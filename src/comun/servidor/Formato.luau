-- Formato de lo que se guarda de cada jugador. Campos con nombre y `version`: lo nuevo se añade sin romper lo viejo.
-- Si un campo cambia de forma, se sube VERSION y se añade abajo el paso que convierte lo viejo. Nunca borrar campos
-- con datos de jugadores. Sin nada de Roblox dentro, para probarlo con Lune.
local Formato = {}

Formato.VERSION = 1

-- Lo de un jugador que entra por primera vez.
function Formato.jugadorNuevo()
	return {
		version = Formato.VERSION,
		monedas = 0,
		clases = {}, -- clases compradas
		cosmeticos = {},
		logros = {},
		records = {},
		partidas = {}, -- resumen de sus ranuras de partida
		compras = {}, -- [PurchaseId] = true: compras de Robux ya entregadas, para no dar dos veces
		diario = 0, -- os.time() del último premio diario
		clase = "", -- Id de la clase elegida en el lobby ("" = ninguna)
	}
end

-- Pone al día lo guardado (o nil si es nuevo): convierte lo de versiones viejas, rellena lo que falte con lo de una
-- partida nueva y arregla valores imposibles. Devuelve la tabla lista para jugar.
function Formato.arreglarJugador(guardado: any)
	local nuevo = Formato.jugadorNuevo()
	if type(guardado) ~= "table" then
		return nuevo
	end
	-- Aquí irán los pasos de una versión a la siguiente: if (guardado.version or 0) < 2 then ... end
	for clave, valor in nuevo do
		if type(guardado[clave]) ~= type(valor) then
			guardado[clave] = valor
		end
	end
	-- Resumen de cada ranura de partida, ["1"] = { noche, hora }: lo apunta el servidor del juego al guardarla.
	for ranura, resumen in guardado.partidas do
		if type(ranura) ~= "string" or type(resumen) ~= "table" or type(resumen.noche) ~= "number" or resumen.noche ~= resumen.noche then
			guardado.partidas[ranura] = nil
		end
	end
	local monedas = guardado.monedas
	if monedas ~= monedas or monedas < 0 or monedas == math.huge then
		guardado.monedas = 0
	end
	guardado.version = Formato.VERSION
	return guardado
end

return Formato
