# Aire vivo: polvo siempre en la luz, haces de luna y niebla baja

Pedido por el usuario: "mejorar la inmersión del juego, que haya efectos de polvo en el aire o cosas así". Todo en el
cliente y solo de adorno: `src/juego/cliente/AireVista.luau` (registrado en `init.client.luau` después de `Efectos`).
Números en `Config.Aire`, a ojo.

## Qué hay

- **Polvo dentro de la casa**: motas muy flojas en una caja delante de la cámara (`Config.Aire.Motas`), con
  `LightInfluence = 1`: a oscuras no se ven y brillan donde da la luz. El haz de la linterna se llena de polvo al barrer
  una sala y alrededor de las bombillas encendidas se ve la neblina. Misma receta que las motas de `Efectos.hacerMotas`.
  - En `Config.Aire.Salas` (rectángulos sacados de `SALAS` de `Mapa`), más: desván, sótano y trastero el triple; garaje y
    cobertizo un poco más. Estas salas cuentan como "dentro" aunque estén fuera de `Config.Casa` (el sótano, el desván
    por encima de y = 28, el garaje y el cobertizo).
  - Lo que levantan los golpes (`Efectos.moverPolvoAire`) es otra caja y se suma encima, igual que antes.
- **Haces de luna**: cada luz de `Mapa.luzLuna` lleva la etiqueta `Luna`. De noche, cerca de la cámara (`Haz.Cerca`), un
  `Beam` azulado casi transparente de la ventana al suelo (un rayo busca la primera cara que mira hacia arriba:
  atraviesa cortinas y marcos), con la textura de humo estirada (bordes suaves) y sus propias motas que brillan dentro.
  Se hace la primera vez que hace falta. Con las cortinas de esa ventana echadas (atributo `Persiana` de la `Ventana` más
  cerca, a menos de `Haz.Ventana`), apagado. Se aclara y oscurece con el atardecer y el amanecer. Con el cielo cerrado
  de tormenta (`AireVista.nublado`, lo pone `CieloVista`) se queda en `Config.Cielo.Tormenta.Haz` (0,15) de lo que se
  veía, motas incluidas (`AireVista.fuerzaHaz`): no hay luna que lo haga.
- **Niebla baja**: fuera y de noche, partículas grandes y planas (`Squash` negativo) a ras de suelo en un radio de ~40
  alrededor de la cámara, que se arrastran despacio hacia donde sopla el viento.
- **Pinocha**: fuera, en las rachas y con un pino a menos de `Pinocha.Cerca` (etiqueta `Pino` en el tronco de cada pino de
  `Mapa`), cae pinocha fina dando vueltas y de lado con el viento.
- **Viento**: no había dirección de viento en `Ambiente`, así que la pone `AireVista.viento()` (hacia dónde, fuerza y
  racha de 0 a 1): ruido lento con la hora del servidor, el mismo en todos los clientes. Sirve para otros adornos.

## Reglas

- Un solo `Heartbeat` que repasa cada `Config.Aire.Cada` (0,1 s): coloca las cajas y enciende o apaga los emisores según
  dónde esté la cámara. Las partículas nacen en el mundo, no van pegadas a la caja.
- Nada en cinemáticas ni en la muerte (cámara `Scriptable` sin el atributo `Vistazo`); en un vistazo por la mirilla o las
  cortinas, sí.
- Rendimiento: motas a `Config.Aire.Rendimiento` (0,3) y sin haces, niebla ni pinocha.
- La noche sale de los atributos del Ciclo con las mismas rampas que `Ambiente` (`AireVista.noche`).
- Texturas `rbxasset` (`smoke_main.dds`): no hacen falta imágenes nuevas.
- Banco: `tests/bancos/aire.luau` (cuentas, cada sitio, Rendimiento, cinemática, cortinas, de día, tormenta). Ojo: en Lune
  `CFrame.lookAt` sale al revés en z; el módulo usa `CFrame.fromMatrix` a mano.

## Probar en Studio

1. De noche (`Config.Test` o esperar), con el generador encendido, entrar en la casa y barrer con la linterna: motas
   flotando en el haz; mirar una bombilla encendida de cerca: neblina suave. Sin luz, no se ve nada.
2. Subir al desván y bajar al sótano: el triple de motas en la linterna.
3. Vestíbulo de noche: el haz azulado de la ventana alta de encima de la puerta hasta la alfombra, con motas. Echar las
   cortinas de esa ventana: el haz se apaga. Mirarlo al amanecer: se va despacio.
4. Salir al bosque de noche: niebla a ras de suelo que se arrastra hacia un lado. Bajo un pino, esperar una racha: cae
   pinocha.
5. Ajustes → Rendimiento: menos motas y nada de haces, niebla ni pinocha. Una cinemática: nada.
6. Mirar que no brille de más (pedido por el usuario: brillos flojos). Si los haces o la niebla se notan demasiado,
   subir `Haz.Transparencia` o la transparencia de la niebla en `AireVista`.
