-- Banco del reparto de bichos del Director (16.15): shared/RepartoBichos de verdad (pura) con Config y un azar con
-- semilla (shared/Azar). Comprueba:
--   la noche final (Bestia) no toca nadie; antes de su noche un especial no sale (y no se gasta tirada);
--   el ataque seguro de la primera noche de cada uno es suyo sin tirar; uno como mucho a la vez de cada uno;
--   el Imitador solo con la puerta principal libre; el orden (Imitador, Trepador, Raspador; si no, Golpeador);
--   con muchas tiradas, cada uno sale cerca de lo que dice su Probabilidad;
--   el intervalo: dentro del rango la primera noche, cada noche antes, nunca menos del mínimo y por el ritmo;
--   misma semilla, mismo reparto;
--   la voz del Imitador: el muerto de esta noche casi siempre, si no uno lejos de la puerta; solo, tu voz o (con la
--   pista 2 leída) a veces Tom.
-- Ejecutar desde la raíz: lune run tests/bancos/reparto-bichos.luau (lo corre regressions.luau).
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local cuentas = 0
local function igual(actual, esperado, etiqueta: string)
	assert(actual == esperado, `{etiqueta}: esperado {tostring(esperado)}, recibido {tostring(actual)}`)
	cuentas += 1
end

local function cargar(ruta: string)
	return luau.load(fs.readFile(ruta .. ".luau"), { debugName = ruta })()
end

local Config = cargar("src/shared/Config")
local Azar = cargar("src/shared/Azar")
local Reparto = cargar("src/shared/RepartoBichos")
local G, R, T, I = Config.Golpeador, Config.Raspador, Config.Trepador, Config.Imitador

-- Un azar con semilla, como un Random: NextNumber() entre 0 y 1, NextNumber(a, b) entre a y b. Cuenta las tiradas.
local ESCALA = 2 ^ 24
local function conSemilla(semilla: number)
	local a = { tiradas = 0 }
	function a:NextNumber(minimo: number?, maximo: number?): number
		self.tiradas += 1
		local x = Azar.entero(semilla, self.tiradas, 0, ESCALA - 1) / ESCALA
		if minimo and maximo then
			return minimo + x * (maximo - minimo)
		end
		return x
	end
	return a
end
-- Uno que da siempre lo mismo.
local function fijo(valor: number)
	local a = { tiradas = 0 }
	function a:NextNumber(minimo: number?, maximo: number?): number
		self.tiradas += 1
		if minimo and maximo then
			return minimo + valor * (maximo - minimo)
		end
		return valor
	end
	return a
end

local function estado(noche: number, cambios: { [string]: any }?)
	local e = { noche = noche, bestia = false, puertaLibre = true, seguros = {},
		cuantos = { Imitador = 0, Trepador = 0, Raspador = 0 } }
	for k, v in cambios or {} do
		e[k] = v
	end
	return e
end

-- Config con sentido: las noches en orden y probabilidades entre 0 y 1.
for _, c in { R, T, I } do
	igual(type(c.Noche) == "number" and c.Noche >= 1, true, "Config: Noche")
	igual(c.Probabilidad > 0 and c.Probabilidad < 1, true, "Config: Probabilidad")
end
igual(R.Noche < T.Noche and T.Noche < I.Noche, true, "Config: Raspador, Trepador e Imitador salen en ese orden")
igual(type(Config.Director.Reintento), "number", "Config.Director.Reintento")

-- La noche final: nadie más (y sin tiradas).
local a = fijo(0)
igual(Reparto.toca(estado(12, { bestia = true }), Config, a), nil, "Bestia: no toca nadie")
igual(a.tiradas, 0, "Bestia: sin tiradas")

-- Antes de la noche del Raspador: siempre el Golpeador, sin gastar tiradas.
a = fijo(0)
igual(Reparto.toca(estado(R.Noche - 1), Config, a), "Golpeador", "antes del Raspador: Golpeador")
igual(a.tiradas, 0, "antes del Raspador: sin tiradas")

-- El primer ataque de su noche es suyo, aunque el azar diga que no.
a = fijo(0.999)
igual(Reparto.toca(estado(R.Noche, { seguros = { Raspador = true } }), Config, a), "Raspador", "seguro: Raspador")
a = fijo(0.999)
igual(Reparto.toca(estado(T.Noche, { seguros = { Trepador = true } }), Config, a), "Trepador", "seguro: Trepador")
a = fijo(0.999)
igual(Reparto.toca(estado(I.Noche, { seguros = { Imitador = true } }), Config, a), "Imitador", "seguro: Imitador")
igual(a.tiradas, 0, "seguro: sin tirar")

-- Uno como mucho a la vez de cada uno.
a = fijo(0)
igual(Reparto.toca(estado(R.Noche, { cuantos = { Raspador = 1 }, seguros = { Raspador = true } }), Config, a),
	"Golpeador", "con un Raspador fuera, no otro")

-- El Imitador solo a la puerta principal libre (aunque le toque seguro).
a = fijo(0)
igual(Reparto.toca(estado(I.Noche, { puertaLibre = false, seguros = { Imitador = true } }), Config, a), "Trepador",
	"puerta ocupada: el siguiente de la lista")

-- El orden: el azar más bajo se lo lleva el primero; el más alto, ninguno.
igual(Reparto.toca(estado(I.Noche), Config, fijo(0)), "Imitador", "orden: primero el Imitador")
igual(Reparto.toca(estado(I.Noche, { cuantos = { Imitador = 1 } }), Config, fijo(0)), "Trepador", "orden: luego el Trepador")
igual(Reparto.toca(estado(I.Noche, { cuantos = { Imitador = 1, Trepador = 1 } }), Config, fijo(0)), "Raspador",
	"orden: luego el Raspador")
a = fijo(0.999)
igual(Reparto.toca(estado(I.Noche), Config, a), "Golpeador", "azar alto: Golpeador")
igual(a.tiradas, 3, "una tirada por cada especial que puede salir")

-- Con muchas tiradas, cerca de la Probabilidad de cada uno (el primero que toca se lo lleva).
local veces = { Golpeador = 0, Raspador = 0, Trepador = 0, Imitador = 0 }
local N = 20000
a = conSemilla(4242)
for _ = 1, N do
	local que = Reparto.toca(estado(I.Noche), Config, a) :: string
	veces[que] += 1
end
local function cerca(actual: number, esperado: number, etiqueta: string)
	assert(math.abs(actual - esperado) < 0.02, `{etiqueta}: esperado ~{esperado}, recibido {actual}`)
	cuentas += 1
end
cerca(veces.Imitador / N, I.Probabilidad, "reparto: Imitador")
cerca(veces.Trepador / N, (1 - I.Probabilidad) * T.Probabilidad, "reparto: Trepador")
cerca(veces.Raspador / N, (1 - I.Probabilidad) * (1 - T.Probabilidad) * R.Probabilidad, "reparto: Raspador")

-- Misma semilla, mismo reparto.
local uno, dos = conSemilla(99), conSemilla(99)
for i = 1, 200 do
	igual(Reparto.toca(estado(I.Noche), Config, uno), Reparto.toca(estado(I.Noche), Config, dos), `semilla: ataque {i}`)
end

-- El intervalo.
for i = 1, 200 do
	local s = Reparto.intervalo(1, 1, G, conSemilla(i))
	igual(s >= G.Intervalo[1] and s <= G.Intervalo[2], true, `intervalo noche 1: en el rango ({s})`)
end
igual(Reparto.intervalo(1, 1, G, fijo(0.5)) > Reparto.intervalo(3, 1, G, fijo(0.5)), true, "intervalo: cada noche antes")
igual(Reparto.intervalo(1, 1, G, fijo(0.5)) - Reparto.intervalo(2, 1, G, fijo(0.5)), G.MenosPorNoche, "intervalo: MenosPorNoche")
igual(Reparto.intervalo(100, 1, G, fijo(0.999)), G.IntervaloMin, "intervalo: nunca menos del mínimo")
igual(Reparto.intervalo(100, 1.3, G, fijo(0)), G.IntervaloMin * 1.3, "intervalo: por el ritmo")
igual(Reparto.intervalo(1, 0.8, G, fijo(0)), G.Intervalo[1] * 0.8, "intervalo: ritmo y rango")

-- La voz del Imitador (RepartoBichos.voz).
igual(I.VozMuerto > 0 and I.VozMuerto < 1, true, "Config: VozMuerto")
igual(I.Antiguo.Probabilidad > 0 and I.Antiguo.Probabilidad < 1, true, "Config: Antiguo.Probabilidad")
igual(I.Antiguo.Nombre, "Tom", "Config: Antiguo.Nombre (el de la foto de la pista 2)")
local ana, luis, eva = { DisplayName = "Ana" }, { DisplayName = "Luis" }, { DisplayName = "Eva" }
local function contarVoces(muertos, lejos, todos, leida: boolean, semilla: number)
	local cuenta = {}
	a = conSemilla(semilla)
	for _ = 1, N do
		local nombre, jugador = Reparto.voz(muertos, lejos, todos, leida, a, I)
		igual(jugador == nil or jugador.DisplayName == nombre, true, "voz: el nombre es el del jugador")
		cuenta[nombre or "nadie"] = (cuenta[nombre or "nadie"] or 0) + 1
	end
	return cuenta
end
-- Con un muerto: casi siempre él (VozMuerto); si no, uno de los de lejos.
local cuenta = contarVoces({ eva }, { luis }, { ana, luis, eva }, true, 7)
cerca(cuenta.Eva / N, I.VozMuerto, "voz: el muerto")
cerca((cuenta.Luis or 0) / N, 1 - I.VozMuerto, "voz: si no, el de lejos")
igual(cuenta.Tom, nil, "voz: con más gente, nunca Tom")
-- Sin muertos: uno de los de lejos, nunca el de la puerta.
cuenta = contarVoces({}, { luis, eva }, { ana, luis, eva }, true, 8)
igual(cuenta.Ana, nil, "voz: nunca el de la puerta")
cerca(cuenta.Luis / N, 0.5, "voz: entre los de lejos, a partes iguales")
-- Solo y sin la foto de Tom: tu voz (y el jugador, para el aviso de "tu voz").
local nombre, jugador = Reparto.voz({}, {}, { ana }, false, fijo(0), I)
igual(nombre, "Ana", "solo sin la pista 2: tu voz")
igual(jugador, ana, "solo sin la pista 2: eres tú")
-- Solo y con la foto: a veces Tom (sin jugador: a nadie le dice que es su voz).
cuenta = contarVoces({}, {}, { ana }, true, 9)
cerca(cuenta.Tom / N, I.Antiguo.Probabilidad, "solo con la pista 2: a veces Tom")
cerca(cuenta.Ana / N, 1 - I.Antiguo.Probabilidad, "solo con la pista 2: si no, tu voz")
nombre, jugador = Reparto.voz({}, {}, { ana }, true, fijo(0), I)
igual(nombre, "Tom", "Tom: el nombre")
igual(jugador, nil, "Tom: sin jugador")
-- Con dos en la partida y los dos en la puerta, nunca Tom (es solo para jugar solo).
cuenta = contarVoces({}, {}, { ana, luis }, true, 10)
igual(cuenta.Tom, nil, "dos en la puerta: nunca Tom")
-- Nadie en la partida: sin voz.
igual(Reparto.voz({}, {}, {}, true, fijo(0), I), nil, "sin jugadores: sin voz")
-- Elegir la voz no toca el reparto: la misma semilla de toca sigue igual.
uno, dos = conSemilla(99), conSemilla(99)
for i = 1, 50 do
	Reparto.voz({ eva }, { luis }, { ana, luis, eva }, true, conSemilla(i), I)
	igual(Reparto.toca(estado(I.Noche), Config, uno), Reparto.toca(estado(I.Noche), Config, dos), `semilla tras la voz: ataque {i}`)
end

-- Los require del servidor del juego (hallazgo 17): ninguno dentro de una función (eran para esquivar un círculo) y
-- ningún círculo entre los de arriba (si los hubiera, el servidor fallaría al arrancar).
local DIR = "src/juego/servidor"
local deps: { [string]: { string } } = {}
local fuentes: { [string]: string } = {}
for _, archivo in fs.readDir(DIR) do
	local nombre = string.match(archivo, "^([%w_]+)%.luau$")
	if nombre then
		local fuente = fs.readFile(DIR .. "/" .. archivo)
		fuentes[nombre] = fuente
		deps[nombre] = {}
		for linea in string.gmatch(fuente .. "\n", "([^\n]*)\n") do
			local otro = string.match(linea, "require%(script%.Parent%.([%w_]+)%)")
			if otro then
				igual(string.match(linea, "^local ") ~= nil, true, `{nombre}: require de {otro} arriba del todo, no dentro de una función`)
				table.insert(deps[nombre], otro)
			end
		end
	end
end
local marcas: { [string]: string } = {} -- "viendo" mientras se recorre, "visto" al acabar
local function recorrer(nombre: string, camino: { string })
	if marcas[nombre] == "visto" then
		return
	end
	assert(marcas[nombre] ~= "viendo", `require en círculo: {table.concat(camino, " -> ")}`)
	marcas[nombre] = "viendo"
	for _, otro in deps[nombre] or {} do
		local siguiente = table.clone(camino)
		table.insert(siguiente, otro)
		recorrer(otro, siguiente)
	end
	marcas[nombre] = "visto"
end
for nombre in deps do
	recorrer(nombre, { nombre })
end
cuentas += 1

-- Todo bicho (un módulo con irse() y quitar()) se apunta en Bichos en su start(), y el init lo arranca: si no, Director,
-- Coche, Bestia e Incendio no lo quitarían.
local init = fs.readFile(DIR .. "/init.server.luau")
local apuntados = 0
for nombre, fuente in fuentes do
	if string.find(fuente, `function {nombre}.irse()`, 1, true) and string.find(fuente, `function {nombre}.quitar()`, 1, true) then
		igual(string.find(fuente, `Bichos.registrar("{nombre}", {nombre})`, 1, true) ~= nil, true, `{nombre}: se apunta en Bichos`)
		igual(string.find(init, `require(Sistemas.{nombre}).start()`, 1, true) ~= nil, true, `{nombre}: arranca en el init`)
		apuntados += 1
	end
end
igual(apuntados >= 6, true, "bichos apuntados (Golpeador, Raspador, Trepador, Imitador, Acechador, Bestia)")
-- Y nadie fuera de su propio módulo llama a quitar() o irse() de uno a uno (para eso está Bichos), salvo el Director
-- con el Acechador en la noche final (lo quita en cuanto aparece).
for nombre, fuente in fuentes do
	for otro in string.gmatch(fuente, "([%w_]+)%.quitar%(%)") do
		if otro ~= nombre and deps[otro] and not (nombre == "Director" and otro == "Acechador") then
			error(`{nombre} quita a {otro} a mano: usa Bichos`)
		end
	end
	for otro in string.gmatch(fuente, "([%w_]+)%.irse%(%)") do
		if otro ~= nombre and deps[otro] then
			error(`{nombre} manda irse a {otro} a mano: usa Bichos`)
		end
	end
end
cuentas += 1

print(`reparto-bichos: {cuentas} comprobaciones`)
