-- Banco de las tiradas de los sucesos del Golpeador (14.10): servidor/GolpeadorTiradas de verdad (pura) con
-- Config.Golpeador.Sucesos. Comprueba:
--   los siete sucesos están en Config, con Probabilidad entre 0 y 1;
--   sale según la Probabilidad (con un azar fijo, justo por debajo sí y justo por encima no; con uno de verdad, en
--   muchas noches, cerca de la Probabilidad);
--   como mucho una vez por noche entre todos (la misma tabla para todos los Golpeadores) y otra vez la noche siguiente;
--   forzar: la siguiente ocasión sale seguro aunque ya hubiera salido esa noche, solo una vez, y un nombre que no
--   existe no se fuerza;
--   reiniciar (volver a empezar el día): la misma noche puede volver a salir.
-- Ejecutar desde la raíz: lune run tests/bancos/golpeador-sucesos.luau (lo corre regressions.luau).
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local cuentas = 0
local function igual(actual, esperado, etiqueta: string)
	assert(actual == esperado, `{etiqueta}: esperado {tostring(esperado)}, recibido {tostring(actual)}`)
	cuentas += 1
end

local function cargar(ruta: string)
	return luau.load(fs.readFile(ruta .. ".luau"), { debugName = ruta })()
end

local Config = cargar("src/shared/Config")
local Tiradas = cargar("src/juego/servidor/GolpeadorTiradas")
local S = Config.Golpeador.Sucesos

for _, nombre in { "Armario", "Olfatea", "Llama", "Cara", "Finge", "Garras", "Quieto" } do
	local c = S[nombre]
	igual(type(c), "table", `Config: {nombre}`)
	igual(type(c.Probabilidad) == "number" and c.Probabilidad > 0 and c.Probabilidad <= 1, true, `Config: {nombre}.Probabilidad`)
end

-- Un azar que da lo que se le pone.
local fijo = { valor = 0 }
function fijo:NextNumber(): number
	return self.valor
end

local t = Tiradas.nueva(S, fijo)
fijo.valor = S.Armario.Probabilidad + 0.01
igual(t:tirar("Armario", 1), false, "por encima de la probabilidad no sale")
fijo.valor = S.Armario.Probabilidad - 0.01
igual(t:tirar("Armario", 1), true, "por debajo sale")
fijo.valor = 0
igual(t:tirar("Armario", 1), false, "una vez por noche")
igual(t:tirar("Olfatea", 1), true, "los demás, aparte")
igual(t:tirar("Armario", 2), true, "la noche siguiente, otra vez")
igual(t:tirar("Olfatea", 2), true, "la noche siguiente, todos")
igual(t:tirar("Nada", 2), false, "uno que no existe no sale")

-- Forzar (modo de pruebas).
igual(t:forzar("Armario"), true, "forzar uno que existe")
igual(t:forzar("Nada"), false, "forzar uno que no existe")
fijo.valor = 0.999
igual(t:tirar("Armario", 2), true, "forzado sale aunque ya salió y el azar diga que no")
igual(t:tirar("Armario", 2), false, "forzado solo una vez")
t:forzar("Garras")
igual(t:tirar("Garras", 3), true, "forzado también al cambiar de noche")

-- Volver a empezar el día: la misma noche se repite.
fijo.valor = 0
igual(t:tirar("Llama", 3), true, "sale")
igual(t:tirar("Llama", 3), false, "ya salió")
t:reiniciar()
igual(t:tirar("Llama", 3), true, "tras reiniciar, otra vez")

-- Con un azar de verdad, una ocasión por noche: sale más o menos la Probabilidad de las noches.
local azar = { semilla = 12345 }
function azar:NextNumber(): number
	self.semilla = (self.semilla * 1103515245 + 12345) % 2147483648
	return self.semilla / 2147483648
end
local r = Tiradas.nueva(S, azar)
for nombre, c in S do
	local salen = 0
	local noches = 4000
	for n = 1, noches do
		-- Dos ocasiones por noche: la segunda solo puede salir si la primera no salió.
		local primera = r:tirar(nombre, n)
		local segunda = r:tirar(nombre, n)
		igual(primera and segunda, false, `{nombre}: dos veces la misma noche`)
		if primera or segunda then
			salen += 1
		end
	end
	-- Con dos ocasiones por noche: 1 - (1 - p)^2.
	local esperado = 1 - (1 - c.Probabilidad) ^ 2
	igual(math.abs(salen / noches - esperado) < 0.04, true, `{nombre}: sale ~{esperado} de las noches ({salen / noches})`)
end

print(`golpeador-sucesos: {cuentas} comprobaciones`)
