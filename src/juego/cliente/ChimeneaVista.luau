-- La chimenea encendida (servidor: Chimenea, atributo Fuego = hora del servidor hasta la que arde): llamas en el hogar,
-- una luz anaranjada que tiembla, brasas, humo saliendo del tiro por el tejado y el crepitar en bucle. Al apagarse se
-- queda un rato el humo.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Sonido = require(script.Parent.Sonido)

local ChimeneaVista = {}

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

	local fuego = parte(hogar, Vector3.new(2, 1, 1))
	local llamas = Instance.new("Fire")
	llamas.Heat = 8
	llamas.Size = 4
	llamas.Color = Color3.fromRGB(255, 120, 40)
	llamas.SecondaryColor = Color3.fromRGB(120, 30, 10)
	llamas.Enabled = false
	llamas.Parent = fuego
	local luz = Instance.new("PointLight")
	luz.Color = Color3.fromRGB(255, 140, 70)
	luz.Range = 20
	luz.Brightness = 0
	luz.Shadows = true
	luz.Parent = fuego
	-- Brasas: un brillo flojo, nada de neón fuerte.
	local brasas = parte(hogar * CFrame.new(0, -0.5, -0.2), Vector3.new(2.4, 0.15, 0.9))
	brasas.Material = Enum.Material.Neon
	brasas.Color = Color3.fromRGB(90, 28, 8)
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
	RunService.Heartbeat:Connect(function(dt)
		local encendida = (modelo:GetAttribute("Fuego") or 0) > workspace:GetServerTimeNow()
		brillo += ((if encendida then 1 else 0) - brillo) * math.min(1, dt * 1.5)
		llamas.Enabled = encendida
		brasas.Transparency = 1 - brillo * 0.6
		local temblor = 0.75 + 0.25 * math.noise(os.clock() * 6, 0.3)
		luz.Brightness = brillo * 1.3 * temblor
		if encendida then
			apagadoDesde = os.clock()
		end
		humo.Enabled = os.clock() - apagadoDesde < 8
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
	end)
end

function ChimeneaVista.start()
	local modelo = CollectionService:GetTagged("Chimenea")[1] or CollectionService:GetInstanceAddedSignal("Chimenea"):Wait()
	preparar(modelo)
end

return ChimeneaVista
