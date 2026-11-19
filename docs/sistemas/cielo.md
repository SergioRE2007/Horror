# Cielo de la partida: nubes, estrellas y luna según la noche

Antes la partida no ponía ni `Sky` ni `Clouds` (solo el lobby, en `Clima.luau`): se veía el cielo de serie, sin nubes y
con 3000 estrellas que con la exposición alta de la noche (`ExposureCompensation` 1,6) brillaban mucho, también las
noches de tormenta. Todo en el cliente y solo de adorno: `src/juego/cliente/CieloVista.luau` (registrado en
`init.client.luau` justo después de `TormentaVista`). Números en `Config.Cielo`, a ojo.

## Qué hay

- **Sky** (`CieloJuego`, o el que traiga el lugar): luna algo mayor (`Luna`, 15 frente a 11 de serie). Estrellas:
  ninguna de día; de noche suben con la misma rampa que la luz de `Ambiente` hasta `Estrellas` (600), de 25 en 25.
  Ninguna con tormenta. Un `Sky` que llegue tarde (del servidor o del lugar) se usa ese y se quita el nuestro.
- **Nubes** (`Clouds` `NubesJuego` en el `Terrain`), tres estados en `Nubes`:
  - `Dia`: grises y casi cerradas.
  - `Noche`: rotas, con la luna y algunas estrellas entre ellas. Al anochecer y al amanecer se mezclan con la luz.
  - `Tormenta`: cerradas, gruesas y oscuras, encima de lo anterior.
  - `Niebla`: las noches de niebla cerrada, tapadas y con la luna velada (de día no cuenta).
- **La tormenta**: la misma cuenta que `TormentaVista.hay` (todos la ven igual) o, en Studio, el atributo `TormentaPrueba`
  del `workspace`. Llega y se va en rampa (`Rampa`, 25 s): al anochecer se ve cerrarse el cielo; a partir de
  `Tormenta.Abre` (el 93 % de la noche, después del último relámpago) se abre otra vez hacia el amanecer. Quien entra
  tarde la ve ya puesta, sin rampa.
- **Noches de niebla cerrada** (`Config.Cielo.Niebla`, a ojo): otro tiempo de noche para que hacia la noche 4 o 5 el
  cielo siga sorprendiendo. `CieloVista.hayNiebla(noche, inicio, cfg)`: desde `Desde` (3), con `Probabilidad` (0,35) y
  nunca si `TormentaVista.hay` (la semilla de `TormentaVista.semilla` + 104729: la ven todos igual). En Studio la fuerza
  el atributo `NieblaPrueba` del `workspace`, pero si hay tormenta (también la de `TormentaPrueba`) manda la tormenta.
  Rampa `neblina` de 0 a 1 (`Niebla.Rampa`, 40 s, suavizada): se cierra al anochecer y se levanta desde `Niebla.Abre`
  (90 % de la noche) hacia el amanecer; quien entra tarde la ve ya puesta. Se publica en `Ambiente.neblina` y
  `AireVista.neblina`. `Ambiente` (en `calcular`, con `neblina × k`: de día nada) lleva la `Atmosphere` de la noche hacia
  `Densidad` 0,58 (la normal 0,36), `Color` gris azulado algo más claro que el de la noche, `Haze` 2,6 y `Offset` 0 (el
  horizonte también se pierde). Sin estrellas y con las nubes de `Nubes.Niebla`. La niebla baja de `AireVista`, por
  `Baja` (2,5) y con la caja `Alto` (1,8) veces más alta (aire.md). No toca las lámparas ni la luz de fuera: la linterna
  es la que sirve.
- **La cuenta, compartida** (`shared/TiempoNoche`: `semilla`, `hayTormenta`, `hayNiebla`): `TormentaVista` y `CieloVista` la usan sin cambiarla y el servidor también (`Caza.esNiebla`: con niebla los bichos tampoco ven lejos fuera, bichos.md). Banco `niebla-bichos`.
- **El relámpago**: mientras `Ambiente.destello` > 0 la nube se aclara por dentro (el color va hacia `Destello.Color` y
  baja algo la densidad), cada fotograma; en cuanto acaba vuelve igual.
- **Luz**: `Ambiente.nublado` y `AireVista.nublado` (de 0 a 1, la tormenta en rampa). `Ambiente` multiplica con él
  `Brightness` y `OutdoorAmbient` hasta `Tormenta.Luz` (0,7) y el brillo de las luces de luna de las ventanas hasta
  `Tormenta.Lunas` (0,25); `AireVista` deja los haces de luna en `Tormenta.Haz` (0,15): con el cielo cerrado la sala se
  queda a oscuras. El relámpago (y el fogonazo de las lunas) se suma después, entero. Con 0, nada cambia.
- **Luces de luna de las ventanas** (hijas de una pieza con la etiqueta `Luna`, también si la etiqueta llega tarde):
  `Ambiente` guarda su azul la primera vez y lo mezcla con la noche desde `LuzDia` (gris frío): de día no cae luz azul
  a pleno sol.
- **Viento**: `workspace.GlobalWind` sigue a `AireVista.viento` (rumbo y rachas, el mismo que arrastra la niebla baja)
  por `Viento`, y más fuerte con tormenta (`Tormenta.Viento`). Solo mueve las nubes: ningún emisor usa `WindAffectsDrag`
  (si uno lo encendiera, también lo empujaría).
- **El viento que se oye** (`Config.Cielo.VientoSonido`, `Ambiente.vientoSonido`, función pura): el bucle `Viento` va
  de `Volumen` de día al doble de noche, por la racha de `AireVista.viento` (`Rachas`, 0,75 a 1,3; tono de 0,96 a 1,04),
  por `Tormenta` (1,5) con el cielo cerrado y sin pasar de `Tope` fuera. Con la cámara en casa (`AireVista.dentro`) baja a
  `Dentro.Volumen` y un `EqualizerSoundEffect` propio llamado `Dentro` (colgado del Sound; el `Oido` de OidoVista sigue
  aparte y lo apaga escondido) le quita agudos y medios; en el sótano, a `Sotano`. El paso de fuera a dentro tarda
  `Cambio` segundos (`Ambiente.acercar`): sin saltos en la puerta.
- **Efectos del lugar**: `Ambiente.start` apaga los `Bloom`, `SunRays` y `DepthOfField` que haya en `Lighting` (los
  trae la plantilla de Roblox) y los que lleguen tarde. Uno que el juego quiera de verdad lleva el atributo `Permitido`.

## Sol, alba y ocaso

En `src/juego/cliente/Ambiente.luau`, con `Config.Cielo.Sol` y `Config.Cielo.Alba` (a ojo).

- `Ambiente.hora(fase, p)`: cuánto de noche (`k`) y la hora (`ClockTime`). Día de 6,5 a 18,5 (`k` sube en el último
  20 %); noche de 18,5 a 6,5, deprisa hasta medianoche, casi quieta con la luna alta y hacia el alba en el último 10 %.
- `Ambiente.sol(hora)`: 0 con el sol bajo el horizonte, 1 con el sol alto, 0,5 justo en `Sol.Sale` / `Sol.Pone`
  (rampas de `Margen` horas a cada lado). Ajustar `Sale` y `Pone` mirando `Lighting:GetSunDirection().Y` en Studio.
- La exposición sigue al **sol**, no a `k`: al atardecer no sube hasta que el sol baja de `Sol.Pleno` (sin pico de luz
  antes de "NIGHT n") y al amanecer no baja hasta que el sol empieza a salir (antes caía con el sol aún abajo y los
  últimos segundos de la noche eran los más negros). El `Brightness` de noche (luna) solo entra `Sol.Luna` horas después
  de ponerse el sol del todo: con sol nunca pasa del de día. Lámparas, `Ambient` y niebla siguen con `k`.
- `Ambiente.franja(hora, nublado)`: campana de `Alba.Ancho` horas alrededor de la salida y la puesta (máxima con el sol
  en el horizonte, 0 a pleno día y plena noche). Lleva la niebla (`Color` más que `Decay`), algo del `OutdoorAmbient` y
  el tinte de la imagen hacia `Alba.Amanecer` (cálido apagado) o `Alba.Atardecer` (rojo apagado); un poco de `Glare` y
  algo menos de gris. Sin Bloom.
- Con tormenta la franja se apaga en rampa con `Ambiente.nublado` (el amanecer de una noche de tormenta sale gris; con
  `TormentaPrueba` en Studio se ve). En la escena final (`EscenaFinal` del jugador) tampoco hay franja: la luz la lleva
  la escena. La bajada de luz de la tormenta y el relámpago van encima de todo esto, como antes.
- Mientras hay franja se repinta a 30 Hz, como con `0 < k < 1`.
- `Ambiente.valores(fase, p, nublado, neblina)`: lo que se pinta antes de la tormenta y el relámpago, sin tocar nada (rellena
  siempre la misma tabla). Lo mira el banco.

## Rendimiento

Con Rendimiento (se mira en cada repaso: cambia en marcha), sin nubes y la mitad de estrellas. Un solo `RenderStepped`
que repasa cada `Cada` s (10 por segundo); las nubes, cada fotograma solo mientras dura un relámpago y una vez al acabar.

## Banco

`tests/bancos/cielo.luau`: carga `CieloVista` y `Ambiente` de verdad con una `TormentaVista` falsa. Mira las cuentas
(estados de nubes, destello que vuelve igual, estrellas, rampa), el día, el anochecer, la noche, la tormenta que llega en
rampa y baja la luz, el relámpago, Rendimiento, las luces de luna (grises de día, azules de noche, apagadas a su parte
con tormenta y con el fogonazo entero), el destello de la pantalla según `Ambiente.cieloVisto` (tormenta.md), `TormentaPrueba` (solo en Studio), entrar tarde, un `Sky` o unas nubes
que llegan tarde y los efectos apagados. La niebla cerrada: con la `TormentaVista` de verdad nunca la misma noche que
la tormenta, la misma semilla da lo mismo, ninguna antes de `Desde` y cerca de `Probabilidad`; la rampa sin saltos, la
densidad dentro de su rango y de día ninguna; en marcha con `NieblaPrueba` se cierra en `Niebla.Rampa`, la tormenta la
quita, se levanta desde `Abre`, fuera de Studio no vale y quien entra tarde la ve. Y el sol: exposición y brillo sin picos ni saltos al atardecer y al amanecer, la
franja en campana, apagada con el cielo cubierto, y en marcha al alba la tormenta y la escena final la quitan.
Y el viento que se oye: rachas, tormenta y tope, dentro y en el sótano, sin saltos al cruzar la puerta, y en marcha con la
cámara fuera, en el vestíbulo, en el sótano y con el cielo cerrado.

## Mirar en Studio

- De día, nubes grises; de noche, nubes rotas con la luna entre ellas y que la niebla (`Atmosphere`, densidad 0,36) no
  las tape del todo. Si se pierden, subir `Density` de las nubes antes que tocar la niebla.
- `workspace:SetAttribute("TormentaPrueba", true)` de noche: en 25 s el cielo se cierra sin estrellas y las nubes se
  encienden con cada relámpago sin cegar; en el vestíbulo se apaga el haz de luna de la alfombra y la sala queda más
  negra, pero el relámpago enciende la ventana igual. Fuera, el viento suena más fuerte y la niebla baja corre más.
- `workspace:SetAttribute("NieblaPrueba", true)` de noche: en ~40 s el bosque se cierra (desde la casa no se ven los
  árboles a 40-60 studs), sin estrellas, la niebla baja más espesa y la linterna sirviendo. Ni blanco lechoso ni negro
  del todo (si no, tocar `Niebla.Color` y `Densidad`). Dentro de casa sin neblina molesta. Se levanta al amanecer.
- De noche fuera el viento sube y baja a la vez que cae la pinocha; al entrar, en 1-2 s queda bajo y sordo, y en el
  sótano casi no se oye. Nada saturado con racha y tormenta a la vez.
- De día en el vestíbulo, la luz de la ventana alta no es azul.
- Ningún `Bloom` ni `SunRays` encendido en `Lighting`. Con Rendimiento, sin nubes.
- La cinemática final (`IncendioVista`, que manda en la luz mientras dura) se ve bien con las nubes de noche al alba.
