# Lobby: la gasolinera (14.7)

Pedido por el usuario (03-11-2026): "el lobby es un poco feo". Según `docs/diseño.md`: gasolinera vieja de noche
junto a la carretera del bosque, con lluvia y un cartel que parpadea; te subes a un coche con tus amigos, el dueño
elige partida y arrancáis; la tienda está dentro. Hecho en una sesión en la nube **sin Studio**: el mapa del servidor
se ha construido con un arnés de Lune (sin errores, `Separar` deja 0 caras), pero nada se ha visto.

Todo es adorno: la jugabilidad del lobby (coches, tienda, viaje) no cambia. Números visuales a ojo, como constantes
al principio de cada módulo; los que puede querer tocar Sergio, en `Config.Lobby`.

## Módulos

| Dónde | Módulo | Qué hace |
|---|---|---|
| servidor | `Gasolinera` | Luz de noche (sin luna ni estrellas), suelo, cunetas, carretera que se pierde en la niebla, orilla (quitamiedos, postes con cables, señal, hitos, una cruz), 3 farolas (una falla, otra muerta), 417 pinos con sotobosque, los puntos `Sombra` y la aparición. Llama a los otros tres con `pcall` y al final a `Separar.caras` |
| servidor | `GasolineraPiezas` | Ayudas para construir: `bloque`, `cilindro`, `cuna`, `luz`, `textura`, `mancha`, `letrero`, `etiqueta`, `punto` y la paleta |
| servidor | `GasolineraTienda` | La tienda por fuera y por dentro (Model `Tienda`) y el `Mostrador` |
| servidor | `GasolineraFuera` | La explanada, la marquesina, los surtidores, el cartel GAS, cabina, contenedor, neumáticos, charcos y basura (Model `Fuera`) |
| servidor | `GasolineraCoches` | Los 4 coches viejos en `workspace.Coches` |
| cliente | `Bucle` | El único bucle por fotograma: `Bucle.cada(nombre, fn)` / `Bucle.quitar(nombre)` |
| cliente | `Sonido` | Como el del juego, pero solo con lo que se usa; los que faltan (`Config.SonidosLobby`, Id 0) devuelven nil |
| cliente | `Clima` | Niebla, lluvia, salpicaduras, goteo, relámpagos y sonidos de fondo |
| cliente | `GasolineraVista` | La vida: luces que fallan, puerta automática, faros y limpias, polillas y la sombra entre los árboles |
| cliente | `SalidaVista` | La cinemática del coche que se va |

## Plano

- Carretera a lo largo de Z en x = 0 (14 de ancho, cara de arriba en y = 0,2), 400 studs a cada lado; hacia -Z, el bosque.
- Explanada de x 7 a 73 y de z -40 a 40 (losas con la cara de arriba en 0,2). Coches en x = 14, z = -24, -8, 8 y 24,
  mirando a -Z. Marquesina en (32, 13, 0), 20 × 26. Aparición en (44, 0,3, 0). Tienda de x 52 a 70 y de z -14 a 14,
  con la puerta en la pared oeste. Cartel alto en (23,5, 0, -45), girado 45° (fuera del paso de los coches).
- Alturas de lo que va encima del asfalto y las losas, separadas a mano para que no parpadeen (lo girado no lo arregla
  `Separar`). Las piezas de los coches y las capas a altura exacta llevan el atributo `SinSeparar`.

## Contrato servidor → cliente

Etiquetas (CollectionService) y atributos dentro de `workspace.Mapa`:

- `LuzFalla` (atributos `Fallo` 0..1 y `Zumba`): la pieza de una luz con su Light dentro. `GasolineraVista` la hace
  fallar (luz, color de la pieza y textos de su SurfaceGui). Con Fallo ≥ 0,7 está casi siempre apagada.
- `Polillas`, `Charco`, `Goteo` (Attachment en el borde de un tejado), `Chapa` (el techo de la marquesina), `Dentro`
  (caja invisible del interior de la tienda), `Nevera`, `Radio`.
- `PuertaAuto`: Model con `Hoja1`/`Hoja2` (atributo `Desliza`) y `Centro`. Las hojas no chocan.
- `Sombra`: Attachment entre los árboles con `Hacia` y `Largo`.
- Coches (`workspace.Coches`, etiqueta `Coche`): `Carroceria` (PrimaryPart), `Asiento1..4`, `Faro` (SpotLight `Haz` y
  PointLight `Brillo`), `Piloto`, `Limpia1`/`Limpia2` (`Eje`, `Normal` hacia fuera del parabrisas), Attachment
  `Escape`, `Rueda` y `Llanta`. Los asientos van invisibles dentro del cuerpo que choca: al saltar, sales por arriba.
- `Mostrador` (hijo directo de Mapa) con el prompt `Tienda` (lo busca TiendaUi).
- Atributo local `SaliendoLocal` en el coche real mientras su copia sale (lo pone SalidaVista; GasolineraVista no lo toca).

## Luz y clima (Clima)

- Atmosphere densa (0,52, azul gris oscuro) y un ColorCorrection algo desaturado y frío. La luz del servidor es casi
  negra: lo que se ve sale de los fluorescentes, la tienda, el cartel, la nevera, las farolas y los faros, todo flojo.
  Sombras solo en 4-5 luces (dos fluorescentes, el tubo bueno de la tienda, la farola buena).
- Lluvia: el cielo alrededor de la cámara en trozos de 8 × 8 studs (8 × 8 trozos; 6 × 6 con Rendimiento), cada uno con
  su emisor; cada trozo se mide una vez con rayos hacia abajo y solo llueve donde no hay tejado (marquesina, tienda,
  cabina, el coche en el que vas). `Config.Lobby.Lluvia.Gotas` por segundo en total (un tercio con Rendimiento).
- Charcos cercanos con gotitas y ondas; gotas que caen de los `Goteo`; relámpagos de 2-3 destellos flojos cada
  `Config.Lobby.Relampago.Cada` s y el trueno a los `Relampago.Trueno` s.

## Vida (GasolineraVista, todo en una tarea de Bucle y solo cerca de la cámara)

- Luces con tres maneras de fallar (tirones, apagones que vuelven, arranque de fluorescente viejo) y su zumbido.
- La puerta corredera se abre con alguien a menos de `Config.Lobby.Puerta` studs (campanilla: falta el sonido).
- Coches con gente: faros y pilotos encendidos, limpias que barren cada pocos segundos (llueve) y humo flojo.
- Polillas en las luces que las tienen (ninguna con Rendimiento).
- Cada `Config.Lobby.Sombra.Cada` s, si estás fuera y no hay cinemática, una figura alta y flaca cruza de reojo
  entre los árboles (a `Sombra.Lejos` studs) con un crujido de rama; si la miras de frente se para y se va deprisa.

## Salida (SalidaVista)

- Cuando el coche tiene `Salida` (la cuenta atrás de `Config.Coches.Salida` = 7 s): el coche real se esconde en ese
  cliente y una copia enciende faros y limpias, tiembla al arrancar, sale de la plaza (con marcha atrás si no cabe)
  hasta el carril x = 3,5 y acelera hasta 40 studs/s hacia la niebla. Todo según la hora del servidor.
- Quien va dentro: interfaz y CoreGui escondidas, dos planos (delante a un lado; detrás siguiéndolo) y fundido a negro
  propio antes de la hora. Se devuelve todo si el servidor para el coche, si te bajas, a los 12 s o si algo falla.

## Sonidos

- Ya existen y se usan: Viento, Zumbido, Parpadeo, Nevera, NeveraClac, Buho, Lobo, Rama, Ramita.
- **Faltan** (`Config.SonidosLobby`, para ElevenLabs): Lluvia (bucle), LluviaChapa (bucle en la chapa de la
  marquesina), Trueno (dos o tres), Radio (radio vieja con interferencias, bucle), Campanilla (puerta de la tienda),
  Arranque (el coche arrancando y saliendo).

## Rendimiento

- Unas 3.250 piezas sin contar los pinos (base 700, coches 465, tienda 1.070, explanada 1.120) y 417 pinos de 2 mallas.
- Lo pequeño sin sombra y sin chocar; en el cliente, lluvia con 64 emisores como mucho (36 con Rendimiento).

## Probar en Studio

- Lobby en su ventana (ver `datos.md`). Mirar de noche: niebla, lluvia (que no llueva bajo la marquesina ni en la
  tienda, sí justo fuera), charcos, goteo, relámpagos; luces que fallan y el cartel GAS; la puerta al acercarte.
- Subirse a un coche: faros y limpias; EMPEZAR: la cinemática entera, el aviso de Studio y que vuelve la imagen con
  el panel y los controles. Probar el coche 1 y uno del medio. Con dos jugadores: el que mira desde fuera.
- Bajarse del coche saltando (los asientos van dentro del cuerpo que choca).
- Esperar fuera 1-3 minutos mirando al bosque: la sombra. Probar Rendimiento en Ajustes.
- Que no salga ningún `warn` de `[Clima]`, `[Bucle]`, `[Gasolinera]` o `[GasolineraVista]`.
