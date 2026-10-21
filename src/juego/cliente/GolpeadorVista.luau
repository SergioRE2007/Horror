-- Mueve el cuerpo del Golpeador en el cliente (el servidor solo lo desplaza): piernas y brazos que se balancean al
-- andar, la cabeza ladeada, el golpe con los dos brazos (remote Golpeador "Golpe") y el rugido al entrar.
-- Pasos pesados que se oyen al andar. Animación sencilla a propósito: se mejora más adelante (pedido por el usuario).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sonido = require(script.Parent.Sonido)

local GolpeadorVista = {}

type Bicho = { modelo: Model, raiz: BasePart, motores: { [string]: Motor6D }, fase: number, golpe: number, pisada: number }
local bichos: { [Model]: Bicho } = {}

local function preparar(modelo: Instance)
	if not modelo:IsA("Model") then
		return
	end
	local raiz = modelo:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not raiz then
		return
	end
	local motores = {}
	for _, nombre in { "PiernaI", "PiernaD", "BrazoI", "BrazoD", "Cabeza" } do
		motores[nombre] = raiz:WaitForChild(nombre, 5) :: Motor6D
	end
	bichos[modelo] = { modelo = modelo, raiz = raiz, motores = motores, fase = 0, golpe = -math.huge, pisada = 1 }
end

-- Ángulo de los brazos durante el golpe: arriba, abajo de golpe contra la ventana y vuelta.
local function brazosGolpe(t: number): number
	if t < 0.35 then
		return 2.6 * (t / 0.35)
	elseif t < 0.45 then
		return 2.6 - 1.4 * ((t - 0.35) / 0.1)
	elseif t < 0.9 then
		return 1.2 * (1 - (t - 0.45) / 0.45)
	end
	return 0
end

local function animar(dt: number)
	local ahora = os.clock()
	local camara = workspace.CurrentCamera.CFrame.Position
	for modelo, b in bichos do
		if not modelo.Parent then
			bichos[modelo] = nil
			continue
		end
		if (b.raiz.Position - camara).Magnitude > 250 then
			continue
		end
		local v = b.raiz.AssemblyLinearVelocity
		local rapidez = Vector3.new(v.X, 0, v.Z).Magnitude
		local paso = math.min(1, rapidez / 9)
		b.fase += dt * rapidez * 0.42
		local s = math.sin(b.fase)
		local m = b.motores
		m.PiernaI.Transform = CFrame.Angles(s * 0.6 * paso, 0, 0)
		m.PiernaD.Transform = CFrame.Angles(-s * 0.6 * paso, 0, 0)
		local golpe = brazosGolpe(ahora - b.golpe)
		local vaiven = math.sin(ahora * 1.3) * 0.06
		m.BrazoI.Transform = CFrame.Angles(golpe - s * 0.35 * paso + vaiven, 0, -0.1)
		m.BrazoD.Transform = CFrame.Angles(golpe + s * 0.35 * paso - vaiven, 0, 0.1)
		m.Cabeza.Transform = CFrame.Angles(0.15 * math.sin(ahora * 0.5), 0, 0.35 + 0.12 * math.sin(ahora * 0.7))
		-- Una pisada cada vez que el seno cambia de signo.
		local lado = if s >= 0 then 1 else -1
		if rapidez > 2 and lado ~= b.pisada then
			b.pisada = lado
			Sonido.en("Paso", b.raiz.Position - Vector3.new(0, 5, 0), 0.55)
		end
	end
end

local function cercano(punto: Vector3): Bicho?
	local mejor, distancia = nil, math.huge
	for _, b in bichos do
		local d = (b.raiz.Position - punto).Magnitude
		if d < distancia then
			mejor, distancia = b, d
		end
	end
	return mejor
end

function GolpeadorVista.start()
	local carpeta = workspace:WaitForChild("Bichos")
	carpeta.ChildAdded:Connect(preparar)
	for _, modelo in carpeta:GetChildren() do
		task.spawn(preparar, modelo)
	end
	RunService.Stepped:Connect(function(_, dt)
		animar(dt)
	end)
	Remotes.Golpeador.OnClientEvent:Connect(function(tipo: string, el: Model)
		local centro = el and el:GetAttribute("Centro")
		if typeof(centro) ~= "CFrame" then
			return
		end
		local b = cercano(centro.Position)
		if tipo == "Golpe" and b then
			b.golpe = os.clock()
		elseif tipo == "Entra" then
			Sonido.en("Rugido", centro.Position)
		end
	end)
end

return GolpeadorVista
