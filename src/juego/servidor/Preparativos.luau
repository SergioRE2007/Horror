-- Preparar la casa para el final de la Bestia (12.2, pedido por el usuario; diseño en TASKS.md). Lo explican las
-- pistas (la 9, el plano de la reja; la 12, las cruces de gasolina).
--   Gasolina: 6 cruces pintadas en el suelo (PUNTOS: escalera del vestíbulo, salón, dormitorio de abajo, pasillo,
--   cocina y dormitorio grande). Con un bidón en las manos, R junto a la cruz (Cargar.alUsar "Bidon", etiqueta
--   "Gasolina"): se echa POR_PUNTO de bidón y queda un charco. Con las 6, un rastro de gasolina va de la primera (la de la
--   escalera, junto a la puerta) al porche: ahí se prende (Incendio). El fuego corre en el orden de PUNTOS.
--   Reja: sale del banco del sótano (Taller, Recetas.delBanco) y se lleva con R al marco del pie de la escalera del
--   sótano (etiqueta "MarcoReja", de Mapa): queda montada y subida. La palanca junto a la trampilla la deja caer (solo
--   con la Bestia suelta, o en pruebas) y llama a Bestia.encerrar(Preparativos.sotano). Sin ella dentro, la reja ha
--   fallado: se queda cerrada esa noche (al amanecer vuelve a subir).
--   Trampilla: del sótano al patio por una escalera de mano; se abre desde abajo (E) y se queda abierta.
--   "Wait for her" (E) en medio del vestíbulo, de día y con todo listo: empieza la noche ya y Bestia.soltar().
-- Estado para el cliente (PreparativosVista), en atributos: cada punto (modelo "Gasolina") Clave, Orden y Lleno; el
-- porche ("PorcheGasolina") Rastro y Desde; el marco Montada y Caida; la palanca Bajada; la trampilla Abierto.
--   Remote `Preparativos` (servidor -> todos): ("Reja", posición) la reja acaba de caer (golpe de hierro).
-- Se guarda con la partida (exportar/importar, FormatoPartida): puntos con gasolina por su clave, rastro y reja montada.
-- Modo de pruebas: ServerStorage.Prueba:Fire("Preparar") lo deja todo listo y da pistola, 3 bengalas y cerillas al
-- primer jugador; ("Palanca") deja caer la reja ya.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Prueba = require(ReplicatedStorage.Shared.Prueba)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Bestia = require(script.Parent.Bestia)
local Cargar = require(script.Parent.Cargar)
local Ciclo = require(script.Parent.Ciclo)
local Mochila = require(script.Parent.Mochila)
local Muerte = require(script.Parent.Muerte)

local Preparativos = {}

local B = Config.Bestia
-- Parte de un bidón que se echa en cada cruz: solo hay 4 bidones en el mapa y no se rellenan (el generador y el coche
-- también gastan), así que uno lleno da para 3.
local POR_PUNTO = Config.Bestia.PorPunto
local MONTAR = Config.Bestia.Montar
local CAER = Config.Bestia.Caer

-- Los puntos, en el orden en que corre el fuego desde el porche hacia dentro: { clave (se guarda: no cambiarla),
-- punto del suelo de su sala (el de ronda del Golpeador, libre de muebles) }. Lo nuevo, al final.
local PUNTOS = {
	{ "Escalera", Vector3.new(0, 1, -20) }, -- al pie de la escalera del vestíbulo: de aquí sale el rastro
	{ "Salon", Vector3.new(25, 1, -15) },
	{ "Dormitorio", Vector3.new(28, 1, 12) }, -- el de la abuela, abajo
	{ "Pasillo", Vector3.new(0, 1, 22) },
	{ "Cocina", Vector3.new(-30, 1, 11) },
	{ "DormitorioGrande", Vector3.new(25, 14, -14) }, -- el de los dueños, arriba
}
local PORCHE = Vector3.new(0, 1, -38.5) -- delante de la puerta principal
local ESPERAR = Vector3.new(0, 4, -24) -- el prompt de "Wait for her", en medio del vestíbulo
local SOTANO = { x1 = -12, x2 = 12, y1 = -12.5, y2 = -1, z1 = 47.1, z2 = 66 } -- la sala, detrás de la reja (z 46,9)

local carpeta: Folder
local modelos: { Model } = {} -- los puntos, en orden
local llenos: { [string]: boolean } = {}
local llenando: { [Model]: boolean } = {}
local rastro = false
local montada = false
local montando = false
local caida = false
local soltada = false -- ya se ha usado "Wait for her" (hasta volver al amanecer)
local porche: BasePart
local marco: Model
local hoja: BasePart
local palanca: Model
local trampilla: Model
local promptEsperar: ProximityPrompt
local promptPalanca: ProximityPrompt
local promptTrampilla: ProximityPrompt

local function avisar(jugador: Player, texto: string)
	Remotes.Aviso:FireClient(jugador, Lang.t(jugador, texto))
end

local function avisarTodos(texto: string)
	for _, jugador in Players:GetPlayers() do
		avisar(jugador, texto)
	end
end

-- Vivo, fuera de un escondite y cerca de `parte`.
local function cerca(jugador: Player, parte: BasePart): BasePart?
	local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if raiz and table.find(Muerte.vivos(), jugador) and not jugador:GetAttribute("Escondido")
		and (parte.Position - raiz.Position).Magnitude <= Config.Casa.Alcance + 4 then
		return raiz
	end
	return nil
end

-- La cara de arriba del suelo bajo `punto` (lo primero que hay debajo, sin contar personajes ni cosas sueltas).
local function alSuelo(punto: Vector3): Vector3
	local filtro = RaycastParams.new()
	filtro.FilterType = Enum.RaycastFilterType.Exclude
	local fuera: { Instance } = { carpeta }
	for _, nombre in { "Objetos", "Pesados" } do
		local f = workspace:FindFirstChild(nombre)
		if f then
			table.insert(fuera, f)
		end
	end
	for _, jugador in Players:GetPlayers() do
		if jugador.Character then
			table.insert(fuera, jugador.Character)
		end
	end
	filtro.FilterDescendantsInstances = fuera
	local hit = workspace:Raycast(punto + Vector3.new(0, 4, 0), Vector3.new(0, -8, 0), filtro)
	return if hit then hit.Position else punto
end

local function pieza(nombre: string, tam: Vector3, cf: CFrame, padre: Instance): Part
	local p = Instance.new("Part")
	p.Name = nombre
	p.Anchored = true
	p.Size = tam
	p.CFrame = cf
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Parent = padre
	return p
end

local function todos(): boolean
	for _, p in PUNTOS do
		if not llenos[p[1]] then
			return false
		end
	end
	return true
end

local function nuevoPrompt(parte: BasePart, texto: string): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.Style = Enum.ProximityPromptStyle.Custom
	p.ActionText = texto
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p.MaxActivationDistance = Config.Casa.Alcance
	p.RequiresLineOfSight = false
	p.Parent = parte
	return p
end

-- La reja montada se ve (y choca) subida o caída; sin montar no está.
local function colocarReja()
	hoja.CFrame = marco:GetAttribute(if caida then "Cerrada" else "Abierta") :: CFrame
	hoja.CanCollide = montada
	hoja.CanQuery = montada
	for _, b in hoja:GetChildren() do
		if b:IsA("BasePart") then
			b.Transparency = if montada then 0 else 1
		end
	end
end

local function actualizarEsperar()
	local fase = Ciclo.fase()
	promptEsperar.Enabled = Preparativos.listo() and fase == "Dia" and not soltada and not Bestia.activa()
end

local function publicar()
	for _, m in modelos do
		m:SetAttribute("Lleno", llenos[m:GetAttribute("Clave")] == true)
	end
	porche:SetAttribute("Rastro", rastro)
	marco:SetAttribute("Montada", montada)
	marco:SetAttribute("Caida", caida)
	palanca:SetAttribute("Bajada", caida)
	promptPalanca.Enabled = montada and not caida
	actualizarEsperar()
end

-- Echar gasolina en una cruz.
local function usoBidon(): Cargar.Uso
	return {
		etiquetas = { "Gasolina" },
		accion = "Verter",
		preparar = function(jugador, objetivo, bidon)
			local clave = objetivo:GetAttribute("Clave")
			if type(clave) ~= "string" or llenos[clave] then
				avisar(jugador, "There's already fuel here.")
				return nil
			elseif llenando[objetivo :: Model] then
				avisar(jugador, "Someone is already using it.")
				return nil
			elseif (bidon:GetAttribute("Carga") or 0) < POR_PUNTO - 0.01 then
				avisar(jugador, "The can is empty.")
				return nil
			end
			llenando[objetivo :: Model] = true
			local suelo = (objetivo:FindFirstChild("Mando") :: BasePart).Position
			-- Inclinado encima de la cruz, con la boca hacia abajo.
			return CFrame.new(suelo + Vector3.new(0.9, 1.7, 0)) * CFrame.Angles(0, 0, math.rad(115)), B.Verter
		end,
		cancelar = function(_jugador, objetivo)
			llenando[objetivo :: Model] = nil
		end,
		terminar = function(jugador, objetivo, bidon)
			llenando[objetivo :: Model] = nil
			local suelo = (objetivo:FindFirstChild("Mando") :: BasePart).Position
			local carga = bidon:GetAttribute("Carga") or 0
			if carga >= POR_PUNTO - 0.01 then
				bidon:SetAttribute("Carga", math.max(0, carga - POR_PUNTO))
				llenos[objetivo:GetAttribute("Clave")] = true
				if not rastro and todos() then
					rastro = true
					avisar(jugador, "The fuel trail now runs to the porch.")
				end
				publicar()
			end
			Cargar.liberar(bidon, CFrame.new(suelo + Vector3.new(2, 1.3, 0)))
		end,
	}
end

-- Montar la reja pesada en su marco: queda subida.
local function usoReja(): Cargar.Uso
	return {
		etiquetas = { "MarcoReja" },
		accion = "Montar",
		preparar = function(jugador)
			if montada or montando then
				avisar(jugador, "The gate is already in place.")
				return nil
			end
			montando = true
			return marco:GetAttribute("Abierta") :: CFrame, MONTAR
		end,
		cancelar = function()
			montando = false
		end,
		terminar = function(jugador, _objetivo, reja)
			montando = false
			reja:Destroy()
			montada, caida = true, false
			colocarReja()
			publicar()
			avisar(jugador, "The gate is ready. The lever drops it.")
		end,
	}
end

-- La reja cae: encierra a la Bestia si está dentro del sótano; si no, ha fallado y se queda cerrada.
local function dejarCaer()
	if not montada or caida then
		return
	end
	caida = true
	publicar()
	local abajo = marco:GetAttribute("Cerrada") :: CFrame
	TweenService:Create(hoja, TweenInfo.new(CAER, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = abajo }):Play()
	task.delay(CAER, function()
		if not caida then -- se ha vuelto a subir mientras caía (volver al amanecer)
			return
		end
		hoja.CFrame = abajo
		Remotes.Preparativos:FireAllClients("Reja", abajo.Position)
		if not Bestia.encerrar(Preparativos.sotano) then
			avisarTodos("The gate fell with nothing behind it.")
		end
	end)
end

local function tirar(jugador: Player)
	if not cerca(jugador, palanca:FindFirstChild("Mando") :: BasePart) or caida then
		return
	end
	if not montada then
		avisar(jugador, "There's no gate to drop.")
	elseif not Bestia.activa() and not Prueba.activa() then
		avisar(jugador, "Not yet. Wait for her.")
	else
		dejarCaer()
	end
end

-- La trampilla solo se abre desde abajo (desde el patio, el prompt no se ve: la tapa lo tapa).
local function abrirTrampilla(jugador: Player)
	local raiz = cerca(jugador, trampilla:FindFirstChild("Mando") :: BasePart)
	if not raiz or raiz.Position.Y > -1 or trampilla:GetAttribute("Abierto") then
		return
	end
	local tapa = trampilla:FindFirstChild("Tapa") :: BasePart
	tapa.CFrame = trampilla:GetAttribute("Abierta") :: CFrame
	tapa.CanCollide = false
	trampilla:SetAttribute("Abierto", true)
	promptTrampilla.Enabled = false
end

local function esperar(jugador: Player)
	if not cerca(jugador, promptEsperar.Parent :: BasePart) or not Preparativos.listo() or soltada or Bestia.activa()
		or Ciclo.fase() ~= "Dia" then
		return
	end
	soltada = true
	avisarTodos("She's coming. Get ready.")
	Ciclo.forzar("Noche")
	Bestia.soltar()
	publicar()
end

-- Las claves de los puntos, en orden (para FormatoPartida).
function Preparativos.claves(): { string }
	local lista = {}
	for _, p in PUNTOS do
		table.insert(lista, p[1])
	end
	return lista
end

-- Los puntos de gasolina (la pieza a ras del suelo de cada cruz), en el orden en que corre el fuego.
function Preparativos.puntos(): { BasePart }
	local lista = {}
	for _, m in modelos do
		table.insert(lista, m:FindFirstChild("Mando") :: BasePart)
	end
	return lista
end

-- El final del rastro en el porche (donde se prende).
function Preparativos.porche(): BasePart
	return porche
end

function Preparativos.listo(): boolean
	return todos() and rastro and montada
end

-- ¿Está este punto dentro de la sala del sótano (detrás de la reja)?
function Preparativos.sotano(posicion: Vector3): boolean
	local s = SOTANO
	return posicion.X > s.x1 and posicion.X < s.x2 and posicion.Y > s.y1 and posicion.Y < s.y2 and posicion.Z > s.z1
		and posicion.Z < s.z2
end

-- Lo que se guarda (Partida): { gasolina = claves de los puntos llenos, rastro, reja = montada }.
function Preparativos.exportar()
	local gasolina = {}
	for _, p in PUNTOS do
		if llenos[p[1]] then
			table.insert(gasolina, p[1])
		end
	end
	return { gasolina = gasolina, rastro = rastro, reja = montada }
end

-- Lo deja como en `t` (ya arreglado por FormatoPartida; nil = nada hecho). La reja montada, subida.
function Preparativos.importar(t)
	table.clear(llenos)
	rastro, montada, caida, soltada = false, false, false, false
	if type(t) == "table" then
		local validas = {}
		for _, p in PUNTOS do
			validas[p[1]] = true
		end
		for _, c in (if type(t.gasolina) == "table" then t.gasolina else {}) do
			if validas[c] then
				llenos[c] = true
			end
		end
		rastro = t.rastro == true and todos()
		montada = t.reja == true
	end
	colocarReja()
	publicar()
end

local function crearPunto(orden: number, clave: string, donde: Vector3)
	local modelo = Instance.new("Model")
	modelo.Name = "Gasolina" .. clave
	modelo.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local suelo = alSuelo(donde)
	local mando = pieza("Mando", Vector3.new(2.4, 0.1, 2.4), CFrame.new(suelo + Vector3.new(0, 0.05, 0)), modelo)
	-- La cruz: dos trazos de pintura roja oscura, como las que marcó el rico (pista 12).
	for i, angulo in { 45, -45 } do
		local trazo = pieza("Cruz", Vector3.new(2, 0.02, 0.2), CFrame.new(suelo + Vector3.new(0, 0.03 + i * 0.004, 0))
			* CFrame.Angles(0, math.rad(angulo), 0), modelo)
		trazo.Transparency = 0.3
		trazo.Color = Color3.fromRGB(78, 24, 20)
		trazo.Material = Enum.Material.SmoothPlastic
	end
	modelo.PrimaryPart = mando
	modelo:SetAttribute("Clave", clave)
	modelo:SetAttribute("Orden", orden)
	modelo:SetAttribute("Lleno", false)
	CollectionService:AddTag(modelo, "Gasolina")
	modelo.Parent = carpeta
	table.insert(modelos, modelo)
end

function Preparativos.start()
	carpeta = Instance.new("Folder")
	carpeta.Name = "Preparativos"
	carpeta.Parent = workspace:WaitForChild("Mapa")
	for i, p in PUNTOS do
		crearPunto(i, p[1], p[2])
	end
	porche = pieza("Porche", Vector3.new(1.5, 0.1, 1.5), CFrame.new(alSuelo(PORCHE) + Vector3.new(0, 0.05, 0)), carpeta)
	porche:SetAttribute("Rastro", false)
	porche:SetAttribute("Desde", (modelos[1]:FindFirstChild("Mando") :: BasePart).Position)
	CollectionService:AddTag(porche, "PorcheGasolina")
	local esperarMando = pieza("Esperar", Vector3.new(1, 1, 1), CFrame.new(ESPERAR), carpeta)
	promptEsperar = nuevoPrompt(esperarMando, "Wait for her")
	promptEsperar.HoldDuration = 1
	promptEsperar.Triggered:Connect(esperar)

	-- La reja, en su marco (de Mapa): la pieza invisible que choca y los barrotes que se ven.
	marco = CollectionService:GetTagged("MarcoReja")[1] :: Model
	local cerrada = marco:GetAttribute("Cerrada") :: CFrame
	hoja = Instance.new("Part")
	hoja.Name = "Reja"
	hoja.Anchored = true
	hoja.Size = marco:GetAttribute("Tam") :: Vector3
	hoja.CFrame = cerrada
	Cargar.barrotes(hoja)
	hoja.Parent = marco

	palanca = CollectionService:GetTagged("Palanca")[1] :: Model
	promptPalanca = nuevoPrompt(palanca:FindFirstChild("Mando") :: BasePart, "Pull")
	promptPalanca.HoldDuration = B.Palanca
	promptPalanca.Triggered:Connect(tirar)
	trampilla = CollectionService:GetTagged("Trampilla")[1] :: Model
	trampilla:SetAttribute("Abierto", false)
	promptTrampilla = nuevoPrompt(trampilla:FindFirstChild("Mando") :: BasePart, "Open")
	promptTrampilla.RequiresLineOfSight = true -- desde el patio la tapa lo tapa

	Cargar.alUsar("Bidon", usoBidon())
	Cargar.alUsar("Reja", usoReja())
	promptTrampilla.Triggered:Connect(abrirTrampilla)
	Ciclo.alCambiar(function(fase)
		-- Una reja que falló vuelve a subir al amanecer (con la Bestia encerrada, no).
		-- Al amanecer la Bestia se ha ido (Director): la reja sube y se la puede volver a esperar.
		if fase == "Dia" then
			soltada = false
			if caida and not workspace:GetAttribute("Final") then
				caida = false
				colocarReja()
			end
		end
		publicar()
	end)
	task.spawn(function() -- la Bestia se va o muere sin avisar: el prompt de esperarla, al día
		while true do
			task.wait(1)
			actualizarEsperar()
		end
	end)
	colocarReja()
	publicar()

	if not Prueba.activa() then
		return
	end
	task.spawn(function() -- el BindableEvent lo crea Director, que arranca después
		ServerStorage:WaitForChild("Prueba").Event:Connect(function(que: string)
			if que == "Preparar" then
				for _, p in PUNTOS do
					llenos[p[1]] = true
				end
				rastro, montada, caida = true, true, false
				colocarReja()
				publicar()
				local jugador = Players:GetPlayers()[1]
				if jugador then
					for _, tipo in { "Pistola", "Bengala", "Bengala", "Bengala", "Cerillas" } do
						Mochila.dar(jugador, tipo)
					end
				end
			elseif que == "Palanca" then
				dejarCaer()
			end
		end)
	end)
end

return Preparativos
