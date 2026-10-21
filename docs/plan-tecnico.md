# Plan técnico (octubre de 2026)

El diseño está en `docs/diseño.md`. Aquí, cómo se construye. Cada sistema tendrá su `docs/sistemas/<sistema>.md` al hacerse.

## Lugares

Una experiencia con dos lugares, cada uno con su archivo de Rojo y `src/shared` común:
- **Lobby** (`lobby.project.json`): gasolinera, coches para formar grupo, elegir partida, tienda de clases y cosméticos.
- **Juego** (`juego.project.json`): la casa, el bosque y el pueblo. Un servidor privado por grupo (`TeleportService:ReserveServer`).

El servidor del lobby guarda en `MemoryStoreService`, con la clave del id del servidor privado, quién es el dueño, qué ranura y quiénes van. El servidor del juego lo lee de ahí: nunca se fía de los datos de teletransporte, porque pasan por el cliente. En Studio el teletransporte no funciona: el lugar Juego arranca solo con un dueño falso en `Config.Test`.

## Guardado (DataStores con candado de sesión, siempre `UpdateAsync`)

- **Jugador** (`jugador_<userId>`): monedas, clases, cosméticos, logros, récords, resumen de sus partidas, compras ya entregadas (`PurchaseId`, para no dar dos veces).
- **Partida** (`partida_<userId>_<ranura>`): noche, estado de la casa (tablones, salas abiertas, daños), recursos guardados, piezas del coche, pistas y semilla del azar (dónde están las llaves). Solo escribe el servidor que la tiene abierta, con su propio candado.
- Cada guardado lleva `version` y campos con nombre. Lo nuevo se añade sin romper lo viejo.
- Las monedas ganadas se guardan en cada jugador al amanecer, aunque luego la partida no se guarde.

## Sistemas (un módulo con `start()` cada uno)

- **Compartido:** `Config`, `Lang`, `Remotes`, `Stats` (ventajas de clases, pases y mejoras), `Rejilla` (lógica de la mochila sin Roblox, para probarla con Lune), `Azar` (con semilla).
- **Servidor del lobby:** `Datos`, `Grupos` (coches), `Viaje` (reservar y teletransportar), `Tienda`, `Compras`.
- **Servidor del juego:** `Datos`, `Partida` (cargar, guardar al amanecer, dueño que se va), `Ciclo` (día y noche), `Dificultad` (tabla por número de jugadores), `Casa` (puertas, ventanas, persianas, tablones, salas cerradas), `Director` (decide qué bicho ataca y dónde) + un módulo por bicho, `Muerte` (escondites, pillar, mirar hasta el amanecer, revivir), `Mochila`, `Cargar` (objetos pesados con física), `Recursos` (talar, objetos por el mapa), `Llaves`, `Vendedor`, `Generador`, `Taller` (recetas del sótano y el garaje), `Coche` (reparación y final de la huida), `Pistas`, `Clases`, `Recompensas`, `Compras`, `Mapa` (genera terreno y edificios por código).
- **Cliente:** `Ui` (helpers del estilo oscuro), `Controles` (botón de acción que cambia, móvil, mando), `MochilaUi`, `Movil` (mapa y batería), `Linterna`, `Sonido` (ambiente por capas, 3D), `Efectos` (temblores, polvo, cristales), `Sustos`, `Ambiente` (luz, niebla, clima), `Ajustes` (Rendimiento).

El servidor manda en todo: los bichos, la mochila, lo que se coge y lo que se compra. El cliente solo pide y anima.

## Pruebas

- Lune (`tests/regressions.luau`): rejilla de la mochila, guardado y cambios de versión, tabla de dificultad, trueque, compras sin duplicar.
- Studio: `Config.Test` (sin guardar, todo desbloqueado, noche rápida), probando con 1 y 2 jugadores y con vista de móvil.

## Orden de construcción

Primero que se juegue y dé miedo con bloques grises; el arte, al final. Pero las animaciones de lo que se toca (puertas, persianas, talar, clavar) se hacen ya en cada paso, aunque sea sobre bloques grises: el juego debe sentirse interactivo desde el principio (pedido por el usuario).

1. **Base:** Rojo con los dos lugares, `Config`, `Lang`, `Remotes`, `Datos` con candado, pruebas de Lune, modo de pruebas.
2. **El corazón:** casa gris, ciclo de día y noche, Golpeador, persianas, esconderse y morir. Probar si da tensión.
3. Raspador, linterna con pilas, flash y dificultad por jugadores.
4. Mochila de casillas, objetos y cargar cosas pesadas.
5. Bosque gris, talar, tablones, generador y móvil con mapa.
6. Guardado de la partida, lobby, coches y viaje.
7. Llaves, salas cerradas, pueblo y vendedor.
8. Taller, coche y final de la huida.
9. Resto de bichos (Trepador, Imitador, Acechador).
10. Clases, monedas, tienda, revivir y compras.
11. Arte: casa y bosque con Blender, monstruos con IA, sonidos con ElevenLabs.
12. Final difícil (La Bestia) e historia con pistas.
13. Tutorial, nombre, iconos y lanzamiento en privado.
