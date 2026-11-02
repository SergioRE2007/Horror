-- Mueve el cuerpo de la Bestia en el cliente y hace sus ruidos (el servidor la mueve y avisa con el remote Bestia).
--   Anda a cuatro patas, pesada: cada pisada suena grave y, cerca, tiembla la cámara. La cabeza da tirones bruscos de
--   un lado a otro. Herida (atributo "Cojea", hora del servidor): arrastra la pata de atrás derecha, el cuerpo se le
--   vence a ese lado y le sale humo de la quemadura.
--   "Ruge": se levanta sobre las patas de atrás con la boca abierta. "Golpe": se alza y descarga los brazos (contra la
--   puerta o la reja). "Herida": se encoge, chilla y ruge. "Atrapada": ruge de rabia. "Flash": aparta la cara.
--   "Quema": arde entera, se retuerce y chilla largo hasta que el servidor la quita.
-- BestiaVista.rugir(punto): para el susto al morir (como los demás bichos). Animación sencilla a propósito.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sonido = require(script.Parent.Sonido)

local BestiaVista = {}

local ALTURA = Config.Bestia.Altura -- de los pies al centro de la raíz

type Bicho = {
	modelo: Model,
	raiz: BasePart,
	motores: { [string]: Motor6D },
	fase: number,
	pisada: number,
	rugido: number, -- os.clock de cada cosa que le pasa
	golpe: number,
	herida: number,
	flash: number,
	quema: number,
	giro: Vector3, -- la cabeza ahora (cabeceo, giro, ladeo) y a dónde da el próximo tirón
	meta: Vector3,
	tiron: number,
	humo: Smoke?,
}
local bichos: { [Model]: Bicho } = {}
local azar = Random.new()
local temblor = 0 -- fuerza del temblor de la cámara (baja sola)

local function preparar(modelo: Instance)
	if not modelo:IsA("Model") or modelo.Name ~= "Bestia" then
		return
	end
	local raiz = modelo:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not raiz then
		return
	end
	local motores = {}
	for _, nombre in { "Lomo", "Cabeza", "Mandibula", "BrazoI", "BrazoD", "PiernaI", "PiernaD" } do
		local motor = raiz:WaitForChild(nombre, 5) :: Motor6D?
		if not motor then
			return
		end
		motores[nombre] = motor
	end
	bichos[modelo] = { modelo = modelo, raiz = raiz, motores = motores, fase = 0, pisada = 1, rugido = -math.huge,
		golpe = -math.huge, herida = -math.huge, flash = -math.huge, quema = -math.huge, giro = Vector3.zero,
		meta = Vector3.zero, tiron = 0, humo = nil }
end

local function temblar(desde: Vector3, fuerza: number, alcance: number)
	local d = (workspace.CurrentCamera.CFrame.Position - desde).Magnitude
	if d < alcance then
		temblor = math.max(temblor, fuerza * (1 - d / alcance))
	end
end

-- Se alza (0..0,3 s), descarga los brazos de golpe (0,3..0,42) y vuelve. Devuelve (brazos, torso).
local function curvaGolpe(t: number): (number, number)
	if t < 0.3 then
		local k = t / 0.3
		return 2.2 * k, 0.4 * k
	elseif t < 0.42 then
		local k = (t - 0.3) / 0.12
		return 2.2 - 1.8 * k, 0.4 - 0.55 * k
	elseif t < 1 then
		local k = 1 - (t - 0.42) / 0.58
		return 0.4 * k, -0.15 * k
	end
	return 0, 0
end

local function prender(pieza: BasePart, tamano: number)
	local fuego = Instance.new("Fire")
	fuego.Size = tamano
	fuego.Heat = 12
	fuego.Color = Color3.fromRGB(236, 120, 40)
	fuego.SecondaryColor = Color3.fromRGB(120, 30, 10)
	fuego.Parent = pieza
	local humo = Instance.new("Smoke")
	humo.Color = Color3.fromRGB(30, 28, 26)
	humo.Opacity = 0.35
	humo.RiseVelocity = 6
	humo.Size = tamano * 0.6
	humo.Parent = pieza
end

local function animar(dt: number)
	local ahora = os.clock()
	local servidor = workspace:GetServerTimeNow()
	local camara = workspace.CurrentCamera.CFrame.Position
	for modelo, b in bichos do
		if not modelo.Parent then
			bichos[modelo] = nil
			continue
		end
		local m = b.motores
		local cojea = (modelo:GetAttribute("Cojea") or 0) > servidor
		-- La quemadura humea mientras cojea.
		if cojea and not b.humo then
			local humo = Instance.new("Smoke")
			humo.Color = Color3.fromRGB(45, 42, 40)
			humo.Opacity = 0.25
			humo.RiseVelocity = 4
			humo.Size = 1.5
			humo.Parent = m.PiernaD.Part1
			b.humo = humo
		elseif not cojea and b.humo then
			b.humo.Enabled = false
			Debris:AddItem(b.humo, 3)
			b.humo = nil
		end
		if (b.raiz.Position - camara).Magnitude > 250 then
			continue
		end
		local v = b.raiz.AssemblyLinearVelocity
		local rapidez = Vector3.new(v.X, 0, v.Z).Magnitude
		local paso = math.min(1, rapidez / 12)
		b.fase += dt * rapidez * 0.3
		local s = math.sin(b.fase)

		local rugiendo = ahora - b.rugido < 2.5
		local quemando = ahora - b.quema < 30
		local brazosG, torsoG = curvaGolpe(ahora - b.golpe)
		local encoge = math.max(0, 1 - (ahora - b.herida) / 0.9)

		-- Patas: en diagonal (brazo izquierdo con pierna derecha). Herida, la de atrás derecha va tiesa y arrastrada.
		m.PiernaI.Transform = CFrame.Angles(s * 0.5 * paso, 0, 0)
		m.PiernaD.Transform = if cojea then CFrame.Angles(0.35 - s * 0.12 * paso, 0, 0.12) else CFrame.Angles(-s * 0.5 * paso, 0, 0)
		local brazo = -s * 0.55 * paso + brazosG + (if rugiendo then 0.9 else 0) + encoge * 0.8
		local otro = s * 0.55 * paso + brazosG + (if rugiendo then 0.9 else 0) + encoge * 0.8
		if quemando then -- se agita con los brazos
			brazo += math.sin(ahora * 11) * 0.9
			otro += math.sin(ahora * 9 + 1) * 0.9
		end
		m.BrazoI.Transform = CFrame.Angles(brazo, 0, 0)
		m.BrazoD.Transform = CFrame.Angles(otro, 0, 0)

		-- Cuerpo: cabecea pesado a cada paso y respira; herida, se le vence hacia el lado de la pata mala.
		local respira = math.sin(ahora * 1.6) * 0.03
		local cabeceo = math.abs(s) * 0.06 * paso
		local vence = if cojea then math.max(0, -s) * 0.18 * paso + 0.05 else 0
		local alza = (if rugiendo then 0.45 else 0) + torsoG
		local ladeo = s * 0.05 * paso - vence - encoge * 0.2
		if quemando then
			local t = ahora - b.quema
			alza += 0.5 * math.max(0, 1 - t / 2) - 0.25 * math.clamp((t - 2) / 2, 0, 1) -- se alza y luego se derrumba
			ladeo += math.sin(ahora * 7) * 0.22
		end
		m.Lomo.Transform = CFrame.Angles(alza + cabeceo + respira, 0, ladeo)

		-- Cabeza: tirones bruscos a una posición nueva cada poco (más seguidos si está alterada).
		if ahora > b.tiron then
			local alterada = rugiendo or quemando or (modelo:GetAttribute("Atrapada") == true)
			b.tiron = ahora + (if alterada then azar:NextNumber(0.2, 0.7) else azar:NextNumber(0.6, 2.2))
			b.meta = Vector3.new(azar:NextNumber(-0.25, 0.2), azar:NextNumber(-0.6, 0.6), azar:NextNumber(-0.7, 0.7))
		end
		b.giro = b.giro:Lerp(b.meta, math.min(1, dt * 18))
		local aparta = if ahora - b.flash < 0.7 then 1.1 else 0
		local giro = b.giro + Vector3.new(if rugiendo then 0.35 else 0, aparta + encoge * 0.9, 0)
		m.Cabeza.Transform = CFrame.Angles(giro.X, giro.Y, giro.Z)
		local abre = 0.2 + 0.06 * math.sin(ahora * 2.5) + brazosG * 0.2 + encoge * 0.6
			+ (if rugiendo or quemando then 0.75 + 0.1 * math.sin(ahora * 30) else 0)
		m.Mandibula.Transform = CFrame.Angles(-abre, 0, 0)

		-- Pisadas: graves y pesadas; cerca, tiembla el suelo.
		local lado = if s >= 0 then 1 else -1
		if rapidez > 2 and lado ~= b.pisada then
			b.pisada = lado
			local pies = b.raiz.Position - Vector3.new(0, ALTURA, 0)
			local blanda = cojea and lado < 0
			local sonido = Sonido.en("Paso", pies, azar:NextNumber(0.4, 0.46))
			sonido.Volume *= if blanda then 0.8 else 1.4
			sonido.RollOffMinDistance = 15
			temblar(pies, if blanda then 0.04 else 0.08, 30)
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

-- Abre la boca del todo unos segundos (el susto al morir). Devuelve la Bestia con la cabeza cerca de `punto`, si hay.
function BestiaVista.rugir(punto: Vector3): Model?
	local b = cercano(punto, 14)
	if b then
		b.rugido = os.clock()
		return b.modelo
	end
	return nil
end

local function cabezaDe(b: Bicho): Vector3
	local c = b.modelo:FindFirstChild("Cabeza") :: BasePart?
	return if c then c.Position else b.raiz.Position
end

local function rugido(b: Bicho, tono: number, lejos: number)
	local s = Sonido.en("Rugido", cabezaDe(b), tono)
	s.RollOffMinDistance = lejos
end

local function mensaje(tipo: string, b: Bicho)
	local ahora = os.clock()
	if tipo == "Ruge" then
		b.rugido = ahora
		rugido(b, 0.6, 45)
		task.delay(0.15, rugido, b, 0.48, 45) -- dos capas: más grave y más grande que los demás
		temblar(b.raiz.Position, 0.12, 40)
	elseif tipo == "Golpe" then
		b.golpe = ahora
		task.delay(0.36, function() -- el golpe suena cuando bajan los brazos
			if b.modelo.Parent then
				local delante = b.raiz.Position + b.raiz.CFrame.LookVector * 5
				Sonido.en("Golpe", delante, azar:NextNumber(0.7, 0.8))
				temblar(delante, 0.25, 35)
			end
		end)
	elseif tipo == "Herida" then
		b.herida = ahora
		Sonido.en("Chillido", cabezaDe(b), 0.7)
		task.delay(0.4, rugido, b, 0.75, 30)
	elseif tipo == "Atrapada" then
		b.rugido = ahora
		rugido(b, 0.52, 40)
		temblar(b.raiz.Position, 0.15, 40)
	elseif tipo == "Flash" then
		b.flash = ahora
	elseif tipo == "Quema" then
		b.quema = ahora
		b.rugido = ahora
		for _, nombre in { "Lomo", "Cabeza", "BrazoI", "BrazoD", "PiernaI", "PiernaD" } do
			local pieza = b.motores[nombre].Part1
			if pieza then
				prender(pieza, if nombre == "Lomo" then 8 else 4)
			end
		end
		local luz = Instance.new("PointLight")
		luz.Color = Color3.fromRGB(255, 140, 60)
		luz.Brightness = 1
		luz.Range = 16
		luz.Parent = b.motores.Lomo.Part1
		-- Chillido largo: varias capas, cada una más grave.
		for i, tono in { 0.62, 0.55, 0.48 } do
			task.delay((i - 1) * 1.3, function()
				if b.modelo.Parent then
					local s = Sonido.en("Chillido", cabezaDe(b), tono)
					s.RollOffMinDistance = 40
				end
			end)
		end
		task.delay(0.2, rugido, b, 0.45, 45)
	end
end

function BestiaVista.start()
	local carpeta = workspace:WaitForChild("Bichos")
	carpeta.ChildAdded:Connect(preparar)
	for _, modelo in carpeta:GetChildren() do
		task.spawn(preparar, modelo)
	end
	RunService.Stepped:Connect(function(_, dt)
		animar(dt)
	end)
	-- Temblor de la cámara (pisadas, golpes, rugidos): después de la cámara normal, y baja solo.
	RunService:BindToRenderStep("BestiaTemblor", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if temblor < 0.002 then
			return
		end
		local t = os.clock() * 40
		local camara = workspace.CurrentCamera
		camara.CFrame *= CFrame.Angles(math.noise(t, 1) * temblor * 0.25, math.noise(t, 2) * temblor * 0.25, math.noise(t, 3) * temblor * 0.15)
		temblor = math.max(0, temblor - dt * 0.8)
	end)
	Remotes.Bestia.OnClientEvent:Connect(function(tipo: string, modelo: Model?)
		if typeof(modelo) ~= "Instance" then
			return
		end
		-- Recién creada puede no estar preparada aún (el rugido al salir del bosque llega a la vez).
		task.spawn(function()
			local b = bichos[modelo]
			for _ = 1, 20 do
				if b then
					break
				end
				task.wait(0.1)
				b = bichos[modelo]
			end
			if b then
				mensaje(tipo, b)
			end
		end)
	end)
end

return BestiaVista
