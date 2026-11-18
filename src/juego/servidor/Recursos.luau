-- Talar y serrar (pedido por el usuario: talar con golpes que astillan). Con bloques grises de momento.
--   Árboles (etiqueta "Arbol", los pone Mapa: solo los finos de cerca de la casa): con el hacha en la mochila, cada E
--   es un hachazo (Config.Talar.Cada entre uno y otro). Atributos del árbol: Golpes y GolpesMax (el cliente ahonda el
--   corte) y Talado (la noche en que cayó). Al último hachazo cae con física hacia el lado contrario de quien lo tala y,
--   al quedarse quieto en el suelo, se parte en troncos (cosas pesadas de Cargar). Queda el tocón; a las
--   Config.Talar.Rebrota noches vuelve a crecer (al amanecer).
--   Caballete: con un tronco en las manos, R (Cargar.alUsar "Tronco"): se sierra y salen tablones al lado.
--   Depósito de gasoil de la granja (etiqueta "Deposito"): con un bidón en las manos, R junto al grifo y se llena con
--   lo que quede (atributo Litros, en bidones: Config.Deposito.Dia cada amanecer, sin acumularse ni guardarse).
-- Las animaciones van en el cliente (TrabajoVista) con el remote Trabajo.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Stats = require(ReplicatedStorage.Shared.Stats)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Limite = require(game:GetService("ServerScriptService"):WaitForChild("Comun").Limite)
local Cargar = require(script.Parent.Cargar)
local Ciclo = require(script.Parent.Ciclo)
local Mochila = require(script.Parent.Mochila)
local Muerte = require(script.Parent.Muerte)

local Recursos = {}

local T = Config.Talar
local azar = Random.new()
local originales: { [Model]: Model } = {} -- copia de cada árbol entero para que vuelva a crecer

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
	if not Limite.pasa(jugador, "Hachazo", T.Cada) then
		return
	end
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

-- ===== Depósito de gasoil =====

local D = Config.Deposito

local function piezaDeposito(nombre: string, tamano: Vector3, cf: CFrame, color: Color3, material: Enum.Material, padre: Instance,
	choca: boolean?): Part
	local p = Instance.new("Part")
	p.Name = nombre
	p.Anchored = true
	p.Size = tamano
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = choca == true
	p.CanQuery = choca == true
	p.CanTouch = false
	p.Parent = padre
	return p
end

-- Depósito viejo de bloques: cilindro oxidado tumbado sobre cuatro patas con dos traviesas, flejes, tapón arriba y el
-- grifo en el extremo del oeste (hacia la casa), con su mancha de gasoil en el suelo y una mano de sangre seca encima.
-- Se hace aquí y no en Lugares. Devuelve el modelo, ya en el mapa.
local function construirDeposito(): Model
	local modelo = Instance.new("Model")
	modelo.Name = "Deposito"
	modelo.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- el Mando llega con el resto
	local suelo = Vector3.new(D.Posicion[1], D.Posicion[2], D.Posicion[3])
	local centro = CFrame.new(suelo + Vector3.new(0, 4.4, 0)) -- el eje del cilindro va a lo largo de X
	local oxido = Color3.fromRGB(92, 58, 42)
	local hierro = Color3.fromRGB(48, 46, 44)
	local cuerpo = piezaDeposito("Cuerpo", Vector3.new(6, 3.2, 3.2), centro, oxido, Enum.Material.CorrodedMetal, modelo, true)
	cuerpo.Shape = Enum.PartType.Cylinder
	CollectionService:AddTag(cuerpo, "EnMapa")
	-- Tapas de los extremos y flejes, un poco más anchos que el cilindro.
	for _, x in { -3, 3 } do
		piezaDeposito("Tapa", Vector3.new(0.2, 3.36, 3.36), centro * CFrame.new(x, 0, 0), hierro, Enum.Material.Metal, modelo).Shape =
			Enum.PartType.Cylinder
	end
	for _, x in { -1.9, 1.9 } do
		piezaDeposito("Fleje", Vector3.new(0.25, 3.3, 3.3), centro * CFrame.new(x, 0, 0), hierro, Enum.Material.CorrodedMetal, modelo).Shape =
			Enum.PartType.Cylinder
	end
	-- Patas y traviesas de hierro (las traviesas abrazan la panza del cilindro).
	for _, x in { -2.2, 2.2 } do
		for _, z in { -0.9, 0.9 } do -- suben hasta meterse un poco en la panza
			piezaDeposito("Pata", Vector3.new(0.35, 3.25, 0.35), CFrame.new(suelo + Vector3.new(x, 1.625, z)), hierro, Enum.Material.CorrodedMetal,
				modelo, true)
		end
		piezaDeposito("Traviesa", Vector3.new(0.4, 0.4, 2.3), CFrame.new(suelo + Vector3.new(x, 2.85, 0)), hierro, Enum.Material.CorrodedMetal,
			modelo, true)
		-- Un tirante en diagonal entre las patas de cada lado.
		piezaDeposito("Tirante", Vector3.new(0.15, 0.15, 2.3), CFrame.new(suelo + Vector3.new(x, 1.4, 0)) * CFrame.Angles(math.rad(38), 0, 0),
			hierro, Enum.Material.Metal, modelo)
	end
	-- Tapón de llenar arriba, con su cadena colgando.
	piezaDeposito("Tapon", Vector3.new(0.45, 0.8, 0.8), centro * CFrame.new(1.4, 1.7, 0) * CFrame.Angles(0, 0, math.pi / 2), hierro,
		Enum.Material.Metal, modelo).Shape = Enum.PartType.Cylinder
	piezaDeposito("Cadena", Vector3.new(0.06, 0.9, 0.06), centro * CFrame.new(1.05, 1.3, 0.35) * CFrame.Angles(0, 0, math.rad(25)), hierro,
		Enum.Material.Metal, modelo)
	-- El grifo: tubo que sale de la tapa del oeste por abajo, codo hacia el suelo y la llave en cruz encima.
	local tubo = Color3.fromRGB(70, 66, 60)
	piezaDeposito("Tubo", Vector3.new(0.9, 0.28, 0.28), centro * CFrame.new(-3.5, -1, 0), tubo, Enum.Material.Metal, modelo).Shape =
		Enum.PartType.Cylinder
	piezaDeposito("Codo", Vector3.new(0.34, 0.34, 0.34), centro * CFrame.new(-3.95, -1, 0), tubo, Enum.Material.Metal, modelo)
	piezaDeposito("Caño", Vector3.new(0.6, 0.26, 0.26), centro * CFrame.new(-3.95, -1.45, 0) * CFrame.Angles(0, 0, math.pi / 2), tubo,
		Enum.Material.Metal, modelo).Shape = Enum.PartType.Cylinder
	piezaDeposito("Eje", Vector3.new(0.1, 0.35, 0.1), centro * CFrame.new(-3.5, -0.72, 0), tubo, Enum.Material.Metal, modelo)
	for _, giro in { 0, 90 } do
		piezaDeposito("Llave", Vector3.new(0.12, 0.1, 0.7), centro * CFrame.new(-3.5, -0.55, 0) * CFrame.Angles(0, math.rad(giro + 20), 0),
			Color3.fromRGB(96, 24, 20), Enum.Material.Metal, modelo)
	end
	-- Lo derramado debajo del grifo (oscuro, sin brillo) y una mano de sangre seca en la tapa, junto al grifo.
	local charco = CFrame.new(suelo + Vector3.new(-3.6, 0.03, 0.3)) * CFrame.Angles(0, 0, math.pi / 2) -- disco tumbado
	local mancha = piezaDeposito("Mancha", Vector3.new(0.05, 3.4, 3.4), charco, Color3.fromRGB(22, 20, 18), Enum.Material.Slate, modelo)
	mancha.Shape = Enum.PartType.Cylinder
	mancha.CastShadow = false
	local tapa = centro * CFrame.new(-3.12, 0, 0) -- un poco por fuera de la cara de la tapa del oeste
	local sangre = Color3.fromRGB(64, 12, 10)
	piezaDeposito("Sangre", Vector3.new(0.02, 0.75, 0.55), tapa * CFrame.new(0, 0.45, 0.55) * CFrame.Angles(math.rad(-12), 0, 0), sangre,
		Enum.Material.SmoothPlastic, modelo).CastShadow = false
	for i, dedo in { { -0.3, 0.12 }, { -0.1, 0.18 }, { 0.1, 0.17 }, { 0.3, 0.1 } } do
		piezaDeposito("Sangre", Vector3.new(0.02, 0.38 + dedo[2], 0.1), tapa * CFrame.new(0, 0.98 + dedo[2] / 2, 0.55 + dedo[1])
			* CFrame.Angles(math.rad(-12 + i * 4), 0, 0), sangre, Enum.Material.SmoothPlastic, modelo).CastShadow = false
	end
	-- Chorretón que baja de la mano hasta el codo del grifo.
	piezaDeposito("Sangre", Vector3.new(0.02, 1.1, 0.07), tapa * CFrame.new(0, -0.35, 0.62), sangre, Enum.Material.SmoothPlastic,
		modelo).CastShadow = false
	-- Dónde se pone el bidón (de pie bajo el caño), dónde cae al acabar y la boca del grifo (el chorro de TrabajoVista).
	local boca = centro * CFrame.new(-3.95, -1.75, 0)
	local mando = piezaDeposito("Mando", Vector3.new(1, 1, 1), boca * CFrame.new(0, -0.3, 0), tubo, Enum.Material.SmoothPlastic, modelo)
	mando.Transparency = 1
	local alto = Config.Pesados.Bidon.Tam[2]
	modelo:SetAttribute("Sitio", CFrame.new(boca.X, suelo.Y + alto / 2 + 0.05, boca.Z))
	modelo:SetAttribute("Salida", CFrame.new(boca.X - 0.2, suelo.Y + alto / 2 + 0.1, boca.Z + 2.4) * CFrame.Angles(0, 0.5, 0))
	modelo:SetAttribute("Grifo", CFrame.new(boca.Position))
	modelo:SetAttribute("Litros", D.Dia)
	CollectionService:AddTag(modelo, "Deposito")
	local mapa = workspace:FindFirstChild("Mapa")
	modelo.Parent = (mapa and mapa:FindFirstChild("Lugares")) or mapa or workspace
	return modelo
end

local function deposito()
	local dep = construirDeposito()
	Cargar.alUsar("Bidon", {
		etiquetas = { "Deposito" },
		accion = "Verter", -- el mismo chorro y sonido que al echar gasolina, del grifo al bidón
		preparar = function(jugador, _dep, pieza)
			if (pieza:GetAttribute("Carga") or 0) >= 0.99 then
				Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "The can is full."))
				return nil
			elseif (dep:GetAttribute("Litros") or 0) <= 0.01 then
				Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "It's dry. Come back tomorrow."))
				return nil
			elseif dep:GetAttribute("Llenando") then
				Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "Someone is already using it."))
				return nil
			end
			dep:SetAttribute("Llenando", true)
			return dep:GetAttribute("Sitio") :: CFrame, D.Llenar
		end,
		terminar = function(_jugador, _dep, pieza)
			dep:SetAttribute("Llenando", nil)
			-- Se vuelve a mirar al acabar: lo que quede ahora, no lo que había al empezar.
			local carga = pieza:GetAttribute("Carga") or 0
			local litros = dep:GetAttribute("Litros") or 0
			local echado = math.clamp(math.min(1 - carga, litros), 0, 1)
			pieza:SetAttribute("Carga", math.min(1, carga + echado))
			dep:SetAttribute("Litros", math.max(0, litros - echado))
			Cargar.liberar(pieza, dep:GetAttribute("Salida") :: CFrame)
		end,
		cancelar = function()
			dep:SetAttribute("Llenando", nil)
		end,
	})
	return dep
end

function Recursos.start()
	for _, modelo in CollectionService:GetTagged("Arbol") do
		originales[modelo] = modelo:Clone()
		preparar(modelo)
	end
	caballete()
	local dep = deposito()
	Ciclo.alCambiar(function(fase, noche)
		if fase == "Dia" then
			rebrotar(noche)
			dep:SetAttribute("Litros", D.Dia) -- lo de ayer no se acumula
		end
	end)
end

return Recursos
