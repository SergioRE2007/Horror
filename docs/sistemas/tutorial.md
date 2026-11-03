# Tutorial de los primeros minutos (14.2 / 13.1)

Propuesta de Claude hecha sin poder ver el juego (sesión en la nube, 03-11-2026): **falta que Sergio la pruebe y la apruebe en Studio**. Pedido por el usuario en el primer juego: muy visible, flecha grande, pasos cortos y premio al acabar.

## Cómo va

- Sale una vez por cuenta, hasta acabarlo (premio) o saltarlo (SALTAR, dos toques; sin premio). Se apunta en `logros.Tutorial` de los datos del jugador: no hace falta subir la versión del guardado.
- Pasos (`shared/PasosTutorial`, probados con Lune):
  1. Abrir la mochila (B, botón MOCHILA o cruceta arriba).
  2. Coger un hacha (hay una junto al caballete y otra en el lavadero).
  3. Talar un árbol y cargar un tronco (vale también uno de los que ya hay delante de la casa).
  4. Serrarlo en el caballete y coger un tablón.
  5. Arrancar el generador del cobertizo.
  6. "No te alejes de la casa. Se acerca la noche." hasta que se pone el sol.
  7. Al ponerse el sol (`Config.Ciclo.Aviso` s antes), cerrar las cortinas de abajo ("quedan 3").
  8. Aguantar hasta el amanecer (la flecha señala el escondite más cercano). Al amanecer: `+100 monedas` (logro `Tutorial` de `Config.Recompensas`, a ojo), solo si esa noche se llegaron a cerrar todas las cortinas de abajo; si no, sigue la noche siguiente. Quedarse quieto no da el premio (las cortinas las puede cerrar un amigo: es cooperativo).
- Lo ya hecho se salta solo (el generador ya encendido, el hacha ya en la mochila, un tablón en las manos). Al anochecer se dejan los pasos del día que falten. Si mueren todos y vuelve el día, se vuelve a lo del día que falte.
- Quien entra de noche o en una partida avanzada también lo tiene: empieza por las cortinas.

## Quién hace qué

- Servidor (`juego/servidor/Tutorial`): cada `Config.Tutorial.Cada` s mira a cada jugador con tutorial y publica `Tutorial` (el paso) y `TutorialFalta` (cortinas) en el `Player`. Todo lo que da premio lo mira el servidor. Remote `Tutorial` ("Saltar").
- Cliente (`juego/cliente/TutorialVista`): cartel de papel arriba en el centro (paso "3/8", frase, SALTAR), flecha roja grande sobre lo más cercano que pide el paso (a través de las paredes) con contorno, flecha en el borde de la pantalla si no está delante y, en el móvil, flecha sobre el botón MOCHILA. Suena `Papel` al pasar de paso. Las cinemáticas lo esconden con el resto (está en `PlayerGui`).
- En Studio solo sale con `Config.Test.Tutorial = true`.

## Por decidir con Sergio

- Si le convence el orden y las frases; si quiere un paso de clavar tablones (ahora no: al empezar no hay nada roto que reparar) o de la linterna.
- El premio (100 monedas a ojo; una clase cuesta 400 y la primera es gratis).
- Una flecha con imagen subida en vez de la hecha con marcos.
