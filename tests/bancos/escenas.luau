-- Banco de las escenas finales y la cámara (14.9): EscenaFinal del jugador (lo ponen HuidaVista e IncendioVista
-- mientras llevan la cámara) es lo que dice "hay una escena", no la cámara en Scriptable (también lo es escondido y
-- por la mirilla) ni Final de workspace (en el incendio se pone ~17 s antes de la escena, mientras corre el fuego).
-- Carga MovilUi y MochilaUi de verdad con el Roblox de mentira (tests/bancos/_roblox.luau):
--   El móvil: se abre escondido (cámara Scriptable) y sigue abierto al esconderte; no se abre en la escena y se guarda
--   al empezar.
--   La mochila: se abre mirando por la mirilla o las cortinas (Vistazo, cámara Scriptable); no en la escena y se cierra
--   al empezar.
-- Ejecutar desde la raíz: lune run tests/bancos/escenas.luau (lo corre regressions.luau).
local crearMundo = require("./_roblox")

local cuentas = 0
local function igual(actual, esperado, etiqueta: string)
	assert(actual == esperado, `{etiqueta}: esperado {tostring(esperado)}, recibido {tostring(actual)}`)
	cuentas += 1
end

local m = crearMundo()
local g = m.global
local CFrame, Enum = g.CFrame, g.Enum
local jugador = m.jugadorLocal
local camara = m.camara

local MovilUi = m.cargar("src/juego/cliente/MovilUi")
local MochilaUi = m.cargar("src/juego/cliente/MochilaUi")
MovilUi.start()
MochilaUi.start()
m.correr(0.3)

-- Lo último que se ha pedido por un remoto (o nil).
local function ultimo(nombre: string): any
	local lista = m.enviados(nombre)
	return lista[#lista]
end
local function pedidos(nombre: string): number
	return #m.enviados(nombre)
end

-- El móvil ---------------------------------------------------------------------------------------------------------
do
	-- Abierto y te escondes (cámara del escondite, Scriptable): sigue abierto.
	jugador:SetAttribute("MovilAbierto", true) -- lo que pone el servidor (Movil.pedir)
	m.correr(0.2)
	jugador:SetAttribute("Escondido", CFrame.new(0, 3, 0))
	camara.CameraType = Enum.CameraType.Scriptable
	m.correr(0.2)
	igual(pedidos("Movil"), 0, "móvil: al esconderte no se guarda")
	-- Escondido, lo cierras y lo vuelves a abrir con M.
	m.pulsar(Enum.KeyCode.M)
	m.correr(0.1)
	igual(ultimo("Movil") and ultimo("Movil")[1], false, "móvil: escondido se guarda con M")
	jugador:SetAttribute("MovilAbierto", nil)
	m.correr(0.1)
	m.pulsar(Enum.KeyCode.M)
	m.correr(0.1)
	igual(ultimo("Movil") and ultimo("Movil")[1], true, "móvil: escondido se saca con M")
	jugador:SetAttribute("MovilAbierto", true)
	m.correr(0.1)
	jugador:SetAttribute("Escondido", nil)
	camara.CameraType = Enum.CameraType.Custom
	m.correr(0.1)

	-- Empieza la escena con el móvil en la mano: se guarda.
	local antes = pedidos("Movil")
	jugador:SetAttribute("EscenaFinal", true)
	camara.CameraType = Enum.CameraType.Scriptable
	m.correr(0.1)
	igual(pedidos("Movil"), antes + 1, "móvil: al empezar la escena se guarda")
	igual(ultimo("Movil")[1], false, "móvil: y se pide guardarlo")
	jugador:SetAttribute("MovilAbierto", nil)
	m.correr(0.1)
	-- En la escena, M no lo saca.
	antes = pedidos("Movil")
	m.pulsar(Enum.KeyCode.M)
	m.correr(0.1)
	igual(pedidos("Movil"), antes, "móvil: en la escena no se saca")
	jugador:SetAttribute("EscenaFinal", nil)
	camara.CameraType = Enum.CameraType.Custom
	m.correr(0.1)
end

-- La mochila -------------------------------------------------------------------------------------------------------
do
	local function abiertaPedida(): boolean?
		local u = ultimo("Mochila")
		return u and u[1] == "Abrir" and u[2]
	end
	-- Por la mirilla (Vistazo, cámara Scriptable): se abre (MirarVista deja de mirar con MochilaAbierta).
	jugador:SetAttribute("Vistazo", "Mirilla")
	camara.CameraType = Enum.CameraType.Scriptable
	m.correr(0.1)
	m.pulsar(Enum.KeyCode.B)
	m.correr(0.1)
	igual(abiertaPedida(), true, "mochila: por la mirilla se abre")
	jugador:SetAttribute("MochilaAbierta", true)
	jugador:SetAttribute("Vistazo", nil)
	camara.CameraType = Enum.CameraType.Custom
	m.correr(0.4)
	m.pulsar(Enum.KeyCode.B)
	m.correr(0.1)
	igual(abiertaPedida(), false, "mochila: y se cierra con B")
	jugador:SetAttribute("MochilaAbierta", nil)
	m.correr(0.4)

	-- Abierta y empieza la escena: se cierra.
	m.pulsar(Enum.KeyCode.B)
	m.correr(0.1)
	igual(abiertaPedida(), true, "mochila: fuera de la escena se abre")
	jugador:SetAttribute("MochilaAbierta", true)
	m.correr(0.4)
	jugador:SetAttribute("EscenaFinal", true)
	camara.CameraType = Enum.CameraType.Scriptable
	m.correr(0.1)
	igual(abiertaPedida(), false, "mochila: al empezar la escena se cierra")
	jugador:SetAttribute("MochilaAbierta", nil)
	m.correr(0.4)
	-- En la escena, B no la abre.
	local antes = pedidos("Mochila")
	m.pulsar(Enum.KeyCode.B)
	m.correr(0.1)
	igual(pedidos("Mochila"), antes, "mochila: en la escena no se abre")
	jugador:SetAttribute("EscenaFinal", nil)
	camara.CameraType = Enum.CameraType.Custom
	m.correr(0.1)
end

igual(#m.errores, 0, "sin errores " .. table.concat(m.errores, "\n"))
print(`escenas: {cuentas} comprobaciones bien`)
