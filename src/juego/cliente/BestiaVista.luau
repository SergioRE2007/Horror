-- Mueve el cuerpo de la Bestia en el cliente y hace sus ruidos (el servidor la mueve y avisa con el remote Bestia).
-- Todo con la Transform de sus Motor6D: no toca lo que hace el servidor ni la física.
--   Anda a cuatro patas, pesada: cada pisada suena grave y, cerca, tiembla la cámara. La cabeza da tirones bruscos de
--   un lado a otro. Herida (atributo "Cojea", hora del servidor): arrastra la pata de atrás derecha, el cuerpo se le
--   vence a ese lado y le sale humo de la quemadura.
--   "Ruge": se levanta sobre las patas de atrás con la boca abierta. "Golpe": se alza y descarga los brazos (contra la
--   puerta o la reja). "Herida": se encoge, chilla y ruge. "Atrapada": ruge de rabia. "Flash": aparta la cara.
--   "Arana": bajo la trampilla, de pie, araña el hueco hacia arriba (garras, polvo y astillas, rugidos).
--   "Quema": arde entera, se retuerce y chilla largo hasta que el servidor la quita.
--   Viva (pedido por el usuario: los bichos con vida mientras esperan), cerca de la cámara: respira pesada (coge aire
--   despacio y el lomo sube; lo suelta de golpe resoplando: cabezada, la boca entreabierta y, de noche, vaho) y tiembla
--   entera; herida o encerrada, más deprisa y más fuerte. Parada o despacio, además: carga el peso de un brazo al otro
--   (el libre se levanta un poco), olfatea a golpes cortos con la cabeza alta, se le crispa algún músculo y gruñe bajo
--   de vez en cuando. Con Rendimiento, nada de eso (como antes: solo respira un poco).
--   Gatea (atributos Gatea y GateaHora en su modelo, del servidor): a por quien se esconde debajo de un mueble. Se
--   echa atrás, se aplasta fuera del borde y mete por debajo la cabeza, ladeada y mirándote, y el brazo derecho, que
--   barre el suelo de lado a tirones hasta pasarte las garras al lado (ver "gatear", abajo).
-- BestiaVista.rugir(punto): para el susto al morir (como los demás bichos).
-- Un solo bucle (Stepped) mientras haya alguna; el temblor de la cámara, atado solo mientras tiembla y nunca con la
-- cámara en Scriptable (cinemáticas, escondite, mirilla).
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sonido = require(script.Parent.Sonido)

local BestiaVista = {}

local ALTURA = Config.Bestia.Altura -- de los pies al centro de la raíz

-- Números visuales de estar viva (a ojo; se retocan en Studio).
local LEJOS = 250 -- studs de la cámara: más lejos no se anima
local CERCA = 120 -- más lejos, sin la vida (respirar fuerte, temblar, resoplar...)
local VAHO_LEJOS = 60 -- studs: más lejos no se le ve el vaho
local RESOPLA_LEJOS = 40 -- studs: más lejos no se le oye resoplar ni gruñir
local MOTORES = { "Lomo", "Cabeza", "Mandibula", "BrazoI", "BrazoD", "PiernaI", "PiernaD" }
local RESPIRA = 2.6 -- segundos por respiración, parada (coge aire despacio y lo suelta de golpe)
local COGE = 0.62 -- parte de la respiración que tarda en coger aire
local ALTERADA = 0.7 -- herida o encerrada, cada respiración dura esto (más deprisa)
local HINCHA = 0.04 -- radianes que sube el lomo de los pulmones vacíos a llenos (los nudillos apenas se levantan)
local RESOPLIDO = 0.5 -- segundos de la cabezada al resoplar
local RESOPLA_SUENA = 0.6 -- de los resoplidos, la parte que se oye (herida o encerrada, todos)
local TIEMBLA = 0.012 -- radianes de temblor de los músculos...
local TIEMBLA_ALTERADA = 2.5 -- ...por esto herida o encerrada
local PESO = { 2.5, 5 } -- segundos entre cambios de peso de un brazo al otro
local PESO_LADEA = 0.035 -- radianes que se ladea el lomo al cargar el peso (sube el hombro del brazo libre)
local HOMBRO = 2.5 -- studs de la línea del lomo a cada hombro (Bestia.luau: los brazos en x = ±2,5)
-- Los hombros vistos desde la junta del lomo (Bestia.luau: C1 del lomo y C0 de los brazos). Respirar, temblar y
-- crisparse giran el lomo sobre ellos: sube y baja la espalda y los nudillos se quedan en el suelo.
local HOMBROS = CFrame.new(0, 1.6, -5.3)
local OLFATEA = { 4, 8 } -- segundos entre olfateos
local OLFATEO = 0.9 -- segundos que dura un olfateo (cuatro golpes de nariz)
local CRISPA = { 1.2, 3.5 } -- segundos entre crispaciones
local PARTES = { "Lomo", "BrazoI", "BrazoD", "PiernaI", "PiernaD", "Cabeza" } -- las que se crispan
local GRUNE = { 7, 13 } -- segundos entre gruñidos bajos (además de los resoplidos)
local GRUNE_DURA = 1.6 -- segundos de cada gruñido
-- Gatear a por quien se esconde debajo de un mueble (studs y radianes, a ojo; el tiempo, en parte de
-- Config.Postura.Gatear). Todo en un suelo G bajo la raíz, -z hacia ti.
local GATEAR = Config.Postura.Gatear -- segundos que dura (desde GateaHora)
local GATEO = {
	Cae = 0.6, -- segundos en aplastarse (los tres tramos)...
	Vuelve = 0.9, -- ...y en levantarse si no te pilla (los mismos, al revés)
	Tramos = { 0.3, 0.65 }, -- dónde acaba cada tramo (parte de la mezcla): atrás arriba, bajar fuera del borde, meterse
	Sube = 0.4, -- al echarse atrás da un salto de esto (y se aparta lo justo para que nada alto le quede sobre el mueble)
	Holgura = 0.9, -- al echarse atrás, lo alto, a esto por fuera del borde (y se queda así hasta que echa a andar)
	Tirones = { 0.18, 0.36, 0.64, 0.84 }, -- cuándo da cada tirón hacia ti...
	Tiron = 0.1, -- ...y lo que dura cada uno
	Olfatea = { 0.47, 0.62 }, -- la parada de olfatear
	Alto = 2.85, -- sin tablero que choque: a esta altura (la mesa del comedor)
	Lomo = 1.6, -- alto del centro del lomo, plano (fuera del mueble: no cabe)
	Margen = 0.9, -- el frente del lomo, a esto por fuera del borde (del que choca: el que se ve sale hasta 0,65 más)...
	Hasta = 3.8, -- ...y a esto de ti como mucho (la cara, a ~1 de ti)
	Avanza = 1.3, -- lo que avanza a tirones
	Bajo = 2.7, -- con menos hueco no mete la cabeza...
	Fuera = 3.7, -- ...y el frente del lomo se queda a esto del borde (la cabeza, fuera del que se ve); también al bajar
	Cabeza = 1.3, -- el centro de la cabeza, a esto por delante del frente del lomo (y su cara, 1,52 más allá)...
	CabezaX = -0.5, -- ...y a esto de lado (a la izquierda: deja sitio al brazo derecho)
	Ladeo = math.pi / 2, -- radianes: la cabeza de lado del todo (así cabe y la boca se abre de lado, sin dar en el suelo)
	Suelo = 0.08, -- lo más bajo de la cabeza y la boca, a esto del suelo (como poco)...
	Techo = 0.08, -- ...y lo más alto, a esto del tablero
	Boca = 0.55, -- radianes: lo más que abre la boca
	Baja = 0.18, -- radianes que bajan los brazos desde el hombro (la mano, a ras de suelo)
	Barre = 0.95, -- radianes: el brazo derecho entra abierto hacia fuera y barre hacia ti...
	Pasa = 1.6, -- ...hasta pasar a esto de ti (y las garras, como poco, también)
	Abierto = 1.45, -- radianes: al bajar fuera del borde, el brazo derecho de lado (fuera del mueble)
	AbreI = 1, -- radianes: el brazo izquierdo, desde atrás hacia fuera (empuja en cada tirón)
	Patas = 0.5, -- radianes que abre las patas de atrás (hacia atrás, a ras de suelo)
}
-- Medidas del cuerpo (servidor/Bestia.luau): del centro del lomo a su frente y a cada cadera (las patas, en x = ±).
local LOMO_FRENTE = 3.1
-- La punta de las garras del brazo, desde el hombro: a lo largo del brazo y hacia dentro (su -Z).
local GARRAS = Vector2.new(7.12, 1.52)
local CADERA = Vector3.new(1.9, -0.4, 2.5)
-- Lo que abulta la cabeza (su caja, la frente, los colmillos y los dientes de arriba) y la mandíbula (su caja y los
-- dientes de abajo), en el espacio de cada pieza: sus esquinas.
local PUNTOS_CABEZA: { Vector3 } = {}
local PUNTOS_BOCA: { Vector3 } = {}
do
	local function esquinas(en: { Vector3 }, centro: CFrame, tam: Vector3)
		for _, x in { -1, 1 } do
			for _, y in { -1, 1 } do
				for _, z in { -1, 1 } do
					table.insert(en, centro * Vector3.new(x * tam.X / 2, y * tam.Y / 2, z * tam.Z / 2))
				end
			end
		end
	end
	esquinas(PUNTOS_CABEZA, CFrame.identity, Vector3.new(2.2, 1.8, 2.8))
	esquinas(PUNTOS_CABEZA, CFrame.new(0, 0.85, -0.55), Vector3.new(2.4, 0.5, 1.6))
	for _, lado in { -1, 1 } do
		esquinas(PUNTOS_CABEZA, CFrame.new(lado * 1.0, -0.75, -1.3) * CFrame.Angles(0.2, 0, lado * 0.25), Vector3.new(0.18, 1.1, 0.16))
	end
	esquinas(PUNTOS_CABEZA, CFrame.new(0, -0.625, -1.46), Vector3.new(1.8, 0.75, 0.12))
	esquinas(PUNTOS_BOCA, CFrame.identity, Vector3.new(2, 0.55, 2.6))
	esquinas(PUNTOS_BOCA, CFrame.new(0, 0.625, -1.32), Vector3.new(1.8, 0.75, 0.12))
end
-- Lo que abulta cada brazo (con el hombro, la mano y las garras) y cada pata (con el muslo y el pie): una caja, en el
-- espacio de la pieza. Al moverse, que nada de eso baje del suelo.
local CAJA_BRAZO = { CFrame.new(0, -0.3, -0.38), Vector3.new(1.6, 7.6, 2.35) }
local CAJA_PATA = { CFrame.new(0, 0.07, -0.3), Vector3.new(1.6, 4.65, 2.6) }

type Gateo = {
	punto: Vector3, -- Gatea: dónde está el jugador debajo (mundo)
	hora: number, -- GateaHora (hora del servidor)
	inicio: number, -- os.clock en que empezó aquí
	borde: number, -- studs (en planta) de la raíz al borde del mueble, hacia el jugador
	alto: number, -- studs del suelo a lo de abajo del tablero
	pata: number, -- studs (en planta) de la raíz a lo primero que choca a la altura de la cabeza (una pata, la viga)
	mezcla: number, -- 0..1: por dónde va del camino de aplastarse (lineal; cada tramo se suaviza al usarla)
	fin: number?, -- os.clock en que se quitó Gatea
	k: number, -- 0..1: por dónde va (se queda donde estaba al acabar)
	tirones: number, -- tirones que ya han sonado
	cayo: boolean, -- ya ha sonado el golpe al aplastarse
	atras: number, -- studs que se aparta al echarse atrás (0: nada alto le queda sobre el mueble)
	olio: boolean, -- ya ha resoplado al olfatear
	colgantes: { BasePart }, -- los chorretones que cuelgan (se esconden aplastada: si no, atravesarían el suelo)
	pose: { [string]: CFrame },
	abajo: { [string]: CFrame }, -- la pose al bajar fuera del borde (en G)...
	dentro: { [string]: CFrame }, -- ...y metida (en G)
}

type Bicho = {
	modelo: Model,
	raiz: BasePart,
	cabeza: BasePart,
	motores: { [string]: Motor6D },
	fase: number,
	pisada: number,
	rugido: number, -- os.clock de cada cosa que le pasa
	golpe: number,
	herida: number,
	flash: number,
	quema: number,
	arana: number, -- bajo la trampilla: se alza y araña hacia arriba
	giro: Vector3, -- la cabeza ahora (cabeceo, giro, ladeo) y a dónde da el próximo tirón
	meta: Vector3,
	tiron: number,
	humo: Smoke?,
	semilla: number,
	quietud: number, -- 0..1, suave: 1 = parada (o muy despacio)
	calma: number, -- 0..1, suave: 1 = viva y sin otra cosa que hacer (ni rugir, ni golpear, ni arañar...)
	aliento: number, -- respiraciones que lleva (la parte decimal: por dónde va la de ahora)
	ciclo: number, -- respiración en la que va (al cambiar, suelta el aire y resopla)
	resopla: number, -- os.clock del último resoplido...
	soplo: number, -- ...y de su segunda bocanada de vaho
	peso: number, -- -1..1: sobre qué brazo carga (suave; + el izquierdo)
	pesoMeta: number,
	proximoPeso: number,
	olfatea: number,
	proximoOlfateo: number,
	olfateado: number, -- cuántos golpes de nariz lleva este olfateo (un poco de vaho en cada uno)
	crispa: number,
	crispaParte: string,
	crispaEje: Vector3,
	proximaCrispa: number,
	grunido: number, -- os.clock del último gruñido
	proximoGrunido: number,
	vaho: ParticleEmitter?,
	c0: { [string]: CFrame },
	c0i: { [string]: CFrame },
	c1: { [string]: CFrame },
	c1i: { [string]: CFrame },
	pose: { [string]: CFrame }, -- la pose de siempre (Transform de cada motor) antes de poner la de gatear encima
	gateo: Gateo?,
	pilla: number, -- os.clock de la última vez que te pilló (rugir)
}
local jugador = Players.LocalPlayer
local bichos: { [Model]: Bicho } = {}
local azar = Random.new()
local conexion: RBXScriptConnection? = nil
local temblor = 0 -- fuerza del temblor de la cámara (baja sola)
local temblando = false -- los dos pasos del temblor están atados
local aplicado: CFrame? = nil -- el giro del temblor puesto en este fotograma (se deshace en el siguiente)

local function rango(r: { number }): number
	return azar:NextNumber(r[1], r[2])
end

-- Suave al empezar y al acabar.
local function suave(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

-- Deja de gatear del todo: los chorretones vuelven a verse.
local function terminarGateo(b: Bicho)
	local g = b.gateo
	if not g then
		return
	end
	for _, pieza in g.colgantes do
		pieza.LocalTransparencyModifier = 0
	end
	b.gateo = nil
end

local function olvidar(modelo: Model)
	local b = bichos[modelo]
	if b then
		terminarGateo(b)
		if b.vaho and b.vaho.Parent then
			(b.vaho.Parent :: Instance):Destroy()
		end
		bichos[modelo] = nil
	end
end

local function puedeVaho(distancia: number): boolean
	return distancia < VAHO_LEJOS and workspace:GetAttribute("Fase") == "Noche" and jugador:GetAttribute("Rendimiento") ~= true
end

-- Vaho caliente por la boca: más grande que el de las personas (las partículas se quedan donde salen).
local function vahoDe(b: Bicho): ParticleEmitter
	if b.vaho and b.vaho.Parent then
		return b.vaho
	end
	local a = Instance.new("Attachment")
	a.Name = "Vaho"
	a.Position = Vector3.new(0, -0.55, -1.6) -- delante de la boca
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.LightInfluence = 1 -- de noche, apenas: solo se ve con la linterna
	e.Color = ColorSequence.new(Color3.fromRGB(215, 220, 228))
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1.8) })
	e.Lifetime = NumberRange.new(1.2, 2)
	e.Speed = NumberRange.new(1.5, 2.6)
	e.SpreadAngle = Vector2.new(25, 25)
	e.EmissionDirection = Enum.NormalId.Front
	e.Acceleration = Vector3.new(0, 0.8, 0)
	e.Drag = 1.8
	e.Rate = 0
	e.Parent = a
	a.Parent = b.cabeza
	b.vaho = e
	return e
end

-- Resopla (o gruñe bajo, `grave`): el resoplido propio si algún día se hace (Config.Sonidos.Resoplido, con
-- ElevenLabs); mientras, el rugido muy grave, flojo y cortado.
local function resoplido(b: Bicho, grave: boolean)
	local boca = b.cabeza.Position
	if not grave and Sonido.hay("Resoplido") then
		Sonido.en("Resoplido", boca, azar:NextNumber(0.9, 1.05)).RollOffMinDistance = 8
		return
	end
	local s = Sonido.en("Rugido", boca, azar:NextNumber(0.36, 0.42))
	s.Volume *= if grave then 0.22 else 0.12
	s.RollOffMinDistance = 8
	local dura = if grave then GRUNE_DURA else 0.6
	TweenService:Create(s, TweenInfo.new(dura * 0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, dura * 0.4),
		{ Volume = 0 }):Play()
	task.delay(dura + 0.1, s.Stop, s)
end

-- Temblor de la cámara (pisadas, golpes, rugidos): después de la cámara normal, y baja solo. El giro de cada fotograma
-- se deshace antes de la cámara de Roblox, que sigue desde donde quedó: si no, se iría sumando y la mirada se quedaría
-- desviada tras cada golpe (como la inclinación de MochilaUi). Los dos pasos solo están atados mientras tiembla.
local function deshacerTemblor()
	local camara = workspace.CurrentCamera
	if aplicado then
		-- Se deshace siempre, también si la cámara acaba de pasar a Scriptable con el giro puesto (si no, se quedaba ahí).
		-- En Scriptable ya no se pone otro (aplicarTemblor): esto solo pasa una vez, al cambiar.
		if camara then
			camara.CFrame *= aplicado:Inverse()
		end
		aplicado = nil
	end
	if temblor < 0.002 then
		temblando = false
		RunService:UnbindFromRenderStep("BestiaTemblorAntes")
		RunService:UnbindFromRenderStep("BestiaTemblor")
	end
end

local function aplicarTemblor(dt: number)
	local camara = workspace.CurrentCamera
	if temblor < 0.002 or not camara then
		return
	end
	if camara.CameraType ~= Enum.CameraType.Scriptable then
		local t = os.clock() * 40
		local giro = CFrame.Angles(math.noise(t, 1) * temblor * 0.25, math.noise(t, 2) * temblor * 0.25,
			math.noise(t, 3) * temblor * 0.15)
		camara.CFrame *= giro
		aplicado = giro
	end
	temblor = math.max(0, temblor - dt * 0.8)
end

local function temblar(desde: Vector3, fuerza: number, alcance: number)
	local d = (workspace.CurrentCamera.CFrame.Position - desde).Magnitude
	if d >= alcance then
		return
	end
	temblor = math.max(temblor, fuerza * (1 - d / alcance))
	if temblor >= 0.002 and not temblando then
		temblando = true
		RunService:BindToRenderStep("BestiaTemblorAntes", Enum.RenderPriority.Camera.Value - 1, deshacerTemblor)
		RunService:BindToRenderStep("BestiaTemblor", Enum.RenderPriority.Camera.Value + 1, aplicarTemblor)
	end
end

-- Se alza (0..0,3 s), descarga los brazos de golpe (0,3..0,42) y vuelve. Devuelve (brazos, torso).
local function curvaGolpe(t: number): (number, number)
	if t < 0.3 then
		local k = t / 0.3
		return 2.2 * k, 0.4 * k
	elseif t < 0.42 then
		local k = (t - 0.3) / 0.12
		return 2.2 - 1.8 * k, 0.4 - 0.55 * k
	elseif t < 1 then
		local k = 1 - (t - 0.42) / 0.58
		return 0.4 * k, -0.15 * k
	end
	return 0, 0
end

local function prender(pieza: BasePart, tamano: number)
	local fuego = Instance.new("Fire")
	fuego.Size = tamano
	fuego.Heat = 12
	fuego.Color = Color3.fromRGB(236, 120, 40)
	fuego.SecondaryColor = Color3.fromRGB(120, 30, 10)
	fuego.Parent = pieza
	local humo = Instance.new("Smoke")
	humo.Color = Color3.fromRGB(30, 28, 26)
	humo.Opacity = 0.35
	humo.RiseVelocity = 6
	humo.Size = tamano * 0.6
	humo.Parent = pieza
end

-- El respingo de una crispación (`k` 0..1), si le toca a esa parte.
local function respingo(b: Bicho, parte: string, k: number): CFrame
	if k <= 0 or parte ~= b.crispaParte then
		return CFrame.identity
	end
	local e = b.crispaEje * k
	return CFrame.Angles(e.X, e.Y, e.Z)
end

---------------------------------------------------------------- gatear

-- Pedido por el usuario (03-11-2026): agachado debajo de un mueble te escondes, y si un bicho te huele gatea a por ti.
-- El servidor le pone Gatea (dónde estás debajo) y GateaHora (cuándo empezó) mientras dura (Config.Postura.Gatear);
-- luego te pilla o lo deja, y los quita. La Bestia es enorme (de pie, la cara le queda 5,6 por delante y metería la
-- cabeza por el tablero): se echa atrás arriba, baja fuera del borde y se mete a ras de suelo. Aplastada, el lomo
-- plano fuera del mueble (no cabe); por debajo entran la cabeza, de lado del todo y mirándote (así cabe y abre la boca
-- de lado sin dar en el suelo), y el brazo derecho, que barre el suelo de lado hacia ti a tirones, con una parada de
-- olfatear, hasta pasarte las garras al lado. Si el hueco es muy bajo, solo entra el brazo.

local techo = RaycastParams.new()
techo.FilterType = Enum.RaycastFilterType.Exclude
techo.RespectCanCollide = true -- la zona invisible de debajo del tablero no cuenta: solo lo que choca

local function plano(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- 0..1: lo que ha avanzado a los `k` (parte del tiempo): a tirones.
local function tirones(k: number): number
	local p = 0
	for _, t0 in GATEO.Tirones do
		p += suave((k - t0) / GATEO.Tiron)
	end
	return p / #GATEO.Tirones
end

-- 0..1 dentro del tirón que esté dando, o -1 si no da ninguno.
local function enTiron(k: number): number
	for _, t0 in GATEO.Tirones do
		local u = (k - t0) / GATEO.Tiron
		if u >= 0 and u < 1 then
			return u
		end
	end
	return -1
end

-- El borde del mueble entre la raíz y `punto` (en planta, desde la raíz) y lo alto de su hueco: rayos hacia arriba
-- cada medio stud, por el medio y a cada lado (lo que mete: la cabeza y el brazo). Sin nada que choque, a ojo. Y lo
-- primero que choca a lo ancho de la cabeza hacia ti (las patas de la mesa, la viga de la de la cocina): rayos de lado.
local function medirMueble(b: Bicho, punto: Vector3): (number, number, number)
	local suelo = b.raiz.Position - Vector3.new(0, ALTURA, 0)
	local hacia = plano(punto - suelo)
	local largo = hacia.Magnitude
	if largo < 0.5 then
		return 0, GATEO.Alto, math.huge
	end
	local ignorar: { Instance } = {}
	if b.modelo.Parent then
		table.insert(ignorar, b.modelo.Parent :: Instance) -- todos los bichos
	end
	for _, otro in Players:GetPlayers() do
		if otro.Character then
			table.insert(ignorar, otro.Character)
		end
	end
	techo.FilterDescendantsInstances = ignorar
	local u = hacia.Unit
	local lado = u:Cross(Vector3.yAxis)
	-- El borde más cercano (por si la mesa está torcida) y el hueco más bajo.
	local borde, alto = math.huge, math.huge
	for _, x in { 0, -1.5, 1.5, -3, 3 } do -- (a ±3, lo ancho del lomo y los hombros)
		local function arriba(d: number): RaycastResult?
			return workspace:Raycast(suelo + u * d + lado * x + Vector3.new(0, 0.2, 0), Vector3.new(0, 4.3, 0), techo)
		end
		for d = 0, math.min(largo, borde), 0.5 do
			local r = arriba(d)
			if r then
				-- Afinado entre el último rayo que no dio y este (a unos 3 cm).
				local fuera, dentro, h = d - 0.5, d, r.Position.Y - suelo.Y
				if d > 0 then
					for _ = 1, 4 do
						local medio = (fuera + dentro) / 2
						local otro = arriba(medio)
						if otro then
							dentro, h = medio, otro.Position.Y - suelo.Y
						else
							fuera = medio
						end
					end
				end
				borde, alto = math.min(borde, dentro), math.min(alto, h)
				break
			end
		end
	end
	local pata = math.huge
	for _, x in { GATEO.CabezaX - 1.3, GATEO.CabezaX, GATEO.CabezaX + 1.3 } do
		for _, y in { 0.5, 1.4, 2.3 } do
			local r = workspace:Raycast(suelo + lado * x + Vector3.new(0, y, 0), u * largo, techo)
			if r then
				pata = math.min(pata, plano(r.Position - suelo):Dot(u))
			end
		end
	end
	if borde == math.huge then
		return math.max(0, largo - 2.5), GATEO.Alto, pata
	end
	return borde, math.max(1, alto), pata
end

-- CFrame con su eje Y hacia `y` y su Z lo más hacia `z`.
local function ejes(pos: Vector3, y: Vector3, z: Vector3): CFrame
	local x = y:Cross(z)
	if x.Magnitude < 1e-3 then
		x = y:Cross(Vector3.xAxis)
	end
	return CFrame.fromMatrix(pos, x.Unit, y)
end

-- Giro mirando hacia `v` (en planta).
local function haciaPlano(v: Vector3): CFrame
	local f = plano(v)
	if f.Magnitude < 1e-3 then
		return CFrame.identity
	end
	f = f.Unit
	return CFrame.fromMatrix(Vector3.zero, f:Cross(Vector3.yAxis), Vector3.yAxis)
end

-- Lo más bajo y lo más alto de la cabeza girada `giro` (desde su centro) con la boca abierta `boca`.
local function alturas(b: Bicho, giro: CFrame, boca: number): (number, number)
	local lo, hi = math.huge, -math.huge
	for _, q in PUNTOS_CABEZA do
		local y = (giro * q).Y
		lo, hi = math.min(lo, y), math.max(hi, y)
	end
	local mandibula = giro * b.c0.Mandibula * CFrame.Angles(-boca, 0, 0) * b.c1i.Mandibula
	for _, q in PUNTOS_BOCA do
		local y = (mandibula * q).Y
		lo, hi = math.min(lo, y), math.max(hi, y)
	end
	return lo, hi
end

type Momento = {
	D: number, -- studs (en planta) de la raíz a ti
	E: number, -- y al borde
	techo: number, -- lo más alto que puede llegar la cabeza (el tablero menos un poco; sin tablero encima, sin tope)
	tiron: number, -- 0..1..0 mientras da un tirón
	olfa: number, -- 0..1 en la parada de olfatear
	boca: number, -- lo que querría abrir la boca
	blanco: Vector3, -- a dónde mira (en G)
	ruido: CFrame, -- temblor de la cabeza
}

-- Aplastada con el frente del lomo a `frente` studs hacia ti y el brazo derecho abierto `barre` radianes hacia fuera:
-- el CFrame de cada pieza (en G) en `en`. Devuelve lo que abre la boca (sin dar en el suelo ni en el tablero).
local function aplastada(b: Bicho, c: Momento, en: { [string]: CFrame }, frente: number, barre: number): number
	-- El lomo plano, a ras de suelo; empuja un poco hacia arriba en cada tirón.
	local lomo = CFrame.new(0, GATEO.Lomo + 0.06 * c.tiron, -(frente - LOMO_FRENTE))
	en.Lomo = lomo
	-- El brazo derecho: del hombro hacia delante, bajando, abierto `barre` hacia fuera; su Z hacia fuera (las garras
	-- miran hacia dentro: barren de lado, no contra el suelo).
	local h = Vector3.new(math.sin(barre), 0, -math.cos(barre))
	local d = h * math.cos(GATEO.Baja) - Vector3.yAxis * math.sin(GATEO.Baja)
	en.BrazoD = ejes(lomo * b.c0.BrazoD.Position + d * b.c1.BrazoD.Position.Y, -d, Vector3.new(-h.Z, 0, h.X))
	-- El izquierdo, abierto hacia atrás y fuera, con la mano en el suelo (empuja en cada tirón).
	local a = GATEO.AbreI + 0.2 * c.tiron
	local hI = Vector3.new(-math.sin(a), 0, math.cos(a))
	local dI = hI * math.cos(GATEO.Baja) - Vector3.yAxis * math.sin(GATEO.Baja)
	en.BrazoI = ejes(lomo * b.c0.BrazoI.Position + dI * b.c1.BrazoI.Position.Y, -dI, Vector3.new(hI.Z, 0, -hI.X))
	-- Las patas de atrás, abiertas hacia atrás a ras de suelo (el pie de adorno, hacia arriba).
	for nombre, lado in { PiernaI = -1, PiernaD = 1 } do
		local cadera = lomo * Vector3.new(lado * CADERA.X, CADERA.Y, CADERA.Z)
		local v = Vector3.new(lado * math.sin(GATEO.Patas), -0.05, math.cos(GATEO.Patas)).Unit
		en[nombre] = ejes(cadera + v * b.c1[nombre].Position.Y, -v, Vector3.new(0, -1, 0))
	end
	-- La cabeza delante del pecho, de lado del todo y mirándote, a ras de suelo (sube un poco al olfatear, si cabe); la
	-- boca, lo que quepa.
	local centro = Vector3.new(GATEO.CabezaX, 0, -(frente + GATEO.Cabeza))
	local giro = haciaPlano(c.blanco - centro) * CFrame.Angles(0, 0, -GATEO.Ladeo) * c.ruido
	local boca = c.boca
	local lo, hi = alturas(b, giro, boca)
	local cabe = c.techo - GATEO.Suelo
	if hi - lo > cabe then
		local cerrada, abierta = 0, boca
		for _ = 1, 8 do
			local medio = (cerrada + abierta) / 2
			local l, h2 = alturas(b, giro, medio)
			if h2 - l > cabe then
				abierta = medio
			else
				cerrada = medio
			end
		end
		boca = cerrada
		lo, hi = alturas(b, giro, boca)
	end
	local y = math.max(GATEO.Suelo - lo, math.min(GATEO.Suelo - lo + 0.12 + 0.1 * c.olfa, c.techo - hi))
	en.Cabeza = CFrame.new(centro.X, y, centro.Z) * giro
	return boca
end

-- Lo más adelantado (hacia ti, en G) de la caja `cf` (espacio de la raíz) por encima de `h`: sus esquinas de arriba y
-- donde sus aristas cruzan esa altura.
local function delanteDe(G: CFrame, cf: CFrame, tam: Vector3, h: number): number
	local q = table.create(8)
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				table.insert(q, G:PointToObjectSpace(cf * Vector3.new(x * tam.X / 2, y * tam.Y / 2, z * tam.Z / 2)))
			end
		end
	end
	local mejor = -math.huge
	for i = 1, 8 do
		local a = q[i]
		if a.Y >= h then
			mejor = math.max(mejor, -a.Z)
		end
		for _, paso in { 1, 2, 4 } do -- la esquina vecina en cada eje
			if (i - 1) // paso % 2 == 0 then
				local o = q[i + paso]
				if (a.Y - h) * (o.Y - h) < 0 then
					mejor = math.max(mejor, -(a.Z + (o.Z - a.Z) * (h - a.Y) / (o.Y - a.Y)))
				end
			end
		end
	end
	return mejor
end

local PIEZAS = { "Lomo", "Cabeza", "BrazoD", "BrazoI", "PiernaI", "PiernaD" }

-- Lo más bajo de la caja `caja` (centro y tamaño, en el espacio de la pieza `cf`).
local function masBajo(cf: CFrame, caja: { any }): number
	local centro, tam = cf * (caja[1] :: CFrame), caja[2] :: Vector3
	return centro.Y - (math.abs(centro.XVector.Y) * tam.X + math.abs(centro.YVector.Y) * tam.Y
		+ math.abs(centro.ZVector.Y) * tam.Z) / 2
end

-- La pose de gatear en `g.pose` (Transform de cada motor), mezclada con la de siempre (b.pose) por el camino de tres
-- tramos (`mezcla` 0..1): atrás arriba (lo justo para que nada alto quede sobre el mueble), bajar fuera del borde y
-- meterse a ras de suelo. Cada pieza va en línea recta en cada tramo (en el espacio de la raíz).
local function poseGateo(b: Bicho, g: Gateo, ahora: number, ojo: Vector3, adornos: boolean, chillando: boolean, mezcla: number)
	local raiz = b.raiz.CFrame
	local suelo = raiz.Position - Vector3.new(0, ALTURA, 0)
	local haciaW = plano(g.punto - suelo)
	local fW = if haciaW.Magnitude > 0.1 then haciaW.Unit else plano(raiz.LookVector).Unit
	local f = raiz:VectorToObjectSpace(fW)
	f = Vector3.new(f.X, 0, f.Z).Unit
	local G = CFrame.fromMatrix(Vector3.new(0, -ALTURA, 0), f:Cross(Vector3.yAxis), Vector3.yAxis)
	local D, E, k = haciaW.Magnitude, g.borde, g.k
	local p, u = tirones(k), enTiron(k)
	local tiron = if u >= 0 then math.sin(u * math.pi) else 0
	local olfa = if adornos then math.clamp(math.min((k - GATEO.Olfatea[1]) / 0.03, (GATEO.Olfatea[2] - k) / 0.03), 0, 1) else 0
	local lejosFin = suave((k - 0.93) / 0.2) -- ya ha llegado
	local bajo = g.alto < GATEO.Bajo

	-- Por dónde va el frente del lomo: avanza a tirones hasta el borde (o hasta tenerte cerca); con el hueco bajo, se
	-- queda fuera con la cabeza.
	-- (y la cara, sin llegar a lo que choque a su altura)
	local fin = if bajo then E - GATEO.Fuera else math.min(E - GATEO.Margen, D - GATEO.Hasta, g.pata - 0.2 - GATEO.Cabeza - 1.52)
	local frente = fin - GATEO.Avanza * (1 - p)
	-- El brazo derecho barre de fuera hacia ti hasta pasar a GATEO.Pasa de ti: desde el hombro (a `L` de ti hacia
	-- delante y a `x` de lado), el ángulo en que la recta del brazo pasa a esa distancia.
	local hx = b.c0.BrazoD.Position.X
	local L = D - (frente - LOMO_FRENTE - b.c0.BrazoD.Position.Z)
	local R = math.sqrt(hx * hx + L * L)
	local cierra = math.asin(math.clamp(GATEO.Pasa / R, -1, 1)) - math.atan2(hx, L)
	-- Si así las garras (al final del brazo, hacia dentro) te quedarían más cerca, se abre lo justo para dejarlas a
	-- GATEO.Pasa de ti.
	local ga, gw = GARRAS.X * math.cos(GATEO.Baja), GARRAS.Y
	local rg = math.sqrt(ga * ga + gw * gw)
	local cosMin = (R * R + rg * rg - GATEO.Pasa * GATEO.Pasa) / (2 * R * rg)
	if cosMin < 1 then
		cierra = math.max(cierra, -math.atan2(hx, L) + math.atan2(gw, ga) + math.acos(math.max(-1, cosMin)))
	end
	local barre = GATEO.Barre + (cierra - GATEO.Barre) * p
	if adornos and u < 0 and olfa <= 0 and p > 0 and p < 1 then
		barre += 0.05 * math.sin(ahora * 13) -- araña
	end

	-- Te mira a ti si eres tú el de debajo (la cámara junto a Gatea y a poca altura); si no, a donde está.
	local debajo = plano(ojo - g.punto).Magnitude < 4 and ojo.Y - suelo.Y < 3.5
	local ruido = CFrame.identity
	if adornos then
		-- (con la cabeza de lado, su X queda vertical: tiembla y da golpes de nariz sobre todo hacia los lados; lo demás
		-- la haría más alta y no cabría)
		local t = if chillando then 0.1 else 0.015
		ruido = CFrame.Angles(olfa * math.abs(math.sin(ahora * 22)) * 0.06 + math.noise(ahora * 9, 1) * t,
			math.noise(ahora * 9, 2) * t * 0.2, math.noise(ahora * 9, 3) * t * 0.2)
	end
	local c: Momento = {
		D = D,
		E = E,
		techo = if bajo then math.huge else g.alto - GATEO.Techo,
		tiron = tiron,
		olfa = olfa,
		boca = math.min(GATEO.Boca, 0.08 + 0.2 * p + 0.1 * tiron - 0.08 * olfa + 0.15 * lejosFin
			+ (if chillando then 0.4 + 0.06 * math.sin(ahora * 30) else 0)),
		blanco = if debajo then G:PointToObjectSpace(raiz:PointToObjectSpace(ojo)) else Vector3.new(0, 1, -D),
		ruido = ruido,
	}
	-- El tramo (y solo lo que hace falta para él: echada atrás, ni baja ni se mete).
	local t1, t2 = GATEO.Tramos[1], GATEO.Tramos[2]
	local tramo = if mezcla <= t1 then 1 elseif mezcla < t2 then 2 else 3
	local boca = 0
	if tramo >= 2 then
		boca = aplastada(b, c, g.abajo, math.min(frente, E - GATEO.Fuera), GATEO.Abierto)
	end
	if tramo == 3 then
		boca = aplastada(b, c, g.dentro, frente, barre)
	end

	-- La pose de siempre (cada pieza en el espacio de la raíz) y lo que se aparta al echarse atrás.
	local base, c0, c0i, c1, c1i = b.pose, b.c0, b.c0i, b.c1, b.c1i
	local lomoB = c0.Lomo * base.Lomo * c1i.Lomo
	local cabezaB = lomoB * c0.Cabeza * base.Cabeza * c1i.Cabeza
	local antes = {
		Lomo = lomoB,
		Cabeza = cabezaB,
		BrazoD = lomoB * c0.BrazoD * base.BrazoD * c1i.BrazoD,
		BrazoI = lomoB * c0.BrazoI * base.BrazoI * c1i.BrazoI,
		PiernaI = c0.PiernaI * base.PiernaI * c1i.PiernaI,
		PiernaD = c0.PiernaD * base.PiernaD * c1i.PiernaD,
	}
	local alto = (if bajo then g.alto else math.min(g.alto, GATEO.Alto)) - 0.5
	local delante = -math.huge
	for _, nombre in { "Lomo", "Cabeza", "BrazoD", "BrazoI" } do
		delante = math.max(delante, delanteDe(G, antes[nombre], (b.motores[nombre].Part1 :: BasePart).Size, alto))
	end
	delante = math.max(delante, delanteDe(G, cabezaB * c0.Mandibula * base.Mandibula * c1i.Mandibula,
		(b.motores.Mandibula.Part1 :: BasePart).Size, alto))
	g.atras = math.max(0, delante - (E - GATEO.Holgura))
	local atras = G:VectorToWorldSpace(Vector3.new(0, 0, g.atras))

	-- El camino: atrás arriba, bajar fuera del borde y meterse.
	local s = if tramo == 1 then suave(mezcla / t1) elseif tramo == 2 then suave((mezcla - t1) / (t2 - t1))
		else suave((mezcla - t2) / (1 - t2))
	local res = {}
	for _, nombre in PIEZAS do
		local cf = antes[nombre]
		if tramo == 1 then
			cf = cf:Lerp(cf + atras, s) + Vector3.new(0, GATEO.Sube * math.sin(math.pi * s), 0)
		elseif tramo == 2 then
			cf = (cf + atras):Lerp(G * g.abajo[nombre], s)
			if nombre == "PiernaI" or nombre == "PiernaD" then
				cf += Vector3.new(0, 0.5 * math.sin(math.pi * s), 0) -- como dando el paso: si no, el pie rozaba bajo el suelo
			end
		else
			cf = (G * g.abajo[nombre]):Lerp(G * g.dentro[nombre], s)
		end
		-- Al girar de pie a aplastada, la mano y los pies bajarían del suelo: se levantan lo justo.
		local caja = if nombre == "BrazoD" or nombre == "BrazoI" then CAJA_BRAZO
			elseif nombre == "PiernaI" or nombre == "PiernaD" then CAJA_PATA else nil
		if caja then
			cf += Vector3.new(0, math.max(0, GATEO.Suelo - ALTURA - masBajo(cf, caja)), 0)
		end
		res[nombre] = cf
	end

	-- Las Transform: el lomo y las patas cuelgan de la raíz; la cabeza y los brazos, del lomo.
	local pose = g.pose
	pose.Lomo = c0i.Lomo * res.Lomo * c1.Lomo
	local lomoI = res.Lomo:Inverse()
	pose.Cabeza = c0i.Cabeza * lomoI * res.Cabeza * c1.Cabeza
	pose.BrazoD = c0i.BrazoD * lomoI * res.BrazoD * c1.BrazoD
	pose.BrazoI = c0i.BrazoI * lomoI * res.BrazoI * c1.BrazoI
	pose.PiernaI = c0i.PiernaI * res.PiernaI * c1.PiernaI
	pose.PiernaD = c0i.PiernaD * res.PiernaD * c1.PiernaD
	pose.Mandibula = base.Mandibula:Lerp(CFrame.Angles(-boca, 0, 0), suave(mezcla))
end

-- Al aplastarse, el golpe contra el suelo, un temblor y un gruñido; en cada tirón, las garras en la madera, el mueble
-- que cruje y tiembla un poco (lo empuja); al olfatear, resopla. Con Rendimiento, solo el golpe y las garras.
local function sonidosGateo(b: Bicho, g: Gateo, adornos: boolean, distancia: number)
	if not g.cayo and g.mezcla >= GATEO.Tramos[2] then
		g.cayo = true
		local pies = b.raiz.Position - Vector3.new(0, ALTURA - 0.5, 0)
		local s = Sonido.en("Paso", pies, azar:NextNumber(0.34, 0.38))
		s.Volume *= 1.8
		s.RollOffMinDistance = 15
		temblar(pies, 0.12, 30)
		if adornos then
			resoplido(b, true)
		end
	end
	local hechos = 0
	for _, t0 in GATEO.Tirones do
		if g.k >= t0 then
			hechos += 1
		end
	end
	if hechos > g.tirones then
		g.tirones = hechos
		local mano = b.motores.BrazoD.Part1
		if mano then
			local s = Sonido.en("Aranazo", (mano :: BasePart).CFrame * Vector3.new(0, -3.3, 0), azar:NextNumber(0.8, 0.95))
			s.Volume *= 0.8
			s.RollOffMinDistance = 8
		end
		if adornos then
			local borde = b.raiz.Position + plano(g.punto - b.raiz.Position).Unit * g.borde
			Sonido.en("Cruje", borde, azar:NextNumber(0.8, 1)).Volume *= 0.7
			temblar(borde, 0.04, 20)
		end
	end
	if adornos and not g.olio and g.k >= GATEO.Olfatea[1] then
		g.olio = true
		resoplido(b, false)
		if puedeVaho(distancia) then
			vahoDe(b):Emit(4)
		end
	end
end

-- Los chorretones de sangre que le cuelgan del vientre y de la boca (finos, rojos y largos): aplastada atravesarían el
-- suelo, así que se esconden mientras gatea.
local function colgantesDe(modelo: Model): { BasePart }
	local lista = {}
	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Adorno" and d.Size.X <= 0.15 and d.Size.Z <= 0.12 and d.Size.Y >= 0.5
			and d.Color.R > 0.2 and d.Color.G < 0.05 then
			table.insert(lista, d)
		end
	end
	return lista
end

-- Gatea, GateaHora y por dónde va. Devuelve la mezcla con la que se pinta (0 = nada). Se queda en la pose si te acaba de
-- pillar (rugir lo llama MuerteVista) para que la escena de muerte le vea la cara ahí; si no, se levanta (y se queda
-- echada atrás mientras no ande).
-- `adornos`: cerca y sin Rendimiento (arañar, temblar, olfatear).
local function gatear(b: Bicho, ahora: number, servidor: number, dt: number, ojo: Vector3, adornos: boolean, distancia: number,
	rapidez: number): number
	local modelo = b.modelo
	local punto = modelo:GetAttribute("Gatea")
	local hora = modelo:GetAttribute("GateaHora")
	local g = b.gateo
	if typeof(punto) == "Vector3" then
		local t = if type(hora) == "number" then hora else servidor
		if not g or g.fin or (g.punto - punto).Magnitude > 0.5 or math.abs(g.hora - t) > 0.05 then
			local borde, alto, pata = medirMueble(b, punto)
			if g then
				for _, pieza in g.colgantes do
					pieza.LocalTransparencyModifier = 0
				end
			end
			local nuevo: Gateo = { punto = punto, hora = t, inicio = ahora, borde = borde, alto = alto, pata = pata,
				mezcla = if g then g.mezcla else 0, fin = nil, k = 0, tirones = 0, cayo = g ~= nil and g.mezcla >= 1, atras = 0,
				olio = false, colgantes = colgantesDe(modelo), pose = if g then g.pose else {}, abajo = {}, dentro = {} }
			g = nuevo
			b.gateo = nuevo
		end
	elseif g and not g.fin then
		g.fin = ahora
	end
	if not g then
		return 0
	end
	if not g.fin then
		g.k = math.clamp((servidor - g.hora) / GATEAR, 0, 1)
	end
	local pilla = b.pilla >= g.inicio and ahora - b.pilla < 2.5
	local meta = if not g.fin or pilla then 1 else 0
	-- Al dejarlo se queda echada atrás hasta que echa a andar: de vuelta en su sitio metería los brazos por el tablero.
	if meta == 0 and g.atras > 0.05 and rapidez < 1.5 then
		meta = math.min(g.mezcla, GATEO.Tramos[1])
	end
	g.mezcla = if meta > g.mezcla then math.min(meta, g.mezcla + dt / GATEO.Cae) else math.max(meta, g.mezcla - dt / GATEO.Vuelve)
	if g.fin and g.mezcla <= 0 then
		terminarGateo(b)
		return 0
	end
	local esconde = if g.mezcla > GATEO.Tramos[1] + 0.01 then 1 else 0 -- al bajar
	for _, pieza in g.colgantes do
		pieza.LocalTransparencyModifier = esconde
	end
	poseGateo(b, g, ahora, ojo, adornos, ahora - b.pilla < 2.5, g.mezcla)
	if distancia < CERCA then -- los sonidos, también con Rendimiento: se oye venir
		sonidosGateo(b, g, adornos, distancia)
	end
	return 1
end

---------------------------------------------------------------- cada fotograma

local function animar(dt: number)
	local ahora = os.clock()
	local servidor = workspace:GetServerTimeNow()
	local ojo = workspace.CurrentCamera.CFrame.Position
	local rendimiento = jugador:GetAttribute("Rendimiento") == true
	for modelo, b in bichos do
		if not modelo.Parent or not b.raiz.Parent or not b.cabeza.Parent then
			olvidar(modelo)
			continue
		end
		local m = b.motores
		local pose = b.pose
		local cojea = (modelo:GetAttribute("Cojea") or 0) > servidor
		-- La quemadura humea mientras cojea.
		if cojea and not b.humo then
			local humo = Instance.new("Smoke")
			humo.Color = Color3.fromRGB(45, 42, 40)
			humo.Opacity = 0.25
			humo.RiseVelocity = 4
			humo.Size = 1.5
			humo.Parent = m.PiernaD.Part1
			b.humo = humo
		elseif not cojea and b.humo then
			b.humo.Enabled = false
			Debris:AddItem(b.humo, 3)
			b.humo = nil
		end
		local distancia = (b.raiz.Position - ojo).Magnitude
		if distancia > LEJOS then
			continue
		end
		local v = b.raiz.AssemblyLinearVelocity
		local rapidez = Vector3.new(v.X, 0, v.Z).Magnitude
		local paso = math.min(1, rapidez / 12)
		b.fase += dt * rapidez * 0.3
		local s = math.sin(b.fase)

		local rugiendo = ahora - b.rugido < 2.5
		local quemando = ahora - b.quema < 30
		local brazosG, torsoG = curvaGolpe(ahora - b.golpe)
		local encoge = math.max(0, 1 - (ahora - b.herida) / 0.9)
		local aranando = ahora - b.arana < 1.4 -- cada "Arana" dura 1,4 s y llegan cada 1,2: seguido mientras araña
		local alterada = cojea or modelo:GetAttribute("Atrapada") == true

		-- Viva: cerca, sin Rendimiento y sin arder. Lo de estar parada, además quieta o despacio y sin otra cosa que
		-- hacer; todo suave, para que nada salte al rugir o echar a andar.
		local viva = not rendimiento and distancia < CERCA and not quemando
		local ocupada = rugiendo or aranando or encoge > 0 or ahora - b.golpe < 1 or ahora - b.flash < 0.7
			or (b.gateo ~= nil and (b.gateo.fin == nil or b.gateo.mezcla > GATEO.Tramos[1])) -- gateando, se pausa
		b.quietud += (math.clamp(1 - (rapidez - 2) / 8, 0, 1) - b.quietud) * math.min(1, dt * 2.5)
		b.calma += ((if viva and not ocupada then 1 else 0) - b.calma) * math.min(1, dt * (if ocupada then 8 else 1.5))
		local parada = b.calma * b.quietud

		-- Respira pesada: coge aire despacio (el lomo sube) y lo suelta de golpe. Más deprisa andando, herida o encerrada.
		b.aliento += dt / (RESPIRA * (1 - 0.3 * paso) * (if alterada then ALTERADA else 1))
		local va = b.aliento % 1
		local lleno = if va < COGE then suave(va / COGE) else (1 - (va - COGE) / (1 - COGE)) ^ 2
		local ciclo = math.floor(b.aliento - COGE)
		if ciclo ~= b.ciclo then
			b.ciclo = ciclo
			-- Suelta el aire: resopla (cabezada y, de noche, vaho en dos bocanadas). Se oye a veces; herida o encerrada,
			-- siempre (y no encima de un gruñido).
			if viva then
				b.resopla = ahora
				if puedeVaho(distancia) then
					vahoDe(b):Emit(5)
					b.soplo = ahora + 0.22
				end
				if distancia < RESOPLA_LEJOS and b.calma > 0.5 and ahora - b.grunido > GRUNE_DURA
					and (alterada or azar:NextNumber() < RESOPLA_SUENA) then
					resoplido(b, false)
				end
			end
		end
		if ahora > b.soplo then
			b.soplo = math.huge
			if puedeVaho(distancia) then
				vahoDe(b):Emit(3)
			end
		end
		local tr = (ahora - b.resopla) / RESOPLIDO
		local cabezada = if tr < 1 then math.sin(math.pi * tr) * (1 - tr) * 1.7 * b.calma else 0

		-- Gruñe bajo de vez en cuando (parada y cerca de la cámara).
		if parada > 0.6 and distancia < RESOPLA_LEJOS and ahora > b.proximoGrunido then
			b.proximoGrunido = ahora + rango(GRUNE) * (if alterada then 0.6 else 1)
			b.grunido = ahora
			resoplido(b, true)
		elseif parada < 0.3 then
			b.proximoGrunido = math.max(b.proximoGrunido, ahora + 2)
		end
		local tg = ahora - b.grunido
		local grune = if tg < GRUNE_DURA then math.clamp(math.min(tg / 0.25, (GRUNE_DURA - tg) / 0.5), 0, 1) else 0

		-- Tiembla entera: más herida o encerrada, y gruñendo.
		local trem = if viva then TIEMBLA * (if alterada then TIEMBLA_ALTERADA else 1) * (1 + 1.5 * grune) * 2 else 0
		local t1 = math.noise(ahora * 13, b.semilla) * trem
		local t2 = math.noise(ahora * 11, b.semilla + 3.3) * trem
		local t3 = math.noise(ahora * 17, b.semilla + 6.6) * trem
		local t4 = math.noise(ahora * 15, b.semilla + 9.9) * trem

		-- Parada, carga el peso de un brazo al otro.
		if ahora > b.proximoPeso then
			b.proximoPeso = ahora + rango(PESO)
			b.pesoMeta = (if b.pesoMeta > 0 then -1 else 1) * azar:NextNumber(0.5, 1)
		end
		b.peso += (b.pesoMeta - b.peso) * math.min(1, dt * 1.4)
		local peso = b.peso * parada

		-- Olfatea a golpes cortos: sube la cabeza y da cuatro golpes de nariz (de noche, un poco de vaho en cada uno).
		if parada > 0.6 and ahora > b.proximoOlfateo then
			b.proximoOlfateo = ahora + rango(OLFATEA)
			b.olfatea = ahora
			b.olfateado = 0
		elseif parada < 0.3 then
			b.proximoOlfateo = math.max(b.proximoOlfateo, ahora + 1.5)
		end
		local to = ahora - b.olfatea
		local olfateo, nariz = 0, 0
		if to < OLFATEO then
			olfateo = math.sin(math.pi * to / OLFATEO) * b.calma
			local golpe = to / (OLFATEO / 4)
			nariz = math.abs(math.sin(golpe * math.pi)) * b.calma
			if math.floor(golpe) >= b.olfateado then
				b.olfateado = math.floor(golpe) + 1
				if puedeVaho(distancia) then
					vahoDe(b):Emit(1)
				end
			end
		end

		-- Crispaciones: un músculo da un respingo (más seguidas herida o encerrada).
		if parada > 0.5 and ahora > b.proximaCrispa then
			b.proximaCrispa = ahora + rango(CRISPA) * (if alterada then 0.6 else 1)
			b.crispa = ahora
			b.crispaParte = PARTES[azar:NextInteger(1, #PARTES)]
			local fuerza = if b.crispaParte == "Lomo" then 0.015 elseif b.crispaParte == "Cabeza" then 0.1 else 0.07
			b.crispaEje = Vector3.new(if azar:NextNumber() < 0.5 then -1 else 1, azar:NextNumber(-0.4, 0.4),
				azar:NextNumber(-1, 1)).Unit * fuerza
		end
		local tc = ahora - b.crispa
		local crispa = if tc < 0.04 then tc / 0.04 elseif tc < 0.6 then math.exp(-(tc - 0.04) / 0.08) else 0

		-- Patas: en diagonal (brazo izquierdo con pierna derecha). Herida, la de atrás derecha va tiesa y arrastrada.
		pose.PiernaI = CFrame.Angles(s * 0.5 * paso, 0, 0) * respingo(b, "PiernaI", crispa)
		pose.PiernaD = (if cojea then CFrame.Angles(0.35 - s * 0.12 * paso, 0, 0.12) else CFrame.Angles(-s * 0.5 * paso, 0, 0))
			* respingo(b, "PiernaD", crispa)
		local brazo = -s * 0.55 * paso + brazosG + (if rugiendo then 0.9 else 0) + encoge * 0.8
		local otro = s * 0.55 * paso + brazosG + (if rugiendo then 0.9 else 0) + encoge * 0.8
		if quemando then -- se agita con los brazos
			brazo += math.sin(ahora * 11) * 0.9
			otro += math.sin(ahora * 9 + 1) * 0.9
		elseif aranando then -- de pie, los brazos arriba arañando el hueco, uno y otro
			brazo = 2.6 + math.sin(ahora * 10) * 0.7
			otro = 2.6 + math.sin(ahora * 10 + math.pi) * 0.7
		end
		-- Viva: el brazo que no carga el peso se adelanta un poco (su hombro sube con el lomo); tiemblan.
		brazo += math.max(0, -peso) * 0.06 + t3
		otro += math.max(0, peso) * 0.06 + t4
		pose.BrazoI = CFrame.Angles(brazo, 0, 0) * respingo(b, "BrazoI", crispa)
		pose.BrazoD = CFrame.Angles(otro, 0, 0) * respingo(b, "BrazoD", crispa)

		-- Cuerpo: cabecea pesado a cada paso; herida, se le vence hacia el lado de la pata mala. Viva, la espalda sube al
		-- coger aire y baja de golpe al soltarlo, y tiembla (si no, respira un poco). Al cargar el peso se ladea subiendo
		-- el hombro del brazo libre, y sube lo justo para que el otro no baje: los nudillos que cargan no se hunden.
		local respira = if viva then 0 else math.sin(ahora * 1.6) * 0.03
		local espalda = HOMBROS * CFrame.Angles(-(if viva then (lleno - 0.5) * HINCHA else 0) + t2 * 0.5, 0, 0)
			* respingo(b, "Lomo", crispa) * HOMBROS:Inverse()
		local cabeceo = math.abs(s) * 0.06 * paso
		local vence = if cojea then math.max(0, -s) * 0.18 * paso + 0.05 else 0
		local alza = (if rugiendo then 0.45 else 0) + torsoG + (if aranando then 0.55 + math.sin(ahora * 10) * 0.05 else 0)
		local ladeo = s * 0.05 * paso - vence - encoge * 0.2
		if quemando then
			local t = ahora - b.quema
			alza += 0.5 * math.max(0, 1 - t / 2) - 0.25 * math.clamp((t - 2) / 2, 0, 1) -- se alza y luego se derrumba
			ladeo += math.sin(ahora * 7) * 0.22
		end
		local carga = peso * PESO_LADEA -- + sube el hombro derecho (carga en el brazo izquierdo)
		pose.Lomo = CFrame.new(0, math.abs(carga) * HOMBRO, 0)
			* CFrame.Angles(alza + cabeceo + respira, 0, ladeo + carga + t1 * 0.5) * espalda

		-- Cabeza: tirones bruscos a una posición nueva cada poco (más seguidos si está alterada). Viva, además: cabezada
		-- al resoplar, alta y a golpecitos al olfatear (buscando a los lados), baja al gruñir; tiembla.
		if ahora > b.tiron then
			local agitada = rugiendo or quemando or alterada
			b.tiron = ahora + (if agitada then azar:NextNumber(0.2, 0.7) else azar:NextNumber(0.6, 2.2))
			b.meta = Vector3.new(azar:NextNumber(-0.25, 0.2), azar:NextNumber(-0.6, 0.6), azar:NextNumber(-0.7, 0.7))
		end
		b.giro = b.giro:Lerp(b.meta, math.min(1, dt * 18))
		local aparta = if ahora - b.flash < 0.7 then 1.1 else 0
		local aire = if viva then lleno - 0.5 else 0 -- -0,5..0,5: la cabeza sube al coger aire y la boca se abre al soltarlo
		local giro = b.giro + Vector3.new((if rugiendo then 0.35 else 0) + (if aranando then 0.6 else 0) + olfateo * 0.3
			+ nariz * 0.05 - cabezada * 0.2 - grune * 0.12 + aire * 0.06 + t3,
			aparta + encoge * 0.9 + olfateo * 0.15 * math.sin(ahora * 3 + b.semilla), t4)
		pose.Cabeza = CFrame.Angles(giro.X, giro.Y, giro.Z) * respingo(b, "Cabeza", crispa)
		local abre = 0.2 + 0.06 * math.sin(ahora * 2.5) + brazosG * 0.2 + encoge * 0.6
			+ (if rugiendo or quemando then 0.75 + 0.1 * math.sin(ahora * 30) else 0)
			+ (if aranando then 0.45 + 0.15 * math.sin(ahora * 13) else 0)
			+ cabezada * 0.2 - olfateo * 0.12 + grune * (0.14 + 0.03 * math.sin(ahora * 45)) - aire * 0.08
		pose.Mandibula = CFrame.Angles(-abre, 0, 0)

		-- Gateando a por alguien debajo de un mueble: manda sobre todo lo demás (ya mezclado con su pose de siempre).
		local gm = gatear(b, ahora, servidor, dt, ojo, not rendimiento and distancia < CERCA, distancia, rapidez)
		local gp = if gm > 0 and b.gateo then b.gateo.pose else nil
		for _, nombre in MOTORES do
			m[nombre].Transform = if gp and gp[nombre] then gp[nombre] else pose[nombre]
		end

		-- Pisadas: graves y pesadas; cerca, tiembla el suelo.
		local lado = if s >= 0 then 1 else -1
		if rapidez > 2 and lado ~= b.pisada then
			b.pisada = lado
			local pies = b.raiz.Position - Vector3.new(0, ALTURA, 0)
			local blanda = cojea and lado < 0
			local sonido = Sonido.en("Paso", pies, azar:NextNumber(0.4, 0.46))
			sonido.Volume *= if blanda then 0.8 else 1.4
			sonido.RollOffMinDistance = 15
			temblar(pies, if blanda then 0.04 else 0.08, 30)
		end
	end
	-- Sin Bestia, el bucle se apaga (vuelve al salir otra).
	if next(bichos) == nil and conexion then
		conexion:Disconnect()
		conexion = nil
	end
end

local function preparar(modelo: Instance)
	if not modelo:IsA("Model") or modelo.Name ~= "Bestia" or bichos[modelo] then
		return
	end
	local raiz = modelo:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not raiz then
		return
	end
	local motores, c0, c0i, c1, c1i, pose = {}, {}, {}, {}, {}, {}
	for _, nombre in MOTORES do
		local motor = raiz:WaitForChild(nombre, 5) :: Motor6D?
		if not motor or not motor:IsA("Motor6D") or not motor.Part1 then
			return
		end
		motores[nombre] = motor
		c0[nombre], c0i[nombre] = motor.C0, motor.C0:Inverse()
		c1[nombre], c1i[nombre] = motor.C1, motor.C1:Inverse()
		pose[nombre] = CFrame.identity
	end
	if not modelo.Parent or bichos[modelo] then
		return
	end
	local ahora = os.clock()
	local semilla = azar:NextNumber(0, 100)
	bichos[modelo] = { modelo = modelo, raiz = raiz, cabeza = motores.Cabeza.Part1 :: BasePart, motores = motores, fase = 0,
		pisada = 1, rugido = -math.huge, golpe = -math.huge, herida = -math.huge, flash = -math.huge, quema = -math.huge,
		arana = -math.huge, giro = Vector3.zero, meta = Vector3.zero, tiron = 0, humo = nil, semilla = semilla, quietud = 0,
		calma = 0, aliento = semilla, ciclo = math.floor(semilla - COGE), resopla = -math.huge, soplo = math.huge, peso = 0,
		pesoMeta = 1, proximoPeso = ahora + rango(PESO), olfatea = -math.huge, proximoOlfateo = ahora + rango(OLFATEA),
		olfateado = 0, crispa = -math.huge, crispaParte = "", crispaEje = Vector3.zero, proximaCrispa = ahora + rango(CRISPA),
		grunido = -math.huge, proximoGrunido = ahora + rango(GRUNE), vaho = nil, c0 = c0, c0i = c0i, c1 = c1, c1i = c1i,
		pose = pose, gateo = nil, pilla = -math.huge }
	if not conexion then
		conexion = RunService.Stepped:Connect(function(_, dt)
			animar(dt)
		end)
	end
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

-- Abre la boca del todo unos segundos (el susto al morir). Devuelve la Bestia con la cabeza cerca de `punto`, si hay.
function BestiaVista.rugir(punto: Vector3): Model?
	local b = cercano(punto, 14)
	if b then
		b.rugido = os.clock()
		b.pilla = b.rugido -- si estaba gateando, se queda aplastada en la pose (la escena de muerte le ve la cara ahí)
		return b.modelo
	end
	return nil
end

local function cabezaDe(b: Bicho): Vector3
	return if b.cabeza.Parent then b.cabeza.Position else b.raiz.Position
end

local function rugido(b: Bicho, tono: number, lejos: number)
	local s = Sonido.en("Rugido", cabezaDe(b), tono)
	s.RollOffMinDistance = lejos
end

-- Polvo y astillas que caen del hueco que araña (un momento y se borran).
local function polvo(donde: Vector3)
	local pieza = Instance.new("Part")
	pieza.Anchored, pieza.CanCollide, pieza.CanQuery, pieza.CanTouch = true, false, false, false
	pieza.Transparency = 1
	pieza.Size = Vector3.new(3, 0.2, 2.5)
	pieza.CFrame = CFrame.new(donde)
	for i, color in { Color3.fromRGB(120, 110, 96), Color3.fromRGB(70, 50, 34) } do
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(color)
		e.LightEmission = 0
		e.Lifetime = NumberRange.new(0.8, 1.6)
		e.Speed = NumberRange.new(0.5, 2)
		e.SpreadAngle = Vector2.new(40, 40)
		e.EmissionDirection = Enum.NormalId.Bottom
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-120, 120)
		if i == 1 then -- polvo
			e.Acceleration = Vector3.new(0, -4, 0)
			e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1.6) })
			e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
		else -- astillas
			e.Acceleration = Vector3.new(0, -30, 0)
			e.Size = NumberSequence.new(0.12)
			e.Squash = NumberSequence.new(1.5)
		end
		e.Enabled = false
		e.Parent = pieza
		task.defer(e.Emit, e, if i == 1 then 18 else 10)
	end
	pieza.Parent = workspace
	Debris:AddItem(pieza, 2.5)
end

local function mensaje(tipo: string, b: Bicho)
	local ahora = os.clock()
	if tipo == "Ruge" then
		b.rugido = ahora
		rugido(b, 0.6, 45)
		task.delay(0.15, rugido, b, 0.48, 45) -- dos capas: más grave y más grande que los demás
		temblar(b.raiz.Position, 0.12, 40)
	elseif tipo == "Golpe" then
		b.golpe = ahora
		task.delay(0.36, function() -- el golpe suena cuando bajan los brazos
			if b.modelo.Parent then
				local delante = b.raiz.Position + b.raiz.CFrame.LookVector * 5
				Sonido.en("Golpe", delante, azar:NextNumber(0.7, 0.8))
				temblar(delante, 0.25, 35)
			end
		end)
	elseif tipo == "Herida" then
		b.herida = ahora
		Sonido.en("Chillido", cabezaDe(b), 0.7)
		task.delay(0.4, rugido, b, 0.75, 30)
	elseif tipo == "Atrapada" then
		b.rugido = ahora
		rugido(b, 0.52, 40)
		temblar(b.raiz.Position, 0.15, 40)
	elseif tipo == "Flash" then
		b.flash = ahora
	elseif tipo == "Arana" then
		-- Bajo la trampilla: garras contra las tablas del hueco, polvo y astillas que caen, y un rugido de vez en cuando.
		local primera = ahora - b.arana > 2
		b.arana = ahora
		local arriba = cabezaDe(b) + Vector3.new(0, 4, 0)
		Sonido.en("Raspado", arriba, azar:NextNumber(0.55, 0.7)).RollOffMinDistance = 25
		task.delay(0.35, function()
			if b.modelo.Parent then
				Sonido.en("Golpe", arriba, azar:NextNumber(0.85, 1)).RollOffMinDistance = 25
				temblar(arriba, 0.14, 30)
				polvo(arriba)
			end
		end)
		if primera or azar:NextNumber() < 0.4 then
			b.rugido = ahora
			rugido(b, azar:NextNumber(0.5, 0.58), 40)
		end
	elseif tipo == "Quema" then
		b.quema = ahora
		b.rugido = ahora
		for _, nombre in { "Lomo", "Cabeza", "BrazoI", "BrazoD", "PiernaI", "PiernaD" } do
			local pieza = b.motores[nombre].Part1
			if pieza then
				prender(pieza, if nombre == "Lomo" then 8 else 4)
			end
		end
		local luz = Instance.new("PointLight")
		luz.Color = Color3.fromRGB(255, 140, 60)
		luz.Brightness = 1
		luz.Range = 16
		luz.Parent = b.motores.Lomo.Part1
		-- Chillido largo: varias capas, cada una más grave.
		for i, tono in { 0.62, 0.55, 0.48 } do
			task.delay((i - 1) * 1.3, function()
				if b.modelo.Parent then
					local s = Sonido.en("Chillido", cabezaDe(b), tono)
					s.RollOffMinDistance = 40
				end
			end)
		end
		task.delay(0.2, rugido, b, 0.45, 45)
	end
end

function BestiaVista.start()
	local carpeta = workspace:WaitForChild("Bichos")
	carpeta.ChildAdded:Connect(preparar)
	carpeta.ChildRemoved:Connect(function(modelo)
		if modelo:IsA("Model") then
			olvidar(modelo)
		end
	end)
	for _, modelo in carpeta:GetChildren() do
		task.spawn(preparar, modelo)
	end
	Remotes.Bestia.OnClientEvent:Connect(function(tipo: string, modelo: Model?)
		if typeof(modelo) ~= "Instance" then
			return
		end
		-- Recién creada puede no estar preparada aún (el rugido al salir del bosque llega a la vez).
		task.spawn(function()
			local b = bichos[modelo]
			for _ = 1, 20 do
				if b then
					break
				end
				task.wait(0.1)
				b = bichos[modelo]
			end
			if b then
				mensaje(tipo, b)
			end
		end)
	end)
end

return BestiaVista
