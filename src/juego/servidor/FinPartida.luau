-- Si la partida ya se ha acabado (16.15): con un final (huida o incendio) o para todos (vuelta al lobby). Lo pone
-- Partida y lo leen Partida, Director y Acechador. Aparte y sin require de nadie: así Acechador no necesita a Partida
-- (Partida -> Coche -> Acechador -> Partida era un círculo que obligaba a hacer require dentro de funciones).
-- Solo va hacia delante: una partida acabada no vuelve a empezar en este servidor.
local FinPartida = {}

local acabada = false

function FinPartida.acabada(): boolean
	return acabada
end

function FinPartida.marcar()
	acabada = true
end

return FinPartida
