-- Lo común del cuerpo del Golpeador para su Vista (GolpeadorVista, con el ciclo y el estado) y sus partes
-- (GolpeadorVistaGateo, GolpeadorVistaSucesos y GolpeadorVistaMuerte): sus medidas, los tipos del estado de cada bicho
-- y las herramientas para poner los brazos y la cabeza encima de la postura de siempre (alcanzar, noAtravesar...).
-- Librería sin start().
local TweenService = game:GetService("TweenService")

local Malla3D = require(script.Parent.Malla3D)
local Sonido = require(script.Parent.Sonido)

local Cuerpo = {}

local LADOS = { -1, 1 }
local LADEO = 0.35 -- la cabeza ladeada
local BOCA = CFrame.new(0, -0.45, -0.75) -- en la cabeza
local ALTURA = 5 -- de los pies al centro de la raíz (Golpeador.luau)
-- Medidas del cuerpo (Golpeador.crear) que usa el gateo.
local CABEZA_CENTRO = Vector3.new(0, 0.6, -0.4) -- del cuello al centro de la cabeza (en la cabeza)
local GARRAS = Vector3.new(0, -7.36, -0.32) -- del hombro a la punta de las garras (en el brazo)
local PIERNA = 4.1 -- de la cadera al pie
-- De pie, la punta de las garras al menos a esto del suelo (studs; su caja baja ~0,03 más), adelantando el brazo como
-- mucho estos radianes (garrasSobreSuelo).
local GARRAS_SUELO, GARRAS_ADELANTA = 0.06, 0.6
-- El codo de la malla (rig.dobla, en el eje X del brazo: hacia delante, como dobla de verdad): para llevar la punta de
-- las garras a un sitio (alcanzar). Los dedos no están en MALLA: de la muñeca a la punta del dedo corazón, ~1,75
-- (medido en el modelo de Tripo). Como mucho CODO_MAX radianes.
local DEDOS, CODO_MAX = 1.75, 2.5

-- Las patas del mueble debajo del que está el escondido (sus cajas de choque: centro y mitad de su tamaño), para que
-- los brazos no las atraviesen.
export type Patas = { { cf: CFrame, medio: Vector3 } }

-- Un gateo: el de ahora o el último (mientras vuelve a su pose).
export type Gateo = {
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
export type Susto = {
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
export type Suceso = {
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
export type Codo = { hueso: number, A: Vector3, B: Vector3 }

export type Bicho = {
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

Cuerpo.LADOS, Cuerpo.LADEO, Cuerpo.BOCA, Cuerpo.ALTURA = LADOS, LADEO, BOCA, ALTURA
Cuerpo.CABEZA_CENTRO, Cuerpo.GARRAS, Cuerpo.PIERNA = CABEZA_CENTRO, GARRAS, PIERNA
Cuerpo.orientar, Cuerpo.mirarCara, Cuerpo.garrasSobreSuelo = orientar, mirarCara, garrasSobreSuelo
Cuerpo.torsoEnRaiz, Cuerpo.perpendicular, Cuerpo.cabezaHacia = torsoEnRaiz, perpendicular, cabezaHacia
Cuerpo.prepararCodos, Cuerpo.alcanzar, Cuerpo.noAtravesar = prepararCodos, alcanzar, noAtravesar
Cuerpo.provisional, Cuerpo.bocaDe = provisional, bocaDe

return Cuerpo
