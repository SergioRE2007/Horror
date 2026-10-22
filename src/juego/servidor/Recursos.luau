-- Talar y serrar (pedido por el usuario: talar con golpes que astillan). Con bloques grises de momento.
--   Árboles (etiqueta "Arbol", los pone Mapa: solo los finos de cerca de la casa): con el hacha en la mochila, cada E
--   es un hachazo (Config.Talar.Cada entre uno y otro). Atributos del árbol: Golpes y GolpesMax (el cliente ahonda el
--   corte) y Talado (la noche en que cayó). Al último hachazo cae con física hacia el lado contrario de quien lo tala y,
--   al quedarse quieto en el suelo, se parte en troncos (cosas pesadas de Cargar). Queda el tocón; a las
--   Config.Talar.Rebrota noches vuelve a crecer (al amanecer).
--   Caballete: con un tronco en las manos, R (Cargar.alUsar "Tronco"): se sierra y salen tablones al lado.
-- Las animaciones van en el cliente (TrabajoVista) con el remote Trabajo.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Stats = require(ReplicatedStorage.Shared.Stats)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Cargar = require(script.Parent.Cargar)
local Ciclo = require(script.Parent.Ciclo)
local Mochila = require(script.Parent.Mochila)
local Muerte = require(script.Parent.Muerte)

local Recursos = {}

local T = Config.Talar
local azar = Random.new()
local originales: { [Model]: Model } = {} -- copia de cada árbol entero para que vuelva a crecer
local ultimo: { [Player]: number } = {}

local function plano(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Al quedarse quieto en el suelo, el tronco caído se parte en troncos que se pueden cargar.
local function partir(tronco: BasePart, troncos: number)
	local eje = plano(tronco.CFrame.RightVector) -- el cilindro va a lo largo de X
	eje = if eje.Magnitude > 0.1 then eje.Unit else Vector3.xAxis
	local centro = tronco.Position
	Remotes.Trabajo:FireAllClients(nil, "Parte", nil, 0, centro, eje, tronco.Size.X)
	local separacion = Config.Pesados.Tronco.Tam[1] + 0.6
	for i = 1, troncos do
		local punto = Vector3.new(centro.X, Config.Pesados.Tronco.Tam[2] / 2 + 0.1, centro.Z) + eje * ((i - (troncos + 1) / 2) * separacion)
		Cargar.nuevo("Tronco", CFrame.fromMatrix(punto, eje, Vector3.yAxis))
	end
	for _, parte in (tronco.Parent :: Instance):GetChildren() do
		if parte:IsA("BasePart") and (parte.Name == "Tronco" or parte.Name == "Copa") then
			parte:Destroy()
		end
	end
end

-- Marca el árbol como talado esa noche y pone el tocón donde estaba el corte.
local function ponerToco(modelo: Model, talado: number): Part
	local tronco = modelo:FindFirstChild("Tronco") :: BasePart
	modelo:SetAttribute("Talado", talado)
	local prompt = modelo:FindFirstChild("Mando") and (modelo.Mando :: BasePart):FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = false
	end
	local base = tronco.Position - Vector3.new(0, tronco.Size.X / 2, 0)
	local toco = Instance.new("Part")
	toco.Name = "Toco"
	toco.Anchored = true
	toco.Shape = Enum.PartType.Cylinder
	toco.Size = Vector3.new(1.2, tronco.Size.Y * 1.05, tronco.Size.Z * 1.05)
	toco.CFrame = CFrame.new(base + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	toco.Color = tronco.Color
	toco.Material = tronco.Material
	toco.Parent = modelo
	return toco
end

local function caer(modelo: Model, jugador: Player)
	local tronco = modelo:FindFirstChild("Tronco") :: BasePart
	local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local base = tronco.Position - Vector3.new(0, tronco.Size.X / 2, 0)
	local toco = ponerToco(modelo, select(2, Ciclo.fase()))
	-- El tronco sube un poco para apoyarse en el tocón.
	tronco.CFrame += Vector3.new(0, 1.3, 0)
	tronco.CollisionGroup = "Cargado" -- no choca con los jugadores al caer
	local sinChocar = Instance.new("NoCollisionConstraint")
	sinChocar.Part0 = tronco
	sinChocar.Part1 = toco
	sinChocar.Parent = toco
	local fuera = if raiz then plano(tronco.Position - raiz.Position) else Vector3.xAxis
	fuera = if fuera.Magnitude > 0.1 then fuera.Unit else Vector3.xAxis
	-- Gira sobre el borde del corte (una bisagra con el tocón) hasta estar casi tumbado; luego cae suelto.
	-- selene: allow(incorrect_standard_library_use)
	local eje = Vector3.yAxis:Cross(fuera)
	local pivote = CFrame.fromMatrix(base + Vector3.new(0, 1.25, 0) + fuera * (tronco.Size.Y / 2), eje, Vector3.yAxis)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent = toco
	a1.Parent = tronco
	a0.WorldCFrame = pivote
	a1.WorldCFrame = pivote
	local bisagra = Instance.new("HingeConstraint")
	bisagra.Attachment0 = a0
	bisagra.Attachment1 = a1
	bisagra.Parent = toco
	tronco.Anchored = false
	tronco:SetNetworkOwner(nil)
	tronco.AssemblyAngularVelocity = eje * 0.35 -- la copa empieza a irse hacia `fuera`
	task.spawn(function()
		local inicio = os.clock()
		repeat
			task.wait(0.1)
			if bisagra.Parent and math.abs(tronco.CFrame.RightVector.Y) < 0.3 then
				bisagra:Destroy() -- casi tumbado: que dé contra el suelo
			end
		until not tronco.Parent or os.clock() - inicio > 9 or (os.clock() - inicio > 2.5 and not bisagra.Parent
			and tronco.AssemblyAngularVelocity.Magnitude < 0.4 and tronco.AssemblyLinearVelocity.Magnitude < 1.5)
		if tronco.Parent then
			partir(tronco, T.Troncos + Stats.valor(jugador, "Troncos"))
		end
	end)
end

local function hachazo(jugador: Player, modelo: Model)
	local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local mando = modelo:FindFirstChild("Mando") :: BasePart?
	if not raiz or not mando or modelo:GetAttribute("Talado") or not table.find(Muerte.vivos(), jugador) then
		return
	end
	for _, atributo in { "Escondido", "Cargando", "MochilaAbierta", "Trabajando" } do
		if jugador:GetAttribute(atributo) then
			return
		end
	end
	if (mando.Position - raiz.Position).Magnitude > Config.Casa.Alcance + 4 then
		return
	end
	if not Mochila.primera(jugador, "Hacha") then
		Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "You need an axe."))
		return
	end
	local ahora = os.clock()
	if ahora - (ultimo[jugador] or -math.huge) < T.Cada then
		return
	end
	ultimo[jugador] = ahora
	local golpes = (modelo:GetAttribute("Golpes") or 0) + Stats.valor(jugador, "Hachazo")
	modelo:SetAttribute("Golpes", golpes)
	Remotes.Trabajo:FireAllClients(jugador, "Hachazo", modelo:FindFirstChild("Tronco"), 0)
	if golpes >= modelo:GetAttribute("GolpesMax") then
		caer(modelo, jugador)
	end
end

local function preparar(modelo: Model)
	modelo:SetAttribute("Golpes", 0)
	modelo:SetAttribute("GolpesMax", azar:NextInteger(T.Golpes[1], T.Golpes[2]))
	modelo:SetAttribute("Talado", nil)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.ActionText = "Chop"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = Config.Casa.Alcance
	prompt.RequiresLineOfSight = false
	prompt.Parent = modelo:WaitForChild("Mando")
	prompt.Triggered:Connect(function(jugador)
		hachazo(jugador, modelo)
	end)
end

-- Cambia el árbol por uno entero recién crecido (también corta una caída a medias: su tronco desaparece).
local function crecer(modelo: Model): Model
	local original = originales[modelo]
	local nuevo = original:Clone()
	originales[nuevo] = original
	originales[modelo] = nil
	nuevo.Parent = modelo.Parent
	modelo:Destroy()
	preparar(nuevo)
	return nuevo
end

-- Al amanecer vuelven a crecer los árboles talados hace Rebrota noches (nadie los ve crecer: es de noche).
local function rebrotar(noche: number)
	for _, modelo in Recursos.arboles() do
		local talado = modelo:GetAttribute("Talado")
		if talado and noche - talado >= T.Rebrota then
			crecer(modelo)
		end
	end
end

-- Los árboles talables de ahora (una lista aparte: crecer cambia la tabla).
function Recursos.arboles(): { Model }
	local lista = {}
	for modelo in originales do
		table.insert(lista, modelo)
	end
	return lista
end

-- Lo que se guarda (Partida): [clave del árbol] = noche en que se taló.
function Recursos.exportar()
	local t = {}
	for modelo in originales do
		local talado = modelo:GetAttribute("Talado")
		if talado then
			t[modelo:GetAttribute("Clave")] = talado
		end
	end
	return t
end

-- Deja el bosque como en `t`: todos los árboles enteros menos los talados, que quedan en tocón.
function Recursos.importar(t)
	for _, modelo in Recursos.arboles() do
		local nuevo = crecer(modelo)
		local talado = t[nuevo:GetAttribute("Clave")]
		if talado then
			ponerToco(nuevo, talado)
			for _, parte in nuevo:GetChildren() do
				if parte.Name == "Tronco" or parte.Name == "Copa" then
					parte:Destroy()
				end
			end
		end
	end
end

local function caballete()
	Cargar.alUsar("Tronco", {
		etiquetas = { "Caballete" },
		accion = "Serrar",
		preparar = function(jugador, cab, _pieza)
			if cab:GetAttribute("Ocupado") then
				Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "Someone is already using it."))
				return nil
			end
			cab:SetAttribute("Ocupado", true)
			return cab:GetAttribute("Encima") :: CFrame, T.Serrar
		end,
		terminar = function(_jugador, cab, pieza)
			cab:SetAttribute("Ocupado", nil)
			pieza:Destroy()
			local salida = cab:GetAttribute("Salida") :: CFrame
			for i = 1, T.Tablones do
				Cargar.nuevo("Tablon", salida * CFrame.new(0, (i - 1) * 0.45, (i - 1) * 0.3) * CFrame.Angles(0, (i - 1) * 0.15, 0))
			end
		end,
		cancelar = function(_jugador, cab, _pieza)
			cab:SetAttribute("Ocupado", nil)
		end,
	})
end

function Recursos.start()
	for _, modelo in CollectionService:GetTagged("Arbol") do
		originales[modelo] = modelo:Clone()
		preparar(modelo)
	end
	caballete()
	Ciclo.alCambiar(function(fase, noche)
		if fase == "Dia" then
			rebrotar(noche)
		end
	end)
	Players.PlayerRemoving:Connect(function(jugador)
		ultimo[jugador] = nil
	end)
end

return Recursos
