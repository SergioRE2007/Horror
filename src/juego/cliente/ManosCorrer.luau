-- Las cuentas de tus manos al correr (14.8, pedido por el usuario: "añadir la mecánica de correr…" y "todo animado e
-- inmersivo"). Librería sin start(), sin servicios ni estado: solo números, Vector3 y CFrame, para que un banco de Lune
-- la pueda cargar tal cual. La usan Manos (el vaivén y el temblor de lo que llevas en la mano; de ahí sale también la
-- luz de la linterna, EquipoVista) y ManosGestos (las capas "Correr" y "Tropiezo", para las manos libres).
--   Todo en el espacio de la cámara: +X a la derecha, +Y arriba, -Z adelante. `s`: 1 la mano derecha, -1 la izquierda.
--   Giros como Vector3 de radianes: X cabecea (negativo, hacia abajo), Y gira de lado, Z se ladea; alrededor de la
--   mano y con los ejes de la cámara (ManosCorrer.aplicar).
--   `fase`: la zancada, pi por paso (la misma cuenta que CuerpoVista y Pasos): una pisada cada vez que sin(fase) pasa
--   por 0.
--   Braceo: corriendo, cada mano libre va y viene, adelante y arriba (el puño asoma por abajo de la pantalla) y atrás y
--   abajo (fuera de la vista), una a destiempo de la otra, una vuelta cada dos pasos. Con la otra mano ocupada, menos
--   braceo; cansado, más bajo y más corto.
--   Vaivén (antes del muelle de Manos): lo que llevas en la mano va de lado con cada paso, baja en cada pisada y se
--   ladea. Nunca hacia delante: así la linterna no se mete en la pared más de lo que ya lo hacía.
--   Temblor (después del muelle, para que no se lo coma): corriendo, en cada pisada un golpe hacia abajo, un vaivén de
--   lado y un traqueteo; muy cansado, un temblor fino. Solo gira la mano (la punta de la linterna apenas se mueve: el
--   haz sí, lejos).
--   Respirar: muy cansado y sin correr, lo que llevas sube y baja con la respiración; agotado, las manos libres asoman
--   abajo y suben y bajan con ella.
--   Tropiezo: las manos libres se adelantan como para frenar la caída y vuelven; lo que llevas da un tirón hacia abajo
--   (la linterna alumbra el suelo) y vuelve.
local ManosCorrer = {}

-- Números a ojo (para mirarlos en Studio). Studs, radianes y segundos.
local CORRIENDO = 24 -- studs/s a los que se corre (16 × Config.Correr.Factor): ahí el vaivén y el temblor son enteros
-- Abajo, fuera de la vista: como el REPOSO de Manos (dedos y dorso de CFrame.Angles(-80°, 0, 0)).
local BAJO = {
	pos = Vector3.new(0.8, -2.5, -0.45),
	dedos = Vector3.new(0, -0.985, -0.174),
	dorso = Vector3.new(0, 0.174, -0.985),
}
local BRACEO = {
	atras = Vector3.new(0.85, -1.9, -0.35), -- la palma atrás del todo (fuera de la vista)
	delante = Vector3.new(0.45, -0.72, -0.98), -- y delante del todo: el puño asoma abajo, hacia el centro
	curva = Vector3.new(0.06, 0, -0.14), -- lo que se sale el camino a medio ir (hacia fuera y hacia delante)
	dedosDelante = Vector3.new(-0.35, 0.75, -0.55), -- delante, el antebrazo hacia arriba y hacia dentro
	dedosAtras = Vector3.new(0, -0.25, -1),
	dorso = Vector3.new(1, 0.15, 0), -- la palma hacia dentro (hacia la otra mano), como un puño
	codo = Vector3.new(0.45, -0.7, 0.55), -- el codo hacia atrás, abajo y fuera
	menos = 0.6, -- con la otra mano ocupada, el braceo va hasta delante pero vuelve solo este tanto
	cansado = 0.3, -- cansado del todo, este tanto menos de vuelta...
	cansadoBaja = 0.12, -- ...y las manos este tanto más bajas
}
local JADEO = { -- agotado: las manos libres asoman abajo, con las palmas hacia abajo
	pos = Vector3.new(0.55, -0.7, -0.92), -- asoman un poco por abajo (más abajo, no se veían)
	dedos = Vector3.new(-0.3, -0.35, -1),
	dorso = Vector3.new(0.25, 1, 0.1),
	codo = Vector3.new(0.7, -1, 0.2),
	sube = 0.05, -- lo que suben y bajan con cada respiración
}
local FRENA = { -- tropiezo: las manos delante, abiertas, con las palmas hacia delante y abajo
	pos = Vector3.new(0.48, -0.6, -1.3),
	dedos = Vector3.new(0.1, 0.6, -1),
	dorso = Vector3.new(0.15, 0.6, 0.8),
	codo = Vector3.new(0.6, -0.8, 0.1),
	arriba = 0.5, -- s que se quedan delante (el muelle las lleva; la vista cae en 0,2 y se queda abajo 0,15)
	vuelve = 0.7, -- s que tardan en volver
	golpe = 0.2, -- s a los que "da con el suelo" (cuando la vista llega abajo)...
	golpeDura = 0.15, -- ...lo que dura el golpe...
	golpeBaja = 0.07, -- ...y lo que bajan las manos con él
}
local LLEVA = { -- tropiezo, con algo en la mano
	baja = 0.16,
	atras = 0.05, -- hacia ti, nunca hacia delante
	cabecea = math.rad(-10), -- la linterna alumbra el suelo
	ladea = math.rad(5),
}
local VAIVEN = { -- corriendo, lo que llevas en la mano (antes del muelle, que se come un cuarto)
	lado = 0.045, -- de lado con cada paso
	baja = 0.06, -- baja en cada pisada...
	atras = 0.03, -- ...y viene hacia ti
	ladea = math.rad(4),
}
local TEMBLOR = {
	golpe = math.rad(1.6), -- corriendo, lo que cabecea en cada pisada...
	sube = 0.08, -- ...en qué parte del paso llega abajo del todo (0..1 del paso)...
	apaga = 6, -- ...y lo deprisa que vuelve
	lado = math.rad(1.2), -- de lado con cada paso
	traqueteo = math.rad(0.7), -- el traqueteo corriendo...
	rapido = 7, -- ...sus vueltas por segundo
	cansado = math.rad(0.6), -- muy cansado, el temblor fino...
	fino = 11, -- ...sus vueltas por segundo
	desde = 0.3, -- cansancio desde el que se nota (sin aguante del todo o agotado, entero)
}
local RESPIRA = {
	ritmo = 1.3, -- radianes por segundo, descansado (como CuerpoVista)
	cansado = 2.4, -- de más, agotado
	hondo = 0.045, -- studs que sube y baja lo que llevas, agotado
	cabecea = math.rad(1.2),
	desde = 0.35, -- cansancio desde el que se nota
}

local function entre01(x: number): number
	return if x ~= x then 0 else math.clamp(x, 0, 1)
end

local function suave(x: number): number
	x = entre01(x)
	return x * x * (3 - 2 * x)
end

local function espejo(v: Vector3, s: number): Vector3
	return Vector3.new(v.X * s, v.Y, v.Z)
end

-- De 0 a 1, lo cansado que se nota (0 por debajo de `desde`).
local function muyCansado(cansancio: number, desde: number): number
	return entre01((cansancio - desde) / (1 - desde))
end

-- De 0 a 1, lo deprisa que vas para el vaivén y el temblor (entero a CORRIENDO studs/s).
function ManosCorrer.deprisa(rapidez: number): number
	return entre01(rapidez / CORRIENDO)
end

-- La zancada tras `dt` s a `rapidez` studs/s con pasos de `zancada` studs (CuerpoVista.zancada). Da la vuelta cada dos
-- pasos (2 pi) para no perder precisión en una partida larga.
function ManosCorrer.fase(fase: number, rapidez: number, dt: number, zancada: number): number
	return (fase + math.max(rapidez, 0) * math.max(dt, 0) / math.max(zancada, 0.1) * math.pi) % (2 * math.pi)
end

-- La respiración con `cansancio` (0..1): su ritmo (radianes por segundo), lo que sube y baja lo que llevas (studs) y lo
-- que cabecea con ella (radianes).
function ManosCorrer.respiracion(cansancio: number): (number, number, number)
	local c = entre01(cansancio)
	local muy = muyCansado(c, RESPIRA.desde)
	return RESPIRA.ritmo + RESPIRA.cansado * c, RESPIRA.hondo * muy, RESPIRA.cabecea * muy
end

-- Una mano libre con `ritmo` de correr (0..1, CorrerVista.ritmo), `jadeo` (0..1: agotado, cuánto asoman) en `respiro`
-- (la fase de la respiración), `cansancio` y `menos` (0..1: la otra mano está ocupada). Devuelve dónde va la palma,
-- hacia dónde los dedos y el dorso, y hacia dónde sale el codo (en la cámara). Con todo a 0, abajo (fuera de la vista).
function ManosCorrer.manoLibre(s: number, fase: number, ritmo: number, jadeo: number, respiro: number,
	cansancio: number, menos: number): (Vector3, Vector3, Vector3, Vector3)
	local c = entre01(cansancio)
	-- El braceo: k de 0 (atrás) a 1 (delante). Menos braceo, igual de delante (que se siga viendo) pero menos atrás.
	local vuelta = (1 - (1 - BRACEO.menos) * entre01(menos)) * (1 - BRACEO.cansado * c)
	local va = math.sin(fase + (if s > 0 then 0 else math.pi)) -- de -1 (atrás) a 1 (delante), a destiempo
	local k = 1 - vuelta * (1 - va) / 2
	local pos = espejo(BRACEO.atras, s):Lerp(espejo(BRACEO.delante, s), k)
		+ espejo(BRACEO.curva, s) * math.sin(math.pi * k) - Vector3.new(0, BRACEO.cansadoBaja * c, 0)
	local dedos = espejo(BRACEO.dedosAtras, s):Lerp(espejo(BRACEO.dedosDelante, s), k)
	local dorso = espejo(BRACEO.dorso, s)
	local codo = espejo(BRACEO.codo, s)
	local w = suave(ritmo)
	pos = espejo(BAJO.pos, s):Lerp(pos, w)
	dedos = BAJO.dedos:Lerp(dedos, w)
	dorso = BAJO.dorso:Lerp(dorso, w)
	-- Agotado (y ya sin correr): asoman abajo y suben y bajan con la respiración.
	local j = suave(jadeo) * (1 - w)
	if j > 0 then
		local arriba = espejo(JADEO.pos, s) + Vector3.new(0, math.sin(respiro) * JADEO.sube, 0)
		pos = pos:Lerp(arriba, j)
		dedos = dedos:Lerp(espejo(JADEO.dedos, s), j)
		dorso = dorso:Lerp(espejo(JADEO.dorso, s), j)
		codo = codo:Lerp(espejo(JADEO.codo, s), j)
	end
	return pos, dedos, dorso, codo
end

-- De 0 a 1, cuánto están delante las manos a los `t` s de tropezar (1 nada más tropezar: el muelle las lleva; 0 al
-- acabar).
function ManosCorrer.tropiezo(t: number): number
	if t ~= t or t < 0 then
		return 0
	elseif t < FRENA.arriba then
		return 1
	end
	return 1 - suave((t - FRENA.arriba) / FRENA.vuelve)
end

-- Una mano libre a los `t` s de tropezar: como manoLibre (palma, dedos, dorso y codo, en la cámara). Al acabar, abajo.
function ManosCorrer.frenar(s: number, t: number): (Vector3, Vector3, Vector3, Vector3)
	local f = ManosCorrer.tropiezo(t)
	local golpe = (t - FRENA.golpe) / FRENA.golpeDura
	local baja = if golpe > 0 and golpe < 1 then math.sin(math.pi * golpe) * FRENA.golpeBaja else 0
	local pos = espejo(BAJO.pos, s):Lerp(espejo(FRENA.pos, s) - Vector3.new(0, baja, 0), f)
	return pos, BAJO.dedos:Lerp(espejo(FRENA.dedos, s), f), BAJO.dorso:Lerp(espejo(FRENA.dorso, s), f),
		espejo(FRENA.codo, s)
end

-- Lo que llevas en la mano a los `t` s de tropezar: lo que se mueve y lo que gira (en la cámara).
function ManosCorrer.tropiezoLleva(s: number, t: number): (Vector3, Vector3)
	local f = ManosCorrer.tropiezo(t)
	if f <= 0 then
		return Vector3.zero, Vector3.zero
	end
	return Vector3.new(0, -LLEVA.baja, LLEVA.atras) * f, Vector3.new(LLEVA.cabecea, 0, LLEVA.ladea * s) * f
end

-- Corriendo, lo que llevas en la mano con `peso` (0..1: ritmo × lo deprisa que vas): lo que se mueve y lo que gira.
function ManosCorrer.vaiven(fase: number, peso: number): (Vector3, Vector3)
	local p = entre01(peso)
	if p <= 0 then
		return Vector3.zero, Vector3.zero
	end
	local va = math.sin(fase)
	local pisa = 1 - math.abs(va) -- 1 en cada pisada
	return Vector3.new(va * VAIVEN.lado, -pisa * VAIVEN.baja, pisa * VAIVEN.atras) * p,
		Vector3.new(0, 0, va * VAIVEN.ladea * p)
end

-- Muy cansado y sin correr (`quieto` 0..1, lo que no se corre: 1 - ritmo), lo que llevas en `respiro`: lo que sube y
-- baja y lo que cabecea.
function ManosCorrer.respirar(respiro: number, cansancio: number, quieto: number): (Vector3, Vector3)
	local _, hondo, cabecea = ManosCorrer.respiracion(cansancio)
	local q = entre01(quieto)
	if hondo <= 0 or q <= 0 then
		return Vector3.zero, Vector3.zero
	end
	local r = math.sin(respiro)
	return Vector3.new(0, r * hondo * q, 0), Vector3.new(r * cabecea * q, 0, 0)
end

-- Lo que gira la mano que lleva algo a los `t` s (os.clock) en `fase`, con `peso` de correr (0..1) y `cansancio`;
-- `semilla` distinta por mano para que no tiemblen igual. Solo giros (radianes, en la cámara).
function ManosCorrer.temblor(t: number, fase: number, peso: number, cansancio: number, semilla: number): Vector3
	local p = entre01(peso)
	local tiembla = TEMBLOR.cansado * muyCansado(entre01(cansancio), TEMBLOR.desde)
	if p <= 0 and tiembla <= 0 then
		return Vector3.zero
	end
	local cabecea, gira, ladea = 0, 0, 0
	if p > 0 then
		-- En cada pisada, un golpe hacia abajo (llega enseguida y se apaga), y de lado con cada paso.
		local u = (fase % math.pi) / math.pi
		local golpe = if u < TEMBLOR.sube then u / TEMBLOR.sube else math.exp(-(u - TEMBLOR.sube) * TEMBLOR.apaga)
		cabecea -= golpe * TEMBLOR.golpe * p
		gira += math.sin(fase) * TEMBLOR.lado * p
		local tr = TEMBLOR.traqueteo * p * 1.6 -- math.noise casi nunca pasa de ±0,6
		cabecea += math.noise(t * TEMBLOR.rapido, semilla, 0.31) * tr
		gira += math.noise(t * TEMBLOR.rapido, semilla + 4.7, 0.73) * tr
	end
	if tiembla > 0 then
		local tf = tiembla * 1.6
		cabecea += math.noise(t * TEMBLOR.fino, semilla + 9.1, 0.17) * tf
		gira += math.noise(t * TEMBLOR.fino, semilla + 13.3, 0.59) * tf
		ladea += math.noise(t * TEMBLOR.fino, semilla + 17.9, 0.41) * tf * 0.5
	end
	return Vector3.new(cabecea, gira, ladea)
end

-- `rel` (una palma en la cámara) movida `desp` y girada `giro` alrededor de ella misma, con los ejes de la cámara.
function ManosCorrer.aplicar(rel: CFrame, desp: Vector3, giro: Vector3): CFrame
	if giro == Vector3.zero then
		return rel + desp
	end
	return CFrame.new(rel.Position + desp) * CFrame.Angles(giro.X, giro.Y, giro.Z) * rel.Rotation
end

return ManosCorrer
