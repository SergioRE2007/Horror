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

## Lo aprendido

- El frente: lo que en Blender mira a -Y (así vienen los de Poly Haven) sale en Roblox mirando a -Z, el frente del juego. Por eso `--girar` es 0 por defecto. La vista `.png` se hace desde ese lado.
- El importador de glTF gira con cuaterniones: el script transforma la malla directamente (`rotation_euler` no hacía nada).
- Envejecer: la textura de color sale menos saturada, amarillenta, más oscura y con manchas grandes y grano (`manchas()`, misma semilla siempre). Las telas claras siguen viéndose claras de noche: para ellas, `--oscurecer 0.7`.
- `Mapa.tienda` apaga el color de las piezas, pero con `SurfaceAppearance` eso no cambia nada: el envejecido va en la textura.
- Rendimiento: unos 5.000 triángulos y 4 texturas de 1024 por mueble. Las cosas pequeñas, con `--res 1k` y `--tris 1500` o menos.
