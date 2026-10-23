-- Pasos según el suelo (Config.Sonidos PasoMadera, PasoTierra y PasoHierba): los de cada jugador cerca de la cámara,
-- en 3D desde sus pies, más seguidos cuanto más rápido va. Quita el sonido de correr de serie de Roblox.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Sonido = require(script.Parent.Sonido)

local Pasos = {}

local CERCA = 60 -- studs de la cámara a los que se oyen los pasos de los demás
local ZANCADA = 7 -- studs entre paso y paso

local SUELO: { [Enum.Material]: string } = {
	[Enum.Material.Wood] = "PasoMadera",
	[Enum.Material.WoodPlanks] = "PasoMadera",
	[Enum.Material.Grass] = "PasoHierba",
	[Enum.Material.LeafyGrass] = "PasoHierba",
}

local andado: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any -- studs desde el último paso
local azar = Random.new()

-- El sonido de correr de serie (lo crea RbxCharacterSounds en la raíz): callado.
local function callar(personaje: Model)
	local raiz = personaje:WaitForChild("HumanoidRootPart", 10)
	if not raiz then
		return
	end
	local function mirar(s: Instance)
		if s:IsA("Sound") and s.Name == "Running" then
			s.Volume = 0
		end
	end
	for _, s in raiz:GetChildren() do
		mirar(s)
	end
	raiz.ChildAdded:Connect(mirar)
end

local function paso(dt: number)
	local camara = workspace.CurrentCamera
	for _, jugador in Players:GetPlayers() do
		local personaje = jugador.Character
		local humanoide = personaje and personaje:FindFirstChildOfClass("Humanoid")
		local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not humanoide or not raiz or humanoide.Health <= 0 or humanoide.FloorMaterial == Enum.Material.Air
			or (raiz.Position - camara.CFrame.Position).Magnitude > CERCA then
			andado[jugador] = 0
			continue
		end
		local v = raiz.AssemblyLinearVelocity
		local rapidez = Vector3.new(v.X, 0, v.Z).Magnitude
		if rapidez < 1 then
			andado[jugador] = ZANCADA * 0.6 -- al echar a andar, el primer paso enseguida
			continue
		end
		andado[jugador] = (andado[jugador] or 0) + rapidez * dt
		if andado[jugador] >= ZANCADA then
			andado[jugador] = 0
			local nombre = SUELO[humanoide.FloorMaterial] or "PasoTierra"
			Sonido.en(nombre, raiz.Position - Vector3.new(0, 2.8, 0), azar:NextNumber(0.9, 1.1))
		end
	end
end

local function alEntrar(jugador: Player)
	jugador.CharacterAdded:Connect(callar)
	if jugador.Character then
		task.spawn(callar, jugador.Character)
	end
end

function Pasos.start()
	Players.PlayerAdded:Connect(alEntrar)
	for _, jugador in Players:GetPlayers() do
		alEntrar(jugador)
	end
	RunService.Heartbeat:Connect(paso)
end

return Pasos
