# Juego de terror: lo aprendido con RNG: Sword Breaker

Primer juego hecho juntos: `Documents\Roblox\a Sword Breaker` (repo `SergioRE2007/RNG-Sword-Breaker`). Si hace falta ver cómo se resolvió algo, mirar allí su `CLAUDE.md`, `docs/sistemas/` y el código: es la referencia. Lo propio de este juego se irá añadiendo aquí cuando empecemos.

## Qué hay en el repo

- `src/` (lo que sincroniza Rojo, `default.project.json`): de momento solo los `init` vacíos y un `Config` mínimo.
- `plantillas/`: módulos de Sword Breaker que sirven en cualquier juego, copiados tal cual y **sin sincronizar**. Para usar uno: pasarlo a `src/`, quitarle lo propio de Sword Breaker (espadas, mazmorras, comercio…) y registrarlo en su `init`. Guardado con candado (`server/PlayerData`), avisos en el idioma de cada uno (`server/Tell`, `server/Language`, `shared/Lang`, `client/Language`, `client/LangSwap`, `client/WorldText`), normas por país (`server/Policy`), reconexión por inactividad (`server/Rejoin`), `shared/Format`, `shared/Chance`, `shared/Remotes`, la librería de interfaz `client/Ui`, sonidos `client/Sfx`, `client/Settings`, modo rendimiento `client/Performance`, aviso de pantalla vertical `client/Orientation`, números flotantes `client/FloatText`, pantalla de carga `first/Loading` y las regresiones de Lune `tests/regressions.luau`. Cuando ya no quede nada por pasar, borrar la carpeta.
- `tools/`: `sonidos` (ElevenLabs; `npm install` dentro antes de usarlo), `blender` (los scripts de Sword Breaker como ejemplo, `subir_modelo.mjs` para subir un `.fbx` con Open Cloud y `cuerpo_r15.obj`, el cuerpo R15 para diseñar sobre él) y `ui` (`botones.mjs`).
- Claves (nunca en el repo): Open Cloud de Roblox en `Documents\Roblox\clave-roblox.txt`; ElevenLabs en la configuración del MCP `elevenlabs` de este proyecto (`~/.claude.json`), que es de donde la lee `tools/sonidos`.
- MCP de este proyecto: `Roblox_Studio` y `figma` (globales), `blender` y `elevenlabs` (solo aquí).

## Sobre Sergio

- Habla español y no programa: todo el código lo escribe Claude. Da ideas a grandes rasgos y espera que Claude proponga los detalles, los construya y los pruebe.
- Le preocupa el gasto de tokens: respuestas cortas, leer solo lo necesario, una funcionalidad por conversación. No volcar árboles enteros del juego ni archivos grandes sin necesidad.
- Le gustan las físicas y los juegos RNG. Quiere una base sólida que se pueda ampliar. No hay modelos propios: piezas, código y modelos de Blender hechos por script; los sonidos, con ElevenLabs.
- Números de equilibrio de contenido nuevo: a ojo siguiendo a los vecinos, sin preguntarle cuántas horas debe durar; avisar en una línea de que son a ojo.
- Público: niños. Poca información en pantalla (carteles de pocas líneas, avisos de una sola, sin "monedas/s" ni desgloses), juego "relativamente f2p": pocos pases de juego y nada imprescindible de pago.
- Cuando algo de Claude no le convence lo dice con frases cortas ("no se nota mucho", "molesta"): rehacerlo más grande y vistoso, no retocar un poco. Los cambios que pide se apuntan en el `CLAUDE.md` o en `docs/sistemas/` con "pedido por el usuario", para no deshacerlos sin querer más adelante.

## Git

- Este juego lo hace Sergio solo, pero con GitHub igual que el primero: repo privado `SergioRE2007/Horror`, rama `main`. Al empezar: `git switch main` y `git pull`. Una rama por funcionalidad, nunca commits directos en `main`.
- Al terminar y haber probado: commit, `git push`, `gh pr create --fill` y `gh pr merge --squash --delete-branch`, preguntando antes de juntar con `main`.
- Comentarios del código en español. El `.rbxl` no se sube. No subir valores de `Config` bajados temporalmente para probar.

## Entorno

- Windows, PowerShell. Rojo 7.7.1 y Lune 0.10.5 con Rokit (`rokit.toml`). Git y `gh` instalados. Blender en línea de comandos para modelos. ffmpeg (winget `Gyan.FFmpeg`) para grabar vídeos.
- Grupo de Roblox: Lotozno Studios (id 1002188803). Clave de Open Cloud en `Documents\Roblox\clave-roblox.txt` (pases de juego, tamaño de servidor, subir modelos como assets). La localización del Creator Hub solo se toca a mano.

## Al empezar una sesión (proyecto con Rojo)

0. `git switch main` y `git pull`.
1. `rojo serve` en segundo plano y comprobar `http://localhost:34872/api/rojo`.
2. `list_roblox_studios` para el `studio_id` (sale con el nombre del lugar abierto, no del proyecto; reconocerlo por algún módulo propio).
3. Si Studio no está conectado al puerto, pedir a Sergio que pulse Rojo → Connect.

## Cómo trabajar en Roblox

- El código vive en `src/` y Rojo lo sincroniza. Editar siempre los archivos, nunca los scripts dentro de Studio. El MCP de Studio solo para probar (play, consola, captura).
- El mapa y la iluminación se generan por código; borrar al arrancar las piezas sueltas que no sean del código (una placa sin anclar llegó a tapar el cielo).
- Arquitectura que funcionó:
  - Un sistema nuevo = un módulo con `start()`, registrado en el `init` del servidor o del cliente. Librerías sin `start()` para lo compartido.
  - `Config` con todos los números (el equilibrio se toca solo ahí). Un módulo `Stats` como única fuente de daño, suertes y multiplicadores, válido en servidor y cliente. Un módulo `Remotes` con todos los RemoteEvents.
  - El servidor manda: el cliente solo pide y el servidor valida todo. El cliente lee el estado de los atributos del `Player`. Los efectos visuales (números, escombros, partículas) solo en el cliente.
  - Lo guardado usa posiciones en listas: no reordenar nunca listas de `Config` que se guarden, lo nuevo al final. Si cambia el formato guardado, compatibilidad con lo viejo.
  - Juegos RNG de números enormes: probabilidades con una función exacta para `p` diminuta (nunca `NextNumber() < p` a mano), números abreviados con un `Format` (K, M, B… Sp…), nada en `IntValue`, suertes y precios exponenciales. Los avisos de rareza usan la probabilidad real (rareza / suerte). No aplicar una misma suerte en dos sitios ni meter multiplicadores escondidos.
  - Pases de juego por ventajas (`perks`), preguntando siempre por la ventaja, nunca por un pase concreto; el servidor la valida.
- Idioma desde el primer día (en el primer juego hubo que rehacerlo todo): textos del jugador en inglés pasando por `Lang.t(jugador, "Frase con {hueco}", {...})` y su español en una tabla aparte; frases enteras con huecos, nunca trozos pegados; el idioma es el del `Translator` del jugador (`GetTranslatorForPlayerAsync`), no el de la cuenta. En el Creator Hub el idioma de origen debe ser inglés.
- Guardado desde el principio con candado de sesión (`UpdateAsync`, nunca `SetAsync`) para que no se pueda duplicar saltando de servidor. Con jugadores reales: cuidado máximo con perder datos, duplicados y trampas en compras, comercio y remotes.
- Modo de pruebas en `Config.Test` (dinero infinito, todas las armas…) que solo actúa en Studio y no guarda esa partida. En un lugar publicado una partida de Studio sí puede guardar: probar siempre con un modo que no guarde.
- Regresiones con Lune (`lune run tests/regressions.luau`) para lo que se pueda simular fuera de Studio, guardado y comercio incluidos.
- Cuando el juego ya tiene jugadores, no cambiar el bucle base: lo nuevo se añade como sistema aparte.
- `CLAUDE.md` del proyecto corto; el detalle de cada sistema en `docs/sistemas/<sistema>.md` (en el primer juego el `CLAUDE.md` creció tanto que gastaba muchos tokens).

## Estilo visual que le gusta

(Era el de un simulador RNG; para el juego de terror, decidir con Sergio qué se mantiene: helpers comunes, nada plano y mayúsculas sí; colores y aspecto, seguramente no.)

- Estilo "simulador de Roblox": ventanas oscuras con cabecera degradada y borde negro grueso, inventarios en casillas cuadradas con el borde del color de la rareza y cartel al pasar el ratón, botones de color con relieve que se aclaran y se hunden, fuente `FredokaOne` con borde negro. Nada plano: siempre degradado y borde. Todo con helpers comunes (`Ui`), no estilos sueltos.
- Texto de botones, títulos de ventanas y botones del menú siempre en mayúsculas.
- Colores vivos sin pasarse: se quejó de neones y saturación alta. Nada de `Neon` en piezas grandes del mapa.
- Logos fijos (monedas, menú, pestañas) como imágenes PNG subidas a Roblox; lo que cambia de color con cada casilla, con marcos.
- Las casillas de armas con el modelo 3D (`ViewportFrame`), no un icono plano.
- Para interfaz: cargar antes las skills `roblox-ui-engineer` y `roblox-ui-designer` (sus reglas ceden ante este estilo, borde negro incluido).

## Cómo probar en Studio (trucos que costó aprender)

- Mirar `get_studio_state` antes de jugar: si ya está en Play es una partida de Sergio; pararla y decírselo. Parar siempre al terminar.
- Rojo tarda en sincronizar: el primer Jugar tras editar suele llevar el código viejo. Comprobar antes con `execute_luau` en `Edit` (`string.find(script.Source, "texto nuevo")`). Rojo no aplica cambios a una partida en marcha.
- `require` de un módulo del servidor desde `execute_luau` da una copia sin estado: el estado se lee de los atributos del `Player`. `require(Remotes)` en modo Edit puede crear una carpeta `Remotes` de más que rompe los remotos al jugar.
- Simular al jugador desde el datamodel `Client`: `PivotTo` del personaje (esperar un momento: el servidor ve los saltos grandes con retraso) y disparar los remotes.
- Errores: `LogService:GetLogHistory()` filtrando lo que no sea `MessageOutput`; `get_console_output` trae mucho ruido.
- `screen_capture` no pinta los `BillboardGui` con `AlwaysOnTop` (ponerlo a `false` para capturar). Mundo negro con el HUD bien = la ventana de Studio está tapada. Capturas de una en una. Para fijar la cámara en modo juego: `RunService:BindToRenderStep` con prioridad `Camera + 10`.
- Revisores: Haiku para lo visual (pasarle el `.jpg` de la captura), Sonnet para el código.
- `WorldPivot` de un Model no llega bien al cliente: animar pieza a pieza. `EditableMesh`: unas 8 vivas a la vez y necesita permiso en la experiencia.
- Lo que solo funciona publicado (compras, pases, DataStores entre servidores, idioma real): decirlo como no probado.

## Móvil y rendimiento

- Pensar en móvil desde el principio: los botones de Roblox (y la cámara del teléfono) tapan la esquina de arriba a la derecha, así que los botones pequeños van a la izquierda de esa zona. Todo el HUD bajo un solo `UIScale` que lo encoge en pantallas pequeñas. Ataque con clic, toque y mando.
- Opción "Rendimiento" en Ajustes: menos partículas, sin animaciones de adorno, solo lo propio del jugador. Lo animado, en un solo bucle que solo corre cuando hace falta y solo cerca de la cámara.
- Brillos y luces flojos: se quejó de objetos que brillaban demasiado.
- Las cinemáticas esconden toda la interfaz ("para que sea más cinemático") y lo que estorba de la vista, y lo devuelven siempre al acabar, aunque se salte o falle.

## Sonidos

- Los de serie de Roblox cambiados de tono no le gustaron nada: los sonidos se hacen con ElevenLabs. Las herramientas del primer juego están en `a Sword Breaker\tools\sonidos` (`generar.mjs` crea varias versiones y una página `escuchar.html` para que elija, `medir.mjs` mide el volumen, `subir.mjs` los sube); reutilizarlas.
- ElevenLabs saca cada audio a un volumen distinto: medir el pico y compensarlo con una ganancia por audio. Los ambientes pedidos de una vez salen casi mudos y con siseo: no usarlos ni enseñárselos.
- Precargar: un `Sound` sin colgar en `SoundService` tarda 0,3-0,5 s la primera vez (lo notó en los botones). Plantillas colgadas en `SoundService` y copias de ellas.
- Botones: suenan al pulsar (no al pasar el ratón) y al cerrar ventana (no al abrir). Los de interfaz y premios siempre iguales, sin azar de tono, para que se reconozcan; solo varían los que se repiten mucho (golpes).

## Imágenes

- Las genera Sergio con ChatGPT a partir de un texto que le da Claude por imagen, con el estilo dentro del texto (dibujo 2D de simulador, contorno negro grueso, fondo transparente, sin letras). Se recortan al dibujo y se pasan a 512 px con `System.Drawing` desde PowerShell (no hay Python ni ImageMagick) y se suben con `upload_image` de Studio. Recién subidas tardan unos segundos en verse.

## Modelos de Blender

- Scripts de Blender en `tools/blender/` que crean las piezas y exportan `.fbx` y vistas `.png` para revisarlas. Se suben como modelo del grupo con Open Cloud (`assets/v1/assets`, Model), se cargan en Studio con `game:GetObjects` y sus MeshParts se vuelcan a un `.rbxmx` en `src/shared`. Mallas con nombre `<Pieza>_<Papel>` (Body, Trim, Gem, Glow…) y el juego les pone color y material según el papel. Para cambiar solo algunas piezas, un archivo "Patch" que manda sobre el original.

## Lanzamiento y analíticas (primer juego, octubre de 2026)

- Publicado en privado primero; testers con un rol del grupo con permiso "Probar experiencias" y enlace directo.
- Primeros datos con anuncios: D1 ~10 %, la mitad de los nuevos se va en 5 minutos; anuncios a ~0,05 $/jugada la mejor campaña. La prioridad que salió: los primeros 5 minutos (tutorial, que se entienda enseguida) y la retención D1. Pensarlo desde el principio en el juego nuevo. El tutorial lo quiso muy visible: "tiene que invadir más la pantalla y que te diga más vistoso dónde clicar" (flecha grande y pasos cortos, con premio al acabar).
- Vídeos promocionales: cámara `Scriptable` en recorrido desde el cliente, clima y hora animados, grabación con ffmpeg `gdigrab` sobre la ventana de Studio y montaje con `xfade`. Le encantó.
