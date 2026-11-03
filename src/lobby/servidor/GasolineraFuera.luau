-- Lo de fuera de la gasolinera del lobby (pedido por el usuario: "el lobby es un poco feo"): la explanada de hormigón
-- (losas de distinto tono con juntas, grietas con hierbajos, manchas de aceite, plazas pintadas, bordillos, rejillas,
-- tapas de los depósitos y charcos), la marquesina (faldón rojo desteñido, cuatro fluorescentes, pilares oxidados), las
-- dos islas con sus surtidores viejos, el cartel alto "GAS", la cabina de teléfono, el contenedor, los neumáticos, el
-- poste de aire y agua, el banco, la máquina expendedora y la basura. Todo en el Model "Fuera" de workspace.Mapa; la
-- tienda y los coches van aparte.
-- Para el cliente (GasolineraVista, Clima), con etiquetas: LuzFalla (atributos Fallo y Zumba), Polillas, Charco, Goteo y
-- Chapa. Aquí no parpadea ni se mueve nada.
-- Choca solo lo grande (losas, islas, pilares, surtidores, cartel, cabina, contenedor, neumáticos, poste de aire, banco
-- y máquina; y la chapa y el faldón de la marquesina, que tapan los rayos de la lluvia); lo demás es adorno. Nada choca
-- en la aparición (x 40-48, z -4..4) ni en el pasillo de los coches (x 7-20).
-- Alturas (cara de arriba): hierba 0; losas 0,2 (la base que se ve en las juntas, 0,15); grietas 0,212; rayas 0,222;
-- aceite 0,228; charcos 0,236; islas 0,7 y sus puntas 0,73. Lo plano lleva SinSeparar (Separar.caras no lo engorda).
local P = require(script.Parent.GasolineraPiezas)

local GasolineraFuera = {}

local C = P.COLOR
local SUELO = 0.2 -- cara de arriba de la explanada (x 7..73, z -40..40)
local TIENDA = { x0 = 52, x1 = 70, z0 = -14, z1 = 14 } -- la tienda va aparte: debajo no van losas
local MQ = { x = 32, z = 0, ancho = 20, largo = 26, abajo = 12.4, alto = 1.2 } -- marquesina: x 22..42, z -13..13
local ISLAS = { -5, 5 } -- z de cada isla (centradas en x = 32, de x 25,5 a 38,5)
local PUNTA = 4.9 -- de su centro a sus puntas redondas, donde van los pilares
local ALTO_ISLA = 0.7
-- El cartel alto, a la entrada norte y girado 45°: su cara de delante mira a la carretera y a quien llega del bosque
-- (-Z), y la de detrás, a la gasolinera. En x = 23,5 y no junto a la carretera para no cortar la salida de los coches.
local CARTEL = CFrame.new(23.5, 0, -45) * CFrame.Angles(0, math.rad(45), 0)
-- Las rejillas de las losas (columnas y filas): la tienda corta las de x 52..70 a su altura.
local OESTE = { 7, 13.4, 19.8, 26.2, 32.6, 39, 45.5, 52 }
local FILAS = { -40, -33.5, -27, -20.5, -14, -7, 0, 7, 14, 20.5, 27, 33.5, 40 }
local JUNTA = 0.16 -- hueco entre losas: deja ver la base oscura

local COLOR = {
	Junta = Color3.fromRGB(34, 33, 31),
	Grieta = Color3.fromRGB(22, 21, 20),
	Charco = Color3.fromRGB(13, 15, 17),
	Bordillo = Color3.fromRGB(98, 96, 90),
	Techo = Color3.fromRGB(116, 114, 106), -- la chapa por debajo: blanca y sucia
	RojoViejo = Color3.fromRGB(98, 38, 32), -- el rojo de la marca, desteñido
	Crema = Color3.fromRGB(136, 128, 110),
	Amarillo = Color3.fromRGB(128, 108, 50), -- protectores y puntas de las islas, desteñidos
	Negro = Color3.fromRGB(24, 24, 24),
	Verde = Color3.fromRGB(44, 58, 42), -- el contenedor
	Cabina = Color3.fromRGB(54, 60, 56),
	Pantalla = Color3.fromRGB(15, 19, 17),
	Apagado = Color3.fromRGB(52, 64, 54), -- números de una pantalla sin corriente
	FondoCartel = Color3.fromRGB(56, 22, 20),
	LetraCartel = Color3.fromRGB(172, 52, 40),
	Precios = Color3.fromRGB(116, 110, 96),
	Tinta = Color3.fromRGB(24, 22, 20),
	LuzTubo = Color3.fromRGB(205, 226, 200), -- blanco verdoso
	LuzCartel = Color3.fromRGB(200, 62, 46),
	LuzBombilla = Color3.fromRGB(255, 196, 140),
	Hierbajo = { Color3.fromRGB(58, 66, 42), Color3.fromRGB(72, 74, 46), Color3.fromRGB(86, 80, 52), Color3.fromRGB(48, 58, 40) },
	Lata = { Color3.fromRGB(96, 34, 30), Color3.fromRGB(44, 62, 86), Color3.fromRGB(118, 118, 114), Color3.fromRGB(52, 74, 46) },
	Papel = { Color3.fromRGB(150, 144, 128), Color3.fromRGB(128, 120, 100), Color3.fromRGB(104, 98, 84) },
}

local azar = Random.new(5821) -- siempre igual: la gasolinera sale idéntica en cada servidor
local raiz: Model

------------------------------------------------------------------------------------------------------------------------
-- Ayudas

local function grupo(nombre: string, padre: Instance?): Model
	local m = Instance.new("Model")
	m.Name = nombre
	m.Parent = padre or raiz
	return m
end

-- Adorno: no choca ni tapa rayos.
local function pieza(padre: Instance, nombre: string, tam: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	return P.bloque(padre, nombre, tam, cf, color, material)
end

-- Lo que choca.
local function solido(padre: Instance, nombre: string, tam: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	return P.bloque(padre, nombre, tam, cf, color, material, true)
end

-- Lámina pegada al suelo o a una cara (rayas, grietas, óxido): sin sombra y sin que Separar.caras la engorde.
local function lamina(padre: Instance, nombre: string, tam: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = P.bloque(padre, nombre, tam, cf, color, material)
	p.CastShadow = false
	p:SetAttribute("SinSeparar", true)
	return p
end

-- Cilindro de pie, de `alto` y `ancho` (diámetro), con su centro en `cf` (los de Roblox van a lo largo de X).
local function columna(padre: Instance, nombre: string, alto: number, ancho: number, cf: CFrame, color: Color3,
	material: Enum.Material?, choca: boolean?): Part
	return P.cilindro(padre, nombre, Vector3.new(alto, ancho, ancho), cf * CFrame.Angles(0, 0, math.pi / 2), color, material, choca)
end

-- CFrame en medio de `a` y `b` con su X de `a` a `b`.
local function ejeX(a: Vector3, b: Vector3): CFrame
	local x = (b - a).Unit
	local ref = if math.abs(x.Y) > 0.95 then Vector3.zAxis else Vector3.yAxis
	local z = x:Cross(ref).Unit
	return CFrame.fromMatrix((a + b) / 2, x, z:Cross(x), z)
end

-- Manguera, cable o palo de `a` a `b` (algo más largo, para que no se vean cortes entre trozos).
local function tubo(padre: Instance, nombre: string, a: Vector3, b: Vector3, grueso: number, color: Color3,
	material: Enum.Material?): Part
	local p = P.cilindro(padre, nombre, Vector3.new((b - a).Magnitude + grueso * 0.5, grueso, grueso), ejeX(a, b), color, material)
	p.CastShadow = false
	return p
end

-- Manguera que cuelga de `a` a `b` por una curva (Bézier con `c1` y `c2`), en `tramos` trozos.
local function curva(padre: Instance, a: Vector3, c1: Vector3, c2: Vector3, b: Vector3, tramos: number, grueso: number,
	color: Color3)
	local antes = a
	for i = 1, tramos do
		local t = i / tramos
		local s = 1 - t
		local punto = a * (s * s * s) + c1 * (3 * s * s * t) + c2 * (3 * s * t * t) + b * (t * t * t)
		tubo(padre, "Manguera", antes, punto, grueso, color, Enum.Material.Rubber)
		antes = punto
	end
end

-- Lo mismo por una lista de puntos.
local function quebrada(padre: Instance, puntos: { Vector3 }, grueso: number, color: Color3)
	for i = 1, #puntos - 1 do
		tubo(padre, "Manguera", puntos[i], puntos[i + 1], grueso, color, Enum.Material.Rubber)
	end
end

-- Chorretón de óxido que baja `alto` desde `arriba` (un punto de una cara vertical que mira hacia `fuera`).
local function chorreton(padre: Instance, arriba: Vector3, fuera: Vector3, alto: number)
	local cf = CFrame.lookAt(arriba, arriba + fuera) * CFrame.new(0, -alto / 2, -0.035)
	lamina(padre, "Chorreton", Vector3.new(azar:NextNumber(0.07, 0.18), alto, 0.02), cf,
		C.Oxido:Lerp(C.OxidoOscuro, azar:NextNumber(0, 0.7)), Enum.Material.CorrodedMetal)
end

-- Parche de óxido sobre una cara: `cara` es un CFrame en ella con su -Z hacia fuera; (u, v) por la cara.
local function parche(padre: Instance, cara: CFrame, u: number, v: number, ancho: number, alto: number)
	lamina(padre, "Oxido", Vector3.new(ancho, alto, 0.03), cara * CFrame.new(u, v, -0.015)
		* CFrame.Angles(0, 0, math.rad(azar:NextNumber(-8, 8))), C.Oxido:Lerp(C.OxidoOscuro, azar:NextNumber(0, 0.6)),
		Enum.Material.CorrodedMetal)
end

-- Cara de arriba de lo que hay debajo de (x, z), para posar basura: islas, explanada o hierba.
local function sueloEn(x: number, z: number): number
	if x > MQ.x - PUNTA - 1.6 and x < MQ.x + PUNTA + 1.6 then
		for _, zc in ISLAS do
			if math.abs(z - zc) < 1.6 then
				return ALTO_ISLA
			end
		end
	end
	if x >= 7 and x <= 73 and z >= -40 and z <= 40 then
		return SUELO
	end
	return 0
end

-- Matojo de hierbajos (tres hojas finas) con su base a la altura `y0`.
local function hierbajo(padre: Instance, x: number, z: number, alto: number, y0: number)
	for _ = 1, 3 do
		local h = alto * azar:NextNumber(0.5, 1)
		local cf = CFrame.new(x + azar:NextNumber(-0.25, 0.25), y0 + h * 0.45, z + azar:NextNumber(-0.25, 0.25))
			* CFrame.Angles(0, azar:NextNumber(0, math.pi * 2), 0)
			* CFrame.Angles(math.rad(azar:NextNumber(-25, 25)), 0, math.rad(azar:NextNumber(-12, 12)))
		P.cuna(padre, "Hierbajo", Vector3.new(0.05, h, azar:NextNumber(0.18, 0.35)), cf,
			COLOR.Hierbajo[azar:NextInteger(1, #COLOR.Hierbajo)], Enum.Material.Grass)
	end
end

-- Un trozo de cristal roto en el suelo.
local function cristal(padre: Instance, x: number, z: number, y0: number?)
	local p = P.cuna(padre, "Cristal", Vector3.new(0.03, azar:NextNumber(0.15, 0.5), azar:NextNumber(0.15, 0.5)),
		CFrame.new(x, (y0 or sueloEn(x, z)) + 0.03, z) * CFrame.Angles(0, azar:NextNumber(0, math.pi * 2), math.pi / 2),
		C.Cristal, Enum.Material.SmoothPlastic)
	p.Transparency = 0.4
	p.Reflectance = 0.1
end

local function papel(padre: Instance, x: number, z: number)
	local y = sueloEn(x, z)
	local color = COLOR.Papel[azar:NextInteger(1, #COLOR.Papel)]
	if azar:NextNumber() < 0.3 then
		P.bola(padre, "Papel", Vector3.one * azar:NextNumber(0.22, 0.38), CFrame.new(x, y + 0.13, z), color, Enum.Material.Fabric)
	else
		lamina(padre, "Papel", Vector3.new(azar:NextNumber(0.4, 0.8), 0.02, azar:NextNumber(0.5, 0.9)),
			CFrame.new(x, y + 0.014, z) * CFrame.Angles(math.rad(azar:NextNumber(-3, 3)), azar:NextNumber(0, math.pi), 0),
			color, Enum.Material.Fabric)
	end
end

local function lata(padre: Instance, x: number, z: number)
	local y = sueloEn(x, z)
	P.cilindro(padre, "Lata", Vector3.new(azar:NextNumber(0.28, 0.45), 0.25, 0.25),
		CFrame.new(x, y + 0.125, z) * CFrame.Angles(0, azar:NextNumber(0, math.pi * 2), 0),
		COLOR.Lata[azar:NextInteger(1, #COLOR.Lata)], Enum.Material.Metal)
end

local function vaso(padre: Instance, x: number, z: number)
	local y = sueloEn(x, z)
	local color = if azar:NextNumber() < 0.5 then Color3.fromRGB(146, 142, 132) else Color3.fromRGB(110, 40, 34)
	P.cilindro(padre, "Vaso", Vector3.new(0.45, 0.3, 0.3),
		CFrame.new(x, y + 0.15, z) * CFrame.Angles(0, azar:NextNumber(0, math.pi * 2), math.rad(4)), color,
		Enum.Material.SmoothPlastic)
end

local function colilla(padre: Instance, x: number, z: number)
	P.cilindro(padre, "Colilla", Vector3.new(0.22, 0.06, 0.06),
		CFrame.new(x, sueloEn(x, z) + 0.03, z) * CFrame.Angles(0, azar:NextNumber(0, math.pi * 2), 0),
		Color3.fromRGB(150, 138, 116), Enum.Material.Fabric)
end

------------------------------------------------------------------------------------------------------------------------
-- La explanada: losas, juntas, grietas con hierbajos, rayas, manchas de aceite, bordillos, rejillas y tapas.

local function losa(m: Model, xa: number, xb: number, za: number, zb: number)
	local cf = CFrame.new((xa + xb) / 2, SUELO - 0.15, (za + zb) / 2)
	if azar:NextNumber() < 0.25 then
		-- Hundida o torcida: el terreno se ha movido.
		cf = cf * CFrame.new(0, -azar:NextNumber(0.004, 0.015), 0)
			* CFrame.Angles(math.rad(azar:NextNumber(-0.3, 0.3)), 0, math.rad(azar:NextNumber(-0.3, 0.3)))
	end
	local color, material = C.Hormigon:Lerp(C.HormigonSucio, azar:NextNumber(0, 0.85)), Enum.Material.Concrete
	if azar:NextNumber() < 0.06 then
		color, material = C.AsfaltoViejo, Enum.Material.Asphalt -- parcheada con asfalto
	end
	local p = P.bloque(m, "Losa", Vector3.new(xb - xa - JUNTA, 0.3, zb - za - JUNTA), cf, color, material, true)
	p.CastShadow = false
	p:SetAttribute("SinSeparar", true)
	if azar:NextNumber() < 0.4 then
		P.mancha(p, Enum.NormalId.Top, nil, Color3.fromRGB(28, 26, 22), azar:NextNumber(0.45, 0.8))
	end
end

-- Grieta en zigzag desde (x, z) hacia `rumbo` (radianes en el suelo); en la punta suele salir un hierbajo.
local function grieta(m: Model, x: number, z: number, rumbo: number, tramos: number)
	local pos = Vector3.new(x, SUELO + 0.002, z)
	for _ = 1, tramos do
		local largo = azar:NextNumber(0.8, 2.2)
		rumbo += azar:NextNumber(-0.7, 0.7)
		local fin = pos + Vector3.new(math.cos(rumbo), 0, math.sin(rumbo)) * largo
		lamina(m, "Grieta", Vector3.new(azar:NextNumber(0.07, 0.16), 0.02, largo + 0.06), CFrame.lookAt((pos + fin) / 2, fin),
			COLOR.Grieta, Enum.Material.Asphalt)
		pos = fin
	end
	if azar:NextNumber() < 0.7 then
		hierbajo(m, pos.X, pos.Z, azar:NextNumber(0.35, 0.8), SUELO)
	end
end

-- Bordillo de hormigón de `desde` a `hasta` (en el suelo), en tramos con juntas; alguno roto o volcado.
local function bordillo(m: Model, desde: Vector3, hasta: Vector3)
	local total, u = (hasta - desde).Magnitude, (hasta - desde).Unit
	local giro = CFrame.lookAt(Vector3.zero, u) * CFrame.Angles(0, math.pi / 2, 0) -- su X a lo largo del bordillo
	local t = 0
	while t < total - 0.2 do
		local l = math.min(azar:NextNumber(3, 5), total - t)
		local centro = desde + u * (t + l / 2)
		local cf = CFrame.new(centro.X, 0.225, centro.Z) * giro -- de -0,05 a 0,5
		local color = COLOR.Bordillo:Lerp(C.HormigonSucio, azar:NextNumber(0, 0.6))
		local r = azar:NextNumber()
		if r < 0.08 then
			-- Roto: falta un trozo y los cascotes están al lado.
			local a = l * azar:NextNumber(0.35, 0.55)
			pieza(m, "Bordillo", Vector3.new(a - 0.06, 0.55, 0.6), cf * CFrame.new(-l / 2 + a / 2, 0, 0), color, Enum.Material.Concrete)
			pieza(m, "Bordillo", Vector3.new(l * 0.25, 0.4, 0.55), cf * CFrame.new(l / 2 - l * 0.125, -0.07, 0)
				* CFrame.Angles(math.rad(5), 0, math.rad(4)), color, Enum.Material.Concrete)
			for _ = 1, 3 do
				pieza(m, "Cascote", Vector3.new(azar:NextNumber(0.2, 0.45), azar:NextNumber(0.15, 0.3), azar:NextNumber(0.2, 0.4)),
					cf * CFrame.new(azar:NextNumber(-0.3, l / 2 - l * 0.3), -0.1, azar:NextNumber(-0.7, 0.7))
						* CFrame.Angles(azar:NextNumber(0, 1), azar:NextNumber(0, 3), azar:NextNumber(0, 1)), color, Enum.Material.Concrete)
			end
		elseif r < 0.2 then
			-- Hundido y volcado.
			pieza(m, "Bordillo", Vector3.new(l - 0.06, 0.55, 0.6), cf * CFrame.new(0, -0.08, 0)
				* CFrame.Angles(math.rad(azar:NextNumber(4, 9) * (if azar:NextNumber() < 0.5 then -1 else 1)), 0, 0), color,
				Enum.Material.Concrete)
		else
			pieza(m, "Bordillo", Vector3.new(l - 0.06, 0.55, 0.6), cf, color, Enum.Material.Concrete)
		end
		t += l
	end
end

-- Raya pintada de `a` a `b`, gastada: a trozos y de tonos distintos.
local function raya(m: Model, a: Vector3, b: Vector3, ancho: number)
	local total, u = (b - a).Magnitude, (b - a).Unit
	local t = 0
	while t < total - 0.1 do
		local l = math.min(azar:NextNumber(0.8, 3.2), total - t)
		if azar:NextNumber() < 0.8 then -- el resto, borrado
			local c = a + u * (t + l / 2)
			local pos = Vector3.new(c.X, SUELO + 0.012, c.Z)
			lamina(m, "Raya", Vector3.new(ancho, 0.02, l), CFrame.lookAt(pos, pos + u), C.Linea:Lerp(C.Hormigon, azar:NextNumber(0.15, 0.55)),
				Enum.Material.Concrete)
		end
		t += l + azar:NextNumber(0.1, 0.7)
	end
end

-- Mancha de aceite: una lámina invisible con una mancha negra encima.
local function aceite(m: Model, x: number, z: number, tam: number)
	local p = lamina(m, "Aceite", Vector3.new(tam, 0.02, tam * azar:NextNumber(0.6, 1)),
		CFrame.new(x, SUELO + 0.018 + azar:NextNumber(0, 0.004), z) * CFrame.Angles(0, azar:NextNumber(0, math.pi), 0), COLOR.Negro,
		Enum.Material.SmoothPlastic)
	p.Transparency = 1
	P.mancha(p, Enum.NormalId.Top, nil, Color3.fromRGB(8, 8, 7), azar:NextNumber(0.25, 0.5))
end

-- Rejilla de desagüe cuadrada: hueco negro, marco y barrotes oxidados.
local function rejilla(m: Model, x: number, z: number, tam: number, giro: number)
	local cf = CFrame.new(x, SUELO, z) * CFrame.Angles(0, giro, 0)
	lamina(m, "Hueco", Vector3.new(tam, 0.02, tam), cf * CFrame.new(0, 0.012, 0), Color3.fromRGB(8, 8, 8), Enum.Material.SmoothPlastic)
	for _, s in { -1, 1 } do
		lamina(m, "Marco", Vector3.new(tam + 0.24, 0.03, 0.12), cf * CFrame.new(0, 0.02, s * (tam / 2 + 0.06)), C.OxidoOscuro,
			Enum.Material.CorrodedMetal)
		lamina(m, "Marco", Vector3.new(0.12, 0.03, tam), cf * CFrame.new(s * (tam / 2 + 0.06), 0.02, 0), C.OxidoOscuro,
			Enum.Material.CorrodedMetal)
	end
	for i = 1, 5 do
		lamina(m, "Barrote", Vector3.new(0.09, 0.03, tam), cf * CFrame.new((i - 3) * tam / 6, 0.015, 0), C.Oxido,
			Enum.Material.CorrodedMetal)
	end
end

-- Tapa redonda de un depósito enterrado, con el color de su combustible casi borrado.
local function tapa(m: Model, x: number, z: number, color: Color3)
	columna(m, "Tapa", 0.05, 1.5, CFrame.new(x, SUELO + 0.02, z), C.Metal, Enum.Material.DiamondPlate)
	columna(m, "Pintura", 0.05, 0.8, CFrame.new(x, SUELO + 0.035, z), color, Enum.Material.Metal)
end

local function explanada()
	local m = grupo("Explanada")
	local base = P.bloque(m, "Base", Vector3.new(66, 0.5, 80), CFrame.new(40, SUELO - 0.3, 0), COLOR.Junta, Enum.Material.Concrete, true)
	base.CastShadow = false
	base:SetAttribute("SinSeparar", true)
	for f = 1, #FILAS - 1 do
		local za, zb = FILAS[f], FILAS[f + 1]
		-- A la altura de la tienda, al este solo queda la tira de detrás de ella.
		local este = if za >= TIENDA.z0 and zb <= TIENDA.z1 then { TIENDA.x1, 73 } else { 52, 59, 66, 73 }
		for _, cols in { OESTE, este } do
			for c = 1, #cols - 1 do
				losa(m, cols[c], cols[c + 1], za, zb)
			end
		end
	end
	for _, g in {
		{ 30, -30, 0.3, 5 }, { 44, -26, 2.2, 4 }, { 58, -33, 1, 5 }, { 64, -20, 2.8, 4 }, { 24, 22, -0.4, 5 },
		{ 38, 30, 1.9, 4 }, { 52, 27, 0.6, 5 }, { 66, 34, 3.4, 3 }, { 12, -20, 1.3, 4 }, { 12, 12, -1.2, 4 }, -- las de x 12: más dentro, que no se metan en la carretera
		{ 46, -12, 1.7, 3 }, { 47, 18, 0.2, 4 }, { 71.5, -6, 1.57, 5 }, { 20, -2, 0.9, 3 },
	} do
		grieta(m, g[1], g[2], g[3], g[4])
	end
	-- Hierbajos en las juntas (no encima de las islas), junto a la carretera y por los bordillos, dentro y fuera.
	for _ = 1, 14 do
		local x, z
		if azar:NextNumber() < 0.5 then
			x, z = OESTE[azar:NextInteger(2, #OESTE - 1)], azar:NextNumber(-39, 39)
		else
			x, z = azar:NextNumber(8, 51), FILAS[azar:NextInteger(2, #FILAS - 1)]
		end
		if not (x > 25 and x < 39 and math.abs(z) < 7.5) then
			hierbajo(m, x, z, azar:NextNumber(0.25, 0.6), SUELO)
		end
	end
	for _ = 1, 6 do
		hierbajo(m, 7.1, azar:NextNumber(-38, 38), azar:NextNumber(0.3, 0.6), SUELO)
	end
	for x = 22, 71, 3.5 do
		for _, lado in { -1, 1 } do
			if azar:NextNumber() < 0.3 then
				hierbajo(m, x + azar:NextNumber(-1, 1), lado * 39.6, azar:NextNumber(0.3, 0.7), SUELO)
			end
			if azar:NextNumber() < 0.4 then
				hierbajo(m, x + azar:NextNumber(-1.2, 1.2), lado * (40.9 + azar:NextNumber(0, 0.6)), azar:NextNumber(0.8, 1.7), 0)
			end
		end
	end
	for z = -38, 38, 3.5 do
		if azar:NextNumber() < 0.3 then
			hierbajo(m, 72.6, z + azar:NextNumber(-1, 1), azar:NextNumber(0.3, 0.7), SUELO)
		end
		if azar:NextNumber() < 0.4 then
			hierbajo(m, 73.9 + azar:NextNumber(0, 0.6), z + azar:NextNumber(-1.2, 1.2), azar:NextNumber(0.8, 1.7), 0)
		end
	end
	-- Bordillos al norte, al sur y al este; al oeste, la carretera (las entradas, x 7..20, sin bordillo).
	bordillo(m, Vector3.new(20, 0, -40.1), Vector3.new(72.8, 0, -40.1))
	bordillo(m, Vector3.new(20, 0, 40.1), Vector3.new(72.8, 0, 40.1))
	bordillo(m, Vector3.new(73.1, 0, -40.4), Vector3.new(73.1, 0, 40.4))
	for _, z in { -40.1, 40.1 } do
		P.cuna(m, "Bordillo", Vector3.new(0.6, 0.55, 1), CFrame.new(19.5, 0.225, z) * CFrame.Angles(0, math.rad(90), 0), COLOR.Bordillo,
			Enum.Material.Concrete)
	end
	-- Las plazas de los coches (x 11..17, mirando a -Z), casi borradas.
	for _, z in { -32, -16, 0, 16, 32 } do
		raya(m, Vector3.new(10.4, 0, z), Vector3.new(18.4, 0, z), 0.3)
	end
	raya(m, Vector3.new(18.6, 0, -32.15), Vector3.new(18.6, 0, 32.15), 0.3)
	for _, a in {
		{ 13.6, -25, 3.2 }, { 14.4, -7.4, 2.6 }, { 13.1, 9.6, 3.4 }, { 14.8, 23.4, 2.4 }, { 29.4, -1.2, 2.2 }, { 34.8, 1.6, 2.8 },
		{ 30.6, -9.6, 2.4 }, { 33.4, 9.4, 2 }, { 12.6, -37.2, 2.6 }, { 42.6, -29.8, 1.6 }, { 46.6, -10.2, 1.8 },
	} do
		aceite(m, a[1], a[2], a[3])
	end
	rejilla(m, 47.3, 12.2, 1.6, 0.1)
	rejilla(m, 40.4, -39, 1.5, 0)
	for i, color in { Color3.fromRGB(70, 74, 60), Color3.fromRGB(96, 40, 34), Color3.fromRGB(108, 96, 50) } do
		tapa(m, 24 + i * 2.6, -19.5, color)
	end
end

------------------------------------------------------------------------------------------------------------------------
-- La marquesina: la chapa (Chapa), el faldón, cuatro fluorescentes (LuzFalla) y los pilares sobre las islas.

-- Los fluorescentes, en el techo sobre las islas: dos zumban, dos tienen polillas y dos hacen sombra.
local TUBOS = {
	{ x = 28, z = -7, fallo = 0.1, zumba = false, polillas = true, sombras = false, brillo = 1, alcance = 22 },
	{ x = 36, z = -7, fallo = 0.35, zumba = true, polillas = false, sombras = true, brillo = 0.9, alcance = 22 },
	{ x = 28, z = 7, fallo = 0.2, zumba = false, polillas = false, sombras = true, brillo = 0.95, alcance = 22 },
	{ x = 36, z = 7, fallo = 0.6, zumba = true, polillas = true, sombras = false, brillo = 0.8, alcance = 20 },
}

local function pilar(m: Model, x: number, z: number)
	local y0 = ALTO_ISLA + 0.03 -- encima de la punta de la isla
	local alto = MQ.abajo - y0 - 0.1 -- sus puntas, dentro de la placa y de la brida (sin caras en el mismo plano)
	solido(m, "Pilar", Vector3.new(1, alto, 1), CFrame.new(x, y0 + 0.05 + alto / 2, z), C.Oxido:Lerp(C.MetalOscuro, 0.35),
		Enum.Material.CorrodedMetal)
	pieza(m, "Placa", Vector3.new(1.5, 0.1, 1.5), CFrame.new(x, y0 + 0.05, z), C.MetalOscuro, Enum.Material.Metal)
	pieza(m, "Brida", Vector3.new(1.5, 0.2, 1.5), CFrame.new(x, MQ.abajo - 0.1, z), C.MetalOscuro, Enum.Material.Metal)
	-- El protector de abajo, amarillo y negro, desteñido (las franjas sobresalen: si Separar engordase el amarillo, se
	-- las comería).
	lamina(m, "Protector", Vector3.new(1.12, 3, 1.12), CFrame.new(x, y0 + 1.6, z), COLOR.Amarillo, Enum.Material.SmoothPlastic)
	for k = 0, 2 do
		lamina(m, "Franja", Vector3.new(1.2, 0.42, 1.2), CFrame.new(x, y0 + 0.6 + k, z), COLOR.Negro, Enum.Material.SmoothPlastic)
	end
	for _ = 1, 2 do
		local n = ({ Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis })[azar:NextInteger(1, 4)]
		chorreton(m, Vector3.new(x, azar:NextNumber(6, 11.8), z) + n * 0.5, n, azar:NextNumber(1.2, 3.5))
	end
end

local function marquesina()
	local m = grupo("Marquesina")
	local techo = P.bloque(m, "Chapa", Vector3.new(MQ.ancho, MQ.alto, MQ.largo), CFrame.new(MQ.x, MQ.abajo + MQ.alto / 2, MQ.z),
		COLOR.Techo, Enum.Material.Metal, true) -- choca y tapa rayos: debajo no llueve
	P.etiqueta(techo, "Chapa")

	-- El faldón de alrededor: chapa roja desteñida con una raya crema, remates oscuros, chorretones y, a la carretera y a
	-- la tienda, la marca medio borrada. Por su borde de abajo gotea (Goteo).
	local x0, x1 = MQ.x - MQ.ancho / 2, MQ.x + MQ.ancho / 2
	local z0, z1 = MQ.z - MQ.largo / 2, MQ.z + MQ.largo / 2
	local G, ALTO, Y = 0.3, 2.2, MQ.abajo + MQ.alto / 2 -- grueso, alto y centro del faldón
	local lados = { -- centro de su cara de fuera, hacia fuera, largo y dónde gotea (a lo largo)
		{ Vector3.new(x0 - G, Y, MQ.z), -Vector3.xAxis, MQ.largo + 2 * G, { -11.2, -6.4, -1.6, 3.9, 9.6 } },
		{ Vector3.new(x1 + G, Y, MQ.z), Vector3.xAxis, MQ.largo + 2 * G, { -10.5, -4.2, 1.8, 7.3, 11.5 } },
		{ Vector3.new(MQ.x, Y, z0 - G), -Vector3.zAxis, MQ.ancho, { -6.8, -0.4, 6.1 } },
		{ Vector3.new(MQ.x, Y, z1 + G), Vector3.zAxis, MQ.ancho, { -7.6, 0.9, 5.4 } },
	}
	for i, lado in lados do
		local fuera, normal, largo = lado[1], lado[2], lado[3]
		local cara = CFrame.lookAt(fuera, fuera + normal) -- X a lo largo, Y arriba y -Z hacia fuera
		local faldon = solido(m, "Faldon", Vector3.new(largo, ALTO, G), cara * CFrame.new(0, 0, G / 2), COLOR.RojoViejo, Enum.Material.Metal)
		lamina(m, "Raya", Vector3.new(largo, 0.28, 0.04), cara * CFrame.new(0, -0.62, -0.02), COLOR.Crema, Enum.Material.Metal)
		local remate = largo + (if normal.X ~= 0 then 0.1 else -0.14) -- los de norte y sur acaban donde empiezan los otros
		pieza(m, "Remate", Vector3.new(remate, 0.14, G + 0.14), cara * CFrame.new(0, ALTO / 2 + 0.07, G / 2), C.MetalOscuro,
			Enum.Material.Metal)
		pieza(m, "Remate", Vector3.new(remate, 0.1, G + 0.14), cara * CFrame.new(0, -ALTO / 2 - 0.05, G / 2), C.MetalOscuro,
			Enum.Material.Metal)
		for _ = 1, 4 do
			local u = azar:NextNumber(-largo / 2 + 0.6, largo / 2 - 0.6)
			chorreton(m, (cara * CFrame.new(u, ALTO / 2 - 0.02, 0)).Position, normal, azar:NextNumber(0.5, 1.6))
		end
		if normal.X ~= 0 then
			local marca = lamina(m, "Marca", Vector3.new(5.6, 1.05, 0.05), cara * CFrame.new(-2.5, 0.28, -0.03),
				COLOR.RojoViejo:Lerp(C.Rojo, 0.6), Enum.Material.Metal)
			P.letrero(marca, Enum.NormalId.Front, "GAS", COLOR.Crema)
		end
		if i == 1 then
			-- A la carretera le falta una chapa: se ve el hueco y la chapa cuelga de una esquina.
			lamina(m, "Hueco", Vector3.new(2.4, 1.2, 0.04), cara * CFrame.new(8.2, 0.22, -0.025), Color3.fromRGB(16, 15, 14),
				Enum.Material.SmoothPlastic)
			pieza(m, "ChapaSuelta", Vector3.new(2.4, 1.2, 0.06), cara * CFrame.new(7, 0.82, -0.12)
				* CFrame.Angles(math.rad(-10), 0, math.rad(-38)) * CFrame.new(1.2, -0.6, 0), COLOR.RojoViejo, Enum.Material.Metal)
		end
		for _, u in lado[4] do
			P.etiqueta(P.punto(faldon, "Goteo", (cara * CFrame.new(u, -ALTO / 2 - 0.12, -0.1)).Position), "Goteo")
		end
	end

	-- Por debajo: juntas de las placas, humedades, una placa caída con cables sueltos.
	for _, z in { -9.75, -3.25, 3.25, 9.75 } do
		lamina(m, "Junta", Vector3.new(MQ.ancho, 0.02, 0.08), CFrame.new(MQ.x, MQ.abajo - 0.01, z), Color3.fromRGB(70, 68, 64),
			Enum.Material.Metal)
	end
	for _ = 1, 3 do
		local humedad = lamina(m, "Humedad", Vector3.new(azar:NextNumber(2, 4), 0.02, azar:NextNumber(2, 4)),
			CFrame.new(azar:NextNumber(24, 40), MQ.abajo - 0.03, azar:NextNumber(-11, 11)), C.Pintura, Enum.Material.SmoothPlastic)
		humedad.Transparency = 1
		P.mancha(humedad, Enum.NormalId.Bottom, nil, Color3.fromRGB(50, 44, 34), azar:NextNumber(0.3, 0.5))
	end
	lamina(m, "Agujero", Vector3.new(2.6, 0.02, 2.2), CFrame.new(31, MQ.abajo - 0.015, -11), Color3.fromRGB(12, 12, 12),
		Enum.Material.SmoothPlastic)
	pieza(m, "PlacaCaida", Vector3.new(2.5, 0.06, 2.1), CFrame.new(29.7, MQ.abajo - 0.05, -11) * CFrame.Angles(0, 0, math.rad(-62))
		* CFrame.new(1.25, 0, 0), COLOR.Techo, Enum.Material.Metal)
	tubo(m, "Cable", Vector3.new(31.4, MQ.abajo - 0.02, -10.4), Vector3.new(31.7, 10.9, -10.2), 0.06, COLOR.Negro, Enum.Material.Rubber)
	tubo(m, "Cable", Vector3.new(31.8, MQ.abajo - 0.02, -11.4), Vector3.new(31.2, 11.4, -11.8), 0.05, Color3.fromRGB(90, 30, 26),
		Enum.Material.Rubber)

	for i, t in TUBOS do
		pieza(m, "Lampara", Vector3.new(5, 0.3, 0.9), CFrame.new(t.x, MQ.abajo - 0.15, t.z), COLOR.Techo:Lerp(C.Pintura, 0.3),
			Enum.Material.Metal).CastShadow = false
		for _, dx in { -2.4, 2.4 } do
			pieza(m, "Portalamparas", Vector3.new(0.14, 0.24, 0.75), CFrame.new(t.x + dx, MQ.abajo - 0.36, t.z), C.MetalOscuro,
				Enum.Material.Metal)
		end
		local luz = P.cilindro(m, "Tubo", Vector3.new(4.66, 0.2, 0.2), CFrame.new(t.x, MQ.abajo - 0.42, t.z - 0.2), C.Tubo,
			Enum.Material.SmoothPlastic)
		luz.CastShadow = false
		P.luz(luz, "PointLight", t.brillo, t.alcance, COLOR.LuzTubo, t.sombras)
		P.etiqueta(luz, "LuzFalla", { Fallo = t.fallo, Zumba = t.zumba })
		if t.polillas then
			P.etiqueta(luz, "Polillas")
		end
		-- El otro tubo, fundido; en una lámpara ni está, y en otra el difusor cuelga de un lado.
		if i ~= 3 then
			P.cilindro(m, "TuboFundido", Vector3.new(4.66, 0.2, 0.2), CFrame.new(t.x, MQ.abajo - 0.42, t.z + 0.2),
				Color3.fromRGB(96, 98, 92), Enum.Material.SmoothPlastic).CastShadow = false
		end
		if i == 2 then
			local difusor = pieza(m, "Difusor", Vector3.new(4.8, 0.04, 0.9), CFrame.new(t.x, MQ.abajo - 0.3, t.z + 0.45)
				* CFrame.Angles(math.rad(-70), 0, math.rad(6)) * CFrame.new(0, 0, -0.45), Color3.fromRGB(150, 150, 140),
				Enum.Material.SmoothPlastic)
			difusor.Transparency = 0.5
		end
	end

	for _, zc in ISLAS do
		for _, dx in { -PUNTA, PUNTA } do
			pilar(m, MQ.x + dx, zc)
		end
	end
	-- Un extintor en un pilar, una cámara vieja mirando a los surtidores y el "prohibido fumar" hacia la tienda.
	local e = Vector3.new(MQ.x - PUNTA - 0.74, 4.6, ISLAS[1])
	columna(m, "Extintor", 1.3, 0.44, CFrame.new(e), Color3.fromRGB(110, 30, 26), Enum.Material.Metal)
	pieza(m, "Valvula", Vector3.new(0.2, 0.25, 0.22), CFrame.new(e + Vector3.new(0, 0.77, 0)), C.MetalOscuro, Enum.Material.Metal)
	tubo(m, "Manguera", e + Vector3.new(-0.05, 0.8, 0.08), e + Vector3.new(-0.26, 0.1, 0.18), 0.06, COLOR.Negro, Enum.Material.Rubber)
	pieza(m, "Abrazadera", Vector3.new(0.5, 0.1, 0.5), CFrame.new(e + Vector3.new(0.02, 0.2, 0)), C.MetalOscuro, Enum.Material.Metal)
	local camara = Vector3.new(MQ.x + PUNTA - 1.1, 10.4, ISLAS[1])
	local mira = CFrame.lookAt(camara, Vector3.new(29, 0, 0))
	tubo(m, "Soporte", Vector3.new(MQ.x + PUNTA - 0.5, 10.6, ISLAS[1]), camara, 0.12, C.MetalOscuro, Enum.Material.Metal)
	pieza(m, "Camara", Vector3.new(0.38, 0.38, 0.9), mira, C.Pintura:Lerp(C.HormigonSucio, 0.5), Enum.Material.SmoothPlastic)
	pieza(m, "Objetivo", Vector3.new(0.26, 0.26, 0.06), mira * CFrame.new(0, 0, -0.47), COLOR.Negro, Enum.Material.SmoothPlastic)
	local placa = pieza(m, "Prohibido", Vector3.new(0.05, 1.1, 1.1), CFrame.new(MQ.x + PUNTA + 0.53, 6.4, ISLAS[2]),
		Color3.fromRGB(140, 136, 124), Enum.Material.SmoothPlastic)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Right
	gui.LightInfluence = 1
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.MaxDistance = 80
	local rojo = Color3.fromRGB(120, 32, 26)
	local function trazo(tam: UDim2, pos: UDim2, color: Color3, giro: number?): Frame
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = tam
		f.Position = pos
		f.Rotation = giro or 0
		f.BackgroundColor3 = color
		f.BorderSizePixel = 0
		f.Parent = gui
		return f
	end
	local aro = trazo(UDim2.fromScale(0.82, 0.82), UDim2.fromScale(0.5, 0.5), Color3.fromRGB(150, 144, 130))
	local redondo = Instance.new("UICorner")
	redondo.CornerRadius = UDim.new(0.5, 0)
	redondo.Parent = aro
	local borde = Instance.new("UIStroke")
	borde.Color = rojo
	borde.Thickness = 6
	borde.Parent = aro
	trazo(UDim2.fromScale(0.5, 0.1), UDim2.fromScale(0.45, 0.52), Color3.fromRGB(170, 164, 150)) -- el cigarro
	trazo(UDim2.fromScale(0.1, 0.1), UDim2.fromScale(0.75, 0.52), Color3.fromRGB(100, 64, 40))
	trazo(UDim2.fromScale(0.9, 0.08), UDim2.fromScale(0.5, 0.5), rojo, 45)
	gui.Parent = placa
end

------------------------------------------------------------------------------------------------------------------------
-- Las islas con los surtidores (viejos, oxidados y sin corriente), una papelera y un cubo con escobilla en cada una.

-- Surtidor de cara a los dos carriles (±Z), con su base en `pf` (encima de la isla). En el `roto`, una manguera se ha
-- caído y el boquerel está en el suelo.
local function surtidor(m: Model, pf: CFrame, numeros: { string }, roto: boolean)
	solido(m, "Zocalo", Vector3.new(3, 0.35, 1.7), pf * CFrame.new(0, 0.175, 0), C.MetalOscuro, Enum.Material.CorrodedMetal)
	solido(m, "Cuerpo", Vector3.new(2.6, 3, 1.35), pf * CFrame.new(0, 1.85, 0), COLOR.RojoViejo:Lerp(C.Oxido, 0.2), Enum.Material.Metal)
	solido(m, "Cabeza", Vector3.new(2.7, 1.5, 1.5), pf * CFrame.new(0, 4.1, 0), COLOR.Crema:Lerp(C.HormigonSucio, 0.25), Enum.Material.Metal)
	local copete = pieza(m, "Copete", Vector3.new(2.5, 0.75, 0.4), pf * CFrame.new(0, 5.225, 0), COLOR.Crema, Enum.Material.SmoothPlastic)
	for _, cara in { Enum.NormalId.Front, Enum.NormalId.Back } do
		P.letrero(copete, cara, "GAS", COLOR.RojoViejo).MaxDistance = 90
	end
	if not roto then
		-- La tapa de un lado, abierta y torcida.
		pieza(m, "Registro", Vector3.new(0.04, 1.4, 0.9), pf * CFrame.new(-1.36, 1.7, 0.1) * CFrame.Angles(0, math.rad(10), math.rad(3)),
			COLOR.RojoViejo, Enum.Material.Metal)
	end
	for k, s in { -1, 1 } do
		-- Marcos en las caras del cuerpo y de la cabeza, con -Z hacia el carril; u < 0 queda a la derecha de quien mira.
		local giro = CFrame.Angles(0, if s < 0 then 0 else math.pi, 0)
		local cuerpo = pf * CFrame.new(0, 0, s * 0.675) * giro
		local cabeza = pf * CFrame.new(0, 0, s * 0.75) * giro
		local pantalla = lamina(m, "Pantalla", Vector3.new(1.9, 0.62, 0.05), cabeza * CFrame.new(0, 4.35, -0.025), COLOR.Pantalla,
			Enum.Material.SmoothPlastic)
		local g1 = P.letrero(pantalla, Enum.NormalId.Front, "0.00", COLOR.Apagado)
		local precio = lamina(m, "Precio", Vector3.new(1.2, 0.34, 0.05), cabeza * CFrame.new(0.25, 3.78, -0.025), COLOR.Pantalla,
			Enum.Material.SmoothPlastic)
		local g2 = P.letrero(precio, Enum.NormalId.Front, "1.29", Color3.fromRGB(78, 64, 42))
		local numero = lamina(m, "Numero", Vector3.new(0.5, 0.5, 0.04), cuerpo * CFrame.new(0.85, 2.7, -0.02), COLOR.Crema,
			Enum.Material.SmoothPlastic)
		local g3 = P.letrero(numero, Enum.NormalId.Front, numeros[k], C.MetalOscuro)
		for _, g in { g1, g2, g3 } do
			g.PixelsPerStud = 80
			g.MaxDistance = 60
		end
		parche(m, cuerpo, 0, 0.47, 2.5, 0.2) -- óxido por abajo
		for _ = 1, 2 do
			parche(m, cuerpo, azar:NextNumber(-0.9, 0.9), azar:NextNumber(0.6, 1.6), azar:NextNumber(0.35, 0.8), azar:NextNumber(0.3, 0.7))
		end
		pieza(m, "Funda", Vector3.new(0.55, 0.7, 0.3), cuerpo * CFrame.new(-0.95, 2.55, -0.15), C.MetalOscuro, Enum.Material.Metal)
		local salida = (pf * CFrame.new(s * 1.38, 4.3, s * 0.35)).Position -- sale del lado de la cabeza
		if roto and s > 0 then
			-- Caída: baja por el lado, cruza el borde de la isla y acaba en el suelo con el boquerel.
			local puntos = {}
			for _, q in {
				Vector3.new(1.38, 4.3, 0.35), Vector3.new(1.55, 2.8, 0.5), Vector3.new(1.62, 1.3, 0.75), Vector3.new(1.65, 0.3, 1.05),
				Vector3.new(1.6, 0.1, 1.5), Vector3.new(1.45, -0.36, 1.85), Vector3.new(1.25, -0.42, 2.3), Vector3.new(1.05, -0.42, 2.7),
			} do
				table.insert(puntos, (pf * CFrame.new(q)).Position)
			end
			quebrada(m, puntos, 0.18, COLOR.Negro)
			local suelo = pf * CFrame.new(0.85, -0.38, 2.95) * CFrame.Angles(0, math.rad(30), math.rad(90))
			pieza(m, "Boquerel", Vector3.new(0.2, 0.62, 0.36), suelo, COLOR.Negro, Enum.Material.Plastic)
			tubo(m, "Canon", (suelo * CFrame.new(0, -0.3, -0.1)).Position, (suelo * CFrame.new(0, -0.72, -0.18)).Position, 0.1, C.Metal,
				Enum.Material.Metal)
		else
			local boca = cuerpo * CFrame.new(-0.95, 3.05, -0.28)
			pieza(m, "Boquerel", Vector3.new(0.2, 0.62, 0.36), boca * CFrame.Angles(math.rad(12), 0, 0), COLOR.Negro, Enum.Material.Plastic)
			tubo(m, "Canon", (cuerpo * CFrame.new(-0.95, 2.85, -0.22)).Position, (cuerpo * CFrame.new(-0.95, 2.4, -0.12)).Position, 0.1,
				C.Metal, Enum.Material.Metal)
			local final = (pf * CFrame.new(s * 0.95, 3.2, s * 1.12)).Position
			curva(m, salida, salida + pf:VectorToWorldSpace(Vector3.new(s * 0.3, -5.1, s * 0.3)),
				final + pf:VectorToWorldSpace(Vector3.new(s * 0.5, -3.9, s * 0.15)), final, 8, 0.18, COLOR.Negro)
		end
	end
end

-- Papelera de chapa con su bolsa negra y basura asomando; `cf` en la isla, debajo de su centro.
local function papelera(m: Model, cf: CFrame)
	pieza(m, "Papelera", Vector3.new(1, 1.84, 1), cf * CFrame.new(0, 0.92, 0), Color3.fromRGB(50, 56, 50), Enum.Material.CorrodedMetal)
	pieza(m, "Aro", Vector3.new(1.06, 0.12, 1.06), cf * CFrame.new(0, 1.9, 0), C.MetalOscuro, Enum.Material.Metal)
	pieza(m, "Bolsa", Vector3.new(0.88, 0.03, 0.88), cf * CFrame.new(0, 1.975, 0), COLOR.Negro, Enum.Material.Plastic)
	pieza(m, "Bolsa", Vector3.new(1, 0.36, 0.03), cf * CFrame.new(0.05, 1.8, 0.545) * CFrame.Angles(math.rad(-6), 0, 0), COLOR.Negro,
		Enum.Material.Plastic)
	columna(m, "Vaso", 0.42, 0.26, cf * CFrame.new(-0.2, 2.15, 0.15) * CFrame.Angles(math.rad(14), 0, math.rad(-9)),
		Color3.fromRGB(146, 142, 132), Enum.Material.SmoothPlastic)
	P.bola(m, "Papel", Vector3.one * 0.32, cf * CFrame.new(0.22, 2.08, -0.18), COLOR.Papel[1], Enum.Material.Fabric)
end

-- Cubo de agua sucia con la escobilla de los cristales; el `volcado`, tumbado con el agua por la isla.
local function cubo(m: Model, cf: CFrame, volcado: boolean)
	local plastico = Color3.fromRGB(50, 58, 68)
	if not volcado then
		columna(m, "Cubo", 1, 0.95, cf * CFrame.new(0, 0.5, 0), plastico, Enum.Material.Plastic)
		columna(m, "AguaSucia", 0.03, 0.86, cf * CFrame.new(0, 1, 0), Color3.fromRGB(42, 40, 32), Enum.Material.SmoothPlastic)
		tubo(m, "Palo", (cf * CFrame.new(0.12, 0.7, 0.08)).Position, (cf * CFrame.new(0.55, 2.6, 0.35)).Position, 0.08, C.Madera,
			Enum.Material.Wood)
		tubo(m, "Asa", (cf * CFrame.new(-0.46, 0.95, 0)).Position, (cf * CFrame.new(0.2, 1.25, 0.42)).Position, 0.04, C.MetalOscuro,
			Enum.Material.Metal)
		return
	end
	P.cilindro(m, "Cubo", Vector3.new(1, 0.95, 0.95), cf * CFrame.new(0, 0.475, 0) * CFrame.Angles(0, math.rad(30), 0), plastico,
		Enum.Material.Plastic)
	local agua = lamina(m, "Agua", Vector3.new(1.8, 0.02, 1.1), cf * CFrame.new(0.95, 0.012, -0.1) * CFrame.Angles(0, math.rad(20), 0),
		COLOR.Charco, Enum.Material.SmoothPlastic)
	agua.Transparency = 0.2
	tubo(m, "Palo", (cf * CFrame.new(-0.5, 0.06, 0.5)).Position, (cf * CFrame.new(1.4, 0.06, 0.95)).Position, 0.08, C.Madera,
		Enum.Material.Wood)
	pieza(m, "Escobilla", Vector3.new(0.75, 0.12, 0.2), cf * CFrame.new(-0.6, 0.06, 0.4) * CFrame.Angles(0, math.rad(77), 0),
		C.Goma, Enum.Material.Rubber)
end

local function isla(n: number, zc: number)
	local m = grupo(`Isla{n}`)
	local base = CFrame.new(MQ.x, SUELO, zc)
	local arriba = ALTO_ISLA - SUELO
	solido(m, "Isla", Vector3.new(2 * PUNTA, 0.55, 3.2), base * CFrame.new(0, 0.225, 0), C.Hormigon:Lerp(C.Pintura, 0.12),
		Enum.Material.Concrete)
	for _, dx in { -PUNTA, PUNTA } do
		columna(m, "Punta", 0.58, 3.2, base * CFrame.new(dx, 0.24, 0), COLOR.Amarillo:Lerp(C.HormigonSucio, 0.35), Enum.Material.Concrete,
			true)
	end
	for _, s in { -1, 1 } do
		lamina(m, "Bordillo", Vector3.new(7.9, 0.04, 0.28), base * CFrame.new(0, arriba, s * 1.46), COLOR.Amarillo:Lerp(C.HormigonSucio, 0.55),
			Enum.Material.Concrete)
	end
	surtidor(m, base * CFrame.new(0, arriba, 0), { tostring(2 * n - 1), tostring(2 * n) }, n == 2)
	papelera(m, base * CFrame.new(3, arriba, if n == 1 then -0.2 else 0.2))
	cubo(m, base * CFrame.new(-3, arriba, if n == 1 then 0.35 else -0.3), n == 2)
	if n == 2 then
		aceite(m, MQ.x + 1, zc + 2.9, 1.4) -- donde gotea el boquerel caído
	end
end

------------------------------------------------------------------------------------------------------------------------
-- El cartel alto: dos postes, la caja con "GAS" (cada letra con su luz) y el panel de precios debajo.

local function cartel()
	local m = grupo("Cartel")
	local K = CARTEL
	local Y = 14 -- centro de la caja (de 11,5 a 16,5)
	for _, u in { -2.5, 2.5 } do
		solido(m, "Zapata", Vector3.new(1.6, 0.9, 1.6), K * CFrame.new(u, 0.25, 0), C.HormigonSucio, Enum.Material.Concrete)
		solido(m, "Poste", Vector3.new(0.8, 15.4, 0.8), K * CFrame.new(u, 8.4, 0), C.Oxido:Lerp(C.MetalOscuro, 0.45), Enum.Material.CorrodedMetal)
		for _, lado in { 1, -1 } do
			chorreton(m, (K * CFrame.new(u + azar:NextNumber(-0.2, 0.2), azar:NextNumber(6, 11), -0.4 * lado)).Position, K.LookVector * lado,
				azar:NextNumber(1.5, 4))
		end
		hierbajo(m, (K * Vector3.new(u + 0.9, 0, 0.6)).X, (K * Vector3.new(u + 0.9, 0, 0.6)).Z, 1.3, 0)
	end
	pieza(m, "Caja", Vector3.new(12, 5, 1), K * CFrame.new(0, Y, 0), COLOR.FondoCartel, Enum.Material.Metal)
	for _, v in { -2.6, 2.6 } do
		pieza(m, "Marco", Vector3.new(12.4, 0.2, 1.18), K * CFrame.new(0, Y + v, 0), C.MetalOscuro, Enum.Material.Metal)
	end
	for _, u in { -6.1, 6.1 } do
		pieza(m, "Marco", Vector3.new(0.2, 5.4, 1.18), K * CFrame.new(u, Y, 0), C.MetalOscuro, Enum.Material.Metal)
	end
	-- Cada letra con su luz (LuzFalla); la A, casi muerta. Por detrás el orden se invierte, así que cada pieza lleva
	-- delante una letra y detrás la que toca para que por las dos caras se lea "GAS".
	for i, l in { { "S", "G", 0.25 }, { "A", "A", 0.85 }, { "G", "S", 0.15 } } do
		local letra = pieza(m, "Letra", Vector3.new(3.2, 4.1, 1.1), K * CFrame.new((i - 2) * 3.7, Y, 0),
			COLOR.FondoCartel:Lerp(COLOR.LetraCartel, 0.15), Enum.Material.SmoothPlastic)
		letra.CastShadow = false
		for k, cara in { Enum.NormalId.Front, Enum.NormalId.Back } do
			-- Que se vea encendida sin Neon; la luz de dentro, floja.
			P.letrero(letra, cara, l[k], COLOR.LetraCartel).LightInfluence = 0
		end
		P.luz(letra, "PointLight", 0.75, 16, COLOR.LuzCartel)
		P.etiqueta(letra, "LuzFalla", { Fallo = l[3], Zumba = false })
	end
	-- Precios: al de abajo se le ha caído un número, que está en la hierba.
	pieza(m, "Precios", Vector3.new(8.4, 2.8, 0.5), K * CFrame.new(0, 9.4, 0), COLOR.Precios, Enum.Material.SmoothPlastic)
	for _, v in { -1.45, 1.45 } do
		pieza(m, "Marco", Vector3.new(8.6, 0.14, 0.6), K * CFrame.new(0, 9.4 + v, 0), C.MetalOscuro, Enum.Material.Metal)
	end
	for f, texto in { "1.29", "1. 9" } do
		local fila = pieza(m, "Fila", Vector3.new(7.6, 1.05, 0.56), K * CFrame.new(0, if f == 1 then 10 else 8.8, 0),
			COLOR.Precios:Lerp(C.Pintura, 0.1), Enum.Material.SmoothPlastic)
		for _, cara in { Enum.NormalId.Front, Enum.NormalId.Back } do
			P.letrero(fila, cara, texto, COLOR.Tinta).MaxDistance = 150
		end
	end
	local caido = lamina(m, "NumeroCaido", Vector3.new(0.55, 0.03, 0.8), K * CFrame.new(1.4, 0.03, -2.2) * CFrame.Angles(0, math.rad(25), 0),
		COLOR.Precios, Enum.Material.SmoothPlastic)
	P.letrero(caido, Enum.NormalId.Top, "4", COLOR.Tinta).MaxDistance = 40
	for _, lado in { 1, -1 } do -- chorretones de óxido por delante y por detrás
		for _ = 1, 3 do
			chorreton(m, (K * CFrame.new(azar:NextNumber(-3.8, 3.8), 10.8, -0.25 * lado)).Position, K.LookVector * lado,
				azar:NextNumber(0.5, 1.6))
		end
		for _, u in { -1.85, 1.85 } do
			chorreton(m, (K * CFrame.new(u + azar:NextNumber(-0.1, 0.1), Y + 2.4, -0.5 * lado)).Position, K.LookVector * lado,
				azar:NextNumber(1.2, 3.2))
		end
	end
	-- Escalera y pasarela de mantenimiento por detrás, y la caja de la luz abajo.
	local escalera = K * CFrame.new(2.5, 0, 0.62)
	for _, du in { -0.32, 0.32 } do
		pieza(m, "Larguero", Vector3.new(0.09, 9.6, 0.09), escalera * CFrame.new(du, 6.4, 0), C.MetalOscuro, Enum.Material.CorrodedMetal)
	end
	for k = 0, 8 do
		pieza(m, "Peldano", Vector3.new(0.64, 0.07, 0.07), escalera * CFrame.new(0, 2.2 + k * 1.05, 0), C.MetalOscuro,
			Enum.Material.CorrodedMetal)
	end
	pieza(m, "Pasarela", Vector3.new(8.2, 0.1, 1), K * CFrame.new(0, 11.25, 1.05), C.MetalOscuro, Enum.Material.DiamondPlate)
	pieza(m, "Baranda", Vector3.new(8.2, 0.08, 0.08), K * CFrame.new(0, 12.3, 1.5), C.MetalOscuro, Enum.Material.Metal)
	for _, u in { -4, 0, 4 } do
		pieza(m, "Baranda", Vector3.new(0.08, 1.05, 0.08), K * CFrame.new(u, 11.8, 1.5), C.MetalOscuro, Enum.Material.Metal)
	end
	pieza(m, "CajaLuz", Vector3.new(0.7, 0.9, 0.35), K * CFrame.new(-2.5, 1.6, 0.6), C.MetalOscuro, Enum.Material.Metal)
	tubo(m, "Tubo", (K * Vector3.new(-2.5, 1.15, 0.62)), (K * Vector3.new(-2.5, 0, 0.62)), 0.12, C.MetalOscuro, Enum.Material.Metal)
	-- Una botella rota en la hierba.
	local botella = K * CFrame.new(-1.6, 0, -1.4)
	P.cilindro(m, "Botella", Vector3.new(0.55, 0.2, 0.2), botella * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, math.rad(40), 0),
		Color3.fromRGB(46, 62, 44), Enum.Material.SmoothPlastic).Transparency = 0.3
	for _ = 1, 5 do
		local p = (botella * CFrame.new(azar:NextNumber(-0.8, 0.8), 0, azar:NextNumber(-0.8, 0.8))).Position
		cristal(m, p.X, p.Z, 0)
	end
end

------------------------------------------------------------------------------------------------------------------------
-- La cabina de teléfono: oxidada, con un cristal roto, la puerta colgando, el auricular colgando del cable y una
-- bombilla que casi no va.

local function cabina()
	local m = grupo("Cabina")
	local bf = CFrame.new(48, SUELO, 22) * CFrame.Angles(0, 0, math.rad(1.2)) -- la puerta a -Z (hacia la tienda); algo torcida
	solido(m, "Base", Vector3.new(3.8, 0.25, 3.8), bf * CFrame.new(0, 0.125, 0), C.HormigonSucio, Enum.Material.Concrete)
	for _, x in { -1.49, 1.49 } do
		for _, z in { -1.49, 1.49 } do
			solido(m, "Poste", Vector3.new(0.22, 7.6, 0.22), bf * CFrame.new(x, 4.05, z), COLOR.Cabina, Enum.Material.CorrodedMetal)
		end
	end
	local techo = solido(m, "Techo", Vector3.new(3.6, 0.3, 3.6), bf * CFrame.new(0, 8, 0), COLOR.Cabina, Enum.Material.CorrodedMetal)
	pieza(m, "Rotulo", Vector3.new(3, 0.6, 3), bf * CFrame.new(0, 8.45, 0), Color3.fromRGB(36, 40, 38), Enum.Material.Metal)
	for _, p in { Vector3.new(-0.9, 7.82, -1.86), Vector3.new(0.85, 7.82, -1.86), Vector3.new(1.86, 7.82, 0.6) } do
		P.etiqueta(P.punto(techo, "Goteo", bf * p), "Goteo")
	end
	-- Fondo de chapa (con el teléfono), un lado de cristal y el otro roto.
	local fondo = solido(m, "Fondo", Vector3.new(2.76, 7.6, 0.08), bf * CFrame.new(0, 4.05, 1.49), COLOR.Cabina, Enum.Material.CorrodedMetal)
	P.mancha(fondo, Enum.NormalId.Front, nil, Color3.fromRGB(30, 26, 20), 0.5)
	local vidrio = C.Cristal:Lerp(COLOR.Cabina, 0.3)
	for _, x in { -1.49, 1.49 } do
		local w = bf * CFrame.new(x, 0, 0) * CFrame.Angles(0, math.rad(90), 0) -- X a lo largo de la pared
		solido(m, "Zocalo", Vector3.new(2.76, 1, 0.08), w * CFrame.new(0, 0.75, 0), COLOR.Cabina, Enum.Material.CorrodedMetal)
		pieza(m, "Remate", Vector3.new(2.76, 0.3, 0.08), w * CFrame.new(0, 7.7, 0), COLOR.Cabina, Enum.Material.CorrodedMetal)
		if x < 0 then
			local cr = solido(m, "Cristal", Vector3.new(2.76, 6.3, 0.05), w * CFrame.new(0, 4.4, 0), vidrio, Enum.Material.SmoothPlastic)
			cr.Transparency = 0.62
			cr.Reflectance = 0.05
			P.mancha(cr, Enum.NormalId.Front, nil, Color3.fromRGB(40, 36, 30), 0.55)
		else
			-- Roto: quedan trozos en las esquinas del marco; el resto está por el suelo.
			for _, t in {
				{ -0.63, 2.85, 1.5, 3.2, -90, 0 }, { 0.83, 6.3, 1.1, 2.5, -90, 180 }, { 1.03, 1.8, 0.7, 1.1, 90, 0 },
				{ -0.98, 6.75, 0.8, 1.6, 90, 180 },
			} do
				local trozo = P.cuna(m, "Cristal", Vector3.new(0.04, t[4], t[3]), w * CFrame.new(t[1], t[2], 0)
					* CFrame.Angles(0, 0, math.rad(t[6])) * CFrame.Angles(0, math.rad(t[5]), 0), vidrio, Enum.Material.SmoothPlastic)
				trozo.Transparency = 0.55
			end
		end
	end
	for _ = 1, 4 do
		local p = bf * Vector3.new(azar:NextNumber(-1.1, 1.1), 0, azar:NextNumber(-1.1, 1.1))
		cristal(m, p.X, p.Z, SUELO + 0.25)
	end
	for _ = 1, 6 do
		local p = bf * Vector3.new(azar:NextNumber(2.1, 3.4), 0, azar:NextNumber(-1.6, 1.8))
		cristal(m, p.X, p.Z)
	end
	-- La puerta, abierta hacia fuera y colgando de la bisagra de arriba.
	local puerta = bf * CFrame.new(-1.49, 0, -1.49) * CFrame.Angles(0, math.rad(105), 0) * CFrame.Angles(0, 0, math.rad(-2.5))
		* CFrame.new(1.37, 3.85, 0)
	pieza(m, "Puerta", Vector3.new(2.5, 6.5, 0.04), puerta, vidrio, Enum.Material.SmoothPlastic).Transparency = 0.62
	for _, u in { -1.3, 1.3 } do
		pieza(m, "Puerta", Vector3.new(0.1, 6.9, 0.08), puerta * CFrame.new(u, 0, 0), COLOR.Cabina, Enum.Material.CorrodedMetal)
	end
	for _, v in { -3.4, 3.4 } do
		pieza(m, "Puerta", Vector3.new(2.7, 0.1, 0.08), puerta * CFrame.new(0, v, 0), COLOR.Cabina, Enum.Material.CorrodedMetal)
	end
	-- El teléfono: la horquilla vacía y el auricular colgando de su cordón.
	local tel = bf * CFrame.new(0.35, 4.6, 1.2)
	pieza(m, "Telefono", Vector3.new(0.9, 1.5, 0.45), tel, Color3.fromRGB(40, 42, 42), Enum.Material.Metal)
	pieza(m, "Teclado", Vector3.new(0.42, 0.5, 0.04), tel * CFrame.new(0.05, -0.1, -0.24), Color3.fromRGB(84, 84, 80), Enum.Material.Metal)
	pieza(m, "Horquilla", Vector3.new(0.22, 0.4, 0.2), tel * CFrame.new(-0.42, 0.35, -0.3), C.MetalOscuro, Enum.Material.Metal)
	pieza(m, "Repisa", Vector3.new(1.3, 0.08, 0.6), bf * CFrame.new(0.35, 3.55, 1.12), COLOR.Cabina, Enum.Material.Metal)
	local a = (tel * CFrame.new(-0.4, -0.75, -0.1)).Position
	local b = (bf * CFrame.new(-0.3, 1.85, 0.8)).Position
	local antes = a
	for k = 1, 6 do
		local punto = a:Lerp(b, k / 6) + bf.RightVector * (if k % 2 == 0 then 0.07 else -0.07)
		tubo(m, "Cordon", antes, punto, 0.05, COLOR.Negro, Enum.Material.Rubber)
		antes = punto
	end
	local auricular = CFrame.new(antes) * bf.Rotation * CFrame.Angles(math.rad(8), math.rad(20), math.rad(6)) * CFrame.new(0, -0.45, 0)
	pieza(m, "Auricular", Vector3.new(0.2, 0.9, 0.2), auricular, COLOR.Negro, Enum.Material.Plastic)
	for _, v in { -0.42, 0.42 } do
		pieza(m, "Auricular", Vector3.new(0.3, 0.22, 0.34), auricular * CFrame.new(0, v, -0.08), COLOR.Negro, Enum.Material.Plastic)
	end
	pieza(m, "Portalamparas", Vector3.new(0.5, 0.1, 0.5), bf * CFrame.new(0, 7.8, 0), C.MetalOscuro, Enum.Material.Metal)
	local bombilla = P.bola(m, "Bombilla", Vector3.one * 0.38, bf * CFrame.new(0, 7.56, 0), C.Bombilla, Enum.Material.SmoothPlastic)
	P.luz(bombilla, "PointLight", 0.55, 11, COLOR.LuzBombilla)
	P.etiqueta(bombilla, "LuzFalla", { Fallo = 0.7, Zumba = false })
	-- Basura dentro: papeles y colillas.
	for _ = 1, 2 do
		local p = bf * Vector3.new(azar:NextNumber(-1, 1), 0, azar:NextNumber(-1, 1))
		lamina(m, "Papel", Vector3.new(0.6, 0.02, 0.8), CFrame.new(p.X, SUELO + 0.265, p.Z) * CFrame.Angles(0, azar:NextNumber(0, 3), 0),
			COLOR.Papel[2], Enum.Material.Fabric)
	end
	for _ = 1, 3 do
		local p = bf * Vector3.new(azar:NextNumber(-1.1, 1.1), 0, azar:NextNumber(-1.1, 1.1))
		P.cilindro(m, "Colilla", Vector3.new(0.22, 0.06, 0.06), CFrame.new(p.X, SUELO + 0.28, p.Z) * CFrame.Angles(0, azar:NextNumber(0, 6), 0),
			Color3.fromRGB(150, 138, 116), Enum.Material.Fabric)
	end
end

------------------------------------------------------------------------------------------------------------------------
-- El contenedor verde, oxidado, con una tapa medio abierta, bolsas alrededor y un palé apoyado.

local function contenedor()
	local m = grupo("Contenedor")
	local cf = CFrame.new(60, SUELO, 20) * CFrame.Angles(0, math.rad(-4), 0) -- las bisagras atrás (-Z, hacia la tienda)
	for _, x in { -3.1, 3.1 } do
		for _, z in { -1.4, 1.4 } do
			P.cilindro(m, "Rueda", Vector3.new(0.25, 0.5, 0.5), cf * CFrame.new(x, 0.25, z), C.Goma, Enum.Material.Rubber)
		end
	end
	local cuerpo = solido(m, "Cuerpo", Vector3.new(7, 3.4, 3.6), cf * CFrame.new(0, 2.25, 0), COLOR.Verde, Enum.Material.CorrodedMetal)
	P.mancha(cuerpo, Enum.NormalId.Back, nil, Color3.fromRGB(62, 14, 12), 0.55) -- algo oscuro chorreando por delante
	pieza(m, "Borde", Vector3.new(7.2, 0.25, 3.8), cf * CFrame.new(0, 4.075, 0), COLOR.Verde:Lerp(C.MetalOscuro, 0.4), Enum.Material.Metal)
	for _, x in { -3.65, 3.65 } do
		pieza(m, "Manga", Vector3.new(0.3, 0.6, 3), cf * CFrame.new(x, 2.7, 0), COLOR.Verde:Lerp(C.MetalOscuro, 0.3), Enum.Material.CorrodedMetal)
	end
	local plastico = Color3.fromRGB(30, 36, 30)
	pieza(m, "Tapa", Vector3.new(3.5, 0.14, 3.86), cf * CFrame.new(-1.78, 4.27, 0.02) * CFrame.Angles(math.rad(2), 0, math.rad(-1.5)), plastico,
		Enum.Material.Plastic)
	pieza(m, "Tapa", Vector3.new(3.5, 0.14, 3.86), cf * CFrame.new(1.78, 4.2, -1.9) * CFrame.Angles(math.rad(-35), 0, 0)
		* CFrame.new(0, 0.07, 1.93), plastico, Enum.Material.Plastic)
	P.bola(m, "Bolsa", Vector3.one * 1.4, cf * CFrame.new(1.5, 4.1, 0.6), COLOR.Negro, Enum.Material.Plastic)
	local frente = cf * CFrame.new(0, 0, 1.8) * CFrame.Angles(0, math.pi, 0) -- cara de delante, -Z hacia fuera
	for _ = 1, 4 do
		parche(m, frente, azar:NextNumber(-3, 3), azar:NextNumber(0.9, 3.4), azar:NextNumber(0.5, 1.4), azar:NextNumber(0.3, 1.1))
	end
	-- El palé apoyado en el lado del este.
	local pale = cf * CFrame.new(4.7, 0, 0.2) * CFrame.Angles(0, math.rad(-90), 0) * CFrame.Angles(math.rad(14), 0, 0)
	for _, u in { -1.35, 0, 1.35 } do
		pieza(m, "Pale", Vector3.new(0.3, 3.4, 0.3), pale * CFrame.new(u, 1.7, 0), C.Madera, Enum.Material.WoodPlanks)
	end
	for _, v in { 0.25, 1, 1.7, 2.4, 3.15 } do
		pieza(m, "Pale", Vector3.new(3, 0.3, 0.07), pale * CFrame.new(0, v, -0.19), C.Madera:Lerp(C.HormigonSucio, 0.2), Enum.Material.WoodPlanks)
	end
	-- Bolsas alrededor (una rota, con lo de dentro por el suelo) y un cartón aplastado.
	for _, b in { { -2.6, 2.7, 1.3 }, { -1.1, 3, 1 }, { 0.7, 2.6, 1.2 }, { 2.9, 2.8, 1.1 }, { 4.9, -2.4, 1.3 }, { -4.5, 0.8, 1 } } do
		P.bola(m, "Bolsa", Vector3.one * b[3], cf * CFrame.new(b[1], b[3] * 0.32, b[2]), COLOR.Negro, Enum.Material.Plastic)
	end
	local rota = cf * CFrame.new(-3.2, 0, 4.2)
	P.bola(m, "BolsaRota", Vector3.one * 0.9, rota * CFrame.new(0, 0.25, 0), Color3.fromRGB(30, 30, 30), Enum.Material.Plastic)
	lamina(m, "Plastico", Vector3.new(1.1, 0.02, 0.7), rota * CFrame.new(0.6, 0.015, 0.4) * CFrame.Angles(0, 0.6, 0), COLOR.Negro,
		Enum.Material.Plastic)
	pieza(m, "Caja", Vector3.new(0.6, 0.3, 0.45), rota * CFrame.new(0.9, 0.15, -0.5) * CFrame.Angles(0, 0.4, 0.2), Color3.fromRGB(110, 86, 60),
		Enum.Material.Cardboard)
	for _ = 1, 3 do
		local p = (rota * CFrame.new(azar:NextNumber(0, 2.2), 0, azar:NextNumber(-1, 1.5))).Position
		papel(m, p.X, p.Z)
	end
	local p = (rota * CFrame.new(1.6, 0, 1.1)).Position
	lata(m, p.X, p.Z)
	pieza(m, "Carton", Vector3.new(2.4, 1.8, 0.06), cf * CFrame.new(-1.6, 0.85, 1.95) * CFrame.Angles(math.rad(-12), 0, math.rad(4)),
		Color3.fromRGB(96, 76, 54), Enum.Material.Cardboard)
end

------------------------------------------------------------------------------------------------------------------------
-- Neumáticos (un montón, alguno tirado y uno apoyado), el poste de aire y agua, el banco y la máquina expendedora.

-- Neumático con su eje a lo largo del Y de `cf` (tumbado si `cf` no gira), con el hueco negro.
local function neumatico(m: Model, cf: CFrame)
	P.cilindro(m, "Neumatico", Vector3.new(0.85, 2.5, 2.5), cf * CFrame.Angles(0, 0, math.pi / 2), C.Goma, Enum.Material.Rubber, true)
	P.cilindro(m, "Hueco", Vector3.new(0.87, 1.35, 1.35), cf * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(10, 10, 10),
		Enum.Material.SmoothPlastic)
end

local function neumaticos()
	local m = grupo("Neumaticos")
	for i = 0, 4 do
		neumatico(m, CFrame.new(50 + azar:NextNumber(-0.12, 0.12) + i * 0.04, SUELO + 0.425 + i * 0.84, -22 + azar:NextNumber(-0.12, 0.12))
			* CFrame.Angles(math.rad(azar:NextNumber(-2, 2)), 0, math.rad(azar:NextNumber(-2, 2))))
	end
	neumatico(m, CFrame.new(47.4, SUELO + 0.425, -23.4))
	neumatico(m, CFrame.new(51.2, SUELO + 0.425, -25.1) * CFrame.Angles(math.rad(3), 0, 0))
	neumatico(m, CFrame.new(56, SUELO + 0.425, -37.6))
	-- De pie, apoyado en el montón (eje casi horizontal, inclinado hacia él).
	neumatico(m, CFrame.new(52.2, SUELO + 1.3, -21.8) * CFrame.Angles(0, 0, math.rad(14)) * CFrame.Angles(0, 0, -math.pi / 2))
end

local function aireAgua()
	local m = grupo("AireAgua")
	local cf = CFrame.new(41, SUELO, -33) * CFrame.Angles(0, math.pi, 0) -- de cara a la explanada (+Z)
	solido(m, "Base", Vector3.new(2.4, 0.25, 2), cf * CFrame.new(0, 0.125, 0), C.HormigonSucio, Enum.Material.Concrete)
	solido(m, "Poste", Vector3.new(0.45, 2.3, 0.45), cf * CFrame.new(0, 1.4, 0.15), C.MetalOscuro, Enum.Material.CorrodedMetal)
	solido(m, "Caja", Vector3.new(1.7, 2, 1.1), cf * CFrame.new(0, 3.55, 0.05), COLOR.RojoViejo:Lerp(C.Oxido, 0.3), Enum.Material.CorrodedMetal)
	pieza(m, "Tapa", Vector3.new(1.85, 0.14, 1.25), cf * CFrame.new(0, 4.62, 0.05), C.MetalOscuro, Enum.Material.Metal)
	local frente = cf * CFrame.new(0, 0, -0.5) -- la cara de delante
	P.cilindro(m, "Manometro", Vector3.new(0.08, 0.55, 0.55), frente * CFrame.new(-0.35, 3.95, -0.04) * CFrame.Angles(0, math.pi / 2, 0),
		C.Pintura, Enum.Material.SmoothPlastic)
	local precio = lamina(m, "Precio", Vector3.new(0.6, 0.3, 0.04), frente * CFrame.new(0.4, 3.95, -0.02), C.Pintura, Enum.Material.SmoothPlastic)
	local gui = P.letrero(precio, Enum.NormalId.Front, "0.75", C.MetalOscuro)
	gui.PixelsPerStud = 80
	gui.MaxDistance = 40
	pieza(m, "Ranura", Vector3.new(0.3, 0.45, 0.06), frente * CFrame.new(0.4, 3.3, -0.03), C.MetalOscuro, Enum.Material.Metal)
	parche(m, frente, 0.2, 2.9, 1.2, 0.5)
	-- Las dos mangueras (aire, negra; agua, verde), colgando en lazo de sus ganchos.
	for _, s in { -1, 1 } do
		local salida = (cf * CFrame.new(s * 0.87, 2.8, -0.2)).Position
		local gancho = (cf * CFrame.new(s * 0.95, 3.9, -0.32)).Position
		pieza(m, "Gancho", Vector3.new(0.2, 0.12, 0.3), CFrame.new(gancho) * cf.Rotation, C.MetalOscuro, Enum.Material.Metal)
		curva(m, salida, salida + cf:VectorToWorldSpace(Vector3.new(s * 0.3, -2.8, 0)), gancho + cf:VectorToWorldSpace(Vector3.new(s * 0.35, -3.2, 0)),
			gancho, 6, 0.12, if s < 0 then COLOR.Negro else Color3.fromRGB(44, 62, 44))
		P.cilindro(m, "Boquilla", Vector3.new(0.35, 0.12, 0.12), CFrame.new(gancho + Vector3.new(0, -0.15, 0)) * cf.Rotation
			* CFrame.Angles(0, 0, math.pi / 2), C.Metal, Enum.Material.Metal)
	end
end

local function banco()
	local m = grupo("Banco")
	local cf = CFrame.new(50.25, SUELO, 9.2) * CFrame.Angles(0, math.rad(93), 0) -- contra la tienda, mirando a la marquesina
	local choque = solido(m, "Choque", Vector3.new(4, 1.55, 1.3), cf * CFrame.new(0, 0.78, 0), C.MetalOscuro, Enum.Material.SmoothPlastic)
	choque.Transparency = 1
	choque.CanQuery = false
	choque.CastShadow = false
	for _, x in { -1.6, 1.6 } do
		pieza(m, "Pata", Vector3.new(0.14, 1.45, 0.14), cf * CFrame.new(x, 0.72, -0.45), C.MetalOscuro, Enum.Material.CorrodedMetal)
		pieza(m, "Pata", Vector3.new(0.14, 2.75, 0.14), cf * CFrame.new(x, 1.37, 0.5) * CFrame.Angles(math.rad(8), 0, 0), C.MetalOscuro,
			Enum.Material.CorrodedMetal)
		pieza(m, "Travesano", Vector3.new(0.12, 0.12, 1.1), cf * CFrame.new(x, 1.42, 0.02), C.MetalOscuro, Enum.Material.Metal)
	end
	local madera = C.Madera:Lerp(C.HormigonSucio, 0.25)
	pieza(m, "Tabla", Vector3.new(3.9, 0.1, 0.3), cf * CFrame.new(0, 1.52, -0.38), madera, Enum.Material.WoodPlanks)
	pieza(m, "Tabla", Vector3.new(1.7, 0.1, 0.3), cf * CFrame.new(-1.1, 1.52, -0.04), madera, Enum.Material.WoodPlanks)
	pieza(m, "Tabla", Vector3.new(3.9, 0.1, 0.3), cf * CFrame.new(0, 1.52, 0.3), madera, Enum.Material.WoodPlanks)
	pieza(m, "Tabla", Vector3.new(2, 0.1, 0.3), cf * CFrame.new(1.2, 0.06, -1.3) * CFrame.Angles(0, 0.4, math.rad(6)), madera,
		Enum.Material.WoodPlanks) -- el trozo que falta, en el suelo
	for _, r in { { 2.05, 0.55 }, { 2.55, 0.62 } } do
		pieza(m, "Respaldo", Vector3.new(3.9, 0.3, 0.1), cf * CFrame.new(0, r[1], r[2]) * CFrame.Angles(math.rad(8), 0, 0), madera,
			Enum.Material.WoodPlanks)
	end
end

local function maquina()
	local m = grupo("Maquina")
	local cf = CFrame.new(49.75, SUELO, -10.1) * CFrame.Angles(0, math.rad(90), 0) -- contra la tienda, mirando a -X
	solido(m, "Cuerpo", Vector3.new(2.9, 5.2, 2.3), cf * CFrame.new(0, 2.8, 0), Color3.fromRGB(44, 50, 60), Enum.Material.Metal)
	pieza(m, "Pie", Vector3.new(2.8, 0.2, 2.2), cf * CFrame.new(0, 0.1, 0), C.MetalOscuro, Enum.Material.Metal)
	local frente = cf * CFrame.new(0, 0, -1.15)
	-- El escaparate apagado: tres baldas de latas tras un cristal sucio.
	for fila = 0, 2 do
		local y = 2.45 + fila
		pieza(m, "Balda", Vector3.new(1.8, 0.06, 0.32), frente * CFrame.new(-0.35, y - 0.26, -0.18), C.MetalOscuro, Enum.Material.Metal)
		for k = -1, 1 do
			columna(m, "Lata", 0.46, 0.26, frente * CFrame.new(-0.35 + k * 0.55, y, -0.17), COLOR.Lata[(fila + k + 1) % #COLOR.Lata + 1],
				Enum.Material.Metal)
		end
	end
	local vitrina = pieza(m, "Cristal", Vector3.new(1.9, 3.2, 0.05), frente * CFrame.new(-0.35, 3.25, -0.34), C.Cristal, Enum.Material.SmoothPlastic)
	vitrina.Transparency = 0.55
	P.mancha(vitrina, Enum.NormalId.Front, nil, Color3.fromRGB(40, 36, 30), 0.5)
	for _, v in { 1.6, 4.9 } do
		pieza(m, "Marco", Vector3.new(2.04, 0.12, 0.4), frente * CFrame.new(-0.35, v, -0.2), C.MetalOscuro, Enum.Material.Metal)
	end
	for _, u in { -1.37, 0.65 } do
		pieza(m, "Marco", Vector3.new(0.12, 3.3, 0.4), frente * CFrame.new(u, 3.25, -0.23), C.MetalOscuro, Enum.Material.Metal)
	end
	pieza(m, "Botonera", Vector3.new(0.6, 3, 0.06), frente * CFrame.new(1.05, 3.3, -0.03), Color3.fromRGB(30, 32, 34), Enum.Material.Metal)
	local precio = lamina(m, "Precio", Vector3.new(0.5, 0.22, 0.03), frente * CFrame.new(1.05, 4.35, -0.075), C.Pintura, Enum.Material.SmoothPlastic)
	local gui = P.letrero(precio, Enum.NormalId.Front, "1.00", C.MetalOscuro)
	gui.PixelsPerStud = 80
	gui.MaxDistance = 40
	pieza(m, "Trampilla", Vector3.new(1.8, 0.6, 0.08), frente * CFrame.new(-0.35, 1, -0.04), COLOR.Negro, Enum.Material.Metal)
	parche(m, frente, -0.2, 0.55, 2.6, 0.35)
	parche(m, frente, 1.0, 2.1, 0.5, 0.9)
end

------------------------------------------------------------------------------------------------------------------------
-- Charcos (Charco: el cliente les pone salpicaduras y ondas) y la basura.

-- Charco de forma irregular: la pieza con la etiqueta y dos o tres trozos pegados a sus lados (de canto, sin
-- montarse: con la transparencia se vería más oscuro donde se pisan).
local function charco(m: Model, x: number, z: number, largo: number, ancho: number, giro: number)
	local cf = CFrame.new(x, SUELO + 0.016, z) * CFrame.Angles(0, giro, 0) -- de 0,196 a 0,236
	local function trozo(nombre: string, l: number, w: number, dx: number, dz: number): Part
		local p = lamina(m, nombre, Vector3.new(l, 0.04, w), cf * CFrame.new(dx, 0, dz), COLOR.Charco, Enum.Material.SmoothPlastic)
		p.Transparency = 0.15
		p.Reflectance = 0.04
		return p
	end
	P.etiqueta(trozo("Charco", largo, ancho, 0, 0), "Charco")
	local l1, w1 = largo * azar:NextNumber(0.45, 0.7), ancho * azar:NextNumber(0.3, 0.5)
	trozo("CharcoBorde", l1, w1, azar:NextNumber(-1, 1) * (largo - l1) / 2, ancho / 2 + w1 / 2)
	local l2, w2 = largo * azar:NextNumber(0.3, 0.55), ancho * azar:NextNumber(0.25, 0.45)
	trozo("CharcoBorde", l2, w2, azar:NextNumber(-1, 1) * (largo - l2) / 2, -(ancho / 2 + w2 / 2))
	if largo > 3 then
		local l3, w3 = math.min(largo * 0.15, 1.2), ancho * azar:NextNumber(0.4, 0.6)
		trozo("CharcoBorde", l3, w3, largo / 2 + l3 / 2, azar:NextNumber(-1, 1) * (ancho - w3) / 2)
	end
end

local function charcos()
	local m = grupo("Charcos")
	-- Donde el suelo baja: bajo el borde de la marquesina (en los tres primeros cae un Goteo), junto a las islas y los
	-- bordillos, las rejillas, el contenedor, la cabina y los neumáticos. Con el centro fuera del techo: Clima mira si
	-- están tapados por su centro, y bajo techo no salpicarían.
	for _, c in {
		{ 27, -14, 5.5, 1.7, 0.03 }, { 38.2, 14.1, 4.8, 1.9, -0.06 }, { 20, 6.3, 3.4, 2.3, 0.35 }, { 44.6, -6.8, 3.6, 2.2, -0.25 },
		{ 46.5, -38.3, 7, 2.1, 0.02 }, { 31.5, 38, 6.2, 2.2, -0.03 }, { 71, 24.5, 6.5, 2, math.pi / 2 }, { 44.2, 12.8, 3, 2.4, 0.25 },
		{ 19, -16.6, 2.8, 2, 0.6 }, { 10.8, -35, 4.6, 3, 0.2 }, { 59.5, 24.8, 4.2, 2.2, 0.12 }, { 45.2, 25.8, 2.6, 1.8, -0.5 },
		{ 47, -27.2, 3, 2, 0.8 }, { 41.4, -31.4, 1.6, 0.9, 0.1 },
	} do
		charco(m, c[1], c[2], c[3], c[4], c[5])
	end
end

-- Sitios con algo sólido encima, donde no se tira basura suelta (x0, x1, z0, z1).
local OCUPADO = {
	{ 25.4, 38.6, -6.7, -3.3 }, { 25.4, 38.6, 3.3, 6.7 }, -- islas
	{ 45.9, 50.1, 19.9, 24.1 }, -- cabina
	{ 56, 64, 17.6, 22.4 }, -- contenedor
	{ 46, 53.3, -26.4, -20.3 }, -- neumáticos
	{ 39.6, 42.4, -34.2, -31.8 }, -- poste de aire y agua
	{ 48, 51.2, -11.7, -8.4 }, -- máquina
	{ TIENDA.x0 - 0.6, TIENDA.x1 + 0.6, TIENDA.z0 - 0.6, TIENDA.z1 + 0.6 }, -- la tienda
}

local function libre(x: number, z: number): boolean
	for _, r in OCUPADO do
		if x > r[1] and x < r[2] and z > r[3] and z < r[4] then
			return false
		end
	end
	return true
end

-- `n` cosas con `poner` repartidas en un rectángulo (x0, x1, z0, z1), saltándose lo ocupado.
local function tirar(m: Model, n: number, zona: { number }, poner: (Model, number, number) -> ())
	local puestas, intentos = 0, 0
	while puestas < n and intentos < n * 6 do
		intentos += 1
		local x, z = azar:NextNumber(zona[1], zona[2]), azar:NextNumber(zona[3], zona[4])
		if libre(x, z) then
			poner(m, x, z)
			puestas += 1
		end
	end
end

local function basura()
	local m = grupo("Basura")
	-- Lo que el viento deja contra los bordillos (norte, sur y este) y en las esquinas.
	for _, zona in { { 21, 72, -39.7, -38.6 }, { 21, 72, 38.6, 39.7 } } do
		tirar(m, 5, zona, papel)
		tirar(m, 2, zona, vaso)
		tirar(m, 2, zona, lata)
	end
	tirar(m, 3, { 71.4, 72.6, -38, 38 }, papel)
	tirar(m, 1, { 71.4, 72.6, -38, 38 }, vaso)
	tirar(m, 1, { 71.4, 72.6, -38, 38 }, lata)
	-- Por los carriles de los surtidores y alrededor de las islas.
	for _, zona in { { 24, 40, -11, -7.2 }, { 24, 40, -2.8, 2.8 }, { 24, 40, 7.2, 11 } } do
		tirar(m, 2, zona, papel)
		tirar(m, 4, zona, colilla)
	end
	tirar(m, 2, { 24, 40, -12, 12 }, lata)
	-- Colillas, una lata y papeles bajo el banco y delante de él; latas junto a la máquina.
	tirar(m, 10, { 48.4, 51, 7, 11.4 }, colilla)
	tirar(m, 2, { 47.5, 49.5, 6.5, 12 }, papel)
	lata(m, 48.9, 10.6)
	vaso(m, 47.8, 8.1)
	tirar(m, 2, { 46.6, 47.9, -12, -8.2 }, lata)
	vaso(m, 47.2, -12.6)
	-- Por toda la explanada, pocas cosas sueltas; detrás de la tienda, más.
	tirar(m, 6, { 8, 72, -38, 38 }, papel)
	tirar(m, 3, { 8, 72, -38, 38 }, lata)
	tirar(m, 2, { 8, 72, -38, 38 }, vaso)
	tirar(m, 12, { 8, 72, -38, 38 }, colilla)
	tirar(m, 2, { 70.4, 72.6, -13, 13 }, papel)
	tirar(m, 1, { 70.4, 72.6, -13, 13 }, lata)
	-- Cristales en la entrada norte (un faro roto).
	for _ = 1, 4 do
		cristal(m, azar:NextNumber(9, 12), azar:NextNumber(-39, -37))
	end
end

------------------------------------------------------------------------------------------------------------------------

function GasolineraFuera.construir(mapa: Folder)
	raiz = Instance.new("Model")
	raiz.Name = "Fuera"
	explanada()
	marquesina()
	for n, z in ISLAS do
		isla(n, z)
	end
	cartel()
	cabina()
	contenedor()
	neumaticos()
	aireAgua()
	banco()
	maquina()
	charcos()
	basura()
	raiz.Parent = mapa -- de una vez, al final
end

return GasolineraFuera
