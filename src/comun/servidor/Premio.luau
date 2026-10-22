-- Cuentas de las monedas que se ganan (las usa Recompensas). Sin nada de Roblox, para probarlas con Lune.
local Premio = {}

export type Ciclo = { fase: string?, noche: number, pagada: number }

-- Lo que hay que recordar del día y la noche de este servidor para no pagar un amanecer dos veces.
function Premio.ciclo(): Ciclo
	return { fase = nil, noche = 0, pagada = 0 }
end

-- Apunta el cambio de fase y dice si es un amanecer de verdad aún sin pagar: de la noche n-1 al día n. No pagan el
-- primer día (al arrancar o cargar la partida), volver al día tras morir todos ni los saltos del modo de pruebas.
function Premio.amanecer(c: Ciclo, fase: string, noche: number): boolean
	local antes, nocheAntes = c.fase, c.noche
	c.fase, c.noche = fase, noche
	if fase ~= "Dia" or antes ~= "Noche" or noche ~= nocheAntes + 1 or noche <= c.pagada then
		return false
	end
	c.pagada = noche
	return true
end

-- Monedas por superar la noche `superada` (1, 2, 3…): cada noche un poco más, hasta un tope.
function Premio.noche(config, superada: number): number
	return config.Noche + config.PorNoche * math.clamp(superada - 1, 0, config.TopeNoches)
end

-- Monedas del logro `nombre` si aún no lo tenía (lo apunta en datos.logros), o 0.
function Premio.logro(datos, config, nombre: string): number
	local logro = config.Logros[nombre]
	if not logro or datos.logros[nombre] then
		return 0
	end
	datos.logros[nombre] = true
	return logro.Monedas
end

-- Monedas del premio diario si ya han pasado config.Cada segundos desde el último (lo apunta en datos.diario), o 0.
-- Una hora guardada absurda (más de un día en el futuro: reloj roto) no bloquea al jugador.
function Premio.diario(datos, config, ahora: number): number
	local pasado = ahora - datos.diario
	if pasado < config.Cada and pasado > -config.Cada then
		return 0
	end
	datos.diario = ahora
	return config.Diario
end

function Premio.sumar(datos, monedas: number)
	if monedas > 0 and monedas < math.huge then
		datos.monedas += monedas
	end
end

return Premio
