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
	local antes = Lang.es["Night {n}"]
	Lang.es["Night {n}"] = "Noche {n}"
	igual(Lang.t(nil, "Night {n}", { n = 3 }), "Night 3", "sin jugador: inglés")
	igual(Lang.t(espanol, "Night {n}", { n = 3 }), "Noche 3", "jugador en español")
	igual(Lang.t(espanol, "Not translated"), "Not translated", "sin traducción: inglés")
	igual(Lang.deLocale("es-mx"), "es", "es-mx es español")
	igual(Lang.deLocale("pt-br"), "en", "pt-br va en inglés")
	Lang.es["Night {n}"] = antes -- la de verdad, que la usa Ambiente
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

-- Lang: todo texto del jugador escrito en el código tiene su español. Lee cada .luau y saca los literales de
-- Lang.t(x, "…") (también con if … then "…" else "…"), los ActionText de los prompts (los traduce comun/cliente/Controles),
-- el último texto de cada nuevoPrompt(…, "…") y las tablas de textos que llegan a Lang.t por variable.
do
	local function conEspanol(texto: string, donde: string)
		if texto ~= "" then
			assert(Lang.es[texto], `sin español en {donde}: "{texto}"`)
			comprobaciones += 1
		end
	end
	local function recorrer(carpeta: string)
		for _, nombre in fs.readDir(carpeta) do
			local ruta = carpeta .. "/" .. nombre
			if fs.isDir(ruta) then
				recorrer(ruta)
			elseif string.match(nombre, "%.luau$") then
				local f = fs.readFile(ruta)
				for t in string.gmatch(f, "Lang%.t%(%s*[%w_%.]+%s*,%s*\"([^\"\n]*)\"") do conEspanol(t, ruta) end
				for a, b in string.gmatch(f, "Lang%.t%(%s*[%w_%.]+%s*,%s*if%s[^\n]-%sthen%s*\"([^\"\n]*)\"%s*else%s*\"([^\"\n]*)\"") do
					conEspanol(a, ruta)
					conEspanol(b, ruta)
				end
				for linea in string.gmatch(f, "[^\n]+") do
					if string.find(linea, "ActionText%s*=[^=]") then
						-- Sin las comparaciones (if forma == "Foto" then …): solo los textos que se ponen.
						local sinComparar = string.gsub(linea, "[=~]=%s*\"[^\"]*\"", "")
						for t in string.gmatch(sinComparar, "\"([^\"]*)\"") do conEspanol(t, ruta) end
					end
				end
				-- Los avisos que pasan por un ayudante que llama a Lang.t (acabar, Viaje.volver, avisar…). El avisar de
				-- Candado es para la consola, no para el jugador.
				local ayudantes = { "%f[%w_%.]acabar%(%s*", "Viaje%.volver%([^,\n]+,%s*" }
				if not string.find(ruta, "Candado") then
					table.insert(ayudantes, "%f[%w_%.]avisar%w*%(%s*")
					table.insert(ayudantes, "%f[%w_%.]avisar%w*%(%s*[%w_%.]+%s*,%s*")
				end
				for _, ayudante in ayudantes do
					for t in string.gmatch(f, ayudante .. "\"([^\"\n]*)\"") do conEspanol(t, ruta) end
					for a, b in string.gmatch(f, ayudante .. "if%s[^\n]-%sthen%s*\"([^\"\n]*)\"%s*else%s*\"([^\"\n]*)\"") do
						conEspanol(a, ruta)
						conEspanol(b, ruta)
					end
				end
				for args in string.gmatch(f, "nuevoPrompt(%b())") do
					local t = string.match(args, "\"([^\"]*)\"%s*%)$")
					if t then conEspanol(t, ruta) end
				end
			end
		end
	end
	for _, carpeta in { "src/juego", "src/lobby", "src/comun" } do
		recorrer(carpeta)
	end
	-- Tablas de textos de prompts y carteles que no pasan por un literal de Lang.t.
	local yaHay = string.match(fs.readFile("src/juego/servidor/Pistas.luau"), "local YA_HAY = (%b{})") :: string
	for t in string.gmatch(yaHay, "\"([^\"]*)\"") do conEspanol(t, "Pistas YA_HAY") end
	local usos = string.match(fs.readFile("src/juego/cliente/CargarVista.luau"), "local USOS[^\n]*\n(.-)\n}") :: string
	for textos in string.gmatch(usos, "textos = (%b{})") do
		for t in string.gmatch(textos, "\"([^\"]*)\"") do conEspanol(t, "CargarVista USOS") end
	end
	for t in string.gmatch(usos, "texto = \"([^\"]*)\"") do conEspanol(t, "CargarVista USOS") end
	for _, clase in Config.Clases do
		conEspanol(clase.Nombre, "Config.Clases")
		conEspanol(clase.Texto, "Config.Clases")
	end
	for _, pase in Config.Compras.Pases do
		conEspanol(pase.Nombre, "Config.Compras.Pases")
		conEspanol(pase.Texto, "Config.Compras.Pases")
	end
	for _, cosa in Config.Cosmeticos do
		conEspanol(cosa.Nombre, "Config.Cosmeticos")
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
	igual(Premio.final(d, R, "Bestia"), R.FinalBestia + R.Logros.Bestia.Monedas, "final de la Bestia: premio y logro")
	igual(Premio.final(d, R, "Bestia"), R.FinalBestia, "final de la Bestia otra vez: sin logro")
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

-- Clases y Stats: Ids sin repetir, ventajas que existen y valores por clase.
do
	local Stats = cargar("src/shared/Stats")
	local vistos = {}
	for _, clase in Config.Clases do
		assert(not vistos[clase.Id], `clase repetida: {clase.Id}`)
		vistos[clase.Id] = true
		for ventaja, valor in clase.Ventajas do
			assert(Config.Ventajas[ventaja] ~= nil, `{clase.Id}: ventaja desconocida {ventaja}`)
			assert(type(valor) == "number" and valor >= 0, `{clase.Id}: {ventaja} no es un número válido`)
			comprobaciones += 1
		end
	end
	local function jugador(clase)
		return { GetAttribute = function(_, nombre) return if nombre == "Clase" then clase else nil end }
	end
	igual(Stats.valor(jugador(nil), "Velocidad"), 1, "sin clase: la base")
	igual(Stats.valor(jugador("NoExiste"), "Velocidad"), 1, "clase que no existe: la base")
	igual(Stats.valor(jugador("Corredor"), "Velocidad"), Stats.clase("Corredor").Ventajas.Velocidad, "corredor: más rápido")
	igual(Stats.valor(jugador("Corredor"), "Hachazo"), 1, "corredor: hachazo normal")
	igual(Stats.valor(nil, "Troncos"), 0, "sin jugador: la base")
	igual(Formato.arreglarJugador({ monedas = 3 }).clase, "", "clase en datos viejos")
end

-- Tienda: precio y monedas, la primera clase gratis, pulsar muchas veces y cosméticos puestos.
do
	local Comprar = cargar("src/comun/servidor/Comprar")
	local vistos = {}
	for _, cosa in Config.Cosmeticos do
		assert(not vistos[cosa.Id], `cosmético repetido: {cosa.Id}`)
		assert(cosa.Precio > 0 and cosa.Tipo and cosa.Nombre, `{cosa.Id}: le falta algo`)
		vistos[cosa.Id] = true
		comprobaciones += 1
	end
	for _, clase in Config.Clases do
		assert(type(clase.Precio) == "number" and clase.Precio > 0 and clase.Texto, `{clase.Id}: sin precio o texto`)
	end
	local C, K = Config.Clases, Config.Cosmeticos
	local d = Formato.jugadorNuevo()
	igual(Comprar.clase(d, C, "Corredor"), "ok", "primera clase sin monedas")
	igual(d.monedas, 0, "primera clase gratis")
	igual(d.clase, "Corredor", "la comprada queda elegida")
	igual(Comprar.clase(d, C, "Corredor"), "tiene", "no se compra dos veces")
	igual(Comprar.clase(d, C, "Lenador"), "monedas", "segunda clase sin monedas")
	igual(d.clases.Lenador, nil, "sin monedas no la da")
	d.monedas = C[1].Precio + 10
	-- Muchos toques seguidos: una sola compra y nunca en negativo.
	local compradas = 0
	for _ = 1, 20 do
		for _, clase in C do
			if Comprar.clase(d, C, clase.Id) == "ok" then
				compradas += 1
			end
		end
	end
	igual(compradas, 1, "muchos toques: una compra")
	igual(d.monedas, 10, "muchos toques: cobra una vez")
	igual(Comprar.clase(d, C, "NoExiste"), "nada", "clase que no existe")
	igual(Comprar.clase(d, C, 5), "nada", "id que no es texto")
	d.monedas = 0 / 0
	igual(Comprar.cosmetico(d, K, K[1].Id), "monedas", "monedas NaN no compran")
	d.monedas = K[1].Precio
	igual(Comprar.cosmetico(d, K, K[1].Id), "ok", "cosmético con monedas justas")
	igual(d.monedas, 0, "cosmético cobrado")
	igual(Comprar.puesto(d, K, K[1].Tipo).Id, K[1].Id, "el comprado queda puesto")
	igual(Comprar.poner(d, K, K[1].Tipo, K[2].Id), false, "no se pone uno que no es suyo")
	igual(Comprar.poner(d, K, "Coche", K[1].Id), false, "no se pone en otro tipo")
	igual(Comprar.poner(d, K, K[1].Tipo, ""), true, "volver al de serie")
	igual(Comprar.puesto(d, K, K[1].Tipo), nil, "de serie")
	d.puestos[K[1].Tipo] = K[2].Id -- guardado a mano sin tenerlo
	igual(Comprar.puesto(d, K, K[1].Tipo), nil, "puesto que no es suyo no cuenta")
	igual(type(Formato.arreglarJugador({ monedas = 3 }).puestos), "table", "puestos en datos viejos")
end

-- Ajustes (14.4): Rendimiento se guarda como booleano y los datos viejos o rotos quedan en false.
do
	igual(Formato.jugadorNuevo().rendimiento, false, "rendimiento: apagado al empezar")
	igual(Formato.arreglarJugador({ monedas = 3 }).rendimiento, false, "rendimiento en datos viejos")
	igual(Formato.arreglarJugador({ rendimiento = "si" }).rendimiento, false, "rendimiento que no es booleano: false")
	local d = Formato.arreglarJugador({ monedas = 3, rendimiento = true })
	igual(d.rendimiento, true, "rendimiento guardado se mantiene")
	guardable(d, "datos con rendimiento")
end

-- Compras con Robux (Recibos): una compra no se entrega dos veces, el regalo de un pase una sola vez y revivir solo
-- de noche, a un muerto y una vez por noche.
do
	local Recibos = cargar("src/comun/servidor/Recibos")
	local d = Formato.jugadorNuevo()
	igual(Recibos.apuntar(d, "A", 100, 3, 300), true, "compra nueva")
	igual(Recibos.apuntar(d, "A", 101, 3, 300), false, "Roblox pregunta otra vez por la misma")
	igual(d.monedas, 300, "las monedas, una vez")
	for i = 1, 5 do
		Recibos.apuntar(d, `B{i}`, 200 + i, 3, 0)
	end
	local cuantas = 0
	for _ in d.compras do
		cuantas += 1
	end
	igual(cuantas, 3, "solo recuerda las últimas")
	igual(d.compras.B5, 205, "la más nueva se queda")
	igual(d.compras.A, nil, "la más vieja se olvida")
	d.compras.Vieja = true -- de antes de apuntar la hora
	Recibos.apuntar(d, "C", 300, 3, 0)
	igual(d.compras.Vieja, nil, "las sin hora son las más viejas")
	-- Guardar y cargar no la vuelve a dar.
	local cargado = Formato.arreglarJugador(guardable(d, "datos"))
	igual(Recibos.apuntar(cargado, "C", 400, 3, 300), false, "tras guardar y cargar no se repite")

	local paquete
	for _, pase in Config.Compras.Pases do
		if pase.Regalo then
			paquete = pase
		end
	end
	local antes = d.monedas
	igual(Recibos.regalo(d, paquete), true, "regalo del pase")
	igual(Recibos.regalo(d, paquete), false, "el regalo no se repite")
	igual(d.monedas, antes + paquete.Regalo.Monedas, "monedas del regalo una vez")
	for _, id in paquete.Regalo.Cosmeticos do
		local existe = false
		for _, cosa in Config.Cosmeticos do
			existe = existe or cosa.Id == id
		end
		igual(existe, true, `cosmético del regalo existe: {id}`)
		igual(d.cosmeticos[id], true, `cosmético del regalo dado: {id}`)
	end
	igual(Recibos.regalo(d, Config.Compras.Pases[1]), false, "pase sin regalo")
	igual(type(Formato.arreglarJugador({ monedas = 3 }).regalos), "table", "regalos en datos viejos")

	local revividos = {}
	igual(Recibos.revivible(false, true, revividos, 1, 1), false, "de día no")
	igual(Recibos.revivible(true, false, revividos, 1, 1), false, "a un vivo no")
	igual(Recibos.revivible(true, true, revividos, 1, 1), true, "de noche a un muerto sí")
	revividos[1] = 1
	igual(Recibos.revivible(true, true, revividos, 1, 1), false, "dos veces la misma noche no")
	igual(Recibos.revivible(true, true, revividos, 2, 1), true, "a otro sí")
	igual(Recibos.revivible(true, true, revividos, 1, 2), true, "la noche siguiente sí")

	-- Los pases: ventajas que existen, sin repetir y sin chocar con las de las clases.
	local vistas = {}
	for _, pase in Config.Compras.Pases do
		igual(vistas[pase.Ventaja], nil, `pase repetido: {pase.Ventaja}`)
		vistas[pase.Ventaja] = true
		for ventaja in pase.Ventajas or {} do
			igual(Config.Ventajas[ventaja] ~= nil, true, `ventaja del pase existe: {ventaja}`)
			for _, clase in Config.Clases do
				igual(clase.Ventajas[ventaja], nil, `ventaja del pase sin clase que la toque: {ventaja}`)
			end
		end
	end
end

-- Pistas de la historia (12.1): se guardan con la partida y lo viejo sin pistas sigue cargando.
do
	local FP = cargar("src/juego/servidor/FormatoPartida")
	local Historia = cargar("src/shared/Historia")
	local LangEs = cargar("src/shared/LangEs")
	local cat = { objetos = Config.Objetos, pesados = Config.Pesados, maximo = Config.Partida.Sueltos, coche = Config.Coche,
		arreglarCoche = cargar("src/shared/Recetas").arreglarCoche, pistas = #Historia }
	igual(#Historia, 12, "las 12 pistas de docs/historia.md")
	for n, p in Historia do
		igual(LangEs[p.que] ~= nil and LangEs[p.texto] ~= nil, true, `pista {n} traducida`)
		igual(p.forma == "Nota" or p.forma == "Foto" or p.forma == "Libreta" or p.forma == "Diario", true, `pista {n} con forma`)
	end
	local fuente = fs.readFile("src/juego/servidor/Pistas.luau")
	local _, sitios = string.gsub(string.match(fuente, "local SITIOS: { CFrame } = (%b{})") :: string, "\n%s*en%a+%(", "")
	igual(sitios, #Historia, "un sitio por pista")

	local vieja = FP.arreglar({ version = 1, noche = 3, semilla = 7 }, cat)
	igual(#vieja.pistas, 0, "guardado viejo sin pistas: ninguna leída")
	local d = FP.arreglar(guardable({ version = 1, noche = 3, semilla = 7, pistas = { 12, 3, 1 } }, "pistas"), cat)
	igual(table.concat(d.pistas, ","), "1,3,12", "las leídas, en orden")
	local mala = FP.arreglar({ noche = 2, pistas = { 2, 2, 0, 13, -1, 1.5, 0 / 0, math.huge, "4", 5 } }, cat)
	igual(table.concat(mala.pistas, ","), "2,5", "sin repetidas, rotas ni que no existen")
	igual(#FP.arreglar({ noche = 2, pistas = "todas" }, cat).pistas, 0, "pistas que no son lista: ninguna")
	guardable(d, "partida con pistas")
end

-- Final de la Bestia (12.2): la reja en el banco del sótano y lo preparado, guardado con la partida (lo viejo sigue
-- cargando).
do
	local FP = cargar("src/juego/servidor/FormatoPartida")
	local Recetas = cargar("src/shared/Recetas")
	local Historia = cargar("src/shared/Historia")
	local sotano = Recetas.delBanco("Sotano", Config)
	igual(#sotano, #Config.Taller.Bancos.Sotano + 1, "banco del sótano: sus recetas y la reja")
	igual(sotano[#sotano].Da, "Reja", "la reja, al final (las de antes no se mueven)")
	igual(sotano[1].Da, Config.Taller.Bancos.Sotano[1].Da, "la primera receta sigue siendo la primera")
	igual(sotano[#sotano].Pide, Config.Bestia.Reja.Pide, "la reja pide lo de Config.Bestia.Reja")
	igual(Config.Pesados.Reja ~= nil, true, "la reja es pesada")
	igual(#Config.Taller.Bancos.Sotano, 2, "delBanco no toca Config")
	igual(#Recetas.delBanco("Garaje", Config), #Config.Taller.Bancos.Garaje, "el garaje, sin reja")
	local pista = Historia[sotano[#sotano].Pista]
	igual(pista ~= nil and string.find(pista.texto, "gate") ~= nil, true, "la pista de la reja habla de la reja")

	-- Las claves de los puntos, sacadas de Preparativos (no se puede cargar fuera de Roblox).
	local fuente = fs.readFile("src/juego/servidor/Preparativos.luau")
	local claves = {}
	for clave in string.gmatch(string.match(fuente, "local PUNTOS = (%b{})") :: string, '{ "(%w+)"') do
		table.insert(claves, clave)
	end
	igual(#claves, Config.Bestia.Puntos, "un punto de gasolina por cada uno de Config.Bestia.Puntos")
	local cat = { objetos = Config.Objetos, pesados = Config.Pesados, maximo = Config.Partida.Sueltos, coche = Config.Coche,
		arreglarCoche = Recetas.arreglarCoche, pistas = #Historia, puntos = claves }

	local vieja = FP.arreglar({ version = 1, noche = 3, semilla = 7 }, cat)
	igual(#vieja.preparativos.gasolina, 0, "guardado viejo: sin gasolina")
	igual(vieja.preparativos.rastro or vieja.preparativos.reja, false, "guardado viejo: sin rastro ni reja")
	local buena = FP.arreglar(guardable({ version = 1, noche = 4, semilla = 7, final = "Bestia",
		preparativos = { gasolina = { claves[3], claves[1] }, rastro = false, reja = true } }, "preparativos"), cat)
	igual(table.concat(buena.preparativos.gasolina, ","), claves[1] .. "," .. claves[3], "los puntos llenos, en orden")
	igual(buena.preparativos.reja, true, "la reja montada")
	igual(buena.final, "Bestia", "final de la Bestia")
	local todos = FP.arreglar(guardable({ noche = 4, preparativos = { gasolina = table.clone(claves), rastro = true } }, "todos"), cat)
	igual(todos.preparativos.rastro, true, "con los 6 puntos, el rastro vale")
	local rota = FP.arreglar({ noche = 2, final = "Otro", preparativos = { gasolina = { claves[2], claves[2], "Tejado", 5, true },
		rastro = true, reja = "si" } }, cat)
	igual(table.concat(rota.preparativos.gasolina, ","), claves[2], "sin repetidos ni puntos que no existen")
	igual(rota.preparativos.rastro, false, "rastro sin todos los puntos: fuera")
	igual(rota.preparativos.reja, false, "reja que no es true: sin montar")
	igual(rota.final, nil, "un final que no existe: partida sin terminar")
	igual(#FP.arreglar({ noche = 2, preparativos = "todo" }, cat).preparativos.gasolina, 0, "preparativos que no son tabla: nada")
	guardable(buena, "partida con preparativos")
end

-- Tutorial (14.2): los pasos del día en orden, lo ya hecho se salta, el anochecer pasa a las cortinas, se acaba al
-- amanecer y si mueren todos vuelve a lo del día.
do
	local PT = cargar("src/shared/PasosTutorial")
	local function vista(cambios)
		local v = { fase = "Dia", noche = 1, quedan = 100, aviso = 20, mochila = false, hacha = false, cargando = nil,
			generador = false, cortinas = 3 }
		for clave, valor in cambios do
			v[clave] = valor
		end
		return v
	end
	local e = PT.nuevo()
	igual(PT.avanzar(e, vista({})), false, "tutorial: empieza sin acabar")
	igual(e.paso, "Mochila", "tutorial: primero la mochila")
	PT.avanzar(e, vista({ mochila = true }))
	igual(e.paso, "Hacha", "tutorial: luego el hacha")
	PT.avanzar(e, vista({ hacha = true }))
	igual(e.paso, "Correr", "tutorial: con el hacha, correr al bosque (14.8)")
	PT.avanzar(e, vista({ cargando = "Tronco" }))
	igual(e.paso, "Serrar", "tutorial: con un tronco en las manos no se pide correr (cargando no se puede)")
	local corre = PT.nuevo()
	PT.avanzar(corre, vista({ mochila = true, hacha = true }))
	igual(corre.paso, "Correr", "tutorial: paso de correr")
	PT.avanzar(corre, vista({ corrido = true }))
	igual(corre.paso, "Tronco", "tutorial: corriendo un momento se pasa a talar")
	local yaCorrio = PT.nuevo()
	PT.avanzar(yaCorrio, vista({ corrido = true }))
	igual(yaCorrio.paso, "Mochila", "tutorial: haber corrido no salta los pasos de antes")
	PT.avanzar(yaCorrio, vista({ mochila = true, hacha = true }))
	igual(yaCorrio.paso, "Tronco", "tutorial: si ya corrió antes, no se le pide")
	local sinCorrer = PT.nuevo()
	PT.avanzar(sinCorrer, vista({ mochila = true, hacha = true, quedan = 10 }))
	igual(sinCorrer.paso, "Cortinas", "tutorial: sin haber corrido, al anochecer igual a las cortinas")
	PT.avanzar(e, vista({ hacha = true, cargando = "Tablon" }))
	igual(e.paso, "Generador", "tutorial: con un tablón en las manos se salta talar y serrar")
	PT.avanzar(e, vista({ generador = true }))
	igual(e.paso, "Espera", "tutorial: todo lo del día hecho, a esperar la noche")
	PT.avanzar(e, vista({ quedan = 15 }))
	igual(e.paso, "Cortinas", "tutorial: al ponerse el sol, las cortinas")
	igual(e.noche, 1, "tutorial: apunta la noche que enseña")
	PT.avanzar(e, vista({ fase = "Noche", cortinas = 0 }))
	igual(e.paso, "Amanecer", "tutorial: cortinas cerradas, a aguantar")
	PT.avanzar(e, vista({ fase = "Noche", cortinas = 2 }))
	igual(e.paso, "Amanecer", "tutorial: si luego abren alguna, no vuelve atrás")
	-- Mueren todos: vuelve el mismo día.
	igual(PT.avanzar(e, vista({ fase = "Dia", noche = 1 })), false, "tutorial: volver al día no lo acaba")
	igual(e.paso, "Espera", "tutorial: tras morir todos, lo del día ya estaba hecho")
	igual(e.noche, nil, "tutorial: la noche se vuelve a apuntar")
	PT.avanzar(e, vista({ fase = "Noche", cortinas = 1 }))
	igual(e.paso, "Cortinas", "tutorial: esa noche otra vez las cortinas")
	igual(PT.avanzar(e, vista({ fase = "Dia", noche = 2 })), false, "tutorial: amanecer sin cerrar las cortinas: no acaba")
	igual(e.paso, "Espera", "tutorial: sin cortinas, a esperar la noche siguiente")
	PT.avanzar(e, vista({ fase = "Noche", noche = 2, cortinas = 0 }))
	igual(e.paso, "Amanecer", "tutorial: la noche 2, con las cortinas cerradas")
	igual(PT.avanzar(e, vista({ fase = "Dia", noche = 3 })), true, "tutorial: al amanecer se acaba")
	-- Quieto todo el rato (AFK): no se acaba nunca.
	local quieto = PT.nuevo()
	PT.avanzar(quieto, vista({ fase = "Noche", noche = 1, cortinas = 4 }))
	igual(PT.avanzar(quieto, vista({ fase = "Dia", noche = 2 })), false, "tutorial: sin hacer nada no hay premio")
	-- Quien entra de noche: directo a las cortinas y se acaba al amanecer.
	local tarde = PT.nuevo()
	PT.avanzar(tarde, vista({ fase = "Noche", noche = 4, cortinas = 0 }))
	igual(tarde.paso, "Amanecer", "tutorial: entrar de noche con todo cerrado")
	igual(PT.avanzar(tarde, vista({ fase = "Dia", noche = 5, quedan = 5 })), true, "tutorial: amanecer visto ya de tarde")
	igual(PT.numero("Cortinas"), 8, "tutorial: número del paso")
	igual(PT.numero("Correr"), 3, "tutorial: correr va tras el hacha")
	igual(#PT.LISTA, #PT.DIA + 3, "tutorial: los del día y los tres de la noche")
	igual(PT.numero("Nada"), 0, "tutorial: paso que no existe")
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

-- Postura (14.6): agacharse y asomarse. Solo ("Agachado", sí/no) y ("Asomar", -1/0/1), como poco cada
-- Config.Postura.Cada s, y nada muerto, escondido ni cargando (con la mochila abierta, agacharse sí y asomarse no).
do
	local PR = cargar("src/shared/PosturaReglas")
	local cada = Config.Postura.Cada
	local function quien(cambios)
		local j = { vivo = true, escondido = false, cargando = false, mochila = false }
		for clave, valor in cambios or {} do
			j[clave] = valor
		end
		return j
	end
	local e = PR.nuevo()
	local cambia, agachado = PR.pedir(e, "Agachado", true, 10, quien())
	igual(cambia, true, "postura: agacharse")
	igual(agachado.agachado, true, "postura: queda agachado")
	igual(e.agachado, false, "postura: el estado de antes no se toca")
	igual((PR.pedir(agachado, "Agachado", false, 10 + cada / 2, quien())), false, "postura: demasiado seguido, no cambia")
	igual((PR.pedir(agachado, "Agachado", true, 20, quien())), false, "postura: pedir lo que ya está no es un cambio")
	local _, igualQue = PR.pedir(agachado, "Agachado", true, 20, quien())
	igual(igualQue.ultimo, 10, "postura: lo que no cambia no cuenta para Cada")
	local asomado
	cambia, asomado = PR.pedir(agachado, "Asomar", 1, 10 + cada + 0.01, quien())
	igual(cambia, true, "postura: asomarse pasado Cada")
	igual(asomado.asomado, 1, "postura: asomado a la derecha")
	igual(asomado.agachado, true, "postura: se puede asomar agachado")
	local _, izquierda = PR.pedir(asomado, "Asomar", -1, 30, quien())
	igual(izquierda.asomado, -1, "postura: de un lado al otro")
	local _, derecho = PR.pedir(izquierda, "Asomar", -0, 31, quien())
	igual(1 / derecho.asomado, math.huge, "postura: -0 queda en 0")
	-- Lo que llega del cliente puede ser cualquier cosa.
	local raros = {
		{ "Asomar", 0.5 }, { "Asomar", 2 }, { "Asomar", -2 }, { "Asomar", 0 / 0 }, { "Asomar", math.huge },
		{ "Asomar", "1" }, { "Asomar", true }, { "Asomar" }, { "Agachado", 1 }, { "Agachado", "true" }, { "Agachado" },
		{ "Agachado", {} }, { "Saltar", true }, { 5, true }, {},
	}
	for i, raro in raros do
		igual((PR.pedir(PR.nuevo(), raro[1], raro[2], 100, quien())), false, `postura: petición rara {i} no cambia`)
	end
	-- Muerto, escondido o cargando: nada (tampoco levantarse: Postura ya lo ha quitado).
	igual((PR.pedir(PR.nuevo(), "Agachado", true, 100, quien({ vivo = false }))), false, "postura: muerto no se agacha")
	igual((PR.pedir(PR.nuevo(), "Agachado", true, 100, quien({ escondido = true }))), false, "postura: escondido no se agacha")
	igual((PR.pedir(PR.nuevo(), "Asomar", -1, 100, quien({ cargando = true }))), false, "postura: cargando no se asoma")
	igual((PR.pedir(agachado, "Agachado", false, 100, quien({ vivo = false }))), false, "postura: muerto no cambia nada")
	-- Mochila abierta: agacharse sí; asomarse no, pero dejar de asomarse sí.
	igual((PR.pedir(PR.nuevo(), "Agachado", true, 100, quien({ mochila = true }))), true, "postura: agacharse con la mochila")
	igual((PR.pedir(PR.nuevo(), "Asomar", 1, 100, quien({ mochila = true }))), false, "postura: con la mochila no se asoma")
	igual((PR.pedir(asomado, "Asomar", 0, 100, quien({ mochila = true }))), true, "postura: con la mochila se deja de asomar")
	-- Limpiar: lo que ya no puede ser se quita, sin contar como cambio.
	local todo = { agachado = true, asomado = 1, ultimo = 5 }
	local quita, limpio = PR.limpiar(todo, quien({ escondido = true }))
	igual(quita, true, "postura: al esconderse se quita")
	igual(limpio.agachado, false, "postura: escondido, de pie")
	igual(limpio.asomado, 0, "postura: escondido, sin asomarse")
	igual(limpio.ultimo, 5, "postura: quitarla no cuenta para Cada")
	igual(todo.agachado, true, "postura: limpiar no toca el de antes")
	igual(select(2, PR.limpiar(todo, quien({ cargando = true }))).agachado, false, "postura: al cargar algo, de pie")
	igual(select(2, PR.limpiar(todo, quien({ vivo = false }))).asomado, 0, "postura: al morir, sin asomarse")
	quita, limpio = PR.limpiar(todo, quien({ mochila = true }))
	igual(limpio.agachado, true, "postura: al abrir la mochila sigue agachado")
	igual(limpio.asomado, 0, "postura: al abrir la mochila deja de asomarse")
	igual((PR.limpiar(todo, quien())), false, "postura: vivo y libre, no se quita nada")
	igual((PR.limpiar(PR.nuevo(), quien({ vivo = false }))), false, "postura: de pie ya, nada que quitar")
	local reaparece = PR.quitar(todo)
	igual(reaparece.agachado or reaparece.asomado ~= 0, false, "postura: al reaparecer, de pie y derecho")
	igual(Config.Postura.Velocidad > 0 and Config.Postura.Velocidad < 1, true, "postura: agachado anda más despacio")
	local CP = Config.Postura
	igual(CP.Baja > 0 and CP.Baja < 2.5 and CP.Asomar > 0 and CP.Asomar < 2, true, "postura: la cámara no sale del cuerpo")
	igual(CP.Giro > 0 and CP.Giro < 30 and CP.Cada > 0 and CP.Cada < 1, true, "postura: ladeo y espera razonables")
	local remotes = fs.readFile("src/shared/Remotes.luau")
	igual(string.find(remotes, '"Postura"', 1, true) ~= nil, true, "postura: existe el remote Postura")

	-- Esconderse agachado: debajo de algo solo te ven y te oyen muy de cerca; agachado, peor; te pueden oler.
	igual(PR.alcanceVista(60, false, false), 60, "esconderse: de pie te ven como siempre")
	igual(PR.alcanceVista(60, true, false), 60 * CP.VistaAgachado, "esconderse: agachado te ven peor")
	igual(PR.alcanceVista(60, true, true), CP.VerCubierto, "esconderse: debajo de algo, solo muy de cerca")
	igual(PR.alcanceVista(2, true, true), 2, "esconderse: nunca más lejos que su vista")
	igual(PR.alcanceOido(8, false, false), 8, "esconderse: de pie te oyen como siempre")
	igual(PR.alcanceOido(8, true, false), math.min(8, CP.OirAgachado), "esconderse: agachado te oyen peor")
	igual(PR.alcanceOido(8, true, true), math.min(8, CP.VerCubierto), "esconderse: debajo de algo casi no te oyen")
	igual(PR.alcanceOido(1, true, true), 1, "esconderse: nunca más lejos que su oído")
	igual(PR.alcanceOido(1, true, false), 1, "esconderse: agachado, tampoco")
	local olor = 0
	for _ = 1, 10 do
		olor = PR.oler(olor, 0.25, CP.Olfato - 1)
	end
	igual(olor, 2.5, "esconderse: cerca, el olor sube 1 por segundo")
	igual(PR.huele(olor), false, "esconderse: aún no sabe dónde estás")
	igual(PR.oler(olor, 1, CP.Olfato + 1), 2, "esconderse: lejos, se le olvida a la mitad de deprisa")
	igual(PR.oler(0.1, 1, CP.Olfato + 1), 0, "esconderse: el olor no baja de 0")
	igual(PR.oler(CP.Huele - 0.1, 1, 0), CP.Huele, "esconderse: el olor no pasa de Huele")
	igual(PR.huele(PR.oler(CP.Huele - 0.1, 1, 0)), true, "esconderse: a Huele s ya te ha olido")
	-- Quién te ha pillado (escena de muerte): ya no se adivina en el cliente (PosturaReglas.quienPilla): el servidor manda
	-- el modelo del bicho con el remote Muerte y MuerteVista ruge con ese (banco tests/bancos/muerte.luau).
	igual(PR.quienPilla, nil, "pillar: sin quienPilla en PosturaReglas")
	local muerteVista = fs.readFile("src/juego/cliente/MuerteVista.luau")
	igual(string.find(muerteVista, "PosturaReglas", 1, true), nil, "pillar: MuerteVista no adivina con PosturaReglas")
	igual(string.find(muerteVista, ".candidatos(", 1, true), nil, "pillar: MuerteVista no pide candidatos a las Vistas")
	igual(string.find(muerteVista, "Vista.rugir(cabeza) or", 1, true), nil, "pillar: la escena no elige por orden fijo")
	for _, bicho in { "Golpeador", "Raspador", "Trepador", "Imitador", "Acechador", "Bestia" } do
		local vista = fs.readFile(`src/juego/cliente/{bicho}Vista.luau`)
		igual(string.find(vista, `function {bicho}Vista.rugir(punto: Vector3, modelo: Model?)`, 1, true) ~= nil, true,
			`pillar: {bicho}Vista.rugir del elegido`)
		local mira = string.find(muerteVista, `{bicho}Vista,`, 1, true) or string.find(muerteVista, `{bicho}Vista }`, 1, true)
		igual(mira ~= nil, true, `pillar: MuerteVista mira a {bicho}Vista`)
	end
	-- Todos los que matan dicen quién: Muerte.matar(jugador, cabeza, modelo) con los tres (una coma fuera de paréntesis
	-- de más cuenta como otro argumento).
	local matan = 0
	for _, nombre in fs.readDir("src/juego/servidor") do
		local texto = if string.match(nombre, "%.luau$") then fs.readFile(`src/juego/servidor/{nombre}`) else ""
		for args in string.gmatch(texto, "Muerte%.matar(%b())") do
			local dentro = string.gsub(string.sub(args, 2, -2), "%b()", "")
			local _, comas = string.gsub(dentro, ",", "")
			igual(comas, 2, `pillar: {nombre} pasa el modelo a Muerte.matar{args}`)
			matan += 1
		end
	end
	igual(matan >= 4, true, "pillar: se encuentran los Muerte.matar (Caza, Acechador, Bestia)")
	igual(CP.Alto > 1.5 and CP.Alto < 3.2, true, "esconderse: agachado cabe bajo una mesa y no atraviesa nada")
	igual(CP.VerCubierto < CP.OirAgachado and CP.OirAgachado < CP.Oido and CP.Olfato > CP.VerCubierto, true,
		"esconderse: cubierto se nota menos que agachado, y agachado menos que de pie")
	igual(CP.Huele > 0 and CP.Gatear > 0 and CP.VistaAgachado > 0 and CP.VistaAgachado < 1, true,
		"esconderse: tiempos y vista razonables")
	igual(CP.FueraBestia >= CP.Fuera and CP.Fuera > 1.5 and CP.CercaBorde > 1 and CP.SeEscapa > CP.CercaBorde, true,
		"esconderse: se para fuera del mueble y le alcanza al borde")
	igual(CP.FueraRaspador >= CP.Fuera and CP.FueraTrepador >= CP.Fuera and CP.FueraBestia < 6, true,
		"esconderse: los que sacan brazos o cabeza se paran algo más lejos, sin pasarse")
	igual(CP.Atasco > 0 and CP.MaxOlor > 0 and CP.MaxOlor < CP.Huele and CP.Ancho > 0.5 and CP.Ancho < 2, true,
		"esconderse: atasco, olor de una vez y anchura razonables")
	igual(CP.SinSalida > CP.Atasco and CP.SinSalida < 120, true, "esconderse: un borde sin salida se vuelve a probar al rato")
end

do -- Caza.borde: por dónde se mete el bicho debajo de un mueble (sacada del texto: Caza necesita Roblox)
	local roblox = require("@lune/roblox")
	local V3, CF = roblox.Vector3, roblox.CFrame
	local fuente = fs.readFile("src/juego/servidor/Caza.luau")
	local i = string.find(fuente, "function Caza.borde(", 1, true)
	local _, f = string.find(fuente, "\r?\nend\r?\n", i)
	local borde = luau.load("local Caza = {}\n" .. string.sub(fuente, i, f) .. "\nreturn Caza.borde",
		{ debugName = "Caza.borde", environment = { Vector3 = V3, CFrame = CF } })()
	local caja, tam, lejos = CF.new(0, 1.3, 0), V3.new(4, 2.6, 6), V3.new(0, 3, -40)
	igual(borde(caja, tam, V3.new(1.5, 1, 0.5), lejos, 2.5), V3.new(4.5, 0, 0.5), "debajo: el lado más cercano, a ras de suelo")
	igual(borde(caja, tam, V3.new(1.5, 1, 0.5), lejos, 2.5, function(b) return b.X < 2 end), V3.new(1, 0, -5.5),
		"debajo: pared en ese lado, el siguiente (nunca a través de ella)")
	igual(borde(caja, tam, V3.new(1.5, 1, 0.5), lejos, 2.5, function(b) return not (b.X > 2 and b.Z > -1) end),
		V3.new(4.5, 0, -1), "debajo: entre sillas, se corre a lo largo del lado")
	igual((borde(caja, tam, V3.zero, lejos, 2.5, function() return false end)), nil, "debajo: sin sitio, nada")
	-- Girada y en otro sitio: lo mismo, girado con ella.
	local girada = CF.new(-25.5, 1.3, -15) * CF.Angles(0, math.pi / 2, 0)
	local b2 = borde(girada, tam, girada:PointToWorldSpace(V3.new(1.5, -0.3, 0.5)), girada:PointToWorldSpace(lejos), 2.5)
	igual((b2 - girada:PointToWorldSpace(V3.new(4.5, -1.3, 0.5))).Magnitude < 1e-4, true, "debajo: mueble girado, borde girado")
	-- Lado más corto que las dos patas: en medio. Y la cara, en la boca del hueco frente a él.
	local estrecha = V3.new(1.5, 2.6, 6)
	local b3, c3 = borde(caja, estrecha, V3.new(0, 1, 2.9), lejos, 2.5, function(b) return b.Z > 3.5 end)
	igual(b3, V3.new(0, 0, 5.5), "debajo: lado corto, en medio")
	igual(c3, V3.new(0, 0, 3), "debajo: la cara, en la boca del hueco")
end

do -- MuebleRayo: rayos que ven los muebles (en el juego tienen CanQuery false y workspace:Raycast no los ve)
	local roblox = require("@lune/roblox")
	local V3, CF = roblox.Vector3, roblox.CFrame
	local zonas = {}
	local MR = luau.load(fs.readFile("src/juego/cliente/MuebleRayo.luau"), { debugName = "MuebleRayo", environment = {
		game = { GetService = function() return { GetTagged = function() return zonas end } end },
		workspace = { Raycast = function() return nil end },
		Vector3 = V3,
		CFrame = CF,
	} })()
	local caja = { cf = CF.new(0, 3, 0) * CF.Angles(0, math.pi / 4, 0), medio = V3.new(2, 0.5, 2), pieza = {}, bajo = V3.zero, alto = V3.zero }
	local t = MR.entra(caja, V3.new(0, 0, 0), V3.new(0, 5, 0))
	igual(t ~= nil and math.abs(t - 0.5) < 1e-6, true, "mueble: rayo hacia arriba entra por abajo")
	igual(MR.entra(caja, V3.new(0, 3, 0), V3.new(0, 5, 0)), nil, "mueble: si empieza dentro no lo ve (como Raycast)")
	igual(MR.entra(caja, V3.new(3, 0, 0), V3.new(0, 5, 0)), nil, "mueble: por fuera de la caja girada no da")
	igual(MR.entra(caja, V3.new(0, 0, 0), V3.new(0, 2, 0)), nil, "mueble: rayo corto que no llega")
	-- La mesa del comedor como en Mapa: zona Debajo, mueble con Tam y pivote, y la caja Choque de una pata en su casa.
	local esPieza = function(_, c) return c == "BasePart" end
	local pivote = CF.new(-25.5, 1, -15) * CF.Angles(0, math.pi / 2, 0)
	local pataCF = pivote * CF.new(-4.88, 1.42, -1.6)
	local pata = { Name = "Choque", CFrame = pataCF, Position = pataCF.Position, Size = V3.new(0.68, 2.84, 0.45), IsA = esPieza }
	local casa = { GetChildren = function() return { pata } end }
	local mueble = {
		Name = "MesaComedorPH",
		Parent = casa,
		IsA = function(_, c) return c == "Model" end,
		GetPivot = function() return pivote end,
		GetAttribute = function(_, k) return if k == "Tam" then V3.new(13, 3.51, 5.56) else nil end,
	}
	local zonaCF = pivote * CF.new(0, 1.42, 0.035)
	table.insert(zonas, { Name = "Debajo", Parent = mueble, CFrame = zonaCF, Position = zonaCF.Position, Size = V3.new(9.08, 2.84, 2.81), IsA = esPieza })
	local cajas = MR.cajas(V3.new(-25.5, 1, -15), 10)
	igual(#cajas, 2, "mueble: el tablero de la zona y la pata de su casa")
	-- Bajo el voladizo del lado largo (la zona llega a 1,4 del centro y el tablero a 2,78): ve el tablero a 2,84.
	local g = MR.rayo(V3.new(-25.5 - 2.6, 1.4, -15), V3.new(0, 4.5, 0), {} :: any, cajas)
	igual(g ~= nil and math.abs(g.Position.Y - 3.84) < 1e-3 and g.Instance == mueble, true,
		"mueble: el tablero entero, hasta el borde que se ve")
	igual(MR.rayo(V3.new(-25.5 - 3, 1.4, -15), V3.new(0, 4.5, 0), {} :: any, cajas), nil, "mueble: fuera del tablero, nada")
	igual(#MR.cajas(V3.new(30, 1, 30), 5), 0, "mueble: lejos, ninguna caja")
end

-- Correr y aguante (14.8): solo sí/no; lo pedido se guarda aunque ahora no se pueda; corriendo gasta, sin correr
-- vuelve tras Espera (más deprisa quieto o agachado); agotado no corre hasta Volver y frena.
do
	local CR = cargar("src/shared/CorrerReglas")
	local C = Config.Correr
	local function quien(cambios)
		local j = { vivo = true, escondido = false, cargando = false, mochila = false, agachado = false, asomado = false }
		for clave, valor in cambios or {} do
			j[clave] = valor
		end
		return j
	end
	local function cerca(a, b, etiqueta)
		assert(math.abs(a - b) < 1e-6, `{etiqueta}: esperado {b}, recibido {a}`)
		comprobaciones += 1
	end
	-- Corre `segundos` a pasos de 1/60 (devuelve el estado y cuántas veces se agotó).
	local function correr(e, segundos, velocidad, delante, j, ahora)
		local agota, t = 0, ahora or 100
		for _ = 1, math.floor(segundos * 60 + 0.5) do
			local ev
			t += 1 / 60
			e, ev = CR.paso(e, 1 / 60, t, velocidad, delante, j or quien())
			if ev == "Agota" then
				agota += 1
			end
		end
		return e, agota, t
	end
	-- Lo que llega del cliente puede ser cualquier cosa.
	for _, raro in { 1, 0, "true", {}, 0 / 0 } do
		igual((CR.pedir(CR.nuevo(), raro, 10)), false, `correr: {tostring(raro)} no es una petición`)
	end
	igual((CR.pedir(CR.nuevo(), nil, 10)), false, "correr: nada no es una petición")
	igual((CR.pedir(CR.nuevo(), false, 10)), false, "correr: pedir lo que ya está no cambia")
	local cambia, e = CR.pedir(CR.nuevo(), true, 10)
	igual(cambia and e.quiere, true, "correr: pedirlo")
	igual(CR.nuevo().quiere, false, "correr: el estado de antes no se toca")
	-- Muy seguido no se pierde: espera y cuenta al pasar Cada.
	local _, rapido = CR.pedir(e, false, 10 + C.Cada / 2)
	igual(rapido.quiere, true, "correr: muy seguido aún no cuenta")
	igual(rapido.pendiente, false, "correr: pero se guarda")
	local tarde = CR.paso(rapido, 1 / 60, 10 + C.Cada + 0.01, 16, 1, quien())
	igual(tarde.quiere == false and tarde.pendiente == nil, true, "correr: lo guardado cuenta al pasar Cada")
	local _, vuelta = CR.pedir(rapido, true, 10 + C.Cada / 2)
	igual(vuelta.quiere == true and vuelta.pendiente == nil, true, "correr: volver a lo de antes quita lo guardado")
	-- Corre solo si se mueve hacia delante y puede.
	igual(CR.seMueve(16, 1), true, "correr: andando recto, sí")
	igual(CR.seMueve(C.Moverse / 2, 1), false, "correr: quieto, no")
	igual(CR.seMueve(16, 0), false, "correr: de lado, no")
	igual(CR.seMueve(16, -1), false, "correr: hacia atrás, no")
	local corre = CR.paso(e, 1 / 60, 20, 16, 1, quien())
	igual(corre.corriendo, true, "correr: lo pide, puede y se mueve")
	igual(corre.aguante < 1, true, "correr: gasta aguante")
	igual(CR.paso(e, 1 / 60, 20, 0, 1, quien()).corriendo, false, "correr: quieto no corre")
	for _, cambio in { { vivo = false }, { escondido = true }, { cargando = true }, { mochila = true },
		{ agachado = true }, { asomado = true }, { vistazo = true }, { cine = true } } do
		local clave = next(cambio)
		local parado = CR.paso(e, 1 / 60, 20, 16, 1, quien(cambio))
		igual(parado.corriendo, false, `correr: con {clave}, no`)
		igual(parado.quiere, true, `correr: con {clave} se guarda lo pedido`)
	end
	igual(CR.paso(e, 0 / 0, 20, 16, 1, quien()).corriendo, false, "correr: dt NaN no corre")
	igual(CR.paso(e, -1, 20, 16, 1, quien()).aguante, 1, "correr: dt negativo no gasta")
	igual(CR.paso(e, 1 / 60, 20, 0 / 0, 0 / 0, quien()).corriendo, false, "correr: velocidad NaN, quieto")
	-- Lleno dura Dura s y se agota una vez.
	local casi, agota = correr(e, C.Dura - 0.1, 16, 1)
	igual(agota, 0, "correr: antes de Dura no se agota")
	igual(casi.corriendo and casi.aguante > 0, true, "correr: sigue corriendo")
	local _, agota2 = correr(casi, 0.2, 16, 1)
	igual(agota2, 1, "correr: a los Dura s se agota (una vez)")
	-- Justo al agotarse (el paso que avisa).
	local agotado, t = casi, 100
	for _ = 1, 60 do
		local ev
		t += 1 / 60
		agotado, ev = CR.paso(agotado, 1 / 60, t, 16, 1, quien())
		if ev then
			break
		end
	end
	igual(agotado.agotado and not agotado.corriendo and agotado.aguante == 0, true, "correr: agotado, a cero y sin correr")
	cerca(agotado.frena, C.Frena, "correr: frena al agotarse")
	-- Agotado: no corre aunque lo pida hasta tener Volver; la espera primero.
	local espera = correr(agotado, C.Espera - 0.05, 16, 1, nil, t)
	cerca(espera.aguante, 0, "correr: durante la espera no vuelve")
	igual(correr(agotado, C.Frena + 0.05, 16, 1, nil, t).frena, 0, "correr: el frenazo pasa")
	local andando = correr(agotado, C.Espera + 1, 16, 1, nil, t)
	igual(andando.aguante > 0 and andando.agotado and not andando.corriendo, true, "correr: agotado vuelve sin correr")
	cerca(andando.aguante, C.Andando, "correr: andando vuelve a su ritmo")
	local quieto = correr(agotado, C.Espera + 1, 0, 1, nil, t)
	cerca(quieto.aguante, C.Quieto, "correr: quieto vuelve más deprisa")
	local agachado = correr(agotado, C.Espera + 1, 8, 1, quien({ agachado = true }), t)
	cerca(agachado.aguante, C.Quieto, "correr: agachado también")
	igual(C.Quieto > C.Andando, true, "correr: quieto más deprisa que andando")
	local listo = correr(agotado, C.Espera + C.Volver / C.Quieto + 0.05, 0, 1, nil, t)
	igual(listo.agotado, false, "correr: con Volver deja de estar agotado")
	igual(CR.paso(listo, 1 / 60, t + 10, 16, 1, quien()).corriendo, true, "correr: y vuelve a correr")
	local _, sinPedir = CR.pedir(agotado, false, t + 1)
	local lleno = correr(sinPedir, 60, 16, 1, nil, t + 1)
	igual(lleno.aguante, 1, "correr: no pasa de lleno")
	-- Dejar de correr a medias: no se agota y vuelve desde ahí.
	local medio = correr(e, C.Dura / 2, 16, 1)
	local _, suelta = CR.pedir(medio, false, 200)
	local descansa = correr(suelta, C.Espera + 1, 16, 1)
	igual(descansa.agotado, false, "correr: soltar a medias no agota")
	cerca(descansa.aguante, medio.aguante + C.Andando, "correr: y vuelve desde lo que quedaba")
	-- Velocidad y cansancio.
	igual(CR.velocidad(16, true), 16 * C.Factor, "correr: velocidad corriendo")
	igual(CR.velocidad(16, false), 16, "correr: andando, la de andar")
	igual(CR.velocidad(16 * 1.2, true), 16 * 1.2 * C.Factor, "correr: la clase Corredor también corre más")
	igual(CR.cansancio(agotado), 1, "correr: agotado, cansado del todo")
	igual(CR.cansancio(CR.nuevo()), 0, "correr: descansado")
	local re = CR.reaparecer(agotado)
	igual(re.aguante == 1 and not re.agotado and not re.quiere and re.ultimo == agotado.ultimo, true, "correr: al reaparecer")
	-- Los bichos te oyen desde más lejos corriendo que de pie (y agachado o debajo de algo no se corre).
	igual(C.Oido > Config.Postura.Oido, true, "correr: hace ruido")
	local PR = cargar("src/shared/PosturaReglas")
	local oido = Config.Postura.Oido
	igual(PR.alcanceOido(oido, false, false, true), C.Oido, "correr: te oyen a Config.Correr.Oido")
	igual(PR.alcanceOido(oido, false, false), oido, "correr: andando, como siempre")
	igual(PR.alcanceOido(oido, false, true, true), math.min(oido, Config.Postura.VerCubierto), "correr: cubierto manda")
end

-- Bancos (tests/bancos, 14.8): módulos del cliente con un Roblox de mentira (tests/bancos/_roblox.luau) y cuentas,
-- cada uno en su propio proceso de Lune (no se pisan lo que tocan). Los que empiezan por "_" son ayudas, no bancos.
do
	local process = require("@lune/process")
	if fs.isDir("tests/bancos") then
		local nombres = fs.readDir("tests/bancos")
		table.sort(nombres)
		for _, nombre in nombres do
			if string.match(nombre, "%.luau$") and not string.match(nombre, "^_") then
				local r = process.exec("lune", { "run", "tests/bancos/" .. nombre })
				assert(r.ok, `banco {nombre}:\n{r.stdout}{r.stderr}`)
				comprobaciones += 1
			end
		end
	end
end

print(`Todo bien: {comprobaciones} comprobaciones.`)
