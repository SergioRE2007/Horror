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
-- Partido como el servidor (pedido en 16.19): aquí el ciclo (animar) y el estado; el gateo en GolpeadorVistaGateo, los
-- sucesos en GolpeadorVistaSucesos, el susto al pillarte en GolpeadorVistaMuerte y lo común del cuerpo (medidas, tipos,
-- alcanzar...) en GolpeadorVistaCuerpo; lo que comparten todas las Vistas de bichos, en BichoComun.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Malla3D = require(script.Parent.Malla3D)
local Sonido = require(script.Parent.Sonido)
-- BichoComun (con su Random), después de Sonido: el Roblox de mentira de los bancos de Lune da a cada Random.new() la
-- semilla que le toca por orden, y así el Golpeador sigue con la misma que antes de partirlo (los bancos de gateo y de
-- sucesos dan siempre lo mismo).
local BichoComun = require(script.Parent.BichoComun)
local Cuerpo = require(script.Parent.GolpeadorVistaCuerpo)
local Gateo = require(script.Parent.GolpeadorVistaGateo)
local Muerte = require(script.Parent.GolpeadorVistaMuerte)
local Sucesos = require(script.Parent.GolpeadorVistaSucesos)

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
local MIRILLA = 14 -- studs de la cámara a su cabeza: te ve mirarle por la mirilla
local MIRILLA_REACCION = 0.5 -- segundos hasta que se da cuenta
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
-- Lo que sobresale la cara de la malla (Cara3D) del centro de la cabeza de bloques, en ella (sin malla, su frente).
local FRENTE_CARA = Vector3.new(0, 0.1, -0.75)

type Bicho = Cuerpo.Bicho

local jugador = Players.LocalPlayer
local azar = BichoComun.azar
local bichos: { [Model]: Bicho } = {}
local conexion: RBXScriptConnection? = nil

local LADEO, BOCA, LADOS = Cuerpo.LADEO, Cuerpo.BOCA, Cuerpo.LADOS
local rango, acercar, suave = BichoComun.rango, BichoComun.acercar, BichoComun.suaveSinTope
local dentroDeCasa = BichoComun.dentroDeCasa
local bocaDe, provisional, prepararCodos = Cuerpo.bocaDe, Cuerpo.provisional, Cuerpo.prepararCodos
local garrasSobreSuelo, noAtravesar = Cuerpo.garrasSobreSuelo, Cuerpo.noAtravesar
local gatear, mesaCerca, apartarBrazos = Gateo.gatear, Gateo.mesaCerca, Gateo.apartarBrazos
local pasoSusto, bocaSusto, asustar = Muerte.paso, Muerte.boca, Muerte.asustar
local sucesos, olvidarSucesos = Sucesos.poner, Sucesos.olvidar
local SUCESO = Sucesos.SUCESO

-- Una crispación: sube de golpe y se apaga temblando (0..1).
local function crispacion(t: number): number
	local c = BichoComun.crispacion(t, 0.45, 0.07)
	-- (Sin multiplicar fuera de ella: antes de la primera, t es infinito y 0 · sin(inf) = NaN.)
	return if c > 0 then c * (1 + 0.25 * math.sin(t * 70)) else 0
end

-- El vaho: una nube que sale de la boca hacia delante y un poco hacia abajo, y se deshace (las partículas se quedan
-- donde salen; de noche apenas se ve: con la linterna o la luz de la ventana).
local VAHO_COMO: BichoComun.Vaho = {
	Transparencia = 0.78, Tam = { 0.25, 1.3 }, Vida = { 1.2, 1.9 }, Rapidez = { 1.4, 2.4 }, Abre = 20, Giro = 25, Sube = 0.5,
	Freno = 1.6,
}
local function echarVaho(boca: CFrame)
	BichoComun.echarVaho("VahoGolpeador", VAHO_COMO, boca.Position, (boca.LookVector - boca.UpVector * 0.3).Unit, VAHO)
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
	return BichoComun.cercano(bichos, punto, maximo)
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


function GolpeadorVista.start()
	local carpeta = workspace:WaitForChild("Bichos")
	carpeta.ChildAdded:Connect(preparar)
	for _, modelo in carpeta:GetChildren() do
		task.spawn(preparar, modelo)
	end
	Remotes.Golpeador.OnClientEvent:Connect(function(tipo: string, el: Model)
		if tipo == "Toque" then
			Sucesos.toque(bichos, el)
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
