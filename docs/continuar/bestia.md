# bestia: gateo de la Bestia (esconderse agachado)

Archivo: `src/juego/cliente/BestiaVista.luau` (solo cliente). Nada visto en Studio: comprobado con un banco de Lune
(Roblox de mentira, CFrame y Vector3 de verdad, la Bestia montada como en `servidor/Bestia.luau` con todos sus adornos)
que mira cada fotograma. El banco está en el scratchpad de la sesión (`.../scratchpad/bestia/banco.luau`), fuera del
repo; si hace falta, se rehace.

## Hecho

- **Gateo de la Bestia** (pedido por el usuario: "que el monstruo pueda gatear si te huele… para pillarte debajo de
  sitios"), con `Gatea` (Vector3) y `GateaHora` en su modelo. Mismo esquema que el del Imitador (`medirMueble`,
  `tirones`, `enTiron`, `ejes`, el tipo `Gateo`, `gatear` y `terminarGateo`):
  - `preparar` guarda `c0/c0i/c1/c1i` de cada motor y `b.pose`; `animar` escribe la pose de siempre en `b.pose` y al
    final pone cada Transform, con la del gateo encima. `ocupada` lleva el gateo: su vida de espera se pausa.
  - Camino de 3 tramos (`GATEO.Tramos`, 0,6 s): se echa atrás con un saltito (lo justo para que nada alto le quede
    sobre el mueble, 0,9 por fuera del borde), baja fuera del borde y se mete a ras de suelo. Cada pieza va en línea
    recta en cada tramo; brazos y patas se levantan lo justo para no bajar del suelo al girar.
  - Aplastada: lomo plano con el centro a 1,6, fuera del mueble (el frente a 0,9 del borde que choca, o a 3,8 de ti);
    avanza 1,3 a tirones (4 tirones y una parada de olfatear). Brazo derecho desde el hombro, bajando 0,18 rad,
    barriendo el suelo de lado (su Z hacia fuera: las garras por delante) desde 0,95 rad hacia fuera hasta pasar a
    1,6 de ti (y las garras, como poco, a 1,6). Brazo izquierdo abierto atrás y fuera, empujando en cada tirón. Patas
    de atrás abiertas hacia atrás a ras de suelo, con el pie de adorno hacia arriba.
  - **Cambio sobre la nota vieja** (`bichos2.md`): la cabeza no va en la junta del cuello con -0,2 rad. Así su frente
    atravesaba el tablero del comedor (~0,1) y la boca no se podía abrir nada (cerrada, la punta de la mandíbula ya
    quedaba a 0,14 del suelo). Va delante del pecho, **de lado del todo** (90º, mirándote) y a ras de suelo: así mide
    2,45 de alto y abre la boca de lado sin dar en el suelo ni en el tablero (se comprueba cada fotograma con las
    esquinas de la cabeza, los colmillos, los dientes y la mandíbula; si no cabe, abre menos). Al olfatear sube un poco
    si cabe y da golpes de nariz de lado.
  - Con el hueco por debajo de 2,7 no mete la cabeza (el frente del lomo se queda a 3,7 del borde): solo el brazo.
  - No mete la cabeza en lo que choque a su altura (patas de la mesa, la viga de la cocina): rayos de lado al empezar.
  - Si te pilla (`rugir`, `b.pilla`): se queda aplastada 2,5 s con la boca abierta del todo (0,55) y temblando.
  - Al dejarlo se levanta por el mismo camino y **se queda echada atrás** hasta que echa a andar (de vuelta en su
    sitio, la pose de siempre metería los brazos por el tablero: ver Riesgos); mientras, su vida de espera sigue.
  - Los chorretones de sangre del vientre y de la boca se esconden aplastada (`LocalTransparencyModifier`): si no,
    atravesarían el suelo.
  - Sonidos: al aplastarse, `Paso` grave fuerte, temblor y gruñido; en cada tirón, `Aranazo` en la mano, `Cruje` en el
    borde y un temblor flojo; al olfatear, resoplido y vaho (de noche). Con Rendimiento: sin arañar, sin temblor de la
    cabeza ni olfateo, y solo el golpe (con su temblor) y los arañazos.

## Falta

- Probarlo en Studio (pasos abajo) y retocar a ojo: lo deprisa del salto atrás (`Cae` 0,6 s; con el borde a 1,5 se
  aparta ~4 studs), el aspecto de la cabeza de lado y la luz (no lleva luz en la cara, como el Imitador).
- Párrafo para `docs/sistemas/bichos.md` (lo pone el principal).

## Riesgos

- Su pose de siempre ya atraviesa el tablero si el servidor la para cerca: de pie apoya los nudillos a ~3,6 por
  delante de la raíz. Caza la para a 3 de la zona Debajo, que en el comedor está 1,4 (lado) o 2 (punta) dentro del
  tablero: el borde queda a ~1-1,9 de la raíz y los brazos ya cruzan el tablero antes de gatear (hasta ~2 studs). El
  gateo lo quita en ~0,1 s (se echa atrás) y al acabar se queda atrás. Arreglo en otro archivo: `FUERA_MUEBLE` de
  `servidor/Bestia.luau` a ~5.
- El brazo derecho (una pieza recta de 7 studs) puede atravesar una pata de la mesa o el caballete de la cocina al
  barrer (el banco lo mira aparte, como información).
- La cabeza de lado del todo, sin ver en Studio. Con el cuerpo de bloques puede quedar rara; si no convence, bajar
  `GATEO.Ladeo` (la boca abrirá menos bajo la mesa del comedor).
- Si el servidor mueve la raíz durante el gateo, todo va pegado a la raíz (se desliza con ella).
- Lune 0.10.5 construye mal `CFrame.lookAt` con vector de arriba propio: en las pruebas, `CFrame.fromMatrix`.

## Probar en Studio

1. Comprobar que Rojo ha sincronizado:
   `string.find(game.StarterPlayer.StarterPlayerScripts.Cliente.BestiaVista.Source, "aplastada")`.
2. Play. En el datamodel Server: `game.ServerStorage.Prueba:Fire("Noche")` y luego `Prueba:Fire("Bestia")`; que entre
   en casa (o ponerla a mano con `workspace.Bichos.Bestia:PivotTo(...)`).
3. Gateo a mano (Server), con el jugador agachado debajo de la mesa del comedor (x -25,5, z -17,7) y la Bestia quieta
   de cara a la mesa a ~2 studs del borde +X (borde en x ≈ -22,7):
   `local m = workspace.Bichos.Bestia; m.HumanoidRootPart.Anchored = true; m:PivotTo(CFrame.lookAt(Vector3.new(-20.5, 5.5, -17.7), Vector3.new(-25.5, 5.5, -17.7)))`
   y luego `m:SetAttribute("Gatea", game.Players:GetPlayers()[1].Character.HumanoidRootPart.Position); m:SetAttribute("GateaHora", workspace:GetServerTimeNow())`;
   a los 2 s `m:SetAttribute("Gatea", nil); m:SetAttribute("GateaHora", nil)`. Mirar: salto atrás, se aplasta, la
   cabeza de lado entra mirándote, el brazo barre hasta dejarte las garras al lado; nada atraviesa el tablero; al
   acabar se levanta y se queda atrás. Repetir en la cocina (x -19,5, z 6,9, Bestia en z ≈ 10,5 de cara a -Z).
4. Con Rendimiento (Ajustes): lo mismo, más simple. Y dejarse pillar: el susto con la cara de lado y la boca abierta.
