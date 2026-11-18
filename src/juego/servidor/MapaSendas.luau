-- Sendas de tierra pisada de la casa a la granja, al aserradero y a la torre del guardabosques: la meta del día manda
-- allí y, sin ellas, un jugador nuevo iba a ciegas por el bosque (la carretera solo lleva al pueblo). Cada una es una
-- curva suave de tiras de tierra (salen en el mapa del móvil), con un mojón cada ~30 studs (estaca vieja con un trapo
-- rojo desvaído) y, al principio, un poste sin letras con una tabla en flecha y el dibujo de adónde va: la X del
-- granero, un disco de sierra o una torrecita. Nada choca. Números a ojo.
--   MapaSendas.trazados: los puntos { x, z } de cada senda, ya en curva (datos puros: tests/bancos/sendas.luau).
--   MapaSendas.cerca(x, z, margen): si (x, z) está a menos de `margen` del borde de alguna senda (el bosque no pone
--     pinos ni sotobosque encima).
--   MapaSendas.construir(bosque, bloque): las piezas (lo llama Mapa al hacer el bosque, después del suelo).
local MapaSendas = {}

-- Ancho de las tiras (varía despacio a lo largo de la senda) y medio ancho máximo, para `cerca`.
MapaSendas.ANCHO = { 3.5, 5 }
local MEDIO = MapaSendas.ANCHO[2] / 2
local PASO = 7 -- studs entre puntos de la curva (cada tira, poco más)
local SOLAPE = 0.6 -- lo que cada tira se alarga por cada punta, para que no queden huecos en las curvas
local MOJON = 30 -- studs entre mojones

-- Puntos de paso de cada senda (la curva pasa por todos). En lista: el orden fija el azar de las piezas.
--   Granja: del claro de detrás de la casa, al este, a la puerta de la casa de la granja (x 188, z 52).
--   Aserradero: de la carretera (x 0) hacia el oeste a z ≈ -80, hasta el lado este de la nave (x -214).
--   Torre: de detrás de la casa, junto a la caseta del guarda (90, 238) por el este, al pie de la escalera (z 251).
local SENDAS = {
	{
		nombre = "Granja",
		dibujo = "Granero",
		control = { { 46, 56 }, { 62, 60 }, { 82, 63 }, { 106, 58 }, { 132, 51 }, { 158, 48 }, { 176, 51 }, { 185.5, 52 } },
	},
	{
		nombre = "Aserradero",
		dibujo = "Sierra",
		control = {
			{ -3, -80 }, { -22, -77 }, { -48, -82 }, { -80, -90 }, { -112, -91 }, { -142, -84 }, { -170, -80 },
			{ -195, -85 }, { -212.5, -88 },
		},
	},
	{
		nombre = "Torre",
		dibujo = "Torre",
		control = {
			{ 22, 62 }, { 28, 82 }, { 40, 108 }, { 54, 136 }, { 68, 164 }, { 80, 192 }, { 88, 214 }, { 93, 226 },
			{ 100, 232 }, { 101, 240 }, { 98, 246 }, { 91, 249.5 },
		},
	},
}

-- Catmull-Rom por los puntos de paso: un punto cada PASO studs (más o menos), empezando y acabando en los extremos.
local function curva(control: { { number } }): { { number } }
	local puntos = { { control[1][1], control[1][2] } }
	for i = 1, #control - 1 do
		local p0, p1, p2, p3 = control[math.max(i - 1, 1)], control[i], control[i + 1], control[math.min(i + 2, #control)]
		local largo = math.sqrt((p2[1] - p1[1]) ^ 2 + (p2[2] - p1[2]) ^ 2)
		local n = math.max(1, math.ceil(largo / PASO))
		for k = 1, n do
			local t = k / n
			local t2, t3 = t * t, t * t * t
			local punto = {}
			for c = 1, 2 do
				punto[c] = 0.5 * (2 * p1[c] + (-p0[c] + p2[c]) * t + (2 * p0[c] - 5 * p1[c] + 4 * p2[c] - p3[c]) * t2
					+ (-p0[c] + 3 * p1[c] - 3 * p2[c] + p3[c]) * t3)
			end
			table.insert(puntos, punto)
		end
	end
	return puntos
end

MapaSendas.trazados = {} :: { [string]: { { number } } }
-- La caja de cada senda (para que `cerca` descarte rápido): { x1, x2, z1, z2 }.
local cajas = {} :: { [string]: { number } }
for _, senda in SENDAS do
	local puntos = curva(senda.control)
	MapaSendas.trazados[senda.nombre] = puntos
	local caja = { math.huge, -math.huge, math.huge, -math.huge }
	for _, p in puntos do
		caja[1], caja[2] = math.min(caja[1], p[1]), math.max(caja[2], p[1])
		caja[3], caja[4] = math.min(caja[3], p[2]), math.max(caja[4], p[2])
	end
	cajas[senda.nombre] = caja
end

-- Distancia de (x, z) al tramo a-b.
local function aTramo(x: number, z: number, a: { number }, b: { number }): number
	local dx, dz = b[1] - a[1], b[2] - a[2]
	local l2 = dx * dx + dz * dz
	local t = if l2 > 0 then math.clamp(((x - a[1]) * dx + (z - a[2]) * dz) / l2, 0, 1) else 0
	local px, pz = a[1] + dx * t, a[2] + dz * t
	return math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)
end
MapaSendas.aTramo = aTramo

function MapaSendas.cerca(x: number, z: number, margen: number): boolean
	local lejos = MEDIO + margen
	for nombre, puntos in MapaSendas.trazados do
		local caja = cajas[nombre]
		if x < caja[1] - lejos or x > caja[2] + lejos or z < caja[3] - lejos or z > caja[4] + lejos then
			continue
		end
		for i = 1, #puntos - 1 do
			if aTramo(x, z, puntos[i], puntos[i + 1]) < lejos then
				return true
			end
		end
	end
	return false
end

-- ===== Piezas (solo en Roblox) =====

-- El dibujo de la tabla, en piezas planas pintadas sobre la cara `lado` (1 o -1) de la tabla `cf` (su X atraviesa la
-- tabla; z = -largo/2 es la punta de la flecha). `zc`: dónde va el centro del dibujo a lo largo de la tabla.
local function dibujar(dibujo: string, cf: CFrame, grueso: number, lado: number, zc: number, pieza)
	local x = lado * (grueso / 2 + 0.015)
	local base = cf * CFrame.new(x, 0, zc)
	local pintura = Color3.fromRGB(172, 164, 146) -- blanco sucio, desconchado
	local oscuro = Color3.fromRGB(52, 48, 44)
	local function trazo(tam: Vector3, en: CFrame, color: Color3?)
		pieza("Pintura", tam, base * en, color or pintura, Enum.Material.SmoothPlastic)
	end
	if dibujo == "Granero" then
		-- Puerta de granero: el marco cuadrado y la X de tablas.
		for _, m in { { 0, 0.3, 0.62, 0.07 }, { 0, -0.3, 0.62, 0.07 }, { 0.3, 0, 0.07, 0.62 }, { -0.3, 0, 0.07, 0.62 } } do
			trazo(Vector3.new(0.03, m[4], m[3]), CFrame.new(0, m[2], m[1]))
		end
		for _, giro in { 45, -45 } do
			trazo(Vector3.new(0.034, 0.08, 0.82), CFrame.Angles(math.rad(giro), 0, 0))
		end
	elseif dibujo == "Sierra" then
		-- Disco de sierra: el disco (cilindro con el eje atravesando la tabla), ocho dientes y el eje oscuro.
		local p = pieza("Pintura", Vector3.new(0.03, 0.62, 0.62), base, pintura, Enum.Material.SmoothPlastic)
		p.Shape = Enum.PartType.Cylinder
		for i = 0, 7 do
			trazo(Vector3.new(0.026, 0.13, 0.13), CFrame.Angles(i * math.pi / 4, 0, 0) * CFrame.new(0, 0.33, 0)
				* CFrame.Angles(math.rad(45), 0, 0))
		end
		local eje = pieza("Pintura", Vector3.new(0.05, 0.14, 0.14), base, oscuro, Enum.Material.SmoothPlastic)
		eje.Shape = Enum.PartType.Cylinder
	else
		-- Torrecita: dos patas abiertas, un travesaño, la caseta y el tejado.
		for _, l in { -1, 1 } do
			trazo(Vector3.new(0.03, 0.46, 0.06), CFrame.new(0, -0.17, l * 0.13) * CFrame.Angles(math.rad(l * 12), 0, 0))
		end
		trazo(Vector3.new(0.03, 0.05, 0.3), CFrame.new(0, -0.2, 0))
		trazo(Vector3.new(0.03, 0.22, 0.32), CFrame.new(0, 0.15, 0))
		trazo(Vector3.new(0.034, 0.07, 0.46), CFrame.new(0, 0.3, 0))
	end
end

-- Punto y dirección (unitaria, en el plano) a `s` studs del principio de la senda.
local function enLargo(puntos: { { number } }, s: number): (Vector3, Vector3)
	local hecho = 0
	for i = 1, #puntos - 1 do
		local a, b = puntos[i], puntos[i + 1]
		local d = Vector3.new(b[1] - a[1], 0, b[2] - a[2])
		local l = d.Magnitude
		if hecho + l >= s or i == #puntos - 1 then
			local t = math.clamp((s - hecho) / math.max(l, 1e-3), 0, 1)
			return Vector3.new(a[1], 0, a[2]) + d * t, d.Unit
		end
		hecho += l
	end
	return Vector3.new(puntos[1][1], 0, puntos[1][2]), Vector3.new(0, 0, 1)
end

local function largoDe(puntos: { { number } }): number
	local total = 0
	for i = 1, #puntos - 1 do
		total += math.sqrt((puntos[i + 1][1] - puntos[i][1]) ^ 2 + (puntos[i + 1][2] - puntos[i][2]) ^ 2)
	end
	return total
end

-- Ancho de la senda a `s` studs del principio: va y viene despacio entre ANCHO[1] y ANCHO[2].
local function anchoEn(s: number, fase: number): number
	local a, b = MapaSendas.ANCHO[1], MapaSendas.ANCHO[2]
	local onda = (math.sin(s * 0.09 + fase) + math.sin(s * 0.031 + fase * 2.3)) / 4 + 0.5 -- 0..1
	return a + (b - a) * onda
end

function MapaSendas.construir(bosque: Instance, bloque)
	local CollectionService = game:GetService("CollectionService")
	local TIERRA = Color3.fromRGB(86, 76, 58) -- algo más clara y menos verde que el suelo del bosque (70, 64, 44)
	local MADERA = Color3.fromRGB(64, 54, 44)
	local GASTADA = Color3.fromRGB(88, 78, 66) -- madera vieja, lavada por la lluvia
	local TRAPO = Color3.fromRGB(116, 40, 34) -- rojo desvaído, sin brillo
	local azar = Random.new(57)
	local carpeta = Instance.new("Folder")
	carpeta.Name = "Sendas"

	local padre: Instance = carpeta
	-- Una pieza de adorno: no choca, no se le apunta y no hace sombra.
	local function pieza(nombre: string, tam: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
		local p = bloque(nombre, tam, cf, color, material, padre)
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		return p
	end

	for _, senda in SENDAS do
		local puntos = MapaSendas.trazados[senda.nombre]
		local suya = Instance.new("Folder")
		suya.Name = senda.nombre
		suya.Parent = carpeta
		padre = suya
		local fase = azar:NextNumber(0, math.pi * 2)

		-- Las tiras de tierra: una por tramo, alargadas por las puntas para tapar las curvas. Tres alturas que se
		-- turnan (la cara de arriba a 0,05-0,07) para que dos tiras que se solapan no parpadeen.
		local hecho = 0
		for i = 1, #puntos - 1 do
			local a, b = puntos[i], puntos[i + 1]
			local desde, hasta = Vector3.new(a[1], 0, a[2]), Vector3.new(b[1], 0, b[2])
			local largo = (hasta - desde).Magnitude
			local arriba = 0.05 + (i % 3) * 0.01
			local medio = (desde + hasta) / 2 + Vector3.new(0, arriba - 0.04, 0)
			local ancho = anchoEn(hecho + largo / 2, fase) + azar:NextNumber(-0.15, 0.15)
			local tira = pieza("Senda", Vector3.new(ancho, 0.08, largo + SOLAPE * 2), CFrame.lookAt(medio, medio + (hasta - desde)),
				TIERRA, Enum.Material.Ground)
			CollectionService:AddTag(tira, "EnMapa")
			hecho += largo
		end

		-- Mojones: estaca vieja algo torcida, medio clavada, con un trapo rojo atado arriba y una tira que cuelga.
		-- Uno a cada lado, turnándose, un poco fuera del borde.
		local total = largoDe(puntos)
		local lado = 1
		local s = MOJON / 2
		while s < total - 10 do
			local en, dir = enLargo(puntos, s)
			local fuera = Vector3.new(-dir.Z, 0, dir.X) * lado
			local pie = en + fuera * (anchoEn(s, fase) / 2 + 0.9)
			local alto = azar:NextNumber(2.4, 3)
			local estaca = CFrame.new(pie) * CFrame.Angles(0, azar:NextNumber(0, math.pi * 2), 0)
				* CFrame.Angles(azar:NextNumber(-0.14, 0.14), 0, azar:NextNumber(-0.14, 0.14))
			pieza("Estaca", Vector3.new(0.32, alto, 0.32), estaca * CFrame.new(0, alto / 2 - 0.3, 0), GASTADA, Enum.Material.Wood)
			local nudo = estaca * CFrame.new(0, alto - 0.75, 0)
			pieza("Trapo", Vector3.new(0.42, 0.26, 0.42), nudo, TRAPO, Enum.Material.Fabric)
			pieza("Trapo", Vector3.new(0.04, 0.85, 0.28), nudo * CFrame.new(0.23, -0.4, 0.04) * CFrame.Angles(0, 0, math.rad(8)),
				TRAPO, Enum.Material.Fabric)
			lado = -lado
			s += MOJON + azar:NextNumber(-3, 3)
		end

		-- El poste del principio: a la izquierda de la senda, con la tabla en flecha hacia donde va y su dibujo
		-- pintado por las dos caras.
		local en, dir = enLargo(puntos, if senda.nombre == "Aserradero" then 8 else 4)
		local izquierda = Vector3.new(dir.Z, 0, -dir.X)
		local pie = en + izquierda * (anchoEn(0, fase) / 2 + 1.2)
		local poste = CFrame.lookAt(pie, pie + dir) * CFrame.Angles(0, 0, math.rad(3))
		pieza("Poste", Vector3.new(0.45, 5, 0.45), poste * CFrame.new(0, 2.3, 0), MADERA, Enum.Material.Wood)
		local grueso, largo = 0.16, 3.2
		-- La tabla, pegada a un lado del poste y un poco caída hacia la punta.
		local tabla = poste * CFrame.new(-(0.45 / 2 + grueso / 2), 4, -(largo / 2 - 0.35)) * CFrame.Angles(math.rad(-4), 0, 0)
		pieza("Tabla", Vector3.new(grueso, 0.9, largo), tabla, GASTADA, Enum.Material.WoodPlanks)
		-- La punta: un cuadrado girado 45 grados, medio metido en la tabla (algo más fino para que no parpadee).
		pieza("Tabla", Vector3.new(grueso * 0.8, 0.95, 0.95), tabla * CFrame.new(0, 0, -largo / 2) * CFrame.Angles(math.rad(45), 0, 0),
			GASTADA, Enum.Material.WoodPlanks)
		for _, cara in { 1, -1 } do
			dibujar(senda.dibujo, tabla, grueso, cara, 0.15, pieza)
		end
		-- Un trapo rojo atado al poste, como los de los mojones: la misma señal.
		pieza("Trapo", Vector3.new(0.58, 0.3, 0.58), poste * CFrame.new(0, 3.1, 0), TRAPO, Enum.Material.Fabric)
		pieza("Trapo", Vector3.new(0.04, 1, 0.3), poste * CFrame.new(0.3, 2.6, 0.05) * CFrame.Angles(0, 0, math.rad(6)), TRAPO,
			Enum.Material.Fabric)
	end
	carpeta.Parent = bosque
end

return MapaSendas
