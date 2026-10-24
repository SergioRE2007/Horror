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

## Lo aprendido

- El frente: lo que en Blender mira a -Y (así vienen los de Poly Haven) sale en Roblox mirando a -Z, el frente del juego. Por eso `--girar` es 0 por defecto. La vista `.png` se hace desde ese lado.
- El importador de glTF gira con cuaterniones: el script transforma la malla directamente (`rotation_euler` no hacía nada).
- Envejecer: la textura de color sale menos saturada, amarillenta, más oscura y con manchas grandes y grano (`manchas()`, misma semilla siempre). Las telas claras siguen viéndose claras de noche: para ellas, `--oscurecer 0.7`.
- `Mapa.tienda` apaga el color de las piezas, pero con `SurfaceAppearance` eso no cambia nada: el envejecido va en la textura.
- Rendimiento: unos 5.000 triángulos y 4 texturas de 1024 por mueble. Las cosas pequeñas, con `--res 1k` y `--tris 1500` o menos.
