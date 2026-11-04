# Lanzamiento en privado (13.2): lo que hay que rellenar

Lista preparada por Claude (03-11-2026) a partir de lo que en `Config` sigue a 0. Lo decide y lo crea Sergio (nombre, iconos, precios); Claude pasa los Id al código.

## Antes de publicar

1. Nombre del juego e icono (dibujo de ChatGPT con el texto que dé Claude) y miniaturas.
2. Publicar los dos lugares en la misma experiencia (Lotozno Studios): el lobby como lugar de inicio y el Juego como segundo lugar. Apuntar sus Id en `Config.Lugares` (`Lobby`, `Juego`).
3. En los ajustes de la experiencia: idioma de origen inglés; acceso a las API de Studio activado (para probar DataStores); permiso de `EditableMesh` si se usa; tamaño de servidor (el Juego, 4).
4. `Config.Test.Activo` solo actúa en Studio, pero **en un lugar publicado una partida de Studio sí puede guardar** (CLAUDE.md): probar siempre con el modo de pruebas puesto.

## Productos y pases (Creator Hub → Monetización), Id en `Config.Compras`

| Qué | Tipo | Robux (a ojo) |
|---|---|---|
| Revivir | Producto | 25 |
| 300 monedas / 900 / 2400 | Productos | 49 / 129 / 299 |
| Mochila grande | Pase | 199 |
| Más ranuras | Pase | 99 |
| Linterna mejor | Pase | 149 |
| Paquete de inicio | Pase | 99 |

- Con Id = 0 no se puede comprar fuera de Studio (en Studio se hace como si se pagara).
- Insignia del final de la Bestia: `Config.Insignias.Bestia`. Falta decidir si hay otra para la huida (habría que añadirla en `Recompensas.final`).

## Probar publicado (no se puede en Studio)

- Teletransporte lobby → juego → lobby, MemoryStore del viaje, servidor reservado por grupo.
- DataStores entre servidores: candado al saltar de servidor, dueño que se va con otros dentro.
- Compras de verdad (pase y producto), que no se den dos veces, revivir pagado de noche, y uno pagado justo al amanecer (reembolso de `Config.Compras.Reembolso`).
- Idioma real del jugador (Translator).
