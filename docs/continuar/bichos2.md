# Bichos con vida y gateo (grupo bichos2): ImitadorVista, AcechadorVista, BestiaVista

Pedido por el usuario: "que todo esté animado y que la experiencia sea inmersiva" (los bichos con vida mientras esperan,
el Imitador que reacciona a la mirilla) y, el 03-11-2026, "agacharte también debería servir para esconderte, por
ejemplo debajo de mesas, y que el monstruo pueda gatear si te huele con una animación guapa para pillarte debajo de
sitios". Todo en el cliente con la Transform de sus Motor6D. Hecho sin Studio: las poses salen de cuentas comprobadas
con Lune (y ejecutando los módulos con un Roblox de mentira, ver abajo). Números visuales al principio de cada módulo.

## Hecho

- **Vida mientras esperan** (las tres Vistas): Imitador demasiado quieto en la puerta (cabeza ladeada escuchando,
  tirones, dedos crispados, golpecitos con los nudillos al compás de `Toc`); Acechador que respira, se mece, se esconde
  tras un tronco sin que se le vea moverse y se asoma inclinándose desde los tobillos (si echa a andar o carga
  viéndole, sale de una zancada); Bestia que respira pesada, resopla (vaho de noche), tiembla, carga el peso, olfatea,
  se crispa y gruñe. Con Rendimiento, nada de eso.
- **Mirilla** (atributo LOCAL `Mirilla` de MirarVista): el Imitador se ve a contraluz, gira la cara, se dobla y se pega
  de golpe (`Sobresalto`), una vez por llamada y solo si sigues mirando.
- **Arreglos del revisor**: Acechador sin deslizarse al echar a andar o cargar; Rendimiento lo devuelve a su sitio;
  golpecito del Imitador con `cerca`; temblor de la Bestia que se deshace siempre.
- **Gateo del Imitador** (atributos `Gatea` y `GateaHora` en su modelo, del servidor): encorvado en el borde con una
  mano en el suelo, el cuello se estira hasta el suelo y asoma la cara por el borde a ras de suelo, ladeada, mirándote;
  el otro brazo baja por el borde y entra arañando a tirones (parada de olfatear) hasta dejarte la mano al lado. Al
  echarse y al levantarse, todo va en línea recta (no atraviesa el tablero ni se hunde). Si te pilla se queda en la
  pose para la escena de muerte; si no, vuelve. Luz floja en la cara (solo cerca). Comprobado con Lune (mesa del
  comedor: hueco de 2,84 y 2,8 entre patas): no atraviesa el tablero ni el suelo en la pose; la cara queda a ~1,2 de
  alto en el borde mirándote y los dedos a 0,4-1 de ti.

## Falta (exactamente)

- **Gateo de la Bestia** (en `BestiaVista`, sin empezar en el código; la vida de espera ya está y funciona). Seguir el
  mismo esquema que el del Imitador (copiar de `ImitadorVista`: `medirMueble` con 3 rayos y bisección, `tirones`,
  `enTiron`, `ejes`, el tipo `Gateo`, `gatear` y `terminarGateo`) y además:
  1. En `preparar`, guardar `c0/c0i/c1/c1i` de cada motor (como el Imitador) y un `b.pose`; en `animar`, que las
     líneas `m.X.Transform = ...` escriban en `b.pose.X` y al final se pongan con la del gateo encima. Meter
     `b.gateo ~= nil` en `ocupada` (así se pausa su vida de espera).
  2. Pose (suelo G bajo la raíz, -z hacia ti): lomo plano con su centro a 1,6 de alto y el frente en
     `min(borde - 0,25, D - 3,25)` (avanza 1,3 a tirones; si el hueco < 2,7, el frente en `borde - 2,4`: no mete la
     cabeza). Cabeza en la junta `lomo * (0, 0,7, -3)`, girada hacia ti y unos -0,2 rad hacia abajo (sube al olfatear);
     boca abierta hasta 0,55 pero comprobando que la punta de la mandíbula `* (0, -0,275, -1,3)` no baje de 0,05.
     Brazo derecho desde `lomo * (2,5, 0,4, -2,3)`, bajando 0,18 rad, barriendo en horizontal de 0,95 rad (hacia fuera)
     al ángulo en que pasa a 1,6 de ti: `asin(1,6 / R) - atan2(2,5, L)` con `L = D - frente + 0,8` y
     `R = sqrt(2,5² + L²)`; su Z hacia `(cos θ, 0, sin θ)` (las garras barren de lado, no contra el suelo). Brazo
     izquierdo abierto atrás-fuera. Patas de atrás desde `lomo * (±1,9, -0,4, 2,5)` abiertas hacia atrás a ras de
     suelo, con su Z hacia abajo (el pie de adorno queda hacia arriba).
  3. Al aplastarse y al levantarse, el lomo y la cabeza con un camino de 3 tramos (atrás arriba, bajar fuera del borde
     y meterse a ras de suelo): de pie su cara está 5,6 por delante de la raíz y pasaría por el tablero. Brazos y patas
     en línea recta (como el Imitador, con las patas algo levantadas a medio camino).
  4. Sonidos: al aplastarse `Paso` grave fuerte + `temblar` + gruñido (`resoplido(b, true)`); en cada tirón
     `Aranazo` en la mano, `Cruje` en el borde y `temblar` flojo (empuja la mesa); al olfatear `resoplido(b, false)` y
     vaho. Con Rendimiento, solo el golpe y el arañazo.
  5. Comprobarlo con Lune como el del Imitador (mesa del comedor: hueco 2,84, 2,8 entre patas; cocina: 3,29) y con el
     borde a 1,5, 3 y 5 de la raíz.
- Repasar el gateo del Imitador con la mesa de la cocina (hueco de 3,29).
- Párrafo para `docs/sistemas/bichos.md` (lo pone el principal).

## Cómo probarlo en Studio

- Comprobar que Rojo ha sincronizado: `string.find(game.StarterPlayer.StarterPlayerScripts.Cliente.ImitadorVista.Source, "gatear")`.
- Vida: `ServerStorage.Prueba:Fire("Noche")` y luego `"Imitador"`, `"Acechador"` (con el jugador en el bosque) o
  `"Bestia"` (para verla parada: `workspace.Bichos.Bestia.HumanoidRootPart.Anchored = true` desde el servidor).
- Mirilla: dentro, en la puerta principal, tecla L o `PlayerScripts:FindFirstChild("MirarVista", true).Probar:Fire("Mirilla")`
  justo después de una llamada; `workspace:SetAttribute("MirarQuieto", true)` para mirar más de 6 s.
- Gateo a mano (servidor), con el Imitador en la casa y el jugador agachado debajo de la mesa del comedor:
  `local m = workspace.Bichos.Imitador; m.HumanoidRootPart.Anchored = true; m:SetAttribute("Gatea", game.Players:GetPlayers()[1].Character.HumanoidRootPart.Position); m:SetAttribute("GateaHora", workspace:GetServerTimeNow())`
  y a los 2 s `m:SetAttribute("Gatea", nil); m:SetAttribute("GateaHora", nil)`. Ponerle antes de cara al borde y a
  1-2 studs de él (`m:PivotTo(...)`).

## Riesgos

- Sin ver en Studio: el aspecto del cuello estirado (se cambia su Size solo en este cliente) y el doblez con el
  cuerpo de bloques.
- El brazo de apoyo del Imitador puede rozar una pata de la mesa según cómo quede (no se miran las patas).
- Si el servidor deja al bicho a menos de ~0,6 del borde, ya de pie toca el tablero.
- Pruebas de Lune (no van en el repo): estaban en el scratchpad de la sesión (`falso.luau`, `escenas.luau`,
  `gatea_imitador.luau`); se pierden al cerrar la sesión.
