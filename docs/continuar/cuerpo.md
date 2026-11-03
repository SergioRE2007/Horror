# Esconderse agachado (cuerpo): estado al día

Pedido por el usuario (03-11-2026): "agacharte también debería servir para esconderte, por ejemplo debajo de mesas,
y que el monstruo pueda gatear si te huele con una animación guapa para pillarte debajo de sitios… que sea útil
agacharte es la finalidad". Esta parte es la del cuerpo y la cámara; los bichos (Caza, Bestia) y las mesas con hueco
(Mapa) los hacen otros.

## Hecho (sin probar en Studio)

- `servidor/Postura`: registra el grupo de colisión `Agachado` (no choca con nada) en `prepararGrupo()`. Atributo
  `Cubierto` (true o nil): agachado y con la raíz dentro de una zona `Debajo` (etiqueta de Mapa); se mira cada 0,2 s
  solo a los agachados (`mirarCubierto`, `debajoDeAlgo`) y se quita con `Agachado` en `publicar()`.
- `cliente/PosturaVista` (sección "El cuerpo agachado", solo R15):
  - Agachado, todo el cuerpo va al grupo `Agachado` y solo choca una banda invisible (`PosturaBanda`, la planta de
    la raíz) de `PASO_LIBRE` (1,1) a `Config.Postura.Alto` (2,6) del suelo: se entra andando bajo un tablero y los
    peldaños de 1 se siguen subiendo. El HipHeight baja a 1,1 (`cuidarCuerpo`, a `CUERPO_VEL`).
  - Cambio sobre la idea del contrato: la raíz no sigue chocando. Con la raíz chocando, para que su techo quede en
    2,6 el HipHeight tendría que bajar a 0,6 y los peldaños de 1 del sótano no se subirían agachado.
  - Levantarse (C, saltar, escalera, sentarse) solo si cabes (`cabeDePie`: Blockcast hasta la coronilla de pie y,
    como lo que choca de los muebles tiene CanQuery false, las zonas `Debajo` a mano con `techoDebajo`). Si no, sigues
    agachado, sin poder saltar, con un Cruje flojo (`topar`). Si el servidor quita `Agachado` estando debajo, el
    cuerpo sigue abajo hasta que quepas (`atascado`). Muerto o escondido, todo vuelve a su sitio al momento.
  - Exporta `bajo()`, `cuerpo()`, `tope()` y `techoDebajo(punto)`.
- `cliente/CuerpoVista` (`postura`): la cámara baja `Config.Postura.Baja` menos lo que ha bajado el cuerpo (misma
  altura que antes). Debajo de algo baja más y nunca se mete (`techoEn`: zonas `Debajo` y un rayo, donde está la
  cabeza y donde va la cámara); andando hacia ello empieza a bajar `ANTICIPA` s antes. Respingo de cámara al toparte.
- `cliente/BrazosVista`: ya no baja la raíz de los demás (su cliente ya los baja). `medirCuerpo` dobla las piernas lo
  que de verdad ha bajado su raíz respecto al suelo y, con algo encima (zonas `Debajo` o rayo), encorva el tronco para
  que la cabeza quepa.
- `cliente/MuerteVista`: debajo de un mueble (`Cubierto`) contienes la respiración solo con un bicho cerca
  (`debajoDeMueble`, reutiliza `respirar`, `tramos` y `notarAliento` del escondite) sin tocar la cámara, y unos bordes
  oscuros flojos (`VINETA_CUBIERTO`, `pintarBordes`).
- Cuentas comprobadas con Lune (script aparte, no en tests): banda de 1,1 a 2,6 con avatares de escala 0,8 a 1,5,
  raíz agachada por debajo de 2,8 (dentro de la zona) y cámara bajo una mesa de 2,8 con su margen.

## Falta

- Probarlo en Studio (abajo). Nada más pendiente de código.

## Cómo probarlo en Studio

1. Play (Config.Test). Ir a la mesa del comedor (`MesaComedorPH`). Pulsar C: en el cliente,
   `local p=game.Players.LocalPlayer local h=p.Character.Humanoid return h.HipHeight, h.CameraOffset, p:GetAttribute("Agachado")`
   → HipHeight 1,1 (de pie, ~2), CameraOffset.Y ≈ -0,8 (escala 1) y true.
2. Andar agachado debajo de la mesa: se entra; la vista baja sola antes del borde y no se mete en el tablero. En el
   servidor, `game.Players:GetPlayers()[1]:GetAttribute("Cubierto")` → true dentro, nil fuera.
3. Debajo: C y espacio no levantan (Cruje flojo y respingo), no se salta. Al salir del todo, C levanta.
4. Bajar y subir la escalera del sótano agachado: los peldaños de 1 se suben.
5. Con un bicho cerca debajo de la mesa: se contiene la respiración (bordes que se cierran, latido) y los bordes
   oscuros flojos están siempre que estás cubierto.
6. Dos jugadores (Test → Clients and Servers): el otro agachado se ve más bajo con las piernas dobladas y los pies en
   el suelo; debajo de la mesa, encorvado sin que la cabeza atraviese el tablero.
7. Esconderse en el armario estando agachado, y morir agachado: el cuerpo vuelve a su sitio sin quedarse raro.

## Riesgos

- R6: sin cuerpo físico (solo la cámara): no cabe debajo de las mesas.
- En el servidor (y para los bichos) la cabeza del agachado queda encima del tablero: el encorvado es solo visual en
  cada cliente. Los bichos deben usar `Cubierto` o mirar a la raíz, no a la cabeza.
- Se da por hecho que el HipHeight que cambia el cliente no se replica (BrazosVista lo usa para saber la altura de
  pie del otro) y que el sensor de suelo del Humanoid sube peldaños aunque la raíz no choque.
- Un grupo de colisión registrado después de `Postura.start` chocaría con `Agachado`: añadirlo en `prepararGrupo`.
- Tu sombra en primera persona sigue sin doblar las piernas (el cuerpo propio no se pinta agachado).
