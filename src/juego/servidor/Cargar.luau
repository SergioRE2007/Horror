-- Cosas pesadas en las manos con física (pedido por el usuario): troncos, tablones, bidón, piezas del coche. Frenan.
-- Cada una tiene un Peso: cuántos hacen falta para levantarla (el motor, entre dos).
-- Cada uno que la coge tira de su agarre con un AlignPosition que solo levanta Config.Cargar.Fuerza veces el peso de
-- la cosa: con todos los que hacen falta sube; con menos no llega y se arrastra por el suelo.
--   Atributos del jugador: Cargando (el tipo de lo que lleva). El cliente (CargarVista) pide soltar con el remote Cargar.
--   Se suelta sola al esconderse, al morir o si se queda atascada lejos.
--   Con R se usa con algo (Cargar.alUsar): serrar en el caballete, clavar en una ventana o puerta, echar gasolina.
-- Mientras se lleva no choca con los jugadores (grupos de colisión "Cargado" y "Personajes").
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Mapa = require(script.Parent.Mapa)
local Muerte = require(script.Parent.Muerte)

local Cargar = {}

local C, PESADOS = Config.Cargar, Config.Pesados
type Agarre = { pieza: BasePart, punto: Attachment, empuje: AlignPosition }
local agarres: { [Player]: Agarre } = {}
local quienes: { [BasePart]: { Player } } = {}
local carpeta: Folder

local COLOR = {
	Tronco = { Color3.fromRGB(86, 66, 50), Enum.Material.Wood },
	Tablon = { Color3.fromRGB(140, 115, 85), Enum.Material.WoodPlanks },
	Bidon = { Color3.fromRGB(110, 30, 25), Enum.Material.Metal },
	Motor = { Color3.fromRGB(70, 72, 75), Enum.Material.DiamondPlate },
}

local function humanoideDe(jugador: Player): Humanoid?
	return jugador.Character and jugador.Character:FindFirstChildOfClass("Humanoid")
end

local function raizDe(jugador: Player): BasePart?
	return jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Velocidad y salto según lo que lleva y si tiene la mochila abierta (Mochila también lo llama).
function Cargar.ajustarVelocidad(jugador: Player)
	local humanoide = humanoideDe(jugador)
	if not humanoide then
		return
	end
	local factor, salto = 1, true
	if jugador:GetAttribute("MochilaAbierta") then
		factor, salto = 0, false
	end
	if jugador:GetAttribute("Trabajando") then
		factor, salto = 0, false
	end
	local agarre = agarres[jugador]
	if agarre then
		local peso = agarre.pieza:GetAttribute("Peso")
		local cuantos = #(quienes[agarre.pieza] or {})
		factor = math.min(factor, if cuantos >= peso then C.Frena[peso] else C.Arrastrar)
		salto = false
	end
	humanoide.WalkSpeed = StarterPlayer.CharacterWalkSpeed * factor
	humanoide.JumpHeight = if salto then StarterPlayer.CharacterJumpHeight else 0
	humanoide.JumpPower = if salto then StarterPlayer.CharacterJumpPower else 0
end

-- Rehace lo que comparten todos los que la llevan: quién la simula, cómo se orienta y si se puede coger.
local function rehacer(pieza: BasePart)
	local lista = quienes[pieza] or {}
	local peso = pieza:GetAttribute("Peso")
	;(pieza:FindFirstChild("Giro") :: AlignOrientation).Enabled = #lista > 0
	if #lista == 0 then
		pieza:SetNetworkOwnershipAuto()
	elseif #lista == 1 then
		pieza:SetNetworkOwner(lista[1]) -- uno solo: la simula su cliente para que vaya suave
	else
		pieza:SetNetworkOwner(nil) -- entre varios, el servidor
	end
	pieza.CollisionGroup = if #lista > 0 then "Cargado" else "Default"
	-- Lo que lleva uno solo no choca con nada: al girarse en una sala se atascaba en las paredes y se caía.
	pieza.CanCollide = #lista ~= 1
	local prompt = pieza:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = #lista < peso and not pieza:GetAttribute("Trabajo")
	end
	for _, j in lista do
		Cargar.ajustarVelocidad(j)
	end
end

function Cargar.soltar(jugador: Player)
	local agarre = agarres[jugador]
	if not agarre then
		return
	end
	agarres[jugador] = nil
	agarre.punto:Destroy()
	local lista = quienes[agarre.pieza]
	local i = lista and table.find(lista, jugador)
	if i then
		table.remove(lista, i)
	end
	jugador:SetAttribute("Cargando", nil)
	if agarre.pieza.Parent then
		rehacer(agarre.pieza)
	end
	Cargar.ajustarVelocidad(jugador)
end

local function puede(jugador: Player): boolean
	return table.find(Muerte.vivos(), jugador) ~= nil and not jugador:GetAttribute("Escondido")
		and not jugador:GetAttribute("MochilaAbierta") and not agarres[jugador] and not jugador:GetAttribute("Trabajando")
end

local function coger(jugador: Player, pieza: BasePart)
	local raiz = raizDe(jugador)
	local lista = quienes[pieza]
	local peso = pieza:GetAttribute("Peso")
	if not raiz or not puede(jugador) or #lista >= peso then
		return
	end
	if (pieza.Position - raiz.Position).Magnitude > Config.Casa.Alcance + pieza.Size.Magnitude / 2 then
		return
	end
	-- Lo de uno, por el centro; lo de varios, por el extremo más cerca que esté libre.
	local agarre = Vector3.zero
	if peso > 1 then
		local mitad = pieza.Size.X / 2
		local lado = if pieza.CFrame:PointToObjectSpace(raiz.Position).X >= 0 then 1 else -1
		for _, otro in lista do
			if agarres[otro].punto.Position.X * lado > 0 then
				lado = -lado
			end
		end
		agarre = Vector3.new(mitad * lado, 0, 0)
	end
	local punto = Instance.new("Attachment")
	punto.Name = "Agarre"
	punto.Position = agarre
	punto.Parent = pieza
	local fuerzaPeso = pieza.AssemblyMass * workspace.Gravity
	local empuje = Instance.new("AlignPosition")
	empuje.Mode = Enum.PositionAlignmentMode.OneAttachment
	empuje.Attachment0 = punto
	empuje.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	empuje.ForceRelativeTo = Enum.ActuatorRelativeTo.World
	empuje.MaxAxesForce = Vector3.new(fuerzaPeso * 2, fuerzaPeso * C.Fuerza * (if peso > 1 then 1 else 2), fuerzaPeso * 2)
	empuje.Responsiveness = 30
	empuje.Position = punto.WorldPosition
	empuje.Parent = punto
	agarres[jugador] = { pieza = pieza, punto = punto, empuje = empuje }
	table.insert(lista, jugador)
	jugador:SetAttribute("Cargando", pieza:GetAttribute("Tipo"))
	if peso > #lista then
		Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "Too heavy. You need someone else."))
	end
	rehacer(pieza)
end

-- Una cosa pesada nueva en el mundo. `carga`: la gasolina del bidón (0..1; lleno si no se dice).
function Cargar.nuevo(tipo: string, cf: CFrame, carga: number?): BasePart
	local datos = PESADOS[tipo]
	local pieza = Instance.new("Part")
	pieza.Name = tipo
	pieza.Size = Vector3.new(datos.Tam[1], datos.Tam[2], datos.Tam[3])
	pieza.CFrame = cf
	pieza.Color, pieza.Material = COLOR[tipo][1], COLOR[tipo][2]
	if tipo == "Tronco" then
		pieza.Shape = Enum.PartType.Cylinder -- tumbado: el cilindro va a lo largo de X
	end
	pieza:SetAttribute("Tipo", tipo)
	pieza:SetAttribute("Peso", datos.Peso)
	if tipo == "Bidon" then
		pieza:SetAttribute("Carga", carga or 1)
	end
	CollectionService:AddTag(pieza, "Pesado")
	local giro = Instance.new("AlignOrientation")
	giro.Name = "Giro"
	giro.Mode = Enum.OrientationAlignmentMode.OneAttachment
	giro.Attachment0 = Instance.new("Attachment", pieza)
	giro.MaxTorque = pieza.AssemblyMass * workspace.Gravity * 40
	giro.Responsiveness = 15
	giro.Enabled = false
	giro.Parent = pieza
	local prompt = Instance.new("ProximityPrompt")
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.ActionText = "Carry"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = Config.Casa.Alcance
	prompt.RequiresLineOfSight = false
	prompt.Parent = pieza
	prompt.Triggered:Connect(function(jugador)
		coger(jugador, pieza)
	end)
	quienes[pieza] = {}
	pieza.Parent = carpeta
	return pieza
end

-- Lo pesado del mapa, para guardarlo (Partida): { tipo, carga (la gasolina del bidón), cf }.
function Cargar.sueltos(): { { tipo: string, carga: number?, cf: CFrame } }
	local lista = {}
	for _, pieza in carpeta:GetChildren() do
		if pieza:IsA("BasePart") then
			table.insert(lista, { tipo = pieza:GetAttribute("Tipo"), carga = pieza:GetAttribute("Carga"), cf = pieza.CFrame })
		end
	end
	return lista
end

-- Todos sueltan lo que llevan, se quita todo lo pesado y se pone lo de la lista (lo que se trabajaba se deja).
function Cargar.importar(lista: { { tipo: string, carga: number?, cf: CFrame } })
	for jugador in agarres do
		Cargar.soltar(jugador)
	end
	carpeta:ClearAllChildren()
	table.clear(quienes)
	for _, p in lista do
		Cargar.nuevo(p.tipo, p.cf, p.carga)
	end
end

-- Lo que se hace con lo que llevas en las manos (R o el botón): serrar un tronco en el caballete, clavar un tablón,
-- echar gasolina. Cada sistema registra el suyo con Cargar.alUsar(tipo, uso):
--   etiquetas: a qué se le puede hacer (CollectionService; el objetivo tiene un "Mando").
--   preparar(jugador, objetivo, pieza) -> (cf, segundos): dónde se queda la pieza mientras se trabaja; nil si no vale
--   (preparar avisa del porqué). terminar(jugador, objetivo, pieza): al acabar; la pieza sigue anclada ahí, así que
--   la quita o la devuelve con Cargar.liberar.
-- Mientras se trabaja: atributo Trabajando del jugador (la acción) y no se mueve; si muere o se esconde, se deja.
export type Uso = {
	etiquetas: { string },
	accion: string,
	preparar: (Player, Instance, BasePart) -> (CFrame?, number?),
	terminar: (Player, Instance, BasePart) -> (),
	cancelar: ((Player, Instance, BasePart) -> ())?, -- si se deja a medias (antes de soltar la pieza)
}
local usos: { [string]: Uso } = {}

function Cargar.alUsar(tipo: string, uso: Uso)
	usos[tipo] = uso
end

-- Devuelve al mundo con física una pieza que estaba anclada trabajando.
function Cargar.liberar(pieza: BasePart, cf: CFrame?)
	pieza:SetAttribute("Trabajo", nil)
	if cf then
		pieza.CFrame = cf
	end
	pieza.Anchored = false
	rehacer(pieza)
end

local function usar(jugador: Player, objetivo: unknown)
	local agarre = agarres[jugador]
	local raiz = raizDe(jugador)
	if not agarre or not raiz or typeof(objetivo) ~= "Instance" or jugador:GetAttribute("Trabajando") then
		return
	end
	local pieza = agarre.pieza
	local uso = usos[pieza:GetAttribute("Tipo")]
	if not uso or #quienes[pieza] > 1 then
		return
	end
	local vale = false
	for _, etiqueta in uso.etiquetas do
		vale = vale or CollectionService:HasTag(objetivo, etiqueta)
	end
	local mando = objetivo:FindFirstChild("Mando")
	if not vale or not mando or not mando:IsA("BasePart") or (mando.Position - raiz.Position).Magnitude > Config.Casa.Alcance + 4 then
		return
	end
	local cf, segundos = uso.preparar(jugador, objetivo, pieza)
	if not cf or not segundos then
		return
	end
	Cargar.soltar(jugador)
	pieza:SetAttribute("Trabajo", true)
	pieza.Anchored = true
	pieza.CFrame = cf
	pieza.CollisionGroup = "Cargado"
	local prompt = pieza:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = false
	end
	jugador:SetAttribute("Trabajando", uso.accion)
	Cargar.ajustarVelocidad(jugador)
	Remotes.Trabajo:FireAllClients(jugador, uso.accion, pieza, segundos)
	local fin = os.clock() + segundos
	while os.clock() < fin do
		task.wait(0.1)
		if not pieza.Parent or not table.find(Muerte.vivos(), jugador) or jugador:GetAttribute("Escondido") then
			jugador:SetAttribute("Trabajando", nil)
			Cargar.ajustarVelocidad(jugador)
			if uso.cancelar then
				uso.cancelar(jugador, objetivo, pieza)
			end
			if pieza.Parent then
				Cargar.liberar(pieza) -- a medias: se cae donde estaba
			end
			Remotes.Trabajo:FireAllClients(jugador, "Parar", pieza, 0)
			return
		end
	end
	jugador:SetAttribute("Trabajando", nil)
	Cargar.ajustarVelocidad(jugador)
	uso.terminar(jugador, objetivo, pieza)
end

-- Cada fotograma: cada agarre va delante de quien lo lleva; si se queda atascado lejos, se suelta.
local function seguir()
	for jugador, agarre in agarres do
		local raiz = raizDe(jugador)
		if not raiz or not agarre.pieza.Parent or not table.find(Muerte.vivos(), jugador) or jugador:GetAttribute("Escondido") then
			Cargar.soltar(jugador)
			continue
		end
		local pieza = agarre.pieza
		local plano = raiz.CFrame.LookVector * Vector3.new(1, 0, 1)
		local frente = if plano.Magnitude > 0.01 then plano.Unit else Vector3.zAxis
		local lista = quienes[pieza]
		-- Lo largo de uno (troncos, tablones) va a lo largo, hacia delante: atravesado no cabía por las puertas.
		local largo = pieza:GetAttribute("Peso") == 1 and pieza.Size.X > 3
		local fondo = if pieza:GetAttribute("Peso") > 1 then 0 elseif largo then pieza.Size.X / 2 - 1.2 else pieza.Size.Z / 2
		local destino = raiz.Position + frente * (C.Delante + 0.8 + fondo) - Vector3.new(0, 0.6, 0)
		agarre.empuje.Position = destino
		-- Uno solo: lo largo hacia delante y lo demás atravesado; entre dos, de uno al otro (cada uno coge un extremo).
		local eje = if largo then frente else frente:Cross(Vector3.yAxis)
		if #lista >= 2 and lista[1] == jugador then
			local otra = raizDe(lista[2])
			local entre = if otra then (otra.Position - raiz.Position) * Vector3.new(1, 0, 1) else Vector3.zero
			if entre.Magnitude > 0.5 then
				eje = entre.Unit * (if agarre.punto.Position.X < 0 then 1 else -1)
			end
		end
		if #lista == 1 or lista[1] == jugador then
			(pieza:FindFirstChild("Giro") :: AlignOrientation).CFrame = CFrame.fromMatrix(Vector3.zero, eje, Vector3.yAxis)
		end
		if (agarre.punto.WorldPosition - destino).Magnitude > C.Suelta then
			Cargar.soltar(jugador)
		end
	end
end

local function grupoPersonaje(personaje: Model)
	for _, parte in personaje:GetDescendants() do
		if parte:IsA("BasePart") then
			parte.CollisionGroup = "Personajes"
		end
	end
	personaje.DescendantAdded:Connect(function(parte)
		if parte:IsA("BasePart") then
			parte.CollisionGroup = "Personajes"
		end
	end)
end

function Cargar.start()
	PhysicsService:RegisterCollisionGroup("Cargado")
	PhysicsService:RegisterCollisionGroup("Personajes")
	PhysicsService:CollisionGroupSetCollidable("Cargado", "Personajes", false)
	carpeta = Instance.new("Folder")
	carpeta.Name = "Pesados"
	carpeta.Parent = workspace
	for _, p in Mapa.pesados do
		Cargar.nuevo(p.tipo, p.cf)
	end
	local function alEntrar(jugador: Player)
		jugador.CharacterAdded:Connect(grupoPersonaje)
		if jugador.Character then
			grupoPersonaje(jugador.Character)
		end
		jugador.CharacterRemoving:Connect(function()
			Cargar.soltar(jugador)
		end)
	end
	Players.PlayerAdded:Connect(alEntrar)
	for _, jugador in Players:GetPlayers() do
		alEntrar(jugador)
	end
	Players.PlayerRemoving:Connect(Cargar.soltar)
	Remotes.Cargar.OnServerEvent:Connect(Cargar.soltar)
	Remotes.Usar.OnServerEvent:Connect(usar)
	RunService.Heartbeat:Connect(seguir)
end

return Cargar
