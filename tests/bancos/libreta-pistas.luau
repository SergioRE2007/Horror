-- Banco de la libreta de pistas y el aviso del plano de la reja. Ejecutar desde la raíz:
-- lune run tests/bancos/libreta-pistas.luau (lo corre tests/regressions.luau).
--   Servidor (Pistas de verdad, con Casa de mentira): PistasLeidas ("1,2,9", en orden) al empezar, leer e importar; a
--   los demás, un aviso al encontrar una nueva (no al releerla); el del plano, a todos, una vez y tras
--   Config.Bestia.AvisoPlano, y no si se ha vuelto al amanecer mientras tanto.
--   Cliente (PistasUi de verdad): la libreta empieza por la última encontrada, < y > (y LB/RB) pasan y dan la vuelta,
--   "n de total" con las leídas, el alto no cambia al pasar, no se cierra lejos de la pista, Escape y B del mando la
--   cierran y leer así no manda nada al servidor.
--   Mochila (MochilaUi de verdad, PistasUi de mentira): NOTAS solo con alguna leída; N la guarda y abre la libreta.
local crearMundo = require("./_roblox")

local cuentas = 0
local function igual(actual, esperado, etiqueta: string)
	assert(actual == esperado, `{etiqueta}: esperado {tostring(esperado)}, recibido {tostring(actual)}`)
	cuentas += 1
end

do -- El servidor.
	local m = crearMundo({ servidor = true })
	local g = m.global
	local mapa = g.Instance.new("Folder")
	mapa.Name = "Mapa"
	mapa.Parent = m.workspace
	local Config = m.cargar("src/shared/Config")
	local Pistas = m.cargar("src/juego/servidor/Pistas", { Casa = { cerradas = function()
		return {}
	end } })
	local remoto = m.cargar("src/shared/Remotes").Pista
	local function enviados(): { any }
		return m.interno(remoto)._enviados or {}
	end
	local function avisosA(nombre: string): { string }
		local l = {}
		for _, p in enviados() do
			if p.quien == nombre and p[1] == "Aviso" then
				table.insert(l, p[2])
			end
		end
		return l
	end
	Pistas.start()
	igual(m.workspace:GetAttribute("PistasLeidas"), "", "servidor: al empezar, ninguna")
	local a, b = m.jugador("A"), m.jugador("B")
	a:LoadCharacter()
	b:LoadCharacter()
	m.correr(0.2)
	local raiz = a.Character:FindFirstChild("HumanoidRootPart")
	local aqui = m.caja(raiz.Position + g.Vector3.new(0, 0, 2), g.Vector3.new(1, 0.1, 1), { CanCollide = false })
	local function leer(n: number)
		aqui.Position = raiz.Position + g.Vector3.new(0, 0, 2) -- junto al personaje (que ha podido caer al suelo)
		Pistas.leer(a, n, aqui)
		m.correr(0.35) -- más que los 0,3 s entre lecturas
	end
	leer(2)
	leer(1)
	igual(m.workspace:GetAttribute("PistasLeidas"), "1,2", "servidor: las leídas, en orden")
	igual(#avisosA("B"), 2, "servidor: B se entera de las dos")
	igual(#avisosA("A"), 0, "servidor: quien la lee no recibe el aviso")
	igual(string.find(avisosA("B")[1], "A", 1, true) ~= nil, true, "servidor: el aviso lleva el nombre")
	leer(1)
	igual(#avisosA("B"), 2, "servidor: releer una no avisa otra vez")
	local plano = Config.Bestia.Reja.Pista
	leer(plano)
	local antes = #avisosA("A")
	m.correr(Config.Bestia.AvisoPlano - 0.5)
	igual(#avisosA("A"), antes, "servidor: el aviso del plano espera a que salga el papel")
	m.correr(0.6)
	igual(#avisosA("A"), antes + 1, "servidor: al rato, el del plano a quien la lee")
	igual(#avisosA("B"), 4, "servidor: y a los demás (más el de que la ha encontrado)")
	igual(Pistas.leida(plano), true, "servidor: la reja ya sale en el banco")
	leer(plano)
	m.correr(Config.Bestia.AvisoPlano + 0.2)
	igual(#avisosA("A"), antes + 1, "servidor: el del plano, una sola vez")
	-- Vuelta al amanecer justo después de leerla: no hay aviso de una reja que ya no se puede hacer.
	Pistas.importar({})
	igual(m.workspace:GetAttribute("PistasLeidas"), "", "servidor: importar vacío publica ninguna")
	leer(plano)
	Pistas.importar({ 3 })
	m.correr(Config.Bestia.AvisoPlano + 0.2)
	igual(#avisosA("A"), antes + 1, "servidor: sin aviso del plano si se ha perdido al volver al amanecer")
	Pistas.importar({ 12, 3, 99 })
	igual(m.workspace:GetAttribute("PistasLeidas"), "3,12", "servidor: lo cargado, en orden y solo las que existen")
	igual(#m.errores, 0, "servidor: sin errores " .. table.concat(m.errores, "\n"))
end

do -- El cliente.
	local m = crearMundo()
	if not m.jugadorLocal.Character then
		m.personaje(m.global.CFrame.new(0, 5, 0), m.jugadorLocal)
	end
	local Historia = m.cargar("src/shared/Historia")
	m.workspace:SetAttribute("PistasLeidas", "1,2")
	local PistasUi = m.cargar("src/juego/cliente/PistasUi")
	PistasUi.start()
	m.correr(0.2)
	local panel = m.jugadorLocal.PlayerGui:FindFirstChild("Hud"):FindFirstChild("Pista")
	local function cuenta(): string
		local mejor = ""
		for _, h in panel:GetChildren() do
			if h:IsA("TextLabel") and string.find(h.Text, " of ", 1, true) then
				mejor = h.Text
			end
		end
		return mejor
	end
	local function titulo(): string
		for _, h in panel:GetChildren() do
			if h:IsA("TextLabel") and h.Position.Y.Offset == 22 then
				return h.Text
			end
		end
		return ""
	end
	-- Otro encuentra la 9: la libreta empieza por ella.
	m.workspace:SetAttribute("PistasLeidas", "1,2,9")
	m.correr(0.1)
	PistasUi.libreta()
	m.correr(0.3)
	igual(panel.Visible, true, "cliente: la libreta se abre")
	igual(PistasUi.libretaAbierta(), true, "cliente: libretaAbierta")
	igual(titulo(), string.upper(Historia[9].que), "cliente: empieza por la última encontrada")
	igual(cuenta(), "3 of 3", "cliente: n de las leídas")
	local alto = panel.Size.Y.Offset
	m.pulsar(m.global.Enum.KeyCode.Right)
	m.soltar(m.global.Enum.KeyCode.Right)
	igual(cuenta(), "1 of 3", "cliente: > de la última da la vuelta")
	igual(panel.Size.Y.Offset, alto, "cliente: el papel no cambia de alto al pasar (las flechas no se mueven)")
	m.pulsar(m.global.Enum.KeyCode.ButtonL1)
	m.soltar(m.global.Enum.KeyCode.ButtonL1)
	igual(cuenta(), "3 of 3", "cliente: LB pasa hacia atrás")
	m.pulsar(m.global.Enum.KeyCode.ButtonR1)
	m.soltar(m.global.Enum.KeyCode.ButtonR1)
	igual(cuenta(), "1 of 3", "cliente: RB pasa hacia delante")
	-- Lejos de cualquier pista (aquí no hay ninguna en el mundo) y un rato: sigue abierta.
	m.jugadorLocal.Character:PivotTo(m.global.CFrame.new(500, 5, 500))
	m.correr(1.5)
	igual(panel.Visible, true, "cliente: la libreta no se cierra por distancia")
	m.pulsar(m.global.Enum.KeyCode.ButtonB)
	m.correr(0.1)
	m.soltar(m.global.Enum.KeyCode.ButtonB)
	igual(panel.Visible, false, "cliente: B del mando la cierra")
	PistasUi.libreta()
	m.correr(0.1)
	m.pulsar(m.global.Enum.KeyCode.Escape)
	m.correr(0.1)
	m.soltar(m.global.Enum.KeyCode.Escape)
	igual(panel.Visible, false, "cliente: Escape la cierra")
	-- Sin leídas no se abre; leer así no manda nada.
	m.workspace:SetAttribute("PistasLeidas", "")
	m.correr(0.1)
	PistasUi.libreta()
	igual(panel.Visible, false, "cliente: sin leídas no hay libreta")
	local mandados = 0
	for _, p in m.enviados("Pista") do
		if p.quien == "servidor" then
			mandados += 1
		end
	end
	igual(mandados, 0, "cliente: la libreta no le pide nada al servidor")
	-- El aviso de las pistas con el papel abierto no lo tapa.
	m.workspace:SetAttribute("PistasLeidas", "4")
	m.correr(0.1)
	PistasUi.libreta()
	m.correr(0.3)
	m.alCliente("Pista", "Aviso", "B found a note. It's in your backpack.")
	m.correr(0.1)
	igual(#m.errores, 0, "cliente: sin errores " .. table.concat(m.errores, "\n"))
end

do -- La mochila: NOTAS solo con alguna leída; N (o el botón) guarda la mochila y abre la libreta.
	local m = crearMundo()
	if not m.jugadorLocal.Character then
		m.personaje(m.global.CFrame.new(0, 5, 0), m.jugadorLocal)
	end
	m.workspace:SetAttribute("PistasLeidas", "")
	local abiertas = 0
	local MochilaUi = m.cargar("src/juego/cliente/MochilaUi", { PistasUi = {
		libreta = function()
			abiertas += 1
		end,
		libretaAbierta = function()
			return false
		end,
		cerrar = function() end,
	} })
	MochilaUi.start()
	m.correr(0.2)
	local raiz = m.jugadorLocal.PlayerGui:FindFirstChild("Hud"):FindFirstChild("Mochila")
	local notas
	for _, d in raiz:GetDescendants() do
		if d:IsA("TextButton") and string.find(d.Text, "NOTES", 1, true) then
			notas = d
		end
	end
	igual(notas ~= nil, true, "mochila: hay botón NOTES")
	igual(notas.Visible, false, "mochila: sin leídas no sale")
	m.workspace:SetAttribute("PistasLeidas", "1")
	m.correr(0.1)
	igual(notas.Visible, true, "mochila: con una leída sale")
	m.pulsar(m.global.Enum.KeyCode.B)
	m.soltar(m.global.Enum.KeyCode.B)
	m.correr(0.5)
	igual(raiz.Visible, true, "mochila: B la abre")
	m.pulsar(m.global.Enum.KeyCode.N)
	m.soltar(m.global.Enum.KeyCode.N)
	m.correr(0.5)
	igual(abiertas, 1, "mochila: N abre la libreta")
	igual(raiz.Visible, false, "mochila: y se guarda la mochila")
	m.pulsar(m.global.Enum.KeyCode.N)
	m.soltar(m.global.Enum.KeyCode.N)
	igual(abiertas, 1, "mochila: N con la mochila cerrada no hace nada")
	igual(#m.errores, 0, "mochila: sin errores " .. table.concat(m.errores, "\n"))
end

print(`libreta-pistas: {cuentas} comprobaciones bien`)
