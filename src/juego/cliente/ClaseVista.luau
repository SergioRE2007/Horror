-- Lo que se ve de las ventajas de tu clase (shared/Stats). De momento, el Explorador: las llaves sueltas a menos de
-- VerLlaves studs se marcan a través de las paredes, solo para él.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Stats = require(ReplicatedStorage.Shared.Stats)

local ClaseVista = {}

local yo = Players.LocalPlayer
local marcas: { [BasePart]: Highlight } = {}

local function quitar(pieza: BasePart)
	local marca = marcas[pieza]
	if marca then
		marca:Destroy()
		marcas[pieza] = nil
	end
end

local function revisar()
	local alcance = Stats.valor(yo, "VerLlaves")
	local raiz = yo.Character and yo.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	for pieza in marcas do
		if not pieza.Parent or not raiz or (pieza.Position - raiz.Position).Magnitude > alcance then
			quitar(pieza)
		end
	end
	if alcance <= 0 or not raiz then
		return
	end
	for _, pieza in CollectionService:GetTagged("Objeto") do
		local datos = Config.Objetos[pieza:GetAttribute("Tipo")]
		if datos and datos.Llave and pieza:IsA("BasePart") and not marcas[pieza]
			and (pieza.Position - raiz.Position).Magnitude <= alcance then
			local marca = Instance.new("Highlight")
			marca.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			marca.FillColor = Color3.fromRGB(255, 205, 120)
			marca.FillTransparency = 0.75
			marca.OutlineColor = Color3.fromRGB(255, 220, 160)
			marca.OutlineTransparency = 0.3
			marca.Adornee = pieza
			marca.Parent = pieza
			marcas[pieza] = marca
		end
	end
end

function ClaseVista.start()
	task.spawn(function()
		while true do
			task.wait(0.5)
			revisar()
		end
	end)
end

return ClaseVista
