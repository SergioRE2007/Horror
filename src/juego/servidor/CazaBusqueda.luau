-- Cuentas de la búsqueda de los bichos cuando te pierden de vista (Caza.cazar). Sin nada de Roblox dentro salvo
-- Vector3, para probarlo con Lune (tests/bancos/caza-busqueda.luau). Números en Config.Caza.Busca.
--   Mientras persigue a alguien guarda un rastro (dónde le vio por última vez, hacia dónde iba él y cuándo). Al llegar
--   ahí sin verle, si el rastro es reciente, sigue unos studs en esa dirección (sin meterse en la pared), se para a
--   mirar a un lado y a otro y recorre las salas de al lado de esa misma planta antes de volver a la ronda.
--   También las cuentas de qué puerta cruza al andar (cruzaPuerta) y desde dónde mira (ojos), que usa Caza.
local CazaBusqueda = {}

export type Rastro = {
	punto: Vector3, -- dónde le vio por última vez (a ras de suelo)
	dir: Vector3?, -- hacia dónde iba el bicho en planta (unitario); nil si iba parado
	hora: number, -- os.clock de la última vez que le vio
}

local function plano(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Hacia dónde va en planta (unitario) con esa velocidad, si es más de `minimo` studs/s; si no, nil.
function CazaBusqueda.rumbo(velocidad: Vector3, minimo: number): Vector3?
	local p = plano(velocidad)
	if p.Magnitude > minimo then
		return p.Unit
	end
	return nil
end

-- ¿Le vale aún el rastro para buscarle? Solo si es de hace menos de `memoria` s.
function CazaBusqueda.vigente(rastro: Rastro?, ahora: number, memoria: number): boolean
	return rastro ~= nil and ahora - rastro.hora < memoria
end

-- Cuánto avanza en la dirección del rastro: `largo`, o hasta `margen` studs antes de la pared si hay una a `golpe`
-- studs (nunca hacia atrás).
function CazaBusqueda.avance(largo: number, golpe: number?, margen: number): number
	if golpe then
		return math.clamp(golpe - margen, 0, largo)
	end
	return largo
end

-- Las `n` salas más cerca de `punto` en planta y de su misma planta (|dy| < `alto`), de la más cerca a la más lejos.
-- Sin las que quedan a menos de `ya` studs (ya está en ella: no la cuenta como sala de al lado).
function CazaBusqueda.salasCerca(salas: { Vector3 }, punto: Vector3, n: number, alto: number, ya: number): { Vector3 }
	local cerca = {}
	for _, sala in salas do
		if math.abs(sala.Y - punto.Y) < alto and plano(sala - punto).Magnitude >= ya then
			table.insert(cerca, sala)
		end
	end
	table.sort(cerca, function(a, b)
		return plano(a - punto).Magnitude < plano(b - punto).Magnitude
	end)
	for i = #cerca, n + 1, -1 do
		cerca[i] = nil
	end
	return cerca
end

-- Una sala al azar para la ronda que no sea `evitar` (la que acaba de mirar), si hay más de una.
function CazaBusqueda.otraSala(salas: { Vector3 }, evitar: Vector3?, azar: Random): Vector3
	local n = #salas
	local quitar: number? = nil
	if evitar and n > 1 then
		for i, sala in salas do
			if (sala - evitar).Magnitude < 0.5 then
				quitar = i
				break
			end
		end
	end
	if not quitar then
		return salas[azar:NextInteger(1, n)]
	end
	local i = azar:NextInteger(1, n - 1)
	if i >= quitar then
		i += 1
	end
	return salas[i]
end

-- Hacia dónde mira (unitario, en planta) a los `t` s de los `total` que se para a buscar: de frente, gira `giro`
-- grados a un lado, luego al otro, y vuelve de frente.
function CazaBusqueda.mirada(dir: Vector3, t: number, total: number, giro: number): Vector3
	local f = plano(dir)
	f = if f.Magnitude > 0.01 then f.Unit else Vector3.new(0, 0, -1)
	local a = math.sin(math.clamp(t / total, 0, 1) * 2 * math.pi) * math.rad(giro)
	local c, s = math.cos(a), math.sin(a)
	return Vector3.new(f.X * c + f.Z * s, 0, f.Z * c - f.X * s)
end

-- ¿Cruza la hoja de una puerta quien va de `desde` hacia `hacia`? Todo en planta. La hoja: su centro, su normal (a
-- cualquiera de los dos lados) y su ancho, con `margen` de más a cada lado. El tramo se alarga hasta `minimo` studs en
-- la misma dirección: el siguiente punto del camino puede quedar justo antes de la hoja. Parado (sin tramo), no.
function CazaBusqueda.cruzaPuerta(desde: Vector3, hacia: Vector3, centro: Vector3, normal: Vector3, ancho: number,
	margen: number, minimo: number): boolean
	local n = plano(normal)
	local tramo = plano(hacia - desde)
	local largo = tramo.Magnitude
	if n.Magnitude < 0.01 or largo < 0.01 then
		return false
	end
	n = n.Unit
	if largo < minimo then
		tramo = tramo.Unit * minimo
	end
	local a = plano(desde - centro)
	local sa, sb = a:Dot(n), (a + tramo):Dot(n)
	-- De un lado del plano de la hoja al otro (o desde el mismo plano, hacia un lado).
	if not ((sa <= 0 and sb > 0) or (sa >= 0 and sb < 0)) then
		return false
	end
	local corte = a + tramo * (sa / (sa - sb))
	local lado = Vector3.new(-n.Z, 0, n.X)
	return math.abs(corte:Dot(lado)) <= ancho / 2 + margen
end

-- Desde dónde mira un bicho: de su cabeza, salvo que entre la raíz y la cabeza haya algo (`golpe`, dónde choca un
-- rayo de la una a la otra): la cabeza va por delante de la raíz y, pegada a una pared, se mete en ella; un rayo que
-- nace dentro de una pieza no la ve, y veía y oía a través. Entonces, OJOS_ANTES studs antes del golpe (nunca por
-- detrás de la raíz).
local OJOS_ANTES = 0.2
function CazaBusqueda.ojos(raiz: Vector3, cabeza: Vector3, golpe: Vector3?): Vector3
	if not golpe then
		return cabeza
	end
	local d = golpe - raiz
	if d.Magnitude <= OJOS_ANTES then
		return raiz
	end
	return golpe - d.Unit * OJOS_ANTES
end

return CazaBusqueda
