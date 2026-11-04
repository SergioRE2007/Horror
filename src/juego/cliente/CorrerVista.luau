-- Correr y aguante, en tu cliente (14.8, pedido por el usuario: "añadir la mecánica de correr, que tengas una stamina
-- abajo del todo, una barra fina así minimalista que aparezca al correr"; y "todo animado e inmersivo"). El servidor
-- (juego/servidor/Correr) manda; aquí se pide, se predice con las mismas reglas (shared/CorrerReglas) para que vaya al
-- momento y se pinta la barra (CorrerBarra).
--   Controles: mantener Shift izquierdo; L3 del mando y el botón CORRER del móvil (Hud.EquipoBotones, LayoutOrder 7,
--   junto a AGACHARSE) alternan: con el pulgar en la palanca, mantener cansa. Lo alternado se apaga solo al pararte un
--   rato (PARADO s; antes de haber corrido, PARADO_SIN), al agotarte, al morir, al esconderte y al reaparecer. Shift se
--   suelta siempre al soltarlo (aunque estuvieras escribiendo) y al perder el foco de la ventana. Agachado, pedir
--   correr te levanta si cabes (PosturaVista.levantarse).
--   Se manda Remotes.Correr (sí/no) solo al cambiar lo que quieres. La predicción: CorrerReglas.paso cada fotograma con
--   tus datos y tu velocidad; se acerca al atributo Aguante si se separa (más de TOLERANCIA, más lo que cambia en lo
--   que tarda en llegar) y se agota si el servidor dice Agotado (y deja de estarlo si él no lo confirma).
--   Velocidad local, para que vaya al momento: corres de verdad si lo predices y el servidor lo confirma (atributo
--   Corriendo) o hace menos de Config.Correr.Gracia s que empezaste. WalkSpeed = CorrerReglas.velocidad(Andar, eso):
--   es lo único que pone WalkSpeed en el cliente (lo de verdad lo pone el servidor, Cargar.ajustarVelocidad).
--   Sonidos: al agotarte, un jadeo fuerte solo para ti y luego resoplidos cada vez más flojos y espaciados mientras
--   sigues cansado (escondido no: ahí respira MuerteVista). De los demás, cerca (OIDO_OTROS), un jadeo en su cabeza al
--   agotarse. Mientras Config.Sonidos.Jadeo no tenga grabación, el provisional Config.Correr.Jadeo, corto y con caída.
--   Muerto, escondido o al reaparecer: todo a reposo.
-- Lo usan CuerpoVista, Pasos, BrazosVista, las manos y MuerteVista con la API de abajo (vale antes de start()).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local CorrerReglas = require(ReplicatedStorage.Shared.CorrerReglas)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CorrerBarra = require(script.Parent.CorrerBarra)
local PosturaVista = require(script.Parent.PosturaVista)
local Sonido = require(script.Parent.Sonido)
local Ui = require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))

local CorrerVista = {}

local C = Config.Correr
-- Números a ojo (para mirarlos en Studio).
local PARADO = 0.8 -- s quieto que apagan L3 o el botón (tras haber corrido)
local PARADO_SIN = 2.5 -- y si aún no has echado a correr (para que dé tiempo a pulsar y luego mover la palanca)
local TOLERANCIA = 0.03 -- de aguante que se deja separar la predicción del servidor
local ACERCA = 4 -- por segundo: lo deprisa que la predicción va hacia lo del servidor cuando se separa
local GRACIA_AGOTADO = 0.4 -- s (más el ping) que se espera a que el servidor confirme que te has agotado
local REAPARECE = 0.5 -- s (más el ping) tras reaparecer sin hacer caso al Aguante del servidor (el viejo aún llega)
local SUBE = 1 / 0.25 -- ritmo() por segundo al echar a correr...
local BAJA = 1 / 0.4 -- ...y al parar
local TROPIEZO = 1.6 -- s que dura un tropiezo
local OIDO_OTROS = 60 -- studs desde la cámara a los que se oye jadear a otro
local RESOPLA = 0.25 -- cansancio por debajo del cual ya no resoplas
local RESOPLA_HASTA = 1 - RESOPLA -- aguante al que paran los resoplidos
local RESOPLA_CADA = { 0.9, 2.6 } -- s entre resoplidos: recién agotado, casi descansado
local RESOPLA_FUERZA = { 0.75, 0.2 } -- y lo fuertes que son
local PRIMER_RESOPLIDO = 1.2 -- s tras el jadeo fuerte del agotamiento
local JADEO_OTRO = 0.9 -- fuerza del jadeo de otro al agotarse
-- El provisional (Config.Correr.Jadeo, un viento a otro tono): corto y con caída.
local PROV_ATAQUE = 0.06 -- s en subir
local PROV_LARGO = { 0.35, 0.9 } -- s en caer: flojo, fuerte
local PROV_VOLUMEN = 0.8 -- sobre el de su plantilla
local VARIA = 0.04 -- tono de más o de menos en los resoplidos (se repiten mucho; el jadeo fuerte, siempre igual)

local jugador = Players.LocalPlayer
local estado = CorrerReglas.nuevo() -- la predicción
local shift = false -- Shift izquierdo apretado
local alterna = false -- L3 o el botón CORRER puestos
local haCorrido = false -- desde que se puso lo alternado, si ya ha corrido (para PARADO)
local quietoDesde: number? = nil -- desde cuándo está parado (para apagar lo alternado)
local empujaDesde: number? = nil -- desde cuándo empujas (palanca o teclas)
local mandado = false -- lo último mandado al servidor
local corres = false -- corres de verdad ahora (lo que mueve la velocidad local)
local empezo = -math.huge -- cuándo empezó la predicción a correr (para Config.Correr.Gracia)
local ritmoVisto = 0
local ultimaCarrera = -math.huge
local tropiezoEn = -math.huge
local tropiezos = 0 -- el último valor visto del atributo Tropiezo
local agotoEn = -math.huge
local reaparecioEn = -math.huge
local avisado = false -- ya se ha avisado de este agotamiento
local servidorAgotado = false -- lo último visto del atributo Agotado (para ver cuándo se agota allí)
local resoplando = false
local proximoResoplido = 0
local fuera = false -- muerto o escondido (todo a reposo)
local boton: TextButton? = nil
local encendido: boolean? = nil
local apagado: boolean? = nil
local barra: CorrerBarra.Barra? = nil
local vista = CorrerBarra.reposo()
local azar = Random.new()
local agotarse = Instance.new("BindableEvent")

-- API ---------------------------------------------------------------------------------------------------------------

-- Tú, ahora (predicho y confirmado o recién empezado: lo que mueve la velocidad local).
function CorrerVista.corriendo(): boolean
	return corres
end

-- De 0 a 1 suavizado (sube en ~0,25 s al echar a correr y baja en ~0,4 s): para mezclar efectos sin saltos.
function CorrerVista.ritmo(): number
	return ritmoVisto
end

-- De 0 a 1, predicho.
function CorrerVista.aguante(): number
	return estado.aguante
end

function CorrerVista.agotado(): boolean
	return estado.agotado
end

-- De 0 a 1 (agotado, 1): respiración, vaho, jadeo escondido.
function CorrerVista.cansancio(): number
	return CorrerReglas.cansancio(estado)
end

-- Segundos desde que empezó tu tropiezo, si hay uno en marcha (dura TROPIEZO s); nil si no.
function CorrerVista.tropiezo(): number?
	local t = os.clock() - tropiezoEn
	return if t >= 0 and t < TROPIEZO then t else nil
end

-- Segundos desde que corriste por última vez (math.huge si nunca).
function CorrerVista.recien(): number
	return if ultimaCarrera == -math.huge then math.huge else os.clock() - ultimaCarrera
end

-- Te has agotado (predicho; una vez por agotamiento).
function CorrerVista.alAgotarse(fn: () -> ()): RBXScriptConnection
	return agotarse.Event:Connect(fn)
end

local function mezcla(par: { number }, t: number): number
	return par[1] + (par[2] - par[1]) * math.clamp(t, 0, 1)
end

-- Un jadeo en `padre` (en 3D; nil: sin posición, solo para ti) con `fuerza` de 0 a 1.
function CorrerVista.jadear(padre: Instance?, fuerza: number)
	fuerza = math.clamp(if fuerza == fuerza then fuerza else 0, 0, 1)
	if fuerza <= 0 then
		return
	end
	local real = Sonido.hay("Jadeo")
	local nombre = if real then "Jadeo" else C.Jadeo
	if not Config.Sonidos[nombre] then
		return
	end
	local s = Sonido.bucle(nombre, padre) -- una copia de la plantilla (precargada), ya sonando
	s.Looped = false
	if padre then
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 6
		s.RollOffMaxDistance = Config.Sonidos.Jadeo.Alcance
	end
	local varia = if fuerza >= 1 then 0 else azar:NextNumber(-VARIA, VARIA)
	if real then
		s.Volume *= fuerza
		s.PlaybackSpeed = 1 + varia
		s.Ended:Once(function()
			s:Destroy()
		end)
		task.delay(10, function()
			if s.Parent then
				s:Destroy()
			end
		end)
		return
	end
	-- El provisional: un trozo del viento, a otro tono, que sube de golpe y cae.
	local largo = mezcla(PROV_LARGO, fuerza)
	local volumen = s.Volume * PROV_VOLUMEN * fuerza
	s.PlaybackSpeed = C.JadeoTono * (1 + varia)
	if s.TimeLength > largo * s.PlaybackSpeed + 0.5 then
		s.TimePosition = azar:NextNumber(0, s.TimeLength - largo * s.PlaybackSpeed - 0.3)
	end
	s.Volume = 0
	local sube = TweenService:Create(s, TweenInfo.new(PROV_ATAQUE), { Volume = volumen })
	sube.Completed:Once(function()
		if s.Parent then
			TweenService:Create(s, TweenInfo.new(largo, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Volume = 0 })
				:Play()
		end
	end)
	sube:Play()
	task.delay(PROV_ATAQUE + largo + 0.1, function()
		if s.Parent then
			s:Destroy()
		end
	end)
end

-- Lo de cada fotograma ----------------------------------------------------------------------------------------------

local function humanoide(): Humanoid?
	local personaje = jugador.Character
	return personaje and personaje:FindFirstChildOfClass("Humanoid")
end

-- ¿Una cinemática? (cámara Scriptable sin estar mirando por la mirilla o las cortinas, como PosturaVista).
local function enCine(): boolean
	local camara = workspace.CurrentCamera
	return camara ~= nil and camara.CameraType == Enum.CameraType.Scriptable and jugador:GetAttribute("Vistazo") == nil
end

-- Tus datos para CorrerReglas, en la misma tabla siempre (se mira cada fotograma).
local misDatos: CorrerReglas.Jugador = {
	vivo = false, escondido = false, cargando = false, mochila = false, agachado = false, asomado = false,
	vistazo = false, cine = false,
}
local function datos(hum: Humanoid?): CorrerReglas.Jugador
	local q = misDatos
	q.vivo = hum ~= nil and hum.Health > 0 and not jugador:GetAttribute("Muerto")
	q.escondido = jugador:GetAttribute("Escondido") ~= nil
	q.cargando = jugador:GetAttribute("Cargando") ~= nil or jugador:GetAttribute("Trabajando") ~= nil
	q.mochila = jugador:GetAttribute("MochilaAbierta") == true
	q.agachado = PosturaVista.agachado()
	q.asomado = PosturaVista.asomado() ~= 0
	q.vistazo = jugador:GetAttribute("Vistazo") ~= nil
	q.cine = enCine()
	return q
end

-- Todo a reposo (muerto, escondido): sin pedir nada, sin resoplar, sin tropiezo.
local function reposo()
	shift, alterna, haCorrido, quietoDesde = false, false, false, nil
	corres, ritmoVisto = false, 0
	resoplando = false
	tropiezoEn = -math.huge
end

local function alAgotarse(ahora: number)
	if avisado then
		return
	end
	avisado = true
	agotoEn = ahora
	alterna = false -- lo alternado se apaga; Shift mantenido vuelve a correr al recuperar Config.Correr.Volver
	if not fuera then
		CorrerVista.jadear(nil, 1)
		resoplando = true
		proximoResoplido = ahora + PRIMER_RESOPLIDO
	end
	agotarse:Fire()
end

-- El botón del móvil: encendido (borde claro sobre rojo oscuro) mientras corres o lo tienes puesto; apagado si ahora
-- no se puede (como el de AGACHARSE de PosturaVista).
local function pintarBoton(libre: boolean)
	local b = boton
	if not b then
		return
	end
	if apagado ~= not libre then
		apagado = not libre
		b.TextTransparency = if libre then 0 else 0.55
	end
	local puesto = alterna or corres
	if encendido == puesto then
		return
	end
	encendido = puesto
	local info = TweenInfo.new(0.15)
	TweenService:Create(b, info, { BackgroundColor3 = if puesto then Ui.Color.Sangre else Ui.Color.Papel }):Play()
	local borde = b:FindFirstChildOfClass("UIStroke")
	if borde then
		TweenService:Create(borde, info, {
			Color = if puesto then Ui.Color.Hueso else Ui.Color.Sangre,
			Thickness = if puesto then 3 else 2,
		}):Play()
	end
end

-- Al pedir correr: agachado, te levantas (si cabes).
local function pedirCorrer()
	if PosturaVista.agachado() then
		PosturaVista.levantarse()
	end
end

local function cada(dt: number)
	local ahora = os.clock()
	local hum = humanoide()
	local d = datos(hum)
	local antesFuera = fuera
	fuera = not d.vivo or d.escondido
	if fuera and not antesFuera then
		reposo()
	end
	if fuera then
		shift, alterna = false, false
	end

	-- Cómo te mueves: la velocidad plana de la raíz y, al empezar a empujar (Config.Correr.Gracia s), como poco lo que
	-- empujas, para que empiece al momento (más tarde no: contra una pared no se corre).
	local andar = jugador:GetAttribute("Andar")
	local andarNum = if type(andar) == "number" then andar elseif hum then hum.WalkSpeed else 16
	local velocidad, delante = 0, 0
	local raiz = hum and hum.RootPart
	if hum and raiz then
		local v = raiz.AssemblyLinearVelocity
		local plana = Vector3.new(v.X, 0, v.Z)
		velocidad = plana.Magnitude
		local empuja = hum.MoveDirection
		local dir = plana
		if empuja.Magnitude > 0.1 then
			empujaDesde = empujaDesde or ahora
			if ahora - (empujaDesde :: number) < C.Gracia then
				velocidad = math.max(velocidad, empuja.Magnitude * andarNum)
			end
			dir = Vector3.new(empuja.X, 0, empuja.Z)
		else
			empujaDesde = nil
		end
		local camara = workspace.CurrentCamera
		local mira = if camara then camara.CFrame.LookVector else raiz.CFrame.LookVector
		mira = Vector3.new(mira.X, 0, mira.Z)
		if dir.Magnitude > 0.05 and mira.Magnitude > 0.01 then
			delante = dir.Unit:Dot(mira.Unit)
		end
	end
	local moviendo = velocidad > C.Moverse

	-- Lo alternado se apaga solo al pararte un rato.
	if alterna then
		if moviendo then
			quietoDesde = nil
		elseif not quietoDesde then
			quietoDesde = ahora
		elseif ahora - quietoDesde >= (if haCorrido then PARADO else PARADO_SIN) then
			alterna = false
		end
	else
		haCorrido, quietoDesde = false, nil
	end

	-- Lo que quieres: al servidor solo al cambiar; en la predicción, con las mismas reglas. Por la mirilla, las cortinas
	-- o en una cinemática no se pide (eso solo lo sabe tu cliente: el servidor te haría correr y gastar aguante si te
	-- mueves); al salir, con Shift aún apretado o lo alternado puesto, se vuelve a pedir.
	local quiere = (shift or alterna) and not d.vistazo and not d.cine
	if quiere ~= mandado then
		mandado = quiere
		Remotes.Correr:FireServer(quiere)
	end
	local _, pedido = CorrerReglas.pedir(estado, quiere, ahora)
	local antes = pedido
	local nuevo, aviso = CorrerReglas.paso(pedido, dt, ahora, velocidad, delante, d)
	estado = nuevo -- (una copia nueva: se puede retocar)

	-- Con el servidor: el aguante se le acerca si se separa (más lo que cambia mientras llega su número)...
	local ping = jugador:GetNetworkPing()
	local servidor = jugador:GetAttribute("Aguante")
	if type(servidor) == "number" and dt > 0 and ahora - reaparecioEn > REAPARECE + ping then
		local cambia = math.abs(estado.aguante - antes.aguante) / dt
		local margen = TOLERANCIA + cambia * (ping + C.Publicar)
		local dif = servidor - estado.aguante
		if math.abs(dif) > margen then
			local paso = (math.abs(dif) - margen) * math.min(1, dt * ACERCA)
			estado.aguante = math.clamp(estado.aguante + math.sign(dif) * paso, 0, 1)
		end
	end
	-- ...y agotado lo dice él: si se agota allí y aquí no, agotado; si aquí sí y él no lo confirma al rato, no lo estás.
	local agotadoServidor = jugador:GetAttribute("Agotado") == true
	if agotadoServidor and not servidorAgotado and not estado.agotado then
		estado.agotado, estado.corriendo = true, false
		estado.frena = math.max(estado.frena, C.Frena)
		aviso = "Agota"
	elseif estado.agotado and not agotadoServidor and aviso == nil
		and ahora - agotoEn > GRACIA_AGOTADO + ping then
		estado.agotado = false
	end
	servidorAgotado = agotadoServidor
	if aviso == "Agota" then
		alAgotarse(ahora)
	elseif not estado.agotado and not agotadoServidor then
		avisado = false -- descansado aquí y allí: el próximo agotamiento se avisa
	end

	-- Correr de verdad: predicho y (confirmado o recién empezado).
	if estado.corriendo and not antes.corriendo then
		empezo = ahora
	end
	corres = estado.corriendo and (jugador:GetAttribute("Corriendo") == true or ahora - empezo < C.Gracia)
	if estado.corriendo then
		ultimaCarrera = ahora
		haCorrido = haCorrido or alterna
	end
	if corres then
		ritmoVisto = math.min(1, ritmoVisto + dt * SUBE)
	else
		ritmoVisto = math.max(0, ritmoVisto - dt * BAJA)
	end

	-- La velocidad local (para que vaya al momento; el servidor manda).
	if hum and d.vivo and type(andar) == "number" then
		local meta = CorrerReglas.velocidad(andar, corres)
		if math.abs(hum.WalkSpeed - meta) > 0.001 then
			hum.WalkSpeed = meta
		end
	end

	-- Resoplidos tras agotarte, cada vez más flojos y espaciados. Debajo de un mueble (Cubierto) respira MuerteVista.
	if resoplando then
		if fuera or jugador:GetAttribute("Cubierto") == true or CorrerReglas.cansancio(estado) <= RESOPLA then
			resoplando = false
		elseif ahora >= proximoResoplido then
			local t = estado.aguante / RESOPLA_HASTA
			CorrerVista.jadear(nil, mezcla(RESOPLA_FUERZA, t))
			proximoResoplido = ahora + mezcla(RESOPLA_CADA, t)
		end
	end

	-- La barra.
	pintarBoton(CorrerReglas.puede(d) and not estado.agotado)
	if barra then
		vista = CorrerBarra.cuadro(vista, {
			aguante = estado.aguante,
			corriendo = corres,
			agotado = estado.agotado,
			oculto = fuera or d.vistazo == true or d.cine == true,
			poco = C.Poco,
		}, dt)
		CorrerBarra.mover(barra, vista)
	end
end

-- Al reaparecer: descansado y sin pedir nada (el servidor hace lo mismo).
local function conPersonaje()
	estado = CorrerReglas.reaparecer(estado)
	reposo()
	empezo, ultimaCarrera, agotoEn, avisado = -math.huge, -math.huge, -math.huge, false
	reaparecioEn = os.clock() -- el Aguante del servidor de antes de morir puede llegar aún: que no tire de la barra
	vista = CorrerBarra.reposo()
end

-- Los demás: al agotarse, un jadeo en su cabeza si están cerca.
local function vigilar(otro: Player)
	if otro == jugador then
		return
	end
	otro:GetAttributeChangedSignal("Agotado"):Connect(function()
		if otro:GetAttribute("Agotado") ~= true then
			return
		end
		local personaje = otro.Character
		local cabeza = personaje and personaje:FindFirstChild("Head")
		local camara = workspace.CurrentCamera
		if cabeza and cabeza:IsA("BasePart") and camara
			and (cabeza.Position - camara.CFrame.Position).Magnitude <= OIDO_OTROS then
			CorrerVista.jadear(cabeza, JADEO_OTRO)
		end
	end)
end

function CorrerVista.start()
	-- Móvil: botón CORRER en la rejilla del equipo (EquipoVista: el tamaño lo pone ella; orden 7, tras AGACHARSE).
	if Ui.tactil() then
		local fila = Ui.hud():FindFirstChild("EquipoBotones")
		if fila then
			local b = Ui.boton(Lang.t(nil, "Run"), { LayoutOrder = 7, Name = "Correr" })
			Ui.queQuepa(b, 22)
			b.Activated:Connect(function()
				if fuera then
					return
				end
				alterna = not alterna
				if alterna then
					pedirCorrer()
				end
			end)
			b.Parent = fila
			boton = b
		end
	end
	UserInputService.InputBegan:Connect(function(entrada, procesado)
		if procesado or fuera then
			return
		end
		if entrada.KeyCode == Enum.KeyCode.LeftShift then
			shift = true
			pedirCorrer()
		elseif entrada.KeyCode == Enum.KeyCode.ButtonL3 then
			alterna = not alterna
			if alterna then
				pedirCorrer()
			end
		end
	end)
	-- Al soltar, aunque estuvieras escribiendo: que no se quede corriendo.
	UserInputService.InputEnded:Connect(function(entrada)
		if entrada.KeyCode == Enum.KeyCode.LeftShift then
			shift = false
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		shift = false
	end)
	-- Tus tropiezos: el servidor sube el atributo Tropiezo.
	local t = jugador:GetAttribute("Tropiezo")
	tropiezos = if type(t) == "number" then t else 0
	jugador:GetAttributeChangedSignal("Tropiezo"):Connect(function()
		local nuevo = jugador:GetAttribute("Tropiezo")
		local n = if type(nuevo) == "number" then nuevo else 0
		if n > tropiezos and not fuera then
			tropiezoEn = os.clock()
		end
		tropiezos = n
	end)
	for _, otro in Players:GetPlayers() do
		vigilar(otro)
	end
	Players.PlayerAdded:Connect(vigilar)
	jugador.CharacterAdded:Connect(conPersonaje)
	barra = CorrerBarra.nueva()
	RunService.Heartbeat:Connect(cada)
end

return CorrerVista
