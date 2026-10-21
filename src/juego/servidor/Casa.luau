-- Lo que se toca de la casa: persianas, cristales y puertas (las reglas, en shared/Defensa).
-- El servidor guarda el estado de cada una y lo publica en atributos del modelo; el cliente (CasaVista) lo anima.
-- Las puertas: el servidor nunca mueve la hoja (la gira cada cliente); solo le quita la colisión al abrirse.
-- Cada cosa tiene un ProximityPrompt principal (persiana o puerta) y otro de reparar que sale solo si hace falta.
-- Se repara clavando un tablón que se lleva en las manos (Cargar.alUsar "Tablon").
-- Los textos de los prompts van en inglés y el cliente los traduce al pintarlos (Controles).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Defensa = require(ReplicatedStorage.Shared.Defensa)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Cargar = require(script.Parent.Cargar)

local Casa = {}

local cfg = Config.Casa
local estados: { [Model]: Defensa.Estado } = {}
local prompts: { [Model]: { principal: ProximityPrompt, reparar: ProximityPrompt } } = {}

local function ahora(): number
	return workspace:GetServerTimeNow()
end

local function publicar(el: Model)
	local e = estados[el]
	el:SetAttribute("Vida", e.vida)
	el:SetAttribute("VidaMax", e.vidaMax)
	local p = prompts[el]
	if e.tipo == "Ventana" then
		el:SetAttribute("Persiana", e.persiana)
		el:SetAttribute("Cristal", e.cristal)
		p.principal.ActionText = if e.persiana then "Raise shutter" else "Lower shutter"
		p.principal.Enabled = e.vida > 0
	else
		el:SetAttribute("Abierta", e.abierta)
		local hoja = el:FindFirstChild("Hoja") :: BasePart
		hoja.CanCollide = not e.abierta
		p.principal.ActionText = if e.abierta then "Close" else "Open"
		p.principal.Enabled = e.vida > 0
	end
	p.reparar.Enabled = Defensa.necesitaReparar(e)
end

-- ¿Puede este jugador tocarlo? Vivo, fuera de un escondite, cerca y, si es una ventana, desde dentro de la casa.
local function puede(jugador: Player, el: Model): boolean
	local personaje = jugador.Character
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoide = personaje and personaje:FindFirstChildOfClass("Humanoid")
	if not raiz or not humanoide or humanoide.Health <= 0 or jugador:GetAttribute("Escondido") then
		return false
	end
	local mando = el:FindFirstChild("Mando") :: BasePart
	if (raiz.Position - mando.Position).Magnitude > cfg.Alcance + 4 then
		return false
	end
	local centro = el:GetAttribute("Centro")
	if estados[el].tipo == "Ventana" and typeof(centro) == "CFrame" then
		return (raiz.Position - centro.Position):Dot(centro.LookVector) < 0
	end
	return true
end

local function nuevoPrompt(mando: BasePart, tecla: Enum.KeyCode, mandoTecla: Enum.KeyCode, texto: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.ActionText = texto
	prompt.KeyboardKeyCode = tecla
	prompt.GamepadKeyCode = mandoTecla
	prompt.MaxActivationDistance = cfg.Alcance
	prompt.RequiresLineOfSight = false
	prompt.Parent = mando
	return prompt
end

local function preparar(el: Model, tipo: string)
	local e = Defensa.nueva(tipo, cfg)
	e.bloqueada = el:GetAttribute("Bloqueada") == true
	estados[el] = e
	local mando = el:WaitForChild("Mando") :: BasePart
	local principal = nuevoPrompt(mando, Enum.KeyCode.E, Enum.KeyCode.ButtonX, "")
	local reparar = nuevoPrompt(mando, Enum.KeyCode.R, Enum.KeyCode.ButtonY, "Repair")
	reparar.UIOffset = Vector2.new(0, 60)
	prompts[el] = { principal = principal, reparar = reparar }

	-- Siempre estados[el] (no `e`): restaurar cambia la tabla.
	principal.Triggered:Connect(function(jugador)
		local e = estados[el]
		if not puede(jugador, el) then
			return
		end
		if tipo == "Ventana" then
			if Defensa.persiana(e, ahora(), cfg) then
				publicar(el)
			end
		elseif e.bloqueada then
			el:SetAttribute("Intentos", (el:GetAttribute("Intentos") or 0) + 1) -- el cliente sacude el pomo
			Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "It's locked."))
		elseif Defensa.puerta(e, ahora(), cfg) then
			publicar(el)
		end
	end)
	-- Se repara con un tablón en las manos (Cargar, R): este prompt solo sale con las manos libres y lo recuerda.
	reparar.Triggered:Connect(function(jugador)
		if puede(jugador, el) and Defensa.necesitaReparar(estados[el]) then
			Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "Bring a plank to repair it."))
		end
	end)
	publicar(el)
end

-- Ventanas y puertas que el Golpeador puede atacar (las de la planta baja que dan fuera).
function Casa.atacables(): { Model }
	local lista = {}
	for el in estados do
		if el:GetAttribute("Atacable") then
			table.insert(lista, el)
		end
	end
	return lista
end

function Casa.estado(el: Model): Defensa.Estado
	return estados[el]
end

function Casa.empezarAtaque(el: Model)
	estados[el].atacada = true
	estados[el].abiertaEnAtaque = false
end

function Casa.terminarAtaque(el: Model)
	estados[el].atacada = false
end

-- Un golpe del bicho: devuelve lo que ha pasado (ver Defensa.golpe).
function Casa.golpe(el: Model, dano: number): string
	local resultado = Defensa.golpe(estados[el], ahora(), dano, cfg)
	el:SetAttribute("Golpes", (el:GetAttribute("Golpes") or 0) + 1) -- el cliente lo hace temblar
	publicar(el)
	return resultado
end

-- El Raspador va agrietando el cristal mientras raspa (`hecho` de 0 a 1); sin llegar a romperlo.
function Casa.agrietar(el: Model, hecho: number)
	local e = estados[el]
	local nivel = math.min(cfg.GolpesCristal - 1, math.floor(hecho * cfg.GolpesCristal))
	if nivel > e.cristal then
		e.cristal = nivel
		publicar(el)
	end
end

function Casa.romper(el: Model)
	Defensa.romper(estados[el], cfg)
	publicar(el)
end

-- El bicho abre de un golpe una puerta cerrada (sin llave) que le estorba. true si la ha abierto.
function Casa.abrirPuerta(el: Model): boolean
	local e = estados[el]
	if e.tipo ~= "Puerta" or e.abierta or e.bloqueada then
		return false
	end
	e.abierta = true
	e.cambio = ahora()
	el:SetAttribute("Portazo", (el:GetAttribute("Portazo") or 0) + 1)
	publicar(el)
	return true
end

-- Puertas que se pueden abrir (sin llave), para que el bicho las abra a su paso.
function Casa.puertas(): { Model }
	local lista = {}
	for el, e in estados do
		if e.tipo == "Puerta" and not e.bloqueada then
			table.insert(lista, el)
		end
	end
	return lista
end

-- Foto del estado de toda la casa (al amanecer) para volver a él si mueren todos.
function Casa.foto(): { [Model]: Defensa.Estado }
	local foto = {}
	for el, e in estados do
		foto[el] = table.clone(e)
	end
	return foto
end

function Casa.restaurar(foto: { [Model]: Defensa.Estado })
	for el, guardado in foto do
		local e = table.clone(guardado)
		e.atacada = false
		e.abiertaEnAtaque = false
		e.cambio = -math.huge
		estados[el] = e
		publicar(el)
	end
end

-- Clavar un tablón (llevándolo en las manos, R): deja la persiana y el cristal, o la puerta, como nuevos. Se clava por
-- dentro en las ventanas y del lado del jugador en las puertas.
local function prepararClavar(jugador: Player, el: Instance, _pieza: BasePart): (CFrame?, number?)
	local e = estados[el :: Model]
	if not e or e.bloqueada or not puede(jugador, el :: Model) then
		return nil
	end
	if not Defensa.necesitaReparar(e) then
		Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "It doesn't need repairs."))
		return nil
	end
	local inclinado = CFrame.Angles(0, 0, math.rad(9)) * CFrame.Angles(math.pi / 2, 0, 0) -- de canto contra la pared
	if e.tipo == "Ventana" then
		return (el:GetAttribute("Centro") :: CFrame) * CFrame.new(0, 0, 1.3) * inclinado, Config.Talar.Clavar
	end
	local bisagra = el:GetAttribute("Bisagra") :: CFrame
	local raiz = (jugador.Character :: Model):FindFirstChild("HumanoidRootPart") :: BasePart
	local lado = if bisagra:PointToObjectSpace(raiz.Position).Z >= 0 then 1 else -1
	return bisagra * CFrame.new(el:GetAttribute("Ancho") / 2, 4.5, 0.6 * lado) * inclinado, Config.Talar.Clavar
end

function Casa.start()
	Cargar.alUsar("Tablon", {
		etiquetas = { "Ventana", "Puerta" },
		accion = "Clavar",
		preparar = prepararClavar,
		terminar = function(_jugador, el, pieza)
			pieza:Destroy()
			local e = estados[el :: Model]
			Defensa.reparar(e)
			publicar(el :: Model)
		end,
	})
	for _, el in CollectionService:GetTagged("Ventana") do
		preparar(el, "Ventana")
	end
	-- Con las manos ocupadas no salen los prompts: una puerta cerrada se abre de un empujón al ir hacia ella.
	task.spawn(function()
		while true do
			task.wait(0.2)
			for _, jugador in Players:GetPlayers() do
				local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not raiz or not jugador:GetAttribute("Cargando") then
					continue
				end
				for el, e in estados do
					local mando = el:FindFirstChild("Mando") :: BasePart
					local hacia = (mando.Position - raiz.Position) * Vector3.new(1, 0, 1)
					if e.tipo == "Puerta" and not e.abierta and not e.bloqueada and hacia.Magnitude < 4.5
						and hacia.Unit:Dot(raiz.CFrame.LookVector) > 0.5 and Defensa.puerta(e, ahora(), cfg) then
						publicar(el)
					end
				end
			end
		end
	end)
	for _, el in CollectionService:GetTagged("Puerta") do
		preparar(el, "Puerta")
	end
end

return Casa
