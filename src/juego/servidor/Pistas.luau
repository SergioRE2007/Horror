-- Pistas de la historia (12.1): notas, fotos y diarios repartidos por la casa, el pueblo y los sitios del bosque
-- (textos en shared/Historia, sitios aquí abajo, en el orden de docs/historia.md). Cada una lleva un prompt "Read"
-- (E): el servidor comprueba que el jugador está vivo y cerca, la apunta como encontrada y le dice al cliente que la
-- enseñe (Remotes.Pista, PistasUi). El cliente nunca pide nada: no hay remote de vuelta.
-- Las encontradas se guardan con la partida (Partida: exportar/importar, FormatoPartida.pistas). Las de la habitación
-- del rico solo se alcanzan con su llave. Pistas.leida(n) es para el final (12.2: plano de la reja, cerillas).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Historia = require(ReplicatedStorage.Shared.Historia)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Casa = require(script.Parent.Casa)

local Pistas = {}

local ALCANCE = Config.Casa.Alcance -- studs del prompt, como todos los demás
local HOLGURA = 4 -- de más en el servidor (el personaje llega con retraso)

-- Lo que está en una pared: el papel, con su cara de delante hacia `fuera` y lo alto en vertical.
local function enPared(pos: Vector3, fuera: Vector3): CFrame
	return CFrame.fromMatrix(pos, Vector3.new(fuera.Z, 0, -fuera.X), fuera) -- x = arriba × fuera: lo ancho, en horizontal
end
-- Lo que está tumbado en una mesa, girado `giro` radianes.
local function enMesa(x: number, y: number, z: number, giro: number): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(0, giro, 0)
end

-- Dónde está cada una (la cara de arriba del papel = lo que se lee). Mismo orden que shared/Historia.
local SITIOS: { CFrame } = {
	enMesa(-19.0, 4.82, 6.9, 0.4), -- 1. cocina: en la mesa, al empezar
	enMesa(17.1, 2.62, 0.7, 0.6), -- 2. salón: la foto en la mesa baja del sofá
	enMesa(23.6, 4.02, -440.1, -0.3), -- 3. pueblo: la mesa de la casa de la puerta rota (contra la pared este, 11.5)
	enPared(Vector3.new(21.47, 5.4, -503.6), -Vector3.xAxis), -- 4. iglesia: clavado junto a la puerta
	enMesa(79.15, 4.02, -481.45, 0.5), -- 5. caseta del enterrador: la mesa
	enMesa(195.6, 4.02, 51.3, 0.25), -- 6. granja: la mesa de la casa
	enPared(Vector3.new(-255.47, 6.3, -72.4), Vector3.xAxis), -- 7. aserradero: en la pared de la oficina, sobre el escritorio
	enMesa(91.1, 47.52, 300.2, -0.4), -- 8. torre: la mesa de la caseta de arriba
	-- 9. sótano: encima del banco del taller, a la izquierda (tablero a y -7.5; sitio dado por la 11.8.13)
	enMesa(-2.8, -7.48, 63.15, 0.2),
	enMesa(-27.5, 30.3, 1.1, 0), -- 10. desván: la nota que ya hay en la mesa del cuarto de revelado
	enMesa(-23.8, 16.9, 5.85, 0), -- 11. habitación del rico: el diario abierto que ya hay en el escritorio
	enMesa(-13.45, 18.96, -14.0, 0), -- 12. habitación del rico: la caja fuerte (la página está dentro)
}

-- Las que ya están en la sala (muebles de Mapa): solo se pone el prompt, en una pieza invisible, con este texto.
local YA_HAY = { [10] = "Read", [11] = "Read", [12] = "Open" }

-- Las que están en una sala con llave: no se leen mientras su puerta siga cerrada (el prompt atraviesa paredes).
local SALA = { [9] = "LlaveSotano", [10] = "LlaveDesvan", [11] = "LlaveRico", [12] = "LlaveRico" }

local MANCHADAS = { [4] = true, [6] = true, [9] = true } -- con una mancha de sangre en una esquina (Moderate)

local leidas: { [number]: boolean } = {}
local ultimo: { [Player]: number } = {}

local function pieza(nombre: string, tamano: Vector3, cf: CFrame, color: Color3, material: Enum.Material, padre: Instance): Part
	local p = Instance.new("Part")
	p.Name = nombre
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = tamano
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = padre
	return p
end

-- Renglones de tinta en la cara de arriba (no se leen: el texto sale en la pantalla).
local function escrito(papel: Part, n: number, manchada: boolean)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.LightInfluence = 1 -- de noche, tan oscuro como el papel
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 200
	gui.Parent = papel
	for i = 0, 6 do
		local largo = 0.62 + ((n * 7 + i * 13) % 10) / 40 -- distintos, siempre los mismos
		local linea = Instance.new("Frame")
		linea.BorderSizePixel = 0
		linea.BackgroundColor3 = Color3.fromRGB(38, 30, 26)
		linea.BackgroundTransparency = 0.3
		-- En la cara de arriba, lo vertical de la SurfaceGui va a lo largo de la x de la pieza: los renglones, en vertical.
		linea.Position = UDim2.fromScale(0.14 + i * 0.1, 0.12)
		linea.Size = UDim2.fromScale(0.018, if i == 6 then largo * 0.5 else largo)
		linea.Parent = gui
	end
	if manchada then
		local mancha = Instance.new("Frame")
		mancha.BorderSizePixel = 0
		mancha.BackgroundColor3 = Color3.fromRGB(78, 8, 6)
		mancha.AnchorPoint = Vector2.new(1, 1)
		mancha.Position = UDim2.fromScale(1.05, 1.05)
		mancha.Size = UDim2.fromScale(0.55, 0.42)
		local gradiente = Instance.new("UIGradient")
		gradiente.Rotation = -135
		gradiente.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.45, 0.55), NumberSequenceKeypoint.new(0.7, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradiente.Parent = mancha
		local esquina = Instance.new("UICorner")
		esquina.CornerRadius = UDim.new(0.5, 0)
		esquina.Parent = mancha
		mancha.Parent = gui
	end
end

-- Una foto: borde blanco amarillento y la imagen oscura y borrosa (dos siluetas).
local function foto(papel: Part)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.LightInfluence = 1
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 200
	gui.Parent = papel
	local imagen = Instance.new("Frame")
	imagen.BorderSizePixel = 0
	imagen.BackgroundColor3 = Color3.fromRGB(58, 50, 42)
	imagen.Position = UDim2.fromScale(0.08, 0.08)
	imagen.Size = UDim2.fromScale(0.84, 0.72)
	imagen.Parent = gui
	for _, s in { { 0.25, 0.3 }, { 0.6, 0.36 } } do
		local silueta = Instance.new("Frame")
		silueta.BorderSizePixel = 0
		silueta.BackgroundColor3 = Color3.fromRGB(26, 22, 20)
		silueta.Position = UDim2.fromScale(s[1], s[2])
		silueta.Size = UDim2.fromScale(0.16, 0.7)
		local esquina = Instance.new("UICorner")
		esquina.CornerRadius = UDim.new(0.4, 0)
		esquina.Parent = silueta
		silueta.Parent = imagen
	end
end

local PAPEL = Color3.fromRGB(190, 178, 150)

-- El objeto de la pista n. Devuelve la pieza que lleva el prompt.
local function construir(n: number, cf: CFrame, padre: Instance): Part
	local forma = Historia[n].forma
	local modelo = Instance.new("Model")
	modelo.Name = `Pista{n}`
	modelo:SetAttribute("N", n)
	local principal: Part
	if YA_HAY[n] then
		principal = pieza("Mando", Vector3.new(1, 1, 1), cf, PAPEL, Enum.Material.SmoothPlastic, modelo)
		principal.Transparency = 1
		principal.CanQuery = false
	elseif forma == "Foto" then
		principal = pieza("Foto", Vector3.new(0.85, 0.02, 0.68), cf * CFrame.new(0, 0.01, 0), Color3.fromRGB(206, 198, 178),
			Enum.Material.SmoothPlastic, modelo)
		foto(principal)
	elseif forma == "Libreta" or forma == "Diario" then
		-- Abierta: las tapas y, encima, las dos hojas.
		local grande = forma == "Diario"
		local ancho, largo = if grande then 1.9 else 1.5, if grande then 1.3 else 1.05
		pieza("Tapas", Vector3.new(ancho, 0.06, largo), cf * CFrame.new(0, 0.03, 0),
			if grande then Color3.fromRGB(70, 30, 24) else Color3.fromRGB(52, 44, 36), Enum.Material.Leather, modelo)
		for _, lado in { -1, 1 } do
			local hoja = pieza("Hoja", Vector3.new(ancho / 2 - 0.06, 0.04, largo - 0.08),
				cf * CFrame.new(lado * ancho / 4, 0.08, 0) * CFrame.Angles(0, 0, lado * -0.04), PAPEL, Enum.Material.SmoothPlastic,
				modelo)
			escrito(hoja, n + lado, false)
			if lado == 1 then
				principal = hoja
			end
		end
	else
		-- Una nota: si está en la pared, con un clavo.
		principal = pieza("Nota", Vector3.new(0.95, 0.02, 1.25), cf * CFrame.new(0, 0.01, 0), PAPEL, Enum.Material.SmoothPlastic,
			modelo)
		escrito(principal, n, MANCHADAS[n] == true)
		if math.abs(cf.YVector.Y) < 0.5 then
			pieza("Clavo", Vector3.new(0.08, 0.1, 0.08), cf * CFrame.new(0, 0.05, -0.5), Color3.fromRGB(60, 56, 52), Enum.Material.Metal,
				modelo)
		end
	end
	modelo.PrimaryPart = principal
	local prompt = Instance.new("ProximityPrompt")
	prompt.Style = Enum.ProximityPromptStyle.Custom -- lo pinta Controles, como los demás (en móvil, con su botón grande)
	prompt.ActionText = YA_HAY[n] or if forma == "Foto" then "Look" else "Read"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.ObjectText = ""
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = ALCANCE
	prompt.RequiresLineOfSight = false -- un papel en la mesa queda tapado por lo de al lado
	prompt.Parent = principal
	prompt.Triggered:Connect(function(jugador)
		Pistas.leer(jugador, n, principal)
	end)
	CollectionService:AddTag(modelo, "Pista")
	modelo.Parent = padre
	return principal
end

-- Cuántas se han encontrado ya en esta partida.
local function cuantas(): number
	local total = 0
	for _ in leidas do
		total += 1
	end
	return total
end

function Pistas.leer(jugador: Player, n: number, donde: BasePart)
	local personaje = jugador.Character
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoide = personaje and personaje:FindFirstChildOfClass("Humanoid")
	if not raiz or not humanoide or humanoide.Health <= 0 or jugador:GetAttribute("Muerto") then
		return
	end
	if (raiz.Position - donde.Position).Magnitude > ALCANCE + HOLGURA then
		return
	end
	if SALA[n] and table.find(Casa.cerradas(), SALA[n]) then
		return -- desde fuera, a través de la pared
	end
	local ahora = os.clock()
	if ahora - (ultimo[jugador] or 0) < 0.3 then
		return
	end
	ultimo[jugador] = ahora
	leidas[n] = true
	Remotes.Pista:FireClient(jugador, n, cuantas())
end

-- ¿Alguien ha leído ya la pista n en esta partida?
function Pistas.leida(n: number): boolean
	return leidas[n] == true
end

-- Para guardar: los números de las leídas, en orden.
function Pistas.exportar(): { number }
	local lista = {}
	for n = 1, #Historia do
		if leidas[n] then
			table.insert(lista, n)
		end
	end
	return lista
end

-- Las leídas de lo guardado (ya arreglado por FormatoPartida); {} = partida nueva.
function Pistas.importar(lista: { number }?)
	table.clear(leidas)
	for _, n in lista or {} do
		if Historia[n] then
			leidas[n] = true
		end
	end
end

function Pistas.start()
	assert(#SITIOS == #Historia, "Pistas: cada pista de shared/Historia necesita su sitio")
	local carpeta = Instance.new("Folder")
	carpeta.Name = "Pistas"
	for n, cf in SITIOS do
		construir(n, cf, carpeta)
	end
	carpeta.Parent = workspace:WaitForChild("Mapa")
	game:GetService("Players").PlayerRemoving:Connect(function(jugador)
		ultimo[jugador] = nil
	end)
end

return Pistas
