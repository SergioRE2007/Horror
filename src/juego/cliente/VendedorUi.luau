-- Los tratos del vendedor (servidor: Vendedor). Al hablarle sale abajo un papel oscuro con lo que dice y sus tratos
-- (Config.Vendedor.Trueques); los que no te puedes permitir, apagados. Se cierra con CERRAR, al alejarte o al morir.
-- El cliente solo pide ("Cambiar", n): el servidor lo valida todo.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))

local VendedorUi = {}

local jugador = Players.LocalPlayer
local V, CAT = Config.Vendedor, Config.Objetos
local panel: TextButton
local dice: TextLabel
local filas: { { texto: TextLabel, boton: TextButton } } = {}
local abierto = 0 -- sube cada vez que se abre: el bucle viejo de cerrar se para

local function cosas(tipo: string, n: number): string
	return Lang.t(nil, "{n} × {thing}", { n = n, thing = Lang.t(nil, CAT[tipo].Nombre) })
end

-- Cuántas de cada cosa llevo (la mochila que publica el servidor).
local function llevo(): { [string]: number }
	local cuenta = {}
	local ok, r = pcall(HttpService.JSONDecode, HttpService, jugador:GetAttribute("Mochila") or "")
	if ok and type(r) == "table" and type(r.cosas) == "table" then
		for _, c in r.cosas do
			cuenta[c.tipo] = (cuenta[c.tipo] or 0) + 1
		end
	end
	return cuenta
end

local function pintar()
	local cuenta = llevo()
	for i, trato in V.Trueques do
		local puedo = (cuenta[trato.Pide[1]] or 0) >= trato.Pide[2]
		filas[i].texto.TextTransparency = if puedo then 0 else 0.55
		filas[i].boton.TextTransparency = if puedo then 0 else 0.6
	end
end

local function cerrar()
	abierto += 1
	panel.Visible = false
	panel.Modal = false
end

local function cerca(): boolean
	local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not raiz or jugador:GetAttribute("Muerto") then
		return false
	end
	for _, modelo in CollectionService:GetTagged("Vendedor") do
		local mando = modelo:FindFirstChild("Mando") :: BasePart?
		if mando and (mando.Position - raiz.Position).Magnitude <= V.Alcance then
			return true
		end
	end
	return false
end

local function abrir(frase: string)
	abierto += 1
	local mio = abierto
	dice.Text = "“" .. frase .. "”"
	pintar()
	panel.Visible = true
	panel.Modal = true -- suelta el ratón en primera persona
	task.spawn(function()
		while abierto == mio do
			task.wait(0.25)
			if abierto == mio and not cerca() then
				cerrar()
			end
		end
	end)
end

local function construir()
	panel = Instance.new("TextButton")
	panel.Name = "Vendedor"
	panel.Text = ""
	panel.AutoButtonColor = false
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -24)
	panel.Size = UDim2.fromOffset(600, 96 + #V.Trueques * 52)
	panel.BackgroundColor3 = Ui.Color.Papel
	panel.BackgroundTransparency = 0.08
	panel.ClipsDescendants = true
	panel.Visible = false
	panel.ZIndex = 10
	local borde = Instance.new("UIStroke")
	borde.Color = Ui.Color.Hueso
	borde.Transparency = 0.75
	borde.Parent = panel
	Ui.mancha(panel)

	dice = Ui.texto("", {
		Position = UDim2.fromOffset(22, 14),
		Size = UDim2.new(1, -190, 0, 54),
		TextSize = 22,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 11,
	})
	dice.Parent = panel
	local salir = Ui.boton(Lang.t(nil, "Close"), {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(150, 40),
		TextSize = 20,
		ZIndex = 11,
	})
	salir.Activated:Connect(cerrar)
	salir.Parent = panel

	for i, trato in V.Trueques do
		local y = 80 + (i - 1) * 52
		local texto = Ui.texto(Ui.mayusculas(Lang.t(nil, "{give} for {take}", { give = cosas(trato.Da[1], trato.Da[2]),
			take = cosas(trato.Pide[1], trato.Pide[2]) })), {
			Position = UDim2.fromOffset(22, y),
			Size = UDim2.new(1, -200, 0, 44),
			TextSize = 21,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 11,
		})
		texto.Parent = panel
		local boton = Ui.boton(Lang.t(nil, "Trade"), {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, y),
			Size = UDim2.fromOffset(150, 42),
			TextSize = 20,
			ZIndex = 11,
		})
		boton.Activated:Connect(function()
			Remotes.Vendedor:FireServer("Cambiar", i)
		end)
		boton.Parent = panel
		filas[i] = { texto = texto, boton = boton }
	end
	panel.Parent = Ui.hud()
end

function VendedorUi.start()
	construir()
	Remotes.Vendedor.OnClientEvent:Connect(function(que, frase)
		if que == "Abrir" and type(frase) == "string" then
			abrir(frase)
		end
	end)
	jugador:GetAttributeChangedSignal("Mochila"):Connect(function()
		if panel.Visible then
			pintar()
		end
	end)
end

return VendedorUi
