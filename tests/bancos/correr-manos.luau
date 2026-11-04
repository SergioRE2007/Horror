-- Banco de tus manos al correr (14.8, pedido por el usuario: "añadir la mecánica de correr…" y "todo animado e
-- inmersivo"). Ejecutar desde la raíz: lune run tests/bancos/correr-manos.luau (también lo lanza
-- tests/regressions.luau).
-- Carga con el Roblox de mentira (tests/bancos/_roblox.luau) los módulos de verdad juego/cliente/Manos, ManosGestos
-- (sus capas: linterna, aire, pared, correr y tropiezo), ManosCorrer y EquipoVista (la luz de tu linterna), con
-- CorrerVista, CuerpoVista, BengalasVista y Sonido falsos. CorrerVista falso lo lleva el banco: corriendo, el ritmo
-- (sube en 0,25 s y baja en 0,4 s, como el de verdad), el cansancio, agotado y el tropiezo.
-- Mira fotograma a fotograma, andando, corriendo, con y sin linterna, tropezando, agotado y con Rendimiento:
--   nada de NaN en los CFrame de brazos, manos, la linterna ni la luz;
--   el braceo va y viene (los puños asoman abajo a ratos, alternando, y vuelven abajo al parar);
--   lo que llevas tiembla y va y viene corriendo, y deja de hacerlo al parar;
--   las manos no se meten en la cámara ni salen disparadas (ni lejos del hombro ni de un salto entre fotogramas);
--   la luz sale de la punta de la linterna (con su temblor) y nunca detrás de una pared;
--   con Rendimiento, ni braceo ni temblor (el tropiezo sí); escondido o en una cinemática, nada.
-- Si algo no se cumple, termina con error.
local crearMundo = require("./_roblox")

local cuentas = 0
local function comprueba(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end

local DT = 1 / 60
local SUBE, BAJA = 0.25, 0.4 -- s que tarda el ritmo de CorrerVista en subir y en bajar (como el de verdad)

-- Un mundo con un suelo enorme, el personaje y los módulos de verdad. `op.rendimiento`: con la opción Rendimiento.
local function montar(op: { rendimiento: boolean? }?)
	local m = crearMundo()
	local g = m.global
	local Vector3, CFrame = g.Vector3, g.CFrame
	m.caja(CFrame.new(0, -0.5, 0), Vector3.new(4000, 1, 4000))
	local pj = m.personaje(CFrame.new(0, 3, 1500))
	m.mirar(0, 0)
	local jugador = m.jugadorLocal
	if op and op.rendimiento then
		jugador:SetAttribute("Rendimiento", true)
	end

	-- CorrerVista falso: lo mueve el banco (cv) y Manos y ManosGestos lo leen.
	local cv = {
		quiere = false, -- corriendo (lo que pediría Shift)
		ritmo = 0,
		cansancio = 0,
		agotado = false,
		tropiezoEn = nil :: number?,
	}
	local alAgotarse = g.Instance.new("BindableEvent")
	local Vista = {
		corriendo = function()
			return cv.quiere
		end,
		ritmo = function()
			return cv.ritmo
		end,
		aguante = function()
			return 1 - cv.cansancio
		end,
		agotado = function()
			return cv.agotado
		end,
		cansancio = function()
			return cv.cansancio
		end,
		tropiezo = function(): number?
			if cv.tropiezoEn then
				local t = m.ahora() - cv.tropiezoEn
				if t < 1.6 then
					return t
				end
			end
			return nil
		end,
		recien = function()
			return math.huge
		end,
		jadear = function() end,
		alAgotarse = function(fn)
			return alAgotarse.Event:Connect(fn)
		end,
	}
	-- Lo que haga falta de Sonido y BengalasVista: nada (un Sound suelto si piden uno).
	local nada = setmetatable({}, {
		__index = function()
			return function()
				return nil
			end
		end,
	})
	local Manos = m.cargar("src/juego/cliente/Manos", {
		CorrerVista = Vista,
		CuerpoVista = {
			zancada = function(ritmo: number)
				return 7 + (6.2 - 7) * math.clamp(ritmo, 0, 1) -- como CuerpoVista
			end,
		},
		Sonido = nada,
		BengalasVista = { enMano = function()
			return false
		end },
	})
	-- Dónde va cada cosa respecto a la palma (para separar el temblor de lo que lleva el muelle).
	local enMano: { [string]: any } = {}
	local cosaOriginal = Manos.cosa
	Manos.cosa = function(nombre, crear, en)
		enMano[nombre] = en
		return cosaOriginal(nombre, crear, en)
	end
	local Gestos = m.cargar("src/juego/cliente/ManosGestos")
	local Equipo = m.cargar("src/juego/cliente/EquipoVista")
	Manos.start()
	Gestos.start()
	Equipo.start()

	local hum = pj:FindFirstChildOfClass("Humanoid")
	-- Tras cada fotograma: el ritmo de CorrerVista (sube y baja suave, como el de verdad) y la velocidad.
	local function seguir(dt: number)
		local quiere = cv.quiere and hum.MoveDirection.Magnitude > 0.1
		cv.ritmo = if quiere then math.min(1, cv.ritmo + dt / SUBE) else math.max(0, cv.ritmo - dt / BAJA)
		hum.WalkSpeed = if quiere then 24 elseif cv.agotado then 16 * 0.6 else 16
	end
	return {
		m = m,
		g = g,
		pj = pj,
		hum = hum,
		cv = cv,
		Manos = Manos,
		enMano = enMano,
		jugador = jugador,
		seguir = seguir,
	}
end




local roblox = require("@lune/roblox")
local VER = require("@lune/process").env.VER ~= nil -- VER=1 lune run ...: escribe lo medido en cada escena
local Vector3, CFrame = roblox.Vector3, roblox.CFrame

-- ===== Lo que se mira en cada fotograma =====

-- Cuánto falta para que el punto `p` toque la caja de la pieza (0 si está dentro).
local function distanciaACaja(parte: any, p: any): number
	local l = parte.CFrame:PointToObjectSpace(p)
	local h = parte.Size / 2
	local x = math.max(math.abs(l.X) - h.X, 0)
	local y = math.max(math.abs(l.Y) - h.Y, 0)
	local z = math.max(math.abs(l.Z) - h.Z, 0)
	return math.sqrt(x * x + y * y + z * z)
end

-- El ángulo (grados) entre dos giros.
local function angulo(a: any, b: any): number
	local _, giro = (a:ToObjectSpace(b)):ToAxisAngle()
	return math.deg(math.abs(giro))
end

local HOMBRO = { der = Vector3.new(0.75, -1.25, 0.2), izq = Vector3.new(-0.75, -1.25, 0.2) } -- como Manos
local ALCANCE = 1.2 + 1.15 -- brazo y antebrazo (Manos)
local CAMPO = math.rad(70) -- campo de visión vertical de la cámara del mundo falso
local CERCA = 0.12 -- ninguna pieza de los brazos más cerca de la cámara que esto (Roblox recorta a 0,1)
local SALTO = 0.6 -- studs por fotograma (a 60 Hz) que como mucho se mueve una palma: más, "sale disparada"

-- Lo que se apunta mientras se mira (cada escena empieza con uno nuevo).
type Notas = {
	cuadros: number,
	vistoDer: number, -- fotogramas con el puño derecho en pantalla
	vistoIzq: number,
	altoDer: number, -- lo más alto y lo más bajo que llega cada palma (Y en la cámara)
	bajoDer: number,
	altoIzq: number,
	bajoIzq: number,
	temblor: number, -- lo más que gira la linterna por el temblor (grados)
	cambiosTemblor: number, -- veces que el temblor cambia de sentido (cabeceo)
	cerca: number, -- lo más cerca de la cámara que llega una pieza de los brazos
	salto: number, -- lo más que se mueve una palma en un fotograma (en la cámara)
	alcance: number, -- lo más lejos del hombro que llega una palma
	alante: number, -- lo más hacia delante que va la linterna (Z en la cámara; más negativo, más delante)
	luz: number, -- lo más lejos que sale la luz de la punta de la linterna
	giroLuz: number, -- y lo más que se tuerce de hacia donde apunta (grados)
}

local function nuevasNotas(): Notas
	return {
		cuadros = 0,
		vistoDer = 0,
		vistoIzq = 0,
		altoDer = -math.huge,
		bajoDer = math.huge,
		altoIzq = -math.huge,
		bajoIzq = math.huge,
		temblor = 0,
		cambiosTemblor = 0,
		cerca = math.huge,
		salto = 0,
		alcance = 0,
		alante = math.huge,
		luz = 0,
		giroLuz = 0,
	}
end

-- ¿Se ve ese punto (en la cámara) en la pantalla de 16:9?
local function enPantalla(p: any): boolean
	if p.Z >= -0.1 then
		return false
	end
	local t = math.tan(CAMPO / 2)
	return math.abs(p.Y / -p.Z) < t and math.abs(p.X / -p.Z) < t * 16 / 9
end

-- La carpeta donde EquipoVista cuelga tu luz (Terrain).
local function terreno(b: any): any
	return b.m.workspace.Terrain
end

-- Mira un fotograma: lo que no puede pasar nunca (assert) y lo que se apunta en `n` para mirarlo luego.
local function mirar(b: any, n: Notas, antes: { [string]: any }, etiqueta: string)
	local m = b.m
	local cam = m.camara
	local cf = cam.CFrame
	n.cuadros += 1
	assert(not m.roto(cf), `{etiqueta}: NaN en la cámara`)
	local modelo = cam:FindFirstChild("Manos")
	if modelo then
		for _, p in modelo:GetDescendants() do
			if p:IsA("BasePart") then
				assert(not m.roto(p.CFrame), `{etiqueta}: NaN en {p.Name}`)
				local d = distanciaACaja(p, cf.Position)
				n.cerca = math.min(n.cerca, d)
				assert((p.Position - cf.Position).Magnitude < 4, `{etiqueta}: {p.Name} lejos de la cámara`)
			end
		end
	end
	for _, lado in { "der", "izq" } do
		local mano = b.Manos.mano(lado)
		if mano then
			assert(not m.roto(mano), `{etiqueta}: NaN en la palma {lado}`)
			local rel = cf:ToObjectSpace(mano)
			local pos = rel.Position
			n.alcance = math.max(n.alcance, (pos - HOMBRO[lado]).Magnitude)
			if antes[lado] then
				n.salto = math.max(n.salto, (pos - antes[lado]).Magnitude)
			end
			antes[lado] = pos
			-- La palma y los nudillos (un poco más allá, hacia los dedos).
			local visto = enPantalla(pos) or enPantalla((rel * CFrame.new(0, 0, -0.2)).Position)
			if lado == "der" then
				n.vistoDer += if visto then 1 else 0
				n.altoDer, n.bajoDer = math.max(n.altoDer, pos.Y), math.min(n.bajoDer, pos.Y)
			else
				n.vistoIzq += if visto then 1 else 0
				n.altoIzq, n.bajoIzq = math.max(n.altoIzq, pos.Y), math.min(n.bajoIzq, pos.Y)
			end
		else
			antes[lado] = nil
		end
	end
	-- La linterna: su temblor (dondeCosa con él contra la palma que lleva el muelle) y la luz.
	local cosa = b.Manos.dondeCosa("Linterna")
	if cosa then
		assert(not m.roto(cosa), `{etiqueta}: NaN en la linterna`)
		local izq = b.Manos.mano("izq")
		if izq then
			local sinTemblor = cf:ToObjectSpace(izq) * b.enMano.Linterna
			local a = angulo(sinTemblor, cosa)
			n.temblor = math.max(n.temblor, a)
			local cabecea = sinTemblor:VectorToObjectSpace(cosa.LookVector).Y
			if antes.cabecea and math.abs(cabecea) > 1e-6 and (cabecea > 0) ~= (antes.cabecea > 0) then
				n.cambiosTemblor += 1
			end
			if math.abs(cabecea) > 1e-6 then
				antes.cabecea = cabecea
			end
			n.alante = math.min(n.alante, sinTemblor.Position.Z)
		end
		local luz = terreno(b):FindFirstChild("Linterna")
		if luz then
			local w = luz.WorldCFrame
			assert(not m.roto(w), `{etiqueta}: NaN en la luz`)
			local punta = cf * cosa * CFrame.new(0, 0, -0.66)
			n.luz = math.max(n.luz, (w.Position - punta.Position).Magnitude)
			n.giroLuz = math.max(n.giroLuz, angulo(w, punta))
		end
	end
end

-- Corre `seg` s mirando cada fotograma; `cada(i)` antes de mirar (para cambiar algo a mitad).
local function escena(b: any, seg: number, etiqueta: string, cada: ((i: number) -> ())?): Notas
	local n = nuevasNotas()
	local antes = {}
	b.m.correr(seg, DT, function(i)
		b.seguir(DT)
		if cada then
			cada(i)
		end
		mirar(b, n, antes, etiqueta)
	end)
	return n
end

local function sinAvisos(b: any, etiqueta: string)
	for _, a in b.m.avisos do
		assert(not string.find(tostring(a), "[Manos]", 1, true), `{etiqueta}: {a}`)
	end
	comprueba(#b.m.errores == 0, `{etiqueta}: errores`)
end

local function informe(n: Notas, etiqueta: string)
	if VER then
		print(etiqueta, n.vistoDer / n.cuadros, n.vistoIzq / n.cuadros, n.altoDer, n.bajoDer, n.altoIzq, n.bajoIzq,
			n.temblor, n.cambiosTemblor, n.cerca, n.salto, n.alcance, n.alante, n.luz, n.giroLuz)
	end
end

-- ===== 1. Sin linterna: andar, correr, parar =====
do
	local b = montar()
	local m = b.m
	m.andar(Vector3.new(0, 0, -1))
	local n = escena(b, 2, "andando")
	informe(n, "andando")
	comprueba(n.vistoDer == 0 and n.vistoIzq == 0, "andando: las manos libres no se ven")

	b.cv.quiere = true
	escena(b, 0.5, "empieza a correr") -- el ritmo sube y el braceo entra
	local muestras = {}
	n = escena(b, 3, "corriendo", function()
		local d, i = b.Manos.mano("der"), b.Manos.mano("izq")
		if d and i then
			local cf = m.camara.CFrame
			table.insert(muestras, { cf:ToObjectSpace(d).Position.Y, cf:ToObjectSpace(i).Position.Y })
		end
	end)
	informe(n, "corriendo")
	comprueba(n.vistoDer / n.cuadros > 0.1 and n.vistoDer / n.cuadros < 0.6, "corriendo: el puño derecho asoma a ratos")
	comprueba(n.vistoIzq / n.cuadros > 0.1 and n.vistoIzq / n.cuadros < 0.6, "corriendo: el puño izquierdo asoma a ratos")
	comprueba(n.altoDer > -0.9 and n.bajoDer < -1.5, "corriendo: el braceo derecho va y viene")
	comprueba(n.altoIzq > -0.9 and n.bajoIzq < -1.5, "corriendo: el braceo izquierdo va y viene")
	-- A destiempo: cuando una sube, la otra baja (correlación negativa).
	local mx, my = 0, 0
	for _, s in muestras do
		mx += s[1]
		my += s[2]
	end
	mx /= #muestras
	my /= #muestras
	local cov, vx, vy = 0, 0, 0
	for _, s in muestras do
		cov += (s[1] - mx) * (s[2] - my)
		vx += (s[1] - mx) ^ 2
		vy += (s[2] - my) ^ 2
	end
	local r = cov / math.sqrt(vx * vy)
	if VER then
		print("correlación del braceo", r)
	end
	comprueba(#muestras > 150 and r < -0.8, "corriendo: las dos manos bracean a destiempo")
	comprueba(n.cerca > CERCA, `corriendo: los brazos se meten en la cámara ({n.cerca})`)
	comprueba(n.salto < SALTO, `corriendo: una palma salta {n.salto} studs en un fotograma`)
	comprueba(n.alcance < ALCANCE + 0.05, `corriendo: una palma más lejos de lo que llega el brazo ({n.alcance})`)

	-- Un salto corriendo: manda la capa del aire (los brazos se abren) y luego vuelve el braceo, sin tirones.
	m.pulsar(b.g.Enum.KeyCode.Space)
	m.soltar(b.g.Enum.KeyCode.Space)
	local enAire = false
	n = escena(b, 1.5, "salto corriendo", function()
		if b.hum.FloorMaterial == b.g.Enum.Material.Air then
			enAire = true
		end
	end)
	informe(n, "salto corriendo")
	comprueba(enAire, "salta")
	comprueba(n.salto < SALTO and n.cerca > CERCA and n.alcance < ALCANCE + 0.05, "salto corriendo: dentro de lo normal")

	-- Al parar, las manos se van abajo enseguida.
	b.cv.quiere = false
	m.andar(nil)
	n = escena(b, 1.2, "para")
	informe(n, "para")
	comprueba(b.Manos.mano("der") == nil and b.Manos.mano("izq") == nil, "al parar, las manos vuelven abajo")
	comprueba(n.salto < SALTO, "al parar: sin saltos")
	sinAvisos(b, "sin linterna")
end

-- ===== 2. Con la linterna: andar, correr (vaivén y temblor), tropezar, parar =====
do
	local b = montar()
	local m = b.m
	b.jugador:SetAttribute("Linterna", true)
	m.andar(Vector3.new(0, 0, -1))
	escena(b, 1, "linterna, sube")
	local n = escena(b, 2, "linterna andando")
	informe(n, "linterna andando")
	comprueba(b.Manos.dondeCosa("Linterna") ~= nil, "la linterna en la mano")
	comprueba(n.temblor < 1e-3, `andando, la linterna no tiembla ({n.temblor}°)`)
	comprueba(n.luz < 0.005 and n.giroLuz < 0.01, "andando, la luz sale de la punta de la linterna")
	comprueba(n.vistoDer == 0, "andando con la linterna, la derecha no se ve")
	local alanteAndando = n.alante

	b.cv.quiere = true
	escena(b, 0.5, "linterna, empieza a correr")
	local lados = {}
	n = escena(b, 3, "linterna corriendo", function()
		local i = b.Manos.mano("izq")
		if i then
			table.insert(lados, m.camara.CFrame:ToObjectSpace(i).Position.X)
		end
	end)
	informe(n, "linterna corriendo")
	comprueba(n.temblor > 0.4 and n.temblor < 3, `corriendo, la linterna tiembla un poco ({n.temblor}°)`)
	comprueba(n.cambiosTemblor >= 10, `corriendo, el temblor va y vuelve ({n.cambiosTemblor})`)
	comprueba(n.luz < 0.005 and n.giroLuz < 0.01, "corriendo, la luz sale de la punta de la linterna (con su temblor)")
	comprueba(n.alante > alanteAndando - 0.01, "corriendo, la linterna no va más hacia delante que andando")
	local minX, maxX = math.huge, -math.huge
	for _, x in lados do
		minX, maxX = math.min(minX, x), math.max(maxX, x)
	end
	if VER then
		print("vaivén de lado", maxX - minX)
	end
	comprueba(maxX - minX > 0.03 and maxX - minX < 0.2, "corriendo, la linterna va de lado con los pasos")
	comprueba(n.vistoDer / n.cuadros > 0.05, "corriendo con la linterna, la derecha sigue braceando")
	comprueba(n.cerca > CERCA and n.salto < SALTO and n.alcance < ALCANCE + 0.05, "corriendo con la linterna: dentro de lo normal")

	-- Tropiezo corriendo: la derecha (libre) se adelanta para frenar; la linterna da un tirón hacia el suelo y vuelve.
	local cf0 = m.camara.CFrame
	local mira0 = cf0:VectorToObjectSpace((cf0 * b.Manos.dondeCosa("Linterna")).LookVector).Y
	b.cv.tropiezoEn = m.ahora()
	local masAbajo, delante = 0, false
	n = escena(b, 0.45, "tropiezo", function()
		local cf = m.camara.CFrame
		local mira = cf:VectorToObjectSpace((cf * b.Manos.dondeCosa("Linterna")).LookVector).Y
		masAbajo = math.max(masAbajo, mira0 - mira)
		local d = b.Manos.mano("der")
		if d and cf:ToObjectSpace(d).Position.Z < -1.1 then
			delante = true
		end
	end)
	informe(n, "tropiezo")
	if VER then
		print("tirón de la linterna", math.deg(math.asin(math.clamp(masAbajo, 0, 1))))
	end
	comprueba(delante, "al tropezar, la mano libre se adelanta para frenar")
	comprueba(masAbajo > math.sin(math.rad(4)), "al tropezar, la linterna da un tirón hacia el suelo")
	comprueba(n.salto < SALTO and n.cerca > CERCA and n.alcance < ALCANCE + 0.05, "tropiezo: dentro de lo normal")
	n = escena(b, 1.3, "tras el tropiezo")
	comprueba(n.salto < SALTO and n.cerca > CERCA, "tras el tropiezo: dentro de lo normal")
	b.cv.tropiezoEn = nil

	-- Al parar, ni vaivén ni temblor.
	b.cv.quiere = false
	m.andar(nil)
	escena(b, 1, "linterna, para")
	n = escena(b, 1, "linterna parado")
	informe(n, "linterna parado")
	comprueba(n.temblor < 1e-3, `parado, la linterna no tiembla ({n.temblor}°)`)
	comprueba(b.Manos.mano("der") == nil, "parado, la derecha vuelve abajo")
	sinAvisos(b, "con linterna")
end

-- ===== 3. Agotado: las manos libres asoman y respiran; lo que llevas tiembla fino =====
do
	local b = montar()
	local m = b.m
	b.jugador:SetAttribute("Linterna", true)
	m.andar(Vector3.new(0, 0, -1))
	b.cv.quiere = true
	escena(b, 2, "agotado, corre")
	-- Se agota: deja de correr, frenado y sin aguante.
	b.cv.quiere = false
	b.cv.agotado = true
	b.cv.cansancio = 1
	escena(b, 0.8, "se agota")
	local n = escena(b, 3, "agotado")
	informe(n, "agotado")
	comprueba(n.vistoDer / n.cuadros > 0.3, "agotado, la mano libre asoma abajo (a ratos, con la respiración)")
	comprueba(n.altoDer - n.bajoDer > 0.04 and n.altoDer - n.bajoDer < 0.2, "agotado, la mano libre sube y baja con la respiración")
	comprueba(n.temblor > 0.1 and n.temblor < 1.5, `agotado, la linterna tiembla fino ({n.temblor}°)`)
	comprueba(n.cambiosTemblor >= 6, "agotado, el temblor va y vuelve")
	comprueba(n.luz < 0.005 and n.giroLuz < 0.01, "agotado, la luz sale de la punta de la linterna")
	comprueba(n.cerca > CERCA and n.salto < SALTO and n.alcance < ALCANCE + 0.05, "agotado: dentro de lo normal")
	-- Recupera el aliento: la mano se va y la linterna deja de temblar.
	b.cv.agotado = false
	b.cv.cansancio = 0
	escena(b, 1.2, "recupera")
	n = escena(b, 1, "descansado")
	comprueba(b.Manos.mano("der") == nil, "descansado, la mano libre se va abajo")
	comprueba(n.temblor < 1e-3, "descansado, la linterna no tiembla")
	sinAvisos(b, "agotado")
end

-- ===== 4. Contra una pared: la luz nunca sale detrás =====
do
	local b = montar()
	local m = b.m
	-- Una pared a 6 studs por delante (su cara, en z = 1494).
	m.caja(CFrame.new(0, 5, 1493), Vector3.new(20, 10, 2))
	b.jugador:SetAttribute("Linterna", true)
	escena(b, 1, "pared, sube la linterna")
	m.andar(Vector3.new(0, 0, -1))
	b.cv.quiere = true
	local detras, pegado = 0, false
	local n = escena(b, 3, "contra la pared", function()
		local luz = terreno(b):FindFirstChild("Linterna")
		local cf = m.camara.CFrame
		if luz then
			detras = math.max(detras, 1494 - luz.WorldCFrame.Position.Z)
		end
		if cf.Position.Z < 1495.5 then
			pegado = true
		end
	end)
	informe(n, "contra la pared")
	comprueba(pegado, "llega a la pared")
	comprueba(detras <= 0, `la luz sale detrás de la pared ({detras} studs)`)
	comprueba(n.cerca > CERCA and n.salto < SALTO, "contra la pared: dentro de lo normal")
	sinAvisos(b, "pared")
end

-- ===== 5. Rendimiento: ni braceo ni temblor (el tropiezo sí) =====
do
	local b = montar({ rendimiento = true })
	local m = b.m
	m.andar(Vector3.new(0, 0, -1))
	b.cv.quiere = true
	local n = escena(b, 3, "rendimiento corriendo")
	informe(n, "rendimiento corriendo")
	comprueba(n.vistoDer == 0 and n.vistoIzq == 0, "con Rendimiento no se bracea")
	b.jugador:SetAttribute("Linterna", true)
	escena(b, 1, "rendimiento, sube la linterna")
	n = escena(b, 2, "rendimiento con linterna")
	comprueba(b.Manos.dondeCosa("Linterna") ~= nil and n.temblor < 1e-3, "con Rendimiento la linterna no tiembla")
	comprueba(n.vistoDer == 0, "con Rendimiento la derecha no bracea")
	b.cv.tropiezoEn = m.ahora()
	n = escena(b, 0.5, "rendimiento tropieza")
	comprueba(n.vistoDer > 0, "con Rendimiento, al tropezar la mano libre sí se adelanta")
	b.cv.quiere, b.cv.agotado, b.cv.cansancio = false, true, 1
	escena(b, 1.6, "rendimiento se agota")
	n = escena(b, 1, "rendimiento agotado")
	comprueba(n.vistoDer == 0 and n.temblor < 1e-3, "con Rendimiento, agotado ni asoman las manos ni tiembla")
	sinAvisos(b, "rendimiento")
end

-- ===== 6. Escondido o en una cinemática corriendo: nada =====
do
	local b = montar()
	local m = b.m
	b.jugador:SetAttribute("Linterna", true)
	m.andar(Vector3.new(0, 0, -1))
	b.cv.quiere = true
	b.cv.cansancio = 1
	escena(b, 1.5, "antes de esconderse")
	b.jugador:SetAttribute("Escondido", "Armario")
	local n = escena(b, 1, "escondido")
	comprueba(m.camara:FindFirstChild("Manos") == nil, "escondido, las manos no se ven")
	comprueba(b.Manos.dondeCosa("Linterna") == nil and n.temblor == 0, "escondido, ni linterna en la mano ni temblor")
	b.jugador:SetAttribute("Escondido", nil)
	escena(b, 1, "sale")
	m.camara.CameraType = b.g.Enum.CameraType.Scriptable
	n = escena(b, 1, "cinemática")
	comprueba(m.camara:FindFirstChild("Manos") == nil, "en una cinemática, las manos no se ven")
	comprueba(b.Manos.dondeCosa("Linterna") == nil, "en una cinemática, la linterna no está en la mano")
	m.camara.CameraType = b.g.Enum.CameraType.Custom
	n = escena(b, 1, "tras la cinemática")
	comprueba(n.salto < SALTO and n.cerca > CERCA, "al volver de la cinemática: sin saltos")
	sinAvisos(b, "escondido")
end

-- ===== 7. A pocos fotogramas por segundo (un móvil flojo): nada se rompe =====
do
	local b = montar()
	local m = b.m
	b.jugador:SetAttribute("Linterna", true)
	m.andar(Vector3.new(0, 0, -1))
	b.cv.quiere = true
	b.cv.cansancio = 0.7
	local lento = 1 / 15
	local n = nuevasNotas()
	local antes = {}
	m.correr(4, lento, function(i)
		b.seguir(lento)
		if i == 20 then
			b.cv.tropiezoEn = m.ahora()
		end
		mirar(b, n, antes, "a 15 fps")
	end)
	informe(n, "a 15 fps")
	comprueba(n.cerca > CERCA and n.alcance < ALCANCE + 0.05, "a 15 fps: los brazos, dentro de lo normal")
	comprueba(n.salto < SALTO * 4, `a 15 fps: una palma salta {n.salto} studs en un fotograma`)
	comprueba(n.temblor < 3 and n.luz < 0.005 and n.giroLuz < 0.01, "a 15 fps: el temblor y la luz, bien")
	sinAvisos(b, "a 15 fps")
end

print(`correr-manos: {cuentas} comprobaciones bien`)
