-- La casa se desordena (docs/sistemas/desorden.md): lo que cae con los golpes y las sillas que vuelca el bicho. Todo en
-- el cliente; el servidor no cambia (manda con Golpes en las ventanas y puertas, y con los bichos de workspace.Bichos).
--   Un golpe en una puerta o ventana (atributo Golpes, lo pone Casa) o una pisada fuerte de un bicho dentro de la casa:
--     de las baldas, mesas y repisas de esa sala se caen de verdad 1-2 adornos, de los más cerca del borde. Caen con
--     física local (una copia sin anclar, empujada fuera del borde), rebotan y se quedan en el suelo. La vajilla y el
--     cristal se rompen en 4-6 trozos que crujen al pisarlos (y una botella deja un charco); el metal rueda con
--     Latas. Un cuadro que ya ha aguantado CuadroGolpes golpes cerca se descuelga y cae con CuadroCae.
--   Un bicho que cruza una sala: las sillas que roza (su raíz a menos de Roce studs) se vuelcan con un botecito y se
--     quedan tiradas; la mecedora y la silla de ruedas se apartan.
--   Lo que cae y en qué orden sale de una cuenta fija (DesordenCuentas): todos los clientes tiran las mismas cosas.
--   Al acabar, la pieza de verdad se pone donde quedó la copia (anclada, en local) y la copia se borra: Efectos la da
--     por movida por otro (`ajeno`) y no la toca hasta que vuelve a su sitio. Por la mañana se ve por dónde pasó y dónde
--     golpeó; al amanecer (Fase Dia) todo vuelve a su sitio.
--   Lejos de la cámara (más de Cerca) no hay física: se pone ya caído, sin sonido. Tope: Tope cosas caídas.
--   Con Rendimiento: una cosa por golpe, la vajilla no se rompe y las sillas caen sin rebote.
-- Un solo Heartbeat, atado solo mientras cae algo, hay trozos en el suelo o bichos en el mundo.
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local C = require(script.Parent.DesordenCuentas)
local Sonido = require(script.Parent.Sonido)

local DesordenVista = {}

local D = Config.Desorden
local jugador = Players.LocalPlayer
local azar = Random.new() -- solo para lo que no tiene que ser igual en todos (por dónde saltan los trozos)

-- Lo que se cae de las baldas y cómo suena: vajilla y cristal (se rompe), metal (rueda) u otra cosa (cae y ya).
local ADORNOS: { [string]: string } = {
	CopasPH = "Vajilla", JarraPH = "Vajilla", JarronPH = "Vajilla", PlatoPH = "Vajilla", TarroPH = "Vajilla",
	TarrosSotano = "Vajilla", JuegoTePH = "Vajilla", Licores = "Vajilla", LamparaAceitePH = "Vajilla",
	CandeleroPH = "Metal", CandelabroPH = "Metal", LataOxidadaPH = "Metal", LatasPH = "Metal", OllaPH = "Metal",
	SartenPH = "Metal", FotoPH1 = "Otro", FotoPH2 = "Otro", RelojRepisaPH = "Otro",
}
-- De la vajilla, la de cristal (trozos transparentes); el resto es loza.
local CRISTAL = {
	CopasPH = true, JarraPH = true, TarroPH = true, TarrosSotano = true, Licores = true, LamparaAceitePH = true,
}
-- Lo que deja un charco al romperse (y de qué color).
local CHARCO: { [string]: Color3 } = {
	Licores = Color3.fromRGB(58, 30, 14),
	JarraPH = Color3.fromRGB(40, 38, 34),
}
local VUELCAN = {
	SillaCocinaPH = true, SillaComedorPH = true, SillaDormitorioPH = true, SillaSotanoPH = true, Banqueta = true,
	Taburete = true,
}
local APARTAN = { Mecedora = true, MecedoraPH = true, SillaRuedasPH = true }
local ESCONDIDA = Vector3.new(0, -1000, 0) -- la pieza de verdad, mientras cae su copia (o rota)

-- Una cosa de la casa que se puede caer o volcar.
type Cosa = {
	modelo: Model,
	partes: { BasePart },
	orig: { CFrame }, -- dónde está cada pieza en su sitio
	centro: Vector3,
	tam: Vector3,
	clase: string, -- "Vajilla", "Metal", "Otro", "Cuadro", "Silla" o "Aparta"
	x: number, -- su sitio redondeado (para el orden fijo)
	y: number,
	z: number,
	borde: number, -- adornos: studs del centro al borde de la balda por donde cae
	apoyo: boolean, -- adornos: está en una balda o mesa (no en el suelo); cuadros: está colgado
	salida: Vector3, -- adornos: hacia dónde cae (fuera del borde); cuadros: hacia la sala
	suelo: number, -- dónde acaba (la y del suelo de debajo); sillas: la y de sus patas
	caja: CFrame, -- cuadros y sillas: su caja con sus ejes (de pie)
	golpes: number, -- cuadros: golpes cerca esta noche
	estado: string, -- "quieto", "cae", "caido" o "roto"
}
type Cae = { c: Cosa, copias: { BasePart }, modelo: Model, nace: number, vy: number, choco: boolean, semilla: number }
type Vuelco = {
	c: Cosa, t0: number, dura: number, dir: Vector3, aparta: boolean, dist: number, giro: number, rebota: boolean,
	sono: boolean,
}
type Trozo = { p: BasePart, nace: number, quieto: boolean }

local carpeta: Folder
local bichosCarpeta: Instance? = nil
local cosas: { Cosa } = {}
local porModelo: { [Model]: Cosa } = {}
local cayendo: { Cae } = {}
local vuelcos: { Vuelco } = {}
local trozos: { Trozo } = {}
local total = 0 -- cosas caídas esta noche (Tope)
local noche = 0 -- sube al amanecer: lo que iba a caer con retraso ya no cae
local celdas: { [string]: boolean } = {} -- casillas ya pisadas fuerte esta noche (cada una cuenta una vez)
local bichoAntes: { [Instance]: Vector3 } = setmetatable({}, { __mode = "k" }) :: any
local crujidos: { [Instance]: Vector3 } = setmetatable({}, { __mode = "k" }) :: any
local indexado = false
local conexion: RBXScriptConnection? = nil
local ultimaMirada = 0

local function poco(): boolean
	return jugador:GetAttribute("Rendimiento") == true
end

local function plano(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function rango(r: { number }): number
	return azar:NextNumber(r[1], r[2])
end

local function dentroDeCasa(p: Vector3): boolean
	local casa = Config.Casa
	if p.Y > 28 then
		return false
	end
	if math.abs(p.X) < casa.MedioX and math.abs(p.Z) < casa.MedioZ then
		return true
	end
	for _, a in casa.Anexos do
		if p.X > a[1] and p.X < a[2] and p.Z > a[3] and p.Z < a[4] then
			return true
		end
	end
	return false
end

local function grupo(): string
	-- Lo que cae no choca con los jugadores (grupo "Cargado", lo registra el servidor en Cargar).
	local ok, si = pcall(PhysicsService.IsCollisionGroupRegistered, PhysicsService, "Cargado")
	return if ok and si then "Cargado" else "Default"
end

-- Un modelo que no es de nadie: sin cartel para tocarlo ni etiqueta (como en Efectos).
local function libre(modelo: Instance): boolean
	return not modelo:FindFirstChildWhichIsA("ProximityPrompt", true) and #CollectionService:GetTags(modelo) == 0
end

local function piezasDe(modelo: Instance): { BasePart }
	local partes = {}
	for _, p in modelo:GetDescendants() do
		if p:IsA("BasePart") then
			table.insert(partes, p)
		end
	end
	return partes
end

-- Caja de unas piezas (en sus CFrame `cfs`) en los ejes de `giro`: centro (en el mundo) y tamaño (en esos ejes).
local function caja(partes: { BasePart }, cfs: { CFrame }, giro: CFrame): (Vector3, Vector3)
	local menor, mayor = Vector3.one * math.huge, -Vector3.one * math.huge
	for i, p in partes do
		local cf, t = giro:ToObjectSpace(cfs[i]), p.Size / 2
		local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
		local ext = Vector3.new(
			math.abs(r.X) * t.X + math.abs(u.X) * t.Y + math.abs(l.X) * t.Z,
			math.abs(r.Y) * t.X + math.abs(u.Y) * t.Y + math.abs(l.Y) * t.Z,
			math.abs(r.Z) * t.X + math.abs(u.Z) * t.Y + math.abs(l.Z) * t.Z)
		menor = menor:Min(cf.Position - ext)
		mayor = mayor:Max(cf.Position + ext)
	end
	return giro * ((menor + mayor) / 2), mayor - menor
end

-- Rayos que no chocan con bichos, personajes, lo nuestro ni los adornos (lo que se pone aparte, en `mas`).
local function filtro(mas: { Instance }?): RaycastParams
	local fuera: { Instance } = { carpeta }
	if bichosCarpeta then
		table.insert(fuera, bichosCarpeta)
	end
	for _, j in Players:GetPlayers() do
		if j.Character then
			table.insert(fuera, j.Character)
		end
	end
	for _, c in cosas do
		if c.clase ~= "Silla" and c.clase ~= "Aparta" then
			table.insert(fuera, c.modelo)
		end
	end
	for _, i in mas or {} do
		table.insert(fuera, i)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = fuera
	return params
end

-- La pieza de verdad sigue en su sitio (lo que Efectos mueve al temblar no cuenta): si no, la tiene otro módulo.
local function enSitio(c: Cosa): boolean
	local p = c.partes[1]
	return p.Parent ~= nil and (p.Position - c.orig[1].Position).Magnitude < (if c.clase == "Cuadro" then 0.8 else 0.5)
end

local function colocar(c: Cosa, giro: CFrame)
	for i, p in c.partes do
		p.CFrame = giro * c.orig[i]
	end
end

local function esconder(c: Cosa)
	for i, p in c.partes do
		p.CFrame = c.orig[i] + ESCONDIDA
	end
end

---------------------------------------------------------------- lo que hay en la casa

-- La balda, mesa o repisa en la que está un adorno: por qué borde se caería (el más cercano que no da a una pared) y
-- dónde acabaría. Sin balda (en el suelo, colgado...) no se cae.
local function mirarBalda(c: Cosa, rayo: RaycastParams)
	local abajo = c.centro.Y - c.tam.Y / 2
	local golpe = workspace:Raycast(Vector3.new(c.centro.X, abajo + 0.3, c.centro.Z), Vector3.new(0, -1.5, 0), rayo)
	if not golpe or golpe.Normal.Y < 0.7 then
		return
	end
	local balda = golpe.Instance
	local cf = balda.CFrame
	local ejes = { cf.RightVector, cf.UpVector, cf.LookVector }
	local medidas = { balda.Size.X, balda.Size.Y, balda.Size.Z }
	local arriba, mejor = 1, -1
	for i, e in ejes do
		if math.abs(e.Y) > mejor then
			arriba, mejor = i, math.abs(e.Y)
		end
	end
	local h = {}
	for i = 1, 3 do
		if i ~= arriba then
			table.insert(h, i)
		end
	end
	local e1, e2 = ejes[h[1]], ejes[h[2]]
	local m1, m2 = medidas[h[1]] / 2, medidas[h[2]] / 2
	if math.max(m1, m2) * 2 > D.BaldaMax then
		return -- el suelo
	end
	-- Debajo de la balda tiene que haber hueco (si no, es una alfombra en el suelo).
	local debajo = workspace:Raycast(golpe.Position - Vector3.new(0, medidas[arriba] + 0.05, 0), Vector3.new(0, -12, 0), rayo)
	if not debajo or golpe.Position.Y - debajo.Position.Y < D.Altura then
		return
	end
	local rel = c.centro - balda.Position
	for _, b in C.bordes(rel:Dot(e1), rel:Dot(e2), m1, m2) do
		local eje = (if b[2] == 1 then e1 else e2) * b[3]
		local dir = plano(eje)
		if dir.Magnitude < 0.5 then
			continue
		end
		dir = dir.Unit
		local sale = C.saliente(CFrame.identity, c.tam, dir)
		if workspace:Raycast(c.centro, dir * (b[1] + sale + 0.6), rayo) then
			continue -- da a una pared o a un lado del mueble: por ahí no cae
		end
		local fuera = c.centro + dir * (b[1] + sale + 0.5)
		local suelo = workspace:Raycast(Vector3.new(fuera.X, golpe.Position.Y + 0.1, fuera.Z), Vector3.new(0, -15, 0), rayo)
		if suelo and golpe.Position.Y - suelo.Position.Y >= D.Altura then
			c.apoyo, c.borde, c.salida, c.suelo = true, b[1], dir, suelo.Position.Y
			return
		end
	end
end

-- Un cuadro: hacia dónde da la sala (el pivote mira hacia ella, como en Sustos) y el suelo de debajo.
local function mirarCuadro(c: Cosa, rayo: RaycastParams)
	local frente = plano(c.modelo:GetPivot().LookVector)
	if frente.Magnitude < 0.5 then
		return
	end
	frente = frente.Unit
	if workspace:Raycast(c.centro, frente * 1.2, rayo) and not workspace:Raycast(c.centro, -frente * 1.2, rayo) then
		frente = -frente -- la pared estaba delante: la sala, al otro lado
	end
	local suelo = workspace:Raycast(c.centro + frente * 0.8, Vector3.new(0, -14, 0), rayo)
	if suelo and c.centro.Y - c.tam.Y / 2 - suelo.Position.Y > 1 then
		c.apoyo, c.salida, c.suelo = true, frente, suelo.Position.Y
	end
end

local function nuevaCosa(modelo: Model, partes: { BasePart }, clase: string): Cosa
	local orig = {}
	for i, p in partes do
		orig[i] = p.CFrame
	end
	local giro = CFrame.identity
	if clase == "Cuadro" or clase == "Silla" or clase == "Aparta" then
		local mira = plano(modelo:GetPivot().LookVector)
		if mira.Magnitude > 0.1 then
			giro = CFrame.lookAt(Vector3.zero, mira.Unit)
		end
	end
	local centro, tam = caja(partes, orig, giro)
	return {
		modelo = modelo, partes = partes, orig = orig, centro = centro, tam = tam, clase = clase,
		x = math.floor(centro.X + 0.5), y = math.floor(centro.Y + 0.5), z = math.floor(centro.Z + 0.5),
		borde = 0, apoyo = false, salida = Vector3.zero, suelo = centro.Y - tam.Y / 2,
		caja = CFrame.new(centro) * giro, golpes = 0, estado = "quieto",
	}
end

-- Busca en la casa lo que se puede caer. Lo que ya se conocía se queda como estaba (su sitio y lo que le pasó).
local function indexar(casa: Instance)
	local nuevas: { Cosa } = {}
	local mapa: { [Model]: Cosa } = {}
	local porMirar: { Cosa } = {}
	local mantas: { Model } = {}
	for _, d in casa:GetDescendants() do
		if not d:IsA("Model") then
			continue
		end
		local nombre = d.Name
		if nombre == "MantaMecedora" then
			table.insert(mantas, d)
			continue
		end
		local clase = ADORNOS[nombre]
		if not clase then
			clase = if string.sub(nombre, 1, 6) == "Cuadro" then "Cuadro"
				elseif VUELCAN[nombre] then "Silla"
				elseif APARTAN[nombre] then "Aparta"
				else nil
		end
		if not clase or not libre(d) then
			continue
		end
		local vieja = porModelo[d]
		if vieja then
			table.insert(nuevas, vieja)
			mapa[d] = vieja
			continue
		end
		local partes = piezasDe(d)
		if #partes == 0 then
			continue
		end
		local c = nuevaCosa(d, partes, clase)
		local tope = if clase == "Cuadro" then 6 elseif clase == "Silla" or clase == "Aparta" then 8 else 4
		if math.max(c.tam.X, c.tam.Y, c.tam.Z) >= tope then
			continue
		end
		table.insert(nuevas, c)
		mapa[d] = c
		table.insert(porMirar, c)
	end
	cosas, porModelo = nuevas, mapa
	-- La manta de la mecedora (otro modelo, encima) va con ella.
	for _, manta in mantas do
		local piezas = piezasDe(manta)
		if #piezas == 0 then
			continue
		end
		local cfs = {}
		for i, p in piezas do
			cfs[i] = p.CFrame
		end
		local centro = caja(piezas, cfs, CFrame.identity)
		for _, c in porMirar do
			if c.clase == "Aparta" and (c.centro - centro).Magnitude < 3 then
				for i, p in piezas do
					table.insert(c.partes, p)
					table.insert(c.orig, cfs[i])
				end
				break
			end
		end
	end
	if #porMirar > 0 then
		local rayo = filtro()
		for _, c in porMirar do
			if c.clase == "Cuadro" then
				mirarCuadro(c, rayo)
			elseif c.clase ~= "Silla" and c.clase ~= "Aparta" then
				mirarBalda(c, rayo)
			end
		end
	end
	indexado = true
end

---------------------------------------------------------------- el bucle (se ata solo cuando hace falta)

local function activar()
	if conexion then
		return
	end
	conexion = RunService.Heartbeat:Connect(function()
		DesordenVista.paso()
	end)
end

---------------------------------------------------------------- caer

-- Dónde se queda una cosa caída sin física (lejos de la cámara o si la copia se va por un hueco): tumbada en el suelo,
-- fuera del borde (un cuadro, boca abajo delante de su pared).
local function poseSuelo(c: Cosa): CFrame
	local base = if c.clase == "Cuadro" then c.caja else CFrame.new(c.centro)
	local tumbada = C.volcar(base, c.tam, c.salida, math.pi / 2)
	local bajo = c.centro.Y - C.saliente(base.Rotation, c.tam, Vector3.yAxis)
	local fuera = if c.clase == "Cuadro" then c.salida * 0.1 else c.salida * (c.borde + 0.4)
	return CFrame.new(fuera + Vector3.new(0, c.suelo - bajo, 0)) * tumbada
end

local function sonar(nombre: string, donde: Vector3, tono: number, volumen: number, corta: number?)
	local s = Sonido.en(nombre, donde, tono)
	s.Volume *= volumen
	if corta then
		task.delay(corta, function()
			if s.Parent then
				TweenService:Create(s, TweenInfo.new(0.12), { Volume = 0 }):Play()
			end
		end)
	end
end

local function nuevoTrozo(tam: Vector3, cf: CFrame, color: Color3, cristal: boolean): Part
	local p = Instance.new("Part")
	p.Name = "Trozo"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = tam
	p.CFrame = cf
	p.Color = color
	if cristal then
		p.Material = Enum.Material.Glass
		p.Transparency = 0.3
		p.Reflectance = 0.1
	else
		p.Material = Enum.Material.SmoothPlastic
	end
	p.Parent = carpeta
	return p
end

-- El color de lo que se rompe: el de su pieza más grande.
local function colorDe(c: Cosa): Color3
	local mejor, color = -1, Color3.fromRGB(200, 196, 186)
	for _, p in c.partes do
		local v = p.Size.X * p.Size.Y * p.Size.Z
		if v > mejor then
			mejor, color = v, p.Color
		end
	end
	return color
end

-- Se rompe en `donde` (la pieza de verdad se queda escondida hasta el amanecer): trozos que saltan un poco (o ya en
-- el suelo, sin física) y, de una botella, un charco que se extiende.
local function romper(c: Cosa, donde: Vector3, semilla: number, fisica: boolean)
	c.estado = "roto"
	esconder(c)
	local nombre = c.modelo.Name
	local cristal = CRISTAL[nombre] == true
	local color = colorDe(c)
	local rayo = filtro()
	local suelo = workspace:Raycast(donde + Vector3.new(0, 1, 0), Vector3.new(0, -4, 0), rayo)
	local y = if suelo then suelo.Position.Y else c.suelo
	if fisica then
		if Sonido.hay("Vajilla") then
			sonar("Vajilla", donde, azar:NextNumber(0.95, 1.05), 1.4)
		else -- mientras no haya uno propio: el de un cristal, agudo y corto
			sonar("Cristal", donde, azar:NextNumber(1.5, 1.8), 0.35, 0.5)
		end
	end
	for _ = 1, C.trozos(semilla) do
		local tam = Vector3.new(azar:NextNumber(0.12, 0.4), azar:NextNumber(0.04, 0.08), azar:NextNumber(0.1, 0.3))
		local giro = CFrame.Angles(0, azar:NextNumber(0, math.pi * 2), 0)
		if fisica then
			local p = nuevoTrozo(tam, CFrame.new(donde + Vector3.new(0, 0.2, 0)) * giro, color, cristal)
			local dir = giro.LookVector
			p.Anchored = false
			p.CanCollide = true
			p.CollisionGroup = grupo()
			p.AssemblyLinearVelocity = dir * rango(D.TrozosSalen) + Vector3.new(0, azar:NextNumber(1, 3), 0)
			p.AssemblyAngularVelocity = Vector3.new(azar:NextNumber(-15, 15), azar:NextNumber(-15, 15), azar:NextNumber(-15, 15))
			table.insert(trozos, { p = p, nace = os.clock(), quieto = false })
		else
			local sitio = Vector3.new(donde.X, y + tam.Y / 2, donde.Z) + giro.LookVector * azar:NextNumber(0.2, 1.4)
			local p = nuevoTrozo(tam, CFrame.new(sitio) * giro, color, cristal)
			table.insert(trozos, { p = p, nace = os.clock(), quieto = true })
		end
	end
	local liquido = CHARCO[nombre]
	if liquido and not poco() then
		local charco = nuevoTrozo(Vector3.new(0.03, 0.4, 0.4),
			CFrame.new(donde.X, y + 0.02, donde.Z) * CFrame.Angles(0, 0, math.pi / 2), liquido, false)
		charco.Name = "Charco"
		charco.Shape = Enum.PartType.Cylinder
		charco.Reflectance = 0.15
		charco.Transparency = 0.25
		local ancho = C.entre(semilla, 400, 1.6, 2.6)
		local llena = Vector3.new(0.03, ancho, ancho * 0.8)
		if fisica then
			TweenService:Create(charco, TweenInfo.new(4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = llena }):Play()
		else
			charco.Size = llena
		end
		table.insert(trozos, { p = charco, nace = os.clock(), quieto = true })
	end
	activar()
end

-- La copia da contra el suelo: suena y, si es vajilla (y sin Rendimiento), se rompe. Devuelve si se ha roto.
local function chocar(k: Cae, donde: Vector3): boolean
	local c = k.c
	k.choco = true
	if c.clase == "Vajilla" then
		if not poco() then
			romper(c, donde, k.semilla, true)
			return true
		end
		if Sonido.hay("Vajilla") then
			sonar("Vajilla", donde, azar:NextNumber(1.1, 1.25), 0.8)
		else
			sonar("CristalVibra", donde, azar:NextNumber(1.3, 1.5), 0.6, 0.3)
		end
	elseif c.clase == "Metal" then
		sonar("Latas", donde, azar:NextNumber(0.9, 1.1), 0.5)
		-- Rueda un poco: un giro de lado y otro repique más flojo.
		local raiz = k.copias[1]
		local eje = Vector3.new(0, 1, 0):Cross(c.salida)
		if eje.Magnitude > 0.1 then
			raiz.AssemblyAngularVelocity += eje.Unit * 9
			raiz.AssemblyLinearVelocity += c.salida * 2
		end
		task.delay(0.35, function()
			if raiz.Parent then
				sonar("Latas", raiz.Position, azar:NextNumber(1.05, 1.25), 0.22)
			end
		end)
	elseif c.clase == "Cuadro" then
		sonar("CuadroCae", donde, azar:NextNumber(0.95, 1.05), 1)
	else
		sonar("CuadroCae", donde, azar:NextNumber(1.35, 1.6), 0.45)
	end
	return false
end

-- Una cosa empieza a caer: una copia sin anclar empujada fuera del borde (o, lejos de la cámara, ya en el suelo).
local function caer(c: Cosa, semilla: number)
	if c.estado ~= "quieto" or total >= D.Tope or not enSitio(c) then
		return
	end
	total += 1
	c.estado = "cae"
	local camara = workspace.CurrentCamera.CFrame.Position
	if (c.centro - camara).Magnitude > D.Cerca then
		if c.clase == "Vajilla" and not poco() then
			romper(c, c.centro + c.salida * (c.borde + 0.6) - Vector3.new(0, c.centro.Y - c.suelo, 0), semilla, false)
		else
			colocar(c, poseSuelo(c))
			c.estado = "caido"
		end
		return
	end
	-- La copia, pieza a pieza (la misma pieza con sus texturas), soldada a la primera.
	local modelo = Instance.new("Model")
	modelo.Name = c.modelo.Name
	local copias: { BasePart } = {}
	local grupoCae = grupo()
	for i, p in c.partes do
		local copia = p:Clone()
		if not copia then -- no se deja copiar (Archivable): al suelo sin física
			modelo:Destroy()
			colocar(c, poseSuelo(c))
			c.estado = "caido"
			return
		end
		for _, d in copia:GetDescendants() do
			if d:IsA("JointInstance") or d:IsA("Constraint") or d:IsA("WeldConstraint") or d:IsA("LuaSourceContainer") then
				d:Destroy()
			end
		end
		copia.CFrame = p.CFrame
		copia.Anchored = false
		copia.CanCollide = true
		copia.CanQuery = false
		copia.CanTouch = false
		copia.Massless = false
		copia.CollisionGroup = grupoCae
		copia.CustomPhysicalProperties = PhysicalProperties.new(0.8, if c.clase == "Metal" then 0.15 else 0.3, 0.25)
		copia.Parent = modelo
		copias[i] = copia
		if i > 1 then
			local w = Instance.new("WeldConstraint")
			w.Part0 = copias[1]
			w.Part1 = copia
			w.Parent = copia
		end
	end
	esconder(c)
	modelo.Parent = carpeta
	local raiz = copias[1]
	if c.clase == "Cuadro" then
		-- Se suelta del clavo: se separa un poco de la pared y la parte de arriba se va hacia la sala.
		raiz.AssemblyLinearVelocity = c.salida * C.entre(semilla, 500, 1, 2) + Vector3.new(0, 0.5, 0)
		raiz.AssemblyAngularVelocity = Vector3.new(0, 1, 0):Cross(c.salida) * C.entre(semilla, 501, 2, 3.5)
	else
		raiz.AssemblyLinearVelocity = c.salida * C.entre(semilla, 500, D.Empuje[1], D.Empuje[2])
			+ Vector3.new(0, C.entre(semilla, 502, 1.5, 3), 0)
		local vuelca = Vector3.new(0, 1, 0):Cross(c.salida) * C.entre(semilla, 501, 3, 7)
		raiz.AssemblyAngularVelocity = vuelca + Vector3.new(0, C.entre(semilla, 503, -2, 2), 0)
	end
	table.insert(cayendo, { c = c, copias = copias, modelo = modelo, nace = os.clock(), vy = 0, choco = false, semilla = semilla })
	activar()
end

---------------------------------------------------------------- sillas

-- Si hacia `dir` hay una pared o un mueble alto pegado a la silla (no cabe tumbada por ahí).
local function tapado(c: Cosa, dir: Vector3, largo: number, rayo: RaycastParams): number?
	local desde = c.caja.Position
	local golpe = workspace:Raycast(desde, dir * (C.saliente(c.caja.Rotation, c.tam, dir) + largo), rayo)
	if golpe and math.abs(golpe.Normal.Y) < 0.5 then
		return (golpe.Position - desde).Magnitude
	end
	return nil
end

-- Un bicho roza una silla yendo hacia `dir`: se vuelca hacia allí (o hacia el primer lado libre); la mecedora y la
-- silla de ruedas se apartan.
local function volcarSilla(c: Cosa, dir: Vector3)
	if c.estado ~= "quieto" or total >= D.Tope or not enSitio(c) then
		return
	end
	local rayo = filtro({ c.modelo })
	local semilla = C.hash(c.modelo.Name .. "@" .. C.clave(c.x, c.y, c.z))
	local v: Vuelco = {
		c = c, t0 = os.clock(), dura = D.Silla.Segundos, dir = dir, aparta = c.clase == "Aparta", dist = 0, giro = 0,
		rebota = not poco(), sono = false,
	}
	if not v.aparta then
		local libreDir: Vector3? = nil
		local derecha = Vector3.new(0, 1, 0):Cross(dir)
		for _, d in { dir, derecha, -derecha, -dir } do
			if not tapado(c, d, c.tam.Y * 0.8, rayo) then
				libreDir = d
				break
			end
		end
		if libreDir then
			v.dir = libreDir
		else
			v.aparta = true -- encajada: solo se mueve un poco
		end
	end
	if v.aparta then
		local quiere = if c.clase == "Aparta" then D.Mecedora.Aparta else 0.6
		local choca = tapado(c, dir, quiere + 0.3, rayo)
		v.dist = if choca then math.max(0, choca - C.saliente(c.caja.Rotation, c.tam, dir) - 0.3) else quiere
		v.giro = math.rad(D.Mecedora.Giro) * (if C.numero(semilla, 1) < 0.5 then -1 else 1)
		v.dura = D.Mecedora.Segundos
	end
	total += 1
	c.estado = "cae"
	local camara = workspace.CurrentCamera.CFrame.Position
	if (c.centro - camara).Magnitude > D.Cerca then
		v.t0 = -math.huge -- lejos: ya tirada, sin sonido
		v.sono = true
	end
	table.insert(vuelcos, v)
	activar()
end

local function giroVuelco(v: Vuelco, t: number): CFrame
	local c = v.c
	if v.aparta then
		local k = C.aparta(t)
		local centro = c.caja.Position
		return CFrame.new(v.dir * v.dist * k) * CFrame.new(centro) * CFrame.Angles(0, v.giro * k, 0) * CFrame.new(-centro)
	end
	return C.volcar(c.caja, c.tam, v.dir, C.caida(t, v.rebota))
end

---------------------------------------------------------------- golpes

-- Un golpe en `donde` (de una puerta, una ventana o una pisada): cuadros que llevan ya muchos golpes y 1-2 adornos de
-- la sala, siempre los mismos para la misma `clave` y número `n`. `desde` es un punto dentro de la sala (para no tirar
-- lo que hay detrás de una pared).
local function golpe(desde: Vector3, clave: string, n: number, alcance: number, sin: Instance?)
	if not indexado or total >= D.Tope then
		return
	end
	clave ..= "|" .. tostring(workspace:GetAttribute("Noche") or 0) -- cada noche, otras cosas
	local semilla = C.semilla(clave, n)
	local cuantos = C.cuantos(semilla, poco())
	local rayo = filtro(if sin then { sin } else nil)
	local function cerca(c: Cosa): boolean
		return plano(c.centro - desde).Magnitude < alcance and math.abs(c.centro.Y - desde.Y) < D.Planta
	end
	local function seVe(c: Cosa): boolean
		local hasta = c.centro + Vector3.new(0, 0.2, 0)
		local r = workspace:Raycast(desde, hasta - desde, rayo)
		if not r or (r.Position - hasta).Magnitude < 1.2 then
			return true
		end
		local p = r.Instance
		return not (math.abs(r.Normal.Y) < 0.3 and math.max(p.Size.X, p.Size.Y, p.Size.Z) > 6) -- una pared corta
	end
	local lista: { Cosa } = {}
	-- Los cuadros: cada golpe cerca cuenta; el que ya lleva muchos se descuelga (uno por golpe, el que más lleve).
	local cuadro: Cosa? = nil
	for _, c in cosas do
		if c.clase == "Cuadro" and c.apoyo and c.estado == "quieto" and cerca(c) then
			c.golpes += 1
			if c.golpes >= D.CuadroGolpes and enSitio(c) then
				if not cuadro or c.golpes > cuadro.golpes
					or (c.golpes == cuadro.golpes and C.clave(c.x, c.y, c.z) < C.clave(cuadro.x, cuadro.y, cuadro.z)) then
					cuadro = c
				end
			end
		elseif c.apoyo and c.estado == "quieto" and c.clase ~= "Cuadro" and c.clase ~= "Silla" and c.clase ~= "Aparta"
			and cerca(c) and enSitio(c) and seVe(c) then
			table.insert(lista, c)
		end
	end
	local orden: { Cosa } = {}
	if cuadro then
		table.insert(orden, cuadro)
		cuantos -= 1
	end
	for _, c in C.elegir(lista, cuantos, semilla) do
		table.insert(orden, c)
	end
	local esta = noche
	local espera = 0
	for i, c in orden do
		if i == 1 then
			caer(c, C.semilla(clave .. "/" .. C.clave(c.x, c.y, c.z), n))
		else
			espera += C.entre(semilla, 300 + i, 0.15, 0.4) -- el segundo, un momento después
			task.delay(espera, function()
				if noche == esta then
					caer(c, C.semilla(clave .. "/" .. C.clave(c.x, c.y, c.z), n))
				end
			end)
		end
	end
end

-- Dónde está una ventana o puerta y un punto de su sala (atributos del servidor: igual en todos los clientes).
local function sitioDe(el: Model): (Vector3?, Vector3?)
	local centro = el:GetAttribute("Centro")
	if typeof(centro) == "CFrame" then
		return centro.Position, centro.Position - plano(centro.LookVector).Unit * 1.5
	end
	local bisagra, hacia = el:GetAttribute("Bisagra"), el:GetAttribute("Hacia")
	if typeof(bisagra) == "CFrame" and typeof(hacia) == "Vector3" and plano(hacia).Magnitude > 0.1 then
		local pie = bisagra.Position + Vector3.new(0, 3, 0)
		return pie, pie + plano(hacia).Unit * 1.5
	end
	return nil, nil
end

local vigilados: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local function vigilar(el: Instance)
	if vigilados[el] or not el:IsA("Model") then
		return
	end
	vigilados[el] = true
	local antes = el:GetAttribute("Golpes") or 0
	el:GetAttributeChangedSignal("Golpes"):Connect(function()
		local n = el:GetAttribute("Golpes") or 0
		if typeof(n) ~= "number" or typeof(antes) ~= "number" then
			antes = n
			return
		end
		local sube = n > antes
		antes = n
		if not sube then
			return
		end
		local donde, dentro = sitioDe(el :: Model)
		if donde and dentro then
			golpe(dentro, "el:" .. C.clave(donde.X, donde.Y, donde.Z), n, D.Alcance, el)
		end
	end)
end

---------------------------------------------------------------- bichos

-- Cada décima: los bichos dentro de la casa vuelcan las sillas que rozan y, los pesados, tiran cosas al pisar fuerte.
local function mirarBichos()
	local carpetaB = bichosCarpeta
	if not carpetaB or not indexado then
		return
	end
	for _, modelo in carpetaB:GetChildren() do
		local datos = Config.Efectos.Bichos[modelo.Name]
		local raiz = modelo:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not datos or not raiz then
			continue
		end
		local pos = raiz.Position
		local antes = bichoAntes[modelo] or pos
		bichoAntes[modelo] = pos
		if (pos - antes).Magnitude > 8 or not dentroDeCasa(pos) then
			continue -- un salto (aparece, lo mueven) o fuera de la casa
		end
		local pies = pos.Y - datos.Pies
		if datos.Peso >= D.Pisada.Peso then
			local clave = modelo.Name .. ":" .. C.celda(pos.X, pies, pos.Z)
			if not celdas[clave] then
				celdas[clave] = true
				if C.pisadaTira(clave) then
					golpe(Vector3.new(pos.X, pies + 2, pos.Z), clave, 1, D.Pisada.Alcance, nil)
				end
			end
		end
		local movido = plano(pos - antes)
		if movido.Magnitude < 0.05 then
			continue
		end
		for _, c in cosas do
			if (c.clase == "Silla" or c.clase == "Aparta") and c.estado == "quieto" and math.abs(c.suelo - pies) < 3
				and plano(c.caja.Position - pos).Magnitude < 10
				and C.roza(antes, pos, c.caja, c.tam.X / 2, c.tam.Z / 2, D.Roce) then
				volcarSilla(c, movido.Unit)
			end
		end
	end
end

---------------------------------------------------------------- pisar los trozos

local function crujir(p: BasePart, fuerza: number)
	sonar("Cruje", p.Position, azar:NextNumber(1.5, 1.8), 0.25 * fuerza, 0.3)
	p.CFrame *= CFrame.new(azar:NextNumber(-0.05, 0.05), 0, azar:NextNumber(-0.05, 0.05))
		* CFrame.Angles(0, azar:NextNumber(-0.5, 0.5), 0)
end

local cercaTrozos: { BasePart } = {} -- los trozos quietos cerca de la cámara en esta mirada (reutilizada)

local function pisa(quien: Instance, pies: Vector3, fuerza: number)
	for _, p in cercaTrozos do
		local d = p.Position
		if math.abs(d.Y - pies.Y) < 1.6 and Vector2.new(d.X - pies.X, d.Z - pies.Z).Magnitude < D.Pisar then
			local ultimo = crujidos[quien]
			if not ultimo or (pies - ultimo).Magnitude > D.CadaCrujido then
				crujidos[quien] = pies
				crujir(p, fuerza)
			end
			return
		end
	end
end

local function pisadas(camara: Vector3)
	table.clear(cercaTrozos)
	for _, t in trozos do
		if t.quieto and t.p.Name == "Trozo" and (t.p.Position - camara).Magnitude <= D.CercaPisar then
			table.insert(cercaTrozos, t.p)
		end
	end
	if #cercaTrozos == 0 then
		return
	end
	for _, j in Players:GetPlayers() do
		local personaje = j.Character
		local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humano = personaje and personaje:FindFirstChildOfClass("Humanoid")
		if personaje and raiz and humano and humano.Health > 0 then
			pisa(personaje, raiz.Position - Vector3.new(0, humano.HipHeight + raiz.Size.Y / 2, 0), 1)
		end
	end
	local carpetaB = bichosCarpeta
	if carpetaB then
		for _, b in carpetaB:GetChildren() do
			local raiz = b:FindFirstChild("HumanoidRootPart") :: BasePart?
			local datos = Config.Efectos.Bichos[b.Name]
			if raiz and datos then
				pisa(b, raiz.Position - Vector3.new(0, datos.Pies, 0), 1.5)
			end
		end
	end
end

---------------------------------------------------------------- un fotograma

-- Lo llama el Heartbeat (el banco, a mano).
function DesordenVista.paso()
	local ahora = os.clock()
	-- Lo que cae con física: al dar contra el suelo suena (o se rompe); quieto, la pieza de verdad va donde quedó.
	for i = #cayendo, 1, -1 do
		local k = cayendo[i]
		local c = k.c
		local raiz = k.copias[1]
		if not c.modelo.Parent or not raiz.Parent then
			k.modelo:Destroy()
			table.remove(cayendo, i)
			continue
		end
		local v = raiz.AssemblyLinearVelocity
		if not k.choco and C.choca(k.vy, v.Y) and chocar(k, raiz.Position) then
			k.modelo:Destroy()
			table.remove(cayendo, i)
			continue
		end
		k.vy = v.Y
		local edad = ahora - k.nace
		if raiz.Position.Y < c.suelo - 4 then -- se ha ido por un hueco: al suelo, sin física
			k.modelo:Destroy()
			table.remove(cayendo, i)
			colocar(c, poseSuelo(c))
			c.estado = "caido"
		elseif (edad >= D.Anclar and v.Magnitude < 1.2) or edad >= D.AnclarMax then
			table.remove(cayendo, i)
			-- Si ha caído sin que se notara el golpe (de una vez), suena ahora.
			if not k.choco and c.orig[1].Position.Y - raiz.Position.Y > 0.8 and chocar(k, raiz.Position) then
				k.modelo:Destroy()
				continue
			end
			for j, p in c.partes do
				p.CFrame = k.copias[j].CFrame
			end
			c.estado = "caido"
			k.modelo:Destroy()
		end
	end
	-- Sillas que vuelcan y mecedoras que se apartan.
	for i = #vuelcos, 1, -1 do
		local v = vuelcos[i]
		local c = v.c
		if not c.modelo.Parent then
			table.remove(vuelcos, i)
			continue
		end
		local t = math.clamp((ahora - v.t0) / v.dura, 0, 1)
		colocar(c, giroVuelco(v, t))
		if not v.sono and (v.aparta or t >= (if v.rebota then 0.7 else 1)) then
			v.sono = true
			local donde = c.caja.Position
			if v.aparta then
				if Sonido.hay("Mecedora") then
					sonar("Mecedora", donde, azar:NextNumber(0.85, 0.95), 1)
				else
					sonar("Cruje", donde, azar:NextNumber(0.7, 0.8), 0.45, 0.5)
				end
			else
				sonar("Caida", donde, azar:NextNumber(1.7, 1.9), 0.22)
			end
		end
		if t >= 1 then
			c.estado = "caido"
			table.remove(vuelcos, i)
		end
	end
	-- Trozos sueltos: quietos (o como mucho a AnclarMax), se anclan; los que se van por un hueco, fuera.
	for i = #trozos, 1, -1 do
		local t = trozos[i]
		if t.quieto then
			continue
		end
		local edad = ahora - t.nace
		if not t.p.Parent or t.p.Position.Y < -50 then
			t.p:Destroy()
			table.remove(trozos, i)
		elseif (edad >= D.Anclar and t.p.AssemblyLinearVelocity.Magnitude < 1) or edad >= D.AnclarMax then
			t.quieto = true
			t.p.Anchored = true
			t.p.CanCollide = false
		end
	end
	if ahora - ultimaMirada >= 0.1 then
		ultimaMirada = ahora
		mirarBichos()
		if #trozos > 0 then
			pisadas(workspace.CurrentCamera.CFrame.Position)
		end
	end
	local hayBichos = bichosCarpeta ~= nil and bichosCarpeta:FindFirstChildWhichIsA("Model") ~= nil
	if #cayendo == 0 and #vuelcos == 0 and #trozos == 0 and not hayBichos and conexion then
		conexion:Disconnect()
		conexion = nil
	end
end

---------------------------------------------------------------- al amanecer

-- Todo vuelve a su sitio: lo caído, lo volcado y lo roto; los trozos se desvanecen.
local function recoger()
	noche += 1
	for _, k in cayendo do
		k.modelo:Destroy()
	end
	table.clear(cayendo)
	table.clear(vuelcos)
	for _, c in cosas do
		if c.estado ~= "quieto" and c.modelo.Parent then
			colocar(c, CFrame.identity)
		end
		c.estado = "quieto"
		c.golpes = 0
	end
	for _, t in trozos do
		local p = t.p
		p.Anchored = true
		p.CanCollide = false
		TweenService:Create(p, TweenInfo.new(1.5), { Transparency = 1 }):Play()
		task.delay(1.6, p.Destroy, p)
	end
	table.clear(trozos)
	table.clear(celdas)
	total = 0
end

---------------------------------------------------------------- para el banco

function DesordenVista.estado(): { total: number, cayendo: { Model }, trozos: number, caidos: { Model } }
	local l, caidos = {}, {}
	for _, k in cayendo do
		table.insert(l, k.modelo)
	end
	for _, c in cosas do
		if c.estado ~= "quieto" then
			table.insert(caidos, c.modelo)
		end
	end
	return { total = total, cayendo = l, trozos = #trozos, caidos = caidos }
end

-- Las copias que caen ahora, con la pieza de verdad de cada una (para moverlas a mano: el banco no tiene física).
function DesordenVista.copias(): { { copias: { BasePart }, modelo: Model } }
	local l = {}
	for _, k in cayendo do
		table.insert(l, { copias = k.copias, modelo = k.c.modelo })
	end
	return l
end

---------------------------------------------------------------- arranque

function DesordenVista.start()
	carpeta = Instance.new("Folder")
	carpeta.Name = "Desorden"
	carpeta.Parent = workspace

	for _, etiqueta in { "Ventana", "Puerta" } do
		CollectionService:GetInstanceAddedSignal(etiqueta):Connect(vigilar)
		for _, el in CollectionService:GetTagged(etiqueta) do
			vigilar(el)
		end
	end

	workspace:GetAttributeChangedSignal("Fase"):Connect(function()
		if workspace:GetAttribute("Fase") == "Dia" then
			recoger()
		end
	end)

	task.spawn(function()
		local carpetaB = workspace:WaitForChild("Bichos")
		bichosCarpeta = carpetaB
		carpetaB.ChildAdded:Connect(activar)
		if #carpetaB:GetChildren() > 0 then
			activar()
		end
	end)

	-- La casa: se busca lo que se cae al cargar y otra vez cuando cambia (llegan modelos), 2 s después del último
	-- cambio y como mucho cada 15 s (como Efectos).
	task.spawn(function()
		local mapa = workspace:WaitForChild("Mapa")
		local sucio, cambio, ultima = true, os.clock(), -math.huge
		mapa.DescendantAdded:Connect(function(d)
			if d:IsA("Model") then
				local casa = mapa:FindFirstChild("Casa")
				if d == casa or (casa and d:IsDescendantOf(casa)) then
					sucio, cambio = true, os.clock()
				end
			end
		end)
		while true do
			task.wait(1)
			local casa = mapa:FindFirstChild("Casa")
			local ahora = os.clock()
			if sucio and casa and ahora - cambio > 2 and ahora - ultima > 15 then
				sucio, ultima = false, ahora
				indexar(casa)
			end
		end
	end)
end

return DesordenVista
