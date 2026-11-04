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
-- ("Herida", modelo), ("Atrapada", modelo), ("Quema", modelo), ("Flash", modelo), ("Arana", modelo) bajo la trampilla.
-- Sube y baja por la escalera del vestíbulo (ir). La trampilla no la cruza: se queda debajo arañando. Atributos: "Cojea" (hora
-- del servidor hasta la que cojea), "Atrapada", "Quema". En workspace, atributo "Bestia" = es la noche final.
-- Debajo de los muebles (pedido por el usuario: "que sea útil agacharte"): como los demás (Caza), a quien está debajo
-- de algo solo le nota muy de cerca y le huele; al olerle va al borde del mueble y gatea a por él (Caza.aPorDebajo,
-- atributos Gatea y GateaHora). Su olfato de siempre (oler) no cuenta a los que están debajo de algo.
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
local OLFATO_RECIENTE = Config.Bestia.OlfatoReciente
local OLFATO_ALTO = Config.Bestia.OlfatoAlto
local ARANAR = Config.Bestia.Aranar
local SIN_TRAMPILLA = Config.Bestia.SinTrampilla
local CERCA_TRAMPILLA = Config.Bestia.CercaTrampilla
local FUERA_MUEBLE = Config.Postura.FueraBestia -- studs fuera del mueble donde se para a gatear (es enorme)

-- La escalera del vestíbulo (Mapa): los caminos no la suben (con los peldaños de arriba sueltos PathfindingService
-- pide saltos), así que ella va al pie o a lo alto y la sube o baja recta por el medio.
local PIE_ESCALERA = Vector3.new(0, 1, -21)
local ANTE_PIE = Vector3.new(0, 1, -25) -- delante del pie, para subir siempre de frente
local CIMA_ESCALERA = Vector3.new(0, 14, 6) -- fuera de enEscalera (si no, se queda yendo y viniendo arriba)
-- La trampilla del sótano al patio (TRAMPILLA en Mapa): no cabe. Debajo, al lado de la escala, se queda arañando.
local TRAMPILLA = Vector3.new(-9.15, -11, 60.6)
local BAJO_TRAMPILLA = Vector3.new(-6.2, -11, 60.6)
local SALIDA_SOTANO = Vector3.new(0, 1, 31) -- en el pasillo, arriba de la escalera del sótano
local ANTE_SOTANO = Vector3.new(0, 1, 29) -- en el pasillo, delante de la puerta del sótano, para bajar de frente
local DELANTE_VANO = Vector3.new(0, -11, 50) -- en la sala del sótano, delante del vano de su escalera
local PIE_SOTANO = Vector3.new(0, -10, 46) -- el primer peldaño, pasado el vano

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
	local torso = miembro("Lomo", Vector3.new(4.4, 3, 6.2), raiz, CFrame.new(0, -0.4, 2.4) * CFrame.Angles(0.2, 0, 0),
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
	-- Que no trepe por la escala de la trampilla (ni por ningún TrussPart): no cabe por arriba y se quedaba colgada.
	humanoide:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	return Caza.nuevo(m, humanoide, {
		Altura = ALTURA,
		Andar = B.Andar,
		Correr = B.Correr,
		Pillar = B.Pillar,
		Vista = B.Vista,
		VioEsconderse = VIO_ESCONDERSE,
		-- Con 8 el camino no cabía por la escalera del sótano y daba la vuelta por la trampilla del patio.
		AltoCamino = B.AltoCamino,
		Fuera = FUERA_MUEBLE,
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

-- Planta de un punto (pies): 1 arriba (y el desván), 0 abajo, el sótano y fuera.
local function planta(p: Vector3): number
	return if p.Y > 8 then 1 else 0
end

local function enEscalera(p: Vector3): boolean
	-- Los peldaños y el rellano de arriba hasta z 4,5 (la galería empieza en z 0): ahí sigue recta al otro extremo.
	return math.abs(p.X) < 4.8 and p.Z > -19 and p.Z < 4.5 and p.Y > 1.6 and p.Y < 14.6
end

-- El sótano, su escalera y el rellano de arriba, delante de la puerta del sótano (HUECO en Mapa).
local function enSotano(p: Vector3): boolean
	return (p.Y < -1.5 and p.Z > 33) or (math.abs(p.X) < 3.5 and p.Z > 33 and p.Z < 36 and p.Y < 2.5)
end

-- Recta por una escalera hasta `hacia`. Andando despacio (rondando o cojeando) el Humanoid se atasca en el primer
-- peldaño: si lleva un momento sin avanzar, un empujón de un peldaño hacia arriba y adelante.
local trabada = 0 -- os.clock desde el que no avanza por la escalera
local filtroEmpujon = RaycastParams.new()
filtroEmpujon.FilterType = Enum.RaycastFilterType.Exclude
local function subirRecta(b: Caza.Bicho, hacia: Vector3)
	b.humanoide:MoveTo(hacia)
	local modelo = b.modelo
	local dir = plano(hacia - b.raiz.Position)
	if not modelo or dir.Magnitude < 2 or plano(b.raiz.AssemblyLinearVelocity).Magnitude > 1.5 then
		trabada = 0
	elseif trabada == 0 then
		trabada = os.clock()
	elseif os.clock() - trabada > 0.6 then
		trabada = 0
		-- Nunca a través de una puerta cerrada, la reja o una pared: a la altura de la raíz solo puede haber aire (los
		-- peldaños quedan por debajo).
		filtroEmpujon.FilterDescendantsInstances = { Caza.carpeta() }
		if workspace:Raycast(b.raiz.Position, dir.Unit * 3, filtroEmpujon) then
			return
		end
		local sube = if hacia.Y > b:suelo().Y + 1 then 1.2 else 0.2
		modelo:PivotTo(modelo:GetPivot() + dir.Unit * 1.2 + Vector3.new(0, sube, 0))
	end
end

-- Un paso hacia `destino` (a ras de suelo), también a la otra planta: los caminos no suben la escalera del vestíbulo
-- (PIE_ESCALERA), así que va a un extremo y anda recta hasta el otro.
local function ir(b: Caza.Bicho, destino: Vector3)
	if b:quieto() then
		b.humanoide:MoveTo(b.raiz.Position)
		return
	end
	local suelo = b:suelo()
	local arriba = planta(destino) == 1
	if enSotano(suelo) and not enSotano(destino) and destino.Y > -1.5 then
		-- Del sótano (o su escalera) a la casa o al patio: primero sube su escalera. Si no, con alguien en el patio
		-- junto a la trampilla, se quedaba empujando la pared hacia él (no hay camino con las puertas cerradas).
		-- En la sala, primero delante del vano y centrada (si no, se quedaba enganchada en la esquina del muro); de
		-- ahí, recta por el medio de la escalera hasta el pasillo, abriendo la puerta del sótano.
		if suelo.Z > 47.8 and (suelo.Z > 51.8 or math.abs(suelo.X) > 1.5) then
			b:pasoHacia(DELANTE_VANO) -- MoveTo se para a 1 stud: por eso el margen de 51,8 y 1,5
		elseif suelo.Z > 47.8 then
			subirRecta(b, PIE_SOTANO) -- recta por el vano
		else
			b:abrirPuertas()
			subirRecta(b, SALIDA_SOTANO)
		end
	elseif destino.Y < -8 and enSotano(destino) and suelo.Z > 27 and suelo.Z < 47.8 and math.abs(suelo.X) < 6
		and suelo.Y > -10 then
		-- Bajar al sótano (14.1): con los caminos se quedaba ladeada contra el marco de la puerta y se rendía. Primero
		-- centrada delante de la puerta; de ahí, recta por el medio de la escalera hasta la sala.
		if suelo.Z < 33 and math.abs(suelo.X) > 1.5 then
			b:pasoHacia(ANTE_SOTANO)
		else
			b:abrirPuertas()
			subirRecta(b, DELANTE_VANO)
		end
	elseif enEscalera(suelo) then
		subirRecta(b, if arriba then CIMA_ESCALERA else PIE_ESCALERA)
	elseif planta(suelo) ~= planta(destino) and arriba then
		-- Siempre de frente: entrando por un lado del pie, la barandilla (Choque, a 7,5 de alto) le pilla el lomo y se
		-- queda encajada debajo.
		if b:cerca(ANTE_PIE, 3) or (math.abs(suelo.X) < 2 and suelo.Z > -26 and suelo.Z < -19) then
			subirRecta(b, CIMA_ESCALERA)
		else
			b:pasoHacia(ANTE_PIE)
		end
	elseif planta(suelo) ~= planta(destino) then
		if b:cerca(CIMA_ESCALERA, 3) then
			subirRecta(b, PIE_ESCALERA)
		else
			b:pasoHacia(CIMA_ESCALERA)
		end
	else
		b:pasoHacia(destino)
	end
end

-- Pilla a `presa` si la alcanza; si no, un paso hacia `destino`. Si está debajo de un mueble (`bajo`, de
-- elegirPresa), `destino` es el borde: va (ir, también por las escaleras) y allí gatea a por ella. true si ya ha
-- acabado con ella: la ha pillado o la deja (se ha escapado de debajo o no llega al borde).
local function perseguir(e: Estado, b: Caza.Bicho, presa: Player, destino: Vector3, bajo: Caza.Debajo?): boolean
	b.humanoide.WalkSpeed = velocidad(e, b.o.Correr)
	if bajo then
		local que = b:aPorDebajo(presa, bajo, ir)
		if que == "Pilla" then
			task.wait(2.5)
		end
		return que ~= nil
	end
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
	ir(b, destino)
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
local parada = 0 -- os.clock desde el que no avanza rondando o buscando
local PARADA = B.Parada -- segundos sin avanzar para cambiar de destino

-- Una sala cualquiera de la casa para rondar, de las dos plantas (sube y baja por la escalera del vestíbulo: ir).
local function otraRonda(_b: Caza.Bicho): Vector3
	return Mapa.salas[azar:NextInteger(1, #Mapa.salas)]
end

-- Sin ver a nadie, huele al más cercano que no esté escondido, a menos de Config.Bestia.Olfato y en su planta: así te
-- sigue escaleras abajo hasta el sótano aunque dobles una esquina (si no, se volvía al llegar a donde te vio). Si le
-- vio hace nada (OLFATO_RECIENTE), también en la otra planta: le ha visto subir la escalera o salir por la trampilla.
-- A quien está debajo de un mueble (Cubierto) no: a ese le huele Caza, despacio (elegirPresa), y se mete a por él.
local sinOlfato = 0 -- os.clock hasta el que no huele (tras atascarse yendo a por alguien que no alcanza)
local function oler(b: Caza.Bicho): Vector3?
	if os.clock() < sinOlfato then
		return nil
	end
	local suelo = b:suelo()
	-- Arriba de la escalera del sótano o dentro, huele más lejos a quien esté abajo (14.1): si no, al bajar
	-- corriendo (o con ella cojeando por una bengala) la perdías y no había forma de meterla en el sótano.
	local enLaBajada = enSotano(suelo) or plano(suelo - SALIDA_SOTANO).Magnitude < 10
	local mejor, distancia = nil, math.huge
	for _, jugador in Muerte.vivos() do
		local raiz = raizDe(jugador)
		if raiz and not jugador:GetAttribute("Escondido") and not jugador:GetAttribute("Cubierto") then
			local pies = raiz.Position - Vector3.new(0, 3, 0)
			local d = (pies - suelo).Magnitude
			local visto = b.vistoEn[jugador]
			local alSotano = enLaBajada and enSotano(pies)
			local alcance = if alSotano then B.OlfatoSotano else B.Olfato
			local alto = if alSotano or (visto and os.clock() - visto < OLFATO_RECIENTE) then OLFATO_ALTO else 8
			if d < alcance and d < distancia and math.abs(pies.Y - suelo.Y) < alto then
				mejor, distancia = pies, d
			end
		end
	end
	return mejor
end

-- La trampilla: si a quien busca se le ha ido por ella (ella en el sótano y él arriba, junto al hueco), va debajo y se
-- queda ARANAR s arañando hacia arriba y rugiendo; luego le busca por la escalera (y en SIN_TRAMPILLA s no vuelve).
-- Así da tiempo a tirar de la palanca desde el patio.
local aranaHasta = 0 -- os.clock hasta el que araña (0 = no está en ello)
local sinTrampilla = 0
local ultimoArano = 0
local yendoTrampilla = 0 -- os.clock desde el que va hacia la trampilla
local function porLaTrampilla(b: Caza.Bicho, punto: Vector3?): boolean
	return punto ~= nil and os.clock() > sinTrampilla and b:suelo().Y < -8 and punto.Y > -5
		and plano(punto - TRAMPILLA).Magnitude < CERCA_TRAMPILLA
end

-- Un paso con la trampilla; false si ya ha acabado de arañar (sigue cazando normal).
local function aranar(e: Estado, b: Caza.Bicho): boolean
	if aranaHasta > 0 then
		if os.clock() > aranaHasta then
			aranaHasta = 0
			sinTrampilla = os.clock() + SIN_TRAMPILLA
			return false
		end
		b.humanoide:MoveTo(b.raiz.Position)
		b:mirarA(TRAMPILLA)
		if os.clock() - ultimoArano > 1.2 and b.modelo then
			ultimoArano = os.clock()
			Remotes.Bestia:FireAllClients("Arana", b.modelo)
		end
		return true
	end
	if yendoTrampilla == 0 then
		yendoTrampilla = os.clock()
	end
	-- Debajo (o si algo no la deja llegar, donde esté al cabo de unos segundos): empieza a arañar.
	if b:cerca(BAJO_TRAMPILLA, 3) or os.clock() - yendoTrampilla > 4 then
		aranaHasta = os.clock() + ARANAR
		ultimoArano = 0
		yendoTrampilla = 0
		return aranar(e, b)
	end
	b.humanoide.WalkSpeed = velocidad(e, b.o.Correr)
	b:pasoHacia(BAJO_TRAMPILLA)
	return true
end

local function cazar(e: Estado, b: Caza.Bicho)
	local presa, destino, bajo = b:elegirPresa(false)
	-- Alguien ha vuelto a bajar al sótano mientras arañaba: a por él.
	if aranaHasta > 0 and destino and destino.Y < -8 then
		aranaHasta = 0
	end
	if not b:quieto() then
		local objetivo = destino or oler(b) or ultimoVisto
		if (aranaHasta > 0 or porLaTrampilla(b, objetivo)) and aranar(e, b) then
			parada = 0
			ultimoVisto = objetivo or ultimoVisto
			return
		end
	end
	yendoTrampilla = 0
	-- Si rondando o buscando no avanza (algo en medio, sin camino), cambia de destino y deja de oler un rato.
	if not presa and not b:quieto() and plano(b.raiz.AssemblyLinearVelocity).Magnitude < 1 then
		if parada == 0 then
			parada = os.clock()
		elseif os.clock() - parada > PARADA then
			parada = 0
			ultimoVisto = nil
			sinOlfato = os.clock() + 4
			ronda = otraRonda(b)
		end
	else
		parada = 0
	end
	if not presa and not b:quieto() then
		ultimoVisto = oler(b) or ultimoVisto
	end
	if b:quieto() then
		b.humanoide:MoveTo(b.raiz.Position)
	elseif presa and destino then
		ultimoVisto = destino
		if perseguir(e, b, presa, destino, bajo) then
			ultimoVisto = nil
		end
	elseif ultimoVisto then
		b.humanoide.WalkSpeed = velocidad(e, b.o.Correr)
		ir(b, ultimoVisto)
		if b:cerca(ultimoVisto, 4) then
			ultimoVisto = nil
			sinOlfato = os.clock() + 1 -- si no, lo vuelve a oler ahí mismo (una puerta cerrada en medio) y empuja
		end
	else
		b.humanoide.WalkSpeed = velocidad(e, b.o.Andar)
		if not ronda or b:cerca(ronda :: Vector3, 4) then
			ronda = otraRonda(b)
		end
		ir(b, ronda :: Vector3)
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
	local presa, destino, bajo = b:elegirPresa(false)
	if presa and destino and dentro(destino + Vector3.new(0, 3, 0)) then
		atascada = 0
		perseguir(e, b, presa, destino, bajo)
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
	ultimoVisto, ronda, ultimoDentro, atascada, parada = nil, nil, nil, 0, 0
	aranaHasta, sinTrampilla, yendoTrampilla, trabada = 0, 0, 0, 0
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
		-- Con pcall: si falla, se quita igual (si no, Bestia.activa() seguía en true hasta el amanecer).
		local ok, fallo = pcall(noche, e)
		if not ok then
			warn("[Bestia] " .. tostring(fallo))
		end
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
	ronda, ultimoVisto, aranaHasta = nil, nil, 0
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
		-- Si gateaba a por alguien, su hilo ya no los quita (task.cancel): se quitan aquí.
		b.modelo:SetAttribute("Gatea", nil)
		b.modelo:SetAttribute("GateaHora", nil)
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
