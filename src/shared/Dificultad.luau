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

return Dificultad
