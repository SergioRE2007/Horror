-- Límite de ritmo de los remotes (16.16): src/comun/servidor/Limite con un reloj falso, y que cada intervalo de
-- Config.Limites exista y lo use algún remote del servidor. Ejecutar desde la raíz: lune run tests/bancos/limite.luau
-- (también lo lanza tests/regressions.luau).
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local comprobaciones = 0
local function igual(actual, esperado, etiqueta: string)
	assert(actual == esperado, `{etiqueta}: esperado {tostring(esperado)}, recibido {tostring(actual)}`)
	comprobaciones += 1
end

local Limite = luau.load(fs.readFile("src/comun/servidor/Limite.luau"), { debugName = "Limite" })()
local Config = luau.load(fs.readFile("src/shared/Config.luau"), { debugName = "Config" })()

local ahora = 100
Limite.reloj = function()
	return ahora
end

local ana, luis = { nombre = "ana" }, { nombre = "luis" }

-- La primera siempre pasa; lo que llega antes de tiempo se tira; pasado el tiempo vuelve a pasar.
igual(Limite.pasa(ana, "Compra", 1), true, "la primera pasa")
igual(Limite.pasa(ana, "Compra", 1), false, "en el mismo instante no")
ahora = 100.5
igual(Limite.pasa(ana, "Compra", 1), false, "a medio segundo no")
ahora = 101
igual(Limite.pasa(ana, "Compra", 1), true, "justo al segundo pasa")
igual(Limite.pasa(ana, "Compra", 1), false, "y la siguiente ya no")

-- Lo tirado no alarga la espera: la cuenta sigue desde la última que pasó (no desde el último intento).
ahora = 101.9
igual(Limite.pasa(ana, "Compra", 1), false, "tirada a 0,9 s")
ahora = 102
igual(Limite.pasa(ana, "Compra", 1), true, "pasa a 1 s de la última que pasó, aunque se insistiera antes")

-- Cada jugador y cada clave llevan su cuenta.
igual(Limite.pasa(luis, "Compra", 1), true, "otro jugador pasa a la vez")
igual(Limite.pasa(ana, "Clase", 0.3), true, "otra clave pasa a la vez")
igual(Limite.pasa(ana, "Compra", 1), false, "su clave sigue bloqueada")

-- Cada llamada trae su propio intervalo (los hay que dependen de una mejora).
ahora = 102.5
igual(Limite.pasa(ana, "Clase", 0.3), true, "intervalo corto: pasa")
igual(Limite.pasa(ana, "Clase", 0.3), false, "intervalo corto: tirada")
igual(Limite.pasa(ana, "Clase", 0.3), false, "intervalo corto: otra tirada")
ahora = 102.7
igual(Limite.pasa(ana, "Clase", 0.3), false, "a 0,2 s con 0,3 no")
igual(Limite.pasa(ana, "Clase", 0.1), true, "pero con 0,1 de intervalo sí")

-- restante: no apunta nada.
ahora = 200
igual(Limite.restante(ana, "Idioma", 1), 0, "sin nada apuntado no falta nada")
igual(Limite.pasa(ana, "Idioma", 1), true, "pasa")
ahora = 200.25
igual(Limite.restante(ana, "Idioma", 1), 0.75, "faltan 0,75 s")
igual(Limite.restante(ana, "Idioma", 1), 0.75, "mirar no cambia la cuenta")
igual(Limite.pasa(ana, "Idioma", 1), false, "sigue sin pasar")
ahora = 201
igual(Limite.restante(ana, "Idioma", 1) <= 0, true, "ya no falta nada")
igual(Limite.pasa(ana, "Idioma", 1), true, "y pasa")

-- La recarga que solo cuenta si se hace (restante antes, pasa al hacerlo): lo que no se hace no la empieza.
ahora = 300
igual(Limite.restante(ana, "FlashRecarga", 4) > 0, false, "sin flash previo se puede")
igual(Limite.restante(ana, "FlashRecarga", 4) > 0, false, "sin hacerlo, sigue pudiendo")
Limite.pasa(ana, "FlashRecarga", 4)
ahora = 302
igual(Limite.restante(ana, "FlashRecarga", 4), 2, "faltan 2 s tras hacerlo")

-- olvidar: se va el jugador y su cuenta con él; los demás siguen.
ahora = 400
igual(Limite.pasa(ana, "Compra", 1), true, "ana pasa")
igual(Limite.pasa(luis, "Compra", 1), true, "luis pasa")
Limite.olvidar(ana)
igual(Limite.pasa(ana, "Compra", 1), true, "tras olvidarla, ana pasa otra vez en el mismo instante")
igual(Limite.pasa(luis, "Compra", 1), false, "luis sigue contando")
igual(Limite.restante(ana, "Clase", 0.3) <= 0, true, "olvidar limpia todas las claves")

-- Los de al lado no se pisan al cargar el módulo dos veces (cada banco trae el suyo).
local otro = luau.load(fs.readFile("src/comun/servidor/Limite.luau"), { debugName = "Limite2" })()
otro.reloj = function()
	return ahora
end
igual(otro.pasa(luis, "Compra", 1), true, "otra copia del módulo lleva su propia cuenta")

-- vaciar (para los bancos): nada se queda apuntado.
Limite.vaciar()
igual(Limite.pasa(luis, "Compra", 1), true, "tras vaciar, pasa")

-- Config.Limites: todo número positivo, y cada intervalo lo usa algún remote del servidor (si no, sobra).
igual(type(Config.Limites), "table", "Config.Limites existe")
local codigo = {}
local function recorrer(dir: string)
	for _, nombre in fs.readDir(dir) do
		local ruta = dir .. "/" .. nombre
		if fs.isDir(ruta) then
			recorrer(ruta)
		elseif string.match(nombre, "%.luau$") then
			table.insert(codigo, fs.readFile(ruta))
		end
	end
end
for _, carpeta in { "src/juego/servidor", "src/comun/servidor", "src/lobby/servidor" } do
	recorrer(carpeta)
end
local todo = table.concat(codigo, "\n")
for clave, segundos in Config.Limites do
	igual(type(segundos) == "number" and segundos > 0 and segundos < 60, true, `Limites.{clave} es un intervalo razonable`)
	igual(string.find(todo, "Config.Limites." .. clave, 1, true) ~= nil, true, `Limites.{clave} lo usa algún remote`)
end

-- Y lo que se usa existe (un nombre mal escrito daría nil y nil no compara: error en pleno juego).
for usado in string.gmatch(todo, "Config%.Limites%.(%w+)") do
	igual(Config.Limites[usado] ~= nil, true, `Config.Limites.{usado} existe`)
end

print(`limite: {comprobaciones} comprobaciones bien`)
