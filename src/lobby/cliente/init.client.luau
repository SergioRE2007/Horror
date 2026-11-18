-- Arranque del cliente del lugar Lobby: cada sistema es un módulo con start(). Los de comun/cliente valen también
-- para el juego.
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
arrancar(Comun:WaitForChild("Controles"))
arrancar(Comun:WaitForChild("AjustesUi")) -- engranaje de Ajustes: Rendimiento (14.4)

local Sistemas = script
arrancar(Sistemas.Clima) -- lluvia, niebla, relámpagos y sonidos de fondo (no espera a nada)
arrancar(Sistemas.GasolineraVista) -- la vida del lobby: luces que fallan, puerta, coches, polillas, la sombra
arrancar(Sistemas.CochesUi)
arrancar(Sistemas.SalidaVista) -- la cinemática del coche que se va
arrancar(Sistemas.LlegadaVista) -- el coche que llega a la plaza del que se fue
arrancar(Sistemas.TiendaUi)
arrancar(Sistemas.GuiaLobby) -- flecha y una línea para el jugador nuevo (16.7)
