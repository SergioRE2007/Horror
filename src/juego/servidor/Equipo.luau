-- Linterna con pilas y cámara con flash (pedido por el usuario). El cliente solo pide (remotes Linterna y Flash) y
-- pinta la luz (EquipoVista); aquí se gasta la pila, se cuentan las fotos y se mira a qué bicho le da la luz.
--   Atributos del jugador: Linterna (encendida), Pila (0..1), Pilas (de repuesto), Fotos (del carrete puesto),
--   Carretes (de repuesto), Cambiando ("Pila" o "Carrete" mientras cambia).
--   La linterna: encendida sobre un bicho le apunta `iluminado` (el Raspador raspa más lento).
--   El flash: al bicho que le dé, `alFlash` (el Raspador huye) o se queda aturdido.
-- La luz no pasa paredes ni la persiana bajada de la ventana a la que está pegado el bicho; sí el cristal.
-- La linterna, la cámara, las pilas y los carretes son objetos de la mochila (Mochila): sin linterna no hay luz y sin
-- cámara no hay flash. La pila de la linterna y las fotos de la cámara van en su `carga`; aquí se gastan.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Stats = require(ReplicatedStorage.Shared.Stats)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Casa = require(script.Parent.Casa)
local Caza = require(script.Parent.Caza)
local Mochila = require(script.Parent.Mochila)
local Muerte = require(script.Parent.Muerte)

local Equipo = {}

local L, F = Config.Linterna, Config.Flash
local ultimoFlash: { [Player]: number } = {}
local cristales: { Instance } = {}
local filtro = RaycastParams.new()
filtro.FilterType = Enum.RaycastFilterType.Exclude

local function cabezaDe(jugador: Player): BasePart?
	local personaje = jugador.Character
	return personaje and personaje:FindFirstChild("Head") :: BasePart?
end

local function puedeUsar(jugador: Player): boolean
	return table.find(Muerte.vivos(), jugador) ~= nil and not jugador:GetAttribute("Escondido")
end

-- ¿Llega la luz desde `ojo` hasta el bicho, dentro de `angulo` grados alrededor de `hacia`?
local function alcanza(ojo: Vector3, hacia: Vector3, b: Caza.Bicho, alcance: number, angulo: number): boolean
	local blanco = b:cabeza()
	local vector = blanco - ojo
	if vector.Magnitude > alcance or vector.Magnitude < 0.1 or hacia.Magnitude < 0.1 then
		return false
	end
	if vector.Unit:Dot(hacia.Unit) < math.cos(math.rad(angulo)) then
		return false
	end
	if b.ventana and Caza.dentroDeCasa(ojo) and Casa.estado(b.ventana).persiana then
		return false -- la persiana bajada tapa (sus lamas solo existen en el cliente)
	end
	local ignorar = table.clone(cristales)
	table.insert(ignorar, Caza.carpeta())
	for _, otro in Players:GetPlayers() do
		if otro.Character then
			table.insert(ignorar, otro.Character)
		end
	end
	filtro.FilterDescendantsInstances = ignorar
	return workspace:Raycast(ojo, vector, filtro) == nil
end

-- Pone una pila o un carrete nuevo (tarda un poco). false si no le quedan.
local function cambiar(jugador: Player, que: string): boolean
	if jugador:GetAttribute("Cambiando") then
		return true
	end
	if not Mochila.gastar(jugador, que) then
		Remotes.Aviso:FireClient(jugador, Lang.t(jugador, if que == "Pila" then "No batteries left." else "No film left."))
		return false
	end
	jugador:SetAttribute("Cambiando", que)
	task.delay(if que == "Pila" then L.Cambiar else F.Cambiar, function()
		if not jugador.Parent then
			return
		end
		jugador:SetAttribute("Cambiando", nil)
		local cosa = Mochila.primera(jugador, if que == "Pila" then "Linterna" else "Camara")
		if cosa then -- si la ha tirado mientras cambiaba, la pila o el carrete se pierde
			cosa.carga = if que == "Pila" then 1 else F.Fotos
			Mochila.publicar(jugador)
			if que == "Pila" then
				jugador:SetAttribute("Linterna", true)
			end
		end
	end)
	return true
end

local function alternarLinterna(jugador: Player)
	if not puedeUsar(jugador) or jugador:GetAttribute("Cambiando") then
		return
	end
	local linterna = Mochila.primera(jugador, "Linterna")
	if not linterna then
		Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "You don't have a flashlight."))
	elseif jugador:GetAttribute("Linterna") then
		jugador:SetAttribute("Linterna", false)
	elseif (linterna.carga or 0) > 0 then
		jugador:SetAttribute("Linterna", true)
	else
		cambiar(jugador, "Pila")
	end
end

local function flash(jugador: Player, hacia: unknown)
	if typeof(hacia) ~= "Vector3" or hacia.Magnitude ~= hacia.Magnitude or hacia.Magnitude < 0.1 then
		return
	end
	local cabeza = cabezaDe(jugador)
	if not cabeza or not puedeUsar(jugador) or jugador:GetAttribute("Cambiando") then
		return
	end
	local camara = Mochila.primera(jugador, "Camara")
	if not camara then
		Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "You don't have a camera."))
		return
	end
	if jugador:GetAttribute("Cargando") or jugador:GetAttribute("MochilaAbierta") or jugador:GetAttribute("Trabajando") then
		Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "Your hands are full."))
		return
	end
	local ahora = os.clock()
	if ahora - (ultimoFlash[jugador] or -math.huge) < F.Recarga * Stats.valor(jugador, "Recarga") then
		return
	end
	if (camara.carga or 0) <= 0 then
		cambiar(jugador, "Carrete")
		return
	end
	ultimoFlash[jugador] = ahora
	camara.carga -= 1
	jugador:SetAttribute("Fotos", camara.carga)
	Remotes.Flash:FireAllClients(jugador)
	for _, b in Caza.todos() do
		if alcanza(cabeza.Position, hacia, b, F.Alcance, F.Angulo) then
			if b.alFlash then
				b.alFlash(jugador)
			else
				b:aturdir(F.Aturde * Stats.valor(jugador, "Aturde"))
			end
		end
	end
end

-- Gasta la pila de las linternas encendidas y apunta a qué bichos les da.
local acumulado = 0
local function gastar(dt: number)
	acumulado += dt
	if acumulado < 0.2 then
		return
	end
	local paso = acumulado
	acumulado = 0
	local bichos = Caza.todos()
	for _, jugador in Players:GetPlayers() do
		if not jugador:GetAttribute("Linterna") then
			continue
		end
		local cabeza = cabezaDe(jugador)
		local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not cabeza or not raiz or not puedeUsar(jugador) then
			jugador:SetAttribute("Linterna", false)
			continue
		end
		local linterna = Mochila.primera(jugador, "Linterna")
		if not linterna then
			jugador:SetAttribute("Linterna", false)
			continue
		end
		local pila = math.max(0, (linterna.carga or 0) - paso / (L.Duracion * Stats.valor(jugador, "Pila")))
		linterna.carga = pila
		jugador:SetAttribute("Pila", pila)
		if pila <= 0 then
			jugador:SetAttribute("Linterna", false)
			continue
		end
		-- En primera persona el cuerpo gira con la cámara: basta con hacia dónde mira, sin la altura.
		for _, b in bichos do
			local hacia = Caza.plano(raiz.CFrame.LookVector)
			local plano = Caza.plano(b:cabeza() - cabeza.Position)
			if plano.Magnitude > 0.1 and plano.Unit:Dot(hacia.Unit) > math.cos(math.rad(L.Angulo))
				and alcanza(cabeza.Position, b:cabeza() - cabeza.Position, b, L.Alcance * Stats.valor(jugador, "Luz"), 90) then
				b.iluminado = os.clock()
			end
		end
	end
end

function Equipo.start()
	for _, el in CollectionService:GetTagged("Ventana") do
		local cristal = el:FindFirstChild("Cristal")
		if cristal then
			table.insert(cristales, cristal)
		end
	end
	Players.PlayerRemoving:Connect(function(jugador)
		ultimoFlash[jugador] = nil
	end)
	Remotes.Linterna.OnServerEvent:Connect(alternarLinterna)
	Remotes.Flash.OnServerEvent:Connect(flash)
	RunService.Heartbeat:Connect(gastar)
end

return Equipo
