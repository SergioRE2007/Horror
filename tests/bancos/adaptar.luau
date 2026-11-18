-- Banco de los ojos que se acostumbran a la oscuridad (pedido por el usuario: "mejorar la inmersión"; docs/sistemas/
-- adaptar.md). Ejecutar desde la raíz: lune run tests/bancos/adaptar.luau (lo corre regressions.luau).
--   1. Las cuentas sueltas (AdaptarCuentas): juntar, punto, foco, rebote, apunta, seguir; acotadas y sin NaN.
--   2. Escenas en el tiempo con `acostumbrar` y `efecto`: apagar la linterna de noche (casi negro de golpe y en 8-12 s
--      un pelo más claro y en grises), encenderla ya acostumbrado (deslumbra y se va en 0,6-1,2 s), un relámpago corto,
--      andar de una sala a otra parecida (sin nada) y la linterna de otro a la cara (mientras apunte).
local crearMundo = require("./_roblox")

local cuentas = 0
local function comprobar(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end
local function cerca(a: number, b: number, margen: number, etiqueta: string)
	comprobar(math.abs(a - b) <= margen, `{etiqueta}: esperado {b}, sale {a}`)
end
local function numero(x: number, etiqueta: string)
	comprobar(x == x and x ~= math.huge and x ~= -math.huge, `{etiqueta}: no es un número ({x})`)
end

local m = crearMundo()
local Config = m.cargar("src/shared/Config")
local C = Config.Adaptar
local A = m.cargar("src/juego/cliente/AdaptarCuentas")
local Vector3 = m.global.Vector3
local NAN = 0 / 0

-- ===== 1. Las cuentas sueltas =====
do
	cerca(A.juntar(0), 0, 1e-9, "juntar 0")
	comprobar(A.juntar(-3) == 0 and A.juntar(NAN) == 0, "juntar negativo o NaN")
	comprobar(A.juntar(20) < 1 and A.juntar(20) > 0.99, "juntar casi llega a 1")
	local antes = -1
	for s = 0, 5, 0.1 do
		local l = A.juntar(s)
		comprobar(l > antes, "juntar crece")
		antes = l
	end

	cerca(A.punto(0, 10, 2), 2, 1e-9, "punto pegado")
	cerca(A.punto(5, 10, 2), 0.5, 1e-9, "punto a mitad")
	comprobar(A.punto(10, 10, 2) == 0 and A.punto(11, 10, 2) == 0, "punto fuera de alcance")
	comprobar(A.punto(NAN, 10, 2) == 0 and A.punto(1, 0, 2) == 0 and A.punto(1, 10, -1) == 0, "punto raro")

	local abajo = Vector3.new(0, -1, 0)
	cerca(A.foco(Vector3.new(0, -5, 0), abajo, 60), 1, 1e-9, "foco en el centro")
	comprobar(A.foco(Vector3.new(5, -0.1, 0), abajo, 60) == 0, "foco fuera del cono")
	comprobar(A.foco(Vector3.new(0, 5, 0), abajo, 60) == 0, "foco detrás")
	cerca(A.foco(Vector3.zero, abajo, 60), 1, 1e-9, "foco encima")
	local borde = A.foco(Vector3.new(math.tan(math.rad(28)), -1, 0), abajo, 60)
	comprobar(borde > 0 and borde < 1, `foco en el borde, suave ({borde})`)

	cerca(A.rebote(0), 1, 1e-9, "rebote pegado")
	comprobar(A.rebote(nil) == 0 and A.rebote(C.Luz.RebotaHasta + 1) == 0 and A.rebote(NAN) == 0, "rebote sin choque")

	-- La linterna de otro: de frente a 6 studs, sí; fuera del cono, lejos o detrás, no.
	local origen = Vector3.new(0, 5, 0)
	local hacia = Vector3.new(0, 0, -1)
	local frente = A.apunta(origen, hacia, Vector3.new(0, 5, -6))
	comprobar(frente > 0.8, `de frente deslumbra ({frente})`)
	comprobar(A.apunta(origen, hacia, Vector3.new(0, 5, -(C.Ajena.Lejos + 1))) == 0, "más lejos que Lejos no")
	local fuera = math.tan(math.rad(C.Ajena.Angulo + 1)) * 10
	comprobar(A.apunta(origen, hacia, Vector3.new(fuera, 5, -10)) == 0, "fuera del cono no")
	comprobar(A.apunta(origen, hacia, Vector3.new(0, 5, 6)) == 0, "detrás no")
	comprobar(A.apunta(origen, hacia, origen) == 0, "en el mismo sitio no")
	comprobar(A.apunta(origen, Vector3.zero, Vector3.new(0, 5, -6)) == 0, "sin dirección no")
	local medio = A.apunta(origen, hacia, Vector3.new(math.tan(math.rad(C.Ajena.Angulo / 2)) * 10, 5, -10))
	comprobar(medio > 0 and medio < A.apunta(origen, hacia, Vector3.new(0, 5, -10)), "al borde del haz, menos")
	comprobar(A.apunta(origen, hacia, Vector3.new(0, 5, -20)) < A.apunta(origen, hacia, Vector3.new(0, 5, -8)),
		"más lejos, menos")

	-- Seguir: entra deprisa, sale algo más despacio, llega justo.
	local v = 0
	for _ = 1, 60 do
		v = A.seguir(v, 1, 1 / 60)
	end
	comprobar(v > 0.99, `la linterna de otro entra en ~1 s ({v})`)
	local s = 1
	for _ = 1, 6 do
		s = A.seguir(s, 0, 1 / 60)
	end
	comprobar(s > 0.5, "sale algo más despacio")
	for _ = 1, 120 do
		s = A.seguir(s, 0, 1 / 60)
	end
	comprobar(s == 0, "y acaba en 0 justo")
	comprobar(A.seguir(NAN, NAN, NAN) == 0, "seguir con NaN")

	-- Acostumbrar sin NaN y acotado.
	numero(A.acostumbrar(NAN, 0.5, 0.1), "acostumbrar desde NaN")
	numero(A.acostumbrar(0.5, NAN, 0.1), "acostumbrar hacia NaN")
	comprobar(A.acostumbrar(0.5, 0.2, -1) == 0.5 and A.acostumbrar(0.5, 0.2, NAN) == 0.5, "acostumbrar sin tiempo")
	comprobar(A.acostumbrar(0.5, 0.2, 1000) >= 0.2, "un fotograma enorme no se pasa")

	-- Sin cambios de luz y con luz normal, nada.
	comprobar(A.nada(A.efecto(0.5, 0.5, 0)), "hecho a la luz que hay: nada")
	local e = A.efecto(NAN, NAN, NAN)
	for _, k in { "brillo", "contraste", "saturacion", "frio", "calido" } do
		numero(e[k], `efecto con NaN: {k}`)
	end
end

-- ===== 2. Escenas en el tiempo =====
local DT = 1 / 60

-- Corre `segundos` con la luz `luz(t)` desde ojos hechos a `hecho`; llama a `mirar(t, efecto, hecho)` en cada fotograma.
local function correr(hecho: number, segundos: number, luz: (number) -> number, mirar: (number, any, number) -> ())
	local t = 0
	while t < segundos do
		t += DT
		local l = luz(t)
		hecho = A.acostumbrar(hecho, l, DT)
		local e = A.efecto(hecho, l, 0)
		for _, k in { "brillo", "contraste", "saturacion", "frio", "calido" } do
			numero(e[k], `escena: {k} a {t} s`)
		end
		comprobar(e.brillo >= C.Hundido - 1e-9 and e.brillo <= C.Deslumbre.Brillo + 1e-9, "brillo acotado")
		mirar(t, e, hecho)
	end
	return hecho
end

local L = C.Luz
local NOCHE_OSCURA = A.juntar(C.Base) -- de noche, en una sala sin luz
local CON_LINTERNA = A.juntar(C.Base + L.Linterna + L.Rebote * 0.7) -- linterna a una pared cerca

-- Apagar la linterna de noche: casi negro de golpe y en 8-12 s un pelo más claro que lo normal y en grises.
do
	local primero: any = nil
	local claroA: number? = nil
	local grisA: number? = nil
	local hecho = correr(CON_LINTERNA, 14, function()
		return NOCHE_OSCURA
	end, function(t, e)
		primero = primero or e
		if not claroA and e.brillo > 0 then
			claroA = t
		end
		if not grisA and e.saturacion <= C.Acostumbrado.Saturacion * 0.95 then
			grisA = t
		end
	end)
	comprobar(primero.brillo <= C.Hundido * 0.95, `de golpe casi negro ({primero.brillo})`)
	comprobar(primero.calido == 0, "a oscuras no deslumbra")
	comprobar(claroA ~= nil and claroA > 3 and claroA < 10, `deja de estar oscuro poco a poco ({claroA})`)
	comprobar(grisA ~= nil and grisA >= 7 and grisA <= 12, `en grises a los 8-12 s ({grisA})`)
	local e = A.efecto(hecho, NOCHE_OSCURA, 0)
	cerca(e.brillo, C.Acostumbrado.Brillo, 0.01, "acostumbrado: un pelo más claro")
	cerca(e.saturacion, C.Acostumbrado.Saturacion, 0.02, "acostumbrado: en grises")
	comprobar(e.frio > 0.95, "acostumbrado: algo frío")

	-- Encender la linterna ya acostumbrado: deslumbra y se va en 0,6-1,2 s.
	local fin: number? = nil
	local maximo = 0
	correr(hecho, 3, function()
		return CON_LINTERNA
	end, function(t, e2)
		maximo = math.max(maximo, e2.calido)
		if e2.calido > 0.95 then
			comprobar(e2.brillo > C.Deslumbre.Brillo * 0.9 and e2.contraste < C.Deslumbre.Contraste * 0.9,
				"deslumbrado: blanco y contraste hundido")
		end
		if maximo > 0.95 and not fin and e2.calido <= 0.02 then
			fin = t
		end
	end)
	comprobar(maximo > 0.95, `encender la linterna acostumbrado deslumbra entero ({maximo})`)
	comprobar(fin ~= nil and fin >= 0.6 and fin <= 1.2, `el deslumbre se va en 0,6-1,2 s ({fin})`)
end

-- Encenderla sin estar acostumbrado (apagar y encender enseguida): casi nada.
do
	local hecho = correr(CON_LINTERNA, 0.4, function()
		return NOCHE_OSCURA
	end, function() end)
	local maximo = 0
	correr(hecho, 2, function()
		return CON_LINTERNA
	end, function(_, e)
		maximo = math.max(maximo, e.calido)
	end)
	comprobar(maximo < 0.3, `apagar y encender enseguida apenas deslumbra ({maximo})`)
end

-- De una sala con luz a otra parecida: nada.
do
	local sala = A.juntar(C.Base + 0.5)
	local otra = A.juntar(C.Base + 0.42)
	local peor = 0
	correr(sala, 6, function(t)
		return if t < 2 then sala else otra
	end, function(_, e)
		peor = math.max(peor, math.abs(e.brillo), e.calido)
	end)
	comprobar(peor < 0.03, `de una sala a otra parecida no pasa nada ({peor})`)
end

-- Salir al día desde dentro de día: algo, no un deslumbre entero.
do
	local dentro = A.juntar(C.Base + L.DiaDentro)
	local fuera = A.juntar(C.Base + L.Dia)
	local maximo = 0
	correr(dentro, 3, function()
		return fuera
	end, function(_, e)
		maximo = math.max(maximo, e.calido)
	end)
	comprobar(maximo < 0.5, `salir de la casa de día deslumbra poco ({maximo})`)
end

-- Un relámpago corto acostumbrado a la oscuridad: deslumbra y luego vuelve a oscuro, sin quedarse negro mucho.
do
	local hecho = correr(CON_LINTERNA, 15, function()
		return NOCHE_OSCURA
	end, function() end)
	local maximo, negroHasta = 0, 0
	correr(hecho, 12, function(t)
		return if t < 0.15 then A.juntar(C.Base + L.Rayo) else NOCHE_OSCURA
	end, function(t, e)
		maximo = math.max(maximo, e.calido)
		if e.brillo < C.Hundido * 0.5 then
			negroHasta = t
		end
	end)
	comprobar(maximo > 0.9, `el relámpago deslumbra ({maximo})`)
	comprobar(negroHasta < 3, `tras el relámpago no se queda negro mucho rato ({negroHasta})`)
end

-- La linterna de otro a la cara: deslumbra mientras apunte y se va al dejar de apuntar.
do
	local hecho = 0.3
	local ajena = 0
	local origen = Vector3.new(0, 5, 0)
	local dir = Vector3.new(0, 0, -1)
	local ojo = Vector3.new(0, 5, -8)
	local t = 0
	while t < 3 do
		t += DT
		local meta = if t < 2 then A.apunta(origen, dir, ojo) * C.Ajena.Fuerza else 0
		ajena = A.seguir(ajena, meta, DT)
		hecho = A.acostumbrar(hecho, 0.3, DT)
		local e = A.efecto(hecho, 0.3, ajena)
		if t > 0.5 and t < 2 then
			comprobar(e.calido > 0.5, "deslumbra mientras apunta")
		end
		if t > 2.9 then
			comprobar(e.calido < 0.05, "deja de apuntar: se va")
		end
	end
	comprobar(C.Ajena.Rendimiento > 0 and C.Ajena.Rendimiento < 1, "con Rendimiento, más flojo")
end

print(`adaptar: {cuentas} comprobaciones, todo bien`)
