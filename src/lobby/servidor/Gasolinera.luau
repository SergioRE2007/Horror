-- El lobby por código (pedido por el usuario: "el lobby es un poco feo"; docs/diseño.md): de noche cerrada y con
-- lluvia, una gasolinera vieja junto a la carretera del bosque. Aquí, el mapa base:
--   la luz del servidor (la niebla de verdad y el color los pone el cliente, Clima), el suelo (hierba con calvas de
--   barro y las cunetas), la carretera (asfalto viejo con parches, grietas, alquitrán, baches con agua y rayas gastadas;
--   arcén de grava y barro), la orilla (quitamiedos torcidos, postes de la luz con cables, una señal doblada, hitos,
--   una cruz), tres farolas (una parpadea y otra está muerta), el bosque (pinos de Blender y sotobosque), los puntos
--   "Sombra" entre los árboles y la aparición. Luego GasolineraTienda, GasolineraFuera (explanada, marquesina,
--   surtidores, cartel…) y GasolineraCoches (en workspace.Coches). Lo que se anima (parpadeos, lluvia, polillas,
--   sombras) lo hace el cliente con las etiquetas y atributos (GasolineraVista, Clima; contrato en docs/sistemas/lobby.md).
-- Plano: la carretera va a lo largo de Z en x = 0 (14 de ancho, cara de arriba en y = 0,2) y sigue 400 studs a cada
-- lado; hacia -Z se entra en el bosque. La explanada, de x 7 a 73 y de z -40 a 40. La hierba, con la cara de arriba en
-- y = 0.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Piezas = require(ReplicatedStorage.Shared.Piezas)
local Separar = require(ServerScriptService:WaitForChild("Comun").Separar)
local P = require(script.Parent.GasolineraPiezas)

local Gasolinera = {}

local COLOR = P.COLOR
local LARGO = 400 -- studs de carretera a cada lado de la gasolinera
local CENTRO = Vector3.new(40, 0, 0) -- el centro de la explanada
-- Altura de la cara de arriba de lo que va encima del asfalto: separadas para que no parpadeen al cruzarse (lo que va
-- girado no lo arregla Separar).
local ASFALTO, PARCHE, GRIETA, ALQUITRAN, RAYA, MANCHA = 0.2, 0.22, 0.245, 0.27, 0.295, 0.32
local ARCEN = 0.15 -- la cara de arriba del arcén de grava
-- La cuneta, a los dos lados (|x|): del borde del arcén baja al fondo de barro y sube a la hierba.
local BORDE, FONDO0, FONDO1, FUERA, HONDO = 9.5, 10.9, 12.3, 14, -1
local CORTE = 48 -- |z| donde la cuneta del este se mete en un tubo (delante de la gasolinera no hay)
local CLARO = { x0 = -12, x1 = 80, z0 = -50, z1 = 50 } -- la gasolinera: sin árboles ni nada del bosque
local CALLE = 16 -- |x| hasta donde no hay árboles junto a la carretera (carretera, arcén y cuneta)
local POSTES_X = -16.5 -- la fila de postes de la luz, al otro lado de la carretera

local GRAVA = Color3.fromRGB(64, 60, 54)
local TALUD = Color3.fromRGB(46, 46, 38)
local TRONCO = Color3.fromRGB(58, 54, 50)
local MADERA = Color3.fromRGB(62, 54, 46) -- madera vieja de los postes
local GALVANIZADO = Color3.fromRGB(96, 98, 96)
local OXIDO = Color3.fromRGB(88, 54, 36)
local SANGRE = Color3.fromRGB(62, 8, 8)
local SODIO = Color3.fromRGB(255, 150, 70) -- la luz de las farolas: naranja floja
local VERTICAL = CFrame.Angles(0, 0, math.pi / 2) -- un cilindro de pie (en Roblox van a lo largo de X)

------------------------------------------------------------------------------------------------------------------------
-- Ayudas

-- Un adorno sin sombra (lo plano y lo pequeño).
local function plano(padre: Instance, nombre: string, tam: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = P.bloque(padre, nombre, tam, cf, color, material)
	p.CastShadow = false
	return p
end

-- Lo que lleva cosas encima a una altura exacta (el suelo, el asfalto, el arcén, las rayas, los charcos): que Separar
-- no lo agrande (subiría la hierba por encima del barro, por ejemplo). Ya va puesto sin caras en el mismo plano.
local function fijo<T>(p: T): T
	(p :: any):SetAttribute("SinSeparar", true)
	return p
end

-- Un disco tumbado (`ancho` × `largo`: una elipse) con la cara de arriba en `arriba`.
local function disco(padre: Instance, nombre: string, x: number, z: number, ancho: number, largo: number, arriba: number,
	grueso: number, giro: number, color: Color3, material: Enum.Material): Part
	local p = P.cilindro(padre, nombre, Vector3.new(grueso, ancho, largo),
		CFrame.new(x, arriba - grueso / 2, z) * CFrame.Angles(0, giro, 0) * VERTICAL, color, material)
	p.CastShadow = false
	return p
end

-- Cuña: triángulo rectángulo con el ángulo recto en M y los catetos e y s (perpendiculares), de `grueso` centrada en M.
local function cuna(padre: Instance, nombre: string, M: Vector3, e: Vector3, s: Vector3, grueso: number, color: Color3,
	material: Enum.Material, choca: boolean?): WedgePart
	local Y, Z = s.Unit, -e.Unit
	return P.cuna(padre, nombre, Vector3.new(grueso, s.Magnitude, e.Magnitude), CFrame.fromMatrix(M + e / 2 + s / 2, Y:Cross(Z), Y, Z),
		color, material, choca)
end

-- La cara de `p` que mira más hacia `dir` (para las manchas de lo girado).
local function caraHacia(p: BasePart, dir: Vector3): Enum.NormalId
	local mejor, cara = -2, Enum.NormalId.Front
	for _, n in Enum.NormalId:GetEnumItems() do
		local d = p.CFrame:VectorToWorldSpace(Vector3.FromNormalId(n)):Dot(dir)
		if d > mejor then
			mejor, cara = d, n
		end
	end
	return cara
end

-- Un punto para colgar un cable: el eje del Attachment hacia abajo, para que el Beam cuelgue (CurveSize).
local function enganche(parte: BasePart, pos: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = "Cable"
	a.CFrame = parte.CFrame:ToObjectSpace(CFrame.fromMatrix(pos, Vector3.new(0, -1, 0), Vector3.new(1, 0, 0)))
	a.Parent = parte
	return a
end

-- Un cable de a0 a a1 que cuelga `comba` studs por el medio (un Beam: no es una pieza).
local function cable(padre: Instance, a0: Attachment, a1: Attachment, comba: number)
	local b = Instance.new("Beam")
	b.Name = "Cable"
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.CurveSize0 = comba / 0.75
	b.CurveSize1 = -comba / 0.75
	b.Width0 = 0.09
	b.Width1 = 0.09
	b.FaceCamera = true
	b.Segments = 12
	b.Color = ColorSequence.new(Color3.fromRGB(18, 18, 18))
	b.Transparency = NumberSequence.new(0)
	b.LightEmission = 0
	b.LightInfluence = 1
	b.Parent = padre
end

local function dentroDelClaro(x: number, z: number): boolean
	return x > CLARO.x0 and x < CLARO.x1 and z > CLARO.z0 and z < CLARO.z1
end

------------------------------------------------------------------------------------------------------------------------
-- La luz: noche cerrada, sin luna ni estrellas. Lo que se ve lo alumbran las luces de la gasolinera, las farolas y
-- los faros. Sin Atmosphere ni ColorCorrection: los pone el cliente (Clima).
local function noche()
	Lighting.ClockTime = 0.4
	Lighting.Brightness = 0.3 -- lo poco que pasa entre las nubes
	Lighting.Ambient = Color3.fromRGB(18, 19, 24)
	Lighting.OutdoorAmbient = Color3.fromRGB(28, 31, 40)
	Lighting.ColorShift_Top = Color3.new(0, 0, 0)
	Lighting.ColorShift_Bottom = Color3.new(0, 0, 0)
	Lighting.EnvironmentDiffuseScale = 0.1
	Lighting.EnvironmentSpecularScale = 0.25 -- algo de brillo en lo mojado, sin pasarse
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.35
	-- La niebla la pone el cliente (Atmosphere); esta solo cuenta si faltara.
	Lighting.FogColor = Color3.fromRGB(14, 15, 19)
	Lighting.FogStart = 20
	Lighting.FogEnd = 230
	local cielo = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	cielo.StarCount = 0
	cielo.CelestialBodiesShown = false
	cielo.Parent = Lighting
end

------------------------------------------------------------------------------------------------------------------------
-- El suelo: hierba (en trozos alrededor de las cunetas), cunetas con el fondo de barro y calvas de barro. Devuelve los
-- trozos de hierba (oeste, noreste, sureste, este) para colgar de ellos los puntos del bosque.
local function suelo(mapa: Folder): { BasePart }
	local f = Instance.new("Folder")
	f.Name = "Suelo"
	local function hierba(x0: number, x1: number, z0: number, z1: number): BasePart
		return fijo(P.bloque(f, "Hierba", Vector3.new(x1 - x0, 2, z1 - z0), CFrame.new((x0 + x1) / 2, -1, (z0 + z1) / 2), COLOR.Hierba,
			Enum.Material.LeafyGrass, true))
	end
	local trozos = {
		hierba(-LARGO, -FUERA, -LARGO, LARGO),
		hierba(FUERA, LARGO, -LARGO, -CORTE),
		hierba(FUERA, LARGO, CORTE, LARGO),
		hierba(6.5, LARGO, -CORTE, CORTE), -- debajo de la explanada y alrededor (ahí no hay cuneta)
	}
	-- Las cunetas: fondo de barro y los dos taludes.
	local function cuneta(lado: number, z0: number, z1: number)
		local zm, largo = (z0 + z1) / 2, z1 - z0
		fijo(P.bloque(f, "Cuneta", Vector3.new(FUERA - BORDE, 1, largo), CFrame.new((BORDE + FUERA) / 2 * lado, HONDO - 0.5, zm), COLOR.Barro,
			Enum.Material.Mud, true))
		local arriba = Vector3.new(0, -HONDO, 0)
		cuna(f, "Talud", Vector3.new(BORDE * lado, HONDO, zm), Vector3.new((FONDO0 - BORDE) * lado, 0, 0), arriba, largo, TALUD,
			Enum.Material.Ground, true)
		cuna(f, "Talud", Vector3.new(FUERA * lado, HONDO, zm), Vector3.new((FONDO1 - FUERA) * lado, 0, 0), arriba, largo, COLOR.Hierba,
			Enum.Material.LeafyGrass, true)
	end
	cuneta(-1, -LARGO, LARGO)
	cuneta(1, -LARGO, -CORTE)
	cuneta(1, CORTE, LARGO)
	-- Donde acaba la cuneta del este: un muro de hormigón con la boca del tubo que pasa por debajo de la entrada.
	local medio = (FONDO0 + FONDO1) / 2
	for _, s in { -1, 1 } do
		local cara = CORTE * s
		local muro = P.bloque(f, "Muro", Vector3.new(FUERA - BORDE + 0.4, 1.45, 0.5), CFrame.new((BORDE + FUERA) / 2, HONDO + 0.525, cara + 0.15 * s),
			COLOR.HormigonSucio, Enum.Material.Concrete, true)
		P.mancha(muro, if s < 0 then Enum.NormalId.Front else Enum.NormalId.Back, nil, Color3.fromRGB(30, 36, 26), 0.35)
		P.cilindro(f, "Tubo", Vector3.new(0.5, 1.3, 1.3), CFrame.new(medio, HONDO + 0.6, cara + 0.55 * s) * CFrame.Angles(0, math.pi / 2, 0),
			COLOR.HormigonSucio, Enum.Material.Concrete)
		P.cilindro(f, "Boca", Vector3.new(0.04, 1.0, 1.0), CFrame.new(medio, HONDO + 0.6, cara + 0.81 * s) * CFrame.Angles(0, math.pi / 2, 0),
			Color3.fromRGB(8, 8, 8), Enum.Material.SmoothPlastic)
	end
	-- Calvas de barro en la hierba, donde se ven: alrededor de la gasolinera y junto a la carretera. Y hojarasca de pino
	-- (más oscura) en el borde del bosque.
	local r = Random.new(5150)
	-- Los discos de una misma altura no se pueden pisar (parpadearían): se apunta lo que ocupa cada uno.
	local ocupados: { Vector3 } = {} -- x, radio, z
	local function cabe(x: number, z: number, radio: number): boolean
		for _, o in ocupados do
			if (o.X - x) ^ 2 + (o.Z - z) ^ 2 < (o.Y + radio) ^ 2 then
				return false
			end
		end
		table.insert(ocupados, Vector3.new(x, radio, z))
		return true
	end
	for _ = 1, 12 do
		local x = if r:NextNumber() < 0.5 then r:NextNumber(-40, -18) else r:NextNumber(82, 98)
		local z, ancho, largo = r:NextNumber(-70, 70), r:NextNumber(12, 22), r:NextNumber(10, 18)
		if cabe(x, z, math.max(ancho, largo) / 2) then
			disco(f, "Hojarasca", x, z, ancho, largo, 0.015, 0.015, r:NextNumber(0, math.pi), Color3.fromRGB(44, 40, 32), Enum.Material.Ground)
		end
	end
	table.clear(ocupados) -- el barro va más alto que la hojarasca: se pueden pisar
	local puestas, intentos = 0, 0
	while puestas < 22 and intentos < 600 do
		intentos += 1
		local x, z = r:NextNumber(-32, 96), r:NextNumber(-84, 84)
		local enHierba = x < -FUERA - 1 or (x > 16 and not (x < 74 and math.abs(z) < 41))
		local ancho, largo, giro = r:NextNumber(3, 8), r:NextNumber(2, 6), r:NextNumber(0, math.pi)
		if not enHierba or (x > 0 and x < 18 and math.abs(z) < 50) or not cabe(x, z, math.max(ancho, largo) / 2 + 0.5) then
			continue
		end
		disco(f, "Barro", x, z, ancho, largo, 0.04, 0.04, giro, COLOR.Barro, Enum.Material.Mud)
		if r:NextNumber() < 0.6 then -- el centro, más mojado
			disco(f, "Barro", x + r:NextNumber(-0.5, 0.5), z + r:NextNumber(-0.5, 0.5), ancho * 0.5, largo * 0.55, 0.07, 0.03, giro + 0.3,
				Color3.fromRGB(38, 33, 28), Enum.Material.Mud)
		end
		puestas += 1
	end
	f.Parent = mapa
	return trozos
end

------------------------------------------------------------------------------------------------------------------------
-- La carretera: asfalto viejo, arcén de grava y barro, baches con agua, parches, grietas, alquitrán y rayas gastadas.

-- Los baches con agua (x, z, ancho, largo, giro): fuera de las rayas.
local BACHES = {
	{ 3.3, -58, 2.6, 1.9, 0.3 },
	{ -3.6, -16, 2.1, 1.5, -0.5 },
	{ 4.4, 33, 2.4, 1.7, 1.1 },
	{ -2.6, 96, 1.9, 1.4, 0.2 },
	{ 2.9, -142, 2.3, 1.8, -0.9 },
}

local function lejosDeBaches(x: number, z: number): boolean
	for _, b in BACHES do
		if (b[1] - x) ^ 2 + (b[2] - z) ^ 2 < 3.5 ^ 2 then
			return false
		end
	end
	return true
end

local function carretera(mapa: Folder)
	local f = Instance.new("Folder")
	f.Name = "Carretera"
	local r = Random.new(3141)
	fijo(P.bloque(f, "Asfalto", Vector3.new(14, 1, LARGO * 2), CFrame.new(0, ASFALTO - 0.5, 0), COLOR.Asfalto, Enum.Material.Asphalt, true))
	for _, t in { { -1, -LARGO, LARGO }, { 1, -LARGO, -40 }, { 1, 40, LARGO } } do
		fijo(P.bloque(f, "Arcen", Vector3.new(BORDE - 7, 1, t[3] - t[2]), CFrame.new((7 + BORDE) / 2 * t[1], ARCEN - 0.5, (t[2] + t[3]) / 2),
			GRAVA, Enum.Material.Pebble, true))
	end

	-- Baches: el agua (Charco: la lluvia salpica en ella) con el borde del asfalto roto alrededor.
	for _, b in BACHES do
		local x, z, ancho, largo, giro = b[1], b[2], b[3], b[4], b[5]
		local sitio = CFrame.new(x, ASFALTO, z) * CFrame.Angles(0, giro, 0)
		local agua = plano(f, "Charco", Vector3.new(ancho, GRIETA - ASFALTO, largo), sitio * CFrame.new(0, (GRIETA - ASFALTO) / 2, 0),
			COLOR.Agua, Enum.Material.SmoothPlastic)
		P.etiqueta(agua, "Charco")
		for k = 1, 5 do
			local a = k / 5 * math.pi * 2 + r:NextNumber(-0.3, 0.3)
			local borde = sitio:PointToWorldSpace(Vector3.new(ancho / 2 * math.cos(a), 0, largo / 2 * math.sin(a)))
			local tangente = sitio:VectorToWorldSpace(Vector3.new(-ancho * math.sin(a), 0, largo * math.cos(a))).Unit
			local alto = r:NextNumber(0.09, 0.13) -- lo de arriba, bien por encima del agua (que no parpadee)
			local centro = borde + Vector3.new(0, alto / 2 - 0.02, 0)
			plano(f, "Desconchon", Vector3.new(r:NextNumber(0.25, 0.45), alto, r:NextNumber(0.5, 0.9)),
				CFrame.lookAt(centro, centro + tangente) * CFrame.Angles(r:NextNumber(-0.12, 0.12), 0, r:NextNumber(-0.2, 0.2)),
				Color3.fromRGB(30, 30, 31), Enum.Material.Asphalt)
		end
	end

	-- Parches de asfalto más nuevo o más gastado, en un carril (no tapan las rayas ni se pisan entre ellos).
	local parches: { { number } } = {}
	for _ = 1, 12 do
		local z = r:NextNumber(-260, 160)
		local ancho, largo = r:NextNumber(2, 4.8), r:NextNumber(3, 9)
		local lado = if r:NextNumber() < 0.5 then -1 else 1
		local x = lado * r:NextNumber(0.6 + ancho / 2, 6.1 - ancho / 2)
		local tono = r:NextInteger(-8, 10)
		local pisa = false
		for _, o in parches do
			if math.abs(o[1] - x) < (o[3] + ancho) / 2 + 0.2 and math.abs(o[2] - z) < (o[4] + largo) / 2 + 0.2 then
				pisa = true
			end
		end
		if not pisa then
			table.insert(parches, { x, z, ancho, largo })
			fijo(plano(f, "Parche", Vector3.new(ancho, PARCHE - ASFALTO, largo), CFrame.new(x, (ASFALTO + PARCHE) / 2, z),
				Color3.fromRGB(38 + tono, 38 + tono, 40 + tono), Enum.Material.Asphalt))
		end
	end

	-- Grietas en zigzag y el alquitrán con que las taparon (negro, brilla un poco mojado).
	local function grieta(desde: Vector3, rumbo: number, tramos: number, ancho: number, arriba: number, quiebro: number,
		color: Color3, material: Enum.Material, nombre: string)
		local pos = desde
		for _ = 1, tramos do
			local largo = r:NextNumber(1.2, 3.4)
			rumbo += r:NextNumber(-quiebro, quiebro)
			local fin = pos + Vector3.new(math.cos(rumbo), 0, math.sin(rumbo)) * largo
			if math.abs(fin.X) > 6.85 or not lejosDeBaches(fin.X, fin.Z) then
				break
			end
			local y = (ASFALTO + arriba) / 2
			local a, b = Vector3.new(pos.X, y, pos.Z), Vector3.new(fin.X, y, fin.Z)
			plano(f, nombre, Vector3.new(ancho, arriba - ASFALTO, largo + 0.08), CFrame.lookAt((a + b) / 2, b), color, material)
			pos = fin
		end
	end
	local function cerca(): number -- más cosas junto a la gasolinera y por donde se va el coche
		return if r:NextNumber() < 0.65 then r:NextNumber(-120, 90) else r:NextNumber(-260, 160)
	end
	for _ = 1, 16 do
		local x, z = r:NextNumber(-6.5, 6.5), cerca()
		if lejosDeBaches(x, z) then
			grieta(Vector3.new(x, 0, z), r:NextNumber(0, math.pi * 2), r:NextInteger(3, 6), r:NextNumber(0.12, 0.24), GRIETA, 0.7,
				Color3.fromRGB(22, 22, 23), Enum.Material.Asphalt, "Grieta")
		end
	end
	-- Piel de cocodrilo junto al borde oeste, enfrente de la gasolinera.
	for _ = 1, 4 do
		local x, z = r:NextNumber(-6.4, -4.6), r:NextNumber(62, 72)
		grieta(Vector3.new(x, 0, z), r:NextNumber(0, math.pi * 2), 3, 0.12, GRIETA, 1.2, Color3.fromRGB(22, 22, 23), Enum.Material.Asphalt,
			"Grieta")
	end
	for _ = 1, 8 do
		local x = if r:NextNumber() < 0.6 then r:NextNumber(-0.9, 0.9) else r:NextNumber(5.6, 6.3) * (if r:NextNumber() < 0.5 then -1 else 1)
		local z = cerca()
		if lejosDeBaches(x, z) then
			grieta(Vector3.new(x, 0, z), math.pi / 2 * (if r:NextNumber() < 0.5 then -1 else 1), r:NextInteger(4, 7), r:NextNumber(0.18, 0.3),
				ALQUITRAN, 0.35, Color3.fromRGB(15, 15, 15), Enum.Material.SmoothPlastic, "Alquitran")
		end
	end

	-- Las rayas: pintura gastada (más o menos), con algún trozo borrado.
	local function raya(x: number, z0: number, z1: number, ancho: number)
		local c = COLOR.Asfalto:Lerp(COLOR.Linea, r:NextNumber(0.55, 1))
		fijo(plano(f, "Raya", Vector3.new(ancho, RAYA - ASFALTO, z1 - z0), CFrame.new(x, (ASFALTO + RAYA) / 2, (z0 + z1) / 2), c,
			Enum.Material.Asphalt))
	end
	local z = -LARGO + 3
	while z + 7 < LARGO do -- la discontinua del centro: 7 de raya y 11 de hueco
		local k = r:NextNumber()
		if k < 0.1 then
			local trozo = r:NextNumber(1.5, 3.5)
			local a = z + r:NextNumber(0, 7 - trozo)
			raya(0, a, a + trozo, 0.35)
		elseif k < 0.28 then
			local corte = r:NextNumber(2, 5)
			raya(0, z, z + corte - 0.5, 0.35)
			raya(0, z + corte + 0.4, z + 7, 0.35)
		else
			raya(0, z, z + 7, 0.35)
		end
		z += 18
	end
	for _, lado in { -1, 1 } do -- las de los bordes; la del este se corta en la entrada de la gasolinera
		z = -LARGO + 2
		while z < LARGO - 2 do
			local junto = math.abs(z) < 170
			local fin = math.min(z + (if junto then r:NextNumber(8, 26) else r:NextNumber(30, 70)), LARGO - 2)
			if lado > 0 and fin > -42 and z < 42 then
				if z < -42 then
					raya(6.55, z, -42, 0.3)
				end
				z = 42
				continue
			end
			raya(6.55 * lado, z, fin, 0.3)
			z = fin + (if junto then r:NextNumber(0.6, 4) else r:NextNumber(1, 3))
		end
	end

	-- El borde del asfalto, desconchado sobre la grava (por fuera de las rayas y las grietas).
	for _ = 1, 12 do
		local lado = if r:NextNumber() < 0.5 then -1 else 1
		local zz = r:NextNumber(-150, 150)
		if lado > 0 and math.abs(zz) < 42 then
			zz += 90 * (if zz < 0 then -1 else 1)
		end
		plano(f, "Desconchon", Vector3.new(r:NextNumber(0.3, 0.6), 0.08, r:NextNumber(0.4, 1.2)),
			CFrame.new(r:NextNumber(7.1, 7.3) * lado, 0.195, zz) * CFrame.Angles(r:NextNumber(-0.06, 0.06), r:NextNumber(-0.4, 0.4), r:NextNumber(-0.06, 0.06)),
			COLOR.Asfalto, Enum.Material.Asphalt)
	end

	-- Charcos en el arcén y en el fondo de las cunetas (uno, delante del tubo del norte).
	for _, c in { { -8.3, -34, 1.7, 3.2 }, { 8.4, 58, 1.5, 2.6 }, { -8.1, 72, 1.8, 4.0 } } do
		P.etiqueta(fijo(plano(f, "Charco", Vector3.new(c[3], 0.04, c[4]), CFrame.new(c[1], ARCEN + 0.02, c[2]), COLOR.Agua,
			Enum.Material.SmoothPlastic)), "Charco")
	end
	local medio = (FONDO0 + FONDO1) / 2
	for _, c in { { -1, -70, 12 }, { -1, -22, 9 }, { -1, 26, 14 }, { -1, 88, 10 }, { 1, -55, 11 }, { 1, 66, 12 } } do
		P.etiqueta(fijo(plano(f, "Charco", Vector3.new(FONDO1 - FONDO0 - 0.1, 0.05, c[3]), CFrame.new(medio * c[1], HONDO + 0.025, c[2]),
			COLOR.Agua, Enum.Material.SmoothPlastic)), "Charco")
	end

	-- Algo pasó aquí, por donde se va el coche: una mancha oscura en el carril, el arrastre hasta la cuneta y una
	-- zapatilla en el arcén.
	local function sangre(pos: Vector3, ancho: number, largo: number, hacia: Vector3, transparencia: number)
		local soporte = plano(f, "Mancha", Vector3.new(ancho, 0.02, largo), CFrame.lookAt(pos, pos + hacia), SANGRE)
		soporte.Transparency = 1
		P.mancha(soporte, Enum.NormalId.Top, nil, SANGRE, transparencia)
	end
	local arrastre = Vector3.new(1, 0, -0.55).Unit
	sangre(Vector3.new(4.2, MANCHA - 0.01, -171), 2.6, 3.2, Vector3.new(0.4, 0, 1), 0.15)
	sangre(Vector3.new(5.9, MANCHA - 0.01, -172.2), 1.1, 3.4, arrastre, 0.35)
	sangre(Vector3.new(8.2, ARCEN + 0.03, -173.5), 0.9, 2.6, arrastre, 0.45)
	local zapatilla = CFrame.new(8.6, ARCEN + 0.2, -177.4) * CFrame.Angles(0, 1.1, math.rad(78))
	plano(f, "Zapatilla", Vector3.new(0.42, 0.12, 1.05), zapatilla, Color3.fromRGB(120, 116, 106), Enum.Material.Rubber)
	plano(f, "Zapatilla", Vector3.new(0.38, 0.34, 0.75), zapatilla * CFrame.new(0, 0.22, 0.12), Color3.fromRGB(58, 60, 66), Enum.Material.Fabric)

	-- Basura en el arcén y la cuneta.
	local function lata(x: number, y: number, zz: number, giro: number, color: Color3, aplastada: boolean)
		P.cilindro(f, "Lata", Vector3.new(0.4, if aplastada then 0.12 else 0.22, 0.22), CFrame.new(x, y + (if aplastada then 0.06 else 0.11), zz)
			* CFrame.Angles(0, giro, 0), color, Enum.Material.Metal).CastShadow = false
	end
	lata(-8.4, ARCEN, 12, 0.4, Color3.fromRGB(98, 34, 30), false)
	lata(8.6, ARCEN, -55, 2.1, Color3.fromRGB(110, 112, 110), true)
	lata(-medio + 0.2, HONDO + 0.05, 27, 1.3, Color3.fromRGB(40, 60, 90), false)
	local botella = CFrame.new(-8.9, ARCEN + 0.14, -31) * CFrame.Angles(0, 0.7, 0)
	for _, b in { { Vector3.new(0.8, 0.28, 0.28), 0 }, { Vector3.new(0.32, 0.12, 0.12), 0.55 } } do
		local p = P.cilindro(f, "Botella", b[1], botella * CFrame.new(b[2], 0, 0), Color3.fromRGB(50, 70, 50), Enum.Material.SmoothPlastic)
		p.Transparency = 0.4
		p.CastShadow = false
	end
	P.bola(f, "Bolsa", Vector3.new(0.9, 0.3, 0.7), CFrame.new(8.2, ARCEN + 0.1, 63) * CFrame.Angles(0, 0.9, 0.1), Color3.fromRGB(118, 118, 112),
		Enum.Material.SmoothPlastic).CastShadow = false
	plano(f, "Caja", Vector3.new(1.2, 0.7, 0.9), CFrame.new(-8.6, ARCEN + 0.3, 44) * CFrame.Angles(0.15, 0.6, -0.25), Color3.fromRGB(92, 78, 58),
		Enum.Material.Cardboard)
	f.Parent = mapa
end

------------------------------------------------------------------------------------------------------------------------
-- La orilla: quitamiedos, postes de la luz con sus cables, la señal doblada, el hito del kilómetro, los hitos de los
-- bordes y una cruz con flores secas.

-- Zonas de la orilla ya ocupadas (lado, z0, z1), para que los hitos no caigan encima.
local OCUPADO = {
	{ -1, -137, -93 }, -- quitamiedos oeste
	{ 1, 93, 139 }, -- quitamiedos este
	{ -1, -66, -50 }, -- cruz y farola
	{ -1, 26, 34 }, -- hito del kilómetro
	{ -1, 48, 56 }, -- farola
	{ 1, -82, -74 }, -- señal
	{ 1, -126, -118 }, -- farola muerta
	{ 1, -180, -168 }, -- la mancha y la zapatilla
}

local function ocupado(lado: number, z: number): boolean
	for _, o in OCUPADO do
		if o[1] == lado and z > o[2] and z < o[3] then
			return true
		end
	end
	return false
end

-- Un quitamiedos de z0 a z1 en el arcén (lado -1 oeste, 1 este), con un tramo hundido de un golpe en `golpe`.
local function quitamiedos(f: Folder, lado: number, z0: number, z1: number, golpe: number, r: Random)
	local xp, xb = 9.1 * lado, 8.8 * lado -- postes por fuera; la bionda, del lado de la carretera
	local paso = 6
	local n = math.floor((z1 - z0) / paso + 0.5)
	local puntos = {}
	for i = 0, n do
		local hundido = if i == golpe then 0.75 else 0
		puntos[i] = Vector3.new(xb + hundido * lado, 1.62 - hundido * 0.4, z0 + i * paso)
		local inclinado = if i == golpe then 0.38 else r:NextNumber(-0.05, 0.05)
		local pie = CFrame.new(xp + hundido * lado, ARCEN, z0 + i * paso) * CFrame.Angles(r:NextNumber(-0.04, 0.04), 0, -inclinado * lado)
		P.bloque(f, "Poste", Vector3.new(0.3, 2.2, 0.3), pie * CFrame.new(0, 0.85, 0), Color3.fromRGB(58, 58, 56), Enum.Material.CorrodedMetal, true)
	end
	local haciaCarretera = Vector3.new(-lado, 0, 0)
	for i = 0, n - 1 do
		local a, b = puntos[i], puntos[i + 1]
		local retorcido = if i == golpe or i + 1 == golpe then 0.22 else r:NextNumber(-0.03, 0.03)
		local bionda = P.bloque(f, "Bionda", Vector3.new(0.12, 0.85, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, 0, retorcido),
			GALVANIZADO, Enum.Material.Metal, true)
		if r:NextNumber() < 0.5 then
			P.mancha(bionda, caraHacia(bionda, haciaCarretera), nil, OXIDO, 0.3)
		end
	end
	-- Los extremos se meten en la tierra.
	for _, e in { { puntos[0], -1 }, { puntos[n], 1 } } do
		local a = e[1]
		local b = Vector3.new(a.X + 0.35 * lado, ARCEN + 0.1, a.Z + 3.2 * e[2])
		P.bloque(f, "Bionda", Vector3.new(0.12, 0.85, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), GALVANIZADO, Enum.Material.Metal, true)
	end
end

-- Los postes de la luz, de madera, al otro lado de la carretera, con tres cables que cuelgan entre poste y poste. Uno
-- echado hacia la carretera; de otro cuelga un cable roto hasta la cuneta. Del de enfrente de la gasolinera salen dos
-- cables por encima de la marquesina hasta un poste detrás de la tienda.
local function postes(f: Folder, r: Random)
	local anteriores: { Attachment }? = nil
	for i = -7, 7 do
		local z = i * 50 + 12
		local cerca = math.abs(z) < 170
		local inclinado = if i == 3 then CFrame.Angles(0.02, 0, -0.1) else CFrame.Angles(r:NextNumber(-0.025, 0.025), 0, r:NextNumber(-0.035, 0.035))
		local base = CFrame.new(POSTES_X, 0, z) * inclinado
		P.cilindro(f, "Poste", Vector3.new(30.4, 0.85, 0.85), base * CFrame.new(0, 14.8, 0) * VERTICAL, MADERA, Enum.Material.Wood, true)
		local cruceta = P.bloque(f, "Cruceta", Vector3.new(6.4, 0.4, 0.45), base * CFrame.new(0, 27.6, 0), MADERA, Enum.Material.Wood)
		local puntos = {}
		for k, sitio in { Vector3.new(-2.8, 27.8, 0), Vector3.new(0, 30.0, 0), Vector3.new(2.8, 27.8, 0) } do
			if cerca then
				P.cilindro(f, "Aislador", Vector3.new(0.5, 0.3, 0.3), base * CFrame.new(sitio + Vector3.new(0, 0.25, 0)) * VERTICAL,
					Color3.fromRGB(138, 134, 122), Enum.Material.SmoothPlastic)
			end
			puntos[k] = enganche(cruceta, (base * CFrame.new(sitio + Vector3.new(0, 0.5, 0))).Position)
		end
		if cerca then
			P.bloque(f, "Riostra", Vector3.new(0.18, 2.5, 0.18), base * CFrame.new(-0.9, 26.5, 0) * CFrame.Angles(0, 0, math.rad(45)), MADERA,
				Enum.Material.Wood)
		end
		if anteriores then
			for k = 1, 3 do
				cable(f, anteriores[k], puntos[k], r:NextNumber(1.8, 2.6))
			end
		end
		anteriores = puntos
		if i == 2 then -- el cable roto, colgando hasta el fondo de la cuneta
			cable(f, puntos[3], enganche(cruceta, Vector3.new(-12.4, HONDO + 0.05, z - 7)), 1.2)
		elseif i == -1 then
			-- A la gasolinera: otra cruceta (a lo largo de la carretera) y los dos cables hasta el poste de detrás de la tienda.
			local otra = P.bloque(f, "Cruceta", Vector3.new(0.4, 0.4, 3.6), base * CFrame.new(0, 24.6, 0), MADERA, Enum.Material.Wood)
			local alla = CFrame.new(78, 0, -24) * CFrame.Angles(0.02, 0, 0.03)
			P.cilindro(f, "Poste", Vector3.new(24.4, 0.75, 0.75), alla * CFrame.new(0, 11.8, 0) * VERTICAL, MADERA, Enum.Material.Wood, true)
			local llega = P.bloque(f, "Cruceta", Vector3.new(0.4, 0.4, 3.6), alla * CFrame.new(0, 21.6, 0), MADERA, Enum.Material.Wood)
			local caja = P.cilindro(f, "Transformador", Vector3.new(1.8, 1.2, 1.2), alla * CFrame.new(-0.85, 19.2, 0) * VERTICAL,
				Color3.fromRGB(70, 72, 72), Enum.Material.CorrodedMetal)
			for _, dz in { -1.5, 1.5 } do
				cable(f, enganche(otra, (base * CFrame.new(0, 25.1, dz)).Position), enganche(llega, (alla * CFrame.new(0, 22.1, dz)).Position), 4)
			end
			-- Y el que baja a la esquina de la tienda (de x 52 a 70, z -14 a 14, paredes de 11).
			cable(f, enganche(caja, (alla * CFrame.new(-0.85, 20.2, 0)).Position), enganche(caja, Vector3.new(70.3, 10.6, -14.3)), 1)
		end
	end
end

-- La señal de 50, con el poste doblado (de un golpe), para los que van hacia el bosque (mira a +Z).
local function senal(f: Folder)
	local pie = CFrame.new(8.7, ARCEN, -78)
	local metal = Color3.fromRGB(80, 80, 78)
	P.bloque(f, "Poste", Vector3.new(0.16, 3.5, 0.16), pie * CFrame.new(0, 1.45, 0), metal, Enum.Material.CorrodedMetal, true)
	local doblez = pie * CFrame.new(0, 3.2, 0) * CFrame.Angles(math.rad(-24), 0, math.rad(9))
	P.bloque(f, "Poste", Vector3.new(0.16, 2.3, 0.16), doblez * CFrame.new(0, 1.1, 0), metal, Enum.Material.CorrodedMetal)
	local placa = doblez * CFrame.new(0, 2.25, 0.1) * CFrame.Angles(0, math.rad(15), 0) * CFrame.Angles(0, -math.pi / 2, 0)
	local aro = P.cilindro(f, "Senal", Vector3.new(0.06, 2.2, 2.2), placa, Color3.fromRGB(110, 30, 26), Enum.Material.SmoothPlastic)
	P.mancha(aro, Enum.NormalId.Left, nil, Color3.fromRGB(40, 36, 30), 0.3)
	local blanco = P.cilindro(f, "Senal", Vector3.new(0.04, 1.7, 1.7), placa * CFrame.new(0.05, 0, 0), Color3.fromRGB(156, 152, 142),
		Enum.Material.SmoothPlastic)
	P.letrero(blanco, Enum.NormalId.Right, "50", Color3.fromRGB(26, 24, 22), Enum.Font.Arial)
	P.mancha(blanco, Enum.NormalId.Right, nil, Color3.fromRGB(46, 40, 30), 0.5)
end

-- Los hitos de los bordes: postes blancos y sucios con una banda negra y el reflectante (apagado: de noche solo
-- brilla con los faros). Alguno torcido y alguno tirado en la cuneta.
local function hitos(f: Folder, r: Random)
	local blanco, negro, ambar = Color3.fromRGB(150, 146, 136), Color3.fromRGB(24, 24, 24), Color3.fromRGB(104, 66, 22)
	for _, lado in { -1, 1 } do
		for z = -180, 180, 36 do
			local zz = z + (if lado > 0 then 18 else 0) -- al tresbolillo
			if (lado > 0 and math.abs(zz) < 46) or ocupado(lado, zz) then
				continue
			end
			local estado = r:NextNumber()
			local base
			if estado < 0.12 then -- tirado en la cuneta
				base = CFrame.new((FONDO0 + 0.2) * lado, HONDO + 0.17, zz + r:NextNumber(-1, 1)) * CFrame.Angles(0, r:NextNumber(0, math.pi), math.pi / 2)
					* CFrame.new(0, -1.0, 0)
			else
				local inclinado = if estado < 0.3 then r:NextNumber(0.15, 0.35) else r:NextNumber(-0.04, 0.04)
				base = CFrame.new(8.9 * lado, ARCEN, zz) * CFrame.Angles(0, if lado > 0 then 0 else math.pi, 0)
					* CFrame.Angles(inclinado * (if r:NextNumber() < 0.5 then -1 else 1), 0, r:NextNumber(-0.05, 0.05))
			end
			-- Algo torcidos: Separar los vería pegados (la banda va 0,04 por fuera del poste).
			fijo(P.bloque(f, "Hito", Vector3.new(0.32, 2.4, 0.32), base * CFrame.new(0, 1.0, 0), blanco, Enum.Material.SmoothPlastic))
			fijo(plano(f, "Hito", Vector3.new(0.4, 0.45, 0.4), base * CFrame.new(0, 1.85, 0), negro, Enum.Material.SmoothPlastic))
			fijo(plano(f, "Reflectante", Vector3.new(0.18, 0.3, 0.04), base * CFrame.new(0, 1.85, 0.215), ambar, Enum.Material.SmoothPlastic))
		end
	end
end

-- La cruz de madera de alguien que se mató aquí, con flores secas, una vela apagada en un tarro y una foto.
local function cruz(f: Folder)
	local base = CFrame.new(-9.15, ARCEN, -62) * CFrame.Angles(0, math.rad(80), math.rad(4))
	local madera = Color3.fromRGB(118, 112, 102)
	P.bloque(f, "Cruz", Vector3.new(0.24, 2.7, 0.14), base * CFrame.new(0, 1.15, 0), madera, Enum.Material.Wood)
	plano(f, "Cruz", Vector3.new(1.3, 0.22, 0.14), base * CFrame.new(0, 1.85, 0), madera, Enum.Material.Wood)
	plano(f, "Foto", Vector3.new(0.4, 0.5, 0.03), base * CFrame.new(0, 1.35, 0.085), Color3.fromRGB(70, 66, 60), Enum.Material.SmoothPlastic)
	for _, flor in {
		{ -0.35, 0.25, 0.35, Color3.fromRGB(78, 26, 28) },
		{ -0.05, 0.2, 0.3, Color3.fromRGB(96, 82, 52) },
		{ 0.25, 0.22, 0.32, Color3.fromRGB(64, 30, 40) },
		{ -0.2, 0.32, 0.25, Color3.fromRGB(70, 74, 50) },
	} do
		local tam = flor[3]
		P.bola(f, "Flor", Vector3.one * tam, base * CFrame.new(flor[1], tam / 2 - 0.02, flor[2]), flor[4], Enum.Material.Fabric)
	end
	local tarro = P.cilindro(f, "Vela", Vector3.new(0.4, 0.3, 0.3), base * CFrame.new(0.5, 0.2, 0.32) * VERTICAL, Color3.fromRGB(130, 110, 90),
		Enum.Material.SmoothPlastic)
	tarro.Transparency = 0.45
end

local function orilla(mapa: Folder)
	local f = Instance.new("Folder")
	f.Name = "Orilla"
	local r = Random.new(808)
	quitamiedos(f, -1, -135, -95, 3, r)
	quitamiedos(f, 1, 95, 137, 4, r)
	postes(f, r)
	senal(f)
	-- El hito del kilómetro, mirando a la carretera.
	local km = P.bloque(f, "Kilometro", Vector3.new(0.3, 1.7, 0.65), CFrame.new(-8.95, ARCEN + 0.6, 30) * CFrame.Angles(0, 0, -0.06),
		Color3.fromRGB(146, 142, 132), Enum.Material.Concrete, true)
	P.letrero(km, Enum.NormalId.Right, "12", Color3.fromRGB(30, 28, 26))
	plano(f, "Kilometro", Vector3.new(0.38, 0.4, 0.73), km.CFrame * CFrame.new(0, 0.85, 0), Color3.fromRGB(104, 34, 28), Enum.Material.Concrete)
	hitos(f, r)
	cruz(f)
	f.Parent = mapa
end

------------------------------------------------------------------------------------------------------------------------
-- Las farolas: de chapa vieja con el brazo sobre la carretera. Una bien (con polillas y sombras), una que falla mucho
-- y una muerta, con el cristal roto en el suelo.
local function farola(f: Folder, x: number, z: number, estado: string)
	local lado = if x < 0 then 1 else -1 -- hacia la carretera
	local base = CFrame.new(x, ARCEN, z) * CFrame.Angles(0, if lado > 0 then 0 else math.pi, 0) -- su +x mira a la carretera
	local chapa = Color3.fromRGB(76, 78, 78)
	P.bloque(f, "Zocalo", Vector3.new(1.3, 0.9, 1.3), base * CFrame.new(0, 0.3, 0), COLOR.HormigonSucio, Enum.Material.Concrete, true)
	local pie = P.cilindro(f, "Farola", Vector3.new(7.4, 0.7, 0.7), base * CFrame.new(0, 4.45, 0) * VERTICAL, chapa, Enum.Material.CorrodedMetal, true)
	P.mancha(pie, Enum.NormalId.Top, nil, OXIDO, 0.4)
	plano(f, "Registro", Vector3.new(0.05, 0.8, 0.3), base * CFrame.new(-0.36, 1.9, 0), Color3.fromRGB(60, 60, 58), Enum.Material.Metal)
	P.cilindro(f, "Farola", Vector3.new(12.5, 0.5, 0.5), base * CFrame.new(0, 14.35, 0) * VERTICAL, chapa, Enum.Material.Metal, true)
	local codo = base * CFrame.new(0, 20.3, 0) * CFrame.Angles(0, 0, math.rad(7))
	P.bloque(f, "Brazo", Vector3.new(5.6, 0.28, 0.28), codo * CFrame.new(2.75, 0, 0), chapa, Enum.Material.Metal)
	local muerta = estado == "muerta"
	local cabeza = codo * CFrame.new(6.3, -0.05, 0) * (if muerta then CFrame.Angles(0.1, 0, math.rad(-14)) else CFrame.identity)
	P.bloque(f, "Cabeza", Vector3.new(2.5, 0.5, 1.05), cabeza, Color3.fromRGB(70, 72, 72), Enum.Material.Metal)
	if muerta then
		-- Media tapa de cristal; la otra mitad, un agujero negro y los trozos en la carretera.
		plano(f, "Cristal", Vector3.new(0.95, 0.12, 0.78), cabeza * CFrame.new(-0.4, -0.3, 0), Color3.fromRGB(46, 46, 44), Enum.Material.SmoothPlastic)
		plano(f, "Roto", Vector3.new(0.95, 0.06, 0.74), cabeza * CFrame.new(0.55, -0.27, 0), Color3.fromRGB(8, 8, 8), Enum.Material.SmoothPlastic)
		local debajo = (cabeza * CFrame.new(0.5, 0, 0)).Position
		local r = Random.new(17)
		for _ = 1, 4 do
			local trozo = Instance.new("WedgePart")
			trozo.Name = "Cristal"
			trozo.Anchored = true
			trozo.CanCollide = false
			trozo.CanQuery = false
			trozo.CanTouch = false
			trozo.CastShadow = false
			trozo.Size = Vector3.new(0.03, r:NextNumber(0.2, 0.5), r:NextNumber(0.2, 0.5))
			trozo.CFrame = CFrame.new(debajo.X + r:NextNumber(-1.2, 1.2), ASFALTO + 0.065, debajo.Z + r:NextNumber(-1.2, 1.2))
				* CFrame.Angles(0, r:NextNumber(0, math.pi * 2), math.pi / 2)
			trozo.Color = COLOR.Cristal
			trozo.Material = Enum.Material.SmoothPlastic
			trozo.Transparency = 0.4
			trozo.Parent = f
		end
		return
	end
	local cristal = plano(f, "Cristal", Vector3.new(1.9, 0.12, 0.78), cabeza * CFrame.new(0.1, -0.3, 0), Color3.fromRGB(214, 160, 98),
		Enum.Material.SmoothPlastic)
	local bien = estado == "bien"
	local luz = P.luz(cristal, "SpotLight", 1.2, 28, SODIO, bien) :: SpotLight -- solo la buena hace sombras
	luz.Face = Enum.NormalId.Bottom
	luz.Angle = 115
	P.etiqueta(cristal, "LuzFalla", { Fallo = if bien then 0.05 else 0.5, Zumba = false })
	if bien then
		P.etiqueta(cristal, "Polillas")
	end
end

local function farolas(mapa: Folder)
	local f = Instance.new("Folder")
	f.Name = "Farolas"
	farola(f, -9.0, -54, "bien")
	farola(f, -9.0, 52, "falla")
	farola(f, 9.0, -122, "muerta")
	f.Parent = mapa
end

------------------------------------------------------------------------------------------------------------------------
-- El bosque: pinos de Blender sobre su tronco (invisible, es lo que choca), más espesos junto a la carretera para que
-- se pierda entre los árboles y la niebla, y alrededor del claro de la gasolinera. Sotobosque donde se ve: helechos,
-- arbustos, rocas y troncos caídos (estos con su caja invisible para chocar). Devuelve los troncos (x, radio, z).

local function prohibido(x: number, z: number): boolean
	return math.abs(x) < CALLE or dentroDelClaro(x, z)
end

local function bosque(mapa: Folder): { Vector3 }
	local f = Instance.new("Folder")
	f.Name = "Bosque"
	local r = Random.new(4611)
	local troncos: { Vector3 } = {}
	local rejilla: { [number]: { Vector3 } } = {}
	local CELDA = 10
	local function hay(x: number, z: number, d: number): boolean -- algún tronco a menos de d
		local cx, cz, n = math.floor(x / CELDA), math.floor(z / CELDA), math.ceil(d / CELDA)
		for i = cx - n, cx + n do
			for j = cz - n, cz + n do
				for _, t in rejilla[i * 1000 + j] or {} do
					if (t.X - x) ^ 2 + (t.Z - z) ^ 2 < d * d then
						return true
					end
				end
			end
		end
		return false
	end
	local function apuntar(x: number, z: number, radio: number)
		local k = math.floor(x / CELDA) * 1000 + math.floor(z / CELDA)
		local t = Vector3.new(x, radio, z)
		rejilla[k] = rejilla[k] or {}
		table.insert(rejilla[k], t)
		table.insert(troncos, t)
	end
	-- Los postes de la luz también ocupan su sitio (que no les salga un pino pegado).
	local sitiosPostes = {}
	for i = -7, 7 do
		table.insert(sitiosPostes, Vector2.new(POSTES_X, i * 50 + 12))
	end
	local function libre(x: number, z: number, d: number): boolean
		if prohibido(x, z) or hay(x, z, d) then
			return false
		end
		for _, p in sitiosPostes do
			if (p.X - x) ^ 2 + (p.Y - z) ^ 2 < 16 then
				return false
			end
		end
		return true
	end
	local function pino(nombre: string, x: number, z: number, alto: number, grueso: number, inclinacion: number)
		local giro = CFrame.new(x, if inclinacion ~= 0 then -0.6 else 0, z) * CFrame.Angles(0, 0, inclinacion)
		local tronco = P.cilindro(f, "Tronco", Vector3.new(alto, grueso, grueso), giro * CFrame.new(0, alto / 2, 0) * VERTICAL, TRONCO,
			Enum.Material.Wood, true)
		local h = alto / 60
		local partes = Piezas.poner(tronco, nombre, giro * CFrame.Angles(0, r:NextNumber(0, math.pi * 2), 0), Vector3.one * h,
			{ Bark = Vector3.new(grueso / 2, h, grueso / 2) })
		if #partes > 0 then
			tronco.Transparency = 1
			tronco.CastShadow = false
			-- Sombra solo los de cerca de la gasolinera (lo que alumbran sus luces): pesa en móvil.
			local sombra = (Vector3.new(x, 0, z) - CENTRO).Magnitude < 95 or math.abs(x) < 30 and math.abs(z) < 80
			for _, p in partes do
				p.CastShadow = sombra
			end
		end
		apuntar(x, z, grueso / 2)
	end
	-- Dos pinos secos echados: uno hacia la carretera y otro hacia la tienda.
	pino("PinoSeco", -19, -95, 52, 2.6, -0.3)
	pino("PinoSeco", 85, 38, 48, 2.4, 0.22)
	local ZONAS = { -- x0, x1, z0, z1, separación, cuántos
		{ -36, -16, -LARGO, LARGO, 8.5, 105 }, -- pegados a la carretera, al oeste
		{ 16, 36, -LARGO, LARGO, 8.5, 95 }, -- y al este (sin el claro)
		{ 80, 104, -80, 80, 9, 40 }, -- detrás de la gasolinera
		{ 36, 80, -78, -50, 9, 22 }, -- al norte
		{ 36, 80, 50, 78, 9, 22 }, -- al sur
		{ -125, -36, -LARGO, LARGO, 19, 85 }, -- más adentro, más claros
		{ 36, 125, -LARGO, LARGO, 19, 70 },
	}
	for _, zona in ZONAS do
		local puestos, intentos = 0, 0
		while puestos < zona[6] and intentos < zona[6] * 30 do
			intentos += 1
			local x, z = r:NextNumber(zona[1], zona[2]), r:NextNumber(zona[3], zona[4])
			if not libre(x, z, zona[5]) then
				continue
			end
			local cual = r:NextNumber()
			local nombre, alto
			if math.abs(x) < 24 then -- la primera fila: de copa estrecha, que no tape la carretera
				nombre, alto = if cual < 0.2 then "PinoSeco" else "PinoB", r:NextNumber(42, 60)
			else
				nombre, alto = if cual < 0.12 then "PinoSeco" elseif cual < 0.55 then "PinoB" else "Pino", r:NextNumber(40, 70)
			end
			pino(nombre, x, z, alto, r:NextNumber(2, 3.6), 0)
			puestos += 1
		end
	end

	-- Sotobosque: junto a la carretera y en el borde del claro (más adentro no se ve).
	local soto = Instance.new("Folder")
	soto.Name = "Sotobosque"
	local puestas: { Vector2 } = {}
	local function sitioSoto(): (number, number)
		local k = r:NextNumber()
		if k < 0.62 then
			return r:NextNumber(CALLE - 1, 40) * (if r:NextNumber() < 0.5 then -1 else 1), r:NextNumber(-220, 220)
		elseif k < 0.82 then
			return r:NextNumber(80, 100), r:NextNumber(-80, 80)
		end
		return r:NextNumber(36, 80), r:NextNumber(50, 76) * (if r:NextNumber() < 0.5 then -1 else 1)
	end
	local function poner(nombre: string, cf: CFrame, escala: number, choca: boolean)
		for _, parte in Piezas.poner(soto, nombre, cf, Vector3.one * escala) do
			parte.CastShadow = false
			if choca and (parte.Name == "StoneDark" or parte.Name == "Bark") then
				-- Una caja invisible por lo grueso (la roca oscura, el tronco caído), para no atravesarlo.
				local choque = P.bloque(soto, "Choque", parte.Size * Vector3.new(0.85, 0.9, 0.85), parte.CFrame, COLOR.Barro, nil, true)
				choque.Transparency = 1
				choque.CastShadow = false
			end
		end
	end
	-- Un tronco caído de través sobre la cuneta del oeste, como un puente.
	if Piezas.hay("TroncoCaido") then
		poner("TroncoCaido", CFrame.new(-14.6, 0, -86) * CFrame.Angles(0, 0.12, 0), 0.7, true)
	end
	for _, cosa in { { "Helecho", 55, 0.8, 1.3, 3.2 }, { "Arbusto", 28, 0.75, 1.3, 3.6 }, { "RocaA", 9, 0.6, 1.1, 4.5 },
		{ "RocaB", 5, 0.5, 0.85, 5.5 }, { "TroncoCaido", 4, 0.7, 0.95, 7 } } do
		local nombre, cuantas = cosa[1], cosa[2]
		if not Piezas.hay(nombre) then
			continue
		end
		local n, intentos = 0, 0
		while n < cuantas and intentos < cuantas * 40 do
			intentos += 1
			local x, z = sitioSoto()
			local hueco = cosa[5]
			if prohibido(x, z) or hay(x, z, hueco) then
				continue
			end
			local junto = false
			for _, otra in puestas do
				if (otra.X - x) ^ 2 + (otra.Y - z) ^ 2 < hueco * hueco then
					junto = true
					break
				end
			end
			if junto then
				continue
			end
			table.insert(puestas, Vector2.new(x, z))
			local grande = nombre ~= "Helecho" and nombre ~= "Arbusto"
			poner(nombre, CFrame.new(x, 0, z) * CFrame.Angles(0, r:NextNumber(0, math.pi * 2), 0), r:NextNumber(cosa[3], cosa[4]), grande)
			n += 1
		end
	end
	soto.Parent = f
	f.Parent = mapa
	return troncos
end

------------------------------------------------------------------------------------------------------------------------
-- Los puntos "Sombra": sitios entre los árboles, alrededor de la gasolinera, desde los que una figura anda de lado (para
-- quien mira desde la explanada) hasta esconderse tras un tronco (lo hace el cliente, GasolineraVista).
local function sombras(troncos: { Vector3 }, trozos: { BasePart })
	local r = Random.new(1313)
	local N = 14
	local puestas = 0
	for i = 1, N do
		for _ = 1, 40 do
			local angulo = (i - 1) / N * math.pi * 2 + r:NextNumber(-0.2, 0.2)
			local d = r:NextNumber(58, 122)
			local radial = Vector3.new(math.cos(angulo), 0, math.sin(angulo))
			local p = CENTRO + radial * d
			if prohibido(p.X, p.Z) then
				continue
			end
			local tangente = Vector3.new(-radial.Z, 0, radial.X) * (if r:NextNumber() < 0.5 then 1 else -1)
			local hacia = (tangente + radial * r:NextNumber(-0.25, 0.25)).Unit
			-- El primer tronco del camino: tiene que quedar del lado de la gasolinera, para que la tape.
			local mejor: number? = nil
			local delante = false
			local metido = false
			for _, t in troncos do
				local v = Vector3.new(t.X - p.X, 0, t.Z - p.Z)
				if v.Magnitude < t.Y + 1.5 then
					metido = true -- empezaría dentro de un tronco
					break
				end
				local s = v:Dot(hacia)
				local lado = v - hacia * s
				if s > 0 and s < 26 and lado.Magnitude < t.Y + 0.7 and (mejor == nil or s < mejor) then
					mejor = s
					delante = lado:Dot(-radial) > -0.4
				end
			end
			if metido or not mejor or mejor < 6 or not delante then
				continue
			end
			local fin = p + hacia * mejor
			if prohibido(fin.X, fin.Z) then
				continue
			end
			local trozo = if p.X < 0 then trozos[1] elseif p.Z < -CORTE then trozos[2] elseif p.Z > CORTE then trozos[3] else trozos[4]
			P.etiqueta(P.punto(trozo, "Sombra", p), "Sombra", { Hacia = hacia, Largo = math.floor(mejor * 10 + 0.5) / 10 })
			puestas += 1
			break
		end
	end
	if puestas < 10 then
		warn(`[Gasolinera] solo {puestas} sitios para las sombras del bosque`)
	end
end

------------------------------------------------------------------------------------------------------------------------

-- Llama al `construir` de otro módulo del lobby sin que un fallo suyo pare el resto (los escriben aparte).
local function construir(nombre: string, carpeta: Instance)
	local modulo = script.Parent:FindFirstChild(nombre)
	if not modulo then
		warn(`[Gasolinera] falta {nombre}`)
		return
	end
	local ok, fallo = pcall(function()
		(require(modulo) :: any).construir(carpeta)
	end)
	if not ok then
		warn(`[Gasolinera] {nombre} ha fallado: {fallo}`)
	end
end

function Gasolinera.start()
	local mapa = workspace:WaitForChild("Mapa") :: Folder
	noche()
	local trozos = suelo(mapa)
	carretera(mapa)
	orilla(mapa)
	farolas(mapa)
	local troncos = bosque(mapa)
	sombras(troncos, trozos)

	local aparicion = Instance.new("SpawnLocation")
	aparicion.Name = "Aparicion"
	aparicion.Anchored = true
	aparicion.Size = Vector3.new(6, 0.2, 6)
	aparicion.CFrame = CFrame.new(44, 0.3, 0)
	aparicion.Transparency = 1 -- se aparece sobre la explanada; la placa no se ve
	aparicion.CanCollide = false
	aparicion.CanQuery = false
	aparicion.CanTouch = false
	aparicion.CastShadow = false
	aparicion.Neutral = true
	aparicion.Duration = 0
	aparicion.Parent = mapa

	construir("GasolineraTienda", mapa)
	construir("GasolineraFuera", mapa)
	-- Los coches, aparcados en fila junto a la carretera mirando al bosque (etiqueta "Coche": Coches).
	local coches = Instance.new("Folder")
	coches.Name = "Coches"
	construir("GasolineraCoches", coches)
	coches.Parent = workspace

	local quedan = Separar.caras(mapa) + Separar.caras(coches) -- que no parpadeen dos caras en el mismo plano
	if quedan > 0 then
		warn(`[Gasolinera] quedan {quedan} caras que parpadean`)
	end
end

return Gasolinera
