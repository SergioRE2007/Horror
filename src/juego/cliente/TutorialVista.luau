-- Lo que se ve del tutorial (14.2; lo manda juego/servidor/Tutorial con el atributo "Tutorial" del jugador). Pedido
-- por el usuario en el primer juego: muy visible, "que te diga más vistoso dónde clicar".
--   Arriba en el centro, un cartel de papel viejo con el paso ("3/8") y una frase corta, y SALTAR (también con la K
--   o la cruceta a la derecha: en el ordenador el ratón va bloqueado).
--   Sobre lo que hay que tocar, una flecha roja grande que sube y baja (a través de las paredes) y un contorno; si no
--   está en pantalla, otra flecha en el borde que señala hacia dónde girarse.
--   En el móvil, los pasos de la mochila y de correr señalan su botón.
-- El cliente no decide nada: solo busca lo más cercano de lo que pide el paso para señalarlo.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local PasosTutorial = require(ReplicatedStorage.Shared.PasosTutorial)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))
local Sonido = require(script.Parent.Sonido)

local TutorialVista = {}

local yo = Players.LocalPlayer
local SANGRE_VIVA = Color3.fromRGB(165, 22, 18) -- la flecha: más clara que Ui.Color.Sangre para verla de noche

-- Lo que dice cada paso. Frases enteras (Lang): la de la mochila cambia con el mando o la pantalla táctil.
local function frase(paso: string): string
	if paso == "Mochila" then
		if Ui.tactil() and not UserInputService.KeyboardEnabled then
			return Lang.t(nil, "Open your backpack: tap BACKPACK.")
		elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
			return Lang.t(nil, "Open your backpack (D-pad up).")
		end
		return Lang.t(nil, "Open your backpack (B).")
	elseif paso == "Hacha" then
		return Lang.t(nil, "Find an axe and pick it up.")
	elseif paso == "Correr" then -- 14.8
		if Ui.tactil() and not UserInputService.KeyboardEnabled then
			return Lang.t(nil, "Run to the forest: tap RUN. Running is loud.")
		elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
			return Lang.t(nil, "Run to the forest: press L3. Running is loud.")
		end
		return Lang.t(nil, "Run to the forest: hold Shift. Running is loud.")
	elseif paso == "Tronco" then
		return Lang.t(nil, "Chop down a tree and carry a log.")
	elseif paso == "Serrar" then
		return Lang.t(nil, "Saw the log on the sawhorse.")
	elseif paso == "Generador" then
		return Lang.t(nil, "Start the generator in the shed.")
	elseif paso == "Espera" then
		return Lang.t(nil, "Stay close to the house. Night is coming.")
	elseif paso == "Cortinas" then
		return Lang.t(nil, "Close the curtains downstairs: {n} left.", { n = yo:GetAttribute("TutorialFalta") or 0 })
	elseif paso == "Amanecer" then
		return Lang.t(nil, "Survive until dawn. If something gets in, hide.")
	end
	return ""
end

-- Lo más cercano a `desde` de una lista de { pieza, posición }.
local function masCerca(desde: Vector3, lista: { { any } }): (Instance?, Vector3?)
	local mejor, donde, distancia = nil, nil, math.huge
	for _, c in lista do
		local d = (c[2] - desde).Magnitude
		if d < distancia then
			mejor, donde, distancia = c[1], c[2], d
		end
	end
	return mejor, donde
end

local function centro(cosa: Instance): Vector3?
	if cosa:IsA("BasePart") then
		return cosa.Position
	elseif cosa:IsA("Model") then
		return cosa:GetPivot().Position
	end
	return nil
end

local function conTipo(etiqueta: string, tipo: string): { { any } }
	local lista = {}
	for _, pieza in CollectionService:GetTagged(etiqueta) do
		if pieza:IsA("BasePart") and pieza:GetAttribute("Tipo") == tipo and pieza:IsDescendantOf(workspace) then
			table.insert(lista, { pieza, pieza.Position })
		end
	end
	return lista
end

local function etiquetados(etiqueta: string, vale: ((Instance) -> boolean)?): { { any } }
	local lista = {}
	for _, cosa in CollectionService:GetTagged(etiqueta) do
		local donde = cosa:IsDescendantOf(workspace) and centro(cosa)
		if donde and (not vale or vale(cosa)) then
			table.insert(lista, { cosa, donde })
		end
	end
	return lista
end

-- Qué señalar en ese paso (nil = nada en el mundo).
local function objetivo(paso: string, desde: Vector3): (Instance?, Vector3?)
	if paso == "Hacha" then
		return masCerca(desde, conTipo("Objeto", "Hacha"))
	elseif paso == "Correr" then -- hacia el bosque: el árbol en pie más cercano
		return masCerca(desde, etiquetados("Arbol", function(arbol)
			return not arbol:GetAttribute("Talado")
		end))
	elseif paso == "Tronco" then
		if yo:GetAttribute("Cargando") then
			return nil -- lleva otra cosa: que la suelte él
		end
		-- Un tronco ya en el suelo o, si no, un árbol en pie.
		local troncos = conTipo("Pesado", "Tronco")
		if #troncos > 0 then
			return masCerca(desde, troncos)
		end
		return masCerca(desde, etiquetados("Arbol", function(arbol)
			return not arbol:GetAttribute("Talado")
		end))
	elseif paso == "Serrar" then
		return masCerca(desde, etiquetados("Caballete"))
	elseif paso == "Generador" then
		return masCerca(desde, etiquetados("Generador"))
	elseif paso == "Cortinas" then
		local lista = {}
		for _, ventana in CollectionService:GetTagged("Ventana") do
			local mando = ventana:FindFirstChild("Mando")
			if ventana:GetAttribute("Atacable") and ventana:GetAttribute("Persiana") == false
				and (ventana:GetAttribute("Vida") or 0) > 0 and mando and mando:IsA("BasePart") then
				table.insert(lista, { ventana, mando.Position })
			end
		end
		return masCerca(desde, lista)
	elseif paso == "Amanecer" then
		return masCerca(desde, etiquetados("Escondite"))
	end
	return nil
end

-- Una flecha que apunta hacia abajo hecha con marcos (sin imágenes subidas): palo y punta en V.
local function flecha(padre: Instance, tamano: number): Frame
	local caja = Instance.new("Frame")
	caja.BackgroundTransparency = 1
	caja.Size = UDim2.fromOffset(tamano, tamano)
	caja.AnchorPoint = Vector2.new(0.5, 0.5)
	local grueso = math.floor(tamano * 0.2)
	local function trozo(nombre: string, tam: UDim2, pos: UDim2, giro: number)
		local f = Instance.new("Frame")
		f.Name = nombre
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = tam
		f.Position = pos
		f.Rotation = giro
		f.BackgroundColor3 = SANGRE_VIVA
		f.BorderSizePixel = 0
		local borde = Instance.new("UIStroke")
		borde.Color = Ui.Color.Hueso
		borde.Thickness = math.max(2, math.floor(tamano / 24))
		borde.Parent = f
		f.Parent = caja
	end
	trozo("Palo", UDim2.fromOffset(grueso, tamano * 0.55), UDim2.fromScale(0.5, 0.3), 0)
	trozo("Izquierda", UDim2.fromOffset(grueso, tamano * 0.5), UDim2.fromScale(0.36, 0.66), -45)
	trozo("Derecha", UDim2.fromOffset(grueso, tamano * 0.5), UDim2.fromScale(0.64, 0.66), 45)
	caja.Parent = padre
	return caja
end

local cartel: Frame
local textoPaso: TextLabel
local numero: TextLabel
local escalaCartel: UIScale
local cartelMundo: BillboardGui
local flechaMundo: Frame
local flechaBorde: Frame
local contorno: Highlight
local flechaBoton: Frame
local saltar: TextButton
local pulsado = 0 -- cuándo se pulsó SALTAR la primera vez

-- Ordenador: teclado sin pantalla táctil. Ahí el ratón va bloqueado en primera persona y SALTAR no se puede pulsar:
-- se pulsa con la K (ver start), que va en su texto.
local function conTecla(): boolean
	return UserInputService.KeyboardEnabled and not UserInputService.TouchEnabled
end

local function textoSaltar(ingles: string): string
	return Ui.mayusculas(Lang.t(nil, ingles)) .. (if conTecla() then "  [K]" else "")
end

-- Dos toques (como NUEVA PARTIDA en el lobby): que no se salte sin querer.
local function pulsarSaltar()
	local ahora = os.clock()
	if ahora - pulsado < 3 then
		Remotes.Tutorial:FireServer("Saltar")
	else
		pulsado = ahora
		saltar.Text = textoSaltar("Sure?")
		task.delay(3, function()
			saltar.Text = textoSaltar("Skip")
		end)
	end
end

local function construir()
	local hud = Ui.hud()
	cartel = Instance.new("Frame")
	cartel.Name = "Tutorial"
	cartel.AnchorPoint = Vector2.new(0.5, 0)
	cartel.Position = UDim2.new(0.5, 0, 0, 8)
	cartel.Size = UDim2.fromOffset(640, 92)
	cartel.BackgroundColor3 = Ui.Color.Papel
	cartel.BackgroundTransparency = 0.08
	cartel.Visible = false
	cartel.ZIndex = 40
	local borde = Instance.new("UIStroke")
	borde.Color = Ui.Color.Sangre
	borde.Thickness = 3
	borde.Parent = cartel
	local esquina = Instance.new("UICorner")
	esquina.CornerRadius = UDim.new(0, 4)
	esquina.Parent = cartel
	escalaCartel = Instance.new("UIScale")
	escalaCartel.Parent = cartel
	local mancha = Ui.mancha(cartel)
	mancha.ZIndex = 40
	mancha.Size = UDim2.fromOffset(120, 80)

	numero = Ui.texto("", {
		Position = UDim2.fromOffset(16, 6),
		Size = UDim2.new(1, -140, 0, 24),
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(190, 70, 60),
		ZIndex = 41,
	})
	numero.Parent = cartel
	textoPaso = Ui.texto("", {
		Position = UDim2.fromOffset(16, 30),
		Size = UDim2.new(1, -32, 0, 54),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 41,
	})
	Ui.queQuepa(textoPaso, 30)
	textoPaso.Parent = cartel

	saltar = Ui.boton(textoSaltar("Skip"), {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 6),
		Size = UDim2.fromOffset(if conTecla() then 140 else 110, Ui.alto(30)), -- con la tecla: "¿SEGURO?  [K]"
		TextSize = 16,
		ZIndex = 42,
	})
	saltar.Parent = cartel
	saltar.Activated:Connect(pulsarSaltar)
	cartel.Parent = hud

	-- La flecha del mundo: en un BillboardGui (en PlayerGui, para que las cinemáticas la escondan con todo lo demás).
	cartelMundo = Instance.new("BillboardGui")
	cartelMundo.Name = "TutorialFlecha"
	cartelMundo.AlwaysOnTop = true
	cartelMundo.LightInfluence = 0
	cartelMundo.Size = UDim2.fromOffset(90, 90)
	cartelMundo.StudsOffsetWorldSpace = Vector3.new(0, Config.Tutorial.Flecha, 0)
	cartelMundo.Enabled = false
	cartelMundo.ResetOnSpawn = false
	flechaMundo = flecha(cartelMundo, 80)
	flechaMundo.Position = UDim2.fromScale(0.5, 0.5)
	cartelMundo.Parent = yo:WaitForChild("PlayerGui")

	contorno = Instance.new("Highlight")
	contorno.Name = "TutorialContorno"
	contorno.FillColor = SANGRE_VIVA
	contorno.FillTransparency = 0.85
	contorno.OutlineColor = Ui.Color.Hueso
	contorno.OutlineTransparency = 0.15
	contorno.DepthMode = Enum.HighlightDepthMode.Occluded
	contorno.Enabled = false
	contorno.Parent = workspace.CurrentCamera

	flechaBorde = flecha(hud, 70)
	flechaBorde.Visible = false
	flechaBorde.ZIndex = 39

	flechaBoton = flecha(hud, 60)
	flechaBoton.Visible = false
	flechaBoton.ZIndex = 45
end

local function esconder()
	cartel.Visible = false
	cartelMundo.Enabled = false
	cartelMundo.Adornee = nil
	contorno.Enabled = false
	contorno.Adornee = nil
	flechaBorde.Visible = false
	flechaBoton.Visible = false
end

local pasoAnterior: string? = nil
local function pintarCartel()
	local paso = yo:GetAttribute("Tutorial")
	if type(paso) ~= "string" then
		pasoAnterior = nil
		esconder()
		return
	end
	cartel.Visible = true
	numero.Text = Ui.mayusculas(Lang.t(nil, "Tutorial")) .. `  {PasosTutorial.numero(paso)}/{#PasosTutorial.LISTA}`
	textoPaso.Text = frase(paso)
	if paso ~= pasoAnterior then
		if pasoAnterior then
			Sonido.tocar("Papel") -- paso hecho: como pasar la hoja de la libreta
		end
		pasoAnterior = paso
		escalaCartel.Scale = 1.12
		TweenService:Create(escalaCartel, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end

-- Los botones del móvil en Hud.EquipoBotones: MOCHILA (EquipoVista, LayoutOrder 4) y CORRER (CorrerVista, 7).
local ORDEN_BOTON = { Mochila = 4, Correr = 7 }
local function botonDelPaso(paso: string): GuiObject?
	local orden = ORDEN_BOTON[paso]
	local fila = orden and Ui.hud():FindFirstChild("EquipoBotones", true)
	if not fila then
		return nil
	end
	for _, b in fila:GetChildren() do
		if b:IsA("GuiButton") and b.LayoutOrder == orden and b.Visible then
			return b
		end
	end
	return nil
end

local siguiente = 0
local objetivoActual: Instance? = nil
local dondeActual: Vector3? = nil

local function cadaFotograma()
	local paso = yo:GetAttribute("Tutorial")
	if type(paso) ~= "string" or not cartel.Visible then
		return
	end
	local camara = workspace.CurrentCamera
	local vaiven = math.sin(os.clock() * 4)

	-- Buscar lo más cercano cuesta: solo un par de veces por segundo.
	local ahora = os.clock()
	if ahora >= siguiente then
		siguiente = ahora + 0.5
		local raiz = yo.Character and yo.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if raiz and not yo:GetAttribute("Muerto") then
			objetivoActual, dondeActual = objetivo(paso, raiz.Position)
		else
			objetivoActual, dondeActual = nil, nil
		end
		local adornar = if objetivoActual and (objetivoActual:IsA("BasePart") or objetivoActual:IsA("Model"))
			then objetivoActual :: PVInstance
			else nil
		cartelMundo.Adornee = adornar
		cartelMundo.Enabled = adornar ~= nil
		contorno.Adornee = adornar
		contorno.Enabled = adornar ~= nil and paso ~= "Amanecer" -- los escondites, solo la flecha
	end
	flechaMundo.Position = UDim2.new(0.5, 0, 0.5, vaiven * 8)

	-- Flecha del borde: si lo que hay que tocar no está delante.
	flechaBorde.Visible = false
	if dondeActual and objetivoActual and objetivoActual.Parent and paso ~= "Amanecer" then
		local punto, delante = camara:WorldToViewportPoint(dondeActual)
		local tam = camara.ViewportSize
		local dentro = delante and punto.X > 0 and punto.X < tam.X and punto.Y > 0 and punto.Y < tam.Y
		if not dentro then
			local medio = tam / 2
			local hacia = Vector2.new(punto.X, punto.Y) - medio
			if not delante then
				hacia = -hacia -- detrás: la proyección sale al revés
			end
			if hacia.Magnitude < 1 then
				hacia = Vector2.new(0, 1)
			end
			hacia = hacia.Unit
			local escala = Ui.escala()
			local margen = 70 * escala
			local cabe = math.min((medio.X - margen) / math.max(math.abs(hacia.X), 1e-3),
				(medio.Y - margen) / math.max(math.abs(hacia.Y), 1e-3))
			local sitio = (medio + hacia * cabe) / escala -- el HUD dibuja en píxeles de diseño
			flechaBorde.Position = UDim2.fromOffset(sitio.X, sitio.Y)
			-- La flecha apunta hacia abajo (0, 1): girarla hacia `hacia`.
			flechaBorde.Rotation = math.deg(math.atan2(hacia.Y, hacia.X)) - 90
			flechaBorde.Visible = true
		end
	end

	-- En el móvil, la mochila o correr: la flecha encima de su botón.
	flechaBoton.Visible = false
	if ORDEN_BOTON[paso] and Ui.tactil() then
		local boton = botonDelPaso(paso)
		if boton then
			local escala = Ui.escala()
			local arriba = boton.AbsolutePosition + Vector2.new(boton.AbsoluteSize.X / 2, -30 * escala + vaiven * 6 * escala)
			flechaBoton.Position = UDim2.fromOffset(arriba.X / escala, arriba.Y / escala)
			flechaBoton.Visible = true
		end
	end
end

function TutorialVista.start()
	construir()
	yo:GetAttributeChangedSignal("Tutorial"):Connect(pintarCartel)
	yo:GetAttributeChangedSignal("TutorialFalta"):Connect(pintarCartel)
	pintarCartel()
	-- SALTAR también con la K (en el mando, la cruceta a la derecha), mientras se ve el cartel (no en las cinemáticas,
	-- que apagan el HUD).
	UserInputService.InputBegan:Connect(function(entrada, procesado)
		local tecla = entrada.KeyCode
		if not procesado and cartel.Visible and Ui.hud().Enabled
			and (tecla == Enum.KeyCode.K or tecla == Enum.KeyCode.DPadRight) then
			pulsarSaltar()
		end
	end)
	-- El bucle solo hace algo mientras hay tutorial (cadaFotograma sale enseguida si no).
	RunService.RenderStepped:Connect(cadaFotograma)
end

return TutorialVista
