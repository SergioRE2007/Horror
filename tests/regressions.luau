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

-- Defensa: persianas, cristales y puertas contra el Golpeador.
do
	local Defensa = cargar("src/shared/Defensa")
	local cfg = Config.Casa

	local v = Defensa.nueva("Ventana", cfg)
	igual(Defensa.golpe(v, 0, 10, cfg), "Grieta", "ventana sin persiana: se agrieta")
	igual(Defensa.golpe(v, 0, 10, cfg), "Grieta", "segunda grieta")
	igual(Defensa.golpe(v, 0, 10, cfg), "Entra", "al romper el cristal entra")

	v = Defensa.nueva("Ventana", cfg)
	igual(Defensa.persiana(v, 0, cfg), true, "bajar la persiana")
	igual(Defensa.golpe(v, cfg.TiempoPersiana / 2, 10, cfg), "Grieta", "a medio bajar no protege")
	igual(Defensa.persiana(v, 0.1, cfg), false, "no se toca a medio mover")
	igual(Defensa.golpe(v, cfg.TiempoPersiana, 10, cfg), "Persiana", "bajada del todo aguanta")
	igual(v.vida, cfg.VidaPersiana - 10, "la persiana pierde vida")
	igual(v.cristal, 1, "la grieta de antes sigue")

	v.atacada = true
	igual(Defensa.persiana(v, 10, cfg), true, "subirla en pleno ataque")
	igual(Defensa.golpe(v, 11, 10, cfg), "Entra", "abrir la persiana al Golpeador: entra")

	v = Defensa.nueva("Ventana", cfg)
	Defensa.persiana(v, 0, cfg)
	local resultado
	for _ = 1, 100 do
		resultado = Defensa.golpe(v, 10, 30, cfg)
		if resultado ~= "Persiana" then break end
	end
	igual(resultado, "PersianaRota", "la persiana acaba rompiéndose")
	igual(Defensa.persiana(v, 20, cfg), false, "una persiana rota no se baja")
	igual(Defensa.necesitaReparar(v), true, "rota necesita reparar")
	Defensa.reparar(v)
	igual(Defensa.necesitaReparar(v), false, "reparada")
	igual(Defensa.persiana(v, 20, cfg), true, "reparada se puede bajar")

	local p = Defensa.nueva("Puerta", cfg)
	igual(Defensa.golpe(p, 0, 10, cfg), "Puerta", "puerta cerrada aguanta")
	Defensa.puerta(p, 5, cfg)
	igual(Defensa.golpe(p, 6, 10, cfg), "Entra", "puerta abierta: entra")
	p = Defensa.nueva("Puerta", cfg)
	igual(Defensa.golpe(p, 0, cfg.VidaPuerta, cfg), "Entra", "puerta derribada")
	igual(Defensa.puerta(p, 10, cfg), false, "puerta rota no se cierra")
	p = Defensa.nueva("Puerta", cfg)
	p.bloqueada = true
	igual(Defensa.puerta(p, 0, cfg), false, "con llave no se abre")
end

-- Dificultad: la tabla de Config por jugadores (pensada para 2) y los rangos de ataques a la vez.
do
	local Dificultad = cargar("src/shared/Dificultad")
	local tabla = Config.Dificultad
	igual(Dificultad.de(1, 0.99, tabla).alaVez, 1, "1 jugador: un ataque a la vez")
	igual(Dificultad.de(2, 0.5, tabla).ritmo, 1, "2 jugadores: ritmo normal")
	igual(Dificultad.de(2, 0.5, tabla).paciencia, 1, "2 jugadores: paciencia normal")
	igual(Dificultad.de(3, 0, tabla).alaVez, 2, "3 jugadores: 2 a la vez como poco")
	igual(Dificultad.de(3, 0.999, tabla).alaVez, 3, "3 jugadores: 3 a la vez como mucho")
	igual(Dificultad.de(4, 0.3, tabla).alaVez, 3, "4 jugadores: 3 a la vez")
	igual(Dificultad.de(8, 0.3, tabla).alaVez, 3, "más de 4: como 4")
	igual(Dificultad.de(0, 0.3, tabla).alaVez, 1, "0 (Studio vacío): como 1")
	assert(Dificultad.de(1, 0, tabla).ritmo > Dificultad.de(4, 0, tabla).ritmo, "con más jugadores, ataques más seguidos")
	assert(Dificultad.de(1, 0, tabla).paciencia > Dificultad.de(4, 0, tabla).paciencia, "con más jugadores, menos paciencia")
	comprobaciones += 2
end

-- Rejilla de la mochila: caber, girar, mover, sacar, gastar y rehacerla de datos rotos.
do
	local Rejilla = cargar("src/shared/Rejilla")
	local cat = Config.Objetos
	local M = Config.Mochila
	for tipo, o in cat do
		assert(o.Tam[1] >= 1 and o.Tam[2] >= 1 and o.Tam[1] <= M.Ancho and o.Tam[2] <= M.Alto, `tamaño raro: {tipo}`)
		assert(Lang.es[o.Nombre], `sin español: {o.Nombre}`)
	end
	for _, tipo in M.Inicio do
		assert(cat[tipo], `inicio con tipo desconocido: {tipo}`)
	end
	comprobaciones += 1
	local r = Rejilla.nueva(M.Ancho, M.Alto)
	for _, tipo in M.Inicio do
		assert(Rejilla.meter(r, cat, tipo, nil), `lo de inicio no cabe: {tipo}`)
	end
	igual(#r.cosas, #M.Inicio, "inicio metido")

	r = Rejilla.nueva(4, 3)
	local hacha = Rejilla.poner(r, cat, "Hacha", 1, 1, false)
	igual(hacha ~= nil, true, "hacha 1x3 de pie cabe")
	igual(Rejilla.poner(r, cat, "Pila", 1, 2, false), nil, "no se pisa")
	igual(Rejilla.cabe(r, cat, "Hacha", 3, 1, true), false, "girada (3x1) desde x=3 se sale")
	igual(Rejilla.cabe(r, cat, "Hacha", 2, 1, true, hacha.id), true, "girada en la fila de arriba cabe (ignorando la suya)")
	igual(Rejilla.cabe(r, cat, "Pila", 0, 1, false), false, "fuera por la izquierda")
	igual(Rejilla.cabe(r, cat, "Pila", 1.5, 1, false), false, "casilla no entera")
	igual(Rejilla.cabe(r, cat, "Nada", 3, 1, false), false, "tipo desconocido")
	igual(Rejilla.mover(r, cat, hacha.id, 2, 1, true), true, "mover y girar")
	igual(Rejilla.en(r, cat, 4, 1), hacha, "la hacha girada ocupa (4,1)")
	igual(Rejilla.en(r, cat, 1, 1), nil, "(1,1) queda libre")
	igual(Rejilla.mover(r, cat, hacha.id, 3, 1, true), false, "no se mueve fuera")
	igual(hacha.x, 2, "al fallar no cambia")
	igual(Rejilla.mover(r, cat, hacha.id, 1, 2, "si"), false, "girada que no es booleano")
	igual(Rejilla.mover(r, cat, 99, 1, 2, false), false, "id que no existe")
	local cam = Rejilla.meter(r, cat, "Camara")
	igual(cam and cam.x, 1, "la cámara 2x2 al primer hueco: x")
	igual(cam and cam.y, 2, "la cámara 2x2 al primer hueco: y")
	igual(Rejilla.meter(r, cat, "Linterna") ~= nil, true, "la linterna 1x2 al lado")
	igual(Rejilla.meter(r, cat, "Pila") ~= nil, true, "queda un hueco")
	igual(Rejilla.meter(r, cat, "Pila") ~= nil, true, "y otro")
	igual(Rejilla.meter(r, cat, "Pila") ~= nil, true, "y el último")
	igual(Rejilla.meter(r, cat, "Pila"), nil, "llena")
	igual(Rejilla.contar(r, "Pila"), 3, "tres pilas")
	igual(Rejilla.gastar(r, "Pila"), true, "gastar una pila")
	igual(Rejilla.contar(r, "Pila"), 2, "quedan dos")
	igual(Rejilla.gastar(r, "Carrete"), false, "no hay carretes")
	igual(Rejilla.primera(r, "Camara"), cam, "primera cámara")
	igual(Rejilla.sacar(r, cam.id), cam, "sacar la cámara")
	igual(Rejilla.buscar(r, cam.id), nil, "ya no está")
	igual(Rejilla.cabe(r, cat, "Camara", 1, 2, false), true, "su hueco queda libre")

	-- De datos rotos: tipos raros fuera, lo que pisa se recoloca, lo que no cabe sobra, ids repetidos se cambian.
	local datos = { cosas = {
		{ id = 1, tipo = "Camara", x = 1, y = 1, girada = false, carga = 4 },
		{ id = 2, tipo = "Camara", x = 2, y = 1, girada = false }, -- pisa a la otra
		{ id = 1, tipo = "Pila", x = 4, y = 1, girada = false }, -- id repetido
		{ id = 5, tipo = "Bomba", x = 1, y = 3 },
		{ id = 6, tipo = "Pila", x = 1, y = 1, carga = 0 / 0 },
		"basura",
	} }
	local r2, sobran = Rejilla.desde(datos, cat, 4, 2)
	igual(Rejilla.buscar(r2, 1).tipo, "Camara", "la primera cámara se queda en su sitio")
	igual(Rejilla.buscar(r2, 1).carga, 4, "con su carga")
	igual(Rejilla.contar(r2, "Camara"), 2, "la segunda cámara se recoloca al lado")
	igual(Rejilla.contar(r2, "Pila"), 0, "las pilas ya no caben")
	igual(#sobran, 2, "sobran las dos pilas")
	igual(sobran[2].carga, nil, "una carga NaN no se queda")
	igual(r2.siguiente > 2, true, "siguiente id por encima de los usados")
	local r3 = Rejilla.desde(nil, cat, 3, 3)
	igual(#r3.cosas, 0, "de nada, vacía")
	local r4, sobran4 = Rejilla.desde({ cosas = { { id = 3, tipo = "Hacha", x = 1, y = 1, girada = false } } }, cat, M.Grande[1], M.Grande[2])
	igual(Rejilla.buscar(r4, 3) ~= nil and #sobran4 == 0, true, "a una mochila más grande, todo en su sitio")
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
