-- La chimenea encendida (servidor: Chimenea, atributo Fuego = hora del servidor hasta la que arde): llamas en el hogar,
-- una luz anaranjada que tiembla, chispas, brasas, humo saliendo del tiro por el tejado y el crepitar en bucle. Al
-- apagarse se queda un rato el humo y las brasas se van enfriando (Config.Detalles.Rescoldo).
-- Detalles (11.9, pedido por el usuario): al quemar al Trepador el fuego se aviva de golpe; si baja con la chimenea
-- apagada, las brasas que quedaban se apagan de golpe (aviso). De noche, con el fuego apagado, el viento aúlla por el
-- tiro y aviva un poco las brasas. Todo en el cliente: nada de esto choca ni cambia el camino del Trepador.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sonido = require(script.Parent.Sonido)

local ChimeneaVista = {}

local D = Config.Detalles
local azar = Random.new()

local function parte(cf: CFrame, tamano: Vector3): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = tamano
	p.CFrame = cf
	p.Parent = workspace
	return p
end

local function preparar(modelo: Instance)
	local hogar = modelo:GetAttribute("Hogar") :: CFrame
	local tiro = modelo:GetAttribute("Tiro") :: Vector3

	-- Hogar (atributo, lo usan también el Trepador y el servidor) queda justo delante de la repisa: lo que se ve va medio
	-- stud más adentro, dentro del hueco (su frente mira a la pared, -Z local).
	local dentro = hogar * CFrame.new(0, 0, -0.5)
	local fuego = parte(dentro, Vector3.new(2, 1, 0.6))
	-- Una llama grande en medio y dos más bajas a los lados (con una sola parecía una antorcha). Tamaño y calor de base.
	local llamas: { { fire: Fire, size: number, heat: number } } = {}
	for _, l in { { 0, 4, 8, fuego }, { -0.65, 2.4, 5 }, { 0.7, 2.1, 5 } } do
		local f = Instance.new("Fire")
		f.Heat = l[3]
		f.Size = l[2]
		f.Color = Color3.fromRGB(255, 120, 40)
		f.SecondaryColor = Color3.fromRGB(120, 30, 10)
		f.Enabled = false
		f.Parent = l[4] or parte(dentro * CFrame.new(l[1], -0.3, 0), Vector3.new(0.6, 0.4, 0.4))
		table.insert(llamas, { fire = f, size = l[2], heat = l[3] })
	end
	local luz = Instance.new("PointLight")
	luz.Color = Color3.fromRGB(255, 140, 70)
	luz.Range = 20
	luz.Brightness = 0
	luz.Shadows = true
	luz.Parent = fuego
	-- Chispas pequeñas que suben y se apagan enseguida (flojas: nada de brillos fuertes).
	local chispas = Instance.new("ParticleEmitter")
	chispas.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	chispas.Color = ColorSequence.new(Color3.fromRGB(255, 160, 60), Color3.fromRGB(200, 60, 20))
	chispas.LightEmission = 0.6
	chispas.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0) })
	chispas.Transparency = NumberSequence.new(0.1, 1)
	chispas.Lifetime = NumberRange.new(0.6, 1.4)
	chispas.Rate = 5
	chispas.Speed = NumberRange.new(2, 4.5)
	chispas.SpreadAngle = Vector2.new(25, 25)
	chispas.Acceleration = Vector3.new(0, 1.5, 0)
	chispas.EmissionDirection = Enum.NormalId.Top
	chispas.Enabled = false
	chispas.Parent = fuego
	-- Brasas: un brillo flojo, nada de neón fuerte.
	local brasas = parte(dentro * CFrame.new(0, -0.62, 0), Vector3.new(2.4, 0.12, 0.6))
	brasas.Material = Enum.Material.Neon
	brasas.Color = Color3.fromRGB(90, 28, 8)
	local luzBrasas = Instance.new("PointLight")
	luzBrasas.Color = Color3.fromRGB(255, 90, 40)
	luzBrasas.Range = 7
	luzBrasas.Brightness = 0
	luzBrasas.Parent = brasas
	local arriba = parte(CFrame.new(tiro + Vector3.new(0, 0.5, 0)), Vector3.new(1, 1, 1))
	local humo = Instance.new("Smoke")
	humo.Color = Color3.fromRGB(70, 66, 62)
	humo.Opacity = 0.18
	humo.Size = 4
	humo.RiseVelocity = 7
	humo.Enabled = false
	humo.Parent = arriba

	local bucle: Sound? = nil
	local brillo = 0
	local apagadoDesde = -math.huge
	local aviva = 0 -- llamarada al quemar al Trepador (1 y baja sola)
	local racha = 0 -- el viento por el tiro aviva las brasas (1 y baja sola)
	local proximoViento = os.clock() + azar:NextNumber(D.VientoTiro[1], D.VientoTiro[2])

	Remotes.Trepador.OnClientEvent:Connect(function(tipo: string)
		if tipo == "Quema" then
			aviva = 1
		elseif tipo == "Baja" and (modelo:GetAttribute("Fuego") or 0) <= workspace:GetServerTimeNow() then
			apagadoDesde = -math.huge -- lo que bajaba por el tiro ha apagado las brasas
			racha = 0
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		local ahora = os.clock()
		local encendida = (modelo:GetAttribute("Fuego") or 0) > workspace:GetServerTimeNow()
		brillo += ((if encendida then 1 else 0) - brillo) * math.min(1, dt * 1.5)
		aviva = math.max(0, aviva - dt / 1.8)
		racha = math.max(0, racha - dt / 3)
		for _, l in llamas do
			l.fire.Enabled = encendida
			l.fire.Size = l.size * (1 + aviva * 1.5)
			l.fire.Heat = l.heat + aviva * 10
		end
		chispas.Enabled = encendida
		chispas.Rate = 5 + aviva * 60
		if encendida then
			apagadoDesde = ahora
		end
		-- Lo que queda de las brasas: 1 con fuego y baja hasta 0 en Rescoldo segundos.
		local rescoldo = math.clamp(1 - (ahora - apagadoDesde) / D.Rescoldo, 0, 1)
		local temblor = 0.75 + 0.25 * math.noise(ahora * 6, 0.3)
		local ascuas = math.max(brillo, rescoldo * (0.45 + 0.4 * racha))
		brasas.Transparency = 1 - ascuas * 0.6 * (0.85 + 0.15 * math.noise(ahora * 2, 1.7))
		luz.Brightness = brillo * 1.3 * temblor * (1 + aviva * 1.5)
		luzBrasas.Brightness = if encendida then 0 else rescoldo * (0.35 + 0.5 * racha) * temblor
		humo.Enabled = ahora - apagadoDesde < 8
		if encendida and not bucle then
			local s = Sonido.bucle("Fuego", fuego)
			s.RollOffMode = Enum.RollOffMode.InverseTapered
			s.RollOffMinDistance = 6
			s.RollOffMaxDistance = 40
			bucle = s
		elseif not encendida and bucle then
			bucle:Destroy()
			bucle = nil
		end
		-- El viento por el tiro: de noche, apagada y con la cámara cerca.
		if ahora >= proximoViento then
			proximoViento = ahora + azar:NextNumber(D.VientoTiro[1], D.VientoTiro[2])
			local cerca = (workspace.CurrentCamera.CFrame.Position - hogar.Position).Magnitude < D.Cerca
			if not encendida and cerca and workspace:GetAttribute("Fase") == "Noche" then
				Sonido.en("VientoTiro", hogar.Position, azar:NextNumber(0.9, 1.1))
				racha = 1
			end
		end
	end)
end

function ChimeneaVista.start()
	local modelo = CollectionService:GetTagged("Chimenea")[1] or CollectionService:GetInstanceAddedSignal("Chimenea"):Wait()
	preparar(modelo)
end

return ChimeneaVista
