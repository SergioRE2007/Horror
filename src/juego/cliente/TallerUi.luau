-- Los bancos del taller (servidor: Taller). Al usar uno sale abajo un papel oscuro con sus recetas
-- (Recetas.delBanco: las de Config.Taller.Bancos y, en el sótano, la reja del final si ya se leyó su pista; el servidor
-- manda cuáles no enseñar): lo que sale y lo que pide; las que no te llegan, apagadas. Lo pesado que pide (tablones) cuenta
-- si está suelto junto al banco. Se cierra con CERRAR, al alejarte, al morir o al ponerte a trabajar.
-- El cliente solo pide ("Hacer", n): el servidor lo valida todo. También suena el cierre de las trampas ("Trampa").
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Recetas = require(ReplicatedStorage.Shared.Recetas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sonido = require(script.Parent.Sonido)
local Ui = require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))

local TallerUi = {}

local jugador = Players.LocalPlayer
local T = Config.Taller
-- Medidas en píxeles de diseño. En el móvil, botones del alto de un dedo, filas más altas y el papel más ancho.
local TACTIL = Ui.tactil()
local ANCHO = if TACTIL then 700 else 640
local BOTON = Ui.alto(42) -- HACER
local CERRAR = Ui.alto(40)
local PASO = BOTON + 10 -- de una receta a la siguiente
local ARRIBA = math.max(80, 14 + CERRAR + 12) -- donde empieza la primera receta
local panel: TextButton
local titulo: TextLabel
local filas: { { texto: TextLabel, boton: TextButton } } = {}
local banco: Model? = nil
local ocultas: { [number]: boolean } = {} -- recetas del banco abierto que aún no se enseñan (la reja, sin su pista)
local abierto = 0 -- sube cada vez que se abre o se cierra: el bucle viejo de cerrar se para

local function nombre(tipo: string): string
	local datos = Config.Objetos[tipo] or Config.Pesados[tipo]
	return Lang.t(nil, datos.Nombre)
end

-- Lo que hay: la mochila que publica el servidor y lo pesado suelto junto al banco.
local function tengo(): { [string]: number }
	local cuenta = {}
	local ok, r = pcall(HttpService.JSONDecode, HttpService, jugador:GetAttribute("Mochila") or "")
	if ok and type(r) == "table" and type(r.cosas) == "table" then
		for _, c in r.cosas do
			cuenta[c.tipo] = (cuenta[c.tipo] or 0) + 1
		end
	end
	local mando = banco and banco:FindFirstChild("Mando") :: BasePart?
	if mando then
		for _, pieza in CollectionService:GetTagged("Pesado") do
			if pieza:IsA("BasePart") and pieza.CollisionGroup ~= "Cargado" and (pieza.Position - mando.Position).Magnitude <= T.Radio then
				local tipo = pieza:GetAttribute("Tipo")
				cuenta[tipo] = (cuenta[tipo] or 0) + 1
			end
		end
	end
	return cuenta
end

local function cerrar()
	abierto += 1
	banco = nil
	panel.Visible = false
	panel.Modal = false
end

local function pintar()
	local recetas = if banco then Recetas.delBanco(banco:GetAttribute("Banco"), Config) else {}
	local cuenta = tengo()
	local vistas = 0
	for i, fila in filas do
		local receta = if ocultas[i] then nil else recetas[i]
		fila.texto.Visible = receta ~= nil
		fila.boton.Visible = receta ~= nil
		if receta then
			-- Una debajo de otra, sin dejar hueco por las ocultas.
			local y = ARRIBA + vistas * PASO
			vistas += 1
			fila.texto.Position = UDim2.fromOffset(22, y)
			fila.boton.Position = UDim2.new(1, -14, 0, y)
			local pide = {}
			for _, p in receta.Pide do
				table.insert(pide, Lang.t(nil, "{n} × {thing}", { n = p[2], thing = nombre(p[1]) }))
			end
			fila.texto.Text = Ui.mayusculas(Lang.t(nil, "{make}: {needs}", { make = nombre(receta.Da), needs = table.concat(pide, ", ") }))
			local puedo = #Recetas.falta(receta.Pide, cuenta) == 0
			fila.texto.TextTransparency = if puedo then 0 else 0.55
			fila.boton.TextTransparency = if puedo then 0 else 0.6
		end
	end
	panel.Size = UDim2.fromOffset(ANCHO, ARRIBA + 16 + vistas * PASO)
end

local function lejos(): boolean
	local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local mando = banco and banco:FindFirstChild("Mando") :: BasePart?
	return not raiz or not mando or jugador:GetAttribute("Muerto") == true or jugador:GetAttribute("Trabajando") ~= nil
		or (mando.Position - raiz.Position).Magnitude > Config.Casa.Alcance + 3
end

local function abrir(nuevo: Model, lista: { number })
	abierto += 1
	local mio = abierto
	banco = nuevo
	ocultas = {}
	for _, n in lista do
		ocultas[n] = true
	end
	titulo.Text = Ui.mayusculas(Lang.t(nil, if nuevo:GetAttribute("Banco") == "Garaje" then "Car workshop" else "Workbench"))
	pintar()
	panel.Visible = true
	panel.Modal = true -- suelta el ratón en primera persona
	task.spawn(function()
		while abierto == mio do
			task.wait(0.25)
			if abierto ~= mio then
				break
			elseif lejos() then
				cerrar()
			else
				pintar() -- lo pesado de alrededor cambia sin avisar
			end
		end
	end)
end

local function construir()
	panel = Instance.new("TextButton")
	panel.Name = "Taller"
	panel.Text = ""
	panel.AutoButtonColor = false
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -24)
	panel.Size = UDim2.fromOffset(ANCHO, 200)
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

	titulo = Ui.texto("", {
		Position = UDim2.fromOffset(22, 14),
		Size = UDim2.new(1, -190, 0, math.max(54, CERRAR)),
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 11,
	})
	titulo.Parent = panel
	local salir = Ui.boton(Lang.t(nil, "Close"), {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14),
		Size = UDim2.fromOffset(150, CERRAR),
		TextSize = 20,
		ZIndex = 11,
	})
	salir.Activated:Connect(cerrar)
	salir.Parent = panel

	local cuantas = 0
	for cual in T.Bancos do
		cuantas = math.max(cuantas, #Recetas.delBanco(cual, Config))
	end
	for i = 1, cuantas do
		local y = ARRIBA + (i - 1) * PASO
		local texto = Ui.texto("", {
			Position = UDim2.fromOffset(22, y),
			Size = UDim2.new(1, -200, 0, math.max(44, BOTON)),
			TextSize = if TACTIL then 22 else 19,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 11,
		})
		texto.Parent = panel
		local boton = Ui.boton(Lang.t(nil, "Make"), {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, y),
			Size = UDim2.fromOffset(150, BOTON),
			TextSize = 20,
			ZIndex = 11,
		})
		boton.Activated:Connect(function()
			Remotes.Taller:FireServer("Hacer", i)
		end)
		boton.Parent = panel
		filas[i] = { texto = texto, boton = boton }
	end
	panel.Parent = Ui.hud()
end

function TallerUi.start()
	construir()
	Remotes.Taller.OnClientEvent:Connect(function(que, dato, lista)
		if que == "Abrir" and typeof(dato) == "Instance" and dato:IsA("Model") then
			abrir(dato, if type(lista) == "table" then lista else {})
		elseif que == "Trampa" and typeof(dato) == "Vector3" then
			Sonido.en("Golpe", dato, 1.5) -- el cepo se cierra de golpe
			Sonido.en("Chillido", dato, 0.8)
		end
	end)
	jugador:GetAttributeChangedSignal("Mochila"):Connect(function()
		if panel.Visible then
			pintar()
		end
	end)
end

return TallerUi
