-- Generador del cobertizo (pedido por el usuario: arranca tirando de la cuerda). Sin gasolina no hay luz en la casa
-- ni enchufe.
--   Prompt E: tirar de la cuerda (no siempre arranca: Config.Generador.Arranca; al tercer tirón seguido, seguro) o
--   apagarlo. Con un bidón en las manos, R (Cargar.alUsar "Bidon"): echa su gasolina.
--   Gasta Deposito segundos de gasolina por depósito, más deprisa con más jugadores (Tareas de Config.Dificultad).
--   Atributos del modelo: Gasolina (0..1), Encendido, Tirones (cada tirón, para animar la cuerda), Ahogado (se ha
--   parado por falta de gasolina) y Llenando.
--   Las lámparas de la casa (Mapa.lamparas) se encienden con él, con un parpadeo al arrancar y al pararse.
-- Enchufe del cuarto de la limpieza: E deja ahí tu móvil (sale de la mochila) y se carga con el generador encendido;
-- se recoge como cualquier objeto, con su batería.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Dificultad = require(ReplicatedStorage.Shared.Dificultad)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Prueba = require(ReplicatedStorage.Shared.Prueba)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Cargar = require(script.Parent.Cargar)
local Mapa = require(script.Parent.Mapa)
local Mochila = require(script.Parent.Mochila)
local Muerte = require(script.Parent.Muerte)

local Generador = {}

local G = Config.Generador
local LAMPARA = { Color3.fromRGB(255, 214, 160), Color3.fromRGB(70, 66, 60) } -- encendida, apagada
local azar = Random.new()
local gen: Model
local prompt: ProximityPrompt
local gasolina = G.Inicio * G.Deposito -- segundos que le quedan
local encendido = false
local seguidos = 0 -- tirones seguidos sin arrancar
local ultimoTiron = -math.huge
local luces = 0 -- sube con cada cambio: un parpadeo viejo se para solo
local enchufe: Model
local promptEnchufe: ProximityPrompt
local enchufado: BasePart? = nil -- el móvil que se está cargando

local function publicar()
	gen:SetAttribute("Gasolina", gasolina / G.Deposito)
	gen:SetAttribute("Encendido", encendido)
	prompt.ActionText = if encendido then "Turn off" else "Pull the cord"
end

local function ponerLuces(encendidas: boolean)
	for _, lampara in Mapa.lamparas do
		lampara.Color = LAMPARA[if encendidas then 1 else 2]
		;(lampara:FindFirstChildOfClass("PointLight") :: PointLight).Enabled = encendidas
	end
end

-- Las luces tardan en asentarse: parpadean un poco antes de quedarse encendidas o apagadas.
local function cambiarLuces(encendidas: boolean)
	luces += 1
	local mio = luces
	task.spawn(function()
		for i = 1, 5 do
			ponerLuces(i % 2 == (if encendidas then 1 else 0))
			task.wait(azar:NextNumber(0.05, 0.18))
			if luces ~= mio then
				return
			end
		end
		ponerLuces(encendidas)
	end)
end

local function puede(jugador: Player, mando: BasePart): boolean
	local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not raiz or not table.find(Muerte.vivos(), jugador) then
		return false
	end
	for _, atributo in { "Escondido", "Cargando", "MochilaAbierta", "Trabajando" } do
		if jugador:GetAttribute(atributo) then
			return false
		end
	end
	return (mando.Position - raiz.Position).Magnitude <= Config.Casa.Alcance + 4
end

local function tirar(jugador: Player)
	if not puede(jugador, gen:FindFirstChild("Mando") :: BasePart) then
		return
	end
	if encendido then
		encendido = false
		cambiarLuces(false)
		publicar()
		return
	end
	local ahora = os.clock()
	if ahora - ultimoTiron < G.Tiron then
		return
	end
	ultimoTiron = ahora
	gen:SetAttribute("Tirones", (gen:GetAttribute("Tirones") or 0) + 1)
	if gasolina <= 0 then
		seguidos = 0
		Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "It has no fuel."))
		return
	end
	seguidos += 1
	if seguidos >= 3 or azar:NextNumber() < G.Arranca then
		seguidos = 0
		task.delay(0.4, function() -- después del tirón
			if gasolina > 0 and not encendido then
				encendido = true
				cambiarLuces(true)
				publicar()
			end
		end)
	end
end

-- Con más jugadores se gasta más (Tareas de la tabla de dificultad).
local function ritmo(): number
	local n = #Players:GetPlayers()
	if Prueba.activa() and Config.Test.Jugadores then
		n = Config.Test.Jugadores
	end
	return Dificultad.de(math.max(n, 1), 0, Config.Dificultad).tareas
end

local function bidon()
	Cargar.alUsar("Bidon", {
		etiquetas = { "Generador" },
		accion = "Verter",
		preparar = function(jugador, _gen, pieza)
			if (pieza:GetAttribute("Carga") or 0) <= 0.01 then
				Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "The can is empty."))
				return nil
			elseif gasolina >= G.Deposito - 1 then
				Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "The tank is full."))
				return nil
			elseif gen:GetAttribute("Llenando") then
				Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "Someone is already using it."))
				return nil
			end
			gen:SetAttribute("Llenando", true)
			-- Inclinado encima del tapón, con la boca hacia abajo.
			local tapon = (gen:GetAttribute("Tapon") :: CFrame).Position
			return CFrame.new(tapon + Vector3.new(1.4, 2.4, 0)) * CFrame.Angles(0, 0, math.rad(110)), G.Verter
		end,
		terminar = function(_jugador, _gen, pieza)
			gen:SetAttribute("Llenando", nil)
			local porBidon = G.PorBidon * G.Deposito
			local echado = math.min((pieza:GetAttribute("Carga") or 0) * porBidon, G.Deposito - gasolina)
			gasolina += echado
			pieza:SetAttribute("Carga", math.max(0, (pieza:GetAttribute("Carga") or 0) - echado / porBidon))
			publicar()
			local tapon = (gen:GetAttribute("Tapon") :: CFrame).Position
			Cargar.liberar(pieza, CFrame.new(tapon + Vector3.new(-1.8, -2.5, -2.6)))
		end,
		cancelar = function()
			gen:SetAttribute("Llenando", nil)
		end,
	})
end

local function enchufar(jugador: Player)
	if enchufado or not puede(jugador, enchufe:FindFirstChild("Mando") :: BasePart) then
		return
	end
	local cosa = Mochila.sacar(jugador, "Movil")
	if not cosa then
		Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "You don't have a phone."))
		return
	end
	local pieza = Mochila.dejar("Movil", cosa.carga or 0, enchufe:GetAttribute("Sitio") :: CFrame)
	pieza.Anchored = true
	enchufado = pieza
	promptEnchufe.Enabled = false
	pieza.AncestryChanged:Connect(function()
		if not pieza.Parent and enchufado == pieza then -- lo han cogido
			enchufado = nil
			promptEnchufe.Enabled = true
		end
	end)
end

local cuenta = 0
local function gastar(dt: number)
	if encendido then
		gasolina = math.max(0, gasolina - dt * ritmo())
		if gasolina <= 0 then
			encendido = false
			gen:SetAttribute("Ahogado", (gen:GetAttribute("Ahogado") or 0) + 1)
			cambiarLuces(false)
			publicar()
		end
	end
	local cargando = encendido and enchufado ~= nil
	if cargando then
		local pieza = enchufado :: BasePart
		pieza:SetAttribute("Carga", math.min(1, (pieza:GetAttribute("Carga") or 0) + dt / Config.Movil.Carga))
	end
	cuenta += dt
	if cuenta >= 0.5 then -- lo que va bajando poco a poco, dos veces por segundo
		cuenta = 0
		gen:SetAttribute("Gasolina", gasolina / G.Deposito)
		local luz = enchufe:FindFirstChild("Luz") :: BasePart
		luz.Color = if cargando then Color3.fromRGB(90, 160, 80) else Color3.fromRGB(45, 43, 42)
	end
end

local function nuevoPrompt(mando: BasePart, texto: string): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Style = Enum.ProximityPromptStyle.Custom
	p.ActionText = texto
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p.MaxActivationDistance = Config.Casa.Alcance
	p.RequiresLineOfSight = false
	p.Parent = mando
	return p
end

function Generador.start()
	gen = CollectionService:GetTagged("Generador")[1]
	enchufe = CollectionService:GetTagged("Enchufe")[1]
	prompt = nuevoPrompt(gen:WaitForChild("Mando") :: BasePart, "")
	prompt.Triggered:Connect(tirar)
	promptEnchufe = nuevoPrompt(enchufe:WaitForChild("Mando") :: BasePart, "Plug in phone")
	promptEnchufe.Triggered:Connect(enchufar)
	bidon()
	ponerLuces(false)
	publicar()
	RunService.Heartbeat:Connect(gastar)
end

return Generador
