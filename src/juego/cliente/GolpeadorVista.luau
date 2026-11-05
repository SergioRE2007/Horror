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
-- Aturdido por el flash (atributo Aturdido del modelo, Caza.aturdir): se echa atrás tapándose la cara y tiembla.
-- El susto al pillarte (rugir, 14.10: ver SUSTO) y los sucesos al azar por atributos del modelo (ver SUCESO): Armario,
-- Olfatea, Llama (remote Golpeador "Toque"), Cara, Aparta, Finge, Garras y Quieto. Sin atravesar sus paredes ni el
-- suelo (comprobado con Lune: tests/bancos/sucesos-golpeador.luau).
-- Con el modelo 3D (Bichos3D.vestir), los bloques son invisibles y la malla copia su postura cada fotograma (Malla3D).
-- Un solo bucle (Stepped) que solo corre mientras hay alguno; la vida, solo cerca de la cámara. Si el modelo se va
-- (StreamOut o lo quita el servidor) se olvida, y si vuelve se prepara otra vez.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Malla3D = require(script.Parent.Malla3D)
local MuebleRayo = require(script.Parent.MuebleRayo)
local Sonido = require(script.Parent.Sonido)

local GolpeadorVista = {}

-- Números visuales a ojo (se retocan en Studio).
local LEJOS = 250 -- studs de la cámara: más lejos no se le mueve nada...
local LEJOS_RENDIMIENTO = 120 -- ...o más lejos que esto con Rendimiento (a ojo)
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
-- Qué bloque sigue cada hueso de la malla 3D (Malla3D): la columna se dobla poco a poco con el torso, el cuello a medio
-- camino de la cabeza, la clavícula algo con el brazo y el pie casi plano. Los brazos de la malla, estirados (codo y
-- muñeca más lejos): sin estirar llegaban ~1,5 studs menos que los de bloques y el golpe no tocaba la pared; con 1,35
-- las puntas de los dedos casi asomaban por dentro (medido en Studio con la orden de prueba "Golpe").
local BRAZO_LARGO = 1.28
local MALLA: { [string]: Malla3D.Sigue } = {
	Hips = { a = "Torso", f = 0, desplaza = true },
	Spine = { a = "Torso", f = 0.4 },
	Spine1 = { a = "Torso", f = 0.7 },
	Spine2 = { a = "Torso" },
	Neck = { a = "Torso", b = "Cabeza", t = 0.5 },
	Head = { a = "Cabeza" },
	LeftShoulder = { a = "Torso", b = "BrazoI", t = 0.3 },
	LeftArm = { a = "BrazoI" },
	LeftForeArm = { a = "BrazoI", estira = BRAZO_LARGO },
	LeftHand = { a = "BrazoI", estira = BRAZO_LARGO },
	RightShoulder = { a = "Torso", b = "BrazoD", t = 0.3 },
	RightArm = { a = "BrazoD" },
	RightForeArm = { a = "BrazoD", estira = BRAZO_LARGO },
	RightHand = { a = "BrazoD", estira = BRAZO_LARGO },
	LeftUpLeg = { a = "PiernaI" },
	LeftLeg = { a = "PiernaI" },
	LeftFoot = { a = "PiernaI", f = 0.3 },
	RightUpLeg = { a = "PiernaD" },
	RightLeg = { a = "PiernaD" },
	RightFoot = { a = "PiernaD", f = 0.3 },
}
-- El centro de la cara de la malla en el hueso Head (su Y va hacia el hocico y su Z hacia arriba), medido en Studio.
local CARA: Malla3D.Cara = { bloque = "Cabeza", hueso = "Head", centro = Vector3.new(0, 0.8, -0.3) }
-- Las piernas de la malla (más largas que las de bloques) van con IK a la planta del pie de su bloque (4,2 de largo,
-- con la junta a 2 del centro: la planta a 2,1 por debajo).
local PIERNAS: { Malla3D.Pierna } = {
	{ muslo = "LeftUpLeg", rodilla = "LeftLeg", pie = "LeftFoot", bloque = "PiernaI", planta = Vector3.new(0, -2.1, 0) },
	{ muslo = "RightUpLeg", rodilla = "RightLeg", pie = "RightFoot", bloque = "PiernaD", planta = Vector3.new(0, -2.1, 0) },
}
-- Al gatear, la malla se mueve para que su cuello caiga en el de los bloques (torso más corto: si no, la cabeza se
-- quedaba a ~4 studs del suelo).
local CUELLO: Malla3D.Cuello = { hueso = "Neck", bloque = "Cabeza" }
-- Aturdido por el flash: cuánto se echa atrás el torso, la cabeza (cabeceo, giro, ladeo: apartándola de la luz), los
-- brazos (hacia delante, hacia dentro) con los codos doblados (solo la malla: los bloques no tienen codo) tapándose la
-- cara y la boca; tiembla `Tiembla` radianes, `Rapido` radianes por segundo.
local ATURDE = {
	Torso = 0.3,
	Cabeza = Vector3.new(-0.45, 0.7, 0.35),
	Brazo = { 1.3, 0.2 },
	Codo = 1.9, -- el antebrazo, hacia dentro por delante de la cara (giro sobre el eje Z del brazo)
	Boca = 0.9,
	Tiembla = 0.05,
	Rapido = 47,
}
-- Los huesos que se doblan con el codo y su lado (-1 izquierdo, 1 derecho).
local CODOS = { LeftForeArm = -1, LeftHand = -1, RightForeArm = 1, RightHand = 1 }
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
}
-- Cuándo suena cada ruido del gateo (en segundos de un gateo de 2 s): al echarse y al empezar cada tirón.
local EVENTOS = { GATEO.Cae, GATEO.Tirones[1][1], GATEO.Tirones[2][1], GATEO.Tirones[3][1] }
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
-- De pie, la punta de las garras al menos a esto del suelo (studs; su caja baja ~0,03 más), adelantando el brazo como
-- mucho estos radianes (garrasSobreSuelo).
local GARRAS_SUELO, GARRAS_ADELANTA = 0.06, 0.6
-- El codo de la malla (rig.dobla, en el eje X del brazo: hacia delante, como dobla de verdad): para llevar la punta de
-- las garras a un sitio (alcanzar). Los dedos no están en MALLA: de la muñeca a la punta del dedo corazón, ~1,75
-- (medido en el modelo de Tripo). Como mucho CODO_MAX radianes.
local DEDOS, CODO_MAX = 1.75, 2.5
-- El susto al pillarte (14.10, pedido por el usuario: "hay que mejorar el screamer"). Los tiempos, en
-- Config.Golpeador.Susto (los lee también MuerteVista, que lleva la cámara): si te pilló gateando, primero Arrastra (te
-- saca de debajo del mueble con el brazo que metía); luego Mira (quieto, mirándote), Salta (se abalanza: torso y
-- cabeza adelante, brazos abriéndose), Encima (boca abierta del todo, la cabeza a tirones y las garras entrando por
-- los lados de la pantalla) y Tiron (el último empujón). Se queda así hasta Espera y luego vuelve a lo suyo. A ojo.
local SUSTO = {
	Entra = 0.12, -- s en ponerse en la pose (de pie)
	Sale = 0.5, -- s en volver a lo suyo al acabar (de pie)
	Antes = 0.3, -- gateando, deja el suelo esto antes de Espera (ya en el fundido a negro): el banco del gateo le mira
	-- levantarse 5 s después de pillarte
	Boca = { Arrastra = 0.6, Mira = 0.4, Salta = 1, Encima = 1.25 }, -- radianes (Malla3D: ~1 son unos 60°)
	Tirones = { 0.06, 0.12 }, -- s entre dos tirones de la cabeza, encima de ti
	Tiron = Vector3.new(0.14, 0.42, 0.55), -- lo que da cada tirón como mucho (cabeceo, giro, ladeo)
	-- La punta de las garras en la cara (Cara3D: X a su derecha, -Z hacia delante; la cámara va a 2,6 en su -Z): de
	-- dónde entran, a dónde llegan (los lados de la pantalla) y a dónde se cierran en el tirón. X va por lados.
	GarrasDesde = Vector3.new(3.2, -0.8, 0.4),
	Garras = Vector3.new(1.05, -0.5, -1.6),
	GarrasTiron = Vector3.new(0.7, -0.35, -1.85),
	GarrasEntran = 0.2, -- s que tardan en entrar
	Levanta = 0.9, -- gateando, studs que levanta la cabeza del suelo tras sacarte
	Giro = 1.2, -- gateando, radianes que gira la cara como mucho hacia ti (fuera del mueble)
}
local FASES = { "Mira", "Salta", "Encima", "Tiron" }
-- Sucesos al azar (14.10, pedido por el usuario: "que no sea siempre igual"). Los decide el servidor (Caza) y los pone
-- en el modelo: Suceso (nombre), SucesoHora, SucesoDura, SucesoMira (Vector3) y SucesoLado (Garras). Cada uno es una
-- pose encima de la de siempre, que entra y sale suave (Sale y Entra: por segundo). Números a ojo.
local SUCESO = {
	Entra = 2.5,
	Sale = 1.8,
	Rapido = 14, -- Aparta: de golpe
	Despacio = 1.1, -- Finge: gira la cabeza despacio
	-- Agachado (Armario y Cara): la cadera baja hasta esto (en la raíz) y el torso cuelga del cuello.
	Cadera = -2.2,
	-- Armario: la cara a `Frente` studs de las rendijas, la cabeza ladeada `Ladeo`; respira cada `Respira` s; las manos
	-- en la pared a los lados del armario (`Manos`: a un lado y arriba de las rendijas).
	Armario = { Frente = 0.4, Ladeo = 0.55, Respira = 3.4, Manos = Vector2.new(2.3, 1.4) },
	-- Olfatea: golpes de nariz cada `Cada` s, en tandas de `Tanda`, con `Pausa` s entre tandas.
	Olfatea = { Cada = 0.34, Tanda = 3, Pausa = { 0.7, 1.1 }, Alza = 0.3 },
	-- Llama: SucesoMira es el centro de la ventana o puerta; el dedo toca `Alto` por encima, `Aparte` studs fuera del
	-- cristal entre toques. El toque i llega a (i - 0,5) · CadaToque s de SucesoHora (Caza): el dedo se acerca `Acerca`
	-- s antes y se retira en `Retira` s.
	Llama = { Alto = 0.6, Aparte = 0.45, Acerca = 0.3, Retira = 0.4 },
	-- Cara: la cara a `Alto` por encima del centro del cristal y a `Frente` de él; las manos a los lados (`Manos`).
	Cara = { Alto = 0.7, Frente = 0.3, Manos = Vector2.new(2.6, 0.9) },
	-- Garras: la punta de las garras a `Pared` de la pared (rayo), arrastrándose `Atras` por detrás del hombro y `Bajo`
	-- por debajo; rayos cada `Cada` s (con Rendimiento, `CadaPoco`), hasta `Largo` studs.
	Garras = { Pared = 0.12, Atras = 1.5, Bajo = 0.9, Cada = 0, CadaPoco = 0.15, Largo = 6 },
	-- Quieto: la cabeza se ladea a tirones de `Paso` radianes cada `Cada` s, crujiendo flojo (`Volumen`).
	Quieto = { Paso = 0.14, Cada = { 0.6, 1.2 }, Max = 1.15, Volumen = 0.3 },
}
-- Lo que sobresale la cara de la malla (Cara3D) del centro de la cabeza de bloques, en ella (sin malla, su frente).
local FRENTE_CARA = Vector3.new(0, 0.1, -0.75)

local jugador = Players.LocalPlayer
local azar = Random.new()
local filtroGateo = RaycastParams.new()
filtroGateo.FilterType = Enum.RaycastFilterType.Exclude
local filtroSuceso = RaycastParams.new()
filtroSuceso.FilterType = Enum.RaycastFilterType.Exclude

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
	levanta: number, -- 0..1: si te ha pillado, cuánto ha levantado la cabeza tras sacarte (y baja suave al acabar)
	mirada: Vector3?, -- ...y hacia dónde mira entonces (en el marco del gateo)
}

-- El susto al pillarte (rugir), mientras dura.
type Susto = {
	t0: number, -- os.clock de rugir
	gatea: boolean, -- te pilló gateando: primero te arrastra fuera y lo demás lo hace en el suelo
	mirar: Vector3, -- a dónde mira en Arrastra y Mira (la cámara: tu cabeza)
	dir: Vector3?, -- desde Salta, hacia dónde mira (en la raíz): fijo (la cámara va delante de su cara)
	fase: string, -- "Arrastra", "Mira", "Salta", "Encima", "Tiron" o "Fin"
	u: number, -- 0..1 dentro de la fase
	tir: Vector3, -- el tirón de la cabeza ahora (cabeceo, giro, ladeo)...
	meta: Vector3, -- ...y a dónde va
	proximo: number, -- os.clock del próximo tirón
	w: number, -- 0..1: cuánto manda la pose del susto (de pie)
}

-- Un suceso al azar (atributos del modelo), mientras entra, dura y sale.
type Suceso = {
	nombre: string,
	hora: number, -- SucesoHora (hora del servidor)
	mira: Vector3, -- SucesoMira
	lado: number, -- SucesoLado (Garras), o el brazo que usa (Llama)
	w: number, -- 0..1: cuánto manda (sin suavizar)
	activo: boolean, -- si el atributo Suceso sigue siendo este
	manos: { [number]: Vector3 }, -- Armario y Cara: dónde apoya cada mano (en el mundo, ya en la pared)
	proximo: number, -- Olfatea y Quieto: os.clock del próximo golpe de nariz o tirón
	golpe: number, -- Olfatea: os.clock del último golpe de nariz; Llama: del último toque (remote)
	tanda: number, -- Olfatea: golpes que quedan en la tanda
	ladeo: number, -- Quieto: el ladeo ahora...
	ladeoMeta: number, -- ...y a dónde va el tirón
	normal: Vector3?, -- Garras: la normal de la pared (mundo), hacia él
	punta: Vector3?, -- Garras: un punto de la pared (mundo, ya con su holgura), si hay pared y nada se cruza
	contacto: number, -- Garras: 0..1, suave: tocando la pared
	rayo: number, -- Garras: os.clock del último rayo
	sonido: Sound?, -- Garras: el arañazo en bucle
	punto: Attachment?, -- ...y dónde suena
}

-- Para alcanzar con la malla: el hueso del hombro y, en los ejes del bloque del brazo, del hombro al codo (A) y del codo a
-- la punta de los dedos (B).
type Codo = { hueso: number, A: Vector3, B: Vector3 }

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
	susto: Susto?, -- el susto al pillarte, mientras dura
	sucesos: { [string]: Suceso }, -- los sucesos que entran, duran o salen
	planos: { { p: Vector3, n: Vector3 } }, -- las paredes de los sucesos de este fotograma (en la raíz): noAtravesar
	agacha: number, -- 0..1: cuánto está agachado por un suceso (la malla se alinea como al gatear)
	offCara: Vector3, -- dónde cae la cara de la malla en la cabeza de bloques (lo mide cada fotograma, suave)
	codos: { [number]: Codo }?, -- para alcanzar con la malla (por brazo, -1 izquierdo, 1 derecho)
	codo: { [number]: number }, -- radianes del codo este fotograma (por brazo)
	mesa: { cf: CFrame, tam: Vector3 }?, -- el tablero con hueco más cercano (mesaCerca)
	mesaHasta: number, -- os.clock en que se vuelve a buscar
	aparta: { number }, -- radianes, suave: lo que se echa atrás cada brazo para no atravesarlo (1 izquierdo, 2 derecho)...
	aparta2: { number }, -- ...de pie y, encima, gateando
	aturde: number, -- 0..1, suave: aturdido por el flash
	rig: Malla3D.Rig?, -- la malla 3D, si la tiene
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

-- El tablero que tapa al escondido en `punto` (el de la zona Debajo en la que está), o nil. Las piezas de los muebles y
-- sus cajas de choque no se ven con rayos (CanQuery false): lo calcula MuebleRayo.tablero con el Tam del mueble.
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
		local cf, tam = MuebleRayo.tablero(zona)
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
local function buscarBorde(b: Bicho, punto: Vector3): (number, Patas?, { [number]: number })
	local raiz = b.raiz.Position
	local plano = Vector3.new(punto.X - raiz.X, 0, punto.Z - raiz.Z)
	local largo = plano.Magnitude
	if largo < 0.5 then
		return 0, nil, { [-1] = math.huge, [1] = math.huge }
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
		-- la mesa de la cocina), con la anchura de la cabeza a cada lado; según hacia qué lado la ladee (`boca`).
		local fondos = { [-1] = math.huge, [1] = math.huge }
		local suelo = raiz.Y - ALTURA
		for _, pata in patas or {} do
			local abajo, arriba = pata.cf.Position.Y - pata.medio.Y - suelo, pata.cf.Position.Y + pata.medio.Y - suelo
			if arriba < CABEZA_FONDO.Bajo or abajo > CABEZA_FONDO.Alto then
				continue
			end
			for _, boca in LADOS do
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
					fondos[boca] = math.min(fondos[boca], math.max(0, entra))
				end
			end
		end
		return math.max(0, borde - BORDE_HOLGURA), patas, fondos
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
				return math.max(0, d - 0.2), nil, { [-1] = math.huge, [1] = math.huge }
			end
		end
		d += 0.3
	end
	return math.max(0, largo - GATEO.Borde), nil, { [-1] = math.huge, [1] = math.huge }
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
			local cf, tam = MuebleRayo.tablero(zona)
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

-- Con los brazos de pie ya puestos este fotograma: si las garras de alguno bajan del suelo, lo adelanta desde el hombro
-- lo justo para que no. Esperando cerca, al soltar el aire con el peso de ese lado (el torso baja y se ladea, y los
-- hombros caen) la punta de los brazos, que cuelgan casi hasta el suelo, se metía ~0,18 en él (comprobado con Lune).
local function garrasSobreSuelo(b: Bicho)
	local m = b.motores
	local torso = m.Torso.C0 * m.Torso.Transform * m.Torso.C1:Inverse()
	for _, lado in LADOS do
		local motor = m[if lado < 0 then "BrazoI" else "BrazoD"]
		local base = torso * motor.C0
		local puntaEnBrazo = motor.C1.Position + GARRAS
		-- Altura de la punta de las garras sobre el suelo con el brazo adelantado `extra` radianes más desde el hombro.
		local function punta(extra: number): number
			return (base * CFrame.Angles(extra, 0, 0) * motor.Transform * motor.C1:Inverse() * puntaEnBrazo).Y + ALTURA
		end
		if punta(0) >= GARRAS_SUELO or punta(GARRAS_ADELANTA) <= punta(0) then
			continue
		end
		local lo, hi = 0, GARRAS_ADELANTA
		for _ = 1, 8 do
			local medio = (lo + hi) / 2
			if punta(medio) < GARRAS_SUELO then
				lo = medio
			else
				hi = medio
			end
		end
		motor.Transform = CFrame.Angles(hi, 0, 0) * motor.Transform
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
			for _, en in EVENTOS do
				if t * 2 / dura > en + 0.15 then
					sonados += 1
				end
			end
			-- La cabeza se ladea hacia el lado del brazo que mete: hacia donde no haya una pata cerca, si la hay.
			local brazo = if azar:NextNumber() < 0.5 then -1 else 1
			local borde, patas, fondos = buscarBorde(b, punto)
			if fondos[-brazo] > fondos[brazo] + 0.05 then
				brazo = -brazo
			end
			local fondo = fondos[brazo]
			g = {
				hora = hora, punto = punto, borde = borde, t = t, sonados = sonados,
				brazo = brazo, cara0 = b.cabeza.Position, sale = 0, espera = 0,
				patas = patas, fondo = fondo, barre = 0, rumbo = {}, levanta = 0, mirada = nil,
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
	local s = b.susto
	local pillado = s ~= nil and s.gatea
	if activo or pillado then
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
	-- Si te ha pillado (el susto): en Arrastra el brazo que metía tira de ti hacia él (vuelve a su lado) y la cabeza sale
	-- de debajo; luego la levanta un poco del suelo y la gira hacia ti (ya fuera del mueble) para lo demás del susto.
	local tirones = Vector3.zero
	if pillado and s then
		local c = Config.Golpeador.Susto
		local t = ahora - s.t0
		a *= 1 - suave(math.clamp(t / c.Arrastra, 0, 1))
		husmea, empuje = 0, 0
		g.levanta = suave(math.clamp((t - c.Arrastra) / 0.3, 0, 1))
		tirones = s.tir
	else
		g.levanta = math.max(0, g.levanta - dt / 0.35) -- al acabar baja suave (sin saltos)
	end
	local levanta = g.levanta

	-- El marco: en el suelo bajo la raíz, mirando hacia el escondido. Todo lo de abajo va en él.
	local enRaiz = b.raiz.CFrame:PointToObjectSpace(g.punto)
	local plano = Vector3.new(enRaiz.X, 0, enRaiz.Z)
	local lejos = math.max(plano.Magnitude, 0.5)
	local marco = CFrame.new(0, -ALTURA, 0) * CFrame.Angles(0, math.atan2(-plano.X, -plano.Z), 0)
	local tuAlto = math.clamp(enRaiz.Y + ALTURA, 0.6, 2)

	-- La cara: baja (pesado: cada vez más deprisa) por fuera del borde; abajo entra a tirones hasta quedarse a
	-- GATEO.Hasta de ti, sin pasar de GATEO.Dentro por debajo del tablero.
	local cara0 = (b.raiz.CFrame * marco):PointToObjectSpace(g.cara0)
	local alto = cara0.Y + (GATEO.Cara - cara0.Y) * w * w + husmea * 0.05 * math.sin(ahora * 26) + SUSTO.Levanta * levanta
	-- (Con tope: con una pata justo delante salía menos que el de `fuera` y math.clamp daba error.)
	local final = math.max(-0.5, math.min(lejos - GATEO.Hasta, g.borde + GATEO.Dentro, g.fondo - CABEZA_FONDO.Delante))
	-- (Echándose y levantándose, la cara más lejos del borde: de lado, la mandíbula rozaba el tablero al subir.)
	local fuera = math.clamp(g.borde - GATEO.Fuera - (1 - w) * GATEO.Aparta, -0.5, final)
	local hasta = fuera + (final - fuera) * a * math.clamp((GATEO.Bajo - alto) / 0.6, 0, 1)
	local hz = suave(math.min(1, w * 2.5))
	local centro = Vector3.new(cara0.X * (1 - hz), alto, cara0.Z + (-hasta - cara0.Z) * hz)
	local haciaCara = Vector3.new(0, tuAlto, -lejos) - centro
	if levanta > 0 then
		-- Pillado: hacia la cámara (fuera del mueble; desde Salta, fija), sin torcer el cuello más de SUSTO.Giro. Al
		-- acabar el susto, la última, mientras baja la cabeza.
		local suya = g.mirada
		if s then
			local dir = if s.dir then marco:VectorToObjectSpace(s.dir)
				else (b.raiz.CFrame * marco):PointToObjectSpace(s.mirar) - centro
			local angulo = math.clamp(math.atan2(-dir.X, -dir.Z), -SUSTO.Giro, SUSTO.Giro)
			local alza = math.clamp(math.atan2(dir.Y, math.sqrt(dir.X * dir.X + dir.Z * dir.Z)), -0.6, 0.7)
			suya = Vector3.new(-math.sin(angulo) * math.cos(alza), math.sin(alza), -math.cos(angulo) * math.cos(alza))
			g.mirada = suya
		end
		if suya then
			haciaCara = haciaCara.Unit:Lerp(suya, levanta)
		end
	end
	local giroCara = mirarCara(haciaCara,
		(g.brazo * GATEO.Ladeo * (1 - 0.75 * levanta) + husmea * 0.12 * math.sin(ahora * 11) + tirones.Z) * suave(w))
		* CFrame.Angles(tirones.X, tirones.Y, 0)
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
	if activo and g.sonados < #EVENTOS and u >= EVENTOS[g.sonados + 1] then
		g.sonados += 1
		if not poco or g.sonados == 1 or g.sonados == #EVENTOS then
			ruidoGateo(b, g.sonados)
		end
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Poses de encima (susto y sucesos): herramientas.

-- El torso con lo que tiene este fotograma, en la raíz.
local function torsoEnRaiz(m: { [string]: Motor6D }): CFrame
	return m.Torso.C0 * m.Torso.Transform * m.Torso.C1:Inverse()
end

-- La parte de `v` perpendicular a `n` (unitario), o una cualquiera si no tiene.
local function perpendicular(v: Vector3, n: Vector3): Vector3
	local p = v - n * v:Dot(n)
	if p.Magnitude < 1e-3 then
		local otro = if math.abs(n.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis
		p = otro - n * otro:Dot(n)
	end
	return p.Unit
end

-- Por el suelo, de `punto` (en la raíz) hacia la raíz: hacia él desde la ventana, la puerta o la pared.
local function haciaRaiz(punto: Vector3): Vector3
	local n = Vector3.new(-punto.X, 0, -punto.Z)
	return if n.Magnitude > 1e-3 then n.Unit else Vector3.zAxis
end

-- Una dirección (en la raíz) sin torcer el cuello más de `giro` radianes a cada lado ni mirar más arriba o abajo.
local function sinTorcer(dir: Vector3, giro: number): Vector3
	local plano = math.sqrt(dir.X * dir.X + dir.Z * dir.Z)
	local a = math.clamp(math.atan2(-dir.X, -dir.Z), -giro, giro)
	local alza = math.clamp(math.atan2(dir.Y, plano), -0.9, 0.7)
	return Vector3.new(-math.sin(a) * math.cos(alza), math.sin(alza), -math.cos(a) * math.cos(alza))
end

-- El Transform de la cabeza para que mire en `dir` (en la raíz), ladeada `ladeo` y con `extra` encima, sobre el torso
-- de este fotograma.
local function cabezaHacia(m: { [string]: Motor6D }, dir: Vector3, ladeo: number, extra: CFrame?): CFrame
	local giro = mirarCara(if dir.Magnitude > 1e-3 then dir else -Vector3.zAxis, ladeo)
	if extra then
		giro *= extra
	end
	return (torsoEnRaiz(m) * m.Cabeza.C0).Rotation:Inverse() * giro
end

-- Con la malla: el hombro, el codo y la punta de los dedos de cada brazo en reposo, en los ejes de su bloque (los huesos
-- giran como él: Malla3D). Así alcanzar sabe dónde acaba la mano de verdad (el codo en reposo ya va algo doblado).
local function prepararCodos(rig: Malla3D.Rig?): { [number]: Codo }?
	if not rig then
		return nil
	end
	local indice: { [string]: number } = {}
	for i, h in rig.huesos do
		indice[h.bone.Name] = i
	end
	local codos: { [number]: Codo } = {}
	for _, lado in LADOS do
		local pre = if lado < 0 then "Left" else "Right"
		local ia, ic, im = indice[pre .. "Arm"], indice[pre .. "ForeArm"], indice[pre .. "Hand"]
		local bloque = rig.reposo[if lado < 0 then "BrazoI" else "BrazoD"]
		if ia and ic and im and bloque then
			local hombro, codo, mano = rig.mundo[ia].Position, rig.mundo[ic].Position, rig.mundo[im].Position
			local ante = mano - codo
			if ante.Magnitude > 0.1 and (codo - hombro).Magnitude > 0.1 then
				codos[lado] = {
					hueso = ia,
					A = bloque:VectorToObjectSpace(codo - hombro),
					B = bloque:VectorToObjectSpace(ante + ante.Unit * DEDOS),
				}
			end
		end
	end
	return if next(codos) then codos else nil
end

-- Lleva la punta de las garras del brazo `lado` a `punto` (en la raíz), con el codo hacia `codoHacia`, mezclando `w`.
-- Con la malla dobla el codo (b.codo, que acaba en rig.dobla) lo justo para llegar. Sin ella (bloques, sin codo) el
-- brazo va recto: con `plano` (un punto y su normal hacia él, en la raíz) la punta se queda en el plano, por donde
-- quede más cerca de `punto` (más allá si no llega tan cerca: así no atraviesa la pared); sin él, apunta a `punto`.
local function alcanzar(b: Bicho, lado: number, punto: Vector3, codoHacia: Vector3, w: number, plano: { p: Vector3, n: Vector3 }?)
	if w <= 1e-3 then
		return
	end
	local m = b.motores
	local motor = m[if lado < 0 then "BrazoI" else "BrazoD"]
	local torso = torsoEnRaiz(m)
	local junta = (torso * motor.C0).Position
	local ik = b.codos and b.codos[lado]
	local rig = b.rig
	local desde, A, B = junta, Vector3.zero, GARRAS
	if ik and rig then
		desde, A, B = rig.mundo[ik.hueso].Position, ik.A, ik.B -- el hombro de la malla (del fotograma anterior)
	elseif plano then
		local largo = GARRAS.Magnitude
		local d = (desde - plano.p):Dot(plano.n)
		if d > 0 and d < largo then
			local pie = desde - plano.n * d
			punto = pie + perpendicular(punto - pie, plano.n) * math.sqrt(largo * largo - d * d)
		end
	end
	local hacia = punto - desde
	local largo = hacia.Magnitude
	if largo < 0.3 then
		return
	end
	local codo = 0
	if ik then
		local function mide(k: number): number
			return (A + CFrame.Angles(k, 0, 0) * B).Magnitude
		end
		if largo < mide(0) then
			local lo, hi = 0, CODO_MAX
			if largo <= mide(hi) then
				lo = hi
			else
				for _ = 1, 10 do
					local medio = (lo + hi) / 2
					if mide(medio) > largo then
						lo = medio
					else
						hi = medio
					end
				end
			end
			codo = lo
		end
	end
	-- El giro del brazo: lleva el hombro-punta (con ese codo) hacia `punto` y el codo hacia `codoHacia`.
	local v = (A + CFrame.Angles(codo, 0, 0) * B).Unit
	local a = perpendicular(if ik then A else Vector3.zAxis, v)
	local t = hacia / largo
	local e = perpendicular(codoHacia, t)
	local giro = CFrame.fromMatrix(Vector3.zero, t, e, t:Cross(e)) * CFrame.fromMatrix(Vector3.zero, v, a, v:Cross(a)):Inverse()
	local parte = CFrame.new(junta) * giro * CFrame.new(-motor.C1.Position)
	motor.Transform = motor.Transform:Lerp(motor.C0:Inverse() * torso:Inverse() * parte * motor.C1, w)
	b.codo[lado] += (codo - b.codo[lado]) * w
end

-- El giro más corto de la dirección `a` a la `b` (unitarias).
local function girar(a: Vector3, b: Vector3): CFrame
	local eje = a:Cross(b)
	local seno = eje.Magnitude
	if seno < 1e-6 then
		return CFrame.identity
	end
	return CFrame.fromAxisAngle(eje / seno, math.atan2(seno, a:Dot(b)))
end

-- `dir` (unitaria, desde un punto a `d` del plano de normal `n`) inclinada lo justo para que a `largo` quede a `holgura`
-- del plano, o nil si ya lo está.
local function sinPasar(dir: Vector3, n: Vector3, d: number, largo: number, holgura: number): Vector3?
	local maximo = math.clamp((d - holgura) / largo, -1, 1) -- lo más que puede ir hacia el plano (coseno con -n)
	if -dir:Dot(n) <= maximo then
		return nil
	end
	return -n * maximo + perpendicular(dir, n) * math.sqrt(1 - maximo * maximo)
end

-- Lo que se mira de cada brazo contra la pared y el suelo: { largo desde el hombro, holgura en la pared, en el suelo }.
-- Bloques: el final del brazo (6,2; medio grueso ~0,33) y la punta de las garras (que se abren ~0,25 a los lados).
-- Malla: el codo (lo gordo del brazo) y la punta de los dedos (su largo, el de cada fotograma: con el codo doblado).
local PASAR_BLOQUES = { { 6.2, 0.33, 0.33 }, { GARRAS.Magnitude, 0.3, 0.2 } }
local PASAR_MALLA = { codo = { 0.25, 0.25 }, punta = { 0.12, 0.12 } }
local SUELO_PLANO = { p = Vector3.new(0, -ALTURA, 0), n = Vector3.yAxis }

-- Con los brazos ya puestos este fotograma: si alguno pasa de alguno de los `planos` (un punto y su normal hacia él, en
-- la raíz) o del suelo, lo gira desde el hombro lo justo para que no (tres vueltas: lo que le saca de una pared puede
-- meterle en el suelo). Al entrar y salir de un suceso los brazos van de colgar a la pared mezclando (Lerp) y, tan
-- largos, a medio camino la atravesaban; agachado, colgando se metían en el suelo (comprobado con Lune).
local function noAtravesar(b: Bicho, planos: { { p: Vector3, n: Vector3 } })
	local m = b.motores
	local torso = torsoEnRaiz(m)
	for _, lado in LADOS do
		local motor = m[if lado < 0 then "BrazoI" else "BrazoD"]
		local junta = (torso * motor.C0).Position
		local parte = torso * motor.C0 * motor.Transform * motor.C1:Inverse()
		local ik = b.codos and b.codos[lado]
		local malla = ik ~= nil and b.rig ~= nil
		local hombro = if ik and b.rig then b.rig.mundo[ik.hueso].Position else junta
		local tramos = if ik and malla
			then { { ik.A, PASAR_MALLA.codo[1], PASAR_MALLA.codo[2] },
				{ ik.A + CFrame.Angles(b.codo[lado], 0, 0) * ik.B, PASAR_MALLA.punta[1], PASAR_MALLA.punta[2] } }
			else nil
		local giro = CFrame.identity
		for vuelta = 1, 3 do
			for i = 0, #planos do
				local plano = if i == 0 then SUELO_PLANO else planos[i]
				if i == 0 and vuelta == 1 then
					continue -- el suelo, después de la primera pared
				end
				local n = plano.n
				local d = (hombro - plano.p):Dot(n)
				if d <= 0 then
					continue
				end
				for k = 1, 2 do
					local v, largo, holgura
					if tramos then
						local t = tramos[k]
						v = giro:VectorToWorldSpace(parte:VectorToWorldSpace(t[1]))
						largo, holgura = v.Magnitude, if i == 0 then t[3] else t[2]
						v /= largo
					else
						local t = PASAR_BLOQUES[k]
						v = giro:VectorToWorldSpace(parte:VectorToWorldSpace(GARRAS.Unit))
						largo, holgura = t[1], if i == 0 then t[3] else t[2]
					end
					local nuevo = sinPasar(v, n, d, largo, holgura)
					if nuevo then
						giro = girar(v, nuevo) * giro
					end
				end
			end
		end
		if giro ~= CFrame.identity then
			parte = CFrame.new(junta) * giro * CFrame.new(-junta) * parte
			motor.Transform = motor.C0:Inverse() * torso:Inverse() * parte * motor.C1
		end
	end
end

-- Agachado con la cara (la de la malla, o el frente de la cabeza) en `cara` (en la raíz) mirando en `dir`, ladeada: el
-- torso cuelga del cuello como al gatear (la cadera, como mucho hasta SUCESO.Cadera; si hace falta, echada atrás) y las
-- piernas van al suelo bajo ella, por delante. Devuelve el marco del suelo, mirando hacia `dir`.
local function agachar(b: Bicho, cara: Vector3, dir: Vector3, ladeo: number, w: number): CFrame
	local m = b.motores
	-- Al entrar y salir, la cara va en línea recta desde donde la tiene ahora (de pie) y casi sin mezclar: mezclando el
	-- torso y la cabeza, a medio camino la cabeza se iba hacia delante y se metía en la puerta (comprobado con Lune).
	local ahora = torsoEnRaiz(m) * m.Cabeza.C0 * m.Cabeza.Transform * m.Cabeza.C1:Inverse()
	cara = (ahora * b.offCara):Lerp(cara, w)
	dir = ahora.LookVector:Lerp(dir.Unit, w)
	ladeo *= w
	w = math.min(1, w * 4)
	local giroCara = mirarCara(dir, ladeo)
	local cuello = cara - giroCara * b.offCara - giroCara * CABEZA_CENTRO
	local plano = Vector3.new(dir.X, 0, dir.Z)
	local rumbo = CFrame.Angles(0, if plano.Magnitude > 1e-3 then math.atan2(-plano.X, -plano.Z) else 0, 0)
	local fi = math.acos(math.clamp((cuello.Y - SUCESO.Cadera) / 3.8, -0.2, math.cos(0.4)))
	local giroT = rumbo * CFrame.fromMatrix(Vector3.zero, Vector3.xAxis, Vector3.new(0, math.cos(fi), -math.sin(fi)))
	local torsoC = CFrame.new(cuello - giroT * m.Cabeza.C0.Position) * giroT
	m.Torso.Transform = m.Torso.Transform:Lerp(m.Torso.C0:Inverse() * torsoC * m.Torso.C1, w)
	m.Cabeza.Transform = m.Cabeza.Transform:Lerp((torsoC * m.Cabeza.C0):Inverse() * (CFrame.new(cuello) * giroCara), w)
	local marco = CFrame.new(0, -ALTURA, 0) * rumbo
	local torso = marco:Inverse() * torsoEnRaiz(m)
	local cadera = torso * m.Torso.C1.Position
	for _, lado in LADOS do
		local motor = m[if lado < 0 then "PiernaI" else "PiernaD"]
		local junta = cadera + torso.XVector * motor.C0.Position.X - Vector3.new(0, 0.1, 0)
		-- Abiertas a los lados (como una araña; hacia delante, de pie el pie iba 1,5 adelante y se metía en la puerta).
		local cae = math.clamp((junta.Y - 0.3) / PIERNA, 0, 1)
		local hacia = Vector3.new(lado * 0.9, 0, -0.3).Unit * math.sqrt(1 - cae * cae) - Vector3.yAxis * cae
		local parte = CFrame.new(junta) * orientar(hacia, -Vector3.zAxis) * CFrame.new(-motor.C1.Position)
		-- (Más deprisa que el resto: mezclando a medias, a medio camino el pie se metía ~0,2 en el suelo.)
		motor.Transform = motor.Transform:Lerp(motor.C0:Inverse() * (marco * parte) * motor.C1, math.min(1, w * 3))
	end
	return marco
end

-- Los cuerpos que no cuentan para los rayos de los sucesos: los bichos y los jugadores.
local function filtrarSucesos()
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
	filtroSuceso.FilterDescendantsInstances = fuera
end

-- `punto` (en el mundo) llevado a la superficie que tenga delante, a lo largo de `n` (hacia él): la pared de al lado de
-- la ventana o del armario, que puede no estar justo en el plano del cristal o de la puerta.
local function enLaPared(punto: Vector3, n: Vector3): Vector3
	local choque = workspace:Raycast(punto + n * 1.5, -n * 3, filtroSuceso)
	return if choque then choque.Position + n * 0.06 else punto
end

-- Lo que suena flojo mientras no esté el sonido de verdad (Id 0): `nombre`, con su tono y volumen, cortado a los `dura` s.
local function provisional(nombre: string, donde: Vector3, tono: number, volumen: number, dura: number): Sound
	local s = Sonido.en(nombre, donde, tono)
	s.Volume *= volumen
	task.delay(dura * 0.6, function()
		if s.Parent then
			TweenService:Create(s, TweenInfo.new(dura * 0.4), { Volume = 0 }):Play()
		end
	end)
	task.delay(dura, function()
		if s.Parent then
			s:Stop()
		end
	end)
	return s
end

-- La boca de la malla (o de la cabeza de bloques) en el mundo.
local function bocaDe(b: Bicho): Vector3
	return ((if b.rig and b.rig.cara then b.rig.cara else b.cabeza).CFrame * BOCA).Position
end

------------------------------------------------------------------------------------------------------------------------
-- Sucesos al azar: una pose por suceso (b, el suceso, su peso ya suave, dt, ahora, fino: con los detalles pequeños).
type Pose = (Bicho, Suceso, number, number, number, boolean) -> ()

-- Las manos apoyadas a los lados de `mira` (Armario y Cara): en la pared y, con la malla, con el codo doblado hacia fuera.
local function manosEnPared(b: Bicho, r: Suceso, w: number, mira: Vector3, n: Vector3, manos: Vector2)
	local raiz = b.raiz.CFrame
	local derecha = (-n):Cross(Vector3.yAxis)
	for _, lado in LADOS do
		local mano = r.manos[lado]
		if not mano then
			mano = enLaPared(raiz * (mira + derecha * lado * manos.X + Vector3.new(0, manos.Y, 0)), raiz:VectorToWorldSpace(n))
			r.manos[lado] = mano
		end
		local p = raiz:PointToObjectSpace(mano)
		alcanzar(b, lado, p, derecha * lado * 0.7 + n * 0.5 - Vector3.yAxis * 0.3, w, { p = p, n = n })
	end
	table.insert(b.planos, { p = mira, n = n }) -- (noAtravesar, en animar: después de todo lo que mueve los brazos)
end

local POSES: { [string]: Pose } = {}

-- Armario: pegado a las rendijas (no sabe que estás), la cabeza ladeada mirando dentro, respirando fuerte y lento (la
-- respiración, en animar), con las manos en la pared a los lados del armario.
POSES.Armario = function(b, r, w, _dt, ahora, fino)
	local A = SUCESO.Armario
	local mira = b.raiz.CFrame:PointToObjectSpace(r.mira)
	local n = haciaRaiz(mira)
	local derecha = (-n):Cross(Vector3.yAxis)
	local aire = math.sin(b.respira)
	local mece = if fino then math.sin(ahora * 0.35) else 0
	local cara = mira + n * (A.Frente + 0.06 * aire) + derecha * 0.12 * mece
	local dir = -n + Vector3.new(0, -0.08, 0) + derecha * (if fino then 0.1 * math.sin(ahora * 0.27) else 0)
	agachar(b, cara, dir, A.Ladeo + 0.15 * mece, w)
	b.agacha = math.max(b.agacha, w)
	manosEnPared(b, r, w, mira, n, A.Manos)
	local m = b.motores
	m.Mandibula.Transform = m.Mandibula.Transform:Lerp(CFrame.Angles(-(0.3 + 0.15 * math.max(0, -aire)), 0, 0), w)
end

-- Olfatea: levanta la cabeza hacia ti y da golpes de nariz cortos, en tandas.
POSES.Olfatea = function(b, r, w, _dt, ahora)
	local O = SUCESO.Olfatea
	if r.activo and ahora >= r.proximo then
		if r.tanda <= 0 then
			r.tanda = O.Tanda
		end
		r.tanda -= 1
		r.golpe = ahora
		r.proximo = ahora + (if r.tanda > 0 then O.Cada else rango(O.Pausa))
		if w > 0.5 then
			local nariz = bocaDe(b)
			if Sonido.hay("Olfateo") then
				Sonido.en("Olfateo", nariz)
			else
				provisional("Rafaga", nariz, 1.7, 0.35, 0.16) -- un soplo corto y agudo, como de nariz
			end
		end
	end
	local tg = ahora - r.golpe
	local golpe = if tg < 0.05 then tg / 0.05 elseif tg < 0.2 then 1 - (tg - 0.05) / 0.15 else 0
	local m = b.motores
	m.Torso.Transform = m.Torso.Transform:Lerp(CFrame.new(0, 0.06 * golpe, 0) * CFrame.Angles(0.12 + 0.02 * golpe, 0, 0), w)
	local raiz = b.raiz.CFrame
	local dir = sinTorcer(raiz:PointToObjectSpace(r.mira) - raiz:PointToObjectSpace(b.cabeza.Position), 1.3)
	dir = (dir + Vector3.new(0, O.Alza, 0)).Unit
	local nariz = CFrame.new(0, 0, -0.08 * golpe) * CFrame.Angles(0.12 * golpe, 0, 0)
	m.Cabeza.Transform = m.Cabeza.Transform:Lerp(cabezaHacia(m, dir, 0.15, nariz), w)
	m.Mandibula.Transform = m.Mandibula.Transform:Lerp(CFrame.Angles(-(0.22 - 0.12 * golpe), 0, 0), w)
end

-- Llama: un dedo contra el cristal, tres toques lentos (a la hora que dice Caza; el remote "Toque" lo hace sonar).
POSES.Llama = function(b, r, w, _dt, ahora, fino)
	local L = SUCESO.Llama
	local reglas = Config.Golpeador.Sucesos.Llama
	local mira = b.raiz.CFrame:PointToObjectSpace(r.mira)
	local n = haciaRaiz(mira)
	local derecha = (-n):Cross(Vector3.yAxis)
	if r.lado == 0 then
		r.lado = if mira:Dot(Vector3.xAxis) >= 0 then 1 else -1 -- el brazo del lado de la ventana
	end
	local tt = workspace:GetServerTimeNow() - r.hora
	local cerca = 0
	for i = 1, reglas.Toques do
		local d = tt - (i - 0.5) * reglas.CadaToque
		if d > -L.Acerca and d < L.Retira then
			cerca = math.max(cerca, if d < 0 then suave(1 + d / L.Acerca) else 1 - suave(d / L.Retira))
		end
	end
	local tr = ahora - r.golpe -- por si el reloj no cuadra: el remote también lo pone en el cristal
	if tr < L.Retira then
		cerca = math.max(cerca, 1 - suave(tr / L.Retira))
	end
	local punto = mira + Vector3.new(0, L.Alto, 0) + derecha * r.lado * 0.35 + n * (0.05 + L.Aparte * (1 - cerca))
	local m = b.motores
	m.Torso.Transform = m.Torso.Transform:Lerp(CFrame.Angles(0.06 + 0.03 * math.sin(ahora * 0.8), 0, 0), w)
	local raiz = b.raiz.CFrame
	local dir = sinTorcer(punto - raiz:PointToObjectSpace(b.cabeza.Position), 1.2)
	m.Cabeza.Transform = m.Cabeza.Transform:Lerp(cabezaHacia(m, dir, 0.4 + (if fino then 0.06 * math.sin(ahora * 0.7) else 0)), w)
	alcanzar(b, r.lado, punto, derecha * r.lado * 0.6 - Vector3.yAxis * 0.7, w, { p = mira + n * 0.05, n = n })
	table.insert(b.planos, { p = mira, n = n }) -- (noAtravesar, en animar: después de todo lo que mueve los brazos)
	m.Mandibula.Transform = m.Mandibula.Transform:Lerp(CFrame.Angles(-0.35, 0, 0), w)
end

-- Cara: la cara pegada al cristal mirando dentro, agachado hasta él, con las manos apoyadas a los lados.
POSES.Cara = function(b, r, w, _dt, ahora, fino)
	local C = SUCESO.Cara
	local mira = b.raiz.CFrame:PointToObjectSpace(r.mira)
	local n = haciaRaiz(mira)
	local derecha = (-n):Cross(Vector3.yAxis)
	local mece = if fino then math.sin(ahora * 0.6) else 0
	local cara = mira + Vector3.new(0, C.Alto, 0) + n * C.Frente + derecha * 0.08 * mece
	agachar(b, cara, -n + Vector3.new(0, -0.1, 0), 0.2 + 0.12 * mece, w)
	b.agacha = math.max(b.agacha, w)
	manosEnPared(b, r, w, mira, n, C.Manos)
	local m = b.motores
	m.Mandibula.Transform = m.Mandibula.Transform:Lerp(CFrame.Angles(-(0.45 + 0.12 * mece), 0, 0), w)
end

-- Aparta: se echa atrás de golpe, con la cabeza apartada y los brazos subiendo.
POSES.Aparta = function(b, _r, w)
	local m = b.motores
	m.Torso.Transform = m.Torso.Transform:Lerp(CFrame.new(0, 0.25, 0.9) * CFrame.Angles(0.45, 0, 0), w)
	m.Cabeza.Transform = m.Cabeza.Transform:Lerp(CFrame.fromEulerAnglesYXZ(0.35, 0.45, -0.3), w)
	for _, lado in LADOS do
		local motor = m[if lado < 0 then "BrazoI" else "BrazoD"]
		motor.Transform = motor.Transform:Lerp(CFrame.Angles(0.6, 0, lado * 0.9), w)
	end
	m.Mandibula.Transform = m.Mandibula.Transform:Lerp(CFrame.Angles(-0.9, 0, 0), w)
end

-- Todo quieto (Finge y Quieto): el torso algo echado adelante (y girado `giro`), los brazos colgando, las piernas rectas.
local function quieto(b: Bicho, w: number, giro: number)
	local m = b.motores
	m.Torso.Transform = m.Torso.Transform:Lerp(CFrame.Angles(-0.08, giro, 0), w)
	for _, lado in LADOS do
		local motor = m[if lado < 0 then "BrazoI" else "BrazoD"]
		motor.Transform = motor.Transform:Lerp(CFrame.Angles(0.04, 0, lado * 0.1), w)
	end
	m.PiernaI.Transform = m.PiernaI.Transform:Lerp(CFrame.identity, w)
	m.PiernaD.Transform = m.PiernaD.Transform:Lerp(CFrame.identity, w)
	m.Mandibula.Transform = m.Mandibula.Transform:Lerp(CFrame.Angles(-0.28, 0, 0), w)
end

-- Finge: parado, mira atrás por encima del hombro hacia la casa, despacio (SUCESO.Despacio) y quieto.
POSES.Finge = function(b, r, w)
	local raiz = b.raiz.CFrame
	local mira = raiz:PointToObjectSpace(r.mira)
	local angulo = math.atan2(-mira.X, -mira.Z)
	quieto(b, w, math.clamp(angulo * 0.3, -0.55, 0.55))
	local m = b.motores
	local dir = sinTorcer(mira - raiz:PointToObjectSpace(b.cabeza.Position), 2.1)
	m.Cabeza.Transform = m.Cabeza.Transform:Lerp(cabezaHacia(m, dir, 0.2), w)
end

-- Quieto: alumbrado al fondo, no se mueve; solo la cabeza se ladea despacio, a tirones, crujiendo flojo.
POSES.Quieto = function(b, r, w, dt, ahora)
	local Q = SUCESO.Quieto
	if r.activo and ahora >= r.proximo and r.ladeoMeta < Q.Max then
		r.proximo = ahora + rango(Q.Cada)
		r.ladeoMeta = math.min(Q.Max, r.ladeoMeta + Q.Paso)
		if w > 0.5 then
			Sonido.en("Crujido", b.cabeza.Position, 1.15).Volume *= Q.Volumen
		end
	end
	r.ladeo = acercar(r.ladeo, r.ladeoMeta, dt, 18)
	quieto(b, w, 0)
	local raiz = b.raiz.CFrame
	local m = b.motores
	local dir = sinTorcer(raiz:PointToObjectSpace(r.mira) - raiz:PointToObjectSpace(b.cabeza.Position), 1)
	m.Cabeza.Transform = m.Cabeza.Transform:Lerp(cabezaHacia(m, dir, r.ladeo), w)
end

-- Garras: andando junto a una pared, el brazo de SucesoLado estirado hacia ella arrastrando las garras por detrás del
-- hombro. La pared se busca con un rayo desde el hombro (la punta se queda SUCESO.Garras.Pared antes de ella) y otro
-- del hombro a la punta: si algo se cruza (el marco de una puerta, una esquina) o no hay pared, el brazo se recoge.
POSES.Garras = function(b, r, w, dt, ahora, fino)
	local G = SUCESO.Garras
	local lado = if r.lado < 0 then -1 else 1
	local m = b.motores
	local raiz = b.raiz.CFrame
	local motor = m[if lado < 0 then "BrazoI" else "BrazoD"]
	local ik = b.codos and b.codos[lado]
	local hombro = if ik and b.rig then b.rig.mundo[ik.hueso].Position else (torsoEnRaiz(m) * motor.C0).Position
	local hombroM = raiz * hombro
	if r.activo and ahora - r.rayo >= (if fino then G.Cada else G.CadaPoco) then
		r.rayo = ahora
		local hacia = r.normal and -r.normal or Vector3.new(r.mira.X - hombroM.X, 0, r.mira.Z - hombroM.Z)
		if hacia.Magnitude < 1e-3 then
			hacia = raiz.RightVector * lado
		end
		r.punta = nil
		local choque = workspace:Raycast(hombroM, hacia.Unit * G.Largo, filtroSuceso)
		local nn = choque and Vector3.new(choque.Normal.X, 0, choque.Normal.Z)
		if choque and nn and nn.Magnitude > 0.5 then
			nn = nn.Unit
			r.normal = nn
			local d = (hombroM - choque.Position):Dot(nn)
			local atras = perpendicular(-raiz.LookVector, nn)
			local punta = hombroM - nn * (d - G.Pared) + atras * G.Atras - Vector3.yAxis * G.Bajo
			if not workspace:Raycast(hombroM, punta - hombroM, filtroSuceso) then
				r.punta = choque.Position + nn * G.Pared -- (un punto del plano de la pared, ya con su holgura)
			end
		end
	end
	local toca = r.activo and r.punta ~= nil and r.normal ~= nil
	r.contacto = acercar(r.contacto, if toca then 1 else 0, dt, 8)
	local normal, enPlano = r.normal, r.punta
	if normal and enPlano and r.contacto > 1e-3 then
		-- La punta, cada fotograma desde el hombro de ahora (sigue andando): en el plano, detrás y abajo.
		local d = (hombroM - enPlano):Dot(normal)
		local atras = perpendicular(-raiz.LookVector, normal)
		local punta = hombroM - normal * d + atras * G.Atras - Vector3.yAxis * G.Bajo
		local n = raiz:VectorToObjectSpace(normal)
		alcanzar(b, lado, raiz:PointToObjectSpace(punta), n * 0.7 + Vector3.yAxis * 0.3 + Vector3.zAxis * 0.4, w * r.contacto,
			{ p = raiz:PointToObjectSpace(enPlano), n = n })
		-- El arañazo, en bucle donde están las garras: más fuerte andando.
		if not r.punto then
			local nombre = if Sonido.hay("UnasPared") then "UnasPared" else "Raspado"
			local punto = Instance.new("Attachment")
			punto.Name = "GarrasGolpeador"
			punto.Parent = workspace.Terrain
			local s = Sonido.bucle(nombre, punto)
			s.RollOffMode = Enum.RollOffMode.InverseTapered
			s.RollOffMinDistance = 6
			s.RollOffMaxDistance = Config.Sonidos[nombre].Alcance or 45
			s:SetAttribute("Base", s.Volume * (if nombre == "Raspado" then 0.35 else 1)) -- el Raspado, bajito
			s.Volume = 0
			r.punto, r.sonido = punto, s
		end
		local v = b.raiz.AssemblyLinearVelocity
		local s = r.sonido :: Sound
		;(r.punto :: Attachment).WorldPosition = punta
		s.Volume = (s:GetAttribute("Base") or 0.5) * r.contacto * math.clamp(Vector3.new(v.X, 0, v.Z).Magnitude / 4, 0.35, 1)
	elseif r.sonido then
		r.sonido.Volume = 0
	end
	if normal and enPlano then
		table.insert(b.planos, { p = raiz:PointToObjectSpace(enPlano - normal * G.Pared), n = raiz:VectorToObjectSpace(normal) })
	end
end

-- El orden en que se ponen (Aparta, la última: sale de la Cara y manda sobre ella).
local ORDEN = { "Armario", "Olfatea", "Llama", "Cara", "Finge", "Garras", "Quieto", "Aparta" }

local function acabarSuceso(r: Suceso)
	if r.punto then
		r.punto:Destroy()
		r.punto, r.sonido = nil, nil
	end
end

local function olvidarSucesos(b: Bicho)
	for _, r in b.sucesos do
		acabarSuceso(r)
	end
	table.clear(b.sucesos)
	b.agacha = 0
end

-- Los sucesos del modelo, encima de la pose de siempre (que ya está en las juntas este fotograma).
local function sucesos(b: Bicho, dt: number, ahora: number, fino: boolean)
	local modelo = b.modelo
	local nombre = modelo:GetAttribute("Suceso")
	local lista = b.sucesos
	if typeof(nombre) ~= "string" or not POSES[nombre] then
		nombre = nil
	end
	b.agacha = 0
	table.clear(b.planos)
	if nombre == nil and next(lista) == nil then
		return
	end
	if nombre then
		local hora = modelo:GetAttribute("SucesoHora")
		hora = if typeof(hora) == "number" then hora else 0
		local r = lista[nombre]
		if not r or r.hora ~= hora then
			local lado = modelo:GetAttribute("SucesoLado")
			local nuevo: Suceso = {
				nombre = nombre, hora = hora, mira = b.cabeza.Position, lado = if typeof(lado) == "number" then lado else 0,
				w = if r then r.w else 0, activo = true, manos = {}, proximo = ahora + 0.3, golpe = -math.huge, tanda = 0,
				ladeo = LADEO, ladeoMeta = LADEO, normal = nil, punta = nil, contacto = 0, rayo = -math.huge,
				sonido = nil, punto = nil,
			}
			if r then
				acabarSuceso(r)
			end
			lista[nombre] = nuevo
			filtrarSucesos()
		end
		local mira = modelo:GetAttribute("SucesoMira")
		if typeof(mira) == "Vector3" then
			lista[nombre].mira = mira
		end
	end
	for _, n in ORDEN do
		local r = lista[n]
		if not r then
			continue
		end
		r.activo = n == nombre
		local rapidez = if n == "Aparta" then SUCESO.Rapido
			elseif not r.activo then SUCESO.Sale
			elseif n == "Finge" then SUCESO.Despacio
			else SUCESO.Entra
		r.w = if r.activo then math.min(1, r.w + dt * rapidez) else math.max(0, r.w - dt * rapidez)
		if r.w <= 0 and not r.activo then
			acabarSuceso(r)
			lista[n] = nil
			continue
		end
		POSES[n](b, r, suave(r.w), dt, ahora, fino)
	end
end

------------------------------------------------------------------------------------------------------------------------
-- El susto al pillarte (rugir).

-- Por dónde va: la fase, el tirón de la cabeza y a dónde mira. Antes de gatear (que lo usa si te pilló gateando).
local function pasoSusto(b: Bicho, dt: number, ahora: number)
	local s = b.susto
	if not s then
		return
	end
	local c = Config.Golpeador.Susto
	local t = ahora - s.t0
	local fin = if s.gatea then c.Espera - SUSTO.Antes else c.Espera
	if t >= fin + (if s.gatea then 0 else SUSTO.Sale) then
		b.susto = nil
		return
	end
	s.w = if t < fin then math.min(1, t / SUSTO.Entra) else 1 - (t - fin) / SUSTO.Sale
	local antes = s.fase
	local fase, u = "Fin", 1
	local resto = t
	if s.gatea then
		if resto < c.Arrastra then
			fase, u = "Arrastra", resto / c.Arrastra
		end
		resto -= c.Arrastra
	end
	if fase == "Fin" and resto >= 0 then
		for _, f in FASES do
			local dura = (c :: any)[f]
			if resto < dura then
				fase, u = f, resto / dura
				break
			end
			resto -= dura
		end
	end
	s.fase, s.u = fase, u
	if fase == "Arrastra" or fase == "Mira" then
		s.mirar = workspace.CurrentCamera.CFrame.Position -- tu cabeza (la cámara la lleva MuerteVista)
	elseif not s.dir then
		s.dir = b.raiz.CFrame:VectorToObjectSpace(s.mirar - b.cabeza.Position)
	end
	if fase == "Salta" and antes ~= "Salta" then
		Sonido.en("Paso", b.raiz.Position - Vector3.new(0, ALTURA, 0), 0.5) -- el pisotón al abalanzarse
	end
	if fase == "Encima" then
		if ahora >= s.proximo then
			s.proximo = ahora + rango(SUSTO.Tirones)
			local k = SUSTO.Tiron
			s.meta = Vector3.new(azar:NextNumber(-k.X, k.X), azar:NextNumber(-k.Y, k.Y), azar:NextNumber(-k.Z, k.Z))
		end
	else
		s.meta = Vector3.zero
	end
	s.tir = s.tir:Lerp(s.meta, math.min(1, dt * 30))
end

-- Cuánto abre la boca en cada fase del susto (radianes).
local function bocaSusto(s: Susto, ahora: number): number
	local B = SUSTO.Boca
	if s.fase == "Arrastra" then
		return B.Arrastra + 0.08 * math.sin(ahora * 21)
	elseif s.fase == "Mira" then
		return B.Mira + 0.04 * math.sin(ahora * 5)
	elseif s.fase == "Salta" then
		return B.Mira + (B.Salta - B.Mira) * suave(s.u)
	end
	return B.Encima + 0.07 * math.sin(ahora * 37)
end

-- La pose del susto, encima de todo: de pie, el cuerpo entero; gateando (lo hace gatear), solo las garras.
local function asustar(b: Bicho, ahora: number, fino: boolean)
	local s = b.susto
	if not s then
		return
	end
	local m = b.motores
	local f, u = s.fase, s.u
	local k = if f == "Mira" or f == "Arrastra" then 0 elseif f == "Salta" then 1 - (1 - u) * (1 - u) else 1
	local kt = if f == "Tiron" then suave(u) elseif f == "Fin" then 1 else 0
	local w = if s.gatea then 1 else suave(math.clamp(s.w, 0, 1))
	if not s.gatea then
		local tiembla = if f == "Encima" then 0.025 * math.sin(ahora * 43) else 0
		m.Torso.Transform = m.Torso.Transform:Lerp(CFrame.new(0, -0.25 * k - 0.1 * kt, -0.7 * k - 0.5 * kt)
			* CFrame.Angles(-0.12 - 0.45 * k - 0.2 * kt + tiembla, 0, tiembla * 0.6), w)
		local dir = s.dir or b.raiz.CFrame:VectorToObjectSpace(s.mirar - b.cabeza.Position)
		m.Cabeza.Transform = m.Cabeza.Transform:Lerp(
			cabezaHacia(m, dir, 0.3 - 0.15 * k + s.tir.Z, CFrame.Angles(s.tir.X, s.tir.Y, 0)), w)
		m.Mandibula.Transform = m.Mandibula.Transform:Lerp(CFrame.Angles(-bocaSusto(s, ahora), 0, 0), w)
		for _, lado in LADOS do
			local motor = m[if lado < 0 then "BrazoI" else "BrazoD"]
			motor.Transform = motor.Transform:Lerp(CFrame.Angles(0.15 + 0.75 * k + 0.3 * kt, 0, lado * (0.12 + 1.3 * k - 0.3 * kt)), w)
		end
		m.PiernaI.Transform = m.PiernaI.Transform:Lerp(CFrame.Angles(-0.2 * k, 0, 0), w)
		m.PiernaD.Transform = m.PiernaD.Transform:Lerp(CFrame.Angles(0.3 * k, 0, 0), w)
		garrasSobreSuelo(b) -- (echado adelante, colgando, las garras rozaban el suelo)
	end
	-- Las garras entrando por los lados de la pantalla: solo con la malla (los bloques no tienen codo: rectos, cruzarían
	-- la cámara). Van en la cara de la malla (donde va la cámara), así siguen a los tirones de la cabeza.
	local cara = b.rig and b.rig.cara
	if b.codos and cara and (f == "Encima" or f == "Tiron" or f == "Fin") then
		local entra = if f == "Encima" then suave(math.min(1, u * Config.Golpeador.Susto.Encima / SUSTO.GarrasEntran)) else 1
		-- El marco: en la cara y con -Z hacia la cámara (el -Z de Cara3D apunta hacia abajo con él encorvado: las
		-- garras salían bajo la barbilla, fuera de la pantalla; probado en Studio).
		local ojoCam = workspace.CurrentCamera.CFrame.Position
		local marco = if (ojoCam - cara.Position).Magnitude > 0.3 then CFrame.lookAt(cara.Position, ojoCam) else cara.CFrame
		local enCara = b.raiz.CFrame:ToObjectSpace(marco)
		for _, lado in LADOS do
			local en = SUSTO.GarrasDesde:Lerp(SUSTO.Garras, entra):Lerp(SUSTO.GarrasTiron, kt)
			local zarpa = if fino then 0.06 * math.sin(ahora * 29 + lado * 2) else 0
			local punto = enCara * Vector3.new(lado * en.X, en.Y + zarpa, en.Z)
			alcanzar(b, lado, punto, enCara:VectorToWorldSpace(Vector3.new(lado, -0.4, 0.5)), w)
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
	local lejos = if poco then LEJOS_RENDIMIENTO else LEJOS
	local noche = workspace:GetAttribute("Fase") == "Noche"
	local mirilla = jugador:GetAttribute("Mirilla") == true
	for modelo, b in bichos do
		if not modelo.Parent or not b.raiz.Parent then
			olvidarSucesos(b) -- (el arañazo de Garras, si sonaba)
			bichos[modelo] = nil
			continue
		end
		local distancia = (b.raiz.Position - ojo).Magnitude
		if distancia > lejos then
			if next(b.sucesos) then
				olvidarSucesos(b)
			end
			continue
		end
		local m = b.motores
		b.codo[-1], b.codo[1] = 0, 0
		local fino = not poco and distancia < vidaLejos -- los detalles pequeños de los sucesos y del susto
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
		-- Mirando por las rendijas del armario, fuerte y lento, y se le oye soltar el aire.
		local calma = math.clamp((tg - 1) / 4, 0, 1)
		local armario = b.sucesos.Armario
		local lento = armario ~= nil and armario.activo and armario.w > 0.5
		b.respira += dt * 2 * math.pi / (if lento then SUCESO.Armario.Respira else RESPIRA[1] + (RESPIRA[2] - RESPIRA[1]) * calma)
		local aire = math.sin(b.respira) -- más: coge aire; menos: lo suelta
		local soltando = math.cos(b.respira) < 0
		if lento and soltando and not b.exhala then
			if Sonido.hay("RespiraBicho") then
				Sonido.en("RespiraBicho", bocaDe(b))
			else
				provisional("Rugido", bocaDe(b), 0.5, 0.2, 1.4) -- mientras falta: el rugido muy grave, flojo y cortado
			end
		end
		if soltando and not b.exhala and noche and not poco and vida > 0.5 and distancia < VAHO_LEJOS then
			local boca = (if b.rig and b.rig.cara then b.rig.cara else b.cabeza).CFrame * BOCA
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

		-- Los sucesos al azar (Armario, Olfatea, Llama...), encima.
		sucesos(b, dt, ahora, fino)

		-- Aturdido por el flash: se echa atrás tapándose la cara con los brazos, temblando.
		local hasta = modelo:GetAttribute("Aturdido")
		local aturdido = typeof(hasta) == "number" and workspace:GetServerTimeNow() < hasta
		b.aturde = acercar(b.aturde, if aturdido then 1 else 0, dt, if aturdido then 7 else 2)
		if b.aturde > 0.001 then
			local k = suave(b.aturde)
			local tiembla = ATURDE.Tiembla * math.sin(ahora * ATURDE.Rapido)
			m.Torso.Transform = m.Torso.Transform:Lerp(CFrame.new(0, -0.2, 0.3) * CFrame.Angles(ATURDE.Torso + tiembla, 0, 0), k)
			local c = ATURDE.Cabeza
			m.Cabeza.Transform = m.Cabeza.Transform:Lerp(CFrame.fromEulerAnglesYXZ(c.X + tiembla, c.Y, c.Z), k)
			for _, lado in LADOS do
				local motor = m[if lado < 0 then "BrazoI" else "BrazoD"]
				motor.Transform = motor.Transform:Lerp(CFrame.Angles(ATURDE.Brazo[1] + tiembla * 2 * lado, 0, -lado * ATURDE.Brazo[2]), k)
			end
			m.Mandibula.Transform = m.Mandibula.Transform:Lerp(CFrame.Angles(-ATURDE.Boca, 0, 0), k)
		end

		garrasSobreSuelo(b)

		-- Sin atravesar el tablero de la mesa de al lado: la postura de pie (de la que sale y a la que vuelve al gatear) y,
		-- por si acaso, lo que quede después de gatear (al echarse y al levantarse, a medio camino entre las dos). Solo
		-- cerca (o gateando): de más lejos no se nota, y buscar la mesa y probar los brazos contra ella cuesta.
		if distancia < VIDA_LEJOS or gateando then
			mesaCerca(b, ahora)
			apartarBrazos(b, dt, b.aparta)
		end
		-- Sin atravesar la pared de un suceso (la ventana, la puerta del armario, la del pasillo) ni el suelo.
		if b.planos[1] then
			noAtravesar(b, b.planos)
		end

		-- Debajo de un mueble: se echa al suelo y gatea a por ti, encima de todo lo anterior (si te ha pillado gateando,
		-- en el suelo hace también el susto, con su boca).
		pasoSusto(b, dt, ahora)
		local susto = b.susto
		gatear(b, dt, ahora, poco, if susto and susto.gatea then bocaSusto(susto, ahora) - 0.2 else abre)
		if b.gatea then
			apartarBrazos(b, dt, b.aparta2)
		end
		-- El susto al pillarte, encima de todo.
		asustar(b, ahora, fino)

		local rig = b.rig
		if rig then
			-- Los codos de la malla: tapándose la cara (aturdido) y lo que doblen las poses de encima (alcanzar).
			for nombre, lado in CODOS do
				rig.dobla[nombre] = Vector3.new(b.codo[lado], 0, -lado * ATURDE.Codo * suave(b.aturde))
			end
			-- Dónde cae su cara en la cabeza de bloques (para agachar), del fotograma anterior.
			if rig.cara then
				b.offCara = b.offCara:Lerp(b.cabeza.CFrame:PointToObjectSpace(rig.cara.Position), math.min(1, dt * 4))
			end
			rig.alinear = math.max(suave(b.gateo), suave(b.agacha))
			Malla3D.mover(rig)
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
	-- Con modelo 3D (lo dice el servidor): se espera a su malla; si no llega, se queda con los bloques.
	if modelo:GetAttribute("Malla3D") then
		modelo:WaitForChild("Malla3D", 5)
	end
	if not modelo.Parent or bichos[modelo] then
		return -- ido, o ya preparado (ChildAdded y el arranque pueden llegar a la vez)
	end
	local rig = Malla3D.preparar(modelo, motores, { mapa = MALLA, cara = CARA, piernas = PIERNAS, cuello = CUELLO })
	local ahora = os.clock()
	bichos[modelo] = {
		modelo = modelo, raiz = raiz, cabeza = cabeza, motores = motores, fase = 0, pisada = 1,
		golpe = -math.huge, desde = 0, avance = 0, ventana = nil, rugido = -math.huge, vida = 0,
		respira = azar:NextNumber(0, 2 * math.pi), exhala = false, peso = azar:NextNumber(0, 2 * math.pi),
		cab = Vector3.new(-0.05, 0, LADEO), meta = Vector3.new(-0.05, 0, LADEO), mira = nil, tiron = ahora + 1, teVe = nil,
		crispa = { -math.huge, -math.huge }, proximaCrispa = ahora + rango(CRISPA),
		sacudida = -math.huge, proximaSacudida = ahora + rango(SACUDIDA),
		gateo = 0, gatea = nil, susto = nil, sucesos = {}, agacha = 0, offCara = FRENTE_CARA, codos = prepararCodos(rig),
		planos = {},
		codo = { [-1] = 0, [1] = 0 }, mesa = nil, mesaHasta = 0, aparta = { 0, 0 }, aparta2 = { 0, 0 },
		aturde = 0, rig = rig,
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

-- El susto al morir (ver SUSTO; si te pilló gateando, te arrastra y lo hace en el suelo). Devuelve el Golpeador cerca
-- de `punto` (tu cabeza), si hay.
-- `modelo`: el que te pilla (lo trae el remote Muerte; si no es un Golpeador, nada); sin él, el más cerca de `punto`.
function GolpeadorVista.rugir(punto: Vector3, modelo: Model?): Model?
	local b = if modelo then bichos[modelo] else cercano(punto, 12)
	if b then
		local ahora = os.clock()
		b.rugido = ahora
		olvidarSucesos(b) -- (en un suceso no mata, pero por si acaso)
		b.susto = {
			t0 = ahora, gatea = b.modelo:GetAttribute("Gatea") ~= nil or (b.gatea ~= nil and b.gateo > 0.5),
			mirar = punto, dir = nil, fase = "Mira", u = 0, tir = Vector3.zero, meta = Vector3.zero, proximo = ahora, w = 0,
		}
		return b.modelo
	end
	return nil
end

-- Un toque del dedo en el cristal (Llama; remote Golpeador "Toque", justo cuando toca): en el bicho que llama a `el`
-- (la ventana o la puerta), el dedo se pega al cristal y suena el toque.
local function toque(el: Instance?)
	local donde = nil
	if typeof(el) == "Instance" then
		local centro = el:GetAttribute("Centro")
		if typeof(centro) == "CFrame" then
			donde = centro.Position
		elseif el:IsA("BasePart") then
			donde = el.Position
		elseif el:IsA("Model") then
			donde = el:GetPivot().Position
		end
	end
	local suyo, distancia = nil, 15
	for _, b in bichos do
		local r = b.sucesos.Llama
		if r and r.activo then
			local d = if donde then (r.mira - donde).Magnitude else 0
			if d < distancia then
				suyo, distancia = r, d
			end
		end
	end
	local punto = if suyo then suyo.mira + Vector3.new(0, SUCESO.Llama.Alto, 0) else donde
	if suyo then
		suyo.golpe = os.clock()
	end
	if not punto then
		return
	end
	if Sonido.hay("ToqueDedo") then
		Sonido.en("ToqueDedo", punto)
	else
		-- Mientras falta: el tic del reloj, más grave y fuerte, suena a una uña contra el cristal.
		local s = Sonido.en("Tic", punto, 0.8)
		s.Volume *= 2
		s.RollOffMaxDistance = Config.Sonidos.ToqueDedo.Alcance or 60
	end
end

function GolpeadorVista.start()
	local carpeta = workspace:WaitForChild("Bichos")
	carpeta.ChildAdded:Connect(preparar)
	for _, modelo in carpeta:GetChildren() do
		task.spawn(preparar, modelo)
	end
	Remotes.Golpeador.OnClientEvent:Connect(function(tipo: string, el: Model)
		if tipo == "Toque" then
			toque(el)
			return
		end
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
