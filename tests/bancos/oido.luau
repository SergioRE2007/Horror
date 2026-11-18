-- Banco del Oído (sonido tapado por las paredes y eco de cada sala; docs/sistemas/oido.md). Carga
-- src/juego/cliente/OidoVista.luau con el Roblox de mentira (tests/bancos/_roblox.luau): las cuentas puras (paredes →
-- ganancias, punto → eco, contar paredes con un rayo de mentira) y una escena con paredes de verdad: una pared, una
-- pared de tres capas (papel, muro, papel) que cuenta como una, dos y tres paredes (se queda en dos), un tronco que no
-- tapa, abrir la "puerta" (quitarla) y que suene claro, escondido (todo apagado menos lo tuyo), el eco al moverse y
-- Rendimiento (más espaciado y nada lejos). Ejecutar desde la raíz: lune run tests/bancos/oido.luau (lo corre
-- regressions.luau).
local crearMundo = require("./_roblox")

local cuentas = 0
local function comprobar(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end
local function cerca(a: number, b: number, etiqueta: string, margen: number?)
	assert(math.abs(a - b) <= (margen or 0.05), `{etiqueta}: esperado {b}, recibido {a}`)
	cuentas += 1
end

local m = crearMundo()
local g = m.global
local Vector3, CFrame, Enum, Instance = g.Vector3, g.CFrame, g.Enum, g.Instance
local camara = m.camara
local jugador = m.jugadorLocal
local Config = m.cargar("src/shared/Config")
local CFG = Config.Oido
local Oido = m.cargar("src/juego/cliente/OidoVista")
local SoundService = m.servicio("SoundService")

-- Cuentas puras ------------------------------------------------------------------------------------------------------
do
	local b, mi, a = Oido.ganancias(0, false, CFG)
	comprobar(b == 0 and mi == 0 and a == 0, "sin paredes ni escondido: nada")
	local dbPared = 20 * math.log10(CFG.PorPared.Volumen)
	b, mi, a = Oido.ganancias(1, false, CFG)
	cerca(b, dbPared, "una pared: graves = el volumen que queda")
	cerca(mi, dbPared + CFG.PorPared.Medios, "una pared: medios")
	cerca(a, dbPared + CFG.PorPared.Agudos, "una pared: agudos")
	comprobar(a < mi and mi < b and b < 0, "una pared: los agudos pierden más que los medios y estos que los graves")
	local b2, _, a2 = Oido.ganancias(2, false, CFG)
	cerca(b2, 2 * dbPared, "dos paredes: el doble")
	local b5, _, a5 = Oido.ganancias(5, false, CFG)
	comprobar(b5 == b2 and a5 == a2, "más de MaxParedes: como MaxParedes")
	local be, _, ae = Oido.ganancias(0, true, CFG)
	comprobar(be < 0 and ae < be, "escondido: apagado, sobre todo los agudos")
	local _, _, a2e = Oido.ganancias(2, true, CFG)
	comprobar(a2e >= -80 and a2e < a2, "dos paredes y escondido: suma sin bajar de -80")
	-- Volumen: una pared deja en torno al 70 %.
	cerca(10 ^ (b / 20), CFG.PorPared.Volumen, "una pared: volumen que queda", 1e-6)
end

do
	local function z(x: number, y: number, zz: number): string
		return Oido.zona(Vector3.new(x, y, zz), CFG)
	end
	comprobar(z(0, -6, 55) == "StoneCorridor", "sótano")
	comprobar(z(0, -3, 40) == "StoneCorridor", "escalera del sótano")
	comprobar(z(0, 6, 34.5) == "StoneCorridor", "arriba de la escalera del sótano")
	comprobar(z(0, 32, 0) == "Room", "desván")
	comprobar(z(17, 6, 26) == "Bathroom", "baño")
	comprobar(z(17, 19, 26) == "LivingRoom", "encima del baño (la planta de arriba): casa")
	comprobar(z(-49, 6, 18) == "Hangar", "garaje")
	comprobar(z(25, 6, -10) == "LivingRoom", "salón")
	comprobar(z(0, 18, 0) == "LivingRoom", "galería de arriba")
	comprobar(z(40, 6, -30) == "LivingRoom", "torre (anexo)")
	comprobar(z(-20, 6, 40) == "LivingRoom", "lavadero (anexo)")
	comprobar(z(28, 5, -470) == "Alley", "pueblo")
	comprobar(z(200, 5, 200) == "Forest", "bosque")
	comprobar(z(0, 5, 100) == "Forest", "patio de atrás, encima del sótano")
	-- Todos los nombres son ecos de Roblox.
	for _, zona in CFG.Zonas do
		comprobar(pcall(function()
			return Enum.ReverbType[zona.Reverb]
		end), "eco que existe: " .. zona.Reverb)
	end
	comprobar(pcall(function()
		return Enum.ReverbType[CFG.Fuera]
	end), "eco de fuera que existe")
end

-- contar con un rayo de mentira: paredes en x = 5 (tres capas: 4,9, 5 y 5,1), x = 10 (una que no tapa) y x = 15.
do
	local golpes = { { x = 4.9, pared = true }, { x = 5, pared = true }, { x = 5.1, pared = true }, { x = 10, pared = false },
		{ x = 15, pared = true }, { x = 20, pared = true } }
	local rayos = 0
	local function lanzar(o: any, d: any)
		rayos += 1
		for _, h in golpes do
			if h.x > o.X + 1e-6 and h.x <= o.X + d.X then
				return Vector3.new(h.x, 0, 0), h.pared
			end
		end
		return nil, false
	end
	local origen = Vector3.zero
	comprobar(Oido.contar(origen, Vector3.new(4, 0, 0), lanzar, CFG) == 0, "contar: nada por medio")
	comprobar(Oido.contar(origen, Vector3.new(8, 0, 0), lanzar, CFG) == 1, "contar: tres capas = una pared")
	comprobar(Oido.contar(origen, Vector3.new(13, 0, 0), lanzar, CFG) == 1, "contar: lo que no tapa no cuenta")
	comprobar(Oido.contar(origen, Vector3.new(16, 0, 0), lanzar, CFG) == 1, "contar: la pared junto al sonido (Margen) no cuenta")
	comprobar(Oido.contar(origen, Vector3.new(18, 0, 0), lanzar, CFG) == 2, "contar: dos paredes")
	rayos = 0
	comprobar(Oido.contar(origen, Vector3.new(40, 0, 0), lanzar, CFG) == CFG.MaxParedes, "contar: tres paredes = MaxParedes")
	comprobar(rayos <= CFG.Rayos, "contar: no pasa de Rayos")
	comprobar(Oido.contar(origen, Vector3.new(1, 0, 0), lanzar, CFG) == 0, "contar: sonido pegado a la cámara")
end

-- Escena con paredes de verdad ---------------------------------------------------------------------------------------
-- Lejos de la casa y del pueblo (x = 300: eco de bosque). Cámara fija mirando a +x.
local X = 300
camara.CameraType = Enum.CameraType.Scriptable
camara.CFrame = CFrame.new(X, 5, 0)
Oido.start()
m.paso(1 / 60)
comprobar(SoundService.AmbientReverb == Enum.ReverbType.Forest, "eco fuera: bosque")

-- Una pared fina de una pieza a 6 studs (la puerta: se quitará), un muro de tres capas a 12 y otro a 18.
local puerta = m.caja(CFrame.new(X + 6, 5, 0), Vector3.new(0.4, 8, 6), { Name = "Puerta" })
m.caja(CFrame.new(X + 11.9, 5, 0), Vector3.new(0.1, 8, 10), { Name = "Papel" })
m.caja(CFrame.new(X + 12.4, 5, 0), Vector3.new(0.9, 8, 10), { Name = "Muro" })
m.caja(CFrame.new(X + 12.9, 5, 0), Vector3.new(0.1, 8, 10), { Name = "Papel" })
m.caja(CFrame.new(X + 18, 5, 0), Vector3.new(1, 8, 10), { Name = "Muro" })
-- Un tronco (alto y estrecho) y una pieza invisible en otra dirección (z): no tapan.
m.caja(CFrame.new(X, 5, 6), Vector3.new(1.5, 20, 1.5), { Name = "Tronco" })
m.caja(CFrame.new(X, 5, 9), Vector3.new(6, 8, 0.5), { Name = "Invisible", Transparency = 1 })

local function sonar(punto: any, looped: boolean?): any
	local a = Instance.new("Attachment")
	a.WorldPosition = punto
	a.Parent = g.workspace.Terrain
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://1"
	s.RollOffMaxDistance = 100
	s.Looped = looped ~= false
	s.Parent = a
	s:Play()
	Oido.seguir(s)
	return s
end
local function eq(s: any): any
	return s:FindFirstChild("Oido")
end
local function paredesDe(s: any): number
	local e = eq(s)
	if not e or not e.Enabled then
		return 0
	end
	return math.floor(e.LowGain / (20 * math.log10(CFG.PorPared.Volumen)) + 0.5)
end

local claro = sonar(Vector3.new(X + 4, 5, 0))
comprobar(eq(claro) == nil, "sin nada por medio: ni ecualizador")
local una = sonar(Vector3.new(X + 9, 5, 0))
comprobar(paredesDe(una) == 1, "detrás de la puerta: una pared al empezar")
cerca(eq(una).HighGain, 20 * math.log10(CFG.PorPared.Volumen) + CFG.PorPared.Agudos, "detrás de la puerta: sin agudos")
local dos = sonar(Vector3.new(X + 15, 5, 0))
comprobar(paredesDe(dos) == 2, "puerta y muro de tres capas: dos paredes")
local tres = sonar(Vector3.new(X + 24, 5, 0))
comprobar(paredesDe(tres) == 2, "tres paredes: se queda en dos")
local tronco = sonar(Vector3.new(X, 5, 8))
comprobar(eq(tronco) == nil, "un tronco no tapa")
local invisible = sonar(Vector3.new(X, 5, 12))
comprobar(eq(invisible) == nil, "una pieza invisible no tapa")
local golpe = sonar(Vector3.new(X + 6.8, 5, 0)) -- golpeando la puerta desde el otro lado, pegado a ella
comprobar(paredesDe(golpe) == 0, "el golpe en la propia puerta (Margen): claro")

-- Abrir la puerta: en menos de Cada se oye claro.
puerta:Destroy()
m.correr(CFG.Cada + 0.05, 1 / 60)
comprobar(paredesDe(una) == 0, "puerta abierta: claro de golpe")
comprobar(paredesDe(dos) == 1, "puerta abierta: queda el muro")

-- Un sonido que acaba y se destruye se olvida (no falla).
local corto = sonar(Vector3.new(X + 15, 5, 0), false)
corto.Ended:Once(function()
	corto.Parent:Destroy()
end)
m.correr(1.5, 1 / 60)
comprobar(corto.Parent == nil, "el corto se ha ido sin fallar")

-- Escondido: todo apagado menos lo tuyo.
local personaje = m.personaje(CFrame.new(X - 10, 3, 0))
m.paso(1 / 60)
local mio = Instance.new("Sound")
mio.SoundId = "rbxassetid://1"
mio.Looped = true
mio.Parent = personaje:FindFirstChild("HumanoidRootPart") or personaje.PrimaryPart
mio:Play()
Oido.seguir(mio)
local fondo = Instance.new("Sound") -- un bucle sin posición (el viento)
fondo.SoundId = "rbxassetid://1"
fondo.Looped = true
fondo.Parent = SoundService
fondo:Play()
Oido.seguir(fondo)
comprobar(eq(fondo) == nil, "el viento sin esconderse: claro")
jugador:SetAttribute("Escondido", CFrame.new(X, 5, 0))
m.paso(1 / 60)
local _, _, altoEsc = Oido.ganancias(0, true, CFG)
comprobar(eq(claro) and eq(claro).Enabled and math.abs(eq(claro).HighGain - altoEsc) < 0.01, "escondido: lo de fuera apagado al momento")
comprobar(eq(fondo) and eq(fondo).Enabled, "escondido: el viento también")
comprobar(eq(mio) == nil or not eq(mio).Enabled, "escondido: lo tuyo no")
local _, _, altoDos = Oido.ganancias(1, true, CFG)
cerca(eq(dos).HighGain, altoDos, "escondido y una pared: se suman")
jugador:SetAttribute("Escondido", nil)
m.paso(1 / 60)
comprobar(not eq(claro).Enabled and not eq(fondo).Enabled, "al salir: claro otra vez")

-- Eco al moverse la cámara: baño, sótano, garaje, casa, pueblo y vuelta al bosque.
for _, caso in { { Vector3.new(17, 6, 26), "Bathroom" }, { Vector3.new(0, -6, 55), "StoneCorridor" },
	{ Vector3.new(-49, 6, 18), "Hangar" }, { Vector3.new(25, 6, -10), "LivingRoom" }, { Vector3.new(0, 32, 0), "Room" },
	{ Vector3.new(28, 5, -470), "Alley" }, { Vector3.new(X, 5, 0), "Forest" } } do
	camara.CFrame = CFrame.new(caso[1])
	m.correr(CFG.Cada + 0.05, 1 / 60)
	comprobar(SoundService.AmbientReverb == Enum.ReverbType[caso[2]], "eco: " .. caso[2])
end

-- Rendimiento: lo lejano (más de CercaRendimiento) no se mide y lo cercano, cada CadaRendimiento.
jugador:SetAttribute("Rendimiento", true)
local lejano = sonar(Vector3.new(X + 24 + CFG.CercaRendimiento, 5, 0))
comprobar(eq(lejano) == nil, "Rendimiento: lo lejano no se mide")
local muro = m.caja(CFrame.new(X + 2, 5, 0), Vector3.new(0.5, 8, 6), { Name = "Puerta2" })
m.correr(CFG.Cada * 0.6, 1 / 60) -- el siguiente repaso del bucle: aún no le toca (Rendimiento: CadaRendimiento)
m.correr(CFG.CadaRendimiento + 0.3, 1 / 60)
comprobar(paredesDe(claro) == 1, "Rendimiento: lo cercano se sigue midiendo")
muro:Destroy()
jugador:SetAttribute("Rendimiento", nil)

-- Muebles (MuebleRayo): un armario (caja Choque invisible y sin CanQuery, como en el juego) tapa; una pata no.
local casa = Instance.new("Model")
casa.Name = "Casa"
casa.Parent = g.workspace
local mesa = Instance.new("Model")
mesa.Name = "Mesa"
mesa:SetAttribute("Tam", Vector3.new(4, 3, 3))
mesa.WorldPivot = CFrame.new(X - 6, 0, -6)
mesa.Parent = casa
local zonaMesa = m.caja(CFrame.new(X - 6, 1.2, -6), Vector3.new(3, 2.4, 2), { CanCollide = false, CanQuery = false, Transparency = 1 })
zonaMesa.Name = "Debajo"
zonaMesa.Parent = mesa
zonaMesa:AddTag("Debajo")
local armario = m.caja(CFrame.new(X, 3.5, -5), Vector3.new(6, 7, 1), { CanQuery = false, Transparency = 1 })
armario.Name = "Choque"
armario.Parent = casa
local pata = m.caja(CFrame.new(X + 3, 2, 3), Vector3.new(0.4, 4, 0.4), { CanQuery = false, Transparency = 1 })
pata.Name = "Choque"
pata.Parent = casa
m.correr(CFG.MuebleCada + 0.3, 1 / 60) -- que se rehagan las cajas de los muebles
local trasArmario = sonar(Vector3.new(X, 5, -8))
comprobar(paredesDe(trasArmario) == 1, "detrás del armario (MuebleRayo): tapado")
local trasPata = sonar(Vector3.new(X + 6, 3, 6))
comprobar(eq(trasPata) == nil, "detrás de una pata: claro")

-- Mil fotogramas sin fallar con todo sonando.
m.correr(5, 1 / 60)
comprobar(true, "cinco segundos sin fallar")

print(`oido: {cuentas} comprobaciones bien`)
