-- Ajustes (14.4), en el lobby y en el juego. Un engranaje pequeño dibujado con marcos en la barra de arriba, justo a
-- la derecha de los botones de Roblox de la izquierda (GuiService.TopbarInset): ahí nunca lo tapa nada, tampoco en
-- móvil (arriba a la derecha lo tapan los de Roblox). Al pulsarlo sale en el centro un papel oscuro con la esquina
-- manchada de sangre y la opción RENDIMIENTO (SÍ/NO) y CERRAR.
-- El cliente solo pide (remote Ajustes) y enseña el atributo "Rendimiento" del Player, que pone el servidor
-- (comun/servidor/Ajustes) y se guarda entre partidas. Los módulos de efectos lo leen cada vez que lo usan.
-- En la partida el ratón va bloqueado en primera persona y el engranaje no se puede pulsar: también se abre y se
-- cierra con la P (en el ordenador, con "[P]" a su lado) y con R3 en el mando (la cruceta y L3 ya son de otros:
-- MovilUi, MochilaUi, RevivirUi, TutorialVista y CorrerVista); ButtonB lo cierra.
-- Al entrar por primera vez en un móvil (táctil sin teclado) pide Rendimiento activado: el servidor solo lo acepta si
-- el jugador nunca lo eligió (16.9).
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)

local AjustesUi = {}

local ANCHO = 460 -- del papel, en píxeles
-- En pantallas táctiles los dos botones son de un dedo (Ui.alto): el SÍ/NO baja hasta y 164 y CERRAR necesita sitio.
local ALTO = if Ui.tactil() then 280 else 250
local ROJO = Color3.fromRGB(150, 34, 28) -- como en PistasUi: sobre el papel oscuro tiene que leerse
local HUECO = 6 -- píxeles entre los botones de Roblox y el engranaje
local SIN_BARRA = 12 -- si no hay barra de Roblox (cinemáticas), el engranaje a esta distancia de la esquina
local MANDO = Enum.KeyCode.ButtonR3 -- abre y cierra con el mando (libre: mirar los otros antes de cambiarlo)

local jugador = Players.LocalPlayer
local panel: TextButton
local escalaPanel: UIScale
local titulo: TextLabel
local nombre: TextLabel
local explica: TextLabel
local interruptor: TextButton
local cerrarBoton: TextButton
local engranaje: TextButton
local rueda: Frame

local function activo(): boolean
	return jugador:GetAttribute("Rendimiento") == true
end

-- Textos al abrir (por si ha cambiado el idioma) y cada vez que cambia el ajuste.
local function pintar()
	titulo.Text = Ui.mayusculas(Lang.t(nil, "Settings"))
	nombre.Text = Ui.mayusculas(Lang.t(nil, "Performance"))
	explica.Text = Lang.t(nil, "Fewer particles and effects.")
	cerrarBoton.Text = Ui.mayusculas(Lang.t(nil, "Close"))
	local si = activo()
	interruptor.Text = Ui.mayusculas(Lang.t(nil, if si then "On" else "Off"))
	interruptor.BackgroundColor3 = if si then Ui.Color.Sangre else Ui.Color.Papel
	interruptor.TextTransparency = if si then 0 else 0.35
end

local function cerrar()
	Ui.soltarSeleccion(panel)
	panel.Visible = false
	panel.Modal = false
	-- Ui lo quita en diferido: la misma B que lo cierra no debe agachar (PosturaVista mira VentanaAbierta en esa pulsación).
	Ui.ventanaAbierta("Ajustes", false)
end

local function abrir(conMando: boolean?)
	if panel.Visible then
		cerrar()
		return
	end
	pintar()
	panel.Visible = true
	panel.Modal = true -- suelta el ratón en primera persona
	Ui.ventanaAbierta("Ajustes", true) -- solo en este cliente: con una ventana abierta, B no agacha (PosturaVista)
	escalaPanel.Scale = 0.92
	TweenService:Create(escalaPanel, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	Ui.seleccionar(interruptor, conMando) -- con el mando (o abierto con R3), A cambia el ajuste enseguida
end

-- El engranaje (o la P): gira un cuarto de vuelta y abre o cierra el papel.
local function pulsarEngranaje(conMando: boolean?)
	rueda.Rotation = 0
	TweenService:Create(rueda, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { Rotation = 90 }):Play()
	abrir(conMando)
end

-- Primera vez en un móvil: pide Rendimiento activado en cuanto el servidor ha publicado el ajuste (datos cargados).
-- Se manda en cada entrada; el servidor lo ignora si el jugador ya lo eligió o ya se le sugirió.
local function sugerirEnMovil()
	if not Ui.tactil() or UserInputService.KeyboardEnabled then
		return
	end
	while jugador.Parent and jugador:GetAttribute("Rendimiento") == nil do
		jugador:GetAttributeChangedSignal("Rendimiento"):Wait()
	end
	if jugador.Parent and not activo() then
		Remotes.Ajustes:FireServer("Sugerir", true)
	end
end

local function construirPanel(hud: ScreenGui)
	panel = Instance.new("TextButton")
	panel.Name = "Ajustes"
	panel.Text = ""
	panel.AutoButtonColor = false
	panel.Selectable = false -- el papel de fondo no lo elige el mando (Ui.seleccionar)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.46)
	panel.Size = UDim2.fromOffset(ANCHO, ALTO)
	panel.BackgroundColor3 = Ui.Color.Papel
	panel.BackgroundTransparency = 0.05
	panel.ClipsDescendants = true
	panel.Visible = false
	panel.ZIndex = 30
	escalaPanel = Instance.new("UIScale")
	escalaPanel.Parent = panel
	local borde = Instance.new("UIStroke")
	borde.Color = Ui.Color.Hueso
	borde.Transparency = 0.75
	borde.Parent = panel
	Ui.mancha(panel).ZIndex = 30

	titulo = Ui.texto("", {
		Position = UDim2.fromOffset(32, 22),
		Size = UDim2.new(1, -64, 0, 26),
		TextSize = 22,
		TextColor3 = ROJO,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 31,
	})
	titulo.Parent = panel
	local raya = Instance.new("Frame")
	raya.Position = UDim2.fromOffset(32, 58)
	raya.Size = UDim2.new(1, -64, 0, 1)
	raya.BackgroundColor3 = Ui.Color.Hueso
	raya.BackgroundTransparency = 0.8
	raya.BorderSizePixel = 0
	raya.ZIndex = 31
	raya.Parent = panel

	-- La opción: nombre y una línea de qué hace a la izquierda, SÍ/NO a la derecha.
	nombre = Ui.texto("", {
		Position = UDim2.fromOffset(32, 80),
		Size = UDim2.new(1, -200, 0, 30),
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 31,
	})
	nombre.Parent = panel
	explica = Ui.texto("", {
		Position = UDim2.fromOffset(32, 112),
		Size = UDim2.new(1, -200, 0, 22),
		TextSize = 16,
		TextTransparency = 0.45,
		TextTruncate = Enum.TextTruncate.AtEnd,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 31,
	})
	explica.Parent = panel
	interruptor = Ui.boton("", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -32, 0, 84),
		Size = UDim2.fromOffset(120, Ui.alto(46)),
		TextSize = 22,
		ZIndex = 31,
	})
	interruptor.Activated:Connect(function()
		-- Solo se pide: el botón cambia cuando el servidor cambia el atributo (y se guarda).
		Remotes.Ajustes:FireServer("Rendimiento", not activo())
	end)
	interruptor.Parent = panel

	cerrarBoton = Ui.boton("", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, -16),
		Size = UDim2.fromOffset(150, Ui.alto(40)),
		TextSize = 20,
		ZIndex = 31,
	})
	cerrarBoton.Activated:Connect(cerrar)
	cerrarBoton.Parent = panel
	panel.Parent = hud
end

-- Un engranaje con marcos: un círculo, ocho dientes (cuatro barras cruzadas) y el agujero del centro.
local function construirEngranaje(hud: ScreenGui)
	engranaje = Ui.boton("", {
		Name = "BotonAjustes",
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 0.35,
		ZIndex = 25,
	})
	local esquina = engranaje:FindFirstChildOfClass("UICorner")
	if esquina then
		esquina.CornerRadius = UDim.new(0.5, 0)
	end
	rueda = Instance.new("Frame")
	rueda.AnchorPoint = Vector2.new(0.5, 0.5)
	rueda.Position = UDim2.fromScale(0.5, 0.5)
	rueda.Size = UDim2.fromScale(0.62, 0.62)
	rueda.BackgroundTransparency = 1
	rueda.ZIndex = 26
	rueda.Parent = engranaje
	local function trozo(tamano: UDim2, giro: number, color: Color3, redondo: boolean, z: number)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.Size = tamano
		f.Rotation = giro
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		f.ZIndex = z
		if redondo then
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0.5, 0)
			c.Parent = f
		end
		f.Parent = rueda
	end
	for i = 0, 3 do
		trozo(UDim2.fromScale(0.22, 1), i * 45, Ui.Color.Hueso, false, 26)
	end
	trozo(UDim2.fromScale(0.72, 0.72), 0, Ui.Color.Hueso, true, 27)
	trozo(UDim2.fromScale(0.3, 0.3), 0, Ui.Color.Papel, true, 28)
	engranaje.Activated:Connect(function()
		pulsarEngranaje()
	end)
	-- Con teclado, su tecla al lado, pequeña (se esconde si pasa a usarse el mando o el dedo).
	do
		local tecla = Ui.texto("[P]", {
			Name = "Tecla",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(1, 6, 0.5, 0),
			Size = UDim2.fromOffset(30, 20),
			TextSize = 14,
			TextTransparency = 0.35,
			TextStrokeTransparency = 0.6,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 26,
			Visible = Ui.conTeclado(),
		})
		tecla.Parent = engranaje
		Ui.alCambiarEntrada(function()
			tecla.Visible = Ui.conTeclado()
		end)
	end
	engranaje.Parent = hud
end

-- Junto a los botones de Roblox de arriba a la izquierda y de su mismo alto. El HUD entero lleva un UIScale: las
-- medidas de Roblox van en píxeles de la pantalla, así que se dividen por la escala.
local function colocar(escala: UIScale?)
	local s = if escala and escala.Scale > 0 then escala.Scale else 1
	local barra = GuiService.TopbarInset
	local alto = barra.Max.Y
	if alto > 0 then
		local lado = math.max(alto - 14, 28)
		engranaje.Size = UDim2.fromOffset(lado / s, lado / s)
		engranaje.Position = UDim2.fromOffset((barra.Min.X + HUECO) / s, (alto / 2) / s)
	else
		engranaje.Size = UDim2.fromOffset(44 / s, 44 / s)
		engranaje.Position = UDim2.fromOffset(SIN_BARRA / s, (SIN_BARRA + 22) / s)
	end
end

function AjustesUi.start()
	local hud = Ui.hud()
	construirPanel(hud)
	construirEngranaje(hud)
	local escala = hud:FindFirstChildOfClass("UIScale")
	local function recolocar()
		colocar(escala)
	end
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(recolocar)
	if escala then
		escala:GetPropertyChangedSignal("Scale"):Connect(recolocar)
	end
	recolocar()
	-- La P (o R3 del mando) hace lo mismo que el engranaje (no con el HUD escondido en las cinemáticas: no se vería).
	-- B cierra aunque Roblox la use para salir de la selección del mando (entonces llega como procesada).
	UserInputService.InputBegan:Connect(function(entrada, procesado)
		local tecla = entrada.KeyCode
		if tecla == Enum.KeyCode.ButtonB and panel.Visible then
			cerrar()
		elseif not procesado and hud.Enabled and (tecla == Enum.KeyCode.P or tecla == MANDO) then
			pulsarEngranaje(tecla == MANDO)
		end
	end)
	Ui.seleccionConMando(panel, function()
		return panel.Visible
	end, function()
		return interruptor
	end)
	task.spawn(sugerirEnMovil)
	jugador:GetAttributeChangedSignal("Rendimiento"):Connect(function()
		if panel.Visible then
			pintar()
		end
	end)
end

return AjustesUi
