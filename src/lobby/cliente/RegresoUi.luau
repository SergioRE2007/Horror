-- Volver a la partida tras un corte (lo decide lobby/servidor/Regreso; aquí solo se pinta y se pide). Con el atributo
-- `PartidaAbierta` baja desde arriba un cartel pequeño de papel viejo con la esquina de sangre: una sola línea,
-- "Your friends are still playing.", y GO BACK (lo principal, en rojo, con el borde latiendo como un corazón). Al pulsarlo
-- suena el papel y se pide al servidor (remote Regreso), que vuelve a mirar si la partida sigue: si no, avisa y quita el
-- atributo, y el cartel sube y se va.
--   Va arriba en el centro, bajo la línea de la guía del lobby (GuiaLobby) y lejos de los botones de Roblox (esquinas de
--   arriba) y del de saltar (abajo a la derecha). En el móvil, GO BACK mide un dedo (Ui.alto).
--   Sentado en un coche o con una ventana abierta (la tienda, Ajustes) se esconde: GO BACK no vale desde el coche.
--   Con mando, al salir el cartel GO BACK ya va elegido (la A lo pulsa); si se suelta con B, no se le vuelve a elegir
--   hasta la próxima vez que salga. En primera persona suelta el ratón (Modal), como CochesUi.
--   Con Rendimiento, sin deslizar ni latir. Lo animado va en el bucle común (Bucle) y solo mientras se ve.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Bucle = require(script.Parent.Bucle)
local Sonido = require(script.Parent.Sonido)
local Ui = require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))

local RegresoUi = {}

local jugador = Players.LocalPlayer
local NOMBRE_BUCLE = "Regreso"
-- Píxeles de diseño (docs/sistemas/movil.md).
local TACTIL = Ui.tactil()
local ANCHO = if TACTIL then 620 else 560
local MARGEN = 14
local BOTON = Ui.alto(46)
local BOTON_ANCHO = if TACTIL then 200 else 170
local ALTO = BOTON + 2 * MARGEN
local ARRIBA = 82 -- bajo la línea de la guía (GuiaLobby: 14 + 56 de alto) con un hueco
local LETRA = if TACTIL then 25 else 23
local LETRA_BOTON = if TACTIL then 23 else 21
-- Colores propios (los demás, de Ui): los de lo principal de CochesUi.
local ROJO = Color3.fromRGB(150, 34, 28)
local ROJO_BOTON = Color3.fromRGB(58, 16, 14)
-- Animaciones (segundos).
local T_BAJA, T_SUBE = 0.45, 0.2
local LATIDO = 1.3 -- cada latido del borde de GO BACK (dos golpes, como un corazón)
local DENTRO = UDim2.new(0.5, 0, 0, ARRIBA)
local FUERA = UDim2.new(0.5, 0, 0, -ALTO - 20)

local cartel: TextButton
local linea: TextLabel
local volver: TextButton
local trazo: UIStroke
local visible = false
local vez = 0 -- sube al enseñar o esconder: la subida de antes ya no lo esconde
local elegido = false -- con mando, GO BACK ya se ha elegido en esta salida
local modal = false -- lo que se ha puesto en cartel.Modal (solo se escribe si cambia)

local function rendimiento(): boolean
	return jugador:GetAttribute("Rendimiento") == true
end

local function quiere(): boolean
	return jugador:GetAttribute("PartidaAbierta") == true and jugador:GetAttribute("Coche") == nil
		and not jugador:GetAttribute("VentanaAbierta")
end

-- En primera persona el ratón va bloqueado en el centro y no se podría pulsar GO BACK: entonces Modal lo suelta.
local function primeraPersona(): boolean
	local camara = workspace.CurrentCamera
	return camara ~= nil and (camara.Focus.Position - camara.CFrame.Position).Magnitude < 2
end

local function ponerModal(si: boolean)
	if si ~= modal then
		modal = si
		cartel.Modal = si
	end
end

-- Lo que late: dos golpes seguidos que se apagan (0..1), cada LATIDO s.
local function golpe(t: number): number
	return if t >= 0 then math.exp(-t * 12) else 0
end
local function latido(ahora: number): number
	local t = ahora % LATIDO
	return math.max(golpe(t), 0.6 * golpe(t - 0.22))
end
RegresoUi.latido = latido -- para el banco

local function cadaFotograma(_dt: number, ahora: number)
	ponerModal(primeraPersona())
	if rendimiento() then
		trazo.Thickness, trazo.Transparency = 2, 0
	else
		local f = latido(ahora)
		trazo.Thickness = 2 + 2.5 * f
		trazo.Transparency = 0.45 * (1 - f)
	end
end

-- Con mando, GO BACK elegido (una vez por salida; con otra ventana encima, no se le quita la suya).
local function elegir()
	if visible and not elegido and Ui.tipoEntrada() == "mando" and not jugador:GetAttribute("VentanaAbierta") then
		elegido = true
		Ui.seleccionar(volver)
	end
end

local function pintar()
	local si = quiere()
	if si == visible then
		return
	end
	visible = si
	vez += 1
	local mia = vez
	if si then
		-- Los textos cada vez que sale: el idioma puede haber llegado después de construirlo.
		linea.Text = Lang.t(nil, "Your friends are still playing.")
		volver.Text = Ui.mayusculas(Lang.t(nil, "Go back"))
		volver.Interactable = true
		volver.TextTransparency = 0
		elegido = false
		cartel.Visible = true
		if rendimiento() then
			cartel.Position = DENTRO
		else
			cartel.Position = FUERA
			TweenService:Create(cartel, TweenInfo.new(T_BAJA, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Position = DENTRO }):Play()
		end
		Bucle.cada(NOMBRE_BUCLE, cadaFotograma)
		task.defer(elegir)
	else
		Bucle.quitar(NOMBRE_BUCLE)
		ponerModal(false)
		Ui.soltarSeleccion(cartel)
		if rendimiento() then
			cartel.Visible = false
			cartel.Position = FUERA
		else
			TweenService:Create(cartel, TweenInfo.new(T_SUBE, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{ Position = FUERA }):Play()
			task.delay(T_SUBE, function()
				if vez == mia then
					cartel.Visible = false
				end
			end)
		end
	end
end

-- GO BACK: suena al pulsar y se apaga un momento (lo que tarda el servidor en dejar otra petición).
local function pulsar()
	if not visible or not volver.Interactable then
		return
	end
	Sonido.tocar("Papel")
	Remotes.Regreso:FireServer()
	volver.Interactable = false
	volver.TextTransparency = 0.45
	local mia = vez
	task.delay(Config.Limites.Regreso, function()
		if vez == mia then
			volver.Interactable = true
			volver.TextTransparency = 0
		end
	end)
end

local function construir()
	-- El papel es un botón: se queda los toques (no mueven la cámara ni el joystick).
	cartel = Instance.new("TextButton")
	cartel.Name = "Regreso"
	cartel.Text = ""
	cartel.AutoButtonColor = false
	cartel.Selectable = false
	cartel.AnchorPoint = Vector2.new(0.5, 0)
	cartel.Position = FUERA
	cartel.Size = UDim2.fromOffset(ANCHO, ALTO)
	cartel.BackgroundColor3 = Ui.Color.Papel
	cartel.BackgroundTransparency = 0.06
	cartel.ClipsDescendants = true
	cartel.Visible = false
	cartel.ZIndex = 40
	local viejo = Instance.new("UIGradient") -- papel viejo: más oscuro abajo
	viejo.Rotation = 90
	viejo.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(196, 188, 178))
	viejo.Parent = cartel
	local borde = Instance.new("UIStroke")
	borde.Color = Ui.Color.Sangre
	borde.Thickness = 2
	borde.Parent = cartel
	local esquina = Instance.new("UICorner")
	esquina.CornerRadius = UDim.new(0, 4)
	esquina.Parent = cartel
	Ui.mancha(cartel)

	linea = Ui.texto("", {
		Name = "Linea",
		Position = UDim2.fromOffset(MARGEN, 0),
		Size = UDim2.new(1, -(3 * MARGEN + BOTON_ANCHO), 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 41,
	})
	Ui.queQuepa(linea, LETRA) -- en otros idiomas la frase es más larga
	linea.Parent = cartel
	-- Raya bajo la frase, como una hoja de libreta.
	local raya = Instance.new("Frame")
	raya.Name = "Raya"
	raya.AnchorPoint = Vector2.new(0, 1)
	raya.Position = UDim2.new(0, MARGEN, 1, -MARGEN + 2)
	raya.Size = UDim2.new(1, -(3 * MARGEN + BOTON_ANCHO), 0, 2)
	raya.BackgroundColor3 = ROJO
	raya.BackgroundTransparency = 0.4
	raya.BorderSizePixel = 0
	raya.ZIndex = 41
	raya.Parent = cartel

	volver = Ui.boton("", {
		Name = "Volver",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -MARGEN, 0.5, 0),
		Size = UDim2.fromOffset(BOTON_ANCHO, BOTON),
		BackgroundColor3 = ROJO_BOTON,
		BackgroundTransparency = 0.05,
		ZIndex = 42,
	})
	Ui.queQuepa(volver, LETRA_BOTON)
	trazo = volver:FindFirstChildOfClass("UIStroke") :: UIStroke
	trazo.Color = ROJO
	volver.Activated:Connect(pulsar)
	volver.Parent = cartel
	cartel.Parent = Ui.hud()
end

function RegresoUi.start()
	construir()
	Sonido.precargar({ "Papel" })
	for _, nombre in { "PartidaAbierta", "Coche", "VentanaAbierta" } do
		jugador:GetAttributeChangedSignal(nombre):Connect(pintar)
	end
	-- Al pasar al mando con el cartel fuera, GO BACK elegido; al dejarlo (ratón, dedo), se suelta.
	Ui.alCambiarEntrada(function()
		if not visible then
			return
		elseif Ui.tipoEntrada() == "mando" then
			elegir()
		else
			Ui.soltarSeleccion(cartel)
		end
	end)
	pintar()
end

return RegresoUi
