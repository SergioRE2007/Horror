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

local function olvidar(modelo: Model)
	local b = bichos[modelo]
	if b then
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
		m.PiernaI.Transform = CFrame.Angles(s * 0.5 * paso, 0, 0) * respingo(b, "PiernaI", crispa)
		m.PiernaD.Transform = (if cojea then CFrame.Angles(0.35 - s * 0.12 * paso, 0, 0.12) else CFrame.Angles(-s * 0.5 * paso, 0, 0))
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
		m.BrazoI.Transform = CFrame.Angles(brazo, 0, 0) * respingo(b, "BrazoI", crispa)
		m.BrazoD.Transform = CFrame.Angles(otro, 0, 0) * respingo(b, "BrazoD", crispa)

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
		m.Lomo.Transform = CFrame.new(0, math.abs(carga) * HOMBRO, 0)
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
		m.Cabeza.Transform = CFrame.Angles(giro.X, giro.Y, giro.Z) * respingo(b, "Cabeza", crispa)
		local abre = 0.2 + 0.06 * math.sin(ahora * 2.5) + brazosG * 0.2 + encoge * 0.6
			+ (if rugiendo or quemando then 0.75 + 0.1 * math.sin(ahora * 30) else 0)
			+ (if aranando then 0.45 + 0.15 * math.sin(ahora * 13) else 0)
			+ cabezada * 0.2 - olfateo * 0.12 + grune * (0.14 + 0.03 * math.sin(ahora * 45)) - aire * 0.08
		m.Mandibula.Transform = CFrame.Angles(-abre, 0, 0)

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
	local motores = {}
	for _, nombre in MOTORES do
		local motor = raiz:WaitForChild(nombre, 5) :: Motor6D?
		if not motor or not motor:IsA("Motor6D") or not motor.Part1 then
			return
		end
		motores[nombre] = motor
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
		grunido = -math.huge, proximoGrunido = ahora + rango(GRUNE), vaho = nil }
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
