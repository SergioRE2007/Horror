# Correr y aguante (14.8)

Pedido por el usuario (04-11-2026): "añadir la mecánica de correr, que tengas una stamina abajo del todo, una barra
fina así minimalista que aparezca al correr", y que se note ("todo animado e inmersivo"). Hecho sin Studio: todo
comprobado con Lune (reglas, cuentas y bancos que cargan los módulos de verdad), nada visto en el juego.

## Controles

- PC: mantener **Shift izquierdo**. Escribiendo en el chat no cuenta; al soltar y al perder el foco de la ventana se
  suelta siempre. Shift no activa el Shift Lock (`StarterPlayer.EnableMouseLockOption` y `DevEnableMouseLock` a
  false, en `Correr`).
- Mando: **L3** alterna. Móvil: botón **CORRER** en `Hud.EquipoBotones` (`LayoutOrder` 7, junto a AGACHARSE; la
  rejilla pasa a 4 × 2), que alterna: con el pulgar en la palanca, mantener cansa. Lo alternado se apaga solo al
  pararte 0,8 s (2,5 s si aún no habías corrido), al agotarte, al morir, esconderte o reaparecer. El botón va en rojo
  con borde claro mientras corres o lo tienes puesto, y apagado si ahora no se puede.
- Solo se corre moviéndose hacia delante (`Config.Correr.Moverse`, `Delante`): ni de lado ni hacia atrás.
- No se corre agachado, cargando algo pesado, con la mochila abierta, trabajando, escondido, por la mirilla o las
  cortinas, asomado ni en cinemáticas. Pedir correr agachado te levanta si cabes (`PosturaVista.levantarse`); si no,
  lo pedido se guarda y corres en cuanto puedas.

## Reglas (`shared/CorrerReglas`, números en `Config.Correr`)

- 16 → 24 (×1,5; la clase Corredor, 19,2 → 28,8). Lleno dura 6,5 s seguidos. Sin correr, tras 1 s vuelve: 5 s de
  vacío a lleno quieto o agachado, 12 s andando.
- Agotado del todo: no vuelves a correr hasta tener un tercio, frenas 1,2 s a 0,6 y jadeas; una de cada ~3 veces,
  tropiezas (la cámara cae y te recuperas).
- Corriendo, los bichos que cazan con `Caza` (Golpeador, Raspador, Trepador, Imitador y Bestia) te oyen a 22 studs en
  vez de 8 (`PosturaReglas.alcanceOido`, también a través de paredes): correr hace ruido, riesgo y premio.
- Pruebas en `tests/regressions.luau` (bloque "Correr y aguante").

## Servidor (`juego/servidor/Correr`): manda

- El cliente solo dice sí/no con el remote `Correr`. Lo que no sea booleano se tira; más de 30 por segundo, también
  (salvo `false`: que una ráfaga no deje a nadie corriendo); las muy seguidas se juntan en `pendiente`.
- Un Heartbeat para todos con la velocidad plana de la raíz y lo que va hacia delante (la raíz mira donde la cámara).
  Quien está en reposo no cuesta nada.
- Atributos del Player (solo al cambiar): `Corriendo` (true/nil), `Aguante` (0..1 a 0,01, como mucho cada 0,1 s),
  `Agotado`, `Frena` (true/nil) y `Tropiezo` (contador; no existe hasta el primero). `Andar` lo pone
  `Cargar.ajustarVelocidad`: la velocidad sin correr (clase, agachado, cargas, mochila y `Frena`).
- La velocidad sigue saliendo de un solo sitio: `Cargar.ajustarVelocidad`, `WalkSpeed = CorrerReglas.velocidad(Andar,
  Corriendo y nada que frene)`. Al reaparecer, descansado.
- Seguridad: el cliente no dice ni su aguante ni su velocidad. La mirilla y las cinemáticas solo las sabe su cliente:
  un tramposo podría correr ahí, pero solo se perjudica a sí mismo.

## Cliente (`CorrerVista`): predice para que vaya al momento

- Cada fotograma, las mismas cuentas (`CorrerReglas.paso`) con tus datos; manda el remote solo al cambiar lo que
  quieres. Se acerca al `Aguante` del servidor si se separa (más de 0,03 más el ping); si el servidor se agota, tú
  también. Al reaparecer ignora 0,5 s el `Aguante` viejo.
- Corres de verdad = lo predicho y (el servidor lo confirma o hace menos de `Config.Correr.Gracia` s que empezaste).
  La única que pone `WalkSpeed` en el cliente: `CorrerReglas.velocidad(Andar, corres)`.
- API para los demás módulos: `corriendo`, `ritmo` (0..1 suavizado), `aguante`, `agotado`, `cansancio`, `tropiezo`
  (s desde tu último tropiezo, 1,6 s), `recien`, `jadear(padre, fuerza)`, `alAgotarse(fn)`.
- Sonidos: al agotarte, un jadeo fuerte solo para ti y luego resoplidos más flojos y espaciados hasta recuperar tres
  cuartos (escondido, debajo de un mueble, muerto o en la escena de un final, no). De los demás a menos de 60 studs,
  un jadeo 3D al agotarse.
  `Config.Sonidos.Jadeo` tiene Id 0: mientras, el provisional `Config.Correr.Jadeo` (VientoTiro a tono 1,6).

## La barra (`CorrerBarra`)

- 4 px de diseño, un tercio del ancho, centrada abajo y bajo el `UIScale` del Hud (`Hud.Aguante`, la raya es
  `Hud.Aguante.Fondo` y el relleno `Fondo.Lleno`). PC: a 7 px del borde (el cartel de la pila acaba a 18). Móvil: a
  `Ui.zonaSegura()` + 6, debajo de la rejilla, que también sube lo que tape el teléfono abajo.
- Blanco hueso con los extremos gastados sobre negro casi transparente, sin texto; se vacía hacia el centro. Aparece
  en 0,25 s al correr o sin llenar, se va 1,5 s después de llenarse; rojo oscuro con menos de 0,25; agotada late
  (1,4 por segundo, engorda y el fondo se tiñe). Fuera escondido, muerto, por la mirilla y en cinemáticas.
- La cuenta de cada fotograma es pura (`CorrerBarra.cuadro`/`pintura`) y lo de Roblox (`nueva`/`mover`) solo escribe
  lo que cambia.

## Que se note

- Cámara (`CuerpoVista`, todo mezclado con `ritmo`): balanceo mayor y zancada de 6,2 (la misma en Pasos y Manos), +7
  grados de campo de visión desde 20 studs/s, sacudida al frenar en seco, respiración y vaho de noche según el
  cansancio, y el tropiezo (cae en 0,2 s, 16 grados abajo y 7 de lado, vuelve en 1,4 s; limitado con `MuebleRayo`
  para no meterse en paredes ni muebles). El campo de visión se suma y se quita sin pisar el de la mirilla ni la
  mochila.
- Tus manos (`Manos`, `ManosGestos`, cuentas en `ManosCorrer`): capa "Correr" (prioridad 3) con las manos libres
  braceando (el puño asoma abajo a ratos) y capa "Tropiezo" (6) que las adelanta para frenar la caída. Lo que llevas
  va de lado y baja en cada pisada y tiembla; agotado, sube y baja con la respiración. La luz de la linterna va ahora
  en `Camera + 6`, justo después de las manos, y no sale detrás de lo que choca delante.
- Los demás (`BrazosVista`): tronco 13 grados hacia delante y braceo de su animación aumentado; tropiezo, cabeceo
  del tronco; agotado, encorvado y hombros que jadean.
- Pasos: zancada 6,2, más fuertes (×1,4) y con más azar de tono; al tropezar, pisotón y arrastre.
- Escondido justo después de correr (`MuerteVista`): jadeas más, la cámara del escondite se mece más, contener el aire
  dura `max(4, 12 × (1 − 0,6 × sofoco))` s y, muy sofocado con un bicho cerca, a veces se escapa un jadeo (respingo,
  bordes y latido). Solo para ti: el servidor no lo sabe.
- Con Rendimiento: sin campo de visión, balanceo extra, frenazo, braceo ni temblor; el tropiezo sí (más corto).

## Tutorial

Paso nuevo 3 "Correr al bosque" (entre coger el hacha y talar; ahora 9 pasos): se acaba al correr un momento (el
servidor mira `Corriendo`); se salta si ya habías corrido o llevas un tronco. Frase por dispositivo (Shift, L3,
CORRER) y "correr hace ruido"; en el móvil la flecha va también al botón CORRER (`docs/sistemas/tutorial.md`).

## Equilibrio con los bichos (`tests/bancos/correr-cuentas.luau`)

En línea recta a 60 Hz (en la casa, las esquinas cambian mucho las cosas):
- Media sostenida: andar 16; Shift pisado todo el rato 17,4; el mejor ciclo 18,7 (Corredor 22,4). Con `Andando` a
  1/10 el mejor ciclo daba 18,98, casi lo de la Bestia (19): por eso 1/12.
- Correr agranda el hueco contra todos en la primera carrera (+32 contra la Bestia, +19 contra el Acechador).
- Golpeador (17): andando te pilla; corriendo, se cansa antes. Bestia (19): corriendo aguantas más; coja tras una
  bengala, escapas.
- Acechador (21) desde su carga a 32: andando te pilla a los 5 s (80 studs); corriendo bien, a los 21 s (420 studs).
  Andando llegas a la luz solo desde menos de 128 del centro de la casa; corriendo, desde la granja, el aserradero o
  la torre; desde el pueblo, ni corriendo. Desde 36, el mejor ciclo aguanta sus 22 s (`Persigue`) y se cansa.
- La clase Corredor sí deja atrás a todos con un buen ciclo (22,4 contra 21): a mirar.

## Bancos de Lune

- `tests/bancos/_roblox.luau`: un Roblox de mentira (instancias con señales, servicios, reloj y tareas falsos, rayos
  contra cajas con `CanQuery`, personaje R15 que anda y choca, pantalla y zona segura, remotes) para cargar módulos
  de verdad; su propio banco es `roblox-falso.luau`. Uso, en la cabecera del archivo.
- `correr-barra.luau`: `CorrerVista` y `CorrerBarra` de verdad con un servidor de mentira que publica con 0,1 s de
  retraso: la barra fotograma a fotograma, la velocidad local y los controles.
- `correr-camara.luau`: `CuerpoVista` y `Pasos` de verdad (muebles con `CanQuery = false`): sin NaN, nunca a menos de
  1 stud del suelo ni dentro de paredes o muebles, y todo vuelve al reposo (campo de visión 70 justo).
- `correr-manos.luau`: `Manos`, `ManosGestos`, `ManosCorrer` y `EquipoVista` de verdad: sin NaN, ni dentro de la
  cámara ni saltos, y la luz sale de la punta de la linterna.
- `correr-cuentas.luau`: las cuentas de arriba. Todos los lanza `lune run tests/regressions.luau`.

## Probar en Studio

Antes: en Edit, que Rojo ha sincronizado (`game.ServerScriptService:FindFirstChild("Correr", true)` existe y el
`Source` de `CorrerVista` contiene `REAPARECE`). Errores: `LogService:GetLogHistory()` sin los `MessageOutput`.
1. **PC** (Play, Client): W + Shift izquierdo. `game.Players.LocalPlayer.Character.Humanoid.WalkSpeed` = 24 al momento
   y el atributo `Corriendo` true; la barra sale abajo, baja y pasa a rojo con poco. A los ~6,5 s: jadeo (provisional),
   la barra late, frenas (9,6 durante 1,2 s en Server) y resoplidos; al llenarse se va ~1,5 s después. Shift no bloquea
   el ratón (Shift Lock). Alt+Tab corriendo para de correr; Shift escribiendo en el chat, no corre. Andar hacia atrás o
   de lado con Shift, no corre.
2. **Server**: `local p = game.Players:GetPlayers()[1]; print(p:GetAttribute("Aguante"), p:GetAttribute("Andar"),
   p.Character.Humanoid.WalkSpeed, p.DevEnableMouseLock)` → `1 16 16 false` (Corredor, `Andar` 19,2). No corre
   agachado (C y luego Shift: te levanta y corre), con un tronco, con la mochila abierta ni escondido.
   Inundación desde Client: `for i = 1, 500 do game.ReplicatedStorage.Remotes.Correr:FireServer(i % 2 == 0) end`, y
   `FireServer("x")`, `FireServer(nil)`, `FireServer(0/0)`: sin errores ni tirones, y al acabar no sigue corriendo.
3. **Cámara**: corriendo, cabeza que sube y baja más y `workspace.CurrentCamera.FieldOfView` ~77; parado, 70 justo.
   Soltar todo de golpe: cabeceo corto; soltar solo Shift andando: nada. Tropiezo a mano (Server):
   `p:SetAttribute("Tropiezo", (p:GetAttribute("Tropiezo") or 0) + 1)`: la vista cae y vuelve en ~1,4 s, con pisotón.
   Repetirlo pegado (PivotTo a 0,6 studs) a una pared de la casa mirándola y junto a la mesa del comedor: captura a los
   0,25 s (`task.delay`), la cámara no ve a través. Correr hacia la mirilla y pulsar E sin soltar Shift: al salir, 70.
   Lo mismo abriendo la mochila corriendo.
4. **Manos y linterna**: corriendo con las manos vacías, a ratos asoma un puño abajo, alternando, al ritmo de los
   pasos. Con la linterna (F): la otra mano bracea menos, la linterna va de lado y baja en cada pisada y el haz, en una
   pared lejana, cabecea con los pasos y va con la punta de la linterna. Tropiezo: manos delante y la luz da un tirón
   al suelo. Agotado y quieto: las manos asoman abajo respirando (si parpadean en el borde, retocar
   `ManosCorrer.JADEO.pos`). Pegado a una pared con la linterna: la luz no sale al otro lado.
5. **Mando**: L3 alterna; parado 0,8 s se apaga.
6. **Móvil** (emulador, teléfono horizontal): CORRER junto a AGACHARSE, la rejilla 4 × 2 no entra en la zona de la
   palanca (40 % izquierdo) y la barra queda debajo sin chocar (`Hud.Aguante.AbsolutePosition` frente a
   `Hud.EquipoBotones`). El botón se enciende al correr y se apaga solo al pararte; agachado o con la mochila, apagado.
   Con un iPhone con barra de inicio en el emulador, que la rejilla y la barra queden por encima.
7. **Dos jugadores** (Test → 2 clientes): al otro se le ve correr (tronco adelante, braceo), tropezar y jadear agotado,
   y se le oye el jadeo en 3D a menos de 60 studs. A la fuerza (Server): `game.Players.Player2:SetAttribute("Corriendo",
   true)` / `("Agotado", true)`; con `Agachado` o `Asomado` a la vez, las piernas no se rompen.
8. **Perseguido por cada bicho** (`game.ServerStorage.Prueba:Fire("Noche")` y luego `("Ataque", ...)`, `("Raspador",
   ...)`, `("Trepador")`, `("Imitador")`, `("Acechador")` con el jugador en el bosque, `("Bestia")`): corriendo se gana
   un trecho, pero el Acechador y la Bestia te alcanzan si no llegas a la luz o a un escondite. Ruido: con un Golpeador
   dentro de la casa y fuera de su vista a ~15 studs, andando no te nota y corriendo va a por ti. Desde el bosque
   (granja, aserradero), corriendo bien se llega a la luz de la casa; andando, no.
9. **Escondido cansado**: correr hasta agotarte y meterte enseguida en un armario: jadeos fuertes que se apagan en ~7 s,
   la cámara se mece más y suena el latido; esperando 10 s antes, nada de eso. Con un bicho a ~10 studs del armario,
   contener dura ~5 s en vez de 12 y a veces se escapa un jadeo (respingo, bordes y latido). Debajo de una mesa
   (`Cubierto`): jadeos de MuerteVista, sin los resoplidos de CorrerVista a la vez. Con Rendimiento, sin mecerse de más.
10. **Tutorial** (`Config.Test.Tutorial = true`, sin subirlo): tras coger el hacha sale "TUTORIAL 3/9" con la flecha al
   árbol más cercano; corriendo un momento pasa a talar. En el móvil la flecha va al botón CORRER y el texto dice
   "tap RUN"; con mando, "press L3". Que quepa en español.
11. **Rendimiento** (Ajustes): corriendo, campo de visión 70, sin balanceo, braceo ni temblor de más; el tropiezo sí.
12. **Morir corriendo y reaparecer**: `Aguante` 1 y sin `Corriendo`, `Agotado` ni `Frena`; la barra no sale.
13. **Escena final** (14.9): correr hasta agotarse (oír los resoplidos) y arrancar el coche enseguida: en la escena
   de la huida ya no suenan (`EscenaFinal`, ver `partida.md`).

## Números a ojo para mirar en Studio

- `Config.Correr.Andando` 1/12 (¿se hace lento llenar andando?) y `Dura` 6,5.
- Cámara: `CORRE_SUBE` 0,9 (la cabeza sube y baja ~0,19 studs corriendo: puede ser mucho), `CAMPO` 7 grados.
- Manos: `ManosCorrer.BRACEO.delante` (cuánto asoma el puño), `JADEO.pos` (las manos agotado, en el borde de abajo).
- Escondido: `ESCAPA_PROB` 0,3 (del todo sofocado se escapa el jadeo ~2 de cada 3 veces: quizá mucho).
- `Config.Acechador.Persigue` 22: con un buen ciclo desde 36 se aguanta entera; subirla a ~26 si se quiere que solo
  salve llegar a la luz.
- La clase Corredor deja atrás a todos corriendo bien.

## Ideas no hechas

- Que tropezar pare al jugador un instante en el servidor (ahora solo cuenta `Frena`).
- Que los bichos vayan al último sitio donde oyeron correr, que correr cerca de las latas suene más lejos, o que tu
  jadeo escondido lo oigan los bichos (haría falta lógica en el servidor).
- Gastar algo de aguante al saltar; una marca tenue en la barra en el tercio mientras estás agotado.
- Botón CORRER que también se pueda mantener; braceo en fase exacta con la cabeza (`CuerpoVista.fase()`).
- Agotado y mirando abajo, las manos en las rodillas.
- Sonidos de verdad: `Jadeo` (y `Respiracion`, `Contener`, `Exhalar`) con ElevenLabs (`sonidos-pendientes.md`).
