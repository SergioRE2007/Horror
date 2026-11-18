-- Banco del guardado y las compras (16.21): Datos, Compras, Recompensas y Revivir de verdad, en servidores de mentira
-- (tests/bancos/_roblox.luau) que comparten un DataStore falso que tarda y falla. Ejecutar desde la raíz:
-- lune run tests/bancos/guardado-compras.luau (lo corre regressions.luau).
--   Datos: candado de sesión con dos servidores a la vez (el segundo espera y echa; uno caído caduca y el viejo ya no
--   escribe), guardado que falla, salir a mitad de la carga, guardados juntados y BindToClose con guardados en marcha.
--   Compras (ProcessReceipt): sin datos cargados no se entrega, el mismo recibo dos veces a la vez da una vez, solo se
--   confirma cuando ya está guardado, y si el guardado falla Roblox vuelve a preguntar sin que se dé dos veces.
--   Recompensas: un amanecer paga una vez y el premio diario no se cobra dos veces (ni volviendo a entrar ni en otro
--   servidor).
--   Revivir: la compra abierta fija a quién se revive (16.4): pulsar otro botón antes de pagar no lo cambia.
-- Lo que no hay aquí: los DataStores y MarketplaceService de verdad (cupos, reintentos de Roblox, compras reales).
local crearMundo = require("./_roblox")

local cuentas = 0
local function igual(actual, esperado, etiqueta: string)
	assert(actual == esperado, `{etiqueta}: esperado {tostring(esperado)}, recibido {tostring(actual)}`)
	cuentas += 1
end

-- Un servidor con Datos (y lo que se pida) arrancado. `nube` = el DataStore compartido.
local function servidor(nube, modulos: { string }?, antes: ((m: any) -> ())?)
	local m = crearMundo({ servidor = true, nube = nube })
	m.Config = m.cargar("src/shared/Config")
	if antes then
		antes(m)
	end
	m.Datos = m.cargar("src/comun/servidor/Datos")
	m.Datos.start()
	for _, ruta in modulos or {} do
		local nombre = string.match(ruta, "([^/]+)$") :: string
		m[nombre] = m.cargar(ruta)
		m[nombre].start()
	end
	return m
end

-- Avanza varios servidores a la vez, con el mismo reloj (os.time de cada uno sale de su mundo).
local function correr(segundos: number, ...)
	local mundos = { ... }
	for _ = 1, math.max(1, math.floor(segundos / 0.1 + 0.5)) do
		for _, m in mundos do
			m.paso(0.1)
		end
	end
end

local function guardado(nube, userId: number)
	return nube.datos["Jugadores_v1/jugador_" .. userId]
end

local function sinErrores(m, que: string)
	igual(#m.errores, 0, `{que}: sin errores ({m.errores[1] or ""})`)
end

local function expulsadoCon(m, jugador, texto: string): boolean
	for _, e in m.expulsados do
		if e.jugador == jugador and e.motivo == texto then
			return true
		end
	end
	return false
end

------------------------------------------------------------------------------------------------------------------
-- Datos: entrar, cambiar, salir.
do
	local nube = { retraso = 0.5 }
	local s = servidor(nube)
	igual(s.Config.Guardado.Almacen, "Jugadores_v1", "datos: el almacén de siempre")
	local a = s.jugador("A")
	igual(a:GetAttribute("DatosListos"), nil, "datos: cargando aún")
	igual(s.Datos.leer(a), nil, "datos: sin leer hasta cargar")
	correr(1, s)
	igual(a:GetAttribute("DatosListos"), true, "datos: cargado")
	igual(type(guardado(nube, a.UserId).candado), "table", "datos: con candado al cargar")
	igual(s.Datos.editar(a, function(d)
		d.monedas += 40
	end), true, "datos: editar")
	igual(a:GetAttribute("Monedas"), 40, "datos: publica las monedas")
	s.salir(a)
	correr(2, s)
	local g = guardado(nube, a.UserId)
	igual(g.datos.monedas, 40, "datos: guardado al salir")
	igual(g.candado, nil, "datos: al salir suelta el candado")
	igual(s.Datos.leer(a), nil, "datos: y lo olvida")
	sinErrores(s, "datos")
end

-- Datos: dos servidores a la vez con el mismo jugador.
do
	local nube = { retraso = 0.5 }
	local s1, s2 = servidor(nube), servidor(nube)
	local a1 = s1.jugador("A", 7)
	correr(1, s1, s2)
	s1.Datos.editar(a1, function(d)
		d.monedas = 100
	end)
	igual(s1.Datos.guardar ~= nil, true, "candado: Datos.guardar existe")
	local id1 = guardado(nube, 7).candado.id
	-- Entra en el otro mientras sigue en este: espera (Config.Guardado.Espera) y le echa sin tocar nada.
	local a2 = s2.jugador("A", 7)
	correr(s2.Config.Guardado.Espera + 5, s1, s2)
	igual(a2:GetAttribute("DatosListos"), nil, "candado: el segundo servidor no carga")
	igual(expulsadoCon(s2, a2, "Your save is open in another server. Try again in a minute."), true,
		"candado: y le echa con el aviso")
	igual(a2.Parent, nil, "candado: echado")
	igual(guardado(nube, 7).candado.id, id1, "candado: sigue siendo del primero")
	-- Entra otra vez en el segundo y sale del primero mientras espera: el segundo carga lo que guardó el primero.
	local b2 = s2.jugador("A", 7)
	correr(4, s1, s2)
	s1.salir(a1)
	correr(8, s1, s2)
	igual(b2:GetAttribute("DatosListos"), true, "candado: al soltarlo el primero, carga el segundo")
	igual(s2.Datos.leer(b2).monedas, 100, "candado: con lo que guardó el primero")
	igual(guardado(nube, 7).candado.id ~= id1, true, "candado: ahora es del segundo")
	sinErrores(s1, "candado")
	sinErrores(s2, "candado")
end

-- Datos: un servidor caído (deja de renovar el candado) y vuelve cuando otro ya tiene la partida.
do
	local nube = { retraso = 0.2 }
	local s1, s2 = servidor(nube), servidor(nube)
	local a1 = s1.jugador("A", 9)
	correr(1, s1, s2)
	s1.Datos.editar(a1, function(d)
		d.monedas = 5
	end)
	-- s1 se queda parado (no avanza su reloj): el candado caduca para s2.
	correr(s2.Config.Guardado.Caduca + 10, s2)
	local a2 = s2.jugador("A", 9)
	correr(s2.Config.Guardado.Espera, s2)
	igual(a2:GetAttribute("DatosListos"), true, "caído: el candado caducado se coge")
	igual(s2.Datos.leer(a2).monedas, 0, "caído: lo guardado (lo de s1 sin guardar no estaba)")
	s2.Datos.editar(a2, function(d)
		d.monedas = 300
	end)
	local ok = nil
	s2.task.spawn(function()
		ok = s2.Datos.guardar(a2)
	end)
	correr(1, s2)
	igual(ok, true, "caído: el nuevo guarda")
	-- s1 vuelve: su guardado automático ve que ya no es suya, no escribe y le echa.
	correr(s1.Config.Guardado.Intervalo + 2, s1, s2)
	igual(guardado(nube, 9).datos.monedas, 300, "caído: el viejo no pisa lo del nuevo")
	igual(expulsadoCon(s1, a1, "Your save was opened in another server."), true, "caído: el viejo echa al jugador")
	igual(s1.Datos.leer(a1), nil, "caído: y deja de guardar")
	sinErrores(s1, "caído")
	sinErrores(s2, "caído")
end

-- Datos: guardados que fallan.
do
	local nube = { retraso = 0.2 }
	local s = servidor(nube)
	local a = s.jugador("A")
	correr(1, s)
	s.Datos.editar(a, function(d)
		d.monedas = 10
	end)
	nube.falla = true
	local ok = nil
	s.task.spawn(function()
		ok = s.Datos.guardar(a)
	end)
	correr(1, s)
	igual(ok, false, "fallo: guardar sin red da false")
	igual(guardado(nube, a.UserId).datos, nil, "fallo: y no ha escrito (jugador nuevo: aún sin datos)")
	nube.falla = false
	s.task.spawn(function()
		ok = s.Datos.guardar(a)
	end)
	correr(1, s)
	igual(ok, true, "fallo: con red otra vez, guarda (no se quedó a medias)")
	igual(guardado(nube, a.UserId).datos.monedas, 10, "fallo: lo de antes")
	-- Al salir reintenta (Config.Guardado.Intentos): dos fallos y el tercero bien.
	s.Datos.editar(a, function(d)
		d.monedas = 20
	end)
	nube.falla = s.Config.Guardado.Intentos - 1
	s.salir(a)
	correr(s.Config.Guardado.Reintento * s.Config.Guardado.Intentos + 2, s)
	igual(guardado(nube, a.UserId).datos.monedas, 20, "fallo: al salir, reintenta hasta guardarlo")
	igual(guardado(nube, a.UserId).candado, nil, "fallo: y suelta el candado")
	-- Escrito pero sin respuesta: lo reintenta y el candado (el mismo id) le deja.
	local b = s.jugador("B")
	correr(1, s)
	s.Datos.editar(b, function(d)
		d.monedas = 33
	end)
	nube.pierde = 1
	s.salir(b)
	correr(s.Config.Guardado.Reintento * 2 + 2, s)
	igual(guardado(nube, b.UserId).datos.monedas, 33, "fallo: respuesta perdida, guardado igual")
	igual(guardado(nube, b.UserId).candado, nil, "fallo: respuesta perdida, candado suelto al reintentar")
	sinErrores(s, "fallo")
end

-- Datos: salir a mitad de la carga (también al cerrar el servidor).
do
	local nube = { retraso = 2 }
	local s = servidor(nube)
	local a = s.jugador("A")
	correr(0.5, s)
	s.salir(a)
	correr(5, s)
	local g = guardado(nube, a.UserId)
	igual(g ~= nil and g.candado, nil, "a medias: al acabar la carga suelta el candado")
	igual(s.Datos.leer(a), nil, "a medias: no se queda con los datos")
	igual(a:GetAttribute("DatosListos"), nil, "a medias: no publica nada")
	-- El cierre espera a la carga a medias.
	local b = s.jugador("B")
	correr(0.5, s)
	local listo = s.cerrar()
	s.salir(b)
	correr(0.5, s)
	igual(listo(), false, "a medias: el cierre espera a la carga")
	correr(5, s)
	igual(listo(), true, "a medias: y acaba")
	igual(guardado(nube, b.UserId).candado, nil, "a medias: cerrando, el candado también se suelta")
	sinErrores(s, "a medias")
end

-- Datos: guardados juntados (pulsar mucho algo que guarda) y BindToClose con guardados en marcha.
do
	local nube = { retraso = 1 }
	local s = servidor(nube)
	local a, b = s.jugador("A"), s.jugador("B")
	correr(2, s)
	local antes = nube.llamadas
	local resultados = {}
	for i = 1, 10 do
		s.task.spawn(function()
			resultados[i] = s.Datos.guardar(a)
		end)
	end
	correr(4, s)
	igual(nube.llamadas - antes, 2, "juntar: diez guardados seguidos son dos peticiones")
	local todos = true
	for i = 1, 10 do
		todos = todos and resultados[i] == true
	end
	igual(todos, true, "juntar: y todos dicen que ha guardado")
	-- Cierre: un guardado normal en marcha, cambios después, y los dos jugadores.
	s.Datos.editar(a, function(d)
		d.monedas = 1
	end)
	s.task.spawn(s.Datos.guardar, a)
	correr(0.3, s)
	s.Datos.editar(a, function(d)
		d.monedas = 2
	end)
	s.Datos.editar(b, function(d)
		d.monedas = 3
	end)
	local listo = s.cerrar()
	-- Roblox también echa a todos al cerrar (PlayerRemoving guarda a la vez que BindToClose).
	s.salir(a)
	s.salir(b)
	correr(s.Config.Guardado.Cierre, s)
	igual(listo(), true, "cierre: acaba antes de Config.Guardado.Cierre")
	igual(guardado(nube, a.UserId).datos.monedas, 2, "cierre: lo último de A guardado")
	igual(guardado(nube, a.UserId).candado, nil, "cierre: A suelto")
	igual(guardado(nube, b.UserId).datos.monedas, 3, "cierre: B guardado")
	igual(guardado(nube, b.UserId).candado, nil, "cierre: B suelto")
	sinErrores(s, "cierre")
end

------------------------------------------------------------------------------------------------------------------
-- Compras: ProcessReceipt.
local PAQUETE = 101
local function conIds(m)
	m.Config.Compras.Monedas[1].Id = PAQUETE
	m.Config.Compras.Revivir.Id = 555
end
local function recibo(m, jugador, compra: string, producto: number?)
	local r = { decision = nil }
	m.task.spawn(function()
		r.decision = m.servicio("MarketplaceService").ProcessReceipt({
			PlayerId = jugador.UserId, ProductId = producto or PAQUETE, PurchaseId = compra, CurrencySpent = 49,
			PlaceIdWherePurchased = 0, CurrencyType = m.global.Enum.CurrencyType.Robux,
		})
	end)
	return r
end
do
	local D = crearMundo({ servidor = true }).global.Enum.ProductPurchaseDecision
	local nube = { retraso = 1 }
	local s = servidor(nube, { "src/comun/servidor/Compras" }, conIds)
	local monedas = s.Config.Compras.Monedas[1].Monedas
	local a = s.jugador("A")
	-- Sin datos cargados: aún no.
	local r0 = recibo(s, a, "c0")
	correr(0.2, s)
	igual(r0.decision, D.NotProcessedYet, "recibo: sin datos cargados, NotProcessedYet")
	correr(2, s)
	igual(s.Datos.leer(a).monedas, 0, "recibo: y no ha dado nada")
	-- El mismo recibo dos veces a la vez (Roblox pregunta otra vez mientras el guardado tarda): se da una vez.
	local r1, r2 = recibo(s, a, "c1"), recibo(s, a, "c1")
	correr(0.5, s)
	igual(r1.decision, nil, "recibo: no se confirma antes de guardar")
	igual(r2.decision, nil, "recibo: el repetido tampoco")
	local guardadoAlConfirmar = nil
	while r1.decision == nil do
		correr(0.1, s)
		if r1.decision ~= nil then
			guardadoAlConfirmar = guardado(nube, a.UserId).datos.compras.c1
		end
	end
	correr(3, s)
	igual(r1.decision, D.PurchaseGranted, "recibo: entregado")
	igual(r2.decision, D.PurchaseGranted, "recibo: el repetido, también entregado")
	igual(guardadoAlConfirmar ~= nil, true, "recibo: al confirmar ya estaba guardado")
	igual(s.Datos.leer(a).monedas, monedas, "recibo: monedas una sola vez")
	igual(guardado(nube, a.UserId).datos.monedas, monedas, "recibo: y guardadas")
	-- Roblox vuelve a preguntar más tarde por el mismo: confirmado otra vez sin dar nada.
	local r3 = recibo(s, a, "c1")
	correr(3, s)
	igual(r3.decision, D.PurchaseGranted, "recibo: repetido luego, entregado")
	igual(s.Datos.leer(a).monedas, monedas, "recibo: repetido luego, sin dar más")
	-- Guardado que falla: NotProcessedYet; al volver a preguntar (con red) se confirma sin darlo otra vez.
	nube.falla = true
	local r4 = recibo(s, a, "c2")
	correr(3, s)
	igual(r4.decision, D.NotProcessedYet, "recibo: sin guardar, NotProcessedYet")
	nube.falla = false
	local r5 = recibo(s, a, "c2")
	correr(3, s)
	igual(r5.decision, D.PurchaseGranted, "recibo: con red, entregado")
	igual(s.Datos.leer(a).monedas, monedas * 2, "recibo: el que falló se da una vez")
	-- Un jugador que no está en este servidor y un producto que no es nuestro: aún no.
	local otro = s.jugador("B")
	correr(2, s)
	s.salir(otro)
	correr(2, s)
	local r6, r7 = recibo(s, otro, "c3"), recibo(s, a, "c4", 999)
	correr(1, s)
	igual(r6.decision, D.NotProcessedYet, "recibo: jugador que no está, NotProcessedYet")
	igual(r7.decision, D.NotProcessedYet, "recibo: producto desconocido, NotProcessedYet")
	-- Un revivir pagado que llega aquí sin encargo (el lobby): monedas de Config.Compras.Reembolso.
	local r8 = recibo(s, a, "c5", 555)
	correr(3, s)
	igual(r8.decision, D.PurchaseGranted, "recibo: revivir sin encargo, entregado")
	igual(s.Datos.leer(a).monedas, monedas * 2 + s.Config.Compras.Reembolso, "recibo: revivir sin encargo, en monedas")
	-- Salir con el guardado de un recibo en marcha: el de salida lo lleva dentro y se confirma.
	local r9 = recibo(s, a, "c6")
	correr(0.3, s)
	s.salir(a)
	correr(s.Config.Guardado.Reintento * 3 + 3, s)
	igual(r9.decision, D.PurchaseGranted, "recibo: saliendo, entregado")
	igual(guardado(nube, a.UserId).datos.compras.c6 ~= nil, true, "recibo: saliendo, guardado con la compra")
	igual(guardado(nube, a.UserId).datos.monedas, monedas * 3 + s.Config.Compras.Reembolso, "recibo: saliendo, monedas")
	sinErrores(s, "recibo")
end

------------------------------------------------------------------------------------------------------------------
-- Recompensas: amanecer y premio diario.
do
	local nube = { retraso = 0.5 }
	local s1 = servidor(nube, { "src/comun/servidor/Recompensas" })
	local R = s1.Config.Recompensas
	local a = s1.jugador("A", 3)
	correr(3, s1)
	igual(s1.Datos.leer(a).monedas, R.Diario, "premios: el diario al entrar")
	igual(guardado(nube, 3).datos.monedas, R.Diario, "premios: y guardado ya")
	-- La noche 1 superada: paga una vez aunque el cambio de fase llegue repetido.
	local paga = R.Noche
	for _, logro in R.Logros do
		if logro.Noche and logro.Noche <= 1 then
			paga += logro.Monedas
		end
	end
	s1.Recompensas.fase("Dia", 1)
	s1.Recompensas.fase("Noche", 1)
	s1.Recompensas.fase("Dia", 2)
	s1.Recompensas.fase("Dia", 2)
	correr(1, s1)
	igual(s1.Datos.leer(a).monedas, R.Diario + paga, "premios: la noche superada, una vez")
	-- Mueren todos: se vuelve al día de antes, eso no paga otra vez.
	s1.Recompensas.fase("Noche", 2)
	s1.Recompensas.fase("Dia", 2)
	correr(1, s1)
	igual(s1.Datos.leer(a).monedas, R.Diario + paga, "premios: volver al día tras morir todos no paga")
	local total = s1.Datos.leer(a).monedas
	-- Sale y vuelve a entrar (aquí y en otro servidor) el mismo día: sin diario.
	s1.salir(a)
	correr(3, s1)
	local a2 = s1.jugador("A", 3)
	correr(3, s1)
	igual(s1.Datos.leer(a2).monedas, total, "premios: volver a entrar no da otro diario")
	s1.salir(a2)
	correr(3, s1)
	local s2 = servidor(nube, { "src/comun/servidor/Recompensas" })
	local a3 = s2.jugador("A", 3)
	correr(3, s1, s2)
	igual(s2.Datos.leer(a3).monedas, total, "premios: en otro servidor tampoco")
	-- Al día siguiente, sí.
	s2.salir(a3)
	correr(R.Cada + 5, s1, s2)
	local a4 = s2.jugador("A", 3)
	correr(3, s1, s2)
	igual(s2.Datos.leer(a4).monedas, total + R.Diario, "premios: al día siguiente, otra vez")
	sinErrores(s1, "premios")
	sinErrores(s2, "premios")
end

------------------------------------------------------------------------------------------------------------------
-- Revivir: la compra abierta fija a quién se revive.
do
	local D = crearMundo({ servidor = true }).global.Enum.ProductPurchaseDecision
	local fase, alCambiar = "Dia", {}
	local revividos = {}
	local s = servidor({}, { "src/comun/servidor/Compras", "src/juego/servidor/Revivir" }, function(m)
		conIds(m)
		m.falso("src/juego/servidor/Ciclo", {
			fase = function()
				return fase
			end,
			alCambiar = function(fn)
				table.insert(alCambiar, fn)
			end,
		})
		m.falso("src/juego/servidor/Muerte", {
			revivir = function(j)
				j:SetAttribute("Muerto", nil)
				table.insert(revividos, j)
			end,
		})
	end)
	local function cambiar(nueva: string)
		fase = nueva
		for _, fn in alCambiar do
			fn(nueva)
		end
	end
	local Remotes = s.cargar("src/shared/Remotes")
	local MPS = s.servicio("MarketplaceService")
	local comprador, b, c, d = s.jugador("A"), s.jugador("B"), s.jugador("C"), s.jugador("D")
	correr(2, s)
	for _, j in { b, c, d } do
		j:SetAttribute("Muerto", true)
	end
	cambiar("Noche")
	igual(b:GetAttribute("Revivible"), true, "revivir: de noche y muerto, se puede")
	local function pedir(objetivo)
		Remotes.Compra.OnServerEvent:Fire(comprador, "Revivir", objetivo)
		correr(s.Config.Limites.Compra + 0.2, s) -- (Config.Limites.Compra entre una petición y otra)
	end
	local function abiertas(): number
		local n = 0
		for _, compra in s.compras do
			if compra[1] == "Producto" and compra[2] == comprador and compra[3] == 555 then
				n += 1
			end
		end
		return n
	end
	pedir(b)
	igual(abiertas(), 1, "revivir: abre la compra")
	pedir(c)
	igual(abiertas(), 1, "revivir: otro botón con la compra abierta no abre otra")
	pedir(b)
	igual(abiertas(), 2, "revivir: el mismo, sí (se vuelve a abrir)")
	MPS.PromptProductPurchaseFinished:Fire(comprador.UserId, 555, true)
	pedir(c)
	igual(abiertas(), 2, "revivir: pagada y sin recibo, otro botón tampoco")
	local r = recibo(s, comprador, "rev1", 555)
	correr(3, s)
	igual(r.decision, D.PurchaseGranted, "revivir: entregado")
	igual(revividos[1], b, "revivir: revive al de la compra abierta, no al último botón")
	igual(#revividos, 1, "revivir: a uno solo")
	igual(c:GetAttribute("Muerto"), true, "revivir: el otro sigue muerto")
	-- Cerrar sin pagar libera: el siguiente botón abre la suya.
	pedir(c)
	igual(abiertas(), 3, "revivir: tras entregar, se abre otra")
	MPS.PromptProductPurchaseFinished:Fire(comprador.UserId, 555, false)
	pedir(d)
	igual(abiertas(), 4, "revivir: cerrada sin pagar, el siguiente botón abre la suya")
	-- Pagada, pero amanece antes del recibo: monedas en su lugar.
	MPS.PromptProductPurchaseFinished:Fire(comprador.UserId, 555, true)
	local antes = s.Datos.leer(comprador).monedas
	cambiar("Dia")
	local r2 = recibo(s, comprador, "rev2", 555)
	correr(3, s)
	igual(r2.decision, D.PurchaseGranted, "revivir: de día, entregado igual")
	igual(#revividos, 1, "revivir: de día no revive")
	igual(s.Datos.leer(comprador).monedas, antes + s.Config.Compras.Reembolso, "revivir: de día, en monedas")
	sinErrores(s, "revivir")
end

print(`guardado-compras: {cuentas} comprobaciones bien`)
