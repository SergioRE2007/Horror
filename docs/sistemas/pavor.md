# Pavor al ver un bicho: vértigo, manos que tiemblan y latido

Pedido por el usuario: "mejorar la inmersión del juego, tema interacciones y todo eso… mejorar las animaciones". Todo
en el cliente y solo de adorno: `src/juego/cliente/PavorVista.luau` (registrado en `init.client.luau` después de
`MirarVista`), con las cuentas en `PavorCuentas.luau`. Números en `Config.Pavor`, a ojo.

## Qué pasa

La primera vez que un bicho de `workspace.Bichos` entra en tu vista de verdad (en la pantalla sin los bordes, a menos de
`Lejos` = 45 studs y con un rayo sin paredes en medio; los cristales y lo casi transparente no tapan), el cuerpo
reacciona. Cuanto más cerca lo veas, más fuerte (`PavorCuentas.fuerza`: entero a `Cerca` = 8 studs, `Minimo` en el
límite).

- **Vértigo**: el campo de visión se cierra de 70 a ~60 en 0,5 s mientras la cámara recula un palmo (sin meterse en la
  pared de detrás), se queda un momento y vuelve despacio (`Vertigo`). Lo suma `CuerpoVista.ponerPavor` como el campo de
  correr: se quita solo y vuelve a 70 justo.
- **Golpe de tensión flojo** (`Sobresalto` al 45 %, como mucho uno cada 4 s) y las manos dan un respingo
  (`ManosGestos.sobresalto`, flojo).
- **Latido** (`Latido`) fuera del escondite: entero 3-6 s (más cerca, más) y se apaga en 2,5 s.
- **Pavor** de 20 a 30 s que baja poco a poco (`Dura`, `Baja`):
  - las manos y la linterna tiemblan (`Manos.pavor`, temblor fino y otro lento con algún tirón, `PavorCuentas.temblor`).
    El haz tiembla con la mano porque la luz sale de `Manos.dondeCosa`;
  - la respiración de la cámara va más deprisa (`CuerpoVista.respiracion` con más susto, y el vaho más seguido);
  - al girar rápido la vista se queda un pelo atrás (`Retraso`: desde 1,5 rad/s, 2,2° como mucho; `PavorCuentas.retraso`).

Un susto nuevo durante el pavor lo sube si es más fuerte, nunca lo baja. El mismo bicho no vuelve a asustar hasta que lo
pierdes de vista `Olvida` = 15 s.

## Cuándo no

- El Imitador mientras finge en la puerta (sin `Abierto`) no cuenta: lo delataría. Un bicho con el Humanoid muerto, tampoco.
- Nada escondido ni debajo de un mueble (`Escondido`, `Cubierto`: allí manda el latido de `MuerteVista`; al esconderte,
  el nuestro se corta), muerto, con la mochila abierta, mirando por la mirilla o la ventana (`Vistazo`, `Mirilla`:
  `MirarVista` tiene su propio susto) ni en cinemáticas (cámara que no es `Custom`). El tiempo del pavor sigue corriendo:
  al salir queda lo que quede.
- Con **Rendimiento**: sin vértigo, sin retraso y sin respiración de más; solo el latido y un temblor flojo
  (`Temblor.Rendimiento`).

## Cómo va por dentro

- Un solo `RenderStep` (`Camera - 2`, antes de `CuerpoVista`): mira los bichos cada `Cada` = 0,15 s (pantalla con
  `WorldToViewportPoint` y un rayo a la cabeza y al cuerpo, hasta 4 atravesando cristales) y pone lo de ahora en
  `CuerpoVista.ponerPavor(campo, recula, susto, retraso)` y `Manos.pavor(x)`. Sin pavor ni latido, lo quita una vez y no
  hace nada más.
- `CuerpoVista` suma la recula y el retraso al mismo `CFrame` que el balanceo (se deshace igual) y el campo de visión al
  de correr.
- Banco: `tests/bancos/pavor.luau` (cuentas, PavorVista con falsos en cada caso de arriba y CuerpoVista de verdad: campo
  60 y vuelta a 70, la pared de detrás, el retraso al girar acotado).

## Probar en Studio

1. Jugar de noche y esperar a un bicho (o ponerse delante de uno; sin esperar, en el cliente:
   `game.Players.LocalPlayer:SetAttribute("PavorPrueba", 10)` hace el susto de ver uno a 10 studs, solo en Studio). Al verlo por primera vez: la vista se cierra un
   momento, golpe flojo, latido unos segundos y las manos con la linterna tiemblan (el haz tiembla en la pared).
2. Girar deprisa con el ratón justo después: la vista se queda un pelo atrás y alcanza al parar.
3. Mirar a otro lado menos de 15 s y volver: no repite. Más de 15 s: sí.
4. Verlo a través de una ventana cerrada: cuenta. Con una pared en medio: no.
5. Con el Imitador en la puerta (sin abrir) y por la mirilla: nada de esto.
6. Esconderse con el latido sonando: se corta y queda el de MuerteVista.
7. Activar Rendimiento en Ajustes: sin el vértigo, solo latido y temblor flojo.
8. A ojo para retocar en `Config.Pavor`: lo fuerte del vértigo (`Vertigo.Campo`, `Recula`), lo que tiembla
   (`Temblor.Giro`) y el retraso (`Retraso.Max`).
