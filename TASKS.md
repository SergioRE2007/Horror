# Tareas

Sale de `docs/plan-tecnico.md` (orden de construcción) y `docs/diseño.md`. Sergio pide pasos enteros ("paso 10"): se hacen todas sus tareas seguidas, en orden, en una sola rama, con un commit por tarea (pedido por el usuario). Estados: `hecho`, `en curso`, `pendiente`. Al acabar una tarea se marca aquí en el mismo commit. Todo lo que queda por hacer está en este archivo (pedido por el usuario: "apunta todo en task"); el detalle de cada sistema va en `docs/sistemas/`.

## Lo siguiente, en orden

0. **Probar en Studio lo de "Pendientes para Studio"** (abajo, de lo más importante a lo menos): todo lo de las
   sesiones del 03 y 04-11-2026 está hecho sin Studio o probado solo en parte.
1. 14.2 (que Sergio apruebe el tutorial) y 14.5 Partida entera de prueba, con la propuesta a ojo de
   `docs/sistemas/economia.md`.
2. Sonidos e imágenes que faltan (`docs/sistemas/sonidos-pendientes.md`), cuando vuelva a haber créditos.
3. 14.10 Golpeador: mejor susto y sucesos al azar (pedido por el usuario).
4. 11.2 Monstruos (casi al final), 13.2 Lanzamiento.

## Hechas

1. Base: Rojo con los dos lugares, `Config`, `Lang`, `Remotes`, `Datos` con candado, Lune y modo de pruebas — hecho
2. El corazón: casa gris, día y noche, Golpeador, persianas, esconderse y morir — hecho
3. Raspador, linterna con pilas, flash y dificultad por jugadores — hecho
4. Mochila de casillas, objetos y cargar cosas pesadas — hecho
5. Bosque gris, talar, tablones, generador y móvil con mapa — hecho
6. Guardado de la partida, lobby, coches y viaje — hecho
7. Llaves, salas cerradas, pueblo y vendedor — hecho
8. Taller, coche y final de la huida — hecho
9. Trepador, Imitador y Acechador — hecho
10. Monedas, clases, tienda de la gasolinera, revivir y compras con Robux — hecho (`docs/sistemas/clases.md`, `tienda.md`, `compras.md`; faltan los Id de Roblox al publicar, 13.2)
11. Arte ya hecho:
    - 11.1 Casa y bosque con Blender — hecho (`docs/sistemas/arte.md`)
    - 11.3 Sonidos con ElevenLabs — hecho (`docs/sistemas/sonidos.md`)
    - 11.4 Cortinas en vez de persianas — hecho (`docs/sistemas/corazon.md`)
    - 11.5 Casa más grande con muebles del Creator Store: la casa — hecho (`docs/sistemas/casa-grande.md`); el pueblo sigue abajo
    - 11.6 Casa nueva con el plano aprobado, ensanchada para correr, y fachada victoriana (`Fachada.luau`) — hecho (`docs/sistemas/casa-nueva.md`); fachada vista y aprobada por Sergio
    - Plugin VistaMapa para mover cosas a mano sin Play — hecho
    - Paso previo del interior: papel, molduras, techos y muebles más apagados y sucios; techos rotos; mecedora nueva; burro de serrar en X; quitadas la mesa de la cocina y la silla volcada; sillas del comedor orientadas — hecho

## 11. Arte (lo que queda)

### 11.8 Interior realista, sala por sala (pedido por el usuario: "la casa por dentro es un ñordo gordo", muebles "demasiado simples")
- **Qué:** cambiar los muebles de la tienda de Roblox y los hechos con bloques por modelos de Poly Haven (CC0, uso comercial libre), pasados por Blender a Roblox con sus texturas (`SurfaceAppearance`). Lo que no haya, en Blender por script, nunca bloques.
- **Cómo (pedido por el usuario: una sala por chat y bien hecha, sin pasar a la siguiente hasta que la apruebe):** los 7 pasos de cada sala, la lista de muebles de cada una y la tubería están en `docs/plan-salas.md`. Blender abierto.
- **Incluye lo que quedaba de la 11.6** (salas menos vacías, que no parezcan cajas: arcos, columnas, techos y suelos distintos, balaustrada de verdad) **y la 11.7** (cada mueble mirando a la sala, apoyado y de tamaño creíble; los sospechosos están puestos en su sala).
- **Reglas que no cambian (pedido por el usuario):** ninguna ventana tapada, el centro libre, vanos anchos, nada que estorbe al correr; Moderate como máximo.
- **Criterios:** realista y abandonado de día y de noche; móvil a 30 fps o más (unos 5.000 triángulos por mueble, texturas de 512-1024); escondites, ventanas atacables, puertas con llave y objetos de `Mapa.objetos` siguen funcionando. Si se mueve una ventana o puerta, avisar: las partidas viejas la pierden.

| Tarea | Sala | Además revisar | Estado |
|---|---|---|---|
| 11.8.0 | Tubería Poly Haven → Roblox (`docs/sistemas/polyhaven.md`), probada con la butaca | — | hecho |
| 11.8.1 | Vestíbulo (aprobado por el usuario: "ha quedado muy bien") | dónde aparece el jugador | hecho |
| 11.8.2 | Salón (aprobado por el usuario: "esta bien") | sofá, tele encogida al 70 %; chimenea del Trepador sin tocar | hecho |
| 11.8.3 | Comedor (aprobado por el usuario: "me convence") | — | hecho |
| 11.8.4 | Cocina (aprobado por el usuario: "esta guay"; nevera de los 50 hecha aquí, pedido por el usuario) | sillas, cocina de hierro | hecho |
| 11.8.5 | Pasillo, baño y trastero (aprobado por el usuario: "esta bien") | bañera y váter; puerta del sótano | hecho |
| 11.8.6 | Dormitorio de abajo (aprobado por el usuario) | cama de hierro (escondite) y armario | hecho |
| 11.8.7 | Galería | balaustrada de verdad sobre el hueco | hecho |
| 11.8.8 | Dormitorio grande | cama y armario (escondites); salida al balcón | hecho |
| 11.8.9 | Habitación del rico | lámpara del escritorio; sitio de las pistas (12.1) | hecho |
| 11.8.10 | Cuarto de los niños | cuna y juguetes | hecho |
| 11.8.11 | Escalera del desván y desván | baúles; cuarto de revelado | hecho |
| 11.8.12 | Lavadero, garaje y cobertizo | enchufe del móvil, coche, generador | hecho |
| 11.8.13 | Sótano | banco del taller (la reja de la 12.2) | hecho (aprobado por el usuario el 02-11-2026) |

En todas: telarañas que flotan o se meten en la pared.

### 11.9 Detalles vivos de la casa (pedido por el usuario: "poner que la chimenea esté animada con fuego o sonidos de los electrodomésticos, detallitos")

- Todo en el cliente (`DetallesVista` y `ChimeneaVista`), sin tocar el camino del Trepador. Detalle en `docs/sistemas/detalles.md`.
- Chimenea: chispas, brasas que se enfrían al apagarse, llamarada al quemar al Trepador; al bajar él, las brasas se apagan de golpe y las luces tiemblan (aviso). Viento por el tiro.
- Reloj de pie del vestíbulo (tic-tac y campanadas de noche), nevera con el generador, gotas en fregadero y lavabo, bombillas que chisporrotean y tuberías que golpean.
- Sonidos con ElevenLabs (tanda `detalles`), elegidos por el usuario; los de la bombilla, de YouTube (pedido por el usuario). — hecho

### 11.5 Pueblo amueblado
- **Qué (pedido por el usuario: "hacerlo bien, pero rápido", no las 2 semanas de la casa):** fachadas bien hechas en todos los edificios y solo unos pocos con interior. Nada de una sala por chat: todo en 1-2 conversaciones.
- **Fachadas:** las de `Fachada.luau` de la casa (tablas, ventanas con molduras, tejados con tejas, porches), cada casa distinta (color, una o dos plantas, porche o no). Iglesia de piedra. Las cerradas, tapiadas y sin interior.
- **Se entra en:** tienda (vendedor), la casa de la puerta rota, iglesia, cripta y caseta del enterrador. Muebles reutilizados de la casa (`src/muebles/`) y pocos nuevos.
- **Calle:** farolas apagadas, coche abandonado, buzones, vallas caídas.
- **Modelos:** borrar todo script y lo que no sea pieza, malla o textura (en la prueba, 2 de 6 traían virus); descartar los sacados de otros juegos. Mejor Poly Haven, como en la 11.8.
- **Estado:** hecho — detalle en `docs/sistemas/pueblo.md` (vendedor como personaje de Roblox, vallas oscuras, charcos sin reflejo y bosque alrededor: pedido por el usuario)

### 11.2 Monstruos con IA
- **Descripción:** Golpeador, Raspador, Trepador, Imitador y Acechador desde dibujos de Sergio, pasados por IA de imagen a 3D, con esqueleto y animaciones por código.
- **Criterios:** licencia comercial comprobada; no pasa de Moderate (se ven en penumbra o un instante); animados.
- **Estado:** pendiente — necesita los dibujos de Sergio; se deja para casi el final (pedido por el usuario)

## 12. Final difícil e historia

### 12.1 Pistas de la historia
- **Descripción:** notas, fotos y diario repartidos por el mapa y las salas cerradas; cuentan que el rico te mandó a propósito.
- **Archivos probables:** `src/juego/servidor/Pistas.luau` (nuevo), `FormatoPartida.luau`, `Lang`.
- **Criterios:** se guardan en la partida; carteles de pocas líneas; guardado viejo sin pistas sigue cargando (prueba de Lune).
- **Estado:** hecho (`docs/sistemas/pistas.md`); falta un sonido de papel

### 12.2 La Bestia
- **Descripción (pedido por el usuario):** la Bestia es el origen de todos los bichos (partes o crías suyas que cazan para ella; el rico la alimenta con gente y por eso te contrató). Se la mata dentro de la casa: herirla, atraerla al sótano, encerrarla y quemar la casa empapada de gasolina. Al morir ella caen todos.
- **Preparación** (días y noches normales, lo explican las pistas):
  1. Gasolina: un bidón en cada uno de 6 puntos marcados de la casa (salón, cocina, pasillo, escalera, los dos dormitorios); se ve el charco, suena `Verter`. El último deja un rastro hasta el porche.
  2. Trampa del sótano: reja de hierro armada en el banco del taller con piezas (cadenas, barrotes); cae con una palanca y encierra lo que haya dentro.
  3. Pistola de bengalas del rico en el desván, con 3 bengalas (luz y fuego: lo que la daña).
  4. Cerillas para prender el rastro.
- **Noche final:** empieza con "Esperarla" en la casa cuando todo está listo. Esa noche no sale ningún otro bicho. Es más rápida que el jugador; cada bengala la deja cojeando ~8 s y más lenta. Se la atrae al sótano, se pasa la reja y se tira de la palanca; se sale por una trampilla nueva al patio. Desde el porche, la cerilla al rastro: el fuego recorre la casa sala por sala, cinemática de la casa ardiendo con su rugido, amanece; recompensa e insignia. Sin bengalas o con la reja fallada, te pilla y mueres.
- **Números a ojo:** 6 puntos de gasolina, 3 bengalas, ~8 s cojeando (en `Config`).
- **Criterios:** se puede completar de principio a fin en `Config.Test`; recompensa e insignia propias, entregadas una vez; lo preparado se guarda en la partida (guardado viejo sigue cargando, prueba de Lune); cinemática que esconde la interfaz y la devuelve siempre.
- **Estado:** hecho — probado en Studio de punta a punta el 02-11-2026 (`docs/sistemas/bestia.md`); lo que queda por pulir, en el plan de pulido

## 13. Lanzamiento

### 13.1 Tutorial
- **Descripción:** los primeros 5 minutos, muy visible (flecha grande, pasos cortos, premio al acabar).
- **Estado:** en curso: es la 14.2 (`docs/sistemas/tutorial.md`)

### 13.2 Nombre, iconos y lanzamiento en privado
- **Descripción:** también crear en Roblox los productos y pases de `Config.Compras` (Id = 0 ahora) y probar compras de verdad.
- **Estado:** pendiente — decide Sergio

## 14. Pulido (pedido por el usuario: "un nuevo plan con muchas fases para empezar con pulir el juego", 02-11-2026)

Cada fase es un paso entero en su rama. Lo que salga al probar, se apunta en su fase.

### 14.1 Final de la Bestia justo y vistoso
- **Palanca fuera:** pasarla al patio, junto a la trampilla. Se la mete en el sótano, se sale por la trampilla y se tira desde fuera (ahora, dentro, te pilla mientras tiras aunque cojee).
- **Que suba al piso de arriba:** ahora arriba estás a salvo porque no encuentra camino.
- **Incendio grande:** llamas por ventanas y tejado, humo, la casa entera ardiendo en la escena final.
- **Puerta principal cerrada** al empezar "Wait for her", para que la reviente.
- **Morir esa noche** no borra lo preparado ese día.
- **Bidón:** no soltarlo después de cada cruz mientras le quede gasolina.
- **Aviso** "Corre. Vuelve a la luz." no tiene sentido en el sótano oscuro de la noche final.
- **Estado:** hecho (`docs/sistemas/bestia.md`; probado en Studio de punta a punta el 02-11-2026)

### 14.2 Los primeros 5 minutos
- Es la 13.1 (tutorial muy visible: flecha grande, pasos cortos, premio al acabar). Se diseña con Sergio.
- **Estado:** en curso: propuesta hecha por Claude sin Studio (`docs/sistemas/tutorial.md`); falta probarla en Studio y que Sergio la apruebe

### 14.3 Más miedo
- Sustos y efectos (temblores, polvo que cae, cristales) como avisos para quien juega sin cascos (sale en `diseño.md`; mirar antes si ya está con otro nombre).
- Trampas de latas que suenan fuera de la casa (ídem).
- Sonido de ambiente, con ElevenLabs. Falta también el sonido de papel de las pistas.
- **Estado:** hecho (`docs/sistemas/miedo.md`; probado en Studio el 02-11-2026). Faltan 8 sonidos (sin créditos de ElevenLabs hasta ~08-11) y la imagen de la mano de sangre

### 14.4 Controles y móvil
- Botones que solo salen muy cerca (la puerta del sótano, a ~3 studs).
- Ajustes con opción Rendimiento (mirar antes si ya está).
- HUD en pantallas pequeñas, cuántas piezas tiene el mapa (el pueblo, ~5.100 más 240 pinos) y probar en móvil.
- Aviso suelto del asset 203785492 en la consola.
- **Estado:** hecho (`docs/sistemas/movil.md`, `ajustes.md`, `rendimiento.md`; probado en Studio en PC el 02-11-2026; el HUD táctil, sin probar aún con el emulador de teléfono). Mapa por partes (StreamingEnabled) preparado pero apagado: antes hay que poner Atomic los bichos (ver `rendimiento.md`)

### Pendientes para Studio (de lo más importante a lo menos)
Cómo empezar: en Edit, que Rojo ha sincronizado (buscar un texto nuevo en el `Source` con `execute_luau`); errores con
`LogService:GetLogHistory()` sin los `MessageOutput`; en Server, `game.ServerStorage.Prueba:Fire("Noche")`. Parar el
Play al acabar.

Lo que puede romper una partida o atascar al jugador:
1. Escenas finales y escondites (14.9), probado con un jugador el 04-11-2026 (bien, también la mirilla con el tutorial y sustos seguidos); falta lo de dos jugadores: el fuego con alguien escondido y el fuego cancelado (la cámara no se congela),
   no esconderse en la escena (sí durante el fuego), el susto justo antes de la escena, `EscenaFinal` que vuelve a nil, nadie revive en un
   final. `docs/sistemas/partida.md`, "Muerte y finales", Probar en Studio.
2. Arreglos de la revisión del código de la rama `claude/admiring-bell-jvgvch` (commits `d34e9d8` y `0b979c2`, ya
   solo en el squash de la PR 24). Probado en Studio el 04-11-2026, todo bien y sin errores: morir todos justo antes de
   anochecer (vuelve al día, sigue la noche 1), sin botón de reiniciar, dos bichos a la vez (se acercan juntos sin
   tirones), bengala a la cabeza de la Bestia (acierto y cojea), fuego cancelado (0 fuegos en el cliente), "Wait for
   her" con el Carpintero (`Config.Test.Clase`; la ventana reforzada sigue a 212,5 y nada más cambia). Falta: dos
   jugadores clavando la misma ventana (Clients and Servers) y la mochila grande al volver (pide un pase de verdad:
   publicado).
3. Revisión entera del 03-11-2026 (14 commits "arreglos de la revisión", los pasos en cada uno): el Acechador no va a
   por quien está en la torre, las esquinas o el garaje; las cerillas no se pierden si amanece con el fuego; no se coge
   nada a través de las paredes del garaje; los bichos no pillan a través de paredes pero sí por una puerta abierta;
   teclas V (revivir), K (saltar tutorial) y P (ajustes) en PC. Probado en Studio el 04-11-2026, todo bien y sin
   errores: el Acechador no sale en la torre, la esquina, el garaje ni el lavadero (en el bosque sí, a los 9 s); cerillas
   que siguen tras prender de verdad y amanecer a mitad; el bidón y la cadena del garaje no se cogen desde fuera (el
   cartel sí sale a través de la pared, pero E no hace nada); a través de la pared no pilla en 8 s y por el hueco de la
   puerta al momento (hoja abierta con `CanQuery` false, cerrada true); P abre y cierra los ajustes; K dos veces salta
   el tutorial (la primera pregunta). Falta la V (revivir), que pide dos jugadores.
4. Muerte con el bicho que pilla: la escena enfoca al que gatea; morir gateando deja `Gatea` a nil; tras revivir vuelve a
   tardar en olerte. `bichos.md`, "Probar en Studio", pasos 5 y 6. Probado con un jugador el 04-11-2026 (bien, sin
   errores): el Golpeador gatea y pilla a los 2 s, la escena le enfoca (12°, 2,7 studs) y se queda en el suelo en el
   susto; con `Health = 0` mientras gatea, `Gatea`/`GateaHora` a nil en 0,09 s. Falta con dos jugadores: que siga su
   ronda tras matar a uno, volver a tardar en olerte tras revivir (con uno solo se revive al amanecer, sin bichos) y
   dos bichos que no gatean por el mismo borde (el Raspador no llegó a la mesa).
5. Correr con los bichos: perseguido por cada uno, el ruido, escondido cansado, morir corriendo, el remote a lo bruto.
   `correr.md`, "Probar en Studio", pasos 2, 8, 9 y 12.
6. Caminos de los bichos (`Caza`): sin tirones, recalcula en ≤1 s si algo tapa, sin errores al amanecer; y las puertas
   con llave tras `Prueba:Fire("Abrir")`, que un bicho abre enseguida. `bichos.md`, pasos 12 y 13.
7. Coche del lobby: el que llega (no choca con los otros, sin "Get in"), salida que pasa a llegada, carril ocupado, y
   el que no sale o llega con alguien de pie en su plaza (lo aparta, sin lanzarlo). `lobby.md`, "Probar en Studio",
   desde "Coche que llega". Tras un viaje el coche vuelve a quedar libre: solo publicado.

Lo que se ve mucho:
8. Gateos de los cinco bichos, a mano y de verdad (comedor y cocina, en diagonal, la Bestia bajo las dos mesas y
   saliendo andando, garras del Golpeador, codo del Raspador, Trepador, luz de la Bestia, NaN). `bichos.md`, pasos 2-4,
   7-10 y 14; el cuerpo debajo de las mesas, `manos.md`, "Esconderse agachado: el cuerpo".
9. Tutorial (`Config.Test.Tutorial = true`, sin subirlo), con el paso de correr, y que Sergio lo apruebe.
   `tutorial.md` y `correr.md`, paso 10.
10. Móvil: emulador 640 × 360 e iPhone (rejilla, barra del aguante, avisos, revivir, ajustes, textos en singular), el
   móvil escondido y la mochila por la mirilla. `movil.md` y `mochila.md`, "Probar en Studio"; `correr.md`, paso 6.
11. Correr en PC, con mando y con dos jugadores (cámara, manos y linterna, resoplidos que se callan en la escena).
   `correr.md`, pasos 1, 3-5, 7, 11 y 13.
12. Lobby nuevo: niebla, lluvia, luces que fallan, la puerta, coches, cinemática de salida, la sombra, dos jugadores,
   Rendimiento, emulador de móvil y el sonido de la llegada (Id 0 hoy). `lobby.md`, "Probar en Studio".
13. Cinemáticas: mochila y móvil se cierran en la huida, la flecha del tutorial por la mirilla, la linterna del otro en
   la escena, sustos seguidos que devuelven la mirada. `partida.md`, último punto de "Probar en Studio".
14. Respiración contenida, escondites vistos desde fuera y la casa que reacciona más (mecedoras, efectos sin errores).
   `manos.md`, al final, y `bichos.md`, paso 12.
15. Vida de espera de los seis bichos, el Imitador en la mirilla y Rendimiento a 120 studs. `bichos.md`, pasos 1 y 11.

Retoques a ojo:
16. Poses de gateo de los cinco bichos, rapidez de los tirones y ruidos (`bichos.md`, "Pendiente" y "Números a ojo");
   las manos (`manos.md`, "Si algo se ve mal").
17. Números de correr (`correr.md`, "Números a ojo para mirar en Studio") y de la llegada al lobby (`lobby.md`,
   "Números a ojo").

### 14.6 Animaciones en primera persona (pedido por el usuario, 03-11-2026: "que se vea cómo lo abres con las manos… todas las animaciones posibles", "que todo esté animado y sea inmersivo")
- **Estado:** hecho sin Studio (`docs/sistemas/manos.md`): tus manos en todo lo que haces, los brazos y la mirada de los demás, cámara con cuerpo, vaho, entrada suave al escondite, vendedor que te mira. Falta verlo y retocar las poses en Studio.
- **Segunda tanda (03 y 04-11-2026):** hecho: respiración contenida en el escondite, ver esconderse a los demás, la casa que reacciona más (mecedoras, vajilla, polvo, corriente), agacharse y asomarse (botón también en el móvil), manos en la pared, mirilla y cortinas (probados en Studio el 03-11-2026), y bichos con más vida mientras esperan y esconderse agachado debajo de las mesas con los bichos que huelen y gatean (`manos.md` y `bichos.md`; sin Studio). Tropezar y frenar al correr cansado: hecho en la 14.8.

### 14.7 Lobby nuevo (pedido por el usuario, 03-11-2026: "es un poco feo")
- Gasolinera vieja de noche por código, al nivel de la casa y el pueblo: tienda por dentro, marquesina, surtidores, cartel GAS que falla, cabina, coches viejos, bosque y carretera en la niebla; lluvia, relámpagos, luces que fallan, puerta automática, faros y limpias, polillas, algo entre los árboles; cinemática de salida del coche (`docs/sistemas/lobby.md`).
- **Estado:** hecho, revisado con `reviewer` y con CochesUi y TiendaUi al estilo oscuro; probado en Studio en parte el 03-11-2026 (tienda, coche, cinemática, bajarse). Falta: emulador de móvil, dos jugadores, la sombra y Rendimiento (`lobby.md`, "Probar en Studio"), y 6 sonidos de ElevenLabs (`Config.SonidosLobby`).

### 14.8 Correr y aguante (pedido por el usuario, 04-11-2026: "añadir la mecánica de correr, que tengas una stamina abajo del todo, una barra fina así minimalista que aparezca al correr")
- **Controles:** mantener Shift izquierdo en PC, L3 en el mando y botón CORRER en el móvil (en `Hud.EquipoBotones`, junto a AGACHARSE). Solo se corre moviéndose. Shift no activa el Shift Lock.
- **Aguante:** más rápido que andar (16 → 24) durante ~6,5 s seguidos; vuelve tras ~1 s sin correr, más deprisa quieto o agachado. Agotado del todo: no se corre hasta recuperar un tercio, frenas un momento, jadeas y a veces tropiezas (la cámara cae y te recuperas).
- **Cuándo no:** agachado (si cabes de pie, correr te levanta), cargando algo pesado, con la mochila abierta, trabajando, escondido, por la mirilla o las cortinas, asomado ni en cinemáticas.
- **Servidor manda:** remote `Correr` (sí/no), reglas puras en `shared/CorrerReglas` (con pruebas de Lune), aguante en atributos del Player, velocidad solo en `Cargar.ajustarVelocidad`.
- **Barra:** abajo del todo y centrada, muy fina, blanco desgastado; sale al correr o sin llenar y se va ~1,5 s después de llenarse; rojo oscuro con poco, late agotado. Bajo el `UIScale` del HUD, por encima de la zona segura, fuera en cinemáticas, mirilla y muerte. Banco de Lune.
- **Que se note:** cámara (balanceo, campo de visión, sacudida al frenar), manos que bracean y linterna que tiembla, los demás se ven correr, pasos más seguidos y fuertes, los bichos te oyen desde más lejos, jadeo y vaho, contener la respiración dura menos si te escondes cansado. Sonido nuevo `Jadeo` (Id 0; mientras, uno provisional). Con Rendimiento, sin campo de visión ni balanceo extra.
- **Equilibrio:** cuentas de persecución con Lune contra Golpeador (17), Bestia (19) y Acechador (21): sirve para escapar un trecho o llegar a la luz, no para dejar atrás a todos siempre. Paso corto en el tutorial si encaja.
- **Estado:** hecho sin Studio (`docs/sistemas/correr.md`): reglas y cuentas con Lune, bancos de la barra, la cámara y las manos con un Roblox de mentira (`tests/bancos`), revisado con `reviewer`. Paso nuevo del tutorial (3/9). Falta verlo en Studio y el sonido `Jadeo` de ElevenLabs.

### 14.9 Pulido general (propuesto por Claude, 04-11-2026)
- **Estado:** hecho sin Studio (04-11-2026). Revisión final en dos rondas, por áreas y por enfoques, verificada a la
  contra: 0 GRAVE; los MEDIO arreglados (cámara congelada al salir del escondite durante el fuego, el móvil escondido,
  el coche del lobby que reaparece encima de alguien) y los LEVE también. Falta verlo en Studio (arriba).
1. Revisión de pulido por áreas con agentes (leer y apuntar, verificar cada hallazgo y arreglar): textos sin `Lang` o sin español y avisos de más de una línea; cosas a medias y warns de la Salida; botones que se tapan en el móvil (también con la barra nueva); lo que no se devuelve tras una cinemática y conexiones sin desconectar; coste por fotograma de los bichos (gateo y vida de espera solo cerca de la cámara). — hecho (`movil.md`; lo de cada área en su doc: `datos.md` los textos, `partida.md` las cinemáticas y los finales, `bichos.md` el coste)
2. Deudas del gateo (`bichos.md`, "Pendiente"): `Muerte.matar` manda el modelo que pilla (fuera la heurística de `quienPilla`); `cajaTablero` de Golpeador, Imitador y PosturaVista juntas en `MuebleRayo.tablero` y el Imitador con `MuebleRayo` en sus rayos de reserva; olvidar el olor del que muere (al morir, `Muerte.alMorir`) y mirar si sigue vivo al gatear (`Muerte.vivo`); luz floja en la cara de la Bestia al gatear. Bancos de Lune: los gateos no atraviesan la mesa. — hecho (`bichos.md`, banco `tests/bancos/gateo.luau`)
3. Lobby: que llegue un coche conduciendo cuando uno se va (ahora reaparece de golpe), con su banco de Lune. — hecho (`lobby.md`, banco `tests/bancos/lobby-coche.luau`)
4. Sonidos e imágenes que faltan: `docs/sistemas/sonidos-pendientes.md` con el texto para ElevenLabs de cada uno y el de ChatGPT para la mano de sangre. — hecho (`sonidos-pendientes.md`)
5. Ritmo y economía (skill `roblox-economy-balancing`): repaso de días, noches, monedas y precios con una partida típica simulada en Lune; propuesta a ojo para la 14.5. — hecho (`economia.md`, banco `tests/bancos/economia.luau`)
6. Ordenar "Pendientes para Studio" de lo más importante a lo menos. — hecho (arriba)

### 14.5 Partida entera de prueba
- Una partida de principio a fin sin órdenes de prueba: ritmo de días y noches, monedas y precios (skill `roblox-economy-balancing`), fallos que salgan.
- **Estado:** pendiente

### 14.10 Golpeador en 3D: mejor susto y sucesos al azar (pedido por el usuario, 05-11-2026)
- **Hecho:** el Golpeador sale en la partida con el modelo 3D (`docs/sistemas/bichos-3d.md`).
- **Susto (screamer), pedido por el usuario: "hay que mejorar el screamer".** Ahora es la cámara fija 1,8 s en su cara
  con temblor y rojo. Propuesta:
  1. Mandíbula de verdad: añadir un hueso `Jaw` en `tools/blender/preparar_bicho.py` (la mandíbula de abajo pesada a
     él) y volver a subir el modelo, para que la boca se abra del todo al pillarte (ahora no se mueve).
  2. Que se te tire encima: empieza a su distancia real, quieto un instante mirándote, y de golpe se abalanza; las
     garras entran por los lados de la pantalla y la cabeza da tirones rápidos a un lado y a otro.
  3. Al final, un tirón hacia él y corte a negro de un fotograma con un chillido propio (sonido nuevo de ElevenLabs,
     `GritoGolpeador`), en vez del susto común.
  4. Si te pilla gateando: la mano te agarra desde debajo del mueble y te arrastra fuera antes de la cara.
- **Sucesos al azar del bicho (pedido por el usuario).** Que no sea siempre igual; el servidor decide (Caza, con
  probabilidades en `Config`), el cliente lo anima por atributos. Nunca injusto: mirarte no te mata. Cada suceso, como
  mucho una vez por noche y bicho. Ideas, de más a menos importante:
  1. **Te mira en el armario** (pedido por el usuario): si pasa cerca del armario donde estás escondido sin saberlo, se
     para delante, gira la cabeza hacia las rendijas y te mira fijo unos segundos respirando (vaho si hace frío);
     luego se va. Contener la respiración ahí debe dar miedo de verdad.
  2. **Olfatea:** en una sala se para, levanta la cabeza y huele hacia donde estás (sonido de olfateo), y sigue.
  3. **Llama despacio:** en vez de aporrear la ventana, tres golpes lentos con un dedo y espera (es "The Knocker");
     si alguien abre o se asoma, entra.
  4. **La cara en el cristal:** fuera, pegado a una ventana sin persiana mirando dentro; si le das con la linterna o le
     miras un rato, se aparta de golpe.
  5. **Finge que se va:** se aleja hacia el bosque, se para a medio camino, gira la cabeza y vuelve corriendo.
  6. **Garras por la pared:** al pasar por un pasillo, arrastra las garras por la pared o la puerta de tu cuarto.
  7. **Se queda quieto en lo oscuro:** si lo descubres con la linterna al fondo del pasillo, no se mueve unos segundos
     (solo la cabeza se ladea crujiendo) y luego viene a por ti.
- **Estado:** pendiente (pensar con Sergio cuáles primero; números a ojo).
