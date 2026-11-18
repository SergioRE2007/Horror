-- Huellas de barro y de sangre que dicen por dónde ha ido el bicho (docs/sistemas/huellas.md). Solo en el cliente y
-- solo de adorno: cada cliente las calcula con lo que ya ve (los bichos de workspace.Bichos, los personajes, los
-- charcos), así que se ven casi igual en todos.
--   Bichos: dentro de la casa, una huella de barro por pisada (su Zancada de Config.Efectos.Bichos), alternando lado
--     izquierdo y derecho; garras (la textura de huellas con uñas del salón, teñida) y, el Trepador, manos y pies.
--     Recién ha matado a alguien (remote Muerte), durante Config.Huellas.Ensangrentado segundos sus huellas son de
--     sangre, dentro y fuera, roja y brillante, que se va secando a marrón: se le puede seguir el rastro.
--   Jugadores: quien pisa un charco (etiqueta "Charco": MuerteVista.charco y el Goteo de Sustos/Sangre) deja 8-10
--     pisadas de zapato rojas que se apagan paso a paso; al entrar en casa del bosque, las 4 primeras son de barro.
--   Duran hasta el amanecer y se van aclarando. Tope de huellas vivas (menos con Rendimiento): las más viejas se borran.
-- Un solo Heartbeat que repasa cada Config.Huellas.Cada segundos lo andado (solo cerca de la cámara) y cada CadaColor el
-- color de las huellas cercanas. Lo que se calcula (cuándo toca una huella, a qué lado, el color, el tope) son
-- funciones puras de este módulo para el banco (tests/bancos/huellas.luau).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local HuellasVista = {}

local CFG = Config.Huellas
local PISADAS = Config.Efectos.Bichos -- Zancada y Pies de cada bicho (los mismos que sus pisadas que hacen temblar)
local MAX_POR_REPASO = 6 -- pisadas como mucho de un mismo bicho o jugador en un repaso (un tirón no llena el suelo)
local SALTO = 14 -- studs en un repaso: más es un salto (teletransporte), no se anda

---------------------------------------------------------------- cuentas (puras, para el banco)

local function entre(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Lo andado en un tramo de `d` studs con `andado` ya andados desde la última pisada: lo que queda andado después y en
-- qué partes del tramo (de 0 a 1) cae cada pisada.
function HuellasVista.pisadas(andado: number, d: number, zancada: number): (number, { number })
	local partes = {}
	if d <= 0 or zancada <= 0 then
		return andado, partes
	end
	local hasta = zancada - andado -- lo que falta para la siguiente
	while hasta <= d and #partes < MAX_POR_REPASO do
		table.insert(partes, math.max(0, hasta) / d)
		hasta += zancada
	end
	if hasta <= d then
		return 0, partes -- un tirón: lo que sobra no cuenta
	end
	return d - (hasta - zancada), partes
end

-- La pisada número `n` (desde 0) de una forma: a qué lado (-1 izquierda, 1 derecha) y qué deja. El Trepador va a cuatro
-- patas: mano izquierda, pie derecho, mano derecha, pie izquierdo.
local CUATRO = { { -1, "Mano" }, { 1, "Pie" }, { 1, "Mano" }, { -1, "Pie" } }
function HuellasVista.marca(forma: string, n: number): (number, string)
	if forma == "ManosPies" then
		local m = CUATRO[n % 4 + 1]
		return m[1], m[2]
	end
	return if n % 2 == 0 then -1 else 1, forma
end

-- El color (RGB de 0 a 255) de la sangre al cabo de `segundos`: de roja y brillante a marrón en CFG.Secar.
function HuellasVista.colorSangre(segundos: number): (number, number, number)
	local t = math.clamp(segundos / CFG.Secar, 0, 1)
	local a, b = CFG.SangreFresca, CFG.SangreSeca
	return entre(a[1], b[1], t), entre(a[2], b[2], t), entre(a[3], b[3], t)
end

-- Lo transparente que está una huella que nació con `base` al cabo de `edad` segundos (se aclara hasta el amanecer).
function HuellasVista.transparencia(base: number, edad: number): number
	local final = CFG.Transparencia[2]
	return math.max(base, entre(base, final, math.clamp(edad / CFG.Aclarar, 0, 1)))
end

-- La transparencia al nacer de la pisada `i` de `n` de un zapato manchado: cada una, menos que la anterior.
function HuellasVista.apagada(i: number, n: number): number
	return entre(CFG.Transparencia[1], CFG.SangreUltima, math.clamp((i - 1) / math.max(1, n - 1), 0, 1))
end

-- Cuántas pisadas rojas deja un jugador tras pisar un charco: entre PasosSangre, siempre las mismas para él (todos los
-- clientes cuentan lo mismo).
function HuellasVista.pasosSangre(userId: number): number
	local p = CFG.PasosSangre
	return p[1] + userId % (p[2] - p[1] + 1)
end

function HuellasVista.tope(rendimiento: boolean): number
	return if rendimiento then CFG.TopeRendimiento else CFG.Tope
end

-- Quita de la lista (por delante: las más viejas) lo que sobre del tope y lo devuelve.
function HuellasVista.recortar<T>(lista: { T }, tope: number): { T }
	local sobran = #lista - tope
	if sobran <= 0 then
		return {}
	end
	local quitadas = table.move(lista, 1, sobran, 1, {})
	table.move(lista, sobran + 1, #lista, 1)
	for i = #lista - sobran + 1, #lista do
		lista[i] = nil
	end
	return quitadas
end

-- Dentro de la casa (con sus anexos: torre, mirador y lavadero) y por debajo del tejado.
function HuellasVista.dentro(p: Vector3): boolean
	local C = Config.Casa
	if p.Y < -14 or p.Y > 40 then
		return false
	end
	if math.abs(p.X) < C.MedioX and math.abs(p.Z) < C.MedioZ then
		return true
	end
	for _, a in C.Anexos do
		if p.X > a[1] and p.X < a[2] and p.Z > a[3] and p.Z < a[4] then
			return true
		end
	end
	return false
end

-- Si unos pies en `pies` pisan un charco con centro `centro` y tamaño `tam` (el lado más grande es su ancho: sirve para
-- el cilindro de MuerteVista y para la placa del Goteo).
function HuellasVista.enCharco(pies: Vector3, centro: Vector3, tam: Vector3): boolean
	local radio = math.max(tam.X, tam.Y, tam.Z) / 2
	local d = Vector3.new(pies.X - centro.X, 0, pies.Z - centro.Z).Magnitude
	return d <= radio and math.abs(pies.Y - centro.Y) < 2
end

---------------------------------------------------------------- en el mundo

type Huella = {
	pieza: BasePart,
	tintes: { Instance }, -- lo que se tiñe y aclara (el Decal de la garra, o las piezas del zapato)
	nace: number,
	base: number, -- transparencia al nacer
	sangre: number?, -- si es de sangre: lo seca que estaba al nacer (segundos)
}

type Bicho = {
	raiz: BasePart,
	zancada: number,
	pies: number,
	forma: string,
	tam: { number },
	lado: number,
	antes: Vector3,
	andado: number,
	n: number,
	mato: number, -- os.clock() de su última muerte
}

type Andante = {
	antes: Vector3?,
	andado: number,
	n: number,
	fuera: boolean, -- ha pisado el bosque: al entrar en casa, barro
	barro: number, -- pisadas de barro que le quedan...
	sangre: number, -- ...y de sangre
	sangreDe: number, -- de cuántas eran (para apagarlas paso a paso)
	sangreEn: number, -- os.clock() del charco
}

local jugador = Players.LocalPlayer
local carpeta: Folder
local huellas: { Huella } = {}
local bichos: { [Model]: Bicho } = {}
local andantes: { [Player]: Andante } = setmetatable({}, { __mode = "k" }) :: any
local charcos: { [BasePart]: true } = {}
local bichosCarpeta: Instance? = nil
local rayo = RaycastParams.new()
local cuenta = 0 -- huellas puestas (para que no se pisen en altura)
local FUERA: { [Enum.Material]: true } = {}
for _, nombre in CFG.Fuera do
	FUERA[(Enum.Material :: any)[nombre]] = true
end

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function poco(): boolean
	return jugador:GetAttribute("Rendimiento") == true
end

local function plano(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Los rayos no ven a los bichos, los personajes ni las huellas.
local function rehacerRayo()
	local fuera: { Instance } = { carpeta }
	if bichosCarpeta then
		table.insert(fuera, bichosCarpeta)
	end
	for _, j in Players:GetPlayers() do
		if j.Character then
			table.insert(fuera, j.Character)
		end
	end
	rayo.FilterType = Enum.RaycastFilterType.Exclude
	rayo.FilterDescendantsInstances = fuera
end

local function pieza(tam: Vector3, cf: CFrame, padre: Instance): Part
	local p = Instance.new("Part")
	p.Name = "Huella"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Size = tam
	p.CFrame = cf
	p.Parent = padre
	return p
end

local function tintar(h: Huella, color: Color3, transparencia: number)
	for _, t in h.tintes do
		if t:IsA("Decal") then
			t.Color3 = color
			t.Transparency = transparencia
		elseif t:IsA("BasePart") then
			t.Color = color
			t.Transparency = transparencia
		end
	end
end

local function colorDe(h: Huella, edad: number): Color3
	if h.sangre then
		local r, g, b = HuellasVista.colorSangre(h.sangre + edad)
		return Color3.fromRGB(r, g, b)
	end
	return rgb(CFG.Barro)
end

-- Una huella en el suelo bajo `desde` (un rayo hacia abajo de `largo` studs), mirando hacia `dir` (en planta, unitario).
-- `forma`: Garra, Mano, Pie o Zapato; `tam`: { ancho, largo }. Sin suelo plano debajo, nada.
local function poner(desde: Vector3, largo: number, dir: Vector3, forma: string, tam: { number }, base: number,
	sangre: number?, soloDentro: boolean): boolean
	local golpe = workspace:Raycast(desde, Vector3.new(0, -largo, 0), rayo)
	if not golpe or golpe.Normal.Y < 0.9 or (soloDentro and not HuellasVista.dentro(golpe.Position)) then
		return false
	end
	cuenta += 1
	local derecha = dir:Cross(Vector3.yAxis).Unit
	local donde = golpe.Position + Vector3.new(0, 0.02 + (cuenta % 6) * 0.003, 0)
	-- fromMatrix con el eje Y hacia arriba: LookVector = dir (la punta del pie hacia donde va).
	local cf = CFrame.fromMatrix(donde, derecha, Vector3.yAxis)
	local h: Huella = { pieza = nil :: any, tintes = {}, nace = os.clock(), base = base, sangre = sangre }
	if forma == "Zapato" then
		-- Óvalos aplastados: la planta y, detrás, el tacón.
		local planta = pieza(Vector3.new(tam[1], 0.04, tam[2]), cf * CFrame.new(0, 0, -tam[2] * 0.2), carpeta)
		local malla = Instance.new("SpecialMesh")
		malla.MeshType = Enum.MeshType.Sphere
		malla.Parent = planta
		local tacon = pieza(Vector3.new(tam[1] * 0.8, 0.04, tam[2] * CFG.Zapato.Tacon / CFG.Zapato.Largo),
			cf * CFrame.new(0, 0, tam[2] * 0.55), planta)
		malla:Clone().Parent = tacon
		h.pieza, h.tintes = planta, { planta, tacon }
	else
		local escala = if forma == "Mano" then 0.75 else 1
		local p = pieza(Vector3.new(tam[1] * escala, 0.02, tam[2] * escala), cf, carpeta)
		p.Transparency = 1
		local d = Instance.new("Decal")
		d.Texture = CFG.Textura
		d.Face = Enum.NormalId.Top
		d.Parent = p
		h.pieza, h.tintes = p, { d }
	end
	tintar(h, colorDe(h, 0), base)
	table.insert(huellas, h)
	for _, vieja in HuellasVista.recortar(huellas, HuellasVista.tope(poco())) do
		vieja.pieza:Destroy()
	end
	return true
end

---------------------------------------------------------------- bichos

local function apuntarBicho(modelo: Instance)
	if not modelo:IsA("Model") or not PISADAS[modelo.Name] or not CFG.Bichos[modelo.Name] then
		return
	end
	local raiz = modelo:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if raiz and modelo.Parent then
		local p, f = PISADAS[modelo.Name], CFG.Bichos[modelo.Name]
		bichos[modelo] = { raiz = raiz, zancada = p.Zancada, pies = p.Pies, forma = f.Forma, tam = f.Tam, lado = f.Lado,
			antes = raiz.Position, andado = 0, n = 0, mato = -math.huge }
		rehacerRayo()
	end
end

local function pisarBicho(b: Bicho, punto: Vector3, dir: Vector3, ahora: number)
	local lado, tipo = HuellasVista.marca(b.forma, b.n)
	b.n += 1
	local derecha = dir:Cross(Vector3.yAxis).Unit
	local adelante = if tipo == "Mano" then b.tam[2] * 0.6 elseif tipo == "Pie" then -b.tam[2] * 0.3 else 0
	-- Los pies un poco hacia fuera, como cualquier bicho al andar.
	local giro = CFrame.Angles(0, -lado * 0.12, 0)
	local mira = (giro:VectorToWorldSpace(dir) :: Vector3).Unit
	local desde = punto + derecha * (lado * b.lado / 2) + dir * adelante + Vector3.new(0, 1.5, 0)
	local reciente = ahora - b.mato
	local sangre = if reciente < CFG.Ensangrentado then reciente else nil
	poner(desde, b.pies + 4, mira, tipo, b.tam, CFG.Transparencia[1], sangre, sangre == nil)
end

local function moverBichos(camara: Vector3, ahora: number)
	for modelo, b in bichos do
		if not modelo.Parent or not b.raiz.Parent then
			bichos[modelo] = nil
			continue
		end
		local pos = b.raiz.Position
		local antes = b.antes
		b.antes = pos
		local movido = plano(pos - antes)
		local d = movido.Magnitude
		-- En la pared, bajando por la chimenea, de un salto o lejos: no pisa el suelo (o no se mira).
		if d > SALTO or modelo:GetAttribute("Trepando") or modelo:GetAttribute("Bajando")
			or (pos - camara).Magnitude > CFG.Cerca then
			continue
		end
		local partes
		b.andado, partes = HuellasVista.pisadas(b.andado, d, b.zancada)
		if #partes > 0 then
			local dir = movido.Unit
			for _, t in partes do
				pisarBicho(b, antes:Lerp(pos, t) - Vector3.new(0, b.pies, 0), dir, ahora)
			end
		end
	end
end

-- Alguien ha muerto: el bicho que le pilló (o el más cercano) se queda con las patas manchadas un rato.
local function alMorir(quien: Player?, cabeza: Vector3?, modelo: Model?)
	local ahora = os.clock()
	if typeof(modelo) == "Instance" and bichos[modelo :: Model] then
		bichos[modelo :: Model].mato = ahora
		return
	end
	local donde: Vector3? = if typeof(cabeza) == "Vector3" then cabeza else nil
	local raiz = quien and quien.Character and quien.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if raiz then
		donde = raiz.Position
	end
	if not donde then
		return
	end
	local mejor, cerca = nil, CFG.CercaMuerte
	for _, b in bichos do
		local d = plano(b.raiz.Position - donde).Magnitude
		if d < cerca then
			mejor, cerca = b, d
		end
	end
	if mejor then
		mejor.mato = ahora
	end
end

---------------------------------------------------------------- jugadores

local function moverJugadores(camara: Vector3, ahora: number)
	for _, j in Players:GetPlayers() do
		local personaje = j.Character
		local humano = personaje and personaje:FindFirstChildOfClass("Humanoid")
		local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
		local a = andantes[j]
		if not a then
			a = { antes = nil, andado = 0, n = 0, fuera = false, barro = 0, sangre = 0, sangreDe = 0, sangreEn = 0 }
			andantes[j] = a
		end
		if not humano or not raiz or humano.Health <= 0 or (raiz.Position - camara).Magnitude > CFG.Cerca then
			a.antes = nil
			continue
		end
		local pos = raiz.Position
		local alto = humano.HipHeight + raiz.Size.Y / 2
		local suelo = humano.FloorMaterial
		if suelo ~= Enum.Material.Air then
			if FUERA[suelo] and not HuellasVista.dentro(pos) then
				a.fuera = true
			end
			-- Un charco bajo los pies: zapatos rojos (mientras siga dentro, vuelven a estar empapados).
			local pies = pos - Vector3.new(0, alto, 0)
			for charco in charcos do
				if charco.Parent and HuellasVista.enCharco(pies, charco.Position, charco.Size) then
					a.sangreDe = HuellasVista.pasosSangre(j.UserId)
					a.sangre, a.sangreEn = a.sangreDe, ahora
					break
				end
			end
		end
		local antes = a.antes
		a.antes = pos
		if not antes or suelo == Enum.Material.Air then
			continue
		end
		local movido = plano(pos - antes)
		local d = movido.Magnitude
		if d > SALTO then
			continue
		end
		local partes
		a.andado, partes = HuellasVista.pisadas(a.andado, d, CFG.Zancada)
		for _, t in partes do
			local punto = antes:Lerp(pos, t)
			if a.fuera and HuellasVista.dentro(punto) then
				a.fuera, a.barro = false, CFG.PasosBarro -- entra del bosque con las suelas llenas de barro
			end
			local lado = if a.n % 2 == 0 then -1 else 1
			a.n += 1
			local base, sangre = nil, nil
			if a.sangre > 0 then
				base = HuellasVista.apagada(a.sangreDe - a.sangre + 1, a.sangreDe)
				sangre = ahora - a.sangreEn
				a.sangre -= 1
			elseif a.barro > 0 then
				base = HuellasVista.apagada(CFG.PasosBarro - a.barro + 1, CFG.PasosBarro)
				a.barro -= 1
			end
			if base then
				local dir = movido.Unit
				local Z = CFG.Zapato
				local desde = punto + dir:Cross(Vector3.yAxis).Unit * (lado * Z.Lado / 2)
				local mira = (CFrame.Angles(0, -lado * 0.08, 0):VectorToWorldSpace(dir) :: Vector3).Unit
				poner(desde, alto + 2, mira, "Zapato", { Z.Ancho, Z.Largo }, base, sangre, false)
			end
		end
	end
end

---------------------------------------------------------------- el bucle

-- Se aclaran (y la sangre se seca) las que están cerca de la cámara.
local function aclarar(camara: Vector3, ahora: number)
	for _, h in huellas do
		if (h.pieza.Position - camara).Magnitude < CFG.Cerca then
			local edad = ahora - h.nace
			tintar(h, colorDe(h, edad), HuellasVista.transparencia(h.base, edad))
		end
	end
end

local function barrer()
	for _, h in huellas do
		h.pieza:Destroy()
	end
	table.clear(huellas)
	for _, b in bichos do
		b.mato = -math.huge
	end
	for _, a in andantes do
		a.fuera, a.barro, a.sangre = false, 0, 0
	end
end

local function vigilarCharco(p: Instance)
	if p:IsA("BasePart") then
		charcos[p] = true
	end
end

function HuellasVista.start()
	carpeta = Instance.new("Folder")
	carpeta.Name = "Huellas"
	carpeta.Parent = workspace
	rehacerRayo()

	for _, p in CollectionService:GetTagged("Charco") do
		vigilarCharco(p)
	end
	CollectionService:GetInstanceAddedSignal("Charco"):Connect(vigilarCharco)
	CollectionService:GetInstanceRemovedSignal("Charco"):Connect(function(p)
		charcos[p :: BasePart] = nil
	end)

	Remotes.Muerte.OnClientEvent:Connect(alMorir)
	-- Los personajes cambian: el filtro de los rayos, al día.
	Players.PlayerAdded:Connect(function(j)
		j.CharacterAdded:Connect(rehacerRayo)
	end)
	for _, j in Players:GetPlayers() do
		j.CharacterAdded:Connect(rehacerRayo)
	end

	-- Al amanecer, el suelo limpio.
	workspace:GetAttributeChangedSignal("Fase"):Connect(function()
		if workspace:GetAttribute("Fase") == "Dia" then
			barrer()
		end
	end)

	task.spawn(function()
		local bichosC = workspace:WaitForChild("Bichos")
		bichosCarpeta = bichosC
		rehacerRayo()
		bichosC.ChildAdded:Connect(apuntarBicho)
		for _, modelo in bichosC:GetChildren() do
			task.spawn(apuntarBicho, modelo)
		end
	end)

	local espera, color = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		espera += dt
		color += dt
		if espera < CFG.Cada then
			return
		end
		espera = 0
		local camara = workspace.CurrentCamera.CFrame.Position
		local ahora = os.clock()
		moverBichos(camara, ahora)
		moverJugadores(camara, ahora)
		if color >= CFG.CadaColor then
			color = 0
			if #huellas > 0 then
				aclarar(camara, ahora)
			end
		end
	end)
end

return HuellasVista
