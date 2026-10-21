# El corazón: casa, día y noche, Golpeador, esconderse y morir (paso 2)

Todo con bloques grises. Animaciones sencillas a propósito: se mejoran más adelante (pedido por el usuario). En la partida siempre primera persona (pedido por el usuario).

## Servidor (`src/juego/servidor`)

- `Mapa`: suelo, 260 troncos, camino y la casa (dos plantas, medidas en la cabecera del archivo). Lo que se toca lleva etiqueta: `Ventana` (cristal + persiana), `Puerta` (hoja con bisagra; `Bloqueada` = sótano y habitación del rico), `Escondite` (3 armarios de lamas, 2 camas). `Mapa.salas` = puntos por los que ronda el bicho. Luces siempre encendidas hasta que haya generador.
- `Casa`: estado de cada ventana y puerta (reglas puras en `shared/Defensa`, probadas con Lune) publicado en atributos; prompts propios (E acción, R reparar manteniendo 4 s, gratis hasta que haya tablones). El servidor nunca mueve la hoja de una puerta: le quita la colisión al abrirse y el cliente la gira.
- `Ciclo`: atributos del workspace `Fase`, `Noche`, `FaseInicio`, `FaseFin`. En Studio, `Config.Test.Dia/Noche` (40 s / 150 s).
- `Director`: un ataque detrás de otro cada noche, más seguidos cada noche. Amanecer: el bicho se va, reviven los muertos y foto de la casa. Si mueren todos: vuelve al principio del día con la casa del amanecer.
- `Golpeador` (desde el paso 3, lo común de cazar está en `Caza` y puede haber varios: ver `raspador.md`): Humanoid del servidor. Llega del bosque, golpea; persiana bajada o puerta cerrada aguantan quitando vida hasta que se cansa; cristal descubierto: 3 golpes y entra. Abrirle la persiana mientras golpea = entra. Dentro ruge 4 s y caza 35 s (ve, oye a < 8 studs, va a donde te vio, ronda; si te vio esconderte te saca). Abre las puertas a golpes (`PathfindingModifier` PassThrough en las que no tienen llave). Fuera de noche persigue a quien vea.
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

## Segunda tanda (21-10-2026)

- Golpeador provisional rehecho de piezas: flaco y encorvado, piel gris de muerto, cabeza ladeada colgando, cuencas negras con un puntito claro, dientes torcidos, mandíbula que se abre (más al golpear y al rugir), costillas, espinazo, garras y sangre en boca, pecho y garras. Al pillarte se gira hacia ti.
- Noche: la luz de luna de Roblox sale negra sin más; `Ambiente` sube la exposición de noche (1,6) y baja las lámparas en proporción (0,41) para que dentro siga en penumbra. La hora de noche se queda cerca de medianoche (luna alta). Si el generador cambia el brillo de las lámparas, `Ambiente` guarda el brillo de cada luz al aparecer: habrá que avisarle.
- Armario: 19 lamas finas y la cámara al fondo; se ve fuera a rayas.
- Susto: cámara de frente a la cara (sin meterse en paredes) con la boca abierta y una luz delante; sangre en pantalla con goterones que bajan desde arriba y salpicaduras con gotas, que se queda goteando un poco al pasar a mirar.
- Móvil: el HUD baja a 0,55 en un teléfono, así que el botón de acción táctil es de 200×90 y SALIR de 220×80. Los avisos, más arriba (0,76) para no pisar SALIR.
- Modo de pruebas: `ServerStorage.Prueba:Fire("Noche" | "Dia" | "Ataque" | "Esconder", punto)`.
- Probado: el bicho te saca del armario si te vio esconderte (a los 0,2 s) y no te encuentra si no te vio (pasó a 5 studs y siguió). Sin errores.

## Por dónde vamos (pendiente)

- Probar jugando de verdad si da tensión (Sergio): oír de dónde vienen los golpes, correr a bajar la persiana, esconderse.
- Sin probar con 2 jugadores: mirar a los vivos de muerto (en Studio: Probar → Clientes y servidores, 2 jugadores).
- Móvil comprobado con una maqueta de los controles de Roblox sobre la pantalla de Studio, no en un teléfono.
- Los avisos de esconderse salen solo para lo que se mira y de uno en uno (el más cercano): con una puerta al lado, hay que mirar bien el armario.
- Equilibrio a ojo: daño 5-7 por golpe (un ataque quita ~60 % a una persiana), paciencia 14-20 s, caza 35 s.
