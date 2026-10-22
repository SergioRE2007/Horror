-- Decide cuándo, dónde y qué bicho ataca cada noche, y lleva el amanecer y el "habéis muerto todos".
--   Noche: la tabla de dificultad (shared/Dificultad, según cuántos jugadores hay) dice cuántos ataques puede haber a
--   la vez, cada cuánto y cuánta paciencia tienen. Cada "hueco" lanza ataques uno detrás de otro a ventanas o puertas
--   libres (nunca la misma dos veces seguidas), cada noche más seguidos; los huecos llegan escalonados.
--   Desde la noche del Raspador, su primer ataque es seguro y luego sale a veces (uno como mucho a la vez). Igual el
--   Trepador (por la chimenea) y el Imitador (a la puerta principal; su primera noche se va la luz). El Acechador va
--   aparte: sale solo al que se queda en el bosque al anochecer.
--   Amanecer: los bichos se van y los muertos reviven (Partida hace la foto de todo y la guarda).
--   Si mueren todos: a los pocos segundos se vuelve al principio del día, con todo como estaba al amanecer.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Dificultad = require(ReplicatedStorage.Shared.Dificultad)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Prueba = require(ReplicatedStorage.Shared.Prueba)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Acechador = require(script.Parent.Acechador)
local Casa = require(script.Parent.Casa)
local Chimenea = require(script.Parent.Chimenea)
local Ciclo = require(script.Parent.Ciclo)
local Golpeador = require(script.Parent.Golpeador)
local Imitador = require(script.Parent.Imitador)
local Muerte = require(script.Parent.Muerte)
local Partida = require(script.Parent.Partida)
local Recompensas = require(game:GetService("ServerScriptService"):WaitForChild("Comun").Recompensas)
local Raspador = require(script.Parent.Raspador)
local Trepador = require(script.Parent.Trepador)

local Director = {}

local G, R, T, I = Config.Golpeador, Config.Raspador, Config.Trepador, Config.Imitador
local azar = Random.new()
local turno = 0 -- sube con cada cambio de fase: los bucles de una noche anterior se paran solos
local enUso: { [Model]: boolean } = {} -- ventanas y puertas con un ataque en marcha
local seguros: { [string]: boolean } = {} -- el primer ataque de la noche en que sale un bicho nuevo es suyo
local apagon = false -- ya se ha ido la luz esta noche (la primera del Imitador)

local function rango(r: { number }): number
	return azar:NextNumber(r[1], r[2])
end

local function esperar(segundos: number, mio: number)
	local hasta = os.clock() + segundos
	while os.clock() < hasta and turno == mio do
		task.wait(0.5)
	end
end

-- Ventanas o puertas libres a las que puede ir ese bicho, sin repetir `ultimo` si hay más.
local function libres(soloVentanas: boolean, ultimo: Model?): { Model }
	local lista = {}
	for _, el in Casa.atacables() do
		if not enUso[el] and el ~= ultimo and (not soloVentanas or Casa.estado(el).tipo == "Ventana") then
			table.insert(lista, el)
		end
	end
	if #lista == 0 and ultimo and not enUso[ultimo] and (not soloVentanas or Casa.estado(ultimo).tipo == "Ventana") then
		table.insert(lista, ultimo)
	end
	return lista
end

local function jugadores(): number
	if Prueba.activa() and Config.Test.Jugadores then
		return Config.Test.Jugadores
	end
	return math.max(1, #Players:GetPlayers())
end

-- Un hueco de ataques: uno detrás de otro hasta que acaba la noche.
local function hueco(mio: number, n: number, dif: Dificultad.Noche, retraso: number)
	esperar(rango(G.PrimerAtaque) + retraso, mio)
	local ultimo: Model? = nil
	while turno == mio and not Partida.terminada() do
		-- Qué bicho: los especiales, uno como mucho a la vez cada uno; si no, el Golpeador.
		local function toca(que: string, desde: number, probabilidad: number, cuantos: number): boolean
			return n >= desde and cuantos == 0 and (seguros[que] or azar:NextNumber() < probabilidad)
		end
		local puerta = Casa.principal()
		local que = "Golpeador"
		if puerta and not enUso[puerta] and toca("Imitador", I.Noche, I.Probabilidad, Imitador.cuantos()) then
			que = "Imitador"
		elseif toca("Trepador", T.Noche, T.Probabilidad, Trepador.cuantos()) then
			que = "Trepador"
		elseif toca("Raspador", R.Noche, R.Probabilidad, Raspador.cuantos()) then
			que = "Raspador"
		end
		local el: Model? = nil
		if que == "Imitador" then
			el = puerta
		elseif que ~= "Trepador" then
			local lista = libres(que == "Raspador", ultimo)
			if #lista == 0 then
				esperar(2, mio)
				continue
			end
			el = lista[azar:NextInteger(1, #lista)]
			ultimo = el
		end
		seguros[que] = nil
		local sigue
		if que == "Trepador" then
			sigue = Trepador.atacar(n, dif.paciencia)
		elseif que == "Imitador" then
			sigue = Imitador.atacar(el :: Model, n, dif.paciencia, n == I.Noche and not apagon)
			apagon = apagon or n == I.Noche
		else
			sigue = (if que == "Raspador" then Raspador else Golpeador).atacar(el :: Model, n, dif.paciencia)
		end
		if el then
			enUso[el] = true
		end
		while sigue() and turno == mio do
			task.wait(0.5)
		end
		if el then
			enUso[el] = nil
		end
		esperar(math.max(G.IntervaloMin, rango(G.Intervalo) - G.MenosPorNoche * (n - 1)) * dif.ritmo, mio)
	end
end

local function noche(mio: number, n: number)
	table.clear(enUso)
	seguros = { Raspador = n == R.Noche, Trepador = n == T.Noche, Imitador = n == I.Noche }
	apagon = false
	local dif = Dificultad.de(jugadores(), azar:NextNumber(), Config.Dificultad)
	local retraso = 0
	for i = 1, dif.alaVez do
		task.spawn(hueco, mio, n, dif, retraso)
		retraso += rango(Config.Separacion)
	end
end

-- La ventana o puerta atacable más cerca de un punto (modo de pruebas).
local function masCerca(punto: Vector3?, soloVentanas: boolean): Model?
	local mejor, distancia = nil, math.huge
	for _, el in Casa.atacables() do
		local d = ((el:GetAttribute("Fuera") :: Vector3) - (punto or Vector3.zero)).Magnitude
		if d < distancia and (not soloVentanas or Casa.estado(el).tipo == "Ventana") then
			mejor, distancia = el, d
		end
	end
	return mejor
end

function Director.start()
	Ciclo.alCambiar(function(fase, n)
		Recompensas.fase(fase, n)
		turno += 1
		if fase == "Dia" then
			Golpeador.irse()
			Raspador.irse()
			Trepador.irse()
			Imitador.irse()
			Acechador.irse()
			Muerte.revivirTodos()
		else
			noche(turno, n)
		end
	end)
	-- Modo de pruebas: ServerStorage.Prueba:Fire(orden, punto). Órdenes: "Noche", "Dia", "Ataque" o "Raspador" (a la
	-- ventana o puerta más cerca del punto), "Romper" (la rompe) y "Esconder" (el primer jugador, en el escondite más cerca del punto).
	-- Bichos nuevos: "Trepador", "Imitador" (con apagón), "Acechador" (a por el primer jugador, que debe estar en el
	-- bosque) y "Fuego" (echa un tronco a la chimenea).
	if Prueba.activa() then
		local orden = Instance.new("BindableEvent")
		orden.Name = "Prueba"
		orden.Event:Connect(function(que: string, punto: Vector3?)
			if que == "Esconder" then
				local mejor, distancia = nil, math.huge
				for _, sitio in game:GetService("CollectionService"):GetTagged("Escondite") do
					local d = (sitio.Mando.Position - (punto or Vector3.zero)).Magnitude
					if d < distancia then
						mejor, distancia = sitio, d
					end
				end
				Muerte.esconder(Players:GetPlayers()[1], mejor)
			elseif que == "Romper" then -- rompe la ventana o puerta de fuera más cerca (para probar a repararla)
				local el = masCerca(punto, false)
				if el then
					Casa.romper(el)
				end
			elseif que == "Ataque" or que == "Raspador" then
				local el = masCerca(punto, que == "Raspador")
				if el then
					(if que == "Raspador" then Raspador else Golpeador).atacar(el, select(2, Ciclo.fase()))
				end
			elseif que == "Trepador" then
				Trepador.atacar(select(2, Ciclo.fase()))
			elseif que == "Imitador" then
				local puerta = Casa.principal()
				if puerta then
					Imitador.atacar(puerta, select(2, Ciclo.fase()), 1, true)
				end
			elseif que == "Acechador" then
				Acechador.atacar(Players:GetPlayers()[1])
			elseif que == "Fuego" then
				Chimenea.echar(1)
			elseif que == "Noche" or que == "Dia" then -- las demás órdenes son de otros sistemas (Partida)
				Ciclo.forzar(que)
			elseif que == "Saltar" then -- acaba la fase de ahora (de noche, un amanecer que paga)
				Ciclo.saltar()
			end
		end)
		orden.Parent = game:GetService("ServerStorage")
	end
	Muerte.alMorirTodos(function()
		if Partida.terminada() then
			return
		end
		local mio = turno
		for _, jugador in Players:GetPlayers() do
			Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "Nobody made it. The day starts again."))
		end
		task.wait(Config.Ciclo.Reinicio)
		if turno ~= mio or #Muerte.vivos() > 0 then
			return
		end
		Golpeador.quitar()
		Raspador.quitar()
		Trepador.quitar()
		Imitador.quitar()
		Acechador.quitar()
		Chimenea.apagar()
		table.clear(enUso)
		Partida.volverAlAmanecer()
		Ciclo.reiniciarDia()
	end)
end

return Director
