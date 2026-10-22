-- Mueve el cuerpo del Trepador en el cliente y hace sus ruidos (el servidor solo lo desplaza y publica atributos).
--   Anda como una araña: patas en diagonal, codos y rodillas por encima de la espalda; parado, la cabeza (del revés)
--   da tirones.
--   En la pared y en el tejado (Trepando, EnTejado): pasos pesados que se oyen desde dentro de la casa y crujidos de
--   la madera de vez en cuando, también cuando se queda quieto.
--   Remote Trepador: "Baja" (algo arrastrándose por dentro del tiro y hollín cayendo al hogar), "Entra" (sale al salón
--   entre una nube de hollín, chillando) y "Quema" (chilla con el fuego).
-- Animación sencilla a propósito: se mejora más adelante (pedido por el usuario).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sonido = require(script.Parent.Sonido)

local TrepadorVista = {}

local MOTORES = { "Torso", "Cabeza", "Mandibula", "BrazoI", "AntebrazoI", "BrazoD", "AntebrazoD", "PiernaI", "EspinillaI",
	"PiernaD", "EspinillaD" }

type Bicho = {
	modelo: Model,
	raiz: BasePart,
	motores: { [string]: Motor6D },
	antes: Vector3,
	rapidez: number,
	fase: number,
	pisada: number,
	chillido: number,
	crujido: number, -- os.clock del próximo crujido del tejado
	semilla: number,
}
local bichos: { [Model]: Bicho } = {}
local azar = Random.new()

local function preparar(modelo: Instance)
	if not modelo:IsA("Model") or modelo.Name ~= "Trepador" then
		return
	end
	local raiz = modelo:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not raiz then
		return
	end
	local motores = {}
	for _, nombre in MOTORES do
		motores[nombre] = raiz:WaitForChild(nombre, 5) :: Motor6D
	end
	bichos[modelo] = {
		modelo = modelo, raiz = raiz, motores = motores, antes = raiz.Position, rapidez = 0, fase = 0, pisada = 1,
		chillido = -math.huge, crujido = os.clock() + 2, semilla = math.random() * 100,
	}
end

-- Un sonido en 3D que se oye bien a través del techo (los pasos de arriba tienen que notarse).
local function fuerte(nombre: string, donde: Vector3, tono: number, volumen: number)
	local s = Sonido.en(nombre, donde, tono)
	s.Volume = volumen
	s.RollOffMinDistance = 22
end

local function animar(dt: number)
	local ahora = os.clock()
	local camara = workspace.CurrentCamera.CFrame.Position
	for modelo, b in bichos do
		if not modelo.Parent then
			bichos[modelo] = nil
			continue
		end
		-- La raíz va anclada en la pared y el tejado: la rapidez sale de cuánto se ha movido.
		local pos = b.raiz.Position
		local movido = (pos - b.antes).Magnitude
		b.antes = pos
		if movido > 8 then
			movido = 0 -- un salto (le han llevado de golpe a otro sitio)
		end
		b.rapidez += (movido / math.max(dt, 1 / 240) - b.rapidez) * math.min(1, dt * 8)
		if (pos - camara).Magnitude > 250 then
			continue
		end
		local m = b.motores
		local arriba = modelo:GetAttribute("Trepando") or modelo:GetAttribute("EnTejado")
		local chillando = ahora - b.chillido < 1.8
		local paso = math.min(1, b.rapidez / 5)
		b.fase += dt * b.rapidez * 0.9
		local s = math.sin(b.fase)

		-- Patas en diagonal: brazo izquierdo con pierna derecha y al revés. Se adelantan y la que avanza sube el codo.
		local function pata(arribaNombre: string, abajoNombre: string, lado: number, fase: number)
			local f = fase * paso
			local temblor = if chillando then math.sin(ahora * 45 + lado) * 0.15 else 0
			m[arribaNombre].Transform = CFrame.Angles(f * 0.55 + temblor, 0, lado * math.max(0, f) * 0.35)
			m[abajoNombre].Transform = CFrame.Angles(-f * 0.2, 0, -lado * math.max(0, f) * 0.4)
		end
		pata("BrazoI", "AntebrazoI", -1, s)
		pata("PiernaD", "EspinillaD", 1, s)
		pata("BrazoD", "AntebrazoD", 1, -s)
		pata("PiernaI", "EspinillaI", -1, -s)
		m.Torso.Transform = CFrame.new(0, math.abs(s) * 0.15 * paso, 0) * CFrame.Angles(0, 0, s * 0.06 * paso)

		-- La cabeza del revés: quieto, da tirones de lado a lado; chillando, se sacude.
		local tiron = if math.noise(ahora * 1.5, b.semilla) > 0.3 then 0.6 else 0
		local quieto = 1 - paso
		m.Cabeza.Transform = CFrame.Angles(0, quieto * tiron + (if chillando then math.sin(ahora * 30) * 0.2 else 0), math.sin(ahora * 0.8) * 0.15)
		m.Mandibula.Transform = CFrame.Angles(-(0.15 + (if chillando then 0.7 else 0) + math.max(0, math.sin(ahora * 2.3)) * 0.1), 0, 0)

		-- Pasos pesados y crujidos en la pared y el tejado; en el suelo, pasos normales.
		local lado = if s >= 0 then 1 else -1
		if b.rapidez > 1.5 and lado ~= b.pisada then
			b.pisada = lado
			if arriba then
				fuerte("Paso", pos, azar:NextNumber(0.55, 0.7), 1.6)
			else
				Sonido.en("Paso", pos - Vector3.new(0, 2, 0), 1.2)
			end
		end
		if arriba and ahora > b.crujido then
			b.crujido = ahora + azar:NextNumber(2.5, 5)
			fuerte("Crujido", pos, azar:NextNumber(0.75, 0.95), 1.6)
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

-- Una nube de hollín negro (al bajar cae al hogar; al salir, revienta hacia el salón).
local function hollin(cf: CFrame, cuanto: number, hacia: Vector3)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(2, 2, 2)
	p.CFrame = cf
	p.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.LightInfluence = 1
	e.Color = ColorSequence.new(Color3.fromRGB(18, 16, 15))
	e.Transparency = NumberSequence.new(0.2, 1)
	e.Size = NumberSequence.new(1.5, 5)
	e.Lifetime = NumberRange.new(1.5, 3)
	e.Speed = NumberRange.new(4, 12)
	e.SpreadAngle = Vector2.new(50, 50)
	e.Acceleration = hacia
	e.EmissionDirection = Enum.NormalId.Top
	e.Rate = 0
	e.Parent = p
	e:Emit(cuanto)
	task.delay(4, function()
		p:Destroy()
	end)
end

function TrepadorVista.rugir(punto: Vector3): Model?
	local b = cercano(punto, 12)
	if b then
		b.chillido = os.clock()
		return b.modelo
	end
	return nil
end

function TrepadorVista.start()
	local carpeta = workspace:WaitForChild("Bichos")
	carpeta.ChildAdded:Connect(preparar)
	for _, modelo in carpeta:GetChildren() do
		task.spawn(preparar, modelo)
	end
	RunService.Stepped:Connect(function(_, dt)
		animar(dt)
	end)
	Remotes.Trepador.OnClientEvent:Connect(function(tipo: string, modelo: Model)
		local chimenea = CollectionService:GetTagged("Chimenea")[1]
		local b = modelo and bichos[modelo]
		if not chimenea then
			return
		end
		local tiro = chimenea:GetAttribute("Tiro") :: Vector3
		local hogar = chimenea:GetAttribute("Hogar") :: CFrame
		if tipo == "Baja" then
			-- Se arrastra por dentro del tiro, de arriba abajo; cae hollín al hogar.
			fuerte("Hollin", Vector3.new(tiro.X, 24, tiro.Z), 0.8, 1.8)
			task.delay(1.8, function()
				fuerte("Hollin", Vector3.new(tiro.X, 12, tiro.Z), 0.7, 2)
				hollin(hogar * CFrame.new(0, 1.5, 0), 25, Vector3.new(0, -6, 0))
			end)
			task.delay(3.2, function()
				fuerte("Crujido", Vector3.new(tiro.X, 6, tiro.Z), 0.6, 2)
			end)
		elseif tipo == "Entra" then
			hollin(hogar * CFrame.new(0, 1.5, 0), 60, Vector3.new(6, 2, 0))
			Sonido.en("Chillido", hogar.Position, 1.25)
			Sonido.en("Rugido", hogar.Position, 1.3)
			if b then
				b.chillido = os.clock() + 1
			end
		elseif tipo == "Quema" and b then
			b.chillido = os.clock() + 0.8
			fuerte("Chillido", b.raiz.Position, 1.5, 2)
			hollin(CFrame.new(tiro), 30, Vector3.new(0, 6, 0))
		end
	end)
end

return TrepadorVista
