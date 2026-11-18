-- Registro común de los bichos (16.15): cada monstruo se apunta en su start() con su nombre y su módulo (con irse()
-- y quitar()). Así los que tienen que echarlos a todos (Director al amanecer o al volver a empezar el día, Coche al
-- huir, Bestia en la noche final, Incendio en su escena) no copian la lista y un bicho nuevo no se queda cazando por
-- olvidar un sitio. Sin require de nadie: no puede cerrar ningún círculo.
--   irseTodos(excepto?) amanece: se van andando. quitarTodos(excepto?) fuera del mapa al momento. quitarSolo(nombres)
--   para quien hoy quita solo a algunos. Se recorren en el orden en que se apuntaron (el del init del servidor).
local Bichos = {}

export type Bicho = { irse: () -> (), quitar: () -> () }

local lista: { { nombre: string, modulo: Bicho } } = {}

-- Lo apunta (una vez: si ya estaba con ese nombre, cambia el módulo y se queda en su sitio).
function Bichos.registrar(nombre: string, modulo: Bicho)
	for _, b in lista do
		if b.nombre == nombre then
			b.modulo = modulo
			return
		end
	end
	table.insert(lista, { nombre = nombre, modulo = modulo })
end

-- Con pcall: que un fallo en uno no deje a los demás cazando.
local function llamar(b: { nombre: string, modulo: Bicho }, que: "irse" | "quitar")
	local ok, fallo = pcall(b.modulo[que])
	if not ok then
		warn(`[Bichos] {b.nombre}.{que}: {fallo}`)
	end
end

function Bichos.irseTodos(excepto: string?)
	for _, b in lista do
		if b.nombre ~= excepto then
			llamar(b, "irse")
		end
	end
end

function Bichos.quitarTodos(excepto: string?)
	for _, b in lista do
		if b.nombre ~= excepto then
			llamar(b, "quitar")
		end
	end
end

function Bichos.quitarSolo(nombres: { string })
	for _, b in lista do
		if table.find(nombres, b.nombre) then
			llamar(b, "quitar")
		end
	end
end

-- Los nombres apuntados, en orden (para pruebas).
function Bichos.nombres(): { string }
	local nombres = {}
	for _, b in lista do
		table.insert(nombres, b.nombre)
	end
	return nombres
end

return Bichos
