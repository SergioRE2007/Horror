-- Mochila de casillas (pedido por el usuario, estilo Resident Evil 4) y los objetos sueltos por el mundo.
-- La lógica de la rejilla está en shared/Rejilla; aquí manda el servidor: el cliente (MochilaUi) solo pide con el
-- remote Mochila: ("Abrir", abierta), ("Mover", id, x, y, girada) o ("Tirar", id).
--   Atributos del jugador: Mochila (la rejilla en JSON, para pintarla), MochilaAbierta (no se mueve mientras),
--   Pilas y Carretes (de repuesto), y los de Equipo: Pila (carga de su linterna) y Fotos (de su cámara).
--   La linterna y la cámara también son objetos: sin ellas en la mochila no hay luz ni flash. Su carga va con el
--   objeto, aunque se tire y lo coja otro.
-- Lo suelto: piezas en workspace.Objetos con atributos Tipo y Carga y un ProximityPrompt "Pick up". Lo tirado sale
-- de delante del jugador con física.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Rejilla = require(ReplicatedStorage.Shared.Rejilla)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Cargar = require(script.Parent.Cargar)
local Mapa = require(script.Parent.Mapa)
local Muerte = require(script.Parent.Muerte)

local Mochila = {}

local M, CAT = Config.Mochila, Config.Objetos
local rejillas: { [Player]: Rejilla.Rejilla } = {}
local carpeta: Folder

-- Tonos de gris para distinguirlos mientras no haya arte.
local COLOR = {
	Pila = Color3.fromRGB(150, 140, 90),
	Carrete = Color3.fromRGB(70, 70, 75),
	Lata = Color3.fromRGB(160, 160, 155),
	Botella = Color3.fromRGB(110, 130, 120),
	Linterna = Color3.fromRGB(60, 60, 60),
	Camara = Color3.fromRGB(45, 45, 48),
	Hacha = Color3.fromRGB(120, 95, 70),
	Movil = Color3.fromRGB(30, 30, 34),
	Chatarra = Color3.fromRGB(118, 92, 72), -- óxido
	Trampa = Color3.fromRGB(85, 82, 78),
	Bateria = Color3.fromRGB(40, 40, 42),
	Radiador = Color3.fromRGB(150, 150, 148),
}

-- La carga con la que sale un objeto nuevo (linterna llena, cámara con el carrete entero).
local function cargaNueva(tipo: string): number?
	if tipo == "Linterna" then
		return 1
	elseif tipo == "Camara" then
		return Config.Flash.Fotos
	elseif tipo == "Movil" then
		return 1
	end
	return nil
end

-- Pasa al jugador lo que el cliente pinta y lo que Equipo usa.
function Mochila.publicar(jugador: Player)
	local r = rejillas[jugador]
	if not r then
		return
	end
	jugador:SetAttribute("Mochila", HttpService:JSONEncode(r))
	jugador:SetAttribute("Pilas", Rejilla.contar(r, "Pila"))
	jugador:SetAttribute("Carretes", Rejilla.contar(r, "Carrete"))
	local linterna = Rejilla.primera(r, "Linterna")
	jugador:SetAttribute("Pila", if linterna then linterna.carga or 0 else 0)
	if not linterna then
		jugador:SetAttribute("Linterna", false)
	end
	local camara = Rejilla.primera(r, "Camara")
	jugador:SetAttribute("Fotos", if camara then camara.carga or 0 else 0)
	local movil = Rejilla.primera(r, "Movil")
	jugador:SetAttribute("Bateria", if movil then movil.carga or 0 else nil) -- nil: no lleva móvil
end

-- La linterna o la cámara que usa (la primera que metió), o nil si no lleva.
function Mochila.primera(jugador: Player, tipo: string): Rejilla.Cosa?
	local r = rejillas[jugador]
	return r and Rejilla.primera(r, tipo)
end

-- Saca de la mochila la primera cosa de ese tipo (la devuelve, o nil si no lleva).
function Mochila.sacar(jugador: Player, tipo: string): Rejilla.Cosa?
	local r = rejillas[jugador]
	local cosa = r and Rejilla.primera(r, tipo)
	if not r or not cosa then
		return nil
	end
	Rejilla.sacar(r, cosa.id)
	Mochila.publicar(jugador)
	return cosa
end

-- Cuántas cosas de ese tipo lleva.
function Mochila.contar(jugador: Player, tipo: string): number
	local r = rejillas[jugador]
	return if r then Rejilla.contar(r, tipo) else 0
end

-- Le da una cosa nueva (con la carga de empezar); si no le cabe, cae a sus pies.
function Mochila.dar(jugador: Player, tipo: string)
	local r = rejillas[jugador]
	local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if r and Rejilla.meter(r, CAT, tipo, cargaNueva(tipo)) then
		Mochila.publicar(jugador)
	elseif raiz then
		Mochila.dejar(tipo, cargaNueva(tipo), raiz.CFrame * CFrame.new(0, -1, -2))
	end
end

-- Gasta una pila o un carrete de repuesto. false si no le quedan.
function Mochila.gastar(jugador: Player, tipo: string): boolean
	local r = rejillas[jugador]
	if not r or not Rejilla.gastar(r, tipo) then
		return false
	end
	Mochila.publicar(jugador)
	return true
end

-- Una pieza suelta en el mundo que se puede coger (Generador también deja así el móvil en el enchufe).
function Mochila.dejar(tipo: string, carga: number?, cf: CFrame, velocidad: Vector3?): BasePart
	local w, h = Rejilla.tamano(CAT, tipo, false)
	local pieza = Instance.new("Part")
	pieza.Name = tipo
	pieza.Size = Vector3.new(w * M.Casilla, 0.3, h * M.Casilla)
	pieza.CFrame = cf
	pieza.Color = COLOR[tipo] or Color3.fromRGB(100, 100, 100)
	pieza.Material = Enum.Material.SmoothPlastic
	pieza:SetAttribute("Tipo", tipo)
	if carga then
		pieza:SetAttribute("Carga", carga)
	end
	if CAT[tipo] and CAT[tipo].Llave then -- llaves de las salas: latón con un brillo flojo para verlas de lejos
		pieza.Color = Color3.fromRGB(150, 118, 58)
		pieza.Material = Enum.Material.Metal
		local luz = Instance.new("PointLight")
		luz.Color = Color3.fromRGB(255, 205, 120)
		luz.Brightness = Config.BrilloLlave.Brillo
		luz.Range = Config.BrilloLlave.Alcance
		luz.Parent = pieza
	end
	CollectionService:AddTag(pieza, "Objeto")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.ActionText = "Pick up"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = Config.Casa.Alcance
	prompt.RequiresLineOfSight = false
	prompt.Parent = pieza
	prompt.Triggered:Connect(function(jugador)
		Mochila.coger(jugador, pieza)
	end)
	pieza.Parent = carpeta
	if velocidad then
		pieza.AssemblyLinearVelocity = velocidad
	end
	return pieza
end

local function puede(jugador: Player): boolean
	return rejillas[jugador] ~= nil and table.find(Muerte.vivos(), jugador) ~= nil and not jugador:GetAttribute("Escondido")
end

-- Coge un objeto suelto si está cerca y cabe.
function Mochila.coger(jugador: Player, pieza: BasePart)
	local r = rejillas[jugador]
	local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not r or not raiz or not puede(jugador) or pieza.Parent ~= carpeta then
		return
	end
	if (pieza.Position - raiz.Position).Magnitude > Config.Casa.Alcance + 2 then
		return
	end
	if jugador:GetAttribute("Cargando") then
		Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "Your hands are full."))
		return
	end
	local tipo = pieza:GetAttribute("Tipo")
	if not Rejilla.meter(r, CAT, tipo, pieza:GetAttribute("Carga")) then
		Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "No room in your backpack."))
		return
	end
	pieza:Destroy()
	Mochila.publicar(jugador)
end

-- Tira una cosa de la mochila delante del jugador.
local function tirar(jugador: Player, id: unknown)
	local r = rejillas[jugador]
	local cabeza = jugador.Character and jugador.Character:FindFirstChild("Head") :: BasePart?
	if not r or not cabeza or not puede(jugador) then
		return
	end
	local cosa = Rejilla.sacar(r, id)
	if not cosa then
		return
	end
	local cf = cabeza.CFrame * CFrame.new(0, -0.8, -1.6)
	Mochila.dejar(cosa.tipo, cosa.carga, cf, cabeza.CFrame.LookVector * 8 + Vector3.new(0, 4, 0))
	Mochila.publicar(jugador)
end

local function abrir(jugador: Player, abierta: boolean)
	if abierta and (not puede(jugador) or jugador:GetAttribute("Cargando") or jugador:GetAttribute("Trabajando")) then
		abierta = false
	end
	jugador:SetAttribute("MochilaAbierta", abierta or nil)
	Cargar.ajustarVelocidad(jugador)
end

local function pedir(jugador: Player, que: unknown, id: unknown, x: unknown, y: unknown, girada: unknown)
	local r = rejillas[jugador]
	if not r then
		return
	end
	if que == "Abrir" then
		abrir(jugador, id == true)
	elseif que == "Mover" then
		-- Si no vale, se vuelve a publicar igual para que el cliente deshaga lo que adelantó.
		Rejilla.mover(r, CAT, id, x, y, girada)
		Mochila.publicar(jugador)
	elseif que == "Tirar" then
		tirar(jugador, id)
	end
end

-- La mochila de bloques a la espalda (los demás la ven; la propia no se ve en primera persona). MochilaUi la pasa
-- delante mientras está abierta.
local function espalda(personaje: Model)
	local torso = (personaje:WaitForChild("UpperTorso", 5) or personaje:FindFirstChild("Torso")) :: BasePart?
	if not torso then
		return
	end
	local pieza = Instance.new("Part")
	pieza.Name = "Mochila"
	pieza.Size = Vector3.new(1.5, 1.7, 0.7)
	pieza.Color = Color3.fromRGB(66, 58, 46)
	pieza.Material = Enum.Material.Fabric
	pieza.CanCollide = false
	pieza.CanQuery = false
	pieza.CanTouch = false
	pieza.Massless = true
	local union = Instance.new("Weld")
	union.Name = "Union"
	union.Part0 = torso
	union.Part1 = pieza
	union.C0 = CFrame.new(0, 0, torso.Size.Z / 2 + 0.4)
	pieza.CFrame = torso.CFrame * union.C0
	union.Parent = pieza
	pieza.Parent = personaje
end

-- La mochila con la que se empieza.
local function deInicio(): Rejilla.Rejilla
	local r = Rejilla.nueva(M.Ancho, M.Alto)
	for _, tipo in M.Inicio do
		Rejilla.meter(r, CAT, tipo, cargaNueva(tipo))
	end
	return r
end

-- Tira al suelo, alrededor de `punto`, una lista de cosas de la rejilla.
local function desparramar(cosas: { Rejilla.Cosa }, punto: Vector3)
	for i, cosa in cosas do
		local angulo = i * 2.4
		local cf = CFrame.new(punto + Vector3.new(math.cos(angulo) * 1.5, 1 + i * 0.3, math.sin(angulo) * 1.5))
		Mochila.dejar(cosa.tipo, cosa.carga, cf * CFrame.Angles(0, angulo, 0))
	end
end

-- Lo que se guarda de su mochila (Partida): { cosas = las de la rejilla }.
function Mochila.exportar(jugador: Player)
	local r = rejillas[jugador]
	if not r then
		return nil
	end
	local cosas = {}
	for _, c in r.cosas do
		table.insert(cosas, { id = c.id, tipo = c.tipo, x = c.x, y = c.y, girada = c.girada, carga = c.carga })
	end
	return { cosas = cosas }
end

-- Le pone la mochila guardada (nil = la de empezar). Lo que ya no cabe cae a sus pies.
function Mochila.importar(jugador: Player, datos)
	if not rejillas[jugador] then
		return
	end
	if datos then
		local r, sobran = Rejilla.desde(datos, CAT, M.Ancho, M.Alto)
		rejillas[jugador] = r
		local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if raiz then
			desparramar(sobran, raiz.Position)
		end
	else
		rejillas[jugador] = deInicio()
	end
	if jugador:GetAttribute("MochilaAbierta") then
		abrir(jugador, false)
	end
	Mochila.publicar(jugador)
end

-- Lo suelto por el mapa, para guardarlo: { tipo, carga, cf }. El móvil del enchufe lo guarda Generador.
function Mochila.sueltos(): { { tipo: string, carga: number?, cf: CFrame } }
	local lista = {}
	for _, pieza in carpeta:GetChildren() do
		if pieza:IsA("BasePart") and not pieza:GetAttribute("Enchufado") then
			table.insert(lista, { tipo = pieza:GetAttribute("Tipo"), carga = pieza:GetAttribute("Carga"), cf = pieza.CFrame })
		end
	end
	return lista
end

-- Quita todo lo suelto y pone lo de la lista.
function Mochila.importarSueltos(lista: { { tipo: string, carga: number?, cf: CFrame } })
	carpeta:ClearAllChildren()
	for _, o in lista do
		Mochila.dejar(o.tipo, o.carga, o.cf)
	end
end

local function alEntrar(jugador: Player)
	rejillas[jugador] = deInicio()
	jugador.CharacterAdded:Connect(espalda)
	if jugador.Character then
		task.spawn(espalda, jugador.Character)
	end
	jugador:SetAttribute("Linterna", false)
	Mochila.publicar(jugador)
	-- Al esconderse o morir se cierra.
	for _, atributo in { "Escondido", "Muerto" } do
		jugador:GetAttributeChangedSignal(atributo):Connect(function()
			if jugador:GetAttribute(atributo) and jugador:GetAttribute("MochilaAbierta") then
				abrir(jugador, false)
			end
		end)
	end
end

function Mochila.start()
	carpeta = Instance.new("Folder")
	carpeta.Name = "Objetos"
	carpeta.Parent = workspace
	for _, o in Mapa.objetos do
		Mochila.dejar(o.tipo, cargaNueva(o.tipo), o.cf)
	end
	Players.PlayerAdded:Connect(alEntrar)
	for _, jugador in Players:GetPlayers() do
		alEntrar(jugador)
	end
	-- Lo que lleva el que se va cae donde estaba, para los demás (Partida ya no se lo guarda a él).
	Players.PlayerRemoving:Connect(function(jugador)
		local r = rejillas[jugador]
		rejillas[jugador] = nil
		local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if r and raiz then
			desparramar(r.cosas, raiz.Position)
		end
	end)
	Remotes.Mochila.OnServerEvent:Connect(pedir)
end

return Mochila
