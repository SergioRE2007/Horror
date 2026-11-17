-- Tormenta seca: relámpagos que iluminan la casa y recortan a los bichos (docs/sistemas/tormenta.md). Solo en el
-- cliente y solo de adorno; números en Config.Tormenta (a ojo).
--   Algunas noches (desde Config.Tormenta.Desde, una de cada dos) hay tormenta seca: sin lluvia, solo relámpagos cada
--   25-70 s. Cada uno son 2-3 destellos muy cortos que suben de golpe la luz de fuera, ponen el cielo blanco azulado
--   (la niebla) y dan un pico de brillo y contraste (Ambiente.destello). Las luces de luna cercanas (etiqueta Luna,
--   Mapa.luzLuna) se vuelven un fogonazo (Ambiente.lunas) y, sin Rendimiento, una luz con sombras por fuera del cristal
--   recorta en el suelo los marcos, las cortinas y lo que haya fuera: un bicho pegado a la ventana se ve en negro
--   contra el cielo blanco y su sombra entra en la sala. Nadie lo programa: sale solo de la luz.
--   1-5 s después, el trueno (Retumbo muy grave y largo mientras no haya un Trueno propio): lejano y sin posición
--   (tapado desde dentro de la casa) o, si fue cerca, en 3D desde fuera (lo tapan las paredes: OidoVista). Con el
--   trueno vibran los cristales cercanos (CasaVista.elementos) y las bombillas tiemblan (Ambiente.temblor).
--   Lo ven todos a la vez: el horario sale de una semilla con Noche y FaseInicio (atributos del Ciclo) y la hora del
--   servidor. Sin servidor nuevo.
-- Nada en cinemáticas ni en la muerte (cámara Scriptable sin el atributo Vistazo; por la mirilla, sí). Con Rendimiento,
-- un solo destello por relámpago y sin la luz con sombras.
-- Un solo bucle de render, y solo mientras dura un relámpago o su trueno; entre medias, una tarea que duerme hasta el
-- siguiente. Las cuentas (si hay tormenta, el horario, la fuerza del destello) son funciones puras para el banco
-- (tests/bancos/tormenta.luau).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local AireVista = require(script.Parent.AireVista)
local Ambiente = require(script.Parent.Ambiente)
local CasaVista = require(script.Parent.CasaVista)
local Sonido = require(script.Parent.Sonido)

local CFG = Config.Tormenta
local jugador = Players.LocalPlayer
local azar = Random.new() -- solo para lo que no tiene que ser igual en todos (el tono de cada cristal)

local TormentaVista = {}

---------------------------------------------------------------- cuentas (sin Roblox: las usa el banco)

export type Destello = { t: number, subida: number, bajada: number, fuerza: number }
export type Relampago = {
	t: number, -- hora del servidor del primer destello
	cerca: number, -- 0 (lejos) a 1 (encima)
	destellos: { Destello }, -- t de cada uno, en segundos desde el primero
	trueno: number, -- segundos del primer destello al trueno
	tono: number, -- 0 a 1: dónde cae el tono del trueno en su rango
	angulo: number, -- de dónde viene el trueno cercano (radianes, en planta)
}

-- La semilla de una noche: la misma en todos los clientes (Noche y FaseInicio llegan iguales del servidor).
function TormentaVista.semilla(noche: number, inicio: number): number
	return (math.floor(inicio) % 2_147_000) * 1000 + math.floor(noche) % 1000
end

-- ¿Hay tormenta esta noche?
function TormentaVista.hay(noche: number, inicio: number, cfg: any): boolean
	if noche < cfg.Desde then
		return false
	end
	return Random.new(TormentaVista.semilla(noche, inicio)):NextNumber() < cfg.Probabilidad
end

-- Todos los relámpagos de una noche (de `inicio` a `fin`, horas del servidor), en orden. Vacío si no hay tormenta
-- (`forzar`: la hay siempre; solo para probar en Studio).
function TormentaVista.horario(noche: number, inicio: number, fin: number, cfg: any, forzar: boolean?): { Relampago }
	local lista: { Relampago } = {}
	if not forzar and not TormentaVista.hay(noche, inicio, cfg) then
		return lista
	end
	local rng = Random.new(TormentaVista.semilla(noche, inicio) + 7919) -- otra tirada que la de "hay"
	local function entre(par: { number }): number
		return rng:NextNumber(par[1], par[2])
	end
	local hasta = inicio + (fin - inicio) * cfg.HastaNoche
	local t = inicio + entre(cfg.Primero)
	while t < hasta and #lista < 500 do
		local cerca = rng:NextNumber()
		local destellos: { Destello } = {}
		local dt = 0
		for i = 1, rng:NextInteger(cfg.Destellos[1], cfg.Destellos[2]) do
			local dura = entre(cfg.Duracion)
			table.insert(destellos, {
				t = dt,
				subida = cfg.Subida,
				bajada = math.max(0.01, dura - cfg.Subida),
				-- El primero, el más fuerte (con Rendimiento es el único).
				fuerza = (0.55 + 0.45 * cerca) * (if i == 1 then rng:NextNumber(0.9, 1) else rng:NextNumber(0.6, 0.9)),
			})
			dt += dura + entre(cfg.Entre)
		end
		table.insert(lista, {
			t = t,
			cerca = cerca,
			destellos = destellos,
			trueno = cfg.Trueno[1] + (cfg.Trueno[2] - cfg.Trueno[1]) * (1 - cerca),
			tono = rng:NextNumber(),
			angulo = rng:NextNumber(0, math.pi * 2),
		})
		t += entre(cfg.Cada)
	end
	return lista
end

-- La fuerza del destello (0 a 1) a los `x` segundos del primero. `uno`: solo el primero (Rendimiento).
function TormentaVista.fuerza(r: Relampago, x: number, uno: boolean): number
	local k = 0
	for i, d in r.destellos do
		if uno and i > 1 then
			break
		end
		local dx = x - d.t
		if dx >= 0 and dx < d.subida + d.bajada then
			local v = if dx < d.subida then dx / d.subida else (1 - (dx - d.subida) / d.bajada) ^ 2
			k = math.max(k, v * d.fuerza)
		end
	end
	return k
end

-- Segundos desde el primer destello hasta que se apaga el último.
function TormentaVista.duracion(r: Relampago): number
	local d = r.destellos[#r.destellos]
	return d.t + d.subida + d.bajada
end

---------------------------------------------------------------- estado

type Activo = { r: Relampago, inicio: number, uno: boolean, fogonazos: { SpotLight }, lunas: { Light } }
local actual: Activo? = nil
local conexion: RBXScriptConnection? = nil
local temblorInicio, temblorFuerza = 0, 0
local carpeta: Folder? = nil
local extras: { [BasePart]: SpotLight } = {} -- luna → su fogonazo con sombras (se hace la primera vez)

-- Lo que el banco puede mirar.
TormentaVista.estado = { lista = {} :: { Relampago }, relampagos = 0, truenos = 0, ultimoTrueno = nil :: Sound? }

local function poco(): boolean
	return jugador:GetAttribute("Rendimiento") == true
end

-- Cinemática o muerte: cámara Scriptable sin estar mirando por la mirilla o las cortinas (como AireVista).
local function cine(): boolean
	local camara = workspace.CurrentCamera
	return camara.CameraType == Enum.CameraType.Scriptable and jugador:GetAttribute("Vistazo") == nil
end

-- La ventana de una luna tiene las cortinas echadas (la ventana más cerca, como los haces de AireVista).
local function tapada(luna: BasePart): boolean
	local mejor, cerca = nil, Config.Aire.Haz.Ventana
	for _, v in CollectionService:GetTagged("Ventana") do
		local c = v:GetAttribute("Centro")
		if typeof(c) == "CFrame" then
			local d = (c.Position - luna.Position).Magnitude
			if d < cerca then
				mejor, cerca = v, d
			end
		end
	end
	return mejor ~= nil and mejor:GetAttribute("Persiana") == true and (mejor:GetAttribute("Vida") or 1) > 0
end

-- El fogonazo con sombras de una luna: una luz en su misma línea pero `Atras` studs por fuera del cristal, para que
-- lo que haya entre ella y la sala (marcos, cortinas, un bicho) haga sombra. Apagada hasta que caiga un relámpago.
local function extraDe(luna: BasePart, foco: SpotLight): SpotLight
	local luz = extras[luna]
	if luz and luz.Parent then
		return luz
	end
	if not carpeta or not carpeta.Parent then
		local c = Instance.new("Folder")
		c.Name = "TormentaLocal" -- fuera de Mapa: Ambiente no la toma por una lámpara
		c.Parent = workspace
		carpeta = c
	end
	local f = CFG.Fogonazo
	local pieza = Instance.new("Part")
	pieza.Name = "Fogonazo"
	pieza.Anchored = true
	pieza.CanCollide = false
	pieza.CanQuery = false
	pieza.CanTouch = false
	pieza.CastShadow = false
	pieza.Transparency = 1
	pieza.Size = Vector3.new(0.2, 0.2, 0.2)
	pieza.CFrame = luna.CFrame * CFrame.new(0, 0, f.Atras) -- hacia atrás en su línea (+Z = contra el LookVector)
	luz = Instance.new("SpotLight")
	luz.Face = Enum.NormalId.Front
	luz.Angle = f.Angulo
	luz.Range = math.min(60, foco.Range + f.Atras)
	luz.Color = Color3.fromRGB(f.Color[1], f.Color[2], f.Color[3])
	luz.Shadows = true
	luz.Brightness = 0
	luz.Enabled = false
	luz.Parent = pieza
	pieza.Parent = carpeta
	extras[luna] = luz
	return luz
end

-- Las lunas cercanas a la cámara que se encienden en este relámpago (y las más cercanas, con su fogonazo).
local function elegirLunas(camara: Vector3, conSombras: boolean): ({ Light }, { SpotLight })
	local f = CFG.Fogonazo
	local cercanas = {}
	for _, luna in CollectionService:GetTagged("Luna") do
		if luna:IsA("BasePart") and luna.Parent then
			local d = (luna.Position - camara).Magnitude
			local foco = luna:FindFirstChildWhichIsA("SpotLight")
			if foco and d < f.Cerca and not tapada(luna) then
				table.insert(cercanas, { luna = luna, foco = foco, d = d })
			end
		end
	end
	table.sort(cercanas, function(a, b)
		return a.d < b.d
	end)
	local lunas, fogonazos = {}, {}
	for i, c in cercanas do
		table.insert(lunas, c.foco)
		if conSombras and i <= f.Max then
			table.insert(fogonazos, extraDe(c.luna, c.foco))
		end
	end
	return lunas, fogonazos
end

local function apagarDestello(a: Activo)
	for _, luz in a.fogonazos do
		luz.Enabled = false
		luz.Brightness = 0
	end
	for _, luz in a.lunas do
		Ambiente.lunas[luz] = nil
	end
end

-- Cada fotograma mientras dura un relámpago o el temblor de su trueno; después se desconecta solo.
local function paso()
	local reloj = os.clock()
	local d = 0
	local a = actual
	if a then
		local x = reloj - a.inicio
		if x > TormentaVista.duracion(a.r) or cine() then
			apagarDestello(a)
			actual = nil
		else
			d = TormentaVista.fuerza(a.r, x, a.uno)
			for _, luz in a.fogonazos do
				luz.Brightness = CFG.Fogonazo.Brillo * d
				luz.Enabled = d > 0.01
			end
		end
	end
	Ambiente.destello = d
	local t = CFG.Temblor
	local x = (reloj - temblorInicio) / t.Dura
	local temblor = 0
	if x >= 0 and x < 1 then
		temblor = temblorFuerza * math.min(1, x / 0.08) * (1 - x) ^ 1.5 -- de golpe y se va despacio
	end
	Ambiente.temblor = temblor
	if not actual and (x >= 1 or x < 0) then
		Ambiente.destello = 0
		Ambiente.temblor = 0
		local c = conexion
		conexion = nil
		if c then
			c:Disconnect()
		end
	end
end

local function conectar()
	if not conexion then
		conexion = RunService.RenderStepped:Connect(paso)
	end
end

-- Los cristales de las ventanas cercanas traquetean con el trueno (unas cuantas veces, cada vez más flojo) y suenan
-- los más cercanos.
local function vibrarVentanas(camara: Vector3, fuerza: number)
	local cerca = {}
	for el, e in CasaVista.elementos do
		local vibrar = e.vibrar
		if vibrar and el.Parent then
			local d = (e.centro.Position - camara).Magnitude
			if d < CFG.Ventanas then
				table.insert(cerca, { vibrar = vibrar, centro = e.centro, k = fuerza * (1 - d / CFG.Ventanas), d = d })
			end
		end
	end
	table.sort(cerca, function(a, b)
		return a.d < b.d
	end)
	for i, c in cerca do
		for vez, espera in { 0, 0.25, 0.55, 0.9 } do
			task.delay(espera, c.vibrar, c.k * (1 - (vez - 1) * 0.22))
		end
		if i <= CFG.VibraSonidos then
			local s = Sonido.en("CristalVibra", c.centro.Position, azar:NextNumber(0.85, 1))
			s.Volume *= math.min(1, c.k * 1.3)
		end
	end
end

local function trueno(r: Relampago)
	if cine() then
		return
	end
	local camara = workspace.CurrentCamera.CFrame.Position
	local propio = Sonido.hay("Trueno")
	local nombre = if propio then "Trueno" else "Retumbo"
	local tonos = if propio then CFG.TonoTrueno else CFG.TonoRetumbo
	local tono = tonos[1] + (tonos[2] - tonos[1]) * r.tono
	local volumen = CFG.Volumen[1] + (CFG.Volumen[2] - CFG.Volumen[1]) * r.cerca
	local dentro = AireVista.dentro(camara) or typeof(jugador:GetAttribute("Escondido")) == "CFrame"
	local cercano = r.cerca >= CFG.Cerca3D
	local s: Sound
	if cercano then
		-- En 3D desde fuera y entero (sin bajar con la distancia): las paredes lo tapan solas (OidoVista).
		local donde = camara + Vector3.new(math.cos(r.angulo) * CFG.Lejos3D, CFG.Alto3D, math.sin(r.angulo) * CFG.Lejos3D)
		s = Sonido.en(nombre, donde, tono)
		s.RollOffMinDistance = CFG.Lejos3D * 2
		s.RollOffMaxDistance = CFG.Lejos3D * 8
	else
		-- Lejano y sin posición: desde dentro de la casa (o escondido) se oye sordo, sin agudos.
		s = Sonido.tocar(nombre)
		s.PlaybackSpeed = tono
		if dentro then
			s.Volume *= CFG.Dentro.Volumen
			local eq = Instance.new("EqualizerSoundEffect")
			eq.LowGain = 0
			eq.MidGain = CFG.Dentro.Medios
			eq.HighGain = CFG.Dentro.Agudos
			eq.Parent = s
		end
	end
	s.Volume *= volumen
	TormentaVista.estado.truenos += 1
	TormentaVista.estado.ultimoTrueno = s
	-- Con el trueno tiembla la casa: las bombillas, los cristales y, si fue encima, un poco la cámara.
	temblorInicio = os.clock()
	temblorFuerza = CFG.Temblor.Fuerza * (0.4 + 0.6 * r.cerca)
	conectar()
	vibrarVentanas(camara, 0.4 + 0.6 * r.cerca)
	if cercano then
		CasaVista.temblar(camara, CFG.TemblorCamara * r.cerca, 10)
	end
end

-- Cae un relámpago (`tarde`: segundos que ya lleva, si este cliente lo ha visto con algo de retraso).
local function lanzar(r: Relampago, tarde: number)
	if cine() then
		return
	end
	local camara = workspace.CurrentCamera.CFrame.Position
	local uno = poco()
	if actual then
		apagarDestello(actual :: Activo)
	end
	local lunas, fogonazos = elegirLunas(camara, not uno)
	for _, luz in lunas do
		Ambiente.lunas[luz] = 1
	end
	actual = { r = r, inicio = os.clock() - tarde, uno = uno, fogonazos = fogonazos, lunas = lunas }
	TormentaVista.estado.relampagos += 1
	conectar()
	task.delay(math.max(0, r.trueno - tarde), trueno, r)
end

---------------------------------------------------------------- horario

local clave: string? = nil
local lista: { Relampago } = {}
local indice = 1

-- Mira el horario de la noche de ahora, lanza el relámpago que toque y dice cuánto dormir hasta volver a mirar
-- (como mucho 2 s, por si cambia la fase; justo hasta el siguiente si está cerca).
function TormentaVista.repasar(): number
	local noche = workspace:GetAttribute("Noche")
	local inicio, fin = workspace:GetAttribute("FaseInicio"), workspace:GetAttribute("FaseFin")
	if workspace:GetAttribute("Fase") ~= "Noche" or type(noche) ~= "number" or type(inicio) ~= "number" or type(fin) ~= "number" then
		clave = nil
		return 2
	end
	-- Para probar en Studio: workspace:SetAttribute("TormentaPrueba", true) fuerza la tormenta en esta noche.
	local forzar = workspace:GetAttribute("TormentaPrueba") == true and RunService:IsStudio()
	local nueva = `{noche}:{inicio}:{fin}:{forzar}`
	if nueva ~= clave then
		clave = nueva
		lista = TormentaVista.horario(noche, inicio, fin, CFG, forzar)
		TormentaVista.estado.lista = lista
		indice = 1
	end
	local ahora = workspace:GetServerTimeNow()
	while lista[indice] and lista[indice].t < ahora - 0.5 do -- los ya pasados (al entrar tarde, o tras un tirón)
		indice += 1
	end
	local r = lista[indice]
	if not r then
		return 2
	end
	if r.t <= ahora then
		indice += 1
		lanzar(r, ahora - r.t)
		return 0
	end
	return math.min(2, r.t - ahora)
end

function TormentaVista.start()
	task.spawn(function()
		while true do
			local espera = TormentaVista.repasar()
			if espera > 0 then
				task.wait(espera)
			end
		end
	end)
end

return TormentaVista
