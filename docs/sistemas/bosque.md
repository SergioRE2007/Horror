# Bosque, talar, tablones, generador y móvil (paso 5)

Con bloques grises y animaciones sencillas pero que se noten (pedido por el usuario). Números a ojo, todos en `Config` (`Talar`, `Generador`, `Movil`).

## El ciclo de la madera

Árbol → (hacha) 2 troncos → (caballete) 2 tablones → (clavar) persiana y cristal, o puerta, como nuevos. Antes se reparaba gratis; ahora hace falta un tablón por reparación (pedido por el usuario).

## Servidor (`src/juego/servidor`)

- `Mapa`: 45 árboles finos que se talan (etiqueta `Arbol`, entre 42 y 170 studs de la casa; los gordos del bosque no se talan), cobertizo pegado detrás de la casa (x 3..13, z 22.5..31, entrada por el este) con el generador (`Generador`), caballete delante a la izquierda (`Caballete`, -22, -32), enchufe en el cuarto de la limpieza (`Enchufe`) y un bidón en el cobertizo. Las lámparas empiezan apagadas (`Mapa.lamparas`). Lo que sale en el mapa del móvil lleva la etiqueta `EnMapa`.
- `Recursos`: con el hacha en la mochila, cada E en un árbol es un hachazo (0,65 s entre uno y otro, 5-7 para tumbarlo). Atributos del árbol: `Golpes`, `GolpesMax`, `Talado` (noche en que cayó). Cae girando sobre el borde del corte (bisagra con el tocón) hacia el lado contrario de quien tala; casi tumbado se suelta, y quieto en el suelo se parte en 2 troncos. Si se queda enganchado en otro árbol, a los 9 s se parte igual. Vuelve a crecer al amanecer 2 noches después. El caballete (R con un tronco): 3 s serrando y salen 2 tablones al lado.
- `Cargar`: además de llevar cosas, `Cargar.alUsar(tipo, uso)` = lo que se hace con lo que llevas en las manos (R): el objetivo tiene etiqueta y un `Mando`; mientras se trabaja la pieza se queda anclada en su sitio y el jugador quieto (atributo `Trabajando`); si muere o se esconde se deja a medias. Lo usan `Recursos` (Tronco → caballete), `Casa` (Tablon → ventana o puerta dañada) y `Generador` (Bidon → generador). `Cargar.nuevo(tipo, cf, carga)` crea cosas pesadas (el bidón con `Carga` = gasolina 0..1).
- Cambios en lo de cargar (21-10-2026): lo largo que lleva uno (troncos, tablones) va a lo largo hacia delante, y lo que lleva uno solo no choca con nada. Atravesado no cabía por las puertas y al girarse en una sala se atascaba en las paredes y se caía. Desde la 15.8 (pedido por el usuario) van al hombro y sí chocan, con un giro flojo (`mochila.md`).
- `Casa`: clavar un tablón (R llevándolo, 3,5 s): se clava por dentro en las ventanas y del lado del jugador en las puertas. El prompt "Reparar" sin tablón solo avisa "Trae un tablón para repararlo." Con las manos ocupadas no salen prompts, así que una puerta cerrada se abre de un empujón al ir hacia ella.
- `Generador` (pedido por el usuario: arranca tirando de la cuerda): E tira de la cuerda (40 % de arrancar, al tercer tirón seguido seguro) o, manteniendo E 1 s (`Apagar`), lo apaga; los 1,5 s después de arrancar (`Gracia`) no se puede apagar, para no apagarlo sin querer al seguir tirando. Depósito de 480 s, empieza al 30 %, un bidón lleno echa medio depósito (R, 3 s; si le queda gasolina vuelve a tus manos, vacío queda en los sacos de al lado). Gasta más con más jugadores (columna `Tareas` de `Config.Dificultad`). Sin gasolina se para. Las lámparas de la casa solo se encienden con él, con un parpadeo al arrancar y al pararse. Atributos del modelo: `Gasolina`, `Encendido`, `Tirones`, `Ahogado`, `Llenando`.
- Enchufe: E deja tu móvil en la repisa (sale de la mochila) y se carga en 60 s con el generador encendido (lucecita verde); se recoge con "Coger" con su batería.
- `Movil` (pedido por el usuario): el móvil es un objeto de la mochila (se empieza con uno). Mirarlo gasta batería (150 s la carga entera); se puede mirar escondido, no con las manos ocupadas. Atributos del jugador: `MovilAbierto`, `Bateria` (nil = no lleva) y `Donde` (x, z de cada jugador, para el mapa de los demás: de lejos su personaje puede no llegar al cliente).
- Modo de pruebas nuevo: `ServerStorage.Prueba:Fire("Romper", punto)` rompe la ventana o puerta de fuera más cerca.

## Linde del mundo (noviembre de 2026)

Antes el bosque acababa a ~420 de la casa y luego había llanura hasta el borde del suelo (±800): corriendo recto se caía al vacío y, sin reaparecer solo, se quedaba muerto hasta el amanecer. Números a ojo.

- `Linde` (sin Roblox, probado con Lune): contorno de 44 lados, círculo de 455 alrededor de la casa que en el sur se abre y rodea el pueblo (edificios, cementerio y calle) a 62 studs, más allá de su cinturón de pinos (55). Granja, aserradero, torre, carretera y el coche de la huida quedan dentro.
- `MapaBosque.linde` (carpeta `Bosque.Linde`, con su propio `Random`: no mueve pinos ni talables guardados): ~400 pinos espesos de 4 a 52 studs por dentro de la pared (sin pisar los del bosque, la carretera ni el pueblo), paredes invisibles de 40 de alto y, por fuera, ~350 troncos altos sin choque (una pieza cada uno, sin sombra) para que desde la pared solo se vea bosque y niebla.
- Grupo de colisión `Linde`: no choca con `Default` (los bichos la cruzan: el Acechador que nace a la espalda llega igual), sí con `Personajes` y `Cargado`. Agachado la para la raíz, que sigue en `Personajes` (el resto del cuerpo, en `Agachado`, no choca con nada, como siempre). Las paredes llevan `PathfindingModifier` con `PassThrough` y no tienen `CanQuery` (no tapan rayos ni vistas). Lo que se tira (`Default`) sí la cruza.

## Sendas a los sitios (`MapaSendas`, pulido)

- Antes solo había la carretera al pueblo y la meta del día mandaba a la granja, al aserradero y a la torre sin decir por dónde. Ahora salen tres sendas de tierra pisada: a la granja (del claro de detrás de la casa, al este, a la puerta de la casa de la granja), al aserradero (de la carretera hacia el oeste a z ≈ -80, a la nave) y a la torre (de detrás de la casa, por el este de la caseta del guarda, al pie de la escalera).
- Cada una: tiras de `Ground` algo más claras que el suelo (3,5 a 5 de ancho, curva Catmull-Rom con un punto cada ~7 studs, tres alturas que se turnan para que no parpadeen), un mojón cada ~30 studs (estaca vieja con un trapo rojo desvaído, a un lado y al otro) y al principio un poste sin letras con la tabla en flecha y el dibujo de bloques de adónde va (la X del granero, un disco de sierra, una torrecita). Nada choca ni hace sombra; las tiras llevan `EnMapa` (salen en el móvil).
- El bosque no pone pinos a menos de 4 del borde de una senda (el intento cuenta igual: los demás pinos no se mueven) ni sotobosque a menos de 3. Los talables no cambian (se guardan por su `Clave`): alguno puede quedar al lado de una senda.
- Banco: `tests/bancos/sendas.luau` (empiezan en el claro o la carretera, acaban en su zona, no pisan la casa ni lo de alrededor, tramos de 10 como mucho). Números a ojo.
- A la cabaña del cazador no va ninguna senda: se llega siguiendo 8 pinos con un corte de hacha desde la senda del aserradero (`LugarCazador`, carpeta `Bosque.Cazador` con su espesura; ver `llaves.md`).

## Cliente (`src/juego/cliente`)

- `TrabajoVista`: herramientas de bloques delante de la cámara (las tuyas) o del pecho (las de los demás). Hachazo con astillas, temblor del árbol y un corte de madera clara que se ahonda; golpe contra el suelo y astillas al partirse. Sierra que va y viene con serrín. Martillo con un clavo nuevo en cada golpe; el tablón se funde al final. Chorro de gasolina. Generador: la cuerda sale y vuelve con cada tirón; encendido tiembla, echa humo y suena; indicador de gasolina en el frente (rojo con poca).
- `CargarVista`: llevando algo, mirando a lo que sirve sale "[R] SERRAR / CLAVAR / ECHAR GASOLINA" junto a ello (en el móvil, un botón encima de SOLTAR). Muy cerca vale aunque no se mire de frente.
- `MovilUi`: M, botón MÓVIL o cruceta abajo. El teléfono sube abajo a la derecha: solo la batería arriba y el mapa (norte arriba, tú en el centro con una flecha hacia donde miras, la casa, el cobertizo, el caballete, el camino, los árboles talables y tus amigos con su nombre; los lejanos, pegados al borde). Sin batería, pantalla negra.
- Sonidos provisionales nuevos de la biblioteca: `Hachazo`, `Caida`, `Serrar`, `Martillo`, `Motor`, `Verter` (la cuerda usa `Persiana`).

## Probado en Studio (21-10-2026)

- Sin hacha: "Necesitas un hacha.". Con hacha: 5 hachazos, cae girando y se parte en 2 troncos junto al tocón.
- Tronco al caballete andando: sale "[R] SERRAR", 3 s y 2 tablones al lado.
- Ventana del salón rota con `Romper`: tablón cargado desde fuera (la puerta principal se abre sola al empujarla), "[R] CLAVAR", 3,5 s: vida 100, cristal entero, tablón gastado.
- Generador: arranca al primer tirón, lámparas encendidas; bidón del cobertizo: 0,3 → 0,8 y el bidón queda vacío al lado.
- Móvil: se abre con la M y gasta (~0,2 en 30 s); en el enchufe sube 1/60 por segundo con luz verde y se recoge con 0,98.
- Sin errores en consola. Lune: 182 comprobaciones bien.

## Pendiente

- Sin probar: herramientas de los demás (2 jugadores), botones del móvil (MÓVIL, SERRAR/CLAVAR), el generador parándose sin gasolina, que un árbol vuelva a crecer.
- El tablón reforzado da más vida (`taller.md`); falta que impida abrir la persiana al Raspador (idea del diseño).
- Desde el paso 6 se guarda al amanecer (árboles, gasolina, móvil del enchufe, lo suelto): ver `partida.md`.
