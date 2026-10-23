# Arte: modelos de Blender (paso 11.1)

La jugabilidad no cambia: las piezas de siempre siguen ahí para chocar (invisibles cuando hay malla encima) y en los mismos sitios. Sin el archivo de mallas, el juego se ve con los bloques de antes.

## Bosque

- `tools/blender/crear_bosque.py` (`blender -b --factory-startup --python tools/blender/crear_bosque.py [-- --only Pino]`): pinos (`Pino`, `PinoB`, `PinoSeco`), la copa de los árboles que se talan (`CopaTalable`), rocas, arbusto, helecho y tronco caído. Vistas `bosque1-3.png` en `Documents\Roblox\modelos` (EEVEE, con la textura).
- Pedido por el usuario ("mejora los pinos"): las ramas son tiras planas con una textura de agujas con transparencia (papel `Rama`), dos cruzadas por rama, que caen hacia la punta; los helechos usan la misma textura. La textura la dibuja `tools/texturas/agujas.ps1` (System.Drawing) y está subida como `rbxassetid://123991254477562`.
- En Roblox la transparencia de la textura solo se respeta si la pieza tiene algo de transparencia (`0.02`) y con `Fabric` (con `SmoothPlastic` las zonas transparentes reflejaban el cielo en blanco). Lo pone `shared/Piezas`.
- Caras con UV de caja (una baldosa cada 6 studs) para que madera, roca y hierba de Roblox se vean con su textura; corteza, roca y musgo con sombreado suave.

## Casa

- `tools/blender/crear_casa.py`: cama, molduras del armario, sofá, mesita, alfombra, cuadro, lámpara, mesa, silla, cocina (encimera, fregadero bajo la ventana, cocina de hierro y armarios de arriba), estantería con libros, bañera de patas, váter, lavabo con espejo y escritorio. Cada uno a la medida del bloque de `Mapa` que tapa (origen en el centro de su base, frente a -Z). Lo común de los dos scripts está en `tools/blender/geometria.py`.
- `Mapa.mueble(nombre, cf, bloques)` pone el mueble y deja invisibles los bloques que tapa (siguen chocando; las camas y armarios siguen siendo escondites). Sillas, váter y lavabo (solo existen con las mallas) llevan su caja invisible.
- Paredes de fuera de tablas viejas (`COLOR.Fachada`), las de dentro de yeso sucio; las de dentro acaban en el centro de la pared que tocan (si no, asomaban en la fachada). Marcos de madera en puertas y ventanas, cruceta en los cristales y porche con tejadillo: `adorno`, sin chocar ni tapar rayos.
- Lámparas: la de Blender cuelga del techo y el bloque de siempre pasa a ser la bombilla (bola) dentro de la pantalla, sin sombra en la pantalla para no tapar la luz.
- `Separar` hace hasta 20 vueltas (con los marcos no llegaban 8).

## Pasarlo al juego

1. `node tools/blender/subir_modelo.mjs <archivo.fbx> <clave>` (modelo del grupo por Open Cloud; da el id).
2. Un receptor en `localhost:8766` que guarde lo que le llega en un archivo, y en Studio (modo Edit) `game:GetObjects("rbxassetid://<id>")`, una línea por MeshPart `Nombre;MeshId;tamaño;CFrame` y `HttpService:PostAsync` con `HttpEnabled` encendido solo ese momento (devolverlo como estaba).
3. `node tools/blender/volcar.mjs <volcado.txt> src/shared/BosqueMallas.rbxmx BosqueMallas`.

## En el juego

- `shared/Piezas.poner(padre, pieza, cf, escala, papeles)`: mallas ancladas, sin chocar ni tapar rayos (`CanQuery = false`), con el color, material y textura de su papel (`ASPECTO`).
- `Mapa`: cada tronco del bosque lleva un pino (la variedad sale de su sitio, no del azar del bosque, que movería los árboles guardados); el tronco se queda invisible para chocar y la corteza se escala a su grosor. Los árboles que se talan llevan la `CopaTalable` soldada al tronco con el nombre `Copa` (Recursos la quita al partirlo). Sotobosque con su propio azar, lejos de la casa, del camino y de los sitios; rocas y troncos caídos con una caja invisible. Suelo `LeafyGrass` (hojarasca).
- Lobby (`Gasolinera`): los mismos pinos sobre sus troncos.

## Probar

- Para capturas, la cámara fija (`BindToRenderStep` + `Scriptable`) deja los avisos (`ProximityPrompt`) sin salir: soltarla y volver a cargar el personaje antes de probar a talar o coger cosas.
