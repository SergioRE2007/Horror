# Clases (paso 10.2, base)

Números a ojo, en `Config.Ventajas` y `Config.Clases` (al final de `Config`; se guarda el `Id`: no cambiarlo, las nuevas al final).

- `shared/Stats`: única fuente de las ventajas, en el servidor y en el cliente. `Stats.valor(jugador, "Velocidad")` = lo de su clase o lo de `Config.Ventajas`. Cada ventaja se usa en un solo sitio:
  - Leñador: `Hachazo` (cada golpe cuenta 1,5) y `Troncos` (+1 del árbol que tumba), en `Recursos`.
  - Corredor: `Velocidad` ×1,2, en `Cargar.ajustarVelocidad` (al aparecer y al cambiar de clase).
  - Fotógrafo: `Recarga` ×0,6 y `Aturde` ×1,5 del flash, en `Equipo`.
  - Mecánico: `Trabajo` ×0,6, los segundos de todo lo de `Cargar.alUsar` (clavar tablones, montar piezas).
  - Carpintero: `Refuerzo` ×1,5 de la vida de más del tablón reforzado (`Casa`). No se guarda: al cargar la partida vuelve a la normal.
  - Explorador: `VerLlaves` = 70 studs: el cliente (`juego/cliente/ClaseVista`) marca las llaves sueltas a través de las paredes, solo para él.
- `comun/servidor/Clases`: la elegida va en los datos del jugador (`datos.clase`, "" = ninguna) y llega al juego con ellos (DataStore con candado), no con los datos del teletransporte. Al cargar, el servidor la publica en el atributo `Clase` del Player solo si `datos.clases[id] == true`. Remote `Clase` (id), solo en el lobby, para elegir una que ya tienes.
- Modo de pruebas: `Config.Test.Clase` = un Id fuerza esa clase en Studio aunque no esté comprada.

## Probado en Studio (22-10-2026)

- Sin clase velocidad 16; Corredor 19,2; Explorador marca una llave a 40 studs y no a 120. Sin errores.

## Pendiente

- Comprar y elegir: hecho en la tienda (`docs/sistemas/tienda.md`).
- Sin probar en Studio: hachazos del Leñador, flash del Fotógrafo, tiempos del Mecánico y tablón del Carpintero (una línea cada uno con `Stats`).
