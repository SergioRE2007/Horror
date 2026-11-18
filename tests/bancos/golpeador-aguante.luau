-- Banco del aguante del Golpeador (16.2): jugando solo no debe golpear más rato que con cuatro jugadores.
-- Ejecutar desde la raíz: lune run tests/bancos/golpeador-aguante.luau (lo corre regressions.luau).
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local function cargar(ruta: string)
	return luau.load(fs.readFile(ruta .. ".luau"), { debugName = ruta })()
end

local Config = cargar("src/shared/Config")
local Dificultad = cargar("src/shared/Dificultad")
local tabla = Config.Dificultad

local cuentas = 0
local function aguante(jugadores: number): number
	return Dificultad.aguanteGolpeando(Dificultad.de(jugadores, 0, tabla).paciencia)
end

-- Con 2 y 3 jugadores, como antes (x1); con 4, como antes (x0,85).
assert(aguante(2) == 1 and aguante(3) == 1, "2 y 3 jugadores: aguante normal")
assert(math.abs(aguante(4) - 0.85) < 1e-9, "4 jugadores: como antes")
-- Solo: nunca más que con cuatro ni que con dos.
assert(aguante(1) <= aguante(4), "solo golpea más rato que con cuatro")
assert(aguante(1) < aguante(2), "solo golpea más rato que con dos")
-- Más paciencia nunca da más aguante, sea cual sea la fila.
local previo = math.huge
for p = 0.5, 3, 0.05 do
	if p > 1 then
		assert(Dificultad.aguanteGolpeando(p) <= previo + 1e-9, `más paciencia, más aguante en {p}`)
	end
	previo = if p >= 1 then Dificultad.aguanteGolpeando(p) else previo
end
assert(Dificultad.aguanteGolpeando(1.25) < 1, "paciencia 1,25 recorta el aguante")
cuentas += 6
print(`golpeador-aguante: {cuentas} comprobaciones.`)
