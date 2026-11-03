-- Los escondites vistos desde fuera (pedido por el usuario: "ver a los demás jugadores esconderse y salir (la puerta
-- del armario)"). Cuando alguien se mete en un armario o una cama, o sale (atributo Ocupado del escondite, que pone
-- juego/servidor/Muerte a la vez que el Escondido del jugador), este cliente lo anima:
--   Armario: sus dos puertas de lamas se abren hacia fuera y se cierran detrás de él, con el sonido de una puerta,
--     más flojo y agudo. En el mapa las lamas van de lado a lado (Mapa, armario): mientras se mueve, las de verdad se
--     esconden y giran dos hojas hechas aquí (cada lama partida en dos, con sus largueros y su tirador).
--   Cama: la colcha se levanta por el lado por el que se mete o sale y vuelve a caer, con un crujido de madera.
--   Si le saca un bicho, las puertas se abren de golpe (la colcha, de un tirón) y al rato se cierran solas, crujiendo.
-- El que entra o sale no se ve saltar (el servidor le mueve de golpe): se esconde un momento y vuelve a verse dentro,
-- con la puerta a medio cerrar (o fuera, con ella abierta). Tu escondite se anima igual (tu cuerpo y la cámara los
-- lleva MuerteVista). Solo cerca de la cámara (el tuyo, siempre) y en un solo bucle que solo corre mientras algo se
-- mueve. Con Rendimiento, solo el tuyo: de los demás, el sonido.
-- En Studio, sin otro jugador (datamodel Client), anima el escondite más cerca de la cámara como si alguien entrara,
-- saliera o le sacaran ("Entrar", "Salir" o "Sacado"):
--   game.Players.LocalPlayer.PlayerScripts:FindFirstChild("EsconditeVista", true).Probar:Fire("Entrar")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Sonido = require(script.Parent.Sonido)

local EsconditeVista = {}

-- Números a ojo (para mirarlos en Studio).
local CERCA = 60 -- studs: más lejos de la cámara no se anima ni suena (los sonidos se oyen hasta 40-50)
local ABRE = 80 -- grados que se abre cada puerta del armario
local DE_GOLPE = 1.25 -- veces ABRE al abrirse de golpe: pasa del tope, rebota y se queda en ABRE
local HUECO = 0.02 -- studs entre las dos hojas
local LARGUERO = 0.12 -- ancho de los largueros de cada hoja (solo con la puerta abierta: cerrada no los hay)
local LEVANTA = 0.35 -- studs que sube la colcha por el lado por el que se mete o sale
local DUDA = 0.1 -- s que espera al salir, para saber si sale o le sacan (Muerto llega a la vez o justo detrás)

-- Cuándo pasa cada cosa (s desde que empieza): la puerta acaba de abrirse en `abre`, empieza a cerrarse en `espera`,
-- encaja en `cierra` y rebota un poco hasta `cierra + rebote`. `ver` = cuándo vuelve a verse el que entra o sale (de
-- escondido a visible). Sonidos: { en qué s, cuál, tono, volumen (por el suyo de Config.Sonidos) }.
type Sonidos = { { any } }
type Fases = {
	abre: number,
	espera: number,
	cierra: number,
	rebote: number,
	tope: number,
	ver: { number }?,
	sonidos: Sonidos,
}
local PUERTA: { [string]: Fases } = {
	-- Al meterse tú, la cámara cruza la puerta hacia los 0,3 s y llega dentro a los 0,5 (MuerteVista): ya está abierta.
	Entrar = { abre = 0.2, espera = 0.48, cierra = 0.95, rebote = 0.15, tope = 1, ver = { 0.55, 0.85 },
		sonidos = { { 0, "Puerta", 1.15, 0.5 }, { 0.9, "PuertaCierra", 1.15, 0.5 } } },
	Salir = { abre = 0.22, espera = 0.55, cierra = 1.15, rebote = 0.15, tope = 1, ver = { 0.08, 0.3 },
		sonidos = { { 0, "Puerta", 1.15, 0.5 }, { 1.1, "PuertaCierra", 1.15, 0.5 } } },
	Sacado = { abre = 0.12, espera = 2.8, cierra = 4.4, rebote = 0.2, tope = DE_GOLPE,
		sonidos = { { 0, "Puerta", 0.8, 1 }, { 2.8, "Cruje", 1.1, 0.6 }, { 4.35, "PuertaCierra", 1, 0.35 } } },
}
-- La colcha: sube hasta `sube` (`tope` = veces LEVANTA) y vuelve a caer hasta `fin`.
type Sacudida = { sube: number, fin: number, tope: number, ver: { number }?, sonidos: Sonidos }
local COLCHA: { [string]: Sacudida } = {
	Entrar = { sube = 0.25, fin = 0.95, tope = 1, ver = { 0.35, 0.65 }, sonidos = { { 0, "Cruje", 1.25, 0.5 } } },
	Salir = { sube = 0.2, fin = 0.85, tope = 1, ver = { 0.1, 0.3 }, sonidos = { { 0, "Cruje", 1.3, 0.5 } } },
	Sacado = { sube = 0.1, fin = 1.6, tope = 2.2, sonidos = { { 0, "Cruje", 0.95, 0.9 } } },
}
-- La colcha de cada cama: la malla de Blender ("Blanket", dentro del modelo del escondite) o la del mueble de la tienda
-- (ServerStorage.Muebles), que cuelga de la casa al lado del escondite: [modelo] = la pieza que es la colcha.
local COLCHAS = { ColchaCama = "ColchaCama_2", ColchaDosel = "ColchaDosel", CamaNino = "CamaNino_2" }

type Anim = {
	tipo: string, -- "Entrar", "Salir" o "Sacado"
	inicio: number,
	desde: number, -- cómo estaba la puerta (o la colcha) al empezar
	mover: boolean, -- false: solo el sonido y el cuerpo (con Rendimiento, el escondite de otro)
	cuerpo: { Instance }?, -- las piezas del que entra o sale, escondidas hasta `ver`
	k: number, -- su LocalTransparencyModifier ahora
	sonado: number, -- cuántos sonidos han sonado ya
}

type Sitio = {
	modelo: Model,
	cama: boolean,
	listo: boolean, -- ya se han buscado sus piezas
	donde: Vector3, -- de dónde sale el sonido (y la distancia a la cámara)
	ocupante: number,
	valor: number, -- cuánto está abierta la puerta (o levantada la colcha) ahora
	anim: Anim?,
	-- Armario
	lamas: { BasePart }, -- las de verdad
	sombra: boolean, -- si las de verdad dan sombra (escondidas no)
	tiradores: BasePart?, -- la malla con los dos tiradores (Mapa le pone ArmarioMarco)
	sombraTiradores: boolean,
	hojas: { BasePart }, -- las piezas de las dos hojas de aquí
	lados: { number }, -- de qué hoja es cada pieza (-1 o 1)
	rel: { CFrame }, -- cada pieza vista desde su bisagra
	cfs: { CFrame }, -- (para no hacer una tabla nueva en cada fotograma)
	largueros: { BasePart },
	bisagraIzq: CFrame,
	bisagraDer: CFrame,
	fuera: boolean, -- las hojas están puestas (y las lamas de verdad, escondidas)
	conLargueros: boolean,
	-- Cama
	colcha: BasePart?,
	colchaCF: CFrame, -- dónde está quieta
	colchaRel: CFrame, -- la colcha vista desde el colchón
	base: CFrame, -- el colchón: X a lo ancho, Z a lo largo
	lado: number, -- por dónde se sale (1 o -1, en la X del colchón)
	pivote: CFrame, -- el borde de la colcha del otro lado, por donde gira
	giro: number, -- radianes que gira con la colcha levantada del todo (1)
	conexion: RBXScriptConnection?, -- la de su atributo Ocupado (se suelta si el escondite se va con el streaming)
}

local jugador = Players.LocalPlayer
local sitios: { [Instance]: Sitio } = {}
local activos: { [Sitio]: boolean } = {}
local bucle: RBXScriptConnection? = nil

local function suave(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

local function enCamara(s: Sitio): number
	return (workspace.CurrentCamera.CFrame.Position - s.donde).Magnitude
end

-- ===== Las piezas de cada escondite (se buscan la primera vez que hacen falta) =====

local function sitioDelMando(s: Sitio)
	local mando = s.modelo:FindFirstChild("Mando")
	s.donde = if mando and mando:IsA("BasePart") then mando.Position else s.modelo:GetPivot().Position
end

-- Pieza de una hoja, con el aspecto de `como` (la lama o el tirador de verdad). Solo se ve: no choca ni tapa rayos.
local function pieza(s: Sitio, como: BasePart, tamano: Vector3, lado: number, cf: CFrame): BasePart
	local p = Instance.new("Part")
	p.Name = "HojaArmario"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = tamano
	p.Color = como.Color
	p.Material = como.Material
	p.MaterialVariant = como.MaterialVariant
	p.Reflectance = como.Reflectance
	p.CastShadow = como.CastShadow
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = cf
	table.insert(s.hojas, p)
	table.insert(s.lados, lado)
	table.insert(s.rel, (if lado < 0 then s.bisagraIzq else s.bisagraDer):ToObjectSpace(cf))
	table.insert(s.cfs, cf)
	return p
end

-- Armario: las lamas de la puerta (Mapa: 19 de 4 × 0,25 × 0,12, de lado a lado) y dos hojas que se abren desde los
-- costados (bisagras en los bordes de las lamas), cada una con la mitad de cada lama.
local function prepararArmario(s: Sitio)
	local lamas = {}
	for _, p in s.modelo:GetChildren() do
		if p:IsA("BasePart") and p.Name == "Armario" and p.Size.Z < 0.2 and p.Size.Y < 0.28 and p.Size.X > 2 then
			table.insert(lamas, p)
		end
	end
	if #lamas < 3 then
		sitioDelMando(s) -- sin lamas (otro armario): solo suena
		return
	end
	s.listo = true
	local suma = Vector3.zero
	for _, l in lamas do
		suma += l.Position
	end
	-- La puerta: en el centro de las lamas, con sus ejes (-Z hacia fuera, X a lo ancho).
	local puerta = CFrame.new(suma / #lamas) * lamas[1].CFrame.Rotation
	local abajo, arriba = math.huge, -math.huge
	for _, l in lamas do
		local y = puerta:PointToObjectSpace(l.Position).Y
		abajo = math.min(abajo, y - l.Size.Y / 2)
		arriba = math.max(arriba, y + l.Size.Y / 2)
	end
	s.donde = puerta.Position
	s.lamas = lamas
	s.sombra = lamas[1].CastShadow
	local molde = lamas[1]
	local ancho, grueso = molde.Size.X, molde.Size.Z
	local mitad = (ancho - HUECO) / 2
	s.bisagraIzq = puerta * CFrame.new(-ancho / 2, 0, 0)
	s.bisagraDer = puerta * CFrame.new(ancho / 2, 0, 0)
	for _, lado in { -1, 1 } do
		for _, l in lamas do
			local y = puerta:PointToObjectSpace(l.Position).Y
			pieza(s, l, Vector3.new(mitad, l.Size.Y, l.Size.Z), lado, puerta * CFrame.new(lado * (HUECO + mitad) / 2, y, 0))
		end
		-- Un larguero en la bisagra y otro en el borde que se junta con la otra hoja.
		for _, borde in { ancho / 2 - LARGUERO / 2, HUECO / 2 + LARGUERO / 2 } do
			local larguero = pieza(s, molde, Vector3.new(LARGUERO, arriba - abajo, grueso + 0.04), lado,
				puerta * CFrame.new(lado * borde, (arriba + abajo) / 2, 0))
			larguero.Transparency = 1
			table.insert(s.largueros, larguero)
		end
	end
	-- Los tiradores (una sola malla con los dos, de sección cuadrada): uno en cada hoja, donde estaban.
	local tiradores = s.modelo:FindFirstChild("Metal")
	if tiradores and tiradores:IsA("BasePart") then
		local barra = tiradores.Size.Z
		local a = puerta:PointToObjectSpace((tiradores.CFrame * CFrame.new(-(tiradores.Size.X - barra) / 2, 0, 0)).Position)
		local b = puerta:PointToObjectSpace((tiradores.CFrame * CFrame.new((tiradores.Size.X - barra) / 2, 0, 0)).Position)
		if a.X * b.X < 0 then -- uno a cada lado del centro (si no, la malla es otra: se queda quieta)
			s.tiradores = tiradores
			s.sombraTiradores = tiradores.CastShadow
			for _, p in { a, b } do
				pieza(s, tiradores, Vector3.new(barra, tiradores.Size.Y, barra), if p.X < 0 then -1 else 1, puerta * CFrame.new(p))
			end
		end
	end
end

-- Cama: el colchón (bloque de Mapa, aunque se vea el mueble) da los ejes, y la colcha gira un poco por el borde del
-- otro lado, de modo que el lado de la salida sube LEVANTA.
local function prepararCama(s: Sitio)
	local colchon = s.modelo:FindFirstChild("Colchon")
	if not (colchon and colchon:IsA("BasePart")) then
		sitioDelMando(s)
		return
	end
	s.donde = colchon.Position
	s.base = colchon.CFrame
	local salida = s.modelo:GetAttribute("Salida")
	local haciaSalida = if typeof(salida) == "CFrame" then salida.Position - colchon.Position else Vector3.zero
	s.lado = if haciaSalida:Dot(colchon.CFrame.RightVector) < 0 then -1 else 1
	local ancho = colchon.Size.X / 2
	s.pivote = CFrame.new(-s.lado * ancho, colchon.Size.Y / 2, 0)
	s.giro = LEVANTA / (2 * ancho)
	local colcha: BasePart? = nil
	local blanket = s.modelo:FindFirstChild("Blanket")
	if blanket and blanket:IsA("BasePart") then
		colcha = blanket
	else
		local mejor = 4.5 -- studs (en planta) desde el centro del colchón
		for _, m in (if s.modelo.Parent then s.modelo.Parent:GetChildren() else {}) do
			local nombre = COLCHAS[m.Name]
			local p = nombre and m:FindFirstChild(nombre, true)
			if p and p:IsA("BasePart") then
				local d = ((p.Position - colchon.Position) * Vector3.new(1, 0, 1)).Magnitude
				if d < mejor then
					colcha, mejor = p, d
				end
			end
		end
	end
	if colcha then
		s.listo = true
		s.colcha = colcha
		s.colchaCF = colcha.CFrame
		s.colchaRel = s.base:ToObjectSpace(colcha.CFrame)
	end
end

local function preparar(s: Sitio)
	if not s.listo then
		if s.cama then
			prepararCama(s)
		else
			prepararArmario(s)
		end
	end
end

-- ===== Mover =====

-- Las hojas en su sitio de cerradas y las lamas de verdad escondidas (o al revés): se ven igual, no se nota el cambio.
-- Escondidas tampoco dan sombra (con LocalTransparencyModifier aún la darían: la de la puerta cerrada).
local function sacarHojas(s: Sitio, sacar: boolean)
	s.fuera = sacar
	for _, l in s.lamas do
		l.LocalTransparencyModifier = if sacar then 1 else 0
		l.CastShadow = not sacar and s.sombra
	end
	local tiradores = s.tiradores
	if tiradores then
		tiradores.LocalTransparencyModifier = if sacar then 1 else 0
		tiradores.CastShadow = not sacar and s.sombraTiradores
	end
	for _, p in s.hojas do
		p.Parent = if sacar then s.modelo else nil
	end
end

local function colocarArmario(s: Sitio, a: number)
	local angulo = math.rad(ABRE * a)
	-- Las dos hacia fuera (-Z de la puerta): la izquierda gira a un lado y la derecha al otro.
	local izq = s.bisagraIzq * CFrame.Angles(0, angulo, 0)
	local der = s.bisagraDer * CFrame.Angles(0, -angulo, 0)
	for i, rel in s.rel do
		s.cfs[i] = (if s.lados[i] < 0 then izq else der) * rel
	end
	workspace:BulkMoveTo(s.hojas, s.cfs, Enum.BulkMoveMode.FireCFrameChanged)
	local largueros = a > 0.06 -- cerrada no se ven (las de verdad no tienen): que no se note el cambio
	if largueros ~= s.conLargueros then
		s.conLargueros = largueros
		for _, l in s.largueros do
			l.Transparency = if largueros then 0 else 1
		end
	end
end

local function colocarColcha(s: Sitio, b: number)
	local colcha = s.colcha
	if colcha then
		colcha.CFrame = s.base * s.pivote * CFrame.Angles(0, 0, s.lado * s.giro * b) * s.pivote:Inverse() * s.colchaRel
	end
end

-- Cuánto está abierta la puerta a los `t` s (0 cerrada, 1 = ABRE).
local function abierta(f: Fases, t: number, desde: number): number
	if t < f.abre then
		local k = t / f.abre
		return desde + (f.tope - desde) * (1 - (1 - k) * (1 - k)) -- sale deprisa y frena
	end
	-- De golpe pasa del tope y rebota hasta quedarse abierta del todo (sin golpe, se queda en 1).
	local u = math.min(t, f.espera) - f.abre
	local quieta = 1 + (f.tope - 1) * math.exp(-u * 6) * math.cos(u * 14)
	if t < f.espera then
		return quieta
	elseif t < f.cierra then
		return quieta * (1 - suave((t - f.espera) / (f.cierra - f.espera)))
	elseif t < f.cierra + f.rebote then
		return 0.04 * math.sin(math.pi * (t - f.cierra) / f.rebote) -- rebota un poco al encajar
	end
	return 0
end

-- Cuánto está levantada la colcha a los `t` s (0 en su sitio, 1 = LEVANTA).
local function levantada(m: Sacudida, t: number, desde: number): number
	if t < m.sube then
		local k = t / m.sube
		return desde + (m.tope - desde) * (1 - (1 - k) * (1 - k))
	elseif t < m.fin then
		return m.tope * (1 - suave((t - m.sube) / (m.fin - m.sube)))
	end
	return 0
end

-- ===== El que entra o sale =====

local function cuerpoDe(quien: Player): { Instance }
	local lista = {}
	local personaje = quien.Character
	for _, d in (if personaje then personaje:GetDescendants() else {}) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			table.insert(lista, d)
		end
	end
	return lista
end

-- `k` = su LocalTransparencyModifier (1 escondido, 0 a la vista). Solo hay piezas y calcomanías (cuerpoDe).
local function verCuerpo(lista: { Instance }, k: number)
	for _, d in lista do
		(d :: BasePart).LocalTransparencyModifier = k
	end
end

-- ===== El bucle (solo mientras se mueve algo) =====

-- Lo deja todo como estaba: el cuerpo a la vista (lo primero: que nadie se quede invisible), las lamas de verdad y la
-- colcha en su sitio.
local function terminar(s: Sitio)
	local a = s.anim
	s.anim = nil
	activos[s] = nil
	s.valor = 0
	if a and a.cuerpo then
		verCuerpo(a.cuerpo, 0)
	end
	-- Con el escondite ya borrado, sus hojas tampoco están (y no se pueden mover de sitio): da igual.
	pcall(function()
		if s.fuera then
			sacarHojas(s, false)
		end
		if s.colcha then
			s.colcha.CFrame = s.colchaCF -- justo donde estaba
		end
	end)
end

-- Un fotograma de un escondite: false cuando ya ha acabado.
local function avanzar(s: Sitio, ahora: number): boolean
	local a = s.anim
	if not a or not s.modelo.Parent then
		return false
	end
	local t = ahora - a.inicio
	local f: Fases | Sacudida = if s.cama then COLCHA[a.tipo] else PUERTA[a.tipo]
	while a.sonado < #f.sonidos and t >= f.sonidos[a.sonado + 1][1] do
		a.sonado += 1
		local son = f.sonidos[a.sonado]
		local sonido = Sonido.en(son[2], s.donde, son[3])
		sonido.Volume *= son[4]
	end
	local ver = f.ver
	if a.cuerpo and ver then
		local k = 1 - math.clamp((t - ver[1]) / (ver[2] - ver[1]), 0, 1)
		if k ~= a.k then
			a.k = k
			verCuerpo(a.cuerpo, k)
		end
	end
	if s.cama then
		local m = f :: Sacudida
		if a.mover and s.colcha then
			s.valor = levantada(m, t, a.desde)
			colocarColcha(s, s.valor)
		end
		return t < m.fin
	end
	local p = f :: Fases
	if a.mover and #s.hojas > 0 then
		if not s.fuera then
			sacarHojas(s, true)
		end
		s.valor = abierta(p, t, a.desde)
		colocarArmario(s, s.valor)
	end
	return t < p.cierra + p.rebote
end

local function paso()
	local ahora = os.clock()
	for s in activos do
		-- Si algo falla, ese escondite se deja como estaba: que no se quede nada a medias (ni nadie invisible).
		local ok, sigue = pcall(avanzar, s, ahora)
		if not ok then
			warn("[EsconditeVista] " .. tostring(sigue))
		end
		if not ok or not sigue then
			terminar(s)
		end
	end
	if next(activos) == nil and bucle then
		bucle:Disconnect()
		bucle = nil
	end
end

-- Empieza a moverse (si ya se movía, sigue desde donde estaba). `cuerpo`: el del que sale, ya escondido.
local function empezar(s: Sitio, tipo: string, quien: Player?, cuerpo: { Instance }?)
	local mio = quien ~= nil and quien == jugador
	if not mio and enCamara(s) > CERCA then
		if cuerpo then
			verCuerpo(cuerpo, 0)
		end
		return
	end
	local anterior = s.anim
	if anterior and anterior.cuerpo and anterior.cuerpo ~= cuerpo then
		verCuerpo(anterior.cuerpo, 0)
	end
	-- Tu cuerpo lo esconde MuerteVista; el de otro, aquí (el de un muerto, no: se le ve caer).
	if not cuerpo and quien and not mio and tipo ~= "Sacado" then
		cuerpo = cuerpoDe(quien)
	end
	if cuerpo then
		verCuerpo(cuerpo, 1)
	end
	s.anim = {
		tipo = tipo,
		inicio = os.clock(),
		desde = s.valor,
		mover = mio or jugador:GetAttribute("Rendimiento") ~= true, -- con Rendimiento, solo lo tuyo
		cuerpo = cuerpo,
		k = 1,
		sonado = 0,
	}
	activos[s] = true
	if not bucle then
		bucle = RunService.RenderStepped:Connect(paso)
	end
end

local function alCambiar(s: Sitio)
	local nuevo = s.modelo:GetAttribute("Ocupado")
	nuevo = if type(nuevo) == "number" then nuevo else 0
	local antes = s.ocupante
	s.ocupante = nuevo
	if nuevo == antes then
		return
	end
	preparar(s)
	if nuevo ~= 0 then
		local quien = Players:GetPlayerByUserId(nuevo)
		if quien then
			empezar(s, "Entrar", quien)
		end
		return
	end
	local quien = Players:GetPlayerByUserId(antes)
	if not quien then
		return -- se ha ido del juego: no sale nadie
	end
	-- ¿Sale o le saca un bicho? Mientras se sabe, que no se le vea saltar fuera.
	local mio = quien == jugador
	local cuerpo = if not mio and enCamara(s) <= CERCA and not quien:GetAttribute("Muerto") then cuerpoDe(quien) else nil
	if cuerpo then
		local anterior = s.anim
		if anterior and anterior.cuerpo then
			-- Si aún se estaba metiendo, su cuerpo lo lleva ya esta salida (que no vuelva a verse mientras se sabe).
			verCuerpo(anterior.cuerpo, 0)
			anterior.cuerpo = nil
		end
		verCuerpo(cuerpo, 1)
	end
	task.delay(DUDA, function()
		if s.ocupante ~= 0 or sitios[s.modelo] ~= s then -- ya ha entrado otro (o el escondite ya no está)
			if cuerpo then
				verCuerpo(cuerpo, 0)
			end
			return
		end
		if quien:GetAttribute("Muerto") then
			if cuerpo then
				verCuerpo(cuerpo, 0)
			end
			empezar(s, "Sacado", quien)
		else
			empezar(s, "Salir", quien, cuerpo)
		end
	end)
end

local function nuevoSitio(modelo: Instance)
	if sitios[modelo] or not modelo:IsA("Model") then
		return
	end
	local ocupado = modelo:GetAttribute("Ocupado")
	local s: Sitio = {
		modelo = modelo :: Model,
		cama = modelo:GetAttribute("Tipo") == "Cama" or modelo.Name == "Cama",
		listo = false,
		donde = Vector3.zero,
		ocupante = if type(ocupado) == "number" then ocupado else 0,
		valor = 0,
		anim = nil,
		lamas = {},
		sombra = true,
		tiradores = nil,
		sombraTiradores = true,
		hojas = {},
		lados = {},
		rel = {},
		cfs = {},
		largueros = {},
		bisagraIzq = CFrame.identity,
		bisagraDer = CFrame.identity,
		fuera = false,
		conLargueros = false,
		colcha = nil,
		colchaCF = CFrame.identity,
		colchaRel = CFrame.identity,
		base = CFrame.identity,
		lado = 1,
		pivote = CFrame.identity,
		giro = 0,
	}
	sitios[modelo] = s
	s.conexion = modelo:GetAttributeChangedSignal("Ocupado"):Connect(function()
		if sitios[modelo] == s then -- (si el escondite se fue y volvió, manda el sitio nuevo: nada de puertas dobles)
			alCambiar(s)
		end
	end)
end

-- Studio: el escondite más cerca de la cámara, como si entrara (o saliera) alguien que no se ve.
local function probar(que: string)
	if not (PUERTA[que] and COLCHA[que]) then
		return
	end
	local mejor, distancia = nil, math.huge
	for _, s in sitios do
		preparar(s)
		local d = enCamara(s)
		if d < distancia then
			mejor, distancia = s, d
		end
	end
	if mejor then
		empezar(mejor, que, nil)
	end
end

function EsconditeVista.start()
	CollectionService:GetInstanceAddedSignal("Escondite"):Connect(nuevoSitio)
	CollectionService:GetInstanceRemovedSignal("Escondite"):Connect(function(modelo)
		local s = sitios[modelo]
		if s then
			sitios[modelo] = nil
			if s.conexion then
				s.conexion:Disconnect()
				s.conexion = nil
			end
			terminar(s)
		end
	end)
	for _, modelo in CollectionService:GetTagged("Escondite") do
		nuevoSitio(modelo)
	end
	if RunService:IsStudio() then
		local orden = Instance.new("BindableEvent")
		orden.Name = "Probar"
		orden.Event:Connect(probar)
		orden.Parent = script
	end
end

return EsconditeVista
