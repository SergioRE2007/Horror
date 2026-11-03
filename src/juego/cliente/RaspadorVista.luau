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
-- Un solo bucle (Stepped) que solo corre mientras hay alguno; la vida, solo cerca de la cámara. Si el modelo se va
-- (StreamOut o lo quita el servidor) se limpia, y si vuelve se prepara otra vez.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
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

local jugador = Players.LocalPlayer
local azar = Random.new()
local carpeta: Instance? = nil
local filtro = RaycastParams.new()
filtro.FilterType = Enum.RaycastFilterType.Exclude

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
		b.vida = acercar(b.vida, if (rapidez < QUIETO or raspando) and not chillando and distancia < vidaLejos then 1 else 0, dt, 2)
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

-- Abre la boca del todo (el susto al morir). Devuelve el Raspador que tenga la cabeza cerca de `punto`, si hay.
function RaspadorVista.rugir(punto: Vector3): Model?
	local b = cercano(punto, 12)
	if b then
		b.chillido = os.clock()
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
