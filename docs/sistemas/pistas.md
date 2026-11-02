# Pistas de la historia (12.1)

Textos aprobados por el usuario en `docs/historia.md` (no cambiarlos sin él). En el juego, en inglés en `shared/Historia` (`que`, `texto`, `forma`) y su español en `LangEs`. Se guardan por su número: no reordenar, lo nuevo al final.

## Servidor (`Pistas`)

- Cada pista es un modelo `Pista<n>` (etiqueta `Pista`, atributo `N`) en `workspace.Mapa.Pistas`, con un prompt "Read" (E, `Config.Casa.Alcance` como los demás, estilo Custom que pinta `Controles`, sin línea de visión). Formas: nota (papel con renglones; la de la iglesia, clavada en la pared), foto (borde blanco y la imagen oscura), libreta o diario abiertos. Mancha de sangre en la 4, la 6 y la 9.
- Sitios en `SITIOS` (mismo orden que `Historia`). La 10 (nota del cuarto de revelado), la 11 (diario del escritorio del rico) y la 12 (caja fuerte, "Open") ya están en los muebles de `Mapa`: solo llevan el prompt en una pieza invisible (`YA_HAY`).
- La 9 (sótano) está encima del banco del taller, a la izquierda (sitio dado por la 11.8.13).
- Al leerla, el servidor comprueba vivo, cerca (`Alcance` + 4 studs de holgura), 0,3 s entre lecturas y, en las salas con llave (9 a 12), que su puerta ya esté abierta (el prompt atraviesa paredes; `SALA`); la apunta y manda `Remotes.Pista` (n, cuántas van). No hay remote de vuelta.
- `Pistas.leida(n)`: para el final (12.2: plano de la reja, cerillas).

## Guardado

- `FormatoPartida.pistas`: lista de números leídos (sin subir versión; lo viejo sin el campo = ninguna). Arreglar quita repetidos, rotos y los que no existen. `Partida` la exporta en la foto y la pone al cargar y al volver al amanecer (si mueren todos, lo leído ese día se pierde, como todo lo demás).

## Cliente (`PistasUi`)

- Papel oscuro en el centro con la esquina de sangre: arriba en rojo lo que es, el texto, abajo "3 de 12" pequeño y CERRAR. Alto según el texto. Suelta el ratón. Se cierra con CERRAR, con E otra vez en la misma pista, al alejarse (11 studs) o al morir.

## Probado en Studio (02-11-2026)

- Con la habitación del rico cerrada, la 12 no se lee; la 1 sí.
- Las 12 salen en su sitio (capturas de la cocina, el escritorio, la caja fuerte, la iglesia, el aserradero y el desván). Leer la 1, la 2 y la 12 ("1/2/3 de 12", en español); E otra vez cierra; alejarse cierra. Guardar → leer la 3 ("4 de 12") → Cargar → leer la 1: "3 de 12". Sin errores.
- En una mesa con una lata al lado, el prompt que sale es el de lo que se mira: hay que mirar al papel.
- Lune: 637 comprobaciones bien (12 pistas traducidas, un sitio por pista, guardado viejo, roto y bueno).

## Pendiente

- Sonido de papel al leer (ElevenLabs, lo elige Sergio).
- Sitio final de la 9 cuando el sótano esté amueblado.
