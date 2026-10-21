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

-- Día y noche (juego/servidor/Ciclo). Segundos.
Config.Ciclo = {
	Dia = 180,
	Noche = 240,
	Aviso = 20, -- segundos antes de anochecer en que suena el aviso
	Reinicio = 6, -- segundos tras morir todos hasta volver al principio del día
}

-- Puertas, persianas y cristales (juego/servidor/Casa y shared/Defensa).
Config.Casa = {
	TiempoPersiana = 1.4, -- lo que tarda en bajar o subir; a medio bajar no protege
	TiempoPuerta = 0.5,
	VidaPersiana = 100,
	VidaPuerta = 160,
	GolpesCristal = 3, -- golpes al cristal sin persiana hasta romperlo y entrar
	Reparar = 4, -- segundos manteniendo pulsado para reparar (provisional: gratis hasta que haya tablones)
	Alcance = 8, -- distancia para tocar las cosas
}

-- El Golpeador (juego/servidor/Golpeador y Director). Rangos {mínimo, máximo}.
Config.Golpeador = {
	PrimerAtaque = { 15, 25 }, -- segundos desde que anochece
	Intervalo = { 30, 45 }, -- segundos entre ataques la primera noche
	MenosPorNoche = 3, -- cada noche los ataques llegan antes...
	IntervaloMin = 15, -- ...hasta este mínimo
	Paciencia = { 14, 20 }, -- segundos golpeando una persiana o puerta cerrada antes de cansarse
	MasPaciencia = 1, -- segundos más por noche
	CadaGolpe = { 1.3, 2.1 },
	Dano = { 5, 7 }, -- a la persiana o la puerta por golpe: un ataque quita ~60 % a una persiana nueva
	Grito = 4, -- segundos rugiendo al entrar: tiempo para esconderse
	Caza = 35, -- segundos dentro de la casa
	Andar = 9,
	Correr = 17, -- el jugador anda a 16
	Pillar = 4.5, -- distancia a la que te pilla
	Vista = 70, -- hasta dónde ve
	VioEsconderse = 1.5, -- si te vio hasta este tiempo antes de esconderte, sabe dónde estás
}

-- El Raspador (juego/servidor/Raspador): se pega a una ventana y raspa despacio. La persiana no le para: hay que
-- subirla y darle un flashazo. La linterna lo frena. Si termina de raspar, entra y caza como el Golpeador (más lento).
-- Números a ojo.
Config.Raspador = {
	Noche = 3, -- primera noche en la que sale; su primer ataque de esa noche es seguro
	Probabilidad = 0.35, -- desde entonces, de cada ataque, cuántos son suyos
	Raspar = { 26, 34 }, -- segundos raspando hasta entrar
	MenosPorNoche = 1, -- cada noche raspa antes...
	RasparMin = 16, -- ...hasta este mínimo
	Frena = 0.25, -- con la linterna encima raspa a esta velocidad
	Grito = 3,
	Caza = 25,
	Andar = 6,
	Correr = 14,
	Huir = 26, -- velocidad al escapar del flash
	Pillar = 4.5,
	Vista = 60,
	VioEsconderse = 1.5,
}

-- Dificultad por número de jugadores (shared/Dificultad), pensada para 2 (pedido por el usuario). Se calcula al
-- empezar cada noche. AlaVez = {mínimo, máximo} ataques a la vez; Ritmo multiplica el tiempo entre ataques,
-- Paciencia lo que aguanta golpeando o raspando, Tareas lo que hay que hacer de día (aún sin usar). Números a ojo.
Config.Dificultad = {
	{ AlaVez = { 1, 1 }, Ritmo = 1.3, Paciencia = 1.25, Tareas = 0.75 },
	{ AlaVez = { 2, 2 }, Ritmo = 1, Paciencia = 1, Tareas = 1 },
	{ AlaVez = { 2, 3 }, Ritmo = 0.9, Paciencia = 1, Tareas = 1.25 },
	{ AlaVez = { 3, 3 }, Ritmo = 0.8, Paciencia = 0.85, Tareas = 1.25 },
}
Config.Separacion = { 12, 20 } -- segundos entre la llegada de un ataque y la del siguiente de la misma noche

-- Linterna con pilas (juego/servidor/Equipo): la F, o el botón en el móvil. Con poca pila parpadea.
Config.Linterna = {
	Duracion = 150, -- segundos encendida que dura una pila
	Poca = 0.2, -- con menos de esto parpadea
	Cambiar = 1.5, -- segundos cambiando la pila (las de repuesto son objetos de la mochila)
	Alcance = 55, -- studs que alumbra
	Angulo = 25, -- grados desde el centro en los que frena a un bicho
	Brillo = 4, -- de noche la exposición sube (Ambiente): con menos apenas se ve el círculo
}

-- Cámara con flash (juego/servidor/Equipo): clic, botón en el móvil o R2. Echa al Raspador; al resto lo aturde.
Config.Flash = {
	Fotos = 6, -- fotos por carrete (los de repuesto son objetos de la mochila)
	Recarga = 4, -- segundos entre flashazos
	Cambiar = 2,
	Alcance = 40,
	Angulo = 30,
	Aturde = 2, -- segundos que se queda quieto el bicho que no huye del flash
}

-- Lo que cabe en la mochila (shared/Rejilla, juego/servidor/Mochila). Tam = {ancho, alto} en casillas; Nombre, en
-- inglés para Lang. La clave es lo que se guarda: no renombrar las que existan, lo nuevo al final.
Config.Objetos = {
	Pila = { Tam = { 1, 1 }, Nombre = "Battery" },
	Carrete = { Tam = { 1, 1 }, Nombre = "Film" },
	Lata = { Tam = { 1, 1 }, Nombre = "Can" },
	Movil = { Tam = { 1, 1 }, Nombre = "Phone" },
	Llave = { Tam = { 1, 1 }, Nombre = "Key" },
	Botella = { Tam = { 1, 2 }, Nombre = "Bottle" },
	Linterna = { Tam = { 1, 2 }, Nombre = "Flashlight" }, -- sin ella en la mochila no hay luz
	Camara = { Tam = { 2, 2 }, Nombre = "Camera" }, -- sin ella no hay flash
	Hacha = { Tam = { 1, 3 }, Nombre = "Axe" },
}

-- Mochila de casillas (pedido por el usuario): B, botón en el móvil o la cruceta arriba en el mando; R gira y G tira.
-- Mientras está abierta no te mueves (el mundo sigue). Números a ojo.
Config.Mochila = {
	Ancho = 8,
	Alto = 6,
	Grande = { 10, 8 }, -- ampliada (pase de juego, más adelante)
	Inicio = { "Linterna", "Camara", "Pila", "Pila", "Carrete" }, -- lo que llevas al empezar
	Casilla = 0.42, -- studs que mide una casilla en el mundo (lo tirado)
}

-- Cosas pesadas que van en las manos con física y frenan (juego/servidor/Cargar). Tam en studs; Peso = cuántos hacen
-- falta para levantarla (el motor, entre dos: uno solo la arrastra). Números a ojo.
Config.Pesados = {
	Tronco = { Tam = { 6, 1.4, 1.4 }, Peso = 1 },
	Tablon = { Tam = { 6, 0.3, 1 }, Peso = 1 },
	Bidon = { Tam = { 1.6, 2.4, 1.6 }, Peso = 1 },
	Motor = { Tam = { 3.2, 2.2, 2.4 }, Peso = 2 },
}
Config.Cargar = {
	Frena = { 0.6, 0.5 }, -- multiplica tu velocidad según el Peso de lo que llevas (con todos los que hacen falta)
	Arrastrar = 0.25, -- velocidad arrastrando algo que necesita más gente
	Fuerza = 0.6, -- parte del peso que levanta cada uno: con 2 que la cogen, 1,2 veces el peso del motor
	Delante = 1.4, -- studs entre tu cuerpo y lo que llevas
	Suelta = 9, -- si se queda más lejos (atascada), se te cae
}

-- Modo de pruebas: solo actúa en Studio (shared/Prueba). Con él no se lee ni se guarda nada.
Config.Test = {
	Activo = true, -- en Studio: partida sin guardar y lo de abajo
	Monedas = 1e6, -- monedas al entrar; 0 = las de una partida nueva
	Lang = nil :: string?, -- "es" o "en" fuerza el idioma en Studio; nil = el del jugador
	Dia = 40, -- noche rápida: segundos de día y de noche en Studio (nil = los de Config.Ciclo)
	Noche = 150,
	Jugadores = nil :: number?, -- fuerza la fila de Config.Dificultad (nil = los que haya)
}

-- Sonidos. Provisionales de la biblioteca de Roblox para probar la tensión; se cambian por los de ElevenLabs.
Config.Sonidos = {
	Golpe = { Id = 9126254743, Volumen = 2, Alcance = 120 },
	Grieta = { Id = 9114588728, Volumen = 0.8, Alcance = 80 },
	Cristal = { Id = 543280386, Volumen = 1.5, Alcance = 120 },
	Rugido = { Id = 9113980319, Volumen = 1.5, Alcance = 150 },
	Paso = { Id = 9126253532, Volumen = 0.5, Alcance = 60 },
	Persiana = { Id = 9112889534, Volumen = 0.6, Alcance = 40 },
	Puerta = { Id = 9120829478, Volumen = 0.6, Alcance = 40 },
	Latido = { Id = 9043365842, Volumen = 0.7 },
	Susto = { Id = 9113985451, Volumen = 2 },
	Raspado = { Id = 9120078794, Volumen = 1.2, Alcance = 70 }, -- en bucle mientras raspa
	Chillido = { Id = 9125474863, Volumen = 1.6, Alcance = 150 }, -- el Raspador al recibir el flash
	Linterna = { Id = 9070807695, Volumen = 0.5 },
	Flash = { Id = 118206070547709, Volumen = 0.9, Alcance = 50 },
	-- Sin viento de fondo hasta tener uno de ElevenLabs: el de la biblioteca sonaba saturado (pedido por el usuario).
	-- Viento = { Id = ..., Volumen = 0.12 },
}

return Config
