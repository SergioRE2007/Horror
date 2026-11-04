-- Esconderse, morir y revivir.
-- Los personajes no reaparecen solos: quien muere mira a los demás hasta el amanecer (MuerteVista) y revive entonces
-- (o antes, si alguien paga por revivirle: Revivir).
-- Escondites (armarios y camas, etiqueta "Escondite"): el personaje se queda quieto dentro (anclado) y el cliente pone
-- la cámara en el atributo "Vista". Atributos del jugador: Escondido (la Vista de su escondite), Muerto.
-- Si mueren todos avisa a quien se haya apuntado con Muerte.alMorirTodos (Director vuelve al principio del día); y a
-- cada muerte, a los de Muerte.alMorir (Caza olvida su olor), muera como muera.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Muerte = {}

local escondidos: { [Player]: { sitio: Model, hora: number } } = {}
local oyentes: { () -> () } = {}
local alMorirOyentes: { (Player) -> () } = {}

local function humanoideDe(jugador: Player): Humanoid?
	local personaje = jugador.Character
	return personaje and personaje:FindFirstChildOfClass("Humanoid")
end

local function vivo(jugador: Player): boolean
	local humanoide = humanoideDe(jugador)
	return humanoide ~= nil and humanoide.Health > 0 and not jugador:GetAttribute("Muerto")
end

-- ¿Está vivo (escondido incluido)? Lo mismo que mirar si está en Muerte.vivos(), sin hacer la lista.
Muerte.vivo = vivo

-- Jugadores vivos (escondidos incluidos).
function Muerte.vivos(): { Player }
	local lista = {}
	for _, jugador in Players:GetPlayers() do
		if vivo(jugador) then
			table.insert(lista, jugador)
		end
	end
	return lista
end

-- Dónde está escondido y desde cuándo (os.clock), o nil.
function Muerte.escondite(jugador: Player): (Model?, number?)
	local dato = escondidos[jugador]
	if dato then
		return dato.sitio, dato.hora
	end
	return nil, nil
end

local function soltarSitio(jugador: Player)
	local dato = escondidos[jugador]
	if not dato then
		return
	end
	escondidos[jugador] = nil
	dato.sitio:SetAttribute("Ocupado", 0)
	local prompt = dato.sitio:FindFirstChild("Mando") and dato.sitio.Mando:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = true
	end
	jugador:SetAttribute("Escondido", nil)
end

-- La escena de un final en marcha (Coche.huir, Incendio.terminar): nadie se esconde hasta que acaba. Mientras corre el
-- fuego del incendio (Final puesto, ~17 s antes de la escena) los bichos siguen cazando y sí se puede.
local enEscena = false

function Muerte.escena(activa: boolean)
	enEscena = activa
end

local function esconder(jugador: Player, sitio: Model)
	-- En la escena de un final no: te metía dentro en mitad de ella y al salir quedabas desanclado.
	if enEscena then
		return
	end
	local personaje = jugador.Character
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not raiz or not vivo(jugador) or escondidos[jugador] or sitio:GetAttribute("Ocupado") ~= 0 then
		return
	end
	if (raiz.Position - sitio.Mando.Position).Magnitude > Config.Casa.Alcance + 4 then
		return
	end
	escondidos[jugador] = { sitio = sitio, hora = os.clock() }
	sitio:SetAttribute("Ocupado", jugador.UserId)
	sitio.Mando:FindFirstChildOfClass("ProximityPrompt").Enabled = false
	raiz.Anchored = true
	personaje:PivotTo(sitio:GetAttribute("Dentro"))
	jugador:SetAttribute("Escondido", sitio:GetAttribute("Vista"))
end

Muerte.esconder = esconder -- también para el modo de pruebas (Director)

local function salir(jugador: Player)
	local dato = escondidos[jugador]
	if not dato then
		return
	end
	local personaje = jugador.Character
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
	soltarSitio(jugador)
	if raiz and personaje then
		personaje:PivotTo(dato.sitio:GetAttribute("Salida"))
		raiz.Anchored = false
	end
end

Muerte.sacar = salir -- también para los finales (Coche, Incendio): fuera del escondite antes de la escena

local function comprobarTodos()
	if #Players:GetPlayers() > 0 and #Muerte.vivos() == 0 then
		for _, fn in oyentes do
			task.spawn(fn)
		end
	end
end

function Muerte.alMorirTodos(fn: () -> ())
	table.insert(oyentes, fn)
end

-- `fn(jugador)` cada vez que alguien muere (le pille un bicho o muera de otra cosa), una sola vez por muerte.
function Muerte.alMorir(fn: (Player) -> ())
	table.insert(alMorirOyentes, fn)
end

-- Ya está Muerto: avisa a los de alMorir y mira si quedan vivos.
local function murio(jugador: Player)
	for _, fn in alMorirOyentes do
		task.spawn(fn, jugador)
	end
	comprobarTodos()
end

-- El bicho le pilla (también si estaba escondido y le ha sacado). `cabeza` = dónde está la cabeza del bicho; `modelo`,
-- el bicho que le pilla (la escena de muerte lo enfoca a él sin adivinar; sin él, MuerteVista busca el más cerca de
-- `cabeza`). false si ya estaba muerto (no pasa nada).
function Muerte.matar(jugador: Player, cabeza: Vector3, modelo: Model?): boolean
	if not vivo(jugador) then
		return false
	end
	soltarSitio(jugador)
	jugador:SetAttribute("Muerto", true)
	Remotes.Muerte:FireAllClients(jugador, cabeza, modelo)
	local personaje = jugador.Character
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
	if raiz then
		raiz.Anchored = false
	end
	local humanoide = humanoideDe(jugador)
	if humanoide then
		humanoide.Health = 0 -- Died ve Muerto puesto: no avisa otra vez
	end
	murio(jugador)
	return true
end

-- Al amanecer (o al volver a empezar el día) vuelven los que no tienen personaje o están muertos.
function Muerte.revivirTodos()
	for _, jugador in Players:GetPlayers() do
		Muerte.revivir(jugador)
	end
end

-- Vuelve ese, si está muerto (al amanecer, o de noche pagando: Revivir).
function Muerte.revivir(jugador: Player)
	if not vivo(jugador) then
		soltarSitio(jugador)
		jugador:SetAttribute("Muerto", nil)
		jugador.ReplicationFocus = nil
		task.spawn(jugador.LoadCharacter, jugador)
	end
end

local function prepararEscondite(sitio: Model)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.ActionText = "Hide"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = Config.Casa.Alcance
	prompt.RequiresLineOfSight = false
	prompt.Parent = sitio:WaitForChild("Mando")
	prompt.Triggered:Connect(function(jugador)
		esconder(jugador, sitio)
	end)
end

local function alEntrar(jugador: Player)
	jugador.CameraMode = Enum.CameraMode.LockFirstPerson -- en la partida siempre primera persona (pedido por el usuario)
	jugador.CharacterAdded:Connect(function(personaje)
		local humanoide = personaje:WaitForChild("Humanoid") :: Humanoid
		humanoide.Died:Connect(function()
			soltarSitio(jugador)
			if not jugador:GetAttribute("Muerto") then
				jugador:SetAttribute("Muerto", true)
				murio(jugador)
			end
		end)
	end)
	jugador:LoadCharacter()
end

-- De muerto, la cámara sigue a otro (MuerteVista): con el mapa por partes (StreamingEnabled, rendimiento.md) el
-- servidor manda el mapa alrededor de él y no del cuerpo. Sin el mapa por partes no cambia nada.
local function mirar(jugador: Player, objetivo: unknown)
	if not jugador:GetAttribute("Muerto") or typeof(objetivo) ~= "Instance" or not objetivo:IsA("Player")
		or objetivo.Parent ~= Players or objetivo == jugador or not vivo(objetivo) then
		return
	end
	local raiz = objetivo.Character and objetivo.Character:FindFirstChild("HumanoidRootPart")
	if raiz and raiz:IsA("BasePart") then
		jugador.ReplicationFocus = raiz
	end
end

function Muerte.start()
	Remotes.Mirar.OnServerEvent:Connect(mirar)
	Players.CharacterAutoLoads = false
	-- Primera persona también en StarterPlayer: en Studio el jugador salía con el CameraMode de StarterPlayer (14.4).
	StarterPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
	for _, sitio in CollectionService:GetTagged("Escondite") do
		prepararEscondite(sitio)
	end
	Remotes.Salir.OnServerEvent:Connect(salir)
	Players.PlayerAdded:Connect(alEntrar)
	for _, jugador in Players:GetPlayers() do
		task.spawn(alEntrar, jugador)
	end
	Players.PlayerRemoving:Connect(function(jugador)
		soltarSitio(jugador)
		task.defer(comprobarTodos)
	end)
end

return Muerte
