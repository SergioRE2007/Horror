-- Banco de la flecha del borde del tutorial (juego/cliente/TutorialVista) y de la guía del lobby (lobby/cliente/
-- GuiaLobby). Ejecutar desde la raíz: lune run tests/bancos/flecha-borde.luau (también lo lanza tests/regressions.luau).
-- Con el Roblox de mentira (tests/bancos/_roblox.luau) y los módulos de verdad. Mira:
--   la cuenta (sitioBorde, igual en los dos): detrás, a media altura en el borde del lado hacia el que girarse y
--   apuntando a ese lado; delante pero a un lado, en ese borde (antes salía al revés); siempre dentro de los márgenes.
--   TutorialVista de verdad, con un hacha detrás: la flecha a la derecha o a la izquierda según dónde esté, girada 90º;
--   en un teléfono de 640 × 360, por debajo del cartel y por encima de la rejilla de botones del equipo, y la flecha
--   del mundo con la escala del HUD; con Rendimiento, quieta.
-- Si algo no se cumple, termina con error.
local crearMundo = require("./_roblox")

local cuentas = 0
local function comprueba(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end
local function cerca(actual: number, esperado: number, margen: number, etiqueta: string)
	assert(math.abs(actual - esperado) <= margen, `{etiqueta}: esperado {esperado} ± {margen}, recibido {actual}`)
	cuentas += 1
end

local DT = 1 / 60

-- La cuenta, sin mundo: la misma en los dos módulos.
do
	local m = crearMundo({ proyecto = "lobby.project.json" })
	local g = m.global
	local Vector2, Vector3 = g.Vector2, g.Vector3
	local GuiaLobby = m.cargar("src/lobby/cliente/GuiaLobby")
	local m2 = crearMundo()
	local TutorialVista = m2.cargar("src/juego/cliente/TutorialVista")
	local tam = Vector2.new(1280, 720)
	for nombre, f in { GuiaLobby = GuiaLobby.sitioBorde, TutorialVista = TutorialVista.sitioBorde } do
		-- Detrás a la derecha (la proyección sale a la izquierda y abajo): a la derecha, a media altura, apuntando a la derecha.
		local sitio, hacia = f(tam, Vector3.new(300, 900, -5), 3, 1, 70, 140, 70)
		cerca(sitio.X, 1280 - 70, 0.01, `{nombre}: detrás a la derecha, en el borde derecho`)
		cerca(sitio.Y, 360, 0.01, `{nombre}: detrás, a media altura`)
		comprueba(hacia.X == 1 and hacia.Y == 0, `{nombre}: detrás a la derecha, apunta a la derecha`)
		sitio, hacia = f(tam, Vector3.new(1000, 900, -5), -3, 1, 70, 140, 70)
		cerca(sitio.X, 70, 0.01, `{nombre}: detrás a la izquierda, en el borde izquierdo`)
		comprueba(hacia.X == -1, `{nombre}: detrás a la izquierda, apunta a la izquierda`)
		-- Mucho margen abajo (el móvil): la media altura se queda dentro de la franja libre (150-270 px de verdad).
		sitio = f(tam, Vector3.new(0, 0, -5), 1, 0.5, 70, 300, 900)
		cerca(sitio.Y * 0.5, 720 - 900 * 0.5, 1e-6, `{nombre}: detrás, entre los márgenes`)
		-- Delante pero a la derecha de la pantalla: en el borde derecho, apuntando a la derecha.
		sitio, hacia = f(tam, Vector3.new(2500, 360, 10), 30, 1, 70, 140, 70)
		cerca(sitio.X, 1280 - 70, 0.01, `{nombre}: delante a la derecha, en el borde derecho`)
		comprueba(hacia.X > 0.99, `{nombre}: delante a la derecha, apunta a la derecha`)
		-- Delante y muy arriba: por debajo del margen de arriba.
		sitio, hacia = f(tam, Vector3.new(640, -3000, 10), 0, 1, 70, 140, 70)
		cerca(sitio.Y, 140, 0.01, `{nombre}: arriba, justo bajo el margen`)
		comprueba(hacia.Y < -0.99, `{nombre}: arriba, apunta arriba`)
		-- En píxeles de diseño (dividido por la escala).
		sitio = f(tam, Vector3.new(2500, 360, 10), 30, 0.5, 70, 140, 70)
		cerca(sitio.X, (1280 - 35) / 0.5, 0.01, `{nombre}: en píxeles de diseño`)
		-- Pantalla diminuta (márgenes que no caben): en el centro, sin NaN.
		sitio = f(Vector2.new(100, 80), Vector3.new(0, 0, -1), 1, 1, 70, 140, 70)
		comprueba(sitio.X == sitio.X and sitio.Y == sitio.Y, `{nombre}: pantalla diminuta sin NaN`)
	end
end

-- TutorialVista de verdad con un hacha detrás.
local function montar(opciones: { movil: boolean?, rendimiento: boolean? })
	local m = crearMundo()
	local g = m.global
	local Vector3, CFrame = g.Vector3, g.CFrame
	if opciones.movil then
		m.movil()
	end
	m.caja(CFrame.new(0, -0.5, 0), Vector3.new(400, 1, 400))
	m.personaje(CFrame.new(0, 3, 0))
	m.mirar(0, 0) -- hacia -Z
	local Ui = m.cargar("src/comun/cliente/Ui")
	local TutorialVista = m.cargar("src/juego/cliente/TutorialVista", {
		Sonido = { tocar = function() end },
	})
	local yo = m.jugadorLocal
	if opciones.rendimiento then
		yo:SetAttribute("Rendimiento", true)
	end
	local hacha = m.caja(CFrame.new(12, 1, 30), Vector3.new(1, 1, 3), { Name = "Hacha" })
	hacha:SetAttribute("Tipo", "Hacha")
	m.servicio("CollectionService"):AddTag(hacha, "Objeto")
	TutorialVista.start()
	yo:SetAttribute("Tutorial", "Hacha")
	m.correr(0.6, DT)
	local hud = Ui.hud()
	local borde = hud:FindFirstChild("TutorialBorde")
	local mundo = yo.PlayerGui:FindFirstChild("TutorialFlecha")
	assert(borde and mundo, "no encuentro las flechas del tutorial")
	return { m = m, g = g, Ui = Ui, hud = hud, borde = borde, mundo = mundo, hacha = hacha }
end

do -- Ordenador: detrás a la derecha y luego a la izquierda.
	local w = montar({})
	local escala = w.Ui.escala()
	local lienzo = w.Ui.lienzo()
	comprueba(w.borde.Visible, "pc: con el hacha detrás se ve la flecha del borde")
	cerca(w.borde.Position.X.Offset, lienzo.X - 70, 7, "pc: detrás a la derecha, en el borde derecho")
	cerca(w.borde.Rotation, -90, 0.01, "pc: detrás a la derecha, apunta a la derecha")
	comprueba(w.borde.Position.Y.Offset > lienzo.Y * 0.3 and w.borde.Position.Y.Offset < lienzo.Y * 0.7,
		"pc: detrás, a media altura (no abajo en el centro)")
	w.hacha.CFrame = w.g.CFrame.new(-12, 1, 30)
	w.m.correr(0.6, DT)
	cerca(w.borde.Position.X.Offset, 70, 7, "pc: detrás a la izquierda, en el borde izquierdo")
	cerca(w.borde.Rotation, 90, 0.01, "pc: detrás a la izquierda, apunta a la izquierda")
	-- Delante pero a un lado (fuera de la pantalla): en ese borde, sin darle la vuelta.
	w.hacha.CFrame = w.g.CFrame.new(60, 1, -5)
	w.m.correr(0.6, DT)
	comprueba(w.borde.Visible and w.borde.Position.X.Offset > lienzo.X - 80, "pc: delante a la derecha, en el borde derecho")
	comprueba(math.abs(w.borde.Rotation + 90) < 30, "pc: delante a la derecha, apunta a la derecha")
	cerca(w.mundo.Size.X.Offset, 90 * escala, 1, "pc: la flecha del mundo con la escala del HUD")
end

do -- Teléfono de 640 × 360: entre el cartel y la rejilla de botones, y la flecha del mundo pequeña.
	local w = montar({ movil = true })
	local escala = w.Ui.escala()
	local lienzo = w.Ui.lienzo()
	local y = w.borde.Position.Y.Offset
	comprueba(w.borde.Visible, "móvil: se ve la flecha del borde")
	comprueba(y - 35 >= 8 + 92, `móvil: por debajo del cartel ({y})`)
	local rejillaArriba = 0.97 * lienzo.Y - w.Ui.zonaSegura() - (2 * 80 + 8)
	comprueba(y + 35 <= rejillaArriba, `móvil: por encima de la rejilla de botones ({y} / {rejillaArriba})`)
	comprueba(escala < 0.8, "móvil: el HUD se encoge")
	cerca(w.mundo.Size.X.Offset, 90 * escala, 1, "móvil: la flecha del mundo encoge con el HUD")
	comprueba(w.mundo.Size.X.Offset < 360 / 6, "móvil: la flecha del mundo no tapa un cuarto de la pantalla")
end

do -- Rendimiento: las flechas quietas.
	local w = montar({ rendimiento = true })
	local flechaMundo = w.mundo:FindFirstChild("Flecha")
	local antes, antesMundo = w.borde.Position, flechaMundo.Position
	local quieta = true
	w.m.correr(1, DT, function()
		quieta = quieta and w.borde.Position == antes and flechaMundo.Position == antesMundo
	end)
	comprueba(quieta, "rendimiento: flechas quietas")
	local w2 = montar({})
	local flecha2 = w2.mundo:FindFirstChild("Flecha")
	local inicio, mueve = flecha2.Position, false
	w2.m.correr(1, DT, function()
		mueve = mueve or flecha2.Position ~= inicio
	end)
	comprueba(mueve, "sin rendimiento: la flecha del mundo sube y baja")
end

print(`flecha del borde: todo se cumple ({cuentas} comprobaciones)`)
