-- Los bichos ven de frente (PosturaReglas.vistaDeLado): colarse a su espalda sirve. Ejecutar desde la raíz:
-- lune run tests/bancos/vista-bichos.luau (también lo lanza tests/regressions.luau).
-- Sin Roblox: carga Config y PosturaReglas y hace las mismas cuentas que Caza.elegirPresa (vistaDeLado y luego
-- alcanceVista) con un bicho en el origen mirando a +Z y el jugador en varios sitios:
--   1. De frente, la Vista entera (como antes); de espaldas, solo VerEspalda.
--   2. El borde del cono: justo dentro, entera; justo fuera, VerEspalda. Un Campo propio (Opciones.Campo) manda.
--   3. Recién visto (menos de Memoria s), entera hacia cualquier lado; pasado ese rato, otra vez VerEspalda.
--   4. Agachado y cubierto siguen mandando también a su espalda.
--   5. Caza.elegirPresa usa vistaDeLado con vistoEn y el LookVector de su raíz.
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
local PR = cargar("src/shared/PosturaReglas")
local P = Config.Postura

local cuentas = 0
local function comprueba(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end
local function cerca(a: number, b: number, etiqueta: string)
	comprueba(math.abs(a - b) < 1e-9, `{etiqueta}: {a} (se esperaba {b})`)
end

-- Las claves existen y tienen sentido.
comprueba(type(P.Campo) == "number" and P.Campo > 0 and P.Campo < 180, "Config.Postura.Campo entre 0 y 180")
comprueba(type(P.VerEspalda) == "number" and P.VerEspalda > P.Oido, "VerEspalda: más que lo que te oye de pie")
comprueba(type(P.Memoria) == "number" and P.Memoria > 0, "Config.Postura.Memoria > 0")

-- Lo que hace Caza.elegirPresa: el bicho en el origen mirando a +Z, el jugador a `angulo` grados de su frente.
local function alcance(vista: number, angulo: number, o: { visto: number?, agachado: boolean?, cubierto: boolean?, campo: number? }?): number
	local op = o or {}
	local recienVisto = op.visto ~= nil and op.visto < P.Memoria -- s desde la última vez que le vio u oyó
	local lado = PR.vistaDeLado(vista, math.cos(math.rad(angulo)), recienVisto, op.campo)
	return PR.alcanceVista(lado, op.agachado == true, op.cubierto == true)
end

-- La Vista de los bichos de verdad (Golpeador, Bestia...) y una de prueba.
local vistas = { 70 }
if Config.Golpeador and Config.Golpeador.Vista then
	vistas[1] = Config.Golpeador.Vista
end
if Config.Bestia and Config.Bestia.Vista then
	table.insert(vistas, Config.Bestia.Vista)
end

for _, vista in vistas do
	-- 1. De frente y de espaldas.
	cerca(alcance(vista, 0), vista, "de frente, entera")
	cerca(alcance(vista, 30), vista, "a 30 grados, entera")
	cerca(alcance(vista, 180), math.min(vista, P.VerEspalda), "de espaldas, VerEspalda")
	cerca(alcance(vista, 90), math.min(vista, P.VerEspalda), "de lado, VerEspalda")
	cerca(alcance(vista, -120), math.min(vista, P.VerEspalda), "por detrás a la izquierda, VerEspalda")
	comprueba(alcance(vista, 180) < 20, "a 20 studs a su espalda no te ve (lo de probar en Studio)")
	-- 2. El borde del cono.
	cerca(alcance(vista, P.Campo - 1), vista, "justo dentro del cono, entera")
	cerca(alcance(vista, -(P.Campo - 1)), vista, "justo dentro del cono (al otro lado), entera")
	cerca(alcance(vista, P.Campo + 1), math.min(vista, P.VerEspalda), "justo fuera del cono, VerEspalda")
	cerca(alcance(vista, 100, { campo = 110 }), vista, "con Campo propio más ancho, entera")
	cerca(alcance(vista, 40, { campo = 30 }), math.min(vista, P.VerEspalda), "con Campo propio más estrecho, fuera")
	-- 3. Recién visto.
	cerca(alcance(vista, 180, { visto = 0 }), vista, "recién visto, de espaldas, entera")
	cerca(alcance(vista, 180, { visto = P.Memoria - 0.1 }), vista, "visto hace casi Memoria s, entera")
	cerca(alcance(vista, 180, { visto = P.Memoria + 0.1 }), math.min(vista, P.VerEspalda), "pasada la Memoria, VerEspalda")
	-- 4. Agachado y cubierto siguen mandando.
	cerca(alcance(vista, 0, { agachado = true }), vista * P.VistaAgachado, "de frente agachado")
	cerca(alcance(vista, 180, { agachado = true }), math.min(vista, P.VerEspalda) * P.VistaAgachado, "de espaldas agachado")
	comprueba(alcance(vista, 180, { agachado = true }) < alcance(vista, 180), "agachado a su espalda, aún menos")
	cerca(alcance(vista, 0, { cubierto = true }), math.min(vista, P.VerCubierto), "de frente cubierto")
	cerca(alcance(vista, 180, { cubierto = true }), math.min(vista, P.VerCubierto), "de espaldas cubierto")
	cerca(alcance(vista, 180, { cubierto = true, visto = 0 }), math.min(vista, P.VerCubierto), "recién visto cubierto")
	-- Ningún lado ve más que de frente.
	for angulo = -180, 180, 5 do
		comprueba(alcance(vista, angulo) <= alcance(vista, 0), `a {angulo} grados no ve más que de frente`)
	end
end

-- Un coseno raro (NaN) cuenta como de frente: nunca a ciegas.
cerca(PR.vistaDeLado(70, 0 / 0, false), 70, "coseno NaN, entera")

-- 5. Caza.elegirPresa lo usa (solo esa función: la vista al perseguir es otra cosa).
local caza = fs.readFile("src/juego/servidor/Caza.luau")
local inicio = string.find(caza, "function Caza.elegirPresa", 1, true)
comprueba(inicio ~= nil, "Caza.elegirPresa existe")
local fin = string.find(caza, "\nend\n", inicio, true)
local cuerpo = string.sub(caza, inicio :: number, fin)
comprueba(string.find(cuerpo, "PosturaReglas.vistaDeLado(", 1, true), "elegirPresa usa vistaDeLado")
comprueba(string.find(cuerpo, "raiz.CFrame.LookVector", 1, true), "elegirPresa mira hacia dónde mira su raíz")
comprueba(string.find(cuerpo, "Config.Postura.Memoria", 1, true), "elegirPresa usa la Memoria con vistoEn")
comprueba(string.find(cuerpo, "self.o.Campo", 1, true), "elegirPresa acepta un Campo propio (Opciones.Campo)")
comprueba(string.find(cuerpo, "PosturaReglas.alcanceVista(vista,", 1, true), "alcanceVista se aplica sobre vistaDeLado")

print(`vista-bichos: {cuentas} comprobaciones bien.`)
