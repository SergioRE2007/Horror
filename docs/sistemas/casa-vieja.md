# Casa vieja: qué tenía cada sala (antes de rehacerla, 11.6)

Pedido por el usuario: la casa se rehace entera (plano, dos plantas con volumen, fachada victoriana), pero cada sala conserva lo que tenía, colocado en otro sitio. El código de la casa vieja está en `Mapa.construirCasa` del commit `7476238` (main); medidas y vestido en `casa-grande.md`.

## Lo que la jugabilidad necesita (todo se busca por etiqueta o por las listas de `Mapa`, no por coordenadas)

- **Puertas:** principal (`PuertaPrincipal`, la ataca el Golpeador) y las de llave: sótano (`LlaveSotano`), desván (`LlaveDesvan`), habitación del rico (`LlaveRico`), garaje (`LlaveGaraje`). Las demás, vanos abiertos de 5-6 studs con marco y cortinas.
- **Ventanas:** 11 con cortina (8 abajo que ataca el Golpeador, 3 arriba) y 4 de arriba sin cortina. Ningún mueble delante.
- **Escondites (`Escondite`):** 2 camas (dormitorio de abajo y de arriba) y 3 armarios (dormitorio de abajo, dormitorio de arriba, limpieza).
- **Chimenea (`Chimenea`):** en el salón; el Trepador baja por el tiro. Atributos `Hogar`, `Tiro`, `Salida`.
- **Enchufe del móvil (`Enchufe`):** en el cuarto de la limpieza.
- **`Mapa.salas`:** un punto por sala por donde ronda el Golpeador. **`Mapa.lamparas`:** una lámpara por sala (las enciende el generador).
- **Aparición:** en el pasillo, junto a la entrada.
- **Trepador:** usa el tejado (`CUMBRE`, `PENDIENTE`, `PARED` en `Trepador.luau`, `TEJADO` en `Mapa`): tejado a dos aguas con la cumbre a lo largo de X y las paredes largas en z = ±33,5. Si el tejado nuevo cambia, cambiar también el Trepador.
- **Sótano:** fuera, detrás de la casa; la puerta del fondo del pasillo da a una escalera tapada (`HUECO`) que baja a una sala bajo el patio (banco de carpintero, estantería, chatarra).
- **Desván:** puerta con llave arriba y escalera de 13 peldaños hasta el techo; dentro, mesa de revelado, cubeta y cuerda con fotos.
- **Garaje** (al este, x 47..65) con coche, banco del taller, portón, rueda, bidón y chatarra; **cobertizo** detrás con el generador; **caballete** delante. Pueden quedarse fuera como están o pegarse a la casa nueva.

## Salas y lo que tenían

- **Salón** (30 × 42): chimenea, sofá mirando al fuego, mesita, alfombra, dos butacas a los lados del fuego, aparador con tele y lámpara de mesa, piano, librería, reloj de pie, un cuadro.
- **Cocina** (30 × 24, aprobada por el usuario): nevera, dos tramos de encimera con alacenas (hechos con piezas), fregadero en medio, cocina de hierro y cocina oxidada, mesa con cuatro sillas en el centro. Objetos: pila y lata en las encimeras, botella y carrete en la mesa.
- **Pasillo de entrada:** escalera a la planta de arriba (fea, pedido por el usuario rehacerla), puerta del sótano al fondo, un cuadro, aparición.
- **Dormitorio de abajo:** cama (escondite), armario (escondite), aparador con lámpara, mesilla con lámpara, un cuadro.
- **Baño:** bañera de patas, váter, lavabo.
- **Limpieza:** estantería, armario (escondite), enchufe del móvil, un hacha en el suelo.
- **Dormitorio de arriba:** cama (escondite), armario (escondite), aparador con lámpara, una pila.
- **Cuarto de la escalera del desván:** escalera al desván y su puerta con llave.
- **Habitación del rico** (con llave): escritorio con lámpara, caja fuerte, dos librerías, reloj, butaca, un cuadro.

## Muebles del Creator Store disponibles (`ServerStorage.Muebles`)

Sofa, Butaca, Aparador, Tele, LamparaMesa, Piano, Libreria, Reloj, Nevera, Fregadero, CocinaHierro, CocinaOxidada, MesaCocina, SillaCocina, Banera, Vater. De Blender (`mueble`): Mesita, Alfombra, Lavabo, Estanteria, Escritorio, Cuadro, ArmarioMarco, cama.
