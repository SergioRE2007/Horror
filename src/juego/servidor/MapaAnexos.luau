-- Lo de la casa que no son sus salas (11.6 y 12.2), sacado de Mapa sin cambiar nada: cobertizo con el generador,
-- caballete, bancos del taller, el coche del garaje, hastiales del desván, sótano, lo del final de la Bestia y garaje.
-- Lo llama Mapa.construirCasa; las ayudas (bloque, tienda…) son las de Mapa (`iniciar`).
local CollectionService = game:GetService("CollectionService")

local Fachada = require(script.Parent.Fachada)
local Medidas = require(script.Parent.MapaMedidas)
local ABAJO, ALTO, COLOR, TEJADO = Medidas.ABAJO, Medidas.ALTO, Medidas.COLOR, Medidas.TEJADO
local TRAMPILLA, FONDO_SOTANO, BANCO_SOTANO = Medidas.TRAMPILLA, Medidas.FONDO_SOTANO, Medidas.BANCO_SOTANO

local MapaAnexos = {}

-- Las ayudas de Mapa (las pone `iniciar`, al cargar Mapa). `casa()` da la casa de ahora: Mapa la crea en
-- construirCasa y Mapa.conPadre la cambia un rato, así que no se guarda una copia.
local Mapa, casa, bloque, variante, mando, lampara, adorno, tienda, muro, v, p, MUEBLES

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
	gen.Parent = casa()
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
	modelo.Parent = casa()
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
	modelo.Parent = casa()
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
	coche.Parent = casa()
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
			cuna.Parent = casa()
		end
	end
	-- Lo de dentro (cuarto de revelado, muebles tapados, vigas…), en vestirDesvan.
end

-- Sótano bajo el patio de atrás: de la puerta del fondo del pasillo (z = 33) baja una escalera tapada (x -3..3) hasta
-- una sala bajo tierra (x -12..12, z 47.6..65.6, suelo en y = -11; encima, el suelo del bosque). El bosque deja un
-- hueco en el suelo encima de la escalera (HUECO). Paredes de piedra, hormigón roto, techo y peldaños de tablas, propios
-- de la sala (11.8.13); los muebles, en vestirSotano.
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
		for _, b in (casa():FindFirstChild("BancoSotano") :: Model):GetChildren() do
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
--   lado (desván, delante del baúl). Las cerillas no están sueltas: las da la caja fuerte del rico (Pistas, pista 12).
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
	guias.Parent = casa()

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
	palanca.Parent = casa()

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
	trampilla.Parent = casa()
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
	escala.Parent = casa()
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
	porton.Parent = casa()
	muro(-59, 3, -59, 33, ABAJO, { v(4, 4, 3, 9, false) }, OESTE)
	muro(-59, 33, -39, 33, ABAJO, {}, Vector3.new(0, 0, 1))
	Fachada.chapa(bloque("Techo", Vector3.new(21, 1, 31), CFrame.new(-49.5, ABAJO + ALTO + 0.5, 18), COLOR.Oscuro, Enum.Material.CorrodedMetal))
	construirCoche(CFrame.new(-49, ABAJO, 18))
	-- El taller, en la pared del fondo frente al portón (11.8.12, opción B elegida por el usuario): el banco de Blender
	-- (BancoTaller, en vestirGaraje) tapa los bloques del de siempre, que siguen chocando y siendo el Banco del Taller.
	banco("Garaje", CFrame.lookAt(Vector3.new(-49.5, ABAJO, 31.1), Vector3.new(-49.5, ABAJO, 20)))
	if MUEBLES.BancoTaller then
		for _, b in (casa():FindFirstChild("BancoGaraje") :: Model):GetChildren() do
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

-- Lo llama Mapa al cargar, con sus ayudas (`a`).
function MapaAnexos.iniciar(a)
	Mapa = a.Mapa
	casa = a.casa
	bloque = a.bloque
	variante = a.variante
	mando = a.mando
	lampara = a.lampara
	adorno = a.adorno
	tienda = a.tienda
	muro = a.muro
	v = a.v
	p = a.p
	MUEBLES = a.MUEBLES
end

MapaAnexos.construirCobertizo = construirCobertizo
MapaAnexos.construirCaballete = construirCaballete
MapaAnexos.construirDesvan = construirDesvan
MapaAnexos.construirSotano = construirSotano
MapaAnexos.construirFinal = construirFinal
MapaAnexos.construirGaraje = construirGaraje

return MapaAnexos
