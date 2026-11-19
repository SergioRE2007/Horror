-- Banco de las cerillas del final: están en la caja fuerte del rico (pista 12, docs/historia.md: "En la caja, las
-- cerillas"), no sueltas por la casa. Lee el código (no hace falta el Roblox de mentira):
--   ningún Mapa*.luau deja Cerillas entre los objetos sueltos;
--   Config.Bestia.PistaCerillas es la 12 y Pistas, al leerla por primera vez (antes de apuntarla), da Cerillas y avisa;
--   las frases nuevas están en LangEs y la vieja ("It must...") ya no está en ningún sitio.
-- Y Llaves de verdad (con Casa, Mapa, Mochila y Pistas de mentira): al morir caen las llaves y todo lo único (pistola,
-- bengalas, cerillas), y Llaves.repasar devuelve las bengalas gastadas al desván solo cuando toca, sin duplicar.
-- Ejecutar desde la raíz: lune run tests/bancos/cerillas.luau (lo corre regressions.luau).
local fs = require("@lune/fs")
local crearMundo = require("./_roblox")

local cuentas = 0
local function bien(cond: any, que: string)
	assert(cond, "cerillas: " .. que)
	cuentas += 1
end
local function igual(actual, esperado, que: string)
	bien(actual == esperado, `{que}: esperado {tostring(esperado)}, recibido {tostring(actual)}`)
end

-- Todo lo que construye el mapa (Mapa, MapaAnexos, MapaBosque...): las cerillas vivían en construirFinal (MapaAnexos).
local SERVIDOR = "src/juego/servidor/"
local mapa = ""
for _, archivo in fs.readDir(SERVIDOR) do
	if string.match(archivo, "^Mapa.*%.luau$") then
		mapa ..= fs.readFile(SERVIDOR .. archivo)
	end
end
local pistas = fs.readFile("src/juego/servidor/Pistas.luau")
local incendio = fs.readFile("src/juego/servidor/Incendio.luau")
local config = fs.readFile("src/shared/Config.luau")
local langEs = fs.readFile("src/shared/LangEs.luau")

bien(not string.find(mapa, '{ "Cerillas"', 1, true), "Mapa ya no pone cerillas sueltas (estaban en la encimera)")
bien(string.find(config, "PistaCerillas = 12,", 1, true), "Config.Bestia.PistaCerillas es la caja fuerte (12)")

-- En Pistas.leer: se mira si es la primera vez antes de apuntarla, y luego se dan y se avisa.
local leer = string.match(pistas, "function Pistas%.leer.-\nend\n")
bien(leer, "Pistas.leer existe")
local antes = string.find(leer, "n == Config.Bestia.PistaCerillas and not leidas[n]", 1, true)
local apunta = string.find(leer, "leidas[n] = true", 1, true)
local da = string.find(leer, 'Mochila.dar(jugador, "Cerillas")', 1, true)
bien(antes and apunta and antes < apunta, "la primera lectura se mira antes de apuntarla (no se dan dos veces)")
bien(da and da > apunta, "da las cerillas al leer la caja fuerte")
bien(string.find(leer, 'Lang.t(jugador, "There are matches inside the safe.")', 1, true), "avisa de las cerillas")
bien(string.find(pistas, "require(script.Parent.Mochila)", 1, true), "Pistas carga Mochila")

-- Sin require circular: ni Mochila ni nada de lo que carga (siguiendo los require hasta el fondo) carga Pistas.
local vistos, pendientes = {}, { "Mochila" }
while #pendientes > 0 do
	local nombre = table.remove(pendientes) :: string
	if not vistos[nombre] then
		vistos[nombre] = true
		local fuente = fs.readFile(`{SERVIDOR}{nombre}.luau`)
		bien(not string.find(fuente, "require(script.Parent.Pistas)", 1, true), `{nombre} no carga Pistas`)
		for otro in string.gmatch(fuente, "require%(script%.Parent%.([%w_]+)%)") do
			table.insert(pendientes, otro)
		end
	end
end
bien(vistos.MapaAnexos and vistos.Mapa and vistos.Cargar, "se han seguido los require de Mochila (Mapa, MapaAnexos...)")

-- Textos: frases enteras con su español.
bien(string.find(incendio, '"She must be locked in the basement first."', 1, true), "Incendio la llama ella")
bien(not string.find(incendio .. langEs, "It must be locked", 1, true), "la frase vieja ya no está")
bien(
	string.find(langEs, '["She must be locked in the basement first."] = "Antes tiene que estar encerrada en el sótano."', 1, true),
	"su español en LangEs"
)
bien(
	string.find(langEs, '["There are matches inside the safe."] = "Dentro de la caja fuerte hay unas cerillas."', 1, true),
	"el aviso tiene su español"
)

-- Llaves de verdad con una Mochila de mentira: lo que lleva cada jugador, lo suelto y lo que se deja.
do
	local m = crearMundo({ servidor = true })
	local g = m.global
	local Config = m.cargar("src/shared/Config")
	local llevan: { [any]: { string } } = {}
	local sueltos: { { tipo: string, cf: any } } = {}
	local function quitar(lista: { string }, tipo: string): boolean
		local i = table.find(lista, tipo)
		if i then
			table.remove(lista, i)
		end
		return i ~= nil
	end
	local Mochila = {
		sacar = function(j, tipo)
			return if quitar(llevan[j] or {}, tipo) then tipo else nil
		end,
		dejar = function(tipo, _, cf)
			table.insert(sueltos, { tipo = tipo, cf = cf })
		end,
		contar = function(j, tipo)
			local n = 0
			for _, t in llevan[j] or {} do
				n += if t == tipo then 1 else 0
			end
			return n
		end,
		sueltos = function()
			return table.clone(sueltos)
		end,
		fueraDeEscondite = function(p)
			return p
		end,
		sitioLibre = function(_, p)
			return p
		end,
	}
	-- Los tres sitios de las bengalas, delante del baúl del desván (como MapaAnexos).
	local objetos = {}
	for x = 1, 3 do
		table.insert(objetos, { tipo = "Bengala", cf = g.CFrame.new(x, 27.6, -11.5) })
	end
	local Llaves = m.cargar("src/juego/servidor/Llaves", {
		Mochila = Mochila,
		Mapa = { llaves = {}, objetos = objetos },
		Casa = { cerradas = function()
			return {}
		end, conLlave = function() end },
		Pistas = { leida = function()
			return false
		end, sitio = function() end },
	})
	Llaves.start()
	local function cuantas(tipo: string): number
		local n = 0
		for _, o in sueltos do
			n += if o.tipo == tipo then 1 else 0
		end
		return n
	end
	local a = m.jugador("A")
	a:LoadCharacter()
	m.correr(0.2)
	llevan[a] = { "Pistola", "Bengala", "Bengala", "Pila", "Cerillas", "LlaveSotano" }
	a:SetAttribute("Muerto", true)
	m.correr(0.1)
	igual(#sueltos, 5, "al morir caen pistola, 2 bengalas, cerillas y la llave")
	igual(cuantas("Pistola") + cuantas("Bengala"), 3, "muerto con pistola y 2 bengalas: 3 en el suelo")
	igual(#llevan[a], 1, "la pila se queda en la mochila")
	igual(llevan[a][1], "Pila", "lo que no es llave ni único no cae")

	-- Las bengalas gastadas: un día normal con 2 no vuelven; con la Bestia fuera ese día, las que faltan.
	local B = Config.Bestia.Bengalas
	table.clear(sueltos)
	llevan[a] = { "Bengala" }
	table.insert(sueltos, { tipo = "Bengala", cf = g.CFrame.new(50, 0, 0) })
	Llaves.repasar(1, {})
	igual(cuantas("Bengala"), 1, "día normal con 2: no vuelve ninguna")
	Llaves.repasar(1, {}, nil, true)
	igual(cuantas("Bengala") + Mochila.contar(a, "Bengala"), B, "noche final fallida: vuelven las que faltan, sin duplicar")
	table.clear(sueltos)
	llevan[a] = {}
	Llaves.repasar(1, {})
	igual(cuantas("Bengala"), B, "sin ninguna en la partida: vuelven todas, aunque sea un día normal")
	igual(sueltos[1].cf.Position.X ~= sueltos[2].cf.Position.X, true, "cada una en su sitio del desván")
	-- Al cargar, las de un esperado (aún no ha entrado) cuentan: no salen otras.
	table.clear(sueltos)
	Llaves.repasar(1, { ["77"] = { cosas = { { tipo = "Bengala" } } } }, { 77 })
	igual(cuantas("Bengala"), 0, "al cargar, la bengala de un esperado cuenta")
	-- Las del que no vuelve: se le quitan y vuelven a su sitio, y no salen otras encima.
	local guardadas = { ["88"] = { cosas = { { tipo = "Bengala" }, { tipo = "Bengala" }, { tipo = "Bengala" } } } }
	Llaves.repasar(1, guardadas, nil, true)
	igual(cuantas("Bengala"), B, "las del que no vuelve, a su sitio, sin duplicar")
	igual(#guardadas["88"].cosas, 0, "y se le quitan de la mochila guardada")
end

print(`cerillas: {cuentas} comprobaciones`)
