-- Banco de los sitios del bosque (Lugares): la casa de la granja, el granero, la oficina del aserradero y la caseta
-- del guarda con fachadas de verdad (PuebloFachadas.uno) y su historia. Carga Lugares de verdad (con PuebloFachadas,
-- PuebloInteriores y PuebloCalle) en el Roblox de mentira (tests/bancos/_roblox.luau), con un Mapa falso que pone cada
-- mueble como una caja de su tamaño (atributo Tam de src/muebles) y su caja de choque, como Mapa.mueble. Mira:
--   - que se construye sin errores ni avisos, y que todo mueble y mancha va dentro de Mapa.conPadre;
--   - las pistas 6, 7 y 8 (sitios de Pistas.luau): la mesa de la granja con la cara de arriba a 4,02, la pared de la
--     oficina a x = -255,5 sin nada delante y la mesa de arriba de la torre;
--   - cada llave y cada objeto de la granja, el aserradero y la torre, encima de algo que choca y no metido en nada;
--   - los dos agujeros (granero y aserradero): hondos (sin suelo hasta el fondo, a -1,5) y con una tapa que choca a
--     ras del suelo (nadie se cae);
--   - las puertas de los cuatro edificios, libres para pasar;
--   - el sitio del depósito de gasoil (5 studs alrededor de (212, 98)) sin nada nuevo.
-- Ejecutar desde la raíz: lune run tests/bancos/lugares.luau (lo corre regressions.luau).
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local crearMundo = require("./_roblox")

local cuentas = 0
local function comprueba(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end

-- Tamaños de los muebles: el atributo Tam de cada molde de src/muebles (como los lee Mapa).
local TAM: { [string]: any } = {}
for _, archivo in fs.readDir("src/muebles") do
	if string.match(archivo, "%.rbxm$") then
		for _, raiz in roblox.deserializeModel(fs.readFile("src/muebles/" .. archivo)) do
			for _, molde in raiz:GetChildren() do
				local t = molde:GetAttribute("Tam")
				if t then
					TAM[molde.Name] = t
				end
			end
		end
	end
end
comprueba(TAM.MesaCocina and TAM.EstanteriaMetalPH, "muebles: se leen sus tamaños")

local m = crearMundo({ servidor = true })
local g = m.global
local Instance, Vector3 = g.Instance, g.Vector3
-- Vector3.FromNormalId no está en @lune/roblox (lo usa PuebloFachadas).
local NORMALES = { Right = Vector3.xAxis, Left = -Vector3.xAxis, Top = Vector3.yAxis, Bottom = -Vector3.yAxis, Back = Vector3.zAxis,
	Front = -Vector3.zAxis }
g.Vector3 = setmetatable({ FromNormalId = function(n)
	return NORMALES[n.Name]
end }, { __index = Vector3 })
-- CFrame.lookAt de @lune/roblox gira mal si se mira algo hacia arriba o hacia abajo (y en vertical da NaN): el de
-- Roblox, hecho con CFrame.fromMatrix (en vertical, como cualquier giro alrededor del eje).
local CFrameLune = g.CFrame
local function lookAt(desde: any, hacia: any, arriba: any?): any
	local z = (desde - hacia).Unit
	local x = (arriba or Vector3.yAxis):Cross(z)
	if x.Magnitude < 1e-6 then
		x = (if math.abs(z.Z) < 0.9 then Vector3.zAxis else Vector3.xAxis):Cross(z)
	end
	x = x.Unit
	return CFrameLune.fromMatrix(desde, x, z:Cross(x), z)
end
g.CFrame = setmetatable({ lookAt = lookAt }, { __index = CFrameLune })
local CFrame = g.CFrame

-- El Mapa falso: lo que Lugares y Pueblo* usan de él.
local actual: any = nil -- el padre de lo que se crea dentro de Mapa.conPadre
local Mapa: any = { llaves = {}, objetos = {}, pesados = {}, SANGRE = { "a", "b", "c" }, MUEBLES = {} }
for nombre, t in TAM do
	Mapa.MUEBLES[nombre] = { GetAttribute = function()
		return t
	end }
end
function Mapa.conPadre(padre: any, fn: () -> ())
	local antes = actual
	actual = padre
	local ok, err = pcall(fn)
	actual = antes
	if not ok then
		error(err, 0)
	end
end
local function pieza(nombre: string, tam: any, cf: any, padre: any, choca: boolean): any
	local p = Instance.new("Part")
	p.Name = nombre
	p.Anchored = true
	p.Size = tam
	p.CFrame = cf
	p.CanCollide = choca
	p.CanQuery = false
	p.Parent = padre
	return p
end
function Mapa.mueble(nombre: string, cf: any, sinChoque: boolean?): any
	local t = TAM[nombre]
	if not t then
		return nil
	end
	assert(actual, `Mapa.mueble("{nombre}") fuera de Mapa.conPadre: se colgaría de la casa`)
	local modelo = Instance.new("Model")
	modelo.Name = nombre
	pieza("Malla", t, cf * CFrame.new(0, t.Y / 2, 0), modelo, false)
	modelo.WorldPivot = cf
	modelo.Parent = actual
	if not sinChoque then
		pieza("Choque", t * Vector3.new(0.9, 1, 0.9), cf * CFrame.new(0, t.Y / 2, 0), actual, true).Transparency = 1
	end
	return modelo
end
function Mapa.contraPared(nombre: string, x: number, y: number, z: number, frente: any, sinChoque: boolean?): any
	local t = TAM[nombre]
	if not t then
		return nil
	end
	local pos = Vector3.new(x, y, z) + frente * (t.Z / 2 + 0.05)
	return Mapa.mueble(nombre, CFrame.lookAt(pos, pos + frente), sinChoque)
end
function Mapa.mancha(pos: any, normal: any, tam: number, _imagen: string, _color: any, giro: number, alto: number?)
	assert(actual, "Mapa.mancha fuera de Mapa.conPadre: se colgaría de la casa")
	local cf = CFrame.lookAt(pos, pos + normal) * CFrame.Angles(0, 0, giro)
	pieza("Mancha", Vector3.new(tam, alto or tam, 0.04), cf, actual, false).Transparency = 1
end
-- Los armarios de lamas de los escondites (Mapa.armario): una caja de su tamaño que choca, con la Salida delante.
Mapa.MARCAS = { Aranazos = "x" }
function Mapa.armario(centro: any, frente: any): any
	assert(actual, "Mapa.armario fuera de Mapa.conPadre: se colgaría de la casa")
	local modelo = Instance.new("Model")
	modelo.Name = "Armario"
	local cf = CFrame.lookAt(centro, centro + frente)
	pieza("Armario", Vector3.new(4.6, 8, 3), cf, modelo, true)
	modelo:SetAttribute("Salida", CFrame.new(centro - Vector3.new(0, 1, 0) + frente * 3.5))
	modelo.Parent = actual
	return modelo
end
function Mapa.variante() end
function Mapa.arbol(x: number, z: number, alto: number, grueso: number, padre: any)
	pieza("Tronco", Vector3.new(grueso, alto, grueso), CFrame.new(x, alto / 2, z), padre, true)
end

-- El mapa con el suelo del bosque en dos trozos (como Mapa: el suelo, de y = -2 a 0, en trozos).
local mapa = Instance.new("Folder")
mapa.Name = "Mapa"
mapa.Parent = m.workspace
local bosque = Instance.new("Folder")
bosque.Name = "Bosque"
bosque.Parent = mapa
for _, r in { { -800, 3.5 }, { 3.5, 800 } } do
	pieza("Suelo", Vector3.new(r[2] - r[1], 2, 1600), CFrame.new((r[1] + r[2]) / 2, -1, 0), bosque, true)
end

local Lugares = m.cargar("src/juego/servidor/Lugares")
Lugares.construir(mapa, Mapa)
m.correr(0.1)
comprueba(#m.errores == 0, "construir: sin errores\n" .. table.concat(m.errores, "\n"))
comprueba(#m.avisos == 0, "construir: sin avisos\n" .. table.concat(m.avisos, "\n"))
local lugares = mapa:FindFirstChild("Lugares")
comprueba(lugares, "construir: la carpeta Lugares")
for _, nombre in { "CasaGranja", "Granero", "Oficina", "CasetaGuarda" } do
	local e = lugares:FindFirstChild(nombre)
	comprueba(e and e:IsA("Model") and e:FindFirstChild("Tejado") and e:FindFirstChild("Cristal"), `{nombre}: con fachada (tejado y ventanas)`)
end

-- Cajas de lo que choca (para la física: aunque CanQuery sea false), alineadas con los ejes; las bolas (la colina de la
-- torre), como bolas.
type Caja = { p: any, min: any, max: any, radio: number? }
local function cajaDe(d: any): Caja
	local cf, s = d.CFrame, d.Size / 2
	if d:IsA("Part") and d.Shape == g.Enum.PartType.Ball then
		local r = math.min(s.X, s.Y, s.Z)
		return { p = d, min = cf.Position - Vector3.one * r, max = cf.Position + Vector3.one * r, radio = r }
	end
	local mn, mx = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local w = cf * Vector3.new(sx * s.X, sy * s.Y, sz * s.Z)
				mn, mx = mn:Min(w), mx:Max(w)
			end
		end
	end
	return { p = d, min = mn, max = mx }
end
-- ¿Toca la bola de `c` la caja de `a` a `b`?
local function tocaBola(c: Caja, a: any, b: any): boolean
	local centro = (c.min + c.max) / 2
	local cerca = centro:Max(a):Min(b)
	return (cerca - centro).Magnitude < (c.radio :: number)
end
local chocan: { Caja } = {}
local visibles: { Caja } = {}
for _, raiz in { lugares, bosque } do
	for _, d in raiz:GetDescendants() do
		if d:IsA("BasePart") then
			if d.CanCollide then
				table.insert(chocan, cajaDe(d))
			end
			if d.Transparency < 1 then
				table.insert(visibles, cajaDe(d))
			end
		end
	end
end

-- Lo más alto que choca debajo de (x, z) con la cara de arriba por debajo de `y`.
local function soporte(x: number, z: number, y: number): (number?, any?)
	local mejor, cual = nil, nil
	for _, c in chocan do
		local arriba = c.max.Y
		if c.radio then
			local centro = (c.min + c.max) / 2
			local d2 = (x - centro.X) ^ 2 + (z - centro.Z) ^ 2
			arriba = if d2 < c.radio ^ 2 then centro.Y + math.sqrt(c.radio ^ 2 - d2) else -math.huge
		end
		if c.min.X <= x and x <= c.max.X and c.min.Z <= z and z <= c.max.Z and arriba <= y and (not mejor or arriba > mejor) then
			mejor, cual = arriba, c.p
		end
	end
	return mejor, cual
end
local function dentroDe(lista: { Caja }, a: any, b: any, saltar: ((any) -> boolean)?): any?
	for _, c in lista do
		if c.min.X < b.X and a.X < c.max.X and c.min.Y < b.Y and a.Y < c.max.Y and c.min.Z < b.Z and a.Z < c.max.Z
			and not (c.radio and not tocaBola(c, a, b)) and not (saltar and saltar(c.p)) then
			return c.p
		end
	end
	return nil
end

-- Pistas 6, 7 y 8: sus sitios, leídos de Pistas.luau.
local pistas = fs.readFile("src/juego/servidor/Pistas.luau")
local function sitio(n: number): (number, number, number)
	local linea = string.match(pistas, `([^\n]*)%-%- {n}%. `)
	assert(linea, `pista {n}: no encuentro su sitio en Pistas.luau`)
	local x, y, z = string.match(linea, "(%-?[%d%.]+), (%-?[%d%.]+), (%-?[%d%.]+)")
	return tonumber(x) :: number, tonumber(y) :: number, tonumber(z) :: number
end
do
	local x, y, z = sitio(6)
	local arriba, mesa = soporte(x, z, y + 0.03)
	comprueba(arriba and math.abs(arriba - 4.02) < 0.03, `pista 6: la mesa de la granja con la cara de arriba a 4,02 ({arriba})`)
	comprueba(mesa and mesa:IsDescendantOf(lugares.CasaGranja), "pista 6: la mesa es de la casa de la granja")
	local tapa = dentroDe(visibles, Vector3.new(x - 0.4, y + 0.03, z - 0.5), Vector3.new(x + 0.4, y + 0.3, z + 0.5))
	comprueba(not tapa, `pista 6: nada encima del papel ({tapa and tapa:GetFullName()})`)
end
do
	local x, y, z = sitio(7)
	local pared = nil
	for _, c in chocan do
		if c.min.X <= x - 0.1 and x - 0.1 <= c.max.X and c.min.Y <= y and y <= c.max.Y and c.min.Z <= z and z <= c.max.Z then
			pared = c
		end
	end
	comprueba(pared and math.abs(pared.max.X - -255.5) < 0.02 and pared.p:IsDescendantOf(lugares.Oficina),
		`pista 7: la pared de dentro de la oficina a x = -255,5 ({pared and pared.max.X})`)
	local tapa = dentroDe(visibles, Vector3.new(x + 0.01, y - 0.4, z - 0.45), Vector3.new(x + 0.6, y + 0.4, z + 0.45))
	comprueba(not tapa, `pista 7: nada delante de la foto ({tapa and tapa:GetFullName()})`)
end
do
	local x, y, z = sitio(8)
	local arriba = soporte(x, z, y + 0.03)
	comprueba(arriba and math.abs(arriba - 47.5) < 0.03, `pista 8: la mesa de arriba de la torre ({arriba})`)
end

-- Llaves y objetos de la granja, el aserradero y la torre: encima de algo (a menos de 1,2) y sin nada que choque donde
-- están.
local ZONAS = { { 205, 75, 55 }, { -232, -86, 45 }, { 90, 285, 70 } }
local function enZona(p: any): boolean
	for _, zona in ZONAS do
		if (p.X - zona[1]) ^ 2 + (p.Z - zona[2]) ^ 2 < zona[3] ^ 2 then
			return true
		end
	end
	return false
end
local sitios = {}
for zona, lista in Mapa.llaves do
	for i, cf in lista do
		table.insert(sitios, { `llave {zona} {i}`, cf.Position })
	end
end
for i, o in Mapa.objetos do
	table.insert(sitios, { `{o.tipo} {i}`, o.cf.Position })
end
for i, p in Mapa.pesados do
	table.insert(sitios, { `{p.tipo} {i}`, p.cf.Position })
end
local mirados = 0
for _, s in sitios do
	local nombre, pos = s[1], s[2]
	if enZona(pos) then
		mirados += 1
		local arriba, debajo = soporte(pos.X, pos.Z, pos.Y - 0.12)
		comprueba(arriba and pos.Y - arriba < 1.25, `{nombre} en {pos}: encima de algo (a {arriba and pos.Y - arriba})`)
		local metido = dentroDe(chocan, pos - Vector3.new(0.05, 0.05, 0.05), pos + Vector3.new(0.05, 0.05, 0.05))
		comprueba(not metido, `{nombre} en {pos}: metido en {metido and metido:GetFullName()} (encima de {debajo and debajo:GetFullName()})`)
	end
end
comprueba(mirados == 23, `llaves, objetos y pesados de los tres sitios: 23 (salen {mirados})`)

-- Los agujeros: tapa que choca a ras del suelo y hondos (ni el piso, ni su forro, ni el suelo del bosque por encima del
-- fondo, a -1,5).
for _, h in { { "granero", 234.9, 80.9, 1.06, lugares.Granero }, { "aserradero", -241.5, -73.5, 0.15, lugares.Oficina } } do
	local nombre, x, z, y = h[1], h[2], h[3], h[4]
	local arriba, tapa = soporte(x, z, y + 0.02)
	comprueba(arriba and math.abs(arriba - y) < 0.02 and tapa.Name == "Tapa", `agujero del {nombre}: la tapa, a ras del suelo ({arriba})`)
	comprueba(tapa.Transparency == 1 and not tapa.CanQuery, `agujero del {nombre}: la tapa no se ve ni tapa rayos`)
	local suelo = dentroDe(visibles, Vector3.new(x - 0.3, -1.4, z - 0.3), Vector3.new(x + 0.3, y - 0.05, z + 0.3), function(p)
		return p.Name ~= "Suelo" and p.Name ~= "Piso"
	end)
	comprueba(not suelo, `agujero del {nombre}: hondo (tapado por {suelo and suelo:GetFullName()})`)
	local fondo = soporte(x, z, -1.45)
	comprueba(fondo and math.abs(fondo - -1.5) < 0.02, `agujero del {nombre}: tierra debajo del fondo ({fondo})`)
	comprueba(h[5]:FindFirstChild("Fondo"), `agujero del {nombre}: el fondo oscuro`)
end

-- Puertas: de 2,5 fuera a 2,5 dentro, 3,4 de ancho y de 1,2 a 7,8 de alto, nada que choque.
local PuebloPlano = m.cargar("src/juego/servidor/PuebloPlano")
for _, e in {
	{ nombre = "CasaGranja", x = 196, z = 52, ancho = 16, largo = 12, puerta = "O" },
	{ nombre = "Granero", x = 228, z = 80, ancho = 20, largo = 24, puerta = "O" },
	{ nombre = "Oficina", x = -252, z = -74, ancho = 8, largo = 8, puerta = "E" },
	{ nombre = "CasetaGuarda", x = 90, z = 238, ancho = 8, largo = 8, puerta = "N" },
} do
	local cf = PuebloPlano.puertaCF(e :: any)
	local a, b = cf * Vector3.new(-1.7, 0.2, -2.5), cf * Vector3.new(1.7, 6.8, 2.5)
	local estorba = dentroDe(chocan, a:Min(b), a:Max(b))
	comprueba(not estorba, `{e.nombre}: la puerta, libre ({estorba and estorba:GetFullName()})`)
end

-- El sitio del depósito de gasoil (otra tarea): nada a menos de 5 de (212, 98) salvo el campo de siempre. Y ninguna
-- pieza con NaN.
do
	local rotas, estorban = {}, {}
	for _, d in lugares:GetDescendants() do
		if d:IsA("BasePart") then
			if m.roto(d.CFrame) or m.roto(d.Size) then
				table.insert(rotas, d:GetFullName())
			elseif not d:IsDescendantOf(lugares.Pueblo) and d.Name ~= "Campo" and d.Name ~= "Surco" then
				local c = cajaDe(d)
				local dx = math.max(c.min.X - 212, 0, 212 - c.max.X)
				local dz = math.max(c.min.Z - 98, 0, 98 - c.max.Z)
				if dx * dx + dz * dz < 25 then
					table.insert(estorban, d:GetFullName())
				end
			end
		end
	end
	comprueba(#rotas == 0, "piezas con NaN:\n" .. table.concat(rotas, "\n"))
	comprueba(#estorban == 0, "depósito de gasoil: se meten en su sitio\n" .. table.concat(estorban, "\n"))
end

-- Sin caras que parpadeen (Mapa avisa "quedan N caras que parpadean"): Separar.caras de verdad sobre lo construido.
local Separar = m.cargar("src/comun/servidor/Separar")
local quedan = Separar.caras(mapa)
comprueba(quedan == 0, `Separar: quedan {quedan} caras que parpadean`)

print(`lugares: {cuentas} comprobaciones bien`)
