-- Arranque del cliente del lugar Juego: cada sistema es un módulo con start(). Los de comun/cliente valen también
-- para el lobby.
local Comun = script.Parent:WaitForChild("Comun")

require(Comun:WaitForChild("Idioma")).start() -- lo primero: que nadie escriba un texto en el idioma que no es
require(Comun:WaitForChild("Avisos")).start()

local Sistemas = script
require(Sistemas.Sonido).start() -- antes que los que tocan sonidos
require(Sistemas.Pasos).start()
require(Sistemas.Ambiente).start()
require(Comun:WaitForChild("Controles")).start()
require(Comun:WaitForChild("AjustesUi")).start() -- engranaje de Ajustes: Rendimiento (14.4)
require(Sistemas.CasaVista).start()
require(Sistemas.GolpeadorVista).start()
require(Sistemas.RaspadorVista).start()
require(Sistemas.TrepadorVista).start()
require(Sistemas.ImitadorVista).start()
require(Sistemas.AcechadorVista).start()
require(Sistemas.ChimeneaVista).start()
task.spawn(require(Sistemas.DetallesVista).start) -- espera al mapa: que no frene a los de después
require(Sistemas.Manos).start() -- brazos en primera persona (las capas se apuntan antes o después, da igual)
require(Sistemas.ManosGestos).start()
require(Sistemas.EquipoVista).start()
require(Sistemas.MochilaUi).start() -- después de EquipoVista: su botón va en la misma fila
require(Sistemas.MovilUi).start() -- después de EquipoVista: su botón va en la misma fila
require(Sistemas.CargarVista).start()
require(Sistemas.TrabajoVista).start()
require(Sistemas.BrazosVista).start() -- los brazos de los demás jugadores
require(Sistemas.MuerteVista).start()
require(Sistemas.VendedorUi).start()
require(Sistemas.PistasUi).start()
require(Sistemas.TallerUi).start()
require(Sistemas.HuidaVista).start()
require(Sistemas.BestiaVista).start() -- final de la Bestia (12.2)
require(Sistemas.BengalasVista).start()
require(Sistemas.PreparativosVista).start()
require(Sistemas.IncendioVista).start()
require(Sistemas.LatasVista).start() -- más miedo (14.3)
require(Sistemas.Efectos).start()
require(Sistemas.Sustos).start()
require(Sistemas.AmbienteMiedo).start()
require(Sistemas.ClaseVista).start()
require(Sistemas.RevivirUi).start()
require(Sistemas.TutorialVista).start() -- los primeros minutos (14.2)
