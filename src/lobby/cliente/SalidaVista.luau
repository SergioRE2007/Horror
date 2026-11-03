-- El coche que se va del lobby. Coches (servidor) pone en el coche el atributo Salida = hora del servidor a la que
-- sale (Config.Coches.Salida s después de que el dueño arranque; nil = parado). Desde ese momento, en cada cliente:
--   · El coche de verdad y los que van sentados se esconden (LocalTransparencyModifier, sus luces y el prompt fuera) y
--     el coche lleva el atributo local SaliendoLocal = true (GasolineraVista no lo toca mientras).
--   · Una copia sin asientos, prompts ni scripts (nada choca ni toca) arranca: tiembla, los faros parpadean al
--     encenderse, pilotos, limpias, humo del escape, ruedas que ruedan (las de delante giran con el volante) y se
--     inclina un poco al acelerar y en las curvas. Para no darle al de delante, si hace falta da un poco de marcha atrás
--     y gira más cerrado; sale con una curva hasta el carril derecho (x = CARRIL) y acelera hacia -Z hasta perderse en
--     la niebla.
--   · Si vas dentro (atributo Coche del jugador), la cinemática: sin interfaz, CoreGui ni los demás personajes, cámara
--     Scriptable en dos planos (bajo delante, en la carretera, mirándolo arrancar; luego detrás y arriba, siguiéndolo y
--     quedándose atrás) y un fundido a negro propio que acaba un poco antes de la hora. Luego, negro hasta que el
--     servidor te lleva.
-- Todo según la hora del servidor (si llegas a media salida, la copia va por donde toca) y el movimiento en el Bucle
-- (una tarea por coche que sale). Lo devuelve todo siempre: si Salida vuelve a nil o cambia, a los ESPERA s de la hora
-- sin habernos ido o si algo falla. Si te bajas a media cuenta atrás, se acaba tu cinemática y lo ves irse como los demás.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Bucle = require(script.Parent.Bucle)
local Sonido = require(script.Parent.Sonido)

local SalidaVista = {}

local jugador = Players.LocalPlayer

-- Plano del lobby: la carretera va a lo largo de Z en x = 0 y el bosque (por donde se va) queda hacia -Z.
local CARRIL = 3.5 -- x del carril derecho yendo hacia -Z
local FIN = -390 -- z donde se borra la copia (la carretera sigue hasta -400 y hace rato que no se ve)
-- Números a ojo (solo cambian cómo se ve).
-- El coche gira como uno de verdad: el centro del eje de atrás va por el camino y el coche mira hacia donde va.
local GIRO_MAX = 9 -- radio del giro al salir de la plaza (en el eje de atrás) si hay sitio: volante a tope…
local GIRO_MIN = 3.5 -- …y lo más cerrado que gira si los coches están muy juntos (para no darle al de delante)
local GIRO_CARRIL = 22 -- radio del giro que lo endereza en el carril
local ANGULO = math.rad(40) -- lo más que se tuerce al salir
local HOLGURA = 0.5 -- studs que deja con los coches de delante y de detrás (si no cabe, marcha atrás; como mucho 3)
local VELOCIDAD = 40 -- studs/s en la carretera
local ESPERA = 12 -- segundos tras la hora sin habernos ido: se devuelve todo
local TARDE = 1.5 -- una salida cuya hora pasó hace más (entrar tarde al servidor) ya no se enseña
-- Tiempos desde que el dueño arranca, en segundos.
local CONTACTO = 0.1 -- el motor arranca: tiembla y echa una bocanada de humo
local FAROS = { 0.2, 0.26, 0.33, 0.37, 0.44 } -- se encienden, se apagan… y desde el último, encendidos
local ATRAS, PARADA = 0.45, 0.1 -- cuándo empieza la marcha atrás (si hace falta) y quieto antes de meter primera
local ATRAS_DURA = { 0.45, 0.2 } -- segundos que dura la marcha atrás: lo primero más lo segundo por cada stud
local SIN_ATRAS = 0.65 -- sin marcha atrás, cuándo empieza a andar
local SALE, TA = 8, 0.45 -- sale de la plaza despacio (hasta SALE studs/s en TA s; menos si gira muy cerrado)…
local TB0, TB1 = 0.55, 3.2 -- …y acelera hasta VELOCIDAD entre estos segundos desde que anda
local LIMPIAS, AMPLITUD, PERIODO = 0.5, math.rad(80), 1.3 -- limpiaparabrisas: desde cuándo, cuánto giran, cada cuánto
-- Cinemática.
local PLANO1 = 1.8 -- segundos del plano bajo delante del coche
local CAMPO1, CAMPO2 = 50, 58 -- FieldOfView de cada plano
local NEGRO, NEGRO_TODO = 1, 0.2 -- el fundido empieza NEGRO s antes de la hora y está negro del todo NEGRO_TODO s antes
-- Faros y pilotos encendidos: SmoothPlastic de color claro con su luz floja (nada de Neon).
local FARO_LUZ = Color3.fromRGB(255, 242, 216)
local PILOTO_LUZ = Color3.fromRGB(196, 38, 30)

type Nodo = { x: number, z: number, psi: number, w: number }
type Caja = { x1: number, x2: number, y1: number, y2: number, z1: number, z2: number }
type Guardado = { [Instance]: { [string]: any } }
-- Piezas que no van pegadas a la carrocería: una rueda (rueda y, si es de delante, gira con el volante) o un
-- limpiaparabrisas (gira alrededor de su Eje). `giro` = cómo están ahora respecto al coche.
type Grupo = {
	rueda: boolean,
	centro: Vector3,
	radio: number,
	delante: boolean,
	eje: Vector3,
	normal: Vector3,
	signo: number,
	giro: CFrame,
}
type Luz = { parte: BasePart, color: Color3, cristal: boolean, luces: { Light } }
type Salida = {
	modelo: Model,
	hora: number, -- la hora del servidor a la que sale (atributo Salida)
	inicio: number, -- cuando arrancó el dueño
	tarea: string, -- nombre en el Bucle
	p0: Vector3, -- centro de la carrocería del coche aparcado
	psi0: number, -- cuánto está girado a la izquierda (aparcado no del todo recto)
	eje: number, -- studs del centro al eje de atrás
	suelo: number,
	techo: number,
	atras: number, -- studs de marcha atrás
	atrasDura: number, -- segundos que dura
	giro: number, -- radio del giro al salir de la plaza
	v1: number, -- velocidad al salir de la plaza
	curva0: number, -- curva del camino al empezar (el volante, girado antes de meter primera)
	camino: { Nodo },
	copia: Model?,
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
	estadoFaros: boolean?,
	estadoPilotos: boolean?,
	humo: ParticleEmitter?,
	bocanada: boolean,
	ruidoPunto: Attachment?,
	asientos: { BasePart },
	esAsiento: { [Instance]: boolean },
	escondidos: { [Model]: Guardado }, -- los personajes sentados, escondidos
	repaso: number,
	otros: { [Model]: Guardado }?, -- en tu cinemática, los demás personajes (estorban en los planos)
	repasoOtros: number,
	guardado: Guardado, -- lo cambiado del coche de verdad
	devolver: { () -> () },
	cine: { () -> () }?, -- lo que deshacer de la cinemática (solo si vas dentro)
	gruaA: Vector3,
	gruaB: Vector3,
	gruaC: Vector3,
	grua: number,
	acabada: boolean,
}

local salidas: { [Model]: Salida } = {}
local vigilados: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
-- Dónde están los limpias de cada coche respecto a su carrocería cuando están quietos (GasolineraVista los mueve con
-- gente dentro; la copia los quiere en su sitio).
local reposo: { [Instance]: { [BasePart]: CFrame } } = setmetatable({}, { __mode = "k" }) :: any
-- Y el color de sus faros y pilotos apagados (GasolineraVista los aclara con gente dentro; la copia parpadea desde
-- apagados).
local apagados: { [Instance]: { [BasePart]: Color3 } } = setmetatable({}, { __mode = "k" }) :: any
local capaNegro: ScreenGui
local negro: Frame
local tweenNegro: Tween? = nil
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

-- Más suave aún (para la grúa de la cámara: sin tirón al empezar ni al parar).
local function suaveMas(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * x * (x * (6 * x - 15) + 10)
end

-- Lo que ha avanzado hacia delante (studs), su velocidad y su aceleración a los `tau` s de empezar a andar, si sale
-- de la plaza a `v1` studs/s.
local function adelante(tau: number, v1: number): (number, number, number)
	local x1, x2 = tau / TA, (tau - TB0) / (TB1 - TB0)
	local extra = VELOCIDAD - v1
	return v1 * TA * area(x1) + extra * (TB1 - TB0) * area(x2),
		v1 * suave(x1) + extra * suave(x2),
		v1 / TA * pendiente(x1) + extra / (TB1 - TB0) * pendiente(x2)
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

-- Dónde va la copia a los `t` s: su marco (en el centro de la carrocería, mirando hacia delante), lo que han rodado las
-- ruedas (con signo), su velocidad, su aceleración y la curva del camino (para el volante).
local function pose(s: Salida, t: number): (CFrame, number, number, number, number)
	local y = s.p0.Y
	if s.atras > 0 and t < ATRAS + s.atrasDura + PARADA then
		local x = (t - ATRAS) / s.atrasDura
		local r = s.atras * suave(x)
		local v = -s.atras / s.atrasDura * pendiente(x)
		local a = -s.atras / (s.atrasDura * s.atrasDura) * curvatura(x)
		-- Recto hacia atrás. Quieto tras la marcha atrás, ya con el volante girado para salir.
		local haciaAtras = Vector3.new(math.sin(s.psi0), 0, math.cos(s.psi0))
		return CFrame.new(s.p0 + haciaAtras * r) * CFrame.Angles(0, s.psi0, 0), -r, v, a, if x >= 1 then s.curva0 else 0
	end
	local d, v, a = adelante(t - (if s.atras > 0 then ATRAS + s.atrasDura + PARADA else SIN_ATRAS), s.v1)
	local x, z, psi = enCamino(s.camino, d)
	-- El giro, algo suavizado a lo largo del camino (sin tirones al pasar de una curva a otra), y lo torcido que estaba
	-- aparcado, que se le va en los primeros studs.
	local h = math.clamp(d, 0, 1.5)
	local _, _, antes = enCamino(s.camino, d - h)
	local _, _, luego = enCamino(s.camino, d + h)
	local giro = (antes + 2 * psi + luego) / 4 + s.psi0 * (1 - suave(d / 6))
	local desde = math.max(0, d - 1)
	local _, _, psiA = enCamino(s.camino, desde)
	local _, _, psiB = enCamino(s.camino, d + 1)
	-- El camino es el del eje de atrás: el centro de la carrocería va `eje` studs por delante.
	local centro = Vector3.new(x - s.eje * math.sin(giro), y, z - s.eje * math.cos(giro))
	return CFrame.new(centro) * CFrame.Angles(0, giro, 0), d - s.atras, v, a, (psiB - psiA) / (d + 1 - desde)
end

-- Faros: parpadean al encenderse (cada hora de FAROS los cambia).
local function farosEncendidos(t: number): boolean
	local encendidos = false
	for _, cuando in FAROS do
		if t >= cuando then
			encendidos = not encendidos
		end
	end
	return encendidos
end

-- Ángulo de los limpias: de quietos hasta arriba y vuelta.
local function barrido(t: number): number
	if t < LIMPIAS then
		return 0
	end
	return AMPLITUD * (0.5 - 0.5 * math.cos((t - LIMPIAS) / PERIODO * 2 * math.pi))
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
local function repartir(s: Salida, copia: Model)
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

-- Esconde a los que van sentados en el coche de verdad y devuelve a los que se bajan.
local function vigilarSentados(s: Salida, reloj: number)
	local sentados: { [Model]: boolean } = {}
	for _, asiento in s.asientos do
		local humanoide = (asiento :: any).Occupant :: Humanoid?
		local personaje = humanoide and humanoide.Parent
		if personaje and personaje:IsA("Model") then
			sentados[personaje] = true
		end
	end
	for _, otro in Players:GetPlayers() do
		local personaje = otro.Character
		local humanoide = personaje and personaje:FindFirstChildOfClass("Humanoid")
		if personaje and humanoide and humanoide.SeatPart and s.esAsiento[humanoide.SeatPart] then
			sentados[personaje] = true
		end
	end
	for personaje, guardado in s.escondidos do
		if not sentados[personaje] then
			devolverGuardado(guardado)
			s.escondidos[personaje] = nil
		end
	end
	local repasar = reloj >= s.repaso -- de vez en cuando, por si le ha salido algo luego (accesorios)
	if repasar then
		s.repaso = reloj + 0.5
	end
	for personaje in sentados do
		local guardado = s.escondidos[personaje]
		local otros = s.otros
		if not guardado and otros and otros[personaje] then -- ya escondido por la cinemática: pasa a los sentados
			devolverGuardado(otros[personaje])
			otros[personaje] = nil
		end
		if not guardado then
			local nuevo = {}
			s.escondidos[personaje] = nuevo
			esconder(personaje, nuevo, false)
		elseif repasar then
			esconder(personaje, guardado, false)
		end
	end
end

-- En tu cinemática, los demás personajes fuera de los planos (los sentados ya los esconde vigilarSentados).
local function vigilarOtros(s: Salida, reloj: number)
	local otros = s.otros
	if not otros or reloj < s.repasoOtros then
		return
	end
	s.repasoOtros = reloj + 0.5
	for _, otro in Players:GetPlayers() do
		local personaje = otro.Character
		if personaje and not s.escondidos[personaje] then
			local guardado = otros[personaje]
			if not guardado then
				guardado = {}
				otros[personaje] = guardado
			end
			esconder(personaje, guardado, false)
		end
	end
end

-- El fundido propio vuelve a transparente (y se esconde al acabar, si nadie lo ha vuelto a usar).
local function quitarNegro()
	if tweenNegro then
		tweenNegro:Cancel()
	end
	local tween = TweenService:Create(negro, TweenInfo.new(0.6), { BackgroundTransparency = 1 })
	tweenNegro = tween
	tween.Completed:Once(function()
		if tweenNegro == tween then
			tweenNegro = nil
			negro.Visible = false
		end
	end)
	tween:Play()
end

local function acabarCine(s: Salida)
	local devolver = s.cine
	if not devolver then
		return
	end
	s.cine = nil
	for i = #devolver, 1, -1 do
		local ok, fallo = pcall(devolver[i])
		if not ok then
			warn(`[SalidaVista] {fallo}`)
		end
	end
end

local function terminar(s: Salida)
	if s.acabada then
		return
	end
	s.acabada = true
	if salidas[s.modelo] == s then
		salidas[s.modelo] = nil
	end
	Bucle.quitar(s.tarea)
	acabarCine(s)
	for _, guardado in s.escondidos do
		devolverGuardado(guardado)
	end
	table.clear(s.escondidos)
	for i = #s.devolver, 1, -1 do
		local ok, fallo = pcall(s.devolver[i])
		if not ok then
			warn(`[SalidaVista] {fallo}`)
		end
	end
	table.clear(s.devolver)
end

-- Vas dentro: fuera la interfaz (también la que salga mientras, menos el fundido propio), la CoreGui y el ratón; cámara
-- Scriptable. Todo vuelve como estaba en acabarCine.
local function empezarCine(s: Salida)
	local devolver: { () -> () } = {}
	s.cine = devolver
	local function alAcabar(fn: () -> ())
		table.insert(devolver, fn)
	end

	local apagadas: { LayerCollector } = {}
	alAcabar(function()
		for _, capa in apagadas do
			if capa.Parent then
				capa.Enabled = true
			end
		end
	end)
	local function apagar(capa: Instance)
		if capa:IsA("LayerCollector") and capa ~= capaNegro and capa.Enabled then
			capa.Enabled = false
			table.insert(apagadas, capa)
		end
	end
	local gui = jugador:FindFirstChildOfClass("PlayerGui")
	if gui then
		for _, capa in gui:GetChildren() do
			apagar(capa)
		end
		local conexion = gui.ChildAdded:Connect(apagar)
		alAcabar(function()
			conexion:Disconnect()
		end)
	end

	local core: { [Enum.CoreGuiType]: boolean } = {}
	for _, tipo in Enum.CoreGuiType:GetEnumItems() do
		if tipo ~= Enum.CoreGuiType.All then
			local ok, encendido = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, tipo)
			if ok then
				core[tipo] = encendido
			end
		end
	end
	alAcabar(function()
		for tipo, encendido in core do
			pcall(StarterGui.SetCoreGuiEnabled, StarterGui, tipo, encendido)
		end
	end)
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)

	local raton = UserInputService.MouseIconEnabled
	alAcabar(function()
		UserInputService.MouseIconEnabled = raton
	end)
	UserInputService.MouseIconEnabled = false

	local otros: { [Model]: Guardado } = {}
	s.otros = otros
	s.repasoOtros = 0
	alAcabar(function()
		s.otros = nil
		for _, guardado in otros do
			devolverGuardado(guardado)
		end
	end)

	local camara = workspace.CurrentCamera
	local campo = camara.FieldOfView
	alAcabar(function()
		local actual = workspace.CurrentCamera
		actual.CameraType = Enum.CameraType.Custom
		actual.FieldOfView = campo
	end)
	camara.CameraType = Enum.CameraType.Scriptable

	if tweenNegro then
		tweenNegro:Cancel()
		tweenNegro = nil
	end
	negro.BackgroundTransparency = 1
	negro.Visible = true
	alAcabar(quitarNegro)
end

-- Los planos: (1) bajo, delante y a un lado, en la carretera, mirándolo arrancar; (2) grúa que empieza detrás y arriba
-- del coche, lo sigue hasta encima del carril y se queda atrás mientras se va. Y el fundido a negro antes de la hora.
local function moverCamara(s: Salida, t: number, ahora: number, marco: CFrame, camara: Camera)
	if t < PLANO1 then
		local u = math.clamp(t / PLANO1, 0, 1)
		local ojo = Vector3.new(CARRIL - 2.5 + 0.6 * u, s.suelo + 1.2 + 0.25 * u, s.p0.Z - 16.5 + 1.3 * u)
		camara.FieldOfView = CAMPO1
		camara.CFrame = CFrame.lookAt(ojo, marco.Position + marco.LookVector * 2 + Vector3.new(0, 0.4, 0))
	else
		local u = suaveMas((t - PLANO1) / s.grua)
		local ojo = s.gruaA:Lerp(s.gruaB, u):Lerp(s.gruaB:Lerp(s.gruaC, u), u)
			+ Vector3.new(0, 0, -1.2 * math.max(0, t - PLANO1 - s.grua)) -- al acabar, sigue un poco, muy despacio
		camara.FieldOfView = CAMPO2
		camara.CFrame = CFrame.lookAt(ojo, marco.Position + Vector3.new(0, 0.8, 0))
	end
	negro.BackgroundTransparency = 1 - suave((ahora - (s.hora - NEGRO)) / (NEGRO - NEGRO_TODO))
end

local function moverCopia(s: Salida, t: number, dt: number, camara: Camera, marco: CFrame, rodado: number, v: number,
	a: number, curva: number)
	local copia = s.copia
	if not copia then
		return
	end
	if marco.Position.Z <= FIN then -- al final de la carretera, entre la niebla: ya no se ve
		copia:Destroy()
		s.copia = nil
		return
	end
	-- De lejos, o con Rendimiento (salvo el coche en el que vas), solo se mueve: sin adornos.
	local cerca = s.cine ~= nil or (camara.CFrame.Position - marco.Position).Magnitude < Config.Lobby.Cerca
	local rendimiento = jugador:GetAttribute("Rendimiento") == true
	local adorno = cerca and (s.cine ~= nil or not rendimiento)

	local faros = farosEncendidos(t)
	if faros ~= s.estadoFaros then
		s.estadoFaros = faros
		for _, faro in s.faros do
			encender(faro, faros, FARO_LUZ)
		end
	end
	local pilotos = t >= FAROS[1]
	if pilotos ~= s.estadoPilotos then
		s.estadoPilotos = pilotos
		for _, piloto in s.pilotos do
			encender(piloto, pilotos, PILOTO_LUZ)
		end
	end

	local humo = s.humo
	if humo then
		local cuanto = 0
		if adorno and t >= CONTACTO then
			cuanto = (9 + 26 * math.clamp(a / 16, 0, 1) + 0.15 * math.abs(v)) * (if rendimiento then 0.35 else 1)
			if not s.bocanada then
				s.bocanada = true
				if t < CONTACTO + 0.5 then
					humo:Emit(if rendimiento then 3 else 8) -- el motor arranca
				end
			end
		end
		humo.Rate = cuanto
	end

	-- El volante sigue la curva del camino sin saltos; la carrocería tiembla al arrancar y en ralentí, cabecea al
	-- acelerar y se inclina hacia fuera en las curvas.
	local objetivo = math.clamp(math.atan(s.batalla * curva), -0.7, 0.7)
	s.volante += (objetivo - s.volante) * (1 - math.exp(-dt * 7))
	local cuerpo = marco
	if adorno then
		local fuerza = if t < CONTACTO then 0 elseif t < CONTACTO + 0.4 then 0.045 - 0.0875 * (t - CONTACTO) else 0.01
		local temblor = fuerza * (if math.abs(v) < 0.3 then 1 else 0.25) * math.sin(t * 150)
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
	local barre = if adorno then barrido(t) else 0
	for _, g in s.limpias do
		g.giro = CFrame.new(g.eje) * CFrame.fromAxisAngle(g.normal, g.signo * barre) * CFrame.new(-g.eje)
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

	local punto = s.ruidoPunto -- el ruido del motor va con el coche
	if punto and punto.Parent then
		punto.WorldPosition = marco.Position
	end
end

local function paso(s: Salida, dt: number, camara: Camera)
	local ahora = workspace:GetServerTimeNow()
	if ahora > s.hora + ESPERA then -- sigue aquí: no se ha ido (o el servidor no ha quitado la hora)
		terminar(s)
		return
	end
	local t = ahora - s.inicio
	vigilarSentados(s, os.clock())
	local marco, rodado, v, a, curva = pose(s, t)
	moverCopia(s, t, dt, camara, marco, rodado, v, a, curva)
	-- La cinemática, si vas dentro. Si te bajas, se acaba la tuya y lo ves irse como los demás.
	local dentro = jugador:GetAttribute("Coche") == s.modelo.Name
	if dentro and not s.cine and ahora < s.hora then
		empezarCine(s)
	elseif not dentro and s.cine then
		acabarCine(s)
	end
	if s.cine then
		vigilarOtros(s, os.clock())
		moverCamara(s, t, ahora, marco, camara)
	end
end

local function preparar(s: Salida)
	local modelo = s.modelo
	local carroceria = modelo.PrimaryPart or modelo:FindFirstChild("Carroceria")
	assert(carroceria and carroceria:IsA("BasePart"), "el coche no tiene Carroceria")
	s.p0 = carroceria.Position
	local mira = carroceria.CFrame.LookVector
	s.psi0 = math.atan2(-mira.X, -mira.Z)
	s.eje = ejeTrasero(modelo, CFrame.new(s.p0) * CFrame.Angles(0, s.psi0, 0))
	local mia = caja(modelo)
	s.suelo, s.techo = mia.y1, mia.y2
	local atras, giro = salirDePlaza(modelo, mia, s.p0, s.eje)
	s.atras = if atras > 0.05 then atras else 0
	s.atrasDura = ATRAS_DURA[1] + ATRAS_DURA[2] * s.atras
	s.giro = giro
	s.v1 = math.min(SALE, giro * 1.1) -- girando muy cerrado, más despacio (que no dé un latigazo)
	local base = s.p0 + Vector3.new(math.sin(s.psi0), 0, math.cos(s.psi0)) * (s.eje + s.atras) -- el eje de atrás
	s.camino = hacerCamino(base.X, base.Z, giro)
	local _, _, psi1 = enCamino(s.camino, 1)
	s.curva0 = psi1

	-- Lo que se le cambia al coche de verdad (s.guardado) vuelve al acabar, aunque falle lo de después.
	table.insert(s.devolver, function()
		devolverGuardado(s.guardado)
		modelo:SetAttribute("SaliendoLocal", nil)
	end)
	-- Antes de copiarlo, sus limpias en su sitio y sus faros y pilotos apagados (con gente dentro, GasolineraVista los
	-- tiene encendidos: la copia los apuntaría encendidos y parpadearía mal).
	for parte, relativo in reposo[modelo] or {} do
		if parte.Parent then
			parte.CFrame = carroceria.CFrame * relativo
		end
	end
	for parte, color in apagados[modelo] or {} do
		if parte.Parent then
			cambiar(s.guardado, parte, "Color", color)
		end
	end
	local copia = hacerCopia(modelo)

	-- El de verdad, escondido en este cliente (GasolineraVista no lo toca mientras) y sin prompt.
	modelo:SetAttribute("SaliendoLocal", true)
	esconder(modelo, s.guardado, true)
	for _, d in modelo:GetDescendants() do
		if d:IsA("Seat") or d:IsA("VehicleSeat") then
			table.insert(s.asientos, d)
			s.esAsiento[d] = true
		end
	end

	table.insert(s.devolver, function()
		copia:Destroy()
	end)
	repartir(s, copia)
	local escape = copia:FindFirstChild("Escape", true)
	if escape and escape:IsA("Attachment") then
		for _, viejo in escape:GetChildren() do
			if viejo:IsA("ParticleEmitter") then
				viejo:Destroy() -- el humo del coche parado, si lo tenía: aquí va el de la salida
			end
		end
		s.humo = hacerHumo(escape, -carroceria.CFrame.LookVector)
	end
	copia.Parent = carpeta()
	s.copia = copia

	-- La grúa del segundo plano: de detrás y arriba del coche (donde esté al cambiar de plano) a encima del carril,
	-- curvándose hacia la carretera para no pasar por encima de los coches aparcados.
	local marco1 = pose(s, PLANO1)
	local detras = marco1.Position - marco1.LookVector * 11
	s.gruaA = Vector3.new(detras.X, s.techo + 2.4, detras.Z)
	s.gruaC = Vector3.new(CARRIL + 1.3, s.techo - 0.3, s.p0.Z - 14)
	s.gruaB = s.gruaA:Lerp(s.gruaC, 0.5) + Vector3.new(-3, 0.8, 0)
	s.grua = math.max(1.5, Config.Coches.Salida - PLANO1 - 0.6)

	if workspace:GetServerTimeNow() - s.inicio < 0.8 then -- al llegar tarde, ya ha arrancado
		local ruido = Sonido.en("Arranque", s.p0)
		if ruido then
			local punto = ruido.Parent
			s.ruidoPunto = if punto and punto:IsA("Attachment") then punto else nil
			table.insert(s.devolver, function()
				ruido:Destroy()
				if punto and punto:IsA("Attachment") then
					punto:Destroy()
				end
			end)
		end
	end
end

local function empezar(modelo: Model, hora: number)
	local s: Salida = {
		modelo = modelo,
		hora = hora,
		inicio = hora - Config.Coches.Salida,
		tarea = "SalidaVista:" .. modelo.Name,
		p0 = Vector3.zero,
		psi0 = 0,
		eje = 4.2,
		suelo = 0,
		techo = 0,
		atras = 0,
		atrasDura = ATRAS_DURA[1],
		giro = GIRO_MAX,
		v1 = SALE,
		curva0 = 0,
		camino = {},
		copia = nil,
		lista = {},
		bases = {},
		grupos = {},
		cframes = {},
		ruedas = {},
		limpias = {},
		batalla = 7.6,
		volante = 0,
		faros = {},
		pilotos = {},
		estadoFaros = nil,
		estadoPilotos = nil,
		humo = nil,
		bocanada = false,
		ruidoPunto = nil,
		asientos = {},
		esAsiento = {},
		escondidos = {},
		repaso = 0,
		otros = nil,
		repasoOtros = 0,
		guardado = {},
		devolver = {},
		cine = nil,
		gruaA = Vector3.zero,
		gruaB = Vector3.zero,
		gruaC = Vector3.zero,
		grua = 2.6,
		acabada = false,
	}
	salidas[modelo] = s
	local function fallo(mensaje: any)
		warn(`[SalidaVista] {modelo.Name}: {mensaje}`)
		terminar(s)
	end
	local ok, porque = pcall(preparar, s)
	if not ok then
		fallo(porque)
		return
	end
	local function cada(dt: number, _: number, camara: Camera)
		local bien, motivo = pcall(paso, s, dt, camara)
		if not bien then
			fallo(motivo)
		end
	end
	Bucle.cada(s.tarea, cada)
	cada(0, 0, workspace.CurrentCamera) -- ya, para que no se vea ni un fotograma la copia en el sitio del otro
end

local function registrar(objeto: Instance)
	if not objeto:IsA("Model") or vigilados[objeto] then
		return
	end
	local modelo = objeto :: Model
	vigilados[modelo] = true
	apuntarReposo(modelo)
	apuntarApagados(modelo)
	local function mirar()
		local hora = modelo:GetAttribute("Salida")
		local s = salidas[modelo]
		if s and s.hora ~= hora then
			terminar(s) -- se ha parado (o vuelto a arrancar con otra hora)
			s = nil
		end
		if not s and type(hora) == "number" and modelo:IsDescendantOf(workspace)
			and workspace:GetServerTimeNow() < hora + TARDE then
			empezar(modelo, hora)
		end
	end
	modelo:GetAttributeChangedSignal("Salida"):Connect(mirar)
	mirar()
end

function SalidaVista.start()
	Sonido.precargar({ "Arranque" })
	-- El fundido propio, por debajo del de CochesUi (DisplayOrder 100), que se esconde con el resto de la interfaz.
	capaNegro = Instance.new("ScreenGui")
	capaNegro.Name = "FundidoSalida"
	capaNegro.IgnoreGuiInset = true
	capaNegro.DisplayOrder = 99
	capaNegro.ResetOnSpawn = false
	negro = Instance.new("Frame")
	negro.Size = UDim2.fromScale(1, 1)
	negro.BackgroundColor3 = Color3.new(0, 0, 0)
	negro.BackgroundTransparency = 1
	negro.BorderSizePixel = 0
	negro.Visible = false
	negro.Parent = capaNegro
	capaNegro.Parent = jugador:WaitForChild("PlayerGui")

	for _, modelo in CollectionService:GetTagged("Coche") do
		registrar(modelo)
	end
	CollectionService:GetInstanceAddedSignal("Coche"):Connect(registrar)
	CollectionService:GetInstanceRemovedSignal("Coche"):Connect(function(objeto)
		local s = salidas[objeto :: any]
		if s then
			terminar(s)
		end
	end)
end

return SalidaVista
