-- Las cuentas de la casa que se desordena (DesordenVista, docs/sistemas/desorden.md), aparte para probarlas con Lune
-- (tests/bancos/desorden.luau). Lo que cae y en qué orden sale de una cuenta fija (de dónde vino el golpe, su número y
-- los adornos ordenados por posición): todos los clientes tiran las mismas cosas sin hablar entre ellos.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local DesordenCuentas = {}

local D = Config.Desorden
local DOS32 = 4294967296

-- a * b en 32 bits sin perder cifras (los double solo tienen 53).
local function mul32(a: number, b: number): number
	local bajo = (a % 65536) * b
	local alto = ((a // 65536) * b) % 65536
	return (bajo + alto * 65536) % DOS32
end

-- Un número de 0 a 2^32 - 1 que sale siempre igual del mismo texto (sdbm y una mezcla final).
function DesordenCuentas.hash(texto: string): number
	local h = 0
	for i = 1, #texto do
		h = (string.byte(texto, i) + h * 65599) % DOS32
	end
	h = bit32.bxor(h, bit32.rshift(h, 16))
	h = mul32(h, 0x45d9f3b)
	h = bit32.bxor(h, bit32.rshift(h, 16))
	return h
end

-- La semilla de un golpe: de dónde viene (una puerta, una ventana o la pisada de un bicho) y su número.
function DesordenCuentas.semilla(clave: string, n: number): number
	return DesordenCuentas.hash(clave .. "#" .. tostring(n))
end

-- El número `i` (de 0 a 1, sin llegar a 1) de los que salen de una semilla.
function DesordenCuentas.numero(semilla: number, i: number): number
	return DesordenCuentas.hash(tostring(semilla) .. ":" .. tostring(i)) / DOS32
end

-- Un sitio como texto, redondeado al stud (igual en todos los clientes: las piezas son las del servidor).
function DesordenCuentas.clave(x: number, y: number, z: number): string
	return string.format("%d,%d,%d", math.floor(x + 0.5), math.floor(y + 0.5), math.floor(z + 0.5))
end

-- La casilla del suelo en la que está un bicho (para las pisadas fuertes): cambia cada Pisada.Celda studs.
function DesordenCuentas.celda(x: number, y: number, z: number): string
	local c = D.Pisada.Celda
	return string.format("%d,%d,%d", math.floor(x / c), math.floor(y / 10), math.floor(z / c))
end

-- Si una pisada fuerte en esa casilla tira algo (no todas: sería un no parar).
function DesordenCuentas.pisadaTira(clave: string): boolean
	return DesordenCuentas.numero(DesordenCuentas.hash(clave), 0) < D.Pisada.Prob
end

-- Cuántas cosas caen con un golpe: de Caen[1] a Caen[2]; con Rendimiento, una.
function DesordenCuentas.cuantos(semilla: number, poco: boolean): number
	if poco then
		return 1
	end
	local a, b = D.Caen[1], D.Caen[2]
	return a + math.floor(DesordenCuentas.numero(semilla, 100) * (b - a + 1))
end

-- Cuántos trozos salen de un plato o una botella rota.
function DesordenCuentas.trozos(semilla: number): number
	local a, b = D.Trozos[1], D.Trozos[2]
	return a + math.floor(DesordenCuentas.numero(semilla, 200) * (b - a + 1))
end

-- Un número entre a y b sacado de la semilla (el `i` lo distingue de los demás).
function DesordenCuentas.entre(semilla: number, i: number, a: number, b: number): number
	return a + (b - a) * DesordenCuentas.numero(semilla, i)
end

export type Candidato = { borde: number, x: number, y: number, z: number }

-- Orden fijo: primero los que están más cerca del borde; a igual borde, por posición.
local function antes(a: Candidato, b: Candidato): boolean
	if a.borde ~= b.borde then
		return a.borde < b.borde
	end
	if a.x ~= b.x then
		return a.x < b.x
	end
	if a.y ~= b.y then
		return a.y < b.y
	end
	return a.z < b.z
end

-- Elige `cuantos` de los candidatos: cada vez uno de los Ventana más cerca del borde que quedan, según la semilla.
-- Devuelve los elegidos en el orden en que caen (no toca la lista que se le da).
function DesordenCuentas.elegir<T>(candidatos: { T & Candidato }, cuantos: number, semilla: number): { T & Candidato }
	local resto = table.clone(candidatos)
	table.sort(resto, antes)
	local elegidos = {}
	for k = 1, math.min(cuantos, #resto) do
		local ventana = math.min(D.Ventana, #resto)
		local i = 1 + math.floor(DesordenCuentas.numero(semilla, k) * ventana)
		table.insert(elegidos, table.remove(resto, i))
	end
	return elegidos
end

-- Lo cerca que está un punto (lx, lz, en los ejes de la balda) de cada borde de una balda de medio ancho hx y medio
-- fondo hz. Devuelve los cuatro bordes del más cercano al más lejano: { distancia, eje (1 = x, 2 = z), signo }.
function DesordenCuentas.bordes(lx: number, lz: number, hx: number, hz: number): { { number } }
	local l = {
		{ math.max(0, hx - lx), 1, 1 },
		{ math.max(0, hx + lx), 1, -1 },
		{ math.max(0, hz - lz), 2, 1 },
		{ math.max(0, hz + lz), 2, -1 },
	}
	table.sort(l, function(a, b)
		if a[1] ~= b[1] then
			return a[1] < b[1]
		end
		return a[2] * 2 + a[3] < b[2] * 2 + b[3] -- empate: siempre el mismo
	end)
	return l
end

-- Lo que sobresale una caja (ejes `rot`, tamaño `tam`) en la dirección horizontal `dir` desde su centro.
function DesordenCuentas.saliente(rot: CFrame, tam: Vector3, dir: Vector3): number
	return math.abs(dir:Dot(rot.RightVector)) * tam.X / 2 + math.abs(dir:Dot(rot.UpVector)) * tam.Y / 2
		+ math.abs(dir:Dot(rot.LookVector)) * tam.Z / 2
end

-- Volcar una caja de pie (centro `caja`, tamaño `tam`) hacia `dir` (horizontal) `angulo` radianes sobre el canto de
-- abajo de ese lado: lo que hay que aplicar a cada pieza (nueva = giro * vieja). A 90° queda tumbada en el suelo de
-- antes, con la cara de ese lado abajo.
function DesordenCuentas.volcar(caja: CFrame, tam: Vector3, dir: Vector3, angulo: number): CFrame
	local d = Vector3.new(dir.X, 0, dir.Z)
	if d.Magnitude < 1e-4 then
		return CFrame.identity
	end
	d = d.Unit
	local bajo = caja.Position.Y - DesordenCuentas.saliente(caja.Rotation, tam, Vector3.yAxis)
	local canto = Vector3.new(caja.Position.X, bajo, caja.Position.Z) + d * DesordenCuentas.saliente(caja.Rotation, tam, d)
	local eje = Vector3.new(0, 1, 0):Cross(d) -- girar sobre él lleva lo de arriba hacia `d`
	return CFrame.new(canto) * CFrame.fromAxisAngle(eje, angulo) * CFrame.new(-canto)
end

-- El ángulo de una silla que vuelca a los `t` (de 0 a 1) de su caída: cae cada vez más deprisa y, si `rebota`, da un
-- botecito al llegar al suelo (sin pasar de 90°: no se mete en él).
function DesordenCuentas.caida(t: number, rebota: boolean): number
	t = math.clamp(t, 0, 1)
	local recto = math.pi / 2
	if not rebota then
		return recto * t * t
	end
	local llega = 0.7
	if t < llega then
		local k = t / llega
		return recto * k * k
	end
	return recto - math.rad(D.Silla.Rebote) * math.sin(math.pi * (t - llega) / (1 - llega))
end

-- La mecedora que se aparta (de 0 a 1): sale deprisa y frena.
function DesordenCuentas.aparta(t: number): number
	t = math.clamp(t, 0, 1)
	return 1 - (1 - t) * (1 - t)
end

-- La distancia en planta de un punto a una caja (centro y ejes `caja`, medio tamaño en planta hx y hz).
function DesordenCuentas.aCaja(p: Vector3, caja: CFrame, hx: number, hz: number): number
	local l = caja:PointToObjectSpace(p)
	local dx = math.max(0, math.abs(l.X) - hx)
	local dz = math.max(0, math.abs(l.Z) - hz)
	return math.sqrt(dx * dx + dz * dz)
end

-- Si un tramo (lo que ha andado un bicho desde la última mirada) pasa a menos de `roce` de la caja. Se mira cada
-- medio stud del tramo, para no saltarse una silla entre dos miradas.
function DesordenCuentas.roza(a: Vector3, b: Vector3, caja: CFrame, hx: number, hz: number, roce: number): boolean
	local largo = (b - a).Magnitude
	local pasos = math.max(1, math.ceil(largo / 0.5))
	for i = 0, pasos do
		if DesordenCuentas.aCaja(a:Lerp(b, i / pasos), caja, hx, hz) < roce then
			return true
		end
	end
	return false
end

-- Si un cambio en la velocidad de caída (de `vieja` a `ahora`, la y) es el de dar contra algo: venía cayendo deprisa
-- y de repente frena.
function DesordenCuentas.choca(vieja: number, ahora: number): boolean
	return vieja < -D.Choque and ahora - vieja > D.Choque * 0.6
end

return DesordenCuentas
