# Esconderse agachado: el gateo del Imitador y del Golpeador

Pedido por el usuario (03-11-2026): "agacharte también debería servir para esconderte, por ejemplo debajo de mesas, y que el monstruo pueda gatear si te huele con una animación guapa para pillarte debajo de sitios… que sea útil agacharte es la finalidad". Archivos: `src/juego/cliente/ImitadorVista.luau` y `src/juego/cliente/GolpeadorVista.luau`. Notas viejas (solo lectura): `bichos1.md`, `bichos2.md`.

## Hecho

- El fallo gordo, en los dos: medían la mesa con rayos hacia arriba, y en el juego los muebles y sus cajas `Choque` tienen `CanQuery = false`: los rayos no daban nunca. El Golpeador ponía el borde a ojo y el Imitador lo daba a 1,6 de ti con el tablero a 2,85: los dos se metían por la mesa. Ahora el tablero sale de la zona `Debajo` en la que estás y del atributo `Tam` del mueble (`cajaTablero`, igual en los dos); los rayos quedan solo si no estás en ninguna zona (en el juego no gatea entonces).
- Golpeador:
  - Patas: busca las cajas `Choque` de la casa bajo el tablero (`patasDe`, una vez por gateo). Los brazos giran como rumbos por fuera, sin pasar por ninguna pata (se quedan en su canto, `BRAZO`). La cabeza no pasa de la primera pata o travesaño que tenga delante (la viga baja de la cocina) y se ladea hacia el lado sin pata (`CABEZA_FONDO`).
  - De pie junto a la mesa (llegando, al echarse y al levantarse) sus brazos larguísimos se metían 1,7 studs en el tablero: `apartarBrazos` los echa atrás desde el hombro lo justo, sin meterlos en el suelo (`APARTA`; la mesa cercana se mira cada 0,5 s).
  - Al acabar: saca la cabeza, recoge el brazo que metía (como mucho `GATEO.Recoge` 0,5 s) y luego se levanta; la cara se aparta algo más del borde al echarse y levantarse (`GATEO.Aparta`). Tope en `final`: con una pata justo delante, `math.clamp` daba error.
- Imitador: el brazo pasa por fuera de la esquina de abajo del tablero (antes miraba a 0,25 de lo de abajo, y el tablero es más gordo); el borde del brazo se mide por su lado (`bordeBrazo`) y el del cuerpo también a 1,5 de cada lado; los hombros no bajan tanto que la cadera se meta en el suelo (`GATEO.Cadera`); al acabar saca mano y cabeza (`GATEO.Recoge` 0,35 s) y luego se levanta; la boca con algo más de margen al chillar.
- Vida de espera: se pausa mientras gatea y vuelve suave (Golpeador: `gateando` → `vida` a 0; Imitador: `enPuerta` falso con `b.gateo`). Si te pilla (`rugir`) se queda en la pose (comprobado: la cara se mueve 0,01-0,03 en 1,9 s).
- Rendimiento: sin adornos ni ruidos de más; lo que se añade (apartar los brazos, medir patas) es poco y solo cerca de una mesa.
- Banco de Lune (fuera del repo): `scratchpad/imitador/banco.luau` de la sesión, `lune run <ruta>/banco.luau Golpeador|Imitador [-traza]` desde la raíz. Monta las dos mesas como en `Mapa` (zona `Debajo`, `Tam`, cajas `Choque`) y mira cada fotograma: NaN, suelo, tablero, patas, saltos, de pie después, a qué distancia quedan la cara, la mano y el brazo, y si se queda quieto al pillarte. Casos: borde a 0,8 / 1,09 / 1,8 / 3 / 5 (cocina 1,86), de frente, al fondo, en diagonal a los dos lados, por las puntas, te pilla, Rendimiento, llega tarde, te escapas, 20 fps, mal girado. Resultado: Golpeador 52/52 bien; Imitador 49/52 y 3 avisos.

## Falta y riesgos

- Imitador a 0,8 del tablero y en diagonal (3 avisos): de pie ya se mete 0,1-0,3 en el tablero y el brazo izquierdo roza al echarse; en la cocina, 0,23 en un caballete. El servidor no le deja ahí (se para a 2,5 de la zona: 1,09 del tablero por los lados largos, 0,54 por las puntas, de frente). El Imitador no mira las patas (no le ha hecho falta de 1,09 para arriba).
- Lejos de la mesa no llegan a tocarte: el Golpeador mete la cara 0,55 bajo el tablero y su brazo barre hasta la pata; el Imitador mete la mano unos 2,3 por dentro del borde. Si estás al fondo de la mesa del comedor, la cara queda a ~2,6 y la mano a ~1,6 (te mata igual el servidor).
- Golpeador: la mesa se mira con las cajas `Choque` hijas de la casa; con StreamingEnabled, si no han llegado al cliente, el brazo no esquiva patas (el tablero sí, por la zona, que es Persistent).
- No probado en Studio (sin Studio en el contenedor): tamaños de cuerpo del banco copiados a mano de `Golpeador.crear` / `Imitador.luau`.

## Probar en Studio

1. Play. En la consola del servidor: `game.ServerStorage.Prueba:Fire("Noche")` y luego `Fire("Ataque", Vector3.new(-25.5, 1, -15))` para el Golpeador (con `Fire("Romper", Vector3.new(-25.5, 1, -15))` la ventana más cerca se rompe y entra antes) o `Fire("Imitador")` para el Imitador.
2. Agacharse debajo de la mesa del comedor (x -25,5, z -15) y, otra vez, de la de la cocina (x -19,5, z 6,9, entrando por +Z). `Player:GetAttribute("Cubierto")` debe ser `true`.
3. Al gatear, desde debajo: ni brazos ni garras ni cabeza asoman por el tablero ni por las patas (en la cocina, ni por los caballetes ni por la viga baja). Mirar de lado con la cámara libre en el cliente.
4. Golpeador de pie junto a la mesa antes de echarse y al levantarse: los brazos por detrás, no a través del tablero. Al acabar: saca la cabeza, recoge el brazo y se levanta.
5. Imitador: la mano entra por debajo del borde, sin cruzar el canto; al acabar saca mano y cabeza y luego se levanta.
6. Dejarse pillar: el bicho queda echado con la cara a ras de suelo durante la escena de muerte. Salir antes de los 2 s: se levanta suave y vuelve a su vida de espera sin tirones.
7. Repetir con Ajustes → Rendimiento.
