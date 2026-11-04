-- Pasos según el suelo (Config.Sonidos PasoMadera, PasoTierra y PasoHierba): los de cada jugador cerca de la cámara,
-- en 3D desde sus pies, más seguidos cuanto más rápido va. Quita el sonido de correr de serie de Roblox.
--   Corriendo (14.8, pedido por el usuario: "todo animado e inmersivo"; tú: CorrerVista, los demás: su atributo
--   Corriendo), los pasos van más seguidos (ZANCADA_CORRE, como CuerpoVista), suenan más fuerte y su tono varía más.
--   Al tropezar (tú: CorrerVista.tropiezo; los demás: su atributo Tropiezo sube), un pisotón fuerte y luego el pie que
--   se arrastra.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CorrerVista = require(script.Parent.CorrerVista)
local Sonido = require(script.Parent.Sonido)

local Pasos = {}

local CERCA = 60 -- studs de la cámara a los que se oyen los pasos de los demás
local ZANCADA = 7 -- studs entre paso y paso
-- Correr. Números a ojo (para mirarlos en Studio).
local ZANCADA_CORRE = 6.2 -- studs entre paso y paso corriendo (como CuerpoVista)
local FUERTE = 1.4 -- corriendo, el volumen por esto
local TONO = { 0.9, 1.1 } -- azar de tono andando...
local TONO_CORRE = { 0.85, 1.2 } -- ...y corriendo
local PISOTON = { tono = 0.78, volumen = 1.9 } -- al tropezar, el pisotón...
local ARRASTRA = { { 0.12, 0.62, 1.1 }, { 0.26, 0.55, 0.6 } } -- ...y el pie que se arrastra: { s después, tono, volumen }

local SUELO: { [Enum.Material]: string } = {
	[Enum.Material.Wood] = "PasoMadera",
	[Enum.Material.WoodPlanks] = "PasoMadera",
	[Enum.Material.Grass] = "PasoHierba",
	[Enum.Material.LeafyGrass] = "PasoHierba",
}

local andado: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any -- studs desde el último paso
local azar = Random.new()
local mioAntes: number? = nil -- lo que dio CorrerVista.tropiezo() la vez anterior (para ver uno nuevo)

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

-- Lo que pisa ahora y dónde (nil si no está en el suelo, vivo y cerca de la cámara).
local function pies(jugador: Player): (string?, Vector3?)
	local personaje = jugador.Character
	local humanoide = personaje and personaje:FindFirstChildOfClass("Humanoid")
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoide or not raiz or humanoide.Health <= 0 or humanoide.FloorMaterial == Enum.Material.Air
		or (raiz.Position - workspace.CurrentCamera.CFrame.Position).Magnitude > CERCA then
		return nil, nil
	end
	return SUELO[humanoide.FloorMaterial] or "PasoTierra", raiz.Position - Vector3.new(0, 2.8, 0)
end

-- Un tropiezo: un pisotón y el pie que se arrastra (el suelo y el sitio se miran otra vez en cada uno).
local function tropezar(jugador: Player)
	local nombre, donde = pies(jugador)
	if not nombre or not donde then
		return
	end
	local s = Sonido.en(nombre, donde, PISOTON.tono)
	s.Volume *= PISOTON.volumen
	for _, a in ARRASTRA do
		task.delay(a[1], function()
			local otroSuelo, ahora = pies(jugador)
			if otroSuelo and ahora then
				local r = Sonido.en(otroSuelo, ahora, a[2])
				r.Volume *= a[3]
			end
		end)
	end
end

local function paso(dt: number)
	local camara = workspace.CurrentCamera
	-- Tu tropiezo, en cuanto lo predice CorrerVista.
	local mio = CorrerVista.tropiezo()
	if mio and (mioAntes == nil or mio < mioAntes) then
		tropezar(Players.LocalPlayer)
		andado[Players.LocalPlayer] = 0 -- el siguiente paso, tras la zancada entera
	end
	mioAntes = mio
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
		-- Corriendo: tú, lo de CorrerVista (mezclado como la cámara); los demás, su atributo.
		local yo = jugador == Players.LocalPlayer
		local ritmo = if yo then CorrerVista.ritmo() elseif jugador:GetAttribute("Corriendo") == true then 1 else 0
		local corriendo = if yo then CorrerVista.corriendo() else ritmo > 0
		andado[jugador] = (andado[jugador] or 0) + rapidez * dt
		if andado[jugador] >= ZANCADA + (ZANCADA_CORRE - ZANCADA) * ritmo then
			andado[jugador] = 0
			local nombre = SUELO[humanoide.FloorMaterial] or "PasoTierra"
			local tono = if corriendo then TONO_CORRE else TONO
			local s = Sonido.en(nombre, raiz.Position - Vector3.new(0, 2.8, 0), azar:NextNumber(tono[1], tono[2]))
			if s and jugador:GetAttribute("Agachado") then
				s.Volume *= 0.5 -- agachado se pisa con cuidado (14.6)
			elseif s and corriendo then
				s.Volume *= FUERTE
			end
		end
	end
end

local function alEntrar(jugador: Player)
	-- El tropiezo de los demás: su atributo Tropiezo sube (el tuyo va por CorrerVista, sin esperar al servidor).
	if jugador ~= Players.LocalPlayer then
		local visto = jugador:GetAttribute("Tropiezo")
		jugador:GetAttributeChangedSignal("Tropiezo"):Connect(function()
			local ahora = jugador:GetAttribute("Tropiezo")
			if type(ahora) == "number" and (type(visto) ~= "number" or ahora > visto) then
				tropezar(jugador)
			end
			visto = ahora
		end)
	end
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
