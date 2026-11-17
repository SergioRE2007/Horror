-- Puertas que revientan (docs/sistemas/puerta-rota.md): lo que el Golpeador hace a una puerta se ve en la hoja.
--   Con menos de la mitad de vida (Config.PuertaRota.Cede) la hoja se parte en tablas y un trozo de una se mete hacia
--     dentro: queda una rendija por la que entra la luz de fuera (luna, relámpago, la linterna del otro lado). Con
--     menos de un cuarto, otro.
--   Echada abajo (Vida 0; el servidor la deja Abierta y sin choque): la hoja se queda colgando de la bisagra de abajo,
--     torcida hacia la sala y ladeada, con un balanceo que se apaga; los trozos metidos salen volando con 10-14 astillas
--     y trozos de tabla (piezas sueltas con física local que se anclan a los 2 s), quedan picos de madera en el marco
--     del lado de la cerradura, el pomo sale rodando y cae polvo del dintel. Las astillas crujen al pisarlas.
--   Reparada (Vida llena): se recogen las astillas y la hoja vuelve a su sitio. De día siguen ahí: se ve qué puerta cayó.
--   Con Rendimiento: 5 astillas, sin tablas que ceden ni pomo que rueda.
-- La hoja la sigue moviendo CasaVista (colocar): aquí solo se le dice dónde colgarla (CasaVista.alPuerta) y se meten
-- las tablas en sus `piezas`. Las marcas de MarcasVista van soldadas a la hoja: cuelgan con ella. Un solo Heartbeat,
-- atado solo mientras hay algo que mover o astillas en el suelo (y quién las pisa, solo cerca de la cámara).
local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local CasaVista = require(script.Parent.CasaVista)
local Sonido = require(script.Parent.Sonido)

type Puerta = CasaVista.Puerta

local PuertaRotaVista = {}

local P = Config.PuertaRota
local jugador = Players.LocalPlayer
local azar = Random.new()
local MADERA_VIVA = Color3.fromRGB(150, 112, 74) -- madera de dentro, recién partida (más clara que la pintada)

local function poco(): boolean
	return jugador:GetAttribute("Rendimiento") == true
end

---------------------------------------------------------------- cuentas (las mira el banco)

-- 0 sana, 1 un trozo metido, 2 dos, 3 echada abajo.
function PuertaRotaVista.etapa(vida: number, vidaMax: number): number
	if vida <= 0 then
		return 3
	end
	local f = vida / math.max(vidaMax, 1e-3)
	return if f < P.Cede[2] then 2 elseif f < P.Cede[1] then 1 else 0
end

-- Cuántas tablas tiene una hoja de este ancho.
function PuertaRotaVista.tablas(ancho: number): number
	return math.max(3, math.floor(ancho / P.Tablas + 0.5))
end

-- La caída de la hoja (t de 0 a 1): cae cada vez más deprisa y rebota un poco al quedarse colgando.
function PuertaRotaVista.rebote(t: number): number
	t = math.clamp(t, 0, 1)
	if t < 0.6 then
		local k = t / 0.6
		return k * k
	end
	return 1 - 0.08 * math.sin(math.pi * (t - 0.6) / 0.4)
end

-- Grados de más hacia la sala mientras se balancea (`t` segundos desde que se quedó colgando).
function PuertaRotaVista.mecer(t: number): number
	local m = P.Mecer
	if t >= m.Segundos then
		return 0
	end
	return m.Grados * math.exp(-3 * t / m.Segundos) * math.sin(2 * math.pi * m.Vueltas * t / m.Segundos)
end

-- Dónde queda la bisagra (lo que CasaVista pone en vez de girarla) con la hoja colgando de la bisagra de abajo:
-- abierta Colgada.Giro grados hacia la sala (`giro`, el signo de CasaVista), caída del lado de la cerradura y con la
-- parte de arriba volcada hacia la sala (`hacia`). Si con eso una esquina se mete en el suelo, sube lo justo: la hoja
-- se apoya en esa esquina. `extra`, grados de más hacia la sala (el balanceo).
function PuertaRotaVista.colgada(bisagra: CFrame, hojaRel: CFrame, tam: Vector3, giro: number, hacia: Vector3,
	extra: number?): CFrame
	local c = P.Colgada
	local apoyo = CFrame.new(0, hojaRel.Y * 2 * c.Bisagra, 0) -- la bisagra de abajo, en la bisagra cerrada
	local cf = bisagra * CFrame.Angles(0, math.rad((c.Giro + (extra or 0)) * giro), 0)
	cf = cf * apoyo * CFrame.Angles(0, 0, -math.rad(c.Ladeo)) * apoyo:Inverse() -- el lado de la cerradura (+X) baja
	local arriba = hojaRel * Vector3.new(0, tam.Y / 2, 0)
	local volcada = cf * apoyo * CFrame.Angles(math.rad(c.Vuelco), 0, 0) * apoyo:Inverse()
	if (volcada * arriba - cf * arriba):Dot(hacia) < 0 then
		volcada = cf * apoyo * CFrame.Angles(-math.rad(c.Vuelco), 0, 0) * apoyo:Inverse()
	end
	cf = volcada
	local suelo = bisagra.Position.Y + 0.02
	local bajo = math.huge
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				bajo = math.min(bajo, (cf * hojaRel * Vector3.new(sx * tam.X / 2, sy * tam.Y / 2, sz * tam.Z / 2)).Y)
			end
		end
	end
	if bajo < suelo then
		cf = CFrame.new(0, suelo - bajo, 0) * cf
	end
	return cf
end

---------------------------------------------------------------- cada puerta

type Astilla = { p: BasePart, nace: number, quieta: boolean }
type Trozo = { x: number, ancho: number, yc: number, alto: number } -- el que cede, en la hoja (studs desde su centro)
type Pieza = { parte: BasePart, rel: CFrame }
type Estado = {
	d: Puerta,
	etapa: number,
	hacia: Vector3,
	sala: number, -- 1 o -1: hacia qué cara de la hoja (su Z) está la sala
	suelo: number,
	trozos: { Trozo }, -- los dos que ceden (siempre los mismos en cada cliente: azar con la posición de la puerta)
	tablas: { Pieza }, -- las de la hoja partida (también en d.piezas); vacía = hoja entera
	medios: { Pieza }, -- los trozos que han cedido (en orden)
	astillas: { Astilla },
	picos: { BasePart },
	pomo: BasePart?, -- el que sale rodando
	pomoT: number,
	hojaT: number,
	cf: CFrame?, -- donde está colgada ahora (nil = gira como siempre)
	meta: CFrame?, -- donde se queda colgada
	anim: { tipo: string, desde: CFrame, t0: number }?,
}
local estados: { [Model]: Estado } = {}
local carpeta: Folder
local conexion: RBXScriptConnection? = nil
local crujidos: { [Instance]: Vector3 } = setmetatable({}, { __mode = "k" }) :: any -- quién → dónde crujió por última vez
local ultimaMirada = 0

local function grupo(): string
	-- Las sueltas no chocan con los jugadores (grupo "Cargado", lo registra el servidor en Cargar).
	local ok, si = pcall(PhysicsService.IsCollisionGroupRegistered, PhysicsService, "Cargado")
	return if ok and si then "Cargado" else "Default"
end

local function nueva(clase: string, tam: Vector3, cf: CFrame, color: Color3): BasePart
	local p = Instance.new(clase) :: BasePart
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Wood
	p.Color = color
	p.Size = tam
	p.CFrame = cf
	p.Parent = carpeta
	return p
end

local function tono(c: Color3, k: number): Color3
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

local function rango(r: { number }): number
	return azar:NextNumber(r[1], r[2])
end

local function quitarPieza(e: Estado, pz: Pieza)
	local i = table.find(e.d.piezas, pz)
	if i then
		table.remove(e.d.piezas, i)
	end
end

-- Vuelve a poner la hoja (y lo que va con ella) donde toca ahora.
local function recolocar(e: Estado)
	e.d.colgar(e.cf)
end

local function activar()
	if conexion then
		return
	end
	conexion = RunService.Heartbeat:Connect(function()
		PuertaRotaVista.paso()
	end)
end

-- Una pieza suelta que sale volando con física local (astilla, trozo de tabla); se ancla al pararse.
local function soltar(e: Estado, p: BasePart, v: Vector3)
	p.Anchored = false
	p.CanCollide = true
	p.CollisionGroup = grupo()
	p.AssemblyLinearVelocity = v
	p.AssemblyAngularVelocity = Vector3.new(azar:NextNumber(-18, 18), azar:NextNumber(-18, 18), azar:NextNumber(-18, 18))
	table.insert(e.astillas, { p = p, nace = os.clock(), quieta = false })
	activar()
end

-- La hoja se parte en tablas (la de verdad se esconde: sigue ahí para el servidor y para las marcas soldadas).
local function partir(e: Estado)
	local d = e.d
	local tam = d.hoja.Size
	local n = PuertaRotaVista.tablas(tam.X)
	local w = tam.X / n
	local base = e.cf or d.normal()
	local function tabla(x: number, y: number, ancho: number, alto: number, k: number): Pieza
		local rel = d.hojaRel * CFrame.new(x, y, 0)
		local p = nueva("Part", Vector3.new(ancho, alto, tam.Z), base * rel, tono(d.hoja.Color, k))
		p.Material = d.hoja.Material
		p.MaterialVariant = d.hoja.MaterialVariant
		p.CastShadow = true -- que la luz solo entre por la rendija
		local pz = { parte = p, rel = rel }
		table.insert(e.tablas, pz)
		table.insert(d.piezas, pz)
		return pz
	end
	for i = 1, n do
		local x = -tam.X / 2 + (i - 0.5) * w
		local k = 0.94 + ((i * 37) % 10) / 100 -- cada tabla, de un tono un poco distinto (igual en todos los clientes)
		local trozo: Trozo? = nil
		for _, t in e.trozos do
			if math.abs(t.x - x) < w / 2 then
				trozo = t
			end
		end
		if trozo then
			-- Tres trozos: abajo y arriba se quedan; el del medio es el que cede.
			local abajo = trozo.yc - trozo.alto / 2 + tam.Y / 2
			local arriba = tam.Y / 2 - (trozo.yc + trozo.alto / 2)
			tabla(x, -tam.Y / 2 + abajo / 2, w, abajo, k)
			tabla(x, tam.Y / 2 - arriba / 2, w, arriba, k)
			local medio = tabla(x, trozo.yc, w, trozo.alto * 0.94, k)
			medio.parte.Name = "Medio"
		else
			tabla(x, 0, w, tam.Y, k)
		end
	end
	e.hojaT = d.hoja.Transparency
	d.hoja.Transparency = 1
	recolocar(e)
end

-- Picos de madera clara en un borde partido de la tabla (`dir` 1 = hacia arriba, -1 = hacia abajo).
local function astillado(e: Estado, x: number, y: number, ancho: number, dir: number)
	local d = e.d
	for _, lado in { -0.25, 0.22 } do
		local largo = azar:NextNumber(0.2, 0.38)
		local rel = d.hojaRel * CFrame.new(x + ancho * lado, y + dir * largo / 2, 0)
			* CFrame.Angles(0, 0, math.rad(azar:NextNumber(-25, 25)))
		local p = nueva("Part", Vector3.new(0.09, largo, d.hoja.Size.Z * 0.6), (e.cf or d.normal()) * rel, MADERA_VIVA)
		local pz = { parte = p, rel = rel }
		table.insert(e.tablas, pz)
		table.insert(d.piezas, pz)
	end
end

-- Unas astillas que saltan desde un punto de la hoja hacia la sala.
local function astillas(e: Estado, desde: CFrame, cuantas: number, fuerza: number)
	for _ = 1, cuantas do
		local tabla = azar:NextNumber() < 0.35
		local tam = if tabla
			then Vector3.new(azar:NextNumber(0.35, 0.7), azar:NextNumber(0.1, 0.16), azar:NextNumber(0.6, 1.3))
			else Vector3.new(azar:NextNumber(0.07, 0.13), azar:NextNumber(0.06, 0.1), azar:NextNumber(0.4, 1.3))
		local cf = desde * CFrame.new(azar:NextNumber(-0.3, 0.3), azar:NextNumber(-0.5, 0.5), 0)
			* CFrame.Angles(azar:NextNumber(0, 6.3), azar:NextNumber(0, 6.3), azar:NextNumber(0, 6.3))
		local p = nueva(if tabla or azar:NextNumber() < 0.5 then "Part" else "WedgePart", tam, cf,
			if tabla then tono(e.d.hoja.Color, azar:NextNumber(0.85, 1)) else MADERA_VIVA)
		local lado = e.d.bisagra.XVector * azar:NextNumber(-3, 3)
		soltar(e, p, (e.hacia * rango(P.Salen) + lado + Vector3.new(0, azar:NextNumber(1, 5), 0)) * fuerza)
	end
end

-- Un trozo de tabla cede: se mete hacia dentro y deja la rendija.
local function ceder(e: Estado, k: number, vivo: boolean)
	if #e.tablas == 0 then
		if poco() then
			return -- con Rendimiento la hoja no se parte
		end
		partir(e)
	end
	local d = e.d
	local t = e.trozos[k]
	local medio: Pieza? = nil
	for _, pz in e.tablas do
		if pz.parte.Name == "Medio" and not table.find(e.medios, pz) then
			local x = (d.hojaRel:Inverse() * pz.rel).X
			if math.abs(x - t.x) < 1e-3 then
				medio = pz
			end
		end
	end
	if not medio then
		return
	end
	table.insert(e.medios, medio)
	medio.rel = d.hojaRel * CFrame.new(t.x, t.yc, e.sala * P.Metido)
		* CFrame.Angles(math.rad(azar:NextNumber(-14, 14)), math.rad(azar:NextNumber(-18, 18)), math.rad(azar:NextNumber(-8, 8)))
	-- Los bordes partidos de lo que queda, astillados.
	astillado(e, t.x, t.yc - t.alto / 2, t.ancho, 1)
	astillado(e, t.x, t.yc + t.alto / 2, t.ancho, -1)
	recolocar(e)
	if vivo then
		local donde = (e.cf or d.normal()) * d.hojaRel * CFrame.new(t.x, t.yc, e.sala * (d.hoja.Size.Z / 2 + 0.15))
		local s = Sonido.en("Crujido", donde.Position, azar:NextNumber(0.75, 0.9))
		s.Volume *= 1.2
		astillas(e, donde, if poco() then 1 else 3, 0.5)
		CasaVista.polvo(donde, Vector3.new(t.ancho, 0.2, 0.2), 8)
	end
end

-- Picos de madera en el marco del lado de la cerradura, a la altura del pomo.
local function picos(e: Estado)
	local d = e.d
	local ancho = d.el:GetAttribute("Ancho") or d.hoja.Size.X + 0.2
	local n = azar:NextInteger(P.Picos[1], P.Picos[2])
	for _ = 1, n do
		local largo = azar:NextNumber(0.35, 0.85)
		local cf = d.bisagra * CFrame.new(ancho - largo / 2 + 0.06, d.pomoRel.Y + azar:NextNumber(-1.3, 1.1),
			azar:NextNumber(-0.12, 0.12)) * CFrame.Angles(0, math.pi / 2, 0)
			* CFrame.Angles(azar:NextNumber(-0.35, 0.35), azar:NextNumber(-0.3, 0.3), if azar:NextNumber() < 0.5 then 0 else math.pi)
		table.insert(e.picos, nueva("WedgePart", Vector3.new(azar:NextNumber(0.08, 0.16), azar:NextNumber(0.15, 0.32), largo),
			cf, MADERA_VIVA))
	end
end

-- Echada abajo.
local function reventar(e: Estado, vivo: boolean)
	local d = e.d
	local fuerza = if vivo then 1 else 0.15
	-- Los trozos metidos salen volando.
	for _, pz in e.medios do
		quitarPieza(e, pz)
		local i = table.find(e.tablas, pz)
		if i then
			table.remove(e.tablas, i)
		end
		soltar(e, pz.parte, (e.hacia * rango(P.Salen) * 0.7 + Vector3.new(0, 2, 0)) * fuerza)
	end
	table.clear(e.medios)
	-- Astillas y trozos de tabla desde el lado de la cerradura.
	local tam = d.hoja.Size
	local cuantas = if poco() then P.AstillasPoco else azar:NextInteger(P.Astillas[1], P.Astillas[2])
	local base = (e.cf or d.normal()) * d.hojaRel
	for _ = 1, cuantas do
		astillas(e, base * CFrame.new(azar:NextNumber(0, tam.X / 2), azar:NextNumber(-tam.Y * 0.3, tam.Y * 0.3),
			e.sala * (tam.Z / 2 + 0.2)), 1, fuerza)
	end
	picos(e)
	-- El pomo sale rodando.
	if not poco() and not e.pomo then
		local pomo = nueva("Part", Vector3.new(0.55, 0.3, 0.3), d.pomo.CFrame * CFrame.Angles(0, math.pi / 2, 0),
			d.pomo.Color) :: Part
		pomo.Name = "Pomo"
		pomo.Shape = Enum.PartType.Cylinder
		pomo.Material = d.pomo.Material
		e.pomo = pomo
		e.pomoT = d.pomo.Transparency
		d.pomo.Transparency = 1
		soltar(e, pomo, (e.hacia * azar:NextNumber(4, 7) + d.bisagra.XVector * azar:NextNumber(-2, 2)
			+ Vector3.new(0, 3, 0)) * fuerza)
	end
	-- La hoja se queda colgando.
	e.meta = PuertaRotaVista.colgada(d.bisagra, d.hojaRel, tam, d.giro, e.hacia)
	if vivo then
		e.anim = { tipo = "cae", desde = e.cf or d.normal(), t0 = os.clock() }
		-- Ya mandamos nosotros: CasaVista la abre a la vez (Abierta), y sin esto se vería abierta un fotograma.
		e.cf = e.anim.desde
		recolocar(e)
		activar()
		local donde = d.hoja.Position
		local s = Sonido.en("Crujido", donde, azar:NextNumber(0.6, 0.7))
		s.Volume *= 1.5
		Sonido.en("Golpe", donde, azar:NextNumber(0.55, 0.65))
		CasaVista.temblar(donde, 0.8)
		local alto = d.hojaRel.Y * 2
		CasaVista.polvo(d.bisagra * CFrame.new(tam.X / 2, alto + 0.15, 0), Vector3.new(tam.X, 0.1, 0.4), P.Polvo)
		local alGolpe = CasaVista.alGolpe
		if alGolpe then
			alGolpe(donde)
		end
	else
		e.anim = nil
		e.cf = e.meta
		recolocar(e)
	end
end

-- Reparada: se recogen las astillas y la hoja vuelve a su sitio, entera.
local function reparar(e: Estado, vivo: boolean)
	local d = e.d
	local sueltas: { BasePart } = table.clone(e.picos)
	for _, a in e.astillas do
		table.insert(sueltas, a.p)
	end
	if e.pomo then -- (el que rueda está entre las astillas)
		d.pomo.Transparency = e.pomoT
		e.pomo = nil
	end
	for _, p in sueltas do
		p.Anchored = true
		p.CanCollide = false
		if vivo then
			TweenService:Create(p, TweenInfo.new(0.6), { Transparency = 1 }):Play()
			task.delay(0.65, p.Destroy, p)
		else
			p:Destroy()
		end
	end
	table.clear(e.astillas)
	table.clear(e.picos)
	for _, pz in e.tablas do
		quitarPieza(e, pz)
		pz.parte:Destroy()
	end
	if #e.tablas > 0 then
		d.hoja.Transparency = e.hojaT
	end
	table.clear(e.tablas)
	table.clear(e.medios)
	e.meta = nil
	if e.cf and vivo then
		e.anim = { tipo = "vuelve", desde = e.cf, t0 = os.clock() }
		activar()
	else
		e.anim = nil
		e.cf = nil
		recolocar(e)
	end
	e.etapa = 0
end

local function ir(e: Estado, n: number, vivo: boolean)
	if n == e.etapa then
		return
	end
	if n < e.etapa then
		reparar(e, vivo and n == 0)
		vivo = false -- vuelve a como estaba sin ruido (solo si baja sin llegar a llena: la vida máxima ha cambiado)
	end
	for k = e.etapa + 1, n do
		if k <= 2 then
			ceder(e, k, vivo)
		else
			reventar(e, vivo)
		end
	end
	e.etapa = n
end

local function vigilar(d: Puerta)
	local el = d.el
	if estados[el] then
		return
	end
	local hacia = el:GetAttribute("Hacia")
	hacia = if typeof(hacia) == "Vector3" and hacia.Magnitude > 1e-3 then hacia.Unit else d.bisagra.ZVector
	-- Los trozos que ceden, siempre los mismos en todos los clientes (azar con la posición de la puerta).
	local pos = d.bisagra.Position
	local suyo = Random.new(math.floor(math.abs(pos.X) * 31 + math.abs(pos.Z) * 17 + math.abs(pos.Y) * 7) % 1048576 + 1)
	local tam = d.hoja.Size
	local n = PuertaRotaVista.tablas(tam.X)
	local w = tam.X / n
	local libres: { number } = {} -- ni la de la bisagra ni la del pomo (si hay tablas de sobra)
	for i = (if n >= 4 then 2 else 1), (if n >= 4 then n - 1 else n) do
		table.insert(libres, i)
	end
	local trozos: { Trozo } = {}
	for _ = 1, 2 do
		local i = table.remove(libres, suyo:NextInteger(1, #libres)) :: number
		local alto = tam.Y * suyo:NextNumber(P.Hueco[1], P.Hueco[2])
		table.insert(trozos, { x = -tam.X / 2 + (i - 0.5) * w, ancho = w, yc = tam.Y * suyo:NextNumber(-0.12, 0.18), alto = alto })
	end
	local e: Estado = {
		d = d, etapa = 0, hacia = hacia, sala = if (d.bisagra * d.hojaRel).ZVector:Dot(hacia) > 0 then 1 else -1,
		suelo = pos.Y, trozos = trozos, tablas = {}, medios = {}, astillas = {}, picos = {}, pomo = nil, pomoT = 0,
		hojaT = 0, cf = nil, meta = nil, anim = nil,
	}
	estados[el] = e
	local function mirar(vivo: boolean)
		ir(e, PuertaRotaVista.etapa(el:GetAttribute("Vida") or 1, el:GetAttribute("VidaMax") or 1), vivo)
	end
	el:GetAttributeChangedSignal("Vida"):Connect(function()
		mirar(true)
	end)
	el:GetAttributeChangedSignal("VidaMax"):Connect(function()
		mirar(true)
	end)
	mirar(false) -- al llegar (o al entrar tarde): como esté, sin ruido
	el.Destroying:Once(function()
		reparar(e, false)
		estados[el] = nil
	end)
end

---------------------------------------------------------------- el bucle

-- Las astillas crujen al pisarlas (jugadores y bichos), solo cerca de la cámara.
local function crujir(p: BasePart, fuerza: number)
	local s = Sonido.en("Cruje", p.Position, azar:NextNumber(1.25, 1.5))
	s.Volume *= 0.3 * fuerza
	task.delay(0.3, function()
		if s.Parent then
			TweenService:Create(s, TweenInfo.new(0.12), { Volume = 0 }):Play()
		end
	end)
	p.CFrame *= CFrame.new(azar:NextNumber(-0.06, 0.06), 0, azar:NextNumber(-0.06, 0.06))
		* CFrame.Angles(0, azar:NextNumber(-0.5, 0.5), 0)
end

local cerca: { Estado } = {}
local function pisa(quien: Instance, pies: Vector3, fuerza: number)
	for _, e in cerca do
		for _, a in e.astillas do
			local d = a.p.Position
			if a.quieta and a.p.Name ~= "Pomo" and math.abs(d.Y - pies.Y) < 1.6
				and Vector2.new(d.X - pies.X, d.Z - pies.Z).Magnitude < P.Pisar then
				local ultimo = crujidos[quien]
				if not ultimo or (pies - ultimo).Magnitude > P.CadaCrujido then
					crujidos[quien] = pies
					crujir(a.p, fuerza)
				end
				return
			end
		end
	end
end

local function pisadas(camara: Vector3)
	table.clear(cerca)
	for _, e in estados do
		if #e.astillas > 0 and (e.d.hoja.Position - camara).Magnitude <= P.Cerca then
			table.insert(cerca, e)
		end
	end
	if #cerca == 0 then
		return
	end
	for _, j in Players:GetPlayers() do
		local personaje = j.Character
		local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humano = personaje and personaje:FindFirstChildOfClass("Humanoid")
		if personaje and raiz and humano and humano.Health > 0 then
			pisa(personaje, raiz.Position - Vector3.new(0, humano.HipHeight + raiz.Size.Y / 2, 0), 1)
		end
	end
	local bichos = workspace:FindFirstChild("Bichos")
	if bichos then
		for _, b in bichos:GetChildren() do
			local raiz = b:FindFirstChild("HumanoidRootPart") :: BasePart?
			local datos = Config.Efectos.Bichos[b.Name]
			if raiz and datos then
				pisa(b, raiz.Position - Vector3.new(0, datos.Pies, 0), 1.5)
			end
		end
	end
end

-- Un fotograma (lo llama el Heartbeat; el banco, a mano).
function PuertaRotaVista.paso()
	local ahora = os.clock()
	local queda = false -- algo que mover (si no, y sin astillas, se suelta el Heartbeat)
	local hayAstillas = false
	for _, e in estados do
		local d = e.d
		local anim = e.anim
		if anim then
			queda = true
			if anim.tipo == "cae" and e.meta then
				local t = (ahora - anim.t0) / P.Caida
				if t < 1 then
					e.cf = anim.desde:Lerp(e.meta, PuertaRotaVista.rebote(t))
				else
					local m = PuertaRotaVista.mecer(ahora - anim.t0 - P.Caida)
					if m == 0 then
						e.cf = e.meta
						e.anim = nil
					else
						e.cf = PuertaRotaVista.colgada(d.bisagra, d.hojaRel, d.hoja.Size, d.giro, e.hacia, m)
					end
				end
			else -- vuelve a su sitio
				local t = math.clamp((ahora - anim.t0) / P.Vuelve, 0, 1)
				e.cf = anim.desde:Lerp(d.normal(), 1 - (1 - t) * (1 - t))
				if t >= 1 then
					e.cf = nil
					e.anim = nil
				end
			end
			recolocar(e)
		end
		-- Las sueltas: quietas (o como mucho al doble de tiempo), se anclan; las que se han ido por un hueco, fuera.
		for i = #e.astillas, 1, -1 do
			local a = e.astillas[i]
			if not a.quieta then
				queda = true
				local edad = ahora - a.nace
				if a.p.Position.Y < e.suelo - 4 or not a.p.Parent then
					a.p:Destroy()
					table.remove(e.astillas, i)
				elseif edad >= P.Anclar and (a.p.AssemblyLinearVelocity.Magnitude < 1.5 or edad >= P.Anclar * 2) then
					a.quieta = true
					a.p.Anchored = true
					a.p.CanCollide = false
				end
			end
		end
		hayAstillas = hayAstillas or #e.astillas > 0
	end
	if hayAstillas and ahora - ultimaMirada >= 0.1 then
		ultimaMirada = ahora
		pisadas(workspace.CurrentCamera.CFrame.Position)
	end
	if not queda and not hayAstillas and conexion then
		conexion:Disconnect()
		conexion = nil
	end
end

-- Para el banco: las astillas sueltas de una puerta.
function PuertaRotaVista.astillasDe(el: Model): { BasePart }
	local l = {}
	local e = estados[el]
	for _, a in if e then e.astillas else {} do
		table.insert(l, a.p)
	end
	return l
end

function PuertaRotaVista.start()
	carpeta = Instance.new("Folder")
	carpeta.Name = "PuertasRotas"
	carpeta.Parent = workspace
	CasaVista.alPuerta(vigilar)
end

return PuertaRotaVista
