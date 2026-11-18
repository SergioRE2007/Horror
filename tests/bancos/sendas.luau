-- Banco de las sendas del bosque (MapaSendas). Ejecutar desde la raíz: lune run tests/bancos/sendas.luau (lo corre
-- tests/regressions.luau). Los trazados son datos puros: se carga el módulo de verdad sin Roblox.
--   Cada senda empieza en el claro de detrás de la casa o en la carretera y acaba en su zona (Lugares), junto a su
--   puerta, nave o escalera; no pasa por la casa, el lavadero, el cobertizo, el garaje, el hueco del sótano, la
--   trampilla, la casa de la granja, la caseta del guarda ni a menos de 5 del depósito (212, 98); tramos de no más
--   de 10; y `cerca` dice que sí encima y al lado de una senda y que no lejos.
-- Si algo no se cumple, termina con error.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local cuentas = 0
local function comprueba(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end

local MapaSendas = luau.load(fs.readFile("src/juego/servidor/MapaSendas.luau"), { debugName = "MapaSendas" })()
local MEDIO = MapaSendas.ANCHO[2] / 2

-- Las zonas, leídas de Lugares (si cambian allí, el banco las sigue).
local lugares = fs.readFile("src/juego/servidor/Lugares.luau")
local function zona(nombre: string): { number }
	local x, z, r = string.match(lugares, nombre .. " = { (%-?[%d%.]+), (%-?[%d%.]+), ([%d%.]+) }")
	assert(x, `no encuentro la zona {nombre} en Lugares`)
	return { tonumber(x) :: number, tonumber(z) :: number, tonumber(r) :: number }
end

-- Adónde llega cada una: { x, z } y lo que puede quedar de distancia.
local META = {
	Granja = { 185.5, 52, 2 }, -- delante de la puerta de la casa de la granja (lado oeste, x 188)
	Aserradero = { -212.5, -88, 2 }, -- el lado este de la nave (x -214)
	Torre = { 91, 249.5, 2 }, -- el pie de la escalera (z 251)
}

-- Cajas por las que no puede pasar ninguna tira (con su medio ancho, o el margen que diga): { x1, x2, z1, z2, nombre, margen }.
local PROHIBIDO = {
	{ -41, 41, -35, 35, "la casa" },
	{ -26, -12, 33, 45, "el lavadero" },
	{ -54, -44, 37, 45.5, "el cobertizo" },
	{ -60, -39, 2, 34, "el garaje" },
	{ -3.5, 3.5, 33.5, 47.6, "el hueco del sótano" },
	{ -11.4, -6.9, 59.2, 62, "la trampilla" },
	{ 188, 204, 46, 58, "la casa de la granja", 1 }, -- se llega de frente a su puerta: basta con no meterse
	{ 85.5, 94.5, 233.5, 242.5, "la caseta del guarda" },
	{ -246, -214, -99, -81, "la nave del aserradero", 1 },
	{ 218, 238, 68, 92, "el granero" },
}

local function dentro(x: number, z: number, c): boolean
	local m = c[6] or MEDIO
	return x > c[1] - m and x < c[2] + m and z > c[3] - m and z < c[4] + m
end

local vistas = 0
for nombre, puntos in MapaSendas.trazados do
	vistas += 1
	comprueba(#puntos >= 10, `{nombre}: tiene puntos`)
	local primero, ultimo = puntos[1], puntos[#puntos]
	local enClaro = primero[1] > -62 and primero[1] < 72 and primero[2] > 35 and primero[2] < 72
	local enCarretera = math.abs(primero[1]) < 6 and primero[2] < -41
	comprueba(enClaro or enCarretera, `{nombre}: empieza en el claro o en la carretera ({primero[1]}, {primero[2]})`)
	local z = zona(nombre)
	comprueba((ultimo[1] - z[1]) ^ 2 + (ultimo[2] - z[2]) ^ 2 < z[3] ^ 2, `{nombre}: acaba en su zona`)
	local meta = META[nombre]
	comprueba(meta, `{nombre}: tiene meta en el banco`)
	comprueba(math.sqrt((ultimo[1] - meta[1]) ^ 2 + (ultimo[2] - meta[2]) ^ 2) <= meta[3], `{nombre}: llega a su sitio`)
	for i = 1, #puntos - 1 do
		local a, b = puntos[i], puntos[i + 1]
		local largo = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
		comprueba(largo <= 10 and largo > 0.5, `{nombre}: tramo {i} de {largo}`)
		-- Las cajas prohibidas, mirando a lo largo del tramo.
		local pisa = nil
		for k = 0, 10 do
			local x, zz = a[1] + (b[1] - a[1]) * k / 10, a[2] + (b[2] - a[2]) * k / 10
			for _, c in PROHIBIDO do
				if dentro(x, zz, c) then
					pisa = `{c[5]} ({x}, {zz})`
				end
			end
		end
		comprueba(not pisa, `{nombre}: el tramo {i} pasa por {pisa}`)
		comprueba(MapaSendas.aTramo(212, 98, a, b) > 5 + MEDIO, `{nombre}: el tramo {i} pisa el depósito`)
		-- Que no dé la vuelta: la curva no se dobla más de 60 grados de un tramo al siguiente.
		if i > 1 then
			local p = puntos[i - 1]
			local d1x, d1z, d2x, d2z = a[1] - p[1], a[2] - p[2], b[1] - a[1], b[2] - a[2]
			local cos = (d1x * d2x + d1z * d2z) / (math.sqrt(d1x ^ 2 + d1z ^ 2) * math.sqrt(d2x ^ 2 + d2z ^ 2))
			comprueba(cos > 0.5, `{nombre}: curva cerrada en el punto {i}`)
		end
	end
	-- `cerca`: encima de la senda sí; a 3 de su eje con margen 1 también; a 40 no.
	local m = puntos[math.floor(#puntos / 2)]
	comprueba(MapaSendas.cerca(m[1], m[2], 0), `{nombre}: cerca encima`)
	comprueba(MapaSendas.cerca(m[1] + 3, m[2], 1), `{nombre}: cerca al lado`)
end
comprueba(vistas == 3, "hay tres sendas")
comprueba(not MapaSendas.cerca(300, 300, 4), "cerca: lejos de todo, no")
comprueba(not MapaSendas.cerca(0, -300, 4), "cerca: en la carretera lejos de la salida al aserradero, no")
comprueba(not MapaSendas.cerca(150, 150, 4), "cerca: en mitad del bosque, no")

-- Las piezas, con el Roblox de mentira: se construyen sin errores, ninguna choca, ni se le apunta, ni hace sombra, ni
-- es Neon; las tiras llevan EnMapa, hay mojones con su trapo y un poste por senda.
do
	local crearMundo = require("./_roblox")
	local m = crearMundo({ servidor = true })
	local g = m.global
	local Sendas = m.cargar("src/juego/servidor/MapaSendas")
	local bosque = g.Instance.new("Folder")
	local function bloque(nombre, tamano, cf, color, material, padre)
		local p = g.Instance.new("Part")
		p.Name, p.Size, p.CFrame, p.Color, p.Material, p.Parent = nombre, tamano, cf, color, material, padre
		return p
	end
	Sendas.construir(bosque, bloque)
	local carpeta = bosque:FindFirstChild("Sendas")
	comprueba(carpeta, "construir: deja la carpeta Sendas")
	local CollectionService = g.game:GetService("CollectionService")
	local cuantas: { [string]: number } = {}
	local total = 0
	for _, p in carpeta:GetDescendants() do
		if p:IsA("BasePart") then
			total += 1
			cuantas[p.Name] = (cuantas[p.Name] or 0) + 1
			comprueba(not p.CanCollide and not p.CanQuery and not p.CastShadow, `construir: {p.Name} no choca ni hace sombra`)
			comprueba(p.Material ~= g.Enum.Material.Neon, `construir: {p.Name} sin Neon`)
			comprueba(p.Size.X > 0 and p.Size.Y > 0 and p.Size.Z > 0, `construir: {p.Name} con tamaño`)
			comprueba((p.Name == "Senda") == CollectionService:HasTag(p, "EnMapa"), `construir: {p.Name} y EnMapa`)
			if p.Name == "Senda" then
				local arriba = p.Position.Y + p.Size.Y / 2
				comprueba(arriba > 0.04 and arriba < 0.09, `construir: la tira asoma poco del suelo ({arriba})`)
			end
		end
	end
	comprueba(cuantas.Poste == 3, "construir: un poste por senda")
	comprueba((cuantas.Estaca or 0) >= 15, `construir: mojones ({cuantas.Estaca})`)
	comprueba((cuantas.Trapo or 0) == (cuantas.Estaca or 0) * 2 + 6, "construir: cada mojón y cada poste con su trapo")
	comprueba(total < 260, `construir: pocas piezas ({total})`)
	print(`Sendas: {total} piezas ({cuantas.Senda} tiras, {cuantas.Estaca} mojones)`)
end

print(`Sendas: {cuentas} comprobaciones bien`)
