-- Lo de dentro de los edificios del pueblo en los que se entra (11.5, plano en PuebloPlano): la tienda con el vendedor,
-- la casa de la puerta rota (comida y la pista 3), la iglesia, la cripta (llave del cementerio) y la caseta del
-- enterrador (la otra llave y la pista 5). Pedido por el usuario: "bien, pero rápido", una pasada de cada uno.
-- Reglas de la casa (pedido por el usuario): ninguna ventana tapada, el centro libre para correr, nada delante de la
-- puerta y los muebles contra las paredes, mirando a la sala, apoyados en el suelo y de tamaño creíble.
-- Las paredes se forran por dentro con láminas finas que no chocan y dejan libres los huecos de puertas y ventanas.
local PuebloInteriores = {}

local C -- el ctx de Lugares (bloque, llave, objeto, vendedor, Mapa, Plano…)
local azar = Random.new(115)

-- Cara de arriba del suelo propio (lámina de 0,06 sobre el suelo del cascarón, en y = 1).
local F = 1.06
local GROSOR = 0.1 -- de las láminas de las paredes

-- Imágenes de sangre seca y desconchones (tools/blender/sangre.py, las del vestíbulo): ya traen su color.
local SANGRE = {
	Gotas = "rbxassetid://100856467107255",
	Arrastre = "rbxassetid://95443489334328",
	Salpicadura = "rbxassetid://82919660578513",
	Desconchon = "rbxassetid://97919593855720",
}
local BLANCO = Color3.new(1, 1, 1)
local HUMEDAD = Color3.fromRGB(46, 36, 24)
local MADERA = Color3.fromRGB(72, 54, 40)
local MADERA_OSCURA = Color3.fromRGB(48, 36, 28)
local PIEDRA = Color3.fromRGB(104, 100, 94)
local CERA = Color3.fromRGB(196, 186, 160)
local HUESO = Color3.fromRGB(140, 128, 104)
-- Sangre seca: oscurece las imágenes (ya traen su rojo vivo) para que se vea vieja y discreta.
local SECA = Color3.fromRGB(135, 95, 90)

-- Pieza que solo se ve: no choca, no tapa rayos y sin sombra.
local function lamina(nombre: string, tam: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, padre: Instance?): Part
	local p = C.bloque(nombre, tam, cf, color, material or Enum.Material.SmoothPlastic, padre)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

-- Pieza que choca (muebles hechos de bloques).
local function solido(nombre: string, tam: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, padre: Instance?): Part
	return C.bloque(nombre, tam, cf, color, material or Enum.Material.Wood, padre)
end

local function mueble(nombre: string, cf: CFrame, sinChoque: boolean?): Model?
	return C.Mapa.mueble(nombre, cf, sinChoque)
end

-- Un mueble de ServerStorage.Muebles contra la pared: (x, z) en la cara de la pared, de pie en el suelo propio.
local function contra(nombre: string, x: number, z: number, frente: Vector3, sinChoque: boolean?): Model?
	return C.Mapa.contraPared(nombre, x, F, z, frente, sinChoque)
end

-- Huecos de puertas y ventanas de un lado: { u1, u2, y1, y2 } (u = x en N/S, z en E/O), con un poco de margen.
local function huecos(e, lado: string): { { number } }
	local P = C.Plano
	local lista = {}
	local med = if e.nombre == "Iglesia" then P.VENTANA_IGLESIA else P.VENTANA
	local m = 0.1
	for _, w in e.ventanas do
		if w.lado == lado then
			local c = if lado == "N" or lado == "S" then e.x + w.desde else e.z + w.desde
			local y0 = P.SUELO + (w.planta - 1) * P.altoPlanta(e) + med.alfeizar
			table.insert(lista, { c - med.ancho / 2 - m, c + med.ancho / 2 + m, y0 - m, y0 + med.alto + m })
		end
	end
	if e.puerta == lado then
		local c = if lado == "N" or lado == "S" then e.x else e.z
		table.insert(lista, { c - P.PUERTA.ancho / 2 - m, c + P.PUERTA.ancho / 2 + m, P.SUELO - 1, P.SUELO + P.PUERTA.alto + m })
	end
	return lista
end

-- Rectángulos de [u1, u2] x [y1, y2] que no pisan ningún hueco (tiras verticales cortadas en los bordes de los huecos).
local function trozos(u1: number, u2: number, y1: number, y2: number, hs: { { number } }): { { number } }
	local cortes = { u1, u2 }
	for _, h in hs do
		for _, u in { h[1], h[2] } do
			if u > u1 and u < u2 then
				table.insert(cortes, u)
			end
		end
	end
	table.sort(cortes)
	local res = {}
	for i = 1, #cortes - 1 do
		local a, b = cortes[i], cortes[i + 1]
		if b - a > 0.02 then
			local medio = (a + b) / 2
			local tapan = {}
			for _, h in hs do
				if h[1] < medio and medio < h[2] and h[4] > y1 and h[3] < y2 then
					table.insert(tapan, h)
				end
			end
			table.sort(tapan, function(p, q)
				return p[3] < q[3]
			end)
			local y = y1
			for _, h in tapan do
				if h[3] > y + 0.02 then
					table.insert(res, { a, b, y, math.min(h[3], y2) })
				end
				y = math.max(y, h[4])
			end
			if y2 > y + 0.02 then
				table.insert(res, { a, b, y, y2 })
			end
		end
	end
	return res
end

export type Capa = { y1: number, y2: number, variante: string?, color: Color3?, material: Enum.Material?, grueso: number? }

-- Forra las cuatro paredes por dentro con varias capas (zócalo, papel, moldura…), suelo y techo propios.
local function forrar(e, padre: Instance, capas: { Capa }, suelo: string, techo: string?)
	local x1, x2, z1, z2 = C.Plano.dentro(e)
	for _, lado in { "N", "S", "E", "O" } do
		local hs = huecos(e, lado)
		local enX = lado == "N" or lado == "S"
		for _, capa in capas do
			local t = capa.grueso or GROSOR
			-- Las de E y O, entre las de N y S de su misma capa: así no se pisan en las esquinas.
			local u1, u2 = if enX then x1 else z1 + t + 0.02, if enX then x2 else z2 - t - 0.02
			for _, r in trozos(u1, u2, capa.y1, capa.y2, hs) do
				local largo, alto = r[2] - r[1], r[4] - r[3]
				local u, y = (r[1] + r[2]) / 2, (r[3] + r[4]) / 2
				local cf, tam
				if lado == "N" then
					cf, tam = CFrame.new(u, y, z1 + 0.01 + t / 2), Vector3.new(largo, alto, t)
				elseif lado == "S" then
					cf, tam = CFrame.new(u, y, z2 - 0.01 - t / 2), Vector3.new(largo, alto, t)
				elseif lado == "E" then
					cf, tam = CFrame.new(x2 - 0.01 - t / 2, y, u), Vector3.new(t, alto, largo)
				else
					cf, tam = CFrame.new(x1 + 0.01 + t / 2, y, u), Vector3.new(t, alto, largo)
				end
				local p = lamina("Forro", tam, cf, capa.color or BLANCO, capa.material, padre)
				p:SetAttribute("SinSeparar", true) -- ya va apartada de la pared (Separar la engordaba)
				if capa.variante then
					C.Mapa.variante(p, capa.variante)
				end
			end
		end
	end
	local p = lamina("Suelo", Vector3.new(x2 - x1, F - 1, z2 - z1), CFrame.new((x1 + x2) / 2, (1 + F) / 2, (z1 + z2) / 2), BLANCO,
		nil, padre)
	C.Mapa.variante(p, suelo)
	p:SetAttribute("SinSeparar", true)
	if techo then
		local arriba = 1 + e.alto - 0.02
		local t = lamina("Techo", Vector3.new(x2 - x1, 0.06, z2 - z1), CFrame.new((x1 + x2) / 2, arriba - 0.03, (z1 + z2) / 2), BLANCO,
			nil, padre)
		C.Mapa.variante(t, techo)
		t:SetAttribute("SinSeparar", true)
	end
end

-- Telaraña en una esquina del techo, mirando a la sala (como abandonar() de Mapa).
local function telarana(x: number, techo: number, z: number, mira: Vector3, escala: number?)
	local nombre = if azar:NextNumber() < 0.5 then "Telarana" else "TelaranaTecho"
	local molde = C.Mapa.MUEBLES[nombre]
	if not molde then
		return
	end
	local k = escala or 0.45
	local pos = Vector3.new(x, techo - (molde:GetAttribute("Tam") :: Vector3).Y * k, z)
	local tela = mueble(nombre, CFrame.lookAt(pos, pos + mira), true)
	if tela then
		tela:ScaleTo(tela:GetScale() * k)
	end
end

-- Papeles y basura por el suelo alrededor de `sitio` (radio `r`).
local function basura(sitio: Vector3, r: number, papeles: number, tablas: number, padre: Instance)
	for _ = 1, papeles do
		local p = lamina("Papel", Vector3.new(0.8, 0.03, 1.1), CFrame.new(sitio + Vector3.new(azar:NextNumber(-r, r), 0.02,
			azar:NextNumber(-r, r))) * CFrame.Angles(0, azar:NextNumber(0, math.pi * 2), 0), Color3.fromRGB(150, 140, 118),
			Enum.Material.Fabric, padre)
		p.Position = Vector3.new(p.Position.X, F + 0.015, p.Position.Z)
	end
	for i = 1, tablas do
		lamina("Tabla", Vector3.new(0.5, 0.14, azar:NextNumber(2, 4)), CFrame.new(sitio + Vector3.new(azar:NextNumber(-r, r) * 0.6,
			0.07 + (i - 1) * 0.13, azar:NextNumber(-r, r) * 0.6)) * CFrame.Angles(0, azar:NextNumber(0, math.pi), 0),
			Color3.fromRGB(78, 62, 46), Enum.Material.WoodPlanks, padre)
	end
end

-- Vela de cera (encendida o no) en `pie` (su base).
local function vela(pie: Vector3, alto: number, encendida: boolean, padre: Instance, brillo: number?, alcance: number?)
	local v = lamina("Vela", Vector3.new(alto, 0.22, 0.22), CFrame.new(pie + Vector3.new(0, alto / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		CERA, Enum.Material.SmoothPlastic, padre)
	v.Shape = Enum.PartType.Cylinder
	-- Cera derretida en la base.
	local charco = lamina("Cera", Vector3.new(0.04, 0.5, 0.5), CFrame.new(pie + Vector3.new(0, 0.02, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		CERA, Enum.Material.SmoothPlastic, padre)
	charco.Shape = Enum.PartType.Cylinder
	if encendida then
		local llama = lamina("Llama", Vector3.new(0.1, 0.22, 0.1), CFrame.new(pie + Vector3.new(0, alto + 0.12, 0)),
			Color3.fromRGB(190, 120, 60), Enum.Material.Neon, padre)
		llama.Transparency = 0.2
		if brillo then
			local luz = Instance.new("PointLight")
			luz.Color = Color3.fromRGB(255, 170, 100)
			luz.Brightness = brillo
			luz.Range = alcance or 12
			luz.Shadows = false
			luz.Parent = llama
		end
	end
end

local function modelo(nombre: string): Model
	local m = Instance.new("Model")
	m.Name = nombre
	m.Parent = C.carpeta
	return m
end

---------------------------------------------------------------------------------------------------------------------
-- Tienda: el vendedor detrás del mostrador mirando a la puerta (este); estanterías llenas detrás de él y cajas y
-- sacos en los rincones. La única luz: un farol muy flojo en el mostrador.
local function tienda()
	local e = C.Plano.buscar("Tienda")
	local m = modelo("InteriorTienda")
	local x1, x2, z1, z2 = C.Plano.dentro(e) -- -26.5, -13.5, -460.5, -449.5
	local techo = 1 + e.alto
	forrar(e, m, {
		{ y1 = 1, y2 = 1.45, color = MADERA_OSCURA, material = Enum.Material.Wood, grueso = 0.2 }, -- rodapié
		{ y1 = 1.45, y2 = 3.6, variante = "ZocaloComedor" },
		{ y1 = 3.5, y2 = 3.75, color = MADERA_OSCURA, material = Enum.Material.Wood, grueso = 0.2 }, -- moldura
		{ y1 = 3.6, y2 = techo - 0.02, variante = "PapelTrastero" },
	}, "SueloTrastero", "TechoSalon")

	C.Mapa.conPadre(m, function()
		-- Mostrador: cuerpo, tablero y cuarterones por delante (el lado de la puerta).
		local mx, mz, largo = -18.15, -455, 7.2
		solido("Mostrador", Vector3.new(1.5, 3.06, largo), CFrame.new(mx, F + 1.53, mz), MADERA_OSCURA, Enum.Material.WoodPlanks, m)
		solido("Tablero", Vector3.new(1.9, 0.18, largo + 0.3), CFrame.new(mx + 0.1, F + 3.15, mz), MADERA, Enum.Material.Wood, m)
		for _, dz in { -2.4, 0, 2.4 } do
			lamina("Cuarteron", Vector3.new(0.08, 2, 1.9), CFrame.new(mx + 0.78, F + 1.6, mz + dz), MADERA, Enum.Material.Wood, m)
		end
		lamina("Zocalo", Vector3.new(0.12, 0.35, largo), CFrame.new(mx + 0.8, F + 0.17, mz), Color3.fromRGB(30, 24, 20), Enum.Material.Wood, m)
		-- Caja registradora vieja y una balanza en el mostrador (no tapan el mando del vendedor, en z = -455).
		local arriba = F + 3.24
		lamina("Caja", Vector3.new(1.1, 0.75, 1.2), CFrame.new(mx, arriba + 0.375, mz - 2.6), Color3.fromRGB(46, 44, 40), Enum.Material.Metal, m)
		lamina("Teclas", Vector3.new(0.6, 0.12, 1.0), CFrame.new(mx + 0.35, arriba + 0.8, mz - 2.6) * CFrame.Angles(0, 0, math.rad(-25)),
			Color3.fromRGB(110, 96, 70), Enum.Material.Metal, m)
		lamina("Balanza", Vector3.new(0.9, 0.12, 0.9), CFrame.new(mx - 0.1, arriba + 0.06, mz + 2.5), Color3.fromRGB(88, 74, 50), Enum.Material.Metal, m)
		lamina("Plato", Vector3.new(0.08, 1.0, 1.0), CFrame.new(mx - 0.1, arriba + 0.6, mz + 2.5) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(120, 100, 64), Enum.Material.Metal, m).Shape = Enum.PartType.Cylinder
		-- El farol, en la punta norte del mostrador: luz muy floja, sin sombras.
		local farol = mueble("LamparaAceitePH", CFrame.new(mx - 0.1, arriba, mz - 1.4), true)
		local luz = lamina("Luz", Vector3.new(0.2, 0.2, 0.2), CFrame.new(mx - 0.1, arriba + 0.8, mz - 1.4), Color3.fromRGB(200, 140, 80),
			Enum.Material.SmoothPlastic, m)
		luz.Transparency = if farol then 1 else 0
		local punto = Instance.new("PointLight")
		punto.Color = Color3.fromRGB(255, 170, 100)
		punto.Brightness = 0.35
		punto.Range = 13
		punto.Shadows = false
		punto.Parent = luz

		-- Detrás del vendedor (pared oeste): la despensa y la estantería de metal, con cosas en las baldas.
		contra("DespensaPH", x1, -457.3, Vector3.xAxis)
		contra("EstanteriaMetalPH", x1, -452, Vector3.xAxis)
		local function balda(nombre: string, z: number, y: number, giro: number?)
			local x = x1 + 1.1 + azar:NextNumber(-0.15, 0.15)
			mueble(nombre, CFrame.new(x, F + y, z) * CFrame.Angles(0, math.pi / 2 + (giro or azar:NextNumber(-0.4, 0.4)), 0), true)
		end
		for _, b in {
			{ "LatasPH", -459.2, 1.6 }, { "LataOxidadaPH", -458.3, 1.6 }, { "LatasPH", -456.6, 1.6 }, { "OllaPH", -455.6, 1.6 },
			{ "JarraPH", -459.0, 2.8 }, { "LataOxidadaPH", -457.6, 2.8 }, { "LataOxidadaPH", -457.0, 2.8 },
			{ "CestaPH", -458.6, 4.0 }, { "LatasPH", -456.4, 4.0 }, { "LatasPH", -455.6, 4.0 },
			{ "EnciclopediaPH", -458.0, 5.3, 0 }, { "LataOxidadaPH", -456.0, 5.3 }, { "Licores", -457.4, 6.9, 0 },
			{ "CajaCartonPH", -452.6, 0.5, 0 }, { "CajaCartonPH", -451.0, 2.6, 0.2 }, { "LatasPH", -453.2, 4.6 },
			{ "LataOxidadaPH", -452.2, 4.6 }, { "LatasPH", -451.1, 4.6 }, { "CuboPH", -452.3, 6.6, 0 },
		} do
			balda(b[1], b[2], b[3], b[4])
		end
		-- Rincones de detrás del mostrador: un barril, un cajón y un cesto (bajos, junto a las paredes).
		mueble("BarrilPH", CFrame.new(-22.4, F, z1 + 1.6))
		contra("CajonPH", -20, z2, -Vector3.zAxis)
		contra("CestoMimbrePH", -22.6, z2, -Vector3.zAxis)
		-- Lado de los clientes: un cajón bajo al norte (bajo la ventana), el estante y una caja al sur.
		contra("CajonPH", -15.4, z1, Vector3.zAxis)
		contra("EstanteCocinaPH", -16.1, z2, -Vector3.zAxis)
		contra("CajaCartonPH", -14.5, z2, -Vector3.zAxis)

		-- Lo abandonado.
		telarana(x1 + 0.4, techo, z1 + 0.4, Vector3.new(1, 0, 1))
		telarana(x2 - 0.4, techo, z2 - 0.4, Vector3.new(-1, 0, -1))
		telarana(x1 + 0.4, techo, z2 - 0.4, Vector3.new(1, 0, -1))
		C.Mapa.mancha(Vector3.new(-22.5, 8.4, z1 + 0.13), Vector3.zAxis, 3.5, SANGRE.Desconchon, Color3.fromRGB(170, 160, 145), 0.8)
		C.Mapa.mancha(Vector3.new(-23.5, techo - 1.6, z1 + 0.13), Vector3.zAxis, 3.5, C.Mapa.SANGRE[1], HUMEDAD, 1.4)
		C.Mapa.mancha(Vector3.new(-19.5, 8.5, z2 - 0.13), -Vector3.zAxis, 4.5, C.Mapa.SANGRE[1], HUMEDAD, 2.2)
		C.Mapa.mancha(Vector3.new(-17.35, F + 1.4, -452.6), Vector3.xAxis, 1.6, SANGRE.Gotas, SECA, 0) -- en el mostrador
		C.Mapa.mancha(Vector3.new(-15.6, F + 0.02, -453.2), Vector3.yAxis, 2.6, SANGRE.Arrastre, SECA, 0.4, 5)
		basura(Vector3.new(-15.5, F, -458.5), 1.2, 5, 2, m)
		basura(Vector3.new(-23.5, F, -451.5), 1, 4, 0, m)
	end)

	-- El vendedor, detrás del mostrador mirando a la puerta (su mando, 3 delante y a 4 de alto, sobre el tablero).
	C.vendedor(Vector3.new(-22, 1, -455), Vector3.new(1, 0, 0))
end

---------------------------------------------------------------------------------------------------------------------
-- Casa de la puerta rota: la cocina de alguien que vivió aquí escondido. La mesa (pista 3) contra la pared este,
-- debajo de la ventana; un colchón sucio en el suelo, la cocina de hierro y la nevera. Comida y chatarra.
local function casaAbierta()
	local e = C.Plano.buscar("CasaAbierta")
	local m = modelo("InteriorCasaAbierta")
	local x1, x2, z1, z2 = C.Plano.dentro(e) -- 14.5, 25.5, -445.5, -434.5
	local techo = 1 + e.alto
	forrar(e, m, {
		{ y1 = 1, y2 = 1.45, color = MADERA_OSCURA, material = Enum.Material.Wood, grueso = 0.2 },
		{ y1 = 1.45, y2 = 3.6, variante = "ZocaloRico" },
		{ y1 = 3.5, y2 = 3.75, color = MADERA_OSCURA, material = Enum.Material.Wood, grueso = 0.2 },
		{ y1 = 3.6, y2 = techo - 0.02, variante = "PapelDormitorio" },
	}, "SueloDormitorio", "TechoComedor")

	C.Mapa.conPadre(m, function()
		-- La mesa (su cara de arriba a 4,02, como antes) y una silla
		-- en su punta sur (el centro, libre para correr).
		mueble("MesaCocina", CFrame.new(24.0, 4.02 - 3.1, -440.1))
		mueble("SillaCocinaPH", CFrame.new(24.0, F, -436.4) * CFrame.Angles(0, 0.15, 0))
		C.objeto("Lata", Vector3.new(24.4, 4.22, -438.4))
		C.objeto("Botella", Vector3.new(24.5, 4.22, -441.9))
		C.objeto("Botella", Vector3.new(21.0, F + 0.2, -444.8)) -- en el suelo, bajo la ventana norte
		C.objeto("Chatarra", Vector3.new(16.2, F + 0.2, -435.6))
		-- Nevera en el rincón del noreste y la cocina de hierro contra la pared sur, con una olla.
		contra("NeveraVieja", 23.9, z1, Vector3.zAxis)
		contra("CocinaHierro", 19.4, z2, -Vector3.zAxis)
		mueble("OllaPH", CFrame.new(18.6, F + 3.46, z2 - 1.4), true)
		mueble("SartenPH", CFrame.new(20.4, F + 3.46, z2 - 1.3) * CFrame.Angles(0, 0.6, 0), true)
		-- Un retrato torcido encima de la cocina (mirando a -z, al norte, como viene).
		mueble("CuadroFamiliaPH2", CFrame.new(19.4, 5.4, z2 - 0.23) * CFrame.Angles(0, 0, math.rad(8)), true)
		-- El colchón en el suelo, a lo largo de la pared norte (no llega a la puerta), con una manta y sangre seca.
		local cx, cz = 17.1, z1 + 1.45
		solido("Colchon", Vector3.new(5, 0.45, 2.6), CFrame.new(cx, F + 0.225, cz) * CFrame.Angles(0, 0.04, 0), Color3.fromRGB(150, 128, 90),
			Enum.Material.Fabric, m)
		lamina("Almohada", Vector3.new(1.2, 0.35, 1.8), CFrame.new(cx - 1.8, F + 0.6, cz) * CFrame.Angles(0, 0.1, math.rad(4)),
			Color3.fromRGB(140, 130, 110), Enum.Material.Fabric, m)
		lamina("Manta", Vector3.new(2.6, 0.12, 2.8), CFrame.new(cx + 0.9, F + 0.5, cz + 0.1) * CFrame.Angles(math.rad(3), 0.2, math.rad(-3)),
			Color3.fromRGB(70, 60, 48), Enum.Material.Fabric, m)
		C.Mapa.mancha(Vector3.new(cx - 0.6, F + 0.47, cz), Vector3.yAxis, 1.6, SANGRE.Gotas, SECA, 1)
		C.Mapa.mancha(Vector3.new(cx - 1, 3.4, z1 + 0.13), Vector3.zAxis, 2.2, SANGRE.Gotas, SECA, 0.3)

		-- Lo abandonado.
		telarana(x1 + 0.4, techo, z1 + 0.4, Vector3.new(1, 0, 1))
		telarana(x2 - 0.4, techo, z2 - 0.4, Vector3.new(-1, 0, -1))
		C.Mapa.mancha(Vector3.new(x2 - 0.13, 7.5, -443.5), -Vector3.xAxis, 3.5, SANGRE.Desconchon, Color3.fromRGB(170, 160, 145), 2)
		C.Mapa.mancha(Vector3.new(16, 8.6, z2 - 0.13), -Vector3.zAxis, 3, SANGRE.Desconchon, Color3.fromRGB(170, 160, 145), 0.5)
		C.Mapa.mancha(Vector3.new(x1 + 0.13, 10.3, -440), Vector3.xAxis, 2.6, C.Mapa.SANGRE[1], HUMEDAD, 0.9)
		C.Mapa.mancha(Vector3.new(19, F + 0.02, -441), Vector3.yAxis, 2.4, SANGRE.Arrastre, SECA, math.pi / 2 + 0.3, 5)
		basura(Vector3.new(23.5, F, -436), 1.2, 4, 2, m)
		basura(Vector3.new(15.6, F, -437), 1, 3, 0, m)
	end)
end

---------------------------------------------------------------------------------------------------------------------
-- Iglesia: bancos a los dos lados de un pasillo central de 7 (de la puerta, al oeste, al altar, al este), el altar
-- sobre una tarima con velas encendidas (la única luz, muy floja) y una cruz torcida en la pared del fondo.
local function banco(m: Instance, cx: number, zc: number, largo: number, cf0: CFrame?)
	-- Mira a +x (al altar); `cf0` lo mueve todo (el banco volcado).
	local base = (cf0 or CFrame.new()) * CFrame.new(cx, F, zc)
	local function pieza(nombre: string, tam: Vector3, off: CFrame)
		local p = solido(nombre, tam, base * off, MADERA, Enum.Material.Wood, m)
		p.Color = Color3.fromRGB(64, 46, 34)
		return p
	end
	pieza("Asiento", Vector3.new(1.4, 0.22, largo), CFrame.new(0, 1.55, 0))
	pieza("Respaldo", Vector3.new(0.18, 1.8, largo), CFrame.new(-0.72, 2.5, 0) * CFrame.Angles(0, 0, math.rad(8)))
	pieza("Travesano", Vector3.new(0.24, 0.22, largo + 0.1), CFrame.new(-0.86, 3.38, 0))
	for _, s in { -1, 1 } do
		-- Costado: la parte baja hasta el brazo y un poste atrás que sube con el respaldo.
		pieza("Lateral", Vector3.new(1.6, 2.1, 0.22), CFrame.new(0, 1.05, s * (largo / 2 + 0.11)))
		pieza("Poste", Vector3.new(0.4, 3.5, 0.24), CFrame.new(-0.82, 1.75, s * (largo / 2 + 0.11)))
		pieza("Brazo", Vector3.new(1.75, 0.16, 0.3), CFrame.new(0.05, 2.15, s * (largo / 2 + 0.11)))
	end
	pieza("Reclinatorio", Vector3.new(0.4, 0.22, largo - 0.4), CFrame.new(1.05, 0.45, 0))
	lamina("Balda", Vector3.new(0.5, 0.1, largo - 0.2), base * CFrame.new(-0.95, 2.5, 0), Color3.fromRGB(60, 44, 32), Enum.Material.Wood, m)
end

local function iglesia()
	local e = C.Plano.buscar("Iglesia")
	local m = modelo("InteriorIglesia")
	local x1, x2, z1, z2 = C.Plano.dentro(e) -- 22.5, 37.5, -513.5, -486.5
	local techo = 1 + e.alto
	forrar(e, m, {
		{ y1 = 1, y2 = 3.4, variante = "ParedSotano" }, -- zócalo de piedra
		{ y1 = 3.3, y2 = 3.6, color = Color3.fromRGB(86, 82, 76), material = Enum.Material.Slate, grueso = 0.22 },
		{ y1 = 3.4, y2 = techo - 0.02, variante = "PapelTrastero" },
	}, "SueloCocina", "TablasDesvan")

	C.Mapa.conPadre(m, function()
		-- Bancos: cuatro filas por lado, pasillo central de z -503,5 a -496,5. Uno volcado y otro movido.
		local filas = { 24.5, 27.2, 29.9, 32.6 }
		for i, cx in filas do
			banco(m, cx, -508.15, 9.1)
			if i == 3 then
				-- Volcado hacia atrás, tumbado sobre el canto de atrás entre la fila 2 y la 4.
				banco(m, 0, 0, 9.1, CFrame.new(31.7, F + 1.03, -491.85) * CFrame.Angles(0, 0, math.pi / 2) * CFrame.new(0, -F, 0))
			elseif i == 2 then
				banco(m, 0, 0, 9.1, CFrame.new(cx + 0.2, 0, -491.85) * CFrame.Angles(0, math.rad(4), 0))
			else
				banco(m, cx, -491.85, 9.1)
			end
		end
		-- Alfombra roja del pasillo, gastada.
		local alfombra = lamina("Alfombra", Vector3.new(10.6, 0.04, 3.4), CFrame.new(28.4, F + 0.02, -500), BLANCO, nil, m)
		C.Mapa.variante(alfombra, "AlfombraRoja")
		alfombra:SetAttribute("SinSeparar", true)
		C.Mapa.mancha(Vector3.new(30.5, F + 0.05, -500.3), Vector3.yAxis, 2.6, SANGRE.Arrastre, SECA, 0.05, 9)

		-- Tarima del altar, de pared a pared, y el altar de piedra con su paño.
		local tx = 34.5
		solido("Tarima", Vector3.new(x2 - tx, 0.5, z2 - z1), CFrame.new((tx + x2) / 2, F + 0.25, (z1 + z2) / 2), Color3.fromRGB(70, 52, 38),
			Enum.Material.WoodPlanks, m)
		solido("Escalon", Vector3.new(0.8, 0.25, 7), CFrame.new(tx - 0.4, F + 0.125, -500), Color3.fromRGB(70, 52, 38), Enum.Material.WoodPlanks, m)
		local arriba = F + 0.5
		solido("Altar", Vector3.new(2.2, 3.1, 6), CFrame.new(36, arriba + 1.55, -500), PIEDRA, Enum.Material.Slate, m)
		solido("Losa", Vector3.new(2.6, 0.25, 6.5), CFrame.new(36, arriba + 3.22, -500), Color3.fromRGB(92, 88, 82), Enum.Material.Slate, m)
		lamina("Pano", Vector3.new(2.7, 0.04, 4.2), CFrame.new(36, arriba + 3.37, -500), Color3.fromRGB(150, 142, 124), Enum.Material.Fabric, m)
		lamina("Caida", Vector3.new(0.04, 1.6, 4.2), CFrame.new(34.63, arriba + 2.6, -500), Color3.fromRGB(140, 130, 112), Enum.Material.Fabric, m)
		C.Mapa.mancha(Vector3.new(34.87, arriba + 1.2, -501.8), -Vector3.xAxis, 1.8, SANGRE.Gotas, SECA, 0)
		local mesa = arriba + 3.39
		vela(Vector3.new(36.2, mesa, -502.4), 1.1, true, m, 0.45, 16)
		vela(Vector3.new(36.3, mesa, -497.8), 0.8, true, m)
		vela(Vector3.new(35.8, mesa, -497.2), 0.5, false, m)
		mueble("CandelabroPH", CFrame.new(36.4, mesa, -500), true)
		-- Velas por el suelo de la tarima, casi todas apagadas.
		for _, v in { { 35.2, -504.6, 0.7, false }, { 35.0, -495.5, 0.4, true }, { 36.8, -505.2, 1.0, false }, { 37.0, -494.6, 0.6, false } } do
			vela(Vector3.new(v[1], arriba, v[2]), v[3], v[4], m)
		end
		-- Atril a un lado de la tarima.
		local ax, az = 35.4, -507.8
		solido("Atril", Vector3.new(0.4, 3.2, 0.4), CFrame.new(ax, arriba + 1.6, az), MADERA_OSCURA, Enum.Material.Wood, m)
		solido("Pie", Vector3.new(1.4, 0.2, 1.4), CFrame.new(ax, arriba + 0.1, az), MADERA_OSCURA, Enum.Material.Wood, m)
		lamina("Atril", Vector3.new(1.3, 0.12, 1.6), CFrame.new(ax - 0.1, arriba + 3.3, az) * CFrame.Angles(0, 0, math.rad(-25)), MADERA,
			Enum.Material.Wood, m)
		lamina("Libro", Vector3.new(0.9, 0.1, 1.3), CFrame.new(ax - 0.12, arriba + 3.4, az) * CFrame.Angles(0, 0, math.rad(-25)),
			Color3.fromRGB(150, 136, 108), Enum.Material.Fabric, m)
		-- La cruz de madera, torcida, entre las dos ventanas del fondo.
		local cruz = CFrame.new(x2 - 0.35, 9.4, -500) * CFrame.Angles(math.rad(7), 0, 0)
		lamina("Cruz", Vector3.new(0.4, 6.2, 0.45), cruz, MADERA_OSCURA, Enum.Material.Wood, m)
		lamina("Cruz", Vector3.new(0.4, 0.45, 2.1), cruz * CFrame.new(0, 1.5, 0), MADERA_OSCURA, Enum.Material.Wood, m)
		C.Mapa.mancha(Vector3.new(x2 - 0.13, 6.2, -500), -Vector3.xAxis, 2.2, SANGRE.Gotas, SECA, 0)

		-- Vigas del techo de madera.
		for z = z1 + 2.5, z2 - 2, 4.5 do
			lamina("Viga", Vector3.new(x2 - x1, 0.7, 0.6), CFrame.new((x1 + x2) / 2, techo - 0.45, z), Color3.fromRGB(52, 38, 28), Enum.Material.Wood, m)
		end

		-- Lo abandonado.
		for _, t in {
			{ x1 + 0.4, z1 + 0.4, Vector3.new(1, 0, 1) }, { x1 + 0.4, z2 - 0.4, Vector3.new(1, 0, -1) },
			{ x2 - 0.4, z1 + 0.4, Vector3.new(-1, 0, 1) }, { x2 - 0.4, z2 - 0.4, Vector3.new(-1, 0, -1) },
		} do
			telarana(t[1], techo - 0.8, t[2], t[3], 0.6)
		end
		for _, d in { { x1 + 0.13, 9, -505, Vector3.xAxis }, { x2 - 0.13, 15, -506, -Vector3.xAxis }, { 26, 12, z2 - 0.13, -Vector3.zAxis } } do
			C.Mapa.mancha(Vector3.new(d[1], d[2], d[3]), d[4], 4, SANGRE.Desconchon, Color3.fromRGB(170, 160, 145), d[2] % 3)
		end
		for _, d in { { 33, 14, z1 + 0.13, Vector3.zAxis }, { x1 + 0.13, 14.6, -488.5, Vector3.xAxis }, { x2 - 0.13, 15.2, -488, -Vector3.xAxis } } do
			C.Mapa.mancha(Vector3.new(d[1], d[2], d[3]), d[4], 4, C.Mapa.SANGRE[1], HUMEDAD, d[1] % 3)
		end
		-- Libros de cantos y hojas por el suelo, entre los bancos y en los pasillos de los lados.
		for _ = 1, 6 do
			local p = Vector3.new(azar:NextNumber(24, 33), F + 0.05, if azar:NextNumber() < 0.5 then -513.1 else -486.9)
			lamina("Libro", Vector3.new(0.7, 0.1, 0.9), CFrame.new(p) * CFrame.Angles(0, azar:NextNumber(0, math.pi), 0),
				Color3.fromRGB(70, 40, 34), Enum.Material.Fabric, m)
		end
		basura(Vector3.new(25, F, -499), 1.5, 6, 0, m)
		basura(Vector3.new(33.5, F, -510), 1.2, 3, 3, m)
	end)
end

---------------------------------------------------------------------------------------------------------------------
-- Cripta: el sarcófago contra la pared del fondo (la llave del cementerio encima), nichos con calaveras en las
-- paredes de los lados y velas apagadas. Sin luz.
local function cripta()
	local e = C.Plano.buscar("Cripta")
	local m = modelo("InteriorCripta")
	local x1, x2, z1, z2 = C.Plano.dentro(e) -- 70.5, 77.5, -518.5, -511.5
	local techo = 1 + e.alto
	forrar(e, m, {
		{ y1 = 1, y2 = techo - 0.02, variante = "ParedSotano" },
	}, "SueloSotano", "ParedSotano")

	C.Mapa.conPadre(m, function()
		-- Sarcófago: peana, caja y la tapa algo corrida (asoma el hueco negro), con una cruz tallada.
		local sx, sz = 75.95, -515
		solido("Peana", Vector3.new(2.9, 0.3, 5.5), CFrame.new(sx, F + 0.15, sz), Color3.fromRGB(80, 77, 72), Enum.Material.Slate, m)
		solido("Sarcofago", Vector3.new(2.4, 2.0, 5.0), CFrame.new(sx, F + 1.3, sz), PIEDRA, Enum.Material.Slate, m)
		local caja = F + 2.3
		lamina("Hueco", Vector3.new(2.0, 0.02, 0.3), CFrame.new(sx, caja + 0.01, sz + 2.35), Color3.fromRGB(8, 8, 8), nil, m)
		local tapa = CFrame.new(sx - 0.1, caja + 0.16, sz - 0.3) * CFrame.Angles(0, math.rad(-4), 0)
		solido("Tapa", Vector3.new(2.7, 0.32, 5.1), tapa, Color3.fromRGB(112, 108, 100), Enum.Material.Slate, m)
		lamina("Cruz", Vector3.new(0.3, 0.08, 2.2), tapa * CFrame.new(0, 0.2, -1.1), Color3.fromRGB(96, 92, 86), Enum.Material.Slate, m)
		lamina("Cruz", Vector3.new(1.3, 0.08, 0.3), tapa * CFrame.new(0, 0.2, -1.6), Color3.fromRGB(96, 92, 86), Enum.Material.Slate, m)
		-- La llave, en la tapa, en la punta de la sala (encima de la tapa a caja + 0,32).
		C.llave("Cementerio", Vector3.new(sx - 0.2, caja + 0.52, sz + 0.9))
		C.Mapa.mancha(Vector3.new(sx - 1.22, F + 1.4, sz + 1.2), -Vector3.xAxis, 1.5, SANGRE.Gotas, SECA, 0) -- mano que resbaló
		C.Mapa.mancha(Vector3.new(73.6, F + 0.02, sz + 1.5), Vector3.yAxis, 1.5, C.Mapa.SANGRE[3], Color3.fromRGB(60, 12, 10), 1.2)

		-- Nichos en las paredes norte y sur: dos filas de tres, con tapas rotas, calaveras y huesos.
		for _, lado in { -1, 1 } do
			local zp = if lado < 0 then z1 else z2
			local dentro = -lado -- hacia la sala
			-- Un punto a `d` de la pared (hacia la sala).
			local function en(x: number, y: number, d: number): CFrame
				return CFrame.new(x, y, zp + dentro * d)
			end
			local GRIS = Color3.fromRGB(96, 92, 86)
			for fila = 0, 1 do
				local y = F + 1.6 + fila * 2.4
				for col = 0, 2 do
					local x = 71.7 + col * 2
					lamina("Nicho", Vector3.new(1.6, 1.2, 0.04), en(x, y, 0.13), Color3.fromRGB(10, 9, 8), nil, m)
					-- Repisa de abajo (honda: ahí se apoya lo de dentro), dintel y jambas.
					lamina("Repisa", Vector3.new(1.9, 0.2, 0.7), en(x, y - 0.7, 0.47), GRIS, Enum.Material.Slate, m)
					lamina("Dintel", Vector3.new(1.9, 0.2, 0.3), en(x, y + 0.7, 0.27), GRIS, Enum.Material.Slate, m)
					for _, s in { -1, 1 } do
						lamina("Jamba", Vector3.new(0.15, 1.2, 0.26), en(x + s * 0.88, y, 0.25), GRIS, Enum.Material.Slate, m)
					end
					local k = (fila * 3 + col + (if lado < 0 then 0 else 2)) % 4
					if k == 0 then
						lamina("Lapida", Vector3.new(1.5, 1.1, 0.12), en(x, y, 0.22), Color3.fromRGB(120, 116, 108), Enum.Material.Slate, m)
					elseif k == 1 then
						local craneo = lamina("Craneo", Vector3.new(0.55, 0.5, 0.6), en(x + 0.2, y - 0.35, 0.5), HUESO, Enum.Material.Plaster, m)
						craneo.Shape = Enum.PartType.Ball
						-- Las cuencas de los ojos, mirando a la sala.
						for _, ox in { -0.11, 0.11 } do
							lamina("Cuenca", Vector3.new(0.11, 0.11, 0.11), en(x + 0.2 + ox, y - 0.3, 0.69), Color3.fromRGB(34, 26, 20), nil, m).Shape =
								Enum.PartType.Ball
						end
						lamina("Hueso", Vector3.new(0.12, 0.12, 0.9), en(x - 0.35, y - 0.54, 0.45) * CFrame.Angles(0, 1.2, 0), HUESO,
							Enum.Material.Plaster, m)
					elseif k == 2 then
						-- Tapa rota: medio trozo y el resto en el suelo.
						lamina("Lapida", Vector3.new(0.7, 1.1, 0.12), en(x - 0.4, y, 0.22) * CFrame.Angles(0, 0, 0.12),
							Color3.fromRGB(120, 116, 108), Enum.Material.Slate, m)
						lamina("Trozo", Vector3.new(0.8, 0.12, 0.6), CFrame.new(x + 0.3, F + 0.06, zp + dentro * 0.7) * CFrame.Angles(0, 0.7, 0),
							Color3.fromRGB(120, 116, 108), Enum.Material.Slate, m)
					end
				end
			end
		end
		-- Velas apagadas alrededor de la peana y una urna en el rincón.
		for _, v in { { 74.3, -517.9, 0.9 }, { 74.2, -512.2, 0.6 }, { 77.0, -518.0, 0.5 } } do
			vela(Vector3.new(v[1], F, v[2]), v[3], false, m)
		end
		-- Lo abandonado.
		telarana(x2 - 0.3, techo, z1 + 0.3, Vector3.new(-1, 0, 1), 0.35)
		telarana(x1 + 0.3, techo, z2 - 0.3, Vector3.new(1, 0, -1), 0.35)
		basura(Vector3.new(72, F, -512.5), 0.8, 0, 2, m)
	end)
end

---------------------------------------------------------------------------------------------------------------------
-- Caseta del enterrador: el banco de trabajo contra la pared este (la llave y la pista 5), palas y un ataúd a medio
-- hacer de pie contra la pared norte. Sin luz.
local function caseta()
	local e = C.Plano.buscar("CasetaEnterrador")
	local m = modelo("InteriorCaseta")
	local x1, x2, z1, z2 = C.Plano.dentro(e) -- 75.5, 80.5, -483.5, -478.5
	local techo = 1 + e.alto
	forrar(e, m, {
		{ y1 = 1, y2 = techo - 0.02, variante = "ParedCobertizo" },
	}, "TablasDesvan", "TablasDesvan")

	C.Mapa.conPadre(m, function()
		-- Banco de trabajo: cara de arriba a 4,02 (como la mesa de antes; ahí va la pista 5).
		local bx, bz, ancho, largo = 79.4, -481.75, 2, 3.1
		local arriba = 4.02
		solido("Banco", Vector3.new(ancho, 0.2, largo), CFrame.new(bx, arriba - 0.1, bz), Color3.fromRGB(84, 64, 46), Enum.Material.WoodPlanks, m)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				solido("Pata", Vector3.new(0.25, arriba - 0.2 - F, 0.25), CFrame.new(bx + sx * (ancho / 2 - 0.2), (F + arriba - 0.2) / 2,
					bz + sz * (largo / 2 - 0.2)), MADERA_OSCURA, Enum.Material.Wood, m)
			end
		end
		lamina("Balda", Vector3.new(ancho - 0.3, 0.12, largo - 0.3), CFrame.new(bx, F + 0.8, bz), Color3.fromRGB(70, 54, 40), Enum.Material.WoodPlanks, m)
		local cajita = mueble("CajaCartonPH", CFrame.new(bx, F + 0.86, bz - 0.4) * CFrame.Angles(0, math.pi / 2, 0), true)
		if cajita then
			cajita:ScaleTo(0.6)
		end
		C.llave("Cementerio", Vector3.new(79.7, arriba + 0.18, -480.6))
		mueble("LamparaAceitePH", CFrame.new(80.0, arriba, -482.9), true)
		mueble("SerruchoPH", CFrame.new(79.9, arriba + 0.1, -481.7) * CFrame.Angles(0, 0, math.pi / 2), true)
		C.Mapa.mancha(Vector3.new(79.0, arriba + 0.01, -482.6), Vector3.yAxis, 0.9, SANGRE.Gotas, SECA, 0)
		-- Ataúd a medio hacer, de pie y algo inclinado contra la pared norte, junto a la puerta.
		local ataud = CFrame.new(77.3, F, z1 + 1.05) * CFrame.Angles(math.rad(-4), 0, 0)
		local function tabla(tam: Vector3, off: CFrame)
			solido("Ataud", tam, ataud * off, Color3.fromRGB(92, 70, 50), Enum.Material.WoodPlanks, m)
		end
		tabla(Vector3.new(1.9, 5.4, 0.15), CFrame.new(0, 2.75, -0.45)) -- fondo, contra la pared
		for _, s in { -1, 1 } do
			tabla(Vector3.new(0.15, 5.4, 0.9), CFrame.new(s * 0.88, 2.75, 0))
		end
		tabla(Vector3.new(1.9, 0.15, 0.9), CFrame.new(0, 0.1, 0))
		tabla(Vector3.new(1.9, 0.15, 0.9), CFrame.new(0, 5.4, 0))
		lamina("Interior", Vector3.new(1.6, 5.1, 0.04), ataud * CFrame.new(0, 2.75, -0.36), Color3.fromRGB(24, 18, 14), nil, m)
		-- Palas en el rincón del sureste (al lado de la ventana, sin taparla; se apoyan en la pared sur).
		mueble("PalaPH", CFrame.new(80.1, F, z2 - 0.85) * CFrame.Angles(math.rad(9), math.pi, 0), true)
		mueble("PalaPH", CFrame.new(79.7, F, z2 - 1.0) * CFrame.Angles(math.rad(12), math.pi + 0.4, math.rad(-5)), true)
		mueble("PalancaPH", CFrame.new(80.4, F + 0.96, -481) * CFrame.Angles(0, 0, math.pi / 2), true) -- en la balda del banco
		-- Bajo la ventana: un montón de tierra de las fosas.
		for i, t in { { 78.0, 0.55, 0 }, { 77.3, 0.4, 0.5 }, { 78.7, 0.35, -0.4 } } do
			lamina("Tierra", Vector3.new(1.6 - i * 0.2, t[2] * 2, 1.4), CFrame.new(t[1], F, z2 - 0.9) * CFrame.Angles(0, t[3], math.rad(i * 9 - 18)),
				Color3.fromRGB(62, 46, 32), Enum.Material.Mud, m)
		end
		C.objeto("Chatarra", Vector3.new(77.0, F + 0.2, -480.9))
		-- Tierra pisada y lo abandonado.
		for _, t in { { 77.5, -481 }, { 78.8, -479.4 } } do
			C.Mapa.mancha(Vector3.new(t[1], F + 0.02, t[2]), Vector3.yAxis, 2.2, C.Mapa.SANGRE[2], Color3.fromRGB(52, 40, 28), t[1])
		end
		telarana(x2 - 0.3, techo, z1 + 0.3, Vector3.new(-1, 0, 1), 0.3)
		telarana(x1 + 0.3, techo, z2 - 0.3, Vector3.new(1, 0, -1), 0.3)
	end)
end

function PuebloInteriores.construir(ctx)
	C = ctx
	tienda()
	casaAbierta()
	iglesia()
	cripta() -- antes que la caseta: el orden de las llaves del cementerio importa
	caseta()
end

return PuebloInteriores
