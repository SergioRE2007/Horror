-- Revivir de noche pagando con Robux (Config.Compras.Revivir, la compra la lleva Compras): a ti o a otro muerto, una
-- vez por noche cada uno (las cuentas, en Recibos.revivible). El cliente (RevivirUi) pide con el remote Compra
-- ("Revivir", jugador muerto); aquí se valida y se apunta a quién antes de abrir la compra, y al pagar se vuelve a
-- mirar: si ya no se puede (ha amanecido, ha revivido…), Compras le da monedas en su lugar.
-- Atributo del Player "Revivible" = true mientras se le puede revivir (lo usan los botones).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Comun = ServerScriptService:WaitForChild("Comun")
local Compras = require(Comun.Compras)
local Recibos = require(Comun.Recibos)
local Ciclo = require(script.Parent.Ciclo)
local Muerte = require(script.Parent.Muerte)

local Revivir = {}

local revividos: { [number]: number } = {} -- [UserId] = la noche en que revivió pagando
local noche = 0 -- noches de este servidor: sube con cada una, también si se repite al morir todos
local pendientes: { [Player]: Player } = setmetatable({}, { __mode = "k" }) :: any -- comprador -> a quién revive

local function puede(objetivo: Player): boolean
	return Recibos.revivible(Ciclo.fase() == "Noche", objetivo:GetAttribute("Muerto") == true, revividos,
		objetivo.UserId, noche)
end

local function publicar()
	for _, jugador in Players:GetPlayers() do
		jugador:SetAttribute("Revivible", if puede(jugador) then true else nil)
	end
end

local function pedir(comprador: Player, objetivo: unknown): boolean
	if typeof(objetivo) ~= "Instance" or not objetivo:IsA("Player") or objetivo.Parent ~= Players or not puede(objetivo) then
		return false
	end
	pendientes[comprador] = objetivo
	return true
end

local function dar(comprador: Player): boolean
	local objetivo = pendientes[comprador]
	pendientes[comprador] = nil
	if not objetivo or objetivo.Parent ~= Players or not puede(objetivo) then
		return false
	end
	revividos[objetivo.UserId] = noche
	Muerte.revivir(objetivo)
	publicar()
	if objetivo == comprador then
		Remotes.Aviso:FireClient(objetivo, Lang.t(objetivo, "You are back."))
	else
		Remotes.Aviso:FireClient(objetivo, Lang.t(objetivo, "{nombre} brought you back.", { nombre = comprador.DisplayName }))
		Remotes.Aviso:FireClient(comprador, Lang.t(comprador, "{nombre} is back.", { nombre = objetivo.DisplayName }))
	end
	return true
end

local function alEntrar(jugador: Player)
	jugador:GetAttributeChangedSignal("Muerto"):Connect(publicar)
end

function Revivir.start()
	Compras.encargar("Revivir", { producto = Config.Compras.Revivir, pedir = pedir, dar = dar })
	Ciclo.alCambiar(function(fase)
		if fase == "Noche" then
			noche += 1
		end
		publicar()
	end)
	Players.PlayerAdded:Connect(alEntrar)
	for _, jugador in Players:GetPlayers() do
		alEntrar(jugador)
	end
end

return Revivir
