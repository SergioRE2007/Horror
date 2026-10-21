-- Estilo de la interfaz (pedido por el usuario): oscura y minimalista, casi nada en pantalla, letras blancas
-- desgastadas sobre papel viejo, algo de rojo oscuro. Todo pasa por aquí para que se vea igual.
-- Todo el HUD cuelga de una sola capa (Ui.hud) con un UIScale que lo encoge en pantallas pequeñas.
-- Textos de botones y títulos en mayúsculas.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

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

local function escalar(gui: ScreenGui, escala: UIScale)
	local tamano = gui.AbsoluteSize
	if tamano.X > 0 then
		escala.Scale = math.clamp(math.min(tamano.X / 1280, tamano.Y / 720), 0.55, 1.3)
	end
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
	gui.Parent = jugador:WaitForChild("PlayerGui")
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		escalar(gui, escala)
	end)
	escalar(gui, escala)
	hud = gui
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

-- Aviso de una sola línea abajo en el centro que se va solo.
local avisoActual: TextLabel? = nil
function Ui.aviso(texto: string, segundos: number?)
	if avisoActual then
		avisoActual:Destroy()
	end
	local t = Ui.texto(texto, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.76), -- encima del botón SALIR del escondite
		Size = UDim2.fromScale(0.8, 0.05),
		TextSize = 26,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		ZIndex = 50,
	})
	t.Parent = Ui.hud()
	avisoActual = t
	TweenService:Create(t, TweenInfo.new(0.4), { TextTransparency = 0, TextStrokeTransparency = 0.4 }):Play()
	task.delay(segundos or 3.5, function()
		if t.Parent then
			local fuera = TweenService:Create(t, TweenInfo.new(1), { TextTransparency = 1, TextStrokeTransparency = 1 })
			fuera:Play()
			fuera.Completed:Wait()
			t:Destroy()
		end
	end)
end

return Ui
