-- Marcas de la noche: arañazos en las puertas y sangre salpicada en las paredes (docs/sistemas/marcas.md). Solo en el
-- cliente y solo de adorno: cada cliente las calcula con lo que ya ve (los atributos de cada Ventana y Puerta, los
-- bichos de workspace.Bichos y el remote Muerte) y con la misma semilla, así que se ven casi igual en todos.
--   Arañazos: cada golpe del Golpeador (atributo Golpes) deja un zarpazo de 3-4 surcos paralelos, oscuros y con el
--     borde claro de madera arrancada, y alguna astilla levantada: en la hoja de la puerta, en el marco o en la pared
--     de al lado de la ventana, por fuera. Cuando la hoja cede (poca vida, o echada abajo), también por dentro. Cada
--     surco se pega a lo que hay de verdad (rayos): si cruza un borde, se corta.
--   El Raspador, según raspa (su atributo Raspado), deja rayas finas y largas en el cristal, por fuera.
--   Se quedan hasta que se repara (vida llena y cristal sano): por la mañana se ve por dónde atacó cada noche. Las del
--     cristal se van con él cuando se rompe. Lo de la hoja y el cristal va soldado a ellos (CasaVista los mueve).
--   Sangre: al morir alguien (remote Muerte), rayos desde su pecho (más hacia el lado contrario del bicho) hasta 3 m:
--     donde dan (paredes, suelo, muebles), una mancha alargada en la dirección del golpe, gotas alrededor y, en lo
--     vertical, algún chorretón que escurre despacio hacia abajo. Rodea el charco de MuerteVista. Se seca de rojo a
--     casi negro y se limpia al amanecer (Fase = Dia). Nada de restos: solo manchas (etiqueta Moderate).
-- Piezas planas sin colisión, CanQuery ni CanTouch, en la carpeta workspace.Marcas del cliente. Tope de marcas vivas
-- (menos con Rendimiento, y entonces los chorretones salen ya escurridos, sin animar). Un solo Heartbeat, atado solo
-- mientras hay chorretones bajando o sangre fresca, que solo toca lo que está cerca de la cámara. Lo que se calcula
-- (semilla, surcos, rayos, tamaños, color, chorreo, tope) son funciones puras para el banco (tests/bancos/marcas.luau).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local MarcasVista = {}

local CFG = Config.Marcas
local RASPADO = CFG.Raspado
local GOLPES_CRISTAL = Config.Casa.GolpesCristal
local MARCO = 0.17 -- studs del borde del hueco al medio del marco (el marco de Mapa tiene 0,35 de grueso)
local PEGADO = 0.008 -- studs por encima de la superficie (que no parpadee con ella)

---------------------------------------------------------------- cuentas (puras, para el banco)

local function entre(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function rango(azar: Random, r: { number }): number
	return azar:NextNumber(r[1], r[2])
end

-- Una semilla que sale igual en todos los clientes: de un texto (la Clave de la ventana o puerta, el UserId) y un número.
function MarcasVista.semilla(texto: string, n: number): number
	local h = 7
	for i = 1, #texto do
		h = (h * 31 + string.byte(texto, i)) % 2147483629
	end
	return (h + math.floor(n) * 7919) % 2147483629 + 1
end

function MarcasVista.tope(rendimiento: boolean): number
	return if rendimiento then CFG.TopeRendimiento else CFG.Tope
end

-- Quita de la lista (por delante: las más viejas) lo que sobre del tope y lo devuelve.
function MarcasVista.recortar<T>(lista: { T }, tope: number): { T }
	local sobran = #lista - tope
	if sobran <= 0 then
		return {}
	end
	local quitadas = table.move(lista, 1, sobran, 1, {})
	table.move(lista, sobran + 1, #lista, 1)
	for i = #lista - sobran + 1, #lista do
		lista[i] = nil
	end
	return quitadas
end

-- Con esta vida la hoja cede: el bicho ya araña también por dentro.
function MarcasVista.cede(vida: number, vidaMax: number): boolean
	return vidaMax > 0 and vida / vidaMax < CFG.Cede
end

-- Si una ventana o puerta está dañada (al dejar de estarlo, se ha reparado).
function MarcasVista.danada(vida: number, vidaMax: number, cristal: number): boolean
	return vida < vidaMax or cristal > 0
end

export type Surco = { x: number, y: number, angulo: number, largo: number, ancho: number }

-- Los surcos de un zarpazo en el plano de la cara (x a un lado, y hacia arriba, en studs desde su centro; `angulo`
-- desde la vertical). Paralelos, un poco abiertos en abanico, el del medio más largo.
function MarcasVista.surcos(azar: Random, inclinaMax: number): { Surco }
	local n = azar:NextInteger(CFG.Surcos[1], CFG.Surcos[2])
	local angulo = azar:NextNumber(-inclinaMax, inclinaMax)
	local separa = rango(azar, CFG.Separa)
	local largo = rango(azar, CFG.Largo)
	local medio = (n + 1) / 2
	local lista = {}
	for i = 1, n do
		local a = angulo + (i - medio) * 0.05
		local lado = (i - medio) * separa
		local corre = azar:NextNumber(-0.12, 0.12) -- cada uña empieza un poco más arriba o más abajo
		local l = largo * (1 - 0.16 * math.abs(i - medio) / medio) * azar:NextNumber(0.9, 1.05)
		table.insert(lista, {
			x = math.cos(angulo) * lado + math.sin(angulo) * corre,
			y = -math.sin(angulo) * lado + math.cos(angulo) * corre,
			angulo = a,
			largo = l,
			ancho = rango(azar, CFG.Ancho),
		})
	end
	return lista
end

-- Las direcciones (unitarias) de los rayos de sangre: alrededor en abanico, casi todas a la altura del pecho o hacia
-- abajo. Con `lejosDe` (en planta, unitario: lo contrario de donde estaba el bicho), la mitad salen hacia ese lado.
function MarcasVista.rayosSangre(azar: Random, n: number, lejosDe: Vector3?): { Vector3 }
	local lista = {}
	local base = if lejosDe then math.atan2(lejosDe.Z, lejosDe.X) else 0
	for i = 1, n do
		local giro
		if lejosDe and i % 2 == 0 then
			giro = base + azar:NextNumber(-0.9, 0.9)
		else
			giro = (i + azar:NextNumber(-0.4, 0.4)) / n * math.pi * 2
		end
		local y = azar:NextNumber(-0.85, 0.3)
		local plano = math.sqrt(1 - y * y)
		table.insert(lista, Vector3.new(math.cos(giro) * plano, y, math.sin(giro) * plano))
	end
	return lista
end

-- El tamaño de una mancha a `distancia` studs que llega en `dir` a una superficie de normal `normal`: { ancho, largo }.
-- Más grande cuanto más cerca; alargada en la dirección del golpe cuanto más de refilón llega (como mucho 3 veces).
function MarcasVista.mancha(distancia: number, dir: Vector3, normal: Vector3, escala: number): (number, number)
	local t = math.clamp(distancia / CFG.Alcance, 0, 1)
	local ancho = entre(CFG.Mancha[2], CFG.Mancha[1], t) * escala
	local recto = math.clamp(math.abs(dir:Dot(normal)), 1 / 3, 1)
	return ancho, ancho / recto
end

-- El color (RGB de 0 a 255) de la sangre al cabo de `segundos`: de roja a casi negra en CFG.Secar.
function MarcasVista.colorSangre(segundos: number): (number, number, number)
	local t = math.clamp(segundos / CFG.Secar, 0, 1)
	local a, b = CFG.Fresca, CFG.Seca
	return entre(a[1], b[1], t), entre(a[2], b[2], t), entre(a[3], b[3], t)
end

-- Lo que ha bajado un chorretón de `largo` studs que tarda `dura` s, al cabo de `t` s: deprisa al principio y cada
-- vez más despacio, como la sangre que se va quedando por el camino.
function MarcasVista.chorreo(t: number, dura: number, largo: number): number
	local u = math.clamp(t / dura, 0, 1)
	return largo * (1 - (1 - u) ^ 2.2)
end

---------------------------------------------------------------- en el mundo

type Marca = {
	partes: { BasePart },
	tintes: { Instance }, -- lo que se seca (piezas y el Decal del hollín)
	el: Model?, -- la ventana o puerta en la que está
	cristal: boolean, -- rayas del Raspador en el cristal (se van al romperse)
	sangre: boolean,
	nace: number,
	seca: boolean,
	viva: boolean,
}

type Chorreon = {
	marca: Marca,
	barra: BasePart,
	gota: BasePart,
	arriba: Vector3,
	abajo: Vector3, -- unitario, por la superficie
	cara: CFrame, -- la orientación (X a un lado, Y = normal, Z = abajo)
	largo: number,
	dura: number,
	nace: number,
}

local jugador = Players.LocalPlayer
local carpeta: Folder
local marcas: { Marca } = {}
local chorreones: { Chorreon } = {}
local frescas: { Marca } = {} -- sangre aún secándose
local fuera: { Instance } = {} -- lo que los rayos no ven
local rayo = RaycastParams.new()
local bichosCarpeta: Instance? = nil
local elementos: { [Model]: boolean } = {} -- ventanas y puertas (true = puerta)
local bucle: RBXScriptConnection? = nil

-- Para el banco: cuántas marcas hay vivas y cuántos chorretones bajando.
function MarcasVista.cuantas(): (number, number)
	return #marcas, #chorreones
end

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function poco(): boolean
	return jugador:GetAttribute("Rendimiento") == true
end

local function rehacerRayo()
	table.clear(fuera)
	table.insert(fuera, carpeta)
	if bichosCarpeta then
		table.insert(fuera, bichosCarpeta)
	end
	for _, j in Players:GetPlayers() do
		if j.Character then
			table.insert(fuera, j.Character)
		end
	end
	rayo.FilterType = Enum.RaycastFilterType.Exclude
	rayo.FilterDescendantsInstances = fuera
end

-- Un rayo que no se para en lo invisible (bloques tapados por un mueble de Blender, el cristal roto). Lo suelto (que
-- se mueve con la física) no vale: la marca se quedaría en el aire.
local function lanzar(desde: Vector3, hacia: Vector3): RaycastResult?
	local params = rayo
	for _ = 1, 4 do
		local r = workspace:Raycast(desde, hacia, params)
		if not r then
			return nil
		end
		local p = r.Instance
		if p:IsA("BasePart") and (p.Transparency >= 0.95 or p.LocalTransparencyModifier >= 0.95) then
			if params == rayo then
				params = RaycastParams.new()
				params.FilterType = Enum.RaycastFilterType.Exclude
				params.FilterDescendantsInstances = table.clone(fuera)
			end
			params:AddToFilter(p)
			continue
		end
		if p:IsA("BasePart") and not p:IsA("Terrain") and not p.Anchored then
			return nil
		end
		return r
	end
	return nil
end

-- La ventana o puerta a la que pertenece una pieza (sus piezas se mueven: lo que se les pega va soldado).
local function elementoDe(p: Instance): Model?
	local a = p.Parent
	while a and a ~= workspace do
		if a:IsA("Model") and elementos[a :: Model] ~= nil then
			return a :: Model
		end
		a = a.Parent
	end
	return nil
end

local function pieza(tam: Vector3, cf: CFrame, color: Color3, material: Enum.Material, m: Marca, en: BasePart?): Part
	local p = Instance.new("Part")
	p.Name = "Marca"
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = material
	p.Color = color
	p.Size = tam
	p.CFrame = cf
	-- Pegada a algo que se mueve (la hoja, el cristal): soldada a ello; si no, anclada.
	if en then
		p.Anchored = false
		p.Massless = true
		local union = Instance.new("WeldConstraint")
		union.Part0, union.Part1 = en, p
		union.Parent = p
	else
		p.Anchored = true
	end
	p.Parent = carpeta
	table.insert(m.partes, p)
	return p
end

local function quitar(m: Marca)
	m.viva = false
	for _, p in m.partes do
		p:Destroy()
	end
	table.clear(m.partes)
end

local function nueva(el: Model?, sangre: boolean, cristal: boolean): Marca
	return { partes = {}, tintes = {}, el = el, cristal = cristal, sangre = sangre, nace = os.clock(), seca = not sangre,
		viva = true }
end

local function apuntar(m: Marca)
	if #m.partes == 0 then
		m.viva = false
		return
	end
	table.insert(marcas, m)
	for _, vieja in MarcasVista.recortar(marcas, MarcasVista.tope(poco())) do
		quitar(vieja)
	end
end

-- Quita las marcas que cumplan `cual` (y las saca de la lista).
local function limpiar(cual: (Marca) -> boolean)
	local quedan = {}
	for _, m in marcas do
		if cual(m) then
			quitar(m)
		else
			table.insert(quedan, m)
		end
	end
	table.clear(marcas)
	table.move(quedan, 1, #quedan, 1, marcas)
end

-- La orientación de algo plano sobre una superficie de normal `normal` y largo hacia `largo` (X a un lado, Y la
-- normal, Z a lo largo).
local function sobre(donde: Vector3, normal: Vector3, largo: Vector3): CFrame
	local z = largo - normal * largo:Dot(normal)
	if z.Magnitude < 1e-3 then
		z = normal:Cross(Vector3.xAxis)
		if z.Magnitude < 1e-3 then
			z = normal:Cross(Vector3.zAxis)
		end
	end
	z = z.Unit
	return CFrame.fromMatrix(donde, normal:Cross(z), normal)
end

---------------------------------------------------------------- arañazos

-- Un surco del plano `cara` (LookVector hacia quien mira la superficie): se busca la superficie de verdad a lo largo de
-- él y se queda con el trozo seguido más largo (misma pieza, misma profundidad, de cara). nil si no queda nada.
local function pegarSurco(cara: CFrame, s: Surco, dentro: Model): (CFrame?, number, BasePart?)
	local mira = cara.LookVector
	local dir = cara.RightVector * math.sin(s.angulo) + cara.UpVector * math.cos(s.angulo)
	local centro = cara.Position + cara.RightVector * s.x + cara.UpVector * s.y
	local PUNTOS = 6
	local tramo, mejor = {}, {}
	local function cerrar()
		if #tramo > #mejor then
			mejor = tramo
		end
		tramo = {}
	end
	-- De cara, sin ser de otra ventana o puerta y opaco (en el cristal no: ahí solo raya el Raspador).
	local function bueno(r: RaycastResult?): boolean
		if not r or r.Normal:Dot(mira) <= 0.7 or (r.Instance :: BasePart).Transparency >= 0.3 then
			return false
		end
		local de = elementoDe(r.Instance)
		return de == nil or de == dentro
	end
	for i = 0, PUNTOS - 1 do
		local u = i / (PUNTOS - 1) - 0.5
		local punto = centro + dir * (u * s.largo)
		local r = lanzar(punto + mira * 1.6, -mira * 3.2)
		if not bueno(r) then
			cerrar()
			continue
		end
		local hit = r :: RaycastResult
		local antes = tramo[#tramo]
		-- Sigue el tramo si es la misma pieza a la misma profundidad; si no, empieza otro aquí.
		if antes and (antes.r.Instance ~= hit.Instance or math.abs((antes.r.Position - hit.Position):Dot(mira)) >= 0.08) then
			cerrar()
		end
		table.insert(tramo, { u = u, r = hit })
	end
	cerrar()
	if #mejor < 2 then
		return nil, 0, nil
	end
	local paso = s.largo / (PUNTOS - 1)
	local desde, hasta = mejor[1].u * s.largo - paso * 0.4, mejor[#mejor].u * s.largo + paso * 0.4
	desde, hasta = math.max(desde, -s.largo / 2), math.min(hasta, s.largo / 2)
	local largo = hasta - desde
	if largo < 0.35 then
		return nil, 0, nil
	end
	local primero = mejor[1].r
	local normal = primero.Normal
	-- El punto medio del trozo, sobre el plano de lo que se tocó.
	local medio = centro + dir * ((desde + hasta) / 2)
	local donde = medio - normal * (medio - primero.Position):Dot(normal)
	local en = primero.Instance :: BasePart
	return sobre(donde + normal * PEGADO, normal, dir), largo, en
end

-- Un zarpazo con centro en `cara` (LookVector hacia fuera de la superficie arañada) en la ventana o puerta `el`.
local function zarpazo(el: Model, cara: CFrame, azar: Random, inclina: number)
	local m = nueva(el, false, false)
	local simple = poco()
	local hechos: { { cf: CFrame, largo: number, ancho: number, en: BasePart? } } = {}
	for _, s in MarcasVista.surcos(azar, inclina) do
		local cf, largo, en = pegarSurco(cara, s, el)
		if not cf or not en then
			continue
		end
		local soldar = if elementoDe(en) == el then en else nil
		local madera = en.Color
		-- El surco, oscuro y en sombra (hundido)...
		pieza(Vector3.new(s.ancho, 0.02, largo), cf, Color3.new(madera.R * CFG.Oscuro, madera.G * CFG.Oscuro,
			madera.B * CFG.Oscuro), Enum.Material.SmoothPlastic, m, soldar)
		-- ...y a un lado, el borde claro de la madera levantada.
		pieza(Vector3.new(s.ancho * 0.4, 0.03, largo * 0.85), cf * CFrame.new(s.ancho * 0.62, 0.006, azar:NextNumber(-0.05, 0.05)),
			rgb(CFG.Claro), Enum.Material.Wood, m, soldar)
		table.insert(hechos, { cf = cf, largo = largo, ancho = s.ancho, en = soldar })
	end
	-- Astillas claras levantadas donde acaban las uñas (en el extremo de abajo del surco).
	if not simple and #hechos > 0 then
		for _ = 1, azar:NextInteger(CFG.Astillas[1], CFG.Astillas[2]) do
			local h = hechos[azar:NextInteger(1, #hechos)]
			local punta = if (h.cf * CFrame.new(0, 0, h.largo / 2)).Position.Y < (h.cf * CFrame.new(0, 0, -h.largo / 2)).Position.Y
				then 1 else -1
			local largo = azar:NextNumber(0.14, 0.3)
			local alza = azar:NextNumber(0.35, 0.7)
			-- Girada sobre su eje X hacia fuera de la superficie (+Y del surco): levantada desde la punta.
			local cf = h.cf * CFrame.new(azar:NextNumber(-h.ancho, h.ancho), 0, punta * (h.largo / 2 - largo * 0.3))
				* CFrame.Angles(-punta * alza, azar:NextNumber(-0.4, 0.4), 0) * CFrame.new(0, 0.015, punta * largo / 2)
			pieza(Vector3.new(azar:NextNumber(0.04, 0.07), 0.025, largo), cf, rgb(CFG.Claro), Enum.Material.Wood, m, h.en)
		end
	end
	apuntar(m)
end

local function clave(el: Model): string
	local c = el:GetAttribute("Clave")
	return if type(c) == "string" then c else el:GetFullName()
end

-- Dónde cae el zarpazo número `golpes` de `el`: un punto de la cara por fuera (o por dentro) y su azar.
local function rascar(el: Model, golpes: number, dentro: boolean)
	local centro = el:GetAttribute("Centro")
	if typeof(centro) ~= "CFrame" then
		return
	end
	local azar = Random.new(MarcasVista.semilla(clave(el), golpes * 2 + (if dentro then 1 else 0)))
	local esPuerta = elementos[el] == true
	local ancho = el:GetAttribute("Ancho") or 4
	local alto = el:GetAttribute("Alto")
	if type(alto) ~= "number" then
		local hoja = el:FindFirstChild("Hoja")
		alto = if hoja and hoja:IsA("BasePart") then hoja.Size.Y else 7
	end
	local x, y, inclina = 0, 0, CFG.Inclina
	if esPuerta and (dentro or azar:NextNumber() < CFG.EnHoja) then
		x = azar:NextNumber(-ancho / 2 + 0.6, ancho / 2 - 0.6)
		y = azar:NextNumber(-alto / 2 + 1.4, alto / 2 - 0.9)
	elseif esPuerta then
		x = (if azar:NextNumber() < 0.5 then -1 else 1) * (ancho / 2 + MARCO)
		y = azar:NextNumber(-alto / 2 + 1.2, alto / 2 - 0.6)
		inclina = 0.15 -- por el marco, a lo largo
	else
		local donde = azar:NextNumber()
		if donde < 0.45 then -- los lados del marco
			x = (if azar:NextNumber() < 0.5 then -1 else 1) * (ancho / 2 + MARCO)
			y = azar:NextNumber(-alto / 2, alto / 2)
			inclina = 0.15
		elseif donde < 0.75 then -- la pared de al lado
			x = (if azar:NextNumber() < 0.5 then -1 else 1) * (ancho / 2 + azar:NextNumber(0.9, 1.6))
			y = azar:NextNumber(-alto / 2, alto / 2)
		else -- el alféizar y la pared de debajo
			x = azar:NextNumber(-ancho / 2 + 0.4, ancho / 2 - 0.4)
			y = -alto / 2 - azar:NextNumber(0.4, 1.4)
		end
	end
	-- Mirando hacia fuera (o hacia la sala, por dentro): LookVector hacia quien ve la superficie arañada.
	local cara = (centro :: CFrame) * CFrame.new(x, y, 0)
	if dentro then
		cara *= CFrame.Angles(0, math.pi, 0)
	end
	zarpazo(el, cara, azar, inclina)
end

---------------------------------------------------------------- el Raspador

local function rasparCristal(el: Model, nivel: number)
	local cristal = el:FindFirstChild("Cristal")
	if not cristal or not cristal:IsA("BasePart") or (el:GetAttribute("Cristal") or 0) >= GOLPES_CRISTAL then
		return
	end
	local azar = Random.new(MarcasVista.semilla(clave(el), 1000 + nivel))
	local ancho, alto = cristal.Size.X, cristal.Size.Y
	local m = nueva(el, false, true)
	local x = azar:NextNumber(-ancho / 2 + 0.4, ancho / 2 - 0.4)
	local angulo = azar:NextNumber(-0.22, 0.22) -- casi rectas hacia abajo: las manos bajan por el cristal
	for i = 1, azar:NextInteger(RASPADO.Rayas[1], RASPADO.Rayas[2]) do
		local largo = math.min(rango(azar, RASPADO.Largo), alto - 0.3)
		-- Que no se salga del cristal: lo que ocupa de lado y de alto, ya inclinada, cabe con 0,15 de margen.
		local mx = ancho / 2 - 0.15 - math.abs(math.sin(angulo)) * largo / 2
		local my = alto / 2 - 0.15 - math.cos(angulo) * largo / 2
		local xi = math.clamp(x + (i - 1) * azar:NextNumber(0.1, 0.22), -math.max(0, mx), math.max(0, mx))
		local yi = azar:NextNumber(-math.max(0, my), math.max(0, my))
		-- Por fuera: el cristal mira hacia fuera con su -Z (Mapa: CFrame.lookAt hacia fuera).
		local cf = cristal.CFrame * CFrame.new(xi, yi, -cristal.Size.Z / 2 - 0.004) * CFrame.Angles(0, 0, angulo)
		local p = pieza(Vector3.new(RASPADO.Ancho, largo, 0.006), cf, rgb(RASPADO.Color), Enum.Material.SmoothPlastic, m,
			cristal)
		p.Transparency = RASPADO.Transparencia
	end
	apuntar(m)
end

local function verRaspador(modelo: Instance)
	if modelo.Name ~= "Raspador" or not modelo:IsA("Model") then
		return
	end
	local raiz = modelo:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if not raiz then
		return
	end
	local nivel = 0
	modelo:GetAttributeChangedSignal("Raspado"):Connect(function()
		local hecho = modelo:GetAttribute("Raspado")
		if type(hecho) ~= "number" then
			return
		end
		local ahora = math.floor(hecho / RASPADO.Cada)
		if ahora < nivel then
			nivel = ahora -- otra ventana: empieza de nuevo
			return
		end
		if ahora == nivel or not modelo:GetAttribute("Raspando") then
			return
		end
		-- La ventana que raspa: la que tiene su sitio de fuera más cerca.
		local mejor, cerca = nil, RASPADO.Cerca
		for el, esPuerta in elementos do
			local f = el:GetAttribute("Fuera")
			if not esPuerta and typeof(f) == "Vector3" then
				local d = Vector3.new(f.X - raiz.Position.X, 0, f.Z - raiz.Position.Z).Magnitude
				if d < cerca then
					mejor, cerca = el, d
				end
			end
		end
		for n = nivel + 1, math.min(ahora, nivel + 3) do
			if mejor then
				rasparCristal(mejor, n)
			end
		end
		nivel = ahora
	end)
end

---------------------------------------------------------------- sangre

local function atar()
	if bucle then
		return
	end
	local espera = 0
	bucle = RunService.Heartbeat:Connect(function(dt)
		local camara = workspace.CurrentCamera.CFrame.Position
		local ahora = os.clock()
		-- Chorretones: bajan cada fotograma (solo los cercanos; los lejos, al acabar se ponen del todo).
		for i = #chorreones, 1, -1 do
			local c = chorreones[i]
			local t = ahora - c.nace
			local acabado = t >= c.dura or not c.marca.viva
			if c.marca.viva and (acabado or (c.arriba - camara).Magnitude < CFG.Cerca) then
				local l = math.max(0.05, MarcasVista.chorreo(t, c.dura, c.largo))
				local cf = c.cara.Rotation + c.arriba
				c.barra.Size = Vector3.new(c.barra.Size.X, c.barra.Size.Y, l)
				c.barra.CFrame = cf * CFrame.new(0, 0, l / 2)
				c.gota.CFrame = cf * CFrame.new(0, 0.004, l)
			end
			if acabado then
				table.remove(chorreones, i)
			end
		end
		espera += dt
		if espera >= CFG.CadaColor then
			espera = 0
			for i = #frescas, 1, -1 do
				local m = frescas[i]
				local edad = ahora - m.nace
				local acabada = edad >= CFG.Secar or not m.viva
				if m.viva and (acabada or #m.partes > 0 and (m.partes[1].Position - camara).Magnitude < CFG.Cerca) then
					local r, g, b = MarcasVista.colorSangre(edad)
					local color = Color3.fromRGB(r, g, b)
					for _, t in m.tintes do
						if t:IsA("Decal") then
							t.Color3 = color
						elseif t:IsA("BasePart") then
							t.Color = color
						end
					end
				end
				if acabada then
					m.seca = true
					table.remove(frescas, i)
				end
			end
		end
		if #chorreones == 0 and #frescas == 0 and bucle then
			bucle:Disconnect()
			bucle = nil
		end
	end)
end

local function bola(tam: Vector3, cf: CFrame, color: Color3, m: Marca, en: BasePart?): Part
	local p = pieza(tam, cf, color, Enum.Material.SmoothPlastic, m, en)
	p.Reflectance = 0.06 -- un poco húmeda: brillo flojo
	local malla = Instance.new("SpecialMesh")
	malla.MeshType = Enum.MeshType.Sphere
	malla.Parent = p
	table.insert(m.tintes, p)
	return p
end

-- Hasta dónde puede bajar un chorretón desde `arriba` por la superficie de `en` (sin salirse de ella ni pasar del
-- suelo), como mucho `largo`.
local function cabe(arriba: Vector3, normal: Vector3, abajo: Vector3, en: Instance, largo: number): number
	local suelo = lanzar(arriba + normal * 0.1, Vector3.new(0, -(largo + 0.2), 0))
	if suelo then
		largo = math.min(largo, suelo.Distance - 0.15)
	end
	local hasta = 0
	local paso = 0.25
	local s = paso
	while s <= largo do
		local p = arriba + abajo * s
		local r = lanzar(p + normal * 0.15, -normal * 0.35)
		if not r or r.Instance ~= en or r.Normal:Dot(normal) < 0.9 then
			break
		end
		hasta = s
		s += paso
	end
	return math.max(0, math.min(largo, hasta))
end

local function salpicar(quien: Player, cabeza: Vector3?)
	local personaje = quien.Character
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not raiz then
		return
	end
	rehacerRayo()
	local origen = raiz.Position + Vector3.new(0, CFG.Pecho, 0)
	local azar = Random.new(MarcasVista.semilla(tostring(quien.UserId),
		math.floor(origen.X + 0.5) * 131 + math.floor(origen.Z + 0.5)))
	local simple = poco()
	local lejosDe = nil
	if cabeza then
		local d = Vector3.new(origen.X - cabeza.X, 0, origen.Z - cabeza.Z)
		if d.Magnitude > 0.1 then
			lejosDe = d.Unit
		end
	end
	local n = if simple then math.floor(CFG.Rayos / 2) else CFG.Rayos
	local fresca = rgb(CFG.Fresca)
	local ahora = os.clock()
	local hechos = 0
	local nuevas: { Marca } = {}
	for _, dir in MarcasVista.rayosSangre(azar, n, lejosDe) do
		local escala = azar:NextNumber(0.75, 1.25)
		local r = lanzar(origen, dir * CFG.Alcance)
		if not r then
			continue
		end
		local en = r.Instance :: BasePart
		local el = elementoDe(en)
		local soldar = if el then en else nil
		local normal = r.Normal
		local ancho, largo = MarcasVista.mancha(r.Distance, dir, normal, escala)
		local alto = 0.012 + (hechos % 5) * 0.002 -- que no se pisen entre ellas (y por debajo del charco: lo rodean)
		hechos += 1
		local donde = r.Position + normal * alto
		local cf = sobre(donde, normal, dir)
		local m = nueva(el, true, false)
		m.nace = ahora
		bola(Vector3.new(ancho, 0.02, largo), cf, fresca, m, soldar)
		-- La mancha grande, con el hollín teñido encima (bordes irregulares).
		if ancho > entre(CFG.Mancha[1], CFG.Mancha[2], 0.5) then
			local placa = pieza(Vector3.new(ancho * 1.5, 0.01, largo * 1.5), cf * CFrame.new(0, 0.004, 0), fresca,
				Enum.Material.SmoothPlastic, m, soldar)
			placa.Transparency = 1
			local d = Instance.new("Decal")
			d.Texture = CFG.Textura
			d.Face = Enum.NormalId.Top
			d.Color3 = fresca
			d.Transparency = 0.25
			d.Parent = placa
			table.insert(m.tintes, d)
			table.insert(m.tintes, placa) -- (no se ve, pero que no se quede roja)
		end
		-- Gotas alrededor, sobre todo hacia donde iba (solo si debajo sigue la misma superficie).
		for _ = 1, azar:NextInteger(CFG.Gotas[1], CFG.Gotas[2]) do
			local lejos = azar:NextNumber(0.6, 1.8) * largo
			local local_ = CFrame.new(azar:NextNumber(-0.6, 0.6) * ancho, 0, lejos * 0.6) -- (+Z: hacia donde iba)
			local punto = (cf * local_).Position
			local abajo = lanzar(punto + normal * 0.2, -normal * 0.4)
			if abajo and abajo.Instance == en then
				local g = rango(azar, CFG.Gota)
				bola(Vector3.new(g, 0.016, g * azar:NextNumber(1, 1.8)), sobre(abajo.Position + normal * alto, normal, dir),
					fresca, m, soldar)
			end
		end
		-- En lo vertical, alguna mancha grande escurre hacia abajo (no en lo que se mueve).
		if math.abs(normal.Y) < 0.35 and not soldar and #chorreones < 40 and ancho > CFG.Mancha[2] * 0.6
			and azar:NextNumber() < CFG.Chorreon then
			local bajar = Vector3.new(0, -1, 0) - normal * -normal.Y
			if bajar.Magnitude > 0.5 and #nuevas < CFG.Chorreones then
				bajar = bajar.Unit
				local cara = sobre(donde, normal, bajar)
				local arriba = donde + bajar * (largo * 0.2)
				local hasta = cabe(arriba, normal, bajar, en, rango(azar, CFG.ChorreaLargo))
				if hasta > 0.3 then
					local grueso = azar:NextNumber(0.06, 0.11)
					local barra = pieza(Vector3.new(grueso, 0.015, 0.05), cara.Rotation + arriba, fresca,
						Enum.Material.SmoothPlastic, m)
					barra.Reflectance = 0.06
					table.insert(m.tintes, barra)
					local gota = bola(Vector3.new(grueso * 1.6, 0.03, grueso * 2.2), cara.Rotation + arriba, fresca, m)
					local c: Chorreon = { marca = m, barra = barra, gota = gota, arriba = arriba, abajo = bajar, cara = cara,
						largo = hasta, dura = rango(azar, CFG.ChorreaDura), nace = ahora + 0.4 }
					if simple then
						c.nace = ahora - c.dura -- con Rendimiento, ya escurrido (sin animar)
						local cf2 = cara.Rotation + arriba
						barra.Size = Vector3.new(grueso, 0.015, hasta)
						barra.CFrame = cf2 * CFrame.new(0, 0, hasta / 2)
						gota.CFrame = cf2 * CFrame.new(0, 0.004, hasta)
					else
						table.insert(chorreones, c)
					end
					table.insert(nuevas, m)
				end
			end
		end
		apuntar(m)
		if m.viva then
			table.insert(frescas, m)
		end
	end
	if #frescas > 0 or #chorreones > 0 then
		atar()
	end
end

---------------------------------------------------------------- ventanas y puertas

local function vigilar(el: Instance, esPuerta: boolean)
	if not el:IsA("Model") or elementos[el] ~= nil then
		return
	end
	local modelo = el :: Model
	elementos[modelo] = esPuerta
	local golpes = modelo:GetAttribute("Golpes") or 0
	local function estado(): (number, number, number)
		local max = modelo:GetAttribute("VidaMax") or 1
		return modelo:GetAttribute("Vida") or max, max, modelo:GetAttribute("Cristal") or 0
	end
	local danada = MarcasVista.danada(estado())
	local vidaAntes = (estado())
	local cristalAntes = modelo:GetAttribute("Cristal") or 0

	local ultimoGolpe = -math.huge
	modelo:GetAttributeChangedSignal("Golpes"):Connect(function()
		ultimoGolpe = os.clock()
		-- En diferido: el servidor sube Golpes y luego la vida; así ya se sabe si la hoja cede.
		task.defer(function()
			local ahora = modelo:GetAttribute("Golpes") or 0
			for n = golpes + 1, math.min(ahora, golpes + 3) do
				rascar(modelo, n, false)
				local vida, max = estado()
				if esPuerta and MarcasVista.cede(vida, max) then
					rascar(modelo, n, true)
				end
			end
			golpes = math.max(golpes, ahora)
		end)
	end)
	local function cambio()
		local vida, max, cristal = estado()
		local ahora = MarcasVista.danada(vida, max, cristal)
		if danada and not ahora then
			-- Reparada: como nueva, sin marcas.
			limpiar(function(m)
				return m.el == modelo
			end)
		elseif cristal >= GOLPES_CRISTAL and cristalAntes < GOLPES_CRISTAL then
			-- El cristal roto: sus rayas se van con él.
			limpiar(function(m)
				return m.el == modelo and m.cristal
			end)
		end
		-- Echada abajo sin golpes (la Bestia rompe la puerta de una vez): arañazos por los dos lados.
		if esPuerta and vida <= 0 and vidaAntes > 0 and os.clock() - ultimoGolpe > 0.5 then
			local n = 500 + (modelo:GetAttribute("Golpes") or 0)
			rascar(modelo, n, false)
			rascar(modelo, n, true)
		end
		danada, vidaAntes, cristalAntes = ahora, vida, cristal
	end
	for _, a in { "Vida", "VidaMax", "Cristal" } do
		modelo:GetAttributeChangedSignal(a):Connect(cambio)
	end
	modelo.Destroying:Once(function()
		elementos[modelo] = nil
		limpiar(function(m)
			return m.el == modelo
		end)
	end)
end

function MarcasVista.start()
	carpeta = Instance.new("Folder")
	carpeta.Name = "Marcas"
	carpeta.Parent = workspace
	rehacerRayo()

	for _, etiqueta in { "Ventana", "Puerta" } do
		local esPuerta = etiqueta == "Puerta"
		for _, el in CollectionService:GetTagged(etiqueta) do
			vigilar(el, esPuerta)
		end
		CollectionService:GetInstanceAddedSignal(etiqueta):Connect(function(el)
			vigilar(el, esPuerta)
		end)
	end

	Remotes.Muerte.OnClientEvent:Connect(function(quien: Player, cabeza: Vector3?)
		if typeof(quien) == "Instance" and quien:IsA("Player") then
			salpicar(quien, if typeof(cabeza) == "Vector3" then cabeza else nil)
		end
	end)
	Players.PlayerAdded:Connect(function(j)
		j.CharacterAdded:Connect(rehacerRayo)
	end)
	for _, j in Players:GetPlayers() do
		j.CharacterAdded:Connect(rehacerRayo)
	end

	-- Al amanecer, la sangre limpia (los arañazos se quedan hasta que se repare).
	workspace:GetAttributeChangedSignal("Fase"):Connect(function()
		if workspace:GetAttribute("Fase") == "Dia" then
			limpiar(function(m)
				return m.sangre
			end)
		end
	end)
	-- Con Rendimiento, el tope más bajo enseguida y los chorretones que bajaban, ya abajo (en el próximo fotograma).
	jugador:GetAttributeChangedSignal("Rendimiento"):Connect(function()
		for _, vieja in MarcasVista.recortar(marcas, MarcasVista.tope(poco())) do
			quitar(vieja)
		end
		if poco() then
			local ahora = os.clock()
			for _, c in chorreones do
				c.nace = ahora - c.dura
			end
		end
	end)

	task.spawn(function()
		local bichosC = workspace:WaitForChild("Bichos")
		bichosCarpeta = bichosC
		rehacerRayo()
		bichosC.ChildAdded:Connect(verRaspador)
		for _, modelo in bichosC:GetChildren() do
			task.spawn(verRaspador, modelo)
		end
	end)
end

return MarcasVista
