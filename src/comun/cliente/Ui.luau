-- Estilo de la interfaz (pedido por el usuario): oscura y minimalista, casi nada en pantalla, letras blancas
-- desgastadas sobre papel viejo, algo de rojo oscuro. Todo pasa por aquí para que se vea igual.
-- Todo el HUD cuelga de una sola capa (Ui.hud) con un UIScale que lo encoge en pantallas pequeñas.
-- Textos de botones y títulos en mayúsculas.
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

-- Pantalla táctil (el móvil): botones grandes y otro reparto de lo de abajo.
function Ui.tactil(): boolean
	return UserInputService.TouchEnabled
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
	gui.Parent = jugador:WaitForChild("PlayerGui")
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		escalar(gui, escala)
	end)
	escalar(gui, escala)
	return gui
end

-- Mayúsculas que entienden las tildes (string.upper deja "á" en minúscula).
local TILDES = { ["á"] = "Á", ["é"] = "É", ["í"] = "Í", ["ó"] = "Ó", ["ú"] = "Ú", ["ñ"] = "Ñ", ["ü"] = "Ü" }
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
local colaAvisos: { { texto: string, segundos: number? } } = {}
local VISIBLE = { TextTransparency = 0, TextStrokeTransparency = 0.4 }
local OCULTO = { TextTransparency = 1, TextStrokeTransparency = 1 }

local mostrarAviso: (texto: string, segundos: number?, entrada: number) -> ()

local function siguienteAviso()
	if avisoActual == nil and #colaAvisos > 0 then
		local s = table.remove(colaAvisos, 1)
		mostrarAviso(s.texto, s.segundos, 0.25) -- encadenado: entra algo más rápido
	end
end

function mostrarAviso(texto: string, segundos: number?, entrada: number)
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

function Ui.aviso(texto: string, segundos: number?)
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
		mostrarAviso(texto, segundos, 0.4)
		return
	end
	if #colaAvisos >= COLA_AVISOS then
		table.remove(colaAvisos, 1)
	end
	table.insert(colaAvisos, { texto = texto, segundos = segundos })
end

return Ui
