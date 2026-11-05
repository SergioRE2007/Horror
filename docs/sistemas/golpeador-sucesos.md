# Sucesos al azar del Golpeador (14.10)

Pedido por el usuario: "que no sea siempre igual". El servidor decide (`juego/servidor/GolpeadorSucesos.luau`, tiradas en
`GolpeadorTiradas.luau`) y lo pone en atributos del modelo; el cliente (`GolpeadorVista`) lo anima. Nunca injustos:
durante un suceso no pilla a nadie y ninguno pilla a través de paredes.

- Cada suceso sale con su `Probabilidad` (Config.Golpeador.Sucesos) en cada ocasión, y como mucho **una vez por noche
  entre todos los Golpeadores**. Se olvida al cambiar de noche y al volver a empezar el día (`Golpeador.quitar`).
- Atributos del modelo: `SucesoHora` (se pone antes que `Suceso`), `SucesoDura`, `SucesoMira`, `SucesoLado` (solo
  Garras) y `Suceso`. Siempre a nil al acabar, también si falla, amanece, le aturden o se quita.
- Gancho en Caza (`b.alCazar`, momentos "Ronda", "Sala" y "Presa"): los demás bichos no lo llevan y siguen igual.
- Tras pillar, Caza espera `Opciones.Espera` (el Golpeador: `Config.Golpeador.Susto.Espera`; los demás, 2,5 s).

| Suceso | Cuándo | Qué hace |
|---|---|---|
| Cara | Al llegar a una ventana con el cristal entero y la cortina abierta | Se arrima (raíz a 2,2 del cristal: desde Fuera no llegaba) y pega la cara `Dura` s. Si le alumbras o le miras de cerca (< `Distancia`, de frente) más de `Mirado` s: "Aparta" (0,6 s). Luego golpea normal |
| Llama | Al llegar (si no hubo Cara), nunca a una ventana o puerta rota o abierta | `Toques` toques con un dedo (remote `Golpeador` "Toque", el toque i a (i − 0,5) × `CadaToque` s) y espera. Si le abren la puerta o la cortina mientras, entra en el primer golpe |
| Finge | Se cansa sin entrar | Se aleja 28 studs, se para mirando atrás `Mira` s, vuelve corriendo y golpea `MasPaciencia` × su paciencia más. Si ve a alguien fuera, le caza |
| Armario | De ronda, a < `Cerca` de un armario con alguien dentro (que no le vio esconderse) y a la vista | Se pone ~3,3 studs delante de la puerta (inclinado, la cara llega a las rendijas) y mira `Dura` s; luego sigue. Solo armarios (`Tipo` = "Armario"), no camas |
| Olfatea | Al llegar a una sala de ronda | Quieto `Dura` s oliendo hacia el jugador más cercano de la casa |
| Garras | De ronda, con una pared a < `Pared` studs de lado (que siga 2 studs más) | Sigue andando `Dura` s arrastrando las garras (no se para) |
| Quieto | Le alumbras con la linterna desde > `Lejos` studs | Quieto `Dura` s mirándote; luego va a por ti sabiendo dónde estás (aunque te escondas mientras) |

Números de Config a ojo; los locales (28 studs de Finge, 30° para "le mira", 5 y 6 s entre ocasiones de Garras y
Quieto) también, en `GolpeadorSucesos.luau`.

## Órdenes de prueba (modo de pruebas, Studio)

`ServerStorage.Prueba:Fire("Suceso", "Armario")` o, desde el MCP, `Prueba:SetAttribute("Punto", "Armario")` y luego
`Prueba:SetAttribute("Orden", "Suceso")`: la próxima ocasión de ese suceso sale seguro, aunque ya haya salido esa noche.
Luego `Orden = "Ataque"` (con `Punto` = un Vector3 cerca de la ventana) para que venga uno.

## Probar en Studio

- Cara: forzar, ventana con la cortina abierta, ataque a esa ventana; mirarle de cerca 1,5 s o alumbrarle: se aparta.
- Llama: forzar, ataque a una puerta; abrirla durante los toques: entra al momento.
- Finge: forzar, cortina cerrada hasta que se canse: se va, se para, mira y vuelve corriendo.
- Armario: forzar, esconderse en un armario (orden "Esconder") antes de que entre; debe pararse delante sin pillarte.
- Olfatea, Garras, Quieto: forzar y dejar que entre (Quieto: alumbrarle desde lejos por un pasillo).
- Banco de Lune: `tests/bancos/golpeador-sucesos.luau` (tiradas, una vez por noche, forzar, reiniciar).
## Probado en Studio (05-11-2026)

- Cara: se pega al cristal (cara a 0,9 studs) y, mirándole desde dentro, se aparta a los 1,7 s.
- Armario: escondido, se para delante 4 s mirando por las rendijas y se va sin pillarte; luego Olfatea en otra sala.
- Llama llamaba al hueco de una ventana rota: arreglado (ver tabla).
- Sin errores en la Salida. Falta verlos a mano: Garras, Quieto, Finge, Llama en una ventana entera y con Rendimiento.
- Para probar con un solo jugador: al morir el único, el día vuelve a empezar a los Config.Ciclo.Reinicio s.
