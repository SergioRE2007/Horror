-- Arranque del cliente del lugar Lobby: cada sistema es un módulo con start(). Los de comun/cliente valen también
-- para el juego.
local Comun = script.Parent:WaitForChild("Comun")

require(Comun:WaitForChild("Idioma")).start() -- lo primero: que nadie escriba un texto en el idioma que no es
require(Comun:WaitForChild("Avisos")).start()
require(Comun:WaitForChild("Controles")).start()
require(Comun:WaitForChild("AjustesUi")).start() -- engranaje de Ajustes: Rendimiento (14.4)

local Sistemas = script
require(Sistemas.Clima).start() -- lluvia, niebla, relámpagos y sonidos de fondo (no espera a nada)
require(Sistemas.GasolineraVista).start() -- la vida del lobby: luces que fallan, puerta, coches, polillas, la sombra
require(Sistemas.CochesUi).start()
require(Sistemas.SalidaVista).start() -- la cinemática del coche que se va
require(Sistemas.LlegadaVista).start() -- el coche que llega a la plaza del que se fue
require(Sistemas.TiendaUi).start()
