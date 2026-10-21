-- El mundo lo genera el código: al arrancar se borra todo lo suelto del Workspace que no sea del código (en el primer
-- juego una placa sin anclar llegó a tapar el cielo). Lo generado va dentro de workspace.Mapa, que crea esto vacía.
local Players = game:GetService("Players")

local Limpieza = {}

function Limpieza.start()
	for _, cosa in workspace:GetChildren() do
		local esPersonaje = cosa:IsA("Model") and Players:GetPlayerFromCharacter(cosa) ~= nil
		if not (cosa:IsA("Terrain") or cosa:IsA("Camera") or esPersonaje) then
			cosa:Destroy()
		end
	end
	local mapa = Instance.new("Folder")
	mapa.Name = "Mapa"
	mapa.Parent = workspace
end

return Limpieza
