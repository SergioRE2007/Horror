-- La pistola de bengalas del rico (12.2, pedido por el usuario). El cliente solo pide el disparo (BengalasVista); aquí
-- se mira que puede, se gasta la bengala y se tira el rayo.
--   Remote `Bengala`:
--     cliente -> servidor: (origen, hacia) la cámara y hacia dónde mira (unitario). El rayo sale de la cabeza del
--       jugador según el servidor; el origen solo se usa para descartar peticiones raras (lejos de la cabeza).
--     servidor -> todos: (quien, origen, impacto, normal?, acierto) para pintar la bengala. normal = nil si no dio a
--       nada (se apaga en el aire); acierto = "Bestia", "Bicho" o nil.
-- Hace falta `Pistola` y al menos una `Bengala` en la mochila; cada disparo gasta una (Mochila.gastar).
-- A la Bestia la hiere (cojea Config.Bestia.Cojea s). A cualquier otro bicho le hace lo mismo que el flash: alFlash si
-- lo tiene (el Raspador huye) o se queda aturdido Config.Flash.Aturde s. Sin Bestia se dispara igual.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Bestia = require(script.Parent.Bestia)
local Caza = require(script.Parent.Caza)
local Mochila = require(script.Parent.Mochila)
local Muerte = require(script.Parent.Muerte)

local Bengalas = {}

local B = Config.Bestia
local CERCA_CABEZA = Config.Bestia.CercaCabeza

local ultimo: { [Player]: number } = {}
local filtroMundo = RaycastParams.new()
filtroMundo.FilterType = Enum.RaycastFilterType.Exclude
filtroMundo.RespectCanCollide = true -- sin chocar con zonas invisibles ni prompts

local function cabezaDe(jugador: Player): BasePart?
	local personaje = jugador.Character
	return personaje and personaje:FindFirstChild("Head") :: BasePart?
end

local function valido(v: unknown): boolean
	return typeof(v) == "Vector3" and v.X == v.X and v.Y == v.Y and v.Z == v.Z
		and math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6 and math.abs(v.Z) < 1e6
end

-- El bicho de Caza al que pertenece una pieza (nil si no es de ninguno).
local function bichoDe(pieza: Instance): Caza.Bicho?
	for _, b in Caza.todos() do
		if b.modelo and pieza:IsDescendantOf(b.modelo) then
			return b
		end
	end
	return nil
end

-- Dónde corta el segmento desde -> desde + vector la caja que envuelve al modelo: (t de 0 a 1, normal) o nil.
local function contraCaja(desde: Vector3, vector: Vector3, modelo: Model): (number?, Vector3?)
	local cf, tam = modelo:GetBoundingBox()
	local o, d = cf:PointToObjectSpace(desde), cf:VectorToObjectSpace(vector)
	local medio = tam / 2
	local entra, sale, eje, signo = 0, 1, nil, 0
	for _, k in { "X", "Y", "Z" } do
		local oi, di, mi = (o :: any)[k], (d :: any)[k], (medio :: any)[k]
		if math.abs(di) < 1e-9 then
			if oi < -mi or oi > mi then
				return nil
			end
		else
			local t1, t2 = (-mi - oi) / di, (mi - oi) / di
			local lado = -1 -- entra por la cara de -mi
			if t1 > t2 then
				t1, t2, lado = t2, t1, 1
			end
			if t1 > entra then
				entra, eje, signo = t1, k, lado
			end
			sale = math.min(sale, t2)
			if entra > sale then
				return nil
			end
		end
	end
	local normal = if eje == "X" then Vector3.xAxis elseif eje == "Y" then Vector3.yAxis elseif eje == "Z" then Vector3.zAxis else -d.Unit
	return entra, cf:VectorToWorldSpace(normal * (if eje then signo else 1))
end

-- Tira el rayo: lo primero que choca del mundo, o un bicho si está antes.
local function rayo(desde: Vector3, hacia: Vector3): (Vector3, Vector3?, Instance?)
	local vector = hacia * B.Alcance
	local ignorar = {}
	for _, otro in Players:GetPlayers() do
		if otro.Character then
			table.insert(ignorar, otro.Character)
		end
	end
	table.insert(ignorar, Caza.carpeta())
	local bestia = Bestia.modelo()
	if bestia then
		table.insert(ignorar, bestia)
	end
	filtroMundo.FilterDescendantsInstances = ignorar
	local mundo = workspace:Raycast(desde, vector, filtroMundo)

	-- Los miembros de los bichos no se pueden mirar con rayos (CanQuery = false en Cuerpo: solo quedaba la raíz, de
	-- 3 × 3 × 1,5, y una bengala a la cabeza o al lomo de la Bestia la atravesaba). Se mira la caja que los envuelve.
	local modelos: { Model } = {}
	for _, b in Caza.todos() do
		if b.modelo and b.modelo.Parent then
			table.insert(modelos, b.modelo)
		end
	end
	if bestia and not table.find(modelos, bestia) then
		table.insert(modelos, bestia)
	end
	local mejor, normalBicho, cual = math.huge, nil, nil
	for _, modelo in modelos do
		local t, n = contraCaja(desde, vector, modelo)
		if t and t < mejor then
			mejor, normalBicho, cual = t, n, modelo
		end
	end
	if cual and (not mundo or mejor * vector.Magnitude <= mundo.Distance) then
		return desde + vector * mejor, normalBicho, cual.PrimaryPart or cual
	elseif mundo then
		return mundo.Position, mundo.Normal, nil
	end
	return desde + vector, nil, nil
end

local function disparar(jugador: Player, origen: unknown, hacia: unknown)
	if not valido(origen) or not valido(hacia) then
		return
	end
	local o, h = origen :: Vector3, hacia :: Vector3
	if math.abs(h.Magnitude - 1) > 0.05 then
		return
	end
	local cabeza = cabezaDe(jugador)
	if not cabeza or (o - cabeza.Position).Magnitude > CERCA_CABEZA then
		return
	end
	if table.find(Muerte.vivos(), jugador) == nil or jugador:GetAttribute("Escondido") then
		return
	end
	local ahora = os.clock()
	if ahora - (ultimo[jugador] or -math.huge) < B.Recarga or not Mochila.primera(jugador, "Pistola") then
		return
	end
	ultimo[jugador] = ahora -- también los intentos fallidos: los avisos no se pueden pedir en ráfaga
	if jugador:GetAttribute("Cargando") or jugador:GetAttribute("MochilaAbierta") or jugador:GetAttribute("Trabajando") then
		Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "Your hands are full."))
		return
	end
	if not Mochila.gastar(jugador, "Bengala") then
		Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "No flares left."))
		return
	end

	local desde = cabeza.Position
	local impacto, normal, pieza = rayo(desde, h.Unit)
	local acierto: string? = nil
	local bestia = Bestia.modelo()
	if pieza and bestia and pieza:IsDescendantOf(bestia) then
		acierto = "Bestia"
		Bestia.herir(B.Cojea)
	elseif pieza then
		local b = bichoDe(pieza)
		if b then
			acierto = "Bicho"
			if b.alFlash then
				b.alFlash(jugador)
			else
				b:aturdir(Config.Flash.Aturde)
			end
		end
	end
	Remotes.Bengala:FireAllClients(jugador, desde, impacto, normal, acierto)
end

function Bengalas.start()
	Players.PlayerRemoving:Connect(function(jugador)
		ultimo[jugador] = nil
	end)
	Remotes.Bengala.OnServerEvent:Connect(disparar)
end

return Bengalas
