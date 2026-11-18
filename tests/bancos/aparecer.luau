-- Banco de aparecer y perderse sin verse (docs/sistemas/bichos.md, Llegar e irse). Ejecutar desde la raíz:
-- lune run tests/bancos/aparecer.luau (lo corre tests/regressions.luau).
--   Caza.sitioSinVer: el primer sitio que nadie vivo ve (las paredes tapan, los cristales no, de lejos no se distingue,
--   la cabeza asoma tras lo bajo); si se ven todos, el más apartado del vivo más cercano (a igualdad, el primero).
--   Caza.cabe y Caza.llegadas: sin sitio dentro de un tronco; si no cabe en ninguno, el de siempre.
--   Acechador (salidas): nunca entre la presa y la casa ni delante de ella (su cono), primero a su espalda, a
--   A.Lejos + 14, y nunca sobre un tejado ni dentro de un tronco.
-- Con un mundo de cajas de mentira (rayos y solapes). Sacadas del texto: Caza y Acechador necesitan Roblox.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local V3, CF = roblox.Vector3, roblox.CFrame

local cuentas = 0
local function comprueba(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end

local function trozo(fuente: string, desde: string, hasta: string): string
	local i = string.find(fuente, desde, 1, true)
	assert(i, `no encuentro {desde}`)
	local f = string.find(fuente, hasta, i, true)
	assert(f, `no encuentro {hasta}`)
	return string.sub(fuente, i, f - 1)
end
local function numero(texto: string, patron: string): number
	local n = tonumber(string.match(texto, patron))
	assert(n, `no encuentro {patron}`)
	return n :: number
end

-- Los números, leídos del texto (Config necesita Roblox).
local config = fs.readFile("src/shared/Config.luau")
local bloqueCaza = string.match(config, "Config%.Caza = (%b{})") :: string
local bloqueAcechador = string.match(config, "Config%.Acechador = (%b{})") :: string
assert(bloqueCaza and bloqueAcechador, "no encuentro Config.Caza o Config.Acechador")
local VER_LEJOS = numero(bloqueCaza, "VerLejos = ([%d%.]+)")
local CANDIDATOS = numero(bloqueCaza, "Candidatos = ([%d%.]+)")
local PERDERSE = numero(bloqueCaza, "PerderseMax = ([%d%.]+)")
local A = {
	Lejos = numero(bloqueAcechador, "Lejos = ([%d%.]+)"),
	Cono = numero(bloqueAcechador, "Cono = ([%d%.]+)"),
}
comprueba(CANDIDATOS >= 3 and CANDIDATOS <= 12, "Config.Caza.Candidatos razonable")
comprueba(PERDERSE >= 4 and PERDERSE <= 30, "Config.Caza.PerderseMax razonable")
comprueba(A.Cono >= 50 and A.Cono < 90, "Config.Acechador.Cono razonable")

local caza = fs.readFile("src/juego/servidor/Caza.luau")
local acechador = fs.readFile("src/juego/servidor/Acechador.luau")
local CABEZA = numero(caza, "local CABEZA = ([%d%.]+)")
local ANCHO = numero(caza, "local ANCHO_CUERPO = ([%d%.]+)")
local EMPATE = numero(caza, "local EMPATE = ([%d%.]+)")

-- El mundo: cajas { min, max, t (Transparency), choca (CanCollide) }. Un rayo no ve la caja de la que sale (como en
-- Roblox) y, con RespectCanCollide, tampoco las que no chocan.
local cajas: { any } = {}
local function caja(a: any, b: any, t: number?, choca: boolean?)
	table.insert(cajas, { min = a, max = b, t = t or 0, choca = choca ~= false })
end
local function dentro(c: any, p: any): boolean
	return p.X > c.min.X and p.X < c.max.X and p.Y > c.min.Y and p.Y < c.max.Y and p.Z > c.min.Z and p.Z < c.max.Z
end
local rayos = 0
local mundo = {}
function mundo.Raycast(_, origen: any, dir: any, params: any): any
	rayos += 1
	local mejor, golpe = math.huge, nil
	for _, c in cajas do
		if dentro(c, origen) or (params.RespectCanCollide and not c.choca) then
			continue
		end
		local t0, t1 = 0, 1
		local fuera = false
		for _, eje in { "X", "Y", "Z" } do
			local o, d, lo, hi = origen[eje], dir[eje], c.min[eje], c.max[eje]
			if math.abs(d) < 1e-9 then
				if o < lo or o > hi then
					fuera = true
				end
			else
				local a, b = (lo - o) / d, (hi - o) / d
				if a > b then
					a, b = b, a
				end
				t0, t1 = math.max(t0, a), math.min(t1, b)
			end
		end
		if not fuera and t0 <= t1 and t0 < mejor then
			mejor, golpe = t0, c
		end
	end
	return if golpe then { Position = origen + dir * mejor, Instance = { Transparency = golpe.t } } else nil
end
function mundo.GetPartBoundsInBox(_, cf: any, tam: any, params: any): { any }
	local p, m = cf.Position, tam / 2
	local lista = {}
	for _, c in cajas do
		if (not params.RespectCanCollide or c.choca) and p.X - m.X < c.max.X and p.X + m.X > c.min.X
			and p.Y - m.Y < c.max.Y and p.Y + m.Y > c.min.Y and p.Z - m.Z < c.max.Z and p.Z + m.Z > c.min.Z then
			table.insert(lista, c)
		end
	end
	return lista
end

-- Los jugadores de mentira: dónde tienen la cabeza, hacia dónde miran y si están vivos.
local jugadores: { any } = {}
local function jugador(cabeza: any, mira: any?, vivo: boolean?): any
	local mirando = CF.lookAt(cabeza, cabeza + (mira or V3.new(1, 0, 0)))
	local j: any = { vivo = vivo ~= false, cabeza = { Position = cabeza, CFrame = mirando } }
	local raiz = { Position = cabeza - V3.new(0, 1.5, 0), CFrame = mirando - V3.new(0, 1.5, 0) }
	j.raiz = raiz
	j.Character = { FindFirstChild = function(_, nombre: string): any
		return if nombre == "Head" then j.cabeza elseif nombre == "HumanoidRootPart" then raiz else nil
	end }
	table.insert(jugadores, j)
	return j
end
local Players = { GetPlayers = function()
	return jugadores
end }
local function nuevoMundo()
	table.clear(cajas)
	table.clear(jugadores)
	caja(V3.new(-1000, -2, -1000), V3.new(1000, 0, 1000)) -- el suelo
end

math.randomseed(11)
local fijo = false -- true: el azar siempre a la mitad (sin giros de azar en el Acechador)
local azar = { NextNumber = function(_, a: number?, b: number?): number
	local lo, hi = a or 0, b or 1
	return lo + (if fijo then 0.5 else math.random()) * (hi - lo)
end }
local function params(): any
	return { new = function()
		return {}
	end }
end
local entorno: { [string]: any } = {
	Vector3 = V3,
	CFrame = CF,
	RaycastParams = params(),
	OverlapParams = params(),
	Enum = { RaycastFilterType = { Exclude = "Exclude" } },
	workspace = mundo,
	Players = Players,
	Muerte = { vivo = function(j: any): boolean
		return j.vivo
	end },
	cabezaDe = function(j: any): any
		return j.cabeza
	end,
	sinPersonajes = function(): { any }
		return {}
	end,
	azar = azar,
	math = math,
	table = table,
}
local C = luau.load("local Caza = {}\nlocal VER_LEJOS, CABEZA, ANCHO_CUERPO, EMPATE, CANDIDATOS = ...\n"
	.. trozo(caza, "local filtroVer = RaycastParams.new()", "-- Anda hasta `destino` como irA y, si no llega")
	.. "return Caza", { debugName = "Caza.sitioSinVer", environment = entorno })(VER_LEJOS, CABEZA, ANCHO, EMPATE, CANDIDATOS)
comprueba(type(C.sitioSinVer) == "function" and type(C.cabe) == "function" and type(C.llegadas) == "function"
	and type(C.nadieVe) == "function", "Caza: sitioSinVer, cabe, llegadas y nadieVe")

local ALTO = 5 -- un Golpeador: de los pies al centro de la raíz
local cerca, tras, lejos = V3.new(40, 0, 0), V3.new(0, 0, 40), V3.new(0, 0, -60)

do -- Sin nadie vivo (o nadie mirando): el primero de la lista.
	nuevoMundo()
	local sitio, oculto = C.sitioSinVer({ cerca, tras }, ALTO)
	comprueba(sitio == cerca and oculto, "sin jugadores: el primero")
	jugador(V3.new(0, 4.5, 0), nil, false)
	sitio, oculto = C.sitioSinVer({ cerca, tras }, ALTO)
	comprueba(sitio == cerca and oculto, "un muerto no ve")
end

do -- Una pared tapa: sale el de detrás aunque esté más cerca de él.
	nuevoMundo()
	jugador(V3.new(0, 4.5, 0))
	caja(V3.new(-10, 0, 20), V3.new(10, 30, 21)) -- una pared entre él y `tras`
	local sitio, oculto = C.sitioSinVer({ cerca, tras, lejos }, ALTO)
	comprueba(sitio == tras and oculto, "la pared tapa: el de detrás de la pared")
	-- La misma pared, de cristal: no tapa (los ve todos) y sale el más apartado.
	cajas[2].t = 0.6
	sitio, oculto = C.sitioSinVer({ cerca, tras, lejos }, ALTO)
	comprueba(sitio == lejos and not oculto, "el cristal no tapa: si se ven todos, el más apartado")
end

do -- Lo bajo no tapa la cabeza; lo alto, sí.
	nuevoMundo()
	jugador(V3.new(0, 4.5, 0))
	caja(V3.new(-10, 0, 20), V3.new(10, ALTO + 1, 21)) -- tapa la raíz, no la cabeza
	local sitio, oculto = C.sitioSinVer({ tras, lejos }, ALTO)
	comprueba(not oculto and sitio == lejos, "tras una mata baja se le ve la cabeza")
	cajas[2].max = V3.new(10, ALTO * CABEZA + 2, 21)
	sitio, oculto = C.sitioSinVer({ lejos, tras }, ALTO)
	comprueba(oculto and sitio == tras, "tras algo más alto que él, oculto")
end

do -- De lejos no se distingue; a igualdad, el primero; cuenta el vivo más cercano.
	nuevoMundo()
	jugador(V3.new(0, 4.5, 0))
	local muyLejos = V3.new(VER_LEJOS + 20, 0, 0)
	local sitio, oculto = C.sitioSinVer({ cerca, muyLejos }, ALTO)
	comprueba(sitio == muyLejos and oculto, "a más de VerLejos no se ve")
	local a, b = V3.new(50, 0, 0), V3.new(-50, 0, 0.5)
	sitio = C.sitioSinVer({ a, b }, ALTO)
	comprueba(sitio == a, "a igualdad, el primero")
	jugador(V3.new(-45, 4.5, 0)) -- otro, pegado a `b`
	sitio = C.sitioSinVer({ b, a }, ALTO)
	comprueba(sitio == a, "si se ven todos, lejos del vivo más cercano (cualquiera)")
end

do -- cabe y llegadas: nunca dentro de un tronco; si no cabe en ninguno, el de siempre.
	nuevoMundo()
	caja(V3.new(-2, 0, -2), V3.new(2, 80, 2)) -- un tronco en el origen
	caja(V3.new(18, 0, -2), V3.new(22, 80, 2), 0, false) -- algo que no choca (una copa baja)
	comprueba(not C.cabe(V3.new(0, 0, 0), ALTO), "cabe: no dentro de un tronco")
	comprueba(not C.cabe(V3.new(ANCHO / 2 + 1, 0, 0), ALTO), "cabe: no pegado al tronco")
	comprueba(C.cabe(V3.new(20, 0, 0), ALTO), "cabe: lo que no choca no estorba")
	comprueba(C.cabe(V3.new(40, 0, 0), ALTO), "cabe: en el claro, sí")
	local fuera, normal, lado = V3.new(0, 0, -100), V3.new(0, 0, -1), V3.new(1, 0, 0)
	local primero = fuera + normal * 75
	local lista = C.llegadas(primero, fuera, normal, lado, ALTO)
	comprueba(#lista == CANDIDATOS and lista[1] == primero, "llegadas: el de siempre primero y CANDIDATOS en total")
	local izquierda, derecha = 0, 0
	for i = 2, #lista do
		local d = lista[i] - fuera
		local hondo, ancho = d:Dot(normal), math.abs(d:Dot(lado))
		comprueba(hondo >= 90 and hondo <= 100 and ancho >= 25 and ancho <= 40, "llegadas: más hondo y a un lado")
		if d:Dot(lado) > 0 then
			derecha += 1
		else
			izquierda += 1
		end
	end
	comprueba(izquierda > 0 and derecha > 0, "llegadas: a los dos lados")
	caja(primero - V3.new(2, 0, 2), primero + V3.new(2, 50, 2)) -- un tronco justo en el de siempre
	lista = C.llegadas(primero, fuera, normal, lado, ALTO)
	comprueba(#lista == CANDIDATOS - 1 and not table.find(lista, primero), "llegadas: sin el del tronco")
	caja(V3.new(-1000, 0, -300), V3.new(1000, 50, -150)) -- todo lleno
	lista = C.llegadas(primero, fuera, normal, lado, ALTO)
	comprueba(#lista == 1 and lista[1] == primero, "llegadas: si no cabe en ninguno, el de siempre")
end

-- El Acechador: de dónde sale (suelo y salidas, sacadas del texto) con el sitioSinVer de arriba.
local ALTURA_A = numero(acechador, "local ALTURA = ([%d%.]+)")
local entornoA: { [string]: any } = table.clone(entorno)
entornoA.Caza = { carpeta = function()
	return {}
end, cabe = C.cabe }
entornoA.A = A
entornoA.ALTURA = ALTURA_A
entornoA.plano = function(v: any): any
	return V3.new(v.X, 0, v.Z)
end
local S = luau.load(trozo(acechador, "local filtro = RaycastParams.new()", "local function ataque(")
	.. "return { suelo = suelo, salidas = salidas }", { debugName = "Acechador.salidas", environment = entornoA })()

local DIST = A.Lejos + 14
local cono = math.cos(math.rad(A.Cono))
local function revisar(j: any, sitios: { any }, etiqueta: string)
	local r = j.raiz.Position
	local afuera = V3.new(r.X, 0, r.Z).Unit
	local mira = V3.new(j.cabeza.CFrame.LookVector.X, 0, j.cabeza.CFrame.LookVector.Z).Unit
	comprueba(#sitios > 0, `{etiqueta}: tiene sitio`)
	for i, s in sitios do
		local d = V3.new(s.X - r.X, 0, s.Z - r.Z)
		comprueba(math.abs(d.Magnitude - DIST) < 0.01, `{etiqueta}: a A.Lejos + 14`)
		comprueba(d.Unit:Dot(afuera) >= -1e-6, `{etiqueta}: nunca entre la presa y la casa`)
		comprueba(d.Unit:Dot(mira) < cono, `{etiqueta}: nunca en su cono`)
		comprueba(math.abs(s.Y) < 0.01, `{etiqueta}: en el suelo`)
		for k, otro in sitios do
			comprueba(k == i or (otro - s).Magnitude > 1, `{etiqueta}: sin sitios repetidos`)
		end
	end
end

for vuelta = 1, 20 do -- Hacia fuera, hacia la casa y de lado, en varias direcciones desde la casa.
	nuevoMundo()
	local ang = vuelta * 0.7
	local afuera = V3.new(math.cos(ang), 0, math.sin(ang))
	local pos = afuera * 120 + V3.new(0, 4.5, 0)
	local giro = CF.Angles(0, (vuelta % 4) * math.pi / 2, 0)
	local j = jugador(pos, giro:VectorToWorldSpace(afuera))
	revisar(j, S.salidas(j, j.raiz), `vuelta {vuelta}`)
end

do -- Volviendo a la casa: sale justo a su espalda (del lado de fuera) y, si se ve, sitioSinVer se queda con ese.
	nuevoMundo()
	fijo = true
	local j = jugador(V3.new(120, 4.5, 0), V3.new(-1, 0, 0))
	local sitios = S.salidas(j, j.raiz)
	local d = (sitios[1] - V3.new(120, 0, 0)).Unit
	comprueba(d:Dot(V3.new(1, 0, 0)) > 0.95, "volviendo a casa: el primero, a su espalda")
	comprueba(C.sitioSinVer(sitios, ALTURA_A) == sitios[1], "a la vista todos: el de su espalda")
	-- Un tronco a su espalda: ese no; y un tejado (a 14 studs) en otro, tampoco.
	local espalda = V3.new(120 + DIST, 0, 0)
	caja(espalda - V3.new(2, 0, 2), espalda + V3.new(2, 80, 2))
	local otro = sitios[2]
	caja(otro - V3.new(6, 0, 6) + V3.new(0, 13, 0), otro + V3.new(6, 14, 6))
	local quedan = S.salidas(j, j.raiz)
	for _, s in quedan do
		comprueba((V3.new(s.X, 0, s.Z) - espalda).Magnitude > ANCHO, "no sale dentro de un tronco")
		comprueba((V3.new(s.X, 0, s.Z) - V3.new(otro.X, 0, otro.Z)).Magnitude > 6, "no sale bajo ni sobre un tejado")
		comprueba(s.Y < 3, "no sale encima de nada")
	end
	comprueba(#quedan > 0 and #quedan == #sitios - 2, "quedan los otros sitios")
	fijo = false
end

do -- Una copa que no choca encima: sale en el suelo, debajo (antes caía en lo alto).
	nuevoMundo()
	local j = jugador(V3.new(0, 4.5, 120), V3.new(0, 0, -1))
	local p = S.suelo(V3.new(0, 3, 120 + DIST), 0)
	comprueba(p and math.abs(p.Y) < 0.01, "suelo: en el suelo, al aire libre")
	caja(V3.new(-6, 9, 120 + DIST - 6), V3.new(6, 20, 120 + DIST + 6), 0, false) -- la copa
	p = S.suelo(V3.new(0, 3, 120 + DIST), 0)
	comprueba(p and math.abs(p.Y) < 0.01, "suelo: bajo una copa, en el suelo")
	caja(V3.new(-3, 0, 120 + DIST - 3), V3.new(3, 2, 120 + DIST + 3)) -- una roca baja
	p = S.suelo(V3.new(0, 3, 120 + DIST), 0)
	comprueba(p and math.abs(p.Y - 2) < 0.01, "suelo: sobre una roca baja, vale")
	caja(V3.new(-3, 2, 120 + DIST - 3), V3.new(3, 5, 120 + DIST + 3)) -- más alta: más de 3 studs sobre sus pies
	p = S.suelo(V3.new(0, 3, 120 + DIST), 0)
	comprueba(p == nil, "suelo: sobre algo alto, no")
	comprueba(#S.salidas(j, j.raiz) > 0, "salidas: hay más sitios")
end

do -- En el texto: los cuatro que atacan llegan desde sitioSinVer y se van con perderse; el Acechador también.
	for _, nombre in { "Golpeador", "Raspador", "Imitador", "Trepador" } do
		local fuente = fs.readFile(`src/juego/servidor/{nombre}.luau`)
		comprueba(string.find(fuente, "local inicio = Caza.sitioSinVer(Caza.llegadas(", 1, true), `{nombre}: inicio sin verse`)
		comprueba(string.find(fuente, "b:perderse(lejos,", 1, true), `{nombre}: se pierde`)
		comprueba(not string.find(fuente, "b:irA(lejos", 1, true), `{nombre}: sin irA a pelo al irse`)
	end
	comprueba(string.find(acechador, "b:perderse(", 1, true), "Acechador: se pierde al rendirse")
	comprueba(not string.find(acechador, "b:irA(", 1, true), "Acechador: sin irA a pelo")
	comprueba(string.find(acechador, "filtro.RespectCanCollide = true", 1, true), "Acechador: suelo solo con lo que choca")
	comprueba(not string.find(acechador, "120, p.Z", 1, true), "Acechador: suelo sin tirar desde lo alto")
	comprueba(string.find(acechador, "Caza.sitioSinVer(sitios, ALTURA)", 1, true), "Acechador: sale donde no se ve")
	local perderse = trozo(caza, "function Caza.perderse(", "\nend\n")
	comprueba(string.find(perderse, "self:irA(lejos, velocidad, limite)", 1, true), "perderse: el irA de siempre")
	comprueba(string.find(perderse, "PERDERSE_MAX", 1, true) and string.find(perderse, "seVeCuerpo(", 1, true),
		"perderse: sigue mientras le vean, PerderseMax como mucho")
end

comprueba(rayos > 0, "se han tirado rayos")
print(`aparecer: {cuentas} comprobaciones bien`)
