-- Anima en el cliente lo que el servidor cambia en la casa (atributos de cada modelo, ver juego/servidor/Casa):
--   Ventana: la persiana (lamas locales) baja o sube traqueteando; con poca vida se tuerce y rota se cae.
--     El cristal se agrieta por golpes y estalla al romperse.
--   Puerta: la hoja gira en la bisagra (de golpe si la abre el bicho); con llave, el pomo traquetea.
--   Con un tablón reforzado clavado (atributo Refuerzo): tablones en aspa con flejes (por dentro o en la hoja).
--   Cada golpe del bicho (atributo Golpes): tiembla, suena, cae polvo y tiembla la cámara si estás cerca.
-- Animación sencilla a propósito: se mejora más adelante (pedido por el usuario).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sonido = require(script.Parent.Sonido)

local CasaVista = {}

local cfg = Config.Casa
local azar = Random.new()
local LAMA = 0.5 -- alto de cada lama de la persiana
local temblor = 0 -- fuerza del temblor de la cámara, baja sola

local function pieza(tamano: Vector3, cf: CFrame, color: Color3, padre: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = tamano
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Metal
	p.Parent = padre
	return p
end

-- Un tablón reforzado: madera oscura con dos flejes de metal.
local function tablon(tamano: Vector3, cf: CFrame, padre: Instance): BasePart
	local p = pieza(tamano, cf, Color3.fromRGB(72, 54, 40), padre)
	p.Material = Enum.Material.Wood
	for _, x in { -0.3, 0.3 } do
		local fleje = pieza(Vector3.new(0.25, tamano.Y + 0.06, tamano.Z + 0.06), cf * CFrame.new(tamano.X * x, 0, 0),
			Color3.fromRGB(60, 60, 64), p)
		fleje.Anchored = false
		local union = Instance.new("WeldConstraint")
		union.Part0, union.Part1 = p, fleje
		union.Parent = fleje
	end
	return p
end

-- Ventana con tablones reforzados (atributo Refuerzo): dos en aspa por dentro.
local function ventanaReforzada(el: Model)
	local hechos: { BasePart } = {}
	local function pintar()
		for _, p in hechos do
			p:Destroy()
		end
		table.clear(hechos)
		local centro = el:GetAttribute("Centro")
		if not el:GetAttribute("Refuerzo") or typeof(centro) ~= "CFrame" then
			return
		end
		local ancho, alto = el:GetAttribute("Ancho") or 4, el:GetAttribute("Alto") or 4
		local largo = math.sqrt(ancho * ancho + alto * alto) * 0.95
		local angulo = math.atan2(alto, ancho)
		for _, lado in { -1, 1 } do
			table.insert(hechos, tablon(Vector3.new(largo, 0.7, 0.22), centro * CFrame.new(0, 0, 1.05 + 0.12 * lado)
				* CFrame.Angles(0, 0, angulo * lado), el))
		end
	end
	el:GetAttributeChangedSignal("Refuerzo"):Connect(pintar)
	pintar()
end

local function sacudirCamara(desde: Vector3, fuerza: number)
	local camara = workspace.CurrentCamera
	local distancia = (camara.CFrame.Position - desde).Magnitude
	if distancia < 35 then
		temblor = math.max(temblor, fuerza * (1 - distancia / 35))
	end
end

-- Trocitos que caen (polvo de un golpe o cristales). Se borran solos.
local function trozos(cf: CFrame, cuantos: number, color: Color3, tamano: number, empuje: Vector3)
	for _ = 1, cuantos do
		local p = pieza(Vector3.new(tamano, tamano, tamano * 0.4),
			cf * CFrame.new(azar:NextNumber(-1.5, 1.5), azar:NextNumber(-1, 1), 0) * CFrame.Angles(azar:NextNumber(0, 6), azar:NextNumber(0, 6), 0),
			color, workspace.Terrain)
		p.Anchored = false
		p.Material = Enum.Material.Glass
		p.AssemblyLinearVelocity = empuje + Vector3.new(azar:NextNumber(-4, 4), azar:NextNumber(0, 5), azar:NextNumber(-4, 4))
		task.delay(3, function()
			TweenService:Create(p, TweenInfo.new(1), { Transparency = 1 }):Play()
			task.delay(1, p.Destroy, p)
		end)
	end
end

local function ventana(el: Model)
	local centro = el:GetAttribute("Centro") :: CFrame
	local ancho, alto = el:GetAttribute("Ancho") :: number, el:GetAttribute("Alto") :: number
	local cristal = el:WaitForChild("Cristal") :: BasePart
	local dentro = -centro.LookVector -- hacia la sala
	local local_ = Instance.new("Folder")
	local_.Name = "Persiana"
	local_.Parent = el

	-- Lamas: posición i (1 arriba) cuando la persiana está bajada del todo.
	local cuantas = math.ceil(alto / LAMA)
	local lamas: { Part } = {}
	local tuerce: { number } = {}
	local function crearLamas()
		local_:ClearAllChildren()
		table.clear(lamas)
		for i = 1, cuantas do
			lamas[i] = pieza(Vector3.new(ancho + 0.2, LAMA * 0.9, 0.12), centro, Color3.fromRGB(96, 94, 90), local_)
			tuerce[i] = azar:NextNumber(-1, 1)
		end
	end
	crearLamas()

	local bajado = if el:GetAttribute("Persiana") then 1 else 0 -- 0 subida, 1 bajada
	local rota = false

	local function colocar(meneo: number)
		local danio = 1 - (el:GetAttribute("Vida") or 1) / (el:GetAttribute("VidaMax") or 1)
		for i, lama in lamas do
			local y = alto / 2 - LAMA * (i - 0.5) + (1 - bajado) * alto
			local oculta = y > alto / 2
			lama.Transparency = if oculta then 1 else 0
			local giro = if danio > 0.4 then tuerce[i] * danio * 0.25 else 0
			lama.CFrame = centro * CFrame.new(azar:NextNumber(-meneo, meneo), y, 0.7) * CFrame.Angles(0, 0, giro)
		end
	end
	colocar(0)

	local moviendo = false
	local function mover(hacia: number)
		if moviendo then
			return
		end
		moviendo = true
		Sonido.en("Persiana", centro.Position)
		local desde, t0 = bajado, os.clock()
		while true do
			local p = math.min(1, (os.clock() - t0) / cfg.TiempoPersiana)
			bajado = desde + (hacia - desde) * p
			colocar(0.04)
			if p >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
		colocar(0)
		moviendo = false
	end

	local function romperPersiana()
		rota = true
		for _, lama in lamas do
			if lama.Transparency < 1 then
				lama.Anchored = false
				lama.AssemblyLinearVelocity = dentro * azar:NextNumber(4, 10)
			end
		end
	end

	local grietas = Instance.new("Folder")
	grietas.Name = "Grietas"
	grietas.Parent = el
	local cristalAntes = el:GetAttribute("Cristal") or 0
	local function pintarCristal()
		local n = el:GetAttribute("Cristal") or 0
		grietas:ClearAllChildren()
		local roto = n >= cfg.GolpesCristal
		cristal.LocalTransparencyModifier = if roto then 1 else 0
		if not roto then
			for _ = 1, n * 5 do
				local largo = azar:NextNumber(0.8, math.min(ancho, alto) * 0.7)
				pieza(Vector3.new(largo, 0.06, 0.25),
					centro * CFrame.new(azar:NextNumber(-ancho / 3, ancho / 3), azar:NextNumber(-alto / 3, alto / 3), 0)
						* CFrame.Angles(0, 0, azar:NextNumber(0, math.pi)),
					Color3.fromRGB(20, 22, 24), grietas).Material = Enum.Material.SmoothPlastic
			end
		end
		if n > cristalAntes then
			if roto then
				Sonido.en("Cristal", centro.Position)
				trozos(centro, 18, Color3.fromRGB(170, 190, 200), 0.5, dentro * 14)
			else
				Sonido.en("Grieta", centro.Position)
			end
		end
		cristalAntes = n
	end
	pintarCristal()

	el:GetAttributeChangedSignal("Persiana"):Connect(function()
		if not rota then
			task.spawn(mover, if el:GetAttribute("Persiana") then 1 else 0)
		end
	end)
	el:GetAttributeChangedSignal("Vida"):Connect(function()
		local vida = el:GetAttribute("Vida") or 0
		if vida <= 0 and not rota then
			romperPersiana()
		elseif vida > 0 and rota then -- reparada: lamas nuevas, subidas
			rota = false
			crearLamas()
			bajado = if el:GetAttribute("Persiana") then 1 else 0
		end
		colocar(0)
	end)
	el:GetAttributeChangedSignal("Cristal"):Connect(pintarCristal)
	el:GetAttributeChangedSignal("Golpes"):Connect(function()
		Sonido.en("Golpe", centro.Position, azar:NextNumber(0.7, 0.85))
		sacudirCamara(centro.Position, 0.5)
		trozos(centro * CFrame.new(0, alto / 2 + 0.6, 1), 4, Color3.fromRGB(120, 110, 95), 0.2, Vector3.zero)
		if not rota and not moviendo then
			for _ = 1, 4 do
				colocar(0.25)
				task.wait(0.03)
			end
			colocar(0)
		end
	end)
end

local function puerta(el: Model)
	local bisagra = el:GetAttribute("Bisagra") :: CFrame
	local hacia = el:GetAttribute("Hacia") :: Vector3
	local hoja = el:WaitForChild("Hoja") :: BasePart
	local pomo = el:WaitForChild("Pomo") :: BasePart
	local hojaRel = bisagra:ToObjectSpace(hoja.CFrame)
	local pomoRel = bisagra:ToObjectSpace(pomo.CFrame)
	-- Hacia qué lado gira: el que deja la hoja apuntando a la sala de `hacia`.
	local giro = if (bisagra * CFrame.Angles(0, math.rad(90), 0)).RightVector:Dot(hacia) > 0 then 1 else -1
	local angulo = Instance.new("NumberValue")
	local tablones: { { parte: BasePart, rel: CFrame } } = {} -- los del refuerzo, que giran con la hoja
	local function colocar(a: number)
		local cf = bisagra * CFrame.Angles(0, math.rad(a), 0)
		hoja.CFrame = cf * hojaRel
		pomo.CFrame = cf * pomoRel
		for _, t in tablones do
			t.parte.CFrame = cf * t.rel
		end
	end
	-- Tablones reforzados (atributo Refuerzo): dos en aspa en cada cara de la hoja.
	local function reforzar()
		for _, t in tablones do
			t.parte:Destroy()
		end
		table.clear(tablones)
		if not el:GetAttribute("Refuerzo") then
			return
		end
		for _, cara in { -1, 1 } do
			for _, inclinado in { -24, 24 } do
				local rel = hojaRel * CFrame.new(0, 0, (hoja.Size.Z / 2 + 0.12) * cara) * CFrame.Angles(0, 0, math.rad(inclinado))
				table.insert(tablones, { parte = tablon(Vector3.new(hoja.Size.X * 1.08, 0.7, 0.22), bisagra * rel, el), rel = rel })
			end
		end
		colocar(angulo.Value)
	end
	el:GetAttributeChangedSignal("Refuerzo"):Connect(reforzar)
	angulo.Changed:Connect(colocar)
	local function destino(): number
		return if el:GetAttribute("Abierta") then 100 * giro else 0
	end
	angulo.Value = destino()
	colocar(angulo.Value)
	reforzar()

	local portazos = el:GetAttribute("Portazo") or 0
	el:GetAttributeChangedSignal("Abierta"):Connect(function()
		local deGolpe = (el:GetAttribute("Portazo") or 0) ~= portazos
		portazos = el:GetAttribute("Portazo") or 0
		if deGolpe then
			Sonido.en("Golpe", hoja.Position, 0.9)
			sacudirCamara(hoja.Position, 0.6)
		else
			Sonido.en("Puerta", hoja.Position)
		end
		TweenService:Create(angulo, TweenInfo.new(if deGolpe then 0.18 else cfg.TiempoPuerta, Enum.EasingStyle.Quad),
			{ Value = destino() }):Play()
	end)
	local function traqueteo(fuerza: number)
		task.spawn(function()
			local base = angulo.Value
			for i = 1, 6 do
				colocar(base + (if i % 2 == 0 then fuerza else -fuerza))
				task.wait(0.04)
			end
			colocar(base)
		end)
	end
	el:GetAttributeChangedSignal("Intentos"):Connect(function()
		Sonido.en("Puerta", hoja.Position, 1.3)
		traqueteo(1)
	end)
	el:GetAttributeChangedSignal("Golpes"):Connect(function()
		Sonido.en("Golpe", hoja.Position, azar:NextNumber(0.7, 0.85))
		sacudirCamara(hoja.Position, 0.5)
		traqueteo(3)
	end)
end

local function cuando(etiqueta: string, fn: (Model) -> ())
	local hechos = {}
	local function preparar(el: Instance)
		if not hechos[el] and el:IsA("Model") then
			hechos[el] = true
			task.spawn(fn, el)
		end
	end
	CollectionService:GetInstanceAddedSignal(etiqueta):Connect(preparar)
	for _, el in CollectionService:GetTagged(etiqueta) do
		preparar(el)
	end
end

function CasaVista.start()
	cuando("Ventana", ventana)
	cuando("Puerta", puerta)
	cuando("Ventana", ventanaReforzada)
	RunService:BindToRenderStep("Temblor", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if temblor > 0.01 then
			local camara = workspace.CurrentCamera
			camara.CFrame *= CFrame.Angles(azar:NextNumber(-1, 1) * temblor * 0.02, azar:NextNumber(-1, 1) * temblor * 0.02, 0)
			temblor = math.max(0, temblor - dt * 2)
		end
	end)
end

return CasaVista
