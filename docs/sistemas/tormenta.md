# Tormenta seca: relámpagos que iluminan la casa y recortan a los bichos

Pedido por el usuario: "mejorar la inmersión del juego". Todo en el cliente y solo de adorno:
`src/juego/cliente/TormentaVista.luau` (registrado en `init.client.luau` después de `AireVista`). Números en
`Config.Tormenta`, a ojo.

## Qué hay

- **Qué noches**: desde la noche `Desde` (2), una de cada dos (`Probabilidad`). Sin lluvia: tormenta seca.
- **Relámpagos**: el primero entre 10 y 30 s después de que empiece la noche, luego uno cada 25-70 s, hasta el 92 % de
  la noche (amanece). Cada uno, 2-3 destellos de 0,05-0,12 s, el primero el más fuerte.
- **La luz**: `Ambiente.destello` (de 0 a 1) se suma cada fotograma a lo que pone `Ambiente`: brillo, luz de fuera
  (`OutdoorAmbient`), niebla (el cielo se pone blanco azulado) y un pico de brillo y contraste del `ColorCorrection`.
  Sin destello, todo queda como lo pone `Ambiente`, así que nunca se queda a medias.
- **La pantalla, según el cielo que se ve**: el pico del `ColorCorrection` (brillo y contraste de la pantalla entera) se
  multiplica por `Ambiente.cieloVisto`, que `TormentaVista.cieloVisto` calcula en cada relámpago: fuera, 1; dentro de casa,
  `1 - distancia / Fogonazo.Cerca` a la luna sin persiana más cercana, con suelo `Pantalla.Dentro` (0,15); en una sala sin
  ventanas (`Pantalla.SinCielo`: el sótano) o escondido (atributo `Escondido`), `Pantalla.Escondido` (0,05). Al acabar
  vuelve a 1. La luz de fuera, la niebla y las lunas, enteras igual: la ventana se enciende, pero en el sótano o en el
  armario la pantalla ya no parpadea entera. El deslumbre de los ojos (`AdaptarVista`, `adaptar.md`) usa el mismo
  `cieloVisto`: si no, los dos `ColorCorrection` se suman y el sótano vuelve a parpadear casi como fuera.
- **Las lunas**: las luces de luna (etiqueta `Luna`, `Mapa.luzLuna`) a menos de `Fogonazo.Cerca` suben su brillo con el
  destello (`Ambiente.lunas`). Con las cortinas de esa ventana echadas (`Persiana`), no.
- **Fogonazo con sombras** (sin Rendimiento): para las 3 lunas más cercanas, un `SpotLight` con sombras en la misma
  línea que la luna pero 5 studs por fuera del cristal (carpeta `TormentaLocal` del workspace, fuera de `Mapa`). Lo que
  haya entre esa luz y la sala hace sombra en el suelo: los marcos, las cortinas y un bicho pegado a la ventana, que se ve
  en negro contra el cielo blanco (ninguna luz le da por delante). Nadie lo programa: sale solo de la luz.
- **El rayo en el cielo**: si el relámpago cae cerca (`Rayo.Desde`, cercanía 0,3 o más), se ve un rayo quebrado del
  mismo lado del que llegará el trueno (`angulo`), a 240 studs (cercanía 0,3) a 90 (encima). Tronco de 9-14 tramos
  desde 200 studs de alto hasta lo primero que haya debajo (suelo, árbol, tejado) y 1-3 ramas que se afinan y acaban en
  el aire. Beams blanco azulados (`LightEmission` 1, `LightInfluence` 0, sin Neon ni piezas) entre Attachments de una
  pieza invisible `Rayo` en `TormentaLocal`, con un resplandor ancho y flojo alrededor del tronco. Se ve con cada
  destello y se apaga en 0,12 s entre uno y otro (parpadea); al acabar el relámpago se esconde y se reutiliza. La forma
  sale de `TormentaVista.forma` con una semilla de la hora del relámpago: todos ven el mismo rayo.
- **El trueno**: 1 a 5 s después (antes cuanto más cerca). Mientras no haya un `Trueno` propio (`sonidos-pendientes.md`,
  fila 38), `Retumbo` a tono 0,38-0,5 (muy grave y largo). Lejano: sin posición y, con la cámara en casa o escondido, sordo
  (ecualizador sin agudos). Cercano (`Cerca3D`): en 3D desde fuera, entero, y las paredes lo tapan solas (`OidoVista`).
- **Con el trueno**: los cristales de las ventanas a menos de `Ventanas` traquetean (`CasaVista.elementos[...].vibrar`)
  y suenan los dos más cercanos (`CristalVibra`); las bombillas (`PointLight`) tiemblan (`Ambiente.temblor`, cada una a
  su aire, sin tocar `Ambiente.factor` para no pisar los parpadeos de `DetallesVista` y `Efectos`); si fue encima, un
  temblor de cámara muy flojo (`CasaVista.temblar`).
- **Todos a la vez**: el horario sale de una semilla con `Noche` y `FaseInicio` (atributos del Ciclo) y la hora del
  servidor (`GetServerTimeNow`). Sin servidor nuevo. Quien entra tarde se salta los ya pasados.

## Reglas

- Nada en cinemáticas ni en la muerte (cámara `Scriptable` sin el atributo `Vistazo`); por la mirilla o las cortinas, sí.
- Rendimiento: un solo destello por relámpago, sin el fogonazo con sombras y el rayo sin ramas ni resplandor (solo el
  tronco; la luz de fuera y las lunas, sí).
- Un solo bucle de render, y solo mientras dura el relámpago o el temblor de su trueno; entre medias, una tarea que duerme
  hasta el siguiente (mira la fase cada 2 s como mucho).
- Lluvia: cuando exista la del lobby, se suma como bucle sin posición en las noches de tormenta (`sonidos-pendientes.md`,
  fila 39).
- Banco: `tests/bancos/tormenta.luau` (noches con tormenta, mismo horario con la misma semilla, rangos, la fuerza del
  destello, la forma del rayo, a su hora, el rayo del lado del trueno y a su distancia, trueno, cristales y bombillas,
  Rendimiento, cinemática, mirilla, el cielo visto (vestíbulo, junto a la ventana, sótano, escondido y fuera), de día,
  y el destello sumado en
  `Ambiente` de verdad).

## Probar en Studio

1. Forzar la tormenta (solo en Studio): de noche, `workspace:SetAttribute("TormentaPrueba", true)` en la barra de
   comandos (servidor o cliente). Para no esperar, bajar `Config.Tormenta.Cada` a `{ 5, 8 }` solo mientras se prueba
   (no subirlo así).
2. En el vestíbulo de noche, mirando a la ventana alta de encima de la puerta: fogonazo blanco azulado, la sombra del
   marco en la alfombra y el cielo blanco un instante. Que no ciegue ni brille de más (pedido por el usuario: brillos
   flojos); si se pasa, bajar `Luz.Brillo`, `Luz.Luna` o `Fogonazo.Brillo`.
3. Con un bicho (Golpeador) pegado a una ventana: en el fogonazo se le ve en negro y su sombra entra en la sala. Si la
   luz del fogonazo no pasa (el cristal o un alero la tapan), probar `Fogonazo.Atras` más pequeño o quitarle la sombra al
   cristal (`CastShadow = false`) en el cliente.
4. En el sótano y dentro del armario la pantalla apenas parpadea; fuera, igual que antes.
5. El trueno: lejano y sordo dentro, claro fuera; uno cercano suena desde un lado y tiemblan los cristales y las
   bombillas.
6. El rayo: fuera y desde una ventana, se ve quebrado en el horizonte, parpadea con los destellos y el trueno cercano
   llega del mismo lado. Que la niebla no lo borre (si se pierde, subir `Rayo.Brillo` o bajar `Rayo.Lejos`) y que no
   deslumbre (bajar `Rayo.Brillo` o `Rayo.Halo.Opacidad`).
7. Ajustes → Rendimiento: un solo destello, sin sombras nuevas y el rayo sin ramas. Una cinemática: nada. Dos
   jugadores: el mismo relámpago (y el mismo rayo) a la vez.
