-- La calle del pueblo, el cementerio y todo lo de fuera entre los edificios. (11.5, plano en PuebloPlano).
-- Pedido por el usuario: "farolas apagadas, un coche abandonado, buzones y vallas caídas", que parezca un pueblo de
-- verdad, abandonado y de terror, sin pasarse de piezas. Nada da luz (el pueblo no tiene corriente) y nada es Neon.
--
-- Alturas (cara de arriba): suelo del bosque 0; calzada vieja 0,3 (la tierra del Camino, 0,15, queda debajo); aceras y
-- plaza de la iglesia 0,5 y bordillo 0,55 (escalones de 0,5 como mucho, se suben andando); suelo del cementerio 0,2.
-- Lo pequeño no choca ni tapa rayos; lo grande (vallas, coche, farolas, postes, lápidas) choca, sin cerrar el paso.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Piezas = require(ReplicatedStorage.Shared.Piezas)

local PuebloCalle = {}

local COLOR = {
	Asfalto = Color3.fromRGB(44, 43, 42),
	Grieta = Color3.fromRGB(22, 21, 20),
	Bache = Color3.fromRGB(42, 37, 32),
	Charco = Color3.fromRGB(12, 13, 13),
	Linea = Color3.fromRGB(112, 106, 84), -- la raya del medio, casi borrada
	Acera = Color3.fromRGB(82, 80, 76),
	Bordillo = Color3.fromRGB(104, 102, 98),
	Losa = Color3.fromRGB(80, 78, 74),
	Adoquin = Color3.fromRGB(78, 74, 70),
	Grava = Color3.fromRGB(82, 78, 72),
	Hierro = Color3.fromRGB(40, 37, 35),
	Oxido = Color3.fromRGB(78, 54, 40),
	Madera = Color3.fromRGB(78, 68, 58),
	MaderaPintada = Color3.fromRGB(68, 63, 56), -- pintura vieja, casi toda ida, y madera sucia (pedido por el usuario: se veían nuevas)
	Poste = Color3.fromRGB(58, 48, 40),
	Cable = Color3.fromRGB(20, 20, 20),
	Piedra = Color3.fromRGB(98, 98, 94),
	Musgo = Color3.fromRGB(72, 78, 62),
	Tierra = Color3.fromRGB(58, 46, 36),
	Hoyo = Color3.fromRGB(16, 12, 10),
	Hierba = Color3.fromRGB(92, 88, 58), -- hierba alta seca
	HierbaVerde = Color3.fromRGB(60, 68, 48),
	Cristal = Color3.fromRGB(150, 165, 170),
	Sangre = Color3.fromRGB(90, 8, 8),
	Hoja = { Color3.fromRGB(86, 58, 34), Color3.fromRGB(70, 50, 32), Color3.fromRGB(96, 74, 40), Color3.fromRGB(58, 48, 36) },
}

-- Medidas de la calle: calzada x -6..6; bordillo de 6 a 6,4 y acera hasta 9 a cada lado; vallas de jardín en x = ±9,6.
local CALLE = { z1 = -534, z2 = -398, acera1 = -532, acera2 = -400, bordillo = 6, acera = 9, valla = 9.6 }
local ALTO = { calzada = 0.3, acera = 0.5, bordillo = 0.55, cementerio = 0.2, camino = 0.14 }
-- La plaza empedrada delante de la iglesia (de la acera a su pared oeste) y el camino de grava al cementerio.
local PLAZA = { x1 = 9, x2 = 21.3, z1 = -507, z2 = -493 }
local CAMINO_CEMENTERIO = { z = -479, x = 40.5 }
-- El cemento delante de la tienda (de su pared a la acera); se rellena en `caminos` con las medidas del plano.
local TIENDA = { x1 = 0, x2 = 0, z1 = 0, z2 = 0, y = 0.4 }

local ctx: any
local azar: Random
local carpeta: Instance

-- Pieza que choca (como ctx.bloque).
-- Suelos y láminas, ya puestos a alturas distintas a mano: Separar.caras no los engorda (el suelo del cementerio
-- crecía hasta tapar la grava).
local PLANOS = {
	Calzada = true, Parche = true, Bache = true, Charco = true, Grieta = true, Raya = true, Losa = true, Hueco = true,
	Bordillo = true, Plaza = true, BordePlaza = true, CementoTienda = true, LosaCamino = true, Grava = true, Cementerio = true,
	Hierbajo = true, Hoyo = true, Hoja = true, Papel = true,
}

local function solido(nombre: string, tam: Vector3, cf: CFrame, color: Color3, material: Enum.Material, padre: Instance?): Part
	local p = ctx.bloque(nombre, tam, cf, color, material, padre or carpeta)
	if PLANOS[nombre] then
		p:SetAttribute("SinSeparar", true)
	end
	return p
end

-- Pieza que solo se ve: no choca ni tapa rayos; lo pequeño, sin sombra.
local function suelta(nombre: string, tam: Vector3, cf: CFrame, color: Color3, material: Enum.Material, padre: Instance?): Part
	local p = solido(nombre, tam, cf, color, material, padre)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	if math.max(tam.X, tam.Y, tam.Z) < 3 then
		p.CastShadow = false
	end
	return p
end

-- Caja invisible que choca (lo de verdad, en piezas sueltas, no choca).
local function choque(tam: Vector3, cf: CFrame, padre: Instance?): Part
	local p = solido("Choque", tam, cf, COLOR.Hierro, Enum.Material.SmoothPlastic, padre)
	p.Transparency = 1
	p.CanQuery = false
	p.CastShadow = false
	return p
end

local function cilindro(p: Part): Part
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function grupo(nombre: string, padre: Instance?): Model
	local m = Instance.new("Model")
	m.Name = nombre
	m.Parent = padre or carpeta
	return m
end

-- Cara de arriba del suelo en (x, z) (para posar hierba, hojas y basura).
local function sueloEn(x: number, z: number): number
	local ax = math.abs(x)
	if z > CALLE.z1 and z < CALLE.z2 and ax < CALLE.bordillo then
		return ALTO.calzada
	elseif z > CALLE.acera1 and z < CALLE.acera2 and ax < CALLE.acera then
		return ALTO.acera
	elseif x > PLAZA.x1 and x < PLAZA.x2 and z > PLAZA.z1 and z < PLAZA.z2 then
		return ALTO.acera
	elseif x > TIENDA.x1 and x < TIENDA.x2 and z > TIENDA.z1 and z < TIENDA.z2 then
		return TIENDA.y
	end
	local c = ctx.Plano.CEMENTERIO
	if x > c.x1 and x < c.x2 and z > c.z1 and z < c.z2 then
		return ALTO.cementerio
	end
	return 0
end

-- ¿Cae (x, z) dentro de algún edificio (con `margen`) o delante de su puerta (paso de 6 de ancho, `fondo` de largo)?
local function ocupado(x: number, z: number, margen: number): boolean
	local P = ctx.Plano
	for _, e in P.edificios do
		if math.abs(x - e.x) < e.ancho / 2 + margen and math.abs(z - e.z) < e.largo / 2 + margen then
			return true
		end
		local fuera = P.LADOS[e.puerta]
		local px, pz = e.x + fuera.X * e.ancho / 2, e.z + fuera.Z * e.largo / 2
		local fondo = 7
		if fuera.X ~= 0 then
			local d = (x - px) * fuera.X
			if d > -1 and d < fondo and math.abs(z - pz) < 3.5 then
				return true
			end
		else
			local d = (z - pz) * fuera.Z
			if d > -1 and d < fondo and math.abs(x - px) < 3.5 then
				return true
			end
		end
	end
	local cam = P.CAMPANARIO
	return math.abs(x - cam.x) < cam.lado / 2 + margen and math.abs(z - cam.z) < cam.lado / 2 + margen
end

-- ¿Se puede poner algo fuera de la calle en (x, z)? Ni en edificios ni puertas, ni en la plaza, ni en el camino de grava.
local function libreFuera(x: number, z: number, margen: number): boolean
	if math.abs(x) < CALLE.valla + 0.3 or ocupado(x, z, margen) then
		return false
	end
	if x > PLAZA.x1 - 1 and x < PLAZA.x2 + 1 and z > PLAZA.z1 - 1 and z < PLAZA.z2 + 1 then
		return false
	end
	if x > TIENDA.x1 - 1 and x < TIENDA.x2 + 1 and z > TIENDA.z1 - 1 and z < TIENDA.z2 + 1 then
		return false
	end
	local c = ctx.Plano.CEMENTERIO
	if x > c.x1 - 4 and x < c.x2 + 1 and z > c.z1 - 1 and z < c.z2 + 1 then
		return false
	end
	return not (math.abs(z - CAMINO_CEMENTERIO.z) < 2.5 and x > 8 and x < c.x1)
end

-- Un cristal roto en el suelo.
local function cristal(x: number, z: number, padre: Instance)
	local p = Instance.new("WedgePart")
	p.Name = "Cristal"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = Vector3.new(0.03, azar:NextNumber(0.2, 0.6), azar:NextNumber(0.2, 0.6))
	p.CFrame = CFrame.new(x, sueloEn(x, z) + 0.03, z) * CFrame.Angles(0, azar:NextNumber(0, math.pi * 2), math.pi / 2)
	p.Color = COLOR.Cristal
	p.Material = Enum.Material.SmoothPlastic
	p.Transparency = 0.4
	p.Reflectance = 0.15
	p.Parent = padre
end

-- Un mueble de ServerStorage.Muebles colgado del pueblo (choca su caja salvo `sinChoque`).
local function mueble(nombre: string, cf: CFrame, sinChoque: boolean?, padre: Instance?): Model?
	local modelo: Model? = nil
	ctx.Mapa.conPadre(padre or carpeta, function()
		modelo = ctx.Mapa.mueble(nombre, cf, sinChoque)
	end)
	return modelo
end

local function mancha(pos: Vector3, normal: Vector3, tam: number, padre: Instance?)
	local M = ctx.Mapa
	M.conPadre(padre or carpeta, function()
		M.mancha(pos, normal, tam, M.SANGRE[azar:NextInteger(1, #M.SANGRE)], COLOR.Sangre, azar:NextNumber(0, math.pi * 2))
	end)
end

-- Pieza de Blender (Piezas: helecho, arbusto, roca); devuelve las mallas puestas (ninguna sin el archivo).
local function planta(nombre: string, cf: CFrame, escala: number, padre: Instance?): { BasePart }
	local partes = Piezas.poner(padre or carpeta, nombre, cf, Vector3.one * escala)
	for _, p in partes do
		p.CastShadow = false
	end
	return partes
end

------------------------------------------------------------------------------------------------------------------------
-- La calle: calzada de asfalto viejo y agrietado, aceras de losas con bordillo y caminitos a las puertas.

-- Una grieta en zigzag sobre el asfalto, desde `desde` hacia `rumbo` (radianes en el suelo).
local function grieta(desde: Vector3, rumbo: number, tramos: number, padre: Instance)
	local pos = desde
	for _ = 1, tramos do
		local largo = azar:NextNumber(1.2, 3.2)
		rumbo += azar:NextNumber(-0.7, 0.7)
		local fin = pos + Vector3.new(math.cos(rumbo), 0, math.sin(rumbo)) * largo
		local medio = (pos + fin) / 2
		suelta("Grieta", Vector3.new(azar:NextNumber(0.12, 0.28), 0.02, largo + 0.1), CFrame.lookAt(medio, fin), COLOR.Grieta,
			Enum.Material.Asphalt, padre)
		pos = fin
	end
end

-- Charco de agua negra: un disco plano de `diametro` con su centro en `pos`. Sin cristal ni reflejo (pedido por el
-- usuario: de día salían azules, reflejaban el cielo).
local function charco(pos: Vector3, diametro: number, padre: Instance)
	local agua = cilindro(suelta("Charco", Vector3.new(0.02, diametro, diametro), CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2),
		COLOR.Charco, Enum.Material.SmoothPlastic, padre))
	agua.Reflectance = 0
end

local function calzada()
	local calle = Instance.new("Folder")
	calle.Name = "Calle"
	calle.Parent = carpeta
	local largo = CALLE.z2 - CALLE.z1
	local suelo = solido("Calzada", Vector3.new(CALLE.bordillo * 2, 0.25, largo),
		CFrame.new(0, ALTO.calzada - 0.125, (CALLE.z1 + CALLE.z2) / 2), COLOR.Asfalto, Enum.Material.Asphalt, calle)
	CollectionService:AddTag(suelo, "EnMapa")
	local arriba = ALTO.calzada + 0.01
	-- Parches de asfalto más nuevo (más oscuro) y trozos levantados donde se ve la tierra (baches).
	for _ = 1, 16 do
		local z = azar:NextNumber(CALLE.z1 + 4, CALLE.z2 - 4)
		local x = azar:NextNumber(-4, 4)
		suelta("Parche", Vector3.new(azar:NextNumber(2, 4), 0.02, azar:NextNumber(2, 5)),
			CFrame.new(x, arriba, z) * CFrame.Angles(0, azar:NextNumber(-0.3, 0.3), 0), COLOR.Asfalto:Lerp(if azar:NextNumber() < 0.5 then COLOR.Grieta else COLOR.Acera, 0.4),
			Enum.Material.Asphalt, calle)
	end
	for _ = 1, 22 do
		local z = azar:NextNumber(CALLE.z1 + 3, CALLE.z2 - 3)
		local x = azar:NextNumber(-5, 5)
		local tam = azar:NextNumber(1.2, 3)
		local giro = CFrame.new(x, arriba + 0.005, z) * CFrame.Angles(0, azar:NextNumber(0, math.pi), 0)
		suelta("Bache", Vector3.new(tam, 0.03, tam * azar:NextNumber(0.6, 1.1)), giro, COLOR.Bache, Enum.Material.Ground, calle)
		-- Agua negra en algunos baches.
		if azar:NextNumber() < 0.5 then
			charco((giro * CFrame.new(0, 0.02, 0)).Position, tam * 0.6, calle)
		end
	end
	-- Charcos más grandes junto a los bordillos (el agua se queda en la cuneta).
	for _, c in { { -4.6, -418, 2.6 }, { 4.7, -447, 2.2 }, { -4.4, -476, 2.8 }, { 4.6, -515, 2.4 }, { -4.6, -527, 2.4 } } do
		-- Dos discos juntos: más largo que ancho.
		charco(Vector3.new(c[1], arriba + 0.012, c[2]), c[3], calle)
		charco(Vector3.new(c[1] + azar:NextNumber(-0.3, 0.3), arriba + 0.014, c[2] + c[3] * 0.6), c[3] * 0.8, calle)
	end
	-- Grietas.
	for _ = 1, 40 do
		grieta(Vector3.new(azar:NextNumber(-5.5, 5.5), arriba + 0.006, azar:NextNumber(CALLE.z1 + 2, CALLE.z2 - 2)),
			azar:NextNumber(0, math.pi * 2), azar:NextInteger(2, 4), calle)
	end
	-- La raya del medio, casi borrada: faltan trozos.
	for z = CALLE.z2 - 4, CALLE.z1 + 6, -7 do
		if azar:NextNumber() < 0.72 then
			suelta("Raya", Vector3.new(0.3, 0.02, azar:NextNumber(1.5, 3.2)), CFrame.new(0, arriba + 0.004, z), COLOR.Linea,
				Enum.Material.Asphalt, calle).Transparency = azar:NextNumber(0.3, 0.6)
		end
	end
	-- El final: el asfalto se deshace en trozos antes de la casa del fondo.
	for i = 1, 6 do
		suelta("Trozo", Vector3.new(azar:NextNumber(1, 2.5), 0.2, azar:NextNumber(0.8, 1.6)),
			CFrame.new(-6 + i * 1.9 + azar:NextNumber(-0.4, 0.4), 0.08, CALLE.z1 - azar:NextNumber(0.4, 1.4))
				* CFrame.Angles(azar:NextNumber(-0.08, 0.08), azar:NextNumber(0, math.pi), azar:NextNumber(-0.08, 0.08)),
			COLOR.Asfalto, Enum.Material.Asphalt, calle)
	end

	-- Las aceras: bordillo seguido y losas de 4 de largo, alguna levantada, rota o que falta.
	for _, lado in { -1, 1 } do
		local largoAcera = CALLE.acera2 - CALLE.acera1
		local mitad = (CALLE.acera1 + CALLE.acera2) / 2
		solido("Bordillo", Vector3.new(0.4, ALTO.bordillo, largoAcera), CFrame.new(lado * (CALLE.bordillo + 0.2), ALTO.bordillo / 2, mitad),
			COLOR.Bordillo, Enum.Material.Concrete, calle)
		local ancho = CALLE.acera - CALLE.bordillo - 0.4
		local x = lado * (CALLE.bordillo + 0.4 + ancho / 2)
		for z = CALLE.acera2 - 2, CALLE.acera1 + 2, -4 do
			local suerte = azar:NextNumber()
			local color = COLOR.Acera:Lerp(COLOR.Grieta, azar:NextNumber(0, 0.18))
			if suerte < 0.05 then
				-- Falta la losa: tierra con hierbajos, a ras de la acera para no tropezar.
				solido("Hueco", Vector3.new(ancho, ALTO.acera - 0.08, 3.96), CFrame.new(x, (ALTO.acera - 0.08) / 2, z), COLOR.Tierra,
					Enum.Material.Ground, calle)
			elseif suerte < 0.13 then
				-- Levantada por una raíz: un poco inclinada (sube 0,2 como mucho).
				solido("Losa", Vector3.new(ancho, ALTO.acera, 3.96), CFrame.new(x, ALTO.acera / 2 + 0.05, z) * CFrame.Angles(math.rad(2.5), 0, 0),
					color, Enum.Material.Pavement, calle)
			else
				solido("Losa", Vector3.new(ancho, ALTO.acera, 3.96), CFrame.new(x, ALTO.acera / 2, z), color, Enum.Material.Pavement, calle)
				if suerte > 0.8 then
					grieta(Vector3.new(x + azar:NextNumber(-1, 1), ALTO.acera + 0.01, z - 1.5), math.pi / 2 + azar:NextNumber(-0.5, 0.5), 2, calle)
				end
			end
		end
	end

	-- La plaza empedrada delante de la iglesia (a la altura de la acera).
	local plaza = solido("Plaza", Vector3.new(PLAZA.x2 - PLAZA.x1, ALTO.acera, PLAZA.z2 - PLAZA.z1),
		CFrame.new((PLAZA.x1 + PLAZA.x2) / 2, ALTO.acera / 2, (PLAZA.z1 + PLAZA.z2) / 2), COLOR.Adoquin, Enum.Material.Cobblestone, calle)
	CollectionService:AddTag(plaza, "EnMapa")
	for _, z in { PLAZA.z1 + 0.2, PLAZA.z2 - 0.2 } do
		solido("BordePlaza", Vector3.new(PLAZA.x2 - PLAZA.x1, ALTO.acera + 0.04, 0.4),
			CFrame.new((PLAZA.x1 + PLAZA.x2) / 2, (ALTO.acera + 0.04) / 2, z), COLOR.Bordillo, Enum.Material.Concrete, calle)
	end
	return calle
end

-- Losas sueltas de un caminito desde `desde` hasta `hasta` (a ras del suelo), de `ancho` de ancho.
local function caminito(desde: Vector3, hasta: Vector3, ancho: number, padre: Instance)
	local largo = (hasta - desde).Magnitude
	local n = math.max(1, math.floor(largo / 1.6))
	local paso = largo / n
	local dir = (hasta - desde).Unit
	for i = 0, n - 1 do
		if azar:NextNumber() < 0.08 then
			continue -- falta una
		end
		local centro = desde + dir * (paso * (i + 0.5))
		local cf = CFrame.lookAt(Vector3.new(centro.X, ALTO.camino / 2, centro.Z), Vector3.new(centro.X, ALTO.camino / 2, centro.Z) + dir)
			* CFrame.Angles(0, azar:NextNumber(-0.1, 0.1), 0)
		solido("LosaCamino", Vector3.new(ancho * azar:NextNumber(0.85, 1), ALTO.camino, paso - 0.25), cf,
			COLOR.Losa:Lerp(COLOR.Musgo, azar:NextNumber(0, 0.4)), Enum.Material.Slate, padre)
	end
end

-- Camino de grava (al cementerio y dentro de él), a `y` de altura.
local function grava(desde: Vector3, hasta: Vector3, ancho: number, y: number, padre: Instance)
	local largo = (hasta - desde).Magnitude
	local medio = (desde + hasta) / 2
	local cf = CFrame.lookAt(Vector3.new(medio.X, y - 0.04, medio.Z), Vector3.new(hasta.X, y - 0.04, hasta.Z))
	solido("Grava", Vector3.new(ancho, 0.08, largo + ancho), cf, COLOR.Grava, Enum.Material.Pebble, padre)
end

local function caminos(calle: Instance)
	local P = ctx.Plano
	for _, e in P.edificios do
		local fuera = P.LADOS[e.puerta]
		if e.nombre == "Iglesia" or e.nombre == "Cripta" or e.nombre == "CasetaEnterrador" then
			continue
		end
		if e.nombre == "Tienda" then
			-- Delante de la tienda, cemento hasta la pared.
			TIENDA.x1, TIENDA.x2 = e.x + e.ancho / 2 + 0.6, -CALLE.acera
			TIENDA.z1, TIENDA.z2 = e.z - e.largo / 2 - 1, e.z + e.largo / 2 + 1
			solido("CementoTienda", Vector3.new(TIENDA.x2 - TIENDA.x1, TIENDA.y, TIENDA.z2 - TIENDA.z1),
				CFrame.new((TIENDA.x1 + TIENDA.x2) / 2, TIENDA.y / 2, e.z), COLOR.Acera:Lerp(COLOR.Tierra, 0.25), Enum.Material.Concrete, calle)
			continue
		end
		if fuera.X ~= 0 then
			local lado = if e.x < 0 then -1 else 1
			caminito(Vector3.new(lado * CALLE.acera, 0, e.z), Vector3.new(e.x + fuera.X * (e.ancho / 2 + 0.6), 0, e.z), 2.6, calle)
		else
			-- La casa del fondo: hasta su fachada de la calle (la de +z).
			caminito(Vector3.new(e.x, 0, CALLE.z1 - 0.2), Vector3.new(e.x, 0, e.z + e.largo / 2 + 0.6), 2.6, calle)
		end
	end
	-- La grava hasta la entrada del cementerio: por el sur de la iglesia y entre ella y la valla.
	local c = ctx.Plano.CEMENTERIO
	local z, x = CAMINO_CEMENTERIO.z, CAMINO_CEMENTERIO.x
	grava(Vector3.new(CALLE.acera, 0, z), Vector3.new(x, 0, z), 3, ALTO.camino, calle)
	grava(Vector3.new(x, 0, z), Vector3.new(x, 0, (c.entrada[1] + c.entrada[2]) / 2), 3, ALTO.camino + 0.005, calle)
end

------------------------------------------------------------------------------------------------------------------------
-- Farolas apagadas, postes de madera con cables, buzones, cubos de basura y el cartel de la entrada.

-- Farola de hierro: `base` a ras del suelo, el brazo hacia -Z (a la calle). `estado`: "bien", "torcida", "caida" o "rota".
local function farola(base: CFrame, estado: string)
	local m = grupo("Farola")
	local cf = base
	if estado == "torcida" then
		cf = base * CFrame.Angles(math.rad(-13), 0, math.rad(6))
	elseif estado == "caida" then
		-- Tumbada hacia atrás (a los jardines), el pie arrancado de la acera; no choca.
		solido("PieRoto", Vector3.new(0.9, 0.5, 0.9), base * CFrame.new(0, 0.25, 0) * CFrame.Angles(0.15, 0.4, 0), COLOR.Hierro,
			Enum.Material.CorrodedMetal, m)
		cf = base * CFrame.new(0, -0.1, 1) * CFrame.Angles(math.rad(86), 0, math.rad(4))
	end
	-- Choca el palo (de pie); lo demás solo se ve.
	local function trozo(nombre: string, tam: Vector3, off: CFrame, material: Enum.Material?, color: Color3?): Part
		local hace = if estado ~= "caida" and (nombre == "Pie" or nombre == "Columna") then solido else suelta
		return hace(nombre, tam, cf * off, color or COLOR.Hierro, material or Enum.Material.Metal, m)
	end
	trozo("Pie", Vector3.new(0.9, 1.4, 0.9), CFrame.new(0, 0.7, 0), Enum.Material.CorrodedMetal)
	cilindro(trozo("Columna", Vector3.new(11, 0.35, 0.35), CFrame.new(0, 6.6, 0) * CFrame.Angles(0, 0, math.pi / 2)))
	trozo("Anillo", Vector3.new(0.6, 0.3, 0.6), CFrame.new(0, 1.55, 0), Enum.Material.CorrodedMetal)
	trozo("Brazo", Vector3.new(0.18, 0.18, 2), CFrame.new(0, 11.8, -0.9))
	trozo("Tirante", Vector3.new(0.12, 0.12, 1.5), CFrame.new(0, 11.3, -0.6) * CFrame.Angles(math.rad(40), 0, 0))
	local farol = cf * CFrame.new(0, 11.05, -1.8)
	if estado == "rota" then
		farol = farol * CFrame.new(0, -0.4, 0) * CFrame.Angles(math.rad(25), 0, math.rad(15)) -- colgando de un tornillo
	end
	suelta("Tapa", Vector3.new(1.1, 0.25, 1.1), farol * CFrame.new(0, 0.7, 0), COLOR.Hierro, Enum.Material.Metal, m)
	suelta("Farol", Vector3.new(0.85, 1.1, 0.85), farol, Color3.fromRGB(38, 42, 44), Enum.Material.SmoothPlastic, m).Transparency =
		if estado == "rota" then 0.7 else 0.25
	suelta("Fondo", Vector3.new(0.7, 0.2, 0.7), farol * CFrame.new(0, -0.62, 0), COLOR.Hierro, Enum.Material.Metal, m)
	if estado == "rota" or estado == "caida" then
		-- Cristales del farol por el suelo.
		local suelo = base.Position + base.LookVector * (if estado == "caida" then -11 else 1.8)
		for _ = 1, 6 do
			cristal(suelo.X + azar:NextNumber(-1.2, 1.2), suelo.Z + azar:NextNumber(-1.2, 1.2), m)
		end
	end
end

-- Cable que cuelga entre dos puntos (combado hacia abajo por el medio).
local function cable(a: Vector3, b: Vector3, comba: number, padre: Instance)
	local medio = (a + b) / 2 - Vector3.new(0, comba, 0)
	local cuartoA = (a + medio) / 2 - Vector3.new(0, comba * 0.18, 0)
	local cuartoB = (medio + b) / 2 - Vector3.new(0, comba * 0.18, 0)
	local puntos = { a, cuartoA, medio, cuartoB, b }
	for i = 1, #puntos - 1 do
		local p, q = puntos[i], puntos[i + 1]
		suelta("Cable", Vector3.new(0.08, 0.08, (q - p).Magnitude + 0.05), CFrame.lookAt((p + q) / 2, q), COLOR.Cable,
			Enum.Material.Rubber, padre)
	end
end

-- Poste de la luz de madera con su cruceta (a lo largo de x) y dos aisladores; devuelve dónde se enganchan los cables.
local function poste(x: number, z: number, inclinado: number, padre: Instance): { Vector3 }
	local m = grupo("Poste", padre)
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, azar:NextNumber(-0.2, 0.2), math.rad(inclinado))
	cilindro(solido("Palo", Vector3.new(22, 0.85, 0.85), base * CFrame.new(0, 11, 0) * CFrame.Angles(0, 0, math.pi / 2), COLOR.Poste,
		Enum.Material.Wood, m))
	suelta("Cruceta", Vector3.new(4.2, 0.35, 0.35), base * CFrame.new(0, 20.6, 0), COLOR.Poste, Enum.Material.Wood, m)
	local enganches = {}
	for _, dx in { -1.7, 1.7 } do
		suelta("Aislador", Vector3.new(0.25, 0.4, 0.25), base * CFrame.new(dx, 21, 0), Color3.fromRGB(70, 74, 72), Enum.Material.Glass, m)
		table.insert(enganches, (base * CFrame.new(dx, 21.15, 0)).Position)
	end
	return enganches
end

local function postesYCables()
	local carpetaPostes = Instance.new("Folder")
	carpetaPostes.Name = "Postes"
	carpetaPostes.Parent = carpeta
	-- Los del este, por la acera; uno más fuera del pueblo, junto a la carretera. Y dos al oeste, con un cable que cruza.
	local este = {
		poste(8.5, -356, 0, carpetaPostes), poste(8.5, -404, 0, carpetaPostes), poste(8.5, -452, -2, carpetaPostes),
		poste(8.5, -475, 6, carpetaPostes), poste(8.5, -516, 0, carpetaPostes),
	}
	for i = 1, #este - 1 do
		for k = 1, 2 do
			cable(este[i][k], este[i + 1][k], 1.4 + k * 0.25, carpetaPostes)
		end
	end
	local oeste = { poste(-8.5, -440, 0, carpetaPostes), poste(-8.5, -500, -3, carpetaPostes) }
	cable(oeste[1][2], oeste[2][2], 1.6, carpetaPostes)
	cable(este[3][1], oeste[1][2], 1.8, carpetaPostes) -- cruza la calle
	-- Un cable roto: cuelga del último poste del oeste hasta el suelo y se enrosca en la acera.
	local suelto = oeste[2][1]
	cable(suelto, Vector3.new(-7.4, 9, -505), 0.4, carpetaPostes)
	cable(Vector3.new(-7.4, 9, -505), Vector3.new(-7.2, ALTO.acera + 0.05, -507.5), 0.2, carpetaPostes)
	cable(Vector3.new(-7.2, ALTO.acera + 0.05, -507.5), Vector3.new(-8.2, ALTO.acera + 0.05, -509.6), 0.02, carpetaPostes)
	-- Un transformador oxidado en el poste del medio.
	local p = este[3][1]
	cilindro(suelta("Transformador", Vector3.new(1.8, 1.2, 1.2), CFrame.new(p.X + 1.5, p.Y - 3.6, p.Z) * CFrame.Angles(0, 0, math.pi / 2),
		COLOR.Oxido, Enum.Material.CorrodedMetal, carpetaPostes))
end

-- Buzón de chapa sobre un palo, junto a la acera (`giro` en y: con 0 la boca mira a -Z). `estado`: "bien", "torcido"
-- o "caido".
local function buzon(x: number, z: number, giro: number, estado: string)
	local m = grupo("Buzon")
	local base = CFrame.new(x, sueloEn(x, z), z) * CFrame.Angles(0, giro, 0)
	if estado == "torcido" then
		base = base * CFrame.Angles(math.rad(azar:NextNumber(-14, 14)), azar:NextNumber(-0.4, 0.4), math.rad(azar:NextNumber(8, 16)))
	elseif estado == "caido" then
		base = base * CFrame.new(0, 0.18, 0) * CFrame.Angles(0, 0.6, math.rad(84))
	end
	suelta("Palo", Vector3.new(0.3, 3.1, 0.3), base * CFrame.new(0, 1.55, 0), COLOR.Madera, Enum.Material.Wood, m)
	local caja = base * CFrame.new(0, 3.45, -0.2)
	local chapa = COLOR.Hierro:Lerp(Color3.fromRGB(70, 74, 72), 0.5)
	suelta("Caja", Vector3.new(0.85, 0.6, 1.6), caja, chapa, Enum.Material.CorrodedMetal, m)
	cilindro(suelta("Techo", Vector3.new(1.6, 0.85, 0.85), caja * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, math.pi / 2, 0), chapa,
		Enum.Material.CorrodedMetal, m))
	suelta("Bandera", Vector3.new(0.06, 0.8, 0.25), caja * CFrame.new(0.46, 0.35, 0.4) * CFrame.Angles(0, 0, math.rad(-35)),
		Color3.fromRGB(96, 34, 30), Enum.Material.Metal, m)
	-- La tapa abierta y colgando en algunos.
	if azar:NextNumber() < 0.5 then
		suelta("Tapa", Vector3.new(0.85, 0.85, 0.06), caja * CFrame.new(0, -0.35, -0.82) * CFrame.Angles(math.rad(-80), 0, 0), chapa,
			Enum.Material.CorrodedMetal, m)
	end
end

local function cuboBasura(pos: Vector3, tumbado: boolean, padre: Instance)
	local m = grupo("CuboBasura", padre)
	local chapa = Color3.fromRGB(66, 68, 64)
	if not tumbado then
		cilindro(suelta("Cubo", Vector3.new(2.6, 1.8, 1.8), CFrame.new(pos + Vector3.new(0, 1.3, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			chapa, Enum.Material.CorrodedMetal, m))
		local tapa = CFrame.new(pos + Vector3.new(0, 2.68, 0)) * CFrame.Angles(math.rad(azar:NextNumber(-12, 12)), 0, math.rad(8))
		cilindro(suelta("Tapa", Vector3.new(0.15, 2, 2), tapa * CFrame.Angles(0, 0, math.pi / 2), chapa, Enum.Material.CorrodedMetal, m))
		return
	end
	local giro = azar:NextNumber(0, math.pi * 2)
	local cf = CFrame.new(pos + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, giro, 0)
	cilindro(suelta("Cubo", Vector3.new(2.6, 1.8, 1.8), cf, chapa, Enum.Material.CorrodedMetal, m))
	cilindro(suelta("Tapa", Vector3.new(0.15, 2, 2), CFrame.new(pos + Vector3.new(azar:NextNumber(1.5, 2.5), 0.08, 2))
		* CFrame.Angles(0, 0, math.pi / 2), chapa, Enum.Material.CorrodedMetal, m))
	-- La basura que se ha salido: bolsas y papeles.
	local boca = cf * CFrame.new(1.8, -0.6, 0)
	for i = 1, 3 do
		local bolsa = suelta("Bolsa", Vector3.new(1.2, 0.8, 1), boca * CFrame.new(i * 0.6, 0.4, azar:NextNumber(-0.8, 0.8))
			* CFrame.Angles(0, azar:NextNumber(0, 3), 0), Color3.fromRGB(24, 24, 24), Enum.Material.Plastic, m)
		bolsa.Shape = Enum.PartType.Ball
		bolsa.Size = Vector3.new(1.1, 1.1, 1.1) * azar:NextNumber(0.7, 1)
		bolsa.CFrame = bolsa.CFrame - Vector3.new(0, 0.25, 0)
	end
	for _ = 1, 4 do
		local p = (boca * CFrame.new(azar:NextNumber(0.5, 3.5), 0, azar:NextNumber(-1.5, 1.5))).Position
		suelta("Papel", Vector3.new(0.7, 0.02, 0.9), CFrame.new(p.X, sueloEn(p.X, p.Z) + 0.03, p.Z) * CFrame.Angles(0, azar:NextNumber(0, 3), 0),
			Color3.fromRGB(112, 104, 88), Enum.Material.Fabric, m)
	end
end

local function cartelEntrada()
	local m = grupo("CartelEntrada")
	-- Al este de la carretera, antes de la primera casa, mirando a quien llega (+z). Sin letras.
	local base = CFrame.new(11.5, 0, -397) * CFrame.Angles(0, math.rad(-25), 0)
	for _, dx in { -2.6, 2.6 } do
		solido("Pata", Vector3.new(0.45, 7, 0.45), base * CFrame.new(dx, 3.5, 0) * CFrame.Angles(0, 0, math.rad(dx * 0.5)), COLOR.Poste,
			Enum.Material.Wood, m)
	end
	local tabla = base * CFrame.new(0, 5.2, 0.3) * CFrame.Angles(0, 0, math.rad(-5))
	-- Tres tablones; al de abajo le falta un trozo (está en el suelo).
	suelta("Tablon", Vector3.new(6.8, 0.9, 0.18), tabla * CFrame.new(0, 0.95, 0), COLOR.Madera, Enum.Material.WoodPlanks, m)
	suelta("Tablon", Vector3.new(6.6, 0.9, 0.18), tabla, COLOR.Madera:Lerp(COLOR.Grieta, 0.15), Enum.Material.WoodPlanks, m)
	suelta("Tablon", Vector3.new(4.2, 0.9, 0.18), tabla * CFrame.new(-1.3, -0.95, 0) * CFrame.Angles(0, 0, math.rad(4)), COLOR.Madera,
		Enum.Material.WoodPlanks, m)
	suelta("TablonCaido", Vector3.new(2.4, 0.9, 0.18), base * CFrame.new(2.2, 0.12, 1.4) * CFrame.Angles(math.rad(88), 0.3, 0),
		COLOR.Madera, Enum.Material.WoodPlanks, m)
	-- El marco pintado, casi sin pintura.
	suelta("Marco", Vector3.new(7, 0.15, 0.22), tabla * CFrame.new(0, 1.45, 0), COLOR.MaderaPintada, Enum.Material.Wood, m)
end

------------------------------------------------------------------------------------------------------------------------
-- Vallas de jardín de madera (pintura blanca vieja), con tramos torcidos, caídos o que faltan.

-- Un tramo recto de `a` a `b` (a ras del suelo). Choca una caja invisible salvo caído.
local function tramoValla(a: Vector3, b: Vector3, padre: Instance)
	local largo = (b - a).Magnitude
	local suerte = azar:NextNumber()
	if suerte < 0.07 then
		-- Falta: solo queda el poste.
		solido("PosteValla", Vector3.new(0.35, 3.2, 0.35), CFrame.new(a + Vector3.new(0, 1.6, 0)), COLOR.MaderaPintada, Enum.Material.Wood, padre)
		return
	end
	local mira = CFrame.lookAt(a, b) -- -Z a lo largo del tramo
	local cf = mira
	local caido = suerte < 0.25
	local torcido = not caido and suerte < 0.4
	if caido then
		-- Tumbado hacia un lado, apoyado en el suelo.
		local lado = if azar:NextNumber() < 0.5 then 1 else -1
		cf = mira * CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.rad(86 * lado))
	elseif torcido then
		cf = mira * CFrame.Angles(0, 0, math.rad(azar:NextNumber(12, 22) * (if azar:NextNumber() < 0.5 then 1 else -1)))
	end
	local pintura = COLOR.MaderaPintada:Lerp(Color3.fromRGB(42, 37, 32), azar:NextNumber(0, 0.6))
	if not caido then
		solido("PosteValla", Vector3.new(0.35, 3.2, 0.35), CFrame.new(a + Vector3.new(0, 1.6, 0)), pintura, Enum.Material.Wood, padre)
	end
	for _, y in { 0.9, 2.2 } do
		suelta("Travesano", Vector3.new(0.12, 0.3, largo), cf * CFrame.new(0, y, -largo / 2), pintura, Enum.Material.Wood, padre)
	end
	local n = math.floor(largo / 0.55)
	for i = 1, n - 1 do
		if azar:NextNumber() < 0.1 then
			continue -- una tabla que falta
		end
		local alto = azar:NextNumber(2.4, 2.9)
		local giro = if azar:NextNumber() < 0.08 then math.rad(azar:NextNumber(-25, 25)) else 0
		suelta("Tabla", Vector3.new(0.08, alto, 0.38), cf * CFrame.new(0.1, alto / 2 + 0.2, -i * largo / n) * CFrame.Angles(giro, 0, 0),
			pintura, Enum.Material.Wood, padre)
	end
	if not caido then
		local medio = (a + b) / 2
		choque(Vector3.new(0.5, 3, largo), CFrame.lookAt(medio, b) * CFrame.new(0, 1.5, 0), padre)
	end
end

-- Valla de `a` a `b` en tramos de unos 3,5.
local function valla(a: Vector3, b: Vector3, padre: Instance)
	local largo = (b - a).Magnitude
	local n = math.max(1, math.round(largo / 3.5))
	for i = 0, n - 1 do
		tramoValla(a:Lerp(b, i / n), a:Lerp(b, (i + 1) / n), padre)
	end
end

local function vallasYBuzones()
	local carpetaVallas = Instance.new("Folder")
	carpetaVallas.Name = "Vallas"
	carpetaVallas.Parent = carpeta
	local P = ctx.Plano
	local estados = { "bien", "torcido", "bien", "caido", "torcido", "bien", "torcido" }
	local k = 0
	for _, e in P.edificios do
		if e.nombre == "Tienda" or e.nombre == "Iglesia" or e.nombre == "Cripta" or e.nombre == "CasetaEnterrador" then
			continue
		end
		k += 1
		local fuera = P.LADOS[e.puerta]
		if fuera.X ~= 0 then
			-- Valla delante (con el paso de 6 a la puerta) y dos vueltas hasta la esquina de la casa.
			local lado = if e.x < 0 then -1 else 1
			local x = lado * CALLE.valla
			local z1, z2 = e.z - e.largo / 2 - 1.5, e.z + e.largo / 2 + 1.5
			valla(Vector3.new(x, 0, z1), Vector3.new(x, 0, e.z - 3), carpetaVallas)
			valla(Vector3.new(x, 0, e.z + 3), Vector3.new(x, 0, z2), carpetaVallas)
			local esquina = e.x + fuera.X * (e.ancho / 2 + 1)
			valla(Vector3.new(x, 0, z1), Vector3.new(esquina, 0, z1), carpetaVallas)
			valla(Vector3.new(x, 0, z2), Vector3.new(esquina, 0, z2), carpetaVallas)
			buzon(lado * (CALLE.acera - 0.4), e.z + 4.2, lado * math.pi / 2, estados[k])
		else
			-- La casa del fondo: valla a lo ancho por delante (+z, a la calle), a los lados del camino.
			local z = e.z + e.largo / 2 + 4.5
			valla(Vector3.new(e.x - e.ancho / 2 - 2, 0, z), Vector3.new(e.x - 3, 0, z), carpetaVallas)
			valla(Vector3.new(e.x + 3, 0, z), Vector3.new(e.x + e.ancho / 2 + 2, 0, z), carpetaVallas)
			buzon(e.x + 4, z + 1.2, math.pi, estados[k])
		end
	end
end

------------------------------------------------------------------------------------------------------------------------
-- El coche abandonado, aparcado a la izquierda de la calle con una rueda menos.

local function coche()
	local m = grupo("CocheAbandonado")
	local base = CFrame.new(-2.7, ALTO.calzada, -497) * CFrame.Angles(0, math.rad(6), 0)
	-- Las ruedas que le quedan (la de delante izquierda, robada: el coche cae sobre unos ladrillos).
	for _, r in { { 1, 4.3 }, { -1, 4.3 }, { 1, -4.4 } } do
		mueble("RuedaCoche", base * CFrame.new(2.75 * r[1], 0, r[2]), true, m)
	end
	for i = 0, 1 do
		suelta("Ladrillo", Vector3.new(1, 0.5, 1.6), base * CFrame.new(-2.4, 0.25 + i * 0.5, -4.4) * CFrame.Angles(0, i * 0.3, 0),
			Color3.fromRGB(110, 58, 46), Enum.Material.Brick, m)
	end
	local cuerpo = base * CFrame.new(0, 0.95, 0) * CFrame.Angles(math.rad(-1), 0, math.rad(1.5))
	local carroceria = mueble("CocheViejo", cuerpo, true, m)
	if carroceria then
		choque(Vector3.new(6.2, 4, 13.6), base * CFrame.new(0, 2.6, 0), m)
	else
		-- Sin las mallas: bloques.
		solido("Chasis", Vector3.new(6.4, 2.1, 13.6), base * CFrame.new(0, 2, 0), COLOR.Oxido, Enum.Material.CorrodedMetal, m)
		solido("Cabina", Vector3.new(6.2, 1.8, 6), base * CFrame.new(0, 4, 1.4), COLOR.Oxido, Enum.Material.CorrodedMetal, m)
	end
	-- El neumático que quitaron, tirado en la acera, y cristales rotos alrededor.
	mueble("NeumaticoPH", CFrame.new(-7.6, ALTO.acera + 0.33, -490) * CFrame.Angles(0, 0.7, 0) * CFrame.Angles(math.pi / 2, 0, 0)
		* CFrame.new(0, -1.2, 0), true, m)
	for _ = 1, 14 do
		local p = (base * CFrame.new(azar:NextNumber(-4.5, 4.5), 0, azar:NextNumber(-8, 3))).Position
		if math.abs(p.X + 2.7) < 3 and p.Z > -504 and p.Z < -490 then
			p += Vector3.new(-3.6, 0, 0) -- debajo del coche no se vería
		end
		cristal(p.X, p.Z, m)
	end
	-- Sangre seca junto a la puerta del conductor y arrastrada hacia la acera.
	mancha(Vector3.new(-6.9, ALTO.calzada + 0.06, -496), Vector3.yAxis, 2.6, m)
	mancha(Vector3.new(-7.8, ALTO.acera + 0.06, -494.5), Vector3.yAxis, 2, m)
end

------------------------------------------------------------------------------------------------------------------------
-- Lo vivo y lo roto: hierba alta, hojarasca, árboles secos, escombros y cristales bajo las ventanas.

-- Mata de hierba alta seca: unas hojas finas abiertas hacia fuera.
local function hierba(x: number, z: number, alto: number, padre: Instance)
	local y = sueloEn(x, z)
	local color = COLOR.Hierba:Lerp(COLOR.HierbaVerde, azar:NextNumber(0, 0.7))
	local giro0 = azar:NextNumber(0, math.pi * 2)
	for i = 1, 5 do
		local h = alto * azar:NextNumber(0.7, 1.1)
		local cf = CFrame.new(x, y, z) * CFrame.Angles(0, giro0 + i * 1.3, 0) * CFrame.Angles(math.rad(azar:NextNumber(10, 28)), 0, 0)
		suelta("Hierba", Vector3.new(0.22, h, 0.04), cf * CFrame.new(0, h / 2, 0), color, Enum.Material.Grass, padre)
	end
end

local function hojarasca(x: number, z: number, radio: number, padre: Instance)
	for _ = 1, azar:NextInteger(5, 9) do
		local px, pz = x + azar:NextNumber(-radio, radio), z + azar:NextNumber(-radio, radio)
		suelta("Hoja", Vector3.new(azar:NextNumber(0.3, 0.6), 0.02, azar:NextNumber(0.25, 0.45)),
			CFrame.new(px, sueloEn(px, pz) + 0.02, pz) * CFrame.Angles(azar:NextNumber(-0.1, 0.1), azar:NextNumber(0, math.pi * 2), 0),
			COLOR.Hoja[azar:NextInteger(1, #COLOR.Hoja)], Enum.Material.Fabric, padre)
	end
end

-- Árbol seco de ramas desnudas (de piezas): `pos` al pie.
local function arbolSeco(pos: Vector3, alto: number, padre: Instance)
	local m = grupo("ArbolSeco", padre)
	local cf = CFrame.new(pos) * CFrame.Angles(math.rad(azar:NextNumber(-5, 5)), azar:NextNumber(0, math.pi * 2), math.rad(azar:NextNumber(-5, 5)))
	local grueso = alto / 12
	cilindro(solido("Tronco", Vector3.new(alto, grueso, grueso), cf * CFrame.new(0, alto / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		COLOR.Poste:Lerp(COLOR.Piedra, 0.25), Enum.Material.Wood, m))
	for i = 1, 6 do
		local salida = cf * CFrame.new(0, alto * (0.45 + i * 0.08), 0) * CFrame.Angles(0, i * 2.2, 0)
		local largo = alto * azar:NextNumber(0.3, 0.5) * (1 - i * 0.07)
		local rama = salida * CFrame.Angles(math.rad(azar:NextNumber(35, 60)), 0, 0)
		cilindro(suelta("Rama", Vector3.new(largo, grueso * 0.4, grueso * 0.4), rama * CFrame.new(0, largo / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
			COLOR.Poste:Lerp(COLOR.Piedra, 0.25), Enum.Material.Wood, m))
		local punta = rama * CFrame.new(0, largo * 0.7, 0) * CFrame.Angles(math.rad(azar:NextNumber(-40, 40)), 0, math.rad(azar:NextNumber(-30, 30)))
		local corto = largo * 0.5
		cilindro(suelta("Ramita", Vector3.new(corto, grueso * 0.2, grueso * 0.2), punta * CFrame.new(0, corto / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
			COLOR.Poste:Lerp(COLOR.Piedra, 0.25), Enum.Material.Wood, m))
	end
end

local function cristalesBajo(e, w, padre: Instance)
	local cf = ctx.Plano.ventanaCF(e, w)
	for _ = 1, 7 do
		local p = (cf * CFrame.new(azar:NextNumber(-1.8, 1.8), 0, -azar:NextNumber(0.8, 2.4))).Position
		cristal(p.X, p.Z, padre)
	end
end

local function escombros(pos: Vector3, padre: Instance)
	for _ = 1, azar:NextInteger(3, 5) do
		local p = pos + Vector3.new(azar:NextNumber(-1.6, 1.6), 0, azar:NextNumber(-1.6, 1.6))
		local y = sueloEn(p.X, p.Z)
		if azar:NextNumber() < 0.5 then
			suelta("Tablon", Vector3.new(0.5, 0.12, azar:NextNumber(2, 3.5)),
				CFrame.new(p.X, y + 0.1, p.Z) * CFrame.Angles(azar:NextNumber(-0.15, 0.15), azar:NextNumber(0, 3), 0), COLOR.Madera,
				Enum.Material.Wood, padre)
		else
			suelta("Ladrillo", Vector3.new(0.8, 0.4, 0.4),
				CFrame.new(p.X, y + 0.2, p.Z) * CFrame.Angles(azar:NextNumber(-0.3, 0.3), azar:NextNumber(0, 3), azar:NextNumber(-0.3, 0.3)),
				Color3.fromRGB(104, 58, 46), Enum.Material.Brick, padre)
		end
	end
end

local function vegetacionYRestos()
	local verde = Instance.new("Folder")
	verde.Name = "Hierba"
	verde.Parent = carpeta
	local restos = Instance.new("Folder")
	restos.Name = "Restos"
	restos.Parent = carpeta
	-- Hierba alta: junto a las vallas, por los jardines y detrás de las casas.
	local puestas, intentos = 0, 0
	while puestas < 60 and intentos < 900 do
		intentos += 1
		local x, z = azar:NextNumber(-32, 34), azar:NextNumber(-545, -396)
		if not libreFuera(x, z, 0.8) then
			continue
		end
		hierba(x, z, azar:NextNumber(1.6, 3.2), verde)
		puestas += 1
	end
	-- Hierbajos junto al bordillo, en la cuneta (cortos: no tapan nada).
	for _ = 1, 22 do
		local lado = if azar:NextNumber() < 0.5 then -1 else 1
		hierba(lado * azar:NextNumber(5.6, 5.9), azar:NextNumber(CALLE.acera1 + 1, CALLE.acera2 - 1), azar:NextNumber(0.6, 1.2), verde)
	end
	-- Helechos y arbustos (de Blender) por los jardines y junto a las casas.
	for _ = 1, 26 do
		local x, z = azar:NextNumber(-34, 36), azar:NextNumber(-545, -400)
		if not libreFuera(x, z, 1.5) then
			continue
		end
		local nombre = if azar:NextNumber() < 0.55 then "Helecho" else "Arbusto"
		local partes = planta(nombre, CFrame.new(x, 0, z) * CFrame.Angles(0, azar:NextNumber(0, math.pi * 2), 0), azar:NextNumber(0.6, 1.1), verde)
		for _, p in partes do
			p.Color = p.Color:Lerp(COLOR.Hierba, 0.45) -- secos
		end
	end
	-- Hojarasca: en los bordillos, en las esquinas de las vallas y en la plaza.
	for _ = 1, 26 do
		local lado = if azar:NextNumber() < 0.5 then -1 else 1
		hojarasca(lado * azar:NextNumber(4.8, 8.6), azar:NextNumber(CALLE.z1 + 2, CALLE.z2 - 2), 1, verde)
	end
	for _, s in { { 14, -495 }, { 19, -505 }, { 12, -506 }, { -11, -470 }, { 11, -450 }, { 30, -478 }, { -12, -497 } } do
		hojarasca(s[1], s[2], 1.6, verde)
	end
	-- Árboles secos: en un jardín, junto al cartel y detrás de las casas.
	arbolSeco(Vector3.new(12.5, 0, -428), 16, verde)
	arbolSeco(Vector3.new(-13, 0, -398), 14, verde)
	for _, s in { { -34, -445, 15 }, { 33, -428, 13 }, { -33, -520, 17 }, { 13, -546, 14 } } do
		arbolSeco(Vector3.new(s[1], 0, s[2]), s[3], verde)
	end
	-- Cristales rotos bajo las ventanas de los lados (las de delante caen en los porches) y escombros.
	local P = ctx.Plano
	for _, sitio in { { "CasaCerrada1", "N" }, { "Tienda", "N" }, { "CasaCerrada3", "N" }, { "CasaAbierta", "N" }, { "CasaCerrada2", "S" },
		{ "CasaCerrada4", "S" } } do
		local e = P.buscar(sitio[1])
		for _, w in e.ventanas do
			if w.lado == sitio[2] and w.planta == 1 then
				cristalesBajo(e, w, restos)
				break
			end
		end
	end
	for _, s in { { -11.5, -463 }, { -11, -445 }, { 12.5, -470 }, { -12.5, -500 }, { 13, -431 }, { -6, -535.5 } } do
		escombros(Vector3.new(s[1], 0, s[2]), restos)
	end
	-- Cubos de basura: junto a la tienda (uno tumbado) y en la casa abierta.
	cuboBasura(Vector3.new(-11, 0.4, -460.8), false, restos)
	cuboBasura(Vector3.new(-11.2, 0, -464.6), true, restos)
	cuboBasura(Vector3.new(11.6, 0, -450), false, restos)
	mueble("BidonGasolinaPH", CFrame.new(-9.9, 0.4, -460.6) * CFrame.Angles(0, 1.1, 0), true, restos)
	mueble("CajaCartonPH", CFrame.new(-11.4, 0.4, -449.4) * CFrame.Angles(0, 0.4, 0), true, restos)
	mueble("BarrilPH", CFrame.new(12.6, 0, -473.5) * CFrame.Angles(0, 0.3, 0), false, restos)
	-- Sangre seca en la acera, delante de la casa abierta (como si alguien se arrastrara a la puerta).
	mancha(Vector3.new(8.4, ALTO.acera + 0.06, -441.5), Vector3.yAxis, 2.2, restos)
end

------------------------------------------------------------------------------------------------------------------------
-- El cementerio detrás de la iglesia: valla de hierro con la entrada al oeste, tumbas, cruces, un ángel y tierra removida.
-- La cripta y la caseta del enterrador son edificios del plano (PuebloFachadas / PuebloInteriores).

-- Valla de hierro de `a` a `b`: barrotes con punta, dos barras y postes cada 10. Choca una pared invisible.
local function vallaHierro(a: Vector3, b: Vector3, padre: Instance)
	local largo = (b - a).Magnitude
	local mira = CFrame.lookAt(a, b)
	local y0 = ALTO.cementerio
	for _, y in { 0.7, 3.7 } do
		suelta("Barra", Vector3.new(0.12, 0.14, largo), mira * CFrame.new(0, y0 + y, -largo / 2), COLOR.Hierro, Enum.Material.Metal, padre)
	end
	local n = math.floor(largo / 0.8)
	for i = 0, n do
		local d = i * largo / n
		if i % 12 == 0 then
			solido("PosteHierro", Vector3.new(0.4, 4.8, 0.4), mira * CFrame.new(0, y0 + 2.4, -d), COLOR.Hierro, Enum.Material.Metal, padre)
			suelta("Bola", Vector3.new(0.6, 0.6, 0.6), mira * CFrame.new(0, y0 + 5, -d), COLOR.Hierro, Enum.Material.Metal, padre).Shape =
				Enum.PartType.Ball
		elseif azar:NextNumber() > 0.06 then
			local doblado = if azar:NextNumber() < 0.08 then math.rad(azar:NextNumber(-18, 18)) else 0
			local barrote = mira * CFrame.new(0, y0, -d) * CFrame.Angles(doblado, 0, 0)
			suelta("Barrote", Vector3.new(0.12, 4.2, 0.12), barrote * CFrame.new(0, 2.1, 0), COLOR.Hierro, Enum.Material.Metal, padre)
			suelta("Punta", Vector3.new(0.22, 0.35, 0.22), barrote * CFrame.new(0, 4.3, 0) * CFrame.Angles(0, math.pi / 4, 0), COLOR.Hierro,
				Enum.Material.Metal, padre)
		end
	end
	choque(Vector3.new(0.4, 5, largo), mira * CFrame.new(0, y0 + 2.5, -largo / 2), padre)
end

-- Una hoja de la cancela (3 de ancho, hacia -Z desde la bisagra).
local function hojaCancela(bisagra: CFrame, padre: Instance)
	for _, y in { 0.6, 2.4, 4.2 } do
		suelta("Barra", Vector3.new(0.14, 0.14, 2.9), bisagra * CFrame.new(0, y, -1.45), COLOR.Hierro, Enum.Material.Metal, padre)
	end
	for i = 0, 6 do
		suelta("Barrote", Vector3.new(0.12, 4.6, 0.12), bisagra * CFrame.new(0, 2.5, -0.1 - i * 0.45), COLOR.Hierro, Enum.Material.Metal,
			padre)
	end
end

local function lapida(base: CFrame, padre: Instance)
	-- base: a ras del suelo, -Z hacia donde mira la lápida (oeste, a la entrada).
	local tipo = azar:NextInteger(1, 5)
	local piedra = COLOR.Piedra:Lerp(COLOR.Musgo, azar:NextNumber(0, 0.5)):Lerp(COLOR.Grieta, azar:NextNumber(0, 0.25))
	local cf = base * CFrame.Angles(math.rad(azar:NextNumber(-9, 9)), 0, math.rad(azar:NextNumber(-7, 7)))
	if tipo == 1 or tipo == 2 then
		-- Redondeada arriba.
		local alto = azar:NextNumber(1.8, 2.8)
		solido("Lapida", Vector3.new(2, alto, 0.4), cf * CFrame.new(0, alto / 2, 0), piedra, Enum.Material.Slate, padre)
		cilindro(suelta("Remate", Vector3.new(0.4, 2, 2), cf * CFrame.new(0, alto, 0) * CFrame.Angles(0, math.pi / 2, 0), piedra,
			Enum.Material.Slate, padre))
	elseif tipo == 3 then
		-- Cruz de piedra.
		solido("Cruz", Vector3.new(0.45, 3.4, 0.45), cf * CFrame.new(0, 1.7, 0), piedra, Enum.Material.Slate, padre)
		suelta("Cruz", Vector3.new(1.8, 0.45, 0.45), cf * CFrame.new(0, 2.6, 0), piedra, Enum.Material.Slate, padre)
		suelta("Peana", Vector3.new(1.2, 0.5, 1), base * CFrame.new(0, 0.25, 0), piedra, Enum.Material.Slate, padre)
	elseif tipo == 4 then
		-- Rota: queda el pie y el trozo de arriba en el suelo.
		local alto = azar:NextNumber(0.8, 1.3)
		solido("Lapida", Vector3.new(2, alto, 0.4), cf * CFrame.new(0, alto / 2, 0), piedra, Enum.Material.Slate, padre)
		suelta("Trozo", Vector3.new(1.9, 0.4, 1.4), base * CFrame.new(azar:NextNumber(-0.4, 0.4), 0.2, -1) * CFrame.Angles(0.08, azar:NextNumber(-0.5, 0.5), 0),
			piedra, Enum.Material.Slate, padre)
	else
		-- Obelisco pequeño sobre un pedestal.
		solido("Pedestal", Vector3.new(1.4, 0.9, 1.4), cf * CFrame.new(0, 0.45, 0), piedra, Enum.Material.Slate, padre)
		solido("Obelisco", Vector3.new(0.8, 3.2, 0.8), cf * CFrame.new(0, 2.5, 0), piedra, Enum.Material.Slate, padre)
		suelta("Punta", Vector3.new(0.55, 0.55, 0.55), cf * CFrame.new(0, 4.2, 0) * CFrame.Angles(math.pi / 4, 0, math.pi / 4), piedra,
			Enum.Material.Slate, padre)
	end
end

-- Una tumba: lápida al este y, delante (al oeste), losa, montón de tierra o bordillo con tierra. Centro (x, z).
local function tumba(x: number, z: number, losa: boolean, padre: Instance): Part?
	local m = grupo("Tumba", padre)
	local y = ALTO.cementerio
	lapida(CFrame.new(x + 2.3, y, z) * CFrame.Angles(0, math.pi / 2, 0), m)
	if losa then
		return solido("Losa", Vector3.new(4.6, 0.5, 2.4), CFrame.new(x, 0.25, z), COLOR.Piedra:Lerp(COLOR.Grieta, 0.2), Enum.Material.Slate, m)
	end
	if azar:NextNumber() < 0.5 then
		suelta("Tierra", Vector3.new(4, 0.5, 2), CFrame.new(x - 0.2, y + 0.1, z) * CFrame.Angles(0, 0, math.rad(azar:NextNumber(-3, 3))), COLOR.Tierra,
			Enum.Material.Ground, m)
	else
		local bordillo = COLOR.Piedra:Lerp(COLOR.Musgo, 0.4)
		for _, dz in { -1.1, 1.1 } do
			suelta("Borde", Vector3.new(4.4, 0.35, 0.25), CFrame.new(x - 0.1, y + 0.17, z + dz), bordillo, Enum.Material.Slate, m)
		end
		suelta("Tierra", Vector3.new(4.2, 0.2, 2), CFrame.new(x - 0.1, y + 0.06, z), COLOR.Tierra:Lerp(COLOR.HierbaVerde, 0.3), Enum.Material.Ground, m)
	end
	return nil
end

local function angel(pos: Vector3, padre: Instance)
	local m = grupo("Angel", padre)
	local piedra = COLOR.Piedra:Lerp(COLOR.Musgo, 0.35)
	local base = CFrame.new(pos) * CFrame.Angles(0, math.pi / 2, 0) -- mira al oeste, a la entrada
	solido("Pedestal", Vector3.new(2.8, 1.6, 2.8), base * CFrame.new(0, 0.8, 0), piedra:Lerp(COLOR.Grieta, 0.15), Enum.Material.Slate, m)
	solido("Tunica", Vector3.new(1.5, 3.6, 1.1), base * CFrame.new(0, 3.4, 0), piedra, Enum.Material.Slate, m)
	suelta("Falda", Vector3.new(1.9, 1.2, 1.4), base * CFrame.new(0, 2.2, 0), piedra, Enum.Material.Slate, m)
	-- Sin cabeza: la cabeza está en el suelo, al pie del pedestal.
	suelta("Cuello", Vector3.new(0.4, 0.3, 0.4), base * CFrame.new(0, 5.35, 0), piedra, Enum.Material.Slate, m)
	suelta("Cabeza", Vector3.new(0.85, 0.85, 0.85), base * CFrame.new(0.9, ALTO.cementerio + 0.4 - pos.Y, -2.2), piedra, Enum.Material.Slate, m).Shape =
		Enum.PartType.Ball
	-- Brazos juntos delante, rezando, y las alas abiertas detrás.
	for _, lado in { -1, 1 } do
		suelta("Brazo", Vector3.new(0.35, 1.5, 0.35), base * CFrame.new(lado * 0.55, 4.3, -0.55) * CFrame.Angles(math.rad(-50), 0, math.rad(lado * -20)),
			piedra, Enum.Material.Slate, m)
		suelta("Ala", Vector3.new(0.18, 3.8, 1.9), base * CFrame.new(lado * 0.75, 3.9, 1) * CFrame.Angles(math.rad(-12), math.rad(lado * -25), math.rad(lado * -8)),
			piedra, Enum.Material.Slate, m)
	end
end

local function cementerio()
	local P = ctx.Plano
	local c = P.CEMENTERIO
	local m = Instance.new("Folder")
	m.Name = "Cementerio"
	m.Parent = carpeta
	CollectionService:AddTag(solido("Cementerio", Vector3.new(c.x2 - c.x1, 0.2, c.z2 - c.z1), CFrame.new((c.x1 + c.x2) / 2, 0.1, (c.z1 + c.z2) / 2),
		COLOR.Tierra:Lerp(COLOR.HierbaVerde, 0.25), Enum.Material.Ground, m), "EnMapa")

	-- Valla de hierro; la entrada al oeste, frente a la iglesia, entre dos pilares de piedra.
	local e1, e2 = c.entrada[1], c.entrada[2]
	vallaHierro(Vector3.new(c.x1, 0, c.z1), Vector3.new(c.x2, 0, c.z1), m)
	vallaHierro(Vector3.new(c.x2, 0, c.z1), Vector3.new(c.x2, 0, c.z2), m)
	vallaHierro(Vector3.new(c.x2, 0, c.z2), Vector3.new(c.x1, 0, c.z2), m)
	vallaHierro(Vector3.new(c.x1, 0, c.z2), Vector3.new(c.x1, 0, e2 + 0.7), m)
	vallaHierro(Vector3.new(c.x1, 0, e1 - 0.7), Vector3.new(c.x1, 0, c.z1), m)
	for _, z in { e1 - 0.6, e2 + 0.6 } do
		solido("Pilar", Vector3.new(1.2, 6.2, 1.2), CFrame.new(c.x1, 3.1, z), COLOR.Piedra:Lerp(COLOR.Musgo, 0.3), Enum.Material.Slate, m)
		suelta("Remate", Vector3.new(1.5, 0.4, 1.5), CFrame.new(c.x1, 6.4, z), COLOR.Piedra, Enum.Material.Slate, m)
	end
	-- La cancela: una hoja abierta contra la valla de dentro y la otra colgando de una bisagra, medio caída.
	hojaCancela(CFrame.new(c.x1 + 0.3, ALTO.cementerio, e1) * CFrame.Angles(0, math.rad(-15), 0), m)
	hojaCancela(CFrame.new(c.x1 + 0.3, ALTO.cementerio, e2) * CFrame.Angles(0, math.rad(-127), 0) * CFrame.Angles(0, 0, math.rad(-9)) * CFrame.new(0, -0.3, 0), m)
	mancha(Vector3.new(c.x1 - 0.62, 3.2, e2 + 0.6), -Vector3.xAxis, 1.6, m)

	-- Caminos de grava: de la entrada al ángel y una rama que lleva a la cripta (norte) y a la caseta (sur).
	local zm = (e1 + e2) / 2
	local y = ALTO.cementerio + 0.06
	grava(Vector3.new(c.x1, 0, zm), Vector3.new(71, 0, zm), 3, y, m)
	local cripta, caseta = P.buscar("Cripta"), P.buscar("CasetaEnterrador")
	local xr = 67.5
	grava(Vector3.new(xr, 0, zm), Vector3.new(xr, 0, cripta.z), 3, y + 0.004, m)
	grava(Vector3.new(xr, 0, cripta.z), Vector3.new(cripta.x - cripta.ancho / 2 - 0.6, 0, cripta.z), 3, y + 0.008, m)
	grava(Vector3.new(xr, 0, zm), Vector3.new(xr, 0, caseta.z), 3, y + 0.004, m)
	grava(Vector3.new(xr, 0, caseta.z), Vector3.new(caseta.x - caseta.ancho / 2 - 0.6, 0, caseta.z), 3, y + 0.008, m)
	angel(Vector3.new(75, ALTO.cementerio, zm), m)

	-- Las tumbas: filas cada 6 en z; la de (50,8, -484) con losa de piedra, donde puede salir la llave.
	local losaLlave: Part? = nil
	for _, zt in { -520, -514, -508, -490, -484, -478 } do
		for _, xt in { 50.8, 57.4, 63 } do
			if xt == 63 and zt == -478 then
				continue -- la tumba abierta va aquí
			end
			local losa = tumba(xt, zt, xt == 50.8 and zt == -484 or azar:NextNumber() < 0.2, m)
			if xt == 50.8 and zt == -484 then
				losaLlave = losa
			end
		end
	end
	for _, s in { { 73.5, -508 }, { 79, -508 }, { 73.5, -491 }, { 79, -491 } } do
		tumba(s[1], s[2], azar:NextNumber() < 0.3, m)
	end
	-- Cruces de madera pequeñas, torcidas, entre las filas (no chocan).
	for _, s in { { 47, -517 }, { 54, -511 }, { 61, -487 }, { 47, -481 }, { 54, -523 }, { 79.5, -500 }, { 78.5, -495.5 } } do
		local cf = CFrame.new(s[1], ALTO.cementerio, s[2]) * CFrame.Angles(math.rad(azar:NextNumber(-14, 14)), -math.pi / 2, math.rad(azar:NextNumber(-12, 12)))
		suelta("CruzMadera", Vector3.new(0.25, 2.2, 0.15), cf * CFrame.new(0, 1.1, 0), COLOR.Madera, Enum.Material.Wood, m)
		suelta("CruzMadera", Vector3.new(1.1, 0.22, 0.15), cf * CFrame.new(0, 1.6, 0), COLOR.Madera, Enum.Material.Wood, m)
	end
	-- Una tumba abierta: el hoyo negro, la tierra amontonada al lado y la pala clavada.
	local hoyo = Vector3.new(63, ALTO.cementerio, -478)
	suelta("Hoyo", Vector3.new(4.2, 0.02, 2.2), CFrame.new(hoyo + Vector3.new(0, 0.01, 0)), COLOR.Hoyo, Enum.Material.Ground, m)
	for _, dz in { -1.2, 1.2 } do
		suelta("BordeHoyo", Vector3.new(4.4, 0.3, 0.3), CFrame.new(hoyo + Vector3.new(0, 0.1, dz)), COLOR.Tierra, Enum.Material.Ground, m)
	end
	lapida(CFrame.new(hoyo + Vector3.new(2.3, 0, 0)) * CFrame.Angles(0, math.pi / 2, 0), m)
	for i, t in { { 1.6, 1.1, 4.2 }, { 1.1, 0.6, 3 } } do
		solido("Monton", Vector3.new(t[3], t[2], t[1] + 0.4), CFrame.new(hoyo + Vector3.new(-0.2, t[2] / 2 - 0.05, -2.6 - (i - 1) * 0.3))
			* CFrame.Angles(math.rad(6 * i), 0.1, 0), COLOR.Tierra:Lerp(COLOR.Hoyo, 0.2), Enum.Material.Ground, m)
	end
	mueble("PalaPH", CFrame.new(hoyo + Vector3.new(0.8, 0.3, -2.7)) * CFrame.Angles(0.35, 0.8, 0.2), true, m)
	mancha(Vector3.new(hoyo.X - 2.6, ALTO.cementerio + 0.05, hoyo.Z - 0.3), Vector3.yAxis, 1.8, m)
	-- Tierra removida en otras dos (alguien ha estado cavando).
	for _, s in { { 57.4, -496 }, { 50.8, -511 } } do
		suelta("Removida", Vector3.new(3, 0.3, 1.6), CFrame.new(s[1], ALTO.cementerio + 0.1, s[2]) * CFrame.Angles(0, azar:NextNumber(-0.3, 0.3), 0),
			COLOR.Tierra:Lerp(COLOR.Hoyo, 0.3), Enum.Material.Ground, m)
	end
	-- Un árbol seco en la esquina y hierba alta junto a la valla.
	arbolSeco(Vector3.new(46, ALTO.cementerio, -521), 18, m)
	for _ = 1, 30 do
		local lado = azar:NextInteger(1, 4)
		local x = if lado == 1 then c.x1 + 0.8 elseif lado == 2 then c.x2 - 0.8 else azar:NextNumber(c.x1 + 1, c.x2 - 1)
		local z = if lado == 3 then c.z1 + 0.8 elseif lado == 4 then c.z2 - 0.8 else azar:NextNumber(c.z1 + 1, c.z2 - 1)
		if lado == 1 and math.abs(z - zm) < 4.5 or ocupado(x, z, 0.5) then
			continue
		end
		hierba(x, z, azar:NextNumber(1.4, 2.6), m)
	end
	-- Manchas de hierba rala sobre la tierra.
	for _ = 1, 14 do
		local x, z = azar:NextNumber(c.x1 + 3, c.x2 - 3), azar:NextNumber(c.z1 + 3, c.z2 - 3)
		if not ocupado(x, z, 0.5) then
			suelta("Hierbajo", Vector3.new(azar:NextNumber(3, 6), 0.04, azar:NextNumber(2, 5)), CFrame.new(x, ALTO.cementerio + azar:NextNumber(0.005, 0.025), z)
				* CFrame.Angles(0, azar:NextNumber(0, math.pi), 0), COLOR.HierbaVerde:Lerp(COLOR.Tierra, azar:NextNumber(0.2, 0.6)), Enum.Material.LeafyGrass, m)
		end
	end
	for _ = 1, 10 do
		hojarasca(azar:NextNumber(c.x1 + 2, c.x2 - 4), azar:NextNumber(c.z1 + 2, c.z2 - 2), 1.4, m)
	end

	-- El banco de piedra junto al camino de la entrada (antes en (46, -500), en medio del paso: ahora a un lado).
	local banco = Vector3.new(46.5, 0, zm - 4.5)
	for _, dx in { -1.2, 1.2 } do
		solido("PataBanco", Vector3.new(0.5, 0.85, 0.9), CFrame.new(banco + Vector3.new(dx, ALTO.cementerio + 0.42, 0)), COLOR.Piedra, Enum.Material.Slate, m)
	end
	solido("BancoPiedra", Vector3.new(3.2, 0.3, 1.1), CFrame.new(banco + Vector3.new(0, 1.05, 0)), COLOR.Piedra:Lerp(COLOR.Musgo, 0.3), Enum.Material.Slate, m)

	-- Las dos llaves de fuera, en este orden: la tumba y el banco.
	local alto = if losaLlave then losaLlave.Position.Y + losaLlave.Size.Y / 2 else 0.5
	ctx.llave("Cementerio", Vector3.new(50.8, alto + 0.2, -484))
	ctx.llave("Cementerio", banco + Vector3.new(0, 1.4, 0))
end

-- Bosque espeso alrededor del pueblo (pedido por el usuario: "pon bosque alrededor"; el del mapa es muy claro y el
-- pueblo quedaba en un descampado). Pinos como los del bosque en un anillo de 8 a 55 studs fuera de los edificios y del
-- cementerio, sin tapar la carretera que llega por el norte. A ojo: uno cada 10 studs más o menos.
local function bosque()
	local plano = ctx.Plano
	local c = plano.CEMENTERIO
	local x1, x2, z1, z2 = c.x1, c.x2, c.z1, c.z2
	for _, e in plano.edificios do
		x1, x2 = math.min(x1, e.x - e.ancho / 2), math.max(x2, e.x + e.ancho / 2)
		z1, z2 = math.min(z1, e.z - e.largo / 2), math.max(z2, e.z + e.largo / 2)
	end
	z2 = math.max(z2, CALLE.z2)
	local arboles = Instance.new("Folder")
	arboles.Name = "Bosque"
	local suerte = Random.new(116)
	local PASO, CERCA, LEJOS = 10, 8, 55
	for x = x1 - LEJOS, x2 + LEJOS, PASO do
		for z = z1 - LEJOS, z2 + LEJOS, PASO do
			local px, pz = x + suerte:NextNumber(-4, 4), z + suerte:NextNumber(-4, 4)
			-- Distancia al rectángulo del pueblo (0 dentro).
			local dx = math.max(x1 - px, 0, px - x2)
			local dz = math.max(z1 - pz, 0, pz - z2)
			local fuera = math.sqrt(dx * dx + dz * dz)
			local carretera = math.abs(px) < 11 and pz > z2 - 1
			if fuera < CERCA or fuera > LEJOS or carretera or suerte:NextNumber() < 0.15 then
				continue
			end
			ctx.Mapa.arbol(px, pz, suerte:NextNumber(40, 75), suerte:NextNumber(2, 4), arboles)
		end
	end
	arboles.Parent = carpeta
end

function PuebloCalle.construir(contexto)
	ctx = contexto
	carpeta = contexto.carpeta
	azar = Random.new(115)
	local calle = calzada()
	caminos(calle)
	postesYCables()
	-- Farolas por los bordillos (ninguna encendida): dos bien, una torcida, una caída, una con el farol colgando.
	for _, f in { { -1, -412, "bien" }, { -1, -468, "torcida" }, { -1, -522, "caida" }, { 1, -428, "bien" }, { 1, -490, "rota" }, { 1, -527, "bien" } } do
		local x = f[1] * (CALLE.bordillo + 1)
		local pos = Vector3.new(x, ALTO.acera, f[2])
		farola(CFrame.lookAt(pos, pos - Vector3.new(f[1], 0, 0)), f[3])
	end
	cartelEntrada()
	vallasYBuzones()
	coche()
	vegetacionYRestos()
	cementerio()
	bosque()
end

return PuebloCalle
