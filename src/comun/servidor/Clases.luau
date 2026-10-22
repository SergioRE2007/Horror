-- Clases (Leñador, Corredor…): una por jugador y partida. La elegida se guarda en sus datos (`clase`) y llega al
-- juego con ellos (DataStore con candado), nunca con los datos del teletransporte, que pasan por el cliente. Al
-- cargar, el servidor comprueba que la tiene y la publica en el atributo "Clase" del Player; las ventajas, en
-- shared/Stats. Solo en el lobby se puede cambiar (remote Clase); comprarlas, en Tienda.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Prueba = require(ReplicatedStorage.Shared.Prueba)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Stats = require(ReplicatedStorage.Shared.Stats)
local Datos = require(script.Parent.Datos)

local Clases = {}

local ultimo: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any

-- "" = sin clase. Una que no existe o no tiene comprada no vale.
local function vale(datos, id: string): boolean
	return id == "" or (Stats.clase(id) ~= nil and datos.clases[id] == true)
end

-- Pone el atributo "Clase" con la que tiene elegida (también lo llama Tienda al comprar una).
function Clases.publicar(jugador: Player)
	local datos = Datos.leer(jugador)
	if not datos then
		return
	end
	local id = datos.clase
	if Prueba.activa() and Config.Test.Clase then
		id = Config.Test.Clase -- en Studio, cualquiera aunque no esté comprada
	elseif not vale(datos, id) then
		id = ""
	end
	jugador:SetAttribute("Clase", if id ~= "" then id else nil)
end

local function alEntrar(jugador: Player)
	while jugador.Parent and not jugador:GetAttribute("DatosListos") do
		task.wait(0.5)
	end
	Clases.publicar(jugador)
end

-- Elegir una clase que ya tiene (solo en el lobby).
local function elegir(jugador: Player, id: unknown)
	if type(id) ~= "string" or #id > 32 then
		return
	end
	local ahora = os.clock()
	if ahora - (ultimo[jugador] or -math.huge) < 0.3 then
		return
	end
	ultimo[jugador] = ahora
	Datos.editar(jugador, function(datos)
		if vale(datos, id) then
			datos.clase = id
		end
	end)
	Clases.publicar(jugador)
end

-- `lobby`: true en el lobby, donde se puede elegir.
function Clases.start(lobby: boolean)
	Players.PlayerAdded:Connect(alEntrar)
	for _, jugador in Players:GetPlayers() do
		task.spawn(alEntrar, jugador)
	end
	if lobby then
		Remotes.Clase.OnServerEvent:Connect(elegir)
	end
end

return Clases
