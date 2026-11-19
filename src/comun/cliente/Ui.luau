-- Estilo de la interfaz (pedido por el usuario): oscura y minimalista, casi nada en pantalla, letras blancas
-- desgastadas sobre papel viejo, algo de rojo oscuro. Todo pasa por aquí para que se vea igual.
-- Todo el HUD cuelga de una sola capa (Ui.hud) con un UIScale que lo encoge en pantallas pequeñas.
-- Textos de botones y títulos en mayúsculas.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Ui = {}

Ui.Color = {
	Hueso = Color3.fromRGB(226, 220, 204), -- letras
	Papel = Color3.fromRGB(24, 21, 19), -- fondos
	Sangre = Color3.fromRGB(112, 12, 12),
	Negro = Color3.new(0, 0, 0),
}
Ui.Fuente = Font.fromEnum(Enum.Font.SpecialElite) -- máquina de escribir gastada

local jugador = Players.LocalPlayer
local hud: ScreenGui? = nil
local escalaHud: UIScale? = nil

-- Móvil (docs/sistemas/movil.md): el HUD se dibuja en "píxeles de diseño" sobre una pantalla de 1280 × 720 y el UIScale
-- del ScreenGui lo encoge; las posiciones en escala siguen siendo de la pantalla de verdad. En un teléfono de 640 × 360
-- la escala es 0,55: el lienzo mide unos 1164 × 655 píxeles de diseño y un botón de Ui.DEDO (80) mide 44 de verdad,
-- lo mínimo para acertar con el dedo.
Ui.DEDO = 80

local function escalar(gui: ScreenGui, escala: UIScale)
	local tamano = gui.AbsoluteSize
	if tamano.X > 0 then
		escala.Scale = math.clamp(math.min(tamano.X / 1280, tamano.Y / 720), 0.55, 1.3)
	end
end

-- Tipo de entrada que se está usando ahora: "tactil", "mando" o "teclado" (teclado y ratón). Sale de LastInputTypeChanged;
-- lo que no cuenta (Focus, sensores, None) no lo cambia. Al empezar, de lo que tenga el aparato.
local function tipoDe(entrada: Enum.UserInputType): string?
	if entrada == Enum.UserInputType.Touch then
		return "tactil"
	elseif entrada == Enum.UserInputType.Keyboard or entrada == Enum.UserInputType.MouseMovement
		or entrada == Enum.UserInputType.MouseWheel or string.sub(entrada.Name, 1, 11) == "MouseButton" then
		return "teclado"
	elseif string.sub(entrada.Name, 1, 7) == "Gamepad" then
		return "mando"
	end
	return nil
end

local function tipoInicial(): string
	local t = tipoDe(UserInputService:GetLastInputType())
	if t then
		return t
	elseif UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "tactil"
	elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled and not UserInputService.MouseEnabled then
		return "mando"
	end
	return "teclado"
end

local tipoActual = tipoInicial()
local cambioEntrada = Instance.new("BindableEvent") -- sin colgar de nada: solo para avisar a quien lo pida

function Ui.tipoEntrada(): string
	return tipoActual
end

-- Pantalla táctil (el móvil): botones grandes y otro reparto de lo de abajo. TouchEnabled solo no vale: los portátiles con
-- pantalla táctil también lo tienen. Sin teclado es táctil; con teclado y pantalla (portátil, tablet con teclado), lo es
-- mientras lo último que se ha usado sea el dedo. Las medidas que se fijan al arrancar no cambian; esto sí lo hace.
function Ui.tactil(): boolean
	if not UserInputService.TouchEnabled then
		return false
	elseif not UserInputService.KeyboardEnabled then
		return true
	end
	return tipoActual == "tactil"
end

-- Pistas de teclado ([R], [Q]…): solo se enseñan con teclado. Con mando o con el dedo, la letra no existe.
function Ui.conTeclado(): boolean
	return UserInputService.KeyboardEnabled and tipoActual == "teclado"
end

-- Texto con su pista de teclado delante: "[R]  texto". Sin teclado, el texto solo (no se enseñan letras de botones del
-- mando: en cada mando se llaman distinto, y Roblox ya pone el suyo en los carteles de coger).
function Ui.pista(tecla: string, texto: string): string
	return if Ui.conTeclado() then "[" .. tecla .. "]  " .. texto else texto
end

-- Llama a `funcion` cuando cambia el tipo de entrada (teclado, mando, táctil): para repintar las pistas.
function Ui.alCambiarEntrada(funcion: () -> ()): RBXScriptConnection
	return cambioEntrada.Event:Connect(funcion)
end

UserInputService.LastInputTypeChanged:Connect(function(entrada)
	local nuevo = tipoDe(entrada)
	if nuevo and nuevo ~= tipoActual then
		tipoActual = nuevo
		cambioEntrada:Fire()
	end
end)

-- Ventanas abiertas (solo en este cliente): mientras haya una, el atributo VentanaAbierta del jugador vale true y B no
-- agacha (PosturaVista lo mira). Al cerrar se quita en diferido: la misma B que cierra la ventana llega a PosturaVista
-- en esa pulsación y debe seguir viéndola abierta.
local ventanasAbiertas: { [string]: boolean } = {}
local function publicarVentanas()
	jugador:SetAttribute("VentanaAbierta", if next(ventanasAbiertas) ~= nil then true else nil)
end

function Ui.ventanaAbierta(nombre: string, abierta: boolean)
	if abierta then
		ventanasAbiertas[nombre] = true
		publicarVentanas()
	else
		ventanasAbiertas[nombre] = nil
		task.defer(publicarVentanas)
	end
end

-- Cierra una ventana con B del mando (y con Escape si `conEscape`). `estaAbierta` y `cerrar` son de la ventana, que
-- además llama a Ui.ventanaAbierta(nombre, ...) al abrirse y al cerrarse para que esa B no agache. B se atiende aunque
-- Roblox la dé por usada (la usa para salir de la selección del mando), como en Ajustes.
function Ui.cerrarConB(estaAbierta: () -> boolean, cerrar: () -> (), conEscape: boolean?)
	UserInputService.InputBegan:Connect(function(entrada)
		local tecla = entrada.KeyCode
		if (tecla == Enum.KeyCode.ButtonB or (conEscape and tecla == Enum.KeyCode.Escape)) and estaAbierta() then
			cerrar()
		end
	end)
end

-- Selección del mando (docs/sistemas/movil.md): con mando, la A solo pulsa el botón elegido (GuiService.SelectedObject).
-- Cada ventana elige el suyo al abrirse (Ui.seleccionar) y lo suelta al cerrarse (Ui.soltarSeleccion); el borde claro
-- que lo marca es el de Ui.hud. El panel de fondo de cada ventana va con Selectable = false: si no, el mando lo elige.
local function aLaVista(objeto: GuiObject): boolean
	local actual: Instance? = objeto
	while actual and actual:IsA("GuiObject") do
		if not (actual :: GuiObject).Visible then
			return false
		end
		actual = actual.Parent
	end
	-- Arriba del todo, su ScreenGui encendido y colgado del PlayerGui.
	return actual ~= nil and actual:IsA("LayerCollector") and (actual :: LayerCollector).Enabled
		and objeto:IsDescendantOf(jugador)
end

local function elegible(boton: GuiObject?): boolean
	return boton ~= nil and boton.Selectable and boton.Interactable and aLaVista(boton)
end

-- Elige `boton` para el mando, solo si se está jugando con mando (o `siempre`, como el R3 de Ajustes) y se puede elegir.
function Ui.seleccionar(boton: GuiObject?, siempre: boolean?)
	if (siempre or tipoActual == "mando") and elegible(boton) then
		GuiService.SelectedObject = boton
	end
end

-- Quita la selección si es de `panel` (al cerrar una ventana, también al empezar su fundido): que no se quede marcado
-- un botón escondido ni la A pulse algo que ya no se ve.
function Ui.soltarSeleccion(panel: Instance)
	local elegido = GuiService.SelectedObject
	if elegido and (elegido == panel or elegido:IsDescendantOf(panel)) then
		GuiService.SelectedObject = nil
	end
end

-- Con `panel` abierto y mando: si no hay nada elegido, o lo elegido se ha escondido (la fila de la tienda ya
-- comprada, la receta que se oculta), elige `principal()`. Para después de repintar una ventana. Lo elegido que se ve
-- se respeta aunque sea de otra (Ajustes abierto encima con R3) o se haya apagado (Interactable = false, como EMPEZAR
-- en la cuenta atrás): no se lo quita, porque saltar a otro botón haría que la siguiente A pulsara algo sin querer.
function Ui.mantenerSeleccion(panel: GuiObject, principal: () -> GuiObject?)
	local elegido = GuiService.SelectedObject
	if tipoActual ~= "mando" or not aLaVista(panel)
		or (elegido and elegido:IsA("GuiObject") and elegido.Selectable and aLaVista(elegido)) then
		return
	end
	Ui.seleccionar(principal())
end

-- Al pasar al mando con la ventana abierta, elige `principal()`; al dejarlo (ratón, dedo), suelta lo de `panel`.
function Ui.seleccionConMando(panel: GuiObject, estaAbierta: () -> boolean, principal: () -> GuiObject?)
	Ui.alCambiarEntrada(function()
		if not estaAbierta() then
			return
		elseif tipoActual == "mando" then
			Ui.mantenerSeleccion(panel, principal)
		else
			Ui.soltarSeleccion(panel)
		end
	end)
end

-- Alto de un botón: el normal, o el de un dedo en pantallas táctiles.
function Ui.alto(normal: number): number
	return if Ui.tactil() then math.max(normal, Ui.DEDO) else normal
end

-- La escala del HUD ahora mismo (para lo que no cuelga de él, como los carteles del mundo).
function Ui.escala(): number
	Ui.hud()
	return if escalaHud then escalaHud.Scale else 1
end

-- Lo que mide la pantalla en píxeles de diseño (lo que cabe dentro del HUD).
function Ui.lienzo(): Vector2
	local gui = Ui.hud()
	return gui.AbsoluteSize / Ui.escala()
end

-- Lo que tapa abajo el teléfono (la barra de inicio de algunos, la muesca de lado no cuenta), en píxeles de diseño;
-- 0 si nada. Se mide con un ScreenGui vacío con ScreenInsets = DeviceSafeInsets frente al Hud (que lo ignora todo): la
-- diferencia entre sus bordes de abajo. Lo usan la rejilla de botones del móvil (EquipoVista) y la barra del aguante.
local seguro: ScreenGui? = nil
function Ui.zonaSegura(): number
	local gui = Ui.hud()
	if not seguro then
		pcall(function()
			local s = Instance.new("ScreenGui")
			s.Name = "ZonaSegura"
			s.ResetOnSpawn = false
			s.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
			s.Parent = jugador:WaitForChild("PlayerGui")
			seguro = s
		end)
	end
	local s = seguro
	if not s then
		return 0
	end
	local abajo = (gui.AbsolutePosition.Y + gui.AbsoluteSize.Y) - (s.AbsolutePosition.Y + s.AbsoluteSize.Y)
	return if abajo == abajo and abajo > 0 then math.min(abajo / Ui.escala(), 80) else 0
end

-- Texto que encoge para caber en su caja (palabras largas en otros idiomas), hasta `maximo`.
function Ui.queQuepa(objeto: TextLabel | TextButton, maximo: number)
	objeto.TextScaled = true
	objeto.TextWrapped = true
	local limite = Instance.new("UITextSizeConstraint")
	limite.MaxTextSize = maximo
	limite.MinTextSize = math.min(maximo, 12)
	limite.Parent = objeto
	local relleno = Instance.new("UIPadding")
	relleno.PaddingLeft, relleno.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	relleno.Parent = objeto
end

-- La capa del HUD (se crea la primera vez).
function Ui.hud(): ScreenGui
	if hud then
		return hud
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local escala = Instance.new("UIScale")
	escala.Parent = gui
	escalaHud = escala
	hud = gui -- antes de esperar: si otro lo pide mientras tanto, es la misma capa
	local playerGui = jugador:WaitForChild("PlayerGui") :: PlayerGui
	gui.Parent = playerGui
	-- El borde del botón que lleva elegido el mando, con el estilo del juego (el de Roblox es un azul chillón): un marco
	-- vacío con un trazo color hueso de 3 px y las esquinas del botón. Vale para todas las ventanas de este jugador.
	local marca = Instance.new("Frame")
	marca.Name = "SeleccionMando"
	marca.BackgroundTransparency = 1
	marca.BorderSizePixel = 0
	local trazo = Instance.new("UIStroke")
	trazo.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	trazo.Color = Ui.Color.Hueso
	trazo.Thickness = 3
	trazo.Parent = marca
	local redondo = Instance.new("UICorner")
	redondo.CornerRadius = UDim.new(0, 4)
	redondo.Parent = marca
	playerGui.SelectionImageObject = marca
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		escalar(gui, escala)
	end)
	escalar(gui, escala)
	return gui
end

-- Mayúsculas que entienden las letras latinas con tilde (string.upper deja "á" en minúscula): las del español y las de
-- otros idiomas que traduce Roblox (francés, portugués, alemán, italiano).
local TILDES = {
	["á"] = "Á", ["é"] = "É", ["í"] = "Í", ["ó"] = "Ó", ["ú"] = "Ú", ["ñ"] = "Ñ", ["ü"] = "Ü",
	["à"] = "À", ["è"] = "È", ["ì"] = "Ì", ["ò"] = "Ò", ["ù"] = "Ù",
	["â"] = "Â", ["ê"] = "Ê", ["î"] = "Î", ["ô"] = "Ô", ["û"] = "Û",
	["ã"] = "Ã", ["õ"] = "Õ", ["ç"] = "Ç", ["ö"] = "Ö", ["ä"] = "Ä",
}
function Ui.mayusculas(texto: string): string
	return (string.gsub(string.upper(texto), "\195[\160-\191]", TILDES))
end

-- Texto con la letra del juego. `props` sobrescribe lo que haga falta.
function Ui.texto(texto: string, props: { [string]: any }?): TextLabel
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.FontFace = Ui.Fuente
	t.Text = texto
	t.TextColor3 = Ui.Color.Hueso
	t.TextStrokeColor3 = Ui.Color.Negro
	t.TextStrokeTransparency = 0.4
	t.TextSize = 24
	for clave, valor in props or {} do
		(t :: any)[clave] = valor
	end
	return t
end

-- Botón de papel oscuro con borde rojo oscuro; se hunde al pulsar. El texto va en mayúsculas.
function Ui.boton(texto: string, props: { [string]: any }?): TextButton
	local b = Instance.new("TextButton")
	b.AutoButtonColor = false
	b.Selectable = true -- el mando lo puede elegir (Ui.seleccionar); el de Roblox ya lo es, aquí se dice
	b.BackgroundColor3 = Ui.Color.Papel
	b.BackgroundTransparency = 0.15
	b.FontFace = Ui.Fuente
	b.Text = Ui.mayusculas(texto)
	b.TextColor3 = Ui.Color.Hueso
	b.TextSize = 26
	local borde = Instance.new("UIStroke")
	borde.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	borde.Color = Ui.Color.Sangre
	borde.Thickness = 2
	borde.Parent = b
	local esquina = Instance.new("UICorner")
	esquina.CornerRadius = UDim.new(0, 4)
	esquina.Parent = b
	local escala = Instance.new("UIScale")
	escala.Parent = b
	b.MouseButton1Down:Connect(function()
		TweenService:Create(escala, TweenInfo.new(0.06), { Scale = 0.94 }):Play()
	end)
	local function soltar()
		TweenService:Create(escala, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	b.MouseButton1Up:Connect(soltar)
	b.MouseLeave:Connect(soltar)
	for clave, valor in props or {} do
		(b :: any)[clave] = valor
	end
	return b
end

-- Una esquina de arriba a la izquierda manchada de sangre, para los paneles.
function Ui.mancha(padre: GuiObject): Frame
	local mancha = Instance.new("Frame")
	mancha.Name = "Mancha"
	mancha.Size = UDim2.fromOffset(190, 150)
	mancha.BackgroundColor3 = Ui.Color.Sangre
	mancha.BorderSizePixel = 0
	local gradiente = Instance.new("UIGradient")
	gradiente.Rotation = 40
	gradiente.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.35, 0.75), NumberSequenceKeypoint.new(0.6, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradiente.Parent = mancha
	mancha.Parent = padre
	return mancha
end

-- Avisos de una sola línea abajo en el centro que se van solos (docs/sistemas/movil.md). Nunca hay más de uno en
-- pantalla y no se pisan: al amanecer llegan a la vez el del amanecer y el del premio y antes uno borraba al otro.
--   misma frase que la que se ve: solo se alarga su tiempo (pulsar E en una puerta cerrada no la hace parpadear);
--   otra distinta: espera en una cola corta a que la de ahora lleve MINIMO_AVISO a la vista y entonces la de ahora se
--   funde en 0,2 s y sale la siguiente; la que pide sus segundos (morir: 5) se ve entera antes de dejar paso.
local MINIMO_AVISO = 1.4 -- s que se ve un aviso antes de dejar paso al siguiente (a ojo)
local DURACION_AVISO = 3.5 -- s que se ve si nadie dice otra cosa
local COLA_AVISOS = 3 -- avisos esperando como mucho; si llega otro, se olvida el más viejo
type Aviso = {
	texto: string,
	desde: number, -- cuándo salió
	hasta: number, -- cuándo empieza a irse si no hay nadie esperando
	minimo: number, -- lo que se ve como poco aunque haya cola
	saliendo: boolean,
	revivir: boolean, -- se repitió mientras se fundía: vuelve a verse
}
local avisoActual: Aviso? = nil
type Colocar = (TextLabel) -> ()
local colaAvisos: { { texto: string, segundos: number?, colocar: Colocar? } } = {}
local VISIBLE = { TextTransparency = 0, TextStrokeTransparency = 0.4 }
local OCULTO = { TextTransparency = 1, TextStrokeTransparency = 1 }

local mostrarAviso: (texto: string, segundos: number?, entrada: number, colocar: Colocar?) -> ()

local function siguienteAviso()
	if avisoActual == nil and #colaAvisos > 0 then
		local s = table.remove(colaAvisos, 1)
		mostrarAviso(s.texto, s.segundos, 0.25, s.colocar) -- encadenado: entra algo más rápido
	end
end

function mostrarAviso(texto: string, segundos: number?, entrada: number, colocar: Colocar?)
	local tactil = Ui.tactil()
	local t = Ui.texto(texto, {
		Name = "Aviso",
		AnchorPoint = Vector2.new(0.5, 1),
		-- Encima del botón SALIR del escondite; en el móvil, más arriba aún: abajo están los botones del equipo.
		Position = UDim2.fromScale(0.5, if tactil then 0.64 else 0.76),
		-- En el móvil acaba antes del 78 % del ancho, donde empiezan los botones de acción (Hud.Acciones, que a esa altura
		-- tienen el de abajo): una frase larga (64 letras a 640 × 360) baja a dos renglones en vez de pisarlos.
		Size = UDim2.fromScale(if tactil then 0.56 else 0.8, if tactil then 0.1 else 0.05),
		TextSize = 26,
		TextYAlignment = Enum.TextYAlignment.Bottom, -- la frase corta queda abajo, donde siempre
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		ZIndex = 50,
	})
	Ui.queQuepa(t, 26) -- y si aun así no cabe (otros idiomas), la letra encoge
	t.Parent = Ui.hud()
	if colocar then
		colocar(t) -- quien lo pidió lo mueve si tapa algo suyo (PistasUi: el papel)
	end
	local ahora = os.clock()
	local a: Aviso = {
		texto = texto,
		desde = ahora,
		hasta = ahora + (segundos or DURACION_AVISO),
		minimo = math.max(MINIMO_AVISO, segundos or 0),
		saliendo = false,
		revivir = false,
	}
	avisoActual = a
	TweenService:Create(t, TweenInfo.new(entrada), VISIBLE):Play()
	task.spawn(function()
		while true do
			-- A la vista hasta su hora, o hasta cumplir el mínimo si alguien espera.
			while t.Parent do
				local reloj = os.clock()
				if reloj >= a.hasta or (#colaAvisos > 0 and reloj >= a.desde + a.minimo) then
					break
				end
				task.wait(0.05)
			end
			-- Se funde: en 1 s si se va sola, en 0,2 s si hay otra esperando (también si llega mientras se funde).
			a.saliendo = true
			local rapido = #colaAvisos > 0
			local fuera = TweenService:Create(t, TweenInfo.new(if rapido then 0.2 else 1), OCULTO)
			fuera:Play()
			local fin = os.clock() + (if rapido then 0.2 else 1)
			while t.Parent and os.clock() < fin and not a.revivir do
				task.wait(0.03)
				if not rapido and #colaAvisos > 0 then
					rapido = true
					fuera:Cancel()
					fuera = TweenService:Create(t, TweenInfo.new(0.2), OCULTO)
					fuera:Play()
					fin = math.min(fin, os.clock() + 0.2)
				end
			end
			a.saliendo = false
			if not (a.revivir and t.Parent) then
				break
			end
			-- Se repitió la frase mientras se iba: vuelve a verse entera y sigue contando.
			a.revivir = false
			fuera:Cancel()
			TweenService:Create(t, TweenInfo.new(0.15), VISIBLE):Play()
		end
		t:Destroy()
		if avisoActual == a then
			avisoActual = nil
		end
		siguienteAviso()
	end)
end

-- `colocar` (opcional) recibe el texto al salir, también si sale después desde la cola (PistasUi lo sube si tapa el papel).
function Ui.aviso(texto: string, segundos: number?, colocar: Colocar?)
	local a = avisoActual
	if a and a.texto == texto then
		-- La misma frase: no se rehace, solo dura más (y si se estaba yendo sin nadie detrás, vuelve).
		a.hasta = math.max(a.hasta, os.clock() + (segundos or DURACION_AVISO))
		if a.saliendo and #colaAvisos == 0 then
			a.revivir = true
		end
		return
	end
	for _, s in colaAvisos do
		if s.texto == texto then
			-- Ya espera: no se repite, pero se queda con los segundos más largos que se pidan.
			if segundos and segundos > (s.segundos or DURACION_AVISO) then
				s.segundos = segundos
			end
			return
		end
	end
	if a == nil then
		mostrarAviso(texto, segundos, 0.4, colocar)
		return
	end
	if #colaAvisos >= COLA_AVISOS then
		table.remove(colaAvisos, 1)
	end
	table.insert(colaAvisos, { texto = texto, segundos = segundos, colocar = colocar })
end

return Ui
