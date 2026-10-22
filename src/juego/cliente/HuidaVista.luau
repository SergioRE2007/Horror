-- La escena final de la huida (servidor: Coche, remote Huida). Todo local y con bloques grises:
--   1. Desde fuera del garaje: el portón sube, se encienden los faros y arranca el motor.
--   2. El coche sale, gira y coge la carretera hacia el pueblo.
--   3. De lado: el bicho sale del bosque rugiendo y lo persigue, cada vez más cerca.
--   4. Desde delante, mirando atrás: lo tiene encima… el coche acelera y lo deja atrás.
--   5. Fundido a negro y "HAS ESCAPADO".
-- Esconde toda la interfaz y a los personajes, y lo devuelve todo al acabar aunque algo falle (en Studio no hay viaje al
-- lobby y se sigue jugando).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sonido = require(script.Parent.Sonido)
local Ui = require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))

local HuidaVista = {}

local jugador = Players.LocalPlayer
local camara = workspace.CurrentCamera
local enMarcha = false

-- Camino del coche: sale del garaje hacia -z, gira hasta la carretera (x = 0) y baja por ella. Puntos cada ~1 stud.
local function camino(desde: Vector3): ({ Vector3 }, { number })
	local puntos = {}
	local y = 0.15 -- la carretera
	local function cubica(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: number)
		for i = 1, n do
			local t = i / n
			local u = 1 - t
			table.insert(puntos, a * u * u * u + b * 3 * u * u * t + c * 3 * u * t * t + d * t * t * t)
		end
	end
	table.insert(puntos, desde)
	for z = desde.Z - 1, -30, -1 do
		table.insert(puntos, Vector3.new(desde.X, if z > -14 then desde.Y else y, z))
	end
	cubica(Vector3.new(desde.X, y, -30), Vector3.new(desde.X, y, -55), Vector3.new(0, y, -40), Vector3.new(0, y, -72), 60)
	for z = -73, -520, -1 do
		table.insert(puntos, Vector3.new(0, y, z))
	end
	local largos = { 0 }
	for i = 2, #puntos do
		largos[i] = largos[i - 1] + (puntos[i] - puntos[i - 1]).Magnitude
	end
	return puntos, largos
end

-- Dónde está y hacia dónde mira lo que va a `d` studs del principio del camino.
local function en(puntos: { Vector3 }, largos: { number }, d: number): (Vector3, Vector3)
	d = math.clamp(d, 0, largos[#largos])
	local i = 2
	while i < #puntos and largos[i] < d do
		i += 1
	end
	local a, b = puntos[i - 1], puntos[i]
	local t = (d - largos[i - 1]) / math.max(1e-3, largos[i] - largos[i - 1])
	local dir = (b - a) * Vector3.new(1, 0, 1)
	return a:Lerp(b, t), if dir.Magnitude > 1e-3 then dir.Unit else Vector3.new(0, 0, -1)
end

-- El bicho de la escena: alto, flaco y encorvado, con brazos largos y ojos rojos. Piezas ancladas que se colocan cada
-- fotograma respecto a su raíz (correr = piernas y brazos que van y vienen).
local function bicho(padre: Instance)
	local NEGRO = Color3.fromRGB(30, 28, 28)
	local partes = {}
	local function parte(nombre: string, tamano: Vector3, color: Color3, material: Enum.Material?)
		local p = Instance.new("Part")
		p.Name = nombre
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Size = tamano
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Parent = padre
		partes[nombre] = p
		return p
	end
	parte("Torso", Vector3.new(2.4, 3.8, 1.3), NEGRO)
	parte("Cabeza", Vector3.new(1.4, 1.7, 1.5), NEGRO)
	for _, lado in { "I", "D" } do
		parte("Ojo" .. lado, Vector3.new(0.25, 0.18, 0.1), Color3.fromRGB(255, 40, 30), Enum.Material.Neon)
		parte("Brazo" .. lado, Vector3.new(0.55, 5, 0.55), NEGRO)
		parte("Pierna" .. lado, Vector3.new(0.75, 3.6, 0.75), NEGRO)
	end
	local luz = Instance.new("PointLight") -- un poco de rojo para que se le vea en la oscuridad
	luz.Color = Color3.fromRGB(255, 60, 40)
	luz.Brightness = 0.8
	luz.Range = 9
	luz.Parent = partes.Cabeza
	-- `cf` = a ras del suelo mirando hacia donde corre; `t` = tiempo para la zancada.
	return function(cf: CFrame, t: number)
		local zancada = math.sin(t * 13)
		local cadera = cf * CFrame.new(0, 3.6 + math.abs(zancada) * 0.35, 0)
		local torso = cadera * CFrame.Angles(math.rad(-30), 0, 0) * CFrame.new(0, 1.9, 0)
		partes.Torso.CFrame = torso
		partes.Cabeza.CFrame = torso * CFrame.new(0, 2.5, -0.5) * CFrame.Angles(math.rad(20), 0, 0)
		for i, lado in { "I", "D" } do
			local s = if i == 1 then 1 else -1
			partes["Pierna" .. lado].CFrame = cadera * CFrame.new(0.6 * s, 0, 0) * CFrame.Angles(math.rad(40 * zancada * s), 0, 0)
				* CFrame.new(0, -1.8, 0)
			partes["Brazo" .. lado].CFrame = torso * CFrame.new(1.5 * s, 1.5, 0) * CFrame.Angles(math.rad(75 + 30 * zancada * s), 0, 0)
				* CFrame.new(0, -2.5, 0)
			partes["Ojo" .. lado].CFrame = partes.Cabeza.CFrame * CFrame.new(0.35 * s, 0.15, -0.76)
		end
	end
end

-- Velocidad del coche (studs/s) a los `t` segundos: arranca, va deprisa y al final acelera y deja atrás al bicho.
local function velocidad(t: number): number
	if t < 2.4 then
		return 0
	elseif t < 5.5 then
		return (t - 2.4) / 3.1 * 30
	elseif t < 12.6 then
		return 30
	end
	return 30 + math.min(1, (t - 12.6) / 1.2) * 32
end

-- Lo que ha recorrido el coche a los `t` segundos (suma de la velocidad a pasitos).
local function recorrido(t: number): number
	local d, paso = 0, 0.05
	for s = 0, t - paso, paso do
		d += velocidad(s) * paso
	end
	return d
end

-- Distancia del bicho detrás del coche: se acerca hasta casi tocarlo y luego se queda atrás.
local function hueco(t: number): number
	if t < 12.8 then
		return 30 - math.clamp((t - 7.5) / 5, 0, 1) * 24
	end
	return 6 + (t - 12.8) * 26
end

-- `devolver`: lo que hay que deshacer al acabar (lo hace quien llama, aunque esto falle a medias).
local function escena(segundos: number, devolver: { () -> () })
	local coche = CollectionService:GetTagged("Coche")[1] :: Model?
	local sitio = coche and coche:GetAttribute("Sitio")
	if not coche or typeof(sitio) ~= "CFrame" then
		return
	end
	local carpeta = Instance.new("Folder")
	carpeta.Name = "Huida"
	carpeta.Parent = workspace
	local function alAcabar(fn: () -> ())
		table.insert(devolver, fn)
	end

	-- Interfaz y personajes fuera.
	local guis = {}
	for _, gui in (jugador:WaitForChild("PlayerGui")):GetChildren() do
		if gui:IsA("LayerCollector") and gui.Enabled then -- también los carteles 3D (prompts, usar)
			gui.Enabled = false
			table.insert(guis, gui)
		end
	end
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)
	alAcabar(function()
		for _, gui in guis do
			gui.Enabled = true
		end
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, true)
	end)
	for _, otro in Players:GetPlayers() do
		for _, p in (otro.Character and otro.Character:GetDescendants() or {}) do
			if p:IsA("BasePart") or p:IsA("Decal") then
				p.LocalTransparencyModifier = 1
			end
		end
	end
	alAcabar(function()
		for _, otro in Players:GetPlayers() do
			for _, p in (otro.Character and otro.Character:GetDescendants() or {}) do
				if p:IsA("BasePart") or p:IsA("Decal") then
					p.LocalTransparencyModifier = 0
				end
			end
		end
	end)

	-- Una copia del coche que se mueve (la de verdad se esconde), con faros y pilotos rojos.
	local copia = coche:Clone()
	CollectionService:RemoveTag(copia, "Coche")
	for _, d in copia:GetDescendants() do
		if d:IsA("ProximityPrompt") then
			d:Destroy()
		end
	end
	copia.WorldPivot = sitio
	local capo = copia:FindFirstChild("Capo") :: BasePart?
	if capo then -- arreglado, ya con el capó cerrado
		capo.Size = Vector3.new(6.2, 1.2, 4.3) -- tapa también el motor y la batería, que asoman
		capo.CFrame = sitio * CFrame.new(0, 3.3, -3.9)
	end
	copia.Parent = carpeta
	for _, p in coche:GetDescendants() do
		if p:IsA("BasePart") then
			p.LocalTransparencyModifier = 1
		end
	end
	alAcabar(function()
		for _, p in coche:GetDescendants() do
			if p:IsA("BasePart") then
				p.LocalTransparencyModifier = 0
			end
		end
	end)
	for _, faro in copia:GetChildren() do
		if faro.Name == "Faro" and faro:IsA("BasePart") then
			local luz = Instance.new("SpotLight")
			luz.Face = Enum.NormalId.Front
			luz.Angle = 55
			luz.Range = 50
			luz.Brightness = 0
			luz.Color = Color3.fromRGB(255, 236, 200)
			luz.Parent = faro
			-- Parpadean al encenderse y se quedan encendidos (el faro, pequeño, con brillo propio).
			task.delay(0.6, function()
				for i = 1, 5 do
					local encendido = i % 2 == 1 or i == 5
					luz.Brightness = if encendido then 5 else 0
					faro.Material = if encendido then Enum.Material.Neon else Enum.Material.SmoothPlastic
					task.wait(0.12)
				end
			end)
		end
	end
	for _, lado in { -1, 1 } do
		local piloto = Instance.new("Part")
		piloto.Name = "Piloto"
		piloto.Size = Vector3.new(1, 0.4, 0.1)
		piloto.CFrame = sitio * CFrame.new(2.4 * lado, 2.3, 6.05)
		piloto.Color = Color3.fromRGB(150, 20, 20)
		piloto.Material = Enum.Material.SmoothPlastic
		piloto.Anchored = true
		piloto.CanCollide = false
		piloto.Parent = copia
		local luz = Instance.new("PointLight")
		luz.Color = Color3.fromRGB(255, 40, 30)
		luz.Brightness = 0.9
		luz.Range = 14
		luz.Parent = piloto
	end

	-- El portón (si estaba cerrado) sube en este cliente.
	local porton = CollectionService:GetTagged("Porton")[1]
	local hoja = porton and porton:FindFirstChild("Hoja") :: BasePart?
	if hoja then
		local antes = hoja.CFrame
		TweenService:Create(hoja, TweenInfo.new(1.8, Enum.EasingStyle.Quad), { CFrame = antes * CFrame.new(0, 8.6, 0) }):Play()
		alAcabar(function()
			hoja.CFrame = antes
		end)
	end

	local motor = Sonido.bucle("Motor", copia:FindFirstChild("Chasis"))
	motor.Volume *= 1.6

	local poner = bicho(carpeta)
	local puntos, largos = camino(sitio.Position)
	local salida = Vector3.zero -- de dónde sale el bicho (del bosque, a un lado)
	local negro = Instance.new("ScreenGui")
	negro.Name = "Final"
	negro.IgnoreGuiInset = true
	negro.DisplayOrder = 100
	local fondo = Instance.new("Frame")
	fondo.Size = UDim2.fromScale(1, 1)
	fondo.BackgroundColor3 = Ui.Color.Negro
	fondo.BackgroundTransparency = 1
	fondo.Parent = negro
	local titulo = Ui.texto(Ui.mayusculas(Lang.t(nil, "You escaped.")), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.2),
		TextScaled = true,
		TextTransparency = 1,
	})
	titulo.Parent = fondo
	local raya = Instance.new("Frame") -- la raya roja de debajo, como en los carteles de noche
	raya.AnchorPoint = Vector2.new(0.5, 0)
	raya.Position = UDim2.fromScale(0.5, 0.6)
	raya.Size = UDim2.new(0, 0, 0, 3)
	raya.BorderSizePixel = 0
	raya.BackgroundColor3 = Ui.Color.Sangre
	raya.Parent = fondo
	negro.Parent = jugador:WaitForChild("PlayerGui")
	alAcabar(function()
		negro:Destroy()
	end)

	camara.CameraType = Enum.CameraType.Scriptable
	alAcabar(function()
		camara.CameraType = Enum.CameraType.Custom
	end)
	local inicio = os.clock()
	local rugidos = 0
	RunService:BindToRenderStep("Huida", Enum.RenderPriority.Camera.Value + 20, function()
		-- En Studio, el atributo HuidaT del Workspace congela la escena en ese segundo (para revisar cada plano).
		local t = if RunService:IsStudio() and workspace:GetAttribute("HuidaT") then workspace:GetAttribute("HuidaT")
			else os.clock() - inicio
		local d = recorrido(t)
		local pos, dir = en(puntos, largos, d)
		local cf = CFrame.lookAt(pos, pos + dir)
		if t > 2.2 and t < 3 then
			cf *= CFrame.new(0, math.sin(t * 60) * 0.05, 0) -- tiembla al arrancar
		end
		copia:PivotTo(cf)
		motor.PlaybackSpeed = 0.8 + velocidad(t) / 50

		-- El bicho: sale del bosque y corre detrás.
		if t >= 7.5 then
			local atras, haciaCoche = en(puntos, largos, d - hueco(t))
			if salida == Vector3.zero then
				salida = atras + Vector3.new(-28, 0, 14)
			end
			local mezcla = math.clamp((t - 7.5) / 1.6, 0, 1)
			local donde = salida:Lerp(atras, mezcla)
			local mira = if mezcla < 1 then (atras - salida) * Vector3.new(1, 0, 1) else haciaCoche
			poner(CFrame.lookAt(donde, donde + mira.Unit), t)
			if rugidos == 0 then
				rugidos = 1
				Sonido.en("Rugido", donde, 0.9)
			elseif rugidos == 1 and t > 13.6 then
				rugidos = 2
				Sonido.en("Rugido", donde, 0.75)
			end
		else
			poner(CFrame.new(0, -200, 0), t) -- escondido bajo el mapa hasta que sale
		end

		-- Cámara por planos.
		if t < 3.4 then
			camara.CFrame = CFrame.lookAt(Vector3.new(sitio.X + 1, 4.5, -27), sitio.Position + Vector3.new(0, 2.5, 0))
		elseif t < 7.4 then
			local ojo = Vector3.new(22, 7, -50)
			camara.CFrame = CFrame.lookAt(ojo, pos + Vector3.new(0, 2, 0))
		elseif t < 11.6 then
			-- De lado, un poco por delante: el coche y, detrás, el bicho acercándose.
			camara.CFrame = CFrame.lookAt((cf * CFrame.new(-10, 5, 4)).Position, (cf * CFrame.new(0, 2.5, 10)).Position)
		else
			camara.CFrame = CFrame.lookAt((cf * CFrame.new(1.5, 5.2, -13)).Position, (cf * CFrame.new(0, 3.6, 12)).Position)
		end
		-- Fundido a negro y el título.
		if t > segundos - 2.2 then
			fondo.BackgroundTransparency = math.max(0, 1 - (t - (segundos - 2.2)) / 1.4)
			titulo.TextTransparency = math.max(0, 1 - (t - (segundos - 1)) / 1)
			raya.Size = UDim2.new(math.clamp((t - (segundos - 1)) / 1.2, 0, 1) * 0.42, 0, 0, 3)
		end
	end)
	alAcabar(function()
		RunService:UnbindFromRenderStep("Huida")
		motor:Destroy()
		carpeta:Destroy()
	end)

	task.wait(segundos + 4) -- el servidor manda al lobby a los segundos + 2; en Studio se vuelve a jugar
	while RunService:IsStudio() and workspace:GetAttribute("HuidaT") do -- congelada para revisarla: sigue
		task.wait(0.5)
	end
end

function HuidaVista.start()
	Remotes.Huida.OnClientEvent:Connect(function(segundos)
		if enMarcha or type(segundos) ~= "number" then
			return
		end
		enMarcha = true
		local devolver = {}
		local ok, fallo = pcall(escena, segundos, devolver)
		if not ok then
			warn("[HuidaVista] " .. tostring(fallo))
		end
		for i = #devolver, 1, -1 do
			pcall(devolver[i])
		end
		enMarcha = false
	end)
end

return HuidaVista
