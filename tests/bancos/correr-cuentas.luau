-- Cuentas de correr y aguante (14.8, pedido por el usuario: "haz las cuentas de distancias y tiempos con Lune").
-- Ejecutar desde la raíz: lune run tests/bancos/correr-cuentas.luau (también lo lanza tests/regressions.luau).
-- Sin Roblox: carga Config, CorrerReglas y PosturaReglas y simula a 60 Hz persecuciones en línea recta (sin esquinas,
-- puertas ni caminos: el bicho va siempre a por ti a su velocidad de correr) con tres maneras de huir:
--   andar: no corre nunca.
--   agotar: mantiene Shift todo el rato (corre hasta agotarse, anda frenado y, en cuanto puede, vuelve a correr).
--   ciclo: suelta Shift al bajar de `hasta` y lo vuelve a pisar al llegar a `desde` (se prueban varios; sale el mejor).
-- Comprueba lo que pide el diseño (riesgo y premio):
--   1. Correr sirve para escapar un trecho: en la primera carrera el hueco crece contra Golpeador, Bestia y Acechador.
--   2. Contra el Acechador, corriendo se llega a la luz (Config.Acechador.Refugio) desde la granja y el aserradero;
--      andando, no (solo muy cerca de la casa).
--   3. Correr no deja atrás a todos siempre: la media sostenida del mejor ciclo de un jugador normal es menor que la
--      de la Bestia y la del Acechador (y el Acechador te acaba pillando si la luz está lejos).
--   4. Correr hace ruido: PosturaReglas.alcanceOido corriendo.
-- Si algo no se cumple, termina con error.
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
local CR = cargar("src/shared/CorrerReglas")
local PosturaReglas = cargar("src/shared/PosturaReglas")
local C = Config.Correr
local A = Config.Acechador

local DT = 1 / 60
local ANDAR = 16 -- StarterPlayer.CharacterWalkSpeed
local CORREDOR = 16 * 1.2 -- la clase Corredor (Ventajas.Velocidad)
local HORIZONTE = 60 -- s de persecución como mucho (los de la casa cazan menos: Config.Golpeador.Caza...)

-- Distancias del bosque, desde el centro de la casa (los centros de las zonas de juego/servidor/Lugares; supuestas
-- para lo que no tiene sitio fijo).
local SITIOS = {
	{ "talando cerca", 100 }, -- supuesto: árboles justo fuera de la luz (el bosque empieza a 48)
	{ "granja", 218 }, -- Lugares: Granja (205, 75)
	{ "aserradero", 248 }, -- Aserradero (-232, -86)
	{ "torre", 299 }, -- Torre (90, 285)
}

local fallos = {}
local function comprobar(cumple: boolean, que: string)
	if not cumple then
		table.insert(fallos, que)
	end
end

local JUGADOR = { vivo = true, escondido = false, cargando = false, mochila = false, agachado = false, asomado = false }

-- Las maneras de huir: dado el estado, ¿pisa Shift? (`pisa` es lo que pisaba el paso anterior)
type Estrategia = { nombre: string, pisa: (e: CR.Estado, pisa: boolean) -> boolean }
local function ciclo(hasta: number, desde: number): Estrategia
	return {
		nombre = `ciclo {hasta}-{desde}`,
		pisa = function(e, pisa)
			if pisa then
				return e.aguante > hasta and not e.agotado
			end
			return e.aguante >= desde and not e.agotado
		end,
	}
end
local ANDA: Estrategia = { nombre = "andar", pisa = function()
	return false
end }
local AGOTA: Estrategia = { nombre = "agotar", pisa = function()
	return true
end }
local CICLOS = {}
for _, hasta in { 0.02, C.Poco } do
	for _, desde in { 0.4, 0.6, 0.8, 1 } do
		table.insert(CICLOS, ciclo(hasta, desde))
	end
end

-- Un jugador que huye: lleva su estado de aguante y su velocidad (como Cargar.ajustarVelocidad con Frena).
type Corredor = { e: CR.Estado, t: number, v: number, pisa: boolean, andar: number, estrategia: Estrategia }
local function nuevoCorredor(estrategia: Estrategia, andar: number): Corredor
	return { e = CR.nuevo(), t = 100, v = andar, pisa = false, andar = andar, estrategia = estrategia }
end
local function paso(c: Corredor): number
	c.t += DT
	local pisa = c.estrategia.pisa(c.e, c.pisa)
	if pisa ~= c.pisa then
		local _, e2 = CR.pedir(c.e, pisa, c.t)
		c.e, c.pisa = e2, pisa
	end
	c.e = CR.paso(c.e, DT, c.t, c.v, 1, JUGADOR)
	local factor = if c.e.frena > 0 then C.FactorFrena else 1
	local andar = c.andar * factor
	c.v = CR.velocidad(andar, c.e.corriendo and factor == 1)
	return c.v * DT
end

-- Velocidad media en los primeros 60 s desde descansado y la sostenida (de 60 a 360 s: ya sin el aguante del
-- principio y con muchos ciclos, para que no dependa de dónde caiga el corte).
local function medias(estrategia: Estrategia, andar: number): (number, number)
	local c = nuevoCorredor(estrategia, andar)
	local hecho, a60 = 0, 0
	for i = 1, 360 * 60 do
		hecho += paso(c)
		if i == 60 * 60 then
			a60 = hecho
		end
	end
	return a60 / 60, (hecho - a60) / 300
end

-- Un bicho detrás a `hueco` studs. `velocidad(t)` la suya en cada instante; `dura` s que persigue como mucho;
-- `luz` studs hasta ponerse a salvo (nil = no hay). Devuelve cuándo pilla (nil = escapa), la distancia ganada en la
-- primera carrera (nil si no corre) y lo que ha recorrido el jugador.
type Bicho = { nombre: string, velocidad: (t: number) -> number, pillar: number, dura: number }
local function persecucion(b: Bicho, hueco: number, estrategia: Estrategia, andar: number, luz: number?)
	local c = nuevoCorredor(estrategia, andar)
	local tiempo, recorrido, distancia = 0, 0, hueco
	local gana, empezo = nil, nil
	while tiempo < b.dura do
		tiempo += DT
		local avance = paso(c)
		recorrido += avance
		distancia += avance - b.velocidad(tiempo) * DT
		if c.e.corriendo and empezo == nil then
			empezo = distancia
		elseif empezo and gana == nil and not c.e.corriendo then
			gana = distancia - empezo
		end
		if luz and recorrido >= luz then
			return nil, gana, recorrido, "luz", tiempo
		end
		if distancia <= b.pillar then
			return tiempo, gana, recorrido, "pilla", tiempo
		end
	end
	return nil, gana, recorrido, "cansa", tiempo
end

local function fijo(v: number)
	return function()
		return v
	end
end
local BICHOS: { Bicho } = {
	{ nombre = "Golpeador", velocidad = fijo(Config.Golpeador.Correr), pillar = Config.Golpeador.Pillar, dura = HORIZONTE },
	{ nombre = "Raspador", velocidad = fijo(Config.Raspador.Correr), pillar = Config.Raspador.Pillar, dura = HORIZONTE },
	{ nombre = "Trepador", velocidad = fijo(Config.Trepador.Correr), pillar = Config.Trepador.Pillar, dura = HORIZONTE },
	{ nombre = "Imitador", velocidad = fijo(Config.Imitador.Correr), pillar = Config.Imitador.Pillar, dura = HORIZONTE },
	{ nombre = "Bestia", velocidad = fijo(Config.Bestia.Correr), pillar = Config.Bestia.Pillar, dura = HORIZONTE },
	{ nombre = "Bestia coja", velocidad = function(t)
		return if t < Config.Bestia.Cojea then Config.Bestia.Cojear else Config.Bestia.Correr
	end, pillar = Config.Bestia.Pillar, dura = HORIZONTE },
	-- Acechador: en su código pilla a Pillar + 2 (Acechador.ataque) y se cansa a los Persigue s.
	{ nombre = "Acechador", velocidad = fijo(A.Correr), pillar = A.Pillar + 2, dura = A.Persigue },
}
local HUECOS = { 8, 15, 25 }
-- El Acechador acecha a Lejos y se acerca hasta Lejos - 4 (Acechador.ataque): carga desde ahí (el peor caso).
local HUECO_ACECHADOR = A.Lejos - 4

local function texto(n: number?, decimales: number?): string
	if n == nil then
		return "-"
	end
	return string.format(`%.{decimales or 1}f`, n)
end

-- 1. Medias sostenidas.
print(`Correr: x{C.Factor}, dura {C.Dura} s, espera {C.Espera} s, vuelve {texto(1 / C.Andando)} s andando`
	.. ` y {texto(1 / C.Quieto)} s quieto, agotado hasta {texto(C.Volver, 2)}, frena {C.Frena} s a x{C.FactorFrena}`)
print("\nVelocidad media (studs/s): primeros 60 s desde descansado | sostenida (de 60 a 360 s)")
local mejorCiclo, mejorSostenida = CICLOS[1], -math.huge
for _, est in { ANDA, AGOTA, table.unpack(CICLOS) } do
	local m60, sost = medias(est, ANDAR)
	local m60c, sostc = medias(est, CORREDOR)
	print(string.format("  %-14s normal %5.2f | %5.2f    Corredor %5.2f | %5.2f", est.nombre, m60, sost, m60c, sostc))
	if est ~= ANDA and sost > mejorSostenida then
		mejorCiclo, mejorSostenida = est, sost
	end
end
print(`  mejor: {mejorCiclo.nombre} ({texto(mejorSostenida, 2)}); Bestia {Config.Bestia.Correr}, Acechador {A.Correr}`)
comprobar(mejorSostenida < Config.Bestia.Correr, "la media sostenida del mejor ciclo no es menor que la Bestia")
comprobar(mejorSostenida < A.Correr, "la media sostenida del mejor ciclo no es menor que el Acechador")
comprobar(mejorSostenida > ANDAR, "correr no sube la media sostenida")

-- 2. Persecuciones. La columna "ciclo" es el mejor de todos los ciclos para esa persecución (escapar o, si no, que
-- tarde más en pillarte).
local function mejorEn(b: Bicho, hueco: number, andar: number, luz: number?)
	local mejor, mejorPilla, mejorGana, mejorRecorrido, mejorComo, mejorT = nil, nil, nil, -math.huge, nil, nil
	for _, est in CICLOS do
		local pilla, gana, recorrido, como, t = persecucion(b, hueco, est, andar, luz)
		local vale = if pilla == nil then math.huge else pilla
		local antes = if mejor == nil then -math.huge elseif mejorPilla == nil then math.huge else mejorPilla
		if vale > antes or (vale == antes and recorrido > mejorRecorrido) then
			mejor, mejorPilla, mejorGana, mejorRecorrido, mejorComo, mejorT = est, pilla, gana, recorrido, como, t
		end
	end
	return mejorPilla, mejorGana, mejorRecorrido, mejorComo, mejorT, mejor
end
local function huir(b: Bicho, hueco: number, est: Estrategia | string, andar: number, luz: number?)
	if est == "ciclo" then
		return mejorEn(b, hueco, andar, luz)
	end
	local pilla, gana, recorrido, como, t = persecucion(b, hueco, est :: Estrategia, andar, luz)
	return pilla, gana, recorrido, como, t, est :: Estrategia
end
local ESTRATEGIAS: { Estrategia | string } = { ANDA, AGOTA, "ciclo" }
local function nombre(est: Estrategia | string): string
	return if type(est) == "string" then est else est.nombre
end
print("\nPersecuciones (jugador normal, 16, en línea recta): pilla a los X s, escapa (le pierde de vista, a más de")
print("su Vista) o se cansa (el bicho deja de perseguir) | hueco ganado en la 1.ª carrera")
for _, b in BICHOS do
	local huecos = if b.nombre == "Acechador" then { HUECO_ACECHADOR, A.Lejos } else HUECOS
	for _, hueco in huecos do
		local fila = string.format("  %-11s a %2d:", b.nombre, hueco)
		for _, est in ESTRATEGIAS do
			local pilla, gana, _, como = huir(b, hueco, est, ANDAR)
			local res = if pilla then `pilla {texto(pilla)} s` else (if como == "cansa" then "se cansa" else "escapa")
			fila ..= string.format("  %-6s %-13s %6s", nombre(est), res, if gana then "+" .. texto(gana) else "-")
			if est ~= ANDA and (b.nombre == "Golpeador" or b.nombre == "Bestia" or b.nombre == "Acechador") then
				comprobar(gana ~= nil and gana > 0, `{b.nombre} a {hueco} ({nombre(est)}): el hueco no crece en la carrera`)
			end
		end
		print(fila)
	end
end

-- 3. El Acechador y la luz: desde la carga, ¿se llega a Refugio?
print(`\nAcechador desde la carga (a {HUECO_ACECHADOR} studs): ¿llega a la luz (a {A.Refugio} del centro)?`)
local alcances: { [string]: number } = {}
for _, est in ESTRATEGIAS do
	local _, _, recorrido, como, t, cual = huir(BICHOS[#BICHOS], HUECO_ACECHADOR, est, ANDAR)
	alcances[nombre(est)] = if como == "pilla" then recorrido else math.huge
	print(string.format("  %-6s (%s) %s a los %4.1f s tras %5.1f studs: llega a la luz desde %s del centro",
		nombre(est), cual.nombre, if como == "pilla" then "le pilla" else "se cansa", t, recorrido,
		if como == "pilla" then string.format("< %.0f", A.Refugio + recorrido) else "cualquier sitio"))
end
for _, sitio in SITIOS do
	local luz = sitio[2] - A.Refugio
	local fila = string.format("  %-14s (%3d, %3d hasta la luz):", sitio[1], sitio[2], luz)
	for _, est in ESTRATEGIAS do
		fila ..= `  {nombre(est)} {if alcances[nombre(est)] >= luz then "SÍ" else "no"}`
	end
	print(fila)
end
local mejorCorriendo = math.max(alcances.agotar, alcances.ciclo)
for _, sitio in SITIOS do
	if sitio[1] == "granja" or sitio[1] == "aserradero" then
		local luz = sitio[2] - A.Refugio
		comprobar(mejorCorriendo >= luz, `Acechador: corriendo no se llega a la luz desde {sitio[1]}`)
		comprobar(alcances.andar < luz, `Acechador: andando se llega a la luz desde {sitio[1]}`)
	end
end
-- Lejos de la luz, con Shift pisado todo el rato te acaba pillando antes de cansarse (no basta con correr: hay que
-- volver a la luz). Con el mejor ciclo, desde la carga más cercana también, por poco; desde Lejos, aguanta hasta que se
-- cansa: es el premio de llevar bien el aguante (Config.Acechador.Persigue lo decide; no es de este bloque).
comprobar(alcances.agotar < math.huge, "Acechador: con Shift pisado aguantas hasta que se cansa (sin llegar a la luz)")

-- 4. Ruido.
local OIDO = Config.Postura.Oido
local oyeCorriendo = PosturaReglas.alcanceOido(OIDO, false, false, true)
print(`\nOído de los bichos: de pie {OIDO}, corriendo {oyeCorriendo}, agachado`
	.. ` {PosturaReglas.alcanceOido(OIDO, true, false, true)}, debajo de algo {PosturaReglas.alcanceOido(OIDO, true, true, true)}`)
comprobar(oyeCorriendo == math.max(OIDO, C.Oido), "corriendo te oyen a Config.Correr.Oido")
comprobar(PosturaReglas.alcanceOido(OIDO, false, false, false) == OIDO, "sin correr, lo de siempre")
comprobar(PosturaReglas.alcanceOido(OIDO, false, false) == OIDO, "sin decir si corre, lo de siempre")
comprobar(PosturaReglas.alcanceOido(OIDO, true, false, true) == Config.Postura.OirAgachado, "agachado no suma el ruido")
comprobar(PosturaReglas.alcanceOido(OIDO, true, true, true) == Config.Postura.VerCubierto, "cubierto no suma el ruido")
comprobar(PosturaReglas.alcanceOido(40, false, false, true) == 40, "corriendo nunca oye menos")

if #fallos > 0 then
	error("correr-cuentas: no se cumple:\n  " .. table.concat(fallos, "\n  "))
end
print(`\nCorrer: cuentas bien (mejor ciclo {mejorCiclo.nombre}: {texto(mejorSostenida, 2)} studs/s sostenidos; del`
	.. ` Acechador, corriendo se llega a la luz desde {texto(A.Refugio + mejorCorriendo, 0)} del centro y andando desde`
	.. ` {texto(A.Refugio + alcances.andar, 0)}).`)
