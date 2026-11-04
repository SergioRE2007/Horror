-- El cascarón y la fachada de cada edificio del pueblo (11.5, pedido por el usuario: "que las casas, las fachadas
-- estén bien"; plano en PuebloPlano). Por edificio: suelo (sale en el mapa del móvil), paredes que chocan (con hueco de
-- puerta y ventanas con cristal en los que se entra), techo plano por dentro y tejado a dos aguas, a cuatro o plano
-- con fachada falsa (la tienda). Por fuera: tablas teñidas, ladrillo o piedra; molduras, contraventanas (alguna
-- colgando o que falta), porches, chimeneas, aleros y canalones torcidos, franja entre plantas, hiedra, humedad,
-- tablas rotas y algo de sangre seca discreta. Los que no se entra, con la puerta tapiada y ventanas de mentira. La
-- iglesia, con contrafuertes, vidrieras oscuras rotas, rosetón y su campanario con campana, aguja y cruz; la cripta,
-- con frontón y reja. Lo que no es pared, suelo, techo o tejado es adorno: no choca ni estorba.
local CollectionService = game:GetService("CollectionService")

local PuebloPlano = require(script.Parent.PuebloPlano)

local PuebloFachadas = {}

-- Imágenes de tools/texturas/fachada.ps1 (claras: se tiñen con Color3) y manchas de tools/texturas/sangre.ps1.
local TABLAS = { id = "rbxassetid://90779205383663", tam = 5, largo = 12 }
local TEJAS = { id = "rbxassetid://91640019978622", tam = 8 }
local MANCHAS = { "rbxassetid://85700610438600", "rbxassetid://78490976398688", "rbxassetid://76547078941684" }

local COLOR = {
	Moldura = Color3.fromRGB(52, 46, 42),
	Piedra = Color3.fromRGB(64, 63, 60),
	PiedraClara = Color3.fromRGB(98, 96, 90),
	PiedraOscura = Color3.fromRGB(58, 57, 55),
	Hierro = Color3.fromRGB(28, 27, 27),
	Oxido = Color3.fromRGB(56, 46, 40),
	Teja = Color3.fromRGB(46, 45, 48),
	TintaTeja = Color3.fromRGB(88, 86, 92),
	Cristal = Color3.fromRGB(24, 28, 30),
	Negro = Color3.fromRGB(9, 9, 10),
	Tabla = Color3.fromRGB(92, 78, 62),
	Puerta = Color3.fromRGB(58, 46, 38),
	Techo = Color3.fromRGB(62, 54, 46),
	Suelo = Color3.fromRGB(66, 56, 46),
	Chimenea = Color3.fromRGB(78, 46, 40),
	Humedad = Color3.fromRGB(30, 34, 24),
	Sangre = Color3.fromRGB(60, 15, 13), -- seca, casi marrón
	Contra = { Color3.fromRGB(44, 50, 44), Color3.fromRGB(56, 40, 36), Color3.fromRGB(48, 46, 44), Color3.fromRGB(40, 44, 54) },
	Hoja = { Color3.fromRGB(36, 50, 28), Color3.fromRGB(46, 60, 32), Color3.fromRGB(56, 64, 36), Color3.fromRGB(72, 58, 38) },
	Vidriera = { Color3.fromRGB(46, 14, 16), Color3.fromRGB(16, 20, 44), Color3.fromRGB(16, 34, 22), Color3.fromRGB(52, 40, 16),
		Color3.fromRGB(32, 16, 38) },
}

-- Cada casa distinta. `color`: el de las tablas (madera) o del ladrillo y la piedra. `tejado`: "dos" (a dos aguas, la
-- cumbrera a lo largo de `eje`), "cuatro" o "plano". `hiedra`: la esquina por la que sube ("SE" = sur y este...).
local ESTILO = {
	CasaCerrada1 = { color = Color3.fromRGB(92, 104, 92), tejado = "dos", eje = "z", pendiente = 0.8, porche = true, chimenea = true,
		hiedra = "SE" },
	Tienda = { color = Color3.fromRGB(64, 36, 30), tejado = "plano" },
	CasaCerrada2 = { color = Color3.fromRGB(106, 62, 54), tejado = "cuatro", pendiente = 0.7, chimenea = true, hiedra = "NE" },
	CasaCerrada3 = { color = Color3.fromRGB(78, 88, 102), tejado = "dos", eje = "x", pendiente = 0.85, porche = true },
	CasaCerrada4 = { color = Color3.fromRGB(116, 100, 68), tejado = "cuatro", pendiente = 0.75, porche = true, chimenea = true },
	CasaAbierta = { color = Color3.fromRGB(136, 130, 118), tejado = "dos", eje = "z", pendiente = 0.7, porche = true, chimenea = true },
	CasaCerrada5 = { color = Color3.fromRGB(56, 38, 34), tejado = "dos", eje = "x", pendiente = 0.8, chimenea = true },
	Iglesia = { color = Color3.fromRGB(64, 63, 60), tejado = "dos", eje = "z", pendiente = 1.15, alero = 1, hiedra = "SE" },
	Cripta = { color = Color3.fromRGB(70, 70, 68), tejado = "dos", eje = "x", pendiente = 0.45, alero = 0.5, vuelo = 0.5, sinTejas = true,
		sinCanalon = true, moldura = COLOR.PiedraClara, hiedra = "NE" },
	CasetaEnterrador = { color = Color3.fromRGB(80, 68, 56), tejado = "dos", eje = "z", pendiente = 0.6, alero = 0.8, vuelo = 0.5 },
	CasaFinal = { color = Color3.fromRGB(86, 80, 94), tejado = "dos", eje = "x", pendiente = 0.75, porche = true, chimenea = true,
		hiedra = "NO" },
}

local ctx
local grupo: Instance -- el modelo del edificio que se está haciendo
local azar = Random.new(1)

-- Adorno: no choca, ni tapa rayos ni toca. Lo pequeño, sin sombra (son muchas piezas y pesa en móvil).
local function adorno(nombre: string, tamano: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
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
	p.CastShadow = math.max(tamano.X, tamano.Y, tamano.Z) > 2.5
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = grupo
	return p
end

-- Lo que choca: paredes, suelos, techos, tejados, escalones.
local function solido(nombre: string, tamano: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = ctx.bloque(nombre, tamano, cf, color, material or Enum.Material.WoodPlanks, grupo)
	if nombre == "Escalon" then
		p:SetAttribute("SinSeparar", true) -- apoyado en y = 0: que Separar.caras no lo ensanche
	end
	return p
end

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

local function textura(p: BasePart, cara: Enum.NormalId, t, color: Color3)
	local tex = Instance.new("Texture")
	tex.Name = "Fachada"
	tex.Texture = t.id
	tex.Color3 = color
	tex.StudsPerTileU = t.largo or t.tam
	tex.StudsPerTileV = t.tam
	tex.Face = cara
	-- Las tablas, a la misma altura en todos los trozos de pared: la V empieza en el borde de arriba de la cara.
	if cara ~= Enum.NormalId.Top and cara ~= Enum.NormalId.Bottom then
		tex.OffsetStudsV = -((p.Position.Y + p.Size.Y / 2) % t.tam)
	end
	tex.Parent = p
end

-- Plancha rectangular con la cara de abajo en el rectángulo de esquina `P` y lados `a` (a lo largo; la textura de tejas
-- va en esa dirección) y `b` (perpendicular a `a`); sale hacia arriba `t` de grueso.
local function plano(nombre: string, P: Vector3, a: Vector3, b: Vector3, t: number, color: Color3, material: Enum.Material, tex, tinta: Color3?,
	choca: boolean?): Part
	local n = a:Cross(b).Unit
	if n.Y < 0 then
		n = -n
	end
	local cf = CFrame.fromMatrix(P + a / 2 + b / 2 + n * t / 2, a.Unit, n)
	local tam = Vector3.new(a.Magnitude, t, b.Magnitude)
	local p = if choca then solido(nombre, tam, cf, color, material) else adorno(nombre, tam, cf, color, material)
	p.CastShadow = true
	if tex then
		textura(p, Enum.NormalId.Top, tex, tinta or color)
	end
	return p
end

-- Triángulo rectángulo (una cuña) con el ángulo recto en `M` y los catetos `e` (la textura va a lo largo) y `s`; sale
-- `t` de grueso hacia `n` (si no se da, hacia arriba).
local function triangulo(nombre: string, M: Vector3, e: Vector3, s: Vector3, n: Vector3?, t: number, color: Color3, material: Enum.Material, tex,
	tinta: Color3?, choca: boolean?): WedgePart
	local normal = n or e:Cross(s).Unit
	if not n and normal.Y < 0 then
		normal = -normal
	end
	local Y, Z = s.Unit, -e.Unit
	local X = Y:Cross(Z)
	local w = Instance.new("WedgePart")
	w.Name = nombre
	w.Anchored = true
	w.CanCollide = choca == true
	w.CanQuery = choca == true
	w.CanTouch = false
	w.Size = Vector3.new(t, s.Magnitude, e.Magnitude)
	w.CFrame = CFrame.fromMatrix(M + e / 2 + s / 2 + normal * t / 2, X, Y, Z)
	w.Color = color
	w.Material = material
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Parent = grupo
	if tex then
		textura(w, if X:Dot(normal) > 0 then Enum.NormalId.Right else Enum.NormalId.Left, tex, tinta or color)
	end
	return w
end

-- Listón de `a` a `b`: `ancho` de lado y `fondo` hacia `arriba` (la normal de la pared en las molduras).
local function barra(nombre: string, a: Vector3, b: Vector3, ancho: number, fondo: number, color: Color3, material: Enum.Material?,
	arriba: Vector3?): Part
	return adorno(nombre, Vector3.new(ancho, fondo, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b, arriba or Vector3.yAxis), color, material)
end

local function tubo(desde: Vector3, hasta: Vector3, grueso: number): Part
	local t = adorno("Canalon", Vector3.new((hasta - desde).Magnitude, grueso, grueso),
		CFrame.lookAt((desde + hasta) / 2, hasta) * CFrame.Angles(0, math.pi / 2, 0), COLOR.Oxido, Enum.Material.Metal)
	t.Shape = Enum.PartType.Cylinder
	return t
end

-- Calcomanía en una lámina invisible (humedad).
local function humedad(pos: Vector3, normal: Vector3, tam: number)
	local p = adorno("Humedad", Vector3.new(tam, tam * 1.4, 0.04), CFrame.lookAt(pos, pos + normal) * CFrame.Angles(0, 0, math.pi), COLOR.Humedad)
	p.Transparency = 1
	p.CastShadow = false
	local d = Instance.new("Decal")
	d.Texture = MANCHAS[azar:NextInteger(1, #MANCHAS)]
	d.Color3 = COLOR.Humedad
	d.Transparency = 0.3
	d.Face = Enum.NormalId.Front
	d.Parent = p
end

-- Sangre seca (como mucho Moderate): con las manchas del módulo Mapa, colgando del edificio.
local function sangre(pos: Vector3, normal: Vector3, tam: number, imagen: number, alto: number?)
	local Mapa = ctx.Mapa
	Mapa.conPadre(grupo, function()
		Mapa.mancha(pos, normal, tam, Mapa.SANGRE[imagen], COLOR.Sangre, azar:NextNumber(0, math.pi * 2), alto)
	end)
end

-- Hiedra que sube por una esquina y se abre por las dos paredes. `paredes`: { normal, hacia (alejándose de la esquina) }.
local function hiedra(esquina: Vector3, paredes: { { Vector3 } }, alto: number, hojas: number)
	for _, pared in paredes do
		local normal, hacia = pared[1], pared[2]
		for _ = 1, hojas do
			local y = azar:NextNumber(0, 1) ^ 0.7 * alto
			local abre = azar:NextNumber(0, 1) ^ 2 * (1.5 + (alto - y) * 0.22)
			local pos = esquina + normal * (0.56 + azar:NextNumber(0, 0.25)) + hacia * abre + Vector3.new(0, y, 0)
			local tam = azar:NextNumber(0.5, 0.9)
			adorno("Hiedra", Vector3.new(tam, tam * 0.8, 0.08), CFrame.lookAt(pos, pos + normal) * CFrame.Angles(0, 0, azar:NextNumber(0, math.pi * 2))
				* CFrame.Angles(math.rad(azar:NextNumber(5, 30)), 0, 0), COLOR.Hoja[azar:NextInteger(1, #COLOR.Hoja)], Enum.Material.LeafyGrass)
		end
		for i = 0, 1 do
			local l = alto * (1 - i * 0.3)
			adorno("Tallo", Vector3.new(0.15, l, 0.15), CFrame.new(esquina + normal * 0.6 + hacia * (0.3 + i * 0.9) + Vector3.new(0, l / 2, 0))
				* CFrame.Angles(0, 0, (i - 0.5) * 0.08), Color3.fromRGB(58, 46, 34))
		end
	end
end

-- Medias medidas de fuera (de cara de fuera a cara de fuera) y el alto de arriba de las paredes.
local function caja(e): (number, number, number)
	return e.ancho / 2 + 0.5, e.largo / 2 + 0.5, 2 + e.alto
end

-- Ejes de un tejado: (a través, y, a lo largo de la cumbrera) al mundo. `P` da puntos y `V` vectores (o tamaños).
local function ejes(cx: number, cz: number, ejeZ: boolean)
	local function V(t: number, y: number, l: number): Vector3
		return if ejeZ then Vector3.new(t, y, l) else Vector3.new(l, y, t)
	end
	local function P(t: number, y: number, l: number): Vector3
		return Vector3.new(cx, 0, cz) + V(t, y, l)
	end
	return P, V
end

-- Punto de la cara de fuera del lado `lado`, a `u` del centro a lo largo de la pared, a `y` y `sale` por delante.
local function enCara(e, lado: string, u: number, y: number, sale: number): Vector3
	local hx, hz = caja(e)
	local f = PuebloPlano.LADOS[lado]
	local base = if lado == "N" or lado == "S" then Vector3.new(e.x + u, y, e.z + f.Z * hz) else Vector3.new(e.x + f.X * hx, y, e.z + u)
	return base + f * sale
end

local function largoLado(e, lado: string): number
	local hx, hz = caja(e)
	return if lado == "N" or lado == "S" then hx else hz
end

local function medidasVentana(e)
	return if e.nombre == "Iglesia" then PuebloPlano.VENTANA_IGLESIA else PuebloPlano.VENTANA
end

-- Pared de 1 de grueso centrada en el contorno, de y = 0 a lo alto, con los huecos { u0, u1, y0, y1 } (u: del centro a
-- lo largo de la pared, en x en N/S y en z en E/O). Las N y S tapan las esquinas.
local function muro(e, lado: string, huecos, aspecto)
	local f = PuebloPlano.LADOS[lado]
	local enX = lado == "N" or lado == "S"
	local medio = if enX then e.ancho / 2 + 0.5 else e.largo / 2 - 0.5
	local linea = if enX then e.z + f.Z * e.largo / 2 else e.x + f.X * e.ancho / 2
	local arriba = 2 + e.alto
	local cortes = { -medio, medio }
	for _, h in huecos do
		table.insert(cortes, h.u0)
		table.insert(cortes, h.u1)
	end
	table.sort(cortes)
	for i = 1, #cortes - 1 do
		local a, b = cortes[i], cortes[i + 1]
		if b - a < 0.01 then
			continue
		end
		local mitad = (a + b) / 2
		local tapan = {}
		for _, h in huecos do
			if h.u0 < mitad and mitad < h.u1 then
				table.insert(tapan, h)
			end
		end
		table.sort(tapan, function(p, q)
			return p.y0 < q.y0
		end)
		local function trozo(y0: number, y1: number)
			if y1 - y0 < 0.01 then
				return
			end
			local centro = if enX then Vector3.new(e.x + mitad, (y0 + y1) / 2, linea) else Vector3.new(linea, (y0 + y1) / 2, e.z + mitad)
			local tam = if enX then Vector3.new(b - a, y1 - y0, 1) else Vector3.new(1, y1 - y0, b - a)
			local p = solido("Muro", tam, CFrame.new(centro), aspecto.color, aspecto.material)
			if aspecto.tablas then
				textura(p, caraHacia(p, f), TABLAS, aspecto.tinta)
			end
		end
		local y = 0
		for _, h in tapan do
			trozo(y, h.y0)
			y = math.max(y, h.y1)
		end
		trozo(y, arriba)
	end
end

-- Canalón a lo largo de un alero (en los ejes del tejado): recto, combado o roto con un trozo colgando, y la bajante.
local function canalon(P, a: number, y: number, l: number, s: number, hastaSuelo: boolean)
	local tirada = azar:NextNumber()
	if tirada < 0.35 then
		tubo(P(s * a, y, -l), P(s * a, y, l), 0.5)
	elseif tirada < 0.7 then
		tubo(P(s * a, y, -l), P(s * a, y - 0.5, 0.1 * l), 0.5)
		tubo(P(s * a, y - 0.5, 0.1 * l), P(s * a, y, l), 0.5)
	else
		local corte = azar:NextNumber(0.1, 0.5) * l
		tubo(P(s * a, y, -l), P(s * a, y - 0.3, corte), 0.5)
		tubo(P(s * a, y - 0.3, corte), P(s * a + s * 0.6, y - 4, corte + 2.2), 0.5) -- el trozo suelto, colgando
	end
	if hastaSuelo then
		local roto = azar:NextNumber() < 0.4
		tubo(P(s * a, y, -l + 0.4), P(s * a, if roto then y * 0.45 else 0.4, -l + 0.4), 0.42)
		if roto then
			tubo(P(s * a + s * 0.5, 0.25, -l + 1), P(s * a + s * 2.2, 0.25, -l + 2.6), 0.42) -- el trozo caído
		end
	end
end

-- Tejado a dos aguas: faldones de tejas, hastiales (de la misma pared), tablas del alero y del hastial, cumbrera y
-- canalones. Devuelve la altura de la cumbrera y las funciones de ejes.
local function dosAguas(e, est, aspecto, ladoPorche: Vector3?)
	local hx, hz, H0 = caja(e)
	local ejeZ = est.eje ~= "x"
	local ha, hl = if ejeZ then hx else hz, if ejeZ then hz else hx
	local P, V = ejes(e.x, e.z, ejeZ)
	local pend, alero, vuelo = est.pendiente, est.alero or 1.2, est.vuelo or 0.8
	local sube = pend * ha
	local cumbre = H0 + sube
	local ye = H0 - pend * alero
	local tex = if est.sinTejas then nil else TEJAS
	local colorTeja = if est.sinTejas then aspecto.color:Lerp(Color3.new(), 0.2) else COLOR.Teja
	local moldura = est.moldura or COLOR.Moldura
	for _, s in { -1, 1 } do
		plano("Tejado", P(s * (ha + alero), ye, -(hl + vuelo)), V(0, 0, 2 * (hl + vuelo)), V(-s * (ha + alero), pend * (ha + alero), 0), 0.5,
			colorTeja, Enum.Material.Slate, tex, COLOR.TintaTeja, true)
		local conPorche = ladoPorche and ladoPorche:Dot(V(s, 0, 0)) > 0.9
		adorno("Alero", V(0.3, 1, 2 * (hl + vuelo)), CFrame.new(P(s * (ha + alero + 0.12), ye - 0.3, 0)), moldura)
		if not est.sinCanalon and not conPorche then
			canalon(P, ha + alero + 0.45, ye - 0.75, hl + vuelo - 0.2, s, true)
		end
	end
	for _, g in { -1, 1 } do
		local n = V(0, 0, g)
		local M = P(0, H0, g * (hl - 0.5)) - n * 0.5
		for _, s in { -1, 1 } do
			triangulo("Hastial", M, V(s * ha, 0, 0), Vector3.new(0, sube, 0), n, 1, aspecto.color, aspecto.material,
				if aspecto.tablas then TABLAS else nil, aspecto.tinta, true)
			barra("Hastial", P(s * (ha + alero + 0.1), ye - 0.25, g * (hl + vuelo + 0.12)), P(0, cumbre + 0.35, g * (hl + vuelo + 0.12)), 1, 0.3,
				moldura, Enum.Material.Wood, n)
		end
	end
	adorno("Cumbrera", V(1.1, 0.45, 2 * (hl + vuelo) + 0.2), CFrame.new(P(0, cumbre + 0.5 / math.cos(math.atan(pend)) - 0.05, 0)),
		colorTeja:Lerp(Color3.new(), 0.3), Enum.Material.Slate)
	return cumbre, P, V, ha, hl
end

-- Tejado a cuatro aguas sobre un rectángulo de medias medidas `A` (a través) y `B` (a lo largo, B >= A) con el alero a
-- `ye` y la cumbrera `alto` más arriba. Faldones de rectángulo y triángulos (para que las tejas sigan el alero) y limas.
local function cuatroAguas(P, V, A: number, B: number, ye: number, alto: number, color: Color3, tex)
	local r = B - A
	for _, s in { -1, 1 } do
		local subir = V(-s * A, alto, 0)
		if r > 0.05 then
			plano("Tejado", P(s * A, ye, -r), V(0, 0, 2 * r), subir, 0.5, color, Enum.Material.Slate, tex, COLOR.TintaTeja, true)
		end
		for _, g in { -1, 1 } do
			triangulo("Tejado", P(s * A, ye, g * r), V(0, 0, g * A), subir, nil, 0.5, color, Enum.Material.Slate, tex, COLOR.TintaTeja, true)
		end
	end
	for _, g in { -1, 1 } do
		local subir = V(0, alto, -g * A)
		for _, s in { -1, 1 } do
			triangulo("Tejado", P(0, ye, g * B), V(s * A, 0, 0), subir, nil, 0.5, color, Enum.Material.Slate, tex, COLOR.TintaTeja, true)
		end
	end
	local oscuro = color:Lerp(Color3.new(), 0.3)
	for _, s in { -1, 1 } do
		for _, g in { -1, 1 } do
			barra("Lima", P(s * A, ye + 0.45, g * B), P(0, ye + alto + 0.45, g * r), 0.7, 0.35, oscuro, Enum.Material.Slate)
		end
	end
	if r > 0.05 then
		adorno("Cumbrera", V(1, 0.45, 2 * r + 0.4), CFrame.new(P(0, ye + alto + 0.5, 0)), oscuro, Enum.Material.Slate)
	end
end

-- Contraventana con la bisagra en `bisagra` (Y arriba, -Z fuera); se abre hacia `sentido` en X. "colgando": solo de
-- la bisagra de arriba, el otro lado cae.
local function contraventana(bisagra: CFrame, sentido: number, ancho: number, alto: number, color: Color3, estado: string)
	local cf = bisagra
	if estado == "colgando" then
		cf = bisagra * CFrame.new(0, alto / 2, -0.15) * CFrame.Angles(0, 0, -sentido * math.rad(azar:NextNumber(18, 34))) * CFrame.new(0, -alto / 2, 0)
	end
	local hoja = cf * CFrame.new(sentido * ancho / 2, 0, 0)
	adorno("Contraventana", Vector3.new(ancho, alto, 0.2), hoja, color, Enum.Material.WoodPlanks)
	for _, y in { alto / 2 - 0.2, -alto / 2 + 0.2, 0 } do
		adorno("Travesano", Vector3.new(ancho, 0.3, 0.1), hoja * CFrame.new(0, y, -0.14), color:Lerp(Color3.new(), 0.3))
	end
end

-- Sitio libre a cada lado de una ventana (a medias con la vecina) para las contraventanas: en +u y en -u.
local function libre(e, w, m): (number, number)
	local fin = largoLado(e, w.lado) - 0.8
	local mas, menos = fin - (w.desde + m.ancho / 2), (w.desde - m.ancho / 2) + fin
	local function otro(u0: number, u1: number, parte: number)
		if u0 >= w.desde + m.ancho / 2 then
			mas = math.min(mas, (u0 - (w.desde + m.ancho / 2)) * parte)
		elseif u1 <= w.desde - m.ancho / 2 then
			menos = math.min(menos, (w.desde - m.ancho / 2 - u1) * parte)
		end
	end
	for _, o in e.ventanas do
		if o ~= w and o.lado == w.lado and o.planta == w.planta then
			otro(o.desde - m.ancho / 2, o.desde + m.ancho / 2, 0.5)
		end
	end
	if w.planta == 1 and w.lado == e.puerta then
		otro(-2.6, 2.6, 1)
	end
	return mas, menos
end

-- Esquirlas de cristal en las esquinas de un hueco roto (`cf` = centro, -Z fuera).
local function esquirlas(cf: CFrame, w: number, h: number, z: number)
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		if azar:NextNumber() < 0.75 then
			local a, b = azar:NextNumber(0.5, 1.3), azar:NextNumber(0.6, 1.6)
			local base = cf * CFrame.new(c[1] * (w / 2 - a / 2), c[2] * (h / 2 - b / 2), z)
			local p = Instance.new("WedgePart")
			p.Name = "Esquirla"
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.CastShadow = false
			p.Size = Vector3.new(0.06, b, a)
			-- El ángulo recto de la cuña en la esquina del marco.
			p.CFrame = base * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(if c[2] > 0 then math.pi else 0, if c[1] > 0 then math.pi else 0, 0)
			p.Color = COLOR.Cristal
			p.Material = Enum.Material.Glass
			p.Transparency = 0.35
			p.Parent = grupo
		end
	end
end

-- Tablas clavadas tapando un hueco (`cf` = centro, -Z fuera), algo torcidas.
local function tablones(cf: CFrame, w: number, h: number, z: number, n: number)
	for i = 1, n do
		local y = (i - (n + 1) / 2) * h / n * 0.9 + azar:NextNumber(-0.2, 0.2)
		adorno("Tablon", Vector3.new(w + 1.4, 0.7, 0.18), cf * CFrame.new(0, y, z - i * 0.03) * CFrame.Angles(0, 0, azar:NextNumber(-0.18, 0.18)),
			COLOR.Tabla:Lerp(Color3.fromRGB(70, 66, 60), azar:NextNumber()), Enum.Material.WoodPlanks)
	end
end

-- Lo de fuera de una ventana: molduras de madera o dintel y alféizar de piedra; con hueco de verdad, cristal (o roto,
-- con una lámina invisible que sigue chocando) y parteluz; si no, ventana de mentira oscura, rota o tapiada.
local function ventana(e, w)
	local m = medidasVentana(e)
	local cf = PuebloPlano.ventanaCF(e, w)
	local ancho, alto = m.ancho, m.alto
	if e.material == "madera" then
		for _, lado in { -1, 1 } do
			adorno("Moldura", Vector3.new(0.5, alto + 0.5, 0.4), cf * CFrame.new(lado * (ancho / 2 + 0.25), 0, -0.6), COLOR.Moldura)
		end
		adorno("Dintel", Vector3.new(ancho + 1.6, 0.7, 0.5), cf * CFrame.new(0, alto / 2 + 0.45, -0.65), COLOR.Moldura)
		adorno("Cornisa", Vector3.new(ancho + 2, 0.25, 0.8), cf * CFrame.new(0, alto / 2 + 0.9, -0.75), COLOR.Moldura)
		adorno("Alfeizar", Vector3.new(ancho + 1.4, 0.3, 0.9), cf * CFrame.new(0, -alto / 2 - 0.15, -0.8), COLOR.Moldura)
	else
		local piedra = if e.material == "piedra" then COLOR.PiedraOscura else COLOR.PiedraClara
		adorno("Dintel", Vector3.new(ancho + 1.2, 0.8, 0.4), cf * CFrame.new(0, alto / 2 + 0.4, -0.6), piedra, Enum.Material.Slate)
		adorno("Alfeizar", Vector3.new(ancho + 1, 0.35, 0.8), cf * CFrame.new(0, -alto / 2 - 0.18, -0.75), piedra, Enum.Material.Slate)
	end
	local roto = false
	if e.entra then
		roto = azar:NextNumber() < 0.5
		local cristal = solido("Cristal", Vector3.new(ancho, alto, 0.2), cf, COLOR.Cristal, Enum.Material.Glass)
		cristal.Transparency = if roto then 1 else 0.45
		cristal.Reflectance = 0.1
		cristal.CastShadow = false
		if roto then
			esquirlas(cf, ancho, alto, 0)
		end
	else
		local tirada = azar:NextNumber()
		local estado = if tirada < 0.4 then "oscura" elseif tirada < 0.72 then "rota" else "tapiada"
		roto = estado == "rota"
		local p = adorno("Cristal", Vector3.new(ancho, alto, 0.1), cf * CFrame.new(0, 0, -0.56), if roto then COLOR.Negro else COLOR.Cristal,
			if roto then Enum.Material.SmoothPlastic else Enum.Material.Glass)
		p.Reflectance = if roto then 0 else 0.12
		if roto then
			esquirlas(cf, ancho, alto, -0.64)
			tablones(cf, ancho, alto, -0.78, 2)
		elseif estado == "tapiada" then
			tablones(cf, ancho, alto, -0.78, 4)
		end
	end
	-- Parteluz (en las rotas, partido).
	local z = if e.entra then -0.15 else -0.66
	adorno("Parteluz", Vector3.new(0.18, if roto then alto * 0.55 else alto, 0.2), cf * CFrame.new(0, if roto then -alto * 0.22 else 0, z), COLOR.Moldura)
	if not roto then
		adorno("Parteluz", Vector3.new(ancho, 0.18, 0.2), cf * CFrame.new(0, 0, z), COLOR.Moldura)
	end
	-- Contraventanas en las de madera, si caben.
	if e.material == "madera" then
		local mas, menos = libre(e, w, m)
		local derechaEsMas = w.lado == "N" or w.lado == "E"
		local color = COLOR.Contra[azar:NextInteger(1, #COLOR.Contra)]
		for _, sentido in { -1, 1 } do
			local sitio = if (sentido > 0) == derechaEsMas then mas else menos
			local anchoHoja = math.min(ancho / 2 + 0.2, sitio - 0.2)
			if anchoHoja >= 1.2 then
				local tirada = azar:NextNumber()
				if tirada >= 0.12 then
					contraventana(cf * CFrame.new(sentido * (ancho / 2 + 0.55), 0, -0.85), sentido, anchoHoja, alto + 0.3, color,
						if tirada < 0.32 then "colgando" else "bien")
				end
			end
		end
	end
end

-- Vidriera de la iglesia: cristales oscuros de colores con plomos (faltan algunos) y arco apuntado de piedra.
local function vidriera(e, w)
	local m = medidasVentana(e)
	local cf = PuebloPlano.ventanaCF(e, w)
	local ancho, alto = m.ancho, m.alto
	solido("Cristal", Vector3.new(ancho, alto, 0.2), cf, COLOR.Cristal, Enum.Material.Glass).Transparency = 1
	for i = 0, 1 do
		for j = 0, 3 do
			if azar:NextNumber() < 0.3 then
				continue -- roto
			end
			local p = adorno("Vidrio", Vector3.new(ancho / 2 - 0.1, alto / 4 - 0.1, 0.1), cf * CFrame.new((i - 0.5) * ancho / 2, (j - 1.5) * alto / 4, 0),
				COLOR.Vidriera[azar:NextInteger(1, #COLOR.Vidriera)], Enum.Material.Glass)
			p.Transparency = 0.1
			p.CastShadow = false
		end
	end
	adorno("Plomo", Vector3.new(0.14, alto, 0.16), cf, COLOR.Hierro, Enum.Material.Metal)
	for j = 1, 3 do
		adorno("Plomo", Vector3.new(ancho, 0.14, 0.16), cf * CFrame.new(0, (j - 2) * alto / 4, 0), COLOR.Hierro, Enum.Material.Metal)
	end
	esquirlas(cf, ancho, alto, -0.1)
	local fuera = cf.LookVector
	for _, lado in { -1, 1 } do
		adorno("Jamba", Vector3.new(0.5, alto, 0.4), cf * CFrame.new(lado * (ancho / 2 + 0.25), 0, -0.6), COLOR.PiedraOscura, Enum.Material.Slate)
		barra("Arco", cf * Vector3.new(lado * (ancho / 2 + 0.5), alto / 2, -0.62), cf * Vector3.new(0, alto / 2 + 1.7, -0.62), 0.55, 0.45,
			COLOR.PiedraOscura, Enum.Material.Slate, fuera)
	end
	adorno("Alfeizar", Vector3.new(ancho + 1, 0.4, 0.8), cf * CFrame.new(0, -alto / 2 - 0.2, -0.7), COLOR.PiedraOscura, Enum.Material.Slate)
end

-- Hoja de puerta abierta hacia fuera desde la bisagra del lado `lado` (en X del hueco), `angulo` desde cerrada.
local function hoja(cf: CFrame, lado: number, ancho: number, angulo: number, caida: number, color: Color3)
	local bisagra = cf * CFrame.new(lado * 2, 4, -0.62) * CFrame.Angles(0, -lado * angulo, 0)
	local c = bisagra * CFrame.new(-lado * ancho / 2, 0, 0) * CFrame.Angles(0, 0, caida)
	adorno("Puerta", Vector3.new(ancho - 0.1, 7.8, 0.25), c, color, Enum.Material.WoodPlanks)
	for _, y in { 2.4, -2.4 } do
		adorno("Cuarteron", Vector3.new(ancho - 0.9, 2.6, 0.08), c * CFrame.new(0, y, -0.15), color:Lerp(Color3.new(), 0.25), Enum.Material.WoodPlanks)
	end
	local pomo = adorno("Pomo", Vector3.new(0.3, 0.3, 0.3), c * CFrame.new(-lado * (ancho / 2 - 0.45), 0, -0.25), COLOR.Oxido, Enum.Material.Metal)
	pomo.Shape = Enum.PartType.Ball
end

-- Puerta de los que se entra: marco que atraviesa la pared y una puerta rota o entreabierta que no estorba.
local function puertaAbierta(e, est)
	local cf = PuebloPlano.puertaCF(e)
	local piedra = e.material == "piedra"
	local color = if piedra then COLOR.PiedraOscura else COLOR.Moldura
	local mat = if piedra then Enum.Material.Slate else Enum.Material.Wood
	for _, lado in { -1, 1 } do
		adorno("Marco", Vector3.new(0.4, 8.4, 1.3), cf * CFrame.new(lado * 2.2, 4.2, 0), color, mat)
	end
	adorno("Marco", Vector3.new(4.8, 0.45, 1.3), cf * CFrame.new(0, 8.2, 0), color, mat)
	local tipo = est.puerta or "abierta"
	if tipo == "caida" then
		-- Arrancada y tirada delante (encima del porche, plana: se pisa sin notarla).
		local abajo = if est.porche then 0.14 else -0.86
		adorno("Puerta", Vector3.new(3.4, 7.2, 0.25), cf * CFrame.new(0.8, abajo, -2.3) * CFrame.Angles(math.pi / 2, 0, 0) * CFrame.Angles(0, 0, math.pi / 2 + 0.12),
			COLOR.Puerta, Enum.Material.WoodPlanks)
		adorno("Bisagra", Vector3.new(0.3, 0.8, 0.2), cf * CFrame.new(-2.05, 6.5, -0.66), COLOR.Oxido, Enum.Material.Metal)
	elseif tipo == "doble" then
		hoja(cf, 1, 2, math.rad(82), 0, COLOR.Puerta)
		hoja(cf, -1, 2, math.rad(100), 0.06, COLOR.Puerta)
	elseif tipo == "reja" then
		-- Reja de hierro medio abierta.
		local bisagra = cf * CFrame.new(-2, 0, -0.62) * CFrame.Angles(0, math.rad(85), 0)
		for _, y in { 0.6, 7.6 } do
			adorno("Reja", Vector3.new(3.9, 0.25, 0.25), bisagra * CFrame.new(1.95, y, 0), COLOR.Hierro, Enum.Material.Metal)
		end
		for i = 0, 5 do
			adorno("Barrote", Vector3.new(0.18, 7.6, 0.18), bisagra * CFrame.new(0.2 + i * 0.7, 4, 0), COLOR.Hierro, Enum.Material.Metal)
		end
	else
		hoja(cf, est.bisagra or 1, 4, math.rad(est.angulo or 75), est.caida or 0, COLOR.Puerta)
	end
	return cf
end

-- Puerta tapiada de los que no se entra (como el `edificio(..., cerrado)` de antes): hoja, marco y tablones clavados.
local function puertaTapiada(e, est)
	local cf = PuebloPlano.puertaCF(e) * CFrame.new(0, 4, 0)
	adorno("Puerta", Vector3.new(4, 8, 0.2), cf * CFrame.new(0, 0, -0.6), COLOR.Puerta, Enum.Material.WoodPlanks)
	for _, lado in { -1, 1 } do
		adorno("Marco", Vector3.new(0.5, 8.5, 0.4), cf * CFrame.new(lado * 2.25, 0.25, -0.62), COLOR.Moldura)
	end
	adorno("Marco", Vector3.new(5, 0.6, 0.45), cf * CFrame.new(0, 4.3, -0.65), COLOR.Moldura)
	tablones(cf, 4, 8, -0.85, 4)
	-- Una tabla en diagonal, de esquina a esquina.
	adorno("Tablon", Vector3.new(9, 0.7, 0.18), cf * CFrame.new(0, 0, -1.05) * CFrame.Angles(0, 0, math.rad(62)), COLOR.Tabla, Enum.Material.WoodPlanks)
	-- Encima del porche (a y = 1) o, sin porche, en el suelo (flotaba a 1 stud).
	adorno("Escalon", Vector3.new(5, 0.5, 1.2), cf * CFrame.new(0, if est.porche then -3.75 else -4.75, -1.1), COLOR.PiedraOscura,
		Enum.Material.Slate)
	return cf
end

-- Porche en el lado de la puerta: suelo que se pisa (arriba a y = 1, como dentro: un solo escalón de 1), medio
-- escalón delante de la puerta, postes, barandillas rotas a los lados y tejadillo de tejas. Lo demás no choca.
local function porche(e)
	local f = PuebloPlano.LADOS[e.puerta]
	local enX = e.puerta == "N" or e.puerta == "S"
	local hx, hz = caja(e)
	local cara = if enX then hz else hx
	local largo = (if enX then hx else hz) * 2 - 0.6
	local prof = 3 -- las vallas de jardín (PuebloCalle) quedan a unos 4,4 de la fachada más cercana
	local a = if enX then Vector3.xAxis else Vector3.zAxis
	local centro = Vector3.new(e.x, 0, e.z) + f * cara
	local function aqui(u: number, y: number, sale: number): Vector3
		return centro + a * u + Vector3.new(0, y, 0) + f * sale
	end
	local suelo = solido("Porche", if enX then Vector3.new(largo, 1, prof) else Vector3.new(prof, 1, largo), CFrame.new(aqui(0, 0.5, prof / 2)),
		COLOR.Suelo, Enum.Material.WoodPlanks)
	suelo:SetAttribute("SinSeparar", true)
	suelo.Color = Color3.fromRGB(60, 52, 44)
	solido("Escalon", if enX then Vector3.new(5, 0.5, 0.8) else Vector3.new(0.8, 0.5, 5), CFrame.new(aqui(0, 0.25, prof + 0.4)), COLOR.PiedraOscura,
		Enum.Material.Slate)
	-- Tablas rotas del suelo del porche (agujeros oscuros) y una suelta.
	for _ = 1, 2 do
		local u = azar:NextNumber(-largo / 2 + 1.5, largo / 2 - 1.5)
		if math.abs(u) > 2.5 then
			adorno("Agujero", if enX then Vector3.new(1.6, 0.06, 0.45) else Vector3.new(0.45, 0.06, 1.6), CFrame.new(aqui(u, 1.02, azar:NextNumber(1, 2.6))),
				COLOR.Negro, Enum.Material.SmoothPlastic)
		end
	end
	local altoPlanta = PuebloPlano.altoPlanta(e)
	local yPared = if e.plantas > 1 then 1 + altoPlanta + 1.2 else e.alto
	local yFrente = yPared - 1.1
	plano("Tejadillo", aqui(-largo / 2 - 0.3, yPared, 0), a * (largo + 0.6), f * (prof + 0.6) - Vector3.new(0, yPared - yFrente, 0), 0.35, COLOR.Teja,
		Enum.Material.Slate, TEJAS, COLOR.TintaTeja)
	adorno("Viga", if enX then Vector3.new(largo + 0.4, 0.8, 0.5) else Vector3.new(0.5, 0.8, largo + 0.4), CFrame.new(aqui(0, yFrente - 0.55, prof - 0.4)),
		COLOR.Moldura)
	for _, s in { -1, 1 } do
		local u = s * (largo / 2 - 0.4)
		adorno("Poste", Vector3.new(0.6, yFrente - 1.6, 0.6), CFrame.new(aqui(u, 1 + (yFrente - 1.6) / 2, prof - 0.4)), COLOR.Moldura)
		adorno("Basa", Vector3.new(1, 0.5, 1), CFrame.new(aqui(u, 1.25, prof - 0.4)), COLOR.Moldura)
		for _, k in { -1, 1 } do
			barra("Mensula", aqui(u + k * 0.3, yFrente - 1.2, prof - 0.4), aqui(u + k * 1.3, yFrente - 0.3, prof - 0.4), 0.3, 0.3, COLOR.Moldura,
				Enum.Material.Wood, f)
		end
		-- Barandilla del costado: pasamanos (en un lado, partido y caído) y balaustres.
		local roto = s > 0
		local desde, hasta = aqui(u, 3.6, 0.5), aqui(u, 3.6, prof - 0.7)
		if roto then
			barra("Pasamanos", desde, desde:Lerp(hasta, 0.45), 0.4, 0.3, COLOR.Moldura)
			barra("Pasamanos", aqui(u, 1.2, 1.6), aqui(u + s * 0.4, 3.3, prof - 0.7), 0.4, 0.3, COLOR.Moldura)
		else
			barra("Pasamanos", desde, hasta, 0.4, 0.3, COLOR.Moldura)
		end
		for i = 0, 3 do
			if not (roto and i == 2) then
				adorno("Balaustre", Vector3.new(0.25, 2.4, 0.25), CFrame.new(aqui(u, 2.3, 0.8 + i * 0.7)), COLOR.Moldura)
			end
		end
	end
end

-- Chimenea de ladrillo que sale del tejado (empieza encima del techo: por dentro no se ve).
local function chimenea(pos: Vector3, desde: number, hasta: number)
	local alto = hasta - desde
	local tuerce = CFrame.Angles(azar:NextNumber(-0.03, 0.03), 0, azar:NextNumber(-0.04, 0.04))
	local cf = CFrame.new(pos.X, desde + alto / 2, pos.Z) * tuerce
	adorno("Chimenea", Vector3.new(2.2, alto, 2.6), cf, COLOR.Chimenea, Enum.Material.Brick).CastShadow = true
	adorno("Remate", Vector3.new(2.8, 0.5, 3.2), cf * CFrame.new(0, alto / 2 - 0.6, 0), COLOR.PiedraOscura, Enum.Material.Slate)
	adorno("Boca", Vector3.new(1.4, 0.1, 1.8), cf * CFrame.new(0, alto / 2 + 0.01, 0), COLOR.Negro, Enum.Material.SmoothPlastic)
end

-- Esquineras, zócalo de piedra y franja entre plantas (madera); lo de abajo deja libres la puerta y el porche.
local function remates(e, est)
	local hx, hz, H0 = caja(e)
	if e.material == "madera" then
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local x, z = e.x + sx * hx, e.z + sz * hz
				adorno("Esquinera", Vector3.new(0.3, H0, 1.2), CFrame.new(x + sx * 0.15, H0 / 2, z - sz * 0.45), COLOR.Moldura)
				adorno("Esquinera", Vector3.new(1.2, H0, 0.3), CFrame.new(x - sx * 0.45, H0 / 2, z + sz * 0.15), COLOR.Moldura)
			end
		end
		for _, lado in { "N", "S", "E", "O" } do
			local l = largoLado(e, lado)
			local tramos = { { -l, l } }
			if lado == e.puerta then
				if est.porche then
					tramos = {}
				else
					tramos = { { -l, -2.5 }, { 2.5, l } }
				end
			end
			local f = PuebloPlano.LADOS[lado]
			local enX = lado == "N" or lado == "S"
			for _, t in tramos do
				local u, largo = (t[1] + t[2]) / 2, t[2] - t[1]
				local pos = enCara(e, lado, u, 0.75, 0.15)
				adorno("Zocalo", if enX then Vector3.new(largo, 1.5, 0.5) else Vector3.new(0.5, 1.5, largo), CFrame.new(pos), COLOR.PiedraOscura,
					Enum.Material.Cobblestone)
				adorno("Remate", if enX then Vector3.new(largo, 0.25, 0.7) else Vector3.new(0.7, 0.25, largo), CFrame.new(pos + Vector3.new(0, 0.85, 0) + f * 0.05),
					COLOR.PiedraOscura, Enum.Material.Slate)
			end
		end
	end
	if e.plantas > 1 then
		local y = 1 + PuebloPlano.altoPlanta(e)
		for _, lado in { "N", "S", "E", "O" } do
			local l = largoLado(e, lado)
			local enX = lado == "N" or lado == "S"
			adorno("Franja", if enX then Vector3.new(2 * l + 0.6, 0.8, 0.5) else Vector3.new(0.5, 0.8, 2 * l + 0.6), CFrame.new(enCara(e, lado, 0, y, 0.1)),
				if e.material == "madera" then COLOR.Moldura else COLOR.PiedraClara, if e.material == "madera" then Enum.Material.Wood else Enum.Material.Slate)
		end
	end
end

-- ¿Hay una ventana o la puerta en ese sitio de la pared? (para no tapar nada con la humedad o las tablas rotas)
local function ocupado(e, lado: string, u: number, y: number, margen: number): boolean
	if lado == e.puerta and math.abs(u) < 2 + margen and y < 9 + margen then
		return true
	end
	local m = medidasVentana(e)
	for _, w in e.ventanas do
		if w.lado == lado then
			local cy = PuebloPlano.ventanaCF(e, w).Position.Y
			if math.abs(u - w.desde) < m.ancho / 2 + margen + 1 and math.abs(y - cy) < m.alto / 2 + margen + 1.2 then
				return true
			end
		end
	end
	return false
end

-- Abandono: manchas de humedad bajo el alero y junto al suelo, tablas rotas (agujeros y una suelta) e hiedra.
local function abandono(e, est)
	local _, _, H0 = caja(e)
	local lados = { "N", "S", "E", "O" }
	for _ = 1, 3 do
		local lado = lados[azar:NextInteger(1, 4)]
		local l = largoLado(e, lado) - 1.5
		local u = azar:NextNumber(-l, l)
		local y = if azar:NextNumber() < 0.6 then H0 - azar:NextNumber(1.8, 3) else azar:NextNumber(2, 3.5)
		if not ocupado(e, lado, u, y, 0.5) then
			humedad(enCara(e, lado, u, y, 0.08), PuebloPlano.LADOS[lado], azar:NextNumber(3, 5))
		end
	end
	if e.material == "madera" then
		local hechas = 0
		for _ = 1, 8 do
			local lado = lados[azar:NextInteger(1, 4)]
			local l = largoLado(e, lado) - 2
			local u, y = azar:NextNumber(-l, l), azar:NextNumber(1.8, H0 - 2)
			if hechas < 3 and not ocupado(e, lado, u, y, 0.3) then
				hechas += 1
				local cf = CFrame.lookAt(enCara(e, lado, u, y, 0.03), enCara(e, lado, u, y, 1))
				adorno("Agujero", Vector3.new(azar:NextNumber(1.6, 3), 0.42, 0.05), cf * CFrame.Angles(0, 0, azar:NextNumber(-0.05, 0.05)), COLOR.Negro,
					Enum.Material.SmoothPlastic)
				if hechas == 1 then
					-- La tabla que falta, colgando de un clavo.
					adorno("TablaSuelta", Vector3.new(3.6, 0.45, 0.15), cf * CFrame.new(1.3, -0.9, -0.12) * CFrame.Angles(0, 0, math.rad(azar:NextNumber(18, 32))),
						est.color:Lerp(Color3.new(), 0.2), Enum.Material.WoodPlanks)
				end
			end
		end
	end
	if est.hiedra then
		local hx, hz = caja(e)
		local sz = if string.find(est.hiedra, "N") then -1 else 1
		local sx = if string.find(est.hiedra, "O") then -1 else 1
		local esquina = Vector3.new(e.x + sx * hx, 0, e.z + sz * hz)
		hiedra(esquina, { { Vector3.new(0, 0, sz), Vector3.new(-sx, 0, 0) }, { Vector3.new(sx, 0, 0), Vector3.new(0, 0, -sz) } }, math.min(H0 + 1, 18), 55)
	end
end

-- La tienda: tejado plano con pretil, fachada falsa escalonada con su cartel (sin letras) y el toldo roto.
local function tienda(e, est)
	local hx, hz, H0 = caja(e)
	solido("Tejado", Vector3.new(2 * hx + 0.8, 0.4, 2 * hz + 0.8), CFrame.new(e.x, H0 + 0.2, e.z), Color3.fromRGB(38, 36, 34), Enum.Material.Slate)
	-- El pretil del oeste, uno solo (estaba dentro del bucle y salían dos iguales); al este va la fachada falsa.
	adorno("Pretil", Vector3.new(1, 1.2, 2 * hz - 2), CFrame.new(e.x - hx + 0.5, H0 + 1, e.z), est.color, Enum.Material.Brick)
	for _, s in { -1, 1 } do
		adorno("Pretil", Vector3.new(2 * hx, 1.2, 1), CFrame.new(e.x, H0 + 1, e.z + s * (hz - 0.5)), est.color, Enum.Material.Brick)
		adorno("Cornisa", Vector3.new(2 * hx + 1, 0.5, 0.6), CFrame.new(e.x, H0 - 0.3, e.z + s * (hz + 0.1)), COLOR.PiedraClara, Enum.Material.Slate)
		adorno("Cornisa", Vector3.new(0.6, 0.5, 2 * hz + 1), CFrame.new(e.x + s * (hx + 0.1), H0 - 0.3, e.z), COLOR.PiedraClara, Enum.Material.Slate)
	end
	-- Fachada falsa sobre la puerta (al este), escalonada.
	local x = e.x + hx - 0.5
	adorno("FachadaFalsa", Vector3.new(1, 4.6, 2 * hz), CFrame.new(x, H0 + 2.7, e.z), est.color, Enum.Material.Brick).CastShadow = true
	adorno("FachadaFalsa", Vector3.new(1, 1.6, 6), CFrame.new(x, H0 + 5.8, e.z), est.color, Enum.Material.Brick)
	adorno("Remate", Vector3.new(1.5, 0.4, 2 * hz + 0.4), CFrame.new(x, H0 + 5.1, e.z), COLOR.PiedraClara, Enum.Material.Slate)
	adorno("Remate", Vector3.new(1.5, 0.4, 6.4), CFrame.new(x, H0 + 6.7, e.z), COLOR.PiedraClara, Enum.Material.Slate)
	local cartel = CFrame.new(x + 0.75, H0 + 2.6, e.z) * CFrame.Angles(math.rad(3), 0, 0)
	adorno("Cartel", Vector3.new(0.3, 2.2, 8.4), cartel, Color3.fromRGB(46, 40, 34), Enum.Material.WoodPlanks)
	adorno("Cartel", Vector3.new(0.12, 1.4, 7.4), cartel * CFrame.new(0.18, 0, 0), Color3.fromRGB(70, 64, 54), Enum.Material.WoodPlanks)
	-- Toldo sobre la puerta y los escaparates: tela vieja a rayas, rasgada en un tramo, con un jirón colgando.
	local cara = e.x + hx
	local fuera = Vector3.xAxis
	for i, t in { { -6.2, -2.4 }, { -2.1, 1.6 }, { 2.4, 6.2 } } do
		local tela = if i % 2 == 0 then Color3.fromRGB(70, 30, 28) else Color3.fromRGB(78, 72, 60)
		local desde = Vector3.new(cara, 10.4, e.z + t[1])
		local p = plano("Toldo", desde, Vector3.zAxis * (t[2] - t[1]), fuera * 3.2 - Vector3.new(0, 1.3, 0), 0.08, tela, Enum.Material.Fabric)
		p.CastShadow = true
		if i == 2 then
			adorno("Jiron", Vector3.new(0.08, 1.8, 1.4), CFrame.new(cara + 3, 8.4, e.z + 0.6) * CFrame.Angles(0, 0, 0.2), tela, Enum.Material.Fabric)
		end
	end
	for _, z in { -6, 0, 6 } do
		barra("Varilla", Vector3.new(cara, 9.2, e.z + z), Vector3.new(cara + 3.2, 9.1, e.z + z), 0.12, 0.12, COLOR.Hierro, Enum.Material.Metal)
	end
	barra("Varilla", Vector3.new(cara + 3.15, 9.1, e.z - 6.2), Vector3.new(cara + 3.15, 9.1, e.z + 6.2), 0.15, 0.15, COLOR.Hierro, Enum.Material.Metal)
end

-- El campanario (fuera, en la esquina del noroeste de la iglesia): torre de piedra, campanario abierto con la campana,
-- aguja de pizarra y cruz de hierro; puerta de mentira, saeteras y un reloj parado sin números.
local function campanario()
	local C = PuebloPlano.CAMPANARIO
	local l, x, z = C.lado, C.x, C.z
	local cuerpo = C.alto - 4 -- lo macizo; encima va el campanario abierto (7) y la aguja
	local piedra = COLOR.Piedra
	solido("Campanario", Vector3.new(l, cuerpo, l), CFrame.new(x, cuerpo / 2, z), piedra, Enum.Material.Cobblestone)
	adorno("Zocalo", Vector3.new(l + 0.6, 1.6, l + 0.6), CFrame.new(x, 0.8, z), COLOR.PiedraOscura, Enum.Material.Slate)
	adorno("Franja", Vector3.new(l + 0.5, 0.5, l + 0.5), CFrame.new(x, 12.5, z), COLOR.PiedraOscura, Enum.Material.Slate)
	adorno("Cornisa", Vector3.new(l + 1, 0.7, l + 1), CFrame.new(x, cuerpo, z), COLOR.PiedraOscura, Enum.Material.Slate)
	local b0, b1 = cuerpo + 0.35, cuerpo + 7
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			adorno("Pilar", Vector3.new(1.3, b1 - b0, 1.3), CFrame.new(x + sx * (l / 2 - 0.65), (b0 + b1) / 2, z + sz * (l / 2 - 0.65)), piedra,
				Enum.Material.Cobblestone).CastShadow = true
		end
	end
	for _, d in { Vector3.xAxis, -Vector3.xAxis, Vector3.zAxis, -Vector3.zAxis } do
		local lado = if math.abs(d.X) > 0 then Vector3.new(0.8, 1, l) else Vector3.new(l, 1, 0.8)
		local antepecho = if math.abs(d.X) > 0 then Vector3.new(0.6, 1.2, l - 2.6) else Vector3.new(l - 2.6, 1.2, 0.6)
		adorno("Arco", lado, CFrame.new(Vector3.new(x, b1 - 0.5, z) + d * (l / 2 - 0.4)), piedra, Enum.Material.Cobblestone)
		adorno("Antepecho", antepecho, CFrame.new(Vector3.new(x, b0 + 0.6, z) + d * (l / 2 - 0.3)), piedra, Enum.Material.Cobblestone)
	end
	adorno("Tapa", Vector3.new(l + 1, 0.8, l + 1), CFrame.new(x, b1 + 0.4, z), COLOR.PiedraOscura, Enum.Material.Slate)
	-- La campana, colgando de su yugo.
	adorno("Yugo", Vector3.new(l - 1.2, 0.6, 0.6), CFrame.new(x, b1 - 1.4, z), Color3.fromRGB(50, 40, 32))
	local bronce = Color3.fromRGB(66, 54, 36)
	local campana = adorno("Campana", Vector3.new(2.2, 2.3, 2.3), CFrame.new(x, b1 - 3.4, z) * CFrame.Angles(0, 0, math.pi / 2), bronce, Enum.Material.Metal)
	campana.Shape = Enum.PartType.Cylinder
	local labio = adorno("Campana", Vector3.new(0.4, 2.8, 2.8), CFrame.new(x, b1 - 4.5, z) * CFrame.Angles(0, 0, math.pi / 2), bronce, Enum.Material.Metal)
	labio.Shape = Enum.PartType.Cylinder
	local cupula = adorno("Campana", Vector3.new(2.2, 2.2, 2.2), CFrame.new(x, b1 - 2.4, z), bronce, Enum.Material.Metal)
	cupula.Shape = Enum.PartType.Ball
	-- Aguja y cruz (algo torcida).
	local P, V = ejes(x, z, true)
	local ye, alto = b1 + 0.8, 11
	cuatroAguas(P, V, l / 2 + 0.5, l / 2 + 0.5, ye, alto, Color3.fromRGB(42, 41, 45), TEJAS)
	local cruz = CFrame.new(x, ye + alto + 2.1, z) * CFrame.Angles(math.rad(5), 0, 0)
	adorno("Cruz", Vector3.new(0.4, 4.4, 0.4), cruz, COLOR.Hierro, Enum.Material.Metal)
	adorno("Cruz", Vector3.new(0.4, 0.4, 2.6), cruz * CFrame.new(0, 0.9, 0), COLOR.Hierro, Enum.Material.Metal)
	-- Por fuera (oeste, a la calle): puerta de mentira, saeteras y el reloj parado.
	local oeste = x - l / 2
	adorno("Puerta", Vector3.new(0.2, 5, 2.6), CFrame.new(oeste - 0.1, 2.5, z), COLOR.Puerta, Enum.Material.WoodPlanks)
	adorno("Dintel", Vector3.new(0.5, 0.6, 3.4), CFrame.new(oeste - 0.2, 5.2, z), COLOR.PiedraOscura, Enum.Material.Slate)
	for _, y in { 9, 16 } do
		adorno("Saetera", Vector3.new(0.1, 2.2, 0.5), CFrame.new(oeste - 0.05, y, z), COLOR.Negro, Enum.Material.SmoothPlastic)
		adorno("Saetera", Vector3.new(0.5, 2.2, 0.1), CFrame.new(x, y + 2, z + l / 2 + 0.05), COLOR.Negro, Enum.Material.SmoothPlastic)
	end
	local reloj = adorno("Reloj", Vector3.new(0.3, 3.4, 3.4), CFrame.new(oeste - 0.15, cuerpo - 3, z), COLOR.PiedraOscura, Enum.Material.Slate)
	reloj.Shape = Enum.PartType.Cylinder
	local esfera = adorno("Reloj", Vector3.new(0.34, 2.8, 2.8), CFrame.new(oeste - 0.17, cuerpo - 3, z), Color3.fromRGB(76, 72, 60), Enum.Material.SmoothPlastic)
	esfera.Shape = Enum.PartType.Cylinder
	adorno("Aguja", Vector3.new(0.1, 1.1, 0.15), CFrame.new(oeste - 0.36, cuerpo - 3, z) * CFrame.Angles(math.rad(200), 0, 0)
		* CFrame.new(0, 0.5, 0), COLOR.Hierro, Enum.Material.Metal)
	adorno("Aguja", Vector3.new(0.1, 0.8, 0.15), CFrame.new(oeste - 0.36, cuerpo - 3, z) * CFrame.Angles(math.rad(-100), 0, 0)
		* CFrame.new(0, 0.35, 0), COLOR.Hierro, Enum.Material.Metal)
end

-- Lo propio de la iglesia (además del campanario): contrafuertes, rosetón y cruces en los hastiales, arco apuntado y
-- escalón en la puerta. En la pared oeste, junto a la puerta (z -504,6..-502,6), va clavada una pista: ahí no se pone
-- nada.
local function iglesia(e, cumbre: number)
	local _, hz = caja(e)
	local contrafuertes = { { "E", -6 }, { "E", 0 }, { "E", 6 }, { "E", -12.5 }, { "E", 12.5 }, { "O", 12.5 } }
	for _, c in contrafuertes do
		local f = PuebloPlano.LADOS[c[1]]
		-- Los del este, menos hondos: entre ellos y la valla del cementerio pasa el camino a su entrada (con 1,5 de fondo
		-- quedaban 1,8 studs y de frente no se cabía).
		local fondo = if c[1] == "E" then 0.6 else 1.5
		local base = enCara(e, c[1], c[2], 0, fondo / 2)
		local cf = CFrame.lookAt(base, base + f)
		solido("Contrafuerte", Vector3.new(1.2, 7, fondo), cf * CFrame.new(0, 3.5, 0), COLOR.Piedra, Enum.Material.Cobblestone)
		local w = Instance.new("WedgePart")
		w.Name = "Contrafuerte"
		w.Anchored = true
		w.CanCollide = false
		w.CanQuery = false
		w.CanTouch = false
		w.Size = Vector3.new(1.2, 2.6, fondo)
		w.CFrame = cf * CFrame.new(0, 8.3, 0)
		w.Color = COLOR.Piedra
		w.Material = Enum.Material.Cobblestone
		w.Parent = grupo
	end
	-- Rosetón de mentira en el hastial sur.
	local _, _, H0 = caja(e)
	local centro = Vector3.new(e.x, H0 + (cumbre - H0) * 0.38, e.z + hz + 0.15)
	local giro = CFrame.new(centro) * CFrame.Angles(0, math.pi / 2, 0)
	local aro = adorno("Roseton", Vector3.new(0.4, 5, 5), giro, COLOR.PiedraOscura, Enum.Material.Slate)
	aro.Shape = Enum.PartType.Cylinder
	local vidrio = adorno("Roseton", Vector3.new(0.46, 4, 4), giro, Color3.fromRGB(40, 18, 22), Enum.Material.Glass)
	vidrio.Shape = Enum.PartType.Cylinder
	vidrio.Reflectance = 0.1
	for k = 0, 3 do
		adorno("Plomo", Vector3.new(0.2, 4, 0.52), CFrame.new(centro) * CFrame.Angles(0, 0, k * math.pi / 4), COLOR.PiedraOscura, Enum.Material.Slate)
	end
	-- Cruces en lo alto de los dos hastiales.
	for _, g in { -1, 1 } do
		local cf = CFrame.new(e.x, cumbre + 2, e.z + g * (hz + 0.4))
		adorno("Cruz", Vector3.new(0.45, 3.2, 0.45), cf, COLOR.PiedraOscura, Enum.Material.Slate)
		adorno("Cruz", Vector3.new(2, 0.45, 0.45), cf * CFrame.new(0, 0.6, 0), COLOR.PiedraOscura, Enum.Material.Slate)
	end
	-- Arco apuntado sobre la puerta (no pasa de z -502,4: a su lado va la pista) y escalón de piedra.
	local cf = PuebloPlano.puertaCF(e)
	local fuera = cf.LookVector
	for _, lado in { -1, 1 } do
		barra("Arco", cf * Vector3.new(lado * 2.35, 8.4, -0.62), cf * Vector3.new(0, 10.6, -0.62), 0.55, 0.45, COLOR.PiedraOscura, Enum.Material.Slate,
			fuera)
	end
	-- De 0 a 0,75, entre la plaza (0,5) y el umbral (1): de 0,5 de alto su cara de arriba coincidía con la de la plaza y
	-- parpadeaban (las dos llevan SinSeparar).
	solido("Escalon", Vector3.new(6, 0.75, 1.6), cf * CFrame.new(0, -0.625, -1.3), COLOR.PiedraOscura, Enum.Material.Slate)
	-- Sangre seca en el muro, al otro lado de la puerta (lejos de la pista).
	sangre(enCara(e, "O", 3.4, 2.3, 0.06), fuera, 1.6, 1)
end

-- La cripta: frontón con su cornisa, pilastras a los lados de la reja, cruz y escalón.
local function cripta(e, cumbre: number)
	local hx, hz, H0 = caja(e)
	local cf = PuebloPlano.puertaCF(e)
	adorno("Cornisa", Vector3.new(0.9, 0.55, 2 * hz + 1.2), CFrame.new(e.x - hx - 0.25, H0 - 0.15, e.z), COLOR.PiedraClara, Enum.Material.Slate)
	for _, lado in { -1, 1 } do
		adorno("Pilastra", Vector3.new(0.6, H0 - 0.6, 0.9), CFrame.new(e.x - hx - 0.3, (H0 - 0.6) / 2, e.z + lado * 3.2), COLOR.PiedraClara, Enum.Material.Slate)
	end
	local cruz = CFrame.new(e.x - hx - 0.1, cumbre + 1.5, e.z)
	adorno("Cruz", Vector3.new(0.4, 2.4, 0.4), cruz, COLOR.PiedraOscura, Enum.Material.Slate)
	adorno("Cruz", Vector3.new(0.4, 0.4, 1.5), cruz * CFrame.new(0, 0.4, 0), COLOR.PiedraOscura, Enum.Material.Slate)
	solido("Escalon", Vector3.new(5.6, 0.5, 1.4), cf * CFrame.new(0, -0.75, -1.2), COLOR.PiedraOscura, Enum.Material.Slate)
	sangre(cf * Vector3.new(-1, -0.45, -1.4), Vector3.yAxis, 1.3, 3)
end

local function edificio(e, est)
	local hx, hz, H0 = caja(e)
	local aspecto = if e.material == "madera"
		then { color = est.color:Lerp(Color3.new(), 0.3), material = Enum.Material.WoodPlanks, tablas = true, tinta = est.color }
		elseif e.material == "ladrillo" then { color = est.color, material = Enum.Material.Brick }
		else { color = est.color, material = Enum.Material.Cobblestone }
	-- Suelo (sale en el mapa del móvil), paredes con sus huecos y techo plano por dentro.
	local piedra = e.material == "piedra"
	local piso = solido("Piso", Vector3.new(e.ancho, 1, e.largo), CFrame.new(e.x, 0.5, e.z), if piedra then COLOR.PiedraOscura else COLOR.Suelo,
		if piedra then Enum.Material.Slate else Enum.Material.WoodPlanks)
	piso:SetAttribute("SinSeparar", true) -- que Separar.caras no lo ensanche
	CollectionService:AddTag(piso, "EnMapa")
	local m = medidasVentana(e)
	for _, lado in { "N", "S", "E", "O" } do
		local huecos = {}
		if e.entra then
			if lado == e.puerta then
				table.insert(huecos, { u0 = -2, u1 = 2, y0 = 1, y1 = 9 })
			end
			for _, w in e.ventanas do
				if w.lado == lado then
					local y0 = PuebloPlano.SUELO + (w.planta - 1) * PuebloPlano.altoPlanta(e) + m.alfeizar
					table.insert(huecos, { u0 = w.desde - m.ancho / 2, u1 = w.desde + m.ancho / 2, y0 = y0, y1 = y0 + m.alto })
				end
			end
		end
		muro(e, lado, huecos, aspecto)
	end
	solido("Techo", Vector3.new(e.ancho - 1, 1, e.largo - 1), CFrame.new(e.x, 1.5 + e.alto, e.z), if piedra then COLOR.PiedraOscura else COLOR.Techo,
		if piedra then Enum.Material.Slate else Enum.Material.WoodPlanks)

	-- Tejado (y la chimenea).
	local ladoPorche = if est.porche then PuebloPlano.LADOS[e.puerta] else nil
	local cumbre = H0
	if est.tejado == "dos" then
		local alto, P, _, ha, hl = dosAguas(e, est, aspecto, ladoPorche)
		cumbre = alto
		if est.chimenea then
			local pos = P(ha * 0.4 * (if azar:NextNumber() < 0.5 then 1 else -1), 0, hl * 0.5)
			chimenea(pos, H0, cumbre + 2.2)
		end
	elseif est.tejado == "cuatro" then
		local ejeZ = hz >= hx
		local P, V = ejes(e.x, e.z, ejeZ)
		local A, B = math.min(hx, hz) + 1.2, math.max(hx, hz) + 1.2
		local ye = H0 - est.pendiente * 1.2
		local alto = est.pendiente * A
		cuatroAguas(P, V, A, B, ye, alto, COLOR.Teja, TEJAS)
		cumbre = ye + alto
		for _, s in { -1, 1 } do
			adorno("Alero", V(0.3, 1, 2 * B), CFrame.new(P(s * (A + 0.12), ye - 0.3, 0)), COLOR.Moldura)
			adorno("Alero", V(2 * A, 1, 0.3), CFrame.new(P(0, ye - 0.3, s * (B + 0.12))), COLOR.Moldura)
			if not (ladoPorche and ladoPorche:Dot(V(s, 0, 0)) > 0.9) then
				canalon(P, A + 0.45, ye - 0.75, B - 0.2, s, s > 0)
			end
		end
		if est.chimenea then
			chimenea(P(A * 0.3, 0, B * 0.35), H0, cumbre + 1)
		end
	else
		tienda(e, est)
	end

	-- Ventanas y puerta.
	for _, w in e.ventanas do
		if e.nombre == "Iglesia" then
			vidriera(e, w)
		else
			ventana(e, w)
		end
	end
	local puerta = if e.entra then puertaAbierta(e, est) else puertaTapiada(e, est)
	remates(e, est)
	if est.porche then
		porche(e)
	end
	abandono(e, est)

	-- Lo de cada uno.
	if e.nombre == "Iglesia" then
		iglesia(e, cumbre)
		campanario()
	elseif e.nombre == "Cripta" then
		cripta(e, cumbre)
	elseif e.nombre == "CasaCerrada3" then
		sangre(puerta * Vector3.new(0.7, -0.4, -1.12), puerta.LookVector, 1.8, 2) -- en los tablones de la puerta
	elseif e.nombre == "CasaFinal" then
		sangre(PuebloPlano.puertaCF(e) * Vector3.new(1.4, 0.03, -2.3), Vector3.yAxis, 2.2, 3) -- en el suelo del porche
	elseif e.nombre == "Tienda" then
		sangre(puerta * Vector3.new(-2.8, 1.6, -0.56), puerta.LookVector, 1.3, 1)
	elseif e.nombre == "CasaCerrada4" then
		local cf = PuebloPlano.ventanaCF(e, e.ventanas[3])
		sangre(cf * Vector3.new(0.3, -m.alto / 2 - 1.3, -0.56), cf.LookVector, 1.1, 2, 2.2) -- churretón bajo la ventana
	end
end

-- Puerta de cada uno de los que se entra (cómo está la hoja).
local PUERTA = {
	Tienda = { puerta = "abierta", bisagra = 1, angulo = 80 },
	CasaAbierta = { puerta = "caida" },
	Iglesia = { puerta = "doble" },
	Cripta = { puerta = "reja" },
	CasetaEnterrador = { puerta = "abierta", bisagra = -1, angulo = 62, caida = 0.07 },
}

function PuebloFachadas.construir(c)
	ctx = c
	for i, e in PuebloPlano.edificios do
		local est = table.clone(ESTILO[e.nombre] or { color = Color3.fromRGB(90, 84, 76), tejado = "dos", eje = "z", pendiente = 0.7 })
		for k, v in PUERTA[e.nombre] or {} do
			est[k] = v
		end
		azar = Random.new(1000 + i * 37) -- siempre igual: el pueblo sale idéntico en cada servidor
		local modelo = Instance.new("Model")
		modelo.Name = e.nombre
		modelo.Parent = ctx.carpeta
		grupo = modelo
		edificio(e, est)
	end
end

return PuebloFachadas
