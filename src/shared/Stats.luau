-- Única fuente de las ventajas de los jugadores (las clases; más adelante pases y mejoras), en el servidor y en el
-- cliente. La clase sale del atributo "Clase" del Player (lo pone comun/servidor/Clases).
--   Stats.valor(jugador, "Velocidad") -> el número de su clase, o el de Config.Ventajas si no tiene.
-- No aplicar una misma ventaja en dos sitios: cada una se usa en un solo sistema (ver Config.Ventajas).
local Config = require(script.Parent.Config)

local Stats = {}

local porId = {}
for _, clase in Config.Clases do
	porId[clase.Id] = clase
end

-- La clase con ese Id (o nil si no existe).
function Stats.clase(id: unknown)
	return if type(id) == "string" then porId[id] else nil
end

function Stats.valor(jugador: Player?, ventaja: string): number
	local base = Config.Ventajas[ventaja]
	assert(base ~= nil, `ventaja desconocida: {ventaja}`)
	local clase = jugador and Stats.clase(jugador:GetAttribute("Clase"))
	return clase and clase.Ventajas[ventaja] or base
end

return Stats
