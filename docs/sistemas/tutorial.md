# Tutorial de los primeros minutos (14.2 / 13.1)

Propuesta de Claude hecha sin poder ver el juego (sesión en la nube, 03-11-2026): **falta que Sergio la pruebe y la apruebe en Studio**. Pedido por el usuario en el primer juego: muy visible, flecha grande, pasos cortos y premio al acabar.

## Cómo va

- Sale una vez por cuenta, hasta acabarlo (premio) o saltarlo (SALTAR, dos toques; sin premio). Se apunta en `logros.Tutorial` de los datos del jugador: no hace falta subir la versión del guardado.
- Pasos (`shared/PasosTutorial`, probados con Lune):
  1. Abrir la mochila (B, botón MOCHILA o cruceta arriba).
  2. Coger un hacha (hay una junto al caballete y otra en el lavadero).
  3. Correr al bosque (14.8, pedido por el usuario: "añade al tutorial un paso corto para correr si encaja"): Shift,
     L3 o CORRER según el dispositivo, y que correr hace ruido. Se acaba al correr un momento (el servidor mira el
     atributo `Corriendo`); se salta si ya había corrido desde que empezó el tutorial o si ya lleva un tronco o un
     tablón. La flecha va al árbol en pie más cercano y, en el móvil, también al botón CORRER (`docs/sistemas/correr.md`).
  4. Talar un árbol y cargar un tronco (vale también uno de los que ya hay delante de la casa).
  5. Serrarlo en el caballete y coger un tablón.
  6. Arrancar el generador del cobertizo.
  7. "No te alejes de la casa. Se acerca la noche." hasta que se pone el sol.
  8. Al ponerse el sol (`Config.Ciclo.Aviso` s antes), cerrar las cortinas de abajo ("quedan 3").
  9. Aguantar hasta el amanecer (la flecha señala el escondite más cercano). Al amanecer: `+100 monedas` (logro `Tutorial` de `Config.Recompensas`, a ojo), solo si esa noche se llegaron a cerrar todas las cortinas de abajo; si no, sigue la noche siguiente. Quedarse quieto no da el premio (las cortinas las puede cerrar un amigo: es cooperativo).
- 16.5 (hallazgos del análisis, propuesta de Claude):
  - Puerta principal: en el paso 8 cuenta como una cortina más si está abierta (abierta, el primer golpe del bicho ya entra) y la flecha la señala ("Cierra la puerta principal y las cortinas de abajo: quedan 3"; si solo queda ella, "Cierra la puerta principal.").
  - Gasolina: la partida empieza con el 30 % del depósito y se gasta también de día, así que con el generador arrancado hacia el minuto 2 la luz se iba a mitad de la noche 1. Ahora el paso 6, con el generador en marcha y menos de `Config.Tutorial.Gasolina` (0,45, a ojo), pide "Llena el generador: llévale un bidón de gasolina." (flecha al bidón con gasolina más cercano; con él en las manos, al generador). Se da por hecho al llegar al mínimo o al subir el depósito. Si no queda ningún bidón con gasolina, no se pide. Mismo número de paso (atributo `TutorialGasolina`).
  - No empieza mientras dura la escena de llegada en coche (`EscenaLlegada` de workspace a `true`).
  - Siguiente meta: quien ya no tiene tutorial (acabado o saltado) recibe al empezar cada día (y al entrar) un aviso de una línea con la siguiente meta, de más cerca a más lejos: llave del sótano (granja), llave del garaje (aserradero), "repara el coche: faltan {n} piezas", su gasolina y "el coche está listo". La misma frase sale arriba en la pantalla del móvil (atributo `Meta` del jugador, MovilUi). Nada fijo en pantalla. Cuentas en `PasosTutorial.meta` (banco `tests/bancos/tutorial-meta.luau`).
  - Probar en Studio: con `Config.Test.Tutorial`, dejar la puerta abierta al anochecer (la flecha va a ella), arrancar el generador y ver que pide el bidón; sin el tutorial, al empezar el día sale el aviso de la meta y el móvil (M) la enseña arriba.
- Lo ya hecho se salta solo (el generador ya encendido, el hacha ya en la mochila, un tablón en las manos). Al anochecer se dejan los pasos del día que falten. Si mueren todos y vuelve el día, se vuelve a lo del día que falte.
- Quien entra de noche o en una partida avanzada también lo tiene: empieza por las cortinas.

## Quién hace qué

- Servidor (`juego/servidor/Tutorial`): cada `Config.Tutorial.Cada` s mira a cada jugador con tutorial y publica `Tutorial` (el paso) y `TutorialFalta` (cortinas) en el `Player`. Todo lo que da premio lo mira el servidor. Remote `Tutorial` ("Saltar").
- Cliente (`juego/cliente/TutorialVista`): cartel de papel arriba en el centro (paso "3/9", frase, SALTAR), flecha roja grande sobre lo más cercano que pide el paso (a través de las paredes) con contorno, flecha en el borde de la pantalla si no está delante y, en el móvil, flecha sobre el botón MOCHILA. Suena `Papel` al pasar de paso. Las cinemáticas lo esconden con el resto (está en `PlayerGui`).
- En Studio solo sale con `Config.Test.Tutorial = true`.

## Guía del lobby (16.7)

El tutorial solo cubre la partida. Lo del lobby (llegar al coche, y tras la primera partida la tienda con su primera clase
gratis) lo hace una guía aparte, con su flecha y una línea: ver `lobby.md`.

## Por decidir con Sergio

- Si le convence el orden y las frases; si quiere un paso de clavar tablones (ahora no: al empezar no hay nada roto que reparar) o de la linterna.
- El premio (100 monedas a ojo; una clase cuesta 400 y la primera es gratis).
- Una flecha con imagen subida en vez de la hecha con marcos.
