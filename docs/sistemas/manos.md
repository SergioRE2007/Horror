# Manos, brazos y cámara con cuerpo (animaciones en primera persona)

Pedido por el usuario (03-11-2026):
- "Cuando abras las cortinas o las cierres (el juego es primera persona) que se vea cómo lo abres o lo cierras con las manos, y eso con todas las animaciones posibles".
- "No hace falta que hagas los dedos: con que el brazo normal esté bien animado es suficiente, hay personajes de Roblox que no tienen dedos".
- "Lo importante es que todo esté animado y sea inmersiva la experiencia".

Hecho en una sesión en la nube **sin Studio**: las poses salen de cuentas (comprobadas con Lune: orientaciones y largos), pero no se han visto. Hay que mirarlas y retocarlas en Studio (números al principio de cada módulo).

## Tus manos (`juego/cliente/Manos`, `ManosGestos`)

- Son copias de los brazos R15 de tu avatar (con tu camiseta y tu piel), adelgazadas a 0,42 de grueso (las de verdad miden 1 stud y taparían media pantalla) y con el mismo largo con cualquier avatar. Con R6, un brazo de bloques con manga oscura. Cuelgan de la cámara; los hombros quedan fuera de la vista.
- Cada mano va hacia un objetivo (la palma: -Z los dedos, +Y el dorso) y el codo sale solo (cinemática inversa de dos huesos). Un muelle la lleva hasta allí; al andar se mecen y quietas respiran.
- Capas por prioridad: pared 4, aire 5, linterna 10, móvil 20, pistola 25, cargar 30, trepar 35, herramienta 40, cambiar 45, gestos 50, foto 60 y susto 90. Sin capa, bajan fuera de la vista.
- Se esconden muerto, escondido, con la mochila abierta y en las cinemáticas (cámara Scriptable), menos el susto al morir.

| Qué | Cómo |
|---|---|
| Cortinas | Las dos manos cogen el borde de cada paño y lo corren con él |
| Puerta | La derecha coge el pomo, lo gira y lo acompaña. Si está cerrada con llave, la mano traquetea con el pomo |
| Coger un objeto | La mano baja, lo coge y se va hacia el bolsillo |
| Cargar algo pesado | Las dos manos van a sus lados y lo llevan (siguen a la pieza) |
| Generador | Coge la cuerda y da el tirón. Para apagarlo, aprieta el botón |
| Esconderse / salir | Empuja la puerta del armario. Al salir, las dos manos empujan |
| Pista | La coge y la sube a la cara |
| Enchufe | Lleva el móvil al enchufe |
| Banco del taller | Las dos manos se apoyan |
| Mantener pulsado | Palanca (tira poco a poco), cerilla (la raspa, prende y la baja al rastro), volante al huir |
| Linterna | En la izquierda; la luz sale de ella. Con poca pila, la sacude de vez en cuando |
| Móvil | En la derecha, con la pantalla hacia ti |
| Foto | Las dos manos suben la cámara a la cara |
| Pistola de bengalas | La derecha en el mango y la izquierda debajo |
| Hacha, sierra, martillo, llave (TrabajoVista) | Las manos en el mango; la izquierda sujeta lo que trabajas |
| Te pillan | Las manos se levantan temblando, abajo para no tapar la cara del bicho |
| Cualquier otro cartel | La mano va y lo toca |
| Cambiar la pila o el carrete | La linterna (o la cámara) en la izquierda; la derecha desenrosca, saca, mete y cierra |
| Coger (además) | Una copia del objeto vuela hasta la palma y se va con ella al bolsillo |
| Escalera de mano | Las manos van de peldaño en peldaño al ritmo al que subes |
| En el aire | Los brazos se abren para no perder el equilibrio |
| Sustos y golpes cerca | Las manos libres suben de golpe por reflejo (los golpes, uno cada 4 s como mucho) |
| Al girar | Las manos se quedan un poco atrás (inercia) |

- Para añadir uno: en `ManosGestos.alPulsar` (por el `ActionText` del cartel o la etiqueta del modelo) con `Manos.gesto(nombre, segundos, fn)`. Para algo que se lleva: `Manos.cosa` y `cosaDer` / `cosaIzq` en la pose.

## Los demás jugadores (`juego/cliente/BrazosVista`)

- Cada cliente gira los hombros R15 de los otros personajes (C0 de `RightShoulder` / `LeftShoulder`) encima de su animación de andar. Se ve cuando trabajan (hacia el mango de la herramienta), cargan, alumbran, miran el móvil, hacen una foto, disparan una bengala, o corren una cortina o abren una puerta junto a ellos.
- Su linterna se ve en la mano izquierda y la luz sale de ella (EquipoVista).
- Mirada: cada cliente manda cuánto mira arriba o abajo (remote `Mirada`, cada 0,2 s si cambia; el servidor, en `Equipo`, lo redondea y lo publica en el atributo `Mirada`). Los demás ven su cabeza inclinada y su linterna apuntando ahí.
- R6: se quedan con sus animaciones de serie.
- El vendedor (VendedorUi) gira el cuello y te sigue con la mirada a menos de 28 studs.

## La cámara como un cuerpo (`juego/cliente/CuerpoVista`)

- Al andar, la cabeza sube y baja con cada paso (la misma zancada que los sonidos de `Pasos`) y se mece. Al moverte de lado se inclina, al caer de alto baja de golpe y vuelve, y quieto respira (más rápido con un bicho a menos de 30 studs).
- Con lo pesado manda `CargarVista`. Nunca en cinemáticas, escondido ni muerto.
- Al esconderse (`MuerteVista`), la cámara va de los ojos al escondite en medio segundo agachándose, en vez de saltar.
- De noche y fuera de la casa se ve el vaho al respirar (sin él con Rendimiento).

## Probar en Studio

- Lanzar un gesto a mano (datamodel Client): `game.Players.LocalPlayer.PlayerScripts:FindFirstChild("ManosPrueba", true).Lanzar:Fire("Cortina")`. Vale `"Cortina"`, `"Puerta"`, `"Foto"`, `"Sobresalto"`, `"Susto"`, `"Pila"`, `"Carrete"`, `"Linterna"` y `"Movil"`. Para fijar la cámara y mirar las manos, ver los trucos del `CLAUDE.md`.

- **Cortinas:** abrir y cerrar varias, cerca y desde lejos (a 8 studs las manos se quedan estiradas hacia ellas).
- **Puertas:** una puerta y la del sótano cerrada con llave.
- **Objetos:** coger un objeto y un tronco, y andar con él.
- **Herramientas:** talar, serrar y clavar, y arrancar el generador.
- **Equipo:** linterna con poca pila, foto y pistola de bengalas.
- **Escondite y muerte:** esconderse, salir y morir.
- **Avatar:** mirar con un avatar R15 con camiseta y con uno R6.
- **Dos jugadores:** que se vean los brazos del otro.
- **Si algo se ve mal:**
  - `HOMBRO`, `REPOSO`, `L1` y `L2` en `Manos`;
  - las posiciones de cada gesto en `ManosGestos`;
  - `SITIO` en `TrabajoVista` (dónde va tu herramienta).

## Escondites: contener la respiración y verlo desde fuera (`MuerteVista`, `EsconditeVista`)

Pedido por el usuario: "respiración contenida al esconderte con un bicho cerca" y "ver a los demás jugadores esconderse y salir (la puerta del armario)". Hecho sin Studio: los números van al principio de cada módulo, para mirarlos y retocarlos.

- **Contener la respiración (MuerteVista):** escondido, con un bicho a menos de 18 studs, coges aire y lo aguantas solo, sin tecla (vale igual en el móvil). No cuenta el Imitador mientras finge en la puerta: lo delataría.
  - Suena `Contener` y se calla `Respiracion`, que suena en bucle mientras estás escondido.
  - La cámara deja de mecerse, sube un poco y tiembla un poquito. Se cierran unos bordes negros de más (a los lados y arriba y abajo) y el latido sube.
  - A más de 24 studs, o a los 12 s (los 4 últimos tiembla más), suena `Exhalar`: la cámara tiembla, baja un momento y jadeas 4 s antes de poder volver a contener.
  - Si sales o te pillan a medias, se corta sin sonar y no se queda nada puesto.
- **El escondite desde fuera (EsconditeVista, atributo `Ocupado` del escondite):**
  - Armario: abre sus dos puertas de lamas hacia fuera y las cierra detrás. Son hojas hechas en el cliente (cada lama partida en dos, con largueros solo abierta y los tiradores); mientras se mueven, las lamas de verdad se esconden.
  - Cama: la colcha se levanta por el lado de la salida y vuelve a caer. Es `Blanket` de Blender o, de la tienda, `ColchaCama_2`, `ColchaDosel` o `CamaNino_2`. Si se cambia el mueble, cambiar `COLCHAS`.
  - Si le saca un bicho, se abre de golpe y al rato se cierra sola, crujiendo.
  - Suenan `Puerta` y `PuertaCierra` flojos y agudos, y en las camas `Cruje`.
  - El que entra o sale se esconde un momento y vuelve a verse dentro, con la puerta a medio cerrar (o fuera, con ella abierta): no se le ve saltar.
  - Tu escondite se anima igual. Solo a menos de 60 studs de la cámara; con Rendimiento, de los demás solo el sonido.
- **Probar en Studio sin otro jugador** (datamodel Client), con el escondite más cerca de la cámara: `game.Players.LocalPlayer.PlayerScripts:FindFirstChild("EsconditeVista", true).Probar:Fire("Entrar")`. También vale `"Salir"` y `"Sacado"`.

## La casa reacciona más a los bichos (`cliente/Efectos`, `cliente/CasaVista`)

Pedido por el usuario: "que reaccionen más a los bichos". Hecho sin Studio (cuentas comprobadas con Lune): falta verlo. Números visuales a ojo al principio de `Efectos` (`MECE`, `TINTINEO`, `POLVO_AIRE`, `CORRIENTE`) y de `CasaVista` (`BRISA_ONDEA`, `BRISA_ALETEO`).
- **Mecedoras** (la del cuarto de la abuela con su manta, la del desván y la del porche): las pisadas y los golpes a menos de 16 studs las ponen a mecerse solas, hasta 5,5° y cada vez menos (unos 20 s), y crujen al dar la vuelta. Se mecen sobre el centro de abajo con los ejes de su pieza más grande (en el molde, sin girar).
- **Lo que tiembla suena**: vajilla, botellas y el juego de té tintinean; latas, ollas y candeleros repiquetean (uno por pisada, dos por golpe). Tiemblan también el juego de té, los licores, el quinqué, latas, ollas, sartenes, las fotos de pie y el reloj de la repisa.
- **Polvo en el aire**: tras un golpe, un portazo, la reja o una pisada pesada cerca o encima, motas que flotan unos 10 s delante de la cámara; solo se ven donde da la luz (el haz de la linterna).
- **Corriente**: con una ventana rota o una puerta echada abajo en la misma sala (un rayo mira que no haya pared en medio), las cortinas de las demás ventanas se hinchan a rachas (`brisa` de CasaVista) y las lámparas colgantes se mecen, hasta repararla.
- El portazo del bicho y la caída de la reja hacen temblar lo de alrededor como un golpe (`CasaVista.alGolpe`).
- Con Rendimiento: sin mecedoras, sin polvo en el aire y sin corriente (el tintineo sí).
- Sonidos prestados mientras no haya propios: `CristalVibra` y `Latas`, más agudos y cortos, para el tintineo, y `Cruje` para la mecedora. Si se añaden `Vajilla` y `Mecedora` a `Config.Sonidos`, se usan solos.
- Temblores de cámara (CasaVista y la reja de PreparativosVista): el giro se deshace en el fotograma siguiente antes de la cámara de Roblox (como en BestiaVista). Antes la mirada se iba desviando con cada temblor. Solo están atados mientras tiembla y nunca en cinemáticas.
- Probar: `workspace.EfectosLocales:GetAttribute("Mecedoras")` debe dar 3.

## Agacharse y asomarse (`PosturaVista`, `servidor/Postura`, `shared/PosturaReglas`, 14.6)

Pedido por el usuario: "cuerpo: agacharse (botón también en el móvil) y asomarse por las esquinas". Números de la vista
al principio de cada módulo; los de juego, en `Config.Postura`.
- Teclas: C o Ctrl izquierdo alterna agacharse (B en el mando; en el móvil, AGACHARSE en `Hud.EquipoBotones`,
  LayoutOrder 6, rojo con borde claro mientras vas agachado). Saltar, subir por una escalera o sentarse te levanta.
  Asomarse: mantener Z (izquierda) o X (derecha), solo con teclado.
- El cliente lo hace al momento con las mismas reglas que el servidor (`PosturaReglas`) y lo pide con el remote
  `Postura`. El servidor valida (tipos, NaN, cada `Config.Postura.Cada` s, vivo, sin esconderse, sin cargar ni
  trabajar; con la mochila abierta se agacha pero no se asoma; lo que no cambia nada ni se mira) y publica `Agachado`
  (true o nil) y `Asomado` (-1, 1 o nil). Al morir, esconderse, reaparecer, coger algo pesado o ponerse a trabajar se
  quitan solos. En una cinemática no se empieza; mirando por la mirilla o entre las cortinas, asomarse se queda como
  estaba hasta acabar.
- Agachado se anda a `Config.Postura.Velocidad` (`Cargar.ajustarVelocidad`) y tus pasos suenan la mitad (`Pasos`).
- Tu cámara (`CuerpoVista`): agachado baja `Config.Postura.Baja` suave con un golpecito de rodillas; asomado se va
  `Config.Postura.Asomar` de lado y se ladea `Config.Postura.Giro` grados, sin meterse en las paredes (rayos desde la
  cabeza y desde la cámara; se queda a 0,3). Va en el `CameraOffset` del Humanoid (CargarVista solo lo toca mientras
  llevas algo), y lo que suma (balanceo y ladeo) se deshace antes del fotograma siguiente girando en el espacio del
  mundo: da igual el orden respecto a los temblores de otros módulos y la mirada no se desvía.
- Los demás (`BrazosVista`, R15): agachados, la cadera baja y las piernas se doblan con los pies en el suelo y el tronco
  algo hacia delante; asomados, el tronco ladeado. R6, como está.
- Probado en Studio (03-11-2026): C agacha (cámara -1,7, velocidad a la mitad) y levanta; Z asoma (1,3 de lado, ~14°).

## Apoyarse en las paredes (`ManosGestos`, capa "Pared", prioridad 4)

Pedido por el usuario: "manos que se apoyan en la pared al pegarte a ella". Números a ojo en `APOYO`, al principio de
`ManosGestos` (poses y codos comprobados con Lune en un mundo de cajas).
- **Pared:** pegado a una pared (a 1,6 studs de los ojos o menos, y a menos de ~63° de donde miras), yendo hacia ella o
  quieto, cada mano libre se apoya: palma contra la pared, dedos arriba y algo hacia fuera; el codo hacia abajo (pegado
  del todo, hacia fuera). Con pared solo a un lado, la mano de ese lado; en algo estrecho (un poste), una.
- **Asomado** (atributo `Asomado`): la mano de ese lado se agarra al borde de la esquina o del marco (con la pared al
  lado, la palma en la cara y los dedos rodeando el borde; por delante del borde, lo coge por el canto, como una C).
- **Agachado** (atributo `Agachado`): la mano va encima de lo bajo que tengas delante (una mesa, un mostrador).
- La mano se queda pegada a lo que toca (no resbala al mirar alrededor) y baja suave al pasar por delante, resbalar,
  irte o darte la vuelta; un sondeo suelto sin pared no la suelta (hacen falta dos) y el meneo se apaga al pegarse.
  Con las cortinas corridas se apoya en la tela. Al apoyarse suena flojo el cristal y, a veces, una puerta cruje.
- Nada con esa mano ocupada (cualquier otra capa manda), escondido, muerto, con la mochila, en cinemáticas ni mirando
  por la mirilla o entre las cortinas. Rayos cada 0,1 s (0,2 con Rendimiento); no tocan personajes, bichos ni objetos
  sueltos; los muebles cuentan por su bloque de choque.
- Para otras capas: `Manos.ocupadaPor(lado)`, `Manos.reposo(lado)`, `Manos.escondidas()`; en la pose, `velDer`/`velIzq`
  (el muelle de cada mano), `codoDer`/`codoIzq` y `meneoDer`/`meneoIzq` (de 1 a 0).
- Probado en Studio (03-11-2026): de cara a la pared del salón la mano derecha se apoya (a 0,6 de la pared). Falta
  juzgar la pose con buena luz.
