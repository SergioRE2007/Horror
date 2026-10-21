-- El viaje del lobby a la partida y la vuelta. Vale en los dos lugares.
--   Lobby (Viaje.ir): reserva un servidor privado del lugar Juego, apunta en MemoryStore (clave = id del servidor
--   privado) quién es el dueño, qué ranura, si es nueva y quiénes van, y los teletransporta a todos juntos.
--   Juego (Viaje.leer): lee eso de MemoryStore. Nunca se fía de los datos del teletransporte: pasan por el cliente.
--   Viaje.volver: de vuelta al lobby.
-- En Studio (o sin publicar, Config.Lugares a 0) no hay teletransporte: el juego usa el dueño falso de Config.Test.
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Viaje = {}

export type Info = { dueno: number, ranura: number, nueva: boolean, jugadores: { number } }

local function sePuede(lugar: number): boolean
	return lugar ~= 0 and not RunService:IsStudio()
end

local function mapa()
	return MemoryStoreService:GetHashMap(Config.Partida.Viajes)
end

-- Teletransporta con un reintento (fallan a veces sin motivo).
local function teletransportar(lugar: number, jugadores: { Player }, opciones: TeleportOptions?): boolean
	for intento = 1, 2 do
		local ok, fallo = pcall(function()
			TeleportService:TeleportAsync(lugar, jugadores, opciones)
		end)
		if ok then
			return true
		end
		warn(`[Viaje] no se pudo teletransportar (intento {intento}): {fallo}`)
		task.wait(2)
	end
	return false
end

-- Lobby: lleva al grupo a un servidor nuevo del juego. Devuelve true si ha salido (luego aún puede fallar al
-- llegar: TeleportService avisa con TeleportInitFailed), o false y por qué ("studio" o "error").
function Viaje.ir(jugadores: { Player }, dueno: number, ranura: number, nueva: boolean): (boolean, string?)
	local lugar = Config.Lugares.Juego
	if not sePuede(lugar) then
		return false, "studio"
	end
	local ok, codigo, servidor = pcall(function()
		return TeleportService:ReserveServer(lugar)
	end)
	if not ok then
		warn(`[Viaje] no se pudo reservar el servidor: {codigo}`)
		return false, "error"
	end
	local ids = {}
	for _, jugador in jugadores do
		table.insert(ids, jugador.UserId)
	end
	local info: Info = { dueno = dueno, ranura = ranura, nueva = nueva, jugadores = ids }
	local apuntado, fallo = pcall(function()
		mapa():SetAsync(servidor, info, Config.Partida.CaducaViaje)
	end)
	if not apuntado then
		warn(`[Viaje] no se pudo apuntar el viaje: {fallo}`)
		return false, "error"
	end
	local opciones = Instance.new("TeleportOptions")
	opciones.ReservedServerAccessCode = codigo
	if teletransportar(lugar, jugadores, opciones) then
		return true
	end
	return false, "error"
end

-- Juego: lo que apuntó el lobby para este servidor, o nil si no es un servidor reservado por el lobby o no se
-- puede leer (reintenta unos segundos: MemoryStore a veces tarda).
function Viaje.leer(): Info?
	if game.PrivateServerId == "" or game.PrivateServerOwnerId ~= 0 then
		return nil
	end
	for _ = 1, 6 do
		local ok, info = pcall(function()
			return mapa():GetAsync(game.PrivateServerId)
		end)
		if ok and type(info) == "table" and type(info.dueno) == "number" and type(info.ranura) == "number"
			and type(info.jugadores) == "table" then
			return { dueno = info.dueno, ranura = info.ranura, nueva = info.nueva == true, jugadores = info.jugadores }
		end
		task.wait(2)
	end
	return nil
end

-- Juego: devuelve al lobby a estos jugadores con un aviso de una línea (`texto` en inglés, para Lang). En Studio
-- solo avisa; si no se puede teletransportar, los echa con el texto.
function Viaje.volver(jugadores: { Player }, texto: string)
	for _, jugador in jugadores do
		Remotes.Aviso:FireClient(jugador, Lang.t(jugador, texto))
	end
	local lugar = Config.Lugares.Lobby
	if RunService:IsStudio() then
		return
	end
	task.wait(3) -- que lean el aviso
	local quedan = {}
	for _, jugador in jugadores do
		if jugador.Parent == Players then
			table.insert(quedan, jugador)
		end
	end
	if #quedan == 0 then
		return
	end
	if not sePuede(lugar) or not teletransportar(lugar, quedan) then
		for _, jugador in quedan do
			jugador:Kick(Lang.t(jugador, texto))
		end
	end
end

return Viaje
