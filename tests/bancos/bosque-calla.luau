-- Banco del bosque que se calla (Ambiente.bosqueCalla y Ambiente.bichoCuenta, Config.BosqueCalla, sonidos.md).
-- Ejecutar desde la raíz: lune run tests/bancos/bosque-calla.luau (lo corre tests/regressions.luau).
-- Las dos funciones se sacan del texto de Ambiente (el módulo entero necesita Roblox: Lighting, Ui, Sonido...) y se
-- prueban con bichos de mentira: a 100 studs calla, a 130 no, el Imitador fingiendo no cuenta (abierto sí), un bicho
-- muerto tampoco, y tras irse sigue callado hasta Vuelve. Si algo no se cumple, termina con error.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local V3 = roblox.Vector3

local cuentas = 0
local function comprueba(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end

-- Un "script" falso para cargar Config (lo mismo que tests/regressions).
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
		local entorno = {
			script = nodo(ruta),
			require = function(n)
				return cargar(n.ruta)
			end,
		}
		cargados[ruta] = luau.load(fs.readFile(ruta .. ".luau"), { debugName = ruta, environment = entorno })()
	end
	return cargados[ruta]
end
local Config = cargar("src/shared/Config")
local BC = Config.BosqueCalla
comprueba(BC and BC.Calla > 0 and BC.Vuelve[1] <= BC.Vuelve[2], "Config.BosqueCalla con sentido")
comprueba(BC.Calla > 100 and BC.Calla < 130, "Calla entre 100 y 130 (lo que mira este banco)")

local fuente = fs.readFile("src/juego/cliente/Ambiente.luau")
local desde = string.find(fuente, "function Ambiente.bichoCuenta", 1, true)
local hasta = string.find(fuente, "local function pintarLamparas", 1, true)
assert(desde and hasta and hasta > desde, "no encuentro bichoCuenta y bosqueCalla en Ambiente")
local Ambiente = {}
luau.load(string.sub(fuente, desde, hasta - 1), {
	debugName = "Ambiente.bosqueCalla",
	environment = { Ambiente = Ambiente, Config = Config, math = math },
})()

-- Un bicho de mentira: lo que mira bichoCuenta (IsA, Name, atributos, su Humanoid).
local function bicho(nombre: string, atributos: { [string]: any }?, vida: number?)
	return {
		Name = nombre,
		IsA = function(_, clase)
			return clase == "Model"
		end,
		GetAttribute = function(_, a)
			return (atributos or {})[a]
		end,
		FindFirstChildOfClass = function(_, clase)
			return if clase == "Humanoid" and vida then { Health = vida } else nil
		end,
	}
end
comprueba(Ambiente.bichoCuenta(bicho("Golpeador")), "un bicho cuenta")
comprueba(not Ambiente.bichoCuenta(bicho("Imitador")), "el Imitador fingiendo no cuenta")
comprueba(Ambiente.bichoCuenta(bicho("Imitador", { Abierto = true })), "el Imitador abierto sí cuenta")
comprueba(not Ambiente.bichoCuenta(bicho("Bestia", nil, 0)), "un bicho muerto no cuenta")
comprueba(Ambiente.bichoCuenta(bicho("Bestia", nil, 50)), "un bicho vivo con Humanoid cuenta")
local pieza = { Name = "Suelta", IsA = function()
	return false
end }
comprueba(not Ambiente.bichoCuenta(pieza), "lo que no es un Model no cuenta")

local cam = V3.new(0, 5, 0)
local callado, hastaN, cerca = Ambiente.bosqueCalla({ V3.new(100, 0, 0) }, cam, 10, -math.huge, 30)
comprueba(callado and hastaN == 40 and cerca == V3.new(100, 0, 0), "a 100 studs calla 30 s más")
callado = Ambiente.bosqueCalla({ V3.new(0, 0, 130) }, cam, 10, -math.huge, 30)
comprueba(not callado, "a 130 studs no calla")
callado = Ambiente.bosqueCalla({ V3.new(60, 80, 60) }, cam, 10, -math.huge, 30)
comprueba(callado, "cuenta en planta: la altura no aleja")
callado = Ambiente.bosqueCalla({}, cam, 10, -math.huge, 30)
comprueba(not callado, "sin bichos, calma")

-- El Imitador fingiendo, como lo hace Ambiente: se filtra antes y el bosque sigue sonando.
local modelos = { bicho("Imitador") }
local posiciones = {}
for _, m in modelos do
	if Ambiente.bichoCuenta(m) then
		table.insert(posiciones, V3.new(20, 0, 0))
	end
end
callado = Ambiente.bosqueCalla(posiciones, cam, 10, -math.huge, 30)
comprueba(not callado, "el Imitador llamando sin abrir no calla el bosque")

-- Se acerca, se queda, se va: sigue callado hasta Vuelve después de irse y luego vuelve la calma.
local hastaT = -math.huge
local ahora = 0
local vuelve = BC.Vuelve[1]
callado, hastaT = Ambiente.bosqueCalla({ V3.new(50, 0, 0) }, cam, ahora, hastaT, vuelve)
comprueba(callado, "con el bicho cerca, calla")
ahora = 5
callado, hastaT = Ambiente.bosqueCalla({ V3.new(40, 0, 0) }, cam, ahora, hastaT, vuelve)
comprueba(callado and hastaT == 5 + vuelve, "mientras sigue cerca, el silencio se alarga")
-- Una tirada más corta no recorta un silencio ya puesto.
callado, hastaT = Ambiente.bosqueCalla({ V3.new(40, 0, 0) }, cam, ahora, hastaT, 1)
comprueba(hastaT == 5 + vuelve, "una tirada corta no recorta el silencio")
local seFue = ahora
for t = seFue + 1, seFue + vuelve - 1 do
	callado, hastaT = Ambiente.bosqueCalla({ V3.new(300, 0, 0) }, cam, t, hastaT, vuelve)
	assert(callado, `a los {t - seFue} s de irse aún tiene que callar`)
end
comprueba(true, "tras irse sigue callado hasta Vuelve")
callado = Ambiente.bosqueCalla({ V3.new(300, 0, 0) }, cam, seFue + vuelve + 0.5, hastaT, vuelve)
comprueba(not callado, "pasado Vuelve, vuelve la calma")

print(`bosque-calla: {cuentas} comprobaciones bien`)
