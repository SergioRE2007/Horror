# raspador: gateo del Raspador

Archivo: `src/juego/cliente/RaspadorVista.luau` (solo cliente: mueve la Transform de sus Motor6D). Nada visto en
Studio: comprobado con un banco de Lune que carga el módulo con un Roblox de mentira, el cuerpo de `Raspador.crear` con
sus adornos y las dos mesas de `Mapa` (`HUECOS` y el `Tam` de `src/muebles/Muebles.rbxm`), y mira cada fotograma.
El banco está en el scratchpad de la sesión, fuera del repo
(`/tmp/claude-0/-home-user-Horror/5efe865c-d18d-5ef8-9502-0fff6029e7d4/scratchpad/raspador/banco.luau`, se lanza desde
la raíz del repo con `lune run <ruta>`): si se pierde, se rehace.

## Hecho (commit 1d7eb52)

- **Gateo** (pedido por el usuario: "que el monstruo pueda gatear si te huele… para pillarte debajo de sitios"), con
  `Gatea` y `GateaHora` en su modelo, mismo contrato que el Golpeador:
  - Se echa boca abajo despacio (0,6 s): la cara se echa atrás hasta quedar por fuera del borde y baja hasta apoyarse
    en el suelo; el torso pasa de inclinado a tumbado (la cadera nunca por debajo de 0,62) y las piernas quedan a
    rastras detrás (levantadas si detrás hay una pared, mirada con un rayo).
  - Echado del todo, se arrastra a tres tirones: entre uno y otro las manos se adelantan y husmea; en el tirón se
    quedan clavadas y el cuerpo se arrastra hacia ellas, balanceándose un poco.
  - El cuello estirado; la cara ladeada (~75°, su manía) a ras de suelo, mirándote, a ~0,9 de ti al final. Si la
    cabeza o la boca abierta fueran a tocar el suelo, la cabeza sube lo justo.
  - Brazos por cinemática 3D: el codo fuera y arriba (como una araña) o plegado hacia atrás si así no choca. Una mano
    llega a tu lado (a 1,15) y araña el suelo a tirones (arrastra las uñas, las levanta, las clava más allá); la otra se
    apoya junto a la cara. Las uñas nunca bajan del suelo.
  - Al acabar, sale arrastrándose hacia atrás (0,5 s) y se levanta (0,9 s). Si te pilla (`rugir`), se queda en el
    suelo 2,2 s con la boca abierta del todo.
  - Ruidos con lo que ya hay: al echarse Paso grave y Cruje (el cuello); en cada tirón Paso y Aranazo; en el último,
    además un Chillido grave cortado.
  - Mientras gatea, la vida de espera se pausa. Con Rendimiento: seguido, sin husmear ni arañar ni balanceo, y solo
    los ruidos de echarse y del final.
- **El tablero se saca de la zona Debajo** en la que está el escondido (CollectionService) y del atributo `Tam` de su
  mueble: las piezas de los muebles y sus cajas de choque tienen `CanQuery = false`, así que los rayos hacia arriba no
  las ven. Si el pivote del mueble no cuadra con la zona, se da por hecho que el tablero sobresale 2 por cada lado.
  Sin zona, el borde a 0,5 de la raíz.
- Banco de Lune (59 casos, todos bien): mesa del comedor (lado largo, puntas, tú cerca o al fondo) y de la cocina, con
  el borde a 1,09 (donde le deja el servidor en el comedor), 1,4, 1,8, 2,06 (el de la cocina), 2,2 y 3 studs, en
  diagonal (2 y 3,5 de lado), mal girado 15°, a 20 fps, con Rendimiento, llegando tarde, escapándote a 1 y 1,5 s, si te
  pilla, con pared detrás, sin pivote y sin zona. En ningún fotograma (también al echarse y al levantarse): NaN, nada
  por debajo del suelo, nada en el tablero más de lo que ya se mete de pie en ese sitio; vuelve de pie. La cara acaba a
  1,0-1,25 del suelo, a 24-32° de tu cabeza. Cuesta ~0,2 ms por fotograma (Lune).

## Falta

- Verlo en Studio (pasos abajo).
- Párrafo para `docs/sistemas/bichos.md` (lo pone el principal; texto en el resultado del agente).

## Riesgos

- **De pie, sus brazos cuelgan ~0,7 por delante.** El servidor le para a 2,5 de la zona (`Caza`, `FUERA`): en el
  comedor eso es 1,09 del borde del tablero por el lado largo y 0,54 por las puntas, y ahí, en diagonal, sus brazos de
  pie ya se meten en el canto del tablero (hasta 0,22) antes y después de gatear. El gateo no lo empeora. Arreglo
  propuesto (otro archivo): `Fuera = 3.4` en las opciones de `Caza.nuevo` de `servidor/Raspador.luau`.
- **Patas:** con el hueco estrecho (puntas del comedor, cocina) o en diagonal, un codo o un antebrazo puede rozar una
  pata o el caballete de la cocina (hasta ~0,7). Con la mano a ~3 del hombro el codo tiene que salir 2,65 hacia algún
  lado y solo cabe de lado; se prefiere eso a meterlo en el tablero o en el suelo.
- Echado mide ~12 studs (la cadera ~4,5 detrás de la raíz): si hay una pared muy cerca detrás, las piernas se levantan
  pero el torso puede meterse en ella. En el comedor y la cocina hay más de 10 studs detrás.
- Las sillas no se miran (no se ven con rayos): un brazo puede atravesar una silla.
- El mantel del comedor cuelga y no choca: la cabeza lo atraviesa al entrar (como el jugador).
- **Golpeador** (otro archivo): su `buscarBorde` lanza rayos hacia arriba que no ven los muebles (`CanQuery = false`),
  así que siempre usa el valor por defecto. Se puede copiar `tablero` y `buscarBorde` de aquí.

## Probar en Studio

1. Play. En el datamodel Server: `game.ServerStorage.Prueba:Fire("Noche")` y
   `game.ServerStorage.Prueba:Fire("Raspador", Vector3.new(25, 0, -40))`.
2. Llevar al Raspador junto a la mesa del comedor, a 1,8 del borde del lado largo, mirándola (Server):
   `local b = workspace.Bichos.Raspador; b.HumanoidRootPart.Anchored = true;`
   `b:PivotTo(CFrame.lookAt(Vector3.new(-30.1, 5.2, -15), Vector3.new(-25.5, 5.2, -15)))`.
3. Tu personaje agachado debajo de la mesa, en (-26.1, 3, -15), mirando hacia -X.
4. Gateo a mano (Server): `b:SetAttribute("GateaHora", workspace:GetServerTimeNow()); b:SetAttribute("Gatea", Vector3.new(-26.1, 3, -15))`.
   A los 2 s: `b:SetAttribute("Gatea", nil); b:SetAttribute("GateaHora", nil)`. Mirar: que se eche boca abajo sin
   meter la cabeza ni los codos en el tablero, que la cara entre ladeada a ras de suelo mirándote, que la mano llegue a
   tu lado arañando y que al final salga y se levante. Repetir con Rendimiento y en diagonal
   (`b:PivotTo(CFrame.lookAt(Vector3.new(-30.1, 5.2, -11.5), Vector3.new(-26.1, 5.2, -15)))`).
5. Cocina: raíz en `Vector3.new(-19.5, 5.2, 10.4)` mirando a `Vector3.new(-19.5, 5.2, 6.9)`; tú en (-19.5, 3, 7.0).
6. NaN (Client): `for _, p in workspace.Bichos:GetDescendants() do if p:IsA("BasePart") and p.Position.X ~= p.Position.X then print(p:GetFullName()) end end`.
7. Al acabar: `b.HumanoidRootPart.Anchored = false`.
