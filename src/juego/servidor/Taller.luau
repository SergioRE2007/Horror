-- Bancos del taller (Config.Taller): el del sótano (carpintería: tablones reforzados y trampas) y el del garaje (piezas
-- del coche: radiador y batería). Prompt "Workbench" (E): el servidor manda ("Abrir", banco) y TallerUi enseña sus
-- recetas; el cliente pide ("Hacer", n) y aquí se valida todo: vivo, cerca, con lo que pide en la mochila y las cosas
-- pesadas dejadas junto al banco (Config.Taller.Radio). Se trabaja unos segundos a martillazos y, si sale bien, se
-- gasta lo pedido y sale lo hecho: a la mochila o, si es pesado, delante del banco.
-- Trampas: una trampa tirada al suelo (objeto suelto, se guarda como los demás) aturde al primer bicho que pasa cerca
-- y se gasta; a los jugadores no les hace nada.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Prueba = require(ReplicatedStorage.Shared.Prueba)
local Recetas = require(ReplicatedStorage.Shared.Recetas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Cargar = require(script.Parent.Cargar)
local Caza = require(script.Parent.Caza)
local Mochila = require(script.Parent.Mochila)
local Muerte = require(script.Parent.Muerte)

local Taller = {}

local T = Config.Taller
local ocupados: { [Model]: boolean } = {} -- bancos con alguien trabajando

local function raizDe(jugador: Player): BasePart?
	return jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- El banco que tiene cerca (vivo, fuera de un escondite y con las manos libres), o nil.
local function bancoDe(jugador: Player): Model?
	local raiz = raizDe(jugador)
	if not raiz or not table.find(Muerte.vivos(), jugador) or jugador:GetAttribute("Escondido") or jugador:GetAttribute("Cargando")
		or jugador:GetAttribute("Trabajando") or jugador:GetAttribute("MochilaAbierta") then
		return nil
	end
	for _, banco in CollectionService:GetTagged("Banco") do
		local mando = banco:FindFirstChild("Mando") :: BasePart?
		if mando and (mando.Position - raiz.Position).Magnitude <= Config.Casa.Alcance + 2 then
			return banco
		end
	end
	return nil
end

-- Las cosas pesadas sueltas junto al banco, de más cerca a más lejos: [tipo] = { pieza }.
local function pesadosCerca(banco: Model): { [string]: { BasePart } }
	local centro = (banco:FindFirstChild("Mando") :: BasePart).Position
	local cerca: { [string]: { BasePart } } = {}
	for _, pieza in CollectionService:GetTagged("Pesado") do
		if pieza:IsA("BasePart") and Cargar.libre(pieza) and (pieza.Position - centro).Magnitude <= T.Radio then
			local tipo = pieza:GetAttribute("Tipo")
			cerca[tipo] = cerca[tipo] or {}
			table.insert(cerca[tipo], pieza)
		end
	end
	for _, lista in cerca do
		table.sort(lista, function(a, b)
			return (a.Position - centro).Magnitude < (b.Position - centro).Magnitude
		end)
	end
	return cerca
end

-- Lo que hay para esa receta (mochila del jugador y pesados junto al banco).
local function tengo(jugador: Player, banco: Model, receta): ({ [string]: number }, { [string]: { BasePart } })
	local cerca = pesadosCerca(banco)
	local cuenta = {}
	for _, p in receta.Pide do
		cuenta[p[1]] = if Config.Pesados[p[1]] then #(cerca[p[1]] or {}) else Mochila.contar(jugador, p[1])
	end
	return cuenta, cerca
end

local function hacer(jugador: Player, n: unknown)
	local banco = bancoDe(jugador)
	local recetas = banco and T.Bancos[banco:GetAttribute("Banco")]
	local receta = recetas and type(n) == "number" and recetas[n]
	if not banco or not receta then
		return
	end
	if ocupados[banco] then
		Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "Someone is already using it."))
		return
	end
	if #Recetas.falta(receta.Pide, (tengo(jugador, banco, receta))) > 0 then
		Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "You don't have enough."))
		return
	end
	ocupados[banco] = true
	local bien = Cargar.trabajar(jugador, "Fabricar", banco:FindFirstChild("Mando") :: BasePart, receta.Tiempo)
	ocupados[banco] = nil
	-- Se vuelve a mirar al acabar: en esos segundos alguien pudo llevarse algo.
	local cuenta, cerca = tengo(jugador, banco, receta)
	if not bien or #Recetas.falta(receta.Pide, cuenta) > 0 then
		return
	end
	for _, p in receta.Pide do
		for i = 1, p[2] do
			if Config.Pesados[p[1]] then
				cerca[p[1]][i]:Destroy()
			else
				Mochila.sacar(jugador, p[1])
			end
		end
	end
	if Config.Pesados[receta.Da] then
		Cargar.nuevo(receta.Da, banco:GetAttribute("Salida") :: CFrame)
	else
		Mochila.dar(jugador, receta.Da)
	end
	Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "Done."))
end

-- La trampa suelta: de metal y con dientes.
local function vestirTrampa(pieza: Instance)
	if not pieza:IsA("BasePart") or pieza:GetAttribute("Tipo") ~= "Trampa" then
		return
	end
	pieza.Material = Enum.Material.Metal
	for _, lado in { -1, 1 } do
		local diente = Instance.new("Part")
		diente.Name = "Dientes"
		diente.Size = Vector3.new(pieza.Size.X, 0.25, 0.08)
		diente.CFrame = pieza.CFrame * CFrame.new(0, 0.25, pieza.Size.Z * 0.35 * lado) * CFrame.Angles(math.rad(25 * lado), 0, 0)
		diente.Color = Color3.fromRGB(60, 58, 56)
		diente.Material = Enum.Material.Metal
		diente.CanCollide = false
		diente.Massless = true
		local union = Instance.new("WeldConstraint")
		union.Part0, union.Part1 = pieza, diente
		union.Parent = diente
		diente.Parent = pieza
	end
end

-- Cada poco: un bicho cerca de una trampa quieta en el suelo se queda aturdido y la trampa se cierra (se gasta).
local function vigilarTrampas()
	while true do
		task.wait(0.2)
		local bichos = Caza.todos()
		if #bichos == 0 then
			continue
		end
		for _, pieza in CollectionService:GetTagged("Objeto") do
			if not pieza:IsA("BasePart") or pieza:GetAttribute("Tipo") ~= "Trampa" or pieza.AssemblyLinearVelocity.Magnitude > 1 then
				continue
			end
			for _, b in bichos do
				if (Caza.suelo(b) - pieza.Position).Magnitude <= T.Trampa.Radio then
					Caza.aturdir(b, T.Trampa.Aturde)
					Remotes.Taller:FireAllClients("Trampa", pieza.Position)
					pieza:Destroy()
					break
				end
			end
		end
	end
end

local function preparar(banco: Model)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.ActionText = "Workbench"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = Config.Casa.Alcance
	prompt.RequiresLineOfSight = false
	prompt.Parent = banco:WaitForChild("Mando")
	prompt.Triggered:Connect(function(jugador)
		if bancoDe(jugador) == banco then
			Remotes.Taller:FireClient(jugador, "Abrir", banco)
		end
	end)
end

function Taller.start()
	for _, banco in CollectionService:GetTagged("Banco") do
		preparar(banco)
	end
	CollectionService:GetInstanceAddedSignal("Objeto"):Connect(vestirTrampa)
	for _, pieza in CollectionService:GetTagged("Objeto") do
		vestirTrampa(pieza)
	end
	Remotes.Taller.OnServerEvent:Connect(function(jugador, que, n)
		if que == "Hacer" then
			hacer(jugador, n)
		end
	end)
	task.spawn(vigilarTrampas)
	-- Modo de pruebas: ServerStorage.Prueba:Fire("Dar", tipo) le da eso al primer jugador (a la mochila o, si es pesado,
	-- delante de él).
	if Prueba.activa() then
		task.spawn(function() -- el BindableEvent lo crea Director, que arranca después
			ServerStorage:WaitForChild("Prueba").Event:Connect(function(que: string, tipo: string)
				local jugador = Players:GetPlayers()[1]
				local raiz = jugador and raizDe(jugador)
				if que ~= "Dar" or not raiz then
					return
				elseif Config.Pesados[tipo] then
					Cargar.nuevo(tipo, raiz.CFrame * CFrame.new(0, 0, -4))
				elseif Config.Objetos[tipo] then
					Mochila.dar(jugador, tipo)
				end
			end)
		end)
	end
end

return Taller
