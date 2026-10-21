-- Móvil (pedido por el usuario): mapa con dónde estáis tú y tus amigos. M, botón MÓVIL en el móvil o la cruceta abajo
-- en el mando. El servidor (juego/servidor/Movil) gasta la batería y lo cierra si se acaba (atributos MovilAbierto y
-- Bateria del jugador).
--   El teléfono sube desde abajo a la derecha, como en la mano. Mapa con el norte arriba y tú en el centro (flecha
--   hacia donde miras): la casa, el cobertizo, el caballete, el camino (piezas con la etiqueta "EnMapa"), los árboles
--   que se pueden talar y tus amigos (punto rojo con el nombre; los que quedan lejos, pegados al borde).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))

local MovilUi = {}

local ANCHO, ALTO = 290, 460
local PANTALLA = Vector2.new(ANCHO - 24, ALTO - 44 - 76) -- el mapa en píxeles (debajo, el botón de adorno)
local ESCALA = (PANTALLA.X / 2) / Config.Movil.Radio -- píxeles por stud

local jugador = Players.LocalPlayer
local camara = workspace.CurrentCamera
local telefono: Frame
local mapa: Frame
local mundo: Frame
local flecha: TextLabel
local bateria: Frame
local apagada: Frame
local abierto = false
local lugares: { [Instance]: Frame } = {}
local puntos: { [Player]: Frame } = {}
local refresco = 0

local function esquina(gui: GuiObject, radio: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radio)
	c.Parent = gui
end

local function caja(props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	for clave, valor in props do
		(f :: any)[clave] = valor
	end
	return f
end

-- Las piezas del mapa y los árboles, en píxeles respecto al origen del mundo (x -> derecha, z -> abajo).
local function pintarLugar(pieza: Instance)
	if not pieza:IsA("BasePart") or lugares[pieza] then
		return
	end
	local _, giro, _ = pieza.CFrame:ToOrientation()
	local color = pieza.Color:Lerp(Color3.new(1, 1, 1), 0.25)
	local f = caja({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(pieza.Position.X * ESCALA, pieza.Position.Z * ESCALA),
		Size = UDim2.fromOffset(math.max(2, pieza.Size.X * ESCALA), math.max(2, pieza.Size.Z * ESCALA)),
		Rotation = -math.deg(giro),
		BackgroundColor3 = color,
		ZIndex = 2,
	})
	f.Parent = mundo
	lugares[pieza] = f
end

local function pintarArbol(modelo: Instance)
	local tronco = modelo:FindFirstChild("Tronco") or modelo:FindFirstChild("Mando")
	if lugares[modelo] or not tronco or not tronco:IsA("BasePart") then
		return
	end
	local f = caja({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(tronco.Position.X * ESCALA, tronco.Position.Z * ESCALA),
		Size = UDim2.fromOffset(5, 5),
		BackgroundColor3 = Color3.fromRGB(70, 96, 64),
		ZIndex = 3,
	})
	esquina(f, 3)
	f.Parent = mundo
	lugares[modelo] = f
end

local function limpiar()
	for cosa, f in lugares do
		if not cosa.Parent then
			f:Destroy()
			lugares[cosa] = nil
		elseif CollectionService:HasTag(cosa, "Arbol") then
			f.Visible = cosa:GetAttribute("Talado") == nil
		end
	end
end

local function puntoDe(otro: Player): Frame
	local f = puntos[otro]
	if f then
		return f
	end
	f = caja({ AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = Color3.fromRGB(170, 30, 30), ZIndex = 6 })
	esquina(f, 5)
	local nombre = Ui.texto(otro.DisplayName, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -2),
		Size = UDim2.fromOffset(120, 16),
		TextSize = 14,
		ZIndex = 6,
	})
	nombre.Parent = f
	f.Parent = mapa
	puntos[otro] = f
	return f
end

local function actualizar(dt: number)
	if not abierto then
		return
	end
	local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local centro = if raiz then raiz.Position else camara.CFrame.Position
	mundo.Position = UDim2.new(0.5, -centro.X * ESCALA, 0.5, -centro.Z * ESCALA)
	local mira = camara.CFrame.LookVector
	flecha.Rotation = math.deg(math.atan2(mira.X, -mira.Z))
	for _, otro in Players:GetPlayers() do
		if otro == jugador then
			continue
		end
		-- Cerca, su personaje; lejos puede no estar en este cliente: lo que publica el servidor (Movil, "Donde").
		local suya = otro.Character and otro.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local donde = if suya then Vector2.new(suya.Position.X, suya.Position.Z) else otro:GetAttribute("Donde")
		local f = puntoDe(otro)
		f.Visible = typeof(donde) == "Vector2" and not otro:GetAttribute("Muerto")
		if typeof(donde) == "Vector2" then
			local d = (donde - Vector2.new(centro.X, centro.Z)) * ESCALA
			local borde = PANTALLA / 2 - Vector2.new(8, 8)
			local fuera = math.max(math.abs(d.X) / borde.X, math.abs(d.Y) / borde.Y)
			if fuera > 1 then
				d /= fuera -- lejos: pegado al borde, en su dirección
			end
			f.Position = UDim2.new(0.5, d.X, 0.5, d.Y)
		end
	end
	for otro, f in puntos do
		if not otro.Parent then
			f:Destroy()
			puntos[otro] = nil
		end
	end
	refresco += dt
	if refresco > 1 then
		refresco = 0
		limpiar()
	end
end

local function pintarBateria()
	local b = math.clamp(jugador:GetAttribute("Bateria") or 0, 0, 1)
	bateria.Size = UDim2.fromScale(b, 1)
	bateria.BackgroundColor3 = if b < 0.2 then Ui.Color.Sangre else Ui.Color.Hueso
	apagada.Visible = b <= 0
end

local function mostrar(si: boolean)
	abierto = si
	if si then
		limpiar()
		pintarBateria()
		telefono.Visible = true
	end
	local tween = TweenService:Create(telefono, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = if si then UDim2.new(0.68, 0, 1, -16) else UDim2.new(0.68, 0, 1, ALTO + 40),
	})
	tween:Play()
	if not si then
		tween.Completed:Once(function()
			if not abierto then
				telefono.Visible = false
			end
		end)
	end
end

local function alternar()
	if jugador:GetAttribute("MovilAbierto") then
		Remotes.Movil:FireServer(false)
		mostrar(false)
	else
		Remotes.Movil:FireServer(true)
	end
end

local function crear()
	telefono = caja({
		Name = "Movil",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.68, 0, 1, ALTO + 40),
		Size = UDim2.fromOffset(ANCHO, ALTO),
		BackgroundColor3 = Color3.fromRGB(14, 14, 16),
		Visible = false,
		ZIndex = 20,
	})
	esquina(telefono, 26)
	local borde = Instance.new("UIStroke")
	borde.Color = Color3.fromRGB(50, 50, 54)
	borde.Thickness = 3
	borde.Parent = telefono

	-- Barra de arriba: solo la batería.
	local pila = caja({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -22, 0, 16),
		Size = UDim2.fromOffset(34, 14),
		BackgroundColor3 = Color3.fromRGB(14, 14, 16),
		ZIndex = 21,
	})
	local marco = Instance.new("UIStroke")
	marco.Color = Ui.Color.Hueso
	marco.Thickness = 1.5
	marco.Parent = pila
	bateria = caja({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Ui.Color.Hueso, ZIndex = 22 })
	bateria.Parent = pila
	pila.Parent = telefono

	mapa = caja({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 44),
		Size = UDim2.fromOffset(PANTALLA.X, PANTALLA.Y),
		BackgroundColor3 = Color3.fromRGB(34, 40, 34),
		ClipsDescendants = true,
		ZIndex = 21,
	})
	esquina(mapa, 10)
	mapa.Parent = telefono
	mundo = caja({ Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, ZIndex = 1 })
	mundo.Parent = mapa
	flecha = Ui.texto("▲", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(18, 18),
		TextSize = 18,
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 7,
	})
	flecha.Parent = mapa
	apagada = caja({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), Visible = false, ZIndex = 30 })
	esquina(apagada, 10)
	apagada.Parent = mapa

	-- Debajo del mapa, nada: un botón de inicio de adorno.
	local inicio = caja({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = Color3.fromRGB(28, 28, 30),
		ZIndex = 21,
	})
	esquina(inicio, 20)
	inicio.Parent = telefono
	telefono.Parent = Ui.hud()

	for _, pieza in CollectionService:GetTagged("EnMapa") do
		pintarLugar(pieza)
	end
	CollectionService:GetInstanceAddedSignal("EnMapa"):Connect(pintarLugar)
	for _, arbol in CollectionService:GetTagged("Arbol") do
		pintarArbol(arbol)
	end
	CollectionService:GetInstanceAddedSignal("Arbol"):Connect(function(arbol)
		task.defer(pintarArbol, arbol)
	end)

	-- Móvil: botón MÓVIL junto a los del equipo.
	if UserInputService.TouchEnabled then
		local botones = Ui.hud():FindFirstChild("EquipoBotones")
		if botones then
			local boton = Ui.boton(Lang.t(nil, "Phone"), { Size = UDim2.fromOffset(140, 80), TextSize = 22, LayoutOrder = -2 })
			boton.Activated:Connect(alternar)
			boton.Parent = botones
		end
	end
end

function MovilUi.start()
	crear()
	jugador:GetAttributeChangedSignal("MovilAbierto"):Connect(function()
		mostrar(jugador:GetAttribute("MovilAbierto") == true)
	end)
	jugador:GetAttributeChangedSignal("Bateria"):Connect(pintarBateria)
	UserInputService.InputBegan:Connect(function(entrada, procesado)
		if not procesado and (entrada.KeyCode == Enum.KeyCode.M or entrada.KeyCode == Enum.KeyCode.DPadDown) then
			alternar()
		end
	end)
	RunService.RenderStepped:Connect(actualizar)
end

return MovilUi
