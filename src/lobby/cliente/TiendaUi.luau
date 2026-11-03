-- La tienda del mostrador de la gasolinera (aquí solo se pide y se pinta; compra el servidor en Comun.Tienda).
--   Pedido por el usuario: "que siga el estilo oscuro de Ui y se vea bien en el móvil", y que parezca la libreta o el
--   catálogo viejo de la gasolinera. Una libreta de espiral: papel oscuro con las anillas a la izquierda, el margen
--   rojo, un renglón bajo cada cosa, la esquina manchada de sangre y la marca de una taza. Por la derecha asoman tres
--   separadores: CLASES (comprar; la primera gratis; elegir la que llevas a la partida), LUCES (el color de la
--   linterna) y ROBUX (pases y paquetes de monedas: abre la compra el servidor, Comun.Compras).
--   Lo tuyo lleva un sello rojo (ELEGIDA, EN USO, TUYO), que se estampa al conseguirlo con la tienda abierta.
--   Comprar con monedas pide dos toques ("¿COMPRAR?", que se olvida a los SEGURO s) para que no se gasten sin querer;
--   con Robux ya pregunta Roblox.
--   Sale con un fundido y un pequeño desliz; cambiar de separador pasa la hoja; las monedas saltan al cambiar. Suena el
--   papel al pasar la hoja y al cerrarla (CLAUDE.md: al pulsar y al cerrar, no al abrir). Con Rendimiento, sin
--   animaciones. Se cierra con la X o al alejarse del mostrador.
--   En el móvil (docs/sistemas/movil.md): botones de un dedo, por debajo de la barra de Roblox y sin tapar el botón de
--   saltar (el papel se mide al abrir con lo que cabe en la pantalla).
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Prueba = require(ReplicatedStorage.Shared.Prueba)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Stats = require(ReplicatedStorage.Shared.Stats)
local Sonido = require(script.Parent.Sonido)
local Ui = require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))

local TiendaUi = {}

local jugador = Players.LocalPlayer
local LEJOS = 16 -- studs del mostrador a los que se cierra sola
local ROBUX = "\u{E002}" -- el símbolo de Robux (lo pintan todas las fuentes)
local SEGURO = 4 -- segundos que dura el "¿COMPRAR?" del primer toque
-- Segundos: un toque en el botón de una fila tan seguido del anterior es un doble toque sin querer y no cuenta (si
-- no, en el móvil un doble toque armaría el "¿COMPRAR?" y lo confirmaría a la vez, o abriría dos compras de Robux).
local DOBLE = 0.4
-- Medidas en píxeles de diseño. En el móvil, botones del alto de un dedo (Ui.DEDO): la X, los separadores y los de
-- cada fila, que crecen con ellos. El papel, como mucho ANCHO × ALTO: por debajo de la barra de Roblox (MARGEN_ALTO
-- arriba y abajo) y con LADO libre a cada lado (en el móvil, el botón de saltar de Roblox queda a la derecha, abajo).
local TACTIL = Ui.tactil()
local BOTON = Ui.alto(46) -- el de cada fila
local ANCHO_BOTON = 170
local PESTANA = Ui.alto(46) -- alto de un separador
local CRUZ = Ui.alto(44)
local CRUZ_ANCHO = math.max(48, CRUZ)
local FILA = math.max(if TACTIL then 96 else 82, BOTON + 16)
local ANCHO = if TACTIL then 800 else 760 -- separadores incluidos
local ANCHO_MIN = 600
local ALTO = if TACTIL then 600 else 620
local ALTO_MIN = 380
local LADO = if TACTIL then 190 else 40
local MARGEN_ALTO = 12
local ESPIRAL = 10 -- lo que asoma la espiral por la izquierda del papel
local SALE = if TACTIL then 140 else 120 -- lo que asoman los separadores por la derecha
local METE = 12 -- lo que se meten bajo el papel
local ESCONDIDA = 10 -- lo que se mete de más un separador que no es el abierto
local MARGEN = 46 -- la raya roja del margen, desde el borde izquierdo del papel
local CABEZA = 14 + math.max(44, CRUZ) + 10 -- alto de la cabecera (título, monedas y X)
local TITULO_ANCHO = 180 -- el título de la libreta (TIENDA); las monedas van de su derecha a la X
local LETRA_NOMBRE = if TACTIL then 26 else 24
local LETRA_LINEA = if TACTIL then 18 else 16
local LETRA_BOTON = if TACTIL then 21 else 19
local MUESTRA = if TACTIL then 40 else 34 -- el círculo con el color de la luz
local SELLO_ALTO = if TACTIL then 46 else 40
local GIRO_SELLO = -7 -- grados
local ANILLAS = 18 -- las que se hacen (se enseñan las que caben a lo alto)
local PRIMERA_ANILLA, PASO_ANILLA = 28, 36
-- Colores propios de la libreta (los demás, de Ui).
local ROJO = Color3.fromRGB(150, 34, 28) -- el margen, la raya y el borde de lo principal: tiene que leerse en el papel
local SELLO = Color3.fromRGB(168, 40, 32) -- la tinta del sello
local ROJO_BOTON = Color3.fromRGB(58, 16, 14) -- fondo de GRATIS y del segundo toque
local OSCURA = Color3.fromRGB(13, 11, 10) -- un separador que no es el abierto
local HOJA = Color3.fromRGB(34, 30, 27) -- la hoja que pasa
local METAL = Color3.fromRGB(122, 116, 106) -- la espiral
local AGUJERO = Color3.fromRGB(6, 5, 5)
local CAFE = Color3.fromRGB(74, 50, 30) -- la marca de la taza
-- Animaciones (segundos, píxeles de diseño y grados). Con Rendimiento no se hace ninguna.
local T_ABRIR, T_CERRAR = 0.32, 0.16
local DESLIZ, GIRO = 26, -1.2 -- de dónde llega el papel al abrirse
local T_TAPA, T_DESTAPA = 0.09, 0.14 -- la hoja que pasa al cambiar de separador

local PESTANAS = { { "Clases", "Classes" }, { "Linterna", "Lights" }, { "Robux", "Robux" } }

-- Una cosa de la lista tal y como hay que pintarla.
type Entrada = {
	clave: string,
	orden: number,
	nombre: string,
	linea: string,
	color: Color3?, -- la muestra de la luz
	boton: string?, -- el texto del botón; si es nil, la tienes y va el sello
	sello: string?,
	rojo: boolean?, -- botón con más rojo (GRATIS y el segundo toque)
	seguro: boolean?, -- está en "¿COMPRAR?"
	alPulsar: (() -> ())?, -- nil: el botón sale apagado
}
-- Una fila hecha (se reutiliza mientras no cambie de separador: así el sello se puede estampar).
type Fila = {
	marco: Frame,
	muestra: Frame,
	brillo: UIStroke,
	nombre: TextLabel,
	linea: TextLabel,
	boton: TextButton,
	borde: UIStroke,
	sello: TextLabel,
	tinta: UIStroke,
	escalaSello: UIScale,
	alPulsar: (() -> ())?,
	marcada: boolean,
	seguro: boolean,
	toque: number, -- os.clock() del último toque en su botón (ver DOBLE)
}

local panel: CanvasGroup
local hoja: TextButton
local monedas: TextLabel
local escalaMonedas: UIScale
local lista: ScrollingFrame
local pasar: Frame
local anillas: { Frame } = {}
local pestanas: { [string]: TextButton } = {}
local rellenos: { [string]: UIPadding } = {}
local pestana = "Clases"
local seguro: string? = nil -- el Id que ya ha tocado una vez para comprar
local vezSeguro = 0
local prompt: ProximityPrompt? = nil
local mostrador: BasePart? = nil
local abierta = false
local vez = 0 -- sube al abrir y al cerrar: el tween y el bucle de la vez anterior ya no hacen nada
local posicion = UDim2.fromScale(0.5, 0.5) -- donde queda el papel abierto (colocar)
local filas: { [string]: Fila } = {}
local monedasAntes: number? = nil
local pasando = 0 -- la hoja que pasa: 0 quieta, 1 tapando, 2 destapando
local vuelta = 0 -- sube cada vez que empieza a pasar una hoja

local function texto(frase: string, huecos: { [string]: any }?): string
	return Ui.mayusculas(Lang.t(nil, frase, huecos))
end

local function rendimiento(): boolean
	return jugador:GetAttribute("Rendimiento") == true
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

local function redondo(objeto: GuiObject)
	local esquina = Instance.new("UICorner")
	esquina.CornerRadius = UDim.new(0.5, 0)
	esquina.Parent = objeto
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

local function crearFila(): Fila
	local marco = Instance.new("Frame")
	marco.Name = "Fila"
	marco.Size = UDim2.new(1, -4, 0, FILA)
	marco.BackgroundColor3 = Ui.Color.Hueso
	marco.BackgroundTransparency = 1
	marco.BorderSizePixel = 0
	-- El renglón de la libreta, debajo.
	local renglon = Instance.new("Frame")
	renglon.Name = "Renglon"
	renglon.AnchorPoint = Vector2.new(0, 1)
	renglon.Position = UDim2.fromScale(0, 1)
	renglon.Size = UDim2.new(1, 0, 0, 1)
	renglon.BackgroundColor3 = Ui.Color.Hueso
	renglon.BackgroundTransparency = 0.86
	renglon.BorderSizePixel = 0
	renglon.Parent = marco

	local muestra = Instance.new("Frame")
	muestra.Name = "Muestra"
	muestra.AnchorPoint = Vector2.new(0, 0.5)
	muestra.Position = UDim2.new(0, 6, 0.5, 0)
	muestra.Size = UDim2.fromOffset(MUESTRA, MUESTRA)
	muestra.BorderSizePixel = 0
	muestra.Visible = false
	redondo(muestra)
	local brillo = Instance.new("UIStroke")
	brillo.Thickness = 3
	brillo.Transparency = 0.6
	brillo.Parent = muestra
	muestra.Parent = marco

	local nombre = Ui.texto("", { Name = "Nombre", TextXAlignment = Enum.TextXAlignment.Left })
	Ui.queQuepa(nombre, LETRA_NOMBRE) -- con la pantalla estrecha, encoge antes que cortarse
	nombre.Parent = marco
	local linea = Ui.texto("", {
		Name = "Linea",
		TextTransparency = 0.25,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	})
	Ui.queQuepa(linea, LETRA_LINEA)
	linea.Parent = marco

	-- El botón, centrado en su sitio (así se hunde hacia su centro al pulsarlo).
	local boton = Ui.boton("", {
		Name = "Boton",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -8 - ANCHO_BOTON / 2, 0.5, 0),
		Size = UDim2.fromOffset(ANCHO_BOTON, BOTON),
	})
	Ui.queQuepa(boton, LETRA_BOTON)
	boton.Parent = marco
	local borde = boton:FindFirstChildOfClass("UIStroke") :: UIStroke

	-- El sello de lo tuyo, en su mismo sitio, torcido como uno de goma.
	local sello = Ui.texto("", {
		Name = "Sello",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -8 - ANCHO_BOTON / 2, 0.5, 0),
		Size = UDim2.fromOffset(ANCHO_BOTON - 24, SELLO_ALTO),
		Rotation = GIRO_SELLO,
		TextColor3 = SELLO,
		TextStrokeTransparency = 0.75,
		Visible = false,
	})
	Ui.queQuepa(sello, LETRA_BOTON + 3)
	local tinta = Instance.new("UIStroke")
	tinta.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	tinta.Color = SELLO
	tinta.Thickness = 2
	tinta.Transparency = 0.1
	tinta.Parent = sello
	local esquina = Instance.new("UICorner")
	esquina.CornerRadius = UDim.new(0, 3)
	esquina.Parent = sello
	local escalaSello = Instance.new("UIScale")
	escalaSello.Parent = sello
	sello.Parent = marco

	local fila: Fila = {
		marco = marco,
		muestra = muestra,
		brillo = brillo,
		nombre = nombre,
		linea = linea,
		boton = boton,
		borde = borde,
		sello = sello,
		tinta = tinta,
		escalaSello = escalaSello,
		alPulsar = nil,
		marcada = false,
		seguro = false,
		toque = 0,
	}
	boton.Activated:Connect(function()
		if not abierta or not fila.alPulsar then
			return
		end
		-- Un doble toque sin querer no cuenta: el segundo no confirma "¿COMPRAR?" ni pide otra vez (Robux, elegir, usar).
		-- Cada toque cuenta como el último, así que entre los dos hay que parar DOBLE s; el botón da un respingo.
		local ahora = os.clock()
		local seguido = ahora - fila.toque < DOBLE
		fila.toque = ahora
		if seguido then
			respingo(boton)
			return
		end
		fila.alPulsar()
	end)
	marco.Parent = lista
	return fila
end

-- Pinta una fila. `animar`: la fila ya estaba (se estampa el sello si acaba de ser tuyo y el botón da un respingo si
-- espera el segundo toque); una fila nueva (al abrir o al pasar la hoja) sale quieta.
local function actualizar(fila: Fila, e: Entrada, animar: boolean)
	local mover = animar and not rendimiento()
	fila.marco.LayoutOrder = e.orden
	local izquierda = if e.color then 6 + MUESTRA + 14 else 8
	fila.muestra.Visible = e.color ~= nil
	if e.color then
		fila.muestra.BackgroundColor3 = e.color
		fila.brillo.Color = e.color
	end
	-- (Ui.queQuepa pone 8 de margen a cada lado: se descuentan para que el texto empiece en `izquierda`.)
	local resto = -(izquierda - 8) - (ANCHO_BOTON + 22)
	local arriba = 6 + LETRA_NOMBRE + 6
	fila.nombre.Position = UDim2.fromOffset(izquierda - 8, 6)
	fila.nombre.Size = UDim2.new(1, resto, 0, LETRA_NOMBRE + 4)
	fila.nombre.Text = Ui.mayusculas(e.nombre)
	fila.linea.Position = UDim2.fromOffset(izquierda - 8, arriba)
	fila.linea.Size = UDim2.new(1, resto, 1, -arriba - 6)
	fila.linea.Text = e.linea

	local marcada = e.sello ~= nil
	fila.marco.BackgroundTransparency = if marcada then 0.95 else 1
	fila.boton.Visible = not marcada
	fila.sello.Visible = marcada
	if marcada then
		fila.sello.Text = e.sello :: string
		if not fila.marcada then
			if mover then
				-- Se estampa: llega grande y sin tinta y da contra el papel.
				fila.escalaSello.Scale = 1.7
				fila.sello.TextTransparency = 1
				fila.tinta.Transparency = 1
				TweenService:Create(fila.escalaSello, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ Scale = 1 }):Play()
				TweenService:Create(fila.sello, TweenInfo.new(0.12), { TextTransparency = 0 }):Play()
				TweenService:Create(fila.tinta, TweenInfo.new(0.12), { Transparency = 0.1 }):Play()
			else
				fila.escalaSello.Scale = 1
				fila.sello.TextTransparency = 0
				fila.tinta.Transparency = 0.1
			end
		end
	else
		local se = e.alPulsar ~= nil
		fila.boton.Text = e.boton or ""
		fila.boton.Interactable = se
		fila.boton.Selectable = se
		fila.boton.TextTransparency = if se then 0 else 0.5
		fila.boton.BackgroundTransparency = if se then 0.15 else 0.5
		fila.boton.BackgroundColor3 = if e.rojo then ROJO_BOTON else Ui.Color.Papel
		fila.borde.Color = if e.rojo then ROJO else Ui.Color.Sangre
		fila.borde.Transparency = if se then 0 else 0.6
		if e.seguro and not fila.seguro and mover then
			respingo(fila.boton) -- "¿COMPRAR?": que se vea que espera el segundo toque
		end
	end
	fila.alPulsar = e.alPulsar
	fila.marcada = marcada
	fila.seguro = e.seguro == true
end

local pintar: (deCero: boolean?) -> ()

-- Primer toque: "¿COMPRAR?" durante SEGURO s. Segundo toque (el doble toque sin querer ya no llega: crearFila): se
-- pide, y sigue en "¿COMPRAR?" hasta que responda el servidor (ya tuyo, la fila deja de pasar por aquí) o pasen otros
-- SEGURO s; así no vuelve un momento al precio, donde otro toque lo volvería a armar.
local function comprar(accion: string, id: string)
	if seguro == id then
		Remotes.Tienda:FireServer(accion, id)
	end
	seguro = id
	vezSeguro += 1
	local mia = vezSeguro
	task.delay(SEGURO, function()
		if vezSeguro == mia and seguro == id then
			seguro = nil
			if abierta then
				pintar()
			end
		end
	end)
end

-- El botón de comprar de algo que no tiene: el precio (GRATIS, en rojo) y al primer toque "¿COMPRAR?".
local function compra(e: Entrada, accion: string, id: string, precio: number)
	local espera = seguro == id
	e.seguro = espera
	e.rojo = espera or precio == 0
	e.boton = if espera then texto("Buy?") elseif precio == 0 then texto("Free") else texto("{n} coins", { n = precio })
	e.alPulsar = function()
		comprar(accion, id)
		pintar()
	end
end

-- Lo que va en la hoja del separador abierto, en orden.
local function entradas(): { Entrada }
	local hay: { Entrada } = {}
	if pestana == "Clases" then
		local tiene = suyas("Clases")
		local elegida = jugador:GetAttribute("Clase")
		for i, clase in Config.Clases do
			local e: Entrada = {
				clave = "Clase:" .. clase.Id,
				orden = i,
				nombre = Lang.t(nil, clase.Nombre),
				linea = Lang.t(nil, clase.Texto),
			}
			if tiene[clase.Id] ~= true then
				compra(e, "Clase", clase.Id, precioClase(clase))
			elseif elegida == clase.Id then
				e.sello = texto("Chosen")
			else
				e.boton = texto("Choose")
				e.alPulsar = function()
					seguro = nil
					Remotes.Clase:FireServer(clase.Id)
				end
			end
			table.insert(hay, e)
		end
	elseif pestana == "Robux" then
		-- Sin Id aún no se puede comprar (salvo probando en Studio): el botón sale apagado.
		local function sePuede(producto): boolean
			return producto.Id > 0 or Prueba.activa()
		end
		for i, pase in Config.Compras.Pases do
			local e: Entrada = {
				clave = "Pase:" .. pase.Ventaja,
				orden = i,
				nombre = Lang.t(nil, pase.Nombre),
				linea = Lang.t(nil, pase.Texto),
			}
			if Stats.pase(jugador, pase.Ventaja) then
				e.sello = texto("Owned")
			else
				e.boton = `{ROBUX}{pase.Robux}`
				if sePuede(pase) then
					e.alPulsar = function()
						Remotes.Compra:FireServer("Pase", pase.Ventaja)
					end
				end
			end
			table.insert(hay, e)
		end
		for i, paquete in Config.Compras.Monedas do
			local e: Entrada = {
				clave = "Monedas:" .. i,
				orden = 100 + i,
				nombre = Lang.t(nil, "{n} coins", { n = paquete.Monedas }),
				linea = Lang.t(nil, "For classes and lights."),
				boton = `{ROBUX}{paquete.Robux}`,
			}
			if sePuede(paquete) then
				e.alPulsar = function()
					Remotes.Compra:FireServer("Monedas", i)
				end
			end
			table.insert(hay, e)
		end
	else
		local tiene = suyas("Cosmeticos")
		local puesta = jugador:GetAttribute("PuestoLinterna")
		local linea = Lang.t(nil, "The color of your flashlight.")
		local calida: Entrada = {
			clave = "Luz:",
			orden = 0,
			nombre = Lang.t(nil, "Warm light"),
			linea = linea,
			color = Color3.fromRGB(255, 236, 205),
		}
		if puesta then
			calida.boton = texto("Use")
			calida.alPulsar = function()
				seguro = nil
				Remotes.Tienda:FireServer("Poner", "Linterna", "")
			end
		else
			calida.sello = texto("In use")
		end
		table.insert(hay, calida)
		for i, cosa in Config.Cosmeticos do
			if cosa.Tipo ~= "Linterna" then
				continue
			end
			local e: Entrada = {
				clave = "Luz:" .. cosa.Id,
				orden = i,
				nombre = Lang.t(nil, cosa.Nombre),
				linea = linea,
				color = Color3.fromRGB(table.unpack(cosa.Color)),
			}
			if tiene[cosa.Id] ~= true then
				compra(e, "Cosmetico", cosa.Id, cosa.Precio)
			elseif puesta == cosa.Id then
				e.sello = texto("In use")
			else
				e.boton = texto("Use")
				e.alPulsar = function()
					seguro = nil
					Remotes.Tienda:FireServer("Poner", "Linterna", cosa.Id)
				end
			end
			table.insert(hay, e)
		end
	end
	return hay
end

-- `deCero`: se tira la hoja y se hace otra (al abrir o al cambiar de separador), arriba del todo. Si no, se repinta
-- encima de la que hay (sin moverla).
function pintar(deCero: boolean?)
	monedas.Text = texto("{n} coins", { n = math.floor(jugador:GetAttribute("Monedas") or 0) })
	if deCero then
		for _, fila in filas do
			fila.marco:Destroy()
		end
		table.clear(filas)
		lista.CanvasPosition = Vector2.zero
	end
	local vistas: { [string]: boolean } = {}
	for _, e in entradas() do
		vistas[e.clave] = true
		local fila = filas[e.clave]
		local estaba = fila ~= nil
		if fila == nil then
			fila = crearFila()
			filas[e.clave] = fila
		end
		actualizar(fila, e, estaba)
	end
	for clave, fila in filas do
		if not vistas[clave] then
			fila.marco:Destroy()
			filas[clave] = nil
		end
	end
end

-- El abierto, del color del papel y por encima de él (pegado a la hoja); los demás, oscuros, por debajo y metidos.
local function pintarPestanas(animar: boolean)
	for i, p in PESTANAS do
		local b = pestanas[p[1]]
		local es = p[1] == pestana
		local borde = b:FindFirstChildOfClass("UIStroke") :: UIStroke
		b.ZIndex = if es then 3 else 1
		b.BackgroundColor3 = if es then Ui.Color.Papel else OSCURA
		b.TextTransparency = if es then 0 else 0.4
		borde.Color = if es then Ui.Color.Hueso else Ui.Color.Sangre
		borde.Transparency = if es then 0.55 else 0.15
		-- El texto, centrado en lo que asoma.
		rellenos[p[1]].PaddingLeft = UDim.new(0, if es then METE else METE + ESCONDIDA)
		local destino = UDim2.new(1, -(SALE + METE + 2) - (if es then 0 else ESCONDIDA), 0,
			CABEZA + 12 + (i - 1) * (PESTANA + 10) + PESTANA / 2)
		if animar and not rendimiento() then
			TweenService:Create(b, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = destino })
				:Play()
		else
			b.Position = destino
		end
	end
end

-- Tamaño y sitio del papel con lo que cabe ahora en la pantalla (al abrir y si cambia la pantalla).
local function colocar()
	local lienzo = Ui.lienzo()
	if lienzo.X < 200 or lienzo.Y < 200 then
		lienzo = Vector2.new(1280, 720) -- aún sin medir
	end
	local barra = GuiService.TopbarInset.Max.Y / Ui.escala()
	local ancho = math.clamp(lienzo.X - 2 * LADO, ANCHO_MIN, ANCHO)
	local alto = math.clamp(lienzo.Y - barra - 2 * MARGEN_ALTO, ALTO_MIN, ALTO)
	panel.Size = UDim2.fromOffset(ancho, alto)
	posicion = UDim2.new(0.5, 0, 0, barra + (lienzo.Y - barra) / 2) -- centrado en lo que queda bajo la barra
	for i, anilla in anillas do
		local y = PRIMERA_ANILLA + (i - 1) * PASO_ANILLA
		anilla.Position = UDim2.fromOffset(0, y)
		anilla.Visible = y <= alto - PRIMERA_ANILLA
	end
end

-- Cambiar de separador: suena el papel y pasa una hoja de derecha a izquierda que tapa la lista y la destapa ya con lo
-- nuevo (se repinta cuando está tapada del todo).
local function cambiarPestana(nueva: string)
	if not abierta or nueva == pestana then
		return
	end
	pestana = nueva
	seguro = nil
	pintarPestanas(true)
	Sonido.tocar("Papel")
	if rendimiento() or pasando == 2 then
		pintar(true) -- (destapando: se cambia debajo de la hoja que se va)
		return
	elseif pasando == 1 then
		return -- tapando: al acabar se pinta el que toque
	end
	vuelta += 1
	local mia = vuelta
	pasando = 1
	pasar.AnchorPoint = Vector2.new(1, 0)
	pasar.Position = UDim2.fromScale(1, 0)
	pasar.Size = UDim2.fromScale(0, 1)
	pasar.Visible = true
	local tapa = TweenService:Create(pasar, TweenInfo.new(T_TAPA, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Size = UDim2.fromScale(1, 1) })
	tapa.Completed:Once(function()
		if vuelta ~= mia then
			return
		end
		pintar(true)
		pasando = 2
		pasar.AnchorPoint = Vector2.zero
		pasar.Position = UDim2.fromScale(0, 0)
		local destapa = TweenService:Create(pasar, TweenInfo.new(T_DESTAPA, Enum.EasingStyle.Quad,
			Enum.EasingDirection.Out), { Size = UDim2.fromScale(0, 1) })
		destapa.Completed:Once(function()
			if vuelta == mia then
				pasando = 0
				pasar.Visible = false
			end
		end)
		destapa:Play()
	end)
	tapa:Play()
end

-- La hoja que pasa, quieta y escondida (al abrir y al cerrar).
local function pararHoja()
	vuelta += 1
	pasando = 0
	pasar.Visible = false
end

local function cerrar()
	if not abierta then
		return
	end
	abierta = false
	vez += 1
	local mia = vez
	seguro = nil
	hoja.Modal = false
	pararHoja()
	Sonido.tocar("Papel")
	if prompt then
		prompt.Enabled = true
	end
	if rendimiento() then
		panel.Visible = false
		return
	end
	local fuera = TweenService:Create(panel, TweenInfo.new(T_CERRAR, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		GroupTransparency = 1,
		Position = posicion + UDim2.fromOffset(0, DESLIZ * 0.6),
	})
	fuera.Completed:Once(function()
		if vez == mia then
			panel.Visible = false
		end
	end)
	fuera:Play()
end

local function abrir()
	if abierta then
		return
	end
	abierta = true
	vez += 1
	local mia = vez
	seguro = nil
	pararHoja()
	colocar()
	pintarPestanas(false)
	pintar(true)
	monedasAntes = jugador:GetAttribute("Monedas")
	hoja.Modal = true -- suelta el ratón si estaba en primera persona
	panel.Visible = true
	if rendimiento() then
		panel.GroupTransparency = 0
		panel.Position = posicion
		panel.Rotation = 0
	else
		-- Llega desde un poco más abajo y algo torcida, como una libreta que te dejan en el mostrador.
		panel.GroupTransparency = 1
		panel.Position = posicion + UDim2.fromOffset(0, DESLIZ)
		panel.Rotation = GIRO
		TweenService:Create(panel, TweenInfo.new(T_ABRIR, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = posicion,
			Rotation = 0,
		}):Play()
		TweenService:Create(panel, TweenInfo.new(T_ABRIR * 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			GroupTransparency = 0,
		}):Play()
	end
	if prompt then
		prompt.Enabled = false -- (solo en este cliente)
	end
	-- Cerrarla al alejarse (un bucle lento, solo mientras está abierta).
	task.spawn(function()
		while vez == mia do
			task.wait(0.5)
			local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if vez == mia and (not raiz or not mostrador or (raiz.Position - mostrador.Position).Magnitude > LEJOS) then
				cerrar()
			end
		end
	end)
end

-- Al cambiar las monedas con la tienda abierta, el número da un salto (y se pone rojo un momento si has gastado).
local function alCambiarMonedas()
	if not abierta then
		return
	end
	local antes, ahora = monedasAntes, jugador:GetAttribute("Monedas")
	monedasAntes = ahora
	pintar()
	if type(antes) ~= "number" or type(ahora) ~= "number" or antes == ahora or rendimiento() then
		return
	end
	escalaMonedas.Scale = 1.18
	TweenService:Create(escalaMonedas, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		:Play()
	if ahora < antes then
		monedas.TextColor3 = SELLO
		TweenService:Create(monedas, TweenInfo.new(0.7), { TextColor3 = Ui.Color.Hueso }):Play()
	end
end

-- Una anilla de la espiral: el agujero del papel y el alambre que entra por él y asoma por fuera.
local function crearAnilla(): Frame
	local anilla = Instance.new("Frame")
	anilla.Name = "Anilla"
	anilla.AnchorPoint = Vector2.new(0, 0.5)
	anilla.Size = UDim2.fromOffset(ESPIRAL + 24, 12)
	anilla.BackgroundTransparency = 1
	anilla.ZIndex = 4
	local agujero = Instance.new("Frame")
	agujero.Name = "Agujero"
	agujero.AnchorPoint = Vector2.new(0.5, 0.5)
	agujero.Position = UDim2.new(0, ESPIRAL + 16, 0.5, 0)
	agujero.Size = UDim2.fromOffset(10, 10)
	agujero.BackgroundColor3 = AGUJERO
	agujero.BorderSizePixel = 0
	agujero.ZIndex = 4
	redondo(agujero)
	agujero.Parent = anilla
	local alambre = Instance.new("Frame")
	alambre.Name = "Alambre"
	alambre.AnchorPoint = Vector2.new(0, 0.5)
	alambre.Position = UDim2.new(0, 1, 0.5, 0)
	alambre.Size = UDim2.fromOffset(ESPIRAL + 18, 5)
	alambre.Rotation = -8 -- la espiral va un poco inclinada
	alambre.BackgroundColor3 = METAL
	alambre.BorderSizePixel = 0
	alambre.ZIndex = 5
	redondo(alambre)
	local reflejo = Instance.new("UIGradient")
	reflejo.Rotation = 90
	reflejo.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(96, 96, 96))
	reflejo.Parent = alambre
	alambre.Parent = anilla
	return anilla
end

-- La marca de una taza de café, muy floja (un aro doble).
local function crearTaza(padre: GuiObject)
	for _, aro in { { 0, 0, 5, 0.8 }, { 4, -3, 2, 0.88 } } do
		local taza = Instance.new("Frame")
		taza.Name = "Taza"
		taza.AnchorPoint = Vector2.new(0.5, 0.5)
		taza.Position = UDim2.new(1, -96 + aro[1], 1, -30 + aro[2])
		taza.Size = UDim2.fromOffset(128, 128)
		taza.BackgroundTransparency = 1
		taza.ZIndex = 1
		redondo(taza)
		local borde = Instance.new("UIStroke")
		borde.Color = CAFE
		borde.Thickness = aro[3]
		borde.Transparency = aro[4]
		borde.Parent = taza
		taza.Parent = padre
	end
end

local function construir()
	-- Todo en un CanvasGroup: el fundido y el giro de abrir y cerrar valen para todo a la vez.
	panel = Instance.new("CanvasGroup")
	panel.Name = "Tienda"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = posicion
	panel.Size = UDim2.fromOffset(ANCHO, ALTO)
	panel.BackgroundTransparency = 1
	panel.GroupTransparency = 1
	panel.Visible = false
	panel.ZIndex = 20

	-- El papel es un botón: se queda los toques (no mueven la cámara) y, con Modal, suelta el ratón en primera persona.
	-- Dos píxeles más bajo y más corto que el grupo para que se vea su borde arriba y abajo.
	hoja = Instance.new("TextButton")
	hoja.Name = "Papel"
	hoja.Text = ""
	hoja.AutoButtonColor = false
	hoja.Selectable = false
	hoja.Position = UDim2.fromOffset(ESPIRAL, 2)
	hoja.Size = UDim2.new(1, -(ESPIRAL + SALE), 1, -4)
	hoja.BackgroundColor3 = Ui.Color.Papel
	hoja.BackgroundTransparency = 0.04
	hoja.BorderSizePixel = 0
	hoja.ClipsDescendants = true
	hoja.ZIndex = 2
	local viejo = Instance.new("UIGradient") -- papel viejo: más oscuro abajo
	viejo.Rotation = 90
	viejo.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(238, 234, 228)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(196, 190, 182)),
	})
	viejo.Parent = hoja
	local borde = Instance.new("UIStroke")
	borde.Color = Ui.Color.Hueso
	borde.Transparency = 0.75
	borde.Parent = hoja
	Ui.mancha(hoja).ZIndex = 1
	crearTaza(hoja)
	local margen = Instance.new("Frame")
	margen.Name = "Margen"
	margen.Position = UDim2.fromOffset(MARGEN, 0)
	margen.Size = UDim2.new(0, 2, 1, 0)
	margen.BackgroundColor3 = ROJO
	margen.BackgroundTransparency = 0.45
	margen.BorderSizePixel = 0
	margen.ZIndex = 2
	margen.Parent = hoja

	local cabeza = math.max(44, CRUZ) -- alto de lo de arriba (título, monedas y X)
	Ui.texto(texto("Shop"), {
		Name = "Titulo",
		Position = UDim2.fromOffset(MARGEN + 14, 14),
		Size = UDim2.fromOffset(TITULO_ANCHO, cabeza),
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	}).Parent = hoja
	-- Las monedas, de 10 a la derecha del título hasta la X (sin pisarse con la hoja estrecha del móvil; si no caben,
	-- encogen).
	monedas = Ui.texto("", {
		Name = "Monedas",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -(14 + CRUZ_ANCHO + 12), 0, 14 + cabeza / 2),
		Size = UDim2.new(1, -(MARGEN + 14 + TITULO_ANCHO + 10) - (14 + CRUZ_ANCHO + 12), 0, 40),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
	})
	Ui.queQuepa(monedas, 24)
	escalaMonedas = Instance.new("UIScale")
	escalaMonedas.Parent = monedas
	monedas.Parent = hoja
	local x = Ui.boton("X", {
		Name = "Cerrar",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -14 - CRUZ_ANCHO / 2, 0, 14 + cabeza / 2),
		Size = UDim2.fromOffset(CRUZ_ANCHO, CRUZ),
		TextSize = 24,
		ZIndex = 3,
	})
	x.Activated:Connect(cerrar)
	x.Parent = hoja
	-- Raya bajo la cabecera, como la de arriba de una hoja de libreta.
	local raya = Instance.new("Frame")
	raya.Name = "Raya"
	raya.Position = UDim2.fromOffset(18, CABEZA)
	raya.Size = UDim2.new(1, -34, 0, 2)
	raya.BackgroundColor3 = ROJO
	raya.BackgroundTransparency = 0.3
	raya.BorderSizePixel = 0
	raya.ZIndex = 2
	raya.Parent = hoja

	lista = Instance.new("ScrollingFrame")
	lista.Name = "Lista"
	lista.Position = UDim2.fromOffset(MARGEN + 10, CABEZA + 10)
	lista.Size = UDim2.new(1, -(MARGEN + 10 + 16), 1, -(CABEZA + 10) - 12)
	lista.BackgroundTransparency = 1
	lista.BorderSizePixel = 0
	lista.ScrollBarThickness = if TACTIL then 8 else 6
	lista.ScrollBarImageColor3 = Ui.Color.Sangre
	lista.ScrollingDirection = Enum.ScrollingDirection.Y
	lista.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar -- la barra no pisa los botones
	lista.AutomaticCanvasSize = Enum.AutomaticSize.Y
	lista.CanvasSize = UDim2.new()
	lista.ZIndex = 3
	local orden = Instance.new("UIListLayout")
	orden.Padding = UDim.new(0, 6)
	orden.SortOrder = Enum.SortOrder.LayoutOrder
	orden.Parent = lista
	local relleno = Instance.new("UIPadding") -- (con 6 clases, la lista justa en una pantalla de 1280 × 720)
	relleno.PaddingTop = UDim.new(0, 2)
	relleno.PaddingBottom = UDim.new(0, 2)
	relleno.Parent = lista
	lista.Parent = hoja

	-- La hoja que pasa al cambiar de separador, encima de la lista.
	local zona = Instance.new("Frame")
	zona.Name = "Pasar"
	zona.Position = lista.Position
	zona.Size = lista.Size
	zona.BackgroundTransparency = 1
	zona.ZIndex = 6
	pasar = Instance.new("Frame")
	pasar.Name = "Hoja"
	pasar.BackgroundColor3 = HOJA
	pasar.BorderSizePixel = 0
	pasar.Visible = false
	pasar.ZIndex = 6
	local filo = Instance.new("UIStroke")
	filo.Color = Ui.Color.Hueso
	filo.Transparency = 0.6
	filo.Parent = pasar
	pasar.Parent = zona
	zona.Parent = hoja
	hoja.Parent = panel

	-- Los separadores, hermanos del papel para poder ir por encima o por debajo de él.
	for _, p in PESTANAS do
		local b = Ui.boton(Lang.t(nil, p[2]), {
			Name = p[1],
			AnchorPoint = Vector2.new(0, 0.5),
			Size = UDim2.fromOffset(SALE + METE, PESTANA),
			TextSize = if TACTIL then 22 else 20,
		})
		local r = Instance.new("UIPadding")
		r.PaddingLeft = UDim.new(0, METE)
		r.Parent = b
		rellenos[p[1]] = r
		b.Activated:Connect(function()
			cambiarPestana(p[1])
		end)
		b.Parent = panel
		pestanas[p[1]] = b
	end
	for i = 1, ANILLAS do
		local anilla = crearAnilla()
		anilla.Parent = panel
		anillas[i] = anilla
	end
	colocar()
	pintarPestanas(false)
	panel.Parent = Ui.hud()
end

function TiendaUi.start()
	construir()
	Sonido.precargar({ "Papel" })
	local atributos = { "Clases", "Cosmeticos", "Clase", "PuestoLinterna" }
	for _, pase in Config.Compras.Pases do
		table.insert(atributos, `Pase{pase.Ventaja}`)
	end
	for _, atributo in atributos do
		jugador:GetAttributeChangedSignal(atributo):Connect(function()
			if abierta then
				pintar()
			end
		end)
	end
	jugador:GetAttributeChangedSignal("Monedas"):Connect(alCambiarMonedas)
	-- Si cambia la pantalla con la tienda abierta (girar el móvil, la ventana), se vuelve a medir. Un momento después:
	-- la escala del HUD (Ui) se recalcula con la misma señal.
	Ui.hud():GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		task.defer(function()
			if abierta then
				colocar()
				panel.Position = posicion
			end
		end)
	end)
	task.spawn(function()
		local m = workspace:WaitForChild("Mapa"):WaitForChild("Mostrador") :: BasePart
		mostrador = m
		prompt = m:WaitForChild("Tienda") :: ProximityPrompt
		;(prompt :: ProximityPrompt).Triggered:Connect(abrir)
	end)
end

return TiendaUi
