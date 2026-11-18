-- Las cuentas del pavor al ver un bicho (PavorVista, docs/sistemas/pavor.md), sin nada de Roblox para probarlas con
-- Lune (tests/bancos/pavor.luau). Las usan PavorVista (cuándo y cuánto), CuerpoVista (el retraso al girar) y Manos (el
-- temblor de las manos y la linterna).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local PavorCuentas = {}

local C = Config.Pavor

local function suave01(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function lerp(a: number, b: number, k: number): number
	return a + (b - a) * k
end

-- De Minimo a 1: lo fuerte que es ver un bicho a `distancia` studs (0 si está más lejos que Lejos).
function PavorCuentas.fuerza(distancia: number): number
	if distancia ~= distancia or distancia > C.Lejos then
		return 0
	end
	local x = math.clamp((distancia - C.Cerca) / (C.Lejos - C.Cerca), 0, 1)
	return lerp(1, C.Minimo, x)
end

-- De 0 a 1, el vértigo a los `t` s de verlo: se cierra suave en Cierra s, se queda Queda s y vuelve despacio.
function PavorCuentas.vertigo(t: number): number
	local v = C.Vertigo
	if t ~= t or t < 0 then
		return 0
	end
	if t < v.Cierra then
		return suave01(t / v.Cierra)
	end
	local queda = v.Cierra + v.Queda
	if t < queda then
		return 1
	end
	return 1 - suave01((t - queda) / v.Vuelve)
end

-- Lo que dura el vértigo entero (después, 0).
function PavorCuentas.finVertigo(): number
	local v = C.Vertigo
	return v.Cierra + v.Queda + v.Vuelve
end

-- Los s que dura el pavor con esa `fuerza` (más cerca, más).
function PavorCuentas.dura(fuerza: number): number
	local k = math.clamp((fuerza - C.Minimo) / (1 - C.Minimo), 0, 1)
	return lerp(C.Dura[1], C.Dura[2], k)
end

-- El pavor que queda a los `t` s de un susto de `fuerza` que dura `dura` s: baja poco a poco hasta 0.
function PavorCuentas.queda(t: number, fuerza: number, dura: number): number
	if t ~= t or dura <= 0 or t >= dura then
		return 0
	end
	return fuerza * (1 - math.max(t, 0) / dura) ^ C.Baja
end

-- Un susto nuevo de `fuerza` con `ahora` de pavor: el nivel desde el que empieza a bajar (nunca menos que lo que había).
function PavorCuentas.sumar(ahora: number, fuerza: number): number
	return math.clamp(math.max(ahora, fuerza), 0, 1)
end

-- De 0 a 1, el volumen del latido a los `t` s de verlo con `fuerza`: entero un rato (más cerca, más) y se apaga.
function PavorCuentas.latido(t: number, fuerza: number): number
	local l = C.Latido
	if t ~= t or t < 0 then
		return 0
	end
	local k = math.clamp((fuerza - C.Minimo) / (1 - C.Minimo), 0, 1)
	local entero = lerp(l.Dura[1], l.Dura[2], k)
	if t < entero then
		return 1
	end
	return 1 - suave01((t - entero) / l.Apaga)
end

-- Lo que dura el latido con esa `fuerza`, apagándose incluido.
function PavorCuentas.finLatido(fuerza: number): number
	local l = C.Latido
	local k = math.clamp((fuerza - C.Minimo) / (1 - C.Minimo), 0, 1)
	return lerp(l.Dura[1], l.Dura[2], k) + l.Apaga
end

-- De 0 a 1, lo que queda de una persecución (el latido, la respiración) a los `t` s de que el bicho deje de perseguirte:
-- entera hasta entonces (t <= 0) y se apaga en Latido.Apaga s.
function PavorCuentas.trasPersecucion(t: number): number
	if t ~= t then
		return 0
	end
	if t <= 0 then
		return 1
	end
	return 1 - suave01(t / C.Latido.Apaga)
end

-- Lo que debería tener ahora la visión de túnel (0..1): `susto`, lo que queda de ver un bicho (su latido por su fuerza,
-- 0..1); `sigue`, lo que queda de una persecución (trasPersecucion). Perseguido pesa más que solo verlo.
function PavorCuentas.tunelMeta(susto: number, sigue: number): number
	local T = C.Tunel
	local m = math.max(susto * T.Ver, sigue * C.Persigue.Tunel)
	if m ~= m then
		return 0
	end
	return math.clamp(m, 0, 1)
end

-- Un paso de `dt` s de la visión de túnel de `antes` hacia `meta`: entra del todo en Tunel.Entra s y sale en Tunel.Sale.
function PavorCuentas.acercarTunel(antes: number, meta: number, dt: number): number
	local T = C.Tunel
	if antes ~= antes or meta ~= meta or dt ~= dt then
		return 0
	end
	local d = math.clamp(dt, 0, 0.25)
	if meta > antes then
		return math.min(meta, antes + d / T.Entra)
	end
	return math.max(meta, antes - d / T.Sale)
end

-- Un golpe del corazón a `x` (0..1) de su vuelta: se cierra deprisa y se abre más despacio.
local function golpe(x: number): number
	if x < 0 then
		return 0
	end
	local sube = 0.05
	if x < sube then
		return suave01(x / sube)
	end
	return math.exp(-(x - sube) / 0.1)
end

-- Cómo se ve la visión de túnel con `nivel` (0..1, ya suavizado con acercarTunel) y `sigue` (la persecución, 0..1), a los
-- `t` s (os.clock; nil: sin latir, con Rendimiento). Devuelve lo negro del borde (0..1), la parte de la pantalla que cubre
-- por cada lado, y la Saturation y el Contrast del ColorCorrection. Late a Tunel.Latir golpes por segundo, cada uno
-- doble ("pum-pum"), más fuerte perseguido.
function PavorCuentas.tunel(nivel: number, sigue: number, t: number?): (number, number, number, number)
	local T = C.Tunel
	local k = if nivel == nivel then math.clamp(nivel, 0, 1) else 0
	if k <= 0 then
		return 0, 0, 0, 0
	end
	-- El golpe de ahora (0..1): entero perseguido, algo menos viéndolo solo.
	local latir = 0
	if t and t == t and math.abs(t) < 1e9 then
		local fase = (t * T.Latir) % 1
		local s = if sigue == sigue then math.clamp(sigue, 0, 1) else 0
		latir = math.max(golpe(fase), 0.6 * golpe(fase - 0.24)) * (0.4 + 0.6 * s)
	end
	-- Sin golpe se queda en (1 - Golpe) de lo suyo; cada golpe lo cierra hasta lo entero.
	local cierra = math.clamp(k * (1 - T.Golpe + T.Golpe * latir), 0, 1)
	local oscuro = math.clamp(T.Bordes * math.min(1, cierra * 1.6), 0, 1)
	return oscuro, lerp(T.Ancho[1], T.Ancho[2], cierra), T.Color * k, T.Contraste * k
end

-- El temblor de una mano con `pavor` (0..1) a los `t` s (os.clock): giro (cabecea, gira, ladea; radianes) y
-- desplazamiento (studs, en la cámara). Uno fino y deprisa y otro lento e irregular, con algún tirón. `semilla`: para que
-- cada mano tiemble a su manera.
function PavorCuentas.temblor(t: number, pavor: number, semilla: number): (Vector3, Vector3)
	local p = math.clamp(pavor, 0, 1)
	if p <= 0 or t ~= t then
		return Vector3.zero, Vector3.zero
	end
	local T = C.Temblor
	-- math.noise casi nunca pasa de ±0,6: por 1,6 llega a ±1 de vez en cuando.
	local fino = T.Giro * p * 1.6 * 0.45
	local lento = T.Giro * p * 1.6 * 0.75
	local f, l = t * T.Fino, t * T.Lento
	local cabecea = math.noise(f, semilla + 21.3, 0.11) * fino + math.noise(l, semilla + 31.7, 0.53) * lento
	local gira = math.noise(f, semilla + 25.9, 0.37) * fino + math.noise(l, semilla + 36.1, 0.29) * lento
	local ladea = math.noise(f, semilla + 28.4, 0.71) * fino * 0.6
	local m = T.Mueve * p * 1.6
	local mueve = Vector3.new(math.noise(f, semilla + 41.2, 0.19) * m, math.noise(f, semilla + 44.8, 0.63) * m, 0)
	return Vector3.new(cabecea, gira, ladea), mueve
end

-- El retraso de la vista al girar rápido. `dx`, `dy`: dónde queda la mirada del fotograma anterior en el espacio de la
-- cámara de ahora (LookVector de antes visto desde la de ahora: X y Y), en `dt` s. `antes`: el retraso del fotograma
-- anterior (cabeceo, giro; radianes). `peso`: 0..1 (el pavor). Devuelve el de ahora, suave: cabeceo (positivo: la vista
-- se queda arriba) y giro (positivo: se queda a la izquierda).
function PavorCuentas.retraso(dx: number, dy: number, dt: number, antesCabeceo: number, antesGiro: number,
	peso: number): (number, number)
	local R = C.Retraso
	local p = math.clamp(peso, 0, 1)
	local metaC, metaG = 0, 0
	if p > 0 and dt > 1e-4 and dx == dx and dy == dy then
		local function eje(rapidez: number): number
			local r = math.abs(rapidez) - R.Desde
			if r <= 0 then
				return 0
			end
			local x = math.min(r * R.Tiempo / R.Max, 10)
			local th = (math.exp(2 * x) - 1) / (math.exp(2 * x) + 1) -- tanh: crece y se queda en Max
			return th * R.Max * (if rapidez < 0 then -1 else 1)
		end
		-- Giras a la derecha: la mirada de antes queda a la izquierda (dx < 0) y la vista se queda atrás (a la
		-- izquierda: giro positivo). Bajas la vista: la de antes queda arriba (dy > 0) y la vista se queda arriba.
		metaG = -eje(dx / dt) * p
		metaC = eje(dy / dt) * p
	end
	local k = if dt > 0 then 1 - math.exp(-math.min(dt, 0.25) * R.Suave) else 0
	local c = antesCabeceo + (metaC - antesCabeceo) * k
	local g = antesGiro + (metaG - antesGiro) * k
	if c ~= c or g ~= g then
		return 0, 0
	end
	if math.abs(c) < 1e-5 then
		c = 0
	end
	if math.abs(g) < 1e-5 then
		g = 0
	end
	return math.clamp(c, -R.Max, R.Max), math.clamp(g, -R.Max, R.Max)
end

return PavorCuentas
