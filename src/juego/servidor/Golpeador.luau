-- El Golpeador: sale del bosque, se planta delante de una ventana o de la puerta y golpea.
--   Persiana bajada o puerta cerrada: le quita vida hasta cansarse (o romperla). Cristal al descubierto: lo agrieta
--   y al romperlo entra. Si le abren mientras golpea, entra (reglas en shared/Defensa).
--   Dentro ruge unos segundos (tiempo para esconderse) y caza: persigue a quien ve, va a donde le vio por última vez
--   y si no, ronda por las salas. Si te vio esconderte, te saca. Luego se va por donde entró.
--   Fuera, de noche, persigue a quien vea en el bosque.
-- Es un Humanoid del servidor (se mueve suave en los clientes); el cliente le anima las piernas y brazos
-- (GolpeadorVista) y oye los golpes con el remote Golpeador.
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Casa = require(script.Parent.Casa)
local Mapa = require(script.Parent.Mapa)
local Muerte = require(script.Parent.Muerte)

local Golpeador = {}

local G = Config.Golpeador
local ALTURA = 5 -- de los pies al centro de la raíz
local azar = Random.new()

local carpeta: Folder
local modelo: Model?
local raiz: BasePart
local humanoide: Humanoid
local hilo: thread?
local objetivo: Model?
local prisa = false -- amanece: deja lo que esté haciendo y se va
local vistoEn: { [Player]: number } = {} -- última vez (os.clock) que vio a cada jugador

local camino = PathfindingService:CreatePath({
	AgentRadius = 1.6,
	AgentHeight = 8,
	AgentCanJump = false,
	WaypointSpacing = 4,
})

local function rango(r: { number }): number
	return azar:NextNumber(r[1], r[2])
end

local function plano(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function dentroDeCasa(p: Vector3): boolean
	return math.abs(p.X) < 27 and math.abs(p.Z) < 23
end

-- Pieza del cuerpo unida a la raíz con un Motor6D (el cliente mueve su Transform).
local function miembro(nombre: string, tamano: Vector3, articulacion: Vector3, desde: Vector3, color: Color3): BasePart
	local p = Instance.new("Part")
	p.Name = nombre
	p.Size = tamano
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.Massless = true
	p.CFrame = raiz.CFrame * CFrame.new(articulacion) * CFrame.new(-desde)
	p.Parent = modelo
	local motor = Instance.new("Motor6D")
	motor.Name = nombre
	motor.Part0 = raiz
	motor.Part1 = p
	motor.C0 = CFrame.new(articulacion)
	motor.C1 = CFrame.new(desde)
	motor.Parent = raiz
	return p
end

local function crearModelo(cf: CFrame)
	local m = Instance.new("Model")
	m.Name = "Golpeador"
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	modelo = m
	raiz = Instance.new("Part")
	raiz.Name = "HumanoidRootPart"
	raiz.Size = Vector3.new(3, 3, 1.5)
	raiz.Transparency = 1
	raiz.CFrame = cf
	raiz.Parent = m
	m.PrimaryPart = raiz

	local carne, palida = Color3.fromRGB(78, 52, 50), Color3.fromRGB(110, 92, 86)
	-- Encorvado: torso y cabeza adelantados; brazos larguísimos casi hasta el suelo.
	miembro("Torso", Vector3.new(3.2, 3.8, 1.8), Vector3.new(0, 0.2, 0), Vector3.new(0, -0.4, 0.3), carne)
	miembro("Cabeza", Vector3.new(1.7, 2.1, 1.7), Vector3.new(0, 2.3, -0.9), Vector3.new(0, -0.9, 0), palida)
	miembro("BrazoI", Vector3.new(0.8, 5.6, 0.8), Vector3.new(-2.1, 1.9, -0.4), Vector3.new(0, 2.6, 0), carne)
	miembro("BrazoD", Vector3.new(0.8, 5.6, 0.8), Vector3.new(2.1, 1.9, -0.4), Vector3.new(0, 2.6, 0), carne)
	miembro("PiernaI", Vector3.new(1.1, 3.6, 1.1), Vector3.new(-0.8, -1.5, 0), Vector3.new(0, 1.7, 0), carne)
	miembro("PiernaD", Vector3.new(1.1, 3.6, 1.1), Vector3.new(0.8, -1.5, 0), Vector3.new(0, 1.7, 0), carne)
	local cabeza = m:FindFirstChild("Cabeza") :: BasePart
	local boca = Instance.new("Part")
	boca.Name = "Boca"
	boca.Size = Vector3.new(0.35, 1.3, 0.1)
	boca.Color = Color3.fromRGB(70, 8, 8)
	boca.Material = Enum.Material.SmoothPlastic
	boca.CanCollide = false
	boca.CanQuery = false
	boca.Massless = true
	boca.CFrame = cabeza.CFrame * CFrame.new(0, -0.2, -0.86)
	local soldadura = Instance.new("WeldConstraint")
	soldadura.Part0 = cabeza
	soldadura.Part1 = boca
	soldadura.Parent = boca
	boca.Parent = m

	humanoide = Instance.new("Humanoid")
	humanoide.HipHeight = ALTURA - raiz.Size.Y / 2
	humanoide.WalkSpeed = G.Andar
	humanoide.MaxHealth = 1e9
	humanoide.Health = 1e9
	humanoide.BreakJointsOnDeath = false
	humanoide.RequiresNeck = false
	humanoide.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoide.Parent = m
	m.Parent = carpeta
	raiz:SetNetworkOwner(nil)
end

local function cabeza(): Vector3
	local c = modelo and modelo:FindFirstChild("Cabeza") :: BasePart?
	return if c then c.Position else raiz.Position + Vector3.new(0, 3, 0)
end

-- Abre de un golpe las puertas cerradas que tenga delante.
local function abrirPuertasCerca()
	for _, puerta in Casa.puertas() do
		local hoja = puerta:FindFirstChild("Hoja") :: BasePart
		local d = hoja.Position - raiz.Position
		if math.abs(d.Y) < 7 and plano(d).Magnitude < 5.5 and not Casa.estado(puerta).abierta then
			Casa.abrirPuerta(puerta)
		end
	end
end

-- Un paso hacia `destino` (a ras de suelo): recto si no hay nada en medio, si no, por el camino que calcula.
local filtroVista = RaycastParams.new()
filtroVista.FilterType = Enum.RaycastFilterType.Exclude

local function libre(desde: Vector3, hasta: Vector3, ignorar: { Instance }): boolean
	filtroVista.FilterDescendantsInstances = ignorar
	return workspace:Raycast(desde, hasta - desde, filtroVista) == nil
end

local function pasoHacia(destino: Vector3)
	abrirPuertasCerca()
	local suelo = raiz.Position - Vector3.new(0, ALTURA, 0)
	if math.abs(destino.Y - suelo.Y) < 3 and libre(raiz.Position, destino + Vector3.new(0, ALTURA, 0), { modelo :: Model, carpeta }) then
		humanoide:MoveTo(destino)
		return
	end
	local ok = pcall(function()
		camino:ComputeAsync(suelo, destino)
	end)
	if ok and camino.Status == Enum.PathStatus.Success then
		for i, punto in camino:GetWaypoints() do
			if i > 1 and (punto.Position - suelo).Magnitude > 3 then
				humanoide:MoveTo(punto.Position)
				return
			end
		end
	end
	humanoide:MoveTo(destino)
end

local function cerca(destino: Vector3, distancia: number): boolean
	local suelo = raiz.Position - Vector3.new(0, ALTURA, 0)
	return plano(destino - suelo).Magnitude < distancia and math.abs(destino.Y - suelo.Y) < 6
end

-- Anda hasta `destino` (o hasta `limite` segundos o hasta que `seguir` diga que no).
local function irA(destino: Vector3, velocidad: number, limite: number, seguir: (() -> boolean)?)
	humanoide.WalkSpeed = velocidad
	local hasta = os.clock() + limite
	while modelo and os.clock() < hasta and not cerca(destino, 3) do
		if seguir and not seguir() then
			return
		end
		pasoHacia(destino)
		task.wait(0.25)
	end
end

local function cabezaDe(jugador: Player): BasePart?
	local personaje = jugador.Character
	return personaje and personaje:FindFirstChild("Head") :: BasePart?
end

-- A quién va a por: el más cercano que ve (o que oye muy cerca), o el escondido al que vio esconderse.
-- Devuelve el jugador y a dónde ir.
local function elegirPresa(soloFuera: boolean): (Player?, Vector3?)
	local ahora = os.clock()
	local mejor, destino, mejorDistancia = nil, nil, math.huge
	local ojos = cabeza()
	for _, jugador in Muerte.vivos() do
		local sitio, hora = Muerte.escondite(jugador)
		local suCabeza = cabezaDe(jugador)
		if sitio then
			if hora and vistoEn[jugador] and hora - vistoEn[jugador] <= G.VioEsconderse and not soloFuera then
				local salida = (sitio:GetAttribute("Salida") :: CFrame).Position - Vector3.new(0, 3, 0)
				local d = (salida - raiz.Position).Magnitude
				if d < mejorDistancia then
					mejor, destino, mejorDistancia = jugador, salida, d
				end
			end
		elseif suCabeza and not (soloFuera and dentroDeCasa(suCabeza.Position)) then
			local d = (suCabeza.Position - ojos).Magnitude
			local loVe = d < G.Vista and libre(ojos, suCabeza.Position, { modelo :: Model, jugador.Character :: Model, carpeta })
			if loVe or d < 8 then
				vistoEn[jugador] = ahora
				if d < mejorDistancia then
					local pies = suCabeza.Position - Vector3.new(0, 4.5, 0)
					mejor, destino, mejorDistancia = jugador, pies, d
				end
			end
		end
	end
	return mejor, destino
end

-- Caza durante `duracion` segundos. `soloFuera`: en el bosque, solo a los que están fuera de la casa.
local function cazar(duracion: number, soloFuera: boolean)
	local fin = os.clock() + duracion
	local ultimoVisto: Vector3? = nil
	local ronda: Vector3? = nil
	while modelo and os.clock() < fin and not prisa do
		local presa, destino = elegirPresa(soloFuera)
		if presa and destino then
			ultimoVisto = destino
			humanoide.WalkSpeed = G.Correr
			local escondido = Muerte.escondite(presa) ~= nil
			local suCabeza = cabezaDe(presa)
			local alcanza = if escondido or not suCabeza then cerca(destino, 5)
				else (suCabeza.Position - raiz.Position).Magnitude < G.Pillar
			if alcanza then
				humanoide:MoveTo(raiz.Position)
				Muerte.matar(presa, cabeza())
				task.wait(2.5)
				ultimoVisto = nil
			else
				pasoHacia(destino)
			end
		elseif ultimoVisto then
			humanoide.WalkSpeed = G.Correr
			pasoHacia(ultimoVisto)
			if cerca(ultimoVisto, 4) then
				ultimoVisto = nil
			end
		elseif soloFuera then
			return -- en el bosque, si no ve a nadie, se olvida
		else
			humanoide.WalkSpeed = G.Andar
			if not ronda or cerca(ronda, 4) then
				ronda = Mapa.salas[azar:NextInteger(1, #Mapa.salas)]
			end
			pasoHacia(ronda :: Vector3)
		end
		task.wait(0.25)
	end
end

local function quitarModelo()
	if objetivo then
		Casa.terminarAtaque(objetivo)
		objetivo = nil
	end
	if modelo then
		modelo:Destroy()
		modelo = nil
	end
end

local function mirarA(punto: Vector3)
	raiz.CFrame = CFrame.lookAt(raiz.Position, Vector3.new(punto.X, raiz.Position.Y, punto.Z))
end

local function ataque(el: Model, noche: number)
	local centro = el:GetAttribute("Centro") :: CFrame
	local fuera = el:GetAttribute("Fuera") :: Vector3
	local dentro = el:GetAttribute("Dentro") :: Vector3
	local normal = plano(centro.LookVector).Unit
	local lado = normal:Cross(Vector3.yAxis)
	local inicio = fuera + normal * 75 + lado * azar:NextNumber(-25, 25)
	local lejos = fuera + normal * 110 + lado * azar:NextNumber(-40, 40)
	crearModelo(CFrame.lookAt(inicio + Vector3.new(0, ALTURA, 0), fuera + Vector3.new(0, ALTURA, 0)))
	local function noVeNadie()
		return not prisa and elegirPresa(true) == nil
	end

	-- Llega desde el bosque; si ve a alguien fuera, va a por él.
	irA(fuera, G.Andar, 30, noVeNadie)
	if not prisa and elegirPresa(true) then
		cazar(G.Caza / 2, true)
		irA(lejos, G.Andar, 25)
		return
	end

	-- Golpea hasta cansarse o hasta entrar.
	objetivo = el
	Casa.empezarAtaque(el)
	humanoide.AutoRotate = false
	mirarA(centro.Position)
	local finPaciencia = os.clock() + rango(G.Paciencia) + G.MasPaciencia * (noche - 1)
	local entra = false
	while os.clock() < finPaciencia and not prisa do
		task.wait(rango(G.CadaGolpe))
		if prisa then
			break
		end
		Remotes.Golpeador:FireAllClients("Golpe", el)
		task.wait(0.35) -- el brazo baja: el golpe suena al llegar
		if Casa.golpe(el, rango(G.Dano)) == "Entra" then
			entra = true
			break
		end
	end
	Casa.terminarAtaque(el)
	objetivo = nil
	humanoide.AutoRotate = true

	if entra then
		Casa.romper(el)
		Remotes.Golpeador:FireAllClients("Entra", el)
		task.wait(0.6)
		local pie = dentro + Vector3.new(0, ALTURA, 0)
		if modelo then
			modelo:PivotTo(CFrame.lookAt(pie, pie - normal))
		end
		task.wait(G.Grito)
		cazar(G.Caza, false)
		-- Se va por donde entró.
		irA(dentro, G.Andar, 25)
		local pieFuera = fuera + Vector3.new(0, ALTURA, 0)
		if modelo then
			modelo:PivotTo(CFrame.lookAt(pieFuera, pieFuera + normal))
		end
	end
	irA(lejos, G.Andar, 25)
end

-- ¿Está ahora en el mapa?
function Golpeador.activo(): boolean
	return modelo ~= nil
end

-- Empieza un ataque a esa ventana o puerta (vuelve enseguida; el ataque sigue solo).
function Golpeador.atacar(el: Model, noche: number)
	if modelo then
		return
	end
	prisa = false
	hilo = task.spawn(function()
		ataque(el, noche)
		quitarModelo()
		hilo = nil
	end)
end

-- Amanece: deja de golpear o cazar y se va andando.
function Golpeador.irse()
	prisa = true
end

-- Lo quita del mapa al momento (al volver a empezar el día).
function Golpeador.quitar()
	if hilo and coroutine.status(hilo) ~= "dead" then
		task.cancel(hilo)
	end
	hilo = nil
	quitarModelo()
end

function Golpeador.start()
	carpeta = Instance.new("Folder")
	carpeta.Name = "Bichos"
	carpeta.Parent = workspace
	Players.PlayerRemoving:Connect(function(jugador)
		vistoEn[jugador] = nil
	end)
end

return Golpeador
