-- Genera el mapa por código con bloques grises (el arte llega al final): suelo, bosque de troncos, camino y la casa.
-- La casa: dos plantas. Abajo recibidor y pasillo con la escalera, salón con chimenea, cocina, dormitorio, baño y
-- cuarto de la limpieza; arriba un dormitorio y la habitación del rico (con llave). El sótano, con llave.
-- Lo que se toca lleva una etiqueta de CollectionService y su estado en atributos (lo maneja Casa o Muerte):
--   "Ventana": cristal y persiana. "Puerta": hoja que gira en la bisagra. "Escondite": armarios y camas.
-- Medidas en studs: suelo de abajo arriba en y = 1, el de arriba en y = 14; paredes de 12 de alto.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Separar = require(ServerScriptService:WaitForChild("Comun").Separar)

local Mapa = {}

local ABAJO, ARRIBA, ALTO = 1, 14, 12

local COLOR = {
	Suelo = Color3.fromRGB(58, 62, 55),
	Camino = Color3.fromRGB(78, 72, 64),
	Tronco = Color3.fromRGB(62, 58, 54),
	Muro = Color3.fromRGB(128, 125, 118),
	Piso = Color3.fromRGB(92, 88, 82),
	Mueble = Color3.fromRGB(105, 100, 95),
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
	local luz = Instance.new("PointLight")
	luz.Color = COLOR.Lampara
	luz.Brightness = 1.1
	luz.Range = 22
	luz.Shadows = true
	luz.Enabled = false -- las enciende el generador
	luz.Parent = p
	table.insert(Mapa.lamparas, p)
end

local function ventana(centro: Vector3, fuera: Vector3, h, suelo: number)
	local modelo = Instance.new("Model")
	modelo.Name = "Ventana"
	modelo.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- el cliente lo necesita entero
	local mira = CFrame.lookAt(centro, centro + fuera)
	local cristal = bloque("Cristal", Vector3.new(h.ancho, h.alto, 0.2), mira, COLOR.Cristal, Enum.Material.Glass, modelo)
	cristal.Transparency = 0.55
	bloque("Repisa", Vector3.new(h.ancho + 0.6, 0.3, 1.6), mira * CFrame.new(0, -h.alto / 2 - 0.15, 0), COLOR.Mueble, nil, modelo)
	modelo.Parent = casa
	if not h.persiana then
		return -- ventana de una sala cerrada: solo cristal
	end
	bloque("Caja", Vector3.new(h.ancho + 0.6, 1, 0.9), mira * CFrame.new(0, h.alto / 2 + 0.5, 0.95), COLOR.Mueble, nil, modelo)
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
	local hoja = bloque("Hoja", Vector3.new(h.ancho - 0.2, h.alto - 0.1, 0.35), bisagra * CFrame.new(h.ancho / 2, h.alto / 2, 0),
		COLOR.Mueble, nil, modelo)
	bloque("Pomo", Vector3.new(0.3, 0.3, 0.8), hoja.CFrame * CFrame.new(h.ancho / 2 - 0.6, -0.4, 0), COLOR.Oscuro,
		Enum.Material.Metal, modelo)
	if not h.bloqueada then
		local modificador = Instance.new("PathfindingModifier")
		modificador.PassThrough = true -- el bicho planea su camino a través de las puertas: las abre a golpes
		modificador.Parent = hoja
	end
	mando(CFrame.new(pie + Vector3.new(0, 4, 0)), modelo)
	modelo:SetAttribute("Clave", clave("P", pie))
	modelo:SetAttribute("Bisagra", bisagra)
	modelo:SetAttribute("Hacia", h.hacia)
	modelo:SetAttribute("Ancho", h.ancho)
	modelo:SetAttribute("Bloqueada", h.bloqueada == true)
	if h.atacable and fuera then
		modelo:SetAttribute("Atacable", true)
		modelo:SetAttribute("Centro", CFrame.lookAt(pie + Vector3.new(0, h.alto / 2, 0), pie + Vector3.new(0, h.alto / 2, 0) + fuera))
		modelo:SetAttribute("Fuera", Vector3.new(pie.X, 0, pie.Z) + fuera * 4)
		modelo:SetAttribute("Dentro", pie - fuera * 4)
	end
	modelo.Parent = casa
	CollectionService:AddTag(modelo, "Puerta")
end

-- Pared recta de (x1, z1) a (x2, z2) (crecientes) con huecos: { en = distancia desde el inicio, ancho, bajo, alto,
-- tipo = "Ventana" | "Puerta" | "Hueco", ... }. `fuera` = hacia dónde queda el exterior (paredes de fuera).
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
		bloque("Muro", tamano, CFrame.new(centro))
	end
	table.sort(huecos, function(a, b)
		return a.en < b.en
	end)
	local cursor = -0.5 -- las paredes se alargan medio stud para cerrar las esquinas
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
		end
	end
	pieza(cursor, largo + 0.5, 0, ALTO)
end

local function v(ancho, bajo, alto, en, persiana, atacable)
	return { tipo = "Ventana", en = en, ancho = ancho, bajo = bajo, alto = alto, persiana = persiana, atacable = atacable }
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
	local function trozo(nombre: string, tamano: Vector3, offset: Vector3, color: Color3?)
		bloque(nombre, tamano, cf * CFrame.new(offset), color or COLOR.Mueble, nil, modelo)
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

-- Cobertizo pegado a la parte de atrás de la casa (x 3..13, z 22.5..31) con el generador; se entra por el este.
local function construirCobertizo()
	local x1, x2, z1, z2, alto = 3, 13, 22.5, 31, 9
	CollectionService:AddTag(bloque("Piso", Vector3.new(x2 - x1, 1, z2 - z1), CFrame.new((x1 + x2) / 2, 0.5, (z1 + z2) / 2), COLOR.Piso),
		"EnMapa")
	bloque("Muro", Vector3.new(x2 - x1 + 1, alto, 1), CFrame.new((x1 + x2) / 2, ABAJO + alto / 2, z2))
	bloque("Muro", Vector3.new(1, alto, z2 - z1), CFrame.new(x1, ABAJO + alto / 2, (z1 + z2) / 2))
	bloque("Muro", Vector3.new(1, alto, 2.5), CFrame.new(x2, ABAJO + alto / 2, z1 + 1.25)) -- este, con la entrada (z 25..30)
	bloque("Muro", Vector3.new(1, alto - 7, 5), CFrame.new(x2, ABAJO + 7 + (alto - 7) / 2, 27.5))
	bloque("Techo", Vector3.new(x2 - x1 + 2, 0.6, z2 - z1 + 1.5), CFrame.new((x1 + x2) / 2, ABAJO + alto + 0.3, (z1 + z2) / 2 + 0.4),
		COLOR.Oscuro, Enum.Material.CorrodedMetal)
	lampara(Vector3.new(8, ABAJO + alto - 0.4, 26.5))

	-- El generador mira al este (a la entrada): la cuerda sale por ese lado.
	local gen = Instance.new("Model")
	gen.Name = "Generador"
	gen.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local base = CFrame.new(8, ABAJO, 28.4)
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
	local base = CFrame.new(-22, 0, -32)
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

local function construirCasa(mapa: Folder)
	casa = Instance.new("Model")
	casa.Name = "Casa"

	-- Suelos: abajo entero; arriba con el hueco de la escalera (x -6..-1, z -2..18); techo.
	bloque("Piso", Vector3.new(53, 1, 45), CFrame.new(0, 0.5, 0), COLOR.Piso)
	for _, r in { { -26.5, 26.5, -22.5, -2 }, { -26.5, 26.5, 18, 22.5 }, { -26.5, -6, -2, 18 }, { -1, 26.5, -2, 18 } } do
		local x1, x2, z1, z2 = r[1], r[2], r[3], r[4]
		bloque("Piso", Vector3.new(x2 - x1, 1, z2 - z1), CFrame.new((x1 + x2) / 2, 13.5, (z1 + z2) / 2), COLOR.Piso)
	end
	bloque("Techo", Vector3.new(53, 1, 45), CFrame.new(0, 26.5, 0), COLOR.Piso)
	local inclinacion = math.atan(9 / 24)
	for _, lado in { 1, -1 } do
		bloque("Tejado", Vector3.new(56, 1, 25.6), CFrame.new(0, 31.5, 12 * lado) * CFrame.Angles(inclinacion * lado, 0, 0),
			COLOR.Oscuro, Enum.Material.Slate)
	end
	bloque("Escalon", Vector3.new(8, 0.5, 3), CFrame.new(0, 0.25, -24), COLOR.Piso) -- porche

	-- Escalera: 13 peldaños de 1 de alto subiendo hacia +z, y barandilla arriba.
	local huella = 20 / 13
	for i = 1, 13 do
		local z1 = -2 + (i - 1) * huella
		bloque("Peldano", Vector3.new(5, i, huella), CFrame.new(-3.5, ABAJO + i / 2, z1 + huella / 2), COLOR.Piso)
	end
	bloque("Barandilla", Vector3.new(0.4, 3.5, 20), CFrame.new(-1, ARRIBA + 1.75, 8), COLOR.Mueble)
	bloque("Barandilla", Vector3.new(5, 3.5, 0.4), CFrame.new(-3.5, ARRIBA + 1.75, -2), COLOR.Mueble)

	local DELANTE, DETRAS = Vector3.new(0, 0, -1), Vector3.new(0, 0, 1)
	local OESTE, ESTE = Vector3.new(-1, 0, 0), Vector3.new(1, 0, 0)

	-- Planta baja: fuera.
	muro(-26, -22, 26, -22, ABAJO, {
		v(8, 2, 7, 10, true, true), -- ventanal del salón
		p(26, DETRAS, { ancho = 5, atacable = true, nombre = "PuertaPrincipal" }),
		v(5, 3, 5, 44, true, true), -- dormitorio
	}, DELANTE)
	muro(-26, 22, 26, 22, ABAJO, {
		v(5, 3, 5, 10, true, true), -- cocina
		p(26, DELANTE, { alto = 8, bloqueada = true, nombre = "Sotano" }),
		v(3, 5, 3, 42, true, true), -- limpieza
	}, DETRAS)
	muro(-26, -22, -26, 22, ABAJO, {
		v(6, 2, 7, 10, true, true), -- salón
		v(4, 3, 5, 36, true, true), -- cocina
	}, OESTE)
	muro(26, -22, 26, 22, ABAJO, {
		v(5, 3, 5, 9, true, true), -- dormitorio
		v(3, 5, 3, 24, true, true), -- baño
	}, ESTE)
	-- Planta baja: dentro.
	muro(-6, -22, -6, 22, ABAJO, { { tipo = "Hueco", en = 12, ancho = 8, alto = 9 } }) -- arco del salón
	muro(6, -22, 6, 22, ABAJO, { p(9, ESTE), p(24, ESTE), p(37, ESTE) }) -- dormitorio, baño, limpieza
	muro(-26, 6, -6, 6, ABAJO, { p(10, DETRAS) }) -- salón | cocina
	muro(6, -4, 26, -4, ABAJO, {})
	muro(6, 8, 26, 8, ABAJO, {})

	-- Planta de arriba.
	muro(-26, -22, 26, -22, ARRIBA, { v(5, 3, 5, 10, true), v(4, 3, 5, 26, true), v(5, 3, 5, 42, false) }, DELANTE)
	muro(-26, 22, 26, 22, ARRIBA, { v(5, 3, 5, 42, false) }, DETRAS)
	muro(-26, -22, -26, 22, ARRIBA, { v(5, 3, 5, 11, true) }, OESTE)
	muro(26, -22, 26, 22, ARRIBA, { v(5, 3, 5, 11, false), v(5, 3, 5, 33, false) }, ESTE)
	muro(-6, -22, -6, 22, ARRIBA, { p(11, OESTE) }) -- dormitorio de arriba
	muro(6, -22, 6, 22, ARRIBA, { p(17, ESTE, { bloqueada = true, nombre = "HabitacionDelRico" }) })
	muro(-26, 0, -6, 0, ARRIBA, {})

	-- Muebles y escondites.
	bloque("Chimenea", Vector3.new(3, 10, 8), CFrame.new(-24.5, ABAJO + 5, -1), Color3.fromRGB(85, 82, 80), Enum.Material.Brick)
	bloque("Hogar", Vector3.new(0.6, 3.5, 4), CFrame.new(-22.8, ABAJO + 1.75, -1), Color3.fromRGB(20, 18, 18), Enum.Material.Slate)
	bloque("Sofa", Vector3.new(8, 2.5, 3), CFrame.new(-15, ABAJO + 1.25, -12), COLOR.Mueble, Enum.Material.Fabric)
	bloque("Sofa", Vector3.new(8, 3, 1), CFrame.new(-15, ABAJO + 2.5, -13.5), COLOR.Mueble, Enum.Material.Fabric)
	bloque("Mesita", Vector3.new(4, 1.5, 3), CFrame.new(-15, ABAJO + 0.75, -7), COLOR.Mueble)
	bloque("Encimera", Vector3.new(14, 3.5, 2), CFrame.new(-18, ABAJO + 1.75, 20.5), COLOR.Mueble)
	bloque("Mesa", Vector3.new(6, 0.4, 4), CFrame.new(-15, ABAJO + 3, 13), COLOR.Mueble)
	bloque("Banera", Vector3.new(7, 2.5, 3.5), CFrame.new(21, ABAJO + 1.25, 6), Color3.fromRGB(150, 150, 148), Enum.Material.SmoothPlastic)
	bloque("Estanteria", Vector3.new(6, 7, 1.5), CFrame.new(12, ABAJO + 3.5, 21), COLOR.Mueble)

	-- Objetos sueltos por la casa (provisional: luego saldrán al azar con la semilla de la partida).
	for _, o in {
		{ "Pila", Vector3.new(-21, ABAJO + 3.7, 20.5) }, { "Lata", Vector3.new(-16, ABAJO + 3.7, 20.5) }, -- encimera
		{ "Botella", Vector3.new(-15.5, ABAJO + 3.4, 13) }, { "Carrete", Vector3.new(-13.5, ABAJO + 3.4, 12.5) }, -- mesa
		{ "Pila", Vector3.new(-17, ARRIBA + 0.2, -12) }, { "Hacha", Vector3.new(21, ABAJO + 0.2, 18) },
	{ "Hacha", Vector3.new(-19, 0.2, -28.5) }, -- junto al caballete
	} do
		table.insert(Mapa.objetos, { tipo = o[1], cf = CFrame.new(o[2]) * CFrame.Angles(0, math.rad(#Mapa.objetos * 37), 0) })
	end
	-- Lo pesado, delante de la casa.
	for _, p in {
		{ "Tronco", CFrame.new(10, 0.7, -32) * CFrame.Angles(0, 0.4, 0) }, { "Tronco", CFrame.new(-10, 0.7, -33) },
		{ "Tablon", CFrame.new(14, 0.15, -27) * CFrame.Angles(0, -0.3, 0) }, { "Bidon", CFrame.new(-14, 1.2, -28) },
		{ "Bidon", CFrame.new(5, ABAJO + 1.2, 29.5) }, -- en el cobertizo
		{ "Motor", CFrame.new(20, 1.1, -38) },
	} do
		table.insert(Mapa.pesados, { tipo = p[1], cf = p[2] })
	end

	cama(Vector3.new(11, ABAJO, -18.5), OESTE, -1)
	armario(Vector3.new(20, ABAJO + 4, -6), DELANTE)
	cama(Vector3.new(-20.5, ARRIBA, -17.5), OESTE, -1)
	armario(Vector3.new(-16, ARRIBA + 4, -2), DELANTE)
	armario(Vector3.new(24, ABAJO + 4, 15), OESTE) -- cuarto de la limpieza

	-- Luces (provisional: siempre encendidas hasta que haya generador) y salas.
	for _, sala in {
		Vector3.new(0, ABAJO, -15), Vector3.new(2, ABAJO, 8), Vector3.new(-16, ABAJO, -8), Vector3.new(-16, ABAJO, 14),
		Vector3.new(14, ABAJO, -13), Vector3.new(14, ABAJO, 2), Vector3.new(14, ABAJO, 15),
		Vector3.new(2, ARRIBA, -12), Vector3.new(-14, ARRIBA, -11),
	} do
		lampara(sala + Vector3.new(0, ALTO - 0.3, 0))
		table.insert(Mapa.salas, sala)
	end

	local aparicion = Instance.new("SpawnLocation")
	aparicion.Anchored = true
	aparicion.Size = Vector3.new(5, 0.2, 5)
	aparicion.CFrame = CFrame.new(0, ABAJO + 0.1, -14)
	aparicion.Transparency = 1
	aparicion.CanCollide = false
	aparicion.CanQuery = false
	aparicion.Neutral = true
	aparicion.Duration = 0
	aparicion.Parent = casa

	construirCobertizo()
	construirCaballete()
	-- Enchufe del móvil en el cuarto de la limpieza: placa, repisa donde se deja el móvil y lucecita de carga.
	local enchufe = Instance.new("Model")
	enchufe.Name = "Enchufe"
	enchufe.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	bloque("Placa", Vector3.new(0.15, 0.8, 0.6), CFrame.new(25.45, ABAJO + 2.6, 19.5), Color3.fromRGB(190, 185, 170),
		Enum.Material.SmoothPlastic, enchufe)
	bloque("Repisa", Vector3.new(1.1, 0.2, 1.4), CFrame.new(24.95, ABAJO + 1.9, 19.5), COLOR.Mueble, nil, enchufe)
	bloque("Luz", Vector3.new(0.1, 0.12, 0.12), CFrame.new(25.36, ABAJO + 3.15, 19.5), COLOR.Oscuro, Enum.Material.SmoothPlastic,
		enchufe)
	mando(CFrame.new(24.6, ABAJO + 2.4, 19.5), enchufe)
	enchufe:SetAttribute("Sitio", CFrame.new(24.95, ABAJO + 2.15, 19.5)) -- donde se queda el móvil cargando
	CollectionService:AddTag(enchufe, "Enchufe")
	enchufe.Parent = casa

	CollectionService:AddTag(casa:FindFirstChild("Piso") :: BasePart, "EnMapa")
	casa.Parent = mapa
end

local function construirBosque(mapa: Folder)
	local bosque = Instance.new("Folder")
	bosque.Name = "Bosque"
	bloque("Suelo", Vector3.new(1600, 2, 1600), CFrame.new(0, -1, 0), COLOR.Suelo, Enum.Material.Grass, bosque)
	CollectionService:AddTag(bloque("Camino", Vector3.new(12, 0.2, 400), CFrame.new(0, 0.05, -225), COLOR.Camino,
		Enum.Material.Ground, bosque), "EnMapa")
	local azar = Random.new(7)
	local puestos = 0
	while puestos < 260 do
		local angulo = azar:NextNumber(0, math.pi * 2)
		local distancia = azar:NextNumber(48, 420)
		local x, z = math.cos(angulo) * distancia, math.sin(angulo) * distancia
		if not (math.abs(x) < 12 and z < -30) then
			local alto, grueso = azar:NextNumber(50, 85), azar:NextNumber(2, 4.5)
			bloque("Tronco", Vector3.new(alto, grueso, grueso), CFrame.new(x, alto / 2, z) * CFrame.Angles(0, 0, math.pi / 2),
				COLOR.Tronco, Enum.Material.Wood, bosque).Shape = Enum.PartType.Cylinder
			puestos += 1
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
		if not (math.abs(x) < 14 and z < -28) and (Vector3.new(x, 0, z) - Vector3.new(-22, 0, -32)).Magnitude > 10 then
			local modelo = Instance.new("Model")
			modelo.Name = "Arbol"
			modelo.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			local alto, grueso = azar:NextNumber(22, 30), azar:NextNumber(1.6, 2.2)
			local tronco = bloque("Tronco", Vector3.new(alto, grueso, grueso), CFrame.new(x, alto / 2, z) * CFrame.Angles(0, 0, math.pi / 2),
				COLOR.Tronco, Enum.Material.Wood, modelo)
			tronco.Shape = Enum.PartType.Cylinder
			for i, copa in { { 9, alto - 4 }, { 6, alto + 1 } } do
				local hoja = bloque("Copa", Vector3.new(copa[1], copa[1] * 0.8, copa[1]),
					CFrame.new(x, copa[2], z) * CFrame.Angles(0, azar:NextNumber(0, math.pi) + i, 0), Color3.fromRGB(44, 54, 42),
					Enum.Material.Grass, modelo)
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
	bosque.Parent = mapa
end

function Mapa.start()
	local mapa = workspace:WaitForChild("Mapa")
	construirBosque(mapa)
	construirCasa(mapa)
	local quedan = Separar.caras(mapa) -- que no parpadeen dos caras en el mismo plano
	if quedan > 0 then
		warn(`[Mapa] quedan {quedan} caras que parpadean`)
	end
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
