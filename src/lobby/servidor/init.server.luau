-- Arranque del servidor del lugar Lobby (gasolinera, coches, tienda): cada sistema es un módulo con start().
-- Los de comun/servidor valen también para el juego.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

require(ReplicatedStorage.Shared.Remotes) -- crea los RemoteEvents antes de que nadie los use

local Comun = ServerScriptService:WaitForChild("Comun")

require(Comun.Limpieza).start() -- lo primero: deja el Workspace solo con lo del código
require(Comun.Idioma).start()
require(Comun.Datos).start()

local Sistemas = script
require(Sistemas.Gasolinera).start() -- el mapa, antes que los coches
require(Sistemas.Coches).start()
