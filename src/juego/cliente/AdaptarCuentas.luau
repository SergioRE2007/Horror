-- Las cuentas de los ojos que se acostumbran a la oscuridad (AdaptarVista, docs/sistemas/adaptar.md), sin nada de Roblox
-- salvo Vector3 para probarlas con Lune (tests/bancos/adaptar.luau).
--   La luz que te llega es una suma sin unidades (Config.Adaptar.Luz) que pasa a 0..1 con `juntar`.
--   Los ojos están "hechos" a una luz (`acostumbrar`): bajan despacio (Baja) y suben deprisa (Sube).
--   `efecto` saca lo que se pone en el ColorCorrectionEffect: hundido en negro si la luz cae de golpe, en grises si ya
--   estás hecho a la oscuridad y deslumbrado (blanco cálido, contraste hundido) si la luz sube de golpe.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local AdaptarCuentas = {}

local C = Config.Adaptar

local function suave01(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Un número de verdad (sin NaN ni infinitos) o `otro`.
local function bien(x: number, otro: number): number
	if x ~= x or x == math.huge or x == -math.huge then
		return otro
	end
	return x
end

-- La suma de luz pasada a 0..1 (nunca llega a 1).
function AdaptarCuentas.juntar(suma: number): number
	suma = bien(suma, 0)
	return 1 - math.exp(-math.max(suma, 0))
end

-- Lo que da una luz a `distancia` studs con ese `alcance` y `brillo` (antes del peso de Config).
function AdaptarCuentas.punto(distancia: number, alcance: number, brillo: number): number
	if distancia ~= distancia or alcance <= 0 or distancia >= alcance or brillo ~= brillo or brillo <= 0 then
		return 0
	end
	local k = 1 - math.max(distancia, 0) / alcance
	return k * k * brillo
end

-- De 0 a 1, cuánto te da un foco que apunta hacia `dir` con un cono de `angulo` grados (el entero, como SpotLight.Angle)
-- si tú estás hacia `haciaMi` desde él. El borde, suave.
function AdaptarCuentas.foco(haciaMi: Vector3, dir: Vector3, angulo: number): number
	if haciaMi.Magnitude < 1e-3 then
		return 1
	end
	if dir.Magnitude < 1e-6 or angulo <= 0 then
		return 0
	end
	local mitad = math.min(angulo, 180) / 2
	local cos = math.clamp(dir.Unit:Dot(haciaMi.Unit), -1, 1)
	local a = math.deg(math.acos(cos))
	if a >= mitad then
		return 0
	end
	return 1 - suave01((a - mitad * 0.8) / (mitad * 0.2))
end

-- De 0 a 1, lo de más que da tu linterna si el haz choca a `distancia` studs (nil: no choca con nada).
function AdaptarCuentas.rebote(distancia: number?): number
	if distancia == nil or distancia ~= distancia then
		return 0
	end
	return math.clamp(1 - distancia / C.Luz.RebotaHasta, 0, 1)
end

-- Lo que suma el relámpago (`destello`, 0..1) con `cieloVisto` (0..1, Ambiente.cieloVisto: fuera 1; dentro, en el sótano
-- o escondido, lo que de él calcula TormentaVista). Así los ojos siguen a la tormenta: en el sótano o en el armario,
-- casi nada.
function AdaptarCuentas.rayo(destello: number, cieloVisto: number): number
	return math.max(bien(destello, 0), 0) * C.Luz.Rayo * math.clamp(bien(cieloVisto, 1), 0, 1)
end

-- Los ojos, hechos a `hecho`, tras `dt` s con `luz` (las dos de 0 a 1): hacia la luz deprisa, hacia la oscuridad despacio.
function AdaptarCuentas.acostumbrar(hecho: number, luz: number, dt: number): number
	luz = math.clamp(bien(luz, 0), 0, 1)
	hecho = bien(hecho, luz)
	if dt ~= dt or dt <= 0 then
		return math.clamp(hecho, 0, 1)
	end
	local tau = if luz > hecho then C.Sube else C.Baja
	local k = 1 - math.exp(-math.min(dt, 0.5) / tau)
	return math.clamp(hecho + (luz - hecho) * k, 0, 1)
end

-- De 0 a 1, cuánto están los ojos acostumbrados a la oscuridad (hechos a menos que Claro; entero a Oscuro).
function AdaptarCuentas.acostumbrado(hecho: number): number
	hecho = bien(hecho, 1)
	return suave01((C.Claro - hecho) / (C.Claro - C.Oscuro))
end

-- De 0 a 1, lo que se nota un salto de luz de `antes` a `ahora` (solo hacia arriba: para hacia abajo, al revés).
function AdaptarCuentas.salto(antes: number, ahora: number): number
	local r = (ahora - antes) / (math.max(antes, 0) + C.Relativo)
	r = bien(r, 0)
	return math.clamp((r - C.Desde) / (C.Pleno - C.Desde), 0, 1)
end

-- Sigue a `meta` (0..1) desde `actual` en `dt` s: entra en Entra s, se va en Sale (la linterna de otro a la cara).
function AdaptarCuentas.seguir(actual: number, meta: number, dt: number): number
	meta = math.clamp(bien(meta, 0), 0, 1)
	actual = math.clamp(bien(actual, 0), 0, 1)
	if dt ~= dt or dt <= 0 then
		return actual
	end
	local A = C.Ajena
	local tau = if meta > actual then A.Entra else A.Sale
	local v = actual + (meta - actual) * (1 - math.exp(-math.min(dt, 0.5) / tau))
	if math.abs(v - meta) < 1e-3 then
		v = meta
	end
	return v
end

-- De 0 a 1, lo que te deslumbra la linterna de otro que sale de `origen` hacia `dir` si tu cámara está en `ojo` (sin
-- mirar paredes: eso, AdaptarVista). Más cerca y más al centro del haz, más.
function AdaptarCuentas.apunta(origen: Vector3, dir: Vector3, ojo: Vector3): number
	local A = C.Ajena
	local d = ojo - origen
	local distancia = d.Magnitude
	if distancia ~= distancia or distancia < 1e-3 or distancia > A.Lejos or dir.Magnitude < 1e-6 then
		return 0
	end
	local cos = math.clamp(dir.Unit:Dot(d / distancia), -1, 1)
	local a = math.deg(math.acos(cos))
	if a >= A.Angulo then
		return 0
	end
	local kAngulo = 1 - suave01(a / A.Angulo)
	local kDistancia = 1 - (distancia / A.Lejos) ^ 2
	return math.clamp(kAngulo * kDistancia, 0, 1)
end

export type Efecto = {
	brillo: number, -- Brightness
	contraste: number, -- Contrast
	saturacion: number, -- Saturation
	frio: number, -- 0..1: cuánto del tinte frío de acostumbrado (Acostumbrado.Frio)
	calido: number, -- 0..1: cuánto del blanco cálido del deslumbre (Deslumbre.Calido)
}

-- Lo que se pone en el ColorCorrectionEffect con los ojos hechos a `hecho`, la `luz` de ahora (0..1) y `ajena` (0..1, la
-- linterna de otro a la cara, ya con su fuerza).
function AdaptarCuentas.efecto(hecho: number, luz: number, ajena: number): Efecto
	hecho = math.clamp(bien(hecho, 0), 0, 1)
	luz = math.clamp(bien(luz, 0), 0, 1)
	local hundido = AdaptarCuentas.salto(luz, hecho) -- la luz cayó: los ojos aún están hechos a más
	local deslumbre = math.max(AdaptarCuentas.salto(hecho, luz), math.clamp(bien(ajena, 0), 0, 1))
	local acostumbrado = AdaptarCuentas.acostumbrado(hecho) * (1 - deslumbre)
	local H, D = C.Acostumbrado, C.Deslumbre
	return {
		brillo = C.Hundido * hundido + H.Brillo * acostumbrado * (1 - hundido) + D.Brillo * deslumbre,
		contraste = D.Contraste * deslumbre,
		saturacion = H.Saturacion * acostumbrado + D.Saturacion * deslumbre,
		frio = acostumbrado,
		calido = deslumbre,
	}
end

-- Si el efecto no hace nada (para no tocar el ColorCorrectionEffect sin motivo).
function AdaptarCuentas.nada(e: Efecto): boolean
	return math.abs(e.brillo) < 1e-3 and math.abs(e.contraste) < 1e-3 and math.abs(e.saturacion) < 1e-3
		and e.frio < 1e-3 and e.calido < 1e-3
end

return AdaptarCuentas
