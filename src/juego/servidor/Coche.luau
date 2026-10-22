-- Tu coche (el final fácil, el de la huida): destrozado y encerrado en el garaje. Le faltan las piezas de
-- Config.Coche.Piezas y gasolina (cuentas en shared/Recetas).
--   Las pesadas (motor entre dos, ruedas) se montan con R llevándolas (Cargar.alUsar, etiqueta "Coche"); el bidón
--   echa su gasolina igual que en el generador. Las de la mochila (batería y radiador, del banco del garaje) con el
--   prompt "Repair" (E) del capó; sin nada que montar, avisa de lo primero que le falta.
--   El portón del garaje se abre y cierra con E desde que la puerta del garaje está abierta (para meter el motor).
--   Con todo puesto sale "Escape" (mantener E en la puerta del conductor): se van los bichos, la partida se da por
--   terminada (Partida, con alHuir), los clientes ven la escena final (HuidaVista) y todos vuelven al lobby.
--   Se guarda con la partida (exportar/importar): piezas montadas, gasolina y el portón.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Prueba = require(ReplicatedStorage.Shared.Prueba)
local Recetas = require(ReplicatedStorage.Shared.Recetas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Viaje = require(ServerScriptService:WaitForChild("Comun").Viaje)
local Recompensas = require(ServerScriptService:WaitForChild("Comun").Recompensas)
local Cargar = require(script.Parent.Cargar)
local Casa = require(script.Parent.Casa)
local Golpeador = require(script.Parent.Golpeador)
local Mochila = require(script.Parent.Mochila)
local Muerte = require(script.Parent.Muerte)
local Raspador = require(script.Parent.Raspador)

local Coche = {}

local C = Config.Coche
-- Qué piezas del modelo enseña cada una, en orden (las ruedas 1 y 2 ya están; debajo de la 3 y la 4, ladrillos).
local PARTES = { Motor = { "Motor" }, Rueda = { "Rueda3", "Rueda4" }, Bateria = { "Bateria" }, Radiador = { "Radiador" } }
local FALTA = {
	Motor = "The car needs its engine.",
	Rueda = "The car needs a wheel.",
	Bateria = "The car needs a battery.",
	Radiador = "The car needs a radiator.",
	Gasolina = "The car needs fuel.",
}

local coche: Model
local hojaPorton: BasePart
local cerradoPorton: CFrame
local estado: Recetas.Coche = Recetas.nuevoCoche()
local enCurso: { [string]: number } = {} -- piezas que alguien está montando ahora (para no montar dos en un hueco)
local huyendo = false
local alHuir: (() -> ())? = nil
local promptReparar: ProximityPrompt
local promptHuir: ProximityPrompt
local promptPorton: ProximityPrompt

local function cerca(jugador: Player, parte: BasePart): boolean
	local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return raiz ~= nil and table.find(Muerte.vivos(), jugador) ~= nil and not jugador:GetAttribute("Escondido")
		and (parte.Position - raiz.Position).Magnitude <= Config.Casa.Alcance + 4
end

-- ¿Cabe otra de esas ahora mismo (contando las que se están montando)?
local function libre(tipo: string): boolean
	if not Recetas.necesita(estado, tipo, C) then
		return false
	end
	local hacen = 0
	for _, p in C.Piezas do
		if p[1] == tipo then
			hacen = p[2]
		end
	end
	return (estado.piezas[tipo] or 0) + (enCurso[tipo] or 0) < hacen
end

local function publicar()
	for tipo, partes in PARTES do
		local n = estado.piezas[tipo] or 0
		for i, nombre in partes do
			local parte = coche:FindFirstChild(nombre) :: BasePart
			parte.Transparency = if i <= n then 0 else 1
			parte.CanCollide = i <= n
			parte.CanQuery = i <= n
			local ladrillos = coche:FindFirstChild("Ladrillos" .. (i)) :: BasePart?
			if tipo == "Rueda" and ladrillos then
				ladrillos.Transparency = if i <= n then 1 else 0
				ladrillos.CanCollide = i > n
			end
		end
		coche:SetAttribute(tipo, n)
	end
	coche:SetAttribute("Gasolina", estado.gasolina)
	local listo = Recetas.queFalta(estado, C) == nil
	coche:SetAttribute("Listo", listo)
	promptReparar.Enabled = not listo and not huyendo
	promptHuir.Enabled = listo and not huyendo
	promptPorton.ActionText = if estado.porton then "Close" else "Open"
	local destino = if estado.porton then cerradoPorton * CFrame.new(0, 8.6, 0) else cerradoPorton
	if hojaPorton.CFrame ~= destino then
		TweenService:Create(hojaPorton, TweenInfo.new(1.6, Enum.EasingStyle.Quad), { CFrame = destino }):Play()
	end
	hojaPorton.CanCollide = not estado.porton
end

-- Las pesadas (motor, ruedas): con R llevándola, se pone en su hueco y se atornilla.
local function usoPieza(tipo: string): Cargar.Uso
	return {
		etiquetas = { "Coche" },
		accion = "Montar",
		preparar = function(jugador, _objetivo, _pieza)
			if huyendo or not libre(tipo) then
				Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "The car doesn't need that."))
				return nil
			end
			local hueco = (estado.piezas[tipo] or 0) + (enCurso[tipo] or 0) + 1
			enCurso[tipo] = (enCurso[tipo] or 0) + 1
			return (coche:FindFirstChild(PARTES[tipo][hueco]) :: BasePart).CFrame, C.Montar
		end,
		cancelar = function()
			enCurso[tipo] = math.max(0, (enCurso[tipo] or 0) - 1)
		end,
		terminar = function(jugador, _objetivo, pieza)
			enCurso[tipo] = math.max(0, (enCurso[tipo] or 0) - 1)
			pieza:Destroy()
			Recetas.montar(estado, tipo, C)
			publicar()
			Remotes.Aviso:FireClient(jugador, Lang.t(jugador, if Recetas.queFalta(estado, C) then "Installed."
				else "The car is ready. Get in and escape!"))
		end,
	}
end

local function usoBidon(): Cargar.Uso
	local function tapon(): Vector3
		return (coche:GetAttribute("Tapon") :: CFrame).Position
	end
	return {
		etiquetas = { "Coche" },
		accion = "Verter",
		preparar = function(jugador, _objetivo, pieza)
			if huyendo or not Recetas.necesita(estado, "Bidon", C) then
				Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "The tank is full."))
				return nil
			end
			if (pieza:GetAttribute("Carga") or 0) <= 0.01 then
				Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "The can is empty."))
				return nil
			end
			-- Al lado del tapón, inclinado hacia él.
			return CFrame.new(tapon() + Vector3.new(1.7, 1.2, 0)) * CFrame.Angles(0, 0, math.rad(70)), Config.Generador.Verter
		end,
		terminar = function(jugador, _objetivo, pieza)
			local _, cabe = Recetas.montar(estado, "Bidon", C, pieza:GetAttribute("Carga") or 0)
			pieza:SetAttribute("Carga", math.max(0, (pieza:GetAttribute("Carga") or 0) - cabe))
			Cargar.liberar(pieza, CFrame.new(tapon() + Vector3.new(2.2, -1.2, 0)))
			publicar()
			if not Recetas.queFalta(estado, C) then
				Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "The car is ready. Get in and escape!"))
			end
		end,
	}
end

-- E en el capó: monta lo que le haga falta y lleves en la mochila; si no llevas nada, dice lo que le falta.
local function reparar(jugador: Player)
	local mando = coche:FindFirstChild("Mando") :: BasePart
	if huyendo or not cerca(jugador, mando) or jugador:GetAttribute("Trabajando") or jugador:GetAttribute("Cargando") then
		return
	end
	for _, p in C.Piezas do
		local tipo = p[1]
		if Config.Pesados[tipo] or not libre(tipo) or Mochila.contar(jugador, tipo) == 0 then
			continue
		end
		enCurso[tipo] = (enCurso[tipo] or 0) + 1
		local bien = Cargar.trabajar(jugador, "Montar", mando, C.Montar)
		enCurso[tipo] = math.max(0, (enCurso[tipo] or 0) - 1)
		if bien and not huyendo and Recetas.necesita(estado, tipo, C) and Mochila.sacar(jugador, tipo) then
			Recetas.montar(estado, tipo, C)
			publicar()
			Remotes.Aviso:FireClient(jugador, Lang.t(jugador, if Recetas.queFalta(estado, C) then "Installed."
				else "The car is ready. Get in and escape!"))
		end
		return
	end
	local falta = Recetas.queFalta(estado, C)
	if falta then
		Remotes.Aviso:FireClient(jugador, Lang.t(jugador, FALTA[falta]))
	end
end

-- El final de la huida: todos se van en el coche (también los muertos: la escena es de todos).
local function huir(jugador: Player)
	if huyendo or Recetas.queFalta(estado, C) or not cerca(jugador, coche:FindFirstChild("Conducir") :: BasePart) then
		return
	end
	huyendo = true
	publicar()
	Golpeador.quitar()
	Raspador.quitar()
	if alHuir then
		alHuir()
	end
	Recompensas.final(C.Cinematica)
	for _, j in Players:GetPlayers() do
		Cargar.soltar(j)
		local raiz = j.Character and j.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if raiz then
			raiz.Anchored = true -- quietos (y a salvo) mientras dura la escena
		end
	end
	Remotes.Huida:FireAllClients(C.Cinematica)
	task.wait(C.Cinematica + 2)
	Viaje.volver(Players:GetPlayers(), "You escaped.")
	for _, j in Players:GetPlayers() do -- en Studio no hay viaje: se puede seguir mirando
		local raiz = j.Character and j.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if raiz then
			raiz.Anchored = false
		end
	end
end

local function porton(jugador: Player)
	if huyendo or not cerca(jugador, hojaPorton) then
		return
	end
	if table.find(Casa.cerradas(), "LlaveGaraje") then
		Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "It won't budge."))
		return
	end
	estado.porton = not estado.porton
	publicar()
end

-- Partida: qué hacer al huir (dar la partida por terminada y guardarla así).
function Coche.alHuir(fn: () -> ())
	alHuir = fn
end

-- Lo que se guarda (Partida): { piezas, gasolina, porton }.
function Coche.exportar()
	return {
		piezas = table.clone(estado.piezas),
		gasolina = math.round(estado.gasolina * 1e4) / 1e4,
		porton = estado.porton,
	}
end

-- Deja el coche como en `t` (nil = sin arreglar, el de una partida nueva).
function Coche.importar(t)
	estado = Recetas.arreglarCoche(t, C)
	publicar()
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

function Coche.start()
	coche = CollectionService:GetTagged("Coche")[1] :: Model
	local modeloPorton = CollectionService:GetTagged("Porton")[1] :: Model
	hojaPorton = modeloPorton:FindFirstChild("Hoja") :: BasePart
	cerradoPorton = hojaPorton.CFrame
	promptReparar = nuevoPrompt(coche:FindFirstChild("Mando") :: BasePart, "Repair")
	promptReparar.Triggered:Connect(reparar)
	promptHuir = nuevoPrompt(coche:FindFirstChild("Conducir") :: BasePart, "Escape")
	promptHuir.HoldDuration = C.Huir
	promptHuir.Triggered:Connect(huir)
	promptPorton = nuevoPrompt(modeloPorton:FindFirstChild("Mando") :: BasePart, "Open")
	promptPorton.Triggered:Connect(porton)
	for tipo in PARTES do
		if Config.Pesados[tipo] then
			Cargar.alUsar(tipo, usoPieza(tipo))
		end
	end
	Cargar.alUsar("Bidon", usoBidon())
	publicar()
	-- Modo de pruebas: ServerStorage.Prueba:Fire("Arreglar") lo deja listo; ("Huir") huye el primer jugador desde donde esté.
	if not Prueba.activa() then
		return
	end
	task.spawn(function() -- el BindableEvent lo crea Director, que arranca después
		ServerStorage:WaitForChild("Prueba").Event:Connect(function(que: string)
			if que == "Arreglar" then
				for _, p in C.Piezas do
					estado.piezas[p[1]] = p[2]
				end
				estado.gasolina = C.Gasolina
				publicar()
			elseif que == "Huir" and Players:GetPlayers()[1] then
				local j = Players:GetPlayers()[1]
				local raiz = j.Character and j.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if raiz then
					raiz.CFrame = (coche:FindFirstChild("Conducir") :: BasePart).CFrame
				end
				huir(j)
			end
		end)
	end)
end

return Coche
