-- Botones de revivir pagando (lo valida y lo hace juego/servidor/Revivir). Salen solo de noche y mientras el
-- servidor dice que se puede (atributo "Revivible" del muerto):
--   Muerto tú: un botón abajo, encima del nombre del que miras.
--   Vivo y con un compañero muerto: un botón pequeño a la izquierda por cada uno.
-- El cliente solo pide (remote Compra "Revivir"); Roblox enseña el precio de verdad al confirmar.
-- En el ordenador el ratón va bloqueado en primera persona y los de los compañeros no se pueden pulsar: la V (en el
-- mando, la cruceta a la izquierda) pulsa el botón que haya, el de arriba si son varios, y en el ordenador lo lleva
-- delante ("[V] REVIVIR A ANA").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Prueba = require(ReplicatedStorage.Shared.Prueba)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))

local RevivirUi = {}

local jugador = Players.LocalPlayer
local ROBUX = "\u{E002}" -- el símbolo de Robux (lo pintan todas las fuentes)

local propio: TextButton
local otros: Frame
local botones: { [Player]: TextButton } = {}

local function pedir(quien: Player)
	Remotes.Compra:FireServer("Revivir", quien)
end

local function precio(): string
	return `{ROBUX}{Config.Compras.Revivir.Robux}`
end

-- Ordenador: teclado sin pantalla táctil (como las teclas de MochilaUi).
local function conTecla(): boolean
	return UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled
end

-- El botón de un compañero: el nombre (que se corta si es largo) y el precio aparte, para que siempre se vea. En el
-- móvil, estrecho y en dos líneas (el nombre arriba, el precio abajo): tres botones (16 + 3 · 144 + 2 · 8 = 464) acaban
-- antes del cartel de pila y fotos (EquipoVista) y de la cuenta de bengalas, que van en la misma altura en el centro.
local function nuevoBoton(): TextButton
	local tactil = Ui.tactil()
	local b = Ui.boton("", { Size = UDim2.fromOffset(if tactil then 144 else 300, Ui.alto(40)) })
	local nombre = Ui.texto("", {
		Name = "Nombre",
		Position = UDim2.new(0, 8, 0, if tactil then 8 else 0),
		Size = if tactil then UDim2.new(1, -16, 0.5, -8) else UDim2.new(1, -80, 1, 0),
		TextSize = if tactil then 16 else 17,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = if tactil then Enum.TextXAlignment.Center else Enum.TextXAlignment.Left,
		TextStrokeTransparency = 1,
	})
	nombre.Parent = b
	local cuanto = Ui.texto(precio(), {
		Name = "Precio",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, if tactil then -8 else 0),
		Size = if tactil then UDim2.new(1, -16, 0.5, -8) else UDim2.new(0, 64, 1, 0),
		TextSize = if tactil then 20 else 17,
		TextXAlignment = if tactil then Enum.TextXAlignment.Center else Enum.TextXAlignment.Right,
		TextStrokeTransparency = 1,
	})
	cuanto.Parent = b
	return b
end

local function pintar()
	-- Sin producto creado no hay nada que comprar (salvo probando en Studio).
	local hay = Config.Compras.Revivir.Id > 0 or Prueba.activa()
	propio.Visible = hay and jugador:GetAttribute("Revivible") == true
	local yoVivo = not jugador:GetAttribute("Muerto")
	local primero = true
	for orden, otro in Players:GetPlayers() do
		local se = hay and yoVivo and otro ~= jugador and otro:GetAttribute("Revivible") == true
		local b = botones[otro]
		if se and not b then
			b = nuevoBoton()
			b.Activated:Connect(function()
				pedir(otro)
			end)
			b.Parent = otros
			botones[otro] = b
		elseif not se and b then
			b:Destroy()
			botones[otro] = nil
			b = nil
		end
		if b then
			-- En el orden de Players: el de arriba es el de la V (ver start), que la lleva delante del texto porque un
			-- nombre largo se corta por el final (solo el nombre: el precio va aparte y siempre se ve).
			b.LayoutOrder = orden
			local texto = Ui.mayusculas(Lang.t(nil, "Revive {nombre}", { nombre = otro.DisplayName }))
			local nombre = b:FindFirstChild("Nombre") :: TextLabel
			nombre.Text = if primero and conTecla() then "[V] " .. texto else texto
			primero = false
		end
	end
	for otro, b in botones do
		if otro.Parent ~= Players then
			b:Destroy()
			botones[otro] = nil
		end
	end
end

local function vigilar(otro: Player)
	otro:GetAttributeChangedSignal("Revivible"):Connect(pintar)
	otro:GetAttributeChangedSignal("Muerto"):Connect(pintar)
end

function RevivirUi.start()
	local hud = Ui.hud()
	propio = Ui.boton(Lang.t(nil, "Revive  {price}", { price = precio() }), {
		Name = "Revivir",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.89),
		Size = UDim2.fromOffset(260, Ui.alto(56)),
		TextSize = 26,
		Visible = false,
		ZIndex = 97, -- encima de la capa de muerto (MuerteVista)
	})
	propio.Activated:Connect(function()
		pedir(jugador)
	end)
	propio.Parent = hud

	-- Los de los compañeros: a la izquierda en el ordenador. En el móvil, en fila arriba a la izquierda, bajo la barra
	-- de Roblox: más abajo estarían en la zona del joystick y se pulsarían sin querer al andar.
	local tactil = Ui.tactil()
	otros = Instance.new("Frame")
	otros.Name = "RevivirOtros"
	otros.AnchorPoint = Vector2.new(0, if tactil then 0 else 0.5)
	otros.Position = if tactil then UDim2.new(0, 16, 0.17, 0) else UDim2.new(0, 16, 0.42, 0)
	otros.Size = if tactil then UDim2.new(1, -32, 0, Ui.DEDO) else UDim2.fromOffset(300, 200)
	otros.BackgroundTransparency = 1
	local lista = Instance.new("UIListLayout")
	lista.Padding = UDim.new(0, 8)
	lista.FillDirection = if tactil then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	lista.SortOrder = Enum.SortOrder.LayoutOrder
	lista.Parent = otros
	otros.Parent = hud

	-- La V (o la cruceta a la izquierda) hace lo mismo que el botón que se ve: muerto, el tuyo; vivo, el de arriba.
	-- Con el HUD escondido (cinemáticas) no hay botón que pulsar.
	UserInputService.InputBegan:Connect(function(entrada, procesado)
		local tecla = entrada.KeyCode
		if procesado or not hud.Enabled or not (tecla == Enum.KeyCode.V or tecla == Enum.KeyCode.DPadLeft) then
			return
		end
		if propio.Visible then
			pedir(jugador)
			return
		end
		for _, otro in Players:GetPlayers() do
			if botones[otro] then
				pedir(otro)
				return
			end
		end
	end)

	Players.PlayerAdded:Connect(vigilar)
	Players.PlayerRemoving:Connect(function()
		task.defer(pintar)
	end)
	for _, otro in Players:GetPlayers() do
		vigilar(otro)
	end
	pintar()
end

return RevivirUi
