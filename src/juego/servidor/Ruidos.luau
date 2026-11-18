-- Ruidos que oyen los bichos (15.8, pedido por el usuario: "arrastrar o dejar caer algo pesado hace ruido y el bicho lo
-- oye"). Librería sin start() y sin require (se prueba con Lune): Cargar apunta cada ruido y Caza.oir pregunta.
--   Ruidos.hacer(punto, alcance, dura): un ruido en `punto` que se oye a `alcance` studs durante `dura` s.
--   Ruidos.oir(desde, visto, factor): el ruido más cerca de `desde` que se oye allí y que es más nuevo que `visto` (el
--   número del último que ya oyó ese bicho, para que no vaya dos veces al mismo). Devuelve el punto (o nil) y el número
--   del más nuevo que oye, para guardarlo en `visto`. `factor(punto)`: cuánto le llega (0 = nada; las paredes, la mitad).
-- Un ruido lleva al bicho a mirar ALLÍ, no al jugador: si estás escondido lejos, no te pilla por él.
local Ruidos = {}

type Ruido = { n: number, punto: Vector3, alcance: number, hasta: number }

local lista: { Ruido } = {}
local cuenta = 0
local MAXIMO = 32 -- ruidos vivos a la vez como mucho (los más viejos se olvidan)

local function limpiar(ahora: number)
	for i = #lista, 1, -1 do
		if lista[i].hasta <= ahora then
			table.remove(lista, i)
		end
	end
	while #lista > MAXIMO do
		table.remove(lista, 1)
	end
end

function Ruidos.hacer(punto: Vector3, alcance: number, dura: number)
	if alcance <= 0 or dura <= 0 then
		return
	end
	local ahora = os.clock()
	limpiar(ahora)
	cuenta += 1
	table.insert(lista, { n = cuenta, punto = punto, alcance = alcance, hasta = ahora + dura })
end

function Ruidos.oir(desde: Vector3, visto: number, factor: ((Vector3) -> number)?): (Vector3?, number)
	local ahora = os.clock()
	limpiar(ahora)
	local mejor, distancia, nuevo = nil, math.huge, visto
	for _, r in lista do
		if r.n <= visto then
			continue
		end
		local d = (r.punto - desde).Magnitude
		local alcance = r.alcance * (if factor then factor(r.punto) else 1)
		if d <= alcance then
			nuevo = math.max(nuevo, r.n)
			if d < distancia then
				mejor, distancia = r.punto, d
			end
		end
	end
	return mejor, nuevo
end

-- Para las pruebas: olvida todo.
function Ruidos.vaciar()
	table.clear(lista)
end

return Ruidos
