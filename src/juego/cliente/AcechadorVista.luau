-- Mueve el cuerpo del Acechador en el cliente y hace sus ruidos (el servidor lo mueve y avisa con el remote Acechador).
-- Todo con la Transform de sus Motor6D: no toca lo que hace el servidor ni la física (sus piezas no chocan ni pesan; los
-- adornos van soldados a su miembro y le siguen solos).
--   Zancadas largas y lentas, encorvado, los brazos casi quietos.
--   Parado entre los árboles (pedido por el usuario: los bichos con vida mientras esperan): respira hondo, se mece como
--   un árbol con el viento, cambia el peso de pierna, da tirones de cabeza (a veces para quedarse mirándote), se le
--   crispan los dedos y le cruje la madera del cuerpo. Con un tronco al lado se esconde detrás (solo mientras no le ves:
--   nunca se le ve deslizarse) y se asoma por un lado, mirándote. De noche le sale vaho por la grieta de la boca.
--   Con Rendimiento, nada de eso (solo andar, la carga y la linterna, como antes).
--   "Rama": una rama que se parte bajo sus pies (en 3D). "Carga": ruge y se echa encima con los brazos por delante.
--   "Luz": la linterna le frena: se encoge, se tapa la cara y chilla.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sonido = require(script.Parent.Sonido)

local AcechadorVista = {}

-- Números visuales (a ojo; se retocan en Studio).
local LEJOS = 300 -- studs de la cámara: más lejos no se anima
local CERCA = 160 -- más lejos, sin la vida de estar parado
local VAHO_LEJOS = 60 -- studs: más lejos no se le ve el vaho
local CRUJE_LEJOS = 55 -- studs: más lejos no se oye crujir su madera
local MOTORES = { "Torso", "Cabeza", "Mandibula", "BrazoI", "BrazoD", "PiernaI", "PiernaD" }
local PIES = Vector3.new(0, -7.5, 0) -- los pies, desde la raíz (Acechador.luau: ALTURA)
local RESPIRA = 4.2 -- segundos por respiración (honda y lenta)
local MECE = { Lado = 0.035, Frente = 0.015, Periodo = 5.5 } -- radianes y segundos: se mece como un árbol
local PESO = { 3.5, 7 } -- segundos entre cambios de peso
local TIRON = { 0.7, 2.6 } -- segundos entre tirones de cabeza
local MIRARTE = 0.45 -- de los tirones, la parte que es para quedarse mirándote
local CRISPA = { 1.5, 4 } -- segundos entre crispaciones
local CRUJE = { 6, 12 } -- segundos entre crujidos de la madera
local TRONCO = { Radio = 9, Detras = 1.1, Max = 4.5, Cada = 0.5 } -- studs (radio, detrás del tronco, lo más que se mueve) y s
-- Asomarse: se inclina por la cintura (Lado) y desde los tobillos (Pie), en radianes y sin mover los pies (la cabeza
-- sale ~2,8 studs de lado), y segundos.
local ASOMA = { Lado = 0.3, Pie = 0.1, Sale = 1.2, Queda = { 1.5, 3.5 }, Espera = { 1.2, 3 } }
local VISTO = 0.45 -- con la cámara mirando a menos de ~63° de él, se le está viendo: no se mueve el escondite
-- Si le ves cuando echa a andar o se echa encima: sale de detrás del tronco de una zancada (segundos y radianes).
local SALE = { Dura = 0.3, Zancada = 0.5 }

type Bicho = {
	modelo: Model,
	raiz: BasePart,
	cabeza: BasePart,
	motores: { [string]: Motor6D },
	c0: { [string]: CFrame },
	c0i: { [string]: CFrame },
	fase: number,
	pisada: number,
	carga: number, -- os.clock en que se echó encima
	luz: number, -- os.clock de la última vez que le frenó la linterna
	chillido: number,
	encogido: number, -- 0..1, suave
	semilla: number,
	quietud: number, -- 0..1, suave: 1 = parado
	peso: number, -- -1..1: sobre qué pierna está (suave)
	pesoMeta: number,
	proximoPeso: number,
	giro: Vector3, -- la cabeza ahora (cabeceo, giro, ladeo) y a dónde va el tirón
	giroMeta: Vector3,
	proximoTiron: number,
	mirandote: boolean, -- el último tirón fue para mirarte
	crispa: number,
	crispaParte: string,
	crispaEje: Vector3,
	proximaCrispa: number,
	proximoCruje: number,
	ciclo: number, -- respiración en la que va (al cambiar, suelta el aire)
	tronco: Vector3?, -- el tronco que tiene al lado (centro, en planta)
	radio: number,
	proximoTronco: number,
	esconde: Vector3, -- lo que se le ve movido (mundo, en planta) para quedar detrás del tronco
	sale: number, -- 0..1 mientras sale de detrás del tronco de una zancada (-1: no)...
	saleDesde: Vector3, -- ...desde lo que estaba movido
	asoma: number, -- 0..1, suave
	asomaMeta: number,
	asomaLado: number,
	asomaHasta: number,
	vaho: ParticleEmitter?,
}

local jugador = Players.LocalPlayer
local bichos: { [Model]: Bicho } = {}
local azar = Random.new()
local conexion: RBXScriptConnection? = nil
local filtroTroncos = OverlapParams.new()
filtroTroncos.FilterType = Enum.RaycastFilterType.Include

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

local function puedeVaho(distancia: number): boolean
	return distancia < VAHO_LEJOS and workspace:GetAttribute("Fase") == "Noche" and jugador:GetAttribute("Rendimiento") ~= true
end

-- Vaho por la grieta de la boca (las partículas se quedan donde salen, como el tuyo en CuerpoVista).
local function vahoDe(b: Bicho): ParticleEmitter
	if b.vaho and b.vaho.Parent then
		return b.vaho
	end
	local a = Instance.new("Attachment")
	a.Name = "Vaho"
	a.Position = Vector3.new(0, -0.45, -0.75) -- delante de la boca
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.LightInfluence = 1 -- de noche, apenas: solo se ve con la linterna
	e.Color = ColorSequence.new(Color3.fromRGB(215, 220, 228))
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1.1) })
	e.Lifetime = NumberRange.new(1.2, 2)
	e.Speed = NumberRange.new(0.8, 1.4)
	e.SpreadAngle = Vector2.new(20, 20)
	e.EmissionDirection = Enum.NormalId.Front
	e.Acceleration = Vector3.new(0, 0.5, 0)
	e.Drag = 1.5
	e.Rate = 0
	e.Parent = a
	a.Parent = b.cabeza
	b.vaho = e
	return e
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

-- El tronco de pie más cercano a su lado (los del bosque y los que se talan: en workspace.Mapa.Bosque), o nil.
local function buscarTronco(b: Bicho)
	local mapa = workspace:FindFirstChild("Mapa")
	local bosque = mapa and mapa:FindFirstChild("Bosque")
	b.tronco = nil
	if not bosque then
		return
	end
	filtroTroncos.FilterDescendantsInstances = { bosque }
	local aqui = b.raiz.Position + PIES + Vector3.new(0, 4, 0)
	local mejor = TRONCO.Radio
	for _, pieza in workspace:GetPartBoundsInRadius(aqui, TRONCO.Radio, filtroTroncos) do
		-- El tronco es un cilindro tumbado de lado (su eje, X, en vertical); uno talado ya no está de pie.
		if pieza.Name == "Tronco" and math.abs(pieza.CFrame.RightVector.Y) > 0.9 then
			local d = plano(pieza.Position - b.raiz.Position).Magnitude
			if d < mejor then
				mejor = d
				b.tronco = plano(pieza.Position)
				b.radio = pieza.Size.Y / 2
			end
		end
	end
end

-- Hacia dónde girar la cabeza (cabeceo y giro, en su espacio) para mirar a la cámara.
local function haciaCamara(b: Bicho, ojo: Vector3): Vector3
	local dir = b.raiz.CFrame:VectorToObjectSpace(ojo - b.cabeza.Position)
	if dir.Magnitude < 1e-3 then
		return Vector3.zero
	end
	dir = dir.Unit
	local giro = math.clamp(math.atan2(-dir.X, -dir.Z), -1.1, 1.1)
	return Vector3.new(math.clamp(math.asin(math.clamp(dir.Y, -1, 1)), -0.6, 0.3), giro, 0)
end

local function animar(dt: number)
	local ahora = os.clock()
	local camara = workspace.CurrentCamera
	local ojo = camara.CFrame.Position
	local mirada = camara.CFrame.LookVector
	local rendimiento = jugador:GetAttribute("Rendimiento") == true
	for modelo, b in bichos do
		if not modelo.Parent or not b.raiz.Parent or not b.cabeza.Parent then
			olvidar(modelo)
			continue
		end
		local distancia = (b.raiz.Position - ojo).Magnitude
		if distancia > LEJOS then
			continue
		end
		local m = b.motores
		local raiz = b.raiz.CFrame
		local v = b.raiz.AssemblyLinearVelocity
		local rapidez = Vector3.new(v.X, 0, v.Z).Magnitude
		local paso = math.min(1, rapidez / 10)
		b.fase += dt * rapidez * 0.28
		local s = math.sin(b.fase)
		local cargando = ahora - b.carga < 20
		local frenado = ahora - b.luz < 2.5
		b.encogido += ((if frenado then 1 else 0) - b.encogido) * math.min(1, dt * (if frenado then 12 else 2))
		local chillando = ahora - b.chillido < 1.4
		b.quietud += ((if rapidez < 1.5 then 1 else 0) - b.quietud) * math.min(1, dt * 2.5)
		-- Cuánta vida de estar parado se le ve (nada andando, cargando, con la linterna, lejos o con Rendimiento).
		local vida = if rendimiento or distancia > CERCA or cargando then 0 else b.quietud * (1 - b.encogido)

		-- Respira hondo: el pecho sube y baja; al soltar el aire, vaho de noche.
		local respira = math.sin((ahora / RESPIRA + b.semilla) * math.pi * 2)
		local ciclo = math.floor(ahora / RESPIRA + b.semilla - 0.25) -- cambia con el pecho arriba: empieza a soltar el aire
		if ciclo ~= b.ciclo then
			b.ciclo = ciclo
			if vida > 0.5 and puedeVaho(distancia) then
				vahoDe(b):Emit(4)
			end
		end
		-- Cambia el peso de pierna de vez en cuando.
		if ahora > b.proximoPeso then
			b.proximoPeso = ahora + rango(PESO)
			b.pesoMeta = (if b.pesoMeta > 0 then -1 else 1) * azar:NextNumber(0.6, 1)
		end
		b.peso += (b.pesoMeta - b.peso) * math.min(1, dt * 1.2)
		-- Tirones de cabeza: a una postura nueva de golpe; a veces, a mirarte (y se queda siguiéndote).
		if vida > 0.3 and ahora > b.proximoTiron then
			b.proximoTiron = ahora + rango(TIRON)
			b.mirandote = azar:NextNumber() < MIRARTE
			b.giroMeta = Vector3.new(azar:NextNumber(-0.15, 0.25), azar:NextNumber(-0.8, 0.8), azar:NextNumber(-0.35, 0.35))
		end
		-- Crispaciones: un brazo, la cabeza o el pecho dan un respingo.
		if vida > 0.5 and ahora > b.proximaCrispa then
			b.proximaCrispa = ahora + rango(CRISPA)
			b.crispa = ahora
			local partes = { "BrazoI", "BrazoD", "BrazoD", "Cabeza", "Torso" }
			b.crispaParte = partes[azar:NextInteger(1, #partes)]
			local fuerza = if b.crispaParte == "Torso" then 0.05 elseif b.crispaParte == "Cabeza" then 0.12 else 0.18
			-- (nunca el vector cero: su Unit daría NaN y descolocaría el cuerpo entero)
			b.crispaEje = Vector3.new(if azar:NextNumber() < 0.5 then -1 else 1, azar:NextNumber(-0.5, 0.5), azar:NextNumber(-1, 1)).Unit
				* fuerza
		end
		local tc = ahora - b.crispa
		local crispa = if tc < 0.04 then tc / 0.04 elseif tc < 0.6 then math.exp(-(tc - 0.04) / 0.08) else 0
		local function respingo(parte: string): CFrame
			if parte ~= b.crispaParte or crispa <= 0 then
				return CFrame.identity
			end
			local e = b.crispaEje * crispa
			return CFrame.Angles(e.X, e.Y, e.Z)
		end
		-- La madera del cuerpo cruje al mecerse.
		if vida > 0.7 and distancia < CRUJE_LEJOS and ahora > b.proximoCruje then
			b.proximoCruje = ahora + rango(CRUJE)
			local cruje = Sonido.en("Crujido", b.cabeza.Position - Vector3.new(0, 4, 0), azar:NextNumber(0.5, 0.65))
			cruje.Volume *= 0.35
			cruje.RollOffMinDistance = 6
		end

		-- El tronco de al lado: escondido detrás (respecto a tu cámara) y asomándose por un lado.
		if vida > 0.5 and ahora > b.proximoTronco then
			b.proximoTronco = ahora + TRONCO.Cada
			buscarTronco(b)
		elseif vida <= 0.5 then
			b.tronco = nil
		end
		local meta = Vector3.zero
		local lado = Vector3.zero -- hacia dónde se asoma (mundo, en planta)
		local tronco = b.tronco
		if tronco then
			local desdeCamara = tronco - plano(ojo)
			if desdeCamara.Magnitude > 1 then
				local detras = tronco + desdeCamara.Unit * (b.radio + TRONCO.Detras)
				local falta = plano(detras - b.raiz.Position)
				meta = if falta.Magnitude <= TRONCO.Max then falta else Vector3.zero
				lado = desdeCamara.Unit:Cross(Vector3.yAxis) * b.asomaLado
			end
		end
		-- Dónde se le ve (`esconde`): detrás del tronco solo parado, sin cargar y con vida; si no, en su sitio de verdad
		-- (con el que el servidor mira la carga y la linterna). Nunca se le ve deslizarse: sin verle, cambia de golpe;
		-- viéndole, se queda donde está, y si echa a andar o se echa encima sale de detrás del tronco de una zancada
		-- rápida (las piernas dan el paso). Con Rendimiento, siempre en su sitio.
		local hacia = b.cabeza.Position - ojo
		local visto = hacia.Magnitude > 1e-3 and mirada:Dot(hacia.Unit) > VISTO
		local quedarse = vida > 0.5 and paso < 0.3 and not cargando
		if rendimiento then
			b.esconde, b.sale = Vector3.zero, -1
		elseif b.sale < 0 then
			if not visto then
				b.esconde = if quedarse then meta else Vector3.zero
			elseif (paso >= 0.3 or cargando) and b.esconde.Magnitude > 0.05 then
				b.sale, b.saleDesde = 0, b.esconde
			end
		end
		local zancada = 0
		if b.sale >= 0 then
			b.sale = math.min(1, b.sale + dt / SALE.Dura)
			b.esconde = b.saleDesde * (1 - suave(b.sale))
			zancada = math.sin(b.sale * math.pi) * SALE.Zancada
			if b.sale >= 1 then
				b.sale = -1
			end
		end
		local escondido = meta.Magnitude > 0 and (b.esconde - meta).Magnitude < 0.5
		if escondido and ahora > b.asomaHasta then
			if b.asomaMeta > 0 then
				b.asomaMeta = 0
				b.asomaHasta = ahora + ASOMA.Sale + rango(ASOMA.Espera)
			else
				b.asomaMeta = 1
				b.asomaLado = if azar:NextNumber() < 0.5 then -1 else 1
				b.asomaHasta = ahora + ASOMA.Sale + rango(ASOMA.Queda)
			end
		elseif not escondido then
			b.asomaMeta = 0
		end
		b.asoma += (b.asomaMeta - b.asoma) * math.min(1, dt * 2.5)
		local asoma = b.asoma * vida
		-- En su espacio, hacia dónde se inclina: girar en X lo echa hacia +Z y girar en -Z, hacia +X.
		local hacialado = raiz:VectorToObjectSpace(lado)
		local asomaLado, asomaFrente = -hacialado.X * ASOMA.Lado * asoma, hacialado.Z * ASOMA.Lado * asoma

		-- Cuerpo entero sobre los pies (que no se mueven): se mece, carga el peso, se inclina desde los tobillos para
		-- asomarse y se queda detrás del tronco.
		local onda = ahora * math.pi * 2 / MECE.Periodo + b.semilla * 6
		local mece = (MECE.Lado * math.sin(onda) + b.peso * 0.03) * vida - hacialado.X * ASOMA.Pie * asoma
		local frente = MECE.Frente * math.sin(onda * 0.73 + 1.7) * vida + hacialado.Z * ASOMA.Pie * asoma
		local movido = raiz:VectorToObjectSpace(b.esconde)
		local cuerpo = CFrame.new(movido) * CFrame.new(PIES) * CFrame.Angles(frente, 0, mece) * CFrame.new(-PIES)
		local function conCuerpo(nombre: string, t: CFrame): CFrame
			return b.c0i[nombre] * cuerpo * b.c0[nombre] * t
		end

		m.PiernaI.Transform = conCuerpo("PiernaI", CFrame.Angles(s * 0.55 * paso + zancada, 0, 0))
		m.PiernaD.Transform = conCuerpo("PiernaD", CFrame.Angles(-s * 0.55 * paso - zancada, 0, 0))
		-- Brazos: casi quietos; echándose encima, por delante con las garras abiertas; con luz, delante de la cara.
		-- Parado, cuelgan como péndulos (se quedan algo atrás al mecerse) y suben un poco al coger aire.
		local delante = if cargando then 1.1 else 0
		local brazo = delante * (1 - b.encogido) + 2.4 * b.encogido - respira * 0.012 * vida
		local temblor = b.encogido * math.sin(ahora * 40) * 0.06
		local pendulo = -mece * 0.6
		m.BrazoI.Transform = CFrame.Angles(brazo - s * 0.12 * paso + temblor, 0, -0.05 + b.encogido * 0.4 + pendulo)
			* respingo("BrazoI")
		m.BrazoD.Transform = CFrame.Angles(brazo + s * 0.12 * paso - temblor, 0, 0.05 - b.encogido * 0.4 + pendulo)
			* respingo("BrazoD")
		m.Torso.Transform = conCuerpo("Torso", CFrame.Angles((if cargando then -0.3 else 0) + b.encogido * 0.35
			+ respira * 0.022 * vida + asomaFrente, 0, s * 0.04 * paso + asomaLado) * respingo("Torso"))

		-- Cabeza: a tirones; asomado, mirándote y ladeada hacia fuera. Sin vida, el tirón de siempre.
		local meta2 = b.giroMeta
		if asoma > 0.3 or b.mirandote then
			meta2 = haciaCamara(b, ojo) + Vector3.new(0, 0, if asoma > 0.3 then asomaLado * 0.8 else b.giroMeta.Z * 0.5)
		end
		b.giro = b.giro:Lerp(meta2, math.min(1, dt * 16))
		local tiron = if math.noise(ahora * 0.9, b.semilla) > 0.4 then 0.5 else 0
		local giro = b.giro * vida
		m.Cabeza.Transform = CFrame.Angles(b.encogido * 0.5 + giro.X + respira * 0.01 * vida,
			b.encogido * 0.9 + giro.Y + (1 - paso) * tiron * (1 - vida), giro.Z + math.sin(ahora * 0.4) * 0.1 * (1 - vida))
			* respingo("Cabeza")
		m.Mandibula.Transform = CFrame.Angles(-(0.1 + 0.15 * asoma + (if cargando then 0.4 else 0)
			+ (if chillando then 0.6 + math.sin(ahora * 30) * 0.1 else 0)), 0, 0)

		local pie = if s >= 0 then 1 else -1
		if rapidez > 2 and pie ~= b.pisada then
			b.pisada = pie
			Sonido.en("Paso", b.raiz.Position - Vector3.new(0, 7, 0), azar:NextNumber(0.6, 0.7))
		end
	end
	-- Sin Acechadores, el bucle se apaga (vuelve al salir otro).
	if next(bichos) == nil and conexion then
		conexion:Disconnect()
		conexion = nil
	end
end

local function preparar(modelo: Instance)
	if not modelo:IsA("Model") or modelo.Name ~= "Acechador" or bichos[modelo] then
		return
	end
	local raiz = modelo:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not raiz then
		return
	end
	local motores, c0, c0i = {}, {}, {}
	for _, nombre in MOTORES do
		local motor = raiz:WaitForChild(nombre, 5) :: Motor6D?
		if not motor or not motor:IsA("Motor6D") then
			return
		end
		motores[nombre] = motor
		c0[nombre], c0i[nombre] = motor.C0, motor.C0:Inverse()
	end
	local cabeza = motores.Cabeza.Part1
	if not cabeza or not modelo.Parent or bichos[modelo] then
		return
	end
	local ahora = os.clock()
	bichos[modelo] = { modelo = modelo, raiz = raiz, cabeza = cabeza, motores = motores, c0 = c0, c0i = c0i, fase = 0,
		pisada = 1, carga = -math.huge, luz = -math.huge, chillido = -math.huge, encogido = 0, semilla = azar:NextNumber(0, 100),
		quietud = 0, peso = 0, pesoMeta = 1, proximoPeso = ahora + rango(PESO), giro = Vector3.zero, giroMeta = Vector3.zero,
		proximoTiron = ahora, mirandote = false, crispa = -math.huge, crispaParte = "", crispaEje = Vector3.zero,
		proximaCrispa = ahora + rango(CRISPA), proximoCruje = ahora + rango(CRUJE), ciclo = 0, tronco = nil, radio = 1,
		proximoTronco = 0, esconde = Vector3.zero, sale = -1, saleDesde = Vector3.zero, asoma = 0, asomaMeta = 0, asomaLado = 1, asomaHasta = 0, vaho = nil }
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

-- Para MuerteVista (quién te ha pillado, PosturaReglas.quienPilla): los Acechadores a menos de 16 de `punto` (la
-- cara del susto), sin tocarlos: su modelo y a cuánto tiene la cabeza de `punto` (no gatea).
function AcechadorVista.candidatos(punto: Vector3): { { modelo: Model, distancia: number, gatea: Vector3? } }
	local lista = {}
	for _, b in bichos do
		if (b.raiz.Position - punto).Magnitude < 16 then
			local cara = if b.cabeza.Parent then b.cabeza.Position else b.raiz.Position
			table.insert(lista, {
				modelo = b.modelo,
				distancia = (cara - punto).Magnitude,
			})
		end
	end
	return lista
end

-- La cabeza está muy alta: se busca por cualquier punto cercano a ella.
-- `modelo`: el que ha elegido MuerteVista (si no es un Acechador, nada); sin él, el más cerca de `punto`.
function AcechadorVista.rugir(punto: Vector3, modelo: Model?): Model?
	local b = if modelo then bichos[modelo] else cercano(punto, 16)
	if b then
		b.chillido = os.clock()
		return b.modelo
	end
	return nil
end

function AcechadorVista.start()
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
	Remotes.Acechador.OnClientEvent:Connect(function(tipo: string, modelo: Model?)
		local b = if typeof(modelo) == "Instance" then bichos[modelo :: Model] else nil
		if not b then
			return
		end
		local pies = b.raiz.Position + PIES
		if tipo == "Rama" then
			local s = Sonido.en("Rama", pies + Vector3.new(azar:NextNumber(-2, 2), 0, azar:NextNumber(-2, 2)), azar:NextNumber(0.85, 1.1))
			s.RollOffMinDistance = 15
		elseif tipo == "Carga" then
			b.carga = os.clock()
			b.chillido = os.clock()
			local s = Sonido.en("Rugido", b.raiz.Position, 0.75)
			s.RollOffMinDistance = 30
			Sonido.en("Rama", pies, 0.8)
		elseif tipo == "Luz" then
			b.luz = os.clock()
			b.chillido = os.clock()
			Sonido.en("Chillido", b.raiz.Position + Vector3.new(0, 5, 0), 0.65)
		end
	end)
end

return AcechadorVista
