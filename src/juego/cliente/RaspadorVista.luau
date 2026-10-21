-- Mueve el cuerpo del Raspador en el cliente (el servidor solo lo desplaza y publica atributos en el modelo).
--   Andando: piernas largas, brazos colgando que se balancean, la cabeza dando tirones.
--   Raspando: los dos brazos en alto contra el cristal, bajando despacio uno y otro, la cara pegada; el chirrido en
--   bucle sube y baja con cada pasada.
--   Con la linterna encima: se encoge hacia atrás, aparta la cara y tiembla.
--   Flash (remote Raspador "Chilla"): chilla con la boca abierta del todo, se tapa la cara y se va corriendo.
-- Animación sencilla a propósito: se mejora más adelante (pedido por el usuario).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sonido = require(script.Parent.Sonido)

local RaspadorVista = {}

type Bicho = {
	modelo: Model,
	raiz: BasePart,
	motores: { [string]: Motor6D },
	fase: number,
	pisada: number,
	chillido: number,
	encogido: number, -- 0..1, suave
	raspar: number, -- 0..1, suave
	bucle: Sound?,
	semilla: number, -- para que cada uno dé sus tirones a destiempo
}
local bichos: { [Model]: Bicho } = {}

local function preparar(modelo: Instance)
	if not modelo:IsA("Model") or modelo.Name ~= "Raspador" then
		return
	end
	local raiz = modelo:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not raiz then
		return
	end
	local motores = {}
	for _, nombre in { "Torso", "Cuello", "Cabeza", "Mandibula", "BrazoI", "BrazoD", "AntebrazoI", "AntebrazoD", "PiernaI", "PiernaD" } do
		motores[nombre] = raiz:WaitForChild(nombre, 5) :: Motor6D
	end
	bichos[modelo] = {
		modelo = modelo, raiz = raiz, motores = motores, fase = 0, pisada = 1,
		chillido = -math.huge, encogido = 0, raspar = 0, bucle = nil, semilla = math.random() * 100,
	}
end

local function quitar(b: Bicho)
	if b.bucle then
		b.bucle:Destroy()
	end
	bichos[b.modelo] = nil
end

local function acercar(actual: number, meta: number, dt: number, rapidez: number): number
	return actual + (meta - actual) * math.min(1, dt * rapidez)
end

local function animar(dt: number)
	local ahora = os.clock()
	local camara = workspace.CurrentCamera.CFrame.Position
	for modelo, b in bichos do
		if not modelo.Parent then
			quitar(b)
			continue
		end
		if (b.raiz.Position - camara).Magnitude > 250 then
			continue
		end
		local m = b.motores
		local raspando = modelo:GetAttribute("Raspando") == true
		local luz = modelo:GetAttribute("Iluminado") == true and raspando
		local chillando = ahora - b.chillido < 1.6
		b.raspar = acercar(b.raspar, if raspando then 1 else 0, dt, 3)
		b.encogido = acercar(b.encogido, if luz or chillando then 1 else 0, dt, if luz or chillando then 10 else 2)

		local v = b.raiz.AssemblyLinearVelocity
		local rapidez = Vector3.new(v.X, 0, v.Z).Magnitude
		local paso = math.min(1, rapidez / 6)
		b.fase += dt * rapidez * 0.5
		local s = math.sin(b.fase)
		m.PiernaI.Transform = CFrame.Angles(s * 0.7 * paso, 0, 0)
		m.PiernaD.Transform = CFrame.Angles(-s * 0.7 * paso, 0, 0)

		-- Brazos: colgando y balanceándose al andar; en alto contra el cristal al raspar (bajan despacio, uno y otro).
		local pasada = (ahora * 0.45) % 1
		local bajaI = 0.5 * pasada
		local bajaD = 0.5 * ((pasada + 0.5) % 1)
		local temblor = b.encogido * math.sin(ahora * 40) * 0.05
		-- Cada brazo: {hombro, codo}. Andando cuelgan con el codo un poco doblado; raspando, el codo arriba y la mano
		-- bajando por el cristal; encogido, los antebrazos delante de la cara.
		local function brazo(baja: number, balanceo: number): (number, number)
			local hombro = (1 - b.raspar) * balanceo + b.raspar * (2.7 - baja * 0.8)
			local codo = (1 - b.raspar) * 0.25 + b.raspar * (-2.4 + baja * 0.8)
			return hombro * (1 - b.encogido) + 1.3 * b.encogido, codo * (1 - b.encogido) + 1.9 * b.encogido
		end
		local hombroI, codoI = brazo(bajaI, -s * 0.4 * paso + math.sin(ahora * 1.1) * 0.05)
		local hombroD, codoD = brazo(bajaD, s * 0.4 * paso - math.sin(ahora * 1.1) * 0.05)
		m.BrazoI.Transform = CFrame.Angles(hombroI + temblor, 0, -0.08)
		m.BrazoD.Transform = CFrame.Angles(hombroD - temblor, 0, 0.08)
		m.AntebrazoI.Transform = CFrame.Angles(codoI, 0, 0)
		m.AntebrazoD.Transform = CFrame.Angles(codoD, 0, 0)

		-- Cuerpo y cabeza: echado hacia el cristal al raspar, hacia atrás si le alumbran.
		m.Torso.Transform = CFrame.Angles(-b.raspar * 0.15 + b.encogido * 0.45 + math.sin(ahora * 1.7) * 0.03, 0, 0)
		local tiron = if math.noise(ahora * 2, b.semilla) > 0.35 then 0.25 else 0
		m.Cuello.Transform = CFrame.Angles(-b.raspar * 0.35, 0, 0)
		m.Cabeza.Transform = CFrame.Angles(b.raspar * 0.3, b.encogido * 0.9 + temblor * 4, 0.3 * math.sin(ahora * 0.6) + tiron)
		local abre = 0.15 + b.raspar * 0.1 * math.sin(ahora * 2) + b.encogido * 0.35 + (if chillando then 0.6 + 0.12 * math.sin(ahora * 35) else 0)
		m.Mandibula.Transform = CFrame.Angles(-abre, 0, 0)

		-- El chirrido en bucle mientras raspa, más fuerte a mitad de cada pasada; con luz casi para.
		if raspando and not b.bucle then
			local cabeza = modelo:FindFirstChild("Cabeza")
			if cabeza then
				b.bucle = Sonido.bucle("Raspado", cabeza)
				local s3 = b.bucle :: Sound
				s3.RollOffMode = Enum.RollOffMode.InverseTapered
				s3.RollOffMinDistance = 8
				s3.RollOffMaxDistance = 70
			end
		elseif not raspando and b.bucle then
			b.bucle:Destroy()
			b.bucle = nil
		end
		if b.bucle then
			b.bucle.Volume = 1.2 * math.sin(pasada * math.pi) * (if luz then 0.25 else 1)
			b.bucle.PlaybackSpeed = if luz then 0.7 else 0.9
		end

		local lado = if s >= 0 then 1 else -1
		if rapidez > 2 and lado ~= b.pisada then
			b.pisada = lado
			Sonido.en("Paso", b.raiz.Position - Vector3.new(0, 4, 0), 1.35)
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

-- Abre la boca del todo (el susto al morir). Devuelve el Raspador que tenga la cabeza cerca de `punto`, si hay.
function RaspadorVista.rugir(punto: Vector3): Model?
	local b = cercano(punto, 12)
	if b then
		b.chillido = os.clock()
		return b.modelo
	end
	return nil
end

function RaspadorVista.start()
	local carpeta = workspace:WaitForChild("Bichos")
	carpeta.ChildAdded:Connect(preparar)
	for _, modelo in carpeta:GetChildren() do
		task.spawn(preparar, modelo)
	end
	RunService.Stepped:Connect(function(_, dt)
		animar(dt)
	end)
	Remotes.Raspador.OnClientEvent:Connect(function(tipo: string, cosa: Instance)
		if tipo == "Chilla" and cosa and bichos[cosa :: Model] then
			local b = bichos[cosa :: Model]
			b.chillido = os.clock()
			Sonido.en("Chillido", b.raiz.Position + Vector3.new(0, 3, 0))
		elseif tipo == "Entra" and cosa then
			local centro = cosa:GetAttribute("Centro")
			if typeof(centro) == "CFrame" then
				Sonido.en("Chillido", centro.Position, 0.6) -- grave: ruge al entrar
				local b = cercano(centro.Position, 15)
				if b then
					b.chillido = os.clock() + 0.6
				end
			end
		end
	end)
end

return RaspadorVista
