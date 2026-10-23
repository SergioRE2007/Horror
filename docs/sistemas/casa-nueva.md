# Casa nueva (paso 11.6)

Plano aprobado por el usuario: `docs/referencias/casa-fuera/plano-nuevo.png`. Todo en `Mapa.construirCasa` (más `construirTorre`, `cuna`, `construirGaraje`, `construirCobertizo`). Lo que tenía cada sala vieja: `casa-vieja.md`.

## Orientación (ojo: costó un fallo)

Mirando la casa desde el camino (delante = -z), **+x es la izquierda**. En una vista desde arriba con el "arriba" de la imagen en +z, +x sale a la izquierda, como en el plano. La primera versión salió en espejo por esto.

## Medidas

- Casa x -39..39, z -33..33 (igual que antes: `Config.Casa.MedioX/MedioZ`, Trepador). Lo que sobresale y cuenta como casa, en `Config.Casa.Anexos` (lo usa `Caza.dentroDeCasa`).
- Abajo (y = 1): vestíbulo x -12..12, z -33..9 (doble altura; escalera de 9 de ancho de z -18 a la galería en z 0, los seis peldaños de abajo macizos y el resto solo huella); pasillo z 9..33 con el sótano al fondo (x 0). Izquierda (+x): salón x 12..39, z -33..5 (chimenea en x 37,5 z -1, como antes; torre octogonal en la esquina x 39 z -33), dormitorio x 22..39 z 5..33, trastero y baño x 12..22. Derecha (-x): comedor x -39..-12, z -33..3 con mirador x -43..-39; cocina z 3..33; lavadero x -26..-12, z 33..45 (enchufe); garaje x -59..-39, z 3..33 (portón en z 3); cobertizo x -54..-44, z 37..45,5.
- Arriba (y = 14): galería x -12..12, z 0..33 con barandilla al hueco; dormitorio grande x 12..39, z -33..9 (torre, puerta al balcón); escalera del desván x 12..39, z 9..33; habitación del rico x -39..-12, z -33..9; niños x -39..-12, z 9..33. Balcón encima del porche (x -30..27, z -41..-33).
- Movimiento libre (pedido por el usuario): vanos de 10-16, pasos de 7 o más alrededor de la escalera.

## Cosas que dependen de la casa

- Trepador: trepa detrás por x 5..34 y delante por x -37..-33 (la torre y el porche estorban); la chimenea en x 37,5.
- `HuidaVista`: el coche sale del garaje por z = 3. `Lugares`: zona sin árboles del garaje en (-49, 18). `junto()` del bosque: x -62..72 (comprobado que no mueve ningún árbol talable).
- Las ventanas y puertas se guardan por su sitio (`clave`): las de antes no casan con las nuevas, así que una partida vieja empieza con la casa como nueva.

## Revisión

Pedido por el usuario: "cámaras de vigilancia", una captura por sala desde una esquina alta que enseñe la sala y su salida (`RunService:BindToRenderStep` con prioridad Camera + 10 y la CFrame en un atributo de `workspace`), y un agente Haiku revisa los `.jpg`.
