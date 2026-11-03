-- Lo que se ve de la preparación del final de la Bestia (servidor: Preparativos, 12.2). Todo local y sin chocar:
--   Charco en cada cruz con gasolina (atributo Lleno de los modelos "Gasolina"): manchas oscuras que brillan poco; al
--   echarla, crece.
--   Rastro: con el atributo Rastro del porche ("PorcheGasolina"), un reguero pegado al suelo desde la primera cruz
--   (atributo Desde) hasta el porche.
--   Palanca (atributo Bajada): el mango baja de golpe con un tirón.
--   Trampilla (atributo Abierto): cruje al abrirse (la tapa la mueve el servidor: deja de chocar).
--   Remote Preparativos ("Reja", posición): la reja acaba de caer: golpe de hierro, polvo y un temblor si estás cerca;
--     lo de alrededor tiembla como con un golpe (CasaVista.alGolpe: tarros, bombillas colgadas, polvo en el aire).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CasaVista = require(script.Parent.CasaVista)
local Sonido = require(script.Parent.Sonido)

local PreparativosVista = {}

local GASOLINA = Color3.fromRGB(16, 14, 12)
local PALANCA = { Subida = -0.5, Bajada = -2.6 } -- giro del mango (radianes) sobre su pivote
local carpeta: Folder
local charcos: { [Instance]: { BasePart } } = {}
local rastro: { BasePart } = {}
local azar = Random.new()

-- Una mancha redonda y plana de gasolina (cilindro tumbado: su eje, X, hacia arriba).
local function mancha(nombre: string, diametro: number, centro: Vector3, giro: number): Part
	local p = Instance.new("Part")
	p.Name = nombre
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.03, diametro, diametro)
	p.CFrame = CFrame.new(centro) * CFrame.Angles(0, giro, math.pi / 2)
	p.Color = GASOLINA
	p.Material = Enum.Material.SmoothPlastic
	p.Reflectance = 0.18 -- brilla poco: nada de brillos fuertes
	p.Transparency = 0.12
	p.Parent = carpeta
	return p
end

local function filtroSuelo(): RaycastParams
	local filtro = RaycastParams.new()
	filtro.FilterType = Enum.RaycastFilterType.Exclude
	local fuera: { Instance } = { carpeta }
	for _, nombre in { "Objetos", "Pesados" } do
		local f = workspace:FindFirstChild(nombre)
		if f then
			table.insert(fuera, f)
		end
	end
	for _, jugador in Players:GetPlayers() do
		if jugador.Character then
			table.insert(fuera, jugador.Character)
		end
	end
	filtro.FilterDescendantsInstances = fuera
	return filtro
end

local function quitarCharco(modelo: Instance)
	for _, p in charcos[modelo] or {} do
		p:Destroy()
	end
	charcos[modelo] = nil
end

local function pintarCharco(modelo: Instance, crecer: boolean)
	quitarCharco(modelo)
	local mando = modelo:FindFirstChild("Mando") :: BasePart?
	if not mando or modelo:GetAttribute("Lleno") ~= true then
		return
	end
	local suelo = mando.Position - Vector3.new(0, mando.Size.Y / 2, 0)
	local forma = Random.new((modelo:GetAttribute("Orden") or 1) * 7919) -- cada charco, siempre igual
	local lista = {}
	for i, diametro in { 2.8, 2, 1.5 } do
		local desvio = if i == 1 then Vector3.zero else Vector3.new(forma:NextNumber(-0.8, 0.8), 0, forma:NextNumber(-0.8, 0.8))
		local p = mancha("Charco", diametro, suelo + desvio + Vector3.new(0, 0.045 + i * 0.004, 0), forma:NextNumber(0, math.pi))
		if crecer then
			local final = p.Size
			p.Size = Vector3.new(final.X, 0.3, 0.3)
			TweenService:Create(p, TweenInfo.new(1.2 + i * 0.3, Enum.EasingStyle.Quad), { Size = final }):Play()
		end
		table.insert(lista, p)
	end
	charcos[modelo] = lista
end

-- El reguero: manchas pequeñas cada poco, cada una a la altura del suelo que tiene debajo (umbral, porche).
local function pintarRastro(porche: Instance)
	for _, p in rastro do
		p:Destroy()
	end
	table.clear(rastro)
	local desde = porche:GetAttribute("Desde")
	if porche:GetAttribute("Rastro") ~= true or typeof(desde) ~= "Vector3" or not porche:IsA("BasePart") then
		return
	end
	local hasta = porche.Position
	local n = math.max(1, math.floor(((hasta - desde) * Vector3.new(1, 0, 1)).Magnitude / 1.1))
	local filtro = filtroSuelo()
	local forma = Random.new(12)
	for i = 0, n do
		local punto = desde:Lerp(hasta, i / n) + Vector3.new(forma:NextNumber(-0.2, 0.2), 0, forma:NextNumber(-0.2, 0.2))
		local hit = workspace:Raycast(punto + Vector3.new(0, 3, 0), Vector3.new(0, -6, 0), filtro)
		local y = (if hit then hit.Position.Y else punto.Y - 0.05) + 0.045 + (i % 2) * 0.004
		table.insert(rastro, mancha("Rastro", forma:NextNumber(0.7, 1.15), Vector3.new(punto.X, y, punto.Z), forma:NextNumber(0, math.pi)))
	end
end

local function moverPalanca(modelo: Instance, animar: boolean)
	local pivote = modelo:GetAttribute("Pivote")
	local mango = modelo:FindFirstChild("Mango") :: BasePart?
	local pomo = modelo:FindFirstChild("Pomo") :: BasePart?
	if typeof(pivote) ~= "CFrame" or not mango or not pomo then
		return
	end
	local bajada = modelo:GetAttribute("Bajada") == true
	local function poner(angulo: number)
		local giro = pivote * CFrame.Angles(0, 0, angulo)
		mango.CFrame = giro * CFrame.new(0, 1, 0)
		pomo.CFrame = giro * CFrame.new(0, 2, 0)
	end
	local hasta = if bajada then PALANCA.Bajada else PALANCA.Subida
	if not animar then
		poner(hasta)
		return
	end
	local valor = Instance.new("NumberValue")
	valor.Value = if bajada then PALANCA.Subida else PALANCA.Bajada
	valor.Changed:Connect(poner)
	local tween = TweenService:Create(valor, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Value = hasta })
	tween.Completed:Connect(function()
		valor:Destroy()
	end)
	tween:Play()
	Sonido.en("Tiron", pivote.Position)
end

-- Temblor de la vista por la reja: el giro se pinta encima de la cámara de Roblox (Camera + 1) y se deshace en el
-- fotograma siguiente antes de ella (Camera - 1); si no, la cámara seguía desde el giro y la mirada se quedaba desviada
-- (como en BestiaVista). Los dos pasos se desatan al acabar, con el último giro ya deshecho.
local TEMBLOR_REJA = 0.45 -- segundos
local finReja = 0 -- hasta cuándo tiembla (os.clock)
local giroReja: CFrame? = nil -- el giro del último fotograma
local temblandoReja = false

local function temblarReja()
	finReja = math.max(finReja, os.clock() + TEMBLOR_REJA)
	if temblandoReja then
		return -- ya tiembla: solo dura más
	end
	temblandoReja = true
	RunService:BindToRenderStep("TemblorRejaAntes", Enum.RenderPriority.Camera.Value - 1, function()
		local camara = workspace.CurrentCamera
		if giroReja then
			-- En una cinemática la cámara la pone un script: no se toca.
			if camara and camara.CameraType ~= Enum.CameraType.Scriptable then
				camara.CFrame *= giroReja:Inverse()
			end
			giroReja = nil
		end
		if os.clock() >= finReja then
			temblandoReja = false
			RunService:UnbindFromRenderStep("TemblorRejaAntes")
			RunService:UnbindFromRenderStep("TemblorReja")
		end
	end)
	RunService:BindToRenderStep("TemblorReja", Enum.RenderPriority.Camera.Value + 1, function()
		local quedan = finReja - os.clock()
		local camara = workspace.CurrentCamera
		if quedan <= 0 or not camara or camara.CameraType == Enum.CameraType.Scriptable then
			return
		end
		local f = quedan * 0.05
		local giro = CFrame.Angles(azar:NextNumber(-f, f), azar:NextNumber(-f, f), 0)
		camara.CFrame *= giro
		giroReja = giro
	end)
end

-- La reja cae: golpe de hierro, polvo y, si estás cerca, la vista tiembla un momento.
local function rejaCae(posicion: Vector3)
	Sonido.en("Golpe", posicion, 0.6)
	Sonido.en("Caida", posicion)
	local suelo = Instance.new("Part")
	suelo.Anchored = true
	suelo.CanCollide = false
	suelo.CanQuery = false
	suelo.CanTouch = false
	suelo.Transparency = 1
	suelo.Size = Vector3.new(4.5, 0.2, 0.6)
	suelo.CFrame = CFrame.new(posicion - Vector3.new(0, 4.2, 0))
	suelo.Parent = carpeta
	local polvo = Instance.new("ParticleEmitter")
	polvo.Color = ColorSequence.new(Color3.fromRGB(95, 88, 78))
	polvo.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 2.4) })
	polvo.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	polvo.Lifetime = NumberRange.new(1.2, 2.2)
	polvo.Speed = NumberRange.new(2, 5)
	polvo.SpreadAngle = Vector2.new(70, 70)
	polvo.Drag = 3
	polvo.Rate = 0
	polvo.Parent = suelo
	polvo:Emit(36)
	task.delay(3, function()
		suelo:Destroy()
	end)
	-- La casa lo nota como un golpe fuerte (Efectos: solo si la cámara está cerca).
	local alGolpe = CasaVista.alGolpe
	if alGolpe then
		alGolpe(posicion)
	end
	if (workspace.CurrentCamera.CFrame.Position - posicion).Magnitude > 35 then
		return
	end
	temblarReja()
end

-- Cada cosa etiquetada, la que ya está y la que llega (con streaming puede llegar tarde).
local function porEtiqueta(etiqueta: string, preparar: (Instance) -> ())
	CollectionService:GetInstanceAddedSignal(etiqueta):Connect(preparar)
	for _, el in CollectionService:GetTagged(etiqueta) do
		task.spawn(preparar, el)
	end
end

function PreparativosVista.start()
	carpeta = Instance.new("Folder")
	carpeta.Name = "PreparativosVista"
	carpeta.Parent = workspace

	porEtiqueta("Gasolina", function(modelo)
		pintarCharco(modelo, false)
		modelo:GetAttributeChangedSignal("Lleno"):Connect(function()
			pintarCharco(modelo, true)
		end)
	end)
	CollectionService:GetInstanceRemovedSignal("Gasolina"):Connect(quitarCharco)
	porEtiqueta("PorcheGasolina", function(porche)
		pintarRastro(porche)
		porche:GetAttributeChangedSignal("Rastro"):Connect(function()
			pintarRastro(porche)
		end)
	end)
	porEtiqueta("Palanca", function(modelo)
		moverPalanca(modelo, false)
		modelo:GetAttributeChangedSignal("Bajada"):Connect(function()
			moverPalanca(modelo, true)
		end)
	end)
	porEtiqueta("Trampilla", function(modelo)
		modelo:GetAttributeChangedSignal("Abierto"):Connect(function()
			local tapa = modelo:FindFirstChild("Tapa") :: BasePart?
			if tapa and modelo:GetAttribute("Abierto") then
				Sonido.en("Crujido", tapa.Position)
			end
		end)
	end)
	Remotes.Preparativos.OnClientEvent:Connect(function(que, posicion)
		if que == "Reja" and typeof(posicion) == "Vector3" then
			rejaCae(posicion)
		end
	end)
end

return PreparativosVista
