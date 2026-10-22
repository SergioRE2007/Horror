# Llaves, salas cerradas, pueblo y vendedor (paso 7)

Con bloques grises. Números a ojo, en `Config` (`Llaves`, `BrilloLlave`, `Vendedor`).

## Salas cerradas (`Mapa`)

Puertas con `Bloqueada` y `Llave` (el tipo de llave que la abre). De más cerca a más lejos (pedido por el usuario):
- **Sótano** (llave en la granja): puerta del fondo del pasillo (z = 22) → escalera tapada que baja bajo el patio → sala bajo tierra (x -12..12, z 36.6..54.6, suelo en y = -11). El suelo del bosque va en 4 trozos con un hueco encima de la escalera (`HUECO`). Banco de carpintería (paso 8, `taller.md`).
- **Garaje** (aserradero): edificio al este de la casa (x 34..52, z -14..6), puerta con llave mirando a la casa y portón al camino; dentro, tu coche y el banco del taller (paso 8, `taller.md`).
- **Desván** (torre): puerta en el rellano de arriba (x = -6, z ≈ 19) → cuarto con 13 peldaños que suben por un hueco del techo hasta el desván, bajo el tejado (hastiales de cuñas, cuarto de revelado).
- **Habitación del rico** (cementerio): la que ya estaba arriba, ahora con escritorio y caja fuerte provisionales.

`Casa`: con la llave en la mochila, E abre la puerta y la gasta ("La llave abre la puerta."); si no, sacude el pomo. La puerta abierta ya deja pasar al bicho (`PathfindingModifier`, lo pone `Casa.publicar` según `bloqueada`).

## Llaves (`Llaves`, `Reparto`, `shared/Azar`)

- Objetos de mochila 1×1 con `Llave = true` (`LlaveSotano`, `LlaveGaraje`, `LlaveDesvan`, `LlaveRico`). Latón con un brillo flojo (`PointLight`, `Config.BrilloLlave`; pedido por el usuario).
- Cada zona da 4 sitios posibles (`Mapa.llaves`, los pone `Lugares`); el sitio sale de `Azar.entero(semilla, orden, …)`: siempre el mismo en la misma partida y en cualquier servidor (no usa `Random`).
- Si mueres con una llave, se cae donde mueres (pedido por el usuario).
- `Llaves.repasar(semilla, mochilasGuardadas)` lo llama `Partida` al empezar una partida nueva, al cargar (`aplicar`) y al amanecer: la llave de una sala aún cerrada que no está suelta ni en la mochila de alguien que está vuelve a su sitio. A los que no han venido se les quitan las llaves de su mochila guardada (nadie se queda la llave fuera ni la duplica al volver). Las cuentas, en `Reparto` (sin Roblox, probado con Lune).
- Se guarda todo con la partida sin cambiar el formato: sala abierta = `bloqueada` de la puerta, llave suelta = objeto suelto, llave en la mochila = mochila.

## Lugares (`Lugares`)

Edificios de una sala con `edificio(...)` (suelo con `EnMapa` para el móvil). El bosque no pone árboles en las zonas (`Lugares.libre`); los troncos grandes cuentan igual para no mover los de fuera.
- Granja (205, 75): casa, granero con paja, campo, caja. 2 latas y 1 botella.
- Aserradero (-230, -90): nave abierta con sierra, tablones, estante, troncos y oficina. 1 botella.
- Torre (90, 300): colina (bola de 140) con la torre; se sube por una escalera de 44 peldaños hasta la caseta de arriba (las escaleras de mano `TrussPart` fallaban al cogerlas). Caseta del guarda al pie.
- Pueblo al final de la carretera (ahora llega a z -530): tienda con el vendedor, casa con la puerta rota (1 lata, 2 botellas), 3 casas tapiadas, iglesia con campanario y cementerio (tumbas, cripta, caseta del enterrador).

## Vendedor (`Vendedor`, cliente `VendedorUi`)

- Viejo de bloques detrás del mostrador (etiqueta `Vendedor`), prompt "Cambiar" (E). Cada vez dice una frase de aviso (pedido por el usuario: "No salgas de noche", "No te quedes en la casa del rico"…).
- Trueque (pedido por el usuario: pide comida y agua): 2 pilas por 1 lata, 1 carrete por 1 botella, linterna por 2 latas, hacha por 2 botellas. Con llaves no se comercia (lo comprueba Lune).
- Panel de papel oscuro abajo con esquina de sangre: la frase, los 4 tratos (apagados si no te llega) y CERRAR; suelta el ratón (`Modal`) y se cierra al alejarte (`Alcance`) o morir. Remote `Vendedor`: servidor → ("Abrir", frase); cliente → ("Cambiar", n). El servidor valida vivo, cerca y que lleve lo que pide; lo que no cabe cae a sus pies (`Mochila.dar`).

## Probado en Studio (22-10-2026)

- Las 4 llaves salen en su zona. Coger la del garaje, abrir la puerta (se gasta y se abre). Morir con la del sótano: cae a 3 m. Guardar → morir → Cargar: la llave vuelve a la mochila, garaje abierto, sótano cerrado. Llave perdida + guardar + cargar: vuelve a su sitio exacto.
- Andando: se sube la torre, la escalera del desván desde su puerta y se baja al sótano.
- Vendedor: coger una lata del pueblo, hablarle, cambiarla por 2 pilas; sin lata no da nada; el panel se cierra al irse. En español.
- Lune: 316 comprobaciones bien.

## Pendiente

- Comida y agua sin uso aún más que el trueque (hambre más adelante). Contenido del desván y la habitación del rico (revelado, diario), paso 12.
- El bicho no entra en el sótano, el garaje ni el desván (no son salas de `Mapa.salas`).
