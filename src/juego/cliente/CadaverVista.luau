-- Cuerpos que caen de verdad: el compañero muerto se queda tirado (docs/sistemas/cadaver.md).
-- Solo adorno del cliente: cada uno hace su muñeco con lo que ve. El servidor (Muerte) solo deja el personaje entero al
-- morir (BreakJointsOnDeath = false) para que aquí se pueda copiar.
--   Al morir alguien (remote Muerte, con dónde está la cabeza del bicho): el personaje de verdad se esconde
--   (LocalTransparencyModifier, sin chocar) y en su sitio sale un muñeco de trapo, una copia del avatar con su ropa en
--   la que cada Motor6D pasa a ser un BallSocketConstraint con límites de giro (cuello, hombros, codos, cintura,
--   cadera, rodillas...). Sale despedido hacia el lado contrario del bicho, da contra el suelo o una pared, se dobla y,
--   quieto o a los Config.Cadaver.Anclar s (con Rendimiento, AnclarRendimiento), se anclan todas sus piezas: ya no cuesta
--   nada y no estorba al andar (sin chocar).
--   El charco de MuerteVista (etiqueta Charco) se queda escondido mientras el muñeco vuela y, cuando se para, se pone
--   bajo su pecho y crece despacio de pequeño a su tamaño (Charco.Crece s).
--   Si llevaba la linterna encendida, la linterna cae, rueda un poco y se queda en el suelo alumbrando a un lado, con el
--   haz parpadeando, hasta que se apaga a los Linterna.Dura s. Con Rendimiento no rueda (cae ya quieta y sin sombras).
--   Desde lejos se oye el grito en 3D (Sonido.en: lo tapan las paredes con Oído) y el golpe del cuerpo contra el suelo.
--   El muñeco se borra cuando revive (CharacterAdded nuevo: al amanecer o pagando con Revivir) o se va.
--   Tope: Config.Cadaver.Tope muñecos moviéndose a la vez; con uno más, el más viejo se ancla tal como está.
--   Tu propia muerte: el muñeco no sale hasta que acaba el susto (la cámara deja de ser de script), para no taparlo, y
--   cae sin apenas empuje desde donde quedó el cuerpo.
--   Muertes sin remote (otras causas): a los SinAviso s del Died, el muñeco cae donde está, sin empuje.
-- Un solo Heartbeat que solo corre mientras algo se mueve (muñecos sin anclar, linternas encendidas, tu muñeco
-- pendiente) y se desconecta después.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sonido = require(script.Parent.Sonido)

local CadaverVista = {}

local CFG = Config.Cadaver
local jugador = Players.LocalPlayer
local azar = Random.new()

---------------------------------------------------------------- cuentas (sin Roblox: el banco las mira)

-- Hacia dónde sale despedido: en horizontal, del bicho hacia el cuerpo. Sin bicho (o encima), hacia atrás del cuerpo.
function CadaverVista.empuje(cuerpo: Vector3, cabeza: Vector3?, mira: Vector3): Vector3
	if cabeza then
		local d = Vector3.new(cuerpo.X - cabeza.X, 0, cuerpo.Z - cabeza.Z)
		if d.Magnitude > 0.05 then
			return d.Unit
		end
	end
	local atras = Vector3.new(-mira.X, 0, -mira.Z)
	return if atras.Magnitude > 0.05 then atras.Unit else Vector3.xAxis
end

-- Los límites de cada junta por su nombre (R15 y R6): { cono, giro } en grados. nil: la de la raíz (se quita).
local JUNTAS = {
	{ "neck", "Cuello" },
	{ "waist", "Cintura" },
	{ "shoulder", "Hombro" },
	{ "elbow", "Codo" },
	{ "wrist", "Muneca" },
	{ "hip", "Cadera" },
	{ "knee", "Rodilla" },
	{ "ankle", "Tobillo" },
}
function CadaverVista.junta(nombre: string): { number }?
	local n = string.lower(nombre)
	if string.find(n, "root", 1, true) then
		return nil
	end
	for _, par in JUNTAS do
		if string.find(n, par[1], 1, true) then
			return CFG.Juntas[par[2]]
		end
	end
	return CFG.Juntas.Otra
end

-- Diámetro del charco a los `t` s de ponerlo: de Charco.Desde a `final` en Charco.Crece s, despacio al final.
function CadaverVista.charcoTam(t: number, final: number): number
	local k = math.clamp(t / CFG.Charco.Crece, 0, 1)
	k = 1 - (1 - k) ^ 2
	return CFG.Charco.Desde + (final - CFG.Charco.Desde) * k
end

-- Brillo (de 0 a 1) de la linterna caída a los `t` s; `ruido` de -1 a 1 (math.noise por dos). Parpadea a tirones, más
-- cuanto más se apaga (los últimos Linterna.Apaga s baja), y a los Linterna.Dura s, 0.
function CadaverVista.brillo(t: number, ruido: number): number
	local L = CFG.Linterna
	if t >= L.Dura then
		return 0
	end
	local base = math.clamp((L.Dura - t) / L.Apaga, 0, 1)
	local umbral = L.Corte + (1 - base) * 0.6
	if ruido < umbral then
		return base * 0.06
	end
	return math.clamp(base * (0.8 + 0.2 * ruido), 0, 1)
end

-- Segundos como mucho que se mueve un muñeco antes de anclarse.
function CadaverVista.anclarEn(rendimiento: boolean): number
	return if rendimiento then CFG.AnclarRendimiento else CFG.Anclar
end

---------------------------------------------------------------- en el mundo

type Linterna = { parte: BasePart, luz: SpotLight, nace: number, anclada: boolean, apagada: boolean, semilla: number }
type Cuerpo = {
	quien: Player,
	real: Model,
	modelo: Model,
	torso: BasePart,
	partes: { BasePart },
	inicio: Vector3,
	nace: number,
	limite: number,
	anclado: boolean,
	quietoDesde: number?,
	vel: number,
	golpes: number,
	propio: boolean,
	charco: BasePart?,
	charcoTransparencia: number,
	charcoPuesto: boolean,
	linterna: Linterna?,
	conexiones: { RBXScriptConnection },
}
type Pendiente = { personaje: Model, cabeza: Vector3?, linterna: boolean, color: Color3, desde: number }

local carpeta: Folder
local cuerpos: { Cuerpo } = {} -- por orden de llegada
local linternas: { Linterna } = {}
local pendiente: Pendiente? = nil -- tu muñeco, esperando a que acabe el susto
local bucle: RBXScriptConnection? = nil
local rayo = RaycastParams.new()
rayo.FilterType = Enum.RaycastFilterType.Exclude
rayo.IgnoreWater = true

-- Color de la luz: el cosmético que llevaba puesto (como EquipoVista).
local COLOR_LUZ = Color3.fromRGB(255, 236, 205)
local COLORES: { [string]: Color3 } = {}
for _, cosa in Config.Cosmeticos do
	if cosa.Tipo == "Linterna" then
		COLORES[cosa.Id] = Color3.fromRGB(table.unpack(cosa.Color))
	end
end
local function colorDe(otro: Player): Color3
	return COLORES[otro:GetAttribute("PuestoLinterna")] or COLOR_LUZ
end

local function poco(): boolean
	return jugador:GetAttribute("Rendimiento") == true
end

-- Lo que la copia no se lleva: scripts, sonidos, luces (la de la linterna de EquipoVista), carteles, herramientas,
-- animaciones y fuerzas.
local QUITAR = {
	Script = true, LocalScript = true, ModuleScript = true, Sound = true, SpotLight = true, PointLight = true,
	SurfaceLight = true, BillboardGui = true, ProximityPrompt = true, ForceField = true, Animator = true,
	Tool = true, Highlight = true, BodyVelocity = true, BodyGyro = true, BodyPosition = true, BodyForce = true,
	BodyAngularVelocity = true, AlignPosition = true, AlignOrientation = true, LinearVelocity = true,
	AngularVelocity = true, VectorForce = true, RopeConstraint = true, SpringConstraint = true,
	HingeConstraint = true, BallSocketConstraint = true, NoCollisionConstraint = true, RigidConstraint = true,
}

local function rehacerRayo()
	local fuera: { Instance } = { carpeta }
	for _, j in Players:GetPlayers() do
		if j.Character then
			table.insert(fuera, j.Character)
		end
	end
	local bichos = workspace:FindFirstChild("Bichos")
	if bichos then
		table.insert(fuera, bichos)
	end
	rayo.FilterDescendantsInstances = fuera
end

local function suelo(desde: Vector3, ignorar: Instance?): Vector3?
	rehacerRayo()
	if ignorar then
		rayo:AddToFilter(ignorar)
	end
	local r = workspace:Raycast(desde + Vector3.new(0, 1, 0), Vector3.new(0, -9, 0), rayo)
	return r and r.Position
end

local function sonar(nombre: string, provisional: string?, donde: Vector3, tono: number?, volumen: number?)
	local s: Sound? = nil
	if Sonido.hay(nombre) then
		s = Sonido.en(nombre, donde)
	elseif provisional then
		s = Sonido.en(provisional, donde, tono)
	end
	if s and volumen then
		s.Volume *= volumen
	end
end

-- Esconde el personaje de verdad (y que no choque con el muñeco). El tuyo, además, anclado: es tuyo (la física la
-- llevas tú) y sin chocar se caería por el suelo. Tu cámara se lo vuelve a enseñar al cambiar de sujeto: se repite.
local function esconderReal(real: Model, propio: boolean, conexiones: { RBXScriptConnection })
	for _, d in real:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = 1
			if propio and d.Name == "HumanoidRootPart" then
				d.Anchored = true
			end
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			if propio then
				table.insert(conexiones, d:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(function()
					if d.LocalTransparencyModifier < 1 then
						d.LocalTransparencyModifier = 1
					end
				end))
			end
		elseif d:IsA("Decal") then
			d.LocalTransparencyModifier = 1
		elseif d:IsA("Humanoid") then
			d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end
end

-- La copia con su ropa: cada Motor6D pasa a ser una rótula con límites, centrada en la junta y con el eje a lo largo del
-- hueso (del sitio de la junta hacia el centro de la pieza de abajo), así la pose de ahora es la de reposo.
local function rotulas(copia: Model)
	for _, m in copia:GetDescendants() do
		if not m:IsA("Motor6D") then
			continue
		end
		local p0, p1 = m.Part0, m.Part1
		local lim = CadaverVista.junta(m.Name)
		if not p0 or not p1 or not lim or p0.Name == "HumanoidRootPart" or p1.Name == "HumanoidRootPart" then
			m:Destroy()
			continue
		end
		local donde = (p1.CFrame * m.C1).Position
		local eje = p1.Position - donde
		eje = if eje.Magnitude > 0.05 then eje.Unit else -p1.CFrame.UpVector
		local arriba = p1.CFrame.LookVector
		if math.abs(eje:Dot(arriba)) > 0.95 then
			arriba = p1.CFrame.RightVector
		end
		arriba = (arriba - eje * eje:Dot(arriba)).Unit
		local mundo = CFrame.fromMatrix(donde, eje, arriba)
		local a0 = Instance.new("Attachment")
		a0.Name = "Cadaver0"
		a0.CFrame = p0.CFrame:ToObjectSpace(mundo)
		a0.Parent = p0
		local a1 = Instance.new("Attachment")
		a1.Name = "Cadaver1"
		a1.CFrame = p1.CFrame:ToObjectSpace(mundo)
		a1.Parent = p1
		local bs = Instance.new("BallSocketConstraint")
		bs.Name = "Cadaver" .. m.Name
		bs.Attachment0 = a0
		bs.Attachment1 = a1
		bs.LimitsEnabled = true
		bs.UpperAngle = lim[1]
		bs.TwistLimitsEnabled = true
		bs.TwistLowerAngle = -lim[2]
		bs.TwistUpperAngle = lim[2]
		bs.MaxFrictionTorque = CFG.Friccion
		bs.Parent = p1
		local nc = Instance.new("NoCollisionConstraint")
		nc.Part0 = p0
		nc.Part1 = p1
		nc.Parent = p1
		m:Destroy()
	end
end

local function copiar(real: Model): Model?
	local antes = real.Archivable
	real.Archivable = true
	local ok, copia = pcall(real.Clone, real)
	real.Archivable = antes
	if not ok or not copia then
		return nil
	end
	local quitar = {}
	for _, d in copia:GetDescendants() do
		if QUITAR[d.ClassName] then
			table.insert(quitar, d)
		end
		for _, etiqueta in d:GetTags() do
			d:RemoveTag(etiqueta) -- que ningún sistema lo tome por algo suyo
		end
	end
	for _, etiqueta in copia:GetTags() do
		copia:RemoveTag(etiqueta)
	end
	for _, d in quitar do
		d:Destroy()
	end
	local hum = copia:FindFirstChildOfClass("Humanoid") -- se queda: sin él no se ve la ropa
	if hum then
		hum.EvaluateStateMachine = false
		hum.BreakJointsOnDeath = false
		hum.RequiresNeck = false
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	rotulas(copia)
	local raiz = copia:FindFirstChild("HumanoidRootPart")
	if raiz then
		raiz:Destroy()
	end
	copia.Name = "Cadaver"
	return copia
end

local function encender()
	if bucle then
		return
	end
	local paso: (number) -> ()
	paso = function(_dt)
		local ahora = os.clock()
		local algo = pendiente ~= nil
		for _, c in cuerpos do
			if not c.anclado then
				algo = true
			end
		end
		for _, l in linternas do
			if not l.apagada then
				algo = true
			end
		end
		if not algo and bucle then
			bucle:Disconnect()
			bucle = nil
			return
		end
		CadaverVista._paso(ahora)
	end
	bucle = RunService.Heartbeat:Connect(paso)
end

local function ponerCharco(c: Cuerpo)
	local charco = c.charco
	if not charco or c.charcoPuesto or not charco.Parent then
		return
	end
	c.charcoPuesto = true
	local pos = suelo(c.torso.Position, charco) or charco.Position
	charco.CFrame = CFrame.new(pos + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	charco.Transparency = c.charcoTransparencia
	local final = azar:NextNumber(CFG.Charco.Tam[1], CFG.Charco.Tam[2])
	charco.Size = Vector3.new(0.05, CFG.Charco.Desde, CFG.Charco.Desde)
	TweenService:Create(charco, TweenInfo.new(CFG.Charco.Crece, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.05, final, final) }):Play()
end

local function anclar(c: Cuerpo)
	if c.anclado then
		return
	end
	c.anclado = true
	for _, p in c.partes do
		if p.Parent then
			p.AssemblyLinearVelocity = Vector3.zero
			p.AssemblyAngularVelocity = Vector3.zero
			p.Anchored = true
			p.CanCollide = false -- tirado en un pasillo no te corta el paso
			p.CanTouch = false
			p.CanQuery = false
		end
	end
	ponerCharco(c)
end

-- El charco de MuerteVista, si es de un cuerpo que acaba de caer: se esconde hasta que el muñeco se pare.
local function adoptar(charco: Instance)
	if not charco:IsA("BasePart") or charco:GetAttribute("Cadaver") then
		return
	end
	for _, c in cuerpos do
		local d = charco.Position - c.inicio
		if not c.charco and not c.propio and Vector3.new(d.X, 0, d.Z).Magnitude <= CFG.Charco.Cerca
			and math.abs(d.Y) < 10 and os.clock() - c.nace < CFG.Charco.Espera then
			charco:SetAttribute("Cadaver", true)
			c.charco = charco
			c.charcoTransparencia = charco.Transparency
			-- Un tween nuevo manda sobre el de MuerteVista (el más nuevo gana): pequeño y escondido.
			TweenService:Create(charco, TweenInfo.new(0.01), { Size = Vector3.new(0.05, 0.05, 0.05) }):Play()
			charco.Transparency = 1
			if c.anclado then
				ponerCharco(c)
			end
			return
		end
	end
end

local function soltarLinterna(c: Cuerpo, donde: Vector3, dir: Vector3, color: Color3, quieta: boolean)
	local L = CFG.Linterna
	local p = Instance.new("Part")
	p.Name = "LinternaCaida"
	p.Shape = Enum.PartType.Cylinder -- el eje es X: la luz sale por la cara de la derecha
	p.Size = Vector3.new(0.9, 0.3, 0.3)
	p.Color = Color3.fromRGB(38, 38, 40)
	p.Material = Enum.Material.Metal
	p.CanTouch = false
	local luz = Instance.new("SpotLight")
	luz.Face = Enum.NormalId.Right
	luz.Color = color
	luz.Range = L.Rango
	luz.Angle = L.Angulo
	luz.Brightness = L.Brillo
	luz.Shadows = not quieta
	luz.Parent = p
	local giro = CFrame.Angles(0, azar:NextNumber(0, math.pi * 2), 0)
	local l: Linterna = { parte = p, luz = luz, nace = os.clock(), anclada = quieta, apagada = false,
		semilla = azar:NextNumber(0, 100) }
	if quieta then
		-- Con Rendimiento: ya en el suelo, quieta.
		local pos = suelo(donde, c.modelo) or donde
		p.CFrame = CFrame.new(pos + Vector3.new(0, 0.15, 0)) * giro
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
	else
		p.CFrame = CFrame.new(donde) * giro
		p.Anchored = false
		p.CanCollide = true
		local lado = Vector3.new(-dir.Z, 0, dir.X) * azar:NextNumber(-3, 3)
		p.AssemblyLinearVelocity = dir * L.Empuje + lado + Vector3.new(0, 4, 0)
		p.AssemblyAngularVelocity = p.CFrame.RightVector * azar:NextNumber(-8, 8) + Vector3.yAxis * azar:NextNumber(-3, 3)
		task.delay(0.35, function()
			if p.Parent then
				sonar("LinternaCae", nil, p.Position)
			end
		end)
	end
	p.Parent = carpeta
	c.linterna = l
	table.insert(linternas, l)
end

local function quitarLinterna(l: Linterna)
	local i = table.find(linternas, l)
	if i then
		table.remove(linternas, i)
	end
	l.parte:Destroy()
end

local function quitar(c: Cuerpo)
	local i = table.find(cuerpos, c)
	if i then
		table.remove(cuerpos, i)
	end
	for _, con in c.conexiones do
		con:Disconnect()
	end
	c.modelo:Destroy()
	if c.linterna then
		quitarLinterna(c.linterna)
	end
end

local function cuerpoDe(quien: Player, real: Model): Cuerpo?
	for _, c in cuerpos do
		if c.quien == quien and c.real == real then
			return c
		end
	end
	return nil
end

-- El muñeco de `quien`. `cabeza`: la del bicho (de ella sale despedido); `fuerza`: cuánto del empuje (0 a 1).
local function crear(quien: Player, cabeza: Vector3?, conLinterna: boolean, color: Color3, fuerza: number)
	local real = quien.Character
	local torsoReal = real and (real:FindFirstChild("UpperTorso") or real:FindFirstChild("Torso"))
	if not real or not torsoReal or not torsoReal:IsA("BasePart") or cuerpoDe(quien, real) then
		return
	end
	for _, c in table.clone(cuerpos) do
		if c.quien == quien then
			quitar(c) -- uno viejo suyo (no debería quedar)
		end
	end
	local copia = copiar(real)
	if not copia then
		return
	end
	local torso = copia:FindFirstChild(torsoReal.Name)
	if not torso or not torso:IsA("BasePart") then
		copia:Destroy()
		return
	end
	local partes: { BasePart } = {}
	for _, d in copia:GetDescendants() do
		if d:IsA("BasePart") then
			local adorno = d:FindFirstAncestorWhichIsA("Accessory") ~= nil
			d.Anchored = false
			d.CanTouch = false
			d.LocalTransparencyModifier = 0
			d.CanCollide = not adorno -- sombreros y pelo van soldados: no chocan ni pesan
			if adorno then
				d.Massless = true
				d.CanQuery = false
			end
			table.insert(partes, d)
		end
	end
	local propio = quien == jugador
	local conexiones: { RBXScriptConnection } = {}
	esconderReal(real, propio, conexiones)
	copia.Parent = carpeta
	local rendimiento = poco()
	local c: Cuerpo = {
		quien = quien,
		real = real,
		modelo = copia,
		torso = torso,
		partes = partes,
		inicio = torsoReal.Position,
		nace = os.clock(),
		limite = CadaverVista.anclarEn(rendimiento),
		anclado = false,
		quietoDesde = nil,
		vel = 0,
		golpes = 0,
		propio = propio,
		charco = nil,
		charcoTransparencia = 0,
		charcoPuesto = false,
		linterna = nil,
		conexiones = conexiones,
	}
	table.insert(cuerpos, c)

	-- El empuje: todo el cuerpo a la vez hacia el lado contrario del bicho, el tronco girando hacia atrás.
	local dir = CadaverVista.empuje(torso.Position, cabeza, torso.CFrame.LookVector)
	local vel = (dir * CFG.Empuje + Vector3.new(0, CFG.Salto, 0)) * fuerza
	for _, p in partes do
		p.AssemblyLinearVelocity = vel * (1 + azar:NextNumber(-CFG.Azar, CFG.Azar))
	end
	torso.AssemblyAngularVelocity = Vector3.yAxis:Cross(dir) * CFG.Giro * fuerza

	if not propio then
		sonar("GritoMuerte", "Susto", torso.Position, CFG.TonoGrito, CFG.VolumenGrito)
	end
	if conLinterna then
		local mano = copia:FindFirstChild("LeftHand") or copia:FindFirstChild("Left Arm")
		local desde = if mano and mano:IsA("BasePart") then mano.Position else torso.Position
		soltarLinterna(c, desde, dir, color, rendimiento)
	end
	-- Su charco, si MuerteVista ya lo ha puesto (si no, llega por la etiqueta).
	for _, charco in CollectionService:GetTagged("Charco") do
		adoptar(charco)
	end
	-- El tope: los más viejos que aún se mueven se anclan tal como están.
	local moviendo = {}
	for _, otro in cuerpos do
		if not otro.anclado then
			table.insert(moviendo, otro)
		end
	end
	for n = 1, #moviendo - CFG.Tope do
		anclar(moviendo[n])
	end
	encender()
end

-- Lo de cada fotograma (Heartbeat, solo mientras algo se mueve).
function CadaverVista._paso(ahora: number)
	local p = pendiente
	if p then
		-- Tu muñeco, cuando acaba el susto (la cámara vuelve a ser la de siempre) o, si algo falla, al rato.
		local camara = workspace.CurrentCamera
		local libre = camara and camara.CameraType ~= Enum.CameraType.Scriptable and ahora - p.desde >= CFG.EsperaPropio
		if jugador.Character ~= p.personaje then
			pendiente = nil
		elseif libre or ahora - p.desde >= CFG.EsperaPropioMax then
			pendiente = nil
			crear(jugador, p.cabeza, p.linterna, p.color, CFG.FuerzaPropio)
		end
	end
	for _, c in table.clone(cuerpos) do
		if c.anclado then
			continue
		end
		if not c.torso.Parent then
			quitar(c)
			continue
		end
		local t = ahora - c.nace
		local v = c.torso.AssemblyLinearVelocity.Magnitude
		-- El golpe contra el suelo o una pared: frena de golpe.
		if c.vel > CFG.Golpe and v < c.vel * 0.5 and c.golpes < 2 then
			c.golpes += 1
			sonar("CuerpoCae", "Retumbo", c.torso.Position, 1.3, if c.golpes == 1 then 0.6 else 0.3)
		end
		c.vel = v
		if v < CFG.Quieto and t >= CFG.QuietoMin then
			c.quietoDesde = c.quietoDesde or ahora
		else
			c.quietoDesde = nil
		end
		local caido = c.torso.Position.Y < c.inicio.Y - 60 -- se fue por un agujero del mapa
		if t >= c.limite or caido or (c.quietoDesde and ahora - c.quietoDesde >= CFG.QuietoTiempo) then
			anclar(c)
		end
	end
	local camara = workspace.CurrentCamera
	local ojo = if camara then camara.CFrame.Position else Vector3.zero
	local L = CFG.Linterna
	for _, l in table.clone(linternas) do
		if l.apagada then
			continue
		end
		if not l.parte.Parent then
			quitarLinterna(l)
			continue
		end
		local t = ahora - l.nace
		if not l.anclada and t >= L.Rueda then
			l.anclada = true
			l.parte.AssemblyLinearVelocity = Vector3.zero
			l.parte.AssemblyAngularVelocity = Vector3.zero
			l.parte.Anchored = true
			l.parte.CanCollide = false
			l.parte.CanQuery = false
		end
		if t >= L.Dura then
			l.apagada = true
			l.luz.Enabled = false
		elseif (l.parte.Position - ojo).Magnitude <= L.Cerca then -- lejos ni se ve: no se toca
			local ruido = math.clamp(math.noise(t * L.Tirones, l.semilla) * 2, -1, 1)
			l.luz.Brightness = L.Brillo * CadaverVista.brillo(t, ruido)
		end
	end
end

-- Lo que hay ahora (para el banco).
function CadaverVista.cuerpos(): { Cuerpo }
	return cuerpos
end
function CadaverVista.activo(): boolean
	return bucle ~= nil
end

local function alMorir(quien: Player, cabeza: Vector3?)
	if typeof(quien) ~= "Instance" or not quien:IsA("Player") then
		return
	end
	local cab = if typeof(cabeza) == "Vector3" then cabeza else nil
	-- Al llegar el remote el servidor aún no ha bajado la vida: la linterna sigue encendida.
	local conLinterna = quien:GetAttribute("Linterna") == true
	if quien == jugador then
		local personaje = jugador.Character
		if personaje then
			pendiente = { personaje = personaje, cabeza = cab, linterna = conLinterna, color = colorDe(quien),
				desde = os.clock() }
			encender()
		end
		return
	end
	crear(quien, cab, conLinterna, colorDe(quien), 1)
end

-- Muertes sin remote (otras causas): el muñeco cae donde está, sin empuje.
local function vigilar(quien: Player, personaje: Model)
	-- Revive (personaje nuevo): fuera el muñeco viejo.
	for _, c in table.clone(cuerpos) do
		if c.quien == quien and c.real ~= personaje then
			quitar(c)
		end
	end
	local hum = personaje:WaitForChild("Humanoid", 10)
	if not hum or not hum:IsA("Humanoid") then
		return
	end
	hum.Died:Connect(function()
		task.delay(CFG.SinAviso, function()
			local enEspera = pendiente ~= nil and pendiente.personaje == personaje
			if quien.Character == personaje and not enEspera and not cuerpoDe(quien, personaje) then
				crear(quien, nil, false, colorDe(quien), 0)
			end
		end)
	end)
end

local function apuntarJugador(quien: Player)
	quien.CharacterAdded:Connect(function(personaje)
		vigilar(quien, personaje)
	end)
	if quien.Character then
		task.spawn(vigilar, quien, quien.Character)
	end
end

function CadaverVista.start()
	carpeta = Instance.new("Folder")
	carpeta.Name = "Cadaveres"
	carpeta.Parent = workspace

	Remotes.Muerte.OnClientEvent:Connect(alMorir)
	CollectionService:GetInstanceAddedSignal("Charco"):Connect(function(charco)
		task.defer(adoptar, charco) -- después de que MuerteVista ponga su tween (el más nuevo gana)
	end)
	Players.PlayerAdded:Connect(apuntarJugador)
	for _, j in Players:GetPlayers() do
		apuntarJugador(j)
	end
	Players.PlayerRemoving:Connect(function(j)
		for _, c in table.clone(cuerpos) do
			if c.quien == j then
				quitar(c)
			end
		end
	end)
	-- Tu cámara enseña otra vez tu cuerpo al cambiar de sujeto (mirar a los vivos): se vuelve a esconder.
	local camara = workspace.CurrentCamera
	if camara then
		camara:GetPropertyChangedSignal("CameraSubject"):Connect(function()
			task.defer(function()
				for _, c in cuerpos do
					if c.propio and c.real.Parent then
						esconderReal(c.real, false, c.conexiones)
					end
				end
			end)
		end)
	end
	-- Al entrar con alguien ya muerto (no llegó el remote): su muñeco, ya en el suelo.
	for _, j in Players:GetPlayers() do
		if j ~= jugador and j:GetAttribute("Muerto") then
			crear(j, nil, false, colorDe(j), 0)
		end
	end
end

return CadaverVista
