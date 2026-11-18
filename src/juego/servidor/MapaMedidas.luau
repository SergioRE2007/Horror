-- Medidas y datos de la casa que comparten Mapa, MapaSalas, MapaAnexos y MapaBosque (solo números y tablas fijas,
-- sin estado). Medidas en studs: suelo de abajo arriba en y = 1, el de arriba en y = 14; paredes de 12 de alto.
local MapaMedidas = {}

local ABAJO, ARRIBA, ALTO = 1, 14, 12
-- Los techos de yeso de cada sala, este tanto por debajo del suelo de arriba (Separar lo engorda 0,15 y los tapaba).
local BAJO_TECHO = 0.2
-- Tejado a dos aguas con la cumbrera a lo largo de x en z = 0: sube `pendiente` por stud desde el alero (|z| = `alero`,
-- a y = 27). El Trepador anda por encima (sus medidas, en Trepador).
local TEJADO = { pendiente = 9 / 24, alero = 34.5 }

local COLOR = {
	Suelo = Color3.fromRGB(70, 64, 44), -- suelo de bosque con hojarasca (LeafyGrass)
	Camino = Color3.fromRGB(78, 72, 64),
	Tronco = Color3.fromRGB(62, 50, 42), -- corteza, como la de los pinos (shared/Piezas)
	Muro = Color3.fromRGB(116, 106, 90), -- yeso sucio de las paredes de dentro
	Fachada = Color3.fromRGB(84, 68, 54), -- tablas viejas de las paredes de fuera
	Marco = Color3.fromRGB(58, 44, 34), -- marcos de puertas y ventanas, porche
	Piso = Color3.fromRGB(78, 60, 46),
	Mueble = Color3.fromRGB(74, 54, 40),
	Oscuro = Color3.fromRGB(45, 43, 42),
	Cristal = Color3.fromRGB(140, 160, 170),
	Lampara = Color3.fromRGB(255, 214, 160),
}

-- Hueco en el suelo del bosque encima de la escalera del sótano (MapaAnexos.construirSotano).
local HUECO = { -3.5, 3.5, 33.5, 47.6 } -- x1, x2, z1, z2
-- Trampilla del sótano al patio (12.2, final de la Bestia): hueco en el techo del sótano y en el suelo del bosque, en el
-- rincón del oeste entre las cadenas del techo y los cajones. Se sube por una escalera de mano; la Bestia no cabe.
local TRAMPILLA = { -11.4, -6.9, 59.2, 62 } -- x1, x2, z1, z2
local FONDO_SOTANO = -11
-- El banco del taller del sótano (BancoCarpintero, en vestirSotano): el origen del mueble, contra la pared del fondo.
local BANCO_SOTANO = Vector3.new(-1, FONDO_SOTANO, 63.55)

-- Torre de la esquina de delante (construirTorre, más abajo).
local TORRE = { x = 39, z = -33, apotema = 8 }

-- La cama del dormitorio grande y la cara de su suelo (la cama la pone construirCasa; lo demás, vestirDormitorioGrande).
local DORMITORIO_GRANDE = {
	-- La cara de la lámina del suelo de la sala (vestirSuelos): aquí el Piso no se engorda y queda a ARRIBA (medido en
	-- Play; en la galería sí, a ARRIBA + 0,18).
	suelo = ARRIBA + 0.06,
	cama = Vector3.new(24, ARRIBA + 0.06, 3.55), -- el centro de la cama a ras del suelo, con la cabecera hacia +z
}
-- La cama del cuarto de los niños (la pone construirCasa; lo demás, vestirNinos).
local NINOS = {
	-- La del oeste, el escondite (cabecera contra la pared del fondo), sobre la lámina del suelo: aquí Separar sí engorda
	-- el Piso (su cara queda a ARRIBA + 0,15, medido en Play) y la lámina va 0,06 por encima.
	cama = Vector3.new(-35.6, ARRIBA + 0.21, 28.9),
}

MapaMedidas.ABAJO = ABAJO
MapaMedidas.ARRIBA = ARRIBA
MapaMedidas.ALTO = ALTO
MapaMedidas.BAJO_TECHO = BAJO_TECHO
MapaMedidas.TEJADO = TEJADO
MapaMedidas.COLOR = COLOR
MapaMedidas.HUECO = HUECO
MapaMedidas.TRAMPILLA = TRAMPILLA
MapaMedidas.FONDO_SOTANO = FONDO_SOTANO
MapaMedidas.BANCO_SOTANO = BANCO_SOTANO
MapaMedidas.TORRE = TORRE
MapaMedidas.DORMITORIO_GRANDE = DORMITORIO_GRANDE
MapaMedidas.NINOS = NINOS

return MapaMedidas
