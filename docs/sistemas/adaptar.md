# Ojos que se acostumbran a la oscuridad (y deslumbran)

Pedido por el usuario: "mejorar la inmersión del juego". Todo en el cliente y solo de adorno:
`src/juego/cliente/AdaptarVista.luau` (registrado en `init.client.luau` después de `TormentaVista`), con las cuentas en
`AdaptarCuentas.luau` y su banco en `tests/bancos/adaptar.luau`. Números en `Config.Adaptar`, a ojo y flojos.

## Qué pasa

Un `ColorCorrectionEffect` propio, `AdaptarOjos` en `Lighting`, que se suma a los de `Ambiente` y `MirarVista` sin
tocarlos (apagado cuando no hace nada).

- **A oscuras de golpe** (apagas la linterna, salta el generador, te metes en un armario): casi negro (`Hundido` = -0,25)
  y en 8-12 s los ojos se acostumbran: sube poco a poco hasta un pelo más claro de lo normal (+0,06), los colores se
  apagan (`Saturation` -0,35) y un tinte algo frío. Al principio da miedo; luego se ven siluetas.
- **Mucha luz de golpe estando hecho a la oscuridad** (enciendes la linterna, un relámpago, el flash de otro, sales al
  día): deslumbra (blanco cálido, contraste hundido) y se va en 0,6-1,2 s. Los saltos se miden en proporción: de una sala
  con luz a otra parecida no pasa nada, y salir de la casa de día apenas se nota.
- **La linterna de otro a la cara** (atributo `Linterna`; su haz va hacia donde mira su raíz con su `Mirada`, como en
  `BrazosVista`): a menos de 25 studs, dentro de ~12° del haz y sin pared en medio, deslumbra mientras te apunte (más
  cerca y más al centro, más).

## La luz que te llega

Una suma sin unidades (`Config.Adaptar.Luz`) que pasa a 0..1 con `1 - e^(-suma)`, medida cada 0,1 s:

- de día, fuera o dentro (un rayo hacia arriba: con techo o no; la noche, con las rampas de `AireVista.noche`);
- tu linterna, y más si el haz da contra algo a menos de 10 studs;
- las luces del mundo a su alcance y sin pared (las 6 que más dan, un rayo cada una; los cristales no tapan): su
  `Brightness` de verdad, que ya lleva el parpadeo de `Ambiente.factor`, el generador y el trueno. Las de luna
  (etiqueta `Luna`) con su peso; la chimenea, las bengalas y el flash de los demás también son luces. No cuentan las
  linternas (la tuya va aparte) ni lo que cuelga de tu personaje (tu flash ya lo pinta de blanco `EquipoVista`);
- en cada fotograma, el relámpago (`Ambiente.destello` × `Luz.Rayo` × `Ambiente.cieloVisto`, el mismo cielo visto que
  usa el destello de la pantalla de la tormenta, `tormenta.md`: fuera entero, dentro algo y en el sótano o escondido
  casi nada). Sin eso, los dos `ColorCorrection` se sumaban y en el sótano la pantalla parpadeaba casi como fuera.

Los ojos "hechos" siguen a esa luz: hacia la oscuridad despacio (`Baja`), hacia la luz deprisa (`Sube`).

## Cuándo no

- Escondido sigue adaptándose, con menos luz (`Luz.Escondido`).
- Muerto, en cinemáticas (cámara `Scriptable` sin vistazo ni escondite) o mirando por la mirilla (`Mirilla`): a cero. Al
  volver, los ojos ya están hechos a la luz de entonces (sin deslumbre).
- Con **Rendimiento** va igual (cuesta poco), pero la linterna de otro deslumbra la mitad (`Ajena.Rendimiento`).

## Probar en Studio

- Jugar de noche dentro de la casa con el generador apagado, la linterna encendida apuntando a una pared, y apagarla:
  casi negro y en ~10 s se aclara en grises. Encenderla: deslumbra un momento.
- Sin esperar: en el cliente, `Players.LocalPlayer:SetAttribute("AdaptarPrueba", 0)` pone los ojos hechos a la
  oscuridad (solo en Studio); con la linterna encendida, deslumbra al momento.
- `require(...AdaptarVista).estado()` devuelve a qué luz están hechos los ojos y la luz de ahora (0..1).
- Con dos jugadores (Test → Clientes): uno apunta con la linterna a la cara del otro a menos de 25 studs.
- Mirar que la mirilla, la muerte y las cinemáticas quedan sin efecto, y que en armario se oscurece.
- Sin probar en Studio (hecho sin él): los pesos de `Luz` son a ojo; si de noche con las bombillas encendidas se ve en
  grises, subir `Bombilla`; si molesta, bajar `Hundido`, `Deslumbre.Brillo` o `Ajena.Fuerza`.
