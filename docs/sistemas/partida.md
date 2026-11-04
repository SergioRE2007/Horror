# Partida guardada, lobby, coches y viaje (paso 6)

Con bloques grises. Números a ojo, en `Config` (`Partida`, `Coches`).

## Lobby (`src/lobby`)

- `Gasolinera` y los suyos: la gasolinera vieja de noche junto a la carretera, con lluvia, la tienda dentro y 4 coches en `workspace.Coches` (etiqueta `Coche`, asientos `Asiento1..4`). Rehecha en 14.7: ver `lobby.md`.
- `Coches` (servidor): prompt "Get in" (E) te sienta en el primer asiento libre. El primero que sube es el dueño; si se baja, lo es el siguiente que subió (y se vuelve a elegir de cero). El dueño elige ranura (1..`Ranuras`), si empieza de cero y arranca: cuenta atrás de `Salida` s y `Viaje.ir`. Atributos del coche: `Dueno`, `Ranura`, `Nueva`, `Salida`, `Llegada`; del jugador: `Coche`. Remote `Coche`: ("Ranura", n), ("Nueva", bool), ("Arrancar"), solo del dueño; Ranura y Nueva, como mucho una petición cada 0,2 s. Tras un viaje que sale bien, cuando el coche se vacía llega otro por la carretera (`Llegada`, 22 s, sin poder subir; 14.9.3) y luego queda libre (antes se quedaba inservible para siempre en ese servidor). Por el carril, de uno en uno: ver `lobby.md`.
- `CochesUi` (cliente): ver `lobby.md` (Interfaz). BAJAR (`Sit = false`: `Jump` desde un script no levanta del asiento); al bajarte sales de pie junto a la puerta.
- `Controles` pasó a `comun/cliente` (vale en los dos lugares). `Ui.mancha(panel)`: la esquina de sangre de los paneles.

## Viaje (`comun/servidor/Viaje`)

- Lobby: `ReserveServer` del lugar Juego, apunta en MemoryStore (`Config.Partida.Viajes`, clave = id del servidor privado, caduca en un día) `{ dueno, ranura, nueva, jugadores }` y `TeleportAsync` a todos juntos (un reintento).
- Juego: `Viaje.leer()` lo lee de MemoryStore (nunca de los datos del teletransporte, que pasan por el cliente). `Viaje.volver(jugadores, texto)`: aviso y de vuelta al lobby (sin lobby publicado, los echa con el texto; en Studio solo avisa). Si la vuelta falla al llegar (`TeleportInitFailed`), se reintenta una vez y si no se echa al jugador con el texto.
- En Studio no hay teletransporte: el coche avisa "El teletransporte no funciona en Studio." y el lugar Juego arranca con el dueño falso de `Config.Test` (`Dueno` = nil → el primero que entra, `Ranura`, `Nueva`).

## Partida (`juego/servidor/Partida` y `FormatoPartida`)

- Clave `partida_<dueño>_<ranura>` en `Config.Partida.Almacen`, con el mismo `Candado` que los jugadores. Al arrancar el servidor: `Viaje.leer`, echa a quien no venía en el coche, coge el candado (si otro servidor la tiene, espera `Guardado.Espera` y vuelven al lobby), deja el mundo como estaba y devuelve la noche para `Ciclo.start(noche)`.
- Al amanecer (también al empezar y tras morir todos) hace una foto de todo y la guarda; cada `Guardado.Intervalo` vuelve a guardar la misma foto para renovar el candado. Lo del día no cuenta: si mueren todos se vuelve a la foto (`Partida.volverAlAmanecer`, lo llama `Director`) y si os vais queda la última foto (pedido por el usuario).
- Lo que se guarda (`FormatoPartida`, versión 1): noche, semilla (para las llaves, paso 7), casa (`[Clave] = vida, persiana, cristal, abierta, bloqueada`), árboles talados (`[Clave] = noche`), generador (gasolina, encendido, móvil del enchufe), objetos y pesados sueltos (`tipo`, `carga`, `sitio` = posición y giro), mochilas (`[UserId] = { cosas }`). `arreglar` limpia datos rotos o trucados (tipos que no existen, números imposibles, cosas caídas del mapa, como mucho `Sueltos` de cada clase) y es el sitio de los pasos entre versiones.
- Desde el paso 8 (sin subir versión): `coche`, `refuerzo` en la casa y `final` (ver `taller.md`). `Coche.exportar/importar`.
- Claves fijas que salen de la posición (`Mapa`: V/P/A + x_y_z redondeados): añadir cosas al mapa no descoloca lo guardado. Ventanas de arriba y de abajo comparten x y z: por eso lleva la y.
- Cada sistema exporta e importa lo suyo: `Casa.exportar/importar`, `Recursos.exportar/importar` (tocón sin caída), `Generador.exportar/importar`, `Mochila.exportar/importar` (nil = la de empezar; lo que no cabe, a sus pies), `Mochila.sueltos/importarSueltos`, `Cargar.sueltos/importar` (todos sueltan lo que llevan). El móvil del enchufe lleva el atributo `Enchufado`: lo guarda Generador, no como suelto.
- Mochilas: son de cada jugador dentro de la partida y se guardan aunque no venga esa vez. Lo que lleva el que se va cae al suelo y en la siguiente foto ya no es suyo (para no duplicar). Si vuelve en la misma sesión, mochila vacía (lo suyo está en el suelo).
- Dueño que se va: aviso a los demás y, si no vuelve en `EsperaDueno` s, se acaba para todos con la última foto.
- Cada guardado apunta en los datos del dueño `partidas["<ranura>"] = { noche, hora }` (atributo `Partidas` del jugador, en JSON): es lo que enseña el lobby.
- Cuidados (de la revisión del código): `op` solo se pone cuando el candado ya es nuestro (un cierre a media carga borraría la partida); si el dueño no llega nunca (le falló el teletransporte), a los `EsperaDueno` s se acaba; tras volver al amanecer, los que se fueron recuperan su mochila de entonces; guardar y volver al lobby no frenan el ciclo ni el arranque.
- Modo de pruebas: almacén de mentira en memoria (pasa por JSON). `ServerStorage.Prueba:Fire("Guardar")` hace la foto y la guarda ya; `("Cargar")` la relee y la pone. `Config.Test.Partidas` = las ranuras que enseña el lobby en Studio.

## Muerte y finales (14.9)

- Mientras `workspace.Final` está puesto (la huida en el coche o el incendio de la Bestia) no se revive a nadie: el
  `Director` se salta el revivir del amanecer, `Revivir.puede` da false y se apaga `Revivible` (sin botones). Si el
  incendio fracasa y quita `Final` ya de día, `Incendio` revive a todos.
- Antes de anclar a todos en los dos finales (`Coche`, `Incendio`), a cada uno: `Muerte.sacar` si está escondido (con
  pcall), suelta lo que carga, mochila cerrada (`MochilaAbierta` a nil) y `Cargar.ajustarVelocidad`.
- `MuerteVista`: el susto va en pcall y la vuelta (negro, cámara Custom, mirar a los vivos) se hace siempre. En la
  escena de un final no toca la cámara (tampoco al reaparecer) y corta en seco el aliento y el latido.
- Atributo `EscenaFinal` del jugador, solo en el cliente local (no se replica): lo ponen `HuidaVista` e `IncendioVista`
  justo al tomar la cámara (Scriptable) y lo quitan siempre en su `alAcabar`, después de devolverla a Custom, aunque la
  escena falle. Es la señal de que hay una escena que lleva la cámara; lo miran `MuerteVista` (escondite, susto, mirar
  a los vivos, reaparecer), `MovilUi`, `MochilaUi` y `CorrerVista` (resoplidos). No vale `workspace.Final`: en el
  incendio se pone ~17 s antes de la escena (`Incendio.prender`) y se quita sin escena si el fuego se cancela. Tampoco
  `CameraType == Scriptable`, que también lo es escondido, por la mirilla o las cortinas y en el susto.
- `Muerte.esconder` rechaza durante la escena de un final (`Muerte.escena(true)`, que ponen `Coche.huir` e
  `Incendio.terminar` antes de sacar a todos y quitan al acabar), también la orden `Esconder` del modo de pruebas.
  Mientras corre el fuego del incendio (`Final` puesto, sin escena) los bichos siguen cazando y sí se puede: `MuerteVista`
  mantiene el escondite de siempre y al salir devuelve la cámara a Custom. La escena empieza sacando a todos
  (`Muerte.sacar`).
- Remote `Muerte` (quien, cabeza, modelo): trae el bicho que pilla y la escena lo enfoca a él (ver `bichos.md`).
- API nueva de `Muerte`: `vivo(jugador)` (como mirar en `vivos()`, sin hacer la lista), `sacar(jugador)` (fuera del
  escondite, lo mismo que salir) y `alMorir(fn)` (`fn(jugador)` una vez por muerte, muera como muera; Caza olvida su olor).
- Cinemáticas (la huida, el incendio): mochila y móvil se guardan o cierran al empezar la escena (`EscenaFinal`) y no
  se abren en ella, pero escondido o por la mirilla sí (ver `movil.md` y `mochila.md`); puntero del ratón escondido; la
  linterna de los demás se apaga con la cámara Scriptable (salvo mirilla o escondido); la flecha y el contorno del
  tutorial se apagan con el Hud apagado o en cinemáticas; el tirón de los sustos (`Util.tiron`) se deshace antes de la
  cámara de Roblox y no toca la Scriptable.
- Bancos de Lune: `tests/bancos/muerte.luau` (Final sin escena, escena con el susto y, en el servidor, que no se
  esconde en la escena y sí con Final y sin ella) y `tests/bancos/escenas.luau` (MovilUi y MochilaUi de verdad, con EscenaFinal, escondite y Vistazo).
- Probado en Studio con un jugador (04-11-2026, todo bien y sin errores): escondido durante el fuego (E sale a Custom),
  fuego cancelado escondido, escena del incendio entera (Bestia atrapada con `Preparar`, `Esperar`, llevarla al sótano
  y `Palanca`; sale del escondite, anclado, sin puntero, E no esconde), huida con la mochila abierta (se cierra, B y M
  no abren, `Esconder` rechazado), no revive con `Final` y sí al fracasar de día, susto justo antes de la escena
  (`Remotes.Muerte:FireClient` y luego `Incendio "Final"`: la cámara sigue en la escena). La mochila no se abre
  escondido, a propósito (`MochilaUi.abrir`). También bien: por la mirilla la flecha del tutorial se apaga y vuelve
  al salir (`Config.Test.Tutorial` a true solo mientras se prueba; L con la cámara mirando a la mirilla), y sustos
  seguidos (3 `Portazo`, 3 `Util.tiron`) dejan la mirada a 0,0000° de donde estaba. Probar de día: de noche un
  Golpeador te mata a mitad. Falta lo de dos jugadores (Test → Clients and Servers). Antes, en Edit: que Rojo ha sincronizado (`string.find(<script>.Source, "EscenaFinal")`
  no da nil en `MuerteVista`, `HuidaVista`, `IncendioVista`, `MovilUi`, `MochilaUi` y `CorrerVista`). Al acabar cada
  escena: `LocalPlayer:GetAttribute("EscenaFinal")` vuelve a nil y `CameraType` es Custom; errores con
  `LogService:GetLogHistory()`.
  - Fuego y escondite (Test → Clients and Servers, 2): A en un armario con E; B prende el porche con las cerillas.
    Mientras corre el fuego (~17 s), A pulsa E: la cámara vuelve a Custom y anda libre; luego la escena es suya. En el
    cliente de A, `EscenaFinal` nil durante el fuego y true en la escena.
  - Fuego cancelado: A escondido y B prende; antes de la escena, quitar el fuego en Server (que amanezca, o
    `workspace:SetAttribute("Final", nil)` y `Remotes.Incendio:FireAllClients("Apagar")`). A sigue en el escondite que
    respira y al pulsar E vuelve a Custom. Nada congelado.
  - Huida: en la escena, E junto a un armario no te mete (`Escondido` nil, `Ocupado` 0). Durante el fuego del
    incendio (antes de la escena) sí te escondes, como siempre.
  - Susto antes de la escena: con `Final` del incendio, que te pille un bicho ~2 s antes de que acabe el fuego. Si la
    escena empieza durante el susto, al acabarlo la cámara sigue en la escena (Scriptable), no en Custom.
  - `Prueba:Fire("Quemar")` con un escondido (`Prueba:Fire("Esconder", <punto junto a un armario>)` antes de prender)
    y la mochila abierta: en la escena no hay puntero, el escondido ha salido (sin latido; E no hace nada), todos
    `Anchored` y la mochila cerrada; al acabar vuelven el puntero y la cámara. Igual con la huida (Escape).
  - Con un muerto, `Prueba:Fire("Dia")` mientras corre el fuego: no revive (`Muerto` sigue, `Final` puesto); al
    fracasar el fuego de día, revive. Con `workspace:SetAttribute("Final", true)` no sale el botón de revivir.
  - Dos jugadores: que muera uno, huida con el otro y `Prueba:Fire("Dia")`: el revivido no aparece en mitad de la escena.
  - Con la mochila o el móvil abiertos, lanzar la huida (`Remotes.Huida:FireAllClients(20)` en Server): se cierran
    solos, no se abren con B o M durante ella y al acabar sí. Por la mirilla, la flecha del tutorial se apaga y vuelve;
    con dos jugadores, la linterna del otro no se ve suelta en la escena final. Sustos seguidos sin mover el ratón: la
    mirada vuelve exactamente a donde estaba.

## Probado en Studio (21-10-2026)

- Juego: 64 claves sin repetir. Puerta principal rota, árbol marcado talado, hacha movida, lata quitada, bidón movido, carrete tirado de la mochila y generador arrancado tirando de la cuerda → Guardar. Luego se tira una pila, se quita la botella y se mueve el motor → Cargar: puerta a 0, tocón sin tronco, objetos y bidón como al guardar, 2 pilas y sin carrete en la mochila, generador encendido. Sin errores.
- Lobby: subir al coche (dueño), panel con "1 NOCHE 4", cambiar de ranura (la 7 no vale), NUEVA PARTIDA con dos toques, cuenta atrás, fundido y aviso de Studio; bajar del coche. Sin errores.
- Lune: 258 comprobaciones bien (formato nuevo, roto y viejo, tope de sueltos, mochila con tipos que ya no existen, candado de la partida con dos servidores, resumen de ranuras).

## Pendiente

- Sin probar (solo funciona publicado): reservar servidor, MemoryStore, teletransporte de ida y vuelta, DataStore real de la partida, dueño que se va con otros dentro. `Config.Lugares` sigue a 0.
- Sin probar en Studio: volver al amanecer al morir todos (usa el mismo `aplicar` que Cargar), dos jugadores en el coche (el que no es dueño).
- La cinemática de llegada a la casa (la de salida del lobby está hecha: `lobby.md`) y volver a una partida tras un corte (el dueño no puede volver a entrar a un servidor reservado: haría falta que el lobby lo mande de vuelta).
- Para probar el lobby en el mismo Studio: `rojo serve lobby.project.json --port 34872` y Rojo → Connect (el lugar se genera entero por código).
- Opcional (pedido por agentes en la 14.9, no hecho): `Muerte.vivo(jugador)` en vez de `table.find(Muerte.vivos(),
  jugador)` en Postura, Movil, Taller, Bengalas, Recursos, Generador, Mochila, Coche, Incendio y Preparativos, y en la
  búsqueda de presa de `Bestia.luau`; un `Muerte.prepararEscena(j)` común para `Coche.huir` e `Incendio.terminar`.
- `AmbienteMiedo`, `TutorialVista`, `EquipoVista`, `PosturaVista`, `Manos` y `BestiaVista` deciden "cinemática" por
  `CameraType` Scriptable con excepciones de `Escondido` o `Vistazo`. Si alguno debe distinguir la escena final de
  verdad, que mire `LocalPlayer:GetAttribute("EscenaFinal")`.
