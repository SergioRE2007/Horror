-- El mundo lo genera el código: al arrancar se borra todo lo suelto del Workspace que no sea del código (en el primer
-- juego una placa sin anclar llegó a tapar el cielo). Lo generado va dentro de workspace.Mapa.
-- Mientras no exista el sistema Mapa, deja un suelo gris provisional con su punto de aparición.
local Players = game:GetService("Players")

local Limpieza = {}

local function suelo(mapa: Folder)
	local base = Instance.new("Part")
	base.Name = "SueloProvisional"
	base.Anchored = true
	base.Size = Vector3.new(256, 2, 256)
	base.Position = Vector3.new(0, -1, 0)
	base.Color = Color3.fromRGB(90, 90, 90)
	base.Material = Enum.Material.Concrete
	base.Parent = mapa

	local aparicion = Instance.new("SpawnLocation")
	aparicion.Anchored = true
	aparicion.Size = Vector3.new(6, 1, 6)
	aparicion.Position = Vector3.new(0, 0.5, 0)
	aparicion.Color = base.Color
	aparicion.Material = base.Material
	aparicion.Neutral = true
	aparicion.Duration = 0
	aparicion.Parent = mapa
end

function Limpieza.start()
	for _, cosa in workspace:GetChildren() do
		local esPersonaje = cosa:IsA("Model") and Players:GetPlayerFromCharacter(cosa) ~= nil
		if not (cosa:IsA("Terrain") or cosa:IsA("Camera") or esPersonaje) then
			cosa:Destroy()
		end
	end
	local mapa = Instance.new("Folder")
	mapa.Name = "Mapa"
	suelo(mapa)
	mapa.Parent = workspace
end

return Limpieza
