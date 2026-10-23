# Casa grande y amueblada (paso 11.5)

Pedido por el usuario: salas grandes y despejadas para moverse rápido, muebles del Creator Store contra las paredes, el centro libre, "como las capturas de `docs/referencias/casa/`, pero más vieja y abandonada".

## Plano (`Mapa.construirCasa`)

- La casa va de x -39 a 39 y de z -33 a 33 (antes 52 × 44; todo 1,5 veces más grande). Alturas iguales: suelo de abajo en y = 1, de arriba en 14, paredes de 12, desván en 27.
- Abajo: salón (x -39..-9, z -33..9) con chimenea en la pared oeste; cocina (x -39..-9, z 9..33, 30 × 24 como la prueba aprobada); pasillo (x -9..9) con la escalera pegada al salón (x -8.5..-3.5, z 6..26); dormitorio, baño y limpieza al este.
- Arriba: dormitorio (x -39..-9, z -33..0), cuarto de la escalera del desván (z 0..33), pasillo y la habitación del rico (todo el lado este).
- Puertas solo donde hacen falta (pedido por el usuario): la principal y las de llave (sótano, desván, rico, garaje). El resto son vanos abiertos (`vano(en, ancho)`, tipo "Vano" de `muro`) con marco oscuro y cortinas a los dos lados, sin chocar.
- Las 11 ventanas con cortina siguen siendo las mismas (8 abajo y 3 arriba). Ningún mueble delante de una ventana (pedido por el usuario).
- Lo de fuera se movió con la casa: cobertizo y sótano 11 hacia atrás, garaje 13 al este (x 47..65), caballete y cosas pesadas 11 hacia delante. El bosque no pone árboles en `junto(x, z)` (casa, garaje, cobertizo y sótano).
- El tejado (`TEJADO`) tiene la misma pendiente; el Trepador usa sus medidas (`CUMBRE`, `PARED`) y la chimenea en x = -37,5.

## Vestido de las salas

- `SALAS`: cada sala con su papel (`PAPEL`), su suelo y si lleva techo de yeso. Damasco mostaza en salón, pasillo y habitación del rico; damasco rojo en los dormitorios; rayas en la cocina; damasco claro en baño y limpieza. Las texturas son imágenes del Creator Store teñidas con `Texture.Color3`.
- `vestirParedes` recorre cada `Muro` y, cara a cara y sala a sala (una pared de fuera pasa por varias salas), pone una lámina con el papel, zócalo oscuro (en la cocina, azulejo blanco a media pared) y moldura blanca arriba. `vestirSuelos`: madera oscura, damas blancas y negras en la cocina, azulejo en el baño y techo de yeso.
- El papel, los suelos y lo abandonado se ponen después de `Separar` (en `Mapa.start`), con el grosor final de las paredes, y llevan el atributo `SinSeparar`: si Separar las tuviera en cuenta, engordaba las paredes al tocarlas de canto y tapaban el papel.
- `abandonar`: telarañas en las esquinas del techo, manchas de humedad con trozos de papel colgando, tablas y papeles por el suelo junto a las paredes, sangre en suelos y paredes (sin pasar de Moderate) y una silla volcada. Nada choca.
- La sangre son imágenes propias, blancas para teñirlas: `tools/texturas/sangre.ps1`, subidas con `upload_image` de Studio. Las de sangre del Creator Store daban "Asset is not approved for the requester".

## Muebles del Creator Store

- Están en `src/muebles/Muebles.rbxm` (Rojo lo pone en `ServerStorage.Muebles`). Cada uno: sin scripts ni nada que no sea pieza, malla o textura; escalado a la casa; con el frente hacia -Z, el pivote abajo en el centro y su tamaño en el atributo `Tam`; el id original en el atributo `Id`.
- `Mapa.tienda(nombre, cf)` lo clona sin chocar ni tapar rayos y pone una caja invisible un poco más pequeña para chocar (no tapa la vista de los bichos). `contraPared(nombre, x, y, z, frente)` lo apoya en la pared calculando el fondo con `Tam`.
- Los asientos (`Seat`) están desactivados: no se sienta uno sin querer al correr.
- Para añadir uno: cargarlo en Studio (modo Edit) con `game:GetObjects`, borrar todo lo que no sea visual, escalarlo, girarlo con el frente a -Z, ponerle `Tam` e `Id` y meterlo en `ServerStorage.Muebles`. Guardar la carpeta con `SerializationService:SerializeInstancesAsync` + `EncodingService:Base64Encode` y un `HttpService:PostAsync` a un receptor local que escriba el `.rbxm` (`HttpEnabled` solo ese momento). Comprobar con `rojo build` y Lune que el archivo trae todos.
- Descartar los modelos sacados de otros juegos (Hello Neighbor, DOORS…) y los resubidos con emojis en el nombre: suelen traer un `Script` escondido.
