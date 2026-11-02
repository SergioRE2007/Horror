-- Ajustes del jugador que se guardan entre partidas (14.4). Por ahora solo Rendimiento: menos partículas y sin
-- adornos animados; lo leen los módulos de efectos del cliente con jugador:GetAttribute("Rendimiento").
-- Vale en los dos lugares. Se guarda en los datos del jugador (campo `rendimiento` de Formato) y se publica en el
-- atributo "Rendimiento" del Player al cargar. El cliente lo cambia con el remote Ajustes ("Rendimiento", activo):
-- solo un booleano, como mucho uno cada MINIMO segundos. Detalle en docs/sistemas/ajustes.md.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Datos = require(script.Parent.Datos)

local Ajustes = {}

local MINIMO = 0.25 -- segundos entre dos cambios del mismo jugador (a ojo: pulsar rápido no satura nada)

local ultimo: { [Player]: number } = setmetatable({}, { __mode = "k" }) :: any

local function publicar(jugador: Player)
	local datos = Datos.leer(jugador)
	if datos then
		jugador:SetAttribute("Rendimiento", datos.rendimiento == true)
	end
end

local function alEntrar(jugador: Player)
	while jugador.Parent and not jugador:GetAttribute("DatosListos") do
		task.wait(0.5)
	end
	publicar(jugador)
end

local function cambiar(jugador: Player, que: unknown, valor: unknown)
	if que ~= "Rendimiento" or type(valor) ~= "boolean" then
		return
	end
	local ahora = os.clock()
	if ahora - (ultimo[jugador] or -math.huge) < MINIMO then
		return -- el cliente solo enseña el atributo: si se pierde una pulsación, el botón sigue diciendo la verdad
	end
	ultimo[jugador] = ahora
	Datos.editar(jugador, function(datos)
		datos.rendimiento = valor
	end)
	publicar(jugador) -- se guarda con el siguiente guardado normal (o al salir)
end

function Ajustes.start()
	Players.PlayerAdded:Connect(alEntrar)
	for _, jugador in Players:GetPlayers() do
		task.spawn(alEntrar, jugador)
	end
	Remotes.Ajustes.OnServerEvent:Connect(cambiar)
end

return Ajustes
