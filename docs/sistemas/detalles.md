# Detalles vivos de la casa (11.9)

Pedido por el usuario: "poner que la chimenea esté animada con fuego o sonidos de los electrodomésticos, detallitos". Todo en el cliente, sin tocar el servidor ni el camino del Trepador. Números en `Config.Detalles` (a ojo).

## Qué hay

- **Chimenea** (`ChimeneaVista`): tres llamas (una grande y dos bajas: con una sola parecía una antorcha), chispas y luz que tiembla. Al apagarse, las brasas siguen rojas y se enfrían en `Rescoldo` segundos. Si el Trepador se quema (`Quema`), el fuego se aviva de golpe. Si baja con la chimenea apagada (`Baja`), las brasas se apagan de golpe (aviso). De noche y apagada, el viento aúlla por el tiro (`VientoTiro`) y aviva un poco las brasas.
- **Reloj de pie del vestíbulo** (`DetallesVista`, el de `Config.Detalles.Reloj`; los del comedor y del rico están parados): tic-tac cada segundo y campanadas a las horas de `Campanadas` (a las 0, doce).
- **Nevera**: zumbido en bucle con el generador encendido; cada rato se para con un traqueteo (`NeveraClac`) y vuelve.
- **Grifos** (fregadero y lavabo): la gota se hincha en el grifo, se ve caer y suena al llegar al fondo de la pila.
- **Bombillas** (solo con el generador): la del pasillo (`BombillaMala`) zumba sin parar y parpadea a menudo; otra cerca de la cámara, de vez en cuando. Cuando el Trepador baja por la chimenea, todas las de la casa tiemblan casi hasta apagarse un par de segundos.
- **Tuberías**: de noche y con la cámara dentro de la casa, golpes dentro de las paredes.

## Cómo va

- `DetallesVista`: un solo `Heartbeat` que mira cuándo toca cada cosa y solo trabaja cerca de la cámara (`Cerca`). Los bucles (nevera, bombilla) se pausan lejos.
- Parpadeo de las luces: `Ambiente` pone el brillo de las lámparas cada fotograma, así que `DetallesVista` no lo toca directamente: escribe `Ambiente.factor[luz]` (0 a 1) y `Ambiente` lo multiplica. La pieza de la bombilla también se oscurece a juego.
- La chimenea: el atributo `Hogar` (lo usan el Trepador y el servidor) queda justo delante de la repisa. El fuego, las chispas y las brasas van medio stud más adentro (`dentro`), en el hueco. Antes se veían delante, sobre el suelo del salón.
- Posiciones en `Config.Detalles` como `{ x, y, z }`: Lune lee `Config` y no tiene `Vector3`.

## Sonidos

- ElevenLabs, tanda `detalles` (elegidos por el usuario): Tic 1, Campanada 2, Nevera 1, NeveraClac 1, Gota 2, Tuberia 2, VientoTiro 3.
- La bombilla, de YouTube (pedido por el usuario: los Chispazo y Parpadeo de ElevenLabs "brutalmente saturados"; ElevenLabs saca así todo lo eléctrico, zumbidos y chisporroteos). `Parpadeo`: "Efecto de Sonido - Foco Luz Rota" (youtu.be/QM4LOxiS-zY, de 2,3 a 3,9 s). `Zumbido`: "Bombilla de Luz Defectuosa Efecto de Sonido SIN COPYRIGHT" (youtu.be/-FAPoez6deM, entero, en bucle). Bajados con `yt-dlp` (winget `yt-dlp.yt-dlp`) a `sonidos-terror\youtube` y recortados con ffmpeg. El del foco no dice nada de derechos.

## Probado en Studio (02-11-2026)

- Sin errores. La bombilla del pasillo zumba y su brillo baja hasta 0,03 al parpadear. La nevera suena con luz. Caen 3 gotas en 10 s con su sonido. Suenan 8 tics en 8 s. Las chispas salen con el fuego y las brasas quedan encendidas al apagarse. Con `Baja`, las brasas se apagan y las 19 lámparas de la casa bajan casi a 0.
- No probado: las campanadas (hace falta llegar de noche a las 0) ni el viento del tiro (solo de noche). Claude no puede oír: el volumen lo decide el usuario.
