-- Esconderse, el susto al morir y mirar a los demás.
--   Escondido (atributo Escondido del jugador = dónde va la cámara): cámara fija dentro del armario o debajo de la
--   cama con un leve respirar, latido que sube cuanto más cerca está el bicho, bordes oscuros y botón SALIR
--   (también E, espacio o B del mando).
--   Te pillan (remote Muerte): la cámara mira a la cara del bicho, temblor, destello rojo, grito y sangre en la
--   pantalla; luego negro y a mirar a los vivos (clic o toque para cambiar, en tercera persona) hasta el amanecer.
--   A otro: un charco de sangre donde ha muerto.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GolpeadorVista = require(script.Parent.GolpeadorVista)
local Sonido = require(script.Parent.Sonido)
local Ui = require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))

local MuerteVista = {}

local jugador = Players.LocalPlayer
local camara = workspace.CurrentCamera
local azar = Random.new()

local capa: Frame -- bordes oscuros, sangre y negro
local bordes: ImageLabel
local rojo: Frame
local negro: Frame
local salir: TextButton
local mirando: TextLabel
local latido: Sound?
local susto = false -- durante el susto nadie más toca la cámara
local mirado = 0 -- índice del vivo al que miras de muerto

local function personajeVisible(visible: boolean)
	local personaje = jugador.Character
	if personaje then
		for _, parte in personaje:GetDescendants() do
			if parte:IsA("BasePart") or parte:IsA("Decal") then
				parte.LocalTransparencyModifier = if visible then 0 else 1
			end
		end
	end
end

local function bichoMasCerca(desde: Vector3): number
	local carpeta = workspace:FindFirstChild("Bichos")
	local mejor = math.huge
	for _, bicho in if carpeta then carpeta:GetChildren() else {} do
		local raiz = bicho:FindFirstChild("HumanoidRootPart") :: BasePart?
		if raiz then
			mejor = math.min(mejor, (raiz.Position - desde).Magnitude)
		end
	end
	return mejor
end

-- Cámara del escondite: fija, con un leve respirar.
local function enEscondite()
	local vista = jugador:GetAttribute("Escondido")
	if typeof(vista) ~= "CFrame" or susto then
		return
	end
	local t = os.clock()
	camara.CameraType = Enum.CameraType.Scriptable
	camara.CFrame = vista * CFrame.new(0, math.sin(t * 1.6) * 0.04, 0) * CFrame.Angles(math.sin(t * 0.8) * 0.01, math.sin(t * 0.5) * 0.02, 0)
	local cerca = bichoMasCerca(vista.Position)
	if latido then
		latido.Volume = 0.25 + 1.2 * math.clamp(1 - cerca / 45, 0, 1)
		latido.PlaybackSpeed = 1 + 0.5 * math.clamp(1 - cerca / 30, 0, 1)
	end
end

local function cambiarEscondido()
	local escondido = typeof(jugador:GetAttribute("Escondido")) == "CFrame"
	salir.Visible = escondido
	TweenService:Create(bordes, TweenInfo.new(0.6), { ImageTransparency = if escondido then 0.05 else 1 }):Play()
	personajeVisible(not escondido)
	if escondido then
		latido = latido or Sonido.bucle("Latido")
		ContextActionService:BindAction("SalirEscondite", function(_, estado)
			if estado == Enum.UserInputState.Begin then
				Remotes.Salir:FireServer()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.E, Enum.KeyCode.Space, Enum.KeyCode.ButtonB)
	else
		ContextActionService:UnbindAction("SalirEscondite")
		if latido then
			latido:Destroy()
			latido = nil
		end
		if not susto then
			camara.CameraType = Enum.CameraType.Custom
		end
	end
end

local function vivos(): { Player }
	local lista = {}
	for _, otro in Players:GetPlayers() do
		local humanoide = otro.Character and otro.Character:FindFirstChildOfClass("Humanoid")
		if otro ~= jugador and humanoide and humanoide.Health > 0 and not otro:GetAttribute("Muerto") then
			table.insert(lista, otro)
		end
	end
	return lista
end

-- De muerto: la cámara sigue a uno de los vivos.
local function mirarVivos(siguiente: boolean)
	if not jugador:GetAttribute("Muerto") or susto then
		mirando.Visible = false
		return
	end
	local lista = vivos()
	if #lista == 0 then
		mirando.Visible = false
		return
	end
	if siguiente then
		mirado += 1
	end
	mirado = ((mirado - 1) % #lista) + 1
	local otro = lista[mirado]
	local humanoide = otro.Character and otro.Character:FindFirstChildOfClass("Humanoid")
	if humanoide and camara.CameraSubject ~= humanoide then
		camara.CameraType = Enum.CameraType.Custom
		camara.CameraSubject = humanoide
	end
	mirando.Text = Lang.t(nil, "Watching {name}", { name = otro.DisplayName })
	mirando.Visible = true
end

-- Sangre en la pantalla: goterones que caen desde el borde de arriba y salpicaduras con gotas alrededor.
-- Los tamaños van en proporción a la altura de la pantalla (RelativeYY) para que no se deformen.
local function gota(padre: GuiObject, posicion: UDim2, ancho: number, alto: number, giro: number): Frame
	local g = Instance.new("Frame")
	g.AnchorPoint = Vector2.new(0.5, 0.5)
	g.Position = posicion
	g.Size = UDim2.fromScale(ancho, alto)
	g.SizeConstraint = Enum.SizeConstraint.RelativeYY
	g.Rotation = giro
	g.BackgroundColor3 = Color3.new(1, 1, 1)
	g.BorderSizePixel = 0
	g.ZIndex = 91
	local redondo = Instance.new("UICorner")
	redondo.CornerRadius = UDim.new(0.5, 0)
	redondo.Parent = g
	local brillo = Instance.new("UIGradient") -- rojo oscuro, más claro por un lado: que parezca mojado
	brillo.Color = ColorSequence.new(Color3.fromRGB(96, 3, 3), Color3.fromRGB(36, 0, 0))
	brillo.Rotation = 90 + giro
	brillo.Parent = g
	g.Parent = padre
	return g
end

local function salpicadura(padre: GuiObject, x: number, y: number, grande: number)
	local aspecto = camara.ViewportSize.X / math.max(1, camara.ViewportSize.Y)
	for _ = 1, 5 do -- el centro: manchas encimadas, forma irregular
		local t = grande * azar:NextNumber(0.5, 1)
		gota(padre, UDim2.fromScale(x + azar:NextNumber(-0.4, 0.4) * grande / aspecto, y + azar:NextNumber(-0.4, 0.4) * grande),
			t, t * azar:NextNumber(0.7, 1.2), azar:NextNumber(0, 180))
	end
	for _ = 1, azar:NextInteger(12, 18) do -- gotas que salen hacia fuera, alargadas en la dirección en que salieron
		local angulo = azar:NextNumber(0, math.pi * 2)
		local lejos = grande * azar:NextNumber(0.6, 1.6)
		local t = grande * azar:NextNumber(0.05, 0.18)
		gota(padre, UDim2.fromScale(x + math.cos(angulo) * lejos / aspecto, y + math.sin(angulo) * lejos),
			t, t * azar:NextNumber(1.5, 3.5), math.deg(angulo) + 90)
	end
end

local function sangre(): Frame
	local capaSangre = Instance.new("Frame")
	capaSangre.Name = "Sangre"
	capaSangre.Size = UDim2.fromScale(1, 1)
	capaSangre.BackgroundTransparency = 1
	capaSangre.ZIndex = 91
	capaSangre.Parent = capa
	-- Borde de arriba empapado y goterones que bajan despacio, cada uno con su gota gorda al final.
	local borde = gota(capaSangre, UDim2.fromScale(0.5, 0), 4, 0.07, 0)
	borde.SizeConstraint = Enum.SizeConstraint.RelativeXY
	borde.Size = UDim2.fromScale(1.1, 0.07)
	for _ = 1, azar:NextInteger(14, 20) do
		local ancho = azar:NextNumber(0.012, 0.035)
		local chorro = gota(capaSangre, UDim2.fromScale(azar:NextNumber(0, 1), 0), ancho, 0, 0)
		chorro.AnchorPoint = Vector2.new(0.5, 0)
		local bola = gota(chorro, UDim2.fromScale(0.5, 1), 1.7, 1.9, 0)
		bola.SizeConstraint = Enum.SizeConstraint.RelativeXX
		TweenService:Create(chorro, TweenInfo.new(azar:NextNumber(2, 5), Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.fromScale(ancho, azar:NextNumber(0.12, 0.55)) }):Play()
	end
	-- Salpicaduras grandes en los lados y una pequeña arriba (abajo en el centro va el aviso).
	salpicadura(capaSangre, azar:NextNumber(0.02, 0.18), azar:NextNumber(0.25, 0.8), azar:NextNumber(0.22, 0.32))
	salpicadura(capaSangre, azar:NextNumber(0.82, 0.98), azar:NextNumber(0.25, 0.8), azar:NextNumber(0.22, 0.32))
	salpicadura(capaSangre, azar:NextNumber(0.35, 0.65), azar:NextNumber(0.05, 0.15), azar:NextNumber(0.08, 0.12))
	return capaSangre
end

local function quitarSangre(capaSangre: Frame, despues: number)
	task.delay(despues, function()
		for _, g in capaSangre:GetDescendants() do
			if g:IsA("Frame") then
				TweenService:Create(g, TweenInfo.new(3), { BackgroundTransparency = 1 }):Play()
			end
		end
		task.delay(3, capaSangre.Destroy, capaSangre)
	end)
end

local function meHanPillado(cabeza: Vector3)
	susto = true
	ContextActionService:UnbindAction("SalirEscondite")
	salir.Visible = false
	local personaje = jugador.Character
	local mia = personaje and personaje:FindFirstChild("Head") :: BasePart?
	local desde = if mia then mia.Position else camara.CFrame.Position
	local hacia = (desde - cabeza)
	hacia = if hacia.Magnitude > 0.1 then hacia.Unit else Vector3.zAxis
	-- La cara del bicho de frente, con la boca abierta, echándose encima; una luz para que se le vea en lo oscuro.
	local bicho = GolpeadorVista.rugir(cabeza)
	local cara = bicho and bicho:FindFirstChild("Cabeza") :: BasePart?
	local luz: Attachment? = nil
	if cara then
		luz = Instance.new("Attachment") -- delante de la cara: dentro de la cabeza no la alumbraría
		luz.Position = Vector3.new(0, -0.3, -1.6)
		local foco = Instance.new("PointLight")
		foco.Color = Color3.fromRGB(255, 215, 195)
		foco.Brightness = 1.2
		foco.Range = 6
		foco.Parent = luz
		luz.Parent = cara
	end
	personajeVisible(false)
	local filtroSusto = RaycastParams.new()
	filtroSusto.FilterType = Enum.RaycastFilterType.Exclude
	filtroSusto.FilterDescendantsInstances = { workspace:FindFirstChild("Bichos") :: Instance, personaje :: Instance }
	camara.CameraType = Enum.CameraType.Scriptable
	local campo = camara.FieldOfView
	camara.FieldOfView = 60
	Sonido.tocar("Susto")
	rojo.BackgroundTransparency = 0.35
	TweenService:Create(rojo, TweenInfo.new(1.4), { BackgroundTransparency = 1 }):Play()
	local capaSangre = sangre()
	local t0 = os.clock()
	while os.clock() - t0 < 1.8 do
		local t = os.clock() - t0
		local fuerza = 0.16 * (1 - t / 1.8) + 0.03
		local ojo, centro
		if cara and cara.Parent then
			local acerca = 1 - math.clamp(t / 0.2, 0, 1)
			centro = cara.Position - Vector3.new(0, 0.6, 0)
			ojo = (cara.CFrame * CFrame.new(0, -0.5, -(2.7 + acerca * 3.5))).Position
			local choque = workspace:Raycast(centro, ojo - centro, filtroSusto) -- sin meterse en las paredes
			if choque then
				ojo = choque.Position + (centro - ojo).Unit * 0.3
			end
		else
			centro, ojo = cabeza, cabeza + hacia * 2.4
		end
		camara.CFrame = CFrame.lookAt(ojo, centro)
			* CFrame.new(azar:NextNumber(-fuerza, fuerza), azar:NextNumber(-fuerza, fuerza), 0)
			* CFrame.Angles(0, 0, azar:NextNumber(-fuerza, fuerza) * 0.5)
		RunService.RenderStepped:Wait()
	end
	if luz then
		luz:Destroy()
	end
	TweenService:Create(negro, TweenInfo.new(0.6), { BackgroundTransparency = 0 }):Play()
	task.wait(1.2)
	camara.FieldOfView = campo
	Ui.aviso(Lang.t(nil, "It got you. You'll wake up at dawn."), 5)
	susto = false
	camara.CameraType = Enum.CameraType.Custom
	mirarVivos(false)
	TweenService:Create(negro, TweenInfo.new(1.5), { BackgroundTransparency = 1 }):Play()
	quitarSangre(capaSangre, 3) -- se queda goteando un poco sobre lo que ves de muerto
end

local function charco(posicion: Vector3)
	local resultado = workspace:Raycast(posicion, Vector3.new(0, -8, 0))
	if not resultado then
		return
	end
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Material = Enum.Material.SmoothPlastic
	p.Reflectance = 0.15
	p.Color = Color3.fromRGB(60, 4, 4)
	p.Size = Vector3.new(0.05, 1, 1)
	p.CFrame = CFrame.new(resultado.Position + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	p.Parent = workspace.Terrain
	local final = azar:NextNumber(5, 7)
	TweenService:Create(p, TweenInfo.new(6, Enum.EasingStyle.Quad), { Size = Vector3.new(0.05, final, final) }):Play()
	-- Se limpia al amanecer.
	local conexion
	conexion = workspace:GetAttributeChangedSignal("Fase"):Connect(function()
		if workspace:GetAttribute("Fase") == "Dia" then
			conexion:Disconnect()
			p:Destroy()
		end
	end)
end

local function capas()
	capa = Instance.new("Frame")
	capa.Name = "Muerte"
	capa.Size = UDim2.fromScale(1, 1)
	capa.BackgroundTransparency = 1
	capa.ZIndex = 90
	capa.Parent = Ui.hud()
	-- Bordes oscuros al esconderse: un degradado radial hecho con UIGradient sobre un marco.
	bordes = Instance.new("ImageLabel")
	bordes.Size = UDim2.fromScale(1, 1)
	bordes.BackgroundTransparency = 1
	bordes.Image = "rbxasset://textures/ui/TopBar/WhiteOverlayAsset.png"
	bordes.ImageColor3 = Color3.new(0, 0, 0)
	bordes.ImageTransparency = 1
	bordes.ZIndex = 90
	local degradado = Instance.new("UIGradient")
	degradado.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.18, 0.75),
		NumberSequenceKeypoint.new(0.82, 0.75),
		NumberSequenceKeypoint.new(1, 0),
	})
	degradado.Parent = bordes
	bordes.Parent = capa
	rojo = Instance.new("Frame")
	rojo.Size = UDim2.fromScale(1, 1)
	rojo.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
	rojo.BackgroundTransparency = 1
	rojo.BorderSizePixel = 0
	rojo.ZIndex = 92
	rojo.Parent = capa
	negro = Instance.new("Frame")
	negro.Size = UDim2.fromScale(1, 1)
	negro.BackgroundColor3 = Color3.new(0, 0, 0)
	negro.BackgroundTransparency = 1
	negro.BorderSizePixel = 0
	negro.ZIndex = 95
	negro.Parent = capa

	salir = Ui.boton(Lang.t(nil, "Leave"), {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.93),
		Size = UDim2.fromOffset(220, 80), -- que se acierte con el dedo en el móvil
		TextSize = 28,
		Visible = false,
		ZIndex = 96,
	})
	salir.Activated:Connect(function()
		Remotes.Salir:FireServer()
	end)
	salir.Parent = capa
	mirando = Ui.texto("", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.95),
		Size = UDim2.fromScale(0.6, 0.04),
		TextSize = 22,
		Visible = false,
		ZIndex = 96,
	})
	mirando.Parent = capa
end

function MuerteVista.start()
	capas()
	jugador:GetAttributeChangedSignal("Escondido"):Connect(cambiarEscondido)
	jugador:GetAttributeChangedSignal("Muerto"):Connect(function()
		if not jugador:GetAttribute("Muerto") then
			mirando.Visible = false
			jugador.CameraMode = Enum.CameraMode.LockFirstPerson
			jugador.CameraMinZoomDistance = 0.5
		else -- de muerto se mira a los demás desde detrás
			jugador.CameraMode = Enum.CameraMode.Classic
			jugador.CameraMinZoomDistance = 10
		end
	end)
	jugador.CharacterAdded:Connect(function(personaje)
		camara.CameraType = Enum.CameraType.Custom
		camara.CameraSubject = personaje:WaitForChild("Humanoid")
	end)
	Remotes.Muerte.OnClientEvent:Connect(function(quien: Player, cabeza: Vector3)
		if quien == jugador then
			task.spawn(meHanPillado, cabeza)
		else
			local raiz = quien.Character and quien.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if raiz then
				charco(raiz.Position)
			end
		end
	end)
	UserInputService.InputBegan:Connect(function(entrada, procesado)
		if procesado or not jugador:GetAttribute("Muerto") then
			return
		end
		if entrada.UserInputType == Enum.UserInputType.MouseButton1 or entrada.UserInputType == Enum.UserInputType.Touch then
			mirarVivos(true)
		end
	end)
	RunService.RenderStepped:Connect(function()
		enEscondite()
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			mirarVivos(false) -- por si el que mirabas ha muerto
		end
	end)
end

return MuerteVista
