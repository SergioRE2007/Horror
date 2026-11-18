-- Banco de Config.Test (16.21): que no se suba al repositorio un valor de pruebas puesto un momento en Studio (CLAUDE.md:
-- "no subir valores de Config bajados temporalmente para probar"). Ejecutar desde la raíz:
-- lune run tests/bancos/config-test.luau (lo corre regressions.luau).
-- Cada campo de Config.Test tiene aquí lo que debe valer al subir. La referencia son los que están apagados hoy:
--   - Apagados (nil o false): los que cambian cómo se prueba en la sesión siguiente (idioma, jugadores, dueño, clase,
--     pases, partida nueva y tutorial). Si se encienden para probar algo, se apagan antes del commit.
--   - Activo = true a propósito: el modo de pruebas solo actúa en Studio y así una partida de Studio nunca guarda (en
--     un lugar publicado sí podría). Apagarlo es probar con los datos de verdad.
--   - Monedas, Dia y Noche: se quedan subidos a propósito (probar sin esperar), solo se mira que tengan sentido.
-- Un campo nuevo en Config.Test hace fallar el banco hasta decidir aquí qué debe valer.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local Config = luau.load(fs.readFile("src/shared/Config.luau"), { debugName = "Config" })()
local T = Config.Test
assert(type(T) == "table", "falta Config.Test")

local cuentas = 0
local fallos: { string } = {}
local function mira(cumple: boolean, texto: string)
	cuentas += 1
	if not cumple then
		table.insert(fallos, texto)
	end
end
local function positivoONil(v: any): boolean
	return v == nil or (type(v) == "number" and v > 0 and v < math.huge)
end

-- [campo] = cómo debe estar al subir (y la frase si no lo está).
local REGLAS: { [string]: { any } } = {
	Activo = { function(v)
		return v == true
	end, "true (si no, una partida de Studio guarda en el DataStore de verdad)" },
	Monedas = { function(v)
		return type(v) == "number" and v >= 0 and v < math.huge
	end, "un número de 0 en adelante" },
	Lang = { function(v)
		return v == nil
	end, "nil (fuerza el idioma en Studio)" },
	Dia = { positivoONil, "nil o segundos > 0" },
	Noche = { positivoONil, "nil o segundos > 0" },
	Jugadores = { function(v)
		return v == nil
	end, "nil (fuerza la fila de Config.Dificultad)" },
	Dueno = { function(v)
		return v == nil
	end, "nil (dueño falso de la partida)" },
	Clase = { function(v)
		return v == nil
	end, "nil (fuerza una clase)" },
	Pases = { function(v)
		return v == false
	end, "false (da todos los pases sin pagar)" },
	Ranura = { function(v)
		return v == 1
	end, "1 (la primera ranura)" },
	Nueva = { function(v)
		return v == false
	end, "false (empieza de cero aunque haya algo guardado)" },
	Partidas = { function(v)
		return type(v) == "table"
	end, "una tabla (lo que el lobby enseña como guardado)" },
	Tutorial = { function(v)
		return v == false
	end, "false (saca el tutorial en Studio)" },
}

for campo, regla in REGLAS do
	local valor = T[campo]
	mira((regla[1] :: (any) -> boolean)(valor), `Config.Test.{campo} = {tostring(valor)}: al subir debe ser {regla[2]}`)
end
-- Los campos que no están en REGLAS: o se ha escrito mal o es nuevo y hay que decidir aquí cómo va al subir.
for campo in T do
	mira(REGLAS[campo] ~= nil, `Config.Test.{campo}: campo nuevo, decidir en tests/bancos/config-test.luau cómo va al subir`)
end
-- Los que se pueden quedar en nil no salen al recorrer la tabla: que sigan escritos en Config (con su comentario).
local fuente = fs.readFile("src/shared/Config.luau")
local bloque = string.match(fuente, "\nConfig%.Test = (%b{})") or ""
for campo in REGLAS do
	mira(string.find(bloque, "\n%s*" .. campo .. "%s*=") ~= nil, `Config.Test.{campo}: ya no está en Config (quitarlo de aquí)`)
end

if #fallos > 0 then
	error("Config.Test:\n  " .. table.concat(fallos, "\n  "), 0)
end
print(`Config.Test bien: {cuentas} comprobaciones.`)
