-- La pistola de bengalas en el cliente (lo manda el servidor: juego/servidor/Bengalas).
--   Sacarla y guardarla: Q o R1 en el mando. Con ella en la mano, clic o R2 dispara (y no hace foto: EquipoVista
--   pregunta `enMano`). En el móvil, el botón BENGALA de la fila del equipo dispara directo. Se apunta con la cámara.
--   La pistola en la mano es de bloques y solo la ve quien la lleva (delante de la cámara).
--   Cada disparo (remote Bengala, para todos): una bola roja que vuela con humo y chispas, ilumina de rojo por donde
--   pasa y se queda ardiendo unos segundos donde da. Si da a un bicho, revienta en chispas.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sonido = require(script.Parent.Sonido)
local Ui = require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))

local BengalasVista = {}

local B = Config.Bestia
local jugador = Players.LocalPlayer
local camara = workspace.CurrentCamera

local VELOCIDAD = Config.Bestia.Vuela
local ARDE = Config.Bestia.Arde
local ROJO = Color3.fromRGB(255, 60, 40)
local LUZ = Color3.fromRGB(255, 70, 45)
local BRILLO = Config.Bestia.Brillo
local RADIO = Config.Bestia.Luz
local EN_MANO = CFrame.new(0.55, -0.55, -1.3) -- dónde se ve la pistola respecto a la cámara

local tengoPistola = false
local bengalas = 0
local mano = false
local pistola: Model? = nil
local boca: Attachment? = nil
local retroceso = 0
local ultimoDisparo = -math.huge
local mira: Frame
local cuenta: TextLabel
local botonMovil: TextButton? = nil

-- Las bengalas que vuelan o arden (un solo bucle las hace parpadear, y solo mientras haya).
type Viva = { luz: PointLight, base: number, semilla: number }
local vivas: { [Viva]: boolean } = {}
local bucle: RBXScriptConnection? = nil

function BengalasVista.enMano(): boolean
	return mano
end

-- Lee de la mochila publicada si lleva la pistola y cuántas bengalas.
local function leerMochila()
	local p, n = false, 0
	local ok, r = pcall(HttpService.JSONDecode, HttpService, jugador:GetAttribute("Mochila") or "")
	if ok and type(r) == "table" and type(r.cosas) == "table" then
		for _, c in r.cosas do
			if c.tipo == "Pistola" then
				p = true
			elseif c.tipo == "Bengala" then
				n += 1
			end
		end
	end
	tengoPistola, bengalas = p, n
	if botonMovil then
		botonMovil.Visible = p
	end
	if cuenta then
		cuenta.Text = Ui.mayusculas(Lang.t(nil, "{n} flares", { n = n }))
	end
end

local function pieza(nombre: string, tam: Vector3, color: Color3, padre: Instance): Part
	local p = Instance.new("Part")
	p.Name = nombre
	p.Size = tam
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = padre
	return p
end

-- La pistola de bengalas (naranja descolorido, de plástico) que se ve en la mano.
local function crearPistola(): Model
	local m = Instance.new("Model")
	m.Name = "PistolaBengalas"
	local naranja = Color3.fromRGB(176, 72, 32)
	local cuerpo = pieza("Cuerpo", Vector3.new(0.22, 0.26, 0.6), naranja, m)
	local canon = pieza("Canon", Vector3.new(0.3, 0.3, 0.75), naranja, m)
	canon.Shape = Enum.PartType.Cylinder
	local mango = pieza("Mango", Vector3.new(0.2, 0.5, 0.24), Color3.fromRGB(58, 52, 48), m)
	local gatillo = pieza("Gatillo", Vector3.new(0.05, 0.14, 0.05), Color3.fromRGB(40, 38, 36), m)
	m.PrimaryPart = cuerpo
	-- Posiciones respecto al cuerpo (se recolocan cada fotograma desde aquí).
	cuerpo:SetAttribute("Rel", CFrame.new())
	canon:SetAttribute("Rel", CFrame.new(0, 0.05, -0.5) * CFrame.Angles(0, math.rad(90), 0))
	mango:SetAttribute("Rel", CFrame.new(0, -0.3, 0.18) * CFrame.Angles(math.rad(-15), 0, 0))
	gatillo:SetAttribute("Rel", CFrame.new(0, -0.17, -0.05))
	local a = Instance.new("Attachment")
	a.Name = "Boca"
	a.Position = Vector3.new(0.38, 0, 0) -- el cilindro va a lo largo de su X, que el giro deja mirando adelante
	a.Parent = canon
	boca = a
	return m
end

local function colocarPistola()
	local m = pistola
	if not m then
		return
	end
	retroceso = math.max(0, retroceso - 0.12)
	local balanceo = math.sin(os.clock() * 1.6) * 0.012
	local base = camara.CFrame * EN_MANO * CFrame.new(0, balanceo, retroceso * 0.25)
		* CFrame.Angles(retroceso * 0.5, 0, 0)
	for _, p in m:GetChildren() do
		local rel = p:GetAttribute("Rel")
		if p:IsA("BasePart") and typeof(rel) == "CFrame" then
			p.CFrame = base * rel
		end
	end
end

local function guardar()
	if not mano then
		return
	end
	mano = false
	RunService:UnbindFromRenderStep("PistolaBengalas")
	if pistola then
		pistola:Destroy()
		pistola, boca = nil, nil
	end
	mira.Visible = false
end

-- ¿Puede tener la pistola en la mano ahora mismo? En las cinemáticas (la cámara la lleva un script) tampoco: como las
-- manos (Manos), se guarda, que si no se quedaba flotando delante de la cámara de cine.
local function libre(): boolean
	return camara.CameraType == Enum.CameraType.Custom
		and not jugador:GetAttribute("Muerto") and not jugador:GetAttribute("Escondido")
		and not jugador:GetAttribute("Cargando") and not jugador:GetAttribute("MochilaAbierta")
		and not jugador:GetAttribute("Trabajando")
end

local function sacar()
	if mano then
		guardar()
		return
	end
	if not tengoPistola then
		Ui.aviso(Lang.t(nil, "You don't have a flare gun."))
		return
	end
	if not libre() then
		Ui.aviso(Lang.t(nil, "Your hands are full."))
		return
	end
	mano = true
	pistola = crearPistola()
	retroceso = 1 -- sube desde abajo al sacarla
	colocarPistola()
	;(pistola :: Model).Parent = camara
	RunService:BindToRenderStep("PistolaBengalas", Enum.RenderPriority.Camera.Value + 2, colocarPistola)
	mira.Visible = true
end

local function disparar()
	if not tengoPistola or not libre() then
		return
	end
	if os.clock() - ultimoDisparo < B.Recarga then
		return
	end
	if bengalas <= 0 then
		Ui.aviso(Lang.t(nil, "No flares left."))
		return
	end
	ultimoDisparo = os.clock()
	retroceso = 1
	Remotes.Bengala:FireServer(camara.CFrame.Position, camara.CFrame.LookVector)
end

local function encenderBucle()
	if bucle then
		return
	end
	bucle = RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for v in vivas do
			-- Parpadeo de llama: lento y corto, para que no maree.
			local r = math.noise(t * 7, v.semilla) * 0.35 + math.noise(t * 19, v.semilla + 3) * 0.12
			v.luz.Brightness = v.base * (1 + r)
		end
		if next(vivas) == nil and bucle then
			bucle:Disconnect()
			bucle = nil
		end
	end)
end

local function particulas(padre: Instance, humo: boolean, chispas: number): (ParticleEmitter, ParticleEmitter)
	local h = Instance.new("ParticleEmitter")
	h.Texture = "rbxasset://textures/particles/smoke_main.dds"
	h.Color = ColorSequence.new(Color3.fromRGB(120, 70, 66), Color3.fromRGB(60, 58, 58))
	h.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	h.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 3.2) })
	h.Lifetime = NumberRange.new(1.5, 2.6)
	h.Speed = NumberRange.new(1, 2.5)
	h.Acceleration = Vector3.new(0, 2.5, 0)
	h.SpreadAngle = Vector2.new(25, 25)
	h.Rotation = NumberRange.new(0, 360)
	h.RotSpeed = NumberRange.new(-30, 30)
	h.LightInfluence = 1
	h.Rate = if humo then 14 else 0
	h.Parent = padre
	local c = Instance.new("ParticleEmitter")
	c.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	c.Color = ColorSequence.new(Color3.fromRGB(255, 190, 120), Color3.fromRGB(255, 70, 40))
	c.LightEmission = 0.6
	c.LightInfluence = 0
	c.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.14), NumberSequenceKeypoint.new(1, 0) })
	c.Lifetime = NumberRange.new(0.25, 0.6)
	c.Speed = NumberRange.new(4, 9)
	c.SpreadAngle = Vector2.new(180, 180)
	c.Acceleration = Vector3.new(0, -25, 0)
	c.Drag = 2
	c.Rate = chispas
	c.Parent = padre
	return h, c
end

-- La bola de la bengala: brilla roja con su luz, humo y chispas.
local function crearBola(desde: Vector3): (Part, Viva, ParticleEmitter, ParticleEmitter)
	local bola = Instance.new("Part")
	bola.Name = "Bengala"
	bola.Shape = Enum.PartType.Ball
	bola.Size = Vector3.new(0.35, 0.35, 0.35)
	bola.Color = ROJO
	bola.Material = Enum.Material.Neon -- una bolita: el único Neon (pequeño) es la llama
	bola.Anchored = true
	bola.CanCollide = false
	bola.CanQuery = false
	bola.CanTouch = false
	bola.CastShadow = false
	bola.Position = desde
	local luz = Instance.new("PointLight")
	luz.Color = LUZ
	luz.Brightness = BRILLO
	luz.Range = RADIO
	luz.Shadows = true
	luz.Parent = bola
	local humo, chispas = particulas(bola, true, 40)
	bola.Parent = workspace.Terrain
	local viva = { luz = luz, base = BRILLO, semilla = math.random() * 100 }
	vivas[viva] = true
	encenderBucle()
	return bola, viva, humo, chispas
end

-- Se apaga poco a poco y se borra (el humo que ya salió termina de subir).
local function apagar(bola: Part, viva: Viva, humo: ParticleEmitter, chispas: ParticleEmitter, segundos: number, sonido: Sound?)
	vivas[viva] = nil
	humo.Rate = 0
	chispas.Rate = 0
	TweenService:Create(viva.luz, TweenInfo.new(segundos), { Brightness = 0 }):Play()
	TweenService:Create(bola, TweenInfo.new(segundos), { Transparency = 1, Size = Vector3.new(0.1, 0.1, 0.1) }):Play()
	if sonido then
		TweenService:Create(sonido, TweenInfo.new(segundos), { Volume = 0 }):Play()
	end
	task.delay(segundos + 2.7, bola.Destroy, bola)
end

local function alDisparo(quien: Player, origen: Vector3, impacto: Vector3, normal: Vector3?, acierto: string?)
	if typeof(origen) ~= "Vector3" or typeof(impacto) ~= "Vector3" then
		return
	end
	local desde = origen
	if quien == jugador then
		retroceso = 1
		if boca then
			desde = boca.WorldPosition
		else
			desde = camara.CFrame * Vector3.new(0.5, -0.4, -1.5)
		end
	end
	-- Sonido del disparo: el suyo si ya existe en Config.Sonidos (aún no hay; pendiente de ElevenLabs).
	if Config.Sonidos.Bengala then
		if quien == jugador then
			Sonido.tocar("Bengala")
		else
			Sonido.en("Bengala", desde)
		end
	end
	local bola, viva, humo, chispas = crearBola(desde)
	-- Fogonazo en la boca un instante.
	viva.luz.Brightness = BRILLO * 2
	local distancia = (impacto - desde).Magnitude
	local vuelo = math.max(0.05, distancia / VELOCIDAD)
	TweenService:Create(bola, TweenInfo.new(vuelo, Enum.EasingStyle.Linear), { Position = impacto }):Play()
	task.delay(vuelo, function()
		if not bola.Parent then
			return
		end
		if acierto then
			-- Revienta en el bicho: un golpe de chispas y se apaga enseguida.
			chispas:Emit(60)
			viva.luz.Brightness = BRILLO * 2.2
			apagar(bola, viva, humo, chispas, 0.8, nil)
		elseif normal then
			-- Se queda ardiendo pegada donde dio.
			bola.Position = impacto + normal * 0.18
			chispas:Emit(25)
			chispas.Rate = 18
			humo.Rate = 10
			local fuego = Sonido.bucle("Fuego", bola)
			fuego.Volume *= 0.5
			fuego.RollOffMode = Enum.RollOffMode.InverseTapered
			fuego.RollOffMinDistance = 4
			fuego.RollOffMaxDistance = 30
			task.delay(ARDE, apagar, bola, viva, humo, chispas, 1.5, fuego)
		else
			-- No dio a nada: se apaga en el aire.
			apagar(bola, viva, humo, chispas, 1, nil)
		end
	end)
end

local function crearHud()
	local hud = Ui.hud()
	-- Una mira mínima y las bengalas que quedan, solo con la pistola en la mano.
	mira = Instance.new("Frame")
	mira.Name = "MiraBengala"
	mira.AnchorPoint = Vector2.new(0.5, 0.5)
	mira.Position = UDim2.fromScale(0.5, 0.5)
	mira.Size = UDim2.fromOffset(6, 6)
	mira.BackgroundColor3 = Ui.Color.Hueso
	mira.BackgroundTransparency = 0.35
	mira.BorderSizePixel = 0
	mira.Visible = false
	local redondo = Instance.new("UICorner")
	redondo.CornerRadius = UDim.new(1, 0)
	redondo.Parent = mira
	mira.Parent = hud
	-- Las que quedan, abajo en el centro (encima del cartel de pila y fotos de EquipoVista). En el móvil, arriba en el
	-- centro, debajo de ese cartel (que allí va arriba: abajo están los botones del equipo).
	local tactil = UserInputService.TouchEnabled
	cuenta = Ui.texto("", {
		AnchorPoint = Vector2.new(0.5, if tactil then 0 else 1),
		Position = if tactil then UDim2.new(0.5, 0, 0.17, 36) else UDim2.new(0.5, 0, 1, -52),
		Size = UDim2.fromOffset(240, 26),
		TextSize = 20,
		Visible = false,
	})
	cuenta.Parent = hud
	mira:GetPropertyChangedSignal("Visible"):Connect(function()
		cuenta.Visible = mira.Visible
	end)

	-- Móvil: botón BENGALA en la fila del equipo (la crea EquipoVista); solo se ve con la pistola en la mochila. Va el
	-- último (LayoutOrder 8), en la casilla de arriba a la izquierda que queda libre: la rejilla salta los botones
	-- escondidos, y con el 3 al coger o tirar la pistola MÓVIL, AGACHARSE y CORRER cambiaban de casilla y se pulsaba
	-- lo que no era.
	if tactil then
		local fila = hud:FindFirstChild("EquipoBotones")
		if fila then
			local boton = Ui.boton(Lang.t(nil, "Flare"))
			Ui.queQuepa(boton, 24)
			boton.Name = "Bengala"
			boton.LayoutOrder = 8 -- después de CORRER (7): nada se mueve al aparecer o irse (orden en EquipoVista)
			boton.Visible = false
			boton.Activated:Connect(disparar)
			boton.Parent = fila
			botonMovil = boton
		end
	end
end

function BengalasVista.start()
	crearHud()
	leerMochila()
	jugador:GetAttributeChangedSignal("Mochila"):Connect(function()
		leerMochila()
		if mano and not tengoPistola then
			guardar()
		end
	end)
	-- Con las manos ocupadas, escondido, muerto o en una cinemática, se guarda sola.
	local function mirarLibre()
		if mano and not libre() then
			guardar()
		end
	end
	for _, atributo in { "Muerto", "Escondido", "Cargando", "MochilaAbierta", "Trabajando" } do
		jugador:GetAttributeChangedSignal(atributo):Connect(mirarLibre)
	end
	camara:GetPropertyChangedSignal("CameraType"):Connect(mirarLibre)
	UserInputService.InputBegan:Connect(function(entrada, procesado)
		if procesado then
			return
		end
		if entrada.KeyCode == Enum.KeyCode.Q or entrada.KeyCode == Enum.KeyCode.ButtonR1 then
			sacar()
		elseif mano and (entrada.UserInputType == Enum.UserInputType.MouseButton1 or entrada.KeyCode == Enum.KeyCode.ButtonR2) then
			disparar()
		end
	end)
	Remotes.Bengala.OnClientEvent:Connect(alDisparo)
end

return BengalasVista
