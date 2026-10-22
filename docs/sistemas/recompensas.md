# Monedas que se ganan (paso 10.1)

Números a ojo, en `Config.Recompensas`.

- `comun/servidor/Recompensas` (en los dos lugares) y sus cuentas en `Premio` (sin Roblox, probadas con Lune). Sin remotes: todo lo decide el servidor; el cliente ve el atributo `Monedas` y un aviso de una línea.
- Amanecer: `Director` pasa cada cambio de fase a `Recompensas.fase`. Paga solo el paso de la noche n-1 al día n, una vez por servidor y noche: el primer día (al arrancar o cargar), volver al día tras morir todos y `forzar` del modo de pruebas no pagan. Cobran todos los que estén, vivos o muertos: `Noche` + `PorNoche` por cada noche más (tope `TopeNoches`) y los logros de noche (`Noche1`, `Noche5`, `Noche10`) si aún no los tenían.
- Final: `Coche` al huir llama a `Recompensas.final`: `Final` + logro `Huida`; se cobra ya y el aviso sale al acabar la escena.
- Diario: al entrar (con `DatosListos`), en el lobby o en el juego, si han pasado `Cada` s desde `datos.diario` (hora del servidor). Una hora guardada de más de un día en el futuro no bloquea.
- Logros: `datos.logros[nombre] = true`, se cobran una vez. Se guarda el nombre: no renombrar los de `Config`.
- Todo lo ganado se guarda enseguida en los datos del jugador (`Datos.guardar`), aunque la partida no llegue a guardarse.
- Modo de pruebas: `ServerStorage.Prueba:Fire("Saltar")` acaba la fase de ahora como si se hubiera acabado el tiempo (de noche = amanecer que paga).

## Probado en Studio (22-10-2026)

- Diario +50 al entrar; noche 1 → amanecer +75 (25 + logro `Noche1`); forzar el día sin pasar la noche no paga; noche 2 → amanecer +30. Sin errores.
- Sin probar: el final de la huida con monedas (misma función de cobro) y el diario contra el DataStore real.
