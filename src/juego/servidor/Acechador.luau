-- El Acechador: al anochecer (desde los últimos segundos del día), al que sigue fuera de la casa le sale detrás en el
-- bosque. Primero le sigue de lejos, entre los árboles, partiendo ramas; si le mira, se queda quieto como un tronco.
-- Luego se le echa encima corriendo más que él. Se rinde si vuelves a la luz de la casa (Config.Acechador.Refugio);
-- la linterna lo frena un momento (y luego tarda en volver a frenarlo). Al amanecer se va. Si te escondes fuera (los
-- armarios de la granja, el granero, la iglesia y el pueblo) no te suelta: espera quieto cerca, partiendo ramas,
-- Config.Acechador.Aguarda segundos y carga si sales antes; si aguantas, se va (y escondido no corre el tiempo).
-- Cada uno va a por una sola presa. Remote Acechador para el cliente (AcechadorVista): "Rama", "Carga", "Luz".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Bichos = require(script.Parent.Bichos)
local Caza = require(script.Parent.Caza)
local Ciclo = require(script.Parent.Ciclo)
local Cuerpo = require(script.Parent.Cuerpo)
local FinPartida = require(script.Parent.FinPartida)
local Muerte = require(script.Parent.Muerte)

local Acechador = {}

local A = Config.Acechador
local ALTURA = 7.5 -- altísimo: de los pies al centro de la raíz
local azar = Random.new()
local plano = Caza.plano

type Ataque = { bicho: Caza.Bicho?, hilo: thread?, prisa: boolean, presa: Player }
local ataques: { [Ataque]: boolean } = {}
local fuera: { [Player]: number } = {} -- segundos seguidos fuera, a oscuras
local espera: { [Player]: number } = {} -- los que le tocan esperar a este hasta que le salga

-- Con niebla cerrada (Caza.esNiebla) acecha y sale más cerca (Config.Caza.Niebla.Acechador): entre la niebla se le ve
-- la silueta y se nota que se queda quieto al mirarle. Sin niebla, 1.
local function porNiebla(): number
	return if Caza.esNiebla() then Config.Caza.Niebla.Acechador else 1
end

local function rango(r: { number }): number
	return azar:NextNumber(r[1], r[2])
end

-- Corteza oscura y húmeda, ramas que le salen de la cabeza; por una raja del pecho se le ve la carne.
local CORTEZA, OSCURA, CARNE, SANGRE = Color3.fromRGB(52, 46, 40), Color3.fromRGB(28, 25, 22), Color3.fromRGB(108, 30, 28),
	Color3.fromRGB(70, 6, 6)

local function crear(cf: CFrame): Caza.Bicho
	local m, raiz = Cuerpo.nuevo("Acechador", cf)
	local function miembro(...)
		return Cuerpo.miembro(m, ...)
	end
	local function pegar(...)
		Cuerpo.pegar(m, ...)
	end

	-- Flaquísimo y altísimo (unos 14 studs), un poco encorvado; brazos hasta las rodillas con dedos como ramitas.
	local torso = miembro("Torso", Vector3.new(1.6, 4.5, 0.9), raiz, CFrame.new(0, -0.6, 0) * CFrame.Angles(-0.25, 0, 0),
		CFrame.new(0, -2.25, 0), CORTEZA)
	pegar(torso, Vector3.new(0.5, 2.2, 0.1), CFrame.new(0.1, 0.4, -0.46) * CFrame.Angles(0, 0, 0.1), CARNE) -- la raja
	for i = 0, 3 do
		pegar(torso, Vector3.new(0.7, 0.1, 0.12), CFrame.new(0.1, -0.4 + i * 0.4, -0.5), Color3.fromRGB(190, 180, 156)) -- costillas
	end
	pegar(torso, Vector3.new(0.12, 1.4, 0.05), CFrame.new(0.25, -1.2, -0.47), SANGRE)

	local cabeza = miembro("Cabeza", Vector3.new(1, 1.8, 1.1), torso, CFrame.new(0, 2.3, -0.2) * CFrame.Angles(0.3, 0, 0),
		CFrame.new(0, -0.8, 0.2), OSCURA)
	-- Dos puntitos claros por ojos (brillan un poco con la linterna) y una boca vertical, como una grieta en el tronco.
	for _, x in { -0.22, 0.22 } do
		pegar(cabeza, Vector3.new(0.09, 0.09, 0.05), CFrame.new(x, 0.35, -0.57), Color3.fromRGB(200, 196, 170), Enum.Material.Neon)
	end
	pegar(cabeza, Vector3.new(0.18, 0.9, 0.06), CFrame.new(0, -0.35, -0.56), Color3.fromRGB(18, 0, 0))
	local mandibula = miembro("Mandibula", Vector3.new(0.8, 0.3, 0.9), cabeza, CFrame.new(0, -0.9, 0.2), CFrame.new(0, 0, 0.4), OSCURA)
	pegar(mandibula, Vector3.new(0.08, 0.6, 0.05), CFrame.new(-0.1, -0.2, -0.46), SANGRE)
	-- Ramas: cuernos torcidos que se abren hacia arriba, con alguna ramita.
	for _, lado in { -1, 1 } do
		for j, datos in { { 2.4, 0.5, 0.35 }, { 1.7, 0.9, -0.2 } } do
			local largo, abre, inclina = datos[1], datos[2], datos[3]
			local donde = CFrame.new(lado * 0.3, 0.8, 0) * CFrame.Angles(inclina, 0, -lado * abre) * CFrame.new(0, largo / 2, 0)
			pegar(cabeza, Vector3.new(0.14, largo, 0.14), donde, OSCURA, Enum.Material.Wood)
			pegar(cabeza, Vector3.new(0.08, 0.9, 0.08), donde * CFrame.new(0, largo * 0.25, 0) * CFrame.Angles(0, 0, lado * 0.8 * j)
				* CFrame.new(0, 0.45, 0), OSCURA, Enum.Material.Wood)
		end
	end

	for _, lado in { -1, 1 } do
		local brazo = miembro(if lado < 0 then "BrazoI" else "BrazoD", Vector3.new(0.4, 7, 0.4), torso,
			CFrame.new(lado * 1.0, 2.0, 0) * CFrame.Angles(0.15, 0, 0), CFrame.new(0, 3.3, 0), CORTEZA)
		for i = -1, 1 do
			pegar(brazo, Vector3.new(0.08, 1.4, 0.08), CFrame.new(i * 0.12, -4.1, 0) * CFrame.Angles(0, 0, i * 0.35), OSCURA, Enum.Material.Wood)
		end
	end
	for _, lado in { -1, 1 } do
		miembro(if lado < 0 then "PiernaI" else "PiernaD", Vector3.new(0.6, 6.6, 0.6), raiz, CFrame.new(lado * 0.55, -0.9, 0),
			CFrame.new(0, 3.3, 0), OSCURA)
	end

	local humanoide = Cuerpo.terminar(m, Caza.carpeta(), ALTURA, A.Andar)
	return Caza.nuevo(m, humanoide, {
		Altura = ALTURA,
		Andar = A.Andar,
		Correr = A.Correr,
		Pillar = A.Pillar,
		Vista = 0,
		VioEsconderse = 0,
	})
end

local function raizDe(jugador: Player): BasePart?
	local personaje = jugador.Character
	return personaje and personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- El garaje pegado a la cocina (Mapa, construirGaraje), paredes incluidas: x1, x2, z1, z2. No está en
-- Config.Casa.Anexos (lo usan otros sistemas, Fachada entre ellos), pero es una sala cerrada de la casa.
local GARAJE = { -59.5, -39, 2.5, 33.5 }

-- A salvo: dentro de la casa (la torre, los anexos y las esquinas se salen del radio de la luz), en el garaje, cerca de
-- la luz de la casa o bajo tierra (el sótano y su escalera están debajo de la casa, no en el bosque: ahí no pinta
-- "Run. Get back to the light.").
local function aSalvo(posicion: Vector3): boolean
	local g = GARAJE
	local enGaraje = posicion.X > g[1] and posicion.X < g[2] and posicion.Z > g[3] and posicion.Z < g[4]
	return Caza.dentroDeCasa(posicion) or enGaraje or plano(posicion).Magnitude < A.Refugio or posicion.Y < -2
end

-- ¿Ya es hora? De noche, o en los últimos segundos del día (cuando suena el aviso de que se pone el sol).
local function oscuro(): boolean
	local fase, n = Ciclo.fase()
	if n < A.Noche then
		return false
	elseif fase == "Noche" then
		return true
	end
	return (workspace:GetAttribute("FaseFin") or 0) - workspace:GetServerTimeNow() < Config.Ciclo.Aviso
end

-- El suelo de verdad debajo de `p` (el bosque no es del todo plano): un rayo desde poco más arriba (p.Y + 8) y solo
-- contra lo que choca. Antes tiraba desde y = 120 contra todo y salía en las copas, los troncos o los tejados. Baja 40
-- studs y, si la presa está en alto (la torre de la colina, a 44 studs del suelo), hasta y = -30 como poco.
-- nil si da en algo a más de 3 studs por encima de los pies de la presa (`pies`: un tronco caído, un tejado) o si no
-- cabe de pie (Caza.cabe: dentro de un tronco, una roca o una casa, que el rayo no ve desde dentro).
local filtro = RaycastParams.new()
filtro.FilterType = Enum.RaycastFilterType.Exclude
filtro.RespectCanCollide = true
local function suelo(p: Vector3, pies: number): Vector3?
	local ignorar: { Instance } = { Caza.carpeta() }
	for _, jugador in Players:GetPlayers() do
		if jugador.Character then
			table.insert(ignorar, jugador.Character)
		end
	end
	filtro.FilterDescendantsInstances = ignorar
	local desde = p.Y + 8
	local golpe = workspace:Raycast(Vector3.new(p.X, desde, p.Z), Vector3.new(0, -math.max(40, desde + 30), 0), filtro)
	if not golpe or golpe.Position.Y > pies + 3 or not Caza.cabe(golpe.Position, ALTURA) then
		return nil
	end
	return golpe.Position
end

-- Por dónde sale, a A.Lejos + 14 studs de la presa (`r`, su raíz) o a `dist` (con niebla, más cerca: porNiebla):
-- primero a su espalda según hacia dónde mira (su cabeza) y luego del lado contrario a la casa. Nunca entre ella y la
-- casa (le cortaría el camino de vuelta a la luz; al volver, lo lleva a la espalda) ni en el cono de su cabeza
-- (A.Cono): antes salía justo delante de quien se alejaba de la casa. Cada giro con algo de azar, para que no salga
-- siempre en el mismo sitio.
local GIROS_ESPALDA = { 0, 0.35, -0.35, 0.7, -0.7 }
local GIROS_FUERA = { 0, 0.45, -0.45, 0.9, -0.9, 1.25, -1.25, 1.5, -1.5 }
local function salidas(presa: Player, r: BasePart, dist: number?): { Vector3 }
	local afuera = plano(r.Position)
	afuera = if afuera.Magnitude > 0.1 then afuera.Unit else Vector3.zAxis
	local cabeza = presa.Character and presa.Character:FindFirstChild("Head") :: BasePart?
	local mira = plano((cabeza or r).CFrame.LookVector)
	mira = if mira.Magnitude > 0.1 then mira.Unit else afuera
	local cono = math.cos(math.rad(A.Cono))
	local pies = r.Position.Y - 3 -- la raíz va a unos 3 studs del suelo
	local azarGiro = azar:NextNumber(-0.15, 0.15)
	local aSalir = dist or (A.Lejos + 14)
	local sitios = {}
	local probadas: { Vector3 } = {}
	local function repetida(d: Vector3): boolean
		for _, otra in probadas do
			if d:Dot(otra) > 0.99 then
				return true -- casi la misma (de cara a la casa, su espalda y el lado de fuera coinciden)
			end
		end
		table.insert(probadas, d)
		return false
	end
	local function probar(hacia: Vector3, giros: { number })
		for _, giro in giros do
			local d = CFrame.Angles(0, giro + azarGiro, 0):VectorToWorldSpace(hacia)
			if d:Dot(afuera) >= 0 and d:Dot(mira) < cono and not repetida(d) then
				local p = suelo(r.Position + d * aSalir, pies)
				if p then
					table.insert(sitios, p)
				end
			end
		end
	end
	probar(-mira, GIROS_ESPALDA)
	probar(afuera, GIROS_FUERA)
	return sitios
end

local function ataque(a: Ataque)
	local presa = a.presa
	local r = raizDe(presa)
	if not r then
		return
	end
	-- Sale lejos, entre los árboles, donde no le vea aparecer nadie (Caza.sitioSinVer). Sin sitio, esta vez no sale.
	local sitios = salidas(presa, r, (A.Lejos + 14) * porNiebla())
	if #sitios == 0 then
		return
	end
	local p = Caza.sitioSinVer(sitios, ALTURA)
	local b = crear(CFrame.lookAt(p + Vector3.new(0, ALTURA, 0), Vector3.new(r.Position.X, p.Y + ALTURA, r.Position.Z)))
	a.bicho = b
	b.prisa = a.prisa
	local modelo = b.modelo :: Model

	-- Aún hay caza: viva, fuera de la luz, sin prisa (escondida fuera de la casa también cuenta: Aguarda).
	local function cazable(): boolean
		local rr = raizDe(presa)
		return not b.prisa and b.modelo ~= nil and rr ~= nil and Muerte.vivo(presa)
			and not aSalvo(rr.Position)
			and not workspace:GetAttribute("Bestia") -- la noche final solo está ella
	end
	local function sigue(): boolean
		return cazable() and Muerte.escondite(presa) == nil
	end
	local function iluminado(): boolean
		return os.clock() - b.iluminado < 0.6
	end

	-- Acecha: le sigue a `Lejos` studs (con niebla, más cerca); si le mira, quieto; si le alumbra, quieto un momento.
	local finAcecho = os.clock() + rango(A.Acecho)
	local rama = os.clock() + azar:NextNumber(0.5, 1.5)
	while os.clock() < finAcecho and sigue() do
		local rr = raizDe(presa) :: BasePart
		local hacia = plano(rr.Position - b.raiz.Position)
		local distancia = hacia.Magnitude
		local aLejos = A.Lejos * porNiebla()
		local leMira = distancia > 0.1 and plano(rr.CFrame.LookVector):Dot(-hacia.Unit) > 0.8
		if iluminado() and not b:quieto() then
			b:aturdir(A.Frena)
			Remotes.Acechador:FireAllClients("Luz", modelo)
		elseif leMira or distancia <= aLejos then
			b.humanoide:MoveTo(b.raiz.Position)
		else
			b.humanoide.WalkSpeed = A.Andar
			b:pasoHacia(rr.Position - hacia.Unit * (aLejos - 4) - Vector3.new(0, 3, 0))
		end
		if os.clock() > rama then
			Remotes.Acechador:FireAllClients("Rama", modelo)
			rama = os.clock() + rango(A.Rama)
		end
		task.wait(0.25)
	end

	-- Se le echa encima. true si acaba porque se ha escondido (fuera de la casa) en mitad de la carga.
	local function cargar(): boolean
		Remotes.Acechador:FireAllClients("Carga", modelo)
		Remotes.Aviso:FireClient(presa, Lang.t(presa, "Run. Get back to the light."))
		local fin = os.clock() + A.Persigue
		local inmune = 0
		while os.clock() < fin and sigue() do
			local ahora = os.clock()
			if iluminado() and ahora > inmune then
				b:aturdir(A.Frena)
				inmune = ahora + A.Frena + A.Inmune
				Remotes.Acechador:FireAllClients("Luz", modelo)
			end
			local rr = raizDe(presa) :: BasePart
			-- Sin nada en medio (Caza.alcanza): si te metes en un edificio y te pegas a la pared, no te pilla a través.
			if not b:quieto() and b:alcanza(presa, A.Pillar + A.MasPillar) then
				b.humanoide:MoveTo(b.raiz.Position)
				b:mirarA(rr.Position)
				Muerte.matar(presa, b:cabeza(), b.modelo)
				task.wait(A.TrasPillar)
				return false
			end
			b.humanoide.WalkSpeed = A.Correr
			b:pasoHacia(rr.Position - Vector3.new(0, 3, 0))
			task.wait(0.15)
		end
		return cazable() and Muerte.escondite(presa) ~= nil
	end

	-- Escondida fuera de la casa: no la suelta. Se acerca hasta `AguardaLejos` del escondite y se queda quieto, de cara
	-- a él, partiendo ramas (la linterna de otro le frena igual), `Aguarda` segundos. true si sale antes (carga); false
	-- si aguanta dentro (se va) o se acaba la caza.
	local function aguardar(): boolean
		local sitio = Muerte.escondite(presa)
		if not sitio then
			return false
		end
		local salida = sitio:GetAttribute("Salida")
		local donde = if typeof(salida) == "CFrame" then salida.Position else sitio:GetPivot().Position
		local fin = os.clock() + A.Aguarda
		while os.clock() < fin and cazable() do
			if Muerte.escondite(presa) == nil then
				return true
			end
			local hacia = plano(donde - b.raiz.Position)
			if iluminado() and not b:quieto() then
				b:aturdir(A.Frena)
				Remotes.Acechador:FireAllClients("Luz", modelo)
			elseif hacia.Magnitude > A.AguardaLejos and not b:quieto() then
				b.humanoide.WalkSpeed = A.Andar
				b:pasoHacia(donde - hacia.Unit * (A.AguardaLejos - 4) - Vector3.new(0, 3, 0))
			else
				b.humanoide:MoveTo(b.raiz.Position)
				if hacia.Magnitude > 0.1 then
					b:mirarA(donde)
				end
			end
			if os.clock() > rama then
				Remotes.Acechador:FireAllClients("Rama", modelo)
				rama = os.clock() + rango(A.Rama)
			end
			task.wait(0.25)
		end
		return false
	end

	-- Carga; si se esconde fuera (antes o durante la carga), espera junto al escondite y vuelve a cargar si sale.
	local esperas = 0
	while true do
		if cazable() and Muerte.escondite(presa) ~= nil then
			if esperas >= A.Aguardas then
				break
			end
			esperas += 1
			if not aguardar() then
				break
			end
		end
		if not sigue() or not cargar() then
			break
		end
	end

	-- Si llegó a la luz (o aguantó escondida): se queda mirando un momento desde los árboles y se va, sin esfumarse a
	-- la vista (Caza.perderse).
	if b.modelo then
		b.humanoide:MoveTo(b.raiz.Position)
		task.wait(if b.prisa then 0 else 2)
		local aqui = b:suelo() -- a ras de suelo, como lo espera irA (con la altura de la raíz nunca "llegaba")
		local afuera = if plano(aqui).Magnitude > 1 then plano(aqui).Unit else Vector3.zAxis
		b:perderse(aqui + afuera * 60, A.Andar, 10)
	end
end

local function terminar(a: Ataque)
	ataques[a] = nil
	if a.bicho then
		a.bicho:quitar()
		a.bicho = nil
	end
end

local function siguiendo(jugador: Player): boolean
	for a in ataques do
		if a.presa == jugador then
			return true
		end
	end
	return false
end

function Acechador.cuantos(): number
	local n = 0
	for _ in ataques do
		n += 1
	end
	return n
end

-- Sale a por `jugador` (también el modo de pruebas).
function Acechador.atacar(jugador: Player)
	local a: Ataque = { bicho = nil, hilo = nil, prisa = false, presa = jugador }
	ataques[a] = true
	a.hilo = task.spawn(function()
		-- Con pcall: si el ataque falla, el bicho se quita igual (si no, se quedaba en el mapa y en `ataques` para siempre).
		local ok, fallo = pcall(ataque, a)
		if not ok then
			warn("[Acechador] " .. tostring(fallo))
		end
		terminar(a)
	end)
end

function Acechador.irse()
	for a in ataques do
		a.prisa = true
		if a.bicho then
			a.bicho.prisa = true
		end
	end
end

function Acechador.quitar()
	for a in ataques do
		if a.hilo and coroutine.status(a.hilo) ~= "dead" then
			task.cancel(a.hilo)
		end
		terminar(a)
	end
end

-- Cada medio segundo: ¿quién lleva un rato fuera a oscuras?
local function vigilar()
	local activo = oscuro() and not FinPartida.acabada() and not workspace:GetAttribute("Bestia") -- la noche final solo sale ella
	for _, jugador in Players:GetPlayers() do
		local r = raizDe(jugador)
		local expuesto = activo and r ~= nil and not aSalvo(r.Position) and Muerte.vivo(jugador)
		if not expuesto or siguiendo(jugador) then
			fuera[jugador] = 0
			espera[jugador] = nil
			continue
		end
		if Muerte.escondite(jugador) then
			continue -- escondido fuera de la casa: no corre el tiempo para que le salga (ni se pierde lo que llevaba)
		end
		fuera[jugador] = (fuera[jugador] or 0) + 0.5
		espera[jugador] = espera[jugador] or rango(A.Espera)
		if fuera[jugador] >= espera[jugador] and Acechador.cuantos() < A.Max then
			fuera[jugador] = 0
			espera[jugador] = nil
			Acechador.atacar(jugador)
		end
	end
end

function Acechador.start()
	Bichos.registrar("Acechador", Acechador)
	Players.PlayerRemoving:Connect(function(jugador)
		fuera[jugador] = nil
		espera[jugador] = nil
		for a in ataques do
			if a.presa == jugador then
				a.prisa = true
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			vigilar()
		end
	end)
end

return Acechador
