-- Mochila de casillas en el cliente (lo manda el servidor: juego/servidor/Mochila). Se abre con la B, el botón
-- MOCHILA en el móvil o la cruceta arriba en el mando. Al abrir, la mochila sube delante de la cámara, la vista baja
-- hacia ella y sale la rejilla encima; no te mueves, pero el mundo sigue.
--   Clic o toque en una cosa: la coges (va con el ratón). En una casilla: la dejas ahí si cabe. R o GIRAR la gira;
--   G o TIRAR la tira al suelo delante de ti. B, CERRAR o tocar fuera la cierra (lo cogido vuelve a su sitio).
-- Lo que se pide se adelanta aquí con la misma Rejilla y luego manda lo que publica el servidor (atributo Mochila).
-- A los demás se les ve la mochila a la espalda; abierta, la llevan delante.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Rejilla = require(ReplicatedStorage.Shared.Rejilla)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))

local MochilaUi = {}

local CAT = Config.Objetos
local CASILLA = 58 -- píxeles de una casilla (el HUD entero se escala)
local jugador = Players.LocalPlayer
local camara = workspace.CurrentCamera

local r: Rejilla.Rejilla? = nil
type Cogida = { id: number, girada: boolean, dx: number, dy: number }
local cogida: Cogida? = nil
local encima: { number }? = nil -- casilla bajo el ratón (o la última tocada)
local abierta = false

local raiz: Frame
local fondo: TextButton
local panel: CanvasGroup
local rejillaGui: Frame
local capaCosas: Frame
local fantasma: Frame
local celdas: { Frame } = {}
local medidas = { 0, 0 }

-- Lo de la vista: mochila de bloques delante de la cámara, vista que baja y un poco de desenfoque.
local apertura = Instance.new("NumberValue") -- 0 cerrada .. 1 abierta
local prop: Model
local tapa: BasePart
local desenfoque: BlurEffect
local campoNormal = 70

local function textoCosa(tipo: string): string
	return Ui.mayusculas(Lang.t(nil, CAT[tipo].Nombre))
end

-- Una cosa pintada en la rejilla: bloque oscuro con su nombre.
local function cuadro(tipo: string, girada: boolean, x: number, y: number): Frame
	local w, h = Rejilla.tamano(CAT, tipo, girada)
	local f = Instance.new("Frame")
	f.Position = UDim2.fromOffset((x - 1) * CASILLA + 3, (y - 1) * CASILLA + 3)
	f.Size = UDim2.fromOffset(w * CASILLA - 6, h * CASILLA - 6)
	f.BackgroundColor3 = Color3.fromRGB(62, 57, 52)
	f.BorderSizePixel = 0
	local borde = Instance.new("UIStroke")
	borde.Color = Ui.Color.Hueso
	borde.Transparency = 0.6
	borde.Thickness = 1.5
	borde.Parent = f
	local degradado = Instance.new("UIGradient")
	degradado.Rotation = 90
	degradado.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150))
	degradado.Parent = f
	-- Lo alto y estrecho, con el nombre de lado; lo de una casilla, con la letra que quepa.
	local deLado = h > w
	local largo, corto = (if deLado then h else w) * CASILLA - 12, (if deLado then w else h) * CASILLA - 12
	local nombre = Ui.texto(textoCosa(tipo), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(largo, math.min(corto, 24)),
		Rotation = if deLado then -90 else 0,
		TextScaled = true,
	})
	local limite = Instance.new("UITextSizeConstraint")
	limite.MaxTextSize = 17
	limite.Parent = nombre
	nombre.Parent = f
	return f
end

local function pintarFantasma()
	if not r or not cogida then
		fantasma.Visible = false
		return
	end
	local c = Rejilla.buscar(r, cogida.id)
	if not c then
		fantasma.Visible = false
		return
	end
	local x, y = c.x, c.y
	if encima then
		x, y = encima[1] - cogida.dx, encima[2] - cogida.dy
	end
	local w, h = Rejilla.tamano(CAT, c.tipo, cogida.girada)
	local cabe = Rejilla.cabe(r, CAT, c.tipo, x, y, cogida.girada, c.id)
	fantasma:ClearAllChildren()
	local dentro = cuadro(c.tipo, cogida.girada, 1, 1)
	dentro.Position = UDim2.fromOffset(3, 3)
	dentro.BackgroundTransparency = 0.15
	dentro.Parent = fantasma
	local borde = dentro:FindFirstChildOfClass("UIStroke") :: UIStroke
	borde.Color = if cabe then Ui.Color.Hueso else Color3.fromRGB(170, 25, 25)
	borde.Transparency = 0
	borde.Thickness = 2.5
	fantasma.Size = UDim2.fromOffset(w * CASILLA, h * CASILLA)
	fantasma.Position = UDim2.fromOffset((x - 1) * CASILLA, (y - 1) * CASILLA)
	fantasma.Visible = true
end

-- Las casillas de fondo (se rehacen si cambia el tamaño: mochila ampliada).
local tocar: (x: number, y: number) -> ()
local function hacerCeldas(ancho: number, alto: number)
	if medidas[1] == ancho and medidas[2] == alto then
		return
	end
	medidas = { ancho, alto }
	for _, c in celdas do
		c:Destroy()
	end
	table.clear(celdas)
	rejillaGui.Size = UDim2.fromOffset(ancho * CASILLA, alto * CASILLA)
	panel.Size = UDim2.fromOffset(ancho * CASILLA + 48, alto * CASILLA + 140)
	for y = 1, alto do
		for x = 1, ancho do
			local celda = Instance.new("TextButton")
			celda.Text = ""
			celda.AutoButtonColor = false
			celda.Position = UDim2.fromOffset((x - 1) * CASILLA, (y - 1) * CASILLA)
			celda.Size = UDim2.fromOffset(CASILLA, CASILLA)
			celda.BackgroundColor3 = Color3.fromRGB(14, 12, 11)
			celda.BackgroundTransparency = 0.25
			celda.BorderSizePixel = 0
			local borde = Instance.new("UIStroke")
			borde.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			borde.Color = Ui.Color.Hueso
			borde.Transparency = 0.88
			borde.Parent = celda
			celda.MouseEnter:Connect(function()
				encima = { x, y }
				pintarFantasma()
			end)
			celda.Activated:Connect(function()
				encima = { x, y }
				tocar(x, y)
			end)
			celda.Parent = rejillaGui
			table.insert(celdas, celda)
		end
	end
end

local function pintar()
	capaCosas:ClearAllChildren()
	if not r then
		return
	end
	hacerCeldas(r.ancho, r.alto)
	for _, c in r.cosas do
		if not (cogida and cogida.id == c.id) then
			cuadro(c.tipo, c.girada, c.x, c.y).Parent = capaCosas
		end
	end
	pintarFantasma()
end

local function sacudir()
	local x = fantasma.Position.X.Offset
	for _, d in { 6, -6, 4, -3, 0 } do
		fantasma.Position = UDim2.fromOffset(x + d, fantasma.Position.Y.Offset)
		task.wait(0.03)
	end
end

function tocar(x: number, y: number)
	if not r then
		return
	end
	if cogida then
		local c = Rejilla.buscar(r, cogida.id)
		local nx, ny = x - cogida.dx, y - cogida.dy
		if c and Rejilla.mover(r, CAT, c.id, nx, ny, cogida.girada) then
			Remotes.Mochila:FireServer("Mover", c.id, nx, ny, cogida.girada)
			cogida = nil
		elseif c then
			task.spawn(sacudir)
			return
		else
			cogida = nil
		end
	else
		local c = Rejilla.en(r, CAT, x, y)
		if c then
			cogida = { id = c.id, girada = c.girada, dx = x - c.x, dy = y - c.y }
		end
	end
	pintar()
end

local function girar()
	if cogida then
		cogida.girada = not cogida.girada
		cogida.dx, cogida.dy = cogida.dy, cogida.dx
		pintarFantasma()
	end
end

local function tirar()
	if not r then
		return
	end
	local c = if cogida then Rejilla.buscar(r, cogida.id) elseif encima then Rejilla.en(r, CAT, encima[1], encima[2]) else nil
	if c then
		Rejilla.sacar(r, c.id)
		Remotes.Mochila:FireServer("Tirar", c.id)
	end
	cogida = nil
	pintar()
end

-- La mochila de bloques que sube delante de la cámara (solo la ve este jugador).
local function hacerProp()
	prop = Instance.new("Model")
	prop.Name = "MochilaVista"
	local function pieza(nombre: string, tamano: Vector3, color: Color3): Part
		local p = Instance.new("Part")
		p.Name = nombre
		p.Size = tamano
		p.Color = color
		p.Material = Enum.Material.Fabric
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Parent = prop
		return p
	end
	pieza("Cuerpo", Vector3.new(5, 3.8, 1.6), Color3.fromRGB(66, 58, 46))
	pieza("Bolsillo", Vector3.new(3.2, 1.6, 0.45), Color3.fromRGB(58, 51, 41))
	tapa = pieza("Tapa", Vector3.new(5.1, 0.3, 1.7), Color3.fromRGB(74, 65, 52))
	for _, lado in { -1, 1 } do
		pieza("Correa" .. lado, Vector3.new(0.4, 3.9, 0.15), Color3.fromRGB(40, 35, 30))
	end
end

local inclinado = 0 -- lo que se ha bajado la vista este fotograma
local function colocarProp()
	local t = apertura.Value
	if t <= 0.001 then
		inclinado = 0
		prop.Parent = nil
		return
	end
	-- La vista baja hacia la mochila (después de la cámara de Roblox; antes de la siguiente se deshace: ver start).
	inclinado = -math.rad(16) * t
	camara.CFrame *= CFrame.Angles(inclinado, 0, 0)
	local base = camara.CFrame * CFrame.new(0, -1.5 - (1 - t) * 3.5, -5) * CFrame.Angles(math.rad(-25), 0, 0)
	local cuerpo = prop:FindFirstChild("Cuerpo") :: BasePart
	cuerpo.CFrame = base
	;(prop:FindFirstChild("Bolsillo") :: BasePart).CFrame = base * CFrame.new(0, -0.8, -1)
	for _, lado in { -1, 1 } do
		(prop:FindFirstChild("Correa" .. lado) :: BasePart).CFrame = base * CFrame.new(1.4 * lado, 0, 0.85)
	end
	-- La tapa se abre hacia atrás desde el borde de arriba.
	tapa.CFrame = base * CFrame.new(0, 1.9, 0.8) * CFrame.Angles(math.rad(-100) * t, 0, 0) * CFrame.new(0, 0.15, -0.85)
	prop.Parent = camara
end

local function animar(abrirla: boolean)
	local info = TweenInfo.new(if abrirla then 0.35 else 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(apertura, info, { Value = if abrirla then 1 else 0 }):Play()
	TweenService:Create(camara, info, { FieldOfView = if abrirla then campoNormal - 12 else campoNormal }):Play()
	TweenService:Create(desenfoque, info, { Size = if abrirla then 5 else 0 }):Play()
	TweenService:Create(fondo, info, { BackgroundTransparency = if abrirla then 0.55 else 1 }):Play()
	TweenService:Create(panel, TweenInfo.new(if abrirla then 0.4 else 0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		GroupTransparency = if abrirla then 0 else 1,
		Position = UDim2.new(0.5, 0, 0.5, if abrirla then 0 else 50),
	}):Play()
end

local function cerrar(avisar: boolean)
	if not abierta then
		return
	end
	abierta = false
	cogida = nil
	encima = nil
	if avisar then
		Remotes.Mochila:FireServer("Abrir", false)
	end
	animar(false)
	fondo.Modal = false
	task.delay(0.26, function()
		if not abierta then
			raiz.Visible = false
		end
	end)
end

local function abrir()
	if abierta or jugador:GetAttribute("Muerto") or jugador:GetAttribute("Escondido") or jugador:GetAttribute("Cargando") then
		return
	end
	abierta = true
	if apertura.Value < 0.01 then
		campoNormal = camara.FieldOfView
	end
	Remotes.Mochila:FireServer("Abrir", true)
	pintar()
	raiz.Visible = true
	fondo.Modal = true -- suelta el ratón en primera persona
	animar(true)
end

local function alternar()
	if abierta then
		cerrar(true)
	else
		abrir()
	end
end

local function leer()
	local texto = jugador:GetAttribute("Mochila")
	if type(texto) ~= "string" then
		return
	end
	local ok, datos = pcall(HttpService.JSONDecode, HttpService, texto)
	if not ok or type(datos) ~= "table" then
		return
	end
	r = Rejilla.desde(datos, CAT, datos.ancho or Config.Mochila.Ancho, datos.alto or Config.Mochila.Alto)
	if cogida and not Rejilla.buscar(r :: Rejilla.Rejilla, cogida.id) then
		cogida = nil
	end
	if abierta then
		pintar()
	end
end

local function crearGui()
	raiz = Instance.new("Frame")
	raiz.Name = "Mochila"
	raiz.Size = UDim2.fromScale(1, 1)
	raiz.BackgroundTransparency = 1
	raiz.Visible = false
	raiz.ZIndex = 20
	raiz.Parent = Ui.hud()

	fondo = Instance.new("TextButton")
	fondo.Name = "Fondo"
	fondo.Text = ""
	fondo.AutoButtonColor = false
	fondo.AnchorPoint = Vector2.new(0.5, 0.5)
	fondo.Position = UDim2.fromScale(0.5, 0.5)
	fondo.Size = UDim2.fromScale(3, 3) -- de sobra aunque el HUD esté encogido
	fondo.BackgroundColor3 = Ui.Color.Negro
	fondo.BackgroundTransparency = 1
	fondo.BorderSizePixel = 0
	fondo.Activated:Connect(function()
		if not cogida then
			cerrar(true)
		end
	end)
	fondo.Parent = raiz

	panel = Instance.new("CanvasGroup")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.new(0.5, 0, 0.5, 50)
	panel.BackgroundColor3 = Ui.Color.Papel
	panel.BackgroundTransparency = 0.08
	panel.GroupTransparency = 1
	panel.Parent = raiz
	local borde = Instance.new("UIStroke")
	borde.Color = Ui.Color.Hueso
	borde.Transparency = 0.75
	borde.Parent = panel
	-- Una esquina manchada de sangre.
	local mancha = Instance.new("Frame")
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
	mancha.Parent = panel

	Ui.texto(Ui.mayusculas(Lang.t(nil, "Backpack")), {
		Position = UDim2.fromOffset(24, 14),
		Size = UDim2.new(1, -48, 0, 40),
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Left,
	}).Parent = panel

	rejillaGui = Instance.new("Frame")
	rejillaGui.Name = "Rejilla"
	rejillaGui.Position = UDim2.fromOffset(24, 62)
	rejillaGui.BackgroundTransparency = 1
	rejillaGui.Parent = panel
	capaCosas = Instance.new("Frame")
	capaCosas.Name = "Cosas"
	capaCosas.Size = UDim2.fromScale(1, 1)
	capaCosas.BackgroundTransparency = 1
	capaCosas.ZIndex = 3
	capaCosas.Parent = rejillaGui
	fantasma = Instance.new("Frame")
	fantasma.Name = "Cogida"
	fantasma.BackgroundTransparency = 1
	fantasma.ZIndex = 4
	fantasma.Visible = false
	fantasma.Parent = rejillaGui

	-- Botones de abajo. En ordenador, con su tecla.
	local fila = Instance.new("Frame")
	fila.AnchorPoint = Vector2.new(0.5, 1)
	fila.Position = UDim2.new(0.5, 0, 1, -14)
	fila.Size = UDim2.new(1, -48, 0, 50)
	fila.BackgroundTransparency = 1
	fila.Parent = panel
	local lista = Instance.new("UIListLayout")
	lista.FillDirection = Enum.FillDirection.Horizontal
	lista.HorizontalAlignment = Enum.HorizontalAlignment.Right
	lista.Padding = UDim.new(0, 10)
	lista.Parent = fila
	local teclado = UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled
	for _, b in { { "Rotate", "R", girar }, { "Throw away", "G", tirar }, { "Close", "B", function() cerrar(true) end } } do
		local texto = Ui.mayusculas(Lang.t(nil, b[1])) .. (if teclado then "  [" .. b[2] .. "]" else "")
		local boton = Ui.boton(texto, { Size = UDim2.fromOffset(0, 50), AutomaticSize = Enum.AutomaticSize.X, TextSize = 22 })
		local relleno = Instance.new("UIPadding")
		relleno.PaddingLeft, relleno.PaddingRight = UDim.new(0, 16), UDim.new(0, 16)
		relleno.Parent = boton
		boton.Activated:Connect(b[3])
		boton.Parent = fila
	end

	-- Móvil: botón MOCHILA junto a los del equipo.
	if UserInputService.TouchEnabled then
		local botones = Ui.hud():FindFirstChild("EquipoBotones")
		if botones then
			local boton = Ui.boton(Lang.t(nil, "Backpack"), { Size = UDim2.fromOffset(140, 80), TextSize = 22, LayoutOrder = -1 })
			boton.Activated:Connect(alternar)
			boton.Parent = botones
		end
	end
end

-- Los demás: la mochila del servidor (a la espalda) pasa delante mientras la tienen abierta.
local function mochilaDe(otro: Player)
	local personaje = otro.Character
	local pieza = personaje and personaje:FindFirstChild("Mochila")
	local union = pieza and pieza:FindFirstChild("Union") :: Weld?
	if not union or not union.Part0 then
		return
	end
	local fondoTorso = (union.Part0 :: BasePart).Size.Z / 2
	local destino = if otro:GetAttribute("MochilaAbierta")
		then CFrame.new(0, -0.5, -(fondoTorso + 1)) * CFrame.Angles(math.rad(-35), 0, 0)
		else CFrame.new(0, 0, fondoTorso + 0.4)
	TweenService:Create(union, TweenInfo.new(0.35, Enum.EasingStyle.Quad), { C0 = destino }):Play()
end

local function vigilar(otro: Player)
	if otro ~= jugador then
		otro:GetAttributeChangedSignal("MochilaAbierta"):Connect(function()
			mochilaDe(otro)
		end)
	end
end

function MochilaUi.start()
	crearGui()
	hacerProp()
	desenfoque = Instance.new("BlurEffect")
	desenfoque.Name = "MochilaBlur"
	desenfoque.Size = 0
	desenfoque.Parent = camara
	jugador:GetAttributeChangedSignal("Mochila"):Connect(leer)
	leer()
	-- Si el servidor la cierra (te escondes, mueres), se cierra aquí también.
	jugador:GetAttributeChangedSignal("MochilaAbierta"):Connect(function()
		if not jugador:GetAttribute("MochilaAbierta") then
			cerrar(false)
		end
	end)
	UserInputService.InputBegan:Connect(function(entrada, procesado)
		if procesado then
			return
		end
		local tecla = entrada.KeyCode
		if tecla == Enum.KeyCode.B or tecla == Enum.KeyCode.DPadUp then
			alternar()
		elseif abierta and tecla == Enum.KeyCode.R then
			girar()
		elseif abierta and tecla == Enum.KeyCode.G then
			tirar()
		elseif abierta and tecla == Enum.KeyCode.ButtonB then
			cerrar(true)
		end
	end)
	for _, otro in Players:GetPlayers() do
		vigilar(otro)
	end
	Players.PlayerAdded:Connect(vigilar)
	-- La cámara de Roblox sigue desde donde quedó la anterior: sin deshacer la inclinación, se iría sumando.
	RunService:BindToRenderStep("MochilaVistaAntes", Enum.RenderPriority.Camera.Value - 1, function()
		if inclinado ~= 0 then
			camara.CFrame *= CFrame.Angles(-inclinado, 0, 0)
			inclinado = 0
		end
	end)
	RunService:BindToRenderStep("MochilaVista", Enum.RenderPriority.Camera.Value + 1, colocarProp)
end

return MochilaUi
