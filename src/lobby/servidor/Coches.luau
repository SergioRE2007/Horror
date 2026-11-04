-- Coches del lobby: te subes con tus amigos, el dueño elige partida y arrancáis.
--   Cada coche (etiqueta "Coche", los pone Gasolinera) tiene Config.Coches.Plazas asientos. Prompt "Get in" (E): te
--   sienta en el primero libre; te bajas saltando. El primero que sube es el dueño: elige una de sus ranuras de
--   partida, si empieza de cero y arranca. Si el dueño se baja, pasa a ser dueño el siguiente que subió.
--   Atributos del coche: Dueno (UserId), Ranura, Nueva, Salida (hora del servidor a la que sale; nil = parado; tras
--   un viaje que sale bien vuelve a nil cuando el coche se vacía) y Llegada (hora del servidor a la que se para en su
--   plaza otro coche que llega por la carretera, tras un viaje: hasta entonces nadie se sube; luego vuelve a nil y el
--   coche queda libre). Lo que se ve, en el cliente: SalidaVista y LlegadaVista.
--   Por el carril delante de las plazas no van dos a la vez: si está llegando otro, la Salida es algo más tarde (la
--   cuenta atrás dura más) y una Llegada espera a que pase el que sale o el que llega antes.
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

-- Tras un viaje, el coche que llega (números a ojo; lo de los clientes tiene que cuadrar con esto).
local LLEGADA = 22 -- segundos que tarda en llegar desde la niebla (LlegadaVista.DURA: el mismo número)
local CERCA = 16 -- sus últimos segundos, cuando ya va por delante de las plazas (LlegadaVista.CERCA)
local SALE_CERCA = 6 -- segundos desde que arranca el que se va hasta que ha dejado atrás las plazas (SalidaVista)
local PAUSA = 2 -- segundos con la plaza vacía antes de que el otro empiece a llegar (entre la niebla, aún no se ve)
local MARGEN = 0.5 -- segundos entre dos coches por el carril

type Coche = { modelo: Model, asientos: { Seat }, orden: { Player }, prompt: ProximityPrompt, saliendo: boolean }
local coches: { Coche } = {}
-- Último cambio de Ranura o Nueva de cada jugador: como mucho uno cada 0,2 s (cada uno se replica a todos). Arrancar no
-- cuenta: solo vale una vez por salida y no se debe perder.
local ultimo: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any

local function avisar(jugadores: { Player }, texto: string)
	for _, jugador in jugadores do
		Remotes.Aviso:FireClient(jugador, Lang.t(jugador, texto))
	end
end

local function parar(c: Coche)
	c.modelo:SetAttribute("Salida", nil)
	c.saliendo = false
end

local function llegando(c: Coche): boolean
	local hora = c.modelo:GetAttribute("Llegada")
	return type(hora) == "number" and workspace:GetServerTimeNow() < hora
end

-- Cuándo va cada coche por el carril delante de las plazas: el que sale, de que arranca a SALE_CERCA s; el que llega,
-- sus últimos CERCA s. Devuelve dónde acaba el primero que pise [desde, hasta] (nil si no pisa ninguno).
local function pisa(desde: number, hasta: number, salvo: Coche): number?
	for _, o in coches do
		if o ~= salvo then
			local salida = o.modelo:GetAttribute("Salida")
			if type(salida) == "number" then
				local arranca = salida - Config.Coches.Salida
				if desde < arranca + SALE_CERCA and hasta > arranca then
					return arranca + SALE_CERCA
				end
			end
			local llegada = o.modelo:GetAttribute("Llegada")
			if type(llegada) == "number" and desde < llegada and hasta > llegada - CERCA then
				return llegada
			end
		end
	end
	return nil
end

-- La primera hora desde `desde` con el carril libre `dura` s.
local function libre(desde: number, dura: number, salvo: Coche): number
	local t = desde
	for _ = 1, 2 * #coches + 1 do
		local fin = pisa(t, t + dura, salvo)
		if not fin then
			break
		end
		t = fin + MARGEN
	end
	return t
end

-- El coche se ha ido de verdad (se han ido todos los que iban): otro llega por la carretera y hasta que se para en su
-- plaza nadie se sube.
local function volver(c: Coche)
	local llegada = libre(workspace:GetServerTimeNow() + PAUSA + LLEGADA - CERCA, CERCA, c) + CERCA
	c.modelo:SetAttribute("Llegada", llegada) -- antes de quitar Salida: el cliente se pasa el coche escondido sin verse
	parar(c)
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
		-- Mientras Viaje.ir espera, no (el nuevo dueño podía arrancar un segundo viaje a la vez), salvo con el coche
		-- vacío: el viaje ya se ha ido (o se han bajado todos) y llega otro coche.
		if c.saliendo and #c.orden == 0 then
			volver(c)
		elseif not c.saliendo then
			parar(c)
		end
	end
	c.prompt.Enabled = #c.orden < #c.asientos and not c.saliendo and not llegando(c)
end

local function subir(c: Coche, jugador: Player)
	local humanoide = jugador.Character and jugador.Character:FindFirstChildOfClass("Humanoid")
	if not humanoide or humanoide.Health <= 0 or humanoide.SeatPart or c.saliendo or llegando(c) then
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
	local ahora = workspace:GetServerTimeNow()
	local hora = libre(ahora, SALE_CERCA, c) + Config.Coches.Salida -- si está llegando otro, cuando se pare
	c.modelo:SetAttribute("Salida", hora)
	task.delay(hora - ahora, function()
		if c.modelo:GetAttribute("Salida") ~= hora or c.orden[1] ~= dueno then
			return -- se ha parado (el dueño se bajó)
		end
		c.saliendo = true
		c.prompt.Enabled = false
		local van = table.clone(c.orden)
		local ok, porque = Viaje.ir(van, dueno.UserId, c.modelo:GetAttribute("Ranura"), c.modelo:GetAttribute("Nueva"))
		if not ok then
			avisar(van, if porque == "studio" then "Teleport doesn't work in Studio." else "Couldn't start the game. Try again.")
			if c.modelo:GetAttribute("Salida") == hora then -- si se vació y ya va otro viaje, a ese no se le para
				parar(c)
			end
			rehacer(c)
		end
	end)
end

local function pedir(jugador: Player, que: unknown, valor: unknown)
	if que ~= "Arrancar" then
		local ahora = os.clock()
		if ahora - (ultimo[jugador] or -math.huge) < 0.2 then
			return
		end
		ultimo[jugador] = ahora
	end
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
	-- La llegada (también si alguien pone Llegada a mano, para probar): a la hora queda libre.
	modelo:GetAttributeChangedSignal("Llegada"):Connect(function()
		local hora = modelo:GetAttribute("Llegada")
		if type(hora) == "number" then
			task.delay(math.max(0, hora - workspace:GetServerTimeNow()), function()
				if modelo:GetAttribute("Llegada") == hora then
					modelo:SetAttribute("Llegada", nil)
				end
			end)
		end
		rehacer(c)
	end)
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
