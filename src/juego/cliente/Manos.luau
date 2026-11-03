-- Brazos y manos en primera persona (pedido por el usuario: "que se vea como tú lo abres o lo cierras con las manos",
-- y lo mismo con todo lo que se pueda; "lo importante es que todo esté animado y sea inmersivo"). Solo los ve el
-- jugador local y cuelgan de la cámara. Son los brazos de tu avatar (copias de RightUpperArm, RightLowerArm,
-- RightHand… con tu camiseta y tu color de piel); sin dedos (pedido por el usuario: hay avatares que no tienen). Con
-- un avatar R6 o sin cargar, un brazo sencillo de bloques. Los demás ven tu personaje con BrazosVista.
--
-- Cómo se mueven:
--   Cada mano tiene un objetivo en el mundo: el CFrame de la palma (-Z hacia donde apuntan los dedos, +Y el dorso). El
--   codo sale solo (cinemática inversa de dos huesos desde un hombro que queda fuera de la pantalla).
--   Quién manda en cada mano: capas con prioridad. Las de sostener (Manos.capa: la linterna, lo que cargas, la
--   herramienta) duran mientras su función devuelva algo; los gestos (Manos.gesto: abrir una cortina, coger algo)
--   duran unos segundos. En cada fotograma, cada mano hace lo de la capa de más prioridad que la pida; si ninguna la
--   pide, baja fuera de la vista.
--   La mano va hacia su objetivo con un muelle en el espacio de la cámara (sin tirones al girar); una capa puede pedir
--   `velocidad = math.huge` para ir pegada (las herramientas que se mueven deprisa).
--   Cosas en la mano (la linterna, la cámara, una cerilla): Manos.cosa(nombre, crear, enMano) las registra y una capa
--   las pide con `cosaDer` / `cosaIzq`.
-- Se esconden muerto, escondido, con la mochila abierta, en tercera persona o en las cinemáticas (cámara Scriptable),
-- salvo los gestos con `siempre` (el susto al morir).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Manos = {}

export type Pose = {
	der: CFrame?, -- objetivo de la palma derecha, en el mundo
	izq: CFrame?,
	cosaDer: string?, -- cosa registrada que lleva en esa mano
	cosaIzq: string?,
	velocidad: number?, -- del muelle (por defecto VELOCIDAD); math.huge = pegada
	siempre: boolean?, -- también cuando se esconden (el susto)
}
type Capa = { prioridad: number, fn: (dt: number) -> Pose?, gesto: boolean }
type Cosa = { crear: () -> Model, enMano: CFrame, modelo: Model?, partes: { BasePart }, rel: { CFrame } }

local jugador = Players.LocalPlayer
local camara = workspace.CurrentCamera

local VELOCIDAD = 14 -- del muelle: cuanto más, más deprisa llega la mano
local L1, L2 = 1.2, 1.15 -- brazo y antebrazo, de junta a junta (todos los avatares igual)
local HOMBRO = { der = Vector3.new(0.75, -1.25, 0.2), izq = Vector3.new(-0.75, -1.25, 0.2) } -- en la cámara, fuera de la vista
local REPOSO = { -- abajo, fuera de la vista
	der = CFrame.new(0.8, -2.5, -0.45) * CFrame.Angles(math.rad(-80), 0, 0),
	izq = CFrame.new(-0.8, -2.5, -0.45) * CFrame.Angles(math.rad(-80), 0, 0),
}
local LADOS = { "der", "izq" }
local SIGNO = { der = 1, izq = -1 }
local NOMBRES = { -- las piezas R15 de cada lado y sus juntas
	der = { "RightUpperArm", "RightLowerArm", "RightHand", "RightShoulderRigAttachment", "RightElbowRigAttachment",
		"RightWristRigAttachment" },
	izq = { "LeftUpperArm", "LeftLowerArm", "LeftHand", "LeftShoulderRigAttachment", "LeftElbowRigAttachment",
		"LeftWristRigAttachment" },
}

local CHAQUETA = Color3.fromRGB(44, 42, 40) -- el brazo de bloques: manga oscura
local PIEL = Color3.fromRGB(204, 160, 128)

local capas: { [string]: Capa } = {}
local cosas: { [string]: Cosa } = {}

-- Un trozo del brazo: la pieza y dónde tiene sus dos juntas (arriba = hacia el hombro), en su espacio.
type Trozo = { parte: BasePart, arriba: Vector3, abajo: Vector3 }
type Brazo = {
	rel: CFrame, -- donde está la palma ahora, en el espacio de la cámara
	brazo: Trozo,
	antebrazo: Trozo,
	mano: Trozo, -- arriba = la muñeca
	l1: number, -- largos (los del avatar)
	l2: number,
	cosa: string?,
}
local brazos: { [string]: Brazo } = {}
local modelo: Model
local piezas: { BasePart } = {}
local sitios: { CFrame } = {}
local visible = false

local function suelta(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
end

local function bloque(nombre: string, tam: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = nombre
	p.Size = tam
	p.Color = color
	p.Material = material
	suelta(p)
	p.Parent = modelo
	return p
end

-- El brazo de bloques (R6 o sin avatar todavía).
local function brazoSencillo(lado: string): Brazo
	local function trozo(nombre: string, tam: Vector3, color: Color3, material: Enum.Material): Trozo
		return { parte = bloque(nombre, tam, color, material), arriba = Vector3.new(0, tam.Y / 2, 0),
			abajo = Vector3.new(0, -tam.Y / 2, 0) }
	end
	return {
		rel = REPOSO[lado],
		brazo = trozo("Brazo", Vector3.new(0.42, L1, 0.42), CHAQUETA, Enum.Material.Fabric),
		antebrazo = trozo("Antebrazo", Vector3.new(0.38, L2, 0.38), CHAQUETA, Enum.Material.Fabric),
		mano = trozo("Mano", Vector3.new(0.36, 0.36, 0.3), PIEL, Enum.Material.SmoothPlastic),
		l1 = L1,
		l2 = L2,
		cosa = nil,
	}
end

-- Copia de los brazos del avatar (R15). nil si no los tiene.
local function brazoDelAvatar(personaje: Model, lado: string): Brazo?
	local n = NOMBRES[lado]
	local superior = personaje:FindFirstChild(n[1])
	local inferior = personaje:FindFirstChild(n[2])
	local mano = personaje:FindFirstChild(n[3])
	if not (superior and inferior and mano and superior:IsA("BasePart") and inferior:IsA("BasePart") and mano:IsA("BasePart")) then
		return nil
	end
	local hombro = superior:FindFirstChild(n[4]) :: Attachment?
	local codoA = superior:FindFirstChild(n[5]) :: Attachment?
	local codoB = inferior:FindFirstChild(n[5]) :: Attachment?
	local munecaA = inferior:FindFirstChild(n[6]) :: Attachment?
	local munecaB = mano:FindFirstChild(n[6]) :: Attachment?
	if not (hombro and codoA and codoB and munecaA and munecaB) then
		return nil
	end
	-- Copia de la pieza, estirada o encogida a la medida de los brazos de primera persona: `ancho` de grueso (los del
	-- avatar miden un stud y taparían media pantalla) y `largo` de junta a junta (igual con todos los avatares).
	local function copia(p: BasePart, arriba: Vector3, abajo: Vector3, ancho: number, largo: number): Trozo
		local archivable = p.Archivable
		p.Archivable = true
		local c = p:Clone() :: BasePart
		p.Archivable = archivable
		for _, hijo in c:GetChildren() do
			if not (hijo:IsA("SpecialMesh") or hijo:IsA("SurfaceAppearance") or hijo:IsA("WrapTarget")) then
				hijo:Destroy() -- juntas, scripts, sonidos…
			end
		end
		local junta = (arriba - abajo).Magnitude
		local k = Vector3.new(ancho / p.Size.X, largo / math.max(junta, 0.05), ancho / p.Size.X)
		c.Size = p.Size * k
		suelta(c)
		c.Transparency = 0
		c.LocalTransparencyModifier = 0 -- en primera persona el personaje lo tiene a 1 y la copia podría heredarlo
		c.Parent = modelo
		return { parte = c, arriba = arriba * k, abajo = abajo * k }
	end
	local finMano = munecaB.Position - Vector3.new(0, mano.Size.Y, 0) -- la punta de la mano (sin junta)
	return {
		rel = REPOSO[lado],
		brazo = copia(superior, hombro.Position, codoA.Position, 0.42, L1),
		antebrazo = copia(inferior, codoB.Position, munecaA.Position, 0.38, L2),
		mano = copia(mano, munecaB.Position, finMano, 0.36, 0.36),
		l1 = L1,
		l2 = L2,
		cosa = nil,
	}
end

-- (Re)hace los dos brazos con los del avatar, con su camiseta (hace falta un Humanoid en el modelo para que se vea la
-- ropa) y sus colores.
local function rehacer(personaje: Model?)
	for _, b in brazos do
		local vieja = b.cosa and cosas[b.cosa]
		if vieja and vieja.modelo then
			vieja.modelo.Parent = nil
		end
	end
	modelo:ClearAllChildren()
	for _, c in cosas do -- las cosas en la mano se vuelven a crear al pedirlas
		c.modelo = nil
		table.clear(c.partes)
		table.clear(c.rel)
	end
	local humanoide = Instance.new("Humanoid")
	humanoide.RequiresNeck = false
	humanoide.BreakJointsOnDeath = false
	humanoide.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoide.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoide.EvaluateStateMachine = false
	-- Con un Humanoid R15 la camiseta se pinta en las copias de los brazos R15.
	if personaje and personaje:FindFirstChild("RightUpperArm") then
		humanoide.RigType = Enum.HumanoidRigType.R15
	end
	humanoide.Parent = modelo
	if personaje then
		for _, ropa in personaje:GetChildren() do
			if ropa:IsA("Shirt") or ropa:IsA("BodyColors") then
				ropa:Clone().Parent = modelo
			end
		end
	end
	for _, lado in LADOS do
		local b = personaje and brazoDelAvatar(personaje, lado) or brazoSencillo(lado)
		local viejo = brazos[lado]
		if viejo then
			b.rel = viejo.rel
		end
		brazos[lado] = b
	end
end

-- ===== Ayudas para las capas (todo en el mundo) =====

-- La palma en `punto`, con los dedos hacia `dedos` y el dorso hacia `dorso` (se endereza solo).
function Manos.palma(punto: Vector3, dedos: Vector3, dorso: Vector3): CFrame
	local z = -dedos.Unit
	local y = dorso - z * dorso:Dot(z)
	if y.Magnitude < 1e-3 then
		y = if math.abs(z.Y) < 0.9 then Vector3.yAxis else Vector3.xAxis
		y -= z * y:Dot(z)
	end
	y = y.Unit
	return CFrame.fromMatrix(punto, y:Cross(z), y, z)
end

-- La palma agarrando una vara (un mango) que pasa por `centro` con su eje `eje` hacia donde queda el pulgar; el dorso
-- hacia `dorso`. La vara queda pegada a la palma, entre los dedos cerrados.
function Manos.vara(lado: string, centro: Vector3, eje: Vector3, dorso: Vector3): CFrame
	local x = eje.Unit * -SIGNO[lado] -- el pulgar de la derecha queda en -X de la palma; el de la izquierda en +X
	local y = dorso - x * dorso:Dot(x)
	if y.Magnitude < 1e-3 then
		y = Vector3.yAxis - x * x.Y
	end
	y = y.Unit
	return CFrame.fromMatrix(centro + y * 0.13, x, y, x:Cross(y))
end

-- Dónde está el hombro de ese lado, en el mundo.
function Manos.hombro(lado: string): Vector3
	return camara.CFrame * HOMBRO[lado]
end

-- La palma yendo hacia `punto` desde su hombro (si está más lejos de lo que llega el brazo, se queda estirada hacia
-- allí). `palma`: "abajo" (dorso arriba), "dentro" (hacia la otra mano), "delante" (empujando) o "agarra" (de
-- frente, para un pomo o una tela).
function Manos.hacia(lado: string, punto: Vector3, palma: string?): CFrame
	local h = Manos.hombro(lado)
	local d = punto - h
	local b = brazos[lado]
	local alcance = if b then b.l1 + b.l2 - 0.05 else 2.4
	if d.Magnitude > alcance then
		punto = h + d.Unit * alcance
	end
	local cf = camara.CFrame
	local dedos = if d.Magnitude > 0.05 then d.Unit else cf.LookVector
	if palma == "dentro" then
		return Manos.palma(punto, dedos, cf.RightVector * SIGNO[lado])
	elseif palma == "delante" then
		return Manos.palma(punto, cf.UpVector + dedos * 0.2, -dedos)
	elseif palma == "agarra" then
		return Manos.palma(punto, dedos + cf.UpVector * 0.3, cf.UpVector - dedos * 0.6 + cf.RightVector * SIGNO[lado] * 0.4)
	end
	return Manos.palma(punto, dedos, cf.UpVector)
end

-- En el espacio de la cámara (para lo que se lleva delante: linterna, móvil).
function Manos.delante(rel: CFrame): CFrame
	return camara.CFrame * rel
end

-- Registra algo que se puede llevar en la mano: `crear` hace el modelo (piezas sueltas; se quedan donde las deje) y
-- `enMano` es dónde va respecto a la palma.
function Manos.cosa(nombre: string, crear: () -> Model, enMano: CFrame)
	cosas[nombre] = { crear = crear, enMano = enMano, modelo = nil, partes = {}, rel = {} }
end

-- Dónde está ahora esa cosa respecto a la cámara (nil si no está en la mano). Para la luz de la linterna.
function Manos.dondeCosa(nombre: string): CFrame?
	for _, lado in LADOS do
		local b = brazos[lado]
		if b and visible and b.cosa == nombre then
			return b.rel * cosas[nombre].enMano
		end
	end
	return nil
end

-- Dónde está ahora la palma de esa mano en el mundo (nil si no se ve). Para lo que va hacia la mano.
function Manos.mano(lado: string): CFrame?
	local b = brazos[lado]
	if not b or not visible or (b.rel.Position - REPOSO[lado].Position).Magnitude < 0.35 then
		return nil
	end
	return camara.CFrame * b.rel
end

-- Una capa de sostener: fn(dt) devuelve la pose mientras dure, o nil. Prioridades: 10 linterna, 20 móvil,
-- 25 pistola, 30 cargar, 40 herramientas; los gestos van por encima (50).
function Manos.capa(nombre: string, prioridad: number, fn: (dt: number) -> Pose?)
	capas[nombre] = { prioridad = prioridad, fn = fn, gesto = false }
end

function Manos.quitar(nombre: string)
	capas[nombre] = nil
end

-- Un gesto de `duracion` s: fn(t de 0 a 1, s desde que empezó) devuelve la pose. Otro con el mismo nombre lo pisa.
function Manos.gesto(nombre: string, duracion: number, fn: (t: number, s: number) -> Pose?, prioridad: number?)
	local inicio = os.clock()
	local clave = "gesto:" .. nombre
	local capa: Capa
	capa = {
		prioridad = prioridad or 50,
		gesto = true,
		fn = function()
			local s = os.clock() - inicio
			if s >= duracion then
				if capas[clave] == capa then
					capas[clave] = nil
				end
				return nil
			end
			return fn(s / duracion, s)
		end,
	}
	capas[clave] = capa
end

-- ¿Hay ahora algún gesto en marcha? (para no empezar otro encima).
function Manos.ocupada(): boolean
	for _, c in capas do
		if c.gesto then
			return true
		end
	end
	return false
end

-- ===== Cada fotograma =====

local function escondidas(): boolean
	local personaje = jugador.Character
	local cabeza = personaje and personaje:FindFirstChild("Head") :: BasePart?
	if not cabeza or jugador:GetAttribute("Muerto") or jugador:GetAttribute("Escondido")
		or jugador:GetAttribute("MochilaAbierta") then
		return true
	end
	if camara.CameraType ~= Enum.CameraType.Custom then
		return true
	end
	return (camara.CFrame.Position - cabeza.Position).Magnitude > 2.5 -- en tercera persona (no debería pasar)
end

local function apuntar(p: BasePart, cf: CFrame)
	table.insert(piezas, p)
	table.insert(sitios, cf)
end

-- Pone un trozo del brazo con su junta de arriba en `desde` y la de abajo hacia `hasta`; `frente` dice hacia dónde
-- mira su cara delantera (que el brazo no se retuerza).
local function trozoEntre(t: Trozo, desde: Vector3, hasta: Vector3, frente: Vector3)
	local eje = t.arriba - t.abajo
	local y = desde - hasta
	y = if y.Magnitude > 1e-3 then y.Unit else Vector3.yAxis
	local z = frente - y * frente:Dot(y)
	z = if z.Magnitude > 1e-3 then z.Unit else (if math.abs(y.Z) < 0.9 then Vector3.zAxis else Vector3.xAxis)
	local x = y:Cross(z)
	-- La pieza tiene su eje de junta a junta a lo largo de su Y (como las del avatar).
	local giro = CFrame.fromMatrix(Vector3.zero, x, y, z)
	if eje.Magnitude > 1e-3 and math.abs(eje.Unit.Y) < 0.99 then
		giro *= CFrame.fromRotationBetweenVectors(eje.Unit, Vector3.yAxis)
	end
	apuntar(t.parte, giro + (desde - giro:VectorToWorldSpace(t.arriba)))
end

-- Coloca un brazo con su palma en `mano` (mundo).
local function colocar(lado: string, b: Brazo, mano: CFrame)
	local s = SIGNO[lado]
	local cf = camara.CFrame
	local hombro = cf * HOMBRO[lado]
	-- La muñeca, detrás de la palma (en su +Z).
	local largoMano = (b.mano.arriba - b.mano.abajo).Magnitude / 2
	local objetivo = (mano * CFrame.new(0, 0, largoMano)).Position
	local d = objetivo - hombro
	local l1, l2 = b.l1, b.l2
	local dist = math.clamp(d.Magnitude, 0.3, l1 + l2 - 0.01)
	local dir = if d.Magnitude > 1e-3 then d.Unit else cf.LookVector
	-- El codo hacia fuera y hacia abajo.
	local polo = cf.RightVector * s * 0.7 - cf.UpVector
	polo = polo - dir * polo:Dot(dir)
	polo = if polo.Magnitude > 1e-3 then polo.Unit else -cf.UpVector
	local cosA = math.clamp((l1 * l1 + dist * dist - l2 * l2) / (2 * l1 * dist), -1, 1)
	local codo = hombro + dir * (l1 * cosA) + polo * (l1 * math.sqrt(1 - cosA * cosA))
	-- Si no llega, la muñeca se queda en la punta del brazo estirado (no se despega).
	local haciaMuneca = objetivo - codo
	local muneca = codo + (if haciaMuneca.Magnitude > 1e-3 then haciaMuneca.Unit else dir) * l2
	-- La cara de delante del brazo (su -Z, como en el avatar) mira al lado contrario del codo: su +Z, hacia el codo.
	trozoEntre(b.brazo, hombro, codo, polo)
	trozoEntre(b.antebrazo, codo, muneca, polo)
	-- La mano: sus dedos (su -Y) hacia los de la palma, y su palma hacia la de la pose (-X la derecha, +X la izquierda,
	-- como en el avatar con los brazos caídos).
	local x = mano.UpVector * s -- el dorso
	local y = -mano.LookVector -- de los dedos a la muñeca: el +Z de la palma
	local giro = CFrame.fromMatrix(Vector3.zero, x, y, x:Cross(y))
	apuntar(b.mano.parte, giro + (muneca - giro:VectorToWorldSpace(b.mano.arriba)))
end

-- La cosa que lleva esa mano (o ninguna): se crea la primera vez y se esconde al soltarla.
local function llevar(b: Brazo, nombre: string?, mano: CFrame?)
	if b.cosa ~= nombre then
		local vieja = b.cosa and cosas[b.cosa]
		if vieja and vieja.modelo then
			vieja.modelo.Parent = nil
		end
		b.cosa = nombre
	end
	local c = nombre and cosas[nombre]
	if not c or not mano then
		return
	end
	if not c.modelo then
		local m = c.crear()
		c.modelo = m
		local base = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
		local origen = if base then base.CFrame else CFrame.new()
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
				table.insert(c.partes, p)
				table.insert(c.rel, origen:ToObjectSpace(p.CFrame))
			end
		end
	end
	local m = c.modelo :: Model
	m.Parent = modelo
	local donde = mano * c.enMano
	for i, p in c.partes do
		apuntar(p, donde * c.rel[i])
	end
end

local balanceo = 0
local avisadas: { [string]: boolean } = {}
local camaraAntes: CFrame? = nil
local inercia = Vector3.zero -- las manos se quedan un poco atrás al girar la cámara
local function paso(dt: number)
	-- La capa de más prioridad que pida cada mano.
	local poses: { { prioridad: number, pose: Pose } } = {}
	for nombre, c in capas do
		local ok, pose = pcall(c.fn, dt)
		if ok and pose then
			table.insert(poses, { prioridad = c.prioridad, pose = pose })
		elseif not ok and not avisadas[nombre] then
			avisadas[nombre] = true -- una vez por capa: no llenar la consola cada fotograma
			warn("[Manos] " .. nombre .. ": " .. tostring(pose))
		end
	end
	table.sort(poses, function(a, b)
		return a.prioridad > b.prioridad
	end)
	local fuera = escondidas()
	local cf = camara.CFrame
	local hum = jugador.Character and jugador.Character:FindFirstChildOfClass("Humanoid")
	local andando = hum ~= nil and hum.MoveDirection.Magnitude > 0.1 and hum.WalkSpeed > 0
	if andando then
		balanceo += dt * (4 + (hum :: Humanoid).WalkSpeed * 0.35)
	end
	-- Inercia: lo que ha girado la cámara desde el fotograma anterior (dónde queda ahora la mirada de antes).
	local giro = Vector3.zero
	if camaraAntes and dt > 0 then
		local antes = cf:VectorToObjectSpace((camaraAntes :: CFrame).LookVector)
		giro = Vector3.new(antes.X, antes.Y, 0) / dt
	end
	camaraAntes = cf
	local quiere = Vector3.new(math.clamp(giro.X * 0.035, -0.18, 0.18), math.clamp(giro.Y * 0.035, -0.14, 0.14), 0)
	inercia = inercia:Lerp(quiere, 1 - math.exp(-dt * 10))
	local meneo = (if andando then CFrame.new(math.sin(balanceo) * 0.025, -math.abs(math.cos(balanceo)) * 0.03, 0)
		else CFrame.new(0, math.sin(os.clock() * 1.3) * 0.006, 0)) -- respirar
		* CFrame.new(inercia)

	table.clear(piezas)
	table.clear(sitios)
	local alguna = false
	for _, lado in LADOS do
		local b = brazos[lado]
		local objetivo: CFrame? = nil
		local cosa, velocidad = nil, VELOCIDAD
		for _, p in poses do
			local mano = p.pose[lado] :: CFrame?
			if mano and (not fuera or p.pose.siempre) then
				objetivo = mano
				cosa = if lado == "der" then p.pose.cosaDer else p.pose.cosaIzq
				velocidad = p.pose.velocidad or VELOCIDAD
				break
			end
		end
		local destino = if objetivo then cf:ToObjectSpace(objetivo) * (if velocidad < math.huge then meneo else CFrame.new())
			else REPOSO[lado]
		if fuera and not objetivo then
			b.rel = REPOSO[lado] -- escondidas de golpe: al volver suben desde abajo
		elseif velocidad == math.huge then
			b.rel = destino
		else
			b.rel = b.rel:Lerp(destino, 1 - math.exp(-dt * velocidad))
		end
		-- Las dos manos se colocan siempre (la que no se usa, abajo, fuera de la vista: si no, se quedaba donde
		-- estuvo, flotando en el mundo); el modelo solo se cuelga si alguna se ve.
		local mano = cf * b.rel
		colocar(lado, b, mano)
		if objetivo or (b.rel.Position - REPOSO[lado].Position).Magnitude > 0.35 then
			alguna = true
			llevar(b, cosa, mano)
		else
			llevar(b, nil, nil)
		end
	end
	visible = alguna
	if alguna then
		modelo.Parent = camara
		workspace:BulkMoveTo(piezas, sitios, Enum.BulkMoveMode.FireCFrameChanged)
	elseif modelo.Parent then
		modelo.Parent = nil
	end
end

function Manos.start()
	modelo = Instance.new("Model")
	modelo.Name = "Manos"
	rehacer(nil)
	-- Con los brazos del avatar cuando ya ha cargado su ropa.
	local function conPersonaje(personaje: Model)
		if not jugador:HasAppearanceLoaded() then
			jugador.CharacterAppearanceLoaded:Wait()
		end
		if jugador.Character == personaje then
			rehacer(personaje)
		end
	end
	jugador.CharacterAdded:Connect(conPersonaje)
	if jugador.Character then
		task.spawn(conPersonaje, jugador.Character)
	end
	-- Después de la cámara y de lo que se coloca delante de ella (la pistola de bengalas, Camera + 2).
	RunService:BindToRenderStep("Manos", Enum.RenderPriority.Camera.Value + 5, paso)
end

return Manos
