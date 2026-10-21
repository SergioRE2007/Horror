-- Lo que ves sentado en un coche del lobby (lo manda Coches en el servidor; aquí solo se pide y se pinta).
--   Dueño: sus ranuras de partida (NOCHE N o VACÍA), NUEVA PARTIDA en una ranura con algo guardado (dos toques: se
--   empieza de cero y se pierde lo guardado) y EMPEZAR / CONTINUAR. Los demás: "Esperando a {name}…".
--   Al arrancar, cuenta atrás y fundido a negro (la cinemática del coche entrando en el bosque, más adelante). Si el
--   servidor para el coche (falló o es Studio) o a los 12 s sigue aquí, vuelve la imagen.
--   BAJAR (también saltando).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))

local CochesUi = {}

local jugador = Players.LocalPlayer
local panel: Frame
local titulo: TextLabel
local fila: Frame
local abajo: Frame
local ranuras: { TextButton } = {}
local nueva: TextButton
local empezar: TextButton
local negro: Frame
local seguro = false -- ya ha tocado una vez NUEVA PARTIDA
local fundida = nil -- la Salida para la que ya se ha fundido a negro

local function texto(frase: string, huecos: { [string]: any }?): string
	return Ui.mayusculas(Lang.t(nil, frase, huecos))
end

local function coche(): Model?
	local nombre = jugador:GetAttribute("Coche")
	local carpeta = workspace:FindFirstChild("Coches")
	return if nombre and carpeta then carpeta:FindFirstChild(nombre) :: Model? else nil
end

local function partidas()
	local ok, t = pcall(HttpService.JSONDecode, HttpService, jugador:GetAttribute("Partidas") or "{}")
	return if ok and type(t) == "table" then t else {}
end

local function volver()
	fundida = nil
	TweenService:Create(negro, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
end

local function fundir(salida: number)
	fundida = salida
	panel.Visible = false
	negro.Visible = true
	TweenService:Create(negro, TweenInfo.new(1.2), { BackgroundTransparency = 0 }):Play()
	task.delay(12, function()
		if fundida == salida then -- sigue aquí: no ha salido
			volver()
		end
	end)
end

local function pintar()
	local c = coche()
	if fundida and (not c or c:GetAttribute("Salida") ~= fundida) then
		volver() -- el servidor lo ha parado: no se sale (falló o es Studio) y hay que ver el aviso
	end
	if not c then
		panel.Visible = false
		seguro = false
		return
	end
	local salida = c:GetAttribute("Salida")
	local queda = if salida then salida - workspace:GetServerTimeNow() else nil
	if queda and queda <= 0.3 then -- un poco antes: en Studio el servidor lo para enseguida
		if fundida ~= salida then
			fundir(salida)
		end
		return
	end
	panel.Visible = fundida == nil
	local esDueno = c:GetAttribute("Dueno") == jugador.UserId
	fila.Visible = esDueno
	abajo.Visible = esDueno
	panel.Size = UDim2.fromOffset(620, if esDueno then 214 else 66)
	if not esDueno then
		local dueno = Players:GetPlayerByUserId(c:GetAttribute("Dueno") or 0)
		titulo.Text = if queda then texto("Leaving in {n}…", { n = math.ceil(queda) })
			else texto("Waiting for {name}…", { name = if dueno then dueno.DisplayName else "…" })
		return
	end
	titulo.Text = texto("Choose a game")
	local p = partidas()
	local elegida = c:GetAttribute("Ranura") or 1
	for i, boton in ranuras do
		local guardada = p[tostring(i)]
		boton.Text = `{i}   ` .. if guardada then texto("Night {n}", { n = guardada.noche }) else texto("Empty")
		local borde = boton:FindFirstChildOfClass("UIStroke") :: UIStroke
		borde.Color = if i == elegida then Ui.Color.Hueso else Ui.Color.Sangre
		borde.Thickness = if i == elegida then 3 else 2
		boton.TextTransparency = if i == elegida then 0 else 0.35
	end
	local hay = p[tostring(elegida)] ~= nil
	local empiezaDeCero = c:GetAttribute("Nueva") == true
	nueva.Visible = hay and not queda
	nueva.Text = if empiezaDeCero then texto("Keep my save") elseif seguro then texto("Sure? It erases it") else texto("New game")
	empezar.Text = if queda then texto("Leaving in {n}…", { n = math.ceil(queda) })
		elseif empiezaDeCero then texto("Start over")
		elseif hay then texto("Continue")
		else texto("Start")
end

local function construir()
	local hud = Ui.hud()
	panel = Instance.new("Frame")
	panel.Name = "Coche"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -24)
	panel.Size = UDim2.fromOffset(620, 214)
	panel.BackgroundColor3 = Ui.Color.Papel
	panel.BackgroundTransparency = 0.08
	panel.ClipsDescendants = true
	panel.Visible = false
	local borde = Instance.new("UIStroke")
	borde.Color = Ui.Color.Hueso
	borde.Transparency = 0.75
	borde.Parent = panel
	Ui.mancha(panel)

	titulo = Ui.texto("", {
		Position = UDim2.fromOffset(22, 14),
		Size = UDim2.new(1, -190, 0, 38),
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	titulo.Parent = panel

	local bajar = Ui.boton(Lang.t(nil, "Get out"), {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 12),
		Size = UDim2.fromOffset(150, 40),
		TextSize = 20,
	})
	bajar.Activated:Connect(function()
		local humanoide = jugador.Character and jugador.Character:FindFirstChildOfClass("Humanoid")
		if humanoide then
			humanoide.Sit = false -- (Jump = true desde un script no lo levanta del asiento)
		end
	end)
	bajar.Parent = panel

	fila = Instance.new("Frame")
	fila.Name = "Ranuras"
	fila.BackgroundTransparency = 1
	fila.Position = UDim2.fromOffset(22, 66)
	fila.Size = UDim2.new(1, -44, 0, 70)
	local lista = Instance.new("UIListLayout")
	lista.FillDirection = Enum.FillDirection.Horizontal
	lista.Padding = UDim.new(0, 12)
	lista.SortOrder = Enum.SortOrder.LayoutOrder
	lista.Parent = fila
	for i = 1, Config.Partida.Ranuras do
		local boton = Ui.boton("", {
			LayoutOrder = i,
			Size = UDim2.new(1 / Config.Partida.Ranuras, -8, 1, 0),
			TextSize = 22,
		})
		boton.Activated:Connect(function()
			seguro = false
			Remotes.Coche:FireServer("Ranura", i)
		end)
		boton.Parent = fila
		ranuras[i] = boton
	end
	fila.Parent = panel

	abajo = Instance.new("Frame")
	abajo.Name = "Abajo"
	abajo.BackgroundTransparency = 1
	abajo.Position = UDim2.new(0, 22, 1, -64)
	abajo.Size = UDim2.new(1, -44, 0, 48)
	local lista2 = Instance.new("UIListLayout")
	lista2.FillDirection = Enum.FillDirection.Horizontal
	lista2.HorizontalAlignment = Enum.HorizontalAlignment.Right
	lista2.Padding = UDim.new(0, 12)
	lista2.SortOrder = Enum.SortOrder.LayoutOrder
	lista2.Parent = abajo
	nueva = Ui.boton("", { LayoutOrder = 1, Size = UDim2.fromOffset(250, 48), TextSize = 19 })
	nueva.Activated:Connect(function()
		local c = coche()
		if not c then
			return
		end
		if c:GetAttribute("Nueva") then
			Remotes.Coche:FireServer("Nueva", false)
		elseif seguro then
			seguro = false
			Remotes.Coche:FireServer("Nueva", true)
		else
			seguro = true
		end
		pintar()
	end)
	nueva.Parent = abajo
	empezar = Ui.boton("", { LayoutOrder = 2, Size = UDim2.fromOffset(250, 48), TextSize = 26 })
	empezar.BackgroundColor3 = Color3.fromRGB(58, 16, 14) -- lo principal, con más rojo
	empezar.Activated:Connect(function()
		Remotes.Coche:FireServer("Arrancar")
	end)
	empezar.Parent = abajo
	abajo.Parent = panel
	panel.Parent = hud

	-- El fundido va en su propia capa, por encima de todo el HUD.
	local capa = Instance.new("ScreenGui")
	capa.Name = "Fundido"
	capa.IgnoreGuiInset = true
	capa.DisplayOrder = 100
	capa.ResetOnSpawn = false
	negro = Instance.new("Frame")
	negro.Size = UDim2.fromScale(1, 1)
	negro.BackgroundColor3 = Ui.Color.Negro
	negro.BackgroundTransparency = 1
	negro.BorderSizePixel = 0
	negro.Visible = false
	negro.Parent = capa
	capa.Parent = jugador:WaitForChild("PlayerGui")
end

function CochesUi.start()
	construir()
	jugador:GetAttributeChangedSignal("Coche"):Connect(pintar)
	jugador:GetAttributeChangedSignal("Partidas"):Connect(pintar)
	-- Un solo bucle lento para la cuenta atrás y lo que cambie en el coche (dueño, ranura…).
	task.spawn(function()
		while true do
			task.wait(0.2)
			pintar()
		end
	end)
end

return CochesUi
