-- Correr y aguante (14.8, pedido por el usuario: "añadir la mecánica de correr, que tengas una stamina abajo del todo,
-- una barra fina así minimalista que aparezca al correr"). Sin nada de Roblox, para probarlo con Lune.
-- Lo usan el servidor (juego/servidor/Correr: valida el remote Correr, lleva el aguante y lo publica en atributos del
-- Player) y el cliente (CorrerVista: predice con las mismas cuentas para que vaya al momento).
--   Solo vale sí/no ("quiero correr"). Lo pedido se guarda (`quiere`) aunque ahora no se pueda (agachado, con algo
--   pesado...): en cuanto se pueda, corre. Las peticiones muy seguidas (menos de Config.Correr.Cada) no se pierden: la
--   última espera en `pendiente` y cuenta cuando toca.
--   Corre de verdad si lo pide, puede (`puede`), va hacia delante a más de Config.Correr.Moverse y no está agotado.
--   Corriendo gasta aguante (lleno dura Config.Correr.Dura s). Sin correr, tras Config.Correr.Espera s vuelve: más
--   deprisa quieto o agachado (Quieto) que andando (Andando).
--   Si llega a 0 corriendo, se agota: no vuelve a correr hasta tener Config.Correr.Volver, frena Config.Correr.Frena s
--   y `paso` avisa con "Agota" (jadeo y, a veces, un tropiezo: lo decide el servidor).
--   La velocidad corriendo: CorrerReglas.velocidad (la usa Cargar.ajustarVelocidad, la única que pone WalkSpeed).
local Config = require(script.Parent.Config)

local C = Config.Correr

local CorrerReglas = {}

local DT_MAX = 0.5 -- s como mucho de una vez (un tirón del servidor no gasta ni recupera de golpe)

export type Estado = {
	aguante: number, -- de 0 a 1
	quiere: boolean, -- lo que pide (Shift, L3 o el botón CORRER)
	pendiente: boolean?, -- lo último pedido que aún no cuenta (llegó antes de Config.Correr.Cada)
	corriendo: boolean, -- corre ahora mismo
	agotado: boolean, -- se agotó del todo: no corre hasta tener Config.Correr.Volver
	sinCorrer: number, -- segundos desde que dejó de correr
	frena: number, -- segundos que le quedan frenando tras agotarse
	ultimo: number, -- cuándo contó la última petición (el reloj del que lo lleva)
}

export type Jugador = {
	vivo: boolean,
	escondido: boolean,
	cargando: boolean, -- manos ocupadas: algo pesado (atributo Cargando) o trabajando (Trabajando)
	mochila: boolean, -- la mochila abierta
	agachado: boolean,
	asomado: boolean,
	vistazo: boolean?, -- por la mirilla o entre las cortinas (atributo local Vistazo: solo lo sabe su cliente)
	cine: boolean?, -- en una cinemática (solo lo sabe su cliente)
}

function CorrerReglas.nuevo(): Estado
	return {
		aguante = 1,
		quiere = false,
		pendiente = nil,
		corriendo = false,
		agotado = false,
		sinCorrer = math.huge,
		frena = 0,
		ultimo = -math.huge,
	}
end

-- Al reaparecer: descansado y sin pedir nada (lo que cuenta para Config.Correr.Cada se queda).
function CorrerReglas.reaparecer(estado: Estado): Estado
	local nuevo = CorrerReglas.nuevo()
	nuevo.ultimo = estado.ultimo
	return nuevo
end

-- ¿Es una petición bien hecha? (lo que llega del cliente puede ser cualquier cosa)
function CorrerReglas.valida(valor: unknown): boolean
	return type(valor) == "boolean"
end

-- ¿Puede correr ahora (sin contar el aguante ni si se mueve)?
function CorrerReglas.puede(jugador: Jugador): boolean
	return jugador.vivo == true and not jugador.escondido and not jugador.cargando and not jugador.mochila
		and not jugador.agachado and not jugador.asomado and not jugador.vistazo and not jugador.cine
end

-- ¿Cuenta como ir corriendo? `velocidad`: studs/s en el plano; `delante`: coseno entre hacia donde va y hacia donde
-- mira (1 recto, 0 de lado, -1 hacia atrás).
function CorrerReglas.seMueve(velocidad: number, delante: number): boolean
	return velocidad > C.Moverse and delante > C.Delante
end

-- Lo que pide el jugador (`valor`) en el instante `ahora`. Devuelve si cambia algo y el estado nuevo (una copia: el
-- de antes no se toca); si no cambia nada, el mismo. Muy seguido, se queda en `pendiente` (la última gana).
function CorrerReglas.pedir(estado: Estado, valor: unknown, ahora: number): (boolean, Estado)
	if not CorrerReglas.valida(valor) then
		return false, estado
	end
	local quiere = valor :: boolean
	if quiere == estado.quiere then
		if estado.pendiente == nil then
			return false, estado -- ya lo tenía: no cuenta para Cada
		end
		local nuevo = table.clone(estado)
		nuevo.pendiente = nil -- lo de antes que esperaba ya no vale: vuelve a pedir lo que tenía
		return true, nuevo
	end
	local nuevo = table.clone(estado)
	if ahora - estado.ultimo >= C.Cada then
		nuevo.quiere, nuevo.pendiente, nuevo.ultimo = quiere, nil, ahora
	else
		nuevo.pendiente = quiere
	end
	return true, nuevo
end

-- Un paso de `dt` s en el instante `ahora`, yendo a `velocidad` studs/s y `delante` (ver seMueve). Devuelve el estado
-- nuevo (una copia) y "Agota" si se ha agotado en este paso.
function CorrerReglas.paso(estado: Estado, dt: number, ahora: number, velocidad: number, delante: number,
	jugador: Jugador): (Estado, string?)
	local nuevo = table.clone(estado)
	if nuevo.pendiente ~= nil and ahora - nuevo.ultimo >= C.Cada then
		nuevo.quiere, nuevo.pendiente, nuevo.ultimo = nuevo.pendiente :: boolean, nil, ahora
	end
	if not (dt > 0) then -- 0, negativo o NaN: nada más
		nuevo.corriendo = false
		return nuevo, nil
	end
	dt = math.min(dt, DT_MAX)
	if velocidad ~= velocidad then
		velocidad = 0
	end
	if delante ~= delante then
		delante = 0
	end
	nuevo.frena = math.max(0, nuevo.frena - dt)
	local corre = nuevo.quiere and not nuevo.agotado and nuevo.aguante > 0 and CorrerReglas.puede(jugador)
		and CorrerReglas.seMueve(velocidad, delante)
	if corre then
		nuevo.corriendo = true
		nuevo.sinCorrer = 0
		nuevo.aguante = math.max(0, nuevo.aguante - dt / C.Dura)
		if nuevo.aguante <= 0 then
			nuevo.aguante = 0
			nuevo.corriendo = false
			nuevo.agotado = true
			nuevo.frena = C.Frena
			return nuevo, "Agota"
		end
		return nuevo, nil
	end
	nuevo.corriendo = false
	local antes = nuevo.sinCorrer
	nuevo.sinCorrer = antes + dt
	-- Solo la parte de este paso que ya pasa de la espera.
	local util = math.min(dt, nuevo.sinCorrer - C.Espera)
	if util > 0 then
		local quieto = velocidad <= C.Moverse or jugador.agachado
		nuevo.aguante = math.min(1, nuevo.aguante + util * (if quieto then C.Quieto else C.Andando))
	end
	if nuevo.agotado and nuevo.aguante >= C.Volver then
		nuevo.agotado = false
	end
	return nuevo, nil
end

-- La velocidad con la que anda (`andar`, ya con todo lo que frena o acelera: clase, agachado, cargando...) corriendo
-- o no. Solo se corre sin nada que frene (Cargar lo mira): aquí no se mezcla con nada más.
function CorrerReglas.velocidad(andar: number, corriendo: boolean): number
	return if corriendo then andar * C.Factor else andar
end

-- Lo cansado que está (de 0 a 1): para la respiración, el vaho y el jadeo. Agotado, del todo; si no, lo que le falta.
function CorrerReglas.cansancio(estado: Estado): number
	if estado.agotado then
		return 1
	end
	return math.clamp(1 - estado.aguante, 0, 1)
end

return CorrerReglas
