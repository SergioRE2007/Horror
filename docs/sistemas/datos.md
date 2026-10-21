# Base del proyecto y guardado

## Estructura

- Dos lugares, cada uno con su proyecto de Rojo: `juego.project.json` (puerto 34872) y `lobby.project.json` (34873). Se sirve uno cada vez: `rojo serve juego.project.json`.
- `src/shared` → `ReplicatedStorage.Shared`: `Config`, `Lang` + `LangEs`, `Remotes`, `Prueba`, `Rejilla` (la mochila, ver `mochila.md`).
- `src/comun/servidor` → `ServerScriptService.Comun` y `src/comun/cliente` → `StarterPlayerScripts.Comun`: lo que vale en los dos lugares (`Datos`, `Candado`, `Formato`, `Idioma`, `Limpieza`, `Viaje`; en el cliente `Ui`, `Avisos`, `Controles`).
- `src/juego/*` y `src/lobby/*` → `ServerScriptService.Servidor` y `StarterPlayerScripts.Cliente`: el `init` de cada lugar, que arranca sus sistemas con `start()`.
- `Limpieza` borra al arrancar todo lo suelto del Workspace y deja `workspace.Mapa` vacía; cada lugar pone ahí su mapa y su punto de aparición (`Mapa`, `Gasolinera`).
- Pedido por el usuario (parpadeos): dos caras de piezas distintas en el mismo plano parpadean al mover la cámara. `Separar.caras(carpeta)` (comun/servidor), al acabar de generar cada mapa, busca esas parejas y agranda 0,03 studs por cara una de las dos hasta que no quede ninguna (avisa con `warn` si quedan). El punto de aparición va encima del suelo, no a ras.

## Guardado del jugador

- `Datos` carga al entrar, guarda cada `Config.Guardado.Intervalo` y al salir guarda y suelta el candado; `BindToClose` guarda a todos a la vez y espera. Desde fuera: `Datos.leer`, `Datos.editar(jugador, fn)` (publica los atributos solo) y `Datos.guardar`. Nadie más escribe en ese DataStore.
- Clave `jugador_<userId>` con `{ datos, candado = { id, hora } }`. `Candado` (sin nada de Roblox) hace todo con `UpdateAsync`: al cargar coge el candado (si otra sesión viva lo tiene, reintenta cada `Reintento` s y a los `Espera` s echa al jugador; un candado sin renovar `Caduca` s se da por muerto), cada guardado lo renueva y solo escribe si sigue siendo suyo. Si otra sesión se ha quedado la partida, deja de guardar y echa al jugador.
- `Formato`: campos con nombre y `version`. `arreglarJugador` rellena lo que falte, arregla valores imposibles y es el sitio de los pasos de una versión a otra. Nunca borrar campos con datos.
- Atributos del `Player`: `Monedas`, `Partidas` (resumen de sus ranuras en JSON, lo apunta el juego al guardar la partida: ver `partida.md`), `DatosListos`, `Lang`.

## Modo de pruebas

- `Config.Test.Activo` solo actúa en Studio (`Prueba.activa()`): no se lee ni se guarda nada y se dan `Config.Test.Monedas`. `Config.Test.Lang` fuerza el idioma; el atributo `LangTest` del jugador local lo cambia en marcha.

## Pruebas

- `lune run tests/regressions.luau`: formato, candado con dos servidores sobre el mismo DataStore falso (ocupado, soltar, perdido, caducado, sin red), `Lang` y huecos de `LangEs`, remotes sin repetir.
- El candado de verdad necesita el juego publicado o el acceso de Studio a los servicios de API: sin probar en Studio.
