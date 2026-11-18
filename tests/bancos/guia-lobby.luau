-- Guía del lobby para el jugador nuevo (16.7): a quién se le enseña qué, solo con lo que ya se guarda. Ejecutar desde la
-- raíz: lune run tests/bancos/guia-lobby.luau (también lo lanza tests/regressions.luau). Sin Roblox: carga GuiaReglas,
-- Comprar, Formato y Config, y mira la etapa de jugadores de mentira. Si algo no se cumple, termina con error.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

-- Un "script" falso: script.Parent.Config = el archivo de al lado, como en Roblox (lo mismo que tests/regressions).
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
			require = function(n)
				return cargar(n.ruta)
			end,
		}
		cargados[ruta] = luau.load(fuente, { debugName = ruta, environment = entorno })()
	end
	return cargados[ruta]
end

local Config = cargar("src/shared/Config")
local Lang = cargar("src/shared/Lang")
local Formato = cargar("src/comun/servidor/Formato")
local Comprar = cargar("src/comun/servidor/Comprar")
local GuiaReglas = cargar("src/lobby/servidor/GuiaReglas")

local comprobaciones = 0
local function igual(actual, esperado, etiqueta: string)
	assert(actual == esperado, `{etiqueta}: esperado {tostring(esperado)}, recibido {tostring(actual)}`)
	comprobaciones += 1
end
local function etapa(datos)
	return GuiaReglas.etapa(datos, Comprar.precioClase)
end

-- Cuenta nueva: la guía del coche.
local nuevo = Formato.jugadorNuevo()
igual(etapa(nuevo), "Coche", "cuenta nueva")
-- Las monedas no cuentan (el premio diario las da a todos al entrar).
nuevo.monedas = 50
igual(etapa(nuevo), "Coche", "monedas del premio diario")
-- Mala entrada: nada, sin romper.
igual(etapa(nil), nil, "sin datos")
igual(etapa("hola"), nil, "datos que no son tabla")

-- Sin jugar pero con la primera clase comprada (la gratis, desde el lobby): aún no ha jugado.
local comprada = Formato.jugadorNuevo()
comprada.clases.Lenador = true
igual(etapa(comprada), "Coche", "sin jugar con clase comprada")

-- Ha jugado (una ranura guardada o un logro) y no ha comprado nada: la guía de la tienda, y su frase es cierta.
local conRanura = Formato.jugadorNuevo()
conRanura.partidas["1"] = { noche = 2, hora = 0 }
igual(etapa(conRanura), "Tienda", "con una ranura guardada")
igual(Comprar.precioClase(conRanura, Config.Clases[1]), 0, "la primera clase es gratis (lo que dice la guía)")
local conLogro = Formato.jugadorNuevo()
conLogro.logros.Noche1 = true
igual(etapa(conLogro), "Tienda", "con un logro")

-- Una sola vez por cuenta: tras apuntarla ya no sale, y el guardado la conserva al cargar.
conLogro.logros[GuiaReglas.VISTA] = true
igual(etapa(conLogro), nil, "tienda ya enseñada")
local recargado = Formato.arreglarJugador(conLogro)
igual(recargado.logros[GuiaReglas.VISTA], true, "Formato conserva la marca de la guía")
igual(etapa(recargado), nil, "tienda ya enseñada tras cargar")

-- Si ya compró una clase, la primera gratis ya no existe: nada.
local compro = Formato.jugadorNuevo()
compro.partidas["1"] = { noche = 3, hora = 0 }
compro.clases.Corredor = true
igual(etapa(compro), nil, "ya compró una clase")

-- Lo que usa el cliente de Config y de LangEs.
igual(type(Config.Lobby.Guia.Altura.Coche), "number", "Config.Lobby.Guia.Altura.Coche")
igual(type(Config.Lobby.Guia.Altura.Tienda), "number", "Config.Lobby.Guia.Altura.Tienda")
igual(Config.Lobby.Guia.TiendaSegundos > 0, true, "Config.Lobby.Guia.TiendaSegundos")
igual(Lang.es["Get in the car"] ~= nil, true, "frase del coche en español")
igual(Lang.es["Your first class is free"] ~= nil, true, "frase de la tienda en español")

print(`guía del lobby: todo se cumple ({comprobaciones} comprobaciones)`)
