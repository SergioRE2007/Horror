-- Banco del aire vivo (docs/sistemas/aire.md). Ejecutar desde la raíz: lune run tests/bancos/aire.luau (lo corre
-- tests/regressions.luau). Carga src/juego/cliente/AireVista.luau de verdad con el Roblox de mentira (_roblox.luau):
--   Cuentas: la noche (las rampas de Ambiente), dentro de casa y las salas con más polvo, el viento (unitario, sin NaN,
--   racha de 0 a 1) y el ancho del haz.
--   Por sitios: motas dentro (el triple en el trastero, el desván y el sótano), nada fuera; niebla solo fuera y de noche;
--   pinocha solo bajo un pino en una racha; el haz de luna de noche, apagado de día, lejos y con las cortinas echadas;
--   con Rendimiento, motas a Config.Aire.Rendimiento y nada más; en una cinemática, nada (en un vistazo, sí).
-- Si algo no se cumple, termina con error.
local crearMundo = require("./_roblox")

local cuentas = 0
local function comprobar(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end
local function cerca(a: number, b: number, etiqueta: string)
	assert(math.abs(a - b) < 1e-6, `{etiqueta}: esperado {b}, recibido {a}`)
	cuentas += 1
end

local m = crearMundo()
local g = m.global
local Vector3, CFrame, Enum, Instance = g.Vector3, g.CFrame, g.Enum, g.Instance
local CollectionService = m.servicio("CollectionService")
local jugador = m.jugadorLocal
local camara = m.camara
local Config = m.cargar("src/shared/Config")
local CFG = Config.Aire

-- El mapa: el suelo de la casa y del bosque, una luz de luna con su ventana y un pino lejos de la casa.
local mapa = Instance.new("Folder")
mapa.Name = "Mapa"
mapa.Parent = g.workspace
m.caja(CFrame.new(0, 0.5, 0), Vector3.new(80, 1, 70), { Name = "Piso" })
m.caja(CFrame.new(200, -1, 200), Vector3.new(300, 2, 300), { Name = "Suelo" })
-- (CFrame.lookAt de Lune sale al revés en z: hecho a mano)
local mira = (Vector3.new(0, 1, -19) - Vector3.new(0, 19, -31.8)).Unit
local lado = mira:Cross(Vector3.yAxis).Unit
local luna = m.caja(CFrame.fromMatrix(Vector3.new(0, 19, -31.8), lado, lado:Cross(mira), -mira), Vector3.new(1, 1, 1),
	{ Name = "Adorno", CanQuery = false, CanCollide = false, Transparency = 1 })
local foco = Instance.new("SpotLight")
foco.Range = 40
foco.Parent = luna
CollectionService:AddTag(luna, "Luna")
local ventana = Instance.new("Model")
ventana.Name = "Ventana"
ventana:SetAttribute("Centro", CFrame.new(0, 19, -32.4))
ventana.Parent = mapa
CollectionService:AddTag(ventana, "Ventana")
-- Un paño de cortina en el camino del haz (de pie, junto a la ventana): el haz lo atraviesa y sigue hasta el suelo.
m.caja(CFrame.new(0, 17, -30.5), Vector3.new(4, 4, 0.2), { Name = "Pano", CanCollide = false }).Parent = ventana
local tronco = m.caja(CFrame.new(150, 30, 150), Vector3.new(3, 60, 3), { Name = "Tronco" })
CollectionService:AddTag(tronco, "Pino")

-- Noche cerrada (a mitad de la noche).
local function fase(nombre: string, p: number)
	local ahora = g.workspace:GetServerTimeNow()
	g.workspace:SetAttribute("Fase", nombre)
	g.workspace:SetAttribute("FaseInicio", ahora - p * 600)
	g.workspace:SetAttribute("FaseFin", ahora + (1 - p) * 600)
end
fase("Noche", 0.5)

local Aire = m.cargar("src/juego/cliente/AireVista")

-- Cuentas. -------------------------------------------------------------------------------------------------------------
cerca(Aire.noche("Dia", 0.5), 0, "noche: de día")
cerca(Aire.noche("Dia", 0.9), 0.5, "noche: atardeciendo")
cerca(Aire.noche("Noche", 0.5), 1, "noche: de noche")
cerca(Aire.noche("Noche", 0.95), 0.5, "noche: amaneciendo")
cerca(Aire.noche(nil, 0.5), 0, "noche: sin fase")
local function dentro(x: number, y: number, z: number): (boolean, number)
	return Aire.dentro(Vector3.new(x, y, z))
end
local d, n = dentro(0, 6, 0)
comprobar(d and n == 1, "dentro: vestíbulo")
d, n = dentro(17, 6, 12)
comprobar(d and n == 3, "dentro: trastero, el triple")
d, n = dentro(0, 32, 0)
comprobar(d and n == 3, "dentro: desván, el triple")
d, n = dentro(0, -6, 55)
comprobar(d and n == 3, "dentro: sótano, el triple")
d = dentro(0, 20, 0)
comprobar(d, "dentro: planta de arriba")
d = dentro(-36, 6, -10)
comprobar(d, "dentro: mirador del comedor (anexo)")
d = dentro(100, 6, 100)
comprobar(not d, "fuera: bosque")
d = dentro(0, 50, 0)
comprobar(not d, "fuera: encima del tejado")
for t = 0, 5000, 37.3 do
	local hacia, fuerza, racha = Aire.vientoEn(1_793_000_000 + t)
	comprobar(math.abs(hacia.Magnitude - 1) < 1e-4 and hacia.Y == 0, "viento: unitario y plano")
	comprobar(fuerza >= CFG.Viento.Fuerza[1] - 1e-9 and fuerza <= CFG.Viento.Fuerza[2] + 1e-9, "viento: fuerza en su rango")
	comprobar(racha >= 0 and racha <= 1, "viento: racha de 0 a 1")
end
local a1, a2 = Aire.anchoHaz(12.5)
comprobar(a1 == CFG.Haz.Ancho[1] and a2 > a1 and a2 <= CFG.Haz.Ancho[2], "haz: se abre hacia el suelo")
local _, a3 = Aire.anchoHaz(500)
comprobar(a3 == CFG.Haz.Ancho[2], "haz: con tope")

-- Por sitios. ---------------------------------------------------------------------------------------------------------
Aire.start()
local carpeta = g.workspace:FindFirstChild("AireLocal")
comprobar(carpeta, "carpeta AireLocal")
local function emisor(nombre: string): any
	return (carpeta:FindFirstChild(nombre) :: any):FindFirstChildOfClass("ParticleEmitter")
end
local motas, niebla, pinocha = emisor("AireMotas"), emisor("AireNiebla"), emisor("AirePinocha")
camara.CameraType = Enum.CameraType.Scriptable
jugador:SetAttribute("Vistazo", "Mirilla") -- Scriptable pero en un vistazo: cuenta como jugando

local function ir(p: any)
	camara.CFrame = CFrame.new(p)
	m.correr(0.25, 1 / 60, function()
		for _, cosa in carpeta:GetDescendants() do
			if cosa:IsA("BasePart") then
				comprobar(not m.roto(cosa.CFrame), "sin NaN en " .. cosa.Name)
			end
		end
	end)
end
local function haz(): any
	local h = Aire.estado.haces[luna]
	return h and h.beam
end

ir(Vector3.new(0, 6, -10))
comprobar(motas.Rate == CFG.Motas.Rate, "motas: dentro, las normales")
comprobar((carpeta.AireMotas.Position - camara.CFrame.Position).Magnitude < CFG.Motas.Delante + 1, "motas: delante de la cámara")
comprobar(niebla.Rate == 0 and pinocha.Rate == 0, "dentro: sin niebla ni pinocha")
comprobar(haz() and haz().Enabled, "haz: de noche y cerca, encendido")
comprobar(Aire.estado.haces[luna].emisor.Rate > 0, "haz: con sus motas")
local largoHaz = (haz().Attachment0.WorldPosition - haz().Attachment1.WorldPosition).Magnitude
comprobar(largoHaz > 10 and largoHaz < 25, "haz: de la ventana al suelo (" .. largoHaz .. ")")
comprobar(math.abs(haz().Attachment1.WorldPosition.Y - 1) < 0.2, "haz: acaba en el suelo")
comprobar(Aire.estado.haces[luna].ventana == ventana, "haz: con su ventana")

ventana:SetAttribute("Persiana", true)
ir(Vector3.new(0, 6, -10))
comprobar(not haz().Enabled and Aire.estado.haces[luna].emisor.Rate == 0, "haz: cortinas echadas, apagado")
ventana:SetAttribute("Persiana", false)
ir(Vector3.new(0, 6, -10))
comprobar(haz().Enabled, "haz: cortinas abiertas, otra vez")

ir(Vector3.new(17, 6, 12))
comprobar(motas.Rate == CFG.Motas.Rate * 3, "motas: el triple en el trastero")
ir(Vector3.new(0, -6, 55))
comprobar(motas.Rate == CFG.Motas.Rate * 3, "motas: el triple en el sótano")

-- Fuera, lejos del pino y de la luna.
ir(Vector3.new(60, 5, 230))
comprobar(motas.Rate == 0, "fuera: sin motas")
comprobar(niebla.Rate > 0, "fuera de noche: niebla")
comprobar(math.abs(carpeta.AireNiebla.Position.Y - CFG.Niebla.Alto / 2) < 0.2, "niebla: a ras de suelo")
comprobar(not haz().Enabled, "haz: lejos, apagado")
comprobar(pinocha.Rate == 0, "pinocha: sin pino cerca, nada")

-- Bajo el pino: cae en alguna racha y nunca sin ella.
local conRacha, sinRacha, alguna = 0, 0, false
for _ = 1, 400 do
	camara.CFrame = CFrame.new(155, 5, 150)
	m.correr(0.5, 0.1)
	local _, _, racha = Aire.viento()
	if pinocha.Rate > 0 then
		alguna = true
		comprobar(racha > CFG.Pinocha.Racha - 0.05, "pinocha: solo en las rachas")
		conRacha += 1
	else
		sinRacha += 1
	end
end
comprobar(alguna and sinRacha > 0, `pinocha: a rachas ({conRacha} con, {sinRacha} sin)`)

-- De día: ni niebla ni haz.
fase("Dia", 0.3)
ir(Vector3.new(60, 5, 230))
comprobar(niebla.Rate == 0, "de día: sin niebla")
ir(Vector3.new(0, 6, -10))
comprobar(not haz().Enabled, "de día: sin haz")
comprobar(motas.Rate == CFG.Motas.Rate, "de día: motas dentro igual")
fase("Noche", 0.5)

-- Rendimiento: motas a 0,3, sin haz, niebla ni pinocha.
jugador:SetAttribute("Rendimiento", true)
ir(Vector3.new(0, 6, -10))
cerca(motas.Rate, CFG.Motas.Rate * CFG.Rendimiento, "rendimiento: motas a 0,3")
comprobar(not haz().Enabled, "rendimiento: sin haz")
ir(Vector3.new(60, 5, 230))
comprobar(niebla.Rate == 0 and pinocha.Rate == 0, "rendimiento: sin niebla ni pinocha")
jugador:SetAttribute("Rendimiento", nil)

-- Cinemática (Scriptable sin vistazo): nada.
jugador:SetAttribute("Vistazo", nil)
ir(Vector3.new(0, 6, -10))
comprobar(motas.Rate == 0 and not haz().Enabled, "cinemática: sin motas ni haz")
ir(Vector3.new(60, 5, 230))
comprobar(niebla.Rate == 0, "cinemática: sin niebla")
camara.CameraType = Enum.CameraType.Custom
ir(Vector3.new(0, 6, -10))
comprobar(motas.Rate == CFG.Motas.Rate and haz().Enabled, "al acabar la cinemática, vuelve")

-- La luna se va (mapa nuevo): su haz se borra.
local cajaHaz = Aire.estado.haces[luna].caja
luna:Destroy()
ir(Vector3.new(0, 6, -10))
comprobar(Aire.estado.haces[luna] == nil and cajaHaz.Parent == nil, "luna borrada: su haz también")

print(`aire: bien ({cuentas} comprobaciones)`)
