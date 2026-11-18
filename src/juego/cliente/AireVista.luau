-- Aire vivo (docs/sistemas/aire.md): la capa de aire que está siempre, solo en el cliente y solo de adorno.
--   Polvo dentro de la casa: motas muy flojas en una caja delante de la cámara, con LightInfluence 1: a oscuras no se
--     ven y brillan donde da la luz (el haz de la linterna se llena de polvo al barrer una sala, alrededor de las
--     bombillas encendidas se ve la neblina). En las salas de Config.Aire.Salas (desván, sótano, trastero...), más.
--     Lo que levantan los golpes (Efectos.moverPolvoAire) es otra caja y se suma encima.
--   Haces de luna: cada luz de luna de una ventana (Mapa.luzLuna, etiqueta "Luna") tiene de noche un Beam azulado casi
--     transparente de la ventana al suelo, con sus propias motas que brillan dentro (como un rayo de luz en una
--     iglesia). Con las cortinas de esa ventana echadas, no. Con el cielo cerrado de tormenta (AireVista.nublado, lo pone
--     CieloVista) casi no se ven: Config.Cielo.Tormenta.Haz.
--   Niebla baja fuera, de noche: partículas grandes y planas a ras de suelo alrededor de la cámara que se arrastran
--     despacio hacia donde sopla el viento (AireVista.viento: rumbo y rachas, el mismo para todos los clientes). Con
--     tormenta, más deprisa (AireVista.empuje).
--   Pinocha: bajo los pinos (etiqueta "Pino" de Mapa), en las rachas, cae algo de pinocha (con tormenta, más a menudo
--     y más de lado). Las mismas rachas suben y bajan el viento que se oye (Ambiente.vientoSonido).
-- Nada en cinemáticas (cámara Scriptable salvo un vistazo por la mirilla o las cortinas). Con Rendimiento, las motas a
-- Config.Aire.Rendimiento y sin haces, niebla ni pinocha. Un solo Heartbeat que repasa cada Config.Aire.Cada segundos y
-- solo trabaja con lo que pide el sitio de la cámara. Las partículas nacen en el mundo (no van pegadas a la caja): la
-- caja se mueve a saltos y no se nota.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local AireVista = {}

local CFG = Config.Aire
local TEXTURA = "rbxasset://textures/particles/smoke_main.dds"
local AZUL_LUNA = Color3.fromRGB(120, 140, 190) -- el de Mapa.luzLuna
local CELDA = 32 -- studs de cada celda de la rejilla de pinos

local jugador = Players.LocalPlayer

-- Cielo cerrado de tormenta (CieloVista, cielo.md): de 0 a 1, en rampa. Apaga los haces de luna hasta su parte.
AireVista.nublado = 0

---------------------------------------------------------------- cuentas (sin Roblox: las usa el banco)

-- Cuánto de noche (0 a 1) según la fase y lo que lleva de ella: las mismas rampas que Ambiente (atardecer al final del
-- día, amanecer al final de la noche).
function AireVista.noche(fase: string?, p: number): number
	if fase == "Dia" then
		return math.clamp((p - 0.8) / 0.2, 0, 1)
	elseif fase == "Noche" then
		return 1 - math.clamp((p - 0.9) / 0.1, 0, 1)
	end
	return 0
end

local function enCaja(p: Vector3, x1: number, x2: number, z1: number, z2: number): boolean
	return p.X > x1 and p.X < x2 and p.Z > z1 and p.Z < z2
end

-- ¿Dentro de la casa (o de una sala de Config.Aire.Salas)? Y cuánto se multiplican las motas ahí, y el nombre de esa
-- sala (nil en el resto de la casa). La casa, como Efectos.dentroDeCasa (Config.Casa) más sus anexos (torre, mirador,
-- lavadero).
function AireVista.dentro(p: Vector3): (boolean, number, string?)
	for _, s in CFG.Salas do
		if enCaja(p, s.x1, s.x2, s.z1, s.z2) and p.Y > s.y1 and p.Y < s.y2 then
			return true, s.Motas, s.Nombre
		end
	end
	if p.Y >= 28 then
		return false, 0
	end
	if math.abs(p.X) < Config.Casa.MedioX and math.abs(p.Z) < Config.Casa.MedioZ then
		return true, 1
	end
	for _, a in Config.Casa.Anexos do
		if enCaja(p, a[1], a[2], a[3], a[4]) then
			return true, 1
		end
	end
	return false, 0
end

-- El viento en el instante `t` (segundos): hacia dónde sopla (unitario, en el plano xz), su fuerza (studs/s de deriva)
-- y la racha (0 a 1). Ruido lento: el rumbo se desvía poco a poco y las rachas van y vienen.
function AireVista.vientoEn(t: number): (Vector3, number, number)
	local v = CFG.Viento
	local s = t % 100000 -- math.noise pierde precisión con números enormes
	local rumbo = v.Rumbo + v.Giro * 2 * math.noise(s * v.Lento, 0.31, 4.7)
	local racha = math.clamp(0.5 + 1.6 * math.noise(s * v.Rachas, 7.3, 1.9), 0, 1)
	local fuerza = v.Fuerza[1] + (v.Fuerza[2] - v.Fuerza[1]) * racha
	return Vector3.new(math.cos(rumbo), 0, math.sin(rumbo)), fuerza, racha
end

-- Cuánto se ve un haz de luna (0 a 1) con la noche `k` y el cielo cerrado `nublado` (0 a 1): con tormenta, su parte.
function AireVista.fuerzaHaz(k: number, nublado: number): number
	return k * (1 - (1 - Config.Cielo.Tormenta.Haz) * math.clamp(nublado, 0, 1))
end

-- Con el cielo cerrado `nublado` (0 a 1), por cuánto va el viento de abajo (niebla baja y pinocha): en rampa hasta
-- Config.Cielo.Tormenta.Viento, el mismo que las nubes. Y desde qué racha cae la pinocha (con tormenta, más a menudo).
function AireVista.empuje(nublado: number): number
	return 1 + (Config.Cielo.Tormenta.Viento - 1) * math.clamp(nublado, 0, 1)
end

function AireVista.umbralPinocha(nublado: number): number
	local p = CFG.Pinocha
	return p.Racha + (p.RachaTormenta - p.Racha) * math.clamp(nublado, 0, 1)
end

-- Ancho del haz en la ventana y en el suelo, para un haz de `largo` studs.
function AireVista.anchoHaz(largo: number): (number, number)
	local h = CFG.Haz
	return h.Ancho[1], math.clamp(h.Ancho[1] + largo * h.Abre, h.Ancho[1], h.Ancho[2])
end

---------------------------------------------------------------- estado

local carpeta: Folder
local motas: ParticleEmitter
local cajaMotas: Part
local niebla: ParticleEmitter
local cajaNiebla: Part
local pinocha: ParticleEmitter
local cajaPinocha: Part

type Haz = {
	luna: BasePart,
	creado: boolean,
	caja: Part?,
	beam: Beam?,
	emisor: ParticleEmitter?,
	ventana: Instance?,
	encendido: boolean,
	k: number, -- lo que se veía (AireVista.fuerzaHaz) cuando se pintó la transparencia por última vez
}
local haces: { [BasePart]: Haz } = {}
local pinos: { [string]: { [BasePart]: Vector3 } } = {} -- celda → tronco → su sitio en planta
local deDonde: { [BasePart]: string } = {} -- tronco → su celda (para quitarlo)

-- Lo que el banco puede mirar.
AireVista.estado = { haces = haces }

local function poco(): boolean
	return jugador:GetAttribute("Rendimiento") == true
end

-- Cinemática o muerte: cámara Scriptable sin estar mirando por la mirilla o las cortinas (como CorrerVista).
local function cine(camara: Camera): boolean
	return camara.CameraType == Enum.CameraType.Scriptable and jugador:GetAttribute("Vistazo") == nil
end

local function nocheAhora(): number
	local fase = workspace:GetAttribute("Fase")
	local inicio, fin = workspace:GetAttribute("FaseInicio"), workspace:GetAttribute("FaseFin")
	if type(inicio) ~= "number" or type(fin) ~= "number" then
		return 0
	end
	local p = math.clamp((workspace:GetServerTimeNow() - inicio) / math.max(1, fin - inicio), 0, 1)
	return AireVista.noche(fase, p)
end

-- El viento de ahora (para quien lo quiera: cortinas, hojas...). Hacia dónde, fuerza y racha.
function AireVista.viento(): (Vector3, number, number)
	return AireVista.vientoEn(workspace:GetServerTimeNow())
end

local function caja(nombre: string, tam: Vector3): Part
	local p = Instance.new("Part")
	p.Name = nombre
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = tam
	p.CFrame = CFrame.new(0, -500, 0)
	p.Parent = carpeta
	return p
end

-- Un CFrame en `pos` que mira hacia `dir` (como CFrame.lookAt, hecho a mano: el de Lune, en los bancos, sale al revés
-- en z).
local function mirando(pos: Vector3, dir: Vector3): CFrame
	local d = dir.Unit
	local arriba = if math.abs(d.Y) > 0.99 then Vector3.xAxis else Vector3.yAxis
	local x = d:Cross(arriba).Unit
	return CFrame.fromMatrix(pos, x, x:Cross(d), -d)
end

local function secuencia(puntos: { { number } }): NumberSequence
	local l = {}
	for _, q in puntos do
		table.insert(l, NumberSequenceKeypoint.new(q[1], q[2], q[3] or 0))
	end
	return NumberSequence.new(l)
end

local function emisor(padre: Part): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = TEXTURA
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Rate = 0
	e.Parent = padre
	return e
end

---------------------------------------------------------------- polvo de dentro, niebla y pinocha

local function hacerEmisores()
	-- Motas: la misma receta que Efectos.hacerMotas, más flojas y que viven más (es la capa que está siempre).
	local t = CFG.Motas.Caja
	cajaMotas = caja("AireMotas", Vector3.new(t[1], t[2], t[3]))
	motas = emisor(cajaMotas)
	motas.Color = ColorSequence.new(Color3.fromRGB(214, 204, 186))
	motas.LightInfluence = 1
	motas.LightEmission = 0
	motas.Size = secuencia({ { 0, 0.06, 0.025 }, { 1, 0.05, 0.025 } })
	motas.Transparency = secuencia({ { 0, 1 }, { 0.25, 0.5 }, { 0.75, 0.55 }, { 1, 1 } })
	motas.Lifetime = NumberRange.new(5, 8)
	motas.Speed = NumberRange.new(0.03, 0.15)
	motas.SpreadAngle = Vector2.new(180, 180)
	motas.Acceleration = Vector3.new(0, -0.03, 0) -- bajan muy despacio
	motas.Drag = 0.6
	motas.Rotation = NumberRange.new(0, 360)
	motas.RotSpeed = NumberRange.new(-20, 20)

	-- Niebla: grandes, planas (Squash < 0 con FacingCamera: anchas y bajas) y casi transparentes; salen de la cara de
	-- delante de su caja, que mira hacia donde sopla el viento.
	cajaNiebla = caja("AireNiebla", Vector3.new(CFG.Niebla.Radio * 2, CFG.Niebla.Alto, CFG.Niebla.Radio * 2))
	niebla = emisor(cajaNiebla)
	niebla.Color = ColorSequence.new(Color3.fromRGB(86, 96, 118))
	niebla.LightInfluence = 0.5
	niebla.LightEmission = 0
	niebla.Size = secuencia({ { 0, 7, 2 }, { 1, 11, 3 } })
	niebla.Squash = NumberSequence.new(-1.6)
	niebla.Transparency = secuencia({ { 0, 1 }, { 0.3, 0.9 }, { 0.7, 0.92 }, { 1, 1 } })
	niebla.Lifetime = NumberRange.new(12, 18)
	niebla.EmissionDirection = Enum.NormalId.Front
	niebla.SpreadAngle = Vector2.new(12, 2)
	niebla.Rotation = NumberRange.new(-6, 6)
	niebla.RotSpeed = NumberRange.new(-1.5, 1.5)
	niebla.ZOffset = -1 -- que no tape lo que está delante a ras de suelo

	-- Pinocha: finas (Squash > 0: altas y estrechas) y dando vueltas, cayendo despacio de lado con el viento.
	cajaPinocha = caja("AirePinocha", Vector3.new(26, 1, 26))
	pinocha = emisor(cajaPinocha)
	pinocha.Color = ColorSequence.new(Color3.fromRGB(104, 82, 54))
	pinocha.LightInfluence = 1
	pinocha.Size = secuencia({ { 0, 0.22, 0.06 }, { 1, 0.22, 0.06 } })
	pinocha.Squash = NumberSequence.new(2.4)
	pinocha.Transparency = secuencia({ { 0, 1 }, { 0.08, 0.15 }, { 0.85, 0.2 }, { 1, 1 } })
	pinocha.Lifetime = NumberRange.new(6, 8)
	pinocha.EmissionDirection = Enum.NormalId.Bottom
	pinocha.Speed = NumberRange.new(1, 2.5)
	pinocha.SpreadAngle = Vector2.new(25, 25)
	pinocha.Drag = 0.8
	pinocha.Rotation = NumberRange.new(0, 360)
	pinocha.RotSpeed = NumberRange.new(-220, 220)
end

local filtroSuelo = RaycastParams.new()
filtroSuelo.FilterType = Enum.RaycastFilterType.Exclude

-- Lo que no es suelo ni pared: lo nuestro, los personajes y los bichos (como mucho cada 2 s: llegan y se van poco).
local filtroPuesto = -math.huge
local function ponerFiltro()
	if os.clock() - filtroPuesto < 2 then
		return
	end
	filtroPuesto = os.clock()
	local fuera: { Instance } = { carpeta }
	for _, otro in Players:GetPlayers() do
		if otro.Character then
			table.insert(fuera, otro.Character)
		end
	end
	local bichos = workspace:FindFirstChild("Bichos")
	if bichos then
		table.insert(fuera, bichos)
	end
	filtroSuelo.FilterDescendantsInstances = fuera
end

local function sueloBajo(p: Vector3): number
	local r = workspace:Raycast(p, Vector3.new(0, -40, 0), filtroSuelo)
	return if r then r.Position.Y else p.Y - 5
end

-- ¿Hay un pino a menos de Pinocha.Cerca (en planta)? Mira las celdas de alrededor.
local function pinoCerca(p: Vector3): boolean
	local cx, cz = math.floor(p.X / CELDA), math.floor(p.Z / CELDA)
	local cerca2 = CFG.Pinocha.Cerca * CFG.Pinocha.Cerca
	for dx = -1, 1 do
		for dz = -1, 1 do
			local celda = pinos[(cx + dx) .. "," .. (cz + dz)]
			if celda then
				for _, q in celda do
					local x, z = q.X - p.X, q.Z - p.Z
					if x * x + z * z < cerca2 then
						return true
					end
				end
			end
		end
	end
	return false
end

local function apuntarPino(t: Instance)
	if t:IsA("BasePart") and not deDonde[t] then
		local q = t.Position
		local clave = math.floor(q.X / CELDA) .. "," .. math.floor(q.Z / CELDA)
		pinos[clave] = pinos[clave] or {}
		pinos[clave][t] = Vector3.new(q.X, 0, q.Z)
		deDonde[t] = clave
	end
end

local function quitarPino(t: Instance)
	local clave = deDonde[t :: BasePart]
	if clave then
		deDonde[t :: BasePart] = nil
		local celda = pinos[clave]
		if celda then
			celda[t :: BasePart] = nil
		end
	end
end

---------------------------------------------------------------- haces de luna

-- La ventana más cerca de la luz (por su atributo Centro), para apagar el haz con las cortinas echadas.
local function ventanaDe(luna: BasePart): Instance?
	local mejor, cerca = nil, CFG.Haz.Ventana
	for _, v in CollectionService:GetTagged("Ventana") do
		local c = v:GetAttribute("Centro")
		if typeof(c) == "CFrame" then
			local d = (c.Position - luna.Position).Magnitude
			if d < cerca then
				mejor, cerca = v, d
			end
		end
	end
	return mejor
end

-- Se hace la primera vez que hace falta (el mapa ya está): un rayo de la ventana hacia donde mira la luz busca el suelo.
local function crearHaz(h: Haz)
	h.creado = true
	local luna = h.luna
	local luz = luna:FindFirstChildWhichIsA("SpotLight")
	local alcance = if luz then luz.Range else 25
	local desde, mira = luna.Position, luna.CFrame.LookVector
	ponerFiltro()
	-- Solo vale una cara que mire hacia arriba (suelo, cama, mesa): las cortinas, el marco o una pared de paso, se
	-- atraviesan (unas pocas veces como mucho).
	local largo = alcance * 0.7
	local hecho = 0
	for _ = 1, 6 do
		local r = workspace:Raycast(desde + mira * hecho, mira * (alcance - hecho), filtroSuelo)
		if not r then
			break
		end
		hecho += r.Distance + 0.05
		if r.Normal.Y > 0.5 then
			largo = hecho - 0.05
			break
		end
	end
	if largo < 1.5 then
		return
	end
	local a1, a2 = AireVista.anchoHaz(largo)
	local c = caja("HazLuna", Vector3.new((a1 + a2) / 2 * 0.8, (a1 + a2) / 2 * 0.8, largo))
	c.CFrame = mirando(desde + mira * (largo / 2), mira)
	local p0 = Instance.new("Attachment")
	p0.CFrame = CFrame.new(0, 0, largo / 2)
	p0.Parent = c
	local p1 = Instance.new("Attachment")
	p1.CFrame = CFrame.new(0, 0, -largo / 2)
	p1.Parent = c
	local b = Instance.new("Beam")
	b.Attachment0 = p0
	b.Attachment1 = p1
	b.Width0, b.Width1 = a1, a2
	b.FaceCamera = true
	b.Segments = 1
	b.Color = ColorSequence.new(AZUL_LUNA)
	b.LightEmission = 0.4
	b.LightInfluence = 0
	b.Brightness = 1
	-- Una bocanada de humo estirada: bordes suaves a lo ancho y a lo largo; se mueve muy despacio (el aire).
	b.Texture = TEXTURA
	b.TextureMode = Enum.TextureMode.Stretch
	b.TextureLength = 1
	b.TextureSpeed = 0.02
	b.Enabled = false
	b.Parent = c
	local e = emisor(c)
	e.Color = ColorSequence.new(Color3.fromRGB(180, 196, 232))
	e.LightInfluence = 0
	e.LightEmission = 0.5
	e.Size = secuencia({ { 0, 0.05, 0.02 }, { 1, 0.05, 0.02 } })
	e.Transparency = secuencia({ { 0, 1 }, { 0.3, 0.35 }, { 0.7, 0.45 }, { 1, 1 } })
	e.Lifetime = NumberRange.new(4, 7)
	e.Speed = NumberRange.new(0.02, 0.12)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -0.02, 0)
	e.Drag = 0.6
	e.Rotation = NumberRange.new(0, 360)
	h.caja, h.beam, h.emisor = c, b, e
	h.ventana = ventanaDe(luna)
end

local function apuntarLuna(luna: Instance)
	if luna:IsA("BasePart") and not haces[luna] then
		haces[luna] = { luna = luna, creado = false, encendido = false, k = -1 }
	end
end

local function quitarLuna(luna: Instance)
	local h = haces[luna :: BasePart]
	if h then
		haces[luna :: BasePart] = nil
		if h.caja then
			h.caja:Destroy()
		end
	end
end

local function tapada(h: Haz): boolean
	local v = h.ventana
	return v ~= nil and v.Parent ~= nil and v:GetAttribute("Persiana") == true and (v:GetAttribute("Vida") or 1) > 0
end

local function moverHaces(camara: Vector3, k: number, vale: boolean)
	local cerca2 = CFG.Haz.Cerca * CFG.Haz.Cerca
	local fuerza = AireVista.fuerzaHaz(k, AireVista.nublado)
	for luna, h in haces do
		if not luna.Parent then
			quitarLuna(luna)
			continue
		end
		local d = luna.Position - camara
		local on = vale and k > 0.02 and d:Dot(d) < cerca2
		if on and not h.creado then
			crearHaz(h)
		end
		on = on and h.beam ~= nil and not tapada(h)
		if h.beam and h.emisor then
			if on and (not h.encendido or math.abs(h.k - fuerza) > 0.01) then
				h.k = fuerza
				local t = 1 - (1 - CFG.Haz.Transparencia) * fuerza
				-- Más transparente en los dos extremos: no se ve dónde empieza ni dónde acaba.
				h.beam.Transparency = secuencia({ { 0, 1 }, { 0.15, t }, { 0.8, t }, { 1, 1 } })
				h.emisor.Rate = CFG.Haz.Motas * fuerza
			end
			if on ~= h.encendido then
				h.beam.Enabled = on
				if not on then
					h.emisor.Rate = 0
				end
			end
		end
		h.encendido = on
	end
end

---------------------------------------------------------------- el repaso

local function repasar()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local vista = cam.CFrame
	local p = vista.Position
	local vale = not cine(cam)
	local ligero = poco()
	local k = nocheAhora()
	local dentro, cuanto = AireVista.dentro(p)
	local hacia, fuerza, racha = AireVista.viento()
	local empuje = AireVista.empuje(AireVista.nublado) -- con tormenta, la niebla y la pinocha van más deprisa

	-- Polvo de dentro.
	if vale and dentro then
		cajaMotas.CFrame = vista * CFrame.new(0, -0.3, -CFG.Motas.Delante)
		motas.Rate = CFG.Motas.Rate * cuanto * (if ligero then CFG.Rendimiento else 1)
	else
		motas.Rate = 0
	end

	-- Haces de luna (de noche, sin Rendimiento).
	moverHaces(p, k, vale and not ligero)

	-- Niebla baja (fuera, de noche, sin Rendimiento).
	if vale and not dentro and not ligero and k > 0.02 then
		ponerFiltro()
		local suelo = sueloBajo(p)
		local centro = Vector3.new(p.X, suelo + CFG.Niebla.Alto / 2, p.Z)
		cajaNiebla.CFrame = mirando(centro, hacia)
		local v = CFG.Niebla.Velocidad
		niebla.Speed = NumberRange.new(v[1] * fuerza * empuje, v[2] * fuerza * empuje)
		niebla.Rate = CFG.Niebla.Rate * k
	else
		niebla.Rate = 0
	end

	-- Pinocha (fuera, en las rachas y bajo un pino, sin Rendimiento).
	local umbral = AireVista.umbralPinocha(AireVista.nublado)
	if vale and not dentro and not ligero and racha > umbral and pinoCerca(p) then
		cajaPinocha.CFrame = CFrame.new(p + Vector3.new(0, CFG.Pinocha.Alto, 0))
		pinocha.Acceleration = hacia * (fuerza * 1.5 * empuje) + Vector3.new(0, -1.2, 0)
		pinocha.Rate = CFG.Pinocha.Rate * (racha - umbral) / (1 - umbral)
	else
		pinocha.Rate = 0
	end
end

function AireVista.start()
	carpeta = Instance.new("Folder")
	carpeta.Name = "AireLocal"
	carpeta.Parent = workspace
	hacerEmisores()

	CollectionService:GetInstanceAddedSignal("Luna"):Connect(apuntarLuna)
	CollectionService:GetInstanceRemovedSignal("Luna"):Connect(quitarLuna)
	for _, luna in CollectionService:GetTagged("Luna") do
		apuntarLuna(luna)
	end
	CollectionService:GetInstanceAddedSignal("Pino"):Connect(apuntarPino)
	CollectionService:GetInstanceRemovedSignal("Pino"):Connect(quitarPino)
	for _, t in CollectionService:GetTagged("Pino") do
		apuntarPino(t)
	end

	local espera = 0
	RunService.Heartbeat:Connect(function(dt)
		espera -= dt
		if espera > 0 then
			return
		end
		espera = CFG.Cada
		repasar()
	end)
end

return AireVista
