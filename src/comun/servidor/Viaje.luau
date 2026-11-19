-- El viaje del lobby a la partida y la vuelta. Vale en los dos lugares.
--   Lobby (Viaje.ir): reserva un servidor privado del lugar Juego, apunta en MemoryStore (clave = id del servidor
--   privado) quién es el dueño, qué ranura, si es nueva y quiénes van, y los teletransporta a todos juntos.
--   Juego (Viaje.leer): lee eso de MemoryStore. Nunca se fía de los datos del teletransporte: pasan por el cliente.
--   Viaje.volver: de vuelta al lobby.
--   Volver tras un corte: el lobby apunta también el código de acceso del servidor reservado (solo lo leen servidores:
--   nunca llega al cliente). Juego: a quien se va se le apunta la vuelta (`vuelta_<UserId>`, caduca en
--   Config.Partida.VueltaCaduca s y la renueva mientras falte). Lobby: Viaje.vuelta la lee y Viaje.regresar le lleva.
--   Cada servidor de partida solo renueva o borra las vueltas que llevan a él (por si se fue luego a otra partida).
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

-- `codigo`: el ReservedServerAccessCode (nil si lo apuntó un lobby de antes o es el dueño falso de Studio).
export type Info = { dueno: number, ranura: number, nueva: boolean, jugadores: { number }, codigo: string? }
-- La partida abierta a la que se puede volver (lo que lee el lobby).
export type Abierta = { codigo: string }

local function sePuede(lugar: number): boolean
	return lugar ~= 0 and not RunService:IsStudio()
end

-- El HashMap de los viajes y las vueltas (los bancos de Lune lo cambian por uno de mentira).
function Viaje.mapa(): MemoryStoreHashMap
	return MemoryStoreService:GetHashMap(Config.Partida.Viajes)
end

local function mapa(): MemoryStoreHashMap
	return Viaje.mapa()
end

local function claveVuelta(userId: number): string
	return `vuelta_{userId}`
end

-- Una llamada a un servicio web (ReserveServer, MemoryStore) con un reintento: fallan a veces sin motivo, y un fallo
-- suelto no debe tirar el viaje de todo el grupo cuando ya ha visto la cuenta atrás.
local function conReintento(que: string, fn: () -> ()): boolean
	for intento = 1, 2 do
		local ok, fallo = pcall(fn)
		if ok then
			return true
		end
		warn(`[Viaje] no se pudo {que} (intento {intento}): {fallo}`)
		if intento == 1 then
			task.wait(1)
		end
	end
	return false
end

-- Teletransporta con un reintento (fallan a veces sin motivo).
local function teletransportar(lugar: number, todos: { Player }, opciones: TeleportOptions?): boolean
	for intento = 1, 2 do
		-- Sin los que se han ido mientras se reservaba el servidor: con uno que ya no está falla para todos.
		local jugadores = {}
		for _, jugador in todos do
			if jugador.Parent == Players then
				table.insert(jugadores, jugador)
			end
		end
		if #jugadores == 0 then
			return false
		end
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
	local codigo, servidor
	if not conReintento("reservar el servidor", function()
		codigo, servidor = TeleportService:ReserveServer(lugar)
	end) then
		return false, "error"
	end
	local ids = {}
	for _, jugador in jugadores do
		table.insert(ids, jugador.UserId)
	end
	local info: Info = { dueno = dueno, ranura = ranura, nueva = nueva, jugadores = ids, codigo = codigo }
	if not conReintento("apuntar el viaje", function()
		mapa():SetAsync(servidor, info, Config.Partida.CaducaViaje)
	end) then
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
			return { dueno = info.dueno, ranura = info.ranura, nueva = info.nueva == true, jugadores = info.jugadores,
				codigo = if type(info.codigo) == "string" and info.codigo ~= "" then info.codigo else nil }
		end
		task.wait(2)
	end
	return nil
end

-- Juego: la partida de este servidor ya se ha guardado una vez. Si era nueva, lo apuntado deja de decirlo: si el
-- servidor reservado se cierra y alguien vuelve (Viaje.regresar arranca otro con el mismo código), carga lo guardado
-- en vez de empezar de cero y pisarlo al amanecer.
function Viaje.yaGuardada()
	if game.PrivateServerId == "" then
		return
	end
	conReintento("apuntar que ya no es nueva", function()
		mapa():UpdateAsync(game.PrivateServerId, function(info)
			if type(info) ~= "table" or info.nueva ~= true then
				return nil -- nada que cambiar
			end
			info.nueva = false
			return info
		end, Config.Partida.CaducaViaje)
	end)
end

-- Juego: apunta que `userId` puede volver a esta partida (se acaba de ir). false si no se puede (sin código o falla).
function Viaje.apuntarVuelta(userId: number, info: Info): boolean
	local codigo = info.codigo
	if not codigo then
		return false
	end
	local abierta: Abierta = { codigo = codigo }
	return conReintento("apuntar la vuelta", function()
		mapa():SetAsync(claveVuelta(userId), abierta, Config.Partida.VueltaCaduca)
	end)
end

-- Juego: renueva la vuelta de `userId`, solo si sigue llevando a esta partida. "ok"; "otra" si ya no está o lleva a
-- otra (ha vuelto, se ha ido luego a otra partida o caducó): no renovarla más; "error" si no se ha podido (otra vez
-- en la siguiente).
function Viaje.renovarVuelta(userId: number, info: Info): "ok" | "otra" | "error"
	local codigo = info.codigo
	if not codigo then
		return "otra"
	end
	local nuestra = false
	local ok = conReintento("renovar la vuelta", function()
		mapa():UpdateAsync(claveVuelta(userId), function(actual)
			-- (MemoryStore puede llamar a esto más de una vez: vale lo de la última)
			nuestra = type(actual) == "table" and actual.codigo == codigo
			return if nuestra then { codigo = codigo } else nil -- nil: no es nuestra, se deja como está
		end, Config.Partida.VueltaCaduca)
	end)
	if not ok then
		return "error"
	end
	return if nuestra then "ok" else "otra"
end

-- Juego: borra la vuelta de `userId` si lleva a esta partida (ha vuelto o la partida se ha acabado).
function Viaje.borrarVuelta(userId: number, info: Info)
	local codigo = info.codigo
	if not codigo then
		return
	end
	local actual = nil
	if not conReintento("leer la vuelta", function()
		actual = mapa():GetAsync(claveVuelta(userId))
	end) then
		return
	end
	if type(actual) == "table" and actual.codigo == codigo then
		conReintento("borrar la vuelta", function()
			mapa():RemoveAsync(claveVuelta(userId))
		end)
	end
end

-- Lobby: la partida abierta a la que puede volver `userId` (o nil), y si se ha podido leer (false = no se sabe:
-- no tocar lo que se enseña). En Studio no hay teletransporte: nunca hay.
function Viaje.vuelta(userId: number): (Abierta?, boolean)
	if RunService:IsStudio() then
		return nil, true
	end
	local leida = nil
	if not conReintento("leer la vuelta", function()
		leida = mapa():GetAsync(claveVuelta(userId))
	end) then
		return nil, false
	end
	if type(leida) == "table" and type(leida.codigo) == "string" and leida.codigo ~= "" then
		return { codigo = leida.codigo }, true
	end
	return nil, true
end

-- Juego: a quién ha mandado Viaje.volver al lobby (al irse no se le apunta la vuelta: se le ha echado).
local devueltos: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any

function Viaje.devuelto(jugador: Player): boolean
	return devueltos[jugador] == true
end

-- Juego: a quién se está devolviendo al lobby, con qué texto y si ya se le ha reintentado.
type Vuelta = { texto: string, reintentado: boolean }
local volviendo: { [Player]: Vuelta } = setmetatable({}, { __mode = "k" }) :: any
local escuchando = false

-- Una vuelta que ha salido aún puede fallar al llegar (TeleportInitFailed): se reintenta una vez y, si vuelve a fallar,
-- se le echa con el texto, para que nadie se quede en una partida acabada. Se conecta con la primera vuelta (en el
-- lobby nunca: allí lo mira Coches). Con IsTeleporting no se hace nada: aún va de camino con otra vuelta.
local function vigilarVuelta()
	if escuchando then
		return
	end
	escuchando = true
	TeleportService.TeleportInitFailed:Connect(function(jugador, resultado)
		local vuelta = volviendo[jugador]
		if not vuelta or jugador.Parent ~= Players or resultado == Enum.TeleportResult.IsTeleporting then
			return
		end
		if not vuelta.reintentado then
			vuelta.reintentado = true
			task.wait(2)
			if jugador.Parent ~= Players or teletransportar(Config.Lugares.Lobby, { jugador }) then
				return
			end
		end
		volviendo[jugador] = nil
		jugador:Kick(Lang.t(jugador, vuelta.texto))
	end)
end

-- Juego: devuelve al lobby a estos jugadores con un aviso de una línea (`texto` en inglés, para Lang). En Studio
-- solo avisa; si no se puede teletransportar (ni al salir ni al llegar), los echa con el texto.
function Viaje.volver(jugadores: { Player }, texto: string)
	for _, jugador in jugadores do
		devueltos[jugador] = true
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
	if sePuede(lugar) then
		vigilarVuelta()
		for _, jugador in quedan do
			volviendo[jugador] = { texto = texto, reintentado = false }
		end
	end
	if not sePuede(lugar) or not teletransportar(lugar, quedan) then
		for _, jugador in quedan do
			jugador:Kick(Lang.t(jugador, texto))
		end
	end
end

-- Lobby: lleva a `jugador` de vuelta a su partida abierta (`vuelta`, de Viaje.vuelta). Como Viaje.ir: true si ha
-- salido (aún puede fallar al llegar: lo avisa Coches con TeleportInitFailed), o false y por qué ("studio" o "error").
function Viaje.regresar(jugador: Player, vuelta: Abierta): (boolean, string?)
	local lugar = Config.Lugares.Juego
	if not sePuede(lugar) then
		return false, "studio"
	end
	local opciones = Instance.new("TeleportOptions")
	opciones.ReservedServerAccessCode = vuelta.codigo
	if teletransportar(lugar, { jugador }, opciones) then
		return true
	end
	return false, "error"
end

return Viaje
