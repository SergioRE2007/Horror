-- La fachada de la casa (11.6, pedido por el usuario: "casa victoriana encantada", referencias en
-- docs/referencias/casa-fuera/): tablas viejas con textura, zócalo de piedra, esquineras y franja entre plantas;
-- ventanas con dintel, alféizar, arco arriba y contraventanas (alguna colgando); tejas, canalones torcidos, crestería,
-- hastiales con ventanuco redondo y la torre con tejado de aguja; columnas y balaustradas del porche, farol y
-- mecedora; hiedra, una ventana tapiada, manchas de humedad, buzón torcido y valla caída. Todo es adorno: no choca ni
-- tapa rayos, así que la jugabilidad no cambia. Lo llama Mapa mientras construye la casa.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Fachada = {}

-- Imágenes de tools/texturas/fachada.ps1 (claras: se tiñen con Color3).
local TABLAS = { id = "rbxassetid://90779205383663", color = Color3.fromRGB(92, 84, 76), tam = 5, largo = 12 } -- tablas largas
local TEJAS = { id = "rbxassetid://91640019978622", color = Color3.fromRGB(92, 90, 96), tam = 8 }
local MANCHAS = { "rbxassetid://85700610438600", "rbxassetid://78490976398688", "rbxassetid://76547078941684" }

local COLOR = {
	Moldura = Color3.fromRGB(52, 46, 42), -- dinteles, esquineras, columnas: pintura oscura gastada
	Piedra = Color3.fromRGB(74, 72, 68),
	Hierro = Color3.fromRGB(28, 27, 27),
	Oxido = Color3.fromRGB(56, 46, 40),
	Contra = { Color3.fromRGB(44, 50, 44), Color3.fromRGB(56, 40, 36), Color3.fromRGB(48, 46, 44) },
	Hoja = { Color3.fromRGB(36, 50, 28), Color3.fromRGB(46, 60, 32), Color3.fromRGB(56, 64, 36), Color3.fromRGB(72, 58, 38) },
	Humedad = Color3.fromRGB(30, 34, 24),
}

local casa: Model
local grupo: Model
local azar = Random.new(1888) -- siempre igual: la casa sale idéntica en cada servidor

local function pieza(nombre: string, tamano: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = nombre
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = tamano
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Wood
	-- Lo pequeño (hojas, lamas, pinchos, balaustres) sin sombra: son muchas piezas y pesa en móvil.
	p.CastShadow = math.max(tamano.X, tamano.Y, tamano.Z) > 2.5
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = grupo
	return p
end

-- La cara de `p` que mira más hacia `dir`.
local function caraHacia(p: BasePart, dir: Vector3): Enum.NormalId
	local mejor, cara = -2, Enum.NormalId.Front
	for _, n in Enum.NormalId:GetEnumItems() do
		local d = p.CFrame:VectorToWorldSpace(Vector3.FromNormalId(n)):Dot(dir)
		if d > mejor then
			mejor, cara = d, n
		end
	end
	return cara
end

local function textura(p: BasePart, cara: Enum.NormalId, t)
	local tex = Instance.new("Texture")
	tex.Name = "Fachada"
	tex.Texture = t.id
	tex.Color3 = t.color
	tex.StudsPerTileU = t.largo or t.tam
	tex.StudsPerTileV = t.tam
	tex.Face = cara
	-- Las tablas, a la misma altura en todos los trozos de pared: la V empieza en el borde de arriba de la cara.
	local arriba = p.Position.Y + p.Size.Y / 2
	if cara ~= Enum.NormalId.Top and cara ~= Enum.NormalId.Bottom then
		tex.OffsetStudsV = -(arriba % t.tam)
	end
	tex.Parent = p
end

-- Si el punto está fuera de todo lo que es casa (paredes de fuera que dan al lavadero o al garaje no se visten).
local function alAireLibre(pos: Vector3): boolean
	local C = Config.Casa
	if math.abs(pos.X) < C.MedioX and math.abs(pos.Z) < C.MedioZ then
		return false
	end
	for i = 2, #C.Anexos do -- el primero es la torre: va aparte, que es redonda
		local r = C.Anexos[i]
		if pos.X > r[1] and pos.X < r[2] and pos.Z > r[3] and pos.Z < r[4] then
			return false
		end
	end
	if pos.X > -59.5 and pos.X < -38.5 and pos.Z > 2.5 and pos.Z < 33.5 then -- garaje
		return false
	end
	return Vector2.new(pos.X - 39, pos.Z + 33).Magnitude > 9 -- torre
end

function Fachada.empezar(modelo: Model)
	casa = modelo
	grupo = Instance.new("Model")
	grupo.Name = "Fachada"
	grupo.Parent = casa
end

-- Un trozo de pared de fuera: tablas viejas en la cara de fuera y, si llega al suelo, zócalo de piedra (no debajo del
-- porche, que lo tapa).
function Fachada.pared(p: BasePart, fuera: Vector3)
	local cara = caraHacia(p, fuera)
	local normal = p.CFrame:VectorToWorldSpace(Vector3.FromNormalId(cara))
	local largo = Vector3.new(normal.Z, 0, -normal.X) -- a lo largo de la pared
	local enPieza = p.CFrame:VectorToObjectSpace(largo)
	local ancho = math.abs(enPieza.X) * p.Size.X + math.abs(enPieza.Y) * p.Size.Y + math.abs(enPieza.Z) * p.Size.Z
	local grueso = math.abs(p.CFrame:VectorToObjectSpace(normal):Dot(p.Size))
	local centro = p.Position + normal * (grueso / 2)
	if not alAireLibre(centro + normal) then
		return
	end
	textura(p, cara, TABLAS)
	local abajo = p.Position.Y - p.Size.Y / 2
	local bajoPorche = centro.Z < -33 and centro.X > -31 and centro.X < 28
	if abajo < 1.5 and not bajoPorche then
		local y0, y1 = -0.5, 2.6
		local cf = CFrame.fromMatrix(Vector3.new(centro.X, (y0 + y1) / 2, centro.Z) + normal * 0.3, largo, Vector3.yAxis)
		pieza("Zocalo", Vector3.new(ancho + 0.6, y1 - y0, 0.6), cf, COLOR.Piedra, Enum.Material.Cobblestone)
		pieza("Remate", Vector3.new(ancho + 0.8, 0.3, 0.8), cf * CFrame.new(0, (y1 - y0) / 2 + 0.1, 0), COLOR.Piedra, Enum.Material.Slate)
	end
end

-- Contraventana de `ancho` x `alto` con su borde de la bisagra en `bisagra` (los ejes de la ventana: Y arriba, -Z
-- fuera); se abre hacia `sentido` (1 o -1, en X). `estado`: "bien", "colgando" (solo de la bisagra de arriba: el otro
-- lado cae) o "falta".
local function contraventana(bisagra: CFrame, sentido: number, ancho: number, alto: number, color: Color3, estado: string)
	if estado == "falta" then
		return
	end
	local cf = bisagra
	if estado == "colgando" then
		cf = bisagra * CFrame.new(0, alto / 2, -0.15) * CFrame.Angles(0, 0, -sentido * math.rad(azar:NextNumber(18, 32)))
			* CFrame.new(0, -alto / 2, 0)
	end
	local hoja = cf * CFrame.new(sentido * ancho / 2, 0, 0)
	pieza("Contraventana", Vector3.new(ancho, alto, 0.2), hoja, color, Enum.Material.WoodPlanks)
	-- Lamas pintadas y travesaños en Z.
	for y = -alto / 2 + 0.6, alto / 2 - 0.5, 0.8 do
		pieza("Lama", Vector3.new(ancho - 0.5, 0.12, 0.1), hoja * CFrame.new(0, y, -0.14), color:Lerp(Color3.new(), 0.35))
	end
	pieza("Marco", Vector3.new(ancho, 0.35, 0.12), hoja * CFrame.new(0, alto / 2 - 0.18, -0.15), color)
	pieza("Marco", Vector3.new(ancho, 0.35, 0.12), hoja * CFrame.new(0, -alto / 2 + 0.18, -0.15), color)
end

-- Por fuera de una ventana: dintel con cornisa, alféizar, molduras a los lados, arco en las de arriba y
-- contraventanas si cabe (alguna colgando o que falta); `tapiada`, con tablas clavadas. `mira` = el centro del cristal
-- con -Z hacia fuera. `h.libreIzq`/`h.libreDer` = pared libre a cada lado (en el eje X de `mira`).
function Fachada.ventana(mira: CFrame, h, torre: boolean)
	local w, alto = h.ancho, h.alto
	local fuera = -0.75 -- algo por delante de la cara de la pared (está a 0,5)
	local function aqui(x: number, y: number, z: number): CFrame
		return mira * CFrame.new(x, y, z)
	end
	for _, lado in { -1, 1 } do
		pieza("Moldura", Vector3.new(0.6, alto + 0.6, 0.5), aqui(lado * (w / 2 + 0.55), 0, fuera), COLOR.Moldura)
	end
	pieza("Dintel", Vector3.new(w + 2.2, 0.9, 0.6), aqui(0, alto / 2 + 0.7, fuera), COLOR.Moldura)
	pieza("Cornisa", Vector3.new(w + 2.8, 0.3, 1.0), aqui(0, alto / 2 + 1.3, fuera - 0.15), COLOR.Moldura)
	pieza("Alfeizar", Vector3.new(w + 2, 0.35, 1.1), aqui(0, -alto / 2 - 0.35, fuera - 0.2), COLOR.Moldura)
	-- Las de arriba, con un arco rebajado encima de la cornisa y su piedra clave (como las de las referencias; más alto
	-- tocaría el alero).
	if mira.Position.Y > 14 and not torre then
		local r, n = w / 2 + 0.6, 8
		local flecha, base = r * 0.55, alto / 2 + 1.45
		local puntos = {}
		for i = 0, n do
			local a = math.pi * i / n
			table.insert(puntos, Vector2.new(math.cos(a) * r, math.sin(a) * flecha))
		end
		for i = 1, n do
			local d, medio = puntos[i + 1] - puntos[i], (puntos[i] + puntos[i + 1]) / 2
			pieza("Arco", Vector3.new(d.Magnitude + 0.12, 0.45, 0.5), aqui(medio.X, base + medio.Y, fuera) * CFrame.Angles(0, 0, math.atan2(d.Y, d.X)),
				COLOR.Moldura)
		end
		pieza("Clave", Vector3.new(0.7, 1, 0.7), aqui(0, base + flecha, fuera - 0.05), COLOR.Moldura)
	end
	-- Contraventanas, si hay sitio a los dos lados.
	local ancho = w / 2 + 0.2
	if not torre and (h.libreIzq or 0) > ancho + 1.6 and (h.libreDer or 0) > ancho + 1.6 then
		local color = COLOR.Contra[azar:NextInteger(1, #COLOR.Contra)]
		for _, lado in { -1, 1 } do
			local tirada = azar:NextNumber()
			local estado = if tirada < 0.12 then "falta" elseif tirada < 0.27 then "colgando" else "bien"
			contraventana(aqui(lado * (w / 2 + 0.85), 0, fuera - 0.1), lado, ancho, alto + 0.3, color, estado)
		end
	end
	if h.tapiada then
		for i, t in { { 0.9, 0.08 }, { 0.35, -0.05 }, { -0.25, 0.12 }, { -0.8, -0.1 }, { 0.05, 0.6 } } do
			pieza("Tapiada", Vector3.new(w + 1.6, 0.7, 0.18), aqui(0, t[1] * alto / 2, fuera - 0.4 - i * 0.03) * CFrame.Angles(0, 0, t[2]),
				Color3.fromRGB(96, 80, 62), Enum.Material.WoodPlanks)
		end
	end
end

-- Columna del porche de `y0` a `y1`: basa, fuste y capitel, con dos ménsulas hacia la viga.
function Fachada.columna(x: number, z: number, y0: number, y1: number)
	local alto = y1 - y0
	pieza("Basa", Vector3.new(1.6, 1, 1.6), CFrame.new(x, y0 + 0.5, z), COLOR.Moldura)
	pieza("Fuste", Vector3.new(1, alto - 1.6, 1), CFrame.new(x, y0 + 1 + (alto - 1.6) / 2, z), COLOR.Moldura)
	pieza("Capitel", Vector3.new(1.6, 0.6, 1.6), CFrame.new(x, y1 - 0.3, z), COLOR.Moldura)
	for _, lado in { -1, 1 } do
		pieza("Mensula", Vector3.new(1.8, 0.35, 0.35), CFrame.new(x + lado * 1, y1 - 1.2, z) * CFrame.Angles(0, 0, lado * math.rad(40)),
			COLOR.Moldura)
	end
end

-- Balaustrada de `a` a `b` (a ras del suelo): pasamanos, zócalo y balaustres; con `rota`, faltan algunos y el
-- pasamanos se parte en un tramo.
function Fachada.balaustrada(a: Vector3, b: Vector3, alto: number, rota: boolean)
	local largo = (b - a).Magnitude
	local cf = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0) -- X a lo largo
	local roto = if rota then azar:NextNumber(0.2, 0.8) else -1
	local hueco = 2.5
	for _, tramo in (if rota then { { -0.5, roto - 0.5 - hueco / largo / 2 }, { roto - 0.5 + hueco / largo / 2, 0.5 } } else { { -0.5, 0.5 } }) do
		local l = (tramo[2] - tramo[1]) * largo
		local x = (tramo[1] + tramo[2]) / 2 * largo
		if l > 0.3 then
			pieza("Pasamanos", Vector3.new(l, 0.35, 0.6), cf * CFrame.new(x, alto - 0.18, 0), COLOR.Moldura)
		end
	end
	pieza("Zocalo", Vector3.new(largo, 0.35, 0.5), cf * CFrame.new(0, 0.5, 0), COLOR.Moldura)
	for x = -largo / 2 + 0.6, largo / 2 - 0.5, 0.9 do
		local t = x / largo + 0.5
		local cerca = rota and math.abs(t - roto) * largo < hueco / 2 + 0.6
		if not (cerca or (rota and azar:NextNumber() < 0.12)) then
			pieza("Balaustre", Vector3.new(0.28, alto - 1, 0.28), cf * CFrame.new(x, (alto - 1) / 2 + 0.68, 0), COLOR.Moldura)
		end
	end
	-- Un balaustre caído en el suelo, junto al tramo roto.
	if rota then
		pieza("Balaustre", Vector3.new(0.28, alto - 1, 0.28), cf * CFrame.new((roto - 0.5) * largo, 0.15, -1.2) * CFrame.Angles(0, 0.4, math.pi / 2),
			COLOR.Moldura)
	end
end

-- Triángulo con dos cuñas (el tejado de la torre).
local function triangulo(a: Vector3, b: Vector3, c: Vector3, color: Color3)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local derecha = ac:Cross(ab).Unit
	local arriba = bc:Cross(derecha).Unit
	local atras = bc.Unit
	local altura = math.abs(ab:Dot(arriba))
	for i, d in { { ab, (a + b) / 2, 1 }, { ac, (a + c) / 2, -1 } } do
		local cuna = Instance.new("WedgePart")
		cuna.Name = "Aguja" .. i
		cuna.Anchored = true
		cuna.CanCollide = false
		cuna.CanQuery = false
		cuna.CanTouch = false
		cuna.Size = Vector3.new(0.4, altura, math.abs(d[1]:Dot(atras)))
		cuna.CFrame = CFrame.fromMatrix(d[2], derecha * d[3], arriba, atras * d[3])
		cuna.Color = color
		cuna.Material = Enum.Material.Slate
		cuna.Parent = grupo
	end
end

-- Pincho de hierro con bola (crestería y remates).
local function pincho(pos: Vector3, alto: number, bola: boolean)
	pieza("Pincho", Vector3.new(0.14, alto, 0.14), CFrame.new(pos + Vector3.new(0, alto / 2, 0)), COLOR.Hierro, Enum.Material.Metal)
	if bola then
		local b = pieza("Bola", Vector3.new(0.4, 0.4, 0.4), CFrame.new(pos + Vector3.new(0, alto * 0.7, 0)), COLOR.Hierro, Enum.Material.Metal)
		b.Shape = Enum.PartType.Ball
	end
end

local function tubo(desde: Vector3, hasta: Vector3, grueso: number)
	local t = pieza("Canalon", Vector3.new((hasta - desde).Magnitude, grueso, grueso),
		CFrame.lookAt((desde + hasta) / 2, hasta) * CFrame.Angles(0, math.pi / 2, 0), COLOR.Oxido, Enum.Material.Metal)
	t.Shape = Enum.PartType.Cylinder
	return t
end

-- Mancha de humedad o de moho en una pared de fuera (`normal` = hacia fuera).
local function humedad(pos: Vector3, normal: Vector3, tam: number)
	local p = pieza("Humedad", Vector3.new(tam, tam * 1.4, 0.04), CFrame.lookAt(pos, pos + normal) * CFrame.Angles(0, 0, math.pi),
		COLOR.Humedad)
	p.Transparency = 1
	p.CastShadow = false
	local d = Instance.new("Decal")
	d.Texture = MANCHAS[azar:NextInteger(1, #MANCHAS)]
	d.Color3 = COLOR.Humedad
	d.Transparency = 0.35
	d.Face = Enum.NormalId.Front
	d.Parent = p
end

-- Hiedra que sube por una esquina y se abre por las dos paredes: hojas sueltas pegadas a la pared.
-- `paredes`: { normal (hacia fuera), hacia (a lo largo de la pared, alejándose de la esquina) }.
local function hiedra(esquina: Vector3, paredes: { { Vector3 } }, alto: number)
	for _, pared in paredes do
		local normal, hacia = pared[1], pared[2]
		for _ = 1, 140 do
			local y = azar:NextNumber(0, 1) ^ 0.7 * alto
			local abre = azar:NextNumber(0, 1) ^ 2 * (2 + (alto - y) * 0.35)
			-- Con volumen: unas más separadas de la pared que otras y medio levantadas (abajo, por delante del zócalo).
			local separada = (if y < 2.9 then 1.0 else 0.62) + azar:NextNumber(0, 0.7)
			local pos = esquina + normal * separada + hacia * abre + Vector3.new(0, y, 0)
			local tam = azar:NextNumber(0.8, 1.4)
			pieza("Hiedra", Vector3.new(tam, tam * 0.8, 0.08), CFrame.lookAt(pos, pos + normal) * CFrame.Angles(0, 0, azar:NextNumber(0, math.pi * 2))
				* CFrame.Angles(math.rad(azar:NextNumber(20, 60)), 0, 0), COLOR.Hoja[azar:NextInteger(1, #COLOR.Hoja)], Enum.Material.LeafyGrass)
		end
		-- Los tallos.
		for i = 0, 2 do
			local x = 0.3 + i * 0.9
			pieza("Tallo", Vector3.new(0.15, alto * (1 - i * 0.25), 0.15),
				CFrame.new(esquina + normal * 0.6 + hacia * x + Vector3.new(0, alto * (1 - i * 0.25) / 2, 0)) * CFrame.Angles(0, 0, (i - 1) * 0.06),
				Color3.fromRGB(58, 46, 34))
		end
	end
end

-- Esquinera: dos tablas en L tapando la esquina de fuera (`sx`, `sz` = hacia dónde queda fuera).
local function esquinera(x: number, z: number, sx: number, sz: number, y0: number, y1: number)
	local alto, y = y1 - y0, (y0 + y1) / 2
	pieza("Esquinera", Vector3.new(0.3, alto, 1.4), CFrame.new(x + sx * 0.65, y, z + sz * 0.1), COLOR.Moldura)
	pieza("Esquinera", Vector3.new(1.4, alto, 0.3), CFrame.new(x - sx * 0.2, y, z + sz * 0.65), COLOR.Moldura)
end

-- Tejado de chapa ondulada y oxidada (garaje y cobertizo): nervios a lo largo de z encima de `techo`.
function Fachada.chapa(techo: BasePart)
	techo.Color = COLOR.Oxido
	techo.Material = Enum.Material.Metal -- CorrodedMetal sale naranja chillón aunque se oscurezca
	local arriba = techo.Position.Y + techo.Size.Y / 2
	for x = techo.Position.X - techo.Size.X / 2 + 0.6, techo.Position.X + techo.Size.X / 2 - 0.4, 1.2 do
		pieza("Nervio", Vector3.new(0.3, 0.2, techo.Size.Z), CFrame.new(x, arriba + 0.1, techo.Position.Z), COLOR.Oxido, Enum.Material.Metal)
	end
end

-- Lo que no va pegado a una pared ni a una ventana. `m`: medidas de Mapa (ABAJO, ARRIBA, ALTO, TEJADO, TORRE).
function Fachada.vestir(m)
	-- Tejado: tejas, tabla del alero con el canalón torcido, bajantes, tablas de los hastiales y crestería en la cumbre.
	local inclinacion = math.atan(m.TEJADO.pendiente)
	local largoFaldon = m.TEJADO.alero / math.cos(inclinacion)
	for _, t in casa:GetChildren() do
		if t:IsA("BasePart") and t.Name == "Tejado" then
			textura(t, Enum.NormalId.Top, TEJAS)
			local lado = if t.Position.Z > 0 then 1 else -1
			local borde = t.CFrame * CFrame.new(0, -0.3, lado * largoFaldon / 2)
			-- Delante, hasta la torre (más allá se metería en su cuarto de arriba).
			local x0, x1 = -41.2, if lado > 0 then 41.2 else 29.5
			local alero = Vector3.new((x0 + x1) / 2, borde.Position.Y - 0.3, borde.Position.Z + lado * 0.2)
			pieza("Alero", Vector3.new(x1 - x0, 1.2, 0.3), CFrame.new(alero), COLOR.Moldura)
			-- Canalón en tres trozos: recto, combado y el último suelto, colgando.
			local y, z = alero.Y - 0.4, alero.Z + lado * 0.5
			tubo(Vector3.new(x0, y, z), Vector3.new(-6, y, z), 0.6)
			tubo(Vector3.new(-6, y, z), Vector3.new(16, y - 0.7, z), 0.6)
			tubo(Vector3.new(16, y - 0.7, z), Vector3.new(22, y - 3.5, z + lado * 0.8), 0.6) -- y luego falta un trozo
			-- Bajantes en las esquinas (delante, solo en la del comedor: en la otra está la torre); el de detrás, partido.
			for _, x in (if lado > 0 then { -40.2, 40.2 } else { -40.2 }) do
				local roto = x > 0
				tubo(Vector3.new(x, y, z), Vector3.new(x, if roto then 12 else 0.4, z), 0.5)
				if roto then
					tubo(Vector3.new(x, 6, z), Vector3.new(x, 0.4, z), 0.5)
					tubo(Vector3.new(x + 0.8, 0.3, z + 0.8), Vector3.new(x - 1.6, 0.3, z + 2.4), 0.5) -- el trozo caído
				end
			end
			for _, x in { -1, 1 } do
				pieza("Hastial", Vector3.new(0.3, 1.4, largoFaldon + 0.2), t.CFrame * CFrame.new(x * (t.Size.X / 2 + 0.15), -0.4, 0), COLOR.Moldura)
			end
		end
	end
	local cumbre = 27 + m.TEJADO.pendiente * m.TEJADO.alero + 0.5 / math.cos(inclinacion)
	pieza("Cumbrera", Vector3.new(82.6, 0.5, 1.6), CFrame.new(0, cumbre, 0), COLOR.Hierro, Enum.Material.Slate)
	pieza("Cresteria", Vector3.new(80, 0.14, 0.14), CFrame.new(0, cumbre + 1.3, 0), COLOR.Hierro, Enum.Material.Metal)
	for i = 0, 50 do
		pincho(Vector3.new(-40 + i * 1.6, cumbre + 0.25, 0), 1.7, i % 4 == 0)
	end
	for _, x in { -41.3, 41.3 } do
		pincho(Vector3.new(x, cumbre - 0.5, 0), 4.5, true)
	end

	-- Hastiales: tablas por las dos caras (dentro es el desván, sin papel) y un ventanuco redondo.
	for _, h in casa:GetChildren() do
		if h:IsA("WedgePart") and h.Name == "Hastial" then
			h.Color = Color3.fromRGB(110, 100, 90)
			textura(h, Enum.NormalId.Left, TABLAS)
			textura(h, Enum.NormalId.Right, TABLAS)
		end
	end
	local alto = m.TEJADO.pendiente * 33.5
	for _, x in { -1, 1 } do
		local c = Vector3.new(x * 39.75, 27 + alto * 0.36, 0)
		local marco = pieza("Ventanuco", Vector3.new(0.5, 4.8, 4.8), CFrame.new(c), COLOR.Moldura)
		marco.Shape = Enum.PartType.Cylinder
		local cristal = pieza("Ventanuco", Vector3.new(0.56, 3.6, 3.6), CFrame.new(c), Color3.fromRGB(30, 34, 36), Enum.Material.Glass)
		cristal.Shape = Enum.PartType.Cylinder
		cristal.Reflectance = 0.15
		pieza("Cruz", Vector3.new(0.62, 3.6, 0.25), CFrame.new(c), COLOR.Moldura)
		pieza("Cruz", Vector3.new(0.62, 0.25, 3.6), CFrame.new(c), COLOR.Moldura)
	end

	-- Chimenea: remate de ladrillo alrededor de la boca (abierta: por ahí baja el Trepador).
	local chimenea = casa:FindFirstChild("Chimenea")
	local tiro = chimenea and chimenea:FindFirstChild("Tiro") :: BasePart?
	if tiro then
		local top = tiro.Position + Vector3.new(0, tiro.Size.Y / 2 - 0.4, 0)
		for _, s in { -1, 1 } do
			pieza("Remate", Vector3.new(0.7, 0.8, tiro.Size.Z + 1.4), CFrame.new(top + Vector3.new(s * (tiro.Size.X / 2 + 0.05), 0, 0)), tiro.Color,
				Enum.Material.Brick)
			pieza("Remate", Vector3.new(tiro.Size.X + 0.1, 0.8, 0.7), CFrame.new(top + Vector3.new(0, 0, s * (tiro.Size.Z / 2 + 0.05))), tiro.Color,
				Enum.Material.Brick)
		end
	end

	-- Torre: tejado de aguja de ocho caras, con su alero, y un remate de hierro arriba.
	local T = m.TORRE
	local radio = (T.apotema + 1.4) / math.cos(math.pi / 8)
	local base = m.ARRIBA + m.ALTO + 1
	local punta = Vector3.new(T.x, base + 21, T.z)
	for k = 0, 7 do
		local a0, a1 = (k - 0.5) * math.pi / 4, (k + 0.5) * math.pi / 4
		local p0 = Vector3.new(T.x + radio * math.cos(a0), base, T.z + radio * math.sin(a0))
		local p1 = Vector3.new(T.x + radio * math.cos(a1), base, T.z + radio * math.sin(a1))
		triangulo(p0, p1, punta, Color3.fromRGB(50, 48, 52))
		pieza("Alero", Vector3.new((p1 - p0).Magnitude + 0.3, 1, 0.3), CFrame.lookAt((p0 + p1) / 2 - Vector3.new(0, 0.6, 0), (p0 + p1) / 2 + (p1 - p0)) *
			CFrame.Angles(0, math.pi / 2, 0), COLOR.Moldura)
	end
	pincho(punta - Vector3.new(0, 0.5, 0), 5, true)
	-- Esquineras en las aristas de fuera de la torre (tapan la rendija entre caras).
	local ra = (T.apotema + 0.5) / math.cos(math.pi / 8)
	for _, k in { 4, 5, 6, 7, 0, 1 } do
		local a = (k + 0.5) * math.pi / 4
		local p = Vector3.new(T.x + ra * math.cos(a), 13.5, T.z + ra * math.sin(a)) -- del suelo al alero
		pieza("Esquinera", Vector3.new(1.1, 27, 0.5), CFrame.lookAt(p, p + Vector3.new(math.cos(a), 0, math.sin(a))), COLOR.Moldura)
	end
	-- Franja entre plantas de la torre, en sus caras de fuera (las mismas que en Mapa.construirTorre).
	local rf = (T.apotema + 0.7) / math.cos(math.pi / 8)
	for _, c in { { 4, 0.5, 1 }, { 5, 0, 1 }, { 6, 0, 1 }, { 7, 0, 1 }, { 0, 0, 1 }, { 1, 0, 1 }, { 2, 0, 0.5 } } do
		local a0, a1 = (c[1] - 0.5) * math.pi / 4, (c[1] + 0.5) * math.pi / 4
		local v0 = Vector3.new(T.x + rf * math.cos(a0), 13.6, T.z + rf * math.sin(a0))
		local v1 = Vector3.new(T.x + rf * math.cos(a1), 13.6, T.z + rf * math.sin(a1))
		local p0, p1 = v0:Lerp(v1, c[2]), v0:Lerp(v1, c[3])
		pieza("Franja", Vector3.new((p1 - p0).Magnitude + 0.3, 1.6, 0.4),
			CFrame.lookAt((p0 + p1) / 2, (p0 + p1) / 2 + (p1 - p0)) * CFrame.Angles(0, math.pi / 2, 0), COLOR.Moldura)
	end

	-- Franja entre las dos plantas y esquineras de la casa y de los anexos.
	for _, f in { { -39.8, 31, -33.7, -33.7 }, { -39.8, 39.8, 33.7, 33.7 }, { -39.7, -39.7, -33.8, 33.8 }, { 39.7, 39.7, -25, 33.8 } } do
		local tam = Vector3.new(math.max(f[2] - f[1], 0.4), 1.6, math.max(f[4] - f[3], 0.4))
		pieza("Franja", tam, CFrame.new((f[1] + f[2]) / 2, 13.6, (f[3] + f[4]) / 2), COLOR.Moldura)
	end
	for _, e in {
		{ -39, -33, -1, -1, 27 }, { -39, 33, -1, 1, 27 }, { 39, 33, 1, 1, 27 }, -- casa
		{ -43, -17, -1, -1, 14 }, { -43, -3, -1, 1, 14 }, -- mirador
		{ -26, 45, -1, 1, 14 }, { -12, 45, 1, 1, 14 }, -- lavadero
		{ -59, 3, -1, -1, 14 }, { -59, 33, -1, 1, 14 }, -- garaje
	} do
		esquinera(e[1], e[2], e[3], e[4], 0, e[5])
	end

	-- Porche: viga con su tabla de alero y balaustrada rota solo en los costados (no choca; por delante, abierto: los
	-- bichos llegan a las ventanas por ahí y se sube por cualquier sitio, como antes).
	pieza("Viga", Vector3.new(58.4, 1.2, 0.6), CFrame.new(-1.5, m.ABAJO + m.ALTO - 0.6, -40.6), COLOR.Moldura)
	pieza("Alero", Vector3.new(58.6, 1.3, 0.3), CFrame.new(-1.5, 13.35, -41.65), COLOR.Moldura)
	for _, x in { 26.4, -29.4 } do
		Fachada.balaustrada(Vector3.new(x, m.ABAJO, -39.8), Vector3.new(x, m.ABAJO, -34.2), 3.2, true)
	end
	-- Farol apagado junto a la puerta.
	local farol = CFrame.new(4.6, m.ABAJO + 7.2, -34.3)
	pieza("Brazo", Vector3.new(0.2, 0.2, 1.4), farol * CFrame.new(0, 1.1, 0.5), COLOR.Hierro, Enum.Material.Metal)
	pieza("Farol", Vector3.new(0.9, 1.2, 0.9), farol, Color3.fromRGB(70, 64, 48), Enum.Material.Glass).Transparency = 0.2
	pieza("Tapa", Vector3.new(1.2, 0.3, 1.2), farol * CFrame.new(0, 0.75, 0), COLOR.Hierro, Enum.Material.Metal)
	pieza("Base", Vector3.new(1, 0.2, 1), farol * CFrame.new(0, -0.7, 0), COLOR.Hierro, Enum.Material.Metal)
	-- Mecedora mirando al camino.
	local silla = CFrame.new(9, m.ABAJO, -37.5) * CFrame.Angles(0, math.rad(200), 0)
	pieza("Asiento", Vector3.new(2, 0.25, 2), silla * CFrame.new(0, 1.6, 0), Color3.fromRGB(48, 38, 30))
	pieza("Respaldo", Vector3.new(2, 2.8, 0.25), silla * CFrame.new(0, 3, 1.05) * CFrame.Angles(math.rad(-12), 0, 0), Color3.fromRGB(48, 38, 30))
	for _, x in { -0.95, 0.95 } do
		pieza("Brazo", Vector3.new(0.2, 0.2, 2), silla * CFrame.new(x, 2.6, 0), Color3.fromRGB(42, 33, 26))
		for _, z in { -0.8, 0.8 } do
			pieza("Pata", Vector3.new(0.2, 1.4, 0.2), silla * CFrame.new(x, 0.9, z), Color3.fromRGB(42, 33, 26))
		end
		for i = -1, 1 do -- el balancín, en tres trozos curvados
			pieza("Balancin", Vector3.new(0.2, 0.2, 1.3), silla * CFrame.new(x, 0.18 + math.abs(i) * 0.12, i * 1.1) * CFrame.Angles(i * 0.22, 0, 0),
				Color3.fromRGB(42, 33, 26))
		end
	end

	-- Abandono: hiedra por la esquina del comedor, manchas de humedad bajo el alero y junto al suelo.
	hiedra(Vector3.new(-39.5, 0, -33.5), { { -Vector3.zAxis, Vector3.xAxis }, { -Vector3.xAxis, Vector3.zAxis } }, 22)
	for _, h in {
		{ -36, 23, -33.6, -Vector3.zAxis, 4 }, { -12, 24, 33.6, Vector3.zAxis, 5 }, { 34, 22.5, 33.6, Vector3.zAxis, 4 },
		{ 39.6, 23, 10, Vector3.xAxis, 5 }, { -39.6, 24, 3, -Vector3.xAxis, 4 }, { -59.6, 2.5, 25, -Vector3.xAxis, 3 },
		{ 18, 2.6, 33.6, Vector3.zAxis, 3 }, { 39.6, 2.4, 22, Vector3.xAxis, 3 },
	} do
		humedad(Vector3.new(h[1], h[2], h[3]), h[4], h[5])
	end
	-- Buzón torcido junto al camino y un trozo de valla caída.
	local buzon = CFrame.new(8, 0, -62) * CFrame.Angles(math.rad(8), math.rad(15), math.rad(-11))
	pieza("Poste", Vector3.new(0.4, 3.6, 0.4), buzon * CFrame.new(0, 1.8, 0), Color3.fromRGB(70, 58, 46))
	pieza("Buzon", Vector3.new(1.1, 1.1, 2), buzon * CFrame.new(0, 3.9, 0), Color3.fromRGB(52, 54, 52), Enum.Material.CorrodedMetal)
	pieza("Bandera", Vector3.new(0.08, 0.9, 0.3), buzon * CFrame.new(0.6, 4.1, 0.5) * CFrame.Angles(math.rad(70), 0, 0), Color3.fromRGB(96, 34, 30),
		Enum.Material.Metal)
	for v, valla in { { CFrame.new(-15, 0.15, -57) * CFrame.Angles(math.pi / 2 - 0.05, math.rad(20), 0), 7 },
		{ CFrame.new(-21.5, 0, -55.5) * CFrame.Angles(math.rad(-14), math.rad(25), math.rad(4)), 5 } } do
		local cf, n = valla[1], valla[2]
		for i = 0, n - 1 do
			if not (v == 1 and i == 3) then
				pieza("Estaca", Vector3.new(0.5, 3.4, 0.15), cf * CFrame.new((i - (n - 1) / 2) * 0.9, 1.7, 0), Color3.fromRGB(72, 68, 62))
			end
		end
		for _, y in { 0.9, 2.5 } do
			pieza("Travesano", Vector3.new(n * 0.9, 0.3, 0.15), cf * CFrame.new(0, y, 0.15), Color3.fromRGB(62, 58, 54))
		end
	end

end

return Fachada
