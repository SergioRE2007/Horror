-- Los sitios fuera de la casa, con bloques grises (pedido por el usuario: todo con sentido, nada "por la cara"):
-- granja, aserradero viejo, torre del guardabosques en una colina y el pueblo abandonado al final de la carretera
-- (iglesia con cementerio, la tienda del vendedor y casas cerradas). De más cerca a más lejos, como las llaves.
-- Cada zona deja en Mapa.llaves los sitios donde puede salir su llave y en Mapa.objetos la comida y el agua (latas y
-- botellas, para el vendedor). El bosque no pone árboles dentro de las zonas (Lugares.libre).
local CollectionService = game:GetService("CollectionService")

local Lugares = {}

local COLOR = {
	Muro = Color3.fromRGB(118, 114, 108),
	Piso = Color3.fromRGB(88, 84, 78),
	Mueble = Color3.fromRGB(100, 95, 90),
	Oscuro = Color3.fromRGB(45, 43, 42),
	Madera = Color3.fromRGB(70, 62, 55),
	Piedra = Color3.fromRGB(105, 105, 102),
	Tierra = Color3.fromRGB(62, 54, 46),
	Hierba = Color3.fromRGB(58, 62, 55),
}

-- Zonas sin árboles del bosque: { x, z, radio }.
local ZONAS = {
	Granja = { 205, 75, 55 },
	Aserradero = { -232, -86, 45 },
	Torre = { 90, 285, 70 },
	Pueblo = { 28, -480, 75 },
	Garaje = { -49, 18, 20 }, -- el de la casa (Mapa)
}

function Lugares.libre(x: number, z: number): boolean
	for _, zona in ZONAS do
		if (x - zona[1]) ^ 2 + (z - zona[2]) ^ 2 < zona[3] ^ 2 then
			return false
		end
	end
	return true
end

local carpeta: Folder
local Mapa -- el módulo Mapa: aquí se apuntan las llaves y los objetos

local function bloque(nombre: string, tamano: Vector3, cf: CFrame, color: Color3?, material: Enum.Material?, padre: Instance?): Part
	local p = Instance.new("Part")
	p.Name = nombre
	p.Anchored = true
	p.Size = tamano
	p.CFrame = cf
	p.Color = color or COLOR.Muro
	p.Material = material or Enum.Material.WoodPlanks
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = padre or carpeta
	return p
end

-- Un sitio donde puede salir la llave de esa zona (encima de algo).
local function llave(zona: string, posicion: Vector3)
	local lista = Mapa.llaves[zona] or {}
	Mapa.llaves[zona] = lista
	table.insert(lista, CFrame.new(posicion) * CFrame.Angles(0, math.rad(#lista * 53), 0))
end

local function objeto(tipo: string, posicion: Vector3)
	table.insert(Mapa.objetos, { tipo = tipo, cf = CFrame.new(posicion) * CFrame.Angles(0, math.rad(#Mapa.objetos * 37), 0) })
end

-- Una cosa pesada (Cargar) que empieza aquí en una partida nueva.
local function pesado(tipo: string, cf: CFrame)
	table.insert(Mapa.pesados, { tipo = tipo, cf = cf })
end

-- Pared recta de 1 de grueso; `centro` a ras del suelo. Con puerta: hueco de 4 x 8 en medio.
local function pared(centro: Vector3, largo: number, enX: boolean, alto: number, puerta: boolean, padre: Instance)
	local function trozo(desde: number, hasta: number, y0: number, y1: number)
		local medio = (desde + hasta) / 2
		local posicion = centro + (if enX then Vector3.new(medio, (y0 + y1) / 2, 0) else Vector3.new(0, (y0 + y1) / 2, medio))
		local tamano = if enX then Vector3.new(hasta - desde, y1 - y0, 1) else Vector3.new(1, y1 - y0, hasta - desde)
		bloque("Muro", tamano, CFrame.new(posicion), COLOR.Muro, nil, padre)
	end
	if puerta then
		trozo(-largo / 2, -2, 0, alto)
		trozo(2, largo / 2, 0, alto)
		trozo(-2, 2, 8, alto)
	else
		trozo(-largo / 2, largo / 2, 0, alto)
	end
end

local LADOS = { N = Vector3.new(0, 0, -1), S = Vector3.new(0, 0, 1), E = Vector3.new(1, 0, 0), O = Vector3.new(-1, 0, 0) }

-- Edificio de una sala: suelo (sale en el mapa del móvil), paredes, techo plano y la puerta en el lado `lado`
-- ("N" = -z, "S" = +z, "E" = +x, "O" = -x). `cerrado`: la puerta tapiada con tablones (las casas del pueblo).
local function edificio(nombre: string, cx: number, cz: number, ancho: number, largo: number, alto: number, lado: string,
	cerrado: boolean): Model
	local modelo = Instance.new("Model")
	modelo.Name = nombre
	CollectionService:AddTag(bloque("Piso", Vector3.new(ancho, 1, largo), CFrame.new(cx, 0.5, cz), COLOR.Piso, nil, modelo), "EnMapa")
	local base = Vector3.new(cx, 1, cz)
	pared(base + Vector3.new(0, 0, -largo / 2), ancho + 1, true, alto, lado == "N", modelo)
	pared(base + Vector3.new(0, 0, largo / 2), ancho + 1, true, alto, lado == "S", modelo)
	pared(base + Vector3.new(-ancho / 2, 0, 0), largo - 1, false, alto, lado == "O", modelo)
	pared(base + Vector3.new(ancho / 2, 0, 0), largo - 1, false, alto, lado == "E", modelo)
	bloque("Techo", Vector3.new(ancho + 2, 1, largo + 2), CFrame.new(cx, 1 + alto + 0.5, cz), COLOR.Oscuro, Enum.Material.Slate, modelo)
	if cerrado then
		local fuera = LADOS[lado]
		local pie = base + fuera * (if lado == "N" or lado == "S" then largo / 2 else ancho / 2) + Vector3.new(0, 4, 0)
		local cf = CFrame.lookAt(pie, pie + fuera)
		bloque("PuertaTapiada", Vector3.new(4, 8, 0.4), cf, COLOR.Mueble, nil, modelo)
		for i, y in { -2.4, 0.3, 2.6 } do
			bloque("Tablon", Vector3.new(5.4, 0.6, 0.3), cf * CFrame.new(0, y, -0.45) * CFrame.Angles(0, 0, math.rad((i - 2) * 12)),
				COLOR.Madera, Enum.Material.Wood, modelo)
		end
	end
	modelo.Parent = carpeta
	return modelo
end

-- Granja (llave del sótano): casa, granero con paja y el campo.
local function granja()
	edificio("CasaGranja", 196, 52, 16, 12, 10, "O", false)
	bloque("Mesa", Vector3.new(5, 3, 3), CFrame.new(197, 2.5, 52), COLOR.Mueble)
	bloque("Encimera", Vector3.new(2, 3.5, 8), CFrame.new(202.5, 2.75, 52), COLOR.Mueble)
	objeto("Lata", Vector3.new(202.5, 4.7, 49.5))
	objeto("Lata", Vector3.new(202.5, 4.7, 54))
	llave("Granja", Vector3.new(197.5, 4.2, 52))

	edificio("Granero", 228, 80, 20, 24, 14, "O", false)
	bloque("Paja", Vector3.new(4, 3, 6), CFrame.new(232, 2.5, 88), Color3.fromRGB(120, 108, 72), Enum.Material.Fabric)
	bloque("Paja", Vector3.new(4, 3, 6), CFrame.new(235, 2.5, 74), Color3.fromRGB(120, 108, 72), Enum.Material.Fabric)
	bloque("Paja", Vector3.new(4, 3, 4), CFrame.new(235, 5.5, 74), Color3.fromRGB(120, 108, 72), Enum.Material.Fabric)
	bloque("Banco", Vector3.new(6, 3.5, 2), CFrame.new(226, 2.75, 90.5), COLOR.Mueble)
	objeto("Botella", Vector3.new(228, 4.9, 90.5))
	objeto("Chatarra", Vector3.new(222, 1.2, 72))
	objeto("Chatarra", Vector3.new(224, 1.2, 86))
	pesado("Bidon", CFrame.new(220, 2.2, 89))
	llave("Granja", Vector3.new(232, 4.2, 88))
	llave("Granja", Vector3.new(224.5, 4.7, 90.5))

	CollectionService:AddTag(bloque("Campo", Vector3.new(36, 0.2, 26), CFrame.new(197, 0.1, 104), COLOR.Tierra, Enum.Material.Ground), "EnMapa")
	for i = 0, 7 do
		bloque("Surco", Vector3.new(34, 0.4, 0.8), CFrame.new(197, 0.3, 94 + i * 3), COLOR.Tierra, Enum.Material.Ground)
	end
	bloque("Caja", Vector3.new(2.5, 2.5, 2.5), CFrame.new(175, 1.25, 96), COLOR.Madera, Enum.Material.Wood)
	llave("Granja", Vector3.new(175, 2.7, 96))
	bloque("Abrevadero", Vector3.new(6, 1.5, 2), CFrame.new(214, 0.75, 62), COLOR.Madera, Enum.Material.Wood)
end

-- Aserradero viejo (llave del garaje): nave abierta con la sierra, tablones, troncos y la oficina.
local function aserradero()
	local cx, cz = -230, -90
	CollectionService:AddTag(bloque("Piso", Vector3.new(32, 1, 18), CFrame.new(cx, 0.5, cz), COLOR.Piedra, Enum.Material.Concrete), "EnMapa")
	for _, x in { -15.5, 0, 15.5 } do
		for _, z in { -8.5, 8.5 } do
			bloque("Poste", Vector3.new(1, 11, 1), CFrame.new(cx + x, 6.5, cz + z), COLOR.Madera, Enum.Material.Wood)
		end
	end
	bloque("Tejado", Vector3.new(34, 1, 20), CFrame.new(cx, 12.5, cz), COLOR.Oscuro, Enum.Material.CorrodedMetal)
	bloque("MesaSierra", Vector3.new(12, 3, 2.5), CFrame.new(cx, 2.5, cz), COLOR.Mueble)
	local disco = bloque("Disco", Vector3.new(0.2, 3, 3), CFrame.new(cx - 2, 4, cz) * CFrame.Angles(0, math.pi / 2, 0),
		Color3.fromRGB(140, 140, 138), Enum.Material.Metal)
	disco.Shape = Enum.PartType.Cylinder
	llave("Aserradero", Vector3.new(cx + 5, 4.2, cz))
	bloque("Tablones", Vector3.new(6, 2, 3), CFrame.new(cx + 10, 2, cz - 6), COLOR.Madera, Enum.Material.Wood)
	llave("Aserradero", Vector3.new(cx + 10, 3.2, cz - 6))
	bloque("Estante", Vector3.new(1.5, 6, 6), CFrame.new(cx - 13.5, 4, cz + 4), COLOR.Mueble)
	llave("Aserradero", Vector3.new(cx - 13.5, 7.2, cz + 4))
	for i = 0, 2 do
		local tronco = bloque("Tronco", Vector3.new(8, 1.6, 1.6), CFrame.new(cx + 20, 0.8, cz + 15 + i * 1.7), COLOR.Madera, Enum.Material.Wood)
		tronco.Shape = Enum.PartType.Cylinder
	end
	pesado("Rueda", CFrame.new(cx + 6, 1.5, cz + 6) * CFrame.Angles(0, 0, math.pi / 2)) -- la otra rueda del coche
	objeto("Chatarra", Vector3.new(cx - 8, 1.2, cz + 6))
	objeto("Chatarra", Vector3.new(cx + 14, 1.2, cz - 2))

	edificio("Oficina", -252, -74, 8, 8, 9, "E", false)
	bloque("Escritorio", Vector3.new(3, 3, 2), CFrame.new(-254, 2.5, -72), COLOR.Mueble)
	llave("Aserradero", Vector3.new(-254.8, 4.2, -72))
	objeto("Botella", Vector3.new(-253, 4.2, -72.2))
end

-- Torre del guardabosques en una colina (llave del desván): una escalera larga sube la colina hasta la caseta de
-- arriba. Abajo, junto a la colina, la caseta del guarda.
local function torre()
	local cx, cz = 90, 300
	local colina = bloque("Colina", Vector3.new(140, 140, 140), CFrame.new(cx, -50, cz), COLOR.Hierba, Enum.Material.Grass)
	colina.Shape = Enum.PartType.Ball -- la cima, en y = 20
	for _, x in { -4, 4 } do
		for _, z in { -4, 4 } do
			bloque("Pata", Vector3.new(1, 26, 1), CFrame.new(cx + x, 31.5, cz + z), COLOR.Madera, Enum.Material.Wood)
		end
	end
	bloque("Plataforma", Vector3.new(10, 1, 10), CFrame.new(cx, 44, cz), COLOR.Madera, Enum.Material.WoodPlanks)
	-- Escalera de peldaños desde el pie de la colina (z 251) hasta la plataforma (z 295, y = 44,5). Las escaleras de
	-- mano (TrussPart) fallaban a veces al cogerlas.
	for i = 1, 44 do
		local arriba = 0.5 + i
		bloque("Peldano", Vector3.new(4, arriba + 2, 1), CFrame.new(cx, (arriba - 2) / 2, cz - 49.5 + i), COLOR.Madera, Enum.Material.WoodPlanks)
	end
	-- Caseta de arriba: barandillas (con hueco donde llega la escalera), postes y tejado.
	for _, b in { { 0, 5, 10, 0.4 }, { -5, 0, 0.4, 10 }, { 5, 0, 0.4, 10 }, { -3.5, -5, 3, 0.4 }, { 3.5, -5, 3, 0.4 } } do
		bloque("Baranda", Vector3.new(b[3], 3, b[4]), CFrame.new(cx + b[1], 46, cz + b[2]), COLOR.Madera, Enum.Material.Wood)
	end
	for _, x in { -4.8, 4.8 } do
		for _, z in { -4.8, 4.8 } do
			bloque("Poste", Vector3.new(0.6, 7, 0.6), CFrame.new(cx + x, 48, cz + z), COLOR.Madera, Enum.Material.Wood)
		end
	end
	bloque("Tejado", Vector3.new(11, 0.6, 11), CFrame.new(cx, 51.8, cz), COLOR.Oscuro, Enum.Material.Slate)
	bloque("Mesa", Vector3.new(3, 3, 2), CFrame.new(cx + 2, 46, cz), COLOR.Mueble)
	llave("Torre", Vector3.new(cx + 2, 47.7, cz))
	llave("Torre", Vector3.new(cx - 3, 44.7, cz - 3))
	llave("Torre", Vector3.new(cx + 1, 22.7, cz - 27.5)) -- en un peldaño, a mitad de la subida

	edificio("CasetaGuarda", cx, 238, 8, 8, 9, "N", false)
	bloque("Mesa", Vector3.new(3, 3, 2), CFrame.new(cx + 2, 2.5, 241), COLOR.Mueble)
	llave("Torre", Vector3.new(cx + 2, 4.2, 241))
	objeto("Chatarra", Vector3.new(cx - 2, 1.2, 236))
end

-- El vendedor: un viejo de bloques detrás del mostrador (Vendedor le pone el prompt en su Mando).
local function vendedor(pie: Vector3, mira: Vector3)
	local modelo = Instance.new("Model")
	modelo.Name = "Vendedor"
	modelo.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local cf = CFrame.lookAt(pie, pie + mira)
	local piel, ropa, oscuro = Color3.fromRGB(150, 128, 112), Color3.fromRGB(72, 64, 54), Color3.fromRGB(40, 38, 36)
	local function trozo(nombre: string, tamano: Vector3, offset: CFrame, color: Color3)
		bloque(nombre, tamano, cf * offset, color, Enum.Material.SmoothPlastic, modelo)
	end
	for _, x in { -0.5, 0.5 } do
		trozo("Pierna", Vector3.new(0.9, 3, 0.9), CFrame.new(x, 1.5, 0), oscuro)
		trozo("Brazo", Vector3.new(0.8, 2.6, 0.8), CFrame.new(x * 3, 4.2, -0.2) * CFrame.Angles(math.rad(15), 0, 0), ropa)
	end
	trozo("Torso", Vector3.new(2.2, 2.6, 1.1), CFrame.new(0, 4.3, -0.1) * CFrame.Angles(math.rad(-10), 0, 0), ropa)
	trozo("Cabeza", Vector3.new(1.2, 1.3, 1.2), CFrame.new(0, 6.2, -0.4), piel)
	trozo("Ala", Vector3.new(2, 0.15, 2), CFrame.new(0, 6.9, -0.4), oscuro)
	trozo("Copa", Vector3.new(1.3, 0.6, 1.3), CFrame.new(0, 7.25, -0.4), oscuro)
	local mando = bloque("Mando", Vector3.new(1, 1, 1), cf * CFrame.new(0, 4, -3), nil, nil, modelo)
	mando.Transparency = 1
	mando.CanCollide = false
	mando.CanQuery = false
	mando.CanTouch = false
	CollectionService:AddTag(modelo, "Vendedor")
	modelo.Parent = carpeta
end

-- Pueblo abandonado al final de la carretera (llave de la habitación del rico, en el cementerio).
local function pueblo()
	-- La tienda, con el vendedor detrás del mostrador mirando a la puerta.
	edificio("Tienda", -20, -455, 14, 12, 10, "E", false)
	bloque("Mostrador", Vector3.new(2, 3.5, 7), CFrame.new(-18, 2.75, -455), COLOR.Mueble)
	bloque("Estanteria", Vector3.new(1.5, 7, 10), CFrame.new(-25.6, 4.5, -455), COLOR.Mueble)
	vendedor(Vector3.new(-22, 1, -455), Vector3.new(1, 0, 0))

	-- Una casa con la puerta rota (comida) y las cerradas.
	edificio("CasaAbierta", 20, -440, 12, 12, 10, "O", false)
	bloque("Mesa", Vector3.new(4, 3, 3), CFrame.new(21, 2.5, -440), COLOR.Mueble)
	objeto("Lata", Vector3.new(20, 4.2, -440))
	objeto("Botella", Vector3.new(22, 4.2, -441))
	objeto("Botella", Vector3.new(24.5, 1.2, -445))
	objeto("Chatarra", Vector3.new(17, 1.2, -444))
	edificio("CasaCerrada", -22, -485, 12, 12, 10, "E", true)
	edificio("CasaCerrada", -22, -510, 12, 12, 10, "E", true)
	edificio("CasaCerrada", 22, -462, 12, 12, 10, "O", true)

	-- La iglesia mirando a la carretera, con su campanario.
	edificio("Iglesia", 30, -500, 16, 28, 16, "O", false)
	for i = 0, 3 do
		for _, z in { -505, -495 } do
			bloque("Banco", Vector3.new(1.5, 1.5, 7), CFrame.new(26 + i * 2.6, 1.75, z), COLOR.Madera, Enum.Material.Wood)
		end
	end
	bloque("Altar", Vector3.new(3, 3.5, 6), CFrame.new(36, 2.75, -500), COLOR.Piedra, Enum.Material.Slate)
	bloque("Campanario", Vector3.new(6, 28, 6), CFrame.new(19, 14, -514), COLOR.Muro)
	bloque("Cruz", Vector3.new(0.5, 4, 0.5), CFrame.new(19, 30, -514), COLOR.Oscuro, Enum.Material.Metal)
	bloque("Cruz", Vector3.new(0.5, 0.5, 2.4), CFrame.new(19, 30.8, -514), COLOR.Oscuro, Enum.Material.Metal)

	-- El cementerio detrás: tumbas, la cripta y la caseta del enterrador.
	local x1, x2, z1, z2 = 42, 82, -525, -475
	CollectionService:AddTag(bloque("Cementerio", Vector3.new(x2 - x1, 0.2, z2 - z1), CFrame.new((x1 + x2) / 2, 0.1, (z1 + z2) / 2),
		COLOR.Tierra, Enum.Material.Ground), "EnMapa")
	bloque("Valla", Vector3.new(x2 - x1, 2.5, 0.4), CFrame.new((x1 + x2) / 2, 1.25, z1), COLOR.Oscuro, Enum.Material.Metal)
	bloque("Valla", Vector3.new(x2 - x1, 2.5, 0.4), CFrame.new((x1 + x2) / 2, 1.25, z2), COLOR.Oscuro, Enum.Material.Metal)
	bloque("Valla", Vector3.new(0.4, 2.5, z2 - z1), CFrame.new(x2, 1.25, (z1 + z2) / 2), COLOR.Oscuro, Enum.Material.Metal)
	for _, tramo in { { z1, -503 }, { -497, z2 } } do -- al oeste, con la entrada frente a la iglesia
		bloque("Valla", Vector3.new(0.4, 2.5, tramo[2] - tramo[1]), CFrame.new(x1, 1.25, (tramo[1] + tramo[2]) / 2), COLOR.Oscuro,
			Enum.Material.Metal)
	end
	edificio("Cripta", 74, -515, 8, 8, 8, "O", false)
	bloque("Sarcofago", Vector3.new(2.5, 2.5, 5), CFrame.new(76, 2.25, -515), COLOR.Piedra, Enum.Material.Slate)
	llave("Cementerio", Vector3.new(76, 3.7, -515))
	edificio("CasetaEnterrador", 78, -481, 6, 6, 8, "O", false)
	bloque("Mesa", Vector3.new(2, 3, 2), CFrame.new(79.5, 2.5, -481), COLOR.Mueble)
	llave("Cementerio", Vector3.new(79.5, 4.2, -481))
	objeto("Chatarra", Vector3.new(77, 1.2, -479))
	for x = 48, 76, 7 do
		for z = -520, -484, 9 do
			if (x > 66 and z < -506) or (x > 70 and z > -488) then
				continue -- ahí están la cripta y la caseta
			end
			bloque("Lapida", Vector3.new(0.5, 3, 2.2), CFrame.new(x, 1.5, z) * CFrame.Angles(0, 0, math.rad((x + z) % 7 - 3)),
				COLOR.Piedra, Enum.Material.Slate)
			bloque("Tumba", Vector3.new(4.6, 0.5, 2.4), CFrame.new(x + 2.8, 0.25, z), COLOR.Tierra, Enum.Material.Ground)
		end
	end
	llave("Cementerio", Vector3.new(50.8, 0.7, -484))
	bloque("BancoPiedra", Vector3.new(1, 1.2, 3), CFrame.new(46, 0.6, -500), COLOR.Piedra, Enum.Material.Slate)
	llave("Cementerio", Vector3.new(46, 1.4, -500))
end

function Lugares.construir(mapa: Folder, modulo)
	Mapa = modulo
	carpeta = Instance.new("Folder")
	carpeta.Name = "Lugares"
	granja()
	aserradero()
	torre()
	pueblo()
	carpeta.Parent = mapa
end

return Lugares
