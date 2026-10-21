-- Todos los números del juego. El equilibrio se toca solo aquí.
-- Listas que se guardan (clases, cosméticos…): no reordenar nunca, lo nuevo al final.
local Config = {}

-- Los dos lugares de la experiencia (lobby.project.json y juego.project.json). 0 = aún sin publicar.
Config.Lugares = {
	Lobby = 0,
	Juego = 0,
}

-- Guardado con candado de sesión (comun/servidor/Datos y Candado).
Config.Guardado = {
	Almacen = "Jugadores_v1", -- nombre del DataStore de los jugadores; cambiarlo borra todo, no tocar con jugadores reales
	Intervalo = 120, -- segundos entre guardados automáticos
	Reintento = 3, -- segundos entre intentos al cargar o guardar
	Espera = 30, -- segundos esperando a que otro servidor suelte la partida antes de echar al jugador
	Caduca = 600, -- segundos sin renovarse tras los que un candado se da por muerto (servidor caído); bastante más que Intervalo
	Intentos = 3, -- intentos del guardado al salir
	Cierre = 25, -- segundos como mucho esperando a los guardados al cerrar el servidor
}

-- Modo de pruebas: solo actúa en Studio (shared/Prueba). Con él no se lee ni se guarda nada.
Config.Test = {
	Activo = true, -- en Studio: partida sin guardar y lo de abajo
	Monedas = 1e6, -- monedas al entrar; 0 = las de una partida nueva
	Lang = nil :: string?, -- "es" o "en" fuerza el idioma en Studio; nil = el del jugador
}

return Config
