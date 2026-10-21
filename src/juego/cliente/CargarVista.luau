-- Lo pesado en el cliente (lo manda el servidor: juego/servidor/Cargar). Mientras llevas algo (atributo Cargando):
--   la E, X en el mando o el botón SOLTAR del móvil lo suelta; con las manos ocupadas no salen los carteles de coger.
--   La vista baja un poco y se balancea al andar, más despacio cuanto más pesa.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))

local CargarVista = {}

local jugador = Players.LocalPlayer
local aviso: TextLabel
local boton: TextButton?
local balanceo = 0

local function soltar()
	if jugador:GetAttribute("Cargando") then
		Remotes.Cargar:FireServer()
	end
end

local function cambiar()
	local llevando = jugador:GetAttribute("Cargando") ~= nil
	TweenService:Create(aviso, TweenInfo.new(0.3), {
		TextTransparency = if llevando then 0.25 else 1,
		TextStrokeTransparency = if llevando then 0.6 else 1,
	}):Play()
	if boton then
		boton.Visible = llevando
	end
end

-- Vista más baja y balanceo al andar con peso.
local function mover(dt: number)
	local humanoide = jugador.Character and jugador.Character:FindFirstChildOfClass("Humanoid")
	if not humanoide then
		return
	end
	local llevando = jugador:GetAttribute("Cargando") ~= nil
	local andando = humanoide.MoveDirection.Magnitude > 0.1 and humanoide.WalkSpeed > 0
	if llevando and andando then
		balanceo += dt * (2 + humanoide.WalkSpeed * 0.45)
	end
	local objetivo = if llevando
		then Vector3.new(math.sin(balanceo) * 0.12, -0.35 - math.abs(math.cos(balanceo)) * (if andando then 0.15 else 0), 0)
		else Vector3.zero
	humanoide.CameraOffset = humanoide.CameraOffset:Lerp(objetivo, math.min(1, dt * 8))
end

function CargarVista.start()
	aviso = Ui.texto("", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -56),
		Size = UDim2.fromOffset(300, 26),
		TextSize = 20,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	local tactil = UserInputService.TouchEnabled
	aviso.Text = if tactil then "" else "[E]  " .. Ui.mayusculas(Lang.t(nil, "Drop"))
	aviso.Parent = Ui.hud()
	if tactil then
		local acciones = Ui.hud():FindFirstChild("Acciones") -- donde sale el botón grande de acción (Controles)
		boton = Ui.boton(Lang.t(nil, "Drop"), { Size = UDim2.fromOffset(200, 90), TextSize = 28, Visible = false })
		;(boton :: TextButton).Activated:Connect(soltar)
		;(boton :: TextButton).Parent = acciones or Ui.hud()
	end
	jugador:GetAttributeChangedSignal("Cargando"):Connect(cambiar)
	UserInputService.InputBegan:Connect(function(entrada, procesado)
		if not procesado and (entrada.KeyCode == Enum.KeyCode.E or entrada.KeyCode == Enum.KeyCode.ButtonX) then
			soltar()
		end
	end)
	RunService.RenderStepped:Connect(mover)
end

return CargarVista
