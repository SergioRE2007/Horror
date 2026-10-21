-- Ejecutar desde la raíz: lune run tests/regressions.luau
-- Carga el código de producción que no necesita Roblox (o lo pide con cuidado) y sustituye el DataStore y el reloj.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local comprobaciones = 0
local function igual(actual, esperado, etiqueta: string)
	assert(actual == esperado, `{etiqueta}: esperado {esperado}, recibido {actual}`)
	comprobaciones += 1
end

-- Un "script" falso: script.Parent.Config = el archivo de al lado, como en Roblox.
local function nodo(ruta: string)
	return setmetatable({ ruta = ruta }, {
		__index = function(_, clave)
			return nodo(if clave == "Parent" then (string.match(ruta, "^(.*)/[^/]+$") :: string) else ruta .. "/" .. clave)
		end,
	})
end
local cargados = {}
local function cargar(ruta: string)
	if cargados[ruta] == nil then
		local fuente = fs.readFile(ruta .. ".luau")
		local entorno = {
			script = nodo(ruta),
			require = function(n) return cargar(n.ruta) end,
		}
		cargados[ruta] = luau.load(fuente, { debugName = ruta, environment = entorno })()
	end
	return cargados[ruta]
end

local Config = cargar("src/shared/Config")
local Lang = cargar("src/shared/Lang")
local Candado = cargar("src/comun/servidor/Candado")
local Formato = cargar("src/comun/servidor/Formato")

-- Lo que devuelve un DataStore de lo que se le da: una copia sin nada compartido. De paso comprueba que se puede
-- guardar (números finitos, textos, booleanos y tablas que sean lista o diccionario de textos, nunca mezcla).
local function guardable(valor, donde: string)
	if type(valor) ~= "table" then
		assert(type(valor) == "string" or type(valor) == "boolean"
			or (type(valor) == "number" and valor == valor and math.abs(valor) ~= math.huge), `no se puede guardar {donde}`)
		return valor
	end
	local copia, cuantos = {}, 0
	for clave, dentro in valor do
		cuantos += 1
		copia[clave] = guardable(dentro, donde .. "." .. tostring(clave))
	end
	if cuantos ~= #valor then
		for clave in valor do
			assert(type(clave) == "string", `no se puede guardar {donde}: clave {tostring(clave)} en un diccionario`)
		end
	end
	return copia
end
local function copia(valor)
	if type(valor) ~= "table" then return valor end
	local nueva = {}
	for clave, dentro in valor do nueva[clave] = copia(dentro) end
	return nueva
end

-- Un DataStore de una clave, como el de verdad: UpdateAsync lee y escribe de una vez, y devolver nil no escribe.
-- Varios "servidores" pueden compartir el mismo. `falla` = true simula que no hay red.
local function almacen()
	local a = { valor = nil, escrituras = 0, falla = false }
	function a.UpdateAsync(_, _, transformar)
		assert(not a.falla, "sin red")
		local salida = transformar(copia(a.valor))
		if salida == nil then return nil end
		a.valor = guardable(salida, "datos")
		a.escrituras += 1
		return a.valor
	end
	return a
end

-- Un reloj de mentira que comparten los servidores; esperar lo adelanta y deja pasar cosas (`mientras`).
local reloj = { hora = 1000, mientras = nil :: (() -> ())? }
local function servidor(a, id: string)
	local avisos = {}
	return {
		almacen = a,
		clave = "jugador_1",
		id = id,
		ahora = function() return reloj.hora end,
		esperar = function(segundos)
			reloj.hora += segundos
			if reloj.mientras then reloj.mientras() end
		end,
		config = Config.Guardado,
		aviso = function(texto) table.insert(avisos, texto) end,
		avisos = avisos,
	}
end
local cfg = Config.Guardado
local intentosCarga = math.floor(cfg.Espera / cfg.Reintento) + 1

-- Config: los números del candado tienen que encajar.
assert(cfg.Caduca > cfg.Intervalo * 2, "Caduca tiene que ser bastante mayor que Intervalo")
assert(cfg.Espera > cfg.Reintento, "Espera tiene que dar para varios intentos")
comprobaciones += 2

-- Formato: partida nueva y arreglar lo viejo o roto.
do
	local nuevo = Formato.arreglarJugador(nil)
	igual(nuevo.version, Formato.VERSION, "nuevo: versión")
	igual(nuevo.monedas, 0, "nuevo: sin monedas")
	guardable(nuevo, "jugador nuevo")
	local viejo = Formato.arreglarJugador({ monedas = 7, logros = { primero = true } })
	igual(viejo.monedas, 7, "viejo: conserva las monedas")
	igual(viejo.logros.primero, true, "viejo: conserva los logros")
	igual(type(viejo.compras), "table", "viejo: gana lo que le faltaba")
	igual(viejo.version, Formato.VERSION, "viejo: sube la versión")
	igual(Formato.arreglarJugador({ monedas = 0 / 0 }).monedas, 0, "monedas NaN -> 0")
	igual(Formato.arreglarJugador({ monedas = -5 }).monedas, 0, "monedas negativas -> 0")
	igual(Formato.arreglarJugador({ monedas = "mucho" }).monedas, 0, "monedas que no son número -> 0")
end

-- Candado: un solo servidor.
do
	local a = almacen()
	local A = servidor(a, "A")
	local estado, datos = Candado.cargar(A)
	igual(estado, "ok", "cargar nuevo")
	igual(datos, nil, "cargar nuevo: sin datos")
	igual(a.valor.candado.id, "A", "cargar pone el candado")
	local d = Formato.jugadorNuevo()
	d.monedas = 5
	reloj.hora += 60
	igual(Candado.guardar(A, d, false, 1), "ok", "guardar")
	igual(a.valor.datos.monedas, 5, "guardar escribe")
	igual(a.valor.candado.hora, reloj.hora, "guardar renueva el candado")
	igual(Candado.guardar(A, d, true, 1), "ok", "guardar al salir")
	igual(a.valor.candado, nil, "salir suelta el candado")
	local otra, guardado = Candado.cargar(servidor(a, "A2"))
	igual(otra, "ok", "volver a entrar")
	igual(guardado.monedas, 5, "volver a entrar: lo guardado sigue")
end

-- Candado: dos servidores con la misma partida.
do
	local a = almacen()
	local A, B = servidor(a, "A"), servidor(a, "B")
	Candado.cargar(A)
	local escrituras = a.escrituras
	local estado = Candado.cargar(B)
	igual(estado, "ocupado", "B no entra mientras A la tiene")
	igual(a.valor.candado.id, "A", "B no toca el candado de A")
	igual(a.escrituras, escrituras, "B no escribe nada")

	-- A se va mientras B espera: B entra con lo que guardó A.
	local d = Formato.jugadorNuevo()
	d.monedas = 9
	local veces = 0
	reloj.mientras = function()
		veces += 1
		if veces == 2 then Candado.guardar(A, d, true, 1) end
	end
	local otro, datos = Candado.cargar(B)
	reloj.mientras = nil
	igual(otro, "ok", "B entra cuando A suelta")
	igual(datos.monedas, 9, "B carga lo que guardó A al salir")

	-- A sigue creyendo que la tiene (p. ej. salto rápido de servidor): no puede escribir encima.
	local viejo = Formato.jugadorNuevo()
	viejo.monedas = 1000
	igual(Candado.guardar(A, viejo, false, 1), "perdido", "A ya no es el dueño")
	igual(a.valor.datos.monedas, 9, "A no escribe encima de B")
	igual(a.valor.candado.id, "B", "el candado sigue siendo de B")
end

-- Candado: servidor caído (no renueva) y fallos de red.
do
	local a = almacen()
	Candado.cargar(servidor(a, "Caido"))
	reloj.hora += cfg.Caduca + 1
	local B = servidor(a, "B")
	local estado = Candado.cargar(B)
	igual(estado, "ok", "candado caducado: se coge")
	igual(a.valor.candado.id, "B", "candado caducado: ahora es de B")

	a.falla = true
	local C = servidor(almacen(), "C")
	C.almacen.falla = true
	igual(Candado.cargar(C), "error", "sin red al cargar: error")
	igual(#C.avisos, intentosCarga, "sin red al cargar: un aviso por intento")

	local D = servidor(almacen(), "D")
	D.almacen.falla = true
	reloj.mientras = function() D.almacen.falla = false end
	igual(Candado.cargar(D), "ok", "la red vuelve mientras espera: entra")
	reloj.mientras = nil

	local avisosAntes = #B.avisos
	igual(Candado.guardar(B, Formato.jugadorNuevo(), true, cfg.Intentos), "error", "sin red al guardar: error")
	igual(#B.avisos - avisosAntes, cfg.Intentos, "sin red al guardar: un aviso por intento")
	a.falla = false
	igual(a.valor.candado.id, "B", "guardar fallido no suelta el candado")
end

-- Lang: inglés por defecto, español con huecos y las mismas llaves en las dos tablas.
do
	local espanol = { GetAttribute = function() return "es" end }
	Lang.es["Night {n}"] = "Noche {n}"
	igual(Lang.t(nil, "Night {n}", { n = 3 }), "Night 3", "sin jugador: inglés")
	igual(Lang.t(espanol, "Night {n}", { n = 3 }), "Noche 3", "jugador en español")
	igual(Lang.t(espanol, "Not translated"), "Not translated", "sin traducción: inglés")
	igual(Lang.deLocale("es-mx"), "es", "es-mx es español")
	igual(Lang.deLocale("pt-br"), "en", "pt-br va en inglés")
	Lang.es["Night {n}"] = nil
	local function huecos(texto: string)
		local lista = {}
		for hueco in string.gmatch(texto, "{(%w+)}") do table.insert(lista, hueco) end
		table.sort(lista)
		return table.concat(lista, ",")
	end
	for ingles, traducido in Lang.es do
		igual(huecos(traducido), huecos(ingles), `LangEs "{ingles}": mismos huecos`)
	end
end

-- Remotes: sin nombres repetidos.
do
	local fuente = fs.readFile("src/shared/Remotes.luau")
	local lista = string.match(fuente, "local NOMBRES = (%b{})") :: string
	local vistos = {}
	for nombre in string.gmatch(lista, '\n%s*"(%w+)"') do
		assert(not vistos[nombre], `remote repetido: {nombre}`)
		vistos[nombre] = true
		comprobaciones += 1
	end
end

print(`Todo bien: {comprobaciones} comprobaciones.`)
