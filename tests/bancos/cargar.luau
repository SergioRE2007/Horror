-- Cuentas de llevar cosas pesadas con físicas (15.8, pedido por el usuario: "todo": físicas, al hombro, lanzar y ruido).
-- Ejecutar desde la raíz: lune run tests/bancos/cargar.luau (también lo lanza tests/regressions.luau).
-- Sin física de Roblox (eso solo se ve en Studio): carga Config, CargarReglas y Ruidos y mira las cuentas:
--   1. Al hombro: troncos y tablones a la derecha, a lo largo hacia delante, algo levantados, encima del hombro y sin
--      meterse en la cámara; lo demás, delante atravesado (como antes). Nunca NaN, mire a donde mire.
--   2. El muelle del giro: se queda atrás al girar, se pasa poco al parar y acaba quieto donde miras; nunca más atrás de
--      Balanceo.MaxRetraso; estable aunque un fotograma tarde mucho.
--   3. Lanzar: solo la madera; carga y dirección raras (NaN, infinitos, textos) no valen o se recortan; ni al cielo ni a
--      los pies; más carga, más lejos; a tope llega a unos metros.
--   4. Golpes y ruido: dejarlo con cuidado no suena; soltarlo desde el hombro sí, más que de la cintura; lanzado, más.
--   5. Ruidos: se oyen a su alcance, se olvidan a su tiempo, cada bicho va una vez a cada uno, va al más cerca y las
--      paredes los apagan.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Vector3, CFrame = roblox.Vector3, roblox.CFrame

local function nodo(ruta: string)
	return setmetatable({ ruta = ruta }, {
		__index = function(_, clave)
			return nodo(if clave == "Parent" then (string.match(ruta, "^(.*)/[^/]+$") :: string) else ruta .. "/" .. clave)
		end,
	})
end
local cargados = {}
local function cargar(ruta: string)
	if cargados[ruta] == nil then
		local fuente = fs.readFile(ruta .. ".luau")
		local entorno = {
			script = nodo(ruta),
			require = function(n)
				return cargar(n.ruta)
			end,
			Vector3 = Vector3,
			CFrame = CFrame,
			typeof = typeof,
		}
		cargados[ruta] = luau.load(fuente, { debugName = ruta, environment = entorno })()
	end
	return cargados[ruta]
end

local Config = cargar("src/shared/Config")
local R = cargar("src/shared/CargarReglas")
local Ruidos = cargar("src/juego/servidor/Ruidos")
local C = Config.Cargar

local fallos = {}
local cuantas = 0
local function comprobar(bien: boolean, que: string)
	cuantas += 1
	if not bien then
		table.insert(fallos, que)
	end
end
local function finito(v: Vector3): boolean
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6 and math.abs(v.Z) < 1e6
end
local function tam(tipo: string): Vector3
	local t = Config.Pesados[tipo].Tam
	return Vector3.new(t[1], t[2], t[3])
end

-- 1. Dónde va. La raíz R15 está a 3 studs del suelo; la cámara en primera persona, ~1,5 por encima de la raíz.
local CAMARA_ALTO = 1.5
for _, tipo in { "Tronco", "Tablon", "TablonReforzado", "Bidon", "Rueda" } do
	local t = tam(tipo)
	for grados = 0, 350, 10 do
		local raiz = CFrame.new(10, 3, -4) * CFrame.Angles(0, math.rad(grados), 0)
		local cf = R.sitio(tipo, t, raiz)
		local l = raiz:ToObjectSpace(cf)
		comprobar(finito(cf.Position) and finito(cf.XVector) and finito(cf.YVector), `{tipo} a {grados}°: sin NaN`)
		if R.alHombro(tipo) then
			comprobar(l.Position.X > 0.6, `{tipo} a {grados}°: a la derecha ({l.Position.X})`)
			comprobar(l.XVector:Dot(Vector3.new(0, 0, -1)) > 0.97, `{tipo} a {grados}°: a lo largo hacia delante`)
			comprobar(l.XVector.Y > 0, `{tipo} a {grados}°: la punta levantada`)
			comprobar(l.Position.Z < 0, `{tipo} a {grados}°: más por delante que por detrás`)
			-- La parte de abajo, sobre el hombro (más alto que la cintura, más bajo que los ojos).
			local abajo = l.Position.Y - t.Y / 2
			comprobar(abajo > -0.6 and abajo < CAMARA_ALTO - 0.5, `{tipo} a {grados}°: apoyado en el hombro ({abajo})`)
			-- La cámara nunca dentro: lo más cerca del eje del tronco al ojo, más que su radio.
			local ojo = Vector3.new(0, CAMARA_ALTO, 0)
			local eje = l.XVector
			local d = ojo - l.Position
			local perp = d - eje * d:Dot(eje)
			comprobar(perp.Magnitude > math.max(t.Y, t.Z) / 2 + 0.25, `{tipo} a {grados}°: no tapa la cámara ({perp.Magnitude})`)
		else
			comprobar(l.Position.Z < -2, `{tipo} a {grados}°: delante`)
			comprobar(math.abs(l.XVector.X) > 0.99, `{tipo} a {grados}°: atravesado`)
			comprobar(math.abs(l.Position.X) < 0.01, `{tipo} a {grados}°: centrado`)
		end
	end
end
comprobar(R.alHombro("Tronco") and R.alHombro("Tablon") and not R.alHombro("Bidon") and not R.alHombro("Motor"),
	"al hombro, solo lo largo de madera")
comprobar(not R.alHombro("NoExiste"), "lo que no existe no va al hombro")
-- Mirando recto arriba o abajo (la raíz no lo hace, pero por si acaso): sigue habiendo un frente.
local recto = R.sitio("Tronco", tam("Tronco"), CFrame.lookAt(Vector3.zero, Vector3.new(0, 1, 0)))
comprobar(finito(recto.Position) and finito(recto.XVector), "mirando arriba: sin NaN")

-- 2. El muelle.
do
	local a, w = 0, 0
	local objetivo = math.rad(120) -- giras 120° de golpe
	local maxPasado, retrasoMax = 0, 0
	for i = 1, 240 do
		a, w = R.muelle(a, w, objetivo, 1 / 60)
		local d = R.diferencia(a, objetivo)
		retrasoMax = math.max(retrasoMax, math.abs(d))
		if i > 5 and d < 0 then
			maxPasado = math.max(maxPasado, -d)
		end
	end
	comprobar(math.abs(R.diferencia(a, objetivo)) < math.rad(0.5), "el muelle acaba donde miras")
	comprobar(retrasoMax <= math.rad(C.Balanceo.MaxRetraso) + 1e-6, "nunca más atrás de MaxRetraso")
	comprobar(maxPasado > math.rad(0.5), `se pasa un poco al parar ({math.deg(maxPasado)}°)`)
	comprobar(maxPasado < math.rad(15), `pero poco ({math.deg(maxPasado)}°)`)
	-- Girando seguido a 180°/s: se queda atrás algo, sin pasar del tope.
	a, w = 0, 0
	local mira = 0
	for _ = 1, 120 do
		mira += math.rad(180) / 60
		a, w = R.muelle(a, w, mira, 1 / 60)
	end
	local atras = R.diferencia(a, mira)
	comprobar(atras > math.rad(5) and atras <= math.rad(C.Balanceo.MaxRetraso) + 1e-6,
		`girando seguido se queda atrás ({math.deg(atras)}°)`)
	-- Por el lado corto: de 170° a -170° son 20°, no 340°.
	comprobar(math.abs(R.diferencia(math.rad(170), math.rad(-170)) - math.rad(20)) < 1e-6, "diferencia por el lado corto")
	-- Un fotograma de 3 s (Studio parado) no lo vuelve loco; con NaN vuelve a donde miras.
	local a2, w2 = R.muelle(0, 0, 1, 3)
	comprobar(a2 == a2 and w2 == w2 and math.abs(w2) < 100, "fotograma larguísimo: estable")
	local a3, w3 = R.muelle(0 / 0, 0, 1, 1 / 60)
	comprobar(a3 == 1 and w3 == 0, "con NaN vuelve a donde miras")
end

-- 3. Lanzar.
local G = 196.2
local function alcance(v: Vector3, alto: number): number
	-- Tiro sin aire desde `alto` studs hasta el suelo.
	local vy, vh = v.Y, Vector3.new(v.X, 0, v.Z).Magnitude
	local t = (vy + math.sqrt(vy * vy + 2 * G * alto)) / G
	return vh * t
end
local delante = Vector3.new(0, 0, -1)
local flojo = R.lanzamiento("Tronco", 0, delante)
local fuerte, vueltas = R.lanzamiento("Tronco", 1, delante)
comprobar(flojo ~= nil and fuerte ~= nil, "el tronco se lanza")
if flojo and fuerte then
	local lejos = alcance(fuerte, 3.5)
	print(`Lanzar un tronco: sin cargar llega a {math.floor(alcance(flojo, 3.5) * 10) / 10} studs, cargado del todo a`
		.. ` {math.floor(lejos * 10) / 10} (de la mano al suelo, sin rebotes)`)
	comprobar(alcance(fuerte, 3.5) > alcance(flojo, 3.5) + 3, "más carga, más lejos")
	comprobar(lejos > 8 and lejos < 25, `cargado del todo llega unos metros ({lejos})`)
	comprobar(fuerte.Y > 0, "sale algo hacia arriba")
	comprobar(type(vueltas) == "number" and vueltas > 0, "da vueltas")
end
comprobar(R.lanzamiento("Bidon", 1, delante) == nil, "el bidón no se lanza")
comprobar(R.lanzamiento("Motor", 1, delante) == nil, "el motor no se lanza")
comprobar(R.lanzamiento("Rueda", 1, delante) == nil, "la rueda no se lanza")
comprobar(R.lanzamiento("NoExiste", 1, delante) == nil, "lo que no existe no se lanza")
comprobar(R.lanzamiento("Tronco", 0 / 0, delante) == nil, "carga NaN no vale")
comprobar(R.lanzamiento("Tronco", math.huge, delante) == nil, "carga infinita no vale")
comprobar(R.lanzamiento("Tronco", "1", delante) == nil, "carga de texto no vale")
comprobar(R.lanzamiento("Tronco", 1, Vector3.new(0 / 0, 0, 1)) == nil, "dirección NaN no vale")
comprobar(R.lanzamiento("Tronco", 1, Vector3.zero) == nil, "dirección cero no vale")
comprobar(R.lanzamiento("Tronco", 1, "arriba") == nil, "dirección de texto no vale")
local mucha = R.lanzamiento("Tronco", 50, delante)
comprobar(mucha ~= nil and fuerte ~= nil and math.abs(mucha.Magnitude - fuerte.Magnitude) < 1e-6, "la carga se recorta a 1")
local enorme = R.lanzamiento("Tronco", 1, Vector3.new(0, 0, -1e5))
comprobar(enorme ~= nil and fuerte ~= nil and math.abs(enorme.Magnitude - fuerte.Magnitude) < 1e-4,
	"una dirección enorme no lanza más fuerte")
local cielo = R.lanzamiento("Tronco", 1, Vector3.new(0, 1, 0))
comprobar(cielo ~= nil and cielo.Unit.Y < math.sin(math.rad(75)), "ni recto al cielo")
local pies = R.lanzamiento("Tronco", 1, Vector3.new(0, -1, 0.0001))
comprobar(pies ~= nil and pies.Unit.Y > math.sin(math.rad(-30)), "ni a los pies")

-- 4. Golpes.
local function caer(alto: number): number
	return math.sqrt(2 * G * alto)
end
local suave = R.golpe(Vector3.new(0, -caer(0.15), 0), Vector3.zero)
local cintura = R.golpe(Vector3.new(0, -caer(2), 0), Vector3.zero)
local hombro = R.golpe(Vector3.new(0, -caer(3.5), 0), Vector3.zero)
comprobar(suave == nil, "dejarlo con cuidado (desde un palmo) no suena")
comprobar(cintura ~= nil and hombro ~= nil and hombro > cintura, "desde el hombro suena más que desde la cintura")
comprobar(R.golpe(Vector3.zero, Vector3.new(0, 30, 0)) == nil, "acelerar de golpe no es un golpe")
comprobar(R.golpe(Vector3.new(0 / 0, 0, 0), Vector3.zero) == nil, "con NaN no suena")
if cintura and hombro and fuerte then
	local lanzado = R.golpe(Vector3.new(fuerte.X, -caer(3.5) - 10, fuerte.Z), Vector3.zero) :: number
	print(`Se oye a: cintura {math.floor(R.alcanceGolpe(cintura))} studs, hombro {math.floor(R.alcanceGolpe(hombro))},`
		.. ` lanzado {math.floor(R.alcanceGolpe(lanzado))}, arrastrar {C.Ruido.Arrastrar}; correr`
		.. ` {Config.Correr.Oido}, de pie {Config.Postura.Oido}`)
	comprobar(R.alcanceGolpe(hombro) > Config.Correr.Oido, "soltar desde el hombro se oye más lejos que correr")
	comprobar(R.alcanceGolpe(lanzado) >= R.alcanceGolpe(hombro), "lanzado, como poco lo mismo")
	comprobar(R.alcanceGolpe(1e9) == C.Ruido.Alcance[2], "con tope")
	comprobar(R.fuerzaGolpe(C.Ruido.Umbral) == 0 and R.fuerzaGolpe(1e9) == 1, "fuerza de 0 a 1")
end
-- Enganchado, con margen para no saltar.
comprobar(R.enganchado(Vector3.zero, Vector3.new(3, 0, 0), false), "a 3 studs, enganchado")
comprobar(not R.enganchado(Vector3.zero, Vector3.new(2, 0, 0), false), "a 2, aún no")
comprobar(R.enganchado(Vector3.zero, Vector3.new(2, 0, 0), true), "a 2 si ya lo estaba, sigue")
comprobar(not R.enganchado(Vector3.zero, Vector3.new(0, 3, 0), false), "bajarlo al suelo no es engancharse")

-- 5. Ruidos (con el reloj de verdad: os.clock avanza solo y los ruidos duran poco).
do
	Ruidos.vaciar()
	local bicho = Vector3.new(0, 0, 0)
	Ruidos.hacer(Vector3.new(20, 0, 0), 30, 5)
	local p, n = Ruidos.oir(bicho, 0)
	comprobar(p ~= nil and p.X == 20, "se oye a su alcance")
	local p2 = Ruidos.oir(bicho, n)
	comprobar(p2 == nil, "el mismo bicho no va dos veces al mismo ruido")
	local p3 = Ruidos.oir(Vector3.new(100, 0, 0), 0)
	comprobar(p3 == nil, "lejos no se oye")
	local p4 = Ruidos.oir(bicho, 0, function()
		return 0.5
	end)
	comprobar(p4 == nil, "con las paredes en medio llega a la mitad (20 > 15)")
	Ruidos.hacer(Vector3.new(5, 0, 0), 30, 5)
	local p5, n5 = Ruidos.oir(bicho, 0)
	comprobar(p5 ~= nil and p5.X == 5, "va al más cerca")
	comprobar(Ruidos.oir(bicho, n5) == nil, "y oídos los dos, ninguno más")
	Ruidos.hacer(Vector3.new(1, 0, 0), 30, 0)
	comprobar(Ruidos.oir(bicho, n5) == nil, "un ruido sin duración no cuenta")
	Ruidos.vaciar()
	Ruidos.hacer(Vector3.new(1, 0, 0), 30, 0.05)
	local fin = os.clock() + 0.1
	while os.clock() < fin do
	end
	comprobar(Ruidos.oir(bicho, 0) == nil, "pasado su tiempo se olvida")
	Ruidos.vaciar()
	for i = 1, 100 do
		Ruidos.hacer(Vector3.new(i, 0, 0), 1000, 10)
	end
	local _, n6 = Ruidos.oir(bicho, 0)
	comprobar(n6 > 0, "con muchos ruidos sigue funcionando")
end

if #fallos > 0 then
	error("cargar: no se cumple:\n  " .. table.concat(fallos, "\n  "))
end
print(`Cargar: cuentas bien ({cuantas} comprobaciones).`)
