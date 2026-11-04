-- Mueve el cuerpo del Trepador en el cliente y hace sus ruidos (el servidor solo lo desplaza y publica atributos).
--   Anda como una araña: patas en diagonal, codos y rodillas por encima de la espalda. Las puntas pisan de verdad
--   (cinemática inversa de dos huesos): van hacia atrás pegadas al suelo y se adelantan por el aire; en la pared, contra
--   la pared.
--   Parado, agazapado y nervioso (pedido por el usuario: "los bichos con más vida mientras esperan"): se agacha (las
--   rodillas suben y las puntas se quedan donde están), jadea deprisa, pasa el peso de un lado a otro, levanta una pata y
--   la apoya un poco más allá, se le crispan las patas y le castañetean los dientes. La cabeza (del revés) da tirones
--   hacia el jugador más cercano o a cualquier lado. Cada poco se para a escuchar: se queda clavado, más agachado y sin
--   respirar, con la cabeza muy ladeada hacia quien tenga más cerca (en el tejado, hacia los de dentro) o hacia abajo;
--   luego suelta el aire de golpe. A ratos le da una sacudida rara: se le retuerce la cabeza y le tiemblan las patas.
--   De noche y fuera de la casa echa vaho al soltar el aire (sin él con Rendimiento).
--   Chillando (al salir al salón, al quemarse o al pillarte): se levanta con las patas de delante en alto, temblando.
--   En la pared y en el tejado (Trepando, EnTejado): pasos pesados que se oyen desde dentro de la casa y crujidos de la
--   madera de vez en cuando, también parado al mover una pata; mientras escucha, silencio.
--   Bajando por el tiro (Bajando) va por dentro del ladrillo: se esconde en el cliente (las patas asomaban por el tiro al
--   dormitorio) y se le oye arrastrarse.
--   Remote Trepador: "Baja" (algo arrastrándose por dentro del tiro y hollín cayendo al hogar), "Entra" (sale al salón
--   entre una nube de hollín, chillando) y "Quema" (chilla con el fuego).
--   Gateando (Gatea y GateaHora en su modelo): se aplasta contra el suelo con las patas muy abiertas y se cuela a tirones
--   debajo del mueble donde te escondes (ver GATEO).
-- Un solo bucle (Stepped) que solo corre mientras hay alguno; la vida, solo cerca de la cámara. Si el modelo se va
-- (StreamOut o lo quita el servidor) se olvida, y si vuelve se prepara otra vez.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local MuebleRayo = require(script.Parent.MuebleRayo)
local Sonido = require(script.Parent.Sonido)

local TrepadorVista = {}

-- Números visuales a ojo (se retocan en Studio).
local LEJOS = 250 -- studs de la cámara: más lejos no se le mueve nada
local VIDA_LEJOS = 120 -- la vida (agazaparse, jadear, tirones...) solo hasta aquí...
local VIDA_RENDIMIENTO = 45 -- ...o hasta aquí con Rendimiento
local VAHO_LEJOS = 60
local QUIETO = 1.2 -- studs/s: más despacio está parado
local SUELO, SUELO_PARED = 2.1, 1.3 -- studs de la raíz a donde apoya las puntas: en el suelo o el tejado, y en la pared
local RITMO = 0.9 -- radianes de paso por stud andado...
local ZANCADA = math.pi / (2 * RITMO) -- ...y studs que va y viene cada punta (así, apoyada, no resbala)
local ALZA = 0.9 -- studs que levanta la punta al adelantarla
local AGAZAPA, AGAZAPA_ESCUCHA = 0.35, 0.6 -- studs que baja el cuerpo parado y escuchando
local RESPIRA = 0.95 -- segundos por respiración: jadea deprisa
local PESO = 3.2 -- segundos en pasar el peso de un lado al otro y volver
local TIRON = { 0.25, 1.1 } -- segundos entre dos tirones de la cabeza
local MUEVE = { 0.6, 1.8 } -- segundos entre dos veces que mueve una pata...
local DURA_MUEVE = 0.3 -- ...y lo que tarda en apoyarla otra vez
local CRISPA = { 1, 2.8 } -- segundos entre dos crispaciones de una pata
local ESCUCHA = { 4, 9 } -- segundos entre dos veces que se para a escuchar...
local DURA_ESCUCHA = { 1.4, 2.8 } -- ...y lo que escucha
local SACUDIDA = { 6, 12 } -- segundos entre dos sacudidas raras
local DURA_SACUDIDA = 0.7
local CASTANETEA = { 3, 7 } -- segundos entre dos veces que le castañetean los dientes
local CRUJE_PATA = 2 -- segundos: en el tejado, mover una pata cruje si hace esto que no cruje nada
local VER = 45 -- studs: mira a los jugadores que tenga más cerca que esto
local GIRO = 1.2 -- radianes que gira la cabeza como mucho a cada lado
local AMENAZA = Vector3.new(0.5, 2.4, -1) -- chillando, cuánto suben las puntas de delante (x hacia fuera)
local BOCA = CFrame.new(0, -0.4, -0.75) -- en la cabeza (del revés: la boca le queda arriba)
local VAHO, VAHO_SUELTA = 3, 9 -- partículas al soltar el aire jadeando y al soltarlo de golpe tras escuchar
local MOTORES = { "Torso", "Cabeza", "Mandibula", "BrazoI", "AntebrazoI", "BrazoD", "AntebrazoD", "PiernaI", "EspinillaI",
	"PiernaD", "EspinillaD" }
-- Las patas (Trepador.crear): al andar van en diagonal, el brazo izquierdo con la pierna derecha y al revés.
local PATAS = {
	{ arriba = "BrazoI", abajo = "AntebrazoI", lado = -1, desfase = 0, delante = true },
	{ arriba = "BrazoD", abajo = "AntebrazoD", lado = 1, desfase = math.pi, delante = true },
	{ arriba = "PiernaI", abajo = "EspinillaI", lado = -1, desfase = math.pi, delante = false },
	{ arriba = "PiernaD", abajo = "EspinillaD", lado = 1, desfase = 0, delante = false },
}
-- Gatear a por alguien escondido debajo de un mueble (pedido por el usuario: "que el monstruo pueda gatear si te huele
-- con una animación guapa para pillarte debajo de sitios"). El servidor (Caza) le para en el borde, de cara a ti, y pone
-- en su modelo Gatea (dónde estás) y GateaHora (workspace:GetServerTimeNow() al empezar) durante Config.Postura.Gatear s.
-- Como una araña: si la cabeza o las rodillas le quedan sobre la mesa, primero se echa atrás; luego se aplasta contra el
-- suelo con las patas muy abiertas (las rodillas bajan de 2,5) y se cuela a tirones, con la cabeza (del revés) a ras de
-- suelo y mirándote, parándose a olfatear. Las patas siguen pisando por cinemática inversa: al aplastarse y entre tirón
-- y tirón las mueve de dos en dos (en diagonal), y las puntas que caerían debajo del tablero se agarran por fuera de él.
-- Al acabar saca la cabeza, se retira a donde se echó atrás y se levanta ahí (se queda retirado hasta que vuelve a
-- andar: si no, al volver a su sitio metería la cabeza en el tablero). Comprobado con Lune contra la mesa del comedor
-- (tablero a 2,84 del suelo) y la de la cocina (a 3,29), a 1,8, 2,2 y 3 studs del borde y en diagonal: ni el suelo ni
-- el tablero se atraviesan en ningún fotograma.
local ALTURA = 2.2 -- de los pies al centro de la raíz (Trepador.luau)
local GATEO = {
	Atras = 0.3, -- (en un gateo de 2 s) cuándo acaba de echarse atrás...
	Cae = 0.45, -- ...y de aplastarse
	Sale = 0.45, -- al acabar, segundos en sacar la cabeza de debajo y retirarse...
	Levanta = 0.6, -- ...y en levantarse
	Plano = 0.66, -- studs del suelo al centro del torso, aplastado (el torso mide 1,1 de alto)
	Hasta = 1.1, -- studs entre su frente y tú al acabar
	Dentro = 2.6, -- studs que mete la frente por debajo del tablero, como mucho (las caderas se quedan fuera)
	Margen = 0.35, -- studs entre el tablero y la cabeza, las rodillas o las puntas que se quedan fuera
	AtrasMax = 3, -- studs que se echa atrás como mucho
	Abre = 6.8, -- studs de la cadera a la punta, por el suelo, con las patas abiertas (así las rodillas, a ~2,2)
	Adelante = 2.4, -- de eso, cuánto va hacia delante (las de delante) o hacia atrás (las de detrás)
	Punta = 0.55, -- studs del suelo a la punta apoyada: los dedos, que siguen más allá, quedan a ras de suelo
	Alza = 0.35, -- studs que levanta la punta al moverla
	Borde = 1.4, -- studs del borde del mueble hasta ti, si los rayos no encuentran el tablero
	-- Los tirones, en un gateo de 2 s: {empieza, acaba, hasta dónde ha llegado (0..1)}.
	Tirones = { { 0.5, 0.68, 0.4 }, { 1, 1.18, 0.72 }, { 1.5, 1.75, 1 } },
	-- Cuándo mueve las patas, en un gateo de 2 s: {empiezan las de un par, las del otro, acaban}. Al aplastarse y en cada
	-- parada entre tirones (al salir y al levantarse, cada par en media vuelta).
	Pasos = { { 0.1, 0.27, 0.45 }, { 0.72, 0.84, 0.96 }, { 1.22, 1.34, 1.46 } },
	Susto = 2.2, -- segundos que se queda aplastado si te pilla (MuerteVista mira su cara)
}
-- Medidas del cuerpo (Trepador.crear) que usa el gateo: del centro del torso a la frente, y a lo más adelantado de las
-- rodillas de delante con las patas abiertas.
local CABEZA_FRENTE, RODILLA = 3.65, 2.9
local CARRILES, CARRIL = 10, 0.75 -- el borde se mide en carriles cada 0,75 studs, 10 a cada lado (lo que abre las patas)
-- Cuándo suenan los ruidos del gateo (ruidoGateo) y cada pisada (al apoyar cada par de patas), en un gateo de 2 s.
local RUIDOS = { GATEO.Cae, GATEO.Tirones[1][1], GATEO.Tirones[2][1], GATEO.Tirones[3][1] }
local PISADAS = {}
for _, paso in GATEO.Pasos do
	table.insert(PISADAS, paso[2])
	table.insert(PISADAS, paso[3])
end

local jugador = Players.LocalPlayer
local azar = Random.new()
local filtroGateo = RaycastParams.new()
filtroGateo.FilterType = Enum.RaycastFilterType.Exclude

type Pata = {
	arriba: Motor6D,
	abajo: Motor6D,
	lado: number,
	desfase: number,
	delante: boolean,
	cadera: Vector3, -- la junta de arriba, en el torso...
	giro: CFrame, -- ...y su giro de reposo
	giroInv: CFrame,
	largo1: number, -- lo que mide el tramo de arriba y el de abajo (hasta la punta)
	largo2: number,
	angulo1: number, -- ángulos de reposo de los dos tramos en el plano de la pata (desde fuera hacia arriba)
	angulo2: number,
	reposo: Vector3, -- la punta en reposo, en la raíz
	apoyo: Vector3, -- parado: cuánto la ha movido de su sitio (x hacia fuera, z hacia atrás)
	antes: Vector3, -- de dónde venía al moverla
	movida: number, -- os.clock desde que la mueve
	crispa: number, -- os.clock de la última crispación
}

-- Un gateo: el de ahora o el último (mientras vuelve a su pose). Todo en el marco: en el suelo bajo la raíz, con -Z
-- hacia el escondido.
type Gateo = {
	hora: number, -- GateaHora (hora del servidor)
	punto: Vector3, -- Gatea: dónde está el escondido
	t: number, -- segundos desde que empezó (se queda en el último al acabar)
	sonados: number, -- cuántos ruidos del gateo han sonado...
	pisadas: number, -- ...y cuántas pisadas
	sale: number, -- 0..1: al acabar, cuánto ha sacado ya la cabeza y se ha retirado
	levanta: boolean, -- ya se está levantando (b.gateo baja de 1 a 0)
	marco: CFrame, -- en la raíz
	bordes: { number }, -- studs hasta el tablero en cada carril (hacia delante); math.huge si no hay
	torso0: CFrame, -- el torso al empezar, las puntas, la cabeza y la boca (lo que se veía el fotograma anterior: así no
	puntas0: { Vector3 }, -- salta nada, ni si empieza otro gateo a medio levantarse)
	cabeza0: CFrame,
	boca0: CFrame,
	zAtras: number, -- dónde se pone el torso al echarse atrás...
	zFin: number, -- ...y al acabar de colarse (z: menos es más adelante)
	plantas: { { Vector3 } }, -- dónde apoya cada pata tras cada vez que las mueve (se calcula al necesitarlo)...
	plantasSimple: { { Vector3 } }, -- ...con Rendimiento
	salida: { Vector3 }?, -- ...y al salir
}

type Bicho = {
	modelo: Model,
	raiz: BasePart,
	cabeza: BasePart,
	motores: { [string]: Motor6D },
	patas: { Pata },
	partes: { BasePart },
	oculto: boolean?, -- escondido en el cliente (bajando por el tiro); nil: aún sin poner
	antes: Vector3,
	rapidez: number,
	fase: number,
	pisada: number,
	chillido: number,
	crujido: number, -- os.clock del próximo crujido del tejado...
	crujio: number, -- ...y del último
	semilla: number,
	vida: number, -- 0..1, suave: parado y cerca de la cámara
	suelo: number, -- studs hasta donde apoya las puntas (suave: menos en la pared)
	amenaza: number, -- 0..1, suave: chillando, con las patas de delante en alto
	respira: number, -- fase de la respiración (radianes)
	exhala: boolean,
	peso: number,
	cab: Vector3, -- la cabeza ahora (cabeceo, giro, ladeo)...
	meta: Vector3, -- ...y a dónde va a dar el tirón
	mira: BasePart?, -- la cabeza del jugador al que mira
	tiron: number, -- os.clock del próximo tirón
	escucha: number, -- 0..1, suave
	escuchaba: boolean,
	escuchaHasta: number,
	proximaEscucha: number,
	jadeo: number, -- os.clock al soltar el aire de golpe
	proximaMueve: number,
	ultimaPata: number,
	proximaCrispa: number,
	sacudida: number,
	proximaSacudida: number,
	castaneo: number,
	proximoCastaneo: number,
	gateo: number, -- 1 mientras gatea; levantándose, de 1 a 0
	gatea: Gateo?,
	agarra: number, -- os.clock de rugir: el susto al morir le deja aplastado
	retiro: Vector3, -- en la raíz: tras gatear se queda donde se echó atrás, hasta que vuelve a andar
	puntas: { Vector3 }, -- las puntas este fotograma (en la raíz)...
	ultimas: { Vector3 }, -- ...y las del anterior, ya con el gateo
	ultimoTorso: CFrame?, -- el torso del fotograma anterior (en la raíz), su cabeza y su boca
	ultimaCabeza: CFrame,
	ultimaBoca: CFrame,
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

-- Una crispación: sube de golpe y se apaga (0..1).
local function crispacion(t: number): number
	if t < 0 or t > 0.4 then
		return 0
	end
	local x = t / 0.05
	return x * math.exp(1 - x)
end

-- Como CuerpoVista: dentro de la casa no se ve el vaho.
local function dentroDeCasa(p: Vector3): boolean
	local c = Config.Casa
	return math.abs(p.X) < c.MedioX and math.abs(p.Z) < c.MedioZ and p.Y < 28
end

-- El vaho: bocanadas cortas que salen de la boca hacia delante y se deshacen (las partículas se quedan donde salen).
local function echarVaho(b: Bicho, cuantas: number)
	local boca = b.cabeza.CFrame * BOCA
	if dentroDeCasa(boca.Position) then
		return
	end
	if not vahoEmisor then
		local a = Instance.new("Attachment")
		a.Name = "VahoTrepador"
		a.Parent = workspace.Terrain
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.LightInfluence = 1 -- de noche apenas se ve: con la linterna o la luz de una ventana
		e.Color = ColorSequence.new(Color3.fromRGB(215, 220, 228))
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 1) })
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.8) })
		e.Lifetime = NumberRange.new(0.9, 1.4)
		e.Speed = NumberRange.new(1.5, 2.5)
		e.SpreadAngle = Vector2.new(25, 25)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-25, 25)
		e.Acceleration = Vector3.new(0, 0.5, 0)
		e.Drag = 1.8
		e.Rate = 0
		e.Parent = a
		vahoPunto, vahoEmisor = a, e
	end
	-- Sale por el eje Y del punto: hacia donde mira la cara.
	;(vahoPunto :: Attachment).WorldCFrame = CFrame.lookAt(boca.Position, boca.Position + boca.LookVector) * CFrame.Angles(-math.pi / 2, 0, 0)
	;(vahoEmisor :: ParticleEmitter):Emit(cuantas)
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

-- Cabeceo y giro de la cabeza para mirar a `punto`, en su junta (del revés: las cuentas valen igual), con los topes.
local function mirada(junta: CFrame, punto: Vector3): (number, number)
	local d = junta:VectorToObjectSpace(punto - junta.Position)
	return math.clamp(math.atan2(d.Y, math.sqrt(d.X * d.X + d.Z * d.Z)), -0.7, 0.7), math.clamp(math.atan2(-d.X, -d.Z), -GIRO, GIRO)
end

-- Mide una pata en reposo: dónde está la cadera, lo que mide cada tramo y sus ángulos en el plano de la pata.
-- `base`: el torso en reposo, en la raíz.
local function medirPata(arriba: Motor6D, abajo: Motor6D, lado: number, base: CFrame): Pata?
	local parte = abajo.Part1
	if not parte then
		return nil
	end
	local junta = arriba.C0
	local rodilla = junta * arriba.C1:Inverse() * abajo.C0
	local punta = rodilla * abajo.C1:Inverse() * Vector3.new(0, -parte.Size.Y / 2, 0)
	local k, t = rodilla.Position - junta.Position, punta - rodilla.Position
	return {
		arriba = arriba, abajo = abajo, lado = lado, desfase = 0, delante = false,
		cadera = junta.Position, giro = junta.Rotation, giroInv = junta.Rotation:Inverse(),
		largo1 = k.Magnitude, largo2 = t.Magnitude,
		angulo1 = math.atan2(k.Y, lado * k.X), angulo2 = math.atan2(t.Y, lado * t.X),
		reposo = base * punta,
		apoyo = Vector3.zero, antes = Vector3.zero, movida = -math.huge, crispa = -math.huge,
	}
end

-- Gira las dos juntas de la pata para que la punta llegue a `objetivo` (en el torso): el plano de la pata gira sobre
-- la vertical de la cadera y los dos tramos se doblan en ese plano con la rodilla arriba (comprobado con Lune: la
-- punta llega justo al sitio, también con el torso agachado y ladeado).
local function pisar(p: Pata, objetivo: Vector3)
	local rel = objetivo - p.cadera
	local lado, l1, l2 = p.lado, p.largo1, p.largo2
	local r = math.sqrt(rel.X * rel.X + rel.Z * rel.Z)
	local d = math.clamp(math.sqrt(r * r + rel.Y * rel.Y), math.abs(l1 - l2) + 0.01, l1 + l2 - 0.01)
	local a1 = math.atan2(rel.Y, r) + math.acos(math.clamp((l1 * l1 + d * d - l2 * l2) / (2 * l1 * d), -1, 1))
	local a2 = math.atan2(rel.Y - l1 * math.sin(a1), r - l1 * math.cos(a1))
	local d1 = lado * (a1 - p.angulo1)
	p.arriba.Transform = p.giroInv * CFrame.Angles(0, math.atan2(-lado * rel.Z, lado * rel.X), 0) * p.giro * CFrame.Angles(0, 0, d1)
	p.abajo.Transform = CFrame.Angles(0, 0, lado * (a2 - p.angulo2) - d1)
end

-- Un sonido en 3D que se oye bien a través del techo (los pasos de arriba tienen que notarse).
local function fuerte(nombre: string, donde: Vector3, tono: number, volumen: number)
	local s = Sonido.en(nombre, donde, tono)
	s.Volume = volumen
	s.RollOffMinDistance = 22
end

-- La madera del tejado cruje bajo su peso.
local function crujir(b: Bicho, ahora: number, volumen: number)
	b.crujido = ahora + azar:NextNumber(2.5, 5)
	b.crujio = ahora
	fuerte("Crujido", b.raiz.Position, azar:NextNumber(0.75, 0.95), volumen)
end

local function duraGateo(): number
	local reglas = Config.Postura
	return if reglas and reglas.Gatear then reglas.Gatear else 2
end

-- Studs (por el suelo, hacia delante) del marco al tablero que tapa al escondido, en cada carril: rayos hacia arriba
-- cada poco. Lo que quede más bajo que un escondite (el asiento de una silla) no cuenta. Si no da con nada en ningún
-- carril, el borde recto a GATEO.Borde de ti. Los muebles no se ven con rayos (CanQuery false): MuebleRayo.
local function buscarBordes(marco: CFrame, largo: number): { number }
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
	local muebles = MuebleRayo.cajas(marco.Position, largo + 8)
	local bordes, alguno = {}, false
	for i = -CARRILES, CARRILES do
		local borde = math.huge
		local d = 0
		while d < largo + 3 do
			local base = marco * Vector3.new(i * CARRIL, 0.4, -d)
			local choque = MuebleRayo.rayo(base, Vector3.new(0, 4.5, 0), filtroGateo, muebles)
			if choque and choque.Instance.Name ~= "Debajo" and choque.Position.Y - marco.Y > 2.3 then
				borde, alguno = math.max(0, d - 0.25), true
				break
			end
			d += 0.25
		end
		bordes[i + CARRILES + 1] = borde
	end
	if not alguno then
		for i in bordes do
			bordes[i] = math.max(0, largo - GATEO.Borde)
		end
	end
	return bordes
end

-- Lo más cerca que está el tablero entre dos carriles (x en el marco). Entre dos rayos, una esquina del tablero puede
-- quedar algo más cerca: medio carril menos.
local function bordeEntre(bordes: { number }, desde: number, hasta: number): number
	local menor = math.huge
	local i1 = math.max(-CARRILES, math.floor(math.min(desde, hasta) / CARRIL))
	for i = i1, math.min(CARRILES, math.ceil(math.max(desde, hasta) / CARRIL)) do
		menor = math.min(menor, bordes[i + CARRILES + 1])
	end
	return menor - CARRIL / 2
end

-- Por dónde va el gateo en `u` (segundos de un gateo de 2 s): cuánto se ha colado (0..1), cuánto olfatea (0..1, entre
-- tirones) y el empujón de cada tirón (0..1). Simple (Rendimiento): seguido, sin olfatear.
local function avanceGateo(u: number, simple: boolean): (number, number, number)
	if simple then
		return suave(math.clamp((u - GATEO.Cae) / (1.75 - GATEO.Cae), 0, 1)), 0, 0
	end
	local a = 0
	for _, tiron in GATEO.Tirones do
		if u >= tiron[2] then
			a = tiron[3]
		elseif u > tiron[1] then
			local k = (u - tiron[1]) / (tiron[2] - tiron[1])
			return a + (tiron[3] - a) * (1 - (1 - k) ^ 3), 0, math.sin(math.pi * k)
		else
			break
		end
	end
	return a, if u > GATEO.Cae then 1 else 0, 0
end

-- Lo que lleva echado atrás en `u` (0..1): de golpe, como quien se aparta de un salto, y frenando.
local function echado(u: number): number
	return 1 - (1 - math.clamp(u / GATEO.Atras, 0, 1)) ^ 2
end

-- El torso entrando, en `u`: se echa atrás (y se pone de cara a ti), se aplasta y se cuela a tirones.
local function torsoEntrando(g: Gateo, u: number, simple: boolean): CFrame
	local kb = echado(u)
	local kh = suave(math.clamp((u - 0.08) / (GATEO.Cae - 0.08), 0, 1))
	local a = avanceGateo(u, simple)
	local p0 = g.torso0.Position
	local z = p0.Z + (g.zAtras - p0.Z) * kb + (g.zFin - g.zAtras) * a
	return CFrame.new(p0.X * (1 - kb), p0.Y + (GATEO.Plano - p0.Y) * kh, z) * g.torso0.Rotation:Lerp(CFrame.new(), kb)
end

-- Dónde apoya la pata con el torso aplastado en `z`: abierta y hacia delante (o atrás), y si la punta cayera debajo del
-- tablero, por fuera de él (más abierta, para que la rodilla no suba).
local function plantar(g: Gateo, p: Pata, z: number): Vector3
	local cadera = Vector3.new(p.cadera.X, 0, z + p.cadera.Z)
	local dz = if p.delante then -GATEO.Adelante else GATEO.Adelante
	local tope = -(bordeEntre(g.bordes, cadera.X, cadera.X + p.lado * (GATEO.Abre + 0.5)) - GATEO.Margen)
	if cadera.Z + dz < tope then
		dz = math.min(tope - cadera.Z, GATEO.Abre - 1)
	end
	local abre = math.sqrt(GATEO.Abre * GATEO.Abre - dz * dz)
	return Vector3.new(cadera.X + p.lado * abre, GATEO.Punta, cadera.Z + dz)
end

-- Dónde apoyan las patas tras moverlas la vez `k` (GATEO.Pasos): donde les toca con el torso a medio camino de lo que
-- avanza mientras siguen ahí (así se estiran y se encogen lo mismo y no resbalan).
local function planta(g: Gateo, patas: { Pata }, k: number, i: number, simple: boolean): Vector3
	local cache = if simple then g.plantasSimple else g.plantas
	local fila = cache[k]
	if not fila then
		local siguiente = GATEO.Pasos[k + 1]
		local z1 = torsoEntrando(g, GATEO.Pasos[k][3], simple).Position.Z
		local z2 = torsoEntrando(g, if siguiente then siguiente[1] else 2, simple).Position.Z
		fila = {}
		for j, p in patas do
			fila[j] = plantar(g, p, (z1 + z2) / 2)
		end
		cache[k] = fila
	end
	return fila[i]
end

-- La punta de un sitio a otro por el aire, de `ini` a `fin` de `k`.
local function pisada(desde: Vector3, hasta: Vector3, k: number, ini: number, fin: number): Vector3
	if k <= ini then
		return desde
	elseif k >= fin then
		return hasta
	end
	local q = (k - ini) / (fin - ini)
	local alza = GATEO.Alza * math.sin(math.pi * q) * math.min(1, (hasta - desde).Magnitude / 0.6)
	return desde:Lerp(hasta, suave(q)) + Vector3.new(0, alza, 0)
end

-- La punta de una pata entrando, en `u`: las mueve de dos en dos (en diagonal, como al andar).
local function puntaEntrando(g: Gateo, patas: { Pata }, i: number, u: number, simple: boolean): Vector3
	local pos = g.puntas0[i]
	local primero = patas[i].desfase == 0
	for k, paso in GATEO.Pasos do
		local ini = if primero then paso[1] else paso[2]
		local fin = if primero then paso[2] else paso[3]
		if u <= ini then
			return pos
		end
		local destino = planta(g, patas, k, i, simple)
		if u < fin then
			return pisada(pos, destino, u, ini, fin)
		end
		pos = destino
	end
	return pos
end

-- Los ruidos del gateo: 1 se aplasta; 2 y 3, cada tirón (araña el suelo); 4, el último, un chillido que se corta.
local function ruidoGateo(b: Bicho, n: number)
	local donde = b.cabeza.Position
	if n == 1 then
		Sonido.en("Paso", b.raiz.Position - Vector3.new(0, 1.5, 0), 1.3)
		Sonido.en("Cruje", donde, 1.1)
		return
	end
	Sonido.en("Aranazo", donde, if n == 4 then 1.35 else 1.2)
	if n == 4 then
		local corto = Sonido.en("Chillido", donde, 1.6)
		task.delay(0.35, function()
			if corto.Parent then
				corto:Stop()
			end
		end)
	end
end

-- Empieza un gateo: el marco de cara a ti, el tablero en cada carril, cuánto se echa atrás (que ni la cabeza ni las
-- rodillas queden sobre la mesa al aplastarse) y hasta dónde se cuela (su frente a GATEO.Hasta de ti, sin pasar de
-- GATEO.Dentro por debajo del tablero). Sale de la pose del fotograma anterior: así no salta si empieza otro.
local function empezarGateo(b: Bicho, punto: Vector3, hora: number, torsoT: CFrame): Gateo
	local m = b.motores
	local enRaiz = b.raiz.CFrame:PointToObjectSpace(punto)
	local plano = Vector3.new(enRaiz.X, 0, enRaiz.Z)
	local lejos = plano.Magnitude
	local marco = CFrame.new(0, -ALTURA, 0) * CFrame.Angles(0, if lejos > 0.3 then math.atan2(-plano.X, -plano.Z) else 0, 0)
	local antes = b.ultimoTorso
	local torso0 = marco:Inverse() * (antes or m.Torso.C0 * torsoT * m.Torso.C1:Inverse())
	local puntas0 = {}
	for i in b.patas do
		puntas0[i] = marco:PointToObjectSpace(if antes then b.ultimas[i] else b.puntas[i])
	end
	local bordes = buscarBordes(b.raiz.CFrame * marco, lejos)
	local cabeza = bordeEntre(bordes, -0.7, 0.7)
	local rodillas = math.min(bordeEntre(bordes, -5.5, -0.2), bordeEntre(bordes, 0.2, 5.5))
	local f0 = -torso0.Position.Z -- studs que el torso está por delante del marco
	local atras = math.clamp(math.min(cabeza - CABEZA_FRENTE, rodillas - RODILLA) - GATEO.Margen, f0 - GATEO.AtrasMax, f0)
	local fin = math.clamp(lejos - GATEO.Hasta - CABEZA_FRENTE, atras, math.max(atras, cabeza + GATEO.Dentro - CABEZA_FRENTE))
	return {
		hora = hora, punto = punto, t = 0, sonados = 0, pisadas = 0, sale = 0, levanta = false, marco = marco,
		bordes = bordes, torso0 = torso0, puntas0 = puntas0, cabeza0 = b.ultimaCabeza, boca0 = b.ultimaBoca, zAtras = -atras,
		zFin = -fin, plantas = {}, plantasSimple = {}, salida = nil,
	}
end

-- El gateo, en lugar de la pose de siempre (`torsoT` y b.puntas, ya calculadas este fotograma; la cabeza y la boca ya
-- están en sus juntas): devuelve el torso y deja en b.puntas dónde va cada punta. Con Gatea y GateaHora en el modelo se
-- cuela; sin ellos, saca la cabeza, se retira y se levanta hasta quedar justo en la pose de siempre.
local function gatear(b: Bicho, dt: number, ahora: number, poco: boolean, torsoT: CFrame, chillando: boolean): CFrame
	local punto = b.modelo:GetAttribute("Gatea")
	local hora = b.modelo:GetAttribute("GateaHora")
	local activo = typeof(punto) == "Vector3" and typeof(hora) == "number"
	local dura = duraGateo()
	local g = b.gatea
	if activo then
		if not g or g.hora ~= hora then
			g = empezarGateo(b, punto, hora, torsoT)
			b.gatea = g
		end
		local actual = g :: Gateo
		actual.punto = punto
		actual.t = math.clamp(workspace:GetServerTimeNow() - hora, 0, dura)
	end
	if not g then
		return torsoT
	end
	local m = b.motores
	local marco = g.marco
	-- Gateando (o mientras dura el susto si te ha pillado) se aplasta; al acabar, se retira y luego se levanta.
	if activo or ahora - b.agarra < GATEO.Susto then
		b.gateo = 1
	else
		g.sale = math.min(1, g.sale + dt / GATEO.Sale)
		if g.sale >= 1 then
			if not g.levanta then
				g.levanta = true
				b.retiro = marco.Rotation * Vector3.new(0, 0, g.zAtras) -- se levanta ahí y ahí se queda
			end
			b.gateo = math.max(0, b.gateo - dt / GATEO.Levanta)
		end
	end
	if b.gateo <= 0 then
		b.gatea = nil
		return torsoT
	end
	local u = g.t * 2 / dura
	local a, olfatea, empuje = avanceGateo(u, poco)
	local husmea = if poco then 0 else olfatea
	local cuerpo = torsoEntrando(g, u, poco)
	local sale = suave(g.sale)
	local levanta = if g.levanta then 1 - b.gateo else 0
	local patas = b.patas
	if g.sale > 0 then
		-- Sale: el torso vuelve a donde se echó atrás y las patas, a donde les toca ahí.
		local z = cuerpo.Position.Z
		local salida = g.salida
		if not salida then
			salida = {}
			for i, p in patas do
				salida[i] = plantar(g, p, (z + g.zAtras) / 2)
			end
			g.salida = salida
		end
		local hasta = salida :: { Vector3 }
		local fuera = CFrame.new(cuerpo.Position.X, cuerpo.Position.Y, z + (g.zAtras - z) * sale) * cuerpo.Rotation
		local normal = marco:Inverse() * (m.Torso.C0 * torsoT * m.Torso.C1:Inverse())
		cuerpo = fuera:Lerp(normal, suave(levanta))
		for i, p in patas do
			-- Cada par en media vuelta; levantándose, de ahí a su pose de siempre (al acabar, justo ella: no salta).
			local ini, fin = if p.desfase == 0 then 0 else 0.45, if p.desfase == 0 then 0.45 else 0.9
			local desde = pisada(puntaEntrando(g, patas, i, u, poco), hasta[i], g.sale, ini, fin)
			b.puntas[i] = marco * pisada(desde, marco:PointToObjectSpace(b.puntas[i]), levanta, ini, fin)
		end
		a, husmea, empuje = a * (1 - sale), 0, 0
	else
		-- Olfateando: respira contra el suelo.
		cuerpo *= CFrame.new(0, husmea * 0.03 * math.sin(ahora * 21), 0)
		for i in patas do
			b.puntas[i] = marco * puntaEntrando(g, patas, i, u, poco)
		end
	end
	local nuevoT = m.Torso.C0:Inverse() * (marco * cuerpo) * m.Torso.C1

	-- La cabeza: mientras se echa atrás y se aplasta, derecha y con la boca cerrada (del revés, la boca le queda arriba y
	-- por detrás: al cabecear o abrirla bajo el tablero, lo rozaría). Ya abajo, de cara a ti y a tu altura, sin cabecear
	-- hacia el suelo; olfateando, a golpecitos; con cada tirón, un empujón; si chilla, temblando.
	local junta = b.raiz.CFrame * marco * cuerpo * m.Cabeza.C0
	local suelo = b.raiz.Position.Y - ALTURA
	local mira = Vector3.new(g.punto.X, suelo + math.clamp(g.punto.Y - suelo, 0.6, 2), g.punto.Z)
	local cabeceo, giro = mirada(junta, mira)
	cabeceo = math.max(cabeceo, 0.03)
	giro += husmea * 0.12 * math.sin(ahora * 7) + (if chillando then math.sin(ahora * 30) * 0.2 else 0)
	local derecha = if g.sale > 0 then 1 else echado(u)
	local abajo = if g.sale > 0 then 1 else suave(math.clamp((u - GATEO.Atras) / (GATEO.Cae - GATEO.Atras), 0, 1))
	local cabezaT = g.cabeza0:Lerp(CFrame.new(), derecha):Lerp(CFrame.fromEulerAnglesYXZ(cabeceo, giro, husmea * 0.08
		* math.sin(ahora * 9)) * CFrame.new(0, 0, -0.15 * empuje), abajo)
	m.Cabeza.Transform = cabezaT:Lerp(m.Cabeza.Transform, suave(levanta))
	-- La boca, abriéndose según se cuela; olfateando, a golpecitos; con cada tirón, un chasquido; si te pilla, chillando.
	local abre = (0.15 + 0.3 * a + husmea * 0.08 * math.abs(math.sin(ahora * 13)) + 0.2 * empuje
		+ (if chillando then 0.55 + 0.1 * math.sin(ahora * 35) else 0)) * abajo
	local boca = g.boca0:Lerp(CFrame.new(), derecha) * CFrame.Angles(-abre, 0, 0)
	m.Mandibula.Transform = boca:Lerp(m.Mandibula.Transform, suave(levanta))

	-- Los ruidos, cada uno una vez (con Rendimiento, solo al aplastarse y el chillido del final), y las pisadas.
	if activo and g.sonados < #RUIDOS and u >= RUIDOS[g.sonados + 1] then
		g.sonados += 1
		if u < RUIDOS[g.sonados] + 0.15 and (not poco or g.sonados == 1 or g.sonados == #RUIDOS) then
			ruidoGateo(b, g.sonados) -- si llega tarde, los que ya han pasado no suenan todos de golpe
		end
	end
	if activo and g.pisadas < #PISADAS and u >= PISADAS[g.pisadas + 1] then
		g.pisadas += 1
		if not poco and u < PISADAS[g.pisadas] + 0.1 then
			Sonido.en("Paso", b.raiz.Position - Vector3.new(0, 1.5, 0), azar:NextNumber(1.5, 1.7))
		end
	end
	return nuevoT
end

local function apagar()
	if conexion then
		conexion:Disconnect()
		conexion = nil
	end
end

-- A dónde da el próximo tirón de la cabeza: al jugador más cercano, a cualquier lado de golpe o un tironcito.
local function decidirTiron(b: Bicho, ahora: number, desde: Vector3)
	b.tiron = ahora + rango(TIRON)
	local suerte = azar:NextNumber()
	b.mira = if suerte < 0.4 then jugadorCerca(desde, VER) else nil
	local ladeo = azar:NextNumber(-0.3, 0.3)
	if b.mira then
		b.meta = Vector3.new(b.cab.X, b.cab.Y, ladeo) -- el cabeceo y el giro, en cada fotograma
	elseif suerte < 0.75 then
		b.meta = Vector3.new(azar:NextNumber(-0.4, 0.45), azar:NextNumber(-GIRO, GIRO), ladeo)
	else
		local m = b.meta
		b.meta = Vector3.new(
			math.clamp(m.X + azar:NextNumber(-0.12, 0.12), -0.6, 0.6),
			math.clamp(m.Y + azar:NextNumber(-0.25, 0.25), -GIRO, GIRO),
			math.clamp(m.Z + azar:NextNumber(-0.2, 0.2), -0.9, 0.9)
		)
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
			bichos[modelo] = nil
			continue
		end
		-- La raíz va anclada en la pared y el tejado: la rapidez sale de cuánto se ha movido.
		local pos = b.raiz.Position
		local movido = (pos - b.antes).Magnitude
		b.antes = pos
		if movido > 8 then
			movido = 0 -- un salto (le han llevado de golpe a otro sitio)
		end
		b.rapidez += (movido / math.max(dt, 1 / 240) - b.rapidez) * math.min(1, dt * 8)
		-- Por dentro del tiro no se ve: va por el ladrillo y las patas asomarían al dormitorio.
		local bajando = modelo:GetAttribute("Bajando") == true
		if b.oculto ~= bajando then
			b.oculto = bajando
			for _, parte in b.partes do
				parte.LocalTransparencyModifier = if bajando then 1 else 0
			end
		end
		local distancia = (pos - ojo).Magnitude
		if distancia > LEJOS then
			continue
		end
		local m = b.motores
		local trepando = modelo:GetAttribute("Trepando") == true
		local arriba = trepando or modelo:GetAttribute("EnTejado") == true
		local chillando = ahora - b.chillido < 1.8
		local paso = math.min(1, b.rapidez / 5)
		local zancada = math.min(1, b.rapidez / 2)
		b.fase += dt * b.rapidez * RITMO
		local s = math.sin(b.fase)
		local gateando = b.gatea ~= nil or modelo:GetAttribute("Gatea") ~= nil -- mientras gatea, la vida de espera se pausa
		b.vida = acercar(b.vida, if b.rapidez < QUIETO and not chillando and not bajando and not gateando and distancia < vidaLejos
			then 1 else 0, dt, 4)
		if b.rapidez > QUIETO and not gateando then
			b.retiro *= math.max(0, 1 - dt * 2) -- retirado tras gatear: al volver a andar, vuelve a su sitio
		end
		local vida = b.vida
		b.amenaza = acercar(b.amenaza, if chillando then 1 else 0, dt, if chillando then 10 else 3)
		local amenaza = b.amenaza
		b.suelo = acercar(b.suelo, if trepando then SUELO_PARED else SUELO, dt, 6)

		-- Se para a escuchar: clavado y sin respirar; al acabar suelta el aire de golpe y da un tirón con la cabeza.
		local escuchando = ahora < b.escuchaHasta
		if escuchando and (vida < 0.5 or chillando) then
			b.escuchaHasta = ahora -- se mueve o chilla: deja de escuchar
			escuchando = false
		end
		if b.escuchaba and not escuchando then
			b.escuchaba = false
			b.tiron = ahora
			if vida > 0.5 then
				b.jadeo = ahora
				if noche and not poco and distancia < VAHO_LEJOS then
					echarVaho(b, VAHO_SUELTA)
				end
				if arriba then
					crujir(b, ahora, 1.4)
				end
			end
		end
		if not escuchando and vida > 0.8 and not chillando and ahora >= b.proximaEscucha then
			escuchando = true
			b.escuchaba = true
			b.escuchaHasta = ahora + rango(DURA_ESCUCHA)
			b.proximaEscucha = b.escuchaHasta + rango(ESCUCHA)
			-- Hacia quien tenga más cerca (en el tejado, los de dentro); si no hay nadie, hacia abajo. Muy ladeada.
			b.mira = jugadorCerca(b.cabeza.Position, VER)
			local lado = if azar:NextNumber() < 0.5 then -1 else 1
			b.meta = Vector3.new(0.35, azar:NextNumber(-0.5, 0.5), lado * azar:NextNumber(0.6, 0.85))
		end
		b.escucha = acercar(b.escucha, if escuchando then 1 else 0, dt, if escuchando then 9 else 4)
		local escucha = b.escucha * vida

		-- Jadea deprisa (escuchando, aguanta el aire); de noche, al soltarlo, echa vaho.
		b.respira += dt * 2 * math.pi / RESPIRA * (1 - b.escucha)
		local aire = math.sin(b.respira) -- más: coge aire; menos: lo suelta
		local soltando = math.cos(b.respira) < 0
		if soltando and not b.exhala and noche and not poco and vida > 0.5 and b.escucha < 0.3 and distancia < VAHO_LEJOS then
			echarVaho(b, VAHO)
		end
		b.exhala = soltando

		-- El peso de un lado a otro, las patas que mueve o se le crispan, la sacudida rara y los dientes.
		b.peso += dt * 2 * math.pi / PESO
		local w = math.sin(b.peso) * vida * (1 - b.escucha)
		if vida < 0.1 then
			for _, p in b.patas do
				p.apoyo, p.antes = Vector3.zero, Vector3.zero -- andando: al pararse apoya cada pata en su sitio
			end
		elseif vida > 0.6 and b.escucha < 0.1 and ahora >= b.proximaMueve then
			b.proximaMueve = ahora + rango(MUEVE)
			local n = azar:NextInteger(1, #b.patas - 1)
			if n >= b.ultimaPata then
				n += 1 -- nunca la misma dos veces seguidas
			end
			b.ultimaPata = n
			local p = b.patas[n]
			p.antes = p.apoyo
			p.apoyo = Vector3.new(azar:NextNumber(-0.35, 0.35), 0, azar:NextNumber(-0.5, 0.5))
			p.movida = ahora
			if arriba and ahora - b.crujio > CRUJE_PATA and azar:NextNumber() < 0.5 then
				crujir(b, ahora, 1.1)
			end
		end
		if vida > 0.5 and ahora >= b.proximaCrispa then
			b.proximaCrispa = ahora + rango(CRISPA)
			b.patas[azar:NextInteger(1, #b.patas)].crispa = ahora
		end
		if vida > 0.8 and b.escucha < 0.1 and ahora >= b.proximaSacudida then
			b.proximaSacudida = ahora + rango(SACUDIDA)
			b.sacudida = ahora
			if arriba and ahora - b.crujio > 1 then
				crujir(b, ahora, 1.4)
			end
		end
		local ts = math.min(ahora - b.sacudida, DURA_SACUDIDA) -- con tope: math.sin(inf) da NaN, y 0 · NaN = NaN
		local sac = if ts < DURA_SACUDIDA then (1 - ts / DURA_SACUDIDA) ^ 2 * vida else 0
		if vida > 0.5 and ahora >= b.proximoCastaneo then
			b.proximoCastaneo = ahora + rango(CASTANETEA)
			b.castaneo = ahora
		end
		local tj = ahora - b.jadeo
		local jadeo = if tj < 0.6 then math.sin(math.pi * tj / 0.6) * vida else 0

		-- Torso: andando se mece; parado, agazapado, jadeando y pasando el peso; escuchando, más bajo y la cabeza
		-- por delante; chillando, se levanta.
		local agazapa = vida * (AGAZAPA + (AGAZAPA_ESCUCHA - AGAZAPA) * b.escucha)
		local torsoT = CFrame.new(
			0.2 * w + sac * 0.06 * math.sin(ts * 47),
			math.abs(s) * 0.15 * paso - agazapa + 0.05 * aire * vida * (1 - b.escucha) - 0.08 * jadeo + 0.25 * amenaza,
			0.3 * amenaza
		) * CFrame.Angles(
			0.32 * amenaza - 0.07 * escucha + 0.02 * aire * vida + sac * 0.05 * math.sin(ts * 39),
			0,
			s * 0.06 * paso + 0.05 * w + sac * 0.1 * math.sin(ts * 29)
		)
		torsoT = m.Torso.C0:Inverse() * CFrame.new(b.retiro) * m.Torso.C0 * torsoT
		local torsoCF = m.Torso.C0 * torsoT * m.Torso.C1:Inverse() -- el torso, en la raíz

		-- Patas: cada punta a su sitio (en la raíz); las juntas, por cinemática inversa al final (tras el gateo).
		local alza = SUELO - b.suelo
		for i, p in b.patas do
			-- Andando: media vuelta la punta va hacia atrás pegada al suelo, tan deprisa como avanza el cuerpo (no
			-- resbala), y la otra media se adelanta por el aire.
			local u = ((b.fase + p.desfase) / (2 * math.pi)) % 1
			local x, y, z = 0, 0, 0
			if u < 0.5 then
				z = ZANCADA * (4 * u - 1)
			else
				local k = (u - 0.5) * 2
				z = ZANCADA * (1 - 2 * suave(k))
				y = ALZA * math.sin(math.pi * k)
			end
			y = alza + y * zancada
			z *= zancada
			-- Parado: donde la apoyó; si la está moviendo, por el aire de un sitio al otro.
			local apoyo = p.apoyo
			local tm = ahora - p.movida
			local levanta = 0
			if tm < DURA_MUEVE then
				local q = tm / DURA_MUEVE
				apoyo = p.antes:Lerp(p.apoyo, suave(q))
				levanta = 0.55 * math.sin(math.pi * q)
			end
			x += apoyo.X * vida
			z += apoyo.Z * vida
			y += (levanta + 0.35 * crispacion(ahora - p.crispa) + sac * 0.3 * math.max(0, math.sin(ts * 31 + i * 1.7))) * vida
			-- Chillando, las de delante en alto, temblando.
			if p.delante and amenaza > 0.01 then
				x += AMENAZA.X * amenaza
				y += (AMENAZA.Y + 0.15 * math.sin(ahora * 45 + i)) * amenaza
				z += AMENAZA.Z * amenaza
			end
			b.puntas[i] = p.reposo + Vector3.new(p.lado * x, y, z) + b.retiro
		end

		-- La cabeza (del revés): a tirones; escuchando, quieta y ladeada hacia quien tenga más cerca.
		local junta = b.raiz.CFrame * torsoCF * m.Cabeza.C0
		if vida > 0.05 then
			if not escuchando and ahora >= b.tiron then
				decidirTiron(b, ahora, junta.Position)
			end
			local suya = b.mira
			if suya then
				if suya.Parent then
					local cabeceo, giro = mirada(junta, suya.Position)
					b.meta = Vector3.new(cabeceo, giro, b.meta.Z)
				else
					b.mira = nil
				end
			end
			b.cab = b.cab:Lerp(b.meta, math.min(1, dt * (if escuchando then 7 else 20)))
		end
		local tiron = if math.noise(ahora * 1.5, b.semilla) > 0.3 then 0.6 else 0
		local andando = Vector3.new(0, (1 - paso) * tiron, math.sin(ahora * 0.8) * 0.15)
		local viva = b.cab
			+ Vector3.new(
				sac * 0.2 * math.sin(ts * 17),
				sac * 0.4 * math.sin(ts * 13),
				sac * 1.1 * math.sin(ts * 21) + escucha * 0.02 * math.sin(ahora * 53)
			)
		local h = andando:Lerp(viva, vida)
		m.Cabeza.Transform = CFrame.fromEulerAnglesYXZ(h.X, h.Y + (if chillando then math.sin(ahora * 30) * 0.2 else 0), h.Z)

		-- La boca: entreabierta; jadeando al soltar el aire; los dientes que castañetean; del todo al chillar.
		local tc = ahora - b.castaneo
		local abre = 0.15 + math.max(0, math.sin(ahora * 2.3)) * 0.1 * (1 - vida)
			+ vida * (0.06 * math.max(0, -aire) * (1 - b.escucha) + 0.12 * b.escucha)
			+ (if tc < 0.7 then math.abs(math.sin(tc * 38)) * 0.14 * vida else 0)
			+ 0.35 * jadeo
			+ sac * 0.3 * math.abs(math.sin(ts * 25))
			+ (if chillando then 0.7 + 0.1 * math.sin(ahora * 35) else 0)
		m.Mandibula.Transform = CFrame.Angles(-abre, 0, 0)

		-- Debajo de un mueble: se aplasta y gatea a por ti, encima de todo lo anterior. Luego, las patas.
		torsoT = gatear(b, dt, ahora, poco, torsoT, chillando)
		m.Torso.Transform = torsoT
		torsoCF = m.Torso.C0 * torsoT * m.Torso.C1:Inverse()
		b.ultimoTorso = torsoCF
		b.ultimaCabeza, b.ultimaBoca = m.Cabeza.Transform, m.Mandibula.Transform
		for i, p in b.patas do
			b.ultimas[i] = b.puntas[i]
			pisar(p, torsoCF:PointToObjectSpace(b.puntas[i]))
		end

		-- Pasos pesados y crujidos en la pared y el tejado (escuchando, silencio); en el suelo, pasos normales.
		local pie = if s >= 0 then 1 else -1
		if b.rapidez > 1.5 and pie ~= b.pisada then
			b.pisada = pie
			if arriba then
				fuerte("Paso", pos, azar:NextNumber(0.55, 0.7), 1.6)
			else
				Sonido.en("Paso", pos - Vector3.new(0, 2, 0), 1.2)
			end
		end
		if arriba and ahora > b.crujido then
			if escuchando then
				b.crujido = ahora + 0.5
			else
				crujir(b, ahora, 1.6)
			end
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
	if not modelo:IsA("Model") or modelo.Name ~= "Trepador" then
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
	local torso = motores.Torso
	local base = torso.C0 * torso.C1:Inverse()
	local patas = {}
	for _, datos in PATAS do
		local p = medirPata(motores[datos.arriba], motores[datos.abajo], datos.lado, base)
		if not p then
			return
		end
		p.desfase, p.delante = datos.desfase, datos.delante
		table.insert(patas, p)
	end
	if not modelo.Parent then
		return
	end
	local partes = {}
	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") and d ~= raiz then
			table.insert(partes, d)
		end
	end
	local ahora = os.clock()
	bichos[modelo :: Model] = {
		modelo = modelo :: Model, raiz = raiz, cabeza = cabeza, motores = motores, patas = patas, partes = partes,
		oculto = nil, antes = raiz.Position, rapidez = 0, fase = 0, pisada = 1, chillido = -math.huge,
		crujido = ahora + 2, crujio = -math.huge, semilla = azar:NextNumber(0, 100), vida = 0, suelo = SUELO,
		amenaza = 0, respira = azar:NextNumber(0, 2 * math.pi), exhala = false, peso = azar:NextNumber(0, 2 * math.pi),
		cab = Vector3.zero, meta = Vector3.zero, mira = nil, tiron = ahora + 0.5,
		escucha = 0, escuchaba = false, escuchaHasta = 0, proximaEscucha = ahora + rango(ESCUCHA), jadeo = -math.huge,
		proximaMueve = ahora + rango(MUEVE), ultimaPata = 1, proximaCrispa = ahora + rango(CRISPA),
		sacudida = -math.huge, proximaSacudida = ahora + rango(SACUDIDA),
		castaneo = -math.huge, proximoCastaneo = ahora + rango(CASTANETEA),
		gateo = 0, gatea = nil, agarra = -math.huge, retiro = Vector3.zero, puntas = table.create(#patas, Vector3.zero),
		ultimas = table.create(#patas, Vector3.zero), ultimoTorso = nil, ultimaCabeza = CFrame.new(), ultimaBoca = CFrame.new(),
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

-- Una nube de hollín negro (al bajar cae al hogar; al salir, revienta hacia el salón).
local function hollin(cf: CFrame, cuanto: number, hacia: Vector3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(2, 2, 2)
	p.CFrame = cf
	p.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.LightInfluence = 1
	e.Color = ColorSequence.new(Color3.fromRGB(18, 16, 15))
	e.Transparency = NumberSequence.new(0.2, 1)
	e.Size = NumberSequence.new(1.5, 5)
	e.Lifetime = NumberRange.new(1.5, 3)
	e.Speed = NumberRange.new(4, 12)
	e.SpreadAngle = Vector2.new(50, 50)
	e.Acceleration = hacia
	e.EmissionDirection = Enum.NormalId.Top
	e.Rate = 0
	e.Parent = p
	e:Emit(cuanto)
	task.delay(4, function()
		p:Destroy()
	end)
end

-- Para MuerteVista (quién te ha pillado, PosturaReglas.quienPilla): los Trepadores a menos de 12 de `punto` (la
-- cara del susto), sin tocarlos: su modelo, a cuánto tiene la cabeza de `punto` y dónde estaba el escondido a por
-- el que gatea (si gatea).
function TrepadorVista.candidatos(punto: Vector3): { { modelo: Model, distancia: number, gatea: Vector3? } }
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

-- Chilla con las patas de delante en alto (el susto al morir; si gateaba, aplastado). Devuelve el Trepador cerca de
-- `punto`, si hay.
-- `modelo`: el que ha elegido MuerteVista (si no es un Trepador, nada); sin él, el más cerca de `punto`.
function TrepadorVista.rugir(punto: Vector3, modelo: Model?): Model?
	local b = if modelo then bichos[modelo] else cercano(punto, 12)
	if b then
		b.chillido = os.clock()
		if b.gatea then
			b.agarra = os.clock() -- te ha pillado gateando: se queda aplastado mientras dura el susto
		end
		return b.modelo
	end
	return nil
end

function TrepadorVista.start()
	local carpeta = workspace:WaitForChild("Bichos")
	carpeta.ChildAdded:Connect(preparar)
	for _, modelo in carpeta:GetChildren() do
		task.spawn(preparar, modelo)
	end
	Remotes.Trepador.OnClientEvent:Connect(function(tipo: string, modelo: Model)
		local chimenea = CollectionService:GetTagged("Chimenea")[1]
		local b = modelo and bichos[modelo]
		if not chimenea then
			return
		end
		local tiro = chimenea:GetAttribute("Tiro")
		local hogar = chimenea:GetAttribute("Hogar")
		if typeof(tiro) ~= "Vector3" or typeof(hogar) ~= "CFrame" then
			return -- la chimenea aún sin sus atributos: sin hollín ni ruidos
		end
		if tipo == "Baja" then
			-- Se arrastra por dentro del tiro, de arriba abajo; cae hollín al hogar.
			fuerte("Hollin", Vector3.new(tiro.X, 24, tiro.Z), 0.8, 1.8)
			task.delay(1.8, function()
				fuerte("Hollin", Vector3.new(tiro.X, 12, tiro.Z), 0.7, 2)
				hollin(hogar * CFrame.new(0, 1.5, 0), 25, Vector3.new(0, -6, 0))
			end)
			task.delay(3.2, function()
				fuerte("Crujido", Vector3.new(tiro.X, 6, tiro.Z), 0.6, 2)
			end)
		elseif tipo == "Entra" then
			-- Hacia el salón: el frente del Hogar (LookVector) mira a la pared de la chimenea.
			hollin(hogar * CFrame.new(0, 1.5, 0), 60, -hogar.LookVector * 6 + Vector3.new(0, 2, 0))
			Sonido.en("Chillido", hogar.Position, 1.25)
			Sonido.en("Rugido", hogar.Position, 1.3)
			if b then
				b.chillido = os.clock() + 1
			end
		elseif tipo == "Quema" and b then
			b.chillido = os.clock() + 0.8
			fuerte("Chillido", b.raiz.Position, 1.5, 2)
			hollin(CFrame.new(tiro), 30, Vector3.new(0, 6, 0))
		end
	end)
end

return TrepadorVista
