-- Las cuentas de llevar cosas pesadas (15.8, pedido por el usuario: "todo": físicas de verdad, al hombro, lanzar y que
-- haga ruido). Sin servicios de Roblox: las usan el servidor (Cargar), el cliente (CargarVista y ManosGestos) y se
-- prueban con Lune (tests/bancos/cargar.luau). Números en Config.Cargar y Config.Pesados.
--   CargarReglas.alHombro(tipo): si va al hombro (troncos y tablones) o delante con las dos manos.
--   CargarReglas.sitio(tipo, tam, raiz): dónde va y cómo de girado lo que lleva uno solo (sin balanceo).
--   CargarReglas.muelle(...): el giro que se queda atrás y se pasa un poco (el balanceo al girar).
--   CargarReglas.lanzamiento(tipo, carga, direccion): la velocidad al lanzarlo (nil si no vale).
--   CargarReglas.golpe(antes, ahora) y alcanceGolpe(fuerza): si ha dado contra algo y a cuánto se oye.
local Config = require(script.Parent.Config)

local CargarReglas = {}

local C, PESADOS = Config.Cargar, Config.Pesados
local ARRIBA = Vector3.new(0, 1, 0)

local function finito(n: number): boolean
	return n == n and n > -math.huge and n < math.huge
end

local function vectorFinito(v: Vector3): boolean
	return finito(v.X) and finito(v.Y) and finito(v.Z)
end

function CargarReglas.alHombro(tipo: string): boolean
	local datos = PESADOS[tipo]
	return datos ~= nil and datos.Hombro == true
end

function CargarReglas.lanzable(tipo: string): boolean
	local datos = PESADOS[tipo]
	return datos ~= nil and datos.Lanzar == true and datos.Peso == 1
end

-- Hacia delante en horizontal de un CFrame (si mira recto arriba o abajo, su arriba).
function CargarReglas.frente(cf: CFrame): Vector3
	local f = cf.LookVector * Vector3.new(1, 0, 1)
	if f.Magnitude < 0.01 then
		f = cf.UpVector * Vector3.new(1, 0, 1)
	end
	return if f.Magnitude > 0.01 then f.Unit else Vector3.new(0, 0, -1)
end

-- Dónde va lo que lleva uno solo, con su giro (el eje X de la pieza es lo largo). `raiz`: la del jugador (solo cuenta
-- hacia dónde mira en horizontal). Al hombro: a la derecha, apoyado encima del hombro y a lo largo hacia delante,
-- con la punta algo levantada. Delante: a la cintura, atravesado, como antes del 15.8.
function CargarReglas.sitio(tipo: string, tam: Vector3, raiz: CFrame): CFrame
	local f = CargarReglas.frente(raiz)
	local derecha = f:Cross(ARRIBA)
	local base = raiz.Position
	if CargarReglas.alHombro(tipo) then
		local h = C.Hombro
		local cabeceo = math.rad(h.Cabeceo)
		local eje = f * math.cos(cabeceo) + ARRIBA * math.sin(cabeceo)
		local hombro = base + derecha * h.Lado + ARRIBA * (h.Apoyo + tam.Y / 2)
		local centro = hombro + eje * (tam.X * h.Delante) -- más por delante que por detrás
		local arriba = (ARRIBA - eje * ARRIBA:Dot(eje)).Unit
		return CFrame.fromMatrix(centro, eje, arriba)
	end
	local centro = base + f * (C.Delante + 0.8 + tam.Z / 2) - ARRIBA * 0.6
	return CFrame.fromMatrix(centro, derecha, ARRIBA)
end

-- Ángulo (radianes) de `a` a `b` por el lado corto, de -pi a pi.
function CargarReglas.diferencia(a: number, b: number): number
	local d = (b - a) % (2 * math.pi)
	if d > math.pi then
		d -= 2 * math.pi
	end
	return d
end

-- Un paso del muelle que sigue tu giro: `angulo` y `vel` (rad/s) de lo que llevas hacia `objetivo` (tu giro).
-- Amortigua < 1: se pasa un poco y vuelve. Nunca se queda atrás más de Balanceo.MaxRetraso grados.
function CargarReglas.muelle(angulo: number, vel: number, objetivo: number, dt: number): (number, number)
	local b = C.Balanceo
	dt = math.clamp(dt, 0, 0.1)
	if not (finito(angulo) and finito(vel)) then
		return objetivo, 0
	end
	local w = b.Giro
	local pasos = math.max(1, math.ceil(dt / (1 / 120))) -- pasos cortos: estable aunque el fotograma tarde
	local h = dt / pasos
	for _ = 1, pasos do
		local d = CargarReglas.diferencia(angulo, objetivo)
		vel += (w * w * d - 2 * b.Amortigua * w * vel) * h
		angulo += vel * h
	end
	local maximo = math.rad(b.MaxRetraso)
	local d = CargarReglas.diferencia(angulo, objetivo)
	if math.abs(d) > maximo then
		angulo = objetivo - math.sign(d) * maximo
	end
	return angulo, vel
end

-- La velocidad con que sale lo que lanzas, o nil si no vale (ni se puede lanzar ni la dirección es de verdad).
-- `carga` de 0 a 1 (se recorta); `direccion`, hacia donde miras (se normaliza y no se deja muy arriba ni abajo).
-- Devuelve también las vueltas (rad/s, alrededor de `derecha`: de punta a punta).
function CargarReglas.lanzamiento(tipo: string, carga: unknown, direccion: unknown): (Vector3?, number?)
	if not CargarReglas.lanzable(tipo) or type(carga) ~= "number" or typeof(direccion) ~= "Vector3" then
		return nil
	end
	local d = direccion :: Vector3
	if not finito(carga) or not vectorFinito(d) or d.Magnitude < 0.01 then
		return nil
	end
	local k = math.clamp(carga, 0, 1)
	d = d.Unit
	-- Ni al cielo ni a tus pies: de -30 a 60 grados.
	local plano = Vector3.new(d.X, 0, d.Z)
	if plano.Magnitude < 0.01 then
		plano = Vector3.new(0, 0, -1)
	end
	local alto = math.clamp(math.asin(math.clamp(d.Y, -1, 1)), math.rad(-30), math.rad(60))
	d = plano.Unit * math.cos(alto) + ARRIBA * math.sin(alto)
	d = (d + ARRIBA * C.Lanzar.Arriba).Unit
	local v = C.Lanzar.Velocidad
	return d * (v[1] + (v[2] - v[1]) * k), C.Lanzar.Vueltas * (0.3 + 0.7 * k)
end

-- ¿Ha dado contra algo? Cuánto ha perdido de golpe entre dos fotogramas (studs/s), si pasa de Ruido.Umbral.
function CargarReglas.golpe(antes: Vector3, ahora: Vector3): number?
	if not (vectorFinito(antes) and vectorFinito(ahora)) then
		return nil
	end
	local perdido = (antes - ahora).Magnitude
	-- Solo frenar cuenta (acelerar de golpe no es dar contra nada): la rapidez tiene que bajar.
	if perdido >= C.Ruido.Umbral and ahora.Magnitude < antes.Magnitude then
		return perdido
	end
	return nil
end

-- A cuántos studs oye un bicho un golpe de esa fuerza (studs/s perdidos).
function CargarReglas.alcanceGolpe(fuerza: number): number
	local r = C.Ruido
	local k = math.clamp((fuerza - r.Umbral) / (r.Fuerte - r.Umbral), 0, 1)
	return r.Alcance[1] + (r.Alcance[2] - r.Alcance[1]) * k
end

-- De 0 a 1, para el volumen del golpe.
function CargarReglas.fuerzaGolpe(fuerza: number): number
	local r = C.Ruido
	return math.clamp((fuerza - r.Umbral) / (r.Fuerte - r.Umbral), 0, 1)
end

-- Lo enganchado que está: distancia en horizontal entre donde debería ir y donde está. `antes`: si ya lo estaba
-- (para no saltar de un lado a otro justo en el borde).
function CargarReglas.enganchado(debe: Vector3, esta: Vector3, antes: boolean): boolean
	local d = (debe - esta) * Vector3.new(1, 0, 1)
	return d.Magnitude > (if antes then C.Desengancha else C.Engancha)
end

return CargarReglas
