-- La cabaña del cazador en el bosque espeso (docs/diseño.md: "cabaña del cazador en el bosque espeso"), al noroeste de
-- la casa y lo más lejos del bosque: el sitio que premia explorar (diseño: "cuanto más lejos, mejores recursos": una
-- trampa ya hecha, chatarra, una lata y una botella). Se llega siguiendo cortes de hacha en los pinos desde la senda del
-- aserradero. Cabaña de troncos sobre un zócalo de piedra (el cascarón y la fachada, de PuebloFachadas.uno; los troncos
-- cruzados en las esquinas, aquí), la puerta colgando de una bisagra y la ventana rota.
-- Lo que pasó, sin una palabra: algo entró por la ventana y arañó el suelo hasta el catre; el cazador descolgó el rifle
-- (en el armero queda su hueco), salió corriendo, pisó su propio cepo (sigue cerrado sobre una bota rota) y algo lo
-- arrastró al bosque hasta un agujero (pista 6: "hay túneles bajo todo el bosque"), donde quedó el rifle partido.
-- Dentro: catre con pieles, estufa de hierro, armero, cajas de cartuchos vacías, las rayas de los días en la pared y el
-- armario de los escondites. Fuera: tendedero de pieles, un ciervo colgado del trípode (abierto y seco, sin vísceras:
-- Moderate), la leñera y el tajo. Alrededor, pinos espesos (en el Bosque del mapa: el Acechador se asoma tras ellos).
-- Nada brilla ni da luz; lo que solo se ve no choca. Medidas a ojo (docs/sistemas/llaves.md). Lo llama
-- Lugares.construir después de la torre, con su ctx y sus ayudas.
local CollectionService = game:GetService("CollectionService")

local PuebloPlano = require(script.Parent.PuebloPlano)
local PuebloFachadas = require(script.Parent.PuebloFachadas)
local PuebloInteriores = require(script.Parent.PuebloInteriores)

local LugarCazador = {}

local ctx -- el de Lugares: bloque, Mapa, Plano y carpeta
local A -- las ayudas de Lugares: adorno, choque, monton, liston, enCara, zarpazo, agujero, objeto…
local Mapa

local F = 1.06 -- cara de arriba del suelo forrado (PuebloInteriores.forrar)
local SEMILLA = 3105

local COLOR = {
	Tronco = Color3.fromRGB(58, 45, 35), -- los troncos de las paredes, casi negros de viejos
	TroncoOscuro = Color3.fromRGB(40, 31, 25),
	Testa = Color3.fromRGB(104, 84, 62), -- la cara cortada de un tronco
	Madera = Color3.fromRGB(72, 58, 45),
	MaderaOscura = Color3.fromRGB(44, 34, 27),
	Corte = Color3.fromRGB(164, 136, 100), -- madera recién cortada: los cortes de hacha
	Astilla = Color3.fromRGB(150, 122, 92),
	Hierro = Color3.fromRGB(34, 32, 31),
	Oxido = Color3.fromRGB(70, 48, 36),
	Laton = Color3.fromRGB(104, 86, 50), -- las vainas de los cartuchos, apagadas
	Carton = Color3.fromRGB(112, 52, 40), -- las cajas de cartuchos, de un rojo desvaído
	Piel = { Color3.fromRGB(86, 64, 46), Color3.fromRGB(72, 60, 50), Color3.fromRGB(98, 80, 60), Color3.fromRGB(62, 52, 45) },
	Curtido = Color3.fromRGB(138, 116, 90), -- el lado de dentro de una piel estirada
	Cuero = Color3.fromRGB(58, 40, 29),
	Cuerda = Color3.fromRGB(104, 88, 62),
	Lona = Color3.fromRGB(74, 76, 54),
	Ciervo = Color3.fromRGB(92, 70, 50),
	CiervoClaro = Color3.fromRGB(126, 104, 82),
	Pezuna = Color3.fromRGB(28, 24, 22),
	Hueco = Color3.fromRGB(34, 13, 11), -- el ciervo abierto y la sangre de hace días: casi negro
	Borde = Color3.fromRGB(78, 33, 28),
	Carbon = Color3.fromRGB(26, 22, 19), -- las rayas de los días
	Ceniza = Color3.fromRGB(82, 80, 76),
	Negro = Color3.fromRGB(12, 11, 10),
	Tierra = Color3.fromRGB(58, 48, 38), -- el patio pisado
	Senda = Color3.fromRGB(86, 76, 58), -- como las tiras de MapaSendas
	Surco = Color3.fromRGB(36, 29, 23),
	Franela = Color3.fromRGB(88, 30, 26),
	Cristal = Color3.fromRGB(24, 28, 30),
	Raiz = Color3.fromRGB(66, 50, 36),
}

local function v(lado: string, desde: number): PuebloPlano.Ventana
	return { lado = lado, desde = desde, planta = 1 }
end

-- La cabaña, con la forma de PuebloPlano.Edificio: 11 × 10 por fuera (dentro, x -220..-210 y z 235,5..244,5), una
-- planta de 9 (el armario de lamas mide 8), la puerta hacia la senda (-z) y una ventana en el lado de la leñera (+x).
LugarCazador.EDIFICIO = {
	nombre = "CabanaCazador",
	x = -215,
	z = 240,
	ancho = 11,
	largo = 10,
	alto = 9,
	plantas = 1,
	puerta = "N",
	entra = true,
	material = "madera",
	ventanas = { v("E", -0.3) },
} :: PuebloPlano.Edificio
local CABANA = LugarCazador.EDIFICIO
-- Tablas casi negras, tejado a dos aguas con el hastial sobre la puerta y sin canalones; la puerta, colgando de la
-- bisagra de abajo (la de arriba, arrancada).
local ESTILO = { color = Color3.fromRGB(46, 36, 29), tejado = "dos", eje = "z", pendiente = 0.85, alero = 0.9, vuelo = 0.7, sinCanalon = true }
local PUERTA = { puerta = "abierta", bisagra = -1, angulo = 58, caida = 0.2 }

LugarCazador.ZONA = Vector3.new(-215, 0, 235) -- el centro de su zona sin bosque (Lugares, ZONAS.Cazador: radio 34)
-- Lo de fuera: el trípode del ciervo, los dos postes del tendedero, el cepo y el tajo.
local TRIPODE = Vector3.new(-224.5, 0, 226.5)
local TENDEDERO = { Vector3.new(-209.8, 0, 225.8), Vector3.new(-203.0, 0, 228.3) }
local CEPO = Vector3.new(-230.5, 0, 229.5)
local TAJO = Vector3.new(-205.3, 0, 236.6)
-- El claro: ningún pino a menos de CLARO de la cabaña (sus copas pasarían por el tejado) ni dentro del patio.
LugarCazador.CAJA = { x1 = -222, x2 = -208, z1 = 233.5, z2 = 246.5 } -- la cabaña con sus troncos y aleros, en planta
LugarCazador.CLARO = 12
LugarCazador.PATIO = { x = -216, z = 225, radio = 15.5 }
-- El rastro del arrastre: del cepo al agujero (el último punto, a la orilla del agujero que salga).
local RASTRO = { CEPO, Vector3.new(-235.5, 0, 232.6), Vector3.new(-240.3, 0, 236.9) }
-- Sitios para el agujero (centro, en planta; 2,6 × 2,2): el primero sin un pino ni una roca cerca. Todos con x < -244,
-- en un solo trozo del suelo del bosque (el hoyo del aserradero lo parte en x -243,5).
local HOYOS = { Vector3.new(-246.7, 0, 243.3), Vector3.new(-246.2, 0, 247.2), Vector3.new(-248.6, 0, 239.8), Vector3.new(-249.6, 0, 244.6) }
-- Los cortes de hacha: de junto a la senda del aserradero (a unos 10 de ella) al borde del claro, `n` pinos con su
-- corte mirando al anterior; `lado`: lo que se aparta cada uno de la recta, para que no parezca una fila.
LugarCazador.CORTES = { desde = Vector3.new(-180, 0, -72), hasta = Vector3.new(-211.5, 0, 206), n = 8, lado = { 0, -3, 2.5, -2, 3, -2.5, 2, 0 } }

---------------------------------------------------------------------------------------------------------------------
-- Ayudas.

-- CFrame con el eje X de `a` a `b` (sirve también en vertical, donde CFrame.lookAt no sabe girar).
local function eje(a: Vector3, b: Vector3): CFrame
	local x = (b - a).Unit
	local ref = if math.abs(x.Y) < 0.9 then Vector3.yAxis else Vector3.zAxis
	local z = x:Cross(ref).Unit
	return CFrame.fromMatrix((a + b) / 2, x, z:Cross(x), z)
end

-- Cilindro de `a` a `b` de `d` de grueso; `choca`: que no se atraviese.
local function cilindro(nombre: string, a: Vector3, b: Vector3, d: number, color: Color3, material: Enum.Material, padre: Instance,
	choca: boolean?): Part
	local tam = Vector3.new((b - a).Magnitude, d, d)
	local p = if choca then ctx.bloque(nombre, tam, eje(a, b), color, material, padre) else A.adorno(nombre, tam, eje(a, b), color, material, padre)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Listón de sección `ancho` × `fondo` de `a` a `b` (en cualquier dirección). No choca.
local function barra(nombre: string, a: Vector3, b: Vector3, ancho: number, fondo: number, color: Color3, material: Enum.Material,
	padre: Instance): Part
	return A.adorno(nombre, Vector3.new((b - a).Magnitude, ancho, fondo), eje(a, b), color, material, padre)
end

-- Calcomanía de `ancho` × `largo` en una cara (`normal` hacia fuera), con lo largo hacia `arriba` y de color `color`.
local function marca(pos: Vector3, normal: Vector3, arriba: Vector3, ancho: number, largo: number, imagen: string, color: Color3, padre: Instance)
	local p = A.adorno("Mancha", Vector3.new(ancho, largo, 0.04), A.enCara(pos, normal, arriba), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic,
		padre)
	p.Transparency = 1
	p.CastShadow = false
	p:SetAttribute("SinSeparar", true)
	local d = Instance.new("Decal")
	d.Texture = imagen
	d.Color3 = color
	d.Face = Enum.NormalId.Front
	d.Parent = p
end

-- Una piel plana en el plano XY de `cf` (la cabeza hacia +Y, la cara de delante hacia -Z): el cuerpo, las patas
-- abiertas, el cuello y el rabo. `colgada`: solo el cuerpo y las patas de abajo (media piel que cuelga de una cuerda).
-- Lo que sale del cuerpo es más fino que él: sin caras en el mismo plano que parpadeen.
local function piel(cf: CFrame, ancho: number, alto: number, color: Color3, padre: Instance, colgada: boolean?)
	local function trozo(tam: Vector3, en: CFrame)
		A.adorno("Piel", tam, cf * en, color, Enum.Material.Fabric, padre)
	end
	trozo(Vector3.new(ancho * 0.72, alto * 0.8, 0.06), CFrame.new())
	for _, sx in { -1, 1 } do
		for _, sy in (if colgada then { -1 } else { -1, 1 }) do
			trozo(Vector3.new(ancho * 0.2, alto * 0.34, 0.04), CFrame.new(sx * ancho * 0.37, sy * alto * 0.37, 0) * CFrame.Angles(0, 0, -sx * sy * 0.55))
		end
	end
	if not colgada then
		trozo(Vector3.new(ancho * 0.26, alto * 0.22, 0.04), CFrame.new(0, alto * 0.47, 0))
		trozo(Vector3.new(ancho * 0.1, alto * 0.14, 0.04), CFrame.new(0, -alto * 0.46, 0))
	end
end

-- Caja de cartuchos de cartón, abierta y vacía, apoyada en `cf` (su base). No choca.
local function cajaCartuchos(cf: CFrame, padre: Instance)
	A.adorno("CajaCartuchos", Vector3.new(0.72, 0.32, 0.46), cf * CFrame.new(0, 0.16, 0), COLOR.Carton, Enum.Material.Fabric, padre)
	A.adorno("Vacia", Vector3.new(0.62, 0.02, 0.36), cf * CFrame.new(0, 0.325, 0), COLOR.Negro, Enum.Material.SmoothPlastic, padre)
	A.adorno("Solapa", Vector3.new(0.72, 0.03, 0.42), cf * CFrame.new(0, 0.42, 0.3) * CFrame.Angles(math.rad(-68), 0, 0), COLOR.Carton,
		Enum.Material.Fabric, padre)
end

-- Vainas de cartucho tiradas alrededor de `pie` (en el suelo, a la altura de `pie`).
local function vainas(pie: Vector3, n: number, radio: number, azar: Random, padre: Instance)
	for _ = 1, n do
		local a, r = azar:NextNumber(0, math.pi * 2), azar:NextNumber(0.2, radio)
		local p = pie + Vector3.new(math.cos(a) * r, 0.045, math.sin(a) * r)
		local vaina = A.adorno("Vaina", Vector3.new(0.26, 0.09, 0.09), CFrame.new(p) * CFrame.Angles(0, azar:NextNumber(0, math.pi), 0), COLOR.Laton,
			Enum.Material.Metal, padre)
		vaina.Shape = Enum.PartType.Cylinder
	end
end

-- Caja (mín, máx) alineada con los ejes de una pieza, girada o no.
local function cajaDe(p: BasePart): (Vector3, Vector3)
	local cf, h = p.CFrame, p.Size / 2
	local x, y, z = cf.RightVector, cf.UpVector, cf.LookVector
	local e = Vector3.new(math.abs(x.X) * h.X + math.abs(y.X) * h.Y + math.abs(z.X) * h.Z,
		math.abs(x.Y) * h.X + math.abs(y.Y) * h.Y + math.abs(z.Y) * h.Z, math.abs(x.Z) * h.X + math.abs(y.Z) * h.Y + math.abs(z.Z) * h.Z)
	return cf.Position - e, cf.Position + e
end

-- Distancia en planta de (x, z) al tramo de `a` a `b`.
local function aTramo(x: number, z: number, a: Vector3, b: Vector3): number
	local dx, dz = b.X - a.X, b.Z - a.Z
	local l2 = dx * dx + dz * dz
	local t = if l2 > 0 then math.clamp(((x - a.X) * dx + (z - a.Z) * dz) / l2, 0, 1) else 0
	return math.sqrt((x - a.X - dx * t) ^ 2 + (z - a.Z - dz * t) ^ 2)
end

-- Lo que ya hay en el bosque por aquí (pinos, árboles que se talan y las rocas y troncos caídos del sotobosque):
-- { x, z, radio } en planta, para no poner un pino encima.
local function ocupado(bosque: Instance?): { { number } }
	local lista = {}
	for _, d in (if bosque then bosque:GetDescendants() else {}) do
		if d:IsA("BasePart") and (d.Name == "Tronco" or d.Name == "Choque") then
			local p = d.Position
			if p.X < -150 and p.X > -290 and p.Z > -110 and p.Z < 310 then
				local s = d.Size
				local r = if d.Name == "Tronco" then math.min(s.X, s.Y, s.Z) / 2 else math.max(s.X, s.Z) / 2
				table.insert(lista, { p.X, p.Z, r })
			end
		end
	end
	return lista
end

local function libre(lista: { { number } }, x: number, z: number, r: number): boolean
	for _, o in lista do
		if (x - o[1]) ^ 2 + (z - o[2]) ^ 2 < (r + o[3]) ^ 2 then
			return false
		end
	end
	return true
end

-- Altura del tejado (a dos aguas, la cumbrera a lo largo de z) en la x `x`: como dosAguas de PuebloFachadas.
local function alturaTejado(x: number): number
	local ha = CABANA.ancho / 2 + 0.5
	return 2 + CABANA.alto + ESTILO.pendiente * (ha - math.abs(x - CABANA.x))
end

---------------------------------------------------------------------------------------------------------------------
-- La cabaña por fuera: troncos, puerta y ventana.

-- Lo pegado a las paredes por fuera (marcos, molduras, contraventanas, la puerta): los troncos se cortan a su alrededor.
local PEGADO = { Marco = true, Moldura = true, Dintel = true, Cornisa = true, Alfeizar = true, Contraventana = true, Travesano = true,
	Puerta = true, Cuarteron = true, Pomo = true, Bisagra = true, Parteluz = true, Esquirla = true }
local RADIO_TRONCO, PASO_TRONCO, SALE_TRONCO = 0.48, 0.9, 0.33

-- Troncos tumbados por fuera de las cuatro paredes, encima del zócalo de piedra: los de las paredes de delante y de
-- detrás medio tronco más abajo que los de los lados, y todos salen 0,6 de las esquinas, así se cruzan como en una
-- cabaña de verdad. Cada punta, con su testa clara. Quita las esquineras de tablas y las tablas rotas de PuebloFachadas
-- (quedarían enterradas en los troncos).
local function troncos(m: Model)
	local e = CABANA
	local hx, hz = e.ancho / 2 + 0.5, e.largo / 2 + 0.5 -- las caras de fuera de las paredes
	for _, p in m:GetChildren() do
		if p.Name == "Esquinera" or p.Name == "Agujero" or p.Name == "TablaSuelta" then
			p:Destroy()
		end
	end
	local pegado = {}
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") and PEGADO[p.Name] then
			local mn, mx = cajaDe(p)
			table.insert(pegado, { mn, mx })
		end
	end
	local azar = Random.new(SEMILLA + 1)
	for _, lado in { "N", "S", "E", "O" } do
		local f = PuebloPlano.LADOS[lado]
		local enX = lado == "N" or lado == "S"
		local medio = (if enX then hx else hz) + 0.6
		local centro = if enX then e.x else e.z
		local signo = if enX then f.Z else f.X
		local cara = (if enX then e.z else e.x) + signo * (if enX then hz else hx)
		-- Lo que no se tapa en esta pared, en { u0, u1, y0, y1 } (u: a lo largo, desde el centro): la puerta, las
		-- ventanas y lo pegado por fuera (de la cara a 1,6 hacia fuera).
		local tapar = {}
		if lado == e.puerta then
			table.insert(tapar, { -2.1, 2.1, 0, 9.1 })
		end
		for _, w in e.ventanas do
			if w.lado == lado then
				table.insert(tapar, { w.desde - 1.6, w.desde + 1.6, 3.9, 8.1 })
			end
		end
		for _, c in pegado do
			local mn, mx = c[1], c[2]
			local a = ((if enX then mn.Z else mn.X) - cara) * signo
			local b = ((if enX then mx.Z else mx.X) - cara) * signo
			if math.max(a, b) > -0.6 and math.min(a, b) < 1.6 then
				local u0, u1 = (if enX then mn.X else mn.Z) - centro, (if enX then mx.X else mx.Z) - centro
				table.insert(tapar, { u0 - 0.12, u1 + 0.12, mn.Y - 0.12, mx.Y + 0.12 })
			end
		end
		local y0 = 1.95 + (if enX then 0 else PASO_TRONCO / 2)
		local alero = 2 + e.alto - ESTILO.pendiente * ESTILO.alero - 0.25 -- bajo el alero (los lados, con la cumbrera a lo largo de z)
		for k = 0, 8 do
			local y = y0 + k * PASO_TRONCO
			if not enX and y + RADIO_TRONCO > alero then
				break
			end
			local tramos = { { -medio, medio } }
			for _, t in tapar do
				if t[3] < y + RADIO_TRONCO and t[4] > y - RADIO_TRONCO then
					local quedan = {}
					for _, s in tramos do
						if t[2] <= s[1] or t[1] >= s[2] then
							table.insert(quedan, s)
						else
							if t[1] > s[1] then
								table.insert(quedan, { s[1], t[1] })
							end
							if t[2] < s[2] then
								table.insert(quedan, { t[2], s[2] })
							end
						end
					end
					tramos = quedan
				end
			end
			local color = COLOR.Tronco:Lerp(COLOR.TroncoOscuro, azar:NextNumber())
			for _, s in tramos do
				local largo = s[2] - s[1]
				if largo >= 0.5 then
					local u = (s[1] + s[2]) / 2
					local pos = if enX then Vector3.new(centro + u, y, cara + signo * SALE_TRONCO) else Vector3.new(cara + signo * SALE_TRONCO, y, centro + u)
					local cf = if enX then CFrame.new(pos) else CFrame.new(pos) * CFrame.Angles(0, math.pi / 2, 0)
					A.adorno("TroncoPared", Vector3.new(largo, RADIO_TRONCO * 2, RADIO_TRONCO * 2), cf, color, Enum.Material.Wood, m).Shape = Enum.PartType.Cylinder
					for _, punta in { -1, 1 } do
						local testa = A.adorno("Testa", Vector3.new(0.04, RADIO_TRONCO * 2 - 0.1, RADIO_TRONCO * 2 - 0.1), cf * CFrame.new(punta * (largo / 2 + 0.01), 0, 0),
							COLOR.Testa, Enum.Material.Wood, m)
						testa.Shape = Enum.PartType.Cylinder
					end
				end
			end
		end
	end
end

-- La puerta: la bisagra de arriba arrancada (el hierro doblado y astillas del marco) y arañazos hondos en la hoja por
-- las dos caras.
local function puertaRota(m: Model)
	local cf = PuebloPlano.puertaCF(CABANA)
	A.adorno("Bisagra", Vector3.new(0.28, 0.7, 0.06), cf * CFrame.new(-2.05, 6.7, -0.72) * CFrame.Angles(0, 0.6, 0.35), COLOR.Oxido,
		Enum.Material.CorrodedMetal, m)
	for i = 1, 3 do
		A.adorno("Astilla", Vector3.new(0.08, 0.45 + i * 0.12, 0.06), cf * CFrame.new(-2.25 + i * 0.05, 6.3 + i * 0.28, -0.72)
			* CFrame.Angles(0.2 * i, 0, -0.3 + i * 0.25), COLOR.Astilla, Enum.Material.Wood, m)
	end
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") and p.Name == "Puerta" then
			A.zarpazo(p.CFrame * CFrame.new(0.4, 0.9, -0.2), 4, 2.2, math.pi / 2 + 0.12, COLOR.Astilla, m)
			A.zarpazo(p.CFrame * CFrame.new(-0.6, -1.5, -0.2), 3, 1.4, math.pi / 2 - 0.2, COLOR.Astilla, m)
			A.zarpazo(p.CFrame * CFrame.new(0.2, 0.3, 0.125) * CFrame.Angles(0, math.pi, 0), 4, 1.9, math.pi / 2 + 0.05, COLOR.Astilla, m)
		end
	end
end

-- La ventana, rota (si PuebloFachadas la dejó entera, aquí se rompe: la lámina sigue chocando, invisible, como en las
-- rotas de allí): esquirlas en las esquinas del marco y los cristales por el suelo de dentro.
local function ventanaRota(m: Model, azar: Random)
	local w = CABANA.ventanas[1]
	local cf = PuebloPlano.ventanaCF(CABANA, w)
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") and p.Name == "Cristal" and (p.Position - cf.Position).Magnitude < 0.5 and p.Transparency < 1 then
			p.Transparency = 1
			for _, c in { { -1, -1 }, { 1, -1 }, { 1, 1 } } do
				local tam = Vector3.new(azar:NextNumber(0.4, 0.8), azar:NextNumber(0.6, 1.2), 0.05)
				local esquirla = A.adorno("Esquirla", tam, cf * CFrame.new(c[1] * (1.5 - tam.X / 2), c[2] * (2 - tam.Y / 2), 0)
					* CFrame.Angles(0, 0, c[1] * c[2] * 0.5), COLOR.Cristal, Enum.Material.SmoothPlastic, m)
				esquirla.Transparency = 0.4
				esquirla.Reflectance = 0.08
			end
		end
	end
	local _, x2, _, _ = PuebloPlano.dentro(CABANA)
	for _ = 1, 7 do
		local trozo = A.adorno("Cristales", Vector3.new(azar:NextNumber(0.15, 0.45), 0.03, azar:NextNumber(0.12, 0.35)),
			CFrame.new(x2 - azar:NextNumber(0.3, 1.6), F + 0.016, cf.Position.Z + azar:NextNumber(-1.2, 1.2)) * CFrame.Angles(0, azar:NextNumber(0, math.pi), 0),
			COLOR.Cristal, Enum.Material.SmoothPlastic, m)
		trozo.Transparency = 0.35
		trozo.Reflectance = 0.08
	end
end

---------------------------------------------------------------------------------------------------------------------
-- La cabaña por dentro.

local function dentro(m: Model)
	local e = CABANA
	local x1, x2, z1, z2 = PuebloPlano.dentro(e) -- -220, -210, 235.5, 244.5
	local techo = 1 + e.alto
	local pared = 0.11 -- de la cara de dentro de la pared a la del forro
	PuebloInteriores.forrar(ctx, e, m, {
		{ y1 = 1, y2 = 1.45, color = COLOR.MaderaOscura, material = Enum.Material.Wood, grueso = 0.2 }, -- rodapié
		{ y1 = 1.45, y2 = techo - 0.02, variante = "ParedCobertizo" },
	}, "SueloCobertizo", "TablasDesvan")
	local azar = Random.new(SEMILLA + 2)

	-- Dos vigas de lado a lado.
	for _, z in { 238.0, 240.4 } do
		A.adorno("Viga", Vector3.new(x2 - x1, 0.6, 0.5), CFrame.new((x1 + x2) / 2, techo - 0.4, z), COLOR.MaderaOscura, Enum.Material.Wood, m)
	end

	-- El catre de lona contra la pared del oeste, al fondo (choca una caja). La piel que hacía de manta, medio caída
	-- hacia la sala: se levantó (o lo levantaron) de golpe.
	local cx, cz = x1 + 1.25, z2 - 2.45 -- -218.75, 242.05
	A.choque(Vector3.new(2.4, 1.3, 4.7), CFrame.new(cx, 1.65, cz), m)
	for _, s in { -1, 1 } do
		A.adorno("Larguero", Vector3.new(0.14, 0.14, 4.7), CFrame.new(cx + s * 1.1, 2.15, cz), COLOR.MaderaOscura, Enum.Material.Wood, m)
		for _, dz in { -2.1, 2.1 } do
			A.adorno("Tijera", Vector3.new(0.1, 1.5, 0.1), CFrame.new(cx + s * 0.55, 1.55, cz + dz) * CFrame.Angles(0, 0, s * 0.85), COLOR.MaderaOscura,
				Enum.Material.Wood, m)
		end
	end
	A.adorno("Lona", Vector3.new(2.1, 0.06, 4.6), CFrame.new(cx, 2.2, cz), COLOR.Lona, Enum.Material.Fabric, m)
	A.adorno("Almohada", Vector3.new(1.2, 0.3, 0.8), CFrame.new(cx - 0.05, 2.38, cz + 1.8) * CFrame.Angles(0, 0.12, math.rad(-5)), Color3.fromRGB(104, 96, 82),
		Enum.Material.Fabric, m)
	A.adorno("Manta", Vector3.new(1.8, 0.08, 1.7), CFrame.new(cx + 0.15, 2.27, cz - 1.0) * CFrame.Angles(0, 0.14, math.rad(3)), COLOR.Piel[1],
		Enum.Material.Fabric, m)
	A.adorno("Manta", Vector3.new(0.08, 0.95, 1.6), CFrame.new(cx + 1.24, 1.78, cz - 1.05) * CFrame.Angles(0, 0.1, math.rad(-14)), COLOR.Piel[1],
		Enum.Material.Fabric, m)
	piel(A.enCara(Vector3.new(cx + 2.15, F + 0.03, cz - 0.85), Vector3.yAxis, Vector3.new(0.5, 0, -1).Unit), 1.5, 1.9, COLOR.Piel[1], m)

	-- Las rayas de los días, a carbón en la pared de encima del catre: grupos de cinco, cada vez más torcidas, y la
	-- última baja de golpe, como si se le hubiera ido la mano.
	local xr = x1 + pared + 0.015
	for fila, y in { 6.7, 5.85 } do
		for g = 0, (if fila == 1 then 5 else 1) do
			local z0 = 240.0 + g * 0.72
			for k = 0, 3 do
				A.adorno("Raya", Vector3.new(0.02, 0.55, 0.05), CFrame.new(xr, y + azar:NextNumber(-0.04, 0.04), z0 + k * 0.13)
					* CFrame.Angles(azar:NextNumber(-0.09, 0.09), 0, 0), COLOR.Carbon, Enum.Material.SmoothPlastic, m)
			end
			A.adorno("Raya", Vector3.new(0.02, 0.7, 0.05), CFrame.new(xr - 0.005, y, z0 + 0.2) * CFrame.Angles(0.8 + azar:NextNumber(-0.1, 0.1), 0, 0),
				COLOR.Carbon, Enum.Material.SmoothPlastic, m)
		end
	end
	for k = 0, 2 do
		A.adorno("Raya", Vector3.new(0.02, 0.55 + k * 0.06, 0.05), CFrame.new(xr, 5.85 - k * 0.05, 241.6 + k * 0.17) * CFrame.Angles(0.12 + k * 0.14, 0, 0),
			COLOR.Carbon, Enum.Material.SmoothPlastic, m)
	end
	A.adorno("Raya", Vector3.new(0.02, 1.7, 0.06), CFrame.new(xr, 5.2, 242.35) * CFrame.Angles(-0.45, 0, 0), COLOR.Carbon, Enum.Material.SmoothPlastic, m)

	-- La estufa de hierro en el rincón de delante: patas, cuerpo con aros, la portezuela abierta hacia la sala, la
	-- ceniza por el suelo, unos leños y el tubo que sale por el tejado con su sombrerete. Fría: sin luz.
	local sx, sz = x1 + 1.45, z1 + 1.5 -- -218.55, 237
	for _, d in { { -0.48, -0.48 }, { 0.48, -0.48 }, { -0.48, 0.48 }, { 0.48, 0.48 } } do
		A.adorno("Pata", Vector3.new(0.16, 0.5, 0.16), CFrame.new(sx + d[1], F + 0.25, sz + d[2]) * CFrame.Angles(0, 0.785, 0), COLOR.Hierro,
			Enum.Material.Metal, m)
	end
	cilindro("Estufa", Vector3.new(sx, F + 0.45, sz), Vector3.new(sx, F + 2.5, sz), 1.5, COLOR.Hierro, Enum.Material.CorrodedMetal, m)
	for _, y in { F + 0.55, F + 2.4 } do
		cilindro("Aro", Vector3.new(sx, y - 0.07, sz), Vector3.new(sx, y + 0.07, sz), 1.62, COLOR.Oxido, Enum.Material.CorrodedMetal, m)
	end
	cilindro("Tapa", Vector3.new(sx, F + 2.5, sz), Vector3.new(sx, F + 2.66, sz), 1.72, COLOR.Hierro, Enum.Material.Metal, m)
	A.adorno("Boca", Vector3.new(0.06, 0.55, 0.62), CFrame.new(sx + 0.74, F + 1.35, sz), COLOR.Negro, Enum.Material.SmoothPlastic, m)
	A.adorno("Portezuela", Vector3.new(0.07, 0.62, 0.68), CFrame.new(sx + 0.79, F + 1.35, sz - 0.34) * CFrame.Angles(0, math.rad(65), 0)
		* CFrame.new(0, 0, 0.34), COLOR.Hierro, Enum.Material.Metal, m)
	local arriba = alturaTejado(sx) + 2.1
	cilindro("Tubo", Vector3.new(sx, F + 2.66, sz), Vector3.new(sx, arriba, sz), 0.48, COLOR.Hierro, Enum.Material.CorrodedMetal, m)
	cilindro("Sombrerete", Vector3.new(sx, arriba + 0.32, sz), Vector3.new(sx, arriba + 0.42, sz), 1.0, COLOR.Hierro, Enum.Material.CorrodedMetal, m)
	for i = 0, 2 do
		local a = i * math.pi * 2 / 3
		A.adorno("Patilla", Vector3.new(0.06, 0.36, 0.06), CFrame.new(sx + math.cos(a) * 0.3, arriba + 0.15, sz + math.sin(a) * 0.3), COLOR.Hierro,
			Enum.Material.Metal, m)
	end
	A.choque(Vector3.new(1.75, 2.66, 1.75), CFrame.new(sx, F + 1.33, sz), m)
	A.monton("Ceniza", Vector3.new(1.1, 0.12, 0.8), CFrame.new(sx + 1.15, F + 0.01, sz + 0.15), COLOR.Ceniza, Enum.Material.Sand, m)
	for i, l in { { 0, 0.15 }, { 0.34, 0.05 }, { 0.17, 0.42 } } do
		local y = F + 0.17 + (if i == 3 then 0.28 else 0)
		cilindro("Leno", Vector3.new(sx + 0.85 + l[1], y, sz - 1.25 - l[2] * 0.2), Vector3.new(sx + 1.05 + l[1], y, sz - 0.35 + l[2] * 0.3), 0.34,
			COLOR.Tronco:Lerp(COLOR.Testa, l[2]), Enum.Material.Wood, m)
	end

	-- La mesa del rincón del este, junto a la puerta (tablero a 4): la trampa y una lata encima, el candil apagado y una
	-- caja de cartuchos vacía. Encima, una piel clavada en la pared.
	local mx1, mx2, mz1, mz2, tope = -212.35, x2 - 0.05, z1 + 0.06, z1 + 2.3, 4.0
	ctx.bloque("Mesa", Vector3.new(mx2 - mx1, 0.16, mz2 - mz1), CFrame.new((mx1 + mx2) / 2, tope - 0.08, (mz1 + mz2) / 2), COLOR.Madera,
		Enum.Material.WoodPlanks, m)
	for _, p in { { mx1 + 0.15, mz1 + 0.15 }, { mx2 - 0.15, mz1 + 0.15 }, { mx1 + 0.15, mz2 - 0.15 }, { mx2 - 0.15, mz2 - 0.15 } } do
		ctx.bloque("Pata", Vector3.new(0.22, tope - 0.16 - F, 0.22), CFrame.new(p[1], (F + tope - 0.16) / 2, p[2]), COLOR.MaderaOscura, Enum.Material.Wood, m)
	end
	A.objeto("Trampa", Vector3.new(-211.5, tope + 0.2, 236.4))
	A.objeto("Lata", Vector3.new(-210.7, tope + 0.2, 237.35))
	cajaCartuchos(CFrame.new(-210.55, tope, 235.95) * CFrame.Angles(0, 0.3, 0), m)
	vainas(Vector3.new(-211.2, tope, 237.4), 3, 0.45, azar, m)
	piel(CFrame.new(-211.2, 6.6, z1 + pared + 0.035) * CFrame.Angles(0, math.pi, 0.05), 1.6, 2.1, COLOR.Piel[3], m)
	for _, c in { { -0.6, 0.8 }, { 0.6, 0.8 }, { -0.55, -0.75 }, { 0.55, -0.75 } } do
		A.adorno("Clavo", Vector3.new(0.09, 0.09, 0.09), CFrame.new(-211.2 + c[1], 6.6 + c[2], z1 + pared + 0.07), COLOR.Hierro, Enum.Material.Metal, m).Shape =
			Enum.PartType.Ball
	end

	-- El armero, en la pared del fondo entre el catre y el armario: el tablero, dos travesaños con sus muescas, la canana
	-- de cuero vacía colgando y el hueco del rifle, la madera más clara donde estuvo colgado tantos años. Debajo, la caja
	-- de munición (cerrada: una botella y chatarra encima) y cajas de cartuchos vacías por el suelo.
	local armero = CFrame.lookAt(Vector3.new(-216.1, 5.9, z2 - pared - 0.07), Vector3.new(-216.1, 5.9, z2 - 5))
	A.adorno("Armero", Vector3.new(2.4, 3.4, 0.12), armero, COLOR.MaderaOscura, Enum.Material.Wood, m)
	for _, y in { -1.15, 1.15 } do
		A.adorno("Travesano", Vector3.new(2.4, 0.22, 0.38), armero * CFrame.new(0, y, -0.24), COLOR.Madera, Enum.Material.Wood, m)
		for _, u in { -0.6, 0.4 } do
			A.adorno("Muesca", Vector3.new(0.16, 0.06, 0.2), armero * CFrame.new(u, y + 0.1, -0.33), COLOR.Negro, Enum.Material.SmoothPlastic, m)
		end
	end
	local hueco = armero * CFrame.new(-0.6, 0, -0.065)
	local claro = COLOR.MaderaOscura:Lerp(COLOR.Corte, 0.32)
	A.adorno("Hueco", Vector3.new(0.13, 2.4, 0.01), hueco * CFrame.new(0, 0.45, 0), claro, Enum.Material.Wood, m)
	A.adorno("Hueco", Vector3.new(0.3, 0.9, 0.01), hueco * CFrame.new(0.03, -1.0, 0) * CFrame.Angles(0, 0, 0.06), claro, Enum.Material.Wood, m)
	local gancho = armero * Vector3.new(0.4, 1.05, -0.45)
	for _, s in { -1, 1 } do
		local abajo = armero * Vector3.new(0.4 + s * 0.32, -0.75, -0.3)
		barra("Canana", gancho, abajo, 0.24, 0.04, COLOR.Cuero, Enum.Material.Fabric, m)
		for k = 1, 4 do
			local p = gancho:Lerp(abajo, k / 5)
			A.adorno("Lazo", Vector3.new(0.1, 0.14, 0.05), CFrame.new(p) * armero.Rotation * CFrame.new(0, 0, -0.03), COLOR.Cuero:Lerp(COLOR.Negro, 0.35),
				Enum.Material.Fabric, m)
		end
	end
	ctx.bloque("Caja", Vector3.new(2.0, 1.1, 1.2), CFrame.new(-216.4, F + 0.55, z2 - 0.72), Color3.fromRGB(66, 64, 46), Enum.Material.WoodPlanks, m)
	for _, u in { -0.75, 0.75 } do
		A.adorno("Fleje", Vector3.new(0.12, 1.16, 1.26), CFrame.new(-216.4 + u, F + 0.55, z2 - 0.72), COLOR.Hierro, Enum.Material.Metal, m)
	end
	A.adorno("Asa", Vector3.new(0.5, 0.1, 0.08), CFrame.new(-216.4, F + 0.8, z2 - 1.36), COLOR.Hierro, Enum.Material.Metal, m)
	A.objeto("Botella", Vector3.new(-216.85, F + 1.3, z2 - 0.7))
	A.objeto("Chatarra", Vector3.new(-216.0, F + 1.3, z2 - 0.75))
	cajaCartuchos(CFrame.new(-216.0, F, 242.6) * CFrame.Angles(0, 0.4, 0), m)
	cajaCartuchos(CFrame.new(-217.0, F + 0.23, 238.5) * CFrame.Angles(0, 1.2, math.pi / 2), m)
	vainas(Vector3.new(-215.4, F, 242.5), 6, 0.8, azar, m)

	-- De la ventana al catre: arañazos que bajan del alféizar por dentro y siguen por el suelo hasta el lado del catre.
	local desde, hasta = Vector3.new(x2 - 0.7, 0, 239.7), Vector3.new(cx + 1.5, 0, cz - 2.2)
	local recorrido = hasta - desde
	local dir = recorrido.Unit
	for i, t in { 0.16, 0.5, 0.84 } do
		local p = desde + recorrido * t + Vector3.new(-dir.Z, 0, dir.X) * ((i - 2) * 0.15)
		marca(Vector3.new(p.X, F + 0.015 + i * 0.003, p.Z), Vector3.yAxis, dir, 1.0, 2.7, Mapa.MARCAS.Aranazos, Color3.fromRGB(120, 76, 70), m)
	end
	A.zarpazo(A.enCara(desde - dir * 0.2 + Vector3.new(0, F + 0.012, 0), Vector3.yAxis, dir), 4, 1.4, math.pi / 2, COLOR.Surco, m)
	A.zarpazo(A.enCara(hasta - dir * 0.9 + Vector3.new(0, F + 0.012, 0), Vector3.yAxis, dir), 4, 1.2, math.pi / 2 + 0.1, COLOR.Surco, m)
	A.zarpazo(A.enCara(Vector3.new(x2 - pared - 0.01, 3.1, 239.3), -Vector3.xAxis, Vector3.yAxis), 4, 1.4, math.pi / 2 + 0.08, COLOR.Astilla, m)
	A.zarpazo(A.enCara(Vector3.new(x2 - pared - 0.01, 2.7, 240.3), -Vector3.xAxis, Vector3.yAxis), 3, 1.0, math.pi / 2 - 0.12, COLOR.Astilla, m)

	-- La piel del suelo, en medio, algo movida.
	piel(A.enCara(Vector3.new(-214.4, F + 0.03, 237.3), Vector3.yAxis, Vector3.new(0.35, 0, -1).Unit), 2.2, 3.0, COLOR.Piel[2], m)

	Mapa.conPadre(m, function()
		-- El armario de los aperos (escondite), contra la pared del fondo en el rincón del este: ni tapa la puerta, ni
		-- la ventana, ni el armero.
		Mapa.armario(Vector3.new(-212.5, F + 4, z2 - 1.55), -Vector3.zAxis, "Aperos")
		Mapa.mancha(Vector3.new(-212.0, F + 0.03, 240.7), Vector3.yAxis, 1.0, A.SANGRE.Gotas, A.SECA, 0.9)
		-- La sangre seca del catre: en la lona y salpicada en la pared, junto a la almohada.
		Mapa.mancha(Vector3.new(cx + 0.35, 2.24, cz + 0.9), Vector3.yAxis, 0.8, A.SANGRE.Gotas, A.SECA, 1.1)
		Mapa.mancha(Vector3.new(x1 + pared + 0.02, 3.2, cz + 1.7), Vector3.xAxis, 1.1, A.SANGRE.Salpicadura, A.SECA, 0.6)
		-- Hollín de la estufa en el techo y en la pared, y el candil apagado en la mesa.
		Mapa.mancha(Vector3.new(sx + 0.4, techo - 0.06, sz + 0.5), -Vector3.yAxis, 2.2, Mapa.SANGRE[1], Color3.fromRGB(22, 20, 18), 0.4)
		Mapa.mancha(Vector3.new(x1 + pared + 0.02, 4.4, sz), Vector3.xAxis, 2.4, Mapa.SANGRE[1], Color3.fromRGB(26, 22, 20), 1.3)
		Mapa.mueble("LamparaAceitePH", CFrame.new(-212.0, tope, 237.5) * CFrame.Angles(0, 0.5, 0), true)
		A.telarana(x1 + 0.4, techo, z2 - 0.4, Vector3.new(1, 0, -1), 0.4)
		A.telarana(x2 - 0.4, techo, z1 + 0.4, Vector3.new(-1, 0, 1), 0.35)
		-- Fuera, encima del marco de la puerta: los cuernos de un ciervo clavados en las tablas.
		Mapa.contraPared("CuernosCiervo", CABANA.x, 9.6, z1 - 1, -Vector3.zAxis, true)
	end)
end

---------------------------------------------------------------------------------------------------------------------
-- El patio.

-- El ciervo colgado de un trípode por las patas de atrás, con el vientre hacia la puerta: abierto en canal y seco (un
-- tajo casi negro con los bordes oscuros y el palito que lo tiene abierto; sin vísceras), churretes secos hasta el
-- hocico y el charco seco debajo. Los tres palos chocan; el ciervo, con una caja invisible. Los palos, a 60 grados del
-- vientre a cada lado y uno detrás: el camal cae entre dos.
local function ciervo(g: Model)
	local c = TRIPODE
	local apice = c + Vector3.new(0, 10, 0)
	local mira = (Vector3.new(CABANA.x, 0, CABANA.z - CABANA.largo / 2) - c).Unit
	local alfa = math.atan2(mira.Z, mira.X)
	for k, a in { math.rad(60), math.pi, math.rad(300) } do
		local pie = c + Vector3.new(math.cos(alfa + a) * 3.4, -0.15, math.sin(alfa + a) * 3.4)
		cilindro("Palo", pie, apice + (apice - pie).Unit * 0.8, 0.32, COLOR.Madera:Lerp(COLOR.MaderaOscura, k * 0.25), Enum.Material.Wood, g, true)
	end
	for _, y in { -0.12, 0.06 } do
		cilindro("Atadura", apice + Vector3.new(0, y - 0.04, 0), apice + Vector3.new(0, y + 0.04, 0), 0.78, COLOR.Cuerda, Enum.Material.Fabric, g)
	end
	local colgado = c + Vector3.new(0, 7.5, 0)
	cilindro("Cuerda", apice - Vector3.new(0, 0.15, 0), colgado + Vector3.new(0, 0.05, 0), 0.08, COLOR.Cuerda, Enum.Material.Fabric, g)
	local D = CFrame.lookAt(colgado, colgado + mira) -- -Z: el vientre
	local S = 0.88 -- el ciervo, algo menor que uno de verdad: que la nariz no toque el suelo
	local function en(x: number, y: number, z: number): CFrame
		return D * CFrame.new(x * S, y * S, z * S)
	end
	local function punto(x: number, y: number, z: number): Vector3
		return D * Vector3.new(x * S, y * S, z * S)
	end
	local pelo, tripa = COLOR.Ciervo, COLOR.CiervoClaro
	A.adorno("Camal", Vector3.new(1.8, 0.16, 0.16) * S, en(0, 0, 0), COLOR.MaderaOscura, Enum.Material.Wood, g)
	for _, s in { -1, 1 } do
		A.adorno("Pezuna", Vector3.new(0.17, 0.32, 0.22) * S, en(s * 0.66, 0.26, 0.04), COLOR.Pezuna, Enum.Material.SmoothPlastic, g)
		barra("Pata", punto(s * 0.64, 0.08, 0.05), punto(s * 0.34, -1.55, 0.1), 0.24 * S, 0.26 * S, pelo, Enum.Material.Fabric, g)
		A.monton("Anca", Vector3.new(0.62, 1.15, 0.78) * S, en(s * 0.28, -1.95, 0.08), pelo, Enum.Material.Fabric, g)
	end
	A.monton("Cuerpo", Vector3.new(1.15, 3.0, 1.05) * S, en(0, -3.4, 0.05), pelo, Enum.Material.Fabric, g)
	A.monton("Tripa", Vector3.new(0.9, 2.5, 0.22) * S, en(0, -3.35, -0.44), tripa, Enum.Material.Fabric, g)
	A.adorno("Abierto", Vector3.new(0.42, 2.1, 0.06) * S, en(0, -3.3, -0.55), COLOR.Hueco, Enum.Material.SmoothPlastic, g)
	for _, s in { -1, 1 } do
		A.adorno("Borde", Vector3.new(0.09, 2.15, 0.08) * S, en(s * 0.24, -3.3, -0.54), COLOR.Borde, Enum.Material.SmoothPlastic, g)
	end
	A.adorno("Palito", Vector3.new(0.9, 0.07, 0.07) * S, en(0, -2.75, -0.6), COLOR.MaderaOscura, Enum.Material.Wood, g)
	A.monton("Pecho", Vector3.new(1.0, 1.05, 0.95) * S, en(0, -4.95, 0), pelo, Enum.Material.Fabric, g)
	for _, s in { -1, 1 } do
		local casco = punto(s * 0.45, -6.45, -0.4)
		barra("Pata", punto(s * 0.32, -5.0, -0.12), casco, 0.2 * S, 0.22 * S, pelo, Enum.Material.Fabric, g)
		A.adorno("Pezuna", Vector3.new(0.16, 0.26, 0.2) * S, CFrame.new(casco) * D.Rotation * CFrame.new(0, -0.1, 0), COLOR.Pezuna, Enum.Material.SmoothPlastic, g)
	end
	barra("Cuello", punto(0, -5.25, 0.05), punto(0, -6.2, -0.08), 0.5 * S, 0.56 * S, pelo, Enum.Material.Fabric, g)
	A.monton("Cabeza", Vector3.new(0.5, 0.78, 0.56) * S, en(0, -6.6, -0.12), pelo, Enum.Material.Fabric, g)
	A.monton("Hocico", Vector3.new(0.32, 0.5, 0.36) * S, en(0, -7.05, -0.24), pelo:Lerp(COLOR.Pezuna, 0.2), Enum.Material.Fabric, g)
	A.adorno("Nariz", Vector3.new(0.16, 0.1, 0.14) * S, en(0, -7.3, -0.3), COLOR.Pezuna, Enum.Material.SmoothPlastic, g)
	for _, s in { -1, 1 } do
		A.adorno("Oreja", Vector3.new(0.08, 0.46, 0.24) * S, en(s * 0.27, -6.25, 0.12) * CFrame.Angles(0, 0, s * 0.5), pelo, Enum.Material.Fabric, g)
		A.adorno("Ojo", Vector3.new(0.08, 0.08, 0.08), en(s * 0.2, -6.55, -0.33), COLOR.Pezuna, Enum.Material.SmoothPlastic, g).Shape = Enum.PartType.Ball
	end
	A.adorno("Rabo", Vector3.new(0.26, 0.45, 0.14) * S, en(0, -1.65, 0.5) * CFrame.Angles(0.35, 0, 0), tripa, Enum.Material.Fabric, g)
	barra("Churrete", punto(0.05, -4.45, -0.55), punto(0.02, -5.5, -0.42), 0.12 * S, 0.03, COLOR.Hueco, Enum.Material.SmoothPlastic, g)
	barra("Churrete", punto(-0.06, -5.55, -0.33), punto(-0.02, -6.9, -0.4), 0.09 * S, 0.03, COLOR.Hueco, Enum.Material.SmoothPlastic, g)
	A.choque(Vector3.new(1.3, 6.4, 1.3), en(0, -3.75, 0), g)
	local debajo = punto(0, -7.3, -0.3)
	Mapa.conPadre(g, function()
		Mapa.mancha(Vector3.new(debajo.X, 0.1, debajo.Z), Vector3.yAxis, 2.6, A.SANGRE.Salpicadura, A.SECA, 0.8)
		Mapa.mancha(Vector3.new(debajo.X + 0.6, 0.105, debajo.Z - 0.4), Vector3.yAxis, 1.3, A.SANGRE.Gotas, A.SECA, 2.2)
	end)
end

-- El tendedero: dos postes (chocan) con una cuerda combada y tres pieles dobladas encima, sujetas con pinzas de madera.
local function tendedero(g: Model)
	local alto = 6.2
	for _, p in TENDEDERO do
		cilindro("Poste", p - Vector3.new(0, 0.3, 0), p + Vector3.new(0, alto, 0), 0.38, COLOR.Madera, Enum.Material.Wood, g, true)
	end
	local ta, tb = TENDEDERO[1] + Vector3.new(0, alto - 0.35, 0), TENDEDERO[2] + Vector3.new(0, alto - 0.35, 0)
	local medio = (ta + tb) / 2 - Vector3.new(0, 0.45, 0)
	cilindro("Cuerda", ta, medio, 0.07, COLOR.Cuerda, Enum.Material.Fabric, g)
	cilindro("Cuerda", medio, tb, 0.07, COLOR.Cuerda, Enum.Material.Fabric, g)
	local r = ((tb - ta) * Vector3.new(1, 0, 1)).Unit
	local n = r:Cross(Vector3.yAxis)
	for i, t in { 0.22, 0.5, 0.78 } do
		local sobre = if t < 0.5 then ta:Lerp(medio, t * 2) else medio:Lerp(tb, (t - 0.5) * 2)
		local ancho, largo = 1.5 + i * 0.12, 2.0 + (i % 2) * 0.35
		for _, s in { -1, 1 } do
			local inclina = s * 0.13
			local arriba = Vector3.yAxis * math.cos(inclina) + n * math.sin(inclina)
			piel(CFrame.fromMatrix(sobre - arriba * (largo * 0.42) + n * s * 0.04, r, arriba, r:Cross(arriba)), ancho, largo, COLOR.Piel[i + 1], g, true)
		end
		for _, du in { -0.45, 0.45 } do
			A.adorno("Pinza", Vector3.new(0.09, 0.34, 0.14), CFrame.fromMatrix(sobre + r * du + Vector3.new(0, 0.05, 0), r, Vector3.yAxis, n),
				COLOR.Madera:Lerp(COLOR.Corte, 0.3), Enum.Material.Wood, g)
		end
	end
end

-- Una piel estirada en su bastidor, apoyada en la pared del oeste por fuera, con el cuero hacia fuera y atada al
-- marco con cordeles.
local function bastidor(g: Model)
	local L = 2.6
	local arriba = Vector3.new(0.36, 1, 0).Unit -- recostado hacia la pared (+x)
	local base = Vector3.new(-222.9, 0.07, 239.2)
	local normal = Vector3.zAxis:Cross(arriba) -- hacia fuera de la pared
	local cf = CFrame.fromMatrix(base + arriba * (L / 2), Vector3.zAxis, arriba, normal)
	for _, s in { -1, 1 } do
		A.adorno("Bastidor", Vector3.new(0.14, L + 0.3, 0.14), cf * CFrame.new(s * L / 2, 0, 0), COLOR.Madera, Enum.Material.Wood, g)
		A.adorno("Bastidor", Vector3.new(L + 0.3, 0.14, 0.14), cf * CFrame.new(0, s * L / 2, 0), COLOR.Madera, Enum.Material.Wood, g)
	end
	local cuero = cf * CFrame.Angles(0, math.pi, 0.04)
	piel(cuero, 2.0, 2.2, COLOR.Curtido, g)
	for k = 0, 7 do
		local a = k * math.pi / 4 + 0.2
		local dentroPiel = cf * Vector3.new(math.cos(a) * 0.72, math.sin(a) * 0.8, 0)
		local marco = cf * Vector3.new(math.clamp(math.cos(a) * 2, -1, 1) * L / 2, math.clamp(math.sin(a) * 2, -1, 1) * L / 2, 0)
		barra("Cordel", dentroPiel, marco, 0.03, 0.03, COLOR.Cuerda, Enum.Material.Fabric, g)
	end
end

-- La leñera contra la pared del este, detrás de la ventana (choca una caja), y el tajo delante con leña partida
-- alrededor: chatarra encima del tajo. Un cubo volcado.
local function lenera(g: Model, azar: Random)
	local lx1, lx2, lz1, lz2, la = -208.05, -206.65, 241.8, 245.2, 2.2
	A.choque(Vector3.new(lx2 - lx1, la, lz2 - lz1), CFrame.new((lx1 + lx2) / 2, la / 2, (lz1 + lz2) / 2), g)
	for fila = 0, 3 do
		local y = 0.27 + fila * 0.5
		for col = 0, 5 do
			local z = lz1 + 0.3 + col * 0.56 + (fila % 2) * 0.27
			if z < lz2 - 0.25 and not (fila == 3 and (col == 0 or col == 4)) then
				local partido = azar:NextNumber() < 0.45
				cilindro("Leno", Vector3.new(lx1 + 0.02, y, z), Vector3.new(lx2 - 0.02 + azar:NextNumber(-0.1, 0.1), y, z), 0.52 - azar:NextNumber(0, 0.08),
					if partido then COLOR.Testa else COLOR.Tronco, Enum.Material.Wood, g)
			end
		end
	end
	cilindro("Tajo", TAJO - Vector3.new(0, 0.1, 0), TAJO + Vector3.new(0, 1.45, 0), 1.9, COLOR.Tronco, Enum.Material.Wood, g, true)
	cilindro("Testa", TAJO + Vector3.new(0, 1.45, 0), TAJO + Vector3.new(0, 1.47, 0), 1.82, COLOR.Testa, Enum.Material.Wood, g)
	A.adorno("Tajada", Vector3.new(1.0, 0.03, 0.07), CFrame.new(TAJO + Vector3.new(-0.15, 1.475, 0.35)) * CFrame.Angles(0, 0.5, 0), COLOR.Negro,
		Enum.Material.SmoothPlastic, g)
	for i = 1, 4 do
		local a = i * 1.6
		A.adorno("Leno", Vector3.new(0.32, 0.26, 1.0), CFrame.new(TAJO + Vector3.new(math.cos(a) * 1.6, 0.13, math.sin(a) * 1.6)) * CFrame.Angles(0, a + 0.4, 0.2),
			COLOR.Testa:Lerp(COLOR.Tronco, 0.4), Enum.Material.Wood, g)
	end
	A.objeto("Chatarra", TAJO + Vector3.new(0.25, 1.67, -0.2))
	Mapa.conPadre(g, function()
		Mapa.mueble("CuboPH", CFrame.new(-206.2, 0.68, 240.6) * CFrame.Angles(0, 0.7, math.rad(-84)), true)
	end)
end

-- El cepo de la orilla del claro, cerrado sobre una bota rota (vacía, abierta por arriba) y atado con su cadena a una
-- estaca; sangre seca en las mandíbulas y alrededor.
local function cepo(g: Model)
	local cf = CFrame.new(CEPO) * CFrame.Angles(0, 0.7, 0)
	A.adorno("Cepo", Vector3.new(0.85, 0.08, 0.85), cf * CFrame.new(0, 0.04, 0), COLOR.Oxido, Enum.Material.CorrodedMetal, g)
	for _, s in { -1, 1 } do
		A.adorno("Muelle", Vector3.new(1.15, 0.08, 0.28), cf * CFrame.new(s * 1.0, 0.05, 0) * CFrame.Angles(0, 0, s * 0.07), COLOR.Hierro, Enum.Material.Metal, g)
		A.adorno("Ojal", Vector3.new(0.12, 0.3, 0.42), cf * CFrame.new(s * 1.52, 0.15, 0), COLOR.Hierro, Enum.Material.Metal, g)
		-- La mandíbula cerrada: sube del borde de la base y casi toca la otra por encima de la caña.
		local quijada = cf * CFrame.new(s * 0.22, 0.38, 0) * CFrame.Angles(0, 0, s * 0.12)
		A.adorno("Mandibula", Vector3.new(0.07, 0.72, 1.05), quijada, COLOR.Hierro, Enum.Material.Metal, g)
		A.adorno("SangreSeca", Vector3.new(0.02, 0.3, 0.55), quijada * CFrame.new(-s * 0.045, 0.15, 0.1), COLOR.Hueco, Enum.Material.SmoothPlastic, g)
		for k = -2, 2 do
			A.adorno("Diente", Vector3.new(0.05, 0.12, 0.07), quijada * CFrame.new(-s * 0.04, 0.36, k * 0.2), COLOR.Hierro, Enum.Material.Metal, g)
		end
	end
	-- La bota tumbada: la caña entre las mandíbulas, el pie de lado con la suela hacia fuera y la boca, rota y vacía.
	A.adorno("Bota", Vector3.new(0.3, 0.42, 1.2), cf * CFrame.new(0, 0.3, -0.15), COLOR.Cuero, Enum.Material.Fabric, g)
	A.adorno("Bota", Vector3.new(0.4, 0.5, 0.95), cf * CFrame.new(0.02, 0.27, 0.85) * CFrame.Angles(0, 0.1, 0), COLOR.Cuero, Enum.Material.Fabric, g)
	A.adorno("Suela", Vector3.new(0.09, 0.55, 1.02), cf * CFrame.new(0.26, 0.28, 0.87) * CFrame.Angles(0, 0.1, 0), COLOR.Pezuna, Enum.Material.SmoothPlastic, g)
	A.adorno("Tacon", Vector3.new(0.14, 0.4, 0.3), cf * CFrame.new(0.3, 0.26, 0.48), COLOR.Pezuna, Enum.Material.SmoothPlastic, g)
	A.adorno("Boca", Vector3.new(0.26, 0.34, 0.03), cf * CFrame.new(0, 0.3, -0.76), COLOR.Hueco, Enum.Material.SmoothPlastic, g)
	for _, a in { -0.7, 0.2, 0.9 } do
		A.adorno("Tira", Vector3.new(0.12, 0.04, 0.45), cf * CFrame.new(math.sin(a) * 0.18, 0.3 + math.cos(a) * 0.2, -0.95)
			* CFrame.Angles(math.cos(a) * 0.5, 0, -a), COLOR.Cuero:Lerp(COLOR.Hueco, 0.3), Enum.Material.Fabric, g)
	end
	A.liston("Cordon", cf * Vector3.new(0.1, 0.5, 0.6), cf * Vector3.new(0.45, 0.02, 0.2), 0.04, 0.04, COLOR.Cuerda, Enum.Material.Fabric, g)
	A.liston("Cordon", cf * Vector3.new(0.05, 0.5, 0.55), cf * Vector3.new(-0.5, 0.02, 0.9), 0.04, 0.04, COLOR.Cuerda, Enum.Material.Fabric, g)
	-- La cadena hasta la estaca.
	local desde, hasta = cf * Vector3.new(1.6, 0.05, 0), cf * Vector3.new(2.7, 0.05, 0.6)
	for k = 0, 5 do
		local p = desde:Lerp(hasta, (k + 0.5) / 6)
		A.adorno("Eslabon", Vector3.new(0.1, 0.05, 0.24), CFrame.lookAt(p, p + (hasta - desde)) * CFrame.Angles(0, 0, if k % 2 == 0 then 0 else math.pi / 2),
			COLOR.Oxido, Enum.Material.CorrodedMetal, g)
	end
	A.adorno("Estaca", Vector3.new(0.14, 0.9, 0.14), CFrame.new(hasta + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0.15, 0, -0.1), COLOR.Madera,
		Enum.Material.Wood, g)
	Mapa.conPadre(g, function()
		Mapa.mancha(CEPO + Vector3.new(0.3, 0.03, -0.3), Vector3.yAxis, 1.7, A.SANGRE.Salpicadura, A.SECA, 0.4)
		Mapa.mancha(CEPO + Vector3.new(-0.9, 0.035, 0.6), Vector3.yAxis, 1.1, A.SANGRE.Gotas, A.SECA, 2.4)
	end)
end

-- El arrastre: del cepo al agujero, sangre seca arrastrada, los dos surcos de los talones, uñas clavadas en la tierra y
-- un jirón de franela. El agujero (hondo y negro, con una tapa invisible: nadie se cae), con raíces rotas que asoman,
-- tierra removida, arañazos enormes en el borde y, al lado, el rifle con la culata partida.
local function rastro(g: Model, hoyo: Vector3, azar: Random)
	local x1, x2, z1, z2 = hoyo.X - 1.3, hoyo.X + 1.3, hoyo.Z - 1.1, hoyo.Z + 1.1
	local puntos = table.clone(RASTRO)
	local ultimo = puntos[#puntos]
	table.insert(puntos, hoyo + (ultimo - hoyo).Unit * 1.5)
	local hecho = 0
	for i = 1, #puntos - 1 do
		local a, b = puntos[i], puntos[i + 1]
		local d = b - a
		local dir = d.Unit
		local lado = Vector3.new(-dir.Z, 0, dir.X)
		local n = math.max(1, math.floor(d.Magnitude / 2.4))
		for k = 0, n - 1 do
			local t = (k + 0.5) / n
			local p = a + d * t + lado * azar:NextNumber(-0.25, 0.25)
			local seco = math.clamp((hecho + d.Magnitude * t) / 22, 0, 0.6) -- hacia el agujero, menos
			marca(Vector3.new(p.X, 0.025 + (k % 3) * 0.004, p.Z), Vector3.yAxis, dir, 1.3 * (1 - seco * 0.5), 2.8, A.SANGRE.Arrastre, A.SECA, g)
		end
		for _, s in { -0.35, 0.35 } do
			local medio = (a + b) / 2 + lado * s + Vector3.new(0, 0.02, 0)
			A.adorno("Surco", Vector3.new(0.2, 0.04, d.Magnitude + 0.3), CFrame.lookAt(medio, medio + dir), COLOR.Surco, Enum.Material.Ground, g).CastShadow = false
		end
		hecho += d.Magnitude
	end
	-- Uñas clavadas en la tierra (quería volver) y el jirón de la camisa.
	for _, i in { 2, 3 } do
		local a, b = puntos[i], puntos[i + 1]
		local dir = (b - a).Unit
		A.zarpazo(A.enCara(a:Lerp(b, 0.4) + Vector3.new(0, 0.012, 0), Vector3.yAxis, dir), 4, 1.1, math.pi / 2 + 0.1, COLOR.Surco, g)
	end
	local jiron = CFrame.new(puntos[2]:Lerp(puntos[3], 0.7) + Vector3.new(0.5, 0.02, 0)) * CFrame.Angles(0, 0.8, 0.03)
	A.adorno("Jiron", Vector3.new(0.55, 0.03, 0.4), jiron, COLOR.Franela, Enum.Material.Fabric, g)
	for _, u in { -0.12, 0.12 } do
		A.adorno("Cuadro", Vector3.new(0.55, 0.01, 0.06), jiron * CFrame.new(0, 0.02, u), COLOR.Franela:Lerp(COLOR.Negro, 0.5), Enum.Material.Fabric, g)
	end

	A.agujero(x1, x2, z1, z2, 0, -1.5, {}, g)
	A.tierraRemovida(x1, x2, z1, z2, 0, azar, g)
	for k = 1, 4 do
		local a = k * 1.55
		local borde = Vector3.new(hoyo.X + math.cos(a) * 1.2, -0.25 - k * 0.12, hoyo.Z + math.sin(a) * 1.0)
		barra("Raiz", borde, borde + Vector3.new(-math.cos(a) * 0.5, -0.3, -math.sin(a) * 0.45), 0.08, 0.08, COLOR.Raiz, Enum.Material.Wood, g)
	end
	local haciaFuera = (puntos[#puntos - 1] - hoyo).Unit
	local lateral = Vector3.new(-haciaFuera.Z, 0, haciaFuera.X)
	for _, pos in { hoyo - haciaFuera * 1.9, hoyo - lateral * 1.9 } do
		A.zarpazo(A.enCara(pos + Vector3.new(0, 0.012, 0), Vector3.yAxis, (hoyo - pos).Unit), 4, 2.0, math.pi / 2 + 0.15, COLOR.Surco, g)
	end
	-- El rifle, tirado a lo largo del borde del agujero: la culata partida en dos, el cañón doblado, el cerrojo y
	-- astillas.
	local rifle = CFrame.new(hoyo + lateral * 2.6 + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, math.atan2(-haciaFuera.X, -haciaFuera.Z) + 0.25, 0)
	A.adorno("Culata", Vector3.new(0.22, 0.3, 1.0), rifle * CFrame.new(0.15, 0.03, 1.4) * CFrame.Angles(0, 0.45, 0), COLOR.Madera, Enum.Material.Wood, g)
	A.adorno("Caja", Vector3.new(0.2, 0.2, 1.0), rifle * CFrame.new(0, 0, 0.35), COLOR.Madera, Enum.Material.Wood, g)
	A.adorno("Canon", Vector3.new(0.09, 0.09, 1.6), rifle * CFrame.new(0, 0.04, -0.95), COLOR.Hierro, Enum.Material.Metal, g)
	A.adorno("Canon", Vector3.new(0.09, 0.09, 0.9), rifle * CFrame.new(0.08, 0.04, -2.15) * CFrame.Angles(0, -0.2, 0), COLOR.Hierro, Enum.Material.Metal, g)
	A.adorno("Cerrojo", Vector3.new(0.12, 0.12, 0.4), rifle * CFrame.new(0.06, 0.13, -0.05), COLOR.Hierro, Enum.Material.Metal, g)
	for i = 1, 3 do
		A.adorno("Astilla", Vector3.new(0.05, 0.04, 0.3), rifle * CFrame.new(0.05 * i, 0.02, 0.9 + i * 0.08) * CFrame.Angles(0, i * 0.7, 0), COLOR.Astilla,
			Enum.Material.Wood, g)
	end
end

-- El patio: tierra pisada (tres discos de alturas distintas: no parpadean), la senda de la puerta al borde del claro
-- (sale en el mapa del móvil, como las del bosque) y todo lo de fuera.
local function patio(hoyo: Vector3)
	local g = Instance.new("Model")
	g.Name = "PatioCazador"
	g.Parent = ctx.carpeta
	for i, d in { { -215.5, 230.5, 25 }, { -221.5, 226.5, 16 }, { -209, 232, 14 } } do
		local alto = 0.02 + i * 0.012
		local disco = A.adorno("Tierra", Vector3.new(alto, d[3], d[3]), CFrame.new(d[1], alto / 2, d[2]) * CFrame.Angles(0, 0, math.pi / 2), COLOR.Tierra,
			Enum.Material.Ground, g)
		disco.Shape = Enum.PartType.Cylinder
		disco.CastShadow = false
	end
	local senda = { Vector3.new(-215, 0, 233.4), Vector3.new(-214.3, 0, 224.5), Vector3.new(-213.3, 0, 215.5) }
	for i = 1, #senda - 1 do
		local a, b = senda[i], senda[i + 1]
		local arriba = 0.07 + i * 0.01
		local medio = (a + b) / 2 + Vector3.new(0, arriba - 0.04, 0)
		local tira = A.adorno("Senda", Vector3.new(2.6 - i * 0.3, 0.08, (b - a).Magnitude + 1.2), CFrame.lookAt(medio, medio + (b - a)), COLOR.Senda,
			Enum.Material.Ground, g)
		tira.CastShadow = false
		CollectionService:AddTag(tira, "EnMapa")
	end
	-- Un tronco medio enterrado de escalón delante de la puerta (choca; queda por debajo del suelo de dentro).
	cilindro("Escalon", Vector3.new(CABANA.x - 1.8, 0.4, 233.6), Vector3.new(CABANA.x + 1.8, 0.4, 233.6), 0.84, COLOR.Tronco, Enum.Material.Wood, g, true)
	local azar = Random.new(SEMILLA + 3)
	ciervo(g)
	tendedero(g)
	bastidor(g)
	lenera(g, azar)
	cepo(g)
	rastro(g, hoyo, azar)
end

---------------------------------------------------------------------------------------------------------------------
-- El bosque de la cabaña: los cortes de hacha y la espesura (en el Bosque del mapa).

-- Perfil del tronco de las mallas de Blender (tools/blender/crear_bosque.py): { alto, radio } con el pino de 60 de alto
-- y 1 de radio; Piezas escala "Bark" con el grueso del tronco y "Dead" (el pino seco) con su alto.
local PERFIL = {
	Bark = { { 0, 1.45 }, { 1.4, 1 }, { 30, 0.75 }, { 60, 0.22 } },
	Dead = { { 0, 1.45 }, { 1.4, 1 }, { 30, 0.7 }, { 60, 0.15 } },
}
-- Radio de lo que se ve de un pino de Mapa.arbol a la altura `y`: el de su malla o, sin mallas, el del tronco.
local function radio(tronco: BasePart, y: number): number
	for papel, perfil in PERFIL do
		local malla = tronco:FindFirstChild(papel)
		if malla and malla:IsA("BasePart") then
			local h = malla.Size.Y / 60
			local escala = if papel == "Bark" then malla.Size.X / 2.9 else h
			local my = y / h
			for k = 1, #perfil - 1 do
				local a, b = perfil[k], perfil[k + 1]
				if my <= b[1] or k == #perfil - 1 then
					return escala * (a[2] + (b[2] - a[2]) * math.clamp((my - a[1]) / (b[1] - a[1]), 0, 1))
				end
			end
		end
	end
	local s = tronco.Size
	return math.min(s.X, s.Y, s.Z) / 2
end

-- Un corte de hacha en el tronco, mirando hacia `hacia` (en planta): la corteza arrancada (madera clara en tres tiras
-- que siguen la curva del tronco), el borde de la corteza en sombra arriba y abajo, y astillas a sus pies.
local function corte(tronco: BasePart, hacia: Vector3, padre: Instance, azar: Random)
	local c = tronco.Position
	local dir = Vector3.new(hacia.X, 0, hacia.Z).Unit
	local y, alto, ancho = 4.9, 1.7, 0.3
	local r = math.max(radio(tronco, y - alto / 2), radio(tronco, y + alto / 2)) + 0.03
	local function tira(nombre: string, altura: number, tam: number, color: Color3, mas: number)
		for k = -1, 1 do
			local d = CFrame.Angles(0, k * ancho / r, 0):VectorToWorldSpace(dir)
			local pos = Vector3.new(c.X, altura, c.Z) + d * (r + mas)
			A.adorno(nombre, Vector3.new(ancho + 0.01, tam - math.abs(k) * 0.12 * (tam / alto), 0.05), CFrame.lookAt(pos, pos + d), color, Enum.Material.Wood, padre)
		end
	end
	tira("Corte", y, alto, COLOR.Corte, 0)
	for _, s in { -1, 1 } do
		tira("Borde", y + s * (alto / 2 + 0.03), 0.12, COLOR.TroncoOscuro, 0.015)
	end
	for _ = 1, 5 do
		local d = CFrame.Angles(0, azar:NextNumber(-0.9, 0.9), 0):VectorToWorldSpace(dir)
		local p = Vector3.new(c.X, 0.04, c.Z) + d * (r + azar:NextNumber(0.4, 1.8))
		A.adorno("Astilla", Vector3.new(azar:NextNumber(0.12, 0.22), 0.05, azar:NextNumber(0.35, 0.7)),
			CFrame.new(p) * CFrame.Angles(0, azar:NextNumber(0, math.pi), 0), COLOR.Corte, Enum.Material.Wood, padre)
	end
end

-- Los pinos con su corte, de la senda del aserradero al claro (cada uno, en su modelo PinoCortado). El tronco, tan
-- gordo como su malla (alto / 30): así el corte va pegado a la corteza sea cual sea el pino que salga. Si el sitio cae
-- encima de algo del bosque, se aparta unos pasos.
local function cortes(bosque: Instance, ocupados: { { number } }, azar: Random)
	local C = LugarCazador.CORTES
	local anterior: Vector3? = nil
	for i = 1, C.n do
		local p = C.desde:Lerp(C.hasta, (i - 1) / (C.n - 1)) + Vector3.new(C.lado[i], 0, 0)
		local alto = azar:NextNumber(54, 70)
		local grueso = alto / 30
		local x, z = p.X, p.Z
		for _, o in { { 0, 0 }, { 5, 0 }, { -5, 0 }, { 0, 5 }, { 0, -5 }, { 7, 7 }, { -7, -7 } } do
			if libre(ocupados, p.X + o[1], p.Z + o[2], grueso / 2 + 1.5) then
				x, z = p.X + o[1], p.Z + o[2]
				break
			end
		end
		local modelo = Instance.new("Model")
		modelo.Name = "PinoCortado"
		Mapa.arbol(x, z, alto, grueso, modelo)
		local tronco = modelo:FindFirstChild("Tronco") :: BasePart?
		if tronco then
			local aqui = Vector3.new(x, 0, z)
			-- Mira al anterior (el primero, a la senda) y el primero, también hacia la casa (se llega por la senda desde el
			-- este): se ven al llegar.
			corte(tronco, if anterior then anterior - aqui else -Vector3.zAxis, modelo, azar)
			if not anterior then
				corte(tronco, Vector3.xAxis, modelo, azar)
			end
			anterior = aqui
			table.insert(ocupados, { x, z, grueso / 2 })
		end
		modelo.Parent = bosque
	end
end

-- ¿Se puede poner un pino de la espesura en (x, z) con radio `r`? Fuera del claro (CLARO de la cabaña y el patio), del
-- camino de los cortes, del arrastre y del agujero, y sin pisar nada del bosque.
local function sitioEspesura(x: number, z: number, r: number, hoyo: Vector3, ocupados: { { number } }): boolean
	local caja, corral = LugarCazador.CAJA, LugarCazador.PATIO
	local dx = math.max(caja.x1 - x, 0, x - caja.x2)
	local dz = math.max(caja.z1 - z, 0, z - caja.z2)
	if math.sqrt(dx * dx + dz * dz) < LugarCazador.CLARO + r or (x - corral.x) ^ 2 + (z - corral.z) ^ 2 < (corral.radio + r) ^ 2 then
		return false
	end
	local C = LugarCazador.CORTES
	local camino = { C.desde:Lerp(C.hasta, (C.n - 2) / (C.n - 1)), C.hasta, Vector3.new(-213.3, 0, 215.5) }
	for i = 1, #camino - 1 do
		if aTramo(x, z, camino[i], camino[i + 1]) < 3.5 + r then
			return false
		end
	end
	local arrastre = table.clone(RASTRO)
	table.insert(arrastre, hoyo)
	for i = 1, #arrastre - 1 do
		if aTramo(x, z, arrastre[i], arrastre[i + 1]) < 3 + r then
			return false
		end
	end
	return (x - hoyo.X) ^ 2 + (z - hoyo.Z) ^ 2 > (4.5 + r) ^ 2 and libre(ocupados, x, z, r + 1.2)
end

-- La espesura alrededor del claro: pinos como los del bosque en una rejilla con desvío, muy juntos dentro de la zona
-- sin bosque y cada vez menos hacia fuera (hasta 52 del centro). Se piden siempre los mismos números por punto.
local function espesura(bosque: Instance, hoyo: Vector3, ocupados: { { number } })
	local azar = Random.new(SEMILLA + 5)
	local Z = LugarCazador.ZONA
	local PASO = 8.5
	for gx = Z.X - 52, Z.X + 52, PASO do
		for gz = Z.Z - 52, Z.Z + 52, PASO do
			local x, z = gx + azar:NextNumber(-3.2, 3.2), gz + azar:NextNumber(-3.2, 3.2)
			local alto, grueso, suerte = azar:NextNumber(50, 76), azar:NextNumber(2, 3.6), azar:NextNumber()
			local d = math.sqrt((x - Z.X) ^ 2 + (z - Z.Z) ^ 2)
			local queda = if d < 34 then 0.9 elseif d < 43 then 0.6 else 0.35
			if d <= 52 and suerte < queda and sitioEspesura(x, z, grueso / 2, hoyo, ocupados) then
				Mapa.arbol(x, z, alto, grueso, bosque)
				table.insert(ocupados, { x, z, grueso / 2 })
			end
		end
	end
end

---------------------------------------------------------------------------------------------------------------------

function LugarCazador.construir(contexto, ayudas)
	ctx, A = contexto, ayudas
	Mapa = contexto.Mapa
	local bosqueMapa = A.raiz and A.raiz:FindFirstChild("Bosque")
	local ocupados = ocupado(bosqueMapa)
	local hoyo = HOYOS[1]
	for _, h in HOYOS do
		if libre(ocupados, h.X, h.Z, 4.5) then
			hoyo = h
			break
		end
	end

	local m = PuebloFachadas.uno(ctx, CABANA, ESTILO, PUERTA, SEMILLA)
	troncos(m)
	puertaRota(m)
	ventanaRota(m, Random.new(SEMILLA + 6))
	dentro(m)
	patio(hoyo)

	local bosque = Instance.new("Folder")
	bosque.Name = "Cazador"
	local azar = Random.new(SEMILLA + 4)
	cortes(bosque, ocupados, azar)
	espesura(bosque, hoyo, ocupados)
	bosque.Parent = bosqueMapa or ctx.carpeta
end

return LugarCazador
