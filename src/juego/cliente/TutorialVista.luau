-- Lo que se ve del tutorial (14.2; lo manda juego/servidor/Tutorial con el atributo "Tutorial" del jugador). Pedido
-- por el usuario en el primer juego: muy visible, "que te diga más vistoso dónde clicar".
--   Arriba en el centro, un cartel de papel viejo con el paso ("3/8") y una frase corta, y SALTAR (también con la K
--   o la cruceta a la derecha: en el ordenador el ratón va bloqueado).
--   Sobre lo que hay que tocar, una flecha roja grande que sube y baja (a través de las paredes) y un contorno; si no
--   está en pantalla, otra flecha en el borde que señala hacia dónde girarse: si está detrás, a media altura en el
--   borde izquierdo o derecho (hacia donde girar), no abajo. En el móvil no se mete bajo el cartel ni bajo la rejilla de
--   botones del equipo, y la flecha del mundo sigue a la escala del HUD.
--   En el móvil, los pasos de la mochila y de correr señalan su botón.
--   Con Rendimiento, las flechas quietas y el cartel sin rebote.
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
-- Píxeles de diseño (como el resto del HUD).
local CARTEL_Y, CARTEL_ALTO = 8, 92
local FLECHA_MUNDO = 90 -- lado de la caja de la flecha sobre lo que hay que tocar (se multiplica por la escala del HUD)
local FLECHA_BORDE = 70
local LADO_BORDE = 70 -- del centro de la flecha del borde a los lados de la pantalla
local REJILLA_ALTO = 2 * 80 + 8 -- la rejilla de botones del móvil (EquipoVista: dos filas de 80 y 8 entre ellas)

local function rendimiento(): boolean
	return yo:GetAttribute("Rendimiento") == true
end

-- Lo que dice cada paso. Frases enteras (Lang): la de la mochila cambia con el mando o la pantalla táctil.
local function frase(paso: string): string
	if paso == "Nota" then -- la pista 1: el gancho de la historia
		return Lang.t(nil, "Read the note on the kitchen table.")
	elseif paso == "Mochila" then
		if Ui.tactil() then
			return Lang.t(nil, "Open your backpack: tap BACKPACK.")
		elseif Ui.tipoEntrada() == "mando" then
			return Lang.t(nil, "Open your backpack (D-pad up).")
		end
		return Lang.t(nil, "Open your backpack (B).")
	elseif paso == "Hacha" then
		return Lang.t(nil, "Find an axe and pick it up.")
	elseif paso == "Correr" then -- 14.8
		if Ui.tactil() then
			return Lang.t(nil, "Run to the forest: tap RUN. Running is loud.")
		elseif Ui.tipoEntrada() == "mando" then
			return Lang.t(nil, "Run to the forest: press L3. Running is loud.")
		end
		return Lang.t(nil, "Run to the forest: hold Shift. Running is loud.")
	elseif paso == "Tronco" then
		return Lang.t(nil, "Chop down a tree and carry a log.")
	elseif paso == "Serrar" then
		-- Sin el tronco en las manos (TutorialRecoger, del servidor): coger lo serrado del suelo o volver a por un tronco.
		local recoger = yo:GetAttribute("TutorialRecoger")
		if recoger == "Tablon" then
			return Lang.t(nil, "Pick up a plank.")
		elseif recoger == "Tronco" then
			return Lang.t(nil, "Bring a log to the sawhorse.")
		end
		return Lang.t(nil, "Saw the log on the sawhorse.")
	elseif paso == "Generador" then
		if yo:GetAttribute("TutorialGasolina") then -- 16.5: con poca gasolina, que le eche un bidón
			return Lang.t(nil, "Fill up the generator: carry a fuel can to it.")
		end
		return Lang.t(nil, "Start the generator in the shed.")
	elseif paso == "Espera" then
		return Lang.t(nil, "Stay close to the house. Night is coming.")
	elseif paso == "Cortinas" then
		local n = yo:GetAttribute("TutorialFalta") or 0
		if yo:GetAttribute("TutorialPuerta") then -- 16.5: la puerta principal abierta cuenta como una más
			if n <= 1 then
				return Lang.t(nil, "Close the front door.")
			end
			return Lang.t(nil, "Close the front door and the curtains downstairs: {n} left.", { n = n })
		end
		return Lang.t(nil, "Close the curtains downstairs: {n} left.", { n = n })
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

-- Lo pesado de ese tipo que se puede coger: nadie lo lleva (Llevada, de Cargar) ni se está trabajando (Trabajo).
local function sueltos(tipo: string): { { any } }
	local lista = {}
	for _, c in conTipo("Pesado", tipo) do
		if not c[1]:GetAttribute("Llevada") and not c[1]:GetAttribute("Trabajo") then
			table.insert(lista, c)
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
	if paso == "Nota" then -- la nota de la mesa de la cocina (Pistas: modelo con N = 1; su pivote es el papel)
		return masCerca(desde, etiquetados("Pista", function(pista)
			return pista:IsA("Model") and pista:GetAttribute("N") == 1 and pista.PrimaryPart ~= nil
		end))
	elseif paso == "Hacha" then
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
		local troncos = sueltos("Tronco")
		if #troncos > 0 then
			return masCerca(desde, troncos)
		end
		return masCerca(desde, etiquetados("Arbol", function(arbol)
			return not arbol:GetAttribute("Talado")
		end))
	elseif paso == "Serrar" then
		local recoger = yo:GetAttribute("TutorialRecoger")
		if recoger == "Tablon" or recoger == "Tronco" then
			if yo:GetAttribute("Cargando") then
				return nil -- lleva otra cosa: que la suelte él
			end
			local lista = sueltos(recoger)
			if recoger == "Tablon" then
				for _, c in sueltos("TablonReforzado") do
					table.insert(lista, c)
				end
			end
			if #lista > 0 then
				return masCerca(desde, lista)
			end
			if recoger == "Tronco" then -- ni un tronco en el suelo: al árbol en pie más cercano
				return masCerca(desde, etiquetados("Arbol", function(arbol)
					return not arbol:GetAttribute("Talado")
				end))
			end
			return nil
		end
		return masCerca(desde, etiquetados("Caballete"))
	elseif paso == "Generador" then
		-- 16.5: si pide gasolina y no lleva un bidón, al bidón con gasolina más cercano; con él en las manos, al generador.
		if yo:GetAttribute("TutorialGasolina") and yo:GetAttribute("Cargando") ~= "Bidon" then
			local bidones = {}
			for _, c in conTipo("Pesado", "Bidon") do
				if (c[1]:GetAttribute("Carga") or 0) > 0.05 then
					table.insert(bidones, c)
				end
			end
			if #bidones > 0 then
				return masCerca(desde, bidones)
			end
		end
		return masCerca(desde, etiquetados("Generador"))
	elseif paso == "Cortinas" then
		local lista = {}
		-- La puerta principal abierta también (16.5): el bicho entra a la primera por ella.
		for _, puerta in CollectionService:GetTagged("Puerta") do
			local mando = puerta:FindFirstChild("Mando")
			if puerta:GetAttribute("Atacable") and puerta:GetAttribute("Abierta") == true
				and (puerta:GetAttribute("Vida") or 0) > 0 and mando and mando:IsA("BasePart") then
				table.insert(lista, { puerta, mando.Position })
			end
		end
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

-- Una flecha que apunta hacia abajo hecha con marcos (sin imágenes subidas): palo y punta en V. Las medidas van en
-- partes de la caja (como en GuiaLobby), para que valga igual en el mundo (que cambia con la pantalla) y en el HUD.
local function flecha(padre: Instance, lado: UDim2, grosor: number): Frame
	local caja = Instance.new("Frame")
	caja.Name = "Flecha"
	caja.BackgroundTransparency = 1
	caja.Size = lado
	caja.AnchorPoint = Vector2.new(0.5, 0.5)
	local function trozo(nombre: string, tam: Vector2, pos: Vector2, giro: number)
		local f = Instance.new("Frame")
		f.Name = nombre
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = UDim2.fromScale(tam.X, tam.Y)
		f.Position = UDim2.fromScale(pos.X, pos.Y)
		f.Rotation = giro
		f.BackgroundColor3 = SANGRE_VIVA
		f.BorderSizePixel = 0
		local borde = Instance.new("UIStroke")
		borde.Color = Ui.Color.Hueso
		borde.Thickness = grosor
		borde.Parent = f
		f.Parent = caja
	end
	trozo("Palo", Vector2.new(0.2, 0.55), Vector2.new(0.5, 0.3), 0)
	trozo("Izquierda", Vector2.new(0.2, 0.5), Vector2.new(0.36, 0.66), -45)
	trozo("Derecha", Vector2.new(0.2, 0.5), Vector2.new(0.64, 0.66), 45)
	caja.Parent = padre
	return caja
end

-- Dónde va la flecha del borde (en píxeles de diseño del HUD) y hacia dónde apunta (unitario, en la pantalla).
--   tam: la pantalla en píxeles de verdad; punto: lo que da WorldToViewportPoint (su Z es la profundidad: <= 0, detrás);
--   lado: la X de lo señalado vista desde la cámara (su signo dice a qué lado girarse); escala: la del HUD;
--   margenLado, margenArriba, margenAbajo: del centro de la flecha a cada borde, en píxeles de diseño.
-- Delante pero fuera de la pantalla: en el borde, en la dirección en que está. Detrás, la proyección no sirve (sale al
-- revés y casi siempre abajo en el centro, que no dice hacia dónde girarse): a media altura en el borde izquierdo o
-- derecho, apuntando a ese lado. La misma cuenta está en GuiaLobby (a propósito, sin ayuda común).
local function sitioBorde(tam: Vector2, punto: Vector3, lado: number, escala: number, margenLado: number,
	margenArriba: number, margenAbajo: number): (Vector2, Vector2)
	local izq, der = margenLado * escala, tam.X - margenLado * escala
	local arriba, abajo = margenArriba * escala, tam.Y - margenAbajo * escala
	if der < izq then
		izq, der = tam.X / 2, tam.X / 2
	end
	if abajo < arriba then
		local m = (arriba + abajo) / 2
		arriba, abajo = m, m
	end
	local medio = Vector2.new(math.clamp(tam.X / 2, izq, der), math.clamp(tam.Y / 2, arriba, abajo))
	if punto.Z <= 0 then
		local signo = if lado < 0 then -1 else 1
		return Vector2.new(if signo > 0 then der else izq, medio.Y) / escala, Vector2.new(signo, 0)
	end
	local hacia = Vector2.new(punto.X, punto.Y) - tam / 2
	if hacia.Magnitude < 1 then
		hacia = Vector2.new(0, 1)
	end
	hacia = hacia.Unit
	local cabeX = (if hacia.X > 0 then der - medio.X else medio.X - izq) / math.max(math.abs(hacia.X), 1e-3)
	local cabeY = (if hacia.Y > 0 then abajo - medio.Y else medio.Y - arriba) / math.max(math.abs(hacia.Y), 1e-3)
	return (medio + hacia * math.max(math.min(cabeX, cabeY), 0)) / escala, hacia
end
TutorialVista.sitioBorde = sitioBorde -- para el banco (tests/bancos/flecha-borde.luau)

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

-- Con teclado el ratón va bloqueado en primera persona y SALTAR no se puede pulsar: se pulsa con la K (ver start), que
-- va en su texto. Con mando o con el dedo no se enseña la letra.
local function textoSaltar(ingles: string): string
	return Ui.mayusculas(Lang.t(nil, ingles)) .. (if Ui.conTeclado() then "  [K]" else "")
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
	cartel.Position = UDim2.new(0.5, 0, 0, CARTEL_Y)
	cartel.Size = UDim2.fromOffset(640, CARTEL_ALTO)
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
	-- En el móvil SALTAR mide un dedo de alto (casi todo el cartel): el texto acaba antes, para no meterse debajo.
	textoPaso = Ui.texto("", {
		Position = UDim2.fromOffset(16, 30),
		Size = UDim2.new(1, if Ui.tactil() then -(16 + 110 + 8 + 16) else -32, 0, 54),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 41,
	})
	Ui.queQuepa(textoPaso, 30)
	textoPaso.Parent = cartel

	saltar = Ui.boton(textoSaltar("Skip"), {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -8, 0, 6),
		Size = UDim2.fromOffset(if Ui.conTeclado() then 140 else 110, Ui.alto(30)), -- con la tecla: "¿SEGURO?  [K]"
		TextSize = 16,
		ZIndex = 42,
	})
	saltar.Parent = cartel
	saltar.Activated:Connect(pulsarSaltar)
	Ui.alCambiarEntrada(function() -- la K sale o se va según lo que se use; el "¿SEGURO?" pendiente se respeta
		saltar.Text = textoSaltar(if pulsado > 0 and os.clock() - pulsado < 3 then "Sure?" else "Skip")
		saltar.Size = UDim2.fromOffset(if Ui.conTeclado() then 140 else 110, Ui.alto(30))
	end)
	cartel.Parent = hud

	-- La flecha del mundo: en un BillboardGui (en PlayerGui, para que las cinemáticas la escondan con todo lo demás).
	-- Su tamaño sigue a la escala del HUD (los BillboardGui no tienen UIScale): en un teléfono de 360 de alto, 90 px
	-- fijos eran un cuarto de la pantalla.
	cartelMundo = Instance.new("BillboardGui")
	cartelMundo.Name = "TutorialFlecha"
	cartelMundo.AlwaysOnTop = true
	cartelMundo.LightInfluence = 0
	cartelMundo.StudsOffsetWorldSpace = Vector3.new(0, Config.Tutorial.Flecha, 0)
	cartelMundo.Enabled = false
	cartelMundo.ResetOnSpawn = false
	flechaMundo = flecha(cartelMundo, UDim2.fromScale(80 / FLECHA_MUNDO, 80 / FLECHA_MUNDO), 3)
	flechaMundo.Position = UDim2.fromScale(0.5, 0.5)
	local function medirMundo()
		local escala = Ui.escala()
		cartelMundo.Size = UDim2.fromOffset(FLECHA_MUNDO * escala, FLECHA_MUNDO * escala)
		for _, borde in flechaMundo:GetDescendants() do
			if borde:IsA("UIStroke") then
				borde.Thickness = math.max(2, math.floor(3 * escala + 0.5))
			end
		end
	end
	medirMundo()
	hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(medirMundo)
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

	flechaBorde = flecha(hud, UDim2.fromOffset(FLECHA_BORDE, FLECHA_BORDE), 2)
	flechaBorde.Name = "TutorialBorde"
	flechaBorde.Visible = false
	flechaBorde.ZIndex = 39

	flechaBoton = flecha(hud, UDim2.fromOffset(60, 60), 2)
	flechaBoton.Name = "TutorialBoton"
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
	numero.Text = Ui.mayusculas(Lang.t(nil, "Tutorial  {n}/{total}",
		{ n = PasosTutorial.numero(paso), total = #PasosTutorial.LISTA }))
	local texto = frase(paso)
	-- Cambia lo que pide dentro del mismo paso (Serrar: coger el tablón del suelo): también salta, para que se lea.
	local otraFrase = paso == pasoAnterior and paso == "Serrar" and texto ~= textoPaso.Text
	textoPaso.Text = texto
	if paso ~= pasoAnterior or otraFrase then
		if pasoAnterior and not otraFrase then
			Sonido.tocar("Papel") -- paso hecho: como pasar la hoja de la libreta
		end
		pasoAnterior = paso
		if not rendimiento() then -- con Rendimiento, sin rebote
			escalaCartel.Scale = 1.12
			TweenService:Create(escalaCartel, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
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
local ladoAnterior = 1 -- a qué lado iba la flecha de detrás: justo a la espalda no cambia de lado a cada fotograma

local function cadaFotograma()
	local paso = yo:GetAttribute("Tutorial")
	if type(paso) ~= "string" or not cartel.Visible then
		return
	end
	local camara = workspace.CurrentCamera
	-- Con el HUD apagado (mirilla, cortinas, cinemáticas) o la cámara de una cinemática (de script sin estar escondido),
	-- ni flecha ni contorno: se pintarían encima de la vista. Al volver se repinta en el siguiente repaso.
	if not Ui.hud().Enabled or (camara.CameraType == Enum.CameraType.Scriptable
		and typeof(yo:GetAttribute("Escondido")) ~= "CFrame") then
		cartelMundo.Enabled = false
		contorno.Enabled = false
		flechaBorde.Visible = false
		flechaBoton.Visible = false
		siguiente = 0
		return
	end
	local vaiven = if rendimiento() then 0 else math.sin(os.clock() * 4)

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
	flechaMundo.Position = UDim2.fromScale(0.5, 0.5 + vaiven * 8 / FLECHA_MUNDO)

	-- Flecha del borde: si lo que hay que tocar no está en la pantalla. El segundo valor de WorldToViewportPoint dice si
	-- se ve (delante y dentro), no si está delante: eso lo dice la Z del punto. Antes se tomaba por "delante" y lo que
	-- estaba delante pero a un lado salía señalado al revés.
	flechaBorde.Visible = false
	if dondeActual and objetivoActual and objetivoActual.Parent and paso ~= "Amanecer" then
		local punto, seVe = camara:WorldToViewportPoint(dondeActual)
		local tam = camara.ViewportSize
		if not (seVe and punto.Z > 0) then
			local lado = camara.CFrame:PointToObjectSpace(dondeActual).X
			if math.abs(lado) > 0.5 then
				ladoAnterior = if lado < 0 then -1 else 1
			end
			-- Arriba, por debajo del cartel del paso (si no, lo tapa); abajo, en el móvil, por encima de la rejilla de
			-- botones del equipo (y del joystick), que va sobre la zona segura y el 3 % de abajo de la pantalla.
			local mitad = FLECHA_BORDE / 2
			local margenArriba = CARTEL_Y + CARTEL_ALTO + mitad + 8
			local margenAbajo = if Ui.tactil()
				then 0.03 * Ui.lienzo().Y + Ui.zonaSegura() + REJILLA_ALTO + mitad + 10
				else 70
			local sitio, hacia = sitioBorde(tam, punto, ladoAnterior, Ui.escala(), LADO_BORDE, margenArriba, margenAbajo)
			sitio += hacia * vaiven * 6 -- empuja hacia donde señala (quieta con Rendimiento)
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
	Ui.alCambiarEntrada(pintarCartel) -- las frases cambian con el mando o la pantalla táctil (frase)
	yo:GetAttributeChangedSignal("TutorialFalta"):Connect(pintarCartel)
	yo:GetAttributeChangedSignal("TutorialPuerta"):Connect(pintarCartel)
	yo:GetAttributeChangedSignal("TutorialGasolina"):Connect(pintarCartel)
	yo:GetAttributeChangedSignal("TutorialRecoger"):Connect(function()
		pintarCartel()
		siguiente = 0 -- la flecha cambia de sitio enseguida (del caballete al tablón), sin esperar al repaso
	end)
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
