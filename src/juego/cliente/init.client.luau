-- Arranque del cliente del lugar Juego: cada sistema es un módulo con start(). Los de comun/cliente valen también
-- para el lobby.
local Comun = script.Parent:WaitForChild("Comun")

require(Comun:WaitForChild("Idioma")).start() -- lo primero: que nadie escriba un texto en el idioma que no es
require(Comun:WaitForChild("Avisos")).start()

local Sistemas = script
require(Sistemas.Sonido).start() -- antes que los que tocan sonidos
require(Sistemas.OidoVista).start() -- Oído: sonido tapado por las paredes y eco de cada sala (oido.md)
require(Sistemas.Pasos).start()
require(Sistemas.Ambiente).start()
require(Sistemas.CuerpoVista).start() -- la cámara como un cuerpo: pasos, respirar, caer
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
require(Sistemas.ManosPrueba).start() -- solo en Studio: lanzar gestos a mano
require(Sistemas.EquipoVista).start()
require(Sistemas.MochilaUi).start() -- después de EquipoVista: su botón va en la misma fila
require(Sistemas.MovilUi).start() -- después de EquipoVista: su botón va en la misma fila
require(Sistemas.PosturaVista).start() -- agacharse y asomarse (14.6); después de EquipoVista: su botón va en la misma fila
require(Sistemas.CorrerVista).start() -- correr y aguante (14.8); después de PosturaVista: su botón va detrás de AGACHARSE
require(Sistemas.CargarVista).start()
require(Sistemas.TrabajoVista).start()
require(Sistemas.BrazosVista).start() -- los brazos de los demás jugadores
require(Sistemas.MuerteVista).start()
require(Sistemas.EsconditeVista).start() -- los escondites vistos desde fuera: puertas del armario y colcha (manos.md)
require(Sistemas.MirarVista).start() -- mirar por la mirilla y entre las cortinas (manos.md)
require(Sistemas.PavorVista).start() -- Pavor al ver un bicho: vértigo, manos que tiemblan y latido (pavor.md)
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
require(Sistemas.PuertaRotaVista).start() -- Puertas que revientan: astillas, la hoja colgando de una bisagra (puerta-rota.md)
require(Sistemas.BichitosVista).start() -- Bichitos: ratas que huyen de la linterna, polillas y moscas (bichitos.md)
require(Sistemas.HuellasVista).start() -- Huellas de barro y de sangre que dicen por dónde ha ido el bicho (huellas.md)
require(Sistemas.MarcasVista).start() -- Marcas de la noche: arañazos en las puertas y sangre en las paredes (marcas.md)
require(Sistemas.OjosVista).start() -- Ojos en la oscuridad: la linterna los hace brillar entre los árboles (ojos.md)
require(Sistemas.CadaverVista).start() -- Cuerpos que caen de verdad: el muñeco del muerto (cadaver.md); tras MuerteVista
require(Sistemas.AireVista).start() -- Aire vivo: polvo siempre en la luz, haces de luna y niebla baja (aire.md)
require(Sistemas.TormentaVista).start() -- Tormenta seca: relámpagos que iluminan la casa y recortan a los bichos (tormenta.md)
require(Sistemas.Sustos).start()
require(Sistemas.AmbienteMiedo).start()
require(Sistemas.ClaseVista).start()
require(Sistemas.RevivirUi).start()
require(Sistemas.TutorialVista).start() -- los primeros minutos (14.2)
