-- Lo pesado en el cliente (lo manda el servidor: juego/servidor/Cargar). Mientras llevas algo (atributo Cargando):
--   la E, X en el mando o el botón SOLTAR del móvil lo suelta; con las manos ocupadas no salen los carteles de coger.
--   La vista baja un poco y se balancea al andar, más despacio cuanto más pesa.
--   Usar lo que llevas (R, Y en el mando o el botón del móvil): mirando algo con lo que sirve sale un cartel junto a ello
--   (tronco -> caballete: SERRAR; tablón -> ventana o puerta dañada: CLAVAR; bidón -> generador: ECHAR GASOLINA).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))

local CargarVista = {}

-- Con qué se usa cada cosa y qué pone el cartel.
local USOS = {
	Tronco = { etiquetas = { "Caballete" }, texto = "Saw" },
	Tablon = { etiquetas = { "Ventana", "Puerta" }, texto = "Nail" },
	Bidon = { etiquetas = { "Generador" }, texto = "Refuel" },
}

local jugador = Players.LocalPlayer
local camara = workspace.CurrentCamera
local aviso: TextLabel
local boton: TextButton?
local botonUsar: TextButton?
local cartel: BillboardGui
local textoCartel: TextLabel
local objetivo: Instance? = nil
local balanceo = 0
local buscado = 0

local function soltar()
	if jugador:GetAttribute("Cargando") and not jugador:GetAttribute("Trabajando") then
		Remotes.Cargar:FireServer()
	end
end

local function usar()
	if objetivo and jugador:GetAttribute("Cargando") and not jugador:GetAttribute("Trabajando") then
		Remotes.Usar:FireServer(objetivo)
	end
end

local function cambiar()
	local llevando = jugador:GetAttribute("Cargando") ~= nil
	TweenService:Create(aviso, TweenInfo.new(0.3), {
		TextTransparency = if llevando then 0.25 else 1,
		TextStrokeTransparency = if llevando then 0.6 else 1,
	}):Play()
	if boton then
		boton.Visible = llevando
	end
end

-- ¿Sirve lo que llevo con esto? Las ventanas, por dentro y si están dañadas; las puertas, si están dañadas.
local function sirve(el: Instance, raiz: BasePart): boolean
	if el:GetAttribute("Bloqueada") then
		return false
	end
	if CollectionService:HasTag(el, "Ventana") or CollectionService:HasTag(el, "Puerta") then
		local danada = (el:GetAttribute("Vida") or 0) < (el:GetAttribute("VidaMax") or 0) or (el:GetAttribute("Cristal") or 0) > 0
		local centro = el:GetAttribute("Centro")
		if CollectionService:HasTag(el, "Ventana") and typeof(centro) == "CFrame" then
			return danada and (raiz.Position - centro.Position):Dot(centro.LookVector) < 0
		end
		return danada
	end
	return true
end

-- Lo más cerca que tengas delante con lo que sirva lo que llevas.
local function buscar(): Instance?
	local tipo = jugador:GetAttribute("Cargando")
	local uso = tipo and USOS[tipo]
	local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not uso or not raiz or jugador:GetAttribute("Trabajando") then
		return nil
	end
	local mejor, distancia = nil, Config.Casa.Alcance
	for _, etiqueta in uso.etiquetas do
		for _, el in CollectionService:GetTagged(etiqueta) do
			local mando = el:FindFirstChild("Mando")
			if not mando or not mando:IsA("BasePart") then
				continue
			end
			local d = (mando.Position - raiz.Position).Magnitude
			local hacia = mando.Position - camara.CFrame.Position
			local delante = hacia.Magnitude > 0.1 and (d < 3.5 or hacia.Unit:Dot(camara.CFrame.LookVector) > 0.55) -- muy cerca, vale de lado
			if d < distancia and delante and sirve(el, raiz) then
				mejor, distancia = el, d
			end
		end
	end
	return mejor
end

local function apuntar()
	local nuevo = buscar()
	if nuevo == objetivo then
		return
	end
	objetivo = nuevo
	local tipo = jugador:GetAttribute("Cargando")
	local texto = if objetivo and tipo then Ui.mayusculas(Lang.t(nil, USOS[tipo].texto)) else ""
	cartel.Adornee = if objetivo then objetivo:FindFirstChild("Mando") :: BasePart else nil
	cartel.Enabled = objetivo ~= nil
	textoCartel.Text = if UserInputService.TouchEnabled then texto else "[R]  " .. texto
	if botonUsar then
		botonUsar.Text = texto
		botonUsar.Visible = objetivo ~= nil
	end
end

-- Vista más baja y balanceo al andar con peso.
local function mover(dt: number)
	buscado += dt
	if buscado > 0.15 then
		buscado = 0
		apuntar()
	end
	local humanoide = jugador.Character and jugador.Character:FindFirstChildOfClass("Humanoid")
	if not humanoide then
		return
	end
	local llevando = jugador:GetAttribute("Cargando") ~= nil
	local andando = humanoide.MoveDirection.Magnitude > 0.1 and humanoide.WalkSpeed > 0
	if llevando and andando then
		balanceo += dt * (2 + humanoide.WalkSpeed * 0.45)
	end
	local objetivoVista = if llevando
		then Vector3.new(math.sin(balanceo) * 0.12, -0.35 - math.abs(math.cos(balanceo)) * (if andando then 0.15 else 0), 0)
		else Vector3.zero
	humanoide.CameraOffset = humanoide.CameraOffset:Lerp(objetivoVista, math.min(1, dt * 8))
end

function CargarVista.start()
	aviso = Ui.texto("", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -56),
		Size = UDim2.fromOffset(300, 26),
		TextSize = 20,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	local tactil = UserInputService.TouchEnabled
	aviso.Text = if tactil then "" else "[E]  " .. Ui.mayusculas(Lang.t(nil, "Drop"))
	aviso.Parent = Ui.hud()

	-- Cartel junto a lo que se puede usar, como los de Controles.
	cartel = Instance.new("BillboardGui")
	cartel.Name = "Usar"
	cartel.AlwaysOnTop = true
	cartel.Size = UDim2.fromOffset(300, 34)
	cartel.LightInfluence = 0
	cartel.Enabled = false
	textoCartel = Ui.texto("", { Size = UDim2.fromScale(1, 1), TextSize = 22 })
	textoCartel.Parent = cartel
	cartel.Parent = Ui.hud().Parent

	if tactil then
		local acciones = Ui.hud():FindFirstChild("Acciones") -- donde sale el botón grande de acción (Controles)
		botonUsar = Ui.boton("", { Size = UDim2.fromOffset(200, 90), TextSize = 26, TextWrapped = true, Visible = false, LayoutOrder = -2 })
		;(botonUsar :: TextButton).Activated:Connect(usar)
		;(botonUsar :: TextButton).Parent = acciones or Ui.hud()
		boton = Ui.boton(Lang.t(nil, "Drop"), { Size = UDim2.fromOffset(200, 90), TextSize = 28, Visible = false, LayoutOrder = -1 })
		;(boton :: TextButton).Activated:Connect(soltar)
		;(boton :: TextButton).Parent = acciones or Ui.hud()
	end
	jugador:GetAttributeChangedSignal("Cargando"):Connect(cambiar)
	UserInputService.InputBegan:Connect(function(entrada, procesado)
		if procesado then
			return
		end
		if entrada.KeyCode == Enum.KeyCode.E or entrada.KeyCode == Enum.KeyCode.ButtonX then
			soltar()
		elseif entrada.KeyCode == Enum.KeyCode.R or entrada.KeyCode == Enum.KeyCode.ButtonY then
			usar()
		end
	end)
	RunService.RenderStepped:Connect(mover)
end

return CargarVista
