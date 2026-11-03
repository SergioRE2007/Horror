# Seguir la sesión del 03-11-2026 (rama `claude/admiring-bell-jvgvch`, PR #24)

Sesión en la nube, sin Studio. Se paró a mitad de la Fase 3 porque se acababa el uso (pedido por el usuario: "prepara
el repo para que cuando tenga uso le diga continue y ya sepa qué hacer"). El encargo entero (4 fases) está resumido
abajo; lo hecho, en los commits de la rama. **Al acabar todo, borrar esta carpeta `docs/continuar/`.**

## 0. Antes de nada

1. `git fetch origin claude/admiring-bell-jvgvch` y `git switch claude/admiring-bell-jvgvch` (seguir en esa rama: los
   commits se suman a la PR #24; no tocar `main` ni juntar sin preguntar).
2. `bash tools/nube/herramientas.sh`: deja selene y lune en `/tmp/herramientas/bin` y el `roblox.yml`. Comprobar:
   `/tmp/herramientas/bin/selene src` sin avisos y `/tmp/herramientas/bin/lune run tests/regressions.luau` en verde.
3. En la nube cada Workflow corre como mucho **2 agentes a la vez**: para ir deprisa, lanzar varios Workflow a la vez
   (cada uno con 2 grupos) en vez de uno grande. Ningún archivo en dos agentes a la vez.

## 1. Lo que queda de la Fase 3 (inmersión en la partida), a medias en parches

Cada grupo está guardado en `docs/continuar/<grupo>.patch` (sobre la rama tal cual; aplican limpios con
`git apply docs/continuar/<grupo>.patch`). Las órdenes exactas de cada agente están en `docs/continuar/fase3.js`
(script de Workflow, con un aviso de "sigue desde lo que hay"). Para seguir: aplicar los parches y lanzar
`Workflow({ scriptPath: "docs/continuar/fase3.js", args: ["cuerpo", "paredes"] })`, y en otros Workflow a la vez
`["mirar", "lobbyui"]` y `["bichos1", "bichos2"]`.

| Grupo | Qué es (pedido por el usuario) | Archivos | Estado al parar |
|---|---|---|---|
| `cuerpo` | Agacharse (C / Ctrl / ButtonB y botón en el móvil) y asomarse (Z / X) | `PosturaVista` (nuevo), `servidor/Postura` (nuevo), `shared/PosturaReglas` (nuevo, puro), `CuerpoVista`, `BrazosVista`, `tests/regressions.luau` | Reglas y sus pruebas hechas (Lune: 796 comprobaciones bien); lo demás a medias |
| `paredes` | Manos que se apoyan en la pared y se agarran a la esquina al asomarse | `Manos`, `ManosGestos` | A medias |
| `mirar` | Mirar por la mirilla de la puerta principal y entre las cortinas (útil con el Imitador) | `MirarVista` (nuevo) | A medias |
| `bichos1` | Golpeador, Raspador y Trepador con más vida mientras esperan | `GolpeadorVista`, `RaspadorVista`, `TrepadorVista` | Golpeador y Raspador a medias; Trepador sin empezar |
| `bichos2` | Imitador, Acechador y Bestia con más vida; el Imitador reacciona a la mirilla | `ImitadorVista`, `AcechadorVista`, `BestiaVista` | A medias; **BestiaVista no pasa selene** (se paró en mitad de un cambio) |
| `lobbyui` | La interfaz del lobby (CochesUi, TiendaUi) al estilo oscuro y bien en el móvil | `CochesUi`, `TiendaUi` | Muy avanzado (TiendaUi casi rehecha) |

Lo que hay que poner a mano al acabar (lo hace el principal, no los agentes):
- `init.server.luau`: `require(Sistemas.Postura).start()`. `init.client.luau`: `PosturaVista` y `MirarVista`.
- `Cargar.ajustarVelocidad`: agachado anda a `Config.Postura.Velocidad` (Config.Postura y el remote Postura ya existen).
- `LangEs`: "Crouch" → "Agacharse"; "Look through" → "Mirar por la mirilla"; "Peek" → "Mirar entre las cortinas"
  (o lo que digan los agentes en su respuesta).
- `docs/sistemas/manos.md`: un párrafo por grupo (lo devuelve cada agente).

Ya hecho de la Fase 3 (commits `1c5b307` y `eb6ed89`): respiración contenida en el escondite y ver esconderse a los
demás (`EsconditeVista`), y la casa que reacciona más (mecedoras, vajilla que tintinea, polvo en el haz, corriente en
las cortinas) con el arreglo de la mirada que se desviaba con los temblores.

## 2. Revisión del lobby (a medias)

Se revisó el lobby nuevo con 4 agentes `reviewer`; solo se verificó el grupo del mapa base (sus dos MEDIO eran falsos).
Quedan por verificar y arreglar estos MEDIO (y los LEVE, si son de pocas líneas):
- `GasolineraFuera.luau:~1032`: la máquina expendedora se mete dentro de la nevera de hielo de la tienda.
- `GasolineraFuera.luau:~1007`: el banco choca con la papelera de la acera de la tienda.
- `SalidaVista.luau:~571`: el parpadeo de faros y pilotos de la copia parte de colores equivocados.
- `lobby/cliente/init.client.luau:11`: un `require` o `start()` que falle deja sin arrancar los sistemas de detrás
  (proteger cada uno con `pcall` y `warn`, como en el servidor).
- LEVE: la puerta automática se pasa de su sitio; la sombra solo mira si estás en la tienda; `Resume()` del zumbido
  en cada fotograma; un fallo puntual apaga una parte del clima; `Volume` escrito cada fotograma; Sonido (la primera
  grabación nunca es la 1, WorldPosition antes del padre, `tocar` que no se borra); Bucle crea una tabla por fotograma.
Para hacerlo con agentes: `Workflow({ scriptPath: "docs/continuar/revisar-lobby.js" })` (revisa, verifica y arregla
solo; tarda). Antes, aplicar y terminar `lobbyui`, que toca CochesUi/TiendaUi.
- Idea pendiente del lobby: cuando el coche se va de verdad, el coche real reaparece de golpe en su plaza para quien
  mira desde fuera (el diseño dice "nada que aparezca de golpe"): que llegue uno conduciendo desde la carretera.

## 3. Fase 4 (cierre), sin empezar

1. Agente `reviewer` sobre todo lo nuevo de la rama (`git diff main...HEAD`, por grupos de archivos); arreglar GRAVE y
   MEDIO; un commit por tema.
2. Docs: `docs/sistemas/manos.md` (lo de la Fase 3), `miedo.md` (sonidos que faltan), `TASKS.md` (marcar lo hecho y
   la lista de pendientes para Studio), y borrar `docs/continuar/`.
3. Push y descripción de la PR #24 al día (con la herramienta de GitHub).
4. Entregar a Sergio, en español y corto: qué se ha hecho por fases, los fallos arreglados por prioridad, qué probar
   en Studio con pasos, las ideas no hechas y los sonidos o imágenes que faltan.

## Notas para el resumen final

- Revisión de la Fase 1: 76 hallazgos, 75 confirmados por un verificador escéptico (3 GRAVE, 26 MEDIO, 46 MENOR);
  arreglados todos los GRAVE y MEDIO y casi todos los MENOR, en 14 commits. Los 3 GRAVE: el coche del lobby que se
  quedaba inservible tras un viaje, el Acechador que mataba dentro de la casa (torre, esquinas, lavadero) y las
  cerillas que se perdían si amanecía con el fuego camino del sótano (sin final de la Bestia).
- MENOR sin arreglar: las manos pueden agarrar el tablón de otro (`ManosGestos`, haría falta un atributo `Quien` en el
  agarre desde `Cargar.coger`); posible pérdida de la mochila guardada si alguien se va antes de cargar la partida
  (`Partida`, sin comprobar).
- Ideas no hechas: tropezar o frenar al correr cansado (no hay sistema de cansancio ni de correr: sería cambiar la
  jugabilidad, preguntar a Sergio).
- Teclas nuevas: V revivir a un compañero (cruceta izquierda), K saltar el tutorial (cruceta derecha), P ajustes; y las
  de la Fase 3 (C/Ctrl/ButtonB agacharse, Z/X asomarse, la de mirar que elija el agente de `mirar`).
- Sonidos que faltan (ElevenLabs): del lobby `Config.SonidosLobby` (Lluvia, LluviaChapa, Trueno, Radio, Campanilla,
  Arranque); de la partida, en `Config.Sonidos` con Id 0 (Respiracion, Contener, Exhalar, Mirilla, Vajilla, Mecedora);
  y los 8 provisionales de 14.3 que ya estaban apuntados.
- Lune 0.10.5 tiene un fallo en `CFrame.lookAt` mirando justo hacia ±Z (lo notaron tres agentes): no afecta al juego,
  solo a las pruebas que lo usen.
- Copia de seguridad del árbol a medias, por si un parche no aplicara: no la hay en el repo (estaba en el scratchpad
  de la sesión, que se pierde); los parches son la única copia.
