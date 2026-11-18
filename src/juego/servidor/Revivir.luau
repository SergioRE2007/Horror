-- Revivir de noche pagando con Robux (Config.Compras.Revivir, la compra la lleva Compras): a ti o a otro muerto, una
-- vez por noche cada uno (las cuentas, en Recibos.revivible). El cliente (RevivirUi) pide con el remote Compra
-- ("Revivir", jugador muerto); aquí se valida y se apunta a quién antes de abrir la compra, y al pagar se vuelve a
-- mirar: si ya no se puede (ha amanecido, ha revivido…), Compras le da monedas en su lugar.
-- Mientras la compra está abierta, a quién revive no cambia: pulsar otro botón no hace nada (antes, al pagar la
-- primera se revivía al del último botón). Se libera al pagar, al cerrar la compra sin pagar
-- (PromptProductPurchaseFinished) o pasado ABIERTA s sin noticias de Roblox.
-- Atributo del Player "Revivible" = true mientras se le puede revivir (lo usan los botones).
local MarketplaceService = game:GetService("MarketplaceService")
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
-- comprador -> a quién revive y desde cuándo (os.clock) está la compra abierta.
-- pagada = Roblox ya avisó de que la pagó (falta el recibo).
local pendientes: { [Player]: { objetivo: Player, desde: number, pagada: boolean? } } =
	setmetatable({}, { __mode = "k" }) :: any
local ABIERTA = 120 -- s que se guarda el objetivo si Roblox no avisa de cómo acabó la compra (no debería pasar)

-- En un final (la huida o el incendio), no: el personaje nuevo saldría en mitad de la escena.
local function puede(objetivo: Player): boolean
	return not workspace:GetAttribute("Final") and Recibos.revivible(Ciclo.fase() == "Noche",
		objetivo:GetAttribute("Muerto") == true, revividos, objetivo.UserId, noche)
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
	local abierta = pendientes[comprador]
	-- Si el apuntado ya no se puede revivir (revivió por otro lado, amaneció, se fue), la compra abierta se da por
	-- caducada y se apunta al nuevo. Salvo si ya está pagada: ese recibo es del primero (o monedas si ya no se puede).
	local vale = abierta ~= nil
		and (abierta.pagada or (abierta.objetivo.Parent == Players and puede(abierta.objetivo)))
	if abierta and vale and os.clock() - abierta.desde < ABIERTA then
		-- Ya hay una compra a medias: solo se vuelve a abrir si es para el mismo (así no cambia a quién revive).
		return abierta.objetivo == objetivo
	end
	pendientes[comprador] = { objetivo = objetivo, desde = os.clock() }
	return true
end

local function dar(comprador: Player): boolean
	local abierta = pendientes[comprador]
	pendientes[comprador] = nil
	local objetivo = abierta and abierta.objetivo
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

-- Cómo acabó la compra abierta: sin pagar, se olvida el objetivo; pagada, se guarda hasta que llegue el recibo (dar).
local function alAcabarCompra(userId: number, producto: number, pagada: boolean)
	if Config.Compras.Revivir.Id <= 0 or producto ~= Config.Compras.Revivir.Id then
		return
	end
	local comprador = Players:GetPlayerByUserId(userId)
	local abierta = comprador and pendientes[comprador]
	if not abierta then
		return
	end
	if pagada then
		abierta.desde = os.clock() -- el recibo puede tardar: que no caduque mientras
		abierta.pagada = true
	else
		pendientes[comprador :: Player] = nil
	end
end

function Revivir.start()
	Compras.encargar("Revivir", { producto = Config.Compras.Revivir, pedir = pedir, dar = dar })
	MarketplaceService.PromptProductPurchaseFinished:Connect(alAcabarCompra)
	Ciclo.alCambiar(function(fase)
		if fase == "Noche" then
			noche += 1
		end
		publicar()
	end)
	workspace:GetAttributeChangedSignal("Final"):Connect(publicar) -- los botones de revivir, fuera en el final
	Players.PlayerAdded:Connect(alEntrar)
	for _, jugador in Players:GetPlayers() do
		alEntrar(jugador)
	end
end

return Revivir
