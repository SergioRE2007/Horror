-- Banco de la casa que se desordena (docs/sistemas/desorden.md). Carga src/juego/cliente/DesordenCuentas.luau y
-- DesordenVista.luau de verdad con el Roblox de mentira (tests/bancos/_roblox.luau) y un Sonido falso que apunta lo que
-- suena. Mira las cuentas (semillas fijas, cuántas caen, el orden por el borde, volcar sin meterse en el suelo, la
-- caída con su bote) y una sala de verdad: una mesa con adornos y una ventana que recibe golpes. Caen 1-2 de los del
-- borde (los mismos en dos clientes), la vajilla se rompe en trozos que crujen al pisarlos, la lata suena y se queda
-- en el suelo, el cuadro se descuelga al tercer golpe, un bicho que pasa vuelca la silla y aparta la mecedora, y al
-- amanecer todo vuelve. Con Rendimiento: una por golpe y sin trozos. Sin NaN nunca.
-- Ejecutar desde la raíz: lune run tests/bancos/desorden.luau (lo corre regressions.luau).
local crearMundo = require("./_roblox")

local cuentas = 0
local function comprobar(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end

---------------------------------------------------------------- cuentas

do
	local m = crearMundo()
	local g = m.global
	local Vector3, CFrame = g.Vector3, g.CFrame
	local Config = m.cargar("src/shared/Config")
	local D = Config.Desorden
	local C = m.cargar("src/juego/cliente/DesordenCuentas")

	comprobar(C.hash("puerta") == C.hash("puerta"), "hash: siempre igual")
	comprobar(C.hash("puerta") ~= C.hash("puertb"), "hash: cambia con el texto")
	for _, t in { "", "a", "el:0,4,9#1", string.rep("z", 300) } do
		local h = C.hash(t)
		comprobar(h >= 0 and h < 2 ^ 32 and h == math.floor(h), "hash: entero de 32 bits")
	end
	comprobar(C.semilla("el:1,2,3", 1) ~= C.semilla("el:1,2,3", 2), "semilla: cada golpe distinto")
	local unos, doses = 0, 0
	for n = 1, 300 do
		local s = C.semilla("el:1,2,3", n)
		local k = C.cuantos(s, false)
		comprobar(k >= D.Caen[1] and k <= D.Caen[2], "cuantos: entre Caen")
		unos += if k == 1 then 1 else 0
		doses += if k == 2 then 1 else 0
		comprobar(C.cuantos(s, true) == 1, "cuantos: con Rendimiento, una")
		local t = C.trozos(s)
		comprobar(t >= D.Trozos[1] and t <= D.Trozos[2], "trozos: entre Trozos")
		local x = C.numero(s, n)
		comprobar(x >= 0 and x < 1, "numero: de 0 a 1")
	end
	comprobar(unos > 60 and doses > 60, `cuantos: salen unos y doses ({unos}, {doses})`)
	local tiran = 0
	for i = 1, 400 do
		tiran += if C.pisadaTira("Golpeador:" .. i) then 1 else 0
	end
	comprobar(tiran > 400 * D.Pisada.Prob * 0.6 and tiran < 400 * D.Pisada.Prob * 1.4, `pisadas: tiran más o menos Prob ({tiran})`)
	comprobar(C.clave(1.4, 2.6, -3.5) == "1,3,-3", "clave: redondeada al stud")

	-- Elegir: siempre los mismos, de los más cerca del borde, sin importar el orden en que llegan.
	local lista = {
		{ borde = 0.9, x = 1, y = 3, z = 0, n = "a" },
		{ borde = 0.2, x = 2, y = 3, z = 0, n = "b" },
		{ borde = 0.5, x = 3, y = 3, z = 0, n = "c" },
		{ borde = 2.0, x = 4, y = 3, z = 0, n = "d" },
		{ borde = 0.5, x = -3, y = 3, z = 0, n = "e" },
	}
	local alReves = {}
	for i = #lista, 1, -1 do
		table.insert(alReves, lista[i])
	end
	for n = 1, 50 do
		local s = C.semilla("x", n)
		local e1, e2 = C.elegir(lista, 2, s), C.elegir(alReves, 2, s)
		comprobar(#e1 == 2 and e1[1].n == e2[1].n and e1[2].n == e2[2].n, "elegir: igual venga como venga")
		comprobar(e1[1] ~= e1[2], "elegir: no repite")
		comprobar(e1[1].n ~= "d" and e1[1].n ~= "a", "elegir: el primero, de los Ventana más cerca del borde")
	end
	comprobar(#C.elegir(lista, 9, 1) == #lista and #C.elegir({}, 2, 1) == 0, "elegir: como mucho los que hay")
	comprobar(#lista == 5 and lista[1].n == "a", "elegir: no toca la lista")

	-- Bordes: del más cerca al más lejos.
	local b = C.bordes(2.5, -0.4, 3, 1.5)
	comprobar(b[1][2] == 1 and b[1][3] == 1 and math.abs(b[1][1] - 0.5) < 1e-6, "bordes: el de +x primero")
	comprobar(b[2][1] <= b[3][1] and b[3][1] <= b[4][1], "bordes: ordenados")

	-- Volcar: a 90° tumbada en el suelo de antes, hacia `dir`, sin NaN; a 0°, quieta.
	local tam = Vector3.new(2, 3, 1.6)
	for _, rot in { 0, 0.7, -2.1 } do
		local cajaCF = CFrame.new(5, 1.5, -2) * CFrame.Angles(0, rot, 0)
		for _, dir in { Vector3.new(1, 0, 0), Vector3.new(0, 0, -1), Vector3.new(0.6, 0, 0.8) } do
			local quieta = C.volcar(cajaCF, tam, dir, 0)
			comprobar((quieta.Position).Magnitude < 1e-4, "volcar: a 0° no se mueve")
			local giro = C.volcar(cajaCF, tam, dir, math.pi / 2)
			comprobar(not m.roto(giro), "volcar: sin NaN")
			local nueva = giro * cajaCF
			local bajo = nueva.Position.Y - C.saliente(nueva.Rotation, tam, Vector3.yAxis)
			comprobar(math.abs(bajo - 0) < 1e-3, `volcar: tumbada en el suelo ({bajo})`)
			comprobar((nueva.Position - cajaCF.Position):Dot(dir) > 0.5, "volcar: hacia donde la empujan")
			comprobar(math.abs(nueva.UpVector:Dot(Vector3.yAxis)) < 1e-3, "volcar: de lado")
		end
	end
	comprobar(C.volcar(CFrame.new(), tam, Vector3.yAxis, 1) == CFrame.identity, "volcar: sin dirección, nada")

	-- La caída: empieza quieta, llega a 90° y el bote no se pasa (no se mete en el suelo).
	comprobar(C.caida(0, true) == 0 and C.caida(0, false) == 0, "caida: empieza de pie")
	comprobar(math.abs(C.caida(1, true) - math.pi / 2) < 1e-6 and math.abs(C.caida(1, false) - math.pi / 2) < 1e-6,
		"caida: acaba tumbada")
	local boto = false
	for t = 0, 1, 0.02 do
		comprobar(C.caida(t, true) <= math.pi / 2 + 1e-9 and C.caida(t, false) <= math.pi / 2 + 1e-9, "caida: nunca más de 90°")
		boto = boto or C.caida(t, true) < math.pi / 2 - 0.05 and t > 0.75
	end
	comprobar(boto, "caida: con rebote, un botecito")
	comprobar(C.aparta(0) == 0 and C.aparta(1) == 1 and C.aparta(0.5) > 0.5, "aparta: deprisa y frena")

	-- Rozar: un tramo que pasa al lado de la caja sí; uno lejos no.
	local cajaS = CFrame.new(10, 1, 10)
	comprobar(C.roza(Vector3.new(6, 5, 11.8), Vector3.new(14, 5, 11.8), cajaS, 1, 1, D.Roce), "roza: pasa a 0,8 del lado")
	comprobar(not C.roza(Vector3.new(6, 5, 14), Vector3.new(14, 5, 14), cajaS, 1, 1, D.Roce), "roza: a 3 no")
	comprobar(C.choca(-10, 0) and not C.choca(-2, 0) and not C.choca(-10, -9), "choca: solo al frenar de golpe")
end

---------------------------------------------------------------- una sala de verdad

-- Un mundo con la sala: suelo, una mesa contra la pared con adornos, un cuadro, una silla, una mecedora y una ventana.
local function escena(rendimiento: boolean)
	local m = crearMundo()
	local g = m.global
	local Vector3, CFrame, Instance = g.Vector3, g.CFrame, g.Instance
	local CollectionService = m.servicio("CollectionService")
	local sonados: { string } = {}
	m.falso("Sonido", {
		en = function(nombre: string)
			table.insert(sonados, nombre)
			local s = Instance.new("Sound")
			s.Parent = g.workspace
			return s
		end,
		hay = function()
			return false
		end,
	})
	local Config = m.cargar("src/shared/Config")
	local C = m.cargar("src/juego/cliente/DesordenCuentas")
	local V = m.cargar("src/juego/cliente/DesordenVista")
	m.jugadorLocal:SetAttribute("Rendimiento", rendimiento)
	g.workspace:SetAttribute("Fase", "Noche")

	local mapa = Instance.new("Folder")
	mapa.Name = "Mapa"
	mapa.Parent = g.workspace
	local casa = Instance.new("Model")
	casa.Name = "Casa"
	casa.Parent = mapa
	local bichos = Instance.new("Folder")
	bichos.Name = "Bichos"
	bichos.Parent = g.workspace

	m.caja(CFrame.new(0, -0.5, 0), Vector3.new(80, 1, 80), { Name = "Suelo", Parent = casa })
	m.caja(CFrame.new(0, 2.8, 0), Vector3.new(6, 0.4, 3), { Name = "Tablero", Parent = casa }) -- arriba a 3
	m.caja(CFrame.new(0, 5, -2.1), Vector3.new(20, 10, 0.2), { Name = "Pared", Parent = casa }) -- detrás de la mesa
	local function cosa(nombre: string, pos: any, tam: any, padre: any?): any
		local modelo = Instance.new("Model")
		modelo.Name = nombre
		local p = Instance.new("Part")
		p.Name = "Cuerpo"
		p.Anchored = true
		p.Size = tam
		p.CFrame = CFrame.new(pos)
		p.Parent = modelo
		modelo.Parent = padre or casa
		return modelo
	end
	local adornos = {
		Plato = cosa("PlatoPH", Vector3.new(2.5, 3.1, 1.2), Vector3.new(0.8, 0.2, 0.8)),
		Licores = cosa("Licores", Vector3.new(-2.6, 3.6, 0.9), Vector3.new(0.4, 1.2, 0.4)),
		Latas = cosa("LatasPH", Vector3.new(0.5, 3.3, 1.0), Vector3.new(0.5, 0.6, 0.5)),
		Tarro = cosa("TarroPH", Vector3.new(0, 3.3, -0.2), Vector3.new(0.5, 0.6, 0.5)),
		Suelo = cosa("TarrosSotano", Vector3.new(5, 0.4, 5), Vector3.new(0.8, 0.8, 0.8)), -- en el suelo: no cae
	}
	local cuadro = cosa("CuadroViejo", Vector3.new(-6, 5, -1.95), Vector3.new(2, 1.5, 0.1))
	-- La silla (patas, asiento y respaldo) y la mecedora, por donde va a pasar el bicho.
	local silla = Instance.new("Model")
	silla.Name = "SillaCocinaPH"
	m.caja(CFrame.new(20, 0.675, 10), Vector3.new(1.8, 1.35, 1.8), { Name = "Patas", Parent = silla })
	m.caja(CFrame.new(20, 1.5, 10), Vector3.new(2, 0.3, 2), { Name = "Asiento", Parent = silla })
	m.caja(CFrame.new(20, 2.65, 9.1), Vector3.new(2, 2, 0.2), { Name = "Respaldo", Parent = silla })
	silla.Parent = casa
	local mecedora = cosa("Mecedora", Vector3.new(21, 1.5, 12.5), Vector3.new(2, 3, 2))
	local ventana = Instance.new("Model")
	ventana.Name = "Ventana"
	ventana:SetAttribute("Centro", CFrame.lookAt(Vector3.new(0, 4, 9), Vector3.new(0, 4, 10))) -- mira hacia fuera
	ventana:SetAttribute("Golpes", 0)
	ventana.Parent = g.workspace
	CollectionService:AddTag(ventana, "Ventana")
	m.camara.CFrame = CFrame.new(0, 5, 10)

	V.start()
	m.correr(4, 1 / 30) -- que busque lo que hay en la casa (2 s después del último cambio)
	return {
		m = m, g = g, V = V, C = C, D = Config.Desorden, sonados = sonados, adornos = adornos, cuadro = cuadro,
		silla = silla, mecedora = mecedora, ventana = ventana, bichos = bichos,
	}
end

local function nombres(lista: { any }): string
	local l = {}
	for _, x in lista do
		table.insert(l, x.Name)
	end
	table.sort(l)
	return table.concat(l, ",")
end

local s = escena(false)
local m, g, V, C, D = s.m, s.g, s.V, s.C, s.D
local Vector3, CFrame = g.Vector3, g.CFrame
local origen: { [any]: any } = {}
for _, modelo in s.adornos do
	origen[modelo] = modelo.Cuerpo.CFrame
end
origen[s.cuadro] = s.cuadro.Cuerpo.CFrame

local function sinNaN(etiqueta: string)
	for _, p in g.workspace.Desorden:GetDescendants() do
		if p:IsA("BasePart") then
			comprobar(not m.roto(p.CFrame), etiqueta .. ": copias y trozos sin NaN")
		end
	end
	for _, modelo in { s.silla, s.mecedora, s.cuadro } do
		for _, p in modelo:GetDescendants() do
			if p:IsA("BasePart") then
				comprobar(not m.roto(p.CFrame), etiqueta .. ": sin NaN")
			end
		end
	end
end
local function correr(segundos: number, etiqueta: string, cada: (() -> ())?)
	m.correr(segundos, 1 / 60, function()
		sinNaN(etiqueta)
		if cada then
			cada()
		end
	end)
end
local function escondido(modelo: any): boolean
	return modelo.Cuerpo.Position.Y < -500
end

-- Primer golpe: caen 1-2 de la mesa (nunca el del suelo ni el cuadro), su pieza de verdad se esconde mientras cae.
s.ventana:SetAttribute("Golpes", 1)
correr(0.5, "golpe 1")
local esperados = C.cuantos(C.semilla("el:" .. C.clave(0, 4, 9) .. "|0", 1), false)
local est = V.estado()
comprobar(est.total == esperados, `golpe 1: caen {esperados} ({est.total})`)
comprobar(#est.cayendo == esperados, "golpe 1: con su copia cayendo")
for _, copia in est.cayendo do
	comprobar(copia.Name ~= "TarrosSotano" and copia.Name ~= "CuadroViejo", "golpe 1: ni lo del suelo ni el cuadro")
end
for _, k in V.copias() do
	comprobar(escondido(k.modelo), "golpe 1: la de verdad, escondida")
end
comprobar(not escondido(s.adornos.Suelo) and not escondido(s.cuadro), "golpe 1: lo demás, en su sitio")
local primeros = nombres(est.cayendo)

-- Otro cliente con la misma casa: caen las mismas cosas.
do
	local s2 = escena(false)
	s2.ventana:SetAttribute("Golpes", 1)
	s2.m.correr(0.5, 1 / 60)
	comprobar(nombres(s2.V.estado().cayendo) == primeros, `otro cliente: las mismas ({primeros})`)
end

-- Dan contra el suelo (a mano: el mundo de mentira no tiene física). La vajilla se rompe; la lata suena y se queda.
local function aterrizar()
	for _, k in V.copias() do
		for _, p in k.copias do
			p.CFrame = p.CFrame - Vector3.new(0, 2.6, 0) + Vector3.new(0, 0, 1.2)
		end
		k.copias[1].AssemblyLinearVelocity = Vector3.new(0, -12, 0)
	end
	m.paso(1 / 60)
	for _, k in V.copias() do
		k.copias[1].AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	end
	m.paso(1 / 60)
end
table.clear(s.sonados)
local caian = V.copias()
aterrizar()
local rotos, latas = 0, 0
for _, k in caian do
	local nombre = k.modelo.Name
	if nombre == "LatasPH" then
		latas += 1
		comprobar(table.find(s.sonados, "Latas") ~= nil, "lata: suena al dar contra el suelo")
	elseif nombre == "PlatoPH" or nombre == "Licores" or nombre == "TarroPH" then
		rotos += 1
		comprobar(escondido(k.modelo), "vajilla: rota, la de verdad no vuelve")
		comprobar(k.copias[1].Parent == nil, "vajilla: la copia se va")
	end
end
if rotos > 0 then
	local trozos = 0
	for _, p in g.workspace.Desorden:GetChildren() do
		trozos += if p.Name == "Trozo" then 1 else 0
	end
	comprobar(trozos >= D.Trozos[1] * rotos and trozos <= D.Trozos[2] * rotos, `vajilla: {trozos} trozos`)
	comprobar(table.find(s.sonados, "Cristal") ~= nil, "vajilla: suena a roto")
end
correr(D.AnclarMax + 0.5, "se posan")
comprobar(#V.copias() == 0, "posadas: no queda ninguna copia")
for _, k in caian do
	if k.modelo.Name == "LatasPH" then
		local p = k.modelo.Cuerpo
		comprobar(not escondido(k.modelo) and p.Anchored, "lata: la de verdad, anclada donde cayó")
		comprobar(p.Position.Y < 1.5, "lata: en el suelo")
	end
end
for _, p in g.workspace.Desorden:GetChildren() do
	if p.Name == "Trozo" then
		comprobar(p.Anchored, "trozos: anclados al pararse")
	end
end
comprobar(rotos + latas == #caian, "golpe 1: todo lo que cayó, roto o en el suelo")

-- Los trozos crujen al pisarlos (uno, a mano, delante del personaje).
local trozo: any = nil
for _, p in g.workspace.Desorden:GetChildren() do
	if p.Name == "Trozo" then
		trozo = p
		break
	end
end
if not trozo then -- solo cayó la lata: se rompe algo a mano para pisarlo
	s.ventana:SetAttribute("Golpes", 2)
	correr(0.5, "golpe 2")
	aterrizar()
	for _, p in g.workspace.Desorden:GetChildren() do
		if p.Name == "Trozo" then
			trozo = p
			break
		end
	end
	correr(D.AnclarMax + 0.5, "se posan 2")
end
if trozo then
	trozo.CFrame = CFrame.new(1, 0.05, 8)
	local pj = s.m.personaje(CFrame.new(1, 3, 4))
	m.camara.CFrame = CFrame.new(1, 5, 4)
	table.clear(s.sonados)
	m.andar(Vector3.new(0, 0, 1))
	correr(1, "pisar")
	m.andar(nil)
	comprobar(table.find(s.sonados, "Cruje") ~= nil, "pisar: cruje")
	local veces = 0
	for _, n in s.sonados do
		veces += if n == "Cruje" then 1 else 0
	end
	comprobar(veces <= 2, `pisar: no a cada fotograma ({veces})`)
	comprobar(pj.Parent ~= nil, "pisar: el personaje sigue ahí")
end

-- El cuadro aguanta dos golpes y se descuelga al tercero.
for n = (s.ventana:GetAttribute("Golpes") :: number) + 1, D.CuadroGolpes - 1 do
	s.ventana:SetAttribute("Golpes", n)
	correr(0.5, "golpe " .. n)
	comprobar(not escondido(s.cuadro), `cuadro: aguanta el golpe {n}`)
	aterrizar()
	correr(D.AnclarMax + 0.5, "se posan " .. n)
end
table.clear(s.sonados)
s.ventana:SetAttribute("Golpes", D.CuadroGolpes)
correr(0.1, "golpe del cuadro")
comprobar(escondido(s.cuadro), "cuadro: al tercer golpe se descuelga")
local cuadroCae = false
for _, k in V.copias() do
	cuadroCae = cuadroCae or k.modelo == s.cuadro
end
comprobar(cuadroCae, "cuadro: cae su copia")
aterrizar()
comprobar(table.find(s.sonados, "CuadroCae") ~= nil, "cuadro: suena al caer")
correr(D.AnclarMax + 0.5, "cuadro posado")
comprobar(not escondido(s.cuadro) and s.cuadro.Cuerpo.Position.Y < 4, "cuadro: en el suelo")

-- Un golpe de mentira (bajar Golpes al reparar) no tira nada.
local antes = V.estado().total
s.ventana:SetAttribute("Golpes", 0)
correr(0.5, "golpes a cero")
comprobar(V.estado().total == antes, "golpes a cero: nada cae")

-- Un bicho cruza la sala: vuelca la silla que roza y aparta la mecedora.
local origSilla: { [any]: any } = {}
for _, p in s.silla:GetChildren() do
	origSilla[p] = p.CFrame
end
local origMecedora = s.mecedora.Cuerpo.CFrame
local bicho = g.Instance.new("Model")
bicho.Name = "Golpeador"
local raiz = g.Instance.new("Part")
raiz.Name = "HumanoidRootPart"
raiz.Anchored = true
raiz.CanCollide = false
raiz.Size = Vector3.new(2, 2, 1)
raiz.CFrame = CFrame.new(15, 5, 10.5)
raiz.Parent = bicho
bicho.Parent = s.bichos
m.camara.CFrame = CFrame.new(20, 5, 20)
table.clear(s.sonados)
local t = 0
correr(1.5, "bicho", function()
	t += 1 / 60
	raiz.CFrame = CFrame.new(15 + math.min(t, 1) * 10, 5, 10.5)
end)
local bajo, arriba = math.huge, -math.huge
for _, p in s.silla:GetChildren() do
	bajo = math.min(bajo, p.Position.Y - 1.1)
	arriba = math.max(arriba, p.Position.Y)
end
local asiento = s.silla.Asiento
comprobar(math.abs(asiento.CFrame.UpVector.Y) < 0.2, "silla: volcada (de lado)")
comprobar(asiento.Position.X > origSilla[asiento].Position.X + 0.3, "silla: hacia donde iba el bicho")
for _, p in s.silla:GetChildren() do
	local cf, tam = p.CFrame, p.Size
	local yMin = math.huge
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				yMin = math.min(yMin, (cf * Vector3.new(sx * tam.X / 2, sy * tam.Y / 2, sz * tam.Z / 2)).Y)
			end
		end
	end
	comprobar(yMin > -0.05, `silla: no se mete en el suelo ({yMin})`)
end
comprobar(table.find(s.sonados, "Caida") ~= nil, "silla: suena al caer")
local movida = s.mecedora.Cuerpo.Position - origMecedora.Position
comprobar(math.abs(movida.Magnitude - D.Mecedora.Aparta) < 0.05, `mecedora: se aparta ({movida.Magnitude})`)
local _, giro = origMecedora:ToObjectSpace(s.mecedora.Cuerpo.CFrame):ToEulerAnglesYXZ()
comprobar(math.abs(math.abs(math.deg(giro)) - D.Mecedora.Giro) < 1, "mecedora: y se gira")
comprobar(math.abs(s.mecedora.Cuerpo.Position.Y - origMecedora.Position.Y) < 1e-4, "mecedora: sin hundirse")
local volcadas = V.estado().total
correr(1, "bicho vuelve", function()
	raiz.CFrame = CFrame.new(25 - math.min(t, 1) * 10, 5, 10.5)
end)
comprobar(V.estado().total == volcadas, "silla: tirada, no vuelve a volcar")

-- Al amanecer todo vuelve a su sitio y los trozos se recogen.
bicho:Destroy()
g.workspace:SetAttribute("Fase", "Dia")
correr(2, "amanecer")
for modelo, cf in origen do
	comprobar((modelo.Cuerpo.Position - cf.Position).Magnitude < 1e-4, `amanecer: {modelo.Name} en su sitio`)
end
for p, cf in origSilla do
	comprobar((p.Position - cf.Position).Magnitude < 1e-4 and p.CFrame.UpVector.Y > 0.999, "amanecer: la silla, de pie")
end
comprobar((s.mecedora.Cuerpo.Position - origMecedora.Position).Magnitude < 1e-4, "amanecer: la mecedora")
comprobar(#g.workspace.Desorden:GetChildren() == 0, "amanecer: sin trozos ni copias")
comprobar(V.estado().total == 0, "amanecer: la cuenta, a cero")

-- Otra noche: los golpes vuelven a tirar cosas.
g.workspace:SetAttribute("Fase", "Noche")
s.ventana:SetAttribute("Golpes", 1)
correr(0.5, "otra noche")
comprobar(V.estado().total >= 1, "otra noche: vuelve a caer")

---------------------------------------------------------------- con Rendimiento

do
	local r = escena(true)
	local rm, rV = r.m, r.V
	for n = 1, 3 do
		r.ventana:SetAttribute("Golpes", n)
		rm.correr(0.5, 1 / 60)
		comprobar(rV.estado().total <= n, `poco: una por golpe ({rV.estado().total})`)
		for _, k in rV.copias() do
			for _, p in k.copias do
				p.CFrame = p.CFrame - r.g.Vector3.new(0, 2.6, 0)
			end
			k.copias[1].AssemblyLinearVelocity = r.g.Vector3.new(0, -12, 0)
		end
		rm.paso(1 / 60)
		for _, k in rV.copias() do
			k.copias[1].AssemblyLinearVelocity = r.g.Vector3.zero
		end
		rm.correr(r.D.AnclarMax + 0.5, 1 / 60)
	end
	comprobar(rV.estado().total >= 1, "poco: también caen")
	comprobar(rV.estado().trozos == 0, "poco: la vajilla no se rompe")
	for _, modelo in r.adornos do
		comprobar(not escondido(modelo), "poco: todo a la vista (entero)")
	end
end

print(`desorden: {cuentas} comprobaciones`)
