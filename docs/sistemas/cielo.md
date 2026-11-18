# Cielo: hora, sol, alba y ocaso

`src/juego/cliente/Ambiente.luau`, solo en el cliente. Lee los atributos del Ciclo del `Workspace` (`Fase`, `FaseInicio`, `FaseFin`) y pinta cada fotograma. Números en `Config.Cielo`, a ojo.

- `Ambiente.hora(fase, p)`: cuánto de noche (`k`) y la hora (`ClockTime`). Día de 6,5 a 18,5 (`k` sube en el último 20 %); noche de 18,5 a 6,5, deprisa hasta medianoche, casi quieta con la luna alta y hacia el alba en el último 10 %.
- `Ambiente.sol(hora)`: 0 con el sol bajo el horizonte, 1 con el sol alto, 0,5 justo en `Sol.Sale` / `Sol.Pone` (rampas de `Margen` horas a cada lado). Ajustar `Sale` y `Pone` mirando `Lighting:GetSunDirection().Y` en Studio.
- La exposición sigue al **sol**, no a `k`: al atardecer no sube hasta que el sol baja de `Sol.Pleno` (sin pico de luz antes de "NIGHT n") y al amanecer no baja hasta que el sol empieza a salir (antes caía con el sol aún abajo y los últimos segundos de la noche eran los más negros). El `Brightness` de noche (luna) solo entra `Sol.Luna` horas después de ponerse el sol del todo: con sol nunca pasa del de día. Lámparas, `Ambient` y niebla siguen con `k`.
- `Ambiente.franja(hora, nublado)`: campana de `Alba.Ancho` horas alrededor de la salida y la puesta (máxima con el sol en el horizonte, 0 a pleno día y plena noche). Lleva la niebla (`Color` más que `Decay`), algo del `OutdoorAmbient` y el tinte de la imagen hacia `Alba.Amanecer` (cálido apagado) o `Alba.Atardecer` (rojo apagado); un poco de `Glare` y algo menos de gris. Sin Bloom.
- Cielo cubierto: atributo `Nublado` del `Workspace` (0 a 1) apaga la franja (amanecer gris). Aún no lo pone nadie: queda para el clima. En la escena final (`EscenaFinal` del jugador) tampoco hay franja: la luz la lleva la escena.
- `Ambiente.valores(fase, p, nublado)`: todo lo que se pinta, sin tocar nada (rellena siempre la misma tabla). Lo prueba `tests/bancos/cielo.luau`.
