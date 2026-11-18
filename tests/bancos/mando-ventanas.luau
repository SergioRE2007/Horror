-- Banco de la selección del mando en las ventanas (docs/sistemas/movil.md). Ejecutar desde la raíz:
-- lune run tests/bancos/mando-ventanas.luau (lo corre tests/regressions.luau). Con el Roblox de mentira:
--   Ui.seleccionar solo elige con mando y botones a la vista; Ui.soltarSeleccion solo suelta lo de su panel; el borde
--   del mando es el del juego (hueso, 3 px).
--   Pistas: con mando sale CERRAR elegido; B la cierra sin agachar (VentanaAbierta sigue en esa pulsación) y no queda
--   nada elegido.
--   Vendedor: sale elegido el primer trato que se puede pagar (si ninguno, CERRAR); B lo cierra y suelta.
--   Coche del lobby: el dueño sale con EMPEZAR elegido; al bajar se suelta.
-- Si algo no se cumple, termina con error.
local crearMundo = require("./_roblox")

local cuentas = 0
local function comprueba(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end

local function pulsar(m, tecla)
	m.pulsar(tecla)
	m.soltar(tecla)
	m.correr(0.05)
end

-- Ui sola.
do
	local m = crearMundo()
	local g = m.global
	local Ui = m.cargar("src/comun/cliente/Ui")
	local GuiService = g.game:GetService("GuiService")
	local hud = Ui.hud()
	local marca = m.jugadorLocal:FindFirstChildOfClass("PlayerGui").SelectionImageObject
	comprueba(marca ~= nil and marca:IsA("Frame") and marca.BackgroundTransparency == 1, "borde del mando: marco vacío")
	local trazo = marca and marca:FindFirstChildOfClass("UIStroke")
	comprueba(trazo and trazo.Thickness == 3 and trazo.Color == Ui.Color.Hueso, "borde del mando: hueso de 3 px")

	local panel = g.Instance.new("Frame")
	panel.Parent = hud
	local boton = Ui.boton("Ok")
	boton.Parent = panel
	local otroPanel = g.Instance.new("Frame")
	otroPanel.Parent = hud
	local otro = Ui.boton("Otro")
	otro.Parent = otroPanel

	Ui.seleccionar(boton)
	comprueba(GuiService.SelectedObject == nil, "con teclado no se elige nada")
	Ui.seleccionar(boton, true)
	comprueba(GuiService.SelectedObject == boton, "con `siempre` (R3 de Ajustes) sí")
	GuiService.SelectedObject = nil
	pulsar(m, g.Enum.KeyCode.ButtonY) -- pasa a mando
	comprueba(Ui.tipoEntrada() == "mando", "ya con mando")
	panel.Visible = false
	Ui.seleccionar(boton)
	comprueba(GuiService.SelectedObject == nil, "botón con su panel escondido: no se elige")
	panel.Visible = true
	boton.Selectable = false
	Ui.seleccionar(boton)
	comprueba(GuiService.SelectedObject == nil, "botón no seleccionable: no se elige")
	boton.Selectable = true
	Ui.seleccionar(boton)
	comprueba(GuiService.SelectedObject == boton, "con mando se elige")
	Ui.soltarSeleccion(otroPanel)
	comprueba(GuiService.SelectedObject == boton, "soltar otro panel no lo quita")
	Ui.soltarSeleccion(panel)
	comprueba(GuiService.SelectedObject == nil, "soltar su panel lo quita")

	-- mantenerSeleccion: lo de otra ventana a la vista se respeta; lo escondido se cambia por lo principal.
	GuiService.SelectedObject = otro
	Ui.mantenerSeleccion(panel, function()
		return boton
	end)
	comprueba(GuiService.SelectedObject == otro, "lo elegido de otra ventana se respeta")
	otroPanel.Visible = false
	Ui.mantenerSeleccion(panel, function()
		return boton
	end)
	comprueba(GuiService.SelectedObject == boton, "lo elegido escondido: vuelve a lo principal")
end

-- Pistas y vendedor (la partida).
do
	local m = crearMundo()
	local g = m.global
	local GuiService = g.game:GetService("GuiService")
	local sonido = { precargar = function() end, tocar = function() end, en = function() end }
	m.personaje()
	local jugador = m.jugadorLocal
	local PistasUi = m.cargar("src/juego/cliente/PistasUi", { Sonido = sonido })
	PistasUi.start()
	local VendedorUi = m.cargar("src/juego/cliente/VendedorUi", { Sonido = sonido })
	VendedorUi.start()
	m.correr(0.2)
	local hud = jugador:FindFirstChildOfClass("PlayerGui"):FindFirstChild("Hud")
	local pista = hud:FindFirstChild("Pista")
	local vendedor = hud:FindFirstChild("Vendedor")
	comprueba(not pista.Selectable and not vendedor.Selectable, "los papeles de fondo no los elige el mando")

	pulsar(m, g.Enum.KeyCode.ButtonY) -- pasa a mando
	m.alCliente("Pista", 1, 3)
	m.correr(0.1)
	comprueba(pista.Visible, "la pista se abre")
	comprueba(GuiService.SelectedObject == pista:FindFirstChild("Cerrar"), "pista: CERRAR elegido")
	comprueba(jugador:GetAttribute("VentanaAbierta") == true, "pista: VentanaAbierta")
	local vista = false
	local conexion = g.game:GetService("UserInputService").InputBegan:Connect(function(entrada)
		if entrada.KeyCode == g.Enum.KeyCode.ButtonB then
			vista = jugador:GetAttribute("VentanaAbierta") == true -- (PosturaVista mira esto en la misma B)
		end
	end)
	m.pulsar(g.Enum.KeyCode.ButtonB)
	comprueba(not pista.Visible, "B cierra la pista")
	comprueba(vista, "la B que la cierra aún ve la ventana: no agacha")
	m.soltar(g.Enum.KeyCode.ButtonB)
	m.correr(0.1)
	conexion:Disconnect()
	comprueba(GuiService.SelectedObject == nil, "pista cerrada: nada elegido")
	comprueba(jugador:GetAttribute("VentanaAbierta") == nil, "pista cerrada: sin VentanaAbierta")

	-- El vendedor, al lado; solo te llega el segundo trato (una botella).
	local modelo = g.Instance.new("Model")
	local mando = m.caja(jugador.Character:GetPivot(), g.Vector3.new(1, 1, 1))
	mando.Name = "Mando"
	mando.Parent = modelo
	modelo:AddTag("Vendedor")
	modelo.Parent = g.workspace
	jugador:SetAttribute("Mochila", '{"cosas":[{"tipo":"Botella"}]}')
	m.alCliente("Vendedor", "Abrir", "Hola")
	m.correr(0.1)
	comprueba(vendedor.Visible, "el vendedor se abre")
	comprueba(GuiService.SelectedObject == vendedor:FindFirstChild("Cambiar2"), "vendedor: el primer trato pagable")
	pulsar(m, g.Enum.KeyCode.ButtonB)
	comprueba(not vendedor.Visible and GuiService.SelectedObject == nil, "B cierra el vendedor y suelta")
	jugador:SetAttribute("Mochila", '{"cosas":[]}')
	m.alCliente("Vendedor", "Abrir", "Hola")
	m.correr(0.1)
	comprueba(GuiService.SelectedObject == vendedor:FindFirstChild("Cerrar"), "vendedor sin nada que pagar: CERRAR")
	pulsar(m, g.Enum.KeyCode.ButtonB)

	-- Con teclado no se elige nada.
	pulsar(m, g.Enum.KeyCode.Z)
	m.alCliente("Pista", 1, 3)
	m.correr(0.1)
	comprueba(pista.Visible and GuiService.SelectedObject == nil, "con teclado la pista se abre sin nada elegido")
	pulsar(m, g.Enum.KeyCode.ButtonY) -- coge el mando con la pista abierta
	comprueba(GuiService.SelectedObject == pista:FindFirstChild("Cerrar"), "al pasar a mando con la pista abierta: CERRAR")
end

-- El coche del lobby: el dueño sale con EMPEZAR elegido.
do
	local m = crearMundo({ proyecto = "lobby.project.json" })
	local g = m.global
	local GuiService = g.game:GetService("GuiService")
	m.personaje()
	local jugador = m.jugadorLocal
	local sonido = { precargar = function() end, tocar = function() end }
	local CochesUi = m.cargar("src/lobby/cliente/CochesUi", { Sonido = sonido })
	CochesUi.start()
	m.correr(0.3)
	pulsar(m, g.Enum.KeyCode.ButtonY) -- pasa a mando
	local carpeta = g.Instance.new("Folder")
	carpeta.Name = "Coches"
	carpeta.Parent = g.workspace
	local modelo = g.Instance.new("Model")
	modelo.Name = "Coche1"
	modelo:SetAttribute("Dueno", jugador.UserId)
	modelo.Parent = carpeta
	jugador:SetAttribute("Coche", "Coche1")
	m.correr(0.6)
	local panel = jugador:FindFirstChildOfClass("PlayerGui"):FindFirstChild("Hud"):FindFirstChild("Coche")
	comprueba(panel.Visible, "el papel del coche sale")
	comprueba(GuiService.SelectedObject ~= nil and GuiService.SelectedObject.Name == "Empezar", "coche: EMPEZAR elegido")
	jugador:SetAttribute("Coche", nil)
	m.correr(0.1)
	comprueba(GuiService.SelectedObject == nil, "al bajar: nada elegido")
end

print(`mando-ventanas: todo bien ({cuentas} comprobaciones).`)
