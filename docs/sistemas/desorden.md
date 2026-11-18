# La casa se desordena

Mejora de inmersión (noviembre de 2026, pedido por el usuario: "mejorar la inmersión, tema interacciones, mejorar las
animaciones"). Antes, los golpes solo hacían temblar las cosas y torcer los cuadros. Ahora la casa se desordena de
verdad. Todo en el cliente (`src/juego/cliente/DesordenVista.luau`, cuentas en `DesordenCuentas.luau`, números en
`Config.Desorden`, a ojo). El servidor no cambia: manda con `Golpes` en las ventanas y puertas (Casa) y con los bichos
de `workspace.Bichos`.

## Qué se ve

- **Un golpe** en una puerta o ventana, o una **pisada fuerte** de un bicho pesado (Golpeador, Bestia) dentro de la
  casa (una de cada tres casillas de 8 studs, más o menos): de las baldas, mesas y repisas de esa sala (14 studs, misma
  planta y sin pared en medio) se caen 1-2 adornos, de los más cerca del borde (botellas, platos, tarros, copas, latas,
  ollas, candeleros, fotos, el reloj de repisa). Lo del suelo y lo que da a una pared por ese lado no se cae.
- Caen con física local: una copia sin anclar empujada fuera del borde, que rebota y se queda en el suelo.
- **La vajilla y el cristal** se rompen en 4-6 trozos (de cristal o de loza, del color del adorno). Una botella de
  licor o la jarra dejan un charco que se extiende. Los trozos crujen al pisarlos (jugadores y bichos, `Cruje` flojo y
  agudo, solo cerca de la cámara). Mientras no haya un `Vajilla` propio, suena un `Cristal` agudo y cortado.
- **El metal** suena con `Latas`, rueda un poco y vuelve a repicar.
- **Un cuadro** que ya ha aguantado 3 golpes cerca se descuelga, cae hacia la sala y suena `CuadroCae`.
- **Un bicho que cruza una sala**: las sillas que roza (su raíz a menos de 2 studs) se vuelcan hacia donde iba, con un
  botecito, y suena `Caida`. Si por ahí hay pared, hacia el primer lado libre. La mecedora y la silla de ruedas se
  apartan 1,4 studs girando un poco (con la manta de la mecedora).
- Por la mañana se ve por dónde pasó y dónde golpeó. **Al amanecer** (Fase `Dia`) todo vuelve a su sitio y los trozos
  se desvanecen.
- **Tope**: 25 cosas caídas por noche. Lejos de la cámara (más de 90 studs) no hay física: se pone ya caído, sin sonido.
- **Rendimiento**: una cosa por golpe, la vajilla no se rompe (cae entera) y las sillas caen sin rebote.

## Cómo va

- Lo que cae y en qué orden sale de una cuenta fija (`DesordenCuentas`): de dónde vino el golpe (el `Centro` o la
  `Bisagra` de la ventana o puerta, o el bicho y su casilla), la noche (`workspace.Noche`), el número de golpe y los
  adornos ordenados por lo cerca que están del borde y por su sitio. Todos los clientes tiran las mismas cosas sin
  hablar entre ellos (con Rendimiento, solo la primera). Los trozos y los botes sí son distintos en cada uno.
- Al acabar de caer, la pieza de verdad se pone donde quedó la copia (anclada, en local) y la copia se borra. La rota
  se queda escondida bajo el mapa hasta el amanecer. Efectos la da por movida por otro (`ajeno`) y no la toca hasta
  que vuelve a su sitio (`revisarAjeno`), como con el cuadro del susto.
- Lo que hay en la casa se busca al cargar el mapa y otra vez si cambia (como Efectos). Para cada adorno se mira la
  balda de debajo con rayos: su borde más cercano que no da a una pared, que tenga hueco debajo (no una alfombra) y el
  suelo donde acabaría.
- Copias y trozos en el grupo `Cargado` (no chocan con los jugadores). Un solo Heartbeat, atado solo mientras cae
  algo, hay trozos o hay bichos en el mundo; los bichos y los trozos pisados se miran cada décima.
- Quien entra tarde no ve lo que cayó antes de llegar (es local).
- Banco: `tests/bancos/desorden.luau` (cuentas; una sala con mesa, ventana, cuadro, silla y mecedora: caen 1-2 del
  borde y los mismos en otro cliente, la vajilla se rompe y cruje, la lata se queda en el suelo, el cuadro cae al
  tercer golpe, el bicho vuelca la silla sin meterla en el suelo y aparta la mecedora, el amanecer lo recoge todo, y
  Rendimiento).

## Probar en Studio

1. Jugar de noche y dejar que el Golpeador golpee una ventana o la puerta de la cocina o el comedor (o subir `Golpes`
   a mano en el modelo de la ventana desde el servidor: 1, 2, 3...).
2. Con cada golpe se caen 1-2 cosas de las mesas y baldas de esa sala; la vajilla se rompe en trozos y la botella deja
   un charco; la lata rueda. Andar por encima de los trozos: crujen. Al tercer golpe, un cuadro de la sala se cae.
3. Dejar que un bicho entre en la casa y pase junto a las sillas de la cocina: se vuelcan; la mecedora se aparta.
4. Mirar con dos jugadores (Test, 2 jugadores) que caen las mismas cosas en los dos.
5. Al amanecer, todo en su sitio. Probar también con Rendimiento en Ajustes.
6. Sin probar todavía en Studio (hecho sin Studio): mirar que las copias no atraviesen las baldas ni el suelo, que el
   empuje baste para sacarlas del borde (si no, subir `Empuje`), que el choque se note al dar contra el suelo y que
   no se queden flotando.
