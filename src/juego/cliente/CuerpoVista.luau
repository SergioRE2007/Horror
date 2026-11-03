-- Que la cámara se sienta un cuerpo (pedido por el usuario: "que todo esté animado y sea inmersivo"). Solo en primera
-- persona, con la cámara normal (nunca en cinemáticas, escondido, muerto ni con la mochila abierta):
--   Al andar, la cabeza sube y baja con cada paso (la misma zancada que los sonidos de Pasos) y se mece un poco de lado;
--   corriendo deprisa, más. Quieto, respira.
--   Al moverte de lado, se inclina un poco hacia ese lado.
--   Al caer de una altura, la cabeza baja de golpe y vuelve.
--   Con un bicho cerca, respira más rápido y más hondo (el miedo).
-- Con lo pesado en las manos el balanceo lo pone CargarVista: aquí no se suma.
-- Se pinta encima de la cámara de Roblox (BindToRenderStep, Camera + 1): solo mueve la posición y la inclina de lado,
-- que la cámara rehace cada fotograma (no se acumula).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

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

	-- Caer: la cabeza baja de golpe y vuelve con un muelle.
	velCaida += (-caida * 120 - velCaida * 16) * dt
	caida += velCaida * dt

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
