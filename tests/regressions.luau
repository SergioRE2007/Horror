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

-- Partida guardada: formato, datos rotos y versiones viejas (juego/servidor/FormatoPartida).
do
	local FP = cargar("src/juego/servidor/FormatoPartida")
	local cat = { objetos = Config.Objetos, pesados = Config.Pesados, maximo = Config.Partida.Sueltos, coche = Config.Coche,
		arreglarCoche = cargar("src/shared/Recetas").arreglarCoche }
	igual(FP.arreglar(nil, cat), nil, "partida nueva: nil")
	igual(FP.arreglar("basura", cat), nil, "lo que no es tabla: nueva")

	-- Una partida bien guardada sale igual tras pasar por el DataStore.
	local buena = {
		version = FP.VERSION, noche = 6, semilla = 12345,
		casa = { V10_20 = { vida = 40, persiana = true, cristal = 2, abierta = false, bloqueada = false },
			P0_5 = { vida = 160, persiana = false, cristal = 0, abierta = true } },
		arboles = { A50_60 = 4 },
		generador = { gasolina = 0.25, encendido = true, movil = 0.5 },
		objetos = { { tipo = "Pila", sitio = { 1, 2, 3, 0, 1.5, 0 } }, { tipo = "Linterna", carga = 0.4, sitio = { 4, 1, 4, 0, 0, 0 } } },
		pesados = { { tipo = "Bidon", carga = 0.3, sitio = { 10, 1.2, 10, 0, 0, 0 } } },
		mochilas = { ["1"] = { cosas = { { id = 1, tipo = "Hacha", x = 1, y = 1, girada = false } } } },
	}
	local d = FP.arreglar(guardable(buena, "partida"), cat)
	igual(d.noche, 6, "noche")
	igual(d.semilla, 12345, "semilla")
	igual(d.casa.V10_20.vida, 40, "vida de la persiana")
	igual(d.casa.V10_20.cristal, 2, "grietas del cristal")
	igual(d.casa.P0_5.abierta, true, "puerta abierta")
	igual(d.casa.P0_5.bloqueada, nil, "sin bloqueada: la del mapa")
	igual(d.arboles.A50_60, 4, "árbol talado la noche 4")
	igual(d.generador.gasolina, 0.25, "gasolina")
	igual(d.generador.movil, 0.5, "móvil en el enchufe")
	igual(#d.objetos, 2, "objetos sueltos")
	igual(d.objetos[2].carga, 0.4, "con su carga")
	igual(d.objetos[1].sitio[5], 1.5, "con su giro")
	igual(d.pesados[1].carga, 0.3, "el bidón con su gasolina")
	igual(#d.mochilas["1"].cosas, 1, "la mochila del jugador 1")
	guardable(d, "partida arreglada")

	-- Datos rotos o trucados.
	local mala = FP.arreglar({
		noche = 0 / 0, semilla = "x",
		casa = { V1_1 = { vida = "mucha" }, V2_2 = { vida = -5, cristal = 1e9 }, [3] = { vida = 1 } },
		arboles = { A1_1 = 0, A2_2 = "ayer", A3_3 = 2.7 },
		generador = { gasolina = 5, encendido = "si", movil = 0 / 0 },
		objetos = {
			{ tipo = "Nada", sitio = { 0, 0, 0, 0, 0, 0 } }, -- tipo que no existe
			{ tipo = "Pila", sitio = { 0, 0, 0, 0, 0 } }, -- faltan números
			{ tipo = "Pila", sitio = { 0, -500, 0, 0, 0, 0 } }, -- se cayó del mapa
			{ tipo = "Pila", sitio = { 0 / 0, 1, 0, 0, 0, 0 } },
			{ tipo = "Pila", carga = math.huge, sitio = { 0, 1, 0, 0, 0, 0 } },
			{ tipo = "Tronco", sitio = { 0, 1, 0, 0, 0, 0 } }, -- es pesado, no objeto
		},
		mochilas = { ["abc"] = { cosas = {} }, ["2"] = "nada", ["3"] = { cosas = {} } },
	}, cat)
	igual(mala.noche, 1, "noche NaN -> 1")
	igual(mala.semilla, 0, "semilla rota -> 0")
	igual(mala.casa.V1_1, nil, "vida que no es número: fuera")
	igual(mala.casa.V2_2.vida, 0, "vida negativa -> 0")
	igual(mala.casa.V2_2.cristal, 100, "grietas imposibles, acotadas (Casa las deja en GolpesCristal)")
	igual(mala.casa[3], nil, "clave que no es texto: fuera")
	igual(mala.arboles.A1_1, nil, "talado la noche 0: fuera")
	igual(mala.arboles.A2_2, nil, "talado sin número: fuera")
	igual(mala.arboles.A3_3, 2, "noche con decimales -> entera")
	igual(mala.generador.gasolina, 1, "gasolina de más -> lleno")
	igual(mala.generador.encendido, false, "encendido que no es booleano -> apagado")
	igual(mala.generador.movil, nil, "móvil NaN: no hay")
	igual(#mala.objetos, 1, "solo vale la pila sana")
	igual(mala.objetos[1].carga, nil, "carga infinita -> sin carga")
	igual(mala.mochilas.abc, nil, "mochila de alguien que no es un UserId: fuera")
	igual(mala.mochilas["2"], nil, "mochila que no es tabla: fuera")
	igual(type(mala.mochilas["3"]), "table", "mochila vacía: se queda")
	igual(FP.arreglar({ noche = 3.9 }, cat).noche, 3, "noche con decimales")
	igual(FP.arreglar({ noche = -2 }, cat).noche, 1, "noche negativa -> 1")

	-- Demasiadas cosas sueltas: solo las primeras Sueltos.
	local muchas = {}
	for i = 1, Config.Partida.Sueltos + 50 do
		muchas[i] = { tipo = "Lata", sitio = { i, 1, 0, 0, 0, 0 } }
	end
	igual(#FP.arreglar({ objetos = muchas }, cat).objetos, Config.Partida.Sueltos, "tope de cosas sueltas")

	-- Una versión vieja (sin versión y sin los campos de ahora) se pone al día sin romperse.
	local vieja = FP.arreglar({ noche = 5 }, cat)
	igual(vieja.version, FP.VERSION, "vieja: sube la versión")
	igual(vieja.noche, 5, "vieja: conserva la noche")
	igual(type(vieja.casa) == "table" and type(vieja.mochilas) == "table" and #vieja.objetos == 0, true, "vieja: gana lo que le faltaba")
	igual(vieja.generador.gasolina, nil, "vieja: sin gasolina guardada (Generador pone la de empezar)")

	-- La mochila guardada se rehace con la rejilla: lo que ya no existe se tira.
	local Rejilla = cargar("src/shared/Rejilla")
	local r = Rejilla.desde({ cosas = { { id = 1, tipo = "Hacha", x = 1, y = 1, girada = false }, { id = 2, tipo = "Espada", x = 3, y = 1 } } },
		Config.Objetos, Config.Mochila.Ancho, Config.Mochila.Alto)
	igual(#r.cosas, 1, "mochila guardada: el tipo que no existe se tira")

	-- Candado de la partida: dos servidores con la misma ranura (el grupo vuelve deprisa del lobby).
	local a = almacen()
	local A = servidor(a, "A")
	A.clave = "partida_1_1"
	igual((Candado.cargar(A)), "ok", "partida nueva: carga")
	igual(Candado.guardar(A, d, false, 1), "ok", "guarda al amanecer")
	local B = servidor(a, "B")
	B.clave = "partida_1_1"
	local estado = Candado.cargar(B)
	igual(estado, "ocupado", "otro servidor no la coge mientras está abierta")
	igual(Candado.guardar(A, d, true, 1), "ok", "al acabar se suelta")
	local estadoB, guardadoB = Candado.cargar(B)
	igual(estadoB, "ok", "ya suelta, la coge el otro")
	igual(FP.arreglar(guardadoB, cat).noche, 6, "y sigue en la noche guardada")
	igual(Candado.guardar(A, d, false, 1), "perdido", "el viejo ya no puede escribir")
end

-- Resumen de las ranuras en los datos del jugador (lo que enseña el lobby).
do
	local j = Formato.arreglarJugador({ partidas = { ["1"] = { noche = 4, hora = 5 }, ["2"] = { noche = "x" }, ["3"] = 7 } })
	igual(j.partidas["1"].noche, 4, "ranura guardada")
	igual(j.partidas["2"], nil, "ranura rota: fuera")
	igual(j.partidas["3"], nil, "ranura que no es tabla: fuera")
	assert(Config.Partida.Ranuras >= 1, "al menos una ranura")
	for ranura in Config.Test.Partidas do
		local n = tonumber(ranura)
		assert(n and n >= 1 and n <= Config.Partida.Ranuras, `Config.Test.Partidas: ranura {ranura} fuera de rango`)
	end
	comprobaciones += 1
end

-- Llaves de las salas cerradas: azar con semilla, Config y qué llaves vuelven a su sitio (juego/servidor/Reparto).
do
	local Azar = cargar("src/shared/Azar")
	local Reparto = cargar("src/juego/servidor/Reparto")
	local FP = cargar("src/juego/servidor/FormatoPartida")

	-- La misma semilla da siempre el mismo sitio; muchas semillas reparten por todos los sitios.
	igual(Azar.entero(12345, 2, 1, 4), Azar.entero(12345, 2, 1, 4), "azar: misma semilla, mismo sitio")
	local vistos, fuera = {}, false
	for semilla = 1, 400 do
		local n = Azar.entero(semilla * 7919, 3, 1, 4)
		vistos[n] = (vistos[n] or 0) + 1
		fuera = fuera or n < 1 or n > 4
	end
	igual(fuera, false, "azar: siempre entre 1 y 4")
	for i = 1, 4 do
		assert((vistos[i] or 0) > 60, `azar: el sitio {i} sale muy poco ({vistos[i]})`)
	end
	igual(Azar.entero(2 ^ 31 - 2, 1, 1, 1), 1, "azar: semilla enorme, un solo sitio")
	local distintos = {}
	for orden = 1, 4 do
		distintos[Azar.entero(777, orden, 1, 1000)] = true
	end
	local cuantos = 0
	for _ in distintos do cuantos += 1 end
	igual(cuantos, 4, "azar: cada llave de la misma partida tira distinto")

	-- Config: cada sala con su llave, que es un objeto de mochila marcado como llave.
	local salas = {}
	for _, l in Config.Llaves do
		local o = Config.Objetos[l.Llave]
		assert(o and o.Llave == true and o.Tam[1] == 1 and o.Tam[2] == 1, `Config.Llaves: {l.Llave} no es una llave de 1x1`)
		assert(not salas[l.Sala], `Config.Llaves: sala repetida {l.Sala}`)
		salas[l.Sala] = true
		comprobaciones += 1
	end

	local function esLlave(tipo)
		return type(tipo) == "string" and Config.Objetos[tipo] ~= nil and Config.Objetos[tipo].Llave == true
	end
	-- Partida nueva: no hay ninguna, salen todas.
	local todas = { "LlaveSotano", "LlaveGaraje", "LlaveDesvan", "LlaveRico" }
	igual(#Reparto.faltan(todas, {}, {}, {}, esLlave), 4, "partida nueva: salen las cuatro")
	-- Sala abierta: su llave ya no sale aunque no esté.
	igual(#Reparto.faltan({ "LlaveGaraje" }, {}, {}, {}, esLlave), 1, "solo la de la sala cerrada")
	-- Suelta o en la mochila de uno que está: no se duplica.
	igual(#Reparto.faltan({ "LlaveSotano" }, { LlaveSotano = 1 }, {}, {}, esLlave), 0, "si ya está, no sale otra")
	-- En la mochila guardada de uno que no ha venido: se le quita y vuelve a su sitio.
	local guardadas = {
		["1"] = { cosas = { { tipo = "Pila" }, { tipo = "LlaveDesvan" }, { tipo = "LlaveRico" } } },
		["2"] = { cosas = { { tipo = "LlaveSotano" } } },
	}
	local faltan = Reparto.faltan({ "LlaveDesvan", "LlaveSotano" }, { LlaveSotano = 1 }, guardadas, { ["2"] = true }, esLlave)
	igual(#faltan, 1, "la del que no está vuelve a su sitio")
	igual(faltan[1], "LlaveDesvan", "y es la suya")
	igual(#guardadas["1"].cosas, 1, "al que no está se le quitan las llaves (también la de una sala ya abierta)")
	igual(guardadas["1"].cosas[1].tipo, "Pila", "y se queda lo demás")
	igual(#guardadas["2"].cosas, 1, "al que está no se le toca")
	-- Mochilas rotas no rompen nada.
	igual(#Reparto.faltan({ "LlaveRico" }, {}, { ["3"] = { cosas = "x" }, ["4"] = 5 }, {}, esLlave), 1, "mochilas rotas")

	-- Se guardan: la llave suelta pasa por FormatoPartida y la puerta abierta también.
	local cat = { objetos = Config.Objetos, pesados = Config.Pesados, maximo = Config.Partida.Sueltos, coche = Config.Coche,
		arreglarCoche = cargar("src/shared/Recetas").arreglarCoche }
	local d = FP.arreglar({
		noche = 2, semilla = 99,
		objetos = { { tipo = "LlaveGaraje", sitio = { -225, 4.2, -90, 0, 0, 0 } } },
		casa = { P0_1_22 = { vida = 160, abierta = true, bloqueada = false }, P6_14_m5 = { vida = 160, bloqueada = true } },
		mochilas = { ["7"] = { cosas = { { id = 1, tipo = "LlaveRico", x = 1, y = 1, girada = false } } } },
	}, cat)
	igual(d.objetos[1].tipo, "LlaveGaraje", "la llave suelta se guarda")
	igual(d.casa.P0_1_22.bloqueada, false, "la sala abierta se guarda")
	igual(d.casa.P6_14_m5.bloqueada, true, "la cerrada sigue cerrada")
	igual(d.semilla, 99, "la semilla se guarda")
	local Rejilla = cargar("src/shared/Rejilla")
	local r = Rejilla.desde(d.mochilas["7"], Config.Objetos, Config.Mochila.Ancho, Config.Mochila.Alto)
	igual(Rejilla.contar(r, "LlaveRico"), 1, "la llave de la mochila se guarda")
end

-- Vendedor: tratos con objetos que existen y cantidades con sentido.
do
	for i, t in Config.Vendedor.Trueques do
		assert(Config.Objetos[t.Da[1]] and Config.Objetos[t.Pide[1]], `trueque {i}: objeto que no existe`)
		assert(t.Da[2] >= 1 and t.Pide[2] >= 1, `trueque {i}: cantidades`)
		assert(not Config.Objetos[t.Da[1]].Llave and not Config.Objetos[t.Pide[1]].Llave, `trueque {i}: con llaves no se comercia`)
		comprobaciones += 1
	end
	for _, frase in Config.Vendedor.Frases do
		assert(Lang.es[frase], `frase del vendedor sin traducir: {frase}`)
		comprobaciones += 1
	end
	for _, o in Config.Objetos do
		assert(Lang.es[o.Nombre], `objeto sin traducir: {o.Nombre}`)
		comprobaciones += 1
	end
end

-- Taller y coche (paso 8): recetas, piezas del coche, refuerzo de ventanas y puertas, y que todo se guarde.
do
	local Recetas = cargar("src/shared/Recetas")
	local Defensa = cargar("src/shared/Defensa")
	local FP = cargar("src/juego/servidor/FormatoPartida")
	local C = Config.Coche

	-- Config con sentido: lo que piden y dan los bancos existe y tiene nombre en español.
	for banco, recetas in Config.Taller.Bancos do
		for i, r in recetas do
			assert(Config.Objetos[r.Da] or Config.Pesados[r.Da], `{banco} {i}: da algo que no existe`)
			assert(r.Tiempo > 0 and #r.Pide > 0, `{banco} {i}: tiempo o pide`)
			for _, p in r.Pide do
				assert((Config.Objetos[p[1]] or Config.Pesados[p[1]]) and p[2] >= 1, `{banco} {i}: pide {p[1]}`)
				assert(not (Config.Objetos[p[1]] and Config.Objetos[p[1]].Llave), `{banco} {i}: con llaves no se fabrica`)
			end
			comprobaciones += 1
		end
	end
	for tipo, p in Config.Pesados do
		assert(Lang.es[p.Nombre], `pesado sin español: {tipo}`)
		comprobaciones += 1
	end
	for _, p in C.Piezas do
		assert(Config.Objetos[p[1]] or Config.Pesados[p[1]], `pieza del coche que no existe: {p[1]}`)
		comprobaciones += 1
	end

	-- Recetas: qué falta.
	local pide = { { "Tablon", 2 }, { "Chatarra", 1 } }
	igual(#Recetas.falta(pide, { Tablon = 2, Chatarra = 3 }), 0, "receta: con todo, no falta nada")
	local falta = Recetas.falta(pide, { Tablon = 1 })
	igual(#falta, 2, "receta: faltan dos cosas")
	igual(falta[1][2], 1, "receta: falta un tablón")
	igual(falta[2][1], "Chatarra", "receta: y la chatarra")

	-- Coche: piezas en orden, ruedas de dos en dos, nada de más y la gasolina.
	local coche = Recetas.nuevoCoche()
	igual(Recetas.queFalta(coche, C), "Motor", "coche nuevo: lo primero, el motor")
	igual(Recetas.montar(coche, "Motor", C), true, "monta el motor")
	igual(Recetas.montar(coche, "Motor", C), false, "un segundo motor no")
	igual(Recetas.queFalta(coche, C), "Rueda", "luego las ruedas")
	igual(Recetas.montar(coche, "Rueda", C), true, "una rueda")
	igual(Recetas.necesita(coche, "Rueda", C), true, "aún le falta otra")
	Recetas.montar(coche, "Rueda", C)
	igual(Recetas.necesita(coche, "Rueda", C), false, "dos ruedas: ya")
	igual(Recetas.montar(coche, "Tronco", C), false, "un tronco no es una pieza")
	Recetas.montar(coche, "Bateria", C)
	Recetas.montar(coche, "Radiador", C)
	igual(Recetas.queFalta(coche, C), "Gasolina", "con todo menos gasolina")
	local ok, cabe = Recetas.montar(coche, "Bidon", C, 0.4)
	igual(ok and cabe, 0.4, "medio bidón entra entero")
	ok, cabe = Recetas.montar(coche, "Bidon", C, 1)
	igual(math.abs(cabe - (C.Gasolina - 0.4)) < 1e-9, true, "el segundo solo echa lo que cabe")
	igual(Recetas.queFalta(coche, C), nil, "listo para huir")
	igual(Recetas.montar(coche, "Bidon", C, 1), false, "lleno: no se echa más")

	-- Lo guardado del coche, roto o trucado.
	local raro = Recetas.arreglarCoche({ piezas = { Motor = 5, Rueda = 0 / 0, Ala = 1, Bateria = 1.7 }, gasolina = -3, porton = "si" }, C)
	igual(raro.piezas.Motor, 1, "más motores de los que caben -> 1")
	igual(raro.piezas.Rueda, nil, "rueda NaN: fuera")
	igual(raro.piezas.Ala, nil, "pieza que no existe: fuera")
	igual(raro.piezas.Bateria, 1, "decimales -> entero")
	igual(raro.gasolina, 0, "gasolina negativa -> 0")
	igual(raro.porton, false, "portón que no es booleano -> cerrado")
	igual(Recetas.queFalta(Recetas.arreglarCoche(nil, C), C), "Motor", "sin nada guardado: sin arreglar")

	-- Refuerzo: más vida, no dos veces, y se pierde al romperla.
	local cfgCasa = Config.Casa
	local e = Defensa.nueva("Ventana", cfgCasa)
	igual(Defensa.reforzar(e, cfgCasa, Config.Taller.Refuerzo), true, "se refuerza")
	igual(e.vidaMax, cfgCasa.VidaPersiana * Config.Taller.Refuerzo, "más vida")
	igual(Defensa.reforzar(e, cfgCasa, Config.Taller.Refuerzo), false, "no dos veces")
	e.persiana, e.listaEn = true, 0
	Defensa.golpe(e, 10, e.vidaMax - 1, cfgCasa)
	igual(e.refuerzo, true, "dañada pero entera: sigue reforzada")
	Defensa.reparar(e)
	igual(e.vida, cfgCasa.VidaPersiana * Config.Taller.Refuerzo, "reparada con un tablón: vuelve a la vida reforzada")
	Defensa.golpe(e, 11, 1e6, cfgCasa)
	igual(e.refuerzo, false, "rota: pierde el refuerzo")
	igual(e.vidaMax, cfgCasa.VidaPersiana, "y vuelve a la vida normal")
	local puerta = Defensa.nueva("Puerta", cfgCasa)
	Defensa.reforzar(puerta, cfgCasa, Config.Taller.Refuerzo)
	Defensa.romper(puerta, cfgCasa)
	igual(puerta.refuerzo, false, "puerta echada abajo: sin refuerzo")

	-- Se guarda con la partida: piezas del coche, gasolina, portón, refuerzo y lo fabricado (suelto o en la mochila).
	local cat = { objetos = Config.Objetos, pesados = Config.Pesados, maximo = Config.Partida.Sueltos, coche = C,
		arreglarCoche = Recetas.arreglarCoche }
	local d = FP.arreglar(guardable({
		noche = 4,
		casa = { V1_2_3 = { vida = 150, persiana = true, cristal = 0, abierta = false, refuerzo = true },
			V4_5_6 = { vida = 50, refuerzo = "si" } },
		coche = { piezas = { Motor = 1, Rueda = 1 }, gasolina = 0.5, porton = true },
		objetos = { { tipo = "Trampa", sitio = { 1, 1, 1, 0, 0, 0 } }, { tipo = "Radiador", sitio = { 2, 1, 1, 0, 0, 0 } } },
		pesados = { { tipo = "TablonReforzado", sitio = { 3, 1, 1, 0, 0, 0 } }, { tipo = "Rueda", sitio = { 4, 1, 1, 0, 0, 0 } } },
		mochilas = { ["9"] = { cosas = { { id = 1, tipo = "Bateria", x = 1, y = 1, girada = false } } } },
		final = "Huida",
	}, "partida del paso 8"), cat)
	igual(d.casa.V1_2_3.refuerzo, true, "ventana reforzada guardada")
	igual(d.casa.V4_5_6.refuerzo, nil, "refuerzo que no es booleano: fuera")
	igual(d.coche.piezas.Motor, 1, "motor montado guardado")
	igual(d.coche.piezas.Rueda, 1, "una rueda guardada")
	igual(d.coche.gasolina, 0.5, "gasolina del coche guardada")
	igual(d.coche.porton, true, "portón abierto guardado")
	igual(#d.objetos, 2, "trampa y radiador sueltos guardados")
	igual(#d.pesados, 2, "tablón reforzado y rueda sueltos guardados")
	local Rejilla = cargar("src/shared/Rejilla")
	igual(Rejilla.contar(Rejilla.desde(d.mochilas["9"], Config.Objetos, Config.Mochila.Ancho, Config.Mochila.Alto), "Bateria"), 1,
		"batería en la mochila guardada")
	igual(d.final, "Huida", "partida terminada")
	igual(FP.arreglar({ final = "Ganar" }, cat).final, nil, "final que no existe: fuera")
	igual(Recetas.queFalta(FP.arreglar({ noche = 2 }, cat).coche, C), "Motor", "partida vieja sin coche: sin arreglar")
	guardable(d, "partida del paso 8 arreglada")
end

-- Premio: un amanecer no paga dos veces, logros una vez y el diario cada 24 h.
do
	local Premio = cargar("src/comun/servidor/Premio")
	local R = Config.Recompensas
	local c = Premio.ciclo()
	igual(Premio.amanecer(c, "Dia", 4), false, "primer día (partida cargada): no paga")
	igual(Premio.amanecer(c, "Noche", 4), false, "anochecer: no paga")
	igual(Premio.amanecer(c, "Dia", 4), false, "mueren todos y vuelve el día: no paga")
	igual(Premio.amanecer(c, "Noche", 4), false, "anochecer otra vez")
	igual(Premio.amanecer(c, "Dia", 5), true, "amanecer de verdad: paga")
	igual(Premio.amanecer(c, "Dia", 5), false, "el mismo amanecer otra vez: no paga")
	igual(Premio.amanecer(c, "Noche", 5), false, "anochecer")
	igual(Premio.amanecer(c, "Dia", 5), false, "salto de pruebas al día sin pasar la noche: no paga")
	c.fase, c.noche = "Noche", 4
	igual(Premio.amanecer(c, "Dia", 5), false, "un amanecer ya pagado: no paga")
	igual(Premio.noche(R, 1), R.Noche, "primera noche")
	igual(Premio.noche(R, 1000), R.Noche + R.PorNoche * R.TopeNoches, "con tope")

	local d = Formato.jugadorNuevo()
	igual(Premio.logro(d, R, "Noche1"), R.Logros.Noche1.Monedas, "logro: paga")
	igual(Premio.logro(d, R, "Noche1"), 0, "logro: solo una vez")
	igual(Premio.logro(d, R, "NoExiste"), 0, "logro que no existe")
	igual(Premio.diario(d, R, 100000), R.Diario, "diario: el primero")
	igual(Premio.diario(d, R, 100000 + R.Cada - 1), 0, "diario: antes de 24 h no")
	igual(Premio.diario(d, R, 100000 + R.Cada), R.Diario, "diario: a las 24 h sí")
	d.diario = 1e12
	igual(Premio.diario(d, R, 200000), R.Diario, "diario: hora guardada absurda no bloquea")
	igual(Formato.arreglarJugador({ monedas = 3 }).diario, 0, "diario en datos viejos")
	Premio.sumar(d, math.huge)
	Premio.sumar(d, -5)
	igual(d.monedas, 0, "sumar: nada infinito ni negativo")
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
