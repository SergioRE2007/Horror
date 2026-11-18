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
  - Los bichos ya son `Atomic` (`Cuerpo.nuevo`, revisado el 03-11-2026): llegan enteros. Las vistas de los bichos ya
    aguantan un `nil` en sus remotes (sin cargar, el modelo o la ventana llegan como nil). Falta mirar que cada vista
    limpie lo suyo cuando el modelo se va lejos (StreamOut) y vuelva a prepararlo al volver.
  - Hecho (03-11-2026): al morir y mirar a otro (MuerteVista) el cliente avisa con el remote `Mirar` y el servidor
    (Muerte) pone `jugador.ReplicationFocus` en el que mira; se quita al revivir. Sin probar con el mapa por partes.
    Con `Config.Limites.Mirar` entre una y otra, la que llega antes no se tira: el servidor guarda la última y la aplica
    al acabar el intervalo (una sola espera por jugador). Probar en Studio: de muerto, cambiar de jugador muy rápido y
    mirar que `ReplicationFocus` acaba en el último (16-final).
  - Lo que el cliente mira una sola vez al empezar y está fuera de la casa: las latas (`Mapa.Latas`, se leen sus atributos:
    bien) y las pistas (sin la pieza no se cierra la nota: bien).
  - Los saltos del servidor (`PivotTo` en Muerte): con `MinimumRadiusPause` el jugador espera a que cargue el suelo.

## Luces, fuego e iluminación más ligeros (16.11)

- Linterna (`EquipoVista`): la sombra solo la lleva la propia y nunca con Rendimiento; las de los compañeros, sin sombra.
- Bengalas (`BengalasVista`): con Rendimiento, luz sin sombra y la mitad de humo y chispas (ritmo y ráfagas).
- Chimenea (`ChimeneaVista`): con Rendimiento, luz sin sombra, una sola llama, la mitad de chispas, sin temblor de luz y sin
  luz de brasas. Su Heartbeat sale pronto si la cámara está a más de 60 studs y no hay nada cambiando (encendiéndose,
  apagándose, brasas, humo, llamarada o viento); el tamaño y el calor de las llamas solo se escriben si cambia la llamarada.
- Ambiente: la iluminación se pinta unas 10 veces por segundo (30 en el atardecer y el amanecer). Las lámparas se repintan
  cada fotograma mientras haya algún parpadeo de bombilla (`Ambiente.factor`), que a 10 Hz se vería a tirones. El aviso
  del atardecer se sigue mirando cada fotograma.
- Sin Rendimiento no debe notarse cambio a la vista. Números (60 studs, 10 y 30 Hz) a ojo.
- Probar en Studio: con Rendimiento apagado, linterna, bengala y chimenea como siempre y bombillas parpadeando suaves; con
  Rendimiento encendido, sin sombras en esas luces y chimenea con una llama; el atardecer y el amanecer fluidos.
