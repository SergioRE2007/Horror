-- Que la cámara se sienta un cuerpo (pedido por el usuario: "que todo esté animado y sea inmersivo"). Solo en primera
-- persona, con la cámara normal (nunca en cinemáticas, escondido, muerto ni con la mochila abierta):
--   Al andar, la cabeza sube y baja con cada paso (la misma zancada que los sonidos de Pasos) y se mece un poco de lado;
--   corriendo deprisa, más. Quieto, respira.
--   Al moverte de lado, se inclina un poco hacia ese lado.
--   Al caer de una altura, la cabeza baja de golpe y vuelve.
--   Con un bicho cerca, respira más rápido y más hondo (el miedo).
--   De noche y fuera de la casa, se ve el vaho al respirar (sin él con Rendimiento).
--   Manda al servidor cuánto miras arriba o abajo (remote Mirada) para que los demás lo vean (BrazosVista).
--   Agachado (PosturaVista, 14.6), la vista baja suave Config.Postura.Baja; al bajar, las rodillas dan un golpecito
--   (sin él con Rendimiento). Asomado, va de lado Config.Postura.Asomar y se ladea Config.Postura.Giro grados, sin
--   meterse en las paredes (rayos hacia ese lado desde la cabeza y desde la cámara, que va ATRAS detrás: si chocan, se
--   queda HOLGURA antes). Mirando por la mirilla (atributo local Mirilla), derecho y de pie. Agachado se sigue con la
--   mochila abierta (la vista no salta al abrirla) y el ladeo vuelve suave; escondido, muerto o en una cinemática la
--   cámara no es de Roblox y no se nota (al volver, el ladeo entra suave).
-- Con lo pesado en las manos el balanceo lo pone CargarVista: aquí no se suma.
-- Se pinta encima de la cámara de Roblox (BindToRenderStep, Camera + 1): solo mueve la posición y la inclina de lado.
-- Lo sumado se quita antes del fotograma siguiente (Camera - 1), girando en el espacio del mundo: los temblores de
-- otros módulos (CasaVista, BestiaVista, la reja, MochilaUi...) giran en Camera + 1 y se deshacen en Camera - 1, y
-- según quién corriera antes su deshacer y el nuestro se mezclaban y la mirada se iba desviando (comprobado con Lune:
-- así sale bien en cualquier orden).
-- Agacharse y asomarse van ANTES de la cámara de Roblox (Camera - 1), en el CameraOffset del Humanoid: así la cámara ya
-- sale de ahí y lo que va colgado de ella (manos, linterna, la mochila abierta, la entrada al escondite) lo ve igual,
-- haya corrido antes quien haya corrido. Con algo pesado el CameraOffset es de CargarVista (y la postura ya está
-- quitada): entonces no se toca.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PosturaVista = require(script.Parent.PosturaVista)

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
local P = Config.Postura
local SUAVE_POSTURA = 9 -- lo deprisa que baja o sube la vista al agacharte y al asomarte
local VUELVE_LADEO = 3 -- por segundo: lo que tarda el ladeo en volver tras una cinemática o un vistazo (1/3 s)
local HOLGURA = 0.3 -- studs que se queda la cámara antes de una pared al asomarte
local ATRAS = 0.5 -- studs que pone la cámara de Roblox los ojos detrás de la cabeza en primera persona
local RODILLAS = 2.5 -- golpecito al agacharte (velocidad que se suma al muelle de la caída; al levantarte, menos)

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
-- Postura (lo que se pone en el CameraOffset; en el espacio de la raíz).
local bajado = 0 -- studs que ha bajado la vista (agachado)
local asomo = 0 -- -1..1: cuánto está asomado (para el ladeo)
local lateral = 0 -- studs de lado ahora mismo (lo que deja la pared)
local aplicado = Vector3.zero -- lo puesto este fotograma
local duenoDe: Humanoid? = nil -- el Humanoid cuyo CameraOffset se lleva aquí (nil con algo pesado: es de CargarVista)
local estabaAgachado = false
local pesoLadeo = 1 -- 0..1: cuánto se nota el ladeo (a 0 mientras la cámara es de otro; luego vuelve suave)
local giroAplicado: CFrame? = nil -- lo que `paso` le ha sumado a la cámara este fotograma
local camaraTras: CFrame? = nil -- y cómo quedó la cámara justo después
local rayo = RaycastParams.new()
rayo.FilterType = Enum.RaycastFilterType.Exclude
rayo.RespectCanCollide = true -- cortinas, hojas y lo que no choca no paran la cabeza

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

local function enJuego(raiz: BasePart): boolean
	if camara.CameraType ~= Enum.CameraType.Custom then
		return false
	end
	if jugador:GetAttribute("Muerto") or jugador:GetAttribute("Escondido") or jugador:GetAttribute("MochilaAbierta") then
		return false
	end
	local cabeza = jugador.Character and jugador.Character:FindFirstChild("Head") :: BasePart?
	-- La cámara está desplazada lo que haya puesto la postura (agachado o asomado): se compara con ese sitio.
	local desvio = raiz.CFrame:VectorToWorldSpace(aplicado)
	return cabeza ~= nil and (camara.CFrame.Position - cabeza.Position - desvio).Magnitude < 2.5
end

-- Lo libre hacia un lado desde `desde`, hasta P.Asomar.
local function libreDesde(desde: Vector3, lado: Vector3): number
	local choque = workspace:Raycast(desde, lado, rayo)
	return if choque then math.max(0, choque.Distance - HOLGURA) else P.Asomar
end

-- Hasta dónde puede ir la cabeza hacia `signo` (1 derecha, -1 izquierda) sin meterse en una pared.
local function hueco(personaje: Model, raiz: BasePart, signo: number): number
	-- Donde pone la cámara de Roblox el centro de la cabeza (1,5 sobre la raíz, más lo que mida de más), ya agachado.
	local ojo = raiz.CFrame:PointToWorldSpace(Vector3.new(0, 1.5 + (raiz.Size.Y - 2) / 2 - bajado, 0))
	local lado = raiz.CFrame.RightVector * (signo * (P.Asomar + HOLGURA))
	rayo.FilterDescendantsInstances = { personaje, camara }
	-- Y desde donde va de verdad la cámara: ATRAS studs detrás, hacia donde miras. Asomándote junto a una esquina que
	-- acaba justo a tu altura, la cabeza ya ha pasado el borde pero la cámara aún no, y se metería en la pared.
	return math.min(libreDesde(ojo, lado), libreDesde(ojo - camara.CFrame.LookVector * ATRAS, lado))
end

-- Quita lo que `paso` le sumó a la cámara el fotograma anterior (ver la cabecera). Por la izquierda, en el espacio del
-- mundo: tras · giro⁻¹ · tras⁻¹ deshace justo lo nuestro aunque otros hayan girado después o ya se hayan deshecho.
-- En una cinemática no se toca (la cámara la lleva un script).
local function deshacer()
	local giro, tras = giroAplicado, camaraTras
	giroAplicado, camaraTras = nil, nil
	if giro and tras and camara.CameraType == Enum.CameraType.Custom then
		camara.CFrame = tras * giro:Inverse() * tras:Inverse() * camara.CFrame
	end
end

-- Le suma `giro` a la cámara (por la derecha, en su espacio) y lo apunta para deshacerlo.
local function aplicar(giro: CFrame)
	camara.CFrame *= giro
	giroAplicado, camaraTras = giro, camara.CFrame
end

-- Antes de la cámara de Roblox: agacharse y asomarse en el CameraOffset (ver la cabecera).
local function postura(dt: number)
	deshacer()
	aplicado = Vector3.zero
	local personaje = jugador.Character
	local hum = personaje and personaje:FindFirstChildOfClass("Humanoid")
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not personaje or not hum or not raiz or jugador:GetAttribute("Cargando") then
		duenoDe = nil -- con lo pesado lo lleva CargarVista
		asomo = if math.abs(asomo) < 1e-3 then 0 else asomo * math.exp(-dt * SUAVE_POSTURA) -- el ladeo vuelve igual
		return
	end
	if duenoDe ~= hum then
		-- Vuelve aquí (al soltar lo pesado, o un personaje nuevo): desde donde lo dejó CargarVista, sin saltos.
		duenoDe = hum
		bajado, lateral, asomo = math.max(0, -hum.CameraOffset.Y), hum.CameraOffset.X, 0
	end
	local muerto = hum.Health <= 0 or jugador:GetAttribute("Muerto") == true
	local derecho = muerto or jugador:GetAttribute("Mirilla") == true -- por la mirilla, de pie y sin asomarse
	local metaBaja = if PosturaVista.agachado() and not derecho then P.Baja else 0
	local metaAsomo = if derecho then 0 else PosturaVista.asomado()
	local k = if muerto then 1 else 1 - math.exp(-dt * SUAVE_POSTURA)
	bajado += (metaBaja - bajado) * k
	asomo += (metaAsomo - asomo) * k
	-- De lado: lo que deja la pared de cada lado por el que va o va a ir (hacia la pared, al momento: nunca dentro).
	local metaLado = metaAsomo * P.Asomar
	local der = if lateral > 0.01 or metaLado > 0 then hueco(personaje, raiz, 1) else P.Asomar
	local izq = if lateral < -0.01 or metaLado < 0 then hueco(personaje, raiz, -1) else P.Asomar
	lateral += (math.clamp(metaLado, -izq, der) - lateral) * k
	lateral = math.clamp(lateral, -izq, der)
	if bajado < 1e-3 then
		bajado = 0
	end
	if math.abs(lateral) < 1e-3 then
		lateral = 0
	end
	if math.abs(asomo) < 1e-3 then
		asomo = 0
	end
	aplicado = Vector3.new(lateral, -bajado, 0)
	if hum.CameraOffset ~= aplicado then
		hum.CameraOffset = aplicado
	end
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
	local agachado = PosturaVista.agachado()
	local cambioPostura = agachado ~= estabaAgachado
	estabaAgachado = agachado
	-- Asomado, la cabeza se ladea hacia ese lado (a la derecha, lo de arriba de la imagen va a la derecha). Solo con la
	-- cámara de Roblox; si ha sido de otro un rato (una cinemática, un vistazo, el escondite), vuelve suave sin saltar.
	pesoLadeo = if camara.CameraType == Enum.CameraType.Custom then math.min(1, pesoLadeo + dt * VUELVE_LADEO) else 0
	local ladeo = -asomo * math.rad(P.Giro) * pesoLadeo * pesoLadeo * (3 - 2 * pesoLadeo)
	if not hum or not raiz or not enJuego(raiz) then
		fuerza, inclinado, caida, velCaida = 0, 0, 0, 0
		-- El ladeo vuelve suave aunque ahora no toque balancear (al abrir la mochila asomándote, p. ej.).
		if hum and ladeo ~= 0 and not jugador:GetAttribute("Escondido") then
			aplicar(CFrame.Angles(0, 0, ladeo))
		end
		return
	end
	-- Al agacharte, las rodillas: la cabeza baja un poco de más y vuelve (con el muelle de la caída).
	if cambioPostura and jugador:GetAttribute("Rendimiento") ~= true then
		velCaida += if agachado then -RODILLAS else RODILLAS * 0.4
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

	aplicar(CFrame.new(lado, sube + respira + caida, 0) * CFrame.Angles(0, 0, mece + inclinado + ladeo))

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
	RunService:BindToRenderStep("CuerpoPostura", Enum.RenderPriority.Camera.Value - 1, postura)
	RunService:BindToRenderStep("Cuerpo", Enum.RenderPriority.Camera.Value + 1, paso)
end

return CuerpoVista
