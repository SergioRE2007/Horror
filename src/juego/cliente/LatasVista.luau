-- Las trampas de latas (14.3) en el cliente: el servidor (Latas) clava las estacas y deja en cada línea (Model "Linea" en
-- workspace.Mapa.Latas) sus atributos A, B (nudos), Comba y Semilla; aquí se cuelgan la cuerda y las latas oxidadas
-- (alguna botella y algún trapo), iguales para todos porque salen de la Semilla.
--   ("Suena", n, fuerza, donde): las latas saltan como péndulos (más las de cerca de `donde`), la cuerda vibra y
--   tintinean en 3D desde ese punto, más fuerte y más lejos cuanto más `fuerza` (un bicho ~1, un jugador ~0,3). Con un
--   bicho, unos tintineos más flojos después mientras se calman.
--   Con viento, un vaivén leve sin sonido.
-- Un solo bucle: solo mueve las líneas cerca de la cámara (CFG.Cerca). Las agitadas, cada fotograma; las de solo viento,
-- si están más cerca aún (CFG.CercaViento), en la vista, con la cámara fuera de la casa y sin Rendimiento, y un
-- fotograma de cada VIENTO_CADA. Metal oxidado que refleja un poco la linterna, sin brillos.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sonido = require(script.Parent.Sonido)

local LatasVista = {}

-- Números en Config.LatasVista.
local CFG = Config.LatasVista

local SEGMENTOS = 14 -- trozos de la cuerda
local VIENTO_CADA = 3 -- las líneas con solo viento se mueven un fotograma de cada tantos
local CUERDA = Color3.fromRGB(92, 84, 68)
local SANGRE = Color3.fromRGB(66, 10, 8)
local OXIDO = { Color3.fromRGB(112, 58, 33), Color3.fromRGB(86, 50, 36), Color3.fromRGB(128, 74, 44), Color3.fromRGB(98, 94, 86) }
local ETIQUETA = { Color3.fromRGB(118, 44, 36), Color3.fromRGB(138, 126, 96), Color3.fromRGB(64, 78, 70), Color3.fromRGB(150, 140, 118) }
local BOTELLA = { Color3.fromRGB(66, 42, 20), Color3.fromRGB(38, 62, 40) }
local TRAPO = Color3.fromRGB(94, 86, 70)

type Colgante = {
	partes: { BasePart },
	offsets: { CFrame },
	u: number, -- dónde cuelga, 0..1 a lo largo de la cuerda
	w2: number, -- gravedad / largo del péndulo
	suena: boolean, -- el trapo no tintinea
	ax: number, vx: number, -- a través de la cuerda
	az: number, vz: number, -- a lo largo de la cuerda
	giro: number, vgiro: number, -- sobre su cuerdecita
}
type Linea = {
	modelo: Model,
	a: Vector3,
	b: Vector3,
	medio: Vector3, -- el punto más bajo de la cuerda en reposo
	comba: number,
	dir: Vector3, -- a lo largo, en horizontal
	lado: Vector3, -- de través, en horizontal
	colgantes: { Colgante },
	cuerda: { BasePart },
	largos: { number }, -- largo puesto a cada trozo de cuerda (solo se toca Size si cambia de verdad)
	onda: number, -- vibración de la cuerda (studs), baja sola
	fase: number,
	agitada: boolean,
	espera: number, -- segundos sin simular (las de solo viento van a saltos de fotogramas)
}
local lineas: { [number]: Linea } = {}
local azar = Random.new()

local function pieza(nombre: string, tamano: Vector3, color: Color3, material: Enum.Material, padre: Instance): Part
	local p = Instance.new("Part")
	p.Name = nombre
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = tamano
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = padre
	return p
end

local function cilindro(nombre: string, radio: number, alto: number, color: Color3, material: Enum.Material, padre: Instance): Part
	local p = pieza(nombre, Vector3.new(alto, radio * 2, radio * 2), color, material, padre)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local VERTICAL = CFrame.Angles(0, 0, math.pi / 2) -- el eje de un cilindro (x) hacia arriba

-- Un colgante: lista de piezas con su sitio respecto al punto de la cuerda del que cuelga (y hacia abajo).
local function colgante(u: number, largo: number, suena: boolean): Colgante
	return {
		partes = {},
		offsets = {},
		u = u,
		w2 = CFG.Gravedad / largo,
		suena = suena,
		ax = 0,
		vx = 0,
		az = 0,
		vz = 0,
		giro = 0,
		vgiro = 0,
	}
end

local function poner(c: Colgante, p: BasePart, cf: CFrame)
	table.insert(c.partes, p)
	table.insert(c.offsets, cf)
end

-- La cuerdecita (alambre o bramante) del punto de la cuerda hasta lo que cuelga.
local function hilo(c: Colgante, largo: number, padre: Instance)
	poner(c, pieza("Hilo", Vector3.new(0.04, largo, 0.04), Color3.fromRGB(70, 62, 52), Enum.Material.Fabric, padre), CFrame.new(0, -largo / 2, 0))
end

local function lata(u: number, suerte: Random, padre: Instance): Colgante
	local tipo = suerte:NextNumber()
	local radio, alto = 0.33, 0.95 -- de conserva
	if tipo < 0.25 then
		radio, alto = 0.46, 1.25 -- bote grande (pintura, aceite)
	elseif tipo < 0.4 then
		radio, alto = 0.27, 0.55 -- pequeña y aplastada
	end
	radio *= suerte:NextNumber(0.92, 1.08)
	local largoHilo = suerte:NextNumber(0.5, 1.3)
	local c = colgante(u, largoHilo + alto / 2, true)
	hilo(c, largoHilo, padre)
	local color = OXIDO[suerte:NextInteger(1, #OXIDO)]:Lerp(Color3.fromRGB(60, 40, 30), suerte:NextNumber(0, 0.35))
	local inclina = CFrame.Angles(suerte:NextNumber(-0.12, 0.12), 0, suerte:NextNumber(-0.12, 0.12)) -- colgada torcida
	local centro = CFrame.new(0, -largoHilo, 0) * inclina * CFrame.new(0, -alto / 2, 0)
	local cuerpo = cilindro("Lata", radio, alto, color, Enum.Material.CorrodedMetal, padre)
	cuerpo.Reflectance = 0.06 -- refleja un poco la linterna
	cuerpo.CastShadow = true
	poner(c, cuerpo, centro * VERTICAL)
	-- Borde de arriba y de abajo, de metal más oscuro (la tapa abierta a medias en alguna).
	local borde = color:Lerp(Color3.new(0, 0, 0), 0.35)
	for _, y in { alto / 2, -alto / 2 } do
		local aro = cilindro("Borde", radio + 0.025, 0.06, borde, Enum.Material.Metal, padre)
		aro.Reflectance = 0.08
		poner(c, aro, centro * CFrame.new(0, y, 0) * VERTICAL)
	end
	if suerte:NextNumber() < 0.35 then
		local tapa = cilindro("Tapa", radio * 0.95, 0.03, borde, Enum.Material.Metal, padre)
		poner(c, tapa, centro * CFrame.new(radio * 0.7, alto / 2 + radio * 0.55, 0) * CFrame.Angles(0, 0, 1.1) * VERTICAL)
	end
	-- Etiqueta de papel desteñida (media lata) y, alguna vez, una mancha de sangre seca.
	if suerte:NextNumber() < 0.55 then
		local papel = cilindro("Etiqueta", radio + 0.012, alto * suerte:NextNumber(0.4, 0.6),
			ETIQUETA[suerte:NextInteger(1, #ETIQUETA)]:Lerp(color, 0.45), Enum.Material.SmoothPlastic, padre)
		poner(c, papel, centro * CFrame.new(0, suerte:NextNumber(-0.08, 0.08), 0) * VERTICAL)
	end
	if suerte:NextNumber() < 0.15 then
		poner(c, pieza("Sangre", Vector3.new(radio * 0.9, alto * 0.7, 0.04), SANGRE, Enum.Material.SmoothPlastic, padre),
			centro * CFrame.new(0, -alto * 0.1, -radio - 0.01) * CFrame.Angles(0, 0, 0.3))
	end
	return c
end

local function botella(u: number, suerte: Random, padre: Instance): Colgante
	local largoHilo = suerte:NextNumber(0.4, 0.9)
	local c = colgante(u, largoHilo + 0.8, true)
	hilo(c, largoHilo, padre)
	-- Atada por el cuello, boca arriba y algo torcida. Plástico y no Glass (Glass no deja ver lo transparente de detrás).
	local color = BOTELLA[suerte:NextInteger(1, #BOTELLA)]
	local base = CFrame.new(0, -largoHilo, 0) * CFrame.Angles(suerte:NextNumber(-0.2, 0.2), 0, suerte:NextNumber(-0.2, 0.2))
	for _, t in { { "Cuello", 0.1, 0.45, -0.22 }, { "Hombro", 0.19, 0.18, -0.52 }, { "Botella", 0.26, 0.95, -1.08 } } do
		local p = cilindro(t[1], t[2], t[3], color, Enum.Material.SmoothPlastic, padre)
		p.Transparency = 0.3
		p.Reflectance = 0.12
		poner(c, p, base * CFrame.new(0, t[4], 0) * VERTICAL)
	end
	return c
end

local function trapo(u: number, suerte: Random, padre: Instance, sangre: boolean): Colgante
	local largo = suerte:NextNumber(1.2, 2)
	local c = colgante(u, largo * 0.6, false)
	local color = if sangre then SANGRE:Lerp(TRAPO, 0.25) else TRAPO:Lerp(Color3.fromRGB(50, 44, 36), suerte:NextNumber(0, 0.5))
	poner(c, pieza("Trapo", Vector3.new(0.5, largo, 0.03), color, Enum.Material.Fabric, padre),
		CFrame.new(0, -largo / 2 + 0.1, 0) * CFrame.Angles(0, suerte:NextNumber(-0.4, 0.4), 0))
	poner(c, pieza("Jiron", Vector3.new(0.18, largo * 0.5, 0.03), color, Enum.Material.Fabric, padre),
		CFrame.new(0.2, -largo + 0.05, 0) * CFrame.Angles(0, 0, 0.15))
	return c
end

-- Punto de la cuerda a `u` (0..1): la comba de siempre más lo que vibra y lo que la mueve el viento.
local function puntoCuerda(l: Linea, u: number, t: number, viento: number): Vector3
	local p = l.a:Lerp(l.b, u) - Vector3.yAxis * (4 * l.comba * u * (1 - u))
	local forma = math.sin(math.pi * u)
	if l.onda > 0.002 then
		local w = t * 38 + l.fase
		local arriba = l.onda * (forma * math.sin(w) + 0.4 * math.sin(2 * math.pi * u) * math.sin(w * 1.7 + 1))
		p += Vector3.yAxis * arriba + l.lado * (arriba * 0.6)
	end
	return p + l.lado * (forma * viento * 0.6)
end

local function crear(modelo: Model)
	local n = modelo:GetAttribute("Linea")
	local a, b = modelo:GetAttribute("A"), modelo:GetAttribute("B")
	if type(n) ~= "number" or typeof(a) ~= "Vector3" or typeof(b) ~= "Vector3" or lineas[n] then
		return
	end
	local suerte = Random.new(modelo:GetAttribute("Semilla") or n)
	local plano = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local dir = plano.Unit
	local l: Linea = {
		modelo = modelo,
		a = a,
		b = b,
		medio = (a + b) / 2 - Vector3.yAxis * (modelo:GetAttribute("Comba") or 0.7),
		comba = modelo:GetAttribute("Comba") or 0.7,
		dir = dir,
		lado = dir:Cross(Vector3.yAxis),
		colgantes = {},
		cuerda = {},
		largos = {},
		onda = 0,
		fase = suerte:NextNumber(0, math.pi * 2),
		agitada = false,
		espera = 0,
	}
	for i = 1, SEGMENTOS do
		local trozo = cilindro("Cuerda", 0.045, 1, CUERDA, Enum.Material.Fabric, modelo)
		trozo.Name = "Cuerda" .. i
		table.insert(l.cuerda, trozo)
	end
	-- Una lata cada ~4 studs (5 a 8), una botella en un sitio al azar (dos en las largas) y, en una de cada tres, un trapo.
	local cuantas = math.clamp(math.round(plano.Magnitude / 4), 5, 8)
	local botellas = { [suerte:NextInteger(1, cuantas)] = true }
	if cuantas >= 8 then
		botellas[suerte:NextInteger(1, cuantas)] = true
	end
	for i = 1, cuantas do
		local u = 0.1 + 0.8 * (i - 0.5) / cuantas + suerte:NextNumber(-0.03, 0.03)
		table.insert(l.colgantes, if botellas[i] then botella(u, suerte, modelo) else lata(u, suerte, modelo))
	end
	if n % 3 == 0 or n % 5 == 1 then
		table.insert(l.colgantes, trapo(suerte:NextNumber(0.15, 0.85), suerte, modelo, n % 5 == 1))
	end
	for _, c in l.colgantes do -- cada uno quieto en un ángulo un poco distinto
		c.giro = suerte:NextNumber(0, math.pi * 2)
		c.ax = suerte:NextNumber(-0.04, 0.04)
	end
	lineas[n] = l
end

local lista: { BasePart } = {}
local sitios: { CFrame } = {}

-- Pone la cuerda y los colgantes donde toca a la hora `t`.
local function colocar(l: Linea, t: number, viento: number)
	table.clear(lista)
	table.clear(sitios)
	local antes = puntoCuerda(l, 0, t, viento)
	for i = 1, SEGMENTOS do
		local p = puntoCuerda(l, i / SEGMENTOS, t, viento)
		table.insert(lista, l.cuerda[i])
		table.insert(sitios, CFrame.lookAt((antes + p) / 2, p) * CFrame.Angles(0, math.pi / 2, 0))
		local largo = (p - antes).Magnitude + 0.03
		if math.abs(largo - (l.largos[i] or 0)) > 0.01 then -- con el viento casi no cambia: no tocar Size
			l.largos[i] = largo
			l.cuerda[i].Size = Vector3.new(largo, 0.09, 0.09)
		end
		antes = p
	end
	for _, c in l.colgantes do
		local cuelga = CFrame.fromMatrix(puntoCuerda(l, c.u, t, viento), l.dir, Vector3.yAxis)
			* CFrame.Angles(c.ax, 0, c.az) * CFrame.Angles(0, c.giro, 0)
		for i, parte in c.partes do
			table.insert(lista, parte)
			table.insert(sitios, cuelga * c.offsets[i])
		end
	end
	-- FireCFrameChanged es el modo barato (no lanza Position/Orientation); nadie escucha estas piezas.
	workspace:BulkMoveTo(lista, sitios, Enum.BulkMoveMode.FireCFrameChanged)
end

-- ¿Se ve la línea? Mira los dos nudos y el medio contra el cono de la cámara (con margen).
local function seVe(l: Linea, cf: CFrame, cosMax: number): boolean
	for _, p in { l.a, l.b, l.medio } do
		local hacia = p - cf.Position
		local d = hacia.Magnitude
		if d < 6 or hacia:Dot(cf.LookVector) > cosMax * d then
			return true
		end
	end
	return false
end

-- Coseno del ángulo de la esquina de la pantalla (más un margen): lo de fuera de ese cono no se ve.
local function conoCamara(camara: Camera): number
	local tanV = math.tan(math.rad(camara.FieldOfView) / 2)
	local vista = camara.ViewportSize
	local tanH = tanV * (if vista.Y > 0 then vista.X / vista.Y else 1.8)
	return math.cos(math.min(math.atan(math.sqrt(tanV * tanV + tanH * tanH)) + 0.2, math.pi * 0.9))
end

-- La cámara dentro de la casa o en el sótano (como AmbienteMiedo): desde ahí el vaivén de fuera no se nota.
local function camaraEnCasa(p: Vector3): boolean
	if p.Y < -2 then
		return true
	end
	if p.Y > Config.AmbienteMiedo.AltoCasa then
		return false
	end
	if math.abs(p.X) < Config.Casa.MedioX and math.abs(p.Z) < Config.Casa.MedioZ then
		return true
	end
	for _, a in Config.Casa.Anexos do
		if p.X > a[1] and p.X < a[2] and p.Z > a[3] and p.Z < a[4] then
			return true
		end
	end
	return false
end

-- El viento: un vaivén lento con rachas, distinto en cada línea.
local function vientoDe(l: Linea, t: number): number
	local racha = 0.6 + 0.4 * math.sin(t * 0.13 + l.fase)
	return CFG.Viento * racha * (math.sin(t * 0.55 + l.fase) + 0.6 * math.sin(t * 1.31 + l.fase * 2))
end

-- Un paso de los péndulos. Devuelve si aún se mueve algo (más que el viento).
local function simular(l: Linea, dt: number, viento: number): boolean
	local frena = math.exp(-CFG.Frena * dt)
	local mueve = l.onda > 0.01
	for _, c in l.colgantes do
		c.vx = (c.vx - c.w2 * (math.sin(c.ax) - viento) * dt) * frena
		c.vz = (c.vz - c.w2 * math.sin(c.az) * dt) * frena
		c.vgiro *= math.exp(-1.6 * dt)
		c.ax = math.clamp(c.ax + c.vx * dt, -1.3, 1.3)
		c.az = math.clamp(c.az + c.vz * dt, -1.1, 1.1)
		c.giro += c.vgiro * dt
		-- 0,15: por encima de lo que mueve el viento solo (si no, una línea con viento no se calmaría nunca).
		if math.abs(c.vx) + math.abs(c.vz) + math.abs(c.vgiro) > 0.15 then
			mueve = true
		end
	end
	l.onda *= math.exp(-2.4 * dt)
	return mueve
end

local function puntoDe(l: Linea, donde: number): Vector3
	return l.a:Lerp(l.b, donde) - Vector3.yAxis * (4 * l.comba * donde * (1 - donde))
end

-- Distancia (en planta) de la cámara a la línea.
local function distancia(l: Linea, p: Vector3): number
	local ab = l.b - l.a
	local t = math.clamp((p - l.a):Dot(ab) / ab:Dot(ab), 0, 1)
	local q = l.a + ab * t
	return Vector3.new(p.X - q.X, 0, p.Z - q.Z).Magnitude
end

local function tintinear(punto: Vector3, fuerza: number, volumen: number, tono: number)
	local s = Sonido.en("Latas", punto, tono)
	s.Volume = Config.Sonidos.Latas.Volumen * volumen * (CFG.Volumen[1] + (CFG.Volumen[2] - CFG.Volumen[1]) * fuerza)
	s.RollOffMinDistance = CFG.Lejos[1] + (CFG.Lejos[2] - CFG.Lejos[1]) * fuerza
	s.RollOffMaxDistance = CFG.Alcance[1] + (CFG.Alcance[2] - CFG.Alcance[1]) * fuerza
end

local function suena(n: number, fuerza: number, donde: number)
	local l = lineas[n]
	if not l then
		return
	end
	-- Las latas saltan: más las de al lado de por donde ha pasado, todas hacia el mismo lado (le han empujado) y
	-- girando cada una a su aire.
	local sentido = if azar:NextNumber() < 0.5 then -1 else 1
	for _, c in l.colgantes do
		local k = fuerza * (0.3 + 0.7 * math.exp(-((c.u - donde) / 0.28) ^ 2))
		c.vx += sentido * k * CFG.Golpe * azar:NextNumber(0.7, 1.2)
		c.vz += k * CFG.Golpe * azar:NextNumber(-0.45, 0.45)
		c.vgiro += k * azar:NextNumber(-7, 7)
	end
	l.onda = math.max(l.onda, CFG.Onda * fuerza)
	l.agitada = true
	local punto = puntoDe(l, donde)
	tintinear(punto, fuerza, 1, azar:NextNumber(0.95, 1.05))
	if fuerza >= 0.6 then -- un bicho: se oyen chocar un rato mientras se calman
		for _, eco in CFG.Ecos do
			task.delay(eco[1] + azar:NextNumber(-0.08, 0.08), function()
				tintinear(puntoDe(l, math.clamp(donde + azar:NextNumber(-0.25, 0.25), 0, 1)), fuerza, eco[2], eco[3])
			end)
		end
	end
end

function LatasVista.start()
	Remotes.Latas.OnClientEvent:Connect(function(que: string, n: number, fuerza: number, donde: number?)
		if que == "Suena" and type(n) == "number" and type(fuerza) == "number" then
			suena(n, math.clamp(fuerza, 0, 1), math.clamp(if type(donde) == "number" then donde else 0.5, 0, 1))
		end
	end)
	task.spawn(function()
		local carpeta = workspace:WaitForChild("Mapa"):WaitForChild("Latas")
		for _, modelo in carpeta:GetChildren() do
			if modelo:IsA("Model") then
				crear(modelo)
			end
		end
		local t = os.clock()
		for _, l in lineas do
			colocar(l, t, 0) -- todas en reposo; luego solo se mueven las de cerca
		end
		local jugador = Players.LocalPlayer
		local cuadro = 0
		RunService.Heartbeat:Connect(function(dt)
			local ahora = os.clock()
			local camara = workspace.CurrentCamera
			local cf = camara.CFrame
			local pos = cf.Position
			dt = math.min(dt, 1 / 20)
			cuadro += 1
			-- Con Rendimiento no hay viento; y desde dentro de la casa el vaivén de fuera no se nota.
			local hayViento = jugador:GetAttribute("Rendimiento") ~= true and not camaraEnCasa(pos)
			local cono: number? = nil
			for n, l in lineas do
				local d = distancia(l, pos)
				if d > CFG.Cerca then
					continue
				end
				if l.agitada then
					-- Agitada por algo: cada fotograma y se vea o no, en dos medios pasos (con un fotograma lento el
					-- péndulo no se dispara).
					local viento = if hayViento then vientoDe(l, ahora) else 0
					l.espera = 0
					simular(l, dt / 2, viento)
					l.agitada = simular(l, dt / 2, viento)
					colocar(l, ahora, viento)
					continue
				end
				-- Solo viento: de cerca, en la vista y un fotograma de cada VIENTO_CADA (repartidas entre fotogramas).
				if not hayViento or d > CFG.CercaViento then
					l.espera = 0
					continue
				end
				l.espera += dt
				if (cuadro + n) % VIENTO_CADA ~= 0 then
					continue
				end
				cono = cono or conoCamara(camara)
				if not seVe(l, cf, cono :: number) then
					l.espera = 0
					continue
				end
				local viento = vientoDe(l, ahora)
				local total = math.min(l.espera, 0.1)
				local pasos = math.max(1, math.ceil(total * 40)) -- pasos de 1/40 s como mucho
				l.espera = 0
				for _ = 1, pasos do
					simular(l, total / pasos, viento) -- solo la agita un ruido (suena), nunca el viento
				end
				colocar(l, ahora, viento)
			end
		end)
	end)
end

return LatasVista
