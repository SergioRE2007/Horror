-- Linterna y flash en el cliente (lo manda el servidor: juego/servidor/Equipo).
--   Linterna: la F, L1 en el mando o el botón en el móvil. La luz de cada jugador: la mía sale de la cámara; la de los
--   demás, de su cabeza. Con poca pila parpadea.
--   Flash: clic, R2 o el botón en el móvil (con la pistola de bengalas en la mano, el clic es suyo: BengalasVista).
--   Destello en todos los clientes; al que hace la foto, la pantalla en blanco.
--   Lo que queda de pila y fotos sale abajo un momento cuando cambia, y se va (casi nada en pantalla).
--   Correr (14.8): tu luz sale de la linterna con su temblor y su vaivén (Manos.dondeCosa, ManosCorrer): el haz se mueve
--   con cada paso y tiembla agotado. Si entre la cámara y la punta de la linterna hay algo que choca (una pared, una
--   puerta), la luz sale justo antes: ni el temblor ni el vaivén la meten detrás de la pared.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Stats = require(ReplicatedStorage.Shared.Stats)
local BengalasVista = require(script.Parent.BengalasVista)
local Manos = require(script.Parent.Manos)
local ManosGestos = require(script.Parent.ManosGestos)
local Sonido = require(script.Parent.Sonido)
local Ui = require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))

local EquipoVista = {}

local L = Config.Linterna
local jugador = Players.LocalPlayer
local camara = workspace.CurrentCamera
local COLOR_LUZ = Color3.fromRGB(255, 236, 205) -- la de serie

-- Color de la luz de cada uno: el cosmético que lleva puesto (atributo "PuestoLinterna", lo pone Comun.Tienda).
local COLORES = {}
for _, cosa in Config.Cosmeticos do
	if cosa.Tipo == "Linterna" then
		COLORES[cosa.Id] = Color3.fromRGB(table.unpack(cosa.Color))
	end
end
local function colorDe(otro: Player): Color3
	return COLORES[otro:GetAttribute("PuestoLinterna")] or COLOR_LUZ
end

-- Hasta dónde llega la luz que se ve y cuánto brillo de más lleva. Roblox no deja pasar el Range de un SpotLight de 60
-- studs, y con el pase "Better flashlight" (ventaja Luz) el alcance no cabe entero (55 × 1,25 ≈ 69): lo que no cabe se
-- pasa a brillo, que hace que el final del haz se vea más y que llegue más lejos (a ojo: con el cuadrado, como la luz de
-- verdad, que hoy da un 31 % más, y nunca más de un 50 % para no deslumbrar). Sin el pase no cambia nada. El servidor
-- frena a los bichos con el alcance entero (juego/servidor/Equipo).
local RANGO_MAX = 60
local function haz(otro: Player): (number, number)
	local alcance = L.Alcance * Stats.valor(otro, "Luz")
	local rango = math.min(RANGO_MAX, alcance)
	return rango, math.min(1.5, (alcance / rango) ^ 2)
end

type Luz = { punto: Attachment, foco: SpotLight }
local luces: { [Player]: Luz } = {}
local blanco: Frame
local cartel: Frame
local barra: Frame
local repuesto: TextLabel
local fotos: TextLabel
local cartelHasta = 0
local ultimaFoto = -math.huge -- cuándo subieron las manos la cámara por última vez (os.clock)

local function nuevaLuz(otro: Player): Luz
	local punto = Instance.new("Attachment")
	punto.Name = "Linterna"
	local foco = Instance.new("SpotLight")
	foco.Color = colorDe(otro)
	foco.Brightness = L.Brillo
	foco.Range = (haz(otro))
	foco.Angle = L.Angulo * 2
	foco.Shadows = true
	foco.Face = Enum.NormalId.Front
	foco.Parent = punto
	return { punto = punto, foco = foco }
end

-- La luz, como mucho hasta lo primero que choca entre la cámara y la punta de la linterna (un rayo por fotograma, solo
-- con tu linterna encendida). Los muebles no los ven los rayos (CanQuery = false): ahí, como antes.
local filtroHaz = RaycastParams.new()
filtroHaz.FilterType = Enum.RaycastFilterType.Exclude
filtroHaz.RespectCanCollide = true -- ni adornos ni mallas que solo se ven
filtroHaz.IgnoreWater = true
local filtroDe: Model? = nil -- el personaje con el que está hecho el filtro
local ANTES_DE_PARED = 0.12 -- studs que se separa la luz de lo que toca

local function sinAtravesar(donde: CFrame): CFrame
	local personaje = jugador.Character
	if personaje ~= filtroDe then
		filtroDe = personaje
		filtroHaz.FilterDescendantsInstances = if personaje then { camara, personaje } else { camara }
	end
	local desde = camara.CFrame.Position
	local hacia = donde.Position - desde
	if hacia.Magnitude < 1e-3 then
		return donde
	end
	local r = workspace:Raycast(desde, hacia, filtroHaz)
	if not r then
		return donde
	end
	local llega = math.max(0, (r.Position - desde).Magnitude - ANTES_DE_PARED)
	return donde.Rotation + (desde + hacia.Unit * llega)
end

-- Coloca y enciende (o apaga) la luz de cada jugador; parpadea con poca pila.
local function actualizarLuces()
	local ahora = os.clock()
	for _, otro in Players:GetPlayers() do
		local encendida = otro:GetAttribute("Linterna") == true
		local luz = luces[otro]
		local cabeza = otro.Character and otro.Character:FindFirstChild("Head") :: BasePart?
		if not encendida or not cabeza then
			if luz then
				luz.punto:Destroy()
				luces[otro] = nil
			end
			continue
		end
		if luz and not luz.punto:IsDescendantOf(game) then
			luz = nil -- se fue con el personaje viejo (se destruye con él)
		end
		if not luz then
			luz = nuevaLuz(otro)
			luces[otro] = luz
		end
		if otro == jugador then
			-- Desde la linterna que llevas en la mano izquierda (Manos); con las manos ocupadas, desde la cámara, un
			-- poco abajo a la derecha.
			luz.punto.Parent = workspace.Terrain
			local enMano = Manos.dondeCosa("Linterna")
			luz.punto.WorldCFrame = sinAtravesar(if enMano then camara.CFrame * enMano * CFrame.new(0, 0, -0.66)
				else camara.CFrame * CFrame.new(0.6, -0.5, -0.5))
			-- En las cinemáticas (la cámara la lleva un script) se apaga, solo aquí: si no, saldría de la cámara de cine.
			-- Vuelve sola al acabar. Escondido o muerto ya la apaga el servidor.
			luz.foco.Enabled = camara.CameraType == Enum.CameraType.Custom
		else
			-- La de los demás, desde su mano izquierda (BrazosVista le levanta el brazo y le pone la linterna); sin mano
			-- (R6), desde la cabeza.
			local mano = otro.Character and otro.Character:FindFirstChild("LeftHand") :: BasePart?
			local donde: Instance = mano or cabeza
			if luz.punto.Parent ~= donde then
				luz.punto.Parent = donde
				luz.punto.CFrame = if mano then CFrame.new(0, -0.55, 0) * CFrame.Angles(math.rad(-90), 0, 0)
					else CFrame.new(0.4, -0.3, -0.6)
			end
			-- En las cinemáticas (Huida, Incendio) los demás se esconden: su haz saldría de una mano que no se ve. Mirando
			-- por la mirilla o las cortinas (Vistazo) o desde el escondite (Escondido) la cámara también es de script, y
			-- ahí sí se ve a los demás con su luz.
			luz.foco.Enabled = not (camara.CameraType == Enum.CameraType.Scriptable and jugador:GetAttribute("Vistazo") == nil
				and typeof(jugador:GetAttribute("Escondido")) ~= "CFrame")
		end
		local pila = otro:GetAttribute("Pila") or 1
		local brillo = L.Brillo
		if pila < L.Poca then
			-- Cuanta menos pila, más se apaga a tirones.
			local fallo = 1 - pila / L.Poca
			local ruido = math.noise(ahora * 9, otro.UserId % 97)
			if ruido < -0.5 + fallo * 0.7 then
				brillo *= 0.05
			else
				brillo *= 0.75 + 0.25 * math.noise(ahora * 30, 3.1)
			end
		end
		local rango, masBrillo = haz(otro)
		luz.foco.Brightness = brillo * masBrillo
		luz.foco.Color = colorDe(otro)
		luz.foco.Range = rango
	end
	for otro, luz in luces do
		if not otro.Parent then
			luz.punto:Destroy()
			luces[otro] = nil
		end
	end
end

local function mostrarCartel()
	cartelHasta = os.clock() + 3
	local pila = jugador:GetAttribute("Pila") or 0
	barra.Size = UDim2.fromScale(math.clamp(pila, 0, 1), 1)
	barra.BackgroundColor3 = if pila < L.Poca then Ui.Color.Sangre else Ui.Color.Hueso
	repuesto.Text = "+" .. tostring(jugador:GetAttribute("Pilas") or 0)
	-- Una frase entera con el repuesto de carretes dentro, y en singular con la última foto.
	local quedan = jugador:GetAttribute("Fotos") or 0
	fotos.Text = Ui.mayusculas(Lang.t(nil, if quedan == 1 then "1 photo  +{spare}" else "{n} photos  +{spare}",
		{ n = quedan, spare = jugador:GetAttribute("Carretes") or 0 }))
	TweenService:Create(cartel, TweenInfo.new(0.25), { GroupTransparency = 0 }):Play()
	task.delay(3.05, function()
		if os.clock() >= cartelHasta then
			TweenService:Create(cartel, TweenInfo.new(1), { GroupTransparency = 1 }):Play()
		end
	end)
end

local ultimaLinterna = -math.huge
local function pedirLinterna()
	-- El servidor no deja cambiarla más de una vez cada 0,25 s (Equipo): sin el clic de un cambio que no va a pasar
	-- (aquí algo más, por lo que varía la red).
	local ahora = os.clock()
	if ahora - ultimaLinterna < 0.3 then
		return
	end
	ultimaLinterna = ahora
	-- Si tiene pila y está apagada, se enciende; si no, el clic de apagar (pedido por el usuario: dos sonidos).
	local enciende = not jugador:GetAttribute("Linterna") and (jugador:GetAttribute("Pila") or 0) > 0
	Sonido.tocar(if enciende then "Linterna" else "LinternaApaga")
	Remotes.Linterna:FireServer()
end

-- ¿Va a salir la foto? Lo mismo que mira el servidor (juego/servidor/Equipo): con las manos ocupadas, cambiando la pila
-- o el carrete, sin fotos (sin cámara, Fotos vale 0) o aún recargando, no sale.
local function saleFoto(): boolean
	return not (jugador:GetAttribute("Cargando") or jugador:GetAttribute("Trabajando")
		or jugador:GetAttribute("MochilaAbierta") or jugador:GetAttribute("Cambiando"))
		and (jugador:GetAttribute("Fotos") or 0) > 0
		and os.clock() - ultimaFoto >= Config.Flash.Recarga * Stats.valor(jugador, "Recarga")
end

local function pedirFlash()
	if jugador:GetAttribute("Escondido") or jugador:GetAttribute("Muerto") or BengalasVista.enMano() then
		return
	end
	-- El remote va siempre: si no sale, el servidor avisa de por qué. El gesto, solo si sale (si no, se veía la cámara
	-- en la cara sin flash, o soltando el tablón que llevas).
	Remotes.Flash:FireServer(camara.CFrame.LookVector)
	if saleFoto() then
		ultimaFoto = os.clock()
		ManosGestos.foto() -- las dos manos suben la cámara a la cara
	end
end

-- Destello de un flash: luz fuerte un instante en la cabeza de quien hace la foto.
local function destello(quien: Player)
	local cabeza = quien.Character and quien.Character:FindFirstChild("Head") :: BasePart?
	if not cabeza then
		return
	end
	local punto = Instance.new("Attachment")
	punto.Position = Vector3.new(0, 0, -1.5)
	local luz = Instance.new("PointLight")
	luz.Color = Color3.fromRGB(235, 240, 255)
	luz.Brightness = 10
	luz.Range = 40
	luz.Parent = punto
	punto.Parent = cabeza
	TweenService:Create(luz, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Brightness = 0 }):Play()
	task.delay(0.4, punto.Destroy, punto)
	if quien == jugador then
		-- Una foto que aquí parecía que no saldría (la recarga del servidor va un poco desfasada): el gesto, tarde.
		if os.clock() - ultimaFoto > 0.7 then
			ultimaFoto = os.clock()
			ManosGestos.foto()
		end
		Sonido.tocar("Flash")
		blanco.BackgroundTransparency = 0.05
		TweenService:Create(blanco, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 }):Play()
	else
		Sonido.en("Flash", cabeza.Position)
	end
end

local function crearHud()
	local hud = Ui.hud()
	local capa = Instance.new("ScreenGui") -- aparte del HUD (sin UIScale): el blanco tapa toda la pantalla
	capa.Name = "Flash"
	capa.IgnoreGuiInset = true
	capa.ResetOnSpawn = false
	capa.DisplayOrder = 5
	capa.Parent = hud.Parent
	blanco = Instance.new("Frame")
	blanco.Size = UDim2.fromScale(1, 1)
	blanco.BackgroundColor3 = Color3.new(1, 1, 1)
	blanco.BackgroundTransparency = 1
	blanco.BorderSizePixel = 0
	blanco.Parent = capa

	-- Pila (una barrita) y fotos, abajo en el centro; sale un momento al cambiar. En el móvil, arriba en el centro, bajo
	-- la barra de Roblox: abajo están los botones del equipo.
	local tactil = UserInputService.TouchEnabled
	cartel = Instance.new("CanvasGroup")
	cartel.Name = "Equipo"
	cartel.AnchorPoint = Vector2.new(0.5, if tactil then 0 else 1)
	cartel.Position = if tactil then UDim2.fromScale(0.5, 0.17) else UDim2.new(0.5, 0, 1, -18)
	cartel.Size = UDim2.fromOffset(300, 30)
	cartel.BackgroundTransparency = 1
	cartel.GroupTransparency = 1
	cartel.Parent = hud
	local lista = Instance.new("UIListLayout")
	lista.FillDirection = Enum.FillDirection.Horizontal
	lista.HorizontalAlignment = Enum.HorizontalAlignment.Center
	lista.VerticalAlignment = Enum.VerticalAlignment.Center
	lista.Padding = UDim.new(0, 10)
	lista.Parent = cartel
	local pila = Instance.new("Frame")
	pila.Size = UDim2.fromOffset(46, 16)
	pila.BackgroundColor3 = Ui.Color.Papel
	pila.BackgroundTransparency = 0.3
	local borde = Instance.new("UIStroke")
	borde.Color = Ui.Color.Hueso
	borde.Transparency = 0.4
	borde.Parent = pila
	barra = Instance.new("Frame")
	barra.BorderSizePixel = 0
	barra.Parent = pila
	pila.Parent = cartel
	repuesto = Ui.texto("", { Size = UDim2.fromOffset(34, 26), TextSize = 20 })
	repuesto.Parent = cartel
	fotos = Ui.texto("", { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 26), TextSize = 20 })
	fotos.Parent = cartel

	-- Móvil: los botones del equipo a la izquierda del de saltar de Roblox, en dos filas de cuatro como mucho para no
	-- meterse en la zona del joystick (el 40 % izquierdo de la pantalla: a 1164 de ancho de diseño, la rejilla empieza
	-- en el 40,8 %). Se rellena desde abajo a la derecha, junto al pulgar, por LayoutOrder: FLASH 1, LINTERNA 2, BENGALA
	-- 3 (BengalasVista, solo con la pistola), MOCHILA 4 (MochilaUi), MÓVIL 5 (MovilUi), AGACHARSE 6 (PosturaVista) y
	-- CORRER 7 (CorrerVista, 14.8). Escondido o muerto no se ven (el botón SALIR y el de revivir van ahí). Por encima de
	-- la zona segura de abajo (Ui.zonaSegura) y con hueco debajo para la barra del aguante (CorrerBarra).
	if tactil then
		local fila = Instance.new("Frame")
		fila.Name = "EquipoBotones"
		fila.AnchorPoint = Vector2.new(1, 1)
		-- Se recoloca si cambia la zona segura (al girar el teléfono), igual que la barra del aguante de debajo.
		local function colocarFila()
			fila.Position = UDim2.new(0.8, 0, 0.97, -Ui.zonaSegura())
		end
		colocarFila()
		hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(colocarFila)
		fila.Size = UDim2.fromOffset(4 * 108 + 3 * 8, 2 * 80 + 8)
		fila.BackgroundTransparency = 1
		local orden = Instance.new("UIGridLayout")
		orden.CellSize = UDim2.fromOffset(108, 80)
		orden.CellPadding = UDim2.fromOffset(8, 8)
		orden.FillDirection = Enum.FillDirection.Horizontal
		orden.FillDirectionMaxCells = 4
		orden.StartCorner = Enum.StartCorner.BottomRight
		orden.SortOrder = Enum.SortOrder.LayoutOrder
		orden.Parent = fila
		for i, datos in { { Lang.t(nil, "Flash"), pedirFlash }, { Lang.t(nil, "Flashlight"), pedirLinterna } } do
			local boton = Ui.boton(datos[1], { LayoutOrder = i })
			Ui.queQuepa(boton, 24) -- FLASHLIGHT no cabe entero a 24
			boton.Activated:Connect(datos[2])
			boton.Parent = fila
		end
		local function verFila()
			fila.Visible = not (jugador:GetAttribute("Muerto") or typeof(jugador:GetAttribute("Escondido")) == "CFrame")
		end
		jugador:GetAttributeChangedSignal("Muerto"):Connect(verFila)
		jugador:GetAttributeChangedSignal("Escondido"):Connect(verFila)
		verFila()
		fila.Parent = hud
	end
end

function EquipoVista.start()
	crearHud()
	UserInputService.InputBegan:Connect(function(entrada, procesado)
		if procesado then
			return
		end
		if entrada.KeyCode == Enum.KeyCode.F or entrada.KeyCode == Enum.KeyCode.ButtonL1 then
			pedirLinterna()
		elseif entrada.UserInputType == Enum.UserInputType.MouseButton1 or entrada.KeyCode == Enum.KeyCode.ButtonR2 then
			pedirFlash()
		end
	end)
	local pilaAntes = 1
	for _, atributo in { "Pila", "Pilas", "Fotos", "Carretes", "Linterna" } do
		jugador:GetAttributeChangedSignal(atributo):Connect(function()
			-- La pila baja poco a poco: solo enseña el cartel al cambiarla o al quedar poca.
			local pila = jugador:GetAttribute("Pila") or 0
			local antes = pilaAntes
			pilaAntes = pila
			if atributo ~= "Pila" or pila > antes or (pila < L.Poca and antes >= L.Poca) then
				mostrarCartel()
			end
		end)
	end
	Remotes.Flash.OnClientEvent:Connect(destello)
	-- Después de lo que mueve la cámara (Camera + 1: CuerpoVista, temblores) y de las manos (Camera + 5): así la luz
	-- sale de la linterna tal como se pinta en este fotograma (antes iba un fotograma tarde y, corriendo, el haz se
	-- torcía hasta 1,5° de la linterna, tanto como su temblor; lo vio el banco correr-manos).
	RunService:BindToRenderStep("Linterna", Enum.RenderPriority.Camera.Value + 6, actualizarLuces)
end

return EquipoVista
