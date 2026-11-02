-- Botones de revivir pagando (lo valida y lo hace juego/servidor/Revivir). Salen solo de noche y mientras el
-- servidor dice que se puede (atributo "Revivible" del muerto):
--   Muerto tú: un botón abajo, encima del nombre del que miras.
--   Vivo y con un compañero muerto: un botón pequeño a la izquierda por cada uno.
-- El cliente solo pide (remote Compra "Revivir"); Roblox enseña el precio de verdad al confirmar.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local function pintar()
	-- Sin producto creado no hay nada que comprar (salvo probando en Studio).
	local hay = Config.Compras.Revivir.Id > 0 or Prueba.activa()
	propio.Visible = hay and jugador:GetAttribute("Revivible") == true
	local yoVivo = not jugador:GetAttribute("Muerto")
	for _, otro in Players:GetPlayers() do
		local se = hay and yoVivo and otro ~= jugador and otro:GetAttribute("Revivible") == true
		local b = botones[otro]
		if se and not b then
			b = Ui.boton(Lang.t(nil, "Revive {nombre}", { nombre = otro.DisplayName }) .. `  {precio()}`, {
				Size = UDim2.fromOffset(240, Ui.alto(40)),
				TextSize = 17,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
			b.Activated:Connect(function()
				pedir(otro)
			end)
			b.Parent = otros
			botones[otro] = b
		elseif not se and b then
			b:Destroy()
			botones[otro] = nil
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
	propio = Ui.boton(Lang.t(nil, "Revive") .. `  {precio()}`, {
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
	otros.Size = if tactil then UDim2.new(1, -32, 0, Ui.DEDO) else UDim2.fromOffset(240, 200)
	otros.BackgroundTransparency = 1
	local lista = Instance.new("UIListLayout")
	lista.Padding = UDim.new(0, 8)
	lista.FillDirection = if tactil then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	lista.Parent = otros
	otros.Parent = hud

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
