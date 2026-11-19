-- Volver a la partida tras un corte. Si te has ido de una partida que sigue (se te cortó, o cerraste sin querer), el
-- servidor de la partida te apunta la vuelta (Viaje.apuntarVuelta, ver docs/sistemas/partida.md) y aquí se ve.
--   Al cargar tus datos (DatosListos) se lee y otra vez a los Config.Partida.VueltaRelee s (el servidor de la partida
--   tarda en darse cuenta de un corte): con vuelta, atributo del jugador `PartidaAbierta` = true y el cliente enseña
--   el cartel con GO BACK (lobby/cliente/RegresoUi).
--   Remote Regreso (sin datos): GO BACK. Pasa por Limite, vuelve a leer la vuelta (nunca se fía del cliente, que solo
--   tiene el atributo; el código de acceso no sale nunca del servidor), no deja si vas sentado en un coche y te lleva
--   con Viaje.regresar. Si ya no hay vuelta (la partida se ha acabado): aviso de una línea y se quita el atributo.
-- En Studio no hay teletransporte (Viaje.vuelta nunca encuentra nada): para ver el cartel, poner PartidaAbierta a mano.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Comun = ServerScriptService:WaitForChild("Comun")
local Limite = require(Comun.Limite)
local Viaje = require(Comun.Viaje)

local Regreso = {}

local ESPERA = 60 -- segundos que se espera a que carguen sus datos (como GuiaLobby); luego se mira igual

local yendo: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any -- GO BACK en marcha (uno a la vez)

local function avisar(jugador: Player, texto: string)
	Remotes.Aviso:FireClient(jugador, Lang.t(jugador, texto))
end

-- Lee si tiene una partida abierta y lo publica. Si no se ha podido leer, no se toca lo que había.
local function mirar(jugador: Player)
	local abierta, leida = Viaje.vuelta(jugador.UserId)
	if leida and jugador.Parent == Players then
		jugador:SetAttribute("PartidaAbierta", if abierta then true else nil)
	end
end

local function preparar(jugador: Player)
	local hasta = os.clock() + ESPERA
	while jugador.Parent == Players and not jugador:GetAttribute("DatosListos") and os.clock() < hasta do
		task.wait(0.25)
	end
	if jugador.Parent ~= Players then
		return
	end
	mirar(jugador)
	task.wait(Config.Partida.VueltaRelee)
	if jugador.Parent == Players and not yendo[jugador] then
		mirar(jugador)
	end
end

local function sentado(jugador: Player): boolean
	local humanoide = jugador.Character and jugador.Character:FindFirstChildOfClass("Humanoid")
	return jugador:GetAttribute("Coche") ~= nil or (humanoide ~= nil and humanoide.SeatPart ~= nil)
end

-- GO BACK. Cuenta también lo que se tira (cada petición lee MemoryStore).
local function pedir(jugador: Player)
	if not Limite.pasa(jugador, "Regreso", Config.Limites.Regreso) or yendo[jugador] or sentado(jugador) then
		return
	end
	yendo[jugador] = true
	local abierta, leida = Viaje.vuelta(jugador.UserId)
	if jugador.Parent ~= Players then
		yendo[jugador] = nil
		return
	end
	if not leida then
		avisar(jugador, "Couldn't start the game. Try again.")
	elseif not abierta then
		avisar(jugador, "Your game has already ended.")
		jugador:SetAttribute("PartidaAbierta", nil)
	elseif not sentado(jugador) then -- (se ha podido subir a un coche mientras se leía)
		local salio, porque = Viaje.regresar(jugador, abierta)
		if not salio then
			avisar(jugador, if porque == "studio" then "Teleport doesn't work in Studio." else "Couldn't start the game. Try again.")
		end
	end
	yendo[jugador] = nil
end

function Regreso.start()
	Remotes.Regreso.OnServerEvent:Connect(pedir)
	Players.PlayerAdded:Connect(function(jugador)
		task.spawn(preparar, jugador)
	end)
	for _, jugador in Players:GetPlayers() do
		task.spawn(preparar, jugador)
	end
end

return Regreso
