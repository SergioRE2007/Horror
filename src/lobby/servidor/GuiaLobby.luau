-- Guía corta del lobby para el jugador nuevo (16.7). Aquí solo se decide la etapa de cada jugador y se publica en su
-- atributo `GuiaLobby` ("Coche", "Tienda" o ninguno); la flecha y el cartel los pone lobby/cliente/GuiaLobby. Las
-- reglas (quién es nuevo, qué se le enseña) están en GuiaReglas y no cambian lo guardado.
-- Se decide una vez al cargar sus datos: la etapa vale para toda la visita. La de la tienda se apunta como vista en
-- `logros` en ese momento, para que salga una sola vez por cuenta (aunque ni la mire).
-- Config.Lobby.Guia.Forzar fuerza la etapa en Studio (para probarla con una cuenta que ya ha jugado).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Prueba = require(ReplicatedStorage.Shared.Prueba)
local Comun = ServerScriptService:WaitForChild("Comun")
local Comprar = require(Comun.Comprar)
local Datos = require(Comun.Datos)
local GuiaReglas = require(script.Parent.GuiaReglas)

local GuiaLobby = {}

local ESPERA = 60 -- segundos que se espera a que carguen sus datos (si no, sin guía)

local function etapaDe(jugador: Player): string?
	local datos = Datos.leer(jugador)
	if not datos then
		return nil
	end
	local forzada = Config.Lobby.Guia.Forzar
	if Prueba.activa() and (forzada == "Coche" or forzada == "Tienda") then
		return forzada
	end
	local etapa = GuiaReglas.etapa(datos, Comprar.precioClase)
	if etapa == "Tienda" then
		Datos.editar(jugador, function(d)
			d.logros[GuiaReglas.VISTA] = true
		end)
	end
	return etapa
end

local function preparar(jugador: Player)
	local hasta = os.clock() + ESPERA
	while jugador.Parent and not jugador:GetAttribute("DatosListos") and os.clock() < hasta do
		task.wait(0.25)
	end
	if not jugador.Parent or not jugador:GetAttribute("DatosListos") then
		return
	end
	jugador:SetAttribute("GuiaLobby", etapaDe(jugador))
end

function GuiaLobby.start()
	Players.PlayerAdded:Connect(function(jugador)
		task.spawn(preparar, jugador)
	end)
	for _, jugador in Players:GetPlayers() do
		task.spawn(preparar, jugador)
	end
end

return GuiaLobby
