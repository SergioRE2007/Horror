-- Arranque del cliente del lugar Juego: cada sistema es un módulo con start(). Los de comun/cliente valen también
-- para el lobby.
local Comun = script.Parent:WaitForChild("Comun")

require(Comun:WaitForChild("Idioma")).start() -- lo primero: que nadie escriba un texto en el idioma que no es
