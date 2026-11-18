-- Lo de dentro de cada sala de la casa (11.8, plan-salas.md), sacado de Mapa sin cambiar nada: papel, suelos y techos
-- (SALAS), lo abandonado y un `vestir<Sala>` por sala con sus muebles, manchas y luces. Mapa.start los llama después
-- de Separar, con la casa ya hecha; las ayudas (bloque, tienda…) son las de Mapa (`iniciar`).
local CollectionService = game:GetService("CollectionService")

local Medidas = require(script.Parent.MapaMedidas)
local ABAJO, ARRIBA, ALTO, BAJO_TECHO = Medidas.ABAJO, Medidas.ARRIBA, Medidas.ALTO, Medidas.BAJO_TECHO
local COLOR, TEJADO, FONDO_SOTANO, BANCO_SOTANO = Medidas.COLOR, Medidas.TEJADO, Medidas.FONDO_SOTANO, Medidas.BANCO_SOTANO
local TORRE, DORMITORIO_GRANDE = Medidas.TORRE, Medidas.DORMITORIO_GRANDE

local MapaSalas = {}

-- Las ayudas de Mapa (las pone `iniciar`, al cargar Mapa). `casa()` da la casa de ahora: Mapa la crea en
-- construirCasa y Mapa.conPadre la cambia un rato, así que no se guarda una copia.
local Mapa, casa, bloque, variante, lampara, adorno, tienda, contraPared, mancha, SANGRE, MUEBLES

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
	for _, pared in casa():GetChildren() do
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
	for _, piso in casa():GetChildren() do
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
	CollectionService:AddTag(luna, "Luna") -- su haz visible de noche (AireVista, docs/sistemas/aire.md)
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
	for _, pared in casa():GetChildren() do
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
	local sotano = casa():FindFirstChild("Sotano")
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
	for _, modelo in casa():GetChildren() do
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
	for _, pared in casa():GetChildren() do
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
	local porton = casa():FindFirstChild("Porton")
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
		for _, pieza in casa():GetChildren() do
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
	for _, m in casa():GetChildren() do
		local pos = m:IsA("Model") and m.Name == "CortinaVano" and m:GetPivot().Position
		if pos and pos.X > 12 and pos.Z > 9 and pos.Z < 33 and math.abs(pos.Y - ARRIBA) < 1 then
			m:Destroy()
		end
	end
	-- Peldaños de madera gastada, como el suelo de la galería.
	local Y = sueloArriba(Vector3.new(28, ARRIBA, 21)) + 0.06 -- cara de la lámina del suelo de la sala
	for _, peldano in casa():GetChildren() do
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
			cuna.Parent = casa()
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

-- Lo llama Mapa al cargar, con sus ayudas (`a`).
function MapaSalas.iniciar(a)
	Mapa = a.Mapa
	casa = a.casa
	bloque = a.bloque
	variante = a.variante
	lampara = a.lampara
	adorno = a.adorno
	tienda = a.tienda
	contraPared = a.contraPared
	mancha = a.mancha
	SANGRE = a.SANGRE
	MUEBLES = a.MUEBLES
end

MapaSalas.vestirParedes = vestirParedes
MapaSalas.vestirSuelos = vestirSuelos
MapaSalas.vestirVestibulo = vestirVestibulo
MapaSalas.vestirSalon = vestirSalon
MapaSalas.vestirComedor = vestirComedor
MapaSalas.vestirCocina = vestirCocina
MapaSalas.vestirPasillo = vestirPasillo
MapaSalas.vestirDormitorio = vestirDormitorio
MapaSalas.vestirGaleria = vestirGaleria
MapaSalas.vestirDormitorioGrande = vestirDormitorioGrande
MapaSalas.vestirHabitacionRico = vestirHabitacionRico
MapaSalas.vestirNinos = vestirNinos
MapaSalas.vestirDesvan = vestirDesvan
MapaSalas.vestirGaraje = vestirGaraje
MapaSalas.vestirSotano = vestirSotano
MapaSalas.abandonar = abandonar

return MapaSalas
