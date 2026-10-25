# Salas en paralelo: varios chats y varios Studios a la vez

Pedido por el usuario (25-10-2026): "estamos tardando mucho", que varios chats hagan una sala cada uno a la vez, cada
uno con su Studio. Aprobado por el usuario reiniciar una vez la tarea "Rojo Horror" para el paso A (cambia
`juego.project.json`).

## Por qué hace falta prepararlo

- **Muebles:** `ServerStorage.Muebles` sale de un solo binario, `src/muebles/Muebles.rbxm`; git no junta dos versiones
  de un binario: el último que guarda borra los muebles de los demás.
- **Studio y Rojo:** un Studio solo tiene una partida a la vez, y la tarea "Rojo Horror" sirve una sola carpeta.
- **Puertos fijos:** el receptor de `Muebles.rbxm` (`tools/receptor.mjs`, 8766) y el servidor de texturas para
  `upload_image` (8777) chocarían entre chats.
- `Mapa.luau` es texto: git lo junta bien si cada chat toca solo su sala.

## A. Un archivo de muebles por sala (en este proyecto, rama `paso-11-fin`)

1. `juego.project.json`: `"Muebles": { "$path": "src/muebles" }`. La carpeta tendrá `Muebles.rbxm` (lo de hasta
   ahora, sin tocar) y un `<Sala>.rbxm` por sala nueva (una `Folder` con los muebles de esa sala). En Studio queda
   `ServerStorage.Muebles.Muebles.<mueble>` y `ServerStorage.Muebles.<Sala>.<mueble>`.
2. `Mapa.luau`: en vez de `MUEBLES:FindFirstChild(nombre)` (en `tienda`, `contraPared`, `abandonar` y donde haya más),
   una tabla `nombre -> molde` hecha al cargar recorriendo cada carpeta de `ServerStorage.Muebles` (avisar con `warn`
   si un nombre sale dos veces). Nada de `FindFirstChild(nombre, true)`: dentro de cada modelo hay MeshParts con el
   mismo nombre que el modelo.
3. Mirar quién más lee `ServerStorage.Muebles` (`tools/plugin/VistaMapa.lua`, `Casa.luau`, tests…) y adaptarlo.
4. `docs/sistemas/polyhaven.md`, paso 6: cada sala guarda solo su carpeta (`ServerStorage.Muebles.<Sala>`) en
   `src/muebles/<Sala>.rbxm`; no se vuelve a guardar `Muebles.rbxm`.
5. `tools/receptor.mjs` con `--puerto` (8766 por defecto) y el servidor de texturas con su puerto, para que cada chat
   use el suyo.
6. Reiniciar la tarea: `Stop-ScheduledTask "Rojo Horror"; Start-ScheduledTask "Rojo Horror"` y pedir al usuario
   Rojo → Connect.
7. Probar: contar los modelos de `Mapa.Casa` en Play antes y después del cambio (tienen que salir los mismos), sin
   errores en la consola; `selene src` y Lune. Commit.

## B. Una copia del proyecto por sala

1. `tools/paralelo/nueva-sala.ps1 -Sala Galeria -Puerto 34874`: `git worktree add ..\Horror-Galeria -b sala-galeria
   paso-11-fin`, copia `juego.rbxl` a `..\Horror-Galeria\juego-Galeria.rbxl` (el nombre con el que el chat reconoce su
   Studio en `list_roblox_studios`) y deja `rojo serve juego.project.json --port <puerto>` corriendo sin ventana en esa
   carpeta. `tools/paralelo/quitar-sala.ps1 -Sala Galeria` para el Rojo de esa copia y quita la copia (después de
   juntarla).
2. Puertos de cada sala: Rojo 34874, 34875, 34876…; receptor 8767, 8768, 8769…; texturas 8778, 8779, 8780…
3. Comprobar antes de nada que dos Studios conectan a la vez a puertos distintos (`datos.md` avisa de que el plugin de
   Rojo a veces se queda en el 34872). Si no se puede, decirlo y parar.
4. Primeras tres: 11.8.7 galería, 11.8.8 dormitorio grande y 11.8.9 habitación del rico (arriba, salas distintas).

## Reglas para cada chat de sala

- Trabaja solo en su copia (`..\Horror-<Sala>`), con su Studio (`juego-<Sala>.rbxl`) y sus puertos (arriba).
- Hace su sala como dice `docs/plan-salas.md` (propuesta con 2 opciones, muebles, revisión, VistaMapa…).
- Toca solo lo de su sala: su trozo de muebles y su `vestir<Sala>()` en `Mapa.luau`, su línea de `SALAS`, sus
  `src/materiales/`, su `src/muebles/<Sala>.rbxm` y su apartado en `plan-salas.md` y `polyhaven.md`. Si necesita
  cambiar algo común (`tienda`, `cama`, `armario`, `a_mano.py` fuera de sus muebles), lo apunta en el commit.
- No marca `TASKS.md` ni junta con `paso-11-fin`: termina con commit en su rama `sala-<sala>`.

## C. Juntar (un chat al final)

- Juntar cada rama `sala-*` en `paso-11-fin` de una en una, arreglando los choques de `Mapa.luau` y de los `.md`.
- Play con todo junto: cada sala con sus muebles, sin errores, escondites funcionando. Marcar en `TASKS.md` lo aprobado.
- `quitar-sala.ps1` de cada copia.
