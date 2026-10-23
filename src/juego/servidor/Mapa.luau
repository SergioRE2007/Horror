-- Genera el mapa por código con bloques grises (el arte llega al final): suelo, bosque de troncos, camino y la casa.
-- La casa (x -39..39, z -33..33): dos plantas. Abajo recibidor y pasillo con la escalera, salón con chimenea, cocina,
-- dormitorio, baño y cuarto de la limpieza; arriba un dormitorio y la habitación del rico. Salas con llave (Llaves): sótano, garaje,
-- desván y habitación del rico. La granja, el aserradero, la torre y el pueblo, en Lugares.
-- Lo que se toca lleva una etiqueta de CollectionService y su estado en atributos (lo maneja Casa o Muerte):
--   "Ventana": cristal y persiana. "Puerta": hoja que gira en la bisagra. "Escondite": armarios y camas.
-- Medidas en studs: suelo de abajo arriba en y = 1, el de arriba en y = 14; paredes de 12 de alto.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Piezas = require(ReplicatedStorage.Shared.Piezas)
local Separar = require(ServerScriptService:WaitForChild("Comun").Separar)
local Lugares = require(script.Parent.Lugares)

-- Muebles del Creator Store (src/muebles/Muebles.rbxm).
local MUEBLES = game:GetService("ServerStorage"):FindFirstChild("Muebles")

local Mapa = {}

local ABAJO, ARRIBA, ALTO = 1, 14, 12
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
	local partes = Piezas.poner(padre or casa, nombre, cf)
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
	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") then
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
	-- Dónde se pone el bicho para golpear (en la hierba) y dónde cae al entrar (en el suelo de la sala).
	modelo:SetAttribute("Fuera", Vector3.new(centro.X, 0, centro.Z) + fuera * 4)
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
		modelo:SetAttribute("Fuera", Vector3.new(pie.X, 0, pie.Z) + fuera * 4)
		modelo:SetAttribute("Dentro", pie - fuera * 4)
	end
	modelo.Parent = casa
	CollectionService:AddTag(modelo, "Puerta")
end

-- Vano abierto (pedido por el usuario: sin puerta donde no hace falta): marco de madera oscura y cortinas oscuras a los
-- lados, por las dos caras. No chocan: no estorban al correr.
local function vanoAbierto(pie: Vector3, eje: Vector3, h)
	local cf = CFrame.fromMatrix(pie + Vector3.new(0, h.alto / 2, 0), eje, Vector3.yAxis)
	marco(cf, h.ancho, h.alto, true)
	for _, cara in { -1, 1 } do
		for _, lado in { -1, 1 } do
			local cortina = adorno(Vector3.new(1.3, h.alto + 0.6, 0.25), cf * CFrame.new(lado * (h.ancho / 2 + 0.25), 0.3, cara * 0.85),
				Enum.Material.Fabric)
			cortina.Color = Color3.fromRGB(30, 22, 22)
		end
		adorno(Vector3.new(h.ancho + 3.4, 0.2, 0.2), cf * CFrame.new(0, h.alto / 2 + 0.6, cara * 0.85), Enum.Material.Metal).Color =
			COLOR.Oscuro
	end
end

-- Pared recta de (x1, z1) a (x2, z2) (crecientes) con huecos: { en = distancia desde el inicio, ancho, bajo, alto,
-- tipo = "Ventana" | "Puerta" | "Vano" | "Hueco", ... }. `fuera` = hacia dónde queda el exterior (paredes de fuera).
local function muro(x1: number, z1: number, x2: number, z2: number, y0: number, huecos, fuera: Vector3?)
	local inicio = Vector3.new(x1, y0, z1)
	local vector = Vector3.new(x2, y0, z2) - inicio
	local largo, eje = vector.Magnitude, vector.Unit
	local enX = math.abs(eje.X) > 0.5
	local function pieza(a: number, b: number, ya: number, yb: number)
		if b - a < 0.05 or yb - ya < 0.05 then
			return
		end
		local centro = inicio + eje * ((a + b) / 2) + Vector3.new(0, (ya + yb) / 2, 0)
		local tamano = if enX then Vector3.new(b - a, yb - ya, 1) else Vector3.new(1, yb - ya, b - a)
		bloque("Muro", tamano, CFrame.new(centro), if fuera then COLOR.Fachada else nil)
	end
	table.sort(huecos, function(a, b)
		return a.en < b.en
	end)
	-- Las de fuera se alargan medio stud para cerrar las esquinas; las de dentro acaban en el centro de la que tocan (si
	-- llegaran a su cara de fuera, asomarían en la fachada).
	local extra = if fuera then 0.5 else 0
	local cursor = -extra
	for _, h in huecos do
		local a, b = h.en - h.ancho / 2, h.en + h.ancho / 2
		pieza(cursor, a, 0, ALTO)
		pieza(a, b, 0, h.bajo or 0)
		pieza(a, b, (h.bajo or 0) + h.alto, ALTO)
		cursor = b
		local pie = inicio + eje * h.en
		if h.tipo == "Ventana" then
			ventana(pie + Vector3.new(0, h.bajo + h.alto / 2, 0), fuera :: Vector3, h, y0)
		elseif h.tipo == "Puerta" then
			puerta(pie, eje, h, fuera)
		elseif h.tipo == "Vano" then
			vanoAbierto(pie, eje, h)
		end
	end
	pieza(cursor, largo + extra, 0, ALTO)
end

local function v(ancho, bajo, alto, en, persiana, atacable)
	return { tipo = "Ventana", en = en, ancho = ancho, bajo = bajo, alto = alto, persiana = persiana, atacable = atacable }
end

local function vano(en, ancho)
	return { tipo = "Vano", en = en, ancho = ancho, bajo = 0, alto = 9 }
end

local function p(en, hacia: Vector3, extra)
	local h = { tipo = "Puerta", en = en, ancho = 4, bajo = 0, alto = 9, hacia = hacia }
	for clave, valor in extra or {} do
		h[clave] = valor
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

-- Cobertizo pegado a la parte de atrás de la casa (x 3..13, z 33.5..42) con el generador; se entra por el este.
local function construirCobertizo()
	local x1, x2, z1, z2, alto = 3, 13, 33.5, 42, 9
	CollectionService:AddTag(bloque("Piso", Vector3.new(x2 - x1, 1, z2 - z1), CFrame.new((x1 + x2) / 2, 0.5, (z1 + z2) / 2), COLOR.Piso),
		"EnMapa")
	bloque("Muro", Vector3.new(x2 - x1 + 1, alto, 1), CFrame.new((x1 + x2) / 2, ABAJO + alto / 2, z2))
	bloque("Muro", Vector3.new(1, alto, z2 - z1), CFrame.new(x1, ABAJO + alto / 2, (z1 + z2) / 2))
	bloque("Muro", Vector3.new(1, alto, 2.5), CFrame.new(x2, ABAJO + alto / 2, z1 + 1.25)) -- este, con la entrada (z 36..41)
	bloque("Muro", Vector3.new(1, alto - 7, 5), CFrame.new(x2, ABAJO + 7 + (alto - 7) / 2, 38.5))
	bloque("Techo", Vector3.new(x2 - x1 + 2, 0.6, z2 - z1 + 1.5), CFrame.new((x1 + x2) / 2, ABAJO + alto + 0.3, (z1 + z2) / 2 + 0.4),
		COLOR.Oscuro, Enum.Material.CorrodedMetal)
	lampara(Vector3.new(8, ABAJO + alto - 0.4, 37.5))

	-- El generador mira al este (a la entrada): la cuerda sale por ese lado.
	local gen = Instance.new("Model")
	gen.Name = "Generador"
	gen.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local base = CFrame.new(8, ABAJO, 39.4)
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
	for _, x in { -2, 2 } do
		for _, lado in { 1, -1 } do
			bloque("Pata", Vector3.new(0.4, 3.2, 0.4), base * CFrame.new(x, 1.5, 0.5 * lado) * CFrame.Angles(math.rad(18 * lado), 0, 0),
				COLOR.Tronco, Enum.Material.Wood, modelo)
		end
	end
	bloque("Viga", Vector3.new(5.6, 0.5, 0.6), base * CFrame.new(0, 3, 0), COLOR.Tronco, Enum.Material.Wood, modelo)
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
	local puerta = mando(base * CFrame.new(-3.8, 3, 0.6), coche) -- huir, en la puerta del conductor
	puerta.Name = "Conducir"
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
	bloque("Muro", Vector3.new(1, 21, 14.6), CFrame.new(-3, FONDO + 10.5, 40.8))
	bloque("Muro", Vector3.new(1, 12, 9), CFrame.new(3, FONDO + 6, 38))
	bloque("Muro", Vector3.new(1, 21, 5.6), CFrame.new(3, FONDO + 10.5, 45.3))
	bloque("Muro", Vector3.new(7, 10, 1), CFrame.new(0, 5, 48.1))
	bloque("Tejadillo", Vector3.new(7, 0.6, 15.1), CFrame.new(0, 10.3, 40.85), COLOR.Oscuro, Enum.Material.CorrodedMetal)
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

-- Garaje junto a la casa, al este (x 47..65, z -14..6): puerta con llave mirando a la casa y portón al camino, que se
-- abre desde que la puerta lo está (Coche). Dentro, tu coche destrozado, el banco del taller, una rueda, un bidón y
-- chatarra. Ventana sin persiana: es una sala cerrada.
local function construirGaraje()
	local OESTE, ESTE = Vector3.new(-1, 0, 0), Vector3.new(1, 0, 0)
	CollectionService:AddTag(bloque("Piso", Vector3.new(19, 1, 21), CFrame.new(56, 0.5, -4), COLOR.Piso, Enum.Material.Concrete), "EnMapa")
	muro(47, -14, 47, 6, ABAJO, { p(10, ESTE, { bloqueada = true, nombre = "Garaje", llave = "LlaveGaraje" }) }, OESTE)
	muro(47, -14, 65, -14, ABAJO, { { tipo = "Hueco", en = 9, ancho = 10, alto = 9 } }, Vector3.new(0, 0, -1))
	local porton = Instance.new("Model")
	porton.Name = "Porton"
	porton.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	bloque("Hoja", Vector3.new(10, 9, 0.4), CFrame.new(56, ABAJO + 4.5, -14), COLOR.Oscuro, Enum.Material.CorrodedMetal, porton)
	-- El mando, en el borde del hueco (como un interruptor): en medio se pisaba con el del capó del coche.
	mando(CFrame.new(50.6, ABAJO + 3.5, -14), porton)
	CollectionService:AddTag(porton, "Porton")
	porton.Parent = casa
	muro(65, -14, 65, 6, ABAJO, { v(4, 4, 3, 12, false) }, ESTE)
	muro(47, 6, 65, 6, ABAJO, {}, Vector3.new(0, 0, 1))
	bloque("Techo", Vector3.new(20, 1, 22), CFrame.new(56, ABAJO + ALTO + 0.5, -4), COLOR.Oscuro, Enum.Material.CorrodedMetal)
	lampara(Vector3.new(56, ABAJO + ALTO - 0.3, -4))
	construirCoche(CFrame.new(55, ABAJO, -4))
	banco("Garaje", CFrame.lookAt(Vector3.new(63.2, ABAJO, -8), Vector3.new(53, ABAJO, -8)))
	table.insert(Mapa.pesados, { tipo = "Rueda", cf = CFrame.new(62, ABAJO + 0.5, 3.5) * CFrame.Angles(0, 0, math.pi / 2) })
	table.insert(Mapa.pesados, { tipo = "Bidon", cf = CFrame.new(49.5, ABAJO + 1.2, 4) })
	for _, z in { -10.5, -5.5 } do
		table.insert(Mapa.objetos, { tipo = "Chatarra", cf = CFrame.new(63.2, ABAJO + 3.7, z) * CFrame.Angles(0, math.pi / 2, 0) })
	end
end

-- Salas de la casa (pedido por el usuario: grandes y despejadas, los muebles contra las paredes y el centro libre).
-- `papel` = el de las paredes (PAPEL), `suelo` = lo que se pone encima del suelo, `techo` = techo de yeso (no en las
-- salas con hueco de escalera).
local SALAS = {
	{ x1 = -39, x2 = -9, z1 = -33, z2 = 9, y = ABAJO, papel = "Salon", suelo = "Madera", techo = true }, -- salón
	{ x1 = -39, x2 = -9, z1 = 9, z2 = 33, y = ABAJO, papel = "Cocina", suelo = "Damas", techo = true }, -- cocina
	{ x1 = -9, x2 = 9, z1 = -33, z2 = 33, y = ABAJO, papel = "Pasillo" }, -- recibidor y pasillo
	{ x1 = 9, x2 = 39, z1 = -33, z2 = -6, y = ABAJO, papel = "Rojo", suelo = "Madera", techo = true }, -- dormitorio
	{ x1 = 9, x2 = 39, z1 = -6, z2 = 12, y = ABAJO, papel = "Claro", suelo = "Azulejo", techo = true }, -- baño
	{ x1 = 9, x2 = 39, z1 = 12, z2 = 33, y = ABAJO, papel = "Claro", suelo = "Madera", techo = true }, -- limpieza
	{ x1 = -39, x2 = -9, z1 = -33, z2 = 0, y = ARRIBA, papel = "Rojo", suelo = "Madera", techo = true }, -- dormitorio de arriba
	{ x1 = -39, x2 = -9, z1 = 0, z2 = 33, y = ARRIBA, papel = "Claro" }, -- cuarto de la escalera del desván
	{ x1 = -9, x2 = 9, z1 = -33, z2 = 33, y = ARRIBA, papel = "Pasillo" },
	{ x1 = 9, x2 = 39, z1 = -33, z2 = 33, y = ARRIBA, papel = "Salon", suelo = "Madera", techo = true }, -- habitación del rico
}
-- Papel pintado (imágenes del Creator Store, teñidas): damasco mostaza en el salón, rayas en la cocina.
local PAPEL = {
	Salon = { id = "rbxassetid://1587307732", color = Color3.fromRGB(170, 124, 52), tam = 7 },
	Pasillo = { id = "rbxassetid://1587307732", color = Color3.fromRGB(130, 96, 46), tam = 7 },
	Cocina = { id = "rbxassetid://7518481506", color = Color3.fromRGB(205, 185, 135), tam = 6 },
	Rojo = { id = "rbxassetid://18672898655", color = Color3.fromRGB(150, 118, 105), tam = 7 },
	Claro = { id = "rbxassetid://1587307732", color = Color3.fromRGB(175, 165, 125), tam = 6 },
}

-- Lámina que se ve pero no choca ni tapa rayos (papel, suelos, techos, zócalos, molduras).
local function lamina(tamano: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = adorno(tamano, cf, material)
	p.Color = color
	p.CastShadow = false
	p:SetAttribute("SinSeparar", true) -- ya va apartada de la pared (Separar)
	return p
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
				local textura = Instance.new("Texture")
				textura.Texture = papel.id
				textura.Color3 = papel.color
				textura.StudsPerTileU = papel.tam
				textura.StudsPerTileV = papel.tam
				textura.Face = if enX then (if signo > 0 then Enum.NormalId.Right else Enum.NormalId.Left)
					else (if signo > 0 then Enum.NormalId.Back else Enum.NormalId.Front)
				textura.Parent = hoja
				if math.abs(bajo - sala.y) < 0.5 then -- Separar las engorda un poco
					if sala.papel == "Cocina" then
						local azulejo = math.min(4.5, alto - bajo) -- bajo una ventana, hasta la repisa
						tira(azulejo, bajo + azulejo / 2, 0.12, Color3.fromRGB(196, 192, 180), Enum.Material.CeramicTiles)
						if azulejo == 4.5 then
							tira(0.25, bajo + 4.62, 0.2, Color3.fromRGB(60, 58, 54), Enum.Material.SmoothPlastic, 0.02)
						end
					else
						tira(0.9, bajo + 0.45, 0.14, COLOR.Marco, Enum.Material.Wood)
					end
				end
				if math.abs(alto - (sala.y + ALTO)) < 0.5 then
					tira(0.5, alto - 0.25, 0.3, Color3.fromRGB(190, 184, 170), Enum.Material.SmoothPlastic)
				end
			end
		end
	end
end

-- Suelos y techos de cada sala: madera oscura, damas blancas y negras en la cocina, azulejo en el baño, techo de yeso.
local function vestirSuelos()
	for _, s in SALAS do
		local ancho, fondo = s.x2 - s.x1 - 1, s.z2 - s.z1 - 1
		local centro = Vector3.new((s.x1 + s.x2) / 2, s.y, (s.z1 + s.z2) / 2)
		if s.suelo == "Madera" then
			lamina(Vector3.new(ancho, 0.06, fondo), CFrame.new(centro + Vector3.new(0, 0.03, 0)), Color3.fromRGB(46, 32, 24),
				Enum.Material.WoodPlanks)
		elseif s.suelo == "Azulejo" then
			lamina(Vector3.new(ancho, 0.06, fondo), CFrame.new(centro + Vector3.new(0, 0.03, 0)), Color3.fromRGB(150, 148, 138),
				Enum.Material.CeramicTiles)
		elseif s.suelo == "Damas" then
			local filas, columnas = math.round(ancho / 3), math.round(fondo / 3)
			local ladoX, ladoZ = ancho / filas, fondo / columnas
			for i = 0, filas - 1 do
				for j = 0, columnas - 1 do
					local blanca = (i + j) % 2 == 0
					local pos = Vector3.new(s.x1 + 0.5 + (i + 0.5) * ladoX, s.y + 0.03, s.z1 + 0.5 + (j + 0.5) * ladoZ)
					lamina(Vector3.new(ladoX, 0.06, ladoZ), CFrame.new(pos),
						if blanca then Color3.fromRGB(170, 166, 156) else Color3.fromRGB(28, 27, 26), Enum.Material.Marble)
				end
			end
		end
		if s.techo then
			lamina(Vector3.new(ancho, 0.06, fondo), CFrame.new(centro + Vector3.new(0, ALTO - 0.03, 0)), Color3.fromRGB(78, 74, 70),
				Enum.Material.Plaster)
		end
	end
end

-- Manchas y sangre, blancas para teñirlas (tools/texturas/sangre.ps1). La sangre, sin pasar de la etiqueta Moderate
-- (pedido por el usuario).
local SANGRE = { "rbxassetid://85700610438600", "rbxassetid://78490976398688", "rbxassetid://76547078941684" }

-- Calcomanía en una lámina invisible: en el suelo (`normal` = arriba) o en una pared (`normal` = hacia la sala).
local function mancha(pos: Vector3, normal: Vector3, tam: number, imagen: string, color: Color3, giro: number)
	local cf = CFrame.lookAt(pos, pos + normal) * CFrame.Angles(0, 0, giro)
	local p = adorno(Vector3.new(tam, tam, 0.04), cf)
	p.Transparency = 1
	p.CastShadow = false
	local d = Instance.new("Decal")
	d.Texture = imagen
	d.Color3 = color
	d.Face = Enum.NormalId.Front
	d.Parent = p
end

-- La casa abandonada (pedido por el usuario: "más vieja y abandonada"): telarañas en las esquinas del techo, manchas de
-- humedad, papel despegado, tablas y basura por el suelo, algo de sangre y alguna silla volcada. Todo pegado a las
-- paredes y sin chocar: no estorba al correr.
local function abandonar()
	local azar = Random.new(11)
	-- Telarañas: { x, y del techo, z, hacia dónde mira (a la sala) }.
	for _, t in {
		{ -37, ABAJO + ALTO, -31, Vector3.new(1, 0, 1) }, { -37, ABAJO + ALTO, 31, Vector3.new(1, 0, -1) },
		{ 37, ABAJO + ALTO, -31, Vector3.new(-1, 0, 1) }, { 37, ABAJO + ALTO, 10, Vector3.new(-1, 0, -1) },
		{ 37, ABAJO + ALTO, 31, Vector3.new(-1, 0, -1) }, { 7, ABAJO + ALTO, 31, Vector3.new(-1, 0, -1) },
		{ -37, ARRIBA + ALTO, -31, Vector3.new(1, 0, 1) }, { 37, ARRIBA + ALTO, 31, Vector3.new(-1, 0, -1) },
		{ -7, ARRIBA + ALTO, -31, Vector3.new(1, 0, 1) },
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
		{ -38.4, ABAJO + 9, -27, Vector3.xAxis }, { -9.6, ABAJO + 8, 4, -Vector3.xAxis }, { -24, ABAJO + 9, 32.4, -Vector3.zAxis },
		{ 38.4, ABAJO + 8, -14, -Vector3.xAxis }, { 24, ABAJO + 9, 11.4, -Vector3.zAxis }, { 8.4, ABAJO + 9, 26, -Vector3.xAxis },
		{ -38.4, ARRIBA + 8, -6, Vector3.xAxis }, { 24, ARRIBA + 9, 32.4, -Vector3.zAxis }, { -8.4, ARRIBA + 7, -24, Vector3.xAxis },
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
		{ 2, ABAJO, -6 }, { -2, ABAJO, -12 }, { -20, ABAJO, 25 }, { 18, ABAJO, -17 }, { 24, ABAJO, 4 },
		{ -24, ARRIBA, -10 }, { 28, ARRIBA, -20 },
	} do
		mancha(Vector3.new(s[1], s[2] + 0.08, s[3]), Vector3.yAxis, azar:NextNumber(3, 5), SANGRE[azar:NextInteger(1, #SANGRE)],
			Color3.fromRGB(90, 8, 8), azar:NextNumber(0, math.pi * 2))
	end
	for _, s in {
		{ 8.4, ABAJO + 3.5, -2, -Vector3.xAxis }, { -12, ABAJO + 4, 32.4, -Vector3.zAxis }, { 38.4, ABAJO + 4, 4, -Vector3.xAxis },
		{ -8.4, ARRIBA + 4, -26, Vector3.xAxis },
	} do
		mancha(Vector3.new(s[1], s[2], s[3]), s[4], azar:NextNumber(2.5, 4), SANGRE[azar:NextInteger(1, #SANGRE)],
			Color3.fromRGB(90, 8, 8), azar:NextNumber(0, math.pi * 2))
	end
	-- Tablas sueltas y basura (papeles), junto a las paredes.
	for _, sitio in {
		Vector3.new(-36, ABAJO, -30), Vector3.new(6.5, ABAJO, -30), Vector3.new(-36, ABAJO, 30), Vector3.new(36, ABAJO, -29),
		Vector3.new(12, ABAJO, 30), Vector3.new(6.5, ARRIBA, -28), Vector3.new(-36, ARRIBA, -30), Vector3.new(36, ARRIBA, 30),
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
	-- Una silla volcada en la cocina, contra la pared.
	tienda("SillaCocina", CFrame.new(-35, ABAJO + 1.2, 14) * CFrame.Angles(0, math.rad(150), math.rad(90)), true)
end

local function construirCasa(mapa: Folder)
	casa = Instance.new("Model")
	casa.Name = "Casa"

	-- Suelos: abajo entero; arriba con el hueco de la escalera (x -8.5..-3.5, z 6..26); techo.
	bloque("Piso", Vector3.new(79, 1, 67), CFrame.new(0, 0.5, 0), COLOR.Piso)
	for _, r in { { -39.5, 39.5, -33.5, 6 }, { -39.5, 39.5, 26, 33.5 }, { -39.5, -8.5, 6, 26 }, { -3.5, 39.5, 6, 26 } } do
		local x1, x2, z1, z2 = r[1], r[2], r[3], r[4]
		bloque("Piso", Vector3.new(x2 - x1, 1, z2 - z1), CFrame.new((x1 + x2) / 2, 13.5, (z1 + z2) / 2), COLOR.Piso)
	end
	-- Techo con el hueco de la escalera del desván (x -17..-13, z 15..23).
	for _, r in { { -39.5, -17, -33.5, 33.5 }, { -13, 39.5, -33.5, 33.5 }, { -17, -13, -33.5, 15 }, { -17, -13, 23, 33.5 } } do
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
	bloque("Escalon", Vector3.new(8, 0.5, 3), CFrame.new(0, 0.25, -35), COLOR.Piso) -- porche

	-- Escalera: 13 peldaños de 1 de alto subiendo hacia +z, pegada a la pared del salón, y barandilla arriba.
	local huella = 20 / 13
	for i = 1, 13 do
		local z1 = 6 + (i - 1) * huella
		bloque("Peldano", Vector3.new(5, i, huella), CFrame.new(-6, ABAJO + i / 2, z1 + huella / 2), COLOR.Piso)
	end
	bloque("Barandilla", Vector3.new(0.4, 3.5, 20), CFrame.new(-3.5, ARRIBA + 1.75, 16), COLOR.Mueble)
	bloque("Barandilla", Vector3.new(5, 3.5, 0.4), CFrame.new(-6, ARRIBA + 1.75, 6), COLOR.Mueble)

	local DELANTE, DETRAS = Vector3.new(0, 0, -1), Vector3.new(0, 0, 1)
	local OESTE, ESTE = Vector3.new(-1, 0, 0), Vector3.new(1, 0, 0)

	-- Planta baja: fuera. Ninguna ventana tiene muebles delante (pedido por el usuario).
	muro(-39, -33, 39, -33, ABAJO, {
		v(10, 2, 7, 15, true, true), -- ventanal del salón
		p(39, DETRAS, { ancho = 5, atacable = true, nombre = "PuertaPrincipal" }),
		v(6, 3, 5, 66, true, true), -- dormitorio
	}, DELANTE)
	muro(-39, 33, 39, 33, ABAJO, {
		v(5, 3, 5, 6, true, true), -- cocina
		p(39, DELANTE, { alto = 8, bloqueada = true, nombre = "Sotano", llave = "LlaveSotano" }), -- baja al sótano
		v(4, 5, 3, 63, true, true), -- limpieza
	}, DETRAS)
	muro(-39, -33, -39, 33, ABAJO, {
		v(7, 2, 7, 13, true, true), -- salón
		v(4, 3, 5, 57, true, true), -- cocina
	}, OESTE)
	muro(39, -33, 39, 33, ABAJO, {
		v(6, 3, 5, 13, true, true), -- dormitorio
		v(4, 5, 3, 36, true, true), -- baño
	}, ESTE)
	-- Planta baja: dentro. Vanos abiertos con marco y cortinas donde no hace falta puerta (pedido por el usuario).
	muro(-9, -33, -9, 33, ABAJO, { vano(18, 10), vano(62, 5) }) -- salón y cocina
	muro(9, -33, 9, 33, ABAJO, { vano(21, 6), vano(36, 6), vano(55, 6) }) -- dormitorio, baño, limpieza
	muro(-39, 9, -9, 9, ABAJO, { vano(15, 6) }) -- salón | cocina
	muro(9, -6, 39, -6, ABAJO, {})
	muro(9, 12, 39, 12, ABAJO, {})

	-- Planta de arriba.
	muro(-39, -33, 39, -33, ARRIBA, { v(5, 3, 5, 15, true), v(4, 3, 5, 39, true), v(5, 3, 5, 66, false) }, DELANTE)
	muro(-39, 33, 39, 33, ARRIBA, { v(5, 3, 5, 66, false) }, DETRAS)
	muro(-39, -33, -39, 33, ARRIBA, { v(5, 3, 5, 17, true) }, OESTE)
	muro(39, -33, 39, 33, ARRIBA, { v(5, 3, 5, 16, false), v(5, 3, 5, 50, false) }, ESTE)
	muro(-9, -33, -9, 33, ARRIBA, {
		vano(17, 6), -- dormitorio de arriba
		p(62, OESTE, { ancho = 3, alto = 8, bloqueada = true, nombre = "Desvan", llave = "LlaveDesvan" }), -- escalera del desván
	})
	muro(9, -33, 9, 33, ARRIBA, { p(25, ESTE, { bloqueada = true, nombre = "HabitacionDelRico", llave = "LlaveRico" }) })
	muro(-39, 0, -9, 0, ARRIBA, {})
	-- Cuarto de la escalera del desván (x -39..-9, z 0..33 arriba): al entrar, 13 peldaños subiendo hacia -z hasta el
	-- techo, con pared al lado para que se coja por abajo.
	for i = 1, 13 do
		bloque("Peldano", Vector3.new(4, i, 1), CFrame.new(-15, ARRIBA + i / 2, 28 - (i - 0.5)), COLOR.Piso)
	end
	bloque("Muro", Vector3.new(0.6, ALTO, 12), CFrame.new(-12.7, ARRIBA + ALTO / 2, 21))
	-- Habitación del rico: escritorio y caja fuerte (el diario y cómo matar al bicho, más adelante).
	mueble("Escritorio", CFrame.new(30, ARRIBA, -23),
		{ bloque("Escritorio", Vector3.new(6, 3, 3), CFrame.new(30, ARRIBA + 1.5, -23), COLOR.Mueble) })
	bloque("CajaFuerte", Vector3.new(2.5, 3, 2.5), CFrame.new(36, ARRIBA + 1.5, 29), COLOR.Oscuro, Enum.Material.Metal)

	-- Muebles y escondites.
	-- Chimenea (Chimenea, y por ella baja el Trepador): el tiro sube hasta salir por el tejado.
	local chimenea = Instance.new("Model")
	chimenea.Name = "Chimenea"
	local ladrillo = Color3.fromRGB(85, 82, 80)
	bloque("Chimenea", Vector3.new(3, 10, 8), CFrame.new(-37.5, ABAJO + 5, -1), ladrillo, Enum.Material.Brick, chimenea)
	bloque("Hogar", Vector3.new(0.6, 3.5, 4), CFrame.new(-35.8, ABAJO + 1.75, -1), Color3.fromRGB(20, 18, 18), Enum.Material.Slate, chimenea)
	bloque("Tiro", Vector3.new(3, 34, 4), CFrame.new(-37.5, ABAJO + 10 + 17, -1), ladrillo, Enum.Material.Brick, chimenea)
	mando(CFrame.new(-34.8, ABAJO + 2, -1), chimenea)
	chimenea:SetAttribute("Hogar", CFrame.new(-34.6, ABAJO + 0.8, -1) * CFrame.Angles(0, math.pi / 2, 0)) -- donde arde el tronco
	chimenea:SetAttribute("Tiro", Vector3.new(-37.5, ABAJO + 44, -1)) -- la boca de arriba
	chimenea:SetAttribute("Salida", CFrame.lookAt(Vector3.new(-33, ABAJO, -1), Vector3.new(-23, ABAJO, -1))) -- delante del hogar
	CollectionService:AddTag(chimenea, "Chimenea")
	chimenea.Parent = casa
	-- Muebles contra las paredes sin ventana y el centro de cada sala libre para correr (pedido por el usuario).
	-- Salón: sofá contra la pared del pasillo mirando a la chimenea, butacas a los lados del fuego, aparador con la tele,
	-- piano, librería y reloj.
	contraPared("Sofa", -9.5, ABAJO, 0, OESTE)
	mueble("Mesita", CFrame.new(-16, ABAJO, 0) * CFrame.Angles(0, math.pi / 2, 0), { bloque("Mesita", Vector3.new(3, 1.5, 4), CFrame.new(-16, ABAJO + 0.75, 0), COLOR.Mueble) })
	mueble("Alfombra", CFrame.new(-18, ABAJO, 0))
	for _, z in { -7, 5 } do
		local pos = Vector3.new(-30, ABAJO, z)
		tienda("Butaca", CFrame.lookAt(pos, Vector3.new(-35, ABAJO, -1)))
	end
	contraPared("Aparador", -15, ABAJO, 8.5, DELANTE)
	local tele = contraPared("Tele", -16.5, ABAJO + 3.4, 8.3, DELANTE, true)
	if tele then
		tele:ScaleTo(tele:GetScale() * 0.7) -- que no sobresalga del aparador
	end
	contraPared("LamparaMesa", -12, ABAJO + 3.4, 8.3, DELANTE, true)
	contraPared("Piano", -13, ABAJO, -32.5, DETRAS)
	contraPared("Libreria", -38.5, ABAJO, -11, ESTE)
	contraPared("Reloj", -38.5, ABAJO, 6, ESTE)
	-- Cocina (prueba aprobada por el usuario): nevera, encimeras viejas hechas con piezas y el fregadero en medio contra la
	-- pared de atrás; las dos cocinas contra la del salón; mesa con cuatro sillas en medio con sitio alrededor.
	contraPared("Nevera", -28, ABAJO, 32.5, DELANTE)
	for _, tramo in { { -25.8, -19 }, { -16, -11.5 } } do
		local x1, x2 = tramo[1], tramo[2]
		local mx = (x1 + x2) / 2
		bloque("Encimera", Vector3.new(x2 - x1, 3.2, 2.4), CFrame.new(mx, ABAJO + 1.6, 31.3), Color3.fromRGB(64, 50, 40))
		bloque("Encimera", Vector3.new(x2 - x1 + 0.2, 0.3, 2.6), CFrame.new(mx, ABAJO + 3.35, 31.25), Color3.fromRGB(104, 98, 90),
			Enum.Material.Marble)
		bloque("Alacena", Vector3.new(x2 - x1, 2.6, 1.4), CFrame.new(mx, ABAJO + 8.3, 31.8), Color3.fromRGB(64, 50, 40))
		for x = x1 + 2, x2 - 1, 2 do -- rendijas de las puertas
			adorno(Vector3.new(0.1, 2.8, 0.06), CFrame.new(x, ABAJO + 1.6, 30.08)).Color = Color3.fromRGB(30, 24, 20)
			adorno(Vector3.new(0.1, 2.2, 0.06), CFrame.new(x, ABAJO + 8.3, 31.08)).Color = Color3.fromRGB(30, 24, 20)
		end
	end
	contraPared("Fregadero", -17.5, ABAJO + 1.3, 32.5, DELANTE, true)
	contraPared("CocinaHierro", -36, ABAJO, 9.5, DETRAS)
	contraPared("CocinaOxidada", -31.2, ABAJO, 9.5, DETRAS)
	tienda("MesaCocina", CFrame.new(-24, ABAJO, 20))
	for _, silla in { { -26.4, 18.8, 1 }, { -26.4, 21.2, 1 }, { -21.6, 18.8, -1 }, { -21.6, 21.2, -1 } } do
		local pos = Vector3.new(silla[1], ABAJO, silla[2])
		tienda("SillaCocina", CFrame.lookAt(pos, pos + Vector3.new(silla[3], 0, 0)))
	end
	-- Dormitorio: cama, armario, aparador con lámpara y mesilla junto a la cama.
	contraPared("Aparador", 33, ABAJO, -6.5, DELANTE)
	contraPared("LamparaMesa", 35.5, ABAJO + 3.4, -6.7, DELANTE, true)
	bloque("Mesilla", Vector3.new(2, 2.4, 2), CFrame.new(10.6, ABAJO + 1.2, -28.6), COLOR.Mueble)
	contraPared("LamparaMesa", 10.6, ABAJO + 2.4, -29.6, DETRAS, true)
	-- Baño: bañera de patas contra la pared de la limpieza, váter y lavabo.
	tienda("Banera", CFrame.lookAt(Vector3.new(30, ABAJO, 9.8), Vector3.new(31, ABAJO, 9.8)))
	contraPared("Vater", 38.5, ABAJO, -2, OESTE)
	mueble("Lavabo", CFrame.lookAt(Vector3.new(16, ABAJO, -4.8), Vector3.new(16, ABAJO, -3.8)))
	local lavabo = bloque("Choque", Vector3.new(2.4, 3, 1.6), CFrame.new(16, ABAJO + 1.5, -4.8))
	lavabo.Transparency = 1
	lavabo.CanQuery = false
	-- Limpieza.
	mueble("Estanteria", CFrame.new(17, ABAJO, 31.5),
		{ bloque("Estanteria", Vector3.new(6, 7, 1.5), CFrame.new(17, ABAJO + 3.5, 31.5), COLOR.Mueble) })
	-- Arriba: el dormitorio y la habitación del rico (librerías, butaca, reloj y lámpara en el escritorio).
	contraPared("Aparador", -31, ARRIBA, -0.5, DELANTE)
	contraPared("LamparaMesa", -33.5, ARRIBA + 3.4, -0.7, DELANTE, true)
	contraPared("Libreria", 38.5, ARRIBA, -27, OESTE)
	contraPared("Libreria", 38.5, ARRIBA, -4, OESTE)
	contraPared("Reloj", 38.5, ARRIBA, 6, OESTE)
	tienda("Butaca", CFrame.lookAt(Vector3.new(20, ARRIBA, -27), Vector3.new(27, ARRIBA, -23)))
	tienda("LamparaMesa", CFrame.new(32, ARRIBA + 3, -23) * CFrame.Angles(0, math.pi, 0), true) -- en el escritorio
	for _, cuadro in { { -9.6, ABAJO, -27 }, { 8.4, ABAJO, -24 }, { 8.4, ARRIBA, -20 } } do
		local pos = Vector3.new(cuadro[1], cuadro[2] + 4.5, cuadro[3])
		mueble("Cuadro", CFrame.lookAt(pos, pos - Vector3.xAxis))
	end
	-- Porche: dos postes y un tejadillo sobre la puerta de entrada.
	for _, x in { -4.5, 4.5 } do
		adorno(Vector3.new(0.6, 10.6, 0.6), CFrame.new(x, 5.3, -36.6))
	end
	adorno(Vector3.new(10, 0.5, 0.5), CFrame.new(0, 10.4, -36.6))
	adorno(Vector3.new(11, 0.4, 4.8), CFrame.new(0, 10.9, -35.3) * CFrame.Angles(math.rad(-12), 0, 0), Enum.Material.Slate).Color =
		COLOR.Oscuro

	-- Objetos sueltos por la casa (provisional: luego saldrán al azar con la semilla de la partida).
	for _, o in {
		{ "Pila", Vector3.new(-24, ABAJO + 3.7, 31.3) }, { "Lata", Vector3.new(-13.5, ABAJO + 3.7, 31.3) }, -- encimeras
		{ "Botella", Vector3.new(-24.3, ABAJO + 3.3, 19.2) }, { "Carrete", Vector3.new(-23.7, ABAJO + 3.3, 21) }, -- mesa
		{ "Pila", Vector3.new(-25, ARRIBA + 0.2, -18) }, { "Hacha", Vector3.new(30, ABAJO + 0.2, 26) },
		{ "Hacha", Vector3.new(-32, 0.2, -39.5) }, -- junto al caballete
	} do
		table.insert(Mapa.objetos, { tipo = o[1], cf = CFrame.new(o[2]) * CFrame.Angles(0, math.rad(#Mapa.objetos * 37), 0) })
	end
	-- Lo pesado, delante de la casa.
	for _, p in {
		{ "Tronco", CFrame.new(10, 0.7, -43) * CFrame.Angles(0, 0.4, 0) }, { "Tronco", CFrame.new(-10, 0.7, -44) },
		{ "Tablon", CFrame.new(14, 0.15, -38) * CFrame.Angles(0, -0.3, 0) }, { "Bidon", CFrame.new(-14, 1.2, -39) },
		{ "Bidon", CFrame.new(5, ABAJO + 1.2, 40.5) }, -- en el cobertizo
		{ "Motor", CFrame.new(20, 1.1, -49) },
	} do
		table.insert(Mapa.pesados, { tipo = p[1], cf = p[2] })
	end

	cama(Vector3.new(14, ABAJO, -24), OESTE, -1)
	armario(Vector3.new(24, ABAJO + 4, -8), DELANTE)
	cama(Vector3.new(-34.3, ARRIBA, -26), OESTE, -1)
	armario(Vector3.new(-20, ARRIBA + 4, -2), DELANTE)
	armario(Vector3.new(37, ABAJO + 4, 22), OESTE) -- cuarto de la limpieza

	-- Luces (las enciende el generador) y salas por las que ronda el Golpeador.
	for _, sala in {
		Vector3.new(0, ABAJO, -20), Vector3.new(3, ABAJO, 14), Vector3.new(-24, ABAJO, -12), Vector3.new(-24, ABAJO, 21),
		Vector3.new(24, ABAJO, -20), Vector3.new(24, ABAJO, 3), Vector3.new(24, ABAJO, 22),
		Vector3.new(2, ARRIBA, -18), Vector3.new(-24, ARRIBA, -16),
	} do
		table.insert(Mapa.salas, sala)
	end
	for _, luz in {
		Vector3.new(0, ABAJO, -20), Vector3.new(3, ABAJO, 14), Vector3.new(-24, ABAJO, -20), Vector3.new(-24, ABAJO, -2),
		Vector3.new(-24, ABAJO, 21), Vector3.new(24, ABAJO, -20), Vector3.new(24, ABAJO, 3), Vector3.new(24, ABAJO, 22),
		Vector3.new(2, ARRIBA, -18), Vector3.new(-24, ARRIBA, -16),
	} do
		lampara(luz + Vector3.new(0, ALTO - 0.3, 0))
	end

	local aparicion = Instance.new("SpawnLocation")
	aparicion.Anchored = true
	aparicion.Size = Vector3.new(5, 0.2, 5)
	aparicion.CFrame = CFrame.new(0, ABAJO + 0.1, -20)
	aparicion.Transparency = 1
	aparicion.CanCollide = false
	aparicion.CanQuery = false
	aparicion.Neutral = true
	aparicion.Duration = 0
	aparicion.Parent = casa

	construirCobertizo()
	construirCaballete()
	construirSotano()
	construirGaraje()
	-- Enchufe del móvil en el cuarto de la limpieza: placa, repisa donde se deja el móvil y lucecita de carga.
	local enchufe = Instance.new("Model")
	enchufe.Name = "Enchufe"
	enchufe.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	bloque("Placa", Vector3.new(0.15, 0.8, 0.6), CFrame.new(38.45, ABAJO + 2.6, 29), Color3.fromRGB(190, 185, 170),
		Enum.Material.SmoothPlastic, enchufe)
	bloque("Repisa", Vector3.new(1.1, 0.2, 1.4), CFrame.new(37.95, ABAJO + 1.9, 29), COLOR.Mueble, nil, enchufe)
	bloque("Luz", Vector3.new(0.1, 0.12, 0.12), CFrame.new(38.36, ABAJO + 3.15, 29), COLOR.Oscuro, Enum.Material.SmoothPlastic,
		enchufe)
	mando(CFrame.new(37.6, ABAJO + 2.4, 29), enchufe)
	enchufe:SetAttribute("Sitio", CFrame.new(37.95, ABAJO + 2.15, 29)) -- donde se queda el móvil cargando
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
-- Junto a la casa, el garaje, el cobertizo, el sótano o lo que hay delante (el motor está en z = -49): ahí no salen
-- árboles ni sotobosque.
local function junto(x: number, z: number): boolean
	return x > -46 and x < 72 and z > -54 and z < 72
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
	abandonar()
	-- Donde se aparece: invisible y encima del suelo de la casa (a ras de él, parpadeaba con el suelo).
	local aparicion = Instance.new("SpawnLocation")
	aparicion.Anchored = true
	aparicion.Size = Vector3.new(6, 0.2, 6)
	aparicion.Position = Vector3.new(0, ABAJO + 0.2, 0)
	aparicion.Transparency = 1
	aparicion.CanCollide = false
	aparicion.Neutral = true
	aparicion.Duration = 0
	aparicion.Parent = mapa
end

return Mapa
