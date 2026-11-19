-- El bosque alrededor de la casa (suelo, camino, pinos y sotobosque), sacado de Mapa sin cambiar nada. Lo llama
-- Mapa.start; Mapa.arbol (el pino suelto que usa el pueblo) es MapaBosque.arbol. Ayudas de Mapa por `iniciar`.
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Piezas = require(ReplicatedStorage.Shared.Piezas)
local Linde = require(script.Parent.Linde)
local Lugares = require(script.Parent.Lugares)
local MapaSendas = require(script.Parent.MapaSendas)
local Medidas = require(script.Parent.MapaMedidas)
local COLOR, HUECO, TRAMPILLA = Medidas.COLOR, Medidas.HUECO, Medidas.TRAMPILLA

local MapaBosque = {}

-- Las ayudas de Mapa (las pone `iniciar`, al cargar Mapa).
local bloque, mando, clave

-- El pino de Blender sobre un tronco del bosque: el tronco (un cilindro) se queda para chocar, invisible. Sin las
-- mallas, el tronco gris de siempre. La variedad sale de su sitio, no del azar del bosque (que movería los árboles).
local function pino(tronco: BasePart, x: number, z: number, alto: number, grueso: number)
	local suerte = Random.new(math.floor(x * 31 + z * 17))
	local cual = suerte:NextNumber()
	local nombre = if cual < 0.15 then "PinoSeco" elseif cual < 0.5 then "PinoB" else "Pino"
	local h = alto / 60
	CollectionService:AddTag(tronco, "Pino") -- la pinocha que cae en las rachas (AireVista, docs/sistemas/aire.md)
	local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, suerte:NextNumber(0, math.pi * 2), 0)
	if #Piezas.poner(tronco, nombre, cf, Vector3.one * h, { Bark = Vector3.new(grueso / 2, h, grueso / 2) }) > 0 then
		tronco.Transparency = 1
		tronco.CastShadow = false
	end
end

-- Lo que hay por el suelo del bosque: rocas y troncos caídos (chocan) y arbustos y helechos (no). Lejos de la casa,
-- del camino, de las sendas (MapaSendas) y de los sitios (Lugares), con su propio azar: no mueve nada de lo que ya había.
-- Junto a la casa, la torre, el garaje, el cobertizo, el sótano o lo que hay delante (el motor está en z = -52, el garaje en x = -59): ahí no salen
-- árboles ni sotobosque.
local function junto(x: number, z: number): boolean
	return x > -62 and x < 72 and z > -54 and z < 72
end

local function sotobosque(bosque: Folder)
	local suelo = Instance.new("Folder")
	suelo.Name = "Sotobosque"
	local azar = Random.new(31)
	for _, cosa in { { "Helecho", 260 }, { "Arbusto", 140 }, { "RocaA", 40 }, { "RocaB", 22 }, { "TroncoCaido", 18 } } do
		local nombre, cuantas = cosa[1], cosa[2]
		if not Piezas.hay(nombre) then
			continue
		end
		local puestas, intentos = 0, 0
		while puestas < cuantas and intentos < cuantas * 20 do
			intentos += 1
			local angulo, distancia = azar:NextNumber(0, math.pi * 2), azar:NextNumber(22, 330)
			local x, z = math.cos(angulo) * distancia, math.sin(angulo) * distancia
			if (math.abs(x) < 10 and z < -24) or junto(x, z) or not Lugares.libre(x, z) or MapaSendas.cerca(x, z, 3) then
				continue
			end
			local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, azar:NextNumber(0, math.pi * 2), 0)
			local partes = Piezas.poner(suelo, nombre, cf, Vector3.one * azar:NextNumber(0.75, 1.3))
			for _, parte in partes do
				if nombre == "Helecho" or nombre == "Arbusto" then
					parte.CastShadow = false
				elseif parte.Name == "StoneDark" or parte.Name == "Bark" then
					-- Una caja invisible por lo grueso (la roca oscura, el tronco caído), para no atravesarlo.
					local choque = bloque("Choque", parte.Size * Vector3.new(0.85, 0.9, 0.85), parte.CFrame, nil, nil, suelo)
					choque.Transparency = 1
					choque.CastShadow = false
				end
			end
			puestas += 1
		end
	end
	suelo.Parent = bosque
end

-- La linde del mundo (contorno en Linde): el bosque se espesa y una pared invisible no deja pasar a los jugadores. Con
-- su propio azar (no mueve los pinos ni los talables, que se guardan). Tres cosas, en la carpeta Bosque.Linde:
--   Pinos espesos (uno cada ~17 studs) en la franja de 4 a 52 studs por dentro de la pared, sin pisar los del bosque,
--     la carretera ni el pueblo (que ya tiene su cinturón). Se llaman Tronco: el Acechador se asoma tras ellos.
--   La pared: un tramo por lado, invisible, de ALTO de alto, en el grupo de colisión "Linde", que solo choca con los
--     jugadores (Personajes y lo que se lleva en las manos; agachado choca su raíz, que sigue en Personajes): los bichos
--     (Default) la cruzan, así el Acechador que nace a la espalda llega igual. Los caminos de los bichos la ignoran.
--   Por fuera, de 6 a 50 studs, solo troncos altos que no chocan (una pieza cada uno): desde la pared se ve bosque y
--     niebla, nunca la llanura ni el borde del suelo.
local function linde(bosque: Folder, pinos: { Vector3 })
	if not PhysicsService:IsCollisionGroupRegistered("Linde") then
		PhysicsService:RegisterCollisionGroup("Linde")
	end
	PhysicsService:CollisionGroupSetCollidable("Linde", "Default", false)
	local carpeta = Instance.new("Folder")
	carpeta.Name = "Linde"
	local azar = Random.new(57)
	for _, s in Linde.sitios(azar, 17, 5, 4, 52, true) do
		local x, z = s.x, s.z
		local alto, grueso = azar:NextNumber(55, 90), azar:NextNumber(2.4, 4.6)
		local lejos = true
		for _, otro in pinos do
			if (otro.X - x) ^ 2 + (otro.Z - z) ^ 2 < 64 then
				lejos = false
				break
			end
		end
		if lejos and Lugares.libre(x, z) then
			local tronco = bloque("Tronco", Vector3.new(alto, grueso, grueso), CFrame.new(x, alto / 2, z) * CFrame.Angles(0, 0, math.pi / 2),
				COLOR.Tronco, Enum.Material.Wood, carpeta)
			tronco.Shape = Enum.PartType.Cylinder
			pino(tronco, x, z, alto, grueso)
		end
	end
	for _, s in Linde.sitios(azar, 21, 6, 6, 50, false) do
		local alto, grueso = azar:NextNumber(80, 125), azar:NextNumber(2.2, 4.4)
		local tronco = bloque("TroncoLejos", Vector3.new(alto, grueso, grueso),
			CFrame.new(s.x, alto / 2 - 1, s.z) * CFrame.Angles(0, 0, math.pi / 2), COLOR.Tronco, Enum.Material.Wood, carpeta)
		tronco.Shape = Enum.PartType.Cylinder
		tronco.CanCollide, tronco.CanQuery, tronco.CastShadow = false, false, false
	end
	local L = Linde.ALTO
	for _, t in Linde.tramos() do
		local a, b = Vector3.new(t.a.x, L / 2 - 1, t.a.z), Vector3.new(t.b.x, L / 2 - 1, t.b.z)
		-- Un grosor más de largo: los tramos se montan en las esquinas y no queda rendija.
		local pared = bloque("Pared", Vector3.new(Linde.GROSOR, L, (b - a).Magnitude + Linde.GROSOR), CFrame.lookAt((a + b) / 2, b),
			nil, Enum.Material.SmoothPlastic, carpeta)
		pared.Transparency = 1
		pared.CastShadow, pared.CanQuery, pared.CanTouch = false, false, false
		pared.CollisionGroup = "Linde"
		local paso = Instance.new("PathfindingModifier")
		paso.PassThrough = true
		paso.Parent = pared
	end
	carpeta.Parent = bosque
end

local function construirBosque(mapa: Folder)
	local bosque = Instance.new("Folder")
	bosque.Name = "Bosque"
	-- El suelo, en trozos alrededor del hueco de la escalera del sótano y del de la trampilla al patio (12.2).
	local x1, x2, z1, z2, L = HUECO[1], HUECO[2], HUECO[3], HUECO[4], 800
	local t1, t2, t3, t4 = TRAMPILLA[1], TRAMPILLA[2], TRAMPILLA[3], TRAMPILLA[4]
	for _, r in {
		{ -L, t1, -L, L }, { t2, x1, -L, L }, { t1, t2, -L, t3 }, { t1, t2, t4, L },
		{ x2, L, -L, L }, { x1, x2, -L, z1 }, { x1, x2, z2, L },
	} do
		bloque("Suelo", Vector3.new(r[2] - r[1], 2, r[4] - r[3]), CFrame.new((r[1] + r[2]) / 2, -1, (r[3] + r[4]) / 2), COLOR.Suelo,
			Enum.Material.LeafyGrass, bosque)
	end
	-- La carretera de tierra: de la casa al pueblo.
	CollectionService:AddTag(bloque("Camino", Vector3.new(12, 0.2, 494), CFrame.new(0, 0.05, -283), COLOR.Camino,
		Enum.Material.Ground, bosque), "EnMapa")
	-- Las sendas a la granja, al aserradero y a la torre (MapaSendas): sin pinos ni sotobosque encima.
	MapaSendas.construir(bosque, bloque)
	local azar = Random.new(7)
	local puestos = 0
	local pinos = {} :: { Vector3 } -- dónde quedan, para que los de la linde no caigan encima
	while puestos < 260 do
		local angulo = azar:NextNumber(0, math.pi * 2)
		local distancia = azar:NextNumber(48, 420)
		local x, z = math.cos(angulo) * distancia, math.sin(angulo) * distancia
		if not (math.abs(x) < 12 and z < -41) then
			local alto, grueso = azar:NextNumber(50, 85), azar:NextNumber(2, 4.5)
			puestos += 1
			-- Dentro de una zona (Lugares) o a menos de 4 de una senda no se pone, pero cuenta igual: los demás no se mueven.
			if not Lugares.libre(x, z) or junto(x, z) or MapaSendas.cerca(x, z, 4) then
				continue
			end
			local tronco = bloque("Tronco", Vector3.new(alto, grueso, grueso), CFrame.new(x, alto / 2, z) * CFrame.Angles(0, 0, math.pi / 2),
				COLOR.Tronco, Enum.Material.Wood, bosque)
			tronco.Shape = Enum.PartType.Cylinder
			pino(tronco, x, z, alto, grueso)
			table.insert(pinos, Vector3.new(x, 0, z))
		end
	end
	-- Árboles finos cerca de la casa: los que se talan (Recursos). Tronco anclado, copa soldada y un mando abajo.
	local talables = Instance.new("Folder")
	talables.Name = "Arboles"
	puestos = 0
	while puestos < Config.Talar.Arboles do
		local angulo = azar:NextNumber(0, math.pi * 2)
		local distancia = azar:NextNumber(42, 170)
		local x, z = math.cos(angulo) * distancia, math.sin(angulo) * distancia
		if not (math.abs(x) < 14 and z < -39) and (Vector3.new(x, 0, z) - Vector3.new(-35, 0, -43)).Magnitude > 10
			and Lugares.libre(x, z) and not junto(x, z) then
			local modelo = Instance.new("Model")
			modelo.Name = "Arbol"
			modelo.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			local alto, grueso = azar:NextNumber(22, 30), azar:NextNumber(1.6, 2.2)
			local tronco = bloque("Tronco", Vector3.new(alto, grueso, grueso), CFrame.new(x, alto / 2, z) * CFrame.Angles(0, 0, math.pi / 2),
				COLOR.Tronco, Enum.Material.Wood, modelo)
			tronco.Shape = Enum.PartType.Cylinder
			-- Dos números del azar por árbol, como siempre (pedir otros tantos movería los árboles guardados).
			local giro = azar:NextNumber(0, math.pi)
			azar:NextNumber(0, math.pi)
			local hojas = Piezas.poner(modelo, "CopaTalable", CFrame.new(x, 0, z) * CFrame.Angles(0, giro * 2, 0),
				Vector3.one * (alto / 26))
			if #hojas == 0 then -- sin las mallas de Blender, la copa de bloques
				for i, copa in { { 9, alto - 4 }, { 6, alto + 1 } } do
					table.insert(hojas, bloque("Copa", Vector3.new(copa[1], copa[1] * 0.8, copa[1]),
						CFrame.new(x, copa[2], z) * CFrame.Angles(0, giro + i, 0), Color3.fromRGB(44, 54, 42), Enum.Material.Grass, modelo))
				end
			end
			for _, hoja in hojas do
				hoja.Name = "Copa" -- Recursos la quita al partir el tronco
				hoja.Anchored = false
				hoja.CanCollide = false
				hoja.Massless = true
				local union = Instance.new("WeldConstraint")
				union.Part0 = tronco
				union.Part1 = hoja
				union.Parent = hoja
			end
			mando(CFrame.new(x, 3.5, z), modelo)
			modelo.PrimaryPart = tronco
			modelo:SetAttribute("Clave", clave("A", Vector3.new(x, 0, z)))
			CollectionService:AddTag(modelo, "Arbol")
			modelo.Parent = talables
			puestos += 1
		end
	end
	talables.Parent = bosque
	sotobosque(bosque)
	linde(bosque, pinos)
	bosque.Parent = mapa
end

-- Un pino como los del bosque (tronco que choca y su modelo de Piezas) en (x, z), colgado de `padre`.
function MapaBosque.arbol(x: number, z: number, alto: number, grueso: number, padre: Instance)
	local tronco = bloque("Tronco", Vector3.new(alto, grueso, grueso), CFrame.new(x, alto / 2, z) * CFrame.Angles(0, 0, math.pi / 2),
		COLOR.Tronco, Enum.Material.Wood, padre)
	tronco.Shape = Enum.PartType.Cylinder
	pino(tronco, x, z, alto, grueso)
end

-- Lo llama Mapa al cargar, con sus ayudas (`a`).
function MapaBosque.iniciar(a)
	bloque = a.bloque
	mando = a.mando
	clave = a.clave
end

MapaBosque.construirBosque = construirBosque

return MapaBosque
