-- Lo común de los bichos que andan y cazan (Golpeador, Raspador y los que vengan). Cada bicho en el mapa es un objeto
-- de Caza.nuevo: se mueve por la casa abriendo las puertas que le estorban, ve y oye a los jugadores, persigue, saca
-- del escondite a quien vio esconderse y pilla.
--   La luz: Equipo apunta en `iluminado` la última vez que una linterna le dio, y al recibir un flash llama a
--   `alFlash` (si no tiene, se queda aturdido unos segundos).
--   Caza.todos(): los que hay ahora en el mapa (para el flash y la linterna).
--   Caza.ir(destino): un paso hacia un sitio, también a la otra planta subiendo o bajando recto la escalera del
--   vestíbulo (los caminos no la suben). Lo usa Caza.cazar: todos rondan y persiguen por las dos plantas.
--   Agacharse para esconderse (pedido por el usuario, 03-11-2026: "agacharte también debería servir para esconderte,
--   por ejemplo debajo de mesas, y que el monstruo pueda gatear si te huele… que sea útil agacharte es la finalidad").
--   Con los atributos del jugador Agachado y Cubierto (agachado debajo de un mueble: zona "Debajo"), PosturaReglas
--   dice hasta dónde le ven y le oyen. Debajo de algo solo se le nota muy de cerca, pero se le huele: cada bicho lleva
--   su olor de cada uno (`olor`) y, cuando le huele (o le vio meterse), va al borde del mueble (Caza.borde) y gatea a
--   por él (Caza.aPorDebajo; la Bestia también). Mientras gatea, atributos Gatea (dónde está él) y GateaHora en el
--   modelo, para el cliente.
--   Correr hace ruido (14.8, pedido por el usuario: riesgo y premio): con el atributo Corriendo del jugador le oyen
--   desde Config.Correr.Oido (PosturaReglas.alcanceOido). Lo usan todos los que eligen presa aquí, la Bestia también.
--   Ruidos (15.8, pedido por el usuario: lo pesado que cae o se arrastra lo oye el bicho): Caza.oir da el ruido más
--   cerca que oye y aún no ha ido a mirar (Ruidos; de dentro de la casa a fuera o al revés llega la mitad). Si no ve
--   a nadie, Caza.cazar va corriendo a mirar allí; nunca pilla por un ruido a quien no está allí.
--   Atascos: si rondando o yendo a un ruido no avanza (Config.Caza.Parada s sin acercarse ni moverse: sin camino, algo
--   en medio), cambia de sala y no hace caso a los ruidos un rato (como la `parada` de la Bestia).
--   Persigue: mientras caza, el atributo Persigue del modelo lleva el UserId de su presa (nil sin presa) para el
--   cliente (PavorVista: el latido; AmbienteMiedo: la tensión). El Imitador mientras finge, nunca.
--   Pillar solo sin nada en medio (Caza.alcanza; también la Bestia y el Acechador): ni a través de una pared ni de una
--   puerta cerrada. Al perderte de vista te busca (CazaBusqueda): sigue hacia donde iba, mira a un lado y a otro y
--   recorre las salas de al lado antes de volver a la ronda (que no repite la sala en la que acaba de estar).
--   Sigilo: quieto casi no se te oye, tras una pared o una puerta a la mitad, y con la linterna encendida agacharte
--   no te esconde de la vista (Config.Postura.OirQuieto, OirPared). Las noches de niebla cerrada (Caza.esNiebla, la
--   misma que ve el cliente) tampoco ven lejos si él o tú estáis fuera (Config.Caza.Niebla.Vista); el oído, igual.
--   Puertas: solo abre la que va a cruzar en ese paso (CazaBusqueda.cruzaPuerta), y las que dan fuera (Atacable) nunca
--   desde fuera: esas las rompen los ataques, o la Bestia (Opciones.RompePuertas). Las de dentro con cerrojo (Casa) no
--   las abre de un empujón: si a donde va queda al otro lado, la aporrea pegado a ella hasta reventarla (la Bestia, de
--   un golpe: Opciones.RompeCerrojos). Ve y oye desde los ojos (ojosDe):
--   la cabeza, o justo antes de la pared si la cabeza se le mete en ella.
--   Ni aparecer ni esfumarse a la vista: llegan desde el sitio que nadie ve (Caza.llegadas y Caza.sitioSinVer) y al
--   irse al bosque se alejan hasta que nadie les vea antes de quitarse (Caza.perderse; en la casa, Caza.salir).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local PosturaReglas = require(ReplicatedStorage.Shared.PosturaReglas)
local TiempoNoche = require(ReplicatedStorage.Shared.TiempoNoche)
local Casa = require(script.Parent.Casa)
local CazaBusqueda = require(script.Parent.CazaBusqueda)
local Mapa = require(script.Parent.Mapa)
local Muerte = require(script.Parent.Muerte)
local Ruidos = require(script.Parent.Ruidos)

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
	Espera: number?, -- s quieto tras pillar a alguien (ESPERA si no); el Golpeador, lo que dura su susto (14.10)
	Campo: number?, -- grados a cada lado en los que ve con su Vista entera (Config.Postura.Campo si no)
	SubeEscalera: boolean?, -- false: no sube la escalera del vestíbulo (Caza.ir) y solo ronda su planta
	-- Cómo revienta (bicho, puerta) una puerta de las que dan fuera (Atacable) si su camino la cruza desde fuera y está
	-- cerrada; sin ella, desde fuera no las abre (la Bestia: sus dos golpes y Casa.romper).
	RompePuertas: ((any, Model) -> ())?,
	-- true: revienta de un golpe las puertas de dentro con cerrojo que cruza (la Bestia); sin él, las aporrea (Casa).
	RompeCerrojos: boolean?,
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
	-- Sucesos propios del bicho (14.10, el Golpeador: GolpeadorSucesos) sin cambiar a los demás. Caza.cazar lo llama
	-- con (bicho, momento, presa, destino): "Ronda" en cada paso de ronda (destino = la sala a la que va), "Sala" al
	-- llegar a una sala de ronda y "Presa" al ir a por alguien que ve (no escondido ni debajo de un mueble). Si hace
	-- algo, lo hace entero dentro (mientras, Caza no pilla a nadie) y devuelve algo: true, o con "Presa" un Vector3 (a
	-- dónde ir luego). nil o false: no ha hecho nada.
	alCazar: ((any, string, Player?, Vector3?) -> any)?,
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
	oido: number, -- el número del último ruido al que fue a mirar (Ruidos)
	parado: Parado?, -- desde dónde y cuándo no avanza hacia donde va sin presa (nil: no se está mirando)
	sordoHasta: number, -- os.clock hasta el que no hace caso a los ruidos (tras atascarse)
	rastro: CazaBusqueda.Rastro?, -- dónde vio por última vez a quien persigue y hacia dónde iba (para buscarle)
	subeEscalera: boolean, -- sube la escalera del vestíbulo (Opciones.SubeEscalera)
	trabada: number, -- os.clock desde el que no avanza yendo recto por una escalera (subirRecta); 0: avanza
}, Caza))

-- Yendo sin presa a `destino` (una sala o un ruido): dónde estaba (`punto`) y lo más cerca que estaba (`mejor`) a la
-- hora `hora` (os.clock). Si en PARADA s no se aleja de `punto` ni se acerca a `destino`, se ha atascado.
type Parado = { destino: Vector3, punto: Vector3, mejor: number, hora: number }

-- Un borde al que no llegó, hasta `hasta` (os.clock).
type SinSalida = { punto: Vector3, hasta: number }

-- Debajo de los muebles (Config.Postura, a ojo).
local OIDO = Config.Postura.Oido
local FUERA = Config.Postura.Fuera
local CERCA_BORDE = Config.Postura.CercaBorde
local SE_ESCAPA = Config.Postura.SeEscapa
local ATASCO = Config.Postura.Atasco
local MAX_DT = Config.Postura.MaxOlor
local NIEBLA_VISTA = Config.Caza.Niebla.Vista
local SIN_SALIDA = Config.Postura.SinSalida
local MAX_SIN_SALIDA = 3 -- bordes a los que no llegó que recuerda a la vez
local ESPERA = 2.5 -- s quieto tras pillar a alguien (Opciones.Espera si la tiene)
-- Atascos rondando o yendo a un ruido (Config.Caza, a ojo).
local PARADA = Config.Caza.Parada
local SORDO = Config.Caza.SordoTrasParada

local azar = Random.new()
local vivos: { [Bicho]: boolean } = {}
local carpeta: Folder?

-- Un Path por bicho: ComputeAsync espera, y con uno compartido un bicho leía con GetWaypoints el camino que acababa
-- de calcular otro (con dos ataques a la vez iban a tirones o se atascaban).
local caminos: { [any]: Path } = setmetatable({}, { __mode = "k" }) :: any

-- El último camino calculado de cada Path: se sigue por sus puntos y solo se rehace si el destino se aleja, pasa
-- RUTA_VIDA, se acaba o se tapa (Blocked). Antes se calculaba en cada paso (cada 0,25 s, cada 0,15 s el Acechador): con
-- tres bichos salían 12-20 ComputeAsync por segundo aunque el destino no se moviera.
type Ruta = { destino: Vector3, hora: number, puntos: { Vector3 }, i: number }
local rutas: { [Path]: Ruta } = setmetatable({}, { __mode = "k" }) :: any
local RUTA_VIDA = 1 -- s que vale un camino calculado
local RUTA_MOVIDO = 3 -- studs que se puede mover el destino sin rehacerlo (o la quinta parte de lo que falta, si es más)

local function caminoDe(bicho: any, alto: number): Path
	local c = caminos[bicho]
	if not c then
		local nuevo = PathfindingService:CreatePath({
			AgentRadius = 1.6,
			AgentHeight = alto,
			AgentCanJump = false,
			WaypointSpacing = 4,
		})
		nuevo.Blocked:Connect(function()
			rutas[nuevo] = nil
		end)
		caminos[bicho] = nuevo
		c = nuevo
	end
	return c :: Path
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

-- ¿Hay niebla cerrada ahora? La misma que ve el cliente (CieloVista: TiempoNoche.hayNiebla con Noche y FaseInicio del
-- workspace): de noche y antes de que se levante (Config.Cielo.Niebla.Abre). En Studio, NieblaPrueba la fuerza y
-- TormentaPrueba la quita (como en CieloVista). La tirada se guarda por noche (se mira en cada elegirPresa).
local nieblaDe: { noche: number, inicio: number, hay: boolean }? = nil
function Caza.esNiebla(): boolean
	if workspace:GetAttribute("Fase") ~= "Noche" then
		return false
	end
	local inicio, fin = workspace:GetAttribute("FaseInicio"), workspace:GetAttribute("FaseFin")
	if type(inicio) ~= "number" or type(fin) ~= "number" then
		return false
	end
	local p = (workspace:GetServerTimeNow() - inicio) / math.max(1, fin - inicio)
	if p >= Config.Cielo.Niebla.Abre then
		return false
	end
	if RunService:IsStudio() then
		if workspace:GetAttribute("TormentaPrueba") == true then
			return false
		elseif workspace:GetAttribute("NieblaPrueba") == true then
			return true
		end
	end
	local noche = workspace:GetAttribute("Noche")
	if type(noche) ~= "number" then
		return false
	end
	local guardada = nieblaDe
	if guardada and guardada.noche == noche and guardada.inicio == inicio then
		return guardada.hay
	end
	local hay = TiempoNoche.hayNiebla(noche, inicio, Config.Cielo.Niebla, Config.Tormenta)
	nieblaDe = { noche = noche, inicio = inicio, hay = hay }
	return hay
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
-- Devuelve siempre la misma tabla (FilterDescendantsInstances la copia al ponerla): úsala enseguida, no la guardes.
local ignorarTodos: { Instance } = {}
local function sinPersonajes(): { Instance }
	table.clear(ignorarTodos)
	table.insert(ignorarTodos, Caza.carpeta())
	for _, otro in Players:GetPlayers() do
		if otro.Character then
			table.insert(ignorarTodos, otro.Character)
		end
	end
	return ignorarTodos
end

-- Los bichos y, si se da, un personaje: también la misma tabla siempre, como sinPersonajes.
local ignorarUno: { Instance } = {}
local function sinBichos(personaje: Instance?): { Instance }
	table.clear(ignorarUno)
	table.insert(ignorarUno, Caza.carpeta())
	if personaje then
		table.insert(ignorarUno, personaje)
	end
	return ignorarUno
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
		alCazar = nil,
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
		oido = 0,
		parado = nil,
		sordoHasta = -math.huge,
		rastro = nil,
		subeEscalera = o.SubeEscalera ~= false,
		trabada = 0,
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

-- Para el cliente (PavorVista, AmbienteMiedo): a quién persigue ahora, en el atributo Persigue del modelo (el UserId de
-- `presa`; nil sin presa). Solo se escribe si cambia. El Imitador mientras finge ser una persona en la puerta (sin
-- Abierto, como lo mira el cliente) no lo lleva nunca: lo delataría.
local function publicarPresa(self: Bicho, presa: Player?)
	local modelo = self.modelo
	if not modelo then
		return
	end
	local id = if presa then presa.UserId else nil
	if id and modelo.Name == "Imitador" and modelo:GetAttribute("Abierto") ~= true then
		id = nil
	end
	if modelo:GetAttribute("Persigue") ~= id then
		modelo:SetAttribute("Persigue", id)
	end
end

function Caza.quitar(self: Bicho)
	publicarPresa(self, nil)
	vivos[self] = nil
	local camino = caminos[self]
	if camino then
		caminos[self] = nil
		camino:Destroy() -- y con él su conexión de Blocked
	end
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
	-- Para que el cliente lo enseñe (GolpeadorVista: se tapa la cara): hasta cuándo, en la hora del servidor.
	if self.modelo then
		self.modelo:SetAttribute("Aturdido", workspace:GetServerTimeNow() + (self.aturdido - os.clock()))
	end
end

function Caza.mirarA(self: Bicho, punto: Vector3)
	self.raiz.CFrame = CFrame.lookAt(self.raiz.Position, Vector3.new(punto.X, self.raiz.Position.Y, punto.Z))
end

-- Abre de un golpe las puertas cerradas que va a cruzar. Con `hacia` (el punto al que anda en este paso), solo las que
-- cruza el tramo de la raíz a ese punto, alargado o recortado a PUERTA.Tramo (CazaBusqueda.cruzaPuerta): antes abría
-- todas las de menos de 5,5 studs, y encerrarse en un cuarto no servía y rondando el vestíbulo abría la de la calle. Sin `hacia`
-- (b:abrirPuertas() de la Bestia en la escalera del sótano), todas las de cerca, como siempre. Las que dan fuera
-- (Atacable) nunca desde fuera: esas solo las rompen los ataques, o quien tenga Opciones.RompePuertas si las cruza.
-- El recorte importa sin camino (MoveTo en recta hacia el destino, p. ej. el Trepador tras alguien de arriba): sin él
-- abría de golpe todas las puertas cerradas de esa recta, aunque estuvieran a 30 studs.
-- Con cerrojo (Casa, Config.Casa.Cerrojo) solo la golpea si `meta` (a donde va de verdad: la sala, el ruido, la presa;
-- si no se da, `hacia`) queda al otro lado de la hoja y está pegado a ella (Cerrojo.Cerca): si solo pasa por el
-- pasillo, no. Mientras la aporrea (Casa.abrirPuerta: un golpe cada Cerrojo.Cada s) no cuenta como atasco
-- (self.parado). Con Opciones.RompeCerrojos (la Bestia), revienta al cruzarla.
local PUERTA = Config.Caza.Puerta
local CERROJO = Config.Casa.Cerrojo
local function abrirPuertasCerca(self: Bicho, hacia: Vector3?, meta: Vector3?)
	local raiz = self.raiz.Position
	meta = meta or hacia
	if hacia and plano(hacia - raiz).Magnitude > PUERTA.Tramo then
		hacia = raiz + plano(hacia - raiz).Unit * PUERTA.Tramo
	end
	local largo = if hacia then PUERTA.Tramo else 0
	local fuera: boolean? = nil -- si está fuera de la casa: solo se mira si hace falta
	for _, puerta in Casa.puertas() do
		local hoja = puerta:FindFirstChild("Hoja") :: BasePart
		local d = hoja.Position - raiz
		local estado = Casa.estado(puerta)
		if math.abs(d.Y) >= 7 or estado.abierta then
			continue
		end
		-- La normal de la hoja es su lado más fino (en Mapa, el Z; así vale aunque alguna se haga girada).
		local tam = hoja.Size
		local normal = plano(if tam.X < tam.Z then hoja.CFrame.RightVector else hoja.CFrame.LookVector)
		if hacia then
			local ancho = (puerta:GetAttribute("Ancho") or math.max(tam.X, tam.Z)) :: number
			if plano(d).Magnitude > largo + ancho / 2 + PUERTA.Margen
				or not CazaBusqueda.cruzaPuerta(raiz, hacia, hoja.Position, normal, ancho, PUERTA.Margen, PUERTA.Tramo,
					PUERTA.Tramo)
			then
				continue
			end
		elseif plano(d).Magnitude >= 5.5 then
			continue
		end
		if puerta:GetAttribute("Atacable") then
			if fuera == nil then
				fuera = not Caza.dentroDeCasa(raiz)
			end
			if fuera then
				local romper = self.o.RompePuertas
				if romper and hacia then
					romper(self, puerta) -- espera mientras la revienta: una por paso
					return
				end
				continue
			end
		end
		if estado.cerrojo and not self.o.RompeCerrojos then
			-- Del lado de la raíz y del de `meta` respecto al plano de la hoja: si es el mismo, no tiene que cruzarla.
			local alOtroLado = meta ~= nil and (-d):Dot(normal) * (meta - hoja.Position):Dot(normal) < 0
			if not alOtroLado or plano(d).Magnitude > CERROJO.Cerca then
				continue
			end
			self.parado = nil -- pegado a la puerta, aporreándola: no está atascado
			Casa.abrirPuerta(puerta)
			return -- una por paso
		end
		Casa.abrirPuerta(puerta, self.o.RompeCerrojos)
	end
end

-- Para quien se mueve a mano sin pasoHacia (la Bestia por la escalera del sótano): b:abrirPuertas().
Caza.abrirPuertas = abrirPuertasCerca

-- Un paso hacia `destino` (a ras de suelo): recto si no hay nada en medio, si no, por el camino que calcula.
function Caza.pasoHacia(self: Bicho, destino: Vector3)
	if self:quieto() then
		self.humanoide:MoveTo(self.raiz.Position)
		return
	end
	local suelo = self:suelo()
	local altura = Vector3.new(0, self.o.Altura, 0)
	local camino = caminoDe(self, self.o.AltoCamino or 8)
	if math.abs(destino.Y - suelo.Y) < 3 and libre(self.raiz.Position, destino + altura, sinBichos()) then
		rutas[camino] = nil -- al volver a ir por camino, uno nuevo desde donde esté
		abrirPuertasCerca(self, destino) -- antes de cada MoveTo, con el punto al que anda: solo la que cruza
		self.humanoide:MoveTo(destino)
		return
	end
	local ahora = os.clock()
	local ruta = rutas[camino]
	local movido = math.max(RUTA_MOVIDO, plano(destino - suelo).Magnitude / 5)
	if not ruta or ahora - ruta.hora > RUTA_VIDA or (ruta.destino - destino).Magnitude > movido then
		ruta = nil
		rutas[camino] = nil
		local ok = pcall(function()
			camino:ComputeAsync(suelo, destino)
		end)
		if ok and camino.Status == Enum.PathStatus.Success then
			local puntos = {}
			for _, punto in camino:GetWaypoints() do
				table.insert(puntos, punto.Position)
			end
			ruta = { destino = destino, hora = ahora, puntos = puntos, i = 2 }
			rutas[camino] = ruta
		end
	end
	if ruta then
		-- Al siguiente punto que no haya alcanzado ya (a más de 3 studs).
		while ruta.i <= #ruta.puntos and (ruta.puntos[ruta.i] - suelo).Magnitude <= 3 do
			ruta.i += 1
		end
		if ruta.i <= #ruta.puntos then
			abrirPuertasCerca(self, ruta.puntos[ruta.i], destino)
			self.humanoide:MoveTo(ruta.puntos[ruta.i])
			return
		end
		rutas[camino] = nil -- acabado: el próximo paso calcula otro
	end
	abrirPuertasCerca(self, destino)
	self.humanoide:MoveTo(destino)
end

-- ¿Pilla a `presa` desde aquí? Su cabeza o su raíz a menos de `distancia` de la raíz del bicho y sin nada en medio:
-- si no, pillaba a través de las paredes (de 1 stud) a quien oye al otro lado o tras una puerta cerrada. El rayo sale
-- de la raíz y no de la cabeza, que va por delante y se mete en la pared cuando la tiene de frente (un rayo que nace
-- dentro de una pieza no la ve). Las hojas de las puertas abiertas no tapan (CanQuery, Casa.publicar). Basta con que
-- no haya nada en medio para la vista (libre) o nada que choque (despejado): las paredes y las puertas cerradas tapan
-- las dos cosas, pero lo que no choca (hierba, adornos sueltos) no salva a nadie.
local function aLaVista(desde: Vector3, parte: BasePart?, ignorar: { Instance }): boolean
	return parte ~= nil and (libre(desde, parte.Position, ignorar) or despejado(desde, parte.Position, ignorar))
end

function Caza.alcanza(self: Bicho, presa: Player, distancia: number): boolean
	local suCabeza = cabezaDe(presa)
	local suRaiz = raizDe(presa)
	local desde = self.raiz.Position
	local cabezaCerca = suCabeza ~= nil and (suCabeza.Position - desde).Magnitude < distancia
	local raizCerca = suRaiz ~= nil and (suRaiz.Position - desde).Magnitude < distancia
	if not (cabezaCerca or raizCerca) then
		return false
	end
	local ignorar = sinBichos(presa.Character)
	return aLaVista(desde, suCabeza, ignorar) or aLaVista(desde, suRaiz, ignorar)
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

-- Llegar e irse sin saltos a la vista (Config.Caza, a ojo). Antes, atascado por el camino, golpeaba o raspaba desde
-- lejos y luego entraba de golpe; y al irse sin llegar a la ventana desaparecía delante del jugador.
local LLEGAR_MAS = Config.Caza.LlegarMas
local SALIR_MAX = Config.Caza.SalirMax
local VER_LEJOS = Config.Caza.VerLejos
local IR_SALIDA = 25 -- s andando hacia la salida antes de mirar si le ven (lo de siempre)
-- Aparecer y perderse en el bosque sin verse (sitioSinVer, perderse). A ojo.
local CANDIDATOS = Config.Caza.Candidatos
local PERDERSE_MAX = Config.Caza.PerderseMax
local CABEZA = 1.9 -- de los pies a lo alto de la cabeza, en `Altura` (de los pies al centro de la raíz)
local ANCHO_CUERPO = 3 -- studs de ancho del hueco que necesita para aparecer (Caza.cabe)
local EMPATE = 2 -- studs: si los ven todos, uno más apartado solo gana si lo está por más (si no, el de antes)
local SEGUIR_FUERA = 40 -- studs por delante a los que apunta mientras se pierde

-- ¿Se ve `hasta` desde `desde`? Los cristales de las ventanas y lo casi transparente no tapan: el rayo sigue tras
-- ellos (hasta 4 veces).
local filtroVer = RaycastParams.new()
filtroVer.FilterType = Enum.RaycastFilterType.Exclude
local function seVe(desde: Vector3, hasta: Vector3, ignorar: { Instance }): boolean
	filtroVer.FilterDescendantsInstances = ignorar
	local origen = desde
	for _ = 1, 4 do
		local tramo = hasta - origen
		if tramo.Magnitude < 0.1 then
			return true
		end
		local golpe = workspace:Raycast(origen, tramo, filtroVer)
		if not golpe then
			return true
		end
		if golpe.Instance.Transparency < 0.3 then
			return false
		end
		origen = golpe.Position + tramo.Unit * 0.05
	end
	return false
end

-- ¿Ve alguien vivo lo que hay `alto` studs por encima de `punto`? Rayo desde la cabeza de cada uno (seVe); a más de
-- VER_LEJOS, de noche, no se distingue.
local function seVePunto(punto: Vector3, alto: number): boolean
	local ignorar = sinPersonajes()
	local mira = punto + Vector3.new(0, alto, 0)
	for _, jugador in Players:GetPlayers() do
		local cabeza = if Muerte.vivo(jugador) then cabezaDe(jugador) else nil
		if cabeza and (mira - cabeza.Position).Magnitude < VER_LEJOS and seVe(cabeza.Position, mira, ignorar) then
			return true
		end
	end
	return false
end

-- ¿Se ve a un bicho de `alto` (Opciones.Altura) plantado en `punto`, a ras de suelo? Su raíz o su cabeza, que asoma
-- tras las matas, las rocas y los troncos caídos.
local function seVeCuerpo(punto: Vector3, alto: number): boolean
	return seVePunto(punto, alto) or seVePunto(punto, alto * CABEZA)
end

-- ¿No le ve nadie vivo, ni a él ni el sitio `punto` (a ras de suelo) donde va a aparecer?
function Caza.nadieVe(self: Bicho, punto: Vector3): boolean
	return not seVePunto(self.raiz.Position, 0) and not seVePunto(punto, self.o.Altura)
end

-- Dónde aparecer sin que se vea (antes se creaban de golpe delante de quien estuviese fuera, hasta en el cono de la
-- linterna). De `candidatos` (a ras de suelo, por orden de preferencia), el primero en el que nadie vivo
-- vería a un bicho de `alto` (seVeCuerpo); si se ven todos, el más apartado del vivo que tenga más cerca (a igualdad,
-- por menos de EMPATE, el de antes). Devuelve el sitio y si nadie lo ve.
function Caza.sitioSinVer(candidatos: { Vector3 }, alto: number): (Vector3, boolean)
	local mejor, mejorLejos = candidatos[1], -math.huge
	for _, sitio in candidatos do
		if not seVeCuerpo(sitio, alto) then
			return sitio, true
		end
		local cerca = math.huge
		for _, jugador in Players:GetPlayers() do
			local cabeza = if Muerte.vivo(jugador) then cabezaDe(jugador) else nil
			if cabeza then
				cerca = math.min(cerca, (sitio - cabeza.Position).Magnitude)
			end
		end
		if cerca > mejorLejos + EMPATE then
			mejor, mejorLejos = sitio, cerca
		end
	end
	return mejor, false
end

-- ¿Cabe de pie en `pie` (a ras de suelo) un bicho de `alto`? Nada que choque en su sitio: ni un tronco, ni una roca, ni
-- una pared o un techo (un rayo que nace dentro de una pieza no la ve; esto sí). Lo que no choca (hierba, copas, la
-- linde, que no es para ellos) no estorba. GetPartBoundsInBox compara cajas: una bola se mide con su forma de verdad
-- (bolaEstorba); si no, la colina de la torre (una bola de 140 studs) tapaba un cubo entero a su alrededor y el
-- Acechador no salía nunca cerca de la torre.
local filtroHueco = OverlapParams.new()
filtroHueco.FilterType = Enum.RaycastFilterType.Exclude
filtroHueco.RespectCanCollide = true
-- Una bola grande es suelo y en cuesta: por el lado de arriba de la ladera se mete un poco en el cuerpo. Solo estorba si
-- entra por encima de CUESTA studs sobre lo de abajo del cuerpo (cuestas de hasta unos 45°; si no, ninguna ladera valía).
local CUESTA = ANCHO_CUERPO / 2
local function bolaEstorba(bola: Part, pie: Vector3, total: number): boolean
	local c, medio = bola.Position, ANCHO_CUERPO / 2
	local radio = math.min(bola.Size.X, bola.Size.Y, bola.Size.Z) / 2
	-- El punto del cuerpo (una caja sin girar) más cerca del centro de la bola.
	local cerca = Vector3.new(
		math.clamp(c.X, pie.X - medio, pie.X + medio),
		math.clamp(c.Y, pie.Y + 0.5 + CUESTA, pie.Y + 0.5 + total),
		math.clamp(c.Z, pie.Z - medio, pie.Z + medio)
	)
	return (cerca - c).Magnitude < radio
end
function Caza.cabe(pie: Vector3, alto: number): boolean
	filtroHueco.FilterDescendantsInstances = sinPersonajes()
	local total = alto * CABEZA
	local caja = CFrame.new(pie + Vector3.new(0, 0.5 + total / 2, 0))
	for _, pieza in workspace:GetPartBoundsInBox(caja, Vector3.new(ANCHO_CUERPO, total, ANCHO_CUERPO), filtroHueco) do
		local bola = pieza:IsA("Part") and (pieza :: Part).Shape == Enum.PartType.Ball
		if not bola or bolaEstorba(pieza :: Part, pie, total) then
			return false
		end
	end
	return true
end

-- Por dónde llega desde el bosque a `fuera` (la ventana, la puerta o el pie de la pared; `normal` hacia fuera y `lado`
-- a lo largo de la pared), para Caza.sitioSinVer: `primero` (el sitio de siempre) y, detrás, hasta CANDIDATOS sitios
-- más hondos (90-100 studs) y a un lado o al otro (25-40), alternando. Solo los que tienen hueco para un bicho de
-- `alto` (Caza.cabe); si no cabe en ninguno, `primero` igual.
function Caza.llegadas(primero: Vector3, fuera: Vector3, normal: Vector3, lado: Vector3, alto: number): { Vector3 }
	local lista = {}
	if Caza.cabe(primero, alto) then
		table.insert(lista, primero)
	end
	local signo = if azar:NextNumber() < 0.5 then 1 else -1
	for _ = 2, CANDIDATOS do
		local sitio = fuera + normal * azar:NextNumber(90, 100) + lado * signo * azar:NextNumber(25, 40)
		signo = -signo
		if Caza.cabe(sitio, alto) then
			table.insert(lista, sitio)
		end
	end
	return if #lista > 0 then lista else { primero }
end

-- Anda hasta `destino` como irA y, si no llega (atascado en el bosque o contra algo), no ataca desde lejos: lo pone en
-- `destino` mirando a `mirar` (el centro de la casa si no se da), pero solo cuando nadie le ve; si alguien le ve, sigue
-- andando hasta LLEGAR_MAS s y luego lo pone allí igual. Si `seguir` dice que no (ha visto a alguien) o hay prisa, no
-- lo mueve. Devuelve si está en `destino`.
function Caza.llegarA(self: Bicho, destino: Vector3, velocidad: number, limite: number, seguir: (() -> boolean)?, mirar: Vector3?): boolean
	local cortado = false
	local function sigue(): boolean
		if seguir and not seguir() then
			cortado = true
			return false
		end
		return true
	end
	self:irA(destino, velocidad, limite, sigue)
	local hasta = os.clock() + LLEGAR_MAS
	while self.modelo and not cortado and not self.prisa and not self:cerca(destino, 3) do
		if os.clock() >= hasta or self:nadieVe(destino) then
			-- Fuera de la vista (o ya no hay más remedio): allí de un paso, de cara a la casa.
			local pie = destino + Vector3.new(0, self.o.Altura, 0)
			local hacia = mirar or Vector3.zero
			local frente = Vector3.new(hacia.X, pie.Y, hacia.Z)
			if plano(frente - pie).Magnitude < 0.1 then
				frente = pie + self.raiz.CFrame.LookVector
			end
			local camino = caminos[self]
			if camino then
				rutas[camino] = nil -- el camino que llevaba ya no vale desde aquí
			end
			local modelo = self.modelo :: Model
			modelo:PivotTo(CFrame.lookAt(pie, frente))
			self.humanoide:MoveTo(destino)
			return true
		end
		if not sigue() then
			break
		end
		self:pasoHacia(destino)
		task.wait(0.25)
	end
	return self.modelo ~= nil and self:cerca(destino, 3)
end

-- Se va por `dentro` (la ventana o la puerta por la que entró, o el hogar): anda hasta allí (hasta IR_SALIDA s) y, si
-- no llega, sigue andando hacia allí hasta que nadie le vea (ni a él ni ese sitio) o hasta SALIR_MAX s. Solo después se
-- le puede poner fuera de golpe o quitar: así no desaparece delante de nadie. Anda con Caza.ir y no con irA/pasoHacia:
-- la caza acaba a menudo arriba (persiguen por la escalera del vestíbulo) y las salidas están abajo; los caminos no
-- bajan esa escalera y se quedaba empujando la barandilla de la galería hasta salir de golpe a la vista.
function Caza.salir(self: Bicho, dentro: Vector3, velocidad: number)
	self.humanoide.WalkSpeed = velocidad
	local hasta = os.clock() + IR_SALIDA
	while self.modelo and os.clock() < hasta and not self:cerca(dentro, 3) do
		self:ir(dentro)
		task.wait(0.25)
	end
	hasta = os.clock() + SALIR_MAX
	while self.modelo and os.clock() < hasta and not self:cerca(dentro, 3) and not self:nadieVe(dentro) do
		self:ir(dentro)
		task.wait(0.25)
	end
	if self.modelo then
		self.humanoide:MoveTo(self.raiz.Position)
	end
end

-- La escalera del vestíbulo (Mapa): los caminos no la suben (con los peldaños de arriba sueltos PathfindingService
-- pide saltos), así que se va al pie o a lo alto y se sube o baja recto por el medio (Caza.ir). Antes solo la Bestia
-- sabía: arriba se estaba a salvo de todos los demás.
local PIE_ESCALERA = Vector3.new(0, 1, -21)
local ANTE_PIE = Vector3.new(0, 1, -25) -- delante del pie, para subir siempre de frente
local CIMA_ESCALERA = Vector3.new(0, 14, 6) -- fuera de enEscalera (si no, se queda yendo y viniendo arriba)

-- Los peldaños y el rellano de arriba hasta z 4,5 (la galería empieza en z 0): ahí sigue recto al otro extremo.
local function enEscalera(p: Vector3): boolean
	return math.abs(p.X) < 4.8 and p.Z > -19 and p.Z < 4.5 and p.Y > 1.6 and p.Y < 14.6
end

-- Planta de un punto (pies): 1 arriba (y el desván), 0 abajo, el sótano y fuera. Fuera de la casa siempre 0, aunque
-- esté en alto (la colina y la escalera de la torre, el balcón del porche): si no, a por quien sube la colina se iba a
-- la escalera del vestíbulo (ANTE_PIE) en vez de subir la ladera por los caminos.
local function planta(p: Vector3): number
	return if p.Y > 8 and (Caza.dentroDeCasa(p) or enEscalera(p)) then 1 else 0
end

-- Como Caza.cerca a 3 studs, desde unos pies en `suelo`.
local function junto(suelo: Vector3, p: Vector3): boolean
	return plano(p - suelo).Magnitude < 3 and math.abs(p.Y - suelo.Y) < 6
end

-- Por dónde va de unos pies en `suelo` a `destino` por la escalera del vestíbulo: el punto y si va recto (subirRecta)
-- o por los caminos (pasoHacia). Si no hace falta la escalera, `destino` por los caminos.
function Caza.tramoEscalera(suelo: Vector3, destino: Vector3): (Vector3, boolean)
	local yaEn, aEscalera = enEscalera(suelo), enEscalera(destino)
	if yaEn then
		-- En la escalera: recto hacia quien también está en ella; si no, al extremo de su planta.
		if aEscalera then
			return destino, true
		end
		return if planta(destino) == 1 then CIMA_ESCALERA else PIE_ESCALERA, true
	end
	if planta(suelo) == planta(destino) and not aEscalera then
		return destino, false
	end
	local fin = if aEscalera then destino elseif planta(destino) == 1 then CIMA_ESCALERA else PIE_ESCALERA
	if planta(suelo) == 0 then
		-- Siempre de frente: entrando por un lado del pie, la barandilla (Choque, a 7,5 de alto) le pilla el lomo a la
		-- Bestia y se queda encajada debajo.
		if junto(suelo, ANTE_PIE) or (math.abs(suelo.X) < 2 and suelo.Z > -26 and suelo.Z < -19) then
			return fin, true
		end
		return ANTE_PIE, false
	end
	if junto(suelo, CIMA_ESCALERA) then
		return fin, true
	end
	return CIMA_ESCALERA, false
end

-- Recto por una escalera hasta `hacia`. Andando despacio (rondando o cojeando) el Humanoid se atasca en el primer
-- peldaño: si lleva un momento sin avanzar, un empujón de un peldaño hacia arriba y adelante. Cada bicho lleva su
-- `trabada` (con uno para todos, dos bichos en la escalera se reiniciaban la cuenta el uno al otro).
local filtroEmpujon = RaycastParams.new()
filtroEmpujon.FilterType = Enum.RaycastFilterType.Exclude
function Caza.subirRecta(self: Bicho, hacia: Vector3)
	self.humanoide:MoveTo(hacia)
	local modelo = self.modelo
	local dir = plano(hacia - self.raiz.Position)
	if not modelo or dir.Magnitude < 2 or plano(self.raiz.AssemblyLinearVelocity).Magnitude > 1.5 then
		self.trabada = 0
	elseif self.trabada == 0 then
		self.trabada = os.clock()
	elseif os.clock() - self.trabada > 0.6 then
		self.trabada = 0
		-- Nunca a través de una puerta cerrada, la reja o una pared: a la altura de la raíz solo puede haber aire (los
		-- peldaños quedan por debajo).
		filtroEmpujon.FilterDescendantsInstances = { Caza.carpeta() }
		if workspace:Raycast(self.raiz.Position, dir.Unit * 3, filtroEmpujon) then
			return
		end
		local sube = if hacia.Y > self:suelo().Y + 1 then 1.2 else 0.2
		modelo:PivotTo(modelo:GetPivot() + dir.Unit * 1.2 + Vector3.new(0, sube, 0))
	end
end

-- Un paso hacia `destino` (a ras de suelo), también a la otra planta por la escalera del vestíbulo (tramoEscalera).
-- Los que no la suben (SubeEscalera = false), por los caminos como siempre.
function Caza.ir(self: Bicho, destino: Vector3)
	if self:quieto() then
		self.humanoide:MoveTo(self.raiz.Position)
		return
	end
	if not self.subeEscalera then
		self:pasoHacia(destino)
		return
	end
	local punto, recto = Caza.tramoEscalera(self:suelo(), destino)
	if recto then
		abrirPuertasCerca(self, punto)
		self:subirRecta(punto)
	else
		self:pasoHacia(punto)
	end
end

-- Se va al bosque sin esfumarse a la vista: anda hasta `lejos` como irA (hasta `limite` s) y, si al acabar alguien le
-- ve (seVeCuerpo: atascado, o con alguien fuera), sigue alejándose de la casa en esa misma dirección hasta que nadie le
-- vea o pasen PERDERSE_MAX s. Solo entonces se le puede quitar (lo quita quien lo llama).
function Caza.perderse(self: Bicho, lejos: Vector3, velocidad: number, limite: number)
	self:irA(lejos, velocidad, limite)
	local afuera = plano(lejos)
	if afuera.Magnitude < 1 then
		afuera = plano(self.raiz.CFrame.LookVector)
	end
	afuera = if afuera.Magnitude > 0.01 then afuera.Unit else Vector3.zAxis
	local hasta = os.clock() + PERDERSE_MAX
	local meta = self:suelo() + afuera * SEGUIR_FUERA
	while self.modelo and os.clock() < hasta and seVeCuerpo(self:suelo(), self.o.Altura) do
		if self:cerca(meta, 6) then
			meta = self:suelo() + afuera * SEGUIR_FUERA -- la meta, siempre por delante
		end
		self.humanoide.WalkSpeed = velocidad
		self:pasoHacia(meta)
		task.wait(0.25)
	end
	if self.modelo then
		self.humanoide:MoveTo(self.raiz.Position)
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
	local function libreBorde(b: Vector3, f: Vector3): boolean
		for _, e in evitar do
			if (b - e).Magnitude < 2 then
				return false
			end
		end
		return sitioLibre(zona, b, f)
	end
	local fuera = self.o.Fuera or FUERA
	local borde, cara = Caza.borde(zona.CFrame, zona.Size, p, self.raiz.Position, fuera, libreBorde)
	if not borde and fuera > FUERA then
		-- Los que se paran más lejos (Fuera propio): si así no cabe por ningún lado (una pared cerca), a la de todos,
		-- aunque de pie meta algo el brazo en el tablero. Si no, ni se acercaba.
		borde, cara = Caza.borde(zona.CFrame, zona.Size, p, self.raiz.Position, FUERA, libreBorde)
	end
	if c then
		c.zona, c.punto, c.hora, c.borde, c.cara = zona, p, ahora, borde, cara
	else
		c = { zona = zona, punto = p, hora = ahora, borde = borde, cara = cara }
		self.debajo[jugador] = c
	end
	return c
end

-- Desde dónde ve y oye (CazaBusqueda.ojos): de la cabeza, o 0,2 studs antes de lo que haya entre la raíz y ella. La
-- cabeza va 1,5-3 studs por delante de la raíz y, de frente a una pared, se mete en ella: el rayo nacía dentro, no la
-- veía, y te veía y te oía al otro lado (lo mismo que se arregló en Caza.alcanza). Sin bichos ni personajes en medio.
local function ojosDe(self: Bicho): Vector3
	local raiz = self.raiz.Position
	local cabeza = self:cabeza()
	filtroChoque.FilterDescendantsInstances = sinPersonajes()
	local golpe = workspace:Raycast(raiz, cabeza - raiz, filtroChoque)
	return CazaBusqueda.ojos(raiz, cabeza, if golpe then golpe.Position else nil)
end

-- A quién va a por: el más cercano que ve (o que oye muy cerca), el escondido al que vio esconderse o el que huele
-- debajo de un mueble. Ve de frente (a su espalda solo de cerca); agachado se le ve y se le oye menos, y debajo de algo
-- solo muy de cerca (PosturaReglas).
-- Devuelve el jugador, a dónde ir y, si está debajo de un mueble, por dónde meterse a por él (Caza.aPorDebajo).
function Caza.elegirPresa(self: Bicho, soloFuera: boolean): (Player?, Vector3?, Debajo?)
	local ahora = os.clock()
	local dt = math.clamp(ahora - self.olido, 0, MAX_DT)
	self.olido = ahora
	local mejor, destino, mejorDistancia, mejorDebajo = nil, nil, math.huge, nil
	local ojos = ojosDe(self) -- para el rayo de vista y oído y la distancia; el cono (mira) sale de la raíz
	local suelo = self:suelo()
	-- Niebla cerrada: fuera de la casa tampoco ve lejos (Config.Caza.Niebla.Vista); el oído, igual.
	local niebla = Caza.esNiebla()
	local yoFuera = niebla and not Caza.dentroDeCasa(self.raiz.Position)
	for _, jugador in Players:GetPlayers() do -- Muerte.vivo y no Muerte.vivos(): sin hacer otra lista en cada vuelta
		if not Muerte.vivo(jugador) then
			continue
		end
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
			local suRaiz = raizDe(jugador)
			-- Debajo de algo solo le notan los de su misma parte del mapa.
			local alAlcance = not cubierto or (suRaiz ~= nil and mismoSitio(suelo, suRaiz.Position))
			local hacia = suCabeza.Position - ojos
			local d = hacia.Magnitude
			-- Ve de frente: a su espalda, solo de cerca, salvo si te acaba de ver u oír (PosturaReglas.vistaDeLado).
			local visto = self.vistoEn[jugador]
			local mira, haciaPlano = plano(self.raiz.CFrame.LookVector), plano(hacia)
			local cosAngulo = if mira.Magnitude > 0.01 and haciaPlano.Magnitude > 0.01
				then mira.Unit:Dot(haciaPlano.Unit)
				else 1 -- justo encima o debajo: de frente
			local recienVisto = visto ~= nil and ahora - visto < Config.Postura.Memoria
			-- Sigilo: la linterna encendida te delata aunque vayas agachado; quieto casi no haces ruido; y tras una
			-- pared o una puerta se te oye a la mitad. Un solo rayo para ver y para saber si hay algo en medio.
			local alumbra = jugador:GetAttribute("Linterna") == true
			local corriendo = jugador:GetAttribute("Corriendo") == true -- corriendo hace ruido (14.8)
			local moviendo = suRaiz == nil or plano(suRaiz.AssemblyLinearVelocity).Magnitude > Config.Correr.Moverse
			local vista = PosturaReglas.vistaDeLado(self.o.Vista, cosAngulo, recienVisto, self.o.Campo)
			local fuera = yoFuera or (niebla and not Caza.dentroDeCasa(suCabeza.Position))
			vista = TiempoNoche.vistaConNiebla(vista, niebla, fuera, NIEBLA_VISTA, Config.Postura.VerEspalda)
			local ve = PosturaReglas.alcanceVista(vista, agachado, cubierto, alumbra)
			local oye = PosturaReglas.alcanceOido(OIDO, agachado, cubierto, corriendo, moviendo)
			local despejado = alAlcance
				and d < math.max(ve, oye)
				and libre(ojos, suCabeza.Position, sinBichos(jugador.Character))
			local loVe = despejado and d < ve
			-- Tapado se oye menos (con OirPared < 1 basta con mirar el alcance de sin pared para tirar el rayo).
			local nota = loVe
				or (
					alAlcance
					and d < PosturaReglas.alcanceOido(OIDO, agachado, cubierto, corriendo, moviendo, not despejado)
				)
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

-- El ruido más cerca que oye y al que aún no ha ido (15.8): dónde, o nil. Con `soloFuera`, los de dentro de la casa no.
-- Entre dentro y fuera de la casa llega Config.Cargar.Ruido.Paredes.
function Caza.oir(self: Bicho, soloFuera: boolean): Vector3?
	local yoDentro = Caza.dentroDeCasa(self.raiz.Position)
	local punto, visto = Ruidos.oir(self.raiz.Position, self.oido, function(p: Vector3): number
		local dentro = Caza.dentroDeCasa(p)
		if soloFuera and dentro then
			return 0
		end
		return if dentro == yoDentro then 1 else Config.Cargar.Ruido.Paredes
	end)
	self.oido = visto
	return punto
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
-- vuelve a olerle desde cero), si le aturden, si amanece, si se quita o si él muere de otra cosa (sin vida, o Muerto:
-- se va sin rugir y sigue con lo suyo). Los atributos vuelven a nil siempre.
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
			if not self.modelo or self.prisa or self:quieto() or not Muerte.vivo(presa) then
				return false -- muerto de otra cosa: su olor ya lo ha borrado Muerte.alMorir (no se vuelve a poner)
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
		return Muerte.matar(presa, susto, modelo) -- false si acaba de morir de otra cosa: nada que esperar
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
-- si no; Caza.cazar, Caza.ir, que sube la escalera del vestíbulo; la Bestia, el suyo, que además baja al sótano) y, al llegar, gatea. Si en ATASCO s no se acerca al borde (no hay
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

-- Yendo sin presa a `destino`: true si en PARADA s no se ha acercado más de 1 stud ni se ha movido de donde estaba (y
-- ahora va parado): no tiene camino o algo le tapa y empujaba la pared. Un destino nuevo, acercarse o moverse empiezan
-- la cuenta otra vez.
local function atascado(self: Bicho, destino: Vector3): boolean
	local ahora = os.clock()
	local aqui = self.raiz.Position
	local d = plano(destino - self:suelo()).Magnitude
	local p = self.parado
	if not p or plano(p.destino - destino).Magnitude > 2 or d < p.mejor - 1 or plano(aqui - p.punto).Magnitude > 1 then
		self.parado = { destino = destino, punto = aqui, mejor = d, hora = ahora }
		return false
	end
	if ahora - p.hora < PARADA or plano(self.raiz.AssemblyLinearVelocity).Magnitude >= 1 then
		return false
	end
	self.parado = nil
	return true
end

-- Búsqueda al perder de vista a quien perseguía (CazaBusqueda, Config.Caza.Busca, a ojo). Antes, al llegar a donde le
-- vio sin verle, elegía una sala al azar de toda la casa: bastaba doblar una esquina para que se fuera a la otra punta.
local BUSCA = Config.Caza.Busca

-- Un punto de la búsqueda: a dónde va y, si al llegar se para a mirar a un lado y a otro, hacia dónde (de frente).
type PuntoBusca = { punto: Vector3, mirar: Vector3? }
type Busca = {
	puntos: { PuntoBusca },
	i: number, -- el punto al que va
	desde: number, -- os.clock desde el que va a ese punto (Busca.Limite)
	mirando: number?, -- os.clock desde el que está parado mirando
}

-- Mientras le ve: dónde y hacia dónde iba el bicho (si va parado, lo de antes).
local function apuntarRastro(self: Bicho, punto: Vector3)
	local antes = self.rastro
	local dir = CazaBusqueda.rumbo(self.raiz.AssemblyLinearVelocity, BUSCA.Rumbo)
	self.rastro = { punto = punto, dir = dir or (antes and antes.dir), hora = os.clock() }
end

-- Al llegar a `llegada` (donde le vio por última vez) sin verle: si el rastro es reciente, sigue hacia donde iba (y si
-- hay pared, se para Busca.Margen antes: no empuja la pared), mira a un lado y a otro, y luego las Busca.Salas salas
-- de al lado de esa planta. nil: rastro viejo (vuelve a la ronda).
local function planBusca(self: Bicho, llegada: Vector3): Busca?
	local rastro = self.rastro
	self.rastro = nil
	if not rastro or not CazaBusqueda.vigente(rastro, os.clock(), BUSCA.Memoria) then
		return nil
	end
	local puntos: { PuntoBusca } = {}
	local base = llegada
	local dir = rastro.dir
	if dir then
		filtroChoque.FilterDescendantsInstances = sinPersonajes()
		local golpe = workspace:Raycast(self.raiz.Position, dir * BUSCA.Adelante, filtroChoque)
		-- Desde donde está él (el rayo sale de ahí), no desde `llegada`: si se quedó algo antes, se metería en la pared.
		local avance = CazaBusqueda.avance(BUSCA.Adelante, if golpe then golpe.Distance else nil, BUSCA.Margen)
		base = self:suelo() + dir * avance
		table.insert(puntos, { punto = base, mirar = dir })
	else
		table.insert(puntos, { punto = llegada, mirar = plano(self.raiz.CFrame.LookVector) })
	end
	for _, sala in CazaBusqueda.salasCerca(Mapa.salas, base, BUSCA.Salas, BUSCA.Planta, 4) do
		table.insert(puntos, { punto = sala })
	end
	return { puntos = puntos, i = 1, desde = os.clock(), mirando = nil }
end

-- Un paso de la búsqueda. Devuelve la sala a la que acaba de llegar (para no repetirla en la ronda), si llega a una.
local function buscar(self: Bicho, busca: Busca): Vector3?
	local p = busca.puntos[busca.i]
	if not p then
		return nil
	end
	local ahora = os.clock()
	if busca.mirando then
		self.humanoide:MoveTo(self.raiz.Position)
		local t = ahora - busca.mirando
		if t < BUSCA.Mirar then
			self:mirarA(self.raiz.Position + CazaBusqueda.mirada(p.mirar :: Vector3, t, BUSCA.Mirar, BUSCA.Giro))
			return nil
		end
		busca.mirando = nil
		busca.i += 1
		busca.desde = ahora
		return nil
	end
	local llega = self:cerca(p.punto, 4)
	if llega or ahora - busca.desde > BUSCA.Limite then
		if p.mirar then
			busca.mirando = ahora
			self.humanoide:MoveTo(self.raiz.Position)
			return nil
		end
		busca.i += 1
		busca.desde = ahora
		if llega then
			if self.alCazar then
				self.alCazar(self, "Sala", nil, p.punto) -- como al llegar a una sala de ronda (el Golpeador: Olfatea)
			end
			return p.punto
		end
		return nil
	end
	-- Al sitio hacia el que iba, corriendo; por las salas de al lado, andando (escuchando).
	self.humanoide.WalkSpeed = if busca.i == 1 then self.o.Correr else self.o.Andar
	self:ir(p.punto)
	return nil
end

-- Una sala a la que ir rondando (Mapa.salas: las dos plantas) que no sea `ultima` (CazaBusqueda.otraSala); los que
-- no suben la escalera, solo las de su planta.
local function salaDeRonda(self: Bicho, ultima: Vector3?): Vector3
	if self.subeEscalera then
		return CazaBusqueda.otraSala(Mapa.salas, ultima, azar)
	end
	local suya = planta(self:suelo())
	local lista = {}
	for _, sala in Mapa.salas do
		if planta(sala) == suya then
			table.insert(lista, sala)
		end
	end
	local de = if #lista > 0 then lista else Mapa.salas
	return CazaBusqueda.otraSala(de, ultima, azar)
end

-- Caza durante `duracion` segundos. `soloFuera`: en el bosque, solo a los que están fuera de la casa.
-- Si se le acaba el tiempo pegado a su presa (vista, no escondida en un armario) no la deja en seco: sigue mientras la
-- tenga, PRORROGA s como mucho. Nunca con prisa (amanece o huye) ni en el bosque.
local PRORROGA = Config.Caza.Prorroga
function Caza.cazar(self: Bicho, duracion: number, soloFuera: boolean)
	local fin = os.clock() + duracion
	local tope = if soloFuera then fin else fin + PRORROGA
	local conPresa = false -- en el último paso tenía presa
	local ultimoVisto: Vector3? = nil
	local ronda: Vector3? = nil
	self.parado = nil
	local busca: Busca? = nil
	local ultimaSala: Vector3? = nil -- la última sala que miró: la ronda al azar no la repite
	self.rastro = nil
	while self.modelo and not self.prisa do
		local ahora = os.clock()
		if ahora >= tope or (ahora >= fin and not conPresa) then
			break
		end
		local presa, destino, bajo = self:elegirPresa(soloFuera)
		publicarPresa(self, presa)
		conPresa = presa ~= nil and Muerte.escondite(presa) == nil
		-- Adónde va este paso sin presa por su cuenta (sala o ruido), para ver si se atasca; nil: no cuenta (quieto, con
		-- presa o lo ha hecho un suceso).
		local yendo: Vector3? = nil
		if not presa and os.clock() >= self.sordoHasta then
			local oido = self:oir(soloFuera)
			if oido then
				ultimoVisto = oido -- lo ha oído (15.8): va corriendo a mirar allí
			end
		end
		if self:quieto() then
			self.humanoide:MoveTo(self.raiz.Position)
		elseif presa and destino and bajo then
			-- Le huele debajo de un mueble: al borde, y allí gatea a por él.
			busca = nil
			ultimoVisto = destino
			apuntarRastro(self, destino)
			self.humanoide.WalkSpeed = self.o.Correr
			local que = self:aPorDebajo(presa, bajo, Caza.ir)
			if que == "Pilla" then
				task.wait(self.o.Espera or ESPERA)
			end
			if que then
				ultimoVisto = nil
				self.rastro = nil
			end
		elseif presa and destino then
			busca = nil
			ultimoVisto = destino
			self.humanoide.WalkSpeed = self.o.Correr
			-- Un suceso propio al verle (el Golpeador: Quieto), entero antes de seguir: mientras, no le pilla.
			local tras = if self.alCazar then self.alCazar(self, "Presa", presa, destino) else nil
			if tras then
				if typeof(tras) == "Vector3" then
					ultimoVisto = tras
				end
				apuntarRastro(self, ultimoVisto :: Vector3)
			else
				apuntarRastro(self, destino)
				local escondido = Muerte.escondite(presa) ~= nil
				local suCabeza = cabezaDe(presa)
				local alcanza = if escondido or not suCabeza then self:cerca(destino, 5)
					else self:alcanza(presa, self.o.Pillar)
				if alcanza then
					self.humanoide:MoveTo(self.raiz.Position)
					self:mirarA(if suCabeza then suCabeza.Position else destino) -- de cara a su víctima: el susto le ve la cara
					Muerte.matar(presa, self:cabeza(), self.modelo)
					task.wait(self.o.Espera or ESPERA)
					ultimoVisto = nil
					self.rastro = nil
				else
					self:ir(destino)
				end
			end
		elseif ultimoVisto then
			self.humanoide.WalkSpeed = self.o.Correr
			self:ir(ultimoVisto)
			if self:cerca(ultimoVisto, 4) then
				-- Ha llegado y no le ve: le busca por ahí (si el rastro es reciente) antes de volver a la ronda.
				busca = if soloFuera then nil else planBusca(self, ultimoVisto)
				ultimoVisto = nil
				ronda = nil
			else
				yendo = ultimoVisto
			end
		elseif busca then
			ultimaSala = buscar(self, busca) or ultimaSala
			if busca.i > #busca.puntos then
				busca = nil
			end
		elseif soloFuera then
			break -- en el bosque, si no ve a nadie, se olvida
		else
			self.humanoide.WalkSpeed = self.o.Andar
			if ronda and self:cerca(ronda, 4) then
				local llegada = ronda
				ronda = nil
				ultimaSala = llegada
				if self.alCazar then
					self.alCazar(self, "Sala", nil, llegada) -- un suceso propio al llegar (el Golpeador: Olfatea)
				end
			end
			if not ronda then
				ronda = salaDeRonda(self, ultimaSala)
			end
			-- Un suceso propio de ronda (el Golpeador: Armario, Garras); si lo hace, este paso ya está.
			if not (self.alCazar and self.alCazar(self, "Ronda", nil, ronda)) then
				self:ir(ronda :: Vector3)
				yendo = ronda
			end
		end
		if not yendo then
			self.parado = nil -- lo de este paso no cuenta: empieza de cero
		elseif atascado(self, yendo) then
			-- No avanza: a otra sala y sordo un rato (el ruido sin camino le volvía a llevar contra la misma pared).
			ultimoVisto = nil
			busca = nil
			ronda = CazaBusqueda.otraSala(Mapa.salas, ronda, azar)
			self.sordoHasta = os.clock() + SORDO
		end
		-- Mirando a un lado y a otro, más a menudo: si no, gira a saltos.
		task.wait(if busca and busca.mirando then 0.1 else 0.25)
	end
	publicarPresa(self, nil)
end

-- Lo que sabe cada bicho de un jugador: al irse y al morir. Al morir y no al revivir: muerto no está en elegirPresa
-- (solo mira a los vivos) y nada se lo vuelve a poner, así que da igual para el olor; pero así vale para todas las
-- formas de revivir (amanecer, Revivir pagando) sin engancharse a cada una, y al revivir debajo del mismo mueble no
-- le huelen de golpe con lo de antes (ni cuenta que le vieron meterse: vistoEn).
local function olvidar(jugador: Player)
	for b in vivos do
		b.vistoEn[jugador] = nil
		b.olor[jugador] = nil
		b.debajo[jugador] = nil
	end
end
Players.PlayerRemoving:Connect(olvidar)
Muerte.alMorir(olvidar)

return Caza
