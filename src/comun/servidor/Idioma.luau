-- Idioma de cada jugador para los textos que escribe el servidor: su cliente dice cuál tiene elegido para esta
-- experiencia (remote Idioma, comun/cliente/Idioma) y aquí se apunta en su atributo "Lang", que es lo primero que
-- mira Lang.codigo. Solo valen "es" y "en".
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Idioma = {}

local ultimo: { [Player]: number } = {}
local pendiente: { [Player]: string } = {}

-- Como mucho un cambio por segundo (cada cambio del atributo llega a todos los clientes). Lo que llega antes no se
-- pierde: se pone el último pedido al pasar el segundo (al entrar, el cliente puede mandar dos seguidos).
local function poner(jugador: Player)
	local codigo = pendiente[jugador]
	if not codigo or not jugador.Parent then
		return
	end
	local espera = 1 - (os.clock() - (ultimo[jugador] or -math.huge))
	if espera > 0 then
		task.delay(espera, poner, jugador)
		return
	end
	pendiente[jugador] = nil
	ultimo[jugador] = os.clock()
	jugador:SetAttribute("Lang", codigo)
end

function Idioma.start()
	Remotes.Idioma.OnServerEvent:Connect(function(jugador: Player, codigo: unknown)
		if codigo ~= "es" and codigo ~= "en" then
			return
		end
		local habia = pendiente[jugador]
		pendiente[jugador] = codigo :: string
		if not habia then
			poner(jugador)
		end
	end)
	Players.PlayerRemoving:Connect(function(jugador)
		ultimo[jugador], pendiente[jugador] = nil, nil
	end)
end

return Idioma
