-- Genera el mapa por código con bloques grises (el arte llega al final): suelo, bosque de troncos, camino y la casa.
-- La casa (x -39..39, z -33..33, más la torre, el mirador, el lavadero y el garaje): dos plantas (ver construirCasa).
-- Salas con llave (Llaves): sótano, garaje, desván y habitación del rico. La granja, el aserradero, la torre y el
-- pueblo, en Lugares.
-- Lo que se toca lleva una etiqueta de CollectionService y su estado en atributos (lo maneja Casa o Muerte):
--   "Ventana": cristal y persiana. "Puerta": hoja que gira en la bisagra. "Escondite": armarios y camas.
-- Medidas en studs: suelo de abajo arriba en y = 1, el de arriba en y = 14; paredes de 12 de alto.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Piezas = require(ReplicatedStorage.Shared.Piezas)
local Separar = require(ServerScriptService:WaitForChild("Comun").Separar)
local Fachada = require(script.Parent.Fachada)
local Lugares = require(script.Parent.Lugares)

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

local ABAJO, ARRIBA, ALTO = 1, 14, 12
-- Los techos de yeso de cada sala, este tanto por debajo del suelo de arriba (Separar lo engorda 0,15 y los tapaba).
local BAJO_TECHO = 0.2
-- Tejado a dos aguas con la cumbrera a lo largo de x en z = 0: sube `pendiente` por stud desde el alero (|z| = `alero`,
-- a y = 27). El Trepador anda por encima (sus medidas, en Trepador).
local TEJADO = { pendiente = 9 / 24, alero = 34.5 }

local COLOR = {
	Suelo = Color3.fromRGB(70, 64, 44), -- suelo de bosque con hojarasca (LeafyGrass)
	Camino = Color3.fromRGB(78, 72, 64),
	Tronco = Color3.fromRGB(62, 50, 42), -- corteza, como la de los pinos (shared/Piezas)
	Muro = Color3.fromRGB(116, 106, 90), -- yeso sucio de las paredes de dentro
	Fachada = Color3.fromRGB(84, 68, 54), -- tablas viejas de las paredes de fuera
	Marco = Color3.fromRGB(58, 44, 34), -- marcos de puertas y ventanas, porche
	Piso = Color3.fromRGB(78, 60, 46),
	Mueble = Color3.fromRGB(74, 54, 40),
	Oscuro = Color3.fromRGB(45, 43, 42),
	Cristal = Color3.fromRGB(140, 160, 170),
	Lampara = Color3.fromRGB(255, 214, 160),
}

-- Puntos de cada sala por los que el Golpeador ronda cuando no ve a nadie.
Mapa.salas = {} :: { Vector3 }
-- Dónde empiezan los objetos sueltos (Mochila) y las cosas pesadas (Cargar).
Mapa.objetos = {} :: { { tipo: string, cf: CFrame } }
Mapa.pesados = {} :: { { tipo: string, cf: CFrame } }
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

-- Pone un mueble del Creator Store (ServerStorage.Muebles: limpios de scripts, escalados, con el frente hacia -Z y el
-- pivote abajo en el centro; su tamaño en el atributo Tam) en `cf`. Solo se ve: choca una caja invisible un poco más
-- pequeña, que no tapa la vista de los bichos. Sin la carpeta (lugar sin Rojo) no pone nada.
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
		local choque = bloque("Choque", tam * Vector3.new(0.9, 1, 0.9), cf * CFrame.new(0, tam.Y / 2, 0))
		choque.Transparency = 1
		choque.CanQuery = false
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

-- Cobertizo suelto detrás del garaje (x -54..-44, z 37..45.5) con el generador; se entra por el este (z 39..44).
local function construirCobertizo()
	local x1, x2, z1, z2, alto = -54, -44, 37, 45.5, 9
	CollectionService:AddTag(bloque("Piso", Vector3.new(x2 - x1, 1, z2 - z1), CFrame.new((x1 + x2) / 2, 0.5, (z1 + z2) / 2), COLOR.Piso),
		"EnMapa")
	for _, z in { z1, z2 } do
		Fachada.pared(bloque("Muro", Vector3.new(x2 - x1 + 1, alto, 1), CFrame.new((x1 + x2) / 2, ABAJO + alto / 2, z)),
			Vector3.new(0, 0, if z == z1 then -1 else 1))
	end
	Fachada.pared(bloque("Muro", Vector3.new(1, alto, z2 - z1), CFrame.new(x1, ABAJO + alto / 2, (z1 + z2) / 2)), Vector3.new(-1, 0, 0))
	for _, pared in {
		bloque("Muro", Vector3.new(1, alto, 39 - z1), CFrame.new(x2, ABAJO + alto / 2, (z1 + 39) / 2)), -- este, con la entrada
		bloque("Muro", Vector3.new(1, alto, z2 - 44), CFrame.new(x2, ABAJO + alto / 2, (44 + z2) / 2)),
		bloque("Muro", Vector3.new(1, alto - 7, 5), CFrame.new(x2, ABAJO + 7 + (alto - 7) / 2, 41.5)),
	} do
		Fachada.pared(pared, Vector3.new(1, 0, 0))
	end
	Fachada.chapa(bloque("Techo", Vector3.new(x2 - x1 + 2, 0.6, z2 - z1 + 1.5), CFrame.new((x1 + x2) / 2, ABAJO + alto + 0.3, (z1 + z2) / 2),
		COLOR.Oscuro, Enum.Material.CorrodedMetal))
	lampara(Vector3.new(-49, ABAJO + alto - 0.4, 41))

	-- El generador mira al este (a la entrada): la cuerda sale por ese lado.
	local gen = Instance.new("Model")
	gen.Name = "Generador"
	gen.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	-- Contra la pared del fondo (11.8.12, opción B elegida por el usuario): el de Poly Haven, con el frente a la entrada.
	-- Los bloques que chocan (cuerpo y escape) son invisibles si está la malla; la cuerda y el indicador, en su frente.
	local base = CFrame.new(-51.6, ABAJO, 41.25)
	local function trozo(nombre: string, tamano: Vector3, offset: CFrame, color: Color3, material: Enum.Material?)
		return bloque(nombre, tamano, base * offset, color, material or Enum.Material.Metal, gen)
	end
	local cuerpo = trozo("Cuerpo", Vector3.new(3.2, 3.3, 4.7), CFrame.new(0, 1.65, 0), Color3.fromRGB(96, 40, 32))
	local escape = trozo("Escape", Vector3.new(0.35, 0.4, 0.35), CFrame.new(-0.6, 3.2, -1.9), COLOR.Oscuro)
	trozo("Cuerda", Vector3.new(0.25, 0.25, 0.9), CFrame.new(1.75, 1.6, -1.2), COLOR.Oscuro, Enum.Material.Plastic)
	-- Indicador de gasolina en el frente: el cliente sube y baja el Nivel.
	trozo("Indicador", Vector3.new(0.1, 1.2, 0.3), CFrame.new(1.72, 2.1, 1.5), Color3.fromRGB(30, 28, 26))
	trozo("Nivel", Vector3.new(0.1, 1, 0.18), CFrame.new(1.78, 2.1, 1.5), Color3.fromRGB(170, 140, 60), Enum.Material.SmoothPlastic)
	mando(base * CFrame.new(3, 2.4, 0), gen)
	gen:SetAttribute("Tapon", base * CFrame.new(0, 3.6, 0.8)) -- donde cae la gasolina
	-- La malla, suelta dentro del modelo: TrabajoVista hace temblar las piezas que cuelgan de él.
	local malla = tienda("GeneradorPH", base * CFrame.Angles(0, -math.pi / 2, 0), true)
	if malla then
		for _, pieza in malla:GetChildren() do
			pieza.Parent = gen
		end
		malla:Destroy()
		cuerpo.Transparency = 1
		escape.Transparency = 1
	end
	CollectionService:AddTag(gen, "Generador")
	gen.Parent = casa
end

-- Caballete para serrar troncos, a un lado de la entrada. Lo serrado sale al lado, hacia la casa.
local function construirCaballete()
	local modelo = Instance.new("Model")
	modelo.Name = "Caballete"
	modelo.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local base = CFrame.new(-35, 0, -43)
	-- Burro de serrar troncos (pedido por el usuario: antes eran "3 palos"): dos aspas en X que arriba hacen de cuna
	-- para el tronco, unidas por la viga en el cruce, con un tirante en diagonal, pernos y serrín alrededor.
	local madera = Color3.fromRGB(92, 72, 54)
	for _, x in { -2.2, 2.2 } do
		for _, lado in { 1, -1 } do
			bloque("Pata", Vector3.new(0.45, 5.4, 0.45), base * CFrame.new(x, 2.5, 0) * CFrame.Angles(math.rad(30 * lado), 0, 0), madera,
				Enum.Material.Wood, modelo)
		end
		local perno = adorno(Vector3.new(1.1, 0.25, 0.25), base * CFrame.new(x, 2.5, 0), Enum.Material.Metal)
		perno.Shape = Enum.PartType.Cylinder
		perno.Color = COLOR.Oscuro
	end
	bloque("Viga", Vector3.new(5.4, 0.45, 0.45), base * CFrame.new(0, 2.5, 0), madera, Enum.Material.Wood, modelo)
	adorno(Vector3.new(0.3, 0.3, 5.2), base * CFrame.new(0, 1.4, 0.55) * CFrame.Angles(0, math.rad(90), math.rad(-22)), Enum.Material.Wood).Color =
		madera
	-- Serrín y rodajas cortadas en el suelo, al lado de donde caen los tablones.
	for i, s in { { 0.6, 1.8, 1.6 }, { -1.5, 2.6, 1.1 }, { 1.8, -1.2, 0.9 } } do
		local serrin = adorno(Vector3.new(0.05, s[3], s[3] * 1.3), base * CFrame.new(s[1], 0.03, s[2]) * CFrame.Angles(0, i, math.pi / 2),
			Enum.Material.Sand)
		serrin.Shape = Enum.PartType.Cylinder
		serrin.Color = Color3.fromRGB(104, 84, 62)
		serrin.CastShadow = false
	end
	for _, r in { { -2.8, 1.6, 0.4 }, { 3.1, 0.9, -0.3 } } do
		local rodaja = adorno(Vector3.new(0.5, 1.3, 1.3), base * CFrame.new(r[1], 0.25, r[2]) * CFrame.Angles(0, r[3], math.pi / 2),
			Enum.Material.Wood)
		rodaja.Shape = Enum.PartType.Cylinder
		rodaja.Color = Color3.fromRGB(120, 96, 70)
	end
	-- Sierra de arco apoyada en una pata: arco de madera, hoja de metal y los dos brazos.
	local sierra = base * CFrame.new(-2.75, 1.6, -1.4) * CFrame.Angles(math.rad(-20), math.rad(90), 0)
	adorno(Vector3.new(3.2, 0.12, 0.05), sierra, Enum.Material.Metal).Color = Color3.fromRGB(110, 108, 104)
	adorno(Vector3.new(3.2, 0.18, 0.18), sierra * CFrame.new(0, 1.3, 0), Enum.Material.Wood).Color = madera
	for _, x in { -1.5, 1.5 } do
		adorno(Vector3.new(0.18, 1.5, 0.18), sierra * CFrame.new(x, 0.65, 0), Enum.Material.Wood).Color = madera
	end
	mando(base * CFrame.new(0, 3, 0), modelo)
	modelo:SetAttribute("Encima", base * CFrame.new(0, 4, 0)) -- donde se pone el tronco
	modelo:SetAttribute("Salida", base * CFrame.new(0, 0.4, 2.4)) -- donde caen los tablones
	CollectionService:AddTag(modelo, "Caballete")
	CollectionService:AddTag(modelo:FindFirstChild("Viga") :: BasePart, "EnMapa")
	modelo.Parent = casa
end

-- Banco del taller (Taller): tablero con patas y un tornillo de banco. `cf` = el centro del tablero a ras del suelo,
-- mirando hacia donde se pone el que trabaja; lo hecho que es pesado sale ahí delante (Salida).
local function banco(nombre: string, cf: CFrame)
	local modelo = Instance.new("Model")
	modelo.Name = "Banco" .. nombre
	modelo.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	bloque("Tablero", Vector3.new(8, 0.5, 2.6), cf * CFrame.new(0, 3.25, 0), COLOR.Mueble, Enum.Material.Wood, modelo)
	for _, x in { -3.6, 3.6 } do
		bloque("Pata", Vector3.new(0.5, 3, 2.2), cf * CFrame.new(x, 1.5, 0), COLOR.Oscuro, Enum.Material.Wood, modelo)
	end
	bloque("Tornillo", Vector3.new(0.8, 0.6, 1), cf * CFrame.new(3, 3.8, -0.9), Color3.fromRGB(70, 72, 76), Enum.Material.Metal, modelo)
	bloque("Martillo", Vector3.new(1.4, 0.2, 0.3), cf * CFrame.new(-1.5, 3.6, 0.3) * CFrame.Angles(0, 0.4, 0), COLOR.Oscuro,
		Enum.Material.Metal, modelo)
	mando(cf * CFrame.new(0, 3.6, -1.6), modelo)
	modelo:SetAttribute("Banco", nombre)
	modelo:SetAttribute("Salida", cf * CFrame.new(0, 0.6, -3.4))
	CollectionService:AddTag(modelo, "Banco")
	modelo.Parent = casa
end

-- Tu coche, destrozado y encerrado en el garaje (Coche lo arregla). Mira hacia -z (al portón); `base` = el centro a ras
-- del suelo. Las piezas que faltan (motor, ruedas de delante, batería, radiador) están puestas pero invisibles: Coche
-- las enseña al montarlas. Los huecos de las ruedas de delante, sobre ladrillos.
local function construirCoche(base: CFrame)
	local coche = Instance.new("Model")
	coche.Name = "Coche"
	coche.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	-- El de Blender (CocheViejo, 11.8.12): un sedán de los setenta de 6,6 × 14,3. Los bloques son lo que choca y el sitio
	-- de cada pieza; si está la malla, son invisibles y cada pieza lleva dentro la suya (Coche enseña las mallas).
	local PINTURA = Color3.fromRGB(78, 88, 96)
	local function trozo(nombre: string, tamano: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): Part
		return bloque(nombre, tamano, base * offset, color, material or Enum.Material.Metal, coche)
	end
	local cuerpo = {
		trozo("Chasis", Vector3.new(6.4, 2.1, 13.6), CFrame.new(0, 2, 0), PINTURA),
		trozo("Cabina", Vector3.new(6.2, 1.8, 6), CFrame.new(0, 4, 1.4), PINTURA),
	}
	-- Los faros: HuidaVista los enciende en la huida (con la malla, solo la luz).
	for _, lado in { -1, 1 } do
		table.insert(cuerpo, trozo("Faro", Vector3.new(0.7, 0.7, 0.1), CFrame.new(2.3 * lado, 2.3, -6.95), Color3.fromRGB(200, 195, 170),
			Enum.Material.SmoothPlastic))
	end
	-- Capó abierto (la bisagra junto al parabrisas): deja ver el hueco del motor. HuidaVista lo cierra.
	local capo = trozo("Capo", Vector3.new(6.2, 0.3, 4.4), CFrame.new(0, 3.1, -2) * CFrame.Angles(math.rad(65), 0, 0) * CFrame.new(0, 0, -2.2),
		PINTURA)
	-- Las piezas: Motor, Rueda1..4 (las 1 y 2, las de atrás, ya están), Bateria y Radiador.
	local piezas = { Motor = "MotorCoche", Bateria = "BateriaCoche", Radiador = "RadiadorCoche" }
	trozo("Motor", Vector3.new(3.1, 2.2, 2.4), CFrame.new(0, 2.45, -4.2), Color3.fromRGB(70, 72, 75), Enum.Material.DiamondPlate)
	for i, sitio in { { 1, 4.3 }, { -1, 4.3 }, { 1, -4.4 }, { -1, -4.4 } } do
		local rueda = trozo("Rueda" .. i, Vector3.new(0.94, 2.6, 2.6), CFrame.new(2.75 * sitio[1], 1.3, sitio[2]), Color3.fromRGB(32, 32, 34),
			Enum.Material.Rubber)
		rueda.Shape = Enum.PartType.Cylinder
		piezas[rueda.Name] = "RuedaCoche"
		if i > 2 then
			trozo("Ladrillos" .. (i - 2), Vector3.new(1, 1.1, 1.6), CFrame.new(2.4 * sitio[1], 0.55, sitio[2]), Color3.fromRGB(120, 60, 48),
				Enum.Material.Brick)
		end
	end
	trozo("Bateria", Vector3.new(1.4, 1.07, 0.9), CFrame.new(-1.9, 1.885, -2.5), Color3.fromRGB(40, 40, 42), Enum.Material.SmoothPlastic)
	trozo("Radiador", Vector3.new(3, 1.55, 0.3), CFrame.new(0, 2.125, -6.15), Color3.fromRGB(150, 150, 148))
	mando(base * CFrame.new(0, 2.6, -7.6), coche) -- reparar, delante del parachoques
	local conducir = mando(base * CFrame.new(-3.9, 3, 0.6), coche) -- huir, en la puerta del conductor
	conducir.Name = "Conducir"
	coche:SetAttribute("Tapon", base * CFrame.new(3.3, 2.6, -1.5)) -- donde cae la gasolina (cerca del capó, para el R)
	local carroceria = tienda("CocheViejo", base * CFrame.new(0, 0.95, 0), true)
	if carroceria then
		for _, pieza in carroceria:GetChildren() do
			pieza.Parent = coche
		end
		carroceria:Destroy()
		for _, b in cuerpo do
			b.Transparency = 1
		end
		-- El capó de verdad es la malla, con el nombre del bloque (HuidaVista la busca).
		local tapa = tienda("CapoCoche", capo.CFrame * CFrame.new(0, -0.125, 0), true)
		if tapa then
			local malla = tapa:FindFirstChildWhichIsA("MeshPart")
			if malla then
				malla.Name = "Capo"
				malla.Parent = coche
				capo:Destroy()
			end
			tapa:Destroy()
		end
		-- Cada pieza, con su malla dentro (de pie sobre el fondo del bloque).
		for nombre, molde in piezas do
			local parte = coche:FindFirstChild(nombre) :: BasePart
			local m = tienda(molde, parte.CFrame * CFrame.new(0, -parte.Size.Y / 2, 0), true)
			if m then
				for _, pieza in m:GetChildren() do
					pieza.Parent = parte
				end
				m:Destroy()
				parte.Transparency = 1
				parte:SetAttribute("ConMalla", true)
			end
		end
		-- Arañazos del bicho en la puerta del conductor (MARCAS.Aranazos).
		local marcas = trozo("Marcas", Vector3.new(0.05, 2, 5), CFrame.new(-3.25, 2.4, 0.8), PINTURA)
		marcas.Transparency = 1
		marcas.CanCollide = false
		marcas.CanQuery = false
		local d = Instance.new("Decal")
		d.Texture = "rbxassetid://72113309993798"
		d.Color3 = Color3.fromRGB(150, 120, 110)
		d.Face = Enum.NormalId.Left
		d.Parent = marcas
	else
		for i = 1, 3 do -- sin la malla, tres rayas
			trozo("Arañazo", Vector3.new(0.1, 0.15, 3.4), CFrame.new(-3.22, 2.3 + i * 0.35, 1) * CFrame.Angles(math.rad(-14), 0, 0),
				Color3.fromRGB(70, 20, 18), Enum.Material.SmoothPlastic)
		end
	end
	coche:SetAttribute("Sitio", base)
	CollectionService:AddTag(coche, "Coche")
	coche.Parent = casa
end

-- Desván bajo el tejado (suelo en y = 27, encima del techo; de alto, 13 en la cumbrera): se sube por la escalera del
-- cuarto cerrado de arriba. Hastiales en los dos lados; el cuarto de revelado del rico y lo demás, en vestirDesvan.
local function construirDesvan()
	local alto = TEJADO.pendiente * 33.5
	for _, x in { -39, 39 } do
		for _, lado in { -1, 1 } do
			-- La cuña es alta por +Z: la de -z va tal cual y la de +z, girada.
			local cuna = Instance.new("WedgePart")
			cuna.Name = "Hastial"
			cuna.Anchored = true
			cuna.Size = Vector3.new(1, alto, 33.5)
			cuna.CFrame = CFrame.new(x, 27 + alto / 2, 16.75 * lado) * (if lado > 0 then CFrame.Angles(0, math.pi, 0) else CFrame.identity)
			cuna.Color = COLOR.Muro
			cuna.Material = Enum.Material.WoodPlanks
			cuna.Parent = casa
		end
	end
	-- Lo de dentro (cuarto de revelado, muebles tapados, vigas…), en vestirDesvan.
end

-- Sótano bajo el patio de atrás: de la puerta del fondo del pasillo (z = 33) baja una escalera tapada (x -3..3) hasta
-- una sala bajo tierra (x -12..12, z 47.6..65.6, suelo en y = -11; encima, el suelo del bosque). El bosque deja un
-- hueco en el suelo encima de la escalera (HUECO). Paredes de piedra, hormigón roto, techo y peldaños de tablas, propios
-- de la sala (11.8.13); los muebles, en vestirSotano.
local HUECO = { -3.5, 3.5, 33.5, 47.6 } -- x1, x2, z1, z2
-- Trampilla del sótano al patio (12.2, final de la Bestia): hueco en el techo del sótano y en el suelo del bosque, en el
-- rincón del oeste entre las cadenas del techo y los cajones. Se sube por una escalera de mano; la Bestia no cabe.
local TRAMPILLA = { -11.4, -6.9, 59.2, 62 } -- x1, x2, z1, z2
local FONDO_SOTANO = -11
-- El banco del taller del sótano (BancoCarpintero, en vestirSotano): el origen del mueble, contra la pared del fondo.
local BANCO_SOTANO = Vector3.new(-1, FONDO_SOTANO, 63.55)
local function construirSotano()
	local FONDO = FONDO_SOTANO
	variante(bloque("Rellano", Vector3.new(5, 12, 2), CFrame.new(0, FONDO + 6, 34.5), COLOR.Piso), "TechoSotano")
	for i = 1, 11 do
		variante(bloque("Peldano", Vector3.new(5, 12 - i, 1.1), CFrame.new(0, FONDO + (12 - i) / 2, 35.5 + (i - 0.5) * 1.1), COLOR.Piso),
			"TechoSotano")
	end
	-- Paredes de la escalera: bajo tierra y por fuera, enteras a los dos lados (la del este era baja porque la tapaba
	-- el cobertizo; al moverlo quedó un hueco al bosque).
	for _, x in { -3, 3 } do
		Fachada.pared(bloque("Muro", Vector3.new(1, 21, 14.6), CFrame.new(x, FONDO + 10.5, 40.8)), Vector3.new(math.sign(x), 0, 0))
	end
	Fachada.pared(bloque("Muro", Vector3.new(7, 10, 1), CFrame.new(0, 5, 48.1)), Vector3.new(0, 0, 1))
	Fachada.chapa(bloque("Tejadillo", Vector3.new(7, 0.6, 15.1), CFrame.new(0, 10.3, 40.85), COLOR.Oscuro, Enum.Material.CorrodedMetal))
	lampara(Vector3.new(0, 9.6, 41))
	-- La sala.
	local z1, z2, alto = 47.6, 65.6, 9
	variante(bloque("Piso", Vector3.new(25, 1, z2 - z1 + 1), CFrame.new(0, FONDO - 0.5, (z1 + z2) / 2), COLOR.Piso, Enum.Material.Concrete),
		"SueloSotano")
	-- El techo, en cuatro trozos alrededor del hueco de la trampilla al patio (12.2).
	local t1, t2, t3, t4 = TRAMPILLA[1], TRAMPILLA[2], TRAMPILLA[3], TRAMPILLA[4]
	for _, r in { { -12.5, t1, z1 - 0.5, z2 + 0.5 }, { t2, 12.5, z1 - 0.5, z2 + 0.5 }, { t1, t2, z1 - 0.5, t3 }, { t1, t2, t4, z2 + 0.5 } } do
		variante(bloque("Techo", Vector3.new(r[2] - r[1], 0.4, r[4] - r[3]), CFrame.new((r[1] + r[2]) / 2, FONDO + alto - 0.2, (r[3] + r[4]) / 2),
			COLOR.Piso, Enum.Material.Concrete), "TechoSotano")
	end
	for _, x in { -7.5, 7.5 } do
		variante(bloque("Muro", Vector3.new(10, alto, 1), CFrame.new(x, FONDO + alto / 2, z1), nil, Enum.Material.Concrete), "ParedSotano")
	end
	variante(bloque("Muro", Vector3.new(25, alto, 1), CFrame.new(0, FONDO + alto / 2, z2), nil, Enum.Material.Concrete), "ParedSotano")
	for _, x in { -12, 12 } do
		variante(bloque("Muro", Vector3.new(1, alto, z2 - z1), CFrame.new(x, FONDO + alto / 2, (z1 + z2) / 2), nil, Enum.Material.Concrete),
			"ParedSotano")
	end
	-- El banco del taller (opción A del usuario, "el banco te espera"): en medio de la pared del fondo, lo primero que se
	-- ve al bajar. El de Blender (BancoCarpintero, en vestirSotano) tapa los bloques de siempre, que siguen chocando y
	-- siendo el Banco del Taller. Delante del pie de la escalera queda sitio para la reja (12.2).
	banco("Sotano", CFrame.lookAt(BANCO_SOTANO, BANCO_SOTANO - Vector3.zAxis))
	if MUEBLES.BancoCarpintero then
		for _, b in (casa:FindFirstChild("BancoSotano") :: Model):GetChildren() do
			if b:IsA("BasePart") then
				b.Transparency = 1
			end
		end
	end
	-- La chatarra, en el suelo entre las dos despensas de tarros (vestirSotano): en una balda se caía, porque la despensa
	-- choca como una caja entera.
	table.insert(Mapa.objetos, { tipo = "Chatarra", cf = CFrame.new(8.6, FONDO + 0.3, 57) })
end

-- Lo del final de la Bestia (12.2; lo maneja Preparativos, que pone la reja, los puntos de gasolina y los prompts):
--   MarcoReja: dos guías de hierro al pie de la escalera del sótano, delante del último peldaño (z 46,9), por donde sube
--   y baja la reja. Atributos: Cerrada y Abierta (dónde va el centro de la reja), Tam (su tamaño).
--   Palanca: fuera, en un poste del patio al oeste de la trampilla (14.1). Atributo Pivote (el eje del mango; lo mueve
--   el cliente).
--   Trampilla: tapa de tablas en el patio sobre el hueco TRAMPILLA, con escalera de mano desde el sótano. Atributo
--   Abierta (CFrame de la tapa abierta). Se abre desde abajo.
--   Por el mapa (objetos sueltos, Mochila): cadenas para la reja, la pistola de bengalas del rico con sus 3 bengalas al
--   lado (desván, delante del baúl) y las cerillas (encimera de la cocina).
local function construirFinal()
	local F = FONDO_SOTANO
	local hierro = Color3.fromRGB(52, 50, 48)
	local guias = Instance.new("Model")
	guias.Name = "MarcoReja"
	guias.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	-- La reja cerrada se apoya en el último peldaño (cara de arriba en F + 1) y tapa el vano de la sala; subida, deja
	-- pasar por debajo hasta a la Bestia.
	local Z, ALTO_REJA, SUBE = 46.9, 8.6, 9.5
	for _, x in { -2.3, 2.3 } do
		local guia = bloque("Guia", Vector3.new(0.3, 19, 0.5), CFrame.new(x, F + 1 + 9.5, Z), hierro, Enum.Material.CorrodedMetal, guias)
		guia.CanCollide = false
	end
	bloque("Travesano", Vector3.new(5.2, 0.5, 0.6), CFrame.new(0, F + 20.25, Z), hierro, Enum.Material.CorrodedMetal, guias).CanCollide = false
	mando(CFrame.new(0, F + 4, 45.4), guias)
	local cerrada = CFrame.new(0, F + 1 + ALTO_REJA / 2, Z)
	guias:SetAttribute("Cerrada", cerrada)
	guias:SetAttribute("Abierta", cerrada + Vector3.new(0, SUBE, 0))
	guias:SetAttribute("Tam", Vector3.new(4.9, ALTO_REJA, 0.25))
	CollectionService:AddTag(guias, "MarcoReja")
	guias.Parent = casa

	-- Palanca (14.1, pedido por el usuario: fuera, en el patio): en un poste de madera al oeste de la trampilla, mirando
	-- al hueco. Se mete a la Bestia en el sótano, se sube por la escalera de mano y se tira nada más salir; desde abajo
	-- no llega. Placa y mango con su pomo; subida, el mango apunta arriba y hacia la trampilla. Un tubo de hierro baja
	-- del poste, va por el suelo y se mete por el hueco: es lo que suelta la reja.
	local palanca = Instance.new("Model")
	palanca.Name = "Palanca"
	palanca.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local PX, PZ = TRAMPILLA[1] - 3.2, (TRAMPILLA[3] + TRAMPILLA[4]) / 2
	bloque("Poste", Vector3.new(0.6, 5.4, 0.6), CFrame.new(PX - 0.4, 1.9, PZ), Color3.fromRGB(58, 44, 34), Enum.Material.Wood, palanca)
	local base = CFrame.new(PX, 3.4, PZ)
	bloque("Placa", Vector3.new(0.2, 1.8, 0.9), base, hierro, Enum.Material.CorrodedMetal, palanca)
	for _, t in {
		{ Vector3.new(0.16, 2.6, 0.16), CFrame.new(PX + 0.05, 1.3, PZ - 0.35) }, -- baja por el poste
		{ Vector3.new(TRAMPILLA[1] - PX + 0.1, 0.16, 0.16), CFrame.new((PX + TRAMPILLA[1]) / 2, 0.08, PZ - 0.35) }, -- por el suelo
		{ Vector3.new(0.16, 3, 0.16), CFrame.new(TRAMPILLA[1] + 0.2, -1.4, PZ - 0.35) }, -- y se mete por el hueco
	} do
		local tubo = bloque("Tubo", t[1], t[2], hierro, Enum.Material.CorrodedMetal, palanca)
		tubo.CanCollide = false
		tubo.CanQuery = false
	end
	local pivote = base * CFrame.new(0.2, 0, 0)
	local giro = pivote * CFrame.Angles(0, 0, -0.5)
	local mango = bloque("Mango", Vector3.new(0.18, 2, 0.18), giro * CFrame.new(0, 1, 0), hierro, Enum.Material.Metal, palanca)
	mango.CanCollide = false
	local pomo = bloque("Pomo", Vector3.new(0.4, 0.4, 0.4), giro * CFrame.new(0, 2, 0), Color3.fromRGB(70, 22, 18), Enum.Material.SmoothPlastic,
		palanca)
	pomo.Shape = Enum.PartType.Ball
	pomo.CanCollide = false
	mando(base * CFrame.new(0.9, 0, 0), palanca)
	palanca:SetAttribute("Pivote", pivote)
	CollectionService:AddTag(palanca, "Palanca")
	palanca.Parent = casa

	-- Trampilla: la tapa, encima del suelo del bosque; la bisagra en el borde del este. El hueco forrado de tablas.
	local tx1, tx2, tz1, tz2 = TRAMPILLA[1], TRAMPILLA[2], TRAMPILLA[3], TRAMPILLA[4]
	local cz = (tz1 + tz2) / 2
	local trampilla = Instance.new("Model")
	trampilla.Name = "Trampilla"
	trampilla.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local ancho = tx2 - tx1 + 0.3
	local bisagra = CFrame.new(tx2 + 0.15, 0.125, cz)
	bloque("Tapa", Vector3.new(ancho, 0.25, tz2 - tz1 + 0.3), bisagra * CFrame.new(-ancho / 2, 0, 0), COLOR.Mueble, Enum.Material.WoodPlanks,
		trampilla)
	mando(CFrame.new((tx1 + tx2) / 2, F + 8, cz), trampilla) -- bajo el techo del sótano: se abre desde abajo
	trampilla:SetAttribute("Abierta", bisagra * CFrame.Angles(0, 0, math.rad(-105)) * CFrame.new(-ancho / 2, 0, 0))
	CollectionService:AddTag(trampilla, "Trampilla")
	trampilla.Parent = casa
	-- Las paredes del hueco, forradas: { centro x, centro z, ancho en x, ancho en z }.
	local mx, w, d = (tx1 + tx2) / 2, tx2 - tx1, tz2 - tz1
	for _, r in { { tx1 + 0.06, cz, 0.1, d }, { tx2 - 0.06, cz, 0.1, d }, { mx, tz1 + 0.06, w, 0.1 }, { mx, tz2 - 0.06, w, 0.1 } } do
		adorno(Vector3.new(r[3], 2.4, r[4]), CFrame.new(r[1], -1.2, r[2]), Enum.Material.WoodPlanks)
	end
	-- Escalera de mano contra la pared del oeste: se ve de madera y trepa por un TrussPart invisible. Con la tapa
	-- cerrada acaba debajo de ella (asomaba por encima: un escalón invisible sobre la tapa y los largueros saliendo por
	-- las tablas); al abrirse sube y asoma por el hueco, para poder salir trepando. La escala se mueve en vez de
	-- encogerse: un TrussPart solo mide de 2 en 2.
	local escala = Instance.new("TrussPart")
	escala.Name = "Escala"
	escala.Anchored = true
	escala.Size = Vector3.new(2, 12, 2)
	escala.CFrame = CFrame.new(tx1 + 1, F + 5, cz) -- de F - 1 (metida en el suelo del sótano) a la tapa
	escala.Transparency = 1
	escala.Parent = casa
	local madera = Color3.fromRGB(70, 52, 38)
	local largueros = {}
	for _, dz in { -0.75, 0.75 } do
		local larguero = adorno(Vector3.new(0.22, 11, 0.22), CFrame.new(tx1 + 0.6, F + 5.5, cz + dz), Enum.Material.Wood)
		larguero.Color = madera
		table.insert(largueros, larguero)
	end
	for i = 1, 11 do
		local peldano = adorno(Vector3.new(0.18, 0.18, 1.5), CFrame.new(tx1 + 0.6, F + i, cz), Enum.Material.Wood)
		peldano.Color = madera
	end
	local asoma = false
	trampilla:GetAttributeChangedSignal("Abierto"):Connect(function()
		local abierta = trampilla:GetAttribute("Abierto") == true
		if abierta == asoma then
			return
		end
		asoma = abierta
		local k = if abierta then 1 else -1
		escala.CFrame += Vector3.new(0, k, 0)
		for _, larguero in largueros do -- crecen por arriba (sumando: Separar ya los puede haber engordado)
			larguero.Size += Vector3.new(0, 1.4 * k, 0)
			larguero.CFrame += Vector3.new(0, 0.7 * k, 0)
		end
	end)

	for _, o in {
		{ "Cadena", Vector3.new(-49.9, ABAJO + 3.7, 30.3) }, -- en el banco del garaje, entre las dos chatarras
		{ "Cadena", Vector3.new(226, 1.2, 79) }, -- en el granero de la granja
		{ "Cadena", Vector3.new(-228, 1.2, -84) }, -- en la nave del aserradero
		{ "Pistola", Vector3.new(-2.4, 27.6, -11.5) }, -- desván, delante del baúl del rico
		{ "Bengala", Vector3.new(-1.2, 27.6, -11.3) },
		{ "Bengala", Vector3.new(-0.9, 27.6, -11.9) },
		{ "Bengala", Vector3.new(-1.6, 27.6, -12) },
		{ "Cerillas", Vector3.new(-26.5, ABAJO + 3.7, 31.3) }, -- encimera de la cocina
	} do
		table.insert(Mapa.objetos, { tipo = o[1], cf = CFrame.new(o[2]) * CFrame.Angles(0, math.rad(#Mapa.objetos * 37), 0) })
	end
end

-- Garaje pegado a la cocina, al oeste (x -59..-39, z 3..33; pedido por el usuario): se entra desde la cocina por la
-- puerta con llave y el portón da al camino por delante; se abre desde que la puerta lo está (Coche). Dentro, tu coche
-- destrozado, el banco del taller, una rueda, un bidón y chatarra. Ventana sin persiana: es una sala cerrada.
local function construirGaraje()
	local OESTE = Vector3.new(-1, 0, 0)
	CollectionService:AddTag(bloque("Piso", Vector3.new(20, 1, 31), CFrame.new(-49.5, 0.5, 18), COLOR.Piso, Enum.Material.Concrete), "EnMapa")
	muro(-39, 3, -39, 33, ABAJO, { p(15, OESTE, { bloqueada = true, nombre = "Garaje", llave = "LlaveGaraje" }) }) -- cocina | garaje
	muro(-59, 3, -39, 3, ABAJO, { { tipo = "Hueco", en = 10, ancho = 10, alto = 9 } }, Vector3.new(0, 0, -1))
	local porton = Instance.new("Model")
	porton.Name = "Porton"
	porton.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	bloque("Hoja", Vector3.new(10, 9, 0.4), CFrame.new(-49, ABAJO + 4.5, 3), COLOR.Oscuro, Enum.Material.CorrodedMetal, porton)
	-- El mando, en el borde del hueco (como un interruptor): en medio se pisaba con el del capó del coche.
	mando(CFrame.new(-44.6, ABAJO + 3.5, 3), porton)
	CollectionService:AddTag(porton, "Porton")
	porton.Parent = casa
	muro(-59, 3, -59, 33, ABAJO, { v(4, 4, 3, 9, false) }, OESTE)
	muro(-59, 33, -39, 33, ABAJO, {}, Vector3.new(0, 0, 1))
	Fachada.chapa(bloque("Techo", Vector3.new(21, 1, 31), CFrame.new(-49.5, ABAJO + ALTO + 0.5, 18), COLOR.Oscuro, Enum.Material.CorrodedMetal))
	construirCoche(CFrame.new(-49, ABAJO, 18))
	-- El taller, en la pared del fondo frente al portón (11.8.12, opción B elegida por el usuario): el banco de Blender
	-- (BancoTaller, en vestirGaraje) tapa los bloques del de siempre, que siguen chocando y siendo el Banco del Taller.
	banco("Garaje", CFrame.lookAt(Vector3.new(-49.5, ABAJO, 31.1), Vector3.new(-49.5, ABAJO, 20)))
	if MUEBLES.BancoTaller then
		for _, b in (casa:FindFirstChild("BancoGaraje") :: Model):GetChildren() do
			if b:IsA("BasePart") then
				b.Transparency = 1
			end
		end
	end
	table.insert(Mapa.pesados, { tipo = "Rueda", cf = CFrame.new(-56, ABAJO + 0.5, 8) * CFrame.Angles(0, 0, math.pi / 2) })
	table.insert(Mapa.pesados, { tipo = "Bidon", cf = CFrame.new(-41.2, ABAJO + 1.2, 25.3) })
	for _, x in { -52, -47.8 } do
		table.insert(Mapa.objetos, { tipo = "Chatarra", cf = CFrame.new(x, ABAJO + 3.7, 30.3) })
	end
end

-- Salas de la casa (pedido por el usuario: grandes y despejadas, los muebles contra las paredes y el centro libre).
-- `papel` = el de las paredes (PAPEL), `suelo` = lo que se pone encima del suelo, `techo` = techo de yeso (no en las
-- salas con hueco de escalera).
local SALAS = {
	-- Salón (11.8.2): papel de rayas de los años 50 sobre papel viejo, rodapié de madera oscura, tablas viejas y techo de
	-- yeso propios de la sala (MaterialVariants).
	{ x1 = 12, x2 = 39, z1 = -33, z2 = 5, y = ABAJO, papel = "PapelSalon", suelo = "SueloSalon", techo = "TechoSalon", rodapie = "MaderaOscura" },
	-- Dormitorio de abajo, el de la abuela (11.8.6): papel de florecillas sobre papel viejo manchado, rodapié oscuro,
	-- tablas oscuras barnizadas y el techo de yeso del salón.
	{ x1 = 22, x2 = 39, z1 = 5, z2 = 33, y = ABAJO, papel = "PapelDormitorio", suelo = "SueloDormitorio", techo = "TechoSalon", rodapie = "MaderaOscura" },
	-- Trastero y baño (11.8.5): yeso roto con el ladrillo a la vista y tablas viejas; en el baño, pintura rosa que se
	-- pela sobre azulejo pequeño a media pared, mosaico en el suelo y techo ahumado. Propios de cada sala.
	{ x1 = 12, x2 = 22, z1 = 5, z2 = 19, y = ABAJO, papel = "PapelTrastero", suelo = "SueloTrastero", techo = true, rodapie = "MaderaOscura" },
	{ x1 = 12, x2 = 22, z1 = 19, z2 = 33, y = ABAJO, papel = "PapelBano", suelo = "SueloBano", techo = "TechoCocina", azulejo = "AzulejoBano" },
	-- Vestíbulo (a doble altura; 11.8.1): papel verde oscuro sobre zócalo alto de paneles, parquet en espiga y techo de
	-- yeso agrietado, propios de la sala (plan-salas.md, paso 3).
	{ x1 = -12, x2 = 12, z1 = -33, z2 = 9, y = ABAJO, papel = "Vestibulo", suelo = "ParquetVestibulo", zocalo = "PanelVestibulo" },
	-- Pasillo del sótano (11.8.5): papel de rayas burdeos sobre papel viejo, rodapié oscuro, tablas gastadas y el techo
	-- agrietado del vestíbulo.
	{ x1 = -12, x2 = 12, z1 = 9, z2 = 33, y = ABAJO, papel = "PapelPasillo", suelo = "SueloPasillo", techo = "TechoVestibulo", rodapie = "MaderaOscura" },
	-- Comedor y su mirador (11.8.3): pintura roja oscura que se cae a trozos sobre un zócalo alto de paneles, parquet en
	-- diagonal y techo de gotelé, propios de la sala.
	{ x1 = -39, x2 = -12, z1 = -33, z2 = 3, y = ABAJO, papel = "PapelComedor", suelo = "SueloComedor", techo = "TechoComedor", zocalo = "ZocaloComedor" },
	{ x1 = -43, x2 = -39, z1 = -17, z2 = -3, y = ABAJO, papel = "PapelComedor", suelo = "SueloComedor", techo = "TechoComedor", zocalo = "ZocaloComedor" },
	-- Cocina (11.8.4): pintura verde menta sucia sobre azulejo blanco alargado a media pared, damas sucias y techo
	-- ahumado, propios de la sala.
	{ x1 = -39, x2 = -12, z1 = 3, z2 = 33, y = ABAJO, papel = "PapelCocina", suelo = "SueloCocina", techo = "TechoCocina", azulejo = "AzulejoCocina" },
	-- Lavadero (11.8.12): pintura que se pela sobre azulejo blanco a media pared, baldosa gastada y el techo ahumado de la
	-- cocina. Garaje y cobertizo, "en bruto" (sin rodapié ni moldura): bloques de hormigón y suelo de garaje con manchas;
	-- tablas viejas y suelo de tierra. Sus techos son la chapa.
	{ x1 = -26, x2 = -12, z1 = 33, z2 = 45, y = ABAJO, papel = "PapelLavadero", suelo = "SueloLavadero", techo = "TechoCocina", azulejo = "AzulejoLavadero", medir = true },
	{ x1 = -59, x2 = -39, z1 = 3, z2 = 33, y = ABAJO, papel = "ParedGaraje", suelo = "SueloGaraje", bruto = true, medir = true },
	{ x1 = -54, x2 = -44, z1 = 37, z2 = 45.5, y = ABAJO, papel = "ParedCobertizo", suelo = "SueloCobertizo", bruto = true, medir = true },
	-- Dormitorio grande, el de los dueños (11.8.8): papel de damasco azul grisáceo sobre papel viejo, rodapié oscuro,
	-- parqué de tiras oscuro y el techo de yeso del salón.
	{ x1 = 12, x2 = 39, z1 = -33, z2 = 9, y = ARRIBA, papel = "PapelDormitorioGrande", suelo = "SueloDormitorioGrande", techo = "TechoSalon", rodapie = "MaderaOscura" },
	-- Escalera del desván (11.8.11): papel viejo ocre sin dibujo, rodapié oscuro y las tablas viejas de la galería (el techo,
	-- de tablas con el hueco de la escalera, en vestirDesvan).
	{ x1 = 12, x2 = 39, z1 = 9, z2 = 33, y = ARRIBA, papel = "PapelEscaleraDesvan", suelo = "SueloGaleria", rodapie = "MaderaOscura" },
	-- Galería (11.8.7): damasco azul pizarra y oro viejo sobre el zócalo de paneles del vestíbulo, tablas viejas y el
	-- techo agrietado del vestíbulo (se ven juntos desde el hueco).
	{ x1 = -12, x2 = 12, z1 = 0, z2 = 33, y = ARRIBA, papel = "PapelGaleria", suelo = "SueloGaleria", techo = "TechoVestibulo", zocalo = "PanelVestibulo" },
	{ x1 = -12, x2 = 12, z1 = -33, z2 = 0, y = ARRIBA, papel = "Vestibulo", techo = "TechoVestibulo" }, -- hueco del vestíbulo
	-- Habitación del rico (11.8.9): papel azul marino de rayas con hilo dorado sobre zócalo alto de paneles de caoba,
	-- parquet oscuro y el techo de yeso del salón.
	{ x1 = -39, x2 = -12, z1 = -33, z2 = 9, y = ARRIBA, papel = "PapelRico", suelo = "SueloRico", techo = "TechoSalon", zocalo = "ZocaloRico" },
	-- Cuarto de los niños (11.8.10): papel de patitos y globos desteñido sobre papel viejo, rodapié oscuro, tablas viejas
	-- y el techo de yeso del salón.
	{ x1 = -39, x2 = -12, z1 = 9, z2 = 33, y = ARRIBA, papel = "PapelNinos", suelo = "SueloNinos", techo = "TechoSalon", rodapie = "MaderaOscura" },
}
-- Papel pintado (imágenes del Creator Store, teñidas): damasco mostaza en el salón.
-- Colores apagados y sucios (pedido por el usuario: el mostaza chillón parecía un juego de niños, no una casa
-- abandonada).
local PAPEL = {
	Salon = { id = "rbxassetid://1587307732", color = Color3.fromRGB(104, 84, 54), tam = 7 },
	Pasillo = { id = "rbxassetid://1587307732", color = Color3.fromRGB(88, 70, 50), tam = 7 },
	Vestibulo = { id = "rbxassetid://1587307732", color = Color3.fromRGB(58, 68, 54), tam = 7 },
	Rojo = { id = "rbxassetid://18672898655", color = Color3.fromRGB(98, 66, 60), tam = 7 },
	Claro = { id = "rbxassetid://1587307732", color = Color3.fromRGB(116, 110, 92), tam = 6 },
}

-- Lámina que se ve pero no choca ni tapa rayos (papel, suelos, techos, zócalos, molduras).
local function lamina(tamano: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local hoja = adorno(tamano, cf, material)
	hoja.Color = color
	hoja.CastShadow = false
	hoja:SetAttribute("SinSeparar", true) -- ya va apartada de la pared (Separar)
	return hoja
end

-- Viste cada cara de pared que da a una sala, trozo a trozo (una pared de fuera pasa por varias salas): papel pintado,
-- zócalo oscuro abajo (azulejo blanco a media pared en la cocina) y moldura blanca arriba. Las caras de fuera de la
-- casa no caen en ninguna sala.
local function vestirParedes()
	for _, pared in casa:GetChildren() do
		if pared.Name ~= "Muro" or not pared:IsA("BasePart") then
			continue
		end
		local enX = pared.Size.X < pared.Size.Z -- la pared es delgada en X (va a lo largo de z)
		local grueso = if enX then pared.Size.X else pared.Size.Z
		local largo = if enX then pared.Size.Z else pared.Size.X
		local medio = if enX then pared.Position.Z else pared.Position.X -- a lo largo de la pared
		local bajo, alto = pared.Position.Y - pared.Size.Y / 2, pared.Position.Y + pared.Size.Y / 2
		for _, signo in { -1, 1 } do
			local normal = if enX then Vector3.new(signo, 0, 0) else Vector3.new(0, 0, signo)
			local delante = (if enX then pared.Position.X else pared.Position.Z) + signo * (grueso / 2 + 0.5)
			for _, sala in SALAS do
				local s1, s2 = if enX then sala.x1 else sala.z1, if enX then sala.x2 else sala.z2 -- a través
				local l1, l2 = if enX then sala.z1 else sala.x1, if enX then sala.z2 else sala.x2 -- a lo largo
				local desde, hasta = math.max(medio - largo / 2, l1), math.min(medio + largo / 2, l2) -- los límites, en medio de un pared
				if delante <= s1 or delante >= s2 or hasta - desde < 0.05 or pared.Position.Y < sala.y or pared.Position.Y > sala.y + ALTO then
					continue
				end
				-- `hueco`: separada de la pared, para que su cara de atrás no coincida con otra y parpadee (Separar).
				local function tira(alto_: number, y: number, fondo: number, color: Color3, material: Enum.Material, hueco: number?): Part
					-- Un pelo más bajas que la pared: si sus caras de arriba o abajo coincidieran con las de la pared, Separar
					-- engordaría la pared y taparía el papel.
					local tamano = if enX then Vector3.new(fondo, alto_ - 0.04, hasta - desde) else Vector3.new(hasta - desde, alto_ - 0.04, fondo)
					local centro = Vector3.new(pared.Position.X, y, pared.Position.Z) + normal * (grueso / 2 + (hueco or 0) + fondo / 2)
					centro = if enX then Vector3.new(centro.X, centro.Y, (desde + hasta) / 2) else Vector3.new((desde + hasta) / 2, centro.Y, centro.Z)
					return lamina(tamano, CFrame.new(centro), color, material)
				end
				local papel = PAPEL[sala.papel]
				local hoja = tira(alto - bajo, (bajo + alto) / 2, 0.04, Color3.fromRGB(40, 32, 26), Enum.Material.SmoothPlastic, 0.01)
				hoja.Name = "Papel"
				if papel then
					local textura = Instance.new("Texture")
					textura.Texture = papel.id
					textura.Color3 = papel.color
					textura.StudsPerTileU = papel.tam
					textura.StudsPerTileV = papel.tam
					textura.Face = if enX then (if signo > 0 then Enum.NormalId.Right else Enum.NormalId.Left)
						else (if signo > 0 then Enum.NormalId.Back else Enum.NormalId.Front)
					textura.Parent = hoja
				else -- papel propio de la sala (un MaterialVariant)
					variante(hoja, sala.papel)
				end
				if sala.bruto then -- garaje y cobertizo: solo la pared
					continue
				end
				if math.abs(bajo - sala.y) < 0.5 then -- Separar las engorda un poco
					if sala.azulejo then
						local azulejo = math.min(4.5, alto - bajo) -- bajo una ventana, hasta la repisa
						variante(tira(azulejo, bajo + azulejo / 2, 0.12, Color3.fromRGB(196, 192, 180), Enum.Material.CeramicTiles), sala.azulejo)
						if azulejo == 4.5 then
							tira(0.25, bajo + 4.62, 0.2, Color3.fromRGB(60, 58, 54), Enum.Material.SmoothPlastic, 0.02)
						end
					elseif sala.zocalo then
						-- Zócalo alto de paneles hasta media pared, con su moldura (vestíbulo).
						local panel = math.min(4, alto - bajo)
						variante(tira(panel, bajo + panel / 2, 0.14, COLOR.Marco, Enum.Material.Wood), sala.zocalo)
						if panel == 4 then
							variante(tira(0.3, bajo + 4.1, 0.24, COLOR.Marco, Enum.Material.Wood, 0.02), "MaderaOscura")
						end
					else
						local rodapie = tira(0.9, bajo + 0.45, 0.14, COLOR.Marco, Enum.Material.Wood)
						if sala.rodapie then
							variante(rodapie, sala.rodapie)
						end
					end
				end
				if math.abs(alto - (sala.y + ALTO)) < 0.5 then
					tira(0.5, alto - 0.25 - (if sala.techo then BAJO_TECHO else 0), 0.3, Color3.fromRGB(122, 114, 100), Enum.Material.Plaster)
				end
			end
		end
	end
end

-- Suelos y techos de cada sala: madera oscura, azulejo en el baño, techo de yeso (o los propios de cada sala).
-- Cara de arriba del suelo de arriba (Piso) en `punto`: Separar lo engorda y queda por encima de ARRIBA (tapaba el suelo
-- propio de la galería, 11.8.7). Abajo solo se mira en las salas con `medir` (el lavadero: su Piso también crece y
-- tapaba la baldosa, 11.8.12); las demás siguen igual. `nivel` = la altura sin engordar (ARRIBA si no se dice).
local function sueloArriba(punto: Vector3, nivel: number?): number
	local base = nivel or ARRIBA
	local alto = base
	for _, piso in casa:GetChildren() do
		if piso.Name == "Piso" and piso:IsA("BasePart") then
			local d = piso.CFrame:PointToObjectSpace(punto)
			local cara = piso.Position.Y + piso.Size.Y / 2
			if math.abs(d.X) < piso.Size.X / 2 and math.abs(d.Z) < piso.Size.Z / 2 and math.abs(cara - base) < 0.5 then
				alto = math.max(alto, cara)
			end
		end
	end
	return alto
end

local function vestirSuelos()
	local azar = Random.new(41) -- siempre igual en todos los servidores
	for _, s in SALAS do
		local ancho, fondo = s.x2 - s.x1 - 1, s.z2 - s.z1 - 1
		local centro = Vector3.new((s.x1 + s.x2) / 2, s.y, (s.z1 + s.z2) / 2)
		-- El suelo de verdad (arriba lo sube Separar): ahí van la lámina y los cascotes; el techo sigue saliendo de centro.
		local pisa = if s.y == ARRIBA then sueloArriba(centro) elseif s.medir then sueloArriba(centro, s.y) else s.y
		local lamSuelo = CFrame.new(centro.X, pisa + 0.03, centro.Z)
		if s.suelo == "Madera" then
			lamina(Vector3.new(ancho, 0.06, fondo), lamSuelo, Color3.fromRGB(46, 32, 24),
				Enum.Material.WoodPlanks)
		elseif s.suelo == "Azulejo" then
			lamina(Vector3.new(ancho, 0.06, fondo), lamSuelo, Color3.fromRGB(150, 148, 138),
				Enum.Material.CeramicTiles)
		elseif s.suelo then -- un MaterialVariant propio de la sala (el último: si no, se comía el azulejo)
			variante(lamina(Vector3.new(ancho, 0.06, fondo), lamSuelo, Color3.fromRGB(46, 32, 24),
				Enum.Material.WoodPlanks), s.suelo)
		end
		if s.techo then
			-- Por debajo del suelo de arriba, que Separar engorda 0,15: a ALTO - 0,03 quedaba dentro y se veían sus tablas.
			local techo = lamina(Vector3.new(ancho, 0.06, fondo), CFrame.new(centro + Vector3.new(0, ALTO - BAJO_TECHO, 0)),
				Color3.fromRGB(62, 58, 52), Enum.Material.Plaster)
			if type(s.techo) == "string" then -- techo propio de la sala (un MaterialVariant)
				variante(techo, s.techo)
			end
			-- Techo roto (pedido por el usuario: más abandonado): un trozo de yeso caído con los listones a la vista y los
			-- cascotes en el suelo, debajo. No choca.
			local agujero = centro + Vector3.new(azar:NextNumber(-ancho / 4, ancho / 4), ALTO - BAJO_TECHO - 0.05, azar:NextNumber(-fondo / 4, fondo / 4))
			local giro = CFrame.Angles(0, azar:NextNumber(0, math.pi), 0)
			lamina(Vector3.new(3.4, 0.04, 2.6), CFrame.new(agujero) * giro, Color3.fromRGB(24, 20, 18), Enum.Material.Wood)
			for k = -1, 1 do
				lamina(Vector3.new(0.35, 0.1, 3), CFrame.new(agujero - Vector3.new(0, 0.08, 0)) * giro * CFrame.new(k * 0.9, 0, 0),
					Color3.fromRGB(72, 58, 44), Enum.Material.Wood)
			end
			for k = 1, 4 do
				-- Los números del azar, siempre y en el mismo orden (si no, cambiarían los cascotes de las salas de después).
				local suelo = Vector3.new(agujero.X + azar:NextNumber(-1.5, 1.5), pisa + 0.1, agujero.Z + azar:NextNumber(-1.5, 1.5))
				local tam = Vector3.new(azar:NextNumber(0.5, 1.4), 0.14, azar:NextNumber(0.4, 1))
				if s.suelo then -- el hueco del vestíbulo no tiene suelo: flotaban en el aire a y = 14
					lamina(tam, CFrame.new(suelo) * CFrame.Angles(0, k, 0), Color3.fromRGB(96, 90, 80), Enum.Material.Plaster)
				end
			end
		end
	end
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

-- La casa abandonada (pedido por el usuario: "más vieja y abandonada"): telarañas en las esquinas del techo, manchas de
-- humedad, papel despegado, tablas y basura por el suelo, algo de sangre y alguna silla volcada. Todo pegado a las
-- paredes y sin chocar: no estorba al correr.
local function abandonar()
	local azar = Random.new(11)
	-- Telarañas: { x, y del techo, z, hacia dónde mira (a la sala) }.
	for _, t in {
		{ 14, ABAJO + ALTO - BAJO_TECHO, -31, Vector3.new(1, 0, 1) }, { 14, ABAJO + ALTO - BAJO_TECHO, 3, Vector3.new(1, 0, -1) }, -- salón
		{ 37, ABAJO + ALTO - BAJO_TECHO, 31, Vector3.new(-1, 0, -1) }, { 14, ABAJO + ALTO - BAJO_TECHO, 31, Vector3.new(1, 0, -1) }, -- dormitorio, baño
		{ -37, ABAJO + ALTO - BAJO_TECHO, -31, Vector3.new(1, 0, 1) }, { -37, ABAJO + ALTO - BAJO_TECHO, 31, Vector3.new(1, 0, -1) }, -- comedor, cocina
		{ -10, ABAJO + ALTO - BAJO_TECHO, 31, Vector3.new(1, 0, -1) }, { -24, ABAJO + ALTO - BAJO_TECHO, 43, Vector3.new(1, 0, -1) }, -- pasillo, lavadero
		{ -37, ARRIBA + ALTO - BAJO_TECHO, -31, Vector3.new(1, 0, 1) }, { 37, ARRIBA + ALTO - BAJO_TECHO, 31, Vector3.new(-1, 0, -1) },
		{ -10, ARRIBA + ALTO - BAJO_TECHO, -31, Vector3.new(1, 0, 1) },
	} do
		local nombre = if azar:NextNumber() < 0.5 then "Telarana" else "TelaranaTecho"
		local molde = MUEBLES[nombre]
		if molde then
			local pos = Vector3.new(t[1], t[2] - (molde:GetAttribute("Tam") :: Vector3).Y * 0.45, t[3])
			local tela = tienda(nombre, CFrame.lookAt(pos, pos + t[4]), true) :: Model
			tela:ScaleTo(tela:GetScale() * 0.45) -- desde el pivote, abajo: la de arriba queda contra el techo
		end
	end
	-- Manchas de humedad en lo alto de las paredes y papel despegado: { x, y, z, normal }.
	for _, m in {
		{ 33, ABAJO + 10, 32.4, -Vector3.zAxis }, -- (las del salón van en vestirSalon)
		{ -38.4, ABAJO + 8, -28, Vector3.xAxis }, { -38.4, ABAJO + 9, 26, Vector3.xAxis }, { -11.4, ABAJO + 9, 30, Vector3.xAxis },
		{ -20, ARRIBA + 9, 8.3, -Vector3.zAxis }, { 34, ARRIBA + 9, 32.4, -Vector3.zAxis }, { -11.4, ARRIBA + 7, -24, Vector3.xAxis },
	} do
		mancha(Vector3.new(m[1], m[2], m[3]), m[4], azar:NextNumber(4, 7), SANGRE[azar:NextInteger(1, #SANGRE)],
			Color3.fromRGB(46, 36, 24), azar:NextNumber(0, math.pi * 2))
		-- Un trozo de papel caído, colgando del techo.
		local trozo = adorno(Vector3.new(1.6, 2.4, 0.04), CFrame.lookAt(Vector3.new(m[1], m[2] + 1.5, m[3]) + m[4] * 0.3,
			Vector3.new(m[1], m[2] + 1.5, m[3]) + m[4]) * CFrame.Angles(math.rad(-25), 0, math.rad(azar:NextNumber(-15, 15))),
			Enum.Material.Fabric)
		trozo.Color = Color3.fromRGB(120, 92, 52)
	end
	-- Sangre: en el suelo { x, y, z } y en las paredes { x, y, z, normal }.
	for _, s in {
		{ -8, ABAJO, -6 }, { 6, ABAJO, -22 }, { 34.2, ABAJO, 28 }, { -18, ABAJO, -17 }, { -24, ABAJO, 8 },
		{ -24, ARRIBA, -10 }, { 28, ARRIBA, -20 },
	} do
		mancha(Vector3.new(s[1], s[2] + 0.08, s[3]), Vector3.yAxis, azar:NextNumber(3, 5), SANGRE[azar:NextInteger(1, #SANGRE)],
			Color3.fromRGB(90, 8, 8), azar:NextNumber(0, math.pi * 2))
	end
	for _, s in {
		{ -11.4, ABAJO + 3.5, -2, Vector3.xAxis }, { 14, ABAJO + 4, 32.4, -Vector3.zAxis }, { -38.4, ABAJO + 4, 6, Vector3.xAxis },
		{ -11.4, ARRIBA + 4, -26, Vector3.xAxis },
	} do
		mancha(Vector3.new(s[1], s[2], s[3]), s[4], azar:NextNumber(2.5, 4), SANGRE[azar:NextInteger(1, #SANGRE)],
			Color3.fromRGB(90, 8, 8), azar:NextNumber(0, math.pi * 2))
	end
	-- Tablas sueltas y basura (papeles), junto a las paredes.
	for _, sitio in {
		Vector3.new(-9.5, ABAJO, 30.5), Vector3.new(25, ABAJO, 30), Vector3.new(-36, ABAJO, -29),
		Vector3.new(-36, ABAJO, 6), Vector3.new(-9, ARRIBA, 31), Vector3.new(-36.5, ARRIBA, -17), Vector3.new(36, ARRIBA, 12),
	} do
		for i = 1, 3 do
			local tabla = adorno(Vector3.new(0.6, 0.15, azar:NextNumber(3, 6)), CFrame.new(sitio + Vector3.new(azar:NextNumber(-1.5, 1.5),
				0.08 + i * 0.15, azar:NextNumber(-1.5, 1.5))) * CFrame.Angles(0, azar:NextNumber(0, math.pi), 0), Enum.Material.WoodPlanks)
			tabla.Color = Color3.fromRGB(78, 62, 46)
		end
		for _ = 1, 5 do
			local papel = adorno(Vector3.new(0.8, 0.03, 1.1), CFrame.new(sitio + Vector3.new(azar:NextNumber(-3, 3), 0.05,
				azar:NextNumber(-3, 3))) * CFrame.Angles(0, azar:NextNumber(0, math.pi * 2), 0), Enum.Material.Fabric)
			papel.Color = Color3.fromRGB(150, 140, 118)
		end
	end
end

-- Lo que cuenta la historia del vestíbulo (11.8.1), pegado a paredes y suelo ya separados: yeso desconchado bajo el
-- papel y sangre seca (Moderate como máximo, pedido por el usuario): una mano que resbaló por la pared al pie de la
-- escalera, salpicaduras en un peldaño y un arrastre por el lado de la escalera hacia el pasillo del sótano. Las
-- imágenes ya traen su color (tools/blender/sangre.py).
local SANGRE_VESTIBULO = {
	Gotas = "rbxassetid://100856467107255",
	Arrastre = "rbxassetid://95443489334328",
	Salpicadura = "rbxassetid://82919660578513",
	Desconchon = "rbxassetid://97919593855720", -- papel arrancado, con el yeso debajo
}
-- Luz de luna (plan-salas.md, paso 5): entra débil y azulada por una ventana, de `desde` hacia `hacia`. Floja, que de
-- noche siga mandando la oscuridad, y sin sombras (las lámparas ya las hacen: dos en la misma sala pesan en móvil).
local function luzLuna(desde: Vector3, hacia: Vector3, brillo: number, alcance: number)
	local luna = adorno(Vector3.new(1, 1, 1), CFrame.lookAt(desde, hacia))
	luna.Transparency = 1
	local foco = Instance.new("SpotLight")
	foco.Color = Color3.fromRGB(120, 140, 190)
	foco.Brightness = brillo
	foco.Range = alcance
	foco.Angle = 45
	foco.Shadows = false
	foco.Face = Enum.NormalId.Front
	foco.Parent = luna
end

local function vestirVestibulo()
	local blanco = Color3.new(1, 1, 1)
	for _, d in {
		{ -8, ABAJO + 8, -32.42, Vector3.zAxis, 3.5 }, { 7, ARRIBA + 7, -32.42, Vector3.zAxis, 4.5 },
		{ 11.42, ABAJO + 9, -4, -Vector3.xAxis, 3.5 }, { -11.42, ABAJO + 10, -5, Vector3.xAxis, 3 },
		{ 11.42, ARRIBA + 8, -26, -Vector3.xAxis, 4.5 }, { -11.42, ARRIBA + 6, -10, Vector3.xAxis, 3.5 },
	} do
		mancha(Vector3.new(d[1], d[2], d[3]), d[4], d[5], SANGRE_VESTIBULO.Desconchon, Color3.fromRGB(170, 160, 145), d[2] % 3)
	end
	-- Luz de luna: entra por la ventana alta de encima de la puerta y cae sobre la alfombra.
	luzLuna(Vector3.new(0, ARRIBA + 5, -31.8), Vector3.new(0, ABAJO, -19), 2, 40)
	mancha(Vector3.new(11.2, ABAJO + 5.2, -12), -Vector3.xAxis, 4.5, SANGRE_VESTIBULO.Gotas, blanco, 0)
	mancha(Vector3.new(1.5, ABAJO + 6.1, -18 + 5.5 * 18 / 13), Vector3.yAxis, 1.6, SANGRE_VESTIBULO.Salpicadura, blanco, 2) -- peldaño 6
	mancha(Vector3.new(7.6, ABAJO + 0.08, -9), Vector3.yAxis, 3.4, SANGRE_VESTIBULO.Arrastre, blanco, 0, 10)
	mancha(Vector3.new(5.2, ABAJO + 0.08, 3.5), Vector3.yAxis, 3, SANGRE_VESTIBULO.Arrastre, blanco, 0.35, 9)
end

-- Torre de la esquina de delante (construirTorre, más abajo).
local TORRE = { x = 39, z = -33, apotema = 8 }

-- Lo que cuenta la historia del salón (11.8.2): papel desconchado, hollín delante del hogar y huellas de algo con uñas
-- que salió de la chimenea y fue hacia el vestíbulo (el Trepador baja por ahí), una mano de sangre seca en la pared del
-- rincón de lectura y una salpicadura junto a la butaca (Moderate como máximo). Luna por el ventanal y la torre.
local HOLLIN = { Hollin = "rbxassetid://93752217357412", Huellas = "rbxassetid://115119002468912" }
local function vestirSalon()
	local blanco = Color3.new(1, 1, 1)
	for _, d in {
		{ 20, ABAJO + 8, 4.42, -Vector3.zAxis, 3.5 }, { 38.42, ABAJO + 9, -22, -Vector3.xAxis, 4 },
		{ 12.58, ABAJO + 8.5, -6, Vector3.xAxis, 3 }, { 31.5, ABAJO + 9.5, -32.42, Vector3.zAxis, 3 },
	} do
		mancha(Vector3.new(d[1], d[2], d[3]), d[4], d[5], SANGRE_VESTIBULO.Desconchon, Color3.fromRGB(170, 160, 145), d[2] % 3)
	end
	mancha(Vector3.new(34.4, ABAJO + 0.08, -1), Vector3.yAxis, 4, HOLLIN.Hollin, blanco, math.pi / 2)
	mancha(Vector3.new(30.2, ABAJO + 0.09, -1.4), Vector3.yAxis, 2.6, HOLLIN.Huellas, blanco, math.pi / 2, 5)
	mancha(Vector3.new(38.42, ABAJO + 5, -14.6), -Vector3.xAxis, 3, SANGRE_VESTIBULO.Gotas, Color3.fromRGB(150, 120, 115), 0) -- más oscura: lejos parecía un globo
	mancha(Vector3.new(30.8, ABAJO + 0.08, -12.4), Vector3.yAxis, 1.8, SANGRE_VESTIBULO.Salpicadura, blanco, 1)
	-- La torre (el mirador del salón) va en diagonal y vestirParedes no la ve: su papel, rodapié, suelo y techo, aquí. Suelo
	-- y techo un pelo por detrás de los de la sala, donde se pisan.
	for _, pared in casa:GetChildren() do
		if pared.Name ~= "MuroTorre" or not pared:IsA("BasePart") or pared.Position.Y > ARRIBA then
			continue
		end
		local cf = pared.CFrame
		local dentro = cf.ZVector
		if (Vector3.new(TORRE.x, pared.Position.Y, TORRE.z) - pared.Position):Dot(dentro) < 0 then
			dentro = -dentro
		end
		local function tira(alto: number, y: number, fondo: number): Part
			local pos = Vector3.new(pared.Position.X, y, pared.Position.Z) + dentro * (pared.Size.Z / 2 + 0.01 + fondo / 2)
			return lamina(Vector3.new(pared.Size.X, alto, fondo), CFrame.fromMatrix(pos, cf.XVector, Vector3.yAxis), COLOR.Marco,
				Enum.Material.SmoothPlastic)
		end
		local bajo = pared.Position.Y - pared.Size.Y / 2
		variante(tira(pared.Size.Y - 0.04, pared.Position.Y, 0.04), "PapelSalon")
		if math.abs(bajo - ABAJO) < 0.1 then
			variante(tira(0.9, ABAJO + 0.45, 0.14), "MaderaOscura")
		end
	end
	local radio = TORRE.apotema / math.cos(math.pi / 8)
	for _, d in { { ABAJO + 0.02, "SueloSalon" }, { ABAJO + ALTO - BAJO_TECHO, "TechoSalon" } } do
		local disco = lamina(Vector3.new(0.04, radio * 2, radio * 2), CFrame.new(TORRE.x, d[1], TORRE.z) * CFrame.Angles(0, 0, math.pi / 2),
			COLOR.Marco, Enum.Material.SmoothPlastic)
		disco.Shape = Enum.PartType.Cylinder
		variante(disco, d[2])
	end
	luzLuna(Vector3.new(25, ABAJO + 8, -32.4), Vector3.new(25, ABAJO, -22), 1.5, 26)
	luzLuna(Vector3.new(42.2, ABAJO + 8, -36.2), Vector3.new(39, ABAJO, -31), 1.2, 18)
end

-- Lo que cuenta la historia del comedor (11.8.3): alguien se levantó de golpe de la cena (la silla volcada), se le cayó
-- la copa en el mantel y se lo llevaron a rastras hacia el vestíbulo, agarrándose al marco (mano en la pared). Papel
-- desconchado y luna por la ventana de delante y la del mirador. Moderate como máximo.
local function vestirComedor()
	local blanco = Color3.new(1, 1, 1)
	for _, d in {
		{ -38.42, ABAJO + 9.5, -21, Vector3.xAxis, 3.5 }, { -16, ABAJO + 9, 2.42, -Vector3.zAxis, 3 },
		{ -34, ABAJO + 7.5, -32.42, Vector3.zAxis, 3 },
	} do
		mancha(Vector3.new(d[1], d[2], d[3]), d[4], d[5], SANGRE_VESTIBULO.Desconchon, Color3.fromRGB(170, 160, 145), d[2] % 3)
	end
	mancha(Vector3.new(-23.6, ABAJO + 3.53, -18.6), Vector3.yAxis, 1.6, SANGRE_VESTIBULO.Salpicadura, Color3.fromRGB(150, 110, 110), 1)
	mancha(Vector3.new(-16.5, ABAJO + 0.08, -19.8), Vector3.yAxis, 3, SANGRE_VESTIBULO.Arrastre, blanco, math.pi / 2 + 0.15, 8)
	mancha(Vector3.new(-12.58, ABAJO + 4.6, -12.6), -Vector3.xAxis, 3, SANGRE_VESTIBULO.Gotas, Color3.fromRGB(150, 120, 115), 0)
	luzLuna(Vector3.new(-24, ABAJO + 8, -32.4), Vector3.new(-24, ABAJO, -22), 1.5, 26)
	luzLuna(Vector3.new(-42.4, ABAJO + 8, -10), Vector3.new(-32, ABAJO, -10), 1.2, 22)
end

-- Lo que cuenta la historia de la cocina (11.8.4): alguien cortaba verdura cuando se lo llevaron a rastras hacia la
-- puerta del garaje (unas gotas junto a la tabla, el arrastre por el suelo y la mano en el marco). Pintura desconchada
-- y luna por la ventana del fondo. Moderate como máximo.
local function vestirCocina()
	for _, d in { { -12.58, ABAJO + 9, 8, -Vector3.xAxis, 3 }, { -31, ABAJO + 9.5, 3.58, Vector3.zAxis, 3.5 },
		{ -27, ABAJO + 8.5, 32.42, -Vector3.zAxis, 2.5 } } do
		mancha(Vector3.new(d[1], d[2], d[3]), d[4], d[5], SANGRE_VESTIBULO.Desconchon, Color3.fromRGB(170, 175, 160), d[2] % 3)
	end
	mancha(Vector3.new(-36.2, ABAJO + 3.52, 24.4), Vector3.yAxis, 1.2, SANGRE_VESTIBULO.Gotas, Color3.fromRGB(150, 110, 110), 0.5)
	mancha(Vector3.new(-35.6, ABAJO + 0.08, 20.6), Vector3.yAxis, 3, SANGRE_VESTIBULO.Arrastre, Color3.new(1, 1, 1), 2.2, 6)
	mancha(Vector3.new(-38.42, ABAJO + 4.4, 21.1), Vector3.xAxis, 3, SANGRE_VESTIBULO.Gotas, Color3.fromRGB(150, 120, 115), 0)
	luzLuna(Vector3.new(-34, ABAJO + 8, 32.4), Vector3.new(-30, ABAJO, 22), 1.5, 24)
end

-- Lo que cuenta la historia del pasillo, el baño y el trastero (11.8.5): el arrastre del vestíbulo sigue por la
-- alfombra y acaba bajo la puerta del sótano, cerrada con cadena y candado, con arañazos de uñas y una mano que resbaló
-- (alguien quiso entrar o salir). Una sola bombilla colgando delante. En el baño, el espejo roto de un golpe, una mano
-- en la cortina de la ducha y la luna por la ventana. Papel desconchado. Moderate como máximo.
local MARCAS = { Aranazos = "rbxassetid://72113309993798", Grietas = "rbxassetid://113133657830111" }
local function vestirPasillo()
	local blanco = Color3.new(1, 1, 1)
	for _, d in {
		{ -11.42, ABAJO + 9, 13, Vector3.xAxis, 3.5 }, { 11.42, ABAJO + 8, 24, -Vector3.xAxis, 3 }, { -9, ABAJO + 9.5, 32.42, -Vector3.zAxis, 3 },
		{ 12.58, ABAJO + 9, 23, Vector3.xAxis, 3 }, { 21.42, ABAJO + 9, 16, -Vector3.xAxis, 3 }, { 14, ABAJO + 9, 18.42, -Vector3.zAxis, 2.5 },
	} do
		mancha(Vector3.new(d[1], d[2], d[3]), d[4], d[5], SANGRE_VESTIBULO.Desconchon, Color3.fromRGB(170, 160, 145), d[2] % 3)
	end
	-- El arrastre, encima de la alfombra (0,27 de alto) y a lo largo de ella (con giro 0, el largo va en x).
	mancha(Vector3.new(1, ABAJO + 0.29, 15.5), Vector3.yAxis, 2.6, SANGRE_VESTIBULO.Arrastre, blanco, math.pi / 2 + 0.06, 9)
	mancha(Vector3.new(0.4, ABAJO + 0.29, 25), Vector3.yAxis, 2.6, SANGRE_VESTIBULO.Arrastre, blanco, math.pi / 2 + 0.03, 9)
	-- Puerta del sótano: la cadena va dentro del modelo de la puerta (Casa la quita al abrirla con la llave); los
	-- arañazos y la mano, en la hoja, para que giren con ella.
	local sotano = casa:FindFirstChild("Sotano")
	local cadena = tienda("CadenaPuerta", CFrame.lookAt(Vector3.new(0, ABAJO + 3.2, 32.45), Vector3.new(0, ABAJO + 3.2, 31)), true)
	if sotano and cadena then
		cadena.Name = "Cadena"
		cadena.Parent = sotano
	end
	local hoja = sotano and sotano:FindFirstChild("Hoja") :: BasePart?
	if hoja then
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front -- la cara del pasillo
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.LightInfluence = 1
		gui.Parent = hoja
		for _, m in { { MARCAS.Aranazos, 0.05, 0.28, 0.9, 0.42 }, { SANGRE_VESTIBULO.Gotas, 0.42, 0.42, 0.5, 0.3, Color3.fromRGB(130, 100, 95) } } do
			local imagen = Instance.new("ImageLabel")
			imagen.BackgroundTransparency = 1
			imagen.Image = m[1]
			imagen.ImageColor3 = m[6] or Color3.new(1, 1, 1) -- la mano, más oscura: roja viva parecía pintura
			imagen.Position = UDim2.fromScale(m[2], m[3])
			imagen.Size = UDim2.fromScale(m[4], m[5])
			imagen.Parent = gui
		end
	end
	-- La bombilla: cuelga de un cable en su portalámparas, delante de la puerta. La única luz del pasillo; la enciende el
	-- generador, como las demás.
	local techo = ABAJO + ALTO - BAJO_TECHO
	local abajo = techo - 2.6
	local cable = adorno(Vector3.new(0.06, techo - abajo, 0.06), CFrame.new(0, (techo + abajo) / 2, 28.5), Enum.Material.SmoothPlastic)
	cable.Color = Color3.fromRGB(20, 18, 16)
	tienda("PortalamparasPH", CFrame.new(0, abajo - 0.66, 28.5), true)
	local bombilla = bloque("Lampara", Vector3.new(0.45, 0.45, 0.45), CFrame.new(0, abajo - 0.45, 28.5), COLOR.Lampara, Enum.Material.SmoothPlastic)
	bombilla.Shape = Enum.PartType.Ball
	bombilla.CanCollide = false
	bombilla.CastShadow = false
	local luz = Instance.new("PointLight")
	luz.Color = COLOR.Lampara
	luz.Brightness = 1.1
	luz.Range = 22
	luz.Shadows = true
	luz.Enabled = false
	luz.Parent = bombilla
	table.insert(Mapa.lamparas, bombilla)
	-- Baño: grietas en el espejo, una mano en la cortina corrida y la luna por la ventana.
	mancha(Vector3.new(21.05, ABAJO + 7.1, 30.9), -Vector3.xAxis, 2.4, MARCAS.Grietas, blanco, 0)
	mancha(Vector3.new(17.4, ABAJO + 4.6, 22.95), Vector3.zAxis, 2.6, SANGRE_VESTIBULO.Gotas, Color3.fromRGB(150, 120, 115), 0)
	luzLuna(Vector3.new(17, ABAJO + 8, 32.4), Vector3.new(17, ABAJO, 25), 1.2, 18)
end

-- Lo que cuenta la historia del dormitorio de abajo (11.8.6): arañazos de uñas que salen de debajo de la cama hacia la
-- puerta (y la sangre de abandonar, debajo de la cama), unas gotas a los pies y el papel desconchado. La única luz es la
-- lámpara de la mesilla (la enciende el generador), más la luna por las dos ventanas. Moderate como máximo.
local function vestirDormitorio()
	for _, d in {
		{ 38.42, ABAJO + 9, 25, -Vector3.xAxis, 3 }, { 22.58, ABAJO + 8.5, 16, Vector3.xAxis, 3.5 }, { 36.5, ABAJO + 9, 5.58, Vector3.zAxis, 2.5 },
	} do
		mancha(Vector3.new(d[1], d[2], d[3]), d[4], d[5], SANGRE_VESTIBULO.Desconchon, Color3.fromRGB(170, 160, 145), d[2] % 3)
	end
	-- Los arañazos, a lo largo (giro pi / 2: el largo de la imagen va en z), un poco torcidos hacia la puerta.
	mancha(Vector3.new(34, ABAJO + 0.09, 20.6), Vector3.yAxis, 3, MARCAS.Aranazos, Color3.fromRGB(130, 80, 75), math.pi / 2 + 0.1, 5)
	mancha(Vector3.new(33.1, ABAJO + 0.09, 16.4), Vector3.yAxis, 2.6, MARCAS.Aranazos, Color3.fromRGB(130, 80, 75), math.pi / 2 + 0.2, 4)
	mancha(Vector3.new(35.4, ABAJO + 0.08, 22.6), Vector3.yAxis, 1.2, SANGRE_VESTIBULO.Gotas, Color3.fromRGB(150, 110, 110), 0.7)
	-- La lámpara de la mesilla de la ventana: la bombilla, dentro de la pantalla.
	local lamparita = contraPared("LamparaMesa", 31, ABAJO + 2.47, 32.5, -Vector3.zAxis, true) -- (DELANTE se define más abajo)
	if lamparita then
		for _, d in lamparita:GetDescendants() do
			if d:IsA("BasePart") then
				d.CastShadow = false -- que la pantalla no tape la luz
			end
		end
		local bombilla = bloque("Lampara", Vector3.new(0.4, 0.4, 0.4), lamparita:GetPivot() * CFrame.new(0, 1.7, 0), COLOR.Lampara,
			Enum.Material.SmoothPlastic)
		bombilla.Shape = Enum.PartType.Ball
		bombilla.CanCollide = false
		bombilla.CastShadow = false
		local luz = Instance.new("PointLight")
		luz.Color = COLOR.Lampara
		luz.Brightness = 0.8
		luz.Range = 22
		luz.Shadows = true
		luz.Enabled = false -- la enciende el generador
		luz.Parent = bombilla
		table.insert(Mapa.lamparas, bombilla)
	else
		lampara(Vector3.new(30, ABAJO + ALTO - 0.3, 19))
	end
	luzLuna(Vector3.new(26, ABAJO + 8, 32.4), Vector3.new(27, ABAJO, 22), 1.2, 22)
	luzLuna(Vector3.new(38.4, ABAJO + 8, 15), Vector3.new(30, ABAJO, 15), 1.2, 20)
end

-- Galería (11.8.7, opción A del usuario, "la silla te espera"): al subir la escalera, al fondo y en el centro, una
-- silla de ruedas vieja quieta mirándote de frente bajo la ventana tapiada, con la luna entre las tablas cayendo
-- encima, y la alfombra larga que lleva hasta ella. Arcón contra la pared del dormitorio grande, cuadros grandes (alguno
-- torcido) en los trozos de pared entre puertas y vanos, y dos macetas con plantas secas a los lados de la silla (junto a
-- la barandilla tapaban la puerta del rico y el vano del dormitorio). Sangre seca: gotas delante de la silla y una mano
-- que resbala hasta el arcón; desconchones. Todo contra las paredes: el centro y los vanos, libres.
local function vestirGaleria()
	local DELANTE, OESTE, ESTE = Vector3.new(0, 0, -1), Vector3.new(-1, 0, 0), Vector3.new(1, 0, 0)
	local y = sueloArriba(Vector3.new(0, ARRIBA, 16)) -- el suelo de verdad, algo por encima de ARRIBA
	-- Balaustrada de verdad sobre el hueco (de una pieza: zócalo con moldura, once barrotes torneados y pasamanos ancho;
	-- a_mano.py), con un poste en cada punta. La que choca es invisible (más arriba).
	for _, x in { -8.1, 8.1 } do
		if tienda("BalaustradaGaleria", CFrame.new(x, y, 0.2), true) then
			tienda("PosteEscalera", CFrame.new(math.sign(x) * 4.4, y - 1.4, 0.2), true)
			tienda("PosteEscalera", CFrame.new(math.sign(x) * 11.3, y - 1.4, 0.2), true)
		end
	end
	tienda("AlfombraGaleria", CFrame.new(0.3, y + 0.075, 14.2) * CFrame.Angles(0, math.rad(-1), 0), true)
	tienda("SillaRuedasPH", CFrame.new(0, y, 29.6) * CFrame.Angles(0, math.rad(8), 0))
	contraPared("ArconPH", 11.42, y, 14, OESTE)
	for _, x in { -4.8, 4.8 } do
		tienda("MacetaPH", CFrame.new(x, y, 31.2), true)
		tienda("PlantaSeca", CFrame.new(x, y + 1.45, 31.2) * CFrame.Angles(0, x, 0), true)
	end
	-- { mueble, x, y, z, hacia la sala, escala, torcido (grados) }
	for _, c in {
		{ "CuadroPH2", -7.5, ARRIBA + 3, 32.42, DELANTE, 1.25, 2 }, { "CuadroFamiliaPH", 7.5, ARRIBA + 3.2, 32.42, DELANTE, 1.6, -3 },
		{ "CuadroSalonPH", 11.42, ARRIBA + 4.4, 14, OESTE, 1.2, 0 }, { "CuadroPH1", 11.42, ARRIBA + 4, 22, OESTE, 1.3, 7 },
		{ "CuadroFamiliaPH2", -11.42, ARRIBA + 3.4, 11.2, ESTE, 1.5, -2 }, { "CuadroPH1", -11.42, ARRIBA + 4, 29.5, ESTE, 1.3, -9 },
	} do
		local cuadro = contraPared(c[1], c[2], c[3], c[4], c[5], true)
		if cuadro then
			cuadro:ScaleTo(cuadro:GetScale() * c[6])
			cuadro:PivotTo(cuadro:GetPivot() * CFrame.Angles(0, 0, math.rad(c[7])))
		end
	end
	local blanco = Color3.new(1, 1, 1)
	for _, d in {
		{ 11.42, ARRIBA + 8, 25, -Vector3.xAxis, 3.5 }, { -11.42, ARRIBA + 9, 19.5, Vector3.xAxis, 3 }, { 9.5, ARRIBA + 9.5, 32.42, -Vector3.zAxis, 3 },
	} do
		mancha(Vector3.new(d[1], d[2], d[3]), d[4], d[5], SANGRE_VESTIBULO.Desconchon, Color3.fromRGB(170, 160, 145), d[2] % 3)
	end
	mancha(Vector3.new(3, y + 0.09, 26.8), Vector3.yAxis, 1.4, SANGRE_VESTIBULO.Gotas, blanco, 0.9)
	mancha(Vector3.new(11.42, ARRIBA + 3.2, 18.2), -Vector3.xAxis, 3.5, SANGRE_VESTIBULO.Gotas, blanco, 0)
	-- La luna entra entre las tablas de la ventana tapiada y cae sobre la silla.
	luzLuna(Vector3.new(0, ARRIBA + 5.5, 32.2), Vector3.new(0, ARRIBA, 25), 1.2, 20)
end

-- Dormitorio grande, el de los dueños (11.8.8, opción A del usuario, "cama al fondo"): la cama gótica con dosel de
-- terciopelo burdeos contra la pared del fondo (el escondite de siempre), una mesilla con lámpara a cada lado y el baúl a
-- sus pies; el armario (escondite) en la esquina de la chimenea, con ropa tirada delante; el tocador con espejo en la
-- pared de la entrada y la butaca verde en la torre, mirando a la ventana. Lo que cuenta: a alguien lo sacaron de la
-- cama a rastras (la colcha arrancada hasta el suelo) y se lo llevaron por el balcón: arañazos de uñas y un arrastre de
-- sangre seca hasta la puerta, y una mano en el marco. Moderate como máximo. El centro, libre para correr.
local DORMITORIO_GRANDE = {
	-- La cara de la lámina del suelo de la sala (vestirSuelos): aquí el Piso no se engorda y queda a ARRIBA (medido en
	-- Play; en la galería sí, a ARRIBA + 0,18).
	suelo = ARRIBA + 0.06,
	cama = Vector3.new(24, ARRIBA + 0.06, 3.55), -- el centro de la cama a ras del suelo, con la cabecera hacia +z
}
local function vestirDormitorioGrande()
	local y = DORMITORIO_GRANDE.suelo
	local blanco = Color3.new(1, 1, 1)
	local delante, este, oeste = -Vector3.zAxis, Vector3.xAxis, -Vector3.xAxis
	-- La cama (cama(), en construirCasa): dosel y colcha con su CFrame más el desfase de a_mano.py (ABAJO y CENTRO).
	local lecho = CFrame.lookAt(DORMITORIO_GRANDE.cama, DORMITORIO_GRANDE.cama + Vector3.zAxis) * CFrame.Angles(0, math.pi, 0)
	tienda("DoselCama", lecho * CFrame.new(0, 0.118, 0), true)
	tienda("ColchaDosel", lecho * CFrame.new(-1.775, 0.049, -1.048), true)
	-- Escondido debajo, se mira por la rendija de debajo del pie de la cama (de 1,1 de alto), al lado del baúl: con la
	-- vista de siempre, en medio, se veía el pie de la cama y el baúl.
	for _, modelo in casa:GetChildren() do
		local colchon = modelo.Name == "Cama" and modelo:FindFirstChild("Colchon")
		if colchon and (colchon.Position - DORMITORIO_GRANDE.cama).Magnitude < 4 then
			modelo:SetAttribute("Vista", CFrame.lookAt(Vector3.new(21.4, y + 0.75, -0.4), Vector3.new(17, y + 0.9, -12)))
		end
	end
	tienda("BaulPH", CFrame.new(24, y, -2.25))
	-- Alfombra persa a los pies de la cama (por encima de la lámina del suelo) y un cuadro grande, torcido, entre la
	-- ventana del lado y la torre.
	tienda("AlfombraSalon", CFrame.new(24, y + 0.015, -4.4) * CFrame.Angles(0, math.rad(92), 0), true)
	local cuadro = contraPared("CuadroPH1", 38.42, y + 4.2, -17, oeste, true)
	if cuadro then
		cuadro:PivotTo(cuadro:GetPivot() * CFrame.Angles(0, 0, math.rad(4)))
	end
	-- Mesillas con su lámpara (algo más pequeña: la mesilla es estrecha). Solo la de la entrada hace sombras.
	for i, x in { 18.9, 29.1 } do
		contraPared("MesillaGoticaPH", x, y, 8.42, delante)
		local lamparita = contraPared("LamparaMesa", x + (if i == 1 then -0.2 else 0.3), y + 2.6, 8.42, delante, true)
		if lamparita then
			lamparita:ScaleTo(lamparita:GetScale() * 0.8)
			for _, d in lamparita:GetDescendants() do
				if d:IsA("BasePart") then
					d.CastShadow = false -- que la pantalla no tape la luz
				end
			end
			local bombilla = bloque("Lampara", Vector3.new(0.35, 0.35, 0.35), lamparita:GetPivot() * CFrame.new(0, 1.36, 0), COLOR.Lampara,
				Enum.Material.SmoothPlastic)
			bombilla.Shape = Enum.PartType.Ball
			bombilla.CanCollide = false
			bombilla.CastShadow = false
			local luz = Instance.new("PointLight")
			luz.Color = COLOR.Lampara
			luz.Brightness = 0.7
			luz.Range = 20
			luz.Shadows = i == 1
			luz.Enabled = false -- la enciende el generador
			luz.Parent = bombilla
			table.insert(Mapa.lamparas, bombilla)
		end
	end
	tienda("FotoPH2", CFrame.new(19.6, y + 2.6, 7.3) * CFrame.Angles(0, -0.35, 0), true)
	tienda("DespertadorPH", CFrame.new(28.5, y + 2.6, 7.25) * CFrame.Angles(0, 0.4, 0), true) -- parado
	-- Ropa tirada delante del armario (por encima de la lámina del suelo).
	tienda("RopaTirada", CFrame.new(33.4, y + 0.01, 2.2) * CFrame.Angles(0, 0.5, 0), true)
	-- Tocador de la señora con sus cosas, el espejo encima (rajado) y la banqueta apartada.
	local tocador = contraPared("TocadorPH", 12.58, y, -12, este)
	if tocador then
		tienda("CosasTocador", tocador:GetPivot() * CFrame.new(0.038, 4.361, -0.292), true)
	end
	contraPared("EspejoPH", 12.58, y + 5.25, -12, este, true)
	mancha(Vector3.new(12.82, y + 7.7, -11.7), este, 1.8, MARCAS.Grietas, blanco, 0.4)
	tienda("Banqueta", CFrame.new(16.2, y, -10.9) * CFrame.Angles(0, math.pi / 2 + 0.35, 0))
	-- La torre: la butaca mirando a la ventana grande, con la mesita y la lámpara de aceite (apagada).
	tienda("ButacaVerdePH", CFrame.lookAt(Vector3.new(38.8, y, -30), Vector3.new(44.7, y, -38.7)))
	tienda("MesitaPH", CFrame.lookAt(Vector3.new(42.4, y, -29.4), Vector3.new(40, y, -33)))
	tienda("LamparaAceitePH", CFrame.new(42.2, y + 2.2, -29.6), true)
	-- La torre va en diagonal y vestirParedes no la ve: su papel, rodapié, suelo y techo, aquí (como en vestirSalon).
	-- Suelo y techo más finos que los de la sala y a su misma altura: donde se pisan, quedan dentro y no parpadean.
	for _, pared in casa:GetChildren() do
		if pared.Name ~= "MuroTorre" or not pared:IsA("BasePart") or pared.Position.Y < ARRIBA then
			continue
		end
		local cf = pared.CFrame
		local dentro = cf.ZVector
		if (Vector3.new(TORRE.x, pared.Position.Y, TORRE.z) - pared.Position):Dot(dentro) < 0 then
			dentro = -dentro
		end
		local function tira(alto: number, altura: number, fondo: number): Part
			local pos = Vector3.new(pared.Position.X, altura, pared.Position.Z) + dentro * (pared.Size.Z / 2 + 0.01 + fondo / 2)
			return lamina(Vector3.new(pared.Size.X, alto, fondo), CFrame.fromMatrix(pos, cf.XVector, Vector3.yAxis), COLOR.Marco,
				Enum.Material.SmoothPlastic)
		end
		variante(tira(pared.Size.Y - 0.04, pared.Position.Y, 0.04), "PapelDormitorioGrande")
		if math.abs(pared.Position.Y - pared.Size.Y / 2 - ARRIBA) < 0.3 then
			variante(tira(0.9, y + 0.45, 0.14), "MaderaOscura")
		end
	end
	local radio = TORRE.apotema / math.cos(math.pi / 8)
	for _, d in { { ARRIBA + 0.03, "SueloDormitorioGrande" }, { ARRIBA + ALTO - BAJO_TECHO, "TechoSalon" } } do
		local disco = lamina(Vector3.new(0.04, radio * 2, radio * 2), CFrame.new(TORRE.x, d[1], TORRE.z) * CFrame.Angles(0, 0, math.pi / 2),
			COLOR.Marco, Enum.Material.SmoothPlastic)
		disco.Shape = Enum.PartType.Cylinder
		variante(disco, d[2])
	end
	-- Lo que pasó: la colcha cae hacia la puerta y desde ahí, arañazos y arrastre por el lado de la entrada hasta el
	-- balcón (pegados a la pared: por el centro se corre), y la mano en el marco de la puerta del balcón.
	mancha(Vector3.new(19.6, y + 0.02, -6), Vector3.yAxis, 3.2, SANGRE_VESTIBULO.Arrastre, blanco, math.pi / 2 + 0.08, 10)
	mancha(Vector3.new(18.9, y + 0.02, -16.5), Vector3.yAxis, 3, SANGRE_VESTIBULO.Arrastre, blanco, math.pi / 2 - 0.05, 10)
	mancha(Vector3.new(18.4, y + 0.02, -26.5), Vector3.yAxis, 2.8, SANGRE_VESTIBULO.Arrastre, blanco, math.pi / 2 + 0.04, 9)
	for _, a in { { 20.1, -3.4, 0.12 }, { 19.3, -11, -0.06 }, { 18.6, -21, 0.05 }, { 18.2, -29.6, -0.1 } } do
		mancha(Vector3.new(a[1], y + 0.03, a[2]), Vector3.yAxis, 2.6, MARCAS.Aranazos, Color3.fromRGB(130, 80, 75), math.pi / 2 + a[3], 4.5)
	end
	mancha(Vector3.new(21.2, y + 4.2, -32.42), Vector3.zAxis, 2.2, SANGRE_VESTIBULO.Gotas, Color3.fromRGB(150, 110, 110), 0.3)
	mancha(Vector3.new(21.8, y + 0.02, 0.2), Vector3.yAxis, 1.4, SANGRE_VESTIBULO.Salpicadura, blanco, 1.2)
	-- Papel desconchado.
	for _, d in {
		{ 38.42, y + 9, -17, oeste, 3.5 }, { 30, y + 9.5, 8.42, delante, 3 }, { 12.58, y + 8.5, -24, este, 3 }, { 25, y + 9, -32.42, Vector3.zAxis, 2.5 },
	} do
		mancha(Vector3.new(d[1], d[2], d[3]), d[4], d[5], SANGRE_VESTIBULO.Desconchon, Color3.fromRGB(170, 160, 145), d[2] % 3)
	end
	-- Luna por la ventana del lado, la de delante (junto al balcón) y la grande de la torre.
	luzLuna(Vector3.new(38.4, ARRIBA + 8, -7), Vector3.new(29, ARRIBA, -8), 1.2, 22)
	luzLuna(Vector3.new(27.5, ARRIBA + 8, -32.4), Vector3.new(27, ARRIBA, -22), 1.1, 20)
	luzLuna(Vector3.new(43.6, ARRIBA + 8, -37.6), Vector3.new(37, ARRIBA, -29), 1.2, 18)
end

-- Lavadero, garaje y cobertizo (11.8.12, opción B elegida por el usuario: "el taller del padre"). En el garaje, el coche
-- en medio y el taller entero en la pared del fondo, frente al portón (se ve nada más abrirlo); estanterías de metal al
-- oeste; neumáticos, escalera, bidones y carro de herramientas en la pared de la cocina. Lo que pasó: al padre lo
-- arrastraron del coche al banco (arrastre y gotas) e intentó salir por el portón (arañazos por dentro). En el lavadero,
-- la pila al oeste (lejos de la ventana), la estantería de botes junto a la entrada, la lavadora al lado del armario,
-- el tendedero junto a la entrada y una cuerda de ropa en diagonal, en lo alto. En el cobertizo, el generador contra el
-- fondo (construirCobertizo), sacos, la pala y la regadera. Caras de las paredes, ya con el papel y el azulejo.
local function vestirGaraje()
	local blanco = Color3.new(1, 1, 1)
	local ESTE_V, OESTE_V, NORTE_V, SUR_V = Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis
	local function suelto(nombre: string, cf: CFrame)
		return tienda(nombre, cf, true)
	end
	-- Lámpara de taller colgada del techo de chapa, con su bombilla (la enciende el generador). Sin la malla, la de siempre.
	local function lamparaTaller(x: number, z: number, alcance: number, sombras: boolean)
		local techo = ABAJO + ALTO
		local molde = MUEBLES.LamparaTallerPH
		if not molde then
			lampara(Vector3.new(x, techo - 0.3, z))
			return
		end
		local abajo = techo - (molde:GetAttribute("Tam") :: Vector3).Y
		suelto("LamparaTallerPH", CFrame.new(x, abajo, z))
		local bombilla = bloque("Lampara", Vector3.new(0.4, 0.4, 0.4), CFrame.new(x, abajo + 0.45, z), COLOR.Lampara, Enum.Material.SmoothPlastic)
		bombilla.Shape = Enum.PartType.Ball
		bombilla.CanCollide = false
		bombilla.CastShadow = false
		local luz = Instance.new("PointLight")
		luz.Color = COLOR.Lampara
		luz.Brightness = 1.1
		luz.Range = alcance
		luz.Shadows = sombras
		luz.Enabled = false
		luz.Parent = bombilla
		table.insert(Mapa.lamparas, bombilla)
	end
	local function telarana(pos: Vector3, hacia: Vector3)
		local molde = MUEBLES.Telarana
		if molde then
			local tela = suelto("Telarana", CFrame.lookAt(pos, pos + hacia) - Vector3.new(0, (molde:GetAttribute("Tam") :: Vector3).Y * 0.45, 0))
			if tela then
				tela:ScaleTo(tela:GetScale() * 0.45)
			end
		end
	end

	-- ===== Garaje (x -59..-39, z 3..33) =====
	local G_OESTE, G_ESTE, G_FONDO = -58.45, -39.55, 32.55
	-- El taller: banco largo con el tablero de herramientas (falta el martillo), tornillo, llave grifa y la sierra colgada.
	suelto("BancoTaller", CFrame.new(-49.5, ABAJO, G_FONDO - 1.43))
	suelto("TornilloBancoPH", CFrame.new(-54.2, ABAJO + 3.5, 30.2))
	suelto("LlaveGrifaPH", CFrame.new(-50.2, ABAJO + 3.57, 30.3) * CFrame.Angles(0, 0.4, 0) * CFrame.Angles(math.pi / 2, 0, 0))
	suelto("SerruchoPH", CFrame.new(-47.3, ABAJO + 6.24, 32.3) * CFrame.Angles(0, math.pi / 2, 0))
	suelto("PalancaPH", CFrame.new(-56.2, ABAJO, 32.05) * CFrame.Angles(-0.12, 0.3, 0))
	lamparaTaller(-49.5, 28.6, 16, false)
	lamparaTaller(-49, 18, 26, true)
	-- Estanterías de metal al oeste (la ventana, z 10..14, libre), con cajas, latas, aceite, un cubo y bidones.
	for i, z in { 17.2, 21.7, 26.2 } do
		contraPared("EstanteriaMetalPH", G_OESTE, ABAJO, z, ESTE_V)
		local x = G_OESTE + 1.06
		local function balda(nombre: string, y: number, dz: number, giro: number?)
			suelto(nombre, CFrame.new(x, ABAJO + y, z + dz) * CFrame.Angles(0, (giro or 0) - math.pi / 2, 0))
		end
		if i == 1 then
			balda("CajaCartonPH", 0.5, 0, math.pi / 2)
			balda("AceitePH", 2.6, -1.2, 0.3)
			balda("AceitePH", 2.6, -0.4, -0.2)
			balda("AceitePH", 2.6, 0.6, 0.1)
			balda("LataOxidadaPH", 4.6, -1, 0)
			balda("LatasPH", 4.6, 0.8, 0.2)
			balda("CajaCartonPH", 6.6, 0.3, math.pi / 2 + 0.1)
		elseif i == 2 then
			balda("BidonGasolinaPH", 0.5, -1, 0)
			balda("BidonGasolinaPH", 0.5, 0.9, 0.15)
			balda("CuboPH", 2.6, -0.6, 0.4)
			balda("AceitePH", 4.6, 0.9, 0)
			balda("LatasPH", 6.6, -0.5, -0.3)
		else
			balda("CajaCartonPH", 0.5, 0.2, math.pi / 2 - 0.1)
			balda("TablaPH", 2.6, 0, 0.2)
			balda("CajaCartonPH", 4.6, -0.4, math.pi / 2)
			balda("LataOxidadaPH", 6.6, -0.9, 0)
			balda("LataOxidadaPH", 6.6, 0.5, 1)
		end
	end
	-- Pared de la cocina: neumáticos apilados junto al portón, la escalera de mano, bidones y el carro de herramientas.
	local azar = Random.new(12)
	for k = 0, 3 do
		local centro = Vector3.new(-41.1 + azar:NextNumber(-0.15, 0.15), ABAJO + 0.33 + k * 0.66, 6.6 + azar:NextNumber(-0.15, 0.15))
		suelto("NeumaticoPH", CFrame.new(centro) * CFrame.Angles(0, azar:NextNumber(0, math.pi), 0) * CFrame.Angles(math.pi / 2, 0, 0)
			* CFrame.new(0, -1.2, 0))
	end
	local pila = bloque("Choque", Vector3.new(2.3, 2.6, 2.3), CFrame.new(-41.1, ABAJO + 1.3, 6.6))
	pila.Transparency = 1
	pila.CanQuery = false
	contraPared("EscaleraManoPH", G_ESTE, ABAJO, 11, OESTE_V)
	contraPared("BidonGasolinaPH", G_ESTE, ABAJO, 21.9, OESTE_V)
	contraPared("BidonGasolinaPH", G_ESTE, ABAJO, 23.5, OESTE_V)
	local carro = contraPared("CarroHerramientasPH", G_ESTE, ABAJO, 29.6, OESTE_V)
	if carro then
		suelto("AceitePH", CFrame.new(-41, ABAJO + 3.87, 28.4))
		suelto("LatasPH", CFrame.new(-41.2, ABAJO + 3.87, 30.6) * CFrame.Angles(0, 0.7, 0))
	end
	-- Lo que pasó: aceite bajo el coche, el arrastre desde la puerta del conductor hasta el banco, gotas delante del banco
	-- y arañazos por dentro del portón (en la hoja, que sube al abrirlo).
	mancha(Vector3.new(-48.6, ABAJO + 0.08, 14.5), Vector3.yAxis, 5, SANGRE_VESTIBULO.Salpicadura, Color3.fromRGB(28, 24, 20), 0.4)
	mancha(Vector3.new(-52.6, ABAJO + 0.09, 24), Vector3.yAxis, 3, SANGRE_VESTIBULO.Arrastre, blanco, math.pi / 2 - 0.17, 10.5)
	mancha(Vector3.new(-51.2, ABAJO + 0.1, 28.9), Vector3.yAxis, 1.8, SANGRE_VESTIBULO.Gotas, blanco, 0.6)
	mancha(Vector3.new(-53.9, ABAJO + 0.1, 20.5), Vector3.yAxis, 2.6, MARCAS.Aranazos, Color3.fromRGB(130, 80, 75), math.pi / 2 + 0.1, 4)
	local porton = casa:FindFirstChild("Porton")
	local hoja = porton and porton:FindFirstChild("Hoja") :: BasePart?
	if hoja then
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back -- la cara de dentro
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 50
		gui.LightInfluence = 1
		gui.Parent = hoja
		for _, m in {
			{ MARCAS.Aranazos, 0.22, 0.5, 0.3, 0.38 }, { MARCAS.Aranazos, 0.5, 0.58, 0.26, 0.32 },
			{ SANGRE_VESTIBULO.Gotas, 0.4, 0.42, 0.2, 0.22, Color3.fromRGB(130, 100, 95) },
		} do
			local imagen = Instance.new("ImageLabel")
			imagen.BackgroundTransparency = 1
			imagen.Image = m[1]
			imagen.ImageColor3 = m[6] or Color3.fromRGB(150, 120, 110)
			imagen.Position = UDim2.fromScale(m[2], m[3])
			imagen.Size = UDim2.fromScale(m[4], m[5])
			imagen.Parent = gui
		end
	end
	-- Techo de tablas con vigas bajo la chapa (por debajo, la chapa se veía como un camuflaje), aquí y en el cobertizo.
	local function techoTablas(x1: number, x2: number, z1: number, z2: number, alto: number)
		local techo = lamina(Vector3.new(x2 - x1 - 1, 0.06, z2 - z1 - 1), CFrame.new((x1 + x2) / 2, alto - 0.05, (z1 + z2) / 2),
			Color3.fromRGB(60, 46, 34), Enum.Material.WoodPlanks)
		variante(techo, "ParedCobertizo")
		for z = z1 + 2.5, z2 - 1.5, 4 do
			local viga = adorno(Vector3.new(x2 - x1 - 1, 0.6, 0.5), CFrame.new((x1 + x2) / 2, alto - 0.38, z))
			viga.Color = Color3.fromRGB(52, 38, 28)
		end
	end
	techoTablas(-59, -39, 3, 33, ABAJO + ALTO)
	techoTablas(-54, -44, 37, 45.5, ABAJO + 9)
	telarana(Vector3.new(-57.2, ABAJO + ALTO - 0.1, 31.3), Vector3.new(1, 0, -1))
	telarana(Vector3.new(-40.8, ABAJO + ALTO - 0.1, 4.7), Vector3.new(-1, 0, 1))
	luzLuna(Vector3.new(-61, ABAJO + 6.5, 12), Vector3.new(-50, ABAJO, 14), 1.5, 30)

	-- ===== Lavadero (x -26..-12, z 33..45) =====
	local L_OESTE, L_ESTE, L_FONDO, L_SUR = -25.37, -12.63, 44.37, 33.63
	local LY = sueloArriba(Vector3.new(-19, ABAJO, 39), ABAJO) + 0.06 -- la cara de la baldosa (su Piso crece con Separar)
	contraPared("PilaLavar", L_OESTE, LY, 37.9, ESTE_V)
	contraPared("LavadoraVieja", -16, LY, L_FONDO, SUR_V)
	contraPared("Tendedero", L_ESTE, LY, 37.5, OESTE_V)
	suelto("CestaPH", CFrame.new(-13.6, LY, 43.3) * CFrame.Angles(0, 0.3, 0))
	-- Estantería de botes junto a la entrada: cesto, lejía y limpiadores, cubo, latas y una caja.
	if contraPared("EstanteriaMetalPH", -23.2, LY, L_SUR, NORTE_V) then
		local z = L_SUR + 1.06
		for _, b in {
			{ "CestoMimbrePH", -23.2, 0.5, 0.1 }, { "LejiaPH", -24.6, 2.6, 0.3 }, { "LimpiadorPH", -23.8, 2.6, -0.2 },
			{ "LejiaPH", -22, 2.6, 0 }, { "CuboPH", -23.6, 4.6, 0.5 }, { "LatasPH", -21.9, 4.6, 0 },
			{ "CajaCartonPH", -23.2, 6.6, math.pi / 2 },
		} do
			suelto(b[1], CFrame.new(b[2], LY + b[3], z) * CFrame.Angles(0, math.pi + b[4], 0))
		end
	end
	-- La cuerda de tender, en diagonal y en lo alto (la ropa no baja de 6,5 sobre el suelo): de la pared de la entrada a la
	-- del enchufe. Sus puntas, a 3,65 sobre el pivote (a_mano.py).
	local a, b = Vector3.new(-22.1, 0, L_SUR + 0.07), Vector3.new(L_ESTE - 0.07, 0, 40.4)
	local medio = (a + b) / 2
	suelto("CuerdaRopa", CFrame.new(medio.X, ABAJO + 10.3 - 3.654, medio.Z) * CFrame.Angles(0, -math.atan2(b.Z - a.Z, b.X - a.X), 0))
	-- El enchufe del móvil (los bloques que funcionan, en construirCasa): su espalda en el azulejo.
	local enchufe = Vector3.new(L_ESTE - 0.488, ABAJO + 1.126, 41)
	suelto("EnchufeViejo", CFrame.lookAt(enchufe, enchufe + OESTE_V))
	mancha(Vector3.new(-20.5, LY + 0.03, 40.6), Vector3.yAxis, 1.6, SANGRE_VESTIBULO.Gotas, blanco, 2.1)
	luzLuna(Vector3.new(-27.5, ABAJO + 6.5, 42), Vector3.new(-18, ABAJO, 40), 1.5, 24)

	-- ===== Cobertizo (x -54..-44, z 37..45,5) =====
	local C_NORTE, C_SUR = 44.95, 37.55
	local sacos = suelto("SacosPH", CFrame.new(-47.6, ABAJO, C_NORTE - 1.09))
	if sacos then
		sacos:ScaleTo(sacos:GetScale() * 0.5)
		local choque = bloque("Choque", Vector3.new(3.7, 1.4, 1.9), CFrame.new(-47.6, ABAJO + 0.7, C_NORTE - 1.09))
		choque.Transparency = 1
		choque.CanQuery = false
	end
	for k = 0, 2 do
		suelto("SacoCementoPH", CFrame.new(-48.4, ABAJO + k * 0.72, C_SUR + 1.0) * CFrame.Angles(0, math.pi / 2 + (k - 1) * 0.12, 0))
	end
	local cemento = bloque("Choque", Vector3.new(2.6, 2.1, 1.8), CFrame.new(-48.4, ABAJO + 1.05, C_SUR + 1.0))
	cemento.Transparency = 1
	cemento.CanQuery = false
	suelto("RegaderaPH", CFrame.new(-48.1, ABAJO + 2.16, C_SUR + 1.0) * CFrame.Angles(0, 0.5, 0))
	suelto("PalaPH", CFrame.new(-52.9, ABAJO, C_SUR + 0.9) * CFrame.Angles(-0.2, 0.2, 0))
	telarana(Vector3.new(-52.8, ABAJO + 8.9, 44.2), Vector3.new(1, 0, -1))
	luzLuna(Vector3.new(-41.5, ABAJO + 6, 41.5), Vector3.new(-50, ABAJO, 41.5), 1.2, 22)
end

-- Sótano (11.8.13, opción A del usuario, "el banco te espera"): al bajar, al fondo, el banco de carpintero con sus
-- herramientas colgadas y la única bombilla encima; delante, de espaldas a la escalera, una silla sola con las cuerdas
-- cortadas. Caldera de carbón en el rincón del oeste (su tiro entra en la pared), cadenas colgando de una viga junto a
-- ella, despensas con tarros turbios en el este, barriles y una rata en el rincón del este. Un arrastre de sangre va de la
-- silla a la puerta de la caldera; arañazos al pie de la escalera. El centro y el pie de la escalera, libres (la reja,
-- 12.2). Los modelos van con su origen de Blender: `enOrigen` suma el desfase de su caja (CENTRO y ABAJO de a_mano.py).
local function vestirSotano()
	local blanco = Color3.new(1, 1, 1)
	local F = sueloArriba(Vector3.new(0, FONDO_SOTANO, 56), FONDO_SOTANO) -- cara del suelo, tras Separar
	local TECHO = FONDO_SOTANO + 9 - 0.4
	local OESTE, ESTE, FONDO_Z = -11.4, 11.4, 64.95 -- caras de las paredes (Separar las engorda un poco)
	local function suelto(nombre: string, cf: CFrame, conChoque: boolean?)
		return tienda(nombre, cf, not conChoque)
	end
	local function enOrigen(nombre: string, origen: CFrame, centro: Vector3, conChoque: boolean?)
		return suelto(nombre, origen * CFrame.new(centro), conChoque)
	end
	local function choque(tam: Vector3, cf: CFrame)
		local b = bloque("Choque", tam, cf)
		b.Transparency = 1
		b.CanQuery = false
	end

	-- Techo de tablas con vigas (de ellas cuelgan las cadenas).
	for _, z in { 50.5, 54.5, 58.5, 62.5 } do
		local viga = adorno(Vector3.new(23, 0.6, 0.5), CFrame.new(0, TECHO - 0.3, z))
		variante(viga, "TechoSotano")
	end
	-- La piedra sigue por dentro de la escalera (se veían las tablas claras de la fachada), delante de las paredes, que
	-- Separar engorda hasta ±2,38. La pared del este solo llega al suelo del patio hasta z 42,5.
	for _, l in { { -2.33, 33.5, 48.1, 10 }, { 2.33, 33.5, 42.5, ABAJO }, { 2.33, 42.5, 48.1, 10 } } do
		local alto = l[4] - FONDO_SOTANO
		local hoja = lamina(Vector3.new(0.06, alto, l[3] - l[2]), CFrame.new(l[1], FONDO_SOTANO + alto / 2, (l[2] + l[3]) / 2),
			Color3.new(1, 1, 1), Enum.Material.Slate)
		variante(hoja, "ParedSotano")
	end
	-- Y en las puntas de esas paredes, que asoman un poco a la sala.
	for _, x in { -3, 3 } do
		variante(lamina(Vector3.new(1.4, 9, 0.06), CFrame.new(x, FONDO_SOTANO + 4.5, 48.26), Color3.new(1, 1, 1), Enum.Material.Slate),
			"ParedSotano")
	end

	-- El banco de carpintero y lo que cuelga de su tablero (origen = BANCO_SOTANO, a ras del suelo).
	local origenBanco = CFrame.new(BANCO_SOTANO.X, F, BANCO_SOTANO.Z)
	enOrigen("BancoCarpintero", origenBanco, Vector3.new(0, 0, -0.483))
	for _, h in {
		{ "SierraArcoPH", -3.3, 6.6 - 0.44 + 0.08, 1.15, 0 }, { "HachaPH", -2.2, 6.6 - 1.154 + 0.1, 1.17, math.pi / 2 },
		{ "MazoPH", -1.0, 6.6 - 1.117 + 0.1, 1.2, 0 }, { "SerruchoPH", 1.1, 6.6 - 0.668 + 0.08, 1.15, math.pi / 2 },
		{ "BerbiquiPH", 3.2, 6.6 - 1.94 + 0.15, 1.0, 0 }, { "LlaveGrifaPH", -2.8, 5.0 - 1.62 + 0.1, 1.18, 0 },
	} do
		suelto(h[1], origenBanco * CFrame.new(h[2], h[3], h[4]) * CFrame.Angles(0, h[5], 0))
	end
	suelto("CepilloPH", origenBanco * CFrame.new(-0.6, 3.4, -0.3) * CFrame.Angles(0, 0.35, 0))
	suelto("CuboPH", CFrame.new(-6.4, F, 64.1) * CFrame.Angles(0, 0.6, 0))
	suelto("MazaPH", CFrame.new(4.6, F, FONDO_Z - 0.6) * CFrame.Angles(0.18, 0.3, 0))
	-- La bombilla de cadenilla, colgada de un cable encima del banco: la única luz (la enciende el generador).
	local alto = 1.8 -- del techo a lo de arriba del portalámparas: la bombilla, a 6,3 del suelo (sobre la cabeza)
	local cable = adorno(Vector3.new(0.08, alto, 0.08), CFrame.new(-1, TECHO - alto / 2, 60.6), Enum.Material.SmoothPlastic)
	cable.Color = Color3.fromRGB(25, 22, 20)
	local tam = MUEBLES.BombillaCadenillaPH and (MUEBLES.BombillaCadenillaPH:GetAttribute("Tam") :: Vector3)
	if tam then
		suelto("BombillaCadenillaPH", CFrame.new(-1, TECHO - alto - tam.Y, 60.6))
	end
	local bombilla = bloque("Lampara", Vector3.new(0.4, 0.4, 0.4), CFrame.new(-1, TECHO - alto - 0.45, 60.6), COLOR.Lampara,
		Enum.Material.SmoothPlastic)
	bombilla.Shape = Enum.PartType.Ball
	bombilla.CanCollide = false
	bombilla.CastShadow = false
	local luz = Instance.new("PointLight")
	luz.Color = COLOR.Lampara
	luz.Brightness = 1.1
	luz.Range = 26
	luz.Shadows = true
	luz.Enabled = false
	luz.Parent = bombilla
	table.insert(Mapa.lamparas, bombilla)

	-- La silla, de espaldas a la escalera y mirando al banco, con sus cuerdas cortadas.
	local silla = CFrame.lookAt(Vector3.new(2, F, 58.3), Vector3.new(2, F, 60))
	if suelto("SillaSotanoPH", silla, true) then
		suelto("CuerdasSilla", silla * CFrame.new(-0.004, 0.005, -0.68))
	end

	-- La caldera en el rincón del oeste, mirando a la sala: su tiro entra en la pared; el carbón, hacia el sur.
	local caldera = CFrame.lookAt(Vector3.new(OESTE + 2.65, F + 0.06, 51.6), Vector3.new(OESTE + 10, F + 0.06, 51.6))
	if enOrigen("CalderaVieja", caldera, Vector3.new(1.082, -0.06, -0.168)) then
		choque(Vector3.new(4.2, 5.5, 3.8), caldera * CFrame.new(0, 2.75, 0))
		choque(Vector3.new(2.4, 1.2, 2.4), caldera * CFrame.new(3.1, 0.6, -0.2))
	end
	-- Cadenas de la viga, entre la caldera y el rincón del fondo (no chocan).
	enOrigen("CadenasTecho", CFrame.new(-8.8, TECHO - 0.6 - 5.6, 58.5), Vector3.new(0.203, 0.05, 0))

	-- Despensas con tarros en la pared del este; en la segunda, latas y cajas (la chatarra, en el suelo entre las dos).
	local function balda(despensa: Model?, h: number, que: string, giro: number?)
		if despensa then
			local cf = despensa:GetPivot() * CFrame.new(0, h, 0) * CFrame.Angles(0, giro or 0, 0)
			if que == "TarrosSotano" then
				suelto(que, cf * CFrame.new(-0.065, 0, 0.021))
			else
				suelto(que, cf)
			end
		end
	end
	local norte = contraPared("DespensaPH", ESTE, F, 53.4, -Vector3.xAxis)
	balda(norte, 1.6, "TarrosSotano")
	balda(norte, 2.8, "TarrosSotano", math.pi)
	balda(norte, 4.0, "TarrosSotano")
	balda(norte, 5.3, "LatasPH", 0.2)
	balda(norte, 6.9, "CajaCartonPH", math.pi / 2)
	local sur = contraPared("DespensaPH", ESTE, F, 59.4, -Vector3.xAxis)
	balda(sur, 0.4, "CajaCartonPH", math.pi / 2)
	if sur then
		suelto("LataOxidadaPH", sur:GetPivot() * CFrame.new(-1.3, 2.8, 0))
	end
	balda(sur, 4.0, "TarrosSotano", math.pi)
	balda(sur, 5.3, "TarrosSotano")
	suelto("RatoneraPH", CFrame.new(8.3, F, 52) * CFrame.Angles(0, 1.2, 0))

	-- Rincón del este, al fondo: barriles y una rata junto a ellos. Rincón del oeste: dos cajones apilados.
	suelto("BarrilPH", CFrame.new(ESTE - 1.65, F, FONDO_Z - 1.65), true)
	suelto("BarrilPH", CFrame.new(ESTE - 4.8, F, FONDO_Z - 1.6) * CFrame.Angles(0, 1.1, 0), true)
	suelto("RataPH", CFrame.new(8.6, F, 61.1) * CFrame.Angles(0, 2.3, 0))
	suelto("CajonPH", CFrame.new(OESTE + 2.2, F, FONDO_Z - 1.0), true)
	suelto("CajonPH", CFrame.new(OESTE + 2.4, F + 1.57, FONDO_Z - 1.1) * CFrame.Angles(0, 0.15, 0))

	-- Lo que pasó: sangre bajo la silla y un arrastre hasta la puerta de la caldera, gotas delante del banco, arañazos al
	-- pie de la escalera (de ahí sube) y hollín y agua sucia delante de la caldera.
	mancha(Vector3.new(2, F + 0.03, 58.3), Vector3.yAxis, 3.4, SANGRE_VESTIBULO.Salpicadura, blanco, 0.5)
	local desde, hasta = Vector3.new(1.2, 0, 57.4), Vector3.new(-6.2, 0, 52.4)
	local medio = (desde + hasta) / 2
	mancha(Vector3.new(medio.X, F + 0.035, medio.Z), Vector3.yAxis, 2.6, SANGRE_VESTIBULO.Arrastre, blanco,
		-math.atan2(hasta.Z - desde.Z, hasta.X - desde.X), (hasta - desde).Magnitude)
	mancha(Vector3.new(-2.6, F + 0.04, 61.2), Vector3.yAxis, 1.6, SANGRE_VESTIBULO.Gotas, blanco, 1.1)
	mancha(Vector3.new(0.2, F + 0.03, 50.2), Vector3.yAxis, 3, MARCAS.Aranazos, Color3.fromRGB(130, 80, 75), math.pi / 2 + 0.15, 4)
	mancha(Vector3.new(-5.9, F + 0.025, 51.4), Vector3.yAxis, 3.2, SANGRE_VESTIBULO.Salpicadura, Color3.fromRGB(25, 22, 20), 1.9)

	-- Telarañas en los rincones del techo.
	local molde = MUEBLES.Telarana
	if molde then
		for _, t in {
			{ OESTE + 0.4, 48.6, Vector3.new(1, 0, 1) }, { ESTE - 0.4, 48.6, Vector3.new(-1, 0, 1) },
			{ OESTE + 0.4, FONDO_Z - 0.4, Vector3.new(1, 0, -1) }, { ESTE - 0.4, FONDO_Z - 0.4, Vector3.new(-1, 0, -1) },
		} do
			local pos = Vector3.new(t[1], TECHO - 0.1, t[2])
			local tela = suelto("Telarana", CFrame.lookAt(pos, pos + t[3]) - Vector3.new(0, (molde:GetAttribute("Tam") :: Vector3).Y * 0.45, 0))
			if tela then
				tela:ScaleTo(tela:GetScale() * 0.45)
			end
		end
	end
end

-- Habitación del rico (11.8.9, opción B del usuario, "despacho y trofeos"). Junto a la puerta, el despacho: escritorio
-- contra la pared de los niños con la lámpara de banquero (la única luz de la sala, la enciende el generador) y el
-- diario abierto (sitio de la pista 11, tarea 12.1), el sillón, el tablero de corcho con el mapa del bosque y las fotos
-- de los vigilantes que mandó (tachadas en rojo, la última con un círculo), el globo y el reloj parado. Al fondo, la
-- sala de trofeos: cuernos de ciervo a los lados de la ventana del oeste, librerías con el toro y el león de bronce
-- encima, a los lados de la de delante, dos butacas con la mesita y el ajedrez, el mueble de licores y el retrato del
-- rico abierto como una puerta sobre la caja fuerte empotrada (sitio de la pista 12). El centro, libre para correr.
local function vestirHabitacionRico()
	local Y = sueloArriba(Vector3.new(-25.5, ARRIBA, -12)) + 0.06 -- cara de la lámina, sobre el Piso final de Separar
	local NORTE, SUR, OESTE_X, ESTE_X = 8.15, -32.25, -38.05, -12.85 -- caras de las paredes, con el papel y la moldura
	local AL_SUR, AL_NORTE, AL_ESTE, AL_OESTE = -Vector3.zAxis, Vector3.zAxis, Vector3.xAxis, -Vector3.xAxis
	-- Lo que cuelga con la espalda en su pivote (cuernos, caja fuerte), pegado a la pared.
	local function enPared(nombre: string, punto: Vector3, frente: Vector3, giro: number?): Model?
		local pos = punto + frente * 0.02
		return tienda(nombre, CFrame.lookAt(pos, pos + frente) * CFrame.Angles(0, 0, giro or 0), true)
	end

	-- Despacho. El escritorio, girado: los cajones y el hueco de las piernas miran a la sala, donde está el sillón.
	local mesa = CFrame.new(-24, Y, 6.6) * CFrame.Angles(0, math.pi, 0)
	tienda("EscritorioRico", mesa)
	tienda("CosasEscritorio", mesa, true)
	tienda("SillonRicoPH", CFrame.lookAt(Vector3.new(-23.6, Y, 3.15), Vector3.new(-24.6, Y, 8)))
	local lamparita = tienda("LamparaBanquero", CFrame.new(-26.8, Y + 2.615, 7.45) * CFrame.Angles(0, math.pi, 0), true)
	if lamparita then
		for _, d in lamparita:GetDescendants() do
			if d:IsA("BasePart") then
				d.CastShadow = false -- que la pantalla no tape la luz
			end
		end
		local bombilla = bloque("Lampara", Vector3.new(0.35, 0.35, 0.35), lamparita:GetPivot() * CFrame.new(0, 1.08, 0), COLOR.Lampara,
			Enum.Material.SmoothPlastic)
		bombilla.Shape = Enum.PartType.Ball
		bombilla.CanCollide = false
		bombilla.CastShadow = false
		local luz = Instance.new("PointLight")
		luz.Color = COLOR.Lampara
		luz.Brightness = 0.9
		luz.Range = 24
		luz.Shadows = true
		luz.Enabled = false -- la enciende el generador
		luz.Parent = bombilla
		table.insert(Mapa.lamparas, bombilla)
	else
		lampara(Vector3.new(-25, ARRIBA + ALTO - 0.3, -14))
	end
	contraPared("TableroHilos", -33, Y + 3.2, NORTE, AL_SUR, true)
	tienda("GloboTerraqueo", CFrame.new(-36.6, Y, 5.4) * CFrame.Angles(0, 0.6, 0))
	contraPared("RelojPiePH", -15, Y, NORTE, AL_SUR) -- fuera del barrido de la puerta (bisagra en z 2, radio 5)

	-- Sala de trofeos.
	for i, z in { -4, -8.5, -21.5, -26 } do
		enPared("CuernosCiervo", Vector3.new(OESTE_X, Y + 5.8, z), AL_ESTE, math.rad(if i % 2 == 0 then 3 else -2))
	end
	for _, l in { { -31, "ToroPH", 0.4 }, { -17, "LeonPH", -0.4 } } do
		local libreria = contraPared("LibreriaPH", l[1], Y, SUR, AL_NORTE)
		for _, sa in libreria and libreria:GetDescendants() or {} do
			if sa:IsA("SurfaceAppearance") then
				sa.Color = Color3.fromRGB(120, 88, 66) -- la madera pálida del salón, aquí más oscura
			end
		end
		local busto = Vector3.new(l[1] + l[3] * 2, Y + 8.25, SUR + 1.2)
		tienda(l[2], CFrame.lookAt(busto, busto + AL_NORTE + Vector3.new(l[3], 0, 0)), true)
		for _, libro in { { 3.84, -1.2 }, { 3.84, 1.0 }, { 5.11, -1.2 }, { 6.65, -0.4 }, { 6.65, 1.6 } } do
			local pos = Vector3.new(l[1] + libro[2], Y + libro[1], SUR + 1.1)
			tienda("EnciclopediaPH", CFrame.lookAt(pos, pos + AL_NORTE), true)
		end
	end
	contraPared("MesitaPH", OESTE_X, Y, -29, AL_ESTE)
	tienda("AjedrezPH", CFrame.new(-37.6, Y + 2.2, -29) * CFrame.Angles(0, 0.3, 0), true)
	tienda("SillonRicoPH", CFrame.lookAt(Vector3.new(-36, Y, -25.6), Vector3.new(-37.4, Y, -29)))
	tienda("SillonRicoPH", CFrame.lookAt(Vector3.new(-35.6, Y, -31.2), Vector3.new(-37.6, Y, -28.6)))
	contraPared("LicoresPH", ESTE_X, Y, -25, AL_OESTE)
	tienda("Licores", CFrame.new(-13.5, Y + 4.2, -25) * CFrame.Angles(0, math.pi / 2, 0), true)
	tienda("AlfombraSalon", CFrame.new(-25.5, Y + 0.02, -20) * CFrame.Angles(0, math.pi / 2, 0), true)
	-- La caja fuerte, y el retrato abierto sobre su borde de -z (la bisagra) para que se vea.
	enPared("CajaFuerte", Vector3.new(ESTE_X, Y + 3.6, -14), AL_OESTE)
	local retrato = contraPared("RetratoRico", ESTE_X, Y + 1.4, -14, AL_OESTE, true)
	if retrato then
		local bisagra = CFrame.new(ESTE_X - 0.4, Y, -14 - 2.77)
		retrato:PivotTo(bisagra * CFrame.Angles(0, math.rad(-50), 0) * bisagra:Inverse() * retrato:GetPivot())
	end

	-- Abandono e historia (Moderate como máximo): desconchones, arañazos de uñas delante de la caja fuerte (algo quiso
	-- abrirla), sangre salpicada junto a ella y unas gotas hacia la puerta.
	for _, d in { { -17.5, Y + 9, NORTE - 0.1, -AL_NORTE, 3 }, { OESTE_X + 0.1, Y + 8.5, -11, AL_ESTE, 2.5 }, { -35, Y + 9.5, SUR + 0.1, AL_NORTE, 3 } } do
		mancha(Vector3.new(d[1], d[2], d[3]), d[4], d[5], SANGRE_VESTIBULO.Desconchon, Color3.fromRGB(170, 160, 145), d[1] % 3)
	end
	mancha(Vector3.new(-15.5, Y + 0.09, -14), Vector3.yAxis, 3, MARCAS.Aranazos, Color3.fromRGB(130, 80, 75), 0.2, 4)
	mancha(Vector3.new(ESTE_X + 0.05, Y + 2.2, -11.2), AL_OESTE, 1.6, SANGRE_VESTIBULO.Salpicadura, Color3.fromRGB(150, 110, 110), 0.4)
	mancha(Vector3.new(-18, Y + 0.08, 0.5), Vector3.yAxis, 1.2, SANGRE_VESTIBULO.Gotas, Color3.fromRGB(150, 110, 110), 1.1)
	-- Telarañas: en la esquina del tablero y entre el reloj y el techo (como las de abandonar).
	for _, t in { { -37, 7, Vector3.new(1, 0, -1) }, { -14, 7, Vector3.new(-1, 0, -1) } } do
		local molde = MUEBLES.Telarana
		if molde then
			local pos = Vector3.new(t[1], ARRIBA + ALTO - BAJO_TECHO - (molde:GetAttribute("Tam") :: Vector3).Y * 0.45, t[2])
			local tela = tienda("Telarana", CFrame.lookAt(pos, pos + t[3]), true)
			if tela then
				tela:ScaleTo(tela:GetScale() * 0.45)
			end
		end
	end
	luzLuna(Vector3.new(-24, ARRIBA + 8, -32.4), Vector3.new(-24, ARRIBA, -22), 1.2, 22)
	luzLuna(Vector3.new(-38.4, ARRIBA + 8, -15), Vector3.new(-30, ARRIBA, -15), 1.2, 20)
end


-- Cuarto de los niños (11.8.10, opción B del usuario, "la merienda de los muñecos"). Dos camas pequeñas de hermanos
-- contra la pared del fondo, una a cada lado de la ventana (la del oeste es el escondite, en construirCasa), con la
-- mesilla y su lámpara (la única luz de la sala, la enciende el generador). Junto a la puerta, la mesita de té con la
-- muñeca, el osito y el conejo sentados y la silla vacía de cara a la puerta, con su trozo de tarta: falta uno. La cuna,
-- sola en el rincón del oeste junto a la pared del rico, con el móvil y arañazos alrededor; el baúl de juguetes volcado en
-- la pared de la ventana del oeste; dibujos de niño con la figura alta y negra en la pared del rico y, debajo, el caballito
-- mirando a la puerta (junto a la ventana tapaba la vista desde debajo de la cama). El centro, libre para correr.
local NINOS = {
	-- La del oeste, el escondite (cabecera contra la pared del fondo), sobre la lámina del suelo: aquí Separar sí engorda
	-- el Piso (su cara queda a ARRIBA + 0,15, medido en Play) y la lámina va 0,06 por encima.
	cama = Vector3.new(-35.6, ARRIBA + 0.21, 28.9),
}
local function vestirNinos()
	local Y = sueloArriba(Vector3.new(-25.5, ARRIBA, 21)) + 0.06
	local NORTE, SUR, OESTE_X, ESTE_X = 9.6, 32.42, -38.3, -12.6 -- caras de las paredes, con el papel
	local AL_SUR, AL_NORTE, AL_ESTE = -Vector3.zAxis, Vector3.zAxis, Vector3.xAxis
	local blanco = Color3.new(1, 1, 1)

	-- La otra cama (sin escondite), la mesilla y la lámpara.
	tienda("CamaNino", CFrame.new(-20.4, Y, SUR - 3.55))
	local mesilla = contraPared("MesillaPH", -16.4, Y, SUR, AL_SUR)
	local alto = if mesilla then (mesilla:GetAttribute("Tam") :: Vector3).Y else 2.46
	local lamparita = tienda("LamparaNino", CFrame.new(-16.4, Y + alto, SUR - 1.1) * CFrame.Angles(0, 0.4, 0), true)
	if lamparita then
		for _, d in lamparita:GetDescendants() do
			if d:IsA("BasePart") then
				d.CastShadow = false -- que la pantalla no tape la luz
			end
		end
		local bombilla = bloque("Lampara", Vector3.new(0.35, 0.35, 0.35), lamparita:GetPivot() * CFrame.new(0, 1.35, 0), COLOR.Lampara,
			Enum.Material.SmoothPlastic)
		bombilla.Shape = Enum.PartType.Ball
		bombilla.CanCollide = false
		bombilla.CastShadow = false
		local luz = Instance.new("PointLight")
		luz.Color = COLOR.Lampara
		luz.Brightness = 0.9
		luz.Range = 24
		luz.Shadows = true
		luz.Enabled = false -- la enciende el generador
		luz.Parent = bombilla
		table.insert(Mapa.lamparas, bombilla)
	else
		lampara(Vector3.new(-25, ARRIBA + ALTO - 0.3, 21))
	end
	tienda("AlfombraTrapo", CFrame.new(-26, Y + 0.015, 21) * CFrame.Angles(0, math.rad(84), 0), true)

	-- La merienda: la silla vacía (la de +X del molde) queda al oeste, de cara a la puerta.
	local mesa = CFrame.new(-16.9, Y, 13.3) * CFrame.Angles(0, math.pi, 0)
	tienda("MesaTe", mesa)
	local centro = mesa.Position + Vector3.new(0, 1, 0)
	for _, s in { { "Muneca", Vector3.new(-1.85, 0, 0), 6 }, { "Osito", Vector3.new(0, 0, -1.85), -9 }, { "Conejo", Vector3.new(0, 0, 1.85), 4 } } do
		local asiento = (mesa * CFrame.new(s[2])).Position + Vector3.new(0, 1, 0)
		tienda(s[1], CFrame.lookAt(asiento, centro) * CFrame.Angles(0, math.rad(s[3]), 0), true)
	end

	-- La cuna en el rincón, con el móvil colgado de su gancho (a 6,1 del suelo), y arañazos de uñas alrededor.
	local cuna = CFrame.new(OESTE_X + 2.75, Y, NORTE + 1.65)
	tienda("CunaNino", cuna)
	tienda("MovilCuna", cuna * CFrame.new(0, 6.1 - 1.57, 0) * CFrame.Angles(0, 0.5, 0), true)
	mancha(Vector3.new(-32, Y + 0.09, 11.2), Vector3.yAxis, 2.6, MARCAS.Aranazos, Color3.fromRGB(130, 80, 75), 1.2, 3.5)
	mancha(Vector3.new(-35.4, Y + 0.09, 14.1), Vector3.yAxis, 2.4, MARCAS.Aranazos, Color3.fromRGB(130, 80, 75), 0.3, 3)

	-- Pared de la ventana del oeste: baúl volcado con los juguetes por el suelo.
	local baul = Vector3.new(OESTE_X + 2.1, Y, 15.3)
	tienda("BaulJuguetes", CFrame.lookAt(baul, baul + Vector3.new(1, 0, 0.15)))
	-- Dibujos de niño en la pared del rico, entre la cuna y la merienda (más grandes, que se lean desde la puerta), y
	-- debajo el caballito, mirando a la puerta.
	local dibujos = contraPared("DibujosNinos", -26.5, Y + 2.1, NORTE, AL_NORTE, true)
	if dibujos then
		dibujos:ScaleTo(dibujos:GetScale() * 1.3)
	end
	local caballo = Vector3.new(-24.2, Y, NORTE + 2.1)
	tienda("Caballito", CFrame.lookAt(caballo, caballo + Vector3.new(1, 0, 0.15)))

	-- Abandono e historia (Moderate como máximo): desconchones, una mano de sangre que resbala por el marco del vano y
	-- unas gotas en el suelo hacia la cuna.
	for _, d in { { -30, Y + 9, SUR, AL_SUR, 3 }, { OESTE_X, Y + 8.5, 28, AL_ESTE, 2.5 }, { -15, Y + 9.5, NORTE, AL_NORTE, 3 } } do
		mancha(Vector3.new(d[1], d[2], d[3]), d[4], d[5], SANGRE_VESTIBULO.Desconchon, Color3.fromRGB(170, 160, 145), d[1] % 3)
	end
	mancha(Vector3.new(ESTE_X, Y + 3.2, 26.6), -AL_ESTE, 3.2, SANGRE_VESTIBULO.Gotas, blanco, 0)
	mancha(Vector3.new(-28, Y + 0.08, 14.8), Vector3.yAxis, 1.6, SANGRE_VESTIBULO.Gotas, Color3.fromRGB(150, 110, 110), 2.1)
	mancha(Vector3.new(-31.6, Y + 0.08, 13.6), Vector3.yAxis, 1.4, SANGRE_VESTIBULO.Gotas, Color3.fromRGB(150, 110, 110), 0.7)
	-- Telarañas: sobre la cuna y en la esquina de la merienda.
	for _, t in { { -37, 11, Vector3.new(1, 0, 1) }, { -14, 11, Vector3.new(-1, 0, 1) } } do
		local molde = MUEBLES.Telarana
		if molde then
			local pos = Vector3.new(t[1], ARRIBA + ALTO - BAJO_TECHO - (molde:GetAttribute("Tam") :: Vector3).Y * 0.45, t[2])
			local tela = tienda("Telarana", CFrame.lookAt(pos, pos + t[3]), true)
			if tela then
				tela:ScaleTo(tela:GetScale() * 0.45)
			end
		end
	end
	luzLuna(Vector3.new(-26, ARRIBA + 8, 32.4), Vector3.new(-26, ARRIBA, 22), 1.2, 22)
	luzLuna(Vector3.new(-38.4, ARRIBA + 8, 21), Vector3.new(-30, ARRIBA, 21), 1.2, 20)
end
-- Escalera del desván y desván (11.8.11, opción B del usuario, "al fondo, la luz roja"). Escalera: peldaños de madera
-- gastada, la pared de al lado llena de fotos de los vigilantes que mandó el rico (tachadas; la última, sin cara), baúles
-- y maletas (una abierta con ropa de hombre) contra la pared de la ventana del lado, espejo tapado y maniquí junto a la
-- del dormitorio y una bombilla colgando. Desván: tablas y vigas a la vista bajo el tejado; desde la trampilla (con su
-- barandilla) se ve al fondo, hacia el oeste, la luz roja del cuarto de revelado del rico, y para llegar se cruza el
-- desván entero entre muebles tapados con sábanas, un maniquí, una rueca y cajas. Dentro: mesa con cubetas, ampliadora,
-- la cámara, las fotos de flash tendidas, la nota (pista 10) y la pistola de bengalas (12.2). La luna entra por los dos
-- ventanucos. El paso del centro, bajo la cumbrera, libre para correr. Moderate como máximo.
local DESVAN = {
	cumbre = 39.4, -- cara de abajo del tejado en la cumbrera (z = 0); baja TEJADO.pendiente por stud hacia los lados
	revelado = { x1 = -30, x2 = -18, z = 6 }, -- el cuarto de revelado: de x1 a x2 y de -z a z (pequeño y agobiante)
	hueco = { x1 = 13, x2 = 17, z1 = 15, z2 = 23 }, -- el hueco de la escalera en el suelo del desván
}
local function vestirDesvan()
	local AL_ESTE, AL_OESTE, AL_NORTE, AL_SUR = Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis
	local blanco = Color3.new(1, 1, 1)
	-- Cara de arriba de la pieza `nombre` que hay en `punto` (Separar engorda suelos y techos).
	local function cara(nombre: string, punto: Vector3, porDefecto: number): number
		for _, pieza in casa:GetChildren() do
			if pieza.Name == nombre and pieza:IsA("BasePart") then
				local d = pieza.CFrame:PointToObjectSpace(punto)
				local arriba = pieza.Position.Y + pieza.Size.Y / 2
				if math.abs(d.X) < pieza.Size.X / 2 and math.abs(d.Z) < pieza.Size.Z / 2 and math.abs(arriba - porDefecto) < 0.5 then
					return arriba
				end
			end
		end
		return porDefecto
	end
	-- Cara de abajo del tejado (y) a una distancia z de la cumbrera.
	local function tejado(z: number): number
		return DESVAN.cumbre - TEJADO.pendiente * math.abs(z)
	end

	-- ESCALERA (x 12..39, z 9..33 arriba). El vano del dormitorio grande llega a la esquina y su cortina de ese lado
	-- atravesaba la pared y asomaba aquí: fuera.
	for _, m in casa:GetChildren() do
		local pos = m:IsA("Model") and m.Name == "CortinaVano" and m:GetPivot().Position
		if pos and pos.X > 12 and pos.Z > 9 and pos.Z < 33 and math.abs(pos.Y - ARRIBA) < 1 then
			m:Destroy()
		end
	end
	-- Peldaños de madera gastada, como el suelo de la galería.
	local Y = sueloArriba(Vector3.new(28, ARRIBA, 21)) + 0.06 -- cara de la lámina del suelo de la sala
	for _, peldano in casa:GetChildren() do
		if peldano.Name == "Peldano" and peldano:IsA("BasePart") and peldano.Position.Y > ARRIBA and math.abs(peldano.Position.X - 15) < 0.1 then
			variante(peldano, "SueloGaleria")
		end
	end
	-- Techo de tablas (como el suelo del desván por debajo), con el hueco de la escalera.
	local alto = ARRIBA + ALTO - BAJO_TECHO
	for _, r in { { 17, 38.5, 9.5, 32.5 }, { 12.5, 17, 9.5, 15 }, { 12.5, 17, 23, 32.5 } } do
		variante(lamina(Vector3.new(r[2] - r[1], 0.06, r[4] - r[3]), CFrame.new((r[1] + r[2]) / 2, alto, (r[3] + r[4]) / 2),
			Color3.fromRGB(62, 50, 40), Enum.Material.WoodPlanks), "TablasDesvan")
	end
	-- Las fotos de los vigilantes, en la pared de al lado de los peldaños (su cara de la sala, con el papel, en x 17,65).
	tienda("FotosVigilantes", CFrame.lookAt(Vector3.new(17.66, Y, 21.4), Vector3.new(18.66, Y, 21.4)), true)
	-- Baúles y maletas en la pared de la ventana del lado (x 39), sin taparla (z 17,5..22,5): el arcón con el baúl
	-- encima, y al otro lado las dos maletas y la abierta, revuelta.
	contraPared("ArconPH", 38.45, Y, 12.6, AL_OESTE)
	local baul = contraPared("BaulPH", 38.45, Y + 2.5, 12.6, AL_OESTE, true)
	if baul then
		baul:PivotTo(baul:GetPivot() * CFrame.Angles(0, math.rad(6), 0))
	end
	contraPared("MaletaPH", 38.45, Y, 28.6, AL_OESTE)
	tienda("MaletaAbierta", CFrame.new(34, Y, 27.2) * CFrame.Angles(0, math.rad(-75), 0))
	contraPared("BaulPH", 33, Y, 32.4, AL_SUR)
	-- Espejo tapado y maniquí junto a la pared del dormitorio grande (z 9).
	contraPared("EspejoTapado", 22.5, Y, 9.55, AL_NORTE)
	tienda("Maniqui", CFrame.lookAt(Vector3.new(30, Y, 11.4), Vector3.new(24, Y, 16)))
	-- La bombilla: cuelga de un cable en medio del cuarto; la enciende el generador.
	local abajo = alto - 2.6
	local cable = adorno(Vector3.new(0.06, alto - abajo, 0.06), CFrame.new(28, (alto + abajo) / 2, 21), Enum.Material.SmoothPlastic)
	cable.Color = Color3.fromRGB(20, 18, 16)
	tienda("PortalamparasPH", CFrame.new(28, abajo - 0.66, 21), true)
	local bombilla = bloque("Lampara", Vector3.new(0.45, 0.45, 0.45), CFrame.new(28, abajo - 0.45, 21), COLOR.Lampara, Enum.Material.SmoothPlastic)
	bombilla.Shape = Enum.PartType.Ball
	bombilla.CanCollide = false
	bombilla.CastShadow = false
	local luz = Instance.new("PointLight")
	luz.Color = COLOR.Lampara
	luz.Brightness = 1.1
	luz.Range = 24
	luz.Shadows = true
	luz.Enabled = false
	luz.Parent = bombilla
	table.insert(Mapa.lamparas, bombilla)
	-- Lo que cuenta: gotas que suben por los peldaños, una mano que resbala en la pared de las fotos y desconchones.
	mancha(Vector3.new(15.2, ARRIBA + 3.03, 25.1), Vector3.yAxis, 1.2, SANGRE_VESTIBULO.Gotas, blanco, 0.4)
	mancha(Vector3.new(14.8, ARRIBA + 8.03, 20.1), Vector3.yAxis, 1, SANGRE_VESTIBULO.Gotas, blanco, 2.1)
	mancha(Vector3.new(17.66, ARRIBA + 3.4, 26), AL_ESTE, 2.4, SANGRE_VESTIBULO.Gotas, Color3.fromRGB(150, 120, 115), 0)
	for _, d in { { 38.4, ARRIBA + 8.5, 26, AL_OESTE, 3 }, { 30, ARRIBA + 9, 32.4, AL_SUR, 3.5 }, { 20, ARRIBA + 7.5, 9.6, AL_NORTE, 2.8 } } do
		mancha(Vector3.new(d[1], d[2], d[3]), d[4], d[5], SANGRE_VESTIBULO.Desconchon, Color3.fromRGB(170, 160, 145), d[2] % 3)
	end
	luzLuna(Vector3.new(38.4, ARRIBA + 7, 20), Vector3.new(30, ARRIBA, 20), 1.2, 20)
	luzLuna(Vector3.new(26, ARRIBA + 7, 32.4), Vector3.new(26, ARRIBA, 25), 1.2, 18)

	-- DESVÁN. Suelo de tablas sin barnizar con el hueco de la escalera.
	local S = cara("Techo", Vector3.new(0, 27, 0), 27) + 0.06 -- cara de la lámina del suelo del desván
	local h = DESVAN.hueco
	for _, r in { { -38.5, h.x1, -33, 33 }, { h.x2, 38.5, -33, 33 }, { h.x1, h.x2, -33, h.z1 }, { h.x1, h.x2, h.z2, 33 } } do
		variante(lamina(Vector3.new(r[2] - r[1], 0.06, r[4] - r[3]), CFrame.new((r[1] + r[2]) / 2, S - 0.03, (r[3] + r[4]) / 2),
			Color3.fromRGB(80, 66, 52), Enum.Material.WoodPlanks), "SueloDesvan")
	end
	-- Abierta por -z, por donde se sube. Su bloque de choque tapaba el hueco entero: chocan tres tablas invisibles.
	tienda("BarandillaTrampilla", CFrame.new((h.x1 + h.x2) / 2, S, (h.z1 + h.z2) / 2), true)
	for _, t in { { Vector3.new(0.3, 3.4, 8.4), Vector3.new(h.x1 - 0.2, 0, (h.z1 + h.z2) / 2) }, { Vector3.new(0.3, 3.4, 8.4), Vector3.new(h.x2 + 0.2, 0, (h.z1 + h.z2) / 2) },
		{ Vector3.new(4.7, 3.4, 0.3), Vector3.new((h.x1 + h.x2) / 2, 0, h.z2 + 0.2) } } do
		local tabla = bloque("Choque", t[1], CFrame.new(t[2] + Vector3.new(0, S + 1.7, 0)))
		tabla.Transparency = 1
		tabla.CanQuery = false
	end
	-- Bajo el tejado: tablas, los pares (vigas inclinadas) cada 4, la viga de la cumbrera y tirantes altos cada 8.
	local inclinacion = math.atan(TEJADO.pendiente)
	local largo = 33.5 / math.cos(inclinacion)
	for _, lado in { 1, -1 } do
		local giro = CFrame.Angles(inclinacion * lado, 0, 0)
		local medio = Vector3.new(0, (tejado(0) + tejado(33.5)) / 2, 16.75 * lado)
		variante(lamina(Vector3.new(77, 0.06, largo), CFrame.new(medio - Vector3.new(0, 0.04, 0)) * giro, Color3.fromRGB(70, 56, 44),
			Enum.Material.WoodPlanks), "TablasDesvan")
		for x = -36, 36, 4 do
			local par = adorno(Vector3.new(0.5, 0.7, largo), CFrame.new(Vector3.new(x, medio.Y, medio.Z)) * giro * CFrame.new(0, -0.42, 0))
			par.Name = "Viga"
			variante(par, "VigaDesvan")
		end
	end
	local cumbrera = adorno(Vector3.new(77, 0.9, 0.7), CFrame.new(0, tejado(0) - 0.45, 0))
	cumbrera.Name = "Viga"
	variante(cumbrera, "VigaDesvan")
	for x = -32, 32, 8 do
		local y = S + 9.2
		local mitad = (DESVAN.cumbre - y) / TEJADO.pendiente
		local tirante = adorno(Vector3.new(0.5, 0.6, 2 * mitad), CFrame.new(x, y, 0))
		tirante.Name = "Viga"
		variante(tirante, "VigaDesvan")
	end
	-- Ventanucos redondos de los hastiales vistos por dentro: el cristal con algo de luna, su cruz y la luz que entra.
	for _, signo in { -1, 1 } do
		local c = Vector3.new(signo * 38.45, 27 + TEJADO.pendiente * 33.5 * 0.36, 0)
		local cristal = adorno(Vector3.new(0.08, 3.6, 3.6), CFrame.new(c), Enum.Material.Glass)
		cristal.Shape = Enum.PartType.Cylinder
		cristal.Color = Color3.fromRGB(62, 74, 96)
		local aro = adorno(Vector3.new(0.06, 4.6, 4.6), CFrame.new(c + Vector3.new(signo * 0.02, 0, 0)))
		aro.Shape = Enum.PartType.Cylinder
		adorno(Vector3.new(0.14, 3.6, 0.2), CFrame.new(c))
		adorno(Vector3.new(0.14, 0.2, 3.6), CFrame.new(c))
		luzLuna(c - Vector3.new(signo * 0.4, 0, 0), Vector3.new(signo * 26, S, 0), 1.3, 26)
	end

	-- El cuarto de revelado al fondo: tabiques de tablas hasta el tejado (los de los lados, a lo largo de x, y los de las
	-- puntas con su pico), la puerta con la cortina negra que deja una rendija y la luz roja de seguridad dentro, siempre
	-- encendida: es lo que se ve desde la trampilla.
	local rv = DESVAN.revelado
	local altoLado = tejado(rv.z) - S
	for _, z in { -rv.z, rv.z } do
		variante(bloque("Tabique", Vector3.new(rv.x2 - rv.x1, altoLado, 0.3), CFrame.new((rv.x1 + rv.x2) / 2, S + altoLado / 2, z)), "TablasDesvan")
	end
	local pico = tejado(0) - tejado(rv.z)
	for _, x in { rv.x1, rv.x2 } do
		local trozos = if x == rv.x2 then { { -rv.z, -2.3 }, { 2.3, rv.z } } else { { -rv.z, rv.z } }
		for _, t in trozos do
			variante(bloque("Tabique", Vector3.new(0.3, altoLado, t[2] - t[1]), CFrame.new(x, S + altoLado / 2, (t[1] + t[2]) / 2)), "TablasDesvan")
		end
		if x == rv.x2 then -- encima de la puerta
			variante(bloque("Tabique", Vector3.new(0.3, altoLado - 7.7, 4.6), CFrame.new(x, S + 7.7 + (altoLado - 7.7) / 2, 0)), "TablasDesvan")
		end
		for _, lado in { -1, 1 } do -- el pico, hasta la cumbrera (un poco más bajo: por la rendija de arriba sale algo de rojo)
			local cuna = Instance.new("WedgePart")
			cuna.Name = "Tabique"
			cuna.Anchored = true
			cuna.Size = Vector3.new(0.3, pico - 0.3, rv.z)
			cuna.CFrame = CFrame.new(x, S + altoLado + (pico - 0.3) / 2, lado * rv.z / 2) * (if lado < 0 then CFrame.identity else CFrame.Angles(0, math.pi, 0))
			cuna.Parent = casa
			variante(cuna, "TablasDesvan")
		end
	end
	tienda("CortinaNegra", CFrame.lookAt(Vector3.new(rv.x2 + 0.25, S, 0), Vector3.new(rv.x2 + 5, S, 0)), true)
	local mesa = CFrame.lookAt(Vector3.new(rv.x1 + 1.75, S, 0), Vector3.new(rv.x2, S, 0))
	tienda("MesaRevelado", mesa)
	tienda("CosasRevelado", mesa, true)
	tienda("CamaraPH", mesa * CFrame.new(-0.3, 3.2, 0.5) * CFrame.Angles(0, math.rad(160), 0), true)
	for _, x in { rv.x1 + 4.5, rv.x1 + 8 } do -- las fotos, a la altura de los ojos
		tienda("FotosTendidas", CFrame.lookAt(Vector3.new(x, S + 6.4, 0), Vector3.new(x + 1, S + 6.4, 0)), true)
	end
	tienda("Banqueta", CFrame.lookAt(Vector3.new(rv.x1 + 4.4, S, 1.2), Vector3.new(rv.x1, S, 0.5)), true)
	tienda("CuboPH", CFrame.new(rv.x1 + 1.2, S, -4.6), true)
	tienda("CajaCartonPH", CFrame.new(rv.x1 + 1.4, S, 4.4) * CFrame.Angles(0, 0.3, 0))
	local roja = bloque("LuzRoja", Vector3.new(0.3, 0.1, 0.3), mesa * CFrame.new(-0.9, 5.9, 0.55), Color3.fromRGB(150, 12, 8), Enum.Material.Neon)
	roja.CanCollide = false
	roja.CanQuery = false
	roja.CastShadow = false
	roja.Transparency = 1
	local rojo = Instance.new("PointLight")
	rojo.Color = Color3.fromRGB(255, 40, 28)
	rojo.Brightness = 1.6
	rojo.Range = 18
	rojo.Shadows = true
	rojo.Parent = roja
	-- Lo que se escapa por la rendija de la cortina y tiñe el suelo de delante: lo que se ve desde la trampilla.
	local rendija = rojo:Clone()
	rendija.Brightness = 0.8
	rendija.Range = 9
	rendija.Shadows = false
	rendija.Parent = adorno(Vector3.new(0.2, 0.2, 0.2), CFrame.new(rv.x2 + 0.6, S + 2.5, 1.2))
	rendija.Parent.Transparency = 1
	-- Arañazos en la tabla de al lado de la puerta, por fuera (algo quiso entrar), y gotas delante de la mesa.
	mancha(Vector3.new(rv.x2 + 0.17, S + 2.6, -4.2), AL_ESTE, 2.6, MARCAS.Aranazos, Color3.fromRGB(120, 70, 60), 0.15)
	mancha(Vector3.new(rv.x1 + 4.5, S + 0.03, -1), Vector3.yAxis, 1.3, SANGRE_VESTIBULO.Gotas, blanco, 1.2)

	-- Muebles tapados y trastos bajo los faldones, a los lados del paso de la cumbrera (|z| < 6, libre).
	tienda("SofaTapado", CFrame.lookAt(Vector3.new(-3, S, 12.2), Vector3.new(-3, S, 0)))
	contraPared("ComodaTapada", 6.5, S, 11.8, AL_SUR)
	tienda("Maniqui", CFrame.lookAt(Vector3.new(-10.5, S, 8.6), Vector3.new(14, S, 14)))
	tienda("ButacaTapada", CFrame.lookAt(Vector3.new(-7, S, -10.8), Vector3.new(-5, S, 0)))
	tienda("EspejoTapado", CFrame.lookAt(Vector3.new(6.5, S, -10.2), Vector3.new(6.5, S, 0)) * CFrame.Angles(math.rad(-6), 0, 0))
	tienda("RuecaPH", CFrame.lookAt(Vector3.new(1, S, -10.5), Vector3.new(0, S, 0)))
	tienda("MecedoraPH", CFrame.lookAt(Vector3.new(-35.4, S, 3), Vector3.new(-39, S, 0))) -- detrás del cuarto, mirando el ventanuco
	tienda("BaulPH", CFrame.lookAt(Vector3.new(-1.5, S, -13.4), Vector3.new(-1.5, S, 0)))
	tienda("MuletasPH", CFrame.lookAt(Vector3.new(35.4, S, 2.6), Vector3.new(30, S, 2.6)) * CFrame.Angles(math.rad(-8), 0, 0), true)
	tienda("ArconPH", CFrame.lookAt(Vector3.new(28, S, -12.2), Vector3.new(28, S, 0)))
	tienda("MaletaPH", CFrame.lookAt(Vector3.new(32.5, S, -13.3), Vector3.new(32.5, S, 0)))
	-- Cajas apiladas: { mueble, x, z, giro (grados), encima de otra }.
	for _, c in {
		{ "CajonPH", -12, -12.6, 10 }, { "CajaCartonPH", -12.3, -12.4, 25, true }, { "CajaCartonPH", -9.6, -13.2, -15 },
		{ "CajonPH", 10.5, 12.4, -5 }, { "CajaCartonPH", 25, 12.8, 30 }, { "CajonPH", 30, 12.6, 0 }, { "CajaCartonPH", 30.2, 12.5, -20, true },
		{ "CajaCartonPH", -14, 11.5, 5 }, { "CajonPH", -36, -10.5, 90 }, { "CajaCartonPH", -36, 11, 70 },
	} do
		local cajon = MUEBLES.CajonPH
		local base = if c[5] and cajon then S + (cajon:GetAttribute("Tam") :: Vector3).Y else S
		tienda(c[1], CFrame.new(c[2], base, c[3]) * CFrame.Angles(0, math.rad(c[4]), 0), c[5] == true)
	end
	-- La bombilla del desván, colgando de la cumbrera junto a la trampilla; la enciende el generador.
	local foco = Vector3.new(9, tejado(0) - 3.4, 3)
	local hilo = adorno(Vector3.new(0.06, 2.5, 0.06), CFrame.new(foco + Vector3.new(0, 1.9, 0)), Enum.Material.SmoothPlastic)
	hilo.Color = Color3.fromRGB(20, 18, 16)
	tienda("PortalamparasPH", CFrame.new(foco - Vector3.new(0, 0.21, 0)), true)
	local bombillaDesvan = bloque("Lampara", Vector3.new(0.45, 0.45, 0.45), CFrame.new(foco), COLOR.Lampara, Enum.Material.SmoothPlastic)
	bombillaDesvan.Shape = Enum.PartType.Ball
	bombillaDesvan.CanCollide = false
	bombillaDesvan.CastShadow = false
	local luzDesvan = luz:Clone()
	luzDesvan.Range = 22
	luzDesvan.Shadows = false -- con la de la escalera debajo, dos con sombras pesan en móvil
	luzDesvan.Parent = bombillaDesvan
	table.insert(Mapa.lamparas, bombillaDesvan)
	-- Telarañas grandes en los rincones de los hastiales con el tejado, en diagonal (de canto parecían una mancha):
	-- { x, z, hacia dónde mira }.
	local tela = MUEBLES.Telarana
	if tela then
		local altoRed = (tela:GetAttribute("Tam") :: Vector3).Y * 0.55
		for _, t in { { -38.3, -10.5, Vector3.new(1, 0, 1) }, { -38.3, 11, Vector3.new(1, 0, -1) }, { 38.3, -9.5, Vector3.new(-1, 0, 1) }, { 38.3, 10.5, Vector3.new(-1, 0, -1) } } do
			local pos = Vector3.new(t[1], tejado(t[2]) - 0.2 - altoRed, t[2])
			local red = tienda("Telarana", CFrame.lookAt(pos, pos + t[3]), true) :: Model
			red:ScaleTo(red:GetScale() * 0.55)
		end
	end

end

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
	construirDesvan()

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
		{ "Motor", CFrame.new(20, 1.1, -52) },
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


	construirCobertizo()
	construirCaballete()
	construirSotano()
	construirFinal() -- reja, palanca y trampilla del sótano; cadenas, pistola y cerillas (12.2)
	construirGaraje()
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

-- El pino de Blender sobre un tronco del bosque: el tronco (un cilindro) se queda para chocar, invisible. Sin las
-- mallas, el tronco gris de siempre. La variedad sale de su sitio, no del azar del bosque (que movería los árboles).
local function pino(tronco: BasePart, x: number, z: number, alto: number, grueso: number)
	local suerte = Random.new(math.floor(x * 31 + z * 17))
	local cual = suerte:NextNumber()
	local nombre = if cual < 0.15 then "PinoSeco" elseif cual < 0.5 then "PinoB" else "Pino"
	local h = alto / 60
	local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, suerte:NextNumber(0, math.pi * 2), 0)
	if #Piezas.poner(tronco, nombre, cf, Vector3.one * h, { Bark = Vector3.new(grueso / 2, h, grueso / 2) }) > 0 then
		tronco.Transparency = 1
		tronco.CastShadow = false
	end
end

-- Lo que hay por el suelo del bosque: rocas y troncos caídos (chocan) y arbustos y helechos (no). Lejos de la casa,
-- del camino y de los sitios (Lugares), con su propio azar: no mueve nada de lo que ya había.
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
			if (math.abs(x) < 10 and z < -24) or junto(x, z) or not Lugares.libre(x, z) then
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
	local azar = Random.new(7)
	local puestos = 0
	while puestos < 260 do
		local angulo = azar:NextNumber(0, math.pi * 2)
		local distancia = azar:NextNumber(48, 420)
		local x, z = math.cos(angulo) * distancia, math.sin(angulo) * distancia
		if not (math.abs(x) < 12 and z < -41) then
			local alto, grueso = azar:NextNumber(50, 85), azar:NextNumber(2, 4.5)
			puestos += 1
			-- Dentro de una zona (Lugares) no se pone, pero cuenta igual: los de fuera no se mueven.
			if not Lugares.libre(x, z) or junto(x, z) then
				continue
			end
			local tronco = bloque("Tronco", Vector3.new(alto, grueso, grueso), CFrame.new(x, alto / 2, z) * CFrame.Angles(0, 0, math.pi / 2),
				COLOR.Tronco, Enum.Material.Wood, bosque)
			tronco.Shape = Enum.PartType.Cylinder
			pino(tronco, x, z, alto, grueso)
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
	bosque.Parent = mapa
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
function Mapa.arbol(x: number, z: number, alto: number, grueso: number, padre: Instance)
	local tronco = bloque("Tronco", Vector3.new(alto, grueso, grueso), CFrame.new(x, alto / 2, z) * CFrame.Angles(0, 0, math.pi / 2),
		COLOR.Tronco, Enum.Material.Wood, padre)
	tronco.Shape = Enum.PartType.Cylinder
	pino(tronco, x, z, alto, grueso)
end

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
				m.LevelOfDetail = Enum.ModelLevelOfDetail.StreamingMesh
				break
			end
		end
	end
end

function Mapa.start()
	local mapa = workspace:WaitForChild("Mapa")
	construirBosque(mapa)
	construirCasa(mapa)
	Lugares.construir(mapa, Mapa)
	local quedan = Separar.caras(mapa) -- que no parpadeen dos caras en el mismo plano
	if quedan > 0 then
		warn(`[Mapa] quedan {quedan} caras que parpadean`)
	end
	-- El papel, los suelos y lo abandonado, después de Separar: van pegados a las paredes con su grosor final.
	vestirParedes()
	vestirSuelos()
	vestirVestibulo()
	vestirSalon()
	vestirComedor()
	vestirCocina()
	vestirPasillo()
	vestirDormitorio()
	vestirGaleria()
	vestirDormitorioGrande()
	vestirHabitacionRico()

	vestirNinos()
	vestirDesvan()

	vestirGaraje()
	vestirSotano()
	abandonar()
	aligerar(mapa)
	porPartes(mapa)
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
end

return Mapa
