-- Ayudas para montar el cuerpo de un bicho con piezas (provisional hasta los modelos de verdad).
-- Raíz invisible con un Humanoid; los miembros van unidos con Motor6D (todos en la raíz) y el cliente mueve su
-- Transform; los adornos van soldados a su miembro.
local Cuerpo = {}

local function pieza(nombre: string, tamano: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = nombre
	p.Size = tamano
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Reflectance = if material then 0 else 0.04 -- un poco brillante: piel mojada
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	return p
end

-- Modelo nuevo con su raíz en `cf` (aún sin colgar en el mapa).
function Cuerpo.nuevo(nombre: string, cf: CFrame): (Model, BasePart)
	local m = Instance.new("Model")
	m.Name = nombre
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local raiz = Instance.new("Part")
	raiz.Name = "HumanoidRootPart"
	raiz.Size = Vector3.new(3, 3, 1.5)
	raiz.Transparency = 1
	raiz.CFrame = cf
	raiz.Parent = m
	m.PrimaryPart = raiz
	return m, raiz
end

-- Pieza del cuerpo unida a `padre` con un Motor6D. `junta`: dónde está la articulación en el padre; `desde`: dónde
-- está en la pieza.
function Cuerpo.miembro(m: Model, nombre: string, tamano: Vector3, padre: BasePart, junta: CFrame, desde: CFrame, color: Color3): BasePart
	local p = pieza(nombre, tamano, color)
	p.CFrame = padre.CFrame * junta * desde:Inverse()
	p.Parent = m
	local motor = Instance.new("Motor6D")
	motor.Name = nombre
	motor.Part0 = padre
	motor.Part1 = p
	motor.C0 = junta
	motor.C1 = desde
	motor.Parent = m.PrimaryPart
	return p
end

-- Adorno pegado a `padre` en `donde` (coordenadas del padre).
function Cuerpo.pegar(m: Model, padre: BasePart, tamano: Vector3, donde: CFrame, color: Color3, material: Enum.Material?)
	local p = pieza("Adorno", tamano, color, material)
	p.CFrame = padre.CFrame * donde
	local soldadura = Instance.new("WeldConstraint")
	soldadura.Part0 = padre
	soldadura.Part1 = p
	soldadura.Parent = p
	p.Parent = m
end

-- Le pone el Humanoid y lo cuelga en `carpeta`. `altura`: de los pies al centro de la raíz.
function Cuerpo.terminar(m: Model, carpeta: Instance, altura: number, andar: number): Humanoid
	local raiz = m.PrimaryPart :: BasePart
	local humanoide = Instance.new("Humanoid")
	humanoide.HipHeight = altura - raiz.Size.Y / 2
	humanoide.WalkSpeed = andar
	humanoide.MaxHealth = 1e9
	humanoide.Health = 1e9
	humanoide.BreakJointsOnDeath = false
	humanoide.RequiresNeck = false
	humanoide.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoide.Parent = m
	m.Parent = carpeta
	raiz:SetNetworkOwner(nil)
	return humanoide
end

return Cuerpo
