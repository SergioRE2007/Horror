-- Lo común de los bichos que andan y cazan (Golpeador, Raspador y los que vengan). Cada bicho en el mapa es un objeto
-- de Caza.nuevo: se mueve por la casa abriendo las puertas que le estorban, ve y oye a los jugadores, persigue, saca
-- del escondite a quien vio esconderse y pilla.
--   La luz: Equipo apunta en `iluminado` la última vez que una linterna le dio, y al recibir un flash llama a
--   `alFlash` (si no tiene, se queda aturdido unos segundos).
--   Caza.todos(): los que hay ahora en el mapa (para el flash y la linterna).
--   Agacharse para esconderse (pedido por el usuario, 03-11-2026: "agacharte también debería servir para esconderte,
--   por ejemplo debajo de mesas, y que el monstruo pueda gatear si te huele… que sea útil agacharte es la finalidad").
--   Con los atributos del jugador Agachado y Cubierto (agachado debajo de un mueble: zona "Debajo"), PosturaReglas
--   dice hasta dónde le ven y le oyen. Debajo de algo solo se le nota muy de cerca, pero se le huele: cada bicho lleva
--   su olor de cada uno (`olor`) y, cuando le huele (o le vio meterse), va al borde del mueble (Caza.borde) y gatea a
--   por él (Caza.aPorDebajo; la Bestia también). Mientras gatea, atributos Gatea (dónde está él) y GateaHora en el
--   modelo, para el cliente.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PosturaReglas = require(ReplicatedStorage.Shared.PosturaReglas)
local Casa = require(script.Parent.Casa)
local Mapa = require(script.Parent.Mapa)
local Muerte = require(script.Parent.Muerte)

local Caza = {}
Caza.__index = Caza

export type Opciones = {
	Altura: number, -- de los pies al centro de la raíz
	Andar: number,
	Correr: number,
	Pillar: number,
	Vista: number,
	VioEsconderse: number,
	AltoCamino: number?, -- alto con el que calcula los caminos (8 si no); la Bestia, agachada, para caber al sótano
	Fuera: number?, -- studs fuera del mueble donde se para a gatear (FUERA si no); más si el bicho es más grande
}

-- Alguien debajo de un mueble, visto por un bicho: por dónde se mete a por él.
export type Debajo = {
	zona: BasePart, -- la zona "Debajo" en la que está
	punto: Vector3, -- dónde tenía la raíz al calcularlo
	hora: number, -- os.clock de ese cálculo
	borde: Vector3?, -- dónde se para a gatear, a ras de suelo (nil: no cabe por ningún lado)
	cara: Vector3?, -- la boca del hueco por ese lado, a ras de suelo
}

export type Bicho = typeof(setmetatable({} :: {
	modelo: Model?,
	raiz: BasePart,
	humanoide: Humanoid,
	o: Opciones,
	prisa: boolean, -- deja lo que esté haciendo (amanece o huye)
	aturdido: number, -- os.clock hasta el que está quieto
	iluminado: number, -- os.clock de la última vez que le dio una linterna
	ventana: Model?, -- la ventana a la que está pegado (la persiana bajada le tapa de la luz)
	alFlash: ((Player) -> ())?,
	vistoEn: { [Player]: number },
	olor: { [Player]: number }, -- lo que lleva oliendo a cada uno (PosturaReglas.oler); sin entrada = nada
	olido: number, -- os.clock de la última vez que olió (para el dt)
	debajo: { [Player]: Debajo }, -- el borde por el que se mete a por cada uno (se rehace si se mueve)
	rumbo: Vector3?, -- el borde al que va
	rumboMejor: number, -- lo más cerca que ha estado de él
	rumboDesde: number, -- os.clock desde el que no se acerca más
	rumboVisto: number, -- os.clock de la última vez que fue hacia él
	sinSalida: { SinSalida }, -- los últimos bordes a los que no llegó (no los vuelve a elegir en un rato)
	gateaEn: Vector3?, -- el borde en el que está gateando (los demás bichos no se le meten ahí)
}, Caza))

-- Un borde al que no llegó, hasta `hasta` (os.clock).
type SinSalida = { punto: Vector3, hasta: number }

-- Debajo de los muebles (Config.Postura, a ojo).
local OIDO = Config.Postura.Oido
local FUERA = Config.Postura.Fuera
local CERCA_BORDE = Config.Postura.CercaBorde
local SE_ESCAPA = Config.Postura.SeEscapa
local ATASCO = Config.Postura.Atasco
local MAX_DT = Config.Postura.MaxOlor
local SIN_SALIDA = Config.Postura.SinSalida
local MAX_SIN_SALIDA = 3 -- bordes a los que no llegó que recuerda a la vez

local azar = Random.new()
local vivos: { [Bicho]: boolean } = {}
local carpeta: Folder?

-- Un Path por bicho: ComputeAsync espera, y con uno compartido un bicho leía con GetWaypoints el camino que acababa
-- de calcular otro (con dos ataques a la vez iban a tirones o se atascaban).
local caminos: { [any]: Path } = setmetatable({}, { __mode = "k" }) :: any
local function caminoDe(bicho: any, alto: number): Path
	local c = caminos[bicho]
	if not c then
		c = PathfindingService:CreatePath({
			AgentRadius = 1.6,
			AgentHeight = alto,
			AgentCanJump = false,
			WaypointSpacing = 4,
		})
		caminos[bicho] = c
	end
	return c
end

local filtroVista = RaycastParams.new()
filtroVista.FilterType = Enum.RaycastFilterType.Exclude

local function plano(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function libre(desde: Vector3, hasta: Vector3, ignorar: { Instance }): boolean
	filtroVista.FilterDescendantsInstances = ignorar
	return workspace:Raycast(desde, hasta - desde, filtroVista) == nil
end

local function cabezaDe(jugador: Player): BasePart?
	local personaje = jugador.Character
	return personaje and personaje:FindFirstChild("Head") :: BasePart?
end

local function raizDe(jugador: Player): BasePart?
	local personaje = jugador.Character
	return personaje and personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Para lo que es por dónde cabe el bicho: lo que no choca (las zonas Debajo, adornos) no estorba.
local filtroChoque = RaycastParams.new()
filtroChoque.FilterType = Enum.RaycastFilterType.Exclude
filtroChoque.RespectCanCollide = true

-- Con lo que no cuenta ya puesto en filtroChoque.
local function nadaEntre(desde: Vector3, hasta: Vector3): boolean
	return workspace:Raycast(desde, hasta - desde, filtroChoque) == nil
end

local function despejado(desde: Vector3, hasta: Vector3, ignorar: { Instance }): boolean
	filtroChoque.FilterDescendantsInstances = ignorar
	return nadaEntre(desde, hasta)
end

-- Las zonas "Debajo" (el hueco de debajo de las mesas, en Mapa), al día con las señales: nada de buscarlas cada vez.
local zonas: { BasePart } = {}
local function anadirZona(zona: Instance)
	if zona:IsA("BasePart") and not table.find(zonas, zona) then
		table.insert(zonas, zona)
	end
end
CollectionService:GetInstanceAddedSignal("Debajo"):Connect(anadirZona)
CollectionService:GetInstanceRemovedSignal("Debajo"):Connect(function(zona)
	local i = table.find(zonas, zona :: any)
	if i then
		table.remove(zonas, i)
	end
end)
for _, zona in CollectionService:GetTagged("Debajo") do
	anadirZona(zona)
end

-- ¿Está `p` dentro de la zona, con `holgura` studs de más a los lados? De alto, 2 de más: la raíz de quien está
-- agachado puede quedar algo por encima del hueco.
local function enZona(zona: BasePart, p: Vector3, holgura: number): boolean
	local l = zona.CFrame:PointToObjectSpace(p)
	local m = zona.Size / 2
	return math.abs(l.X) <= m.X + holgura and math.abs(l.Z) <= m.Z + holgura and math.abs(l.Y) <= m.Y + 2
end

local function zonaDe(p: Vector3): BasePart?
	for _, zona in zonas do
		if enZona(zona, p, 0.5) then
			return zona
		end
	end
	return nil
end

-- Por dónde se mete un bicho a por quien está debajo de un mueble. Pura, sin nada del mapa (se prueba con Lune).
--   `caja`, `tam`: la zona Debajo (girada solo de lado: su Y es la vertical); `punto`: dónde está él; `desde`: dónde está
--   el bicho; `fuera`: studs fuera del mueble donde se para; `valido(borde, cara)`: si cabe ahí (paredes, sillas...).
--   Sitios: en los cuatro lados, frente a él y corriéndose a lo largo del lado cada stud (entre dos sillas no cabe: se
--   corre hasta un hueco), siempre a 1 stud de las esquinas (las patas), o en medio si el lado es corto. Prueba antes
--   los más cercanos a él (lo que hay hasta ese lado más lo que se corre); si dos lo están casi igual, el que le pilla
--   de camino al bicho. Devuelve el borde (donde se para, a ras de suelo) y la cara (la boca del hueco frente a él, a
--   ras de suelo) del primero que vale, o nil si no vale ninguno.
function Caza.borde(caja: CFrame, tam: Vector3, punto: Vector3, desde: Vector3, fuera: number,
	valido: ((borde: Vector3, cara: Vector3) -> boolean)?): (Vector3?, Vector3?)
	local p, b = caja:PointToObjectSpace(punto), caja:PointToObjectSpace(desde)
	local mx, my, mz = tam.X / 2, tam.Y / 2, tam.Z / 2
	local x, z = math.clamp(p.X, -mx, mx), math.clamp(p.Z, -mz, mz)
	local sitios = {}
	for _, n in { Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1) } do
		local enX = n.X ~= 0
		local hondo = if enX then mx - n.X * x else mz - n.Z * z -- lo que hay de él a ese lado
		local suyo = if enX then z else x -- dónde está él a lo largo del lado
		local hasta = math.max((if enX then mz else mx) - 1, 0)
		local function anadir(l: number)
			local cara = if enX then Vector3.new(n.X * mx, -my, l) else Vector3.new(l, -my, n.Z * mz)
			local borde = cara + n * fuera
			local alBicho = Vector3.new(borde.X - b.X, 0, borde.Z - b.Z).Magnitude
			table.insert(sitios, { nota = hondo + math.abs(l - suyo) + 0.1 * alBicho, borde = borde, cara = cara })
		end
		local frente = math.clamp(suyo, -hasta, hasta)
		anadir(frente)
		local trozos = math.ceil(hasta * 2)
		for i = 0, trozos do
			local l = if trozos > 0 then -hasta + i * hasta * 2 / trozos else 0
			if math.abs(l - frente) > 0.25 then
				anadir(l)
			end
		end
	end
	table.sort(sitios, function(s1, s2)
		return s1.nota < s2.nota
	end)
	for _, sitio in sitios do
		local borde, cara = caja:PointToWorldSpace(sitio.borde), caja:PointToWorldSpace(sitio.cara)
		if not valido or valido(borde, cara) then
			return borde, cara
		end
	end
	return nil, nil
end

Caza.plano = plano

function Caza.dentroDeCasa(p: Vector3): boolean
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

-- ¿Está `p` en la misma parte del mapa que unos pies en `suelo`? Los dos dentro de la casa o los dos fuera, y en la
-- misma planta: a quien está debajo de un mueble no se le nota a través de las paredes de fuera ni del suelo (si no,
-- la Bestia, aún fuera, iba a por él sin pasar por la puerta principal).
local function mismoSitio(suelo: Vector3, p: Vector3): boolean
	return math.abs(p.Y - suelo.Y) < 8 and Caza.dentroDeCasa(p) == Caza.dentroDeCasa(suelo)
end

-- La carpeta del mapa donde van todos los bichos (el cliente los busca ahí).
function Caza.carpeta(): Folder
	if not carpeta then
		local c = Instance.new("Folder")
		c.Name = "Bichos"
		c.Parent = workspace
		carpeta = c
	end
	return carpeta :: Folder
end

-- Lo que no estorba en los rayos de por dónde cabe y de si alcanza a alguien: los bichos y todos los personajes.
local function sinPersonajes(): { Instance }
	local ignorar: { Instance } = { Caza.carpeta() }
	for _, otro in Players:GetPlayers() do
		if otro.Character then
			table.insert(ignorar, otro.Character)
		end
	end
	return ignorar
end

-- ¿Cabe el bicho en `borde` y está del lado de quien está debajo? Por debajo del tablero (lo que choca de los muebles
-- de HUECOS en Mapa: tablero, patas, caballetes, vigas; y las cajas de las sillas):
--   - Del medio del hueco hasta algo más allá del borde no hay nada (ni pared ni otro mueble): está del lado de él. Sale
--     del medio y no de la boca: si la zona se mete un poco en la pared, desde la boca nacería dentro de ella, no la
--     vería y daría por bueno el borde del otro lado (pillaría a través de la pared).
--   - A los dos lados, de la boca a pasado el borde, tampoco: cabe de ancho (no se cuela entre dos sillas).
--   - En el borde hay suelo a su altura y nada encima (otra mesa, una silla).
-- Los personajes y los bichos no cuentan: van en filtroChoque, que pone debajoDe una vez para todos los sitios.
local ANCHO = Config.Postura.Ancho -- media anchura libre que necesita a los lados
local function sitioLibre(zona: BasePart, borde: Vector3, cara: Vector3): boolean
	local afuera = plano(borde - cara)
	if afuera.Magnitude < 0.01 then
		return false
	end
	afuera = afuera.Unit
	local alto = Vector3.new(0, math.min(1.2, zona.Size.Y / 2), 0)
	local detras = borde + alto + afuera * 1.5 -- y algo de sitio detrás de él
	local medio = cara - afuera * (cara - zona.Position):Dot(afuera) -- en el medio del hueco, frente a la boca
	if not nadaEntre(medio + alto, detras) then
		return false
	end
	local lado = afuera:Cross(Vector3.yAxis) * ANCHO
	local boca = cara + alto + afuera * 0.1
	if not nadaEntre(boca + lado, detras + lado) or not nadaEntre(boca - lado, detras - lado) then
		return false
	end
	local suelo = workspace:Raycast(borde + Vector3.new(0, 4.5, 0), Vector3.new(0, -6, 0), filtroChoque)
	return suelo ~= nil and math.abs(suelo.Position.Y - borde.Y) < 1.2
end

function Caza.nuevo(modelo: Model, humanoide: Humanoid, o: Opciones): Bicho
	local b = setmetatable({
		modelo = modelo,
		raiz = modelo.PrimaryPart :: BasePart,
		humanoide = humanoide,
		o = o,
		prisa = false,
		aturdido = -math.huge,
		iluminado = -math.huge,
		ventana = nil,
		alFlash = nil,
		vistoEn = {},
		olor = {},
		olido = os.clock(),
		debajo = {},
		rumbo = nil,
		rumboMejor = math.huge,
		rumboDesde = 0,
		rumboVisto = -math.huge,
		sinSalida = {},
		gateaEn = nil,
	}, Caza)
	vivos[b] = true
	return b
end

function Caza.todos(): { Bicho }
	local lista = {}
	for b in vivos do
		table.insert(lista, b)
	end
	return lista
end

function Caza.quitar(self: Bicho)
	vivos[self] = nil
	if self.modelo then
		self.modelo:Destroy()
		self.modelo = nil
	end
end

function Caza.cabeza(self: Bicho): Vector3
	local c = self.modelo and self.modelo:FindFirstChild("Cabeza") :: BasePart?
	return if c then c.Position else self.raiz.Position + Vector3.new(0, 3, 0)
end

function Caza.suelo(self: Bicho): Vector3
	return self.raiz.Position - Vector3.new(0, self.o.Altura, 0)
end

function Caza.quieto(self: Bicho): boolean
	return os.clock() < self.aturdido
end

function Caza.aturdir(self: Bicho, segundos: number)
	self.aturdido = math.max(self.aturdido, os.clock() + segundos)
	self.humanoide:MoveTo(self.raiz.Position)
end

function Caza.mirarA(self: Bicho, punto: Vector3)
	self.raiz.CFrame = CFrame.lookAt(self.raiz.Position, Vector3.new(punto.X, self.raiz.Position.Y, punto.Z))
end

-- Abre de un golpe las puertas cerradas que tenga delante.
local function abrirPuertasCerca(self: Bicho)
	for _, puerta in Casa.puertas() do
		local hoja = puerta:FindFirstChild("Hoja") :: BasePart
		local d = hoja.Position - self.raiz.Position
		if math.abs(d.Y) < 7 and plano(d).Magnitude < 5.5 and not Casa.estado(puerta).abierta then
			Casa.abrirPuerta(puerta)
		end
	end
end

-- Para quien se mueve a mano sin pasoHacia (la Bestia por las escaleras): b:abrirPuertas().
Caza.abrirPuertas = abrirPuertasCerca

-- Un paso hacia `destino` (a ras de suelo): recto si no hay nada en medio, si no, por el camino que calcula.
function Caza.pasoHacia(self: Bicho, destino: Vector3)
	if self:quieto() then
		self.humanoide:MoveTo(self.raiz.Position)
		return
	end
	abrirPuertasCerca(self)
	local suelo = self:suelo()
	local altura = Vector3.new(0, self.o.Altura, 0)
	if math.abs(destino.Y - suelo.Y) < 3 and libre(self.raiz.Position, destino + altura, { Caza.carpeta() }) then
		self.humanoide:MoveTo(destino)
		return
	end
	local camino = caminoDe(self, self.o.AltoCamino or 8)
	local ok = pcall(function()
		camino:ComputeAsync(suelo, destino)
	end)
	if ok and camino.Status == Enum.PathStatus.Success then
		for i, punto in camino:GetWaypoints() do
			if i > 1 and (punto.Position - suelo).Magnitude > 3 then
				self.humanoide:MoveTo(punto.Position)
				return
			end
		end
	end
	self.humanoide:MoveTo(destino)
end

function Caza.cerca(self: Bicho, destino: Vector3, distancia: number): boolean
	local suelo = self:suelo()
	return plano(destino - suelo).Magnitude < distancia and math.abs(destino.Y - suelo.Y) < 6
end

-- Anda hasta `destino` (o hasta `limite` segundos o hasta que `seguir` diga que no).
function Caza.irA(self: Bicho, destino: Vector3, velocidad: number, limite: number, seguir: (() -> boolean)?)
	self.humanoide.WalkSpeed = velocidad
	local hasta = os.clock() + limite
	while self.modelo and os.clock() < hasta and not self:cerca(destino, 3) do
		if seguir and not seguir() then
			return
		end
		self:pasoHacia(destino)
		task.wait(0.25)
	end
end

-- Por dónde se mete a por `jugador`, que tiene la raíz en `p` debajo de un mueble (nil si no está en ninguna zona
-- Debajo). Se guarda por jugador y solo se rehace si él se mueve, cambia de mueble o pasan 2 s. Nunca un borde al que
-- no llegó hace poco (sinSalida: así prueba por otro lado; pasado SIN_SALIDA lo vuelve a probar, que si no un mueble
-- con un solo lado libre quedaba seguro para siempre) ni uno en el que ya gatea otro bicho.
local function debajoDe(self: Bicho, jugador: Player, p: Vector3): Debajo?
	local c = self.debajo[jugador]
	local zona = if c and c.zona.Parent and enZona(c.zona, p, 0.5) then c.zona else zonaDe(p)
	if not zona then
		return nil
	end
	local ahora = os.clock()
	if c and c.zona == zona and (c.punto - p).Magnitude < 1 and ahora - c.hora < 2 then
		return c
	end
	filtroChoque.FilterDescendantsInstances = sinPersonajes() -- para todos los sitioLibre de abajo
	local evitar: { Vector3 } = {}
	for i = #self.sinSalida, 1, -1 do
		local s = self.sinSalida[i]
		if ahora > s.hasta then
			table.remove(self.sinSalida, i)
		else
			table.insert(evitar, s.punto)
		end
	end
	for otro in vivos do
		if otro ~= self and otro.gateaEn then
			table.insert(evitar, otro.gateaEn)
		end
	end
	local borde, cara = Caza.borde(zona.CFrame, zona.Size, p, self.raiz.Position, self.o.Fuera or FUERA,
		function(b: Vector3, f: Vector3): boolean
			for _, e in evitar do
				if (b - e).Magnitude < 2 then
					return false
				end
			end
			return sitioLibre(zona, b, f)
		end)
	if c then
		c.zona, c.punto, c.hora, c.borde, c.cara = zona, p, ahora, borde, cara
	else
		c = { zona = zona, punto = p, hora = ahora, borde = borde, cara = cara }
		self.debajo[jugador] = c
	end
	return c
end

-- A quién va a por: el más cercano que ve (o que oye muy cerca), el escondido al que vio esconderse o el que huele
-- debajo de un mueble. Agachado se le ve y se le oye menos, y debajo de algo solo muy de cerca (PosturaReglas).
-- Devuelve el jugador, a dónde ir y, si está debajo de un mueble, por dónde meterse a por él (Caza.aPorDebajo).
function Caza.elegirPresa(self: Bicho, soloFuera: boolean): (Player?, Vector3?, Debajo?)
	local ahora = os.clock()
	local dt = math.clamp(ahora - self.olido, 0, MAX_DT)
	self.olido = ahora
	local mejor, destino, mejorDistancia, mejorDebajo = nil, nil, math.huge, nil
	local ojos = self:cabeza()
	local suelo = self:suelo()
	for _, jugador in Muerte.vivos() do
		local sitio, hora = Muerte.escondite(jugador)
		local suCabeza = cabezaDe(jugador)
		if sitio then
			local visto = self.vistoEn[jugador]
			if hora and visto and hora - visto <= self.o.VioEsconderse and not soloFuera then
				local salida = (sitio:GetAttribute("Salida") :: CFrame).Position - Vector3.new(0, 3, 0)
				local d = (salida - self.raiz.Position).Magnitude
				if d < mejorDistancia then
					mejor, destino, mejorDistancia, mejorDebajo = jugador, salida, d, nil
				end
			end
		elseif suCabeza and not (soloFuera and Caza.dentroDeCasa(suCabeza.Position)) then
			local agachado = jugador:GetAttribute("Agachado") == true
			local cubierto = jugador:GetAttribute("Cubierto") == true
			local olor = self.olor[jugador]
			local suRaiz = if cubierto or olor then raizDe(jugador) else nil
			-- Debajo de algo solo le notan los de su misma parte del mapa.
			local alAlcance = not cubierto or (suRaiz ~= nil and mismoSitio(suelo, suRaiz.Position))
			local d = (suCabeza.Position - ojos).Magnitude
			local loVe = alAlcance and d < PosturaReglas.alcanceVista(self.o.Vista, agachado, cubierto)
				and libre(ojos, suCabeza.Position, { Caza.carpeta(), jugador.Character :: Model })
			local nota = loVe or (alAlcance and d < PosturaReglas.alcanceOido(OIDO, agachado, cubierto))
			local visto = self.vistoEn[jugador]
			if nota then
				self.vistoEn[jugador] = ahora
			end
			-- El olor sube cerca de quien está debajo de algo y se le va olvidando lejos o cuando sale.
			if cubierto or olor then
				local lejos = if cubierto and alAlcance and suRaiz then plano(suRaiz.Position - suelo).Magnitude else math.huge
				local nuevo = PosturaReglas.oler(olor or 0, dt, lejos)
				-- Le nota ahora (muy cerca) o le vio meterse hace nada: sabe dónde está, como con los armarios.
				if cubierto and alAlcance and (nota or (visto and ahora - visto <= self.o.VioEsconderse)) then
					nuevo = Config.Postura.Huele
				end
				olor = if nuevo > 0 then nuevo else nil
				self.olor[jugador] = olor
			end
			local bajo = if cubierto and suRaiz and olor and PosturaReglas.huele(olor)
				then debajoDe(self, jugador, suRaiz.Position)
				else nil
			if bajo then
				-- Le huele debajo de un mueble: al borde (si no cabe por ningún lado, no puede con él).
				local borde = bajo.borde
				local db = if borde then (borde - self.raiz.Position).Magnitude else math.huge
				if borde and db < mejorDistancia then
					mejor, destino, mejorDistancia, mejorDebajo = jugador, borde, db, bajo
				end
			elseif nota and d < mejorDistancia then
				local pies = suCabeza.Position - Vector3.new(0, 4.5, 0)
				mejor, destino, mejorDistancia, mejorDebajo = jugador, pies, d, nil
			end
		end
	end
	return mejor, destino, mejorDebajo
end

-- ¿Sigue a su alcance quien está debajo del mueble al que se mete? Dentro de esa zona, o fuera pero a menos de
-- SE_ESCAPA del borde; y siempre sin nada que choque en medio (nunca a través de una pared). Dentro, el rayo sale de la
-- boca del hueco por dentro: no hay patas ni sillas (están fuera de la zona) y, si la zona cruzase una pared, la ve.
local function sigueAhi(presa: Player, zona: BasePart, borde: Vector3, cara: Vector3): boolean
	local suRaiz = raizDe(presa)
	if not suRaiz or presa.Parent == nil or presa:GetAttribute("Muerto") or Muerte.escondite(presa) then
		return false
	end
	local p = suRaiz.Position
	if enZona(zona, p, 0.5) then
		local afuera = plano(borde - cara)
		local dentro = cara + Vector3.new(0, math.min(1.2, zona.Size.Y / 2), 0)
			- (if afuera.Magnitude > 0.01 then afuera.Unit * 0.1 else Vector3.zero)
		return despejado(dentro, p, sinPersonajes())
	end
	return plano(p - borde).Magnitude <= SE_ESCAPA and despejado(borde + Vector3.new(0, 1.5, 0), p, sinPersonajes())
end

-- Apunta un borde al que no llega (o desde el que no le alcanza): en SIN_SALIDA s no lo vuelve a elegir. Los más viejos
-- se olvidan: no crece sin límite.
local function apuntarSinSalida(self: Bicho, borde: Vector3)
	table.insert(self.sinSalida, { punto = borde, hasta = os.clock() + SIN_SALIDA })
	if #self.sinSalida > MAX_SIN_SALIDA then
		table.remove(self.sinSalida, 1)
	end
end

-- Gatea a por quien está debajo de un mueble (pedido por el usuario: "que el monstruo pueda gatear si te huele… para
-- pillarte debajo de sitios"). Parado en el borde y de cara a él, con los atributos Gatea (dónde está él) y GateaHora
-- (hora del servidor al empezar) en el modelo, que el cliente anima. Cada poco mira si sigue ahí (sigueAhi); a los
-- Config.Postura.Gatear s le pilla, con la cara del susto baja, en la boca del hueco. Lo deja antes si se escapa (y
-- vuelve a olerle desde cero), si le aturden, si amanece o si se quita. Los atributos vuelven a nil siempre.
-- Mientras, no hace nada más. true si le ha pillado.
function Caza.gatear(self: Bicho, presa: Player, bajo: Debajo): boolean
	local modelo, suRaiz = self.modelo, raizDe(presa)
	local zona, borde, cara = bajo.zona, bajo.borde, bajo.cara
	if not modelo or not suRaiz or not borde or not cara then
		return false
	end
	local humanoide = self.humanoide
	local giraba = humanoide.AutoRotate
	self.rumbo = nil
	self.gateaEn = borde
	local ok, pilla = pcall(function(): boolean
		humanoide.AutoRotate = false
		humanoide:MoveTo(self.raiz.Position)
		self:mirarA(suRaiz.Position)
		-- Primero la hora: el cliente que se entera por Gatea ya la tiene.
		modelo:SetAttribute("GateaHora", workspace:GetServerTimeNow())
		modelo:SetAttribute("Gatea", suRaiz.Position)
		local fin = os.clock() + Config.Postura.Gatear
		repeat
			task.wait(0.1)
			if not self.modelo or self.prisa or self:quieto() then
				return false
			elseif not sigueAhi(presa, zona, borde, cara) then
				if presa.Parent then
					self.olor[presa] = 0 -- se le ha escapado: vuelve a olerle desde cero
					-- Sigue debajo pero desde aquí no le alcanza (algo que choca en medio): por otro lado. Si no, muy
					-- cerca le volvía a notar al momento y gateaba y lo dejaba en el mismo borde sin parar.
					local r = raizDe(presa)
					if r and not presa:GetAttribute("Muerto") and enZona(zona, r.Position, 0.5) then
						apuntarSinSalida(self, borde)
						bajo.hora = -math.huge
					end
				end
				return false
			end
		until os.clock() >= fin
		local afuera = plano(borde - cara)
		local susto = cara + Vector3.new(0, math.min(1.5, zona.Size.Y * 0.6), 0)
			+ (if afuera.Magnitude > 0.01 then afuera.Unit * 0.4 else Vector3.zero)
		Muerte.matar(presa, susto)
		self.olor[presa] = nil
		self.debajo[presa] = nil
		return true
	end)
	self.gateaEn = nil
	if modelo.Parent then -- quitado (Destroy), se van con él
		modelo:SetAttribute("Gatea", nil)
		modelo:SetAttribute("GateaHora", nil)
	end
	humanoide.AutoRotate = giraba
	if not ok then
		error(pilla, 0)
	end
	return pilla :: boolean
end

-- Un paso a por quien huele debajo de un mueble (`bajo`, de elegirPresa): hacia el borde con `paso` (Caza.pasoHacia
-- si no; la Bestia, el suyo, que sube escaleras) y, al llegar, gatea. Si en ATASCO s no se acerca al borde (no hay
-- camino), le deja y vuelve a olerle desde cero. "Pilla": le ha pillado; "Deja": le deja (se ha escapado, le han
-- parado o no llega); nil: sigue yendo.
function Caza.aPorDebajo(self: Bicho, presa: Player, bajo: Debajo, paso: ((Bicho, Vector3) -> ())?): ("Pilla" | "Deja")?
	local borde = bajo.borde
	if not borde then
		return "Deja"
	end
	local suelo = self:suelo()
	if self:cerca(borde, CERCA_BORDE) and math.abs(suelo.Y - borde.Y) < 2 then
		for otro in vivos do
			if otro ~= self and otro.gateaEn and (otro.gateaEn - borde).Magnitude < 2 then
				bajo.hora = -math.huge -- otro bicho ya gatea ahí: busca otro lado (o espera a que acabe)
				self.humanoide:MoveTo(self.raiz.Position)
				return nil
			end
		end
		return if self:gatear(presa, bajo) then "Pilla" else "Deja"
	end
	local ahora = os.clock()
	local d = plano(borde - suelo).Magnitude
	-- El mismo borde aunque se corra un poco (si él se mueve debajo): si no, moviéndose no se atascaba nunca.
	local otroBorde = not self.rumbo or plano(borde - self.rumbo).Magnitude > 2
	if otroBorde or ahora - self.rumboVisto > 1 or d < self.rumboMejor - 1 then
		self.rumbo, self.rumboMejor, self.rumboDesde = borde, d, ahora
	elseif ahora - self.rumboDesde > ATASCO then
		self.rumbo = nil
		apuntarSinSalida(self, borde) -- la próxima vez, por otro sitio
		bajo.hora = -math.huge
		self.olor[presa] = 0
		return "Deja"
	else
		self.rumbo = borde
	end
	self.rumboVisto = ahora
	if paso then
		paso(self, borde)
	else
		self:pasoHacia(borde)
	end
	return nil
end

-- Caza durante `duracion` segundos. `soloFuera`: en el bosque, solo a los que están fuera de la casa.
function Caza.cazar(self: Bicho, duracion: number, soloFuera: boolean)
	local fin = os.clock() + duracion
	local ultimoVisto: Vector3? = nil
	local ronda: Vector3? = nil
	while self.modelo and os.clock() < fin and not self.prisa do
		local presa, destino, bajo = self:elegirPresa(soloFuera)
		if self:quieto() then
			self.humanoide:MoveTo(self.raiz.Position)
		elseif presa and destino and bajo then
			-- Le huele debajo de un mueble: al borde, y allí gatea a por él.
			ultimoVisto = destino
			self.humanoide.WalkSpeed = self.o.Correr
			local que = self:aPorDebajo(presa, bajo)
			if que == "Pilla" then
				task.wait(2.5)
			end
			if que then
				ultimoVisto = nil
			end
		elseif presa and destino then
			ultimoVisto = destino
			self.humanoide.WalkSpeed = self.o.Correr
			local escondido = Muerte.escondite(presa) ~= nil
			local suCabeza = cabezaDe(presa)
			-- Sin nada en medio: si no, pillaba a través de las paredes (de 1 stud) a quien oye al otro lado. El rayo sale
			-- de la raíz y no de la cabeza, que va por delante y se mete en la pared cuando la tiene de frente (un rayo que
			-- nace dentro de una pieza no la ve). Las hojas de las puertas abiertas no tapan (CanQuery, Casa.publicar).
			local alcanza = if escondido or not suCabeza then self:cerca(destino, 5)
				else (suCabeza.Position - self.raiz.Position).Magnitude < self.o.Pillar
					and libre(self.raiz.Position, suCabeza.Position, { Caza.carpeta(), presa.Character :: Model })
			if alcanza then
				self.humanoide:MoveTo(self.raiz.Position)
				self:mirarA(if suCabeza then suCabeza.Position else destino) -- de cara a su víctima: el susto le ve la cara
				Muerte.matar(presa, self:cabeza())
				task.wait(2.5)
				ultimoVisto = nil
			else
				self:pasoHacia(destino)
			end
		elseif ultimoVisto then
			self.humanoide.WalkSpeed = self.o.Correr
			self:pasoHacia(ultimoVisto)
			if self:cerca(ultimoVisto, 4) then
				ultimoVisto = nil
			end
		elseif soloFuera then
			return -- en el bosque, si no ve a nadie, se olvida
		else
			self.humanoide.WalkSpeed = self.o.Andar
			if not ronda or self:cerca(ronda, 4) then
				ronda = Mapa.salas[azar:NextInteger(1, #Mapa.salas)]
			end
			self:pasoHacia(ronda :: Vector3)
		end
		task.wait(0.25)
	end
end

Players.PlayerRemoving:Connect(function(jugador)
	for b in vivos do
		b.vistoEn[jugador] = nil
		b.olor[jugador] = nil
		b.debajo[jugador] = nil
	end
end)

return Caza
