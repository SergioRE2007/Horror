-- Banco de correr en el cliente (14.8, pedido por el usuario: "añadir la mecánica de correr, que tengas una stamina
-- abajo del todo, una barra fina así minimalista que aparezca al correr"). Ejecutar desde la raíz:
-- lune run tests/bancos/correr-barra.luau (también lo lanza tests/regressions.luau).
-- Carga con el Roblox de mentira (tests/bancos/_roblox.luau) los módulos de verdad juego/cliente/CorrerVista y
-- CorrerBarra (PosturaVista y Sonido, falsos) y un servidor de mentira que lleva CorrerReglas y publica los atributos
-- del contrato (Corriendo, Aguante, Agotado, Frena, Andar, Tropiezo y el WalkSpeed) con RETRASO s, como si llegaran por
-- la red. Mira fotograma a fotograma:
--   la barra: no se ve en reposo; aparece suave al correr; baja corriendo; pasa a rojo con poco aguante; late agotada;
--   vuelve a llenarse y se va ~1,5 s después; no sale muerto, escondido, por la mirilla ni en una cinemática; nada de
--   NaN en tamaños, posiciones, colores ni transparencias.
--   la velocidad local: 24 al momento y, si el servidor no lo confirma, 16 pasada Config.Correr.Gracia.
--   los controles: Shift (y soltarlo al perder el foco o si lo procesa el chat), L3 y el botón CORRER del móvil, que
--   alternan y se apagan solos al pararte.
-- Si algo no se cumple, termina con error.
local crearMundo = require("./_roblox")

local cuentas = 0
local function comprueba(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end
local function cerca(actual: number, esperado: number, margen: number, etiqueta: string)
	assert(math.abs(actual - esperado) <= margen, `{etiqueta}: esperado {esperado} ± {margen}, recibido {actual}`)
	cuentas += 1
end

local DT = 1 / 60
local RETRASO = 0.1 -- s que tarda en llegar lo del servidor (ida y vuelta, más o menos)

-- Un mundo con el suelo enorme (se corre mucho en línea recta), el personaje, el servidor de mentira y CorrerVista.
local function montar(movil: boolean)
	local m = crearMundo()
	local g = m.global
	local Vector3, CFrame = g.Vector3, g.CFrame
	if movil then
		m.movil()
	end
	m.caja(CFrame.new(0, -0.5, 0), Vector3.new(6000, 1, 6000))
	m.personaje(CFrame.new(0, 3, 2500))
	m.mirar(0, 0) -- hacia -Z, hacia donde se anda

	local Config = m.cargar("src/shared/Config")
	local Reglas = m.cargar("src/shared/CorrerReglas")
	local Ui = m.cargar("src/comun/cliente/Ui")
	local C = Config.Correr
	local RunService = m.servicio("RunService")
	local jugador = m.jugadorLocal

	-- El servidor de mentira (como juego/servidor/Correr, sin Cargar: Andar es 16, o 16 · FactorFrena frenando).
	local srv = { estado = Reglas.nuevo(), mudo = false, tropiezos = 0, visto = {} :: { [string]: any }, publicado = -math.huge }
	local function publicar(nombre: string, valor: any)
		if srv.visto[nombre] == valor then
			return
		end
		srv.visto[nombre] = valor
		g.task.delay(RETRASO, function()
			jugador:SetAttribute(nombre, valor)
		end)
	end
	local velocidadServidor = 16
	local function andarServidor(e)
		local andar = if e.frena > 0 then 16 * C.FactorFrena else 16
		publicar("Andar", andar)
		local v = Reglas.velocidad(andar, e.corriendo and e.frena <= 0)
		if v ~= velocidadServidor then
			velocidadServidor = v
			g.task.delay(RETRASO, function()
				local pj = jugador.Character
				local hum = pj and pj:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.WalkSpeed = v -- lo del servidor llega y manda (hasta que el cliente lo vuelva a poner)
				end
			end)
		end
	end
	m.remoto("Correr").OnServerEvent:Connect(function(_, valor)
		if srv.mudo then
			return
		end
		local _, e = Reglas.pedir(srv.estado, valor, g.os.clock())
		srv.estado = e
	end)
	jugador.CharacterAdded:Connect(function()
		srv.estado = Reglas.reaparecer(srv.estado)
	end)
	RunService.Heartbeat:Connect(function(dt)
		local pj = jugador.Character
		local hum = pj and pj:FindFirstChildOfClass("Humanoid")
		local raiz = pj and pj:FindFirstChild("HumanoidRootPart")
		local velocidad, delante = 0, 0
		if raiz then
			local v = raiz.AssemblyLinearVelocity
			local plana = Vector3.new(v.X, 0, v.Z)
			velocidad = plana.Magnitude
			local mira = raiz.CFrame.LookVector
			mira = Vector3.new(mira.X, 0, mira.Z)
			if velocidad > 0.05 and mira.Magnitude > 0.01 then
				delante = plana.Unit:Dot(mira.Unit)
			end
		end
		local quien = {
			vivo = hum ~= nil and hum.Health > 0,
			escondido = jugador:GetAttribute("Escondido") ~= nil,
			cargando = false,
			mochila = false,
			agachado = false,
			asomado = false,
		}
		local ahora = g.os.clock()
		local e, aviso = Reglas.paso(srv.estado, dt, ahora, velocidad, delante, quien)
		srv.estado = e
		publicar("Corriendo", if e.corriendo then true else nil)
		publicar("Frena", if e.frena > 0 then true else nil)
		publicar("Agotado", if e.agotado then true else nil)
		local aguante = if e.aguante >= 1 then 1 elseif e.aguante <= 0 then 0 else math.round(e.aguante * 100) / 100
		if aguante == 0 or aguante == 1 or ahora - srv.publicado >= C.Publicar then
			if srv.visto.Aguante ~= aguante then
				srv.publicado = ahora
			end
			publicar("Aguante", aguante)
		end
		if aviso == "Agota" then
			srv.tropiezos += 1 -- aquí siempre (en el juego, con probabilidad Config.Correr.Tropiezo)
			publicar("Tropiezo", srv.tropiezos)
		end
		andarServidor(e)
	end)

	-- Los falsos: la postura (de pie) y el sonido (una copia que suena y se apunta).
	local jadeos = {}
	local postura = { agachado = false }
	local Vista = m.cargar("src/juego/cliente/CorrerVista", {
		PosturaVista = {
			agachado = function()
				return postura.agachado
			end,
			asomado = function()
				return 0
			end,
			levantarse = function()
				postura.agachado = false
				return true
			end,
		},
		Sonido = {
			hay = function()
				return false
			end,
			bucle = function(nombre: string, padre: any)
				local s = g.Instance.new("Sound")
				s.Name = nombre
				s.SoundId = "rbxassetid://1"
				s.Volume = Config.Sonidos[nombre].Volumen
				s.Looped = true
				s.Parent = padre or m.servicio("SoundService")
				s:Play()
				table.insert(jadeos, { nombre = nombre, padre = padre, sonido = s, cuando = g.os.clock() })
				return s
			end,
		},
	})
	local hud = Ui.hud()
	if movil then
		local fila = g.Instance.new("Frame") -- la rejilla de EquipoVista (aquí vacía)
		fila.Name = "EquipoBotones"
		fila.Parent = hud
	end
	Vista.start()
	m.paso(DT)
	local marco = hud:FindFirstChild("Aguante")
	assert(marco, "no está la barra Hud.Aguante")
	local fondo = marco:FindFirstChild("Fondo")
	assert(fondo, "no está la raya de fondo Hud.Aguante.Fondo")
	local lleno = fondo:FindFirstChild("Lleno")
	assert(lleno, "no está el relleno de la barra")
	local rojo = Ui.Color.Sangre:Lerp(g.Color3.fromRGB(200, 40, 34), 0.45)

	local b = {
		m = m, g = g, C = C, Ui = Ui, srv = srv, Vista = Vista, jadeos = jadeos, postura = postura, marco = marco,
		fondo = fondo, lleno = lleno, rojo = rojo, jugador = jugador,
	}

	-- Cada fotograma: nada roto en la barra ni en la API.
	function b.revisar()
		for _, v in {
			marco.Size, marco.Position, fondo.Size, lleno.Size, lleno.Position, fondo.BackgroundColor3,
			lleno.BackgroundColor3, fondo.BackgroundTransparency, lleno.BackgroundTransparency, Vista.ritmo(), Vista.aguante(), Vista.cansancio(),
		} do
			assert(not m.roto(v), `NaN o infinito en la barra o la API: {tostring(v)}`)
		end
		assert(fondo.BackgroundTransparency >= 0 and fondo.BackgroundTransparency <= 1, "transparencia del fondo fuera")
		assert(fondo.Size.Y.Scale > 0 and fondo.Size.Y.Scale <= 1 + 1e-6, "la raya se sale de su hueco")
		assert(lleno.BackgroundTransparency >= 0 and lleno.BackgroundTransparency <= 1, "transparencia del relleno fuera")
		assert(lleno.Size.X.Scale >= 0 and lleno.Size.X.Scale <= 1, "ancho del relleno fuera de 0..1")
		local r = Vista.ritmo()
		assert(r >= 0 and r <= 1, "ritmo fuera de 0..1")
		local h = b.humanoide()
		if h then
			assert(not m.roto(h.WalkSpeed), "WalkSpeed roto")
		end
	end
	function b.correr(segundos: number, cada: (() -> ())?)
		m.correr(segundos, DT, function()
			b.revisar()
			if cada then
				cada()
			end
		end)
	end
	-- Fotograma a fotograma hasta que se cumpla `cond` (como mucho `maximo` s); devuelve los s que han hecho falta.
	function b.hasta(cond: () -> boolean, maximo: number, etiqueta: string): number
		local t = 0
		while not cond() do
			assert(t < maximo, `{etiqueta}: no pasa en {maximo} s`)
			m.paso(DT)
			b.revisar()
			t += DT
		end
		return t
	end
	function b.humanoide(): any
		local pj = jugador.Character
		return pj and pj:FindFirstChildOfClass("Humanoid")
	end
	function b.velocidad(): number
		return b.humanoide().WalkSpeed
	end
	-- ¿Se ve la barra? (Visible y el relleno o el fondo algo opacos)
	function b.seVe(): boolean
		return marco.Visible and (lleno.BackgroundTransparency < 0.98 or fondo.BackgroundTransparency < 0.98)
	end
	function b.ultimoMandado(): boolean?
		local l = m.enviados("Correr")
		return if #l > 0 then l[#l][1] else nil
	end
	function b.andar(si: boolean)
		m.andar(if si then Vector3.new(0, 0, -1) else nil)
	end
	-- Parado, sin pedir nada y con el aguante lleno en los dos lados (y la barra ya ida).
	function b.descansar()
		m.soltar(g.Enum.KeyCode.LeftShift)
		b.andar(false)
		b.hasta(function()
			return Vista.aguante() >= 1 and jugador:GetAttribute("Aguante") == 1 and not b.seVe()
				and not Vista.agotado()
		end, 15, "descansar")
	end
	return b
end

-- El ordenador ------------------------------------------------------------------------------------------------------
do
	local b = montar(false)
	local m, g, C, Vista = b.m, b.g, b.C, b.Vista
	local Enum = g.Enum
	local marco, fondo, lleno = b.marco, b.fondo, b.lleno
	-- El alto de la raya en píxeles de diseño (va en Scale dentro de su hueco, Hud.Aguante).
	local function alto(): number
		return fondo.Size.Y.Scale * marco.Size.Y.Offset
	end

	-- En reposo no se ve.
	b.correr(1)
	comprueba(not b.seVe() and not marco.Visible, "reposo: la barra no se ve")
	cerca(b.velocidad(), 16, 1e-6, "reposo: anda a 16")
	comprueba(not Vista.corriendo() and Vista.ritmo() == 0, "reposo: no corre")
	local bordeAbajo = -marco.Position.Y.Offset + (marco.Size.Y.Offset - alto()) / 2
	comprueba(marco.Position.Y.Scale == 1 and math.abs(bordeAbajo - 7) < 1e-4, `PC: la raya abajo del todo, a 7 px ({bordeAbajo})`)
	cerca(marco.Size.X.Scale, 1 / 3, 1e-6, "PC: un tercio del ancho")
	cerca(alto(), 4, 1e-6, "PC: 4 px de alto")
	comprueba(marco.BackgroundTransparency == 1, "el hueco no se ve (solo la raya)")

	-- Shift sin moverse: no corre ni sale la barra.
	m.pulsar(Enum.KeyCode.LeftShift)
	b.correr(0.5)
	comprueba(not Vista.corriendo() and not b.seVe(), "Shift quieto: ni corre ni sale la barra")
	cerca(b.velocidad(), 16, 1e-6, "Shift quieto: 16")
	m.soltar(Enum.KeyCode.LeftShift)
	b.correr(0.3) -- (que el servidor sepa que lo has soltado antes de andar)
	b.andar(true)
	b.correr(1, function()
		comprueba(not b.seVe() and b.velocidad() == 16, `andando sin Shift: ni barra ni 24 ({b.seVe()}, {b.velocidad()}, {Vista.aguante()})`)
	end)
	b.andar(false)
	b.correr(0.3)
	m.pulsar(Enum.KeyCode.LeftShift)
	b.correr(0.2)

	-- Moviéndote: 24 al momento y la barra aparece suave.
	b.andar(true)
	m.paso(DT)
	b.revisar()
	cerca(b.velocidad(), 24, 1e-6, "Shift andando: 24 en el primer fotograma")
	comprueba(Vista.corriendo(), "Shift andando: corriendo() al momento")
	comprueba(marco.Visible and lleno.BackgroundTransparency > 0.8, "la barra aparece suave (no de golpe)")
	local antesT = lleno.BackgroundTransparency
	local confirmado = nil
	local t = 0
	b.correr(0.3, function()
		t += DT
		comprueba(lleno.BackgroundTransparency <= antesT + 1e-6, "la barra no parpadea al aparecer")
		antesT = lleno.BackgroundTransparency
		cerca(b.velocidad(), 24, 1e-6, "corriendo: 24 todo el rato (también al llegar lo del servidor)")
		if not confirmado and b.jugador:GetAttribute("Corriendo") == true then
			confirmado = t
		end
	end)
	cerca(lleno.BackgroundTransparency, 0.12, 0.01, "a los 0,3 s la barra se ve del todo")
	cerca(Vista.ritmo(), 1, 1e-6, "ritmo() llega a 1 en ~0,25 s")
	comprueba(confirmado and confirmado <= RETRASO + 3 * DT, "el servidor confirma Corriendo con su retraso")
	comprueba(Vista.recien() < 0.05, "recien(): corriendo, 0")

	-- Baja mientras corres (y la predicción no se separa del servidor).
	local ancho = lleno.Size.X.Scale
	local separado = 0
	b.correr(2.5, function()
		comprueba(lleno.Size.X.Scale <= ancho + 1e-6, "corriendo, la barra solo baja")
		ancho = lleno.Size.X.Scale
		local s = b.jugador:GetAttribute("Aguante")
		separado = math.max(separado, math.abs(s - Vista.aguante()))
		comprueba(b.velocidad() == 24, "corriendo: 24")
	end)
	cerca(Vista.aguante(), 1 - 2.8 / C.Dura, 0.03, "a los 2,8 s corriendo queda lo que dice Config.Correr.Dura")
	cerca(lleno.Size.X.Scale, Vista.aguante(), 0.02, "el ancho del relleno es el aguante")
	comprueba(separado < 0.06, `la predicción no se separa del servidor (se separó {separado})`)
	cerca(lleno.BackgroundColor3.R, b.Ui.Color.Hueso.R, 0.01, "con aguante, blanco hueso")
	cerca(lleno.BackgroundColor3.B, b.Ui.Color.Hueso.B, 0.01, "con aguante, blanco hueso (azul)")

	-- Con menos de Config.Correr.Poco, rojo oscuro.
	b.hasta(function()
		return Vista.aguante() < C.Poco
	end, 4, "bajar de Poco")
	b.correr(0.3)
	local c = lleno.BackgroundColor3
	cerca(c.R, b.rojo.R, 0.02, "poco aguante: rojo (R)")
	cerca(c.G, b.rojo.G, 0.02, "poco aguante: rojo (G)")
	comprueba(c.R < 0.75 and c.R > 2.5 * c.G, "poco aguante: rojo oscuro, no chillón")
	comprueba(b.seVe(), "poco aguante: se ve")

	-- Agotado: aviso una vez, jadeo fuerte, tropiezo, frena y la barra late.
	local avisos = 0
	Vista.alAgotarse(function()
		avisos += 1
	end)
	local jadeosAntes = #b.jadeos
	b.hasta(function()
		return Vista.agotado()
	end, 2, "agotarse")
	comprueba(avisos == 1, "alAgotarse: una vez")
	comprueba(#b.jadeos == jadeosAntes + 1, "al agotarte, un jadeo")
	local j = b.jadeos[#b.jadeos]
	comprueba(j.nombre == C.Jadeo and j.padre == nil, "el jadeo: el provisional, sin posición (solo para ti)")
	cerca(j.sonido.PlaybackSpeed, C.JadeoTono, 1e-6, "el jadeo fuerte, siempre al mismo tono")
	comprueba(not Vista.corriendo(), "agotado: no corre")
	local altoMin, altoMax, fondoRojo = math.huge, 0, 0
	local tropezo, frenado = false, false
	b.correr(1.5, function()
		altoMin = math.min(altoMin, alto())
		altoMax = math.max(altoMax, alto())
		local f = fondo.BackgroundColor3
		fondoRojo = math.max(fondoRojo, f.R - f.G)
		tropezo = tropezo or Vista.tropiezo() ~= nil
		frenado = frenado or math.abs(b.velocidad() - 16 * C.FactorFrena) < 1e-6
		comprueba(b.velocidad() <= 16 + 1e-6, "agotado con Shift: no corre")
		comprueba(b.seVe(), "agotado: la barra se ve")
		local s = j.sonido
		comprueba(not m.roto(s.Volume) and s.Volume >= 0, "el jadeo: volumen sano")
	end)
	comprueba(altoMax > 4 * 1.3 and altoMin < 4 * 1.1, `agotada late (alto de {altoMin} a {altoMax})`)
	comprueba(fondoRojo > 0.15, "agotada, el fondo vacío se tiñe de rojo al latir")
	comprueba(tropezo, "tropiezo(): el del servidor llega")
	comprueba(frenado, "agotado: frena a 16 · Config.Correr.FactorFrena")
	comprueba(Vista.cansancio() == 1, "agotado: cansancio 1")
	b.correr(1)
	comprueba(Vista.tropiezo() == nil, "tropiezo(): se acaba")
	comprueba(j.sonido.Parent == nil, "el jadeo se borra al acabar")

	-- Se para a descansar: deja de latir, deja de estar roja, resopla y se va ~1,5 s después de llenarse.
	m.soltar(Enum.KeyCode.LeftShift)
	b.andar(false)
	b.hasta(function()
		return not Vista.agotado()
	end, 4, "dejar de estar agotado")
	comprueba(Vista.aguante() >= C.Volver - 0.03, "deja de estar agotado al recuperar Config.Correr.Volver")
	b.correr(0.6)
	cerca(alto(), 4, 1e-6, "descansado ya no late")
	b.hasta(function()
		return Vista.aguante() >= C.Poco + 0.02
	end, 2, "pasar de Poco")
	b.correr(0.5)
	cerca(lleno.BackgroundColor3.R, b.Ui.Color.Hueso.R, 0.01, "pasado Poco, vuelve al blanco hueso")
	comprueba(#b.jadeos >= jadeosAntes + 3, "resoplidos después del jadeo fuerte")
	b.hasta(function()
		return Vista.aguante() >= 1
	end, 8, "llenarse")
	local resoplidos = #b.jadeos
	local seVeHasta = 0
	t = 0
	b.correr(3, function()
		t += DT
		if b.seVe() then
			seVeHasta = t
		end
	end)
	comprueba(#b.jadeos == resoplidos, "descansado no resopla")
	comprueba(seVeHasta > 1.3 and seVeHasta < 2.3, `llena se va ~1,5 s después (se vio {seVeHasta} s)`)
	comprueba(not marco.Visible, "llena e ida: Visible = false")
	comprueba(Vista.recien() > 5, "recien(): cuenta desde la última carrera")

	-- Que no salga: por la mirilla, en una cinemática, escondido y muerto (con la barra a la vista al empezar).
	local function seEsconde(nombre: string, poner: () -> (), quitar: () -> (), enServidor: boolean)
		b.descansar()
		m.pulsar(Enum.KeyCode.LeftShift)
		b.andar(true)
		b.correr(1)
		comprueba(b.seVe(), nombre .. ": antes se ve")
		poner()
		b.correr(0.25)
		comprueba(not b.seVe(), nombre .. ": se va al momento")
		b.correr(1.5, function()
			comprueba(not b.seVe(), nombre .. ": no sale")
			comprueba(not Vista.corriendo(), nombre .. ": no corre")
		end)
		cerca(b.velocidad(), 16, 1e-6, nombre .. ": vuelve a 16")
		if enServidor then
			comprueba(b.jugador:GetAttribute("Corriendo") == nil, nombre .. ": el servidor tampoco te hace correr")
		end
		quitar()
	end
	seEsconde("mirilla", function()
		b.jugador:SetAttribute("Vistazo", "Mirilla")
	end, function()
		b.jugador:SetAttribute("Vistazo", nil)
	end, true)
	-- Al quitar la mirilla con Shift aún apretado y andando, vuelve a correr.
	b.correr(0.3)
	comprueba(Vista.corriendo() and b.velocidad() == 24, "sin mirilla, con Shift: vuelve a correr")
	seEsconde("cinemática", function()
		m.camara.CameraType = Enum.CameraType.Scriptable
	end, function()
		m.camara.CameraType = Enum.CameraType.Custom
	end, true)
	seEsconde("escondido", function()
		b.jugador:SetAttribute("Escondido", "Armario")
	end, function()
		b.jugador:SetAttribute("Escondido", nil)
	end, true)
	b.correr(0.3)
	comprueba(not Vista.corriendo(), "al salir del escondite hay que volver a pulsar Shift")

	-- Muerto: se va y, al reaparecer, descansado y en reposo.
	b.descansar()
	m.pulsar(Enum.KeyCode.LeftShift)
	b.andar(true)
	b.correr(4)
	b.humanoide().Health = 0
	b.correr(0.25)
	comprueba(not b.seVe(), "muerto: la barra se va")
	b.correr(1.5, function()
		comprueba(not b.seVe(), "muerto: no sale")
	end)
	m.soltar(Enum.KeyCode.LeftShift)
	b.andar(false)
	m.personaje(g.CFrame.new(0, 3, 2500))
	b.correr(1.5, function()
		comprueba(not b.seVe(), "al reaparecer: la barra no sale (el Aguante viejo del servidor no tira de ella)")
	end)
	local quedan = `{Vista.aguante()}, {Vista.agotado()}, {Vista.corriendo()}`
	comprueba(Vista.aguante() == 1 and not Vista.agotado() and not Vista.corriendo(), `al reaparecer: descansado ({quedan})`)
	cerca(b.velocidad(), 16, 1e-6, "al reaparecer: 16")

	-- Perder el foco de la ventana suelta Shift; si lo procesa el chat, no cuenta.
	b.descansar()
	m.pulsar(Enum.KeyCode.LeftShift)
	b.andar(true)
	b.correr(0.3)
	comprueba(Vista.corriendo(), "foco: corriendo antes")
	m.servicio("UserInputService").WindowFocusReleased:Fire()
	b.correr(0.3)
	comprueba(not Vista.corriendo() and b.ultimoMandado() == false, "al perder el foco deja de correr")
	cerca(b.velocidad(), 16, 1e-6, "al perder el foco: 16")
	m.soltar(Enum.KeyCode.LeftShift)
	b.descansar()
	local chat = g.Instance.new("InputObject")
	chat.KeyCode = Enum.KeyCode.LeftShift
	chat.UserInputType = Enum.UserInputType.Keyboard
	chat.UserInputState = Enum.UserInputState.Begin
	m.servicio("UserInputService").InputBegan:Fire(chat, true)
	b.andar(true)
	b.correr(0.5)
	comprueba(not Vista.corriendo() and b.velocidad() == 16, "Shift escribiendo en el chat no hace correr")

	-- Si el servidor no lo confirma: 24 al momento y 16 pasada la gracia.
	b.descansar()
	b.srv.mudo = true
	m.pulsar(Enum.KeyCode.LeftShift)
	b.andar(true)
	m.paso(DT)
	cerca(b.velocidad(), 24, 1e-6, "sin confirmar: 24 al momento")
	b.correr(C.Gracia - 0.1)
	cerca(b.velocidad(), 24, 1e-6, "sin confirmar: 24 durante la gracia")
	b.correr(0.15)
	cerca(b.velocidad(), 16, 1e-6, "sin confirmar: 16 pasada Config.Correr.Gracia")
	b.correr(1.5, function()
		comprueba(b.velocidad() == 16 and not Vista.corriendo(), "sin confirmar: sigue a 16")
	end)
	comprueba(Vista.aguante() > 0.8, "sin confirmar: el servidor no gasta y la predicción se le acerca")
	b.srv.mudo = false
	m.soltar(Enum.KeyCode.LeftShift)
	b.descansar()

	-- L3 alterna: espera a que muevas la palanca, se apaga solo al pararte y con otra pulsación.
	local function l3()
		m.pulsar(Enum.KeyCode.ButtonL3)
		m.soltar(Enum.KeyCode.ButtonL3)
	end
	l3()
	b.correr(1.5)
	comprueba(b.ultimoMandado() == true, "L3: puesto, aún quieto (da tiempo a mover la palanca)")
	b.andar(true)
	m.paso(DT)
	cerca(b.velocidad(), 24, 1e-6, "L3: al mover la palanca, 24 al momento")
	b.correr(1)
	comprueba(Vista.corriendo(), "L3: sigue corriendo sin mantener")
	b.andar(false)
	local apagado = nil
	t = 0
	b.correr(1.3, function()
		t += DT
		if apagado == nil and b.ultimoMandado() == false then
			apagado = t
		end
	end)
	comprueba(apagado and apagado > 0.7 and apagado < 1.1, `L3: se apaga solo al pararte ~0,8 s ({apagado})`)
	b.andar(true)
	b.correr(0.5)
	comprueba(not Vista.corriendo() and b.velocidad() == 16, "L3: apagado, al andar ya no corre")
	b.andar(false)
	b.descansar()
	l3()
	b.correr(2.8)
	comprueba(b.ultimoMandado() == false, "L3: sin llegar a correr, se apaga a los ~2,5 s")
	l3()
	b.andar(true)
	b.correr(0.5)
	comprueba(Vista.corriendo(), "L3: otra vez")
	l3()
	b.correr(0.2)
	comprueba(not Vista.corriendo() and b.ultimoMandado() == false, "L3: la segunda pulsación lo apaga")
	b.andar(false)

	-- Los demás: al agotarse uno cerca, su jadeo en 3D.
	local otro = m.jugador("Otro")
	local aqui = m.camara.CFrame.Position
	local pjOtro = m.personaje(g.CFrame.new(aqui.X + 10, 3, aqui.Z), otro)
	local antes = #b.jadeos
	otro:SetAttribute("Agotado", true)
	comprueba(#b.jadeos == antes + 1 and b.jadeos[#b.jadeos].padre == pjOtro.Head, "otro agotado cerca: jadeo en su cabeza")
	otro:SetAttribute("Agotado", nil)
	pjOtro:PivotTo(g.CFrame.new(aqui.X + 100, 3, aqui.Z))
	otro:SetAttribute("Agotado", true)
	comprueba(#b.jadeos == antes + 1, "otro agotado lejos: no se oye")

	comprueba(#m.errores == 0, "PC: sin errores")
end

-- El móvil: el botón CORRER alterna, se pinta encendido y se apaga solo; la barra sobre la zona segura.
do
	local b = montar(true)
	local m, Vista, Ui = b.m, b.Vista, b.Ui
	local boton = Ui.hud().EquipoBotones:FindFirstChild("Correr")
	comprueba(boton and boton:IsA("TextButton"), "móvil: el botón CORRER en EquipoBotones")
	comprueba(boton.Text == "RUN" and boton.LayoutOrder == 7, "móvil: RUN, tras AGACHARSE")
	local bordeAbajo = -b.marco.Position.Y.Offset + (b.marco.Size.Y.Offset - b.fondo.Size.Y.Scale * b.marco.Size.Y.Offset) / 2
	cerca(bordeAbajo, Ui.zonaSegura() + 6, 0.5, "móvil: la raya sobre la zona segura")
	b.correr(0.5)
	comprueba(not b.seVe(), "móvil: en reposo sin barra")
	m.clic(boton)
	b.correr(0.3)
	comprueba(boton.BackgroundColor3 == Ui.Color.Sangre, "móvil: puesto, el botón encendido")
	b.andar(true)
	m.paso(1 / 60)
	cerca(b.velocidad(), 24, 1e-6, "móvil: al andar, 24 al momento")
	b.correr(1.5)
	comprueba(Vista.corriendo() and b.seVe(), "móvil: corriendo con la barra")
	b.andar(false)
	b.correr(1.3)
	comprueba(b.ultimoMandado() == false and not Vista.corriendo(), "móvil: se apaga solo al pararte")
	comprueba(boton.BackgroundColor3 == Ui.Color.Papel, "móvil: apagado, el botón vuelve a su color")
	m.clic(boton)
	b.correr(0.2)
	m.clic(boton)
	b.correr(0.2)
	comprueba(b.ultimoMandado() == false, "móvil: dos toques, apagado")
	-- Agachado: pedir correr te levanta.
	b.postura.agachado = true
	b.correr(0.2)
	comprueba(boton.TextTransparency > 0.5, "móvil: agachado, el botón sale apagado")
	m.clic(boton)
	b.andar(true)
	b.correr(0.3)
	comprueba(not b.postura.agachado and Vista.corriendo(), "móvil: agachado, CORRER te levanta y corres")
	comprueba(boton.TextTransparency == 0, "móvil: de pie, el botón encendido")
	b.andar(false)
	-- Escondido: el botón no hace nada.
	b.descansar()
	b.jugador:SetAttribute("Escondido", "Armario")
	b.correr(0.2)
	m.clic(boton)
	b.correr(0.2)
	comprueba(b.ultimoMandado() == false and boton.TextTransparency > 0.5, "móvil: escondido, el botón no hace nada")
	b.jugador:SetAttribute("Escondido", nil)
	comprueba(#m.errores == 0, "móvil: sin errores")
end

print(`correr-barra: {cuentas} comprobaciones.`)
