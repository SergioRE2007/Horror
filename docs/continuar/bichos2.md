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

## Falta

- **Gateo de la Bestia** (en `BestiaVista`): aplastada contra el suelo, la cabeza bajo el borde hasta donde quepa y el
  brazo largo barriendo por debajo como la pata de un gato (con 6,35 de brazo no cabe recto en una mesa de 2,8: entra
  en diagonal y las garras pasan a tu lado), empujando el borde (temblor y crujidos) en cada tirón.
- Repasar las transiciones del Imitador con la mesa de la cocina (hueco de 3,29) y con el jugador de lado.
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
