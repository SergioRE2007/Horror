-- Mueve el cuerpo del Acechador en el cliente y hace sus ruidos (el servidor lo mueve y avisa con el remote Acechador).
--   Zancadas largas y lentas, encorvado, los brazos casi quietos; parado, quieto del todo como un tronco (da un tirón
--   de cabeza de vez en cuando).
--   "Rama": una rama que se parte bajo sus pies (en 3D). "Carga": ruge y se echa encima con los brazos por delante.
--   "Luz": la linterna le frena: se encoge, se tapa la cara y chilla.
-- Animación sencilla a propósito: se mejora más adelante (pedido por el usuario).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sonido = require(script.Parent.Sonido)

local AcechadorVista = {}

type Bicho = {
	modelo: Model,
	raiz: BasePart,
	motores: { [string]: Motor6D },
	fase: number,
	pisada: number,
	carga: number, -- os.clock en que se echó encima
	luz: number, -- os.clock de la última vez que le frenó la linterna
	chillido: number,
	encogido: number, -- 0..1, suave
	semilla: number,
}
local bichos: { [Model]: Bicho } = {}
local azar = Random.new()

local function preparar(modelo: Instance)
	if not modelo:IsA("Model") or modelo.Name ~= "Acechador" then
		return
	end
	local raiz = modelo:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not raiz then
		return
	end
	local motores = {}
	for _, nombre in { "Torso", "Cabeza", "Mandibula", "BrazoI", "BrazoD", "PiernaI", "PiernaD" } do
		motores[nombre] = raiz:WaitForChild(nombre, 5) :: Motor6D
	end
	bichos[modelo] = { modelo = modelo, raiz = raiz, motores = motores, fase = 0, pisada = 1, carga = -math.huge,
		luz = -math.huge, chillido = -math.huge, encogido = 0, semilla = math.random() * 100 }
end

local function animar(dt: number)
	local ahora = os.clock()
	local camara = workspace.CurrentCamera.CFrame.Position
	for modelo, b in bichos do
		if not modelo.Parent then
			bichos[modelo] = nil
			continue
		end
		if (b.raiz.Position - camara).Magnitude > 300 then
			continue
		end
		local m = b.motores
		local v = b.raiz.AssemblyLinearVelocity
		local rapidez = Vector3.new(v.X, 0, v.Z).Magnitude
		local paso = math.min(1, rapidez / 10)
		b.fase += dt * rapidez * 0.28
		local s = math.sin(b.fase)
		local cargando = ahora - b.carga < 20
		local frenado = ahora - b.luz < 2.5
		b.encogido += ((if frenado then 1 else 0) - b.encogido) * math.min(1, dt * (if frenado then 12 else 2))
		local chillando = ahora - b.chillido < 1.4

		m.PiernaI.Transform = CFrame.Angles(s * 0.55 * paso, 0, 0)
		m.PiernaD.Transform = CFrame.Angles(-s * 0.55 * paso, 0, 0)
		-- Brazos: casi quietos; echándose encima, por delante con las garras abiertas; con luz, delante de la cara.
		local delante = if cargando then 1.1 else 0
		local brazo = delante * (1 - b.encogido) + 2.4 * b.encogido
		local temblor = b.encogido * math.sin(ahora * 40) * 0.06
		m.BrazoI.Transform = CFrame.Angles(brazo - s * 0.12 * paso + temblor, 0, -0.05 + b.encogido * 0.4)
		m.BrazoD.Transform = CFrame.Angles(brazo + s * 0.12 * paso - temblor, 0, 0.05 - b.encogido * 0.4)
		m.Torso.Transform = CFrame.Angles((if cargando then -0.3 else 0) + b.encogido * 0.35, 0, s * 0.04 * paso)
		local tiron = if math.noise(ahora * 0.9, b.semilla) > 0.4 then 0.5 else 0
		m.Cabeza.Transform = CFrame.Angles(b.encogido * 0.5, b.encogido * 0.9 + (1 - paso) * tiron, math.sin(ahora * 0.4) * 0.1)
		m.Mandibula.Transform = CFrame.Angles(-(0.1 + (if cargando then 0.4 else 0) + (if chillando then 0.6 + math.sin(ahora * 30) * 0.1 else 0)), 0, 0)

		local lado = if s >= 0 then 1 else -1
		if rapidez > 2 and lado ~= b.pisada then
			b.pisada = lado
			Sonido.en("Paso", b.raiz.Position - Vector3.new(0, 7, 0), azar:NextNumber(0.6, 0.7))
		end
	end
end

local function cercano(punto: Vector3, maximo: number): Bicho?
	local mejor, distancia = nil, maximo
	for _, b in bichos do
		local d = (b.raiz.Position - punto).Magnitude
		if d < distancia then
			mejor, distancia = b, d
		end
	end
	return mejor
end

-- La cabeza está muy alta: se busca por cualquier punto cercano a ella.
function AcechadorVista.rugir(punto: Vector3): Model?
	local b = cercano(punto, 16)
	if b then
		b.chillido = os.clock()
		return b.modelo
	end
	return nil
end

function AcechadorVista.start()
	local carpeta = workspace:WaitForChild("Bichos")
	carpeta.ChildAdded:Connect(preparar)
	for _, modelo in carpeta:GetChildren() do
		task.spawn(preparar, modelo)
	end
	RunService.Stepped:Connect(function(_, dt)
		animar(dt)
	end)
	Remotes.Acechador.OnClientEvent:Connect(function(tipo: string, modelo: Model)
		local b = modelo and bichos[modelo]
		if not b then
			return
		end
		local pies = b.raiz.Position - Vector3.new(0, 7, 0)
		if tipo == "Rama" then
			local s = Sonido.en("Rama", pies + Vector3.new(azar:NextNumber(-2, 2), 0, azar:NextNumber(-2, 2)), azar:NextNumber(0.85, 1.1))
			s.RollOffMinDistance = 15
		elseif tipo == "Carga" then
			b.carga = os.clock()
			b.chillido = os.clock()
			local s = Sonido.en("Rugido", b.raiz.Position, 0.75)
			s.RollOffMinDistance = 30
			Sonido.en("Rama", pies, 0.8)
		elseif tipo == "Luz" then
			b.luz = os.clock()
			b.chillido = os.clock()
			Sonido.en("Chillido", b.raiz.Position + Vector3.new(0, 5, 0), 0.65)
		end
	end)
end

return AcechadorVista
