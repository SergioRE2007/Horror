-- Banco de las huellas de barro y de sangre (docs/sistemas/huellas.md). Ejecutar desde la raíz:
-- lune run tests/bancos/huellas.luau (lo corre tests/regressions.luau). Carga src/juego/cliente/HuellasVista.luau de
-- verdad con el Roblox de mentira (_roblox.luau):
--   Cuentas: cuándo toca una pisada (y que no se pierda ninguna al trocear lo andado), a qué lado, el color de la
--   sangre al secarse, lo que se aclaran, las pisadas rojas de cada jugador, el tope, dentro de casa y los charcos.
--   En el mundo: el Golpeador deja barro dentro de casa (alternando lados, sin chocar ni CanQuery) y nada fuera; tras
--   matar (remote Muerte), sangre también fuera, que se seca a marrón y se acaba a los 40 s; el Trepador, manos y pies,
--   y en la pared nada; el tope (y con Rendimiento); al amanecer, todo fuera; tú: 4 de barro al entrar del bosque y
--   8-10 rojas, cada vez más claras, tras pisar un charco.
-- Si algo no se cumple, termina con error.
local crearMundo = require("./_roblox")

local cuentas = 0
local function comprobar(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end
local function cerca(a: number, b: number, etiqueta: string, margen: number?)
	assert(math.abs(a - b) <= (margen or 1e-6), `{etiqueta}: esperado {b}, recibido {a}`)
	cuentas += 1
end

local m = crearMundo()
local g = m.global
local Vector3, CFrame, Enum, Instance, Random = g.Vector3, g.CFrame, g.Enum, g.Instance, g.Random
local CollectionService = m.servicio("CollectionService")
local jugador = m.jugadorLocal
local Config = m.cargar("src/shared/Config")
local CFG = Config.Huellas
local H = m.cargar("src/juego/cliente/HuellasVista")

---------------------------------------------------------------- cuentas

do
	local queda, partes = H.pisadas(0, 7, 3)
	comprobar(#partes == 2, "pisadas: 7 studs con zancada 3, dos")
	cerca(partes[1], 3 / 7, "pisadas: la primera a los 3")
	cerca(partes[2], 6 / 7, "pisadas: la segunda a los 6")
	cerca(queda, 1, "pisadas: queda 1 andado")
	queda, partes = H.pisadas(2.5, 1, 3)
	comprobar(#partes == 1, "pisadas: con 2,5 andados, una en el siguiente stud")
	cerca(partes[1], 0.5, "pisadas: a mitad")
	cerca(queda, 0.5, "pisadas: queda medio")
	queda, partes = H.pisadas(1, 0, 3)
	comprobar(#partes == 0 and queda == 1, "pisadas: quieto, nada")
	queda, partes = H.pisadas(0, 1000, 1)
	comprobar(#partes <= 6 and queda == 0, "pisadas: un tirón no llena el suelo")
	-- Troceado de cualquier manera, salen las mismas pisadas que de una vez.
	local azar = Random.new(3)
	for _, zancada in { 3.6, 7.5, 3.5, 10.5 } do
		local andado, total, recorrido = 0, 0, 0
		for _ = 1, 400 do
			local d = azar:NextNumber(0, 2.5)
			recorrido += d
			local p
			andado, p = H.pisadas(andado, d, zancada)
			total += #p
			for _, t in p do
				comprobar(t >= 0 and t <= 1, "pisadas: dentro del tramo")
			end
		end
		comprobar(total == math.floor(recorrido / zancada + 1e-9), `pisadas: ninguna perdida con zancada {zancada}`)
	end

	-- Lados: izquierda y derecha alternando; el Trepador, mano izquierda, pie derecho, mano derecha, pie izquierdo.
	for n = 0, 9 do
		local lado, tipo = H.marca("Garra", n)
		comprobar(lado == (if n % 2 == 0 then -1 else 1) and tipo == "Garra", "marca: garras alternando")
	end
	local esperado = { { -1, "Mano" }, { 1, "Pie" }, { 1, "Mano" }, { -1, "Pie" } }
	for n = 0, 7 do
		local lado, tipo = H.marca("ManosPies", n)
		local e = esperado[n % 4 + 1]
		comprobar(lado == e[1] and tipo == e[2], "marca: el Trepador a cuatro patas")
	end

	-- La sangre: roja al principio, marrón al secarse, y no pasa de ahí.
	local r0, g0, b0 = H.colorSangre(0)
	comprobar(r0 == CFG.SangreFresca[1] and g0 == CFG.SangreFresca[2] and b0 == CFG.SangreFresca[3], "sangre: fresca")
	local r1 = H.colorSangre(CFG.Secar)
	cerca(r1, CFG.SangreSeca[1], "sangre: seca al cabo de Secar")
	cerca((H.colorSangre(CFG.Secar * 10)), CFG.SangreSeca[1], "sangre: no pasa de seca")
	comprobar(H.colorSangre(CFG.Secar / 2) < r0 and H.colorSangre(CFG.Secar / 2) > r1, "sangre: a medio secar")
	comprobar(r0 > g0 * 4, "sangre: roja de verdad")

	-- Se aclaran: de su base a la final (nunca más oscuras de lo que nacieron).
	cerca(H.transparencia(0.1, 0), 0.1, "aclarar: recién pisada")
	cerca(H.transparencia(0.1, CFG.Aclarar), CFG.Transparencia[2], "aclarar: al cabo de una noche")
	cerca(H.transparencia(0.1, CFG.Aclarar * 5), CFG.Transparencia[2], "aclarar: y así hasta el amanecer")
	cerca(H.transparencia(0.9, 30), 0.9, "aclarar: una ya muy clara no se oscurece")
	cerca(H.apagada(1, 9), CFG.Transparencia[1], "apagada: la primera, fuerte")
	cerca(H.apagada(9, 9), CFG.SangreUltima, "apagada: la última, casi nada")
	for i = 2, 9 do
		comprobar(H.apagada(i, 9) > H.apagada(i - 1, 9), "apagada: paso a paso")
	end

	-- Pisadas rojas: entre 8 y 10, siempre las mismas para cada jugador.
	for _, id in { -3, -2, -1, 1, 2, 3, 4, 123456789 } do
		local n = H.pasosSangre(id)
		comprobar(n >= CFG.PasosSangre[1] and n <= CFG.PasosSangre[2] and n == H.pasosSangre(id), `pasos de sangre: {id}`)
	end

	comprobar(H.tope(false) == CFG.Tope and H.tope(true) == CFG.TopeRendimiento and CFG.TopeRendimiento < CFG.Tope,
		"tope: menos con Rendimiento")
	local lista = {}
	for i = 1, 85 do
		lista[i] = i
	end
	local quitadas = H.recortar(lista, 80)
	comprobar(#quitadas == 5 and quitadas[1] == 1 and quitadas[5] == 5, "tope: se van las más viejas")
	comprobar(#lista == 80 and lista[1] == 6 and lista[80] == 85, "tope: quedan las nuevas, en orden")
	comprobar(#H.recortar(lista, 80) == 0, "tope: sin pasarse, nada")

	comprobar(H.dentro(Vector3.new(0, 1, 0)), "dentro: el vestíbulo")
	comprobar(H.dentro(Vector3.new(40, 1, -30)), "dentro: la torre")
	comprobar(not H.dentro(Vector3.new(100, 1, 0)), "dentro: el bosque no")
	comprobar(not H.dentro(Vector3.new(0, 50, 0)), "dentro: el tejado no")

	local tam = Vector3.new(0.05, 6, 6) -- el cilindro de MuerteVista (tumbado)
	comprobar(H.enCharco(Vector3.new(2.5, 0.5, 0), Vector3.new(0, 0.53, 0), tam), "charco: dentro")
	comprobar(not H.enCharco(Vector3.new(3.5, 0.5, 0), Vector3.new(0, 0.53, 0), tam), "charco: fuera")
	comprobar(not H.enCharco(Vector3.new(0, 14, 0), Vector3.new(0, 0.53, 0), tam), "charco: en el piso de arriba no")
	comprobar(H.enCharco(Vector3.new(0.8, 0.5, 0), Vector3.new(0, 0.53, 0), Vector3.new(1.9, 1.9, 0.02)), "charco: el del Goteo")
end

---------------------------------------------------------------- en el mundo

-- La casa (suelo de tablas) y el bosque (hierba) a su lado.
m.caja(CFrame.new(0, 0, 0), Vector3.new(79, 1, 67), { Name = "Piso", Material = Enum.Material.WoodPlanks })
m.caja(CFrame.new(140, 0, 0), Vector3.new(200, 1, 120), { Name = "Suelo", Material = Enum.Material.Grass })
local bichosC = Instance.new("Folder")
bichosC.Name = "Bichos"
bichosC.Parent = g.workspace
local camara = m.camara
camara.CameraType = Enum.CameraType.Scriptable
camara.CFrame = CFrame.new(0, 6, 20)

local function bicho(nombre: string, donde: any): (any, any)
	local modelo = Instance.new("Model")
	modelo.Name = nombre
	local raiz = m.caja(CFrame.new(donde), Vector3.new(2, 2, 1), { Name = "HumanoidRootPart", CanCollide = false })
	raiz.Parent = modelo
	modelo.PrimaryPart = raiz
	modelo.Parent = bichosC
	return modelo, raiz
end

local carpeta
local function huellas(): { any }
	local t = {}
	for _, p in carpeta:GetChildren() do
		table.insert(t, p)
	end
	return t
end
-- Lleva la raíz de `desde` a `hasta` a `rapidez` studs/s, fotograma a fotograma (la cámara la sigue de cerca).
local function andar(raiz: any, desde: any, hasta: any, rapidez: number)
	local d = (hasta - desde).Magnitude
	local t = d / rapidez
	local n = math.max(1, math.floor(t * 60))
	for i = 1, n do
		local p = desde:Lerp(hasta, i / n)
		raiz.CFrame = CFrame.new(p)
		camara.CFrame = CFrame.new(p + Vector3.new(0, 4, 12))
		m.paso(1 / 60)
	end
	m.correr(0.3)
end

H.start()
m.correr(0.5)
carpeta = g.workspace:FindFirstChild("Huellas")
comprobar(carpeta ~= nil, "mundo: la carpeta de las huellas")
local PIES = Config.Efectos.Bichos

-- El Golpeador cruza el salón: barro, una por pisada, alternando lados.
local golpeador, raizG = bicho("Golpeador", Vector3.new(-30, 0.5 + PIES.Golpeador.Pies, 0))
m.correr(0.5)
andar(raizG, Vector3.new(-30, 0.5 + PIES.Golpeador.Pies, 0), Vector3.new(30, 0.5 + PIES.Golpeador.Pies, 0), 14)
local lista = huellas()
local esperadas = math.floor(60 / PIES.Golpeador.Zancada)
comprobar(#lista >= esperadas - 1 and #lista <= esperadas, `golpeador: {esperadas} huellas en 60 studs ({#lista})`)
table.sort(lista, function(a, b)
	return a.Position.X < b.Position.X
end)
for i, p in lista do
	comprobar(not p.CanCollide and not p.CanQuery and not p.CanTouch and p.Anchored, "golpeador: sin chocar ni CanQuery")
	comprobar(p.Position.Y > 0.5 and p.Position.Y < 0.6, "golpeador: pegada al suelo")
	local d = p:FindFirstChildOfClass("Decal")
	comprobar(d and d.Texture == CFG.Textura and d.Face == Enum.NormalId.Top, "golpeador: la textura de las uñas")
	comprobar(d.Color3.R * 255 - CFG.Barro[1] < 1, "golpeador: de barro")
	comprobar(p.CFrame.LookVector.X > 0.9, "golpeador: mirando hacia donde va")
	if i > 1 then
		comprobar((p.Position.Z > 0) ~= (lista[i - 1].Position.Z > 0), "golpeador: izquierda y derecha alternando")
	end
end

-- Fuera, sin haber matado: nada.
andar(raizG, Vector3.new(30, 0.5 + PIES.Golpeador.Pies, 0), Vector3.new(50, 0.5 + PIES.Golpeador.Pies, 0), 14)
m.correr(0.2)
local antes = #huellas()
andar(raizG, Vector3.new(50, 0.5 + PIES.Golpeador.Pies, 0), Vector3.new(110, 0.5 + PIES.Golpeador.Pies, 0), 14)
comprobar(#huellas() == antes, "golpeador: fuera de casa, sin barro")

-- Mata a alguien: sangre también fuera, roja y brillante.
m.alCliente("Muerte", m.jugador("Victima"), Vector3.new(110, 6, 0), golpeador)
m.correr(0.2)
andar(raizG, Vector3.new(110, 0.5 + PIES.Golpeador.Pies, 0), Vector3.new(170, 0.5 + PIES.Golpeador.Pies, 0), 14)
local rojas = {}
for _, p in huellas() do
	if p.Position.X > 105 then
		table.insert(rojas, p)
	end
end
comprobar(#rojas >= esperadas - 1, `golpeador: rastro de sangre tras matar ({#rojas})`)
local d0 = rojas[1]:FindFirstChildOfClass("Decal")
local rojo = d0.Color3.R
comprobar(rojo > d0.Color3.G * 3 and rojo * 255 > CFG.SangreSeca[1] + 20, "golpeador: sangre roja")
-- Se seca y se aclara.
local claro = d0.Transparency
m.correr(CFG.Secar + 2, 1 / 10)
comprobar(math.abs(d0.Color3.R * 255 - CFG.SangreSeca[1]) < 1.5, "golpeador: la sangre se seca a marrón")
comprobar(d0.Transparency > claro, "golpeador: se aclara")
-- Pasado Ensangrentado, fuera ya no deja nada.
antes = #huellas()
andar(raizG, Vector3.new(170, 0.5 + PIES.Golpeador.Pies, 0), Vector3.new(120, 0.5 + PIES.Golpeador.Pies, 0), 14)
comprobar(#huellas() == antes, "golpeador: a los 40 s, fuera ya nada")
golpeador:Destroy()

-- Al amanecer, todo fuera.
g.workspace:SetAttribute("Fase", "Dia")
m.correr(0.2)
comprobar(#huellas() == 0, "amanecer: suelo limpio")
g.workspace:SetAttribute("Fase", "Noche")

-- El Trepador: manos y pies (las manos más pequeñas); trepando, nada.
local trepador, raizT = bicho("Trepador", Vector3.new(-30, 1, 10))
m.correr(0.5)
andar(raizT, Vector3.new(-30, 1, 10), Vector3.new(0, 1, 10), 12)
lista = huellas()
comprobar(#lista >= 7, `trepador: huellas ({#lista})`)
local tamanos = {}
for _, p in lista do
	tamanos[math.floor(p.Size.X * 100 + 0.5)] = true
end
local distintos = 0
for _ in tamanos do
	distintos += 1
end
comprobar(distintos == 2, "trepador: manos y pies")
antes = #lista
trepador:SetAttribute("Trepando", true)
andar(raizT, Vector3.new(0, 1, 10), Vector3.new(20, 1, 10), 12)
comprobar(#huellas() == antes, "trepador: por la pared no deja nada")
trepador:SetAttribute("Trepando", nil)

-- El tope (y con Rendimiento, menos).
for i = 1, 14 do
	local z = if i % 2 == 0 then 10 else -10
	andar(raizT, Vector3.new(-30, 1, z), Vector3.new(30, 1, z), 30)
end
comprobar(#huellas() == CFG.Tope, `tope: {CFG.Tope} como mucho ({#huellas()})`)
jugador:SetAttribute("Rendimiento", true)
andar(raizT, Vector3.new(-30, 1, 0), Vector3.new(-20, 1, 0), 12)
comprobar(#huellas() == CFG.TopeRendimiento, `tope: con Rendimiento, {CFG.TopeRendimiento}`)
jugador:SetAttribute("Rendimiento", nil)
trepador:Destroy()
g.workspace:SetAttribute("Fase", "Dia")
m.correr(0.2)
g.workspace:SetAttribute("Fase", "Noche")

-- Tú: del bosque a casa, 4 de barro; luego nada.
local pj = m.personaje(CFrame.new(60, 3.5, 0))
camara.CameraType = Enum.CameraType.Custom
m.correr(1)
comprobar(pj.Humanoid.FloorMaterial == Enum.Material.Grass, "tú: en la hierba")
m.andar(Vector3.new(-1, 0, 0))
m.correr(4)
m.andar(nil)
m.correr(0.5)
local zapatos = huellas()
comprobar(#zapatos == CFG.PasosBarro, `tú: {CFG.PasosBarro} de barro al entrar ({#zapatos})`)
for _, p in zapatos do
	comprobar(p:FindFirstChildOfClass("SpecialMesh") ~= nil and #p:GetChildren() == 2, "tú: óvalos de zapato con tacón")
	comprobar(H.dentro(p.Position), "tú: dentro de casa")
end
m.andar(Vector3.new(0, 0, 1))
m.correr(1.5)
m.andar(nil)
comprobar(#huellas() == CFG.PasosBarro, "tú: las suelas ya limpias")

-- Un charco: 8-10 pisadas rojas, cada una más clara.
local raiz = pj.HumanoidRootPart
local charco = m.caja(CFrame.new(raiz.Position.X, 0.53, raiz.Position.Z), Vector3.new(4, 4, 0.02),
	{ Name = "Charco", CanCollide = false, CanQuery = false })
CollectionService:AddTag(charco, "Charco")
m.correr(0.5)
m.andar(Vector3.new(0, 0, -1))
m.correr(5)
m.andar(nil)
m.correr(0.3)
local n = H.pasosSangre(jugador.UserId)
local rojasTu = {}
for _, p in huellas() do
	if p.Color.R > p.Color.G * 3 then
		table.insert(rojasTu, p)
	end
end
comprobar(#rojasTu == n, `tú: {n} pisadas rojas ({#rojasTu})`)
table.sort(rojasTu, function(a, b)
	return a.Position.Z > b.Position.Z
end)
for i = 2, #rojasTu do
	comprobar(rojasTu[i].Transparency > rojasTu[i - 1].Transparency, "tú: se apagan paso a paso")
end

print(`huellas: bien ({cuentas} comprobaciones)`)
