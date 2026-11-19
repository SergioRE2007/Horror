-- Los sitios fuera de la casa (pedido por el usuario: todo con sentido, nada "por la cara"): granja, aserradero viejo,
-- torre del guardabosques en una colina y el pueblo abandonado al final de la carretera (iglesia con cementerio, la
-- tienda del vendedor y casas cerradas). De más cerca a más lejos, como las llaves.
-- Cada zona deja en Mapa.llaves los sitios donde puede salir su llave y en Mapa.objetos la comida y el agua (latas y
-- botellas, para el vendedor). El bosque no pone árboles dentro de las zonas (Lugares.libre).
-- La casa de la granja, el granero, la oficina del aserradero y la caseta del guarda tienen fachada de verdad, como las
-- del pueblo (PuebloFachadas.uno), y cuentan su parte de la historia (docs/historia.md: pistas 6 a 8): la cocina que
-- el granjero dejó deprisa, el boquete por el que algo se llevó a las vacas, el hoyo que cavó Harlan y el mapa del
-- guarda. Medidas a ojo (docs/sistemas/llaves.md). La cabaña del cazador, en LugarCazador.
local CollectionService = game:GetService("CollectionService")

local PuebloPlano = require(script.Parent.PuebloPlano)
local PuebloFachadas = require(script.Parent.PuebloFachadas)
local PuebloInteriores = require(script.Parent.PuebloInteriores)
local PuebloCalle = require(script.Parent.PuebloCalle)
local LugarCazador = require(script.Parent.LugarCazador)

local Lugares = {}

local COLOR = {
	Muro = Color3.fromRGB(118, 114, 108),
	Mueble = Color3.fromRGB(100, 95, 90),
	Oscuro = Color3.fromRGB(45, 43, 42),
	Madera = Color3.fromRGB(70, 62, 55),
	MaderaOscura = Color3.fromRGB(48, 36, 28),
	Tabla = Color3.fromRGB(78, 62, 46), -- tablas sueltas y astillas
	Astilla = Color3.fromRGB(150, 122, 92), -- madera recién arañada o partida
	Piedra = Color3.fromRGB(105, 105, 102),
	Tierra = Color3.fromRGB(62, 54, 46),
	TierraRemovida = Color3.fromRGB(52, 42, 33),
	Hoyo = Color3.fromRGB(14, 11, 9),
	Hierba = Color3.fromRGB(58, 62, 55),
	Paja = Color3.fromRGB(120, 108, 72),
	Serrin = Color3.fromRGB(136, 114, 82),
	Laton = Color3.fromRGB(96, 80, 50),
	Hierro = Color3.fromRGB(32, 30, 29),
	Cuerda = Color3.fromRGB(110, 92, 62),
	Cuero = Color3.fromRGB(62, 42, 30),
	Pintura = Color3.fromRGB(146, 140, 128), -- blanco desvaído de las aspas del granero
	Papel = Color3.fromRGB(156, 146, 118),
	Lona = Color3.fromRGB(74, 76, 54),
}

-- Imágenes de sangre seca (las de PuebloInteriores: tools/blender/sangre.py): ya traen su color, se oscurecen con SECA.
local SANGRE = {
	Gotas = "rbxassetid://100856467107255",
	Arrastre = "rbxassetid://95443489334328",
	Salpicadura = "rbxassetid://82919660578513",
}
local SECA = Color3.fromRGB(135, 95, 90)

-- Zonas sin árboles del bosque: { x, z, radio }.
local ZONAS = {
	Granja = { 205, 75, 55 },
	Aserradero = { -232, -86, 45 },
	Torre = { 90, 285, 70 },
	Pueblo = { 28, -480, 88 }, -- 11.5: llega a las casas nuevas de la entrada y del final de la calle
	Garaje = { -49, 18, 20 }, -- el de la casa (Mapa)
	Cazador = { -215, 235, 34 }, -- la cabaña del cazador (LugarCazador): lejos del anillo de los que se talan (42-170)
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
local raiz: Folder -- el mapa entero (para abrir el suelo del bosque bajo los agujeros)
local Mapa -- el módulo Mapa: aquí se apuntan las llaves y los objetos
local ctx -- lo que necesitan PuebloFachadas.uno y PuebloInteriores.forrar (bloque, Mapa, Plano, carpeta)

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

---------------------------------------------------------------------------------------------------------------------
-- Ayudas para lo de dentro y la historia. Lo que solo se ve no choca, no tapa rayos ni toca (no cierra el paso).

local function adorno(nombre: string, tamano: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, padre: Instance?): Part
	local p = bloque(nombre, tamano, cf, color, material or Enum.Material.Wood, padre)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = math.max(tamano.X, tamano.Y, tamano.Z) > 2.5 -- lo pequeño, sin sombra (pesa en móvil)
	return p
end

-- Caja invisible que choca y no tapa la vista (muebles hechos de piezas, tapas de los agujeros).
local function choque(tamano: Vector3, cf: CFrame, padre: Instance): Part
	local p = bloque("Choque", tamano, cf, nil, nil, padre)
	p.Transparency = 1
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p:SetAttribute("SinSeparar", true)
	return p
end

-- Montón (un elipsoide) de tierra, serrín o paja.
local function monton(nombre: string, tamano: Vector3, cf: CFrame, color: Color3, material: Enum.Material, padre: Instance): Part
	local p = adorno(nombre, tamano, cf, color, material, padre)
	local malla = Instance.new("SpecialMesh")
	malla.MeshType = Enum.MeshType.Sphere
	malla.Parent = p
	return p
end

-- Listón de `a` a `b` (que no vaya en vertical), `ancho` de lado y `grueso`.
local function liston(nombre: string, a: Vector3, b: Vector3, ancho: number, grueso: number, color: Color3, material: Enum.Material?,
	padre: Instance): Part
	return adorno(nombre, Vector3.new(ancho, grueso, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, material, padre)
end

-- Sobre una cara: -Z (LookVector) hacia `normal` (fuera de la cara) e Y hacia `arriba` (a lo largo de la cara). Sin
-- CFrame.lookAt, que con la normal hacia arriba no sabe hacia dónde girar.
local function enCara(pos: Vector3, normal: Vector3, arriba: Vector3): CFrame
	return CFrame.fromMatrix(pos, arriba:Cross(-normal), arriba, -normal)
end

-- Calcomanía de `ancho` × `largo` sobre una cara, con lo largo hacia `arriba` (la sangre arrastrada hacia un sitio).
local function manchaEn(pos: Vector3, normal: Vector3, arriba: Vector3, ancho: number, largo: number, imagen: string, padre: Instance)
	local p = adorno("Mancha", Vector3.new(ancho, largo, 0.04), enCara(pos, normal, arriba), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, padre)
	p.Transparency = 1
	p.CastShadow = false
	p:SetAttribute("SinSeparar", true)
	local d = Instance.new("Decal")
	d.Texture = imagen
	d.Color3 = SECA
	d.Face = Enum.NormalId.Front
	d.Parent = p
end

-- Zarpazo: `n` surcos paralelos de `largo` en la cara `cf` (de enCara), girados `giro` (radianes).
local function zarpazo(cf: CFrame, n: number, largo: number, giro: number, color: Color3, padre: Instance)
	for i = 1, n do
		local l = largo * (0.75 + 0.25 * math.sin(i * 2.1))
		adorno("Zarpazo", Vector3.new(l, 0.07, 0.03), cf * CFrame.Angles(0, 0, giro) * CFrame.new(0.1 * math.sin(i), (i - (n + 1) / 2) * 0.16, -0.015),
			color, Enum.Material.SmoothPlastic, padre)
	end
end

-- Telaraña en una esquina del techo, mirando a la sala (como en PuebloInteriores).
local function telarana(x: number, techo: number, z: number, mira: Vector3, escala: number)
	local molde = Mapa.MUEBLES and Mapa.MUEBLES.Telarana
	if not molde then
		return
	end
	local pos = Vector3.new(x, techo - (molde:GetAttribute("Tam") :: Vector3).Y * escala, z)
	local tela = Mapa.mueble("Telarana", CFrame.lookAt(pos, pos + mira), true)
	if tela then
		tela:ScaleTo(tela:GetScale() * escala)
	end
end

-- Cambia una pieza recta (sin girar) por los trozos de alrededor del hueco [x1, x2] × [z1, z2].
local function recortar(p: BasePart, x1: number, x2: number, z1: number, z2: number)
	local c, s = p.Position, p.Size
	local px1, px2, pz1, pz2 = c.X - s.X / 2, c.X + s.X / 2, c.Z - s.Z / 2, c.Z + s.Z / 2
	for _, r in { { px1, x1, pz1, pz2 }, { x2, px2, pz1, pz2 }, { x1, x2, pz1, z1 }, { x1, x2, z2, pz2 } } do
		if r[2] - r[1] > 0.01 and r[4] - r[3] > 0.01 then
			local trozo = p:Clone()
			trozo.Size = Vector3.new(r[2] - r[1], s.Y, r[4] - r[3])
			trozo.CFrame = CFrame.new((r[1] + r[2]) / 2, c.Y, (r[3] + r[4]) / 2)
			trozo.Parent = p.Parent
		end
	end
	p:Destroy()
end

-- Agujero en el suelo de [x1, x2] × [z1, z2] con el fondo a `fondo`: recorta `piezas` (el piso de un edificio y su
-- forro) y el trozo de suelo del bosque de debajo (Mapa; queda tierra bajo el fondo); paredes de tierra que se
-- oscurecen hacia abajo y el fondo casi negro. Una tapa invisible que choca, con la cara de arriba a `arriba`, lo
-- cubre: nadie se cae, pero se ve hondo.
local function agujero(x1: number, x2: number, z1: number, z2: number, arriba: number, fondo: number, piezas: { BasePart }, padre: Instance)
	for _, p in piezas do
		recortar(p, x1, x2, z1, z2)
	end
	local bosque = raiz:FindFirstChild("Bosque")
	local suelo: BasePart? = nil
	for _, p in (if bosque then bosque:GetChildren() else {}) do
		if p:IsA("BasePart") and p.Name == "Suelo" then
			local c, s = p.Position, p.Size
			if c.X - s.X / 2 <= x1 and x2 <= c.X + s.X / 2 and c.Z - s.Z / 2 <= z1 and z2 <= c.Z + s.Z / 2 then
				suelo = p
				break
			end
		end
	end
	if suelo then
		local abajo = suelo.Position.Y - suelo.Size.Y / 2
		local tapon = suelo:Clone()
		tapon.Size = Vector3.new(x2 - x1, fondo - abajo, z2 - z1)
		tapon.CFrame = CFrame.new((x1 + x2) / 2, (abajo + fondo) / 2, (z1 + z2) / 2)
		tapon.Parent = suelo.Parent
		recortar(suelo, x1, x2, z1, z2)
	else
		warn("[Lugares] un agujero no cae entero en un trozo de suelo del bosque: se queda sin hondo")
	end
	local cx, cz, w, d = (x1 + x2) / 2, (z1 + z2) / 2, x2 - x1, z2 - z1
	local medio = math.max(fondo, arriba - 0.9) -- tierra arriba; abajo, casi negro
	for _, l in { { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } } do
		local enX = l[1] == 0
		local x, z = cx + l[1] * (w / 2 - 0.05), cz + l[2] * (d / 2 - 0.05)
		for _, capa in { { medio, arriba, COLOR.TierraRemovida }, { fondo, medio, COLOR.Hoyo } } do
			if capa[2] - capa[1] > 0.01 then
				local alto = capa[2] - capa[1]
				local tam = if enX then Vector3.new(w, alto, 0.1) else Vector3.new(0.1, alto, d - 0.2)
				adorno("Tierra", tam, CFrame.new(x, (capa[1] + capa[2]) / 2, z), capa[3], Enum.Material.Ground, padre):SetAttribute("SinSeparar", true)
			end
		end
	end
	adorno("Fondo", Vector3.new(w - 0.2, 0.05, d - 0.2), CFrame.new(cx, fondo + 0.025, cz), COLOR.Hoyo, Enum.Material.Ground, padre)
		:SetAttribute("SinSeparar", true)
	choque(Vector3.new(w, 0.5, d), CFrame.new(cx, arriba - 0.25, cz), padre).Name = "Tapa"
end

-- Tierra removida alrededor de un agujero: montones y terrones por el suelo (a `y`), nunca encima del hueco.
local function tierraRemovida(x1: number, x2: number, z1: number, z2: number, y: number, azar: Random, padre: Instance)
	local cx, cz = (x1 + x2) / 2, (z1 + z2) / 2
	local function fuera(x: number, z: number, margen: number): boolean
		return x < x1 - margen or x > x2 + margen or z < z1 - margen or z > z2 + margen
	end
	local puestos = 0
	for _ = 1, 40 do
		if puestos >= 5 then
			break
		end
		local a = azar:NextNumber(0, math.pi * 2)
		local r = azar:NextNumber(0.5, 1.6)
		local x = cx + math.cos(a) * ((x2 - x1) / 2 + r)
		local z = cz + math.sin(a) * ((z2 - z1) / 2 + r)
		local tam = Vector3.new(azar:NextNumber(1.3, 2.3), azar:NextNumber(0.45, 0.75), azar:NextNumber(0.9, 1.5))
		if fuera(x, z, math.max(tam.X, tam.Z) / 2 + 0.05) then
			puestos += 1
			monton("Tierra", tam, CFrame.new(x, y + 0.04, z) * CFrame.Angles(0, azar:NextNumber(0, math.pi), 0),
				COLOR.TierraRemovida:Lerp(COLOR.Tierra, azar:NextNumber(0, 0.6)), Enum.Material.Ground, padre)
		end
	end
	for _ = 1, 12 do
		local x, z = cx + azar:NextNumber(-3.2, 3.2), cz + azar:NextNumber(-3.2, 3.2)
		local t = azar:NextNumber(0.22, 0.45)
		if fuera(x, z, t) then
			local p = adorno("Terron", Vector3.new(t, t, t), CFrame.new(x, y + t * 0.3, z), COLOR.TierraRemovida, Enum.Material.Ground, padre)
			p.Shape = Enum.PartType.Ball
		end
	end
end

-- Aro de tablas rotas alrededor de un agujero en un suelo de tablas (a `y`): astillas que salen hacia dentro, casi
-- todas levantadas (lo reventó algo desde abajo) y alguna colgando, y tablas sueltas tiradas alrededor.
local function tablasRotas(x1: number, x2: number, z1: number, z2: number, y: number, azar: Random, padre: Instance)
	local cx, cz = (x1 + x2) / 2, (z1 + z2) / 2
	for _, b in {
		{ Vector3.new(cx, y, z1), Vector3.zAxis, Vector3.xAxis, x2 - x1 }, { Vector3.new(cx, y, z2), -Vector3.zAxis, Vector3.xAxis, x2 - x1 },
		{ Vector3.new(x1, y, cz), Vector3.xAxis, Vector3.zAxis, z2 - z1 }, { Vector3.new(x2, y, cz), -Vector3.xAxis, Vector3.zAxis, z2 - z1 },
	} do
		local borde, dentro, lado, largo = b[1], b[2], b[3], b[4]
		for k = 1, 3 do
			local u = (k - 2) * largo / 3 + azar:NextNumber(-0.25, 0.25)
			local sube = azar:NextNumber(0.3, 0.95) * (if azar:NextNumber() < 0.75 then 1 else -1.2)
			local dir = dentro * math.cos(sube) + Vector3.yAxis * math.sin(sube)
			local l = azar:NextNumber(0.8, 1.6)
			local base = borde + lado * u - dentro * 0.3 + Vector3.new(0, -0.04, 0)
			local cf = CFrame.lookAt(base + dir * l / 2, base + dir * l) * CFrame.Angles(0, 0, azar:NextNumber(-0.25, 0.25))
			adorno("Astilla", Vector3.new(azar:NextNumber(0.3, 0.55), 0.12, l), cf, COLOR.Tabla:Lerp(COLOR.Astilla, azar:NextNumber(0, 0.4)),
				Enum.Material.WoodPlanks, padre)
		end
	end
	for i = 1, 3 do
		local a = i * 2.1 + azar:NextNumber(-0.4, 0.4)
		local x = cx + math.cos(a) * ((x2 - x1) / 2 + 1.6)
		local z = cz + math.sin(a) * ((z2 - z1) / 2 + 1.6)
		adorno("TablaSuelta", Vector3.new(0.5, 0.1, azar:NextNumber(1.8, 2.6)), CFrame.new(x, y + 0.06 + i * 0.01, z)
			* CFrame.Angles(0, azar:NextNumber(0, math.pi), azar:NextNumber(-0.05, 0.05)), COLOR.Tabla, Enum.Material.WoodPlanks, padre)
	end
end

local function v(lado: string, desde: number): PuebloPlano.Ventana
	return { lado = lado, desde = desde, planta = 1 }
end

-- Los cuatro con fachada, con la forma de PuebloPlano.Edificio y en el mismo sitio y con las mismas medidas que los
-- bloques de antes (el suelo de dentro a y = 1, la cara de dentro de cada pared a ancho/2 - 0,5 del centro): las
-- pistas, las llaves y los objetos cuentan con ellos. Las ventanas no pasan por mesas ni estantes con algo encima, ni
-- por los escondites (el armario de la cocina, en el rincón noroeste: sin la ventana norte de ese lado).
local CASA_GRANJA: PuebloPlano.Edificio = { nombre = "CasaGranja", x = 196, z = 52, ancho = 16, largo = 12, alto = 10, plantas = 1,
	puerta = "O", entra = true, material = "madera", ventanas = { v("O", -3.8), v("O", 3.8), v("N", 3), v("S", 4.5) } }
local GRANERO: PuebloPlano.Edificio = { nombre = "Granero", x = 228, z = 80, ancho = 20, largo = 24, alto = 14, plantas = 1,
	puerta = "O", entra = true, material = "madera", ventanas = { v("N", -4), v("N", 5), v("S", 6) } }
local OFICINA: PuebloPlano.Edificio = { nombre = "Oficina", x = -252, z = -74, ancho = 8, largo = 8, alto = 9, plantas = 1,
	puerta = "E", entra = true, material = "madera", ventanas = { v("S", 1.4) } }
local CASETA: PuebloPlano.Edificio = { nombre = "CasetaGuarda", x = 90, z = 238, ancho = 8, largo = 8, alto = 9, plantas = 1,
	puerta = "N", entra = true, material = "madera", ventanas = { v("O", 0.5) } }

-- Su aspecto (como ESTILO de PuebloFachadas) y cómo está la puerta (como PUERTA).
local ESTILO = {
	-- Tablas color crema desvaído, tejado a dos aguas con el hastial hacia el porche y chimenea.
	CasaGranja = { color = Color3.fromRGB(146, 132, 104), tejado = "dos", eje = "x", pendiente = 0.75, porche = true, chimenea = true,
		hiedra = "NE" },
	-- Rojo desvaído, alto y con mucha pendiente (el hastial, a la puerta).
	Granero = { color = Color3.fromRGB(118, 56, 46), tejado = "dos", eje = "x", pendiente = 0.95, alero = 1, vuelo = 1, hiedra = "NE" },
	Oficina = { color = Color3.fromRGB(88, 82, 72), tejado = "dos", eje = "z", pendiente = 0.45, alero = 0.8, vuelo = 0.5 },
	CasetaGuarda = { color = Color3.fromRGB(72, 82, 66), tejado = "dos", eje = "z", pendiente = 0.7, alero = 0.8, vuelo = 0.6, hiedra = "SE" },
}
local PUERTA = {
	CasaGranja = { puerta = "abierta", bisagra = 1, angulo = 70 },
	Granero = { puerta = "doble" },
	Oficina = { puerta = "abierta", bisagra = -1, angulo = 100, caida = 0.08 },
	CasetaGuarda = { puerta = "abierta", bisagra = 1, angulo = 55 },
}
local SEMILLA = { CasaGranja = 3101, Granero = 3102, Oficina = 3103, CasetaGuarda = 3104 }
-- Los de la granja, con sus ventanas, para el banco de los escondites (tests/bancos/escondites).
Lugares.EDIFICIOS = { CasaGranja = CASA_GRANJA, Granero = GRANERO }

local function fachada(e: PuebloPlano.Edificio): Model
	return PuebloFachadas.uno(ctx, e, ESTILO[e.nombre], PUERTA[e.nombre], SEMILLA[e.nombre])
end

---------------------------------------------------------------------------------------------------------------------
-- Granja (llave del sótano). La nota del granjero (pista 6): "Algo se come a las vacas desde abajo".

local F = 1.06 -- cara de arriba del suelo forrado (PuebloInteriores.forrar)

-- La cocina, dejada deprisa: la mesa en medio (pista 6 y una llave), la silla volcada, el candil apagado, la cocina de
-- hierro con su olla, la encimera con las latas y el armario de lamas (escondite: fuera de la casa, al anochecer solo
-- se corre o se esconde, Acechador).
local function cocinaGranja(m: Model)
	local e = CASA_GRANJA
	local x1, x2, z1, z2 = PuebloPlano.dentro(e) -- 188.5, 203.5, 46.5, 57.5
	local techo = 1 + e.alto
	PuebloInteriores.forrar(ctx, e, m, {
		{ y1 = 1, y2 = 1.45, color = COLOR.MaderaOscura, material = Enum.Material.Wood, grueso = 0.2 }, -- rodapié
		{ y1 = 1.45, y2 = 3.6, variante = "ParedCobertizo" }, -- arrimadero de tablas
		{ y1 = 3.5, y2 = 3.75, color = COLOR.MaderaOscura, material = Enum.Material.Wood, grueso = 0.2 },
		{ y1 = 3.6, y2 = techo - 0.02, variante = "PapelCocina" },
	}, "SueloDesvan", "TechoCocina")
	Mapa.conPadre(m, function()
		-- La mesa de lado en medio, con la cara de arriba a 4,02 (como la de bloques de antes: la pista y la llave).
		if not Mapa.mueble("MesaCocina", CFrame.new(196.55, 4.02 - 3.1, 51.65) * CFrame.Angles(0, math.pi / 2, 0)) then
			bloque("Mesa", Vector3.new(5, 3.1, 2.9), CFrame.new(196.55, 2.47, 51.65), COLOR.Mueble, nil, m)
		end
		Mapa.mueble("LamparaAceitePH", CFrame.new(194.75, 4.02, 52.55) * CFrame.Angles(0, 0.6, 0), true) -- el candil, apagado
		Mapa.mueble("PlatoPH", CFrame.new(198.4, 4.02, 50.9) * CFrame.Angles(0, 0.4, 0), true)
		-- La silla, volcada de espaldas entre la mesa y la cocina (se levantó de golpe).
		Mapa.mueble("SillaCocinaPH", CFrame.new(196.0, F + 1.08, 55.4) * CFrame.Angles(0, math.pi / 2 + 0.2, 0) * CFrame.Angles(math.pi / 2, 0, 0), true)
		-- La encimera contra la pared este: las dos latas de siempre encima (a 4,7).
		for _, z in { 50.2, 53.4 } do
			if not Mapa.contraPared("EncimeraCocina", x2 - 0.06, 1, z, -Vector3.xAxis) then
				bloque("Encimera", Vector3.new(2.5, 3.5, 3), CFrame.new(x2 - 1.3, 2.75, z), COLOR.Mueble, nil, m)
			end
		end
		-- La cocina de hierro contra la pared sur, con la olla encima.
		local hierro = Mapa.contraPared("CocinaHierro", 192.75, F, z2 - 0.06, -Vector3.zAxis)
		if hierro then
			Mapa.mueble("OllaPH", hierro:GetPivot() * CFrame.new(-1, 3.42, 0.1), true)
		end
		-- El retrato de la familia, torcido, entre el armario y la ventana del norte.
		local retrato = Mapa.contraPared("CuadroFamiliaPH", 196.1, 5.4, z1 + 0.11, Vector3.zAxis, true)
		if retrato then
			retrato:PivotTo(retrato:GetPivot() * CFrame.Angles(0, 0, math.rad(7)))
		end
		-- Barro y unas gotas secas de la puerta a la mesa; humedad y telarañas.
		Mapa.mancha(Vector3.new(190.6, F + 0.02, 51.4), Vector3.yAxis, 1.3, SANGRE.Gotas, SECA, 0.7)
		Mapa.mancha(Vector3.new(193.4, F + 0.02, 52.9), Vector3.yAxis, 0.9, SANGRE.Gotas, SECA, 2.1)
		Mapa.mancha(Vector3.new(x2 - 0.13, 8.6, 56), -Vector3.xAxis, 3, Mapa.SANGRE[1], Color3.fromRGB(46, 36, 24), 1.2)
		telarana(x1 + 0.4, techo, z1 + 0.4, Vector3.new(1, 0, 1), 0.45)
		telarana(x2 - 0.4, techo, z2 - 0.4, Vector3.new(-1, 0, -1), 0.45)
		-- El armario, contra la pared norte en el rincón de la puerta (ni tapa la puerta, ni la ventana del oeste, ni la
		-- mesa de la pista). Lo que pasó: a alguien lo sacaron de él a rastras hacia la puerta (arañazos de uñas por el
		-- suelo, que acaban en el umbral) y dejó unas gotas delante.
		Mapa.armario(Vector3.new(192.4, F + 4, z1 + 1.55), Vector3.zAxis)
		Mapa.mancha(Vector3.new(190.9, F + 0.01, 51.2), Vector3.yAxis, 2.6, Mapa.MARCAS.Aranazos, Color3.fromRGB(130, 80, 75), 0.12, 4.4)
		Mapa.mancha(Vector3.new(192.7, F + 0.03, 50.3), Vector3.yAxis, 1.5, SANGRE.Gotas, SECA, 0.6)
	end)
	objeto("Lata", Vector3.new(202.5, 4.7, 49.5))
	objeto("Lata", Vector3.new(202.5, 4.7, 54))
	llave("Granja", Vector3.new(197.5, 4.2, 52))
end

-- Tabique de establo a lo largo de x, de la delantera (x = 232) a la pared este: poste, cuatro tablas que chocan y el
-- pasamanos. `roto`: la segunda tabla partida, con un trozo colgando.
local function tabique(z: number, roto: boolean, m: Model)
	local xa, xb = 232, 237.38
	bloque("Poste", Vector3.new(0.5, 5, 0.5), CFrame.new(xa + 0.25, F + 2.5, z), COLOR.Madera, Enum.Material.Wood, m)
	local largo = xb - xa - 0.5
	for i, y in { 0.7, 1.75, 2.8, 3.85 } do
		if roto and i == 2 then
			bloque("Tabla", Vector3.new(2.2, 0.75, 0.25), CFrame.new(xa + 1.6, F + y, z), COLOR.Madera, Enum.Material.WoodPlanks, m)
			bloque("Tabla", Vector3.new(1.9, 0.75, 0.25), CFrame.new(xb - 0.95, F + y, z), COLOR.Madera, Enum.Material.WoodPlanks, m)
			adorno("Tabla", Vector3.new(1.4, 0.7, 0.22), CFrame.new(xa + 2.9, F + y - 0.25, z) * CFrame.Angles(0, 0, math.rad(-38)), COLOR.Madera,
				Enum.Material.WoodPlanks, m)
		else
			bloque("Tabla", Vector3.new(largo, 0.75, 0.25), CFrame.new(xa + 0.5 + largo / 2, F + y, z), COLOR.Madera, Enum.Material.WoodPlanks, m)
		end
	end
	bloque("Pasamanos", Vector3.new(largo + 0.5, 0.3, 0.4), CFrame.new(xa + largo / 2 + 0.25, F + 4.65, z), COLOR.MaderaOscura, Enum.Material.Wood, m)
end

-- El cencerro de una vaca, tumbado en el suelo (en `pie`) con la correa de cuero arrancada.
local function cencerro(pie: Vector3, giro: number, m: Model)
	local cf = CFrame.new(pie + Vector3.new(0, 0.22, 0)) * CFrame.Angles(0, giro, math.rad(8))
	adorno("Cencerro", Vector3.new(0.78, 0.42, 0.6), cf, COLOR.Laton, Enum.Material.Metal, m)
	adorno("Borde", Vector3.new(0.1, 0.48, 0.68), cf * CFrame.new(0.36, 0, 0), COLOR.Laton:Lerp(Color3.new(), 0.3), Enum.Material.Metal, m)
	adorno("Boca", Vector3.new(0.03, 0.36, 0.52), cf * CFrame.new(0.42, 0, 0), COLOR.Hoyo, Enum.Material.SmoothPlastic, m)
	adorno("Badajo", Vector3.new(0.16, 0.16, 0.16), cf * CFrame.new(0.44, -0.08, 0.05), COLOR.Hierro, Enum.Material.Metal, m).Shape =
		Enum.PartType.Ball
	adorno("Asa", Vector3.new(0.2, 0.12, 0.34), cf * CFrame.new(-0.47, 0, 0), COLOR.Hierro, Enum.Material.Metal, m)
	local a = cf * Vector3.new(-0.55, -0.18, 0)
	local b = Vector3.new(a.X, pie.Y + 0.03, a.Z) + (cf.RightVector * -0.9 + cf.LookVector * -0.5) * Vector3.new(1, 0, 1)
	local c = b + (cf.RightVector * -0.6 + cf.LookVector * 0.4) * Vector3.new(1, 0, 1)
	liston("Correa", a, b, 0.3, 0.05, COLOR.Cuero, Enum.Material.Fabric, m)
	liston("Correa", b, c, 0.3, 0.05, COLOR.Cuero, Enum.Material.Fabric, m)
	adorno("Hebilla", Vector3.new(0.3, 0.06, 0.24), CFrame.new(b) * CFrame.Angles(0, giro + 0.5, 0), COLOR.Hierro, Enum.Material.Metal, m)
end

-- El granero: establos contra la pared este y, en el del medio, el boquete por el que algo se llevó a las vacas
-- (aro de tablas rotas, tierra removida, hondo y oscuro, con tapa para no caerse); arañazos y sangre seca arrastrada
-- desde la puerta hasta él, la cuerda de la vaca que se mete dentro y su cencerro. Paja, el banco y lo de siempre.
local HUECO_GRANERO = { 233.3, 236.5, 79.3, 82.5 } -- x1, x2, z1, z2

local function dentroGranero(m: Model)
	local e = GRANERO
	local x1, x2, z1, z2 = PuebloPlano.dentro(e) -- 218.5, 237.5, 68.5, 91.5
	local techo = 1 + e.alto
	PuebloInteriores.forrar(ctx, e, m, { { y1 = 1, y2 = techo - 0.02, variante = "ParedCobertizo" } }, "SueloCobertizo", "TablasDesvan")
	local azar = Random.new(3112)
	local h = HUECO_GRANERO
	agujero(h[1], h[2], h[3], h[4], F, -1.5, { m:FindFirstChild("Piso") :: BasePart, m:FindFirstChild("Suelo") :: BasePart }, m)
	tablasRotas(h[1], h[2], h[3], h[4], F, azar, m)
	tierraRemovida(h[1], h[2], h[3], h[4], F, azar, m)

	-- Establos: tres, separados por dos tabiques; el del boquete, con un tabique roto.
	tabique(77.5, false, m)
	tabique(84.5, true, m)
	-- Paja: las balas de siempre (una llave puede salir encima de la del sur), con sus cuerdas, y paja suelta.
	for _, b in { { Vector3.new(4, 3, 6), CFrame.new(232, 2.5, 88) }, { Vector3.new(4, 3, 6), CFrame.new(235, 2.5, 74) },
		{ Vector3.new(4, 3, 4), CFrame.new(235, 5.5, 74) } } do
		bloque("Paja", b[1], b[2], COLOR.Paja, Enum.Material.Fabric, m)
		for _, dz in { -0.3, 0.3 } do
			adorno("Atadura", Vector3.new(b[1].X + 0.04, b[1].Y + 0.04, 0.08), b[2] * CFrame.new(0, 0, dz * b[1].Z), COLOR.Cuerda:Lerp(Color3.new(), 0.3),
				Enum.Material.Fabric, m)
		end
	end
	for _ = 1, 9 do
		local x, z = azar:NextNumber(x1 + 1, x2 - 1), azar:NextNumber(z1 + 1, z2 - 1)
		if x < h[1] - 0.8 or x > h[2] + 0.8 or z < h[3] - 0.8 or z > h[4] + 0.8 then
			adorno("PajaSuelta", Vector3.new(azar:NextNumber(1.2, 2.4), 0.04, azar:NextNumber(0.8, 1.6)), CFrame.new(x, F + 0.02, z)
				* CFrame.Angles(0, azar:NextNumber(0, math.pi), 0), COLOR.Paja:Lerp(COLOR.Tierra, azar:NextNumber(0, 0.4)), Enum.Material.Fabric, m)
		end
	end
	-- El banco de la pared sur (tablero a 4,5: una botella y una llave encima).
	bloque("Banco", Vector3.new(6, 0.3, 2), CFrame.new(226, 4.35, 90.5), COLOR.Madera, Enum.Material.WoodPlanks, m)
	for _, p in { { 223.4, 89.8 }, { 228.6, 89.8 }, { 223.4, 91.2 }, { 228.6, 91.2 } } do
		bloque("Pata", Vector3.new(0.35, 4.2 - F, 0.35), CFrame.new(p[1], (F + 4.2) / 2, p[2]), COLOR.MaderaOscura, Enum.Material.Wood, m)
	end
	adorno("Balda", Vector3.new(5.6, 0.15, 1.7), CFrame.new(226, 1.9, 90.5), COLOR.MaderaOscura, Enum.Material.WoodPlanks, m)
	objeto("Botella", Vector3.new(228, 4.9, 90.5))
	objeto("Chatarra", Vector3.new(222, 1.2, 72))
	objeto("Chatarra", Vector3.new(224, 1.2, 86))
	pesado("Bidon", CFrame.new(220, 2.2, 89))
	llave("Granja", Vector3.new(232, 4.2, 88))
	llave("Granja", Vector3.new(224.5, 4.7, 90.5))

	Mapa.conPadre(m, function()
		-- La sangre seca arrastrada desde la puerta hasta el borde del boquete, y gotas y salpicaduras junto a él.
		manchaEn(Vector3.new(225.5, F + 0.02, 80.4), Vector3.yAxis, Vector3.new(1, 0, 0.05).Unit, 2, 4.4, SANGRE.Arrastre, m)
		manchaEn(Vector3.new(230.95, F + 0.02, 80.75), Vector3.yAxis, Vector3.new(1, 0, 0.08).Unit, 2.2, 4.5, SANGRE.Arrastre, m)
		Mapa.mancha(Vector3.new(232.5, F + 0.03, 83.1), Vector3.yAxis, 1.4, SANGRE.Gotas, SECA, 0.4)
		Mapa.mancha(Vector3.new(236.3, F + 0.7, 84.36), -Vector3.zAxis, 1.4, SANGRE.Salpicadura, SECA, 0.3, 0.7)
		Mapa.mancha(Vector3.new(x2 - 0.13, F + 2.2, 80.2), -Vector3.xAxis, 1.8, SANGRE.Salpicadura, SECA, 1.1)
		-- Arañazos: en las tablas de los dos tabiques del establo y en el suelo, hacia el boquete.
		zarpazo(enCara(Vector3.new(235.2, F + 2.8, 77.64), Vector3.zAxis, Vector3.yAxis), 4, 1.1, 0.25, COLOR.Astilla, m)
		zarpazo(enCara(Vector3.new(234.6, F + 0.7, 77.64), Vector3.zAxis, Vector3.yAxis), 3, 1.1, -0.25, COLOR.Astilla, m)
		zarpazo(enCara(Vector3.new(236.4, F + 3.85, 84.36), -Vector3.zAxis, Vector3.yAxis), 4, 1, -0.25, COLOR.Astilla, m)
		zarpazo(enCara(Vector3.new(231.9, F + 0.012, 80.2), Vector3.yAxis, Vector3.zAxis), 4, 1.6, 0.05, Color3.fromRGB(28, 22, 18), m)
		zarpazo(enCara(Vector3.new(232.3, F + 0.012, 82.0), Vector3.yAxis, Vector3.zAxis), 3, 1.3, -0.2, Color3.fromRGB(28, 22, 18), m)
		-- La cuerda de la vaca: de la argolla de la pared al suelo y, por el borde, dentro del boquete.
		local argolla = adorno("Argolla", Vector3.new(0.08, 0.5, 0.5), CFrame.new(x2 - 0.15, F + 3.4, 80.9), COLOR.Hierro, Enum.Material.Metal, m)
		argolla.Shape = Enum.PartType.Cylinder
		local p1, p2 = Vector3.new(237.15, F + 3.15, 80.95), Vector3.new(236.75, F + 0.1, 81.3)
		local p3, p4 = Vector3.new(236.3, F + 0.06, 81.2), Vector3.new(235.4, -0.9, 80.9)
		liston("Cuerda", p1, p2, 0.13, 0.13, COLOR.Cuerda, Enum.Material.Fabric, m)
		liston("Cuerda", p2, p3, 0.13, 0.13, COLOR.Cuerda, Enum.Material.Fabric, m)
		liston("Cuerda", p3, p4, 0.13, 0.13, COLOR.Cuerda, Enum.Material.Fabric, m)
		cencerro(Vector3.new(233.7, F, 83.75), 0.5, m)
		-- Telarañas y humedad.
		telarana(x1 + 0.4, techo, z1 + 0.4, Vector3.new(1, 0, 1), 0.6)
		telarana(x1 + 0.4, techo, z2 - 0.4, Vector3.new(1, 0, -1), 0.6)
		Mapa.mancha(Vector3.new(x1 + 0.13, 12, 86), Vector3.xAxis, 4, Mapa.SANGRE[1], Color3.fromRGB(46, 36, 24), 0.6)

		-- El armario de los aperos (escondite), contra la pared norte entre las dos ventanas (lejos de la puerta, la
		-- paja, los establos y el banco): algo arañó el costado queriendo abrirlo y quien estaba dentro sangró (gotas
		-- secas delante); la horca, apoyada en la pared a su derecha, con la punta oscura.
		local aperos = CFrame.lookAt(Vector3.new(228, F + 4, z1 + 1.55), Vector3.new(228, F + 4, z1 + 6))
		Mapa.armario(aperos.Position, aperos.LookVector, "Aperos")
		Mapa.mancha((aperos * CFrame.new(2.33, 0.6, -0.4)).Position, aperos.RightVector, 1.6, Mapa.MARCAS.Aranazos,
			Color3.fromRGB(120, 76, 70), 0.15, 2.6)
		Mapa.mancha(Vector3.new(228.4, F + 0.03, 73.2), Vector3.yAxis, 1.7, SANGRE.Gotas, SECA, 1.3)
		Mapa.mancha(Vector3.new(227.1, F + 0.04, 74.6), Vector3.yAxis, 0.9, SANGRE.Gotas, SECA, 0.2)
		-- La horca (no choca), de pie contra la pared, un poco inclinada hacia el armario y sin pasar por la ventana.
		local horca = CFrame.new(231.2, F + 2.6, z1 + 0.6) * CFrame.Angles(math.rad(-6), 0, math.rad(4))
		local madera = Color3.fromRGB(78, 64, 50)
		adorno("Horca", Vector3.new(0.18, 5.2, 0.18), horca, madera, Enum.Material.Wood, m)
		adorno("Horca", Vector3.new(0.9, 0.12, 0.12), horca * CFrame.new(0, 2.65, 0), COLOR.Hierro, Enum.Material.CorrodedMetal, m)
		for _, x in { -0.4, 0, 0.4 } do
			adorno("Horca", Vector3.new(0.08, 1.1, 0.08), horca * CFrame.new(x, 3.25, 0), COLOR.Hierro, Enum.Material.CorrodedMetal, m)
		end
		-- La sangre seca de la punta del medio.
		adorno("Horca", Vector3.new(0.1, 0.5, 0.1), horca * CFrame.new(0, 3.55, 0), Color3.fromRGB(70, 14, 12), Enum.Material.SmoothPlastic, m)
	end)
end

-- Lo de fuera del granero: aspas blancas desvaídas en las hojas de la puerta, el portón del pajar en el hastial con la
-- viga de la polea y su cuerda deshilachada, y el cupulín de ventilación con la veleta en la cumbrera.
local function granero(m: Model)
	local blanco = COLOR.Pintura
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") and p.Name == "Puerta" then
			local s = p.Size
			local a = math.atan2(s.Y, s.X)
			for _, cara in { -0.2, 0.18 } do
				for _, signo in { -1, 1 } do
					adorno("Aspa", Vector3.new(math.sqrt(s.X ^ 2 + s.Y ^ 2) - 0.4, 0.3, 0.1), p.CFrame * CFrame.new(0, 0, cara) * CFrame.Angles(0, 0, signo * a),
						blanco, Enum.Material.WoodPlanks, m)
				end
				for _, y in { -1, 1 } do
					adorno("Marco", Vector3.new(s.X, 0.32, 0.1), p.CFrame * CFrame.new(0, y * (s.Y / 2 - 0.16), cara), blanco, Enum.Material.WoodPlanks, m)
				end
			end
		end
	end
	-- El pajar: en el hastial oeste (su cara, a x = 217,5), encima de la puerta.
	local xf = 217.5
	local pajar = CFrame.lookAt(Vector3.new(xf - 0.1, 19.6, 80), Vector3.new(xf - 1, 19.6, 80))
	adorno("Pajar", Vector3.new(3.4, 4.2, 0.2), pajar, Color3.fromRGB(96, 46, 38), Enum.Material.WoodPlanks, m)
	adorno("Rendija", Vector3.new(0.35, 4.0, 0.05), pajar * CFrame.new(1.55, 0, -0.11), COLOR.Hoyo, Enum.Material.SmoothPlastic, m) -- entreabierto
	for _, signo in { -1, 1 } do
		adorno("Aspa", Vector3.new(5, 0.28, 0.1), pajar * CFrame.new(0, 0, -0.14) * CFrame.Angles(0, 0, signo * math.atan2(4.2, 3.4)), blanco,
			Enum.Material.WoodPlanks, m)
	end
	for _, y in { -2.15, 2.15 } do
		adorno("Marco", Vector3.new(3.9, 0.3, 0.3), pajar * CFrame.new(0, y, -0.1), blanco, Enum.Material.WoodPlanks, m)
	end
	local viga = adorno("Viga", Vector3.new(3.8, 0.6, 0.6), CFrame.new(xf - 1.6, 24.6, 80), COLOR.MaderaOscura, Enum.Material.Wood, m)
	viga.CastShadow = true
	local polea = adorno("Polea", Vector3.new(0.3, 0.8, 0.8), CFrame.new(xf - 3.2, 24.0, 80), COLOR.Hierro, Enum.Material.Metal, m)
	polea.Shape = Enum.PartType.Cylinder -- el eje, a lo largo de x: la cuerda baja por los dos lados
	adorno("Cuerda", Vector3.new(0.13, 8.2, 0.13), CFrame.new(xf - 3.2, 19.5, 80.4), COLOR.Cuerda, Enum.Material.Fabric, m)
	adorno("Cuerda", Vector3.new(0.13, 3.4, 0.13), CFrame.new(xf - 3.2, 22.3, 79.6), COLOR.Cuerda, Enum.Material.Fabric, m)
	for i = -1, 1 do
		adorno("Hilacha", Vector3.new(0.05, 0.6, 0.05), CFrame.new(xf - 3.2 + i * 0.06, 15.2, 80.4) * CFrame.Angles(0, 0, i * 0.35), COLOR.Cuerda,
			Enum.Material.Fabric, m)
	end
	-- Cupulín en medio de la cumbrera (a lo largo de x: sube 0,95 por stud desde las paredes, a y = 16).
	local cumbre = 16 + 0.95 * 12.5
	local base = CFrame.new(228, cumbre, 80)
	adorno("Cupulin", Vector3.new(2.6, 3.5, 2.6), base * CFrame.new(0, 0.25, 0), Color3.fromRGB(96, 46, 38), Enum.Material.WoodPlanks, m)
	for _, giro in { 0, math.pi / 2, math.pi, -math.pi / 2 } do
		local cara = base * CFrame.Angles(0, giro, 0) * CFrame.new(0, 1.1, -1.31)
		adorno("Rejilla", Vector3.new(1.7, 1.3, 0.04), cara, COLOR.Hoyo, Enum.Material.SmoothPlastic, m)
		for k = -1, 1 do
			adorno("Lama", Vector3.new(1.7, 0.1, 0.25), cara * CFrame.new(0, k * 0.4, -0.06) * CFrame.Angles(math.rad(-35), 0, 0), blanco,
				Enum.Material.Wood, m)
		end
	end
	for i, t in { { 3.2, 0.3 }, { 2.3, 0.3 }, { 1.3, 0.3 } } do
		adorno("Tejadillo", Vector3.new(t[1], t[2], t[1]), base * CFrame.new(0, 1.85 + i * 0.3, 0), Color3.fromRGB(40, 39, 42), Enum.Material.Slate, m)
	end
	local veleta = base * CFrame.new(0, 2.9, 0)
	adorno("Veleta", Vector3.new(0.1, 2.2, 0.1), veleta * CFrame.new(0, 1.1, 0), COLOR.Hierro, Enum.Material.Metal, m)
	adorno("Veleta", Vector3.new(1, 0.06, 0.06), veleta * CFrame.new(0, 1.2, 0), COLOR.Hierro, Enum.Material.Metal, m)
	adorno("Veleta", Vector3.new(0.06, 0.06, 1), veleta * CFrame.new(0, 1.2, 0), COLOR.Hierro, Enum.Material.Metal, m)
	local flecha = veleta * CFrame.new(0, 1.85, 0) * CFrame.Angles(0, 0.6, 0) -- parada, torcida
	adorno("Veleta", Vector3.new(2, 0.08, 0.08), flecha, COLOR.Hierro, Enum.Material.Metal, m)
	adorno("Cola", Vector3.new(0.5, 0.45, 0.04), flecha * CFrame.new(-0.85, 0, 0), COLOR.Hierro, Enum.Material.Metal, m)
	adorno("Punta", Vector3.new(0.3, 0.25, 0.04), flecha * CFrame.new(1, 0, 0) * CFrame.Angles(0, 0, math.pi / 4), COLOR.Hierro, Enum.Material.Metal, m)
end

-- Granja (llave del sótano): la casa con porche, el granero rojo y el campo.
local function granja()
	cocinaGranja(fachada(CASA_GRANJA))
	local m = fachada(GRANERO)
	granero(m)
	dentroGranero(m)

	CollectionService:AddTag(bloque("Campo", Vector3.new(36, 0.2, 26), CFrame.new(197, 0.1, 104), COLOR.Tierra, Enum.Material.Ground), "EnMapa")
	for i = 0, 7 do
		bloque("Surco", Vector3.new(34, 0.4, 0.8), CFrame.new(197, 0.3, 94 + i * 3), COLOR.Tierra, Enum.Material.Ground)
	end
	bloque("Caja", Vector3.new(2.5, 2.5, 2.5), CFrame.new(175, 1.25, 96), COLOR.Madera, Enum.Material.Wood)
	llave("Granja", Vector3.new(175, 2.7, 96))
	bloque("Abrevadero", Vector3.new(6, 1.5, 2), CFrame.new(214, 0.75, 62), COLOR.Madera, Enum.Material.Wood)
end

---------------------------------------------------------------------------------------------------------------------
-- Aserradero viejo (llave del garaje). La foto de Harlan (pista 7): "Lo encontramos al cavar. 1952."

-- La oficina: el escritorio contra la pared oeste (la pista 7, clavada en esa pared a x = -255,47: su cara de dentro
-- se queda a -255,5, sin forrar), la estantería de metal con cajas al norte y la silla apartada.
local function oficina(m: Model)
	local x1, z1 = -255.5, -77.5
	-- Escritorio de tablas (tablero a 4: una llave y una botella encima) con cajonera.
	bloque("Escritorio", Vector3.new(2.9, 0.15, 2.2), CFrame.new(-254, 3.925, -72), COLOR.MaderaOscura, Enum.Material.Wood, m)
	bloque("Cajonera", Vector3.new(0.85, 2.85, 2.0), CFrame.new(-253.0, 2.425, -72), COLOR.MaderaOscura, Enum.Material.Wood, m)
	for i = 0, 2 do
		local y = 1.55 + i * 0.92
		adorno("Cajon", Vector3.new(0.05, 0.78, 1.8), CFrame.new(-252.55, y, -72), COLOR.Madera, Enum.Material.Wood, m)
		adorno("Tirador", Vector3.new(0.08, 0.1, 0.5), CFrame.new(-252.5, y + 0.1, -72), COLOR.Hierro, Enum.Material.Metal, m)
	end
	for _, z in { -72.95, -71.05 } do
		bloque("Pata", Vector3.new(0.25, 2.85, 0.25), CFrame.new(-255.25, 2.425, z), COLOR.MaderaOscura, Enum.Material.Wood, m)
	end
	adorno("Papeles", Vector3.new(0.85, 0.03, 1.1), CFrame.new(-253.8, 4.015, -71.55) * CFrame.Angles(0, 0.25, 0), COLOR.Papel, Enum.Material.Fabric, m)
	llave("Aserradero", Vector3.new(-254.8, 4.2, -72))
	objeto("Botella", Vector3.new(-253, 4.2, -72.2))
	Mapa.conPadre(m, function()
		Mapa.mueble("SillaCocinaPH", CFrame.lookAt(Vector3.new(-251.2, 1, -72.6), Vector3.new(-255, 1, -71.4)), true)
		-- Estantería de metal contra la pared norte, con cajas de cartón en las baldas y otra en el suelo.
		local estante = Mapa.contraPared("EstanteriaMetalPH", -253.25, 1, z1, Vector3.zAxis)
		if estante then
			local z = z1 + 1.06
			for _, b in { { -254.1, 0.5, 0.1 }, { -252.4, 4.6, -0.15 }, { -253.6, 6.6, 0.05 } } do
				Mapa.mueble("CajaCartonPH", CFrame.new(b[1], 1 + b[2], z) * CFrame.Angles(0, math.pi / 2 + b[3], 0), true)
			end
		end
		Mapa.mueble("CajaCartonPH", CFrame.new(-254.1, 1, -74.25) * CFrame.Angles(0, math.pi / 2 - 0.08, 0))
		-- Humedad y una telaraña.
		Mapa.mancha(Vector3.new(-254.4, 8.6, -70.53), -Vector3.zAxis, 1.8, Mapa.SANGRE[1], Color3.fromRGB(46, 36, 24), 0.4)
		telarana(x1 + 0.9, 10, -70.9, Vector3.new(1, 0, -1), 0.35)
	end)
end

-- Fuera, entre la oficina y la nave: el hoyo que se quedó a medio cavar, tapado con tablones (falta uno y se ve el
-- negro), la tierra sacada con la pala clavada, el cubo y el candil.
local HUECO_ASERRADERO = { -243.5, -239.5, -75.2, -71.8 } -- x1, x2, z1, z2

local function hoyo(m: Model)
	local h = HUECO_ASERRADERO
	local azar = Random.new(3113)
	agujero(h[1], h[2], h[3], h[4], 0.15, -1.5, {}, m)
	-- Tablones de lado a lado (de norte a sur), apoyados en el borde; el tercero, metido de punta en el hoyo.
	for i, x in { -243.05, -242.02, -240.99, -239.96 } do
		if i == 3 then
			liston("Tablon", Vector3.new(x - 0.1, 0.1, -75.6), Vector3.new(x + 0.25, -0.95, -72.6), 0.85, 0.15, COLOR.Tabla, Enum.Material.WoodPlanks, m)
		else
			adorno("Tablon", Vector3.new(0.85, 0.15, 4.2), CFrame.new(x, 0.075, -73.5) * CFrame.Angles(0, azar:NextNumber(-0.04, 0.04), 0),
				COLOR.Tabla:Lerp(COLOR.Madera, azar:NextNumber()), Enum.Material.WoodPlanks, m)
		end
	end
	adorno("Tablon", Vector3.new(4.6, 0.15, 0.7), CFrame.new(-241.6, 0.22, -72.5) * CFrame.Angles(0, 0.12, 0), COLOR.Tabla, Enum.Material.WoodPlanks, m)
	adorno("Piedra", Vector3.new(0.7, 0.7, 0.7), CFrame.new(-242.4, 0.5, -74.3), COLOR.Piedra, Enum.Material.Slate, m).Shape = Enum.PartType.Ball
	-- La tierra que sacaron, al este, con la pala clavada.
	monton("Tierra", Vector3.new(2.8, 1.3, 2.4), CFrame.new(-237.9, 0.1, -73.6) * CFrame.Angles(0, 0.3, 0), COLOR.TierraRemovida, Enum.Material.Ground, m)
	monton("Tierra", Vector3.new(2.0, 0.9, 1.8), CFrame.new(-237.4, 0.05, -71.3) * CFrame.Angles(0, -0.4, 0), COLOR.Tierra, Enum.Material.Ground, m)
	tierraRemovida(h[1], h[2], h[3], h[4], 0, azar, m)
	Mapa.conPadre(m, function()
		Mapa.mueble("PalaPH", CFrame.new(-237.7, 0.35, -73.9) * CFrame.Angles(0.28, 0.5, -0.12), true)
		Mapa.mueble("CuboPH", CFrame.new(-237.2, 0.6, -76.6) * CFrame.Angles(0, 0.4, math.rad(84)), true) -- volcado
		Mapa.mueble("LamparaAceitePH", CFrame.new(-239.9, 0, -70.9), true)
	end)
end

-- Aserradero viejo (llave del garaje): nave abierta con la sierra y su serrín, tablones, barriles, troncos, la oficina
-- y el hoyo.
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

	-- Lo de la nave (en su propio modelo): serrín bajo la sierra y por el suelo, y dos barriles en el rincón del suroeste.
	local nave = Instance.new("Model")
	nave.Name = "Nave"
	nave.Parent = carpeta
	local azar = Random.new(3111)
	monton("Serrin", Vector3.new(2.6, 0.55, 1.8), CFrame.new(cx - 2.4, 1, cz + 2.7) * CFrame.Angles(0, 0.2, 0), COLOR.Serrin, Enum.Material.Sand, nave)
	monton("Serrin", Vector3.new(2, 0.45, 1.4), CFrame.new(cx - 1.6, 1, cz - 2.6) * CFrame.Angles(0, -0.3, 0), COLOR.Serrin, Enum.Material.Sand, nave)
	adorno("Serrin", Vector3.new(2.4, 0.03, 1.6), CFrame.new(cx - 2.3, 4.015, cz), COLOR.Serrin, Enum.Material.Sand, nave)
	for _ = 1, 7 do
		local x, z = cx + azar:NextNumber(-7, 5), cz + azar:NextNumber(-4.5, 5.5)
		if math.abs(z - cz) > 1.6 then -- no debajo de la mesa de la sierra
			adorno("Serrin", Vector3.new(azar:NextNumber(1, 2.4), 0.03, azar:NextNumber(0.8, 1.8)), CFrame.new(x, 1.015, z)
				* CFrame.Angles(0, azar:NextNumber(0, math.pi), 0), COLOR.Serrin:Lerp(COLOR.Tierra, azar:NextNumber(0, 0.35)), Enum.Material.Sand, nave)
		end
	end
	Mapa.conPadre(nave, function()
		Mapa.mueble("BarrilPH", CFrame.new(cx - 12.6, 1, cz - 6.4))
		Mapa.mueble("BarrilPH", CFrame.new(cx - 9.5, 1, cz - 7.2) * CFrame.Angles(0, 0.8, 0))
	end)

	local m = fachada(OFICINA)
	oficina(m)
	hoyo(m)
end

---------------------------------------------------------------------------------------------------------------------
-- Torre del guardabosques. El diario del guarda (pista 8) está arriba; abajo, su caseta.

-- El mapa del guarda clavado en la pared (`cf`: -Z hacia la sala): bosque, la carretera y chinchetas rojas unidas con
-- hilo; todos los hilos van a parar a la de la casa (pista 6: "todos llevan a la casa").
local function mapaGuarda(cf: CFrame, m: Model)
	adorno("Mapa", Vector3.new(3.4, 2.4, 0.03), cf, COLOR.Papel, Enum.Material.SmoothPlastic, m)
	local function en(u: number, w: number, d: number): CFrame
		return cf * CFrame.new(u, w, -d)
	end
	for _, b in { { -1.0, 0.6, 1.1, 0.7 }, { 0.9, 0.5, 1.2, 0.9 }, { -0.6, -0.6, 1.4, 0.6 }, { 1.1, -0.7, 0.8, 0.5 } } do
		adorno("Bosque", Vector3.new(b[3], b[4], 0.01), en(b[1], b[2], 0.02), Color3.fromRGB(96, 104, 80), Enum.Material.SmoothPlastic, m)
	end
	adorno("Carretera", Vector3.new(0.06, 2.3, 0.01), en(0.05, 0, 0.03) * CFrame.Angles(0, 0, 0.12), Color3.fromRGB(110, 86, 62),
		Enum.Material.SmoothPlastic, m)
	local casa = Vector3.new(0.1, 0.1, 0)
	local rojo = Color3.fromRGB(116, 22, 20)
	for _, p in { { -1.3, 0.85 }, { 1.35, 0.75 }, { -1.2, -0.8 }, { 1.2, -0.85 }, { 0.15, 1.05 } } do
		local a = Vector3.new(p[1], p[2], 0)
		local d = casa - a
		adorno("Hilo", Vector3.new(d.Magnitude, 0.025, 0.01), en((a.X + casa.X) / 2, (a.Y + casa.Y) / 2, 0.05) * CFrame.Angles(0, 0, math.atan2(d.Y, d.X)),
			rojo, Enum.Material.SmoothPlastic, m)
		adorno("Chincheta", Vector3.new(0.13, 0.13, 0.13), en(a.X, a.Y, 0.08), rojo, Enum.Material.SmoothPlastic, m).Shape = Enum.PartType.Ball
	end
	adorno("Chincheta", Vector3.new(0.17, 0.17, 0.17), en(casa.X, casa.Y, 0.09), Color3.fromRGB(20, 18, 18), Enum.Material.SmoothPlastic, m).Shape =
		Enum.PartType.Ball
	for i = 0, 7 do -- un círculo a lápiz alrededor de la casa
		local a = i * math.pi / 4
		adorno("Circulo", Vector3.new(0.2, 0.03, 0.01), en(casa.X + math.cos(a) * 0.26, casa.Y + math.sin(a) * 0.26, 0.04) * CFrame.Angles(0, 0, a + math.pi / 2),
			rojo, Enum.Material.SmoothPlastic, m)
	end
end

-- La caseta del guarda al pie de la colina: el catre bajo la ventana, la mesa con el mapa encima (una llave puede
-- salir en la mesa), la escalera de mano junto a la puerta y el candil apagado.
local function caseta()
	local m = fachada(CASETA)
	local x1, x2, z1, z2 = PuebloPlano.dentro(CASETA) -- 86.5, 93.5, 234.5, 241.5
	-- Mesa de tablas contra la pared sur (tablero a 4).
	bloque("Mesa", Vector3.new(2.9, 0.15, 1.9), CFrame.new(92, 3.925, 240.5), COLOR.MaderaOscura, Enum.Material.Wood, m)
	for _, p in { { 90.8, 239.8 }, { 93.2, 239.8 }, { 90.8, 241.2 }, { 93.2, 241.2 } } do
		bloque("Pata", Vector3.new(0.22, 2.85, 0.22), CFrame.new(p[1], 2.425, p[2]), COLOR.MaderaOscura, Enum.Material.Wood, m)
	end
	llave("Torre", Vector3.new(92, 4.2, 241))
	objeto("Chatarra", Vector3.new(88, 1.2, 236))
	-- El catre de lona contra la pared oeste, con la manta y la almohada (choca una caja).
	local cx, cz = x1 + 1.25, 239.05
	choque(Vector3.new(2.4, 1.3, 4.7), CFrame.new(cx, 1.65, cz), m)
	for _, s in { -1, 1 } do
		adorno("Larguero", Vector3.new(0.14, 0.14, 4.7), CFrame.new(cx + s * 1.1, 2.15, cz), COLOR.MaderaOscura, Enum.Material.Wood, m)
		for _, dz in { -2.1, 2.1 } do
			adorno("Tijera", Vector3.new(0.1, 1.5, 0.1), CFrame.new(cx + s * 0.55, 1.55, cz + dz) * CFrame.Angles(0, 0, s * 0.85), COLOR.MaderaOscura,
				Enum.Material.Wood, m)
		end
	end
	adorno("Lona", Vector3.new(2.1, 0.06, 4.6), CFrame.new(cx, 2.2, cz), COLOR.Lona, Enum.Material.Fabric, m)
	adorno("Manta", Vector3.new(1.9, 0.25, 1.4), CFrame.new(cx + 0.05, 2.36, cz + 1.2) * CFrame.Angles(0, 0.15, 0), Color3.fromRGB(70, 62, 50),
		Enum.Material.Fabric, m)
	adorno("Almohada", Vector3.new(1.2, 0.3, 0.8), CFrame.new(cx, 2.38, cz - 1.8) * CFrame.Angles(0, -0.1, math.rad(4)), Color3.fromRGB(120, 112, 96),
		Enum.Material.Fabric, m)
	-- El mapa con chinchetas encima de la mesa, mirando a la sala.
	mapaGuarda(CFrame.lookAt(Vector3.new(91.7, 6.7, z2 - 0.02), Vector3.new(91.7, 6.7, z2 - 1)) * CFrame.Angles(0, 0, 0.03), m)
	Mapa.conPadre(m, function()
		Mapa.contraPared("EscaleraManoPH", x2, 1, 236.9, -Vector3.xAxis, true)
		Mapa.mueble("LamparaAceitePH", CFrame.new(90.95, 4, 240.2), true)
		Mapa.mancha(Vector3.new(cx + 1.6, 1.02, cz - 0.4), Vector3.yAxis, 1.1, SANGRE.Gotas, SECA, 1.9)
		telarana(x2 - 0.4, 10, z1 + 0.4, Vector3.new(-1, 0, 1), 0.35)
	end)
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

	caseta()
end

-- El vendedor como personaje de Roblox (pedido por el usuario): R15 de serie con la ropa pintada en el cuerpo
-- (chaqueta parda, pantalón oscuro, manos y cara de viejo), sombrero de copa y la animación de estar quieto de Roblox.
-- Solo funciona en el servidor de una partida; si falla (en modo Edit), devuelve nil y sale el de bloques.
local IDLE = "rbxassetid://507766388" -- respirar de pie, de las animaciones de serie de Roblox (R15)
local function personaje(cf: CFrame, piel: Color3, ropa: Color3, oscuro: Color3): Model?
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor, desc.TorsoColor = piel, ropa
	desc.LeftArmColor, desc.RightArmColor = ropa, ropa
	desc.LeftLegColor, desc.RightLegColor = oscuro, oscuro
	desc.HeightScale = 1.08 -- que asome bien por encima del mostrador
	local ok, modelo = pcall(function()
		return game:GetService("Players"):CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not modelo then
		return nil
	end
	local humano = modelo:FindFirstChildOfClass("Humanoid") :: Humanoid
	local raiz = modelo:FindFirstChild("HumanoidRootPart") :: BasePart
	local cabeza = modelo:FindFirstChild("Head") :: BasePart
	if not (humano and raiz and cabeza) then
		modelo:Destroy()
		return nil
	end
	local colores = modelo:FindFirstChildOfClass("BodyColors")
	if colores then
		colores:Destroy() -- si no, vuelve a pintar las manos del color de la chaqueta
	end
	for _, nombre in { "LeftHand", "RightHand" } do
		local mano = modelo:FindFirstChild(nombre) :: BasePart?
		if mano then
			mano.Color = piel
		end
	end
	humano.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humano.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humano.BreakJointsOnDeath = false
	raiz.Anchored = true
	-- PivotTo mueve todas las piezas ya (fuera del mapa las articulaciones aún no las colocan).
	modelo:PivotTo(cf * CFrame.new(0, humano.HipHeight + raiz.Size.Y / 2, 0))
	-- Sombrero de copa soldado a la cabeza y delantal de tendero soldado al pecho.
	local pecho = modelo:FindFirstChild("UpperTorso") :: BasePart? or cabeza
	for _, s in {
		{ "Ala", Vector3.new(1.9, 0.12, 1.9), cabeza.CFrame * CFrame.new(0, 0.55, 0), oscuro },
		{ "Copa", Vector3.new(1.2, 0.75, 1.2), cabeza.CFrame * CFrame.new(0, 0.95, 0), oscuro },
		{ "Delantal", Vector3.new(1.7, 1.6, 0.1), pecho.CFrame * CFrame.new(0, -0.25, -0.55), Color3.fromRGB(150, 140, 118) },
	} do
		local p = Instance.new("Part")
		p.Name = s[1]
		p.Size = s[2]
		p.Color = s[4]
		p.Material = if s[1] == "Delantal" then Enum.Material.Fabric else Enum.Material.SmoothPlastic -- el fieltro negro brillaba
		p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
		p.CFrame = s[3]
		local soldadura = Instance.new("WeldConstraint")
		soldadura.Part0, soldadura.Part1 = if s[1] == "Delantal" then pecho else cabeza, p
		soldadura.Parent = p
		p.Parent = modelo
	end
	return modelo
end

-- La animación de estar quieto (ya colgado en el mapa: fuera de él no carga).
local function quieto(modelo: Model)
	local humano = modelo:FindFirstChildOfClass("Humanoid") :: Humanoid
	local animador = humano:FindFirstChildOfClass("Animator") or Instance.new("Animator")
	animador.Parent = humano
	local anim = Instance.new("Animation")
	anim.AnimationId = IDLE
	local ok, pista = pcall(function()
		return animador:LoadAnimation(anim)
	end)
	if ok and pista then
		pista.Looped = true
		pista:Play()
	end
end

-- El vendedor detrás del mostrador (Vendedor le pone el prompt en su Mando).
local function vendedor(pie: Vector3, mira: Vector3)
	local cf = CFrame.lookAt(pie, pie + mira)
	local piel, ropa, oscuro = Color3.fromRGB(150, 128, 112), Color3.fromRGB(72, 64, 54), Color3.fromRGB(40, 38, 36)
	local modelo = personaje(cf, piel, ropa, oscuro)
	if modelo then
		modelo.Name = "Vendedor"
		modelo.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		local mando = bloque("Mando", Vector3.new(1, 1, 1), cf * CFrame.new(0, 4, -3), nil, nil, modelo)
		mando.Transparency = 1
		mando.CanCollide = false
		mando.CanQuery = false
		mando.CanTouch = false
		CollectionService:AddTag(modelo, "Vendedor")
		modelo.Parent = carpeta
		task.defer(quieto, modelo) -- Lugares cuelga el pueblo del mapa al final
		return
	end
	modelo = Instance.new("Model")
	modelo.Name = "Vendedor"
	modelo.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
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

-- Pueblo abandonado al final de la carretera (11.5): el plano en PuebloPlano; el cascarón de cada edificio en
-- PuebloFachadas, lo de dentro de los que se entra en PuebloInteriores (con el vendedor y las llaves de la cripta y la
-- caseta) y la calle y el cementerio en PuebloCalle. El orden importa: así salen los sitios de la llave del cementerio.
local function pueblo()
	local modelo = Instance.new("Folder")
	modelo.Name = "Pueblo"
	modelo.Parent = carpeta
	local ctx = {
		carpeta = modelo,
		COLOR = COLOR,
		Mapa = Mapa,
		Plano = PuebloPlano,
		bloque = function(nombre: string, tamano: Vector3, cf: CFrame, color: Color3?, material: Enum.Material?, padre: Instance?): Part
			return bloque(nombre, tamano, cf, color, material, padre or modelo)
		end,
		llave = llave,
		objeto = objeto,
		pesado = pesado,
		vendedor = function(pie: Vector3, mira: Vector3)
			vendedor(pie, mira)
			local v = carpeta:FindFirstChild("Vendedor")
			if v then
				v.Parent = modelo
			end
		end,
	}
	PuebloFachadas.construir(ctx)
	PuebloInteriores.construir(ctx)
	PuebloCalle.construir(ctx)
end

function Lugares.construir(mapa: Folder, modulo)
	Mapa = modulo
	raiz = mapa
	carpeta = Instance.new("Folder")
	carpeta.Name = "Lugares"
	ctx = { carpeta = carpeta, Mapa = Mapa, Plano = PuebloPlano, bloque = bloque }
	granja()
	aserradero()
	torre()
	LugarCazador.construir(ctx, { raiz = raiz, COLOR = COLOR, SANGRE = SANGRE, SECA = SECA, adorno = adorno, choque = choque, monton = monton,
		liston = liston, enCara = enCara, zarpazo = zarpazo, telarana = telarana, agujero = agujero, tierraRemovida = tierraRemovida,
		objeto = objeto })
	pueblo()
	carpeta.Parent = mapa
end

return Lugares
