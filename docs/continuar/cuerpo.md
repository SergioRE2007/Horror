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
  - Agachado, de tu cuerpo solo choca la raíz, encogida: va de `PASO_LIBRE` (1,1) a `Config.Postura.Alto` (2,6)
    del suelo (el HipHeight baja a 1,1 y la raíz encoge a la vez, `altoRaiz` en `cuidarCuerpo`, a `CUERPO_VEL`). Lo
    demás va al grupo `Agachado`; la raíz se queda en el suyo (`Personajes`) porque el sensor de suelo del Humanoid usa
    el grupo de la raíz: en `Agachado` no vería el suelo y andaría en Freefall apoyado en la banda (arreglo de la
    revisión, 04-11-2026). Una banda invisible (`PosturaBanda`) con la misma caja que la raíz, por si el Humanoid le
    quita CanCollide. Se entra andando bajo un tablero y los peldaños de 1 se siguen subiendo.
  - `cuerpo()` cuenta el HipHeight y lo que ha encogido la raíz (con AutomaticScalingEnabled la cámara de Roblox baja
    el doble de lo encogido): la vista queda a la misma altura que antes.
  - Lo que sale del personaje agachado (una herramienta que se suelta) vuelve a su grupo al momento (`alQuitar`).
  - Levantarse (C, saltar, escalera, sentarse) solo si cabes (`cabeDePie`: Blockcast hasta la coronilla de pie y,
    como lo que choca de los muebles tiene CanQuery false, las zonas `Debajo` a mano con `techoDebajo`). `techoDebajo`
    cubre todo el tablero (atributo `Tam` del mueble, `techoDe`), no solo la zona: en la mesa del comedor sobresale
    1,96 por las puntas y 0,7 por los lados largos, y por ahí se pasa agachado (antes, ALERO fijo de 0,4: te dejaba
    levantarte con la cabeza en el tablero y la cámara no bajaba). Sin `Tam`, ALERO. Si no, sigues
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
  oscuros flojos (`VINETA_CUBIERTO`, `pintarBordes`). Sin `Cubierto` sigue `SALIR_CUBIERTO` (0,5 s): en el borde de
  la zona el atributo va y viene y el latido y la respiración empezaban cada vez.
- Cuentas comprobadas con Lune (script aparte, no en tests): banda de 1,1 a 2,6 con avatares de escala 0,8 a 1,5,
  raíz agachada por debajo de 2,8 (dentro de la zona) y cámara bajo una mesa de 2,8 con su margen. Tras la revisión,
  un banco con un Roblox de mentira (fuera del repo) carga PosturaVista: raíz en su grupo y de 1,1 a 2,6, lo demás en
  `Agachado`, ojos a la misma altura en toda la bajada y la subida, herramienta soltada a su grupo, no se levanta bajo
  el vuelo del tablero (lado largo y punta), todo vuelve al levantarse y al morir.

## Falta

- Probarlo en Studio (abajo). Nada más pendiente de código.

## Cómo probarlo en Studio

1. Play (Config.Test). Ir a la mesa del comedor (`MesaComedorPH`). Pulsar C en suelo llano y en un peldaño: en el
   cliente, `local p=game.Players.LocalPlayer local h=p.Character.Humanoid local r=h.RootPart return h.HipHeight,
   r.Size.Y, r.Position.Y, h:GetState(), h.FloorMaterial, h.CameraOffset, p:GetAttribute("Agachado")` → HipHeight 1,1,
   Size.Y 1,5, Y = suelo + 1,85, Running (no Freefall), el material del suelo (no Air), CameraOffset.Y ≈ -0,3 (escala
   1: baja 1,7 y el cuerpo ya ha bajado 1,4) y true. Mirar que la vista queda donde antes de este arreglo.
   Agachado al borde del lado largo de la mesa (bajo el tablero, fuera de las patas): C no levanta.
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
- Se da por hecho que el HipHeight y el Size de la raíz que cambia el cliente no se replican (BrazosVista los usa
  para saber la altura de pie del otro), que el Humanoid no le devuelve el tamaño a la raíz (AutomaticScaling solo
  mira las escalas) y que la cámara de Roblox suma (Size.Y - 2) / 2 a la cabeza con AutomaticScalingEnabled. Si la
  vista agachado sale más alta o más baja que antes, mirar `PosturaVista.cuerpo()`.
- Los otros ven tu cuerpo 0,25 más abajo que antes (el centro de la raíz baja con lo encogido): BrazosVista dobla las
  piernas lo que de verdad ha bajado, así que los pies siguen en el suelo.
- `PASO_LIBRE`, `ALERO` (PosturaVista) y `CADA_CUBIERTO` (Postura) siguen fuera de `Config` (no es archivo de esta
  zona): si cambia `Config.Postura.Alto` o la altura de una mesa, revisar `PASO_LIBRE` a mano.
- Un grupo de colisión registrado después de `Postura.start` chocaría con `Agachado`: añadirlo en `prepararGrupo`.
- Tu sombra en primera persona sigue sin doblar las piernas (el cuerpo propio no se pinta agachado).
