# Puertas que revientan

Mejora de inmersión (noviembre de 2026, pedido por el usuario: "mejorar la inmersión, tema interacciones, mejorar las
animaciones"). Antes, una puerta echada abajo por el Golpeador se abría entera y en buen estado, como si alguien la
abriera. Ahora revienta. Todo en el cliente (`src/juego/cliente/PuertaRotaVista.luau`); el servidor no cambia: sigue
mandando con `Vida`, `VidaMax` y `Abierta` (`Defensa.romper`) y quitando la colisión de la hoja abierta.

## Qué se ve

- **Cede** (`Config.PuertaRota.Cede`): con menos de la mitad de vida la hoja se parte en tablas (la de verdad se esconde
  en el cliente) y un trozo de una se mete hacia dentro, con los bordes astillados, un crujido y unas astillas. Queda
  una rendija por la que entra la luz de fuera (luna, relámpago, la linterna del otro lado). Con menos de un cuarto,
  otro trozo. Los dos trozos salen de la posición de la puerta: todos los clientes ven los mismos.
- **Revienta** (vida 0): la hoja se queda colgando de la bisagra de abajo, torcida 25° hacia la sala, caída del lado de
  la cerradura y con la parte de arriba volcada hacia la sala. Si una esquina tocaría el suelo, se apoya en ella. Cae
  con un rebote y se balancea un poco. Los trozos metidos salen volando con 10-14 astillas y trozos de tabla (piezas
  sueltas con física local, grupo `Cargado`: no chocan con los jugadores) que se anclan a los 2 s. Quedan 4-6 picos
  de madera clara en el marco del lado de la cerradura, el pomo sale rodando y cae polvo del dintel (`CasaVista.polvo`),
  con temblor, crujido y golpe.
- **Al pisar** las astillas (jugadores y bichos), cruje la madera (`Cruje` flojo y agudo, como los cristales); solo se
  mira cerca de la cámara.
- **Reparada** (vida llena): las astillas se recogen (se desvanecen), la hoja vuelve entera a su sitio.
- De día siguen ahí: se ve qué puerta cayó.
- Las marcas de garra (MarcasVista) van soldadas a la hoja: cuelgan con ella.
- **Rendimiento**: 5 astillas, sin tablas que ceden ni pomo que rueda.

## Cómo va

- `CasaVista.alPuerta(fn)` da cada puerta (`CasaVista.Puerta`): la hoja, el pomo, la bisagra y `colgar(cf)`, que
  pone la bisagra donde se le dice en vez de girarla (nil = vuelve a girar). Lo que se mete en `piezas` va con la
  hoja. Con la vida a 0, CasaVista no la abre con su ruido de siempre.
- Un solo Heartbeat, atado solo mientras hay algo que mover o astillas en el suelo.
- Banco: `tests/bancos/puerta-rota.luau` (las cuentas, una puerta que cede, revienta, cruje y se repara, Rendimiento
  y entrar tarde con la puerta ya caída).

## Probar en Studio

1. Jugar de noche y dejar que el Golpeador golpee la puerta de fuera (o bajar `Vida` a mano en el modelo de la puerta
   desde el servidor: 45, luego 20 y luego 0 con `Abierta` a true).
2. A 45: un trozo de tabla metido hacia dentro y una rendija con luz de fuera. A 20: otro.
3. A 0: la hoja colgando torcida, astillas por el suelo de la sala, picos en el marco, el pomo en el suelo y polvo.
   Andar por encima: cruje.
4. Reparar: se recogen las astillas y la hoja vuelve. Probar también con Rendimiento en Ajustes.
5. Sin probar todavía en Studio (hecho sin Studio): mirar que las astillas no atraviesen el suelo y que la rendija
   deje pasar la luz.
