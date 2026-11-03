-- El incendio de la casa y la escena final de la Bestia (servidor: Incendio, remote Incendio). Todo local.
--   ("Apagar"): el fuego se ha cancelado antes del final (han muerto todos o ha amanecido): se quita todo.
--   ("Prender", camino, porSala, inicio): el fuego corre del porche por el rastro y por los puntos de gasolina, uno cada
--     porSala s, y desde ellos se come la casa entera (pedido por el usuario: "el fuego se ve pequeño"):
--       - cada punto, una hoguera que llena la sala;
--       - las ventanas estallan según les llega el fuego (de la más cercana a lo que arde a la más lejana) y por ellas
--         salen lenguas de fuego que lamen la fachada y humo negro;
--       - el tejado prende desde encima del dormitorio grande y se extiende por los dos faldones, con columnas de humo
--         negro muy altas y brasas que vuelan;
--       - luces anaranjadas fuera que tiemblan e iluminan el patio y el bosque de cerca; crujidos de madera sueltos.
--     Se queda ardiendo (la casa ya no se usa: se vuelve al lobby).
--   ("Final", segundos): la escena, en planos desde fuera y de noche:
--     1. De lejos, desde el camino: la casa ardiendo por todas las ventanas y el tejado, columnas de humo.
--     2. Abajo, junto al porche: el rugido de la Bestia desde dentro, la cámara tiembla, cae una viga ardiendo.
--     3. De lado y alto: el tejado de delante cruje y se hunde hacia dentro, llamarada enorme y chispas.
--     4. Muy de lejos: amanece (el cielo aclara) con la casa aún ardiendo y humeando.
--     5. Fundido a negro y "SHE'S GONE." con la raya roja (como "HAS ESCAPADO").
-- La escena esconde toda la interfaz, los carteles y a los personajes, y lo devuelve todo al acabar aunque algo falle
-- (en Studio no hay viaje al lobby y se sigue jugando). En Studio, el atributo IncendioT del Workspace congela la escena
-- en ese segundo (para revisar cada plano), como HuidaT.
-- Rendimiento: las llamas son ParticleEmitter (las Fire de Roblox se quedan pequeñas) con un tope de emisores y luces;
-- con el atributo Rendimiento del jugador (opción de Ajustes, 14.4) salen la mitad de partículas y sin luces de ventana.
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
local LARGO_ESCENA = 20 -- los tiempos de los planos están pensados para 20 s; con otra duración se estiran
local TEX_LLAMA = "rbxasset://textures/particles/fire_main.dds"
local TEX_HUMO = "rbxasset://textures/particles/smoke_main.dds"
local TEX_CHISPA = "rbxasset://textures/particles/sparkles_main.dds"

-- Números del incendio, solo de cómo se ve (a ojo).
local PROPAGA = 7 -- studs/s: lo que tarda el fuego en llegar de un punto que arde a cada ventana
local PROPAGA_TEJADO = 8 -- studs/s por el tejado, desde encima del dormitorio grande
local TEJADO_ANTES = 2 -- s: el tejado prende esto antes de que llegue el fuego al dormitorio grande
local CRECE = 2.5 -- s que tarda cada llama en llegar a su tamaño
local LUZ_FUERA = 1.6 -- brillo de las luces de fuera (pedido por el usuario: luces flojas; de noche esto ya alumbra)
local ALCANCE_FUERA = 60 -- studs de esas luces: el patio y el bosque de cerca
local CRUJIDOS = 60 -- s que suenan crujidos sueltos de madera mientras arde

-- La casa (Mapa): x -39,5..39,5, z -33,5..33,5; tejado a dos aguas con la cumbrera a lo largo de x en z = 0, que sube
-- 9/24 por stud desde el alero (|z| = 34,5, y = 27).
local PENDIENTE, ALERO = 9 / 24, 34.5
local function alturaTejado(z: number): number
	return 27 + PENDIENTE * (ALERO - math.abs(z)) + 0.6
end
local DESDE_TEJADO = Vector3.new(25, 0, -14) -- encima del dormitorio grande: de aquí corre el fuego por el tejado

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

-- Lo que arde: cada foco se enciende a su `hora` (del servidor) y crece en CRECE s; su luz tiembla, en un solo bucle.
type Emisor = { e: ParticleEmitter, ritmo: number }
type Foco = {
	parte: BasePart,
	hora: number,
	tam: number,
	fuegos: { Fire },
	emisores: { Emisor },
	luz: PointLight?,
	brillo: number,
	sonido: boolean,
	alVivir: (() -> ())?,
	vivo: boolean,
	fuerza: number, -- la escena aviva las llamas del tejado al hundirse
	crecido: boolean?, -- ya a su tamaño y fuerza: el bucle solo hace temblar su luz
}

local carpeta: Folder? = nil -- lo que arde (se queda)
local focos: { Foco } = {}
local rotas: { [Instance]: boolean } = {}
local bucle: RBXScriptConnection? = nil
local fuerzaLuz = 1 -- la escena la baja al amanecer
local envuelta = false -- ya se ha preparado la casa entera ardiendo
local fuera: { PointLight } = {} -- las luces del patio
local horaFuera = math.huge -- desde cuándo alumbran

local function poco(): boolean
	return jugador:GetAttribute("Rendimiento") == true
end

local function pieza(tamano: Vector3, cf: CFrame, padre: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
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

local function secuencia(puntos: { { number } }): NumberSequence
	local lista = {}
	for _, p in puntos do
		table.insert(lista, NumberSequenceKeypoint.new(p[1], p[2]))
	end
	return NumberSequence.new(lista)
end

-- Un emisor de partículas en `padre` (una pieza invisible: sale de todo su volumen hacia su cara `cara`).
--   "Llama": lenguas de fuego de `escala` studs que suben. "Humo": humo negro espeso de `escala` studs al salir que se
--   hincha mucho y sube alto. "Brasa": chispas que vuelan con el aire caliente.
local function emisor(padre: BasePart, tipo: string, escala: number, ritmo: number, cara: Enum.NormalId?): Emisor
	local e = Instance.new("ParticleEmitter")
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.EmissionDirection = cara or Enum.NormalId.Top
	e.Rotation = NumberRange.new(-180, 180)
	e.Rate = 0
	e.Enabled = true
	if tipo == "Llama" then
		e.Texture = TEX_LLAMA
		e.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 225, 150)),
			ColorSequenceKeypoint.new(0.3, Color3.fromRGB(255, 135, 40)),
			ColorSequenceKeypoint.new(0.7, Color3.fromRGB(190, 45, 12)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 18, 10)),
		})
		e.LightEmission = 0.55
		e.LightInfluence = 0
		e.Size = secuencia({ { 0, escala * 0.45 }, { 0.3, escala }, { 1, escala * 0.25 } })
		e.Transparency = secuencia({ { 0, 0.7 }, { 0.12, 0.1 }, { 0.65, 0.35 }, { 1, 1 } })
		e.Lifetime = NumberRange.new(0.7, 1.3)
		e.Speed = NumberRange.new(escala * 0.5, escala * 1.1)
		e.Acceleration = Vector3.new(0, escala * 1.6, 0)
		e.Drag = 1.2
		e.SpreadAngle = Vector2.new(18, 18)
		e.RotSpeed = NumberRange.new(-50, 50)
	elseif tipo == "Humo" then
		e.Texture = TEX_HUMO
		e.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 72, 34)), -- abajo, teñido por el fuego
			ColorSequenceKeypoint.new(0.2, Color3.fromRGB(70, 58, 52)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(46, 44, 44)), -- gris oscuro: negro del todo no se ve de noche
		})
		e.LightEmission = 0
		e.LightInfluence = 0.15
		e.Size = secuencia({ { 0, escala * 0.5 }, { 1, escala * 2.4 } })
		e.Transparency = secuencia({ { 0, 1 }, { 0.06, 0.12 }, { 0.6, 0.3 }, { 1, 1 } })
		e.Lifetime = NumberRange.new(7, 11)
		e.Speed = NumberRange.new(escala * 0.35, escala * 0.6)
		e.Acceleration = Vector3.new(1.6, 1.2, 0.9) -- un poco de viento
		e.Drag = 0.25
		e.SpreadAngle = Vector2.new(12, 12)
		e.RotSpeed = NumberRange.new(-12, 12)
	else
		e.Texture = TEX_CHISPA
		e.Color = ColorSequence.new(Color3.fromRGB(255, 180, 80), Color3.fromRGB(210, 60, 20))
		e.LightEmission = 1
		e.LightInfluence = 0
		e.Size = secuencia({ { 0, escala * 0.3 }, { 1, 0 } })
		e.Transparency = secuencia({ { 0, 0.1 }, { 1, 1 } })
		e.Lifetime = NumberRange.new(2, 4)
		e.Speed = NumberRange.new(4, 12)
		e.Acceleration = Vector3.new(1.5, 3, 0.8)
		e.Drag = 0.4
		e.SpreadAngle = Vector2.new(50, 50)
		e.RotSpeed = NumberRange.new(-200, 200)
	end
	e.Parent = padre
	return { e = e, ritmo = if poco() then ritmo * 0.5 else ritmo }
end

local function nuevoFoco(parte: BasePart, hora: number, tam: number): Foco
	local f: Foco = {
		parte = parte,
		hora = hora,
		tam = tam,
		fuegos = {},
		emisores = {},
		luz = nil,
		brillo = 1,
		sonido = false,
		alVivir = nil,
		vivo = false,
		fuerza = 1,
	}
	table.insert(focos, f)
	return f
end

local function luz(padre: Instance, alcance: number, sombras: boolean): PointLight
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 125, 55)
	l.Range = alcance
	l.Brightness = 0
	l.Shadows = sombras
	l.Parent = padre
	return l
end

-- Un sitio del suelo que arde. `tam`: 2 en el rastro, 8 en un punto, 10 en el sótano. Los grandes llenan la sala de
-- llamas hasta el techo y alumbran.
local function foco(posicion: Vector3, hora: number, tam: number, padre: Instance?, conSonido: boolean?): Foco
	local grande = tam >= 4
	local base = pieza(Vector3.new(math.max(1, tam * 0.7), 0.6, math.max(1, tam * 0.7)), CFrame.new(posicion),
		padre or carpetaFuego())
	local f = nuevoFoco(base, hora, tam)
	local sitios = if grande then { Vector3.zero, Vector3.new(tam * 0.3, 0, tam * 0.15), Vector3.new(-tam * 0.25, 0, -tam * 0.2) }
		else { Vector3.zero }
	for i, desvio in sitios do
		local fuego = Instance.new("Fire")
		fuego.Color = LLAMA
		fuego.SecondaryColor = LLAMA_OSCURA
		fuego.Size = 0.5
		fuego.Heat = if i == 1 then tam + 4 else tam
		fuego.Enabled = false
		fuego.Parent = if i == 1 then base else pieza(Vector3.one, CFrame.new(posicion + desvio), base)
		table.insert(f.fuegos, fuego)
	end
	if grande then
		table.insert(f.emisores, emisor(base, "Llama", tam * 0.55, 30))
		table.insert(f.emisores, emisor(base, "Brasa", 1, 6))
		f.luz = luz(base, math.min(36, tam * 3.5), true)
		f.brillo = if tam >= 6 then 2 else 1.2
	else
		table.insert(f.emisores, emisor(base, "Llama", 1.8, 10))
	end
	f.sonido = conSonido == true
	return f
end

-- Estalla el cristal de una ventana (solo aquí) hacia fuera: salen lenguas de fuego que lamen la fachada y humo negro.
-- `modelo`: el modelo "Ventana" de Mapa (todas, también las de las salas cerradas). Una vez cada una.
local function romperVentana(modelo: Instance, hora: number, conLuz: boolean)
	if rotas[modelo] then
		return
	end
	local cristal = modelo:FindFirstChild("Cristal")
	if not (cristal and cristal:IsA("BasePart")) then
		return
	end
	rotas[modelo] = true
	local mira = cristal.CFrame -- Mapa: mira hacia fuera
	local fueraV = mira.LookVector
	local ancho, alto = cristal.Size.X, cristal.Size.Y
	-- Las llamas salen del hueco hacia fuera y suben pegadas a la pared; el humo, de la parte de arriba.
	local boca = pieza(Vector3.new(ancho * 0.85, alto * 0.6, 0.4), mira * CFrame.new(0, -alto * 0.1, -0.5), carpetaFuego())
	local f = nuevoFoco(boca, hora, 5)
	local lengua = emisor(boca, "Llama", math.clamp(ancho * 1.9, 5, 8), 34, Enum.NormalId.Front)
	lengua.e.Speed = NumberRange.new(4, 8)
	lengua.e.Lifetime = NumberRange.new(0.9, 1.6)
	table.insert(f.emisores, lengua)
	local alta = pieza(Vector3.new(ancho * 0.7, 0.4, 0.4), mira * CFrame.new(0, alto * 0.45, -0.6), boca)
	table.insert(f.emisores, emisor(alta, "Humo", 4, 2, Enum.NormalId.Front))
	if conLuz and not poco() then
		f.luz = luz(boca, 22, false)
		f.brillo = 1.3
	end
	f.alVivir = function()
		cristal.LocalTransparencyModifier = 1
		Sonido.en("Cristal", mira.Position, azar:NextNumber(0.9, 1.1))
		for _ = 1, 8 do
			local p = Instance.new("Part")
			p.Size = Vector3.new(0.4, 0.4, 0.12)
			p.CFrame = mira * CFrame.new(azar:NextNumber(-ancho / 2, ancho / 2), azar:NextNumber(-alto / 2, alto / 2), 0)
				* CFrame.Angles(azar:NextNumber(0, 6), azar:NextNumber(0, 6), 0)
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Transparency = 0.3
			p.Color = Color3.fromRGB(170, 190, 200)
			p.Material = Enum.Material.Glass
			p.AssemblyLinearVelocity = fueraV * azar:NextNumber(10, 18)
				+ Vector3.new(azar:NextNumber(-4, 4), azar:NextNumber(2, 6), azar:NextNumber(-4, 4))
			p.Parent = workspace.Terrain
			task.delay(4, p.Destroy, p)
		end
	end
end

local function ventanas(): { Instance }
	local mapa = workspace:FindFirstChild("Mapa")
	local casa = mapa and mapa:FindFirstChild("Casa")
	local lista = {}
	for _, d in (if casa then casa:GetDescendants() else {}) do
		if d.Name == "Ventana" and d:IsA("Model") and d:FindFirstChild("Cristal") then
			table.insert(lista, d)
		end
	end
	return lista
end

-- La casa entera: ventanas, tejado, humo y luces de fuera, cada cosa a la hora en que le llega el fuego desde lo que
-- ya arde (`ardiendo`: { {posición, hora} }).
local function envolver(ardiendo: { { any } }, inicioTejado: number)
	if envuelta then
		return
	end
	envuelta = true
	local function llega(pos: Vector3, velocidad: number): number
		local mejor = math.huge
		for _, a in ardiendo do
			mejor = math.min(mejor, (a[2] :: number) + ((a[1] :: Vector3) - pos).Magnitude / velocidad)
		end
		return mejor
	end
	-- Ventanas: una de cada tres con luz (con todas sería demasiado para el móvil).
	for i, v in ventanas() do
		local cristal = v:FindFirstChild("Cristal") :: BasePart
		romperVentana(v, llega(cristal.Position, PROPAGA) + azar:NextNumber(0.3, 1.8), i % 3 == 0)
	end
	-- Tejado: una rejilla de hogueras sobre los dos faldones, del dormitorio grande hacia fuera.
	local raiz = carpetaFuego()
	local primero = math.huge
	for _, x in { -33, -22, -11, 0, 11, 22, 33 } do
		for _, z in { -24, -9, 9, 24 } do
			local pos = Vector3.new(x + azar:NextNumber(-2, 2), alturaTejado(z), z)
			local hora = inicioTejado + (Vector3.new(x, 0, z) - DESDE_TEJADO).Magnitude / PROPAGA_TEJADO + azar:NextNumber(0, 1)
			primero = math.min(primero, hora)
			local base = pieza(Vector3.new(9, 1, 7), CFrame.new(pos), raiz)
			local f = nuevoFoco(base, hora, 9)
			table.insert(f.emisores, emisor(base, "Llama", 8, 14))
			if z == -9 or z == 9 then
				table.insert(f.emisores, emisor(base, "Brasa", 1.4, 5))
			end
		end
	end
	-- Columnas de humo negro, encima de la cumbrera: suben muy alto y se ven desde el camino.
	for _, x in { -27, -6, 14, 32 } do
		local pos = Vector3.new(x, alturaTejado(0) + 2, azar:NextNumber(-3, 3))
		local base = pieza(Vector3.new(14, 2, 10), CFrame.new(pos), raiz)
		local f = nuevoFoco(base, inicioTejado + (Vector3.new(x, 0, 0) - DESDE_TEJADO).Magnitude / PROPAGA_TEJADO + 1, 12)
		table.insert(f.emisores, emisor(base, "Humo", 16, 4))
	end
	-- Las paredes de fuera también arden: lenguas que trepan por la fachada (abajo y arriba) y por los lados.
	local paredes = {}
	for _, x in { -30, -18, -6, 6, 18 } do
		table.insert(paredes, CFrame.new(x + azar:NextNumber(-2, 2), 2, -34.4))
		table.insert(paredes, CFrame.new(x + 4 + azar:NextNumber(-2, 2), 15, -34.4))
	end
	for _, lado in { -1, 1 } do
		for _, z in { -20, 0, 20 } do
			table.insert(paredes, CFrame.new(40 * lado, if z == 0 then 15 else 2, z) * CFrame.Angles(0, math.pi / 2, 0))
		end
	end
	for _, cf in paredes do
		local base = pieza(Vector3.new(7, 4, 0.6), cf, raiz)
		local f = nuevoFoco(base, llega(cf.Position, PROPAGA) + azar:NextNumber(1.5, 4), 7)
		table.insert(f.emisores, emisor(base, "Llama", 6, 16))
	end
	-- El porche, de punta a punta: el rastro de gasolina prende las tablas.
	for x = -26, 24, 10 do
		local pos = Vector3.new(x + azar:NextNumber(-2, 2), 1.3, -37 + azar:NextNumber(-1.5, 1.5))
		local f = foco(pos, llega(pos, PROPAGA) + azar:NextNumber(2, 5), 5, raiz)
		if f.luz then -- sin luz propia: ya alumbran las de fuera
			f.luz:Destroy()
			f.luz = nil
		end
	end
	-- Las luces de fuera, a los cuatro lados y una encima: iluminan el patio, la fachada desde fuera y el bosque.
	horaFuera = math.min(primero, llega(Vector3.new(0, 1, -30), PROPAGA))
	for _, sitio in { Vector3.new(-24, 5, -50), Vector3.new(22, 5, -50), Vector3.new(0, 34, -24), Vector3.new(52, 6, 0),
		Vector3.new(-52, 6, 0), Vector3.new(0, 6, 48) } do
		table.insert(fuera, luz(pieza(Vector3.one, CFrame.new(sitio), raiz), ALCANCE_FUERA, false))
	end
	-- El rugido del fuego grande, en las cuatro esquinas, y crujidos sueltos de la madera.
	task.delay(math.max(0, horaFuera - workspace:GetServerTimeNow()), function()
		for _, sitio in { Vector3.new(-30, 10, -30), Vector3.new(30, 10, -30), Vector3.new(-30, 10, 30), Vector3.new(30, 10, 30) } do
			local s = Sonido.bucle("Fuego", pieza(Vector3.one, CFrame.new(sitio), raiz))
			s.Volume *= 2
			s.RollOffMode = Enum.RollOffMode.InverseTapered
			s.RollOffMinDistance = 20
			s.RollOffMaxDistance = 180
		end
		local hasta = os.clock() + CRUJIDOS
		while os.clock() < hasta and raiz.Parent do
			task.wait(azar:NextNumber(2, 4.5))
			local x, z = azar:NextNumber(-36, 36), azar:NextNumber(-30, 30)
			Sonido.en("Crujido", Vector3.new(x, alturaTejado(z), z), azar:NextNumber(0.7, 0.95))
		end
	end)
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
				if f.sonido then
					local s = Sonido.bucle("Fuego", f.parte)
					s.RollOffMode = Enum.RollOffMode.InverseTapered
					s.RollOffMinDistance = 8
					s.RollOffMaxDistance = 60
				end
				if f.alVivir then
					task.spawn(f.alVivir)
				end
			end
			local crece = math.min(1, pasado / CRECE)
			if f.crecido then -- ya a su tamaño: solo tiembla su luz
				if f.luz then
					f.luz.Brightness = f.brillo * fuerzaLuz * (0.65 + 0.35 * math.noise(reloj * 7, i * 1.37))
				end
				continue
			end
			f.crecido = crece >= 1
			for j, fuego in f.fuegos do
				fuego.Size = math.max(0.5, f.tam * crece * (if j == 1 then 1 else 0.65))
			end
			for _, em in f.emisores do
				em.e.Rate = em.ritmo * crece * f.fuerza
			end
			if f.luz then
				f.luz.Brightness = f.brillo * crece * fuerzaLuz * (0.65 + 0.35 * math.noise(reloj * 7, i * 1.37))
			end
		end
		local k = math.clamp((ahora - horaFuera) / 8, 0, 1)
		for i, l in fuera do
			l.Brightness = LUZ_FUERA * k * fuerzaLuz * (0.55 + 0.45 * math.noise(reloj * 5, i * 2.1))
		end
	end)
end

-- El fuego corre por `camino`: del porche (1) por el rastro hasta el primer punto (2) y luego de punto en punto; desde
-- ellos, la casa entera.
local function prender(camino: { Vector3 }, porSala: number, inicio: number)
	-- El rastro: llamitas cada ~3 studs que se van encendiendo.
	local a, b = camino[1], camino[2]
	local largo = (b - a).Magnitude
	local trozos = math.clamp(math.floor(largo / 3), 1, 14)
	for i = 0, trozos - 1 do
		local k = i / trozos
		foco(a:Lerp(b, k) + Vector3.new(0, 0.3, 0), inicio + porSala * k, 2.2, nil, i == 0)
	end
	-- Los puntos de gasolina (y el sótano, el último): una hoguera grande en cada uno.
	local ardiendo = {}
	local tejado = inicio + porSala * (#camino - 2)
	for i = 2, #camino do
		local hora = inicio + porSala * (i - 1)
		foco(camino[i] + Vector3.new(0, 0.5, 0), hora, if i == #camino then 10 else 8, nil, true)
		table.insert(ardiendo, { camino[i], hora })
		if camino[i].Y > 10 then -- el del piso de arriba (dormitorio grande): de ahí prende el tejado
			tejado = hora - TEJADO_ANTES
		end
	end
	envolver(ardiendo, tejado)
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
	copia.Color = copia.Color:Lerp(Color3.new(), 0.6) -- chamuscado
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

-- Una viga ardiendo que cae de `desde` (solo aquí, se queda en el suelo humeando).
local function viga(desde: Vector3, padre: Instance)
	local p = Instance.new("Part")
	p.Size = Vector3.new(0.9, 0.9, azar:NextNumber(6, 9))
	p.CFrame = CFrame.new(desde) * CFrame.Angles(azar:NextNumber(-0.4, 0.4), azar:NextNumber(0, 6.28), azar:NextNumber(-0.3, 0.3))
	p.Color = Color3.fromRGB(28, 20, 16)
	p.Material = Enum.Material.Wood
	p.CanCollide = true
	p.CanQuery = false
	p.CanTouch = false
	p.AssemblyLinearVelocity = Vector3.new(azar:NextNumber(-3, 3), azar:NextNumber(0, 4), -azar:NextNumber(4, 9))
	p.AssemblyAngularVelocity = Vector3.new(azar:NextNumber(-3, 3), azar:NextNumber(-2, 2), azar:NextNumber(-3, 3))
	local fuego = Instance.new("Fire")
	fuego.Color = LLAMA
	fuego.SecondaryColor = LLAMA_OSCURA
	fuego.Size = 4
	fuego.Heat = 8
	fuego.Parent = p
	p.Parent = padre
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

	-- La casa entera en llamas: lo que aún no ardía prende ya (también si se entra con la escena empezada).
	local ahora = workspace:GetServerTimeNow()
	if not envuelta then
		envolver({ { Vector3.new(0, 6, 0), ahora - 4 } }, ahora - 3)
	end
	for _, f in focos do
		if f.hora > ahora + 2.5 then
			f.hora = ahora + azar:NextNumber(0, 2.5)
		end
	end
	horaFuera = math.min(horaFuera, ahora - 8)
	local delante: { Foco } = {} -- las llamas del faldón de delante: se avivan al hundirse
	for _, f in focos do
		if f.tam == 9 and f.parte.Position.Z < 0 then
			table.insert(delante, f)
		end
	end
	-- La llamarada del hueco al hundirse el tejado (sale de golpe y se queda ardiendo muy alta).
	local hueco = pieza(Vector3.new(60, 2, 18), CFrame.new(0, 30, -14), local_)
	local llamarada = emisor(hueco, "Llama", 16, 0)
	local humoHueco = emisor(hueco, "Humo", 18, 0)
	local chispas = emisor(hueco, "Brasa", 2, 0)
	chispas.e.Speed = NumberRange.new(14, 32)
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

		-- Lo que pasa: el rugido desde dentro y una viga que cae junto al porche, el tejado que se hunde.
		if t >= 5.6 and una("Rugido") then
			local rugido = Sonido.en("Rugido", Vector3.new(0, 4, 16), 0.7)
			rugido.Volume *= 1.6
			temblar(t, 1.6, 0.6)
		end
		if t >= 7 and una("Viga") then
			viga(Vector3.new(-6, 24, -36), local_)
			Sonido.en("Crujido", Vector3.new(-6, 20, -36), 0.75)
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
			chispas.e:Emit(if poco() then 80 else 200)
			llamarada.e:Emit(if poco() then 30 else 70)
			temblar(t, 1.3, 0.45)
		end
		-- Tras hundirse, del hueco sale una llamarada que se queda, y las llamas de delante se avivan.
		local aviva = math.clamp((t - 11.2) / 1.5, 0, 1)
		llamarada.e.Rate = llamarada.ritmo + (if poco() then 10 else 22) * aviva
		humoHueco.e.Rate = (if poco() then 1.5 else 3) * aviva
		chispas.e.Rate = (if poco() then 6 else 14) * aviva
		for _, f in delante do
			f.fuerza = 1 + 0.8 * aviva
			f.crecido = false -- que el bucle le aplique la fuerza nueva
		end

		-- Cámara por planos.
		local cf
		if t < 5 then
			cf = plano(t, 0, 5, Vector3.new(10, 6, -112), Vector3.new(6, 8, -95), Vector3.new(0, 20, -5))
		elseif t < 9.5 then
			cf = plano(t, 5, 9.5, Vector3.new(-16, 3.2, -54), Vector3.new(-13, 3.6, -50), Vector3.new(0, 11, -33))
		elseif t < 14 then
			cf = plano(t, 9.5, 14, Vector3.new(62, 20, -78), Vector3.new(56, 21, -72), Vector3.new(0, 30, -12))
		else
			cf = plano(t, 14, LARGO_ESCENA, Vector3.new(-48, 62, -128), Vector3.new(-40, 66, -116), Vector3.new(0, 34, 0))
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

-- El fuego se ha cancelado (han muerto todos mientras corría o ha amanecido): todo como antes de prender.
local function apagar()
	if enMarcha then
		return
	end
	if bucle then
		bucle:Disconnect()
		bucle = nil
	end
	if carpeta then
		carpeta:Destroy() -- llamas, humo, luces y sonidos cuelgan de aquí
		carpeta = nil
	end
	table.clear(focos)
	table.clear(fuera)
	for modelo in rotas do
		local cristal = modelo:FindFirstChild("Cristal")
		if cristal and cristal:IsA("BasePart") then
			-- Como lo pinta CasaVista: roto por un bicho, sigue sin verse.
			local roto = (modelo:GetAttribute("Cristal") or 0) >= Config.Casa.GolpesCristal
			cristal.LocalTransparencyModifier = if roto then 1 else 0
		end
	end
	table.clear(rotas)
	envuelta = false
	horaFuera = math.huge
	fuerzaLuz = 1
end

function IncendioVista.start()
	Remotes.Incendio.OnClientEvent:Connect(function(que, a, b, c)
		if que == "Apagar" then
			apagar()
		elseif que == "Prender" and type(a) == "table" and #a >= 2 and type(b) == "number" and type(c) == "number" then
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
