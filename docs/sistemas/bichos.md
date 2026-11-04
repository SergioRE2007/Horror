# Bichos: Trepador, Imitador y Acechador (paso 9), vida de espera y gateo (14.6)

Con bloques grises y animaciones sencillas, como los pasos 2 y 3. Números a ojo, todos en `Config` (`Trepador`, `Chimenea`, `Imitador`, `Acechador`). Lo común de cazar sigue en `Caza` (ver `raspador.md`). Nada de esto se guarda.

## Servidor (`src/juego/servidor`)

- `Director`: en cada ataque elige bicho: Imitador, Trepador, Raspador o, si no, Golpeador. Cada especial, uno como mucho a la vez, con su primer ataque seguro la noche en que sale (`seguros`). El Imitador solo si la puerta principal está libre.
- `Trepador` (noche 7): trepa por la pared de delante o de detrás (detrás, nunca por el cobertizo), ronda 24-32 s por el tejado (menos cada noche) parándose a ratos, se mete por el tiro y baja 4 s. Sale al salón por el hogar, ruge y caza 30 s. Con la chimenea encendida (en el tejado o mientras baja) chilla, se tira del tejado y huye. En pared y tejado va anclado y se mueve a mano (`deslizar`); medidas del tejado en la cabecera. Avisos: "Algo anda por el tejado." y "¡Algo baja por la chimenea!" (solo a los de dentro).
- `Chimenea`: con un tronco en las manos, R (`Cargar.alUsar "Tronco"`, etiqueta `Chimenea`). Cada tronco arde 50 s, como mucho 2 a la vez. Atributo `Fuego` (hora del servidor). El modelo (en `Mapa`) tiene el tiro que sale por el tejado y los atributos `Hogar`, `Tiro` y `Salida`.
- `Imitador` (noche 10): se planta en la puerta principal y llama 4 veces con la voz de un jugador que no esté junto a la puerta (solo: con la tuya, y te dice "Alguien en la puerta está hablando con tu voz"). Las frases suben de tono; si no le abren: "Sé que estáis ahí dentro." y se va. Si alguien abre (o la encuentra abierta), se le estira el cuello, entra y caza. A quien sale a mirar (a menos de 22 studs), le caza. Avisos solo a los que están a menos de 80 studs.
- Apagón (pedido por el usuario: "esa noche se va la luz"): la primera noche del Imitador, al primer golpe, `Generador.apagon()` para el motor aunque tenga gasolina; hay que salir al cobertizo a arrancarlo. Aviso: "Se ha ido la luz."
- `Acechador` (cada noche, desde los últimos 20 s del día): a quien lleva 6-12 s fuera, a más de 48 studs del centro de la casa, le sale lejos y del lado contrario a la casa (nunca corta el camino de vuelta). Le sigue a 36 studs 14-20 s partiendo ramas; si le miras se queda quieto. Luego se echa encima a 21 (el jugador anda a 16) durante 22 s como mucho: "Corre. Vuelve a la luz." La linterna lo frena 2,5 s y luego tarda 2,5 s en volver a frenarlo. Al llegar a la luz se queda mirando y se va. Uno por presa, 2 a la vez como mucho.
- Modo de pruebas: `ServerStorage.Prueba:Fire("Trepador" | "Imitador" | "Acechador" | "Fuego")`. "Imitador" va con apagón; "Acechador" sale a por el primer jugador (que debe estar en el bosque).

## Cliente (`src/juego/cliente`)

- `TrepadorVista`: anda como una araña (patas en diagonal, codos por encima de la espalda), cabeza del revés que da tirones. Pasos pesados y crujidos en el tejado que se oyen desde dentro. "Baja": algo arrastrándose por el tiro y hollín cayendo al hogar; "Entra": nube de hollín y chillido; "Quema": chillido.
- `ImitadorVista`: anda tieso sin mover los brazos; en la puerta la cabeza se le va ladeando; llama con el puño (3 golpes en 3D). Al entrar se le estira el cuello y abre la boca.
- `AcechadorVista`: altísimo (unos 14 studs), con ramas en la cabeza; zancadas lentas; ramas que se parten (3D); al echarse encima ruge con los brazos por delante; con la linterna se encoge y se tapa la cara.
- `ChimeneaVista`: llamas, luz anaranjada que tiembla, brasas flojas, humo por el tiro y crepitar.
- `CargarVista`: el tronco vale para el caballete (SERRAR) y la chimenea (ECHAR AL FUEGO).
- `MuerteVista`: el susto sirve para los cinco bichos.
- Sonidos nuevos provisionales de la biblioteca (Pro Sound Effects y uno de fuego): `Crujido`, `Hollin`, `Fuego`, `Llamar`, `Rama`.

## Probado en Studio (22-10-2026)

- Trepador: llega, trepa, ronda ~30 s por el tejado, baja por la chimenea, sale al salón y pilla al jugador. Con la chimenea encendida en el tejado salta al momento y huye. Se atascaba en el cobertizo: arreglado.
- Imitador: llama, imita la voz, se va la luz al primer golpe, frases cada 7-10 s; al abrirle entra y pilla al jugador.
- Acechador: sale solo al anochecer a los ~9 s fuera, sigue partiendo ramas, se echa encima, la linterna lo para y luego pilla; al volver a la luz se rinde y se va.
- Tronco a la chimenea con R: arde 50 s. Sin errores en consola. Lune: 425 comprobaciones bien.

## Vida mientras esperan (14.6, sin ver en Studio)

Pedido por el usuario: "los bichos con más vida mientras esperan". En cada `<Bicho>Vista`, con la Transform de sus
Motor6D, en un solo bucle que corre solo si hay alguno a menos de 120 studs (45 con Rendimiento); vaho de noche fuera.
Con Rendimiento, nada de esto. Se pausa mientras gatean.
- Golpeador: respira con rabia, se crispa, da tirones con la cabeza y reacciona a la mirilla. Antes de cada golpe se
  echa atrás y sube los brazos por los lados; las garras se hunden en la pared de encima de la ventana sin asomar dentro.
- Raspador: raspa paciente con la cara ladeada contra el cristal. Con la linterna se encoge y sigue arañando con una
  mano; con el flash recoge las dos. Nada cruza el cristal.
- Trepador: patas por cinemática inversa (no resbalan), agazapado y nervioso; se para a escuchar (clavado, sin
  respirar, cabeza ladeada) y en el tejado cruje la madera.
- Imitador: demasiado quieto en la puerta (cabeza ladeada escuchando, tirones, dedos crispados, nudillos al compás de
  `Toc`). Mirilla (atributo local `Mirilla` de MirarVista): se ve a contraluz, gira la cara y se pega de golpe
  (`Sobresalto`), una vez por llamada y solo si sigues mirando.
- Acechador: respira, se mece, se esconde tras un tronco sin que se le vea moverse y se asoma inclinándose desde los
  tobillos; si echa a andar o carga viéndole, sale de una zancada.
- Bestia: respira pesada, resopla (vaho de noche), tiembla, carga el peso, olfatea, se crispa y gruñe.
- Arreglado de paso: NaN en las juntas del Golpeador y del Raspador hasta su primera sacudida; brazos del Golpeador
  que atravesaban la pared al golpear; dedos del Raspador que atravesaban el cristal.

## Esconderse agachado: los bichos que huelen y gatean (14.6, sin ver en Studio)

Pedido por el usuario (03-11-2026): "agacharte también debería servir para esconderte, por ejemplo debajo de mesas, y
que el monstruo pueda gatear si te huele con una animación guapa para pillarte debajo de sitios… que sea útil
agacharte es la finalidad". El cuerpo del jugador (caber debajo, `Cubierto`), en `manos.md`. Números a ojo al final de
`Config.Postura`.

Servidor (`Caza`, `Bestia`):
- Agachado se te ve y se te oye peor (`PosturaReglas.alcanceVista`/`alcanceOido`); corriendo, te oyen a `Config.Correr.Oido` (22 en vez de 8, 14.8: `correr.md`). Debajo de un mueble (atributo
  `Cubierto`) solo te notan muy de cerca (`VerCubierto`) y en tu misma parte del mapa, pero te huelen (`oler`/`huele`:
  a `Olfato` studs, `Huele` s hasta saber dónde estás).
- Si te huelen o te vieron meterte, van al borde del mueble que da `Caza.borde`: frente a ti, corriéndose entre
  sillas, sin cruzar paredes y con sitio a los lados (`Ancho`), a `Fuera` studs de la zona Debajo (`FueraRaspador`,
  `FueraTrepador` y `FueraBestia` para los que de pie sacan brazos o cabeza: más lejos para no meterlos en el tablero;
  si así no caben por ningún lado, como una pared cerca, a `Fuera`).
  Empiezan a gatear a `CercaBorde` del sitio, así que suelen quedar 1-3 más lejos.
- Gatean con `Gatea` (dónde estás) y `GateaHora` (hora del servidor) en su modelo, que anima el cliente. A los `Gatear`
  s te matan (susto en la boca del hueco); lo dejan si sales y te alejas más de `SeEscapa`, si les aturden, si amanece
  o si se quitan. Los atributos vuelven a nil siempre.
- Si no llegan al borde en `Atasco` s, o desde él no te alcanzan (algo en medio), apuntan ese borde en `sinSalida`
  (como mucho 3, durante `SinSalida` s) y prueban otro lado. Dos bichos no gatean en el mismo borde (`gateaEn`).
- `Mapa` avisa en la Salida si una zona Debajo cruza una pared.

Cliente (cada `<Bicho>Vista`, solo lo visual):
- El tablero no se puede medir con rayos: las piezas de los muebles y sus cajas `Choque` tienen CanQuery = false. Se
  saca de la zona Debajo y del atributo `Tam` de su mueble (`cajaTablero` en Golpeador e Imitador, `tablero` en
  Raspador) o con `MuebleRayo` (Trepador y Bestia: rayos que además ven el tablero entero y las cajas Choque). Antes
  de este arreglo el Trepador y la Bestia gateaban "sin mesa" y metían mandíbula y lomo por el tablero.
- Golpeador: a cuatro patas; la cara baja por fuera del borde y entra de lado a ras de suelo mirándote; un brazo
  apoyado fuera y el otro barre por debajo a tirones, olfateando. Los brazos rodean las patas de la mesa (`patasDe`) y,
  de pie junto a la mesa, se echan atrás para no atravesar el tablero (`apartarBrazos`).
- Raspador: boca abajo, se arrastra a tres tirones con las manos clavadas; cuello estirado y cara ladeada en el suelo
  a ~0,9 de ti; codos de araña por cinemática 3D; una mano te llega al lado arañando.
- Trepador: se echa atrás si la cabeza o las rodillas le quedan sobre la mesa, se aplasta con las patas muy abiertas y
  se cuela a tirones con la cabeza del revés a ras de suelo; las patas no resbalan.
- Imitador: encorvado con una mano en el suelo, el cuello se estira hasta asomar la cara ladeada por el borde; el otro
  brazo entra arañando hasta dejarte la mano al lado. Luz floja en la cara.
- Bestia: salta atrás, baja fuera del borde y se aplasta con el lomo fuera; entran la cabeza de lado, mirándote, y el
  brazo derecho barriendo el suelo hasta dejarte las garras a ~1,6. Con un hueco de menos de 2,7 solo mete el brazo.
- En todos: se pausa la vida de espera; al acabar sacan cabeza y brazo antes de levantarse; si te pillan se quedan en
  la pose durante el susto (`agarra`). Con Rendimiento, versión simple. Ruidos: `Paso`, `Cruje`, `Aranazo` y un
  chillido o rugido cortado al final.
- Escena de muerte (`MuerteVista`): con dos bichos cerca enfoca al que te pilla. Cada Vista da sus `candidatos` y
  `PosturaReglas.quienPilla` elige (primero el que gateaba a por ti; si no, la cabeza más cerca).
- Comprobado con bancos de Lune (Roblox de mentira, fuera del repo) en las mesas del comedor y de la cocina, de 0,8 a
  6 studs del borde, en diagonal, con Rendimiento, a 20 fps y escapándote: sin NaN y sin atravesar suelo ni tablero.

## Probar en Studio (esconderse agachado y vida de espera)

Todo en Play. En el datamodel Server, antes de nada: `game.ServerStorage.Prueba:Fire("Noche")`.
1. Vida de espera: `Prueba:Fire("Ataque", Vector3.new(25, 0, -40))` (Golpeador en el ventanal del salón),
   `("Raspador", Vector3.new(25, 0, -40))`, `("Trepador")`, `("Imitador")` (mirilla con L justo tras una llamada),
   `("Acechador")` (con el jugador en el bosque) y `("Bestia")` (para verla parada:
   `workspace.Bichos.Bestia.HumanoidRootPart.Anchored = true`). Mirarlos de cerca, y con Ajustes → Rendimiento.
2. Gateo a mano, con el bicho que sea en la casa: tú agachado debajo de la mesa del comedor en (-26.1, 3, -15)
   (`game.Players:GetPlayers()[1]:GetAttribute("Cubierto")` → true). En Server:
   `local b = workspace.Bichos:FindFirstChild("Raspador"); local r = b.HumanoidRootPart; local y = r.Position.Y;`
   `r.Anchored = true; b:PivotTo(CFrame.lookAt(Vector3.new(-31, y, -15), Vector3.new(-25.5, y, -15)))` y luego
   `b:SetAttribute("GateaHora", workspace:GetServerTimeNow()); b:SetAttribute("Gatea", Vector3.new(-26.1, 3, -15))`.
   A los 2 s, los dos atributos a nil; al acabar, `r.Anchored = false`. Mirar desde debajo y de lado con la cámara
   libre: nada atraviesa el tablero, las patas, los caballetes ni la viga de la cocina; al final sale y se levanta.
   Repetir en diagonal (`Vector3.new(-31, y, -11.5)` mirando a (-26.1, y, -15)), más lejos (x = -33), con
   Rendimiento y en la cocina (raíz en (-19.5, y, 10.5) mirando a (-19.5, y, 6.9); tú en (-19.5, 3, 7)).
3. NaN (Client): `for _, p in workspace.Bichos:GetDescendants() do if p:IsA("BasePart") and p.Position.X ~= p.Position.X then print(p:GetFullName()) end end`.
4. De verdad: `Prueba:Fire("Ataque", Vector3.new(-25.5, 1, -15))` (con `("Romper", Vector3.new(-25.5, 1, -15))` entra
   antes) y agacharte debajo de la mesa: a los ~5 s va al borde y gatea; a los 2 s, susto en la boca de la mesa.
   Salir y alejarte más de 6 antes de los 2 s: lo deja. Meterte debajo a la vista del bicho: va al momento. La Salida
   no debe decir "[Mapa] la zona Debajo de … cruza …". Repetir con la Bestia (`("Bestia")`).
5. Dos bichos (`Ataque` y `Raspador` a la vez) y tú debajo de la mesa: no gatean por el mismo borde, y la escena de
   muerte enfoca al que gatea, que se queda en el suelo durante el susto.

## Pendiente

- Probar jugando de verdad si dan miedo (Sergio): los pasos en el tejado desde dentro, la duda de la puerta con 2 jugadores, el bosque al anochecer.
- Sin probar: el cartel "[R] ECHAR AL FUEGO" visto en pantalla (la herramienta de pruebas no ve los carteles), 2 jugadores (a quién imita, el móvil para comprobarlo), móvil.
- Sin probar con jugadores reales: que el Imitador llame mientras un amigo de verdad está fuera (elige a uno que no esté junto a la puerta).
- Esconderse agachado y vida de espera: nada visto en Studio (pasos arriba). Retocar a ojo las poses de gateo, la
  rapidez de los tirones y los ruidos.
- Ideas no hechas del gateo: luz floja en la cara de la Bestia si no se la ve desde debajo de noche (el Imitador la
  lleva); un atributo en cada zona Debajo con el tablero, para no depender del pivote del mueble en el cliente (y
  juntar `cajaTablero` de Golpeador, Imitador y PosturaVista con `MuebleRayo.tablero`); que `Muerte.matar` mande el
  modelo que pilla (sobraría `quienPilla`); borrar el olor del que muere al revivir; que el bucle de gatear mire
  también `Humanoid.Health` (si mueres por otra cosa a mitad del gateo, el bicho espera 2,5 s sin rugir); que el
  Imitador use `MuebleRayo` en sus rayos de reserva (solo si no estás en ninguna zona, y entonces no gatea).
