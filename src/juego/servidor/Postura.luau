-- Agacharse y asomarse (14.6, pedido por el usuario: "cuerpo: agacharse (botón también en el móvil) y asomarse por las
-- esquinas"). Los bichos (Caza, Bestia) leen Agachado y Cubierto: agachado te ven y te oyen peor y, cubierto, te huelen.
--   El cliente (PosturaVista) pide con el remote Postura: ("Agachado", sí/no) o ("Asomar", -1 / 0 / 1). Aquí se valida
--   con shared/PosturaReglas (tipos, cada cuánto y si puede) y se publica en los atributos del jugador Agachado (true o
--   nil) y Asomado (-1, 1 o nil), que leen CuerpoVista (su cámara) y BrazosVista (los demás le ven agachado o asomado).
--   Al morir, esconderse, reaparecer, coger algo pesado o ponerse a trabajar (talar, serrar, clavar...) se quita sola;
--   asomarse, también al abrir la mochila.
--   Agachado anda a Config.Postura.Velocidad: Cargar.ajustarVelocidad lo mira y se le llama tras cada cambio.
-- Esconderse agachado (pedido por el usuario, 03-11-2026: "agacharte también debería servir para esconderte, por
-- ejemplo debajo de mesas... que sea útil agacharte es la finalidad"):
--   Cubierto (atributo del jugador, true o nil): agachado y con la raíz dentro de una zona "Debajo" (Part invisible con
--   esa etiqueta que pone Mapa en el hueco de cada mueble que lo tiene). Se mira cada CADA_CUBIERTO s, solo a los
--   agachados, y se quita con Agachado (al levantarse, morir, esconderse o reaparecer). Lo leen los bichos.
--   El grupo de colisión GRUPO_AGACHADO (no choca con nada) se registra aquí: PosturaVista mete en él tu cuerpo
--   agachado salvo la raíz, que encoge y choca baja (ver PosturaVista).
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local PosturaReglas = require(ReplicatedStorage.Shared.PosturaReglas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Cargar = require(script.Parent.Cargar)
local Muerte = require(script.Parent.Muerte)

local Postura = {}

local CADA_CUBIERTO = 0.2 -- s entre dos miradas a quién está debajo de algo
local GRUPO_AGACHADO = "Agachado" -- lo mismo en PosturaVista

local estados: { [Player]: PosturaReglas.Estado } = {}
local agachados: { [Player]: true } = {} -- los que tienen Agachado (los únicos que pueden estar Cubierto)
local debajos: { BasePart } = {} -- las zonas "Debajo" de los muebles

local function estadoDe(jugador: Player): PosturaReglas.Estado
	return estados[jugador] or PosturaReglas.nuevo()
end

local function datosDe(jugador: Player): PosturaReglas.Jugador
	return {
		vivo = table.find(Muerte.vivos(), jugador) ~= nil,
		escondido = jugador:GetAttribute("Escondido") ~= nil,
		cargando = jugador:GetAttribute("Cargando") ~= nil or jugador:GetAttribute("Trabajando") ~= nil,
		mochila = jugador:GetAttribute("MochilaAbierta") == true,
	}
end

local function cubrir(jugador: Player, cubierto: boolean)
	if (jugador:GetAttribute("Cubierto") == true) ~= cubierto then
		jugador:SetAttribute("Cubierto", if cubierto then true else nil)
	end
end

-- ¿Está este punto dentro de alguna zona Debajo? (cajas giradas: se mira en el espacio de cada una)
local function debajoDeAlgo(punto: Vector3): boolean
	for _, zona in debajos do
		local rel = zona.CFrame:PointToObjectSpace(punto)
		local medio = zona.Size / 2
		if math.abs(rel.X) <= medio.X and math.abs(rel.Y) <= medio.Y and math.abs(rel.Z) <= medio.Z then
			return true
		end
	end
	return false
end

local function mirarCubierto(jugador: Player)
	local personaje = jugador.Character
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart")
	cubrir(jugador, raiz ~= nil and raiz:IsA("BasePart") and debajoDeAlgo(raiz.Position))
end

local function publicar(jugador: Player, estado: PosturaReglas.Estado)
	estados[jugador] = estado
	jugador:SetAttribute("Agachado", if estado.agachado then true else nil)
	jugador:SetAttribute("Asomado", if estado.asomado ~= 0 then estado.asomado else nil)
	if estado.agachado then
		agachados[jugador] = true
		mirarCubierto(jugador)
	else
		agachados[jugador] = nil
		cubrir(jugador, false) -- de pie (o muerto, escondido, reaparecido): al descubierto
	end
	Cargar.ajustarVelocidad(jugador)
end

-- Lo que pide el cliente: cualquier cosa rara, muy seguida o fuera de juego se tira sin más.
local function pedir(jugador: Player, que: unknown, valor: unknown)
	if not PosturaReglas.valida(que, valor) then
		return -- lo que no es una petición ni se mira (que mandarlo a chorro no cueste nada)
	end
	local estado, ahora = estadoDe(jugador), os.clock()
	local actual: boolean | number = if que == "Agachado" then estado.agachado else estado.asomado
	if actual == valor or ahora - estado.ultimo < Config.Postura.Cada then
		return -- sin efecto o demasiado seguido: tampoco se miran sus datos (Muerte.vivos hace una lista)
	end
	local cambia, nuevo = PosturaReglas.pedir(estado, que, valor, ahora, datosDe(jugador))
	if cambia then
		publicar(jugador, nuevo)
	end
end

-- Lo que ya no puede ser (muerto, escondido, cargando; asomado con la mochila abierta), fuera.
local function revisar(jugador: Player)
	local cambia, nuevo = PosturaReglas.limpiar(estadoDe(jugador), datosDe(jugador))
	if cambia then
		publicar(jugador, nuevo)
	end
end

-- Al reaparecer, de pie (también lo que hubiera quedado publicado de antes).
local function quitar(jugador: Player)
	local estado = estadoDe(jugador)
	if estado.agachado or estado.asomado ~= 0 or jugador:GetAttribute("Agachado") ~= nil
		or jugador:GetAttribute("Asomado") ~= nil then
		publicar(jugador, PosturaReglas.quitar(estado))
	end
end

local function conPersonaje(jugador: Player, personaje: Model)
	local humanoide = personaje:WaitForChild("Humanoid", 10)
	if humanoide and humanoide:IsA("Humanoid") then
		humanoide.Died:Connect(function()
			revisar(jugador)
		end)
	end
end

local function alEntrar(jugador: Player)
	for _, atributo in { "Muerto", "Escondido", "Cargando", "Trabajando", "MochilaAbierta" } do
		jugador:GetAttributeChangedSignal(atributo):Connect(function()
			revisar(jugador)
		end)
	end
	jugador.CharacterAdded:Connect(function(personaje)
		quitar(jugador)
		conPersonaje(jugador, personaje)
	end)
	if jugador.Character then
		task.spawn(conPersonaje, jugador, jugador.Character)
	end
end

-- El grupo de colisión del cuerpo agachado: no choca con nada (con ninguno de los grupos que hay al arrancar: Default y
-- los de Cargar, que arranca antes). Un grupo que se registre después chocaría con él: habría que añadirlo aquí.
local function prepararGrupo()
	if not PhysicsService:IsCollisionGroupRegistered(GRUPO_AGACHADO) then
		PhysicsService:RegisterCollisionGroup(GRUPO_AGACHADO)
	end
	for _, grupo in PhysicsService:GetRegisteredCollisionGroups() do
		PhysicsService:CollisionGroupSetCollidable(GRUPO_AGACHADO, grupo.name, false)
	end
end

local function nuevaZona(zona: Instance)
	if zona:IsA("BasePart") and not table.find(debajos, zona) then
		table.insert(debajos, zona)
	end
end

function Postura.start()
	prepararGrupo()
	for _, zona in CollectionService:GetTagged("Debajo") do
		nuevaZona(zona)
	end
	CollectionService:GetInstanceAddedSignal("Debajo"):Connect(nuevaZona)
	CollectionService:GetInstanceRemovedSignal("Debajo"):Connect(function(zona)
		local i = table.find(debajos, zona :: any)
		if i then
			table.remove(debajos, i)
		end
	end)
	Players.PlayerAdded:Connect(alEntrar)
	for _, jugador in Players:GetPlayers() do
		alEntrar(jugador)
	end
	Players.PlayerRemoving:Connect(function(jugador)
		estados[jugador] = nil
		agachados[jugador] = nil
	end)
	Remotes.Postura.OnServerEvent:Connect(pedir)
	-- Debajo de algo o no: solo los agachados, cada CADA_CUBIERTO s (sin crear nada por vuelta).
	local espera = 0
	RunService.Heartbeat:Connect(function(dt)
		espera -= dt
		if espera > 0 or next(agachados) == nil then
			return
		end
		espera = CADA_CUBIERTO
		for jugador in agachados do
			mirarCubierto(jugador)
		end
	end)
end

return Postura
