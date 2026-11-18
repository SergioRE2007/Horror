-- Banco de las marcas de la noche: arañazos en las puertas y sangre salpicada (docs/sistemas/marcas.md). Ejecutar desde
-- la raíz: lune run tests/bancos/marcas.luau (lo corre tests/regressions.luau). Carga src/juego/cliente/MarcasVista.luau
-- de verdad con el Roblox de mentira (_roblox.luau):
--   Cuentas: la semilla, los surcos de un zarpazo, los rayos de sangre (y hacia dónde salen), el tamaño de las manchas,
--   el color al secarse, lo que baja un chorretón, el tope, cuándo cede la hoja y cuándo está reparada.
--   En el mundo (una fachada con una puerta y una ventana): cada golpe deja un zarpazo por fuera, sin chocar ni
--   CanQuery, pegado a la hoja, al marco o a la pared; lo de la hoja va soldado y gira con ella; con la hoja cediendo,
--   también por dentro; reparada, sin marcas. El Raspador raya el cristal por fuera según raspa; roto, sus rayas se
--   van. La sangre: manchas en la pared y el suelo hasta 3 m, chorretones que bajan despacio sin pasar del suelo, que
--   se seca a casi negro y se limpia al amanecer (los arañazos se quedan). El tope y Rendimiento. Y dos clientes con
--   lo mismo ven lo mismo.
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
local CFG = Config.Marcas
local M = m.cargar("src/juego/cliente/MarcasVista")

---------------------------------------------------------------- cuentas

do
	comprobar(M.semilla("P1", 3) == M.semilla("P1", 3), "semilla: siempre la misma")
	comprobar(M.semilla("P1", 3) ~= M.semilla("P1", 4) and M.semilla("P1", 3) ~= M.semilla("V1", 3), "semilla: distinta")
	comprobar(M.semilla("", 0) > 0, "semilla: nunca 0")

	local azar = Random.new(5)
	for _ = 1, 50 do
		local lista = M.surcos(azar, CFG.Inclina)
		comprobar(#lista >= CFG.Surcos[1] and #lista <= CFG.Surcos[2], "surcos: 3 o 4")
		for i, s in lista do
			comprobar(s.largo > CFG.Largo[1] * 0.7 and s.largo < CFG.Largo[2] * 1.06, "surcos: de largo")
			comprobar(s.ancho >= CFG.Ancho[1] and s.ancho <= CFG.Ancho[2], "surcos: de ancho")
			comprobar(math.abs(s.angulo) < CFG.Inclina + 0.1, "surcos: arañan hacia abajo")
			if i > 1 then
				local a = lista[i - 1]
				comprobar(math.abs(s.angulo - a.angulo) < 0.06, "surcos: paralelos (algo en abanico)")
				-- La separación de lado (perpendicular al surco) entre uno y el siguiente.
				local lado = (s.x - a.x) * math.cos(a.angulo) - (s.y - a.y) * math.sin(a.angulo)
				comprobar(lado > CFG.Separa[1] - 0.13 and lado < CFG.Separa[2] + 0.13, `surcos: separados ({lado})`)
			end
		end
	end

	local rayos = M.rayosSangre(Random.new(2), 40)
	comprobar(#rayos == 40, "rayos: los pedidos")
	local abajo = 0
	for _, d in rayos do
		cerca(d.Magnitude, 1, "rayos: unitarios", 1e-4)
		comprobar(d.Y <= 0.31, "rayos: no hacia el techo")
		if d.Y < 0 then
			abajo += 1
		end
	end
	comprobar(abajo > 20, "rayos: casi todos hacia abajo o de frente")
	local hacia = 0
	for _, d in M.rayosSangre(Random.new(2), 40, Vector3.new(0, 0, -1)) do
		if d.Z < -0.3 then
			hacia += 1
		end
	end
	comprobar(hacia >= 22, `rayos: más hacia el lado contrario del bicho ({hacia})`)

	local a1, l1 = M.mancha(1, Vector3.new(0, 0, -1), Vector3.new(0, 0, 1), 1)
	local a2, l2 = M.mancha(CFG.Alcance, Vector3.new(0, 0, -1), Vector3.new(0, 0, 1), 1)
	comprobar(a1 > a2 and a1 <= CFG.Mancha[2] and a2 >= CFG.Mancha[1] - 1e-6, "mancha: más grande cerca")
	cerca(l1, a1, "mancha: de frente, redonda")
	local a3, l3 = M.mancha(4, Vector3.new(0, -0.95, -0.3).Unit, Vector3.new(0, 0, 1), 1)
	comprobar(l3 > a3 * 2 and l3 <= a3 * 3 + 1e-6, "mancha: de refilón, alargada (como mucho 3 veces)")
	local _ = l2

	local r, gr, b = M.colorSangre(0)
	comprobar(r == CFG.Fresca[1] and gr == CFG.Fresca[2] and b == CFG.Fresca[3], "color: fresca al principio")
	r = M.colorSangre(CFG.Secar * 3)
	comprobar(r == CFG.Seca[1], "color: seca al final")

	cerca(M.chorreo(0, 6, 2), 0, "chorreo: empieza arriba")
	cerca(M.chorreo(6, 6, 2), 2, "chorreo: acaba abajo del todo")
	cerca(M.chorreo(60, 6, 2), 2, "chorreo: no pasa de su largo")
	comprobar(M.chorreo(1, 6, 2) - M.chorreo(0, 6, 2) > M.chorreo(6, 6, 2) - M.chorreo(5, 6, 2), "chorreo: cada vez más despacio")

	comprobar(M.tope(false) == CFG.Tope and M.tope(true) == CFG.TopeRendimiento and CFG.TopeRendimiento < CFG.Tope,
		"tope: menos con Rendimiento")
	local lista = {}
	for i = 1, 65 do
		lista[i] = i
	end
	local quitadas = M.recortar(lista, 60)
	comprobar(#quitadas == 5 and quitadas[1] == 1 and #lista == 60 and lista[1] == 6, "tope: se van las más viejas")

	comprobar(M.cede(30, 100) and not M.cede(50, 100) and not M.cede(0, 0), "cede: con poca vida")
	comprobar(M.danada(99, 100, 0) and M.danada(100, 100, 1) and not M.danada(100, 100, 0), "dañada: vida o cristal")
end

---------------------------------------------------------------- en el mundo

-- Una fachada en z = -20 (fuera, hacia -Z; la sala, hacia +Z) con una puerta en x = 0 y una ventana en x = 8, como las
-- hace Mapa: marco de 0,35 de grueso y 1,3 de fondo, hoja de 0,35 y cristal de 0,2.
local FZ = -20
local FUERA = Vector3.new(0, 0, -1)
local function fachada(mundo: any): (any, any)
	local gg = mundo.global
	local V, C, I = gg.Vector3, gg.CFrame, gg.Instance
	local caja = mundo.caja
	caja(C.new(0, 0, 0), V.new(80, 1, 80), { Name = "Piso", Material = gg.Enum.Material.WoodPlanks })
	local madera = { Material = gg.Enum.Material.Wood, Color = gg.Color3.fromRGB(58, 44, 34) }
	local function muro(x1: number, x2: number, y1: number, y2: number)
		caja(C.new((x1 + x2) / 2, (y1 + y2) / 2, FZ), V.new(x2 - x1, y2 - y1, 1), { Name = "Muro" })
	end
	muro(-12, -2, 0.5, 12)
	muro(2, 6, 0.5, 12)
	muro(10, 16, 0.5, 12)
	muro(-2, 2, 8, 12)
	muro(6, 10, 0.5, 3)
	muro(6, 10, 7, 12)
	-- La puerta.
	local pie = V.new(0, 0.5, FZ)
	local eje = V.new(1, 0, 0)
	local ancho, alto = 4, 7.5
	local puerta = I.new("Model")
	puerta.Name = "PuertaPrincipal"
	local bisagra = C.fromMatrix(pie - eje * (ancho / 2), eje, V.yAxis)
	for _, lado in { -1, 1 } do
		caja(C.new(lado * (ancho / 2 + 0.125), pie.Y + alto / 2, FZ), V.new(0.35, alto + 0.7, 1.36), madera).Name = "Marco"
	end
	local hoja = caja(bisagra * C.new(ancho / 2, alto / 2, 0), V.new(ancho - 0.2, alto - 0.1, 0.35), madera)
	hoja.Name = "Hoja"
	hoja.Parent = puerta
	puerta:SetAttribute("Clave", "P0")
	puerta:SetAttribute("Bisagra", bisagra)
	puerta:SetAttribute("Ancho", ancho)
	-- (Sin CFrame.lookAt: el de Lune, mirando justo hacia -Z, sale al revés. Sin girar, la CFrame ya mira hacia -Z.)
	puerta:SetAttribute("Centro", C.new(pie + V.new(0, alto / 2, 0)))
	puerta:SetAttribute("Fuera", pie + FUERA * 4)
	puerta:SetAttribute("Vida", 100)
	puerta:SetAttribute("VidaMax", 100)
	puerta.Parent = gg.workspace
	mundo.servicio("CollectionService"):AddTag(puerta, "Puerta")
	-- La ventana.
	local centro = V.new(8, 5, FZ)
	local mira = C.new(centro) -- mira hacia fuera (-Z)
	local ventana = I.new("Model")
	ventana.Name = "Ventana"
	local cristal = caja(mira, V.new(4, 4, 0.2), { Name = "Cristal", Transparency = 0.75 })
	cristal.Parent = ventana
	for _, lado in { -1, 1 } do
		caja(mira * C.new(lado * (2 + 0.125), 0, 0), V.new(0.35, 4.7, 1.36), madera).Name = "Marco"
	end
	caja(mira * C.new(0, -2 - 0.125, 0), V.new(4.7, 0.35, 1.3), madera).Name = "Marco"
	caja(mira * C.new(0, 2 + 0.125, 0), V.new(4.7, 0.35, 1.3), madera).Name = "Marco"
	ventana:SetAttribute("Clave", "V0")
	ventana:SetAttribute("Centro", mira)
	ventana:SetAttribute("Ancho", 4)
	ventana:SetAttribute("Alto", 4)
	ventana:SetAttribute("Fuera", V.new(8, 0.5, FZ) + FUERA * 4)
	ventana:SetAttribute("Vida", 60)
	ventana:SetAttribute("VidaMax", 60)
	ventana:SetAttribute("Cristal", 0)
	ventana.Parent = gg.workspace
	mundo.servicio("CollectionService"):AddTag(ventana, "Ventana")
	local bichos = I.new("Folder")
	bichos.Name = "Bichos"
	bichos.Parent = gg.workspace
	mundo.camara.CameraType = gg.Enum.CameraType.Scriptable
	mundo.camara.CFrame = C.new(4, 6, FZ + 10)
	return puerta, ventana
end

local puerta, ventana = fachada(m)
local hoja = puerta.Hoja
local cristal = ventana.Cristal
M.start()
m.correr(0.3)
local carpeta = g.workspace:FindFirstChild("Marcas")
comprobar(carpeta ~= nil, "mundo: la carpeta de las marcas")

local function piezas(): { any }
	local t = {}
	for _, p in carpeta:GetChildren() do
		table.insert(t, p)
	end
	return t
end
local function golpe(el: any, n: number?)
	for _ = 1, n or 1 do
		el:SetAttribute("Golpes", (el:GetAttribute("Golpes") or 0) + 1)
		m.correr(0.1)
	end
end

-- Golpes en la puerta: un zarpazo por golpe, por fuera, en la hoja (soldado a ella) o en el marco.
golpe(puerta, 6)
local n = M.cuantas()
comprobar(n == 6, `puerta: un zarpazo por golpe ({n})`)
local enHoja, enMarco = 0, 0
for _, p in piezas() do
	comprobar(not p.CanCollide and not p.CanQuery and not p.CanTouch and not p.CastShadow, "puerta: sin chocar ni CanQuery")
	comprobar(not m.roto(p.CFrame) and not m.roto(p.Size), "puerta: sin NaN")
	comprobar(p.Position.Z < FZ - 0.17 and p.Position.Z > FZ - 0.95, `puerta: por fuera, pegado ({p.Position.Z})`)
	comprobar(p.CFrame.UpVector.Z < -0.6, "puerta: plano sobre la cara de fuera")
	comprobar(p.Position.Y > 0.5 and p.Position.Y < 8.5 and math.abs(p.Position.X) < 2.5, "puerta: en la puerta")
	if p.Anchored then
		enMarco += 1
		comprobar(math.abs(p.Position.X) > 1.85, "puerta: lo anclado, en el marco")
	else
		enHoja += 1
		local w = p:FindFirstChildOfClass("WeldConstraint")
		comprobar(w and w.Part0 == hoja and w.Part1 == p and p.Massless, "puerta: lo de la hoja, soldado a ella")
	end
end
comprobar(enHoja > 0, `puerta: arañazos en la hoja ({enHoja} piezas, {enMarco} en el marco)`)
-- Cada surco con su borde claro (madera levantada) y alguna astilla.
local claras, oscuras = 0, 0
for _, p in piezas() do
	if p.Material == Enum.Material.Wood then
		claras += 1
	else
		oscuras += 1
		comprobar(p.Color.R < 0.1, "puerta: el surco, oscuro")
	end
end
comprobar(oscuras >= 6 * 3 * 0.6 and claras > oscuras, `puerta: surcos ({oscuras}) con borde claro y astillas ({claras})`)

-- La hoja gira (CasaVista la abre): lo soldado va con ella.
local rel = {}
for _, p in piezas() do
	if not p.Anchored then
		rel[p] = hoja.CFrame:ToObjectSpace(p.CFrame)
	end
end
local bisagra = puerta:GetAttribute("Bisagra")
hoja.CFrame = bisagra * CFrame.Angles(0, math.rad(100), 0) * CFrame.new(2, 3.75, 0)
m.correr(0.1)
for p, r in rel do
	local ahora = hoja.CFrame:ToObjectSpace(p.CFrame)
	cerca((ahora.Position - r.Position).Magnitude, 0, "puerta: gira con la hoja", 1e-3)
end
hoja.CFrame = bisagra * CFrame.new(2, 3.75, 0)
m.correr(0.1)

-- La hoja cede: también por dentro.
puerta:SetAttribute("Vida", 30)
m.correr(0.1)
golpe(puerta)
local dentro = 0
for _, p in piezas() do
	if p.Position.Z > FZ + 0.17 then
		dentro += 1
		comprobar(p.Position.Z < FZ + 0.3 and p.CFrame.UpVector.Z > 0.6 and not p.Anchored, "cede: en la cara de dentro de la hoja")
	end
end
comprobar(dentro > 0, `cede: arañazos por dentro ({dentro})`)

-- Reparada: sin marcas.
puerta:SetAttribute("Vida", 100)
m.correr(0.1)
comprobar(M.cuantas() == 0 and #piezas() == 0, "reparada: la puerta como nueva")

-- La Bestia la echa abajo de una vez (vida a 0 sin golpe): arañazos por los dos lados.
m.correr(1)
puerta:SetAttribute("Vida", 0)
m.correr(0.1)
comprobar(M.cuantas() == 2, `echada abajo: dos zarpazos ({M.cuantas()})`)
puerta:SetAttribute("Vida", 100)
m.correr(0.1)

-- La ventana: en el marco, la pared de al lado y el alféizar; nunca en el cristal.
golpe(ventana, 8)
comprobar(M.cuantas() == 8, `ventana: un zarpazo por golpe ({M.cuantas()})`)
for _, p in piezas() do
	local x, y = p.Position.X - 8, p.Position.Y - 5
	comprobar(p.Anchored, "ventana: el marco y la pared no se mueven: anclado")
	comprobar(p.Position.Z < FZ - 0.45 and p.Position.Z > FZ - 0.95, `ventana: por fuera, pegado ({p.Position.Z})`)
	comprobar(not (math.abs(x) < 1.9 and math.abs(y) < 1.9), "ventana: nada sobre el cristal")
	comprobar(math.abs(x) < 4 and y < 2.5 and y > -4, "ventana: alrededor de ella")
end

-- El Raspador raspa: rayas finas y largas en el cristal, por fuera, soldadas a él.
local raspador = Instance.new("Model")
raspador.Name = "Raspador"
local raizR = m.caja(CFrame.new(8, 3, FZ - 4), Vector3.new(2, 2, 1), { Name = "HumanoidRootPart", CanCollide = false })
raizR.Parent = raspador
raspador.Parent = g.workspace.Bichos
m.correr(0.3)
raspador:SetAttribute("Raspando", true)
local antes = #piezas()
for i = 1, 20 do
	raspador:SetAttribute("Raspado", i * 0.025)
	m.correr(0.25)
end
local rayas = {}
for _, p in piezas() do
	if not p.Anchored then
		table.insert(rayas, p)
	end
end
local pasadas = math.floor(0.5 / CFG.Raspado.Cada + 1e-9)
comprobar(M.cuantas() == 8 + pasadas, `raspador: una pasada cada {CFG.Raspado.Cada} ({M.cuantas() - 8})`)
comprobar(#rayas == #piezas() - antes and #rayas >= pasadas * CFG.Raspado.Rayas[1], `raspador: rayas ({#rayas})`)
for _, p in rayas do
	local w = p:FindFirstChildOfClass("WeldConstraint")
	comprobar(w and w.Part0 == cristal, "raspador: soldadas al cristal")
	local o = cristal.CFrame:PointToObjectSpace(p.Position)
	comprobar(o.Z < -0.1 and o.Z > -0.12, "raspador: por fuera del cristal")
	local punta = math.abs(p.CFrame.UpVector:Dot(cristal.CFrame.RightVector)) * p.Size.Y / 2
	comprobar(math.abs(o.X) + punta < 2 and math.abs(o.Y) + p.Size.Y / 2 * math.abs(p.CFrame.UpVector.Y) < 2.01,
		"raspador: dentro del cristal")
	comprobar(p.Size.X <= 0.03 and p.Size.Y >= 1.2, "raspador: finas y largas")
	comprobar(math.abs(p.CFrame.UpVector.Y) > 0.95, "raspador: casi rectas hacia abajo")
end
-- Otro Raspado más arriba que no raspa (Raspando = false): nada.
raspador:SetAttribute("Raspando", false)
raspador:SetAttribute("Raspado", 0.9)
m.correr(0.2)
comprobar(M.cuantas() == 8 + pasadas, "raspador: sin raspar, nada")
-- El cristal se rompe: sus rayas se van; lo del marco se queda.
ventana:SetAttribute("Cristal", Config.Casa.GolpesCristal)
m.correr(0.1)
comprobar(M.cuantas() == 8, "raspador: roto el cristal, sus rayas fuera")
raspador:Destroy()

-- Sangre: alguien muere dentro, a 4,5 studs de la fachada, con el bicho detrás (las rayos, más hacia la pared).
local otro = m.jugador("Victima")
local pj = m.personaje(CFrame.new(1, 3.5, FZ + 5), otro)
m.correr(0.2)
local raizV = pj.HumanoidRootPart
local origen = raizV.Position + Vector3.new(0, CFG.Pecho, 0)
antes = #piezas()
m.alCliente("Muerte", otro, Vector3.new(1, 6, FZ + 10), nil)
m.correr(0.05)
local _, bajando = M.cuantas()
local sangre, pared, suelo = {}, 0, 0
for _, p in piezas() do
	if p.Color.R > p.Color.G * 4 and p.Anchored then
		table.insert(sangre, p)
	end
end
comprobar(#sangre > 10, `sangre: manchas ({#sangre})`)
for _, p in sangre do
	comprobar(not p.CanCollide and not p.CanQuery and not p.CanTouch, "sangre: sin chocar ni CanQuery")
	comprobar((p.Position - origen).Magnitude < CFG.Alcance + 3, "sangre: hasta 3 m")
	if p.CFrame.UpVector.Z > 0.99 then
		pared += 1
		-- En la pared o en la cara de dentro de un marco (sobresale 0,18).
		local z = p.Position.Z - FZ
		comprobar(math.abs(z - 0.5) < 0.05 or math.abs(z - 0.68) < 0.05, `sangre: pegada a la pared ({z})`)
	elseif p.CFrame.UpVector.Y > 0.99 then
		suelo += 1
		comprobar(p.Position.Y > 0.5 and p.Position.Y < 0.5 + 0.03, "sangre: pegada al suelo, por debajo del charco (lo rodea)")
	else
		-- El costado de un marco que sobresale de la pared: vertical y pegada a él.
		comprobar(math.abs(p.CFrame.UpVector.Y) < 0.01, `sangre: en un costado, vertical ({p.Position})`)
		comprobar(math.abs(math.abs(p.Position.X - 8) - 2.3) < 0.04 or math.abs(math.abs(p.Position.X) - 1.95) < 0.04
			or math.abs(math.abs(p.Position.X) - 2.3) < 0.04 or math.abs(math.abs(p.Position.X - 8) - 1.7) < 0.04, `sangre: en el costado de un marco ({p.Position})`)
	end
end
comprobar(pared > 4 and suelo > 4, `sangre: en la pared ({pared}) y en el suelo ({suelo})`)
local hollin = 0
for _, p in piezas() do
	local d = p:FindFirstChildOfClass("Decal")
	if d then
		hollin += 1
		comprobar(d.Texture == CFG.Textura and p.Transparency == 1, "sangre: el hollín teñido en las grandes")
	end
end
comprobar(hollin > 0, "sangre: alguna mancha grande con hollín")

-- Los chorretones: bajan despacio por la pared, sin pasar del suelo.
comprobar(bajando >= 1 and bajando <= CFG.Chorreones, `sangre: chorretones ({bajando})`)
local barras = {}
for _, p in sangre do
	if math.abs(p.Size.Y - 0.015) < 1e-4 and not p:FindFirstChildOfClass("SpecialMesh") then
		table.insert(barras, { p = p, largo = p.Size.Z })
	end
end
comprobar(#barras == bajando, "sangre: una barra por chorretón")
m.correr(2)
for _, b in barras do
	comprobar(b.p.Size.Z > b.largo + 0.1, "chorretón: va bajando")
	comprobar(b.p.CFrame.ZVector.Y < -0.95, "chorretón: hacia abajo (a lo largo de su Z)")
	b.largo = b.p.Size.Z
end
m.correr(CFG.ChorreaDura[2])
local _, quedan = M.cuantas()
comprobar(quedan == 0, "chorretón: acaba")
for _, b in barras do
	comprobar(b.p.Size.Z >= b.largo, "chorretón: no sube")
	local fondo = b.p.Position.Y - b.p.Size.Z / 2
	comprobar(fondo > 0.5, `chorretón: no pasa del suelo ({fondo})`)
end
-- Se seca.
m.correr(CFG.Secar + 2, 1 / 10)
for _, p in sangre do
	comprobar(math.abs(p.Color.R * 255 - CFG.Seca[1]) < 1.5, "sangre: seca, casi negra")
end

-- El tope (y con Rendimiento, menos y sin chorretones animados).
for i = 1, 4 do
	m.personaje(CFrame.new(-6 + i * 3, 3.5, FZ + 4), otro)
	m.correr(0.1)
	m.alCliente("Muerte", otro, nil, nil)
	m.correr(0.1)
end
comprobar(M.cuantas() == CFG.Tope, `tope: {CFG.Tope} como mucho ({M.cuantas()})`)
jugador:SetAttribute("Rendimiento", true)
m.correr(0.1)
comprobar(M.cuantas() == CFG.TopeRendimiento, `tope: con Rendimiento, {CFG.TopeRendimiento}`)
m.personaje(CFrame.new(-3, 3.5, FZ + 3), otro)
m.correr(0.1)
m.alCliente("Muerte", otro, Vector3.new(-3, 6, FZ + 8), nil)
m.correr(0.05)
local _, animados = M.cuantas()
comprobar(animados == 0 and M.cuantas() == CFG.TopeRendimiento, "rendimiento: chorretones ya escurridos, sin animar")
jugador:SetAttribute("Rendimiento", nil)

-- Al amanecer: la sangre fuera, los arañazos se quedan.
golpe(puerta, 2)
g.workspace:SetAttribute("Fase", "Dia")
m.correr(0.1)
comprobar(M.cuantas() == 2, `amanecer: quedan los arañazos ({M.cuantas()})`)
for _, p in piezas() do
	comprobar(not (p.Color.R > p.Color.G * 4), "amanecer: nada de sangre")
end

-- Dos clientes con lo mismo ven lo mismo (la misma semilla).
local function escena(mundo: any): { string }
	local p2 = fachada(mundo)
	local Marcas2 = mundo.cargar("src/juego/cliente/MarcasVista")
	Marcas2.start()
	mundo.correr(0.2)
	for _ = 1, 3 do
		p2:SetAttribute("Golpes", (p2:GetAttribute("Golpes") or 0) + 1)
		mundo.correr(0.1)
	end
	local victima = mundo.jugador("Victima")
	mundo.personaje(mundo.global.CFrame.new(1, 3.5, FZ + 5), victima)
	mundo.correr(0.1)
	mundo.alCliente("Muerte", victima, mundo.global.Vector3.new(1, 6, FZ + 10), nil)
	mundo.correr(0.1)
	local t = {}
	for _, p in mundo.global.workspace.Marcas:GetChildren() do
		local q = p.Position
		table.insert(t, string.format("%.3f %.3f %.3f %.3f", q.X, q.Y, q.Z, p.Size.Magnitude))
	end
	table.sort(t)
	return t
end
local a, b = escena(crearMundo()), escena(crearMundo({ semilla = 999 }))
comprobar(#a > 20 and #a == #b, `dos clientes: las mismas piezas ({#a} y {#b})`)
for i = 1, #a do
	comprobar(a[i] == b[i], "dos clientes: en el mismo sitio")
end

print(`marcas: bien ({cuentas} comprobaciones)`)
