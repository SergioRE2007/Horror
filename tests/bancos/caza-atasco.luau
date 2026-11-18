-- Banco de los atascos y de Persigue en Caza (docs/sistemas/bichos.md, Caminos). Ejecutar desde la raíz:
-- lune run tests/bancos/caza-atasco.luau (lo corre tests/regressions.luau).
--   atascado: rondando o yendo a un ruido, si en Config.Caza.Parada s no se acerca ni se mueve, se ha atascado; andando
--   (aunque sea dando un rodeo), acercándose o con un destino nuevo, no.
--   otraSala (la de CazaBusqueda, que usa Caza también al atascarse): nunca la sala de ahora, y salen todas las demás.
--   publicarPresa: el atributo Persigue con el UserId de la presa, nil sin ella, solo si cambia, y nunca en el Imitador
--   mientras finge (sin Abierto).
-- Sacadas del texto: Caza necesita Roblox (Casa, Mapa, Muerte...). Si algo no se cumple, termina con error.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local V3 = roblox.Vector3

local cuentas = 0
local function comprueba(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end

local fuente = fs.readFile("src/juego/servidor/Caza.luau")
local function trozo(desde: string, hasta: string): string
	local i = string.find(fuente, desde, 1, true)
	assert(i, `no encuentro {desde}`)
	local f = string.find(fuente, hasta, i, true)
	assert(f, `no encuentro {hasta}`)
	return string.sub(fuente, i, f - 1)
end

local PARADA, SORDO = 2, 3
do -- Los números de Config.Caza, leídos del texto (Config necesita Roblox).
	local config = fs.readFile("src/shared/Config.luau")
	local bloque = string.match(config, "Config%.Caza = (%b{})")
	assert(bloque, "no encuentro Config.Caza")
	PARADA = tonumber(string.match(bloque, "Parada = ([%d%.]+)")) :: number
	SORDO = tonumber(string.match(bloque, "SordoTrasParada = ([%d%.]+)")) :: number
	comprueba(PARADA > 0.5 and PARADA < 6, "Config.Caza.Parada razonable")
	comprueba(SORDO >= 1 and SORDO < 15, "Config.Caza.SordoTrasParada razonable")
	-- Justo después de Config.Director (pedido en la tarea: no al final ni junto a Config.Postura).
	local d = string.find(config, "Config.Director = {", 1, true)
	local c = string.find(config, "Config.Caza = {", 1, true)
	local siguiente = string.find(config, "\nConfig%.", d + 1)
	comprueba(d and c and c > d and string.find(config, "\nConfig%.", siguiente + 1) > c, "Config.Caza tras Config.Director")
end

local reloj = 0
local salas = { V3.new(10, 0, 0), V3.new(20, 0, 0), V3.new(30, 0, 0), V3.new(40, 0, 0) }
math.randomseed(7)
local azar = { NextInteger = function(_, a: number, b: number): number
	return math.random(a, b)
end }
local trozos = "local Caza = {}\n"
	.. "local PARADA, SORDO = ...\n"
	.. "local function plano(v) return Vector3.new(v.X, 0, v.Z) end\n"
	.. trozo("local function publicarPresa(", "function Caza.quitar(")
	.. trozo("local function atascado(", "-- Búsqueda al perder de vista")
	.. "return { atascado = atascado, publicarPresa = publicarPresa }"
local C = luau.load(trozos, {
	debugName = "Caza.atascos",
	environment = {
		Vector3 = V3,
		Mapa = { salas = salas },
		azar = azar,
		os = { clock = function()
			return reloj
		end },
		math = math,
	},
})(PARADA, SORDO)
local CB = luau.load(fs.readFile("src/juego/servidor/CazaBusqueda.luau"), {
	debugName = "CazaBusqueda",
	environment = { Vector3 = V3 },
})()

-- Un bicho de mentira: dónde está y lo deprisa que va.
local bicho: any = { raiz = { Position = V3.new(0, 3, 0), AssemblyLinearVelocity = V3.zero }, parado = nil }
function bicho.suelo(self)
	return self.raiz.Position - V3.new(0, 3, 0)
end
local function paso(destino: any, mover: any): boolean
	if mover then
		bicho.raiz.Position += mover
		bicho.raiz.AssemblyLinearVelocity = mover * 4
	else
		bicho.raiz.AssemblyLinearVelocity = V3.zero
	end
	local r = C.atascado(bicho, destino)
	reloj += 0.25
	return r
end
local function pasos(n: number, destino: any, mover: any): boolean
	local alguno = false
	for _ = 1, n do
		alguno = paso(destino, mover) or alguno
	end
	return alguno
end

-- Empujando la pared: quieto y sin acercarse. A los PARADA s, atascado (una vez: luego empieza de cero).
local destino = V3.new(0, 0, -30)
local vueltas = math.ceil(PARADA / 0.25)
comprueba(not pasos(vueltas - 1, destino), "atasco: antes de Parada s, aún no")
local cuando = nil
for i = 1, 4 do
	if paso(destino) then
		cuando = i
		break
	end
end
comprueba(cuando ~= nil, "atasco: quieto contra la pared, atascado a los Parada s")
comprueba(bicho.parado == nil, "atasco: al atascarse empieza de cero")
comprueba(not paso(destino), "atasco: justo después, no otra vez")

-- Andando hacia el destino: nunca.
bicho.parado = nil
comprueba(not pasos(40, V3.new(0, 0, -300), V3.new(0, 0, -1.5)), "atasco: andando hacia él, nunca")
-- Dando un rodeo (se aleja pero se mueve): nunca.
bicho.parado = nil
comprueba(not pasos(40, V3.new(0, 0, -300), V3.new(1.5, 0, 0.5)), "atasco: dando un rodeo, nunca")
-- Se desliza muy poco (menos de 1 stud en Parada s) y va parado: atascado.
bicho.parado = nil
comprueba(pasos(vueltas + 4, destino, V3.new(0.02, 0, 0)), "atasco: casi sin moverse, atascado")
-- Va parado poco rato y luego sigue: no.
bicho.parado = nil
pasos(vueltas - 2, destino)
comprueba(not pasos(10, destino, V3.new(0, 0, -1.5)), "atasco: un momento parado y sigue, no")
-- Cambiando de destino antes de Parada s (otra sala, otro ruido): empieza de cero.
bicho.parado = nil
pasos(vueltas - 2, destino)
comprueba(not pasos(vueltas - 2, V3.new(50, 0, 50)), "atasco: un destino nuevo empieza de cero")
-- En el sitio pero con velocidad (resbala contra algo que cede): no.
bicho.parado = nil
for _ = 1, vueltas + 2 do
	bicho.raiz.AssemblyLinearVelocity = V3.new(3, 0, 0)
	comprueba(not C.atascado(bicho, destino), "atasco: con velocidad, no")
	reloj += 0.25
end

-- otraSala: nunca la de ahora; salen todas las demás; sin sala de ahora, cualquiera.
for _, ahora in salas do
	local vistas = {}
	for _ = 1, 200 do
		local s = CB.otraSala(salas, ahora, azar)
		comprueba(s ~= ahora, "otraSala: nunca la de ahora")
		vistas[s] = true
	end
	local n = 0
	for _ in vistas do
		n += 1
	end
	comprueba(n == #salas - 1, "otraSala: salen todas las demás")
end
comprueba(table.find(salas, CB.otraSala(salas, nil, azar)) ~= nil, "otraSala: sin sala de ahora, una cualquiera")

-- publicarPresa: Persigue con el UserId, nil sin presa, solo si cambia; el Imitador fingiendo, nunca.
local function modelo(nombre: string): any
	local m = { Name = nombre, atributos = {}, escritos = 0 }
	function m.GetAttribute(self, k)
		return self.atributos[k]
	end
	function m.SetAttribute(self, k, v)
		self.atributos[k] = v
		self.escritos += 1
	end
	return m
end
local presa = { UserId = 1234 }
local golpeador = modelo("Golpeador")
local b = { modelo = golpeador }
C.publicarPresa(b, presa)
comprueba(golpeador.atributos.Persigue == 1234, "Persigue: el UserId de la presa")
C.publicarPresa(b, presa)
C.publicarPresa(b, presa)
comprueba(golpeador.escritos == 1, "Persigue: solo se escribe si cambia")
C.publicarPresa(b, nil)
comprueba(golpeador.atributos.Persigue == nil and golpeador.escritos == 2, "Persigue: sin presa, nil")
C.publicarPresa(b, nil)
comprueba(golpeador.escritos == 2, "Persigue: nil otra vez no escribe")
local imitador = modelo("Imitador")
local bi = { modelo = imitador }
C.publicarPresa(bi, presa)
comprueba(imitador.atributos.Persigue == nil and imitador.escritos == 0, "Persigue: el Imitador fingiendo, nunca")
imitador.atributos.Abierto = true
C.publicarPresa(bi, presa)
comprueba(imitador.atributos.Persigue == 1234, "Persigue: el Imitador ya abierto, sí")
C.publicarPresa({ modelo = nil }, presa) -- quitado: no rompe

-- Y que Caza.cazar lo use: tras elegirPresa, al salir y en Caza.quitar; el oído, saltado mientras está sordo.
local cazar = trozo("function Caza.cazar(", "\nlocal function olvidar(")
local i1 = string.find(cazar, "self:elegirPresa(soloFuera)", 1, true)
local i2 = string.find(cazar, "publicarPresa(self, presa)", 1, true)
comprueba(i1 and i2 and i2 > i1, "cazar: publica la presa justo tras elegirla")
comprueba(string.find(cazar, "publicarPresa(self, nil)\nend", 1, true) ~= nil, "cazar: al salir, sin presa")
comprueba(string.find(cazar, "os.clock() >= self.sordoHasta", 1, true) ~= nil, "cazar: sordo tras atascarse")
comprueba(not string.find(cazar, "\t\t\treturn -- en el bosque", 1, true), "cazar: en el bosque sale por el final")
comprueba(string.find(trozo("function Caza.quitar(", "function Caza.cabeza("), "publicarPresa(self, nil)", 1, true) ~= nil,
	"quitar: sin presa")

print(`caza-atasco: {cuentas} comprobaciones bien`)
