-- Coches del lobby: te subes con tus amigos, el dueño elige partida y arrancáis.
--   Cada coche (etiqueta "Coche", los pone Gasolinera) tiene Config.Coches.Plazas asientos. Prompt "Get in" (E): te
--   sienta en el primero libre; te bajas saltando. El primero que sube es el dueño: elige una de sus ranuras de
--   partida, si empieza de cero y arranca. Si el dueño se baja, pasa a ser dueño el siguiente que subió.
--   Atributos del coche: Dueno (UserId), Ranura, Nueva, Salida (hora del servidor a la que sale; nil = parado).
--   Atributo del jugador: Coche (el nombre del coche en el que va).
--   Remote Coche: ("Ranura", n), ("Nueva", nueva) o ("Arrancar"), solo del dueño. A la hora, Viaje.ir los lleva.
-- La interfaz, en el cliente (CochesUi).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Stats = require(ReplicatedStorage.Shared.Stats)
local Viaje = require(ServerScriptService:WaitForChild("Comun").Viaje)

local Coches = {}

type Coche = { modelo: Model, asientos: { Seat }, orden: { Player }, prompt: ProximityPrompt, saliendo: boolean }
local coches: { Coche } = {}

local function avisar(jugadores: { Player }, texto: string)
	for _, jugador in jugadores do
		Remotes.Aviso:FireClient(jugador, Lang.t(jugador, texto))
	end
end

local function parar(c: Coche)
	c.modelo:SetAttribute("Salida", nil)
	c.saliendo = false
end

-- Rehace quién va en el coche (en el orden en que subieron) y quién es el dueño.
local function rehacer(c: Coche)
	local sentados = {}
	for _, asiento in c.asientos do
		local humanoide = asiento.Occupant
		local jugador = humanoide and Players:GetPlayerFromCharacter(humanoide.Parent)
		if jugador then
			sentados[jugador] = true
		end
	end
	for i = #c.orden, 1, -1 do
		local jugador = c.orden[i]
		if not sentados[jugador] then
			table.remove(c.orden, i)
			if jugador.Parent and jugador:GetAttribute("Coche") == c.modelo.Name then
				jugador:SetAttribute("Coche", nil)
			end
		end
	end
	for jugador in sentados do
		if not table.find(c.orden, jugador) then
			table.insert(c.orden, jugador)
			jugador:SetAttribute("Coche", c.modelo.Name)
		end
	end
	local dueno = c.orden[1]
	local id = if dueno then dueno.UserId else nil
	if c.modelo:GetAttribute("Dueno") ~= id then
		-- Dueño nuevo (o coche vacío): empieza a elegir de cero y no sale sin él.
		c.modelo:SetAttribute("Dueno", id)
		c.modelo:SetAttribute("Ranura", 1)
		c.modelo:SetAttribute("Nueva", false)
		parar(c)
	end
	c.prompt.Enabled = #c.orden < #c.asientos and not c.saliendo
end

local function subir(c: Coche, jugador: Player)
	local humanoide = jugador.Character and jugador.Character:FindFirstChildOfClass("Humanoid")
	if not humanoide or humanoide.Health <= 0 or humanoide.SeatPart or c.saliendo then
		return
	end
	for _, asiento in c.asientos do
		if not asiento.Occupant then
			asiento:Sit(humanoide)
			return
		end
	end
	Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "The car is full."))
end

local function arrancar(c: Coche)
	local dueno = c.orden[1]
	local hora = workspace:GetServerTimeNow() + Config.Coches.Salida
	c.modelo:SetAttribute("Salida", hora)
	task.delay(Config.Coches.Salida, function()
		if c.modelo:GetAttribute("Salida") ~= hora or c.orden[1] ~= dueno then
			return -- se ha parado (el dueño se bajó)
		end
		c.saliendo = true
		c.prompt.Enabled = false
		local van = table.clone(c.orden)
		local ok, porque = Viaje.ir(van, dueno.UserId, c.modelo:GetAttribute("Ranura"), c.modelo:GetAttribute("Nueva"))
		if not ok then
			avisar(van, if porque == "studio" then "Teleport doesn't work in Studio." else "Couldn't start the game. Try again.")
			parar(c)
			rehacer(c)
		end
	end)
end

local function pedir(jugador: Player, que: unknown, valor: unknown)
	for _, c in coches do
		if c.orden[1] ~= jugador or c.saliendo then
			continue
		end
		if que == "Ranura" and type(valor) == "number" and valor == math.floor(valor) and valor >= 1
			and valor <= Stats.ranuras(jugador) then
			c.modelo:SetAttribute("Ranura", valor)
			c.modelo:SetAttribute("Nueva", false)
		elseif que == "Nueva" and type(valor) == "boolean" then
			c.modelo:SetAttribute("Nueva", valor)
		elseif que == "Arrancar" and not c.modelo:GetAttribute("Salida") then
			arrancar(c)
		end
		return
	end
end

local function preparar(modelo: Model)
	local asientos = {}
	for i = 1, Config.Coches.Plazas do
		table.insert(asientos, modelo:WaitForChild(`Asiento{i}`) :: Seat)
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.ActionText = "Get in"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = modelo:WaitForChild("Carroceria")
	local c: Coche = { modelo = modelo, asientos = asientos, orden = {}, prompt = prompt, saliendo = false }
	table.insert(coches, c)
	prompt.Triggered:Connect(function(jugador)
		subir(c, jugador)
	end)
	for _, asiento in asientos do
		asiento:GetPropertyChangedSignal("Occupant"):Connect(function()
			rehacer(c)
		end)
	end
	rehacer(c)
end

function Coches.start()
	for _, modelo in CollectionService:GetTagged("Coche") do
		preparar(modelo)
	end
	Remotes.Coche.OnServerEvent:Connect(pedir)
	Players.PlayerRemoving:Connect(function()
		task.defer(function() -- el asiento se vacía solo; por si acaso, se rehacen todos
			for _, c in coches do
				rehacer(c)
			end
		end)
	end)
	-- Si el teletransporte falla al llegar, se avisa y el coche vuelve a estar parado.
	TeleportService.TeleportInitFailed:Connect(function(jugador)
		Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "Couldn't start the game. Try again."))
		for _, c in coches do
			if table.find(c.orden, jugador) and c.saliendo then
				parar(c)
				rehacer(c)
			end
		end
	end)
end

return Coches
