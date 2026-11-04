-- Lo que se puede tocar (ProximityPrompt con estilo Custom: el servidor los pone, aquí se pintan).
--   Teclado y mando: un cartelito junto a la cosa con la tecla y la acción; si hay que mantener, una raya roja que
--   se llena.
--   Móvil: el cartelito sin tecla y un botón grande de acción a la derecha que cambia según lo que tengas delante
--   (dos como mucho, uno encima de otro).
-- El texto del prompt viene en inglés del servidor y aquí se traduce. Vale en los dos lugares.
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Lang = require(ReplicatedStorage.Shared.Lang)
local Ui = require(script.Parent.Ui)

local Controles = {}

type Pintado = { cartel: BillboardGui, raya: Frame, boton: TextButton?, conexiones: { RBXScriptConnection } }
local pintados: { [ProximityPrompt]: Pintado } = {}
local botonera: Frame

local function textoDe(prompt: ProximityPrompt): string
	return Ui.mayusculas(Lang.t(nil, prompt.ActionText))
end

local function teclaDe(prompt: ProximityPrompt, tipo: Enum.ProximityPromptInputType): string
	if tipo == Enum.ProximityPromptInputType.Gamepad then
		return (string.gsub(prompt.GamepadKeyCode.Name, "^Button", ""))
	end
	return prompt.KeyboardKeyCode.Name
end

local function mostrar(prompt: ProximityPrompt, tipo: Enum.ProximityPromptInputType)
	local tactil = tipo == Enum.ProximityPromptInputType.Touch
	local fila = math.floor(prompt.UIOffset.Y / 60) -- el segundo prompt de una cosa va debajo
	-- El cartel va fuera del HUD (en el mundo): se encoge a mano con su escala, sin pasar de su tamaño de ordenador.
	local s = math.clamp(Ui.escala(), 0.75, 1)

	local cartel = Instance.new("BillboardGui")
	cartel.Name = "Prompt"
	cartel.Adornee = prompt.Parent :: BasePart
	cartel.AlwaysOnTop = true
	cartel.Size = UDim2.fromOffset(260 * s, 34 * s)
	cartel.StudsOffsetWorldSpace = Vector3.new(0, -0.9 * fila, 0)
	cartel.LightInfluence = 0
	cartel.MaxDistance = 40

	local caja = Instance.new("Frame")
	caja.Size = UDim2.fromScale(1, 1)
	caja.BackgroundTransparency = 1
	caja.Parent = cartel
	local lista = Instance.new("UIListLayout")
	lista.FillDirection = Enum.FillDirection.Horizontal
	lista.HorizontalAlignment = Enum.HorizontalAlignment.Center
	lista.VerticalAlignment = Enum.VerticalAlignment.Center
	lista.Padding = UDim.new(0, 8 * s)
	lista.Parent = caja
	if not tactil then
		local tecla = Ui.texto(teclaDe(prompt, tipo), {
			Size = UDim2.fromOffset(30 * s, 30 * s),
			BackgroundTransparency = 0.2,
			BackgroundColor3 = Ui.Color.Papel,
			TextSize = 20 * s,
		})
		local borde = Instance.new("UIStroke")
		borde.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		borde.Color = Ui.Color.Hueso
		borde.Transparency = 0.5
		borde.Parent = tecla
		tecla.Parent = caja
	end
	local accion = Ui.texto(textoDe(prompt), {
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30 * s),
		TextSize = 22 * s,
	})
	accion.Parent = caja

	local raya = Instance.new("Frame")
	raya.AnchorPoint = Vector2.new(0.5, 0)
	raya.Position = UDim2.fromScale(0.5, 1)
	raya.Size = UDim2.new(0, 0, 0, 3)
	raya.BorderSizePixel = 0
	raya.BackgroundColor3 = Ui.Color.Sangre
	raya.Parent = cartel
	cartel.Parent = Ui.hud().Parent

	local pintado: Pintado = { cartel = cartel, raya = raya, boton = nil, conexiones = {} }
	if tactil then
		local boton = Ui.boton(textoDe(prompt), { -- grande: en el móvil el HUD se encoge a la mitad y hay que darle con el dedo
			Size = UDim2.fromOffset(200, 90),
			LayoutOrder = fila, -- en el orden de los carteles: el de abajo es el de abajo (REPARAR bajo CERRAR CORTINAS)
		})
		Ui.queQuepa(boton, 28) -- las frases largas (y en otros idiomas) bajan de letra en vez de salirse
		boton.Parent = botonera
		boton.InputBegan:Connect(function(entrada)
			if entrada.UserInputType == Enum.UserInputType.Touch or entrada.UserInputType == Enum.UserInputType.MouseButton1 then
				prompt:InputHoldBegin()
			end
		end)
		boton.InputEnded:Connect(function(entrada)
			if entrada.UserInputType == Enum.UserInputType.Touch or entrada.UserInputType == Enum.UserInputType.MouseButton1 then
				prompt:InputHoldEnd()
			end
		end)
		pintado.boton = boton
	end
	table.insert(pintado.conexiones, prompt:GetPropertyChangedSignal("ActionText"):Connect(function()
		accion.Text = textoDe(prompt)
		if pintado.boton then
			pintado.boton.Text = textoDe(prompt)
		end
	end))
	pintados[prompt] = pintado
end

local function ocultar(prompt: ProximityPrompt)
	local pintado = pintados[prompt]
	if not pintado then
		return
	end
	pintados[prompt] = nil
	for _, conexion in pintado.conexiones do
		conexion:Disconnect()
	end
	pintado.cartel:Destroy()
	if pintado.boton then
		pintado.boton:Destroy()
	end
end

function Controles.start()
	botonera = Instance.new("Frame")
	botonera.Name = "Acciones"
	botonera.AnchorPoint = Vector2.new(1, 0.5)
	-- Encima del botón de saltar de Roblox, algo apartada del borde (la cámara de algunos teléfonos tapa el lado).
	-- Mapa del móvil en docs/sistemas/movil.md.
	botonera.Position = UDim2.fromScale(0.955, 0.52)
	botonera.Size = UDim2.fromOffset(200, 190)
	botonera.BackgroundTransparency = 1
	local lista = Instance.new("UIListLayout")
	lista.Padding = UDim.new(0, 10)
	lista.VerticalAlignment = Enum.VerticalAlignment.Bottom
	lista.SortOrder = Enum.SortOrder.LayoutOrder
	lista.Parent = botonera
	botonera.Parent = Ui.hud()

	-- Con las manos ocupadas (llevando algo pesado o trabajando) o la mochila abierta no se toca nada. Lo que se hace
	-- con lo que llevas en las manos lo pinta CargarVista.
	local jugador = game:GetService("Players").LocalPlayer
	local function manosLibres()
		ProximityPromptService.Enabled = not (jugador:GetAttribute("Cargando") or jugador:GetAttribute("MochilaAbierta")
			or jugador:GetAttribute("Trabajando"))
	end
	for _, atributo in { "Cargando", "MochilaAbierta", "Trabajando" } do
		jugador:GetAttributeChangedSignal(atributo):Connect(manosLibres)
	end

	ProximityPromptService.PromptShown:Connect(function(prompt, tipo)
		if prompt.Style == Enum.ProximityPromptStyle.Custom then
			mostrar(prompt, tipo)
		end
	end)
	ProximityPromptService.PromptHidden:Connect(ocultar)
	ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
		local pintado = pintados[prompt]
		if pintado then
			pintado.raya.Size = UDim2.new(0, 0, 0, 3)
			TweenService:Create(pintado.raya, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear),
				{ Size = UDim2.new(0.8, 0, 0, 3) }):Play()
		end
	end)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
		local pintado = pintados[prompt]
		if pintado then
			TweenService:Create(pintado.raya, TweenInfo.new(0.15), { Size = UDim2.new(0, 0, 0, 3) }):Play()
		end
	end)
end

return Controles
