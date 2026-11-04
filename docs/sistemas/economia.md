# Ritmo y economía (14.9.5)

Repaso hecho sin Studio (04-11-2026) con `tests/bancos/economia.luau`, que usa las cuentas de verdad (`Premio`, `Comprar`, `Formato`) y `Config` tal cual. Lo que no está en `Config` son supuestos a ojo, todos en la tabla `S` del banco: cambiarlos ahí cuando se vea jugar a alguien (14.5). **Config no se ha tocado**: la propuesta de abajo la decide Sergio en la 14.5.

## Supuestos (a ojo)

- 90 s del lobby a la casa (tienda, coche, teletransporte) y 30 s de vuelta tras un final.
- Probabilidad de que mueran todos en la noche n: solo 8 % + 3 % por noche (tope 45 %); con dos, 5 % + 2,5 % (tope 35 %). Una noche perdida dura un 60 % y se repite el día.
- Huida tras superar la noche 8 (solo) o 6 (con dos). Bestia en la noche 13 (solo) u 11 (con dos), 30-40 % de morir en ella.
- Semana: 30 min al día, empezando a horas algo distintas (17:30-19:00). Partidas seguidas: la 1.ª acaba huyendo, la 2.ª con la Bestia… Compra en orden (clases y luego luces, de la más barata) y ahorra para la siguiente.

## Cuentas (lo que sale hoy)

**Ciclo:** 3 min de día + 4 de noche = 7 min por noche. En 30 min caben 4 noches. Huida a los ~69 min solo y ~49 con dos (2-3 sesiones); Bestia a ~2 h.

**Monedas por noche:** 25, 30, 35… hasta 75 desde la noche 11. La 1.ª vez, logros: noche 1 +50 (+100 del tutorial = 175), noche 5 +150, noche 10 +400. Huida 300 (+250 la 1.ª vez), Bestia 600 (+500).

| | solo | con dos |
|---|---|---|
| 1.ª partida (huida), jugador nuevo | 1190 monedas en 69 min | 1075 en 49 min |
| Monedas/min huyendo · Bestia · quedarse en la noche 11+ | 9,2 · 10,5 · 7,2 | 10,6 · 12,0 · 8,0 |
| Semana (30 min/día) | 3515 | 3775 |
| Para la 2.ª clase | a los 38 min de juego; la compra el día 3 (la tienda está en el lobby) | igual; la compra el día 2 al volver de la huida |
| Todas las clases | día 7 | día 5 |
| Todo el catálogo (2800 tras la clase gratis) | día 7 | día 5 |
| Premios diarios cobrados | 4 de 7 | 4 de 7 |

- Lo que va bien: la 1.ª clase es gratis en el minuto 0; acabar una partida rinde más que quedarse en las noches altas (empuja a terminar, como pide el diseño); nada de Robux hace falta para los dos finales; con dos jugadores cada uno cobra lo mismo (también el invitado).
- Los días tras un final pagan poco (solo: 120 el día 4; con dos: 90 el día 6): la partida nueva vuelve a 25 por noche y ya no hay logros.

**Primeros 5 minutos:** +50 del diario y la clase gratis en el lobby; luego nada hasta el primer amanecer, en el minuto 8:30. Lo que engancha en esos minutos es el tutorial y que se haga de noche (minuto 4:30).

**Robux** (todo se cumple en el banco):

- Paquetes: 49 R$ → 300 (6,1 por R$), 129 → 900 (7,0), 299 → 2400 (8,0). Una clase ≈ 66 R$.
- Revivir 25 R$ ≈ 153 monedas; el reembolso es de 150: cuadra.
- 4 pases, sin llaves, piezas ni noches. Ninguno vende la ventaja de una clase. LinternaMejor es ×1,5 de pila y ×1,25 de luz: una comodidad. Solo no se puede revivir (morir solo = mueren todos).
- Paquete de inicio (99 R$ = 1000 monedas + la luz violeta, ~14 por R$): todas las clases el día 3 en vez del 7. Pagar solo acelera.

## Problemas que salen

1. **El premio diario se pierde:** pide 24 h justas desde el último, así que jugar a las 17:30 tras haber jugado a las 18:00 no lo da (4 de 7 en la semana). Para la retención D1 es lo peor que hay.
2. **La 2.ª clase llega tarde para el D1:** el día 1 da 330 monedas, menos de 400. Jugando solo la segunda clase se compra el día 3.
3. **Catálogo corto:** 2800 monedas de compras contra ~3500 a la semana. Desde la 2.ª semana las monedas ya no sirven para nada, y los paquetes de monedas tampoco.
4. **Primer premio tarde:** minuto 8:30 desde que entra (la mitad de los nuevos se va en 5 min).

## Propuesta (a ojo, para la 14.5)

Lo marcado con (banco) está simulado en el apartado 5 del banco, sin tocar `Config`. Con todo: 7 diarios de 7, la 2.ª clase al entrar el día 2, todas las clases el día 6 (solo) o 5 (con dos), ~4040 / 4300 monedas a la semana.

1. **Diario cada 20 h** (`Recompensas.Cada = 72000`) (banco). Así perdona jugar un poco antes. Mejor aún, por día del calendario (cambio pequeño en `Premio.diario`). Y quizá una racha de 7 días (50, 75, 100…) más adelante.
2. **Más por la 1.ª noche y el tutorial:** logro `Noche1` 50 → 100 y `Tutorial` 100 → 150 (banco). El día 1 da 430: al volver el día 2 se estrena clase nada más entrar, que es el mejor gancho para el D1.
3. **Logros en las noches de bicho nuevo:** `Noche3` = 75 (llega el Raspador) y `Noche7` = 200 (el Trepador) (banco), nuevos al final de `Logros`. Celebran el hito y rellenan el hueco de los días 4-6.
4. **Primer día más corto:** 120 s en vez de 180 solo en el día 1 de cada partida (banco). La noche llega en el minuto 3:30 y el primer premio en el 7:30. Necesita un número nuevo en `Config.Ciclo` (p. ej. `PrimerDia`) y una línea en `Ciclo`. La noche 1 no se acorta: es donde está el miedo.
5. **Más cosas en que gastar antes de publicar** (sin banco: no existen aún). Son las del diseño: pinturas del coche (300-800), cámaras de colores (200-500), efectos del flash (500-1000) y ropa, ~5000-8000 monedas más. Más adelante, niveles de clase. Sin esto, las propuestas 1-3 vacían el catálogo aún antes.
6. **Sin cambios:** precios de las clases (400) y de las luces, finales, paga por noche, Robux y pases. Si con la propuesta 5 hay mucho más que comprar, quizá subir el paquete de 49 R$ a 350 monedas (que no se quede corto para una clase con el diario).

## Qué mirar en la 14.5 (y con jugadores)

- Cuántas noches se tarda de verdad en huir y en matar a la Bestia, y cuántas se pierden: corregir `S.Huida`, `S.Bestia` y `S.Perder` del banco.
- Minuto del primer amanecer y cuántos se van antes. Retención D1 y D7, y si vuelven el día 2 a comprar clase.
- Monedas guardadas sin gastar a los 7 y 14 días (si suben sin parar, faltan cosas que comprar).
- Qué compran primero (clase o luz) y cuántos compran el paquete de inicio.
