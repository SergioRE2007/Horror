# Diseño del juego (octubre de 2026)

Ideas de Sergio y propuestas de Claude que aceptó. "Pedido por el usuario" = no cambiarlo sin preguntarle. Números a ojo, se ajustan al probar. Por decidir más adelante: nombre del juego, aspecto de los bichos, tutorial, recetas y piezas exactas.

## Idea general

- Terror cooperativo con amigos (1-4, lo normal 2), estilo "99 Nights in the Forest": una partida larga de muchas noches seguidas, cada una más difícil (pedido por el usuario). Sustituye a la idea inicial de "5 noches + modo infinito".
- De día se farmea y se explora; de noche se defiende la casa. No debe ser solo sobrevivir (pedido por el usuario).
- Todo muy interactivo y bien animado (pedido por el usuario): casi todo lo de la casa y el mapa se puede tocar (puertas, persianas, cajones, armarios, interruptores, el generador que arranca tirando de la cuerda…), cada acción con su animación del personaje y del objeto (talar con golpes que astillan, clavar tablones martillo a martillo, persianas que bajan con traqueteo, cristales que se agrietan poco a poco) y su sonido. Nada que aparezca o desaparezca de golpe.
- Estilo realista y oscuro (pedido por el usuario). Tope de contenido: etiqueta Moderate de Roblox, con sangre y algo de gore, sin llegar a Restricted (pedido por el usuario).

## Historia y finales (pedido por el usuario)

- Un rico te contrata para vigilar su casa en el bosque, muy bien pagado. Llegas en tu coche (cinemática al empezar) y la primera noche un bicho te lo destroza: no hay forma de irse.
- Giro (propuesta aceptada): con las pistas se descubre que el rico sabía lo que pasaba en la casa y te mandó a propósito.
- Final de la huida (el fácil): reparar el coche en el taller del garaje con piezas y recursos del bosque. Escena final con el bicho persiguiendo el coche.
- Final de matar al bicho (el difícil, pedido por el usuario): la Bestia es el origen de todos los bichos; muere en la casa quemándola, y con ella caen todos. Pide haber abierto casi toda la casa. Detalle en la tarea 12.2 de `TASKS.md`.
- Sin límite de noches: cada noche más difícil empuja a terminar. Cada final da recompensa e insignia propias.

## Ritmo

- Día ~3 min y noche ~4 min. Al ponerse el sol suena un aviso.
- Hitos que sorprenden en ciertas noches (ejemplos): noche 3 llega el Raspador, noche 7 el Trepador, noche 10 el Imitador y se va la luz…
- Dificultad pensada para 2 jugadores y ajustada a 1, 3 y 4 (pedido por el usuario), con una tabla en `Config`. Se calcula al empezar cada noche:

  | | 1 | 2 | 3 | 4 |
  |---|---|---|---|---|
  | Ataques a la vez | 1 | 2 | 2-3 | 3 |
  | Ritmo de ataques | más lento | normal | algo más rápido | rápido |
  | Paciencia antes de entrar | más larga | normal | normal | más corta |
  | Tareas del día | menos | normal | más | más |

- Quien muere mira a los demás hasta el amanecer y revive de día. La noche no se facilita al morir alguien.

## Bichos

- Propios pero inspirados en el estilo de Trevor Henderson (gigantes, raros, mezcla de cosas normales con carne). Nunca los suyos: tienen derechos de autor y Roblox borra juegos así. Salen por olas, cada vez más difíciles (pedido por el usuario).
- De carne y hueso, nada de animatrónicos: sangre, carne abierta y algún órgano a la vista (pedido por el usuario). Para no pasar de Moderate se ven sobre todo en penumbra, de lejos o un instante. Muy bien animados (pedido por el usuario). Su aspecto se decide casi al final; las mecánicas sirven ya.
- Modelos con IA de imagen a 3D a partir de dibujos de ChatGPT (ver `CLAUDE.md`).

| Bicho | Sale | Cómo se reconoce | Defensa |
|---|---|---|---|
| Golpeador (pedido por el usuario) | noche 1 | Golpes graves, puertas y ventanas tiemblan | Persianas cerradas y tablones hasta que se canse |
| Raspador (pedido por el usuario) | noche 3 | Chirrido lento en el cristal; no soporta la luz | Abrir la persiana y darle un flashazo |
| Trepador | noche 7 | Pasos y crujidos en el tejado | Encender la chimenea con madera |
| Imitador | noche 10 | Llama a la puerta como si fuera un amigo | Mirar en el móvil si ese amigo está fuera de verdad; si se le abre, entra |
| Acechador | al anochecer | Ramas que crujen en el bosque | Volver a la luz; la linterna lo frena un momento |
| La Bestia | final difícil | El origen de todo | Solo en el final |

- Si un bicho entra: unos segundos para esconderse (armario, debajo de la cama) con latido y respiración. Si te pilla: susto en pantalla y mueres.
- Si abres la persiana al Golpeador, entra.

## El día

- Talar árboles: madera para tablones (en las ventanas aguantan al Golpeador, pero no dejan abrir la persiana para el Raspador) y para la chimenea.
- Reparar cristales, puertas y persianas rotas por la noche.
- Generador en un cobertizo pegado a la casa: hay que llenarlo de gasolina. Sin gasolina no hay luz ni enchufe.
- Pilas para la linterna y carretes para el flash: se encuentran o se cambian al vendedor.
- Trampas fuera: latas colgadas que suenan y avisan de por dónde viene algo.
- Pistas de la historia: notas, fotos, diario.
- Cuanto más lejos de la casa, mejores recursos y más peligro si se hace de noche.

## Mapa (pedido por el usuario: todo con sentido, nada "por la cara")

- Casa del rico al final de una carretera de tierra. Antes era del dueño del aserradero.
- Aserradero viejo, con herramientas, tablones y piezas.
- Pueblo abandonado (se vació por las desapariciones): iglesia con cementerio, tienda, casas cerradas. Solo queda el vendedor, que avisa ("no salgas de noche", "no te quedes en la casa del rico") (pedido por el usuario).
- Granja con su campo, cabaña del cazador en el bosque espeso, torre del guardabosques en una colina, lago con embarcadero.

## La casa

- Grande, de madera, antigua y medio podrida (pedido por el usuario). Dos plantas, sótano y desván.
- Abiertas desde el principio: recibidor (puerta principal), salón con chimenea y ventanales (centro de la casa), cocina con despensa (algo de comida al empezar), 2 dormitorios con camas y armarios, baño y cuarto de la limpieza con el enchufe del móvil.
- Salas cerradas con llave (pedido por el usuario), de más cerca a más lejos:

| Sala | Llave en | Qué tiene |
|---|---|---|
| Sótano | granja | Banco de carpintero: tablones reforzados, cerrojos, trampas |
| Garaje | aserradero | Taller y primeras piezas del coche |
| Desván | torre del guardabosques | Cuarto de revelado del rico: mejoras del flash y fotos de la historia |
| Habitación del rico | cementerio | Diario, caja fuerte y cómo matar al bicho |

- Cada llave sale al azar entre varios sitios de su zona en cada partida, con un brillo flojo para verla de lejos. Si mueres con una llave, se cae donde mueres.

## Objetos

- Móvil (pedido por el usuario): mapa con dónde estáis tú y tus amigos. Gasta batería y se carga en el enchufe de la casa (necesita el generador).
- Linterna con pilas que se compran o se encuentran (pedido por el usuario). Con poca pila parpadea.
- Cámara con flash para el Raspador.
- Mochila de casillas estilo Resident Evil 4 (pedido por el usuario; tamaños de Claude): se abre con la B (botón en móvil); el personaje se quita la mochila y la cámara se acerca. Rejilla de 6×8, ampliable a 8×10. Girar con R. Ejemplos: pila, lata, móvil y llave 1×1; botella y linterna 1×2; cámara 2×2; hacha 1×3.
- Lo grande va en las manos con física y frena: troncos, tablones, bidón, piezas del coche. Lo más pesado (el motor) entre dos.
- Vendedor: trueque, pide comida y agua a cambio de sus cosas (pedido por el usuario). La comida y el agua se encuentran en casas, la granja o pescando. Al principio los jugadores no tienen hambre.

## Clases y monedas

- Clases tipo 99 Nights que se compran con monedas (pedido por el usuario), una por jugador y partida:
  - Leñador: tala más rápido y saca más madera.
  - Corredor: corre más y se cansa menos.
  - Fotógrafo: el flash recarga antes y aturde más.
  - Mecánico: repara coche y puertas más rápido.
  - Carpintero: sus barreras aguantan más.
  - Explorador: ve las llaves desde más lejos.
  - Más adelante, quizá niveles por clase.
- Monedas: se ganan con noches superadas, finales, logros y premio diario, y se compran con Robux (pedido por el usuario). La primera clase es gratis y otra se consigue en pocas partidas: pagar solo acelera.

## Robux

- Revivir de noche (~25 R$), también pagando por un amigo, máximo 1 por noche.
- Paquetes de monedas.
- Cosméticos sin ventaja: pinturas del coche, linternas y cámaras de colores, ropa, efectos del flash.
- 3-4 pases: mochila grande, más ranuras de partida, linterna mejor al empezar, paquete de inicio.
- Nada de servidores privados: ya entras con tus amigos desde el lobby (decidido por el usuario). Nunca vender llaves, piezas ni noches, ni cajas al azar con Robux.

## Lobby, grupos y guardado

- Lobby: gasolinera vieja de noche junto a la carretera del bosque, con lluvia y cartel que parpadea. Te subes a un coche con tus amigos, el dueño elige partida y arrancáis (cinemática del coche entrando en el bosque). La tienda, dentro de la gasolinera.
- Teletransporte a un servidor privado solo para el grupo.
- La partida (la casa) es del que la crea, con 2-3 ranuras por jugador. Guarda la noche, la casa, los recursos, las salas abiertas, el coche y las pistas. Se guarda al amanecer; si morís todos o salís, se vuelve al principio de ese día.
- No se puede entrar a una partida empezada: el dueño la inicia con su grupo. Si el dueño se va, se acaba para todos y queda el último amanecer (pedido por el usuario). Propuesta: esperar ~60 s por si es un corte de conexión.
- Monedas, clases, cosméticos, récords y logros son de cada jugador.

## Interfaz, móvil y sonido

- Interfaz oscura y minimalista con alguna esquina con sangre (ver `CLAUDE.md`).
- Móvil desde el principio (pedido por el usuario): un botón grande de acción que cambia según lo que tengas delante; pocos botones fijos (linterna, mochila, móvil) abajo a la derecha, nada arriba a la derecha; mochila tocando para coger y soltar, con botón de girar; botón de coger y soltar lo pesado; mapa por partes (StreamingEnabled) y modo Rendimiento.
- Sonido con ElevenLabs:
  - 3D: cada bicho suena desde su ventana, apagado tras las paredes.
  - Ambiente por capas: viento en bucle y sonidos sueltos al azar (búhos, ramas, aullidos). Nunca ambientes de una pieza.
  - La casa cruje sola. Pasos según el suelo (madera, hierba, barro, agua).
  - Latido y respiración al esconderse. Casi sin música, solo zumbidos de tensión. Sustos fuertes pero pocos.
  - Avisos visuales discretos para quien juega sin cascos (persiana que tiembla, polvo que cae).
  - Chat de voz por cercanía. Más adelante, quizá bichos que oyen las voces.
- Tutorial: se diseña casi al final, cuando el juego esté hecho (pedido por el usuario).
