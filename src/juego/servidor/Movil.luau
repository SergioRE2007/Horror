-- Móvil (pedido por el usuario): mapa con dónde estáis tú y tus amigos. El cliente (MovilUi) lo pinta; aquí se gasta
-- la batería mientras se mira. La batería va en la `carga` del móvil de la mochila (viaja con él si se tira o se deja
-- en el enchufe: ver Generador). Atributos del jugador: MovilAbierto y Bateria (Mochila; nil = no lleva móvil).
-- Se puede mirar escondido, pero no con las manos ocupadas. Atributo Donde de cada jugador (Vector2 x, z) para el mapa.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Mochila = require(script.Parent.Mochila)
local Muerte = require(script.Parent.Muerte)

local Movil = {}

local function cerrar(jugador: Player, aviso: string?)
	jugador:SetAttribute("MovilAbierto", nil)
	if aviso then
		Remotes.Aviso:FireClient(jugador, Lang.t(jugador, aviso))
	end
end

local function pedir(jugador: Player, abierto: unknown)
	if abierto ~= true then
		cerrar(jugador)
		return
	end
	local movil = Mochila.primera(jugador, "Movil")
	if not table.find(Muerte.vivos(), jugador) or jugador:GetAttribute("MochilaAbierta") then
		return
	elseif jugador:GetAttribute("Cargando") or jugador:GetAttribute("Trabajando") then
		Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "Your hands are full."))
	elseif not movil then
		Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "You don't have a phone."))
	elseif (movil.carga or 0) <= 0 then
		Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "Your phone is dead."))
	else
		jugador:SetAttribute("MovilAbierto", true)
	end
end

local cuenta = 0
local function gastar(dt: number)
	cuenta += dt
	local publicar = cuenta >= 0.5
	if publicar then
		cuenta = 0
	end
	for _, jugador in Players:GetPlayers() do
		-- Dónde está cada uno para el mapa: de lejos su personaje puede no llegar al cliente (StreamingEnabled).
		local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if publicar and raiz then
			jugador:SetAttribute("Donde", Vector2.new(raiz.Position.X, raiz.Position.Z))
		end
		if not jugador:GetAttribute("MovilAbierto") then
			continue
		end
		local movil = Mochila.primera(jugador, "Movil")
		if not movil or not table.find(Muerte.vivos(), jugador) or jugador:GetAttribute("Cargando")
			or jugador:GetAttribute("Trabajando") or jugador:GetAttribute("MochilaAbierta") then
			cerrar(jugador)
			continue
		end
		movil.carga = math.max(0, (movil.carga or 0) - dt / Config.Movil.Duracion)
		if movil.carga <= 0 then
			jugador:SetAttribute("Bateria", 0)
			cerrar(jugador, "Your phone is dead.")
		elseif publicar then
			jugador:SetAttribute("Bateria", movil.carga)
		end
	end
end

function Movil.start()
	Remotes.Movil.OnServerEvent:Connect(pedir)
	RunService.Heartbeat:Connect(gastar)
end

return Movil
