# Muebles de Poly Haven (11.8.0)

Modelos CC0 de polyhaven.com (uso comercial libre, sin citar), pasados por Blender a un `MeshPart` con `SurfaceAppearance`. Probado de punta a punta con la butaca (`ButacaPH`, de `ArmChair_01`), que ya sustituye a las tres butacas de la tienda en `Mapa`.

## Pasos por mueble

1. **Elegir** en polyhaven.com/models o con la API (`https://api.polyhaven.com/assets?t=models&s=<búsqueda>`); el id es el de la URL (`ArmChair_01`).
2. **Blender** (sin abrirlo): `blender -b --factory-startup --python tools/blender/polyhaven.py -- --id ArmChair_01 --nombre ButacaPH`. Opciones: `--alto` (studs) o `--escala` (studs por metro, 4 por defecto, como la nevera y el reloj), `--girar` (grados, si sale de espaldas), `--tris` (5000), `--res` (1k), `--oscurecer` (0,85). Lo bajado se guarda en `Documents\Roblox\modelos\polyhaven\_bajados`; lo hecho, en `polyhaven\<nombre>\`: `.fbx`, `_color`, `_normal`, `_rugosidad`, `_metal` (`.png`) y una vista de frente (`<nombre>.png`).
3. **Subir la malla**: `node tools/blender/subir_modelo.mjs <.fbx> ..\clave-roblox.txt` (da el id del modelo).
4. **Subir las texturas**: servir la carpeta con `node tools/servir.mjs <carpeta>` (puerto 8777; en una copia de sala, el suyo con `--puerto`: `plan-paralelo.md`) y `upload_image` de Studio con las cuatro URL. Recién subidas tardan unos 30 s en verse (el mueble sale blanco mientras tanto).
5. **Montarlo en Studio** (modo Edit): `game:GetObjects("rbxassetid://<id>")`, coger el `MeshPart`, ponerlo en `CFrame.new(0, alto/2, 0)` dentro de un `Model` con el nombre del mueble, `WorldPivot` en el origen, un `SurfaceAppearance` con los cuatro mapas y los atributos `Tam` (tamaño), `Id` (id del modelo) y `Fuente` ("Poly Haven <id> (CC0)"). Meterlo en `ServerStorage.Muebles.<Sala>`.
6. **Guardar** la carpeta de la sala: cada sala nueva tiene la suya, `ServerStorage.Muebles.<Sala>` (una `Folder`), guardada en `src/muebles/<Sala>.rbxm`; `Muebles.rbxm` (lo de antes de las salas en paralelo) ya no se vuelve a guardar. `node tools/receptor.mjs src/muebles/<Sala>.rbxm --base64` (en una copia de sala, con su `--puerto`) en segundo plano y en Studio serializar una copia de esa carpeta con un solo mueble por nombre (en Studio a veces salen copias repetidas, como tres `Mecedora`), `EncodingService:Base64Encode` y `HttpService:PostAsync("http://localhost:<puerto>", ...)` con `HttpEnabled` encendido solo ese momento. Comprobar con Lune que la carpeta trae todos (Lune no lee `MeshId` ni los mapas: eso se mira en Play). Un nombre de mueble no puede repetirse entre carpetas (`Mapa` avisa con `warn` y usa el primero).
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

## Cocina (11.8.4)

- `a_mano.py`: muebles de cocina por módulos de 3 de ancho (`EncimeraCocina`, `EncimeraAbierta`, `FregaderoCocina`, `AlacenaCocina`, `AlacenaAbierta`): cuerpo hueco con interior oscuro y puertas de cuarterones que se pueden dejar abiertas (`puerta_cocina`, giro en la bisagra). `MUEBLES_LIMPIOS`: muebles enteros sin las manchas grandes (en la madera pintada clara parecían camuflaje). Con la puerta abierta el `Tam` crece hacia delante, pero la espalda sigue en la pared: `contraPared` los pone bien.
- Paredes y techos lisos (`painted_plaster_wall`, `plastered_wall_04`) con `textura_ph.py --limpia`: con manchas parecían camuflaje. Las damas de `checkered_pavement_tiles`, a `StudsPerTile` 16.
- Alturas de las baldas de un mueble de Poly Haven: los rayos de Studio chocan con su caja (no se puede cambiar `CollisionFidelity` desde un script en Edit); medirlas en Blender con las caras que miran arriba.
- `wooden_bookshelf_worn` a `--alto 8.5` sirve de despensa; `painted_wooden_shelves` es un estante pequeño de pared (no despensa); `ceramic_pot` es una tinaja grande para el suelo; `fish_knife` sale de pie (tumbarlo con 90° en X).
- **Guardar `Muebles.rbxm` en trozos:** con la cocina pasa de 1024 KB aun con Zstd. Partir el texto en Base64 en trozos de 900 KB y mandar cada uno con la cabecera `X-Trozo: k/n`: `tools/receptor.mjs` los junta y escribe al llegar el último.
- El resumen de las texturas subidas (pieza → id) se sirve a Studio como `.json` desde `tools/servir.mjs` (puerto 8777 o el de la copia de sala) (`HttpService:GetAsync`), en vez de pegarlo en el código.

## Pasillo, baño y trastero (11.8.5)

- `a_mano.py`: `VaterViejo` (cisterna alta con cadena), `LavaboPie`, `CortinaDucha` (barra en U con `camino_u`), `Toallas`, `Paraguero` (`paraguas()` sale del perchero, con `grueso`) y `CadenaPuerta` (`eslabon()`). `loza()` hace la imagen de loza vieja. Los que no empiezan en el suelo (la cortina, dentro de la bañera, a 1,4; la cadena, a 3,2) tienen el pivote en su punto más bajo: se ponen con ese desfase.
- Retratos de familia: `hanging_picture_frame_03` es un marco ovalado cuya foto es la pieza `_2`; `tools/texturas/retratos.ps1` hace tres fotos en sepia con las caras rayadas y se montan como `CuadroFamiliaPH`, `PH2` y `PH3` (el mismo marco con otra `ColorMap`).
- `textura_ph.py --rayas --colores` cambia los colores de las rayas (el pasillo, burdeos). `sangre.py` hace también `Aranazos` y `Grietas` (espejo roto).
- Cosas de Poly Haven: `steel_frame_shelves_01` viene a escala 10 (usar `--alto`); `vintage_telephone_wall_clock` es un teléfono de pared rojo, sin auricular suelto; `medical_box` es un botiquín plano y cerrado; `vintage_suitcase` son dos maletas juntas; `terry_cloth` es azul (las toallas, con `rough_linen`). Alturas de baldas medidas en Blender con las caras que miran arriba (la estantería de metal: 0,5, 2,6, 4,6, 6,6 y 8,6).
- Una textura recién subida que falla la primera vez se queda en blanco en modo Edit aunque luego ya cargue (`ContentProvider:PreloadAsync` da `Success`): en Play sí se ve. Mirarlo en Play antes de rehacer nada.
- `ServerStorage.Muebles` puede tener copias repetidas tras guardar `Muebles.rbxm` (Rojo): al cambiar un mueble en Studio, cambiar todas las copias.
- La textura de óxido en una cadena no se distinguía de la madera oscura de la puerta: hierro gris (`liso`) con el envejecido.
- `mancha()` en el suelo: con `giro` 0 el largo (`alto`) va a lo largo de x; para que vaya en z, `math.pi / 2`.
- Lo que va en una puerta que se abre (arañazos, la mano) se pone en un `SurfaceGui` de la `Hoja`, que gira con ella; la cadena va dentro del modelo de la puerta como `Cadena` y `Casa` la esconde cuando ya no está cerrada con llave.

## Dormitorio de abajo (11.8.6)

- `a_mano.py`: `ColchaCama` (colchón, colcha y almohada para la cama de hierro), `AlfombraTrapo`, `CosasMesilla`, `Zapatillas`, `RopaSilla` y `MantaMecedora`. `cojin()` hace cajas redondeadas (supercuádricas); `ganchillo()` y `alfombra_dormitorio()`, las imágenes de la colcha de cuadros y de la alfombra trenzada. Lo que va encima de otro mueble (colcha, ropa, manta) se hace en los ejes de ese mueble y se pone con su mismo CFrame más el desfase que imprime `a_mano.py` (`ABAJO` y `CENTRO`: el pivote del montaje es el centro de abajo de la caja).
- Lo de colores lisos y pequeño (`CosasMesilla`, la suela, el colchón) no sube texturas: al montarlo se le pone color, material y transparencia a la MeshPart (el vaso y el agua, medio transparentes).
- Para comprobar que encajan, `juntar.py` (en el scratchpad de la sesión) importaba los `.fbx` juntos y hacía una vista; medir alturas de asientos y baldas: caras que miran arriba en Blender.
- `textura_ph.py --flores`: papel de florecillas encima de `decrepit_wallpaper`, con `--limpia` (con las manchas del envejecido parecía camuflaje, como en la cocina).
- `old_bed_frame` es de hospital: 0,9 × 2 m, somier de malla a 2,25 del suelo (a `--escala 4.6`) y la cabecera a +Z. `cama()` de `Mapa` acepta un mueble (`aspecto`) y su colcha (`ropa`) con su ancho y largo: los bloques que chocan se hacen a esa medida y quedan invisibles.
- El suelo de las salas (la lámina del `MaterialVariant`) tiene la cara de arriba a `ABAJO + 0,06`: una alfombra fina a `ABAJO + 0,02` parpadeaba con él (va a `+ 0,075`).

## Habitación del rico (11.8.9)

- `a_mano.py`: `EscritorioRico`, `LamparaBanquero` (media caña gruesa de cristal verde; la bombilla va en `Mapa`, a 1,08), `CosasEscritorio` (mismo CFrame que el escritorio), `GloboTerraqueo`, `TableroHilos`, `CuernosCiervo`, `CajaFuerte` y `Licores`. `escritura()` hace papel con letra a mano, `mapamundi()` el globo y `corcho()` el tablero.
- **Atlas con UV propia:** `Mueble.uv[papel] = f(x, y, z) -> (u, v)` (ejes del juego) cambia la UV de caja de ese papel. El tablero pone el mapa, cinco fotos y tres recortes en una sola imagen (`atlas_tablero`, `TABLERO` dice dónde va cada uno): una subida en vez de una por foto. De frente la derecha es -x: `u = (x0 + ancho - x) / ancho`.
- Lo que cuelga con la espalda en el pivote (cuernos, caja fuerte) no va con `contraPared` (que supone el pivote en medio del fondo): `enPared` de `vestirHabitacionRico`.
- **Texturas que fallan al subirlas:** si un mapa falla la primera vez (`NetFail`), Studio deja ese `SurfaceAppearance` en blanco toda la sesión, aunque luego cargue, y volver a subir la misma imagen (con `?v=2`) devuelve el mismo id. Cambiar un píxel (`ffmpeg ... drawbox=x=0:y=0:w=1:h=1`) y subir esa copia (`_b.png`) da un id nuevo; poner un `SurfaceAppearance` nuevo con él.
- `SurfaceAppearance.Color` tiñe un mueble de Poly Haven: las librerías pálidas del salón, aquí más oscuras, sin otro molde.
- `Model:ScaleTo` sirve para dejar un molde a otro tamaño (ajedrez a 0,75 para que quepa en la mesita; el retrato, el marco de `CuadroPH2` a 1,4), con su `Tam` al día.
- Arriba, el suelo de la sala está a `ARRIBA + 0,18` (el `Piso` engordado por `Separar`; el chat de la galería hizo `sueloArriba`), y la moldura del zócalo sale 0,25 de la pared: las caras útiles de esta sala son z 8,15 y -32,25 y x -38,05 y -12,85.
- `GothicCabinet_01` a `--alto 4.2` (a la escala normal es un armario de 9,4); `GreenChair_01` sirve de sillón de despacho tal cual; `bull_head` y `lion_head` son bustos de bronce con peana, no cabezas de pared.
