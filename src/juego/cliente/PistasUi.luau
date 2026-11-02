-- Leer una pista (servidor: Pistas). Sale en el centro un papel oscuro con la esquina manchada de sangre: arriba, en
-- rojo, lo que es ("Nota del rico"); debajo lo que pone; abajo, cuántas llevamos ("3 de 12", pequeño) y CERRAR.
-- Se cierra con CERRAR, volviendo a pulsar E en la misma pista, al alejarse o al morir. Solo enseña: el servidor no
-- espera nada de vuelta.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")

local Historia = require(ReplicatedStorage.Shared.Historia)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))

local PistasUi = {}

local ALCANCE = 11 -- studs: más lejos de la pista, se cierra
local ANCHO = 560 -- del papel, en píxeles (el alto sale del texto)
local ROJO = Color3.fromRGB(150, 34, 28) -- más claro que Ui.Color.Sangre: sobre el papel oscuro tiene que leerse

local jugador = Players.LocalPlayer
local panel: TextButton
local que: TextLabel
local texto: TextLabel
local cuenta: TextLabel
local escala: UIScale
local abierta = 0 -- la pista que se está leyendo (0 = ninguna)
local vez = 0 -- sube cada vez que se abre o se cierra: el bucle viejo de cerrar se para

local function cerrar()
	vez += 1
	abierta = 0
	panel.Visible = false
	panel.Modal = false
end

-- La pieza de la pista n en el mundo (para saber si me he alejado).
local function dondeEsta(n: number): BasePart?
	for _, modelo in CollectionService:GetTagged("Pista") do
		if modelo:GetAttribute("N") == n and modelo:IsA("Model") then
			return modelo.PrimaryPart
		end
	end
	return nil
end

local function cerca(n: number): boolean
	local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local donde = dondeEsta(n)
	if not raiz or jugador:GetAttribute("Muerto") then
		return false
	end
	return donde == nil or (donde.Position - raiz.Position).Magnitude <= ALCANCE -- sin la pieza (streaming): no se cierra por eso
end

local function abrir(n: number, encontradas: number)
	local pista = Historia[n]
	if not pista then
		return
	end
	if panel.Visible and abierta == n then
		cerrar() -- E otra vez en la misma: se guarda el papel
		return
	end
	vez += 1
	local mia = vez
	abierta = n
	que.Text = Ui.mayusculas(Lang.t(nil, pista.que))
	texto.Text = Lang.t(nil, pista.texto)
	-- El papel, tan alto como el texto (las cortas no dejan medio papel vacío).
	local alto = TextService:GetTextSize(texto.Text, texto.TextSize, Enum.Font.SpecialElite, Vector2.new(ANCHO - 64, 1000)).Y
	panel.Size = UDim2.fromOffset(ANCHO, math.max(200, math.ceil(alto * texto.LineHeight) + 150))
	cuenta.Text = Lang.t(nil, "{n} of {total}", { n = encontradas, total = #Historia })
	panel.Visible = true
	panel.Modal = true -- suelta el ratón en primera persona
	escala.Scale = 0.92
	TweenService:Create(escala, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.spawn(function()
		while vez == mia do
			task.wait(0.25)
			if vez == mia and not cerca(n) then
				cerrar()
			end
		end
	end)
end

local function construir()
	panel = Instance.new("TextButton")
	panel.Name = "Pista"
	panel.Text = ""
	panel.AutoButtonColor = false
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.46)
	panel.Size = UDim2.fromOffset(ANCHO, 300)
	panel.BackgroundColor3 = Ui.Color.Papel
	panel.BackgroundTransparency = 0.05
	panel.ClipsDescendants = true
	panel.Visible = false
	panel.ZIndex = 20
	escala = Instance.new("UIScale")
	escala.Parent = panel
	local borde = Instance.new("UIStroke")
	borde.Color = Ui.Color.Hueso
	borde.Transparency = 0.75
	borde.Parent = panel
	Ui.mancha(panel).ZIndex = 20

	que = Ui.texto("", {
		Position = UDim2.fromOffset(32, 22),
		Size = UDim2.new(1, -64, 0, 26),
		TextSize = 19,
		TextColor3 = ROJO,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 21,
	})
	que.Parent = panel
	texto = Ui.texto("", {
		Position = UDim2.fromOffset(32, 60),
		Size = UDim2.new(1, -64, 1, -136),
		TextSize = 24,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LineHeight = 1.15,
		ZIndex = 21,
	})
	texto.Parent = panel
	cuenta = Ui.texto("", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 32, 1, -22),
		Size = UDim2.fromOffset(160, 28),
		TextSize = 17,
		TextTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 21,
	})
	cuenta.Parent = panel
	local salir = Ui.boton(Lang.t(nil, "Close"), {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, -16),
		Size = UDim2.fromOffset(150, 40),
		TextSize = 20,
		ZIndex = 21,
	})
	salir.Activated:Connect(cerrar)
	salir.Parent = panel
	panel.Parent = Ui.hud()
end

function PistasUi.start()
	construir()
	Remotes.Pista.OnClientEvent:Connect(function(n, encontradas)
		if type(n) == "number" and type(encontradas) == "number" then
			abrir(n, encontradas)
		end
	end)
end

return PistasUi
