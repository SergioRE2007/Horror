# Oído: sonido tapado por las paredes y eco de cada sala

Pedido por el usuario: "mejorar la inmersión". Sin sonidos nuevos: cambia cómo se oye todo lo que ya suena. Solo en el
cliente (`src/juego/cliente/OidoVista.luau`), números en `Config.Oido` (a ojo).

## Qué hace

- **Paredes.** Cada sonido en 3D mira al empezar, y cada 0,25 s mientras suena, cuántas paredes hay entre la cámara y su
  punto (hasta 2). Rayos sin bichos ni personajes, y `MuebleRayo` para los muebles (sus cajas `Choque` y tableros no
  tienen CanQuery). Por cada pared, un `EqualizerSoundEffect` (llamado `Oido`, dentro del Sound) quita agudos (-18 dB) y
  medios (-6 dB) y baja el volumen al 70 % (-3 dB en las tres bandas: no se toca `Volume`, que los bichos y los bucles
  mueven cada fotograma). Así el Golpeador en la ventana de otra sala se oye sordo y grave, y al abrir la puerta suena
  claro de golpe: se sabe por el oído si está en tu sala o al otro lado.
- Qué cuenta como pared: el terreno y las piezas visibles con dos lados de al menos 3 studs (puertas, muros, suelos,
  armarios, cristales). Un tronco, una pata o un trozo de cristal no tapan; las capas de una misma pared (papel, muro,
  papel) a menos de 1,6 studs cuentan como una. Lo que está a 1,5 studs del sonido no cuenta (la ventana que golpean no
  tapa su propio golpe).
- **Escondido** (armario, debajo de la cama: atributo `Escondido` de Muerte), todo lo de fuera se oye como a través de la
  madera, también el viento y el fondo de la casa (`ApagarEscondido`). Tu respiración y tu latido no (`Sonido.tocar` y los
  bucles sin posición no se siguen), ni lo que cuelga de tu personaje.
- **Eco.** `SoundService.AmbientReverb` según dónde esté la cámara (`Config.Oido.Zonas`, la primera que la contenga):
  `LivingRoom` en la casa, `Bathroom` en el baño, `StoneCorridor` en el sótano y su escalera, `Room` en el desván, `Hangar`
  en el garaje, `Alley` en el pueblo y `Forest` fuera. Roblox no tiene un Hangar pequeño: si el garaje retumba demasiado,
  probar `ParkingLot` o `StoneRoom`.
- **Rendimiento**: el rayo cada 0,5 s y solo para los sonidos a menos de 60 studs (los demás se quedan como estaban).

## Cómo llega a todo

- `Sonido.en` llama a `OidoVista.seguir(s)`; `Sonido.bucle` también si cuelga de algo (bichos, fuego, motor, sierra) o
  si está en `ApagarEscondido`. Un Sound creado a mano en otro módulo: `OidoVista.seguir(sound)` tras darle Parent.
- Un solo bucle (`task.wait(Cada)`): el eco (unas comparaciones) y los sonidos que suenan y les toca. Los destruidos se
  olvidan solos. Las cajas de los muebles se rehacen cada 2 s o al moverse la cámara 8 studs.
- Cuentas puras para el banco `tests/bancos/oido.luau`: `ganancias` (paredes → dB), `zona` (punto → eco) y `contar`
  (paredes con un rayo cualquiera).

## Ojo

- `AmbientReverb` es de todo el juego: también le da eco a los sonidos de interfaz (en el baño se nota un poco).
- Las zonas son cajas copiadas de `Mapa` (salas) y `Lugares` (pueblo): si se mueve una sala, cambiarlas aquí.

## Probar en Studio

1. Noche con el Golpeador: quedarse en el salón con la puerta cerrada mientras golpea la ventana de la cocina. Debe oírse
   apagado y grave; abrir la puerta y que suene claro al momento. En el Explorer, el Sound del golpe lleva un `Oido`
   con `Enabled` y ganancias negativas.
2. Meterse en el armario: lo de fuera se apaga; la respiración y el latido, igual que siempre.
3. Andar por el baño, el sótano, el garaje y el desván, y salir al bosque: `SoundService.AmbientReverb` cambia
   (`print(game.SoundService.AmbientReverb)` desde la consola del cliente).
4. Con Rendimiento en Ajustes, lo mismo de cerca; un sonido a más de 60 studs ya no se tapa.
