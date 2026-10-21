-- Arranque del cliente del lugar Lobby: cada sistema es un módulo con start(). Los de comun/cliente valen también
-- para el juego.
local Comun = script.Parent:WaitForChild("Comun")

require(Comun:WaitForChild("Idioma")).start() -- lo primero: que nadie escriba un texto en el idioma que no es
require(Comun:WaitForChild("Avisos")).start()
require(Comun:WaitForChild("Controles")).start()

local Sistemas = script
require(Sistemas.CochesUi).start()
