# Pueblo (11.5)

Pedido por el usuario: "hacerlo bien, pero rápido" (no las dos semanas de la casa): fachadas buenas en todos los edificios y solo unos pocos con interior. Hecho en una tarde con tres agentes en paralelo, cada uno con su archivo.

## Archivos

- `PuebloPlano.luau`: el plano común. Edificios (centro, medidas, plantas, lado de la puerta, si se entra, material y ventanas), campanario y cementerio, más las ayudas `dentro`, `ventanaCF` y `puertaCF`. **Para mover un edificio se cambia aquí**: los otros tres lo leen.
- `PuebloFachadas.luau`: el cascarón de cada edificio (un Model con su nombre): suelo `EnMapa`, paredes que chocan, techo, tejado, porche, ventanas, hiedra, manchas… y el campanario.
- `PuebloInteriores.luau`: lo de dentro de los cinco en los que se entra, más el vendedor y las llaves de la cripta y de la caseta.
- `PuebloCalle.luau`: calzada, aceras, farolas apagadas, postes con cables, vallas, buzones, el coche abandonado, el cementerio con sus dos llaves de fuera y el bosque espeso alrededor (`Mapa.arbol`).
- `Lugares.pueblo()` los llama por este orden (así salen los sitios de la llave `Cementerio`: cripta, caseta, tumba y banco) con un `ctx` (bloque, llave, objeto, vendedor, Plano, Mapa). `Mapa.conPadre(padre, fn)` hace que los muebles, manchas y adornos de `Mapa` cuelguen del pueblo y no de la casa.

## Qué hay

- Se entra en la tienda (el vendedor), la casa de la puerta rota (lata, botellas, chatarra y la pista 3), la iglesia (bancos, altar y la pista 4 fuera, junto a la puerta), la cripta (sarcófago con la llave) y la caseta del enterrador (banco con la llave, la pista 5 y chatarra). Las demás casas están tapiadas y sin interior.
- Cada casa es distinta: tablas de otro color, ladrillo o piedra, una o dos plantas, tejado a dos o a cuatro aguas, con porche o sin él.
- Vendedor (pedido por el usuario: "un personaje de Roblox"): R15 de serie con la ropa pintada, delantal y sombrero de copa, la raíz anclada y la animación de estar quieto. En modo Edit no se puede crear y sale el de bloques de antes.
- Vallas oscuras y charcos sin reflejo (pedido por el usuario: las vallas parecían nuevas y los charcos salían azules). El bosque alrededor es un anillo de pinos a entre 8 y 55 studs de los edificios, sin tapar la carretera.

## Ojo

- `Separar.caras` engorda las láminas que apoyan en el mismo plano: los suelos, forros y alfombras finas llevan el atributo `SinSeparar`.
- El saco de cemento de Poly Haven (`SacoCementoPH`) lleva escrito "CEMENT": no usarlo en el pueblo.
- Unas 5.100 piezas en todo el pueblo, más los 240 pinos del bosque de alrededor.
