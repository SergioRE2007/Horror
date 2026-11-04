-- Mueve el cuerpo del Imitador en el cliente (el servidor lo desplaza y publica el atributo Abierto). Todo con la
-- Transform de sus Motor6D: no toca lo que hace el servidor ni la física (sus piezas no chocan ni pesan; los adornos van
-- soldados a su miembro y le siguen solos).
--   Anda tieso, sin mover los brazos.
--   En la puerta, DEMASIADO quieto (pedido por el usuario: los bichos con vida mientras esperan; él, al revés): no
--   respira ni cambia el peso. Tiene la cabeza ladeada como escuchando, que se le va torciendo despacio, demasiado, con
--   algún tirón; se le crispan los dedos de vez en cuando y entre llamada y llamada da algún golpecito con los nudillos
--   en la puerta (dos toques flojos, la mano al compás del sonido).
--   Remote Imitador "Llama": tres golpes en la puerta (la mano llega justo a la hoja, sin atravesarla, al compás de la
--   grabación) y mueve la boca como si hablase; de noche le sale vaho al hablar y solo entonces (sin él con
--   Rendimiento). "Entra": se le estira el cuello, abre la boca del todo y chilla.
--   La mirilla (pedido por el usuario: que sirva para saber que no es tu amigo). Mientras el jugador local mira por la
--   de la puerta principal (su atributo LOCAL "Mirilla", lo pone MirarVista) y el Imitador espera en esa puerta: primero
--   se ve su silueta quieta a contraluz, unos pasos atrás (ya puesto ahí mientras la vista está en negro; si ya mirabas
--   cuando llegó, da esos pasos delante de ti); a 1,5 s gira la cara despacio hacia la mirilla, se dobla y se acerca; y
--   de golpe se pega a ella, la cara llenando la mirilla (Sobresalto y un golpe sordo en la puerta), y al rato da un
--   golpecito junto a ella. Una vez por llamada; si vuelves a mirar en la misma, se queda doblado delante de la
--   mirilla, mirándote, sin moverse. La pose sale de cuentas (cinemática inversa del cuello).
-- ImitadorVista.candidatos(punto) y rugir(punto, modelo): para el susto al morir.
-- Un solo bucle (Stepped) mientras haya alguno; solo cerca de la cámara.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sonido = require(script.Parent.Sonido)

local ImitadorVista = {}

-- Números visuales (a ojo; se retocan en Studio).
local LEJOS = 250 -- studs de la cámara: más lejos no se anima
local CERCA = 120 -- más lejos, sin detalles (crispaciones, tirones)
local VAHO_LEJOS = 60 -- studs: más lejos no se le ve el vaho
local MOTORES = { "Torso", "Cuello", "Cabeza", "Mandibula", "BrazoI", "BrazoD", "PiernaI", "PiernaD" }
local LARGO_BRAZO = 4.45 -- del hombro a la punta de los dedos (Imitador.luau: brazo de 3,8 y dedos de 0,8)
local HOJA = 0.175 -- media hoja de la puerta (Mapa: 0,35 de grueso)
local DELANTE = 2.5 -- studs delante de la puerta donde se planta (Imitador.luau)
local LLAMADA = 1.6 -- segundos de los tres golpes
-- Cuándo suena cada golpe en la grabación "Llamar" (y "Toc", que es la misma) a tono 1: el primero y cada cuánto.
local GOLPES = { Primero = 0.355, Cada = 0.42 }
local HABLA = { 0.25, 2.6 } -- de cuándo a cuándo mueve la boca después de llamar
local LADEO = { 0.15, 0.62 } -- radianes de la cabeza: al acabar de hablar y lo que llega a torcerse
local LADEA = 9 -- segundos en torcerse del todo
local TIRON = { 1.6, 4.5 } -- segundos entre tirones de la cabeza
-- Esperando, algún golpecito con los nudillos: segundos entre uno y otro, toques (la grabación se corta después),
-- tono (más agudo que la llamada: más deprisa) y volumen.
local GOLPECITO = { Cada = { 4, 8 }, Toques = 2, Tono = 1.18, Volumen = 0.4 }
local CRISPA = { 5, 11 } -- segundos entre crispaciones de los dedos
-- La mirilla (segundos desde que empiezas a mirar y studs).
local MIRILLA = {
	Radio = 9, -- studs de la cámara a los que tiene que estar
	Negro = 0.12, -- segundos desde que miras en que la vista aún está en negro (MirarVista la abre en 0,15)
	Silueta = 1.5, -- quieto a contraluz
	Gira = 1.4, -- girando la cara hacia la mirilla
	Acerca = 2.3, -- doblándose hacia ella...
	Empieza = 0.75, -- ...desde que lleva esta parte de la vuelta
	Pega = { 3.9, 4.8 }, -- cuándo se pega de golpe (a medio doblarse o casi doblado: no se sabe cuándo)
	Golpe = 0.09, -- lo que tarda en pegarse
	Atras = 4.6, -- se le ve más atrás que donde está (para que se le vea entero; el porche llega a 8 de la puerta)
	Retrocede = 1.3, -- si ya mirabas cuando llegó: segundos en dar esos pasos atrás delante de ti...
	Zancada = 0.4, -- ...con dos zancadas lentas (radianes de las piernas)
	Cerca = 2.6, -- de la cámara a la cara al acabar de acercarse
	Pegado = 0.75, -- de la cámara a la cara pegada (la cara llena la mirilla)
	Holgura = 0.3, -- la cara nunca a menos de esto de la hoja, por fuera
	Toc = 1.2, -- segundos pegado hasta que da un golpecito junto a la mirilla
	Espalda = 0.55, -- brillo de la luz de luna detrás de él (silueta a contraluz)
	Cara = 0.85, -- brillo de la luz floja que le da en la cara pegada
}
local DOBLA_MAX = 2.1 -- radianes: lo más que se dobla por la cintura
local CUELLO_K, CUELLO_MAX = 0.6, 0.9 -- doblado, cuánto echa el cuello hacia atrás para mirar al frente
local BRAZO_K, BRAZO_ABRE = 0.55, 0.2 -- doblado, los brazos cuelgan hacia atrás y algo abiertos (sin tocar el suelo)
-- Gatear a por quien se esconde debajo de un mueble (studs y segundos; el tiempo, en parte de Config.Postura.Gatear).
local ALTURA = 5 -- de los pies al centro de la raíz (Imitador.luau)
local GATEAR = Config.Postura.Gatear -- segundos que dura (desde GateaHora)
local GATEO = {
	Cae = 0.3, -- segundos en echarse al suelo
	Vuelve = 0.7, -- segundos en volver a su pose si no te pilla
	Tirones = { 0.18, 0.36, 0.64, 0.84 }, -- cuándo da cada tirón hacia ti...
	Tiron = 0.09, -- ...y lo que dura cada uno
	Olfatea = { 0.47, 0.62 }, -- la parada de olfatear
	Brazo = 4.45, -- del hombro a la punta de los dedos (LARGO_BRAZO)
	Llega = 0.9, -- la punta de los dedos, a esto de ti al acabar
	Fuera = 0.8, -- al echarse, la mano en el suelo a esto por fuera del borde
	Hombro = 0.55, -- el hombro, al menos a esto por fuera del borde
	Holgura = 0.45, -- el brazo pasa a esto (como poco) por fuera de la esquina de abajo del tablero (lo gordo del brazo)
	Encorva = 0.75, -- radianes que se le dobla la espalda hacia delante
	Cabeza = 1.25, -- altura del centro de la cabeza: la cara a ras de suelo, a la altura de tus ojos
	Asoma = 0.1, -- la cara, a esto del borde por fuera (al acabar)
	Ladeo = 0.8, -- radianes de la cabeza ladeada mirándote
	Alto = 2.85, -- sin tablero que choque: a esta altura (la mesa del comedor; y el borde a 1,6 de ti)
	Luz = 0.5, -- brillo de la luz floja en la cara (solo cerca)
	Recoge = 0.35, -- segundos en sacar la mano y la cabeza de debajo al acabar, antes de levantarse
	Aparta = 0.8, -- echándose y levantándose, la cara algo más lejos del borde (si no, al subir rozaba el tablero)
	Cadera = 0.15, -- lo más bajo de la cadera, a esto del suelo como poco (encorvado, se metía en él)
}

type Mirilla = {
	inicio: number, -- os.clock en que empezaste a mirar
	pega: number, -- segundos desde el inicio en que se pega
	susto: boolean, -- esta vez se pega (una vez por llamada)
	atras: number, -- studs que se le ve más atrás
	retrocede: boolean, -- ya mirabas cuando llegó: da esos pasos atrás delante de ti
	mezcla: number, -- 0..1: cuánto manda esta pose sobre la de siempre
	sono: boolean,
	toc: boolean,
	luzCara: PointLight?,
	luzEspalda: Attachment?,
	pose: { [string]: CFrame },
}

type Gateo = {
	punto: Vector3, -- Gatea: dónde está el jugador debajo (mundo)
	hora: number, -- GateaHora (hora del servidor)
	inicio: number, -- os.clock en que empezó aquí
	borde: number, -- studs (en planta) de la raíz al borde del mueble, hacia el jugador...
	bordeBrazo: number, -- ...y por el lado del brazo que mete
	alto: number, -- studs del suelo a lo de abajo del tablero
	mezcla: number, -- 0..1: cuánto manda gatear sobre la pose de siempre (lineal; se suaviza al usarla)
	fin: number?, -- os.clock en que se quitó Gatea
	k: number, -- 0..1: por dónde va (se queda donde estaba al acabar)
	recoge: number, -- 0..1: al acabar, cuánto ha sacado ya la mano y la cabeza de debajo
	tirones: number, -- tirones que ya han sonado
	cayo: boolean, -- ya ha sonado el golpe al echarse
	cuello: number, -- largo del cuello estirado
	luz: PointLight?,
	pose: { [string]: CFrame },
}

type Bicho = {
	modelo: Model,
	raiz: BasePart,
	cabeza: BasePart,
	cuelloPieza: BasePart, -- el cuello se estira al gatear (su Size, solo en este cliente)
	cuelloTam: Vector3,
	gateo: Gateo?,
	motores: { [string]: Motor6D },
	c0: { [string]: CFrame },
	c0i: { [string]: CFrame },
	c1: { [string]: CFrame },
	c1i: { [string]: CFrame },
	pose: { [string]: CFrame },
	fase: number,
	pisada: number,
	llamada: number, -- os.clock de la última vez que empezó a llamar
	chillido: number,
	agarra: number, -- os.clock de rugir: el susto al morir le deja en el suelo (no otros chillidos)
	estirado: number, -- 0..1, suave
	quietud: number, -- 0..1, suave: 1 = parado
	oreja: number, -- -1 o 1: hacia dónde ladea la cabeza
	ladeo: number, -- el ladeo de ahora, con su lado (suave)
	escucha: number, -- 0..1, suave: cuánto se inclina hacia la puerta, escuchando
	oido: number, -- la cabeza girada hacia la puerta, con su lado (suave)
	extra: number, -- lo que añade el último tirón, con su lado...
	tiron: number, -- ...lo que lleva de él (rápido)
	proximoTiron: number,
	golpecito: number, -- os.clock del último golpecito en la puerta
	proximoGolpecito: number,
	mano: number, -- con qué mano da el golpecito (1 derecha, -1 izquierda)
	crispa: number,
	proximaCrispa: number,
	crispaLado: number,
	armado: boolean, -- en esta llamada aún puede pegarse a la mirilla
	soplo: number, -- os.clock del próximo vaho al hablar
	vaho: ParticleEmitter?,
	mirilla: Mirilla?,
}

local jugador = Players.LocalPlayer
local bichos: { [Model]: Bicho } = {}
local azar = Random.new()
local conexion: RBXScriptConnection? = nil
local mirillaDesde: number? = nil -- os.clock en que el jugador se puso a mirar por la mirilla
local puerta: Model? = nil
local buscarPuerta = 0 -- os.clock: no buscarla más de una vez cada 2 s si no está

local function rango(r: { number }): number
	return azar:NextNumber(r[1], r[2])
end

local function plano(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Suave al empezar y al acabar.
local function suave(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

-- 0..1: la mano contra la puerta en cada golpe, justo cuando suena en la grabación (`desde`: segundos desde que empezó
-- a sonar; `tono`: lo deprisa que va).
local function toque(desde: number, tono: number): number
	return math.max(0, math.sin((desde * tono - GOLPES.Primero) * math.pi * 2 / GOLPES.Cada + math.pi / 2))
end

-- CFrame en `desde` mirando a `hacia` (igual que CFrame.lookAt, con el arriba del mundo).
local function mirar(desde: Vector3, hacia: Vector3): CFrame
	local frente = hacia - desde
	if frente.Magnitude < 1e-3 then
		return CFrame.new(desde)
	end
	frente = frente.Unit
	local derecha = frente:Cross(Vector3.yAxis)
	derecha = if derecha.Magnitude < 1e-3 then Vector3.xAxis else derecha.Unit
	return CFrame.fromMatrix(desde, derecha, derecha:Cross(frente))
end

-- La puerta principal (a la que llama), con su atributo Centro (mira hacia fuera).
local function puertaPrincipal(ahora: number): CFrame?
	if not (puerta and puerta.Parent) then
		puerta = nil
		if ahora < buscarPuerta then
			return nil
		end
		buscarPuerta = ahora + 2
		for _, el in CollectionService:GetTagged("Puerta") do
			if el:IsA("Model") and el.Name == "PuertaPrincipal" then
				puerta = el
				break
			end
		end
	end
	local centro = puerta and puerta:GetAttribute("Centro")
	return if typeof(centro) == "CFrame" then centro else nil
end

local function puedeVaho(distancia: number): boolean
	return distancia < VAHO_LEJOS and workspace:GetAttribute("Fase") == "Noche" and jugador:GetAttribute("Rendimiento") ~= true
end

-- Vaho por la boca: una nubecilla que se deshace (las partículas se quedan donde salen, como el tuyo en CuerpoVista).
local function vahoDe(b: Bicho): ParticleEmitter
	if b.vaho and b.vaho.Parent then
		return b.vaho
	end
	local a = Instance.new("Attachment")
	a.Name = "Vaho"
	a.Position = Vector3.new(0, -0.4, -0.75) -- delante de la boca
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.LightInfluence = 1 -- de noche, apenas: solo se ve con la linterna
	e.Color = ColorSequence.new(Color3.fromRGB(215, 220, 228))
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.8) })
	e.Lifetime = NumberRange.new(1, 1.6)
	e.Speed = NumberRange.new(0.8, 1.4)
	e.SpreadAngle = Vector2.new(18, 18)
	e.EmissionDirection = Enum.NormalId.Front
	e.Acceleration = Vector3.new(0, 0.6, 0)
	e.Drag = 1.5
	e.Rate = 0
	e.Parent = a
	a.Parent = b.cabeza
	b.vaho = e
	return e
end

local function apagarMirilla(b: Bicho)
	local mi = b.mirilla
	if not mi then
		return
	end
	if mi.luzCara then
		local a = mi.luzCara.Parent
		if a then
			a:Destroy()
		end
	end
	if mi.luzEspalda then
		mi.luzEspalda:Destroy()
	end
	b.mirilla = nil
end

-- Deja de gatear del todo: el cuello vuelve a su largo y se apaga la luz de la cara.
local function terminarGateo(b: Bicho)
	local g = b.gateo
	if not g then
		return
	end
	if g.luz and g.luz.Parent then
		(g.luz.Parent :: Instance):Destroy()
	end
	if b.cuelloPieza.Parent then
		b.cuelloPieza.Size = b.cuelloTam
	end
	b.gateo = nil
end

local function olvidar(modelo: Model)
	local b = bichos[modelo]
	if b then
		terminarGateo(b)
		apagarMirilla(b)
		if b.vaho and b.vaho.Parent then
			(b.vaho.Parent :: Instance):Destroy()
		end
		bichos[modelo] = nil
	end
end

---------------------------------------------------------------- la mirilla

-- El cuello con el torso doblado `theta` por la cintura y el cuello echado atrás lo justo para mirar al frente, en
-- espacio de la raíz (sin desplazar).
local function cadena(b: Bicho, theta: number): CFrame
	local torso = b.c0.Torso * CFrame.Angles(-theta, 0, 0) * b.c1i.Torso
	return torso * b.c0.Cuello * CFrame.Angles(math.min(CUELLO_MAX, theta * CUELLO_K), 0, 0) * b.c1i.Cuello
end

-- Cuánto doblarse y cuánto desplazar el cuerpo (espacio de la raíz) para que lo alto del cuello llegue a `junta`. Lo
-- alto del cuello baja siempre al doblarse más (de 0 a DOBLA_MAX): se busca partiendo en dos.
local function doblar(b: Bicho, junta: Vector3): (number, Vector3)
	local lo, hi = 0, DOBLA_MAX
	for _ = 1, 16 do
		local medio = (lo + hi) / 2
		local cuello = cadena(b, medio)
		if (cuello * b.c0.Cabeza).Position.Y > junta.Y then
			lo = medio
		else
			hi = medio
		end
	end
	local theta = (lo + hi) / 2
	local cuello = cadena(b, theta)
	local o = junta - (cuello * b.c0.Cabeza).Position
	-- Sin hundir los pies en el porche: lo que no llega lo pone la cabeza.
	return theta, Vector3.new(o.X, math.clamp(o.Y, -0.15, 0.3), o.Z)
end

-- Pone en `pose` el cuerpo doblado `theta` por la cintura, desplazado `o` (espacio de la raíz, piernas incluidas), con
-- el cuello `cuelloT` y las piernas abiertas `zancada` (andando). Devuelve lo alto del cuello (la junta de la cabeza,
-- espacio de la raíz) para girar la cabeza.
local function poseDoblado(b: Bicho, theta: number, o: Vector3, cuelloT: CFrame, zancada: number, pose: { [string]: CFrame }): CFrame
	local desplaza = CFrame.new(o)
	local dobla = CFrame.Angles(-theta, 0, 0)
	pose.Torso = b.c0i.Torso * desplaza * b.c0.Torso * dobla
	pose.Cuello = cuelloT
	pose.PiernaI = b.c0i.PiernaI * desplaza * b.c0.PiernaI * CFrame.Angles(zancada, 0, 0)
	pose.PiernaD = b.c0i.PiernaD * desplaza * b.c0.PiernaD * CFrame.Angles(-zancada, 0, 0)
	local cuelga = math.min(1, theta)
	pose.BrazoI = CFrame.Angles(theta * BRAZO_K, 0, -BRAZO_ABRE * cuelga)
	pose.BrazoD = CFrame.Angles(theta * BRAZO_K, 0, BRAZO_ABRE * cuelga)
	return desplaza * b.c0.Torso * dobla * b.c1i.Torso * b.c0.Cuello * cuelloT * b.c1i.Cuello * b.c0.Cabeza
end

-- La pose de la mirilla en `mi.pose` (o false si no se puede). Solo se resuelven dos poses fijas (doblado cerca y la
-- cara pegada); lo de en medio se reparte a mano (doblez, paso y cuello): resolverlo de pie haría saltar el torso con
-- cualquier tirón de la cabeza. `mirando`: aún miras (si no, la pose se va apagando).
local function poseMirilla(b: Bicho, mi: Mirilla, ahora: number, ojo: Vector3, centro: CFrame?, mirando: boolean): boolean
	local raiz = b.raiz.CFrame
	local t = ahora - mi.inicio
	-- Solo se pega si aún miras: si te apartas antes, no (y en esta llamada puede pegarse la próxima vez que mires).
	if mi.susto and not mi.sono and not mirando and t >= mi.pega then
		mi.susto = false
	end
	local fuera = plano(if centro then centro.LookVector else -raiz.LookVector)
	if fuera.Magnitude < 1e-3 then
		return false
	end
	fuera = fuera.Unit
	-- La cámara respecto a la hoja: la cara siempre por fuera de ella.
	local dc = if centro then (ojo - centro.Position):Dot(fuera) else -HOJA
	local camara = raiz:PointToObjectSpace(ojo)
	local haciaFuera = raiz:VectorToObjectSpace(fuera)
	-- Lo alto del cuello para tener la cara a `d` studs de la cámara, mirándola.
	local function juntaA(d: number): Vector3
		local centroCabeza = camara + haciaFuera * (math.max(d, HOJA + MIRILLA.Holgura - dc) + 0.6)
		return (CFrame.new(centroCabeza) * mirar(centroCabeza, camara).Rotation * b.c1.Cabeza).Position
	end
	local roll = CFrame.Angles(0, 0, 0.12 * b.oreja)
	local function aLaCamara(junta: CFrame): CFrame
		return mirar(junta.Position + Vector3.new(0, 0.6, 0), camara).Rotation * roll
	end
	local p = b.pose

	-- De pie, unos pasos atrás y escuchando (como sin mirilla); luego se dobla y se acerca a la vez. Si ya mirabas
	-- cuando llegó, da esos pasos atrás delante de ti: dos zancadas lentas, sin dejar de mirar la puerta.
	local tAntes = if mi.susto then math.min(t, mi.pega) else t
	local atras, zancada = mi.atras, 0
	if mi.retrocede then
		local va = suave(t / MIRILLA.Retrocede)
		atras *= va
		zancada = math.sin(va * math.pi * 2) * math.sin(va * math.pi) * MIRILLA.Zancada
	end
	local dePie = 0.15 * b.estirado + 0.05 * b.escucha -- lo que ya se inclina (p.Torso)
	local acerca = math.clamp((tAntes - MIRILLA.Silueta - MIRILLA.Gira * MIRILLA.Empieza) / MIRILLA.Acerca, 0, 1)
	local k = suave(acerca)
	local final, oFinal = doblar(b, juntaA(MIRILLA.Cerca))
	local theta = dePie + (final - dePie) * k
	local o = Vector3.new(0, 0, atras):Lerp(oFinal, k)
	local cuelloT = p.Cuello:Lerp(CFrame.Angles(math.min(CUELLO_MAX, theta * CUELLO_K), 0, 0), k)
	-- De golpe, la cara contra la mirilla.
	local pegado = if mi.susto then t - mi.pega else -1
	if pegado >= 0 then
		local kp = math.min(1, pegado / MIRILLA.Golpe)
		local thetaP, oP = doblar(b, juntaA(MIRILLA.Pegado))
		theta += (thetaP - theta) * kp
		o = o:Lerp(oP, kp)
		cuelloT = cuelloT:Lerp(CFrame.Angles(math.min(CUELLO_MAX, thetaP * CUELLO_K), 0, 0), kp)
	end
	local junta = poseDoblado(b, theta, o, cuelloT, zancada, mi.pose)

	-- La cabeza, girando sobre el cuello: escuchando, gira despacio hacia la mirilla y ya no deja de mirarte. Pegada,
	-- tiembla, se va ladeando despacio y abre la boca.
	local R = junta.Rotation * p.Cabeza.Rotation
	local gira = suave((tAntes - MIRILLA.Silueta) / MIRILLA.Gira)
	if gira > 0 then
		R = R:Lerp(aLaCamara(junta), gira)
	end
	if acerca > 0 then
		R = R:Lerp(aLaCamara(junta), suave(acerca / 0.25))
	end
	if pegado >= 0 then
		local temblor = 0.14 * math.exp(-pegado / 0.25) + 0.012
		local ladea = b.oreja * (0.1 + 0.28 * suave(pegado / 3))
		R = mirar(junta.Position + Vector3.new(0, 0.6, 0), camara).Rotation * CFrame.Angles(math.noise(ahora * 30, 1) * temblor,
			math.noise(ahora * 30, 2) * temblor, math.noise(ahora * 30, 3) * temblor + ladea)
	end
	mi.pose.Cabeza = junta.Rotation:Inverse() * R
	local boca = if pegado >= 0 then 0.06 + 0.4 * suave((pegado - 0.3) / 2.5) else 0.03
	mi.pose.Mandibula = CFrame.Angles(-boca, 0, 0)

	-- Luces flojas, solo para quien mira: luna detrás de él (silueta) y, al acercarse, algo en la cara.
	local luzCara = 0
	if pegado >= 0 then
		luzCara = MIRILLA.Cara
	elseif t > MIRILLA.Silueta then
		luzCara = 0.12 * suave((t - MIRILLA.Silueta) / MIRILLA.Gira)
			+ 0.4 * suave((t - MIRILLA.Silueta - MIRILLA.Gira * MIRILLA.Empieza) / MIRILLA.Acerca)
	end
	if mi.luzCara then
		mi.luzCara.Brightness = luzCara * mi.mezcla
	end
	if mi.luzEspalda then
		mi.luzEspalda.WorldPosition = raiz:PointToWorldSpace(Vector3.new(0, 2, mi.atras + 7))
		local luna = mi.luzEspalda:FindFirstChildOfClass("PointLight")
		if luna then
			luna.Brightness = MIRILLA.Espalda * mi.mezcla * (if pegado >= 0 then 0.5 else 1)
		end
	end

	-- El susto, una vez: Sobresalto y la cara que da contra la puerta. Luego, quieto, un golpecito junto a la mirilla.
	if pegado >= 0 and not mi.sono then
		mi.sono = true
		b.armado = false
		Sonido.tocar("Sobresalto")
		local golpe = Sonido.en("Toc", ojo + fuera * (HOJA - dc + 0.1), 0.55)
		golpe.Volume *= 1.3
	end
	if pegado >= MIRILLA.Toc and not mi.toc then
		mi.toc = true
		local lado = fuera:Cross(Vector3.yAxis).Unit * (1.1 * b.oreja)
		local toc = Sonido.en("Toc", ojo + fuera * (HOJA - dc + 0.05) + lado - Vector3.new(0, 0.5, 0), 1.15)
		toc.Volume *= 0.5
	end
	return true
end

local function empezarMirilla(b: Bicho, ahora: number)
	-- Recién puesto a mirar, la vista aún está en negro: ya se le ve más atrás, de golpe (nunca se le ve deslizarse).
	-- Si ya mirabas cuando llegó, no se le ve saltar hacia atrás: se queda donde está y la pose entra suave.
	local recien = mirillaDesde ~= nil and ahora - mirillaDesde < MIRILLA.Negro
	local mi: Mirilla = {
		inicio = ahora,
		pega = rango(MIRILLA.Pega),
		susto = b.armado,
		atras = MIRILLA.Atras,
		retrocede = not recien,
		mezcla = if recien then 1 else 0,
		sono = false,
		toc = false,
		luzCara = nil,
		luzEspalda = nil,
		pose = {},
	}
	local a = Instance.new("Attachment")
	a.Name = "LuzMirilla"
	a.Position = Vector3.new(0, -0.1, -1.1) -- delante de la cara: dentro de la cabeza no la alumbraría
	local foco = Instance.new("PointLight")
	foco.Color = Color3.fromRGB(205, 200, 195)
	foco.Brightness = 0
	foco.Range = 3.5
	foco.Shadows = true -- que no pase por la puerta y alumbre el vestíbulo
	foco.Parent = a
	a.Parent = b.cabeza
	mi.luzCara = foco
	local detras = Instance.new("Attachment")
	detras.Name = "LunaMirilla"
	detras.WorldPosition = b.raiz.CFrame:PointToWorldSpace(Vector3.new(0, 2, mi.atras + 7))
	local luna = Instance.new("PointLight")
	luna.Color = Color3.fromRGB(150, 165, 205)
	luna.Brightness = 0
	luna.Range = 14
	luna.Shadows = true
	luna.Parent = detras
	detras.Parent = workspace.Terrain
	mi.luzEspalda = detras
	b.mirilla = mi
end

---------------------------------------------------------------- gatear

-- Pedido por el usuario (03-11-2026): agachado debajo de un mueble te escondes, y si un bicho te huele gatea a por ti.
-- El servidor le pone Gatea (dónde estás debajo) y GateaHora (cuándo empezó) mientras dura (Config.Postura.Gatear);
-- luego te pilla o lo deja, y los quita. Él, encorvado en el borde del mueble con una mano en el suelo: el cuello se
-- le estira hasta el suelo y asoma la cara por el borde a ras de suelo, ladeada, mirándote; el otro brazo baja por el
-- borde y entra arañando el suelo, a tirones y con una parada de olfatear, hasta dejarte la mano al lado. Al acabar,
-- saca la mano y la cabeza y luego se levanta. Comprobado con Lune contra las mesas del comedor y de la cocina (con el
-- bicho a 1-5 studs del borde, de frente y en diagonal): ni el suelo, ni el tablero, ni las patas se atraviesan.

local techo = RaycastParams.new()
techo.FilterType = Enum.RaycastFilterType.Exclude
techo.RespectCanCollide = true -- la zona invisible de debajo del tablero no cuenta: solo lo que choca

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

-- El tablero de un mueble con zona Debajo (Mapa, HUECOS): su centro y su tamaño. Las piezas de los muebles y sus cajas
-- de choque no se ven con rayos (CanQuery false), así que se mira el atributo Tam del mueble (el tablero llega a sus
-- bordes, de lo alto de la zona hasta arriba); si su pivote no cuadra con la zona, se da por hecho que sobresale
-- SALIENTE de la zona por cada lado. (Lo mismo que GolpeadorVista.)
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

-- El tablero que tapa a quien está en `punto` (el de la zona Debajo en la que está) y lo alto de su hueco, o nil.
local function tableroEn(punto: Vector3): (CFrame?, Vector3?, number?)
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
		return cf, tam, zona.Size.Y
	end
	return nil, nil, nil
end

-- El borde del mueble entre la raíz y `punto` (en planta, desde la raíz) y lo alto de su hueco: por la zona Debajo en
-- la que estás (en el juego los rayos no dan nunca en los muebles: CanQuery false) y, si no estás en ninguna, con rayos
-- hacia arriba cada medio stud. Por el medio y a los lados (la cabeza y los brazos): el borde más cercano, por si llega
-- torcido. Sin nada, a ojo: el borde a 1,6 de ti.
local function medirMueble(b: Bicho, punto: Vector3): (number, number, number)
	local suelo = b.raiz.Position - Vector3.new(0, ALTURA, 0)
	local hacia = plano(punto - suelo)
	local largo = hacia.Magnitude
	if largo < 0.5 then
		return 0, GATEO.Alto, 0
	end
	local u = hacia.Unit
	local lado = u:Cross(Vector3.yAxis)
	local cf, tam, hueco = tableroEn(punto)
	if cf and tam and hueco then
		local medio = tam / 2
		local d = cf:VectorToObjectSpace(u)
		-- Por donde entra en el tablero una raya por el suelo a `x` studs a la derecha de la del medio.
		local function entrada(x: number): number
			local o = cf:PointToObjectSpace(Vector3.new(suelo.X, cf.Position.Y, suelo.Z) + lado * x)
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
			return if entra <= sale and sale > 0 then math.max(0, entra) else largo
		end
		-- El del cuerpo y la cabeza, también a stud y medio (llegando en diagonal, los brazos rozaban el tablero por fuera
		-- de las rayas de un stud); el del brazo que mete (el derecho), solo por su lado.
		local borde, brazo = largo, largo
		for _, x in { 0, -1, 1, -1.5, 1.5 } do
			borde = math.min(borde, entrada(x))
		end
		for _, x in { 0.3, 0.7, 1.1, 1.4 } do
			brazo = math.min(brazo, entrada(x))
		end
		return borde, math.max(1, (cf.Position.Y - medio.Y) - suelo.Y), brazo
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
	local borde, alto = math.huge, math.huge
	for _, x in { 0, -1, 1 } do
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
	if borde == math.huge then
		return math.max(0, largo - 1.6), GATEO.Alto, math.max(0, largo - 1.6)
	end
	return borde, math.max(1, alto), borde
end

-- CFrame con su eje Y hacia `y` y su Z lo más hacia `z`.
local function ejes(pos: Vector3, y: Vector3, z: Vector3): CFrame
	local x = y:Cross(z)
	if x.Magnitude < 1e-3 then
		x = y:Cross(Vector3.xAxis)
	end
	return CFrame.fromMatrix(pos, x.Unit, y)
end

-- La pose de gatear en `g.pose` (Transform de cada motor). Todo se piensa en un suelo G bajo la raíz, mirando al jugador
-- (x a su derecha, y arriba, -z hacia ti: un punto a `d` studs hacia ti es (x, y, -d)).
local function poseGateo(b: Bicho, g: Gateo, ahora: number, ojo: Vector3, adornos: boolean, chillando: boolean, m: number)
	local raiz = b.raiz.CFrame
	local suelo = raiz.Position - Vector3.new(0, ALTURA, 0)
	local haciaW = plano(g.punto - suelo)
	local fW = if haciaW.Magnitude > 0.1 then haciaW.Unit else plano(raiz.LookVector).Unit
	local f = raiz:VectorToObjectSpace(fW)
	f = Vector3.new(f.X, 0, f.Z).Unit
	local G = CFrame.fromMatrix(Vector3.new(0, -ALTURA, 0), f:Cross(Vector3.yAxis), Vector3.yAxis)
	local D, E, EB, k = haciaW.Magnitude, g.borde, g.bordeBrazo, g.k
	local p = tirones(k) * (1 - suave(g.recoge))
	local u = if g.recoge > 0 then -1 else enTiron(k)
	local olfa = math.clamp(math.min((k - GATEO.Olfatea[1]) / 0.03, (GATEO.Olfatea[2] - k) / 0.03), 0, 1)
	local lejosFin = suave((k - 0.93) / 0.2) -- ya ha llegado

	-- La mano: del suelo por fuera del borde hasta tu lado, arañando entre tirón y tirón.
	local finMano = math.max(EB + 0.3, D - GATEO.Llega)
	local mano = (EB - GATEO.Fuera) + (finMano - (EB - GATEO.Fuera)) * p
	if adornos and u < 0 and olfa <= 0 then
		mano += 0.09 * math.sin(ahora * 13) -- araña
	end
	local manoX = 0.3

	-- La espalda encorvada sobre el borde (más en cada tirón; se yergue un poco al olfatear).
	local a = GATEO.Encorva + 0.12 * (if u >= 0 then math.sin(u * math.pi) else 0) - 0.12 * olfa
	-- Lo más bajo que pueden ir los hombros sin que la cadera (con su trapo) se meta en el suelo.
	local minimo = GATEO.Cadera + 3.6 * math.cos(a) + 0.55 * math.sin(a)

	-- El hombro derecho: fuera del borde (también del de su izquierda, por donde va el otro hombro) y lo bastante alto
	-- para que el brazo (recto) baje por el borde y llegue a la mano; si pasaría por el tablero (por dentro de su esquina
	-- de abajo), más atrás.
	local hombroD, alto = E - GATEO.Hombro, 0
	for _ = 1, 16 do
		local horiz = math.sqrt((mano - hombroD) ^ 2 + (1.25 - manoX) ^ 2)
		alto = math.clamp(0.06 + math.sqrt(math.max(0, GATEO.Brazo ^ 2 - horiz ^ 2)), math.max(2.6, minimo), 0.06 + GATEO.Brazo)
		if mano <= EB or alto <= g.alto then
			break
		end
		-- Dónde pasa el brazo a la altura de lo de abajo del tablero (antes se miraba a 0,25 de él y, como el tablero es
		-- más gordo, se metía por su canto; comprobado con Lune).
		local enTablero = hombroD + (mano - hombroD) * (alto - g.alto) / (alto - 0.06)
		if enTablero <= EB - GATEO.Holgura then
			break
		end
		hombroD -= 0.2
	end
	local S = Vector3.new(1.25, alto, -hombroD)
	local vy = alto - 0.06
	local horiz = math.sqrt(math.max(0, GATEO.Brazo ^ 2 - vy ^ 2))
	local plana = Vector3.new(manoX - 1.25, 0, -(mano - hombroD))
	plana = if plana.Magnitude > 1e-3 then plana.Unit else Vector3.new(0, 0, -1)
	local dirD = (plana * horiz + Vector3.new(0, -vy, 0)).Unit
	local brazoD = ejes(S + dirD * 1.8, -dirD, Vector3.yAxis)

	local yT = Vector3.new(0, math.cos(a), -math.sin(a))
	local arriba = S - Vector3.new(1.25, 0, 0) + yT * 0.2 -- lo alto del torso (donde nace el cuello)
	local torso = ejes(arriba - yT * 1.5, yT, Vector3.new(0, math.sin(a), math.cos(a)))
	local cadera = arriba - yT * 3

	-- Las piernas abiertas como una araña, hasta el suelo.
	local piernas = {}
	for _, lado in { -1, 1 } do
		local junta = cadera + Vector3.new(lado * 0.5, 0, 0)
		local bajo = math.max(0.1, junta.Y - 0.38)
		local hl = math.sqrt(math.max(0, 4.4 ^ 2 - bajo ^ 2))
		local v = Vector3.new(lado * hl * 0.68, -bajo, hl * 0.73).Unit
		piernas[lado] = ejes(junta + v * 2, -v, Vector3.yAxis)
	end

	-- El brazo izquierdo apoyado en el suelo, abierto hacia fuera y algo atrás (lejos de la mesa aunque estés de lado;
	-- empuja en cada tirón).
	local SI = arriba - Vector3.new(1.25, 0, 0) - yT * 0.2
	local abre = 0.8 + 0.25 * (if u >= 0 then math.sin(u * math.pi) else 0) -- radianes desde atrás hacia fuera
	local vyI = math.max(0, SI.Y - 0.06)
	local hI = math.sqrt(math.max(0, GATEO.Brazo ^ 2 - vyI ^ 2))
	local dirI = Vector3.new(-math.sin(abre) * hI, -vyI, math.cos(abre) * hI).Unit
	local brazoI = ejes(SI + dirI * 1.8, -dirI, Vector3.yAxis)

	-- La cabeza: cuelga del cuello estirado y asoma por el borde a ras de suelo, ladeada, mirándote (al olfatear se
	-- levanta un poco y da golpes de nariz); el cuello va de lo alto del torso a ella.
	local dCabeza = (E - GATEO.Asoma - 0.6) - 0.4 * (1 - p) - GATEO.Aparta * (1 - m)
	local hc = GATEO.Cabeza + 0.12 * olfa - 0.06 * (if u >= 0 then math.sin(u * math.pi) else 0)
	local centro = Vector3.new(-0.3, hc, -dCabeza)
	-- Te mira a ti si eres tú el de debajo (la cámara junto a Gatea y a poca altura); si no, a donde está.
	local debajo = plano(ojo - g.punto).Magnitude < 4 and ojo.Y - suelo.Y < 3.5
	local blanco = if debajo then G:PointToObjectSpace(raiz:PointToObjectSpace(ojo)) else Vector3.new(0, 1, -D)
	local ladeo = GATEO.Ladeo + 0.15 * lejosFin
	local giro = mirar(centro, blanco).Rotation * CFrame.Angles(0, 0, ladeo)
	if adornos then
		local nariz = olfa * math.abs(math.sin(ahora * 22)) * 0.06
		local t = if chillando then 0.12 else 0.015
		giro *= CFrame.Angles(nariz + math.noise(ahora * 9, 1) * t, math.noise(ahora * 9, 2) * t, math.noise(ahora * 9, 3) * t)
	end
	local cabeza = CFrame.new(centro) * giro
	local junta = cabeza * Vector3.new(0, -0.6, 0)
	local cuelloV = junta - arriba
	g.cuello = math.max(b.cuelloTam.Y, cuelloV.Magnitude)
	local cuello = ejes((arriba + junta) / 2, if cuelloV.Magnitude > 1e-3 then cuelloV.Unit else Vector3.yAxis, Vector3.new(0, 0, 1))

	-- La boca: se le va abriendo según llega (cerrada al olfatear); te pilla: abierta del todo. Nunca contra el suelo.
	local boca = 0.06 + 0.2 * p + 0.12 * (if u >= 0 then math.sin(u * math.pi) else 0) - 0.1 * olfa + 0.25 * lejosFin
		+ (if chillando then 0.4 + 0.08 * math.sin(ahora * 30) else 0)
	-- (con algo de margen: chillando, la cabeza tiembla y la barbilla rozaba el suelo)
	local bocaMax = math.asin(math.clamp((hc - 0.9) / (1.1 * math.max(0.2, math.cos(ladeo))), 0, 1))
	boca = math.clamp(boca, 0, bocaMax)

	-- Las Transform ya mezcladas (`m`: 0 = su pose de siempre, b.pose; 1 = gateando). Al echarse y al levantarse, el
	-- torso gira desde la cadera y lo demás va en línea recta de donde estaba a donde va (en el espacio de la raíz):
	-- girando cada junta por su cuenta, las piernas se hundían en el suelo y la cabeza se metía en el tablero.
	local pose, base = g.pose, b.pose
	local c0, c0i, c1, c1i = b.c0, b.c0i, b.c1, b.c1i
	pose.Torso = base.Torso:Lerp(c0i.Torso * G * torso * c1.Torso, m)
	local torsoM = c0.Torso * pose.Torso * c1i.Torso
	local torsoB = c0.Torso * base.Torso * c1i.Torso
	local cuelloB = torsoB * c0.Cuello * base.Cuello * c1i.Cuello
	local cuelloM = cuelloB:Lerp(G * cuello, m)
	pose.Cuello = c0i.Cuello * torsoM:Inverse() * cuelloM * c1.Cuello
	local cabezaB = cuelloB * c0.Cabeza * base.Cabeza * c1i.Cabeza
	pose.Cabeza = c0i.Cabeza * cuelloM:Inverse() * cabezaB:Lerp(G * cabeza, m) * c1.Cabeza
	for nombre, cf in { BrazoD = brazoD, BrazoI = brazoI } do
		local antes = torsoB * c0[nombre] * base[nombre] * c1i[nombre]
		pose[nombre] = c0i[nombre] * torsoM:Inverse() * antes:Lerp(G * cf, m) * c1[nombre]
	end
	for nombre, cf in { PiernaI = piernas[-1], PiernaD = piernas[1] } do
		-- (a medio camino se levantan un poco, como dando el paso: si no, la punta rozaba bajo el suelo)
		local antes = c0[nombre] * base[nombre] * c1i[nombre]
		pose[nombre] = c0i[nombre] * (antes:Lerp(G * cf, m) + Vector3.new(0, 0.3 * math.sin(math.pi * m), 0)) * c1[nombre]
	end
	pose.Mandibula = base.Mandibula:Lerp(CFrame.Angles(-boca, 0, 0), m)
end

-- Al echarse y en cada tirón: el golpe contra el suelo, las uñas en la madera y algún crujido. Solo cerca.
local function sonidosGateo(b: Bicho, g: Gateo)
	local manoPieza = b.motores.BrazoD.Part1
	if not g.cayo and g.mezcla > 0.5 then
		g.cayo = true
		Sonido.en("Paso", b.raiz.Position - Vector3.new(0, ALTURA - 0.5, 0), 0.7).Volume *= 1.3
		Sonido.en("Cruje", b.raiz.Position - Vector3.new(0, ALTURA - 0.5, 0), azar:NextNumber(0.75, 0.9))
	end
	local hechos = 0
	for _, t0 in GATEO.Tirones do
		if g.k >= t0 then
			hechos += 1
		end
	end
	if hechos > g.tirones then
		g.tirones = hechos
		if manoPieza then
			local s = Sonido.en("Aranazo", (manoPieza :: BasePart).CFrame * Vector3.new(0, -2.2, 0), azar:NextNumber(1.15, 1.4))
			s.Volume *= 0.6
			s.RollOffMinDistance = 6
		end
		if azar:NextNumber() < 0.5 then
			Sonido.en("Cruje", b.raiz.Position, azar:NextNumber(0.85, 1.05)).Volume *= 0.6
		end
	end
end

-- Una luz floja en la cara, para que se le vea desde debajo de la mesa (como la de la mirilla).
local function luzGateo(b: Bicho, g: Gateo, brillo: number)
	if not g.luz or not g.luz.Parent then
		local a = Instance.new("Attachment")
		a.Name = "LuzGatea"
		a.Position = Vector3.new(0, -0.1, -1.1) -- delante de la cara: dentro de la cabeza no la alumbraría
		local foco = Instance.new("PointLight")
		foco.Color = Color3.fromRGB(205, 200, 195)
		foco.Range = 4
		foco.Shadows = false
		foco.Parent = a
		a.Parent = b.cabeza
		g.luz = foco
	end
	(g.luz :: PointLight).Brightness = brillo
end

-- Gatea, GateaHora y por dónde va. Devuelve la mezcla con la que se pinta (0 = nada). Se queda en la pose si te acaba de
-- pillar (rugir lo llama MuerteVista) para que la escena de muerte le vea la cara ahí; si no, vuelve suave.
-- `adornos`: cerca y sin Rendimiento (arañar, temblar, olfatear con la nariz).
local function gatear(b: Bicho, ahora: number, servidor: number, dt: number, ojo: Vector3, adornos: boolean, distancia: number): number
	local modelo = b.modelo
	local punto = modelo:GetAttribute("Gatea")
	local hora = modelo:GetAttribute("GateaHora")
	local g = b.gateo
	if typeof(punto) == "Vector3" then
		local t = if type(hora) == "number" then hora else servidor
		if not g or g.fin or (g.punto - punto).Magnitude > 0.5 or math.abs(g.hora - t) > 0.05 then
			local borde, alto, bordeBrazo = medirMueble(b, punto)
			local nuevo: Gateo = { punto = punto, hora = t, inicio = ahora, borde = borde, bordeBrazo = bordeBrazo, alto = alto,
				mezcla = if g then g.mezcla else 0, fin = nil, k = 0, recoge = 0, tirones = 0, cayo = false, cuello = b.cuelloTam.Y,
				luz = if g then g.luz else nil, pose = if g then g.pose else {} }
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
	local pilla = b.agarra >= g.inicio and ahora - b.agarra < 2.2
	-- Al acabar (si no te ha pillado), primero saca la mano y la cabeza de debajo y luego se levanta: levantándose con
	-- ellas dentro, a medio camino el brazo atravesaba el tablero (comprobado con Lune).
	if g.fin and not pilla then
		g.recoge = math.min(1, g.recoge + dt / GATEO.Recoge)
	end
	local meta = if not g.fin or pilla or g.recoge < 1 then 1 else 0
	g.mezcla = if meta > g.mezcla then math.min(meta, g.mezcla + dt / GATEO.Cae) else math.max(meta, g.mezcla - dt / GATEO.Vuelve)
	if g.fin and g.mezcla <= 0 then
		terminarGateo(b)
		return 0
	end
	local mezcla = suave(g.mezcla)
	poseGateo(b, g, ahora, ojo, adornos, ahora - b.chillido < 2, mezcla)
	if b.cuelloPieza.Parent then
		local t = b.cuelloTam
		b.cuelloPieza.Size = Vector3.new(t.X, t.Y + (g.cuello - t.Y) * mezcla, t.Z)
	end
	if distancia < CERCA then -- los sonidos, también con Rendimiento: se oye venir
		sonidosGateo(b, g)
	end
	if distancia < 14 or g.luz then
		luzGateo(b, g, if distancia < 14 then GATEO.Luz * mezcla else 0)
	end
	return mezcla
end

---------------------------------------------------------------- cada fotograma

local function animar(dt: number)
	local ahora = os.clock()
	local servidor = workspace:GetServerTimeNow()
	local camara = workspace.CurrentCamera
	local ojo = camara.CFrame.Position
	local rendimiento = jugador:GetAttribute("Rendimiento") == true
	local mira = jugador:GetAttribute("Mirilla") == true
	if not mira then
		mirillaDesde = nil
	elseif not mirillaDesde then
		mirillaDesde = ahora
	end
	local centro = puertaPrincipal(ahora)
	local fuera = if centro then plano(centro.LookVector) else Vector3.zero
	local delante = if centro and fuera.Magnitude > 1e-3 then centro.Position + fuera.Unit * DELANTE else nil
	for modelo, b in bichos do
		if not modelo.Parent or not b.raiz.Parent or not b.cabeza.Parent then
			olvidar(modelo)
			continue
		end
		local distancia = (b.raiz.Position - ojo).Magnitude
		if distancia > LEJOS then
			apagarMirilla(b)
			continue
		end
		local m = b.motores
		local p = b.pose
		local cerca = distancia < CERCA and not rendimiento
		local v = b.raiz.AssemblyLinearVelocity
		local rapidez = Vector3.new(v.X, 0, v.Z).Magnitude
		local paso = math.min(1, rapidez / 8)
		b.quietud += ((if rapidez < 1 then 1 else 0) - b.quietud) * math.min(1, dt * 3)
		b.fase += dt * rapidez * 0.45
		local s = math.sin(b.fase)
		local abierto = modelo:GetAttribute("Abierto") == true
		b.estirado += ((if abierto then 1 else 0) - b.estirado) * math.min(1, dt * 3)
		local chillando = ahora - b.chillido < 2
		local t = ahora - b.llamada
		-- Esperando en la puerta principal (o, sin ella cargada, delante de la mirilla mientras miras). Gateando no: su vida
		-- de espera (tirones, golpecitos, crispaciones) se pausa y vuelve suave al levantarse.
		local enPuerta = b.quietud > 0.6 and not abierto and not b.gateo
			and (if delante then plano(b.raiz.Position - delante).Magnitude < 4 else mira and distancia < MIRILLA.Radio)

		-- La cabeza ladeada, escuchando: recta mientras habla, luego se le va torciendo, demasiado, con algún tirón.
		-- Todo suave y con su lado dentro: al cambiar de oreja en cada llamada, la cabeza pasa despacio al otro lado.
		local meta = (1 - paso) * 0.25
		local escucha = 0
		if enPuerta then
			escucha = math.clamp((t - HABLA[2]) / LADEA, 0, 1)
			meta = if t < HABLA[2] then LADEO[1] * 0.5 else LADEO[1] + (LADEO[2] - LADEO[1]) * escucha
			if cerca and ahora > b.proximoTiron then
				b.proximoTiron = ahora + rango(TIRON)
				b.extra = azar:NextNumber(-0.16, 0.16)
			end
		else
			b.extra = 0
		end
		b.ladeo += (meta * b.oreja - b.ladeo) * math.min(1, dt * 1.2)
		b.tiron += (b.extra - b.tiron) * math.min(1, dt * 22)
		b.escucha += (escucha - b.escucha) * math.min(1, dt * 2)
		b.oido += ((if enPuerta then 0.2 * b.oreja else 0) - b.oido) * math.min(1, dt * 1.5) -- la oreja hacia la puerta
		local ladeo = b.ladeo + b.tiron

		-- Brazos: tres golpes al llamar y algún golpecito esperando; la punta de los dedos llega justo a la hoja.
		local alcance = 0.55
		if centro and fuera.Magnitude > 1e-3 then
			local hombro = b.raiz.CFrame * b.c0.Torso * b.c1i.Torso * b.c0.BrazoD
			local hasta = (hombro.Position - centro.Position):Dot(fuera.Unit) - HOJA - 0.05
			alcance = math.asin(math.clamp(hasta / LARGO_BRAZO, 0, 1))
		end
		local brazoD, brazoI = 0, 0
		if t < LLAMADA and not abierto then -- (solo llama en la puerta; la primera, nada más plantarse)
			local sube = math.min(1, t / 0.25, (LLAMADA - t) / 0.25)
			brazoD = sube * (alcance - 0.14 + 0.14 * toque(t, 1) ^ 0.6)
		end
		if enPuerta and cerca and t > LLAMADA + 1.5 and ahora > b.proximoGolpecito and not b.mirilla then
			b.proximoGolpecito = ahora + rango(GOLPECITO.Cada)
			b.golpecito = ahora
			b.mano = if azar:NextNumber() < 0.7 then 1 else -1
			-- La punta de los dedos contra la hoja (la mano derecha está en +X de la raíz). Suenan solo sus toques.
			local punta = b.raiz.CFrame:PointToWorldSpace(Vector3.new(1.25 * b.mano, -0.9, -DELANTE + 0.3))
			local toc = Sonido.en("Toc", punta, GOLPECITO.Tono)
			toc.Volume *= GOLPECITO.Volumen
			task.delay((GOLPES.Primero + (GOLPECITO.Toques - 0.5) * GOLPES.Cada) / GOLPECITO.Tono, toc.Stop, toc)
		elseif not enPuerta then
			b.proximoGolpecito = math.max(b.proximoGolpecito, ahora + 2)
		end
		local tg = ahora - b.golpecito
		local dura = (GOLPES.Primero + (GOLPECITO.Toques - 1) * GOLPES.Cada) / GOLPECITO.Tono + 0.3
		if tg < dura then
			local sube = math.min(1, tg / 0.25, (dura - tg) / 0.25)
			local golpecito = sube * (alcance - 0.08 + 0.08 * toque(tg, GOLPECITO.Tono))
			if b.mano > 0 then
				brazoD = math.max(brazoD, golpecito)
			else
				brazoI = math.max(brazoI, golpecito)
			end
		end
		-- Crispación: un tirón de los dedos de una mano, de vez en cuando.
		if cerca and enPuerta and ahora > b.proximaCrispa then
			b.proximaCrispa = ahora + rango(CRISPA)
			b.crispa = ahora
			b.crispaLado = if azar:NextNumber() < 0.5 then -1 else 1
		end
		local tc = ahora - b.crispa
		local crispa = if tc < 0.04 then tc / 0.04 elseif tc < 0.5 then math.exp(-(tc - 0.04) / 0.07) else 0
		local crispaD = if b.crispaLado > 0 then crispa else 0
		local crispaI = if b.crispaLado < 0 then crispa else 0

		-- Boca: como si hablase al llamar (con vaho de noche: es lo único que le sale de la boca).
		local habla = 0
		if not abierto and t > HABLA[1] and t < HABLA[2] then
			habla = 0.05 + 0.11 * math.abs(math.sin(t * 8.5 + math.sin(t * 3.1)))
			if ahora > b.soplo and puedeVaho(distancia) then
				b.soplo = ahora + azar:NextNumber(0.55, 0.8)
				vahoDe(b):Emit(3)
			end
		end

		p.PiernaI = CFrame.Angles(s * 0.6 * paso, 0, 0)
		p.PiernaD = CFrame.Angles(-s * 0.6 * paso, 0, 0)
		p.BrazoD = CFrame.Angles(brazoD + b.estirado * 0.6 + crispaD * 0.05, 0, crispaD * 0.07)
		p.BrazoI = CFrame.Angles(brazoI + b.estirado * 0.6 + crispaI * 0.05, 0, -crispaI * 0.07)
		-- Quieto, la cabeza se le va ladeando; abierto, el cuello se estira y la boca se abre del todo.
		p.Torso = CFrame.Angles(b.estirado * -0.15 - 0.05 * b.escucha, 0, 0)
		p.Cuello = CFrame.new(0, b.estirado * 2.2, 0) * CFrame.Angles(0, 0, ladeo * 0.4)
		p.Cabeza = CFrame.Angles(b.estirado * -0.3 - 0.06 * b.escucha, b.oido,
			ladeo + (if chillando then math.sin(ahora * 35) * 0.12 else 0))
		p.Mandibula = CFrame.Angles(-(habla + b.estirado * 0.9 + (if chillando then 0.3 else 0)), 0, 0)

		-- La mirilla: solo si está en la puerta y miras por ella (y nadie le ha abierto).
		local mirando = mira and enPuerta and distancia < MIRILLA.Radio
		if mirando and not b.mirilla then
			empezarMirilla(b, ahora)
		end
		local mi = b.mirilla
		if mi then
			mi.mezcla += ((if mirando then 1 else 0) - mi.mezcla) * math.min(1, dt * (if mirando then 6 else 5))
			if (not mirando and mi.mezcla < 0.02) or not poseMirilla(b, mi, ahora, ojo, centro, mirando) then
				apagarMirilla(b)
				mi = nil
			end
		end
		-- Gateando a por alguien debajo de un mueble: manda sobre todo lo demás (ya mezclado con su pose de siempre; su
		-- vida de espera se queda debajo).
		local gm = gatear(b, ahora, servidor, dt, ojo, cerca, distancia)
		local gp = if gm > 0 and b.gateo then b.gateo.pose else nil
		for _, nombre in MOTORES do
			local pose = p[nombre]
			if mi and mi.pose[nombre] then
				pose = pose:Lerp(mi.pose[nombre], mi.mezcla)
			end
			m[nombre].Transform = if gp and gp[nombre] then gp[nombre] else pose
		end

		local lado = if s >= 0 then 1 else -1
		if rapidez > 2 and lado ~= b.pisada then
			b.pisada = lado
			Sonido.en("Paso", b.raiz.Position - Vector3.new(0, 4, 0), 1.1)
		end
	end
	-- Sin Imitadores, el bucle se apaga (vuelve al llegar otro).
	if next(bichos) == nil and conexion then
		conexion:Disconnect()
		conexion = nil
	end
end

local function preparar(modelo: Instance)
	if not modelo:IsA("Model") or modelo.Name ~= "Imitador" or bichos[modelo] then
		return
	end
	local raiz = modelo:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not raiz then
		return
	end
	local motores, c0, c0i, c1, c1i = {}, {}, {}, {}, {}
	for _, nombre in MOTORES do
		local motor = raiz:WaitForChild(nombre, 5) :: Motor6D?
		if not motor or not motor:IsA("Motor6D") then
			return
		end
		motores[nombre] = motor
		c0[nombre], c0i[nombre] = motor.C0, motor.C0:Inverse()
		c1[nombre], c1i[nombre] = motor.C1, motor.C1:Inverse()
	end
	local cabeza = motores.Cabeza.Part1
	local cuello = motores.Cuello.Part1
	if not cabeza or not cuello or not modelo.Parent or bichos[modelo] then
		return
	end
	local ahora = os.clock()
	bichos[modelo] = { modelo = modelo, raiz = raiz, cabeza = cabeza, cuelloPieza = cuello, cuelloTam = cuello.Size, gateo = nil,
		motores = motores, c0 = c0, c0i = c0i, c1 = c1,
		c1i = c1i, pose = {}, fase = 0, pisada = 1, llamada = -math.huge, chillido = -math.huge, agarra = -math.huge, estirado = 0, quietud = 0,
		oreja = if azar:NextNumber() < 0.5 then -1 else 1, ladeo = 0, extra = 0, tiron = 0, proximoTiron = ahora,
		escucha = 0, oido = 0, golpecito = -math.huge, proximoGolpecito = ahora + rango(GOLPECITO.Cada), mano = 1, crispa = -math.huge,
		proximaCrispa = ahora + rango(CRISPA), crispaLado = 1, armado = false, soplo = 0, vaho = nil, mirilla = nil }
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

-- Para MuerteVista (quién te ha pillado, PosturaReglas.quienPilla): los Imitadores a menos de 12 de `punto` (la
-- cara del susto), sin tocarlos: su modelo, a cuánto tiene la cabeza de `punto` y dónde estaba el escondido a por
-- el que gatea (si gatea).
function ImitadorVista.candidatos(punto: Vector3): { { modelo: Model, distancia: number, gatea: Vector3? } }
	local lista = {}
	for _, b in bichos do
		if (b.raiz.Position - punto).Magnitude < 12 then
			local cara = if b.cabeza.Parent then b.cabeza.Position else b.raiz.Position
			table.insert(lista, {
				modelo = b.modelo,
				distancia = (cara - punto).Magnitude,
				gatea = b.gateo and b.gateo.punto,
			})
		end
	end
	return lista
end

-- `modelo`: el que ha elegido MuerteVista (si no es un Imitador, nada); sin él, el más cerca de `punto`.
function ImitadorVista.rugir(punto: Vector3, modelo: Model?): Model?
	local b = if modelo then bichos[modelo] else cercano(punto, 12)
	if b then
		b.chillido = os.clock()
		b.agarra = b.chillido
		return b.modelo
	end
	return nil
end

function ImitadorVista.start()
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
	Remotes.Imitador.OnClientEvent:Connect(function(tipo: string, modelo: Model?)
		local b = if typeof(modelo) == "Instance" then bichos[modelo :: Model] else nil
		if not b then
			return
		end
		local delante = b.raiz.Position + b.raiz.CFrame.LookVector * 1.5 + Vector3.new(0, 1, 0)
		if tipo == "Llama" then
			b.llamada = os.clock()
			b.armado = true -- una vez por llamada puede pegarse a la mirilla
			b.soplo = 0
			b.extra = 0
			b.oreja = if azar:NextNumber() < 0.5 then -1 else 1
			local s = Sonido.en("Llamar", delante, 1)
			s.RollOffMinDistance = 20
		elseif tipo == "Entra" then
			b.chillido = os.clock() + 0.4
			Sonido.en("Chillido", delante, 0.8)
			Sonido.en("Rugido", delante, 0.9)
		end
	end)
end

return ImitadorVista
