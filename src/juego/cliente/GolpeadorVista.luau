-- Mueve el cuerpo del Golpeador en el cliente (el servidor solo lo desplaza): piernas y brazos que se balancean al
-- andar, la cabeza ladeada, el golpe (remote Golpeador "Golpe") y el rugido al entrar. Pasos pesados al andar.
-- Esperando o golpeando, pesado y con rabia (pedido por el usuario: "los bichos con más vida mientras esperan"):
--   respira fuerte (pecho y hombros; jadea justo después de cada golpe), pasa el peso de un pie a otro, se le crispan
--   los hombros y los brazos y de vez en cuando le da una sacudida rara. La cabeza va a tirones hacia la ventana, hacia
--   el jugador más cercano o a un lado, como si oyera algo. Si le miras por la mirilla (atributo local "Mirilla"), se da
--   cuenta, gira la cabeza hacia ti y se te queda mirando con la boca abriéndose.
--   Cada golpe: se echa atrás subiendo los brazos por los lados hasta encima de la cabeza, descarga con todo el cuerpo
--   contra la pared de encima de la ventana, rebota y los baja por los lados (son tan largos que, si pasaran por
--   delante, atravesarían el cristal). Las garras se hunden un poco en la pared sin asomar por dentro, también si se ha
--   parado algo más cerca (comprobado con Lune). Esperando el siguiente se va preparando, temblando de rabia.
--   De noche y fuera de la casa echa vaho por la boca al soltar el aire (sin él con Rendimiento).
-- Un solo bucle (Stepped) que solo corre mientras hay alguno; la vida, solo cerca de la cámara. Si el modelo se va
-- (StreamOut o lo quita el servidor) se olvida, y si vuelve se prepara otra vez.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sonido = require(script.Parent.Sonido)

local GolpeadorVista = {}

-- Números visuales a ojo (se retocan en Studio).
local LEJOS = 250 -- studs de la cámara: más lejos no se le mueve nada
local VIDA_LEJOS = 120 -- la vida (respirar, tirones, crisparse...) solo hasta aquí...
local VIDA_RENDIMIENTO = 45 -- ...o hasta aquí con Rendimiento
local VAHO_LEJOS = 60
local QUIETO = 1.5 -- studs/s: más despacio está esperando (o golpeando)
local RESPIRA = { 1.3, 2.4 } -- segundos por respiración: jadeando justo después de un golpe y ya calmado
local PESO = 4.6 -- segundos en pasar el peso de un pie al otro y volver
local TIRON = { 0.5, 2 } -- segundos entre dos tirones de la cabeza
local CRISPA = { 1.2, 3.5 } -- segundos entre dos crispaciones de un hombro
local SACUDIDA = { 5, 10 } -- segundos entre dos sacudidas raras
local DURA_SACUDIDA = 0.55
local VER = 45 -- studs: mira a los jugadores que tenga más cerca que esto
local GIRO = 1 -- radianes que gira la cabeza como mucho a cada lado
local REPOSO_CABEZA = -0.25 -- en reposo la cabeza mira un poco hacia abajo (lo inclinado del cuello)
local LADEO = 0.35 -- la cabeza ladeada
local MIRILLA = 14 -- studs de la cámara a su cabeza: te ve mirarle por la mirilla
local MIRILLA_REACCION = 0.5 -- segundos hasta que se da cuenta
local BOCA = CFrame.new(0, -0.45, -0.75) -- en la cabeza
local VAHO = 6 -- partículas cada vez que suelta el aire
-- El golpe (segundos desde que llega "Golpe"; el servidor lo da a los 0,35): sube los brazos por los lados echándose
-- atrás (Carga), descarga (Descarga), rebota (Rebote) y los baja por los lados (Fin). Esperando el siguiente se va
-- preparando hasta `Prepara` (de 0 a 3, ver `postura`); si no llega en `Espera`, los baja.
local GOLPE = { Carga = 0.32, Descarga = 0.42, Rebote = 0.55, Fin = 1.15, Espera = 2.6, Prepara = 0.8 }
-- Posturas del brazo por las que pasa el golpe, como { hacia delante, hacia fuera } (giros de la junta del hombro):
-- reposo, por el lado hacia abajo, por el lado hacia arriba, encima de la cabeza (un poco atrás) y el golpe (arriba y
-- delante, contra la pared de encima de la ventana). De una a otra cada giro va por separado: así el brazo sube y baja
-- por el lado sin irse hacia delante (con Lerp de CFrame, a medio camino se iba por delante y se metía en la pared
-- hasta asomar por dentro: comprobado con Lune).
local CLAVES = { { 0, 0.1 }, { 0, 0.9 }, { 0, 2 }, { 0.3, 2.9 }, { -0.2, 2.85 } }
-- El golpe de CLAVES llega justo a la pared (las garras entran ~0,5 en ella, de 1 de grueso) desde Fuera, a 4 studs del
-- Centro de la ventana (Mapa). Si se ha parado más cerca, echa los brazos atrás lo que falte: ALCANCE es lo que avanzan
-- las garras por radián (comprobado con Lune).
local FUERA, ALCANCE = 4, 6.5
local MOTORES = { "Torso", "PiernaI", "PiernaD", "BrazoI", "BrazoD", "Cabeza", "Mandibula" }
local LADOS = { -1, 1 }
-- Gatear a por alguien escondido debajo de un mueble (pedido por el usuario: "que el monstruo pueda gatear si te huele
-- con una animación guapa para pillarte debajo de sitios"). El servidor (Caza) le para en el borde, de cara a ti, y pone
-- en su modelo Gatea (dónde estás) y GateaHora (workspace:GetServerTimeNow() al empezar) durante Config.Postura.Gatear s.
-- Pesado: se dobla hasta el suelo apoyando los brazos larguísimos, mete la cabeza de lado a ras de suelo, mirándote, y
-- barre por debajo con un brazo, a tirones, parándose a olfatear. La cara baja por fuera del borde y solo entra cuando
-- está abajo; al acabar, primero la saca, recoge el brazo y luego se levanta. La mesa se mide por su zona Debajo (los
-- rayos no ven los muebles). Comprobado con Lune contra las mesas del comedor (tablero a 2,84 del suelo) y de la cocina
-- (3,29, con caballetes y una viga baja), con el bicho a 0,5-5 studs del borde, de frente y en diagonal: ni el suelo, ni
-- el tablero, ni las patas se atraviesan (tampoco de pie junto a la mesa: los brazos se echan atrás).
local ALTURA = 5 -- de los pies al centro de la raíz (Golpeador.luau)
local GATEO = {
	Cae = 0.45, -- segundos en echarse al suelo
	Sale = 0.35, -- al acabar, segundos en sacar la cabeza de debajo...
	Levanta = 0.6, -- ...y en levantarse
	Recoge = 0.5, -- segundos como mucho que espera a recoger el brazo antes de levantarse
	Cara = 1.2, -- studs del suelo al centro de la cabeza
	Ladeo = 1.35, -- la cabeza casi de lado (así la boca se abre de lado y no contra el suelo)
	Hasta = 1.1, -- studs entre su cara y tú al acabar
	Avanza = 1.6, -- studs que mete la cabeza desde que se echa hasta el final
	Fuera = 1.3, -- studs por fuera del borde a los que baja la cara (luego entra a tirones)
	Aparta = 1.2, -- y lo que se aleja más de pie (al echarse viene de ahí y al levantarse vuelve)
	Borde = 1.4, -- studs del borde del mueble hasta ti, si los rayos no encuentran el tablero
	Dentro = 0.55, -- studs que mete el centro de la cara por debajo del tablero (más, el torso tocaría uno de 2,84)
	Inclina = math.rad(55), -- doblado, el torso va de la cadera a los hombros hacia abajo
	Bajo = 1.95, -- studs del suelo al centro de la cara: más arriba no entra debajo del tablero
	-- Los tirones, en segundos de un gateo de 2 s: {empieza, acaba, hasta dónde ha metido la cabeza (0..1)}.
	Tirones = { { 0.5, 0.68, 0.4 }, { 1, 1.18, 0.72 }, { 1.5, 1.75, 1 } },
	Susto = 2.2, -- segundos que se queda en el suelo si te pilla (MuerteVista mira su cara)
}
-- Medidas del cuerpo (Golpeador.crear) que usa el gateo.
local CABEZA_CENTRO = Vector3.new(0, 0.6, -0.4) -- del cuello al centro de la cabeza (en la cabeza)
local GARRAS = Vector3.new(0, -7.36, -0.32) -- del hombro a la punta de las garras (en el brazo)
local PIERNA = 4.1 -- de la cadera al pie
-- Los brazos al gatear (giros en radianes desde hacia ti, por su lado de fuera): el de apoyo, abierto hacia fuera y algo
-- atrás; si se meten en una pata del mueble, se apartan hacia `Atras` (`Holgura`: lo gordo del brazo). El que mete
-- gira hacia ti como mucho a `Barre` (de 0 a 1) por segundo, y ninguno gira más deprisa que `Giro` por segundo.
local BRAZO = {
	Apoyo = 2.2, -- radianes desde hacia ti, por fuera
	Atras = 2.8,
	Holgura = 0.42,
	Barre = 3,
	Giro = 5,
}
-- Lo más bajo de la mandíbula (en ella): sus esquinas y la sangre que le chorrea de la barbilla.
local BARBILLA = {
	Vector3.new(-0.55, -0.8, -0.61), Vector3.new(0.55, -0.8, -0.61), Vector3.new(-0.55, -0.18, 0.6), Vector3.new(0.55, -0.18, 0.6),
	Vector3.new(-0.55, -0.18, -0.6), Vector3.new(0.55, -0.18, -0.6),
}
-- Junto a un mueble con hueco, los brazos de pie (y al echarse y levantarse) se echan atrás desde el hombro para no
-- atravesar su tablero: lo justo, hasta `Max` radianes, `Sube`/`Baja` radianes por segundo.
local APARTA = { Cerca = 10, Cada = 0.5, Max = 1.6, Sube = 9, Baja = 2.5, Holgura = 0.35 }
-- La cabeza, para no meterla en una pata o travesaño: de qué altura a qué altura del suelo va (con la mandíbula y la
-- sangre), lo que ocupa a cada lado y lo que sobresale por delante de su centro.
-- (La cabeza va de lado: la mandíbula sobresale `Boca` hacia el lado del brazo que mete; al otro, `Ancho`.)
local CABEZA_FONDO = { Bajo = 0.2, Alto = 2.5, Ancho = 0.8, Boca = 1.5, Delante = 1 }
local BORDE_HOLGURA = 0.2 -- studs: se toma el borde del tablero un poco antes de donde está

local jugador = Players.LocalPlayer
local azar = Random.new()
local filtroGateo = RaycastParams.new()
filtroGateo.FilterType = Enum.RaycastFilterType.Exclude

-- Las patas del mueble debajo del que está el escondido (sus cajas de choque: centro y mitad de su tamaño), para que
-- los brazos no las atraviesen.
type Patas = { { cf: CFrame, medio: Vector3 } }

-- Un gateo: el de ahora o el último (mientras vuelve a su pose).
type Gateo = {
	hora: number, -- GateaHora (hora del servidor)
	punto: Vector3, -- Gatea: dónde está el escondido
	borde: number, -- studs (por el suelo, hacia ti) de la raíz al borde del tablero
	t: number, -- segundos desde que empezó (se queda en el último al acabar)
	sonados: number, -- cuántos ruidos del gateo han sonado
	brazo: number, -- el brazo que mete por debajo: -1 izquierdo, 1 derecho
	cara0: Vector3, -- dónde tenía la cabeza al empezar (en el mundo)
	sale: number, -- 0..1: al acabar, cuánto ha sacado ya la cabeza de debajo
	espera: number, -- segundos desde que la sacó, esperando a recoger el brazo para levantarse
	patas: Patas?,
	fondo: number, -- studs (por el suelo, desde la raíz) hasta la primera pata o travesaño delante de la cabeza
	barre: number, -- 0..1, suave: cuánto ha girado el brazo que mete hacia ti
	rumbo: { [number]: number }, -- por brazo (-1, 1): hacia dónde va de verdad (radianes por el suelo, 0 hacia ti)
}

type Bicho = {
	modelo: Model,
	raiz: BasePart,
	cabeza: BasePart,
	motores: { [string]: Motor6D },
	fase: number,
	pisada: number,
	golpe: number, -- os.clock del último "Golpe"
	desde: number, -- por dónde iban los brazos cuando llegó (0..3)
	avance: number, -- por dónde van ahora: 0 reposo, 3 arriba, 4 el golpe, 5 de vuelta
	ventana: CFrame?, -- el Centro de lo que golpea (su LookVector mira hacia fuera)
	rugido: number,
	vida: number, -- 0..1, suave: esperando y cerca de la cámara
	respira: number, -- fase de la respiración (radianes)
	exhala: boolean,
	peso: number,
	cab: Vector3, -- la cabeza ahora (cabeceo, giro, ladeo)...
	meta: Vector3, -- ...y a dónde va a dar el tirón
	mira: BasePart?, -- la cabeza del jugador al que mira
	tiron: number, -- os.clock del próximo tirón
	teVe: number?, -- os.clock desde el que sabe que le miras por la mirilla
	crispa: { number }, -- os.clock de la última crispación de cada hombro (1 izquierdo, 2 derecho)
	proximaCrispa: number,
	sacudida: number,
	proximaSacudida: number,
	gateo: number, -- 0..1, suave: echado al suelo a por alguien debajo de un mueble
	gatea: Gateo?,
	agarra: number, -- os.clock de rugir: el susto al morir le deja en el suelo
	mesa: { cf: CFrame, tam: Vector3 }?, -- el tablero con hueco más cercano (mesaCerca)
	mesaHasta: number, -- os.clock en que se vuelve a buscar
	aparta: { number }, -- radianes, suave: lo que se echa atrás cada brazo para no atravesarlo (1 izquierdo, 2 derecho)...
	aparta2: { number }, -- ...de pie y, encima, gateando
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

-- Una crispación: sube de golpe y se apaga temblando (0..1).
local function crispacion(t: number): number
	if t < 0 or t > 0.45 then
		return 0
	end
	local x = t / 0.07
	return x * math.exp(1 - x) * (1 + 0.25 * math.sin(t * 70))
end

-- Como CuerpoVista: dentro de la casa no se ve el vaho.
local function dentroDeCasa(p: Vector3): boolean
	local c = Config.Casa
	return math.abs(p.X) < c.MedioX and math.abs(p.Z) < c.MedioZ and p.Y < 28
end

-- El vaho: una nube que sale de la boca hacia delante y se deshace (las partículas se quedan donde salen).
local function echarVaho(boca: CFrame)
	if not vahoEmisor then
		local a = Instance.new("Attachment")
		a.Name = "VahoGolpeador"
		a.Parent = workspace.Terrain
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.LightInfluence = 1 -- de noche apenas se ve: con la linterna o la luz de la ventana
		e.Color = ColorSequence.new(Color3.fromRGB(215, 220, 228))
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.78), NumberSequenceKeypoint.new(1, 1) })
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1.3) })
		e.Lifetime = NumberRange.new(1.2, 1.9)
		e.Speed = NumberRange.new(1.4, 2.4)
		e.SpreadAngle = Vector2.new(20, 20)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-25, 25)
		e.Acceleration = Vector3.new(0, 0.5, 0)
		e.Drag = 1.6
		e.Rate = 0
		e.Parent = a
		vahoPunto, vahoEmisor = a, e
	end
	-- Sale por el eje Y del punto: hacia delante y un poco hacia abajo.
	local hacia = (boca.LookVector - boca.UpVector * 0.3).Unit
	;(vahoPunto :: Attachment).WorldCFrame = CFrame.lookAt(boca.Position, boca.Position + hacia) * CFrame.Angles(-math.pi / 2, 0, 0)
	;(vahoEmisor :: ParticleEmitter):Emit(VAHO)
end

-- La cabeza del jugador vivo y a la vista (sin esconder) más cercano a `desde`, si hay alguno a menos de `maximo`.
local function jugadorCerca(desde: Vector3, maximo: number): BasePart?
	local mejor, distancia = nil, maximo
	for _, otro in Players:GetPlayers() do
		if otro:GetAttribute("Muerto") or otro:GetAttribute("Escondido") then
			continue
		end
		local personaje = otro.Character
		local suya = personaje and personaje:FindFirstChild("Head") :: BasePart?
		if suya then
			local d = (suya.Position - desde).Magnitude
			if d < distancia then
				mejor, distancia = suya, d
			end
		end
	end
	return mejor
end

-- Cabeceo y giro de la cabeza para mirar a `punto` (en la raíz, con los topes).
local function mirada(b: Bicho, punto: Vector3): (number, number)
	local d = b.raiz.CFrame:VectorToObjectSpace(punto - b.cabeza.Position)
	local cabeceo = math.atan2(d.Y, math.sqrt(d.X * d.X + d.Z * d.Z)) - REPOSO_CABEZA
	return math.clamp(cabeceo, -0.5, 0.45), math.clamp(math.atan2(-d.X, -d.Z), -GIRO, GIRO)
end

-- Por dónde van los brazos del golpe (0 reposo, 3 arriba, 4 el golpe, 5 de vuelta) y cuánto rebotan.
local function avanceGolpe(b: Bicho, ahora: number): (number, number)
	local t = ahora - b.golpe
	if t < GOLPE.Carga then
		local u = t / GOLPE.Carga
		return b.desde + (3 - b.desde) * (1 - (1 - u) * (1 - u)), 0
	elseif t < GOLPE.Descarga then
		local u = (t - GOLPE.Carga) / (GOLPE.Descarga - GOLPE.Carga)
		return 3 + u * u, 0
	elseif t < GOLPE.Rebote then
		return 4, math.sin(math.pi * (t - GOLPE.Descarga) / (GOLPE.Rebote - GOLPE.Descarga))
	elseif t < GOLPE.Fin then
		return 4 + suave((t - GOLPE.Rebote) / (GOLPE.Fin - GOLPE.Rebote)), 0
	elseif t < GOLPE.Espera then
		-- Esperando el siguiente golpe: se va echando atrás con los brazos abiertos.
		return GOLPE.Prepara * suave(math.clamp((t - GOLPE.Fin) / 0.5, 0, 1)), 0
	elseif t < GOLPE.Espera + 0.6 then
		return GOLPE.Prepara * (1 - suave((t - GOLPE.Espera) / 0.6)), 0 -- no llega: los baja
	end
	return 0, 0
end

-- El giro del hombro a lo largo del golpe (ver CLAVES): hacia delante y hacia fuera. De vuelta pasa por el lado, nunca
-- por delante.
local function postura(p: number): (number, number)
	local a, b, u
	if p >= 4 then
		if p < 4.4 then
			a, b, u = CLAVES[5], CLAVES[3], (p - 4) / 0.4
		elseif p < 4.75 then
			a, b, u = CLAVES[3], CLAVES[2], (p - 4.4) / 0.35
		else
			a, b, u = CLAVES[2], CLAVES[1], math.min(1, (p - 4.75) / 0.25)
		end
	else
		local i = math.floor(p)
		a, b, u = CLAVES[i + 1], CLAVES[i + 2], p - i
	end
	return a[1] + (b[1] - a[1]) * u, a[2] + (b[2] - a[2]) * u
end

-- Lo que hace el resto del cuerpo con el golpe: inclinación del torso (+ atrás), cabeceo de la cabeza y boca.
local function cuerpoGolpe(p: number): (number, number, number)
	if p <= 3 then
		local u = p / 3
		return 0.32 * u ^ 0.7, 0.3 * u, 0.35 * u
	elseif p <= 4 then
		local u = p - 3
		return 0.32 - 0.4 * u, 0.3 - 0.5 * u, 0.35 + 0.35 * u
	end
	local u = 5 - p
	return -0.08 * u, -0.2 * u, 0.7 * u
end

local function apagar()
	if conexion then
		conexion:Disconnect()
		conexion = nil
	end
end

-- A dónde da el próximo tirón de la cabeza: a la ventana, al jugador más cercano o a un lado.
local function decidirTiron(b: Bicho, ahora: number)
	b.tiron = ahora + rango(TIRON)
	local ladeo = LADEO + azar:NextNumber(-0.15, 0.2)
	local suerte = azar:NextNumber()
	b.mira = nil
	if suerte < 0.8 and suerte >= 0.45 then
		b.mira = jugadorCerca(b.cabeza.Position, VER)
	end
	if b.mira then
		b.meta = Vector3.new(b.cab.X, b.cab.Y, ladeo) -- el cabeceo y el giro, en cada fotograma
	elseif suerte < 0.8 then
		-- Hacia dentro por la ventana (si golpea una), o al frente.
		local ventana = if ahora - b.golpe < 6 then b.ventana else nil
		local cabeceo, giro = -0.05, 0
		if ventana then
			cabeceo, giro = mirada(b, ventana.Position - ventana.LookVector * 8 + Vector3.new(0, 1, 0))
		end
		b.meta = Vector3.new(cabeceo + azar:NextNumber(-0.06, 0.06), giro + azar:NextNumber(-0.12, 0.12), ladeo)
	else
		-- A un lado, como si oyera algo.
		b.meta = Vector3.new(azar:NextNumber(-0.3, 0.2), azar:NextNumber(-0.8, 0.8), ladeo + azar:NextNumber(-0.1, 0.25))
	end
end

-- Un giro con -Y hacia `abajo` y -Z lo más cerca posible de `delante` (brazos y piernas).
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

-- El tablero de un mueble con zona Debajo (Mapa, HUECOS). Las piezas de los muebles y sus cajas de choque no se ven con
-- rayos (CanQuery false), así que se mira el atributo Tam del mueble (el tablero llega a sus bordes, desde lo alto de la
-- zona hasta arriba); si su pivote no cuadra con la zona, se da por hecho que el tablero sobresale SALIENTE de la zona
-- por cada lado. Devuelve su centro y su tamaño.
local SALIENTE = 2 -- lo que más sobresale un tablero de su zona (la mesa del comedor, 1,96 por las puntas)
local function cajaTablero(zona: BasePart): (CFrame, Vector3)
	local medio = zona.Size / 2
	local cf = zona.CFrame * CFrame.new(0, medio.Y + 0.4, 0)
	local tam = Vector3.new(zona.Size.X + 2 * SALIENTE, 0.8, zona.Size.Z + 2 * SALIENTE)
	local mueble = zona.Parent
	local medida = if mueble and mueble:IsA("Model") then mueble:GetAttribute("Tam") else nil
	if mueble and typeof(medida) == "Vector3" then
		local pivote = (mueble :: Model):GetPivot()
		local z = pivote:PointToObjectSpace(zona.Position)
		if math.abs(pivote.XVector:Dot(zona.CFrame.XVector)) > 0.99 and math.abs(pivote.YVector:Dot(Vector3.yAxis)) > 0.99
			and math.abs(z.X) + medio.X <= medida.X / 2 + 0.05 and math.abs(z.Z) + medio.Z <= medida.Z / 2 + 0.05
			and math.abs(z.Y - medio.Y) < 0.1 and medida.Y > zona.Size.Y
		then
			cf = pivote * CFrame.new(0, (zona.Size.Y + medida.Y) / 2, 0)
			tam = Vector3.new(medida.X, medida.Y - zona.Size.Y, medida.Z)
		end
	end
	return cf, tam
end

-- El tablero que tapa al escondido en `punto` (el de la zona Debajo en la que está), o nil.
local function tablero(punto: Vector3): (CFrame?, Vector3?, BasePart?)
	for _, zona in CollectionService:GetTagged("Debajo") do
		if not zona:IsA("BasePart") then
			continue
		end
		local medio = zona.Size / 2
		local p = zona.CFrame:PointToObjectSpace(punto)
		if math.abs(p.X) > medio.X + 0.5 or math.abs(p.Z) > medio.Z + 0.5 or p.Y < -medio.Y - 1 or p.Y > medio.Y + 3 then
			continue
		end
		local cf, tam = cajaTablero(zona)
		return cf, tam, zona
	end
	return nil, nil, nil
end

-- Las patas (y travesaños) del mueble de la zona: las cajas de choque de Mapa (HUECOS) que caen bajo su tablero, por
-- debajo de él. No se ven con rayos (CanQuery false): se buscan entre las piezas de la casa, una vez por gateo.
local function patasDe(zona: BasePart, encima: CFrame, tam: Vector3): Patas?
	local mueble = zona.Parent
	local casa = mueble and mueble.Parent
	if not casa then
		return nil
	end
	local abajo = zona.CFrame:PointToWorldSpace(Vector3.new(0, zona.Size.Y / 2, 0)).Y
	local patas: Patas = {}
	for _, pieza in casa:GetChildren() do
		if pieza.Name == "Choque" and pieza:IsA("BasePart") then
			local p = encima:PointToObjectSpace(pieza.Position)
			local arriba = pieza.Position.Y + pieza.Size.Y / 2 -- (de pie: sin girar)
			if math.abs(p.X) < tam.X / 2 and math.abs(p.Z) < tam.Z / 2 and arriba <= abajo + 0.1 then
				table.insert(patas, { cf = pieza.CFrame, medio = pieza.Size / 2 })
			end
		end
	end
	return patas
end

-- Studs (por el suelo, de la raíz hacia `punto`) hasta el borde del tablero que tapa al escondido, en el centro y a los
-- lados (si llega en diagonal, el borde le queda antes a un hombro): el de su zona Debajo y, si no está en ninguna, con
-- rayos hacia arriba cada poco (lo que quede más bajo que un escondite, como el asiento de una silla, no cuenta). Sin
-- tablero, GATEO.Borde antes de ti. (Antes solo con rayos: en el juego no daban nunca en la mesa y se metía por ella.)
local function buscarBorde(b: Bicho, punto: Vector3, boca: number): (number, Patas?, number)
	local raiz = b.raiz.Position
	local plano = Vector3.new(punto.X - raiz.X, 0, punto.Z - raiz.Z)
	local largo = plano.Magnitude
	if largo < 0.5 then
		return 0, nil, math.huge
	end
	local hacia = plano.Unit
	local lado = Vector3.new(-hacia.Z, 0, hacia.X)
	local cf, tam, zona = tablero(punto)
	if cf and tam and zona then
		-- Por donde entra cada raya (paralelas, por el suelo) en la caja del tablero.
		local medio = tam / 2
		local d = cf:VectorToObjectSpace(hacia)
		local borde = largo
		for _, x in { 0, -1.6, 1.6 } do -- (el torso, más ancho que la cabeza, tocaba el tablero entrando en diagonal)
			local o = cf:PointToObjectSpace(raiz + lado * x)
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
		local patas = patasDe(zona, cf, tam)
		-- Lo que la cabeza puede meterse: hasta la primera pata o travesaño que tenga delante a su altura (la viga baja de
		-- la mesa de la cocina), con la anchura de la cabeza a cada lado.
		local fondo = math.huge
		local suelo = raiz.Y - ALTURA
		for _, pata in patas or {} do
			local abajo, arriba = pata.cf.Position.Y - pata.medio.Y - suelo, pata.cf.Position.Y + pata.medio.Y - suelo
			if arriba < CABEZA_FONDO.Bajo or abajo > CABEZA_FONDO.Alto then
				continue
			end
			local corre = lado * boca * (CABEZA_FONDO.Boca - CABEZA_FONDO.Ancho) / 2
			local o = pata.cf:PointToObjectSpace(Vector3.new(raiz.X, pata.cf.Position.Y, raiz.Z) + corre)
			local dl = pata.cf:VectorToObjectSpace(hacia)
			local entra, sale = -math.huge, math.huge
			for _, eje in { "X", "Z" } do
				local oe, de = (o :: any)[eje], (dl :: any)[eje]
				local me = (pata.medio :: any)[eje] + (CABEZA_FONDO.Boca + CABEZA_FONDO.Ancho) / 2
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
				fondo = math.min(fondo, math.max(0, entra))
			end
		end
		return math.max(0, borde - BORDE_HOLGURA), patas, fondo
	end
	local fuera: { Instance } = {}
	local carpeta = workspace:FindFirstChild("Bichos")
	if carpeta then
		table.insert(fuera, carpeta)
	end
	for _, otro in Players:GetPlayers() do
		if otro.Character then
			table.insert(fuera, otro.Character)
		end
	end
	filtroGateo.FilterDescendantsInstances = fuera
	local suelo = raiz.Y - ALTURA
	local d = 0.3
	while d < largo do
		for _, x in { 0, -1.2, 1.2 } do
			local base = Vector3.new(raiz.X, suelo + 0.4, raiz.Z) + hacia * d + lado * x
			local choque = workspace:Raycast(base, Vector3.new(0, 4.5, 0), filtroGateo)
			if choque and choque.Instance.Name ~= "Debajo" and choque.Position.Y - suelo > 2.3 then
				return math.max(0, d - 0.2), nil, math.huge
			end
		end
		d += 0.3
	end
	return math.max(0, largo - GATEO.Borde), nil, math.huge
end

-- Por dónde va el gateo a los `t` s: cuánto ha metido la cabeza (0..1), cuánto olfatea (0..1, entre tirones) y el
-- empujón de cada tirón (0..1). Simple (Rendimiento): seguido, sin olfatear.
local function avanceGateo(t: number, simple: boolean): (number, number, number)
	local u = t * 2 / duraGateo() -- GATEO.Tirones va en segundos de un gateo de 2 s
	if simple then
		return suave(math.clamp((u - GATEO.Cae) / (1.75 - GATEO.Cae), 0, 1)), 0, 0
	end
	local a = 0
	for _, tiron in GATEO.Tirones do
		if u >= tiron[2] then
			a = tiron[3]
		elseif u > tiron[1] then
			local k = (u - tiron[1]) / (tiron[2] - tiron[1])
			-- (suave al empezar: con un arranque seco, la punta de las garras saltaba ~3 studs en un fotograma)
			return a + (tiron[3] - a) * suave(k), 0, math.sin(math.pi * k)
		else
			break
		end
	end
	return a, if u > GATEO.Cae then 1 else 0, 0
end

-- Los ruidos del gateo: 1 se echa al suelo; 2 y 3, cada tirón; 4, el último, con un gruñido grave que se corta.
local function ruidoGateo(b: Bicho, n: number)
	local donde = b.cabeza.Position
	if n == 1 then
		Sonido.en("Paso", donde - Vector3.new(0, 0.8, 0), 0.45)
		Sonido.en("Cruje", donde, 0.8)
		return
	end
	Sonido.en("Paso", donde, 0.6)
	if n == 4 then
		local corto = Sonido.en("Rugido", donde, 0.5)
		task.delay(0.4, function()
			if corto.Parent then
				corto:Stop()
			end
		end)
	else
		Sonido.en("Cruje", donde, 0.9)
	end
end

-- Lo alto de los hombros (en el marco del gateo: su Y es la altura sobre el suelo).
local function hombroAlto(m: { [string]: Motor6D }, torso: CFrame): number
	return (torso * m.BrazoD.C0.Position).Y
end

-- Si un punto (en el mundo) no está dentro de una pata del mueble (con algo de holgura: lo gordo del brazo).
local function puntoLibre(patas: Patas, p: Vector3): boolean
	for _, pata in patas do
		local q = pata.cf:PointToObjectSpace(p)
		local m = pata.medio
		if math.abs(q.X) < m.X + BRAZO.Holgura and math.abs(q.Y) < m.Y + BRAZO.Holgura and math.abs(q.Z) < m.Z + BRAZO.Holgura then
			return false
		end
	end
	return true
end

-- Si el brazo entero (del hombro a la punta de las garras, en `dir`; en el marco `enMundo`) está libre de las patas.
local function brazoLibre(patas: Patas, enMundo: CFrame, hombro: Vector3, dir: Vector3): boolean
	local d = 0.4
	while d <= -GARRAS.Y do
		if not puntoLibre(patas, enMundo * (hombro + dir * d)) then
			return false
		end
		d += 0.4
	end
	return true
end

-- El tablero con hueco más cercano a la raíz (a menos de APARTA.Cerca studs, en planta), mirado cada APARTA.Cada s.
local function mesaCerca(b: Bicho, ahora: number)
	if ahora < b.mesaHasta then
		return
	end
	b.mesaHasta = ahora + APARTA.Cada
	b.mesa = nil
	local raiz = b.raiz.Position
	local mejor = APARTA.Cerca
	for _, zona in CollectionService:GetTagged("Debajo") do
		if zona:IsA("BasePart") and (zona.Position - raiz).Magnitude < APARTA.Cerca + 12 then
			local cf, tam = cajaTablero(zona)
			local q = cf:PointToObjectSpace(raiz)
			local fuera = Vector3.new(math.max(0, math.abs(q.X) - tam.X / 2), 0, math.max(0, math.abs(q.Z) - tam.Z / 2)).Magnitude
			if fuera < mejor then
				mejor = fuera
				b.mesa = { cf = cf, tam = tam }
			end
		end
	end
end

-- Con los brazos ya puestos este fotograma (de pie, echándose, gateando o levantándose): si alguno atraviesa el tablero
-- de la mesa de al lado, lo echa hacia atrás desde el hombro (hacia fuera de la mesa) lo justo para que no. De pie, tan
-- largos y colgando por delante, se metían hasta 1,7 studs en él (comprobado con Lune). Sube deprisa y baja despacio.
local function apartarBrazos(b: Bicho, dt: number, aparta: { number })
	local mesa = b.mesa
	local m = b.motores
	local torso = m.Torso.C0 * m.Torso.Transform * m.Torso.C1:Inverse() -- en el espacio de la raíz
	local caja, medio, eje = nil, nil, nil
	if mesa then
		local c = b.raiz.CFrame:ToObjectSpace(mesa.cf)
		local mm = mesa.tam / 2 + Vector3.one * APARTA.Holgura
		-- Hacia fuera de la mesa (en planta): de su punto más cercano a la raíz.
		local q = c:PointToObjectSpace(Vector3.zero)
		local n = c:VectorToWorldSpace(q - Vector3.new(math.clamp(q.X, -mm.X, mm.X), q.Y, math.clamp(q.Z, -mm.Z, mm.Z)))
		n = Vector3.new(n.X, 0, n.Z)
		if n.Magnitude > 0.05 then
			caja, medio, eje = c, mm, n.Unit:Cross(Vector3.yAxis)
		end
	end
	for i, lado in LADOS do
		local motor = m[if lado < 0 then "BrazoI" else "BrazoD"]
		local hombro = torso * motor.C0.Position
		local parte = torso * motor.C0 * motor.Transform * motor.C1:Inverse()
		local meta = 0
		if caja and medio and eje then
			local desde, largo = motor.C1.Position, GARRAS
			-- El suelo también cuenta (echado, girar el brazo así lo hundía en él), salvo si ya estaba dentro sin girar.
			local suelo = -math.huge
			if (parte * (desde + largo)).Y > -ALTURA + 0.1 then
				suelo = -ALTURA + 0.05
			end
			local function choca(angulo: number): boolean
				local giro = CFrame.new(hombro) * CFrame.fromAxisAngle(eje, angulo) * CFrame.new(-hombro) * parte
				for k = 0, 1, 0.06 do
					local p = giro * (desde + largo * k)
					local q = caja:PointToObjectSpace(p)
					if p.Y < suelo or math.abs(q.X) < medio.X and math.abs(q.Y) < medio.Y and math.abs(q.Z) < medio.Z then
						return true
					end
				end
				return false
			end
			if choca(aparta[i]) or (aparta[i] > 0 and choca(0)) then
				-- Lo justo: el primer ángulo que no choca y, afinado, su canto (si ninguno vale, se queda como estaba).
				meta = aparta[i]
				for j = 1, 10 do
					local probar = APARTA.Max * j / 10
					if not choca(probar) then
						local lo, hi = APARTA.Max * (j - 1) / 10, probar
						for _ = 1, 5 do
							local mitad = (lo + hi) / 2
							if choca(mitad) then
								lo = mitad
							else
								hi = mitad
							end
						end
						meta = hi
						break
					end
				end
			end
		end
		local antes = aparta[i]
		aparta[i] = if meta > antes then math.min(meta, antes + dt * APARTA.Sube) else math.max(meta, antes - dt * APARTA.Baja)
		if aparta[i] > 1e-3 and eje then
			local giro = CFrame.new(hombro) * CFrame.fromAxisAngle(eje, aparta[i]) * CFrame.new(-hombro) * parte
			motor.Transform = motor.C0:Inverse() * torso:Inverse() * giro * motor.C1
		end
	end
end

-- El gateo: con Gatea y GateaHora en el modelo, se echa al suelo y mete la cabeza y un brazo por debajo del mueble,
-- encima de la postura de siempre (que ya está en las juntas este fotograma); sin ellos, saca la cabeza y se levanta.
-- La cara sigue un camino: baja por fuera del borde y solo entra por debajo cuando está abajo (si no, al doblarse, la
-- cabeza y los brazos barrían el tablero). El torso sale de ella, doblándose poco a poco desde la cadera.
local function gatear(b: Bicho, dt: number, ahora: number, poco: boolean, bocaBase: number)
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
			for _, en in { GATEO.Cae, GATEO.Tirones[1][1], GATEO.Tirones[2][1], GATEO.Tirones[3][1] } do
				if t * 2 / dura > en + 0.15 then
					sonados += 1
				end
			end
			-- La cabeza se ladea hacia el lado del brazo que mete: hacia donde no haya una pata cerca, si la hay.
			local brazo = if azar:NextNumber() < 0.5 then -1 else 1
			local borde, patas, fondo = buscarBorde(b, punto, brazo)
			local _, _, otro = buscarBorde(b, punto, -brazo)
			if otro > fondo + 0.05 then
				brazo, fondo = -brazo, otro
			end
			g = {
				hora = hora, punto = punto, borde = borde, t = t, sonados = sonados,
				brazo = brazo, cara0 = b.cabeza.Position, sale = 0, espera = 0,
				patas = patas, fondo = fondo, barre = 0, rumbo = {},
			}
			b.gatea = g
		end
		local actual = g :: Gateo
		actual.punto = punto
		actual.t = math.clamp(workspace:GetServerTimeNow() - hora, 0, dura)
		actual.sale = 0
		actual.espera = 0
	end
	if not g then
		return
	end
	-- Gateando (o mientras dura el susto si te ha pillado) se echa; al acabar, saca la cabeza y luego se levanta.
	if activo or ahora - b.agarra < GATEO.Susto then
		b.gateo = math.min(1, b.gateo + dt / GATEO.Cae)
	else
		g.sale = math.min(1, g.sale + dt / GATEO.Sale)
		if g.sale >= 1 then
			-- Antes de levantarse, el brazo que metía vuelve a apoyarse a su lado: si no, al subir los hombros lo metían en
			-- el tablero (comprobado con Lune). Como mucho GATEO.Recoge s.
			local r = g.rumbo[g.brazo]
			g.espera += dt
			if g.barre < 0.02 and (r == nil or math.abs(r - g.brazo * BRAZO.Apoyo) < 0.15) or g.espera > GATEO.Recoge then
				b.gateo = math.max(0, b.gateo - dt / GATEO.Levanta)
			end
		end
	end
	if b.gateo <= 0 then
		b.gatea = nil
		return
	end
	local m = b.motores
	local w = b.gateo
	local entra = suave(math.min(1, w * 4)) -- lo que manda el gateo sobre la postura de siempre
	local a, olfatea, empuje = avanceGateo(g.t, poco)
	local queda = 1 - suave(g.sale)
	a *= queda
	local husmea = if poco then 0 else olfatea * queda
	empuje *= queda

	-- El marco: en el suelo bajo la raíz, mirando hacia el escondido. Todo lo de abajo va en él.
	local enRaiz = b.raiz.CFrame:PointToObjectSpace(g.punto)
	local plano = Vector3.new(enRaiz.X, 0, enRaiz.Z)
	local lejos = math.max(plano.Magnitude, 0.5)
	local marco = CFrame.new(0, -ALTURA, 0) * CFrame.Angles(0, math.atan2(-plano.X, -plano.Z), 0)
	local tuAlto = math.clamp(enRaiz.Y + ALTURA, 0.6, 2)

	-- La cara: baja (pesado: cada vez más deprisa) por fuera del borde; abajo entra a tirones hasta quedarse a
	-- GATEO.Hasta de ti, sin pasar de GATEO.Dentro por debajo del tablero.
	local cara0 = (b.raiz.CFrame * marco):PointToObjectSpace(g.cara0)
	local alto = cara0.Y + (GATEO.Cara - cara0.Y) * w * w + husmea * 0.05 * math.sin(ahora * 26)
	-- (Con tope: con una pata justo delante salía menos que el de `fuera` y math.clamp daba error.)
	local final = math.max(-0.5, math.min(lejos - GATEO.Hasta, g.borde + GATEO.Dentro, g.fondo - CABEZA_FONDO.Delante))
	-- (Echándose y levantándose, la cara más lejos del borde: de lado, la mandíbula rozaba el tablero al subir.)
	local fuera = math.clamp(g.borde - GATEO.Fuera - (1 - w) * GATEO.Aparta, -0.5, final)
	local hasta = fuera + (final - fuera) * a * math.clamp((GATEO.Bajo - alto) / 0.6, 0, 1)
	local hz = suave(math.min(1, w * 2.5))
	local centro = Vector3.new(cara0.X * (1 - hz), alto, cara0.Z + (-hasta - cara0.Z) * hz)
	local giroCara = mirarCara(Vector3.new(0, tuAlto, -lejos) - centro,
		(g.brazo * GATEO.Ladeo + husmea * 0.12 * math.sin(ahora * 11)) * suave(w))
	local cuello = centro - giroCara * CABEZA_CENTRO

	-- El torso, doblándose desde la cadera: de un poco echado hacia delante a la cadera arriba y los hombros abajo.
	local fi = 0.4 + (math.pi / 2 + GATEO.Inclina - 0.4) * suave(w)
	local giroT = CFrame.fromMatrix(Vector3.zero, Vector3.xAxis, Vector3.new(0, math.cos(fi), -math.sin(fi)))
	local torsoC = CFrame.new(cuello - giroT * m.Cabeza.C0.Position) * giroT
	m.Torso.Transform = m.Torso.Transform:Lerp(m.Torso.C0:Inverse() * (marco * torsoC) * m.Torso.C1, entra)
	m.Cabeza.Transform = m.Cabeza.Transform:Lerp((torsoC * m.Cabeza.C0):Inverse() * (CFrame.new(cuello) * giroCara), entra)

	-- Brazos y piernas, desde el torso que tiene de verdad este fotograma: así las garras y los pies nunca se meten en el
	-- suelo. Un brazo apoyado a su lado, por fuera del mueble; el otro igual hasta que los hombros están abajo, y entonces
	-- barre por debajo hacia ti, a tirones, arañando el suelo (es tan largo que pasa a tu lado).
	local torso = marco:Inverse() * m.Torso.C0 * m.Torso.Transform * m.Torso.C1:Inverse()
	local enMundo = b.raiz.CFrame * marco
	-- Sin ir más deprisa que esto: al llegar tarde (ya metido) el brazo giraba 100° en dos fotogramas.
	local barre = math.clamp(1.15 * a * (1 - suave(math.clamp((hombroAlto(m, torso) - 1.6) / 0.8, 0, 1))), 0, 1)
	g.barre = if barre > g.barre then math.min(barre, g.barre + dt * BRAZO.Barre) else math.max(barre, g.barre - dt * BRAZO.Barre)
	for _, lado in LADOS do
		local motor = m[if lado < 0 then "BrazoI" else "BrazoD"]
		local hombro = torso * motor.C0.Position
		local cae = math.clamp((hombro.Y - 0.12 + GARRAS.Z) / -GARRAS.Y, -0.95, 0.95) -- la punta de las garras a ras de suelo
		-- Los giros, como rumbos por el suelo (0 hacia ti, + hacia su derecha) que pasan siempre por su lado de fuera: con
		-- Lerp de vectores casi opuestos, a medio camino el brazo daba la vuelta de golpe.
		local apoyo = lado * BRAZO.Apoyo
		local rumbo = apoyo
		if lado == g.brazo then
			local junto = Vector3.new(lado * 0.9 - hombro.X, 0, -lejos - hombro.Z)
			local haciaTi = if junto.Magnitude > 0.1 then math.atan2(junto.X, -junto.Z) else 0
			rumbo = apoyo + (haciaTi - apoyo) * g.barre
			if not poco then
				rumbo -= empuje * 0.08 * math.sin(ahora * 31)
			end
		end
		-- Sin atravesar las patas del mueble: va hacia donde querría sin pasar por dentro de ninguna (si una se pone en
		-- medio, se queda en su canto), y si el cuerpo al moverse se la mete dentro, se aparta hacia atrás (hasta
		-- BRAZO.Atras) lo justo. Siempre girando poco a poco: sin saltos.
		local patas = g.patas
		if patas and #patas > 0 then
			local function libre(r: number): boolean
				local dir = Vector3.new(math.sin(r), 0, -math.cos(r))
				return brazoLibre(patas, enMundo, hombro, dir * math.sqrt(1 - cae * cae) - Vector3.yAxis * cae)
			end
			local actual = g.rumbo[lado] or rumbo
			local paso = dt * BRAZO.Giro
			local siguiente = actual + math.clamp(rumbo - actual, -paso, paso)
			if libre(siguiente) then
				actual = siguiente
			elseif not libre(actual) then
				local atras = lado * BRAZO.Atras
				local hallado = atras
				for i = 1, 12 do
					local probar = actual + (atras - actual) * i / 12
					if libre(probar) then
						-- Afinado entre el último que no cabía y este: justo en el canto.
						local lo, hi = actual + (atras - actual) * (i - 1) / 12, probar
						for _ = 1, 4 do
							local medio = (lo + hi) / 2
							if libre(medio) then
								hi = medio
							else
								lo = medio
							end
						end
						hallado = hi
						break
					end
				end
				actual = hallado
			end
			g.rumbo[lado] = actual
			rumbo = actual
		end
		local hacia = Vector3.new(math.sin(rumbo), 0, -math.cos(rumbo))
		local parte = CFrame.new(hombro) * orientar(hacia * math.sqrt(1 - cae * cae) - Vector3.yAxis * cae, -Vector3.yAxis)
			* CFrame.new(-motor.C1.Position)
		motor.Transform = motor.Transform:Lerp(motor.C0:Inverse() * torso:Inverse() * parte * motor.C1, math.min(1, w * 2.5))
	end
	local cadera = torso * m.Torso.C1.Position
	for _, lado in LADOS do
		local motor = m[if lado < 0 then "PiernaI" else "PiernaD"]
		local junta = cadera + torso.XVector * motor.C0.Position.X - Vector3.new(0, 0.1, 0)
		-- El pie en el suelo (la pierna es gruesa: su eje acaba un poco más arriba), la pierna echada hacia atrás.
		local cae = math.clamp((junta.Y - 0.3) / PIERNA, 0, 1)
		local hacia = Vector3.new(lado * 0.3, 0, 0.95).Unit * math.sqrt(1 - cae * cae) - Vector3.yAxis * cae
		local parte = CFrame.new(junta) * orientar(hacia, -Vector3.zAxis) * CFrame.new(-motor.C1.Position)
		motor.Transform = motor.Transform:Lerp(motor.C0:Inverse() * (marco * parte) * motor.C1, math.min(1, w * 2))
	end
	-- La boca, abriéndose según se acerca (de lado); olfateando, a golpecitos. Nunca contra el suelo: con la cabeza tan
	-- baja, abierta del todo (al rugir) la barbilla y la sangre se metían ~0,4 en él (comprobado con Lune).
	local abre = bocaBase + (0.2 + 0.35 * a + husmea * 0.08 * math.abs(math.sin(ahora * 13))) * w
	local cabezaM = marco:Inverse() * m.Torso.C0 * m.Torso.Transform * m.Torso.C1:Inverse() * m.Cabeza.C0 * m.Cabeza.Transform
		* m.Cabeza.C1:Inverse() * m.Mandibula.C0
	local function barbilla(angulo: number): number
		local mand = cabezaM * CFrame.Angles(-angulo, 0, 0) * m.Mandibula.C1:Inverse()
		local bajo = math.huge
		for _, esquina in BARBILLA do
			bajo = math.min(bajo, (mand * esquina).Y)
		end
		return bajo
	end
	if barbilla(abre) < 0.05 then
		local lo, hi = 0, abre
		for _ = 1, 8 do
			local medio = (lo + hi) / 2
			if barbilla(medio) < 0.05 then
				hi = medio
			else
				lo = medio
			end
		end
		abre = lo
	end
	m.Mandibula.Transform = CFrame.Angles(-abre, 0, 0)

	-- Los ruidos, cada uno una vez (con Rendimiento, solo al echarse y el gruñido del final).
	local u = g.t * 2 / dura
	local eventos = { GATEO.Cae, GATEO.Tirones[1][1], GATEO.Tirones[2][1], GATEO.Tirones[3][1] }
	if activo and g.sonados < #eventos and u >= eventos[g.sonados + 1] then
		g.sonados += 1
		if not poco or g.sonados == 1 or g.sonados == #eventos then
			ruidoGateo(b, g.sonados)
		end
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
	local mirilla = jugador:GetAttribute("Mirilla") == true
	for modelo, b in bichos do
		if not modelo.Parent or not b.raiz.Parent then
			bichos[modelo] = nil
			continue
		end
		local distancia = (b.raiz.Position - ojo).Magnitude
		if distancia > LEJOS then
			continue
		end
		local m = b.motores
		local v = b.raiz.AssemblyLinearVelocity
		local rapidez = Vector3.new(v.X, 0, v.Z).Magnitude
		local paso = math.min(1, rapidez / 9)
		b.fase += dt * rapidez * 0.42
		local s = math.sin(b.fase)
		local rugiendo = ahora - b.rugido < 4
		local gateando = b.gateo > 0 or modelo:GetAttribute("Gatea") ~= nil -- mientras gatea, la vida de espera se pausa
		b.vida = acercar(b.vida, if rapidez < QUIETO and not rugiendo and not gateando and distancia < vidaLejos then 1 else 0, dt, 3)
		local vida = b.vida

		-- El golpe y lo que hace el cuerpo con él.
		local p, rebote = avanceGolpe(b, ahora)
		b.avance = p
		local inclina, cabezaGolpe, bocaGolpe = cuerpoGolpe(p)
		local enGolpe = math.sin(math.pi * math.clamp(p / 5, 0, 1)) -- 0 en reposo, 1 a mitad del golpe
		local tg = ahora - b.golpe
		local rabia = if tg >= GOLPE.Fin and tg < GOLPE.Espera + 0.6 then p / GOLPE.Prepara else 0
		-- Mientras golpea, el torso y los brazos sin vaivén ni sacudidas (le metían las garras en la pared); si está más
		-- cerca de la ventana que de costumbre, los brazos un poco más atrás.
		local libre = 1 - math.clamp(math.min(tg / 0.12, (GOLPE.Fin + 0.3 - tg) / 0.3), 0, 1)
		local atras = 0
		local ventana = b.ventana
		if ventana and libre < 1 then
			atras = math.clamp((FUERA - (b.raiz.Position - ventana.Position):Dot(ventana.LookVector)) / ALCANCE, 0, 0.5) * (1 - libre)
		end

		-- Respira fuerte: jadea justo después de cada golpe y se va calmando.
		local calma = math.clamp((tg - 1) / 4, 0, 1)
		b.respira += dt * 2 * math.pi / (RESPIRA[1] + (RESPIRA[2] - RESPIRA[1]) * calma)
		local aire = math.sin(b.respira) -- más: coge aire; menos: lo suelta
		local soltando = math.cos(b.respira) < 0
		if soltando and not b.exhala and noche and not poco and vida > 0.5 and distancia < VAHO_LEJOS then
			local boca = b.cabeza.CFrame * BOCA
			if not dentroDeCasa(boca.Position) then
				echarVaho(boca)
			end
		end
		b.exhala = soltando

		-- El peso de un pie a otro, las crispaciones y alguna sacudida rara.
		b.peso += dt * 2 * math.pi / PESO
		local w = math.sin(b.peso) * vida
		if vida > 0.5 and ahora >= b.proximaCrispa then
			b.proximaCrispa = ahora + rango(CRISPA)
			b.crispa[azar:NextInteger(1, 2)] = ahora
		end
		if vida > 0.8 and ahora >= b.proximaSacudida then
			b.proximaSacudida = ahora + rango(SACUDIDA)
			b.sacudida = ahora
		end
		-- Con tope: sin él, antes de la primera sacudida daba math.sin(inf) = NaN, y 0 · NaN = NaN rompía las juntas.
		local ts = math.min(ahora - b.sacudida, DURA_SACUDIDA)
		local sac = if ts < DURA_SACUDIDA then (1 - ts / DURA_SACUDIDA) ^ 2 * vida else 0

		-- La cabeza: a tirones; si le miras por la mirilla, se te queda mirando.
		if mirilla and (b.cabeza.Position - ojo).Magnitude < MIRILLA then
			b.teVe = b.teVe or ahora + MIRILLA_REACCION
		else
			b.teVe = nil
		end
		local teMira = b.teVe ~= nil and ahora >= (b.teVe :: number)
		if vida > 0.05 then
			if teMira then
				local cabeceo, giro = mirada(b, ojo)
				b.mira = nil
				b.meta = Vector3.new(cabeceo, giro, 0.55)
			elseif ahora >= b.tiron then
				decidirTiron(b, ahora)
			end
			local suya = b.mira
			if suya and not teMira then
				if suya.Parent then
					local cabeceo, giro = mirada(b, suya.Position)
					b.meta = Vector3.new(cabeceo, giro, b.meta.Z)
				else
					b.mira = nil
				end
			end
			b.cab = b.cab:Lerp(b.meta, math.min(1, dt * (if teMira then 9 else 16)))
		end
		local andando = Vector3.new(0.15 * math.sin(ahora * 0.5), 0, LADEO + 0.12 * math.sin(ahora * 0.7))
		local viva = b.cab
			+ Vector3.new(0.03 * aire + sac * 0.15 * math.sin(ts * 23), sac * 0.3 * math.sin(ts * 17), sac * 0.5 * math.sin(ts * 28))
		local h = andando:Lerp(viva, vida * (1 - 0.7 * enGolpe))
		m.Cabeza.Transform = CFrame.fromEulerAnglesYXZ(h.X + cabezaGolpe, h.Y, h.Z)

		-- Torso: el golpe, la respiración, el peso y el rugido.
		m.Torso.Transform = CFrame.new(0.14 * w, 0.07 * aire * vida, 0)
			* CFrame.Angles(
				inclina + 0.05 * rebote + (0.04 * aire + sac * 0.05 * math.sin(ts * 33)) * libre + (if rugiendo then 0.25 else 0),
				0,
				0.035 * w
			)

		-- Brazos: el golpe; andando se balancean; esperando, los hombros suben al coger aire y se crispan. Lo que falte
		-- para no tocar la pared (`atras`) los aparta de ella: hacia atrás si están arriba y hacia delante si cuelgan
		-- es girar al revés.
		local vaiven = math.sin(ahora * 1.3) * 0.06 * libre
		local delante, fuera = postura(p)
		delante -= atras * math.cos(fuera)
		for i, lado in LADOS do
			local cr = crispacion(ahora - b.crispa[i]) * vida
			local balanceo = lado * (s * 0.35 * paso - vaiven)
			local extra = balanceo + cr * 0.16 + 0.12 * rebote + sac * 0.12 * math.sin(ts * 41 + lado) * libre
				+ rabia * 0.035 * math.sin(ahora * 38 + lado)
			local hombros = 0.06 * aire * vida + cr * 0.14
			m[if lado < 0 then "BrazoI" else "BrazoD"].Transform = CFrame.new(0, hombros, 0)
				* CFrame.Angles(extra + delante, 0, lado * fuera) * CFrame.Angles(0, 0, lado * cr * 0.18)
		end

		-- Piernas: andando; quieto, el peso pasa de una a otra (la que descansa se dobla un poco).
		m.PiernaI.Transform = CFrame.Angles(s * 0.6 * paso + 0.07 * math.max(0, w), 0, -0.03 * w)
		m.PiernaD.Transform = CFrame.Angles(-s * 0.6 * paso + 0.07 * math.max(0, -w), 0, -0.03 * w)

		-- La boca, entreabierta; del todo al golpear y rugir; jadeando al soltar el aire; abriéndose si te mira.
		local abre = 0.25 + 0.08 * math.sin(ahora * 3) + bocaGolpe
			+ (if rugiendo then 0.6 + 0.1 * math.sin(ahora * 30) else 0)
			+ vida * (0.12 * math.max(0, -aire) + (if teMira then 0.25 else 0))
		m.Mandibula.Transform = CFrame.Angles(-abre, 0, 0)

		-- Sin atravesar el tablero de la mesa de al lado: la postura de pie (de la que sale y a la que vuelve al gatear) y,
		-- por si acaso, lo que quede después de gatear (al echarse y al levantarse, a medio camino entre las dos).
		mesaCerca(b, ahora)
		apartarBrazos(b, dt, b.aparta)

		-- Debajo de un mueble: se echa al suelo y gatea a por ti, encima de todo lo anterior.
		gatear(b, dt, ahora, poco, abre)
		if b.gatea then
			apartarBrazos(b, dt, b.aparta2)
		end

		-- Una pisada cada vez que el seno cambia de signo.
		local pie = if s >= 0 then 1 else -1
		if rapidez > 2 and pie ~= b.pisada then
			b.pisada = pie
			Sonido.en("Paso", b.raiz.Position - Vector3.new(0, 5, 0), 0.55)
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
	if not modelo:IsA("Model") or modelo.Name ~= "Golpeador" then
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
	local ahora = os.clock()
	bichos[modelo] = {
		modelo = modelo, raiz = raiz, cabeza = cabeza, motores = motores, fase = 0, pisada = 1,
		golpe = -math.huge, desde = 0, avance = 0, ventana = nil, rugido = -math.huge, vida = 0,
		respira = azar:NextNumber(0, 2 * math.pi), exhala = false, peso = azar:NextNumber(0, 2 * math.pi),
		cab = Vector3.new(-0.05, 0, LADEO), meta = Vector3.new(-0.05, 0, LADEO), mira = nil, tiron = ahora + 1, teVe = nil,
		crispa = { -math.huge, -math.huge }, proximaCrispa = ahora + rango(CRISPA),
		sacudida = -math.huge, proximaSacudida = ahora + rango(SACUDIDA),
		gateo = 0, gatea = nil, agarra = -math.huge, mesa = nil, mesaHasta = 0, aparta = { 0, 0 }, aparta2 = { 0, 0 },
	}
	encender()
end

local function cercano(punto: Vector3, maximo: number?): Bicho?
	local mejor, distancia = nil, maximo or math.huge
	for _, b in bichos do
		local d = (b.raiz.Position - punto).Magnitude
		if d < distancia then
			mejor, distancia = b, d
		end
	end
	return mejor
end

-- Abre la boca del todo unos segundos (el susto al morir; si gateaba, en el suelo). Devuelve el Golpeador cerca de
-- `punto`, si hay.
function GolpeadorVista.rugir(punto: Vector3): Model?
	local b = cercano(punto, 12)
	if b then
		b.rugido = os.clock()
		if b.gatea then
			b.agarra = os.clock() -- te ha pillado gateando: se queda en el suelo mientras dura el susto
		end
		return b.modelo
	end
	return nil
end

function GolpeadorVista.start()
	local carpeta = workspace:WaitForChild("Bichos")
	carpeta.ChildAdded:Connect(preparar)
	for _, modelo in carpeta:GetChildren() do
		task.spawn(preparar, modelo)
	end
	Remotes.Golpeador.OnClientEvent:Connect(function(tipo: string, el: Model)
		local centro = el and el:GetAttribute("Centro")
		if typeof(centro) ~= "CFrame" then
			return
		end
		local b = cercano(centro.Position, 12) -- el que golpea está a 4 studs
		if tipo == "Golpe" and b then
			-- Sigue desde donde tenga los brazos (preparándose); si aún volvían del anterior, desde el lado.
			b.desde = if b.avance <= 3 then b.avance else 1
			b.golpe = os.clock()
			b.ventana = centro
		elseif tipo == "Entra" then
			Sonido.en("Rugido", centro.Position)
			if b then
				b.rugido = os.clock() + 0.6 -- ruge al aparecer dentro
			end
		end
	end)
end

return GolpeadorVista
