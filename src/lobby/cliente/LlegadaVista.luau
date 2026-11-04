-- El coche que llega al lobby tras un viaje (pedido por el usuario, 14.9.3: el de verdad reaparecía de golpe en su
-- sitio al quedar libre). Coches (servidor) pone en el coche el atributo Llegada = hora del servidor a la que se para en
-- su plaza (nil = nada); hasta entonces nadie se sube. Desde ese momento, en cada cliente:
--   · El coche de verdad sigue escondido (CocheCopia.tapar: si se acaba de ir, SalidaVista ya lo tenía así y se lo pasa
--     sin que se vea ni un fotograma).
--   · DURA s antes de la hora, una copia aparece entre la niebla al fondo de la carretera (+Z) con los faros
--     encendidos y viene por el carril derecho; frena con los pilotos más rojos y se para pasada su plaza, mete marcha
--     atrás y entra en la plaza por el mismo camino por el que sale el que se va (SalidaVista), pero al revés: así no le
--     da a los de delante ni a los de detrás. Si al salir hacía falta marcha atrás, al final avanza eso mismo. Se queda
--     un momento en marcha, apaga las luces y, a la hora, la copia se borra y vuelve a verse el de verdad, que está justo
--     ahí (el mismo sitio, las luces apagadas).
-- Todo según la hora del servidor: todos lo ven igual y quien entra a medias lo ve donde toca. El movimiento, en el
-- Bucle y solo mientras va la copia (antes, nada: el coche está escondido y ya). Lejos de la cámara o con Rendimiento,
-- sin adornos (ruedas, limpias, humo, temblor). Lo devuelve todo siempre: a la hora, si Llegada vuelve a nil o cambia y
-- si algo falla. Si al acabar estás de pie donde aparece el coche, te aparta a un lado.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Bucle = require(script.Parent.Bucle)
local CocheCopia = require(script.Parent.CocheCopia)
local Sonido = require(script.Parent.Sonido)

local LlegadaVista = {}

local jugador = Players.LocalPlayer

-- Tiempos (s). DURA y CERCA cuadran con Coches (servidor), que no deja pasar a otro por el carril mientras tanto; los
-- mira tests/bancos/lobby-coche.luau. Lo demás, a ojo.
LlegadaVista.DURA = 22 -- de que aparece entre la niebla a que se para del todo
LlegadaVista.CERCA = 16 -- los últimos segundos, desde que llega a la altura de las plazas
local DURA = LlegadaVista.DURA
local VELOCIDAD = 30 -- studs/s por la carretera
local FRENO = 3.2 -- segundos frenando hasta pararse pasada la plaza
local PASADA = 2 -- studs que se pasa del final de la curva (para pararse ya recto)
local QUIETO1 = 0.8 -- parado antes de meter marcha atrás
local ATRAS_VEL = 3.6 -- studs/s de media marcha atrás (en tiempo, entre ATRAS_MIN y ATRAS_MAX s)
local ATRAS_MIN, ATRAS_MAX = 3, 9
local QUIETO2 = 0.5 -- parado antes de avanzar lo que hiciera falta para quedar en su sitio
local AVANCE = { 0.6, 0.25 } -- segundos que tarda en avanzar eso: lo primero más lo segundo por cada stud
local RALENTI = 1.2 -- en marcha, ya en su sitio, antes de apagar
local APAGADO = 0.6 -- apagado antes de que vuelva el de verdad (y sin adornos: la copia, justo como el de verdad)
local LEJOS = 250 -- más lejos de la cámara, entre la niebla, solo se mueve cada MOVER_LEJOS s
local MOVER_LEJOS = 0.25
local AMPLITUD, PERIODO = math.rad(80), 1.3 -- limpiaparabrisas: cuánto giran y cada cuánto
local PILOTO_FRENO = Color3.fromRGB(236, 54, 42) -- los pilotos al frenar (más claros que encendidos)
-- El ruido del motor: el bucle MotorCoche si lo hay en Config.SonidosLobby (cambia de tono con la velocidad); si no,
-- el Arranque de la salida, una vez, cuando ya se acerca (hoy los dos con Id 0: no suenan).
-- Sonido.hay mira que tenga Id: con Id 0 no hay motor y suena el Arranque.
local MOTOR = if Sonido.hay("MotorCoche") then "MotorCoche" else nil

type Llegada = CocheCopia.Copia & {
	modelo: Model,
	hora: number, -- la hora del servidor a la que se para (atributo Llegada)
	inicio: number, -- cuando aparece entre la niebla
	tarea: string,
	plaza: CocheCopia.Plaza?,
	-- El plan, en segundos desde inicio y en studs del camino de salida (CocheCopia.enPlaza).
	recorrido: number, -- de dónde se para (d) a la plaza, marcha atrás
	parada: number, -- cuándo se para pasada la plaza
	atrasDesde: number,
	atrasDura: number,
	avanceDesde: number,
	avanceDura: number,
	apaga: number, -- cuándo apaga las luces
	acercarse: number, -- studs que viene por la carretera hasta pararse
	marcoParada: CFrame, -- dónde se para (ya recto en el carril)
	copia: Model?,
	estadoFaros: boolean?,
	estadoPilotos: Color3?,
	humo: ParticleEmitter?,
	ruido: Sound?,
	punto: Attachment?,
	sonado: boolean,
	movida: number, -- os.clock() de la última vez que se movió (de lejos)
	devolver: { () -> () },
	acabada: boolean,
}

local llegadas: { [Model]: Llegada } = {}
local vigilados: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any

local suave, pendiente, curvatura = CocheCopia.suave, CocheCopia.pendiente, CocheCopia.curvatura

-- El plan de la llegada, de atrás hacia delante desde que se para del todo.
local function planear(l: Llegada, plaza: CocheCopia.Plaza)
	l.plaza = plaza
	l.p0, l.psi0 = plaza.p0, plaza.psi0
	l.recorrido = plaza.recorrido + PASADA
	l.marcoParada = CocheCopia.enPlaza(plaza, l.recorrido)
	l.apaga = DURA - APAGADO
	local quieto = l.apaga - RALENTI
	l.avanceDura = if plaza.atras > 0 then AVANCE[1] + AVANCE[2] * plaza.atras else 0
	l.avanceDesde = quieto - l.avanceDura
	l.atrasDura = math.clamp(l.recorrido / ATRAS_VEL, ATRAS_MIN, ATRAS_MAX)
	l.atrasDesde = l.avanceDesde - (if plaza.atras > 0 then QUIETO2 else 0) - l.atrasDura
	l.parada = l.atrasDesde - QUIETO1
	-- Por la carretera a VELOCIDAD y frenando FRENO s (la mitad de lo que haría sin frenar).
	l.acercarse = VELOCIDAD * (l.parada - FRENO / 2)
end

-- Dónde va la copia a los `t` s: su marco (en el centro de la carrocería, mirando hacia delante), lo que han rodado las
-- ruedas (con signo), su velocidad, su aceleración y la curva del camino (para el volante).
local function pose(l: Llegada, t: number): (CFrame, number, number, number, number)
	local plaza = l.plaza :: CocheCopia.Plaza
	if t < l.parada then
		-- Por la carretera hacia -Z, frenando al final.
		local x = (t - (l.parada - FRENO)) / FRENO
		local hecho = VELOCIDAD * math.min(t, l.parada - FRENO)
		local v, a = VELOCIDAD, 0
		if x > 0 then
			hecho += VELOCIDAD * FRENO * (x - CocheCopia.area(x))
			v = VELOCIDAD * (1 - suave(x))
			a = -VELOCIDAD / FRENO * pendiente(x)
		end
		return l.marcoParada + Vector3.new(0, 0, l.acercarse - hecho), hecho, v, a, 0
	end
	if t < l.atrasDesde + l.atrasDura then
		-- Marcha atrás por el camino de salida, hasta el principio (quieto antes, con el volante aún recto).
		local x = (t - l.atrasDesde) / l.atrasDura
		local d = l.recorrido * (1 - suave(x))
		local v = -l.recorrido / l.atrasDura * pendiente(x)
		local a = -l.recorrido / (l.atrasDura * l.atrasDura) * curvatura(x)
		return CocheCopia.enPlaza(plaza, d), l.acercarse - l.recorrido + d, v, a, if x > 0 then CocheCopia.curva(plaza, d) else 0
	end
	-- Lo que le falte hacia delante (lo que el que sale da de marcha atrás) y quieto en su sitio.
	local rodado = l.acercarse - l.recorrido
	if plaza.atras <= 0 or t >= l.avanceDesde + l.avanceDura then
		return plaza.f0, rodado + plaza.atras, 0, 0, 0
	end
	local x = (t - l.avanceDesde) / l.avanceDura
	local f = plaza.atras * suave(x)
	local adelante = plaza.f0.LookVector
	local v = plaza.atras / l.avanceDura * pendiente(x)
	local a = plaza.atras / (l.avanceDura * l.avanceDura) * curvatura(x)
	return plaza.f0 - adelante * (plaza.atras - f), rodado + f, v, a, 0
end

-- Los limpias barren mientras va en marcha; la última pasada acaba antes de apagar (y quedan en su sitio).
local function barrido(l: Llegada, t: number): number
	if math.floor(t / PERIODO) >= math.floor(l.apaga / PERIODO) then -- la última pasada acaba antes de apagar
		return 0
	end
	return AMPLITUD * (0.5 - 0.5 * math.cos(t / PERIODO * 2 * math.pi))
end

local function terminar(l: Llegada)
	if l.acabada then
		return
	end
	l.acabada = true
	if llegadas[l.modelo] == l then
		llegadas[l.modelo] = nil
	end
	Bucle.quitar(l.tarea)
	for i = #l.devolver, 1, -1 do
		local ok, fallo = pcall(l.devolver[i])
		if not ok then
			warn(`[LlegadaVista] {fallo}`)
		end
	end
	table.clear(l.devolver)
end

local function paso(l: Llegada, dt: number, camara: Camera)
	local t = workspace:GetServerTimeNow() - l.inicio
	if t >= DURA then
		terminar(l)
		return
	end
	local copia = l.copia
	if not copia then
		return
	end
	local marco, rodado, v, a, curva = pose(l, t)
	local distancia = (camara.CFrame.Position - marco.Position).Magnitude
	local reloj = os.clock()
	if distancia > LEJOS and reloj - l.movida < MOVER_LEJOS then
		return -- entre la niebla: no hace falta moverlo en cada fotograma
	end
	l.movida = reloj
	local rendimiento = jugador:GetAttribute("Rendimiento") == true
	local adorno = distancia < Config.Lobby.Cerca and not rendimiento and t < l.apaga + 0.3
	local enMarcha = t < l.apaga

	local faros = enMarcha
	if faros ~= l.estadoFaros then
		l.estadoFaros = faros
		for _, faro in l.faros do
			CocheCopia.encender(faro, faros, CocheCopia.FARO_LUZ)
		end
	end
	-- Pilotos: encendidos, más claros al frenar y parado con el pie en el freno.
	local frenando = a < -0.5 or (math.abs(v) < 0.05 and t >= l.parada - 0.2)
	local pilotos = if not enMarcha then nil elseif frenando then PILOTO_FRENO else CocheCopia.PILOTO_LUZ
	if pilotos ~= l.estadoPilotos then
		l.estadoPilotos = pilotos
		for _, piloto in l.pilotos do
			CocheCopia.encender(piloto, pilotos ~= nil, pilotos or CocheCopia.PILOTO_LUZ)
		end
	end

	local humo = l.humo
	if humo then
		local cuanto = if adorno and enMarcha then 6 + 20 * math.clamp(math.abs(a) / 12, 0, 1) else 0
		if humo.Rate ~= cuanto then
			humo.Rate = cuanto
		end
	end

	-- Tiembla un poco en marcha y da un respingo al apagar.
	local temblor = 0
	if adorno then
		local fuerza = if enMarcha then (if math.abs(v) < 0.3 then 0.01 else 0.0025)
			else 0.04 * math.max(0, 1 - (t - l.apaga) / 0.3)
		temblor = fuerza * math.sin(t * 150)
	end
	CocheCopia.mover(l, marco, rodado, v, a, curva, dt, adorno, temblor, barrido(l, t))

	local punto = l.punto -- el ruido del motor va con el coche
	if punto and punto.Parent then
		punto.WorldPosition = marco.Position
	end
	local ruido = l.ruido
	if ruido then
		ruido.PlaybackSpeed = 0.8 + 0.012 * math.abs(v)
		ruido.Volume = if enMarcha then (Config.SonidosLobby :: any).MotorCoche.Volumen else 0
	elseif not l.sonado and t >= DURA - LlegadaVista.CERCA then
		l.sonado = true
		local una = Sonido.en("Arranque", marco.Position)
		local donde = una and una.Parent
		if donde and donde:IsA("Attachment") then
			l.punto = donde
		end
	end
end

-- La copia y todo lo que se mueve con ella (cuando empieza a llegar).
local function preparar(l: Llegada)
	local modelo = l.modelo
	planear(l, CocheCopia.plaza(modelo))
	local copia = CocheCopia.copiar(modelo)
	table.insert(l.devolver, function()
		copia:Destroy()
		l.copia = nil
	end)
	CocheCopia.repartir(l, copia)
	local escape = copia:FindFirstChild("Escape", true)
	if escape and escape:IsA("Attachment") then
		for _, viejo in escape:GetChildren() do
			if viejo:IsA("ParticleEmitter") then
				viejo:Destroy() -- el humo del coche parado, si lo tenía
			end
		end
		l.humo = CocheCopia.hacerHumo(escape, -(l.plaza :: CocheCopia.Plaza).f0.LookVector)
	end
	if MOTOR then
		local punto = Instance.new("Attachment")
		punto.Name = "MotorLlegada"
		punto.Parent = workspace.Terrain
		l.punto = punto
		table.insert(l.devolver, function()
			punto:Destroy()
		end)
		l.ruido = Sonido.bucle(MOTOR, punto)
	end
	copia.Parent = CocheCopia.carpeta()
	l.copia = copia
end

local function arrancar(l: Llegada)
	if l.acabada then
		return
	end
	local ok, porque = pcall(preparar, l)
	if not ok then
		warn(`[LlegadaVista] {l.modelo.Name}: {porque}`)
		terminar(l)
		return
	end
	local function cada(dt: number, _: number, camara: Camera)
		local bien, motivo = pcall(paso, l, dt, camara)
		if not bien then
			warn(`[LlegadaVista] {l.modelo.Name}: {motivo}`)
			terminar(l)
		end
	end
	Bucle.cada(l.tarea, cada)
	cada(0, 0, workspace.CurrentCamera) -- ya, para que no se vea ni un fotograma la copia en la plaza
end

local function empezar(modelo: Model, hora: number)
	local l: Llegada = {
		modelo = modelo,
		hora = hora,
		inicio = hora - DURA,
		tarea = "LlegadaVista:" .. modelo.Name,
		plaza = nil,
		p0 = Vector3.zero,
		psi0 = 0,
		recorrido = 0,
		parada = 0,
		atrasDesde = 0,
		atrasDura = ATRAS_MIN,
		avanceDesde = 0,
		avanceDura = 0,
		apaga = DURA,
		acercarse = 0,
		marcoParada = CFrame.identity,
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
		ruido = nil,
		punto = nil,
		sonado = false,
		movida = -math.huge,
		devolver = {},
		acabada = false,
	}
	llegadas[modelo] = l
	-- El de verdad, escondido desde ya (el coche se ha ido); vuelve al acabar pase lo que pase.
	table.insert(l.devolver, function()
		CocheCopia.destapar(modelo, l, true) -- vacío y apagado, como la copia
		CocheCopia.apartar(modelo, l.plaza)
	end)
	CocheCopia.tapar(modelo, l)
	local falta = l.inicio - workspace:GetServerTimeNow()
	if falta > 0 then
		task.delay(falta, arrancar, l) -- hasta entonces no hay nada que mover
	else
		arrancar(l)
	end
end

local function registrar(objeto: Instance)
	if not objeto:IsA("Model") or vigilados[objeto] then
		return
	end
	local modelo = objeto :: Model
	vigilados[modelo] = true
	CocheCopia.apuntar(modelo)
	local function mirar()
		local hora = modelo:GetAttribute("Llegada")
		local l = llegadas[modelo]
		if l and l.hora ~= hora then
			terminar(l) -- se ha quitado antes de hora (o ha cambiado)
			l = nil
		end
		if not l and type(hora) == "number" and modelo:IsDescendantOf(workspace) and workspace:GetServerTimeNow() < hora then
			empezar(modelo, hora)
		end
	end
	modelo:GetAttributeChangedSignal("Llegada"):Connect(mirar)
	mirar()
end

function LlegadaVista.start()
	if MOTOR then
		Sonido.precargar({ MOTOR })
	end
	for _, modelo in CollectionService:GetTagged("Coche") do
		registrar(modelo)
	end
	CollectionService:GetInstanceAddedSignal("Coche"):Connect(registrar)
	CollectionService:GetInstanceRemovedSignal("Coche"):Connect(function(objeto)
		local l = llegadas[objeto :: any]
		if l then
			terminar(l)
		end
	end)
end

return LlegadaVista
