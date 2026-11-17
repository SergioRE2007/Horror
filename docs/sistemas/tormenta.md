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
- **Las lunas**: las luces de luna (etiqueta `Luna`, `Mapa.luzLuna`) a menos de `Fogonazo.Cerca` suben su brillo con el
  destello (`Ambiente.lunas`). Con las cortinas de esa ventana echadas (`Persiana`), no.
- **Fogonazo con sombras** (sin Rendimiento): para las 3 lunas más cercanas, un `SpotLight` con sombras en la misma
  línea que la luna pero 5 studs por fuera del cristal (carpeta `TormentaLocal` del workspace, fuera de `Mapa`). Lo que
  haya entre esa luz y la sala hace sombra en el suelo: los marcos, las cortinas y un bicho pegado a la ventana, que se ve
  en negro contra el cielo blanco (ninguna luz le da por delante). Nadie lo programa: sale solo de la luz.
- **El trueno**: 1 a 5 s después (antes cuanto más cerca). Mientras no haya un `Trueno` propio (`sonidos-pendientes.md`,
  fila 34), `Retumbo` a tono 0,38-0,5 (muy grave y largo). Lejano: sin posición y, con la cámara en casa o escondido, sordo
  (ecualizador sin agudos). Cercano (`Cerca3D`): en 3D desde fuera, entero, y las paredes lo tapan solas (`OidoVista`).
- **Con el trueno**: los cristales de las ventanas a menos de `Ventanas` traquetean (`CasaVista.elementos[...].vibrar`)
  y suenan los dos más cercanos (`CristalVibra`); las bombillas (`PointLight`) tiemblan (`Ambiente.temblor`, cada una a
  su aire, sin tocar `Ambiente.factor` para no pisar los parpadeos de `DetallesVista` y `Efectos`); si fue encima, un
  temblor de cámara muy flojo (`CasaVista.temblar`).
- **Todos a la vez**: el horario sale de una semilla con `Noche` y `FaseInicio` (atributos del Ciclo) y la hora del
  servidor (`GetServerTimeNow`). Sin servidor nuevo. Quien entra tarde se salta los ya pasados.

## Reglas

- Nada en cinemáticas ni en la muerte (cámara `Scriptable` sin el atributo `Vistazo`); por la mirilla o las cortinas, sí.
- Rendimiento: un solo destello por relámpago y sin el fogonazo con sombras (la luz de fuera y las lunas, sí).
- Un solo bucle de render, y solo mientras dura el relámpago o el temblor de su trueno; entre medias, una tarea que duerme
  hasta el siguiente (mira la fase cada 2 s como mucho).
- Lluvia: cuando exista la del lobby, se suma como bucle sin posición en las noches de tormenta (`sonidos-pendientes.md`,
  fila 35).
- Banco: `tests/bancos/tormenta.luau` (noches con tormenta, mismo horario con la misma semilla, rangos, la fuerza del
  destello, a su hora, trueno, cristales y bombillas, Rendimiento, cinemática, mirilla, de día, y el destello sumado en
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
4. El trueno: lejano y sordo dentro, claro fuera; uno cercano suena desde un lado y tiemblan los cristales y las
   bombillas.
5. Ajustes → Rendimiento: un solo destello y sin sombras nuevas. Una cinemática: nada. Dos jugadores: el mismo
   relámpago a la vez.
