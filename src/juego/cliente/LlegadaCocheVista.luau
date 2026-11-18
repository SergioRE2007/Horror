-- La escena de llegada en coche al empezar una partida nueva (16.8; servidor: Llegada). Todo local:
--   1. Desde la cuneta: el coche viene por la carretera del bosque con los faros encendidos y pasa de largo.
--   2. Desde el porche: frena y aparca delante de la casa.
--   3. Por detrás del coche, mirando a la casa: se apaga el motor y los faros. Fundido a negro y vuelves a tu cámara.
-- Empieza cuando el servidor pone el atributo LlegadaInicio de mi Player (la hora del servidor en que empezó: si llego
-- tarde, desde donde va). Se salta con SALTAR, espacio, Intro o el botón B/A del mando (y se le dice al servidor con el
-- remote Llegada: cuando la han saltado todos, la acaba y el tutorial empieza). Esconde toda la interfaz, los
-- personajes y el coche aparcado (CocheLlegada) y lo devuelve todo al acabar aunque algo falle (como HuidaVista).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sonido = require(script.Parent.Sonido)
local Ui = require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))

local LlegadaCocheVista = {}

local L = Config.Llegada
local jugador = Players.LocalPlayer
local Camara = require(script.Parent.Camara)
local enMarcha = false

local LLEGAR = 6.4 -- segundos hasta que se para
local PLANO2, PLANO3 = 2.6, 6.9 -- cuándo empiezan los planos 2 y 3
local APAGAR = 7.3 -- motor y faros fuera

-- Lo que le falta al coche para llegar a los `t` segundos (studs): frena de forma suave hasta pararse en su sitio.
local function falta(t: number): number
	local u = math.clamp(t / LLEGAR, 0, 1)
	return L.Recorrido * (1 - u) * (1 - u)
end

-- Espera un poco al coche aparcado (el streaming lo trae enseguida: es Persistent).
local function cocheAparcado(): Model?
	local limite = os.clock() + 3
	while os.clock() < limite do
		local m = CollectionService:GetTagged("CocheLlegada")[1]
		if m and m:IsA("Model") and typeof(m:GetAttribute("Sitio")) == "CFrame" then
			return m
		end
		task.wait(0.1)
	end
	return nil
end

-- `desde`: segundos que ya lleva la escena (si llego tarde). `devolver`: lo que hay que deshacer al acabar (lo hace
-- quien llama, aunque esto falle a medias).
local function escena(desde: number, devolver: { () -> () })
	local aparcado = cocheAparcado()
	if not aparcado then
		return
	end
	local sitio = aparcado:GetAttribute("Sitio") :: CFrame
	local function alAcabar(fn: () -> ())
		table.insert(devolver, fn)
	end

	-- Interfaz fuera (también la que salga mientras dura) y los personajes.
	local playerGui = jugador:WaitForChild("PlayerGui")
	local guis = {}
	local function apagar(gui: Instance)
		if gui:IsA("LayerCollector") and gui.Enabled and gui.Name ~= "Llegada" then -- también los carteles 3D
			gui.Enabled = false
			table.insert(guis, gui)
		end
	end
	for _, gui in playerGui:GetChildren() do
		apagar(gui)
	end
	local nuevas = playerGui.ChildAdded:Connect(function(gui)
		task.defer(apagar, gui)
	end)
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)
	alAcabar(function()
		nuevas:Disconnect()
		for _, gui in guis do
			if gui.Parent then
				gui.Enabled = true
			end
		end
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, true)
	end)
	local function personajes(valor: number)
		for _, otro in Players:GetPlayers() do
			for _, p in (otro.Character and otro.Character:GetDescendants() or {}) do
				if p:IsA("BasePart") or p:IsA("Decal") then
					p.LocalTransparencyModifier = valor
				end
			end
		end
	end
	personajes(1)
	alAcabar(function()
		personajes(0)
	end)
	-- Quieto mientras dura (solo en este cliente: el personaje es suyo).
	local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if raiz then
		local antes = raiz.Anchored
		raiz.Anchored = true
		alAcabar(function()
			raiz.Anchored = antes
		end)
	end

	-- Una copia que se mueve; la aparcada, escondida hasta el final.
	local carpeta = Instance.new("Folder")
	carpeta.Name = "Llegada"
	carpeta.Parent = workspace
	alAcabar(function()
		carpeta:Destroy()
	end)
	local copia = aparcado:Clone()
	CollectionService:RemoveTag(copia, "CocheLlegada")
	copia.WorldPivot = sitio
	for _, p in copia:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
		end
	end
	copia.Parent = carpeta
	for _, p in aparcado:GetDescendants() do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = 1
		end
	end
	alAcabar(function()
		for _, p in aparcado:GetDescendants() do
			if p:IsA("BasePart") then
				p.LocalTransparencyModifier = 0
			end
		end
	end)
	local luces = {}
	for _, faro in copia:GetChildren() do
		if faro.Name == "Faro" and faro:IsA("BasePart") then
			local luz = Instance.new("SpotLight")
			luz.Face = Enum.NormalId.Front
			luz.Angle = 55
			luz.Range = 45
			luz.Brightness = 4
			luz.Color = Color3.fromRGB(255, 236, 200)
			luz.Parent = faro
			faro.Material = Enum.Material.Neon -- pequeño: con brillo propio
			table.insert(luces, { faro = faro, luz = luz })
		end
	end
	local chasis = copia:FindFirstChild("Chasis")
	-- El motor del coche (Config.Sonidos.MotorCoche), no "Motor", que es el zumbido del generador.
	local motor = Sonido.bucle("MotorCoche", chasis or carpeta)
	motor.Volume *= 1.6
	alAcabar(function()
		motor:Destroy()
	end)

	-- Lo de encima: franjas negras de cine, el fundido y SALTAR.
	local gui = Instance.new("ScreenGui")
	gui.Name = "Llegada"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	for _, ancla in { 0, 1 } do
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0, ancla)
		f.Position = UDim2.fromScale(0, ancla)
		f.Size = UDim2.fromScale(1, 0)
		f.BackgroundColor3 = Ui.Color.Negro
		f.BorderSizePixel = 0
		f.Parent = gui
		TweenService:Create(f, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(1, 0.11) }):Play()
	end
	local negro = Instance.new("Frame")
	negro.Size = UDim2.fromScale(1, 1)
	negro.BackgroundColor3 = Ui.Color.Negro
	negro.BackgroundTransparency = if desde < 0.3 then 0 else 1 -- empieza saliendo del negro
	negro.BorderSizePixel = 0
	negro.ZIndex = 5
	negro.Parent = gui
	local saltar = Ui.boton(Lang.t(nil, "Skip"), {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -12),
		Size = UDim2.fromOffset(Ui.alto(110), Ui.alto(38)),
		TextSize = Ui.alto(20),
		BackgroundTransparency = 0.4,
		ZIndex = 3,
	})
	saltar.Parent = gui
	gui.Parent = playerGui
	alAcabar(function()
		gui:Destroy()
	end)

	-- Con la cámara Scriptable el puntero queda suelto (sin la primera persona de Roblox): se deja, para pulsar SALTAR.
	-- La cámara es de la escena: EscenaFinal (solo en este cliente) cierra mochila y móvil y calla lo que haga falta,
	-- como en las escenas de los finales (MuerteVista, MovilUi, MochilaUi, CorrerVista). Se quita siempre al acabar.
	jugador:SetAttribute("EscenaFinal", true)
	alAcabar(function()
		jugador:SetAttribute("EscenaFinal", nil)
	end)
	Camara.get().CameraType = Enum.CameraType.Scriptable
	alAcabar(function()
		Camara.get().CameraType = Enum.CameraType.Custom
	end)

	local salto = false
	saltar.Activated:Connect(function()
		salto = true
	end)
	local teclas = UserInputService.InputBegan:Connect(function(entrada)
		local k = entrada.KeyCode
		if k == Enum.KeyCode.Space or k == Enum.KeyCode.Return or k == Enum.KeyCode.ButtonB or k == Enum.KeyCode.ButtonA then
			salto = true
		end
	end)
	alAcabar(function()
		teclas:Disconnect()
	end)

	local inicio = os.clock() - desde
	local apagado = false
	local fin = L.Segundos
	RunService:BindToRenderStep("Llegada", Enum.RenderPriority.Camera.Value + 20, function()
		local t = os.clock() - inicio
		-- El coche: viene por la carretera (su +z es hacia atrás) y se para en su sitio, con un poco de vaivén.
		local queda = falta(t)
		local cf = sitio * CFrame.new(0, 0, queda)
		if queda > 0.05 then
			cf *= CFrame.new(0, math.sin(t * 17) * 0.04, 0) * CFrame.Angles(math.sin(t * 5.3) * 0.006, 0, 0)
		elseif t < LLEGAR + 0.5 then
			cf *= CFrame.Angles(math.sin((t - LLEGAR) * 12) * 0.012 * (1 - (t - LLEGAR) / 0.5), 0, 0) -- cabeceo al frenar
		end
		copia:PivotTo(cf)
		motor.PlaybackSpeed = 0.75 + queda / L.Recorrido * 0.6
		if not apagado and t >= APAGAR then
			apagado = true
			for _, l in luces do
				l.luz.Brightness = 0
				l.faro.Material = Enum.Material.SmoothPlastic
			end
			TweenService:Create(motor, TweenInfo.new(0.5), { Volume = 0 }):Play()
		end

		-- Cámara por planos.
		local coche = cf.Position + Vector3.new(0, 2, 0)
		if t < PLANO2 then
			-- Desde la cuneta, por delante: viene, pasa de largo y lo sigue.
			local ojo = (sitio * CFrame.new(8, 3, 62)).Position
			Camara.get().CFrame = CFrame.lookAt(ojo, coche)
		elseif t < PLANO3 then
			-- Desde el porche, acercándose un poco: frena y aparca.
			local a = math.clamp((t - PLANO2) / (PLANO3 - PLANO2), 0, 1)
			local ojo = (sitio * CFrame.new(-7, 6.5, -21 + a * 3)).Position
			Camara.get().CFrame = CFrame.lookAt(ojo, coche)
		else
			-- Por detrás del coche, mirando a la casa.
			local a = math.clamp((t - PLANO3) / (fin - PLANO3), 0, 1)
			local ojo = (sitio * CFrame.new(3.2, 6 + a * 0.4, 17 - a * 4)).Position
			Camara.get().CFrame = CFrame.lookAt(ojo, (sitio * CFrame.new(0, 5.5, -32)).Position)
		end
		-- Fundidos: sale del negro al empezar y entra al final.
		if t < 0.8 then
			negro.BackgroundTransparency = math.max(negro.BackgroundTransparency, t / 0.8)
		elseif t > fin - 1 then
			negro.BackgroundTransparency = math.clamp(1 - (t - (fin - 1)) / 0.8, 0, 1)
		end
	end)
	alAcabar(function()
		RunService:UnbindFromRenderStep("Llegada")
	end)

	while os.clock() - inicio < fin and not salto do
		task.wait()
	end
	if salto then -- a negro deprisa
		Remotes.Llegada:FireServer("Saltar") -- cuando la han saltado todos los que la ven, el servidor la acaba
		RunService:UnbindFromRenderStep("Llegada")
		local fundido = TweenService:Create(negro, TweenInfo.new(0.3), { BackgroundTransparency = 0 })
		fundido:Play()
		fundido.Completed:Wait()
	end
	negro.BackgroundTransparency = 0
end

-- Al acabar, de negro a tu cámara (una pantalla aparte: la de la escena ya se ha ido).
local function salirDelNegro()
	local gui = Instance.new("ScreenGui")
	gui.Name = "LlegadaFin"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 100
	local negro = Instance.new("Frame")
	negro.Size = UDim2.fromScale(1, 1)
	negro.BackgroundColor3 = Ui.Color.Negro
	negro.BorderSizePixel = 0
	negro.Parent = gui
	gui.Parent = jugador:WaitForChild("PlayerGui")
	local tween = TweenService:Create(negro, TweenInfo.new(0.7), { BackgroundTransparency = 1 })
	tween:Play()
	tween.Completed:Once(function()
		gui:Destroy()
	end)
	task.delay(2, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end

local function mirar()
	local inicio = jugador:GetAttribute("LlegadaInicio")
	if enMarcha or type(inicio) ~= "number" or jugador:GetAttribute("EscenaFinal") then
		return
	end
	local desde = math.max(0, workspace:GetServerTimeNow() - inicio)
	if desde > L.Segundos - 1.5 then -- llego tarde: ya casi ha acabado
		return
	end
	enMarcha = true
	local devolver = {}
	local ok, fallo = pcall(escena, desde, devolver)
	if not ok then
		warn("[LlegadaCocheVista] " .. tostring(fallo))
	end
	local hubo = #devolver > 0
	for i = #devolver, 1, -1 do
		pcall(devolver[i])
	end
	if hubo then
		pcall(salirDelNegro)
	end
	enMarcha = false
end

function LlegadaCocheVista.start()
	jugador:GetAttributeChangedSignal("LlegadaInicio"):Connect(function()
		task.spawn(mirar)
	end)
	task.spawn(mirar)
end

return LlegadaCocheVista
