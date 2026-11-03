-- Esconderse, el susto al morir y mirar a los demás.
--   Escondido (atributo Escondido del jugador = dónde va la cámara): cámara fija dentro del armario o debajo de la
--   cama con un leve respirar, latido que sube cuanto más cerca está el bicho, bordes oscuros y botón SALIR
--   (también E, espacio o B del mando). La puerta del armario o la colcha las mueve EsconditeVista.
--   Contener la respiración (pedido por el usuario: "respiración contenida al esconderte con un bicho cerca"): con
--   un bicho a menos de CONTENER studs coges aire y lo aguantas solo, sin tecla (vale igual en el móvil): suena
--   Contener, calla la respiración (Respiracion, en bucle mientras estás escondido), la cámara deja de mecerse y
--   tiembla un poco, los bordes se cierran y el latido sube. Cuando se aleja (a más de SOLTAR) o a los AGUANTE s (no
--   se aguanta más: los últimos, tiembla y se cierra más), Exhalar, temblando, y jadeas un rato. Si sales o te
--   pillan a medias, se corta todo sin sonar.
--   Debajo de un mueble (atributo Cubierto, lo pone el servidor en Postura; pedido por el usuario: "agacharte también
--   debería servir para esconderte, por ejemplo debajo de mesas"): lo mismo con un bicho cerca (coges aire y lo
--   aguantas solo, el latido, los bordes que se cierran), pero la cámara sigue siendo tuya: aquí no se mece ni tiembla.
--   Y unos bordes oscuros flojos (VINETA_CUBIERTO) que te dicen que estás escondido sin tapar la vista ni decir nada.
--   Te pillan (remote Muerte): la cámara mira a la cara del bicho, temblor, destello rojo, grito y sangre en la
--   pantalla; luego negro y a mirar a los vivos (clic o toque para cambiar, en tercera persona) hasta el amanecer.
--   A otro: un charco de sangre donde ha muerto.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local GolpeadorVista = require(script.Parent.GolpeadorVista)
local RaspadorVista = require(script.Parent.RaspadorVista)
local TrepadorVista = require(script.Parent.TrepadorVista)
local ImitadorVista = require(script.Parent.ImitadorVista)
local AcechadorVista = require(script.Parent.AcechadorVista)
local BestiaVista = require(script.Parent.BestiaVista)
local Sonido = require(script.Parent.Sonido)
local Ui = require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))

local MuerteVista = {}

-- Contener la respiración escondido. Números a ojo (para mirarlos en Studio).
local CONTENER = 18 -- studs del bicho a los que coges aire y lo aguantas
local SOLTAR = 24 -- más lejos, lo sueltas
local AGUANTE = 12 -- s que se aguanta como mucho
local APRIETA = 4 -- los últimos s del aguante: tiembla más, se cierra más y el latido corre más
local RECUPERAR = 4 -- s jadeando después de soltarlo (sin volver a contener)
local COGER_S = 0.35 -- s en que se nota del todo al coger aire
local SOLTAR_S = 0.8 -- s en que se quita al soltarlo
local TIEMBLA = 0.006 -- radianes que tiembla la cámara conteniendo, y de más al final (TIEMBLA_FIN)
local TIEMBLA_FIN = 0.012
local TIEMBLA_SUELTA = 0.028 -- el temblor al soltar el aire, que se apaga en SUELTA_S
local SUELTA_S = 0.9
local SUBE = 0.025 -- studs que sube la cámara con el aire cogido (y baja el doble al soltarlo)
local CIERRA = 0.85 -- lo oscuros que se ponen los bordes de más conteniendo (de 0 a 1)
local LATIDO_MAS = 0.3 -- volumen de más del latido conteniendo (el doble al final)
local LATIDO_PRISA = 0.12 -- tono de más del latido conteniendo (y otro tanto al final)
local VINETA_CUBIERTO = 0.55 -- lo transparentes que quedan los bordes oscuros debajo de un mueble (escondido, 0,05)

local jugador = Players.LocalPlayer
local camara = workspace.CurrentCamera
local azar = Random.new()

local capa: Frame -- bordes oscuros, sangre y negro
local bordes: ImageLabel
local rojo: Frame
local negro: Frame
local salir: TextButton
local mirando: TextLabel
local latido: Sound?
local susto = false -- durante el susto nadie más toca la cámara
local mirado = 0 -- índice del vivo al que miras de muerto

-- La respiración escondido.
local ahogoLados: ImageLabel -- bordes de más (a los lados y arriba y abajo) que se cierran conteniendo
local ahogoArriba: ImageLabel
local conteniendo = false
local cogido = 0 -- cuándo cogiste aire (os.clock)
local soltado = -math.huge -- cuándo lo soltaste
local ahogo = 0 -- de 0 a 1: cuánto se nota (cámara, bordes, latido)
local cierreVisto = 0 -- lo puesto en los bordes de más
local fase = 0 -- del vaivén de respirar (va más deprisa jadeando)
local respiracion: Sound? -- en bucle mientras estás escondido (si hay grabación)
local respiracionVolumen = 0
local voz: Sound? -- el último Contener o Exhalar, para cortarlo si sales a medias
local cubiertoDesde: number? = nil -- cuándo te metiste debajo de un mueble (os.clock), mientras lo estás

local function personajeVisible(visible: boolean)
	local personaje = jugador.Character
	if personaje then
		for _, parte in personaje:GetDescendants() do
			if parte:IsA("BasePart") or parte:IsA("Decal") then
				parte.LocalTransparencyModifier = if visible then 0 else 1
			end
		end
	end
end

-- Lo que tiene más cerca: cualquier bicho (el latido) y, aparte, sin el Imitador mientras finge ser una persona en
-- la puerta (contener la respiración delataría que no es un amigo, como la tensión de AmbienteMiedo).
local function bichoMasCerca(desde: Vector3): (number, number)
	local carpeta = workspace:FindFirstChild("Bichos")
	local mejor, acecha = math.huge, math.huge
	for _, bicho in if carpeta then carpeta:GetChildren() else {} do
		local raiz = bicho:FindFirstChild("HumanoidRootPart") :: BasePart?
		if raiz then
			local d = (raiz.Position - desde).Magnitude
			mejor = math.min(mejor, d)
			if not (bicho.Name == "Imitador" and not bicho:GetAttribute("Abierto")) then
				acecha = math.min(acecha, d)
			end
		end
	end
	return mejor, acecha
end

-- Contener o Exhalar (si ya hay grabación): uno solo a la vez.
local function decir(nombre: string)
	if voz then
		voz:Destroy()
	end
	voz = if Sonido.hay(nombre) then Sonido.tocar(nombre) else nil
end

-- Deja la respiración como si nada (al salir y en el susto): sin sonar y sin que se quede nada puesto. Saliendo, el
-- aire que ya estabas soltando acaba de sonar (se borra solo); conteniendo, o en el susto (`todo`), se corta.
local function cortarAliento(todo: boolean)
	if voz and (todo or conteniendo) then
		voz:Destroy()
		voz = nil
	end
	conteniendo = false
	soltado = -math.huge
	ahogo = 0
	if respiracion then
		respiracion:Destroy()
		respiracion = nil
	end
	if cierreVisto ~= 0 then
		cierreVisto = 0
		ahogoLados.ImageTransparency = 1
		ahogoArriba.ImageTransparency = 1
	end
end

-- Cámara del escondite: fija, con un leve respirar. Al meterse, la cámara va de los ojos al escondite en un momento
-- (agachándose un poco por el camino), no de golpe.
local metiendose: { desde: CFrame, inicio: number }? = nil
local ENTRAR = 0.5

-- Coge aire o lo suelta según lo cerca que esté el bicho (`acecha`, en studs) y cuánto lleva aguantando. Mientras te
-- metes no: el bicho que te ha visto ya está encima, y primero hay que llegar dentro.
local function respirar(t: number, dt: number, acecha: number, entrando: boolean)
	if conteniendo then
		if acecha > SOLTAR or t - cogido >= AGUANTE then
			conteniendo = false
			soltado = t
			decir("Exhalar")
		end
	elseif not entrando and acecha < CONTENER and t - soltado >= RECUPERAR then
		conteniendo = true
		cogido = t
		decir("Contener")
	end
	ahogo = if conteniendo then math.min(1, ahogo + dt / COGER_S) else math.max(0, ahogo - dt / SOLTAR_S)
end

-- Los últimos segundos del aguante (no puedes más), lo que dura el jadeo y el temblor al soltar el aire: de 1 a 0.
local function tramos(t: number): (number, number, number)
	local aprieta = if conteniendo then math.clamp((t - cogido - (AGUANTE - APRIETA)) / APRIETA, 0, 1) else 0
	local jadeo = math.clamp(1 - (t - soltado) / RECUPERAR, 0, 1)
	local suelta = math.clamp(1 - (t - soltado) / SUELTA_S, 0, 1)
	return aprieta, jadeo, suelta
end

-- Lo que se oye y se ve del aliento, escondido o debajo de un mueble: conteniendo se cierran los bordes, calla la
-- respiración y el latido sube; jadeando, la respiración sube. `cerca`: studs del bicho más cercano; `base`: el
-- volumen del latido sin bichos cerca.
local function notarAliento(cerca: number, base: number, aprieta: number, jadeo: number)
	local cierre = ahogo * (0.7 + 0.3 * aprieta)
	if math.abs(cierre - cierreVisto) > 0.004 or (cierre == 0 and cierreVisto ~= 0) then
		cierreVisto = cierre
		ahogoLados.ImageTransparency = 1 - cierre * CIERRA
		ahogoArriba.ImageTransparency = 1 - cierre * CIERRA
	end
	if respiracion then
		respiracion.Volume = respiracionVolumen * (1 - ahogo) * (1 + 0.6 * jadeo)
		respiracion.PlaybackSpeed = 1 + 0.15 * jadeo
	end
	if latido then
		latido.Volume = base + 1.2 * math.clamp(1 - cerca / 45, 0, 1) + LATIDO_MAS * ahogo * (1 + aprieta)
		latido.PlaybackSpeed = 1 + 0.5 * math.clamp(1 - cerca / 30, 0, 1) + LATIDO_PRISA * (ahogo + aprieta)
	end
end

-- La respiración en bucle, si hay grabación (escondido y debajo de un mueble).
local function respirarEnBucle()
	if not respiracion and Sonido.hay("Respiracion") then
		local s = Sonido.bucle("Respiracion")
		respiracionVolumen = s.Volume
		respiracion = s
	end
end

-- Debajo de un mueble (atributo Cubierto): el aliento como escondido, sin tocar la cámara (la lleva CuerpoVista). El
-- latido solo se oye con un bicho cerca. true mientras dura.
local function debajoDeMueble(dt: number): boolean
	if jugador:GetAttribute("Cubierto") ~= true or susto or jugador:GetAttribute("Muerto") then
		if cubiertoDesde then
			cubiertoDesde = nil
			cortarAliento(false) -- si sales a medias, sin soltar el aire (como del escondite)
			if latido then
				latido:Destroy()
				latido = nil
			end
		end
		return false
	end
	local t = os.clock()
	if not cubiertoDesde then
		cubiertoDesde = t
		latido = latido or Sonido.bucle("Latido")
		respirarEnBucle()
	end
	local cerca, acecha = bichoMasCerca(camara.CFrame.Position)
	respirar(t, dt, acecha, t - (cubiertoDesde :: number) < ENTRAR) -- recién metido, aún no
	local aprieta, jadeo = tramos(t)
	notarAliento(cerca, 0, aprieta, jadeo)
	return true
end

local function enEscondite(dt: number)
	local vista = jugador:GetAttribute("Escondido")
	if typeof(vista) ~= "CFrame" or susto then
		metiendose = nil
		if debajoDeMueble(dt) then
			return
		end
		if conteniendo or ahogo > 0 or soltado > -math.huge or respiracion then
			cortarAliento(susto)
		end
		return
	end
	local t = os.clock()
	if camara.CameraType ~= Enum.CameraType.Scriptable and not metiendose then
		metiendose = { desde = camara.CFrame, inicio = t }
	end
	camara.CameraType = Enum.CameraType.Scriptable
	local e = metiendose
	local cerca, acecha = bichoMasCerca(vista.Position)
	respirar(t, dt, acecha, e ~= nil and t - e.inicio < ENTRAR)
	local aprieta, jadeo, suelta = tramos(t)
	-- El leve respirar: más deprisa y más hondo jadeando; conteniendo, quieta, con el pecho lleno (un poco más
	-- arriba) y temblando un poco (más al final). Al soltar el aire, tiembla y baja un momento.
	fase += dt * (1 + 0.8 * jadeo)
	local mece = (1 - ahogo) * (1 + 0.8 * jadeo)
	local alto = math.sin(fase * 1.6) * 0.04 * mece + SUBE * ahogo - 2 * SUBE * math.sin(suelta * math.pi)
	local destino = vista * CFrame.new(0, alto, 0)
		* CFrame.Angles(math.sin(fase * 0.8) * 0.01 * mece, math.sin(fase * 0.5) * 0.02 * mece, 0)
	local tiembla = ahogo * (TIEMBLA + TIEMBLA_FIN * aprieta) + TIEMBLA_SUELTA * suelta
	if tiembla > 0 then
		destino *= CFrame.Angles(math.noise(t * 11, 1.7) * tiembla, math.noise(t * 11, 5.3) * tiembla,
			math.noise(t * 7, 9.1) * tiembla * 0.5)
	end
	if e and t - e.inicio < ENTRAR then
		local k = (t - e.inicio) / ENTRAR
		k = k * k * (3 - 2 * k)
		local agacha = math.sin(k * math.pi) * 0.5 -- baja un poco al meterse
		destino = e.desde:Lerp(destino, k) * CFrame.new(0, -agacha, 0)
	end
	camara.CFrame = destino
	notarAliento(cerca, 0.25, aprieta, jadeo)
end

-- Los bordes oscuros: cerrados escondido; flojos debajo de un mueble (que sepas que estás escondido); si no, nada.
local function pintarBordes()
	local escondido = typeof(jugador:GetAttribute("Escondido")) == "CFrame"
	local cubierto = jugador:GetAttribute("Cubierto") == true
	local meta = if escondido then 0.05 elseif cubierto then VINETA_CUBIERTO else 1
	TweenService:Create(bordes, TweenInfo.new(0.6), { ImageTransparency = meta }):Play()
end

local function cambiarEscondido()
	local escondido = typeof(jugador:GetAttribute("Escondido")) == "CFrame"
	salir.Visible = escondido
	pintarBordes()
	personajeVisible(not escondido)
	if escondido then
		cubiertoDesde = nil -- de debajo de un mueble al escondite: lo de aquí manda (el latido y el aliento siguen)
		latido = latido or Sonido.bucle("Latido")
		respirarEnBucle()
		ContextActionService:BindAction("SalirEscondite", function(_, estado)
			if estado == Enum.UserInputState.Begin then
				Remotes.Salir:FireServer()
			end
			return Enum.ContextActionResult.Sink
		end, false, Enum.KeyCode.E, Enum.KeyCode.Space, Enum.KeyCode.ButtonB)
	else
		ContextActionService:UnbindAction("SalirEscondite")
		if latido then
			latido:Destroy()
			latido = nil
		end
		cortarAliento(susto) -- si sales a medias, sin soltar el aire
		if not susto then
			camara.CameraType = Enum.CameraType.Custom
		end
	end
end

local function vivos(): { Player }
	local lista = {}
	for _, otro in Players:GetPlayers() do
		local humanoide = otro.Character and otro.Character:FindFirstChildOfClass("Humanoid")
		if otro ~= jugador and humanoide and humanoide.Health > 0 and not otro:GetAttribute("Muerto") then
			table.insert(lista, otro)
		end
	end
	return lista
end

-- De muerto: la cámara sigue a uno de los vivos.
local function mirarVivos(siguiente: boolean)
	if not jugador:GetAttribute("Muerto") or susto then
		mirando.Visible = false
		return
	end
	local lista = vivos()
	if #lista == 0 then
		mirando.Visible = false
		return
	end
	if siguiente then
		mirado += 1
	end
	mirado = ((mirado - 1) % #lista) + 1
	local otro = lista[mirado]
	local humanoide = otro.Character and otro.Character:FindFirstChildOfClass("Humanoid")
	if humanoide and camara.CameraSubject ~= humanoide then
		camara.CameraType = Enum.CameraType.Custom
		camara.CameraSubject = humanoide
		Remotes.Mirar:FireServer(otro) -- con el mapa por partes, que cargue alrededor de él (no del muerto)
	end
	mirando.Text = Lang.t(nil, "Watching {name}", { name = otro.DisplayName })
	mirando.Visible = true
end

-- Sangre en la pantalla: goterones que caen desde el borde de arriba y salpicaduras con gotas alrededor.
-- Los tamaños van en proporción a la altura de la pantalla (RelativeYY) para que no se deformen.
local function gota(padre: GuiObject, posicion: UDim2, ancho: number, alto: number, giro: number): Frame
	local g = Instance.new("Frame")
	g.AnchorPoint = Vector2.new(0.5, 0.5)
	g.Position = posicion
	g.Size = UDim2.fromScale(ancho, alto)
	g.SizeConstraint = Enum.SizeConstraint.RelativeYY
	g.Rotation = giro
	g.BackgroundColor3 = Color3.new(1, 1, 1)
	g.BorderSizePixel = 0
	g.ZIndex = 91
	local redondo = Instance.new("UICorner")
	redondo.CornerRadius = UDim.new(0.5, 0)
	redondo.Parent = g
	local brillo = Instance.new("UIGradient") -- rojo oscuro, más claro por un lado: que parezca mojado
	brillo.Color = ColorSequence.new(Color3.fromRGB(96, 3, 3), Color3.fromRGB(36, 0, 0))
	brillo.Rotation = 90 + giro
	brillo.Parent = g
	g.Parent = padre
	return g
end

local function salpicadura(padre: GuiObject, x: number, y: number, grande: number)
	local aspecto = camara.ViewportSize.X / math.max(1, camara.ViewportSize.Y)
	for _ = 1, 5 do -- el centro: manchas encimadas, forma irregular
		local t = grande * azar:NextNumber(0.5, 1)
		gota(padre, UDim2.fromScale(x + azar:NextNumber(-0.4, 0.4) * grande / aspecto, y + azar:NextNumber(-0.4, 0.4) * grande),
			t, t * azar:NextNumber(0.7, 1.2), azar:NextNumber(0, 180))
	end
	for _ = 1, azar:NextInteger(12, 18) do -- gotas que salen hacia fuera, alargadas en la dirección en que salieron
		local angulo = azar:NextNumber(0, math.pi * 2)
		local lejos = grande * azar:NextNumber(0.6, 1.6)
		local t = grande * azar:NextNumber(0.05, 0.18)
		gota(padre, UDim2.fromScale(x + math.cos(angulo) * lejos / aspecto, y + math.sin(angulo) * lejos),
			t, t * azar:NextNumber(1.5, 3.5), math.deg(angulo) + 90)
	end
end

local function sangre(): Frame
	local capaSangre = Instance.new("Frame")
	capaSangre.Name = "Sangre"
	capaSangre.Size = UDim2.fromScale(1, 1)
	capaSangre.BackgroundTransparency = 1
	capaSangre.ZIndex = 91
	capaSangre.Parent = capa
	-- Borde de arriba empapado y goterones que bajan despacio, cada uno con su gota gorda al final.
	local borde = gota(capaSangre, UDim2.fromScale(0.5, 0), 4, 0.07, 0)
	borde.SizeConstraint = Enum.SizeConstraint.RelativeXY
	borde.Size = UDim2.fromScale(1.1, 0.07)
	for _ = 1, azar:NextInteger(14, 20) do
		local ancho = azar:NextNumber(0.012, 0.035)
		local chorro = gota(capaSangre, UDim2.fromScale(azar:NextNumber(0, 1), 0), ancho, 0, 0)
		chorro.AnchorPoint = Vector2.new(0.5, 0)
		local bola = gota(chorro, UDim2.fromScale(0.5, 1), 1.7, 1.9, 0)
		bola.SizeConstraint = Enum.SizeConstraint.RelativeXX
		TweenService:Create(chorro, TweenInfo.new(azar:NextNumber(2, 5), Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.fromScale(ancho, azar:NextNumber(0.12, 0.55)) }):Play()
	end
	-- Salpicaduras grandes en los lados y una pequeña arriba (abajo en el centro va el aviso).
	salpicadura(capaSangre, azar:NextNumber(0.02, 0.18), azar:NextNumber(0.25, 0.8), azar:NextNumber(0.22, 0.32))
	salpicadura(capaSangre, azar:NextNumber(0.82, 0.98), azar:NextNumber(0.25, 0.8), azar:NextNumber(0.22, 0.32))
	salpicadura(capaSangre, azar:NextNumber(0.35, 0.65), azar:NextNumber(0.05, 0.15), azar:NextNumber(0.08, 0.12))
	return capaSangre
end

local function quitarSangre(capaSangre: Frame, despues: number)
	task.delay(despues, function()
		for _, g in capaSangre:GetDescendants() do
			if g:IsA("Frame") then
				TweenService:Create(g, TweenInfo.new(3), { BackgroundTransparency = 1 }):Play()
			end
		end
		task.delay(3, capaSangre.Destroy, capaSangre)
	end)
end

local function meHanPillado(cabeza: Vector3)
	susto = true
	cortarAliento(true) -- conteniendo o soltándolo: se corta en seco
	ContextActionService:UnbindAction("SalirEscondite")
	salir.Visible = false
	local personaje = jugador.Character
	local mia = personaje and personaje:FindFirstChild("Head") :: BasePart?
	local desde = if mia then mia.Position else camara.CFrame.Position
	local hacia = (desde - cabeza)
	hacia = if hacia.Magnitude > 0.1 then hacia.Unit else Vector3.zAxis
	-- La cara del bicho de frente, con la boca abierta, echándose encima; una luz para que se le vea en lo oscuro.
	local bicho = GolpeadorVista.rugir(cabeza) or RaspadorVista.rugir(cabeza) or TrepadorVista.rugir(cabeza)
		or ImitadorVista.rugir(cabeza) or AcechadorVista.rugir(cabeza) or BestiaVista.rugir(cabeza)
	local cara = bicho and bicho:FindFirstChild("Cabeza") :: BasePart?
	local luz: Attachment? = nil
	if cara then
		luz = Instance.new("Attachment") -- delante de la cara: dentro de la cabeza no la alumbraría
		luz.Position = Vector3.new(0, -0.3, -1.6)
		local foco = Instance.new("PointLight")
		foco.Color = Color3.fromRGB(255, 215, 195)
		foco.Brightness = 1.2
		foco.Range = 6
		foco.Parent = luz
		luz.Parent = cara
	end
	personajeVisible(false)
	local filtroSusto = RaycastParams.new()
	filtroSusto.FilterType = Enum.RaycastFilterType.Exclude
	filtroSusto.FilterDescendantsInstances = { workspace:FindFirstChild("Bichos") :: Instance, personaje :: Instance }
	camara.CameraType = Enum.CameraType.Scriptable
	camara.FieldOfView = 60
	Sonido.tocar("Susto")
	rojo.BackgroundTransparency = 0.35
	TweenService:Create(rojo, TweenInfo.new(1.4), { BackgroundTransparency = 1 }):Play()
	local capaSangre = sangre()
	local t0 = os.clock()
	while os.clock() - t0 < 1.8 do
		local t = os.clock() - t0
		local fuerza = 0.16 * (1 - t / 1.8) + 0.03
		local ojo, centro
		if cara and cara.Parent then
			local acerca = 1 - math.clamp(t / 0.2, 0, 1)
			centro = cara.Position - Vector3.new(0, 0.6, 0)
			ojo = (cara.CFrame * CFrame.new(0, -0.5, -(2.7 + acerca * 3.5))).Position
			local choque = workspace:Raycast(centro, ojo - centro, filtroSusto) -- sin meterse en las paredes
			if choque then
				ojo = choque.Position + (centro - ojo).Unit * 0.3
			end
		else
			centro, ojo = cabeza, cabeza + hacia * 2.4
		end
		camara.CFrame = CFrame.lookAt(ojo, centro)
			* CFrame.new(azar:NextNumber(-fuerza, fuerza), azar:NextNumber(-fuerza, fuerza), 0)
			* CFrame.Angles(0, 0, azar:NextNumber(-fuerza, fuerza) * 0.5)
		RunService.RenderStepped:Wait()
	end
	if luz then
		luz:Destroy()
	end
	TweenService:Create(negro, TweenInfo.new(0.6), { BackgroundTransparency = 0 }):Play()
	task.wait(1.2)
	-- El de Roblox, fijo: el que había al morir podía ser el de la mochila abierta (más cerrado) y se quedaba así.
	camara.FieldOfView = 70
	Ui.aviso(Lang.t(nil, "It got you. You'll wake up at dawn."), 5)
	susto = false
	camara.CameraType = Enum.CameraType.Custom
	mirarVivos(false)
	TweenService:Create(negro, TweenInfo.new(1.5), { BackgroundTransparency = 1 }):Play()
	quitarSangre(capaSangre, 3) -- se queda goteando un poco sobre lo que ves de muerto
end

local function charco(posicion: Vector3)
	local resultado = workspace:Raycast(posicion, Vector3.new(0, -8, 0))
	if not resultado then
		return
	end
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Material = Enum.Material.SmoothPlastic
	p.Reflectance = 0.15
	p.Color = Color3.fromRGB(60, 4, 4)
	p.Size = Vector3.new(0.05, 1, 1)
	p.CFrame = CFrame.new(resultado.Position + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	p.Parent = workspace.Terrain
	local final = azar:NextNumber(5, 7)
	TweenService:Create(p, TweenInfo.new(6, Enum.EasingStyle.Quad), { Size = Vector3.new(0.05, final, final) }):Play()
	-- Se limpia al amanecer.
	local conexion
	conexion = workspace:GetAttributeChangedSignal("Fase"):Connect(function()
		if workspace:GetAttribute("Fase") == "Dia" then
			conexion:Disconnect()
			p:Destroy()
		end
	end)
end

local function capas()
	capa = Instance.new("Frame")
	capa.Name = "Muerte"
	capa.Size = UDim2.fromScale(1, 1)
	capa.BackgroundTransparency = 1
	capa.ZIndex = 90
	capa.Parent = Ui.hud()
	-- Bordes oscuros al esconderse: un degradado radial hecho con UIGradient sobre un marco.
	bordes = Instance.new("ImageLabel")
	bordes.Size = UDim2.fromScale(1, 1)
	bordes.BackgroundTransparency = 1
	bordes.Image = "rbxasset://textures/ui/TopBar/WhiteOverlayAsset.png"
	bordes.ImageColor3 = Color3.new(0, 0, 0)
	bordes.ImageTransparency = 1
	bordes.ZIndex = 90
	local degradado = Instance.new("UIGradient")
	degradado.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.18, 0.75),
		NumberSequenceKeypoint.new(0.82, 0.75),
		NumberSequenceKeypoint.new(1, 0),
	})
	degradado.Parent = bordes
	bordes.Parent = capa
	-- Bordes de más que se cierran conteniendo la respiración: a los lados (más adentro que los de siempre) y arriba
	-- y abajo, para que se estreche la vista.
	local function cerrarse(giro: number): ImageLabel
		local b = Instance.new("ImageLabel")
		b.Name = "Ahogo"
		b.Size = UDim2.fromScale(1, 1)
		b.BackgroundTransparency = 1
		b.Image = "rbxasset://textures/ui/TopBar/WhiteOverlayAsset.png"
		b.ImageColor3 = Color3.new(0, 0, 0)
		b.ImageTransparency = 1
		b.ZIndex = 90
		local d = Instance.new("UIGradient")
		d.Rotation = giro
		d.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.3, 1),
			NumberSequenceKeypoint.new(0.7, 1),
			NumberSequenceKeypoint.new(1, 0),
		})
		d.Parent = b
		b.Parent = capa
		return b
	end
	ahogoLados = cerrarse(0)
	ahogoArriba = cerrarse(90)
	rojo = Instance.new("Frame")
	rojo.Size = UDim2.fromScale(1, 1)
	rojo.BackgroundColor3 = Color3.fromRGB(120, 0, 0)
	rojo.BackgroundTransparency = 1
	rojo.BorderSizePixel = 0
	rojo.ZIndex = 92
	rojo.Parent = capa
	negro = Instance.new("Frame")
	negro.Size = UDim2.fromScale(1, 1)
	negro.BackgroundColor3 = Color3.new(0, 0, 0)
	negro.BackgroundTransparency = 1
	negro.BorderSizePixel = 0
	negro.ZIndex = 95
	negro.Parent = capa

	salir = Ui.boton(Lang.t(nil, "Leave"), {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.93),
		Size = UDim2.fromOffset(220, 80), -- que se acierte con el dedo en el móvil
		TextSize = 28,
		Visible = false,
		ZIndex = 96,
	})
	salir.Activated:Connect(function()
		Remotes.Salir:FireServer()
	end)
	salir.Parent = capa
	mirando = Ui.texto("", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.95),
		Size = UDim2.fromScale(0.6, 0.04),
		TextSize = 22,
		Visible = false,
		ZIndex = 96,
	})
	mirando.Parent = capa
end

function MuerteVista.start()
	capas()
	-- Sin el botón de reiniciar de Roblox: aquí no se reaparece (quedabas muerto hasta el amanecer y, solo, volvía a
	-- empezar el día). SetCore falla hasta que el CoreGui está listo: se reintenta.
	task.spawn(function()
		for _ = 1, 20 do
			if pcall(StarterGui.SetCore, StarterGui, "ResetButtonCallback", false) then
				break
			end
			task.wait(0.5)
		end
	end)
	jugador:GetAttributeChangedSignal("Escondido"):Connect(cambiarEscondido)
	jugador:GetAttributeChangedSignal("Cubierto"):Connect(pintarBordes) -- debajo de un mueble (Postura)
	jugador:GetAttributeChangedSignal("Muerto"):Connect(function()
		if not jugador:GetAttribute("Muerto") then
			mirando.Visible = false
			jugador.CameraMode = Enum.CameraMode.LockFirstPerson
			jugador.CameraMinZoomDistance = 0.5
		else -- de muerto se mira a los demás desde detrás
			jugador.CameraMode = Enum.CameraMode.Classic
			jugador.CameraMinZoomDistance = 10
		end
	end)
	jugador.CharacterAdded:Connect(function(personaje)
		camara.CameraType = Enum.CameraType.Custom
		camara.CameraSubject = personaje:WaitForChild("Humanoid")
	end)
	Remotes.Muerte.OnClientEvent:Connect(function(quien: Player, cabeza: Vector3)
		if quien == jugador then
			task.spawn(meHanPillado, cabeza)
		else
			local raiz = quien.Character and quien.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if raiz then
				charco(raiz.Position)
			end
		end
	end)
	UserInputService.InputBegan:Connect(function(entrada, procesado)
		if procesado or not jugador:GetAttribute("Muerto") then
			return
		end
		if entrada.UserInputType == Enum.UserInputType.MouseButton1 then
			mirarVivos(true)
		end
	end)
	-- En el móvil, solo con un toque corto: arrastrar el dedo (girar la cámara) o pellizcar no cambia de vivo.
	UserInputService.TouchTap:Connect(function(_, procesado)
		if not procesado and jugador:GetAttribute("Muerto") then
			mirarVivos(true)
		end
	end)
	RunService.RenderStepped:Connect(enEscondite)
	task.spawn(function()
		while true do
			task.wait(1)
			mirarVivos(false) -- por si el que mirabas ha muerto
		end
	end)
end

return MuerteVista
