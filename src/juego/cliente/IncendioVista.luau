-- El incendio de la casa y la escena final de la Bestia (servidor: Incendio, remote Incendio). Todo local.
--   ("Prender", camino, porSala, inicio): el fuego corre del porche por el rastro y por los puntos de gasolina, uno cada
--     porSala s: llamas, humo, luz anaranjada que tiembla y los cristales de cerca que estallan con llamas asomando.
--     Se queda ardiendo (la casa ya no se usa: se vuelve al lobby).
--   ("Final", segundos): la escena, en planos desde fuera y de noche:
--     1. De lejos, desde el camino: la casa ardiendo por todas las ventanas, columnas de humo.
--     2. Abajo, junto al porche: el rugido de la Bestia desde dentro, la cámara tiembla.
--     3. De lado y alto: el tejado de delante cruje y se hunde hacia dentro, llamarada de chispas.
--     4. Muy de lejos: amanece (el cielo aclara) con la casa aún humeando.
--     5. Fundido a negro y "SHE'S GONE." con la raya roja (como "HAS ESCAPADO").
-- La escena esconde toda la interfaz, los carteles y a los personajes, y lo devuelve todo al acabar aunque algo falle
-- (en Studio no hay viaje al lobby y se sigue jugando). En Studio, el atributo IncendioT del Workspace congela la escena
-- en ese segundo (para revisar cada plano), como HuidaT.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sonido = require(script.Parent.Sonido)
local Ui = require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))

local IncendioVista = {}

local jugador = Players.LocalPlayer
local camara = workspace.CurrentCamera
local azar = Random.new()
local enMarcha = false

local LLAMA = Color3.fromRGB(255, 120, 40)
local LLAMA_OSCURA = Color3.fromRGB(120, 30, 10)
local HUMO = Color3.fromRGB(38, 35, 33)
local RADIO_VENTANAS = Config.Bestia.Ventanas -- studs: las ventanas a esta distancia de un punto que arde estallan
local LARGO_ESCENA = 20 -- los tiempos de los planos están pensados para 20 s; con otra duración se estiran

-- Noche y amanecer de la escena (la noche, como la de Ambiente; el alba, cálida y con bruma). Números a ojo.
local NOCHE = {
	Hora = 2.5,
	Brightness = 1.4,
	Ambient = Color3.fromRGB(26, 25, 28),
	OutdoorAmbient = Color3.fromRGB(62, 70, 92),
	Exposicion = 1.6,
	Densidad = 0.36,
	Niebla = Color3.fromRGB(30, 36, 52),
}
local ALBA = {
	Hora = 6.5,
	Brightness = 1.8,
	Ambient = Color3.fromRGB(58, 52, 52),
	OutdoorAmbient = Color3.fromRGB(120, 104, 98),
	Exposicion = 0.6,
	Densidad = 0.34,
	Niebla = Color3.fromRGB(150, 120, 105),
}

-- Lo que arde: cada foco se enciende a su `hora` (del servidor) y crece; su luz tiembla en un solo bucle.
type Foco = {
	parte: BasePart,
	hora: number,
	tam: number,
	fuegos: { Fire },
	luz: PointLight?,
	brillo: number,
	humo: Smoke?,
	sonido: boolean,
	vivo: boolean,
}

local carpeta: Folder? = nil -- lo que arde (se queda)
local focos: { Foco } = {}
local rotas: { [Instance]: boolean } = {}
local bucle: RBXScriptConnection? = nil
local fuerzaLuz = 1 -- la escena la baja al amanecer

local function pieza(tamano: Vector3, cf: CFrame, padre: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = tamano
	p.CFrame = cf
	p.Parent = padre
	return p
end

local function carpetaFuego(): Folder
	if not carpeta or not carpeta.Parent then
		local c = Instance.new("Folder")
		c.Name = "Incendio"
		c.Parent = workspace
		carpeta = c
	end
	return carpeta :: Folder
end

local function mezcla(a: number, b: number, k: number): number
	return a + (b - a) * k
end

-- Un sitio que arde. `tam`: tamaño de la llama grande (2 en el rastro, 8 en un punto). Con humo y luz si es grande.
local function foco(posicion: Vector3, hora: number, tam: number, padre: Instance?, conSonido: boolean?): Foco
	local base = pieza(Vector3.new(math.max(1, tam * 0.4), 0.4, math.max(1, tam * 0.4)), CFrame.new(posicion),
		padre or carpetaFuego())
	local fuegos = {}
	local sitios = if tam >= 4 then { Vector3.zero, Vector3.new(tam * 0.3, 0, tam * 0.15), Vector3.new(-tam * 0.25, 0, -tam * 0.2) }
		else { Vector3.zero }
	for i, desvio in sitios do
		local f = Instance.new("Fire")
		f.Color = LLAMA
		f.SecondaryColor = LLAMA_OSCURA
		f.Size = 0.5
		f.Heat = if i == 1 then tam + 4 else tam
		f.Enabled = false
		f.Parent = if i == 1 then base else pieza(Vector3.one, CFrame.new(posicion + desvio), base)
		table.insert(fuegos, f)
	end
	local luz, humo = nil, nil
	if tam >= 4 then
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(255, 130, 60)
		l.Range = math.min(40, tam * 3)
		l.Brightness = 0
		l.Shadows = true
		l.Parent = base
		luz = l
		local h = Instance.new("Smoke")
		h.Color = HUMO
		h.Opacity = 0.3
		h.Size = tam
		h.RiseVelocity = 6
		h.Enabled = false
		h.Parent = base
		humo = h
	end
	local f: Foco = {
		parte = base,
		hora = hora,
		tam = tam,
		fuegos = fuegos,
		luz = luz,
		brillo = if tam >= 6 then 1.6 else 1,
		humo = humo,
		sonido = conSonido == true,
		vivo = false,
	}
	table.insert(focos, f)
	return f
end

-- El bucle de todo lo que arde: enciende cada foco a su hora, lo hace crecer y hace temblar las luces.
local function arrancarBucle()
	if bucle then
		return
	end
	bucle = RunService.Heartbeat:Connect(function()
		local ahora = workspace:GetServerTimeNow()
		local reloj = os.clock()
		for i, f in focos do
			if not f.parte.Parent then
				continue
			end
			local pasado = ahora - f.hora
			if pasado < 0 then
				continue
			end
			if not f.vivo then
				f.vivo = true
				for _, fuego in f.fuegos do
					fuego.Enabled = true
				end
				if f.humo then
					f.humo.Enabled = true
				end
				if f.sonido then
					local s = Sonido.bucle("Fuego", f.parte)
					s.RollOffMode = Enum.RollOffMode.InverseTapered
					s.RollOffMinDistance = 8
					s.RollOffMaxDistance = 60
				end
			end
			local crece = math.min(1, pasado / 2.5)
			for j, fuego in f.fuegos do
				fuego.Size = math.max(0.5, f.tam * crece * (if j == 1 then 1 else 0.65))
			end
			if f.luz then
				f.luz.Brightness = f.brillo * crece * fuerzaLuz * (0.7 + 0.3 * math.noise(reloj * 7, i * 1.37))
			end
		end
	end)
end

-- Estalla el cristal de una ventana (solo aquí) hacia fuera y asoman las llamas. Una vez cada una.
local function romperVentana(el: Instance, hora: number)
	if rotas[el] then
		return
	end
	rotas[el] = true
	local centro = el:GetAttribute("Centro")
	local cristal = el:FindFirstChild("Cristal")
	if typeof(centro) ~= "CFrame" then
		return
	end
	local fuera = centro.LookVector -- CasaVista: la sala queda hacia -LookVector
	foco(centro.Position - fuera * 0.4 - Vector3.new(0, 1, 0), hora, 4.5)
	task.delay(math.max(0, hora - workspace:GetServerTimeNow()), function()
		if cristal and cristal:IsA("BasePart") then
			cristal.LocalTransparencyModifier = 1
		end
		Sonido.en("Cristal", centro.Position, azar:NextNumber(0.9, 1.1))
		for _ = 1, 10 do
			local p = pieza(Vector3.new(0.4, 0.4, 0.12),
				centro * CFrame.new(azar:NextNumber(-1.2, 1.2), azar:NextNumber(-1, 1), 0)
					* CFrame.Angles(azar:NextNumber(0, 6), azar:NextNumber(0, 6), 0), workspace.Terrain)
			p.Transparency = 0.3
			p.Color = Color3.fromRGB(170, 190, 200)
			p.Material = Enum.Material.Glass
			p.Anchored = false
			p.AssemblyLinearVelocity = fuera * azar:NextNumber(10, 18) + Vector3.new(azar:NextNumber(-4, 4), azar:NextNumber(2, 6), azar:NextNumber(-4, 4))
			task.delay(4, p.Destroy, p)
		end
	end)
end

-- Las ventanas a menos de RADIO_VENTANAS de `posicion` estallan un poco después de que llegue allí el fuego.
local function ventanasCerca(posicion: Vector3, hora: number)
	for _, el in CollectionService:GetTagged("Ventana") do
		local centro = el:GetAttribute("Centro")
		if typeof(centro) == "CFrame" and (centro.Position - posicion).Magnitude <= RADIO_VENTANAS then
			romperVentana(el, hora + azar:NextNumber(0.6, 2.2))
		end
	end
end

-- El fuego corre por `camino`: del porche (1) por el rastro hasta el primer punto (2) y luego de punto en punto.
local function prender(camino: { Vector3 }, porSala: number, inicio: number)
	-- El rastro: llamitas cada ~3 studs que se van encendiendo.
	local a, b = camino[1], camino[2]
	local largo = (b - a).Magnitude
	local trozos = math.clamp(math.floor(largo / 3), 1, 14)
	for i = 0, trozos - 1 do
		local k = i / trozos
		foco(a:Lerp(b, k) + Vector3.new(0, 0.3, 0), inicio + porSala * k, 2.2, nil, i == 0)
	end
	-- Los puntos de gasolina (y el sótano, el último): un fuego grande en cada uno.
	for i = 2, #camino do
		local hora = inicio + porSala * (i - 1)
		foco(camino[i] + Vector3.new(0, 0.5, 0), hora, if i == #camino then 10 else 8, nil, true)
		ventanasCerca(camino[i], hora)
	end
	arrancarBucle()
end

-- Mientras dura la escena manda ella en estas propiedades: Ambiente las pinta cada fotograma, así que si otro las cambia
-- se vuelven a poner al momento. Devuelve poner(objeto, propiedad, valor).
local function forzador(alAcabar: (() -> ()) -> ()): (Instance, string, any) -> ()
	local valores: { [Instance]: { [string]: any } } = {}
	local conexiones: { RBXScriptConnection } = {}
	alAcabar(function()
		for _, c in conexiones do
			c:Disconnect()
		end
	end)
	return function(objeto: Instance, propiedad: string, valor: any)
		local deEste = valores[objeto]
		if not deEste then
			deEste = {}
			valores[objeto] = deEste
		end
		if deEste[propiedad] == nil then
			table.insert(conexiones, objeto:GetPropertyChangedSignal(propiedad):Connect(function()
				local quiero = deEste[propiedad]
				if (objeto :: any)[propiedad] ~= quiero then
					(objeto :: any)[propiedad] = quiero
				end
			end))
		end
		deEste[propiedad] = valor;
		(objeto :: any)[propiedad] = valor
	end
end

-- Una copia del tejado de delante que se hunde hacia dentro girando sobre el alero (el de verdad se esconde aquí).
-- Devuelve hundir(p) con p de 0 a 1, o nil si no hay tejado.
local function tejadoQueCae(casa: Instance, padre: Instance, alAcabar: (() -> ()) -> ()): ((number) -> ())?
	local tejado: BasePart? = nil
	for _, t in casa:GetChildren() do
		if t:IsA("BasePart") and t.Name == "Tejado" and t.Position.Z < 0 then -- el faldón de la fachada (Mapa)
			tejado = t
		end
	end
	if not tejado then
		return nil
	end
	local original = tejado :: BasePart
	local copia = original:Clone()
	for _, d in copia:GetDescendants() do
		if not (d:IsA("BasePart") or d:IsA("Texture") or d:IsA("Decal") or d:IsA("SpecialMesh")) then
			d:Destroy()
		end
	end
	copia.Parent = padre
	original.LocalTransparencyModifier = 1
	alAcabar(function()
		original.LocalTransparencyModifier = 0
	end)
	-- La cumbrera y lo de encima (crestería, pinchos): se esconden al hundirse, como si ardieran.
	local cumbre: { BasePart } = {}
	for _, p in casa:GetDescendants() do
		if p:IsA("BasePart") and p.Position.Y > 39.3 and math.abs(p.Position.Z) < 2.5 then
			table.insert(cumbre, p)
		end
	end
	alAcabar(function()
		for _, p in cumbre do
			p.LocalTransparencyModifier = 0
		end
	end)
	local cf0 = original.CFrame
	local medio = original.Size.Z / 2
	local zAlero = if (cf0 * CFrame.new(0, 0, medio)).Y < (cf0 * CFrame.new(0, 0, -medio)).Y then medio else -medio
	local bisagra = cf0 * CFrame.new(0, 0, zAlero)
	local relativo = bisagra:Inverse() * cf0
	local function girado(angulo: number): CFrame
		return bisagra * CFrame.Angles(angulo, 0, 0) * relativo
	end
	-- Hacia donde la cumbre baja (hacia dentro de la casa).
	local signo = if (girado(0.6) * CFrame.new(0, 0, -zAlero)).Y < (girado(-0.6) * CFrame.new(0, 0, -zAlero)).Y then 1 else -1
	return function(p: number)
		local e = p * p -- empieza despacio y cae de golpe
		copia.CFrame = girado(signo * 0.65 * e) - Vector3.new(0, 4 * e, 0)
		for _, c in cumbre do
			c.LocalTransparencyModifier = if p > 0.25 then 1 else 0
		end
	end
end

-- `devolver`: lo que hay que deshacer al acabar (lo hace quien llama, aunque esto falle a medias).
local function escena(segundos: number, devolver: { () -> () })
	local mapa = workspace:FindFirstChild("Mapa")
	local casa = mapa and mapa:FindFirstChild("Casa")
	local local_ = Instance.new("Folder")
	local_.Name = "IncendioEscena"
	local_.Parent = workspace
	local function alAcabar(fn: () -> ())
		table.insert(devolver, fn)
	end
	alAcabar(function()
		local_:Destroy()
	end)

	-- Interfaz y personajes fuera.
	local guis = {}
	for _, gui in (jugador:WaitForChild("PlayerGui")):GetChildren() do
		if gui:IsA("LayerCollector") and gui.Enabled then -- también los carteles 3D (prompts, usar)
			gui.Enabled = false
			table.insert(guis, gui)
		end
	end
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)
	alAcabar(function()
		for _, gui in guis do
			gui.Enabled = true
		end
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, true)
	end)
	for _, otro in Players:GetPlayers() do
		for _, p in (otro.Character and otro.Character:GetDescendants() or {}) do
			if p:IsA("BasePart") or p:IsA("Decal") then
				p.LocalTransparencyModifier = 1
			end
		end
	end
	alAcabar(function()
		for _, otro in Players:GetPlayers() do
			for _, p in (otro.Character and otro.Character:GetDescendants() or {}) do
				if p:IsA("BasePart") or p:IsA("Decal") then
					p.LocalTransparencyModifier = 0
				end
			end
		end
	end)

	-- La casa entera en llamas: todas las ventanas (se quedan, como lo que ya ardía), fuego en el tejado, columnas de
	-- humo y luces anaranjadas fuera para que se vea la fachada. Lo de la escena va en `local_` y se quita al acabar.
	local ahora = workspace:GetServerTimeNow()
	for _, el in CollectionService:GetTagged("Ventana") do
		romperVentana(el, ahora + azar:NextNumber(0, 2.5))
	end
	local tejado: { Foco } = {}
	for x = -30, 30, 12 do
		-- Encima del faldón de delante (Mapa: en z = -8 está a y ≈ 37); al hundirse, quedan ardiendo sobre el hueco.
		table.insert(tejado, foco(Vector3.new(x, 37.8, -8), ahora + azar:NextNumber(0, 1), 9, local_))
	end
	for _, x in { -22, 4, 26 } do
		local h = Instance.new("Smoke")
		h.Color = HUMO
		h.Opacity = 0.45
		h.Size = 30
		h.RiseVelocity = 12
		h.Parent = pieza(Vector3.one, CFrame.new(x, 42, 2), local_)
	end
	local fuera: { PointLight } = {}
	for _, sitio in { Vector3.new(-24, 6, -40), Vector3.new(20, 6, -40), Vector3.new(0, 22, -38), Vector3.new(44, 10, -10) } do
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(255, 120, 50)
		l.Range = 45
		l.Brightness = 0
		l.Parent = pieza(Vector3.one, CFrame.new(sitio), local_)
		table.insert(fuera, l)
	end
	local chispas = Instance.new("ParticleEmitter")
	chispas.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	chispas.Color = ColorSequence.new(Color3.fromRGB(255, 170, 70), Color3.fromRGB(200, 60, 20))
	chispas.LightEmission = 0.6
	chispas.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
	chispas.Transparency = NumberSequence.new(0.1, 1)
	chispas.Lifetime = NumberRange.new(1.5, 3)
	chispas.Speed = NumberRange.new(10, 26)
	chispas.SpreadAngle = Vector2.new(40, 40)
	chispas.Acceleration = Vector3.new(0, -4, 0)
	chispas.EmissionDirection = Enum.NormalId.Top
	chispas.Rate = 6
	chispas.Parent = pieza(Vector3.new(60, 1, 12), CFrame.new(0, 34, -12), local_)
	arrancarBucle()
	local hundir = if casa then tejadoQueCae(casa, local_, alAcabar) else nil

	local fuego = Sonido.bucle("Fuego") -- el fuego grande, de fondo durante toda la escena
	fuego.Volume *= 2
	alAcabar(function()
		fuego:Destroy()
	end)

	-- Noche y amanecer: mandan sobre Ambiente mientras dura la escena.
	local poner = forzador(alAcabar)
	local atmosfera = Lighting:FindFirstChildOfClass("Atmosphere")
	alAcabar(function()
		fuerzaLuz = 1
	end)

	-- Fundido a negro y el título (como HuidaVista).
	local negro = Instance.new("ScreenGui")
	negro.Name = "Final"
	negro.IgnoreGuiInset = true
	negro.DisplayOrder = 100
	local fondo = Instance.new("Frame")
	fondo.Size = UDim2.fromScale(1, 1)
	fondo.BackgroundColor3 = Ui.Color.Negro
	fondo.BackgroundTransparency = 1
	fondo.Parent = negro
	local titulo = Ui.texto(Ui.mayusculas(Lang.t(nil, "She's gone.")), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.2),
		TextScaled = true,
		TextTransparency = 1,
	})
	titulo.Parent = fondo
	local raya = Instance.new("Frame") -- la raya roja de debajo, como en los carteles de noche
	raya.AnchorPoint = Vector2.new(0.5, 0)
	raya.Position = UDim2.fromScale(0.5, 0.6)
	raya.Size = UDim2.new(0, 0, 0, 3)
	raya.BorderSizePixel = 0
	raya.BackgroundColor3 = Ui.Color.Sangre
	raya.Parent = fondo
	negro.Parent = jugador:WaitForChild("PlayerGui")
	alAcabar(function()
		negro:Destroy()
	end)

	camara.CameraType = Enum.CameraType.Scriptable
	alAcabar(function()
		camara.CameraType = Enum.CameraType.Custom
	end)
	local escala = LARGO_ESCENA / math.max(1, segundos)
	local inicio = os.clock()
	local hecho: { [string]: boolean } = {}
	local function una(nombre: string): boolean -- true la primera vez (para los sonidos y golpes de un momento)
		if hecho[nombre] then
			return false
		end
		hecho[nombre] = true
		return true
	end
	local temblorHasta, temblorFuerza = 0, 0
	local function temblar(t: number, durante: number, fuerza: number)
		temblorHasta, temblorFuerza = t + durante, fuerza
	end
	local function plano(t: number, desde: number, hasta: number, ojoA: Vector3, ojoB: Vector3, mira: Vector3): CFrame
		local k = math.clamp((t - desde) / (hasta - desde), 0, 1)
		return CFrame.lookAt(ojoA:Lerp(ojoB, k), mira)
	end

	RunService:BindToRenderStep("Incendio", Enum.RenderPriority.Camera.Value + 20, function()
		-- En Studio, el atributo IncendioT del Workspace congela la escena en ese segundo (para revisar cada plano).
		local real = if RunService:IsStudio() and workspace:GetAttribute("IncendioT") then workspace:GetAttribute("IncendioT")
			else os.clock() - inicio
		local t = real * escala -- en segundos de una escena de 20

		-- Noche que amanece al final.
		local alba = math.clamp((t - 13.5) / 5, 0, 1)
		alba = alba * alba * (3 - 2 * alba)
		poner(Lighting, "ClockTime", mezcla(NOCHE.Hora, ALBA.Hora, alba))
		poner(Lighting, "Brightness", mezcla(NOCHE.Brightness, ALBA.Brightness, alba))
		poner(Lighting, "Ambient", NOCHE.Ambient:Lerp(ALBA.Ambient, alba))
		poner(Lighting, "OutdoorAmbient", NOCHE.OutdoorAmbient:Lerp(ALBA.OutdoorAmbient, alba))
		poner(Lighting, "ExposureCompensation", mezcla(NOCHE.Exposicion, ALBA.Exposicion, alba))
		if atmosfera then
			poner(atmosfera, "Density", mezcla(NOCHE.Densidad, ALBA.Densidad, alba))
			poner(atmosfera, "Color", NOCHE.Niebla:Lerp(ALBA.Niebla, alba))
			poner(atmosfera, "Decay", NOCHE.Niebla:Lerp(ALBA.Niebla, alba))
		end
		fuerzaLuz = 1 - 0.45 * alba
		local reloj = os.clock()
		for i, l in fuera do
			l.Brightness = 1.3 * fuerzaLuz * (0.7 + 0.3 * math.noise(reloj * 6, i * 2.1))
		end

		-- Lo que pasa: el rugido desde dentro, el tejado que se hunde.
		if t >= 5.6 and una("Rugido") then
			local rugido = Sonido.en("Rugido", Vector3.new(0, 4, 16), 0.7)
			rugido.Volume *= 1.6
			temblar(t, 1.6, 0.6)
		end
		if t >= 8 and una("Chillido") then
			Sonido.en("Chillido", Vector3.new(0, 4, 16), 0.6)
		end
		if t >= 9.9 and una("Crujido") then
			local crujido = Sonido.en("Crujido", Vector3.new(0, 34, -12), 0.8)
			crujido.Volume *= 1.5
		end
		local cae = math.clamp((t - 10.5) / 1.4, 0, 1)
		if hundir then
			hundir(cae)
		end
		if cae >= 0.6 and una("Caida") then
			Sonido.en("Caida", Vector3.new(0, 30, -12), 0.8)
			chispas:Emit(120)
			temblar(t, 1.3, 0.45)
		end
		for _, f in tejado do -- tras hundirse, las llamas del tejado suben
			f.tam = 9 + 14 * math.clamp((t - 11.2) / 1.5, 0, 1)
		end

		-- Cámara por planos.
		local cf
		if t < 5 then
			cf = plano(t, 0, 5, Vector3.new(10, 6, -112), Vector3.new(6, 8, -95), Vector3.new(0, 18, -5))
		elseif t < 9.5 then
			cf = plano(t, 5, 9.5, Vector3.new(-16, 3.2, -54), Vector3.new(-13, 3.6, -50), Vector3.new(0, 9, -33))
		elseif t < 14 then
			cf = plano(t, 9.5, 14, Vector3.new(62, 20, -78), Vector3.new(56, 21, -72), Vector3.new(0, 30, -12))
		else
			cf = plano(t, 14, LARGO_ESCENA, Vector3.new(-70, 16, -150), Vector3.new(-62, 18, -138), Vector3.new(0, 20, 0))
		end
		if t < temblorHasta then
			local f = temblorFuerza * (temblorHasta - t)
			cf *= CFrame.Angles(math.rad(math.noise(reloj * 25, 1) * f), math.rad(math.noise(reloj * 25, 2) * f), 0)
		end
		camara.CFrame = cf

		-- Fundido a negro y el título.
		if t > LARGO_ESCENA - 2.2 then
			fondo.BackgroundTransparency = math.max(0, 1 - (t - (LARGO_ESCENA - 2.2)) / 1.4)
			titulo.TextTransparency = math.max(0, 1 - (t - (LARGO_ESCENA - 1)) / 1)
			raya.Size = UDim2.new(math.clamp((t - (LARGO_ESCENA - 1)) / 1.2, 0, 1) * 0.42, 0, 0, 3)
		end
	end)
	alAcabar(function()
		RunService:UnbindFromRenderStep("Incendio")
	end)

	task.wait(segundos + 4) -- el servidor manda al lobby a los segundos + 2; en Studio se vuelve a jugar
	while RunService:IsStudio() and workspace:GetAttribute("IncendioT") do -- congelada para revisarla: sigue
		task.wait(0.5)
	end
end

function IncendioVista.start()
	Remotes.Incendio.OnClientEvent:Connect(function(que, a, b, c)
		if que == "Prender" and type(a) == "table" and #a >= 2 and type(b) == "number" and type(c) == "number" then
			prender(a, b, c)
		elseif que == "Final" and type(a) == "number" and not enMarcha then
			enMarcha = true
			local devolver = {}
			local ok, fallo = pcall(escena, a, devolver)
			if not ok then
				warn("[IncendioVista] " .. tostring(fallo))
			end
			for i = #devolver, 1, -1 do
				pcall(devolver[i])
			end
			enMarcha = false
		end
	end)
end

return IncendioVista
