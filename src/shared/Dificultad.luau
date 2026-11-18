-- Dificultad de una noche según cuántos jugadores hay (tabla en Config.Dificultad). Sin nada de Roblox, para probarlo
-- con Lune. `azar` es un número entre 0 y 1 (de fuera) para elegir dentro de los rangos.
local Dificultad = {}

export type Noche = { alaVez: number, ritmo: number, paciencia: number, tareas: number }

function Dificultad.de(jugadores: number, azar: number, tabla): Noche
	local fila = tabla[math.clamp(math.floor(jugadores), 1, #tabla)]
	local minimo, maximo = fila.AlaVez[1], fila.AlaVez[2]
	return {
		alaVez = math.min(maximo, minimo + math.floor(azar * (maximo - minimo + 1))),
		ritmo = fila.Ritmo,
		paciencia = fila.Paciencia,
		tareas = fila.Tareas,
	}
end

-- Cuánto se multiplica lo que el Golpeador aguanta golpeando, dada la paciencia de la fila. La Paciencia alarga el
-- margen del Raspador, el Trepador y el Generador (más = más fácil), pero en el Golpeador alargar el aguante son más
-- golpes y más daño (más = más difícil). Por eso, con paciencia > 1 (jugando solo) golpea MENOS rato (1 / paciencia)
-- y con paciencia <= 1 se queda como estaba. Así solo nunca aguanta más que con cuatro.
function Dificultad.aguanteGolpeando(paciencia: number): number
	if paciencia > 1 then
		return 1 / paciencia
	end
	return paciencia
end

return Dificultad
