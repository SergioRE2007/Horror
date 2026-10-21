-- ¿Está activo el modo de pruebas? Solo en Studio y con Config.Test.Activo. Vale en servidor y cliente.
local Config = require(script.Parent.Config)

local Prueba = {}

local enStudio = false
pcall(function()
	enStudio = game:GetService("RunService"):IsStudio()
end)

function Prueba.activa(): boolean
	return enStudio and Config.Test.Activo == true
end

return Prueba
