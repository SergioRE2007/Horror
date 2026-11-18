-- Banco del tutorial, 16.5 (shared/PasosTutorial, sin Roblox):
--   La gasolina del generador: en marcha con poco depósito, el paso Generador pide echarle un bidón (repostar) hasta
--   que llega al mínimo o sube; sin bidones con gasolina no lo pide; parado y sin gasolina, primero el bidón.
--   La siguiente meta tras el tutorial: llenar el generador si no aguanta la noche, reparar ventanas y puertas rotas,
--   troncos junto a la chimenea, llave del sótano, del garaje, piezas del coche, su gasolina y huir. Y la del final
--   de la Bestia: cruces, plano de la reja, reja y esperarla.
-- Ejecutar desde la raíz: lune run tests/bancos/tutorial-meta.luau (lo corre regressions.luau).
local PT = require("../../src/shared/PasosTutorial")

local cuentas = 0
local function igual(actual, esperado, etiqueta: string)
	assert(actual == esperado, `{etiqueta}: esperado {tostring(esperado)}, recibido {tostring(actual)}`)
	cuentas += 1
end

local function vista(cambios)
	local v = { fase = "Dia", noche = 1, quedan = 100, aviso = 20, nota = true, mochila = true, hacha = true, corrido = true,
		cargando = "Tablon", generador = false, cortinas = 3, gasolina = 0.3, gasolinaMin = 0.45, bidon = true }
	for clave, valor in cambios do
		v[clave] = valor
	end
	return v
end

-- Gasolina del generador ------------------------------------------------------------------------------------------
do
	local e = PT.nuevo()
	PT.avanzar(e, vista({}))
	igual(e.paso, "Generador", "gasolina: primero arrancarlo")
	igual(e.repostar, nil, "gasolina: con algo de gasolina, primero arrancar")
	PT.avanzar(e, vista({ generador = true, gasolina = 0.29 }))
	igual(e.paso, "Generador", "gasolina: en marcha con poca, sigue en el generador")
	igual(e.repostar, true, "gasolina: pide echarle un bidón")
	PT.avanzar(e, vista({ generador = true, gasolina = 0.28 }))
	igual(e.repostar, true, "gasolina: gastándose no cuenta como echada")
	PT.avanzar(e, vista({ generador = true, gasolina = 0.4 }))
	igual(e.paso, "Espera", "gasolina: al subir el depósito (aunque no llegue al mínimo) se da por echada")
	igual(e.repostar, nil, "gasolina: ya no pide")
	PT.avanzar(e, vista({ generador = true, gasolina = 0.1 }))
	igual(e.paso, "Espera", "gasolina: hecha una vez, no vuelve a pedirla")

	local lleno = PT.nuevo()
	PT.avanzar(lleno, vista({ generador = true, gasolina = 0.8 }))
	igual(lleno.paso, "Espera", "gasolina: con el depósito lleno no se pide")

	local sinBidon = PT.nuevo()
	PT.avanzar(sinBidon, vista({ generador = true, gasolina = 0.2, bidon = false }))
	igual(sinBidon.paso, "Espera", "gasolina: sin bidones con gasolina no se pide")

	local seco = PT.nuevo()
	PT.avanzar(seco, vista({ gasolina = 0 }))
	igual(seco.paso, "Generador", "gasolina: parado y seco, en el generador")
	igual(seco.repostar, true, "gasolina: parado y seco, primero el bidón (sin gasolina no arranca)")
	PT.avanzar(seco, vista({ gasolina = 0.5 }))
	igual(seco.repostar, nil, "gasolina: echada, ahora arrancarlo")
	igual(seco.paso, "Generador", "gasolina: aún falta arrancarlo")

	local antiguo = PT.nuevo()
	local sinDato = vista({ generador = true })
	sinDato.gasolina = nil
	PT.avanzar(antiguo, sinDato)
	igual(antiguo.paso, "Espera", "gasolina: sin dato del generador, como antes")

	local noche = PT.nuevo()
	PT.avanzar(noche, vista({ generador = true, gasolina = 0.1, quedan = 10 }))
	igual(noche.paso, "Cortinas", "gasolina: al anochecer se deja, como lo demás del día")
	igual(noche.repostar, nil, "gasolina: de noche no se pide")
end

-- Siguiente meta --------------------------------------------------------------------------------------------------
do
	local todas = { "LlaveSotano", "LlaveGaraje", "LlaveDesvan", "LlaveRico" }
	igual(PT.meta(todas, 5, true, nil, 0, false), "Sotano", "meta: primero la llave del sótano")
	igual(PT.meta({ "LlaveGaraje", "LlaveDesvan" }, 5, true, nil, 0, false), "Garaje", "meta: luego la del garaje")
	local meta, n = PT.meta({ "LlaveDesvan", "LlaveRico" }, 3, true, nil, 0, false)
	igual(meta, "Piezas", "meta: con el garaje abierto, el coche")
	igual(n, 3, "meta: cuántas piezas faltan")
	igual(PT.meta({}, 0, true, nil, 0, false), "Gasolina", "meta: solo falta la gasolina del coche")
	igual(PT.meta({}, 0, false, nil, 0, false), "Huir", "meta: listo para huir")
	-- El generador no aguanta la noche (Tutorial calcula `poca`: de día, bajo el mínimo y con gasolina a mano)
	igual(PT.meta(todas, 5, true, true, 0, false), "Generador", "meta: poca gasolina, el generador antes que el sótano")
	igual(PT.meta({}, 0, false, true, 0, false), "Generador", "meta: poca gasolina, antes incluso que huir")
	igual(PT.meta(todas, 5, true, false, 0, false), "Sotano", "meta: con gasolina de sobra (o sin nada que echarle), como antes")
	igual(PT.meta(todas, 5, true, nil, 0, false), "Sotano", "meta: sin el dato, como antes")

	-- Ventanas y puertas rotas (Tutorial cuenta las de abajo sin vida): antes que las llaves, después del generador
	meta, n = PT.meta(todas, 5, true, false, 1, false)
	igual(meta, "Reparar", "meta: una rota, repararla antes que la llave")
	igual(n, 1, "meta: cuántas rotas (1)")
	meta, n = PT.meta({}, 0, false, false, 3, true)
	igual(meta, "Reparar", "meta: rotas antes que la chimenea y que huir")
	igual(n, 3, "meta: cuántas rotas (3)")
	igual(PT.meta(todas, 5, true, true, 2, true), "Generador", "meta: sin luz no se aguanta: el generador antes que reparar")
	igual(select(2, PT.meta(todas, 5, true, true, 2, false)), 0, "meta: el generador no lleva número")

	-- Troncos junto a la chimenea (Tutorial: de día, ya sale el Trepador, apagada y sin troncos cerca)
	meta, n = PT.meta(todas, 5, true, false, 0, true)
	igual(meta, "Chimenea", "meta: chimenea antes que la llave del sótano")
	igual(n, 0, "meta: la chimenea no lleva número")
	igual(PT.meta({}, 0, false, false, 0, true), "Chimenea", "meta: chimenea antes incluso que huir")
	igual(PT.meta({}, 0, true, true, 0, true), "Generador", "meta: el generador antes que la chimenea")
	igual(PT.meta({ "LlaveGaraje" }, 5, true, false, 0, false), "Garaje", "meta: con troncos y nada roto, lo de siempre")
end

-- Meta del final de la Bestia (Tutorial la usa con la 12 leída y la casa ya a medio preparar) ------------------------
do
	local meta, n = PT.metaBestia(5, false, false)
	igual(meta, "Cruces", "bestia: primero las cruces")
	igual(n, 5, "bestia: cuántas cruces faltan")
	meta, n = PT.metaBestia(1, true, true)
	igual(meta, "Cruces", "bestia: con la reja ya montada, aún falta una cruz")
	igual(n, 1, "bestia: la última cruz")
	igual(PT.metaBestia(0, false, false), "Plano", "bestia: cruces hechas, falta el plano de la 9")
	igual(PT.metaBestia(0, true, false), "Reja", "bestia: con el plano, armar y montar la reja")
	igual(PT.metaBestia(0, false, true), "Esperar", "bestia: reja montada (aunque no se leyera la 9), a esperarla")
	igual(PT.metaBestia(0, true, true), "Esperar", "bestia: todo listo, a esperarla")
	igual(select(2, PT.metaBestia(0, true, true)), 0, "bestia: sin número fuera de las cruces")
end

print(`tutorial-meta: {cuentas} comprobaciones`)
