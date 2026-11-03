-- Los brazos de los DEMÁS jugadores (tus manos en primera persona, en Manos): que en cooperativo se vea lo que hace
-- tu amigo (pedido por el usuario: "que todo esté animado y sea inmersivo"). Cada cliente mueve los hombros de los
-- otros personajes (R15) girando el C0 de su RightShoulder / LeftShoulder, encima de las animaciones de andar.
--   Con la herramienta (TrabajoVista): el brazo derecho (y el izquierdo con el hacha) hacia el mango, que va y viene.
--   Cargando algo pesado: los dos brazos a sus lados. Linterna encendida: el izquierdo delante, alumbrando.
--   Móvil abierto: el derecho delante, doblado. Una foto: los dos a la cara. Una bengala: el derecho hacia donde da.
--   Una cortina o una puerta que se mueve junto a él (y más cerca de él que de ti): los brazos hacia ella.
-- Solo los que están a menos de CERCA studs de la cámara.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local TrabajoVista = require(script.Parent.TrabajoVista)

local BrazosVista = {}

local jugador = Players.LocalPlayer
local camara = workspace.CurrentCamera
local CERCA = 120
local SUAVE = 10 -- lo deprisa que gira el hombro hacia su objetivo
local ABAJO = Vector3.new(0, -1, 0) -- hacia donde cuelga el brazo en el espacio del hombro

type Hombro = { motor: Motor6D, original: CFrame, giro: CFrame }
type Gesto = { hasta: number, der: Vector3?, izq: Vector3? }
type Otro = { personaje: Model, der: Hombro?, izq: Hombro?, gesto: Gesto? }
local otros: { [Player]: Otro } = {}

local function hombroDe(personaje: Model, pieza: string, nombre: string): Hombro?
	local brazo = personaje:FindFirstChild(pieza)
	local motor = brazo and brazo:FindFirstChild(nombre)
	if motor and motor:IsA("Motor6D") then
		return { motor = motor, original = motor.C0, giro = CFrame.new() }
	end
	return nil
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
			gesto = nil,
		}
	end)
end

local function alEntrar(otro: Player)
	if otro == jugador then
		return
	end
	otro.CharacterAdded:Connect(function(personaje)
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

-- Lo pesado que lleva otro: el de su tipo más cerca de él.
local function pesadoDe(otro: Player, raiz: BasePart): BasePart?
	local tipo = otro:GetAttribute("Cargando")
	if type(tipo) ~= "string" then
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
	local der = if otro:GetAttribute("MovilAbierto") then (cf * CFrame.new(0.3, 0.9, -1.6)).Position else nil
	local izq = if otro:GetAttribute("Linterna") then (cf * CFrame.new(-0.3, 1.2, -5)).Position else nil
	return der, izq
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

local function paso(dt: number)
	local ojo = camara.CFrame.Position
	for otro, o in otros do
		if not otro.Parent or otro.Character ~= o.personaje then
			otros[otro] = nil
			continue
		end
		local raiz = raizDe(otro)
		if not raiz then
			continue
		end
		if (raiz.Position - ojo).Magnitude > CERCA or otro:GetAttribute("Muerto") or otro:GetAttribute("Escondido") then
			girar(o.der, nil, 1) -- lejos o fuera de juego: como estaban, sin gastar
			girar(o.izq, nil, 1)
			continue
		end
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
		if raiz then
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
