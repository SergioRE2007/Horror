-- La vida de la gasolinera en el cliente (lobby). La construyen Gasolinera* en el servidor; aquí solo se anima, en una
-- sola tarea del Bucle y solo cerca de la cámara (Config.Lobby.Cerca). Cada cosa se apunta por su etiqueta de
-- CollectionService al llegar y se quita (con todo lo que se le haya creado) al irse; si algo no está, se aguanta.
--   LuzFalla: parpadea según su atributo Fallo (0 nunca; 0,15 tirones de vez en cuando; 0,5 mucho; 0,9 casi muerta):
--     tirones de 2-5 parpadeos, apagones, arranques de fluorescente viejo y, las casi muertas, algún destello. Lejos de
--     la cámara, quieta como está en reposo (encendida; las casi muertas, apagadas). Con Zumba, zumba y chasquea.
--   Polillas: Config.Lobby.Polillas alrededor de cada luz con esa etiqueta (ninguna con Rendimiento).
--   PuertaAuto: se abre sola con alguien cerca (con un tironcito al final) y se cierra a ~1,5 s sin nadie.
--   Nevera y Radio: sus sonidos en bucle; la nevera se para a ratos con un clac y la radio pierde la señal.
--   Coches (workspace.Coches): con alguien dentro, faros y pilotos encendidos, limpias que barren de vez en cuando
--     (llueve) y humo flojo del escape; sin nadie, todo apagado y quieto. Con SaliendoLocal no se tocan (SalidaVista).
--   Sombra: cada Config.Lobby.Sombra.Cada segundos, una figura alta y flaca anda a tirones entre los árboles, de reojo;
--     si la miras de frente, se para, te mira y se va deprisa.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Bucle = require(script.Parent.Bucle)
local Sonido = require(script.Parent.Sonido)

local GasolineraVista = {}

local L = Config.Lobby
local jugador = Players.LocalPlayer
local azar = Random.new()

-- Números de esta vista, a ojo (los del lobby que se tocan para ajustar están en Config.Lobby).
local MARGEN = 8 -- studs de más para dejar de animar lo que ya se animaba (que no salte en el borde de Cerca)
local MUERTA = 0.7 -- desde este Fallo la luz pasa casi todo el rato apagada
local CHASQUIDO = Config.Sonidos.Parpadeo.Alcance -- más lejos, los parpadeos no suenan
local ENTRE_CHASQUIDOS = 1.2 -- segundos, como poco, entre dos chasquidos de la misma luz
local CERCA_POLILLAS = math.min(L.Cerca, 50) -- son diminutas: más lejos no se ven
local CHOQUE = 0.3 -- segundos de una polilla que se da contra la luz (ida y vuelta)
local ABRE, CIERRA, ESPERA = 1.1, 1.4, 1.5 -- segundos de la puerta: abrirse, cerrarse y esperar sin nadie
local PASADA, ANGULO = 1.2, math.rad(80) -- segundos y ángulo de una pasada del limpiaparabrisas
local PASADAS = { 3, 6 } -- segundos entre pasadas
local HUMO, HUMO_POCO = 5, 2 -- partículas por segundo del escape (con Rendimiento, HUMO_POCO)
local NEVERA = Config.Detalles.Nevera -- segundos en marcha y parada, como la nevera de la casa
local REINTENTO = { 4, 9 } -- segundos hasta volver a buscar sitio para la figura si ahora no lo había
local DE_REOJO = { 20, 55 } -- grados del centro de la mirada en que puede salir la figura
local DE_FRENTE = 10 -- grados: mirándola así, se para y se va deprisa
local DESVANECE = 1.5 -- studs del final de su camino en los que se va borrando (por si el árbol no la tapa entera)
local NEGRO = Color3.fromRGB(6, 6, 7)
local FARO = Color3.fromRGB(255, 246, 226) -- el faro encendido, más claro (sin Neon: la luz la pone su SpotLight)
local PILOTO = Color3.fromRGB(196, 44, 34)
local CARAS = { Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left,
	Enum.NormalId.Right }

local function entre(par: { number }): number
	return azar:NextNumber(par[1], par[2])
end

local carpeta: Folder? = nil
-- Donde van las piezas que crea esta vista (polillas y la figura): solo existen en este cliente.
local function carpetaVista(): Folder
	local c = carpeta
	if not c or not c.Parent then
		local nueva = Instance.new("Folder")
		nueva.Name = "GasolineraVista"
		nueva.Parent = workspace
		carpeta = nueva
		return nueva
	end
	return c
end

-- Una pieza de adorno: anclada, sin chocar, sin tapar rayos ni tocar y sin sombra.
local function adorno(padre: Instance, nombre: string, tamano: Vector3, color: Color3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name = nombre
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = tamano
	p.Color = color
	p.CFrame = cf
	p.Parent = padre
	return p
end

-- Cada cosa con la etiqueta, al llegar (y las que ya están) y al irse (también si se va con el mapa por partes).
local function seguir(etiqueta: string, llega: (Instance) -> (), seVa: (Instance) -> ())
	CollectionService:GetInstanceAddedSignal(etiqueta):Connect(llega)
	CollectionService:GetInstanceRemovedSignal(etiqueta):Connect(seVa)
	for _, cosa in CollectionService:GetTagged(etiqueta) do
		task.spawn(llega, cosa)
	end
end

---------------------------------------------------------------- luces que fallan

type Base = { brillo: number, encendida: boolean }
type BaseTexto = { texto: number, borde: number }
type Paso = { n: number, hasta: number, suena: boolean }
type Luz = {
	pieza: BasePart,
	luces: { [Light]: Base },
	textos: { [TextLabel]: BaseTexto },
	color: Color3,
	oscuro: Color3,
	nivel: number, -- lo encendida que está ahora (0 a 1)
	pasos: { Paso }, -- el fallo de ahora (vacío: en reposo)
	paso: number,
	sonado: number, -- el último paso que ya ha chasqueado
	proximo: number, -- cuándo empieza el siguiente fallo
	cerca: boolean,
	zumba: boolean,
	zumbido: Sound?,
	volumen: number,
	chasquido: number, -- cuándo chasqueó por última vez
	conexiones: { RBXScriptConnection },
}
local luces: { [BasePart]: Luz } = {}
local ultimoChasquido = 0 -- de cualquier luz: que no chasqueen varias a la vez

local function fallo(l: Luz): number
	local f = l.pieza:GetAttribute("Fallo")
	return if type(f) == "number" then math.clamp(f, 0, 1) else 0
end

local function reposo(l: Luz): number
	return if fallo(l) >= MUERTA then 0 else 1
end

-- Segundos hasta el siguiente fallo: con más Fallo, más seguido (~50 s con 0,02, ~15 con 0,15, ~6 con 0,5); las casi
-- muertas, algún destello cada ~7 s.
local function espera(f: number): number
	local media = if f >= MUERTA then 2 + 6 * f else 0.8 + 2.6 / (f + 0.03)
	return media * azar:NextNumber(0.5, 1.5)
end

local function pintarLuz(luz: Light, base: Base, n: number)
	luz.Enabled = base.encendida and n > 0.02
	luz.Brightness = base.brillo * n
end

local function pintarTexto(texto: TextLabel, base: BaseTexto, n: number)
	-- Apagada, las letras casi transparentes.
	texto.TextTransparency = 0.88 + (base.texto - 0.88) * n
	texto.TextStrokeTransparency = 1 + (base.borde - 1) * n
end

local function pintar(l: Luz, n: number)
	if math.abs(n - l.nivel) < 0.005 then
		return
	end
	l.nivel = n
	for luz, base in l.luces do
		pintarLuz(luz, base, n)
	end
	for texto, base in l.textos do
		pintarTexto(texto, base, n)
	end
	l.pieza.Color = l.oscuro:Lerp(l.color, n)
	local s = l.zumbido
	if s then
		s.Volume = l.volumen * (0.05 + 0.95 * n)
	end
end

-- Las luces y los letreros de la pieza (pueden llegar después que ella).
local function recoger(l: Luz, d: Instance)
	if d:IsA("Light") and not l.luces[d] then
		local base = { brillo = d.Brightness, encendida = d.Enabled }
		l.luces[d] = base
		pintarLuz(d, base, l.nivel)
	elseif d:IsA("TextLabel") and not l.textos[d] then
		local base = { texto = d.TextTransparency, borde = d.TextStrokeTransparency }
		l.textos[d] = base
		pintarTexto(d, base, l.nivel)
	end
end

local function chasquear(l: Luz, ahora: number, distancia: number)
	-- Solo en algunos parpadeos (si sonara en todos, cansaría): como poco ENTRE_CHASQUIDOS entre dos de la misma luz.
	if l.zumba and distancia < CHASQUIDO and ahora - l.chasquido > ENTRE_CHASQUIDOS
		and ahora - ultimoChasquido > 0.12 then
		l.chasquido = ahora
		ultimoChasquido = ahora
		Sonido.en("Parpadeo", l.pieza.Position, azar:NextNumber(0.92, 1.08))
	end
end

-- Prepara el siguiente fallo de la luz: una lista de pasos (lo encendida que está y hasta cuándo). Al acabar vuelve a
-- su reposo. Devuelve false si esta luz no falla nunca (Fallo 0) o está muerta del todo (1).
local function secuencia(l: Luz, ahora: number): boolean
	local f = fallo(l)
	if f <= 0 or f >= 0.99 then
		return false
	end
	local pasos = l.pasos
	table.clear(pasos)
	local t = ahora
	local function poner(n: number, dura: number, suena: boolean?)
		t += dura
		table.insert(pasos, { n = n, hasta = t, suena = suena == true })
	end
	local function tiron(minimo: number, maximo: number)
		for k = 1, azar:NextInteger(minimo, maximo) do
			-- Casi siempre se corta del todo; a veces se queda en un hilo de luz.
			poner(if azar:NextNumber() < 0.65 then 0 else azar:NextNumber(0.05, 0.25), azar:NextNumber(0.03, 0.1),
				k == 1 and azar:NextNumber() < 0.5)
			poner(azar:NextNumber(0.6, 1), azar:NextNumber(0.03, 0.14))
		end
	end
	-- Fluorescente viejo arrancando: unos intentos flojos entre ratos a oscuras ("tic, tic") y prende de golpe.
	local function arranque()
		for k = 1, azar:NextInteger(2, 4) do
			poner(azar:NextNumber(0.15, 0.45), azar:NextNumber(0.03, 0.08), k == 1)
			poner(0, azar:NextNumber(0.12, 0.5))
		end
		poner(1, 0.05, true)
		poner(0.3, 0.04)
		poner(0.9, 0.1)
		poner(0.75, 0.08)
		poner(1, 0.25)
	end
	local r = azar:NextNumber()
	if f < MUERTA then
		if r < 0.4 * f then
			tiron(1, 3) -- apagón: se va un rato y vuelve arrancando
			poner(0, azar:NextNumber(0.3, 0.6 + 3 * f))
			arranque()
		elseif r < 0.08 + 0.52 * f then
			poner(0, azar:NextNumber(0.05, 0.2), true) -- se corta y arranca otra vez
			arranque()
		else
			tiron(2, 5)
		end
	elseif r < 0.3 - 0.8 * (f - MUERTA) then
		arranque() -- casi muerta: intenta arrancar, aguanta un poco y se muere parpadeando
		poner(1, azar:NextNumber(0.5, 0.5 + 4 * (1 - f)))
		tiron(2, 4)
	else
		for k = 1, azar:NextInteger(1, 3) do -- destellos sueltos
			poner(azar:NextNumber(0.45, 1), azar:NextNumber(0.03, 0.12), k == 1)
			poner(azar:NextNumber(0, 0.08), azar:NextNumber(0.05, 0.25))
		end
	end
	l.paso = 1
	l.sonado = 0
	return true
end

local function llegaLuz(cosa: Instance)
	if not cosa:IsA("BasePart") or luces[cosa] then
		return
	end
	local pieza = cosa
	local c = pieza.Color
	local l: Luz = {
		pieza = pieza,
		luces = {},
		textos = {},
		color = c,
		oscuro = Color3.new(c.R * 0.35, c.G * 0.35, c.B * 0.35),
		nivel = 1,
		pasos = {},
		paso = 1,
		sonado = 0,
		proximo = 0,
		cerca = false,
		zumba = false,
		zumbido = nil,
		volumen = 0,
		chasquido = 0,
		conexiones = {},
	}
	luces[pieza] = l
	for _, d in pieza:GetDescendants() do
		recoger(l, d)
	end
	table.insert(l.conexiones, pieza.DescendantAdded:Connect(function(d)
		recoger(l, d)
	end))
	table.insert(l.conexiones, pieza.DescendantRemoving:Connect(function(d)
		if d:IsA("Light") then
			l.luces[d] = nil
		elseif d:IsA("TextLabel") then
			l.textos[d] = nil
		end
	end))
	-- El zumbido, una vez, al llegar (o cuando llegue su atributo).
	local function zumbar()
		l.zumba = pieza:GetAttribute("Zumba") == true
		if l.zumba and not l.zumbido and luces[pieza] == l then
			local s = Sonido.bucle("Zumbido", pieza)
			if s then
				l.zumbido = s
				l.volumen = s.Volume
				s.Volume = l.volumen * (0.05 + 0.95 * l.nivel)
				if not l.cerca then
					s:Pause()
				end
			end
		end
	end
	zumbar()
	table.insert(l.conexiones, pieza:GetAttributeChangedSignal("Zumba"):Connect(zumbar))
	pintar(l, reposo(l))
end

local function seVaLuz(cosa: Instance)
	local l = luces[cosa :: BasePart]
	if not l then
		return
	end
	luces[l.pieza] = nil
	for _, conexion in l.conexiones do
		conexion:Disconnect()
	end
	if l.zumbido then
		l.zumbido:Destroy()
		l.zumbido = nil
	end
	pintar(l, 1) -- como la dejó el servidor (si la pieza sigue ahí)
end

local function pasoLuces(ahora: number, cam: Vector3)
	for pieza, l in luces do
		local distancia = (pieza.Position - cam).Magnitude
		local cerca = distancia < L.Cerca + (if l.cerca then MARGEN else 0)
		if cerca ~= l.cerca then
			-- Al acercarse empieza a fallar; al alejarse se queda quieta como está en reposo.
			l.cerca = cerca
			table.clear(l.pasos)
			pintar(l, reposo(l))
			l.proximo = ahora + espera(fallo(l)) * azar:NextNumber(0.1, 1)
			local s = l.zumbido
			if s and cerca then
				s:Resume()
			elseif s then
				s:Pause()
			end
		end
		if not cerca then
			continue
		end
		if #l.pasos == 0 then
			if ahora < l.proximo then
				continue
			end
			if not secuencia(l, ahora) then
				pintar(l, reposo(l)) -- no falla (o está muerta del todo); se vuelve a mirar por si cambia su Fallo
				l.proximo = ahora + 5
				continue
			end
		end
		while l.pasos[l.paso] and ahora >= l.pasos[l.paso].hasta do
			l.paso += 1
		end
		local p = l.pasos[l.paso]
		if p then
			if p.suena and l.sonado ~= l.paso then
				l.sonado = l.paso
				chasquear(l, ahora, distancia)
			end
			pintar(l, p.n)
		else
			table.clear(l.pasos)
			pintar(l, reposo(l))
			l.proximo = ahora + espera(fallo(l))
		end
	end
end

---------------------------------------------------------------- polillas

type Polilla = {
	pieza: Part,
	centro: Vector3, -- alrededor de dónde vuela
	toque: Vector3, -- dónde se da contra la luz
	radio: number,
	vel: number,
	fase: number,
	alto: number,
	frec: number,
	semilla: number,
	choque: number?, -- cuándo empezó a ir contra la luz
	proximo: number, -- cuándo vuelve a ir
	antes: Vector3,
}
local polillas: { [BasePart]: { Polilla } } = {} -- luz -> sus polillas (vacía: ahora no tiene)

local function crearPolillas(luz: BasePart, ahora: number): { Polilla }
	local lista = {}
	local cf, medio = luz.CFrame, luz.Size / 2
	for _ = 1, L.Polillas do
		-- Un poco por debajo de la luz (las de la marquesina están pegadas al techo).
		local centro = cf * Vector3.new(azar:NextNumber(-0.9, 0.9) * medio.X, azar:NextNumber(-0.9, 0.9) * medio.Y,
			azar:NextNumber(-0.9, 0.9) * medio.Z) - Vector3.new(0, 0.45, 0)
		local relativo = cf:PointToObjectSpace(centro)
		local toque = cf * Vector3.new(math.clamp(relativo.X, -medio.X, medio.X), math.clamp(relativo.Y, -medio.Y, medio.Y),
			math.clamp(relativo.Z, -medio.Z, medio.Z))
		local gris = azar:NextNumber(0.75, 1.1)
		local pieza = adorno(carpetaVista(), "Polilla", Vector3.new(0.16, 0.03, 0.1) * azar:NextNumber(0.8, 1.25),
			Color3.fromRGB(122 * gris, 114 * gris, 100 * gris), CFrame.new(centro))
		table.insert(lista, {
			pieza = pieza,
			centro = centro,
			toque = toque,
			radio = azar:NextNumber(0.5, 1.4),
			vel = azar:NextNumber(2.2, 5) * (if azar:NextNumber() < 0.5 then -1 else 1),
			fase = azar:NextNumber(0, 2 * math.pi),
			alto = azar:NextNumber(0.15, 0.45),
			frec = azar:NextNumber(1.5, 3.5),
			semilla = azar:NextNumber(0, 1000),
			choque = nil,
			proximo = ahora + azar:NextNumber(0.8, 4),
			antes = centro,
		})
	end
	return lista
end

local function borrarPolillas(lista: { Polilla })
	for _, m in lista do
		m.pieza:Destroy()
	end
	table.clear(lista)
end

-- Vueltas raras alrededor de la luz (con ruido) y, de vez en cuando, un golpe contra ella.
local function moverPolilla(m: Polilla, ahora: number)
	local a = m.fase + m.vel * ahora + 1.6 * math.noise(m.semilla, ahora * 0.6)
	local r = m.radio * (0.75 + 0.6 * math.noise(m.semilla + 7.3, ahora * 1.1))
	local y = m.alto * math.sin(m.frec * ahora + m.fase) + 0.35 * math.noise(m.semilla + 3.1, ahora * 1.7)
	local pos = m.centro + Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
	local choque = m.choque
	if choque then
		local u = (ahora - choque) / CHOQUE
		if u >= 1 then
			m.choque = nil
			m.proximo = ahora + azar:NextNumber(0.8, 4)
		else
			pos = pos:Lerp(m.toque, math.sin(math.pi * u) * 0.95)
		end
	elseif ahora >= m.proximo then
		m.choque = ahora
	end
	local dir = pos - m.antes
	m.antes = pos
	local cf = if dir.Magnitude > 1e-3 then CFrame.lookAt(pos, pos + dir) else CFrame.new(pos)
	m.pieza.CFrame = cf * CFrame.Angles(0, 0, math.sin(ahora * 46 + m.fase) * 0.8) -- aleteo
end

local function pasoPolillas(ahora: number, cam: Vector3, poco: boolean)
	for luz, lista in polillas do
		local hay = #lista > 0
		local quiere = not poco and (luz.Position - cam).Magnitude < CERCA_POLILLAS + (if hay then MARGEN else 0)
		if quiere and not hay then
			lista = crearPolillas(luz, ahora)
			polillas[luz] = lista
		elseif hay and not quiere then
			borrarPolillas(lista)
		end
		for _, m in lista do
			moverPolilla(m, ahora)
		end
	end
end

---------------------------------------------------------------- puerta automática

type Hoja = { cosa: Instance, reposo: CFrame }
type Puerta = {
	modelo: Model,
	hojas: { [string]: Hoja },
	pos: number, -- 0 cerrada, 1 abierta
	desde: number,
	hacia: number,
	inicio: number,
	dura: number,
	visto: number, -- la última vez que había alguien cerca
}
local puertas: { [Model]: Puerta } = {}
local HOJAS = { "Hoja1", "Hoja2" }

-- Suave y, al final, un tironcito con un pelín de rebote (puerta automática vieja). u de 0 a 1.
local function curva(u: number): number
	if u >= 1 then
		return 1
	elseif u < 0.78 then
		return 0.93 * (1 - math.cos(u / 0.78 * math.pi)) / 2
	elseif u < 0.88 then
		return 0.93 -- el motor duda
	end
	local k = (u - 0.88) / 0.12
	return 0.93 + 0.07 * (1 - (1 - k) ^ 3) + 0.035 * math.sin(k * math.pi)
end

-- La hoja y su sitio cerrada (puede llegar después que el modelo, o volver a llegar con el mapa por partes).
local function hoja(pu: Puerta, nombre: string): Hoja?
	local h = pu.hojas[nombre]
	if h and h.cosa:IsDescendantOf(pu.modelo) then
		return h
	end
	local cosa = pu.modelo:FindFirstChild(nombre, true)
	local nueva: Hoja? = nil
	if cosa and cosa:IsA("BasePart") then
		nueva = { cosa = cosa, reposo = cosa.CFrame }
	elseif cosa and cosa:IsA("Model") and cosa.PrimaryPart then
		nueva = { cosa = cosa, reposo = cosa:GetPivot() }
	end
	pu.hojas[nombre] = nueva
	return nueva
end

local function colocar(pu: Puerta, pos: number)
	for _, nombre in HOJAS do
		local h = hoja(pu, nombre)
		if not h then
			continue
		end
		local cosa = h.cosa
		local desliza = cosa:GetAttribute("Desliza")
		local cf = if typeof(desliza) == "Vector3" then h.reposo + desliza * pos else h.reposo
		if cosa:IsA("BasePart") then
			cosa.CFrame = cf
		elseif cosa:IsA("Model") then
			cosa:PivotTo(cf)
		end
	end
end

local function llegaPuerta(cosa: Instance)
	if cosa:IsA("Model") and not puertas[cosa] then
		puertas[cosa] = { modelo = cosa, hojas = {}, pos = 0, desde = 0, hacia = 0, inicio = 0, dura = 1, visto = -math.huge }
	end
end

local function seVaPuerta(cosa: Instance)
	local pu = puertas[cosa :: Model]
	if pu then
		puertas[pu.modelo] = nil
		colocar(pu, 0) -- cerrada, como la dejó el servidor
	end
end

local function pasoPuertas(ahora: number, cam: Vector3)
	for modelo, pu in puertas do
		local c = modelo:GetAttribute("Centro")
		local centro: Vector3 = if typeof(c) == "Vector3" then c else modelo:GetPivot().Position
		if (centro - cam).Magnitude > L.Cerca then
			if pu.pos ~= 0 or pu.hacia ~= 0 then -- lejos: cerrada y quieta
				pu.pos, pu.desde, pu.hacia = 0, 0, 0
				colocar(pu, 0)
			end
			continue
		end
		for _, otro in Players:GetPlayers() do
			local cuerpo = otro.Character
			local raiz = cuerpo and cuerpo:FindFirstChild("HumanoidRootPart")
			if raiz and raiz:IsA("BasePart") and (raiz.Position - centro).Magnitude < L.Puerta then
				pu.visto = ahora
				break
			end
		end
		local quiere = if ahora - pu.visto < ESPERA then 1 else 0
		if quiere ~= pu.hacia then
			if quiere == 1 and pu.pos < 0.3 then
				Sonido.en("Campanilla", centro)
			end
			pu.desde, pu.hacia, pu.inicio = pu.pos, quiere, ahora
			pu.dura = (if quiere == 1 then ABRE else CIERRA) * math.max(0.35, math.abs(quiere - pu.pos))
		end
		if pu.pos ~= pu.hacia then
			local u = (ahora - pu.inicio) / pu.dura
			pu.pos = if u >= 1 then pu.hacia else pu.desde + (pu.hacia - pu.desde) * curva(u)
			colocar(pu, pu.pos)
		end
	end
end

---------------------------------------------------------------- nevera y radio

type Aparato = {
	punto: Attachment, -- de donde sale su sonido (creado aquí, en el Terrain)
	sonido: Sound?,
	volumen: number,
	nevera: boolean,
	marcha: boolean, -- la nevera: el motor en marcha
	cambio: number, -- cuándo arranca o se para la nevera; cuándo pierde o recupera la señal la radio
	corte: boolean, -- la radio: sin señal ahora
}
local aparatos: { [Instance]: Aparato } = {}

local function llegaAparato(cosa: Instance, nombre: string)
	if aparatos[cosa] then
		return
	end
	local pos = if cosa:IsA("BasePart") then cosa.Position
		elseif cosa:IsA("Model") then cosa:GetPivot().Position
		elseif cosa:IsA("Attachment") then cosa.WorldPosition
		else nil
	if not pos then
		return
	end
	-- En un Attachment propio: colgado de un Model, Sonido.bucle no sonaría en 3D.
	local punto = Instance.new("Attachment")
	punto.Name = "Sonido" .. nombre
	punto.Parent = workspace.Terrain
	punto.WorldPosition = pos
	local sonido = Sonido.bucle(nombre, punto) -- la radio aún no tiene sonido: nil
	local nevera = nombre == "Nevera"
	aparatos[cosa] = {
		punto = punto,
		sonido = sonido,
		volumen = if sonido then sonido.Volume else 0,
		nevera = nevera,
		marcha = true,
		cambio = os.clock() + (if nevera then entre(NEVERA.Encendida) else azar:NextNumber(4, 12)),
		corte = false,
	}
end

local function seVaAparato(cosa: Instance)
	local a = aparatos[cosa]
	if a then
		aparatos[cosa] = nil
		a.punto:Destroy() -- y su sonido con él
	end
end

local function pasoAparatos(ahora: number, cam: Vector3)
	for _, a in aparatos do
		local donde = a.punto.WorldPosition
		local cerca = (donde - cam).Magnitude < L.Cerca
		if ahora >= a.cambio then
			if a.nevera then
				-- El motor se para un rato (clac) y vuelve a arrancar.
				a.marcha = not a.marcha
				a.cambio = ahora + entre(if a.marcha then NEVERA.Encendida else NEVERA.Parada)
				if cerca then
					Sonido.en("NeveraClac", donde, if a.marcha then 0.92 else 1)
				end
			else
				-- La radio pierde la señal un momento.
				a.corte = not a.corte
				a.cambio = ahora + (if a.corte then azar:NextNumber(0.15, 0.7) else azar:NextNumber(4, 12))
				if a.sonido then
					a.sonido.Volume = a.volumen * (if a.corte then azar:NextNumber(0.15, 0.45) else 1)
				end
			end
		end
		local s = a.sonido
		if s then
			local suena = cerca and a.marcha
			if suena and not s.IsPlaying then
				s:Resume()
			elseif not suena and s.IsPlaying then
				s:Pause()
			end
		end
	end
end

---------------------------------------------------------------- coches

type Limpia = { reposo: CFrame, signo: number? }
type Coche = {
	modelo: Model,
	sucio: boolean, -- hay que volver a buscar sus piezas (han llegado o se han ido)
	asientos: { Instance },
	faros: { BasePart },
	pilotos: { BasePart },
	colores: { [BasePart]: Color3 }, -- el color de cada faro y piloto apagado
	limpias: { [Instance]: Limpia },
	escape: Attachment?,
	humo: ParticleEmitter?,
	encendido: boolean?,
	pasada: number?, -- cuándo empezó la pasada de los limpias de ahora
	proxima: number,
	quieto: boolean, -- los limpias, en su sitio
	fuera: boolean, -- con SaliendoLocal (lo lleva SalidaVista): no se toca
	conexiones: { RBXScriptConnection },
}
local coches: { [Model]: Coche } = {}

local function crearHumo(c: Coche, escape: Attachment): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = "Humo"
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(118, 116, 112))
	e.LightEmission = 0
	e.LightInfluence = 0.9 -- casi solo se ve con luz cerca (los pilotos lo tiñen de rojo)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 2.2) })
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.82),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(1.4, 2.4)
	e.Speed = NumberRange.new(1.5, 3)
	e.SpreadAngle = Vector2.new(14, 14)
	e.Acceleration = Vector3.new(0, 0.9, 0)
	e.Drag = 1.4
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-25, 25)
	e.Rate = HUMO
	e.Enabled = false
	-- Hacia atrás del coche: la cara del Attachment que más mira atrás (no se sabe cómo lo han girado).
	local carroceria = c.modelo.PrimaryPart
	local atras = -(if carroceria then carroceria.CFrame.LookVector else c.modelo:GetPivot().LookVector)
	local mejor = -2
	for _, cara in CARAS do
		local v = escape.WorldCFrame:VectorToWorldSpace(Vector3.FromNormalId(cara))
		if v:Dot(atras) > mejor then
			mejor = v:Dot(atras)
			e.EmissionDirection = cara
		end
	end
	e.Parent = escape
	return e
end

local function escanear(c: Coche)
	c.sucio = false
	table.clear(c.asientos)
	table.clear(c.faros)
	table.clear(c.pilotos)
	local colores, limpias = {}, {}
	local escape: Attachment? = nil
	for _, d in c.modelo:GetDescendants() do
		local nombre = d.Name
		if d:IsA("Seat") or d:IsA("VehicleSeat") then
			table.insert(c.asientos, d)
		elseif nombre == "Limpia1" or nombre == "Limpia2" then
			-- Su sitio de reposo, la primera vez que se ve (si no, el que ya tenía: puede estar a media pasada).
			if d:IsA("BasePart") then
				limpias[d] = c.limpias[d] or { reposo = d.CFrame }
			elseif d:IsA("Model") then
				limpias[d] = c.limpias[d] or { reposo = d:GetPivot() }
			end
		elseif (nombre == "Faro" or nombre == "Piloto") and d:IsA("BasePart") then
			table.insert(if nombre == "Faro" then c.faros else c.pilotos, d)
			colores[d] = c.colores[d] or d.Color
		elseif nombre == "Escape" and d:IsA("Attachment") then
			escape = d
		end
	end
	c.colores = colores
	c.limpias = limpias
	c.escape = escape
	if c.humo and c.humo.Parent ~= escape then
		c.humo:Destroy()
		c.humo = nil
	end
	if escape and not c.humo then
		c.humo = crearHumo(c, escape)
	end
	c.encendido = nil -- que se pinte todo otra vez
	c.quieto = false
end

local function encender(c: Coche, si: boolean, ahora: number)
	c.encendido = si
	for _, lista in { c.faros, c.pilotos } do
		local claro = if lista == c.faros then FARO else PILOTO
		for _, pieza in lista do
			for _, luz in pieza:GetChildren() do
				if luz:IsA("Light") then
					luz.Enabled = si
				end
			end
			local base = c.colores[pieza]
			if base then
				pieza.Color = if si then base:Lerp(claro, 0.65) else base
			end
		end
	end
	if si then
		c.proxima = ahora + azar:NextNumber(0.4, 1.5) -- al subir, enseguida una pasada
	end
end

-- Los limpias girados k (0 en reposo, 1 arriba del todo) alrededor de su Eje y su Normal.
local function barrer(c: Coche, k: number)
	for cosa, li in c.limpias do
		local eje, normal = cosa:GetAttribute("Eje"), cosa:GetAttribute("Normal")
		if typeof(eje) ~= "Vector3" or typeof(normal) ~= "Vector3" or normal.Magnitude < 0.01 then
			continue
		end
		local n = normal.Unit
		-- Que la punta suba por el cristal (no se sabe hacia qué lado apunta la Normal).
		local signo = li.signo or (if n:Cross(li.reposo.Position - eje).Y >= 0 then 1 else -1)
		li.signo = signo
		local cf = CFrame.new(eje) * CFrame.fromAxisAngle(n, k * ANGULO * signo) * CFrame.new(-eje) * li.reposo
		if cosa:IsA("BasePart") then
			cosa.CFrame = cf
		elseif cosa:IsA("Model") then
			cosa:PivotTo(cf)
		end
	end
end

local function llegaCoche(cosa: Instance)
	if not cosa:IsA("Model") or coches[cosa] then
		return
	end
	local c: Coche = {
		modelo = cosa,
		sucio = true,
		asientos = {},
		faros = {},
		pilotos = {},
		colores = {},
		limpias = {},
		escape = nil,
		humo = nil,
		encendido = nil,
		pasada = nil,
		proxima = 0,
		quieto = true,
		fuera = false,
		conexiones = {},
	}
	coches[cosa] = c
	local function cambia(d: Instance)
		if not (d:IsA("ParticleEmitter") and d.Name == "Humo") then -- el humo lo pone esta vista
			c.sucio = true
		end
	end
	table.insert(c.conexiones, cosa.DescendantAdded:Connect(cambia))
	table.insert(c.conexiones, cosa.DescendantRemoving:Connect(cambia))
end

local function seVaCoche(cosa: Instance)
	local c = coches[cosa :: Model]
	if not c then
		return
	end
	coches[c.modelo] = nil
	for _, conexion in c.conexiones do
		conexion:Disconnect()
	end
	if c.humo then
		c.humo:Destroy()
		c.humo = nil
	end
	if not c.fuera then
		barrer(c, 0)
		encender(c, false, 0)
	end
end

local function pasoCoches(ahora: number, cam: Vector3, poco: boolean)
	local fila = workspace:FindFirstChild("Coches")
	for modelo, c in coches do
		if modelo.Parent ~= fila then
			continue -- solo los aparcados (una copia del coche no es de la fila)
		end
		if modelo:GetAttribute("SaliendoLocal") then
			if not c.fuera then
				c.fuera = true
				if c.humo then
					c.humo.Enabled = false
				end
			end
			continue
		end
		if c.fuera then -- no ha llegado a salir: se vuelve a pintar
			c.fuera = false
			c.sucio = true
			c.pasada = nil
		end
		if c.sucio then
			escanear(c)
		end
		local alguien = modelo:GetAttribute("Dueno") ~= nil
		for _, asiento in c.asientos do
			if alguien then
				break
			end
			alguien = (asiento :: any).Occupant ~= nil
		end
		if alguien ~= c.encendido then
			encender(c, alguien, ahora)
		end
		local cerca = (modelo:GetPivot().Position - cam).Magnitude < L.Cerca
		local humo = c.humo
		if humo then
			local quiere = alguien and cerca
			if humo.Enabled ~= quiere then
				humo.Enabled = quiere
			end
			local cuanto = if poco then HUMO_POCO else HUMO
			if humo.Rate ~= cuanto then
				humo.Rate = cuanto
			end
		end
		-- Limpias: con gente y cerca, una pasada cada pocos segundos (llueve); si no, en su sitio.
		if not c.pasada and alguien and cerca and ahora >= c.proxima then
			c.pasada = ahora
		elseif c.pasada and not (alguien and cerca) then
			c.pasada = nil
		end
		local pasada = c.pasada
		if pasada then
			local u = (ahora - pasada) / PASADA
			if u >= 1 then
				c.pasada = nil
				c.proxima = ahora + entre(PASADAS)
				barrer(c, 0)
				c.quieto = true
			else
				barrer(c, (1 - math.cos(u * 2 * math.pi)) / 2)
				c.quieto = false
			end
		elseif not c.quieto then
			barrer(c, 0)
			c.quieto = true
		end
	end
end

---------------------------------------------------------------- algo entre los árboles

-- La figura: sus piezas y su tamaño a escala 1 (sale de 8 a 10 studs de alto, encorvada y con los brazos casi hasta el
-- suelo). Las de los lados acaban en 1 (izquierda) y 2 (derecha).
local FIGURA = {
	Cadera = Vector3.new(0.95, 0.5, 0.45),
	Cuerpo = Vector3.new(0.85, 3.3, 0.48),
	Hombros = Vector3.new(1.75, 0.3, 0.42),
	Cuello = Vector3.new(0.2, 0.75, 0.2),
	Cabeza = Vector3.new(0.6, 0.85, 0.75),
	Muslo1 = Vector3.new(0.34, 2.4, 0.34),
	Muslo2 = Vector3.new(0.34, 2.4, 0.34),
	Pierna1 = Vector3.new(0.26, 2.5, 0.26),
	Pierna2 = Vector3.new(0.26, 2.5, 0.26),
	Brazo1 = Vector3.new(0.2, 2.9, 0.2),
	Brazo2 = Vector3.new(0.2, 2.9, 0.2),
	Antebrazo1 = Vector3.new(0.17, 2.9, 0.17),
	Antebrazo2 = Vector3.new(0.17, 2.9, 0.17),
	Mano1 = Vector3.new(0.24, 1.15, 0.09),
	Mano2 = Vector3.new(0.24, 1.15, 0.09),
}

type Figura = {
	modelo: Model,
	partes: { [string]: BasePart },
	ojos: BillboardGui,
	escala: number,
	inicio: Vector3,
	hacia: Vector3,
	largo: number,
	vel: number,
	avance: number, -- studs andados
	raiz: CFrame, -- la de la pose de ahora (en el suelo, mirando hacia donde anda)
	estado: string, -- "anda", "quieta" (la has pillado mirándola) o "huye"
	hasta: number,
	pillada: boolean,
	salto: number, -- cuándo cambia la pose (a tirones)
	creada: number,
}
local sombras: { [Attachment]: boolean } = {}
local cajas: { [BasePart]: boolean } = {} -- "Dentro": el interior de la tienda
local ultimaSombra: Attachment? = nil
local proximaSombra = 0
local figura: Figura? = nil

-- Pone cada pieza de la figura según lo andado. `giro`: la cabeza vuelta hacia un lado (radianes); `mira`: levanta la
-- cabeza (te está mirando).
local function posar(f: Figura, giro: number, mira: boolean)
	local s, p, raiz = f.escala, f.partes, f.raiz
	local fase = f.avance / (1.6 * s) * math.pi -- un paso cada 1,6 studs (a escala)
	-- Piernas: la que pisa marca la altura de la cadera (así sube y baja al andar).
	local muslo, rodilla = { 0, 0 }, { 0, 0 }
	local alto = 0
	for i = 1, 2 do
		local fi = fase + (i - 1) * math.pi
		muslo[i] = 0.42 * math.sin(fi)
		rodilla[i] = 0.12 + 0.55 * math.max(0, math.cos(fi))
		alto = math.max(alto, (2.4 * math.cos(muslo[i]) + 2.5 * math.cos(muslo[i] - rodilla[i])) * s)
	end
	for i = 1, 2 do
		local lado = if i == 1 then -1 else 1
		local cadera = Vector3.new(lado * 0.36 * s, alto, 0)
		local g = CFrame.Angles(muslo[i], 0, 0)
		p[`Muslo{i}`].CFrame = raiz * CFrame.new(cadera) * g * CFrame.new(0, -1.2 * s, 0)
		local codoPierna = cadera + g * Vector3.new(0, -2.4 * s, 0)
		p[`Pierna{i}`].CFrame = raiz * CFrame.new(codoPierna) * CFrame.Angles(muslo[i] - rodilla[i], 0, 0)
			* CFrame.new(0, -1.25 * s, 0)
	end
	-- Cuerpo encorvado hacia delante y la cabeza colgando por delante de los hombros.
	local cuerpo = CFrame.new(0, alto + 0.15 * s, 0)
		* CFrame.Angles(-0.58 - 0.04 * math.sin(fase * 2), 0, 0.05 * math.sin(fase))
	p.Cadera.CFrame = raiz * CFrame.new(0, alto + 0.1 * s, 0)
	p.Cuerpo.CFrame = raiz * cuerpo * CFrame.new(0, 1.65 * s, 0)
	local hombros = cuerpo * CFrame.new(0, 3.3 * s, 0)
	p.Hombros.CFrame = raiz * hombros
	local cuello = hombros.Position
	p.Cuello.CFrame = raiz * CFrame.new(cuello) * CFrame.Angles(-1.22, 0, 0) * CFrame.new(0, 0.375 * s, 0)
	local nuca = cuello + Vector3.new(0, 0.75 * s * math.cos(1.22), -0.75 * s * math.sin(1.22))
	p.Cabeza.CFrame = raiz * CFrame.new(nuca) * CFrame.Angles(0, giro, 0) * CFrame.Angles(if mira then -0.1 else -0.35, 0, 0)
		* CFrame.new(0, 0.1 * s, -0.32 * s)
	-- Brazos larguísimos, colgando casi hasta el suelo y balanceándose al revés que las piernas.
	for i = 1, 2 do
		local lado = if i == 1 then -1 else 1
		local a = 0.06 - 0.16 * math.sin(fase + (i - 1) * math.pi)
		local hombro = hombros * Vector3.new(lado * 0.82 * s, 0, 0)
		local g1 = CFrame.Angles(a, 0, lado * 0.08)
		p[`Brazo{i}`].CFrame = raiz * CFrame.new(hombro) * g1 * CFrame.new(0, -1.45 * s, 0)
		local codo = hombro + g1 * Vector3.new(0, -2.9 * s, 0)
		local g2 = CFrame.Angles(a + 0.22, 0, lado * 0.05)
		p[`Antebrazo{i}`].CFrame = raiz * CFrame.new(codo) * g2 * CFrame.new(0, -1.45 * s, 0)
		local muneca = codo + g2 * Vector3.new(0, -2.9 * s, 0)
		p[`Mano{i}`].CFrame = raiz * CFrame.new(muneca) * CFrame.Angles(a + 0.32, 0, lado * 0.03)
			* CFrame.new(0, -0.575 * s, 0)
	end
end

local function borrarFigura()
	local f = figura
	if f then
		figura = nil
		f.modelo:Destroy()
	end
end

local function crearFigura(punto: Attachment, ahora: number, cam: Vector3): Figura
	local inicio = punto.WorldPosition
	local h = punto:GetAttribute("Hacia")
	local plano = if typeof(h) == "Vector3" then Vector3.new(h.X, 0, h.Z) else Vector3.zero
	if plano.Magnitude < 0.01 then
		local a = inicio - cam -- sin Hacia: de lado para quien mira
		plano = Vector3.new(-a.Z, 0, a.X)
	end
	local hacia = if plano.Magnitude > 0.01 then plano.Unit else Vector3.new(1, 0, 0)
	local largo = punto:GetAttribute("Largo")
	local escala = azar:NextNumber(0.98, 1.17)
	local modelo = Instance.new("Model")
	modelo.Name = "Figura"
	local partes = {}
	for nombre, tam in FIGURA do
		partes[nombre] = adorno(modelo, nombre, tam * escala, NEGRO, CFrame.new(inicio))
	end
	-- Los ojos: dos puntitos claros que solo se ven cuando te mira. De tamaño fijo en pantalla (de lejos no
	-- desaparecen), más pequeños cuanto más lejos.
	local cara = Instance.new("Attachment")
	cara.Name = "Cara"
	cara.Position = Vector3.new(0, 0.05, -0.39) * escala
	cara.Parent = partes.Cabeza
	local px = math.clamp(math.floor(260 / (inicio - cam).Magnitude + 0.5), 2, 4)
	local ojos = Instance.new("BillboardGui")
	ojos.Name = "Ojos"
	ojos.Size = UDim2.fromOffset(px * 3, px)
	ojos.StudsOffset = Vector3.new(0, 0, 0.3) -- un poco hacia la cámara, que no los tape la cabeza
	ojos.LightInfluence = 0
	ojos.AlwaysOnTop = false
	ojos.Enabled = false
	for i = 0, 1 do
		local ojo = Instance.new("Frame")
		ojo.Size = UDim2.fromOffset(px, px)
		ojo.Position = UDim2.fromOffset(i * px * 2, 0)
		ojo.BackgroundColor3 = Color3.fromRGB(214, 208, 190)
		ojo.BorderSizePixel = 0
		ojo.Parent = ojos
	end
	ojos.Parent = cara
	local f: Figura = {
		modelo = modelo,
		partes = partes,
		ojos = ojos,
		escala = escala,
		inicio = inicio,
		hacia = hacia,
		largo = if type(largo) == "number" and largo > 0 then largo else 12,
		vel = 0,
		avance = 0,
		raiz = CFrame.lookAt(inicio, inicio + hacia),
		estado = "anda",
		hasta = 0,
		pillada = false,
		salto = ahora,
		creada = ahora,
	}
	f.vel = f.largo / azar:NextNumber(2.5, 4)
	posar(f, 0, false)
	modelo.Parent = carpetaVista()
	Sonido.en(if azar:NextNumber() < 0.5 then "Rama" else "Ramita", inicio + Vector3.new(0, 1, 0), azar:NextNumber(0.9, 1.1))
	return f
end

local function moverFigura(f: Figura, dt: number, ahora: number, vista: CFrame)
	if ahora - f.creada > 15 then
		borrarFigura() -- por si acaso
		return
	end
	if not f.pillada then
		local a = f.raiz.Position + Vector3.new(0, 5 * f.escala, 0) - vista.Position
		if a.Magnitude > 1 and vista.LookVector:Dot(a.Unit) > math.cos(math.rad(DE_FRENTE)) then
			-- La has visto: se para en seco y te mira.
			f.pillada = true
			f.estado = "quieta"
			f.hasta = ahora + azar:NextNumber(0.45, 0.8)
			f.salto = ahora
		end
	end
	if f.estado == "quieta" then
		if ahora >= f.hasta then
			f.estado = "huye"
			f.ojos.Enabled = false
			f.salto = ahora
			if azar:NextNumber() < 0.6 then
				Sonido.en("Ramita", f.raiz.Position + Vector3.new(0, 1, 0), azar:NextNumber(1, 1.15))
			end
		end
	else
		f.avance += f.vel * dt * (if f.estado == "huye" then 2.6 else 1)
		if f.avance >= f.largo then
			borrarFigura() -- ya está detrás del árbol
			return
		end
	end
	if ahora < f.salto then
		return -- a tirones: la pose solo cambia de vez en cuando
	end
	f.salto = ahora + (if azar:NextNumber() < 0.1 then azar:NextNumber(0.25, 0.4) else azar:NextNumber(0.05, 0.16))
	local base = f.inicio + f.hacia * f.avance
	f.raiz = CFrame.lookAt(base, base + f.hacia)
	local giro = 0
	local mira = f.estado == "quieta"
	if mira then
		local rel = f.raiz:PointToObjectSpace(vista.Position)
		giro = math.clamp(math.atan2(-rel.X, -rel.Z), -2.3, 2.3) -- hasta casi la espalda, como un búho
		f.ojos.Enabled = true
	elseif f.estado == "anda" and azar:NextNumber() < 0.12 then
		giro = azar:NextNumber(-0.5, 0.5) -- un tic de la cabeza
	end
	posar(f, giro, mira)
	local transparencia = math.clamp(1 - (f.largo - f.avance) / DESVANECE, 0, 0.95)
	if transparencia > 0 then
		for _, pieza in f.partes do
			pieza.Transparency = transparencia
		end
	end
end

local function enTienda(pos: Vector3): boolean
	for caja in cajas do
		local rel = caja.CFrame:PointToObjectSpace(pos)
		local medio = caja.Size / 2
		if math.abs(rel.X) <= medio.X and math.abs(rel.Y) <= medio.Y and math.abs(rel.Z) <= medio.Z then
			return true
		end
	end
	return false
end

-- Un sitio entre los árboles a la distancia buena y de reojo en la vista (nunca el de la vez anterior).
local function elegir(vista: CFrame): Attachment?
	local lista = {}
	local abierto, cerrado = math.cos(math.rad(DE_REOJO[2])), math.cos(math.rad(DE_REOJO[1]))
	for punto in sombras do
		if punto == ultimaSombra or not punto.Parent then
			continue
		end
		local a = punto.WorldPosition + Vector3.new(0, 4.5, 0) - vista.Position
		local d = a.Magnitude
		if d >= L.Sombra.Lejos[1] and d <= L.Sombra.Lejos[2] then
			local c = vista.LookVector:Dot(a / d)
			if c >= abierto and c <= cerrado then
				table.insert(lista, punto)
			end
		end
	end
	return if #lista > 0 then lista[azar:NextInteger(1, #lista)] else nil
end

local function pasoSombra(dt: number, ahora: number, camara: Camera)
	local cine = camara.CameraType == Enum.CameraType.Scriptable
	local f = figura
	if f then
		if cine then
			borrarFigura() -- en una cinemática, fuera
		else
			moverFigura(f, dt, ahora, camara.CFrame)
		end
		return
	end
	if ahora < proximaSombra then
		return
	end
	local vista = camara.CFrame
	local punto = if cine or enTienda(vista.Position) then nil else elegir(vista)
	if not punto then
		proximaSombra = ahora + entre(REINTENTO)
		return
	end
	ultimaSombra = punto
	proximaSombra = ahora + entre(L.Sombra.Cada)
	figura = crearFigura(punto, ahora, vista.Position)
end

---------------------------------------------------------------- arranque

local avisado: { [string]: boolean } = {}
-- Cada parte en su pcall: si una falla, se avisa una vez y las demás siguen (el Bucle quitaría la tarea entera).
local function seguro(nombre: string, fn: (...any) -> (), ...: any)
	local ok, problema = pcall(fn, ...)
	if not ok and not avisado[nombre] then
		avisado[nombre] = true
		warn(`[GasolineraVista] {nombre}: {problema}`)
	end
end

function GasolineraVista.start()
	Sonido.precargar({ "Zumbido", "Parpadeo", "Nevera", "NeveraClac", "Radio", "Campanilla", "Rama", "Ramita" })

	seguir("LuzFalla", llegaLuz, seVaLuz)
	seguir("Polillas", function(cosa)
		if cosa:IsA("BasePart") and not polillas[cosa] then
			polillas[cosa] = {}
		end
	end, function(cosa)
		local lista = polillas[cosa :: BasePart]
		if lista then
			polillas[cosa :: BasePart] = nil
			borrarPolillas(lista)
		end
	end)
	seguir("PuertaAuto", llegaPuerta, seVaPuerta)
	seguir("Nevera", function(cosa)
		llegaAparato(cosa, "Nevera")
	end, seVaAparato)
	seguir("Radio", function(cosa)
		llegaAparato(cosa, "Radio")
	end, seVaAparato)
	seguir("Coche", llegaCoche, seVaCoche)
	seguir("Sombra", function(cosa)
		if cosa:IsA("Attachment") then
			sombras[cosa] = true
		end
	end, function(cosa)
		sombras[cosa :: Attachment] = nil
	end)
	seguir("Dentro", function(cosa)
		if cosa:IsA("BasePart") then
			cajas[cosa] = true
		end
	end, function(cosa)
		cajas[cosa :: BasePart] = nil
	end)

	proximaSombra = os.clock() + entre(L.Sombra.Cada) * 0.5 -- la primera, antes
	Bucle.cada("GasolineraVista", function(dt, ahora, camara)
		if not camara then
			return
		end
		local cam = camara.CFrame.Position
		local poco = jugador:GetAttribute("Rendimiento") == true -- se lee cada vez: cambia en marcha
		seguro("luces", pasoLuces, ahora, cam)
		seguro("polillas", pasoPolillas, ahora, cam, poco)
		seguro("puertas", pasoPuertas, ahora, cam)
		seguro("aparatos", pasoAparatos, ahora, cam)
		seguro("coches", pasoCoches, ahora, cam, poco)
		seguro("sombra", pasoSombra, dt, ahora, camara)
	end)
end

return GasolineraVista
