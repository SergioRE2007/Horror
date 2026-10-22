-- Linterna y flash en el cliente (lo manda el servidor: juego/servidor/Equipo).
--   Linterna: la F, L1 en el mando o el botón en el móvil. La luz de cada jugador: la mía sale de la cámara; la de los
--   demás, de su cabeza. Con poca pila parpadea.
--   Flash: clic, R2 o el botón en el móvil. Destello en todos los clientes; al que hace la foto, la pantalla en blanco.
--   Lo que queda de pila y fotos sale abajo un momento cuando cambia, y se va (casi nada en pantalla).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sonido = require(script.Parent.Sonido)
local Ui = require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))

local EquipoVista = {}

local L = Config.Linterna
local jugador = Players.LocalPlayer
local camara = workspace.CurrentCamera
local COLOR_LUZ = Color3.fromRGB(255, 236, 205) -- la de serie

-- Color de la luz de cada uno: el cosmético que lleva puesto (atributo "PuestoLinterna", lo pone Comun.Tienda).
local COLORES = {}
for _, cosa in Config.Cosmeticos do
	if cosa.Tipo == "Linterna" then
		COLORES[cosa.Id] = Color3.fromRGB(table.unpack(cosa.Color))
	end
end
local function colorDe(otro: Player): Color3
	return COLORES[otro:GetAttribute("PuestoLinterna")] or COLOR_LUZ
end

type Luz = { punto: Attachment, foco: SpotLight }
local luces: { [Player]: Luz } = {}
local blanco: Frame
local cartel: Frame
local barra: Frame
local repuesto: TextLabel
local fotos: TextLabel
local cartelHasta = 0

local function nuevaLuz(otro: Player): Luz
	local punto = Instance.new("Attachment")
	punto.Name = "Linterna"
	local foco = Instance.new("SpotLight")
	foco.Color = colorDe(otro)
	foco.Brightness = L.Brillo
	foco.Range = L.Alcance
	foco.Angle = L.Angulo * 2
	foco.Shadows = true
	foco.Face = Enum.NormalId.Front
	foco.Parent = punto
	return { punto = punto, foco = foco }
end

-- Coloca y enciende (o apaga) la luz de cada jugador; parpadea con poca pila.
local function actualizarLuces()
	local ahora = os.clock()
	for _, otro in Players:GetPlayers() do
		local encendida = otro:GetAttribute("Linterna") == true
		local luz = luces[otro]
		local cabeza = otro.Character and otro.Character:FindFirstChild("Head") :: BasePart?
		if not encendida or not cabeza then
			if luz then
				luz.punto:Destroy()
				luces[otro] = nil
			end
			continue
		end
		if not luz then
			luz = nuevaLuz(otro)
			luces[otro] = luz
		end
		if otro == jugador then
			-- Desde la cámara, un poco abajo a la derecha (en la mano).
			luz.punto.Parent = workspace.Terrain
			luz.punto.WorldCFrame = camara.CFrame * CFrame.new(0.6, -0.5, -0.5)
		elseif luz.punto.Parent ~= cabeza then
			luz.punto.Parent = cabeza
			luz.punto.CFrame = CFrame.new(0.4, -0.3, -0.6)
		end
		local pila = otro:GetAttribute("Pila") or 1
		local brillo = L.Brillo
		if pila < L.Poca then
			-- Cuanta menos pila, más se apaga a tirones.
			local fallo = 1 - pila / L.Poca
			local ruido = math.noise(ahora * 9, otro.UserId % 97)
			if ruido < -0.5 + fallo * 0.7 then
				brillo *= 0.05
			else
				brillo *= 0.75 + 0.25 * math.noise(ahora * 30, 3.1)
			end
		end
		luz.foco.Brightness = brillo
		luz.foco.Color = colorDe(otro)
	end
	for otro, luz in luces do
		if not otro.Parent then
			luz.punto:Destroy()
			luces[otro] = nil
		end
	end
end

local function mostrarCartel()
	cartelHasta = os.clock() + 3
	local pila = jugador:GetAttribute("Pila") or 0
	barra.Size = UDim2.fromScale(math.clamp(pila, 0, 1), 1)
	barra.BackgroundColor3 = if pila < L.Poca then Ui.Color.Sangre else Ui.Color.Hueso
	repuesto.Text = "+" .. tostring(jugador:GetAttribute("Pilas") or 0)
	fotos.Text = Ui.mayusculas(Lang.t(nil, "{n} photos", { n = jugador:GetAttribute("Fotos") or 0 }))
		.. "  +" .. tostring(jugador:GetAttribute("Carretes") or 0)
	TweenService:Create(cartel, TweenInfo.new(0.25), { GroupTransparency = 0 }):Play()
	task.delay(3.05, function()
		if os.clock() >= cartelHasta then
			TweenService:Create(cartel, TweenInfo.new(1), { GroupTransparency = 1 }):Play()
		end
	end)
end

local function pedirLinterna()
	Sonido.tocar("Linterna")
	Remotes.Linterna:FireServer()
end

local function pedirFlash()
	if jugador:GetAttribute("Escondido") or jugador:GetAttribute("Muerto") then
		return
	end
	Remotes.Flash:FireServer(camara.CFrame.LookVector)
end

-- Destello de un flash: luz fuerte un instante en la cabeza de quien hace la foto.
local function destello(quien: Player)
	local cabeza = quien.Character and quien.Character:FindFirstChild("Head") :: BasePart?
	if not cabeza then
		return
	end
	local punto = Instance.new("Attachment")
	punto.Position = Vector3.new(0, 0, -1.5)
	local luz = Instance.new("PointLight")
	luz.Color = Color3.fromRGB(235, 240, 255)
	luz.Brightness = 10
	luz.Range = 40
	luz.Parent = punto
	punto.Parent = cabeza
	TweenService:Create(luz, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Brightness = 0 }):Play()
	task.delay(0.4, punto.Destroy, punto)
	if quien == jugador then
		Sonido.tocar("Flash")
		blanco.BackgroundTransparency = 0.05
		TweenService:Create(blanco, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 }):Play()
	else
		Sonido.en("Flash", cabeza.Position)
	end
end

local function crearHud()
	local hud = Ui.hud()
	local capa = Instance.new("ScreenGui") -- aparte del HUD (sin UIScale): el blanco tapa toda la pantalla
	capa.Name = "Flash"
	capa.IgnoreGuiInset = true
	capa.ResetOnSpawn = false
	capa.DisplayOrder = 5
	capa.Parent = hud.Parent
	blanco = Instance.new("Frame")
	blanco.Size = UDim2.fromScale(1, 1)
	blanco.BackgroundColor3 = Color3.new(1, 1, 1)
	blanco.BackgroundTransparency = 1
	blanco.BorderSizePixel = 0
	blanco.Parent = capa

	-- Pila (una barrita) y fotos, abajo en el centro; sale un momento al cambiar.
	cartel = Instance.new("CanvasGroup")
	cartel.Name = "Equipo"
	cartel.AnchorPoint = Vector2.new(0.5, 1)
	cartel.Position = UDim2.new(0.5, 0, 1, -18)
	cartel.Size = UDim2.fromOffset(300, 30)
	cartel.BackgroundTransparency = 1
	cartel.GroupTransparency = 1
	cartel.Parent = hud
	local lista = Instance.new("UIListLayout")
	lista.FillDirection = Enum.FillDirection.Horizontal
	lista.HorizontalAlignment = Enum.HorizontalAlignment.Center
	lista.VerticalAlignment = Enum.VerticalAlignment.Center
	lista.Padding = UDim.new(0, 10)
	lista.Parent = cartel
	local pila = Instance.new("Frame")
	pila.Size = UDim2.fromOffset(46, 16)
	pila.BackgroundColor3 = Ui.Color.Papel
	pila.BackgroundTransparency = 0.3
	local borde = Instance.new("UIStroke")
	borde.Color = Ui.Color.Hueso
	borde.Transparency = 0.4
	borde.Parent = pila
	barra = Instance.new("Frame")
	barra.BorderSizePixel = 0
	barra.Parent = pila
	pila.Parent = cartel
	repuesto = Ui.texto("", { Size = UDim2.fromOffset(34, 26), TextSize = 20 })
	repuesto.Parent = cartel
	fotos = Ui.texto("", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 26), TextSize = 20 })
	fotos.Parent = cartel

	-- Móvil: dos botones a la izquierda del de saltar de Roblox.
	if UserInputService.TouchEnabled then
		local fila = Instance.new("Frame")
		fila.Name = "EquipoBotones"
		fila.AnchorPoint = Vector2.new(1, 1)
		fila.Position = UDim2.fromScale(0.8, 0.97)
		fila.Size = UDim2.fromOffset(290, 80)
		fila.BackgroundTransparency = 1
		local orden = Instance.new("UIListLayout")
		orden.FillDirection = Enum.FillDirection.Horizontal
		orden.HorizontalAlignment = Enum.HorizontalAlignment.Right
		orden.Padding = UDim.new(0, 10)
		orden.Parent = fila
		for _, datos in { { Lang.t(nil, "Flashlight"), pedirLinterna }, { "FLASH", pedirFlash } } do
			local boton = Ui.boton(datos[1], { Size = UDim2.fromOffset(140, 80), TextSize = 24 })
			boton.Activated:Connect(datos[2])
			boton.Parent = fila
		end
		fila.Parent = hud
	end
end

function EquipoVista.start()
	crearHud()
	UserInputService.InputBegan:Connect(function(entrada, procesado)
		if procesado then
			return
		end
		if entrada.KeyCode == Enum.KeyCode.F or entrada.KeyCode == Enum.KeyCode.ButtonL1 then
			pedirLinterna()
		elseif entrada.UserInputType == Enum.UserInputType.MouseButton1 or entrada.KeyCode == Enum.KeyCode.ButtonR2 then
			pedirFlash()
		end
	end)
	local pilaAntes = 1
	for _, atributo in { "Pila", "Pilas", "Fotos", "Carretes", "Linterna" } do
		jugador:GetAttributeChangedSignal(atributo):Connect(function()
			-- La pila baja poco a poco: solo enseña el cartel al cambiarla o al quedar poca.
			local pila = jugador:GetAttribute("Pila") or 0
			local antes = pilaAntes
			pilaAntes = pila
			if atributo ~= "Pila" or pila > antes or (pila < L.Poca and antes >= L.Poca) then
				mostrarCartel()
			end
		end)
	end
	Remotes.Flash.OnClientEvent:Connect(destello)
	RunService:BindToRenderStep("Linterna", Enum.RenderPriority.Camera.Value + 1, actualizarLuces)
end

return EquipoVista
