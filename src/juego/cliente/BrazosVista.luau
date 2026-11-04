-- Los brazos de los DEMÁS jugadores (tus manos en primera persona, en Manos): que en cooperativo se vea lo que hace
-- tu amigo (pedido por el usuario: "que todo esté animado y sea inmersivo"). Cada cliente mueve los hombros de los
-- otros personajes (R15) girando el C0 de su RightShoulder / LeftShoulder, encima de las animaciones de andar.
--   Con la herramienta (TrabajoVista): el brazo derecho (y el izquierdo con el hacha) hacia el mango, que va y viene.
--   Cargando algo pesado: los dos brazos a sus lados. Linterna encendida: el izquierdo delante, alumbrando.
--   Móvil abierto: el derecho delante, doblado. Una foto: los dos a la cara. Una bengala: el derecho hacia donde da.
--   Una cortina o una puerta que se mueve junto a él (y más cerca de él que de ti): los brazos hacia ella.
--   La cabeza (y la linterna), inclinada hacia donde mira arriba o abajo (atributo Mirada, lo manda CuerpoVista).
--   Agachado (atributo Agachado, 14.6): su cliente ya le baja de verdad (PosturaVista baja su HipHeight y la física lo
--   replica), así que aquí no se le baja otra vez: las caderas, rodillas y tobillos (C0, suave) se doblan lo que de
--   verdad ha bajado su raíz respecto al suelo (un rayo hacia abajo cada MEDIR s) para que los pies sigan en el suelo,
--   con el tronco algo hacia delante. Debajo de algo (un rayo hacia arriba desde la cintura), se encorva lo que haga
--   falta para que la cabeza quepa (esconderse debajo de una mesa, pedido por el usuario). Asomado (atributo
--   Asomado): el tronco ladeado (cintura) hacia ese lado. R6, como está.
-- Solo los que están a menos de CERCA studs de la cámara.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PosturaVista = require(script.Parent.PosturaVista)
local TrabajoVista = require(script.Parent.TrabajoVista)

local BrazosVista = {}

local jugador = Players.LocalPlayer
local camara = workspace.CurrentCamera
local CERCA = 120
local SUAVE = 10 -- lo deprisa que gira el hombro hacia su objetivo
local ABAJO = Vector3.new(0, -1, 0) -- hacia donde cuelga el brazo en el espacio del hombro
local INCLINA = math.rad(18) -- agachado, el tronco hacia delante
local LADEO = 1.6 -- asomado, el tronco se ladea esto por los grados de Config.Postura.Giro (la cabeza va más de lado)
local MEDIR = 0.1 -- s entre dos medidas de lo que ha bajado un agachado y de lo que tiene encima
local CABEZA_LIBRE = 0.1 -- studs que deja la coronilla bajo lo de arriba al encorvarse
local ENCORVA = math.rad(70) -- lo más que se encorva debajo de algo
local LEVANTA = 0.7 -- radianes que, como mucho, levanta la cabeza para seguir mirando al frente encorvado

type Hombro = { motor: Motor6D, original: CFrame, giro: CFrame }
type Gesto = { hasta: number, der: Vector3?, izq: Vector3? }
type Junta = { motor: Motor6D, original: CFrame }
type Pierna = { cadera: Junta, rodilla: Junta, tobillo: Junta?, muslo: number, pierna: number }
type Postura = {
	cintura: Junta?,
	cuello: Junta?, -- (solo para medir el tronco: la cabeza la gira cabecear)
	cabeza: BasePart?,
	piernas: { Pierna },
	largo: number, -- de la cadera al tobillo de la pierna más corta: lo más que se puede doblar
	tronco: number, -- de la cintura a la coronilla con el tronco derecho (0 si no se sabe)
	baja: number, -- studs que ha bajado su raíz respecto a de pie (suave)
	bajaMeta: number, -- lo medido
	techo: number, -- radianes que se encorva para caber debajo de algo (suave)
	techoMeta: number, -- lo medido
	medido: number, -- cuándo se midió (os.clock)
	t: number, -- 0..1: cuánto está agachado (suave)
	lado: number, -- -1..1: cuánto está asomado (suave)
	quieta: boolean, -- todo como lo dejan sus animaciones (no se toca)
	fija: boolean, -- ya ha llegado a su postura y está escrita: no se reescribe cada fotograma
}
type Otro = {
	personaje: Model,
	der: Hombro?,
	izq: Hombro?,
	cuello: Hombro?,
	gesto: Gesto?,
	linterna: { BasePart }?,
	postura: Postura?,
	reintento: number, -- sin postura (le faltaba alguna junta al llegar): cuándo se vuelve a buscar
}
local otros: { [Player]: Otro } = {}
local ponerLinterna: (o: Otro, encendida: boolean) -> () -- más abajo
local miradaDe: (otro: Player) -> number -- más abajo

local function hombroDe(personaje: Model, pieza: string, nombre: string): Hombro?
	local brazo = personaje:FindFirstChild(pieza)
	local motor = brazo and brazo:FindFirstChild(nombre)
	if motor and motor:IsA("Motor6D") then
		return { motor = motor, original = motor.C0, giro = CFrame.new() }
	end
	return nil
end

local function juntaDe(personaje: Model, pieza: string, nombre: string): Junta?
	local parte = personaje:FindFirstChild(pieza)
	local motor = parte and parte:FindFirstChild(nombre)
	if motor and motor:IsA("Motor6D") then
		return { motor = motor, original = motor.C0 }
	end
	return nil
end

-- Lo que miden los huesos de las piernas y del tronco y cómo están las juntas ahora (sin tocar): al preparar y cada
-- vez que se agacha o se asoma (por si el avatar ha cambiado de tamaño). false si algo no tiene sentido.
local function medir(p: Postura): boolean
	if p.cintura then
		p.cintura.original = p.cintura.motor.C0
	end
	local corta, hueso = math.huge, math.huge
	for _, pierna in p.piernas do
		pierna.cadera.original = pierna.cadera.motor.C0
		pierna.rodilla.original = pierna.rodilla.motor.C0
		if pierna.tobillo then
			pierna.tobillo.original = pierna.tobillo.motor.C0
		end
		-- De la cadera a la rodilla, en el muslo; de la rodilla al tobillo, en la pierna.
		pierna.muslo = (pierna.rodilla.motor.C0.Position - pierna.cadera.motor.C1.Position).Magnitude
		pierna.pierna = if pierna.tobillo
			then (pierna.tobillo.motor.C0.Position - pierna.rodilla.motor.C1.Position).Magnitude
			else pierna.muslo
		corta = math.min(corta, pierna.muslo + pierna.pierna)
		hueso = math.min(hueso, pierna.muslo, pierna.pierna)
	end
	p.largo = corta
	-- De la cintura a la coronilla, derecho: el cuello sobre la cintura (los dos en el UpperTorso), el centro de la
	-- cabeza sobre el cuello (en la cabeza) y media cabeza.
	local cintura, cuello, cabeza = p.cintura, p.cuello, p.cabeza
	p.tronco = if cintura and cuello and cabeza
		then (cuello.motor.C0.Position - cintura.motor.C1.Position).Y - cuello.motor.C1.Position.Y + cabeza.Size.Y / 2
		else 0
	return hueso > 0.05 and corta < math.huge -- un hueso de largo 0 daría NaN en los ángulos
end

-- Las juntas de agacharse y asomarse (R15). nil si falta alguna: se queda sin postura.
local function prepararPostura(personaje: Model): Postura?
	if not juntaDe(personaje, "LowerTorso", "Root") then
		return nil
	end
	local piernas = {}
	for _, lado in { "Left", "Right" } do
		local cadera = juntaDe(personaje, lado .. "UpperLeg", lado .. "Hip")
		local rodilla = juntaDe(personaje, lado .. "LowerLeg", lado .. "Knee")
		if not cadera or not rodilla then
			return nil
		end
		table.insert(piernas, {
			cadera = cadera,
			rodilla = rodilla,
			tobillo = juntaDe(personaje, lado .. "Foot", lado .. "Ankle"),
			muslo = 0,
			pierna = 0,
		})
	end
	local cabeza = personaje:FindFirstChild("Head")
	local p: Postura = {
		cintura = juntaDe(personaje, "UpperTorso", "Waist"),
		cuello = juntaDe(personaje, "Head", "Neck"),
		cabeza = if cabeza and cabeza:IsA("BasePart") then cabeza else nil,
		piernas = piernas,
		largo = 0,
		tronco = 0,
		baja = 0,
		bajaMeta = 0,
		techo = 0,
		techoMeta = 0,
		medido = -math.huge,
		t = 0,
		lado = 0,
		quieta = true,
		fija = false,
	}
	return if medir(p) then p else nil
end

local function preparar(otro: Player, personaje: Model)
	task.spawn(function()
		personaje:WaitForChild("RightUpperArm", 10)
		personaje:WaitForChild("LeftUpperArm", 10)
		local der = personaje:FindFirstChild("RightUpperArm") and personaje.RightUpperArm:WaitForChild("RightShoulder", 5)
		local izq = personaje:FindFirstChild("LeftUpperArm") and personaje.LeftUpperArm:WaitForChild("LeftShoulder", 5)
		if otro.Character ~= personaje or not der or not izq then
			return -- R6 o sin brazos: se quedan con sus animaciones
		end
		otros[otro] = {
			personaje = personaje,
			der = hombroDe(personaje, "RightUpperArm", "RightShoulder"),
			izq = hombroDe(personaje, "LeftUpperArm", "LeftShoulder"),
			cuello = hombroDe(personaje, "Head", "Neck"),
			gesto = nil,
			postura = prepararPostura(personaje),
			reintento = 0,
		}
	end)
end

local function alEntrar(otro: Player)
	if otro == jugador then
		return
	end
	otro.CharacterAdded:Connect(function(personaje)
		local viejo = otros[otro]
		if viejo then
			ponerLinterna(viejo, false)
		end
		otros[otro] = nil
		preparar(otro, personaje)
	end)
	if otro.Character then
		preparar(otro, otro.Character)
	end
end

local function raizDe(otro: Player): BasePart?
	local o = otros[otro]
	return o and o.personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Un gesto corto de otro: sus brazos hacia esos puntos unos segundos.
local function gesto(otro: Player, segundos: number, der: Vector3?, izq: Vector3?)
	local o = otros[otro]
	if o then
		o.gesto = { hasta = os.clock() + segundos, der = der, izq = izq }
	end
end

-- El otro jugador más cerca de `punto` (a menos de `radio`), si está más cerca que tú: ha sido él.
local function quienJunto(punto: Vector3, radio: number): Player?
	local mejor, distancia = nil, radio
	for otro in otros do
		local raiz = raizDe(otro)
		if raiz then
			local d = (raiz.Position - punto).Magnitude
			if d < distancia then
				mejor, distancia = otro, d
			end
		end
	end
	local mia = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if mejor and mia and (mia.Position - punto).Magnitude < distancia then
		return nil
	end
	return mejor
end

local function vigilarVentana(el: Instance)
	el:GetAttributeChangedSignal("Persiana"):Connect(function()
		local centro = el:GetAttribute("Centro")
		if typeof(centro) ~= "CFrame" then
			return
		end
		local quien = quienJunto(centro.Position, Config.Casa.Alcance + 2)
		if quien then
			local ancho = el:GetAttribute("Ancho") or 4
			gesto(quien, Config.Casa.TiempoPersiana, (centro * CFrame.new(ancho / 3, 0, 1)).Position,
				(centro * CFrame.new(-ancho / 3, 0, 1)).Position)
		end
	end)
end

local function vigilarPuerta(el: Instance)
	el:GetAttributeChangedSignal("Abierta"):Connect(function()
		local pomo = el:FindFirstChild("Pomo")
		if pomo and pomo:IsA("BasePart") then
			local quien = quienJunto(pomo.Position, Config.Casa.Alcance + 2)
			if quien then
				gesto(quien, 0.6, pomo.Position, nil)
			end
		end
	end)
end

-- Lo pesado que lleva otro: el de su tipo más cerca de él. Se recuerda y solo se vuelve a buscar entre todas las
-- piezas cada 0,3 s si ya no vale.
local pesados: { [Player]: { pieza: BasePart?, buscado: number } } = setmetatable({}, { __mode = "k" }) :: any
local function pesadoDe(otro: Player, raiz: BasePart): BasePart?
	local tipo = otro:GetAttribute("Cargando")
	if type(tipo) ~= "string" then
		pesados[otro] = nil
		return nil
	end
	local guardado = pesados[otro]
	local antes = guardado and guardado.pieza
	if antes and antes.Parent and antes:GetAttribute("Tipo") == tipo and (antes.Position - raiz.Position).Magnitude < 8 then
		return antes
	end
	if guardado and os.clock() - guardado.buscado < 0.3 then
		return nil
	end
	local mejor, distancia = nil, 8
	for _, p in CollectionService:GetTagged("Pesado") do
		if p:IsA("BasePart") and p:GetAttribute("Tipo") == tipo then
			local d = (p.Position - raiz.Position).Magnitude
			if d < distancia then
				mejor, distancia = p, d
			end
		end
	end
	pesados[otro] = { pieza = mejor, buscado = os.clock() }
	return mejor
end

-- Hacia dónde apunta cada brazo de otro ahora (nil = como lo dejan sus animaciones).
local function objetivos(otro: Player, o: Otro, raiz: BasePart): (Vector3?, Vector3?)
	local cf = raiz.CFrame
	local agarre, accion = TrabajoVista.agarreDe(otro)
	if agarre then
		local izq = if accion == "Hachazo" then (agarre * CFrame.new(0, 0.7, 0)).Position else nil
		return agarre.Position, izq
	end
	local pesado = pesadoDe(otro, raiz)
	if pesado then
		return pesado.Position + cf.RightVector * (pesado.Size.Magnitude * 0.2),
			pesado.Position - cf.RightVector * (pesado.Size.Magnitude * 0.2)
	end
	local g = o.gesto
	if g then
		if os.clock() < g.hasta then
			return g.der, g.izq
		end
		o.gesto = nil
	end
	-- Lo de su cuerpo (el móvil, la linterna): agachado, su raíz ya está más abajo de verdad y esto baja con ella.
	local der = if otro:GetAttribute("MovilAbierto") then (cf * CFrame.new(0.3, 0.9, -1.6)).Position else nil
	-- La linterna, hacia donde mira (arriba o abajo: atributo Mirada).
	local izq = if otro:GetAttribute("Linterna")
		then (cf * CFrame.new(-0.3, 1.4, 0) * CFrame.Angles(miradaDe(otro), 0, 0) * CFrame.new(0, 0, -5)).Position
		else nil
	return der, izq
end

-- La linterna que se le ve en la mano izquierda mientras la lleva encendida (la luz la pone EquipoVista en esa mano).
local LINTERNA = { -- { tamaño, sitio respecto a la mano (el brazo baja por su -Y), color }
	{ Vector3.new(0.75, 0.18, 0.18), CFrame.new(0, -0.25, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(52, 52, 55) },
	{ Vector3.new(0.22, 0.28, 0.28), CFrame.new(0, -0.62, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(52, 52, 55) },
}
function ponerLinterna(o: Otro, encendida: boolean)
	local mano = o.personaje:FindFirstChild("LeftHand") :: BasePart?
	if encendida and mano then
		if not o.linterna then
			local partes = {}
			for _, d in LINTERNA do
				local p = Instance.new("Part")
				p.Name = "LinternaOtro"
				p.Shape = Enum.PartType.Cylinder
				p.Size = d[1]
				p.Color = d[3]
				p.Material = Enum.Material.Metal
				p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
				p.Parent = camara
				table.insert(partes, p)
			end
			o.linterna = partes
		end
		for i, p in o.linterna :: { BasePart } do
			p.CFrame = mano.CFrame * LINTERNA[i][2]
		end
	elseif o.linterna then
		for _, p in o.linterna do
			p:Destroy()
		end
		o.linterna = nil
	end
end

function miradaDe(otro: Player): number
	local m = otro:GetAttribute("Mirada")
	return if type(m) == "number" and m == m then math.clamp(m, -1.4, 1.4) else 0
end

-- La cabeza de otro, inclinada hacia donde mira (sin pasarse: el cuello no dobla tanto). `levanta`: lo que tiene que
-- subir de más porque el tronco va hacia delante (agachado), para que siga mirando a donde mira.
local function cabecear(o: Otro, inclinacion: number, levanta: number, dt: number)
	local h = o.cuello
	if not h or not h.motor.Parent then
		return
	end
	local destino = CFrame.Angles(math.clamp(inclinacion * 0.75, -0.9, 0.9) + levanta, 0, 0)
	h.giro = h.giro:Lerp(destino, 1 - math.exp(-dt * SUAVE))
	h.motor.C0 = h.original * h.giro
end

local function girar(h: Hombro?, hacia: Vector3?, dt: number)
	if not h then
		return
	end
	local motor = h.motor
	local torso = motor.Part0
	if not motor.Parent or not torso then
		return
	end
	local destino = CFrame.new()
	if hacia then
		local junta = torso.CFrame * h.original
		local dir = junta:VectorToObjectSpace(hacia - junta.Position)
		if dir.Magnitude > 0.2 then
			dir = dir.Unit
			if dir:Dot(ABAJO) > -0.98 then -- justo hacia arriba la rotación no está definida
				destino = CFrame.fromRotationBetweenVectors(ABAJO, dir)
			end
		end
	end
	h.giro = h.giro:Lerp(destino, 1 - math.exp(-dt * SUAVE))
	local quieto = not hacia and h.giro.Position.Magnitude < 1e-4
		and math.abs(select(2, h.giro:ToAxisAngle())) < 0.01
	motor.C0 = if quieto then h.original else h.original * h.giro
	if quieto then
		h.giro = CFrame.new()
	end
end

-- El sitio de una junta girada `giro` (en el espacio de su Part0) alrededor de su punto.
local function girada(original: CFrame, giro: CFrame): CFrame
	return CFrame.new(original.Position) * giro * original.Rotation
end

-- Todo como lo dejan sus animaciones.
local function soltarPostura(p: Postura)
	if p.cintura then
		p.cintura.motor.C0 = p.cintura.original
	end
	for _, pierna in p.piernas do
		pierna.cadera.motor.C0 = pierna.cadera.original
		pierna.rodilla.motor.C0 = pierna.rodilla.original
		if pierna.tobillo then
			pierna.tobillo.motor.C0 = pierna.tobillo.original
		end
	end
	p.t, p.lado, p.baja, p.bajaMeta, p.techo, p.techoMeta = 0, 0, 0, 0, 0, 0
	p.quieta, p.fija = true, false
end

-- Lo que de verdad ha bajado su raíz respecto a de pie (un rayo al suelo) y, si tiene algo encima, lo que tiene que
-- encorvarse para que la cabeza quepa (un rayo hacia arriba desde la cintura). De pie, su raíz va a HipHeight y medio
-- alto sobre el suelo: el HipHeight que se ve aquí es el del servidor (el que baja su cliente no se replica).
local suelo = RaycastParams.new()
suelo.FilterType = Enum.RaycastFilterType.Exclude
suelo.RespectCanCollide = true
local function medirCuerpo(o: Otro, p: Postura, raiz: BasePart)
	p.medido = os.clock()
	local hum = o.personaje:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	suelo.FilterDescendantsInstances = { o.personaje, camara }
	local dePie = hum.HipHeight + raiz.Size.Y / 2
	local abajo = workspace:Raycast(raiz.Position, Vector3.new(0, -(dePie + 1), 0), suelo)
	p.bajaMeta = if abajo then math.clamp(dePie - (raiz.Position.Y - abajo.Position.Y), 0, p.largo) else 0
	p.techoMeta = 0
	local cintura = p.cintura
	local torso = cintura and cintura.motor.Part0
	if cintura and torso and p.tronco > 0 and p.bajaMeta > 0.05 then
		local desde = (torso.CFrame * cintura.original).Position
		-- El tablero de un mueble (sus zonas Debajo: lo que choca de los muebles no se ve con rayos) o lo demás.
		local y = PosturaVista.techoDebajo(desde) or math.huge
		local encima = workspace:Raycast(desde, Vector3.new(0, p.tronco + CABEZA_LIBRE, 0), suelo)
		if encima then
			y = math.min(y, encima.Position.Y)
		end
		local cabe = y - CABEZA_LIBRE - desde.Y
		if cabe < p.tronco then
			p.techoMeta = math.min(ENCORVA, math.acos(math.clamp(cabe / p.tronco, -1, 1)))
		end
	end
end

-- Lo que va hacia delante el tronco: agachado, un poco; debajo de algo, lo que haga falta.
local function inclinacion(p: Postura): number
	return math.max(INCLINA * p.t, p.techo)
end

-- Agachado y asomado, suave hacia lo que publica el servidor (atributos Agachado y Asomado) y lo medido. Agachado,
-- cada pierna se dobla lo que ha bajado su raíz para que el tobillo siga donde estaba (dos huesos, como las manos): el
-- muslo va hacia delante, la pierna hacia atrás y el pie se queda plano. Todo encima de su animación de andar.
local function posar(p: Postura, agachado: boolean, asomado: number, dt: number)
	local meta = if agachado then 1 else 0
	-- Ya ha llegado: las juntas se escriben una última vez y luego no se tocan (su andar va aparte, en el Transform).
	local llegada = math.abs(meta - p.t) < 1e-3 and math.abs(asomado - p.lado) < 1e-3
		and math.abs(p.bajaMeta - p.baja) < 1e-3 and math.abs(p.techoMeta - p.techo) < 1e-3
	if llegada and (p.fija or p.quieta) then
		return
	end
	p.fija = llegada
	if llegada then
		p.t, p.lado, p.baja, p.techo = meta, asomado, p.bajaMeta, p.techoMeta
	else
		local k = 1 - math.exp(-dt * SUAVE)
		p.t += (meta - p.t) * k
		p.lado += (asomado - p.lado) * k
		p.baja += (p.bajaMeta - p.baja) * k
		p.techo += (p.techoMeta - p.techo) * k
	end
	if meta == 0 and asomado == 0 and p.t < 0.01 and math.abs(p.lado) < 0.01 and p.baja < 0.01 and p.techo < 0.01 then
		if not p.quieta then
			soltarPostura(p)
		end
		return
	end
	if p.quieta then
		if not medir(p) then
			p.t, p.lado, p.baja, p.techo = 0, 0, 0, 0 -- un avatar raro: se queda como está
			return
		end
		p.quieta = false
	end
	local baja = p.baja
	for _, pierna in p.piernas do
		local l1, l2 = pierna.muslo, pierna.pierna
		local h = math.clamp(l1 + l2 - baja, math.abs(l1 - l2) + 0.05, l1 + l2) -- de la cadera al tobillo
		local a = math.acos(math.clamp((l1 * l1 + h * h - l2 * l2) / (2 * l1 * h), -1, 1))
		local b = math.acos(math.clamp((l2 * l2 + h * h - l1 * l1) / (2 * l2 * h), -1, 1))
		pierna.cadera.motor.C0 = girada(pierna.cadera.original, CFrame.Angles(a, 0, 0))
		pierna.rodilla.motor.C0 = girada(pierna.rodilla.original, CFrame.Angles(-(a + b), 0, 0))
		if pierna.tobillo then
			pierna.tobillo.motor.C0 = girada(pierna.tobillo.original, CFrame.Angles(b, 0, 0))
		end
	end
	if p.cintura then
		-- A la derecha (lado 1), lo de arriba del tronco hacia su derecha.
		p.cintura.motor.C0 = girada(p.cintura.original,
			CFrame.Angles(-inclinacion(p), 0, -p.lado * math.rad(Config.Postura.Giro) * LADEO))
	end
end

local function paso(dt: number)
	local ojo = camara.CFrame.Position
	for otro, o in otros do
		if not otro.Parent or otro.Character ~= o.personaje then
			ponerLinterna(o, false)
			otros[otro] = nil
			continue
		end
		ponerLinterna(o, otro:GetAttribute("Linterna") == true and not otro:GetAttribute("Muerto"))
		local raiz = raizDe(otro)
		if not raiz then
			continue
		end
		local p = o.postura
		if (raiz.Position - ojo).Magnitude > CERCA or otro:GetAttribute("Muerto") or otro:GetAttribute("Escondido") then
			girar(o.der, nil, 1) -- lejos o fuera de juego: como estaban, sin gastar
			girar(o.izq, nil, 1)
			cabecear(o, 0, 0, 1)
			if p and not p.quieta then
				soltarPostura(p)
			end
			continue
		end
		local asomado = otro:GetAttribute("Asomado")
		local agachado = otro:GetAttribute("Agachado") == true
		asomado = if asomado == -1 or asomado == 1 then asomado else 0
		if not p and (agachado or asomado ~= 0) and os.clock() >= o.reintento then
			-- Le faltaba alguna junta al llegar (el mapa por partes): se vuelve a buscar, como mucho una vez por segundo.
			o.reintento = os.clock() + 1
			o.postura = prepararPostura(o.personaje)
			p = o.postura
		end
		if p then
			-- Lo de verdad bajado y lo que tiene encima, cada MEDIR s mientras está agachado o aún abajo.
			if agachado or p.bajaMeta > 0.05 then
				if os.clock() - p.medido >= MEDIR then
					medirCuerpo(o, p, raiz)
				end
			else
				p.bajaMeta, p.techoMeta = 0, 0
			end
			posar(p, agachado, asomado, dt)
		end
		cabecear(o, miradaDe(otro), if p then math.min(inclinacion(p), LEVANTA) else 0, dt)
		local der, izq = objetivos(otro, o, raiz)
		girar(o.der, der, dt)
		girar(o.izq, izq, dt)
	end
end

function BrazosVista.start()
	Players.PlayerAdded:Connect(alEntrar)
	for _, otro in Players:GetPlayers() do
		alEntrar(otro)
	end
	Players.PlayerRemoving:Connect(function(otro)
		local o = otros[otro]
		if o then
			ponerLinterna(o, false)
		end
		otros[otro] = nil
	end)
	for _, el in CollectionService:GetTagged("Ventana") do
		vigilarVentana(el)
	end
	CollectionService:GetInstanceAddedSignal("Ventana"):Connect(vigilarVentana)
	for _, el in CollectionService:GetTagged("Puerta") do
		vigilarPuerta(el)
	end
	CollectionService:GetInstanceAddedSignal("Puerta"):Connect(vigilarPuerta)
	-- Una foto: los dos brazos a la cara. Una bengala: el derecho hacia donde ha dado.
	Remotes.Flash.OnClientEvent:Connect(function(quien: Player)
		local raiz = quien ~= jugador and raizDe(quien)
		local o = otros[quien]
		if raiz and o then
			local cara = (raiz.CFrame * CFrame.new(0, 1.6, -1.2)).Position
			gesto(quien, 0.5, cara + raiz.CFrame.RightVector * 0.3, cara - raiz.CFrame.RightVector * 0.3)
		end
	end)
	Remotes.Bengala.OnClientEvent:Connect(function(quien: Player, _desde: Vector3, impacto: Vector3)
		if quien ~= jugador and typeof(impacto) == "Vector3" then
			gesto(quien, 0.6, impacto, nil)
		end
	end)
	RunService.RenderStepped:Connect(paso)
end

return BrazosVista
