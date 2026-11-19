# Pulido en bucle (paso 17)

Pedido por el usuario el 18-11-2026: "pulir todo, absolutamente todo". Un bucle de agentes buscó mejoras, las
construyó, las verificó y las juntó (48, `TASKS.md`, paso 17); después una revisión con varios agentes arregló 5 fallos.

- Hecho en la nube, **sin Studio**: nada de esto se ha visto todavía en el juego. Lune pasa entero.
- Los números nuevos son **a ojo** (están en `Config`).
- Selene no funciona en la nube: pasar `selene src` una vez en Windows antes de probar.
- Atajos de prueba: `game.ServerStorage.Prueba:Fire("Noche")`, `"Ataque"`, `"Bestia"`, etc.;
  `workspace:SetAttribute("TormentaPrueba", true)` y `("NieblaPrueba", true)` de noche.

## Mejoras y qué mirar en Studio

### 17.1 Los bichos ven de frente: sigilo de verdad a su espalda
Ven entero solo delante (65° a cada lado); de lado o por detrás, solo a 12 studs. Si te vieron hace menos de 2 s, te
ven en todas direcciones.
- Golpeador rondando: andando a 20 studs a su espalda no te nota; a menos de 12, sí. De frente, a 70 como antes.
- Que el frente de cada modelo coincida con hacia dónde mira su raíz (también en sus sucesos y en el Trepador en la pared).
- Agachado detrás, aún más difícil (unos 7 studs).

### 17.2 Bichos que no se atascan contra una pared y persecución que se nota
Si un bicho se queda parado yendo a una sala, cambia de sala. Al perseguirte, zumbido que sube, latido seguido y un
golpe suave al empezar (como mucho cada 10 s).
- Tapar con una caja la puerta adonde va: a los 2 s cambia de sala.
- Persecución: zumbido y latido, que se apagan unos 2,5 s después de perderte. Escondido, solo el latido de siempre.
- Con Rendimiento, solo latido y golpe.

### 17.3 Cielo propio de la partida: nubes, estrellas y luna según la noche
Módulo nuevo `CieloVista`: de día nubes grises casi cerradas; de noche, rotas, con luna y estrellas.
- Que la niebla no tape del todo las nubes de noche. Con tormenta se cierra el cielo y se van las estrellas.
- Con Rendimiento, sin nubes y menos estrellas. Que las estrellas no parpadeen al atardecer.
- La escena final del fuego se ve bien con las nubes.

### 17.4 Rayo visible en el cielo, del lado de donde viene el trueno
Con tormenta se ve un rayo quebrado con ramas en el horizonte, del lado del trueno.
- Desde fuera y desde una ventana: que la niebla no lo borre, que no deslumbre ni parezca una mancha.
- Con Rendimiento, solo el tronco del rayo. En las cinemáticas, ninguno.

### 17.5 Depósito de gasoil en la granja para rellenar bidones
Depósito viejo al sur del granero (224, 0, 99) para rellenar bidones; da 1,5 bidones al día.
- Con un bidón vacío junto al grifo: "[R] FILL CAN", chorro unos 4 s y el bidón cae lleno sin hundirse.
- Al acabarse: "It's dry. Come back tomorrow."; al amanecer vuelve a 1,5.
- Con VER MAPA: patas, sangre sin parpadeo, nada tocando granero ni campo. Sale en el mapa del móvil.

### 17.6 Avisos de una línea que no se pisan entre sí
Solo un aviso a la vez; los demás esperan en cola (hasta 3). Si se repite el mismo, dura más.
- Al amanecer, "Dawn…" y luego el de las monedas, los dos legibles.
- E varias veces en una puerta cerrada: sin parpadeo. Al morir, "It got you…" dura sus 5 s.

### 17.7 Lo tirado de la mochila y lo que cae al morir no atraviesa paredes
Lo que se tira con G o cae al morir se para antes de una pared o puerta.
- Tirar una llave contra la puerta del sótano: queda en el pasillo y se coge.
- Morir contra una pared: todo cae de tu lado. Sin nada delante, vuela como antes.

### 17.8 Granja, aserradero y caseta de la torre con fachadas de verdad y su historia
Fachadas como las del pueblo (tablones, tejado, ventanas, puerta) y detalles de su parte de la historia.
- Sin avisos `[Mapa]` ni `[Lugares]` al arrancar; el pueblo igual que antes.
- Pistas 6, 7 y 8 legibles; llaves encima de algo; los agujeros del granero y del aserradero no dejan caer.
- Mirar muebles, sangre arrastrada del granero, hiedra que no tape ventanas.

### 17.9 Atardecer y amanecer que siguen al sol
La luz sigue al sol: sin fogonazo antes de "NIGHT n", rojo apagado al atardecer y amanecer cálido.
- Ajustar `Config.Cielo.Sol.Sale` y `Pone` para que el sol caiga justo en el horizonte.
- Amanecer nublado, gris. Que el brillo (Glare 0,3) no moleste. La escena del fuego igual que antes.

### 17.10 La linterna falla con un bicho cerca (y arreglo del parpadeo de los sustos)
Con un bicho a menos de 22 studs (también tras una pared) tu linterna parpadea a ráfagas. Arreglado que el parpadeo de
los sustos a veces no salía.
- Sustos "Pasillo" y "Susurro": la luz parpadea.
- Bicho tras una pared: ráfagas, más seguidas cuanto más cerca, sin apagones largos.
- El Imitador sin abrirle no hace fallar la luz. La linterna del amigo no falla por tus bichos.

### 17.11 Las cerillas, en la caja fuerte del rico como dice la pista 12
Las cerillas ya no están en la encimera: salen de la caja fuerte del rico, con la última página del diario.
- Abrir la caja con la llave del rico: página, aviso y cerillas (a los pies si la mochila va llena). Solo una vez.
- Prender el porche sin la Bestia encerrada: "She must be locked in the basement first."

### 17.12 Bestia y Acechador no pillan a través de paredes; al perderte, el bicho te busca
Solo pillan si llegan a tocarte sin pared en medio. Al perderte, el bicho mira a los lados y registra 2 salas cercanas.
- Bestia tras una puerta cerrada: no te mata hasta abrirla. Acechador: no pilla a través de la pared de la granja.
- Golpeador: tras perderte, se para, mira a los lados 1,5 s y registra; no empuja paredes.

### 17.13 La meta del día avisa si el generador no aguanta la noche
De día, con el generador bajo y gasolina a mano, la meta pide llenarlo ("The farm has fuel").
- Generador al 30 %: lo pide en el aviso y en el móvil (M); al echar un bidón, vuelve a la llave del sótano.
- Sin gasolina en ningún sitio no lo pide; de noche tampoco.

### 17.14 Flecha del tutorial: a un lado cuando está detrás, márgenes de móvil y Rendimiento
Si el objetivo queda detrás, la flecha va al borde izquierdo o derecho según hacia dónde girar. Cabe en el móvil.
- De espaldas al hacha: flecha a media altura en el lado del giro.
- Emulador 640 × 360: no pisa la tarjeta, los botones ni el joystick. Con Rendimiento, quieta.
- En el lobby, la guía del coche igual.

### 17.15 Con mando, las ventanas abren con un botón ya elegido y B cierra las notas
Coche, tienda, banco, vendedor, nota y Ajustes abren con un botón ya marcado, así A hace algo enseguida.
- Coche del lobby: EMPEZAR marcado (borde hueso, no azul). Tienda: tras comprar pasa al siguiente.
- Nota: CERRAR marcado y B la cierra sin agacharse. Ajustes con R3 vuelve luego a la ventana de antes.
- Que el borde de selección se vea de verdad.

### 17.16 Borde del mundo: el bosque se cierra y no se cae al vacío
Círculo de unos 455 studs alrededor de la casa: el bosque se espesa y una pared invisible para; abierto al sur para el
pueblo.
- Andar al este, norte y oeste: solo troncos y niebla, nunca el borde del suelo.
- Pueblo cerrado tras el cementerio y CasaFinal. Coche de la huida y carretera libres.
- El Acechador llega hasta quien esté pegado a la pared. Fotogramas en móvil (~1.550 piezas más).

### 17.17 Sigilo: quieto no haces ruido, las paredes tapan el oído y la linterna te delata
Quieto casi no se te oye, una pared tapa el ruido, y agachado con la linterna encendida se te ve como de pie.
- Quieto tras una puerta a 5 studs: pasa de largo. Andando tras la pared a 3: no te oye; corriendo a 10, sí.
- Agachado con linterna: te ve como de pie; apagada, a 0,6 de eso. Bajo la mesa, como antes.

### 17.18 El tutorial empieza por la nota del rico y la meta guía el final de la Bestia
Primer paso nuevo: leer la nota de la mesa de la cocina (tutorial de 10 pasos). Tras el tutorial, la meta guía el
final: cruces, plano, reja y esperarla.
- "TUTORIAL 1/10" y la flecha a la nota; al leerla pasa a la mochila.
- Sin tutorial: con la pista 12 y una cruz hecha, "5 left"; luego el plano (pista 9), la reja y "wait for her in the hall".
- Que las frases en español quepan en el móvil.

### 17.19 Lo que cae al morir escondido o no cabe en la mochila queda a mano
Morir o salir escondido deja llaves y mochila en la salida del escondite, no dentro. Lo que no cabe en la mochila cae a
tus pies con aviso.
- Llave en el armario y `Muerte.matar`: cae en la puerta del armario. Igual en la cama.
- Mochila llena en el banco o el vendedor: cae detrás de ti, sin meterse en mostrador ni caja.

### 17.20 Ver morir a un compañero te deja helado
Si ves cómo pillan a un amigo: vista que se cierra, golpe, latido y manos temblando. Tras una pared y cerca, solo
latido y golpe suave.
- Con 2 jugadores, a la vista, tras una pared a menos de 22 y lejos (nada). Escondido o con Rendimiento, nada de esto.

### 17.21 Libreta de pistas en la mochila (compartida) y aviso del plano de la reja
Botón NOTAS en la mochila (o N): libreta con las pistas que ha leído cualquiera del grupo. Al leer la 9, aviso del plano.
- Pasar páginas con flechas o LB/RB; cerrar con CLOSE, B o Escape sin encender linterna ni agacharse.
- Que los 4 botones de abajo de la mochila quepan, también en móvil.
- Con 2 jugadores, el otro recibe el aviso y la ve. Guardar y cargar: siguen ahí.

### 17.22 Con tormenta la luna se tapa y el relámpago solo destella donde se ve el cielo
Con tormenta se apaga la luz de luna de las ventanas; de día ya no es azul. El relámpago apenas se nota en sótano y armario.
- Vestíbulo de día: la ventana alta no da luz azul. De noche con tormenta, el haz de luna se va.
- Que fuera no quede demasiado negro.

### 17.23 Los bichos no golpean desde lejos, no cortan la caza en seco y no desaparecen a la vista
El bicho llega de verdad a la ventana antes de golpear; la caza dura unos segundos de más si te persigue; al irse no se
esfuma mientras lo miras.
- Ventana tapada con cajas: sin golpes desde lejos. Al final de la caza sigue hasta 8 s más.
- Al irse por la ventana rota, mirándolo: espera hasta 10 s. Con "Dia", se va enseguida.

### 17.24 El generador no se apaga de un toque y el bidón vuelve a las manos
Para apagarlo hay que mantener E 1 s. Si al bidón le queda gasolina tras echar, vuelve a las manos.
- Tirar de la cuerda varias veces: no se apaga. El cartel dice que se mantiene.
- Medio bidón al generador o al coche: sigue en las manos; vacío, cae.

### 17.25 Golpeador, Raspador, Trepador e Imitador también suben la escalera del vestíbulo
Golpeador, Raspador e Imitador rondan y persiguen por los dos pisos. El Trepador se queda abajo.
- Con el jugador en la galería: sube recto sin trabarse bajo la barandilla; también el Raspador y el Imitador.
- La Bestia sube y baja como antes. Nada atascado arriba ni en una puerta de la galería.

### 17.26 Llaves, pistola, bengalas y cerillas no se pierden al cargar ni con el amigo que no vuelve
Al cargar, lo de los que aún no han entrado no se quita. Lo del amigo que no vuelve vuelve a su sitio al amanecer.
- Guardar y cargar con otro jugador que lleva la pistola: nada duplicado ni perdido.
- Cargar sin él: la pistola vuelve al baúl del desván. Cerillas fuera del mundo: vuelven delante de la caja fuerte.
- Solo publicado: el servidor con jugadores aún llegando.

### 17.27 Sendas con mojones de la casa a la granja, el aserradero y la torre
Tres sendas de tierra con postes y trapos rojos; cada poste de salida con su dibujo (granero, sierra, torre).
- De día y de noche con linterna: se ven y se siguen hasta cada sitio.
- Sin pinos, rocas ni troncos encima; sin parpadeo con el suelo. Salen en el mapa del móvil.
- Los árboles talables guardados siguen en su sitio.

### 17.28 El viento sopla a rachas, más fuerte con tormenta y sordo dentro de casa
El viento sube y baja con las rachas, más fuerte con tormenta y sordo dentro de casa (casi nada en el sótano).
- Fuera, a la vez que caen las agujas de pino. Al entrar al vestíbulo, sordo en 1-2 s.
- Con tormenta, más fuerte, sin saturar. En el armario, callado como antes.

### 17.29 Los bichos no aparecen ni se esfuman a la vista en el bosque
Aparecen y se van donde nadie los ve; el Acechador sale a un lado o detrás, nunca en un pino o un tejado.
- Con linterna a la ventana atacada: el bicho no aparece en el haz. Al irse, se pierde entre los árboles (como mucho 12 s).
- Acechador: nunca delante ni sobre un tejado. Imitador y Trepador llegan como siempre.

### 17.30 La meta del día pide reparar lo roto y, tras el Trepador, dejar troncos junto a la chimenea
Metas nuevas: "repara la ventana o la puerta rota con un tablón" y, desde la noche del Trepador, troncos junto a la chimenea.
- Ventana rota y saltar al amanecer: lo pide en el aviso y en el móvil; al clavar el tablón cambia.
- Con 2 o más rotas, da el número. Chimenea apagada sin troncos: los pide; de noche no.

### 17.31 El susto al morir de los demás bichos, por fases como el del Golpeador
Acechador, Raspador, Imitador, Bestia y Trepador tienen el susto por fases: quieto mirándote, salto, en tu cara con
sangre, tirón con grito y negro.
- Que la cámara no entre en paredes, suelo ni en la cabeza de la Bestia; queda un poco bajo la boca.
- El del Golpeador, igual que antes.

### 17.32 El flash y el cepo se notan en todos los bichos, no solo en el Golpeador
Con el flash o el cepo, cada bicho chilla y se tapa la cara o forcejea a su manera, sin quedarse congelado.
- Flash al Trepador (suelo y pared), Imitador, Acechador; cepo al Raspador (6 s, sin atravesar el cristal).
- Bajo la mesa del comedor nada atraviesa el tablero. La Bestia igual. Con Rendimiento, quietos y sin temblor.
- Que suenen bien los chillidos.

### 17.33 Noches de niebla cerrada: el bosque se pierde a pocos metros
Tipo de noche nuevo: niebla cerrada, sin estrellas, con los árboles perdidos a 40-60 studs. Con tormenta gana la tormenta.
- `NieblaPrueba`: color ni blanco lechoso ni negro; dentro de casa sin niebla molesta.
- Se levanta al final de la noche. Con Rendimiento, sin niebla baja.

### 17.34 Los bichos solo abren la puerta que cruzan y no ven a través de la pared que tienen delante
Ya no abren puertas por pasar al lado. La puerta principal no se abre desde fuera (la Bestia la revienta). No ven a
través de una pared pegada.
- Golpeador por el pasillo: solo abre las puertas que cruza. El Imitador llama y la puerta sigue cerrada.
- Bestia: revienta la puerta principal, también si la cierras tras entrar corriendo.
- Bicho pegado a la pared del comedor: no te ve al otro lado.

### 17.35 Visión de túnel y color apagado con el pavor y la persecución
Con miedo los bordes se oscurecen y el color se apaga; persiguiéndote, más cerrado, latiendo y casi gris.
- `PavorPrueba` en el cliente; luego con el Golpeador detrás. Que quede bajo los avisos y la mochila, también en móvil.
- Escondido, en cinemáticas o con Rendimiento, nada o casi nada. Captura para el revisor.

### 17.36 Escondites fuera de casa: granja, granero, iglesia y casa abierta del pueblo
Cuatro escondites nuevos fuera; el Acechador espera a unos 28 studs y se va a los 20 s.
- Entrar y salir de cada uno (también confesionario y armario de herramientas), ver por las rendijas.
- Salir antes: carga contra ti. Al salir no quedas dentro de una pared.
- Mirar muebles nuevos de la iglesia y la casa abierta. Sin avisos `[Mapa]`.

### 17.37 Escondido, los golpes y las pisadas se sienten en el armario
En el armario, cada golpe fuerte da un respingo, tiembla y acelera el latido; las pisadas cercanas se notan un poco.
- Armario del salón con "Ataque": golpes en ventana o puerta del cuarto. Con Rendimiento, temblor a la mitad.

### 17.38 La pistola y las bengalas caen al morir y las gastadas vuelven tras la noche de la Bestia
Al morir caen pistola, bengalas, cerillas y llaves (la pila no). Las bengalas gastadas en la noche final vuelven al baúl.
- "Preparar" y morir: todo suelto junto al cuerpo. Otro jugador las coge y dispara.
- Gastar las 3 la noche final: vuelven 3 al desván, sin duplicar. Un día normal, no vuelven.

### 17.39 La meta del final pide pistola y cerillas, y avisa al atraparla
Antes de "esperarla", la meta pide la pistola con alguna bengala y las cerillas. Al cerrar la reja: "She's locked in.
Light the trail on the porch."
- "Preparar" sin pistola: la pide; con ella, pide las cerillas; con todo, "wait for her in the hall".

### 17.40 Avisos de una línea con la tecla de la linterna, el flash y la pistola de bengalas cuando hacen falta
La primera vez que hace falta, un aviso dice qué tecla usar según el aparato (F / L1 / LINTERNA, etc.).
- Al atardecer sin linterna: "Press F…" unos 5 s después, sin pisar el otro aviso. Con mando, L1; en móvil, LINTERNA.
- Flash en la noche 3, pistola al darla. No se repite; nada escondido, muerto ni en cinemáticas.

### 17.41 Moverse o saltar corta el trabajo a medias (ya no te quedas clavado)
Moverse o saltar a mitad de clavar, serrar o montar lo cancela sin gastar nada.
- Clavando un tablón, soltar y volver a pulsar W: el tablón cae y la ventana no cambia. Igual con salto y joystick.
- Llegar con W pulsada y pulsar R sin soltarla: no se corta solo.

### 17.42 El paso de serrar pide coger un tablón y señala los tablones
En el tutorial, tras serrar pide "Coge un tablón." y la flecha pasa al tablón; si sueltas el tronco, lo señala.
- Con 2 jugadores, el tablón que lleva otro no se señala.

### 17.43 El bosque se calla cuando se acerca un bicho (y el rugido del atardecer suena desde el bosque)
Grillos y búhos de noche; se callan cuando un bicho se acerca (110 studs) y vuelven tras irse. El rugido del atardecer
viene de un lado.
- Con "Ataque": silencio antes de que llegue, a veces una rama en su dirección. Con el Imitador sin abrir, sigue sonando.
- Que el rugido no quede demasiado flojo.

### 17.44 Con niebla cerrada los bichos tampoco ven lejos en el bosque
En noches de niebla los bichos ven solo a unos 28 studs fuera; el Acechador acecha a unos 22, como silueta.
- `NieblaPrueba` en el bosque: el Golpeador no te persigue desde 60-70. Con tormenta o sin niebla, como antes.
- Que servidor y cliente coincidan en qué noches hay niebla.

### 17.45 Volver a la partida desde el lobby tras un corte
Si se te cae Roblox en plena partida, en el lobby sale GO BACK para volver. Salir y entrar de noche ya no revive gratis.
- Lobby: `PartidaAbierta = true` a mano en tu Player; cartel arriba sin pisar botones; con ratón, toque y mando.
- Matar a uno de noche y simular su vuelta: entra muerto mirando a los vivos.
- Solo publicado, con dos cuentas: volver de verdad, seguir muerto y que la partida acabe a los 120 s sin el dueño.

### 17.46 El Imitador llama con la voz del amigo que acaba de morir (o de Tom)
Si alguien murió esa noche, el Imitador suele usar su voz. Solo y con la pista 2 leída, a veces "Soy Tom".
- 2 jugadores, matar a uno: el otro oye "Soy <muerto>". Solo sin la pista 2: el aviso de tu propia voz.

### 17.47 Cerrojos del banco del sótano: encerrarse en un cuarto de verdad
Cerrojo nuevo en el banco (2 chatarras). Puesto en una puerta interior, los bichos ya no la abren: la golpean unos 10 s
hasta reventarla.
- "INSTALL BOLT" con R, 3 s con el martillo; se ve en las dos caras y se cierra con clic.
- Encerrado con "Ataque": la golpea varias veces, da tiempo al armario, revienta y el cerrojo sale volando.
- Se guarda al amanecer. La Bestia revienta la puerta del sótano de un golpe.

### 17.48 La cabaña del cazador en el bosque espeso
Cabaña nueva al noroeste, con escondite, trampa, chatarra y algo de miedo (ciervo, sangre), y un camino de cortes en los
árboles desde la senda del aserradero.
- Seguir los 8 cortes desde x ≈ -180. Troncos, cuernos y patio sin cosas flotando ni atravesadas.
- Armario y objetos funcionan. Ningún pino atraviesa la cabaña. Sale en el mapa del móvil.
- De noche da miedo sin brillar y dentro de Moderate. Fluido en móvil (~850 piezas).

## Fallos menores pendientes
Los dejó la revisión; nada rompe una partida.
- `Config.Bestia.PistaCerillas` está dos veces (líneas 555 y 596); hoy valen lo mismo (12). Quitar una.
- El aviso de las cerillas y el de "mochila llena" de la caja fuerte usan el aviso de siempre, no el de la libreta, y
  pueden salir encima del papel de la pista 12 (`Pistas.luau`).
- Al atascarse cazando, el bicho elige sala nueva entre todas: el Trepador puede elegir una de arriba que no alcanza (`Caza.luau`).
- Ningún bicho vuelve a entrar por la puerta principal desde fuera (salvo la Bestia); y si está fuera busca en salas de
  la casa (`Caza.luau`).
- Si la pistola desaparece del mundo, no vuelve nunca (`Llaves.repasar` no la cuenta).
- Una partida reabierta con GO BACK tras caerse el servidor arranca sin el dueño y no espera por él (`Partida.luau`).
- Con mando, el aviso de cargar sale con teclas de teclado; al cambiar de aparato se pierde el "LANZAR" (`CargarVista`).
- `PistasControles` mira el mando con la lógica vieja en vez de `Ui.tipoEntrada()`.
- La libreta de pistas no tiene botón de mando y no marca ningún botón al abrirse (`MochilaUi`).
- El banco de las sendas vigila el depósito en (212, 98), pero está en (224, 99); hoy no hay choque (`tests/bancos/sendas.luau`).
- `docs/sistemas/taller.md`: se perdió el título de la sección "Bancos" (queda un trozo suelto en la línea 16).
- Las líneas viejas del paso 16 en `TASKS.md` sobre la meta tras el tutorial ya no valen (17.18 la arregló).
- La lógica nueva de llegar e irse de los bichos (`Caza.nadieVe`, `llegarA`, `salir`, `perderse`) solo se comprueba
  como texto en Lune, sin ejecutarla.
