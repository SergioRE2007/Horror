# Muebles de Poly Haven (11.8.0)

Modelos CC0 de polyhaven.com (uso comercial libre, sin citar), pasados por Blender a un `MeshPart` con `SurfaceAppearance`. Probado de punta a punta con la butaca (`ButacaPH`, de `ArmChair_01`), que ya sustituye a las tres butacas de la tienda en `Mapa`.

## Pasos por mueble

1. **Elegir** en polyhaven.com/models o con la API (`https://api.polyhaven.com/assets?t=models&s=<búsqueda>`); el id es el de la URL (`ArmChair_01`).
2. **Blender** (sin abrirlo): `blender -b --factory-startup --python tools/blender/polyhaven.py -- --id ArmChair_01 --nombre ButacaPH`. Opciones: `--alto` (studs) o `--escala` (studs por metro, 4 por defecto, como la nevera y el reloj), `--girar` (grados, si sale de espaldas), `--tris` (5000), `--res` (1k), `--oscurecer` (0,85). Lo bajado se guarda en `Documents\Roblox\modelos\polyhaven\_bajados`; lo hecho, en `polyhaven\<nombre>\`: `.fbx`, `_color`, `_normal`, `_rugosidad`, `_metal` (`.png`) y una vista de frente (`<nombre>.png`).
3. **Subir la malla**: `node tools/blender/subir_modelo.mjs <.fbx> ..\clave-roblox.txt` (da el id del modelo).
4. **Subir las texturas**: servir la carpeta con un servidor local (`node -e` con `http.createServer` en el puerto 8777) y `upload_image` de Studio con las cuatro URL. Recién subidas tardan unos 30 s en verse (el mueble sale blanco mientras tanto).
5. **Montarlo en Studio** (modo Edit): `game:GetObjects("rbxassetid://<id>")`, coger el `MeshPart`, ponerlo en `CFrame.new(0, alto/2, 0)` dentro de un `Model` con el nombre del mueble, `WorldPivot` en el origen, un `SurfaceAppearance` con los cuatro mapas y los atributos `Tam` (tamaño), `Id` (id del modelo) y `Fuente` ("Poly Haven <id> (CC0)"). Meterlo en `ServerStorage.Muebles`.
6. **Guardar** `src/muebles/Muebles.rbxm`: `node tools/receptor.mjs src/muebles/Muebles.rbxm --base64` en segundo plano y en Studio serializar una copia de la carpeta con un solo mueble por nombre (en Studio a veces salen copias repetidas, como tres `Mecedora`), `EncodingService:Base64Encode` y `HttpService:PostAsync("http://localhost:8766", ...)` con `HttpEnabled` encendido solo ese momento. Comprobar con Lune que la carpeta trae todos (Lune no lee `MeshId` ni los mapas: eso se mira en Play).
7. **Ponerlo** en `Mapa` con `tienda(nombre, cf)` o `contraPared(...)`, como los demás.

## Varios materiales, hechos a mano y texturas de sala (11.8.1)

- **Varios materiales** (araña, cuadros, reloj): `polyhaven.py` saca una malla por material, `<nombre>_1`, `_2`…, cada una con sus texturas (`<nombre>_1_color.png`…) o con su color liso si el material no tiene imagen; lo dice `<nombre>_piezas.json`. En Studio, un `SurfaceAppearance` por MeshPart, o color liso para las `liso`.
- **`--formato blend`**: el importador de glTF de Blender 5.2 falla con algunos (el reloj de pie: `IndexError`). El `.blend` trae el esqueleto y sus mandos (`wdg_*`): se quitan las mallas sin material.
- **Lo que no hay en Poly Haven** (perchero con abrigo y sombrero, cartas, alfombra larga, barrotes y poste de la escalera, rosetón): `tools/blender/a_mano.py --nombre <X>`, geometría por script con texturas de Poly Haven y el mismo envejecido. Un papel = un material = una MeshPart. Las láminas de una cara (alfombra, sobres) van con la cara hacia arriba (`ARRIBA`); si no, no se ven.
- **Paredes, suelos y techos propios de cada sala**: `MaterialVariant` en `src/materiales/<Nombre>.model.json` (Rojo, `MaterialService.Materiales`), con texturas de `tools/blender/textura_ph.py --id <textura> --nombre <X> [--tinte r,g,b] [--limpia]`. El color de la pieza no tiñe un MaterialVariant: el tinte va en la textura. En suelos, `--limpia` (las manchas del envejecido se veían en cuadrícula). En el código, `variante(pieza, "<X>")`.
- **Sangre seca y desconchones**: `tools/blender/sangre.py` hace las imágenes con transparencia (gotas, arrastre, salpicadura, papel arrancado) y se ponen con `mancha()` de `Mapa`.
- **Texturas recién subidas**: durante un rato salen en blanco ("*Asset content representation is being generated*"), y si falla un solo mapa, el `SurfaceAppearance` o el `MaterialVariant` entero sale blanco (pasó con el relieve de los paneles del vestíbulo y con dos mapas de un cuadro). Esperar y volver a mirar antes de tocar nada; si uno no carga nunca, quitar ese mapa.
- Las texturas iguales (la madera oscura del perchero, los barrotes y el poste) se suben una vez: Roblox da el mismo id.

## Salón (11.8.2)

- `a_mano.py`: color liso (`("liso", rgb)`) o imagen hecha por una función (teclas del piano, alfombra persa) en vez de una textura de Poly Haven; `tela()` hace telas con grueso que se ven por las dos caras (cortinas); el sofá tapado sale de cajas fundidas con un remallado en vóxeles y pliegues hacia abajo. `LIMPIOS`: telas claras sin las manchas grandes del envejecido (la sábana parecía piedra).
- `textura_ph.py --rayas`: papel de rayas verticales encima de un papel de Poly Haven.
- Marcos de fotos y cuadros de Poly Haven: la pieza de delante (`_3`) es el cristal y trae la textura del marco: tapa la foto (sale negra). Se le quita el `SurfaceAppearance` y queda de cristal transparente.
- Guardar `Muebles.rbxm`: `EncodingService:Base64Encode` devuelve un `buffer`: pasarlo por `buffer.tostring` antes de `PostAsync` (sin eso se guardó un archivo de 7 bytes).
- Los que tienen la pared en diagonal (torre) no los viste `vestirParedes`: papel, rodapié, suelo y techo de la torre van aparte (`vestirSalon`).

## Lo aprendido

- El frente: lo que en Blender mira a -Y (así vienen los de Poly Haven) sale en Roblox mirando a -Z, el frente del juego. Por eso `--girar` es 0 por defecto. La vista `.png` se hace desde ese lado.
- El importador de glTF gira con cuaterniones: el script transforma la malla directamente (`rotation_euler` no hacía nada).
- Envejecer: la textura de color sale menos saturada, amarillenta, más oscura y con manchas grandes y grano (`manchas()`, misma semilla siempre). Las telas claras siguen viéndose claras de noche: para ellas, `--oscurecer 0.7`.
- `Mapa.tienda` apaga el color de las piezas, pero con `SurfaceAppearance` eso no cambia nada: el envejecido va en la textura.
- Rendimiento: unos 5.000 triángulos y 4 texturas de 1024 por mueble. Las cosas pequeñas, con `--res 1k` y `--tris 1500` o menos.

## Comedor (11.8.3)

- **Techos tapados (arreglado para toda la casa):** `Separar` engorda 0,15 el suelo de arriba (`Piso`) y el techo de yeso de cada sala, a `ALTO - 0,03`, quedaba dentro: se veían las tablas del suelo de arriba en todas las salas, también en el salón y la torre. Ahora van a `ALTO - BAJO_TECHO` (0,2), con el roto, los rosetones y las arañas.
- **Alargar un mueble:** el `Size` del `MeshPart` se puede estirar en un solo eje (la mesa del comedor, de 9 a 13 de largo, con su `Tam` al día). Un mueble muy pequeño o desproporcionado se rehace con `--escala` o `--alto` (el aparador es un arcón bajo, `gallinera_table`, a `--escala 7.5`).
- **Lo que no vale:** `WoodenChair_01` es un trono de 2,3 m (no sirve de silla de cabecera); `wine_bottles_01` sale en 8 piezas con sus texturas (demasiadas subidas para unas botellas); `wooden_candlestick` trae 213.000 triángulos y a 700 se deshace (a 3.000 bien).
- `a_mano.py`: `PlantaSeca`, tallos secos y hojas arrugadas para meter en `MacetaPH` (`planter_pot_clay` a `--escala 8`).
- **Guardar `Muebles.rbxm`:** `PostAsync` no deja mandar más de 1024 KB (lo mide antes de su Gzip, así que `compress` no ayuda). Comprimir con `EncodingService:CompressBuffer(datos, Enum.CompressionAlgorithm.Zstd, 9)` antes del Base64 y mandar la cabecera `X-Comprimido: zstd`: `tools/receptor.mjs` lo descomprime.
- Subir otra vez una textura cambiada: añadir `?v=2` a la URL de `upload_image` (si no, puede devolver el id viejo).
