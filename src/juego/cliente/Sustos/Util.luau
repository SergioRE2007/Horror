-- Lo común de los sustos sueltos (ver Sustos/init): dónde está la casa, qué mira la cámara, figuras oscuras, polvo,
-- tirón de cámara, parpadeo de luces y linterna, y lo que hay que devolver a su sitio al amanecer. Todo local.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ambiente = require(script.Parent.Parent.Ambiente)
local ManosGestos = require(script.Parent.Parent.ManosGestos)

local Util = {}

Util.cfg = {} :: any -- la tabla CFG de Sustos/init (la pone init al arrancar)
Util.azar = Random.new()

local jugador = Players.LocalPlayer
local ENCENDIDA = Color3.fromRGB(255, 214, 160) -- los colores de la bombilla de Generador (como DetallesVista)
local APAGADA = Color3.fromRGB(70, 66, 60)
Util.ENCENDIDA, Util.APAGADA = ENCENDIDA, APAGADA
Util.SANGRE = Color3.fromRGB(92, 8, 10)
-- Imágenes de sangre que ya usa el mapa (tools/blender/sangre.py; ya traen su color).
Util.IMAGEN = {
	Gotas = "rbxassetid://100856467107255", -- un manchón arriba y regueros que bajan
	Salpicadura = "rbxassetid://82919660578513",
}

function Util.entre(par: { number }): number
	return Util.azar:NextNumber(par[1], par[2])
end

---------------------------------------------------------------- la casa y la cámara

local carpeta: Folder? = nil
-- Carpeta local donde va todo lo que crean los sustos.
function Util.carpeta(): Folder
	if not carpeta or not carpeta.Parent then
		local c = Instance.new("Folder")
		c.Name = "Sustos"
		c.Parent = workspace
		carpeta = c
	end
	return carpeta :: Folder
end

function Util.casa(): Instance?
	local mapa = workspace:FindFirstChild("Mapa")
	return mapa and mapa:FindFirstChild("Casa")
end

-- Dentro de la casa (como Caza.dentroDeCasa), con `margen` studs de más alrededor ("junto a la casa").
function Util.dentro(p: Vector3, margen: number?): boolean
	local m = margen or 0
	if p.Y > 40 then
		return false
	end
	if math.abs(p.X) < Config.Casa.MedioX + m and math.abs(p.Z) < Config.Casa.MedioZ + m then
		return true
	end
	for _, a in Config.Casa.Anexos do
		if p.X > a[1] - m and p.X < a[2] + m and p.Z > a[3] - m and p.Z < a[4] + m then
			return true
		end
	end
	return false
end

-- Planta de la casa de una altura: 0 abajo (suelo en y = 1), 1 arriba (y = 14), 2 el desván.
function Util.planta(y: number): number
	return if y < 13.5 then 0 elseif y < 26.5 then 1 else 2
end

function Util.camara(): CFrame
	return workspace.CurrentCamera.CFrame
end

-- Hacia dónde mira la cámara, en horizontal.
function Util.delante(): Vector3
	local mira = Util.camara().LookVector * Vector3.new(1, 0, 1)
	return if mira.Magnitude > 1e-3 then mira.Unit else Vector3.new(0, 0, -1)
end

-- Coseno entre lo que mira la cámara y la dirección a `p` (1 = justo en el centro de la pantalla).
function Util.mirada(p: Vector3): number
	local cf = Util.camara()
	local hacia = p - cf.Position
	if hacia.Magnitude < 1e-3 then
		return 1
	end
	return cf.LookVector:Dot(hacia.Unit)
end

-- Los pies del jugador (o la cámara si aún no hay personaje).
function Util.pies(): Vector3
	local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if raiz then
		return raiz.Position - Vector3.new(0, 3, 0)
	end
	return Util.camara().Position - Vector3.new(0, 4.5, 0)
end

local function parametros(ignorar: { Instance }?): RaycastParams
	local lista = { Util.carpeta() } :: { Instance }
	if jugador.Character then
		table.insert(lista, jugador.Character)
	end
	local bichos = workspace:FindFirstChild("Bichos")
	if bichos then
		table.insert(lista, bichos)
	end
	for _, i in ignorar or {} do
		table.insert(lista, i)
	end
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.FilterDescendantsInstances = lista
	return p
end

function Util.rayo(desde: Vector3, hacia: Vector3, ignorar: { Instance }?): RaycastResult?
	return workspace:Raycast(desde, hacia, parametros(ignorar))
end

-- Nada que tape la vista de `desde` a `hasta` (paredes y suelos; los muebles no cuentan, no se dejan tocar con rayos).
function Util.libre(desde: Vector3, hasta: Vector3, ignorar: { Instance }?): boolean
	local r = Util.rayo(desde, hasta - desde, ignorar)
	return r == nil or (r.Position - hasta).Magnitude < 0.8
end

-- Altura del suelo bajo `p` (buscando hasta `alto` studs por debajo).
function Util.suelo(p: Vector3, alto: number?, ignorar: { Instance }?): number?
	local r = Util.rayo(p, Vector3.new(0, -(alto or 12), 0), ignorar)
	return r and r.Position.Y
end

-- Altura del techo sobre `p` (hasta 16 studs).
function Util.techo(p: Vector3): number?
	local r = Util.rayo(p, Vector3.new(0, 16, 0))
	return if r and r.Normal.Y < -0.7 then r.Position.Y else nil
end

-- Lo más alto de los muebles de la casa justo bajo `p`, por encima de `suelo` y por debajo de `p` (los muebles no se
-- dejan tocar con rayos: se miran sus cajas). Para que lo que cae no atraviese una cómoda.
function Util.encimaDeMuebles(p: Vector3, suelo: number, ignorar: Instance?): number
	local casa = Util.casa()
	local alto = suelo
	if not casa then
		return alto
	end
	for _, m in casa:GetChildren() do
		if m:IsA("Model") and m ~= ignorar and not CollectionService:HasTag(m, "Ventana") and not CollectionService:HasTag(m, "Puerta") then
			local pivote = m:GetPivot().Position
			if math.abs(pivote.X - p.X) < 6 and math.abs(pivote.Z - p.Z) < 6 then
				local cf, tam = m:GetBoundingBox()
				local local_ = cf:PointToObjectSpace(Vector3.new(p.X, cf.Y, p.Z))
				local arriba = cf.Y + tam.Y / 2
				if math.abs(local_.X) < tam.X / 2 and math.abs(local_.Z) < tam.Z / 2 and arriba > alto and arriba < p.Y - 0.2
					and tam.Y > 0.5 then
					alto = arriba
				end
			end
		end
	end
	return alto
end

---------------------------------------------------------------- bichos y luces

-- Algún bicho a menos de `distancia` de la cámara.
function Util.bichoCerca(distancia: number): boolean
	local bichos = workspace:FindFirstChild("Bichos")
	if not bichos then
		return false
	end
	local p = Util.camara().Position
	for _, b in bichos:GetChildren() do
		if b:IsA("Model") and (b:GetPivot().Position - p).Magnitude < distancia then
			return true
		end
	end
	return false
end

-- El generador está encendido (hay luz en la casa).
function Util.hayLuz(): boolean
	local gen = CollectionService:GetTagged("Generador")[1]
	return gen ~= nil and gen:GetAttribute("Encendido") == true
end

local lamparas: { PointLight } = {}
local conLamparas = false
-- Las bombillas de la casa (PointLight dentro de una pieza "Lampara", como en DetallesVista).
function Util.lamparas(): { PointLight }
	local casa = Util.casa()
	if not conLamparas and casa then
		conLamparas = true
		local function apuntar(d: Instance)
			if d:IsA("PointLight") and d.Parent and d.Parent.Name == "Lampara" and d.Parent:IsA("BasePart") then
				table.insert(lamparas, d)
			end
		end
		for _, d in casa:GetDescendants() do
			apuntar(d)
		end
		casa.DescendantAdded:Connect(apuntar)
	end
	for i = #lamparas, 1, -1 do
		if not lamparas[i].Parent then
			table.remove(lamparas, i)
		end
	end
	return lamparas
end

-- Las bombillas encendidas a menos de `distancia` de `p` y en la misma planta.
function Util.lamparasCerca(p: Vector3, distancia: number): { PointLight }
	local lista = {}
	for _, luz in Util.lamparas() do
		local pieza = luz.Parent :: BasePart
		if luz.Enabled and (pieza.Position - p).Magnitude < distancia and Util.planta(pieza.Position.Y - 2) == Util.planta(p.Y) then
			table.insert(lista, luz)
		end
	end
	return lista
end

-- Mi linterna (la pone EquipoVista en el Terrain y le da el brillo cada fotograma).
function Util.miLinterna(): SpotLight?
	local punto = workspace.Terrain:FindFirstChild("Linterna")
	return punto and punto:FindFirstChildOfClass("SpotLight")
end

function Util.linternaEncendida(): boolean
	return jugador:GetAttribute("Linterna") == true and Util.miLinterna() ~= nil
end

---------------------------------------------------------------- lo de cada susto y lo del amanecer

local alAcabar: { () -> () } = {}
-- Algo que se deshace al acabar el susto en marcha, aunque falle a medias.
function Util.alAcabar(fn: () -> ())
	table.insert(alAcabar, fn)
end

-- Una pieza o conexión que se quita al acabar el susto.
function Util.temporal<T>(cosa: T): T
	table.insert(alAcabar, function()
		local c: any = cosa
		if typeof(c) == "RBXScriptConnection" then
			c:Disconnect()
		elseif typeof(c) == "Instance" then
			c:Destroy()
		end
	end)
	return cosa
end

function Util.acabar()
	local lista = alAcabar
	alAcabar = {}
	for i = #lista, 1, -1 do
		local ok, fallo = pcall(lista[i])
		if not ok then
			warn("Sustos: al acabar", fallo)
		end
	end
end

local alAlba: { () -> () } = {}
-- Lo que se deja movido o roto hasta que amanezca (y entonces vuelve a su sitio).
function Util.alAlba(fn: () -> ())
	table.insert(alAlba, fn)
end

function Util.alba()
	local lista = alAlba
	alAlba = {}
	for _, fn in lista do
		local ok, fallo = pcall(fn)
		if not ok then
			warn("Sustos: al amanecer", fallo)
		end
	end
end

local vigilantes: { () -> boolean } = {}
-- Algo que mira de vez en cuando (en el bucle de Sustos, cada poco) hasta que devuelve true.
function Util.vigilar(fn: () -> boolean)
	table.insert(vigilantes, fn)
end

function Util.vigilarTodo()
	for i = #vigilantes, 1, -1 do
		local ok, hecho = pcall(vigilantes[i])
		if not ok or hecho then
			table.remove(vigilantes, i)
		end
	end
end

---------------------------------------------------------------- piezas y efectos

function Util.pieza(tamano: Vector3, cf: CFrame, color: Color3, padre: Instance?, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = tamano
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = padre or Util.carpeta()
	return p
end

export type Figura = { modelo: Model, poner: (cf: CFrame, t: number) -> () }

-- Una figura alta, flaca y encorvada (unos 8 studs), con los brazos largos colgando hasta las rodillas y la cabeza ladeada.
-- `palida`: cara blanquecina con las cuencas y la boca negras (la que se ve con la linterna); si no, toda negra
-- (silueta contra la luna). `poner(cf, t)`: los pies en `cf` mirando a su LookVector; `t` para el leve vaivén.
function Util.figura(palida: boolean): Figura
	local modelo = Instance.new("Model")
	modelo.Name = "Figura"
	local NEGRO = Color3.fromRGB(16, 15, 15)
	local CARA = Color3.fromRGB(158, 152, 142)
	local partes: { [string]: Part } = {}
	local function parte(nombre: string, tamano: Vector3, color: Color3): Part
		local p = Util.pieza(tamano, CFrame.new(), color, modelo)
		p.Name = nombre
		partes[nombre] = p
		return p
	end
	parte("Torso", Vector3.new(1.2, 2.8, 0.7), NEGRO)
	parte("Cuello", Vector3.new(0.32, 0.7, 0.32), NEGRO)
	local cabeza = parte("Cabeza", Vector3.new(1.1, 1.1, 1.1), if palida then CARA else NEGRO)
	cabeza.Shape = Enum.PartType.Ball
	for _, lado in { "I", "D" } do
		parte("Brazo" .. lado, Vector3.new(0.28, 4.8, 0.28), NEGRO)
		parte("Pierna" .. lado, Vector3.new(0.42, 3.8, 0.42), NEGRO)
		if palida then
			parte("Ojo" .. lado, Vector3.new(0.24, 0.2, 0.06), Color3.new(0, 0, 0))
		end
	end
	if palida then
		parte("Boca", Vector3.new(0.22, 0.42, 0.06), Color3.new(0, 0, 0))
	end
	modelo.Parent = Util.carpeta()
	local ladeo = math.rad(Util.azar:NextNumber(14, 24)) * (if Util.azar:NextNumber() < 0.5 then 1 else -1)
	local function poner(cf: CFrame, t: number)
		local base = cf * CFrame.Angles(0, 0, math.sin(t * 0.7) * 0.02)
		local cadera = base * CFrame.new(0, 3.8, 0)
		for i, lado in { "I", "D" } do
			local s = if i == 1 then -1 else 1
			partes["Pierna" .. lado].CFrame = cadera * CFrame.new(0.32 * s, -1.9, 0)
		end
		-- Encorvada: el torso algo hacia delante y el cuello más aún, con la cabeza ladeada.
		local torso = cadera * CFrame.Angles(math.rad(-9), 0, 0) * CFrame.new(0, 1.4, 0)
		partes.Torso.CFrame = torso
		local cuello = torso * CFrame.new(0, 1.4, -0.1) * CFrame.Angles(math.rad(-22), 0, ladeo * 0.4) * CFrame.new(0, 0.3, 0)
		partes.Cuello.CFrame = cuello
		local cara = cuello * CFrame.new(0, 0.75, 0) * CFrame.Angles(math.rad(14), 0, ladeo + math.sin(t * 0.5) * 0.04)
		cabeza.CFrame = cara
		for i, lado in { "I", "D" } do
			local s = if i == 1 then -1 else 1
			partes["Brazo" .. lado].CFrame = torso * CFrame.new(0.78 * s, 1.25, 0) * CFrame.Angles(math.rad(9), 0, math.rad(5 * s))
				* CFrame.new(0, -2.4, 0)
			local ojo = partes["Ojo" .. lado]
			if ojo then
				ojo.CFrame = cara * CFrame.new(0.21 * s, 0.1, -0.52)
			end
		end
		if partes.Boca then
			partes.Boca.CFrame = cara * CFrame.new(0, -0.27, -0.5)
		end
	end
	return { modelo = modelo, poner = poner }
end

-- Polvo y arenilla que caen de `p` (techo o pared): una nube floja y unos granitos que rebotan en el suelo.
function Util.polvo(p: Vector3, cuanto: number)
	local punto = Instance.new("Attachment")
	punto.WorldPosition = p
	punto.Parent = workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.LightInfluence = 1
	e.Color = ColorSequence.new(Color3.fromRGB(150, 140, 122))
	e.Transparency = NumberSequence.new(0.55, 1)
	e.Size = NumberSequence.new(0.3, 1.6)
	e.Lifetime = NumberRange.new(1.2, 2.2)
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(40, 40)
	e.Acceleration = Vector3.new(0, -3, 0)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Rate = 0
	e.Parent = punto
	e:Emit(math.ceil(cuanto * 6))
	for _ = 1, math.ceil(cuanto * 5) do
		local g = Util.pieza(Vector3.one * Util.azar:NextNumber(0.06, 0.13),
			CFrame.new(p + Vector3.new(Util.azar:NextNumber(-0.6, 0.6), -0.1, Util.azar:NextNumber(-0.6, 0.6))),
			Color3.fromRGB(128, 118, 100), workspace.Terrain, Enum.Material.Concrete)
		g.Anchored = false
		g.CanCollide = true
		g.Massless = true
		g.CastShadow = false
		task.delay(2.5, g.Destroy, g)
	end
	task.delay(3, punto.Destroy, punto)
end

-- Un tirón de la cámara, como un respingo (más flojo cuanto más lejos esté `desde`, si se da).
function Util.tiron(fuerza: number)
	ManosGestos.sobresalto(fuerza) -- y las manos suben de golpe, por reflejo
	local nombre = "SustosTiron"
	local fin = os.clock() + 0.35
	pcall(RunService.UnbindFromRenderStep, RunService, nombre)
	RunService:BindToRenderStep(nombre, Enum.RenderPriority.Camera.Value + 2, function()
		local queda = (fin - os.clock()) / 0.35
		if queda <= 0 then
			RunService:UnbindFromRenderStep(nombre)
			return
		end
		local f = fuerza * queda * 0.025
		local camara = workspace.CurrentCamera
		camara.CFrame *= CFrame.Angles(Util.azar:NextNumber(-1, 1) * f, Util.azar:NextNumber(-1, 1) * f, 0)
	end)
end

-- Apaga a tirones las bombillas de `luces` y mi linterna (si está encendida) siguiendo `pasos` = { { cuánta luz
-- queda (0 a 1), segundos }, ... }. `alPaso(i)` se llama al empezar cada paso. Espera hasta acabar. Las bombillas se
-- apagan con Ambiente.factor, como hace DetallesVista; se escribe cada fotograma para que su parpadeo no lo pise.
function Util.parpadeo(luces: { PointLight }, pasos: { { number } }, alPaso: ((number) -> ())?)
	local f = 1
	local colores: { [BasePart]: Color3 } = {}
	for _, luz in luces do
		local pieza = luz.Parent
		if pieza and pieza:IsA("BasePart") then
			colores[pieza] = pieza.Color
		end
	end
	local conexion = RunService.RenderStepped:Connect(function()
		for _, luz in luces do
			Ambiente.factor[luz] = f
		end
		for pieza, color in colores do
			pieza.Color = APAGADA:Lerp(color, math.min(f, 1))
		end
	end)
	local nombre = "SustosLinterna"
	pcall(RunService.UnbindFromRenderStep, RunService, nombre)
	-- Después de EquipoVista (Camera + 1), que le pone el brillo cada fotograma.
	RunService:BindToRenderStep(nombre, Enum.RenderPriority.Camera.Value + 3, function()
		local foco = Util.miLinterna()
		if foco then
			foco.Brightness *= f
		end
	end)
	local function devolver()
		conexion:Disconnect()
		pcall(RunService.UnbindFromRenderStep, RunService, nombre)
		for _, luz in luces do
			Ambiente.factor[luz] = nil
		end
		for pieza, color in colores do
			pieza.Color = color
		end
	end
	Util.alAcabar(devolver) -- por si el susto falla a medias
	for i, paso in pasos do
		f = paso[1]
		if alPaso then
			alPaso(i)
		end
		task.wait(paso[2])
	end
	devolver()
end

-- Un tirón de linterna y luces corto (para cuando algo desaparece).
Util.CORTE = { { 0.05, 0.07 }, { 1, 0.05 }, { 0, 0.22 }, { 0.5, 0.04 }, { 0, 0.07 }, { 1, 0.01 } }

-- Quita una figura o pieza poco a poco.
function Util.desvanecer(modelo: Instance, segundos: number)
	local TweenService = game:GetService("TweenService")
	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") then
			TweenService:Create(d, TweenInfo.new(segundos), { Transparency = 1 }):Play()
		end
	end
	task.delay(segundos, modelo.Destroy, modelo)
end

return Util
