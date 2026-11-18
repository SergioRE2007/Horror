-- Banco del pavor al ver un bicho (pedido por el usuario: "mejorar la inmersión"; docs/sistemas/pavor.md). Ejecutar
-- desde la raíz: lune run tests/bancos/pavor.luau (lo corre regressions.luau).
--   1. Las cuentas (PavorCuentas): fuerza por distancia, curva del vértigo, cómo baja el pavor, el latido, el temblor
--      de las manos y el retraso al girar (acotados y sin NaN).
--   2. PavorVista de verdad con el Roblox de mentira (tests/bancos/_roblox.luau) y CuerpoVista, Manos, ManosGestos y
--      Sonido falsos que apuntan lo que les llega: un bicho detrás, tras una pared, tras un cristal, lejos, el Imitador
--      fingiendo, el mismo otra vez (antes y después de Olvida s), escondido, muerto, en una cinemática, con
--      Rendimiento, y que todo vuelve a 0 al pasar el pavor.
--   3. CuerpoVista de verdad con ponerPavor: el campo de visión baja a ~60 y vuelve a 70 justo, la cámara recula sin
--      meterse en la pared de detrás y al girar rápido la vista se queda atrás un poco (nunca más de Retraso.Max).
--   4. Persecución: un bicho falso con el atributo Persigue (lo pone Caza): en PavorVista, latido entero mientras te
--      persigue aunque no lo veas y apagándose al dejarte, golpe flojo como mucho cada Persigue.Cada s, respiración y
--      manos; nada si persigue a otro, con el Imitador fingiendo, escondido o en una cinemática; con Rendimiento solo
--      latido y golpe. En AmbienteMiedo, la tensión entera en ~1 s.
local crearMundo = require("./_roblox")

local cuentas = 0
local function comprobar(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end
local function cerca(a: number, b: number, margen: number, etiqueta: string)
	comprobar(math.abs(a - b) <= margen, `{etiqueta}: esperado {b}, sale {a}`)
end

-- ===== 1. Las cuentas =====
do
	local m = crearMundo()
	local Config = m.cargar("src/shared/Config")
	local C = Config.Pavor
	local P = m.cargar("src/juego/cliente/PavorCuentas")
	local Vector3 = m.global.Vector3

	-- Fuerza por distancia.
	cerca(P.fuerza(0), 1, 1e-9, "fuerza pegado")
	cerca(P.fuerza(C.Cerca), 1, 1e-9, "fuerza en Cerca")
	cerca(P.fuerza(C.Lejos), C.Minimo, 1e-9, "fuerza en Lejos")
	comprobar(P.fuerza(C.Lejos + 0.1) == 0, "más lejos que Lejos no asusta")
	comprobar(P.fuerza(0 / 0) == 0, "fuerza con NaN")
	local antes = 2
	for d = 0, C.Lejos, 1 do
		local f = P.fuerza(d)
		comprobar(f <= antes + 1e-9 and f >= C.Minimo - 1e-9, `fuerza baja con la distancia ({d})`)
		antes = f
	end

	-- Vértigo.
	local V = C.Vertigo
	cerca(P.vertigo(0), 0, 1e-9, "vértigo al empezar")
	cerca(P.vertigo(V.Cierra), 1, 1e-9, "vértigo cerrado")
	cerca(P.vertigo(V.Cierra + V.Queda * 0.5), 1, 1e-9, "vértigo se queda")
	cerca(P.vertigo(P.finVertigo()), 0, 1e-9, "vértigo acaba")
	comprobar(P.vertigo(-1) == 0 and P.vertigo(0 / 0) == 0, "vértigo fuera de tiempo")
	comprobar(P.vertigo(V.Cierra * 0.5) > 0.3 and P.vertigo(V.Cierra * 0.5) < 0.7, "vértigo a medio cerrar")
	local prev = 1
	for t = V.Cierra + V.Queda, P.finVertigo(), 0.05 do
		local v = P.vertigo(t)
		comprobar(v <= prev + 1e-9, "el vértigo vuelve sin saltos hacia arriba")
		comprobar(prev - v < 0.06, `el vértigo vuelve despacio ({prev - v} en 0,05 s)`)
		prev = v
	end

	-- El pavor: dura 20-30 s y baja poco a poco.
	cerca(P.dura(C.Minimo), C.Dura[1], 1e-9, "dura lejos")
	cerca(P.dura(1), C.Dura[2], 1e-9, "dura cerca")
	cerca(P.queda(0, 0.8, 25), 0.8, 1e-9, "pavor al empezar")
	comprobar(P.queda(25, 0.8, 25) == 0 and P.queda(30, 0.8, 25) == 0, "pavor acaba")
	comprobar(P.queda(0 / 0, 1, 25) == 0, "pavor con NaN")
	prev = 2
	for t = 0, 25, 0.5 do
		local q = P.queda(t, 1, 25)
		comprobar(q <= prev + 1e-9 and q >= 0, "el pavor baja")
		prev = q
	end
	comprobar(P.queda(10, 1, 25) > 0.3, "a los 10 s queda bastante pavor")
	cerca(P.sumar(0.7, 0.5), 0.7, 1e-9, "un susto flojo no baja el pavor")
	cerca(P.sumar(0.2, 0.9), 0.9, 1e-9, "un susto fuerte lo sube")

	-- El latido: entero unos segundos y se apaga.
	cerca(P.latido(0, 1), 1, 1e-9, "latido al empezar")
	cerca(P.latido(C.Latido.Dura[2] - 0.1, 1), 1, 1e-9, "latido entero de cerca")
	comprobar(P.latido(C.Latido.Dura[1] + C.Latido.Apaga * 0.5, C.Minimo) < 1, "de lejos se apaga antes")
	cerca(P.latido(P.finLatido(1), 1), 0, 1e-9, "latido acaba")
	comprobar(P.finLatido(1) > P.finLatido(C.Minimo), "de cerca, latido más largo")
	-- Tras una persecución: entera hasta que te deja y se apaga en Latido.Apaga s.
	cerca(P.trasPersecucion(-1), 1, 1e-9, "persecución: entera mientras dura")
	cerca(P.trasPersecucion(0), 1, 1e-9, "persecución: entera al dejarte")
	local mitad = P.trasPersecucion(C.Latido.Apaga * 0.5)
	comprobar(mitad > 0.2 and mitad < 0.8, "persecución: a medio apagar")
	cerca(P.trasPersecucion(C.Latido.Apaga), 0, 1e-9, "persecución: apagada")
	comprobar(P.trasPersecucion(math.huge) == 0 and P.trasPersecucion(0 / 0) == 0, "persecución: fuera de tiempo")

	-- El temblor de las manos: nada sin pavor, acotado, se mueve con el tiempo y más con más pavor.
	local g0, d0 = P.temblor(1.23, 0, 1.7)
	comprobar(g0 == Vector3.zero and d0 == Vector3.zero, "sin pavor no tiembla")
	local maxGiro, maxMueve, cambia = 0, 0, 0
	local suma1, sumaFlojo = 0, 0
	local antesG = nil
	for i = 0, 600 do
		local t = i / 60
		local g, d = P.temblor(t, 1, 1.7)
		local gf = P.temblor(t, 0.3, 1.7)
		maxGiro = math.max(maxGiro, math.abs(g.X), math.abs(g.Y), math.abs(g.Z))
		maxMueve = math.max(maxMueve, d.Magnitude)
		suma1 += g.Magnitude
		sumaFlojo += gf.Magnitude
		if antesG then
			cambia += (g - antesG).Magnitude
		end
		antesG = g
	end
	comprobar(maxGiro > math.rad(0.4), `con pavor se nota el temblor ({math.deg(maxGiro)}°)`)
	comprobar(maxGiro < math.rad(3), `el temblor no se pasa ({math.deg(maxGiro)}°)`)
	comprobar(maxMueve < 0.05, "la mano casi no se desplaza")
	comprobar(cambia > 0.05, "el temblor se mueve")
	comprobar(sumaFlojo < suma1 * 0.5, "con poco pavor tiembla menos")
	local gN = P.temblor(0 / 0, 1, 1)
	comprobar(gN == Vector3.zero, "temblor con NaN")

	-- El retraso al girar.
	local R = C.Retraso
	local dt = 1 / 60
	local c, g = 0, 0
	for _ = 1, 60 do -- girar despacio (1 rad/s) no se nota
		c, g = P.retraso(-1 * dt, 0, dt, c, g, 1)
	end
	comprobar(c == 0 and g == 0, "girando despacio la vista no se queda atrás")
	for _ = 1, 60 do -- a la derecha deprisa (8 rad/s): se queda a la izquierda
		c, g = P.retraso(-8 * dt, 0, dt, c, g, 1)
	end
	comprobar(g > math.rad(0.8) and g <= R.Max + 1e-9, `girando a la derecha deprisa se queda atrás ({math.deg(g)}°)`)
	for _ = 1, 60 do -- muy deprisa: nunca más de Max
		c, g = P.retraso(-80 * dt, 40 * dt, dt, c, g, 1)
		comprobar(math.abs(g) <= R.Max + 1e-9 and math.abs(c) <= R.Max + 1e-9, "el retraso nunca pasa de Max")
	end
	comprobar(c > 0, "bajando la vista deprisa, se queda arriba")
	for _ = 1, 120 do -- al parar vuelve
		c, g = P.retraso(0, 0, dt, c, g, 1)
	end
	comprobar(c == 0 and g == 0, "al parar de girar, vuelve")
	c, g = 0, 0
	for _ = 1, 60 do
		c, g = P.retraso(-8 * dt, 0, dt, c, g, 0)
	end
	comprobar(c == 0 and g == 0, "sin pavor, sin retraso")
	c, g = P.retraso(0 / 0, 0, dt, 0, 0, 1)
	comprobar(c == 0 and g == 0, "retraso con NaN")
	c, g = P.retraso(-1, 0, 0, 0, 0, 1)
	comprobar(c == 0 and g == 0, "retraso con dt 0")
end

-- ===== 2. PavorVista =====
do
	local m = crearMundo()
	local g = m.global
	local Vector3, CFrame, Enum = g.Vector3, g.CFrame, g.Enum
	local Config = m.cargar("src/shared/Config")
	local C = Config.Pavor
	local jugador = m.jugadorLocal
	local camara = m.camara

	m.caja(CFrame.new(0, -0.5, 0), Vector3.new(400, 1, 400), { Name = "Suelo" })
	local pj = m.personaje(CFrame.new(0, 3, 0))
	local hum = pj:FindFirstChildOfClass("Humanoid")
	m.mirar(0, 0) -- hacia -Z

	-- Lo que llega a los falsos.
	local cuerpo = { campo = 0, recula = 0, susto = 0, retraso = 0, campoMax = 0 }
	local manos = { pavor = 0, max = 0 }
	local sobresaltos, respingos = 0, 0
	local latidos: { any } = {}
	local CuerpoFalso = {
		ponerPavor = function(campo: number, recula: number, susto: number, retraso: number)
			cuerpo.campo, cuerpo.recula, cuerpo.susto, cuerpo.retraso = campo, recula, susto, retraso
			cuerpo.campoMax = math.max(cuerpo.campoMax, campo)
		end,
	}
	local ManosFalso = {
		pavor = function(x: number)
			manos.pavor = x
			manos.max = math.max(manos.max, x)
		end,
	}
	local GestosFalso = {
		sobresalto = function()
			respingos += 1
		end,
	}
	local SonidoFalso = {
		tocar = function(nombre: string)
			local s = g.Instance.new("Sound")
			s.Volume = 1.2
			if nombre == "Sobresalto" then
				sobresaltos += 1
			end
			return s
		end,
		bucle = function(nombre: string)
			local s = g.Instance.new("Sound")
			s.Name = nombre
			s.Volume = 0.8
			s.Parent = g.game:GetService("SoundService")
			table.insert(latidos, s)
			return s
		end,
		hay = function()
			return true
		end,
	}
	local Pavor = m.cargar("src/juego/cliente/PavorVista", {
		CuerpoVista = CuerpoFalso,
		Manos = ManosFalso,
		ManosGestos = GestosFalso,
		Sonido = SonidoFalso,
	})
	Pavor.start()

	local carpeta = g.Instance.new("Folder")
	carpeta.Name = "Bichos"
	carpeta.Parent = g.workspace
	local function bicho(nombre: string, pos: any): any
		local b = g.Instance.new("Model")
		b.Name = nombre
		local raiz = m.caja(CFrame.new(pos), Vector3.new(2, 5, 1), { CanCollide = false })
		raiz.Name = "HumanoidRootPart"
		raiz.Parent = b
		local cabeza = m.caja(CFrame.new(pos + Vector3.new(0, 3, 0)), Vector3.new(1.5, 1.5, 1.5), { CanCollide = false })
		cabeza.Name = "Cabeza"
		cabeza.Parent = b
		local h = g.Instance.new("Humanoid")
		h.Parent = b
		b.Parent = carpeta
		return b
	end
	local function sonando(): number
		local n = 0
		for _, s in latidos do
			if s.Parent ~= nil then
				n += 1
			end
		end
		return n
	end
	local function limpiar()
		for _, b in carpeta:GetChildren() do
			b:Destroy()
		end
		m.correr(40) -- que pase todo el pavor y se olviden
		cuerpo.campoMax, manos.max = 0, 0
		sobresaltos, respingos = 0, 0
	end
	m.correr(0.5)
	local ojo = camara.CFrame.Position

	-- Nada sin bichos.
	m.correr(1)
	comprobar(cuerpo.campo == 0 and manos.pavor == 0 and sonando() == 0, "sin bichos, nada")

	-- Detrás de ti: no cuenta.
	local b = bicho("Golpeador", ojo + Vector3.new(0, -3, 20))
	m.correr(1)
	comprobar(sobresaltos == 0 and cuerpo.campoMax == 0, "un bicho detrás no asusta")
	b:Destroy()

	-- Delante tras una pared: no cuenta.
	local pared = m.caja(CFrame.new(ojo + Vector3.new(0, 0, -10)), Vector3.new(30, 20, 1), { Name = "Pared" })
	b = bicho("Golpeador", ojo + Vector3.new(0, -3, -20))
	m.correr(1)
	comprobar(sobresaltos == 0 and cuerpo.campoMax == 0, "tras una pared no asusta")
	-- La pared se vuelve cristal: sí se ve.
	pared.Transparency = 0.6
	m.correr(0.3)
	comprobar(sobresaltos == 1 and respingos == 1, "a través de un cristal asusta (golpe y respingo)")
	comprobar(sonando() == 1, "suena el latido")
	pared:Destroy()
	-- El vértigo se cierra en 0,5 s y luego vuelve.
	m.correr(0.4)
	local f20 = (1 - (20 - C.Cerca) / (C.Lejos - C.Cerca)) * (1 - C.Minimo) + C.Minimo
	cerca(cuerpo.campoMax, C.Vertigo.Campo * f20, 0.6, "vértigo de 20 studs")
	comprobar(cuerpo.recula > 0 and cuerpo.recula <= C.Vertigo.Recula + 1e-6, "recula un palmo")
	comprobar(manos.pavor > 0.4 and cuerpo.susto > 0 and cuerpo.retraso > 0, "pavor: manos, respiración y retraso")
	-- Mientras se sigue viendo, nada nuevo.
	m.correr(5)
	comprobar(sobresaltos == 1, "viéndolo, no repite")
	comprobar(cuerpo.campo < 0.01 and cuerpo.recula < 0.01, "el vértigo ha vuelto")
	comprobar(manos.pavor > 0.3, "queda pavor")
	-- Miras a otro lado 5 s y vuelves: no repite.
	m.mirar(math.pi, 0)
	m.correr(5)
	m.mirar(0, 0)
	m.correr(1)
	comprobar(sobresaltos == 1, "perdido de vista 5 s, no repite")
	-- 16 s sin verlo: vuelve a asustar.
	m.mirar(math.pi, 0)
	m.correr(C.Olvida + 1)
	m.mirar(0, 0)
	m.correr(0.5)
	comprobar(sobresaltos == 2, "perdido de vista 16 s, vuelve a asustar")
	-- El latido se apaga solo y el pavor pasa del todo (con el bicho fuera de la vista).
	m.mirar(math.pi, 0)
	m.correr(10)
	comprobar(sonando() == 0, "el latido se apaga")
	m.correr(C.Dura[2] + 1)
	comprobar(cuerpo.campo == 0 and cuerpo.susto == 0 and cuerpo.retraso == 0 and manos.pavor == 0,
		"al pasar el pavor, todo a 0")
	limpiar()

	-- Más cerca, más fuerte.
	bicho("Raspador", ojo + Vector3.new(0, -3, -6))
	m.mirar(0, 0)
	m.correr(1)
	cerca(cuerpo.campoMax, C.Vertigo.Campo, 0.3, "pegado, el vértigo entero (70 a 60)")
	local fuerteManos = manos.max
	limpiar()
	bicho("Raspador", ojo + Vector3.new(0, -3, -40))
	m.correr(1)
	comprobar(cuerpo.campoMax > 0 and cuerpo.campoMax < C.Vertigo.Campo * 0.6, "de lejos, vértigo flojo")
	comprobar(manos.max < fuerteManos, "de lejos, tiemblan menos")
	limpiar()

	-- Demasiado lejos: no cuenta.
	bicho("Acechador", ojo + Vector3.new(0, -3, -(C.Lejos + 5)))
	m.correr(1)
	comprobar(sobresaltos == 0 and cuerpo.campoMax == 0, "más lejos que Lejos no asusta")
	limpiar()

	-- El Imitador fingiendo no cuenta; abierto, sí.
	local imitador = bicho("Imitador", ojo + Vector3.new(0, -3, -12))
	m.correr(1)
	comprobar(sobresaltos == 0 and cuerpo.campoMax == 0, "el Imitador fingiendo no asusta")
	imitador:SetAttribute("Abierto", true)
	m.correr(0.5)
	comprobar(sobresaltos == 1, "el Imitador abierto sí")
	limpiar()

	-- Un bicho muerto no cuenta.
	local muerto = bicho("Trepador", ojo + Vector3.new(0, -3, -12))
	muerto:FindFirstChildOfClass("Humanoid").Health = 0
	m.correr(1)
	comprobar(sobresaltos == 0, "un bicho muerto no asusta")
	limpiar()

	-- Escondido: ni lo ve ni deja nada; al esconderse con pavor, todo se quita y el latido se corta.
	jugador:SetAttribute("Escondido", CFrame.new())
	bicho("Golpeador", ojo + Vector3.new(0, -3, -12))
	m.correr(1)
	comprobar(sobresaltos == 0 and cuerpo.campoMax == 0, "escondido no asusta")
	jugador:SetAttribute("Escondido", nil)
	m.correr(0.5)
	comprobar(sobresaltos == 1 and sonando() == 1, "al salir, ya lo ves")
	jugador:SetAttribute("Escondido", CFrame.new())
	m.correr(0.1)
	comprobar(sonando() == 0, "al esconderte, el latido se corta (manda MuerteVista)")
	comprobar(cuerpo.campo == 0 and cuerpo.susto == 0 and manos.pavor == 0, "escondido, nada puesto")
	jugador:SetAttribute("Escondido", nil)
	m.correr(0.5)
	comprobar(manos.pavor > 0 and sobresaltos == 1, "al salir sigue lo que quede del pavor, sin otro susto")
	limpiar()

	-- Debajo de un mueble (Cubierto), mirando por la mirilla y en una cinemática: tampoco.
	for _, caso in { "Cubierto", "Vistazo", "Cinematica", "Muerto" } do
		if caso == "Cinematica" then
			camara.CameraType = Enum.CameraType.Scriptable
		elseif caso == "Vistazo" then
			jugador:SetAttribute("Vistazo", "Mirilla")
		else
			jugador:SetAttribute(caso, true)
		end
		bicho("Golpeador", ojo + Vector3.new(0, -3, -12))
		m.correr(1)
		comprobar(sobresaltos == 0 and cuerpo.campoMax == 0 and manos.max == 0, `{caso}: no asusta`)
		camara.CameraType = Enum.CameraType.Custom
		jugador:SetAttribute(caso, nil)
		limpiar()
	end

	-- Con Rendimiento: sin vértigo, sin respiración ni retraso; latido y temblor flojo.
	jugador:SetAttribute("Rendimiento", true)
	bicho("Golpeador", ojo + Vector3.new(0, -3, -8))
	m.correr(1)
	comprobar(sobresaltos == 1 and sonando() == 1, "con Rendimiento, golpe y latido")
	comprobar(cuerpo.campoMax == 0 and cuerpo.susto == 0 and cuerpo.retraso == 0, "con Rendimiento, sin vértigo")
	comprobar(manos.max > 0 and manos.max <= C.Temblor.Rendimiento + 1e-6, "con Rendimiento, temblor flojo")
	jugador:SetAttribute("Rendimiento", nil)
	limpiar()

	-- Muerto el personaje (sin el atributo): nada.
	hum.Health = 0
	bicho("Golpeador", ojo + Vector3.new(0, -3, -12))
	m.correr(1)
	comprobar(sobresaltos == 0, "con el personaje muerto, nada")
end

-- ===== 3. CuerpoVista con el pavor =====
do
	local m = crearMundo()
	local g = m.global
	local Vector3, CFrame, Enum = g.Vector3, g.CFrame, g.Enum
	local RunService = m.servicio("RunService")
	local Config = m.cargar("src/shared/Config")
	local C = Config.Pavor
	local camara = m.camara
	local X = 200 -- lejos de la casa
	m.caja(CFrame.new(X, -0.5, 0), Vector3.new(200, 1, 200), { Name = "Suelo" })
	local pj = m.personaje(CFrame.new(X, 3, 0))
	local raiz, hum = pj.HumanoidRootPart, pj.Humanoid
	local nada = function()
		return nil
	end
	local CorrerFalso = {
		corriendo = function()
			return false
		end,
		ritmo = function()
			return 0
		end,
		aguante = function()
			return 1
		end,
		agotado = function()
			return false
		end,
		cansancio = function()
			return 0
		end,
		tropiezo = nada,
		recien = function()
			return math.huge
		end,
		jadear = function() end,
		alAgotarse = function()
			return { Disconnect = function() end }
		end,
	}
	local PosturaFalsa = {
		agachado = function()
			return false
		end,
		asomado = function()
			return 0
		end,
		bajo = function()
			return false
		end,
		cuerpo = function()
			return 0
		end,
		tope = function()
			return 0
		end,
		techoDebajo = nada,
		levantarse = function()
			return true
		end,
	}
	local SonidoFalso = {
		en = function()
			return g.Instance.new("Sound")
		end,
		tocar = function()
			return g.Instance.new("Sound")
		end,
	}
	local Cuerpo = m.cargar("src/juego/cliente/CuerpoVista", {
		CorrerVista = CorrerFalso,
		PosturaVista = PosturaFalsa,
		Sonido = SonidoFalso,
	})
	Cuerpo.start()
	local mirada = { giro = 0, arriba = 0 }
	local medida = { fov = 70, desvio = 0, atras = 0, giro = 0, roto = false }
	RunService:BindToRenderStep("Sonda", Enum.RenderPriority.Camera.Value + 2, function()
		local cf = camara.CFrame
		medida.roto = medida.roto or m.roto(cf) or m.roto(camara.FieldOfView)
		medida.fov = camara.FieldOfView
		local base = CFrame.new(raiz.Position + Vector3.new(0, 1.5, 0) + raiz.CFrame:VectorToWorldSpace(hum.CameraOffset))
			* CFrame.fromOrientation(mirada.arriba, mirada.giro, 0)
		local rel = base:ToObjectSpace(cf)
		medida.desvio = rel.Position.Magnitude
		medida.atras = rel.Position.Z -- + hacia atrás
		local enBase = base:VectorToObjectSpace(cf.LookVector)
		medida.giro = math.atan2(-enBase.X, -enBase.Z) -- + a la izquierda de donde mira Roblox
	end)
	local function colocar(giro: number)
		mirada.giro, mirada.arriba = giro, 0
		m.mirar(giro, 0)
		pj:PivotTo(CFrame.new(X, 3, 0) * CFrame.Angles(0, giro, 0))
		m.correr(2)
	end
	colocar(0)
	cerca(medida.fov, 70, 1e-6, "sin pavor, campo 70")

	-- El vértigo entero: 60 y un palmo atrás.
	Cuerpo.ponerPavor(C.Vertigo.Campo, C.Vertigo.Recula, 0, 0)
	m.correr(0.2)
	cerca(medida.fov, 70 - C.Vertigo.Campo, 1e-3, "con el vértigo, campo 60")
	cerca(medida.atras, C.Vertigo.Recula, 0.08, "con el vértigo, la cámara recula")
	Cuerpo.ponerPavor(0, 0, 0, 0)
	m.correr(0.2)
	cerca(medida.fov, 70, 1e-6, "al quitarlo, campo 70 justo")
	comprobar(medida.desvio < 0.05, "al quitarlo, sin desvío")

	-- Con una pared justo detrás: no se mete.
	local paredZ = 0.35 -- la cara de la pared, detrás de la cámara (la cámara va en z = 0)
	m.caja(CFrame.new(X, 4, paredZ + 0.5), Vector3.new(20, 8, 1), { Name = "Pared" })
	m.correr(0.5)
	Cuerpo.ponerPavor(C.Vertigo.Campo, C.Vertigo.Recula, 0, 0)
	m.correr(0.3)
	comprobar(camara.CFrame.Position.Z <= paredZ - 0.1, `con la pared detrás no se mete (z = {camara.CFrame.Position.Z})`)
	Cuerpo.ponerPavor(0, 0, 0, 0)
	m.correr(0.3)
	cerca(medida.fov, 70, 1e-6, "tras la pared, campo 70 justo")

	-- Girar deprisa con pavor: la vista se queda atrás, poco; al parar, vuelve.
	Cuerpo.ponerPavor(0, 0, 0.8, 1)
	local maxGiro = 0
	local signoBien = true
	m.correr(1, nil, function()
		mirada.giro -= 8 / 60 -- a la derecha, 8 rad/s
		m.mirar(mirada.giro, 0)
		maxGiro = math.max(maxGiro, math.abs(medida.giro))
		if medida.giro < -1e-4 then
			signoBien = false
		end
	end)
	comprobar(maxGiro > math.rad(0.5), `girando deprisa la vista se queda atrás ({math.deg(maxGiro)}°)`)
	comprobar(maxGiro <= C.Retraso.Max + math.rad(0.3), `el retraso es un pelo ({math.deg(maxGiro)}°)`)
	comprobar(signoBien, "girando a la derecha, la vista se queda a la izquierda")
	m.correr(1)
	comprobar(math.abs(medida.giro) < math.rad(0.05), "al parar de girar, la vista vuelve")
	Cuerpo.ponerPavor(0 / 0, math.huge, -1, 0 / 0) -- basura: que no rompa nada
	m.correr(0.3)
	comprobar(not medida.roto, "sin NaN en la cámara")
	Cuerpo.ponerPavor(0, 0, 0, 0)
	m.correr(1)
	cerca(medida.fov, 70, 1e-6, "al final, campo 70 justo")
	comprobar(not medida.roto, "sin NaN en la cámara (al final)")
end

-- ===== 4. Persecución (atributo Persigue) =====
do
	local m = crearMundo()
	local g = m.global
	local Vector3, CFrame, Enum = g.Vector3, g.CFrame, g.Enum
	local Config = m.cargar("src/shared/Config")
	local C = Config.Pavor
	local P = C.Persigue
	local jugador = m.jugadorLocal
	local camara = m.camara
	local yo = jugador.UserId

	m.caja(CFrame.new(0, -0.5, 0), Vector3.new(400, 1, 400), { Name = "Suelo" })
	m.personaje(CFrame.new(0, 3, 0))
	m.mirar(0, 0) -- hacia -Z

	local cuerpo = { susto = 0, campoMax = 0 }
	local manos = { pavor = 0 }
	local sobresaltos, respingos = 0, 0
	local latidos: { any } = {}
	local Pavor = m.cargar("src/juego/cliente/PavorVista", {
		CuerpoVista = { ponerPavor = function(campo: number, _recula: number, susto: number)
			cuerpo.susto = susto
			cuerpo.campoMax = math.max(cuerpo.campoMax, campo)
		end },
		Manos = { pavor = function(x: number)
			manos.pavor = x
		end },
		ManosGestos = { sobresalto = function()
			respingos += 1
		end },
		Sonido = {
			tocar = function(nombre: string)
				local s = g.Instance.new("Sound")
				s.Volume = 1.2
				if nombre == "Sobresalto" then
					sobresaltos += 1
				end
				return s
			end,
			bucle = function(nombre: string)
				local s = g.Instance.new("Sound")
				s.Name = nombre
				s.Volume = 0.8
				s.Parent = g.game:GetService("SoundService")
				table.insert(latidos, s)
				return s
			end,
			hay = function()
				return true
			end,
		},
	})
	Pavor.start()

	local carpeta = g.Instance.new("Folder")
	carpeta.Name = "Bichos"
	carpeta.Parent = g.workspace
	-- Un bicho detrás de ti (no lo ves: solo cuenta que te persigue).
	local function bicho(nombre: string): any
		local b = g.Instance.new("Model")
		b.Name = nombre
		local raiz = m.caja(CFrame.new(0, 3, 25), Vector3.new(2, 5, 1), { CanCollide = false })
		raiz.Name = "HumanoidRootPart"
		raiz.Parent = b
		g.Instance.new("Humanoid").Parent = b
		b.Parent = carpeta
		return b
	end
	local function latido(): any
		for _, s in latidos do
			if s.Parent ~= nil then
				return s
			end
		end
		return nil
	end
	local lleno = 0.8 * C.Latido.Volumen * P.Latido
	m.correr(0.5)

	-- Te persigue sin que lo veas: golpe, respingo, latido entero, respiración y manos.
	local b = bicho("Golpeador")
	m.correr(1)
	comprobar(sobresaltos == 0 and latido() == nil, "persecución: un bicho que no te persigue, nada")
	b:SetAttribute("Persigue", yo)
	m.correr(0.3)
	comprobar(sobresaltos == 1 and respingos == 1, "persecución: al empezar, golpe y respingo")
	comprobar(latido() ~= nil, "persecución: suena el latido sin verlo")
	cerca(cuerpo.susto, P.Respira, 1e-6, "persecución: respiración más deprisa")
	cerca(manos.pavor, P.Manos, 1e-6, "persecución: las manos tiemblan algo")
	comprobar(cuerpo.campoMax == 0, "persecución: sin verlo, sin vértigo")
	-- Mientras dura (más que lo que dura el latido de verlo), entero y sin más golpes.
	m.correr(C.Latido.Dura[2] + C.Latido.Apaga + 5)
	local l = latido()
	comprobar(l ~= nil and math.abs(l.Volume - lleno) < 1e-6, "persecución: el latido sigue entero mientras dura")
	comprobar(sobresaltos == 1, "persecución: un solo golpe")
	-- Te deja: se apaga en Latido.Apaga s.
	b:SetAttribute("Persigue", nil)
	m.correr(C.Latido.Apaga * 0.5)
	l = latido()
	comprobar(l ~= nil and l.Volume < lleno - 0.05 and l.Volume > 0, "persecución: al dejarte se va apagando")
	m.correr(C.Latido.Apaga * 0.5 + 0.5)
	comprobar(latido() == nil, "persecución: apagado del todo")
	comprobar(cuerpo.susto == 0 and manos.pavor == 0, "persecución: respiración y manos vuelven")
	-- Otra enseguida (menos de Cada s desde el golpe de antes, contando desde que empezó): latido, sin golpe.
	local t0 = sobresaltos
	b:SetAttribute("Persigue", yo)
	m.correr(0.3)
	comprobar(latido() ~= nil, "persecución: otra, latido")
	-- La de antes empezó hace más de Cada s: esta sí da golpe. Ahora una tercera enseguida: sin golpe.
	comprobar(sobresaltos == t0 + 1, "persecución: pasado Cada s, otro golpe")
	b:SetAttribute("Persigue", nil)
	m.correr(1)
	b:SetAttribute("Persigue", yo)
	m.correr(0.3)
	comprobar(sobresaltos == t0 + 1, "persecución: otra antes de Cada s, sin golpe")
	comprobar(latido() ~= nil, "persecución: y el latido, entero")
	b:SetAttribute("Persigue", nil)
	m.correr(C.Latido.Apaga + P.Cada + 1)

	-- Persigue a otro: nada.
	b:SetAttribute("Persigue", yo + 1000)
	m.correr(1)
	comprobar(latido() == nil and sobresaltos == t0 + 1, "persecución: si persigue a otro, nada")
	b:Destroy()

	-- El Imitador fingiendo: nada (Caza tampoco se lo pone; por si acaso).
	local imitador = bicho("Imitador")
	imitador:SetAttribute("Persigue", yo)
	m.correr(1)
	comprobar(latido() == nil and sobresaltos == t0 + 1, "persecución: el Imitador fingiendo, nada")
	imitador:Destroy()
	m.correr(0.5)

	-- Escondido: nada nuestro (el latido es de MuerteVista).
	jugador:SetAttribute("Escondido", CFrame.new())
	b = bicho("Golpeador")
	b:SetAttribute("Persigue", yo)
	m.correr(1)
	comprobar(latido() == nil and sobresaltos == t0 + 1 and cuerpo.susto == 0, "persecución: escondido, nada")
	jugador:SetAttribute("Escondido", nil)
	m.correr(0.3)
	comprobar(latido() ~= nil, "persecución: al salir del escondite, el latido")
	b:SetAttribute("Persigue", nil)
	m.correr(C.Latido.Apaga + P.Cada + 1)

	-- En una cinemática: nada.
	camara.CameraType = Enum.CameraType.Scriptable
	b:SetAttribute("Persigue", yo)
	m.correr(1)
	comprobar(latido() == nil and cuerpo.susto == 0, "persecución: en una cinemática, nada")
	camara.CameraType = Enum.CameraType.Custom
	b:SetAttribute("Persigue", nil)
	m.correr(C.Latido.Apaga + P.Cada + 1)

	-- Con Rendimiento: latido y golpe, sin respingo, respiración ni temblor.
	jugador:SetAttribute("Rendimiento", true)
	local s0, r0 = sobresaltos, respingos
	b:SetAttribute("Persigue", yo)
	m.correr(1)
	comprobar(latido() ~= nil and sobresaltos == s0 + 1, "persecución con Rendimiento: latido y golpe")
	comprobar(respingos == r0 and cuerpo.susto == 0 and manos.pavor == 0, "persecución con Rendimiento: nada más")
	jugador:SetAttribute("Rendimiento", nil)
	b:Destroy()
end

-- ===== 5. La tensión de AmbienteMiedo con un bicho que te persigue =====
do
	local m = crearMundo()
	local g = m.global
	local Vector3, CFrame = g.Vector3, g.CFrame
	local Config = m.cargar("src/shared/Config")
	local A = Config.AmbienteMiedo
	local jugador = m.jugadorLocal
	local X = 300 -- fuera de la casa: solo cuenta la distancia
	m.caja(CFrame.new(X, -0.5, 0), Vector3.new(200, 1, 200), { Name = "Suelo" })
	m.personaje(CFrame.new(X, 3, 0))
	local bucles: { [string]: any } = {}
	local Ambiente = m.cargar("src/juego/cliente/AmbienteMiedo", {
		Sonido = {
			bucle = function(nombre: string)
				local s = g.Instance.new("Sound")
				s.Name = nombre
				s.Volume = 1
				bucles[nombre] = s
				return s
			end,
			en = function() end,
		},
	})
	Ambiente.start()
	local carpeta = g.Instance.new("Folder")
	carpeta.Name = "Bichos"
	carpeta.Parent = g.workspace
	local b = g.Instance.new("Model")
	b.Name = "Golpeador"
	local raiz = m.caja(CFrame.new(X, 3, A.TensionLejos - 5), Vector3.new(2, 5, 1), { CanCollide = false })
	raiz.Name = "HumanoidRootPart"
	raiz.Parent = b
	b.PrimaryPart = raiz
	b.Parent = carpeta
	m.correr(2)
	local lejos = bucles.Tension.Volume
	comprobar(lejos < 0.15, `tensión: un bicho lejos que no te persigue, poca ({lejos})`)
	b:SetAttribute("Persigue", jugador.UserId)
	m.correr(1)
	comprobar(bucles.Tension.Volume > 0.95, `tensión: te persigue, entera en ~1 s ({bucles.Tension.Volume})`)
	b:SetAttribute("Persigue", nil)
	m.correr(2)
	comprobar(bucles.Tension.Volume < 0.95 and bucles.Tension.Volume > lejos, "tensión: al dejarte baja despacio")
end

print(`pavor: {cuentas} comprobaciones bien`)
