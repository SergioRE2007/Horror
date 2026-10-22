-- Tienda de clases y cosméticos, en la gasolinera del lobby (las cuentas, en Comprar). El cliente solo pide por el
-- remote Tienda: ("Clase", id) o ("Cosmetico", id) para comprar, ("Poner", tipo, id) para ponerse uno suyo ("" = el
-- de serie). El servidor mira precio y monedas en los datos del jugador y guarda enseguida.
-- En los dos lugares publica lo que lleva puesto de cada tipo en el atributo "Puesto<Tipo>" del Player (p. ej.
-- "PuestoLinterna" = Id), solo si es suyo; el cliente lo pinta (la luz de la linterna, en EquipoVista).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Clases = require(script.Parent.Clases)
local Comprar = require(script.Parent.Comprar)
local Datos = require(script.Parent.Datos)

local Tienda = {}

local ultimo: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any

local TIPOS = {}
for _, cosa in Config.Cosmeticos do
	TIPOS[cosa.Tipo] = true
end

local function publicar(jugador: Player)
	local datos = Datos.leer(jugador)
	if not datos then
		return
	end
	for tipo in TIPOS do
		local cosa = Comprar.puesto(datos, Config.Cosmeticos, tipo)
		jugador:SetAttribute(`Puesto{tipo}`, if cosa then cosa.Id else nil)
	end
end

local function alEntrar(jugador: Player)
	while jugador.Parent and not jugador:GetAttribute("DatosListos") do
		task.wait(0.5)
	end
	publicar(jugador)
end

local function avisar(jugador: Player, frase: string)
	Remotes.Aviso:FireClient(jugador, Lang.t(jugador, frase))
end

local function pedir(jugador: Player, accion: unknown, a: unknown, b: unknown)
	if type(accion) ~= "string" or (a ~= nil and type(a) ~= "string") or (b ~= nil and type(b) ~= "string") then
		return
	end
	local ahora = os.clock()
	if ahora - (ultimo[jugador] or -math.huge) < 0.3 then
		return
	end
	ultimo[jugador] = ahora
	local r = "nada"
	Datos.editar(jugador, function(datos)
		if accion == "Clase" then
			r = Comprar.clase(datos, Config.Clases, a)
		elseif accion == "Cosmetico" then
			r = Comprar.cosmetico(datos, Config.Cosmeticos, a)
		elseif accion == "Poner" then
			r = if Comprar.poner(datos, Config.Cosmeticos, a, b) then "puesto" else "nada"
		end
	end)
	if r == "ok" or r == "puesto" then
		Clases.publicar(jugador)
		publicar(jugador)
		task.spawn(Datos.guardar, jugador)
		if r == "ok" then
			avisar(jugador, "Bought.")
		end
	elseif r == "monedas" then
		avisar(jugador, "Not enough coins.")
	end
end

-- `lobby`: true en el lobby, donde está la tienda.
function Tienda.start(lobby: boolean)
	Players.PlayerAdded:Connect(alEntrar)
	for _, jugador in Players:GetPlayers() do
		task.spawn(alEntrar, jugador)
	end
	if lobby then
		Remotes.Tienda.OnServerEvent:Connect(pedir)
	end
end

return Tienda
