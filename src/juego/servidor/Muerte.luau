-- Esconderse, morir y revivir.
-- Los personajes no reaparecen solos: quien muere mira a los demás hasta el amanecer (MuerteVista) y revive entonces
-- (o antes, si alguien paga por revivirle: Revivir).
-- Escondites (armarios y camas, etiqueta "Escondite"): el personaje se queda quieto dentro (anclado) y el cliente pone
-- la cámara en el atributo "Vista". Atributos del jugador: Escondido (la Vista de su escondite), Muerto.
-- Si mueren todos avisa a quien se haya apuntado con Muerte.alMorirTodos (Director vuelve al principio del día).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Muerte = {}

local escondidos: { [Player]: { sitio: Model, hora: number } } = {}
local oyentes: { () -> () } = {}

local function humanoideDe(jugador: Player): Humanoid?
	local personaje = jugador.Character
	return personaje and personaje:FindFirstChildOfClass("Humanoid")
end

local function vivo(jugador: Player): boolean
	local humanoide = humanoideDe(jugador)
	return humanoide ~= nil and humanoide.Health > 0 and not jugador:GetAttribute("Muerto")
end

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

local function esconder(jugador: Player, sitio: Model)
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

-- El bicho le pilla (también si estaba escondido y le ha sacado). `cabeza` = dónde está la cabeza del bicho.
function Muerte.matar(jugador: Player, cabeza: Vector3)
	if not vivo(jugador) then
		return
	end
	soltarSitio(jugador)
	jugador:SetAttribute("Muerto", true)
	Remotes.Muerte:FireAllClients(jugador, cabeza)
	local personaje = jugador.Character
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
	if raiz then
		raiz.Anchored = false
	end
	local humanoide = humanoideDe(jugador)
	if humanoide then
		humanoide.Health = 0
	end
	comprobarTodos()
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
				comprobarTodos()
			end
		end)
	end)
	jugador:LoadCharacter()
end

function Muerte.start()
	Players.CharacterAutoLoads = false
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
