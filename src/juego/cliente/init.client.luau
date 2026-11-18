-- Arranque del cliente del lugar Juego: cada sistema es un módulo con start(). Los de comun/cliente valen también
-- para el lobby.
local Comun = script.Parent:WaitForChild("Comun")

-- Arranca un sistema sin que un fallo suyo frene a los de después: require y start van protegidos (el error sale como
-- aviso con su traza) y, con `aparte`, en su propio hilo (los que esperan al mapa: así no bloquean el arranque).
local function arrancar(modulo: ModuleScript, aparte: boolean?)
	local function lanzar()
		local ok, err = xpcall(function()
			require(modulo).start()
		end, debug.traceback)
		if not ok then
			warn(`[arranque] {modulo.Name} no ha arrancado: {err}`)
		end
	end
	if aparte then
		task.spawn(lanzar)
	else
		lanzar()
	end
end

arrancar(Comun:WaitForChild("Idioma")) -- lo primero: que nadie escriba un texto en el idioma que no es
arrancar(Comun:WaitForChild("Avisos"))

local Sistemas = script
arrancar(Sistemas.Sonido) -- antes que los que tocan sonidos
arrancar(Sistemas.OidoVista) -- Oído: sonido tapado por las paredes y eco de cada sala (oido.md)
arrancar(Sistemas.Pasos)
arrancar(Sistemas.Ambiente)
arrancar(Sistemas.CuerpoVista) -- la cámara como un cuerpo: pasos, respirar, caer
arrancar(Comun:WaitForChild("Controles"))
arrancar(Comun:WaitForChild("AjustesUi")) -- engranaje de Ajustes: Rendimiento (14.4)
arrancar(Sistemas.CasaVista)
arrancar(Sistemas.GolpeadorVista, true)
arrancar(Sistemas.RaspadorVista, true)
arrancar(Sistemas.TrepadorVista, true)
arrancar(Sistemas.ImitadorVista, true)
arrancar(Sistemas.AcechadorVista, true)
arrancar(Sistemas.ChimeneaVista, true)
arrancar(Sistemas.DetallesVista, true) -- espera al mapa: que no frene a los de después
arrancar(Sistemas.Manos) -- brazos en primera persona (las capas se apuntan antes o después, da igual)
arrancar(Sistemas.ManosGestos)
arrancar(Sistemas.ManosPrueba) -- solo en Studio: lanzar gestos a mano
arrancar(Sistemas.EquipoVista)
arrancar(Sistemas.MochilaUi) -- después de EquipoVista: su botón va en la misma fila
arrancar(Sistemas.MovilUi) -- después de EquipoVista: su botón va en la misma fila
arrancar(Sistemas.PosturaVista) -- agacharse y asomarse (14.6); después de EquipoVista: su botón va en la misma fila
arrancar(Sistemas.CorrerVista) -- correr y aguante (14.8); después de PosturaVista: su botón va detrás de AGACHARSE
arrancar(Sistemas.CargarVista)
arrancar(Sistemas.TrabajoVista)
arrancar(Sistemas.BrazosVista) -- los brazos de los demás jugadores
arrancar(Sistemas.MuerteVista)
arrancar(Sistemas.EsconditeVista) -- los escondites vistos desde fuera: puertas del armario y colcha (manos.md)
arrancar(Sistemas.MirarVista) -- mirar por la mirilla y entre las cortinas (manos.md)
arrancar(Sistemas.PavorVista) -- Pavor al ver un bicho: vértigo, manos que tiemblan y latido (pavor.md)
arrancar(Sistemas.VendedorUi)
arrancar(Sistemas.PistasUi)
arrancar(Sistemas.TallerUi)
arrancar(Sistemas.HuidaVista)
arrancar(Sistemas.LlegadaCocheVista) -- escena de llegada en coche (16.8)
arrancar(Sistemas.BestiaVista, true) -- final de la Bestia (12.2)
arrancar(Sistemas.BengalasVista)
arrancar(Sistemas.PreparativosVista)
arrancar(Sistemas.IncendioVista)
arrancar(Sistemas.LatasVista) -- más miedo (14.3)
arrancar(Sistemas.Efectos)
arrancar(Sistemas.PuertaRotaVista) -- Puertas que revientan: astillas, la hoja colgando de una bisagra (puerta-rota.md)
arrancar(Sistemas.DesordenVista) -- La casa se desordena: lo que cae con los golpes y las sillas que vuelca el bicho (desorden.md)
arrancar(Sistemas.BichitosVista) -- Bichitos: ratas que huyen de la linterna, polillas y moscas (bichitos.md)
arrancar(Sistemas.HuellasVista) -- Huellas de barro y de sangre que dicen por dónde ha ido el bicho (huellas.md)
arrancar(Sistemas.MarcasVista) -- Marcas de la noche: arañazos en las puertas y sangre en las paredes (marcas.md)
arrancar(Sistemas.CadaverVista) -- Cuerpos que caen de verdad: el muñeco del muerto (cadaver.md); tras MuerteVista
arrancar(Sistemas.OjosVista) -- Ojos en la oscuridad: la linterna los hace brillar entre los árboles (ojos.md)
arrancar(Sistemas.AireVista) -- Aire vivo: polvo siempre en la luz, haces de luna y niebla baja (aire.md)
arrancar(Sistemas.TormentaVista) -- Tormenta seca: relámpagos que iluminan la casa y recortan a los bichos (tormenta.md)
arrancar(Sistemas.AdaptarVista) -- Ojos que se acostumbran a la oscuridad (y deslumbran) (adaptar.md)
arrancar(Sistemas.Sustos)
arrancar(Sistemas.AmbienteMiedo)
arrancar(Sistemas.ClaseVista)
arrancar(Sistemas.RevivirUi)
arrancar(Sistemas.TutorialVista) -- los primeros minutos (14.2)
