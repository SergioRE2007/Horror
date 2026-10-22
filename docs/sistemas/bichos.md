# Trepador, Imitador y Acechador (paso 9)

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

## Pendiente

- Probar jugando de verdad si dan miedo (Sergio): los pasos en el tejado desde dentro, la duda de la puerta con 2 jugadores, el bosque al anochecer.
- Sin probar: el cartel "[R] ECHAR AL FUEGO" visto en pantalla (la herramienta de pruebas no ve los carteles), 2 jugadores (a quién imita, el móvil para comprobarlo), móvil.
- Sin probar con jugadores reales: que el Imitador llame mientras un amigo de verdad está fuera (elige a uno que no esté junto a la puerta).
