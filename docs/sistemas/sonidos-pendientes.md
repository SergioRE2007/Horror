# Sonidos e imágenes que faltan (14.9.4)

Lista para cuando vuelvan los créditos de ElevenLabs (~08-11-2026). Ordenada por lo que más se oye. Duraciones y
número de versiones, a ojo.

Reglas (de `sonidos.md`, pedido por el usuario): nada de sonidos de serie de Roblox cambiados de tono; los ambientes
pedidos de una vez salen mudos y con siseo (por eso la lluvia tiene plan B compuesto); lo eléctrico sale saturado (la
radio va pedida suave y, si satura, una de YouTube sin derechos que elija Sergio); volumen compensado con el pico.

## Pasos

1. Pegar la tanda de abajo dentro de `BATCHES` de `tools/sonidos/generar.mjs` como `pendientes: [ ... ],` (el script no
   lee JSON: las tandas son objetos del JS y este JSON vale tal cual dentro). Quitar de la tanda `miedo` las 8 líneas
   de Susurro a Rafaga, que van aquí (Toc cambiado), para que no salgan dos veces.
2. `node tools/sonidos/generar.mjs "$HOME\Documents\Roblox\sonidos-terror" pendientes` → `pendientes\escuchar.html`.
   Sergio elige de oído (Claude no oye).
3. Si alguno empieza con silencio o con un golpe saturado: `node tools/sonidos/recortar.mjs <in.mp3> <out.wav> 0.05`.
4. `node tools/sonidos/picos.mjs <carpeta>\pendientes`: los que salgan flojos, `Volumen = el de la tabla × 1 / pico`.
5. `node tools/sonidos/subir.mjs <carpeta>\pendientes g1002188803 "$HOME\Documents\Roblox\clave-roblox.txt" "^(Lluvia_2|Trueno_1|...)$"`
   → ids en `pendientes\ids.json`.
6. Poner el Id (una lista si se eligen varias versiones) y el volumen en la clave de la tabla; `selene src`, Lune y
   probar en Studio.

Si no llegan los créditos para todo: primero las filas 1 a 8.

## Sonidos

| # | Clave (Id y Volumen) | Qué es | s | Tipo | Vers. | Ahora suena |
|---|---|---|---|---|---|---|
| 1 | `Config.SonidosLobby.Lluvia` (0,6) | Lluvia de fondo del lobby | 20 | bucle | 3 | nada (Id 0) |
| 2 | `Config.SonidosLobby.Trueno` (1,2) | Trueno lejano tras cada relámpago (25-70 s); lista de 2-3 | 7 | suelto | 4 | nada |
| 3 | `Config.SonidosLobby.LluviaChapa` (0,5) | Lluvia en la chapa de la marquesina | 12 | bucle | 3 | nada |
| 4 | `Config.Sonidos.Jadeo` (0,7) | Jadeo al agotarte; el código lo baja para los resoplidos | 3 | suelto, lista | 4 | provisional `Config.Correr.Jadeo` (VientoTiro a tono 1,6) |
| 5 | `Config.Sonidos.Respiracion` (0,5) | Respiración nerviosa escondido y en la mirilla | 8 | bucle | 3 | nada |
| 6 | `Config.Sonidos.Contener` (0,6) | Coger aire de golpe y aguantarlo | 1,5 | suelto | 3 | nada |
| 7 | `Config.Sonidos.Exhalar` (0,6) | Soltar el aire temblando | 3 | suelto | 3 | nada |
| 8 | `Config.Sonidos.Rafaga` (0,8) | Ráfaga contra una ventana (35-90 s) | 4 | suelto | 3 | VientoTiro |
| 9 | `Config.Sonidos.Retumbo` (0,8) | Pisada enorme que hace temblar la casa | 2 | suelto | 3 | Golpe (puñetazo en persiana) |
| 10 | `Config.Sonidos.Vajilla` (0,5) | Platos y vasos que tintinean al temblar; lista | 1 | suelto, lista | 4 | CristalVibra y Latas, agudos |
| 11 | `Config.Sonidos.CristalVibra` (0,6) | Cristal que traquetea en el marco | 1,5 | suelto | 3 | Grieta (madera) |
| 12 | `Config.Sonidos.Polvo` (0,6) | Arenilla que cae del techo | 2 | suelto | 3 | Hollín |
| 13 | `Config.Sonidos.Mecedora` (0,6) | Crujido de la mecedora al dar la vuelta; lista | 1,5 | suelto, lista | 4 | Cruje |
| 14 | `Config.Sonidos.Aranazo` (1) | Algo araña madera (susto Pared, Bestia, Imitador, Raspador) | 2,5 | suelto | 3 | Raspado (uñas en cristal) |
| 15 | `Config.Sonidos.Toc` (0,8) | UN golpe de nudillo en el cristal; lista | 0,5 | suelto, lista | 4 | Llamar (tres golpes en la puerta) |
| 16 | `Config.Sonidos.Sobresalto` (1,2) | Golpe de tensión al ver algo | 2 | suelto | 3 | Susto (el de morir) |
| 17 | `Config.Sonidos.Susurro` (0,5) | Susurro al oído | 3 | suelto, lista | 4 | Susto: el más equivocado de los provisionales |
| 18 | `Config.Sonidos.Resoplido` (0,8) | La Bestia suelta el aire por la nariz | 2 | suelto | 3 | Rugido grave y cortado |
| 19 | `Config.SonidosLobby.Radio` (0,5) | Radio vieja de la tienda con interferencias | 15 | bucle | 3 | nada |
| 20 | `Config.SonidosLobby.Campanilla` (0,6) | Campanilla al abrirse la puerta de la tienda | 2 | suelto | 3 | nada |
| 21 | `Config.SonidosLobby.Sello` (0,6), **clave nueva** | Sello al estamparse ELEGIDA / EN USO / TUYO en la tienda | 0,6 | suelto | 3 | nada (solo `Papel` al cambiar de separador y al cerrar) |
| 22 | `Config.SonidosLobby.MotorCoche` (0,8) | Motor de coche viejo al ralentí: el que llega al lobby tras un viaje (22 s) | 10 | bucle | 3 | el Arranque una vez al acercarse (hoy también Id 0: nada) |
| 23 | `Config.SonidosLobby.Arranque` (1) | El coche arranca y se va (cinemática de 7 s) | 7 | suelto | 3 | nada |
| 24 | `Config.Sonidos.Mirilla` (0,5) | La tapita de latón de la mirilla | 0,6 | suelto | 3 | nada |
| 25 | `Config.Sonidos.Papel` (0,75) | Papel de las pistas (y de la tienda y los coches) | — | — | — | ya hecho: 3 versiones que puso Claude |
| 26 | `Config.Sonidos.GritoGolpeador` (2) | Chillido final del susto del Golpeador (14.10) | 1,5 | suelto | 4 | Susto otra vez |
| 27 | `Config.Sonidos.RespiraBicho` (0,8) | El Golpeador respirando pegado a tu armario | 5 | suelto | 3 | otro provisional |
| 28 | `Config.Sonidos.Olfateo` (0,9) | El Golpeador olfateando | 2 | suelto | 3 | otro provisional |
| 29 | `Config.Sonidos.UnasPared` (1) | Garras por la pared al pasar | 2,5 | suelto | 3 | otro provisional |
| 30 | `Config.Sonidos.ToqueDedo` (1) | Toque lento de uña en el cristal | 0,5 | suelto | 4 | otro provisional |

Notas por fila:

- **1 Lluvia, plan B**: si sale muda o puro siseo, componerla (`componer.mjs`) con la receta de abajo y piezas
  `lluviatrozo` y `goterones` (también en la tanda).
- **4 Jadeo**: con su Id, `Config.Correr.Jadeo` y `JadeoTono` quedan sin uso (se pueden borrar). El mismo sonido sirve
  para el jadeo fuerte, los resoplidos flojos (`CorrerVista`) y los de escondido (`MuerteVista`).
- **15 Toc**: el código lo toca de uno en uno (tres seguidos en el susto Cristal). `ImitadorVista` (`GOLPES`,
  `GOLPECITO`) cuenta con que Toc es la grabación de Llamar y la corta tras 2 golpes: al poner el nuevo, cambiar allí a
  `"Llamar"` o quitar el corte. `Sustos/Ruidos` lo usa en una pared a tono 0,6: oírlo.
- **21 Sello**: añadir la clave a `Config.SonidosLobby`, tocarlo en `lobby/cliente/TiendaUi` donde se estampa
  (`fila.escalaSello.Scale = 1.7`) y meterlo en su `Sonido.precargar`.
- **19 Radio**: pedida suave y apagada; si satura, de YouTube sin derechos (como la bombilla).
- **22 MotorCoche**: va antes que Arranque porque cada salida trae una llegada y dura el triple. `LlegadaVista` lo toca
  en bucle en la copia y le sube el tono con la velocidad (`PlaybackSpeed` 0,8 + 0,012 × studs/s: 0,8 parado, ~1,16 a
  30); al apagar el coche, volumen 0. Pedirlo a velocidad constante, sin arranque ni acelerones. Sin él (Id 0), la llegada
  usa el Arranque una vez a 16 s de la hora (`Sonido.hay`).
- **25 Papel**: no generar más. Falta que Sergio elija en `sonidos-terror\miedo\escuchar.html`; si no le gusta ninguno,
  se pide otro.

## Tanda `pendientes` (pegar en `BATCHES`)

```json
[
	{ "name": "Lluvia", "seconds": 20, "versions": 3, "loop": true, "label": "Lluvia de fondo sobre la explanada y los árboles (bucle)", "text": "Steady heavy rain falling at night on a forest clearing and a wet asphalt road, dense close raindrops and splashes in puddles, full and clearly audible, rich detail, no thunder, no hiss, no music, seamless ambient loop" },
	{ "name": "Trueno", "seconds": 7, "versions": 4, "label": "Trueno lejano que retumba y se apaga", "text": "Distant thunder rolling across the night sky, deep low long rumble that slowly fades out, no rain, no music" },
	{ "name": "LluviaChapa", "seconds": 12, "versions": 3, "loop": true, "label": "Lluvia sobre la chapa de la marquesina (bucle)", "text": "Rain drumming on a corrugated metal roof of a gas station canopy, heard from right underneath, dense metallic pattering and drips, clearly audible, no thunder, no music, seamless ambient loop" },
	{ "name": "Jadeo", "seconds": 3, "versions": 4, "label": "Jadeo fuerte al agotarse corriendo", "text": "Exhausted young person heavily panting after sprinting, fast deep gasping breaths through the mouth that slowly calm down, close to the microphone, no voice, no words, horror game sound effect, realistic, dry, no reverb, no music" },
	{ "name": "Respiracion", "seconds": 8, "versions": 3, "loop": true, "label": "Respiración nerviosa escondido (bucle)", "text": "Nervous shaky breathing of a frightened person hiding in a dark closet, quiet trembling breaths in and out, close to the ear, steady rhythm, no voice, no words, realistic, dry, seamless loop" },
	{ "name": "Contener", "seconds": 1.5, "versions": 3, "label": "Coger aire de golpe y aguantarlo", "text": "Frightened person sharply inhaling a quick gasp and then holding their breath, the sound stops abruptly into silence, close, no voice, horror game sound effect, realistic, dry, no reverb, no music" },
	{ "name": "Exhalar", "seconds": 3, "versions": 3, "label": "Soltar el aire temblando", "text": "Frightened person slowly releasing a held breath, long shaky trembling exhale, then one short gasp, close, no voice, horror game sound effect, realistic, dry, no reverb, no music" },
	{ "name": "Rafaga", "seconds": 4, "versions": 3, "label": "Ráfaga de viento contra una ventana", "text": "Strong gust of wind hitting a window from outside, the glass rattling and the wind whistling through the gaps of the frame, rises and fades, horror game sound effect, realistic, dry, no reverb, no music" },
	{ "name": "Retumbo", "seconds": 2, "versions": 3, "label": "Pisada enorme que hace temblar la casa", "text": "Deep heavy rumbling thud of a giant footstep nearby, the whole wooden house shaking and rattling, low boom, horror game sound effect, realistic, dry, no reverb, no music" },
	{ "name": "Vajilla", "seconds": 1, "versions": 4, "label": "Platos y vasos que tintinean al temblar", "text": "Plates, cups and glasses on a wooden shelf briefly rattling and clinking together as the floor shakes, short delicate ceramic and glass chatter, horror game sound effect, realistic, dry, no reverb, no music" },
	{ "name": "CristalVibra", "seconds": 1.5, "versions": 3, "label": "Cristal que traquetea en su marco de madera", "text": "Loose window glass pane rattling in its old wooden frame, short trembling rattle, horror game sound effect, realistic, dry, no reverb, no music" },
	{ "name": "Polvo", "seconds": 2, "versions": 3, "label": "Arenilla y polvo que caen del techo", "text": "Dust, grit and small plaster debris trickling down from a ceiling onto a wooden floor, soft sandy patter, horror game sound effect, realistic, dry, no reverb, no music" },
	{ "name": "Mecedora", "seconds": 1.5, "versions": 4, "label": "Mecedora que cruje al mecerse sola", "text": "Old wooden rocking chair rocking once on a wooden floor, a single slow creak of the runners and joints, horror game sound effect, realistic, dry, no reverb, no music" },
	{ "name": "Aranazo", "seconds": 2.5, "versions": 3, "label": "Algo araña por dentro de una pared de madera", "text": "Something scratching and clawing from inside a wooden wall, slow scraping claws on wood, muffled, horror game sound effect, realistic, dry, no reverb, no music" },
	{ "name": "Toc", "seconds": 0.5, "versions": 4, "label": "Un solo golpe de nudillo en el cristal", "text": "Single knuckle knock on a glass window pane, one sharp hollow tap with a faint glass ring, very short, horror game sound effect, realistic, dry, no reverb, no music" },
	{ "name": "Sobresalto", "seconds": 2, "versions": 3, "label": "Golpe de tensión corto (no un grito)", "text": "Short horror tension stinger, deep low dissonant boom hit with a dark rumble tail, no scream, no voice, no music melody" },
	{ "name": "Susurro", "seconds": 3, "versions": 4, "label": "Susurro ininteligible al oído", "text": "Creepy unintelligible whisper very close to the ear, breathy hushed murmur with no clear words, intimate, horror game sound effect, no music" },
	{ "name": "Resoplido", "seconds": 2, "versions": 3, "label": "La Bestia suelta el aire por la nariz", "text": "Huge beast exhaling forcefully through its nostrils, a deep heavy wet snort like a giant bull, low and powerful, no roar, horror game sound effect, realistic, dry, no reverb, no music" },
	{ "name": "Radio", "seconds": 15, "versions": 3, "loop": true, "label": "Radio vieja de la tienda con interferencias (bucle)", "text": "Old transistor radio in a small shop, faint muffled crackling static with a distant indistinct voice fading in and out, soft and quiet, gentle, no harsh noise, no distortion, no music, seamless ambient loop" },
	{ "name": "Campanilla", "seconds": 2, "versions": 3, "label": "Campanilla de la puerta de la tienda", "text": "Small brass shop door bell jingling as the door opens, a few bright tinkles that fade, realistic, dry, no music" },
	{ "name": "Sello", "seconds": 0.6, "versions": 3, "label": "Sello de goma que se estampa en la libreta", "text": "Rubber stamp pressed hard onto paper on a wooden desk, a single firm muffled thump with a soft paper slap, very short, realistic, dry, no reverb, no music" },
	{ "name": "MotorCoche", "seconds": 10, "versions": 3, "loop": true, "label": "Motor de coche viejo al ralentí (bucle; el que llega al lobby)", "text": "Old car engine idling steadily, low rough rumble with a slight irregular sputter, heard from outside the car a few meters away, constant engine speed, no starting, no revving, no driving away, no rain, no music, seamless loop" },
	{ "name": "Arranque", "seconds": 7, "versions": 3, "label": "Coche viejo que arranca y se va bajo la lluvia", "text": "Old car engine cranking, starting with a cough and rumbling to life, then revving and driving away on a wet road in the rain, tires on wet asphalt, fading into the distance, no music" },
	{ "name": "Mirilla", "seconds": 0.6, "versions": 3, "label": "La tapita de latón de la mirilla al apartarla", "text": "Small brass peephole cover on a wooden front door being slid aside, tiny metallic scrape and a soft click, very short, close, horror game sound effect, realistic, dry, no reverb, no music" },
	{ "name": "lluviatrozo", "seconds": 5, "versions": 2, "label": "Pieza (plan B de Lluvia): chaparrón cercano", "text": "Close burst of heavy rain on leaves and wet ground, dense clear raindrops, clean, no hiss, no thunder, no music" },
	{ "name": "goterones", "seconds": 3, "versions": 2, "label": "Pieza (plan B de Lluvia): goterones en un charco", "text": "Big water drops falling from a roof edge into a puddle, a few distinct clear plops and splashes, clean, no music" },
	{ "name": "GritoGolpeador", "seconds": 1.5, "versions": 4, "label": "Chillido final del susto del Golpeador", "text": "Sudden piercing monstrous shriek right in the face, a gaunt humanoid creature screaming with its jaw wide open, raw wet throat, harsh and terrifying, starts instantly at full loudness, short, horror jumpscare sound effect, no music" },
	{ "name": "Olfateo", "seconds": 2, "versions": 3, "label": "Golpes de nariz de un bicho grande", "text": "Large creature sniffing the air in short sharp bursts through its nose, four or five quick wet sniffs, close, horror game sound effect, realistic, dry, no reverb, no music" },
	{ "name": "UnasPared", "seconds": 2.5, "versions": 3, "label": "Garras arrastradas por una pared al pasar", "text": "Long sharp claws slowly dragged along a wooden and plaster wall while walking, a continuous scraping screech of nails on wallpaper and wood, horror game sound effect, realistic, dry, no reverb, no music" },
	{ "name": "ToqueDedo", "seconds": 0.5, "versions": 4, "label": "Un toque lento de uña en el cristal", "text": "Single slow tap of a long fingernail against a window pane, one hard click on glass with a faint ring, very short, horror game sound effect, realistic, dry, no reverb, no music" },
	{ "name": "RespiraBicho", "seconds": 5, "versions": 3, "label": "Respiración del bicho pegado al armario", "text": "Slow heavy wet breathing of a large creature right outside a wooden closet door, deep rattling inhales and long exhales, very close, no voice, no growl, horror game sound effect, realistic, dry, no reverb, no music" }
]
```

Plan B de la lluvia (receta de `componer.mjs`; guardarla como `tools/sonidos/lluvia.json` y
`node tools/sonidos/componer.mjs tools/sonidos/lluvia.json <carpeta>\pendientes Lluvia_B.wav`): la brisa de fondo con
el corte alto hace de lluvia lejana y las piezas le dan cuerpo.

```json
{
	"seconds": 30,
	"cutoff": 9000,
	"peak": 0.9,
	"bed": { "level": 0.06, "cutoff": 3500, "depth": 0.25, "seed": 83 },
	"events": [
		{ "file": "lluviatrozo_1.mp3", "at": 0.0, "gain": 0.5, "pan": -0.4 },
		{ "file": "goterones_1.mp3", "at": 3.5, "gain": 0.3, "pan": 0.6 },
		{ "file": "lluviatrozo_2.mp3", "at": 5.0, "gain": 0.45, "pan": 0.3 },
		{ "file": "lluviatrozo_1.mp3", "at": 10.0, "gain": 0.5, "pan": 0.0 },
		{ "file": "goterones_2.mp3", "at": 13.0, "gain": 0.28, "pan": -0.6 },
		{ "file": "lluviatrozo_2.mp3", "at": 15.0, "gain": 0.45, "pan": -0.3 },
		{ "file": "lluviatrozo_1.mp3", "at": 20.0, "gain": 0.5, "pan": 0.4 },
		{ "file": "goterones_1.mp3", "at": 22.5, "gain": 0.3, "pan": -0.2 },
		{ "file": "lluviatrozo_2.mp3", "at": 25.0, "gain": 0.45, "pan": -0.5 }
	]
}
```

## Imagen: la mano de sangre

Qué es: en el susto Cristal (`juego/cliente/Sustos/Sangre.luau`, `lanzarCristal`), tras tres golpecitos aparece de golpe
una mano de sangre por fuera de una ventana cercana, resbala un poco y deja regueros. Ahora la mano está hecha con
marcos (función `mano`) y se ve de dibujo. Va en una placa de 2 × 3,7 studs; la mano ocupa el cuadrado de arriba
(2 × 2 studs, a 70 px por stud) con el pulgar a la derecha.

Texto para ChatGPT (en español: una mano izquierda apoyada en un cristal, sangre oscura y realista, fondo
transparente, sin letras):

```text
Photorealistic bloody handprint, as if a person pressed an open left hand flat against a window pane from outside,
seen straight on with the thumb on the right side of the image. Palm and five fingers clearly printed in dark, slightly
dried crimson blood (deep red, almost brown at the edges), smeared a little downward, with a few thin drips running
down from the bottom of the palm. Uneven texture like real blood on glass: darker where the pressure was, thin and
patchy at the fingertips, faint skin creases visible. Dark realistic horror mood, not a cartoon, not a drawing, no
outlines. Only the handprint, centered, filling about 80% of a square image. Real transparent background (PNG with
alpha, not a checkerboard), no glass, no window, no hand or person, no text, no letters, no watermark, no frame.
Moderate amount of blood, nothing else gory.
```

Cómo se prepara (PowerShell, como `tools/texturas/*.ps1`): si el fondo no sale transparente de verdad, pedirlo otra
vez. Recortar al dibujo, dejarlo cuadrado con un margen pequeño y pasarlo a 512 × 512:

```powershell
Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Bitmap]::FromFile("$HOME\Downloads\mano.png")
$x0 = $img.Width; $y0 = $img.Height; $x1 = 0; $y1 = 0
for ($y = 0; $y -lt $img.Height; $y += 2) { for ($x = 0; $x -lt $img.Width; $x += 2) {
	if ($img.GetPixel($x, $y).A -gt 10) { $x0 = [Math]::Min($x0, $x); $x1 = [Math]::Max($x1, $x); $y0 = [Math]::Min($y0, $y); $y1 = [Math]::Max($y1, $y) } } }
$lado = [Math]::Max($x1 - $x0, $y1 - $y0) * 1.06
$cx = ($x0 + $x1) / 2; $cy = ($y0 + $y1) / 2
$out = New-Object System.Drawing.Bitmap 512, 512
$g = [System.Drawing.Graphics]::FromImage($out)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.Clear([System.Drawing.Color]::Transparent)
$g.DrawImage($img, (New-Object System.Drawing.RectangleF 0, 0, 512, 512), (New-Object System.Drawing.RectangleF ($cx - $lado / 2), ($cy - $lado / 2), $lado, $lado), [System.Drawing.GraphicsUnit]::Pixel)
$out.Save("$HOME\Downloads\mano512.png", [System.Drawing.Imaging.ImageFormat]::Png)
```

Subirla con `upload_image` de Studio (tarda unos segundos en verse) y poner su Id en
`src/juego/cliente/Sustos/Util.luau`: `Util.IMAGEN.Mano = "rbxassetid://<id>"`. En `Sangre.luau`, en lugar de
`mano(grupo)`, un `ImageLabel` que llene `grupo` con esa imagen (sin teñir: ya trae su color), y los marcos solo si no
hay `Mano`. Luego quitar la línea de la mano de "Pendiente" en `miedo.md`.

## Fuera de esta lista

Faltan también, sin texto aquí: `CristalPisa`, `CajaMusica` y `BombillaRevienta` (`miedo.md`) y el fuego grande y el
derrumbe de la Bestia (`bestia.md`). También:

- El disparo de la pistola de bengalas: `BengalasVista.luau` ya lo toca si existe la clave `Bengala` en
  `Config.Sonidos` (hoy no hay y va mudo); al hacerlo, añadir esa clave.
- El motor del coche, el cepo y la llave inglesa, que ahora usan sonidos provisionales (`taller.md`).
- Coger, tirar y abrir la mochila, que de momento no suenan (`mochila.md`).
