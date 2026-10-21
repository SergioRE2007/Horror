-- Decide cuándo, dónde y qué bicho ataca cada noche, y lleva el amanecer y el "habéis muerto todos".
--   Noche: la tabla de dificultad (shared/Dificultad, según cuántos jugadores hay) dice cuántos ataques puede haber a
--   la vez, cada cuánto y cuánta paciencia tienen. Cada "hueco" lanza ataques uno detrás de otro a ventanas o puertas
--   libres (nunca la misma dos veces seguidas), cada noche más seguidos; los huecos llegan escalonados.
--   Desde la noche del Raspador, su primer ataque es seguro y luego sale a veces (uno como mucho a la vez).
--   Amanecer: los bichos se van, los muertos reviven y se hace una foto de la casa.
--   Si mueren todos: a los pocos segundos se vuelve al principio del día, con la casa como estaba al amanecer.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Dificultad = require(ReplicatedStorage.Shared.Dificultad)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Prueba = require(ReplicatedStorage.Shared.Prueba)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Casa = require(script.Parent.Casa)
local Ciclo = require(script.Parent.Ciclo)
local Golpeador = require(script.Parent.Golpeador)
local Muerte = require(script.Parent.Muerte)
local Raspador = require(script.Parent.Raspador)

local Director = {}

local G, R = Config.Golpeador, Config.Raspador
local azar = Random.new()
local turno = 0 -- sube con cada cambio de fase: los bucles de una noche anterior se paran solos
local foto = nil
local enUso: { [Model]: boolean } = {} -- ventanas y puertas con un ataque en marcha
local raspadorSeguro = false -- el primer ataque de la noche del Raspador es suyo

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
	while turno == mio do
		local raspa = n >= R.Noche and Raspador.cuantos() == 0 and (raspadorSeguro or azar:NextNumber() < R.Probabilidad)
		local lista = libres(raspa, ultimo)
		if #lista == 0 then
			esperar(2, mio)
			continue
		end
		if raspa then
			raspadorSeguro = false
		end
		local el = lista[azar:NextInteger(1, #lista)]
		ultimo = el
		enUso[el] = true
		local sigue = (if raspa then Raspador else Golpeador).atacar(el, n, dif.paciencia)
		while sigue() and turno == mio do
			task.wait(0.5)
		end
		enUso[el] = nil
		esperar(math.max(G.IntervaloMin, rango(G.Intervalo) - G.MenosPorNoche * (n - 1)) * dif.ritmo, mio)
	end
end

local function noche(mio: number, n: number)
	table.clear(enUso)
	raspadorSeguro = n == R.Noche
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
		turno += 1
		if fase == "Dia" then
			Golpeador.irse()
			Raspador.irse()
			Muerte.revivirTodos()
			foto = Casa.foto()
		else
			noche(turno, n)
		end
	end)
	-- Modo de pruebas: ServerStorage.Prueba:Fire(orden, punto). Órdenes: "Noche", "Dia", "Ataque" o "Raspador" (a la
	-- ventana o puerta más cerca del punto) y "Esconder" (el primer jugador, en el escondite más cerca del punto).
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
			elseif que == "Ataque" or que == "Raspador" then
				local el = masCerca(punto, que == "Raspador")
				if el then
					(if que == "Raspador" then Raspador else Golpeador).atacar(el, select(2, Ciclo.fase()))
				end
			else
				Ciclo.forzar(que)
			end
		end)
		orden.Parent = game:GetService("ServerStorage")
	end
	Muerte.alMorirTodos(function()
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
		table.clear(enUso)
		if foto then
			Casa.restaurar(foto)
		end
		Ciclo.reiniciarDia()
	end)
end

return Director
