-- Lo común de los bichos que andan y cazan (Golpeador, Raspador y los que vengan). Cada bicho en el mapa es un objeto
-- de Caza.nuevo: se mueve por la casa abriendo las puertas que le estorban, ve y oye a los jugadores, persigue, saca
-- del escondite a quien vio esconderse y pilla.
--   La luz: Equipo apunta en `iluminado` la última vez que una linterna le dio, y al recibir un flash llama a
--   `alFlash` (si no tiene, se queda aturdido unos segundos).
--   Caza.todos(): los que hay ahora en el mapa (para el flash y la linterna).
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")

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
}, Caza))

local azar = Random.new()
local vivos: { [Bicho]: boolean } = {}
local carpeta: Folder?

local camino = PathfindingService:CreatePath({
	AgentRadius = 1.6,
	AgentHeight = 8,
	AgentCanJump = false,
	WaypointSpacing = 4,
})

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

Caza.plano = plano

function Caza.dentroDeCasa(p: Vector3): boolean
	return math.abs(p.X) < 27 and math.abs(p.Z) < 23
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

-- A quién va a por: el más cercano que ve (o que oye muy cerca), o el escondido al que vio esconderse.
-- Devuelve el jugador y a dónde ir.
function Caza.elegirPresa(self: Bicho, soloFuera: boolean): (Player?, Vector3?)
	local ahora = os.clock()
	local mejor, destino, mejorDistancia = nil, nil, math.huge
	local ojos = self:cabeza()
	for _, jugador in Muerte.vivos() do
		local sitio, hora = Muerte.escondite(jugador)
		local suCabeza = cabezaDe(jugador)
		if sitio then
			local visto = self.vistoEn[jugador]
			if hora and visto and hora - visto <= self.o.VioEsconderse and not soloFuera then
				local salida = (sitio:GetAttribute("Salida") :: CFrame).Position - Vector3.new(0, 3, 0)
				local d = (salida - self.raiz.Position).Magnitude
				if d < mejorDistancia then
					mejor, destino, mejorDistancia = jugador, salida, d
				end
			end
		elseif suCabeza and not (soloFuera and Caza.dentroDeCasa(suCabeza.Position)) then
			local d = (suCabeza.Position - ojos).Magnitude
			local loVe = d < self.o.Vista and libre(ojos, suCabeza.Position, { Caza.carpeta(), jugador.Character :: Model })
			if loVe or d < 8 then
				self.vistoEn[jugador] = ahora
				if d < mejorDistancia then
					local pies = suCabeza.Position - Vector3.new(0, 4.5, 0)
					mejor, destino, mejorDistancia = jugador, pies, d
				end
			end
		end
	end
	return mejor, destino
end

-- Caza durante `duracion` segundos. `soloFuera`: en el bosque, solo a los que están fuera de la casa.
function Caza.cazar(self: Bicho, duracion: number, soloFuera: boolean)
	local fin = os.clock() + duracion
	local ultimoVisto: Vector3? = nil
	local ronda: Vector3? = nil
	while self.modelo and os.clock() < fin and not self.prisa do
		local presa, destino = self:elegirPresa(soloFuera)
		if self:quieto() then
			self.humanoide:MoveTo(self.raiz.Position)
		elseif presa and destino then
			ultimoVisto = destino
			self.humanoide.WalkSpeed = self.o.Correr
			local escondido = Muerte.escondite(presa) ~= nil
			local suCabeza = cabezaDe(presa)
			local alcanza = if escondido or not suCabeza then self:cerca(destino, 5)
				else (suCabeza.Position - self.raiz.Position).Magnitude < self.o.Pillar
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
	end
end)

return Caza
