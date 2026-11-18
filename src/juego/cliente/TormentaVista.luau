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
--   Si cae cerca (Rayo.Desde), además se ve el rayo en el cielo: un trazo quebrado de Beams (TormentaVista.forma) del
--   mismo lado del que llegará el trueno (angulo), más cerca cuanto más cerca cae, que parpadea con los destellos.
--   Lo ven todos a la vez: el horario sale de una semilla con Noche y FaseInicio (atributos del Ciclo) y la hora del
--   servidor. Sin servidor nuevo.
-- Nada en cinemáticas ni en la muerte (cámara Scriptable sin el atributo Vistazo; por la mirilla, sí). Con Rendimiento,
-- un solo destello por relámpago, sin la luz con sombras y el rayo sin ramas ni resplandor.
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

export type Forma = {
	tronco: { Vector3 }, -- de arriba (y = Alto) al suelo (0, 0, 0), donde cae
	ramas: { { Vector3 } }, -- cada una empieza en un punto del tronco y acaba en el aire
	ancho: number, -- studs del tronco
}

-- La forma de un rayo, con el sitio donde cae en (0, 0, 0). La misma semilla da la misma forma en todos los clientes
-- (la semilla sale de la hora del relámpago, sin gastar tiradas del horario).
function TormentaVista.forma(semilla: number, cerca: number, cfg: any): Forma
	local R = cfg.Rayo
	local rng = Random.new(semilla)
	local n = rng:NextInteger(R.Tramos[1], R.Tramos[2])
	-- Tramos de largo desigual: unos largos y otros cortos, como un rayo de verdad.
	local pesos, suma = {}, 0
	for i = 1, n do
		pesos[i] = rng:NextNumber(0.5, 1.5)
		suma += pesos[i]
	end
	local ix = rng:NextNumber(-R.Inclina, R.Inclina) -- todo el rayo se inclina un poco hacia un lado
	local iz = rng:NextNumber(-R.Inclina, R.Inclina)
	local x, y, z = 0, R.Alto, 0
	local puntos = { Vector3.new(x, y, z) }
	for i = 1, n do
		local paso = R.Alto * pesos[i] / suma
		x += (rng:NextNumber(-1, 1) * R.Desvio + ix) * paso
		z += (rng:NextNumber(-1, 1) * R.Desvio + iz) * paso
		y = if i == n then 0 else y - paso
		table.insert(puntos, Vector3.new(x, y, z))
	end
	-- Que caiga justo en (0, 0, 0).
	local abajo = Vector3.new(x, 0, z)
	local tronco = {}
	for i, p in puntos do
		tronco[i] = p - abajo
	end
	local ramas = {}
	for _ = 1, rng:NextInteger(R.Ramas[1], R.Ramas[2]) do
		local desde = tronco[rng:NextInteger(2, math.max(2, math.floor(n * 0.6)))]
		local giro = rng:NextNumber(0, math.pi * 2)
		local rama = { desde }
		local p = desde
		for _ = 1, rng:NextInteger(R.TramosRama[1], R.TramosRama[2]) do
			local paso = R.Alto / n * rng:NextNumber(0.5, 0.9)
			local fuera = paso * rng:NextNumber(0.6, 1.2)
			giro += rng:NextNumber(-0.6, 0.6)
			local siguiente = p + Vector3.new(math.cos(giro) * fuera, -paso, math.sin(giro) * fuera)
			if siguiente.Y < R.Alto * 0.08 then
				break -- las ramas nunca llegan al suelo
			end
			table.insert(rama, siguiente)
			p = siguiente
		end
		if #rama >= 2 then
			table.insert(ramas, rama)
		end
	end
	local k = math.clamp(cerca, 0, 1)
	return { tronco = tronco, ramas = ramas, ancho = R.Ancho[1] + (R.Ancho[2] - R.Ancho[1]) * k }
end

-- A cuántos studs de la cámara (en planta) cae el rayo de un relámpago, o nil si cae tan lejos que no se ve.
function TormentaVista.distanciaRayo(cerca: number, cfg: any): number?
	local R = cfg.Rayo
	if cerca < R.Desde then
		return nil
	end
	local k = math.clamp((cerca - R.Desde) / math.max(1e-6, 1 - R.Desde), 0, 1)
	return R.Lejos + (R.Cerca - R.Lejos) * k
end

-- La semilla de la forma del rayo de un relámpago (igual en todos: sale de su hora).
function TormentaVista.semillaRayo(r: Relampago): number
	return math.floor(r.t * 1000) % 2_147_483_647
end

---------------------------------------------------------------- estado

type Activo = { r: Relampago, inicio: number, uno: boolean, fogonazos: { SpotLight }, lunas: { Light } }
local actual: Activo? = nil
local conexion: RBXScriptConnection? = nil
local temblorInicio, temblorFuerza = 0, 0
local carpeta: Folder? = nil
local extras: { [BasePart]: SpotLight } = {} -- luna → su fogonazo con sombras (se hace la primera vez)

-- El rayo del cielo: Beams entre Attachments de una pieza invisible en el origen (TormentaLocal). Se hacen la primera
-- vez y se reutilizan; entre relámpagos, apagados.
local rayo = {
	pieza = nil :: Part?,
	puntos = {} :: { Attachment },
	nucleos = {} :: { Beam },
	halos = {} :: { Beam },
	usados = 0, -- núcleos encendidos
	halosUsados = 0,
	vis = 0, -- lo que se ve ahora (0 a 1)
	reloj = 0, -- cuándo se pintó por última vez (para el resto en el ojo)
}

-- Lo que el banco puede mirar.
TormentaVista.estado = {
	lista = {} :: { Relampago },
	relampagos = 0,
	truenos = 0,
	ultimoTrueno = nil :: Sound?,
	rayos = 0, -- rayos dibujados en el cielo
	rayo = nil :: { base: Vector3, forma: Forma, ramas: boolean }?, -- el que hay ahora (nil cuando se apaga)
}

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
local function carpetaLocal(): Folder
	local c = carpeta
	if not c or not c.Parent then
		c = Instance.new("Folder")
		c.Name = "TormentaLocal" -- fuera de Mapa: Ambiente no la toma por una lámpara
		c.Parent = workspace
		carpeta = c
	end
	return c :: Folder
end

local function extraDe(luna: BasePart, foco: SpotLight): SpotLight
	local luz = extras[luna]
	if luz and luz.Parent then
		return luz
	end
	local dentroDe = carpetaLocal()
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
	pieza.Parent = dentroDe
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

---------------------------------------------------------------- el rayo del cielo

-- La pieza que lleva los puntos del rayo (en el origen, así cada Attachment.Position es su sitio en el mundo).
local function piezaRayo(): Part
	local p = rayo.pieza
	if p and p.Parent then
		return p
	end
	rayo.puntos, rayo.nucleos, rayo.halos = {}, {}, {}
	rayo.usados, rayo.halosUsados = 0, 0
	local nueva = Instance.new("Part")
	nueva.Name = "Rayo"
	nueva.Anchored = true
	nueva.CanCollide = false
	nueva.CanQuery = false
	nueva.CanTouch = false
	nueva.CastShadow = false
	nueva.Transparency = 1
	nueva.Size = Vector3.new(0.2, 0.2, 0.2)
	nueva.CFrame = CFrame.new()
	nueva.Parent = carpetaLocal()
	rayo.pieza = nueva
	return nueva
end

local function puntoRayo(i: number): Attachment
	local a = rayo.puntos[i]
	if not a then
		a = Instance.new("Attachment")
		a.Name = "Punto"
		a.Parent = piezaRayo()
		rayo.puntos[i] = a
	end
	return a
end

-- Un Beam del rayo (del pozo de núcleos o del de halos): blanco azulado, sin luz del mundo, siempre de cara.
local function hazRayo(pozo: { Beam }, i: number, nombre: string): Beam
	local b = pozo[i]
	if not b then
		local R = CFG.Rayo
		b = Instance.new("Beam")
		b.Name = nombre
		b.FaceCamera = true
		b.Segments = 1
		b.Color = ColorSequence.new(Color3.fromRGB(R.Color[1], R.Color[2], R.Color[3]))
		b.LightEmission = 1
		b.LightInfluence = 0
		b.Brightness = R.Brillo
		b.Transparency = NumberSequence.new(1)
		b.Enabled = false
		b.Parent = piezaRayo()
		pozo[i] = b
	end
	return b
end

local function esconderRayo()
	for i = 1, rayo.usados do
		rayo.nucleos[i].Enabled = false
	end
	for i = 1, rayo.halosUsados do
		rayo.halos[i].Enabled = false
	end
	rayo.usados, rayo.halosUsados, rayo.vis = 0, 0, 0
	TormentaVista.estado.rayo = nil
end

-- Dibuja (aún sin verse) el rayo de `f` cayendo en `base`; con `completo`, ramas y resplandor.
local function dibujarRayo(f: Forma, base: Vector3, completo: boolean)
	esconderRayo()
	piezaRayo()
	local R = CFG.Rayo
	local n, nb, nh = 0, 0, 0
	local function linea(puntos: { Vector3 }, ancho: number, afinar: boolean, halo: boolean)
		local antes: Attachment? = nil
		for j, p in puntos do
			n += 1
			local a = puntoRayo(n)
			a.Position = base + p
			if antes then
				-- Las ramas se afinan hacia la punta; el tronco, igual de ancho de arriba abajo.
				local w0 = if afinar then ancho * (1 - 0.7 * (j - 2) / #puntos) else ancho
				local w1 = if afinar then ancho * (1 - 0.7 * (j - 1) / #puntos) else ancho
				nb += 1
				local b = hazRayo(rayo.nucleos, nb, "Tramo")
				b.Attachment0, b.Attachment1 = antes, a
				b.Width0, b.Width1 = w0, w1
				b.Transparency = NumberSequence.new(1)
				b.Enabled = true
				if halo then
					nh += 1
					local h = hazRayo(rayo.halos, nh, "Halo")
					h.Attachment0, h.Attachment1 = antes, a
					h.Width0, h.Width1 = w0 * R.Halo.Ancho, w1 * R.Halo.Ancho
					h.Transparency = NumberSequence.new(1)
					h.Enabled = true
				end
			end
			antes = a
		end
	end
	linea(f.tronco, f.ancho, false, completo)
	if completo then
		for _, rama in f.ramas do
			linea(rama, f.ancho * R.Rama, true, false)
		end
	end
	rayo.usados, rayo.halosUsados, rayo.vis = nb, nh, 0
	rayo.reloj = os.clock()
	TormentaVista.estado.rayos += 1
	TormentaVista.estado.rayo = { base = base, forma = f, ramas = completo }
end

-- Lo que se ve del rayo sigue al destello y, entre uno y otro, se apaga en Rayo.Resto (se queda un instante en el ojo).
local function pintarRayo(d: number, reloj: number)
	if rayo.usados == 0 then
		return
	end
	local R = CFG.Rayo
	local v = math.max(0, math.min(1, d * R.Realce), rayo.vis - (reloj - rayo.reloj) / R.Resto)
	rayo.reloj = reloj
	if v == rayo.vis or (v > 0 and math.abs(v - rayo.vis) < 0.01) then
		return -- casi igual que antes: no se cambian las secuencias
	end
	rayo.vis = v
	local nucleo = NumberSequence.new(1 - v)
	local halo = NumberSequence.new(1 - v * R.Halo.Opacidad)
	for i = 1, rayo.usados do
		rayo.nucleos[i].Transparency = nucleo
	end
	for i = 1, rayo.halosUsados do
		rayo.halos[i].Transparency = halo
	end
end

-- Dónde toca el suelo el rayo que cae en (x, z): lo primero que haya debajo (un árbol, un tejado) o Rayo.Suelo.
local function sueloEn(x: number, z: number, alto: number): number
	local filtro = RaycastParams.new()
	filtro.FilterType = Enum.RaycastFilterType.Exclude
	local fuera: { Instance } = { carpetaLocal() }
	if jugador.Character then
		table.insert(fuera, jugador.Character)
	end
	filtro.FilterDescendantsInstances = fuera
	local hit = workspace:Raycast(Vector3.new(x, alto, z), Vector3.new(0, -alto - 200, 0), filtro)
	return if hit then hit.Position.Y else CFG.Rayo.Suelo
end

local function apagarDestello(a: Activo)
	esconderRayo()
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
			pintarRayo(d, reloj)
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
	-- Si cae cerca, el rayo en el cielo, del lado del que llegará el trueno.
	local lejos = TormentaVista.distanciaRayo(r.cerca, CFG)
	if lejos then
		local x = camara.X + math.cos(r.angulo) * lejos
		local z = camara.Z + math.sin(r.angulo) * lejos
		local y = sueloEn(x, z, math.max(camara.Y, 0) + CFG.Rayo.Alto)
		dibujarRayo(TormentaVista.forma(TormentaVista.semillaRayo(r), r.cerca, CFG), Vector3.new(x, y, z), not uno)
	end
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
