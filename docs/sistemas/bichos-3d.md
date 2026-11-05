# Bichos en 3D (IA de imagen a 3D)

Pedido por el usuario: los bichos se hacen con Tripo a partir de los dibujos de `monstruos-prompts.md`; Claude los prepara para Roblox. El primero, el Golpeador (05-11-2026, `models/monster 3d model degarrador.glb`, que Sergio llamó "Desgarrador"; es el prompt 1, "The Knocker").

## Licencia

- Tripo con cuenta gratis: no está claro que se pueda usar en un juego que da dinero (su ayuda dice que lo de los usuarios gratis es de Tripo). Con plan de pago (Pro o más), sí. Mirarlo antes de publicar.

## Preparar y subir

1. `blender -b --factory-startup --python tools/blender/preparar_bicho.py -- <bicho.glb> <Nombre> <altura en studs> <carpeta> [--brazos 70]`
   (carpeta: `Documents\Roblox\modelos\bichos`). Quita la bola suelta que deja Tripo, une los triángulos (vienen sueltos: sin unirlos, simplificar deshace la malla), baja a 19.500 triángulos (Roblox: 20.000 por malla), baja los brazos de la postura en T y lo deja como reposo, escala a la altura, quita el `mixamorig:` de los huesos y pasa las texturas a 1024 px (más no admite Roblox).
2. Comparado en Blender: con 92.000 → 20.000 triángulos y 4096 → 1024 px de cerca la cabeza se ve casi igual.
3. `node tools/blender/subir_modelo.mjs <Nombre>.glb <clave>`: el **.glb** es el que vale (llega con malla con esqueleto, 52 huesos y las cuatro texturas en su `SurfaceAppearance`). El .fbx llegaba sin la textura de color ni rugosidad/metal.
4. El id, en `Config.Bichos3D`. Recién subido, las texturas tardan unos segundos en verse (sale blanco).
- `tools/blender/subir_imagen.mjs` sube .png sueltos como calcomanía (para texturas aparte; `GetObjects(id)[1].Texture` da la imagen).

## En el juego

- `juego/servidor/Bichos3D.copia(nombre, cf)`: carga el modelo una vez con `InsertService:LoadAsset` (el modelo es del grupo, como el juego) y da copias ancladas, sin chocar, con los pies en `cf` mirando a su `LookVector`. Sin modelo devuelve `nil` (el bicho sigue con sus bloques).
- Los huesos (`Hips`, `Spine`…`Head`, `LeftArm`, `LeftForeArm`, `LeftHand`, dedos, piernas) mueven la malla: animar por código con `Bone.Transform`.
- `Mapa.start`, solo en modo edición (VER MAPA): `MuestraGolpeador` en la hierba delante del porche (6, 0, -50) mirando a la casa, para verlo (pedido por el usuario).

## En la partida (Golpeador, 05-11-2026)

- Servidor: `Bichos3D.vestir(m, nombre, pies, cadera)` le pone la malla al bicho de bloques antes de colgarlo: copia soldada a la raíz (sin peso ni choque), con la cadera de la malla encima de la de los bloques, y los bloques invisibles (siguen para chocar, los rayos, `Caza.cabeza` y el gateo). Pone el atributo `Malla3D`. Sin modelo no toca nada.
- Cliente: `juego/cliente/Malla3D` (librería). La Vista sigue moviendo los Motor6D de los bloques como siempre y, al final de cada fotograma, `Malla3D.mover` copia en cada hueso el giro de su bloque desde el reposo (tabla `MALLA` de GolpeadorVista: la columna se dobla poco a poco, el cuello a medias con la cabeza, el pie casi plano). Así andar encorvado, golpear, gatear y el susto salen solos.
- Lo que no cuadra entre malla y bloques (medido en Studio), arreglado en Malla3D:
  - Brazos ×1,28 (codo y muñeca más lejos): sin estirar, el golpe no llegaba a la pared (1,5 studs menos); con 1,35 los dedos asomaban por dentro.
  - Piernas más largas: IK de dos huesos a la planta del pie de su bloque (sin pies hundidos y, andando, las rodillas se doblan).
  - Torso más corto: al gatear (`alinear` = lo echado que está) toda la malla se mueve para que su cuello caiga en el de los bloques; sin eso la cabeza se quedaba a 4 studs del suelo.
  - Sin mandíbula en el esqueleto: la boca no se abre (el modelo ya la tiene abierta).
- `Cara3D`: pieza invisible del cliente en la cara de la malla; la cámara del susto (MuerteVista) la mira en vez de la cabeza de bloques.
- El flash: `Caza.aturdir` pone el atributo `Aturdido` (hora del servidor); el Golpeador se echa atrás y se tapa la cara con los antebrazos cruzados (los codos solo existen en la malla: `rig.dobla`).
- Rendimiento: `mover` ~40 µs por bicho y fotograma en PC; la malla con `RenderFidelity` Automatic (menos detalle de lejos). Lejos de la cámara la Vista no lo anima (LEJOS).
- Probado en Studio: andar, golpe en la ventana (medido contra la pared), aturdido, gateo bajo la mesa del comedor visto desde el escondido, susto y de noche en primera persona. Falta: móvil de verdad.
