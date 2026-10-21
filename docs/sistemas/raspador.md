# Raspador, linterna, flash y dificultad (paso 3)

Con bloques grises y animaciones sencillas, como el paso 2. Números a ojo, todos en `Config` (`Raspador`, `Dificultad`, `Separacion`, `Linterna`, `Flash`).

## Servidor (`src/juego/servidor`)

- `Caza` (librería): lo común de los bichos, sacado del Golpeador. Cada bicho en el mapa es un objeto (`Caza.nuevo`): andar abriendo puertas, ver y oír, perseguir, sacar del escondite, pillar. `Caza.todos()` para la luz. Campos de luz: `iluminado` (última vez que le dio una linterna), `alFlash` (si no tiene, el flash le aturde `Flash.Aturde` s), `ventana` (a la que está pegado: su persiana bajada tapa la luz).
- `Cuerpo` (librería): montar bichos con piezas y Motor6D.
- `Golpeador`: igual que antes pero puede haber varios a la vez. `atacar` devuelve una función "¿sigue?". El flash le para unos segundos (también deja de golpear).
- `Raspador` (pedido por el usuario): desde la noche 3 (su primer ataque de esa noche es seguro, luego 35 %; uno a la vez como mucho). Solo ventanas. Se pega al cristal y raspa 26-34 s (menos cada noche); va agrietando el cristal. La persiana no le para: al terminar rompe todo y entra, ruge y caza como el Golpeador, más lento. Linterna encima: raspa al 25 %. Flash con la persiana subida: chilla y huye corriendo (también si ya está dentro). Con la persiana bajada el flash no le llega. Atributos del modelo: `Raspado`, `Raspando`, `Iluminado`, `Huye`.
- `Equipo`: linterna (pila de 150 s, 2 pilas de repuesto) y cámara (carretes de 6 fotos, 1 de repuesto, 4 s entre flashazos). Al acabarse, pulsar otra vez cambia pila o carrete (1,5 / 2 s). Atributos del jugador: `Linterna`, `Pila`, `Pilas`, `Fotos`, `Carretes`, `Cambiando`. Sin mochila todavía (paso 4): pilas y carretes son solo números.
- `Director`: tabla de dificultad (`shared/Dificultad`, probada con Lune) al empezar cada noche según los jugadores: ataques a la vez (1 / 2 / 2-3 / 3), ritmo y paciencia. Cada "hueco" lanza ataques seguidos a ventanas o puertas libres; los huecos llegan escalonados 12-20 s. `Tareas` aún sin usar (paso 5). En Studio, `Config.Test.Jugadores` fuerza la fila.
- Modo de pruebas: `ServerStorage.Prueba:Fire("Raspador", punto)`.

## Cliente (`src/juego/cliente`)

- `EquipoVista`: F / L1 / botón LINTERNA; clic / R2 / botón FLASH. La luz propia sale de la cámara, la de los demás de su cabeza; parpadea con menos del 20 % de pila. Flash: destello para todos y pantalla en blanco para quien hace la foto. Abajo en el centro, un momento al cambiar: barrita de pila, pilas de repuesto y fotos.
- `RaspadorVista`: brazos con codo; raspando, los codos arriba y las manos bajando por el cristal con el chirrido en bucle; con luz se encoge, aparta la cara y tiembla; con flash chilla con la boca abierta.
- `MuerteVista`: el susto sirve para los dos bichos.
- Sonidos nuevos provisionales de la biblioteca: `Raspado`, `Chillido`, `Linterna`, `Flash`.

## Probado en Studio (21-10-2026)

- El Raspador llega, se pega y raspa (~0,029/s); con linterna, ~0,008/s. Flash con la persiana bajada: no le hace nada; subida: huye. Si termina, entra y pilla al jugador (susto con su cara).
- Dos Golpeadores a la vez en dos ventanas, los dos entran. Flash a un Golpeador que corría a 13 studs/s: 0 durante 1,2 s y luego sigue.
- Cambio de carrete al acabarse las fotos; el cartelito de abajo sale y se va. Lune: 101 comprobaciones bien.

## Pendiente

- Sin probar: botones del móvil, el parpadeo con poca pila jugando, 2 o más jugadores (luces de los demás, tabla de dificultad real).
- La linterna se ve poco con las lámparas de la casa encendidas; fuera sí se nota el círculo (brillo 4).
