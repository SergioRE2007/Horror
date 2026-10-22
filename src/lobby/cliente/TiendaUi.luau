-- La tienda del mostrador de la gasolinera (aquí solo se pide y se pinta; compra el servidor en Comun.Tienda).
--   Libreta oscura con tres pestañas: CLASES (comprar; la primera gratis; elegir la que llevas a la partida), LUCES
--   (el color de la linterna) y ROBUX (pases y paquetes de monedas: abre la compra el servidor, Comun.Compras).
--   Comprar con monedas pide dos toques ("¿COMPRAR?") para que no se gasten sin querer; con Robux ya pregunta Roblox.
--   Se cierra con la X o al alejarse del mostrador.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Prueba = require(ReplicatedStorage.Shared.Prueba)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Stats = require(ReplicatedStorage.Shared.Stats)
local Ui = require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))

local TiendaUi = {}

local jugador = Players.LocalPlayer
local LEJOS = 16 -- studs del mostrador a los que se cierra sola
local ROBUX = "\u{E002}" -- el símbolo de Robux (lo pintan todas las fuentes)

local panel: Frame
local escala: UIScale
local monedas: TextLabel
local lista: ScrollingFrame
local pestanas: { [string]: TextButton } = {}
local pestana = "Clases"
local seguro: string? = nil -- el Id que ya ha tocado una vez para comprar
local prompt: ProximityPrompt? = nil

local function texto(frase: string, huecos: { [string]: any }?): string
	return Ui.mayusculas(Lang.t(nil, frase, huecos))
end

local function suyas(atributo: string): { [string]: boolean }
	local ok, t = pcall(HttpService.JSONDecode, HttpService, jugador:GetAttribute(atributo) or "{}")
	return if ok and type(t) == "table" then t else {}
end

-- Lo mismo que Comprar.precioClase en el servidor (solo para enseñarlo).
local function precioClase(clase): number
	for _, tiene in suyas("Clases") do
		if tiene == true then
			return clase.Precio
		end
	end
	return 0
end

-- Una fila de la libreta: nombre, una línea y el botón de la derecha. `marcada` = la que lleva puesta.
local function fila(orden: number, nombre: string, linea: string, boton: string, marcada: boolean, color: Color3?,
	alPulsar: (() -> ())?)
	local f = Instance.new("Frame")
	f.Name = "Fila"
	f.LayoutOrder = orden
	f.Size = UDim2.new(1, -12, 0, 78)
	f.BackgroundColor3 = Ui.Color.Negro
	f.BackgroundTransparency = if marcada then 0.45 else 0.7
	local borde = Instance.new("UIStroke")
	borde.Color = if marcada then Ui.Color.Hueso else Ui.Color.Sangre
	borde.Transparency = if marcada then 0.3 else 0.6
	borde.Parent = f
	local izquierda = 16
	if color then
		-- La muestra del color de la luz.
		local muestra = Instance.new("Frame")
		muestra.AnchorPoint = Vector2.new(0, 0.5)
		muestra.Position = UDim2.new(0, 16, 0.5, 0)
		muestra.Size = UDim2.fromOffset(34, 34)
		muestra.BackgroundColor3 = color
		local redondo = Instance.new("UICorner")
		redondo.CornerRadius = UDim.new(0.5, 0)
		redondo.Parent = muestra
		local brillo = Instance.new("UIStroke")
		brillo.Color = color
		brillo.Thickness = 3
		brillo.Transparency = 0.6
		brillo.Parent = muestra
		muestra.Parent = f
		izquierda = 64
	end
	Ui.texto(Ui.mayusculas(nombre), {
		Position = UDim2.fromOffset(izquierda, 8),
		Size = UDim2.new(1, -izquierda - 196, 0, 30),
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}).Parent = f
	Ui.texto(linea, {
		Position = UDim2.fromOffset(izquierda, 38),
		Size = UDim2.new(1, -izquierda - 196, 0, 34),
		TextSize = 16,
		TextTransparency = 0.25,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}).Parent = f
	local b = Ui.boton(boton, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(170, 46),
		TextSize = 19,
	})
	if not alPulsar then
		b.AutoButtonColor = false
		b.Active = false
		b.TextTransparency = 0.45
	elseif boton == texto("Buy?") then
		b.BackgroundColor3 = Color3.fromRGB(58, 16, 14) -- el segundo toque, con más rojo
	end
	if alPulsar then
		b.Activated:Connect(alPulsar)
	end
	b.Parent = f
	f.Parent = lista
end

local function comprar(accion: string, id: string)
	if seguro == id then
		seguro = nil
		Remotes.Tienda:FireServer(accion, id)
	else
		seguro = id
	end
end

local pintar: () -> ()

-- Botón de comprar de algo que no tiene: el precio, y al primer toque "¿COMPRAR?".
local function botonCompra(accion: string, id: string, precio: number): (string, () -> ())
	local etiqueta = if seguro == id then texto("Buy?")
		elseif precio == 0 then texto("Free")
		else texto("{n} coins", { n = precio })
	return etiqueta, function()
		comprar(accion, id)
		pintar()
	end
end

function pintar()
	for _, hijo in lista:GetChildren() do
		if hijo:IsA("Frame") then
			hijo:Destroy()
		end
	end
	monedas.Text = texto("{n} coins", { n = math.floor(jugador:GetAttribute("Monedas") or 0) })
	for nombre, b in pestanas do
		local borde = b:FindFirstChildOfClass("UIStroke") :: UIStroke
		borde.Color = if nombre == pestana then Ui.Color.Hueso else Ui.Color.Sangre
		b.TextTransparency = if nombre == pestana then 0 else 0.35
	end
	if pestana == "Clases" then
		local tiene = suyas("Clases")
		local elegida = jugador:GetAttribute("Clase")
		for i, clase in Config.Clases do
			local nombre, linea = Lang.t(nil, clase.Nombre), Lang.t(nil, clase.Texto)
			if tiene[clase.Id] ~= true then
				local etiqueta, alPulsar = botonCompra("Clase", clase.Id, precioClase(clase))
				fila(i, nombre, linea, etiqueta, false, nil, alPulsar)
			elseif elegida == clase.Id then
				fila(i, nombre, linea, texto("Chosen"), true)
			else
				fila(i, nombre, linea, texto("Choose"), false, nil, function()
					seguro = nil
					Remotes.Clase:FireServer(clase.Id)
				end)
			end
		end
	elseif pestana == "Robux" then
		-- Sin Id aún no se puede comprar (salvo probando en Studio): el botón sale apagado.
		local function boton(producto): (string, boolean)
			return `{ROBUX}{producto.Robux}`, producto.Id > 0 or Prueba.activa()
		end
		for i, pase in Config.Compras.Pases do
			local nombre, linea = Lang.t(nil, pase.Nombre), Lang.t(nil, pase.Texto)
			if Stats.pase(jugador, pase.Ventaja) then
				fila(i, nombre, linea, texto("Owned"), true)
			else
				local etiqueta, se = boton(pase)
				fila(i, nombre, linea, etiqueta, false, nil, if se then function()
					Remotes.Compra:FireServer("Pase", pase.Ventaja)
				end else nil)
			end
		end
		for i, paquete in Config.Compras.Monedas do
			local etiqueta, se = boton(paquete)
			fila(100 + i, Lang.t(nil, "{n} coins", { n = paquete.Monedas }), Lang.t(nil, "For classes and lights."),
				etiqueta, false, nil, if se then function()
					Remotes.Compra:FireServer("Monedas", i)
				end else nil)
		end
	else
		local tiene = suyas("Cosmeticos")
		local puesta = jugador:GetAttribute("PuestoLinterna")
		local linea = Lang.t(nil, "The color of your flashlight.")
		fila(0, Lang.t(nil, "Warm light"), linea, if puesta then texto("Use") else texto("In use"), puesta == nil,
			Color3.fromRGB(255, 236, 205), if puesta then function()
				seguro = nil
				Remotes.Tienda:FireServer("Poner", "Linterna", "")
			end else nil)
		for i, cosa in Config.Cosmeticos do
			if cosa.Tipo ~= "Linterna" then
				continue
			end
			local nombre = Lang.t(nil, cosa.Nombre)
			local color = Color3.fromRGB(table.unpack(cosa.Color))
			if tiene[cosa.Id] ~= true then
				local etiqueta, alPulsar = botonCompra("Cosmetico", cosa.Id, cosa.Precio)
				fila(i, nombre, linea, etiqueta, false, color, alPulsar)
			elseif puesta == cosa.Id then
				fila(i, nombre, linea, texto("In use"), true, color)
			else
				fila(i, nombre, linea, texto("Use"), false, color, function()
					seguro = nil
					Remotes.Tienda:FireServer("Poner", "Linterna", cosa.Id)
				end)
			end
		end
	end
end

local function cerrar()
	if not panel.Visible then
		return
	end
	seguro = nil
	panel.Visible = false
	if prompt then
		prompt.Enabled = true
	end
end

local function abrir()
	seguro = nil
	pintar()
	panel.Visible = true
	escala.Scale = 0.94
	TweenService:Create(escala, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	if prompt then
		prompt.Enabled = false -- (solo en este cliente)
	end
end

local function construir()
	panel = Instance.new("Frame")
	panel.Name = "Tienda"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.fromOffset(680, 540)
	panel.BackgroundColor3 = Ui.Color.Papel
	panel.BackgroundTransparency = 0.04
	panel.ClipsDescendants = true
	panel.Visible = false
	escala = Instance.new("UIScale")
	escala.Parent = panel
	local borde = Instance.new("UIStroke")
	borde.Color = Ui.Color.Hueso
	borde.Transparency = 0.75
	borde.Parent = panel
	Ui.mancha(panel)

	Ui.texto(texto("Shop"), {
		Position = UDim2.fromOffset(26, 16),
		Size = UDim2.fromOffset(240, 44),
		TextSize = 36,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = panel
	monedas = Ui.texto("", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -78, 0, 20),
		Size = UDim2.fromOffset(300, 36),
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Right,
	})
	monedas.Parent = panel
	local x = Ui.boton("X", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 16),
		Size = UDim2.fromOffset(48, 44),
		TextSize = 24,
	})
	x.Activated:Connect(cerrar)
	x.Parent = panel

	-- Raya bajo el título, como una hoja de libreta.
	local raya = Instance.new("Frame")
	raya.Position = UDim2.fromOffset(26, 70)
	raya.Size = UDim2.new(1, -52, 0, 2)
	raya.BackgroundColor3 = Ui.Color.Sangre
	raya.BackgroundTransparency = 0.3
	raya.BorderSizePixel = 0
	raya.Parent = panel

	for i, p in { { "Clases", "Classes" }, { "Linterna", "Lights" }, { "Robux", "Robux" } } do
		local b = Ui.boton(Lang.t(nil, p[2]), {
			Position = UDim2.fromOffset(26 + (i - 1) * 182, 86),
			Size = UDim2.fromOffset(170, 42),
			TextSize = 20,
		})
		b.Activated:Connect(function()
			pestana = p[1]
			seguro = nil
			pintar()
		end)
		b.Parent = panel
		pestanas[p[1]] = b
	end

	lista = Instance.new("ScrollingFrame")
	lista.Name = "Lista"
	lista.Position = UDim2.fromOffset(20, 142)
	lista.Size = UDim2.new(1, -40, 1, -158)
	lista.BackgroundTransparency = 1
	lista.BorderSizePixel = 0
	lista.ScrollBarThickness = 6
	lista.ScrollBarImageColor3 = Ui.Color.Sangre
	lista.AutomaticCanvasSize = Enum.AutomaticSize.Y
	lista.CanvasSize = UDim2.new()
	local orden = Instance.new("UIListLayout")
	orden.Padding = UDim.new(0, 8)
	orden.SortOrder = Enum.SortOrder.LayoutOrder
	orden.Parent = lista
	local margen = Instance.new("UIPadding")
	margen.PaddingTop = UDim.new(0, 4)
	margen.PaddingLeft = UDim.new(0, 6)
	margen.Parent = lista
	lista.Parent = panel
	panel.Parent = Ui.hud()
end

function TiendaUi.start()
	construir()
	local atributos = { "Monedas", "Clases", "Cosmeticos", "Clase", "PuestoLinterna" }
	for _, pase in Config.Compras.Pases do
		table.insert(atributos, `Pase{pase.Ventaja}`)
	end
	for _, atributo in atributos do
		jugador:GetAttributeChangedSignal(atributo):Connect(function()
			if panel.Visible then
				pintar()
			end
		end)
	end
	task.spawn(function()
		local mostrador = workspace:WaitForChild("Mapa"):WaitForChild("Mostrador") :: BasePart
		prompt = mostrador:WaitForChild("Tienda") :: ProximityPrompt
		;(prompt :: ProximityPrompt).Triggered:Connect(abrir)
		-- Cerrarla al alejarse (un bucle lento; solo mira algo mientras está abierta).
		while true do
			task.wait(0.5)
			local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if panel.Visible and (not raiz or (raiz.Position - mostrador.Position).Magnitude > LEJOS) then
				cerrar()
			end
		end
	end)
end

return TiendaUi
