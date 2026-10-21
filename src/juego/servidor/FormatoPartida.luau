-- Formato de lo que se guarda de cada partida (clave partida_<dueño>_<ranura>): cómo estaba todo al último amanecer.
-- Campos con nombre y `version`: lo nuevo se añade sin romper lo viejo. Si un campo cambia de forma, se sube VERSION
-- y se añade abajo el paso que convierte lo viejo. Sin nada de Roblox dentro, para probarlo con Lune.
--   noche: el día en el que se vuelve a empezar (el de esa noche).
--   semilla: el azar de la partida (dónde salen las llaves y las pistas, más adelante).
--   casa: [clave de la ventana o puerta] = { vida, persiana, cristal, abierta, bloqueada }.
--   arboles: [clave del árbol] = noche en que se taló (los que no están, de pie).
--   generador: { gasolina (0..1), encendido, movil (batería del móvil del enchufe, o nada) }.
--   objetos y pesados: listas de { tipo, carga, sitio = { x, y, z, rx, ry, rz } } (lo suelto por el mapa).
--   mochilas: [UserId en texto] = { cosas = las de shared/Rejilla } (de todos los que han jugado en ella).
local FormatoPartida = {}

FormatoPartida.VERSION = 1

local function finito(n: unknown): boolean
	return type(n) == "number" and n == n and math.abs(n) ~= math.huge
end

local function numero(n: unknown, minimo: number, maximo: number, otro: number): number
	return if finito(n) then math.clamp(n :: number, minimo, maximo) else otro
end

-- Seis números finitos y razonables (posición y giro), o nil. Lo que se ha caído por debajo del mapa no vale.
local function sitio(t: unknown): { number }?
	if type(t) ~= "table" or #t ~= 6 then
		return nil
	end
	for i = 1, 6 do
		if not finito(t[i]) or math.abs(t[i]) > 1e5 then
			return nil
		end
	end
	return if t[2] > -50 then { t[1], t[2], t[3], t[4], t[5], t[6] } else nil
end

-- Lista de cosas sueltas: solo tipos del catálogo, con su sitio y, como mucho, `maximo`.
local function sueltos(lista: unknown, catalogo, maximo: number)
	local salida = {}
	if type(lista) ~= "table" then
		return salida
	end
	for _, c in lista do
		if #salida >= maximo then
			break
		end
		local donde = type(c) == "table" and sitio(c.sitio)
		if donde and type(c.tipo) == "string" and catalogo[c.tipo] then
			table.insert(salida, { tipo = c.tipo, carga = if finito(c.carga) then c.carga else nil, sitio = donde })
		end
	end
	return salida
end

-- Pone al día lo guardado de una partida. nil (o algo que no es una tabla) = partida nueva: devuelve nil y el mundo
-- se queda como lo genera el mapa. `cat` = { objetos = Config.Objetos, pesados = Config.Pesados, maximo = Sueltos }.
function FormatoPartida.arreglar(guardado: unknown, cat)
	if type(guardado) ~= "table" then
		return nil
	end
	local g = guardado :: any
	-- Aquí irán los pasos de una versión a la siguiente: if (g.version or 0) < 2 then ... end
	local d = {
		version = FormatoPartida.VERSION,
		noche = math.max(1, math.floor(numero(g.noche, 1, 1e6, 1))),
		semilla = math.floor(numero(g.semilla, 0, 2 ^ 31 - 1, 0)),
		casa = {},
		arboles = {},
		generador = {},
		objetos = sueltos(g.objetos, cat.objetos, cat.maximo),
		pesados = sueltos(g.pesados, cat.pesados, cat.maximo),
		mochilas = {},
	}
	if type(g.casa) == "table" then
		for clave, e in g.casa do
			if type(clave) == "string" and type(e) == "table" and finito(e.vida) then
				d.casa[clave] = {
					vida = math.max(0, e.vida),
					persiana = e.persiana == true,
					cristal = math.floor(numero(e.cristal, 0, 100, 0)),
					abierta = e.abierta == true,
					bloqueada = if type(e.bloqueada) == "boolean" then e.bloqueada else nil,
				}
			end
		end
	end
	if type(g.arboles) == "table" then
		for clave, talado in g.arboles do
			if type(clave) == "string" and finito(talado) and talado >= 1 then
				d.arboles[clave] = math.floor(talado)
			end
		end
	end
	if type(g.generador) == "table" then
		local gen = g.generador
		d.generador = {
			gasolina = if finito(gen.gasolina) then math.clamp(gen.gasolina, 0, 1) else nil,
			encendido = gen.encendido == true,
			movil = if finito(gen.movil) then math.clamp(gen.movil, 0, 1) else nil,
		}
	end
	if type(g.mochilas) == "table" then
		for id, m in g.mochilas do
			-- Lo de dentro lo arregla Rejilla.desde al ponerla (tipos que ya no existen, cosas que se pisan…).
			if type(id) == "string" and tonumber(id) and type(m) == "table" and type(m.cosas) == "table" then
				d.mochilas[id] = { cosas = m.cosas }
			end
		end
	end
	return d
end

return FormatoPartida
