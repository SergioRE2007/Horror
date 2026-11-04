-- Lo que comparten el coche que se va (SalidaVista) y el que llega (LlegadaVista): una copia del coche aparcado que se
-- mueve en este cliente mientras el de verdad se esconde. Librería sin start().
--   C.apuntar(modelo): al ver un coche por primera vez, apunta dónde están quietos sus limpias y el color de sus faros
--     y pilotos apagados (con gente dentro, GasolineraVista los mueve y los aclara; la copia los quiere en reposo).
--   C.tapar(modelo, quien) / C.destapar(modelo, quien, apagado?): esconde en este cliente el coche de verdad (piezas, luces,
--     prompt, sonidos y choque; atributo local SaliendoLocal = true, que GasolineraVista y Clima respetan) mientras haya
--     alguien que lo pida; al soltarlo el último, todo vuelve como estaba. Así la salida y la llegada se pasan el coche
--     escondido sin que se vea ni un fotograma en medio.
--   C.plaza(modelo) -> Plaza: cómo sale de su plaza sin darle a los de delante y detrás (marcha atrás, radio del giro)
--     y el camino del eje de atrás hasta el carril. C.enPlaza(plaza, d) da el marco de la carrocería a `d` studs de ese
--     camino (d < 0: hacia atrás, recto) y C.curva(plaza, d) la curva (para el volante). El que llega lo recorre al revés.
--   C.copiar(modelo) -> Model: la copia (limpias en su sitio, faros y pilotos apagados, nada choca ni toca).
--   C.repartir(s, copia) y C.mover(s, ...): reparte las piezas de la copia (ruedas, limpias y lo demás) y las mueve en
--     cada fotograma (volante, ruedas que ruedan, limpias, temblor y balanceo), con un solo BulkMoveTo.
--   C.encender(luz, si, color), C.hacerHumo(escape, atras), C.carpeta() (workspace.CochesSaliendo, donde van las copias).
-- Plano del lobby: la carretera va a lo largo de Z en x = 0 y el bosque queda hacia -Z.
local CollectionService = game:GetService("CollectionService")

local C = {}

C.CARRIL = 3.5 -- x del carril derecho yendo hacia -Z
C.FIN = -390 -- z donde se acaba el camino (la carretera sigue hasta -400 y hace rato que no se ve)
local CARRIL, FIN = C.CARRIL, C.FIN
-- Números a ojo (solo cambian cómo se ve).
-- El coche gira como uno de verdad: el centro del eje de atrás va por el camino y el coche mira hacia donde va.
local GIRO_MAX = 9 -- radio del giro al salir de la plaza (en el eje de atrás) si hay sitio: volante a tope…
local GIRO_MIN = 3.5 -- …y lo más cerrado que gira si los coches están muy juntos (para no darle al de delante)
local GIRO_CARRIL = 22 -- radio del giro que lo endereza en el carril
local ANGULO = math.rad(40) -- lo más que se tuerce al salir
local HOLGURA = 0.5 -- studs que deja con los coches de delante y de detrás (si no cabe, marcha atrás; como mucho 3)
-- Faros y pilotos encendidos: SmoothPlastic de color claro con su luz floja (nada de Neon).
C.FARO_LUZ = Color3.fromRGB(255, 242, 216)
C.PILOTO_LUZ = Color3.fromRGB(196, 38, 30)

type Nodo = { x: number, z: number, psi: number, w: number }
type Caja = { x1: number, x2: number, y1: number, y2: number, z1: number, z2: number }
export type Guardado = { [Instance]: { [string]: any } }
-- Piezas que no van pegadas a la carrocería: una rueda (rueda y, si es de delante, gira con el volante) o un
-- limpiaparabrisas (gira alrededor de su Eje). `giro` = cómo están ahora respecto al coche.
export type Grupo = {
	rueda: boolean,
	centro: Vector3,
	radio: number,
	delante: boolean,
	eje: Vector3,
	normal: Vector3,
	signo: number,
	giro: CFrame,
}
export type Luz = { parte: BasePart, color: Color3, cristal: boolean, luces: { Light } }
-- Lo que hace falta para mover una copia (lo llevan las salidas y las llegadas).
export type Copia = {
	p0: Vector3, -- centro de la carrocería del coche aparcado
	psi0: number, -- cuánto está girado a la izquierda (aparcado no del todo recto)
	lista: { BasePart }, -- piezas de la copia, para BulkMoveTo
	bases: { CFrame }, -- dónde está cada una respecto al coche aparcado
	grupos: { Grupo | boolean }, -- false = pegada a la carrocería
	cframes: { CFrame },
	ruedas: { Grupo },
	limpias: { Grupo },
	batalla: number, -- distancia entre ejes
	volante: number,
	faros: { Luz },
	pilotos: { Luz },
}
export type Plaza = {
	p0: Vector3,
	psi0: number,
	f0: CFrame, -- la carrocería aparcada (sin cabeceo ni balanceo)
	eje: number, -- studs del centro al eje de atrás
	suelo: number,
	techo: number,
	atras: number, -- studs de marcha atrás para salir
	giro: number, -- radio del giro al salir de la plaza
	camino: { Nodo },
	recorrido: number, -- studs del camino hasta quedar recto en el carril (el final de la curva)
}

-- Dónde están los limpias de cada coche respecto a su carrocería cuando están quietos, y el color de sus faros y pilotos
-- apagados (de C.apuntar).
local reposo: { [Instance]: { [BasePart]: CFrame } } = setmetatable({}, { __mode = "k" }) :: any
local apagados: { [Instance]: { [BasePart]: Color3 } } = setmetatable({}, { __mode = "k" }) :: any
local carpetaCopias: Folder? = nil

-- Rampa suave de 0 a 1 (y su derivada, su derivada segunda y su integral desde 0).
local function suave(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function pendiente(x: number): number
	return if x > 0 and x < 1 then 6 * x * (1 - x) else 0
end

local function curvatura(x: number): number
	return if x > 0 and x < 1 then 6 - 12 * x else 0
end

local function area(x: number): number
	if x <= 0 then
		return 0
	elseif x >= 1 then
		return x - 0.5
	end
	return x * x * x - x * x * x * x / 2
end

-- El camino del eje de atrás desde (x0, z0) mirando a -Z: giro a la izquierda de radio `giro`, recta y giro a la
-- derecha hasta el carril, y la carretera recta hasta FIN. `psi` = cuánto va girado a la izquierda; `w` = distancia
-- desde el principio.
local function hacerCamino(x0: number, z0: number, giro: number): { Nodo }
	local nodos: { Nodo } = { { x = x0, z = z0, psi = 0, w = 0 } }
	local function poner(x: number, z: number, psi: number)
		local antes = nodos[#nodos]
		local dx, dz = x - antes.x, z - antes.z
		table.insert(nodos, { x = x, z = z, psi = psi, w = antes.w + math.sqrt(dx * dx + dz * dz) })
	end
	local lado = x0 - CARRIL
	if lado > 0.5 then
		local radios = giro + GIRO_CARRIL
		local th = ANGULO
		local recta = 0
		if radios * (1 - math.cos(th)) > lado then
			th = math.acos(1 - lado / radios) -- poco sitio hasta el carril: se tuerce menos y sin recta
		else
			recta = (lado - radios * (1 - math.cos(th))) / math.sin(th)
		end
		local n = math.max(2, math.ceil(giro * th / 0.3))
		for i = 1, n do
			local p = th * i / n
			poner(x0 - giro + giro * math.cos(p), z0 - giro * math.sin(p), p)
		end
		local x, z = nodos[#nodos].x, nodos[#nodos].z
		if recta > 0 then
			x, z = x - recta * math.sin(th), z - recta * math.cos(th)
			poner(x, z, th)
		end
		local cx, cz = x + GIRO_CARRIL * math.cos(th), z - GIRO_CARRIL * math.sin(th)
		n = math.max(2, math.ceil(GIRO_CARRIL * th / 0.4))
		for i = 1, n do
			local p = th * (1 - i / n)
			poner(cx - GIRO_CARRIL * math.cos(p), cz + GIRO_CARRIL * math.sin(p), p)
		end
	end
	local ultimo = nodos[#nodos]
	poner(ultimo.x, math.min(FIN, ultimo.z - 1), 0)
	return nodos
end

-- Posición (x, z) y giro a `w` studs del principio del camino (antes del principio y tras el final, recto).
local function enCamino(nodos: { Nodo }, w: number): (number, number, number)
	local n = #nodos
	if w <= 0 then
		return nodos[1].x, nodos[1].z - w, 0
	elseif w >= nodos[n].w then
		return nodos[n].x, nodos[n].z - (w - nodos[n].w), 0
	end
	local bajo, alto = 1, n
	while alto - bajo > 1 do
		local medio = math.floor((bajo + alto) / 2)
		if nodos[medio].w <= w then
			bajo = medio
		else
			alto = medio
		end
	end
	local a, b = nodos[bajo], nodos[alto]
	local f = (w - a.w) / math.max(1e-6, b.w - a.w)
	return a.x + (b.x - a.x) * f, a.z + (b.z - a.z) * f, a.psi + (b.psi - a.psi) * f
end

-- La caja de un modelo en el mundo (alineada con los ejes).
local function caja(modelo: Model): Caja
	local cf, tam = modelo:GetBoundingBox()
	local h = tam / 2
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	local function eje(a: number, b: number, c: number): number
		return math.abs(a) * h.X + math.abs(b) * h.Y + math.abs(c) * h.Z
	end
	local ex, ey, ez = eje(r.X, u.X, l.X), eje(r.Y, u.Y, l.Y), eje(r.Z, u.Z, l.Z)
	local p = cf.Position
	return { x1 = p.X - ex, x2 = p.X + ex, y1 = p.Y - ey, y2 = p.Y + ey, z1 = p.Z - ez, z2 = p.Z + ez }
end

-- Studs del centro de la carrocería al eje de atrás (por las ruedas; `f0` = el coche aparcado).
local function ejeTrasero(modelo: Model, f0: CFrame): number
	local eje = 0
	for _, d in modelo:GetDescendants() do
		if d.Name == "Rueda" and d:IsA("BasePart") then
			eje = math.max(eje, f0:PointToObjectSpace(d.Position).Z)
		end
	end
	return if eje > 0.5 then eje else 4.2
end

-- Cómo sale de la plaza sin darle al coche de delante (el que está justo hacia -Z en la misma fila): con el giro más
-- abierto (más real) que quepa con la marcha atrás que deja el de detrás. Mientras gira, todo el coche da vueltas
-- alrededor del centro del giro (a la izquierda del eje de atrás): lo más lejano de él (la esquina delantera derecha)
-- no puede llegar a lo más cercano del otro. Devuelve la marcha atrás y el radio del giro.
local function salirDePlaza(modelo: Model, mia: Caja, p0: Vector3, eje: number): (number, number)
	local delante: Caja?, detras: Caja? = nil, nil
	for _, otro in CollectionService:GetTagged("Coche") do
		if otro ~= modelo and otro:IsA("Model") then
			local c = caja(otro)
			if c.x2 > mia.x1 and c.x1 < mia.x2 then
				if c.z2 <= mia.z1 + 0.5 then
					if not delante or c.z2 > delante.z2 then
						delante = c
					end
				elseif c.z1 >= mia.z2 - 0.5 then
					if not detras or c.z1 < detras.z1 then
						detras = c
					end
				end
			end
		end
	end
	local hueco = math.clamp(if detras then detras.z1 - mia.z2 - HOLGURA else 3, 0, 3)
	if not delante then
		return 0, GIRO_MAX
	end
	local otro = delante :: Caja
	local function falta(r: number): number
		local a = r + (mia.x2 - p0.X)
		local b = (p0.Z - mia.z1) + eje
		local lejos = math.sqrt(a * a + b * b) + HOLGURA
		local cx = p0.X - r
		local dx = math.clamp(cx, otro.x1, otro.x2) - cx
		local q = lejos * lejos - dx * dx
		return if q > 0 then math.sqrt(q) - (p0.Z + eje - otro.z2) else 0
	end
	local r = GIRO_MAX
	while r > GIRO_MIN and falta(r) > hueco do
		r -= 0.25
	end
	return math.clamp(falta(r), 0, hueco), r
end

-- Pone `valor` en la propiedad y guarda la de antes (solo la primera vez).
local function cambiar(guardado: Guardado, objeto: Instance, propiedad: string, valor: any)
	local antes = guardado[objeto]
	if not antes then
		antes = {}
		guardado[objeto] = antes
	end
	local o: any = objeto
	if antes[propiedad] == nil then
		antes[propiedad] = o[propiedad]
	end
	o[propiedad] = valor
end

local function poner(objeto: any, propiedad: string, valor: any)
	objeto[propiedad] = valor
end

-- Deja como estaba todo lo guardado.
local function devolverGuardado(guardado: Guardado)
	for objeto, antes in guardado do
		for propiedad, valor in antes do
			pcall(poner, objeto, propiedad, valor)
		end
	end
	table.clear(guardado)
end

-- Esconde en este cliente lo que se ve de `raiz` (piezas, luces, carteles, partículas, nombres y, si `sonidos`, lo que
-- suena) y quita sus prompts (sin tocar Enabled, que lo cambia el servidor).
local function esconder(raiz: Instance, guardado: Guardado, sonidos: boolean)
	for _, d in raiz:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then
			cambiar(guardado, d, "LocalTransparencyModifier", 1)
		elseif d:IsA("Light") or d:IsA("ParticleEmitter") or d:IsA("Beam") or d:IsA("Trail")
			or d:IsA("LayerCollector") or d:IsA("Highlight") then
			cambiar(guardado, d, "Enabled", false)
		elseif d:IsA("Humanoid") then
			cambiar(guardado, d, "DisplayDistanceType", Enum.HumanoidDisplayDistanceType.None)
		elseif d:IsA("ProximityPrompt") then
			cambiar(guardado, d, "MaxActivationDistance", 0)
		elseif sonidos and d:IsA("Sound") then
			cambiar(guardado, d, "Volume", 0)
		end
	end
end

local function carpeta(): Folder
	local f = carpetaCopias
	if not f or not f.Parent then
		local nueva = Instance.new("Folder")
		nueva.Name = "CochesSaliendo"
		nueva.Parent = workspace
		carpetaCopias = nueva
		return nueva
	end
	return f
end

-- Las piezas de un limpia (si es un Model, las de dentro).
local function esLimpia(d: Instance): boolean
	local padre = d.Parent
	return string.sub(d.Name, 1, 6) == "Limpia" or (padre ~= nil and string.sub(padre.Name, 1, 6) == "Limpia")
end

-- Apunta dónde están quietos los limpias de un coche (al verlo por primera vez).
local function apuntarReposo(modelo: Model)
	local carroceria = modelo.PrimaryPart
	if not carroceria then
		return
	end
	local apuntadas = {}
	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") and esLimpia(d) then
			apuntadas[d] = carroceria.CFrame:ToObjectSpace(d.CFrame)
		end
	end
	reposo[modelo] = apuntadas
end

-- Si alguna luz de la pieza está encendida.
local function encendida(parte: BasePart): boolean
	for _, l in parte:GetDescendants() do
		if l:IsA("Light") and l.Enabled then
			return true
		end
	end
	return false
end

-- Apunta el color de los faros y pilotos de un coche (al verlo por primera vez; los que ya estén encendidos, no).
local function apuntarApagados(modelo: Model)
	local colores = {}
	for _, d in modelo:GetDescendants() do
		if (d.Name == "Faro" or d.Name == "Piloto") and d:IsA("BasePart") and not encendida(d) then
			colores[d] = d.Color
		end
	end
	apagados[modelo] = colores
end

-- La copia que se mueve: sin asientos, prompts, scripts, juntas ni sonidos, sin etiquetas (que ningún otro sistema la
-- tome por un coche o una luz del mapa) y sin chocar ni tocar nada.
local function hacerCopia(modelo: Model): Model
	local copia = modelo:Clone()
	assert(copia, "el coche no se puede copiar")
	copia.Name = modelo.Name .. "Saliendo"
	for _, etiqueta in copia:GetTags() do
		copia:RemoveTag(etiqueta)
	end
	for _, d in copia:GetDescendants() do
		for _, etiqueta in d:GetTags() do
			d:RemoveTag(etiqueta)
		end
		if d:IsA("Seat") or d:IsA("VehicleSeat") or d:IsA("ProximityPrompt") or d:IsA("ClickDetector")
			or d:IsA("DragDetector") or d:IsA("LuaSourceContainer") or d:IsA("JointInstance")
			or d:IsA("WeldConstraint") or d:IsA("NoCollisionConstraint") or d:IsA("Sound") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.LocalTransparencyModifier = 0
		end
	end
	return copia
end

-- Medio alto de una pieza en el mundo (el radio, si es una rueda).
local function medioAlto(p: BasePart): number
	local cf, h = p.CFrame, p.Size / 2
	return math.abs(cf.RightVector.Y) * h.X + math.abs(cf.UpVector.Y) * h.Y + math.abs(cf.LookVector.Y) * h.Z
end

-- Reparte las piezas de la copia: ruedas (con lo que va en su mismo centro, como la llanta), limpias y lo demás
-- (pegado a la carrocería); y sus faros y pilotos. Todo respecto al coche aparcado.
local function repartir(s: Copia, copia: Model)
	local f0 = CFrame.new(s.p0) * CFrame.Angles(0, s.psi0, 0)
	local grupoDe: { [BasePart]: Grupo } = {}
	local function partes(objeto: Instance): { BasePart }
		local lista = {}
		if objeto:IsA("BasePart") then
			table.insert(lista, objeto)
		end
		for _, d in objeto:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(lista, d)
			end
		end
		return lista
	end
	local delanteZ, detrasZ = math.huge, -math.huge
	for _, d in copia:GetDescendants() do
		if d.Name == "Rueda" and (d:IsA("BasePart") or d:IsA("Model")) and not grupoDe[d :: any] then
			local lista = partes(d)
			if #lista > 0 then
				local centroMundo = if d:IsA("BasePart") then d.Position else (d :: Model):GetBoundingBox().Position
				local radio = 0
				for _, p in lista do
					radio = math.max(radio, p.Position.Y + medioAlto(p) - centroMundo.Y)
				end
				local centro = f0:PointToObjectSpace(centroMundo)
				local g: Grupo = {
					rueda = true,
					centro = centro,
					radio = math.max(0.3, radio),
					delante = centro.Z < 0,
					eje = Vector3.zero,
					normal = Vector3.xAxis,
					signo = 1,
					giro = CFrame.identity,
				}
				table.insert(s.ruedas, g)
				for _, p in lista do
					grupoDe[p] = g
				end
				delanteZ, detrasZ = math.min(delanteZ, centro.Z), math.max(detrasZ, centro.Z)
			end
		elseif string.sub(d.Name, 1, 6) == "Limpia" and (d:IsA("BasePart") or d:IsA("Model")) then
			local ejeMundo, normalMundo = d:GetAttribute("Eje"), d:GetAttribute("Normal")
			local lista = partes(d)
			if typeof(ejeMundo) == "Vector3" and typeof(normalMundo) == "Vector3" and normalMundo.Magnitude > 0.01
				and #lista > 0 then
				local n = f0:VectorToObjectSpace(normalMundo).Unit
				local eje = f0:PointToObjectSpace(ejeMundo)
				local suma = Vector3.zero
				for _, p in lista do
					suma += p.Position
				end
				-- Hacia dónde gira para subir por el parabrisas (no hacia abajo, que se metería en el capó).
				local brazo = f0:PointToObjectSpace(suma / #lista) - eje
				brazo -= n * n:Dot(brazo)
				local arriba = Vector3.yAxis - n * n.Y
				local g: Grupo = {
					rueda = false,
					centro = Vector3.zero,
					radio = 1,
					delante = false,
					eje = eje,
					normal = n,
					signo = if n:Cross(brazo):Dot(arriba) >= 0 then 1 else -1,
					giro = CFrame.identity,
				}
				table.insert(s.limpias, g)
				for _, p in lista do
					grupoDe[p] = g
				end
			end
		end
	end
	if delanteZ < detrasZ then
		s.batalla = detrasZ - delanteZ
	end
	for _, p in copia:GetDescendants() do
		if p:IsA("BasePart") then
			local base = f0:ToObjectSpace(p.CFrame)
			if not grupoDe[p] then
				for _, g in s.ruedas do
					if (base.Position - g.centro).Magnitude < 0.4 then -- la llanta (o un tapacubos): rueda con ella
						grupoDe[p] = g
						break
					end
				end
			end
			table.insert(s.lista, p)
			table.insert(s.bases, base)
			table.insert(s.grupos, grupoDe[p] or false)
			table.insert(s.cframes, p.CFrame)
			if p.Name == "Faro" or p.Name == "Piloto" then
				local luces = {}
				for _, l in p:GetDescendants() do
					if l:IsA("Light") then
						table.insert(luces, l)
					end
				end
				local luz: Luz = {
					parte = p,
					color = p.Color,
					cristal = p.Material == Enum.Material.Glass,
					luces = luces,
				}
				table.insert(if p.Name == "Faro" then s.faros else s.pilotos, luz)
			end
		end
	end
end

local function encender(luz: Luz, si: boolean, color: Color3)
	luz.parte.Color = if si then color else luz.color
	if luz.cristal then -- el cristal a oscuras no parece encendido
		luz.parte.Material = if si then Enum.Material.SmoothPlastic else Enum.Material.Glass
	end
	for _, l in luz.luces do
		l.Enabled = si
	end
end

-- El humo del escape: gris, con las luces del coche encima (de noche se ve rojo junto a los pilotos). Sale hacia
-- `atras` (la cara del Attachment que más mira hacia allí: no se sabe cómo lo han girado).
local function hacerHumo(escape: Attachment, atras: Vector3): ParticleEmitter
	local humo = Instance.new("ParticleEmitter")
	humo.Name = "Humo"
	humo.Texture = "rbxasset://textures/particles/smoke_main.dds"
	humo.Color = ColorSequence.new(Color3.fromRGB(150, 148, 144), Color3.fromRGB(96, 96, 99))
	humo.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.35, 0.72),
		NumberSequenceKeypoint.new(1, 1),
	})
	humo.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 2.4) })
	humo.Lifetime = NumberRange.new(1.2, 2)
	humo.Speed = NumberRange.new(0.8, 2)
	local mejor = -2
	for _, cara in Enum.NormalId:GetEnumItems() do
		local hacia = escape.WorldCFrame:VectorToWorldSpace(Vector3.FromNormalId(cara)):Dot(atras)
		if hacia > mejor then
			mejor = hacia
			humo.EmissionDirection = cara
		end
	end
	humo.SpreadAngle = Vector2.new(35, 35)
	humo.Acceleration = Vector3.new(0, 1.6, 0)
	humo.Drag = 1.2
	humo.Rotation = NumberRange.new(0, 360)
	humo.RotSpeed = NumberRange.new(-25, 25)
	humo.LightInfluence = 1
	humo.LightEmission = 0
	humo.Rate = 0
	humo.Parent = escape
	return humo
end
-- Coches escondidos en este cliente: quién lo pide (una salida, una llegada) y lo cambiado para esconderlo.
local tapados: { [Instance]: { quienes: { [any]: boolean }, guardado: Guardado, apagar: boolean } } = {}

function C.tapar(modelo: Model, quien: any)
	local t = tapados[modelo]
	if not t then
		local guardado: Guardado = {}
		t = { quienes = {}, guardado = guardado, apagar = false }
		tapados[modelo] = t
		modelo:SetAttribute("SaliendoLocal", true)
		esconder(modelo, guardado, true)
		for _, d in modelo:GetDescendants() do
			if d:IsA("BasePart") and d.CanCollide then
				cambiar(guardado, d, "CanCollide", false) -- que nadie se choque aquí con un coche que no se ve
			end
		end
	end
	t.quienes[quien] = true
end

-- Con `apagado` (el que llega, que lo deja vacío y apagado), vuelve con los faros, los pilotos y el humo apagados,
-- aunque al esconderlo estuvieran encendidos (con gente dentro): si no, se encenderían un fotograma hasta que
-- GasolineraVista vea que está vacío.
function C.destapar(modelo: Model, quien: any, apagado: boolean?)
	local t = tapados[modelo]
	if not t or not t.quienes[quien] then
		return
	end
	t.quienes[quien] = nil
	t.apagar = t.apagar or apagado == true
	if next(t.quienes) ~= nil then
		return
	end
	tapados[modelo] = nil
	devolverGuardado(t.guardado)
	if t.apagar then
		for parte, color in apagados[modelo] or {} do
			if parte.Parent then
				parte.Color = color
			end
		end
		for _, d in modelo:GetDescendants() do
			local padre = d.Parent
			local luz = d:IsA("Light") and padre ~= nil and (padre.Name == "Faro" or padre.Name == "Piloto")
			if luz or d:IsA("ParticleEmitter") then
				(d :: any).Enabled = false
			end
		end
	end
	modelo:SetAttribute("SaliendoLocal", nil)
end

function C.tapado(modelo: Model): boolean
	return tapados[modelo] ~= nil
end

function C.apuntar(modelo: Model)
	if not reposo[modelo] then
		apuntarReposo(modelo)
	end
	if not apagados[modelo] then
		apuntarApagados(modelo)
	end
end

-- La copia, como el coche aparcado: limpias en su sitio y faros y pilotos apagados (con gente dentro, GasolineraVista
-- los tiene encendidos y la copia parpadearía mal). Si ya está escondido, se copia como se vería sin esconder. Todo
-- de golpe, en el mismo fotograma: el de verdad no llega a verse.
function C.copiar(modelo: Model): Model
	local carroceria = modelo.PrimaryPart
	if carroceria then
		for parte, relativo in reposo[modelo] or {} do
			if parte.Parent then
				parte.CFrame = carroceria.CFrame * relativo
			end
		end
	end
	local antes: Guardado = {}
	for parte, color in apagados[modelo] or {} do
		if parte.Parent then
			cambiar(antes, parte, "Color", color)
		end
	end
	local t = tapados[modelo]
	local escondido: Guardado = {}
	if t then
		for objeto, valores in t.guardado do
			local ahora = {}
			escondido[objeto] = ahora
			for propiedad, valor in valores do
				local o: any = objeto
				ahora[propiedad] = o[propiedad]
				pcall(poner, objeto, propiedad, valor)
			end
		end
	end
	local ok, copia = pcall(hacerCopia, modelo)
	devolverGuardado(escondido)
	devolverGuardado(antes)
	if not ok then
		error(copia, 0)
	end
	return copia
end

-- Cómo sale el coche de su plaza (y por dónde entra el que llega, al revés).
function C.plaza(modelo: Model): Plaza
	local carroceria = modelo.PrimaryPart or modelo:FindFirstChild("Carroceria")
	assert(carroceria and carroceria:IsA("BasePart"), "el coche no tiene Carroceria")
	local p0 = carroceria.Position
	local mira = carroceria.CFrame.LookVector
	local psi0 = math.atan2(-mira.X, -mira.Z)
	local f0 = CFrame.new(p0) * CFrame.Angles(0, psi0, 0)
	local eje = ejeTrasero(modelo, f0)
	local mia = caja(modelo)
	local atras, giro = salirDePlaza(modelo, mia, p0, eje)
	atras = if atras > 0.05 then atras else 0
	local base = p0 + Vector3.new(math.sin(psi0), 0, math.cos(psi0)) * (eje + atras) -- el eje de atrás
	local camino = hacerCamino(base.X, base.Z, giro)
	return {
		p0 = p0,
		psi0 = psi0,
		f0 = f0,
		eje = eje,
		suelo = mia.y1,
		techo = mia.y2,
		atras = atras,
		giro = giro,
		camino = camino,
		recorrido = camino[math.max(1, #camino - 1)].w,
	}
end

-- El marco de la carrocería a `d` studs del camino: el giro, algo suavizado a lo largo del camino (sin tirones al pasar
-- de una curva a otra), y lo torcido que estaba aparcado, que se le va en los primeros studs. El camino es el del eje
-- de atrás: el centro de la carrocería va `eje` studs por delante.
function C.enPlaza(pl: Plaza, d: number): CFrame
	local x, z, psi = enCamino(pl.camino, d)
	local h = math.clamp(d, 0, 1.5)
	local _, _, antes = enCamino(pl.camino, d - h)
	local _, _, luego = enCamino(pl.camino, d + h)
	local giro = (antes + 2 * psi + luego) / 4 + pl.psi0 * (1 - suave(d / 6))
	local centro = Vector3.new(x - pl.eje * math.sin(giro), pl.p0.Y, z - pl.eje * math.cos(giro))
	return CFrame.new(centro) * CFrame.Angles(0, giro, 0)
end

-- La curva del camino a `d` studs (giro por stud, para el volante).
function C.curva(pl: Plaza, d: number): number
	local desde = math.max(0, d - 1)
	local _, _, psiA = enCamino(pl.camino, desde)
	local _, _, psiB = enCamino(pl.camino, d + 1)
	return (psiB - psiA) / (d + 1 - desde)
end

-- Mueve la copia a `marco`: el volante sigue la curva del camino sin saltos; con `adorno`, la carrocería tiembla
-- (`temblor` studs), cabecea al acelerar y frenar y se inclina hacia fuera en las curvas, las ruedas ruedan (`rodado`
-- studs, con signo) y los limpias barren (`barre` radianes). Sin adorno, todo quieto respecto al coche.
function C.mover(s: Copia, marco: CFrame, rodado: number, v: number, a: number, curva: number, dt: number,
	adorno: boolean, temblor: number, barre: number)
	local objetivo = math.clamp(math.atan(s.batalla * curva), -0.7, 0.7)
	s.volante += (objetivo - s.volante) * (1 - math.exp(-dt * 7))
	local cuerpo = marco
	if adorno then
		local cabeceo = math.clamp(a * 0.0025, -0.035, 0.035)
		local balanceo = math.clamp(-v * v * math.tan(s.volante) / s.batalla * 0.0016, -0.035, 0.035)
		cuerpo = marco * CFrame.new(0, temblor, 0) * CFrame.Angles(cabeceo, 0, balanceo)
	end
	for _, g in s.ruedas do
		g.giro = if adorno
			then CFrame.new(g.centro) * CFrame.Angles(0, if g.delante then s.volante else 0, 0)
				* CFrame.Angles(-rodado / g.radio, 0, 0) * CFrame.new(-g.centro)
			else CFrame.identity
	end
	local giroLimpias = if adorno then barre else 0
	for _, g in s.limpias do
		g.giro = CFrame.new(g.eje) * CFrame.fromAxisAngle(g.normal, g.signo * giroLimpias) * CFrame.new(-g.eje)
	end
	for i, base in s.bases do
		local g = s.grupos[i]
		if typeof(g) ~= "table" then
			s.cframes[i] = cuerpo * base
		elseif g.rueda then
			s.cframes[i] = marco * g.giro * base
		else
			s.cframes[i] = cuerpo * g.giro * base
		end
	end
	workspace:BulkMoveTo(s.lista, s.cframes, Enum.BulkMoveMode.FireCFrameChanged)
end

C.suave = suave
C.pendiente = pendiente
C.curvatura = curvatura
C.area = area
C.caja = caja
C.cambiar = cambiar
C.devolverGuardado = devolverGuardado
C.esconder = esconder
C.carpeta = carpeta
C.repartir = repartir
C.encender = encender
C.hacerHumo = hacerHumo

return C
