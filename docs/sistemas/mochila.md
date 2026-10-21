# Mochila, objetos y cargar cosas pesadas (paso 4)

Con bloques grises y animaciones sencillas. Números a ojo, todos en `Config` (`Objetos`, `Mochila`, `Pesados`, `Cargar`).

## Rejilla (`shared/Rejilla`, sin Roblox, probada con Lune)

- Casillas de (1, 1) arriba a la izquierda. Cada cosa: `id`, `tipo`, `x`, `y`, `girada` y `carga` (pila de la linterna 0..1 o fotos de la cámara). El tamaño sale de `Config.Objetos[tipo].Tam`; girada cambia ancho por alto.
- `cabe`, `poner`, `meter` (primer hueco, fila a fila, primero sin girar), `mover` (si no cabe no cambia nada), `sacar`, `en` (qué hay en una casilla), `primera` (la de id más bajo: la linterna o cámara que se usa), `contar`, `gastar` (quita la última de un tipo).
- `desde(datos, catálogo, ancho, alto)` rehace una rejilla de datos que no son de fiar (lo guardado o lo que llega por la red): tira tipos desconocidos, recoloca lo que pisa o se sale y devuelve aparte lo que ya no cabe. Vale para una mochila más grande que la guardada.
- La clave de `Config.Objetos` es lo que se guardará (paso 6): no renombrar, lo nuevo al final.

## Servidor (`src/juego/servidor`)

- `Mochila` (pedido por el usuario, estilo Resident Evil 4): rejilla de 8×6 por jugador (ampliable a 10×8 con un pase, más adelante). Al empezar: linterna, cámara, 2 pilas y 1 carrete. Remote `Mochila`: ("Abrir", abierta), ("Mover", id, x, y, girada), ("Tirar", id); si un movimiento no vale, vuelve a publicar la rejilla y el cliente deshace. Atributos del jugador: `Mochila` (la rejilla en JSON), `MochilaAbierta` (velocidad 0, el mundo sigue), `Pilas`, `Carretes`. Se cierra sola al esconderse o morir.
- Objetos sueltos en `workspace.Objetos` (piezas con física, atributos `Tipo` y `Carga`, prompt "Pick up"). Los primeros, en `Mapa.objetos` (provisional: luego al azar con la semilla). Lo tirado sale delante del jugador con un empujón. Si no cabe: "No cabe en la mochila."
- La mochila a la espalda es una pieza (`Mochila` con su `Weld` `Union`) que ven los demás.
- `Equipo`: la linterna, la cámara, las pilas y los carretes son objetos de la mochila. Sin linterna no hay luz; sin cámara, no hay flash. La pila y las fotos van en la `carga` del objeto, así que viajan con él si se tira y lo coge otro. Cambiar pila o carrete gasta uno de la mochila. Con las manos ocupadas (cargando) no hay flash.
- `Cargar` (pedido por el usuario): troncos, tablones, bidón y motor en `workspace.Pesados` (primeros en `Mapa.pesados`, delante de la casa). Prompt "Carry". Cada uno que coge tira de su agarre con un `AlignPosition` que solo levanta `Cargar.Fuerza` (0,6) veces el peso: con todos los que pide el `Peso` se levanta; con menos, se arrastra por el suelo (el motor, entre dos). Uno solo: la lleva delante (lo largo, a lo largo; desde el paso 5 sin chocar con nada, ver `bosque.md`) y la simula su cliente. Entre dos: cada uno coge un extremo y la simula el servidor. Frena: ×0,6 una persona, ×0,5 entre dos, ×0,25 arrastrando; sin salto. Mientras se lleva no choca con los jugadores (grupos `Cargado` y `Personajes`). Se suelta sola al esconderse, morir o quedarse atascada a más de 9 studs. Atributo `Cargando` (el tipo).

## Cliente (`src/juego/cliente`)

- `MochilaUi`: B, botón MOCHILA en el móvil o cruceta arriba. Al abrir, una mochila de bloques sube delante de la cámara con la tapa abriéndose, la vista baja 16°, el campo se cierra y el fondo se oscurece con algo de desenfoque; la rejilla sale encima (panel oscuro con una esquina de sangre). Clic o toque en una cosa la coge (sale con borde claro donde iría, rojo si no cabe); clic en una casilla la deja; R o GIRAR la gira; G o TIRAR la tira; B, CERRAR o tocar fuera cierra. Las cosas altas llevan el nombre de lado. A los demás, su mochila les pasa de la espalda al pecho mientras la tienen abierta.
- La inclinación de la vista se deshace antes de la cámara de Roblox en cada fotograma (`MochilaVistaAntes`): la cámara parte de la del fotograma anterior y, sin eso, se iba sumando hasta mirar al suelo.
- `CargarVista`: con algo en las manos, "[E] SOLTAR" abajo (en el móvil, botón SOLTAR donde el de acción); la vista baja un poco y se balancea al andar.
- `Controles`: con las manos ocupadas o la mochila abierta no salen los carteles de coger o abrir.
- `Ui.mayusculas`: mayúsculas con tildes (string.upper dejaba "CáMARA").

## Probado en Studio (21-10-2026)

- Abrir y cerrar con la B (la vista vuelve igual), mover la pila, coger, girar y dejar la linterna; el servidor queda igual que lo pintado. Tirar con la G (cae a ~3 studs) y volver a cogerla con la E, con su pila. Sin linterna, la F avisa "No llevas linterna". Siete fotos: al acabarse, el carrete sale de la mochila.
- Tronco: delante a la cintura, sigue al andar a 9,6, se suelta con la E. Motor solo: se arrastra por el suelo a velocidad 4. Con un segundo agarre puesto a mano se levanta 1 stud; quitándolo, cae. Con las manos ocupadas no se abre la mochila ni hay flash. Esconderse con la mochila abierta la cierra.
- Lune: 163 comprobaciones bien.

## Pendiente

- Sin probar: dos jugadores de verdad con el motor, botones del móvil, la mochila con mando (abre y cierra, pero no se mueve por la rejilla).
- Lo que lleva un jugador que se va se pierde; al morir todos, lo gastado no vuelve (el guardado de la partida es el paso 6).
- Sin sonidos de coger, tirar ni abrir (llegan con ElevenLabs).
