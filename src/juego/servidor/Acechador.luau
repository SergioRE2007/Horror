-- El Acechador: al anochecer (desde los últimos segundos del día), al que sigue fuera de la casa le sale detrás en el
-- bosque. Primero le sigue de lejos, entre los árboles, partiendo ramas; si le mira, se queda quieto como un tronco.
-- Luego se le echa encima corriendo más que él. Se rinde si vuelves a la luz de la casa (Config.Acechador.Refugio);
-- la linterna lo frena un momento (y luego tarda en volver a frenarlo). Al amanecer se va.
-- Cada uno va a por una sola presa. Remote Acechador para el cliente (AcechadorVista): "Rama", "Carga", "Luz".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Caza = require(script.Parent.Caza)
local Ciclo = require(script.Parent.Ciclo)
local Cuerpo = require(script.Parent.Cuerpo)
local Muerte = require(script.Parent.Muerte)
local Partida = require(script.Parent.Partida)

local Acechador = {}

local A = Config.Acechador
local ALTURA = 7.5 -- altísimo: de los pies al centro de la raíz
local azar = Random.new()
local plano = Caza.plano

type Ataque = { bicho: Caza.Bicho?, hilo: thread?, prisa: boolean, presa: Player }
local ataques: { [Ataque]: boolean } = {}
local fuera: { [Player]: number } = {} -- segundos seguidos fuera, a oscuras
local espera: { [Player]: number } = {} -- los que le tocan esperar a este hasta que le salga

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

local function aSalvo(posicion: Vector3): boolean
	return plano(posicion).Magnitude < A.Refugio
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

-- El suelo debajo de un punto (el bosque no es del todo plano).
local filtro = RaycastParams.new()
filtro.FilterType = Enum.RaycastFilterType.Exclude
local function suelo(p: Vector3): Vector3
	local ignorar: { Instance } = { Caza.carpeta() }
	for _, jugador in Players:GetPlayers() do
		if jugador.Character then
			table.insert(ignorar, jugador.Character)
		end
	end
	filtro.FilterDescendantsInstances = ignorar
	local golpe = workspace:Raycast(Vector3.new(p.X, 120, p.Z), Vector3.new(0, -200, 0), filtro)
	return if golpe then golpe.Position else Vector3.new(p.X, 0, p.Z)
end

local function ataque(a: Ataque)
	local presa = a.presa
	local r = raizDe(presa)
	if not r then
		return
	end
	-- Sale lejos, entre los árboles, del lado contrario a la casa: nunca le corta el camino de vuelta a la luz (y al
	-- volver, lo lleva a la espalda).
	local atras = plano(r.Position)
	atras = if atras.Magnitude > 0.1 then atras.Unit else Vector3.zAxis
	atras = CFrame.Angles(0, azar:NextNumber(-0.9, 0.9), 0):VectorToWorldSpace(atras)
	local p = suelo(r.Position + atras * (A.Lejos + 14))
	local b = crear(CFrame.lookAt(p + Vector3.new(0, ALTURA, 0), Vector3.new(r.Position.X, p.Y + ALTURA, r.Position.Z)))
	a.bicho = b
	b.prisa = a.prisa
	local modelo = b.modelo :: Model

	local function sigue(): boolean
		local rr = raizDe(presa)
		return not b.prisa and b.modelo ~= nil and rr ~= nil and table.find(Muerte.vivos(), presa) ~= nil
			and not aSalvo(rr.Position) and Muerte.escondite(presa) == nil
	end
	local function iluminado(): boolean
		return os.clock() - b.iluminado < 0.6
	end

	-- Acecha: le sigue a `Lejos` studs; si le mira, quieto; si le alumbra, quieto un momento.
	local finAcecho = os.clock() + rango(A.Acecho)
	local rama = os.clock() + azar:NextNumber(0.5, 1.5)
	while os.clock() < finAcecho and sigue() do
		local rr = raizDe(presa) :: BasePart
		local hacia = plano(rr.Position - b.raiz.Position)
		local distancia = hacia.Magnitude
		local leMira = distancia > 0.1 and plano(rr.CFrame.LookVector):Dot(-hacia.Unit) > 0.8
		if iluminado() and not b:quieto() then
			b:aturdir(A.Frena)
			Remotes.Acechador:FireAllClients("Luz", modelo)
		elseif leMira or distancia <= A.Lejos then
			b.humanoide:MoveTo(b.raiz.Position)
		else
			b.humanoide.WalkSpeed = A.Andar
			b:pasoHacia(rr.Position - hacia.Unit * (A.Lejos - 4) - Vector3.new(0, 3, 0))
		end
		if os.clock() > rama then
			Remotes.Acechador:FireAllClients("Rama", modelo)
			rama = os.clock() + rango(A.Rama)
		end
		task.wait(0.25)
	end

	-- Se le echa encima.
	if sigue() then
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
			if not b:quieto() and (rr.Position - b.raiz.Position).Magnitude < A.Pillar + 2 then
				b.humanoide:MoveTo(b.raiz.Position)
				b:mirarA(rr.Position)
				Muerte.matar(presa, b:cabeza())
				task.wait(2.5)
				break
			end
			b.humanoide.WalkSpeed = A.Correr
			b:pasoHacia(rr.Position - Vector3.new(0, 3, 0))
			task.wait(0.15)
		end
	end

	-- Si llegó a la luz: se queda mirando un momento desde los árboles y se va.
	if b.modelo then
		b.humanoide:MoveTo(b.raiz.Position)
		task.wait(if b.prisa then 0 else 2)
		local aqui = b.raiz.Position
		local afuera = if plano(aqui).Magnitude > 1 then plano(aqui).Unit else Vector3.zAxis
		b:irA(aqui + afuera * 60, A.Andar, 10)
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
		ataque(a)
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
	local activo = oscuro() and not Partida.terminada()
	for _, jugador in Players:GetPlayers() do
		local r = raizDe(jugador)
		local expuesto = activo and r ~= nil and not aSalvo(r.Position) and table.find(Muerte.vivos(), jugador) ~= nil
		if not expuesto or siguiendo(jugador) then
			fuera[jugador] = 0
			espera[jugador] = nil
			continue
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
