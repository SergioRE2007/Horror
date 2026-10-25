# Plan del interior, sala por sala (11.8)

Pedido por el usuario: "mejor hacer un plan bien elaborado para cada habitación, no algo generalizado por piso, y así nos dedicamos todo a una sola cosa y lo haces bien". **Una sala por chat**, en el orden de abajo, sin pasar a la siguiente hasta que el usuario la apruebe.

## Cómo se hace cada sala (igual en todas)

1. **Propuesta.** Claude enseña una planta dibujada de la sala (vista de arriba, con puertas, ventanas y muebles) con 2 opciones de distribución. El usuario elige o corrige.
2. **Muebles.** Los de la lista de la sala, de Poly Haven, por la tubería de abajo. Lo que no haya en Poly Haven, en Blender por script con el mismo estilo (madera vieja, texturas de verdad), nunca bloques de Roblox.
3. **Paredes, suelo y techo propios de la sala**, no los genéricos del piso: papel, zócalo, moldura y suelo elegidos para esa sala.
4. **Detalle e historia.** Cosas pequeñas que cuentan quién vivía allí (libros, platos, fotos, ropa) y el abandono (polvo, sangre seca sin pasar de Moderate, cosas volcadas). Siempre contra las paredes: el centro libre para correr.
5. **Luz.** Lámparas de la sala con su color, más una luz débil de la luna por las ventanas.
6. **Revisión.** Capturas de día y de noche desde las esquinas ("cámaras de vigilancia") + agente Haiku. Después se le enseña al usuario en Studio con VistaMapa, y él mueve lo que no le guste: Claude lo pasa al código.
7. **Juego.** Comprobar que escondites, ventanas, puertas, objetos y llaves de la sala siguen funcionando. Commit.

Reglas que no cambian (pedido por el usuario): ninguna ventana tapada, el centro de las salas libre, vanos anchos, nada que estorbe al correr; Moderate como máximo.

## Tubería Poly Haven → Roblox

Hecha y probada con la butaca (11.8.0): pasos y lo aprendido en `docs/sistemas/polyhaven.md`.

## Orden y lista de salas

Medidas y sitio de cada sala: `docs/sistemas/casa-nueva.md`. Los nombres en `código` son modelos de Poly Haven.

### 1. Vestíbulo (abajo, x -12..12, z -33..9, doble altura)
- **Es** lo primero que se ve al entrar: tiene que impresionar. Recibidor de casa rica venida a menos.
- **Ahora:** escalera grande al fondo y casi nada más; se ve vacío.
- **Plan:** escalera con balaustrada torneada de verdad y alfombra de escalera roída; una lámpara de araña grande colgando del hueco (`Chandelier_01` o `_03`, sin cristales, una bombilla viva); consola con espejo a un lado (`ClassicConsole_01` + `ornate_mirror_01`); perchero con abrigo y paraguas; reloj de pie (`vintage_grandfather_clock_01`) parado; cuadros torcidos (`fancy_picture_frame_01/02`); suelo de madera con alfombra larga sucia; cartas sin abrir en el suelo junto a la puerta.
- **Juego:** paso libre de 7 a cada lado de la escalera; dónde aparece el jugador.
- **Elegido por el usuario (opción B, "entrada vacía y fría"):** la entrada casi vacía (perchero con abrigo y paraguas a la izquierda de la puerta, cartas tiradas, alfombra larga algo torcida hasta la escalera, araña algo más baja y retratos grandes en los trozos de pared de delante); el reloj de pie, el banco y la consola con espejo, al fondo bajo la galería (reloj y banco a la izquierda, lado del salón; consola a la derecha), que se descubren al rodear la escalera. Cuadros torcidos en las paredes junto a la escalera. Se aparece justo al entrar, mirando a la escalera.
- **Hecho (11.8.1):** papel damasco verde oscuro, zócalo alto de paneles con moldura, parquet en espiga y techo de yeso agrietado (MaterialVariants); escalera de madera oscura con alfombra roja roída, varillas de latón, barrotes torneados y poste (también en la barandilla de la galería); araña colgada de un rosetón con una sola bombilla, que enciende el generador; luz de luna azulada por la ventana alta; consola con jarrón y candeleros (uno tumbado), cuadro caído junto a la puerta, desconchones, una mano de sangre que resbala por la pared al pie de la escalera, salpicaduras en un peldaño y un arrastre hacia el pasillo del sótano. Además, pedido por el usuario a la vez: puertas de 5 × 10,5 (la principal de 7), que eran "enanas".

### 2. Salón (abajo, x 12..39, z -33..5, con la chimenea y la torre)
- **Es** la sala de estar de una familia de los años 50: chimenea como centro.
- **Plan:** chimenea de verdad (repisa de madera tallada, `mantel_clock_01` y `brass_candleholders` encima, cuadro encima de la repisa); sofá y dos butacas mirando al fuego (`Sofa_01`/`sofa_03`, `ArmChair_01`) con sábanas encima de alguna (muebles tapados = casa abandonada); mesa baja (`CoffeeTable_01`); tele de tubo (`Television_01`) en su mueble; piano vertical (de Blender si no hay); librería gastada (`wooden_bookshelf_worn`) con `book_encyclopedia_set_01`; la torre como rincón de lectura con la butaca y `vintage_oil_lamp`; alfombra grande.
- **Juego:** la chimenea (Trepador y tronco) sin tocar; delante del hogar, libre.
- **Elegido por el usuario (opción B, "dos rincones"):** rincón de la tele en la esquina del fondo (sofá tapado de espaldas a la sala mirando la tele); rincón de lectura junto al fuego (butaca, mesita con lámpara de aceite, librería); el piano dentro de la torre, contra la cara sin ventana (la butaca que había puesto él en la torre pasa al fuego); vitrina con fotos junto al ventanal.
- **Hecho (11.8.2):** papel de rayas de los 50 sobre papel viejo, rodapié oscuro, tablas viejas y techo de yeso (MaterialVariants), también dentro de la torre; chimenea de ladrillo de verdad con frente tallado, reloj parado, candeleros, foto y cuadro; tele de tubo en su mueble, sofá tapado con sábana, mesa baja, alfombra persa y lámpara de pie (la luz del rincón); butaca, mesita, lámpara de aceite y librería con enciclopedias (una tirada); piano con partituras y banqueta en la torre; vitrina con fotos (una boca abajo). Hollín y huellas con uñas que salen del hogar, mano de sangre en la pared del rincón de lectura, salpicadura junto a la butaca y desconchones. Luna por el ventanal y la torre. Arregladas las cortinas, que se veían como ruido negro: las de los vanos son ahora un modelo de terciopelo recogido con cordón, y las de las ventanas llevan el MaterialVariant `Terciopelo` (en toda la casa).

### 3. Comedor (abajo, x -39..-12, z -33..3, con mirador)
- **Es** la cena que nunca se recogió.
- **Plan:** mesa larga de madera (`dining_table` o `WoodenTable_02`) con 6 sillas (`dining_chair_02`), alguna separada o volcada; mantel sucio; platos, copas (`brass_goblets`), candelabros (`wooden_candlestick`) y comida podrida; aparador (`vintage_cabinet_01` o `painted_wooden_cabinet`) con vajilla; lámpara de araña pequeña encima de la mesa; el mirador con cortinas rotas y una planta muerta (`planter_pot_clay`).
- **Elegido por el usuario (opción A, "cena servida"):** mesa larga en medio, a lo largo, con todo puesto (mantel, platos con comida podrida, copas, candelabros) y la araña encima; sillas en su sitio menos una volcada; vitrina con vajilla en la pared de la cocina, aparador con lámpara en la del vestíbulo, reloj parado en la esquina de delante y plantas muertas en el mirador.
- **Hecho (11.8.3):** pintura roja oscura que se cae a trozos sobre zócalo alto de paneles oscuros, parquet en diagonal y techo de yeso (MaterialVariants), también en el mirador; mesa de 13 con mantel de cuadros, ocho sillas de cuero (una apartada y torcida, otra volcada hacia el vestíbulo), platos con manzanas y granadas podridas, frutero, copas de latón, dos candelabros y jarra; araña de cinco brazos colgada de un rosetón, con una bombilla viva; vitrina con el juego de té, aparador (arcón tallado) con lámpara de aceite, candelabro y jarra; reloj de pie parado en la esquina de delante; macetas con plantas secas a los lados de la ventana del mirador. Copa derramada en el mantel, arrastre de sangre hacia el vestíbulo y una mano en el marco, desconchones; luna por la ventana de delante y la del mirador.

### 4. Cocina (abajo, x -39..-12, z 3..33)
- **Es** una cocina de los 50 abandonada a medio cocinar.
- **Plan:** encimeras y alacenas de madera con puertas de verdad (Blender, con las texturas de Poly Haven), cocina de hierro y nevera vieja (las de ahora tienen buena textura: se quedan si encajan), fregadero con platos; ollas (`pot_enamel_01`, `brass_pan_01`), tarros, latas (`russian_food_cans_01`), tabla de cortar y cuchillo; mesa pequeña contra la pared con 2 sillas (`painted_wooden_table`, `painted_wooden_chair_01`); el centro libre (el usuario quitó la mesa de en medio); suelo de damas sucio.

### 5. Pasillo, baño y trastero (abajo, detrás del vestíbulo)
- **Pasillo:** largo y estrecho de sensación aunque sea ancho: cuadros de familia en fila (`hanging_picture_frame_01/02/03`), una mesita con teléfono viejo (`vintage_telephone_wall_clock`), la puerta del sótano con cadena y marcas de arañazos.
- **Baño:** bañera con patas (la de ahora, si convence), lavabo con espejo roto, váter, toallas sucias, botiquín abierto (`medical_box`), azulejos con manchas.
- **Trastero:** estanterías llenas (`painted_wooden_shelves`, `steel_frame_shelves_01`), cajas (`cardboard_box_01`, `wooden_crate_01`), maleta vieja (`vintage_suitcase`), escoba (`wooden_broom`), cubo.

### 6. Dormitorio de abajo (x 22..39, z 5..33)
- **Es** el cuarto de invitados o de la abuela.
- **Plan:** cama de hierro o madera vieja (`old_bed_frame` o `GothicBed_01`) con colcha (el escondite debajo, igual), mesillas (`ClassicNightstand_01`), cómoda (`GothicCommode_01`) con espejo, armario (escondite), silla con ropa, mecedora en el rincón (`Rockingchair_01`).

### 7. Galería (arriba, x -12..12, z 0..33)
- **Es** el distribuidor de arriba que mira al vestíbulo.
- **Plan:** balaustrada torneada de verdad sobre el hueco (la de ahora es una pared baja); banco o arcón contra la pared; cuadros grandes; maceta con planta seca; una silla de ruedas vieja quieta (`wheelchair_01`): susto sin moverse.

### 8. Dormitorio grande (arriba, x 12..39, z -33..9, con la torre y el balcón)
- **Es** el cuarto de los dueños.
- **Plan:** cama grande con dosel (`GothicBed_01`), mesillas con lámparas, tocador con espejo (`ornate_mirror_01`), armario grande (escondite), baúl a los pies de la cama (`vintage_wooden_drawer_01` o de Blender), la torre como rincón con butaca y ventana; ropa tirada; la salida al balcón libre.

### 9. Habitación del rico (arriba, x -39..-12, z -33..9; con llave)
- **Es** la sala clave de la historia (12.1): el despacho del que te mandó aquí.
- **Plan:** escritorio grande con lámpara (`desk_lamp_arm_01` o `vintage_oil_lamp`), sillón de despacho, librerías llenas, caja fuerte de verdad, globo terráqueo, mapas y fotos en la pared con hilos, cabezas de animales (`bull_head`, `horse_head`), reloj, alfombra buena; el sitio del diario y de cómo matar a la Bestia (`docs/historia.md`).

### 10. Cuarto de los niños (arriba, x -39..-12, z 9..33)
- **Es** el más inquietante: juguetes y cuna.
- **Plan:** cuna (Blender, de barrotes de verdad), cama pequeña, baúl de juguetes, caballito de madera, muñecos y peluches (`rubber_duck_toy`, de Blender lo demás), dibujos infantiles en la pared (inquietantes), móvil colgando de la cuna, papel infantil desteñido.

### 11. Escalera del desván y desván (arriba, x 12..39, z 9..33, y el desván bajo el tejado)
- **Escalera:** peldaños de madera con barandilla, baúles (los de ahora, cambiados por `vintage_suitcase` y arcones).
- **Desván:** vigas a la vista bajo el tejado, cuarto oscuro de revelado (mesa, cubetas, fotos tendidas: ya está la idea), muebles tapados con sábanas, maniquí, cajas, polvo y telarañas grandes.

### 12. Lavadero, garaje y cobertizo
- **Lavadero:** lavadora antigua o pila de lavar, cuerdas con ropa, cestos (`wicker_basket_01`), estantería con botes (`bleach_bottle`, `all_purpose_cleaner`), el enchufe del móvil igual.
- **Garaje:** coche (el de ahora, mejorado en Blender), banco de trabajo con herramientas (`metal_tool_chest`, `bench_vice_01`, `handsaw_wood`, `crowbar_01`), estanterías de metal, bidones (`metal_jerrycan`), neumáticos (`old_tyre`).
- **Cobertizo:** generador (`portable_generator` si encaja con el de ahora), herramientas de jardín (`rusted_spade_01`, `watering_can_metal_01`), sacos (`compost_bags`), escalera de mano (`wooden_ladder`).

### 13. Sótano
- **Es** lo peor de la casa: el final de la historia.
- **Plan:** banco de carpintero de verdad, estanterías con tarros, caldera vieja, cadenas, una silla sola en medio con cuerdas, manchas en el suelo; muy poca luz (una bombilla colgando, `pull_chain_light_socket`).

## Cosas a vigilar

- **Rendimiento:** contar los triángulos de cada sala; texturas compartidas cuando se pueda; en móvil, que no baje de 30 fps.
- **Juego:** cada escondite (armarios y camas), ventana atacable, puerta con llave y objeto suelto de `Mapa.objetos` tiene que seguir en su sitio o moverse a propósito y apuntarse.
- **Lo guardado:** las ventanas y puertas se guardan por su sitio (`clave`): si se mueven, las partidas viejas las pierden (ya pasó con la casa nueva; avisar).
