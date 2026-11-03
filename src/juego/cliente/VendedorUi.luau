-- Los tratos del vendedor (servidor: Vendedor). Al hablarle sale abajo un papel oscuro con lo que dice y sus tratos
-- (Config.Vendedor.Trueques); los que no te puedes permitir, apagados. Se cierra con CERRAR, al alejarte o al morir.
-- El cliente solo pide ("Cambiar", n): el servidor lo valida todo.
-- Cuando te acercas, el vendedor gira la cabeza y te sigue con la mirada (solo en tu pantalla: el cuello, en local).
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))

local VendedorUi = {}

local jugador = Players.LocalPlayer
local V, CAT = Config.Vendedor, Config.Objetos
-- Medidas en píxeles de diseño. En el móvil, botones del alto de un dedo, filas más altas y el papel más ancho (con 5
-- tratos mide 562 de alto: cabe en los 655 de un teléfono de 640 × 360).
local TACTIL = Ui.tactil()
local ANCHO = if TACTIL then 700 else 600
local BOTON = Ui.alto(42) -- CAMBIAR
local CERRAR = Ui.alto(40)
local PASO = BOTON + (if TACTIL then 8 else 10) -- de un trato al siguiente
local ARRIBA = math.max(80, 14 + CERRAR + 12) -- donde empieza el primer trato
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
	panel.Size = UDim2.fromOffset(ANCHO, ARRIBA + 16 + #V.Trueques * PASO)
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
		Size = UDim2.new(1, -190, 0, math.max(54, CERRAR)),
		TextSize = 22,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 11,
	})
	dice.Parent = panel
	local salir = Ui.boton(Lang.t(nil, "Close"), {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(150, CERRAR),
		TextSize = 20,
		ZIndex = 11,
	})
	salir.Activated:Connect(cerrar)
	salir.Parent = panel

	for i, trato in V.Trueques do
		local y = ARRIBA + (i - 1) * PASO
		local texto = Ui.texto(Ui.mayusculas(Lang.t(nil, "{give} for {take}", { give = cosas(trato.Da[1], trato.Da[2]),
			take = cosas(trato.Pide[1], trato.Pide[2]) })), {
			Position = UDim2.fromOffset(22, y),
			Size = UDim2.new(1, -200, 0, math.max(44, BOTON)),
			TextSize = if TACTIL then 24 else 21,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 11,
		})
		texto.Parent = panel
		local boton = Ui.boton(Lang.t(nil, "Trade"), {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, y),
			Size = UDim2.fromOffset(150, BOTON),
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

-- El vendedor te mira: su cuello (R15) gira hacia tu cámara si estás a menos de MIRA studs, sin pasarse de lo que
-- gira un cuello. Al irte, vuelve despacio a mirar al frente.
local MIRA = 28
local cuellos: { [Motor6D]: { original: CFrame, giro: CFrame } } = setmetatable({}, { __mode = "k" }) :: any
local function mirarte(dt: number)
	local camara = workspace.CurrentCamera
	for _, modelo in CollectionService:GetTagged("Vendedor") do
		local cabeza = modelo:FindFirstChild("Head")
		local cuello = cabeza and cabeza:FindFirstChild("Neck")
		if not (cuello and cuello:IsA("Motor6D") and cuello.Part0 and cabeza:IsA("BasePart")) then
			continue
		end
		local c = cuellos[cuello]
		if not c then
			c = { original = cuello.C0, giro = CFrame.new() }
			cuellos[cuello] = c
		end
		local destino = CFrame.new()
		local hacia = camara.CFrame.Position - cabeza.Position
		if hacia.Magnitude < MIRA then
			local d = ((cuello.Part0 :: BasePart).CFrame * c.original):VectorToObjectSpace(hacia)
			local giro = math.clamp(math.atan2(-d.X, -d.Z), math.rad(-70), math.rad(70))
			local alto = math.clamp(math.atan2(d.Y, Vector2.new(d.X, d.Z).Magnitude), math.rad(-30), math.rad(30))
			destino = CFrame.Angles(0, giro, 0) * CFrame.Angles(alto, 0, 0)
		end
		c.giro = c.giro:Lerp(destino, 1 - math.exp(-dt * 4))
		cuello.C0 = c.original * c.giro
	end
end

function VendedorUi.start()
	construir()
	RunService.Heartbeat:Connect(mirarte)
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
