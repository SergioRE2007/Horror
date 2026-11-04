# Esconderse agachado: arreglos de la revisión del "contrato"

Pedido por el usuario (03-11-2026): "agacharte también debería servir para esconderte, por ejemplo debajo de mesas, y
que el monstruo pueda gatear si te huele… que sea útil agacharte es la finalidad". Revisión de cómo encajan las
piezas (PosturaVista, Postura, Caza, Bestia, las seis `<Bicho>Vista` y MuerteVista).

## Hecho (04-11-2026)

- [MEDIO] La escena de muerte enfocaba al bicho que no era. `MuerteVista` elegía con una cadena fija
  `GolpeadorVista.rugir(cabeza) or RaspadorVista.rugir(cabeza) or …`: ganaba la primera clase con alguno a menos de
  12 (14 la Bestia, 16 el Acechador). Con dos bichos en la casa (`AlaVez` {2,2} o {3,3}), un Raspador que te sacaba de
  debajo de la mesa con un Golpeador al lado: la cámara miraba al Golpeador y el Raspador, sin `agarra`, se levantaba
  en medio del susto. Ahora:
  - Cada `<Bicho>Vista.candidatos(punto)` devuelve, sin tocar nada, los suyos a menos de su alcance de antes: modelo,
    distancia de su cabeza a la cara del susto y, si gatea, dónde estaba el escondido (`gatea.punto` / `gateo.punto`,
    que se queda mientras vuelve a su pose: el `Gatea` del modelo puede llegar a nil antes que el remote Muerte).
  - `PosturaReglas.quienPilla` (pura, en `tests/regressions.luau`): primero el que gateaba a por quien estaba ahí (el
    escondido a menos de 10 de la cara del susto: la mesa del comedor mide 9,1 de punta a punta), si no el de la
    cabeza más cerca; entre dos que gatean, el más cerca.
  - `MuerteVista.quienPilla` junta los candidatos de las seis y llama solo a `rugir(cabeza, modelo)` de la que gana
    (`rugir` sin modelo sigue buscando el más cerca, como antes).
- Banco: `scratchpad/arreglos-contrato/pillar.luau` de la sesión (fuera del repo): Raspador gateando bajo la mesa del
  comedor con un Golpeador de pie al lado; gana el Raspador.

## Falta

- Probar en Studio (no hay Studio en la nube): dos bichos en la casa, uno gateando bajo la mesa del comedor y otro de
  pie al lado; la escena debe enfocar al que gatea y que este se quede en el suelo durante el susto.
- Lo más limpio sería que el servidor mandase en el remote Muerte el modelo que pilla (`Muerte.matar` es de
  `servidor/Muerte.luau`, fuera de esta zona); con eso `quienPilla` sobraría.
