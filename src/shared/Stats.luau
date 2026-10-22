-- Única fuente de las ventajas de los jugadores (las clases y los pases), en el servidor y en el cliente. La clase
-- sale del atributo "Clase" del Player (lo pone comun/servidor/Clases) y los pases de "Pase<Ventaja>" (Compras).
--   Stats.valor(jugador, "Velocidad") -> el número de su clase o de un pase suyo, o el de Config.Ventajas si no tiene.
--   Stats.pase(jugador, "MochilaGrande") -> true si tiene el pase con esa ventaja. Se pregunta por la ventaja, nunca
--   por un pase concreto.
-- No aplicar una misma ventaja en dos sitios: cada una se usa en un solo sistema (ver Config.Ventajas).
local Config = require(script.Parent.Config)

local Stats = {}

local porId = {}
for _, clase in Config.Clases do
	porId[clase.Id] = clase
end

local pases = {}
for _, pase in Config.Compras.Pases do
	pases[pase.Ventaja] = pase
end

-- La clase con ese Id (o nil si no existe).
function Stats.clase(id: unknown)
	return if type(id) == "string" then porId[id] else nil
end

-- El pase con esa ventaja (o nil si no existe).
function Stats.paseDe(ventaja: unknown)
	return if type(ventaja) == "string" then pases[ventaja] else nil
end

function Stats.pase(jugador: Player?, ventaja: string): boolean
	assert(pases[ventaja] ~= nil, `pase desconocido: {ventaja}`)
	return jugador ~= nil and jugador:GetAttribute(`Pase{ventaja}`) == true
end

function Stats.valor(jugador: Player?, ventaja: string): number
	local base = Config.Ventajas[ventaja]
	assert(base ~= nil, `ventaja desconocida: {ventaja}`)
	local clase = jugador and Stats.clase(jugador:GetAttribute("Clase"))
	if clase and clase.Ventajas[ventaja] then
		return clase.Ventajas[ventaja]
	end
	for clave, pase in pases do
		if pase.Ventajas and pase.Ventajas[ventaja] and Stats.pase(jugador, clave) then
			return pase.Ventajas[ventaja]
		end
	end
	return base
end

-- Ancho y alto de su mochila.
function Stats.mochila(jugador: Player?): (number, number)
	local M = Config.Mochila
	if Stats.pase(jugador, "MochilaGrande") then
		return M.Grande[1], M.Grande[2]
	end
	return M.Ancho, M.Alto
end

-- Cuántas partidas guardadas puede tener.
function Stats.ranuras(jugador: Player?): number
	return if Stats.pase(jugador, "MasRanuras") then pases.MasRanuras.Ranuras else Config.Partida.Ranuras
end

-- Las que puede llegar a tener alguien (para construir la interfaz una vez).
Stats.RANURAS_MAX = math.max(Config.Partida.Ranuras, pases.MasRanuras.Ranuras)

return Stats
