-- Tutorial de los primeros minutos (14.2 / 13.1; pedido por el usuario en el primer juego: "tiene que invadir más la
-- pantalla y que te diga más vistoso dónde clicar"). Sale una vez por cuenta: hasta que lo acaba (premio, el logro
-- Tutorial de Config.Recompensas) o lo salta. Los pasos y cuándo se pasa de uno a otro, en shared/PasosTutorial.
--   Cada Config.Tutorial.Cada s mira lo de cada jugador con tutorial (la nota de la cocina, mochila, hacha, si ha corrido, lo que carga,
--   generador y su gasolina, cortinas de abajo y puerta principal abiertas) y publica el paso en atributos del Player:
--     Tutorial = el paso ("Mochila", "Hacha"…; nil = sin tutorial), TutorialFalta = cortinas (y puerta) que quedan
--     por cerrar, TutorialPuerta = la puerta principal está abierta (16.5), TutorialGasolina = el paso del generador
--     pide echarle un bidón (16.5).
--   No empieza mientras dura la escena de llegada en coche (atributo EscenaLlegada de workspace; con Config.Llegada
--   activa, sin poner aún = Llegada no ha decidido: también espera). Si vuelve a haber escena, el cartel se esconde.
-- Siguiente meta (16.5): quien ya no tiene tutorial recibe al empezar cada día (y al entrar) un aviso de una línea con
--   la siguiente meta (PasosTutorial.meta: llenar el generador si no aguanta la noche, reparar ventanas y puertas
--   rotas, troncos junto a la chimenea apagada desde que sale el Trepador, llaves, piezas del coche, huir), y la misma frase en el atributo Meta del Player, que enseña el móvil (MovilUi). Si ya se ha abierto la caja
--   fuerte (la 12) y se ha empezado a preparar la casa (una cruz con gasolina o la reja montada), la meta es la del
--   final de la Bestia (PasosTutorial.metaBestia: cruces que faltan, plano, reja, esperarla); con ella suelta, ninguna.
--   El cliente (TutorialVista) pinta el cartel y la flecha; solo puede pedir saltarlo (remote Tutorial, "Saltar").
--   Todo lo que da premio lo mira el servidor: el cliente no puede acabarlo antes de tiempo.
-- En Studio solo sale con Config.Test.Tutorial (los datos de prueba nunca lo tienen hecho).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local PasosTutorial = require(ReplicatedStorage.Shared.PasosTutorial)
local Prueba = require(ReplicatedStorage.Shared.Prueba)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Comun = ServerScriptService:WaitForChild("Comun")
local Datos = require(Comun.Datos)
local Recompensas = require(Comun.Recompensas)
local Bestia = require(script.Parent.Bestia)
local Casa = require(script.Parent.Casa)
local Ciclo = require(script.Parent.Ciclo)
local Mochila = require(script.Parent.Mochila)
local Pistas = require(script.Parent.Pistas)
local Preparativos = require(script.Parent.Preparativos)

local Tutorial = {}

type Activo = {
	estado: PasosTutorial.Estado,
	mochila: boolean, -- ha abierto la mochila desde que empezó
	corrido: boolean, -- ha corrido desde que empezó (atributo Corriendo, de juego/servidor/Correr): un momento basta
	conexiones: { RBXScriptConnection },
}

local activos: { [Player]: Activo } = {}
local conMeta: { [Player]: true } = {} -- sin tutorial (acabado o saltado): reciben la siguiente meta
local avisadoEn: { [Player]: number } = {} -- cuándo se le avisó la meta por última vez (para no repetirla)

-- Mientras se ve la escena de llegada en coche (la pone Llegada en workspace), ni tutorial ni avisos. Con la llegada
-- activa, hasta que Llegada la ponga a false (nil = aún no sabe si la partida es nueva): así no importa quién arranca
-- antes ni cuándo llegan los datos del jugador (DatosListos).
local function enEscena(): boolean
	local escena = workspace:GetAttribute("EscenaLlegada")
	if Config.Llegada.Activa then
		-- Seguro: si Llegada fallara antes de decidir, que el tutorial no se quede esperando para siempre
		if escena == nil and time() > Config.Llegada.SinDecidir then
			return false
		end
		return escena ~= false
	end
	return escena == true
end

local function quitar(jugador: Player)
	local a = activos[jugador]
	if a then
		for _, c in a.conexiones do
			c:Disconnect()
		end
		activos[jugador] = nil
	end
	if jugador.Parent then
		jugador:SetAttribute("Tutorial", nil)
		jugador:SetAttribute("TutorialFalta", nil)
		jugador:SetAttribute("TutorialPuerta", nil)
		jugador:SetAttribute("TutorialGasolina", nil)
	end
end

-- Cortinas de la planta baja (las que ataca el Golpeador) aún abiertas, más la puerta principal si está abierta (16.5:
-- abierta, el primer golpe del bicho ya entra); las rotas no cuentan (no se pueden cerrar). Y si la puerta lo está.
local function cortinasAbiertas(): (number, boolean)
	local n, puerta = 0, false
	for _, el in Casa.atacables() do
		local e = Casa.estado(el)
		if e.vida <= 0 then
			continue
		end
		if e.tipo == "Ventana" and not e.persiana then
			n += 1
		elseif e.tipo == "Puerta" and e.abierta then
			n += 1
			puerta = true
		end
	end
	return n, puerta
end

local function generadorEncendido(): (boolean, number?)
	local gen = CollectionService:GetTagged("Generador")[1]
	if not gen then
		return false, nil
	end
	local gasolina = gen:GetAttribute("Gasolina")
	return gen:GetAttribute("Encendido") == true, if type(gasolina) == "number" then gasolina else nil
end

-- ¿Queda algún bidón con gasolina por el mundo (suelto o en las manos de alguien)?
local function hayBidon(): boolean
	for _, pieza in CollectionService:GetTagged("Pesado") do
		if pieza:GetAttribute("Tipo") == "Bidon" and (pieza:GetAttribute("Carga") or 0) > 0.05
			and pieza:IsDescendantOf(workspace) then
			return true
		end
	end
	return false
end

-- ¿Hay gasolina que echarle al generador? Un bidón con gasolina, o un bidón (aunque esté vacío) y el depósito de la
-- granja con algo dentro para llenarlo.
local function hayGasolina(): boolean
	if hayBidon() then
		return true
	end
	local hayLata = false
	for _, pieza in CollectionService:GetTagged("Pesado") do
		if pieza:GetAttribute("Tipo") == "Bidon" and pieza:IsDescendantOf(workspace) then
			hayLata = true
			break
		end
	end
	if not hayLata then
		return false
	end
	for _, dep in CollectionService:GetTagged("Deposito") do
		local litros = dep:GetAttribute("Litros")
		if type(litros) == "number" and litros > 0.05 and dep:IsDescendantOf(workspace) then
			return true
		end
	end
	return false
end

local function mirar()
	if next(activos) == nil then
		return
	end
	if enEscena() then -- el cartel y la flecha, fuera mientras dura (vuelven al acabar)
		for jugador in activos do
			if jugador.Parent and jugador:GetAttribute("Tutorial") ~= nil then
				jugador:SetAttribute("Tutorial", nil)
				jugador:SetAttribute("TutorialFalta", nil)
				jugador:SetAttribute("TutorialPuerta", nil)
				jugador:SetAttribute("TutorialGasolina", nil)
			end
		end
		return
	end
	local fase, noche = Ciclo.fase()
	local fin = workspace:GetAttribute("FaseFin")
	local quedan = if type(fin) == "number" then fin - workspace:GetServerTimeNow() else math.huge
	local cortinas, puerta = cortinasAbiertas()
	local generador, gasolina = generadorEncendido()
	local bidon = hayBidon()
	for jugador, a in activos do
		if not jugador.Parent then
			quitar(jugador)
			continue
		end
		local cargando = jugador:GetAttribute("Cargando")
		local acabado = PasosTutorial.avanzar(a.estado, {
			fase = fase,
			noche = noche,
			quedan = quedan,
			aviso = Config.Ciclo.Aviso,
			nota = jugador:GetAttribute("Leida1") == true, -- la pista 1, en la mesa de la cocina (Pistas.leer)
			mochila = a.mochila,
			hacha = Mochila.contar(jugador, "Hacha") > 0,
			cargando = if type(cargando) == "string" then cargando else nil,
			generador = generador,
			cortinas = cortinas,
			corrido = a.corrido,
			gasolina = gasolina,
			gasolinaMin = Config.Tutorial.Gasolina,
			bidon = bidon,
		})
		if acabado then
			quitar(jugador)
			conMeta[jugador] = true -- la meta llega con el aviso de este amanecer (Ciclo.alCambiar, más abajo)
			Recompensas.tutorial(jugador) -- apunta el logro (ya no vuelve a salir) y da las monedas una sola vez
		else
			local enCortinas = a.estado.paso == "Cortinas"
			jugador:SetAttribute("Tutorial", a.estado.paso)
			jugador:SetAttribute("TutorialFalta", if enCortinas then cortinas else nil)
			jugador:SetAttribute("TutorialPuerta", if enCortinas and puerta then true else nil)
			jugador:SetAttribute("TutorialGasolina", if a.estado.repostar then true else nil)
		end
	end
end

-- Ventanas y puertas de abajo reventadas (sin vida: no protegen y el bicho entra al primer golpe). El cristal roto con
-- la cortina sana no cuenta. Y si la única rota es una puerta (para la frase).
local function rotas(): (number, boolean)
	local n, puerta = 0, false
	for _, el in Casa.atacables() do
		local e = Casa.estado(el)
		if e and e.vida <= 0 then
			n += 1
			puerta = e.tipo == "Puerta"
		end
	end
	return n, n == 1 and puerta
end

-- ¿La chimenea está apagada y sin troncos al lado? Cuenta cualquier tronco (suelto o en las manos de alguien) a menos
-- de Config.Chimenea.Cerca del Mando o del sitio donde arde.
local function chimeneaSinTroncos(): boolean
	local chimenea = CollectionService:GetTagged("Chimenea")[1]
	if not chimenea then
		return false
	end
	local fuego = chimenea:GetAttribute("Fuego")
	if type(fuego) == "number" and fuego > workspace:GetServerTimeNow() then
		return false
	end
	local sitios = {}
	local mando = chimenea:FindFirstChild("Mando")
	if mando and mando:IsA("BasePart") then
		table.insert(sitios, mando.Position)
	end
	local hogar = chimenea:GetAttribute("Hogar")
	if typeof(hogar) == "CFrame" then
		table.insert(sitios, hogar.Position)
	end
	for _, pieza in CollectionService:GetTagged("Pesado") do
		if pieza:GetAttribute("Tipo") == "Tronco" and pieza:IsA("BasePart") and pieza:IsDescendantOf(workspace) then
			for _, sitio in sitios do
				if (pieza.Position - sitio).Magnitude < Config.Chimenea.Cerca then
					return false
				end
			end
		end
	end
	return true
end

-- La siguiente meta de la partida, ya en el idioma del jugador (nil = ninguna: la partida se está acabando).
local function textoMeta(jugador: Player): string?
	if workspace:GetAttribute("Final") or Bestia.activa() then
		return nil
	end
	local coche = CollectionService:GetTagged("Coche")[1]
	local piezas = 0
	for _, p in Config.Coche.Piezas do
		local hay = if coche then coche:GetAttribute(p[1]) else nil
		piezas += math.max(0, p[2] - (if type(hay) == "number" then hay else 0))
	end
	local gasolina = if coche then coche:GetAttribute("Gasolina") else nil
	local sinGasolina = (if type(gasolina) == "number" then gasolina else 0) < Config.Coche.Gasolina - 1e-3
	-- El generador no aguanta la noche: de día, por debajo del mínimo del tutorial y con gasolina a mano
	local _, nivel = generadorEncendido()
	local poca = Ciclo.fase() == "Dia" and nivel ~= nil and nivel < Config.Tutorial.Gasolina and hayGasolina()
	-- El final de la Bestia, si ya se ha empezado (la 12 leída y una cruz con gasolina o la reja montada). El generador
	-- sigue antes: sin luz no se llega a la noche final.
	if not poca and Pistas.leida(Config.Bestia.PistaCerillas) then
		local prep = Preparativos.estado()
		if prep.cruces > 0 or prep.montada then
			-- Lo que la frena y lo que la quema, en la mochila de cualquiera (ponerMetas lo repinta cada 2 s, así que
			-- coger o soltar la pistola o las cerillas cambia la meta enseguida)
			local pistola, cerillas = false, false
			for _, otro in Players:GetPlayers() do
				if Mochila.contar(otro, "Pistola") > 0 and Mochila.contar(otro, "Bengala") > 0 then
					pistola = true
				end
				if Mochila.contar(otro, "Cerillas") > 0 then
					cerillas = true
				end
			end
			local paso, faltan = PasosTutorial.metaBestia(prep.total - prep.cruces, Pistas.leida(Config.Bestia.Reja.Pista),
				prep.montada, pistola, cerillas)
			if paso == "Cruces" then
				return if faltan == 1
					then Lang.t(jugador, "Next: pour fuel on the last red cross.")
					else Lang.t(jugador, "Next: pour fuel on the red crosses. {n} left.", { n = faltan })
			elseif paso == "Plano" then
				return Lang.t(jugador, "Next: find Harlan's plan in the basement.")
			elseif paso == "Reja" then
				return Lang.t(jugador, "Next: build the gate at the basement bench and set it in its frame.")
			elseif paso == "Pistola" then
				return Lang.t(jugador, "Next: take the flare gun and flares from the attic.")
			elseif paso == "Cerillas" then
				return Lang.t(jugador, "Next: someone must carry the matches from the safe.")
			end
			return Lang.t(jugador, "Next: wait for her in the hall.")
		end
	end
	-- Lo que necesita la noche que viene (solo de día: las frases dicen "antes de la noche"): reparar lo roto y, desde
	-- que sale el Trepador, troncos junto a la chimenea.
	local fase, noche = Ciclo.fase()
	local nRotas, puerta = 0, false
	if fase == "Dia" then
		nRotas, puerta = rotas()
	end
	local chimenea = fase == "Dia" and noche > Config.Trepador.Noche and chimeneaSinTroncos()
	local meta, n = PasosTutorial.meta(Casa.cerradas(), piezas, sinGasolina, poca, nRotas, chimenea)
	if meta == "Generador" then
		return Lang.t(jugador, "Next: fuel the generator before night. The farm has fuel.")
	elseif meta == "Reparar" then
		if n == 1 then
			return if puerta
				then Lang.t(jugador, "Next: repair the broken door with a plank before night.")
				else Lang.t(jugador, "Next: repair the broken window with a plank before night.")
		end
		return Lang.t(jugador, "Next: repair the {n} broken windows and doors with planks before night.", { n = n })
	elseif meta == "Chimenea" then
		return Lang.t(jugador, "Next: leave logs by the fireplace. Fire drives off what comes down the chimney.")
	elseif meta == "Sotano" then
		return Lang.t(jugador, "Next: find the basement key. It's somewhere on the farm.")
	elseif meta == "Garaje" then
		return Lang.t(jugador, "Next: find the garage key. It's somewhere at the sawmill.")
	elseif meta == "Piezas" then
		return if n == 1
			then Lang.t(jugador, "Next: fix the car in the garage. 1 part missing.")
			else Lang.t(jugador, "Next: fix the car in the garage. {n} parts missing.", { n = n })
	elseif meta == "Gasolina" then
		return Lang.t(jugador, "Next: fill the car with fuel and escape.")
	end
	return Lang.t(jugador, "The car is ready. Get in and escape.")
end

-- Pone al día el atributo Meta (lo enseña el móvil) de quien ya no tiene tutorial.
local function ponerMetas()
	for jugador in conMeta do
		if not jugador.Parent then
			conMeta[jugador], avisadoEn[jugador] = nil, nil
			continue
		end
		local texto = textoMeta(jugador)
		if jugador:GetAttribute("Meta") ~= texto then
			jugador:SetAttribute("Meta", texto)
		end
	end
end

-- El aviso de una línea con la meta: de día, fuera de la escena de llegada y no dos veces seguidas (al entrar el día 1
-- llegan a la vez el de entrar y el del día).
local function avisarMeta(jugador: Player)
	while jugador.Parent and enEscena() do
		task.wait(0.5)
	end
	local ahora = os.clock()
	if not jugador.Parent or not conMeta[jugador] or Ciclo.fase() ~= "Dia"
		or ahora - (avisadoEn[jugador] or -math.huge) < Config.Tutorial.MetaOtraVez then
		return
	end
	local texto = textoMeta(jugador)
	jugador:SetAttribute("Meta", texto)
	if texto then
		avisadoEn[jugador] = ahora
		Remotes.Aviso:FireClient(jugador, texto)
	end
end

local function empezar(jugador: Player, conTutorial: boolean)
	while jugador.Parent and not jugador:GetAttribute("DatosListos") do
		task.wait(0.5)
	end
	-- Durante la escena de llegada en coche no empieza: espera a que acabe.
	while jugador.Parent and enEscena() do
		task.wait(0.5)
	end
	local datos = Datos.leer(jugador)
	if not jugador.Parent or not datos or activos[jugador] or conMeta[jugador] then
		return
	end
	if datos.logros.Tutorial or not conTutorial then
		-- Ya lo hizo (o no sale aquí): la siguiente meta, un momento después de entrar.
		conMeta[jugador] = true
		ponerMetas()
		task.delay(Config.Tutorial.Meta, avisarMeta, jugador)
		return
	end
	local a: Activo
	a = {
		estado = PasosTutorial.nuevo(),
		mochila = false,
		corrido = false,
		conexiones = {
			jugador:GetAttributeChangedSignal("MochilaAbierta"):Connect(function()
				if jugador:GetAttribute("MochilaAbierta") then
					a.mochila = true
				end
			end),
			-- Con la señal (y no mirando cada Cada s) no se escapa una carrera corta.
			jugador:GetAttributeChangedSignal("Corriendo"):Connect(function()
				if jugador:GetAttribute("Corriendo") == true then
					a.corrido = true
				end
			end),
		},
	}
	activos[jugador] = a
end

-- Lo salta (sin premio): ya no vuelve a salir en esta cuenta. La meta, enseguida.
local function saltar(jugador: Player, que: unknown)
	if que ~= "Saltar" or not activos[jugador] then
		return
	end
	quitar(jugador)
	conMeta[jugador] = true
	ponerMetas()
	task.delay(1, avisarMeta, jugador)
	if Datos.editar(jugador, function(datos)
		datos.logros.Tutorial = true
	end) then
		task.spawn(Datos.guardar, jugador)
	end
end

function Tutorial.start()
	if not Config.Tutorial.Activo then
		return
	end
	-- En Studio el tutorial solo sale con Config.Test.Tutorial; la siguiente meta, siempre.
	local conTutorial = not Prueba.activa() or Config.Test.Tutorial == true
	Players.PlayerAdded:Connect(function(jugador)
		empezar(jugador, conTutorial)
	end)
	for _, jugador in Players:GetPlayers() do
		task.spawn(empezar, jugador, conTutorial)
	end
	Players.PlayerRemoving:Connect(function(jugador)
		quitar(jugador)
		conMeta[jugador], avisadoEn[jugador] = nil, nil
	end)
	Remotes.Tutorial.OnServerEvent:Connect(saltar)
	-- Al empezar cada día (también al volver a empezarlo tras morir todos), la meta; un poco después, para no pisar el
	-- aviso del amanecer ni el premio del tutorial.
	Ciclo.alCambiar(function(fase)
		if fase == "Dia" then
			task.wait(Config.Tutorial.Meta)
			for jugador in conMeta do
				task.spawn(avisarMeta, jugador)
			end
		end
	end)
	task.spawn(function()
		local vueltas = 0
		while true do
			task.wait(Config.Tutorial.Cada)
			mirar()
			vueltas += 1
			if vueltas % 4 == 0 then -- la meta del móvil cambia poco: cada 2 s basta
				ponerMetas()
			end
		end
	end)
end

return Tutorial
