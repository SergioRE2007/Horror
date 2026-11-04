-- Mueve el cuerpo del Raspador en el cliente (el servidor solo lo desplaza y publica atributos en el modelo).
--   Andando: piernas largas, brazos colgando que se balancean, la cabeza dando tirones.
--   Raspando, lento y paciente (pedido por el usuario: "los bichos con más vida mientras esperan"): el cuello
--   estirado y la cara pegada al cristal, ladeada (de vez en cuando la ladea al otro lado, despacio); los codos arriba y
--   las manos bajando por el cristal, una y otra, con los dedos arañándolo; al llegar abajo la mano se despega y vuelve
--   arriba. Las manos van al cristal con cinemática inversa y la cara se pega con la inclinación del torso: el cristal
--   se mide con rayos cada segundo, a la altura de la cara, de lo alto de la cabeza y de cada mano (antes la cara y las
--   manos lo atravesaban). Respira despacio y hondo, pasa el peso de un pie a otro, se le crispan los dedos, la cara se
--   va volviendo hacia el jugador de dentro más cercano con tironcitos, y a ratos le cruje el cuello o abre la boca muy
--   despacio. El chirrido en bucle sube con cada pasada.
--   De noche echa vaho contra el cristal al soltar el aire (sin él con Rendimiento).
--   Con la linterna encima: se encoge hacia atrás, aparta la cara, recoge una mano delante del pecho temblando y con la
--   otra sigue arañando, más despacio y casi sin ruido (el servidor raspa más lento, no para).
--   Flash (remote Raspador "Chilla"): chilla con la boca abierta del todo, recoge las dos manos y se va corriendo.
--   Gateando (atributos Gatea y GateaHora, pedido por el usuario: "que el monstruo pueda gatear si te huele... para
--   pillarte debajo de sitios"): se echa boca abajo y se arrastra por debajo del mueble a por ti (ver GATEO).
-- Un solo bucle (Stepped) que solo corre mientras hay alguno; la vida, solo cerca de la cámara. Si el modelo se va
-- (StreamOut o lo quita el servidor) se limpia, y si vuelve se prepara otra vez.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MuebleRayo = require(script.Parent.MuebleRayo)
local Sonido = require(script.Parent.Sonido)

local RaspadorVista = {}

-- Números visuales a ojo (se retocan en Studio).
local LEJOS = 250 -- studs de la cámara: más lejos no se le mueve nada
local VIDA_LEJOS = 120 -- la vida (respirar, tirones, crisparse...) solo hasta aquí...
local VIDA_RENDIMIENTO = 45 -- ...o hasta aquí con Rendimiento
local VAHO_LEJOS = 60
local QUIETO = 1 -- studs/s: más despacio está quieto
local RESPIRA = 4.6 -- segundos por respiración: lenta y honda
local PESO = 9 -- segundos en pasar el peso de un pie al otro y volver
local CRISPA = { 1.5, 4 } -- segundos entre dos crispaciones de los dedos
local RARO = { 7, 14 } -- segundos entre dos cosas raras: el cuello que cruje o la boca que se abre despacio
local RESPINGO = { 1.2, 3.5 } -- segundos entre dos tironcitos de la cabeza
local BUSCAR = { 1.5, 3.5 } -- segundos entre dos veces que busca a quién mirar
local VER = 30 -- studs: se vuelve hacia los jugadores que tenga más cerca que esto
local LADEO = 0.42 -- la cabeza ladeada contra el cristal
local CAMBIA_LADEO = { 8, 15 } -- segundos hasta que la ladea al otro lado
-- Pegado: el cuello estirado (Cuello) y la cabeza levantada (Cabeza) dejan la cara de frente al cristal.
local CUELLO_PEGADO, CABEZA_PEGADA = -0.3, 0.35
local CRISTAL = 2.62 -- studs de la raíz al cristal si no se puede medir (el servidor lo deja a 2,8 de su centro)
-- Hueco entre el cristal y el centro de la cara (sus esquinas se adelantan ~0,3 con la cabeza ladeada y vuelta hacia ti:
-- comprobado con Lune) y entre el cristal y la punta de los dedos.
local MARGEN_CARA, MARGEN_MANOS = 0.35, 0.06
local ALTO_CARA, ALTO_MANOS = 4.3, 0.8 -- alturas (sobre la raíz) a las que se mide el cristal...
local ALTO_CABEZA = 0.7 -- ...y lo alto de la cabeza, por encima de la cara: si la ventana es baja, ahí hay pared...
local HUNDE = 0.35 -- ...en la que puede hundirse un poco (es de 1 de grueso: no asoma por dentro)
-- Encogido (le alumbran o chilla): la punta de los dedos va aquí (en la raíz; x hacia fuera), recogida delante del
-- pecho, por cinemática y siempre de este lado del cristal (antes mezclaba los giros con la postura de raspar y los dedos
-- atravesaban el cristal hasta 3 studs: comprobado con Lune).
local RECOGIDA = Vector3.new(0.9, 2.6, -1.1)
local MANO_ARRIBA, MANO_ABAJO = 1.5, 0.1 -- de dónde a dónde baja la punta de los dedos (sobre la raíz)
local MANO_X = 1.05
local PASADA = 2.8 -- segundos por pasada de cada mano (las dos a destiempo)
local BAJA = 0.82 -- de cada pasada, lo que baja arañando (el resto vuelve arriba despegada del cristal)
local DESPEGA = 0.45 -- studs que se aparta la mano al volver arriba
local BOCA = CFrame.new(0, -0.3, -0.66) -- en la cabeza
local VAHO = 7 -- partículas cada vez que suelta el aire
-- Brazo (Raspador.crear): del hombro al codo y del codo a la punta de los dedos, que va un poco por delante del antebrazo.
local BRAZO, ANTEBRAZO = 2.65, 4.153
local DESVIO = math.atan2(0.17, 4.15)
local CARA = CFrame.new(0, 0, -0.62) -- en la cabeza
local MOTORES = { "Torso", "Cuello", "Cabeza", "Mandibula", "BrazoI", "BrazoD", "AntebrazoI", "AntebrazoD", "PiernaI", "PiernaD" }
local LADOS = { -1, 1 }
-- Gatear a por alguien escondido debajo de un mueble (pedido por el usuario: "que el monstruo pueda gatear si te huele
-- con una animación guapa para pillarte debajo de sitios"). El servidor (Caza) le para en el borde, de cara a ti, y pone
-- en su modelo Gatea (dónde estás) y GateaHora (workspace:GetServerTimeNow() al empezar) durante Config.Postura.Gatear s.
-- Se echa boca abajo despacio y se arrastra: el cuello estirado, la cara ladeada a ras de suelo mirándote, los codos
-- hacia fuera y arriba (como una araña) y una mano que se adelanta hasta tu lado, arañando el suelo a tirones. La cara
-- baja por fuera del borde y el cuerpo solo se mete cuando está echado del todo; al acabar, se arrastra hacia atrás y
-- luego se levanta. Comprobado con Lune contra la mesa del comedor (tablero a 2,84 del suelo) y la de la cocina (3,29),
-- con la raíz a 1,1 (donde le deja el servidor), 1,4, 1,8, 2,2 y 3 studs del borde, por las puntas y en diagonal, a 20
-- fps, con Rendimiento, llegando tarde y si te pilla: en ningún fotograma (tampoco al echarse ni al levantarse) se
-- atraviesan el suelo ni el tablero; las patas sí se pueden rozar con un codo (ver chocaBrazo).
local ALTURA = 4.2 -- de los pies al centro de la raíz (Raspador.luau)
local GATEO = {
	Cae = 0.6, -- segundos (de un gateo de 2 s) en echarse boca abajo
	Sale = 0.5, -- al acabar, segundos en arrastrarse hacia atrás para salir de debajo...
	Levanta = 0.9, -- ...y en levantarse
	Cara = 0.5, -- studs del suelo al centro de la cabeza, echado: más bajo de lo que cabe, así se apoya en el suelo
	Ladeo = 1.3, -- la cabeza ladeada (su manía), casi de lado: la boca se abre de lado y no contra el suelo
	Alza = 0.3, -- echado, te mira con la cara alzada como mucho esto (pendiente: alto / por el suelo)
	Hasta = 1.45, -- studs del centro de la cabeza a ti al acabar (la cara queda a ~0,8)
	Fuera = 1.05, -- studs por fuera del borde a los que baja el centro de la cabeza (luego se mete arrastrándose)
	-- Sin zona Debajo (no debería pasar: el servidor solo gatea a por quien está en una, y el cliente las tiene siempre):
	-- el borde, a esto de ti, pero como mucho a SinZona de la raíz (el servidor le para a 2,5 de la zona y ningún
	-- tablero sobresale más de 2 de ella).
	Borde = 1.4,
	SinZona = 0.5,
	Techo = 2.8, -- studs del suelo al tablero, sin zona
	Hombros = 0.52, -- studs del suelo a la junta del cuello, echado: el pecho (y sus costillas) justo sobre el suelo
	Cadera = 0.62, -- studs: la cadera nunca más baja (con el torso inclinado, su esquina no toca el suelo)
	Mano = 0.16, -- studs del suelo a la punta de los dedos apoyados
	Codo = 0.3, -- los brazos, por debajo del tablero, como mucho a esto de él
	Alcance = 1.45, -- studs que se adelanta la mano que va a por ti, por delante del centro de la cabeza
	Codos = 0.66, -- hacia dónde salen los codos: de 0 (arriba) a 1 (de lado); en medio, fuera y arriba
	-- Los tirones, en segundos de un gateo de 2 s: {empieza, acaba, hasta dónde se ha metido (0..1)}. Entre uno y otro
	-- las manos se adelantan y husmea; en el tirón se quedan clavadas y el cuerpo se arrastra hacia ellas.
	Tirones = { { 0.8, 1.05, 0.35 }, { 1.2, 1.45, 0.7 }, { 1.6, 1.85, 1 } },
	Susto = 2.2, -- segundos que se queda en el suelo si te pilla (MuerteVista mira su cara)
}
local LARGO_CUELLO, LARGO_TORSO, PIERNA = 1.6, 3.6, 4 -- Raspador.crear
-- Cajas (centro y media medida) de la cabeza, de la mandíbula con su sangre y de los dedos en el antebrazo
-- (Raspador.crear), para que ninguna toque el suelo.
local CABEZA_MEDIO = Vector3.new(0.55, 0.75, 0.67)
local BOCA_CAJA, BOCA_MEDIO = CFrame.new(0, -0.175, 0), Vector3.new(0.5, 0.325, 0.59)
local DEDOS: { { any } } = {}
for i = 0, 3 do
	local x = (i - 1.5) * 0.09
	table.insert(DEDOS, { CFrame.new(x, -2.1, -0.05) * CFrame.Angles(0.15, 0, (i - 1.5) * 0.08), Vector3.new(0.03, 0.8, 0.03) })
	table.insert(DEDOS, { CFrame.new(x * 1.3, -2.85, -0.17), Vector3.new(0.035, 0.15, 0.035) })
end
local HOLGURA = 0.04 -- studs que se quedan por encima del suelo
local CODOS = 20 -- sitios del codo que se prueban (brazo3D)

local jugador = Players.LocalPlayer
local azar = Random.new()
local carpeta: Instance? = nil
local filtro = RaycastParams.new()
filtro.FilterType = Enum.RaycastFilterType.Exclude
local filtroGateo = RaycastParams.new()
filtroGateo.FilterType = Enum.RaycastFilterType.Exclude

-- Por dónde cabe entre las patas del mueble, de lado (lo que se aparte más de `centro` a lo largo de `eje` da con ellas).
type Hueco = { centro: Vector3, eje: Vector3, ancho: number }

-- Un gateo: el de ahora o el último (mientras vuelve a su pose).
type Gateo = {
	hora: number, -- GateaHora (hora del servidor)
	punto: Vector3, -- Gatea: dónde está el escondido
	borde: number, -- studs (por el suelo, hacia ti) de la raíz al borde del tablero
	techo: number, -- studs del suelo al tablero...
	arriba: number, -- ...y a lo alto del mueble
	caja: CFrame?, -- el tablero (su centro) y la mitad de su medida, si se sabe
	medio: Vector3,
	atras: number, -- studs libres detrás de la raíz (para las piernas)
	hueco: Hueco?, -- entre qué patas está el escondido
	t: number, -- segundos desde que empezó (se queda en el último al acabar)
	sonados: number, -- cuántos ruidos del gateo han sonado
	brazo: number, -- la mano que va a por ti: -1 izquierda, 1 derecha
	ladeo: number, -- hacia qué lado ladea la cabeza
	cara0: Vector3, -- dónde tenía la cabeza al empezar (en el mundo)
	sale: number, -- 0..1: al acabar, cuánto ha salido ya de debajo
	piernas: number, -- 0..1, suave: levantadas (hay una pared detrás)
}

type Bicho = {
	modelo: Model,
	raiz: BasePart,
	cabeza: BasePart,
	motores: { [string]: Motor6D },
	fase: number,
	pisada: number,
	chillido: number,
	encogido: number, -- 0..1, suave
	raspar: number, -- 0..1, suave
	bucle: Sound?,
	semilla: number, -- para que cada uno dé sus tirones a destiempo
	pasada: number, -- por dónde va la pasada de las manos (vueltas; con luz va más despacio)
	vida: number, -- 0..1, suave: quieto o raspando, cerca de la cámara y sin luz
	respira: number,
	exhala: boolean,
	peso: number,
	hastaCara: number, -- studs de la raíz al cristal (o la pared) a la altura de la cara...
	hastaManos: { number }, -- ...y a la de cada mano (1 izquierda, 2 derecha): en medio suele estar la cruceta
	pegar: number, -- inclinación del torso que deja la cara contra el cristal
	medido: number, -- os.clock de la última vez que se midió
	ladeo: number, -- -1 o 1
	cambiaLadeo: number,
	cab: Vector3, -- la cabeza ahora (cabeceo, giro, ladeo) y a dónde va
	meta: Vector3,
	mira: BasePart?,
	buscar: number,
	respingo: Vector3,
	respingoHora: number,
	proximoRespingo: number,
	crispa: { number }, -- os.clock de la última crispación de los dedos de cada mano (1 izquierda, 2 derecha)
	proximaCrispa: number,
	raro: number, -- os.clock de la última cosa rara...
	tipoRaro: number, -- ...1: le cruje el cuello; 2: abre la boca despacio
	proximoRaro: number,
	gateo: number, -- 0..1, suave: echado boca abajo a por alguien debajo de un mueble
	gatea: Gateo?,
	agarra: number, -- os.clock de rugir: el susto al morir le deja en el suelo
}
local bichos: { [Model]: Bicho } = {}
local conexion: RBXScriptConnection? = nil

local vahoPunto: Attachment? = nil
local vahoEmisor: ParticleEmitter? = nil

local function rango(r: { number }): number
	return azar:NextNumber(r[1], r[2])
end

local function acercar(actual: number, meta: number, dt: number, rapidez: number): number
	return actual + (meta - actual) * math.min(1, dt * rapidez)
end

local function suave(u: number): number
	return u * u * (3 - 2 * u)
end

local function crispacion(t: number): number
	if t < 0 or t > 0.45 then
		return 0
	end
	local x = t / 0.06
	return x * math.exp(1 - x)
end

local function dentroDeCasa(p: Vector3): boolean
	local c = Config.Casa
	return math.abs(p.X) < c.MedioX and math.abs(p.Z) < c.MedioZ and p.Y < 28
end

-- El vaho contra el cristal: sale despacio de la boca y se abre hacia los lados.
local function echarVaho(boca: CFrame)
	if not vahoEmisor then
		local a = Instance.new("Attachment")
		a.Name = "VahoRaspador"
		a.Parent = workspace.Terrain
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.LightInfluence = 1 -- de noche apenas se ve: con la linterna o la luz de dentro
		e.Color = ColorSequence.new(Color3.fromRGB(215, 220, 228))
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 1) })
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.9) })
		e.Lifetime = NumberRange.new(1.4, 2.2)
		e.Speed = NumberRange.new(0.4, 0.9)
		e.SpreadAngle = Vector2.new(65, 65)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-20, 20)
		e.Acceleration = Vector3.new(0, 0.35, 0)
		e.Drag = 2
		e.Rate = 0
		e.Parent = a
		vahoPunto, vahoEmisor = a, e
	end
	;(vahoPunto :: Attachment).WorldCFrame = CFrame.lookAt(boca.Position, boca.Position + boca.LookVector) * CFrame.Angles(-math.pi / 2, 0, 0)
	;(vahoEmisor :: ParticleEmitter):Emit(VAHO)
end

-- La cabeza del jugador vivo y sin esconder más cercano a `desde` (si `delante`, solo los que tiene delante).
local function jugadorCerca(desde: Vector3, maximo: number, delante: Vector3?): BasePart?
	local mejor, distancia = nil, maximo
	for _, otro in Players:GetPlayers() do
		if otro:GetAttribute("Muerto") or otro:GetAttribute("Escondido") then
			continue
		end
		local personaje = otro.Character
		local suya = personaje and personaje:FindFirstChild("Head") :: BasePart?
		if suya and (not delante or (suya.Position - desde):Dot(delante) > 0) then
			local d = (suya.Position - desde).Magnitude
			if d < distancia then
				mejor, distancia = suya, d
			end
		end
	end
	return mejor
end

-- Studs de la raíz al cristal (o la pared) a esa altura (y `x` de lado), mirando al frente; nil si no hay nada.
local function medir(b: Bicho, alto: number, x: number?): number?
	filtro.FilterDescendantsInstances = { carpeta :: Instance, jugador.Character :: Instance }
	local cf = b.raiz.CFrame
	local choque = workspace:Raycast(cf * Vector3.new(x or 0, alto, -0.4), cf.LookVector * 3.6, filtro)
	return if choque then math.clamp(0.4 + choque.Distance, 1.8, 3.4) else nil
end

-- Inclinación del torso (con el cuello y la cabeza pegados) que deja la cara a `hasta` studs por delante de la raíz.
-- Es casi lineal: tres pasos de Newton (comprobado con Lune).
local function inclinar(m: { [string]: Motor6D }, hasta: number): number
	local cuello = m.Cuello.C0 * CFrame.Angles(CUELLO_PEGADO, 0, 0) * m.Cuello.C1:Inverse() * m.Cabeza.C0
		* CFrame.Angles(CABEZA_PEGADA, 0, 0) * m.Cabeza.C1:Inverse() * CARA
	local function caraZ(t: number): number
		return (m.Torso.C0 * CFrame.Angles(t, 0, 0) * m.Torso.C1:Inverse() * cuello).Position.Z
	end
	local t = 0
	for _ = 1, 3 do
		local z0 = caraZ(t)
		local pendiente = (caraZ(t + 0.01) - z0) / 0.01
		if math.abs(pendiente) < 0.1 then
			break
		end
		t = math.clamp(t - (z0 + hasta) / pendiente, -0.3, 0.45)
	end
	return t
end

-- Giros del hombro y del codo para que la punta de los dedos llegue a `objetivo` (en la raíz), con el torso girado
-- `torso`. Dos huesos en el plano del brazo, el codo hacia arriba (comprobado con Lune).
local function brazoIK(m: { [string]: Motor6D }, torso: CFrame, hombro: Motor6D, objetivo: Vector3): (number, number)
	local p = (m.Torso.C0 * torso * m.Torso.C1:Inverse() * hombro.C0):PointToObjectSpace(objetivo)
	local y, z = p.Y, p.Z
	local d = math.clamp(math.sqrt(y * y + z * z), ANTEBRAZO - BRAZO + 0.01, ANTEBRAZO + BRAZO - 0.01)
	local h = math.atan2(-z, -y) + math.acos(math.clamp((BRAZO * BRAZO + d * d - ANTEBRAZO * ANTEBRAZO) / (2 * BRAZO * d), -1, 1))
	local ey, ez = -math.cos(h) * BRAZO, -math.sin(h) * BRAZO
	return h, math.atan2(-(z - ez), -(y - ey)) - h - DESVIO
end

-- Una pasada de una mano (u de 0 a 1): baja despacio arañando y vuelve arriba despegada.
-- Devuelve la altura de la punta de los dedos, cuánto se despega y cuánto araña.
local function pasada(u: number): (number, number, number)
	if u < BAJA then
		local x = u / BAJA
		return MANO_ARRIBA + (MANO_ABAJO - MANO_ARRIBA) * x, 0, math.sin(math.pi * x)
	end
	local x = (u - BAJA) / (1 - BAJA)
	return MANO_ABAJO + (MANO_ARRIBA - MANO_ABAJO) * suave(x), math.sin(math.pi * x), 0
end

-- Cabeceo y giro de la cabeza para mirar a `punto` (en la raíz), con su reposo y sus topes.
local function mirada(b: Bicho, punto: Vector3, reposo: number, giroMax: number, bajo: number, alto: number): (number, number)
	local d = b.raiz.CFrame:VectorToObjectSpace(punto - b.cabeza.Position)
	local cabeceo = math.atan2(d.Y, math.sqrt(d.X * d.X + d.Z * d.Z)) - reposo
	return math.clamp(cabeceo, bajo, alto), math.clamp(math.atan2(-d.X, -d.Z), -giroMax, giroMax)
end

-- Lo más bajo de una caja girada (`medio`: la mitad de su medida).
local function masBajo(cf: CFrame, medio: Vector3): number
	return cf.Position.Y - (math.abs(cf.XVector.Y) * medio.X + math.abs(cf.YVector.Y) * medio.Y + math.abs(cf.ZVector.Y) * medio.Z)
end

local function dedosBajo(antebrazo: CFrame): number
	local y = math.huge
	for _, d in DEDOS do
		y = math.min(y, masBajo(antebrazo * d[1], d[2]))
	end
	return y
end

-- Lo que se mete en el tablero (caja de media medida `medio`, en cuyo espacio van `a` y `c`) el tramo de `a` a `c` de
-- un brazo: la caja crece 0,2 por los lados y por arriba (el brazo es gordo) y `bajo` por abajo. Lo más hondo del trozo
-- que queda dentro, contado desde abajo (0 si no la toca).
local function dentroCaja(a: Vector3, c: Vector3, medio: Vector3, bajo: number): number
	local d = c - a
	local t0, t1 = 0, 1
	for _, eje in { "X", "Y", "Z" } do
		local ae, de = (a :: any)[eje], (d :: any)[eje]
		local lo = if eje == "Y" then -medio.Y - bajo else -(medio :: any)[eje] - 0.2
		local hi = (medio :: any)[eje] + 0.2
		if math.abs(de) < 1e-6 then
			if ae < lo or ae > hi then
				return 0
			end
		else
			local u0, u1 = (lo - ae) / de, (hi - ae) / de
			t0, t1 = math.max(t0, math.min(u0, u1)), math.min(t1, math.max(u0, u1))
			if t0 > t1 then
				return 0
			end
		end
	end
	return math.max(a.Y + d.Y * t0, a.Y + d.Y * t1) + medio.Y + bajo
end

-- Un giro con -Y hacia `abajo` y -Z lo más cerca posible de `delante` (brazos, cuello y piernas).
local function orientar(abajo: Vector3, delante: Vector3): CFrame
	local y = -abajo.Unit
	local z = -(delante - y * delante:Dot(y))
	if z.Magnitude < 1e-4 then
		z = y:Cross(if math.abs(y.X) < 0.9 then Vector3.xAxis else Vector3.zAxis)
	end
	z = z.Unit
	return CFrame.fromMatrix(Vector3.zero, y:Cross(z), y, z)
end

-- Un giro con -Z hacia `mira` (la cara), derecho y ladeado `ladeo` radianes.
local function mirarCara(mira: Vector3, ladeo: number): CFrame
	local z = -mira.Unit
	local x = Vector3.new(0, 1, 0):Cross(z)
	x = if x.Magnitude < 1e-4 then Vector3.xAxis else x.Unit
	return CFrame.fromMatrix(Vector3.zero, x, z:Cross(x), z) * CFrame.Angles(0, 0, ladeo)
end

local function duraGateo(): number
	local reglas = Config.Postura
	return if reglas and reglas.Gatear then reglas.Gatear else 2
end

-- El tablero que tapa al escondido en `punto`: la zona Debajo en la que está (Mapa, HUECOS) y su mueble. Las piezas de
-- los muebles y sus cajas de choque no se ven con rayos (CanQuery false): lo calcula MuebleRayo.tablero con el Tam del
-- mueble. Devuelve su centro, su tamaño, la altura del hueco y la zona, o nil si no está debajo de nada.
local function tablero(punto: Vector3): (CFrame?, Vector3?, number?, BasePart?)
	for _, zona in CollectionService:GetTagged("Debajo") do
		if not zona:IsA("BasePart") then
			continue
		end
		local medio = zona.Size / 2
		local p = zona.CFrame:PointToObjectSpace(punto)
		if math.abs(p.X) > medio.X + 0.5 or math.abs(p.Z) > medio.Z + 0.5 or p.Y < -medio.Y - 1 or p.Y > medio.Y + 3 then
			continue
		end
		local cf, tam = MuebleRayo.tablero(zona)
		return cf, tam, zona.Size.Y, zona
	end
	return nil, nil, nil, nil
end

-- Studs (por el suelo, de la raíz hacia `punto`) hasta el borde del tablero que tapa al escondido, por el centro y a
-- los lados (los codos van muy abiertos: hasta 2,4), la altura del hueco, lo que queda libre detrás de la raíz (hasta
-- una pared, para las piernas) y entre qué patas cabe. Sin tablero, GATEO.Borde (o SinZona) y GATEO.Techo.
type Borde = { borde: number, techo: number, arriba: number, atras: number, hueco: Hueco?, caja: CFrame?, medio: Vector3 }
local function buscarBorde(b: Bicho, punto: Vector3): Borde
	local raiz = b.raiz.Position
	local suelo = raiz.Y - ALTURA
	local plano = Vector3.new(punto.X - raiz.X, 0, punto.Z - raiz.Z)
	local largo = plano.Magnitude
	local frente = b.raiz.CFrame.LookVector
	local hacia = if largo > 0.01 then plano.Unit else Vector3.new(frente.X, 0, frente.Z).Unit
	local fuera: { Instance } = {}
	if carpeta then
		table.insert(fuera, carpeta)
	end
	for _, otro in Players:GetPlayers() do
		if otro.Character then
			table.insert(fuera, otro.Character)
		end
	end
	filtroGateo.FilterDescendantsInstances = fuera
	local detras = workspace:Raycast(Vector3.new(raiz.X, suelo + 0.7, raiz.Z), -hacia * 9, filtroGateo)
	local atras = if detras then detras.Distance else 9
	local cf, tam, abajo, zona = tablero(punto)
	if not cf or not tam or not abajo or not zona then
		return { borde = math.clamp(largo - GATEO.Borde, 0, GATEO.SinZona), techo = GATEO.Techo, arriba = GATEO.Techo + 1, atras = atras,
			hueco = nil, caja = nil, medio = Vector3.zero }
	end
	-- De lado: el eje de la zona más atravesado a su camino.
	local deLado = math.abs(zona.CFrame.XVector:Dot(hacia)) < math.abs(zona.CFrame.ZVector:Dot(hacia))
	local hueco = {
		centro = zona.Position,
		eje = if deLado then zona.CFrame.XVector else zona.CFrame.ZVector,
		ancho = math.max(0, (if deLado then zona.Size.X else zona.Size.Z) / 2 - 0.3),
	}
	-- Por donde entra cada raya (paralelas, en el plano del tablero) en su caja.
	local medio = tam / 2
	local d = cf:VectorToObjectSpace(hacia)
	local lado = cf:VectorToObjectSpace(Vector3.new(-hacia.Z, 0, hacia.X))
	local borde = largo
	for _, x in { 0, -1.2, 1.2, -2.4, 2.4 } do
		local o = cf:PointToObjectSpace(raiz) + lado * x
		local entra, sale = -math.huge, math.huge
		for _, eje in { "X", "Z" } do
			local oe, de, me = (o :: any)[eje], (d :: any)[eje], (medio :: any)[eje]
			if math.abs(de) < 1e-6 then
				if math.abs(oe) > me then
					entra = math.huge
				end
			else
				local t1, t2 = (-me - oe) / de, (me - oe) / de
				entra, sale = math.max(entra, math.min(t1, t2)), math.min(sale, math.max(t1, t2))
			end
		end
		if entra <= sale and sale > 0 then
			borde = math.min(borde, math.max(0, entra))
		end
	end
	return { borde = borde, techo = abajo, arriba = abajo + tam.Y, atras = atras, hueco = hueco, caja = cf, medio = medio }
end

-- Por dónde va el gateo a los `t` s: cuánto se ha metido (0..1), cuánto husmea (0..1, entre tirones), el empujón de
-- cada tirón (0..1) y, para las manos, a qué avance van apoyadas (entre tirones se adelantan al del próximo, levantadas
-- `alza`; en el tirón se quedan clavadas y el cuerpo se arrastra hacia ellas). Simple (Rendimiento): seguido.
local function avanceGateo(t: number, simple: boolean): (number, number, number, number, number)
	local u = t * 2 / duraGateo() -- GATEO.Tirones va en segundos de un gateo de 2 s
	local ultimo = GATEO.Tirones[#GATEO.Tirones]
	if simple then
		local a = suave(math.clamp((u - GATEO.Cae) / (ultimo[2] - GATEO.Cae), 0, 1))
		return a, 0, 0, a, 0
	end
	local a, antes = 0, GATEO.Cae -- lo metido y cuándo acabó el último tirón (o cuándo se echó)
	for _, tiron in GATEO.Tirones do
		if u >= tiron[2] then
			a, antes = tiron[3], tiron[2]
		elseif u > tiron[1] then
			local k = (u - tiron[1]) / (tiron[2] - tiron[1])
			return a + (tiron[3] - a) * (1 - (1 - k) ^ 3), 0, math.sin(math.pi * k), tiron[3], 0
		else
			local k = math.clamp((u - antes) / ((tiron[1] - antes) * 0.7), 0, 1)
			return a, if u > GATEO.Cae then 1 else 0, 0, a + (tiron[3] - a) * suave(k), math.sin(math.pi * k)
		end
	end
	return a, 1, 0, a, 0
end

-- Los ruidos del gateo: 1 se echa al suelo (golpe sordo y le cruje el cuello); 2 y 3, cada tirón, arrastrándose y
-- arañando; 4, el último, con un chillido ahogado que se corta.
local EVENTOS = { GATEO.Cae, GATEO.Tirones[1][1], GATEO.Tirones[2][1], GATEO.Tirones[3][1] }
local function ruidoGateo(b: Bicho, n: number)
	local donde = b.cabeza.Position
	if n == 1 then
		Sonido.en("Paso", donde - Vector3.new(0, 0.5, 0), 0.5)
		Sonido.en("Cruje", donde, 0.75)
		return
	end
	Sonido.en("Paso", donde, 0.7)
	Sonido.en("Aranazo", donde, 1.1)
	if n == #EVENTOS then
		local corto = Sonido.en("Chillido", donde, 0.55)
		task.delay(0.45, function()
			if corto.Parent then
				corto:Stop()
			end
		end)
	end
end

-- Cinemática del brazo en 3D: el codo va en el círculo en el que cabe, y de ese círculo se prueban unos cuantos
-- sitios: de arriba a hacia fuera (`lado`) a la altura del hombro y de ahí a hacia atrás, plegado junto al cuerpo como
-- una mantis (debajo de la mesa, doblado, no cabe de otra forma); se queda el más cercano a `prefiere` (0 arriba, 1
-- fuera, 2 atrás) entre los que menos chocan según `choca(hombro, codo, punta)` (studs que se mete: tablero, patas). Devuelve
-- el codo y la punta de los dedos (`punta`, o lo más cerca que llegue).
local function brazo3D(hombro: Vector3, punta: Vector3, lado: number, prefiere: number,
	choca: (Vector3, Vector3, Vector3) -> number): (Vector3, Vector3)
	local eje = punta - hombro
	local largo = eje.Magnitude
	local dir = if largo > 1e-3 then eje / largo else -Vector3.yAxis
	local d = math.clamp(largo, ANTEBRAZO - BRAZO + 0.02, ANTEBRAZO + BRAZO - 0.02)
	local x = (d * d + BRAZO * BRAZO - ANTEBRAZO * ANTEBRAZO) / (2 * d)
	local r = math.sqrt(math.max(0, BRAZO * BRAZO - x * x))
	local llega = hombro + dir * d
	local function codoHacia(t: number): Vector3
		local p = if t <= 1 then Vector3.new(lado * math.sin(t * math.pi / 2), math.cos(t * math.pi / 2), 0.15)
			else Vector3.new(lado * math.cos((t - 1) * math.pi / 2), 0.1, 0.15 + math.sin((t - 1) * math.pi / 2))
		local fuera = p - dir * p:Dot(dir)
		if fuera.Magnitude < 1e-3 then
			fuera = dir:Cross(Vector3.yAxis)
			if fuera.Magnitude < 1e-3 then
				fuera = Vector3.xAxis
			end
		end
		return hombro + dir * x + fuera.Unit * r
	end
	local mejor = codoHacia(prefiere)
	local nota = 100 * choca(hombro, mejor, llega)
	if nota <= 0 then
		return mejor, llega -- lo normal: donde prefiere no choca con nada
	end
	for i = 0, CODOS do
		local t = 2 * i / CODOS
		local codo = codoHacia(t)
		local n = 100 * choca(hombro, codo, llega) + math.abs(t - prefiere)
		if n < nota then
			mejor, nota = codo, n
		end
	end
	return mejor, llega
end

-- El gateo: con Gatea y GateaHora en el modelo, se echa boca abajo y se arrastra por debajo del mueble, encima de la
-- postura de siempre (que ya está en las juntas este fotograma); sin ellos, sale arrastrándose hacia atrás y se
-- levanta. Todo sale de la cabeza: la cara baja por fuera del borde y solo se mete cuando está echado del todo (si no,
-- al echarse, la cabeza y los codos darían con el tablero); detrás va el cuello estirado, el torso (la cadera nunca
-- por debajo de GATEO.Cadera) y las piernas, a ras de suelo o levantadas si detrás hay una pared. Los brazos, por
-- cinemática 3D desde el torso que tiene de verdad este fotograma.
local function gatear(b: Bicho, dt: number, ahora: number, poco: boolean)
	local punto = b.modelo:GetAttribute("Gatea")
	local hora = b.modelo:GetAttribute("GateaHora")
	local activo = typeof(punto) == "Vector3" and typeof(hora) == "number"
	local dura = duraGateo()
	local g = b.gatea
	if activo then
		if not g or g.hora ~= hora then
			local t = math.clamp(workspace:GetServerTimeNow() - hora, 0, dura)
			-- Si llega tarde, los ruidos que ya han pasado no suenan todos de golpe.
			local sonados = 0
			for _, en in EVENTOS do
				if t * 2 / dura > en + 0.15 then
					sonados += 1
				end
			end
			local m = buscarBorde(b, punto)
			g = {
				hora = hora, punto = punto, borde = m.borde, techo = m.techo, arriba = m.arriba, atras = m.atras,
				hueco = m.hueco, caja = m.caja, medio = m.medio, t = t, sonados = sonados,
				brazo = if azar:NextNumber() < 0.5 then -1 else 1, ladeo = b.ladeo, cara0 = b.cabeza.Position, sale = 0,
				piernas = 0,
			}
			b.gatea = g
		end
		local actual = g :: Gateo
		actual.punto = punto
		actual.t = math.clamp(workspace:GetServerTimeNow() - hora, 0, dura)
		actual.sale = 0
	end
	if not g then
		return
	end
	-- Gateando (o mientras dura el susto si te ha pillado) se echa; al acabar, sale de debajo y luego se levanta.
	if activo or ahora - b.agarra < GATEO.Susto then
		b.gateo = math.min(1, b.gateo + dt / (GATEO.Cae * dura / 2))
	else
		g.sale = math.min(1, g.sale + dt / GATEO.Sale)
		if g.sale >= 1 then
			b.gateo = math.max(0, b.gateo - dt / GATEO.Levanta)
		end
	end
	if b.gateo <= 0 then
		b.gatea = nil
		return
	end
	local m = b.motores
	local w = b.gateo
	local sw = suave(w)
	local entra = suave(math.min(1, w * 4)) -- lo que manda el gateo sobre la postura de siempre
	local a, olfatea, empuje, aMano, alza = avanceGateo(g.t, poco)
	local queda = 1 - suave(g.sale)
	a *= queda
	aMano *= queda
	alza *= queda
	empuje *= queda
	local husmea = if poco then 0 else olfatea * queda
	local abajo = math.clamp((w - 0.85) / 0.15, 0, 1) -- echado del todo: ya se puede meter debajo

	-- El marco: en el suelo bajo la raíz, mirando hacia el escondido. Todo lo de abajo va en él.
	local enRaiz = b.raiz.CFrame:PointToObjectSpace(g.punto)
	local plano = Vector3.new(enRaiz.X, 0, enRaiz.Z)
	local lejos = math.max(plano.Magnitude, 0.5)
	local marco = CFrame.new(0, -ALTURA, 0) * CFrame.Angles(0, math.atan2(-plano.X, -plano.Z), 0)
	local tuAlto = math.clamp(enRaiz.Y + ALTURA, 0.6, 2)

	-- La cabeza: primero se echa atrás hasta quedar por fuera del borde y baja despacio hasta el suelo; echado, se mete
	-- a tirones hasta quedarse a GATEO.Hasta de ti, ladeada y mirándote.
	local final = lejos - GATEO.Hasta
	local fuera = math.min(g.borde - GATEO.Fuera, final)
	local function metida(av: number): number
		return fuera + (math.max(final, fuera) - fuera) * av * abajo
	end
	local enMarco = b.raiz.CFrame * marco
	local cara0 = enMarco:PointToObjectSpace(g.cara0)
	local alto = cara0.Y + (GATEO.Cara - cara0.Y) * sw + husmea * 0.05 * math.sin(ahora * 21)
	local hz = suave(math.min(1, w * 2.5))
	local centro = Vector3.new(cara0.X * (1 - hz), alto, cara0.Z + (-metida(a) - cara0.Z) * hz)
	-- Te mira sin levantar mucho la cara del suelo (si no, al estar tan cerca la cabeza se le echaba atrás).
	local mira = Vector3.new(0, tuAlto, -lejos) - centro
	local llano = math.max(Vector3.new(mira.X, 0, mira.Z).Magnitude, 0.3)
	mira = Vector3.new(mira.X, math.clamp(mira.Y, -0.5 * llano, GATEO.Alza * llano + math.max(0, 1 - sw) * 10), mira.Z)
	local giroCara = mirarCara(mira,
		(g.ladeo * GATEO.Ladeo + husmea * 0.15 * math.sin(ahora * 9)) * sw)
	local cabezaC = CFrame.new(centro) * giroCara
	-- La boca, abriéndose según se acerca (de lado); husmeando, a golpecitos; si te pilla, del todo. Si así la cabeza o
	-- la mandíbula tocaran el suelo, la cabeza sube lo justo.
	local chilla = if ahora - b.chillido < 1.6 then 0.45 + 0.1 * math.sin(ahora * 35) else 0
	local abre = (0.2 + 0.35 * a + husmea * 0.1 * math.abs(math.sin(ahora * 13)) + chilla) * w
	local boca = cabezaC * m.Mandibula.C0 * CFrame.Angles(-abre, 0, 0) * m.Mandibula.C1:Inverse() * BOCA_CAJA
	local falta = HOLGURA - math.min(masBajo(cabezaC, CABEZA_MEDIO), masBajo(boca, BOCA_MEDIO))
	if falta > 0 then
		cabezaC += Vector3.new(0, falta, 0)
	end
	local nuca = cabezaC * m.Cabeza.C1.Position

	-- El cuello, estirado: de pie va hacia delante y arriba; echado, casi tumbado, desde los hombros a ras de suelo.
	local dy = nuca.Y - GATEO.Hombros
	local echado = Vector3.new(nuca.X, dy, -math.sqrt(math.max(0.09, LARGO_CUELLO * LARGO_CUELLO - nuca.X * nuca.X - dy * dy)))
	local dirCuello = Vector3.new(0, math.cos(0.9), -math.sin(0.9)):Lerp(echado.Unit, sw)
	dirCuello = if dirCuello.Magnitude > 0.1 then dirCuello.Unit else echado.Unit
	local cuello = nuca - dirCuello * LARGO_CUELLO

	-- El torso, de un poco echado hacia delante a boca abajo; si así la cadera quedara muy baja, más tumbado. En cada
	-- tirón se balancea un poco hacia la mano que tira.
	local fi = 0.2 + (math.pi / 2 - 0.2) * sw
	fi = math.max(fi, math.acos(math.clamp((cuello.Y - GATEO.Cadera) / LARGO_TORSO, -1, 1)))
	local giroT = CFrame.fromMatrix(Vector3.zero, Vector3.xAxis, Vector3.new(0, math.cos(fi), -math.sin(fi)))
		* CFrame.Angles(0, if poco then 0 else 0.06 * empuje * g.brazo, 0)
	local torsoC = CFrame.new(cuello - giroT * m.Cuello.C0.Position) * giroT
	local cuelloC = CFrame.new(cuello) * orientar(-dirCuello, giroT.LookVector) * CFrame.new(-m.Cuello.C1.Position)
	m.Torso.Transform = m.Torso.Transform:Lerp(m.Torso.C0:Inverse() * (marco * torsoC) * m.Torso.C1, entra)
	m.Cuello.Transform = m.Cuello.Transform:Lerp(m.Cuello.C0:Inverse() * torsoC:Inverse() * cuelloC * m.Cuello.C1, entra)
	m.Cabeza.Transform = m.Cabeza.Transform:Lerp(m.Cabeza.C0:Inverse() * cuelloC:Inverse() * cabezaC * m.Cabeza.C1, entra)

	-- Los brazos, desde el torso que tiene de verdad este fotograma: de colgando, bajan hasta apoyar las manos por fuera
	-- del borde; echado, una se adelanta hasta tu lado y araña el suelo a tirones, y la otra se apoya junto a la cara,
	-- muy abierta. Los codos hacia fuera y arriba, sin dar con el tablero.
	local torso = marco:Inverse() * m.Torso.C0 * m.Torso.Transform * m.Torso.C1:Inverse()
	local limite = g.borde - 0.3 + 50 * abajo -- hasta dónde pueden ir las manos por delante de la raíz
	local manda = suave(math.min(1, w * 6))
	-- Lo que se mete un brazo en el tablero (de su altura menos GATEO.Codo a lo alto del mueble; sin saber dónde está
	-- la caja, todo lo que haya por delante del borde) o en el suelo y, debajo, el codo entre las patas (eso cuenta
	-- mucho menos: con la mano a ~3 del hombro el codo tiene que salir 2,65 hacia algún lado, y en un hueco estrecho
	-- solo cabe de lado, rozando una pata).
	local hueco = g.hueco
	local aCaja = if g.caja then g.caja:Inverse() * enMarco else nil
	local medio = g.medio
	local function tramo(p1: Vector3, p2: Vector3): number
		if aCaja then
			return dentroCaja(aCaja * p1, aCaja * p2, medio, GATEO.Codo)
		end
		local mal = 0
		for _, p in { p1, p2, p1:Lerp(p2, 0.5) } do
			if p.Z < 0.25 - g.borde and p.Y < g.arriba + 0.3 then
				mal += math.max(0, p.Y - (g.techo - GATEO.Codo))
			end
		end
		return mal
	end
	local function chocaBrazo(hombro: Vector3, codo: Vector3, mano: Vector3): number
		-- El brazo es gordo: solo los dedos (lo que pasa de 2/3 del antebrazo) llegan al suelo.
		local mal = math.max(0, 0.32 - codo.Y) + math.max(0, 0.25 - codo:Lerp(mano, 0.6).Y)
			+ tramo(hombro, codo) + tramo(codo, mano)
		if hueco and codo.Z < 0.3 - g.borde then
			mal += 0.05 * math.max(0, math.abs((enMarco * codo - hueco.centro):Dot(hueco.eje)) - hueco.ancho - 0.1)
		end
		return mal
	end
	for _, lado in LADOS do
		local brazo = m[if lado < 0 then "BrazoI" else "BrazoD"]
		local antebrazo = m[if lado < 0 then "AntebrazoI" else "AntebrazoD"]
		local hombro = torso * brazo.C0.Position
		local va = lado == g.brazo
		local hondo = if va then math.min(metida(aMano) + GATEO.Alcance, lejos) else metida(aMano) - 0.3
		local apoyo = Vector3.new(lado * (if va then 1.15 else 1.85), GATEO.Mano + alza * 0.45, -hondo)
		local rasca = if va and not poco then husmea * (1 - alza) ^ 2 else 0
		if rasca > 0 then
			-- Araña hacia sí a tirones: arrastra las uñas, las levanta y las vuelve a clavar más allá.
			local f = (ahora * 3.2 + b.semilla) % 1
			local tira = if f < 0.7 then suave(f / 0.7) else 1 - suave((f - 0.7) / 0.3)
			local sube = if f < 0.7 then 0 else math.sin(math.pi * (f - 0.7) / 0.3)
			apoyo += Vector3.new(0.04 * math.sin(ahora * 23), 0.28 * sube, 0.35 * tira) * rasca
		end
		local colgando = Vector3.new(lado * 1.3, hombro.Y - 6.2, hombro.Z + 0.8) -- recogidos hacia atrás: no por delante
		local punta = colgando:Lerp(apoyo, suave(math.min(1, w * 1.5)))
		punta = Vector3.new(punta.X, math.max(punta.Y, GATEO.Mano), math.max(punta.Z, -limite))
		if hueco and punta.Z < -g.borde then -- debajo, la mano no se sale por entre las patas
			local enMundo = enMarco * punta
			local deLado = (enMundo - hueco.centro):Dot(hueco.eje)
			punta = enMarco:PointToObjectSpace(enMundo + hueco.eje * (math.clamp(deLado, -hueco.ancho, hueco.ancho) - deLado))
		end
		local codo, llega, brazoC, antebrazoC
		for _ = 1, 2 do -- si las uñas tocaran el suelo, la mano un poco más arriba
			codo, llega = brazo3D(hombro, punta, lado, GATEO.Codos, chocaBrazo)
			brazoC = CFrame.new(hombro) * orientar(codo - hombro, Vector3.new(0, -1, -0.5)) * CFrame.new(-brazo.C1.Position)
			antebrazoC = CFrame.new(codo) * orientar(llega - codo, -Vector3.yAxis) * CFrame.Angles(-DESVIO, 0, 0)
				* CFrame.new(-antebrazo.C1.Position)
			local sobra = dedosBajo(antebrazoC) - HOLGURA
			if sobra >= 0 then
				break
			end
			punta -= Vector3.new(0, sobra, 0)
		end
		-- Antes que el torso: si no, al bajar los hombros los brazos de pie meterían las uñas en el suelo.
		brazo.Transform = brazo.Transform:Lerp(brazo.C0:Inverse() * torso:Inverse() * brazoC * brazo.C1, manda)
		local brazoReal = torso * brazo.C0 * brazo.Transform * brazo.C1:Inverse()
		antebrazo.Transform = antebrazo.Transform:Lerp(antebrazo.C0:Inverse() * brazoReal:Inverse() * antebrazoC * antebrazo.C1, manda)
	end

	-- Las piernas, a rastras detrás de la cadera; si detrás hay una pared, levantadas (poco a poco).
	local cadera = torso * m.Torso.C1.Position
	local cabeAtras = math.clamp((g.atras - 0.3 - cadera.Z) / PIERNA, 0, 1)
	local tumbadas = math.sqrt(1 - math.clamp((cadera.Y - 0.3) / PIERNA, 0, 1) ^ 2)
	g.piernas = acercar(g.piernas, if tumbadas > cabeAtras + 0.02 then 1 else 0, dt, 6)
	for _, lado in LADOS do
		local motor = m[if lado < 0 then "PiernaI" else "PiernaD"]
		local junta = cadera + torso.XVector * motor.C0.Position.X
		local cae = math.clamp((junta.Y - 0.3) / PIERNA, 0, 1)
		local largo = math.sqrt(1 - cae * cae)
		local cabe = math.clamp((g.atras - 0.3 - junta.Z) / PIERNA, 0, 1)
		local hacia = Vector3.new(lado * 0.25, 0, 1).Unit * (largo + (cabe - largo) * g.piernas)
			+ Vector3.yAxis * (-cae + (cae + math.sqrt(1 - cabe * cabe)) * g.piernas)
		local parte = CFrame.new(junta) * orientar(hacia, -Vector3.zAxis) * CFrame.new(-motor.C1.Position)
		motor.Transform = motor.Transform:Lerp(motor.C0:Inverse() * (marco * parte) * motor.C1, entra)
	end

	m.Mandibula.Transform = m.Mandibula.Transform:Lerp(CFrame.Angles(-abre, 0, 0), entra)

	-- Los ruidos, cada uno una vez (con Rendimiento, solo al echarse y el del final).
	local u = g.t * 2 / dura
	if activo and g.sonados < #EVENTOS and u >= EVENTOS[g.sonados + 1] then
		g.sonados += 1
		if not poco or g.sonados == 1 or g.sonados == #EVENTOS then
			ruidoGateo(b, g.sonados)
		end
	end
end

local function quitar(b: Bicho)
	if b.bucle then
		b.bucle:Destroy()
		b.bucle = nil
	end
	if bichos[b.modelo] == b then
		bichos[b.modelo] = nil
	end
end

local function apagar()
	if conexion then
		conexion:Disconnect()
		conexion = nil
	end
end

local function animar(dt: number)
	if next(bichos) == nil then
		apagar()
		return
	end
	local ahora = os.clock()
	local ojo = workspace.CurrentCamera.CFrame.Position
	local poco = jugador:GetAttribute("Rendimiento") == true
	local vidaLejos = if poco then VIDA_RENDIMIENTO else VIDA_LEJOS
	local noche = workspace:GetAttribute("Fase") == "Noche"
	for modelo, b in bichos do
		if not modelo.Parent or not b.raiz.Parent then
			quitar(b)
			continue
		end
		local distancia = (b.raiz.Position - ojo).Magnitude
		if distancia > LEJOS then
			if b.bucle then -- lejos no se anima: que no se quede el chirrido sonando
				b.bucle:Destroy()
				b.bucle = nil
			end
			continue
		end
		local m = b.motores
		local raspando = modelo:GetAttribute("Raspando") == true
		local luz = modelo:GetAttribute("Iluminado") == true and raspando
		local chillando = ahora - b.chillido < 1.6
		b.raspar = acercar(b.raspar, if raspando then 1 else 0, dt, 3)
		b.encogido = acercar(b.encogido, if luz or chillando then 1 else 0, dt, if luz or chillando then 10 else 2)

		local v = b.raiz.AssemblyLinearVelocity
		local rapidez = Vector3.new(v.X, 0, v.Z).Magnitude
		local paso = math.min(1, rapidez / 6)
		b.fase += dt * rapidez * 0.5
		local s = math.sin(b.fase)
		local gateando = b.gateo > 0 or modelo:GetAttribute("Gatea") ~= nil -- mientras gatea, la vida de espera se pausa
		b.vida = acercar(b.vida, if (rapidez < QUIETO or raspando) and not chillando and not gateando and distancia < vidaLejos
			then 1 else 0, dt, 2)
		local vida = b.vida * (1 - b.encogido)

		-- Dónde está el cristal (cada segundo mientras raspa): la cara y las manos se quedan justo delante. La cara se
		-- mide también a la altura de lo alto de la cabeza: si la ventana es baja, ahí está la pared (más cerca).
		if raspando and distancia < vidaLejos and ahora - b.medido > 1 then
			b.medido = ahora + azar:NextNumber(-0.25, 0.25) -- a destiempo si hay varios
			b.hastaCara = math.min(medir(b, ALTO_CARA) or CRISTAL, (medir(b, ALTO_CARA + ALTO_CABEZA) or CRISTAL) + HUNDE)
			for i, lado in LADOS do
				b.hastaManos[i] = medir(b, ALTO_MANOS, lado * MANO_X) or b.hastaCara
			end
			b.pegar = inclinar(m, b.hastaCara - MARGEN_CARA)
		end

		-- Respira despacio y hondo; de noche, al soltar el aire, echa vaho contra el cristal (la boca pegada al
		-- cristal ya cuenta como dentro de la casa: se mira dónde tiene los pies).
		b.respira += dt * 2 * math.pi / RESPIRA
		local aire = math.sin(b.respira)
		local soltando = math.cos(b.respira) < 0
		if soltando and not b.exhala and noche and not poco and vida > 0.5 and distancia < VAHO_LEJOS
			and not dentroDeCasa(b.raiz.Position)
		then
			echarVaho(b.cabeza.CFrame * BOCA)
		end
		b.exhala = soltando

		-- El peso, los dedos que se crispan y las cosas raras.
		b.peso += dt * 2 * math.pi / PESO
		local w = math.sin(b.peso) * vida
		if vida > 0.5 and ahora >= b.proximaCrispa then
			b.proximaCrispa = ahora + rango(CRISPA)
			b.crispa[azar:NextInteger(1, 2)] = ahora
		end
		if vida > 0.8 and ahora >= b.proximoRaro then
			b.proximoRaro = ahora + rango(RARO)
			b.raro = ahora
			b.tipoRaro = azar:NextInteger(1, 2)
		end
		-- Con tope: sin él, antes de la primera daba math.sin(inf) = NaN, y 0 · NaN = NaN rompía el cuello y la cabeza.
		local tr = math.min(ahora - b.raro, 2.2)
		local cruje = if b.tipoRaro == 1 and tr < 0.6 then (1 - tr / 0.6) ^ 2 * vida else 0
		local bocaLenta = 0
		if b.tipoRaro == 2 and tr < 2.2 then
			bocaLenta = (if tr < 1.4 then suave(tr / 1.4) else 1 - suave((tr - 1.4) / 0.8)) * vida
		end

		-- La cabeza: ladeada; poco a poco hacia el jugador más cercano (de dentro, si raspa), con tironcitos.
		if vida > 0.05 then
			if ahora >= b.cambiaLadeo then
				b.cambiaLadeo = ahora + rango(CAMBIA_LADEO)
				b.ladeo = -b.ladeo
			end
			if ahora >= b.buscar then
				b.buscar = ahora + rango(BUSCAR)
				b.mira = jugadorCerca(b.cabeza.Position, VER, if raspando then b.raiz.CFrame.LookVector else nil)
			end
			local cabeceo, giro = 0, 0
			local suya = b.mira
			if suya and suya.Parent then
				local r = b.raspar
				cabeceo, giro = mirada(b, suya.Position, -0.2 * (1 - r), 0.8 - 0.48 * r, -0.4 + 0.28 * r, 0.35 - 0.15 * r)
			end
			b.meta = Vector3.new(cabeceo, giro, b.ladeo * (LADEO + 0.15 * bocaLenta))
			b.cab = b.cab:Lerp(b.meta, math.min(1, dt * 1.3))
			if ahora >= b.proximoRespingo then
				b.proximoRespingo = ahora + rango(RESPINGO)
				b.respingoHora = ahora
				b.respingo = Vector3.new(azar:NextNumber(-0.05, 0.05), azar:NextNumber(-0.09, 0.09), azar:NextNumber(-0.12, 0.12))
			end
		end
		local tRes = ahora - b.respingoHora
		local respingo = b.respingo * (if tRes < 0.05 then tRes / 0.05 else math.exp(-(tRes - 0.05) * 5))

		-- Torso: pegado al cristal (raspando) o echado atrás (luz); respira y pasa el peso de un pie a otro.
		local inclina = b.raspar * b.pegar + b.encogido * 0.45 + 0.03 * aire
		local torso = CFrame.new(0.06 * w, 0.04 * aire * vida, 0) * CFrame.Angles(inclina, 0, 0.02 * w)
		m.Torso.Transform = torso
		m.PiernaI.Transform = CFrame.Angles(s * 0.7 * paso + 0.04 * math.max(0, w), 0, -0.015 * w)
		m.PiernaD.Transform = CFrame.Angles(-s * 0.7 * paso + 0.04 * math.max(0, -w), 0, -0.015 * w)

		-- Brazos: colgando y balanceándose al andar; raspando, las manos al cristal (una y otra, a destiempo); encogido,
		-- las manos se despegan y se recogen delante del pecho, temblando: con la linterna solo la izquierda (con la otra
		-- sigue arañando, más despacio: el servidor raspa más lento, no para) y al chillar las dos. Todo por cinemática:
		-- de un sitio a otro la punta de los dedos va en línea recta, sin cruzar el cristal.
		local temblor = b.encogido * math.sin(ahora * 40) * 0.05
		local aranan = 0
		local peso = math.min(1, b.raspar + b.encogido) -- suma: al chillar, una baja mientras la otra sube
		b.pasada += dt / PASADA * (if luz then 0.3 else 1)
		for i, lado in LADOS do
			local hombro = m[if lado < 0 then "BrazoI" else "BrazoD"]
			local codo = m[if lado < 0 then "AntebrazoI" else "AntebrazoD"]
			local h = lado * (s * 0.4 * paso - math.sin(ahora * 1.1) * 0.05)
			local c, giro, rasca = 0.25, 0, 0
			local retira = if chillando or lado < 0 then b.encogido else 0
			if peso > 0.01 then
				local u = (b.pasada + (if lado < 0 then 0 else 0.5) + b.semilla) % 1
				local alto, despega, arana = pasada(u)
				aranan += arana * arana * (1 - retira)
				rasca = arana * vida
				-- La punta de los dedos en el cristal (la cinemática solo mira la altura y la distancia; de lado va el hombro).
				local enCristal = Vector3.new(
					lado * MANO_X,
					alto + 0.035 * math.sin(ahora * 23 + lado * 1.7) * rasca + 0.08 * cruje,
					-(b.hastaManos[i] - MARGEN_MANOS) + DESPEGA * despega
				)
				local recogida = Vector3.new(lado * RECOGIDA.X, RECOGIDA.Y, RECOGIDA.Z)
				local hIK, cIK = brazoIK(m, torso, hombro, enCristal:Lerp(recogida, retira))
				h += (hIK - h) * peso
				c += (cIK - c) * peso
				giro = 0.14 * math.sin(ahora * 15 + lado) * rasca * (1 - retira) -- los dedos rascando
			end
			c -= 0.15 * crispacion(ahora - b.crispa[i]) * vida -- los dedos se despegan de golpe
			-- Al subirlos al cristal o bajarlos pasan por el lado (por delante los codos y los dedos atravesarían el cristal).
			local abre = 0.08 + 1.0 * math.sin(math.pi * peso) + 0.02 * math.sin(ahora * 17 + lado * 2) * rasca
			hombro.Transform = CFrame.Angles(h + lado * temblor * (0.3 + 0.7 * retira), 0, lado * abre) -- la que araña, poco
			codo.Transform = CFrame.Angles(c, giro, 0)
		end

		-- Cuello y cabeza: estirados contra el cristal al raspar; ladeada y volviéndose hacia ti; si le alumbran, la aparta.
		local tiron = if math.noise(ahora * 2, b.semilla) > 0.35 then 0.25 else 0
		local andando = Vector3.new(0, 0, 0.3 * math.sin(ahora * 0.6) + tiron)
		local h = andando:Lerp(b.cab + respingo, vida)
		m.Cuello.Transform = CFrame.Angles(b.raspar * CUELLO_PEGADO - 0.015 * aire, 0, cruje * 0.35 * math.sin(tr * 22))
		m.Cabeza.Transform = CFrame.fromEulerAnglesYXZ(
			b.raspar * CABEZA_PEGADA + h.X,
			b.encogido * 0.9 + temblor * 4 + h.Y + cruje * 0.3 * math.sin(tr * 17),
			h.Z
		)
		local abre = 0.15 + b.encogido * 0.35 + (if chillando then 0.6 + 0.12 * math.sin(ahora * 35) else 0)
			+ vida * (0.06 * math.max(0, -aire) + 0.5 * bocaLenta)
		m.Mandibula.Transform = CFrame.Angles(-abre, 0, 0)

		-- Debajo de un mueble: se echa boca abajo y se arrastra a por ti, encima de todo lo anterior.
		gatear(b, dt, ahora, poco)

		-- El chirrido en bucle mientras raspa, más fuerte a mitad de cada pasada; con luz casi para.
		if raspando and not b.bucle then
			b.bucle = Sonido.bucle("Raspado", b.cabeza)
			local bucle = b.bucle :: Sound
			bucle.RollOffMode = Enum.RollOffMode.InverseTapered
			bucle.RollOffMinDistance = 8
			bucle.RollOffMaxDistance = 70
		elseif not raspando and b.bucle then
			b.bucle:Destroy()
			b.bucle = nil
		end
		if b.bucle then
			b.bucle.Volume = 1.2 * math.min(1, aranan) * (if luz then 0.25 else 1)
			b.bucle.PlaybackSpeed = if luz then 0.7 else 0.9
		end

		local pie = if s >= 0 then 1 else -1
		if rapidez > 2 and pie ~= b.pisada then
			b.pisada = pie
			Sonido.en("Paso", b.raiz.Position - Vector3.new(0, 4, 0), 1.35)
		end
	end
end

local function encender()
	if not conexion then
		conexion = RunService.Stepped:Connect(function(_, dt)
			animar(dt)
		end)
	end
end

local function preparar(modelo: Instance)
	if not modelo:IsA("Model") or modelo.Name ~= "Raspador" then
		return
	end
	local raiz = modelo:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	local cabeza = modelo:WaitForChild("Cabeza", 5) :: BasePart?
	if not raiz or not cabeza then
		return
	end
	local motores = {}
	for _, nombre in MOTORES do
		local motor = raiz:WaitForChild(nombre, 5)
		if not motor or not motor:IsA("Motor6D") then
			return -- a medias (se ha ido mientras llegaba): se prepara si vuelve
		end
		motores[nombre] = motor
	end
	if not modelo.Parent then
		return
	end
	local antes = bichos[modelo :: Model]
	if antes then
		quitar(antes) -- ha vuelto (StreamIn): de cero
	end
	local ahora = os.clock()
	bichos[modelo :: Model] = {
		modelo = modelo :: Model, raiz = raiz, cabeza = cabeza, motores = motores, fase = 0, pisada = 1,
		chillido = -math.huge, encogido = 0, raspar = 0, bucle = nil, semilla = azar:NextNumber(0, 100), pasada = 0, vida = 0,
		respira = azar:NextNumber(0, 2 * math.pi), exhala = false, peso = azar:NextNumber(0, 2 * math.pi),
		hastaCara = CRISTAL, hastaManos = { CRISTAL, CRISTAL }, pegar = inclinar(motores, CRISTAL - MARGEN_CARA), medido = -math.huge,
		ladeo = if azar:NextNumber() < 0.5 then -1 else 1, cambiaLadeo = ahora + rango(CAMBIA_LADEO),
		cab = Vector3.zero, meta = Vector3.zero, mira = nil, buscar = ahora,
		respingo = Vector3.zero, respingoHora = -math.huge, proximoRespingo = ahora + rango(RESPINGO),
		crispa = { -math.huge, -math.huge }, proximaCrispa = ahora + rango(CRISPA),
		raro = -math.huge, tipoRaro = 1, proximoRaro = ahora + rango(RARO),
		gateo = 0, gatea = nil, agarra = -math.huge,
	}
	encender()
end

local function cercano(punto: Vector3, maximo: number): Bicho?
	local mejor, distancia = nil, maximo
	for _, b in bichos do
		local d = (b.raiz.Position - punto).Magnitude
		if d < distancia then
			mejor, distancia = b, d
		end
	end
	return mejor
end

-- Para MuerteVista (quién te ha pillado, PosturaReglas.quienPilla): los Raspadores a menos de 12 de `punto` (la
-- cara del susto), sin tocarlos: su modelo, a cuánto tiene la cabeza de `punto` y dónde estaba el escondido a por
-- el que gatea (si gatea).
function RaspadorVista.candidatos(punto: Vector3): { { modelo: Model, distancia: number, gatea: Vector3? } }
	local lista = {}
	for _, b in bichos do
		if (b.raiz.Position - punto).Magnitude < 12 then
			local cara = if b.cabeza.Parent then b.cabeza.Position else b.raiz.Position
			table.insert(lista, {
				modelo = b.modelo,
				distancia = (cara - punto).Magnitude,
				gatea = b.gatea and b.gatea.punto,
			})
		end
	end
	return lista
end

-- Abre la boca del todo (el susto al morir). Devuelve el Raspador que tenga la cabeza cerca de `punto`, si hay.
-- `modelo`: el que ha elegido MuerteVista (si no es un Raspador, nada); sin él, el más cerca de `punto`.
function RaspadorVista.rugir(punto: Vector3, modelo: Model?): Model?
	local b = if modelo then bichos[modelo] else cercano(punto, 12)
	if b then
		b.chillido = os.clock()
		if b.gatea then
			b.agarra = os.clock() -- te ha pillado gateando: se queda en el suelo mientras dura el susto
		end
		return b.modelo
	end
	return nil
end

function RaspadorVista.start()
	carpeta = workspace:WaitForChild("Bichos")
	local bichosCarpeta = carpeta :: Instance
	bichosCarpeta.ChildAdded:Connect(preparar)
	for _, modelo in bichosCarpeta:GetChildren() do
		task.spawn(preparar, modelo)
	end
	Remotes.Raspador.OnClientEvent:Connect(function(tipo: string, cosa: Instance)
		if tipo == "Chilla" and cosa and bichos[cosa :: Model] then
			local b = bichos[cosa :: Model]
			b.chillido = os.clock()
			Sonido.en("Chillido", b.raiz.Position + Vector3.new(0, 3, 0))
		elseif tipo == "Entra" and cosa then
			local centro = cosa:GetAttribute("Centro")
			if typeof(centro) == "CFrame" then
				Sonido.en("Chillido", centro.Position, 0.6) -- grave: ruge al entrar
				local b = cercano(centro.Position, 15)
				if b then
					b.chillido = os.clock() + 0.6
				end
			end
		end
	end)
end

return RaspadorVista
