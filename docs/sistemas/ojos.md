# Ojos en la oscuridad

Pedido por el usuario ("mejorar la inmersión"). Código: `src/juego/cliente/OjosVista.luau`; números en `Config.Ojos`
(a ojo); banco: `tests/bancos/ojos.luau`.

## Qué hace

- **Ojos falsos** (de cada cliente, de adorno): de noche, con la cámara fuera de casa y la linterna encendida, cada
  `Entre` (18-45 s) asoman dos puntitos verdosos o ámbar junto a un tronco (etiqueta `Pino`) que esté dentro del haz, a
  30-70 studs, por un lado del tronco, a altura de animal (1,1-2,4) o de persona (4,6-5,6). A veces (`Doble`) son dos
  pares. Se mueven un poco y parpadean. Viven 5-10 s y se van solos sin ruido.
- **Solo dentro de tu haz**: cada fotograma brillan según lo cerca que estén del centro del cono de tu linterna
  (`Config.Linterna.Angulo`) y de su alcance; fuera del haz, nada. Con poca pila, parpadean con la luz. Un tronco
  delante los tapa (`AlwaysOnTop = false`).
- **Se van**: mirarlos fijo (`Fijo` grados, `Mirada` s) o acercarte a menos de `Cerca` los apaga mientras se meten tras
  el tronco, y suena una `Ramita` en 3D un poco más allá (a veces otra más lejos), como algo que huye.
- **Ojos de los bichos** (los mismos en todos los clientes): Acechador, Golpeador, Bestia (sus seis ojos) y Trepador
  llevan un punto que brilla donde están los puntitos Neon de su `Cabeza` (`Config.Ojos.Bichos`). Brillan con tu
  linterna si el bicho está fuera de casa, te mira de cara y está a más de `BichoCerca`. **No se apagan al mirarlos**:
  unos ojos que siguen ahí son un aviso de verdad. Mismo color y tamaño que los falsos, para que no se distingan por eso.
- Nunca dentro de casa ni a menos de `Nunca` studs; nada en las cinemáticas (cámara que no es `Custom`); de día se
  quitan. Con **Rendimiento**, solo los de los bichos.
- Cada ojo es un `BillboardGui` de pocos píxeles (más un poco en studs, para que de lejos no se pierda) con un núcleo y
  un halo muy flojos, sin luz propia ni `Neon`. Un repaso cada `Cada` s; el `Heartbeat` solo va con la linterna
  encendida y falsos vivos o un bicho al alcance.

## Probar en Studio

- De noche (o con `Config.Test`), salir al bosque con la linterna y barrer entre los árboles: cada 20-45 s, dos
  puntitos junto a un tronco. Apartar la linterna: desaparecen; volver: siguen ahí. Mirarlos fijo: se apagan y cruje
  una ramita desde allí.
- Para verlos enseguida: `Config.Ojos.Entre = { 1, 2 }` (no subirlo así).
- Con un Acechador o un Golpeador fuera, alumbrarlo de lejos: sus ojos brillan y no se van al mirarlos. Sin probar con
  la malla 3D del Golpeador (`GolpeadorVista`, Malla3D): si la malla tapa el punto, adelantar su `z` en
  `Config.Ojos.Bichos`.
- Con Rendimiento en Ajustes: solo salen los de los bichos.
- `screen_capture` sí los pinta (no usan `AlwaysOnTop`).
