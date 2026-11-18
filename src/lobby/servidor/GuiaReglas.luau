-- Reglas de la guía del lobby (GuiaLobby): a quién se le enseña y qué. Sin nada de Roblox, para probarlas con Lune
-- (tests/bancos/guia-lobby.luau). Solo mira lo que YA se guarda de cada jugador (docs/sistemas/lobby.md), no añade nada
-- al formato:
--   "Coche"  nunca ha jugado: ni una ranura de partida guardada (`partidas`) ni un logro (`logros`, que se cobran al
--            superar noches). Quien muere en su primera noche sigue contando como nuevo: no deja nada apuntado.
--   "Tienda" ya ha jugado y no ha comprado ninguna clase: la primera es gratis (Comprar.precioClase), así que la frase
--            "Your first class is free" es cierta. Se enseña una sola vez por cuenta: GuiaReglas.VISTA en `logros`.
--   nil      ni una ni otra.
local GuiaReglas = {}

-- Clave de `logros` donde se apunta que ya se le enseñó la tienda. Es una clave libre dentro de una tabla que ya existe
-- (como `Tutorial`): no cambia la forma de lo guardado ni hace falta subir su versión. No renombrar.
GuiaReglas.VISTA = "GuiaTienda"

local function hayAlgo(tabla: unknown): boolean
	return type(tabla) == "table" and next(tabla :: any) ~= nil
end

-- ¿Ha jugado alguna vez? (alguna noche superada o una partida guardada)
function GuiaReglas.haJugado(datos: any): boolean
	return type(datos) == "table" and (hayAlgo(datos.partidas) or hayAlgo(datos.logros))
end

-- La etapa de la guía de este jugador. `precioClase` es Comprar.precioClase(datos, clase): si pide algo por una clase
-- cualquiera, ya ha comprado una y la primera gratis ya no cuenta.
function GuiaReglas.etapa(datos: any, precioClase: (datos: any, clase: any) -> number): string?
	if type(datos) ~= "table" then
		return nil
	end
	if not GuiaReglas.haJugado(datos) then
		return "Coche"
	end
	if type(datos.logros) == "table" and datos.logros[GuiaReglas.VISTA] == true then
		return nil
	end
	if precioClase(datos, { Precio = 1 }) == 0 then
		return "Tienda"
	end
	return nil
end

return GuiaReglas
