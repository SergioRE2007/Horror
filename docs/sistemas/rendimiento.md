# Rendimiento y móvil (14.4)

## Cifras del mapa (noviembre de 2026, medido en una partida)

| Zona | Piezas | De ellas MeshPart |
|---|---|---|
| Casa (con garaje, cobertizo, coche, sótano, desván) | 4.358 | 1.025 |
| Pueblo (fachadas, interiores, calle, cementerio, pinos de alrededor) | ~5.000 | ~750 |
| Bosque (suelo, 231 pinos con su tronco, 45 talables, sotobosque) | ~1.700 | ~1.290 |
| Granja, aserradero, torre | ~130 | 0 |
| **Total** | **12.293** | **3.064** (475 mallas distintas) |

- Pinos: 515 en total (231 del bosque y 284 alrededor del pueblo), 3 piezas cada uno (tronco invisible que choca, corteza y ramas).
- Luces: 55 (25 con sombras, casi todas en la casa y apagadas hasta el generador). Partículas en el mapa: 0.
- Texturas: 940 SurfaceAppearance (804 en la casa) con 245 texturas de color distintas, y 50 MaterialVariant. Es lo que más
  memoria gasta en un móvil.
- Ya estaba bien antes de 14.4: piezas pequeñas sin sombra (solo quedan 324 con sombra, casi todas objetos de la casa que se
  ven de cerca), adornos sin CanQuery ni CanTouch, mallas de Blender con colisión en caja. `GlobalShadows` lo enciende el
  cliente (Ambiente).

## Decisiones

- `Mapa.aligerar`: CanTouch a false en todo el mapa (2.010 piezas lo tenían). Nadie usa `Touched` en el juego. Si alguna vez se
  usa, ponerlo a true solo en esa pieza después de `Mapa.start`.
- No se juntan piezas ni se quitan: lo que queda es detalle que se ve de cerca (hierba, hiedra, barrotes) o tronco invisible
  que choca (no se dibuja).
- `CollisionFidelity` y `RenderFidelity` no se pueden cambiar con el juego en marcha (Roblox lo ignora sin avisar). Las 1.146
  mallas que no chocan y aún tienen colisión `Default` vienen de los moldes de `ServerStorage.Muebles` (`src/muebles`): ponerles
  `Box` allí, en Studio, cuando se toquen.
- Mapa por partes (StreamingEnabled): preparado en `Mapa.porPartes`, que solo actúa con la propiedad del Workspace encendida.
  Casa y árboles talables, `Persistent`; el mapa del móvil, con copias invisibles en `Mapa.Plano`; los edificios del pueblo, con
  `LevelOfDetail = StreamingMesh`. Ajustes propuestos para el lugar: `StreamingIntegrityMode = MinimumRadiusPause`,
  `StreamingMinRadius = 128`, `StreamingTargetRadius = 384`, `ModelStreamingBehavior` y `StreamOutBehavior` por defecto.
  Sin encender todavía. Riesgos que hay que arreglar antes (no son de los generadores del mapa):
  - Los bichos de `workspace.Bichos` (Caza) no son `Atomic`: las vistas del cliente los preparan al llegar (`ChildAdded`) y
    con el mapa por partes llegarían sin piezas. Ponerlos `Atomic` y que cada vista limpie lo suyo cuando el modelo se va.
  - Al morir y mirar a otro jugador (MuerteVista) la cámara se va lejos, pero el mapa se carga alrededor del muerto: el
    servidor debe poner `jugador.ReplicationFocus` en el jugador al que mira (y quitarlo al revivir).
  - Lo que el cliente mira una sola vez al empezar y está fuera de la casa: las latas (`Mapa.Latas`, se leen sus atributos:
    bien) y las pistas (sin la pieza no se cierra la nota: bien).
  - Los saltos del servidor (`PivotTo` en Muerte): con `MinimumRadiusPause` el jugador espera a que cargue el suelo.
