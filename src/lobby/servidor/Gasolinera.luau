-- El mapa del lobby por código, con bloques grises (el arte llega al final): una gasolinera vieja de noche junto a la
-- carretera del bosque, con la marquesina, dos surtidores, la tienda (más adelante, la de clases y cosméticos), un
-- cartel que parpadea y los coches aparcados (Coches). Los coches llevan la etiqueta "Coche" y van en workspace.Coches.
-- La carretera va a lo largo de Z en x = 0; hacia -Z se entra en el bosque. Lluvia: más adelante.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Separar = require(ServerScriptService:WaitForChild("Comun").Separar)

local Gasolinera = {}

local COLOR = {
	Hierba = Color3.fromRGB(46, 52, 44),
	Asfalto = Color3.fromRGB(44, 44, 46),
	Hormigon = Color3.fromRGB(96, 94, 90),
	Muro = Color3.fromRGB(118, 114, 106),
	Oscuro = Color3.fromRGB(40, 39, 38),
	Tronco = Color3.fromRGB(58, 54, 50),
	Coche = Color3.fromRGB(88, 86, 84),
	Rueda = Color3.fromRGB(28, 28, 30),
	Cristal = Color3.fromRGB(120, 135, 145),
	Cartel = Color3.fromRGB(150, 40, 32),
}

local function bloque(nombre: string, tamano: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, padre: Instance): Part
	local p = Instance.new("Part")
	p.Name = nombre
	p.Anchored = true
	p.Size = tamano
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Concrete
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = padre
	return p
end

local function luz(pieza: BasePart, brillo: number, alcance: number, color: Color3): PointLight
	local l = Instance.new("PointLight")
	l.Brightness = brillo
	l.Range = alcance
	l.Color = color
	l.Shadows = true
	l.Parent = pieza
	return l
end

-- Un coche con Config.Coches.Plazas asientos, mirando hacia `-Z` local (hacia el bosque).
local function coche(n: number, cf: CFrame, padre: Instance)
	local modelo = Instance.new("Model")
	modelo.Name = `Coche{n}`
	local cuerpo = bloque("Carroceria", Vector3.new(6, 2, 12), cf * CFrame.new(0, 1.6, 0), COLOR.Coche, Enum.Material.Metal, modelo)
	bloque("Capo", Vector3.new(5.8, 0.6, 3.4), cf * CFrame.new(0, 2.9, -4.2), COLOR.Coche, Enum.Material.Metal, modelo)
	bloque("Maletero", Vector3.new(5.8, 0.6, 2), cf * CFrame.new(0, 2.9, 4.9), COLOR.Coche, Enum.Material.Metal, modelo)
	bloque("Techo", Vector3.new(5.8, 0.3, 6.2), cf * CFrame.new(0, 6.3, 0.6), COLOR.Coche, Enum.Material.Metal, modelo)
	for _, x in { -2.75, 2.75 } do
		for _, z in { -2.3, 3.5 } do
			bloque("Poste", Vector3.new(0.3, 3.5, 0.3), cf * CFrame.new(x, 4.4, z), COLOR.Coche, Enum.Material.Metal, modelo)
		end
	end
	local luna = bloque("Luna", Vector3.new(5.4, 3.3, 0.15), cf * CFrame.new(0, 4.5, -2.4) * CFrame.Angles(math.rad(-20), 0, 0),
		COLOR.Cristal, Enum.Material.Glass, modelo)
	luna.Transparency = 0.6
	for _, x in { -3.1, 3.1 } do
		for _, z in { -3.8, 3.8 } do
			local rueda = bloque("Rueda", Vector3.new(0.9, 2.4, 2.4), cf * CFrame.new(x, 1.2, z), COLOR.Rueda, Enum.Material.Rubber, modelo)
			rueda.Shape = Enum.PartType.Cylinder
		end
	end
	-- Faros (con una luz floja: es de noche y el coche está parado).
	for _, x in { -2.1, 2.1 } do
		local faro = bloque("Faro", Vector3.new(1.2, 0.6, 0.2), cf * CFrame.new(x, 2.1, -6.05), Color3.fromRGB(200, 196, 180),
			Enum.Material.Glass, modelo)
		luz(faro, 0.4, 10, Color3.fromRGB(255, 236, 200)).Shadows = false
	end
	local sitios = { Vector3.new(-1.3, 2.8, -0.6), Vector3.new(1.3, 2.8, -0.6), Vector3.new(-1.3, 2.8, 2.4), Vector3.new(1.3, 2.8, 2.4) }
	for i = 1, Config.Coches.Plazas do
		local asiento = Instance.new("Seat")
		asiento.Name = `Asiento{i}`
		asiento.Anchored = true
		asiento.Size = Vector3.new(2, 0.4, 2)
		asiento.CFrame = cf * CFrame.new(sitios[(i - 1) % #sitios + 1])
		asiento.Color = COLOR.Oscuro
		asiento.Material = Enum.Material.Fabric
		asiento.Parent = modelo
	end
	modelo.PrimaryPart = cuerpo
	CollectionService:AddTag(modelo, "Coche")
	modelo.Parent = padre
end

local function bosque(mapa: Folder)
	local azar = Random.new(11)
	local puestos = 0
	while puestos < 180 do
		local x, z = azar:NextNumber(-260, 260), azar:NextNumber(-260, 260)
		local enGasolinera = x > -14 and x < 80 and math.abs(z) < 50
		if math.abs(x) > 12 and not enGasolinera then
			local alto, grueso = azar:NextNumber(40, 70), azar:NextNumber(2, 4)
			bloque("Tronco", Vector3.new(alto, grueso, grueso), CFrame.new(x, alto / 2, z) * CFrame.Angles(0, 0, math.pi / 2),
				COLOR.Tronco, Enum.Material.Wood, mapa).Shape = Enum.PartType.Cylinder
			puestos += 1
		end
	end
end

local function cartel(mapa: Folder)
	bloque("Poste", Vector3.new(0.8, 18, 0.8), CFrame.new(10, 9, -42), COLOR.Oscuro, Enum.Material.Metal, mapa)
	local tabla = bloque("Cartel", Vector3.new(8, 4, 0.6), CFrame.new(10, 19, -42) * CFrame.Angles(0, math.rad(90), 0), COLOR.Cartel,
		Enum.Material.SmoothPlastic, mapa)
	for _, cara in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = cara
		gui.LightInfluence = 1
		local texto = Instance.new("TextLabel")
		texto.Size = UDim2.fromScale(1, 1)
		texto.BackgroundTransparency = 1
		texto.Text = "GAS"
		texto.TextScaled = true
		texto.Font = Enum.Font.SpecialElite
		texto.TextColor3 = Color3.fromRGB(230, 220, 200)
		texto.Parent = gui
		gui.Parent = tabla
	end
	local l = luz(tabla, 1.2, 22, Color3.fromRGB(255, 120, 100))
	-- Parpadea como un fluorescente viejo: casi siempre encendido, con tirones de vez en cuando.
	task.spawn(function()
		local azar = Random.new()
		while true do
			task.wait(azar:NextNumber(1.5, 6))
			for _ = 1, azar:NextInteger(2, 5) do
				l.Enabled = false
				tabla.Color = Color3.fromRGB(70, 22, 20)
				task.wait(azar:NextNumber(0.04, 0.15))
				l.Enabled = true
				tabla.Color = COLOR.Cartel
				task.wait(azar:NextNumber(0.04, 0.2))
			end
		end
	end)
end

local function noche()
	Lighting.ClockTime = 0.5
	Lighting.Brightness = 0.6
	Lighting.Ambient = Color3.fromRGB(26, 27, 34)
	Lighting.OutdoorAmbient = Color3.fromRGB(34, 36, 46)
	Lighting.FogColor = Color3.fromRGB(14, 15, 20)
	Lighting.FogStart = 20
	Lighting.FogEnd = 260
	Lighting.EnvironmentDiffuseScale = 0.2
	Lighting.EnvironmentSpecularScale = 0.2
end

function Gasolinera.start()
	local mapa = workspace:WaitForChild("Mapa")
	noche()
	bloque("Hierba", Vector3.new(800, 2, 800), CFrame.new(0, -1, 0), COLOR.Hierba, Enum.Material.Grass, mapa)
	bloque("Carretera", Vector3.new(14, 0.2, 800), CFrame.new(0, 0.1, 0), COLOR.Asfalto, Enum.Material.Asphalt, mapa)
	bloque("Explanada", Vector3.new(66, 0.2, 80), CFrame.new(40, 0.1, 0), COLOR.Hormigon, Enum.Material.Concrete, mapa)

	-- Marquesina sobre los surtidores, con dos luces flojas.
	local techo = bloque("Marquesina", Vector3.new(20, 1.2, 26), CFrame.new(32, 13, 0), COLOR.Muro, Enum.Material.Metal, mapa)
	for _, z in { -6, 6 } do
		luz(bloque("Fluorescente", Vector3.new(1, 0.2, 6), CFrame.new(32, 12.3, z), Color3.fromRGB(210, 214, 200),
			Enum.Material.SmoothPlastic, mapa), 1.1, 26, Color3.fromRGB(225, 230, 215))
	end
	for _, x in { 24, 40 } do
		for _, z in { -11, 11 } do
			bloque("Pilar", Vector3.new(1, 12.4, 1), CFrame.new(x, 6.2, z), COLOR.Muro, Enum.Material.Concrete, mapa)
		end
		bloque("Surtidor", Vector3.new(2, 5, 3), CFrame.new(x == 24 and 30 or 34, 2.5, 0), COLOR.Oscuro, Enum.Material.Metal, mapa)
	end
	techo.CastShadow = true

	-- La tienda: una caja con la puerta hacia la carretera (dentro irá la tienda de clases y cosméticos).
	local x0, x1, z0, z1, alto = 52, 70, -14, 14, 11
	bloque("Muro", Vector3.new(x1 - x0, alto, 1), CFrame.new((x0 + x1) / 2, alto / 2, z0), COLOR.Muro, nil, mapa)
	bloque("Muro", Vector3.new(x1 - x0, alto, 1), CFrame.new((x0 + x1) / 2, alto / 2, z1), COLOR.Muro, nil, mapa)
	bloque("Muro", Vector3.new(1, alto, z1 - z0), CFrame.new(x1, alto / 2, 0), COLOR.Muro, nil, mapa)
	bloque("Muro", Vector3.new(1, alto, 10), CFrame.new(x0, alto / 2, -9), COLOR.Muro, nil, mapa)
	bloque("Muro", Vector3.new(1, alto, 10), CFrame.new(x0, alto / 2, 9), COLOR.Muro, nil, mapa)
	bloque("Dintel", Vector3.new(1, alto - 8, 8), CFrame.new(x0, 8 + (alto - 8) / 2, 0), COLOR.Muro, nil, mapa)
	bloque("Tejado", Vector3.new(x1 - x0 + 2, 1, z1 - z0 + 2), CFrame.new((x0 + x1) / 2, alto + 0.5, 0), COLOR.Oscuro, nil, mapa)
	luz(bloque("Bombilla", Vector3.new(0.6, 0.6, 0.6), CFrame.new(61, alto - 1, 0), Color3.fromRGB(255, 214, 160),
		Enum.Material.SmoothPlastic, mapa), 0.9, 20, Color3.fromRGB(255, 200, 150))

	cartel(mapa)
	bosque(mapa)

	local aparicion = Instance.new("SpawnLocation")
	aparicion.Anchored = true
	aparicion.Size = Vector3.new(6, 0.4, 6)
	aparicion.CFrame = CFrame.new(44, 0.3, 0)
	aparicion.Color = COLOR.Hormigon
	aparicion.Material = Enum.Material.Concrete
	aparicion.Neutral = true
	aparicion.Duration = 0
	aparicion.Parent = mapa

	-- Los coches, aparcados en fila junto a la carretera mirando al bosque.
	local coches = Instance.new("Folder")
	coches.Name = "Coches"
	for i = 1, Config.Coches.Cuantos do
		coche(i, CFrame.new(14, 0.2, -24 + (i - 1) * 16), coches)
	end
	coches.Parent = workspace
	local quedan = Separar.caras(mapa) + Separar.caras(coches) -- que no parpadeen dos caras en el mismo plano
	if quedan > 0 then
		warn(`[Gasolinera] quedan {quedan} caras que parpadean`)
	end
end

return Gasolinera
