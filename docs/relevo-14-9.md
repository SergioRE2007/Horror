# Relevo de la sesión del 04-11-2026 (14.8 y 14.9), para seguir en otro chat

Archivo temporal (pedido por el usuario: pausar y seguir en otro chat). Al integrarlo en `docs/sistemas/` y `TASKS.md`,
borrarlo. Rama: `ccr-b3390946-d29edq` (sin PR todavía). Todo con commit y subido; `selene src` 0 errores y 0 avisos,
`lune run tests/regressions.luau` en verde (1166 comprobaciones).

## Hecho

- **14.8 Correr y aguante**: hecha, revisada con `reviewer` (sin GRAVES; MEDIOS arreglados en 902081b) y documentada
  (`docs/sistemas/correr.md`, con sus pasos para Studio). En TASKS.md ya está como hecha sin Studio.
- **14.9.1 Pulido por áreas**: 42 hallazgos (textos, a medias y avisos, móvil, cinemáticas y conexiones, coste de los
  bichos); 41 confirmados y arreglados por 6 grupos, y los restos entre grupos, arreglados después (agente RESTOS).
  `movil.md` ya al día.
- **14.9.2 Deudas del gateo**: hecho salvo el banco (ver abajo). `Muerte.matar(jugador, cabeza, modelo?)` manda el
  modelo y MuerteVista ruge el de ese modelo (fuera `PosturaReglas.quienPilla` y los `candidatos` de las Vistas);
  `MuebleRayo.tablero` único (devuelve también `medido`) para Golpeador, Imitador, Raspador y el techo de PosturaVista;
  el Imitador mira sus rayos de reserva con MuebleRayo; Caza olvida olor, vistoEn y debajo al morir
  (`Muerte.alMorir`) y el gateo mira `Muerte.vivo`; luz floja en la cara de la Bestia al gatear; `LEJOS_RENDIMIENTO`
  = 120 en todas las Vistas; banco `tests/bancos/muerte.luau`.
- **14.9.3 Coche que llega al lobby**: hecho (`LlegadaVista`, `CocheCopia`, atributo `Llegada`, carril de uno en uno) con
  su banco `tests/bancos/lobby-coche.luau`.
- **14.9.4**: `docs/sistemas/sonidos-pendientes.md` (falta añadir la fila de `MotorCoche`, ya creado con Id 0 en
  `Config.SonidosLobby`).
- **14.9.5**: `tests/bancos/economia.luau` y `docs/sistemas/economia.md` (propuesta para la 14.5, sin tocar Config).

## Lo que falta, en orden

1. **Terminar el banco del gateo** (`tests/bancos/_gateo.luau`, WIP en 0b235fa; con "_" no lo lanza regressions):
   - Correr `GATEO_VER=1 lune run tests/bancos/_gateo.luau <Bicho>` para los cinco (30-60 s cada uno).
   - Imitador pasa los 15 casos. Golpeador: 2 casos por poco en el suelo (adorno del BrazoD 0,18 al salir
     "escapándote"; 0,10 en "Comedor a 0,8"; el margen SUELO es 0,10). Raspador: "Cocina en diagonal", el AntebrazoI
     0,13 en una pata a los 1,95 s. Trepador: la Mandíbula ~0,14 en el tablero en el primer fotograma (heredado de cómo
     llega andando: mirar el descuento HEREDA = 0,3 s). Bestia: tras gatear, al andar y parada, adornos del BrazoD
     0,2-0,34 en el suelo (vida de andar o parada, no el gateo); "Comedor en diagonal", el BrazoI 0,51 en el tablero en
     el primer fotograma (heredado); sin comprobar tras el último cambio la luz con Rendimiento y "sale del hueco".
   - Decidir si lo de andar o estar parado cuenta (medir solo "gateando" y "saliendo", o comparar con un "andando" de
     antes de gatear); arreglar o aceptar con un margen dicho; quitar los print de depuración (`GATEO_DEBUG`,
     `_G.DEPURA`); renombrarlo a `tests/bancos/gateo.luau` y commit.
   - Ya arreglado por el banco: el brazo que barre de la Bestia se metía ~0,9 en las patas (`barreLibre` con
     `MuebleRayo.choca`, nuevo; queda ~0,6 en la viga de la cocina, sin volver a medir). No comparado fotograma a
     fotograma con antes.
2. **Revisión final** (agente `reviewer`) sobre `git diff 8643a4a..HEAD -- src tests` (toda la sesión): exploits,
   cosas que no se devuelven, conexiones, llamadas a funciones quitadas (`quienPilla`, `candidatos`, `cajaTablero`,
   `MirarVista.mirando`, `Util.desvanecer`, `P.textura`, `Incendio.ardiendo`), NaN, textos. Arreglar lo GRAVE y lo MEDIO.
3. **Docs** (con las notas de abajo): `bichos.md`, `lobby.md`, `sonidos-pendientes.md` (MotorCoche) y una línea en
   `partida.md` o donde vaya la muerte (finales que no reviven, `Muerte.vivo`, `Muerte.sacar`, `Muerte.alMorir`).
4. **TASKS.md**: marcar 14.9.1-14.9.5 (hechos sin Studio) y la 14.9.6: ordenar "Pendientes para Studio" de lo más
   importante a lo menos con todo lo de esta sesión (los pasos de abajo y los de `correr.md`).
5. **PR** con las herramientas de GitHub (`mcp__github__create_pull_request`, base `main`), preguntar a Sergio antes
   de juntar. Desde la nube no se borran ramas: darle el comando.
6. **Resumen para Sergio**, en español y corto: qué se ha hecho, fallos arreglados por prioridad, qué probar en Studio
   (lo más importante primero), números a ojo, ideas no hechas y sonidos o imágenes que faltan.

Opcional (pedido por agentes, no hecho): `Muerte.vivo(jugador)` en vez de `table.find(Muerte.vivos(), jugador)` en
Postura, Movil, Taller, Bengalas, Recursos, Generador, Mochila, Coche, Incendio y Preparativos, y en la búsqueda de
presa de `Bestia.luau` (~397); un `Muerte.prepararEscena(j)` común para Coche.huir e Incendio.terminar.

## Notas para los docs

- **bichos.md, Cliente**: el tablero sale en un solo sitio, `MuebleRayo.tablero(zona) → (cf, tam, medido)` (todas las
  Vistas y el techo de PosturaVista); los que miden con rayos (Trepador, Bestia y los rayos de reserva del Imitador)
  usan `MuebleRayo.cajas`/`rayo`. Bestia: luz floja en la cara metida bajo el mueble (PointLight sin sombras, brillo
  0,5, alcance 4,5, a menos de 14 studs; 0 echada atrás, se quita al acabar; sin ella con Rendimiento) y el brazo que
  barre se cierra lo justo para no atravesar las patas (`MuebleRayo.choca`). Con Rendimiento, solo se animan hasta 120
  studs (sin él, 250; el Acechador 300). Escena de muerte: el remote Muerte trae el modelo; MuerteVista llama a
  `<Bicho>Vista.rugir(cabeza, modelo)`; sin modelo, el de la Cabeza más cerca en Bichos a menos de 16 studs.
  Comprobado con Lune: mismas poses antes y después (5 bichos, con y sin mesa) y mismas cajas del tablero.
- **bichos.md, Servidor**: Caza olvida olor, vistoEn y debajo al morir (`Muerte.alMorir`), no al revivir; el gateo lo
  deja si la presa muere de otra cosa (`Muerte.vivo`), y si muere en la última décima `matar` devuelve false y no
  espera. `Caza.pasoHacia` guarda el último camino y lo rehace solo si pasa 1 s (`RUTA_VIDA`), si el destino se mueve
  más de max(3, 1/5 de lo que falta) (`RUTA_MOVIDO`), si se acaba, si salta `Path.Blocked` o si fue en línea recta
  (banco `pulido-4`). `Casa.puertas()` devuelve una lista guardada y congelada.
- **bichos.md, Pendiente**: quitar la luz de la Bestia, juntar cajaTablero, Imitador con MuebleRayo, quienPilla, olor
  y Health. Se queda la idea de los atributos `Tablero` y `TableroTam` en cada zona Debajo (los pondría `Mapa.conHueco`
  y `MuebleRayo.tablero` los leería primero): `Model:GetPivot` sin PrimaryPart usa WorldPivot, que no llega bien al
  cliente, y entonces cae en silencio al saliente de 2.
- **lobby.md**: módulos nuevos `CocheCopia` (lo común de salida y llegada: copia, camino `plaza`/`enPlaza`/`curva`,
  `mover`, `tapar`/`destapar` del de verdad, varios a la vez; escondido tampoco choca) y `LlegadaVista`. Atributo del
  coche `Llegada` (hora del servidor a la que se para; lo pone Coches al vaciarse tras un viaje, antes de quitar
  `Salida`; mientras, prompt apagado y `subir()` rechaza). La llegada (22 s, `Coches.LLEGADA` = `LlegadaVista.DURA`):
  aparece en la niebla en z≈+240 por el carril x=3,5 con los faros, a 30 studs/s, frena 3,2 s, se pasa 2 studs, entra
  marcha atrás por el camino de salida al revés, avanza lo que el que sale da de marcha atrás, 1,2 s al ralentí, apaga
  y vuelve el de verdad. Carril de uno en uno: una Salida que pisaría una llegada se retrasa (cuenta atrás más larga) y
  una Llegada espera a la anterior. Si estás de pie en la plaza al acabar, te aparta. Con Rendimiento o lejos, sin
  adornos. Sentado en un coche, su "Get in" se apaga en ese cliente (CochesUi, banco `pulido-2`).
- **Muerte y finales**: mientras `workspace.Final` está puesto no se revive a nadie (Director lo salta al amanecer,
  `Revivir.puede` da false y se apaga `Revivible`); si el incendio fracasa y es de día, Incendio revive a todos. Antes
  de anclar a todos en los dos finales: `Muerte.sacar` a los escondidos, soltar lo cargado, cerrar la mochila y
  reajustar la velocidad. MuerteVista: el susto en pcall y la vuelta siempre; en un final no toca la cámara y corta el
  aliento y el latido. API nueva: `Muerte.vivo`, `Muerte.sacar`, `Muerte.alMorir`.
- **Textos**: `tests/regressions.luau` comprueba ahora que todo texto escrito en el código (literales de `Lang.t`,
  también con if/then/else, `ActionText`, `nuevoPrompt`, `acabar`, `Viaje.volver`, `avisar*`, `YA_HAY`, `USOS`, y
  `Config.Clases`, `Compras.Pases`, `Cosmeticos`) tiene su español. Un texto que llegue por otra tabla necesita su
  propio assert.
- **Cinemáticas**: mochila y móvil se cierran al empezar una y no se abren en ella; puntero del ratón escondido en la
  huida y el incendio; la linterna de los demás se apaga con la cámara Scriptable (salvo mirilla o escondido); la
  flecha y el contorno del tutorial se apagan con el Hud apagado o en cinemáticas; el tirón de los sustos se deshace
  antes de la cámara de Roblox y no toca la Scriptable.

## Pasos para Studio de la 14.9 (para ordenarlos en TASKS.md con los de `correr.md`)

Antes: en Edit, que Rojo ha sincronizado (buscar un texto nuevo en el `Source`); errores con
`LogService:GetLogHistory()` sin los `MessageOutput`. `game.ServerStorage.Prueba:Fire("Noche")` para empezar.
- **Muerte con el bicho que pilla**: debajo de la mesa del comedor en (-26.1, 3, -15) con un Raspador y un Golpeador a
  ~6 studs (PivotTo en Server); cuando el Raspador gatee (atributo `Gatea`) y pasen `Config.Postura.Gatear` s, la
  escena enfoca al Raspador en la pose de agarrar, no al Golpeador. Con un bicho gateando a por ti,
  `Character.Humanoid.Health = 0` en Server: en <0,2 s `Gatea`/`GateaHora` a nil y el bicho sigue su ronda. Morir
  debajo de un mueble oliéndote y revivir: vuelve a tardar `Config.Postura.Huele` s en olerte.
- **Gateos a mano** (paso 2 de `bichos.md`, "Probar en Studio") con Golpeador, Raspador, Imitador y Bestia (raíz en
  (-33, y, -15)), en el comedor y en la cocina (raíz en (-19.5, y, 10.5) mirando a (-19.5, y, 6.9); tú en (-19.5, 3,
  7)): nada atraviesa tablero, patas, caballetes ni viga; el brazo de la Bestia que barre no pasa por las patas.
  Imitador con `Gatea` fuera de la zona, bajo el voladizo (-27.9, 3, -15): la mano y la cara no entran en el tablero.
  Luz de la Bestia: `workspace.Bichos.Bestia.Cabeza:FindFirstChild("LuzGatea")` con brillo ~0,5 mientras gatea, sin
  ella con Rendimiento. NaN: el bucle de `bichos.md` paso 3 no imprime nada.
- **Rendimiento a 120 studs**: con Rendimiento y un bicho a 120-250 studs, su `Torso.Transform` (Bestia: `Lomo`) no
  cambia en 1 s; a menos de 120, sí.
- **Finales**: `Prueba:Fire("Quemar")` con un escondido (`Prueba:Fire("Esconder", <punto junto a un armario>)`) y la
  mochila abierta: en la escena no hay puntero, el escondido ha salido (sin latido; E no hace nada), todos `Anchored`
  y la mochila cerrada; al acabar vuelven el puntero y la cámara. Igual con la huida (Escape). Con un muerto,
  `Prueba:Fire("Dia")` mientras corre el fuego: no revive (`Muerto` sigue, `Final` puesto); al fracasar el fuego de
  día, revive. Con `workspace:SetAttribute("Final", true)` no sale el botón de revivir. Dos jugadores: que muera uno,
  huida con el otro y `Prueba:Fire("Dia")`: el revivido no aparece en mitad de la escena.
- **Móvil (emulador 640 × 360 y un iPhone 844 × 390)**: rejilla abajo FLASH, LINTERNA, MOCHILA, MÓVIL; arriba
  AGACHARSE, CORRER y BENGALA (solo con la pistola, sin mover a los demás); la barra del aguante debajo, sin chocar,
  también al girar. El móvil abierto no pisa la fila de arriba ni queda bajo la barra de Roblox ni tapa Acciones.
  Avisos: con un botón de acción en pantalla, el aviso largo (la reja) queda a su izquierda en una o dos líneas.
  Revivir con 2-3 jugadores: botones de 144 con nombre arriba y precio abajo; con un nombre de 20 letras se corta el
  nombre, nunca el precio. Ajustes: SÍ/NO y CERRAR de un dedo. Mochila: el engranaje no pinta encima. Tutorial: el
  texto del paso acaba antes de SALTAR. Taller y vendedor: con su papel abierto no asoma su botón de acción.
- **Textos**: con una foto, "1 PHOTO  +N" / "1 FOTO  +N"; con una bengala, "1 FLARE" / "1 BENGALA"; el aviso de la reja
  en una línea ("La reja está lista. Tira de la palanca de la trampilla.").
- **Cinemáticas**: abrir la mochila o el móvil y lanzar la huida (`Remotes.Huida:FireAllClients(20)` en Server): se
  cierran solos, no se abren con B o M durante ella, y al acabar sí. Mirar por la mirilla: la flecha del tutorial se
  apaga y vuelve; con dos jugadores, la linterna del otro no se ve suelta en la escena final. Sustos seguidos sin
  mover el ratón: la mirada vuelve exactamente a donde estaba.
- **Bichos y coste**: un Golpeador o Acechador por la casa y el bosque sigue el camino sin tirones y recalcula en ≤1 s
  si algo le tapa; sin errores de Caza al amanecer; Pathfinding cuesta menos (MicroProfiler) con 2-3 bichos. Trepador
  bajo una mesa grande y una pequeña: no mete cabeza ni rodillas y no hay tirón al empezar. Efectos (acechos tras una
  ventana, cortinas con un cristal roto, cristales que crujen, polvo del techo) sin errores.
- **Lobby, coche que llega** (lugar Lobby, `lobby.project.json` en el puerto 34873): en Client,
  `game.Players.LocalPlayer.Character:PivotTo(CFrame.lookAt(Vector3.new(22, 3.5, 30), Vector3.new(3.5, 2, 90)))`; en
  Server, `workspace.Coches.Coche2:SetAttribute("Llegada", workspace:GetServerTimeNow() + 22)`: el Coche2 desaparece,
  la copia sale de la niebla con los faros, entra marcha atrás sin tocar al Coche1 ni al Coche3 y a los 22 s se cambia
  por el de verdad sin salto; sin "Get in" mientras llega. Repetir con Coche1 y Coche4, con Rendimiento, con 2
  jugadores (lo ven a la vez) y de pie en la plaza (te aparta). Salida que pasa a llegada: `local c =
  workspace.Coches.Coche3; c:SetAttribute("Salida", workspace:GetServerTimeNow() + 7); task.delay(9, function()
  c:SetAttribute("Llegada", workspace:GetServerTimeNow() + 24); c:SetAttribute("Salida", nil) end)`. Carril ocupado:
  durante una llegada, arrancar otro coche: su cuenta atrás es más larga y no sale hasta que el otro para.
  `workspace.CochesSaliendo` vacía al acabar. Sentado en un coche no sale su "Get in"; al bajarte, sí.

## Números a ojo nuevos (para el resumen)

`Config.Correr` (todo; `Andando` 1/12), cámara (`CORRE_SUBE` 0,9, `CAMPO` 7), manos (`ManosCorrer.BRACEO.delante`,
`JADEO.pos`), escondido (`ESCAPA_PROB` 0,3), `Config.Acechador.Persigue` 22 (subir a ~26 si solo debe salvar la luz),
la clase Corredor deja atrás a todos corriendo bien; `LEJOS_RENDIMIENTO` 120; luz de la Bestia 0,5 / 14 / 4,5;
`CERCA_SUSTO` 16; Caza `RUTA_VIDA` 1 s y `RUTA_MOVIDO`; lobby: llegada 22 s, 30 studs/s, carril 6 s y 16 s.

## Ideas no hechas (para el resumen)

Las de `correr.md`; atributos `Tablero`/`TableroTam` en las zonas Debajo; que los bichos oigan tu jadeo escondido;
`Muerte.prepararEscena` común; luces de la cara de Bestia e Imitador solo de noche; repartir el carril del lobby por
zonas; luz de marcha atrás y ruido de ruedas mojadas; que la copia del coche esquive a quien se ponga delante; las de
`economia.md` (diario cada 20 h o por día, logros Noche3/Noche7, primer día más corto, más cosas que comprar).
