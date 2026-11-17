# Bichitos: ratas, cucarachas, polillas y moscas

Pedido por el usuario (inmersión: "que haya efectos de polvo en el aire o cosas así, mejorar las animaciones"). Todo en
el cliente, de adorno: `src/juego/cliente/BichitosVista.luau`, números en `Config.Bichitos` (a ojo). Nada afecta a la
partida ni pasa por el servidor.

## Qué hay

- **Ratas** en el sótano, el desván, el trastero y el garaje (2-4 por sala). Hechas de piezas: cuerpo y cabeza de
  pelo, hocico, ojos con un brillito, orejas, cuatro patas que trotan en diagonal y una cola de 6 trozos que se menea
  (abierta y lenta quieta, casi recta huyendo). Quietas husmean (cabeza que cabecea y gira); luego dan un paseo corto.
- **Huyen** si las alumbras con tu linterna (a menos de `Rata.Luz` studs y `Rata.Angulo` grados del centro, sin pared
  en medio) o si tú u otro jugador os acercáis a menos de `Rata.Susto` (6). Corren pegadas a la pared hasta el rincón
  más lejos de lo que las asusta (sin pasar por su lado), donde hay un agujerito oscuro en el zócalo, y desaparecen. Si
  se topan con un mueble o se acaba el suelo, se meten ahí. Vuelven a los `Rata.Vuelve` segundos si no estás encima ni
  las alumbras. Al huir chillan (70 %).
- **Aviso sin sonido**: con un bicho (`workspace.Bichos`) a menos de `Rata.Bicho` studs de la sala, todas se esconden
  sin chillar y no salen hasta que se va. Si de repente no hay ratas, algo viene.
- **Cucarachas** por el suelo de la cocina (2-4): quietas o andando un poco, con las antenas siempre moviéndose; al
  darles la luz o pisarlas casi, corren a la pared más cercana y se meten.
- **Polillas** alrededor de cada bombilla encendida (las `Lampara` con PointLight del generador, como en
  `DetallesVista`): 2-3 dando vueltas raras y dándose contra ella de vez en cuando, la receta de `GasolineraVista` del
  lobby. Mientras la bombilla parpadea a oscuras (`Ambiente.factor`), no van a por ella.
- **La polilla de la linterna**: de noche, fuera de casa y con la linterna encendida, cada `PolillaLinterna.Cada`
  segundos llega una de la oscuridad, revolotea delante de la cámara, se da contra el cristal y se va (también al
  apagar la linterna o al entrar en casa).
- **Moscas** sobre los charcos de sangre (etiqueta `Charco`, que ponen `MuerteVista.charco` y el susto Goteo de
  `Sustos/Sangre`; la comparte `HuellasVista`): llegan a los `Moscas.Llegan` segundos, zumban en zigzag y alguna se
  posa un momento en la sangre.

## Cómo está hecho

- Salas como rectángulos en planta en `Config.Bichitos.Salas` (de las medidas de `juego/servidor/Mapa`), con la altura
  del suelo y lo alto: solo hay bichitos con la cámara entre el suelo y el techo de la sala y a menos de `Cerca` (25)
  studs en planta; se borran a `Cerca + Margen`.
- Ratas y cucarachas andan sobre el suelo de verdad: un rayo hacia abajo en cada paso (un suelo a más de `Desnivel` de
  la altura de la sala no vale: escalera, huecos). No atraviesan paredes ni muebles: rayo por delante hasta la punta
  del hocico con `MuebleRayo` (ve también las cajas `Choque` de los muebles, que no ven los rayos normales); si no
  pueden seguir recto prueban 35° y 70° a cada lado, y al girar no meten el hocico en la pared. Avanzan hacia donde
  miran (giran deprisa; con el destino muy de lado, giran en el sitio).
- Los rincones salen del rectángulo; un rayo a cada lado busca la pared y, si la hay, pone el agujerito (media esfera
  negra aplastada contra el zócalo) y la rata se mete justo delante.
- Un repaso cada `Cada` segundos (qué salas, bombillas y charcos están cerca, bichos, Rendimiento, la polilla de la
  linterna). El `Heartbeat` que anima solo está conectado mientras haya algo; todas las piezas de ratas y cucarachas se
  colocan de una vez con `workspace:BulkMoveTo`. Piezas sin chocar, sin `CanQuery` ni `CanTouch` y casi todas sin
  sombra (el cuerpo de la rata sí), en `workspace.Bichitos`.
- **Rendimiento**: una rata por sala y una polilla por bombilla; ni cucarachas, ni moscas, ni la polilla de la
  linterna. Al cambiarlo se borra todo y sale de nuevo con lo que toca.
- Sonidos que faltan (filas 31-33 de `sonidos-pendientes.md`): `RataChillido`, `RataPatas` y `Moscas`. Mientras, la
  rata chilla con `Cruje` muy flojo (`Rata.Volumen`) y agudo (`Rata.Tono`); patitas y moscas, mudas. Con su Id, el
  código los usa solo (`Sonido.hay`).
- Banco: `tests/bancos/bichitos.luau` (rectángulo, suelo, paredes, NaN, pared en medio, linterna, vuelta, bicho,
  Rendimiento, cucarachas, polillas, moscas y la polilla de la linterna).

## Probar en Studio

1. Play, encender el generador y bajar al sótano (o entrar en el trastero o el garaje) sin linterna: 2-4 ratas
   husmeando y paseando. Mirar que pisan el suelo y no se meten en paredes ni muebles.
2. Encender la linterna y apuntar a una: huye pegada a la pared hasta un rincón con agujerito y desaparece (chillido
   flojo). Acercarse a menos de 6 studs de otra: huye igual. Salir y volver a los ~40 s: han vuelto.
3. Con una rata a la vista, hacer que se acerque un bicho (o poner un modelo de `workspace.Bichos` al lado con
   `execute_luau`): se esconden todas, sin ruido.
4. Cocina con la linterna apagada: alguna cucaracha; al alumbrarla, corre a la pared.
5. Con el generador encendido, mirar una bombilla: 2-3 polillas que se dan contra ella.
6. De noche fuera con la linterna: a los 15-35 s llega una polilla a la luz; al apagar, se va.
7. Morir (o el susto Goteo): a los ~6 s, moscas sobre el charco.
8. Ajustes → Rendimiento: una rata por sala, sin cucarachas ni moscas.
9. Ver que la consola no tiene avisos `[BichitosVista]`.

Afinar a ojo en Studio: las alturas de `Suelo` de cada sala (si en alguna no sale ninguna rata, es que el rayo no
encuentra el suelo a esa altura) y el tamaño de la rata.
