-- Decide cuándo y dónde ataca el Golpeador cada noche, y lleva el amanecer y el "habéis muerto todos".
--   Noche: tras un rato, ataques uno detrás de otro a ventanas o a la puerta al azar (nunca la misma dos veces
--   seguidas), cada noche más seguidos.
--   Amanecer: el bicho se va, los muertos reviven y se hace una foto de la casa.
--   Si mueren todos: a los pocos segundos se vuelve al principio del día, con la casa como estaba al amanecer.
-- Provisional hasta la tabla de dificultad (paso 3): un solo ataque a la vez, sin mirar cuántos jugadores hay.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Prueba = require(ReplicatedStorage.Shared.Prueba)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Casa = require(script.Parent.Casa)
local Ciclo = require(script.Parent.Ciclo)
local Golpeador = require(script.Parent.Golpeador)
local Muerte = require(script.Parent.Muerte)

local Director = {}

local G = Config.Golpeador
local azar = Random.new()
local turno = 0 -- sube con cada cambio de fase: los bucles de una noche anterior se paran solos
local foto = nil

local function rango(r: { number }): number
	return azar:NextNumber(r[1], r[2])
end

local function esperar(segundos: number, mio: number)
	local hasta = os.clock() + segundos
	while os.clock() < hasta and turno == mio do
		task.wait(0.5)
	end
end

local function noche(mio: number, n: number)
	esperar(rango(G.PrimerAtaque), mio)
	local ultimo: Model? = nil
	while turno == mio do
		local lista = Casa.atacables()
		if #lista > 1 and ultimo then
			table.remove(lista, table.find(lista, ultimo) or #lista + 1)
		end
		ultimo = lista[azar:NextInteger(1, #lista)]
		Golpeador.atacar(ultimo :: Model, n)
		while Golpeador.activo() and turno == mio do
			task.wait(0.5)
		end
		esperar(math.max(G.IntervaloMin, rango(G.Intervalo) - G.MenosPorNoche * (n - 1)), mio)
	end
end

function Director.start()
	Ciclo.alCambiar(function(fase, n)
		turno += 1
		if fase == "Dia" then
			Golpeador.irse()
			Muerte.revivirTodos()
			foto = Casa.foto()
		else
			noche(turno, n)
		end
	end)
	-- Modo de pruebas: ServerStorage.Prueba:Fire(orden, punto). Órdenes: "Noche", "Dia", "Ataque" (a la ventana o
	-- puerta más cerca del punto) y "Esconder" (el primer jugador, en el escondite más cerca del punto).
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
			elseif que == "Ataque" then
				local mejor, distancia = nil, math.huge
				for _, el in Casa.atacables() do
					local d = ((el:GetAttribute("Fuera") :: Vector3) - (punto or Vector3.zero)).Magnitude
					if d < distancia then
						mejor, distancia = el, d
					end
				end
				Golpeador.quitar()
				Golpeador.atacar(mejor, select(2, Ciclo.fase()))
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
		if foto then
			Casa.restaurar(foto)
		end
		Ciclo.reiniciarDia()
	end)
end

return Director
