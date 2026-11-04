-- Avisos que se VEN para quien juega sin cascos (14.3, diseño: "persiana que tiembla, polvo que cae"; temblores, polvo
-- y cristales). Todo en el cliente, sin tocar el servidor: mira a los bichos de workspace.Bichos (los crea Caza en el
-- servidor y se replican; la raíz es su HumanoidRootPart) y saca de cada uno sus pisadas por lo que anda.
--   Algo llega a una ventana o puerta de fuera (antes del primer golpe, mientras se acerca y se planta): CasaVista.acecho
--     mece las cortinas hacia dentro, hace vibrar el cristal, suelta polvillo del marco y, pegado, empaña el cristal.
--   Pisadas de los bichos cerca (CFG.Bichos: zancada y peso de cada uno): retumbo grave, temblor de cámara muy suave
--     (nunca en cinemáticas; la Bestia ya tiene el suyo), vasos, platos y tarros que tiemblan, cuadros que se tuercen,
--     cristales que traquetean, lámparas colgantes que se balancean y bombillas que tiemblan.
--   Pisadas por encima (el Trepador en el tejado, un bicho en la planta de arriba): polvo y arenilla del techo justo
--     debajo de donde pisa.
--   Cristales: al romperse una ventana los trozos saltan hacia dentro, se quedan en el suelo hasta el amanecer (o hasta
--     que se repare) y crujen al pisarlos (jugadores y bichos).
-- La casa reacciona más a los bichos (pedido por el usuario: "que reaccionen más a los bichos"):
--   Mecedoras (la del cuarto de la abuela, con su manta, y la del porche): las pisadas y los golpes cerca las ponen a
--     mecerse solas; siguen un buen rato, cada vez más despacio, y crujen al dar la vuelta.
--   Lo que tiembla fuerte suena: platos, copas, tarros, botellas y el juego de té tintinean; latas, ollas y
--     candeleros repiquetean (el que más tiembla de cada pisada; con un golpe, los dos que más).
--   Polvo en el aire: tras un golpe, un portazo, la reja o una pisada pesada cerca (o por encima), motas que flotan
--     unos segundos delante de la cámara. A oscuras no se ven: brillan donde da la luz, sobre todo en el haz de la
--     linterna.
--   Corriente: con una ventana rota o una puerta echada abajo en la misma sala (sin pared en medio), las cortinas de
--     las demás ventanas se hinchan a rachas (CasaVista, `brisa`) y las lámparas colgantes se mecen, hasta repararla.
--   Con Rendimiento, sin mecedoras, sin polvo en el aire y sin corriente (el tintineo, que solo es sonido, sí).
-- Un solo Heartbeat que solo trabaja con lo que está cerca de la cámara. Lámparas y adornos de la casa se buscan al
-- cargar el mapa (y otra vez si cambia). Las bombillas tiemblan con Ambiente.factor, sin pisar el parpadeo de
-- DetallesVista (si DetallesVista está con una, se le deja).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Ambiente = require(script.Parent.Ambiente)
local CasaVista = require(script.Parent.CasaVista)
local Sonido = require(script.Parent.Sonido)

local Efectos = {}

-- Números a ojo.
local CFG = Config.Efectos

-- Adornos pequeños que tiemblan (modelos de la casa); los cuadros, por el principio del nombre.
local ADORNOS = {
	CopasPH = true, JarraPH = true, JarronPH = true, PlatoPH = true, TarroPH = true, TarrosSotano = true,
	CandeleroPH = true, CandelabroPH = true, LataOxidadaPH = true,
	JuegoTePH = true, Licores = true, LamparaAceitePH = true, LatasPH = true, OllaPH = true, SartenPH = true,
	FotoPH1 = true, FotoPH2 = true, RelojRepisaPH = true,
}
-- Los que suenan al temblar fuerte: vajilla y cristal (tintinean) o metal (repiquetean).
local SUENA: { [string]: string } = {
	CopasPH = "Vajilla", JarraPH = "Vajilla", JarronPH = "Vajilla", PlatoPH = "Vajilla", TarroPH = "Vajilla",
	TarrosSotano = "Vajilla", JuegoTePH = "Vajilla", Licores = "Vajilla", LamparaAceitePH = "Vajilla",
	CandeleroPH = "Metal", CandelabroPH = "Metal", LataOxidadaPH = "Metal", LatasPH = "Metal", OllaPH = "Metal",
	SartenPH = "Metal",
}
-- Números a ojo de lo nuevo (visuales, no de equilibrio).
local TINTINEO = {
	Desde = 0.35, -- lo fuerte que tiembla un adorno (de 0 a 1,4) para que suene
	Max = 1, -- como mucho por pisada (el que más tiembla)...
	MaxFuerte = 2, -- ...y por golpe o pisada de la Bestia (peso desde 1,2)
	Cada = { 0.8, 1.5 }, -- segundos entre dos del mismo adorno
	-- Mientras no haya uno propio ("Vajilla"): CristalVibra y Latas, más agudos, solo el principio y a este volumen.
	Vajilla = 0.55,
	Metal = 0.22,
	Corta = 0.3,
	Alcance = 30,
}
-- Mecedoras: se mecen sobre el canto de abajo, como un péndulo amortiguado.
local MECEDORAS = { MecedoraPH = true, Mecedora = true }
local MECE = {
	Alcance = 16, -- studs (en planta) de la pisada o el golpe a los que se pone a mecerse
	K = 12, -- (2π / periodo)²: unos 1,8 s de ida y vuelta
	Amortigua = 0.3, -- se va parando sola en unos 15-20 s
	Empuje = 0.14, -- radianes/s por pisada de peso 1 justo al lado
	Max = math.rad(5.5), -- lo más que se inclina
	Cruje = math.rad(1.8), -- con más que esto, cruje al dar la vuelta
	Quieta = math.rad(0.25), -- con menos vaivén que esto, se para
	Volumen = 0.4,
	Manta = 3, -- studs: la manta (otro modelo) más cerca que esto va con ella
}
-- Polvo que flota en el aire después de un golpe fuerte.
local POLVO_AIRE = {
	Motas = 26, -- por segundo con todo el polvo levantado
	Asienta = 10, -- segundos hasta que se asienta del todo
	Golpe = 16, -- studs de un golpe, un portazo o la reja a los que se levanta
	Pesado = 14, -- studs de una pisada de peso 1 o más
	Delante = CFrame.new(0, -0.3, -5), -- dónde nacen, respecto a la cámara (lo que alumbra la linterna)
	Zona = Vector3.new(7, 4.5, 8),
}
-- Corriente por una ventana rota o una puerta echada abajo.
local CORRIENTE = {
	Alcance = 18, -- studs en planta de la entrada del aire (y en la misma planta: menos de 7 de alto)
	Cerca = 45, -- studs de la cámara: más lejos no se mueve nada
	Dentro = 1.5, -- studs hacia la sala desde el centro de la ventana: de ahí sale el rayo que busca paredes
	Sube = 0.5, -- lo deprisa que llega y se va (por segundo)
	Lampara = 0.09, -- radianes/s de cada racha en una lámpara colgante
	Racha = { 1.2, 3 }, -- segundos entre dos rachas en la misma lámpara
}
local ENCENDIDA = Color3.fromRGB(255, 214, 160) -- los colores de la bombilla (como DetallesVista)
local APAGADA = Color3.fromRGB(70, 66, 60)
local COLOR_CRISTAL = Color3.fromRGB(170, 190, 200)

local jugador = Players.LocalPlayer
local azar = Random.new()

local function poco(): boolean
	return jugador:GetAttribute("Rendimiento") == true
end

local function plano(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function dentroDeCasa(p: Vector3): boolean
	return math.abs(p.X) < Config.Casa.MedioX and math.abs(p.Z) < Config.Casa.MedioZ and p.Y < 28
end

local carpeta: Folder -- lo de este módulo que está en el mundo (cristales del suelo)
local bichosCarpeta: Instance? = nil

-- Rayos que no chocan con bichos, personajes ni lo nuestro (lo que se pone aparte, en `mas`). Con `f`, lo reutiliza
-- (solo cambia su lista) en vez de crear otro.
local function filtro(mas: { Instance }?, f: RaycastParams?): RaycastParams
	local fuera: { Instance } = { carpeta }
	if bichosCarpeta then
		table.insert(fuera, bichosCarpeta)
	end
	for _, j in Players:GetPlayers() do
		if j.Character then
			table.insert(fuera, j.Character)
		end
	end
	for _, i in mas or {} do
		table.insert(fuera, i)
	end
	local params = f or RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = fuera
	return params
end

-- Dónde estaba cada pieza la primera vez que la vimos (su sitio de verdad): `buscar` puede volver a pasar con un
-- cuadro torcido o una lámpara movida, y no debe tomar esa pose como reposo.
local reposo: { [BasePart]: CFrame } = setmetatable({}, { __mode = "k" }) :: any

local function original(p: BasePart): CFrame
	local cf = reposo[p]
	if not cf then
		cf = p.CFrame
		reposo[p] = cf
	end
	return cf
end

-- Caja de unas piezas en su sitio original, en los ejes de `ejes` (sin él, los del mundo): centro (en el mundo) y
-- tamaño (en esos ejes).
local function caja(partes: { BasePart }, ejes: CFrame?): (Vector3, Vector3)
	local giro = if ejes then ejes.Rotation else CFrame.identity
	local menor, mayor = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in partes do
		local cf, t = giro:ToObjectSpace(original(p)), p.Size / 2
		local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
		local ext = Vector3.new(
			math.abs(r.X) * t.X + math.abs(u.X) * t.Y + math.abs(l.X) * t.Z,
			math.abs(r.Y) * t.X + math.abs(u.Y) * t.Y + math.abs(l.Y) * t.Z,
			math.abs(r.Z) * t.X + math.abs(u.Z) * t.Y + math.abs(l.Z) * t.Z)
		menor = menor:Min(cf.Position - ext)
		mayor = mayor:Max(cf.Position + ext)
	end
	return giro * ((menor + mayor) / 2), mayor - menor
end

-- Un modelo que no es de nadie: sin cartel para tocarlo ni etiqueta (lo de otros sistemas no se mueve).
local function libre(modelo: Instance): boolean
	return not modelo:FindFirstChildWhichIsA("ProximityPrompt", true) and #CollectionService:GetTags(modelo) == 0
end

local function piezasDe(modelo: Instance): { BasePart }
	local partes = {}
	for _, p in modelo:GetDescendants() do
		if p:IsA("BasePart") then
			table.insert(partes, p)
		end
	end
	return partes
end

-- De un sonido prestado de otra cosa, solo el principio: se apaga en un momento.
local function corta(s: Sound, segundos: number)
	task.delay(segundos, function()
		if s.Parent then
			TweenService:Create(s, TweenInfo.new(0.12), { Volume = 0 }):Play()
		end
	end)
end

---------------------------------------------------------------- lo que se mueve (adornos, cuadros, lámparas)

-- Un grupo de piezas que se mueve entero alrededor de `pivote` (cada pieza guarda dónde está respecto a él). Las
-- piezas son del servidor, ancladas y quietas: en el cliente se pueden mover y se devuelven a su sitio al parar.
type Movil = {
	partes: { BasePart },
	rel: { CFrame },
	pivote: CFrame,
	centro: Vector3, -- para medir distancias
	semilla: number,
	-- Adorno: tiembla `sacude` (baja solo). Cuadro: además se tuerce sobre `eje` (`giro` va hacia `torcido`).
	sacude: number,
	cuadro: boolean,
	eje: Vector3,
	giro: number,
	vgiro: number,
	torcido: number,
	-- Lámpara colgante: péndulo (ángulos sobre x y z del mundo).
	lampara: boolean,
	k: number, -- gravedad / largo
	angulo: Vector2,
	vel: Vector2,
	racha: number, -- cuándo le toca la siguiente racha de corriente (os.clock)
	-- Mecedora: se mece sobre el eje de lado de `pivote` (abajo en el centro, con sus ejes) con `giro` y `vgiro`.
	mecedora: boolean,
	lado: number, -- hacia dónde iba (1 o -1): cruje al dar la vuelta
	-- Lo que suena al temblar (SUENA) y cuándo puede volver a sonar.
	suena: string?,
	proximoSuena: number,
	ultimo: Vector3, -- dónde dejamos la primera pieza: si está en otro sitio, la ha movido otro módulo
	ajeno: boolean, -- y entonces no se toca hasta que vuelva a su sitio (revisarAjeno)
}
local adornos: { Movil } = {}
local lamparas: { Movil } = {}
local mecedoras: { Movil } = {}
type Bombilla = { luz: PointLight, pieza: BasePart }
local bombillas: { Bombilla } = {}
local activos: { [Movil]: boolean } = {}
local corrienteLampara: { [Movil]: number } = {} -- la corriente de una ventana rota que le llega a cada lámpara

local function movil(partes: { BasePart }, pivote: CFrame, centro: Vector3): Movil
	local rel = {}
	for i, p in partes do
		rel[i] = pivote:ToObjectSpace(original(p))
	end
	return {
		partes = partes, rel = rel, pivote = pivote, centro = centro, semilla = azar:NextNumber(0, 100), sacude = 0,
		cuadro = false, eje = Vector3.xAxis, giro = 0, vgiro = 0, torcido = 0, lampara = false, k = 0,
		angulo = Vector2.zero, vel = Vector2.zero, racha = 0, mecedora = false, lado = 1, suena = nil, proximoSuena = 0,
		ultimo = partes[1].Position, ajeno = false,
	}
end

local function colocarMovil(m: Movil, giro: CFrame)
	if m.ajeno or (m.partes[1].Position - m.ultimo).Magnitude > 0.2 then
		m.ajeno = true -- otro módulo lo ha movido (un susto, un cuadro que se cae): se le deja
		return
	end
	local cf = m.pivote * giro
	for i, p in m.partes do
		p.CFrame = cf * m.rel[i]
	end
	m.ultimo = m.partes[1].Position
end

-- Un móvil que movió otro módulo vuelve a ser nuestro cuando la pieza está otra vez en su sitio original (o donde la
-- dejamos nosotros).
local function revisarAjeno(m: Movil)
	if not m.ajeno or not m.partes[1].Parent then
		return
	end
	local pos = m.partes[1].Position
	if (pos - (m.pivote * m.rel[1]).Position).Magnitude < 0.2 then
		m.ajeno, m.ultimo = false, pos
		m.torcido, m.giro, m.vgiro = 0, 0, 0 -- recto en su sitio
	elseif (pos - m.ultimo).Magnitude < 0.2 then
		m.ajeno = false
		if m.cuadro and m.torcido ~= 0 and workspace:GetAttribute("Fase") == "Dia" then
			m.torcido = 0 -- se perdió el amanecer: a enderezarse
			activos[m] = true
		end
	end
end

-- Busca en la casa los adornos, los cuadros, las lámparas colgantes y las bombillas.
local function buscar(casa: Instance)
	-- Lo que se estaba moviendo, a su sitio (los cuadros, con lo que tuvieran de torcido).
	for m in activos do
		colocarMovil(m, if m.cuadro then CFrame.fromAxisAngle(m.eje, m.torcido) else CFrame.identity)
	end
	table.clear(activos)
	table.clear(corrienteLampara) -- eran de las lámparas de antes (se vuelve a mirar en medio segundo)
	-- Los de antes (por su primera pieza), para no perder lo torcido ni lo que tiene otro módulo.
	local previos: { [BasePart]: Movil } = {}
	for _, m in adornos do
		previos[m.partes[1]] = m
	end
	for _, m in lamparas do
		previos[m.partes[1]] = m
	end
	for _, m in mecedoras do
		previos[m.partes[1]] = m
	end
	local function heredar(m: Movil)
		local viejo = previos[m.partes[1]]
		if viejo then
			m.ajeno, m.ultimo = viejo.ajeno, viejo.ultimo
			if m.cuadro then
				m.torcido, m.giro = viejo.torcido, viejo.torcido
			end
		elseif (m.partes[1].Position - (m.pivote * m.rel[1]).Position).Magnitude > 0.2 then
			m.ajeno = true -- nuevo y ya fuera de su sitio: lo tiene otro módulo
		end
	end
	table.clear(adornos)
	table.clear(lamparas)
	table.clear(bombillas)
	table.clear(mecedoras)
	local sueltas: { BasePart } = {} -- piezas pequeñas (cables, cadenas, portalámparas)
	local aranas: { Model } = {}
	local sillas: { Model } = {} -- mecedoras
	local mantas: { Model } = {} -- la de la mecedora es otro modelo, encima
	for _, d in casa:GetDescendants() do
		if d:IsA("Model") then
			local esCuadro = string.sub(d.Name, 1, 6) == "Cuadro"
			if (ADORNOS[d.Name] or esCuadro) and libre(d) then
				local partes = piezasDe(d)
				if #partes > 0 then
					local centro, tam = caja(partes)
					if math.max(tam.X, tam.Y, tam.Z) < (if esCuadro then 6 else 4) then
						if esCuadro then
							-- Cuelga de un clavo arriba en el medio y se tuerce en el plano de la pared.
							local m = movil(partes, CFrame.new(centro + Vector3.new(0, tam.Y / 2, 0)), centro)
							m.cuadro = true
							m.eje = if tam.X < tam.Z then Vector3.xAxis else Vector3.zAxis
							heredar(m)
							table.insert(adornos, m)
						else
							local m = movil(partes, CFrame.new(centro - Vector3.new(0, tam.Y / 2, 0)), centro)
							m.suena = SUENA[d.Name]
							heredar(m)
							table.insert(adornos, m)
						end
					end
				end
			elseif string.sub(d.Name, 1, 5) == "Arana" then
				table.insert(aranas, d)
			elseif MECEDORAS[d.Name] and libre(d) then
				table.insert(sillas, d)
			elseif d.Name == "MantaMecedora" then
				table.insert(mantas, d)
			end
		elseif d:IsA("BasePart") then
			if d.Name == "Lampara" then
				local luz = d:FindFirstChildOfClass("PointLight")
				if luz then
					table.insert(bombillas, { luz = luz, pieza = d })
				end
			end
			if math.max(d.Size.X, d.Size.Y, d.Size.Z) < 3 then
				table.insert(sueltas, d)
			end
		end
	end

	local rayo = filtro()
	local usadas: { [BasePart]: boolean } = {}
	local function techoSobre(p: Vector3): number?
		local golpe = workspace:Raycast(p, Vector3.new(0, 10, 0), rayo)
		return golpe and golpe.Position.Y
	end
	local function colgar(partes: { BasePart }, eje: Vector3, techo: number, abajo: number)
		local m = movil(partes, CFrame.new(eje.X, techo, eje.Z), Vector3.new(eje.X, abajo, eje.Z))
		m.lampara = true
		m.k = CFG.Gravedad / math.max(1, techo - abajo)
		heredar(m)
		table.insert(lamparas, m)
	end
	-- Arañas (vestíbulo y comedor): el modelo entero, su cadena y su bombilla.
	for _, arana in aranas do
		local partes = piezasDe(arana)
		if #partes == 0 then
			continue
		end
		local centro, tam = caja(partes)
		local techo = techoSobre(centro)
		if not techo then
			continue
		end
		local arriba = centro.Y + tam.Y / 2
		for _, p in sueltas do
			local h = plano(p.Position - centro).Magnitude
			if (h < 0.4 and p.Position.Y > arriba - 0.5 and p.Position.Y < techo - 0.05 and p.Name ~= "Lampara")
				or (p.Name == "Lampara" and h < math.max(tam.X, tam.Z) / 2 + 0.5 and math.abs(p.Position.Y - centro.Y) < tam.Y / 2 + 0.5) then
				table.insert(partes, p)
				usadas[p] = true
			end
		end
		colgar(partes, centro, techo, centro.Y - tam.Y / 2)
	end
	-- Bombillas que cuelgan de un cable o una cadenilla (sótano, desván, cuartos): lo que hay entre ella y el techo.
	-- Hace falta algo fino que llegue al techo; si no, es una lámpara de mesa o de techo pegada (esas solo tiemblan).
	for _, b in bombillas do
		local bombilla = b.pieza
		if usadas[bombilla] then
			continue
		end
		local techo = techoSobre(bombilla.Position + Vector3.new(0, bombilla.Size.Y / 2 + 0.05, 0))
		if not techo or techo - bombilla.Position.Y < CFG.Colgada then
			continue
		end
		local partes = { bombilla }
		local cable = false
		for _, p in sueltas do
			if p ~= bombilla and plano(p.Position - bombilla.Position).Magnitude < 0.7
				and p.Position.Y > bombilla.Position.Y - 1.2 and p.Position.Y < techo - 0.05 then
				table.insert(partes, p)
				if math.min(p.Size.X, p.Size.Z) < 0.3 and p.Position.Y + p.Size.Y / 2 > techo - 0.4 then
					cable = true
				end
			end
		end
		if cable then
			colgar(partes, bombilla.Position, techo, bombilla.Position.Y)
		end
	end
	-- Mecedoras: los ejes salen de su pieza más grande (en el molde va sin girar, con el frente hacia -Z: la de
	-- Poly Haven es una sola malla y en la del porche es el asiento) y se mecen sobre el centro de abajo, donde los
	-- patines tocan el suelo (para ángulos pequeños es lo mismo que rodar: se hunden menos de 0,03 studs). La manta
	-- de encima (otro modelo) va con ella.
	for _, silla in sillas do
		local partes = piezasDe(silla)
		if #partes == 0 then
			continue
		end
		local mayor = partes[1]
		for _, p in partes do
			if p.Size.X * p.Size.Y * p.Size.Z > mayor.Size.X * mayor.Size.Y * mayor.Size.Z then
				mayor = p
			end
		end
		local ejes = original(mayor).Rotation
		local centro, tam = caja(partes, ejes)
		for i = #mantas, 1, -1 do
			local deManta = piezasDe(mantas[i])
			if #deManta > 0 and (caja(deManta) - centro).Magnitude < MECE.Manta then
				for _, p in deManta do
					table.insert(partes, p)
				end
				table.remove(mantas, i)
			end
		end
		local m = movil(partes, CFrame.new(centro - ejes.UpVector * (tam.Y / 2)) * ejes, centro)
		m.mecedora = true
		heredar(m)
		table.insert(mecedoras, m)
	end
	-- Para comprobar en Studio cuánto ha encontrado.
	carpeta:SetAttribute("Adornos", #adornos)
	carpeta:SetAttribute("Lamparas", #lamparas)
	carpeta:SetAttribute("Bombillas", #bombillas)
	carpeta:SetAttribute("Mecedoras", #mecedoras)
end

-- Un adorno que tiembla fuerte suena: la vajilla tintinea y el metal repiquetea. Mientras no haya uno propio
-- ("Vajilla"), el traqueteo del cristal (CristalVibra) y el de las latas, más agudos y solo el principio.
local function tintinear(m: Movil, k: number)
	local s: Sound
	if m.suena == "Metal" then
		s = Sonido.en("Latas", m.centro, azar:NextNumber(1.2, 1.45))
		s.Volume *= TINTINEO.Metal
		corta(s, TINTINEO.Corta)
	elseif Sonido.hay("Vajilla") then
		s = Sonido.en("Vajilla", m.centro, azar:NextNumber(0.94, 1.06))
	else
		s = Sonido.en("CristalVibra", m.centro, azar:NextNumber(1.3, 1.6))
		s.Volume *= TINTINEO.Vajilla
		corta(s, TINTINEO.Corta)
	end
	s.Volume *= math.clamp(k, 0.3, 1)
	s.RollOffMaxDistance = TINTINEO.Alcance
end

-- La mecedora cruje al dar la vuelta (más fuerte cuanto más se mece). Mientras no haya uno propio ("Mecedora"), el
-- crujido de la casa, más agudo y corto.
local function crujirMecedora(m: Movil)
	local s: Sound
	if Sonido.hay("Mecedora") then
		s = Sonido.en("Mecedora", m.centro, azar:NextNumber(0.94, 1.06))
	else
		s = Sonido.en("Cruje", m.centro, azar:NextNumber(1.15, 1.35))
		corta(s, 0.45)
	end
	s.Volume *= MECE.Volumen * math.clamp(math.abs(m.giro) / MECE.Max, 0.3, 1)
	s.RollOffMaxDistance = 30
end

-- Empuja la mecedora en el sentido en que ya va (quieta, hacia un lado al azar), como quien empuja un columpio, sin
-- pasar de MECE.Max: con el ángulo que ya tiene, la velocidad no pasa de la que la llevaría justo al tope.
local function mecer(m: Movil, empuje: number)
	if empuje <= 0 then
		return
	end
	local sentido = if m.vgiro > 0 then 1 elseif m.vgiro < 0 then -1 elseif azar:NextNumber() < 0.5 then -1 else 1
	local a = math.min(math.abs(m.giro), MECE.Max)
	local tope = math.sqrt(MECE.K * (MECE.Max * MECE.Max - a * a))
	m.vgiro = math.clamp(m.vgiro + sentido * empuje, -tope, tope)
	activos[m] = true
end

-- Una pisada hace temblar lo que hay cerca de `donde` (`fuerza` ya lleva el peso).
local function sacudirCosas(donde: Vector3, peso: number, encima: boolean)
	local alcance = CFG.Objetos
	local ahora = os.clock()
	local suenan: { { m: Movil, k: number } } = {}
	for _, m in adornos do
		local d = m.centro - donde
		local h = plano(d).Magnitude
		if h < alcance and math.abs(d.Y) < 9 and not m.ajeno then
			local k = peso * (1 - h / alcance)
			m.sacude = math.max(m.sacude, k)
			if m.cuadro and k > 0.3 then
				local paso = math.rad(CFG.Cuadro) * k * (if azar:NextNumber() < 0.5 then -1 else 1)
				m.torcido = math.clamp(m.torcido + paso, -math.rad(CFG.CuadroMax), math.rad(CFG.CuadroMax))
				m.vgiro += paso * 6
			end
			if m.suena and k > TINTINEO.Desde and ahora >= m.proximoSuena then
				table.insert(suenan, { m = m, k = k })
			end
			activos[m] = true
		end
	end
	-- Suenan los que más tiemblan (no todos a la vez: sería un estruendo).
	table.sort(suenan, function(a, b)
		return a.k > b.k
	end)
	for i = 1, math.min(if peso >= 1.2 then TINTINEO.MaxFuerte else TINTINEO.Max, #suenan) do
		local s = suenan[i]
		s.m.proximoSuena = ahora + azar:NextNumber(TINTINEO.Cada[1], TINTINEO.Cada[2])
		tintinear(s.m, s.k)
	end
	-- Las mecedoras se ponen a mecerse (con Rendimiento, no: es un adorno animado).
	if not poco() then
		for _, m in mecedoras do
			local d = m.centro - donde
			local h = plano(d).Magnitude
			if h < MECE.Alcance and math.abs(d.Y) < 9 and not m.ajeno then
				mecer(m, peso * (1 - h / MECE.Alcance) * MECE.Empuje)
			end
		end
	end
	for _, m in lamparas do
		local d = m.pivote.Position - donde
		local h = plano(d).Magnitude
		if h < alcance and d.Y > -4 and d.Y < 16 and not m.ajeno then
			local k = peso * (1 - h / alcance) * CFG.Empuje * (if encima then 1.6 else 1)
			local a = azar:NextNumber(0, math.pi * 2)
			m.vel += Vector2.new(math.cos(a), math.sin(a)) * k
			activos[m] = true
		end
	end
	for el, e in CasaVista.elementos do
		local vibrar = e.vibrar
		if vibrar and el.Parent then
			local d = e.centro.Position - donde
			local h = plano(d).Magnitude
			if h < alcance * 0.75 and math.abs(d.Y) < 10 then
				vibrar(peso * (1 - h / (alcance * 0.75)))
			end
		end
	end
end

local function moverActivos(dt: number, ahora: number, camara: Vector3)
	for m in activos do
		if m.ajeno then
			activos[m] = nil
			continue
		end
		if not m.partes[1].Parent or (m.centro - camara).Magnitude > CFG.Cerca then
			if m.partes[1].Parent then
				colocarMovil(m, if m.cuadro then CFrame.fromAxisAngle(m.eje, m.torcido) else CFrame.identity) -- el cuadro, torcido
			end
			m.sacude, m.vel, m.angulo = 0, Vector2.zero, Vector2.zero
			m.giro, m.vgiro = m.torcido, 0
			activos[m] = nil
			continue
		end
		if m.mecedora then
			-- Péndulo amortiguado (con el paso acotado: un tirón de fotogramas no la dispara). Con Rendimiento, quieta.
			local paso = math.min(dt, 0.05)
			if poco() then
				m.giro, m.vgiro = 0, 0
			end
			m.vgiro += (-m.giro * MECE.K - m.vgiro * MECE.Amortigua) * paso
			m.giro += m.vgiro * paso
			local lado = if m.vgiro >= 0 then 1 else -1
			if lado ~= m.lado then
				m.lado = lado
				if math.abs(m.giro) > MECE.Cruje then
					crujirMecedora(m)
				end
			end
			-- El vaivén que le queda (el ángulo al que llegaría con la velocidad que lleva).
			if m.giro * m.giro + m.vgiro * m.vgiro / MECE.K < MECE.Quieta * MECE.Quieta then
				m.giro, m.vgiro = 0, 0
				colocarMovil(m, CFrame.identity)
				activos[m] = nil
			else
				colocarMovil(m, CFrame.Angles(m.giro, 0, 0))
			end
			continue
		end
		if m.lampara then
			local fuerza = -m.angulo * m.k - m.vel * CFG.Amortigua
			m.vel += fuerza * dt
			m.angulo += m.vel * dt
			if m.angulo.Magnitude > CFG.MaxAngulo then
				m.angulo = m.angulo.Unit * CFG.MaxAngulo
			end
			if m.angulo.Magnitude < 0.002 and m.vel.Magnitude < 0.004 then
				m.angulo, m.vel = Vector2.zero, Vector2.zero
				activos[m] = nil
			end
			colocarMovil(m, CFrame.Angles(m.angulo.X, 0, m.angulo.Y))
			continue
		end
		m.sacude = math.max(0, m.sacude - dt * 2.5)
		local s = m.sacude
		local t = ahora * 32
		if m.cuadro then
			-- Muelle hacia lo torcido, con un temblor encima.
			m.vgiro += ((m.torcido - m.giro) * 50 - m.vgiro * 7) * dt
			m.giro += m.vgiro * dt
			local temblor = math.noise(t, m.semilla) * 0.03 * s
			colocarMovil(m, CFrame.fromAxisAngle(m.eje, m.giro + temblor))
			if s <= 0 and math.abs(m.torcido - m.giro) < 0.001 and math.abs(m.vgiro) < 0.002 then
				activos[m] = nil
			end
		else
			-- Vasos y tarros: tiemblan y dan saltitos sobre la balda.
			local n = m.semilla
			colocarMovil(m, CFrame.new(math.noise(t, n) * 0.05 * s, math.abs(math.noise(t, n + 3)) * 0.04 * s,
				math.noise(t, n + 7) * 0.05 * s) * CFrame.Angles(math.noise(t, n + 11) * 0.06 * s, math.noise(t, n + 13) * 0.1 * s,
				math.noise(t, n + 17) * 0.06 * s))
			if s <= 0 then
				colocarMovil(m, CFrame.identity)
				activos[m] = nil
			end
		end
	end
end

---------------------------------------------------------------- bombillas

-- Bombilla temblando: luz → hasta cuándo, cuánto puede bajar y lo último que le pusimos (si Ambiente.factor ya no lo
-- tiene, es que DetallesVista está con ella: se le deja).
type Parpadeo = { b: Bombilla, hasta: number, minimo: number, siguiente: number, ultimo: number? }
local parpadeos: { [PointLight]: Parpadeo } = {}

local function temblarBombilla(b: Bombilla, fuerza: number)
	if parpadeos[b.luz] or not b.luz.Enabled or Ambiente.factor[b.luz] ~= nil then
		return
	end
	parpadeos[b.luz] = {
		b = b, hasta = os.clock() + azar:NextNumber(0.25, 0.6), minimo = math.clamp(1 - fuerza * 0.7, 0.25, 0.85),
		siguiente = 0, ultimo = nil,
	}
end

local function moverBombillas(ahora: number)
	for luz, p in parpadeos do
		local actual = Ambiente.factor[luz]
		if not luz.Parent or (actual ~= nil and actual ~= p.ultimo) then
			parpadeos[luz] = nil -- quitada o en manos de DetallesVista
			continue
		end
		if ahora > p.hasta or not luz.Enabled then
			if actual ~= nil then
				Ambiente.factor[luz] = nil
			end
			if luz.Enabled then
				p.b.pieza.Color = ENCENDIDA
			end
			parpadeos[luz] = nil
			continue
		end
		if ahora > p.siguiente then
			p.siguiente = ahora + azar:NextNumber(0.03, 0.08)
			local f = azar:NextNumber(p.minimo, 1)
			p.ultimo = f
			Ambiente.factor[luz] = f
			p.b.pieza.Color = APAGADA:Lerp(ENCENDIDA, f)
		end
	end
end

---------------------------------------------------------------- polvo en el aire

local polvoAire = 0 -- de 0 a 1: lo que flota ahora; se asienta solo
local motas: ParticleEmitter? = nil
local zonaMotas: BasePart? = nil
local polvoAsentado = 0 -- cuándo se asentó el último polvo (la caja se borra 6,5 s después del último)

-- Un golpe, un portazo o una pisada fuerte levanta polvo (con Rendimiento, nada: son partículas de adorno).
local function levantarPolvo(cuanto: number)
	if cuanto > 0.02 and not poco() then
		polvoAire = math.max(polvoAire, math.min(cuanto, 1))
	end
end

-- Las motas nacen en una caja delante de la cámara (lo que alumbra la linterna) y se quedan flotando donde nacen, sin
-- ir con ella. Con LightInfluence 1, a oscuras no se ven: brillan donde da la luz.
local function hacerMotas(): ParticleEmitter
	local zona = Instance.new("Part")
	zona.Name = "PolvoAire"
	zona.Anchored = true
	zona.CanCollide = false
	zona.CanQuery = false
	zona.CanTouch = false
	zona.CastShadow = false
	zona.Transparency = 1
	zona.Size = POLVO_AIRE.Zona
	zona.Parent = carpeta
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(214, 204, 186))
	e.LightInfluence = 1
	e.LightEmission = 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.07, 0.03), NumberSequenceKeypoint.new(1, 0.06, 0.03) })
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.35), NumberSequenceKeypoint.new(0.75, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(3.5, 6)
	e.Speed = NumberRange.new(0.05, 0.25)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -0.05, 0) -- bajan muy despacio
	e.Drag = 0.5
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-25, 25)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Rate = 0
	e.Parent = zona
	zonaMotas = zona
	return e
end

-- Solo con la cámara dentro de la casa y fuera de cinemáticas; las que ya flotan se apagan solas. Asentado del todo,
-- la caja se borra cuando se apagan las últimas motas (si no ha vuelto a hacer falta).
local function moverPolvoAire(dt: number, camara: CFrame)
	if polvoAire <= 0 then
		return
	end
	polvoAire = math.max(0, polvoAire - dt / POLVO_AIRE.Asienta)
	local e, zona = motas, zonaMotas
	if not e or not zona or not zona:IsDescendantOf(workspace) then
		e = hacerMotas()
		motas, zona = e, zonaMotas
	end
	local sale = polvoAire > 0 and dentroDeCasa(camara.Position) and not poco()
		and workspace.CurrentCamera.CameraType ~= Enum.CameraType.Scriptable
	e.Rate = if sale then POLVO_AIRE.Motas * polvoAire else 0
	if sale and zona then
		zona.CFrame = camara * POLVO_AIRE.Delante
	end
	if polvoAire <= 0 then
		local asentado = os.clock()
		polvoAsentado = asentado
		task.delay(6.5, function()
			-- (si después hubo otra ráfaga ya asentada, espera a la suya: que sus motas no se borren de golpe)
			if polvoAire <= 0 and polvoAsentado == asentado and zona and zonaMotas == zona then
				zona:Destroy()
				zonaMotas, motas = nil, nil
			end
		end)
	end
end

---------------------------------------------------------------- pisadas

type Bicho = {
	modelo: Model,
	raiz: BasePart,
	datos: { Zancada: number, Pies: number, Peso: number, SinTemblor: boolean? },
	antes: Vector3,
	andado: number,
}
local bichos: { [Model]: Bicho } = {}

local function apuntarBicho(modelo: Instance)
	if not modelo:IsA("Model") or not CFG.Bichos[modelo.Name] then
		return
	end
	local raiz = modelo:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	if raiz then
		bichos[modelo] = { modelo = modelo, raiz = raiz, datos = CFG.Bichos[modelo.Name], antes = raiz.Position, andado = 0 }
	end
end

-- Todo lo que tiembla con una pisada o un golpe en `donde`: adornos, cuadros, lámparas, cristales y bombillas.
local function temblarCerca(donde: Vector3, peso: number, fuerza: number, encima: boolean)
	sacudirCosas(donde, peso, encima)
	for _, bombilla in bombillas do
		local d = bombilla.pieza.Position - donde
		if plano(d).Magnitude < CFG.Objetos and math.abs(d.Y) < 12 and azar:NextNumber() < CFG.Bombilla * peso then
			temblarBombilla(bombilla, fuerza)
		end
	end
end

local rayoTecho: RaycastParams? = nil
local rayoHora = 0

-- Polvo del techo justo debajo de una pisada que va por encima de la cámara.
local function polvoTecho(pies: Vector3, camara: Vector3, fuerza: number)
	local desde = Vector3.new(pies.X + azar:NextNumber(-0.5, 0.5), camara.Y + 1, pies.Z + azar:NextNumber(-0.5, 0.5))
	if not dentroDeCasa(desde) then
		return
	end
	if not rayoTecho or os.clock() - rayoHora > 3 then
		rayoTecho, rayoHora = filtro(nil, rayoTecho), os.clock()
	end
	local golpe = workspace:Raycast(desde, Vector3.new(0, math.max(1, pies.Y - desde.Y + 0.5), 0), rayoTecho)
	if not golpe then
		return
	end
	CasaVista.polvo(CFrame.new(golpe.Position - Vector3.new(0, 0.12, 0)), Vector3.new(1.6, 0.1, 1.6),
		math.ceil(CFG.PolvoTecho * math.clamp(fuerza, 0.3, 1)))
	if azar:NextNumber() < 0.5 then
		local s = Sonido.en("Polvo", golpe.Position, azar:NextNumber(0.9, 1.1))
		s.Volume *= math.clamp(fuerza, 0.3, 1)
	end
end

local function pisada(b: Bicho, pies: Vector3, camara: Vector3)
	local distancia = (pies - camara).Magnitude
	if distancia > CFG.Pasos then
		return
	end
	local peso = b.datos.Peso
	local fuerza = peso * (1 - distancia / CFG.Pasos)
	local encima = pies.Y - camara.Y > CFG.Encima and plano(pies - camara).Magnitude < CFG.EncimaPlanta
	local retumbo = Sonido.en("Retumbo", pies, azar:NextNumber(0.5, 0.62))
	retumbo.Volume *= CFG.Retumbo * fuerza * (if encima then 1.3 else 1)
	if not b.datos.SinTemblor then
		CasaVista.temblar(pies, CFG.Temblor * peso, CFG.AlcanceTemblor)
	end
	if encima and dentroDeCasa(camara) then
		polvoTecho(pies, camara, fuerza)
	end
	-- Lo que tiembla: lo de la sala de debajo si pisa encima; si no, lo de alrededor.
	local donde = if encima then Vector3.new(pies.X, camara.Y, pies.Z) else pies
	temblarCerca(donde, peso, fuerza, encima)
	-- Y el polvo que se queda flotando: lo que cae del techo o lo que levanta algo muy pesado al lado.
	if encima then
		levantarPolvo(fuerza * 0.6)
	elseif peso >= 1 and distancia < POLVO_AIRE.Pesado then
		levantarPolvo((1 - distancia / POLVO_AIRE.Pesado) * 0.7)
	end
end

local function moverBichos(camara: Vector3)
	for modelo, b in bichos do
		if not modelo.Parent or not b.raiz.Parent then
			bichos[modelo] = nil
			continue
		end
		local pos = b.raiz.Position
		local movido = pos - b.antes
		b.antes = pos
		-- En la pared cuenta también lo que sube; en el suelo y el tejado, solo en planta.
		local d = (if modelo:GetAttribute("Trepando") then movido else plano(movido)).Magnitude
		if d > 8 or modelo:GetAttribute("Bajando") or (pos - camara).Magnitude > CFG.Cerca then
			continue -- un salto, dentro del tiro o lejos
		end
		b.andado += d
		if b.andado >= b.datos.Zancada then
			b.andado = 0
			pisada(b, pos - Vector3.new(0, b.datos.Pies, 0), camara)
		end
	end
end

---------------------------------------------------------------- algo fuera de una ventana o puerta

type Acecho = { p: number, plantado: number }
local acechos: { [Model]: Acecho } = {}

local function moverAcechos(dt: number, camara: Vector3)
	if next(bichos) == nil and next(acechos) == nil then
		return -- sin bichos y sin ninguno a medio irse: nada que mirar en cada ventana
	end
	for el, e in CasaVista.elementos do
		if not el.Parent then
			continue
		end
		local a = acechos[el]
		local centro = e.centro
		local objetivo, plantado, cabeza = 0, 0, nil
		if (centro.Position - camara).Magnitude < CFG.Cerca then
			local mejor = math.huge
			for modelo, b in bichos do
				if modelo.Name == "Acechador" then
					continue -- solo en el bosque
				end
				local raiz = b.raiz.Position
				local desdeCristal = raiz - centro.Position
				if desdeCristal:Dot(centro.LookVector) < 0.3 then
					continue -- dentro de la casa
				end
				local cerca = desdeCristal.Magnitude - 1.5
				if e.fuera and math.abs(raiz.Y - b.datos.Pies - e.fuera.Y) < 12 then
					cerca = math.min(cerca, plano(raiz - e.fuera).Magnitude)
				end
				if cerca < mejor then
					mejor, cabeza = cerca, raiz + Vector3.new(0, b.datos.Pies * 0.35, 0)
				end
			end
			objetivo = math.max(math.clamp(1 - (mejor - 2) / (CFG.Acerca - 2), 0, 1),
				math.clamp(1 - (mejor - CFG.Plantado) / (CFG.Pegado - CFG.Plantado), 0, 1) * 0.8)
			plantado = if mejor < CFG.Plantado then 1 else 0
		end
		if not a then
			if objetivo <= 0 then
				continue
			end
			a = { p = 0, plantado = 0 }
			acechos[el] = a
		end
		local paso = dt * CFG.Suaviza
		a.p += math.clamp(objetivo - a.p, -paso, paso)
		a.plantado += math.clamp(plantado - a.plantado, -paso, paso)
		if a.p <= 0.005 and objetivo <= 0 then
			acechos[el] = nil
			e.acecho(0, 0, nil)
		else
			e.acecho(a.p, a.plantado, cabeza)
		end
	end
	for el in acechos do
		if not CasaVista.elementos[el] then
			acechos[el] = nil
		end
	end
end

---------------------------------------------------------------- corriente por una ventana rota

local corrienteVentana: { [Model]: number } = {} -- lo que debería llegarle a cada ventana (se mira cada medio segundo)
local corrientes: { [Model]: number } = {} -- lo que le llega ahora a cada ventana (suavizado)
local proximoMirar = 0
-- Reutilizados en cada mirada (cada medio segundo) en vez de crearlos.
local entradas: { Vector3 } = {}
local fueraCorriente: { Instance } = {} -- lo que no corta el aire: cortinas y lámparas
local rayoCorriente: RaycastParams? = nil

-- Por dónde entra el aire: un cristal roto o una ventana o puerta echada abajo.
local function entraAire(el: Model): boolean
	return (el:GetAttribute("Cristal") or 0) >= Config.Casa.GolpesCristal or (el:GetAttribute("Vida") or 1) <= 0
end

-- Cada medio segundo: de dónde entra aire cerca y a qué ventanas y lámparas llega. Llega de la entrada más cercana en
-- la misma planta y sin pared en medio (un rayo de sala a sala, sin las ventanas, que tienen el cristal).
local function mirarCorrientes(camara: Vector3)
	table.clear(corrienteVentana)
	table.clear(corrienteLampara)
	table.clear(entradas)
	table.clear(fueraCorriente)
	if poco() or not dentroDeCasa(camara) then
		return
	end
	local fuera = fueraCorriente
	for el, e in CasaVista.elementos do
		if el.Parent and entraAire(el) and (e.centro.Position - camara).Magnitude < CORRIENTE.Cerca + CORRIENTE.Alcance then
			table.insert(entradas, e.centro.Position - e.centro.LookVector * CORRIENTE.Dentro)
		end
		if e.brisa then
			table.insert(fuera, el)
		end
	end
	if #entradas == 0 then
		return
	end
	for _, m in lamparas do
		for _, p in m.partes do
			table.insert(fuera, p)
		end
	end
	local rayo = filtro(fuera, rayoCorriente)
	rayoCorriente = rayo
	local function llega(aqui: Vector3): number
		local mejor = 0
		for _, entrada in entradas do
			local d = entrada - aqui
			local h = plano(d).Magnitude
			local k = 1 - h / CORRIENTE.Alcance
			if h > 1 and k > mejor and math.abs(d.Y) < 7 and not workspace:Raycast(aqui, d, rayo) then
				mejor = k
			end
		end
		return mejor
	end
	for el, e in CasaVista.elementos do
		if e.brisa and el.Parent and (e.centro.Position - camara).Magnitude < CORRIENTE.Cerca then
			local k = llega(e.centro.Position - e.centro.LookVector * CORRIENTE.Dentro)
			if k > 0 then
				corrienteVentana[el] = k
			end
		end
	end
	for _, m in lamparas do
		if not m.ajeno and (m.centro - camara).Magnitude < CORRIENTE.Cerca then
			local k = llega(m.centro - Vector3.new(0, 0.4, 0))
			if k > 0 then
				corrienteLampara[m] = k
			end
		end
	end
end

-- Cada fotograma: las cortinas van poco a poco hacia la corriente que les llega (y vuelven a quedarse quietas) y las
-- lámparas reciben una racha de vez en cuando.
local function moverCorrientes(dt: number, ahora: number, camara: Vector3)
	if ahora >= proximoMirar then
		proximoMirar = ahora + 0.5
		mirarCorrientes(camara)
	end
	if next(corrienteVentana) == nil and next(corrientes) == nil and next(corrienteLampara) == nil then
		return
	end
	local paso = dt * CORRIENTE.Sube
	for el, e in CasaVista.elementos do
		local brisa = e.brisa
		local actual = corrientes[el]
		local objetivo = corrienteVentana[el] or 0
		if not brisa or (not actual and objetivo <= 0) then
			continue
		end
		local nueva = (actual or 0) + math.clamp(objetivo - (actual or 0), -paso, paso)
		if nueva <= 0.002 and objetivo <= 0 then
			corrientes[el] = nil
			brisa(0)
		else
			corrientes[el] = nueva
			brisa(nueva)
		end
	end
	for el in corrientes do
		if not CasaVista.elementos[el] then
			corrientes[el] = nil
		end
	end
	for m, k in corrienteLampara do
		if ahora >= m.racha and not m.ajeno and m.partes[1].Parent then
			m.racha = ahora + azar:NextNumber(CORRIENTE.Racha[1], CORRIENTE.Racha[2])
			local a = azar:NextNumber(0, math.pi * 2)
			m.vel += Vector2.new(math.cos(a), math.sin(a)) * CORRIENTE.Lampara * k
			activos[m] = true
		end
	end
end

---------------------------------------------------------------- cristales del suelo

type Trozo = { p: BasePart, v: Vector3, gira: Vector3, botes: number, nace: number }
type Campo = {
	el: Model,
	trozos: { BasePart },
	volando: { Trozo },
	centro: Vector3,
	radio: number,
	filtro: RaycastParams,
	filtroHora: number, -- se rehace cada pocos segundos (los personajes que reaparecen)
	conexion: RBXScriptConnection?, -- la de "reparada"
}
local campos: { Campo } = {}
local crujidos: { [Instance]: Vector3 } = setmetatable({}, { __mode = "k" }) :: any -- quién → dónde crujió por última vez
local piesAntes: { [Instance]: Vector3 } = setmetatable({}, { __mode = "k" }) :: any -- quién → dónde tenía los pies en la última mirada
local ultimaPisada = 0

local function barrer(campo: Campo)
	local i = table.find(campos, campo)
	if i then
		table.remove(campos, i)
	end
	if campo.conexion then
		campo.conexion:Disconnect()
		campo.conexion = nil
	end
	for _, t in campo.volando do
		table.insert(campo.trozos, t.p)
	end
	table.clear(campo.volando)
	for _, p in campo.trozos do
		TweenService:Create(p, TweenInfo.new(2.5), { Transparency = 1 }):Play()
		task.delay(2.6, p.Destroy, p)
	end
end

-- La ventana se rompe: los trozos saltan hacia dentro, rebotan y se quedan en el suelo.
local function romper(el: Model, centro: CFrame, ancho: number, alto: number)
	for _, c in campos do
		if c.el == el then
			barrer(c)
			break
		end
	end
	if #campos >= CFG.MaxVentanas then
		barrer(campos[1])
	end
	local dentro = -centro.LookVector
	local campo: Campo = {
		el = el, trozos = {}, volando = {}, centro = centro.Position + dentro * 2, radio = 6, filtro = filtro({ el }),
		filtroHora = os.clock(), conexion = nil,
	}
	table.insert(campos, campo)
	local n = if poco() then math.ceil(CFG.Trozos / 2) else CFG.Trozos
	for _ = 1, n do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Glass
		p.Color = COLOR_CRISTAL
		p.Transparency = 0.35
		p.Reflectance = 0.12
		p.Size = Vector3.new(azar:NextNumber(0.1, 0.5), 0.035, azar:NextNumber(0.1, 0.4))
		p.CFrame = centro * CFrame.new(azar:NextNumber(-ancho / 2.2, ancho / 2.2), azar:NextNumber(-alto / 2.2, alto / 2.2), 0.2)
			* CFrame.Angles(azar:NextNumber(0, 6), azar:NextNumber(0, 6), azar:NextNumber(0, 6))
		p.Parent = carpeta
		local lado = centro.RightVector * azar:NextNumber(-4, 4)
		table.insert(campo.volando, {
			p = p, v = dentro * azar:NextNumber(7, 16) + lado + Vector3.new(0, azar:NextNumber(-1, 4), 0),
			gira = Vector3.new(azar:NextNumber(-14, 14), azar:NextNumber(-14, 14), azar:NextNumber(-14, 14)), botes = 0,
			nace = os.clock(),
		})
	end
	-- Reparada: se barren (barrer quita la conexión, también si se barre por otra cosa).
	campo.conexion = el:GetAttributeChangedSignal("Cristal"):Connect(function()
		if (el:GetAttribute("Cristal") or 0) < Config.Casa.GolpesCristal and table.find(campos, campo) then
			barrer(campo)
		end
	end)
end

-- Un trozo que llega al suelo: tumbado sobre lo que ha tocado, girado al azar.
local function posar(p: BasePart, donde: Vector3, normal: Vector3)
	local lado = normal:Cross(Vector3.new(azar:NextNumber(-1, 1), 0.01, azar:NextNumber(-1, 1)).Unit)
	if lado.Magnitude < 0.01 then
		lado = normal:Cross(Vector3.xAxis)
	end
	p.CFrame = CFrame.fromMatrix(donde + normal * 0.02, lado.Unit, normal)
end

local function crujir(campo: Campo, trozo: BasePart, fuerza: number)
	local s = Sonido.en("Cristal", trozo.Position, azar:NextNumber(1.7, 2.1)) -- provisional: falta uno de pisar cristales
	s.Volume *= 0.2 * fuerza
	task.delay(0.25, function()
		if s.Parent then
			TweenService:Create(s, TweenInfo.new(0.12), { Volume = 0 }):Play()
		end
	end)
	-- El trozo pisado se mueve un poco (y se parte en dos si es grande).
	trozo.CFrame *= CFrame.new(azar:NextNumber(-0.08, 0.08), 0, azar:NextNumber(-0.08, 0.08)) * CFrame.Angles(0, azar:NextNumber(-0.6, 0.6), 0)
	if trozo.Size.X > 0.3 and #campo.trozos < CFG.Trozos * 1.5 then
		trozo.Size = Vector3.new(trozo.Size.X / 2, trozo.Size.Y, trozo.Size.Z)
		local otro = trozo:Clone()
		otro.CFrame = trozo.CFrame * CFrame.new(trozo.Size.X * 0.7, 0, azar:NextNumber(-0.1, 0.1)) * CFrame.Angles(0, azar:NextNumber(-1, 1), 0)
		otro.Parent = carpeta
		table.insert(campo.trozos, otro)
	end
end

-- Distancia en planta de `p` al tramo `a`-`b` (lo andado desde la última mirada).
local function aTramo(p: Vector3, a: Vector3, b: Vector3): number
	local ab = plano(b - a)
	local largo = ab:Dot(ab)
	local t = if largo > 1e-4 then math.clamp(plano(p - a):Dot(ab) / largo, 0, 1) else 0
	return (plano(p - a) - ab * t).Magnitude
end

-- Los del suelo crujen al pisarlos. Se mira cada 0,1 s y solo con campos cerca de la cámara; para no saltarse
-- trozos entre dos miradas se mira todo el tramo andado.
local cerca: { Campo } = {} -- los campos cerca de la cámara en esta mirada (reutilizada)

-- Si `quien` ha pisado algún trozo de los campos de `cerca` desde la última mirada, cruje.
local function pisa(quien: Instance, pies: Vector3, fuerza: number)
	local antes = piesAntes[quien] or pies
	piesAntes[quien] = pies
	if (pies - antes).Magnitude > 8 then
		antes = pies -- un salto grande (reaparece, lo mueven): solo cuenta donde está
	end
	for _, campo in cerca do
		if aTramo(campo.centro, antes, pies) > campo.radio + 2 then
			continue
		end
		for _, trozo in campo.trozos do
			local d = trozo.Position
			if math.abs(d.Y - pies.Y) < 1.6 and aTramo(d, antes, pies) < CFG.Pisar then
				local ultimo = crujidos[quien]
				if not ultimo or (pies - ultimo).Magnitude > CFG.CadaCrujido then
					crujidos[quien] = pies
					crujir(campo, trozo, fuerza)
				end
				return
			end
		end
	end
end

local function pisarCristales(camara: Vector3)
	table.clear(cerca)
	for _, campo in campos do
		if #campo.trozos > 0 and (campo.centro - camara).Magnitude <= CFG.Cerca then
			table.insert(cerca, campo)
		end
	end
	if #cerca == 0 then
		table.clear(piesAntes)
		return
	end
	-- Quién puede pisarlos: los jugadores y los bichos (con dónde tienen los pies).
	for _, j in Players:GetPlayers() do
		local personaje = j.Character
		local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humano = personaje and personaje:FindFirstChildOfClass("Humanoid")
		if personaje and raiz and humano and humano.Health > 0 then
			pisa(personaje, raiz.Position - Vector3.new(0, humano.HipHeight + raiz.Size.Y / 2, 0), 1)
		end
	end
	for modelo, b in bichos do
		pisa(modelo, b.raiz.Position - Vector3.new(0, b.datos.Pies, 0), 1.5)
	end
end

local function moverCristales(dt: number, ahora: number, camara: Vector3)
	if #campos == 0 then
		if next(piesAntes) then
			table.clear(piesAntes)
		end
		return
	end
	for _, campo in campos do
		if #campo.volando > 0 and ahora - campo.filtroHora > 3 then
			campo.filtro, campo.filtroHora = filtro({ campo.el }, campo.filtro), ahora -- con los personajes de ahora
		end
		-- Los que vuelan: caen, rebotan una vez y se posan.
		for i = #campo.volando, 1, -1 do
			local t = campo.volando[i]
			t.v += Vector3.new(0, -70, 0) * dt
			local desde = t.p.Position
			local golpe = workspace:Raycast(desde, t.v * dt, campo.filtro)
			if golpe then
				local n = golpe.Normal
				if t.botes == 0 and t.v.Magnitude > 9 and n.Y > 0.5 then
					t.botes = 1
					t.v = (t.v - 2 * t.v:Dot(n) * n) * 0.25
					t.p.CFrame = CFrame.new(golpe.Position + n * 0.05) * t.p.CFrame.Rotation
				elseif n.Y > 0.5 then
					posar(t.p, golpe.Position, n)
					table.remove(campo.volando, i)
					table.insert(campo.trozos, t.p)
				else
					t.v = (t.v - 2 * t.v:Dot(n) * n) * 0.3 -- contra una pared o un mueble: rebota y sigue cayendo
				end
			elseif ahora - t.nace > 4 then
				t.p:Destroy() -- se ha ido por un hueco
				table.remove(campo.volando, i)
			else
				t.p.CFrame = (t.p.CFrame + t.v * dt) * CFrame.Angles(t.gira.X * dt, t.gira.Y * dt, t.gira.Z * dt)
			end
		end
	end
	if ahora - ultimaPisada >= 0.1 then
		ultimaPisada = ahora
		pisarCristales(camara)
	end
end

---------------------------------------------------------------- arranque

function Efectos.start()
	carpeta = Instance.new("Folder")
	carpeta.Name = "EfectosLocales"
	carpeta.Parent = workspace
	CasaVista.alRomper = romper
	CasaVista.alGolpe = function(donde: Vector3)
		local d = (donde - workspace.CurrentCamera.CFrame.Position).Magnitude
		if d < CFG.Pasos then
			temblarCerca(donde, CFG.Golpe, CFG.Golpe * (1 - d / CFG.Pasos), false)
		end
		if d < POLVO_AIRE.Golpe then
			levantarPolvo(1 - d / POLVO_AIRE.Golpe)
		end
	end

	-- Al amanecer se barren los cristales y los cuadros vuelven rectos (de noche se quedan torcidos, a propósito).
	workspace:GetAttributeChangedSignal("Fase"):Connect(function()
		if workspace:GetAttribute("Fase") == "Dia" then
			for _, campo in table.clone(campos) do
				barrer(campo)
			end
			for _, m in adornos do
				if m.cuadro and not m.ajeno and m.torcido ~= 0 then
					m.torcido = 0
					activos[m] = true
				end
			end
		end
	end)

	task.spawn(function()
		local bichosC = workspace:WaitForChild("Bichos")
		bichosCarpeta = bichosC
		bichosC.ChildAdded:Connect(apuntarBicho)
		for _, modelo in bichosC:GetChildren() do
			task.spawn(apuntarBicho, modelo)
		end
	end)

	-- La casa: se busca lo que se mueve al cargar y otra vez cuando cambia (llegan modelos o luces a la casa), 2 s
	-- después del último cambio y como mucho cada 15 s.
	local cambio, ultima = os.clock(), -math.huge
	local sucio = true
	task.spawn(function()
		local mapa = workspace:WaitForChild("Mapa")
		mapa.DescendantAdded:Connect(function(d)
			if d:IsA("Model") or d:IsA("Light") then
				local casa = mapa:FindFirstChild("Casa")
				if d == casa or (casa and d:IsDescendantOf(casa)) then
					sucio, cambio = true, os.clock()
				end
			end
		end)
		while true do
			task.wait(1)
			for _, m in adornos do
				revisarAjeno(m)
			end
			for _, m in lamparas do
				revisarAjeno(m)
			end
			for _, m in mecedoras do
				revisarAjeno(m)
			end
			local casa = mapa:FindFirstChild("Casa")
			local ahora = os.clock()
			if sucio and casa and ahora - cambio > 2 and ahora - ultima > 15 then
				sucio, ultima = false, ahora
				buscar(casa)
			end
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		local ahora = os.clock()
		local vista = workspace.CurrentCamera.CFrame
		local camara = vista.Position
		moverBichos(camara)
		moverAcechos(dt, camara)
		moverCorrientes(dt, ahora, camara)
		moverActivos(dt, ahora, camara)
		moverBombillas(ahora)
		moverCristales(dt, ahora, camara)
		moverPolvoAire(dt, vista)
	end)
end

return Efectos
