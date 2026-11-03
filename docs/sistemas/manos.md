# Manos, brazos y cámara con cuerpo (animaciones en primera persona)

Pedido por el usuario (03-11-2026):
- "Cuando abras las cortinas o las cierres (el juego es primera persona) que se vea cómo lo abres o lo cierras con las manos, y eso con todas las animaciones posibles".
- "No hace falta que hagas los dedos: con que el brazo normal esté bien animado es suficiente, hay personajes de Roblox que no tienen dedos".
- "Lo importante es que todo esté animado y sea inmersiva la experiencia".

Hecho en una sesión en la nube **sin Studio**: las poses salen de cuentas (comprobadas con Lune: orientaciones y largos), pero no se han visto. Hay que mirarlas y retocarlas en Studio (números al principio de cada módulo).

## Tus manos (`juego/cliente/Manos`, `ManosGestos`)

- Son copias de los brazos R15 de tu avatar (con tu camiseta y tu piel), adelgazadas a 0,42 de grueso (las de verdad miden 1 stud y taparían media pantalla) y con el mismo largo con cualquier avatar. Con R6, un brazo de bloques con manga oscura. Cuelgan de la cámara; los hombros quedan fuera de la vista.
- Cada mano va hacia un objetivo (la palma: -Z los dedos, +Y el dorso) y el codo sale solo (cinemática inversa de dos huesos). Un muelle la lleva hasta allí; al andar se mecen y quietas respiran.
- Capas por prioridad: linterna 10, móvil 20, pistola 25, cargar 30, herramienta 40, gestos 50, foto 60 y susto 90. Sin capa, bajan fuera de la vista.
- Se esconden muerto, escondido, con la mochila abierta y en las cinemáticas (cámara Scriptable), menos el susto al morir.

| Qué | Cómo |
|---|---|
| Cortinas | Las dos manos cogen el borde de cada paño y lo corren con él |
| Puerta | La derecha coge el pomo, lo gira y lo acompaña. Si está cerrada con llave, la mano traquetea con el pomo |
| Coger un objeto | La mano baja, lo coge y se va hacia el bolsillo |
| Cargar algo pesado | Las dos manos van a sus lados y lo llevan (siguen a la pieza) |
| Generador | Coge la cuerda y da el tirón. Para apagarlo, aprieta el botón |
| Esconderse / salir | Empuja la puerta del armario. Al salir, las dos manos empujan |
| Pista | La coge y la sube a la cara |
| Enchufe | Lleva el móvil al enchufe |
| Banco del taller | Las dos manos se apoyan |
| Mantener pulsado | Palanca (tira poco a poco), cerilla (la raspa, prende y la baja al rastro), volante al huir |
| Linterna | En la izquierda; la luz sale de ella. Con poca pila, la sacude de vez en cuando |
| Móvil | En la derecha, con la pantalla hacia ti |
| Foto | Las dos manos suben la cámara a la cara |
| Pistola de bengalas | La derecha en el mango y la izquierda debajo |
| Hacha, sierra, martillo, llave (TrabajoVista) | Las manos en el mango; la izquierda sujeta lo que trabajas |
| Te pillan | Las manos se levantan temblando, abajo para no tapar la cara del bicho |
| Cualquier otro cartel | La mano va y lo toca |

- Para añadir uno: en `ManosGestos.alPulsar` (por el `ActionText` del cartel o la etiqueta del modelo) con `Manos.gesto(nombre, segundos, fn)`. Para algo que se lleva: `Manos.cosa` y `cosaDer` / `cosaIzq` en la pose.

## Los demás jugadores (`juego/cliente/BrazosVista`)

- Cada cliente gira los hombros R15 de los otros personajes (C0 de `RightShoulder` / `LeftShoulder`) encima de su animación de andar. Se ve cuando trabajan (hacia el mango de la herramienta), cargan, alumbran, miran el móvil, hacen una foto, disparan una bengala, o corren una cortina o abren una puerta junto a ellos.
- R6: se quedan con sus animaciones de serie.

## La cámara como un cuerpo (`juego/cliente/CuerpoVista`)

- Al andar, la cabeza sube y baja con cada paso (la misma zancada que los sonidos de `Pasos`) y se mece. Al moverte de lado se inclina, al caer de alto baja de golpe y vuelve, y quieto respira (más rápido con un bicho a menos de 30 studs).
- Con lo pesado manda `CargarVista`. Nunca en cinemáticas, escondido ni muerto.
- Al esconderse (`MuerteVista`), la cámara va de los ojos al escondite en medio segundo agachándose, en vez de saltar.

## Probar en Studio

- **Cortinas:** abrir y cerrar varias, cerca y desde lejos (a 8 studs las manos se quedan estiradas hacia ellas).
- **Puertas:** una puerta y la del sótano cerrada con llave.
- **Objetos:** coger un objeto y un tronco, y andar con él.
- **Herramientas:** talar, serrar y clavar, y arrancar el generador.
- **Equipo:** linterna con poca pila, foto y pistola de bengalas.
- **Escondite y muerte:** esconderse, salir y morir.
- **Avatar:** mirar con un avatar R15 con camiseta y con uno R6.
- **Dos jugadores:** que se vean los brazos del otro.
- **Si algo se ve mal:**
  - `HOMBRO`, `REPOSO`, `L1` y `L2` en `Manos`;
  - las posiciones de cada gesto en `ManosGestos`;
  - `SITIO` en `TrabajoVista` (dónde va tu herramienta).
