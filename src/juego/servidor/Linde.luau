-- La linde del mundo: hasta dónde se puede andar. Sin Roblox (solo cuentas), para probarla con Lune; las piezas las pone
-- MapaBosque (linde). El suelo llega a ±800 y el bosque, a unos 420 de la casa: sin esto se cruzaba una llanura pelada y se
-- caía al vacío. El contorno es un círculo de RADIO alrededor de la casa que en el lado del pueblo se abre y rodea el
-- pueblo entero (edificios, cementerio, calle) con su cinturón de pinos (PuebloCalle.bosque, de 8 a 55 studs) y algo más.
-- Números a ojo.
local PuebloPlano = require(script.Parent.PuebloPlano)

local Linde = {}

Linde.RADIO = 455 -- el círculo de las paredes (la casa en el centro)
Linde.LADOS = 44 -- lados del polígono si fuera el círculo entero (el arco del pueblo se queda con su parte)
Linde.MARGEN = 62 -- de los edificios del pueblo a la pared que lo rodea (su cinturón llega a 55)
Linde.CINTURON = 58 -- los pinos de la linde no entran en el pueblo más su cinturón (no se pisan con los suyos)
Linde.ALTO = 40 -- alto de las paredes, desde y = -1 (lo de abajo del suelo)
Linde.GROSOR = 2
local CALLE_Z2 = -398 -- donde empieza la calle del pueblo (CALLE.z2 en PuebloCalle, que necesita Roblox)

export type Punto = { x: number, z: number }

-- El rectángulo del pueblo (x1, x2, z1, z2): edificios, cementerio y calle, como lo mide PuebloCalle.bosque.
function Linde.pueblo(): (number, number, number, number)
	local c = PuebloPlano.CEMENTERIO
	local x1, x2, z1, z2 = c.x1, c.x2, c.z1, c.z2
	for _, e in PuebloPlano.edificios do
		x1, x2 = math.min(x1, e.x - e.ancho / 2), math.max(x2, e.x + e.ancho / 2)
		z1, z2 = math.min(z1, e.z - e.largo / 2), math.max(z2, e.z + e.largo / 2)
	end
	return x1, x2, z1, math.max(z2, CALLE_Z2)
end

-- ¿Está (x, z) en el pueblo agrandado `margen` studs por cada lado?
function Linde.enPueblo(x: number, z: number, margen: number): boolean
	local x1, x2, z1, z2 = Linde.pueblo()
	return x > x1 - margen and x < x2 + margen and z > z1 - margen and z < z2 + margen
end

-- La carretera de la casa al pueblo (por donde no se ponen árboles, como en Mapa).
function Linde.carretera(x: number, z: number): boolean
	return math.abs(x) < 12 and z < -41
end

-- El contorno, en orden (sin repetir el primero al final): el arco del círculo por el norte, de la esquina este del
-- pueblo a la oeste, y el rectángulo del pueblo agrandado por el sur. El pueblo tiene que asomar fuera del círculo y
-- cortarlo por sus dos lados (si alguien lo mueve y no, da error al arrancar en vez de dejar un hueco).
local contorno: { Punto }? = nil
function Linde.contorno(): { Punto }
	if contorno then
		return contorno
	end
	local x1, x2, z1, z2 = Linde.pueblo()
	local R = Linde.RADIO
	local X1, X2, Z1, Z2 = x1 - Linde.MARGEN, x2 + Linde.MARGEN, z1 - Linde.MARGEN, z2 + Linde.MARGEN
	assert(math.abs(X1) < R and math.abs(X2) < R, "[Linde] el pueblo es más ancho que el círculo")
	local zE, zO = -math.sqrt(R * R - X2 * X2), -math.sqrt(R * R - X1 * X1)
	assert(zE > Z1 and zE < Z2 and zO > Z1 and zO < Z2, "[Linde] el pueblo no corta el círculo por sus lados")
	local desde = math.atan2(zE, X2)
	local hasta = math.atan2(zO, X1) + math.pi * 2
	local n = math.max(math.ceil((hasta - desde) / (math.pi * 2 / Linde.LADOS)), 2)
	local puntos = {}
	for i = 0, n do
		local a = desde + (hasta - desde) * i / n
		table.insert(puntos, if i == 0 then { x = X2, z = zE } elseif i == n then { x = X1, z = zO }
			else { x = R * math.cos(a), z = R * math.sin(a) })
	end
	table.insert(puntos, { x = X1, z = Z1 })
	table.insert(puntos, { x = X2, z = Z1 })
	contorno = puntos
	return puntos
end

-- Las paredes: un tramo por lado del contorno, { a, b }.
function Linde.tramos(): { { a: Punto, b: Punto } }
	local puntos = Linde.contorno()
	local lista = {}
	for i, a in puntos do
		table.insert(lista, { a = a, b = puntos[i % #puntos + 1] })
	end
	return lista
end

-- ¿Está (x, z) dentro del contorno? (Rayo hacia +x contando cruces.)
function Linde.dentro(x: number, z: number): boolean
	local puntos = Linde.contorno()
	local dentro = false
	local j = #puntos
	for i = 1, #puntos do
		local a, b = puntos[i], puntos[j]
		if (a.z > z) ~= (b.z > z) and x < a.x + (z - a.z) * (b.x - a.x) / (b.z - a.z) then
			dentro = not dentro
		end
		j = i
	end
	return dentro
end

-- Distancia de (x, z) al contorno (la más corta a alguno de sus lados), esté dentro o fuera.
function Linde.distancia(x: number, z: number): number
	local mejor = math.huge
	for _, t in Linde.tramos() do
		local dx, dz = t.b.x - t.a.x, t.b.z - t.a.z
		local largo2 = dx * dx + dz * dz
		local k = if largo2 > 0 then math.clamp(((x - t.a.x) * dx + (z - t.a.z) * dz) / largo2, 0, 1) else 0
		local px, pz = t.a.x + dx * k - x, t.a.z + dz * k - z
		mejor = math.min(mejor, math.sqrt(px * px + pz * pz))
	end
	return mejor
end

-- Sitios para árboles en una franja pegada al contorno: rejilla de `paso` con un desvío de hasta `desvio`, a entre
-- `cerca` y `lejos` del contorno, por dentro (`dentro` = true) o por fuera. Por dentro no entran en el pueblo con su
-- cinturón ni en la carretera. `azar` es un Random (o algo con NextNumber); se piden siempre dos números por punto de
-- la rejilla, salga o no, para que el resto no se mueva al cambiar las reglas.
function Linde.sitios(azar, paso: number, desvio: number, cerca: number, lejos: number, dentro: boolean): { Punto }
	local puntos = Linde.contorno()
	local x1, x2, z1, z2 = math.huge, -math.huge, math.huge, -math.huge
	for _, p in puntos do
		x1, x2, z1, z2 = math.min(x1, p.x), math.max(x2, p.x), math.min(z1, p.z), math.max(z2, p.z)
	end
	local cerca2 = (Linde.RADIO - lejos - desvio - 2) ^ 2 -- más cerca de la casa no hay nada que mirar
	local lista = {}
	for gx = x1 - lejos, x2 + lejos, paso do
		for gz = z1 - lejos, z2 + lejos, paso do
			local x, z = gx + azar:NextNumber(-desvio, desvio), gz + azar:NextNumber(-desvio, desvio)
			if x * x + z * z < cerca2 or Linde.dentro(x, z) ~= dentro then
				continue
			end
			if dentro and (Linde.enPueblo(x, z, Linde.CINTURON) or Linde.carretera(x, z)) then
				continue
			end
			local d = Linde.distancia(x, z)
			if d >= cerca and d <= lejos then
				table.insert(lista, { x = x, z = z })
			end
		end
	end
	return lista
end

return Linde
