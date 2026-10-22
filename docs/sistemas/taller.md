# Taller, coche y final de la huida (paso 8)

Con bloques grises. Números a ojo, en `Config` (`Taller`, `Coche`, objetos y pesados nuevos al final de sus listas).

## Objetos nuevos

- Mochila: `Chatarra` 2×1 (por el mapa: 2 en el garaje, 1 en el sótano, 2 en la granja, 2 en el aserradero, 1 en el pueblo, 1 en la caseta del guarda y 1 en la del enterrador; el vendedor da 2 por 1 lata), `Trampa` 2×2, `Bateria` 2×1, `Radiador` 2×2.
- Pesados: `Rueda` (cilindro con llanta; una en el garaje y otra en el aserradero) y `TablonReforzado` (con flejes). Más bidones: uno en el garaje y otro en el granero.
- `Config.Pesados` lleva ahora `Nombre` (para el taller y Lang).

## Bancos (`Taller`, cliente `TallerUi`, lógica en `shared/Recetas`)

- Dos bancos de bloques (`Mapa.banco`, etiqueta `Banco`, atributo `Banco`): el del sótano (carpintería) y el del garaje (taller del coche). Prompt "Workbench" (E).
- Panel de papel oscuro abajo con esquina de sangre: título del banco y cada receta "LO QUE SALE: 2 × TABLÓN, 1 × CHATARRA" con HACER (apagada si no llega). Se cierra con CERRAR, al alejarte, al morir o al ponerte a trabajar.
- Lo que pide sale de la mochila o de las cosas pesadas sueltas junto al banco (`Taller.Radio`). Se trabaja unos segundos a martillazos con chispas (`Fabricar`); al acabar se vuelve a comprobar todo y se gasta. Lo pesado que sale aparece delante del banco; lo demás, a la mochila.
- Sótano: tablón reforzado (2 tablones + 1 chatarra) y trampa (2 chatarras + 1 tablón). Garaje: radiador (3 chatarras + 1 botella) y batería (4 pilas + 1 chatarra).
- Tablón reforzado (`Casa`, R como el tablón): deja la persiana o puerta como nueva y con ×1,75 de vida (`Config.Taller.Refuerzo`) hasta que el bicho la rompa (`Defensa.reforzar`). Se ve con dos tablones en aspa con flejes (por dentro de la ventana; en la hoja de la puerta, girando con ella).
- Trampa: se tira con G como cualquier objeto. Quieta en el suelo, al primer bicho que pasa a 3,5 studs lo deja quieto 6 s y se gasta (golpe y chillido). A los jugadores no les hace nada.

## Coche (`Coche`, cliente `HuidaVista`)

- Tu coche, destrozado y encerrado en el garaje (arañazos del bicho, capó abierto, ruedas de delante sobre ladrillos). Le faltan motor (el de delante de la casa, entre dos o arrastrado), 2 ruedas, batería, radiador y un bidón lleno de gasolina (`Config.Coche`).
- Lo pesado (motor, ruedas, bidón) con R llevándolo junto al capó: se pone en su hueco y se atornilla con una llave inglesa (`Montar`). Lo de la mochila con E en el capó ("Repair"), una pieza cada vez. Sin nada que montar avisa de lo primero que falta ("Al coche le falta el motor.").
- El portón del garaje se abre con E (interruptor a un lado del hueco) desde que la puerta del garaje está abierta: para meter el motor entre dos. Antes: "No se mueve."
- Con todo: "Escape" manteniendo E 2 s en la puerta del conductor. Se van los bichos, la partida se da por terminada (`Partida.terminada`, el Director ya no lanza ataques), todos se quedan quietos y ven la escena final (también los muertos) y vuelven al lobby.
- Escena final (17 s, todo local; esconde interfaz, carteles y personajes y lo devuelve aunque falle): portón que sube y faros que parpadean al encenderse → el coche sale y coge la carretera → de lado, el bicho sale del bosque rugiendo y lo persigue → desde delante, lo tiene encima y el coche acelera → fundido a negro, "HAS ESCAPADO" con la raya roja.

## Guardado

- `FormatoPartida` sin subir versión: `coche = { piezas, gasolina, porton }` (lo viejo sale sin arreglar), `refuerzo` en la casa y `final = "Huida"`. Lo fabricado se guarda como lo demás (suelto o en la mochila).
- Al huir se guarda con `final` y la ranura del dueño queda libre en el lobby; si se vuelve a ella, partida nueva.

## Arreglado de paso

- El motor arrastrado por uno solo se hundía en el suelo: desde el paso 5 lo que lleva uno no choca con nada, y eso incluía lo que se arrastra. Ahora solo deja de chocar lo que uno levanta del todo (`Cargar.rehacer`).
- `Cargar.alUsar` admite varios usos por tipo (el bidón: generador y coche) y lo que llevan entre varios lo usa uno y los demás lo sueltan. `Cargar.trabajar` es el "trabajar unos segundos" común (también Taller y Coche).

## Pruebas (modo de pruebas, `ServerStorage.Prueba`)

- `("Dar", tipo)`: le da eso al primer jugador (mochila o, si es pesado, delante). `("Arreglar")`: coche listo. `("Huir")`: huye el primer jugador.
- En Studio, el atributo `HuidaT` del Workspace (en el cliente) congela la escena final en ese segundo para revisar cada plano.

## Probado en Studio (22-10-2026)

- Banco del garaje: panel en español, radiador y batería hechos y gastado lo pedido. Montados en el capó con E; sin nada, "Al coche le falta el motor.".
- Llave del garaje abre la puerta; el portón no se mueve antes y sube después. Rueda y motor (arrastrado solo) montados con R; los ladrillos desaparecen. Bidón: depósito lleno y el bidón vacío cae al lado.
- Guardar → arreglar → Cargar: vuelve el coche como estaba al guardar (rueda, batería, radiador, gasolina).
- Banco del sótano: tablón reforzado (sale delante) y trampa (a la mochila). Tablón reforzado clavado en una ventana: 175/175 y tablones en aspa. Trampa tirada donde golpea el bicho: salta a los 8,6 s del ataque.
- Escena final de noche, plano a plano; al acabar vuelven cámara, interfaz y personajes. Tras huir no hay más ataques. Sin errores.
- Lune: 410 comprobaciones bien.

## Pendiente

- Sin probar: dos jugadores de verdad con el motor, volver al lobby tras huir (solo publicado), móvil.
- Recompensa e insignia del final (paso 10). Cerrojos del banco del sótano (el diseño los nombra; de momento solo tablón reforzado y trampa).
- Sonido propio de motor del coche, cepo y llave inglesa (ElevenLabs); ahora usa los provisionales.
