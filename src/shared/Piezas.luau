-- Piezas hechas en Blender (tools/blender/crear_*.py), guardadas en Shared.BosqueMallas y CasaMallas: mallas
-- "<Pieza>_<Papel>" y "<Pieza>_Origin" (centro del suelo de la pieza); las marcas Axis_* dan la escala y los ejes de
-- la importación. Se leen una vez. Sin el archivo, Piezas.poner no pone nada (el juego sigue con los bloques).
--   Piezas.poner(padre, "Pino", cf, escala, papeles) -> las MeshParts puestas, ya ancladas, sin chocar ni tapar rayos
--   (los choques los llevan las piezas de siempre, invisibles). `escala` = Vector3 (ancho, alto, fondo); `papeles`
--   cambia la escala de algún papel (el tronco del pino, más o menos grueso que su copa).
local Piezas = {}

type Trozo = { parte: MeshPart, papel: string, posicion: Vector3, giro: CFrame, tamano: Vector3 }
local plantillas: { [string]: { Trozo } }? = nil

local ARCHIVOS = { "BosqueMallas", "CasaMallas" } -- tools/blender/crear_bosque.py y crear_casa.py

local function cargar(): { [string]: { Trozo } }
	if plantillas then
		return plantillas
	end
	local todas = {}
	plantillas = todas
	for _, nombre in ARCHIVOS do
		local carpeta = script.Parent:FindFirstChild(nombre)
		local eje = carpeta and carpeta:FindFirstChild("Axis_Origin") :: BasePart?
		local arriba = carpeta and carpeta:FindFirstChild("Axis_Up") :: BasePart?
		local frente = carpeta and carpeta:FindFirstChild("Axis_Front") :: BasePart?
		if not (carpeta and eje and arriba and frente) then
			continue
		end
		local vectorArriba = arriba.Position - eje.Position
		local studs = vectorArriba.Magnitude / 2
		local atras = (eje.Position - frente.Position).Unit
		local marco = CFrame.fromMatrix(Vector3.zero, vectorArriba.Unit:Cross(atras), vectorArriba.Unit, atras)
		local origenes = {}
		for _, cosa in carpeta:GetChildren() do
			local pieza = cosa:IsA("BasePart") and string.match(cosa.Name, "^(%a+)_Origin$")
			if pieza and pieza ~= "Axis" then
				origenes[pieza] = cosa
				todas[pieza] = {}
			end
		end
		for _, cosa in carpeta:GetChildren() do
			local pieza, papel = string.match(cosa.Name, "^(%a+)_(%a+)$")
			if cosa:IsA("MeshPart") and pieza and papel ~= "Origin" and origenes[pieza] then
				table.insert(todas[pieza], {
					parte = cosa,
					papel = papel,
					posicion = marco:VectorToObjectSpace(cosa.Position - origenes[pieza].Position) / studs,
					giro = marco.Rotation:Inverse() * cosa.CFrame.Rotation,
					tamano = cosa.Size / studs,
				})
			end
		end
	end
	return todas
end

-- Color y material de cada papel: realista y apagado (la noche y la niebla hacen el resto). Nada brilla. El tercero,
-- si lo hay, es la textura (las ramas de los pinos: agujas con transparencia, de tools/texturas/agujas.ps1).
local ASPECTO: { [string]: { any } } = {
	Rama = { Color3.fromRGB(40, 56, 40), Enum.Material.Fabric, "rbxassetid://123991254477562" }, -- sin brillo: lo liso reflejaba el cielo
	Bark = { Color3.fromRGB(62, 50, 42), Enum.Material.Wood },
	Needles = { Color3.fromRGB(38, 54, 38), Enum.Material.Grass },
	NeedlesDark = { Color3.fromRGB(25, 37, 27), Enum.Material.Grass },
	Dead = { Color3.fromRGB(92, 86, 80), Enum.Material.Wood },
	Moss = { Color3.fromRGB(56, 70, 38), Enum.Material.Grass },
	Stone = { Color3.fromRGB(96, 96, 94), Enum.Material.Rock },
	StoneDark = { Color3.fromRGB(66, 66, 66), Enum.Material.Slate },
	Leaf = { Color3.fromRGB(42, 58, 34), Enum.Material.Grass },
	LeafDark = { Color3.fromRGB(28, 41, 26), Enum.Material.Grass },
	Fern = { Color3.fromRGB(48, 70, 36), Enum.Material.Grass },
	-- La casa: madera vieja, telas sucias, loza amarillenta.
	Wood = { Color3.fromRGB(72, 52, 38), Enum.Material.Wood },
	WoodDark = { Color3.fromRGB(46, 33, 25), Enum.Material.Wood },
	WoodLight = { Color3.fromRGB(96, 74, 54), Enum.Material.Wood },
	Fabric = { Color3.fromRGB(80, 46, 40), Enum.Material.Fabric },
	Cloth = { Color3.fromRGB(150, 142, 124), Enum.Material.Fabric },
	Blanket = { Color3.fromRGB(70, 62, 52), Enum.Material.Fabric },
	Metal = { Color3.fromRGB(92, 90, 88), Enum.Material.Metal },
	MetalDark = { Color3.fromRGB(42, 41, 42), Enum.Material.Metal },
	Ceramic = { Color3.fromRGB(152, 142, 122), Enum.Material.SmoothPlastic }, -- loza amarillenta y sucia
	Grime = { Color3.fromRGB(62, 52, 40), Enum.Material.SmoothPlastic },
	Counter = { Color3.fromRGB(88, 84, 78), Enum.Material.Granite },
	Paper = { Color3.fromRGB(176, 166, 138), Enum.Material.SmoothPlastic },
	BookA = { Color3.fromRGB(88, 30, 28), Enum.Material.Fabric },
	BookB = { Color3.fromRGB(40, 52, 70), Enum.Material.Fabric },
	BookC = { Color3.fromRGB(110, 96, 70), Enum.Material.Fabric },
	Painting = { Color3.fromRGB(52, 42, 34), Enum.Material.SmoothPlastic },
	Rug = { Color3.fromRGB(92, 38, 34), Enum.Material.Fabric },
}

function Piezas.hay(nombre: string): boolean
	return cargar()[nombre] ~= nil
end

function Piezas.poner(padre: Instance, nombre: string, cf: CFrame, escala: Vector3?, papeles: { [string]: Vector3 }?): { MeshPart }
	local trozos = cargar()[nombre]
	local puestas = {}
	if not trozos then
		return puestas
	end
	local general = escala or Vector3.one
	for _, t in trozos do
		local e = papeles and papeles[t.papel] or general
		local parte = t.parte:Clone()
		parte.Name = t.papel
		parte.Size = t.tamano * e
		parte.CFrame = cf * CFrame.new(t.posicion * e) * t.giro
		parte.Anchored = true
		parte.CanCollide = false
		parte.CanQuery = false -- que no tapen las comprobaciones de vista y de luz
		parte.CanTouch = false
		local aspecto = ASPECTO[t.papel]
		if aspecto then
			parte.Color = aspecto[1]
			parte.Material = aspecto[2]
			if aspecto[3] then
				parte.TextureID = aspecto[3]
				parte.Transparency = 0.02 -- con algo de transparencia Roblox respeta la de la textura
			end
		end
		parte.Parent = padre
		table.insert(puestas, parte)
	end
	return puestas
end

return Piezas
