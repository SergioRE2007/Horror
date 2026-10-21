# Partida guardada, lobby, coches y viaje (paso 6)

Con bloques grises. Números a ojo, en `Config` (`Partida`, `Coches`).

## Lobby (`src/lobby`)

- `Gasolinera`: gasolinera vieja de noche junto a la carretera (x = 0, el bosque hacia -Z): marquesina con dos fluorescentes flojos, dos surtidores, la tienda (caja vacía con puerta; dentro irá la de clases y cosméticos), cartel rojo "GAS" que parpadea como un fluorescente viejo, bosque de troncos alrededor y 4 coches en `workspace.Coches` (etiqueta `Coche`, asientos `Asiento1..4`).
- `Coches` (servidor): prompt "Get in" (E) te sienta en el primer asiento libre. El primero que sube es el dueño; si se baja, lo es el siguiente que subió (y se vuelve a elegir de cero). El dueño elige ranura (1..`Ranuras`), si empieza de cero y arranca: cuenta atrás de `Salida` s y `Viaje.ir`. Atributos del coche: `Dueno`, `Ranura`, `Nueva`, `Salida`; del jugador: `Coche`. Remote `Coche`: ("Ranura", n), ("Nueva", bool), ("Arrancar"), solo del dueño.
- `CochesUi` (cliente): panel oscuro abajo con esquina de sangre. Dueño: las 3 ranuras ("1 NOCHE 4" / "VACÍA", la elegida con borde claro), NUEVA PARTIDA en una ranura guardada (dos toques; luego "SEGUIR CON LA GUARDADA") y EMPEZAR / CONTINUAR / EMPEZAR DE CERO. Los demás: "Esperando a {name}…". Cuenta atrás "SALÍS EN 3…", fundido a negro al salir; si el servidor para el coche (falla o Studio) vuelve la imagen. BAJAR (`Sit = false`: `Jump` desde un script no levanta del asiento).
- `Controles` pasó a `comun/cliente` (vale en los dos lugares). `Ui.mancha(panel)`: la esquina de sangre de los paneles.

## Viaje (`comun/servidor/Viaje`)

- Lobby: `ReserveServer` del lugar Juego, apunta en MemoryStore (`Config.Partida.Viajes`, clave = id del servidor privado, caduca en un día) `{ dueno, ranura, nueva, jugadores }` y `TeleportAsync` a todos juntos (un reintento).
- Juego: `Viaje.leer()` lo lee de MemoryStore (nunca de los datos del teletransporte, que pasan por el cliente). `Viaje.volver(jugadores, texto)`: aviso y de vuelta al lobby (sin lobby publicado, los echa con el texto; en Studio solo avisa).
- En Studio no hay teletransporte: el coche avisa "El teletransporte no funciona en Studio." y el lugar Juego arranca con el dueño falso de `Config.Test` (`Dueno` = nil → el primero que entra, `Ranura`, `Nueva`).

## Partida (`juego/servidor/Partida` y `FormatoPartida`)

- Clave `partida_<dueño>_<ranura>` en `Config.Partida.Almacen`, con el mismo `Candado` que los jugadores. Al arrancar el servidor: `Viaje.leer`, echa a quien no venía en el coche, coge el candado (si otro servidor la tiene, espera `Guardado.Espera` y vuelven al lobby), deja el mundo como estaba y devuelve la noche para `Ciclo.start(noche)`.
- Al amanecer (también al empezar y tras morir todos) hace una foto de todo y la guarda; cada `Guardado.Intervalo` vuelve a guardar la misma foto para renovar el candado. Lo del día no cuenta: si mueren todos se vuelve a la foto (`Partida.volverAlAmanecer`, lo llama `Director`) y si os vais queda la última foto (pedido por el usuario).
- Lo que se guarda (`FormatoPartida`, versión 1): noche, semilla (para las llaves, paso 7), casa (`[Clave] = vida, persiana, cristal, abierta, bloqueada`), árboles talados (`[Clave] = noche`), generador (gasolina, encendido, móvil del enchufe), objetos y pesados sueltos (`tipo`, `carga`, `sitio` = posición y giro), mochilas (`[UserId] = { cosas }`). `arreglar` limpia datos rotos o trucados (tipos que no existen, números imposibles, cosas caídas del mapa, como mucho `Sueltos` de cada clase) y es el sitio de los pasos entre versiones.
- Claves fijas que salen de la posición (`Mapa`: V/P/A + x_y_z redondeados): añadir cosas al mapa no descoloca lo guardado. Ventanas de arriba y de abajo comparten x y z: por eso lleva la y.
- Cada sistema exporta e importa lo suyo: `Casa.exportar/importar`, `Recursos.exportar/importar` (tocón sin caída), `Generador.exportar/importar`, `Mochila.exportar/importar` (nil = la de empezar; lo que no cabe, a sus pies), `Mochila.sueltos/importarSueltos`, `Cargar.sueltos/importar` (todos sueltan lo que llevan). El móvil del enchufe lleva el atributo `Enchufado`: lo guarda Generador, no como suelto.
- Mochilas: son de cada jugador dentro de la partida y se guardan aunque no venga esa vez. Lo que lleva el que se va cae al suelo y en la siguiente foto ya no es suyo (para no duplicar). Si vuelve en la misma sesión, mochila vacía (lo suyo está en el suelo).
- Dueño que se va: aviso a los demás y, si no vuelve en `EsperaDueno` s, se acaba para todos con la última foto.
- Cada guardado apunta en los datos del dueño `partidas["<ranura>"] = { noche, hora }` (atributo `Partidas` del jugador, en JSON): es lo que enseña el lobby.
- Cuidados (de la revisión del código): `op` solo se pone cuando el candado ya es nuestro (un cierre a media carga borraría la partida); si el dueño no llega nunca (le falló el teletransporte), a los `EsperaDueno` s se acaba; tras volver al amanecer, los que se fueron recuperan su mochila de entonces; guardar y volver al lobby no frenan el ciclo ni el arranque.
- Modo de pruebas: almacén de mentira en memoria (pasa por JSON). `ServerStorage.Prueba:Fire("Guardar")` hace la foto y la guarda ya; `("Cargar")` la relee y la pone. `Config.Test.Partidas` = las ranuras que enseña el lobby en Studio.

## Probado en Studio (21-10-2026)

- Juego: 64 claves sin repetir. Puerta principal rota, árbol marcado talado, hacha movida, lata quitada, bidón movido, carrete tirado de la mochila y generador arrancado tirando de la cuerda → Guardar. Luego se tira una pila, se quita la botella y se mueve el motor → Cargar: puerta a 0, tocón sin tronco, objetos y bidón como al guardar, 2 pilas y sin carrete en la mochila, generador encendido. Sin errores.
- Lobby: subir al coche (dueño), panel con "1 NOCHE 4", cambiar de ranura (la 7 no vale), NUEVA PARTIDA con dos toques, cuenta atrás, fundido y aviso de Studio; bajar del coche. Sin errores.
- Lune: 258 comprobaciones bien (formato nuevo, roto y viejo, tope de sueltos, mochila con tipos que ya no existen, candado de la partida con dos servidores, resumen de ranuras).

## Pendiente

- Sin probar (solo funciona publicado): reservar servidor, MemoryStore, teletransporte de ida y vuelta, DataStore real de la partida, dueño que se va con otros dentro. `Config.Lugares` sigue a 0.
- Sin probar en Studio: volver al amanecer al morir todos (usa el mismo `aplicar` que Cargar), dos jugadores en el coche (el que no es dueño).
- Monedas al amanecer (paso 10). Lluvia del lobby, cinemáticas del coche (salida del lobby y llegada a la casa) y volver a una partida tras un corte (el dueño no puede volver a entrar a un servidor reservado: haría falta que el lobby lo mande de vuelta).
- Para probar el lobby en el mismo Studio: `rojo serve lobby.project.json --port 34872` y Rojo → Connect (el lugar se genera entero por código).
