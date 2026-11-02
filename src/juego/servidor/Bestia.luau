-- La Bestia: el bicho del final difícil (12.2, TASKS.md). Es el origen de todos los demás.
--   Bestia.soltar(): empieza la noche final. Los demás bichos se van y el Director no lanza ninguno más mientras
--   Bestia.activa(). A los Config.Bestia.Espera s sale del borde del bosque delante de la puerta principal, ruge, la
--   revienta y entra. Dentro caza como los demás (Caza): persigue a quien ve, le saca del escondite si le vio esconderse
--   y pilla. Corre más que el jugador: sin bengalas te pilla.
--   Bestia.herir(s): una bengala; cojea esos segundos (más lenta) y ruge. El flash de la cámara no la para.
--   Bestia.encerrar(dentro): la reja ha caído; si está dentro del sótano queda atrapada: no sale (si se cuela, vuelve),
--   solo pilla a quien esté dentro con ella; a quien ve fuera cerca, va hacia él y golpea la reja. Si no, ronda el sótano.
--   Bestia.quemar(): chillido largo y desaparece; caen todos los bichos.
--   Bestia.activa(): es la noche final (desde soltar hasta irse o quitar, también después de quemarla).
--   Bestia.irse(): amanece (se va al bosque). Bestia.quitar(): fuera del mapa al momento.
-- Remote Bestia (a todos), para BestiaVista: ("Ruge", modelo), ("Golpe", modelo) contra la reja o la puerta,
-- ("Herida", modelo), ("Atrapada", modelo), ("Quema", modelo), ("Flash", modelo). Atributos del modelo: "Cojea" (hora
-- del servidor hasta la que cojea), "Atrapada", "Quema". En workspace, atributo "Bestia" = es la noche final.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Acechador: any -- se carga en start(): Acechador -> Partida -> Preparativos -> Bestia sería un require circular
local Casa = require(script.Parent.Casa)
local Caza = require(script.Parent.Caza)
local Cuerpo = require(script.Parent.Cuerpo)
local Golpeador = require(script.Parent.Golpeador)
local Imitador = require(script.Parent.Imitador)
local Mapa = require(script.Parent.Mapa)
local Muerte = require(script.Parent.Muerte)
local Raspador = require(script.Parent.Raspador)
local Trepador = require(script.Parent.Trepador)

local Bestia = {}

local B = Config.Bestia
local ALTURA = B.Altura
local azar = Random.new()
local plano = Caza.plano

local VIO_ESCONDERSE = Config.Bestia.VioEsconderse
local BORDE = Config.Bestia.Borde
local RUGIDO = Config.Bestia.Rugido
local QUEMA = Config.Bestia.Quema
local SOBRESALTO = Config.Bestia.Sobresalto
local CERCA_REJA = Config.Bestia.CercaReja
local CADA_GOLPE = Config.Bestia.CadaGolpe

type Estado = {
	bicho: Caza.Bicho?,
	hilo: thread?,
	yendose: boolean, -- amanece: ya no es la noche final (se va andando)
	atrapada: boolean,
	dentro: ((Vector3) -> boolean)?,
	centro: Vector3?, -- donde quedó atrapada (ronda alrededor)
	cojeaHasta: number, -- os.clock
	quemada: boolean,
}
local actual: Estado? = nil

-- Piel gris oscura casi negra, tirante, con heridas abiertas; hueso amarillento; sangre seca y fresca.
local PIEL, OSCURA, HUESO = Color3.fromRGB(46, 43, 42), Color3.fromRGB(24, 22, 22), Color3.fromRGB(150, 138, 108)
local CARNE, SANGRE, SECA = Color3.fromRGB(96, 24, 22), Color3.fromRGB(70, 6, 6), Color3.fromRGB(38, 8, 6)

local function crear(cf: CFrame): Caza.Bicho
	local m, raiz = Cuerpo.nuevo("Bestia", cf)
	local function miembro(...)
		return Cuerpo.miembro(m, ...)
	end
	local function pegar(...)
		Cuerpo.pegar(m, ...)
	end

	-- Enorme, a cuatro patas como un gorila: lomo largo que sube hacia unos hombros altos (unos 8,5 studs), brazos más
	-- largos que las piernas, cabeza baja y alargada delante del pecho. Provisional hasta el modelo de verdad.
	-- El torso gira desde las caderas (atrás y abajo): la parte de delante queda más alta.
	local torso = miembro("Torso", Vector3.new(4.4, 3, 6.2), raiz, CFrame.new(0, -0.4, 2.4) * CFrame.Angles(0.2, 0, 0),
		CFrame.new(0, -1.2, 3), PIEL)
	-- Joroba de los hombros y espinazo de huesos que asoman por el lomo.
	pegar(torso, Vector3.new(3.6, 1.2, 2.8), CFrame.new(0, 1.5, -1.7) * CFrame.Angles(0.15, 0, 0), PIEL)
	for i = 0, 6 do
		local alto = if i < 3 then 0.6 else 0.7 - (i - 3) * 0.1
		local base = if i < 3 then 2.0 else 1.4 -- los de delante salen de la joroba
		pegar(torso, Vector3.new(0.35, alto, 0.4), CFrame.new(0, base + alto / 2, -2.6 + i * 0.85)
			* CFrame.Angles(0.45, 0, 0), HUESO)
	end
	-- Costillas marcadas a los dos lados, con la carne abierta entre ellas en un costado.
	for _, lado in { -1, 1 } do
		for i = 0, 4 do
			pegar(torso, Vector3.new(0.12, 2.2, 0.22), CFrame.new(lado * 2.22, -0.1, -2.2 + i * 0.75) * CFrame.Angles(0, 0, lado * 0.08), OSCURA)
		end
	end
	pegar(torso, Vector3.new(0.1, 1.6, 2.4), CFrame.new(2.21, 0, -1), CARNE)
	pegar(torso, Vector3.new(0.12, 0.8, 0.5), CFrame.new(2.24, -0.9, -1.4), SANGRE)
	-- Pecho y vientre manchados de sangre de lo que ha comido, chorretones que cuelgan.
	pegar(torso, Vector3.new(2.6, 1.8, 0.12), CFrame.new(0, -0.3, -3.1), SECA)
	pegar(torso, Vector3.new(1.4, 1.2, 0.14), CFrame.new(-0.4, -0.5, -3.12), SANGRE)
	for _, x in { -0.9, -0.2, 0.6 } do
		local largo = azar:NextNumber(0.6, 1.4)
		pegar(torso, Vector3.new(0.14, largo, 0.1), CFrame.new(x, -1.5 - largo / 2 + 0.2, -2.6), SANGRE)
	end

	-- Cabeza baja y alargada, colgando delante del pecho, sin nariz: una cara lisa con muchos ojos y la boca enorme.
	local cabeza = miembro("Cabeza", Vector3.new(2.2, 1.8, 2.8), torso, CFrame.new(0, 0.7, -3) * CFrame.Angles(-0.4, 0, 0),
		CFrame.new(0, 0.3, 1.2), PIEL)
	pegar(cabeza, Vector3.new(2.4, 0.5, 1.6), CFrame.new(0, 0.85, -0.55), OSCURA) -- frente abultada sobre los ojos
	-- Seis ojos pequeños, hundidos y desordenados, con un puntito claro al fondo (los Neon son de 0,06: no brillan).
	for _, ojo in { { -0.6, 0.45 }, { 0.55, 0.5 }, { -0.25, 0.65 }, { 0.3, 0.3 }, { -0.75, 0.15 }, { 0.8, 0.2 } } do
		local x, y = ojo[1], ojo[2]
		pegar(cabeza, Vector3.new(0.3, 0.26, 0.1), CFrame.new(x, y, -1.41) * CFrame.Angles(0, 0, azar:NextNumber(-0.4, 0.4)),
			Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
		pegar(cabeza, Vector3.new(0.06, 0.06, 0.05), CFrame.new(x, y, -1.47), Color3.fromRGB(170, 160, 130), Enum.Material.Neon)
	end
	-- Boca: un agujero negro rojizo con dientes largos y torcidos arriba y abajo.
	local diente = Color3.fromRGB(170, 156, 118)
	local function dientes(padre: BasePart, y: number, z: number, hacia: number, n: number)
		for i = 1, n do
			local largo = azar:NextNumber(0.35, 0.75)
			local x = (i - (n + 1) / 2) * (1.7 / n) + azar:NextNumber(-0.04, 0.04)
			pegar(padre, Vector3.new(0.14, largo, 0.12), CFrame.new(x, y + hacia * largo / 2, z) * CFrame.Angles(0, 0, azar:NextNumber(-0.3, 0.3)),
				diente, Enum.Material.SmoothPlastic)
		end
	end
	pegar(cabeza, Vector3.new(1.9, 0.7, 0.1), CFrame.new(0, -0.55, -1.41), Color3.fromRGB(28, 0, 0), Enum.Material.SmoothPlastic)
	dientes(cabeza, -0.25, -1.46, -1, 7)
	-- Colmillos laterales que salen por fuera de la boca.
	for _, lado in { -1, 1 } do
		pegar(cabeza, Vector3.new(0.18, 1.1, 0.16), CFrame.new(lado * 1.0, -0.75, -1.3) * CFrame.Angles(0.2, 0, lado * 0.25), diente)
	end
	local mandibula = miembro("Mandibula", Vector3.new(2, 0.55, 2.6), cabeza, CFrame.new(0, -0.95, 1.1), CFrame.new(0, 0.15, 1.2), PIEL)
	dientes(mandibula, 0.25, -1.32, 1, 6)
	-- Sangre que le chorrea de la boca, larga, y babas oscuras.
	for _, x in { -0.75, -0.2, 0.35, 0.8 } do
		local largo = azar:NextNumber(0.7, 1.6)
		pegar(mandibula, Vector3.new(0.1, largo, 0.06), CFrame.new(x, 0.1 - largo / 2, -1.31), SANGRE, Enum.Material.SmoothPlastic)
	end
	pegar(mandibula, Vector3.new(1.6, 0.12, 1.4), CFrame.new(0, -0.3, -0.4), SECA)

	-- Brazos delanteros: larguísimos y gruesos, se apoya en los nudillos; garras enormes manchadas.
	for _, lado in { -1, 1 } do
		local brazo = miembro(if lado < 0 then "BrazoI" else "BrazoD", Vector3.new(1.1, 6.8, 1.1), torso,
			CFrame.new(lado * 2.5, 0.4, -2.3) * CFrame.Angles(-0.05, 0, lado * 0.06), CFrame.new(0, 3.1, 0), PIEL)
		pegar(brazo, Vector3.new(1.6, 2.2, 1.6), CFrame.new(0, 2.4, 0), PIEL) -- hombro
		pegar(brazo, Vector3.new(1.4, 1.6, 1.4), CFrame.new(0, -0.2, 0) * CFrame.Angles(0.3, 0, 0), OSCURA) -- codo
		pegar(brazo, Vector3.new(1.5, 0.7, 1.5), CFrame.new(0, -3.25, -0.2), OSCURA) -- mano
		for i = -1.5, 1.5 do
			pegar(brazo, Vector3.new(0.16, 1.4, 0.16), CFrame.new(i * 0.4, -3.7, -0.9) * CFrame.Angles(1.1, 0, 0), Color3.fromRGB(34, 10, 8),
				Enum.Material.SmoothPlastic)
		end
		pegar(brazo, Vector3.new(1.2, 1.4, 0.1), CFrame.new(0, -2.6, -0.56), SANGRE)
	end
	-- Piernas de atrás: más cortas y dobladas, con el muslo grueso.
	for _, lado in { -1, 1 } do
		local pierna = miembro(if lado < 0 then "PiernaI" else "PiernaD", Vector3.new(1.2, 4.5, 1.3), raiz,
			CFrame.new(lado * 1.7, 0, 2.6), CFrame.new(0, 2.2, 0), OSCURA)
		pegar(pierna, Vector3.new(1.6, 2.4, 2), CFrame.new(0, 1.1, -0.3) * CFrame.Angles(-0.35, 0, 0), PIEL) -- muslo
		pegar(pierna, Vector3.new(1.3, 0.5, 2), CFrame.new(0, -2, -0.5), OSCURA) -- pie
	end

	local humanoide = Cuerpo.terminar(m, Caza.carpeta(), ALTURA, B.Andar)
	return Caza.nuevo(m, humanoide, {
		Altura = ALTURA,
		Andar = B.Andar,
		Correr = B.Correr,
		Pillar = B.Pillar,
		Vista = B.Vista,
		VioEsconderse = VIO_ESCONDERSE,
	})
end

local function avisar(texto: string)
	for _, jugador in Players:GetPlayers() do
		Remotes.Aviso:FireClient(jugador, Lang.t(jugador, texto))
	end
end

local function cojeando(e: Estado): boolean
	return os.clock() < e.cojeaHasta
end

local function velocidad(e: Estado, base: number): number
	return if cojeando(e) then math.min(base, B.Cojear) else base
end

local function raizDe(jugador: Player): BasePart?
	local personaje = jugador.Character
	return personaje and personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Pilla a `presa` si la alcanza; si no, un paso hacia `destino`. true si la ha pillado.
local function perseguir(e: Estado, b: Caza.Bicho, presa: Player, destino: Vector3): boolean
	b.humanoide.WalkSpeed = velocidad(e, b.o.Correr)
	local escondido = Muerte.escondite(presa) ~= nil
	local suRaiz = raizDe(presa)
	local alcanza = if escondido or not suRaiz then b:cerca(destino, 5)
		else (suRaiz.Position - b.raiz.Position).Magnitude < b.o.Pillar + 1.5
	if alcanza then
		b.humanoide:MoveTo(b.raiz.Position)
		b:mirarA(if suRaiz then suRaiz.Position else destino)
		Muerte.matar(presa, b:cabeza())
		task.wait(2.5)
		return true
	end
	b:pasoHacia(destino)
	return false
end

-- Llega del bosque a la puerta principal y la revienta (si sigue cerrada). Si por el camino ve a alguien, deja la
-- puerta y va a por él.
local function llegar(b: Caza.Bicho, puerta: Model)
	local fuera = puerta:GetAttribute("Fuera") :: Vector3
	local dentro = puerta:GetAttribute("Dentro") :: Vector3
	local centro = puerta:GetAttribute("Centro") :: CFrame
	b:irA(fuera, B.Andar, 40, function()
		return not b.prisa and b:elegirPresa(false) == nil
	end)
	if b.prisa or b:elegirPresa(false) or not b.modelo or not b:cerca(fuera, 6) then
		return
	end
	local estado = Casa.estado(puerta)
	if estado and not estado.abierta then
		b.humanoide.AutoRotate = false
		b:mirarA(centro.Position)
		for _ = 1, 2 do
			Remotes.Bestia:FireAllClients("Golpe", b.modelo)
			task.wait(1)
		end
		Casa.romper(puerta)
		b.humanoide.AutoRotate = true
	end
	local normal = plano(centro.LookVector).Unit
	local pie = dentro + Vector3.new(0, ALTURA, 0)
	if b.modelo then
		b.modelo:PivotTo(CFrame.lookAt(pie, pie - normal))
	end
end

-- Dentro de la casa o bajo tierra (el sótano y su escalera no cuentan en Caza.dentroDeCasa).
local function enCasa(pies: Vector3): boolean
	return Caza.dentroDeCasa(pies) or pies.Y < -2
end

-- Un paso de caza por la casa (suelta).
local ultimoVisto: Vector3? = nil
local ronda: Vector3? = nil
local function cazar(e: Estado, b: Caza.Bicho)
	local presa, destino = b:elegirPresa(false)
	if b:quieto() then
		b.humanoide:MoveTo(b.raiz.Position)
	elseif presa and destino then
		ultimoVisto = destino
		if perseguir(e, b, presa, destino) then
			ultimoVisto = nil
		end
	elseif ultimoVisto then
		b.humanoide.WalkSpeed = velocidad(e, b.o.Correr)
		b:pasoHacia(ultimoVisto)
		if b:cerca(ultimoVisto, 4) then
			ultimoVisto = nil
		end
	else
		b.humanoide.WalkSpeed = velocidad(e, b.o.Andar)
		if not ronda or b:cerca(ronda :: Vector3, 4) then
			ronda = Mapa.salas[azar:NextInteger(1, #Mapa.salas)]
		end
		b:pasoHacia(ronda :: Vector3)
	end
end

-- Un paso encerrada en el sótano.
local ultimoDentro: CFrame? = nil
local ultimoGolpe = 0
local atascada = 0 -- os.clock desde el que no avanza hacia alguien de fuera
local function golpear(b: Caza.Bicho, hacia: Vector3)
	if os.clock() - ultimoGolpe < CADA_GOLPE or not b.modelo then
		return
	end
	ultimoGolpe = os.clock()
	b.humanoide:MoveTo(b.raiz.Position)
	b:mirarA(hacia)
	Remotes.Bestia:FireAllClients("Golpe", b.modelo)
end

local function encerrada(e: Estado, b: Caza.Bicho)
	local dentro = e.dentro :: (Vector3) -> boolean
	local modelo = b.modelo :: Model
	-- No sale nunca: si se ha colado por la reja, vuelve a donde estaba y golpea.
	if dentro(b.raiz.Position) then
		ultimoDentro = modelo:GetPivot()
	elseif ultimoDentro then
		modelo:PivotTo(ultimoDentro)
		golpear(b, b.raiz.Position + b.raiz.CFrame.LookVector * 5)
		return
	end
	if b:quieto() then
		b.humanoide:MoveTo(b.raiz.Position)
		return
	end
	local presa, destino = b:elegirPresa(false)
	if presa and destino and dentro(destino + Vector3.new(0, 3, 0)) then
		atascada = 0
		perseguir(e, b, presa, destino)
	elseif presa and destino and (destino - b.raiz.Position).Magnitude < CERCA_REJA then
		-- Le ve fuera, cerca: va hacia él hasta la reja y la golpea.
		b.humanoide.WalkSpeed = velocidad(e, b.o.Correr)
		local v = b.raiz.AssemblyLinearVelocity
		if plano(v).Magnitude < 1.5 then
			if atascada == 0 then
				atascada = os.clock()
			elseif os.clock() - atascada > 0.6 then
				golpear(b, destino)
				return
			end
		else
			atascada = 0
		end
		b:pasoHacia(destino)
	else
		atascada = 0
		b.humanoide.WalkSpeed = velocidad(e, b.o.Andar)
		if not ronda or b:cerca(ronda :: Vector3, 3) or not dentro((ronda :: Vector3) + Vector3.new(0, ALTURA, 0)) then
			local centro = e.centro or b.raiz.Position
			ronda = nil
			for _ = 1, 10 do
				local p = centro + Vector3.new(azar:NextNumber(-8, 8), 0, azar:NextNumber(-8, 8))
				if dentro(p) then
					ronda = p - Vector3.new(0, ALTURA, 0)
					break
				end
			end
		end
		if ronda then
			b:pasoHacia(ronda :: Vector3)
		end
	end
end

local function terminar(e: Estado)
	if e.bicho then
		e.bicho:quitar()
		e.bicho = nil
	end
	if actual == e then
		actual = nil
		workspace:SetAttribute("Bestia", nil)
	end
end

local function noche(e: Estado)
	task.wait(B.Espera)
	local puerta = Casa.principal()
	if not puerta then
		warn("Bestia: no hay puerta principal")
		return
	end
	local centro = puerta:GetAttribute("Centro") :: CFrame
	local fuera = puerta:GetAttribute("Fuera") :: Vector3
	local normal = plano(centro.LookVector).Unit
	local inicio = fuera + normal * BORDE + normal:Cross(Vector3.yAxis) * azar:NextNumber(-12, 12)
	local b = crear(CFrame.lookAt(inicio + Vector3.new(0, ALTURA, 0), fuera + Vector3.new(0, ALTURA, 0)))
	e.bicho = b
	b.prisa = e.yendose
	local modelo = b.modelo :: Model
	b.alFlash = function()
		-- El flash no la para: solo aparta la cara (lo que la daña es el fuego).
		Remotes.Bestia:FireAllClients("Flash", modelo)
	end
	ultimoVisto, ronda, ultimoDentro, atascada = nil, nil, nil, 0
	Remotes.Bestia:FireAllClients("Ruge", modelo)
	avisar("Something huge is coming out of the woods.")
	task.wait(RUGIDO)

	while b.modelo and not b.prisa do
		if e.atrapada then
			encerrada(e, b)
		elseif not enCasa(b:suelo()) and not ultimoVisto and b:elegirPresa(false) == nil then
			llegar(b, puerta) -- fuera y sin nadie a la vista: entra por la puerta principal
		else
			cazar(e, b)
		end
		task.wait(0.25)
	end
	-- Amanece: se vuelve al bosque (encerrada no puede: desaparece).
	if b.modelo and not e.atrapada then
		local aqui = b.raiz.Position
		local afuera = if plano(aqui).Magnitude > 1 then plano(aqui).Unit else Vector3.zAxis
		b:irA(aqui + afuera * 120, B.Andar, 15)
	end
end

function Bestia.soltar()
	if actual and not actual.yendose then
		return
	end
	Bestia.quitar()
	local e: Estado = { bicho = nil, hilo = nil, yendose = false, atrapada = false, dentro = nil, centro = nil, cojeaHasta = 0, quemada = false }
	actual = e
	workspace:SetAttribute("Bestia", true)
	-- Esta noche solo está ella: los demás se van.
	Golpeador.irse()
	Raspador.irse()
	Trepador.irse()
	Imitador.irse()
	Acechador.irse()
	e.hilo = task.spawn(function()
		noche(e)
		if not e.quemada then
			terminar(e)
		end
	end)
end

function Bestia.activa(): boolean
	return actual ~= nil and not actual.yendose
end

function Bestia.modelo(): Model?
	local e = actual
	return if e and e.bicho and not e.quemada then e.bicho.modelo else nil
end

function Bestia.atrapada(): boolean
	return actual ~= nil and actual.atrapada
end

function Bestia.herir(segundos: number)
	local e = actual
	local b = e and e.bicho
	if not e or not b or not b.modelo or e.quemada then
		return
	end
	e.cojeaHasta = math.max(e.cojeaHasta, os.clock() + segundos)
	b.modelo:SetAttribute("Cojea", workspace:GetServerTimeNow() + (e.cojeaHasta - os.clock()))
	b:aturdir(SOBRESALTO)
	Remotes.Bestia:FireAllClients("Herida", b.modelo)
end

function Bestia.encerrar(dentro: (Vector3) -> boolean): boolean
	local e = actual
	local b = e and e.bicho
	if not e or not b or not b.modelo or e.quemada then
		return false
	end
	if e.atrapada then
		return true
	end
	if not dentro(b.raiz.Position) then
		return false
	end
	e.atrapada = true
	e.dentro = dentro
	e.centro = b.raiz.Position
	ultimoDentro = b.modelo:GetPivot()
	ronda, ultimoVisto = nil, nil
	b.modelo:SetAttribute("Atrapada", true)
	Remotes.Bestia:FireAllClients("Atrapada", b.modelo)
	return true
end

function Bestia.quemar()
	local e = actual
	if not e or e.quemada then
		return
	end
	e.quemada = true
	if e.hilo and coroutine.status(e.hilo) ~= "dead" and e.hilo ~= coroutine.running() then
		task.cancel(e.hilo)
	end
	-- Caen todos: eran partes suyas.
	Golpeador.quitar()
	Raspador.quitar()
	Trepador.quitar()
	Imitador.quitar()
	Acechador.quitar()
	local b = e.bicho
	if b and b.modelo then
		b.humanoide:MoveTo(b.raiz.Position)
		b.raiz.Anchored = true
		b.modelo:SetAttribute("Quema", true)
		Remotes.Bestia:FireAllClients("Quema", b.modelo)
		task.delay(QUEMA, function()
			if e.bicho then
				e.bicho:quitar()
				e.bicho = nil
			end
		end)
	end
end

-- Amanece: se va (y deja de ser la noche final).
function Bestia.irse()
	local e = actual
	if not e then
		return
	end
	e.yendose = true
	workspace:SetAttribute("Bestia", nil)
	if e.quemada or e.atrapada or not e.bicho then
		Bestia.quitar()
	else
		e.bicho.prisa = true
	end
end

function Bestia.quitar()
	local e = actual
	if not e then
		return
	end
	if e.hilo and coroutine.status(e.hilo) ~= "dead" and e.hilo ~= coroutine.running() then
		task.cancel(e.hilo)
	end
	terminar(e)
end

function Bestia.start()
	Acechador = require(script.Parent.Acechador)
	Caza.carpeta()
end

return Bestia
