-- Genera el mapa por código con bloques grises (el arte llega al final): suelo, bosque de troncos, camino y la casa.
-- La casa (x -39..39, z -33..33, más la torre, el mirador, el lavadero y el garaje): dos plantas (ver construirCasa).
-- Salas con llave (Llaves): sótano, garaje, desván y habitación del rico. La granja, el aserradero, la torre y el
-- pueblo, en Lugares.
-- Lo que se toca lleva una etiqueta de CollectionService y su estado en atributos (lo maneja Casa o Muerte):
--   "Ventana": cristal y persiana. "Puerta": hoja que gira en la bisagra. "Escondite": armarios y camas.
-- Medidas en studs: suelo de abajo arriba en y = 1, el de arriba en y = 14; paredes de 12 de alto.
-- Partido en módulos (16.18): las medidas en MapaMedidas, lo de dentro de cada sala en MapaSalas, lo que no son
-- salas (cobertizo, garaje, coche, sótano, desván, final) en MapaAnexos y el bosque en MapaBosque. Aquí quedan las
-- ayudas (bloque, tienda, muro…), la casa (construirCasa), la API que usan los demás y `start`, que lo llama todo.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Piezas = require(ReplicatedStorage.Shared.Piezas)
local Separar = require(ServerScriptService:WaitForChild("Comun").Separar)
local Bichos3D = require(script.Parent.Bichos3D)
local Fachada = require(script.Parent.Fachada)
local Lugares = require(script.Parent.Lugares)
local MapaAnexos = require(script.Parent.MapaAnexos)
local MapaBosque = require(script.Parent.MapaBosque)
local MapaMedidas = require(script.Parent.MapaMedidas)
local MapaSalas = require(script.Parent.MapaSalas)

-- Muebles del Creator Store y de Poly Haven: una carpeta por archivo de src/muebles (Muebles.rbxm, lo de antes, y un
-- <Sala>.rbxm por sala, para hacer salas en paralelo: plan-paralelo.md). Tabla nombre -> molde mirando solo los hijos
-- de cada carpeta: dentro de cada modelo hay MeshParts con su mismo nombre.
local MUEBLES: { [string]: Model } = {}
do
	local carpeta = game:GetService("ServerStorage"):FindFirstChild("Muebles")
	for _, sala in (if carpeta then carpeta:GetChildren() else {}) do
		for _, molde in sala:GetChildren() do
			local otro = MUEBLES[molde.Name]
			-- En Studio a veces sale un mueble repetido en la misma carpeta (tres Mecedora): solo se avisa entre salas.
			if otro and otro.Parent ~= sala then
				warn(`[Mapa] Mueble repetido: {molde.Name} en {otro.Parent.Name} y en {sala.Name}`)
			elseif not otro and molde:IsA("Model") then
				MUEBLES[molde.Name] = molde
			end
		end
	end
end
-- Materiales con texturas de Poly Haven para paredes, suelos y techos de cada sala (src/materiales).
local MATERIALES = game:GetService("MaterialService"):FindFirstChild("Materiales")

local Mapa = {}

-- Medidas de la casa (MapaMedidas, compartidas con MapaSalas, MapaAnexos y MapaBosque).
local ABAJO, ARRIBA, ALTO, BAJO_TECHO, TEJADO, COLOR = MapaMedidas.ABAJO, MapaMedidas.ARRIBA, MapaMedidas.ALTO,
	MapaMedidas.BAJO_TECHO, MapaMedidas.TEJADO, MapaMedidas.COLOR
local TORRE, DORMITORIO_GRANDE, NINOS = MapaMedidas.TORRE, MapaMedidas.DORMITORIO_GRANDE, MapaMedidas.NINOS
-- Puntos de cada sala por los que el Golpeador ronda cuando no ve a nadie.
Mapa.salas = {} :: { Vector3 }
-- Dónde empiezan los objetos sueltos (Mochila) y las cosas pesadas (Cargar).
Mapa.objetos = {} :: { { tipo: string, cf: CFrame } }
Mapa.pesados = {} :: { { tipo: string, cf: CFrame } }
-- El motor suelto delante de la casa: no está en `pesados`, lo pone Llegada al salir el coche destrozado (16.8).
Mapa.motorSuelto = CFrame.new(20, 1.1, -52)
-- Lámparas de la casa (las enciende Generador).
Mapa.lamparas = {} :: { BasePart }
-- Sitios donde puede salir cada llave: [zona de Config.Llaves] = { CFrame } (los pone Lugares; los elige Llaves).
Mapa.llaves = {} :: { [string]: { CFrame } }

local casa: Model

-- Nombre fijo de lo que se guarda (Partida): sale de dónde está, para que añadir cosas al mapa no lo cambie.
local function clave(letra: string, punto: Vector3): string
	return `{letra}{math.round(punto.X)}_{math.round(punto.Y)}_{math.round(punto.Z)}`
end

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
	p.Parent = padre or casa
	return p
end

-- Le pone a la pieza un MaterialVariant de MATERIALES (si no está, se queda con su material de siempre).
local function variante(p: BasePart, nombre: string)
	local v = MATERIALES and MATERIALES:FindFirstChild(nombre) :: MaterialVariant?
	if v then
		p.Material = v.BaseMaterial
		p.MaterialVariant = nombre
		p.Color = Color3.new(1, 1, 1) -- el color va en la textura
	end
end

-- Pieza invisible donde cuelga el ProximityPrompt de algo.
local function mando(cf: CFrame, padre: Instance): Part
	local p = bloque("Mando", Vector3.new(1, 1, 1), cf, nil, nil, padre)
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function lampara(posicion: Vector3)
	local p = bloque("Lampara", Vector3.new(1.2, 0.4, 1.2), CFrame.new(posicion), COLOR.Lampara, Enum.Material.SmoothPlastic)
	-- Con la lámpara de Blender (el techo está 0,3 más arriba), el bloque es la bombilla dentro de la pantalla:
	-- Generador le cambia el color al encenderla.
	local techo = posicion + Vector3.new(0, 0.3, 0)
	local partes = Piezas.poner(casa, "Lampara", CFrame.new(techo))
	for _, parte in partes do
		parte.CastShadow = false -- que la pantalla no tape la luz
	end
	if #partes > 0 then
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(0.45, 0.45, 0.45)
		p.Position = techo - Vector3.new(0, 0.62, 0)
	end
	local luz = Instance.new("PointLight")
	luz.Color = COLOR.Lampara
	luz.Brightness = 1.1
	luz.Range = 22
	luz.Shadows = true
	luz.Enabled = false -- las enciende el generador
	luz.Parent = p
	table.insert(Mapa.lamparas, p)
end

-- Adorno de madera que no choca ni tapa rayos (marcos, porche): solo se ve.
local function adorno(tamano: Vector3, cf: CFrame, material: Enum.Material?): Part
	local p = bloque("Adorno", tamano, cf, COLOR.Marco, material or Enum.Material.Wood)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

-- Marco de madera alrededor de un hueco de `ancho` x `alto` centrado en `cf` (Z = a través de la pared). Sobresale un
-- poco por las dos caras; `sinBajo` = sin travesaño abajo (puertas).
local function marco(cf: CFrame, ancho: number, alto: number, sinBajo: boolean?)
	local g, fondo = 0.35, 1.3
	for _, lado in { -1, 1 } do
		-- Un poco más hondos que los travesaños: si sus caras coincidieran en las esquinas, parpadearían.
		adorno(Vector3.new(g, alto + g * 2, fondo + 0.06), cf * CFrame.new(lado * (ancho / 2 + g / 2 - 0.05), 0, 0))
	end
	adorno(Vector3.new(ancho + g * 2, g, fondo), cf * CFrame.new(0, alto / 2 + g / 2 - 0.05, 0))
	if not sinBajo then
		adorno(Vector3.new(ancho + g * 2, g, fondo), cf * CFrame.new(0, -alto / 2 - g / 2 + 0.05, 0))
	end
end

-- Pone el mueble de Blender `nombre` (shared/Piezas) en `cf` y esconde los bloques que tapa, que siguen chocando.
-- Sin las mallas no hace nada: se ven los bloques.
local function mueble(nombre: string, cf: CFrame, tapa: { BasePart }?, padre: Instance?): { MeshPart }
	-- Suelto en la casa, cada mueble en su modelo: así se coge entero en el plugin VistaMapa (pedido por el usuario).
	if not padre then
		local modelo = Instance.new("Model")
		modelo.Name = nombre
		modelo.Parent = casa
		padre = modelo
	end
	local partes = Piezas.poner(padre :: Instance, nombre, cf)
	if #partes > 0 and tapa then
		for _, b in tapa do
			b.Transparency = 1
		end
	end
	return partes
end

-- Muebles con hueco debajo donde esconderse agachado (pedido por el usuario, 03-11-2026: "agacharte también debería
-- servir para esconderte, por ejemplo debajo de mesas… que sea útil agacharte es la finalidad"). En vez de la caja
-- maciza de `tienda` chocan el tablero (una losa de su cara de abajo hasta arriba, con la planta de la caja de siempre)
-- y las patas, así que se entra agachado (Config.Postura.Alto) por los lados libres; y en el hueco, entre las patas, una
-- pieza "Debajo" (etiqueta y atributo Mueble) marca dónde se está cubierto. Medidas de cada malla, sacadas en Blender,
-- en ejes del molde (pivote abajo en el centro, frente a -Z):
--   abajo = cara de abajo del tablero; cajas = { x1, x2, y1, y2, z1, z2 } que chocan (patas, caballetes, vigas);
--   hueco = { x1, x2, z1, z2 } de la zona Debajo, del suelo a `abajo`.
-- Solo los que dejan Config.Postura.Alto + 0,2 de alto y unos 2,2 × 2,2 libres. No valen el escritorio del rico (bajo
-- el cajón quedan 2,1), la mesa del revelado (faldones a 2,6 y balda abajo) ni la del té (tablero a 1,6).
type Hueco = { abajo: number, cajas: { { number } }, hueco: { number } }
local HUECOS: { [string]: Hueco } = {
	-- 2,84 bajo el marco del tablero; cuatro patas metidas 1 hacia dentro de las esquinas. El mantel cuelga y no choca.
	MesaComedorPH = {
		abajo = 2.84,
		cajas = {
			{ -5.22, -4.54, 0, 2.84, -1.82, -1.37 },
			{ -5.22, -4.54, 0, 2.84, 1.44, 1.92 },
			{ 4.54, 5.22, 0, 2.84, -1.82, -1.37 },
			{ 4.54, 5.22, 0, 2.84, 1.44, 1.92 },
		},
		hueco = { -4.54, 4.54, -1.37, 1.44 },
	},
	-- Mesa de caballetes: 3,29 bajo los travesaños. La viga baja del medio también choca, así que solo se entra en la
	-- mitad de delante (-Z; la de atrás da a la pared de la cocina).
	MesaCocinaPH = {
		abajo = 3.29,
		cajas = {
			{ -2.33, -2.11, 0, 3.29, -1.63, 1.61 },
			{ 2.11, 2.33, 0, 3.29, -1.63, 1.61 },
			{ -2.11, 2.11, 0.88, 1.49, -0.08, 0.09 },
		},
		hueco = { -2.11, 2.11, -1.63, -0.08 },
	},
}

-- Caja invisible que choca, en ejes del mueble (`cf`, su pivote): de (x1, y1, z1) a (x2, y2, z2). Como la de `tienda`,
-- no tapa la vista de los bichos.
local function choqueEn(cf: CFrame, x1: number, x2: number, y1: number, y2: number, z1: number, z2: number)
	local p = bloque("Choque", Vector3.new(x2 - x1, y2 - y1, z2 - z1), cf * CFrame.new((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2))
	p.Transparency = 1
	p.CanQuery = false
	p.CanTouch = false
end

-- Lo que choca de un mueble de HUECOS y su zona Debajo, colgada del modelo para que vaya con la casa (Persistent en
-- `porPartes`: el cliente la tiene siempre).
local function conHueco(nombre: string, modelo: Model, cf: CFrame, tam: Vector3, h: Hueco)
	if h.abajo < Config.Postura.Alto + 0.2 then
		warn(`[Mapa] {nombre}: debajo no se cabe agachado (Config.Postura.Alto)`)
	end
	choqueEn(cf, -tam.X * 0.45, tam.X * 0.45, h.abajo, tam.Y, -tam.Z * 0.45, tam.Z * 0.45)
	for _, c in h.cajas do
		choqueEn(cf, c[1], c[2], c[3], c[4], c[5], c[6])
	end
	local x1, x2, z1, z2 = h.hueco[1], h.hueco[2], h.hueco[3], h.hueco[4]
	local zona = bloque("Debajo", Vector3.new(x2 - x1, h.abajo, z2 - z1), cf * CFrame.new((x1 + x2) / 2, h.abajo / 2, (z1 + z2) / 2),
		nil, nil, modelo)
	zona.Transparency = 1
	zona.CanCollide = false
	zona.CanQuery = false
	zona.CanTouch = false
	zona.CastShadow = false
	zona:SetAttribute("Mueble", nombre)
	CollectionService:AddTag(zona, "Debajo")
end

-- Pone un mueble del Creator Store (ServerStorage.Muebles: limpios de scripts, escalados, con el frente hacia -Z y el
-- pivote abajo en el centro; su tamaño en el atributo Tam) en `cf`. Solo se ve: choca una caja invisible un poco más
-- pequeña, que no tapa la vista de los bichos (o, si tiene hueco debajo, su tablero y sus patas: HUECOS). Sin la
-- carpeta (lugar sin Rojo) no pone nada.
local function tienda(nombre: string, cf: CFrame, sinChoque: boolean?): Model?
	local molde = MUEBLES[nombre]
	if not molde then
		return nil
	end
	local modelo = molde:Clone() :: Model
	-- Viejos y desteñidos (pedido por el usuario: los colores vivos de la tienda parecían de dibujos animados).
	-- Las telarañas no, y la mecedora ya viene envejecida.
	local envejecer = not (string.find(nombre, "^Telarana") or nombre == "Mecedora")
	local function apagar(c: Color3): Color3
		local h, s, v = c:ToHSV()
		return Color3.fromHSV(h, s * 0.6, v * 0.7)
	end
	for _, d in modelo:GetDescendants() do
		if envejecer and (d:IsA("Texture") or d:IsA("Decal")) then
			d.Color3 = apagar(d.Color3)
		end
		if d:IsA("BasePart") then
			if envejecer then
				if nombre == "Libreria" and d:IsA("MeshPart") then
					-- Su textura es naranja chillón y con textura el color no cuenta: se quita y queda de madera oscura (las
					-- texturas de la cocina y el fregadero sí son buenas y se quedan).
					d.TextureID = ""
					d.Color = Color3.fromRGB(70, 52, 40)
					d.Material = Enum.Material.Wood
				else
					d.Color = apagar(d.Color)
				end
				if d:IsA("UnionOperation") then
					d.UsePartColor = true -- si no, la unión pinta los colores de sus piezas y no cambia
				end
			end
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	modelo:PivotTo(cf)
	modelo.Parent = casa
	if not sinChoque then
		local tam = modelo:GetAttribute("Tam") :: Vector3
		local hueco = HUECOS[nombre]
		if hueco then
			conHueco(nombre, modelo, cf, tam, hueco)
		else
			local choque = bloque("Choque", tam * Vector3.new(0.9, 1, 0.9), cf * CFrame.new(0, tam.Y / 2, 0))
			choque.Transparency = 1
			choque.CanQuery = false
		end
	end
	return modelo
end

-- Araña del vestíbulo (Poly Haven, pedido por el usuario: algo baja): cuelga de un rosetón por una cadena y tiene una
-- sola bombilla viva, en la pantalla de delante, que enciende el generador como las demás lámparas. La del comedor es
-- otra (`nombre`), con su bombilla en `bombilla` (desde abajo del todo) y menos alcance.
local function arana(abajo: Vector3, techo: number, nombre: string?, bombilla: Vector3?, alcance: number?)
	local modelo = tienda(nombre or "AranaPH", CFrame.new(abajo), true)
	if not modelo then
		lampara(Vector3.new(abajo.X, techo - 0.3, abajo.Z))
		return
	end
	tienda("Roseton", CFrame.new(abajo.X, techo, abajo.Z) * CFrame.Angles(math.pi, 0, 0), true)
	local arriba = abajo.Y + (modelo:GetAttribute("Tam") :: Vector3).Y
	local cadena = adorno(Vector3.new(0.15, math.max(techo - arriba, 0.1), 0.15), CFrame.new(abajo.X, (arriba + techo) / 2, abajo.Z), Enum.Material.Metal)
	cadena.Color = Color3.fromRGB(70, 58, 40)
	local p = bloque("Lampara", Vector3.new(0.4, 0.4, 0.4), CFrame.new(abajo + (bombilla or Vector3.new(0, 2.2, -1.75))),
		COLOR.Lampara, Enum.Material.SmoothPlastic)
	p.Shape = Enum.PartType.Ball
	p.CanCollide = false
	p.CastShadow = false
	local luz = Instance.new("PointLight")
	luz.Color = COLOR.Lampara
	luz.Brightness = 1.1
	luz.Range = alcance or 30 -- el hueco del vestíbulo es grande y alto
	luz.Shadows = true
	luz.Enabled = false -- la enciende el generador
	luz.Parent = p
	table.insert(Mapa.lamparas, p)
end

-- Un mueble de la tienda contra la pared: (x, y, z) = un punto de la cara de la pared; `frente` = hacia la sala.
local function contraPared(nombre: string, x: number, y: number, z: number, frente: Vector3, sinChoque: boolean?): Model?
	local molde = MUEBLES[nombre]
	if not molde then
		return nil
	end
	local pos = Vector3.new(x, y, z) + frente * ((molde:GetAttribute("Tam") :: Vector3).Z / 2 + 0.05)
	return tienda(nombre, CFrame.lookAt(pos, pos + frente), sinChoque)
end

local function ventana(centro: Vector3, fuera: Vector3, h, suelo: number)
	local modelo = Instance.new("Model")
	modelo.Name = "Ventana"
	modelo.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- el cliente lo necesita entero
	local mira = CFrame.lookAt(centro, centro + fuera)
	local cristal = bloque("Cristal", Vector3.new(h.ancho, h.alto, 0.2), mira, COLOR.Cristal, Enum.Material.SmoothPlastic, modelo)
	-- Plástico y no Glass: detrás de Glass Roblox no pinta lo transparente (las ramas de los pinos desaparecían).
	marco(mira, h.ancho, h.alto)
	-- Cruceta de madera en el cristal, por fuera.
	adorno(Vector3.new(0.18, h.alto, 0.12), mira * CFrame.new(0, 0, -0.16))
	adorno(Vector3.new(h.ancho, 0.18, 0.08), mira * CFrame.new(0, 0, -0.16))
	cristal.Transparency = 0.75
	cristal.Reflectance = 0.05
	bloque("Repisa", Vector3.new(h.ancho + 0.6, 0.3, 1.6), mira * CFrame.new(0, -h.alto / 2 - 0.15, 0), COLOR.Mueble, nil, modelo)
	Fachada.ventana(mira, h, h.torre)
	modelo.Parent = casa
	if not h.persiana then
		return -- ventana de una sala cerrada: solo cristal
	end
	-- La barra de las cortinas (las cortinas las pinta CasaVista; pedido por el usuario: cortinas, no persianas).
	local barra = bloque("Barra", Vector3.new(h.ancho + 1.8, 0.22, 0.22), mira * CFrame.new(0, h.alto / 2 + 0.55, 0.75),
		COLOR.Marco, Enum.Material.Wood, modelo)
	barra.Shape = Enum.PartType.Cylinder
	barra.CanCollide = false
	barra.CanQuery = false
	mando(mira * CFrame.new(0, 0, 1.4), modelo)
	modelo:SetAttribute("Clave", clave("V", centro))
	modelo:SetAttribute("Centro", mira)
	modelo:SetAttribute("Ancho", h.ancho)
	modelo:SetAttribute("Alto", h.alto)
	modelo:SetAttribute("Atacable", h.atacable == true)
	-- Dónde se pone el bicho para golpear (en la hierba o en el porche, `fueraY`) y dónde cae al entrar (en el suelo de
	-- la sala, a 4 de la ventana; `dentro` si ahí hay un mueble).
	modelo:SetAttribute("Fuera", Vector3.new(centro.X, h.fueraY or 0, centro.Z) + fuera * 4)
	modelo:SetAttribute("Dentro", h.dentro or (Vector3.new(centro.X, suelo, centro.Z) - fuera * 4))
	CollectionService:AddTag(modelo, "Ventana")
end

local function puerta(pie: Vector3, eje: Vector3, h, fuera: Vector3?)
	local modelo = Instance.new("Model")
	modelo.Name = if h.nombre then h.nombre else "Puerta"
	modelo.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	-- La bisagra en el borde izquierdo de abajo; la hoja se extiende hacia `eje`.
	local bisagra = CFrame.fromMatrix(pie - eje * (h.ancho / 2), eje, Vector3.yAxis)
	marco(CFrame.fromMatrix(pie + Vector3.new(0, h.alto / 2, 0), eje, Vector3.yAxis), h.ancho, h.alto, true)
	local hoja = bloque("Hoja", Vector3.new(h.ancho - 0.2, h.alto - 0.1, 0.35), bisagra * CFrame.new(h.ancho / 2, h.alto / 2, 0),
		COLOR.Mueble, nil, modelo)
	bloque("Pomo", Vector3.new(0.3, 0.3, 0.8), hoja.CFrame * CFrame.new(h.ancho / 2 - 0.6, -0.4, 0), COLOR.Oscuro,
		Enum.Material.Metal, modelo)
	mando(CFrame.new(pie + Vector3.new(0, 4, 0)), modelo)
	modelo:SetAttribute("Clave", clave("P", pie))
	modelo:SetAttribute("Bisagra", bisagra)
	modelo:SetAttribute("Hacia", h.hacia)
	modelo:SetAttribute("Ancho", h.ancho)
	modelo:SetAttribute("Bloqueada", h.bloqueada == true)
	modelo:SetAttribute("Llave", h.llave) -- la que la abre (Config.Llaves), si es de una sala cerrada
	if h.atacable and fuera then
		modelo:SetAttribute("Atacable", true)
		modelo:SetAttribute("Centro", CFrame.lookAt(pie + Vector3.new(0, h.alto / 2, 0), pie + Vector3.new(0, h.alto / 2, 0) + fuera))
		modelo:SetAttribute("Fuera", Vector3.new(pie.X, h.fueraY or 0, pie.Z) + fuera * 4)
		modelo:SetAttribute("Dentro", pie - fuera * 4)
	end
	modelo.Parent = casa
	CollectionService:AddTag(modelo, "Puerta")
end

-- Vano abierto (pedido por el usuario: sin puerta donde no hace falta): marco de madera oscura y cortinas a los lados,
-- por las dos caras. No chocan: no estorban al correr. Las cortinas son de terciopelo rojo oscuro con pliegues y
-- recogidas con un cordón (11.8.2: las de bloque con material Fabric se veían como ruido negro con brillos).
local function vanoAbierto(pie: Vector3, eje: Vector3, h)
	local cf = CFrame.fromMatrix(pie + Vector3.new(0, h.alto / 2, 0), eje, Vector3.yAxis)
	marco(cf, h.ancho, h.alto, true)
	for _, cara in { -1, 1 } do
		for _, lado in { -1, 1 } do
			-- Su frente (-Z) mira a la sala de esa cara.
			local suelo = CFrame.fromMatrix(pie, eje, Vector3.yAxis) * CFrame.new(lado * (h.ancho / 2 + 1), 0, cara * 0.85)
			if not tienda("CortinaVano", suelo * CFrame.Angles(0, if cara > 0 then math.pi else 0, 0), true) then
				local cortina = adorno(Vector3.new(1.3, h.alto + 0.6, 0.25), cf * CFrame.new(lado * (h.ancho / 2 + 0.25), 0.3, cara * 0.85),
					Enum.Material.Fabric)
				cortina.Color = Color3.fromRGB(30, 22, 22)
			end
		end
		adorno(Vector3.new(h.ancho + 3.4, 0.2, 0.2), cf * CFrame.new(0, h.alto / 2 + 0.6, cara * 0.85), Enum.Material.Metal).Color =
			COLOR.Oscuro
	end
end

-- Pared recta de (x1, z1) a (x2, z2) (crecientes) con huecos: { en = distancia desde el inicio, ancho, bajo, alto,
-- tipo = "Ventana" | "Puerta" | "Vano" | "Hueco", ... }. `fuera` = hacia dónde queda el exterior (paredes de fuera).
-- `nombre`: pared girada (la torre, en diagonal): sus trozos se llaman así y no llevan papel (vestirParedes).
local function muro(x1: number, z1: number, x2: number, z2: number, y0: number, huecos, fuera: Vector3?, nombre: string?)
	local inicio = Vector3.new(x1, y0, z1)
	local vector = Vector3.new(x2, y0, z2) - inicio
	local largo, eje = vector.Magnitude, vector.Unit
	local enX = math.abs(eje.X) > 0.5
	local function pieza(a: number, b: number, ya: number, yb: number)
		if b - a < 0.05 or yb - ya < 0.05 then
			return
		end
		local centro = inicio + eje * ((a + b) / 2) + Vector3.new(0, (ya + yb) / 2, 0)
		local color = if fuera then COLOR.Fachada else nil
		local tamano = if enX then Vector3.new(b - a, yb - ya, 1) else Vector3.new(1, yb - ya, b - a)
		local trozo = if nombre
			then bloque(nombre, Vector3.new(b - a, yb - ya, 1), CFrame.fromMatrix(centro, eje, Vector3.yAxis), color)
			else bloque("Muro", tamano, CFrame.new(centro), color)
		if fuera then
			Fachada.pared(trozo, fuera)
		end
	end
	table.sort(huecos, function(a, b)
		return a.en < b.en
	end)
	-- Las de fuera se alargan medio stud para cerrar las esquinas; las de dentro acaban en el centro de la que tocan (si
	-- llegaran a su cara de fuera, asomarían en la fachada).
	local extra = if fuera then 0.5 else 0
	local cursor = -extra
	for i, h in huecos do
		local a, b = h.en - h.ancho / 2, h.en + h.ancho / 2
		pieza(cursor, a, 0, ALTO)
		pieza(a, b, 0, h.bajo or 0)
		pieza(a, b, (h.bajo or 0) + h.alto, ALTO)
		local pie = inicio + eje * h.en
		if h.tipo == "Ventana" then
			-- Pared libre a cada lado, para las contraventanas (Fachada): en los ejes de la ventana, X = fuera × arriba.
			local siguiente = if huecos[i + 1] then huecos[i + 1].en - huecos[i + 1].ancho / 2 else largo + extra
			local antes, despues = a - cursor, siguiente - b
			local derecha = (fuera :: Vector3):Cross(Vector3.yAxis):Dot(eje) > 0
			h.libreDer, h.libreIzq = if derecha then despues else antes, if derecha then antes else despues
			h.torre = nombre ~= nil
			ventana(pie + Vector3.new(0, h.bajo + h.alto / 2, 0), fuera :: Vector3, h, y0)
		elseif h.tipo == "Puerta" then
			puerta(pie, eje, h, fuera)
		elseif h.tipo == "Vano" then
			vanoAbierto(pie, eje, h)
		end
		cursor = b
	end
	pieza(cursor, largo + extra, 0, ALTO)
end

local function v(ancho, bajo, alto, en, persiana, atacable, fueraY)
	return { tipo = "Ventana", en = en, ancho = ancho, bajo = bajo, alto = alto, persiana = persiana, atacable = atacable,
		fueraY = fueraY }
end

-- Ventana de fuera con tablas clavadas (Fachada).
local function tapiada(h)
	h.tapiada = true
	return h
end

local function vano(en, ancho)
	return { tipo = "Vano", en = en, ancho = ancho, bajo = 0, alto = 10 }
end

-- Puertas de 5 × 10,5 (pedido por el usuario: las de 4 × 9 y 4 × 8 parecían "enanas" al lado del personaje).
local function p(en, hacia: Vector3, extra)
	local h = { tipo = "Puerta", en = en, ancho = 5, bajo = 0, alto = 10.5, hacia = hacia }
	for campo, valor in extra or {} do
		h[campo] = valor
	end
	return h
end

-- Armario de lamas: se ve fuera entre las rendijas. `frente` = hacia dónde mira la puerta.
local function armario(centro: Vector3, frente: Vector3)
	local modelo = Instance.new("Model")
	modelo.Name = "Armario"
	modelo.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- el cliente lo necesita entero
	local cf = CFrame.lookAt(centro, centro + frente) -- -Z del armario = frente
	local function trozo(tamano: Vector3, offset: Vector3)
		bloque("Armario", tamano, cf * CFrame.new(offset), COLOR.Mueble, nil, modelo)
	end
	trozo(Vector3.new(4.6, 8, 0.3), Vector3.new(0, 0, 1.35)) -- fondo
	trozo(Vector3.new(0.3, 8, 3), Vector3.new(-2.15, 0, 0))
	trozo(Vector3.new(0.3, 8, 3), Vector3.new(2.15, 0, 0))
	trozo(Vector3.new(4.6, 0.3, 3), Vector3.new(0, 3.85, 0))
	trozo(Vector3.new(4.6, 0.3, 3), Vector3.new(0, -3.85, 0))
	for i = 0, 18 do -- puertas de lamas con rendijas estrechas: se ve fuera a rayas
		trozo(Vector3.new(4.0, 0.25, 0.12), Vector3.new(0, -3.6 + i * 0.4, -1.35))
	end	local suelo = centro.Y - 4
	mueble("ArmarioMarco", cf * CFrame.new(0, -4, 0), nil, modelo)
	modelo:SetAttribute("Tipo", "Armario")
	modelo:SetAttribute("Dentro", CFrame.lookAt(Vector3.new(centro.X, suelo + 3, centro.Z), Vector3.new(centro.X, suelo + 3, centro.Z) + frente))
	modelo:SetAttribute("Vista", cf * CFrame.new(0, 1.6, 0.4)) -- al fondo: las lamas no tapan media pantalla
	modelo:SetAttribute("Salida", CFrame.lookAt(Vector3.new(centro.X, suelo + 3, centro.Z) + frente * 3.5,
		Vector3.new(centro.X, suelo + 3, centro.Z) + frente * 6))
	modelo:SetAttribute("Ocupado", 0)
	mando(cf * CFrame.new(0, -1, -2.2), modelo)
	modelo.Parent = casa
	CollectionService:AddTag(modelo, "Escondite")
end

-- Cama con hueco debajo para esconderse. `largo` = de los pies a la cabecera; `lado` (1 o -1) por dónde se sale.
-- `aspecto` = un mueble de ServerStorage.Muebles con la cabecera a +Z (la de hierro del dormitorio de abajo, con su
-- colcha `ropa`), de `ancho` × `largoCama`; sin él, la de Blender de 5 × 8. Los bloques siguen chocando, invisibles.
local function cama(centro: Vector3, largo: Vector3, lado: number, aspecto: string?, ropa: string?, ancho: number?, largoCama: number?)
	local modelo = Instance.new("Model")
	modelo.Name = "Cama"
	modelo.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- el cliente lo necesita entero
	local cf = CFrame.lookAt(centro, centro + largo) -- -Z = hacia la cabecera
	local a, l = ancho or 5, largoCama or 8
	local trozos = {}
	local function trozo(nombre: string, tamano: Vector3, offset: Vector3, color: Color3?)
		table.insert(trozos, bloque(nombre, tamano, cf * CFrame.new(offset), color or COLOR.Mueble, nil, modelo))
	end
	trozo("Colchon", Vector3.new(a, 1, l), Vector3.new(0, 2.9, 0), Color3.fromRGB(120, 116, 110))
	trozo("Somier", Vector3.new(a + 0.2, 0.4, l + 0.2), Vector3.new(0, 2.2, 0))
	trozo("Cabecero", Vector3.new(a + 0.2, 5, 0.4), Vector3.new(0, 2.5, -l / 2 - 0.2))
	for _, x in { -a / 2 + 0.1, a / 2 - 0.1 } do
		for _, z in { -l / 2 + 0.1, l / 2 - 0.1 } do
			trozo("Pata", Vector3.new(0.4, 2, 0.4), Vector3.new(x, 1, z))
		end
	end
	trozo("Almohada", Vector3.new(a - 1, 0.6, 1.4), Vector3.new(0, 3.7, -l / 2 + 0.8), Color3.fromRGB(140, 136, 130))
	local girada = cf * CFrame.Angles(0, math.pi, 0) -- la cabecera del mueble (+Z) hacia la de la cama
	if aspecto and tienda(aspecto, girada, true) then
		for _, b in trozos do
			b.Transparency = 1
		end
		if ropa then -- lo más bajo de la colcha (el bajo, por los lados) va a 1,24 del suelo
			tienda(ropa, girada * CFrame.new(0, 1.24, -0.03), true)
		end
	else
		mueble("Cama", cf, trozos, modelo)
	end
	-- Tumbado boca abajo debajo de la cama, la cabeza hacia los pies de la cama, mirando fuera.
	local dentro = cf * CFrame.new(0, 0.7, -0.5) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(-math.pi / 2, 0, 0)
	modelo:SetAttribute("Tipo", "Cama")
	modelo:SetAttribute("Dentro", dentro)
	modelo:SetAttribute("Vista", cf * CFrame.new(0, 0.9, 3.2) * CFrame.Angles(0, math.pi, 0))
	local salida = cf * CFrame.new(4.5 * lado, 3, 0)
	modelo:SetAttribute("Salida", CFrame.lookAt(salida.Position, salida.Position + cf.RightVector * lado))
	modelo:SetAttribute("Ocupado", 0)
	mando(cf * CFrame.new(3 * lado, 1.5, 2), modelo)
	modelo.Parent = casa
	CollectionService:AddTag(modelo, "Escondite")
end

-- Manchas y sangre, blancas para teñirlas (tools/texturas/sangre.ps1). La sangre, sin pasar de la etiqueta Moderate
-- (pedido por el usuario).
local SANGRE = { "rbxassetid://85700610438600", "rbxassetid://78490976398688", "rbxassetid://76547078941684" }

-- Calcomanía en una lámina invisible: en el suelo (`normal` = arriba) o en una pared (`normal` = hacia la sala).
-- Cuadrada de `tam`, o de `tam` × `alto`.
local function mancha(pos: Vector3, normal: Vector3, tam: number, imagen: string, color: Color3, giro: number, alto: number?)
	local cf = CFrame.lookAt(pos, pos + normal) * CFrame.Angles(0, 0, giro)
	local soporte = adorno(Vector3.new(tam, alto or tam, 0.04), cf)
	soporte.Transparency = 1
	soporte.CastShadow = false
	local d = Instance.new("Decal")
	d.Texture = imagen
	d.Color3 = color
	d.Face = Enum.NormalId.Front
	d.Parent = soporte
end

-- Las salas (MapaSalas), lo de fuera de las salas (MapaAnexos) y el bosque (MapaBosque) están en sus módulos, con
-- estas mismas ayudas. `casa` es una función: Mapa.conPadre cambia la casa un rato y así siempre ven la de ahora.
local ayudas = {
	Mapa = Mapa,
	casa = function(): Model
		return casa
	end,
	MUEBLES = MUEBLES,
	bloque = bloque,
	variante = variante,
	mando = mando,
	lampara = lampara,
	adorno = adorno,
	tienda = tienda,
	contraPared = contraPared,
	muro = muro,
	v = v,
	p = p,
	clave = clave,
	mancha = mancha,
	SANGRE = SANGRE,
}
MapaAnexos.iniciar(ayudas)
MapaSalas.iniciar(ayudas)
MapaBosque.iniciar(ayudas)

-- Torre de la esquina de delante a la izquierda, mirando la casa desde el camino (pedido por el usuario): un octógono
-- de 8 de apotema centrado en la esquina de la casa (x 39, z -33), en las dos plantas. Abajo es el mirador del salón y
-- arriba, del dormitorio grande: las caras que caen dentro de la casa no se hacen y la torre se abre a la sala. La cara
-- k mira a k·45° (0 = +x, girando hacia +z). `ventanas` = { [k] = hueco }; `sinSuelo`: el de abajo ya pone el techo.
local function construirTorre(y0: number, ventanas, sinSuelo: boolean?)
	local radio = TORRE.apotema / math.cos(math.pi / 8)
	local function vertice(angulo: number): Vector3
		return Vector3.new(TORRE.x + radio * math.cos(angulo), 0, TORRE.z + radio * math.sin(angulo))
	end
	-- { cara, desde, hasta } en tantos por uno de la cara: de la que mira a -x y la que mira a +z, solo la mitad de fuera.
	for _, c in { { 4, 0.5, 1 }, { 5, 0, 1 }, { 6, 0, 1 }, { 7, 0, 1 }, { 0, 0, 1 }, { 1, 0, 1 }, { 2, 0, 0.5 } } do
		local k = c[1]
		local a, b = vertice((k - 0.5) * math.pi / 4), vertice((k + 0.5) * math.pi / 4)
		local p0, p1 = a:Lerp(b, c[2]), a:Lerp(b, c[3])
		local h = ventanas[k]
		if h then
			h.en = (p1 - p0).Magnitude / 2
		end
		local normal = Vector3.new(math.cos(k * math.pi / 4), 0, math.sin(k * math.pi / 4))
		muro(p0.X, p0.Z, p1.X, p1.Z, y0, if h then { h } else {}, normal, "MuroTorre")
	end
	-- Suelo y techo redondos (el borde lo tapa la pared).
	for _, y in if sinSuelo then { y0 + ALTO + 0.5 } else { y0 - 0.5, y0 + ALTO + 0.5 } do
		local disco = bloque("Piso", Vector3.new(1, radio * 2, radio * 2), CFrame.new(TORRE.x, y, TORRE.z) * CFrame.Angles(0, 0, math.pi / 2),
			COLOR.Piso)
		disco.Shape = Enum.PartType.Cylinder
		CollectionService:AddTag(disco, "EnMapa")
	end
end

-- La casa nueva (11.6, plano aprobado por el usuario en docs/referencias/casa-fuera/plano-nuevo.png; izquierda y
-- derecha, mirando la casa desde el camino: +x es la izquierda). Salas grandes y vanos anchos para correr (pedido por
-- el usuario). Abajo: porche, vestíbulo a doble altura (x -12..12) con la escalera grande al fondo, salón con chimenea
-- y la torre a la izquierda, comedor con mirador a la derecha, cocina detrás con el lavadero saliendo hacia atrás y el
-- garaje pegado, pasillo al sótano, dormitorio con baño y trastero. Arriba: galería con barandilla al hueco, dormitorio
-- grande con la torre y salida al balcón (encima del porche), cuarto de la escalera del desván, habitación del rico y
-- cuarto de los niños. Lo que tenía cada sala vieja, en docs/sistemas/casa-vieja.md.
local function construirCasa(mapa: Folder)
	casa = Instance.new("Model")
	casa.Name = "Casa"
	Fachada.empezar(casa)
	local DELANTE, DETRAS = Vector3.new(0, 0, -1), Vector3.new(0, 0, 1)
	local OESTE, ESTE = Vector3.new(-1, 0, 0), Vector3.new(1, 0, 0)

	-- Suelos: abajo entero, más el mirador del comedor y el lavadero (con su techo). Arriba, con el hueco del vestíbulo,
	-- que es de doble altura (x -11.5..11.5, z -32.5..0).
	bloque("Piso", Vector3.new(79, 1, 67), CFrame.new(0, 0.5, 0), COLOR.Piso)
	for _, r in { { -43.5, -39.5, -17.5, -2.5 }, { -26.5, -11.5, 33.5, 45.5 } } do
		local x1, x2, z1, z2 = r[1], r[2], r[3], r[4]
		CollectionService:AddTag(bloque("Piso", Vector3.new(x2 - x1, 1, z2 - z1), CFrame.new((x1 + x2) / 2, 0.5, (z1 + z2) / 2), COLOR.Piso),
			"EnMapa")
		bloque("Techo", Vector3.new(x2 - x1 + 1, 1, z2 - z1 + 1), CFrame.new((x1 + x2) / 2, ABAJO + ALTO + 0.5, (z1 + z2) / 2), COLOR.Oscuro,
			Enum.Material.Slate)
	end
	for _, r in { { -39.5, -11.5, -33.5, 33.5 }, { 11.5, 39.5, -33.5, 33.5 }, { -11.5, 11.5, 0, 33.5 }, { -11.5, 11.5, -33.5, -32.5 } } do
		local x1, x2, z1, z2 = r[1], r[2], r[3], r[4]
		bloque("Piso", Vector3.new(x2 - x1, 1, z2 - z1), CFrame.new((x1 + x2) / 2, 13.5, (z1 + z2) / 2), COLOR.Piso)
	end
	-- Techo con el hueco de la escalera del desván (x 13..17, z 15..23).
	for _, r in { { -39.5, 13, -33.5, 33.5 }, { 17, 39.5, -33.5, 33.5 }, { 13, 17, -33.5, 15 }, { 13, 17, 23, 33.5 } } do
		local x1, x2, z1, z2 = r[1], r[2], r[3], r[4]
		bloque("Techo", Vector3.new(x2 - x1, 1, z2 - z1), CFrame.new((x1 + x2) / 2, 26.5, (z1 + z2) / 2), COLOR.Piso)
	end
	local inclinacion = math.atan(TEJADO.pendiente)
	local largoFaldon = TEJADO.alero / math.cos(inclinacion)
	for _, lado in { 1, -1 } do
		bloque("Tejado", Vector3.new(82, 1, largoFaldon), CFrame.new(0, 27 + TEJADO.pendiente * TEJADO.alero / 2, TEJADO.alero / 2 * lado)
			* CFrame.Angles(inclinacion * lado, 0, 0), COLOR.Oscuro, Enum.Material.Slate)
	end
	MapaAnexos.construirDesvan()

	-- Porche a lo largo de la fachada (x -30..27): suelo de tablas a la altura de la casa, un escalón todo alrededor
	-- para subir por cualquier sitio, postes (no chocan) y el tejadillo, que arriba es el balcón (con barandilla).
	CollectionService:AddTag(bloque("Porche", Vector3.new(57, 1, 8), CFrame.new(-1.5, 0.5, -37), COLOR.Piso), "EnMapa")
	bloque("Escalon", Vector3.new(60, 0.5, 1.5), CFrame.new(-1.5, 0.25, -41.75), COLOR.Piso)
	for _, x in { 27.75, -30.75 } do
		bloque("Escalon", Vector3.new(1.5, 0.5, 8), CFrame.new(x, 0.25, -37), COLOR.Piso)
	end
	for _, x in { 26.4, 15, 4, -4, -15, -29.4 } do
		Fachada.columna(x, -40.4, ABAJO, ABAJO + ALTO - 1.2)
	end
	bloque("Porche", Vector3.new(58, 1, 8.5), CFrame.new(-1.5, 13.5, -37.25), COLOR.Piso)
	-- La barandilla del balcón choca con una pared invisible; lo que se ve es la balaustrada (Fachada).
	bloque("Barandilla", Vector3.new(58, 3.2, 0.4), CFrame.new(-1.5, ARRIBA + 1.6, -41.3)).Transparency = 1
	Fachada.balaustrada(Vector3.new(-30.3, ARRIBA, -41.3), Vector3.new(27.3, ARRIBA, -41.3), 3.2, false)
	for _, x in { -30.3, 27.3 } do
		bloque("Barandilla", Vector3.new(0.4, 3.2, 8.1), CFrame.new(x, ARRIBA + 1.6, -37.3)).Transparency = 1
		Fachada.balaustrada(Vector3.new(x, ARRIBA, -41.1), Vector3.new(x, ARRIBA, -33.6), 3.2, false)
	end

	-- Escalera grande al fondo del vestíbulo (pedido por el usuario: grande y que no se tope uno con ella al entrar):
	-- 13 peldaños de 9 de ancho que suben hacia +z de z -18 a la galería (z 0); los dos primeros, más anchos. Delante
	-- quedan 14 studs libres y a los lados, 7 de paso hacia el fondo.
	-- Los seis de abajo, macizos; los de arriba son solo la huella, con el bajo de la escalera inclinado por debajo:
	-- se ve hueco y se pasa por debajo (en bloque entero tapaba el paso bajo la galería).
	-- Peldaños de madera oscura con alfombra de escalera roja y roída (más estrecha en unos, con calvas en otros) y su
	-- varilla de latón en cada rincón (11.8.1).
	local huella = 18 / 13
	local roida = Random.new(5) -- siempre igual en todos los servidores
	for i = 1, 13 do
		local ancho = if i == 1 then 12 elseif i == 2 then 10.5 else 9
		local alto = if i <= 6 then i else 1
		local z = -18 + (i - 0.5) * huella
		variante(bloque("Peldano", Vector3.new(ancho, alto, huella), CFrame.new(0, ABAJO + i - alto / 2, z), COLOR.Piso), "MaderaOscura")
		local largo = if i == 4 or i == 10 then huella * 0.55 else huella -- calvas: la alfombra gastada hasta la madera
		local tela = 5 - roida:NextNumber(0, 0.7)
		local x = roida:NextNumber(-0.2, 0.2)
		variante(adorno(Vector3.new(tela, 0.06, largo), CFrame.new(x, ABAJO + i + 0.04, z + (huella - largo) / 2)), "AlfombraRoja")
		variante(adorno(Vector3.new(tela, 0.96, 0.06), CFrame.new(x, ABAJO + i - 0.5, z - huella / 2 - 0.04)), "AlfombraRoja")
		local varilla = adorno(Vector3.new(tela + 0.4, 0.09, 0.09), CFrame.new(x, ABAJO + i + 0.06, z - huella / 2 + 0.03), Enum.Material.Metal)
		varilla.Color = Color3.fromRGB(92, 74, 40)
	end
	local largoBajo = math.sqrt((7 * huella) ^ 2 + 7 ^ 2)
	adorno(Vector3.new(9, 0.3, largoBajo), CFrame.new(0, ABAJO + 6 + 3.5 - 1.2, -18 + 6 * huella + 3.5 * huella)
		* CFrame.Angles(-math.atan2(7, 7 * huella), 0, 0), Enum.Material.WoodPlanks)
	-- Pasamanos a los dos lados: poste abajo, barrotes, la barandilla inclinada y una pared invisible que no deja caerse.
	-- El centro de cada peldaño está en la línea y = ABAJO + 0,5 + (z + 18) · 13/18.
	local subida = math.atan2(13, 18)
	local baranda = math.sqrt(13 ^ 2 + 18 ^ 2)
	-- Poste torneado en el arranque y un barrote torneado en cada peldaño (Blender, a_mano.py); sin ellos, los de bloque.
	for _, x in { -4.7, 4.7 } do
		local xb = x * 4.4 / 4.7 -- barrotes y pasamanos, sobre el borde del peldaño (de 9)
		if not tienda("PosteEscalera", CFrame.new(xb, ABAJO + 1, -17.3), true) then
			adorno(Vector3.new(0.7, 4.6, 0.7), CFrame.new(x, ABAJO + 1 + 2.3, -17.3))
		end
		variante(adorno(Vector3.new(0.4, 0.3, baranda), CFrame.new(xb, ABAJO + 7 + 3.25, -9) * CFrame.Angles(-subida, 0, 0)), "MaderaOscura")
		for i = 2, 13 do
			local z = -18 + (i - 0.5) * huella
			if not tienda("Balaustre", CFrame.new(xb, ABAJO + i, z), true) and i % 2 == 1 then
				adorno(Vector3.new(0.2, 3.2, 0.2), CFrame.new(x, ABAJO + i + 1.6, z))
			end
		end
		local pared = bloque("Choque", Vector3.new(0.3, 4, baranda), CFrame.new(x, ABAJO + 7 + 1.5, -9) * CFrame.Angles(-subida, 0, 0))
		pared.Transparency = 1
		pared.CanQuery = false
	end
	-- Barandilla de la galería, al borde del hueco: choca invisible; lo que se ve, la balaustrada, va en vestirGaleria.
	for _, x in { -8.1, 8.1 } do
		local barandilla = bloque("Barandilla", Vector3.new(6.8, 3.5, 0.4), CFrame.new(x, ARRIBA + 1.75, 0.2), COLOR.Mueble)
		barandilla.Transparency = if MUEBLES.BalaustradaGaleria then 1 else 0
	end

	-- Planta baja: fuera. Ninguna ventana tiene muebles delante (pedido por el usuario). Las de delante dan al porche.
	muro(-39, -33, 31, -33, ABAJO, {
		v(8, 2, 7, 15, true, true, ABAJO), -- comedor
		p(39, DETRAS, { ancho = 7, atacable = true, nombre = "PuertaPrincipal", fueraY = ABAJO }),
		v(8, 2, 7, 64, true, true, ABAJO), -- ventanal del salón
	}, DELANTE)
	muro(-39, 33, 39, 33, ABAJO, {
		v(4, 3, 5, 5, true, true), -- cocina
		vano(22.5, 7), -- lavadero
		p(39, DELANTE, { bloqueada = true, nombre = "Sotano", llave = "LlaveSotano" }), -- baja al sótano
		v(3, 5, 3, 56, false), -- baño
		v(6, 3, 5, 65, true, true), -- dormitorio
	}, DETRAS)
	muro(39, -25, 39, 33, ABAJO, { v(6, 3, 5, 40, true, true) }, ESTE) -- dormitorio (en el salón está la chimenea)
	muro(-39, -33, -39, 3, ABAJO, { { tipo = "Hueco", en = 23, ancho = 14, alto = 10 } }, OESTE) -- comedor, abierto al mirador
	-- Mirador del comedor (x -43..-39, z -17..-3).
	muro(-43, -17, -39, -17, ABAJO, {}, DELANTE)
	muro(-43, -17, -43, -3, ABAJO, { v(6, 2, 7, 7, true, true) }, OESTE)
	muro(-43, -3, -39, -3, ABAJO, {}, DETRAS)
	-- Lavadero (x -26..-12, z 33..45), saliendo por detrás de la cocina.
	muro(-12, 33, -12, 45, ABAJO, {}, ESTE)
	-- El bicho que entra por su ventana cae junto a la pila: a 4 de ella caía dentro del armario de lamas.
	local lavadero = v(4, 4, 3, 9, true, true)
	lavadero.dentro = Vector3.new(-21, ABAJO, 38.5)
	muro(-26, 33, -26, 45, ABAJO, { lavadero }, OESTE)
	muro(-26, 45, -12, 45, ABAJO, {}, DETRAS)
	-- Torre: el mirador del salón, con la ventana grande mirando a la esquina y dos estrechas a los lados.
	construirTorre(ABAJO, { [7] = v(5, 2, 7, 0, true, true), [6] = v(3, 3, 5, 0, false), [0] = v(3, 3, 5, 0, false) })
	-- Planta baja: dentro. Vanos abiertos y anchos con marco y cortinas donde no hace falta puerta (pedido por el usuario).
	muro(-12, -33, -12, 33, ABAJO, { vano(13, 12), vano(55, 10) }) -- vestíbulo | comedor, pasillo | cocina
	muro(12, -33, 12, 33, ABAJO, { vano(13, 12), vano(47, 8) }) -- vestíbulo | salón, pasillo | trastero
	muro(12, 5, 39, 5, ABAJO, { vano(18.5, 9) }) -- salón | trastero y dormitorio
	muro(22, 5, 22, 33, ABAJO, { vano(21, 6) }) -- trastero y baño | dormitorio
	muro(12, 19, 22, 19, ABAJO, {}) -- trastero | baño
	muro(-12, 9, 12, 9, ABAJO, { vano(12, 16) }) -- vestíbulo | pasillo
	muro(-39, 3, -12, 3, ABAJO, { vano(8, 10) }) -- comedor | cocina

	-- Planta de arriba: fuera. Tres ventanas con cortina (dormitorio grande, torre y habitación del rico); las demás,
	-- solo cristal. La de delante que da al hueco, sin cortina: no se llega a ella.
	muro(-39, -33, 31, -33, ARRIBA, {
		v(5, 3, 5, 15, true), -- habitación del rico
		v(4, 3, 5, 39, false), -- hueco del vestíbulo
		p(57, DETRAS, { nombre = "Balcon" }), -- salida al balcón
		v(5, 3, 5, 66.5, true), -- dormitorio grande
	}, DELANTE)
	muro(-39, 33, 39, 33, ARRIBA, { v(5, 3, 5, 13, false), tapiada(v(5, 3, 5, 39, false)), v(5, 3, 5, 65, false) }, DETRAS)
	muro(-39, -33, -39, 33, ARRIBA, { v(5, 3, 5, 18, false), v(5, 3, 5, 54, false) }, OESTE)
	muro(39, -25, 39, 33, ARRIBA, { v(5, 3, 5, 18, false), v(5, 3, 5, 45, false) }, ESTE)
	construirTorre(ARRIBA, { [7] = v(5, 3, 5, 0, true), [6] = v(3, 3, 5, 0, false), [0] = v(3, 3, 5, 0, false) }, true)
	-- Planta de arriba: dentro. La galería (x -12..12, z 0..33) da a todo.
	muro(12, -33, 12, 33, ARRIBA, {
		vano(37.5, 8), -- dormitorio grande
		p(62.5, ESTE, { ancho = 4, bloqueada = true, nombre = "Desvan", llave = "LlaveDesvan" }), -- escalera del desván
	})
	muro(-12, -33, -12, 33, ARRIBA, {
		p(37.5, OESTE, { bloqueada = true, nombre = "HabitacionDelRico", llave = "LlaveRico" }),
		vano(54, 10), -- cuarto de los niños
	})
	muro(12, 9, 39, 9, ARRIBA, {}) -- dormitorio grande | escalera del desván
	muro(-39, 9, -12, 9, ARRIBA, {}) -- habitación del rico | niños
	-- Cuarto de la escalera del desván (x 12..39, z 9..33 arriba): al entrar, 13 peldaños subiendo hacia -z hasta el
	-- techo, con pared al lado para que se coja por abajo.
	for i = 1, 13 do
		bloque("Peldano", Vector3.new(4, i, 1), CFrame.new(15, ARRIBA + i / 2, 28 - (i - 0.5)), COLOR.Piso)
	end
	bloque("Muro", Vector3.new(0.6, ALTO, 12), CFrame.new(17.3, ARRIBA + ALTO / 2, 21))
	-- Baúles, maletas y lo demás del cuarto, en vestirDesvan.

	-- Chimenea del salón (Chimenea, y por ella baja el Trepador): el tiro sube por el dormitorio grande hasta salir por
	-- el tejado. Está en x = 37,5 y z = -1: el Trepador va a ella por el tejado.
	local chimenea = Instance.new("Model")
	chimenea.Name = "Chimenea"
	local ladrillo = Color3.fromRGB(80, 60, 52) -- ladrillo viejo, oscuro
	-- Ladrillo viejo de verdad (11.8.2); el frente tallado y lo de la repisa van aparte, en el salón (no tocan el hogar).
	variante(bloque("Chimenea", Vector3.new(3, 10, 8), CFrame.new(37.5, ABAJO + 5, -1), ladrillo, Enum.Material.Brick, chimenea),
		"LadrilloSalon")
	bloque("Hogar", Vector3.new(0.6, 3.5, 4), CFrame.new(35.8, ABAJO + 1.75, -1), Color3.fromRGB(20, 18, 18), Enum.Material.Slate, chimenea)
	variante(bloque("Tiro", Vector3.new(3, 34, 4), CFrame.new(37.5, ABAJO + 10 + 17, -1), ladrillo, Enum.Material.Brick, chimenea),
		"LadrilloSalon")
	mando(CFrame.new(34.8, ABAJO + 2, -1), chimenea)
	chimenea:SetAttribute("Hogar", CFrame.new(34.6, ABAJO + 0.8, -1) * CFrame.Angles(0, -math.pi / 2, 0)) -- donde arde el tronco
	chimenea:SetAttribute("Tiro", Vector3.new(37.5, ABAJO + 44, -1)) -- la boca de arriba
	chimenea:SetAttribute("Salida", CFrame.lookAt(Vector3.new(33, ABAJO, -1), Vector3.new(23, ABAJO, -1))) -- delante del hogar
	CollectionService:AddTag(chimenea, "Chimenea")
	chimenea.Parent = casa

	-- Muebles contra las paredes sin ventana y el centro de cada sala libre para correr (pedido por el usuario).
	-- Vestíbulo (11.8.1, opción B del usuario, "entrada vacía y fría"): a la entrada solo el perchero (con abrigo y
	-- sombrero: de noche parece alguien quieto), las cartas tiradas junto a la puerta y la alfombra larga algo torcida;
	-- el reloj de pie, el banco y la consola con espejo, al fondo bajo la galería, que se ven al rodear la escalera.
	-- Cuadros torcidos a la entrada, junto a la escalera y en lo alto del hueco. Muebles de Poly Haven (polyhaven.md).
	local perchero = tienda("Perchero", CFrame.new(6.5, ABAJO, -31) * CFrame.Angles(0, math.rad(-20), 0))
	local abrigo = perchero and perchero:FindFirstChild("Perchero_1") :: BasePart?
	if abrigo then -- el abrigo, algo separado del perchero (movido por el usuario)
		abrigo.CFrame = CFrame.new(6.77, ABAJO + 4.81, -30.14) * CFrame.Angles(0, math.rad(-19), 0)
	end
	tienda("AlfombraLarga", CFrame.new(0.4, ABAJO + 0.05, -24.8) * CFrame.Angles(0, math.rad(3), 0), true)
	tienda("Cartas", CFrame.new(-5, ABAJO + 0.07, -30.6) * CFrame.Angles(0, math.rad(15), 0), true)
	contraPared("RelojPiePH", 10, ABAJO, 8.5, DELANTE)
	contraPared("BancoPH", 11.5, ABAJO, 3.5, OESTE)
	contraPared("ConsolaPH", -11.5, ABAJO, 3, ESTE)
	contraPared("EspejoPH", -11.4, ABAJO + 4.4, 3, ESTE, true)
	-- En la consola, un jarrón y dos candeleros, uno tumbado; a la entrada, un cuadro caído apoyado en la pared.
	tienda("JarronPH", CFrame.new(-10.4, ABAJO + 3.78, 1.2), true)
	tienda("CandeleroPH", CFrame.new(-10.5, ABAJO + 3.78, 5), true)
	tienda("CandeleroPH", CFrame.new(-10.2, ABAJO + 3.98, 4.1) * CFrame.Angles(0, math.rad(70), math.rad(90)), true)
	tienda("CuadroPH1", CFrame.lookAt(Vector3.new(9.6, ABAJO, -31.9), Vector3.new(9.6, ABAJO, 0)) * CFrame.Angles(math.rad(14), 0, 0), true)
	for _, c in {
		{ "CuadroPH2", 11.4, ABAJO + 4.6, -29.5, OESTE, -4 }, { "CuadroPH1", -11.4, ABAJO + 5.4, -29.5, ESTE, 3 },
		{ "CuadroPH1", 11.4, ABAJO + 5, -8, OESTE, 6 }, { "CuadroPH2", -11.4, ABAJO + 4.6, -9, ESTE, -2 },
		{ "CuadroPH2", -11.4, ARRIBA + 3, -20, ESTE, 2 }, { "CuadroPH1", 11.4, ARRIBA + 4, -17, OESTE, -3 },
	} do
		local cuadro = contraPared(c[1], c[2], c[3], c[4], c[5], true)
		if cuadro then
			cuadro:PivotTo(cuadro:GetPivot() * CFrame.Angles(0, 0, math.rad(c[6])))
		end
	end

	-- Salón (11.8.2, opción B del usuario, "dos rincones"). Rincón de la tele en la esquina del fondo: la tele de tubo en
	-- su mueble, el sofá tapado con una sábana (casa cerrada) de espaldas a la sala mirándola, mesa baja, alfombra persa
	-- y lámpara de pie. Rincón de lectura junto al fuego: butaca, mesita con la lámpara de aceite y la librería con
	-- enciclopedias (huecos y una caída). El piano dentro de la torre, contra la cara sin ventana, con su banqueta. Vitrina
	-- con fotos junto al ventanal. Repisa tallada en la chimenea. El centro y delante del hogar, libres.
	contraPared("MuebleTelePH", 17.6, ABAJO, 4.5, DELANTE)
	contraPared("TelePH", 17.6, ABAJO + 3.3, 4.5, DELANTE, true)
	tienda("AlfombraSalon", CFrame.new(17.6, ABAJO + 0.02, -1) * CFrame.Angles(0, math.pi / 2, 0), true)
	tienda("MesaBajaPH", CFrame.new(17.6, ABAJO, 0.2) * CFrame.Angles(0, math.rad(4), 0))
	tienda("SofaTapado", CFrame.new(17.6, ABAJO, -5.2) * CFrame.Angles(0, math.pi, 0))
	local pie = tienda("LamparaPie", CFrame.new(22.6, ABAJO, 3.3), true)
	if pie then
		for _, d in pie:GetDescendants() do
			if d:IsA("BasePart") then
				d.CastShadow = false -- que la pantalla no tape la luz
			end
		end
		local bombilla = bloque("Lampara", Vector3.new(0.45, 0.45, 0.45), CFrame.new(22.6, ABAJO + 5.55, 3.3), COLOR.Lampara,
			Enum.Material.SmoothPlastic)
		bombilla.Shape = Enum.PartType.Ball
		bombilla.CanCollide = false
		bombilla.CastShadow = false
		local luz = Instance.new("PointLight")
		luz.Color = COLOR.Lampara
		luz.Brightness = 0.9
		luz.Range = 22
		luz.Shadows = true
		luz.Enabled = false -- la enciende el generador
		luz.Parent = bombilla
		table.insert(Mapa.lamparas, bombilla)
	end
	tienda("ButacaPH", CFrame.lookAt(Vector3.new(32.6, ABAJO, -9.4), Vector3.new(35.5, ABAJO, -1.5)))
	contraPared("MesitaPH", 38.5, ABAJO, -12.2, OESTE)
	tienda("LamparaAceitePH", CFrame.new(37.5, ABAJO + 2.2, -11.8), true)
	contraPared("LibreriaPH", 38.5, ABAJO, -18.5, OESTE)
	for _, libro in { { 3.84, -19.7 }, { 3.84, -17.5 }, { 5.11, -19.7 }, { 6.65, -18.9 }, { 6.65, -16.9 } } do
		local pos = Vector3.new(37.4, ABAJO + libro[1], libro[2])
		tienda("EnciclopediaPH", CFrame.lookAt(pos, pos + OESTE), true)
	end
	-- Una tumbada en el suelo, delante de la librería (de lado: el centro de la caja a ras de suelo).
	tienda("EnciclopediaPH", CFrame.new(35.4, ABAJO + 0.33, -16.2) * CFrame.Angles(0, 0.7, 0) * CFrame.Angles(math.pi / 2, 0, 0)
		* CFrame.new(0, -0.475, 0), true)
	-- Piano y banqueta en la torre, contra su cara de atrás (la que mira a +x +z, sin ventana), mirando al centro.
	for _, cosa in { { "Piano", 6.2 }, { "Banqueta", 3.7 } } do
		local pos = Vector3.new(TORRE.x, ABAJO, TORRE.z) + Vector3.new(1, 0, 1).Unit * cosa[2]
		tienda(cosa[1], CFrame.lookAt(pos, Vector3.new(TORRE.x, ABAJO, TORRE.z)))
	end
	contraPared("VitrinaPH", 16.5, ABAJO, -32.5, DETRAS)
	for _, foto in { { "FotoPH1", 14.4, 10 }, { "FotoPH2", 16.2, -8 } } do
		local pos = Vector3.new(foto[2], ABAJO + 3.26, -30.6)
		tienda(foto[1], CFrame.lookAt(pos, pos + DETRAS) * CFrame.Angles(0, math.rad(foto[3]), 0), true)
	end
	-- Una foto boca abajo en la vitrina.
	tienda("FotoPH1", CFrame.new(18.4, ABAJO + 3.3, -30.8) * CFrame.Angles(math.pi / 2, math.rad(15), 0) * CFrame.new(0, -0.5, 0), true)
	contraPared("CuadroPH2", 12.5, ABAJO + 4.6, -30.07, ESTE, true) -- corrido por el usuario
	-- Repisa: reloj parado en medio, un candelero a cada lado, una foto y el cuadro encima, algo torcido.
	contraPared("Repisa", 36, ABAJO, -1, OESTE, true)
	for _, cosa in { { "RelojRepisaPH", -1 }, { "CandeleroPH", -4 }, { "CandeleroPH", 2 }, { "FotoPH2", 0.8 } } do
		local pos = Vector3.new(35.3, ABAJO + 4.71, cosa[2])
		tienda(cosa[1], CFrame.lookAt(pos, pos + OESTE), true)
	end
	local encima = contraPared("CuadroSalonPH", 36, ABAJO + 6, -1, OESTE, true)
	if encima then
		encima:PivotTo(encima:GetPivot() * CFrame.Angles(0, 0, math.rad(-3)))
	end
	-- Comedor (11.8.3, opción A del usuario, "cena servida"): la cena que nunca se recogió. Mesa larga en medio, a lo
	-- largo, con el mantel, los platos con fruta podrida, copas, candelabros, jarra y frutero; ocho sillas, una apartada y
	-- otra volcada hacia el vestíbulo; la araña encima. Vitrina con el juego de té en la pared de la cocina, aparador con
	-- lámpara y candelabro en la del vestíbulo, el reloj de pie parado en la esquina de delante y plantas muertas en el
	-- mirador, a los lados de la ventana.
	local MESA = Vector3.new(-25.5, ABAJO, -15)
	tienda("MesaComedorPH", CFrame.new(MESA) * CFrame.Angles(0, math.pi / 2, 0))
	local encimaMesa = ABAJO + 3.28 -- bajado por el usuario: a 3,51 lo de encima flotaba
	local function sobreMesa(nombre: string, x: number, z: number, giro: number?, alto: number?)
		tienda(nombre, CFrame.new(MESA.X + x, encimaMesa + (alto or 0), MESA.Z + z) * CFrame.Angles(0, giro or 0, 0), true)
	end
	-- Ocho sillas: { x, z } desde el centro de la mesa (13 de largo), mirándola. La de la cabecera de delante, apartada
	-- y torcida.
	for i, s in { { -3.4, -4.2 }, { -3.4, 0 }, { -3.4, 4.2 }, { 3.4, 0 }, { 3.4, 4.2 }, { 0, 7.3 }, { 0.6, -8.6 } } do
		local pos = MESA + Vector3.new(s[1], 0, s[2])
		local cf = CFrame.lookAt(pos, MESA + Vector3.new(0, 0, s[2] * 0.6))
		tienda("SillaComedorPH", if i == 7 then cf * CFrame.Angles(0, math.rad(-25), 0) else cf)
		if i == 7 then -- el de la apartada, movido por el usuario
			sobreMesa("PlatoPH", 0.86, -5.35, i, -0.1)
		else
			sobreMesa("PlatoPH", s[1] * 0.5, math.clamp(s[2], -5.4, 5.4), i)
		end
	end
	sobreMesa("PlatoPH", 1.84, -4.65, 8, -0.13) -- el de la silla volcada (movido por el usuario)
	-- Volcada de espaldas hacia el vestíbulo, como si alguien se hubiera levantado de golpe. No choca (sería una caja
	-- tumbada): queda a un lado, fuera del paso. El usuario la acercó a la mesa sin girarla.
	local giroVolcada = CFrame.lookAt(MESA + Vector3.new(5.6, 0, -4.6), MESA + Vector3.new(0, 0, -4.2)).Rotation
	tienda("SillaComedorPH", CFrame.new(MESA + Vector3.new(3.71, 0, -3.95)) * giroVolcada * CFrame.Angles(0, math.rad(15), 0)
		* CFrame.new(0, 1.16, 0) * CFrame.Angles(math.rad(90), 0, 0), true)
	-- Lo que había en la mesa: fruta podrida en los platos y en el frutero, copas, dos candelabros y la jarra.
	sobreMesa("FruteroPH", 0, 0)
	for k, f in { { "ManzanaPH", 0.25, 0.1 }, { "GranadaPH", -0.2, -0.15 }, { "ManzanaPH", -0.1, 0.3 }, { "ManzanaPH", 1.85, 4.1 },
		{ "GranadaPH", -1.6, -4.3 }, { "ManzanaPH", 0.2, 5.5 } } do
		sobreMesa(f[1], f[2], f[3], k, 0.08)
	end
	sobreMesa("CopasPH", 0.9, -1.4, 0.3)
	sobreMesa("CandelabroPH", 0, -2.6)
	sobreMesa("CandelabroPH", 0, 2.6)
	sobreMesa("JarraPH", -0.9, 1.4, 2)
	contraPared("VitrinaComedorPH", -19.5, ABAJO, 2.3, DELANTE)
	tienda("JuegoTePH", CFrame.new(-19.5, ABAJO + 3.95, 0.5), true)
	local aparador = contraPared("AparadorPH", -12.7, ABAJO, -5, OESTE)
	if aparador then
		local x = aparador:GetPivot().X
		tienda("LamparaAceitePH", CFrame.new(x, ABAJO + 3.66, -6.8), true)
		tienda("CandelabroPH", CFrame.new(x - 0.4, ABAJO + 3.66, -3.4), true)
		tienda("JarraPH", CFrame.new(x + 0.2, ABAJO + 3.66, -4.6) * CFrame.Angles(0, math.rad(-70), 0), true)
	end
	contraPared("RelojPiePH", -12.7, ABAJO, -30, OESTE)
	-- { maceta x, z, planta x, z, giro }, como las dejó el usuario.
	for _, m in { { -41.11, -4.96, -41.26, -5.11, -4.6 }, { -41.03, -15.05, -41.46, -14.95, -15.4 } } do
		tienda("MacetaPH", CFrame.new(m[1], ABAJO, m[2]), true)
		tienda("PlantaSeca", CFrame.new(m[3], ABAJO + 1.45, m[4]) * CFrame.Angles(0, m[5], 0), true)
	end
	-- Cocina (11.8.4, opción A del usuario, "cocina en L"): una cocina de los 50 abandonada a medio cocinar. Encimeras
	-- con alacenas en L, en el fondo (fregadero en medio, sin tapar la ventana) y en la pared del garaje; nevera y cocina
	-- de hierro, con la olla al fuego, junto al comedor; mesa con dos sillas en la pared del comedor y despensa con
	-- latas y tarros en la del pasillo. El centro, libre para correr.
	for i, z in { 23, 26, 29 } do -- pared del garaje
		contraPared("EncimeraCocina", -38.3, ABAJO, z, ESTE)
		contraPared(if i == 3 then "AlacenaAbierta" else "AlacenaCocina", -38.3, ABAJO + 6.3, z, ESTE, true)
	end
	contraPared("EncimeraCocina", -29.9, ABAJO, 32.3, DELANTE) -- fondo
	contraPared("AlacenaCocina", -29.9, ABAJO + 6.3, 32.3, DELANTE, true)
	local fregadero = contraPared("FregaderoCocina", -26.4, ABAJO, 32.3, DELANTE)
	contraPared("EncimeraAbierta", -22.9, ABAJO, 32.3, DELANTE)
	contraPared("AlacenaCocina", -22.9, ABAJO + 6.3, 32.3, DELANTE, true)
	if fregadero then -- platos sucios en la pila y dos de pie en el escurridor
		local f = fregadero:GetPivot()
		tienda("PlatoPH", f * CFrame.new(-0.5, 2.83, -0.1), true)
		tienda("PlatoPH", f * CFrame.new(-0.4, 2.93, -0.15) * CFrame.Angles(0.1, 1, 0), true)
		for _, x in { 1.35, 1.6 } do
			tienda("PlatoPH", f * CFrame.new(x, 4.1, 0.04) * CFrame.Angles(0, 0, math.pi / 2), true)
		end
	end
	-- A medio cocinar: la tabla con el cuchillo y la verdura a medio cortar, y la cesta de verdura en el rincón.
	local tablero = ABAJO + 3.5
	tienda("TablaPH", CFrame.new(-37, tablero, 23.4) * CFrame.Angles(0, math.pi / 2 + 0.2, 0), true)
	tienda("CuchilloPH", CFrame.new(-36.8, tablero + 0.2, 23.1) * CFrame.Angles(0, 0.4, 0) * CFrame.Angles(math.pi / 2, 0, 0), true)
	tienda("CebollaPH", CFrame.new(-37.2, tablero + 0.17, 23.9), true)
	tienda("BoniatoPH", CFrame.new(-37.4, tablero, 25.2) * CFrame.Angles(math.pi / 2, 0, 0.5) * CFrame.new(0, -0.12, 0), true)
	tienda("CestaPH", CFrame.new(-37.3, ABAJO, 31.4), true)
	for k, cosa in { { "CebollaPH", -0.4, 0.1 }, { "BoniatoPH", 0.2, -0.2 }, { "CebollaPH", 0.4, 0.25 } } do
		tienda(cosa[1], CFrame.new(-37.3 + cosa[2], ABAJO + 0.12, 31.4 + cosa[3]) * CFrame.Angles(0, k, 0), true)
	end
	-- Apartadas del rincón del comedor: la nevera allí estrechaba el vano (vanos anchos, pedido por el usuario).
	local hierro = contraPared("CocinaHierro", -38.3, ABAJO, 8, ESTE)
	contraPared("NeveraVieja", -38.3, ABAJO, 12.7, ESTE) -- de los 50, hecha aquí (pedido por el usuario: la oxidada no le gustaba)
	if hierro then
		tienda("OllaPH", hierro:GetPivot() * CFrame.new(-1, 3.42, 0.1), true)
		tienda("SartenPH", hierro:GetPivot() * CFrame.new(1.1, 3.42, 0) * CFrame.Angles(0, 0.5, 0), true)
	end
	-- Mesa de diario contra la pared del comedor, con una silla apartada y torcida; estante con latas encima.
	local mesa = contraPared("MesaCocinaPH", -19.5, ABAJO, 3.7, DETRAS)
	if mesa then
		local m = mesa:GetPivot()
		tienda("PlatoPH", m * CFrame.new(1.2, 3.84, 0.3), true)
		tienda("BoniatoPH", m * CFrame.new(1.2, 3.92, 0.3) * CFrame.Angles(math.pi / 2, 0, 0) * CFrame.new(0, -0.12, 0), true)
		tienda("LataOxidadaPH", m * CFrame.new(-1.8, 3.84, 0.9), true)
	end
	tienda("SillaCocinaPH", CFrame.lookAt(Vector3.new(-15.1, ABAJO, 6), Vector3.new(-19.5, ABAJO, 6)))
	tienda("SillaCocinaPH", CFrame.lookAt(Vector3.new(-24.6, ABAJO, 7.4), Vector3.new(-19.5, ABAJO, 6)) * CFrame.Angles(0, math.rad(35), 0))
	local estante = contraPared("EstanteCocinaPH", -19.5, ABAJO + 5.2, 3.7, DETRAS, true)
	if estante then
		local e = estante:GetPivot()
		tienda("LatasPH", e * CFrame.new(0, 1.45, 0.1), true)
		tienda("CebollaPH", e * CFrame.new(-0.3, 0.1, 0), true)
		tienda("CebollaPH", e * CFrame.new(0.25, 0.1, 0.1), true)
	end
	-- Despensa: latas, tarros y una olla por las baldas (a 0,44, 1,61, 2,77, 3,96, 5,26 y 6,85 del suelo), con huecos.
	local despensa = contraPared("DespensaPH", -12.7, ABAJO, 9.8, OESTE)
	if despensa then
		local d = despensa:GetPivot()
		for k, c in {
			{ "LataOxidadaPH", 1.2, 0.44 }, { "LataOxidadaPH", 1.8, 0.44 }, { "CestaPH", -1.3, 0.44 },
			{ "LatasPH", -1.8, 1.61 }, { "LatasPH", -0.9, 1.61 }, { "OllaPH", 0.6, 1.61 }, { "LatasPH", 1.9, 1.61 },
			{ "LatasPH", -1.5, 2.77 }, { "SartenPH", 1.2, 2.77 },
			{ "LataOxidadaPH", -1.9, 3.96 }, { "LataOxidadaPH", -1.3, 3.96 }, { "LatasPH", 0.9, 3.96 },
			{ "LatasPH", -0.4, 5.26 }, { "CestaPH", 0.8, 6.85 },
		} do
			tienda(c[1], d * CFrame.new(c[2], c[3], 0.1) * CFrame.Angles(0, (k % 3 - 1) * 0.3, 0), true)
		end
		-- Una lata volcada en la de en medio.
		tienda("LataOxidadaPH", d * CFrame.new(0.2, 3.96 + 0.25, 0) * CFrame.Angles(0, 0.7, math.pi / 2), true)
	end
	contraPared("TarroPH", -12.7, ABAJO, 14.5, OESTE)
	-- Dormitorio de abajo (11.8.6, opción A del usuario, "el cuarto de la abuela"): la cama de hierro (escondite, más
	-- abajo) contra la pared del fondo con una mesilla a cada lado: en la de la ventana, la lámpara (la luz del cuarto, en
	-- vestirDormitorio); en la otra, el vaso con la dentadura, las pastillas y el rosario. Alfombra de trapo y zapatillas
	-- al lado de la cama, silla con la ropa doblada y la rebeca entre la cama y la ventana del lado, cómoda con espejo y
	-- fotos junto a la entrada, y la mecedora con su manta en la pared del baño, mirando a la cama. El centro, libre.
	contraPared("MesillaPH", 31, ABAJO, 32.5, DELANTE)
	contraPared("MesillaPH", 37.4, ABAJO, 32.5, DELANTE)
	tienda("CosasMesilla", CFrame.new(37.4, ABAJO + 2.47, 31.5) * CFrame.Angles(0, 0.3, 0), true)
	tienda("AlfombraTrapo", CFrame.new(30, ABAJO + 0.075, 26.5) * CFrame.Angles(0, math.pi / 2, 0), true)
	tienda("Zapatillas", CFrame.new(30.7, ABAJO + 0.115, 26.9) * CFrame.Angles(0, math.pi / 2 + 0.2, 0), true) -- giradas por el usuario
	local silla = contraPared("SillaDormitorioPH", 38.5, ABAJO, 20.6, OESTE)
	if silla then -- la ropa, con el mismo CFrame que la silla (su caja empieza en el asiento)
		tienda("RopaSilla", silla:GetPivot() * CFrame.new(0, 2.32, 0.42), true)
	end
	contraPared("ComodaPH", 38.5, ABAJO, 8.6, OESTE)
	contraPared("EspejoPH", 38.5, ABAJO + 5.3, 8.6, OESTE, true)
	tienda("FotoPH1", CFrame.new(37.6, ABAJO + 4.85, 7.2) * CFrame.Angles(0, math.pi / 2 + 0.25, 0), true)
	tienda("FotoPH2", CFrame.new(37.7, ABAJO + 4.85, 10.2) * CFrame.Angles(0, math.pi / 2 - 0.2, 0), true)
	local mecedora = CFrame.lookAt(Vector3.new(24.8, ABAJO, 19), Vector3.new(34.2, ABAJO, 27.85))
	tienda("MecedoraPH", mecedora)
	tienda("MantaMecedora", mecedora * CFrame.new(0, 1.7, 0.34), true)
	-- Pasillo (11.8.5, opción A del usuario, "todo lleva al sótano"): la alfombra larga, recta hasta la puerta del
	-- sótano, que se ve desde la entrada; retratos de familia (con las caras rayadas) en fila a los dos lados de la
	-- puerta, la mesita con el teléfono de pared junto a ella y un paragüero. Los lados, casi vacíos. La cadena, los
	-- arañazos, la sangre y la bombilla, en vestirPasillo.
	local alfombra = tienda("AlfombraLarga", CFrame.new(0, ABAJO, 20.6), true)
	if alfombra then -- estirada a lo largo (de 13,4 a 20), como la mesa del comedor
		local k = 20 / (alfombra:GetAttribute("Tam") :: Vector3).Z
		for _, pieza in alfombra:GetDescendants() do
			if pieza:IsA("BasePart") then
				pieza.Size *= Vector3.new(1, 1, k)
				pieza.Position = Vector3.new(pieza.Position.X, pieza.Position.Y, 20.6 + (pieza.Position.Z - 20.6) * k)
			end
		end
	end
	for i, x in { -10, -7.2, -4.4, 4.4, 7.2, 10 } do
		local retrato = contraPared(if i % 3 == 1 then "CuadroFamiliaPH" elseif i % 3 == 2 then "CuadroFamiliaPH2" else "CuadroFamiliaPH3",
			x, ABAJO + 5.9 + (i % 2) * 0.35, 32.3, DELANTE, true)
		if retrato then -- cada uno algo torcido
			retrato:PivotTo(retrato:GetPivot() * CFrame.Angles(0, 0, math.rad(({ -4, 2, -1, 5, -2, 9 })[i])))
		end
	end
	contraPared("MesitaPH", -6.2, ABAJO, 32.3, DELANTE)
	contraPared("TelefonoPH", -6.2, ABAJO + 3.3, 32.3, DELANTE, true)
	contraPared("Paraguero", 11.3, ABAJO, 29.5, OESTE, true)
	-- Trastero (11.8.5): lleno. En la pared del salón, la escoba y el cubo junto a la entrada, una estantería de madera
	-- con trastos y la maleta encima, y cajas en el rincón; en la del baño, la estantería de metal y un cajón con una caja
	-- encima, y más cajas junto al armario (escondite, más abajo). El centro, libre.
	contraPared("EscobaPH", 12.7, ABAJO, 6.8, ESTE, true)
	tienda("CuboPH", CFrame.new(13.6, ABAJO, 8.8) * CFrame.Angles(0, 0.6, 0))
	local estanteria = contraPared("DespensaPH", 16.3, ABAJO, 5.7, DETRAS)
	if estanteria then -- baldas a 0,44, 1,61, 2,77, 3,96, 5,26 y 6,85 del suelo (la despensa de la cocina)
		local e = estanteria:GetPivot()
		for k, c in {
			{ "CestaPH", -1.4, 0.44 }, { "LatasPH", 1.3, 0.44 }, { "EnciclopediaPH", -0.8, 1.61 }, { "LatasPH", 1.5, 1.61 },
			{ "OllaPH", -1.2, 2.77 }, { "CestaPH", 1.1, 3.96 }, { "LataOxidadaPH", -1.6, 5.26 }, { "LataOxidadaPH", -1.1, 5.26 },
		} do
			tienda(c[1], e * CFrame.new(c[2], c[3], 0) * CFrame.Angles(0, k * 0.5, 0), true)
		end
		local maleta = tienda("MaletaPH", e * CFrame.new(0, 8.5, 0.1), true)
		if maleta then
			maleta:ScaleTo(0.85)
		end
	end
	tienda("CajaCartonPH", CFrame.new(20.2, ABAJO, 7) * CFrame.Angles(0, 0.08, 0))
	tienda("CajaCartonPH", CFrame.new(20.1, ABAJO + 1.7, 7.2) * CFrame.Angles(0, -0.3, 0), true)
	local metal = contraPared("EstanteriaMetalPH", 15.3, ABAJO, 18.3, DELANTE)
	if metal then -- baldas a 0,5, 2,6, 4,6, 6,6 y 8,6 (arriba del todo); las cajas, giradas para que quepan de fondo
		local e = metal:GetPivot()
		for k, c in {
			{ "CajonPH", 0, 0.5, 0 }, { "CestaPH", -1.2, 2.6, 0.4 }, { "LatasPH", 0.6, 2.6, 0 }, { "LataOxidadaPH", 1.5, 2.6, 0 },
			{ "CajaCartonPH", -0.6, 4.6, math.pi / 2 }, { "EnciclopediaPH", 1.3, 4.6, 0.2 }, { "OllaPH", -1.1, 6.6, 0 },
			{ "LataOxidadaPH", 0.9, 6.6, 0 }, { "CajaCartonPH", 0.3, 8.6, math.pi / 2 + 0.15 },
		} do
			tienda(c[1], e * CFrame.new(c[2], c[3], 0) * CFrame.Angles(0, c[4] + k * 0.05, 0), true)
		end
	end
	local cajon = contraPared("CajonPH", 19.45, ABAJO, 18.3, DELANTE)
	if cajon then
		tienda("CajaCartonPH", cajon:GetPivot() * CFrame.new(0.4, 1.57, 0) * CFrame.Angles(0, math.pi / 2 + 0.2, 0), true)
	end
	contraPared("CajaCartonPH", 21.3, ABAJO, 15, OESTE)
	-- Baño (11.8.5, como estaba): la bañera de patas contra la pared del trastero con la cortina corrida (no se ve qué
	-- hay dentro), el váter de cisterna alta, el lavabo de pie con el espejo roto de un golpe, el botiquín tirado y
	-- toallas sucias en el suelo. Las grietas y la sangre, en vestirPasillo.
	tienda("Banera", CFrame.lookAt(Vector3.new(16, ABAJO, 21.2), Vector3.new(15, ABAJO, 21.2)))
	-- La cortina empieza a 1,4 del suelo (dentro de la bañera): su pivote es su punto más bajo.
	tienda("CortinaDucha", CFrame.lookAt(Vector3.new(16, ABAJO + 1.4, 21.2), Vector3.new(16, ABAJO + 1.4, 22.2)), true)
	contraPared("VaterViejo", 12.7, ABAJO, 28, ESTE)
	contraPared("LavaboPie", 21.3, ABAJO, 31, OESTE)
	contraPared("EspejoPH", 21.3, ABAJO + 4.6, 30.9, OESTE, true)
	tienda("BotiquinPH", CFrame.new(19.4, ABAJO, 28.6) * CFrame.Angles(0, 0.5, 0), true)
	tienda("Toallas", CFrame.new(15.2, ABAJO, 24.6) * CFrame.Angles(0, 0.4, 0), true)
	-- Lavadero: el armario y el enchufe del móvil, más abajo; lo demás, en vestirGaraje (11.8.12).
	-- Arriba: dormitorio grande y habitación del rico se amueblan después de Separar (11.8.8 y 11.8.9).
	-- Aquí solo quedan los escondites, más abajo.
	-- Cuarto de los niños: se amuebla después de Separar (11.8.10, vestirNinos); aquí solo el escondite, más abajo.
	for _, cuadro in {
		-- los del vestíbulo y el salón son de Poly Haven (arriba)
		{ -25, ARRIBA, 8.4, -Vector3.zAxis },
	} do
		local pos = Vector3.new(cuadro[1], cuadro[2] + 4.5, cuadro[3])
		mueble("Cuadro", CFrame.lookAt(pos, pos + cuadro[4]))
	end

	-- Objetos sueltos por la casa (provisional: luego saldrán al azar con la semilla de la partida).
	for _, o in {
		{ "Pila", Vector3.new(-29.5, ABAJO + 3.7, 31.3) }, { "Lata", Vector3.new(-23, ABAJO + 3.7, 31.3) }, -- encimeras
		{ "Botella", Vector3.new(-22, ABAJO + 3.7, 31.3) }, { "Carrete", Vector3.new(-30.5, ABAJO + 3.7, 31.3) }, -- encimeras
		{ "Pila", Vector3.new(25, ARRIBA + 0.2, -18) }, { "Hacha", Vector3.new(-19, ABAJO + 0.2, 39.5) }, -- en el lavadero
		{ "Hacha", Vector3.new(-33, 0.2, -39.8) }, -- junto al caballete
	} do
		table.insert(Mapa.objetos, { tipo = o[1], cf = CFrame.new(o[2]) * CFrame.Angles(0, math.rad(#Mapa.objetos * 37), 0) })
	end
	-- Lo pesado, delante de la casa.
	for _, pesado in {
		{ "Tronco", CFrame.new(10, 0.7, -47) * CFrame.Angles(0, 0.4, 0) }, { "Tronco", CFrame.new(-10, 0.7, -48) },
		{ "Tablon", CFrame.new(14, 0.15, -45) * CFrame.Angles(0, -0.3, 0) }, { "Bidon", CFrame.new(-14, 1.2, -46) },
		{ "Bidon", CFrame.new(-45.6, ABAJO + 1.2, 38.4) }, -- en el cobertizo, en la esquina de la entrada
		-- el motor (Mapa.motorSuelto) lo pone Llegada con el coche destrozado
	} do
		table.insert(Mapa.pesados, { tipo = pesado[1], cf = pesado[2] })
	end

	-- Escondites: las camas de los dos dormitorios y la de los niños, y los armarios (dormitorios, trastero y lavadero).
	cama(Vector3.new(34.2, ABAJO, 27.85), DETRAS, 1, "CamaHierroPH", "ColchaCama", 4, 8.8) -- la de hierro de la abuela
	armario(Vector3.new(24, ABAJO + 4, 12), ESTE)
	armario(Vector3.new(20, ABAJO + 4, 12), OESTE) -- trastero
	armario(Vector3.new(-21, ABAJO + 4, 43), DELANTE) -- lavadero
	cama(DORMITORIO_GRANDE.cama, DETRAS, 1, "CamaDoselPH", nil, 6.7, 9.2) -- la gótica con dosel de los dueños
	armario(Vector3.new(35, DORMITORIO_GRANDE.suelo + 4, 7), DELANTE)
	cama(NINOS.cama, Vector3.zAxis, -1, "CamaNino", nil, 4.27, 7.05) -- la cama pequeña del oeste en el cuarto de los niños

	-- Luces (las enciende el generador) y salas por las que ronda el Golpeador.
	for _, sala in {
		Vector3.new(0, ABAJO, -26), Vector3.new(0, ABAJO, 4.5), Vector3.new(0, ABAJO, 22), Vector3.new(25, ABAJO, -15),
		Vector3.new(28, ABAJO, 12), Vector3.new(-30, ABAJO, -26), Vector3.new(-30, ABAJO, 11), Vector3.new(-19, ABAJO, 39),
		Vector3.new(0, ARRIBA, 18), Vector3.new(25, ARRIBA, -14), Vector3.new(-25, ARRIBA, 21),
	} do
		table.insert(Mapa.salas, sala)
	end
	for _, luz in {
		Vector3.new(0, ABAJO, 4.5), Vector3.new(25, ABAJO, -20), -- en el salón, además, la lámpara de pie; en el pasillo, la bombilla
		Vector3.new(17, ABAJO, 12), Vector3.new(17, ABAJO, 26), -- en el comedor, la araña (abajo); en el dormitorio, la lámpara de la mesilla
		Vector3.new(-25.5, ABAJO, 18), Vector3.new(-19, ABAJO, 39), Vector3.new(42, ABAJO, -36),
		Vector3.new(0, ARRIBA, 18), Vector3.new(25, ARRIBA, -14), -- la del rico, en su escritorio; la de los niños, en su mesilla
		Vector3.new(42, ARRIBA, -36), -- en la escalera del desván, la bombilla (vestirDesvan)
	} do
		lampara(luz + Vector3.new(0, ALTO - 0.3, 0))
	end
	arana(Vector3.new(0, ABAJO + 12, -21), ARRIBA + ALTO - BAJO_TECHO) -- en el hueco del vestíbulo, algo baja
	-- Sobre la mesa del comedor, colgada de su barra (llega al techo).
	arana(Vector3.new(-25.5, ABAJO + ALTO - 5.3, -15), ABAJO + ALTO - BAJO_TECHO, "AranaComedorPH", Vector3.new(0, 1.3, -1.5), 24)


	MapaAnexos.construirCobertizo()
	MapaAnexos.construirCaballete()
	MapaAnexos.construirSotano()
	MapaAnexos.construirFinal() -- reja, palanca y trampilla del sótano; cadenas, pistola y cerillas (12.2)
	MapaAnexos.construirGaraje()
	Fachada.vestir({ ABAJO = ABAJO, ARRIBA = ARRIBA, ALTO = ALTO, TEJADO = TEJADO, TORRE = TORRE })
	-- Mecedora en el porche, mirando al camino (no choca: el porche es para correr).
	tienda("Mecedora", CFrame.new(9, ABAJO, -37.5) * CFrame.Angles(0, math.rad(20), 0), true)
	-- Enchufe del móvil en el lavadero: placa, repisa donde se deja el móvil y lucecita de carga.
	local enchufe = Instance.new("Model")
	enchufe.Name = "Enchufe"
	enchufe.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	-- Delante del azulejo del lavadero (su cara, en x = -12,62). Con el de Blender (EnchufeViejo, en vestirGaraje), la
	-- placa y la repisa no se ven; la lucecita sí, sobre su placa.
	local placa = bloque("Placa", Vector3.new(0.15, 0.8, 0.6), CFrame.new(-12.7, ABAJO + 2.6, 41), Color3.fromRGB(190, 185, 170),
		Enum.Material.SmoothPlastic, enchufe)
	local repisa = bloque("Repisa", Vector3.new(1.1, 0.2, 1.4), CFrame.new(-13.17, ABAJO + 1.9, 41), COLOR.Mueble, nil, enchufe)
	bloque("Luz", Vector3.new(0.1, 0.12, 0.12), CFrame.new(-12.79, ABAJO + 2.75, 41.2), COLOR.Oscuro, Enum.Material.SmoothPlastic,
		enchufe)
	if MUEBLES.EnchufeViejo then
		placa.Transparency = 1
		repisa.Transparency = 1
	end
	mando(CFrame.new(-13.5, ABAJO + 2.4, 41), enchufe)
	enchufe:SetAttribute("Sitio", CFrame.new(-13.17, ABAJO + 2.15, 41)) -- donde se queda el móvil cargando
	CollectionService:AddTag(enchufe, "Enchufe")
	enchufe.Parent = casa

	CollectionService:AddTag(casa:FindFirstChild("Piso") :: BasePart, "EnMapa")
	casa.Parent = mapa
end


-- Para el pueblo (Pueblo*.luau, por Lugares): las mismas ayudas que usa la casa. `Mapa.conPadre(padre, fn)` hace que
-- todo lo que se cree dentro de `fn` (muebles, manchas, adornos) cuelgue de `padre` en vez de la casa.
function Mapa.conPadre(padre: Instance, fn: () -> ())
	local antes = casa
	casa = padre :: any
	local ok, err = pcall(fn)
	casa = antes
	if not ok then
		error(err, 0)
	end
end
Mapa.mueble = tienda
Mapa.contraPared = contraPared
Mapa.mancha = mancha
Mapa.adorno = adorno
Mapa.variante = variante
Mapa.SANGRE = SANGRE
Mapa.MUEBLES = MUEBLES
-- Un pino como los del bosque (tronco que choca y su modelo de Piezas) en (x, z), colgado de `padre`.
Mapa.arbol = MapaBosque.arbol

-- Rendimiento (14.4, docs/sistemas/rendimiento.md). Con el mapa ya hecho: nadie usa Touched en el mapa (ni servidor ni
-- cliente), así que ninguna pieza necesita CanTouch: menos contactos que vigilar al andar por el suelo y los troncos.
local function aligerar(mapa: Folder)
	for _, d in mapa:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanTouch = false
		end
	end
end

-- Mapa por partes (StreamingEnabled). Se enciende en Studio, en la propiedad StreamingEnabled del Workspace (no se puede
-- cambiar con el juego en marcha): con ella apagada esto no hace nada. Lo que el cliente necesita siempre y entero:
--   La casa (Persistent): sustos, efectos, detalles, el incendio y la huida la recorren o buscan cosas en ella.
--   Los árboles que se talan (Persistent): el mapa del móvil los pinta y los borra cuando dejan de existir.
--   El plano del móvil: copias invisibles de las piezas "EnMapa" de fuera de la casa, en un modelo Persistent; si no,
--     el móvil borraría el pueblo y la granja del mapa al alejarse (MovilUi quita lo que desaparece).
-- Los edificios del pueblo, de lejos, como una malla simple (LevelOfDetail): que se vea su silueta al fondo.
local POR_PARTES = workspace.StreamingEnabled
local SILUETA = { "^Casa", "^Tienda$", "^Iglesia$", "^Cripta$", "^Caseta" }

local function porPartes(mapa: Folder)
	if not POR_PARTES or not casa then
		return
	end
	local fijo = Enum.ModelStreamingMode.Persistent
	casa.ModelStreamingMode = fijo
	local bosque = mapa:FindFirstChild("Bosque")
	local arboles = bosque and bosque:FindFirstChild("Arboles")
	for _, arbol in (if arboles then arboles:GetChildren() else {}) do
		if arbol:IsA("Model") then
			arbol.ModelStreamingMode = fijo
		end
	end
	local plano = Instance.new("Model")
	plano.Name = "Plano"
	plano.ModelStreamingMode = fijo
	for _, pieza in CollectionService:GetTagged("EnMapa") do
		if pieza:IsA("BasePart") and pieza:IsDescendantOf(mapa) and not pieza:IsDescendantOf(casa) then
			local copia = Instance.new("Part")
			copia.Name = pieza.Name
			copia.Anchored = true
			copia.Size = pieza.Size
			copia.CFrame = pieza.CFrame
			copia.Color = pieza.Color
			copia.Transparency = 1
			copia.CanCollide, copia.CanQuery, copia.CanTouch, copia.CastShadow = false, false, false, false
			copia.Parent = plano
			CollectionService:RemoveTag(pieza, "EnMapa")
			CollectionService:AddTag(copia, "EnMapa")
		end
	end
	plano.Parent = mapa
	local lugares = mapa:FindFirstChild("Lugares")
	local pueblo = lugares and lugares:FindFirstChild("Pueblo")
	for _, m in (if pueblo then pueblo:GetChildren() else {}) do
		for _, patron in SILUETA do
			if m:IsA("Model") and string.find(m.Name, patron) then
				-- Con pcall: desde nov. 2026 Roblox no deja a los scripts tocar LevelOfDetail (pide permiso de plugin) y el
				-- error paraba el arranque entero del servidor. Sin él, el pueblo lejano se ve igual, solo cuesta algo más.
				pcall(function()
					m.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh
				end)
				break
			end
		end
	end
end

-- Las zonas Debajo deben quedarse dentro de su sala: si una cruzase una pared, un bicho podría oler y gatear a por
-- quien está al otro lado (Caza lo mira con rayos, pero mejor que no pase). Avisa en la Salida si dentro de alguna
-- (algo encogida, para no contar el suelo, las patas ni el tablero, que la tocan) hay algo que choca que no sea una
-- caja Choque de mueble o silla.
local function revisarDebajo()
	local filtro = OverlapParams.new()
	filtro.RespectCanCollide = true
	for _, zona in CollectionService:GetTagged("Debajo") do
		if zona:IsA("BasePart") then
			filtro.FilterDescendantsInstances = { zona }
			for _, pieza in workspace:GetPartBoundsInBox(zona.CFrame, zona.Size - Vector3.new(0.8, 0.8, 0.8), filtro) do
				if pieza.Name ~= "Choque" then
					warn(`[Mapa] la zona Debajo de {zona:GetAttribute("Mueble")} cruza {pieza:GetFullName()}`)
				end
			end
		end
	end
end

function Mapa.start()
	local mapa = workspace:WaitForChild("Mapa")
	MapaBosque.construirBosque(mapa)
	construirCasa(mapa)
	Lugares.construir(mapa, Mapa)
	local quedan = Separar.caras(mapa) -- que no parpadeen dos caras en el mismo plano
	if quedan > 0 then
		warn(`[Mapa] quedan {quedan} caras que parpadean`)
	end
	-- El papel, los suelos y lo abandonado, después de Separar: van pegados a las paredes con su grosor final.
	MapaSalas.vestirParedes()
	MapaSalas.vestirSuelos()
	MapaSalas.vestirVestibulo()
	MapaSalas.vestirSalon()
	MapaSalas.vestirComedor()
	MapaSalas.vestirCocina()
	MapaSalas.vestirPasillo()
	MapaSalas.vestirDormitorio()
	MapaSalas.vestirGaleria()
	MapaSalas.vestirDormitorioGrande()
	MapaSalas.vestirHabitacionRico()

	MapaSalas.vestirNinos()
	MapaSalas.vestirDesvan()

	MapaSalas.vestirGaraje()
	MapaSalas.vestirSotano()
	MapaSalas.abandonar()
	aligerar(mapa)
	porPartes(mapa)
	revisarDebajo()
	-- Donde se aparece: invisible y encima del suelo de la casa (a ras de él, parpadeaba con el suelo). Justo al entrar,
	-- mirando a la escalera y a la araña (11.8.1, elegido por el usuario).
	local aparicion = Instance.new("SpawnLocation")
	aparicion.Anchored = true
	aparicion.Size = Vector3.new(6, 0.2, 6)
	aparicion.CFrame = CFrame.lookAt(Vector3.new(0, ABAJO + 0.2, -28), Vector3.new(0, ABAJO + 0.2, 0))
	aparicion.Transparency = 1
	aparicion.CanCollide = false
	aparicion.Neutral = true
	aparicion.Duration = 0
	aparicion.Parent = mapa

	-- Muestra del modelo 3D del Golpeador en la hierba delante del porche, mirando a la casa: solo en modo edición
	-- (VER MAPA del plugin), para verlo y moverlo a mano (pedido por el usuario). En la partida no sale.
	if not game:GetService("RunService"):IsRunning() then
		local muestra = Bichos3D.copia("Golpeador", CFrame.lookAt(Vector3.new(6, 0, -50), Vector3.new(6, 0, 0)))
		if muestra then
			muestra.Name = "MuestraGolpeador"
			muestra.Parent = mapa
		end
	end
end

return Mapa
