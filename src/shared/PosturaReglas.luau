-- Agacharse y asomarse (14.6): qué se puede pedir y cuándo. Sin nada de Roblox, para probarlo con Lune.
-- Lo usan el servidor (juego/servidor/Postura, que valida el remote Postura y publica los atributos Agachado y Asomado)
-- y el cliente (PosturaVista, que predice con las mismas reglas para no esperar al servidor).
--   Solo valen ("Agachado", sí/no) y ("Asomar", -1 izquierda / 0 / 1 derecha). Cualquier otra cosa (tipos raros, NaN,
--   0,5, 2...) no cambia nada.
--   Muerto, escondido o con las manos ocupadas (algo pesado o trabajando) no se cambia (y `limpiar` lo quita). Con la
--   mochila abierta se puede agachar y levantar, pero no asomarse.
--   Entre dos cambios, como poco Config.Postura.Cada segundos (lo que no cambia nada no cuenta).
local Config = require(script.Parent.Config)

-- Quién te ha pillado (quienPilla): un bicho que gatea cuenta como el que te saca si el escondido estaba a menos de
-- esto de la cara del susto (la mesa del comedor mide 9,1 de largo: de una punta a la boca del otro lado, ~9,2).
local GATEA_PILLA = 10

local PosturaReglas = {}

export type Estado = {
	agachado: boolean,
	asomado: number, -- -1, 0 o 1
	ultimo: number, -- cuándo fue el último cambio pedido (el reloj del que lo lleva)
}

export type Jugador = {
	vivo: boolean,
	escondido: boolean,
	cargando: boolean, -- manos ocupadas: algo pesado (atributo Cargando) o trabajando (Trabajando: talar, serrar...)
	mochila: boolean, -- tiene la mochila abierta (no se asoma)
}

function PosturaReglas.nuevo(): Estado
	return { agachado = false, asomado = 0, ultimo = -math.huge }
end

-- ¿Puede estar agachado o asomado?
function PosturaReglas.puede(jugador: Jugador): boolean
	return jugador.vivo == true and not jugador.escondido and not jugador.cargando
end

-- ¿Es una petición bien hecha? (lo que llega del cliente puede ser cualquier cosa)
function PosturaReglas.valida(que: unknown, valor: unknown): boolean
	if que == "Agachado" then
		return type(valor) == "boolean"
	elseif que == "Asomar" then
		return type(valor) == "number" and (valor == -1 or valor == 0 or valor == 1) -- NaN e infinitos, fuera
	end
	return false
end

-- ¿Se puede pedir eso ahora (sin contar el tiempo)?
function PosturaReglas.permitido(que: unknown, valor: unknown, jugador: Jugador): boolean
	if not PosturaReglas.valida(que, valor) or not PosturaReglas.puede(jugador) then
		return false
	end
	return not (que == "Asomar" and valor ~= 0 and jugador.mochila)
end

-- Lo que pide el jugador (`que`, `valor`) en el instante `ahora`. Devuelve si cambia y el estado nuevo (una copia: el
-- de antes no se toca); si no cambia, el mismo.
function PosturaReglas.pedir(estado: Estado, que: unknown, valor: unknown, ahora: number, jugador: Jugador): (boolean, Estado)
	if not PosturaReglas.permitido(que, valor, jugador) then
		return false, estado
	end
	local actual: boolean | number = if que == "Agachado" then estado.agachado else estado.asomado
	if actual == valor or ahora - estado.ultimo < Config.Postura.Cada then
		return false, estado
	end
	local nuevo = table.clone(estado)
	if que == "Agachado" then
		nuevo.agachado = valor :: boolean
	else
		nuevo.asomado = if valor == 0 then 0 else valor :: number -- sin -0
	end
	nuevo.ultimo = ahora
	return true, nuevo
end

-- Quita lo que ya no puede ser: todo si está muerto, escondido o cargando; asomarse si tiene la mochila abierta. No
-- cuenta como un cambio pedido (no toca `ultimo`).
function PosturaReglas.limpiar(estado: Estado, jugador: Jugador): (boolean, Estado)
	local agachado, asomado = estado.agachado, estado.asomado
	if not PosturaReglas.puede(jugador) then
		agachado, asomado = false, 0
	elseif jugador.mochila then
		asomado = 0
	end
	if agachado == estado.agachado and asomado == estado.asomado then
		return false, estado
	end
	local nuevo = table.clone(estado)
	nuevo.agachado, nuevo.asomado = agachado, asomado
	return true, nuevo
end

-- De pie y sin asomarse, pase lo que pase (al reaparecer).
function PosturaReglas.quitar(estado: Estado): Estado
	local nuevo = table.clone(estado)
	nuevo.agachado, nuevo.asomado = false, 0
	return nuevo
end

-- Esconderse agachado (pedido por el usuario: "que sea útil agacharte"). Lo usan los bichos (Caza, Bestia) con los
-- atributos Agachado y Cubierto (agachado debajo de un mueble) del jugador.

-- Hasta dónde ve un bicho a un jugador, con `vista` la de siempre (de pie).
function PosturaReglas.alcanceVista(vista: number, agachado: boolean, cubierto: boolean): number
	if cubierto then
		return math.min(vista, Config.Postura.VerCubierto)
	elseif agachado then
		return vista * Config.Postura.VistaAgachado
	end
	return vista
end

-- Hasta dónde le oye, con `oido` lo de siempre (de pie). Corriendo (atributo Corriendo, 14.8, pedido por el usuario:
-- correr hace ruido, riesgo y premio) se le oye desde Config.Correr.Oido; agachado o debajo de algo no se corre.
function PosturaReglas.alcanceOido(oido: number, agachado: boolean, cubierto: boolean, corriendo: boolean?): number
	if cubierto then
		return math.min(oido, Config.Postura.VerCubierto)
	elseif agachado then
		return math.min(oido, Config.Postura.OirAgachado)
	elseif corriendo then
		return math.max(oido, Config.Correr.Oido)
	end
	return oido
end

-- Lo que un bicho lleva oliendo a un jugador escondido debajo de algo, tras `dt` s a `distancia` studs: sube 1 por
-- segundo a menos de Config.Postura.Olfato y baja a la mitad de deprisa si está más lejos (de 0 a Config.Postura.Huele).
function PosturaReglas.oler(olor: number, dt: number, distancia: number): number
	if distancia < Config.Postura.Olfato then
		return math.min(olor + dt, Config.Postura.Huele)
	end
	return math.max(0, olor - dt * 0.5)
end

-- Ya sabe dónde está (va a por él y gatea para sacarle).
function PosturaReglas.huele(olor: number): boolean
	return olor >= Config.Postura.Huele
end

export type Candidato = {
	distancia: number, -- de su cabeza a la cara del susto
	gatea: number?, -- de dónde estaba el escondido a por el que gatea a la cara del susto; nil si no gatea
}

-- Quién te ha pillado, para la escena de muerte (MuerteVista): el remote Muerte solo dice dónde está la cara del bicho.
-- Primero el que gateaba a por quien estaba ahí (te ha sacado de debajo); si no, el de la cabeza más cerca. Entre dos
-- que gatean a por ti, también el más cerca. Devuelve su posición en la lista, o nil si está vacía.
function PosturaReglas.quienPilla(candidatos: { Candidato }): number?
	local mejor: number? = nil
	local mejorGatea, mejorDistancia = false, math.huge
	for i, c in candidatos do
		local gatea = c.gatea ~= nil and c.gatea <= GATEA_PILLA
		if (gatea and not mejorGatea) or (gatea == mejorGatea and c.distancia < mejorDistancia) then
			mejor, mejorGatea, mejorDistancia = i, gatea, c.distancia
		end
	end
	return mejor
end

return PosturaReglas
