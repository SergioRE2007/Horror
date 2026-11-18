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
	-- El susto al pillarte (14.10, pedido por el usuario: "hay que mejorar el screamer"), en segundos. Lo leen
	-- MuerteVista (la cámara) y GolpeadorVista (su cuerpo). Números a ojo.
	Susto = {
		Arrastra = 0.8, -- si te pilla debajo de un mueble: la mano te agarra y te saca a rastras (antes de lo demás)
		Mira = 0.45, -- quieto a su distancia real, mirándote
		Salta = 0.28, -- se abalanza
		Encima = 1.1, -- encima: garras por los lados de la pantalla y tirones de la cabeza
		Tiron = 0.12, -- tirón final hacia él; luego un fotograma negro con el chillido
		Espera = 3.4, -- el servidor no se mueve hasta pasado esto (Caza.cazar)
	},
	-- Sucesos al azar (14.10, pedido por el usuario: "que no sea siempre igual"). Nunca injustos: mirarte no te mata.
	-- Cada uno, como mucho una vez por noche (entre todos los Golpeadores). Probabilidad = de cada ocasión. A ojo.
	-- Armario.Llegar: s como mucho andando hasta el armario. Finge.Lejos: studs que se aleja antes de mirar atrás.
	-- Garras.Otra: s sin volver a tirar Garras tras una ocasión. Quieto.Otra: s sin tirar Quieto por el mismo jugador.
	Sucesos = {
		Armario = { Probabilidad = 0.6, Cerca = 14, Dura = { 4, 6 }, Llegar = 6 }, -- te mira por las rendijas sin saber que estás
		Olfatea = { Probabilidad = 0.25, Dura = { 2.2, 3 } }, -- se para en una sala y huele hacia ti (cada sala nueva)
		Llama = { Probabilidad = 0.35, Toques = 3, CadaToque = 1.6, Espera = { 3, 4 } }, -- tres toques lentos y espera
		Cara = { Probabilidad = 0.4, Dura = { 5, 8 }, Mirado = 1.5, Distancia = 25 }, -- la cara pegada al cristal
		Finge = { Probabilidad = 0.5, Mira = { 1.4, 2 }, MasPaciencia = 0.5, Lejos = 28 }, -- se va, se para, mira atrás y vuelve
		Garras = { Probabilidad = 0.3, Pared = 3, Dura = { 1.8, 2.6 }, Otra = 5 }, -- arrastra las garras por la pared al pasar
		Quieto = { Probabilidad = 0.5, Lejos = 18, Dura = { 2.5, 3.5 }, Otra = 6 }, -- alumbrado al fondo: no se mueve y luego viene
	},
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
	AmigoLejos = 25, -- imita a uno que esté al menos así de lejos de la puerta (si no hay, a cualquiera)
	SaleCerca = 22, -- studs: si alguien sale y se le acerca tanto, deja de llamar y va a por él
	Apagon = 1.5, -- segundos desde la primera llamada hasta "The lights went out." (su primera noche)
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
	MasPillar = 2, -- studs de más al pillar mientras se te echa encima (corriendo se pasa de largo)
	TrasPillar = 2.5, -- segundos quieto tras pillarte
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
-- El Director (juego/servidor/Director; el reparto de qué bicho toca, en shared/RepartoBichos).
Config.Director = {
	Reintento = 2, -- segundos que espera un hueco sin ventana libre o con la Bestia fuera antes de volver a mirar
}

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
-- 15.8 (pedido por el usuario): Hombro = va al hombro a lo largo (si no, delante con las dos manos); Lanzar = se puede
-- tirar (solo la madera: lo demás es único o hace falta, y no debe perderse); Golpe = el sonido al caer.
Config.Pesados = {
	Tronco = { Tam = { 6, 1.4, 1.4 }, Peso = 1, Nombre = "Log", Hombro = true, Lanzar = true, Golpe = "GolpeMadera" },
	Tablon = { Tam = { 6, 0.3, 1 }, Peso = 1, Nombre = "Plank", Hombro = true, Lanzar = true, Golpe = "GolpeMadera" },
	Bidon = { Tam = { 1.6, 2.4, 1.6 }, Peso = 1, Nombre = "Fuel can", Golpe = "GolpeMetal" },
	Motor = { Tam = { 3.2, 2.2, 2.4 }, Peso = 2, Nombre = "Engine", Golpe = "GolpeMetal" },
	Rueda = { Tam = { 1, 2.6, 2.6 }, Peso = 1, Nombre = "Wheel", Golpe = "GolpeMetal" }, -- cilindro: el eje va a lo largo de X
	TablonReforzado = { Tam = { 6, 0.45, 1 }, Peso = 1, Nombre = "Reinforced plank", Hombro = true, Lanzar = true,
		Golpe = "GolpeMadera" },
	Reja = { Tam = { 6, 6, 0.5 }, Peso = 2, Nombre = "Iron gate", Golpe = "GolpeMetal" }, -- sale del banco del sótano; se monta al pie de la escalera
}
Config.Cargar = {
	Frena = { 0.6, 0.5 }, -- multiplica tu velocidad según el Peso de lo que llevas (con todos los que hacen falta)
	Arrastrar = 0.25, -- velocidad arrastrando algo que necesita más gente
	Fuerza = 0.6, -- parte del peso que levanta cada uno: con 2 que la cogen, 1,2 veces el peso del motor
	Delante = 1.4, -- studs entre tu cuerpo y lo que llevas
	Suelta = 9, -- si se queda más lejos (atascada), se te cae
	-- 15.8 (pedido por el usuario: "todo"): físicas de verdad, al hombro, lanzar y ruido (shared/CargarReglas). A ojo.
	-- Lo que lleva uno solo (Peso 1) lo mueve su cliente (CargarVista) y choca con todo menos con los jugadores.
	Engancha = 2.5, -- studs (en horizontal) entre donde debería ir y donde está: se ha enganchado en algo
	Desengancha = 1.6, -- y por debajo de esto ya no
	FrenaEnganche = 0.35, -- tu velocidad mientras lo que llevas está enganchado (si sigues tirando, a Suelta se cae)
	Giro = 8, -- fuerza (veces su peso) con que se endereza lo que lleva uno: floja, para que los marcos lo giren
	Hombro = { Lado = 1, Apoyo = -0.2, Delante = 0.12, Cabeceo = 6 }, -- studs desde la raíz, parte del largo y grados
	Balanceo = {
		Giro = 9, -- rad/s del muelle con que sigue tu giro (menos = se queda más atrás)
		Amortigua = 0.5, -- menos de 1: al parar de girar se pasa un poco y vuelve
		MaxRetraso = 55, -- grados como mucho que se queda atrás
		Bote = 0.09, -- studs que baja a cada paso
		Ladeo = 3, -- grados que se ladea a cada paso
		Paso = 0.55, -- pasos por stud andado
	},
	Dejar = 0.35, -- s que tardas en dejarlo en el suelo con la E (así no suena)
	Lanzar = {
		Carga = 0.8, -- s manteniendo hasta la fuerza máxima
		Velocidad = { 18, 46 }, -- studs/s sin cargar y cargado del todo
		Arriba = 0.35, -- lo que sube de más hacia arriba (si no, cae enseguida)
		Vueltas = 5, -- rad/s que da vueltas de punta a punta, cargado del todo
		Atras = 0.7, -- studs que lo echas atrás al cargar
		Minimo = 0.15, -- s que hay que mantener para que sea lanzar (menos, no hace nada)
	},
	Vuelo = 6, -- s como mucho que el servidor sigue lo que se suelta (golpes y que no se pierda)
	Caida = 40, -- studs por debajo de donde se soltó: se ha salido del mapa y vuelve allí
	Ruido = {
		Umbral = 14, -- studs/s que tiene que perder de golpe para que suene
		Fuerte = 45, -- studs/s de un golpe a tope
		Alcance = { 18, 45 }, -- studs a los que lo oye un bicho, del golpe más flojo al más fuerte
		Arrastrar = 26, -- studs a los que se oye arrastrar algo
		CadaArrastre = 0.6, -- s entre dos ruidos de arrastre
		Dura = 2, -- s que un bicho puede oír cada ruido
		Espera = 0.25, -- s como mínimo entre dos golpes de la misma pieza
		Paredes = 0.5, -- lo que llega de un ruido de dentro de la casa a un bicho de fuera, o al revés
	},
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

-- Llegada en coche y coche destrozado tras la noche 1 (juego/servidor/Llegada, cliente LlegadaCocheVista, 16.8).
-- Números a ojo. Sitio = { x, z } donde aparca, en la carretera delante de la casa (mirando a ella).
Config.Llegada = {
	Activa = true,
	Sitio = { 0, -60 },
	Segundos = 9, -- lo que dura la escena de llegada
	Recorrido = 110, -- studs de carretera que hace el coche en la escena
	Espera = 8, -- segundos como mucho esperando a que tengan personaje antes de la escena
	Tope = 30, -- segundos como mucho con EscenaLlegada puesto, aunque algo falle
	SinDecidir = 60, -- si tras esto desde que arranca el servidor sigue sin decidirse (nil), el tutorial empieza igual
	Ver = 30, -- a esta distancia del coche destrozado te llega el aviso
	Minimo = 60, -- segundos tras el amanecer antes de llevárselo al garaje
	Lejos = 55, -- y sin nadie a menos de esto
	Giro = 14, -- grados que queda torcido el destrozado
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
-- esquinas"). Agachado los bichos te ven y te oyen menos; debajo de un mueble te huelen y gatean a por ti. Números a ojo.
Config.Postura = {
	Velocidad = 0.5, -- agachado se anda a la mitad
	Baja = 1.7, -- studs que baja la cámara al agacharse
	Asomar = 1.3, -- studs que se mueve la cabeza de lado al asomarte
	Giro = 14, -- grados que se ladea al asomarte
	Cada = 0.15, -- segundos como mínimo entre dos cambios (servidor)
	-- Esconderse agachado (pedido por el usuario, 03-11-2026: "agacharte también debería servir para esconderte, por
	-- ejemplo debajo de mesas, y que el monstruo pueda gatear si te huele… que sea útil agacharte es la finalidad").
	Alto = 2.6, -- studs de alto de lo que choca de tu cuerpo agachado: cabes bajo un tablero algo más alto
	VistaAgachado = 0.6, -- agachado y sin cubrirte, los bichos te ven a esta parte de su Vista
	OirAgachado = 4, -- y te oyen a estos studs (de pie, a 8)
	VerCubierto = 3, -- debajo de algo (atributo Cubierto) solo te ven o te oyen así de cerca
	Olfato = 14, -- studs a los que un bicho te huele debajo de algo
	Huele = 5, -- segundos oliéndote hasta saber dónde estás (lejos, se le olvida a la mitad de deprisa)
	Gatear = 2, -- segundos que tarda en meterse a por ti debajo del mueble (si sales y te alejas antes, lo deja)
	-- Los bichos (Caza y Bestia) con quien está debajo de un mueble. A ojo.
	Oido = 8, -- studs a los que te oye un bicho de pie (agachado o debajo de algo, menos: OirAgachado, VerCubierto)
	Fuera = 2.5, -- studs fuera del mueble donde se para a gatear: cabe su raíz (3 × 1,5) y el camino llega
	-- Los que de pie sacan brazos o cabeza por delante se paran algo más lejos, para no meterlos en el tablero antes
	-- de gatear (empiezan a gatear a CercaBorde del sitio, así que suelen quedar 1-3 más lejos todavía).
	FueraRaspador = 3.4, -- el Raspador (brazos colgando)
	FueraTrepador = 4, -- el Trepador (cabeza muy adelantada)
	FueraBestia = 4, -- la Bestia, que es enorme
	CercaBorde = 3, -- studs del borde a los que empieza a gatear
	SeEscapa = 6, -- studs del borde: si sales del mueble y te alejas más, ya no te alcanza
	Atasco = 4, -- segundos sin acercarse al borde (no hay camino) para dejarte y probar otro lado
	MaxOlor = 0.5, -- segundos de olor como mucho de una vez (si lleva rato sin mirar, golpeando una puerta)
	Ancho = 1.3, -- media anchura libre que necesita a los lados del borde para meterse (su raíz mide 3)
	SinSalida = 20, -- segundos sin volver a probar un borde al que no llegó (luego lo vuelve a intentar)
}

-- Correr y aguante (14.8, pedido por el usuario: "añadir la mecánica de correr, que tengas una stamina abajo del todo,
-- una barra fina así minimalista que aparezca al correr"). Reglas en shared/CorrerReglas; el servidor (juego/servidor/
-- Correr) lleva el aguante y la velocidad sale de Cargar.ajustarVelocidad. Números a ojo (cuentas de persecución en
-- tests/bancos/correr-cuentas.luau).
Config.Correr = {
	Factor = 1.5, -- corriendo, la velocidad de andar por esto (16 → 24; con la clase Corredor, 19,2 → 28,8)
	Dura = 6.5, -- segundos de aguante seguido corriendo, con el aguante lleno
	Espera = 1, -- segundos sin correr hasta que el aguante empieza a volver
	-- Aguante que vuelve por segundo andando (de vacío a lleno, 12 s). Con 10, el mejor ciclo de correr y andar
	-- sostenía 18,9 studs/s, casi la Bestia (19): se la dejaba en tablas en línea recta (tests/bancos/correr-cuentas).
	Andando = 1 / 12,
	Quieto = 1 / 5, -- y quieto o agachado (5 s)
	Volver = 1 / 3, -- agotado del todo, no se vuelve a correr hasta tener esto
	Frena = 1.2, -- segundos que frenas al agotarte...
	FactorFrena = 0.6, -- ...andando a esta parte de lo normal
	Tropiezo = 0.35, -- de cada vez que te agotas corriendo, cuántas tropiezas (la cámara cae y te recuperas)
	Moverse = 2, -- studs/s: más despacio no cuenta como correr (aunque lo pidas)
	Delante = 0.25, -- y tiene que ir hacia delante: coseno entre hacia donde va y hacia donde mira (de lado o atrás, no)
	Oido = 22, -- studs a los que te oye un bicho mientras corres (de pie, Config.Postura.Oido)
	Cada = 0.1, -- segundos como mínimo entre dos peticiones que cuentan (servidor; las de más se juntan)
	Publicar = 0.1, -- segundos como mínimo entre dos publicaciones del atributo Aguante
	Gracia = 0.4, -- s que el cliente corre sin que el servidor lo confirme (al empezar: que vaya al momento)
	Poco = 0.25, -- con menos aguante, la barra pasa a rojo oscuro
	Jadeo = "VientoTiro", -- sonido provisional del jadeo mientras Config.Sonidos.Jadeo tenga Id 0
	JadeoTono = 1.6, -- y su tono (solo el provisional)
}

Config.Movil = {
	Duracion = 150, -- segundos mirándolo con la batería llena
	Carga = 60, -- segundos en el enchufe hasta llenarse
	Radio = 90, -- studs de mundo que se ven del centro al borde (de lado) de la pantalla
}

-- Segundos mínimos entre dos peticiones del mismo jugador a cada remote (servidor/Limite, 16.16). Los de antes están como
-- estaban; los marcados "nuevo" no tenían y son a ojo (nadie los pulsa tan seguido). Lo que tiene su propio ritmo de
-- juego no está aquí: Bestia.Recarga (bengalas), Talar.Cada (hachazos), Flash.Recarga, Postura.Cada y la ventana de Correr.
Config.Limites = {
	Idioma = 1, -- cada cambio del atributo Lang llega a todos los clientes
	Ajustes = 0.25,
	Clase = 0.3,
	Compra = 1,
	Tienda = 0.3,
	Coche = 0.2, -- todo menos "Arrancar"
	Pista = 0.3,
	Mochila = 0.05, -- mover/tirar; lo que llega antes se deshace en el cliente
	Linterna = 0.25, -- no pasa de dos destellos por segundo
	Mirada = 0.15,
	Flash = 0.25, -- nuevo: contando también los intentos fallidos (avisos); la recarga de verdad es Flash.Recarga
	Movil = 0.3, -- nuevo: al abrirlo, contando los fallidos (avisos)
	Vendedor = 0.25, -- nuevo
	Taller = 0.3, -- nuevo
	Usar = 0.25, -- nuevo: usar lo que se lleva en las manos sobre un sitio
	Mirar = 0.2, -- nuevo: el muerto cambia a quién mira
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
	-- 16.5, a ojo: parte del depósito del generador que pide antes de la noche (una noche gasta 0,5 a ritmo 1; con un
	-- bidón lleno siempre se llega), segundos tras empezar el día hasta el aviso de la siguiente meta y lo que tarda
	-- en poder repetirse (que no lleguen dos seguidos al entrar el día 1).
	Gasolina = 0.45,
	Meta = 6,
	MetaOtraVez = 30,
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
	Vajilla = { Id = 0, Volumen = 0.5, Alcance = 30 }, -- platos y vasos que tintinean al temblar (mientras, CristalVibra)
	Mecedora = { Id = 0, Volumen = 0.6, Alcance = 30 }, -- crujido de la mecedora al mecerse sola (mientras, Cruje)
	Resoplido = { Id = 0, Volumen = 0.8, Alcance = 40 }, -- la Bestia al soltar el aire (mientras, el Rugido muy grave y cortado)
	-- Correr (14.8): FALTA, para hacer con ElevenLabs. Mientras, el provisional de Config.Correr.Jadeo.
	Jadeo = { Id = 0, Volumen = 0.7, Alcance = 30 }, -- jadeo al agotarte corriendo (lo oyen los de cerca)
	-- Golpeador (14.10): FALTAN, para hacer con ElevenLabs (sonidos-pendientes.md). Mientras, el código usa otro.
	GritoGolpeador = { Id = 0, Volumen = 2 }, -- el chillido final del susto del Golpeador (mientras, Susto)
	Olfateo = { Id = 0, Volumen = 0.9, Alcance = 35 }, -- golpes de nariz cortos de un bicho grande
	UnasPared = { Id = 0, Volumen = 1, Alcance = 45 }, -- garras arrastradas por una pared de madera y yeso
	ToqueDedo = { Id = 0, Volumen = 1, Alcance = 60 }, -- un toque lento con una uña contra un cristal
	RespiraBicho = { Id = 0, Volumen = 0.8, Alcance = 20 }, -- respiración húmeda y lenta de un bicho, muy de cerca
	-- Cargar con físicas (15.8): PROVISIONALES con ids de otros sonidos hasta hacerlos con ElevenLabs
	-- (sonidos-pendientes.md); Lanzar falta (Id 0: no suena).
	GolpeMadera = { Id = 90088146547108, Volumen = 1.2, Alcance = 90 }, -- un tronco o un tablón que da contra el suelo (mientras, Caida)
	GolpeMetal = { Id = 90763366072682, Volumen = 1.6, Alcance = 90 }, -- el bidón, la rueda o el motor al caer (mientras, Golpe)
	Arrastre = { Id = 133574014508797, Volumen = 1.2, Alcance = 50 }, -- algo pesado arrastrado por el suelo, en bucle (mientras, Hollin)
	Lanzar = { Id = 0, Volumen = 0.7, Alcance = 25 }, -- el resoplido al lanzar algo pesado
	-- Bichitos (bichitos.md): FALTAN, para hacer con ElevenLabs. Mientras, la rata chilla con un Cruje flojo y agudo.
	RataChillido = { Id = 0, Volumen = 0.35, Alcance = 25 }, -- chillido corto de rata al huir
	RataPatas = { Id = 0, Volumen = 0.3, Alcance = 18 }, -- patitas con uñas corriendo por madera
	Moscas = { Id = 0, Volumen = 0.25, Alcance = 12 }, -- zumbido de moscas sobre un charco, en bucle
	-- Cuerpos que caen de verdad (cadaver.md): FALTAN, para hacer con ElevenLabs (sonidos-pendientes.md).
	GritoMuerte = { Id = 0, Volumen = 1.6, Alcance = 200 }, -- grito de alguien al que pilla un bicho (mientras, Susto)
	CuerpoCae = { Id = 0, Volumen = 0.9, Alcance = 50 }, -- cuerpo contra el suelo (mientras, Retumbo flojo y agudo)
	LinternaCae = { Id = 0, Volumen = 0.6, Alcance = 30 }, -- linterna que cae y rueda por el suelo (mientras, nada)
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
	EsperaChimenea = 30, -- segundos como mucho esperando a que el mapa traiga la chimenea (si no llega, sin chimenea viva)
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

-- Aire vivo: polvo siempre en la luz, haces de luna y niebla baja (juego/cliente/AireVista, docs/sistemas/aire.md).
-- Solo adorno del cliente; números a ojo. Con Rendimiento, motas a Rendimiento y sin haces, niebla ni pinocha.
Config.Aire = {
	Cada = 0.1, -- segundos entre dos repasos (cajas colocadas, emisores encendidos o apagados)
	Rendimiento = 0.3, -- parte de las motas que quedan con Rendimiento
	-- Motas de dentro: una caja delante de la cámara; con LightInfluence 1 solo se ven donde da la luz.
	Motas = { Rate = 7, Caja = { 9, 5, 11 }, Delante = 6 }, -- por segundo, caja (ancho, alto, fondo) y studs por delante
	-- Salas con más polvo (o casa también, aunque estén fuera de Config.Casa): rectángulos sacados de SALAS de Mapa.
	-- `Motas` multiplica Motas.Rate. Lo primero que contenga a la cámara manda.
	Salas = {
		{ Nombre = "Desvan", x1 = -39.5, x2 = 39.5, y1 = 26.5, y2 = 42, z1 = -33.5, z2 = 33.5, Motas = 3 },
		{ Nombre = "Sotano", x1 = -12.5, x2 = 12.5, y1 = -12, y2 = 0.5, z1 = 33.5, z2 = 66, Motas = 3 },
		{ Nombre = "Trastero", x1 = 12, x2 = 22, y1 = 0, y2 = 13.5, z1 = 5, z2 = 19, Motas = 3 },
		{ Nombre = "Garaje", x1 = -59, x2 = -39, y1 = 0, y2 = 14, z1 = 3, z2 = 33, Motas = 1.5 },
		{ Nombre = "Cobertizo", x1 = -54, x2 = -44, y1 = 0, y2 = 12, z1 = 37, z2 = 45.5, Motas = 2 },
	} :: { { Nombre: string, x1: number, x2: number, y1: number, y2: number, z1: number, z2: number, Motas: number } },
	-- Haces de luna (las luces etiquetadas "Luna" de Mapa.luzLuna): de noche, de la ventana al suelo.
	Haz = {
		Cerca = 70, -- studs de la cámara: más lejos, apagado
		Ancho = { 2.2, 7 }, -- en la ventana y en el suelo (como mucho)
		Abre = 0.3, -- studs de ancho por stud de largo
		Transparencia = 0.93, -- en el centro (casi transparente)
		Motas = 3, -- por segundo dentro de cada haz
		Ventana = 7, -- studs: la ventana (etiqueta Ventana) más cerca que esto la tapa al cerrar la persiana o tablones
	},
	-- Niebla baja de fuera, de noche: partículas grandes y planas alrededor de la cámara.
	Niebla = { Radio = 40, Rate = 5, Alto = 2.2, Velocidad = { 0.5, 1.4 } },
	-- Pinocha que cae en las rachas, con un pino a menos de `Cerca` studs (en planta).
	Pinocha = { Cerca = 16, Rate = 12, Racha = 0.55, Alto = 14 },
	-- Viento (no lo había en Ambiente: lo pone AireVista.viento): rumbo en radianes en el plano xz, cuánto se desvía y
	-- cada cuánto, y fuerza (studs/s de deriva).
	Viento = { Rumbo = 0.7, Giro = 0.6, Lento = 0.012, Fuerza = { 0.4, 1.6 }, Rachas = 0.16 },
}

-- Pavor al ver un bicho: vértigo, manos que tiemblan y latido (juego/cliente/PavorVista, docs/sistemas/pavor.md).
-- Solo adorno del cliente; números a ojo. Con Rendimiento, sin vértigo ni retraso: solo el latido y un temblor flojo.
Config.Pavor = {
	Lejos = 45, -- studs: más lejos, verlo no cuenta
	Cerca = 8, -- studs: más cerca, del todo
	Minimo = 0.4, -- lo fuerte que es verlo justo en el límite (Lejos)
	Olvida = 15, -- s sin verlo para que el mismo bicho vuelva a asustar
	Cada = 0.15, -- s entre mirada y mirada (los rayos)
	Borde = 0.04, -- parte de la pantalla, por cada borde, que no cuenta como "a la vista"
	-- Vértigo: el campo de visión se cierra `Campo` grados (del todo) y la cámara recula `Recula` studs, en `Cierra` s;
	-- se queda `Queda` s y vuelve en `Vuelve` s.
	Vertigo = { Campo = 10, Recula = 0.35, Cierra = 0.5, Queda = 0.25, Vuelve = 2.6 },
	Sobresalto = 0.45, -- el golpe de tensión, flojo: su volumen por este número (y menos lejos)
	SobresaltoCada = 4, -- s como poco entre dos
	Manos = 0.5, -- el respingo de las manos (ManosGestos.sobresalto) del todo
	Latido = { Volumen = 0.9, Dura = { 3, 6 }, Apaga = 2.5 }, -- por el suyo; s que suena entero (lejos, cerca) y apagándose
	Dura = { 20, 30 }, -- s que dura el pavor (lejos, cerca), bajando poco a poco
	Baja = 1.6, -- cómo baja: (1 - t / dura) ^ Baja
	-- Las manos y la linterna tiemblan: giro (radianes) y desplazamiento (studs) con el pavor entero; vueltas por
	-- segundo del temblor fino y del lento; con Rendimiento, por `Rendimiento`.
	Temblor = { Giro = math.rad(1.3), Mueve = 0.012, Fino = 9, Lento = 2.3, Rendimiento = 0.4 },
	Respira = 0.8, -- el susto de la respiración de la cámara (CuerpoVista.respiracion) con el pavor entero
	-- Al girar rápido la vista se queda atrás: desde `Desde` rad/s, `Tiempo` s de lo girado, `Max` radianes como mucho,
	-- y lo deprisa que sigue (por segundo).
	Retraso = { Desde = 1.5, Tiempo = 0.025, Max = math.rad(2.2), Suave = 12 },
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

-- Huellas de barro y de sangre que dicen por dónde ha ido el bicho (juego/cliente/HuellasVista, docs/sistemas/huellas.md).
-- Solo adorno del cliente: cada uno las calcula con lo que ve. Colores en RGB (sin Color3, para que Lune lo cargue). A ojo.
Config.Huellas = {
	Cada = 0.1, -- segundos entre dos repasos de lo andado
	CadaColor = 1, -- segundos entre dos repasos del color y lo aclarado
	Cerca = 160, -- studs de la cámara: más lejos ni se cuentan pisadas ni se aclaran
	Tope = 80, -- huellas vivas como mucho (las más viejas se borran primero)
	TopeRendimiento = 30,
	Textura = "rbxassetid://115119002468912", -- la de las huellas con uñas del salón (Mapa, HOLLIN.Huellas)
	Barro = { 52, 38, 26 },
	SangreFresca = { 150, 14, 10 }, -- roja y brillante...
	SangreSeca = { 64, 32, 20 }, -- ...y seca, marrón
	Secar = 60, -- segundos de fresca a seca
	Ensangrentado = 40, -- segundos tras matar en que el bicho deja huellas de sangre
	CercaMuerte = 16, -- studs: si el remote Muerte no dice qué bicho fue, el más cercano a esto
	Transparencia = { 0.1, 0.7 }, -- recién pisada ... al cabo de Aclarar (y así hasta el amanecer)
	Aclarar = 240, -- segundos (una noche)
	-- Jugadores: zapatos.
	Zancada = 3.6, -- studs entre dos pisadas
	PasosSangre = { 8, 10 }, -- pisadas rojas tras pisar un charco (cada jugador siempre las mismas: por su UserId)
	SangreUltima = 0.85, -- transparencia de la última de ellas (se apagan paso a paso)
	PasosBarro = 4, -- al entrar en casa del bosque
	Fuera = { "Grass", "LeafyGrass", "Ground", "Mud" }, -- suelo de fuera que manchará de barro
	Zapato = { Ancho = 0.48, Largo = 0.78, Tacon = 0.36, Lado = 0.45 }, -- planta, tacón y separación entre pies
	-- Bichos: forma de la huella (Garra, ManosPies o Zapato), tamaño { ancho, largo } y separación entre los dos lados.
	Bichos = {
		Golpeador = { Forma = "Garra", Tam = { 1.4, 2.7 }, Lado = 1.6 },
		Raspador = { Forma = "Garra", Tam = { 1, 1.9 }, Lado = 1.1 },
		Trepador = { Forma = "ManosPies", Tam = { 0.9, 1.7 }, Lado = 1.3 },
		Imitador = { Forma = "Zapato", Tam = { 0.52, 1.1 }, Lado = 0.5 }, -- imita a una persona: zapatos
		Acechador = { Forma = "Garra", Tam = { 1.5, 2.9 }, Lado = 1.8 },
		Bestia = { Forma = "Garra", Tam = { 2.8, 5.4 }, Lado = 3.4 },
	} :: { [string]: { Forma: string, Tam: { number }, Lado: number } },
}

-- Marcas de la noche: arañazos en las puertas y sangre salpicada en las paredes (juego/cliente/MarcasVista,
-- docs/sistemas/marcas.md). Solo adorno del cliente, calculado por cada uno con la misma semilla. RGB sin Color3. A ojo.
Config.Marcas = {
	Tope = 60, -- marcas vivas como mucho (un zarpazo o una mancha con sus gotas); las más viejas se borran primero
	TopeRendimiento = 20,
	Cerca = 70, -- studs de la cámara: más lejos no se animan los chorretones ni se seca la sangre (se pone al día luego)
	-- Arañazos del Golpeador (cada golpe, atributo Golpes): un zarpazo de 3-4 surcos paralelos, oscuros y con el borde
	-- claro, y alguna astilla levantada. En la hoja, el marco o la pared de al lado, por fuera.
	Surcos = { 3, 4 },
	Largo = { 1.3, 2.4 }, -- studs de cada surco
	Separa = { 0.16, 0.24 }, -- studs entre dos surcos
	Ancho = { 0.06, 0.1 }, -- studs de cada surco
	Inclina = 0.6, -- radianes como mucho desde la vertical (arañan hacia abajo)
	Oscuro = 0.3, -- el color del surco: el de la madera por esto (hundido, en sombra)
	Claro = { 182, 146, 104 }, -- madera recién arrancada: el borde levantado y las astillas
	Astillas = { 1, 3 }, -- por zarpazo (con Rendimiento, ninguna)
	EnHoja = 0.75, -- en una puerta, de cada zarpazo, lo que cae en la hoja (el resto, en el marco)
	Cede = 0.4, -- con la vida por debajo de esto (de 0 a 1) la hoja cede: también arañazos por dentro
	-- El Raspador: rayas finas y largas en el cristal, por fuera, según va raspando (atributo Raspado de 0 a 1).
	Raspado = {
		Cada = 0.08, -- una pasada de rayas por cada tanto de Raspado
		Rayas = { 2, 3 },
		Largo = { 1.4, 3 },
		Ancho = 0.025,
		Color = { 214, 218, 220 },
		Transparencia = 0.4,
		Cerca = 7, -- studs del bicho a donde se planta (Fuera de la ventana) para saber qué ventana raspa
	},
	-- Sangre (remote Muerte): rayos desde el pecho del muerto hacia paredes, suelo y muebles; donde dan, manchas
	-- alargadas en la dirección del golpe, gotas alrededor y, en lo vertical, algún chorretón que escurre despacio.
	Rayos = 26, -- (con Rendimiento, Rayos / 2)
	Alcance = 10.5, -- studs (unos 3 m)
	Pecho = 1.2, -- studs por encima de la raíz de donde sale
	Mancha = { 0.5, 1.5 }, -- studs de ancho de una mancha: lejos ... cerca
	Gotas = { 1, 3 }, -- gotas pequeñas alrededor de cada mancha
	Gota = { 0.08, 0.22 }, -- studs de ancho de una gota
	Chorreon = 0.4, -- de cada mancha grande en lo vertical, lo que escurre
	Chorreones = 5, -- como mucho por muerte
	ChorreaLargo = { 0.8, 2.6 }, -- studs que baja
	ChorreaDura = { 5, 9 }, -- segundos que tarda en bajar del todo
	Textura = "rbxassetid://93752217357412", -- el hollín de Mapa (HOLLIN.Hollin), teñido, sobre las manchas grandes
	Fresca = { 112, 8, 6 }, -- roja...
	Seca = { 52, 12, 8 }, -- ...y seca, casi negra
	Secar = 90, -- segundos de fresca a seca
	CadaColor = 1, -- segundos entre dos repasos del color
}

-- Cuerpos que caen de verdad: el compañero muerto se queda tirado (juego/cliente/CadaverVista,
-- docs/sistemas/cadaver.md). Solo adorno del cliente. Segundos, studs y grados; números a ojo.
Config.Cadaver = {
	Anclar = 3, -- segundos como mucho que se mueve el muñeco; luego se anclan todas sus piezas
	AnclarRendimiento = 1.5,
	Quieto = 1.5, -- studs/s del tronco: más despacio que esto...
	QuietoMin = 0.8, -- ...pasado este rato...
	QuietoTiempo = 0.4, -- ...y durante esto, ya se ancla antes
	Tope = 4, -- muñecos moviéndose a la vez; con uno más, el más viejo se ancla tal como está
	Empuje = 20, -- studs/s en horizontal, hacia el lado contrario del bicho
	Salto = 9, -- studs/s hacia arriba
	Giro = 5, -- rad/s del tronco hacia atrás
	Azar = 0.2, -- cada pieza, un poco más o menos de empuje
	Friccion = 4, -- rozamiento de las rótulas: que no se balanceen sin fin
	Golpe = 10, -- studs/s: frenar de golpe desde más que esto suena a cuerpo contra el suelo
	TonoGrito = 0.8, -- el grito provisional (Susto) mientras GritoMuerte tenga Id 0
	VolumenGrito = 0.8,
	EsperaPropio = 1, -- tu muñeco: como poco esto tras morir, y cuando la cámara deja de ser de script
	EsperaPropioMax = 25, -- ...o a esto, pase lo que pase
	FuerzaPropio = 0.15, -- tu cuerpo ya ha caído durante el susto: apenas empuje
	SinAviso = 0.3, -- muertes sin remote Muerte: tras el Died, el muñeco cae donde está
	-- Límites de cada rótula: { cono, giro a cada lado } en grados.
	Juntas = {
		Cuello = { 40, 45 },
		Cintura = { 25, 20 },
		Hombro = { 85, 60 },
		Codo = { 70, 10 },
		Muneca = { 30, 15 },
		Cadera = { 55, 25 },
		Rodilla = { 70, 8 },
		Tobillo = { 25, 10 },
		Otra = { 30, 20 },
	},
	-- El charco de MuerteVista: escondido mientras vuela el muñeco; luego bajo su pecho, creciendo despacio.
	Charco = {
		Crece = 8, -- segundos de pequeño a su tamaño
		Desde = 0.5, -- studs de diámetro al empezar
		Tam = { 5, 7 }, -- studs de diámetro al final
		Cerca = 4, -- studs: un charco nuevo tan cerca de donde cayó es suyo
		Espera = 3, -- segundos tras la muerte en que se busca su charco
	},
	-- La linterna que se le cae, si la llevaba encendida.
	Linterna = {
		Dura = 40, -- segundos encendida en el suelo
		Apaga = 6, -- los últimos segundos baja y parpadea más
		Corte = -0.45, -- con el ruido por debajo de esto, un tirón a casi apagada (más alto, más tirones)
		Tirones = 3, -- lo deprisa que cambia el ruido
		Rueda = 2.5, -- segundos rodando antes de quedarse quieta
		Brillo = 2.5, -- más flojo que en la mano (Config.Linterna.Brillo)
		Rango = 30,
		Angulo = 50,
		Empuje = 7, -- studs/s con que sale de la mano
		Cerca = 160, -- studs de la cámara: más lejos no se le toca el brillo
	},
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

-- Puertas que revientan: astillas, la hoja colgando de una bisagra (juego/cliente/PuertaRotaVista,
-- docs/sistemas/puerta-rota.md). Solo lo ve el cliente; números a ojo.
Config.PuertaRota = {
	Cede = { 0.5, 0.25 }, -- con menos vida que esto (de la máxima) se mete un tablón hacia dentro, y luego otro
	Tablas = 0.8, -- studs de ancho de cada tabla de la hoja (la hoja se parte en tablas al ceder)
	Metido = 0.45, -- studs que se mete hacia dentro el trozo de tabla que cede
	Hueco = { 0.28, 0.38 }, -- alto del trozo que cede (parte del alto de la hoja)
	Colgada = { Giro = 25, Ladeo = 7, Vuelco = 6, Bisagra = 0.15 }, -- grados hacia la sala, caída del lado de la
	-- cerradura, la parte de arriba hacia la sala y altura de la bisagra que aguanta (parte del alto de la hoja)
	Caida = 0.4, -- segundos que tarda la hoja en quedarse colgando (con su rebote)
	Mecer = { Grados = 6, Segundos = 2.5, Vueltas = 3 }, -- se balancea un poco en la bisagra y se para
	Vuelve = 0.6, -- segundos que tarda en volver a su sitio al repararla
	Astillas = { 10, 14 }, -- astillas y trozos de tabla que saltan al reventar
	AstillasPoco = 5, -- con Rendimiento
	Salen = { 8, 15 }, -- studs/s hacia la sala
	Anclar = 2, -- segundos: las que ya están quietas se anclan (las que aún se mueven, como mucho al doble)
	Picos = { 4, 6 }, -- picos de madera que quedan en el marco del lado de la cerradura
	Polvo = 30, -- polvo y arenilla que caen del dintel al reventar
	Cerca = 30, -- studs de la cámara: más lejos ni se mira quién las pisa
	Pisar = 1.1, -- studs (en planta) de unos pies a una astilla para que cruja
	CadaCrujido = 1.4, -- studs que hay que andar para que vuelva a crujir
}

-- La casa se desordena: lo que cae con los golpes y las sillas que vuelca el bicho (juego/cliente/DesordenVista,
-- docs/sistemas/desorden.md). Solo adorno del cliente; números a ojo.
Config.Desorden = {
	Alcance = 14, -- studs en planta de un golpe en una puerta o ventana a los que se caen cosas...
	Planta = 6, -- ...en la misma planta (studs de alto)
	Caen = { 1, 2 }, -- cosas por golpe (con Rendimiento, una)
	Ventana = 3, -- se elige entre los tantos más cerca del borde que quedan
	Pisada = { Peso = 1, Celda = 8, Prob = 0.35, Alcance = 9 }, -- pisadas fuertes: peso mínimo del bicho, cada cuántos
	-- studs cuenta una, la parte de ellas que tira algo y a cuántos studs
	CuadroGolpes = 3, -- golpes cerca para que un cuadro ya muy torcido se descuelgue
	Tope = 25, -- cosas caídas como mucho (adornos, cuadros y sillas)
	Altura = 1, -- studs mínimos de la balda o la mesa al suelo (lo del suelo no se cae)
	BaldaMax = 18, -- studs: un apoyo más grande es el suelo
	Empuje = { 3.5, 5.5 }, -- studs/s hacia fuera del borde
	Choque = 6, -- studs/s de caída: frenar de golpe desde más que esto es dar contra el suelo
	Anclar = 2.5, -- segundos: lo caído y quieto se ancla (lo que aún se mueve, como mucho a AnclarMax)
	AnclarMax = 5,
	Trozos = { 4, 6 }, -- trozos de un plato o una botella rota (con Rendimiento no se rompen)
	TrozosSalen = { 2, 5 }, -- studs/s
	Cerca = 90, -- studs de la cámara: más lejos no hay física, se pone ya en el suelo (y sin sonido)
	Roce = 2, -- studs en planta de la raíz del bicho a una silla para volcarla
	Silla = { Segundos = 0.55, Rebote = 7 }, -- lo que tarda en caer y los grados del botecito (sin él con Rendimiento)
	Mecedora = { Aparta = 1.4, Giro = 25, Segundos = 0.45 }, -- studs, grados y segundos
	Pisar = 0.9, -- studs (en planta) de unos pies a un trozo para que cruja
	CadaCrujido = 1.2, -- studs que hay que andar para que vuelva a crujir
	CercaPisar = 30, -- studs de la cámara: más lejos ni se mira quién los pisa
}

-- Bichitos: ratas que huyen de la linterna, polillas en las bombillas y moscas en la sangre (juego/cliente/BichitosVista,
-- docs/sistemas/bichitos.md). Solo adorno del cliente; números a ojo.
Config.Bichitos = {
	Cerca = 25, -- studs de la cámara (en planta) a los que hay bichitos; más lejos se borran
	Margen = 5, -- studs de más para borrar lo que ya estaba (que no salga y se borre en el borde)
	Cada = 0.25, -- segundos entre dos repasos de qué hay cerca
	Desnivel = 1.2, -- studs: un suelo más alto o más bajo que el de la sala (escalón, hueco) no vale para andar
	-- Salas: rectángulos en planta por dentro de las paredes (de juego/servidor/Mapa), la altura de su suelo y lo alto
	-- (la cámara tiene que estar entre el suelo y el techo). Ratas o Cucarachas: cuántas { mín, máx }.
	Salas = {
		{ Nombre = "Sotano", x1 = -12, x2 = 12, z1 = 35, z2 = 65.5, Suelo = -11, Alto = 12, Ratas = { 2, 4 } },
		{ Nombre = "Desvan", x1 = -38.5, x2 = 38.5, z1 = -14, z2 = 14, Suelo = 27, Alto = 13, Ratas = { 2, 4 } },
		{ Nombre = "Trastero", x1 = 12.5, x2 = 21.5, z1 = 5.5, z2 = 18.5, Suelo = 1, Alto = 12, Ratas = { 2, 3 } },
		{ Nombre = "Garaje", x1 = -58.5, x2 = -39.5, z1 = 3.5, z2 = 32.5, Suelo = 1, Alto = 14, Ratas = { 2, 4 } },
		{ Nombre = "Cocina", x1 = -38.5, x2 = -12.5, z1 = 3.5, z2 = 32.5, Suelo = 1, Alto = 12, Cucarachas = { 2, 4 } },
	} :: { { Nombre: string, x1: number, x2: number, z1: number, z2: number, Suelo: number, Alto: number,
		Ratas: { number }?, Cucarachas: { number }? } },
	-- Studs/s andando y huyendo; Susto: studs (en planta) de ti o de otro jugador a los que huye sin luz; Luz y Angulo:
	-- hasta dónde y a cuántos grados del centro la espanta tu linterna (sin pared en medio); segundos quieta, studs de
	-- cada paseo y segundos escondida antes de volver; Bicho: studs de la sala a los que un bicho (workspace.Bichos) las
	-- esconde a todas, sin un ruido, hasta que se va; Tam: tamaño.
	Rata = {
		Anda = 2.4, Huye = 14, Susto = 6, Luz = 30, Angulo = 20,
		Pausa = { 1.5, 5 }, Paseo = { 1.5, 4.5 }, Vuelve = { 18, 40 }, Bicho = 22, Tam = { 0.85, 1.15 },
		Volumen = 0.12, Tono = { 1.9, 2.3 }, -- el chillido provisional (Cruje muy flojo y agudo) mientras no haya RataChillido
	},
	Cucaracha = {
		Anda = 0.8, Huye = 8, Susto = 2.5, Luz = 18, Angulo = 24,
		Pausa = { 2, 8 }, Paseo = { 0.4, 1.5 }, Vuelve = { 12, 30 }, Bicho = 22, Tam = { 0.8, 1.2 },
	},
	Polillas = { 2, 3 }, -- alrededor de cada bombilla encendida (las "Lampara" del generador)
	-- De noche y fuera de casa, con la linterna encendida: cada cuánto acude una polilla, cuánto se queda y a cuántos
	-- studs por delante de la cámara revolotea.
	PolillaLinterna = { Cada = { 30, 70 }, Dura = { 8, 15 }, Delante = 2.6 },
	Moscas = { Cuantas = { 5, 8 }, Llegan = 6 }, -- por charco de sangre (etiqueta Charco) y segundos que tardan en llegar
	Rendimiento = { Ratas = 1, Polillas = 1 }, -- con Rendimiento: esto por sala y por bombilla; ni cucarachas ni moscas
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
	LejosBicho = 30, -- con un bicho más cerca (o cualquiera dentro de la casa), nada
	TrasBicho = 8, -- y nada hasta estos segundos después de que se aleje
	-- Noche desde la que puede salir cada uno (sin él, desde la 1): que vaya a más, los de sangre al final.
	Desde = {
		Cuadro = 1, Portazo = 1, Pasos = 1, Bombilla = 1, Silueta = 2, Pared = 2,
		Susurro = 2, Juguetes = 2, Pasillo = 3, Cristal = 3, Espejo = 4, Goteo = 4,
	},
	PistaGiro = 11, -- el "He knew" del espejo solo sale si el jugador ya ha leído esta pista (la del giro, historia.md)
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
	TiendaLejos = 25, -- studs del mostrador a los que el servidor aún acepta una compra
	TiendaCerrar = 16, -- y a los que el cliente (TiendaUi) la cierra sola: menos que TiendaLejos, para no fallar compras
	Polillas = 4, -- alrededor de cada luz que las tenga (con Rendimiento, ninguna)
	Sombra = { Cada = { 60, 150 }, Lejos = { 50, 120 } }, -- algo que se mueve entre los árboles: cada cuánto y a qué distancia
	-- Guía del jugador nuevo (16.7, a ojo): flecha grande y una línea. Altura = studs de la flecha sobre lo que señala;
	-- TiendaSegundos = lo que dura la de la tienda si no la sigue; Forzar = "Coche" o "Tienda" para verla en Studio.
	Guia = { Forzar = nil :: string?, Altura = { Coche = 6, Tienda = 4.5 }, TiendaSegundos = 120 },
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
	MotorCoche = { Id = 0, Volumen = 0.8, Alcance = 60 }, -- motor de coche viejo al ralentí, en bucle: el que llega tras
	-- un viaje (LlegadaVista, 14.9.3), que le cambia el tono con la velocidad. Mientras tenga Id 0, Arranque una vez.
}
-- El mismo motor de coche en la partida (la llegada en coche, juego/cliente/LlegadaCocheVista, 16.8): una sola entrada
-- para los dos lugares, así al grabarlo suena en ambos. Con Id 0, mudo (mejor que el zumbido del generador, Motor).
Config.Sonidos.MotorCoche = Config.SonidosLobby.MotorCoche

-- Modelos 3D de los bichos (IA de imagen a 3D, preparados con tools/blender/preparar_bicho.py y subidos como modelo
-- del grupo): id del modelo con malla con esqueleto y sus cuatro texturas. Ver docs/sistemas/bichos-3d.md.
Config.Bichos3D = {
	Golpeador = 86798537714395,
}

-- Oído: sonido tapado por las paredes y eco de cada sala (juego/cliente/OidoVista, docs/sistemas/oido.md). A ojo.
Config.Oido = {
	Cada = 0.25, -- segundos entre dos rayos de un mismo sonido mientras suena
	CadaRendimiento = 0.5, -- ...con Rendimiento
	CercaRendimiento = 60, -- con Rendimiento, solo se miden los sonidos a menos de esto (studs)
	MaxParedes = 2, -- paredes que se cuentan como mucho
	Rayos = 6, -- rayos por sonido como mucho (capas de una misma pared, cosas pequeñas por medio)
	Grosor = 1.6, -- golpes más juntos que esto a lo largo del rayo son la misma pared (papel, muro y papel)
	Margen = 1.5, -- studs sin mirar junto al sonido: la ventana que golpean no tapa su propio golpe
	Pared = 3, -- tapa lo que tenga dos lados de al menos esto (studs): un tronco o una pata no tapan
	PorPared = { Agudos = -18, Medios = -6, Volumen = 0.7 }, -- por pared: dB menos en agudos y medios, y volumen que queda
	Escondido = { Agudos = -14, Medios = -5, Volumen = 0.75 }, -- escondido: lo de fuera, a través de la madera
	ApagarEscondido = { Viento = true, CasaFondo = true }, -- bucles sin posición que también se apagan escondido
	MuebleRadio = 40, -- studs alrededor de la cámara en los que se miran los muebles (MuebleRayo)
	MuebleCada = 2, -- segundos: las cajas de los muebles se rehacen así de a menudo...
	MuebleMover = 8, -- ...o al moverse la cámara esto (studs)
	-- Eco (Enum.ReverbType) según dónde esté la cámara: la primera zona que la contenga. Cajas { x1, x2, y1, y2, z1, z2 }
	-- (las salas, en juego/servidor/Mapa) o un círculo en planta (Centro { x, z } y Radio). Si ninguna, Fuera.
	Zonas = {
		{ Reverb = "StoneCorridor", Cajas = { { -13, 13, -14, -1.5, 33, 67 }, { -3.5, 3.5, -14, 8, 33.5, 48 } } }, -- sótano y su escalera
		{ Reverb = "Room", Cajas = { { -39.5, 39.5, 26.5, 50, -33.5, 33.5 } } }, -- desván
		{ Reverb = "Bathroom", Cajas = { { 12, 22, 0, 13.5, 19, 33 } } }, -- baño
		{ Reverb = "Hangar", Cajas = { { -59.5, -39, 0, 16, 2.5, 33.5 } } }, -- garaje
		{ Reverb = "LivingRoom", Cajas = { -- la casa y sus anexos (Config.Casa.Anexos)
			{ -39.5, 39.5, -2, 26.5, -33.5, 33.5 },
			{ 30.5, 47.5, -2, 40, -41.5, -24.5 },
			{ -43.5, -39, -2, 26.5, -17.5, -2.5 },
			{ -26.5, -11.5, -2, 26.5, 33, 45.5 },
		} },
		{ Reverb = "Alley", Centro = { 28, -480 }, Radio = 88 }, -- el pueblo (Lugares, ZONAS.Pueblo)
	},
	Fuera = "Forest",
}

-- Tormenta seca: relámpagos que iluminan la casa y recortan a los bichos (juego/cliente/TormentaVista,
-- docs/sistemas/tormenta.md). Solo en el cliente; el horario sale de una semilla con Noche y FaseInicio. A ojo.
Config.Tormenta = {
	Desde = 2, -- noche desde la que puede haber tormenta
	Probabilidad = 0.5, -- de las noches desde Desde, cuántas tienen tormenta
	Primero = { 10, 30 }, -- segundos desde que empieza la noche hasta el primer relámpago
	Cada = { 25, 70 }, -- segundos entre relámpagos
	HastaNoche = 0.92, -- parte de la noche a partir de la que ya no cae ninguno (amanece)
	Destellos = { 2, 3 }, -- destellos por relámpago (con Rendimiento, uno)
	Duracion = { 0.05, 0.12 }, -- segundos que dura cada destello
	Subida = 0.015, -- segundos hasta lo más fuerte de un destello
	Entre = { 0.06, 0.25 }, -- segundos entre dos destellos seguidos
	Trueno = { 1, 5 }, -- segundos del relámpago al trueno (cerca, antes)
	Cerca3D = 0.65, -- desde esta cercanía (0 a 1) el trueno suena en 3D desde fuera; si no, lejano y sin posición
	Lejos3D = 45, -- studs de la cámara (en planta) desde donde suena el trueno cercano
	Alto3D = 25, -- ...y a esta altura por encima de ella
	TonoRetumbo = { 0.38, 0.5 }, -- Retumbo muy grave y largo, mientras no haya un trueno propio (Sonidos.Trueno)
	TonoTrueno = { 0.9, 1.05 }, -- el trueno propio, cuando lo haya
	Volumen = { 0.6, 1.2 }, -- lo que se multiplica el volumen: de lejos a cerca
	Dentro = { Volumen = 0.7, Agudos = -22, Medios = -8 }, -- el trueno lejano oído desde dentro de la casa
	-- Lo que sube en lo más fuerte de un destello (se suma a la luz de Ambiente; un instante, nunca más).
	Luz = {
		Brillo = 2, -- Lighting.Brightness
		Fuera = { 80, 88, 110 }, -- RGB que se suma al OutdoorAmbient (sin Color3, para que Lune lo cargue)
		Niebla = { 130, 140, 165 }, -- RGB que se suma a la niebla: el cielo se pone blanco azulado
		Color = 0.1, -- brillo del ColorCorrection
		Contraste = 0.2, -- contraste del ColorCorrection: las siluetas, más negras
		Luna = 4, -- se suma al brillo de cada luz de luna cercana (las de Mapa.luzLuna)
	},
	-- Fogonazo con sombras (sin Rendimiento): una luz por luna cercana, por fuera del cristal y en la misma línea que la
	-- luna, para que los marcos, las cortinas y lo que haya fuera (un bicho) recorten su sombra en el suelo.
	Fogonazo = {
		Cerca = 50, -- studs de la cámara: lunas más lejos, sin fogonazo
		Max = 3, -- como mucho, las tantas más cercanas
		Atras = 5, -- studs por fuera de la luna, hacia atrás en su línea
		Brillo = 7,
		Angulo = 55,
		Color = { 205, 215, 255 }, -- RGB
	},
	Ventanas = 22, -- studs: con el trueno vibran los cristales de las ventanas a menos de esto de la cámara
	VibraSonidos = 2, -- ...y suenan las tantas más cercanas
	Temblor = { Fuerza = 0.35, Dura = 1.4 }, -- las bombillas tiemblan con el trueno (de 0 a 1 de su brillo) tanto tiempo
	TemblorCamara = 0.15, -- con un trueno cercano, un temblor de cámara así de flojo (CasaVista.temblar)
}
-- El trueno propio de la tormenta, mientras tanto con Id 0 (suena Retumbo): docs/sistemas/sonidos-pendientes.md.
Config.Sonidos.Trueno = { Id = 0, Volumen = 1, Alcance = 400 }

-- Ojos en la oscuridad: la linterna los hace brillar entre los árboles (juego/cliente/OjosVista, docs/sistemas/ojos.md).
-- Solo del cliente y de adorno, salvo que los de los bichos son de verdad (y no se apagan al mirarlos). Colores en RGB
-- (sin Color3, para que Lune lo cargue). Todo a ojo.
Config.Ojos = {
	Cada = 0.25, -- segundos entre repasos (qué bichos hay cerca, si toca sacar unos ojos falsos)
	Noche = 0.5, -- desde esta noche (0 a 1, las rampas de Ambiente) hay ojos
	Entre = { 18, 45 }, -- segundos entre unos ojos falsos y los siguientes (fuera, de noche y con la linterna)
	Distancia = { 30, 70 }, -- studs de la cámara a los que salen los falsos (nunca a menos de Nunca)
	Nunca = 20,
	Lejos = 70, -- más allá no brillan (ni los de los bichos); con el pase Luz, hasta Alcance × 1,3 si es más
	Cono = 0.9, -- de la mitad del ángulo de la linterna (Config.Linterna.Angulo): los falsos salen dentro de esto
	Centro = 0.55, -- dentro de esta parte del cono brillan enteros; hacia el borde se apagan (fuera del haz, nada)
	Doble = 0.3, -- probabilidad de que salgan dos pares
	Persona = 0.3, -- probabilidad de que estén a altura de persona (si no, de animal)
	Alto = { Animal = { 1.1, 2.4 }, Persona = { 4.6, 5.6 } }, -- studs sobre el suelo
	Separacion = { Animal = { 0.35, 0.6 }, Persona = { 0.3, 0.4 } }, -- studs entre los dos ojos de un par
	Vida = { 5, 10 }, -- segundos que se quedan los falsos si no los miras
	Parpadeo = { 1.2, 3.5 }, -- segundos entre parpadeos de los falsos
	ParpadeoBicho = { 3, 7 }, -- ...y de los bichos
	Cierre = 0.12, -- segundos con los ojos cerrados en un parpadeo
	Fijo = 6, -- grados del centro de la vista: mirarlos así de fijo...
	Mirada = 0.6, -- ...estos segundos los apaga (a los falsos)
	Cerca = 24, -- studs: acercarse a menos de esto también los apaga
	Apagar = 0.2, -- segundos que tardan en apagarse al irse
	Ramita = { Tras = 0.25, Volumen = 0.7, Otra = 0.5, Lejos = 3 }, -- al irse: retraso, volumen, otra más lejos, studs
	BichoCerca = 12, -- studs: más cerca, los ojos del bicho ya no brillan (se le ve entero)
	Cara = 0.15, -- los del bicho, solo si te mira de cara (el coseno entre su cara y tú)
	Tam = { Studs = 0.07, Px = 3 }, -- tamaño de cada ojo (studs más píxeles: de lejos no se pierde)
	Halo = 2.6, -- el halo flojo alrededor de cada ojo, tantas veces el ojo
	Transparencia = 0.3, -- del ojo encendido del todo ("muy flojos")
	TransparenciaHalo = 0.85,
	Colores = { { 150, 195, 110 }, { 225, 160, 75 } }, -- verdoso y ámbar
	-- Los bichos que tienen ojos que brillan: dónde está cada ojo en su Cabeza (los puntitos Neon de su modelo, un poco
	-- por delante) y su color (de Colores).
	Bichos = {
		Acechador = { Color = 2, Ojos = { { -0.22, 0.35, -0.62 }, { 0.22, 0.35, -0.62 } } },
		Golpeador = { Color = 2, Ojos = { { -0.32, 0.38, -0.78 }, { 0.3, 0.31, -0.78 } } },
		Trepador = { Color = 1, Ojos = { { -0.3, 0.3, -0.78 }, { 0.3, 0.3, -0.78 } } },
		Bestia = { Color = 2, Ojos = { { -0.6, 0.45, -1.52 }, { 0.55, 0.5, -1.52 }, { -0.25, 0.65, -1.52 },
			{ 0.3, 0.3, -1.52 }, { -0.75, 0.15, -1.52 }, { 0.8, 0.2, -1.52 } } },
	},
}

-- Ojos que se acostumbran a la oscuridad (y deslumbran) (juego/cliente/AdaptarVista, docs/sistemas/adaptar.md). Solo del
-- cliente y de adorno. "Luz" es una suma sin unidades que pasa a 0..1 con 1 - e^(-suma) (AdaptarCuentas.juntar).
-- Todo a ojo y flojo, para que no moleste.
Config.Adaptar = {
	Cada = 0.1, -- segundos entre medidas de la luz que te llega
	Rayos = 6, -- luces que se miran con un rayo por medida como mucho (las que más dan)
	Minimo = 0.02, -- una luz que da menos que esto ni se mira
	Base = 0.03, -- lo que hay siempre (cielo, estrellas)
	Luz = {
		Dia = 1.6, -- de día, fuera (sin techo encima)...
		DiaDentro = 0.5, -- ...y dentro
		Linterna = 0.45, -- la tuya encendida...
		Rebote = 0.55, -- ...y lo de más si el haz da contra algo cerca...
		RebotaHasta = 10, -- ...a menos de estos studs
		Bombilla = 0.6, -- cada luz a su alcance y sin pared: brillo × (1 - distancia/alcance)² × esto
		Luna = 0.5, -- las de luna (etiqueta Luna), igual
		Rayo = 1.8, -- el relámpago (Ambiente.destello) fuera...
		RayoDentro = 0.5, -- ...y dentro
		Escondido = 0.3, -- metido en un escondite, de todo eso solo llega esta parte
		Techo = 60, -- studs del rayo hacia arriba para saber si estás bajo techo
	},
	Baja = 3.5, -- s (τ): acostumbrarse a la oscuridad (casi del todo en ~10 s)
	Sube = 0.6, -- s (τ): acostumbrarse a la luz (el deslumbre se va en ~1 s)
	Relativo = 0.1, -- los saltos de luz se miden en proporción: (nueva - vieja) / (vieja + esto)
	Desde = 0.3, -- salto desde el que se nota...
	Pleno = 1.8, -- ...y desde el que es entero
	Claro = 0.25, -- con los ojos hechos a más luz que esto, nada de grises...
	Oscuro = 0.06, -- ...y hechos a menos, del todo acostumbrado
	Hundido = -0.25, -- Brightness al quedarte a oscuras de golpe
	Acostumbrado = { Brillo = 0.06, Saturacion = -0.35, Frio = { 232, 238, 255 } }, -- a oscuras y hecho: siluetas en gris
	Deslumbre = { Brillo = 0.3, Contraste = -0.3, Saturacion = -0.15, Calido = { 255, 238, 214 } }, -- RGB, sin Color3
	-- La linterna de otro a la cara: a menos de Lejos studs y dentro de Angulo grados de su haz.
	Ajena = { Lejos = 25, Angulo = 12, Fuerza = 0.8, Rendimiento = 0.5, Entra = 0.08, Sale = 0.25 },
}

-- Cielo de la partida (juego/cliente/CieloVista, docs/sistemas/cielo.md): estrellas, luna, nubes (Clouds del Terrain)
-- y el viento que las arrastra. Colores en RGB, sin Color3 (para que Lune lo cargue). Números a ojo.
Config.Cielo = {
	Cada = 0.1, -- s entre repasos (10 por segundo); mientras dura un relámpago, las nubes cada fotograma
	Estrellas = 600, -- de noche (las 3000 de serie brillaban demasiado con la exposición alta); de día y con tormenta, 0
	EstrellasRendimiento = 0.5, -- con Rendimiento, esta parte (y sin nubes)
	Luna = 15, -- MoonAngularSize (de serie 11): algo mayor
	Rampa = 25, -- s que tarda el cielo en cerrarse o abrirse con la tormenta
	-- Clouds: Cover (cuánto cielo tapan), Density (lo gruesas y oscuras que son) y Color (RGB). Día y noche se mezclan con
	-- la misma rampa que la luz de Ambiente; la tormenta va encima.
	Nubes = {
		Dia = { Cover = 0.8, Density = 0.55, Color = { 150, 153, 158 } }, -- gris y casi cerrado
		Noche = { Cover = 0.56, Density = 0.42, Color = { 104, 111, 132 } }, -- rotas: la luna y algunas estrellas entre ellas
		Tormenta = { Cover = 0.94, Density = 0.86, Color = { 64, 66, 76 } }, -- cerrado, bajo y pesado
	},
	-- Con cada relámpago (Ambiente.destello, de 0 a 1) la nube se aclara por dentro: el color va hacia Color en esta
	-- parte (Mezcla) y se hace algo menos densa. Vuelve igual en cuanto acaba.
	Destello = { Color = { 205, 214, 240 }, Mezcla = 0.8, Densidad = -0.2 },
	Viento = 6, -- workspace.GlobalWind = AireVista.viento (rumbo × fuerza de 0,4 a 1,6) × esto: las nubes se arrastran
	Tormenta = {
		Abre = 0.93, -- parte de la noche desde la que el cielo empieza a abrirse (el último relámpago cae antes del 0,92)
		Luz = 0.8, -- con el cielo cerrado, Brightness y OutdoorAmbient de Ambiente por esto (el relámpago, entero)
		Viento = 1.8, -- el viento de las nubes, por esto
	},
}

return Config
