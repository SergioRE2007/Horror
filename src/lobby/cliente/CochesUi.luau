-- Lo que ves sentado en un coche del lobby (lo manda Coches en el servidor; aquí solo se pide y se pinta). Pedido por
-- el usuario: "que siga el estilo oscuro de Ui y se vea bien en el móvil". Papel oscuro abajo con la esquina manchada
-- de sangre, que sube desde el borde al sentarte y baja al bajarte.
--   Dueño: sus ranuras de partida como fichas (NOCHE N o VACÍA; la elegida con borde claro y un marcapáginas rojo, y
--   tachada si va a empezar de cero; al cambiar de ficha suena el papel), NUEVA PARTIDA en una ranura con algo
--   guardado (dos toques: se empieza de cero y se pierde lo guardado; el primer toque se olvida a los SEGURO s),
--   EMPEZAR / CONTINUAR (lo principal, en rojo) y BAJAR. Los demás: "Esperando a {name}…" y BAJAR.
--   Los botones van colocados a mano y centrados en su sitio (sin UIListLayout): así se hunden hacia su centro al
--   pulsarlos (Ui.boton) sin empujar a los de al lado.
--   Al arrancar, la cinemática de salida la hace SalidaVista: esconde toda la interfaz (esta también) y tiene su propio
--   fundido (capa FundidoSalida, DisplayOrder 99); si el servidor para el coche lo devuelve todo. Aquí queda, por si
--   acaso, la cuenta atrás y un fundido a negro propio (capa Fundido, DisplayOrder 100) un poco antes de la hora. Si el
--   servidor para el coche (falló o es Studio) o a los 12 s sigue aquí, vuelve la imagen (y para esa salida ya no se
--   vuelve a fundir).
--   BAJAR (también saltando). Con Rendimiento, sin animaciones. En el móvil, todo del alto de un dedo y sin tapar el
--   botón de saltar de Roblox (abajo a la derecha).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Stats = require(ReplicatedStorage.Shared.Stats)
local Sonido = require(script.Parent.Sonido)
local Ui = require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))

local CochesUi = {}

local jugador = Players.LocalPlayer
-- Medidas en píxeles de diseño (docs/sistemas/movil.md). En el móvil los botones y las fichas miden un dedo
-- (Ui.DEDO) y el papel es más ancho, pero deja LADO libre a cada lado: así no pisa el botón de saltar de Roblox.
local TACTIL = Ui.tactil()
local ANCHO = if TACTIL then 780 else 680 -- como mucho
local ANCHO_MIN = 560
local LADO = if TACTIL then 190 else 40
-- Del papel al borde de abajo de la pantalla (en el móvil, más: la raya de inicio del teléfono; el botón de saltar de
-- Roblox también deja ~20 px de verdad).
local ABAJO = if TACTIL then 36 else 16
local MARGEN = 22 -- de los bordes del papel a lo de dentro
local TITULO = 36 -- alto de la fila del título
local FICHA = Ui.alto(70) -- alto de cada ranura
local BOTON = Ui.alto(46) -- BAJAR, NUEVA PARTIDA y EMPEZAR
local BAJAR_ANCHO = if TACTIL then 170 else 140
local HUECO = 12 -- entre filas y entre botones
local PAD = 10 -- entre fichas
local ALTO_DUENO = 12 + TITULO + HUECO + FICHA + HUECO + BOTON + 14
local ALTO_OTRO = 12 + math.max(TITULO, BOTON) + 12
local LETRA_TITULO = if TACTIL then 28 else 26
local LETRA_FICHA = if TACTIL then 24 else 22
local LETRA_BOTON = if TACTIL then 22 else 20
local LETRA_NUMERO = if TACTIL then 18 else 15 -- el número de la ficha, arriba a la izquierda
local CINTA = Vector2.new(10, 22) -- el marcapáginas de la ficha elegida
local TACHON = 0.8 -- lo largo del tachón, en partes del ancho de la ficha
local SEGURO = 4 -- segundos que dura el "¿SEGURO?" de NUEVA PARTIDA
-- Segundos: un toque en NUEVA PARTIDA tan seguido del anterior es un doble toque sin querer y no cuenta (si no, en el
-- móvil un doble toque armaría el "¿SEGURO?" y lo confirmaría a la vez, y se borraría la partida).
local DOBLE = 0.4
-- Colores propios (los demás, de Ui).
local ROJO = Color3.fromRGB(150, 34, 28) -- borde de lo principal, marcapáginas y tachón: sobre el papel tiene que leerse
local ROJO_BOTON = Color3.fromRGB(58, 16, 14) -- fondo de lo principal y del segundo toque
-- Animaciones (segundos).
local T_SUBE, T_BAJA, T_CAMBIA = 0.35, 0.2, 0.2

type Ficha = { boton: TextButton, borde: UIStroke, estado: TextLabel, cinta: Frame, tachon: Frame }

local panel: TextButton
local titulo: TextLabel
local raya: Frame
local fila: Frame
local derecha: Frame
local bajar: TextButton
local nueva: TextButton
local empezar: TextButton
local negro: Frame
local fichas: { Ficha } = {}
local seguro = false -- ya ha tocado una vez NUEVA PARTIDA (o lo ha confirmado y aún no ha llegado Nueva)
local vezSeguro = 0
local toqueNueva = 0 -- os.clock() del último toque en NUEVA PARTIDA (ver DOBLE)
local modal = false -- lo que se ha puesto en panel.Modal (solo se escribe si cambia)
local fundida = nil -- la Salida para la que ya se ha fundido a negro
local devuelta = nil -- la Salida tras cuyo fundido volvió la imagen a los 12 s: para esa ya no se vuelve a fundir
local visible = false -- el papel está fuera (o subiendo)
local vezPanel = 0 -- sube al enseñarlo o esconderlo: el tween de antes ya no lo esconde
local modo: string? = nil -- "dueno" u "otro": cómo está colocado
local ancho = ANCHO
-- Lo que se pintó la última vez (para animar solo lo que cambia; -1 = hay que repintarlo).
local elegidaAntes: number? = -1
local tachadaAntes: number? = -1
local seguroAntes = false
local recien = true -- el papel acaba de salir o de cambiar de dueño: lo de dentro se pone sin animar

local function texto(frase: string, huecos: { [string]: any }?): string
	return Ui.mayusculas(Lang.t(nil, frase, huecos))
end

local function rendimiento(): boolean
	return jugador:GetAttribute("Rendimiento") == true
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

-- En primera persona (la cámara pegada a la cabeza) el ratón va bloqueado en el centro y no se podría pulsar el papel:
-- entonces Modal lo suelta. En tercera persona no (arrastrar con el botón derecho para mirar sigue como siempre).
local function primeraPersona(): boolean
	local camara = workspace.CurrentCamera
	return camara ~= nil and (camara.Focus.Position - camara.CFrame.Position).Magnitude < 2
end

-- Suelta el ratón (Modal) si el papel está fuera y vas en primera persona; solo escribe Modal cuando cambia.
local function soltarRaton()
	local si = visible and primeraPersona()
	if si ~= modal then
		modal = si
		panel.Modal = si
	end
end

-- Un respingo del botón (se tuerce y vuelve): espera el segundo toque o no ha contado un doble toque.
local function respingo(boton: GuiObject)
	if rendimiento() then
		return
	end
	boton.Rotation = -5
	TweenService:Create(boton, TweenInfo.new(0.45, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { Rotation = 0 })
		:Play()
end

-- Un tween corto, o de golpe con Rendimiento.
local function animar(objeto: Instance, segundos: number, props: { [string]: any }, estilo: Enum.EasingStyle?)
	if rendimiento() then
		for clave, valor in props do
			(objeto :: any)[clave] = valor
		end
		return
	end
	TweenService:Create(objeto, TweenInfo.new(segundos, estilo or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
		:Play()
end

-- Saca el papel desde el borde de abajo o lo vuelve a meter (`deGolpe`: sin animación, como al fundir a negro).
local function mostrar(si: boolean, deGolpe: boolean?)
	if si == visible then
		return
	end
	visible = si
	vezPanel += 1
	local mia = vezPanel
	soltarRaton()
	local dentro = UDim2.new(0.5, 0, 1, -ABAJO)
	local fuera = UDim2.new(0.5, 0, 1, panel.Size.Y.Offset + 24) -- del todo por debajo de la pantalla
	local deUnaVez = deGolpe or rendimiento()
	if si then
		recien, elegidaAntes, tachadaAntes, seguroAntes = true, -1, -1, false
		if deUnaVez then
			panel.Position = dentro
		else
			if not panel.Visible then
				panel.Position = fuera -- (si aún estaba bajando, sube desde donde va)
			end
			TweenService:Create(panel, TweenInfo.new(T_SUBE, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Position = dentro }):Play()
		end
		panel.Visible = true
	elseif deUnaVez then
		panel.Visible = false
	else
		local baja = TweenService:Create(panel, TweenInfo.new(T_BAJA, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = fuera })
		baja:Play()
		baja.Completed:Once(function()
			if vezPanel == mia then
				panel.Visible = false
			end
		end)
	end
end

-- Tamaño y reparto según quién eres (dueño o no) y lo ancho de la pantalla. Solo hace algo si cambia.
local function colocar(esDueno: boolean)
	local lienzo = Ui.lienzo()
	local quiere = if lienzo.X >= 200 then math.clamp(lienzo.X - 2 * LADO, ANCHO_MIN, ANCHO) else ANCHO
	local nuevo = if esDueno then "dueno" else "otro"
	if nuevo == modo and quiere == ancho then
		return
	end
	local crece = modo ~= nil and modo ~= nuevo and visible -- ya estaba a la vista: el papel crece o encoge
	if nuevo ~= modo then
		recien, elegidaAntes, tachadaAntes = true, -1, -1
	end
	modo, ancho = nuevo, quiere
	local tamano = UDim2.fromOffset(ancho, if esDueno then ALTO_DUENO else ALTO_OTRO)
	if crece then
		animar(panel, T_CAMBIA, { Size = tamano })
	else
		panel.Size = tamano
	end
	fila.Visible = esDueno
	derecha.Visible = esDueno
	raya.Visible = esDueno
	-- (Ui.queQuepa pone 8 de margen a cada lado del título: se descuentan para que empiece en MARGEN.)
	-- (BAJAR, centrado en su sitio: abajo a la izquierda para el dueño, a la derecha del título para los demás.)
	if esDueno then
		titulo.AnchorPoint = Vector2.zero
		titulo.Position = UDim2.fromOffset(MARGEN - 8, 12)
		titulo.Size = UDim2.new(1, -2 * MARGEN + 16, 0, TITULO)
		bajar.Position = UDim2.new(0, MARGEN + BAJAR_ANCHO / 2, 1, -14 - BOTON / 2)
	else
		titulo.AnchorPoint = Vector2.new(0, 0.5)
		titulo.Position = UDim2.new(0, MARGEN - 8, 0.5, 0)
		titulo.Size = UDim2.new(1, -(2 * MARGEN + BAJAR_ANCHO + HUECO) + 16, 0, TITULO)
		bajar.Position = UDim2.new(1, -14 - BAJAR_ANCHO / 2, 0.5, 0)
	end
end

local function volver(salida: number?)
	devuelta = salida
	fundida = nil
	local claro = TweenService:Create(negro, TweenInfo.new(0.8), { BackgroundTransparency = 1 })
	claro.Completed:Once(function()
		if fundida == nil then -- (si mientras tanto se ha vuelto a fundir, se queda)
			negro.Visible = false
		end
	end)
	claro:Play()
end

local function fundir(salida: number)
	fundida = salida
	mostrar(false, true)
	negro.Visible = true
	TweenService:Create(negro, TweenInfo.new(1.2), { BackgroundTransparency = 0 }):Play()
	task.delay(12, function()
		if fundida == salida then -- sigue aquí: no ha salido
			volver(salida)
		end
	end)
end

-- Las fichas de las ranuras: la elegida, más clara y con el marcapáginas (que baja al elegirla); tachada si empieza
-- de cero. Se reparten el ancho con PAD entre ellas, cada una colocada por su centro.
local function pintarFichas(p, elegida: number, cuantas: number, tachada: number?, quieto: boolean)
	for i, f in fichas do
		local guardada = p[tostring(i)]
		local es = i == elegida
		f.boton.Visible = i <= cuantas
		f.boton.Size = UDim2.new(1 / cuantas, -PAD * (cuantas - 1) / cuantas, 1, 0)
		f.boton.Position = UDim2.new((i - 0.5) / cuantas, PAD * (2 * i - 1 - cuantas) / (2 * cuantas), 0.5, 0)
		f.boton.Interactable = not quieto
		f.boton.BackgroundTransparency = if es then 0.02 else 0.3
		f.borde.Color = if es then Ui.Color.Hueso else Ui.Color.Sangre
		f.borde.Thickness = if es then 3 else 2
		f.estado.Text = if guardada then texto("Night {n}", { n = guardada.noche }) else texto("Empty")
		f.estado.TextTransparency = if i == tachada then 0.45 elseif es then 0 elseif guardada then 0.3 else 0.55
	end
	local cambia = not recien and not rendimiento() -- al sacar el papel, todo ya en su sitio
	recien = false
	if elegida ~= elegidaAntes then
		elegidaAntes = elegida
		for i, f in fichas do
			f.cinta.Visible = i == elegida
		end
		local f = fichas[elegida]
		if f then
			-- El marcapáginas baja hasta la ficha nueva.
			f.cinta.Size = UDim2.fromOffset(CINTA.X, if cambia then 0 else CINTA.Y)
			if cambia then
				TweenService:Create(f.cinta, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
					{ Size = UDim2.fromOffset(CINTA.X, CINTA.Y) }):Play()
			end
		end
	end
	if tachada ~= tachadaAntes then
		tachadaAntes = tachada
		for i, f in fichas do
			f.tachon.Visible = i == tachada
		end
		local f = if tachada then fichas[tachada] else nil
		if f then
			-- Se tacha de un trazo, de izquierda a derecha, como en una libreta.
			f.tachon.Size = UDim2.new(if cambia then 0 else TACHON, 0, 0, 3)
			if cambia then
				TweenService:Create(f.tachon, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Size = UDim2.new(TACHON, 0, 0, 3) }):Play()
			end
		end
	end
end

local function pintar()
	local c = coche()
	if fundida and (not c or c:GetAttribute("Salida") ~= fundida) then
		volver() -- el servidor lo ha parado: no se sale (falló o es Studio) y hay que ver el aviso
	end
	if not c then
		seguro = false
		devuelta = nil
		mostrar(false)
		return
	end
	local salida = c:GetAttribute("Salida")
	local queda = if salida then salida - workspace:GetServerTimeNow() else nil
	if queda and queda <= 0.3 then -- un poco antes: en Studio el servidor lo para enseguida
		if fundida ~= salida and devuelta ~= salida then
			fundir(salida)
		end
		mostrar(false, true)
		return
	end
	local esDueno = c:GetAttribute("Dueno") == jugador.UserId
	colocar(esDueno)
	mostrar(fundida == nil)
	soltarRaton() -- (se mira cada vez: puede acercar o alejar la cámara sentado)
	if not esDueno then
		local dueno = Players:GetPlayerByUserId(c:GetAttribute("Dueno") or 0)
		titulo.Text = if queda then texto("Leaving in {n}…", { n = math.ceil(queda) })
			else texto("Waiting for {name}…", { name = if dueno then dueno.DisplayName else "…" })
		return
	end
	titulo.Text = texto("Choose a game")
	local p = partidas()
	local elegida = c:GetAttribute("Ranura") or 1
	-- Las suyas (más con el pase MasRanuras): las fichas se reparten el ancho.
	local cuantas = Stats.ranuras(jugador)
	local hay = p[tostring(elegida)] ~= nil
	local empiezaDeCero = c:GetAttribute("Nueva") == true
	if empiezaDeCero then
		seguro = false -- ya ha llegado lo confirmado con el segundo toque
	end
	pintarFichas(p, elegida, cuantas, if empiezaDeCero and hay then elegida else nil, queda ~= nil)

	nueva.Visible = hay and not queda
	nueva.Text = if empiezaDeCero then texto("Keep my save") elseif seguro then texto("Sure? It erases it")
		else texto("New game")
	local avisa = seguro and not empiezaDeCero
	nueva.BackgroundColor3 = if avisa then ROJO_BOTON else Ui.Color.Papel
	if avisa ~= seguroAntes then
		seguroAntes = avisa
		if avisa then
			respingo(nueva) -- "¿SEGURO?": que se vea que espera el segundo toque
		end
	end
	empezar.Interactable = queda == nil
	empezar.Text = if queda then texto("Leaving in {n}…", { n = math.ceil(queda) })
		elseif empiezaDeCero then texto("Start over")
		elseif hay then texto("Continue")
		else texto("Start")
end

local function crearFicha(i: number): Ficha
	local boton = Ui.boton("", { Name = `Ranura{i}`, LayoutOrder = i, AnchorPoint = Vector2.new(0.5, 0.5) })
	local borde = boton:FindFirstChildOfClass("UIStroke") :: UIStroke
	-- Como una ficha de cartulina: un poco más oscura abajo.
	local luz = Instance.new("UIGradient")
	luz.Rotation = 90
	luz.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(186, 182, 176))
	luz.Parent = boton
	Ui.texto(tostring(i), {
		Name = "Numero",
		Position = UDim2.fromOffset(8, 4),
		Size = UDim2.fromOffset(30, LETRA_NUMERO + 3),
		TextSize = LETRA_NUMERO,
		TextTransparency = 0.45,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = boton
	local estado = Ui.texto("", {
		Name = "Estado",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, 6),
		Size = UDim2.new(1, 0, 0, 32),
	})
	Ui.queQuepa(estado, LETRA_FICHA)
	estado.Parent = boton
	local tachon = Instance.new("Frame")
	tachon.Name = "Tachon"
	tachon.AnchorPoint = Vector2.new(0, 0.5)
	tachon.Position = UDim2.new((1 - TACHON) / 2, 0, 0.5, 6)
	tachon.Size = UDim2.new(TACHON, 0, 0, 3)
	tachon.Rotation = -6
	tachon.BackgroundColor3 = ROJO
	tachon.BorderSizePixel = 0
	tachon.Visible = false
	tachon.ZIndex = 2
	tachon.Parent = boton
	local cinta = Instance.new("Frame")
	cinta.Name = "Marcapaginas"
	cinta.AnchorPoint = Vector2.new(0.5, 0)
	cinta.Position = UDim2.new(1, -18, 0, -3)
	cinta.Size = UDim2.fromOffset(CINTA.X, CINTA.Y)
	cinta.BackgroundColor3 = ROJO
	cinta.BorderSizePixel = 0
	cinta.Visible = false
	cinta.ZIndex = 3
	cinta.Parent = boton
	boton.Activated:Connect(function()
		if visible then
			seguro = false
			local c = coche()
			if c and (c:GetAttribute("Ranura") or 1) ~= i then
				Sonido.tocar("Papel") -- como pasar a otra ficha (al pulsar, sin esperar al servidor)
			end
			Remotes.Coche:FireServer("Ranura", i)
		end
	end)
	return { boton = boton, borde = borde, estado = estado, cinta = cinta, tachon = tachon }
end

local function construir()
	local hud = Ui.hud()
	-- El papel es un botón: se queda los toques (no mueven la cámara ni el joystick); ver primeraPersona.
	panel = Instance.new("TextButton")
	panel.Name = "Coche"
	panel.Text = ""
	panel.AutoButtonColor = false
	panel.Selectable = false
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -ABAJO)
	panel.Size = UDim2.fromOffset(ANCHO, ALTO_DUENO)
	panel.BackgroundColor3 = Ui.Color.Papel
	panel.BackgroundTransparency = 0.08
	panel.ClipsDescendants = true
	panel.Visible = false
	panel.ZIndex = 10
	local viejo = Instance.new("UIGradient") -- papel viejo: más oscuro abajo
	viejo.Rotation = 90
	viejo.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 194, 186))
	viejo.Parent = panel
	local borde = Instance.new("UIStroke")
	borde.Color = Ui.Color.Hueso
	borde.Transparency = 0.75
	borde.Parent = panel
	Ui.mancha(panel)

	titulo = Ui.texto("", { Name = "Titulo", TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 2 })
	Ui.queQuepa(titulo, LETRA_TITULO) -- "Esperando a {name}…" con nombres largos
	titulo.Parent = panel
	-- Raya bajo el título, como una hoja de libreta.
	raya = Instance.new("Frame")
	raya.Name = "Raya"
	raya.Position = UDim2.fromOffset(MARGEN, 12 + TITULO + 4)
	raya.Size = UDim2.new(1, -2 * MARGEN, 0, 2)
	raya.BackgroundColor3 = ROJO
	raya.BackgroundTransparency = 0.35
	raya.BorderSizePixel = 0
	raya.ZIndex = 2
	raya.Parent = panel

	fila = Instance.new("Frame")
	fila.Name = "Ranuras"
	fila.BackgroundTransparency = 1
	fila.Position = UDim2.fromOffset(MARGEN, 12 + TITULO + HUECO)
	fila.Size = UDim2.new(1, -2 * MARGEN, 0, FICHA)
	fila.ZIndex = 2
	for i = 1, Stats.RANURAS_MAX do -- (las coloca pintarFichas)
		local f = crearFicha(i)
		f.boton.Parent = fila
		fichas[i] = f
	end
	fila.Parent = panel

	bajar = Ui.boton(Lang.t(nil, "Get out"), {
		Name = "Bajar",
		AnchorPoint = Vector2.new(0.5, 0.5), -- (lo coloca colocar)
		Size = UDim2.fromOffset(BAJAR_ANCHO, BOTON),
		ZIndex = 2,
	})
	Ui.queQuepa(bajar, LETRA_BOTON)
	bajar.Activated:Connect(function()
		local humanoide = jugador.Character and jugador.Character:FindFirstChildOfClass("Humanoid")
		if humanoide then
			humanoide.Sit = false -- (Jump = true desde un script no lo levanta del asiento)
		end
	end)
	bajar.Parent = panel

	-- NUEVA PARTIDA y EMPEZAR, abajo a la derecha (a la izquierda queda BAJAR); se reparten lo que quede, con HUECO
	-- entre los dos. EMPEZAR siempre a la derecha del todo (sin nada guardado, NUEVA PARTIDA no sale).
	derecha = Instance.new("Frame")
	derecha.Name = "Abajo"
	derecha.BackgroundTransparency = 1
	derecha.AnchorPoint = Vector2.new(1, 1)
	derecha.Position = UDim2.new(1, -MARGEN, 1, -14)
	derecha.Size = UDim2.new(1, -(2 * MARGEN + BAJAR_ANCHO + 2 * HUECO), 0, BOTON)
	derecha.ZIndex = 2
	nueva = Ui.boton("", {
		Name = "Nueva",
		LayoutOrder = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.25, -HUECO / 4, 0.5, 0),
		Size = UDim2.new(0.5, -HUECO / 2, 1, 0),
	})
	Ui.queQuepa(nueva, LETRA_BOTON - 1) -- "SEGUIR CON LA GUARDADA" cabe en dos líneas
	-- Deja NUEVA PARTIDA en "¿SEGURO?" SEGURO s, contados desde ahora.
	local function armar()
		seguro = true
		vezSeguro += 1
		local mia = vezSeguro
		task.delay(SEGURO, function()
			if vezSeguro == mia and seguro then
				seguro = false
				pintar()
			end
		end)
	end
	nueva.Activated:Connect(function()
		local c = coche()
		if not c or not visible then
			return
		end
		-- Un doble toque sin querer no cuenta: el segundo no confirma ni pide nada. Cada toque cuenta como el último,
		-- así que entre los dos hay que parar DOBLE s; el botón da un respingo para que se vea que sigue esperando.
		local ahora = os.clock()
		local seguido = ahora - toqueNueva < DOBLE
		toqueNueva = ahora
		if seguido then
			respingo(nueva)
			return
		end
		if c:GetAttribute("Nueva") then
			Remotes.Coche:FireServer("Nueva", false)
		elseif seguro then
			Remotes.Coche:FireServer("Nueva", true)
			-- Sigue en "¿SEGURO?" hasta que llegue Nueva del servidor (lo quita pintar): así no vuelve un momento a
			-- NUEVA PARTIDA, donde otro toque lo volvería a armar. Si no llega, se olvida a los SEGURO s.
			armar()
		else
			armar()
		end
		pintar()
	end)
	nueva.Parent = derecha
	empezar = Ui.boton("", {
		Name = "Empezar",
		LayoutOrder = 2,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.75, HUECO / 4, 0.5, 0),
		Size = UDim2.new(0.5, -HUECO / 2, 1, 0),
		BackgroundColor3 = ROJO_BOTON, -- lo principal, con más rojo
	})
	local bordeEmpezar = empezar:FindFirstChildOfClass("UIStroke") :: UIStroke
	bordeEmpezar.Color = ROJO
	bordeEmpezar.Thickness = 3
	Ui.queQuepa(empezar, LETRA_BOTON + 4)
	empezar.Activated:Connect(function()
		if visible then
			Remotes.Coche:FireServer("Arrancar")
		end
	end)
	empezar.Parent = derecha
	derecha.Parent = panel
	panel.Parent = hud

	-- El fundido va en su propia capa, por encima de todo el HUD (y del de SalidaVista, que es el que se ve: este se
	-- esconde con el resto de la interfaz mientras dura la cinemática).
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

---------------------------------------------------------------- bajarse del coche

-- Al bajarte (saltando o con BAJAR) sales de pie junto a la puerta de tu lado. Sin esto caías en el suelo del coche,
-- entre las puertas (que chocan), con la cabeza por el techo (visto en Studio, 03-11-2026). Lo hace este cliente: el
-- personaje es suyo (desde el servidor se perdía y arrastraba el asiento, que aún iba soldado).
local SALIDA_HUECO = 1.6 -- studs entre el lado del coche y el centro del que sale
local SALIDA_CAJA = Vector3.new(2, 4.4, 2) -- lo que ocupa de pie (para ver si cabe)

-- Hasta dónde llega lo que choca del coche, desde su centro: (de lado, de largo).
local function medidas(modelo: Model, ref: CFrame): (number, number)
	local deLado, deLargo = 0, 0
	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") and d.CanCollide then
			local cf, s, rel = d.CFrame, d.Size / 2, d.Position - ref.Position
			local function hasta(eje: Vector3): number
				return math.abs(rel:Dot(eje)) + s.X * math.abs(cf.RightVector:Dot(eje)) + s.Y * math.abs(cf.UpVector:Dot(eje))
					+ s.Z * math.abs(cf.LookVector:Dot(eje))
			end
			deLado = math.max(deLado, hasta(ref.RightVector))
			deLargo = math.max(deLargo, hasta(ref.LookVector))
		end
	end
	return deLado, deLargo
end

local function sacar(asiento: Seat)
	local cuerpo = jugador.Character
	local humanoide = cuerpo and cuerpo:FindFirstChildOfClass("Humanoid")
	local raiz = humanoide and humanoide.RootPart
	local modelo = asiento.Parent
	local carroceria = modelo and modelo:IsA("Model") and modelo.PrimaryPart
	if not (cuerpo and humanoide and raiz and carroceria and humanoide.Health > 0) then
		return
	end
	-- Hasta que no se suelte del asiento, moverlo arrastraría el asiento con él.
	local hasta = os.clock() + 1.5
	while os.clock() < hasta do
		local soldado = false
		for _, w in asiento:GetChildren() do
			if w:IsA("JointInstance") and (w.Part0 == raiz or w.Part1 == raiz) then
				soldado = true
			end
		end
		if not soldado then
			break
		end
		task.wait()
	end
	if humanoide.SeatPart or humanoide.Health <= 0 or not cuerpo:IsDescendantOf(workspace) then
		return -- se ha vuelto a sentar o ya no está
	end
	local base = carroceria.CFrame
	local deLado, deLargo = medidas(modelo :: Model, base)
	local rel = base:PointToObjectSpace(asiento.Position)
	local lado = if rel.X < 0 then -1 else 1
	local sitios = {
		Vector3.new(lado * (deLado + SALIDA_HUECO), 0, rel.Z), -- por su puerta
		Vector3.new(-lado * (deLado + SALIDA_HUECO), 0, rel.Z), -- por la otra
		Vector3.new(0, 0, deLargo + SALIDA_HUECO), -- por detrás
		Vector3.new(0, 0, -(deLargo + SALIDA_HUECO)), -- por delante
	}
	local alto = if humanoide.RigType == Enum.HumanoidRigType.R15 then humanoide.HipHeight + raiz.Size.Y / 2 else 3
	local rayo = RaycastParams.new()
	rayo.FilterType = Enum.RaycastFilterType.Exclude
	rayo.FilterDescendantsInstances = { cuerpo, modelo }
	local caja = OverlapParams.new()
	caja.FilterType = Enum.RaycastFilterType.Exclude
	caja.FilterDescendantsInstances = { cuerpo, modelo }
	caja.RespectCanCollide = true
	for _, sitio in sitios do
		local punto = base:PointToWorldSpace(sitio)
		local suelo = workspace:Raycast(Vector3.new(punto.X, base.Position.Y + 2, punto.Z), Vector3.new(0, -8, 0), rayo)
		if not suelo or suelo.Position.Y > base.Position.Y then
			continue -- sin suelo, o encima de algo alto (un surtidor, la isla): ahí no
		end
		local pie = suelo.Position
		if #workspace:GetPartBoundsInBox(CFrame.new(pie + Vector3.new(0, 0.3 + SALIDA_CAJA.Y / 2, 0)), SALIDA_CAJA, caja) > 0 then
			continue -- no cabe (otro coche, una columna, otro jugador)
		end
		local fuera = Vector3.new(punto.X - base.Position.X, 0, punto.Z - base.Position.Z)
		local donde = pie + Vector3.new(0, alto, 0)
		cuerpo:PivotTo(if fuera.Magnitude > 0.01 then CFrame.lookAt(donde, donde + fuera.Unit) else CFrame.new(donde))
		raiz.AssemblyLinearVelocity = Vector3.zero
		return
	end
end

-- Sentado en un coche, su "Get in" fuera en este cliente (como la tienda): seguía a la vista mientras quedasen plazas
-- y en el móvil el botón grande de Controles no servía de nada y se montaba con el papel. Enabled lo cambia el
-- servidor (rehacer): si lo enciende mientras sigues sentado, se vuelve a apagar. Al bajarte se enciende: acabas de
-- dejar una plaza libre, y si el servidor dice otra cosa su cambio llega después y manda. (MaxActivationDistance no:
-- lo usa SalidaVista para esconder el coche que se va.)
local apagado: { prompt: ProximityPrompt, conexion: RBXScriptConnection }? = nil

local function encenderPrompt()
	local a = apagado
	if a then
		apagado = nil
		a.conexion:Disconnect()
		a.prompt.Enabled = true
	end
end

local function apagarPrompt(asiento: BasePart?)
	encenderPrompt()
	local modelo = asiento and asiento:IsA("Seat") and asiento.Parent
	if not (modelo and modelo:HasTag("Coche")) then
		return
	end
	local carroceria = modelo:FindFirstChild("Carroceria")
	local prompt = carroceria and carroceria:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end
	prompt.Enabled = false -- (solo en este cliente)
	apagado = {
		prompt = prompt,
		conexion = prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
			if prompt.Enabled then
				prompt.Enabled = false
			end
		end),
	}
end

-- Vigila el asiento de tu personaje: al dejar el de un coche, te saca.
local function vigilarAsiento(cuerpo: Model)
	encenderPrompt() -- el personaje de antes pudo irse sentado (sin cambiar de SeatPart)
	local humanoide = cuerpo:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoide then
		return
	end
	local antes: BasePart? = humanoide.SeatPart
	apagarPrompt(antes)
	humanoide:GetPropertyChangedSignal("SeatPart"):Connect(function()
		local asiento = antes
		antes = humanoide.SeatPart
		apagarPrompt(antes)
		if asiento and not humanoide.SeatPart and asiento:IsA("Seat") and asiento.Parent
			and asiento.Parent:HasTag("Coche") then
			task.spawn(sacar, asiento)
		end
	end)
end

function CochesUi.start()
	construir()
	if jugador.Character then
		task.spawn(vigilarAsiento, jugador.Character)
	end
	jugador.CharacterAdded:Connect(vigilarAsiento)
	Sonido.precargar({ "Papel" })
	jugador:GetAttributeChangedSignal("Coche"):Connect(pintar)
	jugador:GetAttributeChangedSignal("Partidas"):Connect(pintar)
	jugador:GetAttributeChangedSignal("PaseMasRanuras"):Connect(pintar)
	-- Un solo bucle lento para la cuenta atrás, lo que cambie en el coche (dueño, ranura…) y el ancho de la pantalla.
	task.spawn(function()
		while true do
			task.wait(0.2)
			pintar()
		end
	end)
end

return CochesUi
