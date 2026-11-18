# Huellas de barro y de sangre (inmersión, noviembre de 2026)

Pedido por el usuario: "mejorar la inmersión del juego". Las huellas dicen por dónde ha ido el bicho. Solo en el
cliente y solo de adorno (`src/juego/cliente/HuellasVista.luau`); números en `Config.Huellas`, a ojo.

## Qué hace

- **Bichos** (`workspace.Bichos`): dentro de la casa (`Config.Casa` y sus anexos), una huella de barro oscuro por
  pisada, con la `Zancada` y los `Pies` de `Config.Efectos.Bichos` (los mismos que las pisadas que hacen temblar las
  cosas), alternando izquierda y derecha y con la punta un poco hacia fuera. Fuera de casa, nada.
  - Forma (`Config.Huellas.Bichos`): garras (la textura de huellas con uñas del salón, `Mapa` `HOLLIN.Huellas`, teñida
    con `Decal.Color3`) para Golpeador, Raspador, Acechador y Bestia; el Trepador va a cuatro patas (mano izquierda,
    pie derecho, mano derecha, pie izquierdo; las manos más pequeñas y por delante); el Imitador deja zapatos, porque
    imita a una persona (decidido a ojo).
  - Trepando por la pared o bajando por la chimenea (atributos `Trepando` y `Bajando`), nada.
- **Sangre del bicho**: con el remote `Muerte` (el modelo que pilló; si no viene, el bicho más cercano a
  `CercaMuerte`), durante `Ensangrentado` (40 s) sus huellas son de sangre, también fuera de casa: rojas al principio y
  más marrones cuanto más tiempo ha pasado. Cada una sigue secándose (`Secar`, 60 s) hasta marrón.
- **Jugadores** (zapatos: dos óvalos aplastados, planta y tacón, con `SpecialMesh` de esfera): quien pisa un charco
  (etiqueta `Charco`) deja de 8 a 10 pisadas rojas (siempre las mismas para cada jugador, por su `UserId`) que se
  apagan paso a paso. Al entrar en casa después de pisar el bosque (hierba, tierra o barro), las 4 primeras son de
  barro.
- **Charcos**: `MuerteVista.charco` y el Goteo de `Sustos/Sangre` llevan la etiqueta `Charco` (una línea en cada uno).
- Todas duran hasta el amanecer (`Fase` = `Dia`: se borran) y se van aclarando (`Transparencia`, `Aclarar`).
- Tope de huellas vivas: 80 (`TopeRendimiento`, 30, con Rendimiento); las más viejas se borran primero.
- Piezas planas ancladas, sin colisión, `CanQuery` ni `CanTouch`, sin sombra, en la carpeta `workspace.Huellas` del
  cliente.
- Un solo `Heartbeat`: cada `Cada` (0,1 s) mira lo andado por bichos y jugadores a menos de `Cerca` de la cámara (el
  tramo se trocea: cada huella cae en su sitio exacto, aunque se repase a saltos); cada `CadaColor` (1 s) aclara y seca
  las huellas cercanas.
- Lo que se calcula son funciones puras de `HuellasVista` (`pisadas`, `marca`, `colorSangre`, `transparencia`,
  `apagada`, `pasosSangre`, `tope`, `recortar`, `dentro`, `enCharco`). Banco: `tests/bancos/huellas.luau`.

## Probar en Studio

1. De noche, dejar que un Golpeador entre en casa: barro oscuro en el suelo detrás de él, izquierda y derecha.
2. Que mate a otro jugador (dos jugadores en Probar): sus huellas pasan a rojas y se le puede seguir el rastro, también
   fuera; a los 40 s, otra vez barro y solo dentro. Las rojas se ponen marrones en un minuto.
3. Pisar el charco del muerto (o el del susto del Goteo): 8-10 pisadas rojas de zapato que se apagan.
4. Entrar del bosque: 4 pisadas de barro al cruzar la puerta.
5. Trepador: manos y pies alternando; en la pared, nada.
6. Mirar en Studio: que la textura de las uñas se vea teñida (si la imagen es negra, `Decal.Color3` no la tiñe: habría
   que subir una versión blanca) y que la punta mire hacia donde va el bicho (si sale al revés, girar 180° en
   `poner`). Con Rendimiento, no más de 30 a la vez. Al amanecer, el suelo limpio.
