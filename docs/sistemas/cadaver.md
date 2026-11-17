# Cuerpos que caen de verdad

Pedido por el usuario (noviembre de 2026): "mejorar la inmersión del juego... mejorar las animaciones". Antes, al pillar
un bicho a otro jugador, su personaje se deshacía en piezas sueltas (lo de serie de Roblox). Ahora cae como un muñeco de
trapo y se queda tirado hasta que revive.

## Cómo va

- Servidor (`juego/servidor/Muerte`, `alEntrar`): `BreakJointsOnDeath = false` en cada personaje, como ya tenían los
  bichos. Al morir se queda entero para que cada cliente lo copie. Nada más cambia en el servidor.
- Cliente (`juego/cliente/CadaverVista`, solo adorno, cada uno con lo que ve):
  - Remote `Muerte` (con la cabeza del bicho): el personaje de verdad se esconde (`LocalTransparencyModifier`, sin
    chocar ni rayos ni nombre encima) y en su sitio sale una copia del avatar con su ropa (se queda su `Humanoid`, sin
    hacer nada: sin él no se ve la ropa). Sin scripts, sonidos, luces, herramientas, raíz ni etiquetas.
  - Cada `Motor6D` pasa a ser un `BallSocketConstraint` con límites (`Config.Cadaver.Juntas`: cono y giro de cuello,
    cintura, hombros, codos, muñecas, cadera, rodillas y tobillos; R15 y R6 por el nombre). El eje va a lo largo del
    hueso y la pose del momento es la de reposo. Cada junta lleva un `NoCollisionConstraint` y rozamiento (`Friccion`).
  - Sale despedido hacia el lado contrario del bicho (`Empuje`, `Salto`, el tronco girando hacia atrás), choca, se dobla
    y, quieto o a los `Anclar` s (con Rendimiento, `AnclarRendimiento`), se anclan todas sus piezas, sin chocar (no
    corta un pasillo). Al frenar de golpe suena `CuerpoCae` en 3D.
  - El grito `GritoMuerte` en 3D desde el cuerpo (Oído lo tapa con las paredes). No en tu propia muerte (ahí ya está
    el susto de MuerteVista).
  - El charco de MuerteVista (etiqueta `Charco`, sin tocar MuerteVista): se esconde mientras vuela el muñeco y al
    pararse se pone bajo su pecho y crece de `Charco.Desde` a `Charco.Tam` en `Charco.Crece` s (un tween nuevo manda
    sobre el de MuerteVista). Lo demás de la sangre (MarcasVista, HuellasVista) no cambia.
  - Linterna encendida al morir (atributos `Linterna` y `PuestoLinterna`): cae de la mano izquierda, rueda
    `Linterna.Rueda` s y se queda en el suelo alumbrando a un lado con su color, más floja que en la mano y con el haz
    parpadeando a tirones, cada vez más al final; a los `Linterna.Dura` s se apaga y se queda tirada.
  - Se borra (muñeco y linterna) con el `CharacterAdded` nuevo (revive al amanecer o con Revivir) o si se va. La sangre
    se queda (MuerteVista la limpia al amanecer).
  - Tope: `Tope` muñecos moviéndose a la vez; con uno más, el más viejo se ancla tal como está.
  - Tu muerte: el muñeco no sale hasta que acaba el susto (la cámara deja de ser `Scriptable`), para no taparlo, y cae
    con `FuerzaPropio` desde donde quedó el cuerpo. Tu cuerpo de verdad se ancla (la física es tuya) y se vuelve a
    esconder cada vez que la cámara cambia de sujeto (la de Roblox lo enseña al cambiar).
  - Muertes sin remote: a los `SinAviso` s del `Died`, el muñeco donde está, sin empuje. Al entrar con alguien ya
    muerto, igual.
- Rendimiento: se ancla a los 1,5 s y la linterna cae ya quieta en el suelo y sin sombras.
- Un solo `Heartbeat`, conectado solo mientras algo se mueve (muñecos sin anclar, linternas encendidas, tu muñeco
  pendiente); el brillo de una linterna solo se toca a menos de `Linterna.Cerca` de la cámara.
- Gore sin pasar de Moderate: cuerpo entero y sangre, nada de restos.
- Sonidos pendientes (Id 0): `GritoMuerte` (mientras, `Susto` a tono 0,8), `CuerpoCae` (mientras, `Retumbo` flojo y
  agudo), `LinternaCae` (mientras, nada). Filas 36-38 de `sonidos-pendientes.md`.
- Banco: `tests/bancos/cadaver.luau` (sin física: mira la copia, las rótulas, los tiempos, el charco, la linterna, el
  tope, Rendimiento, revivir, tu muerte y la muerte sin remote).

## Probar en Studio

Sin probar todavía en Studio (hecho sin él). Con dos jugadores (Test → 2 jugadores):

1. Que un bicho pille a uno con la linterna encendida. Desde el otro: el cuerpo sale despedido lejos del bicho, se
   dobla al caer (rodillas y codos sin girar al revés), se para y el charco crece debajo del pecho en ~8 s. Ni piezas
   sueltas ni el personaje de verdad a la vista (ni su nombre).
2. La linterna rueda un poco y alumbra el suelo de lado, parpadeando; a los 40 s se apaga. Desde otra sala se ve la luz
   por el pasillo.
3. Desde lejos se oye el grito tapado por las paredes (con `Susto` mientras falte `GritoMuerte`).
4. Revivir (Revivir o al amanecer): el muñeco y la linterna desaparecen; la sangre sigue.
5. Desde el que muere: el susto se ve limpio (sin el muñeco delante de la cámara) y, mirando a los vivos, su cuerpo
   tirado donde cayó.
6. Con Rendimiento: se para antes y la linterna cae quieta. Mirar que el muñeco no tiemble ni salga volando (si pasa,
   bajar `Empuje` o subir `Friccion`) y que la ropa se vea (si no, el `Humanoid` de la copia).
