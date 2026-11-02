# La Bestia: el final difícil (12.2)

Pedido por el usuario: la Bestia es el origen de todos los bichos, y el rico la alimenta con gente. Se la mata dentro de la casa: herirla con bengalas, llevarla al sótano, encerrarla con la reja y quemar la casa empapada de gasolina. Al morir ella caen todos. Números en `Config.Bestia` (a ojo).

## Módulos

- `Preparativos` (servidor) y `PreparativosVista` (cliente): gasolina, reja, palanca, trampilla, "Wait for her" y guardado.
- `Bestia` y `BestiaVista`: el bicho. Usa `Caza` como los demás.
- `Bengalas` y `BengalasVista`: la pistola del rico.
- `Incendio` y `IncendioVista`: el fuego, la escena final y el premio (`Recompensas.finalBestia`).

## Preparación (de día)

1. **Gasolina:** hay 6 cruces en el suelo (escalera del vestíbulo, salón, dormitorio de abajo, pasillo, cocina y dormitorio grande). Con un bidón en las manos, R junto a la cruz. Cada cruz gasta 1/3 de bidón. Si le queda para otra cruz, el bidón sigue en las manos; vacío, se deja en el suelo (14.1, pedido por el usuario). Con las 6 llenas sale un rastro de la escalera al porche.
2. **Reja:** se hace en el banco del sótano con 4 chatarras y 2 cadenas. La receta solo sale después de leer la pista 9, que está en el sótano (hace falta su llave). Se lleva con R a su marco, al pie de la escalera del sótano.
3. **Pistola y bengalas:** la pistola y 3 bengalas están en el desván, delante del baúl del rico. Las cerillas, en la encimera de la cocina.
4. **Trampilla:** del sótano al patio. Se abre desde abajo y se queda abierta.

Lo preparado se guarda con la partida. Si mueren todos, se vuelve al amanecer: lo hecho ese día se pierde. Excepción (14.1, pedido por el usuario): al pulsar "Wait for her" se hace la foto de la partida y se guarda, así que morir esa noche vuelve a ese momento (de día, con todo preparado y las mochilas de entonces).

## Noche final

- **Empezar:** "Wait for her" en el vestíbulo, de día y con todo listo. Se hace de noche y no sale ningún otro bicho. A los 6 s ella sale del bosque delante de la puerta principal, ruge, revienta la puerta y entra. Al pulsar "Wait for her" la puerta principal se cierra de golpe (y queda entera), para que siempre la reviente (14.1, pedido por el usuario).
- **Cómo caza:** corre a 19 (el jugador, a 16) y pilla a 5 studs. Persigue a quien ve. Sin verle, huele a quien no esté escondido a menos de 25 studs en su planta (16 de alto si te vio hace menos de 6 s). Arriba de la escalera del sótano o dentro huele a 40 a quien esté abajo, para que se la pueda meter aunque cojee (14.1). Si lleva 2 s sin avanzar, cambia de destino y deja de oler 4 s. Ronda las dos plantas.
- **Escaleras (14.1, pedido por el usuario: arriba estabas a salvo):** PathfindingService no sube la escalera del vestíbulo, así que `ir()` la lleva al pie (o a lo alto) y la sube recta por el medio, con un empujón de un peldaño si se atasca (un rayo comprueba antes que no haya pared, puerta ni reja). La escalera del sótano también se baja y se sube recta y centrada (con los caminos se quedaba ladeada contra el marco).
- **Trampilla:** no pasa por ella (no trepa). Si a quien busca se le va por la trampilla, se queda debajo 8 s arañando hacia arriba (`Aranar`, `BestiaVista` "Arana") y luego le busca por la escalera; en 15 s no vuelve a la trampilla.
- **Bengala:** se queda quieta 0,6 s y cojea 8 s a velocidad 7. El flash de la cámara no la para.
- **Palanca:** fuera, en un poste del patio al oeste de la trampilla, con un tubo de hierro que baja por el hueco (14.1, pedido por el usuario: dentro te pillaba mientras tirabas). Se mete a la Bestia en el sótano, se sube por la escalera de mano y se tira al salir; desde abajo no llega. Si ella ya está dentro del sótano, la reja cae y la deja atrapada. Si no, aviso de que la reja ha caído sin nada detrás, y la reja vuelve a subir al amanecer.
- **Atrapada:** no sale. Golpea la reja si ve a alguien fuera cerca y solo pilla a quien esté dentro con ella.
- **Incendio:** "Light" en el porche (2 s con cerillas) con ella atrapada. El fuego sale del porche, pasa por las cruces en orden, uno cada 1,6 s, y acaba en el sótano. Ella chilla y desaparece, y caen todos los bichos.
- **Premio:** escena final de 20 s sin interfaz y premio: 600 monedas del final más 500 del logro de la Bestia, que solo se da la primera vez (prueba de Lune). La insignia sale de `Config.Insignias.Bestia`, que vale 0 hasta publicar. Después, vuelta al lobby (en Studio no hay teletransporte).

## Probado en Studio (02-11-2026)

- **Prueba de punta a punta:**
  - Echar gasolina en las 6 cruces con bidones de verdad.
  - Abrir el sótano con su llave, leer la pista 9 y hacer la reja en el banco.
  - Montar la reja.
  - Coger del desván la pistola y las 3 bengalas, y de la cocina las cerillas.
  - "Wait for her".
  - Bengala que le da y la hace cojear.
  - Llevarla al sótano y bajar la reja: queda atrapada.
  - "Light" desde el porche, fuego, escena final, +1.100 monedas y la interfaz vuelve.
- **Arreglado al probar:**
  - La pieza "Torso" de la Bestia: Roblox la hace chocar siempre y no cabía por la puerta del sótano. Ahora se llama "Lomo".
  - Calculaba los caminos con altura 8 y la escalera del sótano no cabía, así que daba la vuelta por la trampilla. Ahora usa altura 7 (`AltoCamino`).
  - Se quedaba empujando la escalera del vestíbulo cuando rondaba hacia una sala de arriba.
  - Se volvía al llegar a donde te vio por última vez. Ahora huele (`Olfato`).
- **Órdenes de prueba** (`ServerStorage.Prueba:Fire(...)`, solo en Studio):
  - "Esperar": es "Wait for her" sin ir al vestíbulo (14.1).
  - "Preparar": lo deja todo listo.
  - "Abrir": quita la llave a las salas cerradas.
  - "Trampilla": la abre.
  - "Bestia": la suelta.
  - "Bengala": la hiere.
  - "Palanca": deja caer la reja.
  - "Quemar": prende el fuego.

- **Incendio grande (14.1, pedido por el usuario: "el fuego se ve pequeño"):** en `IncendioVista`, desde cada punto que arde el fuego se come la casa entera: revientan las ventanas con lenguas de fuego, arde el tejado (rejilla de hogueras), suben columnas de humo muy altas y luces naranjas iluminan el patio y el bosque. En la escena cae una viga y se hunde el tejado de delante con una llamarada. `ArdeCasa` s de casa ardiendo antes de la escena. Con el atributo `Rendimiento` del jugador (14.4), la mitad de partículas.
  - Faltan sonidos propios: un rugido de incendio grande (ahora "Fuego" de la chimenea en cuatro sitios) y un derrumbe de tejado (ahora "Caida", el del árbol).

## Probado en Studio (14.1, 02-11-2026)

- Bidón en dos cruces seguidas sin soltarlo. "Wait for her" cierra la puerta principal abierta. Morir esa noche vuelve al día con las 6 cruces, la reja montada, la trampilla abierta y la pistola con 3 bengalas.
- Sube la escalera del vestíbulo y caza arriba (unos 4 s en la escalera).
- Bengala en el pasillo, bajar al sótano: te sigue cojeando (6-7 s), sales por la trampilla, tiras de la palanca desde el patio y queda atrapada. "Light" en el porche, escena final, +1.100 monedas y vuelve la cámara.
- Sin ver a nadie en el sótano no baja: hay que dejarse ver.
