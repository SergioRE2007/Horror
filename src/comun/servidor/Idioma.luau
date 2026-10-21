-- Idioma de cada jugador para los textos que escribe el servidor: su cliente dice cuál tiene elegido para esta
-- experiencia (remote Idioma, comun/cliente/Idioma) y aquí se apunta en su atributo "Lang", que es lo primero que
-- mira Lang.codigo. Solo valen "es" y "en".
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Idioma = {}

function Idioma.start()
	Remotes.Idioma.OnServerEvent:Connect(function(jugador: Player, codigo: unknown)
		if codigo == "es" or codigo == "en" then
			jugador:SetAttribute("Lang", codigo)
		end
	end)
end

return Idioma
