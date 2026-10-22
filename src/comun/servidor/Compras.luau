-- Compras con Robux (Config.Compras), en los dos lugares. Las cuentas, en Recibos (probadas con Lune).
--   Pases: al entrar se pregunta a Roblox cuáles tiene y se publica "Pase<Ventaja>" = true en el Player (lo leen
--   servidor y cliente con Stats.pase). El aviso de compra del cliente se comprueba con Roblox antes de darlo. Lo de
--   una vez de un pase (Regalo) se da al tenerlo y los datos estar cargados, apuntado en `regalos`.
--   Productos (paquetes de monedas y lo que otro sistema encargue, como Revivir): Roblox llama a ProcessReceipt hasta
--   que se le dice que está entregado. Cada compra se apunta en `compras` (Recibos.apuntar) para no darla dos veces, y
--   solo se le dice "entregada" cuando los datos han quedado guardados con ella dentro.
--   Remote Compra (cliente -> servidor): ("Monedas", n), ("Pase", ventaja) o (encargo, ...) abre la compra. La abre el
--   servidor: así valida antes (revivir solo de noche y a un muerto).
-- Modo de pruebas: con Id = 0 se hace como si se pagara (sin Roblox) y Config.Test.Pases da todos los pases.
-- Sin probar fuera de Studio: los Id de verdad, PromptGamePassPurchaseFinished y ProcessReceipt reales.
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Prueba = require(ReplicatedStorage.Shared.Prueba)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Stats = require(ReplicatedStorage.Shared.Stats)
local Datos = require(script.Parent.Datos)
local Recibos = require(script.Parent.Recibos)

local Compras = {}

local C = Config.Compras
local INTENTOS = 3 -- veces que se pregunta a Roblox si tiene un pase al entrar (la consulta falla a veces)
local COMPROBAR = 6 -- comprobaciones de un pase recién comprado...
local ESPERA = 10 -- ...y segundos entre una y otra (Roblox tarda un poco en darlo por suyo)

type Encargo = {
	producto: { Id: number },
	pedir: (comprador: Player, ...any) -> boolean, -- ¿se puede abrir la compra ahora? (y apuntar qué se compra)
	dar: (comprador: Player) -> boolean, -- lo hace al pagar; false si ya no se puede (se devuelven monedas)
}

local encargos: { [string]: Encargo } = {}
local ultimo: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any

local function avisar(jugador: Player, frase: string, huecos: { [string]: any }?)
	Remotes.Aviso:FireClient(jugador, Lang.t(jugador, frase, huecos))
end

-- Lo de una vez del pase, si lo tiene y los datos están cargados.
local function regalar(jugador: Player, pase)
	if not pase.Regalo or not Stats.pase(jugador, pase.Ventaja) then
		return
	end
	local dado = false
	Datos.editar(jugador, function(datos)
		dado = Recibos.regalo(datos, pase)
	end)
	if dado then
		avisar(jugador, "{pase}: +{monedas} coins", { pase = Lang.t(jugador, pase.Nombre), monedas = pase.Regalo.Monedas or 0 })
		task.spawn(Datos.guardar, jugador)
	end
end

local function darPase(jugador: Player, pase)
	if jugador.Parent then
		jugador:SetAttribute(`Pase{pase.Ventaja}`, true)
		regalar(jugador, pase)
	end
end

-- ¿Tiene ese pase en Roblox? true, false o nil (no se ha podido saber).
local function tiene(jugador: Player, pase): boolean?
	local ok, si = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, jugador.UserId, pase.Id)
	if not ok then
		warn(`[Compras] No se ha podido mirar el pase {pase.Ventaja} de {jugador.Name}: {si}`)
		return nil
	end
	return si == true
end

local function alEntrar(jugador: Player)
	for _, pase in C.Pases do
		if Prueba.activa() and Config.Test.Pases then
			task.spawn(darPase, jugador, pase)
		elseif pase.Id > 0 then
			task.spawn(function()
				-- Si la consulta falla se insiste: quien lo ha pagado no puede quedarse sin él toda la sesión.
				for intento = 1, INTENTOS do
					local si = tiene(jugador, pase)
					if si then
						darPase(jugador, pase)
					end
					if si ~= nil or not jugador.Parent then
						return
					end
					task.wait(intento * 5)
				end
			end)
		end
	end
	-- Los regalos esperan a los datos.
	while jugador.Parent and not jugador:GetAttribute("DatosListos") do
		task.wait(0.5)
	end
	for _, pase in C.Pases do
		regalar(jugador, pase)
	end
end

-- El aviso de compra de un pase lo puede falsear un cliente con trampas: se da solo si Roblox lo confirma.
local function paseComprado(jugador: Player, pase)
	for intento = 1, COMPROBAR do
		if not jugador.Parent or Stats.pase(jugador, pase.Ventaja) then
			return
		end
		if tiene(jugador, pase) then
			darPase(jugador, pase)
			return
		end
		if intento < COMPROBAR then
			task.wait(ESPERA)
		end
	end
end

-- Entrega una compra de producto. `cual` = un paquete de Config.Compras.Monedas o el nombre de un encargo.
-- Devuelve la decisión para Roblox.
local function entregar(jugador: Player, cual: any, id: string): Enum.ProductPurchaseDecision
	local datos = Datos.leer(jugador)
	if not datos then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if datos.compras[id] == nil then
		local monedas, frase = 0, "+{monedas} coins"
		if type(cual) == "table" then
			monedas = cual.Monedas
		elseif not encargos[cual].dar(jugador) then
			monedas, frase = C.Reembolso, "It could not be done. You get {monedas} coins."
		else
			frase = ""
		end
		-- Sin esperas entre mirar `compras` y apuntarla: no se puede dar dos veces.
		Datos.editar(jugador, function(editados)
			Recibos.apuntar(editados, id, os.time(), C.Recordadas, monedas)
		end)
		if frase ~= "" then
			avisar(jugador, frase, { monedas = monedas })
		end
	end
	if Datos.guardar(jugador) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Qué es ese producto de Roblox: un paquete de monedas, el nombre de un encargo o nil.
local function productoDe(id: number): any
	for _, paquete in C.Monedas do
		if paquete.Id > 0 and paquete.Id == id then
			return paquete
		end
	end
	for nombre, encargo in encargos do
		if encargo.producto.Id > 0 and encargo.producto.Id == id then
			return nombre
		end
	end
	return nil
end

local function recibo(r): Enum.ProductPurchaseDecision
	local cual = productoDe(r.ProductId)
	local jugador = Players:GetPlayerByUserId(r.PlayerId)
	if cual == nil or not jugador then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return entregar(jugador, cual, r.PurchaseId)
end

-- Abre la compra de un producto (o, con Id = 0 en el modo de pruebas, la da como pagada).
local function abrirProducto(jugador: Player, cual: any, producto: { Id: number })
	if producto.Id > 0 then
		MarketplaceService:PromptProductPurchase(jugador, producto.Id)
	elseif Prueba.activa() then
		task.spawn(entregar, jugador, cual, `prueba_{HttpService:GenerateGUID(false)}`)
	end
end

local function pedir(jugador: Player, que: unknown, a: unknown)
	if type(que) ~= "string" then
		return
	end
	local ahora = os.clock()
	if ahora - (ultimo[jugador] or -math.huge) < 1 then
		return
	end
	ultimo[jugador] = ahora
	if que == "Monedas" then
		local paquete = type(a) == "number" and C.Monedas[a]
		if paquete then
			abrirProducto(jugador, paquete, paquete)
		end
	elseif que == "Pase" then
		local pase = Stats.paseDe(a)
		if not pase or Stats.pase(jugador, pase.Ventaja) then
			return
		end
		if pase.Id > 0 then
			MarketplaceService:PromptGamePassPurchase(jugador, pase.Id)
		elseif Prueba.activa() then
			darPase(jugador, pase)
		end
	elseif encargos[que] and encargos[que].pedir(jugador, a) then
		abrirProducto(jugador, que, encargos[que].producto)
	end
end

-- Otro sistema se encarga de un producto (Revivir en el juego). Ver el tipo Encargo.
function Compras.encargar(nombre: string, encargo: Encargo)
	encargos[nombre] = encargo
end

function Compras.start()
	MarketplaceService.ProcessReceipt = function(r)
		local ok, decision = pcall(recibo, r)
		if not ok then
			warn(`[Compras] Compra {r.PurchaseId} sin entregar: {decision}`)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		return decision
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(jugador, id, comprado)
		if not comprado or typeof(jugador) ~= "Instance" or not jugador:IsA("Player") then
			return
		end
		for _, pase in C.Pases do
			if pase.Id > 0 and pase.Id == id then
				task.spawn(paseComprado, jugador, pase)
			end
		end
	end)
	Remotes.Compra.OnServerEvent:Connect(pedir)
	Players.PlayerAdded:Connect(alEntrar)
	for _, jugador in Players:GetPlayers() do
		task.spawn(alEntrar, jugador)
	end
end

return Compras
