# El corazón: casa, día y noche, Golpeador, esconderse y morir (paso 2)

Todo con bloques grises. Animaciones sencillas a propósito: se mejoran más adelante (pedido por el usuario). En la partida siempre primera persona (pedido por el usuario).

## Servidor (`src/juego/servidor`)

- `Mapa`: suelo, 260 troncos, camino y la casa (dos plantas, medidas en la cabecera del archivo). Lo que se toca lleva etiqueta: `Ventana` (cristal + persiana), `Puerta` (hoja con bisagra; `Bloqueada` = sótano y habitación del rico), `Escondite` (3 armarios de lamas, 2 camas). `Mapa.salas` = puntos por los que ronda el bicho. Luces siempre encendidas hasta que haya generador.
- `Casa`: estado de cada ventana y puerta (reglas puras en `shared/Defensa`, probadas con Lune) publicado en atributos; prompts propios (E acción, R reparar manteniendo 4 s, gratis hasta que haya tablones). El servidor nunca mueve la hoja de una puerta: le quita la colisión al abrirse y el cliente la gira.
- `Ciclo`: atributos del workspace `Fase`, `Noche`, `FaseInicio`, `FaseFin`. En Studio, `Config.Test.Dia/Noche` (40 s / 150 s).
- `Director`: un ataque detrás de otro cada noche, más seguidos cada noche. Amanecer: el bicho se va, reviven los muertos y foto de la casa. Si mueren todos: vuelve al principio del día con la casa del amanecer.
- `Golpeador`: Humanoid del servidor. Llega del bosque, golpea; persiana bajada o puerta cerrada aguantan quitando vida hasta que se cansa; cristal descubierto: 3 golpes y entra. Abrirle la persiana mientras golpea = entra. Dentro ruge 4 s y caza 35 s (ve, oye a < 8 studs, va a donde te vio, ronda; si te vio esconderte te saca). Abre las puertas a golpes (`PathfindingModifier` PassThrough en las que no tienen llave). Fuera de noche persigue a quien vea.
- `Muerte`: personajes sin reaparición automática, primera persona, esconderse (anclado dentro, atributo `Escondido` = CFrame de la cámara), `matar`, `revivirTodos`, aviso de "todos muertos".

## Cliente (`src/juego/cliente` y `src/comun/cliente`)

- `Ui` (común): estilo oscuro, fuente SpecialElite, letras hueso, rojo oscuro; un solo `UIScale`. `Avisos` (común): avisos de una línea del servidor.
- `Controles`: pinta los prompts Custom; en móvil, botón grande de acción a la derecha.
- `CasaVista`: lamas de la persiana (locales), grietas y cristal que estalla, puertas, temblor y polvo con cada golpe.
- `GolpeadorVista`: balanceo de piernas y brazos, golpe con los dos brazos, cabeza ladeada, pasos.
- `Ambiente`: luz y niebla de día y de noche, viento, aviso al atardecer con rugido lejano, "NOCHE n".
- `MuerteVista`: cámara del escondite con latido según lo cerca que esté el bicho, susto al morir (cara del bicho, rojo, sangre en pantalla), charco de sangre, mirar a los vivos en tercera persona.
- `Sonido`: plantillas precargadas. Los de `Config.Sonidos` son provisionales de la biblioteca de Roblox (todos cargan); se cambian por ElevenLabs.

## Probado en Studio (21-10-2026)

- Ciclo completo solo: anochece, llega, rompe un cristal sin persiana en 3 golpes, entra y pilla al jugador; todos muertos → vuelve el día 1 con la casa arreglada.
- Bajar persianas (los prompts solo salen si la cosa está en pantalla: hay que mirarla), golpes contra persiana bajada hasta cansarse, esconderse en el armario y salir.
- Sin errores en consola.

## Por dónde vamos (pendiente)

- Probar jugando de verdad si da tensión (Sergio): oír de dónde vienen los golpes, correr a bajar la persiana, esconderse.
- Sin ver aún: el modelo del Golpeador de cerca, la noche tras subir la luz de luna y las lámparas, las rendijas del armario más abiertas, el susto en pantalla, mirar a los vivos y la vista de móvil.
- Equilibrio a ojo: daño 5-7 por golpe (un ataque quita ~60 % a una persiana), paciencia 14-20 s, caza 35 s.
- Sin probar: el bicho sacando a alguien de su escondite y con 2 jugadores.
