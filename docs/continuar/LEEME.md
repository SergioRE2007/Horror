# Seguir la sesión del 03-11-2026, tarde (rama `claude/admiring-bell-jvgvch`, PR #24)

Sesión en local con Studio. Se paró por falta de uso (pedido por el usuario: "apunta por donde nos hemos quedado y
prepara un prompt para cuando se me vuelva a reiniciar el uso"). **Al acabar todo, borrar esta carpeta.**

## 0. Antes de nada

- `git fetch` y `git switch claude/admiring-bell-jvgvch` y `git pull` (seguir en esa rama; los commits se suman a la PR #24).
- Rojo de la partida: tarea "Rojo Horror" (puerto 34872). El lobby se sirve a mano: `rojo serve lobby.project.json`
  (34873); ventanas de Studio con `Start-Process juego.rbxl` y `Start-Process lobby.rbxl`, y Sergio pulsa Connect.
- Agentes: con esfuerzo **alto** (no max: pedido por el usuario, gasta demasiado), commits frecuentes de solo sus
  archivos (`git commit -- <rutas>`) y una nota suya en `docs/continuar/<grupo>.md` al día.
- Trucos nuevos de Studio (ya en `CLAUDE.md`): `execute_luau` devuelve la cámara a Custom si el script la cambia
  (lanzar con `task.delay`); `user_mouse_input` va en coordenadas de la GUI (~56 px más arriba que la captura).

## 1. Hecho en esta sesión (commits, probado en Studio salvo lo dicho)

- `c56b347` Lobby: arreglos de la revisión (máquina en la nevera, banco en la papelera, faros de la copia, puerta,
  clima). `0057fe9` Lobby: CochesUi y TiendaUi al estilo oscuro, a prueba de doble toque, y bajar del coche por la
  puerta (fallo visto en Studio: al saltar te quedabas dentro del coche).
- `5f35e6b` Agacharse y asomarse. `f592cba` Manos en la pared. `216c184` Mirilla y cortinas (con el Imitador que se
  pega a la mirilla). `c9bb0c6` Escondite y casa: arreglos de la revisión (sin probar el streaming de verdad).
- `12ecc97` Esconderse agachado (a medias): reglas puras con pruebas, números en `Config.Postura` y mesas con hueco
  (`Mapa`, `HUECOS`: comedor 2,84 y cocina 3,29, zonas "Debajo").
- Revisados con `reviewer` y arreglados sus GRAVE y MEDIO: lobby, interfaz del lobby, agacharse, pared, mirilla,
  escondite y casa, y los seis bichos.

## 2. A medias: esconderse agachado (pedido por el usuario, 03-11-2026)

"agacharte también debería servir para esconderte, por ejemplo debajo de mesas, y que el monstruo pueda gatear si te
huele con una animación guapa para pillarte debajo de sitios… que sea útil agacharte es la finalidad".

Contrato: agachado, lo que choca del cuerpo no pasa de `Config.Postura.Alto` (2,6) y cabes bajo las mesas con zona
"Debajo"; el servidor pone `Cubierto` en el jugador (agachado con la raíz en una zona). Los bichos te ven y oyen peor
agachado (`PosturaReglas.alcanceVista/alcanceOido`); cubierto solo muy de cerca, pero te huelen (`oler`/`huele`): van
al borde del mueble, ponen en su modelo `Gatea` (Vector3) y `GateaHora`, y a `Config.Postura.Gatear` s te pillan
(Muerte.matar) o lo dejan si sales y te alejas. Cada Vista anima su gateo mientras haya `Gatea`.

Estado de cada parte (cada agente lo apunta en su nota de esta carpeta):
- Cuerpo (`PosturaVista`, `CuerpoVista`, `BrazosVista`, `servidor/Postura`, `MuerteVista`): `cuerpo.md`.
- Bichos en el servidor (`Caza`, `Bestia`): `caza.md`.
- Gateo de Golpeador, Raspador y Trepador (y su vida de espera, ya hecha y revisada): `bichos1.md`.
- Gateo de Imitador y Bestia (y la vida de espera de los tres, con el Acechador): `bichos2.md`.

Lo que falte de cada parte: relanzar su agente (esfuerzo alto) con su nota y "sigue desde lo que hay". Luego, el
principal: párrafos en `docs/sistemas/manos.md` y `bichos.md`, `selene src` y Lune, y **probar en Studio**: entrar
agachado bajo la mesa del comedor (personaje en `CFrame.lookAt(Vector3.new(-20.5, 4, -17.7), Vector3.new(-26, 4, -17.7))`,
agacharse y andar hacia -X: debe salir `Cubierto`), que no te puedas levantar debajo, y un bicho
(`ServerStorage.Prueba:Fire("Noche")` y `("Ataque", punto)`) que te huela y gatee; también poner `Gatea` y `GateaHora`
a mano en un bicho para ver la animación. Después, `reviewer` sobre todo esto, arreglar GRAVE y MEDIO, commit.
La vida de espera de los seis bichos aún no se ha visto en Studio: mirarla también (pasos en `bichos1.md` y
`bichos2.md`).

## 3. Fase 4 (sin empezar)

1. Probar en Studio lo de "Pendientes para Studio" de `TASKS.md` (lo más importante: el tutorial con
   `Config.Test.Tutorial = true` para que Sergio lo apruebe; el Acechador que no va a por quien está en la torre, las
   esquinas o el garaje; las cerillas si amanece con el fuego en marcha; las teclas V, K y P). Del lobby falta el
   emulador de móvil, dos jugadores, la sombra y Rendimiento.
2. Docs al día y `TASKS.md` (14.6 segunda tanda, 14.7 lobby y la lista de pendientes); borrar `docs/continuar/`.
3. Push y descripción de la PR #24 (`gh pr edit 24 --body-file ...`).
4. Juntar en `main` (pedido por el usuario: "me gustaría que se juntaran todas las ramas ya en main, hay demasiadas
   ramas y borrar las obsoletas"), preguntando antes de juntar:
   - PR #24: `gh pr merge 24 --squash --delete-branch`.
   - `paso-11-salas` (0 commits por delante de main): borrar local y remota.
   - `sala-desvan`, `sala-detalles`, `sala-garaje`, `sala-ninos`, `sala-pistas`, `sala-sotano` (remotas, 1 commit
     cada una) y `base` (con la PR #1 abierta): ver con `git diff origin/main...origin/<rama> --stat` si lo suyo ya
     está en main (salas de la 11.x, juntadas a mano). Si ya está, borrarlas y cerrar la PR #1; si no, decírselo a
     Sergio antes de juntar nada.
5. Entregar a Sergio, en español y corto: qué se ha hecho por fases, fallos arreglados por prioridad, qué está probado
   en Studio y qué falta, ideas no hechas y sonidos o imágenes que faltan.

## Notas para el resumen final

- Fallos arreglados que salieron en Studio: bajar del coche del lobby (te quedabas dentro). Y del agente de los
  bichos: las juntas del Golpeador y del Raspador recibían NaN (salían rotos) hasta la primera sacudida.
- Ideas no hechas: tropezar o frenar al correr cansado (no hay sistema de correr: preguntar a Sergio); que en el
  lobby llegue un coche conduciendo cuando uno se va (ahora reaparece de golpe para quien mira desde fuera).
- Sonidos que faltan (ElevenLabs): del lobby `Config.SonidosLobby` (Lluvia, LluviaChapa, Trueno, Radio, Campanilla,
  Arranque); de la partida con Id 0 en `Config.Sonidos` (Respiracion, Contener, Exhalar, Mirilla, Vajilla, Mecedora,
  Resoplido) y los 8 provisionales de 14.3. Un sonido de clic o de sello para los botones de la tienda (idea del
  agente de la interfaz del lobby).
- Las cabezas de bloques provisionales se ven poco miedosas en la mirilla (el Imitador): cuando haya modelos de
  verdad, mirarlo otra vez.

## Prompt para la próxima sesión (copiar y pegar)

```
Seguimos con el juego de terror en local con Roblox Studio, en la rama claude/admiring-bell-jvgvch (PR #24). Lee
primero CLAUDE.md, TASKS.md y docs/continuar/LEEME.md con las notas de esa carpeta: ahí está qué se ha hecho, qué
queda y cómo seguir.

Trabaja de forma autónoma como un senior developer. Usa los agentes que hagan falta con esfuerzo alto (no max), sin
dos agentes en el mismo archivo, con commits frecuentes de solo sus archivos y su nota al día. Los agentes no le dan
a Play: Play solo lo usa la conversación principal.

1. Termina "esconderse agachado" (debajo de las mesas, y los bichos que huelen y gatean): relanza lo que falte de cada
   parte, júntalo, pruébalo en Studio con el gateo de los bichos y mira también la vida de espera de los seis bichos.
   Reviewer, arregla lo GRAVE y lo MEDIO, y commit.
2. Fase 4: prueba en Studio lo más importante de "Pendientes para Studio" de TASKS.md, pon al día los docs y
   TASKS.md, borra docs/continuar/, haz push y actualiza la descripción de la PR #24.
3. Junta todo en main y borra las ramas obsoletas como dice el LEEME (pregúntame antes de juntar).

Antes de cada commit: selene src y lune run tests/regressions.luau en verde. Un commit por tema.

Al acabar, dame en español y corto: qué se ha hecho, los fallos arreglados por prioridad, qué está probado en Studio
y qué falta, las ideas no hechas y los sonidos o imágenes que faltan para ElevenLabs o ChatGPT.
```
