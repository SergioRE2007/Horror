-- Arranque del servidor del lugar Juego (la casa, el bosque y el pueblo): cada sistema es un módulo con start().
-- Los de comun/servidor valen también para el lobby.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

require(ReplicatedStorage.Shared.Remotes) -- crea los RemoteEvents antes de que nadie los use

local Comun = ServerScriptService:WaitForChild("Comun")

require(Comun.Limpieza).start() -- lo primero: deja el Workspace solo con lo del código
require(Comun.Idioma).start()
require(Comun.Datos).start()
require(Comun.Recompensas).start()

local Sistemas = script
require(Sistemas.Mapa).start() -- la casa y el bosque, antes que lo que los usa
require(Sistemas.Casa).start()
require(Sistemas.Muerte).start()
require(Sistemas.Golpeador).start()
require(Sistemas.Cargar).start()
require(Sistemas.Mochila).start()
require(Sistemas.Equipo).start()
require(Sistemas.Recursos).start()
require(Sistemas.Generador).start()
require(Sistemas.Chimenea).start()
require(Sistemas.Movil).start()
require(Sistemas.Llaves).start()
require(Sistemas.Vendedor).start()
require(Sistemas.Taller).start()
require(Sistemas.Coche).start()
require(Sistemas.Director).start()
require(Sistemas.Acechador).start()
local noche = require(Sistemas.Partida).start() -- espera a cargar la partida y deja el mundo como estaba
require(Sistemas.Ciclo).start(noche) -- lo último: el primer día empieza cuando todos están escuchando
