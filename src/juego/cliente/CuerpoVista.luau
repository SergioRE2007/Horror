-- Que la cámara se sienta un cuerpo (pedido por el usuario: "que todo esté animado y sea inmersivo"). Solo en primera
-- persona, con la cámara normal (nunca en cinemáticas, escondido, muerto ni con la mochila abierta):
--   Al andar, la cabeza sube y baja con cada paso (la misma zancada que los sonidos de Pasos) y se mece un poco de lado;
--   corriendo deprisa, más. Quieto, respira.
--   Al moverte de lado, se inclina un poco hacia ese lado.
--   Al caer de una altura, la cabeza baja de golpe y vuelve.
--   Con un bicho cerca, respira más rápido y más hondo (el miedo).
--   De noche y fuera de la casa, se ve el vaho al respirar (sin él con Rendimiento).
--   Manda al servidor cuánto miras arriba o abajo (remote Mirada) para que los demás lo vean (BrazosVista).
-- Con lo pesado en las manos el balanceo lo pone CargarVista: aquí no se suma.
-- Se pinta encima de la cámara de Roblox (BindToRenderStep, Camera + 1): solo mueve la posición y la inclina de lado,
-- que la cámara rehace cada fotograma (no se acumula).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local CuerpoVista = {}

local jugador = Players.LocalPlayer
local camara = workspace.CurrentCamera
local ZANCADA = 7 -- studs entre paso y paso (como Pasos)
local SUBE = 0.07 -- studs que sube y baja la cabeza al andar a 16
local LADO = 0.045
local MECE = math.rad(0.5) -- inclinación al andar
local INCLINA = math.rad(1.4) -- de lado, al moverte a 16 hacia un lado
local CAIDA = 0.45 -- studs que baja la cabeza al caer de alto
local MIEDO = 30 -- studs: con un bicho más cerca, respira con miedo

local fase = 0
local fuerza = 0 -- cuánto se nota el andar (sube y baja suave al empezar y al parar)
local inclinado = 0
local caida = 0 -- lo que ha bajado la cabeza al caer (vuelve sola)
local velCaida = 0
local respiracion = 0
local miedo = 0
local bichoCerca = 0 -- se mira cada poco
local proximoVaho = 0
local proximaMirada = 0
local vaho: ParticleEmitter? = nil
local boca: Attachment? = nil

-- Dentro de la casa (como Ambiente: la caja de la casa y por debajo del tejado).
local function enCasa(p: Vector3): boolean
	local c = Config.Casa
	return math.abs(p.X) < c.MedioX and math.abs(p.Z) < c.MedioZ and p.Y < 28
end

-- El vaho: una nubecilla que sale de la boca y se deshace (las partículas se quedan donde salen).
local function echarVaho(cf: CFrame)
	if not vaho then
		local a = Instance.new("Attachment")
		a.Name = "Vaho"
		a.Parent = workspace.Terrain
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.LightInfluence = 1 -- de noche, apenas: solo se ve con la linterna
		e.Color = ColorSequence.new(Color3.fromRGB(215, 220, 228))
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.82), NumberSequenceKeypoint.new(1, 1) })
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0.7) })
		e.Lifetime = NumberRange.new(1, 1.6)
		e.Speed = NumberRange.new(0.8, 1.4)
		e.SpreadAngle = Vector2.new(18, 18)
		e.Acceleration = Vector3.new(0, 0.6, 0)
		e.Drag = 1.5
		e.Rate = 0
		e.Parent = a
		boca, vaho = a, e
	end
	(boca :: Attachment).WorldCFrame = cf * CFrame.new(0, -0.35, -0.6)
	;(vaho :: ParticleEmitter):Emit(5)
end

local function enJuego(): boolean
	if camara.CameraType ~= Enum.CameraType.Custom then
		return false
	end
	if jugador:GetAttribute("Muerto") or jugador:GetAttribute("Escondido") or jugador:GetAttribute("MochilaAbierta") then
		return false
	end
	local cabeza = jugador.Character and jugador.Character:FindFirstChild("Head") :: BasePart?
	return cabeza ~= nil and (camara.CFrame.Position - cabeza.Position).Magnitude < 2.5
end

local function distanciaBicho(desde: Vector3): number
	local carpeta = workspace:FindFirstChild("Bichos")
	local mejor = math.huge
	for _, bicho in (if carpeta then carpeta:GetChildren() else {}) do
		local raiz = bicho:FindFirstChild("HumanoidRootPart")
		if raiz and raiz:IsA("BasePart") then
			mejor = math.min(mejor, (raiz.Position - desde).Magnitude)
		end
	end
	return mejor
end

local function paso(dt: number)
	local personaje = jugador.Character
	local hum = personaje and personaje:FindFirstChildOfClass("Humanoid")
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not raiz or not enJuego() then
		fuerza, inclinado, caida, velCaida = 0, 0, 0, 0
		return
	end
	local cf = camara.CFrame
	local v = raiz.AssemblyLinearVelocity
	local plano = Vector3.new(v.X, 0, v.Z)
	local rapidez = plano.Magnitude
	local enSuelo = hum.FloorMaterial ~= Enum.Material.Air
	local cargando = jugador:GetAttribute("Cargando") ~= nil

	-- Andar: una bajada por paso.
	local andando = enSuelo and rapidez > 1 and not cargando
	fuerza += ((if andando then math.clamp(rapidez / 16, 0, 1.4) else 0) - fuerza) * (1 - math.exp(-dt * 6))
	if andando then
		fase += rapidez * dt / ZANCADA * math.pi
	end
	local sube = -math.abs(math.sin(fase)) * SUBE * fuerza * 2 + SUBE * fuerza
	local lado = math.sin(fase) * LADO * fuerza
	local mece = math.sin(fase) * MECE * fuerza

	-- De lado: se inclina hacia donde va.
	local deLado = plano:Dot(cf.RightVector)
	inclinado += (-deLado / 16 * INCLINA - inclinado) * (1 - math.exp(-dt * 5))

	-- Caer: la cabeza baja de golpe y vuelve con un muelle. A pasitos de 1/60 s como mucho: con fotogramas largos (un
	-- móvil lento, un tirón al aterrizar) el muelle se disparaba y la cámara salía volando.
	local pasos = math.clamp(math.ceil(dt * 60), 1, 15)
	local h = math.min(dt, 0.25) / pasos
	for _ = 1, pasos do
		velCaida += (-caida * 120 - velCaida * 16) * h
		caida += velCaida * h
	end
	if caida ~= caida or velCaida ~= velCaida then
		caida, velCaida = 0, 0 -- por si acaso (NaN): que no se rompa la cámara
	end

	-- Respirar, con miedo si hay un bicho cerca.
	bichoCerca -= dt
	if bichoCerca <= 0 then
		bichoCerca = 0.4
		local d = distanciaBicho(raiz.Position)
		miedo = math.clamp(1 - (d - 8) / (MIEDO - 8), 0, 1)
	end
	respiracion += dt * (1.3 + miedo * 2.2)
	local respira = math.sin(respiracion) * (0.012 + miedo * 0.03)

	camara.CFrame = cf * CFrame.new(lado, sube + respira + caida, 0) * CFrame.Angles(0, 0, mece + inclinado)

	-- Hacia dónde miras, para que los demás vean tu cabeza y tu linterna (BrazosVista), cada 0,2 s si ha cambiado.
	-- Se compara con lo que ha publicado el servidor (atributo Mirada, entre -1,4 y 1,4 y redondeado a 0,05), no con lo
	-- último mandado: si tiró un envío (dos llegaron muy seguidos), se vuelve a mandar hasta que se publique y la de
	-- antes no se queda atascada.
	if os.clock() >= proximaMirada then
		proximaMirada = os.clock() + 0.2
		local inclinacion = math.asin(math.clamp(cf.LookVector.Y, -1, 1))
		local publicada = jugador:GetAttribute("Mirada")
		local dicha = if type(publicada) == "number" then publicada else 0
		if math.abs(math.clamp(inclinacion, -1.4, 1.4) - dicha) >= 0.05 then
			Remotes.Mirada:FireServer(inclinacion)
		end
	end

	-- Vaho de noche fuera de casa, al soltar el aire (más seguido con miedo).
	local ahora = os.clock()
	if ahora >= proximoVaho then
		proximoVaho = ahora + 3.2 - miedo * 1.6
		if workspace:GetAttribute("Fase") == "Noche" and not enCasa(cf.Position)
			and jugador:GetAttribute("Rendimiento") ~= true then
			echarVaho(camara.CFrame)
		end
	end
end

function CuerpoVista.start()
	local function conPersonaje(personaje: Model)
		local hum = personaje:WaitForChild("Humanoid", 10) :: Humanoid?
		if not hum then
			return
		end
		local altura: number? = nil -- desde dónde empezó a caer
		hum.StateChanged:Connect(function(_, nuevo)
			local raiz = personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not raiz then
				return
			end
			if nuevo == Enum.HumanoidStateType.Freefall then
				altura = raiz.Position.Y
			elseif nuevo == Enum.HumanoidStateType.Landed and altura then
				local cayo = altura - raiz.Position.Y
				altura = nil
				if cayo > 2.5 then
					velCaida -= math.clamp(cayo / 10, 0.3, 1) * CAIDA * 14
				end
			end
		end)
	end
	jugador.CharacterAdded:Connect(conPersonaje)
	if jugador.Character then
		task.spawn(conPersonaje, jugador.Character)
	end
	RunService:BindToRenderStep("Cuerpo", Enum.RenderPriority.Camera.Value + 1, paso)
end

return CuerpoVista
