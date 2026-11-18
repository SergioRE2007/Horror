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
		compras = {}, -- [PurchaseId] = os.time() de la entrega: compras de Robux ya entregadas, para no dar dos veces
		regalos = {}, -- [Ventaja] = true: lo de una vez de ese pase ya entregado (Config.Compras.Pases, Regalo)
		diario = 0, -- os.time() del último premio diario
		clase = "", -- Id de la clase elegida en el lobby ("" = ninguna)
		puestos = {}, -- [Tipo] = Id del cosmético que lleva puesto de cada tipo (sin entrada = el de serie)
		rendimiento = false, -- ajuste Rendimiento (comun/servidor/Ajustes): menos partículas y adornos
		-- true cuando el jugador ya ha elegido Rendimiento con el botón (o se le sugirió una vez en el móvil): desde
		-- entonces manda lo suyo y no se vuelve a sugerir. Los datos de antes no lo traen (16.9): ver arreglarJugador.
		rendimientoElegido = false,
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
	-- Datos de antes de 16.9, sin `rendimientoElegido`: false era también "nunca lo tocó", así que solo cuenta como
	-- elegido si lo dejó activado; con false se le puede sugerir una vez (solo lo enciende, nunca lo apaga).
	if guardado.rendimientoElegido == nil and guardado.rendimiento == true then
		guardado.rendimientoElegido = true
	end
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

-- Sugerencia del cliente al entrar (16.9: táctil sin teclado = Rendimiento activado). Solo si el jugador nunca lo
-- ha elegido, solo un booleano y una sola vez: queda como elegido. true si ha cambiado algo.
function Formato.sugerirRendimiento(datos: any, valor: unknown): boolean
	if type(datos) ~= "table" or type(valor) ~= "boolean" or datos.rendimientoElegido == true then
		return false
	end
	datos.rendimiento = valor
	datos.rendimientoElegido = true
	return true
end

return Formato
