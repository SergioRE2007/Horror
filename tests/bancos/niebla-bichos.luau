-- Con niebla cerrada los bichos tampoco ven lejos en el bosque (docs/sistemas/bichos.md, cielo.md). Ejecutar desde la
-- raíz: lune run tests/bancos/niebla-bichos.luau (también lo lanza tests/regressions.luau).
--   1. shared/TiempoNoche da lo mismo que las cuentas de antes (TormentaVista.semilla y hay, CieloVista.hayNiebla,
--      copiadas aquí tal cual) en muchas noches, y TormentaVista y CieloVista de verdad dan lo mismo que TiempoNoche.
--   2. Nunca niebla y tormenta la misma noche; ninguna niebla antes de Desde.
--   3. TiempoNoche.vistaConNiebla: con niebla y fuera, la vista por Config.Caza.Niebla.Vista (el Golpeador, 70 a 28) sin
--      bajar de VerEspalda; dentro o sin niebla, la misma. Agachado sigue mandando encima.
--   4. Caza.esNiebla (sacada del texto: Caza necesita Roblox): de día nada; de noche la de TiempoNoche hasta
--      Config.Cielo.Niebla.Abre; NieblaPrueba y TormentaPrueba solo en Studio; la tirada, una vez por noche.
--   5. Caza.elegirPresa la aplica entre vistaDeLado y alcanceVista y el oído no cambia; el Acechador, más cerca.
-- Si algo no se cumple, termina con error.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local crearMundo = require("./_roblox")

local cuentas = 0
local function comprueba(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end

local m = crearMundo({})
local g = m.global
local Config = m.cargar("src/shared/Config")
local TN = m.cargar("src/shared/TiempoNoche")
local PR = m.cargar("src/shared/PosturaReglas")
local NB, TC = Config.Cielo.Niebla, Config.Tormenta

-- Las cuentas de antes, tal cual estaban en TormentaVista y CieloVista.
local function semillaVieja(noche: number, inicio: number): number
	return (math.floor(inicio) % 2_147_000) * 1000 + math.floor(noche) % 1000
end
local function hayVieja(noche: number, inicio: number, cfg: any): boolean
	if noche < cfg.Desde then
		return false
	end
	return g.Random.new(semillaVieja(noche, inicio)):NextNumber() < cfg.Probabilidad
end
local function nieblaVieja(noche: number, inicio: number, cfg: any): boolean
	if noche < cfg.Desde or hayVieja(noche, inicio, TC) then
		return false
	end
	return g.Random.new(semillaVieja(noche, inicio) + 104729):NextNumber() < cfg.Probabilidad
end

-- 1 y 2. La cuenta compartida, la misma que la vieja; TormentaVista y CieloVista de verdad, también.
local mudo = { bucle = function()
	return g.Instance.new("Sound")
end, tocar = function() end, en = function() end }
m.cargar("src/juego/cliente/Ambiente", { Sonido = mudo })
local TV = m.cargar("src/juego/cliente/TormentaVista", { CasaVista = {}, Sonido = mudo })
local CV = m.cargar("src/juego/cliente/CieloVista")
local distintas, juntas, nieblas, tormentas, antes = 0, 0, 0, 0, 0
for i = 1, 4000 do
	local noche, inicio = 1 + i % 14, 1_700_000_000 + i * 977 + (i % 7) * 0.37
	local t, n = TN.hayTormenta(noche, inicio, TC), TN.hayNiebla(noche, inicio, NB, TC)
	if TN.semilla(noche, inicio) ~= semillaVieja(noche, inicio) or t ~= hayVieja(noche, inicio, TC)
		or n ~= nieblaVieja(noche, inicio, NB) then
		distintas += 1
	end
	if TV.semilla(noche, inicio) ~= TN.semilla(noche, inicio) or TV.hay(noche, inicio, TC) ~= t
		or CV.hayNiebla(noche, inicio, NB) ~= n then
		distintas += 1
	end
	juntas += if t and n then 1 else 0
	antes += if noche < NB.Desde and n then 1 else 0
	nieblas += if n then 1 else 0
	tormentas += if t then 1 else 0
end
comprueba(distintas == 0, `TiempoNoche da lo mismo que las cuentas de antes ({distintas} noches distintas)`)
comprueba(juntas == 0, "nunca niebla y tormenta la misma noche")
comprueba(antes == 0, "ninguna niebla antes de Desde")
comprueba(nieblas > 0 and tormentas > 0, `hay noches de las dos ({nieblas} de niebla, {tormentas} de tormenta)`)

-- 3. La vista con niebla: menor solo fuera.
local K, ESPALDA = Config.Caza.Niebla.Vista, Config.Postura.VerEspalda
comprueba(K > 0 and K < 1, "Config.Caza.Niebla.Vista entre 0 y 1")
local A = Config.Caza.Niebla.Acechador
comprueba(type(A) == "number" and A > 0 and A < 1, "Config.Caza.Niebla.Acechador entre 0 y 1")
local GOLPEADOR = Config.Golpeador.Vista
local conNiebla = TN.vistaConNiebla(GOLPEADOR, true, true, K, ESPALDA)
comprueba(math.abs(conNiebla - GOLPEADOR * K) < 1e-6, `con niebla y fuera, Vista por Niebla.Vista ({conNiebla})`)
comprueba(conNiebla < GOLPEADOR and conNiebla > ESPALDA, "con niebla ve menos, pero más que a su espalda")
comprueba(TN.vistaConNiebla(GOLPEADOR, true, false, K, ESPALDA) == GOLPEADOR, "con niebla y dentro, la misma")
comprueba(TN.vistaConNiebla(GOLPEADOR, false, true, K, ESPALDA) == GOLPEADOR, "sin niebla, la misma")
comprueba(TN.vistaConNiebla(ESPALDA, true, true, K, ESPALDA) == ESPALDA, "a su espalda no baja de VerEspalda")
comprueba(TN.vistaConNiebla(ESPALDA * 2, true, true, 0.01, ESPALDA) == ESPALDA, "nunca por debajo de VerEspalda")
comprueba(TN.vistaConNiebla(5, true, true, K, ESPALDA) == 5, "una vista menor que VerEspalda no sube")
for _, bicho in { "Golpeador", "Raspador", "Imitador", "Trepador" } do
	local v = Config[bicho].Vista
	local fuera = PR.alcanceVista(TN.vistaConNiebla(v, true, true, K, ESPALDA), true, false, false)
	local dentro = PR.alcanceVista(TN.vistaConNiebla(v, true, false, K, ESPALDA), true, false, false)
	comprueba(fuera < dentro, `{bicho}: agachado con niebla fuera se te ve menos que dentro`)
end

-- 4. Caza.esNiebla, sacada del texto con un workspace y un RunService de mentira.
local caza = fs.readFile("src/juego/servidor/Caza.luau")
local i0 = string.find(caza, "local nieblaDe", 1, true)
local _, i1 = string.find(caza, "\nend\n", string.find(caza, "function Caza.esNiebla()", 1, true), true)
comprueba(i0 and i1, "Caza.esNiebla existe")
local atributos: { [string]: any } = {}
local ahora = 1_700_000_000
local studio = false
local tiradas = 0
local TNcontado = table.clone(TN)
TNcontado.hayNiebla = function(...)
	tiradas += 1
	return TN.hayNiebla(...)
end
local espacio = {
	GetAttribute = function(_, k: string)
		return atributos[k]
	end,
	GetServerTimeNow = function()
		return ahora
	end,
}
local esNiebla = luau.load("local Caza = {}\n" .. string.sub(caza, i0 :: number, i1 :: number) .. "\nreturn Caza.esNiebla", {
	debugName = "Caza.esNiebla",
	environment = {
		workspace = espacio,
		RunService = { IsStudio = function()
			return studio
		end },
		Config = Config,
		TiempoNoche = TNcontado,
	},
})()

-- Una noche con niebla y otra sin (ni tormenta), de verdad.
local function buscar(con: boolean): number
	for k = 1, 5000 do
		local inicio = 1_700_000_000 + k * 331
		if TN.hayNiebla(5, inicio, NB, TC) == con and not TN.hayTormenta(5, inicio, TC) then
			return inicio
		end
	end
	error("buscar: ninguna")
end
local conN, sinN = buscar(true), buscar(false)
local LARGO = 600
local function noche(inicio: number, p: number, fase: string?)
	atributos.Fase = fase or "Noche"
	atributos.Noche = 5
	atributos.FaseInicio = inicio
	atributos.FaseFin = inicio + LARGO
	ahora = inicio + p * LARGO
end
noche(conN, 0.3)
comprueba(esNiebla() == true, "esNiebla: una noche de niebla, sí")
noche(conN, NB.Abre + 0.01)
comprueba(esNiebla() == false, "esNiebla: desde Niebla.Abre, ya no")
noche(conN, 0.3, "Dia")
comprueba(esNiebla() == false, "esNiebla: de día, nunca")
noche(sinN, 0.3)
comprueba(esNiebla() == false, "esNiebla: una noche sin niebla, no")
atributos.NieblaPrueba = true
comprueba(esNiebla() == false, "esNiebla: NieblaPrueba fuera de Studio, nada")
studio = true
comprueba(esNiebla() == true, "esNiebla: NieblaPrueba en Studio, sí")
atributos.TormentaPrueba = true
comprueba(esNiebla() == false, "esNiebla: con TormentaPrueba en Studio manda la tormenta")
atributos.NieblaPrueba, atributos.TormentaPrueba, studio = nil, nil, false
noche(conN, 0.1)
tiradas = 0
for _ = 1, 50 do
	esNiebla()
end
comprueba(tiradas <= 1, `esNiebla: una tirada por noche ({tiradas})`)
atributos.Noche = 6
esNiebla()
comprueba(tiradas == 2, "esNiebla: otra noche, otra tirada")

-- 5. Dónde se aplica.
local ini = string.find(caza, "function Caza.elegirPresa", 1, true)
local cuerpo = string.sub(caza, ini :: number, string.find(caza, "\nend\n", ini, true))
local a = string.find(cuerpo, "PosturaReglas.vistaDeLado(", 1, true)
local b = string.find(cuerpo, "TiempoNoche.vistaConNiebla(vista, niebla, fuera, NIEBLA_VISTA, Config.Postura.VerEspalda)", 1, true)
local c = string.find(cuerpo, "PosturaReglas.alcanceVista(vista,", 1, true)
comprueba(a and b and c and a < b and b < c, "elegirPresa: la niebla entre vistaDeLado y alcanceVista")
comprueba(string.find(cuerpo, "local niebla = Caza.esNiebla()", 1, true), "elegirPresa: mira la niebla una vez por vuelta")
comprueba(string.find(cuerpo, "Caza.dentroDeCasa(self.raiz.Position)", 1, true)
	and string.find(cuerpo, "Caza.dentroDeCasa(suCabeza.Position)", 1, true), "elegirPresa: fuera el bicho o el jugador")
comprueba(not string.find(cuerpo, "alcanceOido(OIDO *", 1, true) and not string.find(cuerpo, "OIDO * NIEBLA", 1, true),
	"elegirPresa: el oído no cambia con la niebla")
local acechador = fs.readFile("src/juego/servidor/Acechador.luau")
comprueba(string.find(acechador, "salidas(presa, r, (A.Lejos + 14) * porNiebla())", 1, true),
	"Acechador: con niebla sale más cerca")
comprueba(string.find(acechador, "local aLejos = A.Lejos * porNiebla()", 1, true), "Acechador: con niebla acecha más cerca")
comprueba(string.find(acechador, "Config.Caza.Niebla.Acechador", 1, true), "Acechador: usa Config.Caza.Niebla.Acechador")

print(`niebla-bichos: {cuentas} comprobaciones bien.`)
