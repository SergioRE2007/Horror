-- Enseña los avisos de una línea que manda el servidor (remote Aviso), ya en el idioma del jugador.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Ui)

local Avisos = {}

function Avisos.start()
	Remotes.Aviso.OnClientEvent:Connect(function(texto: string)
		Ui.aviso(texto)
	end)
end

return Avisos
