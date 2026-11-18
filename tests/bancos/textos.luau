-- Banco de textos (16.21): cada frase del jugador escrita en el código tiene su español en src/shared/LangEs.luau.
-- Ejecutar desde la raíz: lune run tests/bancos/textos.luau (lo corre regressions.luau).
-- Lee cada src/**/*.luau con un tokenizador pequeño de Luau (cadenas, comentarios, bloques) y saca:
--   - los literales del segundo argumento de Lang.t(x, "…"), también en varias líneas y en if … then "…" else "…"
--     (sin los de las condiciones ni los de comparaciones: if forma == "Foto");
--   - los ActionText de los prompts (los traduce comun/cliente/Controles con Lang.t);
--   - los textos que pasan por un ayudante: una función que lleva uno de sus parámetros a Lang.t o a ActionText
--     (avisar, acabar, nuevoPrompt, Viaje.volver…). Se encuentran solos, también los que llaman a otro ayudante.
-- Solo literales: una frase construida en una variable no se puede ver aquí (las tablas de textos las mira
-- tests/regressions.luau). Falla si falta alguna; de las claves de LangEs que no salen en ningún archivo de src solo
-- avisa (pueden venir de Config o de tablas, y quitarlas es cosa de quien las conoce).
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local cuentas = 0
local fallos: { string } = {}

------------------------------------------------------------------------------------------------------------------
-- Tokenizador: { tipo = "nombre" | "cadena" | "num" | "simbolo" | "interp", v = texto, linea = n, crudo = fuente }
type Token = { tipo: string, v: string, linea: number, crudo: string? }

-- El valor de verdad de un literal "…" o '…' (con escapes): el mismo que tendría como clave de LangEs.
local function valorCadena(crudo: string): string
	if not string.find(crudo, "\\", 1, true) then
		return string.sub(crudo, 2, -2)
	end
	return luau.load("return " .. crudo)()
end

local SIMBOLOS = { "...", "..=", "//=", "..", "==", "~=", "<=", ">=", "->", "+=", "-=", "*=", "/=", "%=", "^=", "//",
	"::" }

local function tokenizar(f: string, ruta: string): { Token }
	local t: { Token } = {}
	local i, n, linea = 1, #f, 1
	local function avanzar(hasta: number) -- de i a hasta (incluido), contando líneas
		local trozo = string.sub(f, i, hasta)
		for _ in string.gmatch(trozo, "\n") do
			linea += 1
		end
		i = hasta + 1
	end
	while i <= n do
		local c = string.sub(f, i, i)
		if c == "\n" then
			linea += 1
			i += 1
		elseif string.match(c, "%s") then
			i += 1
		elseif string.sub(f, i, i + 1) == "--" then
			local largo = string.match(f, "^%-%-%[(=*)%[", i)
			if largo then
				local _, fin = string.find(f, "]" .. largo .. "]", i, true)
				avanzar(fin or n)
			else
				local fin = string.find(f, "\n", i, true)
				i = fin or (n + 1)
			end
		elseif string.match(f, "^%[=*%[", i) then
			local largo = string.match(f, "^%[(=*)%[", i) :: string
			local _, fin = string.find(f, "]" .. largo .. "]", i, true)
			local ini = linea
			local cuerpo = string.sub(f, i + #largo + 2, (fin or n) - #largo - 2)
			avanzar(fin or n)
			table.insert(t, { tipo = "cadena", v = (string.gsub(cuerpo, "^\n", "")), linea = ini })
		elseif c == "\"" or c == "'" then
			local j = i + 1
			while j <= n do
				local d = string.sub(f, j, j)
				if d == "\\" then
					j += 2
				elseif d == c then
					break
				elseif d == "\n" then
					error(`{ruta}:{linea}: cadena sin cerrar`)
				else
					j += 1
				end
			end
			local crudo = string.sub(f, i, j)
			table.insert(t, { tipo = "cadena", v = valorCadena(crudo), linea = linea, crudo = crudo })
			i = j + 1
		elseif c == "`" then
			-- Cadena con huecos: se salta entera (con lo que haya dentro de sus {…}). No es una frase para Lang.
			local j, llaves = i + 1, 0
			local ini = linea
			while j <= n do
				local d = string.sub(f, j, j)
				if d == "\\" then
					j += 2
				elseif llaves == 0 and d == "`" then
					break
				elseif d == "{" then
					llaves += 1
					j += 1
				elseif d == "}" then
					llaves -= 1
					j += 1
				elseif llaves > 0 and (d == "\"" or d == "'") then
					local k = j + 1
					while k <= n and string.sub(f, k, k) ~= d do
						k += if string.sub(f, k, k) == "\\" then 2 else 1
					end
					j = k + 1
				else
					j += 1
				end
			end
			avanzar(j)
			table.insert(t, { tipo = "interp", v = "`", linea = ini })
		elseif string.match(c, "[%a_]") then
			local nombre = string.match(f, "^[%w_]+", i) :: string
			table.insert(t, { tipo = "nombre", v = nombre, linea = linea })
			i += #nombre
		elseif string.match(c, "%d") or (c == "." and string.match(f, "^%.%d", i)) then
			local num = string.match(f, "^0[xXbB][%x_]+", i) or string.match(f, "^[%d_]*%.?[%d_]*[eE][%+%-]?[%d_]+", i)
				or string.match(f, "^[%d_]*%.?[%d_]+", i) or string.match(f, "^[%d_]+%.", i) :: string
			table.insert(t, { tipo = "num", v = num, linea = linea })
			i += #num
		else
			local s = c
			for _, largo in SIMBOLOS do
				if string.sub(f, i, i + #largo - 1) == largo then
					s = largo
					break
				end
			end
			table.insert(t, { tipo = "simbolo", v = s, linea = linea })
			i += #s
		end
	end
	return t
end

------------------------------------------------------------------------------------------------------------------
-- Qué hay en cada archivo.
local ABRE = { ["("] = true, ["{"] = true, ["["] = true }
local CIERRA = { [")"] = true, ["}"] = true, ["]"] = true }
-- Tras estos, un `if` es una expresión (if … then … else …) y no abre bloque.
local ANTES_DE_EXPRESION = { ["="] = true, ["("] = true, [","] = true, ["{"] = true, ["["] = true, ["return"] = true,
	["or"] = true, ["and"] = true, ["not"] = true, [".."] = true, ["=="] = true, ["~="] = true, ["<"] = true, [">"] = true,
	["<="] = true, [">="] = true, ["+"] = true, ["-"] = true, ["*"] = true, ["/"] = true, ["//"] = true, ["%"] = true,
	["^"] = true, ["in"] = true, ["until"] = true, ["+="] = true, ["-="] = true, ["*="] = true, ["/="] = true,
	["..="] = true, [":"] = true, ["::"] = true, ["#"] = true }

local function es(tok: Token?, v: string): boolean
	return tok ~= nil and tok.v == v and (tok.tipo == "simbolo" or tok.tipo == "nombre")
end

-- Del paréntesis que abre en `desde` al que lo cierra: los argumentos, cada uno como lista de tokens, y dónde acaba.
local function argumentos(t: { Token }, desde: number): ({ { Token } }, number)
	local args: { { Token } } = { {} }
	local hondo = 0
	local i = desde + 1
	while i <= #t do
		local tok = t[i]
		if tok.tipo == "simbolo" and CIERRA[tok.v] then
			if hondo == 0 then
				break
			end
			hondo -= 1
		elseif tok.tipo == "simbolo" and ABRE[tok.v] then
			hondo += 1
		end
		if hondo == 0 and es(tok, ",") then
			table.insert(args, {})
		else
			table.insert(args[#args], tok)
		end
		i += 1
	end
	if #args == 1 and #args[1] == 0 then
		args = {}
	end
	return args, i
end

-- Los literales que una expresión puede dar como texto: los de arriba del todo y los de las ramas de un if, sin los de
-- las condiciones, las comparaciones, las llamadas ni los índices. Un literal pegado con .. es un fallo (frases enteras).
local function frases(expr: { Token }): { string }
	local lista = {}
	local hondo, condicion = 0, false
	for k, tok in expr do
		if tok.tipo == "simbolo" and ABRE[tok.v] then
			hondo += 1
		elseif tok.tipo == "simbolo" and CIERRA[tok.v] then
			hondo -= 1
		elseif hondo == 0 and (es(tok, "if") or es(tok, "elseif")) then
			condicion = true
		elseif hondo == 0 and es(tok, "then") then
			condicion = false
		elseif hondo == 0 and tok.tipo == "cadena" and not condicion then
			local antes, despues = expr[k - 1], expr[k + 1]
			local comparada = es(antes, "==") or es(antes, "~=") or es(despues, "==") or es(despues, "~=")
			local pegada = es(antes, "..") or es(despues, "..")
			if pegada then
				table.insert(fallos, `texto pegado a trozos en la línea {tok.linea}: "{tok.v}" (frases enteras con huecos)`)
			elseif not comparada then
				table.insert(lista, tok.v)
			end
		end
	end
	return lista
end

type Funcion = { nombre: string, modulo: boolean, params: { string }, desde: number, hasta: number }

-- Las funciones del archivo con sus parámetros y dónde empieza y acaba su cuerpo (contando bloques).
local function funciones(t: { Token }, ruta: string): { Funcion }
	local lista: { Funcion } = {}
	local pila: { Funcion | false } = {}
	local i = 1
	while i <= #t do
		local tok = t[i]
		local antes = t[i - 1]
		if tok.tipo == "nombre" and tok.v == "function" then
			-- function a.b:c<T>(params) | local function f(params) | f = function(params)
			local nombre, modulo = "", false
			local j = i + 1
			if t[j] and t[j].tipo == "nombre" then
				nombre = t[j].v
				j += 1
				while es(t[j], ".") or es(t[j], ":") do
					modulo = true
					nombre = t[j + 1].v
					j += 2
				end
			elseif es(antes, "=") and t[i - 2] and t[i - 2].tipo == "nombre" then
				nombre = t[i - 2].v
				modulo = es(t[i - 3], ".")
			end
			if es(t[j], "<") then
				local hondo = 0
				repeat
					if es(t[j], "<") then
						hondo += 1
					elseif es(t[j], ">") then
						hondo -= 1
					end
					j += 1
				until hondo == 0 or j > #t
			end
			assert(es(t[j], "("), `{ruta}:{tok.linea}: no entiendo esta función`)
			local args, fin = argumentos(t, j)
			local params = {}
			for _, a in args do
				table.insert(params, if a[1] and a[1].tipo == "nombre" then a[1].v else "")
			end
			local f: Funcion = { nombre = nombre, modulo = modulo, params = params, desde = fin + 1, hasta = #t }
			table.insert(lista, f)
			table.insert(pila, f)
			i = fin + 1
		elseif tok.tipo == "nombre" and (tok.v == "do" or tok.v == "repeat" or (tok.v == "if"
			and not (antes and ANTES_DE_EXPRESION[antes.v] and antes.tipo ~= "cadena" and antes.tipo ~= "num"))) then
			-- Un bloque que no es función (un `if` que es una expresión no abre bloque).
			table.insert(pila, false)
			i += 1
		elseif tok.tipo == "nombre" and (tok.v == "end" or tok.v == "until") then
			local cerrado = table.remove(pila)
			assert(cerrado ~= nil, `{ruta}:{tok.linea}: "{tok.v}" de más (el tokenizador se ha perdido)`)
			if cerrado then
				cerrado.hasta = i - 1
			end
			i += 1
		else
			i += 1
		end
	end
	assert(#pila == 0, `{ruta}: bloques sin cerrar al acabar el archivo (el tokenizador se ha perdido)`)
	return lista
end

------------------------------------------------------------------------------------------------------------------
-- Todos los archivos.
local archivos: { { ruta: string, t: { Token }, fns: { Funcion } } } = {}
local function recorrer(dir: string)
	local nombres = fs.readDir(dir)
	table.sort(nombres)
	for _, nombre in nombres do
		local ruta = dir .. "/" .. nombre
		if fs.isDir(ruta) then
			recorrer(ruta)
		elseif string.match(nombre, "%.luau$") and ruta ~= "src/shared/LangEs.luau" then
			local t = tokenizar(fs.readFile(ruta), ruta)
			table.insert(archivos, { ruta = ruta, t = t, fns = funciones(t, ruta) })
		end
	end
end
recorrer("src")
assert(#archivos > 50, "no encuentro los archivos de src (ejecutar desde la raíz)")

local LangEs = luau.load(fs.readFile("src/shared/LangEs.luau"), { debugName = "LangEs" })()

-- ¿Es `t[i]` el nombre de una llamada a `nombre`? (local: f( sin . ni : delante; de módulo: X.f( o X:f()
local function llamadaA(t: { Token }, i: number, nombre: string, modulo: boolean): boolean
	local tok = t[i]
	if tok.tipo ~= "nombre" or tok.v ~= nombre or not es(t[i + 1], "(") then
		return false
	end
	local antes = t[i - 1]
	if es(antes, "function") then
		return false
	end
	if modulo then
		return es(antes, ".") or es(antes, ":")
	end
	return not (es(antes, ".") or es(antes, ":"))
end

-- Ayudantes: [nombre] = { modulo, índice del parámetro que acaba en Lang.t o ActionText, ruta donde está }. Uno que
-- llama a otro con su parámetro también lo es: se repite hasta que no salen más.
type Ayudante = { nombre: string, modulo: boolean, indice: number, ruta: string }
local ayudantes: { Ayudante } = {}
local function yaEs(nombre: string, modulo: boolean, indice: number, ruta: string): boolean
	for _, a in ayudantes do
		if a.nombre == nombre and a.modulo == modulo and a.indice == indice and (a.modulo or a.ruta == ruta) then
			return true
		end
	end
	return false
end
-- Los ayudantes que valen en ese archivo: los locales de él y los de módulo de cualquiera.
local function ayudantesDe(ruta: string): { Ayudante }
	local l = {}
	for _, a in ayudantes do
		if a.modulo or a.ruta == ruta then
			table.insert(l, a)
		end
	end
	return l
end
-- Lo que llega a Lang.t: Lang.t(x, <aquí>); a ActionText: X.ActionText = <aquí>; a un ayudante: f(…, <aquí>).
-- Llama a `ver(expr, i)` con la expresión y el token donde está.
local function destinos(archivo, ver: (expr: { Token }, i: number) -> ())
	local t = archivo.t
	local propios = ayudantesDe(archivo.ruta)
	for i, tok in t do
		if tok.tipo == "nombre" and tok.v == "t" and es(t[i - 1], ".") and t[i - 2] and t[i - 2].v == "Lang"
			and es(t[i + 1], "(") and not es(t[i - 3], "function") then
			local args = argumentos(t, i + 1)
			if args[2] then
				ver(args[2], i)
			end
		elseif tok.tipo == "nombre" and tok.v == "ActionText" and es(t[i - 1], ".") and es(t[i + 1], "=") then
			-- Hasta el final de la línea, o más si la línea acaba a medias (then, else, or, and, ..).
			local expr = {}
			local j = i + 2
			while t[j] do
				table.insert(expr, t[j])
				local sig = t[j + 1]
				if not sig or (sig.linea > t[j].linea and not (es(t[j], "then") or es(t[j], "else")
					or es(t[j], "or") or es(t[j], "and") or es(t[j], ".."))) then
					break
				end
				j += 1
			end
			ver(expr, i)
		elseif tok.tipo == "nombre" and (tok.v == "spawn" or tok.v == "defer" or tok.v == "delay")
			and es(t[i - 1], ".") and t[i - 2] and t[i - 2].v == "task" and es(t[i + 1], "(") then
			-- task.spawn(f, a, b) llama a f(a, b); task.delay(s, f, a) también.
			local args = argumentos(t, i + 1)
			local salto = if tok.v == "delay" then 2 else 1
			local fn = args[salto]
			local ultimo = fn and fn[#fn]
			if ultimo and ultimo.tipo == "nombre" then
				local modulo = #fn >= 3 and (es(fn[#fn - 1], ".") or es(fn[#fn - 1], ":"))
				for _, a in propios do
					if a.nombre == ultimo.v and a.modulo == modulo and args[a.indice + salto] then
						ver(args[a.indice + salto], i)
					end
				end
			end
		else
			for _, a in propios do
				if llamadaA(t, i, a.nombre, a.modulo) then
					local args = argumentos(t, i + 1)
					if args[a.indice] then
						ver(args[a.indice], i)
					end
				end
			end
		end
	end
end
for _ = 1, 10 do
	local nuevos = 0
	for _, archivo in archivos do
		destinos(archivo, function(expr, i)
			if #expr ~= 1 or expr[1].tipo ~= "nombre" then
				return
			end
			for _, f in archivo.fns do
				local indice = table.find(f.params, expr[1].v)
				-- La función más de dentro que tiene ese parámetro (y la llamada en su cuerpo).
				if indice and i >= f.desde and i <= f.hasta and f.nombre ~= "" and not yaEs(f.nombre, f.modulo, indice,
					archivo.ruta) then
					table.insert(ayudantes, { nombre = f.nombre, modulo = f.modulo, indice = indice, ruta = archivo.ruta })
					nuevos += 1
				end
			end
		end)
	end
	if nuevos == 0 then
		break
	end
end

-- Los ayudantes que deben salir solos: si alguno deja de encontrarse, el tokenizador se ha perdido.
for _, esperado in { "avisar", "acabar", "volver", "nuevoPrompt" } do
	local hay = false
	for _, a in ayudantes do
		hay = hay or a.nombre == esperado
	end
	if not hay then
		table.insert(fallos, `no encuentro el ayudante {esperado} (¿se ha perdido el tokenizador?)`)
	end
end

-- Y ahora, cada frase.
local vistas: { [string]: boolean } = {}
for _, archivo in archivos do
	destinos(archivo, function(expr, i)
		for _, frase in frases(expr) do
			if frase ~= "" then
				vistas[frase] = true
				cuentas += 1
				if LangEs[frase] == nil then
					table.insert(fallos, `sin español en {archivo.ruta}:{archivo.t[i].linea}: "{frase}"`)
				end
			end
		end
	end)
end
assert(cuentas > 200, `solo {cuentas} frases: el banco no está viendo los textos`)

-- Claves de LangEs que no salen en ningún literal de src (solo aviso).
local literales: { [string]: boolean } = {}
for _, archivo in archivos do
	for _, tok in archivo.t do
		if tok.tipo == "cadena" then
			literales[tok.v] = true
		end
	end
end
local sobran = {}
for clave in LangEs do
	if not literales[clave] then
		table.insert(sobran, clave)
	end
end
table.sort(sobran)
for _, clave in sobran do
	print(`[aviso] LangEs: nadie usa "{clave}"`)
end

if #fallos > 0 then
	error("textos:\n  " .. table.concat(fallos, "\n  "), 0)
end
local nombres = {}
for _, a in ayudantes do
	table.insert(nombres, a.nombre)
end
table.sort(nombres)
print(`Textos bien: {cuentas} frases con español; ayudantes vistos: {table.concat(nombres, ", ")}.`)
