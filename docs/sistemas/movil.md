# Móvil: el HUD en pantallas pequeñas (14.4)

Pedido por el usuario (CLAUDE.md): móvil desde el principio, todo el HUD bajo un solo `UIScale`, nada pequeño en la
esquina de arriba a la derecha.

## Escala

- Todo cuelga de `Ui.hud()` (ScreenGui `Hud`, `IgnoreGuiInset`) con un `UIScale` = `min(ancho / 1280, alto / 720)`
  entre 0,55 y 1,3. Se dibuja en píxeles de diseño de una pantalla de 1280 × 720; las posiciones en escala siguen
  siendo de la pantalla de verdad (comprobado en Studio: un marco de 1 × 1 tapa la pantalla con el HUD a 1,1).
- A 640 × 360 la escala es 0,55 y el lienzo mide ~1164 × 655 de diseño: ninguna ventana debe pasar de eso
  (`Ui.lienzo()` lo da en el momento).
- Fuera del HUD a propósito: el blanco del flash, el fundido del lobby y los finales (tapan la pantalla entera), y los
  carteles del mundo (`BillboardGui` de Controles y CargarVista), que se encogen a mano con `Ui.escala()` (entre 0,75 y 1).

## Botones táctiles

- `Ui.DEDO` = 80 de diseño = 44 píxeles de verdad a la escala mínima. `Ui.alto(n)` da `n` en el ordenador y como
  mínimo `Ui.DEDO` en pantallas táctiles: así el ordenador se queda como estaba.
- `Ui.queQuepa(texto, máximo)`: letra que encoge para caber (FLASHLIGHT, frases largas de los prompts, otros idiomas).
- Ventanas con botones de un dedo en el móvil: mochila (además, casillas de hasta 76 de diseño según el alto de la
  pantalla), pista, taller, vendedor, revivir, ajustes (SÍ/NO y CERRAR con `Ui.alto`, papel de 280 de alto en
  pantallas táctiles), tienda y coche del lobby. La mochila va con ZIndex 26, encima del engranaje (25): a 640 × 360
  su papel llega a la barra de arriba.

## Reparto en el móvil (horizontal)

- Arriba: barra de Roblox (unos 58 px de verdad, botones en las dos esquinas). Debajo, al 17 % del alto: a la
  izquierda los botones de revivir compañeros (en fila, de 144 × 80 en dos líneas: el nombre arriba, que se corta, y
  el precio abajo, que siempre se ve; tres caben antes del cartel) y en el centro el cartel de pila y fotos y las
  bengalas. El texto del paso del tutorial deja libre el hueco de SALTAR.
- Joystick: Roblox lo pone en el 40 % izquierdo y los dos tercios de abajo; ahí no va ningún botón.
- Derecha: los botones de acción de los prompts (`Hud.Acciones`, al 95,5 % del ancho, apartados del borde por la
  cámara de algunos teléfonos) encima del botón de saltar de Roblox.
- Abajo, a la izquierda del salto (`Hud.EquipoBotones`, rejilla de 4 × 2 de 108 × 80 desde abajo a la derecha, 14.8):
  FLASH 1, LINTERNA 2, MOCHILA 4, MÓVIL 5, AGACHARSE 6 (`PosturaVista`, rojo con borde claro mientras vas agachado),
  CORRER 7 (`CorrerVista`, igual mientras corres) y BENGALA 8 (con la pistola, en la casilla de arriba a la izquierda
  que queda libre: nada se mueve al aparecer o irse). Se recoloca al cambiar el tamaño de la pantalla. A 1164 de ancho de diseño
  empieza en el 40,8 %: fuera de la zona de la palanca. Escondido o muerto se esconde: ahí van SALIR y REVIVIR.
- Zona segura de abajo (`Ui.zonaSegura()`, 14.8): lo que tapa el teléfono abajo (barra de inicio), medido con un
  ScreenGui con `ScreenInsets = DeviceSafeInsets`. La rejilla se sube eso y debajo queda la barra del aguante
  (`docs/sistemas/correr.md`), a la zona segura + 6.
- El móvil (mapa) se abre encima de esa rejilla contando la zona segura (14.9), con un UIScale de 0,75 como mucho que
  baja si no cabe bajo la barra de Roblox. Los avisos de una línea suben al 64 % del alto, en un cuadro de 0,56 del
  ancho que acaba antes de `Hud.Acciones`; una frase larga baja a dos renglones y encoge (`Ui.queQuepa`, 26 como
  mucho), pero los avisos se escriben para que quepan en una línea.
- Acciones de teclado con botón en el móvil: B (MOCHILA), R/G (GIRAR/TIRAR en la mochila), F (LINTERNA), clic (FLASH),
  Q/clic (BENGALA dispara directamente), M (MÓVIL), C/Ctrl (AGACHARSE), Shift mantenido (CORRER, que en el móvil y con L3 alterna), E/R con peso (SOLTAR / el botón de usar), E en
  el escondite (SALIR) y la E de cada prompt (botón grande de acción). Asomarse (Z/X) es solo de teclado.
- Hueco para el engranaje de Ajustes: arriba, a la izquierda de la esquina de la derecha (p. ej. `AnchorPoint` (1, 0)
  en `UDim2.new(0.8, 0, 0, 12)`, 80 × 80 en el móvil): no pisa los botones de Roblox ni los de acción.

## Móvil y mochila en escondites y escenas (14.9)

- Pedido antes por el usuario y recuperado en la 14.9: el móvil se puede mirar escondido (no se guarda al esconderse)
  y la mochila se abre por la mirilla o entre las cortinas (`MirarVista` deja de mirar con `MochilaAbierta`). Los dos
  se guardan o cierran solo al empezar la escena de un final (atributo `EscenaFinal`, ver `partida.md`) y no se abren
  durante ella. Banco `tests/bancos/escenas.luau`.

## Probar en Studio (14.9, sin probar)

- Emulador 640 × 360 y un iPhone 844 × 390: rejilla abajo FLASH, LINTERNA, MOCHILA, MÓVIL; arriba AGACHARSE, CORRER y
  BENGALA (solo con la pistola, sin mover a los demás); la barra del aguante debajo, sin chocar, también al girar. El
  móvil abierto no pisa la fila de arriba ni queda bajo la barra de Roblox ni tapa Acciones.
- Avisos: con un botón de acción en pantalla, el aviso largo (la reja) queda a su izquierda en una o dos líneas.
- Revivir con 2-3 jugadores: botones de 144 con nombre arriba y precio abajo; con un nombre de 20 letras se corta el
  nombre, nunca el precio. Ajustes: SÍ/NO y CERRAR de un dedo. Mochila: el engranaje no pinta encima. Tutorial: el
  texto del paso acaba antes de SALTAR. Taller y vendedor: con su papel abierto no asoma su botón de acción.
- Textos: con una foto, "1 PHOTO  +N" / "1 FOTO  +N"; con una bengala, "1 FLARE" / "1 BENGALA"; el aviso de la reja en
  una línea ("La reja está lista. Tira de la palanca de la trampilla.").
- Móvil escondido: abrirlo con M y meterse en un armario: sigue abierto. Cerrarlo con M dentro y abrirlo otra vez: se
  abre. En la huida o el incendio, al empezar la escena se guarda y M no lo saca.
