-- Plano del pueblo (11.5, pedido por el usuario: "bien, pero rápido": fachadas buenas en todos los edificios y solo
-- unos pocos con interior). Lo comparten PuebloFachadas (el cascarón de cada edificio), PuebloInteriores (lo de dentro
-- de los que se entra) y PuebloCalle (calle, cementerio y lo de fuera): nadie mueve un edificio sin cambiarlo aquí.
--
-- Medidas (studs): el suelo de dentro está en y = 1; las paredes, de 1 de grueso y centradas en el contorno, así que
-- la cara de dentro queda a ancho/2 - 0,5 del centro. La puerta, un hueco de 4 x 8 en el medio de su lado. Lados:
-- "N" = -z, "S" = +z, "E" = +x, "O" = -x. La carretera llega por x -6..6 hasta z = -530.
local PuebloPlano = {}

export type Ventana = { lado: string, desde: number, planta: number }
export type Edificio = {
	nombre: string,
	x: number,
	z: number,
	ancho: number, -- en x
	largo: number, -- en z
	alto: number, -- de y = 1 al techo (con dos plantas, las dos)
	plantas: number,
	puerta: string, -- lado de la puerta
	entra: boolean, -- con interior (PuebloInteriores); si no, puerta y ventanas tapiadas
	material: string, -- "madera", "ladrillo" o "piedra"
	ventanas: { Ventana }, -- `desde` = del centro de la pared, a lo largo de ella (en x en N/S, en z en E/O)
}

-- Tamaño de las ventanas: ancho, alto y alféizar (desde el suelo de su planta).
PuebloPlano.VENTANA = { ancho = 3, alto = 4, alfeizar = 3 }
PuebloPlano.VENTANA_IGLESIA = { ancho = 3, alto = 8, alfeizar = 4 }
PuebloPlano.PUERTA = { ancho = 4, alto = 8 }
PuebloPlano.SUELO = 1

local function v(lado: string, desde: number, planta: number?): Ventana
	return { lado = lado, desde = desde, planta = planta or 1 }
end

-- Al oeste de la calle las puertas miran al este y al revés. Los de antes (tienda, casa abierta, tres cerradas,
-- iglesia, cripta y caseta) siguen donde estaban: las pistas, llaves y objetos del pueblo cuentan con ellos.
PuebloPlano.edificios = {
	-- Oeste de la calle, de la entrada al fondo.
	{ nombre = "CasaCerrada1", x = -22, z = -425, ancho = 12, largo = 12, alto = 18, plantas = 2, puerta = "E", entra = false,
		material = "madera", ventanas = { v("E", -3.8), v("E", 3.8), v("E", -3, 2), v("E", 3, 2), v("N", 0), v("S", 0, 2) } },
	{ nombre = "Tienda", x = -20, z = -455, ancho = 14, largo = 12, alto = 10, plantas = 1, puerta = "E", entra = true,
		material = "ladrillo", ventanas = { v("E", -3.8), v("E", 3.8), v("N", 2) } },
	{ nombre = "CasaCerrada2", x = -22, z = -485, ancho = 12, largo = 12, alto = 18, plantas = 2, puerta = "E", entra = false,
		material = "madera", ventanas = { v("E", -3.8), v("E", 3.8), v("E", 0, 2), v("S", -2), v("N", 2, 2) } },
	{ nombre = "CasaCerrada3", x = -22, z = -510, ancho = 12, largo = 12, alto = 10, plantas = 1, puerta = "E", entra = false,
		material = "madera", ventanas = { v("E", -3.8), v("E", 3.8), v("N", 0) } },
	-- Este de la calle.
	{ nombre = "CasaCerrada4", x = 22, z = -415, ancho = 12, largo = 12, alto = 10, plantas = 1, puerta = "O", entra = false,
		material = "madera", ventanas = { v("O", -3.8), v("O", 3.8), v("S", 0) } },
	{ nombre = "CasaAbierta", x = 20, z = -440, ancho = 12, largo = 12, alto = 10, plantas = 1, puerta = "O", entra = true,
		material = "madera", ventanas = { v("O", -3.8), v("O", 3.8), v("N", 0), v("E", 2) } },
	{ nombre = "CasaCerrada5", x = 22, z = -462, ancho = 12, largo = 12, alto = 18, plantas = 2, puerta = "O", entra = false,
		material = "ladrillo", ventanas = { v("O", -3.8), v("O", 3.8), v("O", -3, 2), v("O", 3, 2), v("S", 0, 2) } },
	-- La iglesia mirando a la calle (el campanario, fuera, en la esquina del noroeste) y el cementerio detrás.
	{ nombre = "Iglesia", x = 30, z = -500, ancho = 16, largo = 28, alto = 16, plantas = 1, puerta = "O", entra = true,
		material = "piedra", ventanas = { v("O", -9), v("O", 7), v("E", -9), v("E", -3), v("E", 3), v("E", 9), v("S", 0) } },
	{ nombre = "Cripta", x = 74, z = -515, ancho = 8, largo = 8, alto = 8, plantas = 1, puerta = "O", entra = true,
		material = "piedra", ventanas = {} },
	{ nombre = "CasetaEnterrador", x = 78, z = -481, ancho = 6, largo = 6, alto = 8, plantas = 1, puerta = "O", entra = true,
		material = "madera", ventanas = { v("S", 0) } },
	-- Al final de la carretera, cerrando la calle.
	-- La puerta, al sur: la calle llega desde +z.
	{ nombre = "CasaFinal", x = 0, z = -548, ancho = 16, largo = 12, alto = 18, plantas = 2, puerta = "S", entra = false,
		material = "madera", ventanas = { v("S", -4.5), v("S", 4.5), v("S", -4.5, 2), v("S", 0, 2), v("S", 4.5, 2), v("E", 0) } },
} :: { Edificio }

-- Campanario de la iglesia (fuera, pegado a la pared oeste): centro, lado y alto.
PuebloPlano.CAMPANARIO = { x = 19, z = -514, lado = 6, alto = 28 }
-- Cementerio: x1, x2, z1, z2 (la entrada, en la valla oeste entre z -503 y -497, frente a la puerta de la iglesia).
PuebloPlano.CEMENTERIO = { x1 = 42, x2 = 82, z1 = -525, z2 = -475, entrada = { -503, -497 } }

PuebloPlano.LADOS = { N = Vector3.new(0, 0, -1), S = Vector3.new(0, 0, 1), E = Vector3.new(1, 0, 0), O = Vector3.new(-1, 0, 0) }

function PuebloPlano.buscar(nombre: string): Edificio
	for _, e in PuebloPlano.edificios do
		if e.nombre == nombre then
			return e
		end
	end
	error(`[PuebloPlano] no hay edificio {nombre}`)
end

-- Caras de dentro de las paredes: x1, x2, z1, z2.
function PuebloPlano.dentro(e: Edificio): (number, number, number, number)
	return e.x - e.ancho / 2 + 0.5, e.x + e.ancho / 2 - 0.5, e.z - e.largo / 2 + 0.5, e.z + e.largo / 2 - 0.5
end

-- Alto de cada planta.
function PuebloPlano.altoPlanta(e: Edificio): number
	return e.alto / e.plantas
end

-- Centro del hueco de una ventana (en medio del grueso de la pared), con -Z hacia fuera (como Fachada.ventana).
function PuebloPlano.ventanaCF(e: Edificio, w: Ventana): CFrame
	local medidas = if e.nombre == "Iglesia" then PuebloPlano.VENTANA_IGLESIA else PuebloPlano.VENTANA
	local fuera = PuebloPlano.LADOS[w.lado]
	local y = PuebloPlano.SUELO + (w.planta - 1) * PuebloPlano.altoPlanta(e) + medidas.alfeizar + medidas.alto / 2
	local centro = if w.lado == "N" or w.lado == "S"
		then Vector3.new(e.x + w.desde, y, e.z + fuera.Z * e.largo / 2)
		else Vector3.new(e.x + fuera.X * e.ancho / 2, y, e.z + w.desde)
	return CFrame.lookAt(centro, centro + fuera)
end

-- Centro del hueco de la puerta a ras del suelo, con -Z hacia fuera.
function PuebloPlano.puertaCF(e: Edificio): CFrame
	local fuera = PuebloPlano.LADOS[e.puerta]
	local centro = Vector3.new(e.x + fuera.X * e.ancho / 2, PuebloPlano.SUELO, e.z + fuera.Z * e.largo / 2)
	return CFrame.lookAt(centro, centro + fuera)
end

return PuebloPlano
