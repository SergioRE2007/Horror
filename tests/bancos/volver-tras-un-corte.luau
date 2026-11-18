-- Banco de volver a la partida tras un corte (docs/sistemas/partida.md, "Volver tras un corte"). Ejecutar desde la
-- raíz: lune run tests/bancos/volver-tras-un-corte.luau (lo corre tests/regressions.luau). Con el Roblox de mentira:
--   Viaje (de verdad, con un MemoryStore de mentira): Viaje.ir apunta el código de acceso con el viaje; la vuelta se
--   apunta con su caducidad, solo se renueva y se borra si lleva a esta partida (si lleva a otra, ni se toca), se lee
--   con lo que sea que haya (basura = sin vuelta) y un fallo de red no es "sin vuelta". Viaje.regresar lleva al
--   servidor reservado con su código. Viaje.yaGuardada quita "nueva" del viaje. Viaje.volver marca al devuelto.
--   Muerte (de verdad): quien murió esta noche y vuelve a entrar sigue muerto y sin personaje (no se revive gratis);
--   revive pagando o al amanecer (también si amaneció mientras faltaba); vivo, vuelve con personaje. Solo y muerto en
--   el servidor, es como si murieran todos.
--   Regreso del lobby (de verdad, con Viaje falso): PartidaAbierta al cargar los datos y otra vez a los VueltaRelee s;
--   GO BACK vuelve a leer la vuelta y lleva con ella; sin vuelta, avisa y quita el atributo; sentado en un coche, nada;
--   con Limite; un fallo al leer no quita el atributo.
--   RegresoUi (de verdad): con PartidaAbierta sale el cartel con la frase y GO BACK; el clic pide al servidor y lo apaga
--   un momento; sentado o sin el atributo se va; con mando, GO BACK sale elegido; en el móvil mide un dedo.
local crearMundo = require("./_roblox")

local cuentas = 0
local function igual(actual, esperado, etiqueta: string)
	assert(actual == esperado, `{etiqueta}: esperado {tostring(esperado)}, recibido {tostring(actual)}`)
	cuentas += 1
end

local function copia(v)
	if type(v) ~= "table" then
		return v
	end
	local c = {}
	for k, x in v do
		c[k] = copia(x)
	end
	return c
end

-- Un HashMap de MemoryStore de mentira: lo que se escribe se guarda copiado, con su caducidad. `falla` = todas fallan.
local function mapaFalso()
	local f = { datos = {}, caduca = {}, falla = false, llamadas = 0 }
	local function llamar(self)
		self.llamadas += 1
		if self.falla then
			error("MemoryStore sin red")
		end
	end
	function f.GetAsync(self, clave: string)
		llamar(self)
		return copia(self.datos[clave])
	end
	function f.SetAsync(self, clave: string, valor, caduca: number)
		llamar(self)
		self.datos[clave], self.caduca[clave] = copia(valor), caduca
		return true
	end
	function f.UpdateAsync(self, clave: string, fn, caduca: number)
		llamar(self)
		local nuevo = fn(copia(self.datos[clave]))
		if nuevo ~= nil then
			self.datos[clave], self.caduca[clave] = copia(nuevo), caduca
		end
		return nuevo
	end
	function f.RemoveAsync(self, clave: string)
		llamar(self)
		self.datos[clave], self.caduca[clave] = nil, nil
	end
	return f
end

------------------------------------------------------------------------------------------------------------------------
-- 1. Viaje.
do
	local m = crearMundo({ servidor = true })
	local Config = m.cargar("src/shared/Config")
	local Viaje = m.cargar("src/comun/servidor/Viaje")
	local mapa = mapaFalso()
	Viaje.mapa = function()
		return mapa
	end
	-- Lo que falta en el mundo falso del teletransporte.
	local tele = m.interno(m.servicio("TeleportService")).clase
	tele.metodos = tele.metodos or {}
	local reservados, llevados = 0, {}
	tele.metodos.ReserveServer = function()
		reservados += 1
		return "CODIGO-A", "SERVIDOR-A"
	end
	tele.metodos.TeleportAsync = function(_, lugar, jugadores, opciones)
		table.insert(llevados, { lugar = lugar, jugadores = jugadores, codigo = opciones and opciones.ReservedServerAccessCode })
	end
	-- Corre `fn` en una tarea del mundo (las llamadas esperan como en Roblox) y devuelve lo que devuelve.
	local function hacer(fn: () -> ...any): ...any
		local r = nil
		m.task.spawn(function()
			r = table.pack(fn())
		end)
		m.correr(5)
		assert(r, "la tarea no ha acabado")
		return table.unpack(r, 1, r.n)
	end
	local A = m.jugador("A", 101)
	local B = m.jugador("B", 102)

	-- Viaje.ir apunta el código de acceso con el viaje (solo lo leen servidores).
	Config.Lugares.Juego = 555
	local ok = hacer(function()
		return Viaje.ir({ A, B }, A.UserId, 2, true)
	end)
	igual(ok, true, "ir: sale")
	igual(reservados, 1, "ir: reserva un servidor")
	local apuntado = mapa.datos["SERVIDOR-A"]
	igual(apuntado and apuntado.codigo, "CODIGO-A", "ir: el viaje lleva el código de acceso")
	igual(apuntado and apuntado.dueno, A.UserId, "ir: y lo de siempre")
	igual(llevados[1] and llevados[1].codigo, "CODIGO-A", "ir: teletransporte con el código")

	local info = { dueno = A.UserId, ranura = 2, nueva = false, jugadores = { A.UserId, B.UserId }, codigo = "CODIGO-A" }
	local otra = { dueno = 9, ranura = 1, nueva = false, jugadores = { 9 }, codigo = "CODIGO-B" }
	local sinCodigo = { dueno = A.UserId, ranura = 2, nueva = false, jugadores = {} }
	local clave = `vuelta_{B.UserId}`

	-- Sin código (lobby de antes, Studio): nada.
	local antes = mapa.llamadas
	igual(hacer(function()
		return Viaje.apuntarVuelta(B.UserId, sinCodigo)
	end), false, "sin código: no se apunta")
	igual(hacer(function()
		return Viaje.renovarVuelta(B.UserId, sinCodigo)
	end), "otra", "sin código: no se renueva")
	hacer(function()
		Viaje.borrarVuelta(B.UserId, sinCodigo)
	end)
	igual(mapa.llamadas, antes, "sin código: ni se pregunta a MemoryStore")

	-- Se apunta, se lee y se renueva.
	igual(hacer(function()
		return Viaje.apuntarVuelta(B.UserId, info)
	end), true, "apuntar: bien")
	igual(mapa.datos[clave] and mapa.datos[clave].codigo, "CODIGO-A", "apuntar: con el código")
	igual(mapa.caduca[clave], Config.Partida.VueltaCaduca, "apuntar: caduca sola")
	local leida, bien = hacer(function()
		return Viaje.vuelta(B.UserId)
	end)
	igual(bien, true, "leer: se ha podido")
	igual(leida and leida.codigo, "CODIGO-A", "leer: la vuelta")
	mapa.caduca[clave] = 1
	igual(hacer(function()
		return Viaje.renovarVuelta(B.UserId, info)
	end), "ok", "renovar: la nuestra")
	igual(mapa.caduca[clave], Config.Partida.VueltaCaduca, "renovar: caduca otra vez más tarde")

	-- Otra partida no la toca (se fue luego a esa).
	igual(hacer(function()
		return Viaje.renovarVuelta(B.UserId, otra)
	end), "otra", "renovar: la de otra partida no")
	hacer(function()
		Viaje.borrarVuelta(B.UserId, otra)
	end)
	igual(mapa.datos[clave] and mapa.datos[clave].codigo, "CODIGO-A", "borrar: la de otra partida no se borra")

	-- Sin red: ni "sin vuelta" ni se para de renovar.
	mapa.falla = true
	local nada, sinRed = hacer(function()
		return Viaje.vuelta(B.UserId)
	end)
	igual(nada == nil and sinRed == false, true, "sin red: no se sabe (no es sin vuelta)")
	igual(hacer(function()
		return Viaje.renovarVuelta(B.UserId, info)
	end), "error", "sin red: renovar da error (otra vez en la siguiente)")
	mapa.falla = false

	-- Se borra la nuestra; luego ya no hay.
	hacer(function()
		Viaje.borrarVuelta(B.UserId, info)
	end)
	igual(mapa.datos[clave], nil, "borrar: la nuestra")
	local ninguna, leidaBien = hacer(function()
		return Viaje.vuelta(B.UserId)
	end)
	igual(ninguna == nil and leidaBien == true, true, "leer: ya no hay")
	igual(hacer(function()
		return Viaje.renovarVuelta(B.UserId, info)
	end), "otra", "renovar: borrada, no se vuelve a crear")
	igual(mapa.datos[clave], nil, "renovar: sigue sin estar")

	-- Basura en MemoryStore: sin vuelta.
	for i, basura in { { codigo = 5 }, { codigo = "" }, "CODIGO", 7, { otra = "x" } } do
		mapa.datos[clave] = basura
		local v, si = hacer(function()
			return Viaje.vuelta(B.UserId)
		end)
		igual(v == nil and si == true, true, `leer: basura {i} = sin vuelta`)
	end

	-- regresar: al servidor reservado con su código; sin lugar publicado, "studio".
	local salio = hacer(function()
		return Viaje.regresar(B, { codigo = "CODIGO-A" })
	end)
	igual(salio, true, "regresar: sale")
	local ultimo = llevados[#llevados]
	igual(ultimo.lugar == 555 and ultimo.codigo == "CODIGO-A" and ultimo.jugadores[1] == B, true, "regresar: con su código")
	Config.Lugares.Juego = 0
	local _, porque = hacer(function()
		return Viaje.regresar(B, { codigo = "CODIGO-A" })
	end)
	igual(porque, "studio", "regresar: sin lugar publicado no se va")

	-- volver marca al devuelto (al irse no se le apunta la vuelta).
	igual(Viaje.devuelto(A), false, "volver: aún no")
	m.task.spawn(Viaje.volver, { A }, "This game has already ended.")
	m.paso()
	igual(Viaje.devuelto(A), true, "volver: devuelto")
	igual(Viaje.devuelto(B), false, "volver: solo él")
	m.correr(5)
	igual(#m.errores, 0, `viaje: sin errores ({m.errores[1] or ""})`)
end

-- Viaje.yaGuardada: el viaje de este servidor deja de ser "nueva" (si se cierra y alguien vuelve, carga lo guardado).
do
	local m = crearMundo({ servidor = true })
	local Viaje = m.cargar("src/comun/servidor/Viaje")
	local mapa = mapaFalso()
	Viaje.mapa = function()
		return mapa
	end
	-- Lo que falta en el mundo falso: el id del servidor privado.
	local juego = m.global.game
	m.interno(juego).props.PrivateServerId = "SERVIDOR-N"
	igual(juego.PrivateServerId, "SERVIDOR-N", "yaGuardada: servidor privado de mentira")
	mapa.datos["SERVIDOR-N"] = { dueno = 1, ranura = 1, nueva = true, jugadores = { 1 }, codigo = "C" }
	m.task.spawn(Viaje.yaGuardada)
	m.correr(3)
	igual(mapa.datos["SERVIDOR-N"].nueva, false, "yaGuardada: ya no es nueva")
	igual(mapa.datos["SERVIDOR-N"].codigo, "C", "yaGuardada: lo demás sigue")
	igual(mapa.caduca["SERVIDOR-N"], m.cargar("src/shared/Config").Partida.CaducaViaje, "yaGuardada: con la caducidad del viaje")
	local llamadas = mapa.llamadas
	m.task.spawn(Viaje.yaGuardada)
	m.correr(3)
	igual(mapa.datos["SERVIDOR-N"].nueva, false, "yaGuardada: otra vez, nada que cambiar")
	igual(mapa.llamadas, llamadas + 1, "yaGuardada: una sola petición")
end

------------------------------------------------------------------------------------------------------------------------
-- 2. Muerte: salir y volver a entrar de noche no revive.
do
	local m = crearMundo({ servidor = true })
	local g = m.global
	local Muerte = m.cargar("src/juego/servidor/Muerte")
	local Remotes = m.cargar("src/shared/Remotes")
	Muerte.start()
	local todos = 0
	Muerte.alMorirTodos(function()
		todos += 1
	end)
	local A = m.jugador("A", 201)
	local B = m.jugador("B", 202)
	m.correr(0.2)
	igual(A.Character ~= nil and B.Character ~= nil, true, "muerte: los dos con personaje")
	igual(Muerte.matar(A, g.Vector3.new(0, 5, 0)), true, "muerte: A muere")
	m.correr(0.2)
	m.salir(A)
	m.correr(0.5)
	local A2 = m.jugador("A", 201)
	m.correr(0.5)
	igual(A2.Character, nil, "muerte: vuelve a entrar muerto: sin personaje")
	igual(A2:GetAttribute("Muerto"), true, "muerte: y Muerto")
	igual(Muerte.vivo(A2), false, "muerte: no está vivo")
	igual(Muerte.vivo(B), true, "muerte: B sigue vivo")
	igual(todos, 0, "muerte: con B vivo no han muerto todos")
	m.correr(3)
	local avisos = m.interno(Remotes.Aviso)._enviados or {}
	local aviso = avisos[#avisos]
	igual(aviso and aviso.quien == A2.Name and aviso[1] == "It got you. You'll wake up at dawn.", true,
		"muerte: se le recuerda que despierta al amanecer")
	-- Pagando (Revivir) revive.
	Muerte.revivir(A2)
	m.correr(0.5)
	igual(A2.Character ~= nil and A2:GetAttribute("Muerto") == nil, true, "muerte: revivir le da personaje")
	-- Revivido, sale y vuelve: vivo.
	m.salir(A2)
	m.correr(0.2)
	local A3 = m.jugador("A", 201)
	m.correr(0.5)
	igual(A3.Character ~= nil and not A3:GetAttribute("Muerto"), true, "muerte: revivido y vuelve: vivo")
	-- Muere, se va y amanece mientras falta: vuelve vivo.
	Muerte.matar(A3, g.Vector3.zero)
	m.correr(0.2)
	m.salir(A3)
	m.correr(0.2)
	Muerte.revivirTodos()
	m.correr(0.2)
	local A4 = m.jugador("A", 201)
	m.correr(0.5)
	igual(A4.Character ~= nil and not A4:GetAttribute("Muerto"), true, "muerte: amaneció mientras faltaba: vivo")
	-- Muere, se va, se va también el vivo y vuelve solo: es como si murieran todos.
	Muerte.matar(A4, g.Vector3.zero)
	m.correr(0.2)
	m.salir(A4)
	m.correr(0.2)
	m.salir(B)
	m.correr(0.2)
	igual(todos, 0, "muerte: sin nadie en el servidor no se avisa")
	local A5 = m.jugador("A", 201)
	m.correr(0.5)
	igual(A5:GetAttribute("Muerto"), true, "muerte: vuelve solo y muerto")
	igual(todos, 1, "muerte: solo y muerto = han muerto todos (el día vuelve a empezar)")
	igual(#m.errores, 0, `muerte: sin errores ({m.errores[1] or ""})`)
end

------------------------------------------------------------------------------------------------------------------------
-- 3. Regreso (lobby, servidor), con Viaje falso.
do
	local m = crearMundo({ servidor = true, proyecto = "lobby.project.json" })
	local Config = m.cargar("src/shared/Config")
	local Remotes = m.cargar("src/shared/Remotes")
	local abiertas: { [number]: any } = {} -- [UserId] = la vuelta que devuelve el Viaje falso
	local falla = false
	local regresos = {}
	local falso = {
		vuelta = function(userId: number)
			if falla then
				return nil, false
			end
			return abiertas[userId], true
		end,
		regresar = function(jugador, vuelta)
			table.insert(regresos, { jugador = jugador, codigo = vuelta.codigo })
			return true
		end,
	}
	local Regreso = m.cargar("src/lobby/servidor/Regreso", { Viaje = falso })
	Regreso.start()
	local function avisosDe(j): { string }
		local l = {}
		for _, e in m.interno(Remotes.Aviso)._enviados or {} do
			if e.quien == j.Name then -- (el mundo falso apunta el nombre)
				table.insert(l, e[1])
			end
		end
		return l
	end

	abiertas[301] = { codigo = "CODIGO-A" }
	local A = m.jugador("A", 301)
	local B = m.jugador("B", 302)
	m.correr(1)
	igual(A:GetAttribute("PartidaAbierta"), nil, "regreso: hasta cargar los datos no se mira")
	A:SetAttribute("DatosListos", true)
	B:SetAttribute("DatosListos", true)
	m.correr(1)
	igual(A:GetAttribute("PartidaAbierta"), true, "regreso: con vuelta, PartidaAbierta")
	igual(B:GetAttribute("PartidaAbierta"), nil, "regreso: sin vuelta, nada")
	-- El juego aún no ha visto el corte de B: a los VueltaRelee s se vuelve a mirar.
	abiertas[302] = { codigo = "CODIGO-B" }
	m.correr(Config.Partida.VueltaRelee + 1)
	igual(B:GetAttribute("PartidaAbierta"), true, "regreso: se vuelve a mirar más tarde")

	-- GO BACK: lee otra vez y lleva con su código (nunca con lo del cliente).
	Remotes.Regreso.OnServerEvent:Fire(A, { codigo = "TRAMPA" })
	m.correr(0.5)
	igual(#regresos, 1, "regreso: GO BACK lleva")
	igual(regresos[1].jugador == A and regresos[1].codigo == "CODIGO-A", true, "regreso: con el código del servidor")
	Remotes.Regreso.OnServerEvent:Fire(A)
	m.correr(0.1)
	igual(#regresos, 1, "regreso: Limite (dos seguidos, uno)")

	-- Sentado en un coche: nada.
	m.correr(Config.Limites.Regreso + 0.1)
	A:SetAttribute("Coche", "Coche1")
	Remotes.Regreso.OnServerEvent:Fire(A)
	m.correr(0.5)
	igual(#regresos, 1, "regreso: sentado en un coche no se va")
	A:SetAttribute("Coche", nil)

	-- La partida ya se acabó: aviso y fuera el atributo.
	m.correr(Config.Limites.Regreso + 0.1)
	abiertas[301] = nil
	Remotes.Regreso.OnServerEvent:Fire(A)
	m.correr(0.5)
	igual(#regresos, 1, "regreso: sin vuelta no se va")
	igual(A:GetAttribute("PartidaAbierta"), nil, "regreso: sin vuelta se quita el atributo")
	local lista = avisosDe(A)
	igual(lista[#lista], "Your game has already ended.", "regreso: avisa de que se ha acabado")

	-- Un fallo al leer no quita el atributo.
	m.correr(Config.Limites.Regreso + 0.1)
	falla = true
	Remotes.Regreso.OnServerEvent:Fire(B)
	m.correr(0.5)
	igual(B:GetAttribute("PartidaAbierta"), true, "regreso: un fallo al leer no lo quita")
	lista = avisosDe(B)
	igual(lista[#lista], "Couldn't start the game. Try again.", "regreso: y avisa de que lo intente otra vez")
	igual(#m.errores, 0, `regreso: sin errores ({m.errores[1] or ""})`)
end

------------------------------------------------------------------------------------------------------------------------
-- 4. RegresoUi (lobby, cliente).
local function montarUi(movil: boolean?)
	local m = crearMundo({ proyecto = "lobby.project.json" })
	if movil then
		m.movil()
	end
	local sonados = {}
	local Ui = m.cargar("src/comun/cliente/Ui")
	local RegresoUi = m.cargar("src/lobby/cliente/RegresoUi", { Sonido = {
		precargar = function() end,
		tocar = function(nombre)
			table.insert(sonados, nombre)
		end,
	} })
	RegresoUi.start()
	m.correr(0.1)
	local cartel = Ui.hud():FindFirstChild("Regreso")
	return m, Ui, cartel, sonados, RegresoUi
end

do
	local m, Ui, cartel, sonados, RegresoUi = montarUi()
	local g = m.global
	local yo = m.jugadorLocal
	igual(cartel ~= nil, true, "ui: hay cartel")
	igual(cartel.Visible, false, "ui: sin partida abierta no se ve")
	yo:SetAttribute("PartidaAbierta", true)
	m.correr(1)
	igual(cartel.Visible, true, "ui: con partida abierta sale")
	igual(cartel.Position.Y.Offset > 0, true, "ui: ha bajado a su sitio")
	local volver = cartel:FindFirstChild("Volver")
	igual(volver and volver.Text, "GO BACK", "ui: GO BACK en mayúsculas")
	igual(cartel:FindFirstChild("Linea").Text, "Your friends are still playing.", "ui: una sola línea")
	igual(cartel:FindFirstChild("Mancha") ~= nil, true, "ui: con la esquina de sangre")
	m.clic(volver)
	m.correr(0.1)
	igual(#m.enviados("Regreso"), 1, "ui: GO BACK pide al servidor")
	igual(sonados[#sonados], "Papel", "ui: suena al pulsar")
	igual(volver.Interactable, false, "ui: se apaga un momento")
	m.clic(volver)
	igual(#m.enviados("Regreso"), 1, "ui: apagado no pide otra vez")
	m.correr(3)
	igual(volver.Interactable, true, "ui: vuelve a encenderse")
	-- El latido: dos golpes, nunca fuera de 0..1.
	local max, min = 0, 1
	for t = 0, 2.6, 0.01 do
		local f = RegresoUi.latido(t)
		max, min = math.max(max, f), math.min(min, f)
	end
	igual(max <= 1 and min >= 0 and max > 0.9, true, "ui: el latido va de 0 a 1")
	-- Sentado en un coche se va; al bajar vuelve.
	yo:SetAttribute("Coche", "Coche1")
	m.correr(1)
	igual(cartel.Visible, false, "ui: sentado en un coche se va")
	yo:SetAttribute("Coche", nil)
	m.correr(1)
	igual(cartel.Visible, true, "ui: al bajar vuelve")
	-- Sin el atributo (la partida se acabó) se va.
	yo:SetAttribute("PartidaAbierta", nil)
	m.correr(1)
	igual(cartel.Visible, false, "ui: sin partida abierta se va")
	-- Con mando, GO BACK sale elegido.
	m.pulsar(g.Enum.KeyCode.ButtonY)
	m.soltar(g.Enum.KeyCode.ButtonY)
	m.correr(0.1)
	igual(Ui.tipoEntrada(), "mando", "ui: con mando")
	local GuiService = g.game:GetService("GuiService")
	yo:SetAttribute("PartidaAbierta", true)
	m.correr(1)
	igual(GuiService.SelectedObject, volver, "ui: con mando GO BACK ya elegido")
	yo:SetAttribute("PartidaAbierta", nil)
	m.correr(1)
	igual(GuiService.SelectedObject, nil, "ui: al irse se suelta")
	-- Con Rendimiento sale sin deslizar.
	yo:SetAttribute("Rendimiento", true)
	yo:SetAttribute("PartidaAbierta", true)
	m.paso()
	igual(cartel.Visible and cartel.Position.Y.Offset > 0, true, "ui: con Rendimiento, en su sitio de golpe")
	igual(#m.errores, 0, `ui: sin errores ({m.errores[1] or ""})`)
end

do -- En el móvil GO BACK mide un dedo.
	local m, Ui, cartel = montarUi(true)
	m.jugadorLocal:SetAttribute("PartidaAbierta", true)
	m.correr(1)
	local volver = cartel:FindFirstChild("Volver")
	igual(volver.Size.Y.Offset >= Ui.DEDO, true, "ui móvil: GO BACK de un dedo")
	igual(cartel.Size.X.Offset <= 1100, true, "ui móvil: cabe en el teléfono")
	igual(#m.errores, 0, `ui móvil: sin errores ({m.errores[1] or ""})`)
end

print(`volver-tras-un-corte: {cuentas} comprobaciones bien`)
