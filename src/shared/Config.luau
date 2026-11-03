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

-- Monedas que se ganan (comun/servidor/Recompensas y Premio). Números a ojo.
Config.Recompensas = {
	Noche = 25, -- por superar la primera noche
	PorNoche = 5, -- más por cada noche siguiente
	TopeNoches = 10, -- a partir de la noche 11 ya no sube
	Final = 300, -- por escapar en el coche
	FinalBestia = 600, -- por matar a la Bestia (el final difícil)
	Diario = 50, -- premio diario
	Cada = 86400, -- segundos entre premios diarios
	-- Logros: se cobran una sola vez por jugador (se guarda el nombre: no renombrar). Noche = al superar esa noche.
	Logros = {
		Noche1 = { Noche = 1, Monedas = 50 },
		Noche5 = { Noche = 5, Monedas = 150 },
		Noche10 = { Noche = 10, Monedas = 400 },
		Huida = { Monedas = 250 },
		Bestia = { Monedas = 500 },
		Tutorial = { Monedas = 100 }, -- al acabar el tutorial (juego/servidor/Tutorial); también apunta que ya lo hizo
	},
}

-- Partidas (juego/servidor/Partida y comun/servidor/Viaje): la casa es del que la crea y se guarda al amanecer, con el
-- mismo candado que los jugadores (Config.Guardado). Números a ojo.
Config.Partida = {
	Almacen = "Partidas_v1", -- DataStore de las partidas; cambiarlo borra todas, no tocar con jugadores reales
	Viajes = "Viajes_v1", -- MemoryStore donde el lobby apunta quién va a cada servidor reservado
	Ranuras = 3, -- partidas por jugador
	EsperaDueno = 60, -- segundos esperando al dueño que se va (por si es un corte) antes de acabar para todos
	CaducaViaje = 86400, -- segundos que vive en MemoryStore lo apuntado de un viaje
	Sueltos = 400, -- como mucho, cosas sueltas guardadas de cada clase (objetos y pesados)
}

-- Coches del lobby (lobby/servidor/Coches): te subes con tus amigos, el primero que sube elige la partida y arranca.
Config.Coches = {
	Cuantos = 4,
	Plazas = 4,
	Salida = 7, -- segundos de cuenta atrás al arrancar (lo que dura la cinemática de salida, lobby/cliente/SalidaVista)
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
	MedioX = 39.5, -- la casa va de -MedioX a MedioX en x y de -MedioZ a MedioZ en z, paredes incluidas (Mapa)
	MedioZ = 33.5,
	-- Lo que sobresale y también es casa: { x1, x2, z1, z2 } de la torre, el mirador del comedor y el lavadero (Mapa).
	Anexos = { { 30.5, 47.5, -41.5, -24.5 }, { -43.5, -39, -17.5, -2.5 }, { -26.5, -11.5, 33, 45.5 } },
	TiempoPersiana = 1.4, -- lo que tarda en bajar o subir; a medio bajar no protege
	TiempoPuerta = 0.5,
	VidaPersiana = 100,
	VidaPuerta = 160,
	GolpesCristal = 3, -- golpes al cristal sin persiana hasta romperlo y entrar
	Alcance = 8, -- distancia para tocar las cosas (reparar: con un tablón, ver Config.Talar)
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

-- El Trepador (juego/servidor/Trepador): trepa por una pared, anda por el tejado (pasos y crujidos) y baja por la
-- chimenea. Se le echa encendiendo la chimenea con troncos (Config.Chimenea), también mientras baja. Números a ojo.
Config.Trepador = {
	Noche = 7, -- primera noche en la que sale; su primer ataque de esa noche es seguro
	Probabilidad = 0.3, -- desde entonces, de cada ataque, cuántos son suyos
	Tejado = { 24, 32 }, -- segundos rondando por el tejado antes de bajar por la chimenea
	MenosPorNoche = 1, -- cada noche baja antes...
	TejadoMin = 15, -- ...hasta este mínimo
	Subir = 3, -- segundos trepando por la pared
	Bajar = 4, -- segundos bajando por dentro de la chimenea (aún se le puede quemar)
	PorTejado = 7, -- velocidad por el tejado
	Grito = 3,
	Caza = 30,
	Andar = 8,
	Correr = 16,
	Huir = 24,
	Pillar = 4.5,
	Vista = 60,
	VioEsconderse = 1.5,
}

-- La chimenea del salón (juego/servidor/Chimenea): con un tronco en las manos, R lo echa al fuego. Números a ojo.
Config.Chimenea = {
	PorTronco = 50, -- segundos que arde cada tronco
	Max = 2, -- troncos ardiendo a la vez como mucho
	Echar = 1.2, -- segundos echándolo
}

-- El Imitador (juego/servidor/Imitador): llama a la puerta principal con la voz de un amigo. Hay que mirar en el móvil
-- si ese amigo está fuera de verdad: si se le abre, entra. La primera noche que sale se va la luz. Números a ojo.
Config.Imitador = {
	Noche = 10,
	Probabilidad = 0.25,
	Llamadas = 4, -- veces que llama antes de irse
	CadaLlamada = { 7, 10 }, -- segundos entre llamadas
	Oido = 80, -- studs desde la puerta a los que se le oye (los avisos solo les llegan a esos)
	Grito = 2.5,
	Caza = 30,
	Andar = 8,
	Correr = 18,
	Pillar = 4.5,
	Vista = 70,
	VioEsconderse = 1.5,
}

-- El Acechador (juego/servidor/Acechador): al anochecer, al que sigue en el bosque le sigue de lejos (ramas que
-- crujen) y luego se le echa encima. Se rinde si vuelves a la luz de la casa; la linterna lo frena un momento.
-- Números a ojo.
Config.Acechador = {
	Noche = 1, -- desde esta noche (y en los últimos segundos del día de antes: Config.Ciclo.Aviso)
	Refugio = 48, -- studs desde el centro de la casa: ahí ya hay luz y se rinde
	Espera = { 6, 12 }, -- segundos fuera hasta que empieza a seguirte
	Acecho = { 14, 20 }, -- segundos siguiéndote de lejos antes de echarse encima
	Lejos = 36, -- a cuánto te sigue mientras acecha
	Rama = { 2.5, 5 }, -- segundos entre ramas que crujen
	Andar = 18,
	Correr = 21, -- el jugador anda a 16
	Persigue = 22, -- segundos como mucho echándose encima; luego se cansa
	Frena = 2.5, -- segundos quieto al darle la linterna...
	Inmune = 2.5, -- ...y después, segundos en que no le vuelve a frenar
	Pillar = 5,
	Max = 2, -- como mucho, a la vez en el mapa
}

-- Dificultad por número de jugadores (shared/Dificultad), pensada para 2 (pedido por el usuario). Se calcula al
-- empezar cada noche. AlaVez = {mínimo, máximo} ataques a la vez; Ritmo multiplica el tiempo entre ataques,
-- Paciencia lo que aguanta golpeando o raspando, Tareas lo que hay que hacer de día (de momento, lo deprisa que gasta
-- gasolina el generador: Generador). Números a ojo.
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
	Llave = { Tam = { 1, 1 }, Nombre = "Key" }, -- sin usar: las de las salas cerradas van abajo
	Botella = { Tam = { 1, 2 }, Nombre = "Bottle" },
	Linterna = { Tam = { 1, 2 }, Nombre = "Flashlight" }, -- sin ella en la mochila no hay luz
	Camara = { Tam = { 2, 2 }, Nombre = "Camera" }, -- sin ella no hay flash
	Hacha = { Tam = { 1, 3 }, Nombre = "Axe" },
	-- Llaves de las salas cerradas (Config.Llaves): Llave = true.
	LlaveSotano = { Tam = { 1, 1 }, Nombre = "Basement key", Llave = true },
	LlaveGaraje = { Tam = { 1, 1 }, Nombre = "Garage key", Llave = true },
	LlaveDesvan = { Tam = { 1, 1 }, Nombre = "Attic key", Llave = true },
	LlaveRico = { Tam = { 1, 1 }, Nombre = "Master bedroom key", Llave = true },
	-- Taller y coche (Config.Taller, Config.Coche).
	Chatarra = { Tam = { 2, 1 }, Nombre = "Scrap metal" }, -- por los sitios del mapa; se gasta en los bancos
	Trampa = { Tam = { 2, 2 }, Nombre = "Trap" }, -- tirada al suelo, aturde al bicho que pasa encima
	Bateria = { Tam = { 2, 1 }, Nombre = "Car battery" },
	Radiador = { Tam = { 2, 2 }, Nombre = "Radiator" },
	-- Final de la Bestia (Config.Bestia, 12.2).
	Cadena = { Tam = { 2, 1 }, Nombre = "Chain" }, -- para la reja del sótano
	Pistola = { Tam = { 2, 1 }, Nombre = "Flare gun" }, -- la del rico, en el desván
	Bengala = { Tam = { 1, 1 }, Nombre = "Flare" }, -- cada disparo gasta una
	Cerillas = { Tam = { 1, 1 }, Nombre = "Matches" }, -- para prender el rastro de gasolina
}

-- Salas cerradas con llave (pedido por el usuario), de más cerca a más lejos (juego/servidor/Llaves). Cada llave sale
-- con la semilla de la partida en uno de los sitios de su zona (Lugares). No reordenar: el orden cambia el sitio.
Config.Llaves = {
	{ Sala = "Sotano", Llave = "LlaveSotano", Zona = "Granja" },
	{ Sala = "Garaje", Llave = "LlaveGaraje", Zona = "Aserradero" },
	{ Sala = "Desvan", Llave = "LlaveDesvan", Zona = "Torre" },
	{ Sala = "HabitacionDelRico", Llave = "LlaveRico", Zona = "Cementerio" },
}
Config.BrilloLlave = { Brillo = 0.7, Alcance = 7 } -- brillo flojo para verla de lejos (pedido por el usuario)

-- Vendedor del pueblo (juego/servidor/Vendedor): trueque, pide comida y agua (pedido por el usuario). Da = lo que te
-- da, Pide = lo que quiere; { tipo, cuántos }. Números a ojo.
Config.Vendedor = {
	Trueques = {
		{ Da = { "Pila", 2 }, Pide = { "Lata", 1 } },
		{ Da = { "Carrete", 1 }, Pide = { "Botella", 1 } },
		{ Da = { "Linterna", 1 }, Pide = { "Lata", 2 } },
		{ Da = { "Hacha", 1 }, Pide = { "Botella", 2 } },
		{ Da = { "Chatarra", 2 }, Pide = { "Lata", 1 } },
	},
	Alcance = 12, -- studs: más lejos se cierra el trato
	Frases = { -- lo que dice al hablarle (pedido por el usuario: avisa)
		"Don't go out at night.",
		"Don't stay in the rich man's house.",
		"Food and water. That's all I take.",
		"Everyone else left. Or didn't.",
	},
}

-- Mochila de casillas (pedido por el usuario): B, botón en el móvil o la cruceta arriba en el mando; R gira y G tira.
-- Mientras está abierta no te mueves (el mundo sigue). Números a ojo.
Config.Mochila = {
	Ancho = 8,
	Alto = 6,
	Grande = { 10, 8 }, -- ampliada (pase MochilaGrande, Stats.mochila)
	Inicio = { "Linterna", "Camara", "Movil", "Pila", "Pila", "Carrete" }, -- lo que llevas al empezar
	Casilla = 0.42, -- studs que mide una casilla en el mundo (lo tirado)
}

-- Cosas pesadas que van en las manos con física y frenan (juego/servidor/Cargar). Tam en studs; Peso = cuántos hacen
-- falta para levantarla (el motor, entre dos: uno solo la arrastra). Nombre, en inglés para Lang. La clave se guarda.
-- Números a ojo.
Config.Pesados = {
	Tronco = { Tam = { 6, 1.4, 1.4 }, Peso = 1, Nombre = "Log" },
	Tablon = { Tam = { 6, 0.3, 1 }, Peso = 1, Nombre = "Plank" },
	Bidon = { Tam = { 1.6, 2.4, 1.6 }, Peso = 1, Nombre = "Fuel can" },
	Motor = { Tam = { 3.2, 2.2, 2.4 }, Peso = 2, Nombre = "Engine" },
	Rueda = { Tam = { 1, 2.6, 2.6 }, Peso = 1, Nombre = "Wheel" }, -- cilindro: el eje va a lo largo de X
	TablonReforzado = { Tam = { 6, 0.45, 1 }, Peso = 1, Nombre = "Reinforced plank" },
	Reja = { Tam = { 6, 6, 0.5 }, Peso = 2, Nombre = "Iron gate" }, -- sale del banco del sótano; se monta al pie de la escalera
}
Config.Cargar = {
	Frena = { 0.6, 0.5 }, -- multiplica tu velocidad según el Peso de lo que llevas (con todos los que hacen falta)
	Arrastrar = 0.25, -- velocidad arrastrando algo que necesita más gente
	Fuerza = 0.6, -- parte del peso que levanta cada uno: con 2 que la cogen, 1,2 veces el peso del motor
	Delante = 1.4, -- studs entre tu cuerpo y lo que llevas
	Suelta = 9, -- si se queda más lejos (atascada), se te cae
}

-- Talar, serrar y clavar (juego/servidor/Recursos y Casa): árbol -> troncos -> (caballete) tablones -> reparar una
-- persiana o una puerta. Solo se talan los árboles finos de cerca de la casa. Números a ojo.
Config.Talar = {
	Arboles = 45, -- árboles que se pueden talar
	Golpes = { 5, 7 }, -- hachazos hasta que cae
	Cada = 0.65, -- segundos entre hachazos
	Troncos = 2, -- troncos que salen de un árbol
	Serrar = 3, -- segundos serrando un tronco en el caballete
	Tablones = 2, -- tablones que salen de un tronco
	Clavar = 3.5, -- segundos clavando un tablón: deja la persiana (y el cristal) o la puerta como nuevas
	Rebrota = 2, -- noches hasta que un árbol talado vuelve a crecer
}

-- Generador del cobertizo (juego/servidor/Generador): sin gasolina no hay luz en la casa ni enchufe. Se arranca tirando
-- de la cuerda y se llena con el bidón. Con más jugadores gasta más (Config.Dificultad, Tareas). Números a ojo.
Config.Generador = {
	Deposito = 480, -- segundos encendido con el depósito lleno (una noche son 240)
	Inicio = 0.3, -- parte del depósito llena al empezar la partida
	PorBidon = 0.5, -- parte del depósito que llena un bidón lleno
	Verter = 3, -- segundos echando gasolina
	Arranca = 0.4, -- probabilidad de arrancar con cada tirón; al tercero seguido arranca seguro
	Tiron = 1.1, -- segundos entre tirones
}

-- Bancos del taller (juego/servidor/Taller, cliente TallerUi): el del sótano (carpintería) y el del garaje (piezas
-- del coche). Pide = lo que gasta, { tipo, cuántos }: objetos de la mochila o cosas pesadas dejadas junto al banco (a
-- Radio studs). Da = lo que sale (a la mochila o, si es pesado, junto al banco). Números a ojo.
Config.Taller = {
	Radio = 10,
	Bancos = {
		Sotano = {
			{ Da = "TablonReforzado", Pide = { { "Tablon", 2 }, { "Chatarra", 1 } }, Tiempo = 5 },
			{ Da = "Trampa", Pide = { { "Chatarra", 2 }, { "Tablon", 1 } }, Tiempo = 5 },
		},
		Garaje = {
			{ Da = "Radiador", Pide = { { "Chatarra", 3 }, { "Botella", 1 } }, Tiempo = 6 },
			{ Da = "Bateria", Pide = { { "Pila", 4 }, { "Chatarra", 1 } }, Tiempo = 6 },
		},
	},
	Refuerzo = 1.75, -- el tablón reforzado multiplica la vida de la persiana o la puerta hasta que la rompan
	Trampa = { Aturde = 6, Radio = 3.5 }, -- segundos quieto el bicho que la pisa, y a cuánto salta
}

-- Tu coche (juego/servidor/Coche): destrozado y encerrado en el garaje. Se arregla con estas piezas y un depósito de
-- gasolina (Gasolina = bidones llenos que hacen falta) y se huye en él: el final fácil. Las piezas pesadas se montan
-- con R, las de la mochila con E en el capó. No reordenar Piezas: la clave se guarda. Números a ojo.
Config.Coche = {
	Piezas = { { "Motor", 1 }, { "Rueda", 2 }, { "Bateria", 1 }, { "Radiador", 1 } },
	Gasolina = 1,
	Montar = 4, -- segundos montando una pieza
	Huir = 2, -- segundos manteniendo la E para huir
	Cinematica = 17, -- segundos de la escena final
}

-- Móvil (juego/servidor/Movil, cliente MovilUi): mapa con dónde estáis tú y tus amigos (pedido por el usuario). Gasta
-- batería mientras se mira y se carga en el enchufe de la casa con el generador encendido. Números a ojo.
-- El final difícil (12.2, TASKS.md): preparar la casa de día, "Esperarla", herirla con bengalas, encerrarla en el
-- sótano con la reja y quemar la casa desde el porche. Módulos: Preparativos (gasolina, reja, palanca, trampilla,
-- guardado), Bestia (el bicho), Bengalas (la pistola) e Incendio (el fuego, la escena y el premio). Números a ojo.
Config.Bestia = {
	-- Preparativos
	Puntos = 6, -- puntos de gasolina en la casa (salón, cocina, pasillo, escalera, los dos dormitorios)
	Verter = 3, -- segundos echando un bidón en un punto
	PorPunto = 1 / 3, -- parte de un bidón que gasta cada punto (hay pocos bidones y no se rellenan)
	-- Receta en el banco del sótano; solo sale tras leer la pista Pista (shared/Historia)
	Reja = { Pide = { { "Chatarra", 4 }, { "Cadena", 2 } }, Tiempo = 8, Pista = 9 },
	Montar = 4, -- segundos montando la reja en su marco
	Caer = 0.35, -- segundos que tarda la reja en caer
	Palanca = 1.5, -- segundos tirando de la palanca
	-- La Bestia
	Altura = 4.5, -- de los pies al centro de la raíz
	Andar = 10,
	Correr = 19, -- el jugador anda a 16: más rápida que él
	Cojear = 7, -- velocidad mientras cojea
	Cojea = 8, -- segundos cojeando tras una bengala
	Pillar = 5, -- studs a los que te pilla
	Vista = 90,
	Olfato = 25, -- studs: sin verle, huele a quien no está escondido en su planta (para que te siga al sótano)
	Parada = 2, -- segundos sin avanzar para cambiar de destino
	AltoCamino = 7, -- alto con el que calcula los caminos: con 8 no cabía por la escalera del sótano
	Espera = 6, -- segundos desde "Esperarla" hasta que llega
	VioEsconderse = 3, -- segundos en que aún te saca del escondite si te vio meterte (más lista que los demás)
	Borde = 70, -- studs de la puerta principal al sitio del bosque por donde sale
	Rugido = 2.5, -- segundos rugiendo al salir del bosque
	Quema = 4, -- segundos chillando en el fuego hasta desaparecer
	Sobresalto = 0.6, -- segundos quieta al darle una bengala
	CercaReja = 45, -- atrapada: va hacia quien ve fuera a menos de esto
	CadaGolpe = 1.3, -- atrapada: segundos entre golpes a la reja
	OlfatoSotano = 40, -- studs: arriba de la escalera del sótano o dentro, a quien esté abajo (para poder meterla)
	OlfatoReciente = 6, -- segundos tras verle en que aún le huele en la otra planta (le ha visto subir o salir)
	OlfatoAlto = 16, -- studs de alto a los que huele entonces (si no, 8: su planta)
	Aranar = 8, -- segundos arañando bajo la trampilla cuando alguien se le escapa por ella (da tiempo a subir y tirar)
	SinTrampilla = 15, -- segundos después en que ya no vuelve a la trampilla (busca por la escalera)
	CercaTrampilla = 16, -- studs: si a quien busca está arriba a menos de esto del hueco, se ha ido por la trampilla
	-- Bengalas
	Bengalas = 3, -- las que trae la pistola
	Alcance = 120, -- studs del disparo
	Recarga = 1.5, -- segundos entre disparos
	CercaCabeza = 6, -- studs: el origen del disparo que manda el cliente no puede estar más lejos de su cabeza
	Vuela = 160, -- studs/s que vuela la bola (solo se ve)
	Arde = 9, -- segundos ardiendo donde da
	Brillo = 2.2, -- luz de la bengala: fuerte sin pasarse (pedido por el usuario: nada de brillos exagerados)
	Luz = 22, -- alcance de esa luz
	-- Incendio
	Prender = 2, -- segundos con la cerilla en el rastro
	PorSala = 1.6, -- segundos que tarda el fuego en pasar de un punto al siguiente
	Chillido = 1.5, -- segundos entre que ella se quema y la escena final
	ArdeCasa = 5, -- segundos con la casa entera ardiendo (y su chillido dentro) antes de la escena final
	Cinematica = 20, -- segundos de la escena final
}
Config.Insignias = { Bestia = 0 } -- Id de la insignia (BadgeService) al publicar (13.2); 0 = no se da

-- Postura en la partida (14.6, pedido por el usuario: "agacharse (botón también en el móvil) y asomarse por las
-- esquinas"). Solo cuerpo y cámara: los bichos no lo notan. Números a ojo.
Config.Postura = {
	Velocidad = 0.5, -- agachado se anda a la mitad
	Baja = 1.7, -- studs que baja la cámara al agacharse
	Asomar = 1.3, -- studs que se mueve la cabeza de lado al asomarte
	Giro = 14, -- grados que se ladea al asomarte
	Cada = 0.15, -- segundos como mínimo entre dos cambios (servidor)
}

Config.Movil = {
	Duracion = 150, -- segundos mirándolo con la batería llena
	Carga = 60, -- segundos en el enchufe hasta llenarse
	Radio = 90, -- studs de mundo que se ven del centro al borde (de lado) de la pantalla
}

-- Modo de pruebas: solo actúa en Studio (shared/Prueba). Con él no se lee ni se guarda nada.
Config.Test = {
	Activo = true, -- en Studio: partida sin guardar y lo de abajo
	Monedas = 1e6, -- monedas al entrar; 0 = las de una partida nueva
	Lang = nil :: string?, -- "es" o "en" fuerza el idioma en Studio; nil = el del jugador
	Dia = 40, -- noche rápida: segundos de día y de noche en Studio (nil = los de Config.Ciclo)
	Noche = 150,
	Jugadores = nil :: number?, -- fuerza la fila de Config.Dificultad (nil = los que haya)
	-- El teletransporte no funciona en Studio: el lugar Juego arranca con este dueño falso (la partida se guarda en un
	-- almacén de mentira que dura lo que la prueba).
	Dueno = nil :: number?, -- UserId del dueño (nil = el primero que entra)
	Clase = nil :: string?, -- Id de una clase de Config.Clases para probar su ventaja (nil = la elegida en el lobby)
	Pases = false, -- true = todos los pases de Config.Compras (sin pagar)
	Ranura = 1,
	Nueva = false, -- true = empezar de cero aunque haya algo guardado
	Partidas = { ["1"] = { noche = 4, hora = 0 } }, -- lo que el lobby enseña como ya guardado (las ranuras)
	Tutorial = false, -- true = sale el tutorial en Studio (los datos de prueba nunca lo tienen hecho)
}

-- Tutorial de los primeros minutos (juego/servidor/Tutorial y cliente/TutorialVista, 14.2). Sale una vez por cuenta,
-- hasta acabarlo o saltarlo; el premio es el logro Tutorial de Config.Recompensas. Pasos en shared/PasosTutorial.
Config.Tutorial = {
	Activo = true,
	Cada = 0.5, -- segundos entre dos miradas del servidor
	Flecha = 4, -- studs por encima de lo que señala la flecha
}

-- Sonidos (juego/cliente/Sonido): de ElevenLabs, elegidos por el usuario de oído (tools/sonidos, docs/sistemas/sonidos.md).
-- Id = uno o una lista (suenan alternados). Volumen ya compensado: casi todos salen a tope; los flojos van subidos
-- (1 / su pico). Alcance = studs hasta los que se oye desde donde pasa. Los dos que aún son de la biblioteca de
-- Roblox están marcados.
Config.Sonidos = {
	Golpe = { Id = 90763366072682, Volumen = 3, Alcance = 120 },
	Grieta = { Id = 100084710095294, Volumen = 0.8, Alcance = 80 },
	Cristal = { Id = { 109453489344482, 97637753283588, 128730961489069 }, Volumen = 1.3, Alcance = 120 },
	Rugido = { Id = 127253467505898, Volumen = 1.5, Alcance = 150 },
	Paso = { Id = 136017086076556, Volumen = 0.6, Alcance = 60 }, -- de los bichos
	Cortina = { Id = 79954556495838, Volumen = 0.6, Alcance = 40 }, -- al abrirla
	CortinaCierra = { Id = 116375610138100, Volumen = 0.6, Alcance = 40 },
	Tiron = { Id = 9112889534, Volumen = 0.6, Alcance = 40 }, -- la cuerda del generador (biblioteca, sin cambiar)
	Puerta = { Id = 126413574108197, Volumen = 0.6, Alcance = 40 }, -- al abrirse
	PuertaCierra = { Id = 77366400653400, Volumen = 0.6, Alcance = 40 },
	Latido = { Id = 114745522513692, Volumen = 0.8 },
	Susto = { Id = 76385773029835, Volumen = 1.8 },
	Raspado = { Id = 73284823449392, Volumen = 1.8, Alcance = 70 }, -- en bucle mientras raspa
	Chillido = { Id = 81928223946678, Volumen = 1.5, Alcance = 150 }, -- el Raspador al recibir el flash
	Linterna = { Id = 83923860147180, Volumen = 0.5 }, -- al encenderla
	LinternaApaga = { Id = 125142713337345, Volumen = 0.5 },
	Flash = { Id = 132658894276493, Volumen = 0.9, Alcance = 50 }, -- de YouTube, libre de derechos (elegido por el usuario)
	Hachazo = { Id = 100140958893599, Volumen = 1.2, Alcance = 90 },
	Caida = { Id = 90088146547108, Volumen = 2, Alcance = 150 }, -- el árbol al dar contra el suelo
	Serrar = { Id = 127179113277901, Volumen = 0.8, Alcance = 50 }, -- en bucle
	Martillo = { Id = 97902434243999, Volumen = 1, Alcance = 60 },
	Motor = { Id = 118749656286088, Volumen = 0.5, Alcance = 70 }, -- el generador encendido, en bucle
	Verter = { Id = 73665182403100, Volumen = 1, Alcance = 30 },
	Crujido = { Id = 101323772432262, Volumen = 1.4, Alcance = 80 }, -- madera del tejado bajo el Trepador
	Hollin = { Id = 133574014508797, Volumen = 1.6, Alcance = 90 }, -- algo arrastrándose dentro de la chimenea
	Fuego = { Id = 120345409600923, Volumen = 1.2, Alcance = 40 }, -- la chimenea encendida, en bucle
	Llamar = { Id = 85091064305699, Volumen = 1.2, Alcance = 90 }, -- el Imitador en la puerta
	Rama = { Id = 130950746994310, Volumen = 1.8, Alcance = 90 }, -- el Acechador en el bosque
	Cruje = { Id = 90016245337834, Volumen = 0.9, Alcance = 50 }, -- la casa cruje sola de noche (Ambiente)
	-- Tus pasos según el suelo (juego/cliente/Pasos).
	PasoMadera = { Id = 120688859292249, Volumen = 0.35, Alcance = 40 },
	PasoTierra = { Id = 134774038857358, Volumen = 0.6, Alcance = 40 },
	PasoHierba = { Id = 139972541989405, Volumen = 2, Alcance = 40 },
	-- Fondo del bosque en bucle: solo viento y hojas, compuesto con tools/sonidos/componer.mjs y bosque.json. Sube de
	-- noche (Ambiente). Lo demás suena suelto y al azar desde algún sitio del bosque (pedido por el usuario: que no se
	-- oiga siempre lo mismo).
	Viento = { Id = 135916874292391, Volumen = 0.6 },
	Lobo = { Id = { 94567506276238, 123890651978034 }, Volumen = 1.2, Alcance = 400 },
	Buho = { Id = { 128579231147340, 99006707518885 }, Volumen = 0.9, Alcance = 250 },
	Ramita = { Id = { 81824412925307, 91333969182246 }, Volumen = 3, Alcance = 150 },
	Grillo = { Id = { 106921997334500, 94261260619240 }, Volumen = 0.8, Alcance = 120 },
	-- Detalles vivos de la casa (juego/cliente/DetallesVista y ChimeneaVista, 11.9). Elegidos por el usuario; los dos de
	-- la bombilla, de YouTube (pedido por el usuario: los de ElevenLabs salían saturados).
	Tic = { Id = 125137723416876, Volumen = 0.6, Alcance = 30 }, -- el reloj de pie del vestíbulo
	Campanada = { Id = 140173958642561, Volumen = 1.2, Alcance = 160 },
	Nevera = { Id = 105328731081136, Volumen = 1.2, Alcance = 22 }, -- zumbido en bucle con el generador encendido
	NeveraClac = { Id = 113816743112992, Volumen = 0.8, Alcance = 30 },
	Gota = { Id = 135808961631299, Volumen = 1.2, Alcance = 22 },
	Tuberia = { Id = 84822903759176, Volumen = 1.6, Alcance = 60 },
	VientoTiro = { Id = 108230513932897, Volumen = 1.3, Alcance = 50 }, -- el viento por el tiro de la chimenea
	Parpadeo = { Id = 115400138567928, Volumen = 0.7, Alcance = 40 }, -- "Efecto de Sonido - Foco Luz Rota" (YouTube)
	Zumbido = { Id = 129528625281695, Volumen = 0.35, Alcance = 22 }, -- "Bombilla de Luz Defectuosa" (YouTube, sin copyright)
	-- Más miedo (14.3, tanda miedo). Latas, PuertaGolpe, CuadroCae, PasosArriba, Papel, Tension y CasaFondo: la versión
	-- que recomendó Claude, falta que elija el usuario. Los demás, PROVISIONALES con ids de otros sonidos: sin créditos
	-- de ElevenLabs hasta la recarga (~08-11-2026).
	Latas = { Id = 84516470881879, Volumen = 1.45, Alcance = 120 }, -- latas colgadas que tintinean al pasar algo
	PuertaGolpe = { Id = 112896966864592, Volumen = 1.5, Alcance = 90 }, -- un portazo en otra sala (susto)
	CuadroCae = { Id = 77766212438473, Volumen = 0.97, Alcance = 50 }, -- un cuadro que se cae de la pared (susto)
	PasosArriba = { Id = 74222410792500, Volumen = 0.9, Alcance = 60 }, -- pasos en el piso de arriba sin nadie (susto)
	Susurro = { Id = 76385773029835, Volumen = 0.5 }, -- un susurro al oído, sin posición (susto)
	Toc = { Id = 85091064305699, Volumen = 0.8, Alcance = 40 }, -- unos golpecitos en el cristal (susto)
	Aranazo = { Id = 73284823449392, Volumen = 1, Alcance = 40 }, -- algo araña dentro de la pared (susto)
	Sobresalto = { Id = 76385773029835, Volumen = 1.2 }, -- golpe de tensión al ver algo (susto)
	Polvo = { Id = 133574014508797, Volumen = 0.6, Alcance = 30 }, -- polvo y arenilla que caen del techo
	CristalVibra = { Id = 100084710095294, Volumen = 0.6, Alcance = 30 }, -- el cristal traquetea en el marco
	Retumbo = { Id = 90763366072682, Volumen = 0.8, Alcance = 80 }, -- retumbo grave de algo pesado cerca
	Tension = { Id = 128655385492630, Volumen = 0.44 }, -- zumbido grave de tensión, en bucle (Ambiente)
	CasaFondo = { Id = 78347978132756, Volumen = 0.38 }, -- fondo de dentro de la casa de noche, en bucle (Ambiente)
	Rafaga = { Id = 108230513932897, Volumen = 0.8, Alcance = 60 }, -- ráfaga de viento contra una ventana (Ambiente)
	Papel = { Id = { 102356296355745, 123486080921232, 140510968287147 }, Volumen = 0.75 }, -- papel al coger o leer una pista
	-- Inmersión (14.6, docs/sistemas/manos.md): FALTAN, para hacer con ElevenLabs. Con Id = 0 no suenan (Sonido.hay).
	Respiracion = { Id = 0, Volumen = 0.5 }, -- respiración nerviosa en bucle, escondido
	Contener = { Id = 0, Volumen = 0.6 }, -- coger aire de golpe y aguantarlo (escondido, con un bicho cerca)
	Exhalar = { Id = 0, Volumen = 0.6 }, -- soltar el aire temblando cuando se va
	Mirilla = { Id = 0, Volumen = 0.5, Alcance = 12 }, -- la tapita de metal de la mirilla al apartarla
}

-- Detalles vivos de la casa (juego/cliente/DetallesVista, 11.9, pedido por el usuario). Segundos; números a ojo.
-- Posiciones como { x, y, z } (sin Vector3: Lune lee Config).
Config.Detalles = {
	Cerca = 45, -- más lejos de la cámara no se anima ni suena nada
	Reloj = { 10, 1, 8.5 }, -- el reloj de pie que anda (el del vestíbulo); los otros están parados
	Campanadas = { 0, 1, 2, 3 }, -- horas de la noche a las que da campanadas (a las 0, doce)
	Nevera = { Encendida = { 40, 70 }, Parada = { 15, 30 } },
	Grifos = { -- x, y, z de donde sale la gota y la altura del fondo de la pila
		{ -26.45, 4.72, 31.4, 3.75 }, -- fregadero de la cocina
		{ 20.45, 4.45, 31, 4.03 }, -- lavabo del baño
	},
	Gota = { 1.5, 4 },
	BombillaMala = { 0, 8, 28.5 }, -- la del pasillo: zumba y parpadea más a menudo
	ParpadeoMala = { 5, 12 },
	ParpadeoOtras = { 25, 60 }, -- alguna otra bombilla cerca de la cámara
	Tuberias = { { 14, 4, 32 }, { -30, 3, 33 }, { -6, 3, 26 } }, -- dentro de las paredes
	Tuberia = { 40, 90 }, -- solo de noche y con la cámara dentro de la casa
	VientoTiro = { 25, 60 }, -- de noche, con la chimenea apagada
	Rescoldo = 90, -- lo que tardan las brasas en enfriarse después de apagarse el fuego
}

-- Ventajas de los jugadores (shared/Stats): lo de quien no tiene clase. Cada una se usa en un solo sistema.
Config.Ventajas = {
	Velocidad = 1, -- multiplica la velocidad al andar (Cargar)
	Hachazo = 1, -- golpes que cuenta cada hachazo (Recursos)
	Troncos = 0, -- troncos de más del árbol que tala (Recursos)
	Recarga = 1, -- multiplica los segundos entre flashazos (Equipo)
	Aturde = 1, -- multiplica los segundos que aturde el flash (Equipo)
	Trabajo = 1, -- multiplica los segundos de clavar tablones y montar piezas (Cargar)
	Refuerzo = 1, -- multiplica la vida de más del tablón reforzado que clava (Casa)
	VerLlaves = 0, -- studs a los que ve las llaves a través de todo, solo él (ClaseVista)
	-- Las de los pases (Config.Compras.Pases); ninguna clase las toca.
	Pila = 1, -- multiplica lo que dura la pila de la linterna (Equipo)
	Luz = 1, -- multiplica el alcance de la linterna: lo que frena a un bicho (Equipo) y lo que se ve (EquipoVista)
}

-- Clases (comun/servidor/Clases): una por jugador y partida. Se guarda el Id: no cambiarlo nunca y las nuevas al
-- final. Ventajas = lo que cambia de Config.Ventajas. Texto = una línea para la tienda. Precio en monedas (la primera
-- que compra cada jugador es gratis; una partida de unas 5 noches da unas 375). Números a ojo.
Config.Clases = {
	{ Id = "Lenador", Nombre = "Lumberjack", Texto = "Chops trees faster and gets more logs.", Precio = 400,
		Ventajas = { Hachazo = 1.5, Troncos = 1 } },
	{ Id = "Corredor", Nombre = "Runner", Texto = "Runs faster.", Precio = 400, Ventajas = { Velocidad = 1.2 } },
	{ Id = "Fotografo", Nombre = "Photographer", Texto = "The flash recharges sooner and stuns for longer.", Precio = 400,
		Ventajas = { Recarga = 0.6, Aturde = 1.5 } },
	{ Id = "Mecanico", Nombre = "Mechanic", Texto = "Nails boards and fixes the car faster.", Precio = 400,
		Ventajas = { Trabajo = 0.6 } },
	{ Id = "Carpintero", Nombre = "Carpenter", Texto = "Reinforced boards hold much longer.", Precio = 400,
		Ventajas = { Refuerzo = 1.5 } },
	{ Id = "Explorador", Nombre = "Explorer", Texto = "Sees nearby keys through walls.", Precio = 400,
		Ventajas = { VerLlaves = 70 } },
}

-- Cosméticos sin ventaja (lobby/servidor/Tienda). Se guarda el Id: no cambiarlo nunca y los nuevos al final. Tipo =
-- dónde se pone (uno de cada tipo a la vez). Linterna: el color de la luz en RGB (juego/cliente/EquipoVista; sin Color3, para que Lune lo cargue); la de serie es
-- la cálida. Colores flojos, nada de neón. Precios a ojo.
Config.Cosmeticos = {
	{ Id = "LuzFria", Tipo = "Linterna", Nombre = "Cold light", Color = { 205, 222, 255 }, Precio = 150 },
	{ Id = "LuzAmbar", Tipo = "Linterna", Nombre = "Amber light", Color = { 255, 190, 110 }, Precio = 150 },
	{ Id = "LuzRoja", Tipo = "Linterna", Nombre = "Red light", Color = { 255, 110, 95 }, Precio = 250 },
	{ Id = "LuzVerde", Tipo = "Linterna", Nombre = "Green light", Color = { 160, 240, 150 }, Precio = 250 },
	{ Id = "LuzMorada", Tipo = "Linterna", Nombre = "Violet light", Color = { 185, 155, 255 }, Precio = 400 },
}

-- Compras con Robux (comun/servidor/Compras). Id = el de Roblox (0 = aún sin crear: no se puede comprar; en Studio
-- con el modo de pruebas se hace como si se pagara). Robux = el precio que hay que ponerle al crearlo en el Creator
-- Hub (aquí solo se enseña). Los pases se piden por su Ventaja (Stats.pase), nunca por el pase concreto: la clave se
-- guarda en `regalos`, no cambiarla. Números a ojo.
Config.Compras = {
	Recordadas = 100, -- compras entregadas que recuerda cada jugador (para no dar la misma dos veces)
	Revivir = { Id = 0, Robux = 25 }, -- de noche, a ti o a otro muerto; una vez por noche cada uno (juego/servidor/Revivir)
	Reembolso = 150, -- monedas si un revivir pagado ya no se puede hacer (ha amanecido, ya ha revivido…)
	Monedas = {
		{ Id = 0, Robux = 49, Monedas = 300 },
		{ Id = 0, Robux = 129, Monedas = 900 },
		{ Id = 0, Robux = 299, Monedas = 2400 },
	},
	Pases = {
		{ Ventaja = "MochilaGrande", Id = 0, Robux = 199, Nombre = "Big backpack",
			Texto = "A bigger backpack: more room for everything." }, -- Config.Mochila.Grande
		{ Ventaja = "MasRanuras", Id = 0, Robux = 99, Nombre = "More saves", Texto = "Six saved games instead of three.",
			Ranuras = 6 },
		{ Ventaja = "LinternaMejor", Id = 0, Robux = 149, Nombre = "Better flashlight",
			Texto = "Batteries last longer and the light reaches farther.", Ventajas = { Pila = 1.5, Luz = 1.25 } },
		-- Lo de Regalo se da una sola vez (al confirmar el pase): monedas y cosméticos de Config.Cosmeticos.
		{ Ventaja = "PaqueteInicio", Id = 0, Robux = 99, Nombre = "Starter pack", Texto = "1000 coins and the violet light.",
			Regalo = { Monedas = 1000, Cosmeticos = { "LuzMorada" } } },
	},
}

-- Trampas de latas fuera de la casa (juego/servidor/Latas, 14.3). Números a ojo. Lineas: { x1, z1, x2, z2 }; no reordenar (el cliente siembra las latas con el número).
Config.Latas = {
	Cada = 0.2, -- segundos entre dos miradas
	Radio = 2.5, -- studs de la cuerda (en planta) a los que algo la hace sonar
	Espera = 4, -- segundos entre dos avisos de bicho de la misma línea
	EsperaJugador = 2.5, -- lo mismo para los jugadores
	FuerzaBicho = { 0.75, 1 }, -- andando ... corriendo (a CFG.Rapido studs/s o más)
	FuerzaJugador = { 0.25, 0.45 },
	Rapido = 20, -- studs/s a los que ya suena con la fuerza máxima
	Salto = 40, -- studs en una mirada: más es que lo han movido de golpe (PivotTo), no que haya cruzado
	Alto = 4.8, -- studs del suelo al nudo de la cuerda en la estaca
	Comba = 0.7, -- lo que cuelga la cuerda en el medio
	-- Las líneas { x1, z1, x2, z2 } (en planta, a ras de suelo). No reordenar: el cliente siembra las latas con el número.
	Lineas = {
		{ -40, -77, -12, -81 }, -- delante, a la izquierda de la carretera (comedor y puerta)
		{ 12, -81, 42, -76 }, -- delante, a la derecha (salón y puerta)
		{ 54, -71, 78, -49 }, -- la esquina de la torre (su ventana mira al sureste)
		{ 80, -20, 82, 8 }, -- este, hacia delante
		{ 81, 14, 78, 42 }, -- este, hacia atrás (ventana del dormitorio)
		{ 72, 54, 52, 74 }, -- esquina de atrás a la derecha
		{ 42, 79, 12, 81 }, -- detrás, a la derecha (dormitorio de abajo)
		{ -16, 81, -48, 78 }, -- detrás, a la izquierda (cocina)
		{ -58, 74, -76, 56 }, -- esquina de atrás a la izquierda (detrás del cobertizo)
		{ -78, 48, -76, 20 }, -- oeste, hacia atrás (lavadero)
		{ -79, 10, -77, -24 }, -- oeste, hacia delante (mirador del comedor)
		{ -70, -44, -48, -70 }, -- esquina de delante a la izquierda (fuera del camino del coche)
		{ -10, -84, 10, -84 }, -- por encima de la carretera, entre dos postes altos: la puerta principal (Imitador, Bestia)
	},
	-- Líneas distintas: [n] = { Alto, Comba, SoloBichos }. La de la carretera, alta para que el coche pase por debajo al
	-- huir; los jugadores también pasan por debajo (no la tocan), los bichos no.
	Especiales = {
		[13] = { Alto = 9.5, Comba = 0.45, SoloBichos = true },
	} :: { [number]: { Alto: number, Comba: number, SoloBichos: boolean } },
}

-- Cómo se mueven y suenan las latas (juego/cliente/LatasVista, 14.3). A ojo.
Config.LatasVista = {
	Cerca = 120, -- studs: más lejos no se anima nada
	CercaViento = 60, -- studs: el vaivén del viento solo a esta distancia
	Gravedad = 35, -- studs/s² "de verdad" (1 stud ~ 0,28 m): péndulos lentos como los de una lata real
	Frena = 0.6, -- amortiguado del balanceo (por segundo)
	Viento = 0.07, -- radianes de vaivén con viento
	Golpe = 5, -- velocidad de giro (rad/s) que da un bicho a la lata que tiene al lado
	Onda = 0.35, -- studs que vibra la cuerda con fuerza 1
	Volumen = { 0.35, 1 }, -- parte del volumen del sonido con fuerza 0 ... 1
	Lejos = { 10, 28 }, -- RollOffMinDistance con fuerza 0 ... 1 (desde la casa hay que oírlas: están a ~75 studs)
	Alcance = { 70, 170 }, -- RollOffMaxDistance con fuerza 0 ... 1
	Ecos = { { 0.38, 0.4, 1.08 }, { 0.85, 0.22, 0.94 }, { 1.45, 0.12, 1.15 } }, -- tintineos después: { s, volumen, tono }
}

-- Avisos visuales para quien juega sin cascos (juego/cliente/Efectos, 14.3): pisadas, polvo del techo, lámparas, cristales en el suelo. A ojo.
Config.Efectos = {
	Cerca = 90, -- studs de la cámara: más lejos no se mira nada
	-- Algo fuera de una ventana o puerta.
	Acerca = 18, -- studs (en planta) del sitio donde se planta el bicho: desde aquí empieza a notarse
	Pegado = 7, -- studs del cristal o la puerta: se nota aunque no sea su sitio (el Trepador por la pared)
	Plantado = 3.5, -- a menos de esto del sitio o del cristal: está pegado (vaho)
	Suaviza = 1.5, -- lo deprisa que sube y baja (por segundo)
	-- Cada bicho: studs entre dos pisadas (como en su Vista), de los pies a la raíz y lo que pesa.
	Bichos = {
		Golpeador = { Zancada = 7.5, Pies = 5, Peso = 1 },
		Raspador = { Zancada = 6.3, Pies = 4, Peso = 0.55 },
		Trepador = { Zancada = 3.5, Pies = 0, Peso = 0.85 },
		Imitador = { Zancada = 7, Pies = 4, Peso = 0.45 },
		Acechador = { Zancada = 11, Pies = 7, Peso = 0.9 },
		Bestia = { Zancada = 10.5, Pies = Config.Bestia.Altura, Peso = 1.4, SinTemblor = true }, -- su temblor, en BestiaVista
	},
	Pasos = 45, -- studs de la cámara a los que se notan las pisadas
	Retumbo = 0.55, -- volumen del retumbo (por el peso y la distancia)
	Temblor = 0.22, -- temblor de cámara por pisada (en CasaVista un golpe es 0,5)
	AlcanceTemblor = 26,
	Encima = 6, -- studs por encima de la cámara: pisa "encima" (cae polvo del techo)
	EncimaPlanta = 18, -- studs en planta de la cámara a los que cae
	PolvoTecho = 14, -- granos de arenilla por pisada encima
	Objetos = 11, -- studs de la pisada a los que tiemblan adornos, cuadros, lámparas, bombillas y cristales
	Cuadro = 1.6, -- grados que se tuerce un cuadro con una pisada fuerte...
	CuadroMax = 7, -- ...hasta este tope
	Bombilla = 0.45, -- probabilidad de que tiemble una bombilla con una pisada (por el peso)
	Golpe = 1.3, -- un golpe en una ventana o puerta hace temblar lo de alrededor como una pisada de este peso
	-- Lámparas colgantes (péndulo).
	Colgada = 1.4, -- studs mínimos de la bombilla al techo para que cuelgue
	Gravedad = 30, -- cuanto más, más deprisa oscila
	Amortigua = 0.5,
	Empuje = 0.22, -- radianes/s por pisada (encima, x1,6)
	MaxAngulo = 0.3,
	-- Cristales del suelo.
	Trozos = 24, -- (con Rendimiento, la mitad)
	Pisar = 0.9, -- studs de un trozo a los que cruje
	CadaCrujido = 0.9, -- studs andados entre dos crujidos
	MaxVentanas = 6, -- ventanas con cristales en el suelo a la vez (las más viejas se barren)
}

-- Cortinas, cristales y puertas cuando algo se acerca por fuera (juego/cliente/CasaVista, 14.3). A ojo.
Config.EfectosCasa = {
	Ondea = 0.32, -- radianes que se mecen las cortinas hacia dentro con algo pegado fuera (abajo del todo)
	VibraCristal = 0.03, -- studs que se mueve el cristal en el marco al vibrar
	VibraDesde = 0.3, -- corriente a partir de la que suena el traqueteo del cristal
	CadaVibra = { 2.2, 4.5 }, -- segundos entre dos traqueteos
	CadaPolvo = { 2.5, 5 }, -- segundos entre dos polvillos del marco
	Empuje = 0.9, -- grados que se comba la puerta hacia dentro
	Vaho = 0.22, -- lo opaco del vaho en el cristal (0 a 1)
	Dientes = 10, -- picos de cristal que quedan en el marco al romperse
}

-- Ambiente con miedo (juego/cliente/AmbienteMiedo, 14.3): fondo de la casa, tensión con un bicho cerca y ráfagas. A ojo.
Config.AmbienteMiedo = {
	Paso = 0.1, -- s entre cada vuelta del bucle
	AltoCasa = 28, -- por encima de esto la cámara ya no está "en casa" (como Ambiente)
	FondoSubir = 0.35, -- del volumen entero por segundo al entrar (unos 3 s)
	FondoBajar = 0.6, -- y al salir (algo menos de 2 s)
	TensionCerca = 16, -- studs: a esta distancia o menos de un bicho, la tensión entera
	TensionLejos = 60, -- más lejos, nada
	TensionDentro = 0.55, -- un bicho dentro de la casa con la cámara dentro: al menos esto
	TensionSubir = 0.12, -- por segundo: de nada a entera en unos 8 s
	TensionBajar = 0.07, -- por segundo: se va más despacio todavía
	TensionEscondido = 0.4, -- escondido, la tensión se queda en esta parte (manda el latido)
	TensionTono = { 0.94, 1.05 }, -- el zumbido sube un poco de tono con la tensión
	RafagaCada = { 35, 90 }, -- s entre ráfagas
	RafagaAlcance = 30, -- studs: ventanas a esta distancia de la cámara
	RafagaFuera = 0.8, -- studs por fuera del cristal desde donde suena
	RafagaTono = { 0.9, 1.08 },
}

-- Sustos sueltos de noche, cada jugador los suyos (juego/cliente/Sustos, 14.3). Segundos y studs a ojo.
Config.Sustos = {
	Paso = 0.25, -- segundos entre vueltas del bucle
	Primero = { 45, 80 }, -- segundos desde que empieza la noche hasta el primero
	Espera = { 170, 230 }, -- segundos entre sustos la primera noche (la noche dura ~240)...
	MenosPorNoche = 0.05, -- ...cada noche un 5 % menos...
	EsperaMinima = 0.5, -- ...hasta la mitad
	Reintento = 3, -- si ahora no se puede, se mira otra vez a los tantos segundos
	LejosBicho = 90, -- con un bicho más cerca, nada
	TrasBicho = 20, -- y nada hasta estos segundos después de que se aleje
	Junto = 8, -- studs alrededor de la casa que aún cuentan
	RepetidoEstaNoche = 0.3, -- el peso de uno que ya ha salido esta noche se multiplica por esto
	Pesos = {
		Silueta = 3, Pasillo = 3, Susurro = 2, Pasos = 3, Pared = 2, Portazo = 3,
		Cuadro = 2, Bombilla = 2, Juguetes = 3, Cristal = 3, Espejo = 2, Goteo = 2,
	},
	-- Silueta
	SiluetaDistancia = { 6, 32 }, -- de la cámara a la ventana
	SiluetaFuera = 5, -- studs por fuera de la ventana
	SiluetaMax = 30, -- si en este tiempo no la ves, se va sola
	-- Pasillo: { x, y, z } de los fondos (el del sótano, la galería y la entrada) y a qué distancia se ve
	Fondos = { { 0, 1, 29.5 }, { 0, 14, 30 }, { 0, 1, -29 } },
	FondoDistancia = { 16, 55 },
	PasilloMirar = 0.45, -- segundos mirándola (o con la linterna encima) hasta que se va
	PasilloMax = 30,
	-- Susurro
	DetrasDesde = 4, -- desde esta noche, a veces hay algo detrás al girarte
	DetrasProb = 0.5,
	-- Pasos
	PasosLargo = 16, -- studs que andan antes de pararse
	PasosTiempo = 5.5,
	PasosMinimo = 1.5, -- segundos como mínimo entre dos sonidos de pasos (por si aún no ha cargado)
	-- Portazo
	PuertaDistancia = { 10, 38 },
	PuertaCerrada = { 5, 8 }, -- segundos cerrada antes de volver a abrirse sola, despacio
	-- Cuadro
	CuadroDistancia = { 5, 26 },
	-- Bombilla
	BombillaDistancia = 16,
	Oscuro = { 12, 18 }, -- segundos a oscuras
	-- Cristal
	CristalDistancia = { 3, 14 },
	-- Espejo
	EspejoDistancia = { 5, 28 },
	-- Goteo
	GoteoTiempo = 9,
	GoteoCada = { 0.5, 1.1 },
}

-- Lobby de noche (lobby/servidor/Gasolinera*, lobby/cliente/*Vista, docs/sistemas/lobby.md; pedido por el usuario:
-- "es un poco feo"). Todo es adorno: segundos y studs a ojo.
Config.Lobby = {
	Cerca = 90, -- más lejos de la cámara no se anima nada (parpadeos pequeños, polillas, limpiaparabrisas)
	Lluvia = {
		Gotas = 700, -- gotas por segundo alrededor de la cámara (con Rendimiento, un tercio)
		Salpicaduras = 14, -- por charco y segundo (con Rendimiento, ninguna)
		Goteo = 2.5, -- gotas por segundo de cada punto del borde de la marquesina y del tejado
	},
	Relampago = { Cada = { 25, 70 }, Trueno = { 1.2, 5 } }, -- segundos entre relámpagos y del relámpago al trueno
	Puerta = 7, -- studs: la puerta de la tienda se abre con alguien a menos de esto
	Polillas = 4, -- alrededor de cada luz que las tenga (con Rendimiento, ninguna)
	Sombra = { Cada = { 60, 150 }, Lejos = { 50, 120 } }, -- algo que se mueve entre los árboles: cada cuánto y a qué distancia
}

-- Sonidos del lobby que aún no existen (para hacer con ElevenLabs; con Id = 0 no suenan). Lo demás del lobby usa los de
-- Config.Sonidos (Viento, Zumbido, Parpadeo, Nevera, NeveraClac, Gota, Buho, Lobo, Rama, Ramita). Al tenerlos, poner
-- su Id y su volumen compensado (docs/sistemas/sonidos.md).
Config.SonidosLobby = {
	Lluvia = { Id = 0, Volumen = 0.6 }, -- lluvia de fondo en bucle (sobre la explanada y los árboles)
	LluviaChapa = { Id = 0, Volumen = 0.5, Alcance = 40 }, -- la lluvia sobre la chapa de la marquesina, en bucle
	Trueno = { Id = 0, Volumen = 1.2 }, -- trueno lejano (mejor una lista de dos o tres)
	Radio = { Id = 0, Volumen = 0.5, Alcance = 18 }, -- radio vieja de la tienda con interferencias, en bucle
	Campanilla = { Id = 0, Volumen = 0.6, Alcance = 25 }, -- la campanilla de la puerta de la tienda
	Arranque = { Id = 0, Volumen = 1, Alcance = 60 }, -- el coche arrancando y saliendo (la cinemática)
}

return Config
