-- Banco de la búsqueda de los bichos al perderte de vista y de pillar sin paredes en medio. Ejecutar desde la raíz:
-- lune run tests/bancos/caza-busqueda.luau (lo corre tests/regressions.luau).
--   servidor/CazaBusqueda de verdad (pura, con el Vector3 de Lune) y Config.Caza.Busca:
--     rumbo: hacia dónde iba en planta, solo si va deprisa; vigente: el rastro caduca a los Busca.Memoria s;
--     avance: se para Busca.Margen antes de la pared y nunca va hacia atrás;
--     salasCerca: las más cerca de su misma planta, en orden, sin la que ya está y sin pasar de n;
--     otraSala: la ronda al azar nunca repite la sala de la que viene; mirada: de frente, a un lado y a otro.
--   En el texto: la Bestia, el Acechador y Caza.cazar pillan con Caza.alcanza (rayo), no solo por distancia, y la ronda
--   elige con otraSala.
-- Si algo no se cumple, termina con error.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local V3 = roblox.Vector3

local cuentas = 0
local function comprueba(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end
local function casi(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

local Config = luau.load(fs.readFile("src/shared/Config.luau"), { debugName = "Config" })()
local B = Config.Caza and Config.Caza.Busca
comprueba(type(B) == "table", "Config.Caza.Busca existe")
for _, nombre in { "Memoria", "Adelante", "Margen", "Mirar", "Giro", "Salas", "Planta", "Limite", "Rumbo" } do
	comprueba(type(B[nombre]) == "number" and B[nombre] > 0, `Config.Caza.Busca.{nombre} es un número positivo`)
end
comprueba(B.Margen < B.Adelante, "el margen es menor que lo que avanza")
comprueba(type(Config.Acechador.MasPillar) == "number", "Config.Acechador.MasPillar")

local CB = luau.load(fs.readFile("src/juego/servidor/CazaBusqueda.luau"), {
	debugName = "CazaBusqueda",
	environment = { Vector3 = V3 },
})()

-- rumbo
comprueba(CB.rumbo(V3.new(0.5, 9, 1), B.Rumbo) == nil, "rumbo: parado (o cayendo) no apunta")
local r = CB.rumbo(V3.new(10, -3, 0), B.Rumbo)
comprueba(r and casi(r.X, 1) and casi(r.Y, 0) and casi(r.Z, 0), "rumbo: en planta y unitario")

-- vigente
comprueba(not CB.vigente(nil, 10, B.Memoria), "vigente: sin rastro, no")
comprueba(CB.vigente({ punto = V3.zero, hora = 10 }, 10 + B.Memoria - 0.1, B.Memoria), "vigente: reciente, sí")
comprueba(not CB.vigente({ punto = V3.zero, hora = 10 }, 10 + B.Memoria + 0.1, B.Memoria), "vigente: viejo, no")

-- avance
comprueba(CB.avance(B.Adelante, nil, B.Margen) == B.Adelante, "avance: sin pared, todo")
comprueba(casi(CB.avance(B.Adelante, 5, B.Margen), 5 - B.Margen), "avance: se para antes de la pared")
comprueba(CB.avance(B.Adelante, 1, B.Margen) == 0, "avance: pared pegada, no se mueve (no empuja)")
comprueba(CB.avance(B.Adelante, 100, B.Margen) == B.Adelante, "avance: pared lejos, lo de siempre")

-- salasCerca
local salas = {
	V3.new(0, 1, -26), V3.new(0, 1, 4.5), V3.new(0, 1, 22), V3.new(25, 1, -15), V3.new(28, 1, 12),
	V3.new(0, 14, 18), V3.new(25, 14, -14), V3.new(-25, 14, 21),
}
local cerca = CB.salasCerca(salas, V3.new(1, 1, 6), 2, B.Planta, 4)
comprueba(#cerca == 2, "salasCerca: como mucho n")
comprueba(cerca[1] == salas[3] and cerca[2] == salas[5], "salasCerca: sin la que ya está, de la más cerca a la más lejos")
local arriba = CB.salasCerca(salas, V3.new(0, 14, 17), 5, B.Planta, 0)
comprueba(#arriba == 3, "salasCerca: solo las de su planta")
for _, s in arriba do
	comprueba(s.Y == 14, "salasCerca: ninguna de la otra planta")
end
comprueba(#CB.salasCerca({}, V3.zero, 2, B.Planta, 4) == 0, "salasCerca: sin salas, nada")

-- otraSala, con un azar que da lo que se le pide (el primero o el último que deja elegir)
local function azarFijo(cual: string)
	return {
		NextInteger = function(_, a: number, b: number): number
			return if cual == "primero" then a else b
		end,
	}
end
for i, sala in salas do
	for _, cual in { "primero", "ultimo" } do
		comprueba(CB.otraSala(salas, sala, azarFijo(cual)) ~= sala, `otraSala: no repite la sala {i} ({cual})`)
	end
end
comprueba(CB.otraSala(salas, salas[1], azarFijo("primero")) == salas[2], "otraSala: salta la que evita")
comprueba(CB.otraSala(salas, salas[#salas], azarFijo("ultimo")) == salas[#salas - 1], "otraSala: y la última")
comprueba(CB.otraSala(salas, nil, azarFijo("ultimo")) == salas[#salas], "otraSala: sin sala de antes, cualquiera")
comprueba(CB.otraSala({ salas[1] }, salas[1], azarFijo("primero")) == salas[1], "otraSala: con una sola, esa")
-- Todas salen alguna vez con un azar de verdad (no se queda siempre en la misma).
local vistas = {}
local semilla = 7
local azarCutre = {
	NextInteger = function(_, a: number, b: number): number
		semilla = (semilla * 1103515245 + 12345) % 2147483648
		return a + semilla % (b - a + 1)
	end,
}
local antes = salas[1]
for _ = 1, 400 do
	local s = CB.otraSala(salas, antes, azarCutre)
	comprueba(s ~= antes, "otraSala: nunca dos veces seguidas")
	vistas[s] = true
	antes = s
end
local n = 0
for _ in vistas do
	n += 1
end
comprueba(n == #salas, "otraSala: salen todas")

-- mirada
local frente = V3.new(0, 0, -1)
local m0 = CB.mirada(frente, 0, B.Mirar, B.Giro)
comprueba(casi(m0.X, 0) and casi(m0.Z, -1), "mirada: empieza de frente")
local m1 = CB.mirada(frente, B.Mirar / 4, B.Mirar, B.Giro)
local m3 = CB.mirada(frente, B.Mirar * 3 / 4, B.Mirar, B.Giro)
comprueba(casi(m1:Dot(frente), math.cos(math.rad(B.Giro))), "mirada: gira Giro grados a un lado")
comprueba(m1.X * m3.X < 0, "mirada: y luego al otro")
comprueba(casi(m1.Magnitude, 1) and casi(m1.Y, 0), "mirada: unitaria y en planta")
local mf = CB.mirada(frente, B.Mirar, B.Mirar, B.Giro)
comprueba(mf:Dot(frente) > 0.999, "mirada: acaba de frente")
comprueba(CB.mirada(V3.zero, 0, B.Mirar, B.Giro).Magnitude > 0.99, "mirada: sin dirección no da cero")

-- En el texto: pillar con rayo.
local function quitarComentarios(t: string): string
	return (string.gsub(t, "%-%-[^\n]*", ""))
end
local bestia = quitarComentarios(fs.readFile("src/juego/servidor/Bestia.luau"))
local acechador = quitarComentarios(fs.readFile("src/juego/servidor/Acechador.luau"))
local caza = quitarComentarios(fs.readFile("src/juego/servidor/Caza.luau"))
comprueba(string.find(bestia, "b:alcanza(presa, b.o.Pillar + 1.5)", 1, true), "Bestia: pilla con Caza.alcanza")
comprueba(not string.find(bestia, "Magnitude < b.o.Pillar", 1, true), "Bestia: ya no pilla solo por distancia")
comprueba(string.find(acechador, "b:alcanza(presa, A.Pillar + A.MasPillar)", 1, true), "Acechador: pilla con Caza.alcanza")
comprueba(not string.find(acechador, "Magnitude < A.Pillar", 1, true), "Acechador: ya no pilla solo por distancia")
comprueba(string.find(caza, "self:alcanza(presa, self.o.Pillar)", 1, true), "Caza.cazar: pilla con Caza.alcanza")
comprueba(string.find(caza, "CazaBusqueda.otraSala(Mapa.salas", 1, true), "Caza.cazar: la ronda no repite sala")
comprueba(not string.find(caza, "Mapa.salas[azar:NextInteger", 1, true), "Caza.cazar: ya no elige sala a ciegas")
comprueba(string.find(caza, "planBusca(self, ultimoVisto)", 1, true), "Caza.cazar: busca al llegar a donde le vio")

print(`caza-busqueda: {cuentas} comprobaciones`)
