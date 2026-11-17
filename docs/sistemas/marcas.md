# Marcas de la noche: arañazos y sangre salpicada (inmersión, noviembre de 2026)

Pedido por el usuario: "mejorar la inmersión del juego". Lo que pasa de noche deja marca en la casa: por la mañana
se ve por dónde atacó el bicho y dónde murió alguien. Solo en el cliente y solo de adorno
(`src/juego/cliente/MarcasVista.luau`); números en `Config.Marcas`, a ojo.

## Qué hace

- **Arañazos** (cada golpe del Golpeador: atributo `Golpes` de cada `Ventana` y `Puerta`): un zarpazo de 3-4 surcos
  paralelos (un poco en abanico, el del medio más largo, inclinados hasta `Inclina` desde la vertical). Cada surco es
  oscuro (el color de la madera por `Oscuro`: hundido, en sombra) con un borde claro de madera arrancada al lado
  (`Claro`) y, sin Rendimiento, 1-3 astillas claras levantadas en la punta de abajo.
  - Puerta: `EnHoja` (3 de cada 4) en la hoja, el resto en el marco. Con la vida por debajo de `Cede` (la hoja cede),
    cada golpe también deja uno por dentro. Echada abajo sin golpes (la Bestia), uno por cada lado.
  - Ventana: en los lados del marco, en la pared de al lado o en el alféizar y la pared de debajo. Nunca en el cristal
    (lo transparente no se araña).
  - Cada surco se pega a lo que hay de verdad: 6 rayos a lo largo; se queda con el trozo seguido más largo (misma
    pieza, misma profundidad, de cara). Si cruza el borde del marco, se corta ahí; si no queda nada, no se pone.
  - Lo de la hoja y el cristal va soldado (`WeldConstraint`) a ellos: gira con la hoja cuando CasaVista la abre.
- **Raspador** (su atributo `Raspado`, de 0 a 1, mientras `Raspando`): cada `Raspado.Cada` de avance, 2-3 rayas
  finas, largas y casi rectas hacia abajo en el cristal de la ventana que raspa (la de su `Fuera` más cerca), por
  fuera, blanquecinas y medio transparentes. Al romperse el cristal se van con él.
- **Se quedan hasta que se repara** (vida llena y cristal sano: el tablón, el tablón reforzado o la partida cargada).
  Decidido a ojo: el pedido decía "hasta el amanecer o hasta repararla" y "por la mañana se sabe por dónde atacó cada
  noche"; para que se vea por la mañana, los arañazos no se borran al amanecer, solo la sangre.
- **Sangre** (remote `Muerte`): `Rayos` (26; 13 con Rendimiento) desde el pecho del muerto (`Pecho` por encima de la
  raíz), alrededor y casi todos de frente o hacia abajo, la mitad hacia el lado contrario del bicho (la cabeza que
  manda el remote). Donde dan, hasta `Alcance` (unos 3 m): paredes, suelo, muebles, cristal.
  - Una mancha (elipse aplastada con `SpecialMesh` de esfera): más grande cuanto más cerca (`Mancha`), alargada en la
    dirección del golpe cuanto más de refilón llega (como mucho 3 veces). Las grandes llevan encima el hollín de
    `Mapa` (`HOLLIN.Hollin`, `Textura`) teñido, para que el borde no sea liso.
  - 1-3 gotas pequeñas (`Gota`) hacia donde iba, si debajo sigue la misma superficie.
  - En lo vertical, de cada mancha grande `Chorreon` escurre (como mucho `Chorreones` por muerte): una barra fina que
    baja por la pared en `ChorreaDura` s, deprisa y cada vez más despacio, con una gota en la punta; no se sale de la
    pared ni pasa del suelo. No en lo que se mueve (hoja, cristal).
  - Rodea el charco de `MuerteVista.charco`: las del suelo van por debajo de él.
  - Se seca de `Fresca` a `Seca` (casi negra) en `Secar` s. Se limpia al amanecer (`Fase` = `Dia`).
  - Gore sin pasar de Moderate: solo manchas, gotas y chorretones; nada de restos.
- Todo sale igual en todos los clientes: la semilla es la `Clave` de la ventana o puerta y el número de golpe, o el
  `UserId` del muerto y su sitio.
- Piezas planas sin colisión, `CanQuery`, `CanTouch` ni sombra, en `workspace.Marcas` (carpeta del cliente). Los rayos
  no ven a los personajes, a los bichos ni lo invisible (bloques tapados por un mueble de Blender); en algo suelto (con
  física) no se pone nada.
- Tope de marcas vivas (un zarpazo, una pasada del Raspador o una mancha con sus gotas): `Tope` 60, `TopeRendimiento`
  20; las más viejas se borran primero. Con Rendimiento, los chorretones salen ya escurridos, sin animar (y al
  activarlo, los que bajaban acaban de golpe).
- Un solo `Heartbeat`, atado solo mientras hay chorretones bajando o sangre fresca: los chorretones cada fotograma y el
  color cada `CadaColor`, solo a menos de `Cerca` de la cámara (lo lejano se pone al día al acabar).
- Funciones puras de `MarcasVista` para el banco (`semilla`, `surcos`, `rayosSangre`, `mancha`, `colorSangre`,
  `chorreo`, `tope`, `recortar`, `cede`, `danada`). Banco: `tests/bancos/marcas.luau` (también comprueba que dos
  clientes ven lo mismo).

## Probar en Studio

1. De noche, dejar que un Golpeador aporree la puerta principal: a cada golpe, un zarpazo más en la hoja o el marco,
   por fuera. Mirar que los surcos se vean hundidos (oscuros con el borde claro) y que no floten (ni en el borde del
   marco). Abrir la puerta: los arañazos giran con la hoja.
2. Que siga hasta que la hoja ceda (menos del 40 % de vida): arañazos también por dentro.
3. Una ventana: arañazos en el marco, la pared de al lado y el alféizar, nunca en el cristal.
4. El Raspador en una ventana: rayas finas en el cristal según raspa; al romperlo, se van; con el tablón, todo fuera.
5. Que muera alguien junto a una pared (dos jugadores en Probar): manchas en la pared, el suelo y los muebles cercanos
   alrededor del charco, gotas y algún chorretón que baja despacio. En un minuto y medio, casi negra. Al amanecer, la
   sangre fuera y los arañazos siguen.
6. Mirar el hollín teñido de las manchas grandes: si sale negro (la imagen no es blanca, `Decal.Color3` no la tiñe),
   quitar `Textura` o subir una versión blanca.
7. Con Rendimiento: no más de 20 marcas y chorretones sin animar.
