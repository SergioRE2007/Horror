-- Clima del lobby (pedido por el usuario: "el lobby es un poco feo"; docs/diseño.md: gasolinera vieja de noche, con
-- lluvia, junto a la carretera del bosque). Todo en el cliente; lo que cambia en cada fotograma, en una sola tarea de
-- Bucle ("Clima"). Lo de aspecto, a ojo en las constantes de abajo; las cantidades, en Config.Lobby.
--   Luz: niebla espesa y fría (Atmosphere: con ella FogStart/FogEnd no cuentan), colores apagados (ColorCorrection) y
--     cielo cerrado, sin luna ni estrellas.
--   Lluvia alrededor de la cámara: no llueve debajo de los tejados pero sí justo fuera (bajo la marquesina o desde la
--     tienda se ve llover fuera). Charcos ("Charco") cerca: salpicaduras y ondas. "Goteo": gotas del borde de los tejados.
--   Relámpagos de vez en cuando: 2-3 destellos flojos y, segundos después, el trueno.
--   Fondo: la lluvia (más baja y apagada dentro de la tienda, "Dentro"), la lluvia en la chapa de la marquesina
--     ("Chapa"), el viento bajito y algún búho o lobo lejos en el bosque.
-- Con Rendimiento (atributo del jugador, se lee en cada uso: cambia en marcha): un tercio de gotas y menos trozos de
-- lluvia, sin salpicaduras y medio goteo.
--
-- Cómo llueve: las partículas no chocan con nada, así que un emisor encima de la cámara llovería a través de los tejados
-- cerca de su borde (desde la aparición, dentro de la marquesina). El cielo alrededor de la cámara se parte en trozos de
-- 8 × 8 studs fijos en el mundo (se recolocan al andar), cada uno con su pieza invisible y su emisor. Cada trozo mira una
-- vez qué tiene debajo con 4 × 4 rayos hacia abajo (solo contra workspace.Mapa: ni personajes ni coches; lo fino, como
-- farolas, postes, paredes o carteles, no cuenta) más las cajas de "Chapa" y "Dentro" (por si sus piezas no tapan
-- rayos). Libre: llueve hasta el suelo. Con tejado en una parte: solo en el mayor rectángulo libre. Todo tejado: las
-- gotas se acaban justo encima. Cada 0,2 s, además, un rayo hacia arriba desde la cámara (sin personajes) y la caja
-- "Dentro": si lo de encima no es del mapa (el coche en el que vas) se quita también la lluvia de su huella, y se sabe
-- si estás bajo techo o dentro (para los sonidos).
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Bucle = require(script.Parent.Bucle)
local Sonido = require(script.Parent.Sonido)

local Clima = {}

local CFG = Config.Lobby
local jugador = Players.LocalPlayer
local azar = Random.new()

-- Aspecto (a ojo; hay que mirarlo en Studio).
local NIEBLA = {
	Densidad = 0.52, -- alta: la carretera se pierde en la niebla a unos 150-250 studs
	Offset = 0.2, -- algo de silueta de los árboles contra la niebla
	Haze = 2.2,
	Color = Color3.fromRGB(56, 63, 76), -- azul grisáceo oscuro
	Decay = Color3.fromRGB(36, 41, 52),
}
local COLOR = { Saturacion = -0.3, Contraste = 0.07, Tinte = Color3.fromRGB(222, 230, 255) } -- apagado y frío
local TEX_GOTA = "rbxasset://textures/particles/sparkles_main.dds" -- estirada no se reconoce: pasa por gota
local TEX_ONDA = "rbxasset://textures/particles/smoke_main.dds" -- mancha suave que crece tumbada en el agua
local LLUVIA = {
	Celda = 8, -- studs de lado de cada trozo de cielo
	Lado = 8, -- trozos por lado alrededor de la cámara: llueve a 28-36 studs (con Rendimiento, 6: a 20-28)
	LadoPoco = 6,
	Rayos = 4, -- rayos por lado en cada trozo (uno cada 2 studs)
	Encima = 20, -- las gotas salen a estos studs por encima de la cámara...
	Alto = { 22, 70 }, -- ...entre estas alturas del mundo
	Velocidad = { 82, 98 }, -- studs/s cayendo
	Suelo = 1.5, -- lo que esté más bajo es suelo: las gotas lo atraviesan y no se ve
	Guardados = 900, -- trozos medidos que se recuerdan (luego se olvidan todos y se vuelven a medir)
}
local ALTO_RAYO = 150 -- de dónde bajan los rayos que buscan tejados (por encima de todo el lobby)
local FINO = 3 -- studs: lo que tenga la huella más estrecha no tapa la lluvia (las gotas pasan por dentro y no se ve)
local MEDIR = 4 -- trozos que se miden como mucho en cada fotograma (para que no dé tirones)
local MARGEN = { Chapa = 0.4, Dentro = 1.2, Coche = 1 } -- studs de más alrededor de cada tejado (paredes, aleros)
local VIENTO = { Fuerza = { 10, 36 }, Cambio = { 3, 8 }, Rumbo = 0.7, Giro = 0.5 } -- empuje de lado (studs/s²) y rachas
local CERCA = { Charco = 45, Goteo = 40 } -- studs desde la cámara
local GOTEO = { Gravedad = 80 } -- studs/s²: menos que la física de Roblox, que deja ver caer la gota
local RELAMPAGO = { -- lo que sube en lo más fuerte de un destello (nunca cegador)
	Brillo = 0.7, -- Lighting.Brightness
	Fuera = Color3.fromRGB(44, 47, 56), -- se suma al OutdoorAmbient
	Niebla = Color3.fromRGB(34, 37, 46), -- se suma a la niebla
	Color = 0.05, -- brillo del ColorCorrection
	Primero = { 8, 16 }, -- segundos hasta el primero (que se vea en los primeros minutos)
}
local SONIDOS = { Dentro = 0.3, Techo = 0.75, Viento = 0.45, VientoDentro = 0.45, ChapaDentro = 0.45 } -- proporciones
local ANIMALES = { Cada = { 40, 90 }, Lejos = { 90, 150 }, Centro = Vector3.new(40, 0, 0) } -- desde la explanada

type Caja = { x0: number, z0: number, x1: number, z1: number, y: number, y0: number } -- huella en el suelo, arriba y abajo
type Celda = {
	parte: Part,
	emisor: ParticleEmitter,
	cx: number, -- trozo de la rejilla (si clave no es nil)
	cz: number,
	clave: string?,
	medida: { number }?, -- altura de lo que hay en cada punto (0 = suelo)
	pendiente: boolean,
	peso: number, -- cuánto llueve por la distancia a la cámara (0 a 1)
	-- lo puesto ahora, para no tocar propiedades sin cambios
	encendida: boolean,
	ritmo: number,
	vida: number,
	sitio: Vector3,
	tamano: Vector3,
}
type Charco = { emisor: Part?, gotitas: ParticleEmitter?, ondas: ParticleEmitter?, tapado: boolean?, encendido: boolean }
type Goteo = {
	hecho: boolean, -- ya se midió su caída y se hicieron sus emisores
	gota: ParticleEmitter?,
	suelo: Attachment?, -- donde cae
	chof: ParticleEmitter?,
	onda: ParticleEmitter?,
	encendido: boolean,
	ritmo: number,
}
type Pulso = { inicio: number, subida: number, bajada: number, fuerza: number }

local carpeta: Folder -- lo que pone el clima en el mundo (solo en este cliente)
local mapa: Instance? = nil
local atmosfera: Atmosphere
local color: ColorCorrectionEffect
local cieloMio: Sky? = nil

local rayosMapa = RaycastParams.new() -- solo el mapa: lo que no se mueve
rayosMapa.FilterType = Enum.RaycastFilterType.Include
rayosMapa.IgnoreWater = true
local rayosArriba = RaycastParams.new() -- todo menos los personajes y lo del clima
rayosArriba.FilterType = Enum.RaycastFilterType.Exclude
rayosArriba.IgnoreWater = true

local fijos: { Caja } = {} -- "Chapa" y "Dentro"
local tapas: { Caja } = {} -- lo que tapa ahora y no es del mapa (el coche en el que vas, lo de encima de la cámara)
local firmaTapas = ""
local medidas: { [string]: { number } } = {}
local cuantasMedidas = 0
local sucio = false -- cambió el mapa o los tejados: hay que volver a medir
local celdas: { Celda } = {}
local puestas: { [string]: Celda } = {} -- clave del trozo → la celda que lo llueve
local pendientes: { Celda } = {}
local centroX, centroZ, ladoPuesto = math.huge, math.huge, 0
local alto = LLUVIA.Alto[1] -- de dónde salen las gotas ahora (altura del mundo)
local sumaPesos = 1
local viento = Vector3.zero
local vientoObjetivo = Vector3.zero
local proximoViento = 0

local dentro = false -- la cámara dentro de una caja "Dentro" (la tienda)
local techo = false -- algo que tapa encima de la cámara
local charcos: { [BasePart]: Charco } = {}
local goteos: { [Attachment]: Goteo } = {}

local lluvia: Sound? = nil
local apagado: EqualizerSoundEffect? = nil -- la lluvia oída desde dentro: sin agudos
local vientoSonido: Sound? = nil
local chapas: { [BasePart]: Sound } = {}
local volumen = { Lluvia = 0, Viento = 0, Chapa = 0 } -- proporción puesta ahora (sube al empezar)
local objetivo = { Lluvia = 1, Viento = SONIDOS.Viento, Chapa = 1 }

local pulsos: { Pulso } = {}
type Base = { brillo: number, fuera: Color3, color: number, niebla: Color3, decay: Color3, atmosfera: Atmosphere }
local base: Base? = nil -- la luz de antes del destello que está sonando

local function poco(): boolean
	return jugador:GetAttribute("Rendimiento") == true
end

local function entre(par: { number }): number
	return azar:NextNumber(par[1], par[2])
end

local function secuencia(puntos: { { number } }): NumberSequence
	local lista = {}
	for _, p in puntos do
		table.insert(lista, NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0))
	end
	return NumberSequence.new(lista)
end

-- Pieza invisible que no choca ni tapa nada, para colgar emisores.
local function parte(nombre: string, tamano: Vector3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = nombre
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Size = tamano
	p.CFrame = cf
	p.Parent = carpeta
	return p
end

-- La huella en el suelo (XZ) de una caja girada, con `margen` studs de más, y la altura de su cara de arriba.
local function huella(cf: CFrame, tamano: Vector3, margen: number): Caja
	local m = tamano / 2
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	local ex = math.abs(r.X) * m.X + math.abs(u.X) * m.Y + math.abs(l.X) * m.Z
	local ey = math.abs(r.Y) * m.X + math.abs(u.Y) * m.Y + math.abs(l.Y) * m.Z
	local ez = math.abs(r.Z) * m.X + math.abs(u.Z) * m.Y + math.abs(l.Z) * m.Z
	local p = cf.Position
	return {
		x0 = p.X - ex - margen,
		x1 = p.X + ex + margen,
		z0 = p.Z - ez - margen,
		z1 = p.Z + ez + margen,
		y = p.Y + ey,
		y0 = p.Y - ey,
	}
end

local function dentroDeCaja(cf: CFrame, tamano: Vector3, p: Vector3): boolean
	local l = cf:PointToObjectSpace(p)
	return math.abs(l.X) <= tamano.X / 2 and math.abs(l.Y) <= tamano.Y / 2 and math.abs(l.Z) <= tamano.Z / 2
end

-- Si una pieza tapa la lluvia como un tejado: lo fino (farolas, postes, paredes, carteles) y lo alto y estrecho
-- (troncos) no; las gotas pasan por dentro y no se ve.
local function tapa(cosa: Instance): boolean
	if cosa:IsA("Terrain") then
		return true
	end
	if not cosa:IsA("BasePart") then
		return false
	end
	local h = huella(cosa.CFrame, cosa.Size, 0)
	local ancho = math.min(h.x1 - h.x0, h.z1 - h.z0)
	return ancho >= FINO and h.y - h.y0 <= ancho * 2
end

local function cocheDe(cosa: Instance): Model?
	local m = cosa:FindFirstAncestorWhichIsA("Model")
	while m do
		if CollectionService:HasTag(m, "Coche") then
			return m
		end
		m = m:FindFirstAncestorWhichIsA("Model")
	end
	return nil
end

-- LUZ ------------------------------------------------------------------------------------------------------------

local function ponerNiebla(a: Atmosphere)
	a.Density = NIEBLA.Densidad
	a.Offset = NIEBLA.Offset
	a.Haze = NIEBLA.Haze
	a.Glare = 0
	a.Color = NIEBLA.Color
	a.Decay = NIEBLA.Decay
end

local function sinLuna(cielo: Sky)
	cielo.CelestialBodiesShown = false -- ni sol, ni luna, ni estrellas: noche cerrada de lluvia
	cielo.StarCount = 0
end

local function luz()
	local suya = Lighting:FindFirstChildOfClass("Atmosphere") -- si ya hay una (del servidor), se usa esa
	atmosfera = suya or Instance.new("Atmosphere")
	ponerNiebla(atmosfera)
	atmosfera.Parent = Lighting
	local mia = if suya then nil else atmosfera
	color = Instance.new("ColorCorrectionEffect")
	color.Name = "ColorClima"
	color.Saturation = COLOR.Saturacion
	color.Contrast = COLOR.Contraste
	color.TintColor = COLOR.Tinte
	color.Brightness = 0
	color.Parent = Lighting
	local cielo = Lighting:FindFirstChildOfClass("Sky")
	if cielo then
		sinLuna(cielo)
	else
		local nuevo = Instance.new("Sky")
		nuevo.Name = "CieloClima"
		sinLuna(nuevo)
		nuevo.Parent = Lighting
		cieloMio = nuevo
	end
	-- Lo del servidor que llegue tarde manda sobre lo puesto aquí (nunca dos a la vez).
	Lighting.ChildAdded:Connect(function(hijo)
		if hijo:IsA("Sky") and hijo ~= cieloMio then
			sinLuna(hijo)
			if cieloMio then
				cieloMio:Destroy()
				cieloMio = nil
			end
		elseif hijo:IsA("Atmosphere") and hijo ~= atmosfera then
			atmosfera = hijo
			ponerNiebla(hijo)
			if mia then
				mia:Destroy()
				mia = nil
			end
		end
	end)
end

-- RELÁMPAGOS ------------------------------------------------------------------------------------------------------

local function mas(c: Color3, d: Color3, k: number): Color3
	return Color3.new(math.min(1, c.R + d.R * k), math.min(1, c.G + d.G * k), math.min(1, c.B + d.B * k))
end

-- Deja la luz como estaba antes del destello (lo apuntado al empezar, nunca a medias: aunque se solapen dos).
local function restaurar()
	local b = base
	if not b then
		return
	end
	base = nil
	Lighting.Brightness = b.brillo
	Lighting.OutdoorAmbient = b.fuera
	color.Brightness = b.color
	b.atmosfera.Color = b.niebla
	b.atmosfera.Decay = b.decay
end

-- Cada fotograma: la fuerza de ahora es la del destello más fuerte que esté sonando (0 = ninguno).
local function pintarRelampago(ahora: number)
	if #pulsos == 0 and not base then
		return
	end
	local k = 0
	for i = #pulsos, 1, -1 do
		local p = pulsos[i]
		local x = ahora - p.inicio
		if x >= p.subida + p.bajada then
			table.remove(pulsos, i)
		elseif x > 0 then
			local v = if x < p.subida then x / p.subida else (1 - (x - p.subida) / p.bajada) ^ 2
			k = math.max(k, v * p.fuerza)
		end
	end
	if k <= 0.001 then
		restaurar()
		return
	end
	local b = base
		or { -- lo de antes del destello, apuntado al empezar
			brillo = Lighting.Brightness,
			fuera = Lighting.OutdoorAmbient,
			color = color.Brightness,
			niebla = atmosfera.Color,
			decay = atmosfera.Decay,
			atmosfera = atmosfera,
		}
	base = b
	Lighting.Brightness = b.brillo + RELAMPAGO.Brillo * k
	Lighting.OutdoorAmbient = mas(b.fuera, RELAMPAGO.Fuera, k)
	color.Brightness = b.color + RELAMPAGO.Color * k
	b.atmosfera.Color = mas(b.niebla, RELAMPAGO.Niebla, k)
	b.atmosfera.Decay = mas(b.decay, RELAMPAGO.Niebla, k * 0.6)
end

-- Un relámpago: 2-3 destellos seguidos y el trueno después. Cuanto más cerca, más fuerte y antes suena.
local function relampago()
	local ahora = os.clock()
	for i = #pulsos, 1, -1 do -- los ya acabados (por si el bucle no ha corrido)
		if ahora - pulsos[i].inicio > 2 then
			table.remove(pulsos, i)
		end
	end
	local cerca = azar:NextNumber()
	local t = ahora
	for _ = 1, azar:NextInteger(2, 3) do
		table.insert(pulsos, {
			inicio = t,
			subida = 0.025,
			bajada = azar:NextNumber(0.08, 0.22),
			fuerza = (0.5 + 0.5 * cerca) * azar:NextNumber(0.6, 1),
		})
		t += azar:NextNumber(0.08, 0.3)
	end
	local tr = CFG.Relampago.Trueno
	task.delay(tr[1] + (tr[2] - tr[1]) * (1 - cerca), function()
		local s = Sonido.tocar("Trueno")
		if s then
			s.Volume *= (0.55 + 0.45 * cerca) * (if dentro then 0.7 else 1)
			s.PlaybackSpeed = azar:NextNumber(0.9, 1.05)
		end
	end)
end

-- LLUVIA ----------------------------------------------------------------------------------------------------------

local function peso(d: number): number
	if d <= 12 then
		return 1
	end
	return math.max(0.3, 1 - (d - 12) / 26 * 0.7)
end

-- Lo que suman los pesos de una ventana de n × n trozos libres: así Config.Lobby.Lluvia.Gotas es el total por segundo.
local function sumar(n: number): number
	local s = 0
	for a = 0, n - 1 do
		for b = 0, n - 1 do
			local dx, dz = (a - n / 2 + 0.5) * LLUVIA.Celda, (b - n / 2 + 0.5) * LLUVIA.Celda
			s += peso(math.sqrt(dx * dx + dz * dz))
		end
	end
	return s
end

local function rehacerFijos()
	table.clear(fijos)
	for _, tag in { "Chapa", "Dentro" } do
		for _, p in CollectionService:GetTagged(tag) do
			if p:IsA("BasePart") and p:IsDescendantOf(workspace) then
				table.insert(fijos, huella(p.CFrame, p.Size, MARGEN[tag]))
			end
		end
	end
	sucio = true
end

-- Altura de lo que tapa en (x, z), mirando desde arriba (0 = suelo).
local function cima(x: number, z: number): number
	local h = 0
	local desde = Vector3.new(x, ALTO_RAYO, z)
	for _ = 1, 4 do
		local r = workspace:Raycast(desde, Vector3.new(0, -(desde.Y + 20), 0), rayosMapa)
		if not r then
			break
		end
		if tapa(r.Instance) then
			h = r.Position.Y
			break
		end
		desde = r.Position - Vector3.new(0, 0.05, 0) -- lo fino no cuenta: se sigue mirando debajo
	end
	for _, t in fijos do
		if x >= t.x0 and x <= t.x1 and z >= t.z0 and z <= t.z1 then
			h = math.max(h, t.y)
		end
	end
	return h
end

local function medir(cx: number, cz: number): { number }
	local clave = cx .. "," .. cz
	local hecha = medidas[clave]
	if hecha then
		return hecha
	end
	if cuantasMedidas >= LLUVIA.Guardados then
		table.clear(medidas)
		cuantasMedidas = 0
	end
	local n = LLUVIA.Rayos
	local paso = LLUVIA.Celda / n
	local x0, z0 = cx * LLUVIA.Celda, cz * LLUVIA.Celda
	local lista = table.create(n * n, 0)
	for j = 1, n do
		for i = 1, n do
			lista[(j - 1) * n + i] = cima(x0 + (i - 0.5) * paso, z0 + (j - 0.5) * paso)
		end
	end
	medidas[clave] = lista
	cuantasMedidas += 1
	return lista
end

-- El mayor rectángulo de puntos libres de una rejilla n × n (libre[(j - 1) * n + i]): fuerza bruta, son 100 en 4 × 4.
local function rectangulo(libre: { boolean }, n: number): (number?, number?, number?, number?)
	local mejor = 0
	local ri0, rj0, ri1, rj1
	for i0 = 1, n do
		for i1 = i0, n do
			for j0 = 1, n do
				for j1 = j0, n do
					-- la fila j1 entre i0 e i1 (las de antes ya se miraron con j1 más corto)
					local fila = true
					for i = i0, i1 do
						if not libre[(j1 - 1) * n + i] then
							fila = false
							break
						end
					end
					if not fila then
						break -- más alto tampoco vale
					end
					local area = (i1 - i0 + 1) * (j1 - j0 + 1)
					if area > mejor then
						mejor, ri0, rj0, ri1, rj1 = area, i0, j0, i1, j1
					end
				end
			end
		end
	end
	return ri0, rj0, ri1, rj1
end

-- Qué pasa en un punto con lo que tiene debajo (h) y lo que tapa ahora: "libre" (llueve hasta el suelo), "tejado" (las
-- gotas se acaban en él) o "tapado" (no llueve: lo de encima sube más que de donde salen las gotas).
local function estadoPunto(h: number, x: number, z: number): (string, number)
	for _, t in tapas do
		if x >= t.x0 and x <= t.x1 and z >= t.z0 and z <= t.z1 then
			h = math.max(h, t.y)
		end
	end
	if h <= LLUVIA.Suelo then
		return "libre", h
	elseif h < alto - 1 then
		return "tejado", h
	end
	return "tapado", h
end

local function total(): number
	return if poco() then CFG.Lluvia.Gotas / 3 else CFG.Lluvia.Gotas
end

-- Dónde y cuánto llueve en un trozo (lo calcula todo y solo cambia las propiedades que cambian).
local function pintarCelda(c: Celda)
	local G, n = LLUVIA.Celda, LLUVIA.Rayos
	local paso = G / n
	local medida = c.medida
	local encender, ritmo, vida = false, c.ritmo, c.vida
	local sitio, tamano = c.sitio, c.tamano
	if c.clave and medida and c.peso > 0 then
		local x0, z0 = c.cx * G, c.cz * G
		local libre = table.create(n * n, false)
		local libres, tejados, encima = 0, 0, 0
		for j = 1, n do
			for i = 1, n do
				local k = (j - 1) * n + i
				local estado, h = estadoPunto(medida[k], x0 + (i - 0.5) * paso, z0 + (j - 0.5) * paso)
				if estado == "libre" then
					libre[k] = true
					libres += 1
				elseif estado == "tejado" then
					tejados += 1
					encima = math.max(encima, h)
				end
			end
		end
		local todo = total() * c.peso / sumaPesos -- gotas/s del trozo entero
		if libres > 0 then
			local i0, j0, i1, j1 = 1, 1, n, n
			if libres < n * n then
				i0, j0, i1, j1 = rectangulo(libre, n)
			end
			if i0 and j0 and i1 and j1 then
				local ax, az = x0 + (i0 - 1) * paso, z0 + (j0 - 1) * paso
				local bx, bz = x0 + i1 * paso, z0 + j1 * paso
				sitio = Vector3.new((ax + bx) / 2, alto, (az + bz) / 2)
				tamano = Vector3.new(bx - ax, 0.2, bz - az)
				ritmo = todo * (i1 - i0 + 1) * (j1 - j0 + 1) / (n * n)
				vida = (alto + 0.6) / LLUVIA.Velocidad[1] -- hasta pasar del suelo, también las más lentas
				encender = true
			end
		elseif tejados == n * n and alto - encima > 2 then
			sitio = Vector3.new(x0 + G / 2, alto, z0 + G / 2)
			tamano = Vector3.new(G, 0.2, G)
			ritmo = todo * 0.5 -- encima de un tejado casi no se ven
			vida = (alto - encima - 0.4) / LLUVIA.Velocidad[2] -- se acaban encima, también las más rápidas
			encender = true
		end
	end
	if encender then
		if sitio ~= c.sitio then
			c.parte.CFrame = CFrame.new(sitio)
			c.sitio = sitio
		end
		if tamano ~= c.tamano then
			c.parte.Size = tamano
			c.tamano = tamano
		end
		if math.abs(ritmo - c.ritmo) > 0.05 then
			c.emisor.Rate = ritmo
			c.ritmo = ritmo
		end
		if math.abs(vida - c.vida) > 0.004 then
			c.emisor.Lifetime = NumberRange.new(vida)
			c.vida = vida
		end
	end
	if encender ~= c.encendida then
		c.emisor.Enabled = encender
		c.encendida = encender
	end
end

local function pintarTodas()
	for _, c in celdas do
		pintarCelda(c)
	end
end

local function nuevaCelda(): Celda
	local p = parte("Lluvia", Vector3.new(LLUVIA.Celda, 0.2, LLUVIA.Celda), CFrame.new(0, -500, 0))
	local e = Instance.new("ParticleEmitter")
	e.Name = "Gotas"
	e.Texture = TEX_GOTA
	-- Alineadas con su velocidad (cayendo, algo inclinadas con el viento). Squash, según la documentación de Roblox:
	-- > 0 encoge a lo ancho y estira a lo alto, < 0 estira a lo ancho y encoge a lo alto. Eso vale tal cual con
	-- FacingCamera; con VelocityParallel el ancho de la partícula queda a lo largo de su velocidad, así que va al revés:
	-- la guía de lluvia de Roblox ("Simulate rain") y su ejemplo weather-island piden Squash negativo con
	-- VelocityParallel (el ejemplo usa -3). Por eso -3: gotas largas a lo largo de la caída y finas.
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Squash = NumberSequence.new(-3)
	e.Size = secuencia({ { 0, 0.5, 0.08 }, { 1, 0.5, 0.08 } })
	e.Color = ColorSequence.new(Color3.fromRGB(165, 176, 192)) -- gris azulado
	e.Transparency = secuencia({ { 0, 0.85 }, { 0.15, 0.6 }, { 1, 0.62 } })
	e.LightInfluence = 0.75 -- se ven sobre todo cerca de las luces
	e.LightEmission = 0.1
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Speed = NumberRange.new(LLUVIA.Velocidad[1], LLUVIA.Velocidad[2])
	e.SpreadAngle = Vector2.new(2, 2)
	e.Acceleration = viento
	e.Lifetime = NumberRange.new(0.3)
	e.Rate = 0
	e.Enabled = false
	e.Parent = p
	local c: Celda = {
		parte = p,
		emisor = e,
		cx = 0,
		cz = 0,
		clave = nil,
		medida = nil,
		pendiente = false,
		peso = 0,
		encendida = false,
		ritmo = 0,
		vida = 0.3,
		sitio = p.Position,
		tamano = p.Size,
	}
	table.insert(celdas, c)
	return c
end

-- La ventana de n × n trozos alrededor del vértice (vx, vz) de la rejilla: los que ya estaban se quedan; los que
-- salen se usan para los que entran.
local function recolocar(vx: number, vz: number, n: number)
	if n ~= ladoPuesto then
		sumaPesos = sumar(n)
	end
	centroX, centroZ, ladoPuesto = vx, vz, n
	local G = LLUVIA.Celda
	local quedan: { [string]: boolean } = {}
	local faltan: { { number } } = {}
	for a = 0, n - 1 do
		for b = 0, n - 1 do
			local cx, cz = vx - n / 2 + a, vz - n / 2 + b
			local clave = cx .. "," .. cz
			quedan[clave] = true
			if not puestas[clave] then
				table.insert(faltan, { cx, cz })
			end
		end
	end
	for clave, c in puestas do
		if not quedan[clave] then
			puestas[clave] = nil
			c.clave = nil
			c.medida = nil
		end
	end
	local indice = 1
	for _, f in faltan do
		local suelta: Celda? = nil
		while indice <= #celdas do
			local c = celdas[indice]
			indice += 1
			if not c.clave then
				suelta = c
				break
			end
		end
		local c = suelta or nuevaCelda()
		c.cx, c.cz = f[1], f[2]
		c.clave = f[1] .. "," .. f[2]
		c.medida = medidas[c.clave] -- si ya se midió; si no, se mide poco a poco (MEDIR por fotograma)
		puestas[c.clave :: string] = c
		if not c.medida and not c.pendiente then
			c.pendiente = true
			table.insert(pendientes, c)
		end
	end
	for _, c in celdas do
		if c.clave then
			local dx, dz = (c.cx + 0.5 - vx) * G, (c.cz + 0.5 - vz) * G
			c.peso = peso(math.sqrt(dx * dx + dz * dz))
		else
			c.peso = 0
		end
		pintarCelda(c)
	end
end

local function medirPendientes()
	local hechas = 0
	while hechas < MEDIR and #pendientes > 0 do
		local c = table.remove(pendientes, 1) :: Celda
		c.pendiente = false
		if c.clave then
			c.medida = medir(c.cx, c.cz)
			pintarCelda(c)
			hechas += 1
		end
	end
end

-- Cada fotograma: la ventana sigue a la cámara (solo se recoloca al pasar a otro vértice de la rejilla).
local function seguirCamara(pos: Vector3)
	if pos.X ~= pos.X or math.abs(pos.X) > 1e5 or math.abs(pos.Z) > 1e5 then
		return -- cámara rota (NaN o lejísimos)
	end
	local G = LLUVIA.Celda
	local n = if poco() then LLUVIA.LadoPoco else LLUVIA.Lado
	local vx, vz = math.floor(pos.X / G + 0.5), math.floor(pos.Z / G + 0.5)
	local nuevoAlto = math.clamp(math.floor((pos.Y + LLUVIA.Encima) / 3) * 3, LLUVIA.Alto[1], LLUVIA.Alto[2])
	if vx ~= centroX or vz ~= centroZ or n ~= ladoPuesto then
		alto = nuevoAlto
		recolocar(vx, vz, n)
	elseif nuevoAlto ~= alto then
		alto = nuevoAlto
		pintarTodas()
	end
	medirPendientes()
end

-- Cambió el mapa o los tejados: se olvida lo medido y se vuelve a medir lo puesto (mientras, llueve como antes).
local function volverAMedir()
	sucio = false
	table.clear(medidas)
	cuantasMedidas = 0
	for _, c in celdas do
		if c.clave and not c.pendiente then
			c.pendiente = true
			table.insert(pendientes, c)
		end
	end
	for _, c in charcos do
		c.tapado = nil -- se vuelve a mirar si están bajo techo
	end
end

local function soplar(ahora: number)
	if ahora >= proximoViento then
		proximoViento = ahora + entre(VIENTO.Cambio)
		local rumbo = VIENTO.Rumbo + azar:NextNumber(-VIENTO.Giro, VIENTO.Giro)
		vientoObjetivo = Vector3.new(math.cos(rumbo), 0, math.sin(rumbo)) * entre(VIENTO.Fuerza)
	end
	local nuevo = viento:Lerp(vientoObjetivo, 0.35)
	if (nuevo - viento).Magnitude > 0.5 then
		viento = nuevo
		for _, c in celdas do
			c.emisor.Acceleration = viento
		end
	end
end

-- TECHO -----------------------------------------------------------------------------------------------------------

local function toca(c: Celda, t: Caja): boolean
	local G = LLUVIA.Celda
	local x0, z0 = c.cx * G, c.cz * G
	return t.x1 >= x0 and t.x0 <= x0 + G and t.z1 >= z0 and t.z0 <= z0 + G
end

-- Cada 0,2 s: si la cámara está dentro de la tienda o bajo techo, y lo que tapa sin ser del mapa (el coche en el que vas
-- aunque la cámara esté fuera, un coche con la cámara dentro, lo que haya encima).
local function mirarEncima(pos: Vector3)
	local fuera: { Instance } = { carpeta }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(fuera, p.Character)
		end
	end
	rayosArriba.FilterDescendantsInstances = fuera

	dentro = false
	for _, caja in CollectionService:GetTagged("Dentro") do
		if caja:IsA("BasePart") and caja:IsDescendantOf(workspace) and dentroDeCaja(caja.CFrame, caja.Size, pos) then
			dentro = true
			break
		end
	end

	local nuevas: { Caja } = {}
	local vistos: { [Instance]: boolean } = {}
	local function taparCon(cosa: Instance)
		if vistos[cosa] then
			return
		end
		vistos[cosa] = true
		if cosa:IsA("Model") then
			local ok, cf, tam = pcall(cosa.GetBoundingBox, cosa)
			if ok then
				table.insert(nuevas, huella(cf, tam, MARGEN.Coche))
			end
		elseif cosa:IsA("BasePart") then
			table.insert(nuevas, huella(cosa.CFrame, cosa.Size, MARGEN.Coche))
		end
	end
	local r = workspace:Raycast(pos, Vector3.new(0, 40, 0), rayosArriba)
	techo = r ~= nil and tapa(r.Instance)
	if r and techo and not (mapa and r.Instance:IsDescendantOf(mapa)) then
		taparCon(cocheDe(r.Instance) or r.Instance)
	end
	for _, t in fijos do -- la marquesina aunque su pieza no tape rayos
		if pos.X >= t.x0 and pos.X <= t.x1 and pos.Z >= t.z0 and pos.Z <= t.z1 and t.y > pos.Y then
			techo = true
		end
	end
	local nombre = jugador:GetAttribute("Coche")
	local coches = workspace:FindFirstChild("Coches")
	local mio = if type(nombre) == "string" and coches then coches:FindFirstChild(nombre) else nil
	-- (el que está saliendo se esconde mientras va su copia, SalidaVista: ese no tapa)
	if mio and mio:IsA("Model") and not mio:GetAttribute("SaliendoLocal") then
		taparCon(mio)
	end
	for _, m in CollectionService:GetTagged("Coche") do
		if m:IsA("Model") and m:IsDescendantOf(workspace) and not m:GetAttribute("SaliendoLocal")
			and (m:GetPivot().Position - pos).Magnitude < 16 then
			local ok, cf, tam = pcall(m.GetBoundingBox, m)
			if ok and dentroDeCaja(cf, tam, pos) then
				taparCon(m)
				techo = true
			end
		end
	end
	techo = techo or dentro

	local firma = ""
	for _, t in nuevas do
		firma ..= string.format("%.0f,%.0f,%.0f,%.0f,%.0f;", t.x0, t.z0, t.x1, t.z1, t.y)
	end
	if firma ~= firmaTapas then
		local viejas = tapas
		tapas, firmaTapas = nuevas, firma
		for _, c in celdas do
			if c.clave then
				local repintar = false
				for _, t in viejas do
					repintar = repintar or toca(c, t)
				end
				for _, t in nuevas do
					repintar = repintar or toca(c, t)
				end
				if repintar then
					pintarCelda(c)
				end
			end
		end
	end

	objetivo.Lluvia = if dentro then SONIDOS.Dentro elseif techo then SONIDOS.Techo else 1
	local racha = 0.8 + 0.4 * math.min(1, viento.Magnitude / VIENTO.Fuerza[2])
	objetivo.Viento = SONIDOS.Viento * racha * (if dentro then SONIDOS.VientoDentro else 1)
	objetivo.Chapa = if dentro then SONIDOS.ChapaDentro else 1
	if apagado then
		apagado.Enabled = dentro
	end
end

-- CHARCOS Y GOTEO -------------------------------------------------------------------------------------------------

local function tapadoEn(p: Vector3): boolean
	for _, t in fijos do
		if p.X >= t.x0 and p.X <= t.x1 and p.Z >= t.z0 and p.Z <= t.z1 and t.y > p.Y then
			return true
		end
	end
	local r = workspace:Raycast(p + Vector3.new(0, 0.3, 0), Vector3.new(0, 40, 0), rayosArriba)
	return r ~= nil and tapa(r.Instance)
end

-- La cara de arriba de una pieza plana (su eje más vertical es el grueso): el centro de esa cara (con el giro de la
-- pieza alrededor de Y) y sus dos medidas.
local function caraDeArriba(p: BasePart): (CFrame, number, number)
	local cf, s = p.CFrame, p.Size
	local ejes = { cf.RightVector, cf.UpVector, cf.LookVector }
	local largos = { s.X, s.Y, s.Z }
	local k = 2
	for i = 1, 3 do
		if math.abs(ejes[i].Y) > math.abs(ejes[k].Y) then
			k = i
		end
	end
	local a, b = if k == 1 then 2 else 1, if k == 3 then 2 else 3
	local arriba = if ejes[k].Y >= 0 then ejes[k] else -ejes[k]
	local lado = Vector3.new(ejes[a].X, 0, ejes[a].Z)
	lado = if lado.Magnitude > 1e-3 then lado.Unit else Vector3.xAxis
	return CFrame.fromMatrix(cf.Position + arriba * largos[k] / 2, lado, Vector3.yAxis), largos[a], largos[b]
end

-- Gotitas que saltan al caer una gota (charcos y debajo del goteo).
local function gotitas(padre: Instance, ritmo: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "Gotitas"
	e.Texture = TEX_GOTA
	e.Color = ColorSequence.new(Color3.fromRGB(176, 186, 200))
	e.LightInfluence = 0.85
	e.LightEmission = 0.1
	e.Size = secuencia({ { 0, 0.09, 0.03 }, { 1, 0.05, 0.02 } })
	e.Transparency = secuencia({ { 0, 0.35 }, { 1, 1 } })
	e.Lifetime = NumberRange.new(0.16, 0.3)
	e.Speed = NumberRange.new(3, 6)
	e.SpreadAngle = Vector2.new(40, 40)
	e.Acceleration = Vector3.new(0, -60, 0)
	e.EmissionDirection = Enum.NormalId.Top
	e.Rate = ritmo
	e.Enabled = false
	e.Parent = padre
	return e
end

-- Ondas planas en el agua: VelocityPerpendicular con una velocidad mínima hacia arriba las deja tumbadas.
local function ondas(padre: Instance, ritmo: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "Ondas"
	e.Texture = TEX_ONDA
	e.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	e.Color = ColorSequence.new(Color3.fromRGB(170, 180, 196))
	e.LightInfluence = 1 -- solo se ven con luz cerca
	e.LightEmission = 0
	e.Size = secuencia({ { 0, 0.15 }, { 1, 1.1, 0.25 } })
	e.Transparency = secuencia({ { 0, 0.55 }, { 1, 1 } })
	e.Lifetime = NumberRange.new(0.45, 0.7)
	e.Speed = NumberRange.new(0.05)
	e.SpreadAngle = Vector2.zero
	e.Rotation = NumberRange.new(0, 360)
	e.EmissionDirection = Enum.NormalId.Top
	e.Rate = ritmo
	e.Enabled = false
	e.Parent = padre
	return e
end

local function hacerCharco(pieza: BasePart, c: Charco)
	local cf, ancho, largo = caraDeArriba(pieza)
	local redondo = pieza:IsA("Part") and pieza.Shape ~= Enum.PartType.Block
	local f = if redondo then 0.6 else 0.8 -- que no salgan fuera del agua
	local tam = Vector3.new(math.max(0.2, ancho * f), 0.02, math.max(0.2, largo * f))
	local e = parte("Charco", tam, cf * CFrame.new(0, 0.04, 0)) -- un poco por encima: que no parpadee con el agua
	c.emisor = e
	c.gotitas = gotitas(e, CFG.Lluvia.Salpicaduras * 1.5)
	c.ondas = ondas(e, CFG.Lluvia.Salpicaduras)
end

local function quitarCharco(pieza: Instance)
	local c = charcos[pieza :: BasePart]
	if c then
		charcos[pieza :: BasePart] = nil
		if c.emisor then
			c.emisor:Destroy()
		end
	end
end

local function charcosCerca(pos: Vector3)
	local sin = poco() -- con Rendimiento, ninguna salpicadura
	for pieza, c in charcos do
		local quiere = not sin and pieza:IsDescendantOf(workspace) and (pieza.Position - pos).Magnitude < CERCA.Charco
		if quiere and c.tapado == nil then
			c.tapado = tapadoEn(caraDeArriba(pieza).Position)
		end
		quiere = quiere and not c.tapado
		if quiere and not c.emisor then
			hacerCharco(pieza, c)
		end
		if quiere ~= c.encendido then
			c.encendido = quiere
			if c.gotitas then
				c.gotitas.Enabled = quiere
			end
			if c.ondas then
				c.ondas.Enabled = quiere
			end
		end
	end
end

-- La gota del borde del tejado: sale quieta y cae acelerando hasta lo que haya debajo; allí, gotitas (y ondas si es un
-- charco). La caída se mide una vez.
local function hacerGoteo(punto: Attachment, g: Goteo)
	g.hecho = true
	local desde = punto.WorldPosition
	local r = workspace:Raycast(desde - Vector3.new(0, 0.25, 0), Vector3.new(0, -60, 0), rayosMapa)
	local hasta = if r then r.Position else Vector3.new(desde.X, 0, desde.Z)
	local enCharco = false -- cae en un charco (aunque no tape rayos): ondas
	for pieza in charcos do
		local h = huella(pieza.CFrame, pieza.Size, 0)
		local encima = math.abs(h.y - hasta.Y) < 0.6
		if encima and hasta.X >= h.x0 and hasta.X <= h.x1 and hasta.Z >= h.z0 and hasta.Z <= h.z1 then
			enCharco = true
			hasta = Vector3.new(hasta.X, math.max(hasta.Y, h.y), hasta.Z)
		end
	end
	local caida = desde.Y - hasta.Y
	if caida < 0.5 then
		return
	end
	local e = Instance.new("ParticleEmitter")
	e.Name = "Gota"
	e.Texture = TEX_GOTA
	e.Orientation = Enum.ParticleOrientation.VelocityParallel
	e.Squash = secuencia({ { 0, 0 }, { 0.4, -1 }, { 1, -2.2 } }) -- se estira al coger velocidad (negativo: ver Gotas)
	e.Size = secuencia({ { 0, 0.14, 0.03 }, { 1, 0.14, 0.03 } })
	e.Color = ColorSequence.new(Color3.fromRGB(175, 185, 200))
	e.Transparency = NumberSequence.new(0.35)
	e.LightInfluence = 0.8
	e.LightEmission = 0.1
	e.Speed = NumberRange.new(0) -- quieta: la dirección del Attachment no importa
	e.Acceleration = Vector3.new(0, -GOTEO.Gravedad, 0)
	e.Lifetime = NumberRange.new(math.sqrt(2 * caida / GOTEO.Gravedad))
	e.Rate = CFG.Lluvia.Goteo
	e.Enabled = false
	e.Parent = punto
	g.gota = e
	g.ritmo = CFG.Lluvia.Goteo
	local suelo = Instance.new("Attachment")
	suelo.Name = "GoteoSuelo"
	suelo.Parent = workspace.Terrain
	suelo.WorldPosition = hasta + Vector3.new(0, 0.05, 0)
	g.suelo = suelo
	g.chof = gotitas(suelo, CFG.Lluvia.Goteo)
	if enCharco then
		g.onda = ondas(suelo, CFG.Lluvia.Goteo)
	end
end

local function quitarGoteo(punto: Instance)
	local g = goteos[punto :: Attachment]
	if g then
		goteos[punto :: Attachment] = nil
		if g.gota then
			g.gota:Destroy()
		end
		if g.suelo then
			g.suelo:Destroy()
		end
	end
end

local function goteoCerca(pos: Vector3)
	local sin = poco() -- con Rendimiento, medio goteo y sin salpicar
	for punto, g in goteos do
		local quiere = punto:IsDescendantOf(workspace) and (punto.WorldPosition - pos).Magnitude < CERCA.Goteo
		if quiere and not g.hecho then
			hacerGoteo(punto, g)
		end
		local gota = g.gota
		if gota then
			local ritmo = if sin then CFG.Lluvia.Goteo / 2 else CFG.Lluvia.Goteo
			if ritmo ~= g.ritmo then
				g.ritmo = ritmo
				gota.Rate = ritmo
			end
			local salpica = quiere and not sin
			if quiere ~= g.encendido or (g.chof and g.chof.Enabled ~= salpica) then
				g.encendido = quiere
				gota.Enabled = quiere
				if g.chof then
					g.chof.Enabled = salpica
				end
				if g.onda then
					g.onda.Enabled = salpica
				end
			end
		end
	end
end

-- Cada 0,5 s: lo que se enciende y se apaga por la distancia, el viento y lo que hay que volver a medir.
local ultimaMedida = 0
local function cercanos(pos: Vector3, ahora: number)
	if sucio and ahora - ultimaMedida > 1 then
		ultimaMedida = ahora
		volverAMedir()
	end
	soplar(ahora)
	charcosCerca(pos)
	goteoCerca(pos)
end

-- SONIDOS ---------------------------------------------------------------------------------------------------------

local function volumenes(dt: number)
	local k = math.min(1, dt * 3)
	for clave, quiere in objetivo do
		volumen[clave] += (quiere - volumen[clave]) * k
	end
	if lluvia then
		lluvia.Volume = Config.SonidosLobby.Lluvia.Volumen * volumen.Lluvia
	end
	if vientoSonido then
		vientoSonido.Volume = Config.Sonidos.Viento.Volumen * volumen.Viento
	end
	for _, s in chapas do
		s.Volume = Config.SonidosLobby.LluviaChapa.Volumen * volumen.Chapa
	end
end

local function sonidos()
	Sonido.precargar({ "Lluvia", "LluviaChapa", "Viento", "Trueno", "Buho", "Lobo" })
	lluvia = Sonido.bucle("Lluvia")
	if lluvia then
		lluvia.Volume = 0
		local eq = Instance.new("EqualizerSoundEffect")
		eq.LowGain = 0
		eq.MidGain = -5
		eq.HighGain = -14
		eq.Enabled = false
		eq.Parent = lluvia
		apagado = eq
	end
	vientoSonido = Sonido.bucle("Viento")
	if vientoSonido then
		vientoSonido.Volume = 0
	end
end

-- De vez en cuando, un búho (en lo alto de un árbol) o un lobo, lejos en el bosque.
local function animales()
	while true do
		task.wait(entre(ANIMALES.Cada))
		local nombre = if azar:NextNumber() < 0.6 then "Buho" else "Lobo"
		local angulo = azar:NextNumber(0, math.pi * 2)
		local lejos = entre(ANIMALES.Lejos)
		local donde = ANIMALES.Centro + Vector3.new(math.cos(angulo) * lejos, 0, math.sin(angulo) * lejos)
		local y = if nombre == "Buho" then azar:NextNumber(18, 30) else 1.5
		Sonido.en(nombre, Vector3.new(donde.X, y, donde.Z), azar:NextNumber(0.92, 1.06))
	end
end

local function relampagos()
	task.wait(entre(RELAMPAGO.Primero))
	while true do
		relampago()
		task.wait(entre(CFG.Relampago.Cada))
	end
end

-- ARRANQUE --------------------------------------------------------------------------------------------------------

local rotos: { [string]: boolean } = {}
-- Un trozo que falla avisa una vez y se deja de hacer, sin parar lo demás (Bucle quitaría toda la tarea).
local function seguro(nombre: string, fn: (...any) -> (), ...: any)
	if rotos[nombre] then
		return
	end
	local ok, fallo = pcall(fn, ...)
	if not ok then
		rotos[nombre] = true
		warn(`[Clima] {nombre}: {fallo}`)
		if nombre == "Relampago" then
			pcall(restaurar)
		end
	end
end

local function vigilar(tag: string, alPoner: (Instance) -> (), alQuitar: (Instance) -> ())
	CollectionService:GetInstanceAddedSignal(tag):Connect(alPoner)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(alQuitar)
	for _, cosa in CollectionService:GetTagged(tag) do
		alPoner(cosa)
	end
end

local proximoTecho, proximoMedio = 0, 0
local function paso(dt: number, ahora: number, camara: Camera)
	if not camara then
		return
	end
	local pos = camara.CFrame.Position
	if mapa then
		seguro("Lluvia", seguirCamara, pos)
		if ahora >= proximoTecho then
			proximoTecho = ahora + 0.2
			seguro("Techo", mirarEncima, pos)
		end
		if ahora >= proximoMedio then
			proximoMedio = ahora + 0.5
			seguro("Cerca", cercanos, pos, ahora)
		end
	end
	seguro("Sonidos", volumenes, dt)
	seguro("Relampago", pintarRelampago, ahora)
end

function Clima.start()
	local c = Instance.new("Folder")
	c.Name = "Clima"
	c.Parent = workspace
	carpeta = c
	luz()
	sonidos()
	task.spawn(relampagos)
	task.spawn(animales)
	Bucle.cada("Clima", paso)
	task.spawn(function()
		local m = workspace:WaitForChild("Mapa")
		rayosMapa.FilterDescendantsInstances = { m, workspace.Terrain }
		-- Lo que llega o se va del mapa cambia los tejados (el mapa llega a trozos al entrar).
		local function cambia(d: Instance)
			if d:IsA("BasePart") and d.CanQuery then
				sucio = true
			end
		end
		m.DescendantAdded:Connect(cambia)
		m.DescendantRemoving:Connect(cambia)
		vigilar("Chapa", function(p)
			rehacerFijos()
			if p:IsA("BasePart") and not chapas[p] then
				local s = Sonido.bucle("LluviaChapa", p)
				if s then
					s.Volume = 0
					chapas[p] = s
				end
			end
		end, function(p)
			rehacerFijos()
			local s = chapas[p :: BasePart]
			if s then
				chapas[p :: BasePart] = nil
				s:Destroy()
			end
		end)
		vigilar("Dentro", rehacerFijos, rehacerFijos)
		vigilar("Charco", function(p)
			if p:IsA("BasePart") and not charcos[p] then
				charcos[p] = { encendido = false }
			end
		end, quitarCharco)
		vigilar("Goteo", function(a)
			if a:IsA("Attachment") and not goteos[a] then
				goteos[a] = { hecho = false, encendido = false, ritmo = 0 }
			end
		end, quitarGoteo)
		sucio = false -- lo medido a partir de ahora ya ve los tejados de arriba
		mapa = m
	end)
end

return Clima
