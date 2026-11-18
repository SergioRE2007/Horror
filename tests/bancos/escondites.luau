-- Banco de los escondites de fuera de la casa: Mapa.armario (el armario de lamas de siempre, también dentro de
-- Mapa.conPadre) y los cuatro de Lugares y PuebloInteriores (la cocina de la granja, el granero, el confesionario de la
-- iglesia y el ropero de la casa abierta del pueblo). Carga Mapa, Lugares y el pueblo de verdad con el Roblox de mentira
-- (tests/bancos/_roblox.luau); los muebles de la tienda, con su tamaño de verdad (atributo Tam de src/muebles), para
-- que choquen sus cajas. Comprueba de cada escondite nuevo:
--   - que está dentro de su edificio y su Salida también (y libre: nada que choque donde aparece el jugador);
--   - que lo que choca de él no se mete en paredes, muebles ni bancos;
--   - que no pisa la puerta (ni el paso de delante) ni tapa una ventana del pueblo;
--   - que no tapa llaves, objetos, pesados ni pistas (shared/Pistas: sus sitios, sacados del texto);
--   - que tiene al lado algo que cuente lo que pasó (una calcomanía: arañazos o sangre seca).
-- Ejecutar desde la raíz: lune run tests/bancos/escondites.luau (lo corre regressions.luau).
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local crearMundo = require("./_roblox")

local cuentas = 0
local function comprueba(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end

local m = crearMundo({ servidor = true })
local g = m.global
-- Dos arreglos de @lune/roblox para este banco: Vector3.FromNormalId (lo usa PuebloFachadas) no está y CFrame.lookAt
-- falla (abajo).
do
	local V = roblox.Vector3
	local NORMALES = { Right = V.xAxis, Left = -V.xAxis, Top = V.yAxis, Bottom = -V.yAxis,
		Back = V.zAxis, Front = -V.zAxis }
	local real = g.Vector3
	g.Vector3 = setmetatable({ FromNormalId = function(n)
		return NORMALES[n.Name]
	end }, { __index = real })
	-- CFrame.lookAt de @lune/roblox 0.10.5 da la vuelta a la z de la mirada (hacia +z mira a -z): uno como el de Roblox.
	local C = g.CFrame
	g.CFrame = setmetatable({ lookAt = function(desde, hacia, arriba)
		local mira = (hacia - desde).Unit
		local derecha = mira:Cross(arriba or V.yAxis)
		derecha = if derecha.Magnitude > 1e-6 then derecha.Unit else V.xAxis
		return C.fromMatrix(desde, derecha, derecha:Cross(mira))
	end }, { __index = C })
end
local Instance, Vector3 = g.Instance, g.Vector3
local CollectionService = m.game:GetService("CollectionService")

-- Los muebles de la tienda (ServerStorage.Muebles): un molde vacío con su Tam por cada uno de src/muebles.
do
	local muebles = Instance.new("Folder")
	muebles.Name = "Muebles"
	for _, archivo in fs.readDir("src/muebles") do
		if string.match(archivo, "%.rbxm$") then
			local sala = Instance.new("Folder")
			sala.Name = string.gsub(archivo, "%.rbxm$", "")
			for _, raiz in roblox.deserializeModel(fs.readFile("src/muebles/" .. archivo)) do
				for _, molde in raiz:GetChildren() do
					local tam = molde:GetAttribute("Tam")
					if molde.ClassName == "Model" and typeof(tam) == "Vector3" and not sala:FindFirstChild(molde.Name) then
						local falso = Instance.new("Model")
						falso.Name = molde.Name
						falso:SetAttribute("Tam", tam)
						falso.Parent = sala
					end
				end
			end
			sala.Parent = muebles
		end
	end
	muebles.Parent = m.game:GetService("ServerStorage")
end

local Mapa = m.cargar("src/juego/servidor/Mapa", {
	Separar = { caras = function()
		return 0
	end },
	Bichos3D = { copia = function()
		return nil
	end },
	Fachada = { pared = function() end, ventana = function() end },
})
local Lugares = m.cargar("src/juego/servidor/Lugares")
local Plano = m.cargar("src/juego/servidor/PuebloPlano")

-- Mapa.armario, en el padre de conPadre ----------------------------------------------------------------------------
do
	comprueba(type(Mapa.armario) == "function", "Mapa.armario existe")
	local prueba = Instance.new("Folder")
	prueba.Name = "Prueba"
	prueba.Parent = m.workspace
	for _, aspecto in { false, "Aperos", "Confesionario" } do
		local modelo
		Mapa.conPadre(prueba, function()
			modelo = Mapa.armario(Vector3.new(500, 5, 500), Vector3.zAxis, aspecto or nil)
		end)
		local nombre = tostring(aspecto)
		comprueba(modelo and modelo.Parent == prueba, `armario {nombre}: cuelga del padre de conPadre`)
		comprueba(CollectionService:HasTag(modelo, "Escondite"), `armario {nombre}: etiqueta Escondite`)
		for _, at in { "Dentro", "Vista", "Salida" } do
			comprueba(typeof(modelo:GetAttribute(at)) == "CFrame", `armario {nombre}: atributo {at}`)
		end
		comprueba(modelo:GetAttribute("Ocupado") == 0 and modelo:GetAttribute("Tipo") == "Armario", `armario {nombre}: Ocupado y Tipo`)
		comprueba(modelo:FindFirstChild("Mando") ~= nil, `armario {nombre}: Mando para el prompt`)
		-- Las lamas como las busca EsconditeVista (para abrir las hojas): "Armario", finas y anchas.
		local lamas = 0
		for _, p in modelo:GetChildren() do
			if p:IsA("BasePart") and p.Name == "Armario" and p.Size.Z < 0.2 and p.Size.Y < 0.28 and p.Size.X > 2 then
				lamas += 1
			end
		end
		comprueba(lamas == 19, `armario {nombre}: 19 lamas (hay {lamas})`)
		local salida = modelo:GetAttribute("Salida").Position
		comprueba(math.abs((salida - Vector3.new(500, 4, 503.5)).Magnitude) < 0.01, `armario {nombre}: sale 3,5 por delante`)
	end
	prueba:Destroy()
end

-- Los escondites de fuera ------------------------------------------------------------------------------------------
local mapa = Instance.new("Folder")
mapa.Name = "Mapa"
mapa.Parent = m.workspace
-- El suelo del bosque (como Mapa: de y = -2 a 0), para que los agujeros de la granja y el aserradero lo recorten.
do
	local bosque = Instance.new("Folder")
	bosque.Name = "Bosque"
	bosque.Parent = mapa
	local suelo = Instance.new("Part")
	suelo.Name = "Suelo"
	suelo.Anchored = true
	suelo.Size = Vector3.new(1600, 2, 1600)
	suelo.CFrame = g.CFrame.new(0, -1, 0)
	suelo.Parent = bosque
end
Lugares.construir(mapa, Mapa)

-- Caja alineada con los ejes de una pieza (con su giro): centro y medio tamaño.
local function caja(p: any): (any, any)
	local cf, h = p.CFrame, p.Size / 2
	local x, y, z = cf.RightVector, cf.UpVector, cf.LookVector
	local function eje(a: number, b: number, c: number): number
		return math.abs(a) * h.X + math.abs(b) * h.Y + math.abs(c) * h.Z
	end
	return cf.Position, Vector3.new(eje(x.X, y.X, z.X), eje(x.Y, y.Y, z.Y), eje(x.Z, y.Z, z.Z))
end
local function solapan(c1: any, h1: any, c2: any, h2: any, margen: number?): boolean
	local d, s = c1 - c2, h1 + h2 - Vector3.one * (margen or 0)
	return math.abs(d.X) < s.X and math.abs(d.Y) < s.Y and math.abs(d.Z) < s.Z
end

-- Lo que choca en el mapa (paredes, suelos, muebles, bancos y las cajas Choque de la tienda).
local solidos = {}
for _, p in mapa:GetDescendants() do
	if p:IsA("BasePart") and p.CanCollide then
		table.insert(solidos, p)
	end
end

-- Los sitios de las pistas (shared/Pistas: enMesa(x, y, z, …) y enPared(Vector3.new(x, y, z), …)).
local pistas = {}
do
	local fuente = fs.readFile("src/juego/servidor/Pistas.luau")
	for x, y, z in string.gmatch(fuente, "enMesa%((%-?[%d%.]+), (%-?[%d%.]+), (%-?[%d%.]+),") do
		table.insert(pistas, Vector3.new(tonumber(x), tonumber(y), tonumber(z)))
	end
	for x, y, z in string.gmatch(fuente, "enPared%(Vector3%.new%((%-?[%d%.]+), (%-?[%d%.]+), (%-?[%d%.]+)%)") do
		table.insert(pistas, Vector3.new(tonumber(x), tonumber(y), tonumber(z)))
	end
	comprueba(#pistas >= 12, `pistas: sus sitios salen del texto ({#pistas})`)
end
local cosas = {} -- { nombre, punto }
for zona, lista in Mapa.llaves do
	for _, cf in lista do
		table.insert(cosas, { `llave de {zona}`, cf.Position })
	end
end
for _, o in Mapa.objetos do
	table.insert(cosas, { o.tipo, o.cf.Position })
end
for _, o in Mapa.pesados do
	table.insert(cosas, { o.tipo, o.cf.Position })
end
for i, p in pistas do
	table.insert(cosas, { `pista {i}`, p })
end

-- Los edificios: lo de dentro (x1, x2, z1, z2), la puerta ("N" -z, "S" +z, "E" +x, "O" -x) y las ventanas. Los de la
-- granja, de Lugares.EDIFICIOS (con fachada, como los del pueblo).
type Edificio = { nombre: string, x1: number, x2: number, z1: number, z2: number, puerta: string, ancho: number, cx: number,
	cz: number,
	ventanas: { { lado: string, en: number, ancho: number, y1: number, y2: number } } }
local function edificio(nombre: string): Edificio
	local e = Lugares.EDIFICIOS[nombre] or Plano.buscar(nombre)
	local x1, x2, z1, z2 = Plano.dentro(e)
	local med = if nombre == "Iglesia" then Plano.VENTANA_IGLESIA else Plano.VENTANA
	local ventanas = {}
	for _, w in e.ventanas do
		local y1 = Plano.SUELO + (w.planta - 1) * Plano.altoPlanta(e) + med.alfeizar
		local en = if w.lado == "N" or w.lado == "S" then e.x + w.desde else e.z + w.desde
		table.insert(ventanas, { lado = w.lado, en = en, ancho = med.ancho, y1 = y1, y2 = y1 + med.alto })
	end
	return { nombre = nombre, x1 = x1, x2 = x2, z1 = z1, z2 = z2, puerta = e.puerta, ancho = Plano.PUERTA.ancho, cx = e.x,
		cz = e.z, ventanas = ventanas } :: any
end
local EDIFICIOS = {
	edificio("CasaGranja"),
	edificio("Granero"),
	edificio("Iglesia"),
	edificio("CasaAbierta"),
}

-- La zona de un hueco de pared vista desde dentro: `en` a lo largo de la pared, `hondo` studs hacia dentro.
local function zonaHueco(e: any, lado: string, en: number, ancho: number, y1: number, y2: number, hondo: number): (any, any)
	local y = (y1 + y2) / 2
	if lado == "N" then
		return Vector3.new(en, y, e.z1 + hondo / 2), Vector3.new(ancho / 2, (y2 - y1) / 2, hondo / 2)
	elseif lado == "S" then
		return Vector3.new(en, y, e.z2 - hondo / 2), Vector3.new(ancho / 2, (y2 - y1) / 2, hondo / 2)
	elseif lado == "E" then
		return Vector3.new(e.x2 - hondo / 2, y, en), Vector3.new(hondo / 2, (y2 - y1) / 2, ancho / 2)
	end
	return Vector3.new(e.x1 + hondo / 2, y, en), Vector3.new(hondo / 2, (y2 - y1) / 2, ancho / 2)
end

local lugares = mapa:FindFirstChild("Lugares")
comprueba(lugares ~= nil, "Lugares cuelga su carpeta del mapa")
local nuevos = {}
for _, sitio in CollectionService:GetTagged("Escondite") do
	if sitio:IsDescendantOf(lugares) then
		table.insert(nuevos, sitio)
	end
end
comprueba(#nuevos == #EDIFICIOS, `fuera de la casa hay {#EDIFICIOS} escondites (hay {#nuevos})`)

local calcomanias = {}
for _, d in mapa:GetDescendants() do
	if d:IsA("Decal") and d.Parent and d.Parent:IsA("BasePart") then
		table.insert(calcomanias, d.Parent.Position)
	end
end

for _, e in EDIFICIOS do
	local nombre = e.nombre
	local sitio
	for _, s in nuevos do
		local p = s.Mando.Position
		if p.X > e.x1 and p.X < e.x2 and p.Z > e.z1 and p.Z < e.z2 then
			sitio = s
		end
	end
	comprueba(sitio ~= nil, `{nombre}: tiene su escondite dentro`)
	local partes, choca = {}, {}
	for _, p in sitio:GetDescendants() do
		if p:IsA("BasePart") and p.Name ~= "Mando" then
			table.insert(partes, p)
			if p.CanCollide then
				table.insert(choca, p)
			end
		end
	end
	-- Dentro del edificio, entero (con lo que solo se ve) y sin meterse en lo que choca.
	for _, p in partes do
		local c, h = caja(p)
		assert(c.X - h.X > e.x1 - 0.25 and c.X + h.X < e.x2 + 0.25 and c.Z - h.Z > e.z1 - 0.25 and c.Z + h.Z < e.z2 + 0.25,
			`{nombre}: {p.Name} no se sale del edificio`)
	end
	for _, p in choca do
		local c, h = caja(p)
		for _, s in solidos do
			if not s:IsDescendantOf(sitio) and s.Name ~= "Piso" then
				local c2, h2 = caja(s)
				assert(not solapan(c, h, c2, h2, 0.05), `{nombre}: {p.Name} no se mete en {s.Name} ({s:GetFullName()})`)
			end
		end
	end

	-- La Salida: dentro del edificio y libre (el cuerpo, de los pies a la cabeza, sin nada que choque).
	local salida = sitio:GetAttribute("Salida").Position
	comprueba(salida.X > e.x1 + 1 and salida.X < e.x2 - 1 and salida.Z > e.z1 + 1 and salida.Z < e.z2 - 1,
		`{nombre}: la Salida queda dentro del edificio`)
	local cuerpo, medio = salida - Vector3.new(0, 0.3, 0), Vector3.new(1, 2.5, 1)
	for _, s in solidos do
		if s.Name ~= "Piso" then
			local c2, h2 = caja(s)
			assert(not solapan(cuerpo, medio, c2, h2, 0.02), `{nombre}: la Salida choca con {s:GetFullName()}`)
		end
	end
	local suelo = sitio:GetAttribute("Dentro").Position.Y - 3
	comprueba(math.abs(suelo - (salida.Y - 3)) < 0.01 and suelo >= 1 and suelo < 1.2, `{nombre}: la Salida, a ras del suelo`)

	-- Ni la puerta ni el paso de delante (su ancho y 0,4 a cada lado, 5 hacia dentro), ni las ventanas (1,5 hacia
	-- dentro).
	local enPuerta = if e.puerta == "N" or e.puerta == "S" then e.cx else e.cz
	local cp, hp = zonaHueco(e, e.puerta, enPuerta, e.ancho + 0.8, 1, 9, 5)
	for _, p in partes do
		local c, h = caja(p)
		assert(not solapan(c, h, cp, hp, 0.01), `{nombre}: {p.Name} no estorba la puerta ({c - h} .. {c + h})`)
		for _, w in e.ventanas do
			local cw, hw = zonaHueco(e, w.lado, w.en, w.ancho, w.y1, w.y2, 1.5)
			assert(not solapan(c, h, cw, hw, 0.01), `{nombre}: {p.Name} no tapa la ventana {w.lado} {w.en}`)
		end
	end

	-- Llaves, objetos, pesados y pistas: ni dentro ni pegados (a menos de 0,8).
	for _, cosa in cosas do
		for _, p in partes do
			local c, h = caja(p)
			assert(not solapan(c, h + Vector3.one * 0.8, cosa[2], Vector3.zero), `{nombre}: {p.Name} tapa {cosa[1]}`)
		end
		assert((cosa[2] - salida).Magnitude > 1.2 or cosa[2].Y > salida.Y + 1, `{nombre}: la Salida cae encima de {cosa[1]}`)
	end

	-- (Lo de arriba, con assert: miles de pares; cuenta como uno por cosa mirada.)
	cuentas += 6

	-- Algo que cuente lo que pasó: arañazos o sangre seca cerca (a menos de 5 studs de la Salida).
	local cerca = 0
	for _, p in calcomanias do
		if (p - salida).Magnitude < 5 then
			cerca += 1
		end
	end
	comprueba(cerca >= 2, `{nombre}: tiene al lado lo que cuenta lo que pasó ({cerca} calcomanías)`)
end

-- El Acechador espera junto a los escondites de fuera (Config.Acechador).
do
	local A = m.cargar("src/shared/Config").Acechador
	comprueba(type(A.Aguarda) == "number" and A.Aguarda > 0, "Acechador: Aguarda")
	comprueba(type(A.AguardaLejos) == "number" and A.AguardaLejos > A.Pillar + 2, "Acechador: espera más lejos de lo que pilla")
	comprueba(type(A.Aguardas) == "number" and A.Aguardas >= 1, "Acechador: Aguardas")
end

comprueba(#m.errores == 0, `sin errores en el mundo: {table.concat(m.errores, "\n")}`)
print(`escondites: {cuentas} comprobaciones bien`)
