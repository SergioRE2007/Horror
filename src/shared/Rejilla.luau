-- Rejilla de la mochila (estilo Resident Evil 4, pedido por el usuario), sin nada de Roblox para probarla con Lune.
-- Casillas de (1, 1) arriba a la izquierda a (ancho, alto). Cada cosa ocupa un rectángulo desde su casilla (x, y):
-- su tamaño sale del catálogo (Config.Objetos, Tam = {ancho, alto}) y `girada` cambia un lado por el otro.
-- `carga` es lo que le queda a una linterna (pila 0..1) o a una cámara (fotos); la rejilla solo la guarda.
-- La usan el servidor (Mochila, que manda) y el cliente (MochilaUi, que la pinta y adelanta lo que pide).
local Rejilla = {}

export type Cosa = { id: number, tipo: string, x: number, y: number, girada: boolean, carga: number? }
export type Rejilla = { ancho: number, alto: number, cosas: { Cosa }, siguiente: number }
export type Catalogo = { [string]: { Tam: { number } } }

function Rejilla.nueva(ancho: number, alto: number): Rejilla
	return { ancho = ancho, alto = alto, cosas = {}, siguiente = 1 }
end

-- Ancho y alto que ocupa un tipo, girado o no.
function Rejilla.tamano(catalogo: Catalogo, tipo: string, girada: boolean): (number, number)
	local tam = catalogo[tipo].Tam
	if girada then
		return tam[2], tam[1]
	end
	return tam[1], tam[2]
end

local function entero(n: unknown): boolean
	return type(n) == "number" and n == n and n == math.floor(n)
end

-- ¿Cabe ese tipo en (x, y) sin salirse ni pisar otra cosa? `sin` = id de una cosa que no cuenta (la que se mueve).
function Rejilla.cabe(r: Rejilla, catalogo: Catalogo, tipo: string, x: number, y: number, girada: boolean, sin: number?): boolean
	if not catalogo[tipo] or not entero(x) or not entero(y) then
		return false
	end
	local w, h = Rejilla.tamano(catalogo, tipo, girada)
	if x < 1 or y < 1 or x + w - 1 > r.ancho or y + h - 1 > r.alto then
		return false
	end
	for _, c in r.cosas do
		if c.id ~= sin then
			local cw, ch = Rejilla.tamano(catalogo, c.tipo, c.girada)
			if x < c.x + cw and c.x < x + w and y < c.y + ch and c.y < y + h then
				return false
			end
		end
	end
	return true
end

-- Mete el tipo en (x, y). Devuelve la cosa nueva, o nil si no cabe ahí.
function Rejilla.poner(r: Rejilla, catalogo: Catalogo, tipo: string, x: number, y: number, girada: boolean, carga: number?): Cosa?
	if not Rejilla.cabe(r, catalogo, tipo, x, y, girada) then
		return nil
	end
	local cosa = { id = r.siguiente, tipo = tipo, x = x, y = y, girada = girada, carga = carga }
	r.siguiente += 1
	table.insert(r.cosas, cosa)
	return cosa
end

-- El primer hueco libre para ese tipo, fila a fila desde arriba; primero sin girar y luego girada.
function Rejilla.hueco(r: Rejilla, catalogo: Catalogo, tipo: string): (number?, number?, boolean?)
	if not catalogo[tipo] then
		return nil, nil, nil
	end
	for _, girada in { false, true } do
		for y = 1, r.alto do
			for x = 1, r.ancho do
				if Rejilla.cabe(r, catalogo, tipo, x, y, girada) then
					return x, y, girada
				end
			end
		end
	end
	return nil, nil, nil
end

-- Mete el tipo en el primer hueco. nil si no cabe en ningún sitio.
function Rejilla.meter(r: Rejilla, catalogo: Catalogo, tipo: string, carga: number?): Cosa?
	local x, y, girada = Rejilla.hueco(r, catalogo, tipo)
	if not x then
		return nil
	end
	return Rejilla.poner(r, catalogo, tipo, x :: number, y :: number, girada :: boolean, carga)
end

function Rejilla.buscar(r: Rejilla, id: unknown): Cosa?
	for _, c in r.cosas do
		if c.id == id then
			return c
		end
	end
	return nil
end

-- La cosa que ocupa la casilla (x, y), si hay alguna.
function Rejilla.en(r: Rejilla, catalogo: Catalogo, x: number, y: number): Cosa?
	for _, c in r.cosas do
		local w, h = Rejilla.tamano(catalogo, c.tipo, c.girada)
		if x >= c.x and x < c.x + w and y >= c.y and y < c.y + h then
			return c
		end
	end
	return nil
end

-- Mueve (y gira) una cosa. false si no existe o no cabe ahí; entonces no cambia nada.
function Rejilla.mover(r: Rejilla, catalogo: Catalogo, id: unknown, x: unknown, y: unknown, girada: unknown): boolean
	local c = Rejilla.buscar(r, id)
	if not c or type(girada) ~= "boolean" or not entero(x) or not entero(y) then
		return false
	end
	if not Rejilla.cabe(r, catalogo, c.tipo, x :: number, y :: number, girada, c.id) then
		return false
	end
	c.x, c.y, c.girada = x :: number, y :: number, girada
	return true
end

-- Saca una cosa de la rejilla y la devuelve (nil si no estaba).
function Rejilla.sacar(r: Rejilla, id: unknown): Cosa?
	for i, c in r.cosas do
		if c.id == id then
			table.remove(r.cosas, i)
			return c
		end
	end
	return nil
end

-- La primera de ese tipo que se metió (la que se usa: la linterna o la cámara "de la mano").
function Rejilla.primera(r: Rejilla, tipo: string): Cosa?
	local mejor: Cosa? = nil
	for _, c in r.cosas do
		if c.tipo == tipo and (not mejor or c.id < mejor.id) then
			mejor = c
		end
	end
	return mejor
end

function Rejilla.contar(r: Rejilla, tipo: string): number
	local n = 0
	for _, c in r.cosas do
		if c.tipo == tipo then
			n += 1
		end
	end
	return n
end

-- Saca una de ese tipo (la última que se metió). false si no había.
function Rejilla.gastar(r: Rejilla, tipo: string): boolean
	local ultima: Cosa? = nil
	for _, c in r.cosas do
		if c.tipo == tipo and (not ultima or c.id > ultima.id) then
			ultima = c
		end
	end
	return ultima ~= nil and Rejilla.sacar(r, ultima.id) ~= nil
end

-- Rehace una rejilla de unos datos que no son de fiar (lo guardado o lo que llega por la red): tira lo de tipo
-- desconocido, lo que se sale o pisa a otra lo vuelve a meter en un hueco y lo que ya no cabe lo devuelve aparte
-- (para soltarlo en el mundo). La rejilla puede ser más grande que la de los datos (mochila ampliada).
function Rejilla.desde(datos: unknown, catalogo: Catalogo, ancho: number, alto: number): (Rejilla, { Cosa })
	local r = Rejilla.nueva(ancho, alto)
	local sobran: { Cosa } = {}
	local cosas = if type(datos) == "table" and type((datos :: any).cosas) == "table" then (datos :: any).cosas else {}
	local pendientes = {}
	for _, c in cosas do
		if type(c) ~= "table" or type(c.tipo) ~= "string" or not catalogo[c.tipo] then
			continue
		end
		local carga = if type(c.carga) == "number" and c.carga == c.carga and math.abs(c.carga) ~= math.huge then c.carga else nil
		local id = if entero(c.id) and c.id > 0 and not Rejilla.buscar(r, c.id) then c.id else nil
		local girada = c.girada == true
		if id and Rejilla.cabe(r, catalogo, c.tipo, c.x, c.y, girada) then
			table.insert(r.cosas, { id = id, tipo = c.tipo, x = c.x, y = c.y, girada = girada, carga = carga })
			r.siguiente = math.max(r.siguiente, id + 1)
		else
			table.insert(pendientes, { tipo = c.tipo, carga = carga })
		end
	end
	for _, p in pendientes do
		local cosa = Rejilla.meter(r, catalogo, p.tipo, p.carga)
		if not cosa then
			table.insert(sobran, { id = 0, tipo = p.tipo, x = 0, y = 0, girada = false, carga = p.carga })
		end
	end
	return r, sobran
end

return Rejilla
