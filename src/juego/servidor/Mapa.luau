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

-- Muebles del Creator Store (src/muebles/Muebles.rbxm).
local MUEBLES = game:GetService("ServerStorage"):FindFirstChild("Muebles")
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
	local molde = MUEBLES and MUEBLES:FindFirstChild(nombre)
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
	local molde = MUEBLES and MUEBLES:FindFirstChild(nombre)
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
	-- la sala).
	modelo:SetAttribute("Fuera", Vector3.new(centro.X, h.fueraY or 0, centro.Z) + fuera * 4)
	modelo:SetAttribute("Dentro", Vector3.new(centro.X, suelo, centro.Z) - fuera * 4)
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
local function cama(centro: Vector3, largo: Vector3, lado: number)
	local modelo = Instance.new("Model")
	modelo.Name = "Cama"
	modelo.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- el cliente lo necesita entero
	local cf = CFrame.lookAt(centro, centro + largo) -- -Z = hacia la cabecera
	local trozos = {}
	local function trozo(nombre: string, tamano: Vector3, offset: Vector3, color: Color3?)
		table.insert(trozos, bloque(nombre, tamano, cf * CFrame.new(offset), color or COLOR.Mueble, nil, modelo))
	end
	trozo("Colchon", Vector3.new(5, 1, 8), Vector3.new(0, 2.9, 0), Color3.fromRGB(120, 116, 110))
	trozo("Somier", Vector3.new(5.2, 0.4, 8.2), Vector3.new(0, 2.2, 0))
	trozo("Cabecero", Vector3.new(5.2, 5, 0.4), Vector3.new(0, 2.5, -4.2))
	for _, x in { -2.4, 2.4 } do
		for _, z in { -3.9, 3.9 } do
			trozo("Pata", Vector3.new(0.4, 2, 0.4), Vector3.new(x, 1, z))
		end
	end
	trozo("Almohada", Vector3.new(4, 0.6, 1.4), Vector3.new(0, 3.7, -3.2), Color3.fromRGB(140, 136, 130))
	mueble("Cama", cf, trozos, modelo)
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
	local base = CFrame.new(-50, ABAJO, 41.5)
	local function trozo(nombre: string, tamano: Vector3, offset: CFrame, color: Color3, material: Enum.Material?)
		return bloque(nombre, tamano, base * offset, color, material or Enum.Material.Metal, gen)
	end
	trozo("Cuerpo", Vector3.new(4, 2.4, 2.6), CFrame.new(0, 1.5, 0), Color3.fromRGB(96, 40, 32))
	trozo("Patas", Vector3.new(4.4, 0.3, 2.9), CFrame.new(0, 0.15, 0), COLOR.Oscuro)
	trozo("Deposito", Vector3.new(2.4, 0.8, 1.9), CFrame.new(-0.5, 3.1, 0), Color3.fromRGB(110, 46, 36))
	trozo("Tapon", Vector3.new(0.5, 0.3, 0.5), CFrame.new(-1.2, 3.6, 0), COLOR.Oscuro)
	trozo("Escape", Vector3.new(0.35, 1.6, 0.35), CFrame.new(-1.7, 3.3, -1), COLOR.Oscuro)
	trozo("Motor", Vector3.new(1.4, 1.6, 1.8), CFrame.new(1.4, 1.6, 0), Color3.fromRGB(60, 60, 62), Enum.Material.DiamondPlate)
	trozo("Cuerda", Vector3.new(0.25, 0.25, 0.9), CFrame.new(2.3, 2, 0.3), COLOR.Oscuro, Enum.Material.Plastic)
	-- Indicador de gasolina en el frente: el cliente sube y baja el Nivel.
	trozo("Indicador", Vector3.new(0.1, 1.6, 0.3), CFrame.new(2.05, 1.5, -1.1), Color3.fromRGB(30, 28, 26))
	trozo("Nivel", Vector3.new(0.1, 1.4, 0.18), CFrame.new(2.11, 1.5, -1.1), Color3.fromRGB(170, 140, 60), Enum.Material.SmoothPlastic)
	mando(base * CFrame.new(3.4, 2.4, 0), gen)
	gen:SetAttribute("Tapon", base * CFrame.new(-1.2, 3.8, 0)) -- donde cae la gasolina
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
	local PINTURA, CRISTAL = Color3.fromRGB(78, 88, 96), Color3.fromRGB(120, 135, 140)
	local function trozo(nombre: string, tamano: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): Part
		return bloque(nombre, tamano, base * offset, color, material or Enum.Material.Metal, coche)
	end
	trozo("Chasis", Vector3.new(6.4, 1.6, 12), CFrame.new(0, 1.9, 0), PINTURA)
	trozo("Cabina", Vector3.new(6, 2.4, 5.6), CFrame.new(0, 3.9, 1.4), PINTURA)
	local parabrisas = trozo("Parabrisas", Vector3.new(5.6, 2, 0.2), CFrame.new(0, 3.8, -1.45) * CFrame.Angles(math.rad(-20), 0, 0),
		CRISTAL, Enum.Material.Glass)
	parabrisas.Transparency = 0.5
	for _, lado in { -1, 1 } do
		local ventanilla = trozo("Ventanilla", Vector3.new(0.2, 1.6, 4), CFrame.new(3.02 * lado, 4.1, 1.4), CRISTAL, Enum.Material.Glass)
		ventanilla.Transparency = 0.5
		trozo("Faro", Vector3.new(1.2, 0.6, 0.1), CFrame.new(2.2 * lado, 2.2, -6.05), Color3.fromRGB(200, 195, 170),
			Enum.Material.SmoothPlastic)
	end
	-- Arañazos del bicho en el lado del conductor.
	for i = 1, 3 do
		trozo("Arañazo", Vector3.new(0.1, 0.15, 3.4), CFrame.new(-3.22, 2.3 + i * 0.35, 1) * CFrame.Angles(math.rad(-14), 0, 0),
			Color3.fromRGB(70, 20, 18), Enum.Material.SmoothPlastic)
	end
	-- Capó abierto (la bisagra junto al parabrisas): deja ver el hueco del motor.
	trozo("Capo", Vector3.new(6.2, 0.3, 4.2), CFrame.new(0, 2.8, -1.7) * CFrame.Angles(math.rad(65), 0, 0) * CFrame.new(0, 0, -2.1),
		PINTURA)
	-- Las piezas: Motor, Rueda1..4 (las 1 y 2, las de atrás, ya están), Bateria y Radiador.
	trozo("Motor", Vector3.new(3.2, 2.2, 2.4), CFrame.new(0, 2.4, -4), Color3.fromRGB(70, 72, 75), Enum.Material.DiamondPlate)
	for i, sitio in { { 1, 4 }, { -1, 4 }, { 1, -4 }, { -1, -4 } } do
		local rueda = trozo("Rueda" .. i, Vector3.new(1, 2.6, 2.6), CFrame.new(3.45 * sitio[1], 1.3, sitio[2]), Color3.fromRGB(32, 32, 34),
			Enum.Material.Rubber)
		rueda.Shape = Enum.PartType.Cylinder
		if i > 2 then
			trozo("Ladrillos" .. (i - 2), Vector3.new(1.2, 1.1, 1.6), CFrame.new(2.6 * sitio[1], 0.55, sitio[2]), Color3.fromRGB(120, 60, 48),
				Enum.Material.Brick)
		end
	end
	trozo("Bateria", Vector3.new(1.4, 1, 0.9), CFrame.new(-2.2, 3.2, -5.3), Color3.fromRGB(40, 40, 42), Enum.Material.SmoothPlastic)
	trozo("Radiador", Vector3.new(3, 1.4, 0.3), CFrame.new(0, 2, -6.2), Color3.fromRGB(150, 150, 148))
	mando(base * CFrame.new(0, 2.6, -6.6), coche) -- reparar, delante del capó
	local conducir = mando(base * CFrame.new(-3.8, 3, 0.6), coche) -- huir, en la puerta del conductor
	conducir.Name = "Conducir"
	coche:SetAttribute("Tapon", base * CFrame.new(3.25, 2.4, -1.5)) -- donde cae la gasolina (cerca del capó, para el R)
	coche:SetAttribute("Sitio", base)
	CollectionService:AddTag(coche, "Coche")
	coche.Parent = casa
end

-- Desván bajo el tejado (suelo en y = 27, encima del techo; de alto, 13 en la cumbrera): se sube por la escalera del
-- cuarto cerrado de arriba. Hastiales en los dos lados y el cuarto de revelado del rico.
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
	bloque("MesaRevelado", Vector3.new(6, 3, 3), CFrame.new(10, 28.5, 0), COLOR.Mueble)
	bloque("Cubeta", Vector3.new(1.6, 0.3, 1.2), CFrame.new(9, 30.15, 0), COLOR.Oscuro, Enum.Material.SmoothPlastic)
	bloque("Cuerda", Vector3.new(14, 0.1, 0.1), CFrame.new(10, 32.5, -3), COLOR.Oscuro, Enum.Material.Fabric) -- fotos tendidas
	lampara(Vector3.new(4, 34.5, 0))
end

-- Sótano bajo el patio de atrás: de la puerta del fondo del pasillo (z = 33) baja una escalera tapada (x -3..3) hasta
-- una sala bajo tierra (x -12..12, z 47.6..65.6, suelo en y = -11; encima, el suelo del bosque). El bosque deja un
-- hueco en el suelo encima de la escalera (HUECO). El banco de carpintero, provisional (paso 8).
local HUECO = { -3.5, 3.5, 33.5, 47.6 } -- x1, x2, z1, z2
local function construirSotano()
	local FONDO = -11
	bloque("Rellano", Vector3.new(5, 12, 2), CFrame.new(0, FONDO + 6, 34.5), COLOR.Piso)
	for i = 1, 11 do
		bloque("Peldano", Vector3.new(5, 12 - i, 1.1), CFrame.new(0, FONDO + (12 - i) / 2, 35.5 + (i - 0.5) * 1.1), COLOR.Piso)
	end
	-- Paredes de la escalera: bajo tierra y por fuera (la del este, junto al cobertizo, hasta su suelo).
	Fachada.pared(bloque("Muro", Vector3.new(1, 21, 14.6), CFrame.new(-3, FONDO + 10.5, 40.8)), Vector3.new(-1, 0, 0))
	bloque("Muro", Vector3.new(1, 12, 9), CFrame.new(3, FONDO + 6, 38))
	Fachada.pared(bloque("Muro", Vector3.new(1, 21, 5.6), CFrame.new(3, FONDO + 10.5, 45.3)), Vector3.new(1, 0, 0))
	Fachada.pared(bloque("Muro", Vector3.new(7, 10, 1), CFrame.new(0, 5, 48.1)), Vector3.new(0, 0, 1))
	Fachada.chapa(bloque("Tejadillo", Vector3.new(7, 0.6, 15.1), CFrame.new(0, 10.3, 40.85), COLOR.Oscuro, Enum.Material.CorrodedMetal))
	lampara(Vector3.new(0, 9.6, 41))
	-- La sala.
	local z1, z2, alto = 47.6, 65.6, 9
	bloque("Piso", Vector3.new(25, 1, z2 - z1 + 1), CFrame.new(0, FONDO - 0.5, (z1 + z2) / 2), COLOR.Piso, Enum.Material.Concrete)
	bloque("Techo", Vector3.new(25, 0.4, z2 - z1 + 1), CFrame.new(0, FONDO + alto - 0.2, (z1 + z2) / 2), COLOR.Piso, Enum.Material.Concrete)
	for _, x in { -7.5, 7.5 } do
		bloque("Muro", Vector3.new(10, alto, 1), CFrame.new(x, FONDO + alto / 2, z1), nil, Enum.Material.Concrete)
	end
	bloque("Muro", Vector3.new(25, alto, 1), CFrame.new(0, FONDO + alto / 2, z2), nil, Enum.Material.Concrete)
	for _, x in { -12, 12 } do
		bloque("Muro", Vector3.new(1, alto, z2 - z1), CFrame.new(x, FONDO + alto / 2, (z1 + z2) / 2), nil, Enum.Material.Concrete)
	end
	banco("Sotano", CFrame.lookAt(Vector3.new(-6, FONDO, 63.6), Vector3.new(-6, FONDO, 51)))
	bloque("Estanteria", Vector3.new(1.5, 7, 8), CFrame.new(10.5, FONDO + 3.5, 57), COLOR.Mueble)
	table.insert(Mapa.objetos, { tipo = "Chatarra", cf = CFrame.new(10.5, FONDO + 7.2, 55) })
	lampara(Vector3.new(0, -2.6, 56))
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
	lampara(Vector3.new(-49, ABAJO + ALTO - 0.3, 18))
	construirCoche(CFrame.new(-49, ABAJO, 18))
	banco("Garaje", CFrame.lookAt(Vector3.new(-57.2, ABAJO, 27), Vector3.new(-47, ABAJO, 27)))
	table.insert(Mapa.pesados, { tipo = "Rueda", cf = CFrame.new(-56, ABAJO + 0.5, 8) * CFrame.Angles(0, 0, math.pi / 2) })
	table.insert(Mapa.pesados, { tipo = "Bidon", cf = CFrame.new(-41.5, ABAJO + 1.2, 30.5) })
	for _, z in { 24.5, 29.5 } do
		table.insert(Mapa.objetos, { tipo = "Chatarra", cf = CFrame.new(-57.2, ABAJO + 3.7, z) * CFrame.Angles(0, math.pi / 2, 0) })
	end
end

-- Salas de la casa (pedido por el usuario: grandes y despejadas, los muebles contra las paredes y el centro libre).
-- `papel` = el de las paredes (PAPEL), `suelo` = lo que se pone encima del suelo, `techo` = techo de yeso (no en las
-- salas con hueco de escalera).
local SALAS = {
	-- Salón (11.8.2): papel de rayas de los años 50 sobre papel viejo, rodapié de madera oscura, tablas viejas y techo de
	-- yeso propios de la sala (MaterialVariants).
	{ x1 = 12, x2 = 39, z1 = -33, z2 = 5, y = ABAJO, papel = "PapelSalon", suelo = "SueloSalon", techo = "TechoSalon", rodapie = "MaderaOscura" },
	{ x1 = 22, x2 = 39, z1 = 5, z2 = 33, y = ABAJO, papel = "Rojo", suelo = "Madera", techo = true }, -- dormitorio
	{ x1 = 12, x2 = 22, z1 = 5, z2 = 19, y = ABAJO, papel = "Claro", suelo = "Madera", techo = true }, -- trastero
	{ x1 = 12, x2 = 22, z1 = 19, z2 = 33, y = ABAJO, papel = "Claro", suelo = "Azulejo", techo = true }, -- baño
	-- Vestíbulo (a doble altura; 11.8.1): papel verde oscuro sobre zócalo alto de paneles, parquet en espiga y techo de
	-- yeso agrietado, propios de la sala (plan-salas.md, paso 3).
	{ x1 = -12, x2 = 12, z1 = -33, z2 = 9, y = ABAJO, papel = "Vestibulo", suelo = "ParquetVestibulo", zocalo = "PanelVestibulo" },
	{ x1 = -12, x2 = 12, z1 = 9, z2 = 33, y = ABAJO, papel = "Pasillo", suelo = "Madera", techo = true }, -- pasillo del sótano
	-- Comedor y su mirador (11.8.3): pintura roja oscura que se cae a trozos sobre un zócalo alto de paneles, parquet en
	-- diagonal y techo de gotelé, propios de la sala.
	{ x1 = -39, x2 = -12, z1 = -33, z2 = 3, y = ABAJO, papel = "PapelComedor", suelo = "SueloComedor", techo = "TechoComedor", zocalo = "ZocaloComedor" },
	{ x1 = -43, x2 = -39, z1 = -17, z2 = -3, y = ABAJO, papel = "PapelComedor", suelo = "SueloComedor", techo = "TechoComedor", zocalo = "ZocaloComedor" },
	-- Cocina (11.8.4): pintura verde menta sucia sobre azulejo blanco alargado a media pared, damas sucias y techo
	-- ahumado, propios de la sala.
	{ x1 = -39, x2 = -12, z1 = 3, z2 = 33, y = ABAJO, papel = "PapelCocina", suelo = "SueloCocina", techo = "TechoCocina", azulejo = "AzulejoCocina" },
	{ x1 = -26, x2 = -12, z1 = 33, z2 = 45, y = ABAJO, papel = "Claro", suelo = "Azulejo", techo = true }, -- lavadero
	{ x1 = 12, x2 = 39, z1 = -33, z2 = 9, y = ARRIBA, papel = "Rojo", suelo = "Madera", techo = true }, -- dormitorio grande
	{ x1 = 12, x2 = 39, z1 = 9, z2 = 33, y = ARRIBA, papel = "Claro" }, -- cuarto de la escalera del desván
	{ x1 = -12, x2 = 12, z1 = 0, z2 = 33, y = ARRIBA, papel = "Pasillo", suelo = "Madera", techo = true }, -- galería
	{ x1 = -12, x2 = 12, z1 = -33, z2 = 0, y = ARRIBA, papel = "Vestibulo", techo = "TechoVestibulo" }, -- hueco del vestíbulo
	{ x1 = -39, x2 = -12, z1 = -33, z2 = 9, y = ARRIBA, papel = "Salon", suelo = "Madera", techo = true }, -- habitación del rico
	{ x1 = -39, x2 = -12, z1 = 9, z2 = 33, y = ARRIBA, papel = "Claro", suelo = "Madera", techo = true }, -- cuarto de los niños
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
local function vestirSuelos()
	local azar = Random.new(41) -- siempre igual en todos los servidores
	for _, s in SALAS do
		local ancho, fondo = s.x2 - s.x1 - 1, s.z2 - s.z1 - 1
		local centro = Vector3.new((s.x1 + s.x2) / 2, s.y, (s.z1 + s.z2) / 2)
		if s.suelo == "Madera" then
			lamina(Vector3.new(ancho, 0.06, fondo), CFrame.new(centro + Vector3.new(0, 0.03, 0)), Color3.fromRGB(46, 32, 24),
				Enum.Material.WoodPlanks)
		elseif s.suelo == "Azulejo" then
			lamina(Vector3.new(ancho, 0.06, fondo), CFrame.new(centro + Vector3.new(0, 0.03, 0)), Color3.fromRGB(150, 148, 138),
				Enum.Material.CeramicTiles)
		elseif s.suelo then -- un MaterialVariant propio de la sala (el último: si no, se comía el azulejo)
			variante(lamina(Vector3.new(ancho, 0.06, fondo), CFrame.new(centro + Vector3.new(0, 0.03, 0)), Color3.fromRGB(46, 32, 24),
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
				local suelo = Vector3.new(agujero.X + azar:NextNumber(-1.5, 1.5), s.y + 0.1, agujero.Z + azar:NextNumber(-1.5, 1.5))
				lamina(Vector3.new(azar:NextNumber(0.5, 1.4), 0.14, azar:NextNumber(0.4, 1)), CFrame.new(suelo) * CFrame.Angles(0, k, 0),
					Color3.fromRGB(96, 90, 80), Enum.Material.Plaster)
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
		local molde = MUEBLES and MUEBLES:FindFirstChild(nombre)
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
		{ -38.4, ARRIBA + 8, -6, Vector3.xAxis }, { 34, ARRIBA + 9, 32.4, -Vector3.zAxis }, { -11.4, ARRIBA + 7, -24, Vector3.xAxis },
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
		{ -8, ABAJO, -6 }, { 6, ABAJO, -22 }, { 28, ABAJO, 25 }, { -18, ABAJO, -17 }, { -24, ABAJO, 8 },
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
		Vector3.new(10, ABAJO, 31), Vector3.new(25, ABAJO, 30), Vector3.new(-36, ABAJO, -29),
		Vector3.new(-36, ABAJO, 6), Vector3.new(-9, ARRIBA, 31), Vector3.new(-36, ARRIBA, -30), Vector3.new(36, ARRIBA, 12),
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

-- Cuna del cuarto de los niños: barrotes alrededor de un colchón. Choca una caja invisible. `cf` = el centro a ras del
-- suelo, a lo largo de x.
local function cuna(cf: CFrame)
	local largo, ancho, alto = 5, 2.8, 3.4
	bloque("Colchon", Vector3.new(largo - 0.4, 0.5, ancho - 0.4), cf * CFrame.new(0, 1.6, 0), Color3.fromRGB(120, 112, 100), Enum.Material.Fabric)
	for _, z in { -ancho / 2, ancho / 2 } do
		adorno(Vector3.new(largo, 0.25, 0.25), cf * CFrame.new(0, alto, z))
		adorno(Vector3.new(largo, 0.25, 0.25), cf * CFrame.new(0, 1.3, z))
		for x = -largo / 2, largo / 2 + 0.01, largo / 10 do
			adorno(Vector3.new(0.15, alto - 1.3, 0.15), cf * CFrame.new(x, (alto + 1.3) / 2, z))
		end
	end
	for _, x in { -largo / 2, largo / 2 } do
		for _, z in { -ancho / 2, ancho / 2 } do
			adorno(Vector3.new(0.3, alto + 0.3, 0.3), cf * CFrame.new(x, (alto + 0.3) / 2, z))
		end
		adorno(Vector3.new(0.25, 0.25, ancho), cf * CFrame.new(x, alto, 0))
	end
	local choque = bloque("Choque", Vector3.new(largo, alto, ancho), cf * CFrame.new(0, alto / 2, 0))
	choque.Transparency = 1
	choque.CanQuery = false
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
	-- Barandilla de la galería, al borde del hueco.
	-- Choca invisible y se ven barrotes torneados como los de la escalera, con pasamanos y un poste en cada punta.
	for _, x in { -8.1, 8.1 } do
		local barandilla = bloque("Barandilla", Vector3.new(6.8, 3.5, 0.4), CFrame.new(x, ARRIBA + 1.75, 0.2), COLOR.Mueble)
		if MUEBLES and MUEBLES:FindFirstChild("Balaustre") then
			barandilla.Transparency = 1
			for k = 0, 7 do
				tienda("Balaustre", CFrame.new(x - 3 + k * 6 / 7, ARRIBA, 0.2), true)
			end
			variante(adorno(Vector3.new(6.8, 0.3, 0.4), CFrame.new(x, ARRIBA + 3.35, 0.2)), "MaderaOscura")
			tienda("PosteEscalera", CFrame.new(math.sign(x) * 4.4, ARRIBA - 1.4, 0.2), true)
		end
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
	muro(-26, 33, -26, 45, ABAJO, { v(4, 4, 3, 9, true, true) }, OESTE)
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
	-- Baúles viejos contra las paredes (que no sea una sala vacía).
	for _, b in { { 37, 14, 0.2 }, { 37, 25, -0.1 }, { 30, 31.8, 1.57 } } do
		local cf = CFrame.new(b[1], ARRIBA, b[2]) * CFrame.Angles(0, b[3], 0)
		bloque("Baul", Vector3.new(2.2, 2, 4), cf * CFrame.new(0, 1, 0), Color3.fromRGB(70, 50, 36))
		bloque("Tapa", Vector3.new(2.4, 0.3, 4.2), cf * CFrame.new(0, 2.15, 0), Color3.fromRGB(48, 36, 28))
		adorno(Vector3.new(2.45, 2.1, 0.25), cf * CFrame.new(0, 1.05, 1.2), Enum.Material.Metal).Color = COLOR.Oscuro
		adorno(Vector3.new(2.45, 2.1, 0.25), cf * CFrame.new(0, 1.05, -1.2), Enum.Material.Metal).Color = COLOR.Oscuro
	end

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
	tienda("Perchero", CFrame.new(6.5, ABAJO, -31) * CFrame.Angles(0, math.rad(-20), 0))
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
	contraPared("CuadroPH2", 12.5, ABAJO + 4.6, -27.5, ESTE, true)
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
	for _, z in { -4.6, -15.4 } do
		tienda("MacetaPH", CFrame.new(-41.3, ABAJO, z), true)
		tienda("PlantaSeca", CFrame.new(-41.3, ABAJO + 1.45, z) * CFrame.Angles(0, z, 0), true)
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
	-- Dormitorio: cama con el cabecero contra la pared de atrás, mesilla con lámpara y armario.
	bloque("Mesilla", Vector3.new(2, 2.4, 2), CFrame.new(30.6, ABAJO + 1.2, 31.4), COLOR.Mueble)
	contraPared("LamparaMesa", 30.6, ABAJO + 2.4, 32.5, DELANTE, true)
	-- Trastero: estantería y armario.
	mueble("Estanteria", CFrame.new(16, ABAJO, 6.25) * CFrame.Angles(0, math.pi, 0),
		{ bloque("Estanteria", Vector3.new(6, 7, 1.5), CFrame.new(16, ABAJO + 3.5, 6.25), COLOR.Mueble) })
	-- Baño: bañera de patas contra la pared del trastero, váter y lavabo.
	tienda("Banera", CFrame.lookAt(Vector3.new(16, ABAJO, 21.2), Vector3.new(15, ABAJO, 21.2)))
	contraPared("Vater", 12.5, ABAJO, 28, ESTE)
	mueble("Lavabo", CFrame.lookAt(Vector3.new(20.7, ABAJO, 31), Vector3.new(19.7, ABAJO, 31)))
	local lavabo = bloque("Choque", Vector3.new(1.6, 3, 2.4), CFrame.new(20.7, ABAJO + 1.5, 31))
	lavabo.Transparency = 1
	lavabo.CanQuery = false
	-- Lavadero: estantería, armario y el enchufe del móvil (más abajo).
	mueble("Estanteria", CFrame.new(-24.75, ABAJO, 36.6) * CFrame.Angles(0, -math.pi / 2, 0),
		{ bloque("Estanteria", Vector3.new(1.5, 7, 6), CFrame.new(-24.75, ABAJO + 3.5, 36.6), COLOR.Mueble) })
	-- Arriba. Dormitorio grande: cama, mesilla con lámpara, armario y aparador con lámpara; la torre, libre.
	bloque("Mesilla", Vector3.new(2, 2.4, 2), CFrame.new(31, ARRIBA + 1.2, 7.4), COLOR.Mueble)
	contraPared("LamparaMesa", 31, ARRIBA + 2.4, 8.5, DELANTE, true)
	contraPared("Aparador", 38.5, ARRIBA, -17, OESTE)
	contraPared("LamparaMesa", 38.3, ARRIBA + 3.4, -14.5, OESTE, true)
	-- Habitación del rico: escritorio con lámpara, butaca, caja fuerte, dos librerías y reloj (el diario y cómo matar al
	-- bicho, más adelante).
	mueble("Escritorio", CFrame.new(-26, ARRIBA, -24),
		{ bloque("Escritorio", Vector3.new(6, 3, 3), CFrame.new(-26, ARRIBA + 1.5, -24), COLOR.Mueble) })
	tienda("LamparaMesa", CFrame.new(-28, ARRIBA + 3, -24) * CFrame.Angles(0, math.pi, 0), true) -- en el escritorio
	tienda("ButacaPH", CFrame.lookAt(Vector3.new(-19, ARRIBA, -28), Vector3.new(-26, ARRIBA, -24)))
	bloque("CajaFuerte", Vector3.new(2.5, 3, 2.5), CFrame.new(-36, ARRIBA + 1.5, 6.5), COLOR.Oscuro, Enum.Material.Metal)
	contraPared("Libreria", -38.5, ARRIBA, -27, ESTE)
	contraPared("Libreria", -38.5, ARRIBA, -4, ESTE)
	contraPared("Reloj", -38.5, ARRIBA, 1, ESTE)
	-- Cuarto de los niños: cuna, caja de juguetes con algunos por el suelo y aparador con lámpara.
	cuna(CFrame.new(-33, ARRIBA, 31))
	bloque("Juguetes", Vector3.new(3, 2, 2), CFrame.new(-16, ARRIBA + 1, 31.4), Color3.fromRGB(96, 70, 52))
	for i, j in { { -15, 28, Color3.fromRGB(110, 52, 46) }, { -18, 27, Color3.fromRGB(60, 78, 96) }, { -30, 25, Color3.fromRGB(150, 140, 110) } } do
		local cubo = adorno(Vector3.new(0.8, 0.8, 0.8), CFrame.new(j[1], ARRIBA + 0.4, j[2]) * CFrame.Angles(0, i, 0), Enum.Material.SmoothPlastic)
		cubo.Color = j[3]
	end
	contraPared("Aparador", -25.5, ARRIBA, 9.5, DETRAS)
	contraPared("LamparaMesa", -23, ARRIBA + 3.4, 9.7, DETRAS, true)
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
		{ "Bidon", CFrame.new(-52, ABAJO + 1.2, 44) }, -- en el cobertizo
		{ "Motor", CFrame.new(20, 1.1, -52) },
	} do
		table.insert(Mapa.pesados, { tipo = pesado[1], cf = pesado[2] })
	end

	-- Escondites: las camas de los dos dormitorios y los armarios (dormitorios, trastero y lavadero).
	cama(Vector3.new(34.5, ABAJO, 28.1), DETRAS, 1)
	armario(Vector3.new(24, ABAJO + 4, 12), ESTE)
	armario(Vector3.new(20, ABAJO + 4, 12), OESTE) -- trastero
	armario(Vector3.new(-21, ABAJO + 4, 43), DELANTE) -- lavadero
	cama(Vector3.new(27, ARRIBA, 4.1), DETRAS, 1)
	armario(Vector3.new(35, ARRIBA + 4, 7), DELANTE)

	-- Luces (las enciende el generador) y salas por las que ronda el Golpeador.
	for _, sala in {
		Vector3.new(0, ABAJO, -26), Vector3.new(0, ABAJO, 4.5), Vector3.new(0, ABAJO, 22), Vector3.new(25, ABAJO, -15),
		Vector3.new(28, ABAJO, 12), Vector3.new(-30, ABAJO, -26), Vector3.new(-30, ABAJO, 11), Vector3.new(-19, ABAJO, 39),
		Vector3.new(0, ARRIBA, 18), Vector3.new(25, ARRIBA, -14), Vector3.new(-25, ARRIBA, 21),
	} do
		table.insert(Mapa.salas, sala)
	end
	for _, luz in {
		Vector3.new(0, ABAJO, 4.5), Vector3.new(0, ABAJO, 22), Vector3.new(25, ABAJO, -20), -- en el salón, además, la lámpara de pie
		Vector3.new(30, ABAJO, 19), Vector3.new(17, ABAJO, 12), Vector3.new(17, ABAJO, 26), -- en el comedor, la araña (abajo)
		Vector3.new(-25.5, ABAJO, 18), Vector3.new(-19, ABAJO, 39), Vector3.new(42, ABAJO, -36),
		Vector3.new(0, ARRIBA, 18), Vector3.new(25, ARRIBA, -14), Vector3.new(-25, ARRIBA, -14), Vector3.new(-25, ARRIBA, 21),
		Vector3.new(27, ARRIBA, 21), Vector3.new(42, ARRIBA, -36),
	} do
		lampara(luz + Vector3.new(0, ALTO - 0.3, 0))
	end
	arana(Vector3.new(0, ABAJO + 12, -21), ARRIBA + ALTO - BAJO_TECHO) -- en el hueco del vestíbulo, algo baja
	-- Sobre la mesa del comedor, colgada de su barra (llega al techo).
	arana(Vector3.new(-25.5, ABAJO + ALTO - 5.3, -15), ABAJO + ALTO - BAJO_TECHO, "AranaComedorPH", Vector3.new(0, 1.3, -1.5), 24)


	construirCobertizo()
	construirCaballete()
	construirSotano()
	construirGaraje()
	Fachada.vestir({ ABAJO = ABAJO, ARRIBA = ARRIBA, ALTO = ALTO, TEJADO = TEJADO, TORRE = TORRE })
	-- Mecedora en el porche, mirando al camino (no choca: el porche es para correr).
	tienda("Mecedora", CFrame.new(9, ABAJO, -37.5) * CFrame.Angles(0, math.rad(20), 0), true)
	-- Enchufe del móvil en el lavadero: placa, repisa donde se deja el móvil y lucecita de carga.
	local enchufe = Instance.new("Model")
	enchufe.Name = "Enchufe"
	enchufe.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	bloque("Placa", Vector3.new(0.15, 0.8, 0.6), CFrame.new(-12.55, ABAJO + 2.6, 41), Color3.fromRGB(190, 185, 170),
		Enum.Material.SmoothPlastic, enchufe)
	bloque("Repisa", Vector3.new(1.1, 0.2, 1.4), CFrame.new(-13.05, ABAJO + 1.9, 41), COLOR.Mueble, nil, enchufe)
	bloque("Luz", Vector3.new(0.1, 0.12, 0.12), CFrame.new(-12.64, ABAJO + 3.15, 41), COLOR.Oscuro, Enum.Material.SmoothPlastic,
		enchufe)
	mando(CFrame.new(-13.4, ABAJO + 2.4, 41), enchufe)
	enchufe:SetAttribute("Sitio", CFrame.new(-13.05, ABAJO + 2.15, 41)) -- donde se queda el móvil cargando
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
	-- El suelo, en cuatro trozos alrededor del hueco de la escalera del sótano.
	local x1, x2, z1, z2, L = HUECO[1], HUECO[2], HUECO[3], HUECO[4], 800
	for _, r in { { -L, x1, -L, L }, { x2, L, -L, L }, { x1, x2, -L, z1 }, { x1, x2, z2, L } } do
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
	abandonar()
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
