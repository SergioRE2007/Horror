-- Rendimiento sugerido en el móvil (16.9): solo si el jugador nunca lo eligió, solo un booleano, una sola vez, y los
-- datos de antes (sin rendimientoElegido) siguen cargando bien. Ejecutar desde la raíz:
-- lune run tests/bancos/ajustes-rendimiento.luau (también lo lanza tests/regressions.luau).
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local Formato = luau.load(fs.readFile("src/comun/servidor/Formato.luau"), { debugName = "Formato" })()

local comprobaciones = 0
local function igual(actual, esperado, etiqueta: string)
	assert(actual == esperado, `{etiqueta}: esperado {tostring(esperado)}, recibido {tostring(actual)}`)
	comprobaciones += 1
end

-- Cuenta nueva: sin elegir; la sugerencia lo activa y ya no vale otra.
local nuevo = Formato.arreglarJugador(nil)
igual(nuevo.rendimiento, false, "nuevo empieza apagado")
igual(nuevo.rendimientoElegido, false, "nuevo sin elegir")
igual(Formato.sugerirRendimiento(nuevo, true), true, "sugerencia aceptada")
igual(nuevo.rendimiento, true, "sugerencia lo activa")
igual(Formato.sugerirRendimiento(nuevo, false), false, "segunda sugerencia rechazada")
igual(nuevo.rendimiento, true, "sigue activo")

-- Lo que no es booleano no vale.
local otro = Formato.jugadorNuevo()
igual(Formato.sugerirRendimiento(otro, "si"), false, "texto rechazado")
igual(Formato.sugerirRendimiento(otro, 1), false, "número rechazado")
igual(Formato.sugerirRendimiento(otro, nil), false, "nil rechazado")
igual(otro.rendimientoElegido, false, "sigue sin elegir")

-- Ya elegido con el botón (apagado): la sugerencia no lo toca.
local elegido = Formato.jugadorNuevo()
elegido.rendimientoElegido = true
igual(Formato.sugerirRendimiento(elegido, true), false, "elegido no se sugiere")
igual(elegido.rendimiento, false, "elegido sigue apagado")

-- Datos de antes de 16.9: activado cuenta como elegido; apagado se puede sugerir.
local viejoSi = Formato.arreglarJugador({ version = 1, monedas = 5, rendimiento = true })
igual(viejoSi.rendimientoElegido, true, "viejo activado = elegido")
igual(Formato.sugerirRendimiento(viejoSi, false), false, "viejo activado no se toca")
igual(viejoSi.rendimiento, true, "viejo sigue activado")
local viejoNo = Formato.arreglarJugador({ version = 1, monedas = 5, rendimiento = false })
igual(viejoNo.rendimientoElegido, false, "viejo apagado sin elegir")
igual(viejoNo.monedas, 5, "viejo conserva monedas")
-- Campo roto: se arregla a false.
igual(Formato.arreglarJugador({ rendimientoElegido = "x" }).rendimientoElegido, false, "campo roto")

print(`ajustes-rendimiento: {comprobaciones} comprobaciones bien`)
