-- Mueve el cuerpo del Imitador en el cliente (el servidor lo desplaza y publica el atributo Abierto).
--   Anda tieso, sin mover los brazos. En la puerta, la cabeza se le va ladeando despacio, demasiado.
--   Remote Imitador "Llama": tres golpes con el puño en la puerta (en 3D). "Entra": se le estira el cuello, abre la
--   boca del todo y chilla.
-- Animación sencilla a propósito: se mejora más adelante (pedido por el usuario).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sonido = require(script.Parent.Sonido)

local ImitadorVista = {}

type Bicho = {
	modelo: Model,
	raiz: BasePart,
	motores: { [string]: Motor6D },
	fase: number,
	pisada: number,
	llamada: number, -- os.clock de la última vez que empezó a llamar
	chillido: number,
	estirado: number, -- 0..1, suave
}
local bichos: { [Model]: Bicho } = {}

local function preparar(modelo: Instance)
	if not modelo:IsA("Model") or modelo.Name ~= "Imitador" then
		return
	end
	local raiz = modelo:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not raiz then
		return
	end
	local motores = {}
	for _, nombre in { "Torso", "Cuello", "Cabeza", "Mandibula", "BrazoI", "BrazoD", "PiernaI", "PiernaD" } do
		motores[nombre] = raiz:WaitForChild(nombre, 5) :: Motor6D
	end
	bichos[modelo] = { modelo = modelo, raiz = raiz, motores = motores, fase = 0, pisada = 1, llamada = -math.huge,
		chillido = -math.huge, estirado = 0 }
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
		local m = b.motores
		local v = b.raiz.AssemblyLinearVelocity
		local rapidez = Vector3.new(v.X, 0, v.Z).Magnitude
		local paso = math.min(1, rapidez / 8)
		b.fase += dt * rapidez * 0.45
		local s = math.sin(b.fase)
		m.PiernaI.Transform = CFrame.Angles(s * 0.6 * paso, 0, 0)
		m.PiernaD.Transform = CFrame.Angles(-s * 0.6 * paso, 0, 0)

		local abierto = modelo:GetAttribute("Abierto") == true
		b.estirado += ((if abierto then 1 else 0) - b.estirado) * math.min(1, dt * 3)
		local chillando = ahora - b.chillido < 2

		-- Brazo derecho: tres golpes en la puerta, el puño a la altura de la cara.
		local t = ahora - b.llamada
		local golpe = 0
		if t < 1.6 then
			local subida = math.min(1, t / 0.25, (1.6 - t) / 0.25)
			golpe = subida * (1.5 + 0.25 * math.max(0, math.sin(t * math.pi * 2 / 0.4)))
		end
		m.BrazoD.Transform = CFrame.Angles(golpe + b.estirado * 0.6, 0, 0)
		m.BrazoI.Transform = CFrame.Angles(b.estirado * 0.6, 0, 0)

		-- Quieto, la cabeza se le va ladeando; abierto, el cuello se estira y la boca se abre del todo.
		local ladeo = (1 - paso) * (0.35 + 0.15 * math.sin(ahora * 0.3))
		m.Cuello.Transform = CFrame.new(0, b.estirado * 2.2, 0) * CFrame.Angles(0, 0, ladeo * 0.4)
		m.Cabeza.Transform = CFrame.Angles(b.estirado * -0.3, 0, ladeo + (if chillando then math.sin(ahora * 35) * 0.12 else 0))
		m.Mandibula.Transform = CFrame.Angles(-(b.estirado * 0.9 + (if chillando then 0.3 else 0)), 0, 0)
		m.Torso.Transform = CFrame.Angles(b.estirado * -0.15, 0, 0)

		local lado = if s >= 0 then 1 else -1
		if rapidez > 2 and lado ~= b.pisada then
			b.pisada = lado
			Sonido.en("Paso", b.raiz.Position - Vector3.new(0, 4, 0), 1.1)
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

function ImitadorVista.rugir(punto: Vector3): Model?
	local b = cercano(punto, 12)
	if b then
		b.chillido = os.clock()
		return b.modelo
	end
	return nil
end

function ImitadorVista.start()
	local carpeta = workspace:WaitForChild("Bichos")
	carpeta.ChildAdded:Connect(preparar)
	for _, modelo in carpeta:GetChildren() do
		task.spawn(preparar, modelo)
	end
	RunService.Stepped:Connect(function(_, dt)
		animar(dt)
	end)
	Remotes.Imitador.OnClientEvent:Connect(function(tipo: string, modelo: Model)
		local b = modelo and bichos[modelo]
		if not b then
			return
		end
		local delante = b.raiz.Position + b.raiz.CFrame.LookVector * 1.5 + Vector3.new(0, 1, 0)
		if tipo == "Llama" then
			b.llamada = os.clock()
			local s = Sonido.en("Llamar", delante, 1)
			s.RollOffMinDistance = 20
		elseif tipo == "Entra" then
			b.chillido = os.clock() + 0.4
			Sonido.en("Chillido", delante, 0.8)
			Sonido.en("Rugido", delante, 0.9)
		end
	end)
end

return ImitadorVista
