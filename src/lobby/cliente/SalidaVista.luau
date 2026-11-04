-- El coche que se va del lobby. Coches (servidor) pone en el coche el atributo Salida = hora del servidor a la que
-- sale (Config.Coches.Salida s después de que el dueño arranque; nil = parado). Desde ese momento, en cada cliente:
--   · El coche de verdad y los que van sentados se esconden (LocalTransparencyModifier, sus luces, el prompt y el choque
--     fuera) y el coche lleva el atributo local SaliendoLocal = true (GasolineraVista no lo toca mientras). La copia,
--     el camino para salir de la plaza y lo de esconder, en CocheCopia (lo comparte con LlegadaVista).
--   · Una copia sin asientos, prompts ni scripts (nada choca ni toca) arranca: tiembla, los faros parpadean al
--     encenderse, pilotos, limpias, humo del escape, ruedas que ruedan (las de delante giran con el volante) y se
--     inclina un poco al acelerar y en las curvas. Para no darle al de delante, si hace falta da un poco de marcha atrás
--     y gira más cerrado; sale con una curva hasta el carril derecho (x = CARRIL) y acelera hacia -Z hasta perderse en
--     la niebla.
--   · Si vas dentro (atributo Coche del jugador), la cinemática: sin interfaz, CoreGui ni los demás personajes, cámara
--     Scriptable en dos planos (bajo delante, en la carretera, mirándolo arrancar; luego detrás y arriba, siguiéndolo y
--     quedándose atrás) y un fundido a negro propio que acaba un poco antes de la hora. Luego, negro hasta que el
--     servidor te lleva.
-- Todo según la hora del servidor (si llegas a media salida, la copia va por donde toca) y el movimiento en el Bucle
-- (una tarea por coche que sale). Si el servidor la retrasa (Salida a más de Config.Coches.Salida s: estaba llegando
-- otro coche por el carril), no empieza hasta entonces. Lo devuelve todo siempre: si Salida vuelve a nil o cambia, a los
-- ESPERA s de la hora sin habernos ido o si algo falla. Si te bajas a media cuenta atrás, se acaba tu cinemática y lo
-- ves irse como los demás. Si Salida vuelve a nil porque se ha ido de verdad y el coche ya tiene Llegada (Coches), la
-- copia sigue hasta la niebla y el de verdad sigue escondido: lo devuelve LlegadaVista cuando llega el otro.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Bucle = require(script.Parent.Bucle)
local CocheCopia = require(script.Parent.CocheCopia)
local Sonido = require(script.Parent.Sonido)

local SalidaVista = {}

local jugador = Players.LocalPlayer

-- Plano del lobby: la carretera va a lo largo de Z en x = 0 y el bosque (por donde se va) queda hacia -Z.
local CARRIL, FIN = CocheCopia.CARRIL, CocheCopia.FIN -- el carril derecho yendo hacia -Z; donde se borra la copia
-- Números a ojo (solo cambian cómo se ve). El camino para salir de la plaza (giros, holgura), en CocheCopia.
local VELOCIDAD = 40 -- studs/s en la carretera
local ESPERA = 12 -- segundos tras la hora sin habernos ido: se devuelve todo
local TARDE = 1.5 -- una salida cuya hora pasó hace más (entrar tarde al servidor) ya no se enseña
-- Tiempos desde que el dueño arranca, en segundos.
local CONTACTO = 0.1 -- el motor arranca: tiembla y echa una bocanada de humo
local FAROS = { 0.2, 0.26, 0.33, 0.37, 0.44 } -- se encienden, se apagan… y desde el último, encendidos
local ATRAS, PARADA = 0.45, 0.1 -- cuándo empieza la marcha atrás (si hace falta) y quieto antes de meter primera
local ATRAS_DURA = { 0.45, 0.2 } -- segundos que dura la marcha atrás: lo primero más lo segundo por cada stud
local SIN_ATRAS = 0.65 -- sin marcha atrás, cuándo empieza a andar
local SALE, TA = 8, 0.45 -- sale de la plaza despacio (hasta SALE studs/s en TA s; menos si gira muy cerrado)…
local TB0, TB1 = 0.55, 3.2 -- …y acelera hasta VELOCIDAD entre estos segundos desde que anda
local LIMPIAS, AMPLITUD, PERIODO = 0.5, math.rad(80), 1.3 -- limpiaparabrisas: desde cuándo, cuánto giran, cada cuánto
-- Cinemática.
local PLANO1 = 1.8 -- segundos del plano bajo delante del coche
local CAMPO1, CAMPO2 = 50, 58 -- FieldOfView de cada plano
local NEGRO, NEGRO_TODO = 1, 0.2 -- el fundido empieza NEGRO s antes de la hora y está negro del todo NEGRO_TODO s antes
local FARO_LUZ, PILOTO_LUZ = CocheCopia.FARO_LUZ, CocheCopia.PILOTO_LUZ

type Guardado = CocheCopia.Guardado
type Grupo = CocheCopia.Grupo
type Luz = CocheCopia.Luz
type Salida = {
	modelo: Model,
	hora: number, -- la hora del servidor a la que sale (atributo Salida)
	inicio: number, -- cuando arrancó el dueño
	tarea: string, -- nombre en el Bucle
	p0: Vector3, -- centro de la carrocería del coche aparcado
	psi0: number, -- cuánto está girado a la izquierda (aparcado no del todo recto)
	eje: number, -- studs del centro al eje de atrás
	suelo: number,
	techo: number,
	atras: number, -- studs de marcha atrás
	atrasDura: number, -- segundos que dura
	giro: number, -- radio del giro al salir de la plaza
	v1: number, -- velocidad al salir de la plaza
	curva0: number, -- curva del camino al empezar (el volante, girado antes de meter primera)
	plaza: CocheCopia.Plaza?, -- cómo sale de su plaza y el camino hasta el carril
	copia: Model?,
	lista: { BasePart }, -- piezas de la copia, para BulkMoveTo
	bases: { CFrame }, -- dónde está cada una respecto al coche aparcado
	grupos: { Grupo | boolean }, -- false = pegada a la carrocería
	cframes: { CFrame },
	ruedas: { Grupo },
	limpias: { Grupo },
	batalla: number, -- distancia entre ejes
	volante: number,
	faros: { Luz },
	pilotos: { Luz },
	estadoFaros: boolean?,
	estadoPilotos: boolean?,
	humo: ParticleEmitter?,
	bocanada: boolean,
	ruidoPunto: Attachment?,
	asientos: { BasePart },
	esAsiento: { [Instance]: boolean },
	escondidos: { [Model]: Guardado }, -- los personajes sentados, escondidos
	repaso: number,
	otros: { [Model]: Guardado }?, -- en tu cinemática, los demás personajes (estorban en los planos)
	repasoOtros: number,
	devolver: { () -> () },
	cine: { () -> () }?, -- lo que deshacer de la cinemática (solo si vas dentro)
	gruaA: Vector3,
	gruaB: Vector3,
	gruaC: Vector3,
	grua: number,
	acabada: boolean,
	suelta: boolean, -- el servidor ya no la lleva (el coche se ha vaciado y vuelve otro): acaba al perderse la copia
}

local salidas: { [Model]: Salida } = {}
local esperando: { [Instance]: number } = {} -- coches con una Salida que aún no empieza (la hora de esa Salida)
local vigilados: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local capaNegro: ScreenGui
local negro: Frame
local tweenNegro: Tween? = nil

local suave, pendiente, curvatura, area = CocheCopia.suave, CocheCopia.pendiente, CocheCopia.curvatura, CocheCopia.area
local devolverGuardado, esconder = CocheCopia.devolverGuardado, CocheCopia.esconder

-- Más suave aún (para la grúa de la cámara: sin tirón al empezar ni al parar).
local function suaveMas(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * x * (x * (6 * x - 15) + 10)
end

-- Lo que ha avanzado hacia delante (studs), su velocidad y su aceleración a los `tau` s de empezar a andar, si sale
-- de la plaza a `v1` studs/s.
local function adelante(tau: number, v1: number): (number, number, number)
	local x1, x2 = tau / TA, (tau - TB0) / (TB1 - TB0)
	local extra = VELOCIDAD - v1
	return v1 * TA * area(x1) + extra * (TB1 - TB0) * area(x2),
		v1 * suave(x1) + extra * suave(x2),
		v1 / TA * pendiente(x1) + extra / (TB1 - TB0) * pendiente(x2)
end

-- Dónde va la copia a los `t` s: su marco (en el centro de la carrocería, mirando hacia delante), lo que han rodado las
-- ruedas (con signo), su velocidad, su aceleración y la curva del camino (para el volante).
local function pose(s: Salida, t: number): (CFrame, number, number, number, number)
	if s.atras > 0 and t < ATRAS + s.atrasDura + PARADA then
		local x = (t - ATRAS) / s.atrasDura
		local r = s.atras * suave(x)
		local v = -s.atras / s.atrasDura * pendiente(x)
		local a = -s.atras / (s.atrasDura * s.atrasDura) * curvatura(x)
		-- Recto hacia atrás. Quieto tras la marcha atrás, ya con el volante girado para salir.
		local haciaAtras = Vector3.new(math.sin(s.psi0), 0, math.cos(s.psi0))
		return CFrame.new(s.p0 + haciaAtras * r) * CFrame.Angles(0, s.psi0, 0), -r, v, a, if x >= 1 then s.curva0 else 0
	end
	local d, v, a = adelante(t - (if s.atras > 0 then ATRAS + s.atrasDura + PARADA else SIN_ATRAS), s.v1)
	local plaza = s.plaza :: CocheCopia.Plaza
	return CocheCopia.enPlaza(plaza, d), d - s.atras, v, a, CocheCopia.curva(plaza, d)
end

-- Faros: parpadean al encenderse (cada hora de FAROS los cambia).
local function farosEncendidos(t: number): boolean
	local encendidos = false
	for _, cuando in FAROS do
		if t >= cuando then
			encendidos = not encendidos
		end
	end
	return encendidos
end

-- Ángulo de los limpias: de quietos hasta arriba y vuelta.
local function barrido(t: number): number
	if t < LIMPIAS then
		return 0
	end
	return AMPLITUD * (0.5 - 0.5 * math.cos((t - LIMPIAS) / PERIODO * 2 * math.pi))
end

-- Esconde a los que van sentados en el coche de verdad y devuelve a los que se bajan.
local function vigilarSentados(s: Salida, reloj: number)
	local sentados: { [Model]: boolean } = {}
	for _, asiento in s.asientos do
		local humanoide = (asiento :: any).Occupant :: Humanoid?
		local personaje = humanoide and humanoide.Parent
		if personaje and personaje:IsA("Model") then
			sentados[personaje] = true
		end
	end
	for _, otro in Players:GetPlayers() do
		local personaje = otro.Character
		local humanoide = personaje and personaje:FindFirstChildOfClass("Humanoid")
		if personaje and humanoide and humanoide.SeatPart and s.esAsiento[humanoide.SeatPart] then
			sentados[personaje] = true
		end
	end
	for personaje, guardado in s.escondidos do
		if not sentados[personaje] then
			devolverGuardado(guardado)
			s.escondidos[personaje] = nil
		end
	end
	local repasar = reloj >= s.repaso -- de vez en cuando, por si le ha salido algo luego (accesorios)
	if repasar then
		s.repaso = reloj + 0.5
	end
	for personaje in sentados do
		local guardado = s.escondidos[personaje]
		local otros = s.otros
		if not guardado and otros and otros[personaje] then -- ya escondido por la cinemática: pasa a los sentados
			devolverGuardado(otros[personaje])
			otros[personaje] = nil
		end
		if not guardado then
			local nuevo = {}
			s.escondidos[personaje] = nuevo
			esconder(personaje, nuevo, false)
		elseif repasar then
			esconder(personaje, guardado, false)
		end
	end
end

-- En tu cinemática, los demás personajes fuera de los planos (los sentados ya los esconde vigilarSentados).
local function vigilarOtros(s: Salida, reloj: number)
	local otros = s.otros
	if not otros or reloj < s.repasoOtros then
		return
	end
	s.repasoOtros = reloj + 0.5
	for _, otro in Players:GetPlayers() do
		local personaje = otro.Character
		if personaje and not s.escondidos[personaje] then
			local guardado = otros[personaje]
			if not guardado then
				guardado = {}
				otros[personaje] = guardado
			end
			esconder(personaje, guardado, false)
		end
	end
end

-- El fundido propio vuelve a transparente (y se esconde al acabar, si nadie lo ha vuelto a usar).
local function quitarNegro()
	if tweenNegro then
		tweenNegro:Cancel()
	end
	local tween = TweenService:Create(negro, TweenInfo.new(0.6), { BackgroundTransparency = 1 })
	tweenNegro = tween
	tween.Completed:Once(function()
		if tweenNegro == tween then
			tweenNegro = nil
			negro.Visible = false
		end
	end)
	tween:Play()
end

local function acabarCine(s: Salida)
	local devolver = s.cine
	if not devolver then
		return
	end
	s.cine = nil
	for i = #devolver, 1, -1 do
		local ok, fallo = pcall(devolver[i])
		if not ok then
			warn(`[SalidaVista] {fallo}`)
		end
	end
end

local function terminar(s: Salida)
	if s.acabada then
		return
	end
	s.acabada = true
	if salidas[s.modelo] == s then
		salidas[s.modelo] = nil
	end
	Bucle.quitar(s.tarea)
	acabarCine(s)
	for _, guardado in s.escondidos do
		devolverGuardado(guardado)
	end
	table.clear(s.escondidos)
	for i = #s.devolver, 1, -1 do
		local ok, fallo = pcall(s.devolver[i])
		if not ok then
			warn(`[SalidaVista] {fallo}`)
		end
	end
	table.clear(s.devolver)
end

-- Vas dentro: fuera la interfaz (también la que salga mientras, menos el fundido propio), la CoreGui y el ratón; cámara
-- Scriptable. Todo vuelve como estaba en acabarCine.
local function empezarCine(s: Salida)
	local devolver: { () -> () } = {}
	s.cine = devolver
	local function alAcabar(fn: () -> ())
		table.insert(devolver, fn)
	end

	local apagadas: { LayerCollector } = {}
	alAcabar(function()
		for _, capa in apagadas do
			if capa.Parent then
				capa.Enabled = true
			end
		end
	end)
	local function apagar(capa: Instance)
		if capa:IsA("LayerCollector") and capa ~= capaNegro and capa.Enabled then
			capa.Enabled = false
			table.insert(apagadas, capa)
		end
	end
	local gui = jugador:FindFirstChildOfClass("PlayerGui")
	if gui then
		for _, capa in gui:GetChildren() do
			apagar(capa)
		end
		local conexion = gui.ChildAdded:Connect(apagar)
		alAcabar(function()
			conexion:Disconnect()
		end)
	end

	local core: { [Enum.CoreGuiType]: boolean } = {}
	for _, tipo in Enum.CoreGuiType:GetEnumItems() do
		if tipo ~= Enum.CoreGuiType.All then
			local ok, encendido = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, tipo)
			if ok then
				core[tipo] = encendido
			end
		end
	end
	alAcabar(function()
		for tipo, encendido in core do
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, tipo, encendido)
		end
	end)
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)

	local raton = UserInputService.MouseIconEnabled
	alAcabar(function()
		UserInputService.MouseIconEnabled = raton
	end)
	UserInputService.MouseIconEnabled = false

	local otros: { [Model]: Guardado } = {}
	s.otros = otros
	s.repasoOtros = 0
	alAcabar(function()
		s.otros = nil
		for _, guardado in otros do
			devolverGuardado(guardado)
		end
	end)

	local camara = workspace.CurrentCamera
	local campo = camara.FieldOfView
	alAcabar(function()
		local actual = workspace.CurrentCamera
		actual.CameraType = Enum.CameraType.Custom
		actual.FieldOfView = campo
	end)
	camara.CameraType = Enum.CameraType.Scriptable

	if tweenNegro then
		tweenNegro:Cancel()
		tweenNegro = nil
	end
	negro.BackgroundTransparency = 1
	negro.Visible = true
	alAcabar(quitarNegro)
end

-- Los planos: (1) bajo, delante y a un lado, en la carretera, mirándolo arrancar; (2) grúa que empieza detrás y arriba
-- del coche, lo sigue hasta encima del carril y se queda atrás mientras se va. Y el fundido a negro antes de la hora.
local function moverCamara(s: Salida, t: number, ahora: number, marco: CFrame, camara: Camera)
	if t < PLANO1 then
		local u = math.clamp(t / PLANO1, 0, 1)
		local ojo = Vector3.new(CARRIL - 2.5 + 0.6 * u, s.suelo + 1.2 + 0.25 * u, s.p0.Z - 16.5 + 1.3 * u)
		camara.FieldOfView = CAMPO1
		camara.CFrame = CFrame.lookAt(ojo, marco.Position + marco.LookVector * 2 + Vector3.new(0, 0.4, 0))
	else
		local u = suaveMas((t - PLANO1) / s.grua)
		local ojo = s.gruaA:Lerp(s.gruaB, u):Lerp(s.gruaB:Lerp(s.gruaC, u), u)
			+ Vector3.new(0, 0, -1.2 * math.max(0, t - PLANO1 - s.grua)) -- al acabar, sigue un poco, muy despacio
		camara.FieldOfView = CAMPO2
		camara.CFrame = CFrame.lookAt(ojo, marco.Position + Vector3.new(0, 0.8, 0))
	end
	negro.BackgroundTransparency = 1 - suave((ahora - (s.hora - NEGRO)) / (NEGRO - NEGRO_TODO))
end

local function moverCopia(s: Salida, t: number, dt: number, camara: Camera, marco: CFrame, rodado: number, v: number,
	a: number, curva: number)
	local copia = s.copia
	if not copia then
		return
	end
	if marco.Position.Z <= FIN then -- al final de la carretera, entre la niebla: ya no se ve
		copia:Destroy()
		s.copia = nil
		return
	end
	-- De lejos, o con Rendimiento (salvo el coche en el que vas), solo se mueve: sin adornos.
	local cerca = s.cine ~= nil or (camara.CFrame.Position - marco.Position).Magnitude < Config.Lobby.Cerca
	local rendimiento = jugador:GetAttribute("Rendimiento") == true
	local adorno = cerca and (s.cine ~= nil or not rendimiento)

	local faros = farosEncendidos(t)
	if faros ~= s.estadoFaros then
		s.estadoFaros = faros
		for _, faro in s.faros do
			CocheCopia.encender(faro, faros, FARO_LUZ)
		end
	end
	local pilotos = t >= FAROS[1]
	if pilotos ~= s.estadoPilotos then
		s.estadoPilotos = pilotos
		for _, piloto in s.pilotos do
			CocheCopia.encender(piloto, pilotos, PILOTO_LUZ)
		end
	end

	local humo = s.humo
	if humo then
		local cuanto = 0
		if adorno and t >= CONTACTO then
			cuanto = (9 + 26 * math.clamp(a / 16, 0, 1) + 0.15 * math.abs(v)) * (if rendimiento then 0.35 else 1)
			if not s.bocanada then
				s.bocanada = true
				if t < CONTACTO + 0.5 then
					humo:Emit(if rendimiento then 3 else 8) -- el motor arranca
				end
			end
		end
		humo.Rate = cuanto
	end

	-- La carrocería tiembla al arrancar y en ralentí (lo demás, en CocheCopia.mover).
	local temblor = 0
	if adorno then
		local fuerza = if t < CONTACTO then 0 elseif t < CONTACTO + 0.4 then 0.045 - 0.0875 * (t - CONTACTO) else 0.01
		temblor = fuerza * (if math.abs(v) < 0.3 then 1 else 0.25) * math.sin(t * 150)
	end
	CocheCopia.mover(s, marco, rodado, v, a, curva, dt, adorno, temblor, barrido(t))

	local punto = s.ruidoPunto -- el ruido del motor va con el coche
	if punto and punto.Parent then
		punto.WorldPosition = marco.Position
	end
end

local function paso(s: Salida, dt: number, camara: Camera)
	local ahora = workspace:GetServerTimeNow()
	if ahora > s.hora + ESPERA then -- sigue aquí: no se ha ido (o el servidor no ha quitado la hora)
		terminar(s)
		return
	end
	if s.suelta and not s.copia then -- ya se ha perdido en la niebla: lo demás lo lleva LlegadaVista
		terminar(s)
		return
	end
	local t = ahora - s.inicio
	vigilarSentados(s, os.clock())
	local marco, rodado, v, a, curva = pose(s, t)
	moverCopia(s, t, dt, camara, marco, rodado, v, a, curva)
	-- La cinemática, si vas dentro. Si te bajas, se acaba la tuya y lo ves irse como los demás.
	local dentro = jugador:GetAttribute("Coche") == s.modelo.Name
	if dentro and not s.cine and not s.suelta and ahora < s.hora then
		empezarCine(s)
	elseif not dentro and s.cine then
		acabarCine(s)
	end
	if s.cine then
		vigilarOtros(s, os.clock())
		moverCamara(s, t, ahora, marco, camara)
	end
end

local function preparar(s: Salida)
	local modelo = s.modelo
	local plaza = CocheCopia.plaza(modelo)
	s.plaza = plaza
	s.p0, s.psi0, s.eje = plaza.p0, plaza.psi0, plaza.eje
	s.suelo, s.techo = plaza.suelo, plaza.techo
	s.atras = plaza.atras
	s.atrasDura = ATRAS_DURA[1] + ATRAS_DURA[2] * s.atras
	s.giro = plaza.giro
	s.v1 = math.min(SALE, plaza.giro * 1.1) -- girando muy cerrado, más despacio (que no dé un latigazo)
	s.curva0 = CocheCopia.curva(plaza, 0)

	-- La copia (como aparcado: limpias en su sitio, faros y pilotos apagados) y el de verdad, escondido en este cliente
	-- (GasolineraVista no lo toca mientras) y sin prompt. Vuelve al acabar, aunque falle lo de después.
	local copia = CocheCopia.copiar(modelo)
	table.insert(s.devolver, function()
		CocheCopia.destapar(modelo, s)
	end)
	CocheCopia.tapar(modelo, s)
	for _, d in modelo:GetDescendants() do
		if d:IsA("Seat") or d:IsA("VehicleSeat") then
			table.insert(s.asientos, d)
			s.esAsiento[d] = true
		end
	end

	table.insert(s.devolver, function()
		copia:Destroy()
	end)
	CocheCopia.repartir(s, copia)
	local escape = copia:FindFirstChild("Escape", true)
	if escape and escape:IsA("Attachment") then
		for _, viejo in escape:GetChildren() do
			if viejo:IsA("ParticleEmitter") then
				viejo:Destroy() -- el humo del coche parado, si lo tenía: aquí va el de la salida
			end
		end
		s.humo = CocheCopia.hacerHumo(escape, -plaza.f0.LookVector)
	end
	copia.Parent = CocheCopia.carpeta()
	s.copia = copia

	-- La grúa del segundo plano: de detrás y arriba del coche (donde esté al cambiar de plano) a encima del carril,
	-- curvándose hacia la carretera para no pasar por encima de los coches aparcados.
	local marco1 = pose(s, PLANO1)
	local detras = marco1.Position - marco1.LookVector * 11
	s.gruaA = Vector3.new(detras.X, s.techo + 2.4, detras.Z)
	s.gruaC = Vector3.new(CARRIL + 1.3, s.techo - 0.3, s.p0.Z - 14)
	s.gruaB = s.gruaA:Lerp(s.gruaC, 0.5) + Vector3.new(-3, 0.8, 0)
	s.grua = math.max(1.5, Config.Coches.Salida - PLANO1 - 0.6)

	if workspace:GetServerTimeNow() - s.inicio < 0.8 then -- al llegar tarde, ya ha arrancado
		local ruido = Sonido.en("Arranque", s.p0)
		if ruido then
			local punto = ruido.Parent
			s.ruidoPunto = if punto and punto:IsA("Attachment") then punto else nil
			table.insert(s.devolver, function()
				ruido:Destroy()
				if punto and punto:IsA("Attachment") then
					punto:Destroy()
				end
			end)
		end
	end
end

local function empezar(modelo: Model, hora: number)
	local s: Salida = {
		modelo = modelo,
		hora = hora,
		inicio = hora - Config.Coches.Salida,
		tarea = "SalidaVista:" .. modelo.Name,
		p0 = Vector3.zero,
		psi0 = 0,
		eje = 4.2,
		suelo = 0,
		techo = 0,
		atras = 0,
		atrasDura = ATRAS_DURA[1],
		giro = 9,
		v1 = SALE,
		curva0 = 0,
		plaza = nil,
		copia = nil,
		lista = {},
		bases = {},
		grupos = {},
		cframes = {},
		ruedas = {},
		limpias = {},
		batalla = 7.6,
		volante = 0,
		faros = {},
		pilotos = {},
		estadoFaros = nil,
		estadoPilotos = nil,
		humo = nil,
		bocanada = false,
		ruidoPunto = nil,
		asientos = {},
		esAsiento = {},
		escondidos = {},
		repaso = 0,
		otros = nil,
		repasoOtros = 0,
		devolver = {},
		cine = nil,
		gruaA = Vector3.zero,
		gruaB = Vector3.zero,
		gruaC = Vector3.zero,
		grua = 2.6,
		acabada = false,
		suelta = false,
	}
	salidas[modelo] = s
	local function fallo(mensaje: any)
		warn(`[SalidaVista] {modelo.Name}: {mensaje}`)
		terminar(s)
	end
	local ok, porque = pcall(preparar, s)
	if not ok then
		fallo(porque)
		return
	end
	local function cada(dt: number, _: number, camara: Camera)
		local bien, motivo = pcall(paso, s, dt, camara)
		if not bien then
			fallo(motivo)
		end
	end
	Bucle.cada(s.tarea, cada)
	cada(0, 0, workspace.CurrentCamera) -- ya, para que no se vea ni un fotograma la copia en el sitio del otro
end

local function registrar(objeto: Instance)
	if not objeto:IsA("Model") or vigilados[objeto] then
		return
	end
	local modelo = objeto :: Model
	vigilados[modelo] = true
	CocheCopia.apuntar(modelo)
	local function mirar()
		local hora = modelo:GetAttribute("Salida")
		local ahora = workspace:GetServerTimeNow()
		local s = salidas[modelo]
		if s and s.hora ~= hora then
			if not s.suelta and hora == nil and ahora >= s.hora and type(modelo:GetAttribute("Llegada")) == "number" then
				-- Se ha ido de verdad y vuelve otro coche (LlegadaVista, que ya lo tiene escondido): esta copia sigue
				-- hasta perderse en la niebla.
				s.suelta = true
				acabarCine(s)
			elseif hora ~= nil or not s.suelta then
				terminar(s) -- se ha parado (o vuelto a arrancar con otra hora)
			end
		end
		s = salidas[modelo]
		if type(hora) ~= "number" or (s and s.hora == hora) or not modelo:IsDescendantOf(workspace)
			or ahora >= hora + TARDE then
			return
		end
		local inicio = hora - Config.Coches.Salida
		if ahora < inicio - 0.05 then
			-- El servidor la ha retrasado (estaba llegando otro coche por el carril): hasta entonces, quieto.
			if esperando[modelo] ~= hora then
				esperando[modelo] = hora
				task.delay(inicio - ahora, function()
					if esperando[modelo] == hora then
						esperando[modelo] = nil
						mirar()
					end
				end)
			end
			return
		end
		esperando[modelo] = nil
		if s then
			terminar(s) -- la de antes, suelta
		end
		empezar(modelo, hora)
	end
	modelo:GetAttributeChangedSignal("Salida"):Connect(mirar)
	mirar()
end

function SalidaVista.start()
	Sonido.precargar({ "Arranque" })
	-- El fundido propio, por debajo del de CochesUi (DisplayOrder 100), que se esconde con el resto de la interfaz.
	capaNegro = Instance.new("ScreenGui")
	capaNegro.Name = "FundidoSalida"
	capaNegro.IgnoreGuiInset = true
	capaNegro.DisplayOrder = 99
	capaNegro.ResetOnSpawn = false
	negro = Instance.new("Frame")
	negro.Size = UDim2.fromScale(1, 1)
	negro.BackgroundColor3 = Color3.new(0, 0, 0)
	negro.BackgroundTransparency = 1
	negro.BorderSizePixel = 0
	negro.Visible = false
	negro.Parent = capaNegro
	capaNegro.Parent = jugador:WaitForChild("PlayerGui")

	for _, modelo in CollectionService:GetTagged("Coche") do
		registrar(modelo)
	end
	CollectionService:GetInstanceAddedSignal("Coche"):Connect(registrar)
	CollectionService:GetInstanceRemovedSignal("Coche"):Connect(function(objeto)
		local s = salidas[objeto :: any]
		if s then
			terminar(s)
		end
	end)
end

return SalidaVista