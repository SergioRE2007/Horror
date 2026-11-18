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
- **La tormenta**: la misma cuenta que `TormentaVista.hay` (todos la ven igual) o, en Studio, el atributo `TormentaPrueba`
  del `workspace`. Llega y se va en rampa (`Rampa`, 25 s): al anochecer se ve cerrarse el cielo; a partir de
  `Tormenta.Abre` (el 93 % de la noche, después del último relámpago) se abre otra vez hacia el amanecer. Quien entra
  tarde la ve ya puesta, sin rampa.
- **El relámpago**: mientras `Ambiente.destello` > 0 la nube se aclara por dentro (el color va hacia `Destello.Color` y
  baja algo la densidad), cada fotograma; en cuanto acaba vuelve igual.
- **Luz**: `Ambiente.nublado` (de 0 a 1, la tormenta en rampa). `Ambiente` multiplica con él `Brightness` y
  `OutdoorAmbient` hasta `Tormenta.Luz` (0,8); el relámpago se suma después, entero. Con 0, nada cambia.
- **Viento**: `workspace.GlobalWind` sigue a `AireVista.viento` (rumbo y rachas, el mismo que arrastra la niebla baja)
  por `Viento`, y más fuerte con tormenta (`Tormenta.Viento`). Solo mueve las nubes: ningún emisor usa `WindAffectsDrag`
  (si uno lo encendiera, también lo empujaría).
- **Efectos del lugar**: `Ambiente.start` apaga los `Bloom`, `SunRays` y `DepthOfField` que haya en `Lighting` (los
  trae la plantilla de Roblox) y los que lleguen tarde. Uno que el juego quiera de verdad lleva el atributo `Permitido`.

## Rendimiento

Con Rendimiento (se mira en cada repaso: cambia en marcha), sin nubes y la mitad de estrellas. Un solo `RenderStepped`
que repasa cada `Cada` s (10 por segundo); las nubes, cada fotograma solo mientras dura un relámpago y una vez al acabar.

## Banco

`tests/bancos/cielo.luau`: carga `CieloVista` y `Ambiente` de verdad con una `TormentaVista` falsa. Mira las cuentas
(estados de nubes, destello que vuelve igual, estrellas, rampa), el día, el anochecer, la noche, la tormenta que llega en
rampa y baja la luz, el relámpago, Rendimiento, `TormentaPrueba` (solo en Studio), entrar tarde, un `Sky` o unas nubes
que llegan tarde y los efectos apagados.

## Mirar en Studio

- De día, nubes grises; de noche, nubes rotas con la luna entre ellas y que la niebla (`Atmosphere`, densidad 0,36) no
  las tape del todo. Si se pierden, subir `Density` de las nubes antes que tocar la niebla.
- `workspace:SetAttribute("TormentaPrueba", true)` de noche: en 25 s el cielo se cierra sin estrellas y las nubes se
  encienden con cada relámpago sin cegar.
- Ningún `Bloom` ni `SunRays` encendido en `Lighting`. Con Rendimiento, sin nubes.
- La cinemática final (`IncendioVista`, que manda en la luz mientras dura) se ve bien con las nubes de noche al alba.
