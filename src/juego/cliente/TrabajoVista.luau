-- Animaciones de trabajar (pedido por el usuario: sencillas pero que se noten): talar, serrar, clavar y echar
-- gasolina, y el generador. Las manda el servidor con el remote Trabajo (Recursos, Cargar, Casa, Generador).
--   Herramientas de bloques: las tuyas delante de la cámara; las de los demás, delante de su pecho.
--   Talar: hachazo con astillas, el árbol tiembla y el corte se ahonda con cada golpe; al caer, golpe contra el suelo
--   y, al partirse, polvo y astillas a lo largo del tronco.
--   Serrar: la sierra va y viene con serrín. Clavar: martillazos con un clavo nuevo en cada uno; el tablón se funde al
--   final con lo reparado. Verter: un chorro del bidón al tapón (del generador o del coche). Montar: la llave inglesa
--   aprieta a tirones (piezas del coche). Fabricar: martillazos con chispas en un banco del taller.
--   Generador: la cuerda se estira con cada tirón; encendido tiembla, echa humo y suena; indicador de gasolina.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sonido = require(script.Parent.Sonido)

local TrabajoVista = {}

local jugador = Players.LocalPlayer
local camara = workspace.CurrentCamera
local azar = Random.new()

local MADERA = Color3.fromRGB(150, 118, 82)
local METAL = Color3.fromRGB(95, 96, 100)

-- Una herramienta de bloques: piezas con su sitio respecto al agarre (el mango sube por Y, lo que corta va hacia -Z).
type Pieza = { parte: BasePart, sitio: CFrame }
type Activo = { piezas: { Pieza }, accion: string, inicio: number, fin: number, golpes: number, pieza: BasePart? }
local activos: { [Player]: Activo } = {}

local function parte(tamano: Vector3, color: Color3, material: Enum.Material?): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = tamano
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	return p
end

local HERRAMIENTAS = {
	Hachazo = {
		{ Vector3.new(0.22, 3.2, 0.22), CFrame.new(0, 1.3, 0), MADERA, Enum.Material.Wood },
		{ Vector3.new(0.14, 0.75, 1.05), CFrame.new(0, 2.7, -0.4), METAL, Enum.Material.Metal },
	},
	Serrar = {
		{ Vector3.new(0.3, 0.7, 0.55), CFrame.new(0, 0, 0), MADERA, Enum.Material.Wood },
		{ Vector3.new(0.05, 0.55, 2.8), CFrame.new(0, 0.05, -1.6), METAL, Enum.Material.Metal },
	},
	Clavar = {
		{ Vector3.new(0.18, 1.5, 0.18), CFrame.new(0, 0.6, 0), MADERA, Enum.Material.Wood },
		{ Vector3.new(0.34, 0.34, 0.95), CFrame.new(0, 1.35, -0.1), METAL, Enum.Material.Metal },
	},
	Montar = { -- llave inglesa
		{ Vector3.new(0.16, 1.4, 0.3), CFrame.new(0, 0.55, 0), METAL, Enum.Material.Metal },
		{ Vector3.new(0.16, 0.3, 0.6), CFrame.new(0, 1.3, -0.15), METAL, Enum.Material.Metal },
	},
}
HERRAMIENTAS.Fabricar = HERRAMIENTAS.Clavar

local function herramienta(accion: string): { Pieza }
	local lista = {}
	for _, datos in HERRAMIENTAS[accion] or {} do
		local p = parte(datos[1], datos[3], datos[4])
		p.Parent = camara
		table.insert(lista, { parte = p, sitio = datos[2] })
	end
	return lista
end

local function quitar(quien: Player)
	local activo = activos[quien]
	if activo then
		activos[quien] = nil
		for _, p in activo.piezas do
			p.parte:Destroy()
		end
	end
end

-- Trocitos que saltan y se apagan (astillas, serrín, polvo).
local function trozos(punto: Vector3, cuantos: number, color: Color3, fuerza: number, tamano: number)
	for _ = 1, cuantos do
		local p = parte(Vector3.new(tamano, tamano * 0.5, tamano * azar:NextNumber(1, 2.5)), color, Enum.Material.Wood)
		p.Anchored = false
		p.CanCollide = true
		p.Massless = true
		p.CollisionGroup = "Cargado" -- no choca con los jugadores
		p.CFrame = CFrame.new(punto) * CFrame.Angles(azar:NextNumber(0, 6), azar:NextNumber(0, 6), 0)
		p.Parent = workspace
		p.AssemblyLinearVelocity = Vector3.new(azar:NextNumber(-1, 1), azar:NextNumber(0.6, 1.4), azar:NextNumber(-1, 1)) * fuerza
		p.AssemblyAngularVelocity = Vector3.new(azar:NextNumber(-12, 12), azar:NextNumber(-12, 12), 0)
		TweenService:Create(p, TweenInfo.new(1.2, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 1), { Transparency = 1 }):Play()
		task.delay(2.4, p.Destroy, p)
	end
end

-- Mueve un instante una pieza anclada y la devuelve a su sitio.
local function sacudir(p: BasePart, fuerza: number)
	local origen = p:GetAttribute("Origen") or p.CFrame
	p:SetAttribute("Origen", origen)
	task.spawn(function()
		for i = 3, 1, -1 do
			if not p.Anchored then
				break
			end
			p.CFrame = origen * CFrame.Angles(azar:NextNumber(-1, 1) * fuerza * i, 0, azar:NextNumber(-1, 1) * fuerza * i)
			task.wait(0.03)
		end
		if p.Anchored then
			p.CFrame = origen
		end
		p:SetAttribute("Origen", nil)
	end)
end

-- ===== Talar =====

local function plano(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- El corte del árbol: una franja oscura que se ensancha y ahonda con cada hachazo, del lado de quien tala.
local function cortar(tronco: BasePart, desde: Vector3)
	local modelo = tronco.Parent :: Model
	local hacia = plano(desde - tronco.Position)
	hacia = if hacia.Magnitude > 0.1 then hacia.Unit else Vector3.xAxis
	local radio = tronco.Size.Y / 2
	local hecho = math.clamp((modelo:GetAttribute("Golpes") or 0) / (modelo:GetAttribute("GolpesMax") or 6), 0, 1)
	local base = tronco.Position.Y - tronco.Size.X / 2
	local superficie = Vector3.new(tronco.Position.X, base + 3.2, tronco.Position.Z) + hacia * radio
	local corte = modelo:FindFirstChild("CorteLocal") :: BasePart?
	if not corte then
		corte = parte(Vector3.one, Color3.fromRGB(205, 172, 122), Enum.Material.Wood) -- madera clara de dentro
		;(corte :: BasePart).Name = "CorteLocal"
		;(corte :: BasePart).Parent = modelo
		tronco:GetPropertyChangedSignal("Anchored"):Once(function()
			(corte :: BasePart):Destroy() -- al caer
		end)
	end
	local hondo = 0.15 + hecho * radio * 1.2
	;(corte :: BasePart).Size = Vector3.new(tronco.Size.Y * 0.7, 0.35 + hecho * 0.5, hondo)
	;(corte :: BasePart).CFrame = CFrame.lookAt(superficie - hacia * (hondo / 2 - 0.06), superficie + hacia)
	trozos(superficie + hacia * 0.2, 5, Color3.fromRGB(196, 168, 120), 14, 0.22)
	sacudir(tronco, 0.006)
	Sonido.en("Hachazo", superficie, azar:NextNumber(0.9, 1.1))
end

-- Hachazo: sube (0,12 s), baja de golpe (0,1 s) y vuelve; el golpe suena al llegar abajo.
local function poseHacha(t: number): CFrame
	local angulo
	if t < 0.12 then
		angulo = 15 + (60 - 15) * (t / 0.12)
	elseif t < 0.22 then
		angulo = 60 - 135 * ((t - 0.12) / 0.1)
	elseif t < 0.5 then
		angulo = -75 + 90 * ((t - 0.22) / 0.28)
	else
		angulo = 15
	end
	return CFrame.Angles(math.rad(angulo), 0, math.rad(-12))
end

local function hachazo(quien: Player, tronco: BasePart?)
	local activo = activos[quien]
	if not activo or activo.accion ~= "Hachazo" then
		quitar(quien)
		activo = { piezas = herramienta("Hachazo"), accion = "Hachazo", inicio = 0, fin = 0, golpes = 0 }
		activos[quien] = activo
	end
	local a = activo :: Activo
	a.inicio = os.clock()
	a.fin = os.clock() + 1.6 -- se queda el hacha en la mano un rato
	local raiz = quien.Character and quien.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	task.delay(0.22, function()
		if tronco and tronco.Parent and raiz then
			cortar(tronco, raiz.Position)
		end
	end)
end

-- El tronco caído se parte: polvo y astillas a lo largo.
local function parte_(centro: Vector3, eje: Vector3, largo: number)
	for i = -2, 2 do
		trozos(centro + eje * (largo / 5) * i, 4, Color3.fromRGB(120, 100, 76), 10, 0.3)
	end
	Sonido.en("Hachazo", centro, 0.7)
end

-- Cuando un árbol empieza a caer, el golpe contra el suelo.
local function vigilarArbol(modelo: Instance)
	local tronco = modelo:WaitForChild("Tronco", 10) :: BasePart?
	if not tronco then
		return
	end
	tronco:GetPropertyChangedSignal("Anchored"):Connect(function()
		if tronco.Anchored then
			return
		end
		task.spawn(function()
			local inicio = os.clock()
			while tronco.Parent and os.clock() - inicio < 8 do
				if math.abs(tronco.CFrame.RightVector.Y) < 0.25 then -- ya tumbado: da contra el suelo
					Sonido.en("Caida", tronco.Position)
					trozos(tronco.Position, 8, Color3.fromRGB(90, 80, 64), 8, 0.35)
					return
				end
				task.wait(0.03)
			end
		end)
	end)
end

-- ===== Serrar, clavar, verter =====

-- La sierra tumbada hacia delante, un poco hacia abajo, yendo y viniendo.
local function poseSierra(t: number): CFrame
	return CFrame.new(0, 0, math.sin(t * math.pi * 2 * 1.6) * 0.7) * CFrame.Angles(math.rad(-15), 0, 0)
end

-- Dónde va el agarre de cada herramienta: delante de tu cámara o del pecho de otro.
local SITIO = {
	Hachazo = { CFrame.new(1.1, -1.3, -2.1), CFrame.new(0.9, 0.3, -1.4) },
	Serrar = { CFrame.new(0.35, -1.2, -1.1), CFrame.new(0.5, 0.2, -0.9) },
	Clavar = { CFrame.new(0.8, -1.2, -1.8), CFrame.new(0.8, 0.4, -1.4) },
	Montar = { CFrame.new(0.7, -1.1, -1.7), CFrame.new(0.8, 0.2, -1.4) },
}
SITIO.Fabricar = SITIO.Clavar

-- La llave inglesa gira a tirones (aprieta, vuelve).
local function poseLlave(t: number): CFrame
	local fase = (t % 0.6) / 0.6
	return CFrame.Angles(0, 0, math.rad(if fase < 0.7 then -50 * (fase / 0.7) else -50 + 50 * ((fase - 0.7) / 0.3)))
end

local CADA_MARTILLAZO = 0.45
local function poseMartillo(t: number): CFrame
	local fase = (t % CADA_MARTILLAZO) / CADA_MARTILLAZO
	local angulo = if fase < 0.65 then -40 + 95 * (fase / 0.65) else 55 - 95 * ((fase - 0.65) / 0.35)
	return CFrame.Angles(math.rad(angulo), 0, 0)
end

-- Un martillazo: clavo nuevo en el tablón, que salta un poco.
local function martillazo(a: Activo, quien: Player)
	local tablon = a.pieza
	if not tablon or not tablon.Parent then
		return
	end
	a.golpes += 1
	local ojo = if quien == jugador then camara.CFrame.Position else tablon.Position + Vector3.yAxis
	local cara = if (ojo - tablon.Position):Dot(tablon.CFrame.UpVector) >= 0 then 1 else -1
	local sitios = { -2.3, 2.3, -1.3, 1.3, 0 }
	local x = sitios[(a.golpes - 1) % #sitios + 1]
	local clavo = parte(Vector3.new(0.12, 0.12, 0.12), Color3.fromRGB(40, 40, 42), Enum.Material.Metal)
	clavo.CFrame = tablon.CFrame * CFrame.new(x, 0.17 * cara, 0)
	clavo.Parent = tablon
	sacudir(tablon, 0.01)
	trozos(clavo.Position, 2, Color3.fromRGB(196, 168, 120), 6, 0.12)
	Sonido.en("Martillo", clavo.Position, 1)
end

-- El chorro del bidón al tapón más cerca (el del generador o el del coche).
local function chorro(pieza: BasePart, segundos: number)
	local tapon: Vector3? = nil
	for _, etiqueta in { "Generador", "Coche" } do
		for _, el in CollectionService:GetTagged(etiqueta) do
			local cf = el:GetAttribute("Tapon")
			if typeof(cf) == "CFrame" and (not tapon or (cf.Position - pieza.Position).Magnitude < (tapon - pieza.Position).Magnitude) then
				tapon = cf.Position
			end
		end
	end
	if not tapon then
		return
	end
	local boca = pieza.Position + pieza.CFrame.UpVector * (pieza.Size.Y / 2)
	local largo = (boca - tapon).Magnitude
	local p = parte(Vector3.new(0.2, 0.2, largo), Color3.fromRGB(205, 165, 60), Enum.Material.Glass)
	p.Transparency = 0.25
	p.CFrame = CFrame.lookAt((boca + tapon) / 2, tapon)
	p.Parent = camara
	local s = Sonido.bucle("Verter", p)
	task.delay(segundos, function()
		s:Destroy()
		p:Destroy()
	end)
end

local function empezar(quien: Player, accion: string, pieza: BasePart?, segundos: number)
	quitar(quien)
	if not pieza then
		return
	end
	local a: Activo = { piezas = herramienta(accion), accion = accion, inicio = os.clock(), fin = os.clock() + segundos, golpes = 0,
		pieza = pieza }
	activos[quien] = a
	if accion == "Serrar" then
		local punto = Instance.new("Attachment")
		punto.Parent = pieza
		local serrin = Instance.new("ParticleEmitter")
		serrin.Texture = "rbxasset://textures/particles/smoke_main.dds"
		serrin.LightInfluence = 1 -- que no brille de noche
		serrin.Color = ColorSequence.new(Color3.fromRGB(210, 185, 140))
		serrin.Size = NumberSequence.new(0.12)
		serrin.Lifetime = NumberRange.new(0.6, 1)
		serrin.Rate = 40
		serrin.Speed = NumberRange.new(2, 4)
		serrin.SpreadAngle = Vector2.new(60, 60)
		serrin.Acceleration = Vector3.new(0, -20, 0)
		serrin.Parent = punto
		local s = Sonido.bucle("Serrar", pieza)
		task.delay(segundos, function()
			s:Destroy()
			punto:Destroy()
			if pieza.Parent then
				trozos(pieza.Position, 8, Color3.fromRGB(196, 168, 120), 10, 0.2)
			end
		end)
	elseif accion == "Clavar" then
		-- Al final el tablón se funde con lo reparado (el servidor lo quita al acabar).
		task.delay(math.max(0, segundos - 0.5), function()
			if pieza.Parent then
				for _, p in { pieza, table.unpack(pieza:GetChildren()) } do
					if p:IsA("BasePart") then
						TweenService:Create(p, TweenInfo.new(0.45), { Transparency = 1 }):Play()
					end
				end
			end
		end)
	elseif accion == "Verter" then
		chorro(pieza, segundos)
	end
end

-- Cada fotograma: las herramientas en su sitio y los martillazos a su ritmo.
local function mover()
	local ahora = os.clock()
	for quien, a in activos do
		if ahora > a.fin then
			quitar(quien)
			continue
		end
		local base: CFrame
		local sitio = SITIO[a.accion] or SITIO.Hachazo
		if quien == jugador then
			base = camara.CFrame * sitio[1]
		else
			local raiz = quien.Character and quien.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not raiz then
				quitar(quien)
				continue
			end
			base = raiz.CFrame * sitio[2]
		end
		local t = ahora - a.inicio
		local pose = if a.accion == "Hachazo" then poseHacha(t) elseif a.accion == "Serrar" then poseSierra(t)
			elseif a.accion == "Montar" then poseLlave(t) else poseMartillo(t)
		if a.accion == "Clavar" and math.floor(t / CADA_MARTILLAZO) > a.golpes and t < a.fin - a.inicio - 0.5 then
			martillazo(a, quien)
		elseif a.accion == "Fabricar" and math.floor(t / CADA_MARTILLAZO) > a.golpes and a.pieza then
			-- En el banco: martillazos con chispas de metal y astillas.
			a.golpes += 1
			Sonido.en("Martillo", a.pieza.Position, azar:NextNumber(0.9, 1.1))
			trozos(a.pieza.Position, 2, if a.golpes % 2 == 0 then Color3.fromRGB(196, 168, 120) else Color3.fromRGB(120, 92, 72), 7, 0.12)
		elseif a.accion == "Montar" and math.floor(t / 0.6) > a.golpes and a.pieza then
			a.golpes += 1
			Sonido.en("Martillo", a.pieza.Position, 1.6) -- clic metálico de la llave
		end
		for _, p in a.piezas do
			p.parte.CFrame = base * pose * p.sitio
		end
	end
end

-- ===== Generador =====

local function generador(gen: Instance)
	local cuerda = gen:WaitForChild("Cuerda") :: BasePart
	local nivel = gen:WaitForChild("Nivel") :: BasePart
	local escape = gen:WaitForChild("Escape") :: BasePart
	local origenCuerda = cuerda.CFrame
	local origenNivel = nivel.CFrame
	local altoNivel = nivel.Size.Y
	local temblar: { [BasePart]: CFrame } = {}
	for _, p in gen:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "Mando" and p.Name ~= "Cuerda" and p.Name ~= "Nivel" then
			temblar[p] = p.CFrame
		end
	end
	local punto = Instance.new("Attachment")
	punto.Position = Vector3.new(0, escape.Size.Y / 2, 0)
	punto.Parent = escape
	local humo = Instance.new("ParticleEmitter")
	humo.Texture = "rbxasset://textures/particles/smoke_main.dds"
	humo.LightInfluence = 1
	humo.Color = ColorSequence.new(Color3.fromRGB(60, 58, 56))
	humo.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	humo.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1.6) })
	humo.Lifetime = NumberRange.new(1.2, 2)
	humo.Rate = 8
	humo.Speed = NumberRange.new(1.5, 2.5)
	humo.Enabled = false
	humo.Parent = punto
	local motor: Sound? = nil

	local function nivelar()
		local g = math.clamp(gen:GetAttribute("Gasolina") or 0, 0, 1)
		local alto = math.max(0.03, altoNivel * g)
		nivel.Size = Vector3.new(nivel.Size.X, alto, nivel.Size.Z)
		nivel.CFrame = origenNivel * CFrame.new(0, -(altoNivel - alto) / 2, 0)
		nivel.Color = if g < 0.15 then Color3.fromRGB(140, 40, 30) else Color3.fromRGB(170, 140, 60)
	end
	local function encender()
		local encendido = gen:GetAttribute("Encendido") == true
		humo.Enabled = encendido
		if encendido and not motor then
			motor = Sonido.bucle("Motor", escape)
		elseif not encendido and motor then
			local s = motor :: Sound
			motor = nil
			TweenService:Create(s, TweenInfo.new(0.8), { PlaybackSpeed = 0.3, Volume = 0 }):Play()
			task.delay(0.8, s.Destroy, s)
			for p, cf in temblar do
				p.CFrame = cf
			end
		end
	end
	gen:GetAttributeChangedSignal("Gasolina"):Connect(nivelar)
	gen:GetAttributeChangedSignal("Encendido"):Connect(encender)
	gen:GetAttributeChangedSignal("Tirones"):Connect(function()
		-- Tirón: la cuerda sale de golpe y vuelve sola; el generador da un respingo.
		local fuera = origenCuerda * CFrame.new(0, 0, 0) + gen:GetPivot().RightVector * 1.8
		TweenService:Create(cuerda, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = fuera }):Play()
		task.delay(0.15, function()
			TweenService:Create(cuerda, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { CFrame = origenCuerda }):Play()
		end)
		Sonido.en("Tiron", cuerda.Position, 1.4)
		for p in temblar do
			sacudir(p, 0.01)
		end
	end)
	gen:GetAttributeChangedSignal("Ahogado"):Connect(function()
		trozos(escape.Position + Vector3.yAxis, 3, Color3.fromRGB(40, 38, 36), 3, 0.3)
	end)
	nivelar()
	encender()
	-- Encendido y cerca: tiembla.
	RunService.Heartbeat:Connect(function()
		if motor and (camara.CFrame.Position - escape.Position).Magnitude < 60 then
			for p, cf in temblar do
				p.CFrame = cf * CFrame.new(azar:NextNumber(-0.02, 0.02), azar:NextNumber(-0.02, 0.02), 0)
			end
		end
	end)
end

function TrabajoVista.start()
	Remotes.Trabajo.OnClientEvent:Connect(function(quien: Player?, accion: string, pieza: BasePart?, segundos: number, ...)
		if accion == "Parte" then
			parte_(...)
		elseif not quien then
			return
		elseif accion == "Hachazo" then
			hachazo(quien, pieza)
		elseif accion == "Parar" then
			quitar(quien)
		else
			empezar(quien, accion, pieza, segundos)
		end
	end)
	CollectionService:GetInstanceAddedSignal("Arbol"):Connect(vigilarArbol)
	for _, arbol in CollectionService:GetTagged("Arbol") do
		task.spawn(vigilarArbol, arbol)
	end
	task.spawn(function()
		local gen = CollectionService:GetTagged("Generador")[1]
		while not gen do
			CollectionService:GetInstanceAddedSignal("Generador"):Wait()
			gen = CollectionService:GetTagged("Generador")[1]
		end
		generador(gen)
	end)
	Players.PlayerRemoving:Connect(quitar)
	RunService.RenderStepped:Connect(mover)
end

return TrabajoVista
