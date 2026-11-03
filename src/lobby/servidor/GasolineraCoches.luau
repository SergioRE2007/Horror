-- Los coches del lobby (pedido por el usuario: "el lobby es un poco feo"): berlinas y rancheras viejas de los 80,
-- aparcadas en fila junto a la carretera mirando al bosque (-Z), de colores desteñidos, sucias y con óxido. Te subes
-- con tus amigos y el dueño arranca (lobby/servidor/Coches; lo que se enciende y se mueve, en el cliente:
-- GasolineraVista y SalidaVista). Lo llama Gasolinera con la carpeta workspace.Coches.
-- Cada coche es un Model "Coche<n>" con la etiqueta "Coche" y estas piezas (las que lee el resto del juego):
--   Carroceria (PrimaryPart: el cuerpo de abajo; su LookVector, hacia delante), Asiento1..Asiento<Plazas> (Seat
--   anclados e invisibles dentro del cuerpo, mirando hacia delante), Faro ×2 (con el SpotLight "Haz" y el PointLight
--   "Brillo", apagados), Piloto ×2 (con su PointLight rojo, apagado), Limpia1 y Limpia2 (con los atributos Eje y
--   Normal: el punto donde giran y el eje de giro, perpendicular al parabrisas), el Attachment "Escape" en el tubo y
--   las cuatro ruedas "Rueda" (cilindros; la llanta es otra pieza, "Llanta").
-- Choca solo el cuerpo (de los bajos a la cintura de las ventanillas); cristales, techo, montantes y detalles no. Así,
-- quien salta del asiento sale por arriba y no se queda encerrado.
-- Medidas en el espacio del coche: x a la derecha, y hacia arriba desde el suelo, z hacia atrás (delante = -z).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local P = require(script.Parent.GasolineraPiezas)

local GasolineraCoches = {}

local COLOR = P.COLOR

-- Sitio de cada coche en la explanada (x = 14), en orden, y su giro a ojo (aparcados no del todo rectos).
local SITIOS = { -24, -8, 8, 24 }
local GIROS = { -1.2, 0.8, 0.3, -1.6 }

-- Medidas del coche (studs). La cabeza de un R15 sentado llega ~3,4 por encima del asiento: con el asiento a 1,85
-- queda en 5,25, por debajo del techo (5,7).
local LARGO = 6.75 -- medio largo de la carrocería, sin parachoques
local ANCHO = 3.1 -- medio ancho
local BAJOS = 0.6 -- los bajos (de aquí al suelo, aire)
local CAPO = 2.8 -- la tapa del capó delante, las aletas y el maletero
local CINTURA = 3.1 -- donde empiezan las ventanillas (y acaba el capó junto al parabrisas)
local TECHO = 5.7 -- la cara de abajo del techo
local CRISTAL = 2.95 -- el plano de las ventanillas de los lados (el techo es algo más estrecho que el cuerpo)
local RUEDA = 1.15 -- radio de las ruedas
local EJES = { -4.3, 4.2 } -- z del eje de delante y del de atrás
local HUECO = 1.3 -- medio hueco del paso de rueda (algo más que la rueda)
local ARCO = 2.45 -- lo alto del paso de rueda
local NUCLEO = 2.2 -- medio ancho del cuerpo entre las ruedas
local PARABRISAS = -2.75 -- z de abajo del parabrisas (lo de arriba, en z = -0,95)
local ASIENTO = 1.85 -- la cara de arriba de los asientos
local PLAZAS = { Vector2.new(-1.4, -0.35), Vector2.new(1.4, -0.35), Vector2.new(-1.4, 2.75), Vector2.new(1.4, 2.75),
	Vector2.new(0, 2.75) } -- x, z de cada asiento; el 1 es el del conductor (a la izquierda)

local CROMO = Color3.fromRGB(122, 122, 118) -- cromado viejo, sin brillo
local NEGRO = Color3.fromRGB(26, 26, 26) -- plásticos y gomas negras
local OXIDO = Color3.fromRGB(88, 52, 34)
local BARRO = Color3.fromRGB(58, 46, 34)
local LUZ_FARO = Color3.fromRGB(255, 236, 200)
local LUZ_PILOTO = Color3.fromRGB(255, 40, 30)

type Estilo = {
	ranchera: boolean,
	pintura: Color3,
	tapiceria: Color3,
	matricula: string,
	techo: Color3?, -- techo de vinilo
	capo: Color3?, -- capó cambiado, en imprimación gris
	rueda: number?, -- la rueda distinta (1-4: delante izquierda, delante derecha, detrás izquierda, detrás derecha)
	abollado: boolean?, -- puerta de delante izquierda abollada y rozada
	grieta: boolean?, -- parabrisas rajado
	ambientador: boolean?,
	baca: boolean?,
}

-- Los cuatro, de colores desteñidos distintos (si Config.Coches.Cuantos pide más, se repiten).
local ESTILOS: { Estilo } = {
	{ ranchera = false, pintura = Color3.fromRGB(50, 62, 50), tapiceria = Color3.fromRGB(92, 78, 60), matricula = "LE-4721-B",
		techo = Color3.fromRGB(44, 36, 30), ambientador = true },
	{ ranchera = true, pintura = Color3.fromRGB(84, 64, 48), tapiceria = Color3.fromRGB(62, 48, 38), matricula = "O-2180-AF",
		rueda = 4, grieta = true, baca = true },
	{ ranchera = false, pintura = Color3.fromRGB(74, 82, 92), tapiceria = Color3.fromRGB(50, 54, 62), matricula = "BU-0937-C",
		abollado = true },
	{ ranchera = true, pintura = Color3.fromRGB(88, 38, 40), tapiceria = Color3.fromRGB(66, 42, 38), matricula = "ZA-1564-D",
		capo = Color3.fromRGB(96, 96, 92), ambientador = true },
}

local function oscuro(c: Color3, k: number): Color3
	return Color3.new(c.R * k, c.G * k, c.B * k)
end

-- Construye un coche. `base` = el centro del suelo debajo del coche, mirando hacia delante.
local function coche(n: number, base: CFrame, estilo: Estilo, carpeta: Instance)
	local modelo = Instance.new("Model")
	modelo.Name = `Coche{n}`
	modelo.ModelStreamingMode = Enum.ModelStreamingMode.Atomic -- llega entero al cliente (SalidaVista lo copia)
	local pintura = estilo.pintura
	local finCabina = if estilo.ranchera then 6.4 else 4.75 -- z donde acaba el habitáculo (y el maletero empieza)

	-- Un bloque de x0 a x1, y0 a y1, z0 a z1 en el espacio del coche.
	local function caja(nombre: string, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, color: Color3,
		material: Enum.Material?, choca: boolean?): Part
		local tam = Vector3.new(math.abs(x1 - x0), y1 - y0, z1 - z0)
		return P.bloque(modelo, nombre, tam, base * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color,
			material or Enum.Material.SmoothPlastic, choca)
	end
	-- Una cuña: triángulo rectángulo con el ángulo recto en M y los catetos e y s (perpendiculares), de `grueso` a lo
	-- largo de e × s, centrada en M. Todo en el espacio del coche.
	local function cuna(nombre: string, M: Vector3, e: Vector3, s: Vector3, grueso: number, color: Color3,
		material: Enum.Material?, choca: boolean?): WedgePart
		local Y, Z = s.Unit, -e.Unit
		local marco = CFrame.fromMatrix(M + e / 2 + s / 2, Y:Cross(Z), Y, Z)
		return P.cuna(modelo, nombre, Vector3.new(grueso, s.Magnitude, e.Magnitude), base * marco, color,
			material or Enum.Material.SmoothPlastic, choca)
	end
	-- Una pieza fina girada (cristales, montantes, escobillas): `cf` en el espacio del coche.
	local function girada(nombre: string, tam: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
		local p = P.bloque(modelo, nombre, tam, base * cf, color, material or Enum.Material.SmoothPlastic)
		p.CastShadow = false
		return p
	end
	local function cristal(p: BasePart)
		p.Transparency = 0.7 -- no Glass: tapa lo transparente de detrás (las ramas de los pinos)
		p.CastShadow = false
	end
	local function caraLado(lado: number): Enum.NormalId
		return if lado > 0 then Enum.NormalId.Right else Enum.NormalId.Left
	end

	------------------------------------------------------------------ el cuerpo (choca)
	-- Entre las ruedas, de punta a punta; delante y detrás, todo el ancho. Por fuera, los paneles de los lados dejan los
	-- huecos de las ruedas.
	local del, tras = EJES[1], EJES[2]
	local carroceria = caja("Carroceria", -NUCLEO, NUCLEO, BAJOS, CAPO, del - HUECO, tras + HUECO, pintura, nil, true)
	local morro = caja("Morro", -ANCHO, ANCHO, BAJOS, CAPO, -LARGO, del - HUECO, pintura, nil, true)
	local cola = caja("Cola", -ANCHO, ANCHO, BAJOS, CAPO, tras + HUECO, LARGO, pintura, nil, true)
	P.mancha(morro, Enum.NormalId.Front, nil, BARRO, 0.45)
	P.mancha(cola, Enum.NormalId.Back, nil, BARRO, 0.45)
	for _, lado in { -1, 1 } do
		local x0, x1 = NUCLEO * lado, ANCHO * lado
		local aletas = {
			caja("Aleta", x0, x1, ARCO, CAPO, del - HUECO, del + HUECO, pintura, nil, true),
			caja("Aleta", x0, x1, ARCO, CAPO, tras - HUECO, tras + HUECO, pintura, nil, true),
		}
		local puerta = caja("Puerta", x0, x1, BAJOS, CAPO, del + HUECO, tras - HUECO, pintura, nil, true)
		caja("Borde", (ANCHO - 0.3) * lado, x1, CAPO, CINTURA, PARABRISAS, finCabina, pintura, nil, true)
		P.mancha(puerta, caraLado(lado), nil, BARRO, 0.55)
		for _, aleta in aletas do
			P.mancha(aleta, caraLado(lado), nil, OXIDO, 0.3) -- óxido encima de las ruedas
		end
		-- Los pasos de rueda: forro negro por dentro y las esquinas de arriba cortadas (que no sean un cuadrado).
		local medio = (NUCLEO + 0.06 + ANCHO) / 2 * lado
		for _, eje in EJES do
			caja("Paso", x0, (NUCLEO + 0.06) * lado, BAJOS, ARCO, eje - HUECO, eje + HUECO, Color3.fromRGB(16, 16, 16))
			for _, sentido in { -1, 1 } do
				cuna("Arco", Vector3.new(medio, ARCO, eje + HUECO * sentido), Vector3.new(0, 0, -0.55 * sentido),
					Vector3.new(0, -0.6, 0), ANCHO - NUCLEO - 0.06, pintura)
			end
		end
	end
	-- El suelo del habitáculo, a la altura de la cintura (por debajo, el cuerpo tapa las piernas de los que van
	-- sentados): oscuro, como la tapicería.
	caja("Piso", -(ANCHO - 0.3), ANCHO - 0.3, CAPO, CINTURA, PARABRISAS, finCabina, oscuro(estilo.tapiceria, 0.55),
		Enum.Material.Fabric, true)
	-- El capó, que baja un poco hacia delante (más alto junto al parabrisas).
	cuna("Capo", Vector3.new(0, CAPO, PARABRISAS), Vector3.new(0, 0, -(LARGO + PARABRISAS)), Vector3.new(0, CINTURA - CAPO, 0),
		ANCHO * 2, estilo.capo or pintura, if estilo.capo then Enum.Material.Plastic else nil, true)
	if estilo.ranchera then
		caja("Porton", -ANCHO, ANCHO, CAPO, CINTURA, finCabina, LARGO, pintura, nil, true)
	else
		caja("Maletero", -ANCHO, ANCHO, CAPO, CAPO + 0.25, finCabina, LARGO, pintura, nil, true)
	end

	------------------------------------------------------------------ lo de arriba: techo, montantes y cristales
	local finTecho = if estilo.ranchera then 6.6 else 3.35
	local techo = caja("Techo", -(CRISTAL - 0.05), CRISTAL - 0.05, TECHO, TECHO + 0.25, -0.95, finTecho, estilo.techo or pintura,
		if estilo.techo then Enum.Material.Leather else nil)
	if not estilo.techo then
		P.mancha(techo, Enum.NormalId.Top, nil, Color3.fromRGB(40, 44, 34), 0.55) -- verdín de estar aparcado al raso
	end
	local alto = TECHO - CINTURA
	-- Parabrisas: de (y = CINTURA, z = PARABRISAS) a (y = TECHO, z = -0,95).
	local inclinacion = math.atan2(-0.95 - PARABRISAS, alto)
	local largoLuna = math.sqrt(alto ^ 2 + (-0.95 - PARABRISAS) ^ 2)
	local marcoLuna = CFrame.new(0, (CINTURA + TECHO) / 2, (PARABRISAS - 0.95) / 2) * CFrame.Angles(inclinacion, 0, 0)
	cristal(girada("Luna", Vector3.new(5.7, largoLuna + 0.04, 0.08), marcoLuna, COLOR.Cristal))
	for _, lado in { -1, 1 } do
		girada("Pilar", Vector3.new(0.22, largoLuna + 0.1, 0.2), CFrame.new(CRISTAL * lado, 0, 0) * marcoLuna, pintura)
		caja("Pilar", (CRISTAL - 0.11) * lado, (CRISTAL + 0.11) * lado, CINTURA, TECHO, 0.96, 1.24, NEGRO)
		-- Ventanilla de delante: el triángulo bajo el montante y el resto.
		cristal(cuna("Cristal", Vector3.new(CRISTAL * lado, CINTURA, -0.95), Vector3.new(0, 0, PARABRISAS + 0.95),
			Vector3.new(0, alto, 0), 0.06, COLOR.Cristal))
		cristal(caja("Cristal", (CRISTAL - 0.03) * lado, (CRISTAL + 0.03) * lado, CINTURA, TECHO, -0.95, 0.96, COLOR.Cristal))
		-- Cromado de la cintura, encima del borde de las puertas.
		caja("Cromo", (ANCHO - 0.1) * lado, (ANCHO + 0.02) * lado, CINTURA, CINTURA + 0.06, PARABRISAS + 0.05, finCabina - 0.05,
			CROMO, Enum.Material.Metal)
		if estilo.ranchera then
			cristal(caja("Cristal", (CRISTAL - 0.03) * lado, (CRISTAL + 0.03) * lado, CINTURA, TECHO, 1.24, 3.55, COLOR.Cristal))
			caja("Pilar", (CRISTAL - 0.11) * lado, (CRISTAL + 0.11) * lado, CINTURA, TECHO, 3.55, 3.85, pintura)
			cristal(caja("Cristal", (CRISTAL - 0.03) * lado, (CRISTAL + 0.03) * lado, CINTURA, TECHO, 3.85, 6.3, COLOR.Cristal))
			caja("Pilar", (CRISTAL - 0.11) * lado, (CRISTAL + 0.11) * lado, CINTURA, TECHO, 6.3, 6.6, pintura)
		else
			cristal(caja("Cristal", (CRISTAL - 0.03) * lado, (CRISTAL + 0.03) * lado, CINTURA, TECHO, 1.24, 3.0, COLOR.Cristal))
			-- El montante de atrás: ancho, con el triángulo bajo la luneta.
			caja("Pilar", (CRISTAL - 0.11) * lado, (CRISTAL + 0.11) * lado, CINTURA, TECHO, 3.0, 3.35, pintura)
			cuna("Pilar", Vector3.new(CRISTAL * lado, CINTURA, 3.35), Vector3.new(0, 0, finCabina - 3.35), Vector3.new(0, alto, 0),
				0.22, pintura)
		end
	end
	if estilo.ranchera then
		-- Casi de pie, en el portón.
		cristal(girada("Luneta", Vector3.new(5.6, alto + 0.02, 0.08), CFrame.new(0, (CINTURA + TECHO) / 2, 6.535)
			* CFrame.Angles(-math.atan2(0.17, alto), 0, 0), COLOR.Cristal))
	else
		local caida = finCabina - 3.35
		cristal(girada("Luneta", Vector3.new(5.6, math.sqrt(alto ^ 2 + caida ^ 2) + 0.04, 0.08),
			CFrame.new(0, (CINTURA + TECHO) / 2, (3.35 + finCabina) / 2) * CFrame.Angles(-math.atan2(caida, alto), 0, 0), COLOR.Cristal))
	end
	if estilo.baca then
		for _, lado in { -1, 1 } do
			caja("Baca", 2.3 * lado, 2.5 * lado, TECHO + 0.25, TECHO + 0.4, 0.2, 6.0, NEGRO, Enum.Material.Metal)
		end
	end
	if estilo.grieta then
		-- Raja en el parabrisas, del lado del acompañante (por fuera del cristal).
		for _, giro in { 0.5, -0.75 } do
			local raja = girada("Raja", Vector3.new(1.3, 0.025, 0.015), marcoLuna * CFrame.new(1.25, 0.25, -0.05)
				* CFrame.Angles(0, 0, giro) * CFrame.new(0.6, 0, 0), Color3.fromRGB(150, 152, 150))
			raja.Transparency = 0.35
		end
	end

	------------------------------------------------------------------ limpiaparabrisas
	-- Tumbados abajo del parabrisas, con el giro a la izquierda y la punta hacia la derecha. El cliente los gira
	-- alrededor de Eje con la Normal (y elige él el sentido para que suban).
	local subir = marcoLuna.UpVector
	local fuera = marcoLuna.LookVector -- hacia fuera del cristal (arriba y adelante)
	local abajo = marcoLuna.Position - subir * (largoLuna / 2)
	for i, x0 in { -2.4, 0 } do
		local eje = Vector3.new(x0, abajo.Y, abajo.Z) + subir * 0.3 + fuera * 0.075
		local cf = CFrame.fromMatrix(eje + Vector3.new(1.15, 0, 0), Vector3.new(1, 0, 0), subir)
		local limpia = girada(`Limpia{i}`, Vector3.new(2.3, 0.07, 0.06), cf, NEGRO, Enum.Material.Rubber)
		limpia:SetAttribute("Eje", base:PointToWorldSpace(eje))
		limpia:SetAttribute("Normal", base:VectorToWorldSpace(fuera))
	end

	------------------------------------------------------------------ detalles de los lados
	for _, lado in { -1, 1 } do
		local x = ANCHO * lado
		local fueraX = (ANCHO + 0.03) * lado
		-- Juntas de las puertas, tiradores y la banda de goma.
		local juntas = if estilo.ranchera then { { PARABRISAS, BAJOS + 0.15 }, { 1.1, BAJOS + 0.15 }, { 3.7, ARCO + 0.05 } }
			else { { PARABRISAS, BAJOS + 0.15 }, { 1.1, BAJOS + 0.15 }, { 3.25, ARCO + 0.05 } }
		for _, j in juntas do
			caja("Junta", x, fueraX, j[2], CINTURA, j[1] - 0.025, j[1] + 0.025, Color3.fromRGB(20, 20, 20))
		end
		local tiradores = if estilo.ranchera then { 0.35, 3.1 } else { 0.35, 2.65 }
		for _, z in tiradores do
			caja("Tirador", x, (ANCHO + 0.07) * lado, 2.62, 2.74, z, z + 0.45, CROMO, Enum.Material.Metal)
		end
		caja("Banda", x, (ANCHO + 0.06) * lado, 1.85, 2.05, del + HUECO + 0.05, tras - HUECO - 0.05, NEGRO, Enum.Material.Rubber)
		-- Retrovisor, en la esquina de la puerta junto al montante.
		caja("Retrovisor", (ANCHO - 0.05) * lado, (ANCHO + 0.38) * lado, CINTURA + 0.03, CINTURA + 0.38, -2.55, -2.3, NEGRO)
	end
	-- Antena en la aleta de delante derecha, un poco echada hacia atrás.
	girada("Antena", Vector3.new(0.05, 2.6, 0.05), CFrame.new(2.85, CAPO, -3.3) * CFrame.Angles(math.rad(10), 0, 0)
		* CFrame.new(0, 1.3, 0), NEGRO, Enum.Material.Metal)
	if estilo.abollado then
		-- La puerta de delante izquierda, hundida (una mancha más oscura y torcida) y rozada.
		girada("Abolladura", Vector3.new(0.04, 0.75, 1.3), CFrame.new(-ANCHO - 0.03, 1.75, -1.3) * CFrame.Angles(math.rad(2), math.rad(2.5), 0),
			oscuro(pintura, 0.72))
		for k, giro in { 0.08, -0.05 } do
			girada("Roce", Vector3.new(0.02, 0.04, 1.6), CFrame.new(-ANCHO - 0.09, 1.6 + k * 0.22, -1.1) * CFrame.Angles(giro, 0, 0),
				Color3.fromRGB(130, 128, 120))
		end
	end

	------------------------------------------------------------------ delante: parachoques, calandra y faros
	for _, s in { -1, 1 } do -- -1 delante, 1 detrás
		local cara = LARGO * s
		local z0, z1 = if s < 0 then -LARGO - 0.3 else LARGO, if s < 0 then -LARGO else LARGO + 0.3
		local barra = caja("Parachoques", -ANCHO - 0.12, ANCHO + 0.12, 1.12, 1.58, z0, z1, CROMO, Enum.Material.Metal)
		P.mancha(barra, if s < 0 then Enum.NormalId.Front else Enum.NormalId.Back, nil, OXIDO, 0.35)
		for _, lado in { -1, 1 } do
			-- La vuelta del parachoques por el lado y su tope de goma.
			local v0, v1 = if s < 0 then -LARGO else LARGO - 0.7, if s < 0 then -LARGO + 0.7 else LARGO
			caja("Parachoques", ANCHO * lado, (ANCHO + 0.12) * lado, 1.12, 1.58, v0, v1, CROMO, Enum.Material.Metal)
			local t0, t1 = if s < 0 then -LARGO - 0.37 else LARGO + 0.2, if s < 0 then -LARGO - 0.2 else LARGO + 0.37
			caja("Tope", 1.35 * lado, 1.75 * lado, 1.05, 1.68, t0, t1, NEGRO, Enum.Material.Rubber)
		end
		-- Matrícula: delante, en el parachoques; detrás, encima.
		local placa = if s < 0 then caja("Matricula", -0.75, 0.75, 1.15, 1.55, -LARGO - 0.34, -LARGO - 0.3, Color3.fromRGB(168, 164, 150))
			else caja("Matricula", -0.75, 0.75, 1.75, 2.15, LARGO, LARGO + 0.04, Color3.fromRGB(168, 164, 150))
		P.letrero(placa, if s < 0 then Enum.NormalId.Front else Enum.NormalId.Back, estilo.matricula, Color3.fromRGB(30, 30, 32))
		if s > 0 then
			-- Pilotos: el rojo (con su luz) y el ámbar del intermitente debajo.
			for _, lado in { -1, 1 } do
				local piloto = caja("Piloto", 1.75 * lado, 2.95 * lado, 2.3, 2.75, cara, cara + 0.08, Color3.fromRGB(104, 22, 20))
				P.luz(piloto, "PointLight", 0.8, 10, LUZ_PILOTO).Enabled = false
				caja("Intermitente", 1.75 * lado, 2.95 * lado, 2.02, 2.28, cara, cara + 0.07, Color3.fromRGB(122, 78, 32))
			end
		end
	end
	caja("Calandra", -1.45, 1.45, 1.75, 2.75, -LARGO - 0.05, -LARGO, Color3.fromRGB(22, 22, 22))
	for _, y in { 2.0, 2.25, 2.5, 2.76 } do
		caja("Rejilla", -1.45, 1.45, y - 0.035, y + 0.035, -LARGO - 0.09, -LARGO - 0.05, CROMO, Enum.Material.Metal)
	end
	P.cilindro(modelo, "Emblema", Vector3.new(0.05, 0.35, 0.35), base * CFrame.new(0, 2.25, -LARGO - 0.115)
		* CFrame.Angles(0, math.pi / 2, 0), CROMO, Enum.Material.Metal)
	for _, lado in { -1, 1 } do
		caja("Bisel", 1.58 * lado, 2.92 * lado, 2.05, 2.79, -LARGO - 0.05, -LARGO, CROMO, Enum.Material.Metal)
		local faro = caja("Faro", 1.65 * lado, 2.85 * lado, 2.12, 2.72, -LARGO - 0.08, -LARGO, Color3.fromRGB(150, 148, 136))
		local haz = P.luz(faro, "SpotLight", 2, 45, LUZ_FARO) :: SpotLight
		haz.Name = "Haz"
		haz.Face = Enum.NormalId.Front
		haz.Angle = 55
		haz.Enabled = false
		local brillo = P.luz(faro, "PointLight", 0.7, 10, LUZ_FARO)
		brillo.Name = "Brillo"
		brillo.Enabled = false
		caja("Intermitente", 2.05 * lado, 2.85 * lado, 1.62, 1.92, -LARGO - 0.05, -LARGO, Color3.fromRGB(128, 84, 34))
	end
	-- Tubo de escape, debajo del parachoques de atrás.
	local tubo = P.cilindro(modelo, "Tubo", Vector3.new(0.7, 0.24, 0.24), base * CFrame.new(1.6, 0.55, LARGO)
		* CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(52, 40, 34), Enum.Material.CorrodedMetal)
	P.punto(tubo, "Escape", base:PointToWorldSpace(Vector3.new(1.6, 0.55, LARGO + 0.37)))

	------------------------------------------------------------------ ruedas
	for i, sitio in { { -1, del }, { 1, del }, { -1, tras }, { 1, tras } } do
		local cf = base * CFrame.new(2.65 * sitio[1], RUEDA, sitio[2])
		local distinta = estilo.rueda == i -- la de repuesto: llanta de chapa negra, sin tapacubos
		P.cilindro(modelo, "Rueda", Vector3.new(0.85, RUEDA * 2, RUEDA * 2), cf, if distinta then Color3.fromRGB(34, 33, 32) else COLOR.Goma,
			Enum.Material.Rubber)
		P.cilindro(modelo, "Llanta", if distinta then Vector3.new(0.92, 1.2, 1.2) else Vector3.new(0.95, 1.35, 1.35), cf,
			if distinta then Color3.fromRGB(38, 38, 40) else CROMO, Enum.Material.Metal)
	end

	------------------------------------------------------------------ dentro
	local tela = estilo.tapiceria
	caja("Salpicadero", -2.75, 2.75, CINTURA, CINTURA + 0.5, -2.3, -1.7, Color3.fromRGB(34, 32, 30))
	caja("Relojes", -2.0, -0.8, CINTURA + 0.5, CINTURA + 0.7, -2.1, -1.8, Color3.fromRGB(24, 24, 24))
	-- Volante delante del conductor, inclinado como la columna (que baja hacia el salpicadero).
	local columna = Vector3.new(0, -0.5, -0.866)
	local centro = Vector3.new(-1.4, 3.95, -1.45)
	P.cilindro(modelo, "Volante", Vector3.new(0.1, 1.2, 1.2), base * CFrame.fromMatrix(centro, columna, Vector3.new(0, 0.866, -0.5)),
		Color3.fromRGB(30, 28, 26))
	girada("Columna", Vector3.new(0.14, 0.14, 0.7), CFrame.lookAt(centro + columna * 0.35, centro + columna), Color3.fromRGB(30, 28, 26))
	for _, lado in { -1, 1 } do
		caja("Respaldo", 0.45 * lado, 2.35 * lado, CINTURA, 4.6, 0.2, 0.6, tela, Enum.Material.Fabric)
		caja("Reposacabezas", 0.95 * lado, 1.85 * lado, 4.68, 5.15, 0.3, 0.58, tela, Enum.Material.Fabric)
	end
	caja("Respaldo", -2.5, 2.5, CINTURA, 4.5, 3.3, 3.7, tela, Enum.Material.Fabric)
	caja("Retrovisor", -0.35, 0.35, TECHO - 0.35, TECHO - 0.15, -0.86, -0.79, NEGRO)
	if estilo.ambientador then
		girada("Ambientador", Vector3.new(0.16, 0.28, 0.02), CFrame.new(0.12, TECHO - 0.6, -0.82) * CFrame.Angles(0, 0.4, 0),
			Color3.fromRGB(40, 60, 40))
	end
	-- Los asientos de verdad (donde se sienta el personaje): invisibles dentro del cuerpo, mirando hacia delante.
	for i = 1, Config.Coches.Plazas do
		local sitio = PLAZAS[(i - 1) % #PLAZAS + 1]
		local asiento = Instance.new("Seat")
		asiento.Name = `Asiento{i}`
		asiento.Anchored = true
		asiento.Size = Vector3.new(1.9, 0.4, 1.9)
		asiento.CFrame = base * CFrame.new(sitio.X, ASIENTO - 0.2, sitio.Y)
		asiento.Transparency = 1
		asiento.CanCollide = false
		asiento.CanQuery = false
		asiento.CanTouch = false -- solo se sube con el prompt de Coches (Seat:Sit), no tocándolo
		asiento.CastShadow = false
		asiento.Parent = modelo
	end

	-- Hecho a mano sin caras en el mismo plano: que Separar no lo toque (con el coche algo girado, lo veía todo pegado
	-- y agrandaba las piezas en cadena).
	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") then
			d:SetAttribute("SinSeparar", true)
		end
	end
	modelo.PrimaryPart = carroceria
	P.etiqueta(modelo, "Coche")
	modelo.Parent = carpeta
end

function GasolineraCoches.construir(carpeta: Folder)
	for i = 1, Config.Coches.Cuantos do
		local z = SITIOS[i] or (SITIOS[#SITIOS] + (i - #SITIOS) * 16) -- si hubiera más, siguen la fila
		local giro = GIROS[(i - 1) % #GIROS + 1]
		coche(i, CFrame.new(14, 0.2, z) * CFrame.Angles(0, math.rad(giro), 0), ESTILOS[(i - 1) % #ESTILOS + 1], carpeta)
	end
end

return GasolineraCoches
