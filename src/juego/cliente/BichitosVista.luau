-- Bichitos (pedido por el usuario: "mejorar la inmersión, que haya cosas así"): ratas que huyen de la linterna,
-- cucarachas en la cocina, polillas en las bombillas y moscas en la sangre. Todo del cliente, de adorno, y solo cerca de
-- la cámara (Config.Bichitos.Cerca). Detalle en docs/sistemas/bichitos.md.
--   Ratas (sótano, desván, trastero y garaje; las salas, como rectángulos en Config.Bichitos.Salas): 2-4 por sala,
--     hechas de piezas (cuerpo, cabeza, orejas, patas que trotan y cola que se menea). Husmean y pasean un poco; si las
--     alumbras con la linterna o te acercas, huyen pegadas a la pared hasta un rincón (con su agujerito en la pared) o se
--     meten bajo el primer mueble con el que se topan, y al rato vuelven a salir. Con un bicho cerca
--     (workspace.Bichos), todas se esconden sin un ruido y no salen hasta que se va: es un aviso.
--   Cucarachas (cocina): quietas por el suelo; al darles la luz, corren a la pared más cercana y se meten.
--   Polillas: alrededor de cada bombilla encendida (las "Lampara" con su PointLight, como DetallesVista), dando vueltas
--     y dándose contra ella de vez en cuando (la receta de GasolineraVista, en el lobby). De noche y fuera de casa, con
--     la linterna encendida, de vez en cuando acude una a la luz, revolotea delante, se da contra el cristal y se va.
--   Moscas: sobre los charcos de sangre (etiqueta "Charco": MuerteVista y el susto Goteo), una nubecilla que llega a los
--     pocos segundos; alguna se posa a ratos.
-- Ratas y cucarachas andan sobre el suelo de verdad (un rayo hacia abajo en cada paso) y no atraviesan paredes ni
-- muebles (un rayo por delante con MuebleRayo, que ve también las cajas Choque de los muebles).
-- Con Rendimiento: una rata por sala y una polilla por bombilla; ni cucarachas, ni moscas, ni la polilla de la linterna.
-- Un repaso cada Config.Bichitos.Cada segundos decide qué hay cerca; el Heartbeat que lo anima solo está conectado
-- mientras haya algo que animar.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ambiente = require(script.Parent.Ambiente)
local MuebleRayo = require(script.Parent.MuebleRayo)
local Sonido = require(script.Parent.Sonido)

local BichitosVista = {}

local CFG = Config.Bichitos
local jugador = Players.LocalPlayer
local azar = Random.new()

-- Números de esta vista, a ojo (los que se tocan para ajustar están en Config.Bichitos).
local PELO = Color3.fromRGB(54, 47, 42)
local PIEL = Color3.fromRGB(146, 104, 98) -- orejas, patas, cola y hocico
local NEGRO = Color3.fromRGB(8, 7, 7)
local CUCARACHA = Color3.fromRGB(56, 30, 16)
local MOSCA = Color3.fromRGB(14, 14, 12)
local AGUJERO = Color3.fromRGB(5, 4, 4)
local CHOQUE = 0.3 -- segundos de una polilla que se da contra la luz (ida y vuelta), como en el lobby
local DENTRO = 0.6 -- studs que se separan los caminos y los rincones de los lados del rectángulo de la sala
local ALTO_RAYO = 0.2 -- studs sobre el suelo del rayo que mira por delante (por debajo de los tableros)
local CAJAS_CADA = 10 -- segundos: las cajas de los muebles de una sala se vuelven a juntar así de a menudo
local ENTRE_CHILLIDOS = 0.6
local GIROS = { 0, math.rad(35), -math.rad(35), math.rad(70), -math.rad(70) } -- si no puede seguir recto
local COLA = 6 -- trozos de la cola
local LARGO_COLA = 0.24
-- Patas de la rata: x, z y desfase del trote (en diagonal: la delantera izquierda con la trasera derecha).
local PATAS = { { -0.15, -0.3, 0 }, { 0.15, -0.3, math.pi }, { -0.16, 0.3, math.pi }, { 0.16, 0.3, 0 } }
-- Patas de la cucaracha: lado, z y desfase (de tres en tres, como un trípode).
local PATAS_CUCARACHA = {
	{ -1, -0.08, 0 }, { 1, 0, 0 }, { -1, 0.08, 0 },
	{ 1, -0.08, math.pi }, { -1, 0, math.pi }, { 1, 0.08, math.pi },
}

local function entre(par: { number }): number
	return azar:NextNumber(par[1], par[2])
end

local function plano(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function rendimiento(): boolean
	return jugador:GetAttribute("Rendimiento") == true -- se lee cada vez: cambia en marcha
end

local carpeta: Folder? = nil
-- Donde van las piezas de esta vista: solo existen en este cliente.
local function carpetaVista(): Folder
	local c = carpeta
	if not c or not c.Parent then
		local nueva = Instance.new("Folder")
		nueva.Name = "Bichitos"
		nueva.Parent = workspace
		carpeta = nueva
		return nueva
	end
	return c
end

-- Una pieza de adorno: anclada, sin chocar, sin tapar rayos ni tocar y sin sombra. Con `bola`, una esfera estirada
-- (SpecialMesh) del tamaño de la pieza.
local function pieza(nombre: string, tamano: Vector3, color: Color3, bola: boolean?, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = nombre
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = tamano
	p.Color = color
	if bola then
		local malla = Instance.new("SpecialMesh")
		malla.MeshType = Enum.MeshType.Sphere
		malla.Parent = p
	end
	p.Parent = carpetaVista()
	return p
end

-- Rayos: no ven estas piezas, a los jugadores ni a los bichos (las ratas no se paran en tus pies).
local filtro = RaycastParams.new()
filtro.FilterType = Enum.RaycastFilterType.Exclude
filtro.IgnoreWater = true
local function ponerFiltro()
	local fuera: { Instance } = { carpetaVista() }
	for _, otro in Players:GetPlayers() do
		if otro.Character then
			table.insert(fuera, otro.Character)
		end
	end
	local bichos = workspace:FindFirstChild("Bichos")
	if bichos then
		table.insert(fuera, bichos)
	end
	filtro.FilterDescendantsInstances = fuera
end

-- El suelo de verdad bajo (x, z), mirando desde `alto` studs por encima de `y`: su altura, o nil si no hay o está a
-- más de Desnivel de `y` (un hueco, la escalera, un mueble que sí ven los rayos).
local function suelo(x: number, z: number, y: number, alto: number): number?
	local r = workspace:Raycast(Vector3.new(x, y + alto, z), Vector3.new(0, -alto - CFG.Desnivel - 0.5, 0), filtro)
	if r and r.Normal.Y > 0.7 and math.abs(r.Position.Y - y) <= CFG.Desnivel then
		return r.Position.Y
	end
	return nil
end

-- Un ángulo `a` acercado a `b` como mucho `paso` radianes (por el lado corto).
local function acercarAngulo(a: number, b: number, paso: number): number
	local d = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + math.clamp(d, -paso, paso)
end

local function girar(dir: Vector3, a: number): Vector3
	local c, s = math.cos(a), math.sin(a)
	return Vector3.new(dir.X * c - dir.Z * s, 0, dir.X * s + dir.Z * c)
end

-- Si `punto` está en el cono de una linterna que sale de `vista` (sin mirar paredes).
function BichitosVista.enElCono(vista: CFrame, punto: Vector3, alcance: number, angulo: number): boolean
	local d = punto - vista.Position
	local dist = d.Magnitude
	if dist < 1e-3 then
		return true
	end
	return dist <= alcance and vista.LookVector:Dot(d / dist) >= math.cos(math.rad(angulo))
end

-- Lo más cerca de `p` (en planta) que hay del rectángulo de la sala, y si `p` está entre su suelo y su techo.
function BichitosVista.distanciaSala(datos: any, p: Vector3): (number, boolean)
	local dx = math.max(datos.x1 - p.X, 0, p.X - datos.x2)
	local dz = math.max(datos.z1 - p.Z, 0, p.Z - datos.z2)
	return math.sqrt(dx * dx + dz * dz), p.Y >= datos.Suelo - 3 and p.Y <= datos.Suelo + datos.Alto
end

---------------------------------------------------------------- ratas y cucarachas

type Hueco = { pos: Vector3, x: number, z: number } -- dónde se mete la rata y el rincón (x, z) del que es
type Sala = {
	datos: any,
	viva: boolean,
	bichos: { Bichito },
	huecos: { Hueco },
	agujeros: { BasePart },
	cajas: { MuebleRayo.Caja },
	cajasHasta: number,
	bicho: Vector3?, -- un bicho cerca de la sala (todas escondidas mientras siga)
}
type Bichito = {
	rata: boolean,
	datos: any,
	sala: Sala,
	partes: { BasePart },
	transparencia: { number },
	cfs: { CFrame },
	pos: Vector3, -- en el suelo
	yaw: number,
	vel: number,
	estado: string, -- "quieta", "anda", "huye" o "fuera" (escondida)
	hasta: number, -- quieta: hasta cuándo; fuera: cuándo vuelve a salir
	camino: { Vector3 },
	fase: number, -- del trote
	semilla: number,
	tam: number,
	visible: boolean,
}

local salas: { Sala } = {}
for _, datos in CFG.Salas do
	table.insert(salas, {
		datos = datos,
		viva = false,
		bichos = {},
		huecos = {},
		agujeros = {},
		cajas = {},
		cajasHasta = 0,
		bicho = nil,
	})
end

local function crearRata(tam: number): { BasePart }
	local s = tam
	local partes = {
		pieza("Cuerpo", Vector3.new(0.5, 0.4, 1) * s, PELO, true, Enum.Material.Fabric),
		pieza("Cabeza", Vector3.new(0.3, 0.26, 0.44) * s, PELO, true, Enum.Material.Fabric),
		pieza("Hocico", Vector3.new(0.08, 0.07, 0.08) * s, PIEL, true),
		pieza("Ojo", Vector3.new(0.05, 0.05, 0.05) * s, NEGRO, true),
		pieza("Ojo", Vector3.new(0.05, 0.05, 0.05) * s, NEGRO, true),
		pieza("Oreja", Vector3.new(0.17, 0.17, 0.03) * s, PIEL, true),
		pieza("Oreja", Vector3.new(0.17, 0.17, 0.03) * s, PIEL, true),
	}
	partes[4].Reflectance, partes[5].Reflectance = 0.35, 0.35 -- un brillito en los ojos con la linterna
	partes[1].CastShadow = true -- la sombra de la rata en el haz (las piezas pequeñas, sin)
	for _ = 1, 4 do
		table.insert(partes, pieza("Pata", Vector3.new(0.08, 0.14, 0.11) * s, PIEL))
	end
	for i = 1, COLA do
		local grueso = (0.07 - 0.009 * i) * s
		table.insert(partes, pieza("Cola", Vector3.new(grueso, grueso, LARGO_COLA * s + 0.02), PIEL))
	end
	return partes
end

local function crearCucaracha(tam: number): { BasePart }
	local s = tam
	local partes = {
		pieza("Cuerpo", Vector3.new(0.2, 0.07, 0.32) * s, CUCARACHA, true),
		pieza("Cabeza", Vector3.new(0.1, 0.05, 0.08) * s, CUCARACHA, true),
		pieza("Antena", Vector3.new(0.012, 0.012, 0.28) * s, CUCARACHA),
		pieza("Antena", Vector3.new(0.012, 0.012, 0.28) * s, CUCARACHA),
	}
	partes[1].Reflectance = 0.25 -- caparazón que brilla con la luz
	for _ = 1, #PATAS_CUCARACHA do
		table.insert(partes, pieza("Pata", Vector3.new(0.014, 0.014, 0.12) * s, CUCARACHA))
	end
	return partes
end

local function verBichito(b: Bichito, visible: boolean)
	if b.visible == visible then
		return
	end
	b.visible = visible
	for i, p in b.partes do
		p.Transparency = if visible then b.transparencia[i] else 1
	end
end

-- La pose de la rata en este momento (cuerpo que bota al trotar, cabeza que husmea, patas y cola).
local function poseRata(b: Bichito, ahora: number)
	local s, cfs = b.tam, b.cfs
	local k = math.clamp(b.vel / b.datos.Huye, 0, 1) -- 0 quieta, 1 a toda velocidad
	local trota = math.clamp(b.vel / b.datos.Anda, 0, 1)
	local f = b.fase
	local raiz = CFrame.new(b.pos) * CFrame.Angles(0, b.yaw, 0)
	local bote = math.abs(math.sin(f)) * 0.05 * s * trota
	-- Corriendo va más pegada al suelo.
	local cuerpo = raiz * CFrame.new(0, (0.28 - 0.05 * k) * s + bote, 0) * CFrame.Angles(math.sin(2 * f) * 0.05 * trota, 0, 0)
	cfs[1] = cuerpo
	local husmea = if b.estado == "quieta" then 1 else 0
	local giro = math.noise(b.semilla, ahora * 0.9) * 0.6 * husmea
	local cabeceo = -0.15 + math.sin(ahora * 17 + b.semilla) * 0.07 * husmea + 0.12 * k
	local cuello = cuerpo * CFrame.new(0, 0.02 * s, -0.42 * s) * CFrame.Angles(cabeceo, giro, 0)
	cfs[2] = cuello * CFrame.new(0, 0, -0.18 * s)
	cfs[3] = cuello * CFrame.new(0, -0.03 * s, -0.4 * s)
	cfs[4] = cuello * CFrame.new(-0.09 * s, 0.07 * s, -0.25 * s)
	cfs[5] = cuello * CFrame.new(0.09 * s, 0.07 * s, -0.25 * s)
	local orejas = 0.25 * k -- echadas hacia atrás al huir
	cfs[6] = cuello * CFrame.new(-0.11 * s, 0.14 * s, -0.05 * s) * CFrame.Angles(orejas, -0.35, 0)
	cfs[7] = cuello * CFrame.new(0.11 * s, 0.14 * s, -0.05 * s) * CFrame.Angles(orejas, 0.35, 0)
	for i, p in PATAS do
		local a = f + p[3]
		local adelante = math.sin(a) * 0.13 * s * trota
		local sube = math.max(0, math.cos(a)) * 0.07 * s * trota
		cfs[7 + i] = raiz * CFrame.new(p[1] * s, 0.07 * s + sube, p[2] * s + adelante)
	end
	-- La cola: cae hasta el suelo desde el lomo y se menea (más despacio y más abierta quieta; casi recta huyendo).
	local abre = 0.22 + 0.2 * husmea - 0.12 * k
	local cf = cuerpo * CFrame.new(0, -0.06 * s, 0.47 * s)
	for i = 1, COLA do
		local lado = math.sin(ahora * (3 + 6 * k) - i * 0.7 + b.semilla) * abre
		cf = cf * CFrame.Angles(if i == 1 then 0.3 else -0.06, lado, 0)
		cfs[7 + #PATAS + i] = cf * CFrame.new(0, 0, LARGO_COLA * s / 2)
		cf = cf * CFrame.new(0, 0, LARGO_COLA * s)
	end
end

local function poseCucaracha(b: Bichito, ahora: number)
	local s, cfs = b.tam, b.cfs
	local trota = math.clamp(b.vel / b.datos.Anda, 0, 1)
	local raiz = CFrame.new(b.pos) * CFrame.Angles(0, b.yaw, 0)
	local cuerpo = raiz * CFrame.new(0, 0.05 * s, 0)
	cfs[1] = cuerpo
	cfs[2] = cuerpo * CFrame.new(0, 0, -0.19 * s)
	for i, lado in { -1, 1 } do
		-- Las antenas no paran quietas.
		local mueve = math.noise(b.semilla + i * 5.1, ahora * 2.5) * 0.5
		cfs[2 + i] = cuerpo * CFrame.new(lado * 0.025 * s, 0.01 * s, -0.22 * s)
			* CFrame.Angles(-0.12 + math.sin(ahora * 9 + i) * 0.1, -lado * 0.35 + mueve, 0) * CFrame.new(0, 0, -0.14 * s)
	end
	for i, p in PATAS_CUCARACHA do
		local barre = math.sin(b.fase + p[3]) * 0.6 * trota
		cfs[4 + i] = cuerpo * CFrame.new(p[1] * 0.08 * s, -0.02 * s, p[2] * s)
			* CFrame.Angles(0, -p[1] * math.pi / 2 + barre, 0) * CFrame.new(0, 0, -0.06 * s)
	end
end

-- Un punto del suelo de la sala, al azar (nil si no lo encuentra: muebles que ven los rayos, huecos).
local function puntoSuelo(sala: Sala): Vector3?
	local d = sala.datos
	for _ = 1, 8 do
		local x = azar:NextNumber(d.x1 + DENTRO, d.x2 - DENTRO)
		local z = azar:NextNumber(d.z1 + DENTRO, d.z2 - DENTRO)
		local y = suelo(x, z, d.Suelo, 2.5)
		if y then
			local p = Vector3.new(x, y, z)
			-- Que no salga metida en un armario (las cajas Choque no las ven los rayos normales) ni dentro de algo que sí
			-- ven (el suelo de un coche, un cajón).
			if not MuebleRayo.choca(CFrame.new(p + Vector3.new(0, 0.25, 0)), Vector3.new(0.3, 0.2, 0.5), sala.cajas)
				and not workspace:Raycast(p + Vector3.new(0, 0.05, 0), Vector3.new(0, 1, 0), filtro) then
				return p
			end
		end
	end
	return nil
end

local ultimoChillido = -math.huge
local function chillar(donde: Vector3)
	local ahora = os.clock()
	if ahora - ultimoChillido < ENTRE_CHILLIDOS then
		return
	end
	ultimoChillido = ahora
	if Sonido.hay("RataChillido") then
		Sonido.en("RataChillido", donde, azar:NextNumber(0.94, 1.08))
	else
		local s = Sonido.en("Cruje", donde, entre(CFG.Rata.Tono))
		s.Volume *= CFG.Rata.Volumen
	end
	if Sonido.hay("RataPatas") then
		Sonido.en("RataPatas", donde, azar:NextNumber(0.95, 1.05))
	end
end

-- El hueco por el que se mete: el rincón más lejos de `de` (lo que la asusta) sin pasar por su lado. El camino va
-- primero a la pared del rincón más cercana y luego, pegado a ella, hasta el rincón.
local function caminoRata(b: Bichito, de: Vector3): { Vector3 }
	local sala, pos = b.sala, b.pos
	local mejor: Hueco? = nil
	local puntos = -math.huge
	local haciaDe = plano(de - pos)
	haciaDe = if haciaDe.Magnitude > 1e-3 then haciaDe.Unit else Vector3.zero
	for _, h in sala.huecos do
		local haciaH = plano(h.pos - pos)
		local largo = haciaH.Magnitude
		local castigo = if largo > 1e-3 then math.max(0, (haciaH / largo):Dot(haciaDe)) * 15 else 0
		local p = plano(h.pos - de).Magnitude - largo * 0.6 - castigo
		if p > puntos then
			mejor, puntos = h, p
		end
	end
	if not mejor then
		return {}
	end
	local h = mejor
	local camino = {}
	if math.abs(pos.X - h.x) < math.abs(pos.Z - h.z) then
		if math.abs(pos.X - h.x) > 0.4 then
			table.insert(camino, Vector3.new(h.x, pos.Y, pos.Z)) -- a la pared de ese lado (x)...
		end
	elseif math.abs(pos.Z - h.z) > 0.4 then
		table.insert(camino, Vector3.new(pos.X, pos.Y, h.z)) -- ...o a la de z
	end
	table.insert(camino, h.pos)
	return camino
end

-- La cucaracha corre a la pared más cercana (a la sombra del zócalo) y se mete.
local function caminoCucaracha(b: Bichito): { Vector3 }
	local d, p = b.sala.datos, b.pos
	local x1, x2, z1, z2 = d.x1 + DENTRO, d.x2 - DENTRO, d.z1 + DENTRO, d.z2 - DENTRO
	local opciones = {
		{ p.X - x1, Vector3.new(x1, p.Y, p.Z) },
		{ x2 - p.X, Vector3.new(x2, p.Y, p.Z) },
		{ p.Z - z1, Vector3.new(p.X, p.Y, z1) },
		{ z2 - p.Z, Vector3.new(p.X, p.Y, z2) },
	}
	table.sort(opciones, function(a, c)
		return a[1] < c[1]
	end)
	return { opciones[1][2] }
end

local function huir(b: Bichito, de: Vector3, chilla: boolean)
	if b.estado == "huye" or b.estado == "fuera" then
		return
	end
	b.camino = if b.rata then caminoRata(b, de) else caminoCucaracha(b)
	b.estado = "huye"
	b.hasta = os.clock() + 4 -- como mucho: luego se mete donde esté
	if chilla and b.rata and azar:NextNumber() < 0.7 then
		chillar(b.pos)
	end
end

local function esconder(b: Bichito, ahora: number)
	b.estado = "fuera"
	b.vel = 0
	b.hasta = ahora + entre(b.datos.Vuelve)
	table.clear(b.camino)
	verBichito(b, false)
end

local function quieta(b: Bichito, ahora: number)
	b.estado = "quieta"
	b.hasta = ahora + entre(b.datos.Pausa)
	table.clear(b.camino)
end

-- Un paseo corto (hacia el centro de la sala si `centro`, al salir del escondite).
local function pasear(b: Bichito, ahora: number, centro: boolean?)
	local d = b.sala.datos
	local dir
	if centro then
		local medio = Vector3.new((d.x1 + d.x2) / 2, b.pos.Y, (d.z1 + d.z2) / 2)
		dir = plano(medio - b.pos)
		dir = if dir.Magnitude > 1e-3 then girar(dir.Unit, azar:NextNumber(-0.5, 0.5)) else Vector3.xAxis
	else
		local a = azar:NextNumber(0, 2 * math.pi)
		dir = Vector3.new(math.cos(a), 0, math.sin(a))
	end
	local largo = entre(b.datos.Paseo) * (if centro then 1.5 else 1)
	local x = math.clamp(b.pos.X + dir.X * largo, d.x1 + DENTRO, d.x2 - DENTRO)
	local z = math.clamp(b.pos.Z + dir.Z * largo, d.z1 + DENTRO, d.z2 - DENTRO)
	b.camino = { Vector3.new(x, b.pos.Y, z) }
	b.estado = "anda"
	b.hasta = ahora + 8 -- como mucho: luego se para donde esté
end

local function nuevoBichito(sala: Sala, rata: boolean, ahora: number): Bichito?
	local donde = puntoSuelo(sala)
	if not donde then
		return nil
	end
	local datos = if rata then CFG.Rata else CFG.Cucaracha
	local tam = entre(datos.Tam)
	local partes = if rata then crearRata(tam) else crearCucaracha(tam)
	local transparencia, cfs = {}, {}
	for i, p in partes do
		transparencia[i] = p.Transparency
		cfs[i] = CFrame.new(donde)
	end
	local b: Bichito = {
		rata = rata,
		datos = datos,
		sala = sala,
		partes = partes,
		transparencia = transparencia,
		cfs = cfs,
		pos = donde,
		yaw = azar:NextNumber(-math.pi, math.pi),
		vel = 0,
		estado = "quieta",
		hasta = ahora + entre(datos.Pausa),
		camino = {},
		fase = azar:NextNumber(0, 2 * math.pi),
		semilla = azar:NextNumber(0, 1000),
		tam = tam,
		visible = true,
	}
	-- Algunas empiezan escondidas y salen al poco (que no estén siempre todas a la vista al llegar).
	if azar:NextNumber() < 0.3 then
		local h = if rata and #sala.huecos > 0 then sala.huecos[azar:NextInteger(1, #sala.huecos)] else nil
		if h then
			b.pos = h.pos
		end
		esconder(b, ahora)
		b.hasta = ahora + azar:NextNumber(2, 12)
	end
	return b
end

-- Los rincones de la sala; si hay pared al lado (un rayo a cada lado), el rincón se pega a ella y lleva un agujerito
-- oscuro en el zócalo (media esfera aplastada contra la pared, con la mitad de abajo bajo el suelo).
local function hacerHuecos(sala: Sala)
	local d = sala.datos
	for _, esquina in { { d.x1, d.z1, -1, -1 }, { d.x2, d.z1, 1, -1 }, { d.x1, d.z2, -1, 1 }, { d.x2, d.z2, 1, 1 } } do
		local x, z = esquina[1] - esquina[3] * DENTRO, esquina[2] - esquina[4] * DENTRO
		local y = suelo(x, z, d.Suelo, 2.5) or d.Suelo
		local pos = Vector3.new(x, y, z)
		for _, hacia in { Vector3.new(esquina[3], 0, 0), Vector3.new(0, 0, esquina[4]) } do
			local desde = pos + Vector3.new(0, 0.25, 0) - hacia * 0.6
			local r = workspace:Raycast(desde, hacia * 2.2, filtro)
			if r and math.abs(r.Normal.Y) < 0.3 then
				local agujero = pieza("Agujero", Vector3.new(0.04, 0.5, 0.42), AGUJERO, true)
				local n = plano(r.Normal).Unit
				agujero.CFrame = CFrame.fromMatrix(Vector3.new(r.Position.X, y, r.Position.Z) + n * 0.015, n, Vector3.yAxis)
				table.insert(sala.agujeros, agujero)
				-- La rata se mete justo delante del agujero.
				pos = Vector3.new(r.Position.X, y, r.Position.Z) + n * 0.45
				break
			end
		end
		table.insert(sala.huecos, { pos = pos, x = x, z = z })
	end
end

local function nacerSala(sala: Sala, ahora: number, poco: boolean)
	local d = sala.datos
	sala.viva = true
	sala.cajas = MuebleRayo.cajas(Vector3.new((d.x1 + d.x2) / 2, d.Suelo + 1, (d.z1 + d.z2) / 2),
		Vector3.new(d.x2 - d.x1, 0, d.z2 - d.z1).Magnitude / 2 + 2)
	sala.cajasHasta = ahora + CAJAS_CADA
	local rata = d.Ratas ~= nil
	if rata then
		hacerHuecos(sala)
	end
	local cuantos = 0
	if rata then
		cuantos = if poco then CFG.Rendimiento.Ratas else azar:NextInteger(d.Ratas[1], d.Ratas[2])
	elseif d.Cucarachas and not poco then
		cuantos = azar:NextInteger(d.Cucarachas[1], d.Cucarachas[2])
	end
	for _ = 1, cuantos do
		local b = nuevoBichito(sala, rata, ahora)
		if b then
			table.insert(sala.bichos, b)
		end
	end
end

local function morirSala(sala: Sala)
	sala.viva = false
	for _, b in sala.bichos do
		for _, p in b.partes do
			p:Destroy()
		end
	end
	for _, p in sala.agujeros do
		p:Destroy()
	end
	table.clear(sala.bichos)
	table.clear(sala.agujeros)
	table.clear(sala.huecos)
	sala.cajas = {}
	sala.bicho = nil
end

-- Lo que mide del centro a la punta del hocico (o de la cabeza, la cucaracha): lo que se mira por delante.
local function hocico(b: Bichito): number
	return (if b.rata then 0.95 else 0.25) * b.tam
end

-- Si desde `pos`, mirando a `frente`, el hocico se mete en una pared o un mueble.
local function topa(b: Bichito, pos: Vector3, frente: Vector3, extra: number): boolean
	local origen = pos + Vector3.new(0, ALTO_RAYO * b.tam, 0)
	return MuebleRayo.rayo(origen, frente * (hocico(b) + extra), filtro, b.sala.cajas) ~= nil
end

-- Un paso de `paso` studs mirando a `frente` sin meterse en paredes ni muebles: la dirección que vale (recto o un poco
-- girado, para rodear; el hocico, que sigue mirando a `frente`, tampoco puede quedar dentro) o nil si no puede.
local function buscarPaso(b: Bichito, frente: Vector3, paso: number): Vector3?
	for _, a in GIROS do
		local d = if a == 0 then frente else girar(frente, a)
		if not topa(b, b.pos, d, paso) and (a == 0 or not topa(b, b.pos + d * paso, frente, 0)) then
			return d
		end
	end
	return nil
end

local function moverBichito(b: Bichito, dt: number, ahora: number)
	local huye = b.estado == "huye"
	if b.estado ~= "anda" and not huye then
		b.vel = math.max(0, b.vel - dt * 25)
		if b.estado == "quieta" and ahora >= b.hasta then
			pasear(b, ahora)
		end
		return
	end
	-- Pared, mueble o se acaba el suelo. Huyendo: si es la pared a la que iba, sigue pegada a ella hacia el rincón; si
	-- no, se mete ahí (bajo el mueble, tras el armario). Andando, se para.
	local function atascada()
		if huye and #b.camino > 1 then
			table.remove(b.camino, 1)
		elseif huye then
			esconder(b, ahora)
		else
			quieta(b, ahora)
		end
	end
	local destino = b.camino[1]
	if not destino or ahora >= b.hasta then
		-- Llegó o se le acabó el tiempo (por si se queda girando contra algo).
		if huye then
			esconder(b, ahora)
		else
			quieta(b, ahora)
		end
		return
	end
	local hacia = plano(destino - b.pos)
	local dist = hacia.Magnitude
	if dist < 0.15 then
		table.remove(b.camino, 1)
		return
	end
	local dir = hacia / dist
	local objetivo = if huye then b.datos.Huye else b.datos.Anda
	b.vel += (objetivo - b.vel) * math.min(1, dt * (if huye then 14 else 5))
	-- Avanza hacia donde mira (girando deprisa): con el destino muy de lado, primero gira en el sitio.
	local quiere = math.atan2(-dir.X, -dir.Z)
	local antes = b.yaw
	b.yaw = acercarAngulo(b.yaw, quiere, dt * (if huye then 20 else 7))
	local function frenteDe(yaw: number): Vector3
		return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
	end
	-- Que al girar no meta el hocico en la pared (si ya lo tenía pegado, sí puede girar para sacarlo).
	if topa(b, b.pos, frenteDe(b.yaw), 0) and not topa(b, b.pos, frenteDe(antes), 0) then
		b.yaw = antes
		atascada()
		return
	end
	local falta = math.abs((quiere - b.yaw + math.pi) % (2 * math.pi) - math.pi)
	local paso = if falta > 1.2 then 0 else math.min(dist, b.vel * dt)
	if paso <= 0 then
		return
	end
	local libre = buscarPaso(b, frenteDe(b.yaw), paso)
	local nueva = if libre then b.pos + libre * paso else nil
	local y = if nueva then suelo(nueva.X, nueva.Z, b.pos.Y, 0.8) else nil
	if not nueva or not y then
		atascada()
		return
	end
	b.pos = Vector3.new(nueva.X, y, nueva.Z)
	b.fase += paso * (if b.rata then 9 else 30) -- radianes de trote por stud
end

-- Qué la asusta ahora: tu linterna encima, tú (o otro jugador) demasiado cerca. Devuelve de dónde huye, o nil.
local function susto(b: Bichito, vista: CFrame, linterna: boolean, cuerpos: { Vector3 }): Vector3?
	local cam = vista.Position
	local datos = b.datos
	local centro = b.pos + Vector3.new(0, 0.15, 0)
	if math.abs(cam.Y - b.pos.Y) < 8 and plano(cam - b.pos).Magnitude < datos.Susto then
		return cam
	end
	for _, c in cuerpos do
		if math.abs(c.Y - b.pos.Y) < 6 and plano(c - b.pos).Magnitude < datos.Susto then
			return c
		end
	end
	if linterna and BichitosVista.enElCono(vista, centro, datos.Luz, datos.Angulo) then
		local d = centro - cam
		if d.Magnitude < 0.5 or not workspace:Raycast(cam, d - d.Unit * 0.3, filtro) then
			return cam
		end
	end
	return nil
end

-- Si puede volver a salir: ni bicho, ni tú encima, ni la linterna apuntando al escondite.
local function puedeVolver(b: Bichito, vista: CFrame, linterna: boolean, cuerpos: { Vector3 }): boolean
	if b.sala.bicho then
		return false
	end
	local cam = vista.Position
	if plano(cam - b.pos).Magnitude < b.datos.Susto * 1.5 and math.abs(cam.Y - b.pos.Y) < 8 then
		return false
	end
	for _, c in cuerpos do
		if plano(c - b.pos).Magnitude < b.datos.Susto * 1.5 and math.abs(c.Y - b.pos.Y) < 6 then
			return false
		end
	end
	return not (linterna and BichitosVista.enElCono(vista, b.pos, b.datos.Luz, b.datos.Angulo))
end

---------------------------------------------------------------- polillas

type Polilla = {
	pieza: BasePart,
	centro: Vector3,
	toque: Vector3,
	radio: number,
	vel: number,
	fase: number,
	alto: number,
	frec: number,
	semilla: number,
	choque: number?, -- cuándo empezó a ir contra la luz
	proximo: number, -- cuándo vuelve a ir
	antes: Vector3,
}
type Bombilla = { luz: PointLight, pieza: BasePart, polillas: { Polilla } }
local bombillas: { [PointLight]: Bombilla } = {}

-- Mirando hacia `dir` desde `pos` (sin CFrame.lookAt, que en Lune sale al revés en z).
local function mirando(pos: Vector3, dir: Vector3): CFrame
	if dir.Magnitude < 1e-4 then
		return CFrame.new(pos)
	end
	local f = dir.Unit
	if math.abs(f.Y) > 0.98 then
		return CFrame.new(pos)
	end
	local derecha = f:Cross(Vector3.yAxis).Unit
	return CFrame.fromMatrix(pos, derecha, derecha:Cross(f), -f)
end

local function nuevaPolilla(centro: Vector3, toque: Vector3, ahora: number): Polilla
	local gris = azar:NextNumber(0.75, 1.1)
	local p = pieza("Polilla", Vector3.new(0.16, 0.03, 0.1) * azar:NextNumber(0.8, 1.25),
		Color3.fromRGB(122 * gris, 114 * gris, 100 * gris))
	p.CFrame = CFrame.new(centro)
	return {
		pieza = p,
		centro = centro,
		toque = toque,
		radio = azar:NextNumber(0.5, 1.2),
		vel = azar:NextNumber(2.2, 5) * (if azar:NextNumber() < 0.5 then -1 else 1),
		fase = azar:NextNumber(0, 2 * math.pi),
		alto = azar:NextNumber(0.15, 0.45),
		frec = azar:NextNumber(1.5, 3.5),
		semilla = azar:NextNumber(0, 1000),
		choque = nil,
		proximo = ahora + azar:NextNumber(0.8, 4),
		antes = centro,
	}
end

local function crearPolillas(b: Bombilla, ahora: number, cuantas: number)
	local cf, medio = b.pieza.CFrame, b.pieza.Size / 2
	for _ = 1, cuantas do
		-- Un poco por debajo de la bombilla (cuelgan del techo); el golpe, en el punto de la bombilla más cercano.
		local centro = cf * Vector3.new(azar:NextNumber(-0.9, 0.9) * medio.X, azar:NextNumber(-0.9, 0.9) * medio.Y,
			azar:NextNumber(-0.9, 0.9) * medio.Z) - Vector3.new(0, 0.45, 0)
		local rel = cf:PointToObjectSpace(centro)
		local toque = cf * Vector3.new(math.clamp(rel.X, -medio.X, medio.X), math.clamp(rel.Y, -medio.Y, medio.Y),
			math.clamp(rel.Z, -medio.Z, medio.Z))
		table.insert(b.polillas, nuevaPolilla(centro, toque, ahora))
	end
end

local function borrarPolillas(lista: { Polilla })
	for _, m in lista do
		m.pieza:Destroy()
	end
	table.clear(lista)
end

-- Vueltas raras alrededor del centro (con ruido) y, de vez en cuando, un golpe contra la luz.
local function vueltaPolilla(m: Polilla, ahora: number): Vector3
	local a = m.fase + m.vel * ahora + 1.6 * math.noise(m.semilla, ahora * 0.6)
	local r = m.radio * (0.75 + 0.6 * math.noise(m.semilla + 7.3, ahora * 1.1))
	local y = m.alto * math.sin(m.frec * ahora + m.fase) + 0.35 * math.noise(m.semilla + 3.1, ahora * 1.7)
	local pos = m.centro + Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
	local choque = m.choque
	if choque then
		local u = (ahora - choque) / CHOQUE
		if u >= 1 then
			m.choque = nil
			m.proximo = ahora + azar:NextNumber(0.8, 4)
		else
			pos = pos:Lerp(m.toque, math.sin(math.pi * u) * 0.95)
		end
	elseif ahora >= m.proximo then
		m.choque = ahora
	end
	return pos
end

local function ponerPolilla(m: Polilla, pos: Vector3, ahora: number)
	local dir = pos - m.antes
	m.antes = pos
	m.pieza.CFrame = mirando(pos, dir) * CFrame.Angles(0, 0, math.sin(ahora * 46 + m.fase) * 0.8) -- aleteo
end

local function apuntarBombilla(luz: Instance)
	if not luz:IsA("PointLight") or bombillas[luz] then
		return
	end
	local p = luz.Parent
	if not p or p.Name ~= "Lampara" or not p:IsA("BasePart") then
		return
	end
	bombillas[luz] = { luz = luz, pieza = p, polillas = {} }
	luz.Destroying:Once(function()
		local b = bombillas[luz]
		if b then
			bombillas[luz] = nil
			borrarPolillas(b.polillas)
		end
	end)
end

-- La de tu linterna, de noche fuera: llega desde la oscuridad, revolotea delante, se da contra el cristal y se va.
type Visita = { m: Polilla, llega: number, sale: number, desde: Vector3, hacia: Vector3?, ultima: Vector3 }
local visita: Visita? = nil
local proximaVisita = 0

local function dentroDeCasa(p: Vector3): boolean
	local C = Config.Casa
	if math.abs(p.X) < C.MedioX and math.abs(p.Z) < C.MedioZ and p.Y < 45 then
		return true
	end
	for _, a in C.Anexos do
		if p.X > a[1] and p.X < a[2] and p.Z > a[3] and p.Z < a[4] and p.Y < 45 then
			return true
		end
	end
	for _, s in CFG.Salas do
		local d, entra = BichitosVista.distanciaSala(s, p)
		if d == 0 and entra then
			return true
		end
	end
	return false
end

local function moverVisita(v: Visita, vista: CFrame, ahora: number)
	local m = v.m
	local delante = vista.Position + vista.LookVector * CFG.PolillaLinterna.Delante - Vector3.new(0, 0.3, 0)
	m.centro = delante
	-- El golpe, contra la luz de la linterna (justo delante de la cámara, sin meterse en ella).
	m.toque = vista.Position + vista.LookVector * 1.2
	local pos = vueltaPolilla(m, ahora)
	local u = math.clamp((ahora - v.llega) / 1.5, 0, 1)
	pos = v.desde:Lerp(pos, u * u * (3 - 2 * u))
	local hacia = v.hacia
	if hacia then
		local w = math.clamp((ahora - v.sale) / 1.5, 0, 1)
		pos = pos:Lerp(hacia, w * w)
	end
	v.ultima = pos
	ponerPolilla(m, pos, ahora)
end

---------------------------------------------------------------- moscas

type Mosca = { pieza: BasePart, semilla: number, vel: number, posada: number, sitio: Vector3?, proxima: number }
type Charco = { charco: BasePart, desde: number, moscas: { Mosca }, zumbido: Sound?, punto: Attachment? }
local charcos: { [BasePart]: Charco } = {}

local function borrarMoscas(c: Charco)
	for _, m in c.moscas do
		m.pieza:Destroy()
	end
	table.clear(c.moscas)
	if c.punto then
		c.punto:Destroy()
		c.punto, c.zumbido = nil, nil
	end
end

local function crearMoscas(c: Charco, ahora: number)
	for _ = 1, azar:NextInteger(CFG.Moscas.Cuantas[1], CFG.Moscas.Cuantas[2]) do
		local p = pieza("Mosca", Vector3.one * azar:NextNumber(0.06, 0.085), MOSCA)
		p.Shape = Enum.PartType.Ball
		p.CFrame = CFrame.new(c.charco.Position)
		table.insert(c.moscas, {
			pieza = p,
			semilla = azar:NextNumber(0, 1000),
			vel = azar:NextNumber(1.5, 3) * (if azar:NextNumber() < 0.5 then -1 else 1),
			posada = 0,
			sitio = nil,
			proxima = ahora + azar:NextNumber(1, 6),
		})
	end
	if Sonido.hay("Moscas") then
		local punto = Instance.new("Attachment")
		punto.WorldPosition = c.charco.Position + Vector3.new(0, 0.6, 0)
		punto.Parent = workspace.Terrain
		c.punto = punto
		local s = Sonido.bucle("Moscas", punto)
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 2
		s.RollOffMaxDistance = Config.Sonidos.Moscas.Alcance
		c.zumbido = s
	end
end

-- Zumban en zigzag sobre el charco; de vez en cuando una se posa un par de segundos en la sangre.
local function moverMosca(m: Mosca, charco: BasePart, ahora: number)
	local centro = charco.Position
	local t = charco.Size
	local radio = math.clamp(math.max(t.X, t.Y, t.Z) / 2 * 0.6, 0.4, 2.2)
	if m.sitio then
		if ahora >= m.posada then
			m.sitio = nil
			m.proxima = ahora + azar:NextNumber(2, 7)
		else
			m.pieza.CFrame = CFrame.new(m.sitio)
			return
		end
	elseif ahora >= m.proxima then
		local a, r = azar:NextNumber(0, 2 * math.pi), azar:NextNumber(0, radio * 0.8)
		m.sitio = centro + Vector3.new(math.cos(a) * r, 0.05, math.sin(a) * r)
		m.posada = ahora + azar:NextNumber(1, 3)
		m.pieza.CFrame = CFrame.new(m.sitio :: Vector3)
		return
	end
	local a = m.semilla + m.vel * ahora + 3 * math.noise(m.semilla, ahora * 1.3)
	local r = radio * (0.4 + 0.6 * math.abs(math.noise(m.semilla + 4.7, ahora * 2.1)))
	local y = 0.3 + 0.9 * math.abs(math.noise(m.semilla + 9.2, ahora * 1.7))
	m.pieza.CFrame = CFrame.new(centro + Vector3.new(math.cos(a) * r, y, math.sin(a) * r))
end

---------------------------------------------------------------- bucle

local conexion: RBXScriptConnection? = nil
local avisado = false
local poneParts: { BasePart } = {}
local poneCfs: { CFrame } = {}

local function linternaEncendida(): boolean
	return jugador:GetAttribute("Linterna") == true and (jugador:GetAttribute("Pila") or 1) > 0
end

-- Los cuerpos de los demás jugadores (también asustan a las ratas). Se rehace en cada repaso.
local cuerpos: { Vector3 } = {}

local function fotograma(dt: number)
	local camara = workspace.CurrentCamera
	if not camara then
		return
	end
	local vista = camara.CFrame
	local ahora = os.clock()
	local linterna = linternaEncendida()
	dt = math.min(dt, 0.1) -- un tirón de fotogramas no las lanza por la pared
	table.clear(poneParts)
	table.clear(poneCfs)
	for _, sala in salas do
		if not sala.viva then
			continue
		end
		for _, b in sala.bichos do
			if b.estado == "fuera" then
				if ahora >= b.hasta then
					if puedeVolver(b, vista, linterna, cuerpos) then
						verBichito(b, true)
						pasear(b, ahora, true)
						-- Sale del agujero ya mirando hacia fuera.
						local hacia = b.camino[1] and plano(b.camino[1] - b.pos)
						if hacia and hacia.Magnitude > 1e-3 then
							b.yaw = math.atan2(-hacia.X, -hacia.Z)
						end
					else
						b.hasta = ahora + azar:NextNumber(2, 5)
					end
				end
				continue
			end
			if b.estado ~= "huye" then
				local de = susto(b, vista, linterna, cuerpos)
				if de then
					huir(b, de, true)
				end
			end
			moverBichito(b, dt, ahora)
			if not b.visible then
				continue -- se acaba de meter
			end
			if b.rata then
				poseRata(b, ahora)
			else
				poseCucaracha(b, ahora)
			end
			for i, p in b.partes do
				table.insert(poneParts, p)
				table.insert(poneCfs, b.cfs[i])
			end
		end
	end
	if #poneParts > 0 then
		workspace:BulkMoveTo(poneParts, poneCfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
	for luz, b in bombillas do
		-- Mientras la bombilla parpadea a oscuras (DetallesVista, Efectos), no van a por ella.
		local aOscuras = (Ambiente.factor[luz] or 1) < 0.3
		for _, m in b.polillas do
			if aOscuras and not m.choque then
				m.proximo = math.max(m.proximo, ahora + 0.4)
			end
			ponerPolilla(m, vueltaPolilla(m, ahora), ahora)
		end
	end
	local v = visita
	if v then
		moverVisita(v, vista, ahora)
	end
	for _, c in charcos do
		for _, m in c.moscas do
			moverMosca(m, c.charco, ahora)
		end
	end
end

-- Si hay algo que animar (si no, el Heartbeat se desconecta).
local function hayAlgo(): boolean
	for _, sala in salas do
		if sala.viva then
			return true
		end
	end
	for _, b in bombillas do
		if #b.polillas > 0 then
			return true
		end
	end
	if visita then
		return true
	end
	for _, c in charcos do
		if #c.moscas > 0 then
			return true
		end
	end
	return false
end

local poco: boolean? = nil

local function borrarTodo()
	for _, sala in salas do
		if sala.viva then
			morirSala(sala)
		end
	end
	for _, b in bombillas do
		borrarPolillas(b.polillas)
	end
	local v = visita
	if v then
		v.m.pieza:Destroy()
		visita = nil
	end
	for _, c in charcos do
		borrarMoscas(c)
	end
end

-- Lo que hay cerca de la cámara: salas con vida, bombillas con polillas, charcos con moscas y la polilla de la linterna.
local function repaso()
	local camara = workspace.CurrentCamera
	if not camara then
		return
	end
	local vista = camara.CFrame
	local cam = vista.Position
	local ahora = os.clock()
	local ahoraPoco = rendimiento()
	if poco ~= nil and ahoraPoco ~= poco then
		borrarTodo() -- cambió Rendimiento: todo de nuevo con lo que toca
	end
	poco = ahoraPoco
	ponerFiltro()

	table.clear(cuerpos)
	for _, otro in Players:GetPlayers() do
		local raiz = otro ~= jugador and otro.Character and otro.Character:FindFirstChild("HumanoidRootPart")
		if raiz and raiz:IsA("BasePart") then
			table.insert(cuerpos, raiz.Position)
		end
	end
	local bichos: { Vector3 } = {}
	local carpetaBichos = workspace:FindFirstChild("Bichos")
	if carpetaBichos then
		for _, modelo in carpetaBichos:GetChildren() do
			if modelo:IsA("Model") then
				local raiz = modelo:FindFirstChild("HumanoidRootPart")
				table.insert(bichos, if raiz and raiz:IsA("BasePart") then raiz.Position else modelo:GetPivot().Position)
			end
		end
	end

	for _, sala in salas do
		local d = sala.datos
		local lejos, entra = BichitosVista.distanciaSala(d, cam)
		local quiere = entra and lejos < CFG.Cerca + (if sala.viva then CFG.Margen else 0)
		if quiere and not sala.viva then
			nacerSala(sala, ahora, ahoraPoco)
		elseif sala.viva and not quiere then
			morirSala(sala)
		end
		if sala.viva then
			if ahora >= sala.cajasHasta then
				sala.cajasHasta = ahora + CAJAS_CADA
				sala.cajas = MuebleRayo.cajas(Vector3.new((d.x1 + d.x2) / 2, d.Suelo + 1, (d.z1 + d.z2) / 2),
					Vector3.new(d.x2 - d.x1, 0, d.z2 - d.z1).Magnitude / 2 + 2)
			end
			-- Un bicho cerca: todas se esconden, sin un ruido (el aviso es que ya no están).
			sala.bicho = nil
			for _, p in bichos do
				local db = BichitosVista.distanciaSala(d, p)
				if db < CFG.Rata.Bicho and p.Y > d.Suelo - 6 and p.Y < d.Suelo + d.Alto + 6 then
					sala.bicho = p
					break
				end
			end
			local bicho = sala.bicho
			if bicho then
				for _, b in sala.bichos do
					huir(b, bicho, false)
				end
			end
		end
	end

	-- Polillas en las bombillas encendidas.
	local cuantas = if ahoraPoco then CFG.Rendimiento.Polillas else azar:NextInteger(CFG.Polillas[1], CFG.Polillas[2])
	for luz, b in bombillas do
		local hay = #b.polillas > 0
		local quiere = luz.Enabled and b.pieza.Parent ~= nil
			and (b.pieza.Position - cam).Magnitude < CFG.Cerca + (if hay then CFG.Margen else 0)
		if quiere and not hay then
			crearPolillas(b, ahora, cuantas)
		elseif hay and not quiere then
			borrarPolillas(b.polillas)
		end
	end

	-- La polilla de la linterna (de noche, fuera de casa).
	local puede = not ahoraPoco and workspace:GetAttribute("Fase") == "Noche" and linternaEncendida()
		and not dentroDeCasa(cam)
	local v = visita
	if v then
		if not v.hacia and (not puede or ahora >= v.sale) then
			v.sale = ahora
			local lado = girar(plano(vista.LookVector).Unit, azar:NextNumber(1, 2) * (if azar:NextNumber() < 0.5 then -1 else 1))
			v.hacia = v.ultima + lado * 12 + Vector3.new(0, azar:NextNumber(1, 4), 0)
		elseif v.hacia and ahora - v.sale > 1.6 then
			v.m.pieza:Destroy()
			visita = nil
			proximaVisita = ahora + entre(CFG.PolillaLinterna.Cada)
		end
	elseif puede and ahora >= proximaVisita then
		local plana = plano(vista.LookVector)
		plana = if plana.Magnitude > 1e-3 then plana.Unit else Vector3.zAxis
		local desde = cam + girar(plana, azar:NextNumber(-1.2, 1.2)) * 14 + Vector3.new(0, azar:NextNumber(1, 5), 0)
		local m = nuevaPolilla(desde, desde, ahora)
		m.radio = azar:NextNumber(0.4, 0.8)
		visita = { m = m, llega = ahora, sale = ahora + entre(CFG.PolillaLinterna.Dura), desde = desde, ultima = desde }
	end

	-- Moscas en los charcos de sangre.
	for parte, c in charcos do
		if not parte:IsDescendantOf(game) then
			charcos[parte] = nil -- se fue sin avisar a la etiqueta
			borrarMoscas(c)
			continue
		end
		local hay = #c.moscas > 0
		local quiere = not ahoraPoco and parte.Parent ~= nil and ahora - c.desde >= CFG.Moscas.Llegan
			and (parte.Position - cam).Magnitude < CFG.Cerca + (if hay then CFG.Margen else 0)
		if quiere and not hay then
			crearMoscas(c, ahora)
		elseif hay and not quiere then
			borrarMoscas(c)
		end
	end

	if hayAlgo() then
		if not conexion then
			conexion = RunService.Heartbeat:Connect(function(dt)
				local ok, problema = pcall(fotograma, dt)
				if not ok and not avisado then
					avisado = true -- una vez: que no llene la consola
					warn(`[BichitosVista] {problema}`)
				end
			end)
		end
	elseif conexion then
		conexion:Disconnect()
		conexion = nil
	end
end

-- Para el banco (tests/bancos/bichitos.luau): lo de dentro, sin tocarlo.
function BichitosVista.estado()
	return { salas = salas, bombillas = bombillas, charcos = charcos, visita = visita, animando = conexion ~= nil }
end

function BichitosVista.start()
	proximaVisita = os.clock() + entre(CFG.PolillaLinterna.Cada) * 0.5 -- la primera, antes
	local function llegaCharco(cosa: Instance)
		if cosa:IsA("BasePart") and not charcos[cosa] then
			charcos[cosa] = { charco = cosa, desde = os.clock(), moscas = {}, zumbido = nil, punto = nil }
		end
	end
	CollectionService:GetInstanceAddedSignal("Charco"):Connect(llegaCharco)
	CollectionService:GetInstanceRemovedSignal("Charco"):Connect(function(cosa)
		local c = charcos[cosa :: BasePart]
		if c then
			charcos[cosa :: BasePart] = nil
			borrarMoscas(c)
		end
	end)
	for _, cosa in CollectionService:GetTagged("Charco") do
		llegaCharco(cosa)
	end

	task.spawn(function()
		local mapa = workspace:WaitForChild("Mapa")
		mapa.DescendantAdded:Connect(apuntarBombilla)
		for _, d in mapa:GetDescendants() do
			apuntarBombilla(d)
		end
	end)

	task.spawn(function()
		while true do
			local ok, problema = pcall(repaso)
			if not ok then
				warn(`[BichitosVista] {problema}`)
			end
			task.wait(CFG.Cada)
		end
	end)
end

return BichitosVista
