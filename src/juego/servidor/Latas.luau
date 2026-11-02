-- Trampas de latas (14.3, diseño: "latas colgadas que suenan y avisan de por dónde viene algo"). Alrededor del claro de
-- la casa, en el borde del bosque, hay líneas de cuerda tensada entre dos estacas con latas oxidadas y alguna botella
-- colgando. Están donde cruzan los bichos al llegar a cada ventana o puerta (salen a ~75 studs de ella, de frente:
-- Golpeador, Raspador, Imitador, Trepador, Bestia) y donde el Acechador se rinde (Config.Acechador.Refugio), así que
-- cada lado de la casa tiene las suyas y el tintineo dice POR DÓNDE viene. Ninguna cruza la carretera ni el camino del
-- coche al huir (HuidaVista), y nada choca ni tapa rayos (ni la vista de los bichos ni la linterna).
--   Aquí solo van las estacas: la cuerda, las latas y su balanceo los pone el cliente (LatasVista) con los atributos de
--   cada línea (Model "Linea" en workspace.Mapa.Latas): Linea (n), A y B (los nudos de la cuerda), Comba (lo que cuelga
--   en el medio) y Semilla (para que todos vean las mismas latas).
--   Cada CFG.Cada s mira a todos los bichos (Caza.todos) y a los jugadores vivos: si uno cruza una línea o entra a menos
--   de CFG.Radio de ella, Remotes.Latas:FireAllClients("Suena", n, fuerza, donde) (donde = 0..1 a lo largo de la cuerda).
--   Cada línea espera CFG.Espera s entre dos avisos de bicho; los jugadores suenan más flojo y no tapan a los bichos.
-- Modo de pruebas: ServerStorage.Prueba:Fire("Latas", punto) hace sonar la línea más cerca del punto como si pasara un
-- bicho (sin punto, todas una detrás de otra).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Prueba = require(ReplicatedStorage.Shared.Prueba)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Caza = require(script.Parent.Caza)
local Muerte = require(script.Parent.Muerte)

local Latas = {}

-- Números a ojo.
local CFG = Config.Latas
Latas.CFG = CFG

type Linea = {
	n: number,
	a: Vector3, -- en planta (y = 0)
	b: Vector3,
	soloBichos: boolean,
	ultimaBicho: number,
	ultimaJugador: number,
}
local lineas: { Linea } = {}

local MADERA = Color3.fromRGB(66, 52, 40) -- estaca vieja, mojada
local CUERDA = Color3.fromRGB(92, 84, 68)
local SANGRE = Color3.fromRGB(62, 8, 7)

local function pieza(nombre: string, tamano: Vector3, cf: CFrame, color: Color3, material: Enum.Material, padre: Instance): Part
	local p = Instance.new("Part")
	p.Name = nombre
	p.Anchored = true
	p.CanCollide = false -- ni jugadores ni bichos se atascan
	p.CanQuery = false -- ni tapa la vista de los bichos ni la linterna
	p.CanTouch = false
	p.Size = tamano
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = padre
	return p
end

-- Si un tronco del bosque (o un árbol de los que se talan) cae justo donde va una estaca, la estaca se aparta un poco
-- hacia dentro de la línea: que no salga clavada en el árbol.
local function troncos(): { BasePart }
	local lista = {}
	local bosque = workspace:FindFirstChild("Mapa") and workspace.Mapa:FindFirstChild("Bosque")
	if not bosque then
		return lista
	end
	for _, cosa in bosque:GetChildren() do
		if cosa:IsA("BasePart") and cosa.Name == "Tronco" then
			table.insert(lista, cosa)
		end
	end
	local arboles = bosque:FindFirstChild("Arboles")
	for _, arbol in if arboles then arboles:GetChildren() else {} do
		local tronco = arbol:IsA("Model") and arbol.PrimaryPart
		if tronco then
			table.insert(lista, tronco)
		end
	end
	return lista
end

local function libreDeTroncos(p: Vector3, hacia: Vector3, lista: { BasePart }): Vector3
	for _ = 1, 8 do
		local choca = false
		for _, t in lista do
			local d = Vector3.new(t.Position.X - p.X, 0, t.Position.Z - p.Z).Magnitude
			if d < t.Size.Y / 2 + 1.2 then -- el tronco es un cilindro tumbado: Size.Y es su grosor
				choca = true
				break
			end
		end
		if not choca then
			return p
		end
		p += hacia * 1.5
	end
	return p
end

-- Una estaca clavada en `base` (a ras de suelo), un poco inclinada hacia fuera de la línea (la tensa la cuerda).
-- Devuelve dónde va el nudo de la cuerda.
local function estaca(base: Vector3, fuera: Vector3, alto: number, padre: Instance, azar: Random, manchada: boolean): Vector3
	local inclina = math.rad(if alto > CFG.Alto then azar:NextNumber(2, 5) else azar:NextNumber(5, 11))
	local eje = (Vector3.yAxis * math.cos(inclina) + fuera * math.sin(inclina)).Unit
	local lado = eje:Cross(fuera).Unit
	local largo, enterrado = alto + 1, 0.9
	local grueso = if alto > CFG.Alto then 0.6 else 0.42 -- los postes altos, más gordos
	local centro = base + eje * ((largo - enterrado) / 2) -- de enterrado bajo el suelo a largo encima
	local giro = CFrame.fromMatrix(centro, lado, eje) * CFrame.Angles(0, azar:NextNumber(0, math.pi), 0)
	local palo = pieza("Estaca", Vector3.new(grueso, largo + enterrado, grueso), giro, MADERA, Enum.Material.Wood, padre)
	palo.CastShadow = true
	-- La punta astillada (un taco más fino arriba) y la vuelta de cuerda del nudo.
	pieza("Punta", Vector3.new(grueso * 0.7, 0.35, grueso * 0.7), giro * CFrame.new(0, (largo + enterrado) / 2 + 0.12, 0) * CFrame.Angles(0, 0.6, 0.12),
		MADERA:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Wood, padre).CastShadow = false
	local nudo = base + eje * alto
	local vuelta = pieza("Nudo", Vector3.new(0.22, grueso + 0.14, grueso + 0.14), CFrame.fromMatrix(nudo, eje, lado), CUERDA, Enum.Material.Fabric, padre)
	vuelta.Shape = Enum.PartType.Cylinder
	vuelta.CastShadow = false
	-- Un poco de barro en el pie y, en alguna, la marca de una mano con sangre seca.
	pieza("Barro", Vector3.new(1.3, 0.12, 1.3), CFrame.new(base + Vector3.new(0, 0.04, 0)) * CFrame.Angles(0, azar:NextNumber(0, 6), 0),
		Color3.fromRGB(52, 44, 34), Enum.Material.Mud, padre).CastShadow = false
	if manchada then
		local mano = azar:NextNumber(2.2, 3.4)
		pieza("Sangre", Vector3.new(0.44, 0.9, 0.05), giro * CFrame.new(0, mano - (largo - enterrado) / 2, -grueso / 2) * CFrame.Angles(0, 0, 0.2),
			SANGRE, Enum.Material.SmoothPlastic, padre).CastShadow = false
		pieza("Gotas", Vector3.new(0.12, 1.1, 0.05), giro * CFrame.new(0.08, mano - (largo - enterrado) / 2 - 0.8, -grueso / 2), SANGRE,
			Enum.Material.SmoothPlastic, padre).CastShadow = false
	end
	return nudo
end

local function construir()
	local carpeta = Instance.new("Folder")
	carpeta.Name = "Latas"
	local lista = troncos()
	for n, l in CFG.Lineas do
		local azar = Random.new(n * 977)
		local a, b = Vector3.new(l[1], 0, l[2]), Vector3.new(l[3], 0, l[4])
		local dir = (b - a).Unit
		a = libreDeTroncos(a, dir, lista)
		b = libreDeTroncos(b, -dir, lista)
		local especial = CFG.Especiales[n]
		local alto = if especial then especial.Alto else CFG.Alto
		local modelo = Instance.new("Model")
		modelo.Name = "Linea"
		local nudoA = estaca(a, -dir, alto, modelo, azar, n % 4 == 2)
		local nudoB = estaca(b, dir, alto, modelo, azar, false)
		modelo:SetAttribute("Linea", n)
		modelo:SetAttribute("A", nudoA)
		modelo:SetAttribute("B", nudoB)
		modelo:SetAttribute("Comba", (if especial then especial.Comba else CFG.Comba) * azar:NextNumber(0.8, 1.25))
		modelo:SetAttribute("Semilla", n * 131 + 7)
		modelo.Parent = carpeta
		table.insert(lineas, {
			n = n,
			a = a,
			b = b,
			soloBichos = especial ~= nil and especial.SoloBichos,
			ultimaBicho = -math.huge, ultimaJugador = -math.huge })
	end
	carpeta.Parent = workspace:WaitForChild("Mapa")
end

-- En planta: ¿se cortan los segmentos p1-p2 y q1-q2? (x, z)
local function cruzan(p1: Vector3, p2: Vector3, q1: Vector3, q2: Vector3): boolean
	local function lado(o: Vector3, a: Vector3, b: Vector3): number
		return (a.X - o.X) * (b.Z - o.Z) - (a.Z - o.Z) * (b.X - o.X)
	end
	local d1, d2 = lado(q1, q2, p1), lado(q1, q2, p2)
	local d3, d4 = lado(p1, p2, q1), lado(p1, p2, q2)
	return ((d1 > 0) ~= (d2 > 0)) and ((d3 > 0) ~= (d4 > 0))
end

-- Distancia en planta de `p` a la línea y por dónde de ella (0..1).
local function aLinea(p: Vector3, l: Linea): (number, number)
	local ab = l.b - l.a
	local plano = Vector3.new(p.X, 0, p.Z)
	local t = math.clamp((plano - l.a):Dot(ab) / ab:Dot(ab), 0, 1)
	return (plano - (l.a + ab * t)).Magnitude, t
end

local function sonar(l: Linea, fuerza: number, donde: number)
	Remotes.Latas:FireAllClients("Suena", l.n, math.clamp(fuerza, 0, 1), donde)
end

-- Lo que se mueve fuera: cada cosa que puede tocar las cuerdas con su posición de la mirada anterior y en qué líneas
-- estaba ya metida (para sonar al entrar, no cada vez que se mira mientras sigue al lado).
type Rastro = { antes: Vector3?, dentro: { [number]: boolean } }
local rastros: { [any]: Rastro } = setmetatable({}, { __mode = "k" }) :: any

local function mirar(clave: any, pos: Vector3, esBicho: boolean, ahora: number)
	local r = rastros[clave]
	if not r then
		r = { antes = nil, dentro = {} }
		rastros[clave] = r
	end
	local antes = r.antes
	r.antes = pos
	if pos.Y < -3 or pos.Y > 20 then -- en el sótano o en el tejado: lejos de las cuerdas
		table.clear(r.dentro)
		return
	end
	local paso = if antes then Vector3.new(pos.X - antes.X, 0, pos.Z - antes.Z).Magnitude else 0
	local saltado = paso > CFG.Salto
	local velocidad = paso / CFG.Cada
	for _, l in lineas do
		if l.soloBichos and not esBicho then
			continue -- pasan por debajo
		end
		local d, donde = aLinea(pos, l)
		local cerca = d < CFG.Radio
		local cruzo = antes ~= nil and not saltado and cruzan(antes, pos, l.a, l.b)
		local entra = (cerca or cruzo) and not r.dentro[l.n]
		r.dentro[l.n] = cerca or nil
		if not entra then
			continue
		end
		local rango = if esBicho then CFG.FuerzaBicho else CFG.FuerzaJugador
		local fuerza = rango[1] + (rango[2] - rango[1]) * math.clamp(velocidad / CFG.Rapido, 0, 1)
		if esBicho and ahora - l.ultimaBicho >= CFG.Espera then
			l.ultimaBicho = ahora
			sonar(l, fuerza, donde)
		elseif not esBicho and ahora - l.ultimaJugador >= CFG.EsperaJugador and ahora - l.ultimaBicho >= 1 then
			l.ultimaJugador = ahora
			sonar(l, fuerza, donde)
		end
	end
end

local function vigilar()
	while true do
		task.wait(CFG.Cada)
		local ahora = os.clock()
		for _, b in Caza.todos() do
			if b.modelo and b.raiz.Parent then
				mirar(b, b.raiz.Position, true, ahora)
			end
		end
		for _, jugador in Muerte.vivos() do
			local personaje = jugador.Character
			local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
			if raiz and not jugador:GetAttribute("Escondido") then
				mirar(jugador, raiz.Position, false, ahora)
			end
		end
	end
end

-- La línea más cerca de un punto (modo de pruebas).
local function masCerca(punto: Vector3): Linea?
	local mejor, distancia = nil, math.huge
	for _, l in lineas do
		local d = aLinea(punto, l)
		if d < distancia then
			mejor, distancia = l, d
		end
	end
	return mejor
end

function Latas.start()
	construir()
	task.spawn(vigilar)
	Players.PlayerRemoving:Connect(function(jugador)
		rastros[jugador] = nil
	end)
	if Prueba.activa() then
		task.spawn(function()
			local orden = ServerStorage:WaitForChild("Prueba", 10) :: BindableEvent?
			if not orden then
				return
			end
			orden.Event:Connect(function(que: string, punto: Vector3?)
				if que ~= "Latas" then
					return
				end
				if punto then
					local l = masCerca(punto)
					if l then
						local _, donde = aLinea(punto, l)
						sonar(l, 1, donde)
					end
				else
					for _, l in lineas do
						sonar(l, 1, 0.5)
						task.wait(1.5)
					end
				end
			end)
		end)
	end
end

return Latas
