# Prompts de imagen de los monstruos (para Tripo)

Pedido por el usuario (03-11-2026): imágenes de referencia de los 6 bichos que ya existen, para pasarlas a 3D con Tripo. Estilo híbrido entre terror realista y mascot horror (la filosofía visual de FNAF, Poppy Playtime y Resident Evil, pero con diseños propios): anatomía semirrealista, siluetas reconocibles, caras inquietantes, texturas realistas, sangre sin pasar de Moderate. Las imágenes las genera Sergio con ChatGPT copiando cada prompt.

- Medidas sacadas de las piezas del código (`src/juego/servidor/<Bicho>.luau`). El jugador mide unos 5 studs.
- Pose neutra en todos: las animaciones son por código (el cuello que se estira del Imitador, los tirones de cabeza del Trepador…).
- El Imitador: el código dice "de la talla de una persona", pero sus bloques miden ~10 studs, a la escala de los demás bichos. El prompt le da proporciones de persona alta; el tamaño se ajusta en Roblox.
- Para Tripo: con la imagen buena, pedir en el mismo chat *"the exact same creature from the back, same pose, same background"* (varias vistas; sobre todo Trepador y Bestia).

---

## 1. Golpeador (noche 1)

**Función:** sale del bosque, aporrea ventanas y puertas hasta romperlas, entra y caza. El flash lo aturde un momento.
**Medidas:** unos **9 studs** de alto encorvado (≈1,8 veces el jugador). Torso de 2,3 de ancho y 3,8 de largo, inclinado unos 23° hacia delante. Brazos de **6,4 studs** con garras que casi rozan el suelo. Piernas de 4,2. Cabeza alargada de 1,3 × 1,8 que le cuelga hacia delante.

```
Full-body 3D character reference image of an original horror creature called "The Knocker". Style: a hybrid of realistic horror and mascot horror — the instantly readable silhouette and unforgettable unsettling face of a mascot-horror character, combined with semi-realistic anatomy and photorealistic textures, like a high-end survival horror video game creature. Not cartoonish, not a generic mutant.

Anatomy and proportions: a gaunt, emaciated humanoid about 1.8 times the height of an adult man, standing on two legs with a strong forward hunch, the torso leaning about 25 degrees forward from the hips. Narrow but bony shoulders, a long thin torso with every rib and the ridge of the spine clearly visible under the skin. Legs are long, thin and slightly darker than the body. The arms are absurdly long and thin — hanging down, the hands reach the ankles, and the clawed fingertips almost scrape the floor. Each hand has three long, thin, dark claws stained with dried blood. The knuckles are swollen, bruised and split open from pounding on doors.

Head and face: a long, narrow, horse-like skull hanging forward and slightly down from the shoulders. Two deep, hollow black eye sockets, asymmetrical (one higher than the other), each with a tiny faint pale glint deep inside. No nose, just two small slits. The lower jaw hangs open, slack and too long, showing uneven, crooked, yellowed teeth on top and bottom. Dried dark blood runs from the corners of the mouth and the chin down onto the chest.

Skin and materials: cold, grey, corpse-like skin (dull grey with darker grey shadows), slightly wet and glossy, with fine wrinkles, pores and faint veins. A long streak of dried dark-maroon blood down the chest. No clothing, no hair.

Pose and presentation: neutral standing pose for 3D rigging, hunched posture preserved, arms hanging slightly away from the body so they don't touch the torso or legs, legs slightly apart, fingers and claws clearly separated. Three-quarter front view. The entire body visible from the top of the head to the feet, centered with margin around it. Plain seamless neutral light-grey background, soft even studio lighting, no harsh shadows, sharp focus, clean readable shapes. Single creature only, no props, no scenery, no floor details, no text, no watermark, no logo, no frame, no motion blur.
```

---

## 2. Raspador (noche 3)

**Función:** se pega al cristal de una ventana y lo raspa despacio con los dedos hasta romperlo. No soporta la luz: con la linterna raspa más lento y con el flash chilla y huye.
**Medidas:** unos **8,5-9 studs** (≈1,7 veces el jugador). Es el más flaco: torso de 1,7 × 0,9. El cuello (1,6) va estirado hacia delante. Brazos con codo (2,8 + 2,8) y **dedos de aguja de 1,6** que le llegan a los pies, cuatro por mano. Piernas muy finas de 4.

```
Full-body 3D character reference image of an original horror creature called "The Scraper". Style: a hybrid of realistic horror and mascot horror — the instantly readable silhouette and unforgettable unsettling face of a mascot-horror character, combined with semi-realistic anatomy and photorealistic textures, like a high-end survival horror video game creature. Not cartoonish, not a generic mutant.

Anatomy and proportions: an extremely tall, skeletal humanoid about 1.7 times the height of an adult man, so thin it looks like skin stretched over bones. A very narrow, shallow torso leaning slightly forward, with a few thin ribs and one thick dark vein running down the chest. A long thin neck that juts forward at an angle, pushing the head out in front of the body. Very thin, long legs. The arms are extremely long with clear elbows: upper arm and forearm are equally long, and with the fingers the arms reach all the way down to the feet. Each hand has four needle-like fingers, as long as a forearm is thick times five, perfectly straight and thin like knitting needles, with dark dried-blood stains on the tips and broken nails.

Head and face: a smooth, bald, slightly elongated head with NO eyes — only two shallow sunken depressions of darker skin where the eyes should be. A wide slit of a mouth stretching from ear to ear, slightly parted, pitch black inside, lined with many thin, needle-like pale teeth. A thin trickle of dried blood from one corner of the mouth down the chin.

Skin and materials: pale, sickly yellowish-white skin like something that never sees the sun, slightly translucent, with bluish-grey veins visible underneath, a waxy and slightly damp surface, fine wrinkles at the joints. No clothing, no hair.

Pose and presentation: neutral standing pose for 3D rigging, forward-jutting neck preserved, arms hanging slightly away from the body with elbows slightly bent, all four needle fingers on each hand spread apart and clearly separated, legs slightly apart. Three-quarter front view. The entire body visible from the top of the head to the feet, centered with margin around it. Plain seamless neutral light-grey background, soft even studio lighting, no harsh shadows, sharp focus, clean readable shapes. Single creature only, no props, no scenery, no text, no watermark, no logo, no frame, no motion blur.
```

---

## 3. Trepador (noche 7)

**Función:** trepa por la pared, ronda por el tejado (se oyen los pasos desde dentro), baja por la chimenea y sale al salón por el hogar. El fuego lo echa.
**Medidas:** a cuatro patas, como una araña. Cuerpo tumbado de **4,4 de largo** × 1,9 de ancho, con la tripa a unos 1,7 del suelo. Cada pata tiene un tramo de arriba de 3, que sube hacia fuera, y uno de abajo de 4,5, que baja al suelo: **codos y rodillas a ~4,3 studs**, por encima de la espalda. Mide unos 6 de largo con la cabeza y unos 8 de ancho entre patas. Lleva la cabeza (1,2 × 1,3 × 1,4) **del revés**, con la boca arriba.

```
Full-body 3D character reference image of an original horror creature called "The Climber". Style: a hybrid of realistic horror and mascot horror — the instantly readable silhouette and unforgettable unsettling face of a mascot-horror character, combined with semi-realistic anatomy and photorealistic textures, like a high-end survival horror video game creature. Not cartoonish, not a generic mutant.

Anatomy and proportions: a human-derived creature moving on all fours like a giant spider. The torso is horizontal and low, long and narrow (more than twice as long as it is wide), the belly hovering about knee height of a man above the ground. Four long, thin limbs: from each shoulder and hip, the upper segment rises upward and outward at 45 degrees, so the elbows and knees stick up high above the back like a spider's leg joints, and the lower segment (longer than the upper one) comes straight down to the ground. Wide spider-like stance, legs spread far to the sides. At the end of each limb, long thin spread fingers or toes, blackened with soot and dried blood.

Back: the skin of the back is torn open along the spine, exposing a row of pale ribs and the knobbed vertebrae of the spine, with dark raw flesh between them. Graphic but not excessive.

Head and face: a human-like head attached to the front of the torso UPSIDE DOWN — the chin points to the sky and the top of the skull points to the ground, so the mouth is on top and the eyes are below it. Wide-open lidless eyes, dark with tiny pale pupils, staring. A wide mouth (now on top) with a row of small pale teeth and a drip of dried blood. No hair, no ears visible.

Skin and materials: pale, flayed-looking pinkish-beige skin, raw and slightly glossy, peeling in places, with dark maroon flesh showing at the tears. Hands, feet and lower limbs dirtied with black soot from chimneys. No clothing.

Pose and presentation: neutral standing spider stance on all four limbs for 3D rigging, symmetrical, all four limbs clearly separated from each other and from the body, fingers spread. Three-quarter front view from slightly above, so the upside-down face, the open back and all four legs are clearly visible. The entire creature visible, centered with margin around it. Plain seamless neutral light-grey background, soft even studio lighting, no harsh shadows, sharp focus, clean readable shapes. Single creature only, no props, no scenery, no text, no watermark, no logo, no frame, no motion blur.
```

---

## 4. Imitador (noche 10)

**Función:** llama a la puerta principal con la voz de un amigo. De lejos y a oscuras parece una persona. Si le abren, se le estira el cuello, abre la boca y entra a cazar. Anda tieso, sin mover los brazos.
**Medidas:** unos **10 studs** con proporciones de persona alta (≈7,5 cabezas). Piernas de 4,4, torso de 3, cuello de 0,8 y cabeza de 1,15 × 1,3. Brazos algo largos (3,8 + dedos de 0,8) que le llegan a mitad del muslo. Abrigo oscuro hasta arriba del muslo.

```
Full-body 3D character reference image of an original horror creature called "The Mimic". Style: a hybrid of realistic horror and mascot horror — the instantly readable silhouette and unforgettable unsettling face of a mascot-horror character, combined with semi-realistic anatomy and photorealistic textures, like a high-end survival horror video game creature. Not cartoonish, not a generic mutant.

Concept: something pretending to be a person. From far away it reads as a normal tall man; up close everything is slightly wrong, like a mannequin wearing human skin.

Anatomy and proportions: a tall, slender humanoid with almost-human proportions (about 7.5 heads tall), standing perfectly straight and stiff, too symmetrical. Shoulders a little too wide and square. The arms are slightly too long: the hands hang down to mid-thigh. The hands are grey and waxy with long, thin fingers, a bit too many joints visible. Straight, stiff legs in dark trousers.

Clothing: a plain dark charcoal-grey coat, buttoned, ending at the upper thigh so the legs stay fully visible, simple shapes without loose flaps, belts or pockets that hang. A dark maroon bloodstain on the chest of the coat that clearly isn't his. Dark trousers and plain dark shoes.

Head and face: a normal-sized human head with short, flat, dark hair like a wig glued on. Waxy, pale greyish skin with a slight sheen, too smooth, no pores, like a mannequin. Small black eyes like beads, set too far apart. The signature feature: a smile far too wide, stretching from ear to ear, lips pulled thin, with a long row of small, tightly clenched, yellow-white teeth all visible. A thin line of dried blood from one corner of the mouth down the chin. The face is frozen in that friendly-neighbor expression.

Pose and presentation: neutral A-pose for 3D rigging, standing stiffly upright, arms held slightly away from the body, fingers separated, legs slightly apart. Three-quarter front view. The entire body visible from the top of the head to the feet, centered with margin around it. Plain seamless neutral light-grey background, soft even studio lighting, no harsh shadows, sharp focus, clean readable shapes. Single creature only, no props, no scenery, no text, no watermark, no logo, no frame, no motion blur.
```

---

## 5. Acechador (cada noche, en el bosque)

**Función:** a quien se queda fuera al anochecer lo sigue entre los árboles partiendo ramas. Si lo miras se queda quieto como un tronco, y luego se te echa encima corriendo más que tú. Con la linterna se encoge y se tapa la cara.
**Medidas:** el más alto: **unos 14 studs** con las ramas (≈2,8 veces el jugador). Muy flaco: torso de 1,6 × 0,9 y 4,5 de largo, un poco encorvado. Piernas de **6,6**, brazos de **7** hasta las rodillas con dedos de ramita de 1,4. Cabeza de 1 × 1,8 con ramas en forma de cuernos de hasta 2,4.

```
Full-body 3D character reference image of an original horror creature called "The Stalker". Style: a hybrid of realistic horror and mascot horror — the instantly readable silhouette and unforgettable unsettling face of a mascot-horror character, combined with semi-realistic anatomy and photorealistic textures, like a high-end survival horror video game creature. Not cartoonish, not a generic mutant.

Concept: a forest creature that can stand perfectly still and pass for a dead tree trunk.

Anatomy and proportions: an extremely tall and extremely thin humanoid, almost three times the height of an adult man, with very elongated limbs. Slightly hunched forward at the upper back. The torso is narrow and flat. The legs are very long and thin, almost half of the total height. The arms are very long and thin, hanging down to the knees, ending in three long, thin, twig-like fingers per hand, slightly spread and knotted like small branches.

Chest: a long vertical split in the bark of the chest, like a wound in a tree, showing dark red raw flesh and a few pale ribs inside, with a thin trickle of dried blood running down from it.

Head and face: a long narrow head made of dark wet bark, with two pairs of twisted branches growing out of the top of the skull like antlers, spreading up and outward, each with a few small side twigs (the branches are about as tall as the head itself). Two tiny pale glinting points for eyes. No nose. The mouth is a single VERTICAL crack running down the middle of the face, like a split in a tree trunk, dark inside, with a drip of dried blood from it.

Skin and materials: the whole body is covered in dark, damp, rough bark texture (dark brown-grey, almost black in the cracks), with a wet sheen, fine moss in a few crevices, and human anatomy (knees, elbows, collarbones) still recognizable under the bark. No clothing, no leaves.

Pose and presentation: neutral standing pose for 3D rigging, slight hunch preserved, arms hanging slightly away from the body so they don't touch the legs, twig fingers clearly separated, legs slightly apart. Three-quarter front view. The entire body visible from the tips of the branches to the feet, centered with margin around it. Plain seamless neutral light-grey background, soft even studio lighting, no harsh shadows, sharp focus, clean readable shapes. Single creature only, no props, no scenery, no trees, no ground details, no text, no watermark, no logo, no frame, no motion blur.
```

---

## 6. La Bestia (final difícil)

**Función:** el origen de todos los bichos; el rico la alimenta con gente. Revienta la puerta, corre más que el jugador y huele a quien no está escondido. Se la hiere con bengalas, se la encierra en el sótano y se la quema con la casa.
**Medidas:** enorme y a cuatro patas, como un gorila que anda sobre los nudillos. **Hombros a ~8,5 studs**, unos 10 de largo con la cabeza y ~6,5 de ancho. Lomo de 4,4 × 3 × 6,2, más alto delante, con joroba. Brazos de delante de **6,8**, gruesos y más largos que las piernas de atrás (4,5, dobladas). Cabeza baja de 2,2 × 1,8 × 2,8 delante del pecho, con **seis ojos** y colmillos.

```
Full-body 3D character reference image of an original horror creature called "The Beast", the monstrous origin of all the other creatures. Style: a hybrid of realistic horror and mascot horror — the instantly readable silhouette and unforgettable unsettling face of a mascot-horror character, combined with semi-realistic anatomy and photorealistic textures, like a high-end survival horror video game boss. Not cartoonish, not a generic mutant.

Anatomy and proportions: a massive, heavy quadruped built like a giant gorilla, walking on its knuckles. The shoulders are huge and tall (about 1.7 times the height of an adult man), with a big muscular hump between them, and the long back slopes down toward lower hips. The front arms are extremely long and thick, longer than the hind legs, with massive shoulders and heavy elbows; it leans on its knuckles, and each huge hand has four enormous curved dark claws. The hind legs are shorter, bent, with very thick thighs and wide flat feet. A row of pale yellowish bone spikes pokes out along the spine, larger on the hump. Ribs are visible along both flanks, and on one side the skin is torn open between the ribs showing raw red flesh.

Head and face: a low, elongated, heavy head hanging in front of the chest, below the shoulder line. No nose: a smooth flat face under a heavy bulging brow. SIX small eyes sunken under the brow, arranged irregularly, each a black hole with a tiny pale glint. An enormous wide mouth, slightly open, dark red-black inside, filled with long crooked yellowed teeth on top and bottom, and two large tusks sticking out from the sides of the mouth past the lips. Long strands of dark blood and drool hanging from the lower jaw.

Skin and materials: very dark grey, almost black skin, stretched tight over the muscles, leathery with deep wrinkles, old scars and a few open wounds. The chest, belly and front of the forearms are stained with dried and fresh dark-maroon blood from what it has eaten, with drips running down. Yellowed bone on the spikes and tusks. No fur, no clothing, no chains.

Pose and presentation: neutral standing pose on all fours for 3D rigging, symmetrical, weight on the knuckles and hind feet, all four limbs clearly separated from each other and from the body, claws separated. Three-quarter front view from slightly above, so the head, the six eyes, the hump and all four limbs are clearly visible. The entire creature visible, centered with margin around it. Plain seamless neutral light-grey background, soft even studio lighting, no harsh shadows, sharp focus, clean readable shapes. Single creature only, no props, no scenery, no text, no watermark, no logo, no frame, no motion blur.
```
