-- Arranque del cliente del lugar Juego: cada sistema es un módulo con start(). Los de comun/cliente valen también
-- para el lobby.
local Comun = script.Parent:WaitForChild("Comun")

require(Comun:WaitForChild("Idioma")).start() -- lo primero: que nadie escriba un texto en el idioma que no es
require(Comun:WaitForChild("Avisos")).start()

local Sistemas = script
require(Sistemas.Sonido).start() -- antes que los que tocan sonidos
require(Sistemas.Ambiente).start()
require(Sistemas.Controles).start()
require(Sistemas.CasaVista).start()
require(Sistemas.GolpeadorVista).start()
require(Sistemas.MuerteVista).start()
