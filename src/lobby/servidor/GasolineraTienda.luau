-- La tienda de la gasolinera del lobby (pedido por el usuario: "el lobby es un poco feo"), por fuera y por dentro: en
-- x de 52 a 70 y z de -14 a 14, con la acera de delante de la puerta (x de 48,6 a 52). Al nivel de la casa y el pueblo
-- del juego: bloques de hormigón pintados y sucios, escaparates con cristales sucios, la puerta corredera de cristal,
-- el 24H, la bombilla con polillas, la nevera de hielo y los periódicos; dentro, baldosas gastadas, falso techo roto,
-- dos fluorescentes (uno falla), estanterías con productos algo revueltos, la nevera de bebidas, el mostrador (abre la
-- tienda) y, detrás, el mostrador de clases y cosméticos (linternas colgadas y un corcho con notas y fotos).
-- Todo va en el modelo "Tienda" de workspace.Mapa menos el "Mostrador", suelto en Mapa (lo busca lobby/cliente/TiendaUi).
-- Etiquetas y atributos para el cliente (LuzFalla, Polillas, Charco, Goteo, PuertaAuto, Nevera, Radio, Dentro): el
-- contrato del lobby, docs/sistemas/lobby.md. Solo chocan paredes (con su forro de dentro), suelos, falso techo,
-- cristales, puerta de atrás, mostrador, mueble de la cafetera, estanterías, neveras (y el congelador) y los dos muebles
-- grandes de la acera (hielo y periódicos); lo demás es adorno. Medidas a ojo.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local P = require(script.Parent.GasolineraPiezas)

local GasolineraTienda = {}

local COLOR = P.COLOR

-- Plano de la tienda (caras de fuera de las paredes, de 1 de grueso).
local X0, X1, Z0, Z1, ALTO = 52, 70, -14, 14, 11
local SUELO = 0.5 -- cara de arriba del suelo de la tienda y de la acera (la explanada está en 0,2)
local TECHO = 9.4 -- cara de abajo del falso techo
local PUERTA = { z = 4, alto = 8 } -- la entrada, en la pared oeste: z de -4 a 4, hasta y = 8
local VENTANA = { z0 = 5.5, z1 = 12, y0 = 2.4, y1 = 8 } -- los escaparates, a los dos lados (z de ±5,5 a ±12)
local TRASERA = { z0 = 7.5, z1 = 10.5, alto = 7.5 } -- la puerta de atrás, en la pared este (al bosque)

-- Imágenes que ya están en el juego (juego/servidor/Mapa y PuebloInteriores): grietas y una salpicadura de sangre seca
-- de tools/blender/sangre.py (ya trae su color; SECA la oscurece). La sangre, pequeña y discreta (Moderate).
local GRIETAS = "rbxassetid://113133657830111"
local SALPICADURA = "rbxassetid://82919660578513"

local HUMEDAD = Color3.fromRGB(38, 42, 32)
local OXIDO = COLOR.Oxido
local SECA = Color3.fromRGB(135, 95, 90)
local PARED = Color3.fromRGB(142, 134, 110) -- pintura de dentro, crema sucia
local BALDOSA_A = Color3.fromRGB(126, 120, 102)
local BALDOSA_B = Color3.fromRGB(50, 54, 50)
local PLACA = Color3.fromRGB(146, 142, 124) -- placas del falso techo
local MARCO = Color3.fromRGB(58, 54, 48) -- aluminio oscuro de escaparates y puertas
local ESTANTE = Color3.fromRGB(64, 66, 64)
local MADERA = Color3.fromRGB(72, 56, 42)
local CARTON = Color3.fromRGB(122, 96, 64)
local CARTON_MOJADO = Color3.fromRGB(80, 63, 45)
local PAPEL = Color3.fromRGB(164, 156, 132)
local LETRAS = Color3.fromRGB(52, 48, 44) -- los renglones de mentira de papeles y carteles
local MUGRE = Color3.fromRGB(48, 40, 32)
-- Etiquetas de los productos, desteñidas.
local PRODUCTOS = {
	Color3.fromRGB(112, 46, 38), Color3.fromRGB(52, 72, 100), Color3.fromRGB(70, 94, 58), Color3.fromRGB(146, 122, 64),
	Color3.fromRGB(124, 80, 42), Color3.fromRGB(92, 54, 80), Color3.fromRGB(146, 138, 120), Color3.fromRGB(62, 60, 58),
	Color3.fromRGB(42, 72, 78), Color3.fromRGB(136, 62, 48),
}
local BEBIDAS = { -- cola, naranja, lima, agua, azul, cerveza
	{ Color3.fromRGB(52, 30, 22), 0 }, { Color3.fromRGB(148, 82, 32), 0.1 }, { Color3.fromRGB(86, 118, 52), 0.15 },
	{ Color3.fromRGB(128, 148, 158), 0.35 }, { Color3.fromRGB(44, 70, 118), 0.1 }, { Color3.fromRGB(72, 46, 26), 0.05 },
}

local azar = Random.new(5270) -- siempre igual: la tienda sale idéntica en cada servidor
local grupo: Instance -- el modelo en el que van las piezas que se están haciendo
local tienda: Model

---------------------------------------------------------------------------------------------------------------------
-- Ayudas

-- Caja sin girar entre dos esquinas (en cualquier orden). Sin `choca` es adorno.
local function caja(nombre: string, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, color: Color3,
	material: Enum.Material?, choca: boolean?): Part
	local tam = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	return P.bloque(grupo, nombre, tam, CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color, material, choca)
end

-- Bloque girado (adorno).
local function pieza(nombre: string, tam: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	return P.bloque(grupo, nombre, tam, cf, color, material)
end

-- Cilindro de pie con la base en `pie` (adorno).
local function dePie(nombre: string, pie: Vector3, diametro: number, alto: number, color: Color3, material: Enum.Material?): Part
	return P.cilindro(grupo, nombre, Vector3.new(alto, diametro, diametro),
		CFrame.new(pie + Vector3.new(0, alto / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, material)
end

local function mirando(desde: Vector3, hacia: Vector3): CFrame
	local arriba = if math.abs((hacia - desde).Unit.Y) > 0.99 then Vector3.zAxis else Vector3.yAxis
	return CFrame.lookAt(desde, hacia, arriba)
end

-- Cilindro de `a` a `b` (adorno).
local function tubo(nombre: string, a: Vector3, b: Vector3, diametro: number, color: Color3, material: Enum.Material?): Part
	return P.cilindro(grupo, nombre, Vector3.new((b - a).Magnitude, diametro, diametro),
		mirando((a + b) / 2, b) * CFrame.Angles(0, math.pi / 2, 0), color, material)
end

-- Barra cuadrada de `a` a `b` (adorno).
local function barra(nombre: string, a: Vector3, b: Vector3, grueso: number, color: Color3, material: Enum.Material?): Part
	return P.bloque(grupo, nombre, Vector3.new(grueso, grueso, (b - a).Magnitude), mirando((a + b) / 2, b), color, material)
end

-- Marco de algo plano pegado a una pared o al suelo, mirando hacia `normal`: su cara de delante (Front, -Z local) da a
-- `normal`; X local a lo ancho e Y a lo alto. `giro` lo tuerce sobre la normal.
local function plano(pos: Vector3, normal: Vector3, giro: number?): CFrame
	local arriba = if math.abs(normal.Y) > 0.9 then Vector3.zAxis else Vector3.yAxis
	return CFrame.lookAt(pos, pos + normal, arriba) * CFrame.Angles(0, 0, giro or 0)
end

-- Mancha (humedad, óxido, mugre, grieta o sangre) en una lámina invisible en `pos`, mirando hacia `normal`.
local function mancha(pos: Vector3, normal: Vector3, ancho: number, alto: number, color: Color3, transparencia: number,
	id: string?, giro: number?)
	local soporte = pieza("Mancha", Vector3.new(ancho, alto, 0.02), plano(pos, normal, giro), color, Enum.Material.SmoothPlastic)
	soporte.Transparency = 1
	soporte.CastShadow = false
	P.mancha(soporte, Enum.NormalId.Front, id, color, transparencia)
end

-- Cristal sucio: SmoothPlastic medio transparente (Glass tapa lo transparente de detrás) con mugre en las dos caras.
local function ensuciar(p: Part, fuera: Enum.NormalId, dentro: Enum.NormalId)
	p.Transparency = 0.6
	p.Reflectance = 0.05
	p.CastShadow = false
	P.mancha(p, fuera, nil, Color3.fromRGB(66, 62, 54), 0.45)
	P.mancha(p, dentro, nil, Color3.fromRGB(92, 90, 82), 0.65)
end

-- Renglones de mentira (sin letras: los textos del mundo no pasan por Lang) delante de una hoja de centro `cf`.
local function renglones(cf: CFrame, ancho: number, y0: number, n: number, paso: number)
	for i = 0, n - 1 do
		local largo = ancho * azar:NextNumber(0.5, 0.9)
		pieza("Renglon", Vector3.new(largo, 0.045, 0.01), cf * CFrame.new((ancho - largo) / 2, y0 - i * paso, -0.035), LETRAS,
			Enum.Material.SmoothPlastic)
	end
end

local function color(lista: { Color3 }): Color3
	return lista[azar:NextInteger(1, #lista)]
end

local function modelo(nombre: string): Model
	local m = Instance.new("Model")
	m.Name = nombre
	m.Parent = tienda
	grupo = m
	return m
end

---------------------------------------------------------------------------------------------------------------------
-- Paredes, tejado, canalón y manchas de fuera

-- El canalón de delante cuelga un poco hacia el medio: su altura (centro) en cada z.
local function alturaCanalon(z: number): number
	return 10.92 - 0.16 * (1 - math.abs(z - 2) / 16.8)
end

local function paredes()
	modelo("Fachada")
	local b, ladrillo = COLOR.Bloque, Enum.Material.Brick
	-- Norte, sur y este (con el hueco de la puerta de atrás).
	caja("Pared", X0, 0, Z0, X1, ALTO, Z0 + 1, b, ladrillo, true)
	caja("Pared", X0, 0, Z1 - 1, X1, ALTO, Z1, b, ladrillo, true)
	caja("Pared", X1 - 1, 0, Z0 + 1, X1, ALTO, TRASERA.z0, b, ladrillo, true)
	caja("Pared", X1 - 1, 0, TRASERA.z1, X1, ALTO, Z1 - 1, b, ladrillo, true)
	caja("Pared", X1 - 1, TRASERA.alto, TRASERA.z0, X1, ALTO, TRASERA.z1, b, ladrillo, true)
	caja("Umbral", X1 - 1, 0, TRASERA.z0, X1, SUELO, TRASERA.z1, COLOR.HormigonSucio, Enum.Material.Concrete, true)
	-- Oeste: el dintel corrido por encima de la puerta y los escaparates; debajo, machones y antepechos.
	caja("Pared", X0, PUERTA.alto, Z0 + 1, X0 + 1, ALTO, Z1 - 1, b, ladrillo, true)
	for _, s in { -1, 1 } do
		caja("Pared", X0, 0, s * VENTANA.z1, X0 + 1, PUERTA.alto, s * (Z1 - 1), b, ladrillo, true)
		caja("Pared", X0, 0, s * PUERTA.z, X0 + 1, PUERTA.alto, s * VENTANA.z0, b, ladrillo, true)
		caja("Pared", X0, 0, s * VENTANA.z0, X0 + 1, VENTANA.y0, s * VENTANA.z1, b, ladrillo, true)
	end
	caja("Umbral", X0, 0, -PUERTA.z, X0 + 1, SUELO, PUERTA.z, COLOR.MetalOscuro, Enum.Material.DiamondPlate, true)

	-- Banda baja más oscura por fuera (sucia de salpicar la lluvia), un poco separada de la pared.
	local zocalo = Color3.fromRGB(56, 58, 54)
	local hormigon = Enum.Material.Concrete
	caja("Zocalo", X0, 0.15, Z0 - 0.06, X1, 1.6, Z0, zocalo, hormigon)
	caja("Zocalo", X0, 0.15, Z1, X1, 1.6, Z1 + 0.06, zocalo, hormigon)
	caja("Zocalo", X1, 0.15, Z0, X1 + 0.06, 1.6, TRASERA.z0, zocalo, hormigon)
	caja("Zocalo", X1, 0.15, TRASERA.z1, X1 + 0.06, 1.6, Z1, zocalo, hormigon)
	for _, s in { -1, 1 } do
		caja("Zocalo", X0 - 0.06, SUELO, s * PUERTA.z, X0, 1.6, s * Z1, zocalo, hormigon)
	end

	-- Por dentro: pintura crema sucia (láminas un poco separadas de la pared), rodapié de goma y una franja roja. Las
	-- láminas chocan: la cámara de Roblox solo se para en lo que choca, y así no se mete entre lámina y pared.
	local yeso = Enum.Material.Plaster
	local bajo = SUELO + 0.04 -- encima de las baldosas
	caja("Forro", X0 + 1, bajo, Z0 + 1.01, X1 - 1, TECHO, Z0 + 1.11, PARED, yeso, true)
	caja("Forro", X0 + 1, bajo, Z1 - 1.11, X1 - 1, TECHO, Z1 - 1.01, PARED, yeso, true)
	caja("Forro", X1 - 1.11, bajo, Z0 + 1.11, X1 - 1.01, TECHO, TRASERA.z0, PARED, yeso, true)
	caja("Forro", X1 - 1.11, bajo, TRASERA.z1, X1 - 1.01, TECHO, Z1 - 1.11, PARED, yeso, true)
	caja("Forro", X1 - 1.11, TRASERA.alto, TRASERA.z0, X1 - 1.01, TECHO, TRASERA.z1, PARED, yeso, true)
	caja("Forro", X0 + 1.01, PUERTA.alto, Z0 + 1.11, X0 + 1.11, TECHO, Z1 - 1.11, PARED, yeso, true)
	for _, s in { -1, 1 } do
		caja("Forro", X0 + 1.01, bajo, s * VENTANA.z1, X0 + 1.11, PUERTA.alto, s * (Z1 - 1.11), PARED, yeso, true)
		caja("Forro", X0 + 1.01, bajo, s * PUERTA.z, X0 + 1.11, PUERTA.alto, s * VENTANA.z0, PARED, yeso, true)
		caja("Forro", X0 + 1.01, bajo, s * VENTANA.z0, X0 + 1.11, VENTANA.y0, s * VENTANA.z1, PARED, yeso, true)
	end
	local goma, rodapie = Color3.fromRGB(34, 32, 30), Enum.Material.Rubber
	caja("Rodapie", X0 + 1.11, bajo, Z0 + 1.11, X1 - 1.17, 0.95, Z0 + 1.17, goma, rodapie)
	caja("Rodapie", X0 + 1.11, bajo, Z1 - 1.17, X1 - 1.17, 0.95, Z1 - 1.11, goma, rodapie)
	caja("Rodapie", X1 - 1.17, bajo, Z0 + 1.11, X1 - 1.11, 0.95, TRASERA.z0, goma, rodapie)
	caja("Rodapie", X1 - 1.17, bajo, TRASERA.z1, X1 - 1.11, 0.95, Z1 - 1.11, goma, rodapie)
	for _, s in { -1, 1 } do
		caja("Rodapie", X0 + 1.11, bajo, s * PUERTA.z, X0 + 1.17, 0.95, s * (Z1 - 1.17), goma, rodapie)
	end
	caja("Franja", X0 + 1.11, 3.3, Z0 + 1.11, X1 - 1.15, 3.6, Z0 + 1.15, COLOR.Rojo, Enum.Material.SmoothPlastic)
	caja("Franja", X0 + 1.11, 3.3, Z1 - 1.15, X1 - 1.15, 3.6, Z1 - 1.11, COLOR.Rojo, Enum.Material.SmoothPlastic)
	caja("Franja", X1 - 1.15, 3.3, Z0 + 1.11, X1 - 1.11, 3.6, TRASERA.z0, COLOR.Rojo, Enum.Material.SmoothPlastic)
	caja("Franja", X1 - 1.15, 3.3, TRASERA.z1, X1 - 1.11, 3.6, Z1 - 1.11, COLOR.Rojo, Enum.Material.SmoothPlastic)

	-- Tejado plano: losa con vuelo delante (de ahí gotea), bandas con el rojo de la marca y su raya, y remate de chapa.
	local tejado = caja("Tejado", 50.9, ALTO, Z0 - 0.5, X1 + 0.5, ALTO + 0.6, Z1 + 0.5, Color3.fromRGB(54, 52, 49), hormigon, true)
	local plastico = Enum.Material.Plastic
	caja("Banda", 50.6, 10.7, Z0 - 0.8, 50.9, 12.4, Z1 + 0.8, COLOR.Rojo, plastico)
	caja("Banda", 50.9, 10.7, Z0 - 0.8, X1 + 0.8, 12.4, Z0 - 0.5, COLOR.Rojo, plastico)
	caja("Banda", 50.9, 10.7, Z1 + 0.5, X1 + 0.8, 12.4, Z1 + 0.8, COLOR.Rojo, plastico)
	caja("Banda", X1 + 0.5, 10.7, Z0 - 0.5, X1 + 0.8, 12.4, Z1 + 0.5, COLOR.HormigonSucio, plastico) -- detrás, sin pintar
	caja("Raya", 50.56, 11.85, Z0 - 0.78, 50.6, 12.05, Z1 + 0.78, COLOR.Linea, plastico)
	caja("Raya", 50.9, 11.85, Z0 - 0.84, X1 + 0.8, 12.05, Z0 - 0.8, COLOR.Linea, plastico)
	caja("Raya", 50.9, 11.85, Z1 + 0.8, X1 + 0.8, 12.05, Z1 + 0.84, COLOR.Linea, plastico)
	local chapa = Enum.Material.Metal
	caja("Remate", 50.5, 12.4, Z0 - 0.9, 51, 12.55, Z1 + 0.9, COLOR.Metal, chapa)
	caja("Remate", 51, 12.4, Z0 - 0.9, X1 + 0.9, 12.55, Z0 - 0.4, COLOR.Metal, chapa)
	caja("Remate", 51, 12.4, Z1 + 0.4, X1 + 0.9, 12.55, Z1 + 0.9, COLOR.Metal, chapa)
	caja("Remate", X1 + 0.4, 12.4, Z0 - 0.4, X1 + 0.9, 12.55, Z1 + 0.4, COLOR.Metal, chapa)
	-- Un trozo de remate suelto, colgando de la esquina del sur.
	pieza("Remate", Vector3.new(0.5, 0.15, 2.2), CFrame.new(50.72, 12.05, 14.25) * CFrame.Angles(math.rad(28), 0, math.rad(6)),
		COLOR.Metal, chapa)

	-- Canalón de delante, colgado de la banda con escuadras (una rota) y algo combado; bajante roto en la esquina norte.
	local canal = Color3.fromRGB(70, 68, 62)
	local function punto(z: number): Vector3
		return Vector3.new(50.25, alturaCanalon(z), z)
	end
	tubo("Canalon", punto(Z0 - 0.8), punto(2), 0.5, canal, chapa)
	tubo("Canalon", punto(2), punto(Z1 + 0.8), 0.5, canal, chapa)
	for _, z in { Z0 - 0.8, Z1 + 0.8 } do
		tubo("Tapa", punto(z) - Vector3.new(0, 0, 0.02), punto(z) + Vector3.new(0, 0, 0.02), 0.54, canal, chapa)
	end
	for _, z in { -12, -6, 0, 6, 12 } do
		caja("Escuadra", 50.44, alturaCanalon(z) + 0.05, z - 0.04, 50.6, alturaCanalon(z) + 0.3, z + 0.04, COLOR.OxidoOscuro, chapa)
	end
	pieza("Escuadra", Vector3.new(0.08, 0.5, 0.08), CFrame.new(50.5, alturaCanalon(8.6) - 0.1, 8.6) * CFrame.Angles(0, 0, math.rad(35)),
		COLOR.OxidoOscuro, chapa)
	-- Gotas del borde de delante del tejado (Clima): por el canalón que pierde, sin caer encima de los muebles de la acera.
	for _, z in { -13, -11.2, -4.6, -1.6, 1.8, 4.4, 10.2, 12.8 } do
		P.etiqueta(P.punto(tejado, "Goteo", punto(z) - Vector3.new(0, 0.27, 0)), "Goteo")
	end
	local bajante = Vector3.new(51.72, 0, -13.55)
	tubo("Bajante", punto(Z0 - 0.4) - Vector3.new(0, 0.1, 0), bajante + Vector3.new(0, 9.9, 0), 0.42, canal, chapa)
	tubo("Bajante", bajante + Vector3.new(0, 9.9, 0), bajante + Vector3.new(0, 3.8, 0), 0.42, canal, chapa)
	for _, y in { 8.6, 5.6 } do
		caja("Abrazadera", bajante.X - 0.25, y, bajante.Z - 0.25, bajante.X + 0.25, y + 0.12, bajante.Z + 0.25, COLOR.OxidoOscuro, chapa)
	end
	dePie("Bajante", bajante + Vector3.new(0, SUELO, 0), 0.42, 0.6, canal, chapa) -- lo que queda abajo
	tubo("Bajante", Vector3.new(51.25, SUELO + 0.21, -12.7), Vector3.new(49.95, SUELO + 0.21, -10.7), 0.42, canal, chapa) -- el trozo caído
	P.etiqueta(P.punto(tejado, "Goteo", bajante + Vector3.new(0, 3.75, 0)), "Goteo") -- el agua sale por la rotura

	-- Humedad bajo el tejado y en el zócalo, óxido y grietas (por los cuatro lados).
	local oeste, norte, sur, este = -Vector3.xAxis, -Vector3.zAxis, Vector3.zAxis, Vector3.xAxis
	for _, m in {
		{ Vector3.new(X0 - 0.03, 9.7, -9.5), oeste, 3, 1.6 }, { Vector3.new(X0 - 0.03, 9.5, 9), oeste, 2.6, 1.4 },
		{ Vector3.new(58, 9.6, Z0 - 0.03), norte, 4, 2.4 }, { Vector3.new(66.5, 9.8, Z0 - 0.03), norte, 3, 2 },
		{ Vector3.new(57, 9.5, Z1 + 0.03), sur, 3.5, 2.2 }, { Vector3.new(65, 9.7, Z1 + 0.03), sur, 3, 2 },
		{ Vector3.new(X1 + 0.03, 9.6, -6), este, 3, 2 }, { Vector3.new(X1 + 0.03, 9.5, 4), este, 3.4, 2.2 },
	} do
		mancha(m[1], m[2], m[3], m[4], HUMEDAD, 0.3)
	end
	for _, m in {
		{ Vector3.new(X0 - 0.08, 1.2, -12.6), oeste, 1.6, 1.3 }, { Vector3.new(X0 - 0.08, 1.3, 11.2), oeste, 2, 1.4 },
		{ Vector3.new(55, 1.5, Z0 - 0.08), norte, 3, 1.6 }, { Vector3.new(63, 1.3, Z0 - 0.08), norte, 2.5, 1.4 },
		{ Vector3.new(60, 1.3, Z1 + 0.08), sur, 3, 1.5 }, { Vector3.new(68, 1.5, Z1 + 0.08), sur, 2, 1.4 },
		{ Vector3.new(X1 + 0.08, 1.3, 2), este, 3, 1.4 }, { Vector3.new(X1 + 0.08, 1.4, -11), este, 2.4, 1.3 },
	} do
		mancha(m[1], m[2], m[3], m[4], HUMEDAD, 0.25)
	end
	mancha(Vector3.new(X0 - 0.03, 9.25, 0.05), oeste, 0.5, 0.7, OXIDO, 0.4) -- bajo el brazo de la bombilla
	mancha(Vector3.new(X0 - 0.03, 7.2, -13.55), oeste, 0.6, 4, OXIDO, 0.5) -- detrás del bajante
	for _, m in {
		{ Vector3.new(X0 - 0.08, 1.05, -8.2), oeste, 1.2 }, { Vector3.new(60.5, 5.5, Z0 - 0.03), norte, 2 },
		{ Vector3.new(54.5, 6, Z1 + 0.03), sur, 1.8 }, { Vector3.new(X1 + 0.03, 6.5, 3), este, 1.6 },
		{ Vector3.new(X1 + 0.03, 3.2, 12.2), este, 1.2 },
	} do
		mancha(m[1], m[2], m[3], m[3], Color3.fromRGB(165, 160, 150), 0.2, GRIETAS, azar:NextNumber(0, math.pi * 2))
	end
	return tejado
end

---------------------------------------------------------------------------------------------------------------------
-- Escaparates: marco de aluminio, dos cristales sucios por lado, alféizar fuera y repisa dentro. En el del norte, un
-- cristal rajado con cinta y un cartel de oferta descolorido; en el del sur, una persiana torcida.

local function escaparates()
	modelo("Escaparates")
	local metal = Enum.Material.Metal
	for _, s in { -1, 1 } do
		local za, zb = math.min(s * VENTANA.z0, s * VENTANA.z1), math.max(s * VENTANA.z0, s * VENTANA.z1)
		local y0, y1, zm = VENTANA.y0, VENTANA.y1, (za + zb) / 2
		local xa, xb = X0 + 0.3, X0 + 0.75
		caja("Marco", xa, y1 - 0.15, za, xb, y1, zb, MARCO, metal)
		caja("Marco", xa, y0, za, xb, y0 + 0.15, zb, MARCO, metal)
		caja("Marco", xa, y0 + 0.15, za, xb, y1 - 0.15, za + 0.15, MARCO, metal)
		caja("Marco", xa, y0 + 0.15, zb - 0.15, xb, y1 - 0.15, zb, MARCO, metal)
		caja("Marco", xa, y0 + 0.15, zm - 0.075, xb, y1 - 0.15, zm + 0.075, MARCO, metal)
		for _, tramo in { { za + 0.15, zm - 0.075 }, { zm + 0.075, zb - 0.15 } } do
			local c = caja("Cristal", X0 + 0.47, y0 + 0.15, tramo[1], X0 + 0.53, y1 - 0.15, tramo[2], COLOR.Cristal,
				Enum.Material.SmoothPlastic, true)
			ensuciar(c, Enum.NormalId.Left, Enum.NormalId.Right)
		end
		caja("Alfeizar", X0 - 0.25, 2.2, za - 0.2, X0 + 0.3, 2.45, zb + 0.2, COLOR.Hormigon, Enum.Material.Concrete)
		caja("Repisa", X0 + 0.75, y0, za, X0 + 1.5, y0 + 0.1, zb, PARED, Enum.Material.Plaster)
	end

	-- Norte: el cristal de junto a la puerta, rajado y con cinta en cruz.
	local afuera = -Vector3.xAxis
	mancha(Vector3.new(X0 + 0.44, 5.3, -7.1), afuera, 1.7, 1.7, Color3.fromRGB(190, 190, 186), 0.15, GRIETAS, 0.4)
	for _, giro in { 0.7, -0.75 } do
		pieza("Cinta", Vector3.new(1.5, 0.16, 0.015), plano(Vector3.new(X0 + 0.425, 5.3, -7.1), afuera, giro),
			Color3.fromRGB(150, 146, 128), Enum.Material.Fabric).Transparency = 0.15
	end
	-- Cartel de oferta pegado por dentro (se ve desde fuera; sin letras): banda roja y una botella.
	local cartel = plano(Vector3.new(X0 + 0.6, 5.4, -10.4), afuera, 0.03)
	pieza("Cartel", Vector3.new(1.5, 2.1, 0.02), cartel, Color3.fromRGB(150, 142, 118), Enum.Material.SmoothPlastic)
	pieza("Cartel", Vector3.new(1.3, 0.7, 0.01), cartel * CFrame.new(0, 0.55, -0.03), Color3.fromRGB(104, 40, 34), Enum.Material.SmoothPlastic)
	pieza("Cartel", Vector3.new(0.34, 0.8, 0.01), cartel * CFrame.new(0.25, -0.45, -0.03), Color3.fromRGB(44, 34, 28), Enum.Material.SmoothPlastic)
	pieza("Cartel", Vector3.new(0.13, 0.22, 0.01), cartel * CFrame.new(0.25, 0.06, -0.03), Color3.fromRGB(44, 34, 28), Enum.Material.SmoothPlastic)

	-- Sur: persiana de lamas bajada a medias, torcida (se rompió un cordón) y con una lama partida.
	local zc, largo = (VENTANA.z0 + VENTANA.z1) / 2, VENTANA.z1 - VENTANA.z0 - 0.3
	local lama = Color3.fromRGB(154, 148, 128)
	caja("Persiana", X0 + 1.2, 7.7, VENTANA.z0 + 0.1, X0 + 1.4, 7.92, VENTANA.z1 - 0.1, lama, Enum.Material.Plastic)
	for k = 0, 8 do
		if k ~= 3 then -- falta una
			local cf = CFrame.new(X0 + 1.3, 7.55 - k * 0.28, zc) * CFrame.Angles(0.014 * k, 0, math.rad(30))
			if k == 6 then
				pieza("Lama", Vector3.new(0.22, 0.02, largo / 2), cf * CFrame.new(0, 0, -largo / 4), lama, Enum.Material.Plastic)
				pieza("Lama", Vector3.new(0.22, 0.02, largo / 2), cf * CFrame.new(0, 0, 0.02) * CFrame.Angles(0.55, 0, 0)
					* CFrame.new(0, 0, largo / 4), lama, Enum.Material.Plastic)
			else
				pieza("Lama", Vector3.new(0.22, 0.02, largo), cf, lama, Enum.Material.Plastic)
			end
		end
	end
	pieza("Persiana", Vector3.new(0.26, 0.06, largo), CFrame.new(X0 + 1.3, 5.0, zc) * CFrame.Angles(0.14, 0, 0), lama, Enum.Material.Plastic)
	for _, z in { 7.2, 10.3 } do
		caja("Cordon", X0 + 1.29, 5.0 - (z - zc) * 0.14, z - 0.01, X0 + 1.31, 7.7, z + 0.01, Color3.fromRGB(120, 114, 98), Enum.Material.Fabric)
	end
	caja("Cordon", X0 + 1.37, 4.2, 11.59, X0 + 1.39, 7.7, 11.61, Color3.fromRGB(120, 114, 98), Enum.Material.Fabric)
end

---------------------------------------------------------------------------------------------------------------------
-- Puerta corredera de cristal (contrato: PuertaAuto con Hoja1 y Hoja2 que se abren hacia los lados, sin chocar), su
-- motor, el 24H que parpadea en la banda y la bombilla con tulipa encima de la puerta.

local function puerta()
	modelo("Entrada")
	local metal = Enum.Material.Metal
	local auto = Instance.new("Model")
	auto.Name = "PuertaAuto"
	for i, s in { -1, 1 } do
		local hoja = Instance.new("Model")
		hoja.Name = `Hoja{i}`
		grupo = hoja
		local za, zb = math.min(0, s * 4.2), math.max(0, s * 4.2)
		local xa, xb, y0, y1 = 51.48, 51.64, SUELO + 0.06, 8.1
		local c = caja("Cristal", 51.53, y0 + 0.55, za + 0.2, 51.59, y1 - 0.25, zb - 0.2, COLOR.Cristal, Enum.Material.SmoothPlastic)
		ensuciar(c, Enum.NormalId.Left, Enum.NormalId.Right)
		caja("Marco", xa, y1 - 0.25, za, xb, y1, zb, MARCO, metal)
		caja("Marco", xa, y0, za, xb, y0 + 0.55, zb, MARCO, metal)
		caja("Marco", xa, y0 + 0.55, za, xb, y1 - 0.25, za + 0.2, MARCO, metal)
		caja("Marco", xa, y0 + 0.55, zb - 0.2, xb, y1 - 0.25, zb, MARCO, metal)
		if s < 0 then -- la goma de donde se juntan las dos, en la primera
			caja("Goma", xa + 0.03, y0 + 0.6, -0.02, xb - 0.03, y1 - 0.3, 0.02, COLOR.Goma, Enum.Material.Rubber)
		else
			mancha(Vector3.new(51.5, 1.7, 1.6), -Vector3.xAxis, 0.9, 0.9, Color3.fromRGB(190, 190, 186), 0.2, GRIETAS, 1.1)
		end
		hoja.PrimaryPart = c
		hoja:SetAttribute("Desliza", Vector3.new(0, 0, 4 * s))
		hoja.Parent = auto
	end
	P.etiqueta(auto, "PuertaAuto", { Centro = Vector3.new(X0, 3, 0) })
	auto.Parent = tienda
	grupo = tienda:FindFirstChild("Entrada") :: Instance

	-- Motor arriba (por delante de la pared), sensor, carril en el suelo y jambas de chapa en el hueco.
	caja("Motor", 51.25, 8.1, -8.6, X0, 8.9, 8.6, MARCO, metal)
	caja("Sensor", 51.27, 7.92, -0.3, 51.45, 8.1, 0.3, COLOR.MetalOscuro, Enum.Material.SmoothPlastic)
	caja("Carril", 51.4, SUELO, -8.4, 51.72, SUELO + 0.04, 8.4, COLOR.MetalOscuro, metal)
	for _, s in { -1, 1 } do
		caja("Jamba", X0, SUELO, s * PUERTA.z, X0 + 1.11, PUERTA.alto, s * (PUERTA.z - 0.12), MARCO, metal)
	end
	caja("Jamba", X0, PUERTA.alto - 0.12, -PUERTA.z + 0.12, X0 + 1.11, PUERTA.alto, PUERTA.z - 0.12, MARCO, metal)

	-- 24H en una caja de luz en la banda de delante (contrato: LuzFalla; parpadea de vez en cuando).
	local letrero = caja("Letrero", 50.33, 11.25, -1.6, 50.63, 12.15, 1.6, Color3.fromRGB(58, 26, 22), Enum.Material.SmoothPlastic)
	P.letrero(letrero, Enum.NormalId.Left, "24H", Color3.fromRGB(186, 66, 50)).LightInfluence = 0.25 -- casi apagado
	P.luz(letrero, "PointLight", 0.3, 10, Color3.fromRGB(255, 110, 90))
	P.etiqueta(letrero, "LuzFalla", { Fallo = 0.35, Zumba = false })
	for _, y in { 11.2, 12.15 } do
		caja("Marco", 50.28, y, -1.66, 50.64, y + 0.05, 1.66, MARCO, metal)
	end

	-- Bombilla con tulipa de chapa en un brazo sobre la puerta (contrato: LuzFalla y Polillas).
	local tulipa = Color3.fromRGB(52, 58, 52)
	caja("Placa", X0 - 0.05, 9.5, -0.25, X0, 10.1, 0.25, COLOR.OxidoOscuro, metal)
	barra("Brazo", Vector3.new(X0 - 0.05, 9.98, 0), Vector3.new(51.15, 9.98, 0), 0.08, COLOR.OxidoOscuro, metal)
	barra("Brazo", Vector3.new(X0 - 0.05, 9.55, 0), Vector3.new(51.5, 9.94, 0), 0.06, COLOR.OxidoOscuro, metal)
	dePie("Tulipa", Vector3.new(51.15, 9.55, 0), 1.1, 0.18, tulipa, metal)
	dePie("Tulipa", Vector3.new(51.15, 9.73, 0), 0.75, 0.16, tulipa, metal)
	dePie("Tulipa", Vector3.new(51.15, 9.89, 0), 0.32, 0.12, tulipa, metal)
	local bombilla = P.bola(grupo, "Bombilla", Vector3.new(0.42, 0.42, 0.42), CFrame.new(51.15, 9.4, 0), COLOR.Bombilla,
		Enum.Material.SmoothPlastic)
	P.luz(bombilla, "PointLight", 0.8, 18, Color3.fromRGB(255, 205, 150))
	P.etiqueta(bombilla, "LuzFalla", { Fallo = 0.2, Zumba = false })
	P.etiqueta(bombilla, "Polillas")
end

---------------------------------------------------------------------------------------------------------------------
-- La acera de delante: bordillo pintado, bolardos, la nevera de hielo con candado, el expositor de periódicos, una
-- papelera, un cartel de desaparecido pegado junto a la puerta y charcos.

local function charco(pos: Vector3, ancho: number, largo: number, giro: number)
	local agua = pieza("Charco", Vector3.new(ancho, 0.02, largo), CFrame.new(pos) * CFrame.Angles(0, giro, 0), COLOR.Agua,
		Enum.Material.SmoothPlastic)
	agua.Reflectance = 0.2
	agua.Transparency = 0.15
	P.etiqueta(agua, "Charco")
	-- Otro trozo encima para que no sea un rectángulo (solo el de abajo lleva la etiqueta).
	local borde = pieza("Agua", Vector3.new(ancho * 0.6, 0.02, largo * 0.75), CFrame.new(pos + Vector3.new(ancho * 0.3, 0.025,
		largo * 0.2)) * CFrame.Angles(0, giro + 0.7, 0), COLOR.Agua, Enum.Material.SmoothPlastic)
	borde.Reflectance = 0.2
	borde.Transparency = 0.15
end

local function hielo()
	local x0, x1, z0, z1 = 49, 51.3, -9.9, -5.7
	local zm = (z0 + z1) / 2
	local metal = Enum.Material.Metal
	local blanco = Color3.fromRGB(128, 138, 142)
	local cuerpo = caja("Hielo", x0, 0.85, z0, x1, 6.1, z1, blanco, metal, true)
	P.mancha(cuerpo, Enum.NormalId.Back, nil, OXIDO, 0.3)
	P.mancha(cuerpo, Enum.NormalId.Front, nil, OXIDO, 0.4)
	caja("Base", x0 + 0.15, SUELO, z0 + 0.15, x1 - 0.15, 0.85, z1 - 0.15, COLOR.MetalOscuro, metal)
	caja("Tapa", x0 - 0.06, 6.1, z0 - 0.06, x1 + 0.05, 6.22, z1 + 0.06, blanco:Lerp(OXIDO, 0.35), metal)
	for _, t in { { z0 + 0.1, zm - 0.05 }, { zm + 0.05, z1 - 0.1 } } do
		local hoja = caja("PuertaHielo", x0 - 0.06, 1.1, t[1], x0, 5, t[2], Color3.fromRGB(136, 146, 150), metal)
		P.mancha(hoja, Enum.NormalId.Left, nil, OXIDO, 0.35)
		local z = if t[1] < zm then t[2] - 0.3 else t[1] + 0.3
		caja("Tirador", x0 - 0.16, 2.6, z - 0.06, x0 - 0.06, 3.5, z + 0.06, COLOR.MetalOscuro, metal)
	end
	caja("Candado", x0 - 0.3, 2.9, zm - 0.14, x0 - 0.12, 3.25, zm + 0.14, Color3.fromRGB(104, 86, 50), metal)
	caja("Candado", x0 - 0.26, 3.25, zm - 0.08, x0 - 0.16, 3.45, zm + 0.08, COLOR.Metal, metal)
	local cartel = caja("Cartel", x0 - 0.06, 5.12, z0 + 0.12, x0, 5.98, z1 - 0.12, Color3.fromRGB(40, 56, 82), Enum.Material.SmoothPlastic)
	P.letrero(cartel, Enum.NormalId.Left, "ICE", Color3.fromRGB(176, 184, 190))
	mancha(Vector3.new(x0 - 0.08, 2.4, zm), -Vector3.xAxis, 0.5, 1.2, OXIDO, 0.35) -- óxido que baja del candado
end

local function periodicos()
	local xc, zc = 50.45, 6.2
	local metal = Enum.Material.Metal
	caja("Pie", xc - 0.5, SUELO, zc - 0.5, xc + 0.5, SUELO + 0.06, zc + 0.5, COLOR.MetalOscuro, metal)
	dePie("Pie", Vector3.new(xc, SUELO + 0.06, zc), 0.35, 1.2, COLOR.MetalOscuro, metal)
	local cuerpo = caja("Periodicos", 49.75, 1.75, 5.5, 51.15, 3.85, 6.9, Color3.fromRGB(46, 64, 68), metal, true)
	P.mancha(cuerpo, Enum.NormalId.Left, nil, OXIDO, 0.4)
	caja("Monedero", 50.0, 3.85, 5.85, 50.6, 4.15, 6.55, COLOR.MetalOscuro, metal)
	caja("Tirador", 49.66, 2.25, 5.85, 49.75, 2.35, 6.55, COLOR.Metal, metal)
	-- El periódico del escaparate: titular (una raya gruesa), foto y renglones; el cristal, delante.
	local hoja = plano(Vector3.new(49.71, 3.0, zc), -Vector3.xAxis)
	pieza("Periodico", Vector3.new(1.15, 1.0, 0.02), hoja, Color3.fromRGB(138, 134, 118), Enum.Material.SmoothPlastic)
	pieza("Titular", Vector3.new(1.0, 0.14, 0.01), hoja * CFrame.new(0, 0.36, -0.035), LETRAS, Enum.Material.SmoothPlastic)
	pieza("Foto", Vector3.new(0.45, 0.42, 0.01), hoja * CFrame.new(0.27, -0.05, -0.035), Color3.fromRGB(64, 62, 58), Enum.Material.SmoothPlastic)
	renglones(hoja * CFrame.new(-0.26, 0, 0), 0.5, 0.12, 4, 0.12)
	local vidrio = caja("Cristal", 49.62, 2.45, 5.62, 49.64, 3.55, 6.78, COLOR.Cristal, Enum.Material.SmoothPlastic)
	vidrio.Transparency = 0.55
	P.mancha(vidrio, Enum.NormalId.Left, nil, Color3.fromRGB(70, 66, 58), 0.4)
end

local function acera()
	modelo("Acera")
	caja("Acera", 48.6, 0.2, Z0 - 0.8, X0, SUELO, Z1 + 0.8, Color3.fromRGB(84, 82, 78), Enum.Material.Concrete, true)
	caja("Bordillo", 48.56, 0.15, Z0 - 0.75, 48.9, SUELO + 0.03, Z1 + 0.75, Color3.fromRGB(120, 106, 54), Enum.Material.Concrete)
	mancha(Vector3.new(50.2, SUELO + 0.03, -2.4), Vector3.yAxis, 2.4, 1.6, MUGRE, 0.55)
	mancha(Vector3.new(49.8, SUELO + 0.03, 10.6), Vector3.yAxis, 1.8, 1.4, COLOR.Aceite, 0.5)
	mancha(Vector3.new(51.2, SUELO + 0.03, -3.0), Vector3.yAxis, 1.2, 1.2, Color3.fromRGB(160, 156, 148), 0.3, GRIETAS, 0.6)
	for _, z in { -12.9, -4.6, 4.6, 12.9 } do
		dePie("Bolardo", Vector3.new(49, SUELO, z), 0.55, 2.9, Color3.fromRGB(138, 118, 50), Enum.Material.Metal)
		P.bola(grupo, "Bolardo", Vector3.new(0.55, 0.55, 0.55), CFrame.new(49, SUELO + 2.9, z), Color3.fromRGB(138, 118, 50),
			Enum.Material.Metal)
	end
	hielo()
	periodicos()
	-- Papelera de chapa con su bolsa y un vaso tirado al lado.
	local papelera = Vector3.new(50.4, SUELO, 9.4)
	dePie("Papelera", papelera, 1.1, 2.4, Color3.fromRGB(50, 56, 50), Enum.Material.CorrodedMetal)
	dePie("Aro", papelera + Vector3.new(0, 2.4, 0), 1.2, 0.12, COLOR.MetalOscuro, Enum.Material.Metal)
	P.bola(grupo, "Bolsa", Vector3.new(0.9, 0.9, 0.9), CFrame.new(papelera + Vector3.new(0, 2.5, 0)), COLOR.Goma, Enum.Material.Plastic)
	tubo("Vaso", Vector3.new(49.6, SUELO + 0.12, 10.3), Vector3.new(49.85, SUELO + 0.12, 10.62), 0.24, Color3.fromRGB(150, 144, 130),
		Enum.Material.SmoothPlastic)
	-- Cartel de desaparecido pegado en el machón de junto a la puerta: mojado, torcido y sin letras.
	local hoja = plano(Vector3.new(X0 - 0.03, 4.6, 4.75), -Vector3.xAxis, 0.05)
	local papel = pieza("Desaparecido", Vector3.new(1.15, 1.5, 0.02), hoja, Color3.fromRGB(156, 150, 128), Enum.Material.SmoothPlastic)
	P.mancha(papel, Enum.NormalId.Front, nil, Color3.fromRGB(80, 76, 62), 0.5)
	pieza("Titular", Vector3.new(0.95, 0.2, 0.01), hoja * CFrame.new(0, 0.56, -0.035), LETRAS, Enum.Material.SmoothPlastic)
	pieza("Foto", Vector3.new(0.6, 0.62, 0.01), hoja * CFrame.new(0, 0.08, -0.035), Color3.fromRGB(70, 68, 64), Enum.Material.SmoothPlastic)
	pieza("Cara", Vector3.new(0.26, 0.32, 0.01), hoja * CFrame.new(0.02, 0.12, -0.06), Color3.fromRGB(116, 108, 96), Enum.Material.SmoothPlastic)
	renglones(hoja, 0.9, -0.36, 3, 0.11)
	for _, x in { -0.45, 0.45 } do
		pieza("Celo", Vector3.new(0.26, 0.1, 0.01), hoja * CFrame.new(x, 0.72, -0.035) * CFrame.Angles(0, 0, x), Color3.fromRGB(160, 154, 130),
			Enum.Material.SmoothPlastic).Transparency = 0.3
	end
	-- Charcos (Clima): delante de la puerta y donde echa el agua el bajante roto.
	charco(Vector3.new(50, SUELO + 0.02, 2.0), 2, 1.4, 0.25)
	charco(Vector3.new(50.6, SUELO + 0.02, -12.4), 2, 1.5, -0.4)
end

---------------------------------------------------------------------------------------------------------------------
-- Detrás (al bosque): la puerta trasera cerrada con su luz casi muerta, el escalón, palés, cajas mojadas, bolsas de
-- basura, el aire acondicionado oxidado y el contador de la luz en la pared del norte.

local function pale(cf: CFrame)
	local madera = Color3.fromRGB(96, 80, 60)
	for _, z in { -1.25, 0, 1.25 } do
		pieza("Pale", Vector3.new(3.4, 0.32, 0.3), cf * CFrame.new(0, 0.16, z), madera, Enum.Material.WoodPlanks)
	end
	for _, x in { -1.45, -0.72, 0, 0.72, 1.45 } do
		pieza("Pale", Vector3.new(0.5, 0.1, 2.8), cf * CFrame.new(x, 0.37, 0), madera:Lerp(MUGRE, azar:NextNumber(0, 0.4)), Enum.Material.WoodPlanks)
	end
end

local function trasera()
	modelo("Trasera")
	local metal = Enum.Material.Metal
	local zc = (TRASERA.z0 + TRASERA.z1) / 2
	-- La puerta, cerrada (choca), con barra antipánico por dentro y chapa abajo por fuera.
	local hoja = caja("PuertaTrasera", X1 - 0.4, SUELO, TRASERA.z0 + 0.1, X1 - 0.15, TRASERA.alto - 0.1, TRASERA.z1 - 0.1,
		Color3.fromRGB(62, 46, 40), Enum.Material.CorrodedMetal, true)
	P.mancha(hoja, Enum.NormalId.Right, nil, OXIDO, 0.35)
	for _, z in { TRASERA.z0, TRASERA.z1 - 0.1 } do
		caja("Marco", X1 - 1.15, SUELO, z, X1, TRASERA.alto, z + 0.1, MARCO, metal)
	end
	caja("Marco", X1 - 1.15, TRASERA.alto - 0.1, TRASERA.z0 + 0.1, X1, TRASERA.alto, TRASERA.z1 - 0.1, MARCO, metal)
	caja("Barra", X1 - 0.62, 3.5, TRASERA.z0 + 0.4, X1 - 0.48, 3.68, TRASERA.z1 - 0.4, COLOR.Metal, metal)
	for _, z in { TRASERA.z0 + 0.45, TRASERA.z1 - 0.6 } do
		caja("Barra", X1 - 0.55, 3.45, z, X1 - 0.4, 3.73, z + 0.15, COLOR.MetalOscuro, metal)
	end
	caja("Chapa", X1 - 0.15, SUELO + 0.1, TRASERA.z0 + 0.25, X1 - 0.12, 1.5, TRASERA.z1 - 0.25, COLOR.MetalOscuro, metal)
	tubo("Cerrojo", Vector3.new(X1 - 0.15, 3.8, TRASERA.z1 - 0.45), Vector3.new(X1 - 0.03, 3.8, TRASERA.z1 - 0.45), 0.22, COLOR.Metal, metal)
	caja("Escalon", X1, 0.2, TRASERA.z0, X1 + 1.3, SUELO, TRASERA.z1, COLOR.HormigonSucio, Enum.Material.Concrete, true)
	-- Luz de jaula encima, casi muerta (contrato: LuzFalla con Fallo 0,9).
	caja("Placa", X1, 8.05, zc - 0.25, X1 + 0.08, 8.55, zc + 0.25, COLOR.OxidoOscuro, metal)
	tubo("Portalamparas", Vector3.new(X1 + 0.08, 8.3, zc), Vector3.new(X1 + 0.4, 8.3, zc), 0.4, COLOR.OxidoOscuro, metal)
	local bombilla = P.bola(grupo, "Bombilla", Vector3.new(0.32, 0.32, 0.32), CFrame.new(X1 + 0.55, 8.3, zc), COLOR.Bombilla,
		Enum.Material.SmoothPlastic)
	P.luz(bombilla, "PointLight", 0.6, 12, Color3.fromRGB(255, 180, 120))
	P.etiqueta(bombilla, "LuzFalla", { Fallo = 0.9, Zumba = false })
	caja("Jaula", X1 + 0.42, 8.1, zc - 0.03, X1 + 0.74, 8.5, zc + 0.03, COLOR.MetalOscuro, metal)
	caja("Jaula", X1 + 0.45, 8.27, zc - 0.2, X1 + 0.71, 8.33, zc + 0.2, COLOR.MetalOscuro, metal)

	-- Palés: uno apoyado en la pared y dos apilados; cajas de cartón mojadas y bolsas de basura.
	pale(CFrame.new(X1 + 0.62, 0.2 + 1.66, 12.6) * CFrame.Angles(0, 0, math.pi / 2 + 0.22) * CFrame.new(0, -0.21, 0))
	pale(CFrame.new(71.6, 0.2, -10.5) * CFrame.Angles(0, math.pi / 2 + 0.06, 0))
	pale(CFrame.new(71.62, 0.62, -10.45) * CFrame.Angles(0, math.pi / 2 - 0.09, 0))
	pieza("Caja", Vector3.new(1.6, 1.2, 1.4), CFrame.new(71.05, 0.8, 3.1) * CFrame.Angles(0, 0.2, 0), CARTON_MOJADO, Enum.Material.Cardboard)
	pieza("Caja", Vector3.new(1.2, 0.9, 1.1), CFrame.new(71.1, 1.85, 3.15) * CFrame.Angles(0, -0.3, 0.05), CARTON_MOJADO, Enum.Material.Cardboard)
	pieza("Caja", Vector3.new(1.6, 0.22, 1.9), CFrame.new(72.2, 0.31, 1.3) * CFrame.Angles(0.04, 0.7, 0), CARTON_MOJADO, Enum.Material.Cardboard)
	for _, b in { { 71.7, 11.4, 1.2 }, { 72.5, 12.4, 1.05 }, { 71.6, 13.4, 1.0 } } do
		local d = b[3]
		local bolsa = P.bola(grupo, "Bolsa", Vector3.new(d, d, d), CFrame.new(b[1], 0.2 + d * 0.45, b[2]), COLOR.Goma, Enum.Material.Plastic)
		bolsa.Reflectance = 0.08
		P.bola(grupo, "Nudo", Vector3.new(0.32, 0.32, 0.32), CFrame.new(b[1], 0.2 + d * 0.92, b[2]), COLOR.Goma, Enum.Material.Plastic)
	end
	charco(Vector3.new(71.7, 0.22, 5.6), 2, 1.4, 0.5)

	-- Aire acondicionado oxidado en la pared de atrás, con óxido que baja.
	caja("Aire", X1 + 0.06, 6.3, -6, 71.6, 7.7, -3.6, Color3.fromRGB(94, 92, 84), Enum.Material.CorrodedMetal)
	caja("Rejilla", 71.6, 6.45, -5.85, 71.63, 7.55, -3.75, Color3.fromRGB(32, 32, 32), metal)
	tubo("Ventilador", Vector3.new(71.63, 7, -4.8), Vector3.new(71.66, 7, -4.8), 1.0, Color3.fromRGB(20, 20, 20), metal)
	for _, z in { -5.6, -4.0 } do
		barra("Escuadra", Vector3.new(X1 + 0.06, 5.3, z), Vector3.new(71.4, 6.3, z), 0.1, COLOR.OxidoOscuro, metal)
	end
	mancha(Vector3.new(X1 + 0.03, 5.2, -4.8), Vector3.xAxis, 0.8, 2, OXIDO, 0.35)

	-- Contador de la luz con su tubo, en la pared del norte.
	caja("Contador", 65.5, 4, Z0 - 0.35, 66.5, 5.4, Z0, Color3.fromRGB(86, 88, 86), metal)
	local medidor = tubo("Medidor", Vector3.new(66, 4.8, Z0 - 0.35), Vector3.new(66, 4.8, Z0 - 0.48), 0.55, Color3.fromRGB(120, 126, 124),
		Enum.Material.SmoothPlastic)
	medidor.Transparency = 0.3
	dePie("Tubo", Vector3.new(66, 5.4, Z0 - 0.2), 0.18, 5.3, Color3.fromRGB(86, 88, 86), metal)
	caja("Caja", 65.8, 2.4, Z0 - 0.25, 66.2, 2.9, Z0, Color3.fromRGB(86, 88, 86), metal)
	dePie("Tubo", Vector3.new(66, 0.2, Z0 - 0.15), 0.14, 2.2, Color3.fromRGB(86, 88, 86), metal)
	mancha(Vector3.new(66, 3.4, Z0 - 0.03), -Vector3.zAxis, 0.5, 1.2, OXIDO, 0.4)
end

---------------------------------------------------------------------------------------------------------------------
-- Suelo de dentro: baldosas de dos colores gastadas (las oscuras, sueltas encima de la base clara: ~52 piezas), alguna
-- partida, levantada o que falta, el felpudo y mugre por donde se pisa. Las baldosas bajan un poco dentro de la base
-- (B0): así su cara de abajo no coincide con la de los muebles (Separar las engordaría).

local function suelo()
	modelo("Suelo")
	caja("Suelo", X0 + 1, 0.2, Z0 + 1, X1 - 1, SUELO, Z1 - 1, BALDOSA_A, Enum.Material.Plastic, true)
	local plastico = Enum.Material.Plastic
	local B0 = SUELO - 0.03
	for i = 0, 7 do
		for j = 0, 12 do
			local x, z = X0 + 2 + i * 2, Z0 + 2 + j * 2
			local tirada = azar:NextNumber()
			if (i + j) % 2 == 0 then
				local c = BALDOSA_B:Lerp(Color3.fromRGB(72, 68, 58), azar:NextNumber(0, 0.4))
				-- Con tirada < 0,04 falta (se queda la clara: la cambiaron por otra), salvo junto a la puerta.
				if i == 2 and j == 4 then -- levantada por una esquina
					pieza("Baldosa", Vector3.new(1.94, 0.04, 1.94), CFrame.new(x, SUELO + 0.05, z) * CFrame.Angles(0.05, 0, 0.03), c, plastico)
				elseif tirada < 0.1 and (tirada >= 0.04 or i == 0) then -- partida en dos
					pieza("Baldosa", Vector3.new(1.94, 0.07, 0.94), CFrame.new(x, SUELO + 0.005, z - 0.505), c, plastico)
					pieza("Baldosa", Vector3.new(1.94, 0.07, 0.94), CFrame.new(x + 0.03, SUELO + 0.005, z + 0.5) * CFrame.Angles(0, 0.03, 0), c, plastico)
				elseif tirada >= 0.1 then
					caja("Baldosa", x - 0.97, B0, z - 0.97, x + 0.97, SUELO + 0.04, z + 0.97, c, plastico)
				end
			elseif tirada < 0.05 then -- clara que falta: el cemento de debajo
				caja("Cemento", x - 0.97, B0, z - 0.97, x + 0.97, SUELO + 0.025, z + 0.97, Color3.fromRGB(80, 78, 72), Enum.Material.Concrete)
			elseif tirada < 0.2 then -- clara más sucia
				caja("Baldosa", x - 0.97, B0, z - 0.97, x + 0.97, SUELO + 0.03, z + 0.97, BALDOSA_A:Lerp(MUGRE, 0.25), plastico)
			end
		end
	end
	caja("Felpudo", X0 + 1.2, SUELO + 0.04, -2.3, X0 + 3.6, SUELO + 0.1, 2.3, Color3.fromRGB(40, 38, 34), Enum.Material.Carpet)
	-- Mugre: barro de la entrada hacia el mostrador, delante de las neveras y en los rincones.
	local arriba = Vector3.yAxis
	for _, m in {
		{ 55.9, 0, 3.2, 2.6, 0.45 }, { 59.5, 0.6, 2.8, 2.2, 0.55 }, { 62.6, -0.8, 2.2, 2.4, 0.5 }, { 65.6, -9.8, 3.4, 1.4, 0.5 },
		{ 54.2, 12.1, 1.6, 1.6, 0.5 }, { 57.8, 7.6, 3, 1.4, 0.6 }, { 61.2, -9.6, 2.4, 1.6, 0.6 },
	} do
		mancha(Vector3.new(m[1], SUELO + 0.07, m[2]), arriba, m[3], m[4], MUGRE, m[5], nil, azar:NextNumber(0, math.pi * 2))
	end
	-- Lo mojado junto al cartel de suelo mojado (no es un charco de lluvia: no lleva la etiqueta).
	-- (a alturas distintas: dos capas transparentes casi juntas parpadean)
	for _, t in { { 61.6, 5.4, 2.2, 1.5, 0.3, 0.065 }, { 62.5, 5.9, 1.4, 1.2, -0.5, 0.09 } } do
		local mojado = pieza("Mojado", Vector3.new(t[3], 0.01, t[4]), CFrame.new(t[1], SUELO + t[6], t[2]) * CFrame.Angles(0, t[5], 0),
			Color3.fromRGB(44, 46, 44), Enum.Material.SmoothPlastic)
		mojado.Transparency = 0.45
		mojado.Reflectance = 0.12
	end
end

---------------------------------------------------------------------------------------------------------------------
-- Falso techo de placas con su perfilería: falta una placa (otra cuelga), manchas de agua, los dos fluorescentes
-- (contrato: LuzFalla con Zumba; uno bien y otro que falla) y un ventilador parado con una aspa caída.

local function fluorescente(x: number, z: number, fallo: number, brillo: number, alcance: number, sombras: boolean)
	caja("Pantalla", x - 0.35, TECHO - 0.18, z - 2.2, x + 0.35, TECHO, z + 2.2, Color3.fromRGB(150, 148, 138), Enum.Material.Metal)
	local luz = P.cilindro(grupo, "Tubo", Vector3.new(4, 0.22, 0.22), CFrame.new(x, TECHO - 0.31, z) * CFrame.Angles(0, math.pi / 2, 0),
		COLOR.Tubo, Enum.Material.SmoothPlastic)
	for _, s in { -1, 1 } do
		caja("Casquillo", x - 0.14, TECHO - 0.45, z + s * 2.0, x + 0.14, TECHO - 0.18, z + s * 2.12, Color3.fromRGB(70, 70, 68), Enum.Material.Metal)
	end
	P.luz(luz, "PointLight", brillo, alcance, Color3.fromRGB(222, 230, 212), sombras)
	P.etiqueta(luz, "LuzFalla", { Fallo = fallo, Zumba = true })
end

local function techo()
	modelo("Techo")
	-- Las placas chocan: la cámara no sube por encima del falso techo y al saltar se da con él.
	local t1 = TECHO + 0.1
	caja("Placas", X0 + 1, TECHO, Z0 + 1, X1 - 1, t1, -9, PLACA, Enum.Material.Plastic, true)
	caja("Placas", X0 + 1, TECHO, -9, 59, t1, -5, PLACA, Enum.Material.Plastic, true)
	caja("Placas", 61, TECHO, -9, X1 - 1, t1, -5, PLACA, Enum.Material.Plastic, true)
	caja("Placas", X0 + 1, TECHO, -5, X1 - 1, t1, Z1 - 1, PLACA, Enum.Material.Plastic, true)
	caja("Hueco", 59, 10.9, -9, 61, 10.95, -5, Color3.fromRGB(12, 12, 12), Enum.Material.SmoothPlastic) -- lo negro de arriba
	-- Perfilería (a alturas un poco distintas, que no parpadeen al cruzarse) y angulares contra las paredes.
	local perfil, metal = Color3.fromRGB(122, 118, 106), Enum.Material.Metal
	for x = 55, 67, 2 do
		caja("Perfil", x - 0.06, TECHO - 0.045, -12.75, x + 0.06, TECHO, 12.75, perfil, metal)
	end
	for _, z in { -9, -5, -1, 3, 7, 11 } do
		caja("Perfil", 53.25, TECHO - 0.1, z - 0.06, 68.75, TECHO - 0.03, z + 0.06, perfil, metal)
	end
	caja("Angular", 53.11, TECHO - 0.07, -12.89, 68.89, TECHO, -12.75, perfil, metal)
	caja("Angular", 53.11, TECHO - 0.07, 12.75, 68.89, TECHO, 12.89, perfil, metal)
	caja("Angular", 53.11, TECHO - 0.07, -12.75, 53.25, TECHO, 12.75, perfil, metal)
	caja("Angular", 68.75, TECHO - 0.07, -12.75, 68.89, TECHO, 12.75, perfil, metal)
	-- La placa que cuelga del hueco y un cable suelto.
	pieza("Placa", Vector3.new(1.94, 0.08, 3.9), CFrame.new(59.06, TECHO + 0.03, -7) * CFrame.Angles(0, 0, -math.rad(55))
		* CFrame.new(0.97, 0, 0), Color3.fromRGB(136, 126, 102), Enum.Material.Plastic)
	tubo("Cable", Vector3.new(60.4, 10.9, -6.1), Vector3.new(60.7, 8.2, -6.5), 0.05, COLOR.Goma, Enum.Material.Rubber)
	-- Manchas de agua (la lluvia entra por el tejado; la primera, junto al hueco, sin llegar a él aunque gire).
	local abajo = -Vector3.yAxis
	for _, m in { { 63.2, -7, 2, 2 }, { 55, 9.5, 2.4, 2 }, { 65.5, -11.2, 2, 1.8 }, { 57.2, -1.6, 1.4, 1.4 }, { 66.5, 9, 1.8, 1.6 } } do
		mancha(Vector3.new(m[1], TECHO - 0.015, m[2]), abajo, m[3], m[4], Color3.fromRGB(86, 66, 38), 0.3, nil, azar:NextNumber(0, math.pi * 2))
	end
	-- Fluorescentes: el bueno hace sombras (de las pocas del lobby); el otro falla mucho.
	fluorescente(62, -4, 0.1, 0.9, 22, true)
	fluorescente(58, 6.5, 0.5, 0.75, 18, false)
	-- Ventilador de techo parado.
	local fx, fz = 58.5, -0.5
	local oscuro = Color3.fromRGB(90, 86, 78)
	dePie("Ventilador", Vector3.new(fx, TECHO - 0.15, fz), 0.4, 0.15, oscuro, metal)
	dePie("Ventilador", Vector3.new(fx, 8.75, fz), 0.12, TECHO - 0.15 - 8.75, oscuro, metal)
	dePie("Ventilador", Vector3.new(fx, 8.42, fz), 0.7, 0.35, oscuro, metal)
	for k = 0, 3 do
		local giro = math.rad(20) + k * math.pi / 2
		local caida = if k == 2 then math.rad(14) else math.rad(2)
		pieza("Aspa", Vector3.new(1.9, 0.04, 0.42), CFrame.new(fx, 8.5, fz) * CFrame.Angles(0, giro, 0) * CFrame.new(0.3, 0, 0)
			* CFrame.Angles(0, 0, -caida) * CFrame.new(0.95, 0, 0), Color3.fromRGB(66, 50, 38), Enum.Material.Wood)
	end
end

---------------------------------------------------------------------------------------------------------------------
-- Estanterías: dos de pared (norte y sur) y la góndola baja; productos de colores apagados, con huecos, alguno torcido
-- o caído. Cada mueble choca con una caja invisible.

-- Un producto en la balda de marco `cf` (en el borde de delante, a la altura de la balda; -Z local hacia el pasillo),
-- con su borde izquierdo en `x` y `resto` de sitio hasta el lateral (nunca menos de 0,45). Devuelve lo que ocupa.
local function producto(cf: CFrame, x: number, libre: number, tipo: string, resto: number): number
	local suave = Enum.Material.SmoothPlastic
	local giro = azar:NextNumber(-0.12, 0.12)
	local tirada = azar:NextNumber()
	if tipo == "coche" then -- aceite, anticongelante, limpiaparabrisas
		local ancho, alto = 0.44, math.min(0.85, libre - 0.1)
		local c = ({ Color3.fromRGB(60, 50, 30), Color3.fromRGB(44, 88, 52), Color3.fromRGB(42, 64, 104), Color3.fromRGB(118, 96, 40) })[azar:NextInteger(1, 4)]
		if tirada < 0.06 and alto <= resto then -- tumbado
			pieza("Bote", Vector3.new(alto, ancho, 0.3), cf * CFrame.new(x + alto / 2, ancho / 2, 0.2), c, suave)
			return alto
		end
		local base = cf * CFrame.new(x + ancho / 2, 0, 0.2) * CFrame.Angles(0, giro, 0)
		pieza("Bote", Vector3.new(ancho, alto, 0.3), base * CFrame.new(0, alto / 2, 0), c, suave)
		dePie("Tapon", (base * CFrame.new(0.1, alto, 0)).Position, 0.14, 0.12, COLOR.Goma, suave)
		return ancho
	elseif tirada < 0.3 then -- latas (de una a tres iguales; a veces dos pisos y, si no, alguna caída)
		local d, alto = azar:NextNumber(0.3, 0.34), azar:NextNumber(0.42, 0.48)
		local n, c = math.min(azar:NextInteger(1, 3), math.floor(resto / (d + 0.02))), color(PRODUCTOS)
		local pisos = if libre > alto * 2 + 0.2 and azar:NextNumber() < 0.35 then 2 else 1
		for k = 0, n - 1 do
			for p = 0, pisos - 1 do
				local pie = cf * CFrame.new(x + d / 2 + k * (d + 0.02), p * alto, d / 2 + 0.06)
				if pisos == 1 and k == n - 1 and azar:NextNumber() < 0.07 then -- rodando hacia el borde
					tubo("Lata", (pie * CFrame.new(0, d / 2, 0)).Position, (pie * CFrame.new(0, d / 2, -alto)).Position, d, c, Enum.Material.Metal)
				else
					dePie("Lata", pie.Position, d, alto, c, Enum.Material.Metal)
				end
			end
		end
		return n * (d + 0.02)
	elseif tirada < 0.5 then -- botella
		local d, alto = azar:NextNumber(0.34, 0.4), math.min(azar:NextNumber(0.7, 0.85), libre - 0.35)
		local b = BEBIDAS[azar:NextInteger(1, #BEBIDAS)]
		local pie = cf * CFrame.new(x + d / 2, 0, d / 2 + 0.06)
		if azar:NextNumber() < 0.06 and alto + 0.24 <= resto then -- tumbada a lo largo de la balda
			local a, z = (pie * CFrame.new(-d / 2, d / 2, 0)).Position, (pie * CFrame.new(-d / 2 + alto, d / 2, 0)).Position
			tubo("Botella", a, z, d, b[1], suave).Transparency = b[2]
			tubo("Tapon", z, z + (z - a).Unit * 0.24, 0.14, color(PRODUCTOS), suave)
			return alto + 0.24
		end
		dePie("Botella", pie.Position, d, alto, b[1], suave).Transparency = b[2]
		dePie("Tapon", (pie * CFrame.new(0, alto, 0)).Position, 0.14, 0.24, color(PRODUCTOS), suave)
		return d
	elseif tirada < 0.62 then -- tarro con tapa
		local d, alto = azar:NextNumber(0.36, 0.42), azar:NextNumber(0.42, 0.52)
		local pie = cf * CFrame.new(x + d / 2, 0, d / 2 + 0.06)
		dePie("Tarro", pie.Position, d, alto, Color3.fromRGB(112, 96, 70), suave).Transparency = 0.2
		dePie("Tapa", (pie * CFrame.new(0, alto, 0)).Position, d + 0.02, 0.08, color(PRODUCTOS), Enum.Material.Metal)
		return d
	elseif tirada < 0.8 then -- caja (galletas, cereales, detergente)
		local ancho, alto = math.min(azar:NextNumber(0.55, 0.95), resto), math.min(azar:NextNumber(0.8, 1.25), libre - 0.1)
		local fondo = azar:NextNumber(0.3, 0.5)
		local c = color(PRODUCTOS)
		if azar:NextNumber() < 0.08 and alto <= resto then -- tumbada a lo largo de la balda
			local prof = math.min(ancho, 0.7)
			pieza("Caja", Vector3.new(alto, fondo, prof), cf * CFrame.new(x + alto / 2, fondo / 2, prof / 2 + 0.06) * CFrame.Angles(0, giro / 2, 0),
				c, suave)
			return alto
		end
		local ladeo = if azar:NextNumber() < 0.1 and ancho + 0.22 <= resto then 0.22 else 0
		pieza("Caja", Vector3.new(ancho, alto, fondo), cf * CFrame.new(x + ancho / 2, alto / 2, fondo / 2 + 0.06) * CFrame.Angles(0, giro, ladeo),
			c, suave)
		return ancho + ladeo
	end
	-- Bolsa de patatas: brillante y algo echada hacia atrás.
	local ancho, alto = math.min(azar:NextNumber(0.65, 0.8), resto), math.min(azar:NextNumber(0.85, 1.0), libre - 0.1)
	pieza("Bolsa", Vector3.new(ancho, alto, 0.28), cf * CFrame.new(x + ancho / 2, alto / 2, 0.26) * CFrame.Angles(0.15, giro, 0),
		color(PRODUCTOS), Enum.Material.Foil)
	return ancho
end

-- Llena una balda de `largo` (centrada en `cf`) con productos y huecos, sin pasarse del final.
local function llenar(cf: CFrame, largo: number, libre: number, tipo: string)
	local x, fin = -largo / 2 + 0.15, largo / 2 - 0.15
	while x < fin - 0.45 do
		if azar:NextNumber() < 0.14 then
			x += azar:NextNumber(0.4, 1.1) -- hueco: no repone nadie
		else
			x += producto(cf, x, libre, tipo, fin - x) + azar:NextNumber(0.03, 0.12)
		end
	end
end

-- Estantería de pared: `centro` en el suelo, en el medio del borde de delante; `fuera` hacia el pasillo.
local function estanteria(centro: Vector3, fuera: Vector3, largo: number, tipos: { string })
	local fondo, alto = 1.6, 6.5
	local cf = CFrame.lookAt(centro, centro + fuera) -- X a lo largo, Y arriba, +Z hacia la pared
	local metal = Enum.Material.Metal
	local function trozo(nombre: string, tam: Vector3, pos: Vector3, c: Color3?)
		pieza(nombre, tam, cf * CFrame.new(pos), c or ESTANTE, metal)
	end
	-- Las piezas no comparten caras (Separar las engordaría): trasera y baldas entre los laterales, remate encima.
	local dentro = largo - 0.24
	trozo("Trasera", Vector3.new(dentro, alto - 0.45, 0.1), Vector3.new(0, (alto + 0.45) / 2, fondo - 0.05))
	for _, s in { -1, 1 } do
		trozo("Lateral", Vector3.new(0.12, alto, fondo), Vector3.new(s * (largo / 2 - 0.06), alto / 2, fondo / 2))
	end
	trozo("Base", Vector3.new(dentro, 0.45, fondo - 0.1), Vector3.new(0, 0.225, (fondo - 0.1) / 2))
	trozo("Remate", Vector3.new(largo + 0.06, 0.12, fondo + 0.01), Vector3.new(0, alto + 0.06, fondo / 2 - 0.035))
	local alturas = { 0.45, 1.9, 3.35, 4.8 }
	for i, h in alturas do
		if i > 1 then
			trozo("Balda", Vector3.new(dentro, 0.08, fondo - 0.15), Vector3.new(0, h - 0.04, (fondo - 0.15) / 2))
		end
		trozo("Etiquetero", Vector3.new(dentro, 0.16, 0.04), Vector3.new(0, h - 0.08, -0.02), Color3.fromRGB(140, 134, 112))
		local techoBalda = if i < #alturas then alturas[i + 1] - 0.08 else alto
		llenar(cf * CFrame.new(0, h, 0), largo - 0.3, techoBalda - h, tipos[i])
	end
	local choque = P.bloque(grupo, "Choque", Vector3.new(largo, alto, fondo), cf * CFrame.new(0, alto / 2, fondo / 2), ESTANTE, nil, true)
	choque.Transparency = 1
	choque.CastShadow = false
	-- Cajas de reserva encima.
	for k = 1, 2 do
		local ancho, altoCaja = azar:NextNumber(1.2, 1.8), azar:NextNumber(0.8, 1.1)
		pieza("Caja", Vector3.new(ancho, altoCaja, 1.2), cf * CFrame.new((k - 1.5) * largo * 0.5 + azar:NextNumber(-0.5, 0.5),
			alto + 0.12 + altoCaja / 2, 0.9) * CFrame.Angles(0, azar:NextNumber(-0.2, 0.2), 0), CARTON, Enum.Material.Cardboard)
	end
end

local function gondola()
	local x0, x1, z0, z1, alto = 56, 62, -8.3, -6.5, 4.2
	local metal = Enum.Material.Metal
	local zm = (z0 + z1) / 2
	local dentro = x1 - x0 - 0.24
	caja("Gondola", x0 + 0.12, SUELO, zm - 0.05, x1 - 0.12, SUELO + alto, zm + 0.05, ESTANTE, metal)
	for _, x in { x0, x1 - 0.12 } do
		caja("Lateral", x, SUELO, z0, x + 0.12, SUELO + alto, z1, ESTANTE, metal)
	end
	caja("Remate", x0 - 0.03, SUELO + alto, z0 - 0.03, x1 + 0.03, SUELO + alto + 0.08, z1 + 0.03, ESTANTE, metal)
	local alturas = { 0.45, 1.75, 3.05 }
	for _, lado in { { z0, -Vector3.zAxis, { "coche", "comida", "comida" } }, { z1, Vector3.zAxis, { "comida", "comida", "comida" } } } do
		local centro = Vector3.new((x0 + x1) / 2, SUELO, lado[1])
		local cf = CFrame.lookAt(centro, centro + lado[2])
		pieza("Base", Vector3.new(dentro, 0.45, 0.8), cf * CFrame.new(0, 0.225, 0.4), ESTANTE, metal)
		for i, h in alturas do
			if i > 1 then
				pieza("Balda", Vector3.new(dentro, 0.08, 0.8), cf * CFrame.new(0, h - 0.04, 0.4), ESTANTE, metal)
			end
			pieza("Etiquetero", Vector3.new(dentro, 0.16, 0.04), cf * CFrame.new(0, h - 0.08, -0.02), Color3.fromRGB(140, 134, 112), metal)
			local techoBalda = if i < #alturas then alturas[i + 1] - 0.08 else alto
			llenar(cf * CFrame.new(0, h, 0), x1 - x0 - 0.3, techoBalda - h, lado[3][i])
		end
	end
	-- Encima, patatas en su caja expositora.
	local arriba = SUELO + alto + 0.08
	pieza("Caja", Vector3.new(1.6, 0.5, 1.2), CFrame.new(60.6, arriba + 0.25, zm) * CFrame.Angles(0, 0.08, 0), CARTON, Enum.Material.Cardboard)
	for k = 0, 2 do
		pieza("Bolsa", Vector3.new(0.45, 0.6, 0.18), CFrame.new(60.1 + k * 0.5, arriba + 0.55, zm + 0.1) * CFrame.Angles(-0.25, 0, 0),
			color(PRODUCTOS), Enum.Material.Foil)
	end
	local choque = caja("Choque", x0, SUELO, z0, x1, SUELO + alto, z1, ESTANTE, nil, true)
	choque.Transparency = 1
	choque.CastShadow = false
end

local function estanterias()
	modelo("Estanterias")
	estanteria(Vector3.new(58.4, SUELO, -11.25), Vector3.zAxis, 8.4, { "coche", "comida", "comida", "comida" })
	estanteria(Vector3.new(57.8, SUELO, 11.25), -Vector3.zAxis, 7.2, { "comida", "comida", "comida", "comida" })
	gondola()
	-- Lo caído por el suelo (fuera del pasillo de la puerta al mostrador).
	tubo("Lata", Vector3.new(60.3, SUELO + 0.2, -10.2), Vector3.new(60.62, SUELO + 0.2, -9.9), 0.32, PRODUCTOS[1], Enum.Material.Metal)
	pieza("Caja", Vector3.new(0.8, 0.4, 1.1), CFrame.new(56.6, SUELO + 0.25, -9.2) * CFrame.Angles(0, 0.5, 0), PRODUCTOS[4], Enum.Material.SmoothPlastic)
	pieza("Bolsa", Vector3.new(0.7, 0.15, 0.95), CFrame.new(57.9, SUELO + 0.12, 10.1) * CFrame.Angles(0, -0.4, 0.05), PRODUCTOS[2], Enum.Material.Foil)
	-- Caja abierta a medio colocar en el pasillo del norte.
	local abierta = CFrame.new(61.3, SUELO, -9.75) * CFrame.Angles(0, 0.3, 0)
	pieza("Caja", Vector3.new(1.3, 0.9, 1.1), abierta * CFrame.new(0, 0.45, 0), CARTON, Enum.Material.Cardboard)
	pieza("Solapa", Vector3.new(1.3, 0.04, 0.5), abierta * CFrame.new(0, 0.9, -0.55) * CFrame.Angles(-2.2, 0, 0) * CFrame.new(0, 0, -0.25), CARTON,
		Enum.Material.Cardboard)
	pieza("Solapa", Vector3.new(1.3, 0.04, 0.5), abierta * CFrame.new(0, 0.9, 0.55) * CFrame.Angles(2.0, 0, 0) * CFrame.new(0, 0, 0.25), CARTON,
		Enum.Material.Cardboard)
	dePie("Lata", (abierta * CFrame.new(-0.3, 0.9, 0)).Position, 0.32, 0.45, PRODUCTOS[3], Enum.Material.Metal)
	dePie("Lata", (abierta * CFrame.new(0.15, 0.9, 0.1)).Position, 0.32, 0.45, PRODUCTOS[3], Enum.Material.Metal)
end

---------------------------------------------------------------------------------------------------------------------
-- Nevera de bebidas (contrato: Nevera, en la pieza del motor, y su luz azulada con LuzFalla): armario hueco con dos
-- puertas de cristal empañado, baldas de rejilla y botellas dentro. Choca entera.

local function nevera()
	modelo("Nevera")
	local x0, x1, z0, z1 = 63.4, 68.8, -12.84, -10.6
	local metal, suave = Enum.Material.Metal, Enum.Material.SmoothPlastic
	local blanco = Color3.fromRGB(150, 154, 152)
	local motor = caja("Motor", x0, SUELO, z0, x1, 1.3, z1, Color3.fromRGB(44, 44, 46), metal, true)
	P.etiqueta(motor, "Nevera")
	caja("Rejilla", x0 + 0.2, SUELO + 0.1, z1, x1 - 0.2, 1.2, z1 + 0.04, Color3.fromRGB(26, 26, 27), metal)
	caja("Fondo", x0, 1.3, z0, x1, 7.1, z0 + 0.16, blanco, metal, true)
	caja("Lado", x0, 1.3, z0 + 0.16, x0 + 0.2, 7.1, z1, blanco, metal, true)
	caja("Lado", x1 - 0.2, 1.3, z0 + 0.16, x1, 7.1, z1, blanco, metal, true)
	caja("Copete", x0, 7.1, z0, x1, 7.9, z1 + 0.15, Color3.fromRGB(36, 36, 38), metal, true)
	caja("Raya", x0 + 0.1, 7.35, z1 + 0.15, x1 - 0.1, 7.55, z1 + 0.18, COLOR.Rojo, suave)
	P.mancha(motor, Enum.NormalId.Back, nil, OXIDO, 0.4)
	-- Baldas y botellas (una fila delante; detrás, lo vacío).
	local alturas = { 1.3, 2.75, 4.2, 5.65 }
	for i, h in alturas do
		if i > 1 then
			caja("Balda", x0 + 0.2, h - 0.05, z0 + 0.18, x1 - 0.2, h, z1 - 0.2, Color3.fromRGB(108, 110, 110), metal)
		end
		local latas = i == 3
		for k = 0, 8 do
			local x = x0 + 0.5 + k * 0.55
			if azar:NextNumber() > 0.14 then
				local b = BEBIDAS[azar:NextInteger(1, #BEBIDAS)]
				local pie = Vector3.new(x + azar:NextNumber(-0.04, 0.04), h, -11.2 + azar:NextNumber(-0.06, 0.06))
				if latas then
					dePie("Lata", pie, 0.32, 0.46, color(PRODUCTOS), metal)
				else
					dePie("Botella", pie, 0.38, 0.8, b[1], suave).Transparency = b[2]
					dePie("Tapon", pie + Vector3.new(0, 0.8, 0), 0.15, 0.24, color(PRODUCTOS), suave)
				end
			end
		end
	end
	-- Puertas: marco, cristal (choca: cierra la nevera) empañado y tirador junto al parteluz.
	local zp = z1 + 0.07
	caja("Parteluz", 66.05, 1.3, z1, 66.15, 7.1, z1 + 0.16, MARCO, metal)
	for _, t in { { x0 + 0.2, 66.05, 65.85 }, { 66.15, x1 - 0.2, 66.35 } } do
		local a, b = t[1], t[2]
		caja("Marco", a, 6.95, z1, b, 7.1, z1 + 0.14, MARCO, metal)
		caja("Marco", a, 1.3, z1, b, 1.45, z1 + 0.14, MARCO, metal)
		caja("Marco", a, 1.45, z1, a + 0.12, 6.95, z1 + 0.14, MARCO, metal)
		caja("Marco", b - 0.12, 1.45, z1, b, 6.95, z1 + 0.14, MARCO, metal)
		local vidrio = caja("Cristal", a + 0.12, 1.45, zp - 0.03, b - 0.12, 6.95, zp + 0.03, Color3.fromRGB(150, 170, 180), suave, true)
		vidrio.Transparency = 0.55
		vidrio.CastShadow = false
		P.mancha(vidrio, Enum.NormalId.Back, nil, Color3.fromRGB(196, 204, 208), 0.62) -- empañado
		caja("Tirador", t[3] - 0.05, 3.2, z1 + 0.14, t[3] + 0.05, 5.2, z1 + 0.26, COLOR.Metal, metal)
	end
	-- La luz de dentro, arriba detrás de las puertas: azulada y muy floja.
	local luz = P.cilindro(grupo, "LuzNevera", Vector3.new(4.8, 0.14, 0.14), CFrame.new((x0 + x1) / 2, 6.88, z1 - 0.18),
		Color3.fromRGB(176, 200, 220), suave)
	P.luz(luz, "PointLight", 0.4, 10, Color3.fromRGB(165, 195, 230))
	P.etiqueta(luz, "LuzFalla", { Fallo = 0.1, Zumba = false })
	-- Una caja olvidada encima.
	pieza("Caja", Vector3.new(1.6, 1.0, 1.4), CFrame.new(64.8, 8.4, -11.9) * CFrame.Angles(0, 0.15, 0), CARTON, Enum.Material.Cardboard)
end

-- Congelador de helados (bajo, en la mitad sur): cuba con tapas de cristal escarchadas y cajas dentro.
local function congelador()
	modelo("Congelador")
	local x0, x1, z0, z1 = 55.5, 60.5, 6.2, 8.4
	local metal = Enum.Material.Metal
	local blanco = Color3.fromRGB(136, 140, 138)
	local cuerpo = caja("Congelador", x0, SUELO, z0, x1, 2.3, z1, blanco, metal, true)
	P.mancha(cuerpo, Enum.NormalId.Front, nil, OXIDO, 0.45)
	caja("Borde", x0, 2.3, z0, x1, 3.2, z0 + 0.15, blanco, metal, true)
	caja("Borde", x0, 2.3, z1 - 0.15, x1, 3.2, z1, blanco, metal, true)
	caja("Borde", x0, 2.3, z0 + 0.15, x0 + 0.15, 3.2, z1 - 0.15, blanco, metal, true)
	caja("Borde", x1 - 0.15, 2.3, z0 + 0.15, x1, 3.2, z1 - 0.15, blanco, metal, true)
	caja("Raya", x0 + 0.1, 1.6, z0 - 0.04, x1 - 0.1, 1.9, z0, Color3.fromRGB(44, 62, 92), Enum.Material.SmoothPlastic)
	caja("Escarcha", x0 + 0.15, 2.3, z0 + 0.15, x1 - 0.15, 2.36, z1 - 0.15, Color3.fromRGB(168, 174, 176), Enum.Material.Snow)
	for k = 0, 5 do
		pieza("Helado", Vector3.new(0.7, 0.36, 0.5), CFrame.new(x0 + 0.6 + k * 0.72, 2.54, 7.3 + azar:NextNumber(-0.4, 0.4))
			* CFrame.Angles(0, azar:NextNumber(-0.3, 0.3), 0), color(PRODUCTOS), Enum.Material.SmoothPlastic)
	end
	for _, t in { { x0 + 0.1, 58.2, 3.2 }, { 57.8, x1 - 0.1, 3.27 } } do
		local tapa = caja("Tapa", t[1], t[3], z0 + 0.1, t[2], t[3] + 0.06, z1 - 0.1, Color3.fromRGB(150, 160, 166), Enum.Material.SmoothPlastic)
		tapa.Transparency = 0.5
		tapa.CastShadow = false
		P.mancha(tapa, Enum.NormalId.Top, nil, Color3.fromRGB(200, 206, 210), 0.55) -- escarcha
	end
end

---------------------------------------------------------------------------------------------------------------------
-- El mostrador (contrato: "Mostrador" suelto en Mapa con el prompt "Tienda") con la caja registradora vieja, la
-- lámpara, la lotería, chucherías y el taburete detrás.

local function registradora()
	local beige, metal = Color3.fromRGB(118, 112, 96), Enum.Material.Metal
	caja("Registradora", 64.55, 4.05, -2.35, 66.05, 4.6, -0.65, beige, metal)
	caja("Registradora", 64.6, 4.6, -2.3, 65.25, 5.1, -0.7, beige, metal)
	-- Teclado inclinado hacia el que cobra (al este) y sus teclas.
	local tablero = CFrame.new(65.65, 4.72, -1.5) * CFrame.Angles(0, 0, math.rad(-18))
	pieza("Teclado", Vector3.new(0.85, 0.14, 1.5), tablero, beige:Lerp(Color3.new(), 0.25), metal)
	for u = -1, 1 do
		for v = -1, 1 do
			local c = if u == 1 and v == 1 then Color3.fromRGB(96, 40, 34) elseif u == 1 and v == -1 then Color3.fromRGB(52, 74, 50)
				else Color3.fromRGB(150, 146, 130)
			pieza("Tecla", Vector3.new(0.17, 0.07, 0.2), tablero * CFrame.new(u * 0.25, 0.09, v * 0.38 - 0.12), c, Enum.Material.SmoothPlastic)
		end
	end
	pieza("Tecla", Vector3.new(0.17, 0.07, 0.42), tablero * CFrame.new(0, 0.09, 0.55), Color3.fromRGB(150, 146, 130), Enum.Material.SmoothPlastic)
	-- Pantallita en su palo, con números para el cliente y para el que cobra.
	dePie("Palo", Vector3.new(64.92, 5.1, -1.5), 0.08, 0.3, COLOR.MetalOscuro, metal)
	local pantalla = caja("Pantalla", 64.77, 5.4, -1.85, 65.07, 5.72, -1.15, Color3.fromRGB(30, 32, 30), Enum.Material.SmoothPlastic)
	for _, cara in { Enum.NormalId.Left, Enum.NormalId.Right } do
		P.letrero(pantalla, cara, "0.00", Color3.fromRGB(110, 150, 96), Enum.Font.Code).LightInfluence = 0.35
	end
	-- El cajón, un poco abierto, con billetes y monedas.
	caja("Cajon", 66.05, 4.1, -2.2, 66.38, 4.45, -0.8, beige:Lerp(Color3.new(), 0.15), metal)
	caja("Billete", 66.08, 4.45, -2.0, 66.33, 4.47, -1.6, Color3.fromRGB(88, 104, 80), Enum.Material.SmoothPlastic)
	caja("Billete", 66.08, 4.45, -1.5, 66.33, 4.475, -1.1, Color3.fromRGB(96, 110, 86), Enum.Material.SmoothPlastic)
	dePie("Monedas", Vector3.new(66.2, 4.45, -0.95), 0.16, 0.05, Color3.fromRGB(130, 120, 90), metal)
	-- Rollo de papel y un tique colgando.
	tubo("Rollo", Vector3.new(64.65, 5.25, -1.05), Vector3.new(64.65, 5.25, -0.75), 0.3, Color3.fromRGB(160, 156, 140), Enum.Material.SmoothPlastic)
	caja("Tique", 64.5, 4.7, -0.95, 64.52, 5.15, -0.82, Color3.fromRGB(160, 156, 140), Enum.Material.SmoothPlastic)
end

local function mostrador(mapa: Folder)
	modelo("Barra")
	-- La pieza del mostrador (choca): del lado del cliente; detrás quedan los huecos del que cobra.
	local cuerpo = P.bloque(mapa, "Mostrador", Vector3.new(1.8, 3.35, 11), CFrame.new(64.7, SUELO + 1.675, -1), MADERA,
		Enum.Material.Wood, true)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Tienda"
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.ActionText = "Shop"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = cuerpo
	local metal = Enum.Material.Metal
	caja("Encimera", 63.5, 3.85, -6.7, 66.5, 4.05, 4.7, Color3.fromRGB(98, 92, 82), Enum.Material.Plastic)
	caja("Canto", 63.44, 3.83, -6.7, 63.5, 4.07, 4.7, COLOR.Metal, metal)
	-- Cara del cliente: zócalo de goma, franja roja, juntas de los tableros y rozaduras.
	caja("Zocalo", 63.74, SUELO + 0.04, -6.5, 63.8, 1, 4.5, COLOR.Goma, Enum.Material.Rubber)
	caja("Franja", 63.76, 3.35, -6.5, 63.8, 3.65, 4.5, COLOR.Rojo, Enum.Material.SmoothPlastic)
	for _, z in { -3.75, -1, 1.75 } do
		caja("Junta", 63.77, 1, z - 0.03, 63.8, 3.35, z + 0.03, MADERA:Lerp(Color3.new(), 0.4), Enum.Material.Wood)
	end
	mancha(Vector3.new(63.77, 1.4, 0.5), -Vector3.xAxis, 3, 1, MUGRE, 0.5)
	-- Lado del que cobra: costados, dos baldas y un divisor, con bolsas, papeles, un botiquín y un bate escondido.
	for _, z in { -6.5, 4.4 } do
		caja("Costado", 65.6, SUELO, z, 66.4, 3.85, z + 0.1, MADERA, Enum.Material.Wood)
	end
	for _, y in { 1.55, 2.65 } do
		caja("Balda", 65.6, y, -6.4, 66.35, y + 0.08, 4.4, MADERA:Lerp(Color3.new(), 0.2), Enum.Material.Wood)
	end
	caja("Divisor", 65.65, SUELO, -1.05, 66.4, 3.85, -0.95, MADERA, Enum.Material.Wood)
	dePie("Bolsas", Vector3.new(66.0, 2.73, -4.5), 0.5, 0.7, Color3.fromRGB(150, 146, 136), Enum.Material.Plastic)
	caja("Papeles", 65.7, 1.63, -3.2, 66.3, 1.85, -2.2, PAPEL, Enum.Material.SmoothPlastic)
	caja("Botiquin", 65.7, 2.73, 0.4, 66.3, 3.2, 1.4, Color3.fromRGB(110, 40, 34), Enum.Material.Plastic)
	-- El bate, apoyado delante de los huecos (a mano del que cobra), sin atravesar las baldas.
	tubo("Bate", Vector3.new(66.62, SUELO + 0.15, 3.95), Vector3.new(66.52, 3.6, 3.5), 0.24, Color3.fromRGB(110, 84, 56), Enum.Material.Wood)
	caja("Cajas", 65.7, SUELO, -6.3, 66.3, 1.4, -5.2, CARTON, Enum.Material.Cardboard)

	-- Encima: alfombrilla, caja registradora, lámpara, terminal de lotería, chucherías y boletos.
	caja("Alfombrilla", 63.8, 4.05, -0.3, 64.6, 4.08, 0.6, COLOR.Goma, Enum.Material.Rubber)
	registradora()
	dePie("Lampara", Vector3.new(65.9, 4.05, -5.6), 0.6, 0.1, Color3.fromRGB(40, 40, 40), metal)
	barra("Lampara", Vector3.new(65.9, 4.15, -5.6), Vector3.new(66, 5.12, -5.3), 0.08, Color3.fromRGB(40, 40, 40), metal)
	tubo("Pantalla", Vector3.new(66, 5.2, -5.3), Vector3.new(65.75, 4.85, -4.9), 0.5, Color3.fromRGB(40, 56, 44), metal)
	local bombilla = P.bola(grupo, "Bombilla", Vector3.new(0.24, 0.24, 0.24), CFrame.new(65.73, 4.8, -4.86), COLOR.Bombilla,
		Enum.Material.SmoothPlastic)
	P.luz(bombilla, "PointLight", 0.45, 10, Color3.fromRGB(255, 190, 130))
	caja("Terminal", 65.2, 4.05, -4.4, 65.9, 4.45, -3.6, Color3.fromRGB(50, 52, 54), Enum.Material.Plastic)
	pieza("Pantalla", Vector3.new(0.05, 0.32, 0.6), CFrame.new(65.32, 4.62, -4) * CFrame.Angles(0, 0, math.rad(20)), Color3.fromRGB(36, 44, 40),
		Enum.Material.SmoothPlastic)
	caja("Bandeja", 65.25, 4.45, -4.35, 65.45, 4.5, -3.65, Color3.fromRGB(40, 40, 40), Enum.Material.Plastic)
	caja("Expositor", 63.6, 4.05, 1.3, 64.5, 4.3, 2.7, COLOR.MetalOscuro, metal)
	caja("Expositor", 64.05, 4.3, 1.3, 64.5, 4.55, 2.7, COLOR.MetalOscuro, metal)
	for k = 0, 2 do
		local z = 1.35 + k * 0.45
		caja("Chuches", 63.62, 4.3, z, 64.0, 4.55, z + 0.42, color(PRODUCTOS), Enum.Material.SmoothPlastic)
		caja("Chuches", 64.07, 4.55, z, 64.48, 4.8, z + 0.42, color(PRODUCTOS), Enum.Material.SmoothPlastic)
	end
	local urna = caja("Loteria", 63.9, 4.05, 3, 64.9, 4.95, 4.3, Color3.fromRGB(140, 150, 156), Enum.Material.SmoothPlastic)
	urna.Transparency = 0.7
	urna.CastShadow = false
	for k = 0, 4 do
		local z = 3.15 + k * 0.22
		caja("Boleto", 64.1, 4.1, z, 64.7, 4.85, z + 0.16, ({ Color3.fromRGB(120, 44, 40), Color3.fromRGB(48, 66, 110),
			Color3.fromRGB(62, 100, 58), Color3.fromRGB(150, 128, 56), Color3.fromRGB(92, 56, 100) })[k + 1], Enum.Material.SmoothPlastic)
	end
	-- Taburete del que cobra (asiento de cuero roto).
	local sitio = Vector3.new(67.6, SUELO + 0.04, -1.4)
	dePie("Taburete", sitio, 1.0, 0.1, COLOR.MetalOscuro, metal)
	dePie("Taburete", sitio + Vector3.new(0, 0.1, 0), 0.16, 2.0, COLOR.Metal, metal)
	dePie("Asiento", sitio + Vector3.new(0, 2.1, 0), 0.95, 0.28, Color3.fromRGB(70, 30, 26), Enum.Material.Leather)
	dePie("Espuma", sitio + Vector3.new(0.1, 2.38, 0.05), 0.3, 0.02, Color3.fromRGB(150, 130, 80), Enum.Material.Fabric)
	-- Tiques tirados delante.
	pieza("Tique", Vector3.new(0.3, 0.02, 0.5), CFrame.new(62.9, SUELO + 0.05, -2.3) * CFrame.Angles(0, 0.7, 0), Color3.fromRGB(160, 156, 140),
		Enum.Material.SmoothPlastic)
	pieza("Tique", Vector3.new(0.3, 0.02, 0.4), CFrame.new(63.2, SUELO + 0.05, 2.6) * CFrame.Angles(0, -0.4, 0), Color3.fromRGB(160, 156, 140),
		Enum.Material.SmoothPlastic)
end

---------------------------------------------------------------------------------------------------------------------
-- Detrás del mostrador (pared este), el "mostrador de clases y cosméticos", todo de adorno: un tablero de agujeros con
-- las linternas de colores de Config.Cosmeticos (con su precio) y un corcho con una nota y una foto por cada clase de
-- Config.Clases. Encima, una balda con la radio vieja (contrato: Radio); al lado, el tabaco.

local XP = X1 - 1.28 -- cara de delante de los tableros (de 0,14; detrás, el forro de la pared en x = 68,89)

local function tableroLinternas()
	local tablero = caja("Tablero", XP, 3.6, -6, XP + 0.14, 7.6, -0.6, Color3.fromRGB(122, 96, 66), Enum.Material.Cardboard)
	-- Los agujeros: puntos oscuros pintados en la cara de delante (no son piezas).
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Left
	gui.LightInfluence = 1
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 25
	local columnas, filas = 12, 9
	for i = 1, columnas do
		for j = 1, filas do
			local punto = Instance.new("Frame")
			punto.BorderSizePixel = 0
			punto.BackgroundColor3 = Color3.fromRGB(26, 22, 18)
			punto.AnchorPoint = Vector2.new(0.5, 0.5)
			punto.Size = UDim2.fromOffset(3, 3)
			punto.Position = UDim2.fromScale((i - 0.5) / columnas, (j - 0.5) / filas)
			punto.Parent = gui
		end
	end
	gui.Parent = tablero
	local linternas = {}
	for _, c in Config.Cosmeticos do
		if c.Tipo == "Linterna" and #linternas < 6 then
			table.insert(linternas, c)
		end
	end
	local metal = Enum.Material.Metal
	for i, c in linternas do
		local fila, col = (i - 1) // 3, (i - 1) % 3
		local enFila = math.min(3, #linternas - fila * 3)
		local z = -3.3 + (col - (enFila - 1) / 2) * 1.6
		local y = if fila == 0 then 7.35 else 5.45 -- el gancho
		local luz = Color3.fromRGB(c.Color[1], c.Color[2], c.Color[3])
		caja("Gancho", XP - 0.42, y - 0.03, z - 0.03, XP, y + 0.03, z + 0.03, COLOR.Metal, metal)
		caja("Carton", XP - 0.1, y - 1.25, z - 0.45, XP - 0.06, y + 0.08, z + 0.45, luz:Lerp(Color3.fromRGB(30, 28, 26), 0.7), Enum.Material.Cardboard)
		caja("Correa", XP - 0.38, y - 0.3, z - 0.06, XP - 0.34, y, z + 0.06, COLOR.Goma, Enum.Material.Fabric)
		local pie = Vector3.new(XP - 0.36, y - 1.2, z)
		dePie("Cabeza", pie, 0.44, 0.27, luz:Lerp(Color3.fromRGB(30, 30, 30), 0.65), metal)
		dePie("Linterna", pie + Vector3.new(0, 0.27, 0), 0.3, 0.63, luz:Lerp(Color3.fromRGB(30, 30, 30), 0.5), metal)
		dePie("Cristal", pie - Vector3.new(0, 0.02, 0), 0.38, 0.02, luz:Lerp(Color3.fromRGB(30, 30, 30), 0.15), Enum.Material.SmoothPlastic)
		local precio = caja("Precio", XP - 0.08, y - 1.5, z - 0.25, XP - 0.04, y - 1.27, z + 0.25, Color3.fromRGB(168, 162, 140),
			Enum.Material.SmoothPlastic)
		P.letrero(precio, Enum.NormalId.Left, tostring(c.Precio), Color3.fromRGB(40, 34, 30))
	end
	-- Ganchos vacíos (se vendieron).
	for _, g in { { 7.35, -0.95 }, { 5.45, -5.5 }, { 5.45, -0.95 } } do
		caja("Gancho", XP - 0.42, g[1] - 0.03, g[2] - 0.03, XP, g[1] + 0.03, g[2] + 0.03, COLOR.Metal, metal)
	end
end

local function corcho()
	caja("Corcho", XP, 4.1, 0.2, XP + 0.14, 7.3, 4.9, Color3.fromRGB(128, 92, 60), Enum.Material.Sand)
	local marco = Color3.fromRGB(58, 42, 30)
	caja("Marco", XP - 0.04, 7.3, 0.05, XP + 0.16, 7.45, 5.05, marco, Enum.Material.Wood)
	caja("Marco", XP - 0.04, 3.95, 0.05, XP + 0.16, 4.1, 5.05, marco, Enum.Material.Wood)
	caja("Marco", XP - 0.04, 4.1, 0.05, XP + 0.16, 7.3, 0.2, marco, Enum.Material.Wood)
	caja("Marco", XP - 0.04, 4.1, 4.9, XP + 0.16, 7.3, 5.05, marco, Enum.Material.Wood)
	local notas = { Color3.fromRGB(150, 140, 90), Color3.fromRGB(160, 156, 140), Color3.fromRGB(150, 120, 112) }
	local chinchetas = { Color3.fromRGB(120, 34, 30), Color3.fromRGB(44, 60, 110), Color3.fromRGB(56, 96, 50) }
	local fuera = -Vector3.xAxis
	local suave = Enum.Material.SmoothPlastic
	local clavos = {}
	for i = 1, math.min(#Config.Clases, 6) do
		local fila, col = (i - 1) // 3, (i - 1) % 3
		local z, y = 1.15 + col * 1.4 + azar:NextNumber(-0.1, 0.1), (if fila == 0 then 6.45 else 4.95) + azar:NextNumber(-0.08, 0.08)
		-- Foto (polaroid con una cara borrosa) y, encima de una esquina, la nota.
		-- (capas a 0,02 o más unas de otras: si no, Separar las engorda)
		local foto = plano(Vector3.new(XP - 0.055, y, z), fuera, azar:NextNumber(-0.12, 0.12))
		pieza("Foto", Vector3.new(0.8, 0.95, 0.02), foto, Color3.fromRGB(166, 162, 150), suave)
		pieza("Foto", Vector3.new(0.66, 0.64, 0.01), foto * CFrame.new(0, 0.1, -0.03), Color3.fromRGB(50, 46, 42), suave)
		pieza("Cara", Vector3.new(0.22, 0.28, 0.01), foto * CFrame.new(azar:NextNumber(-0.12, 0.12), 0.12, -0.055), Color3.fromRGB(104, 96, 86), suave)
		local nota = foto * CFrame.new(-0.3, -0.55, -0.04) * CFrame.Angles(0, 0, azar:NextNumber(-0.15, 0.15))
		pieza("Nota", Vector3.new(0.75, 0.6, 0.02), nota, notas[(i - 1) % #notas + 1], suave)
		renglones(nota, 0.6, 0.12, 3, 0.13)
		local clavo = (foto * CFrame.new(0, 0.4, -0.06)).Position
		P.bola(grupo, "Chincheta", Vector3.new(0.12, 0.12, 0.12), CFrame.new(clavo), chinchetas[(i - 1) % #chinchetas + 1], suave)
		table.insert(clavos, clavo)
	end
	-- Hilo rojo entre algunas (como un tablón de búsqueda).
	for _, par in { { 1, 5 }, { 2, 6 }, { 5, 3 } } do
		local a, b = clavos[par[1]], clavos[par[2]]
		if a and b then
			barra("Hilo", a + Vector3.new(-0.02, 0, 0), b + Vector3.new(-0.02, 0, 0), 0.025, Color3.fromRGB(110, 30, 26), Enum.Material.Fabric)
		end
	end
end

local function baldaRadio()
	local madera = Color3.fromRGB(70, 54, 40)
	local metal, suave = Enum.Material.Metal, Enum.Material.SmoothPlastic
	caja("Balda", 68.0, 7.7, -6.3, XP + 0.12, 7.82, 5.1, madera, Enum.Material.Wood)
	for _, z in { -5.8, -0.4, 4.6 } do
		caja("Escuadra", XP - 0.26, 7.2, z - 0.04, XP, 7.7, z + 0.04, COLOR.MetalOscuro, metal)
	end
	-- La radio vieja (contrato: Radio), mirando a la tienda: altavoces, dial, botones, asa y antena.
	local radio = caja("Radio", 68.15, 7.82, 1.65, 68.7, 8.67, 3.15, Color3.fromRGB(58, 52, 44), Enum.Material.Plastic)
	P.etiqueta(radio, "Radio")
	for _, z in { 1.95, 2.85 } do
		tubo("Altavoz", Vector3.new(68.15, 8.2, z), Vector3.new(68.12, 8.2, z), 0.5, Color3.fromRGB(28, 26, 24), Enum.Material.Fabric)
	end
	caja("Dial", 68.12, 8.3, 2.25, 68.15, 8.45, 2.55, Color3.fromRGB(120, 96, 56), suave)
	for _, z in { 2.3, 2.5 } do
		tubo("Boton", Vector3.new(68.15, 8.55, z), Vector3.new(68.08, 8.55, z), 0.1, COLOR.MetalOscuro, metal)
	end
	caja("Asa", 68.38, 8.95, 1.85, 68.48, 9.03, 2.95, COLOR.MetalOscuro, metal)
	for _, z in { 1.85, 2.87 } do
		caja("Asa", 68.38, 8.67, z, 68.48, 8.95, z + 0.08, COLOR.MetalOscuro, metal)
	end
	tubo("Antena", Vector3.new(68.3, 8.67, 3.0), Vector3.new(68.2, 9.3, 3.6), 0.04, COLOR.Metal, metal)
	-- Archivadores, una caja, un termo y una taza.
	for k, c in { Color3.fromRGB(40, 50, 74), Color3.fromRGB(96, 38, 32), Color3.fromRGB(70, 70, 66) } do
		local giro = if k == 3 then 0.3 else 0
		pieza("Archivador", Vector3.new(0.6, 1.1, 0.28), CFrame.new(68.5, 8.37, -5.9 + k * 0.3) * CFrame.Angles(giro, 0, 0), c, Enum.Material.Plastic)
	end
	caja("Caja", 68.1, 7.82, -4.2, 68.8, 8.62, -3.2, CARTON, Enum.Material.Cardboard)
	dePie("Termo", Vector3.new(68.45, 7.82, -1.5), 0.32, 0.8, Color3.fromRGB(60, 70, 64), metal)
	dePie("Termo", Vector3.new(68.45, 8.62, -1.5), 0.34, 0.15, COLOR.MetalOscuro, metal)
	dePie("Taza", Vector3.new(68.4, 7.82, 0.3), 0.28, 0.32, Color3.fromRGB(130, 124, 110), suave)
end

local function tabaco()
	local x0, z0, z1 = 68.3, -10.2, -7.1
	local madera = Color3.fromRGB(34, 30, 28)
	caja("Tabaco", XP + 0.06, 4.2, z0, XP + 0.12, 7.6, z1, madera, Enum.Material.Wood)
	for _, z in { z0, z1 - 0.08 } do
		caja("Tabaco", x0, 4.2, z, XP + 0.06, 7.6, z + 0.08, madera, Enum.Material.Wood)
	end
	caja("Tabaco", x0, 7.52, z0 + 0.08, XP + 0.06, 7.6, z1 - 0.08, madera, Enum.Material.Wood)
	local cajetillas = { Color3.fromRGB(120, 40, 34), Color3.fromRGB(150, 146, 132), Color3.fromRGB(44, 58, 92), Color3.fromRGB(136, 114, 60),
		Color3.fromRGB(52, 80, 56) }
	for k = 0, 3 do
		local y = 4.2 + k * 0.85
		caja("Balda", x0, y, z0 + 0.08, XP + 0.06, y + 0.06, z1 - 0.08, madera, Enum.Material.Wood)
		local z = z0 + 0.12
		while z < z1 - 0.5 do
			local ancho = azar:NextNumber(0.6, 1.0)
			if azar:NextNumber() < 0.85 then
				caja("Cajetillas", x0 + 0.12, y + 0.06, z, XP + 0.02, y + 0.06 + azar:NextNumber(0.36, 0.42), math.min(z + ancho, z1 - 0.12),
					color(cajetillas), Enum.Material.SmoothPlastic)
			end
			z += ancho + 0.05
		end
	end
end

---------------------------------------------------------------------------------------------------------------------
-- Rincones: cafetera, cubo con fregona, cartel de suelo mojado, cajas, extintor, espejo de vigilancia, cámara, reloj
-- parado, cuadro de la luz y, junto a la puerta de atrás, una mancha pequeña de sangre seca (Moderate como mucho).

local function cafetera()
	local madera = Color3.fromRGB(64, 54, 44)
	local metal, suave = Enum.Material.Metal, Enum.Material.SmoothPlastic
	caja("Mueble", 61.8, SUELO, 11.3, 65.2, 3.5, Z1 - 1.15, madera, Enum.Material.Wood, true)
	for k = 0, 1 do
		local x = 61.95 + k * 1.65
		caja("Puerta", x, 0.8, 11.26, x + 1.5, 3.25, 11.3, madera:Lerp(Color3.new(), 0.2), Enum.Material.Wood)
		caja("Tirador", x + (if k == 0 then 1.3 else 0.1), 2.6, 11.2, x + (if k == 0 then 1.4 else 0.2), 3.0, 11.26, COLOR.Metal, metal)
	end
	caja("Encimera", 61.7, 3.5, 11.2, 65.3, 3.65, Z1 - 1.15, Color3.fromRGB(92, 86, 76), Enum.Material.Plastic)
	-- La cafetera de goteo con su jarra a medias y la lucecita roja.
	local negro = Color3.fromRGB(30, 30, 30)
	caja("Cafetera", 62.4, 3.65, 12.4, 63.3, 5.1, 12.85, negro, Enum.Material.Plastic)
	caja("Cafetera", 62.4, 4.8, 12.05, 63.3, 5.1, 12.4, negro, Enum.Material.Plastic)
	dePie("Placa", Vector3.new(62.85, 3.65, 12.2), 0.62, 0.05, Color3.fromRGB(40, 40, 40), metal)
	local jarra = dePie("Jarra", Vector3.new(62.85, 3.7, 12.2), 0.55, 0.6, Color3.fromRGB(70, 74, 76), suave)
	jarra.Transparency = 0.45
	dePie("Cafe", Vector3.new(62.85, 3.72, 12.2), 0.5, 0.25, Color3.fromRGB(30, 18, 12), suave)
	dePie("Tapa", Vector3.new(62.85, 4.3, 12.2), 0.42, 0.08, negro, Enum.Material.Plastic)
	caja("Asa", 62.5, 3.85, 12.17, 62.58, 4.2, 12.23, negro, Enum.Material.Plastic)
	caja("Piloto", 63.05, 4.9, 12.02, 63.12, 4.97, 12.05, Color3.fromRGB(150, 34, 28), suave)
	-- Vasos, azucarero, servilletero, un vaso aplastado y café derramado.
	dePie("Vasos", Vector3.new(63.7, 3.65, 12.4), 0.32, 0.9, Color3.fromRGB(168, 164, 150), suave)
	dePie("Vasos", Vector3.new(64.1, 3.65, 12.45), 0.32, 0.65, Color3.fromRGB(168, 164, 150), suave)
	dePie("Azucarero", Vector3.new(64.6, 3.65, 12.3), 0.3, 0.45, Color3.fromRGB(150, 156, 156), suave).Transparency = 0.3
	dePie("Azucarero", Vector3.new(64.6, 4.1, 12.3), 0.3, 0.12, COLOR.Metal, metal)
	caja("Servilletero", 64.85, 3.65, 11.6, 65.15, 4.0, 12.1, COLOR.Metal, metal)
	pieza("Vaso", Vector3.new(0.35, 0.18, 0.28), CFrame.new(62.0, 3.74, 11.7) * CFrame.Angles(0.3, 0.6, 0.2), Color3.fromRGB(160, 156, 142), suave)
	mancha(Vector3.new(63.4, 3.67, 11.75), Vector3.yAxis, 0.9, 0.7, Color3.fromRGB(40, 24, 14), 0.3)
end

local function rincones()
	modelo("Rincones")
	cafetera()
	-- Cubo con fregona (amarillo apagado) en el rincón y el cartel de suelo mojado junto a lo fregado.
	local amarillo = Color3.fromRGB(146, 124, 52)
	local cubo = Vector3.new(66.1, SUELO + 0.04, 12.05)
	dePie("Cubo", cubo, 1.0, 1.0, amarillo, Enum.Material.Plastic)
	dePie("Agua", cubo + Vector3.new(0, 0.85, 0), 0.9, 0.05, Color3.fromRGB(56, 52, 40), Enum.Material.SmoothPlastic)
	caja("Escurridor", 65.85, 1.4, 11.55, 66.35, 1.8, 11.95, Color3.fromRGB(110, 94, 44), Enum.Material.Plastic)
	tubo("Fregona", cubo + Vector3.new(0.1, 0.6, 0.1), Vector3.new(66.5, 5.2, Z1 - 1.25), 0.1, Color3.fromRGB(96, 92, 84), Enum.Material.Metal)
	P.bola(grupo, "Mocho", Vector3.new(0.6, 0.6, 0.6), CFrame.new(cubo + Vector3.new(0.1, 0.75, 0.1)), Color3.fromRGB(120, 116, 100),
		Enum.Material.Fabric)
	local cartel = Vector3.new(62.0, SUELO + 0.04, 4.6)
	for _, s in { -1, 1 } do
		local panel = CFrame.new(cartel + Vector3.new(s * 0.24, 1.08, 0)) * CFrame.Angles(0, 0, s * math.rad(12))
		pieza("Cartel", Vector3.new(0.06, 2.2, 1.0), panel, amarillo, Enum.Material.Plastic)
		pieza("Aviso", Vector3.new(0.02, 0.45, 0.45), panel * CFrame.new(s * 0.04, 0.3, 0) * CFrame.Angles(math.rad(45), 0, 0),
			Color3.fromRGB(26, 24, 20), Enum.Material.SmoothPlastic)
	end
	caja("Asa", 61.9, SUELO + 2.18, 4.35, 62.1, SUELO + 2.3, 4.85, amarillo, Enum.Material.Plastic)
	-- Cajas de cartón apiladas en el rincón de la puerta de atrás.
	pieza("Caja", Vector3.new(1.7, 1.4, 1.8), CFrame.new(67.95, SUELO + 0.74, 11.85) * CFrame.Angles(0, 0.05, 0), CARTON, Enum.Material.Cardboard)
	pieza("Caja", Vector3.new(1.4, 1.2, 1.5), CFrame.new(67.9, SUELO + 2.04, 11.8) * CFrame.Angles(0, -0.25, 0), CARTON:Lerp(MUGRE, 0.2),
		Enum.Material.Cardboard)
	-- Revistero delante del escaparate del norte (por delante de la repisa; se ve desde fuera), con revistas
	-- desteñidas echadas hacia atrás.
	local madera, xr = Color3.fromRGB(62, 48, 36), X0 + 1.55
	caja("Revistero", xr, SUELO + 0.04, -10.85, xr + 0.07, 3.1, -7.15, madera, Enum.Material.Wood)
	for _, z in { -10.85, -7.23 } do
		caja("Revistero", xr + 0.07, SUELO + 0.04, z, xr + 0.75, 3.1, z + 0.08, madera, Enum.Material.Wood)
	end
	for k = 0, 2 do
		local y = 1.0 + k * 0.85
		caja("Revistero", xr + 0.07, y, -10.77, xr + 0.75, y + 0.06, -7.23, madera, Enum.Material.Wood)
		caja("Revistero", xr + 0.7, y + 0.06, -10.77, xr + 0.75, y + 0.2, -7.23, madera, Enum.Material.Wood)
		for m = 0, 2 do
			local z = -10.2 + m * 1.15 + azar:NextNumber(-0.08, 0.08)
			pieza("Revista", Vector3.new(0.05, 0.7, 0.62), CFrame.new(xr + 0.3, y + 0.41, z) * CFrame.Angles(0, 0, math.rad(14)),
				color(PRODUCTOS):Lerp(PAPEL, 0.25), Enum.Material.SmoothPlastic)
		end
	end
	-- Leña a la venta bajo el escaparate del sur: haces de tres troncos atados con fleje.
	for _, h in { { 54.2, SUELO + 0.04, 9.4 }, { 54.25, SUELO + 0.04, 10.6 }, { 54.12, SUELO + 0.44, 10.0 } } do
		for t = 0, 2 do
			local dz = (t - 1) * 0.38
			local y = h[2] + 0.2 + (if t == 1 then 0.12 else 0)
			tubo("Leña", Vector3.new(h[1] - 0.8, y, h[3] + dz), Vector3.new(h[1] + 0.8, y, h[3] + dz), 0.4, Color3.fromRGB(78, 60, 44),
				Enum.Material.Wood)
		end
		caja("Fleje", h[1] - 0.08, h[2] + 0.02, h[3] - 0.6, h[1] + 0.08, h[2] + 0.56, h[3] + 0.6, Color3.fromRGB(96, 34, 30), Enum.Material.Plastic)
	end
	-- Extintor en el machón de junto a la puerta.
	local rojo = Color3.fromRGB(112, 30, 26)
	dePie("Extintor", Vector3.new(53.45, 1.6, -4.75), 0.42, 1.25, rojo, Enum.Material.Metal)
	dePie("Valvula", Vector3.new(53.45, 2.85, -4.75), 0.16, 0.18, COLOR.MetalOscuro, Enum.Material.Metal)
	barra("Manguera", Vector3.new(53.42, 2.95, -4.62), Vector3.new(53.55, 2.0, -4.5), 0.07, COLOR.Goma, Enum.Material.Rubber)
	caja("Soporte", 53.11, 2.2, -4.95, 53.24, 2.4, -4.55, COLOR.MetalOscuro, Enum.Material.Metal)
	-- Espejo redondo de vigilancia en la esquina y una cámara (de mentira) mirando a la puerta.
	local espejo = P.bola(grupo, "Espejo", Vector3.new(1.1, 1.1, 1.1), CFrame.new(53.6, 8.55, -12.4), Color3.fromRGB(128, 132, 134),
		Enum.Material.SmoothPlastic)
	espejo.Reflectance = 0.35
	local camara = CFrame.lookAt(Vector3.new(68.3, 8.9, -9.8), Vector3.new(55, 3, 0))
	pieza("Camara", Vector3.new(0.35, 0.35, 0.8), camara, Color3.fromRGB(60, 60, 58), Enum.Material.Plastic)
	barra("Soporte", Vector3.new(68.88, 9.2, -9.8), (camara * CFrame.new(0, 0, 0.3)).Position, 0.08, COLOR.MetalOscuro, Enum.Material.Metal)
	P.bola(grupo, "Piloto", Vector3.new(0.07, 0.07, 0.07), camara * CFrame.new(0.12, 0.12, -0.41), Color3.fromRGB(120, 30, 26),
		Enum.Material.SmoothPlastic)
	-- Reloj parado (las tres y siete) encima de la estantería del norte.
	local reloj = Vector3.new(58.4, 8.25, Z0 + 1.11)
	tubo("Reloj", reloj, reloj + Vector3.new(0, 0, 0.08), 1.2, Color3.fromRGB(46, 44, 42), Enum.Material.Plastic)
	tubo("Reloj", reloj + Vector3.new(0, 0, 0.08), reloj + Vector3.new(0, 0, 0.12), 1.04, Color3.fromRGB(150, 146, 132), Enum.Material.SmoothPlastic)
	for _, a in { { math.rad(93.5), 0.3, 0.06 }, { math.rad(42), 0.42, 0.04 } } do
		local dir = Vector3.new(math.sin(a[1]), math.cos(a[1]), 0)
		pieza("Aguja", Vector3.new(a[3], a[2], 0.02), CFrame.new(reloj + Vector3.new(0, 0, 0.14) + dir * (a[2] / 2)) * CFrame.Angles(0, 0, -a[1]),
			Color3.fromRGB(26, 24, 22), Enum.Material.SmoothPlastic)
	end
	-- Cuadro de la luz junto a la puerta de atrás y la luz de emergencia de encima, fundida.
	caja("CuadroLuz", 68.6, 5, 11.1, X1 - 1.12, 6.6, 12.1, Color3.fromRGB(90, 92, 90), Enum.Material.Metal)
	dePie("Tubo", Vector3.new(68.75, 6.6, 11.6), 0.14, TECHO - 6.6, Color3.fromRGB(90, 92, 90), Enum.Material.Metal)
	caja("Emergencia", 68.6, 7.75, 8.4, X1 - 1.12, 8.15, 9.6, Color3.fromRGB(130, 130, 124), Enum.Material.Plastic)
	-- Sangre seca junto a la puerta de atrás: una salpicadura pequeña y dos gotas.
	mancha(Vector3.new(67.9, SUELO + 0.07, 9.3), Vector3.yAxis, 1.3, 1.3, SECA, 0.15, SALPICADURA, 0.8)
	mancha(Vector3.new(67.1, SUELO + 0.07, 8.6), Vector3.yAxis, 0.35, 0.35, Color3.fromRGB(60, 16, 14), 0.3)
	mancha(Vector3.new(66.7, SUELO + 0.07, 8.2), Vector3.yAxis, 0.25, 0.25, Color3.fromRGB(60, 16, 14), 0.35)
	-- Humedad y mugre en las paredes de dentro.
	for _, m in {
		{ Vector3.new(55, 8.6, Z0 + 1.13), Vector3.zAxis, 2.6, 1.6 }, { Vector3.new(64, 8.4, Z1 - 1.13), -Vector3.zAxis, 3, 1.8 },
		{ Vector3.new(X1 - 1.13, 8.9, -8.5), -Vector3.xAxis, 2, 1 }, { Vector3.new(X0 + 1.13, 8.8, 9), Vector3.xAxis, 3, 1.1 },
		{ Vector3.new(X1 - 1.13, 1.6, 6.6), -Vector3.xAxis, 1.6, 1.8 },
	} do
		mancha(m[1], m[2], m[3], m[4], HUMEDAD, 0.35)
	end
	mancha(Vector3.new(X0 + 1.13, 6.4, -12.3), Vector3.xAxis, 1.2, 1.2, Color3.fromRGB(150, 145, 135), 0.25, GRIETAS, 2)
end

---------------------------------------------------------------------------------------------------------------------

function GasolineraTienda.construir(mapa: Folder)
	tienda = Instance.new("Model")
	tienda.Name = "Tienda"
	paredes()
	escaparates()
	puerta()
	acera()
	trasera()
	suelo()
	techo()
	estanterias()
	nevera()
	congelador()
	mostrador(mapa)
	grupo = tienda:FindFirstChild("Barra") :: Instance
	tableroLinternas()
	corcho()
	baldaRadio()
	tabaco()
	rincones()
	-- Por dentro no llueve y la lluvia se oye menos (contrato: Dentro).
	grupo = tienda
	local dentro = caja("Dentro", X0, 0.2, Z0 + 1, X1 - 1, ALTO, Z1 - 1, Color3.new(), Enum.Material.SmoothPlastic)
	dentro.Transparency = 1
	dentro.CastShadow = false
	P.etiqueta(dentro, "Dentro")
	tienda.Parent = mapa
end

return GasolineraTienda
