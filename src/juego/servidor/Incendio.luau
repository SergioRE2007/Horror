-- El final difícil (12.2, TASKS.md): con la Bestia encerrada en el sótano, se prende el rastro de gasolina desde el
-- porche y arde la casa con ella dentro.
--   Prompt "Light" (mantener E Config.Bestia.Prender s) en Preparativos.porche(); sale cuando el rastro está listo
--   (Preparativos.listo). Al prender: la Bestia atrapada, vivo, cerca y con cerillas en la mochila (se gasta una). Si
--   falta algo, aviso de una línea con lo primero que falta.
--   El fuego sale del porche, corre por el rastro y por Preparativos.puntos() en orden (uno cada Config.Bestia.PorSala s)
--   y por último llega al sótano: Bestia.quemar(). Desde ahí se come la casa entera (IncendioVista) y a los
--   Chillido + ARDE s empieza la escena final.
--   Luego, como la huida (Coche.huir): se quitan los bichos, la partida se da por terminada (alTerminar, antes del premio),
--   premio (Recompensas.finalBestia: monedas, logro e insignia), todos quietos y a salvo mientras los clientes ven la
--   escena final (IncendioVista) y vuelta al lobby.
-- Remote Incendio (servidor -> todos; el cliente no manda nada):
--   ("Prender", camino: { Vector3 }, porSala: number, inicio: number) el fuego sale de camino[1] (el porche) a la hora del
--     servidor `inicio` y llega a camino[i] a los (i - 1) * porSala s. El último punto es el sótano (donde está ella).
--   ("Final", segundos: number) la escena final.
--   ("Apagar") el fuego se ha cancelado antes del final (han muerto todos o ha amanecido).
-- Modo de pruebas: ServerStorage.Prueba:Fire("Quemar") lo prende ya, sin mirar nada (ni cerillas ni si está listo).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Prueba = require(ReplicatedStorage.Shared.Prueba)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Recompensas = require(ServerScriptService:WaitForChild("Comun").Recompensas)
local Viaje = require(ServerScriptService:WaitForChild("Comun").Viaje)
local Cargar = require(script.Parent.Cargar)
local Golpeador = require(script.Parent.Golpeador)
local Mochila = require(script.Parent.Mochila)
local Muerte = require(script.Parent.Muerte)
local Raspador = require(script.Parent.Raspador)

local Incendio = {}

local B = Config.Bestia
-- Centro del sótano (Mapa: sala x -12..12, z 47.6..65.6, suelo en y = -11), por si no se encuentra a la Bestia.
local SOTANO = Vector3.new(0, -8, 56)
-- Segundos que se ve la casa entera ardiendo (con su chillido dentro) antes de la escena final, para quien esté fuera:
-- el fuego aún se está comiendo el tejado y las ventanas de lejos (IncendioVista).
local ARDE = B.ArdeCasa

-- Bestia y Preparativos se cargan en start(): así no hay require en círculo si ellos usan Incendio.ardiendo().
local Bestia: any
local Preparativos: any
local ardiendo = false
local alTerminar: (() -> ())? = nil
local prompt: ProximityPrompt
local mensaje: { any }? = nil -- el ("Prender", ...) enviado, para quien entre con la casa ardiendo

local function cerca(jugador: Player, parte: BasePart): boolean
	local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return raiz ~= nil and table.find(Muerte.vivos(), jugador) ~= nil and not jugador:GetAttribute("Escondido")
		and (parte.Position - raiz.Position).Magnitude <= Config.Casa.Alcance + 4
end

-- Lo primero que falta para poder prender (frase en inglés para Lang) o nil si se puede.
local function queFalta(jugador: Player): string?
	if not Preparativos.listo() then
		return "The trail isn't ready yet."
	elseif not Bestia.atrapada() then
		return "It must be locked in the basement first."
	elseif Mochila.contar(jugador, "Cerillas") == 0 then
		return "You need matches."
	end
	return nil
end

-- La escena final: como Coche.huir. Todos (también los muertos) cobran y ven la escena.
local function terminar()
	Golpeador.quitar()
	Raspador.quitar()
	if alTerminar then
		local ok, fallo = pcall(alTerminar) -- que un fallo al guardar no deje sin premio ni escena
		if not ok then
			warn("[Incendio] alTerminar: " .. tostring(fallo))
		end
	end
	Recompensas.finalBestia(B.Cinematica)
	for _, j in Players:GetPlayers() do
		Cargar.soltar(j)
		local raiz = j.Character and j.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if raiz then
			raiz.Anchored = true -- quietos (y a salvo) mientras dura la escena
		end
	end
	Remotes.Incendio:FireAllClients("Final", B.Cinematica)
	task.wait(B.Cinematica + 2)
	Viaje.volver(Players:GetPlayers(), "The house burned with her inside.")
	for _, j in Players:GetPlayers() do -- en Studio no hay viaje: se puede seguir mirando
		local raiz = j.Character and j.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if raiz then
			raiz.Anchored = false
		end
	end
end

-- La cerilla al rastro. `forzado` (modo de pruebas): sin jugador ni comprobaciones.
local function prender(jugador: Player?, forzado: boolean?)
	if ardiendo or workspace:GetAttribute("Final") then -- un solo final: no a la vez que la huida en el coche
		return
	end
	local porche = Preparativos.porche() :: BasePart
	if not forzado then
		if not jugador or not cerca(jugador, porche) or jugador:GetAttribute("Trabajando") or jugador:GetAttribute("Cargando") then
			return
		end
		local falta = queFalta(jugador)
		if falta then
			Remotes.Aviso:FireClient(jugador, Lang.t(jugador, falta))
			return
		end
		if not Mochila.sacar(jugador, "Cerillas") then -- sin esperas desde que se miró: no se puede gastar dos veces
			return
		end
	end
	ardiendo = true
	workspace:SetAttribute("Final", true)
	prompt.Enabled = false

	-- Del porche por el rastro hasta el primer punto, luego los demás en orden y al final el sótano, donde está ella.
	local camino = { porche.Position }
	for _, punto in Preparativos.puntos() :: { BasePart } do
		table.insert(camino, punto.Position)
	end
	local modelo = Bestia.modelo() :: Model?
	table.insert(camino, if modelo and modelo.Parent then modelo:GetPivot().Position else SOTANO)
	mensaje = { "Prender", camino, B.PorSala, workspace:GetServerTimeNow() }
	Remotes.Incendio:FireAllClients(table.unpack(mensaje :: { any }))
	task.wait(B.PorSala * (#camino - 1))
	-- Mientras corría el fuego han muerto todos (se vuelve al amanecer) o ha amanecido y se ha ido: sin final ni premio.
	if not Bestia.atrapada() or #Muerte.vivos() == 0 then
		ardiendo = false
		workspace:SetAttribute("Final", nil)
		-- Que los clientes lo apaguen y que quien entre después no lo vea prender otra vez.
		mensaje = nil
		Remotes.Incendio:FireAllClients("Apagar")
		return
	end
	Bestia.quemar()
	task.wait(Config.Bestia.Chillido + ARDE) -- que se oiga su chillido y se vea arder la casa antes de la escena
	terminar()
end

-- Partida: qué hacer al terminar así (dar la partida por terminada con final = "Bestia" y guardarla).
function Incendio.alTerminar(fn: () -> ())
	alTerminar = fn
end

function Incendio.ardiendo(): boolean
	return ardiendo
end

function Incendio.start()
	Bestia = require(script.Parent.Bestia) :: any
	Preparativos = require(script.Parent.Preparativos) :: any

	prompt = Instance.new("ProximityPrompt")
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.ActionText = "Light"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = Config.Casa.Alcance
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = B.Prender
	prompt.Enabled = false
	prompt.Parent = Preparativos.porche()
	prompt.Triggered:Connect(function(jugador)
		prender(jugador)
	end)
	-- Solo sale con el rastro listo (Preparativos no avisa al cambiar: se mira cada segundo).
	task.spawn(function()
		while true do -- sigue tras un fuego cancelado (mueren todos o amanece y se vuelve a intentar)
			prompt.Enabled = not ardiendo and Preparativos.listo() == true
			task.wait(1)
		end
	end)
	Players.PlayerAdded:Connect(function(jugador)
		if mensaje then
			Remotes.Incendio:FireClient(jugador, table.unpack(mensaje))
		end
	end)

	if not Prueba.activa() then
		return
	end
	task.spawn(function() -- el BindableEvent lo crea Director, que arranca después
		ServerStorage:WaitForChild("Prueba").Event:Connect(function(que: string)
			if que == "Quemar" then
				task.spawn(prender, nil, true)
			end
		end)
	end)
end

return Incendio
