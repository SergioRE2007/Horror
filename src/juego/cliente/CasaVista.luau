-- Anima en el cliente lo que el servidor cambia en la casa (atributos de cada modelo, ver juego/servidor/Casa):
--   Ventana: las cortinas (pliegues locales) se corren o se recogen; con poca vida se rasgan y rota se caen.
--     El cristal se agrieta por golpes y estalla al romperse; roto, quedan picos de cristal en el marco hasta repararlo.
--   Puerta: la hoja gira en la bisagra (de golpe si la abre el bicho); con llave, el pomo traquetea.
--   Con un tablón reforzado clavado (atributo Refuerzo): tablones en aspa con flejes (por dentro o en la hoja).
--   Cada golpe del bicho (atributo Golpes): tiembla, suena, cae polvo del marco y tiembla la cámara si estás cerca.
-- Avisos sin sonido (14.3, para quien juega sin cascos; los dispara Efectos con CasaVista.acecho cada fotograma):
--   Algo se acerca o se planta fuera: las cortinas se mecen hacia dentro como por una corriente, el cristal vibra en el
--   marco (con su traqueteo) y cae polvillo; pegado al cristal, su aliento lo empaña. La puerta se comba un poco
--   hacia dentro, como si empujaran, y cruje.
-- Para los demás módulos: CasaVista.temblar (temblor de cámara suave, nunca en cinemáticas), CasaVista.polvo (polvo y
-- arenilla que caen), CasaVista.vibrar (el cristal traquetea un momento) y CasaVista.alRomper (lo pone Efectos: los
-- trozos de cristal que quedan en el suelo).
-- Animación sencilla a propósito: se mejora más adelante (pedido por el usuario).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sonido = require(script.Parent.Sonido)

local CasaVista = {}

-- Números a ojo de los avisos sin sonido (14.3).
local CFG = Config.EfectosCasa

local cfg = Config.Casa
local jugador = Players.LocalPlayer
local azar = Random.new()
local PLIEGUES = 6 -- pliegues de cada paño de cortina
local TELA = Color3.fromRGB(86, 40, 36) -- terciopelo granate viejo
local TELA_OSCURA = Color3.fromRGB(62, 28, 26)
-- Terciopelo de verdad (MaterialVariant de Poly Haven, 11.8.2): con el Fabric de serie en un color tan oscuro las
-- cortinas se veían como ruido negro con brillos. Sin él (lugar sin Rojo), Fabric con los colores de arriba.
-- Se mira al hacer cada cortina, no al cargar: la carpeta puede llegar después.
local function hayTerciopelo(): boolean
	local materiales = game:GetService("MaterialService"):FindFirstChild("Materiales")
	return materiales ~= nil and materiales:FindFirstChild("Terciopelo") ~= nil
end
local temblor = 0 -- fuerza del temblor de la cámara, baja sola

-- Lo que Efectos necesita de cada ventana o puerta de fuera: dónde está y cómo avisar de que algo se acerca.
export type Elemento = {
	centro: CFrame, -- LookVector hacia fuera
	fuera: Vector3?, -- donde se planta el bicho (solo las atacables)
	acecho: (p: number, plantado: number, cabeza: Vector3?) -> (), -- p y plantado de 0 a 1; 0 y 0 = deja de notarse
	vibrar: ((fuerza: number) -> ())?, -- solo ventanas
}
CasaVista.elementos = {} :: { [Model]: Elemento }

-- Lo pone Efectos: trozos de cristal que se quedan en el suelo. Sin él, trocitos que se borran solos.
CasaVista.alRomper = nil :: ((el: Model, centro: CFrame, ancho: number, alto: number) -> ())?
-- Lo pone Efectos: cada golpe en una ventana o puerta hace temblar lo de alrededor (vasos, cuadros, lámparas).
CasaVista.alGolpe = nil :: ((donde: Vector3) -> ())?

local function poco(): boolean
	return jugador:GetAttribute("Rendimiento") == true
end

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

-- Temblor de la cámara si está a menos de `alcance` studs de `desde` (más flojo cuanto más lejos).
function CasaVista.temblar(desde: Vector3, fuerza: number, alcance: number?)
	local lejos = alcance or 35
	local distancia = (workspace.CurrentCamera.CFrame.Position - desde).Magnitude
	if distancia < lejos then
		temblor = math.max(temblor, fuerza * (1 - distancia / lejos))
	end
end

-- Polvo que cae: arenilla que baja deprisa y una nubecilla que se queda flotando. `cf` y `tam`, la caja de donde sale
-- (el borde de un marco, un trozo de techo). Se borra solo.
function CasaVista.polvo(cf: CFrame, tam: Vector3, cuanto: number)
	if poco() then
		cuanto = math.ceil(cuanto / 2)
	end
	local caja = Instance.new("Part")
	caja.Anchored = true
	caja.CanCollide = false
	caja.CanQuery = false
	caja.CanTouch = false
	caja.Transparency = 1
	caja.Size = tam
	caja.CFrame = cf
	caja.Parent = workspace.Terrain
	local arenilla = Instance.new("ParticleEmitter")
	arenilla.Texture = "rbxasset://textures/particles/smoke_main.dds"
	arenilla.Color = ColorSequence.new(Color3.fromRGB(104, 96, 84))
	arenilla.LightInfluence = 1
	arenilla.Size = NumberSequence.new(0.14, 0.09)
	arenilla.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(0.7, 0.35), NumberSequenceKeypoint.new(1, 1),
	})
	arenilla.Lifetime = NumberRange.new(0.9, 1.5)
	arenilla.Speed = NumberRange.new(0, 1.5)
	arenilla.SpreadAngle = Vector2.new(25, 25)
	arenilla.EmissionDirection = Enum.NormalId.Bottom
	arenilla.Acceleration = Vector3.new(0, -16, 0)
	arenilla.Drag = 0.6
	arenilla.Rotation = NumberRange.new(0, 360)
	arenilla.Rate = 0
	arenilla.Parent = caja
	local nube = arenilla:Clone()
	nube.Color = ColorSequence.new(Color3.fromRGB(130, 122, 110))
	nube.Size = NumberSequence.new(0.35, 1.8)
	nube.Transparency = NumberSequence.new(0.72, 1)
	nube.Lifetime = NumberRange.new(2, 3.2)
	nube.Speed = NumberRange.new(0.3, 1)
	nube.Acceleration = Vector3.new(0, -1.2, 0)
	nube.Drag = 1.5
	nube.RotSpeed = NumberRange.new(-20, 20)
	nube.Parent = caja
	arenilla:Emit(cuanto)
	nube:Emit(math.max(1, math.floor(cuanto / 4)))
	task.delay(4, caja.Destroy, caja)
end

-- Trocitos que caen (cristales, si nadie se encarga de dejarlos en el suelo). Se borran solos.
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

local function rango(r: { number }): number
	return azar:NextNumber(r[1], r[2])
end

local function ventana(el: Model)
	local centro = el:GetAttribute("Centro") :: CFrame
	local ancho, alto = el:GetAttribute("Ancho") :: number, el:GetAttribute("Alto") :: number
	local cristal = el:WaitForChild("Cristal") :: BasePart
	local cristalBase = cristal.CFrame -- el servidor no lo mueve: al vibrar se mueve desde aquí y vuelve
	local dentro = -centro.LookVector -- hacia la sala
	local semilla = azar:NextNumber(0, 100)
	local local_ = Instance.new("Folder")
	local_.Name = "Cortinas"
	local_.Parent = el

	-- Cortinas (pedido por el usuario: cortinas en vez de persianas; el atributo sigue llamándose Persiana): dos paños
	-- de pliegues de tela colgados de la barra, por dentro. Cerradas (bajado = 1) se juntan en el medio; abiertas, se
	-- recogen a los lados del marco.
	local caida = alto + 0.9 -- de la barra a un poco por debajo de la repisa
	local pliegues: { Part } = {}
	local tuerce: { number } = {}
	local function crearCortinas()
		local_:ClearAllChildren()
		table.clear(pliegues)
		for i = 1, PLIEGUES * 2 do
			local p = pieza(Vector3.new(0.5, caida, 0.08), centro, if i % 2 == 0 then TELA else TELA_OSCURA, local_)
			p.Material = Enum.Material.Fabric
			if hayTerciopelo() then
				p.MaterialVariant = "Terciopelo"
				p.Color = Color3.new(1, 1, 1) -- el color va en la textura
			end
			pliegues[i] = p
			tuerce[i] = azar:NextNumber(-1, 1)
		end
	end
	crearCortinas()

	local bajado = if el:GetAttribute("Persiana") then 1 else 0 -- 0 abiertas, 1 cerradas
	local rota = false
	local corriente = 0 -- algo pegado fuera (Efectos): las cortinas se mecen hacia dentro

	local function colocar(meneo: number)
		local danio = 1 - (el:GetAttribute("Vida") or 1) / (el:GetAttribute("VidaMax") or 1)
		local fuera = ancho / 2 + 0.6 -- el borde de fuera de cada paño, tras el marco
		local dentro_ = fuera - (0.9 + (fuera - 0.9) * bajado) -- el de dentro: recogido o en el medio
		local ancho_ = fuera - dentro_
		local ahora = os.clock()
		for i, p in pliegues do
			local lado = if i <= PLIEGUES then -1 else 1
			local k = (i - 1) % PLIEGUES -- de fuera hacia el medio
			local x = lado * (fuera - ancho_ * (k + 0.5) / PLIEGUES)
			local zigzag = if k % 2 == 0 then 1 else -1
			-- Rasgada con poca vida: los pliegues se caen hacia un lado y se acortan.
			local giro = if danio > 0.4 then tuerce[i] * danio * 0.3 else 0
			local corto = if danio > 0.6 then math.abs(tuerce[i]) * danio * 1.5 else 0
			-- La corriente: cada pliegue se hincha hacia dentro desde la barra, a rachas y no todos a la vez.
			local ondea, aleteo = 0, 0
			if corriente > 0 then
				local racha = 0.55 + math.noise(ahora * 0.9, semilla) + 0.6 * math.noise(ahora * 2.1, i * 0.37, semilla)
				ondea = corriente * CFG.Ondea * math.clamp(racha, 0.15, 1.3)
				aleteo = corriente * 0.12 * math.noise(ahora * 3, i * 0.71)
			end
			p.Size = Vector3.new(ancho_ / PLIEGUES * 1.25, caida - corto, 0.08)
			p.CFrame = centro * CFrame.new(x + aleteo + azar:NextNumber(-meneo, meneo), alto / 2 + 0.55, 0.75 + zigzag * 0.06)
				* CFrame.Angles(-ondea, 0, 0) * CFrame.new(0, -(caida + corto) / 2, 0)
				* CFrame.Angles(0, zigzag * math.rad(28) * (0.4 + 0.6 * bajado), giro)
		end
	end
	colocar(0)

	local moviendo = false
	local function mover(hacia: number)
		if moviendo then
			return
		end
		moviendo = true
		Sonido.en(if hacia > 0.5 then "CortinaCierra" else "Cortina", centro.Position) -- 1 cerradas, 0 abiertas
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

	-- Rota la ventana: las cortinas se arrancan y caen hacia dentro.
	local function romperCortinas()
		rota = true
		for _, p in pliegues do
			p.Anchored = false
			p.AssemblyLinearVelocity = dentro * azar:NextNumber(4, 10)
		end
	end

	local grietas = Instance.new("Folder")
	grietas.Name = "Grietas"
	grietas.Parent = el
	local enGrietas: { [BasePart]: CFrame } = {} -- grietas y picos, para que vibren con el cristal

	-- Picos de cristal que quedan clavados en el marco al romperse, apuntando al centro (cuñas finas).
	local function dientes()
		for i = 1, CFG.Dientes do
			local borde = i % 4 -- arriba, abajo, izquierda, derecha
			local base, haciaDentro
			if borde <= 1 then
				local y = if borde == 0 then alto / 2 else -alto / 2
				base = Vector2.new(azar:NextNumber(-ancho / 2 + 0.2, ancho / 2 - 0.2), y)
				haciaDentro = Vector2.new(azar:NextNumber(-0.5, 0.5), -math.sign(y))
			else
				local x = if borde == 2 then -ancho / 2 else ancho / 2
				base = Vector2.new(x, azar:NextNumber(-alto / 2 + 0.2, alto / 2 - 0.2))
				haciaDentro = Vector2.new(-math.sign(x), azar:NextNumber(-0.5, 0.5))
			end
			haciaDentro = haciaDentro.Unit
			local largo = azar:NextNumber(0.4, math.min(ancho, alto) * 0.32)
			local medio = base + haciaDentro * largo / 2
			local cuna = Instance.new("WedgePart")
			cuna.Anchored = true
			cuna.CanCollide = false
			cuna.CanQuery = false
			cuna.CanTouch = false
			cuna.CastShadow = false
			cuna.Material = Enum.Material.SmoothPlastic
			cuna.Color = cristal.Color
			cuna.Transparency = 0.55
			cuna.Reflectance = 0.08
			-- La cuña: triángulo en su plano YZ con la punta hacia +Y; se tumba en el plano del cristal.
			cuna.Size = Vector3.new(0.05, largo, azar:NextNumber(0.15, 0.5))
			cuna.CFrame = centro * CFrame.new(medio.X, medio.Y, 0) * CFrame.Angles(0, 0, math.atan2(-haciaDentro.X, haciaDentro.Y))
				* CFrame.Angles(0, math.pi / 2, 0)
			cuna.Parent = grietas
		end
	end

	local cristalAntes = el:GetAttribute("Cristal") or 0
	local function pintarCristal()
		local n = el:GetAttribute("Cristal") or 0
		grietas:ClearAllChildren()
		table.clear(enGrietas)
		local roto = n >= cfg.GolpesCristal
		cristal.LocalTransparencyModifier = if roto then 1 else 0
		if roto then
			dientes()
		else
			for _ = 1, n * 5 do
				local largo = azar:NextNumber(0.8, math.min(ancho, alto) * 0.7)
				pieza(Vector3.new(largo, 0.06, 0.25),
					centro * CFrame.new(azar:NextNumber(-ancho / 3, ancho / 3), azar:NextNumber(-alto / 3, alto / 3), 0)
						* CFrame.Angles(0, 0, azar:NextNumber(0, math.pi)),
					Color3.fromRGB(20, 22, 24), grietas).Material = Enum.Material.SmoothPlastic
			end
			for _, g in grietas:GetChildren() do
				if g:IsA("BasePart") then
					enGrietas[g] = g.CFrame
				end
			end
		end
		if n > cristalAntes then
			if roto then
				Sonido.en("Cristal", centro.Position)
				local alRomper = CasaVista.alRomper
				if alRomper then
					alRomper(el, centro, ancho, alto)
				else
					trozos(centro, 18, Color3.fromRGB(170, 190, 200), 0.5, dentro * 14)
				end
			else
				Sonido.en("Grieta", centro.Position)
			end
		end
		cristalAntes = n
	end
	pintarCristal()

	-- El cristal (con sus grietas) se mueve un poco en el marco; fuerza 0 = vuelve a su sitio.
	local cristalMovido = false
	local function moverCristal(fuerza: number)
		if fuerza <= 0 then
			if cristalMovido then
				cristalMovido = false
				cristal.CFrame = cristalBase
				for g, base in enGrietas do
					g.CFrame = base
				end
			end
			return
		end
		cristalMovido = true
		local v = CFG.VibraCristal * fuerza
		local delta = centro * CFrame.new(azar:NextNumber(-v, v) * 0.6, azar:NextNumber(-v, v) * 0.4, azar:NextNumber(-v, v))
			* CFrame.Angles(azar:NextNumber(-v, v) * 0.15, azar:NextNumber(-v, v) * 0.3, 0) * centro:Inverse()
		cristal.CFrame = delta * cristalBase
		for g, base in enGrietas do
			g.CFrame = delta * base
		end
	end

	-- Vaho en el cristal por fuera: dos manchas pálidas que laten como una respiración, a la altura de su cabeza.
	-- Cuelga fuera de la casa (en EfectosLocales, o en el Terrain si aún no está) para que lo que recorre la casa
	-- buscando piezas no lo cuente; se coloca siguiendo a la ventana y se quita si la ventana desaparece.
	local vaho: { Part } = {}
	local function empanar(fuerza: number, cabeza: Vector3?)
		if fuerza <= 0.01 or not cabeza or not el.Parent then
			for _, v in vaho do
				v:Destroy()
			end
			table.clear(vaho)
			return
		end
		if #vaho == 0 then
			local padre = workspace:FindFirstChild("EfectosLocales") or workspace.Terrain
			for i, d in { 1.7, 1.1 } do
				local v = pieza(Vector3.new(0.02, d, d * 0.85), centro, Color3.fromRGB(205, 210, 214), padre)
				v.Name = "Vaho" .. i
				v.Shape = Enum.PartType.Cylinder
				v.Material = Enum.Material.SmoothPlastic
				v.Transparency = 1
				vaho[i] = v
			end
		end
		local enCristal = centro:PointToObjectSpace(cabeza)
		local x = math.clamp(enCristal.X, -ancho / 2 + 0.9, ancho / 2 - 0.9)
		local y = math.clamp(enCristal.Y, -alto / 2 + 0.8, alto / 2 - 0.8)
		local respira = 0.6 + 0.4 * math.sin(os.clock() * 1.7 + semilla)
		for i, v in vaho do
			local desvio = if i == 1 then Vector2.zero else Vector2.new(0.35, -0.3)
			v.CFrame = centro * CFrame.new(x + desvio.X, y + desvio.Y, -0.115) * CFrame.Angles(0, math.pi / 2, 0)
			v.Transparency = 1 - CFG.Vaho * fuerza * respira * (if i == 1 then 1 else 0.8)
		end
	end

	local proximoVibra, proximoPolvo = 0, 0
	local function polvillo(cuanto: number)
		CasaVista.polvo(centro * CFrame.new(0, alto / 2 + 0.25, 0.55), Vector3.new(ancho, 0.1, 0.3), cuanto)
	end

	CasaVista.elementos[el] = {
		centro = centro,
		fuera = el:GetAttribute("Fuera"),
		acecho = function(p: number, plantado: number, cabeza: Vector3?)
			corriente = p
			if not rota and not moviendo then
				colocar(0)
			end
			local roto = (el:GetAttribute("Cristal") or 0) >= cfg.GolpesCristal
			local ahora = os.clock()
			if roto or p <= 0.02 then
				moverCristal(0)
			else
				-- Vibra a rachas, no sin parar.
				local racha = math.clamp(math.noise(ahora * 1.8, semilla, 3) * 2 + 0.3, 0, 1)
				moverCristal(p * racha)
				if p > CFG.VibraDesde and racha > 0.4 and ahora > proximoVibra then
					proximoVibra = ahora + rango(CFG.CadaVibra)
					local s = Sonido.en("CristalVibra", centro.Position, azar:NextNumber(0.92, 1.08))
					s.Volume *= math.min(1, p * 1.2)
				end
			end
			if p > 0.35 and ahora > proximoPolvo then
				proximoPolvo = ahora + rango(CFG.CadaPolvo)
				polvillo(math.ceil(8 * p))
			end
			empanar(if roto then 0 else plantado, cabeza)
		end,
		vibrar = function(fuerza: number)
			if (el:GetAttribute("Cristal") or 0) >= cfg.GolpesCristal then
				return
			end
			task.spawn(function()
				for _ = 1, 5 do
					moverCristal(fuerza)
					task.wait(0.03)
				end
				moverCristal(if corriente > 0.02 then corriente * 0.3 else 0)
			end)
		end,
	}

	el:GetAttributeChangedSignal("Persiana"):Connect(function()
		if not rota then
			task.spawn(mover, if el:GetAttribute("Persiana") then 1 else 0)
		end
	end)
	el:GetAttributeChangedSignal("Vida"):Connect(function()
		local vida = el:GetAttribute("Vida") or 0
		if vida <= 0 and not rota then
			romperCortinas()
		elseif vida > 0 and rota then -- reparada: cortinas nuevas
			rota = false
			crearCortinas()
			bajado = if el:GetAttribute("Persiana") then 1 else 0
		end
		colocar(0)
	end)
	el:GetAttributeChangedSignal("Cristal"):Connect(function()
		moverCristal(0)
		pintarCristal()
	end)
	el:GetAttributeChangedSignal("Golpes"):Connect(function()
		Sonido.en("Golpe", centro.Position, azar:NextNumber(0.7, 0.85))
		CasaVista.temblar(centro.Position, 0.5)
		polvillo(14)
		local alGolpe = CasaVista.alGolpe
		if alGolpe then
			alGolpe(centro.Position)
		end
		if not rota and not moviendo then
			for _ = 1, 4 do
				colocar(0.25)
				task.wait(0.03)
			end
			colocar(0)
		end
	end)
	el.Destroying:Once(function()
		CasaVista.elementos[el] = nil
		empanar(0) -- el vaho está fuera del modelo: no se va con él
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

	-- Polvo del dintel, por dentro (solo las de fuera tienen Centro).
	local centro = el:GetAttribute("Centro")
	local function polvillo(cuanto: number)
		if typeof(centro) == "CFrame" then
			CasaVista.polvo(centro * CFrame.new(0, hoja.Size.Y / 2 + 0.2, 0.5), Vector3.new(hoja.Size.X, 0.1, 0.3), cuanto)
		end
	end

	local portazos = el:GetAttribute("Portazo") or 0
	el:GetAttributeChangedSignal("Abierta"):Connect(function()
		local deGolpe = (el:GetAttribute("Portazo") or 0) ~= portazos
		portazos = el:GetAttribute("Portazo") or 0
		if deGolpe then
			Sonido.en("Golpe", hoja.Position, 0.9)
			CasaVista.temblar(hoja.Position, 0.6)
			polvillo(16)
		else
			Sonido.en(if el:GetAttribute("Abierta") then "Puerta" else "PuertaCierra", hoja.Position)
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
		CasaVista.temblar(hoja.Position, 0.5)
		polvillo(12)
		local alGolpe = CasaVista.alGolpe
		if alGolpe then
			alGolpe(hoja.Position)
		end
		traqueteo(3)
	end)

	-- Algo al otro lado de la puerta de fuera: la hoja se comba hacia dentro a ratos, cruje y suelta polvo del dintel.
	if typeof(centro) ~= "CFrame" then
		return
	end
	local semilla = azar:NextNumber(0, 100)
	local empujando = false
	local proximoCrujido, proximoPolvo = 0, 0
	CasaVista.elementos[el] = {
		centro = centro,
		fuera = el:GetAttribute("Fuera"),
		acecho = function(p: number)
			local cerrada = not el:GetAttribute("Abierta") and math.abs(angulo.Value) < 0.01
			local ahora = os.clock()
			if cerrada and p > 0.02 then
				local empuje = math.clamp(math.noise(ahora * 1.3, semilla) * 2 + 0.2, 0, 1)
				colocar(giro * CFG.Empuje * p * empuje)
				empujando = true
				if p > 0.5 and empuje > 0.6 and ahora > proximoCrujido then
					proximoCrujido = ahora + rango(CFG.CadaVibra)
					local s = Sonido.en("Crujido", hoja.Position, azar:NextNumber(0.85, 1))
					s.Volume *= 0.45 * p
				end
			elseif empujando then
				empujando = false
				colocar(angulo.Value)
			end
			if cerrada and p > 0.35 and ahora > proximoPolvo then
				proximoPolvo = ahora + rango(CFG.CadaPolvo)
				polvillo(math.ceil(7 * p))
			end
		end,
	}
	el.Destroying:Once(function()
		CasaVista.elementos[el] = nil
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
			-- Nunca en cinemáticas (la cámara la lleva un script).
			if camara.CameraType ~= Enum.CameraType.Scriptable then
				camara.CFrame *= CFrame.Angles(azar:NextNumber(-1, 1) * temblor * 0.02, azar:NextNumber(-1, 1) * temblor * 0.02, 0)
			end
			temblor = math.max(0, temblor - dt * 2)
		end
	end)
end

return CasaVista
