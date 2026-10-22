-- El vendedor del pueblo (pedido por el usuario): el único que queda. Trueque: pide comida y agua (latas y botellas) a
-- cambio de sus cosas (Config.Vendedor.Trueques) y avisa ("no salgas de noche"). Prompt "Trade" (E): el servidor le
-- manda al cliente ("Abrir", frase) y VendedorUi enseña los tratos; el cliente pide ("Cambiar", número) y aquí se
-- valida todo: vivo, cerca y con lo que pide en la mochila. Lo que no le cabe cae a sus pies.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Mochila = require(script.Parent.Mochila)
local Muerte = require(script.Parent.Muerte)

local Vendedor = {}

local V = Config.Vendedor
local frase = 0

local function cerca(jugador: Player): boolean
	local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not raiz or not table.find(Muerte.vivos(), jugador) or jugador:GetAttribute("Escondido") then
		return false
	end
	for _, modelo in CollectionService:GetTagged("Vendedor") do
		local mando = modelo:FindFirstChild("Mando") :: BasePart?
		if mando and (mando.Position - raiz.Position).Magnitude <= V.Alcance then
			return true
		end
	end
	return false
end

local function cambiar(jugador: Player, i: unknown)
	local trato = type(i) == "number" and V.Trueques[i]
	if not trato or not cerca(jugador) then
		return
	end
	local pide, cuantos = trato.Pide[1], trato.Pide[2]
	if Mochila.contar(jugador, pide) < cuantos then
		Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "You don't have enough."))
		return
	end
	for _ = 1, cuantos do
		Mochila.sacar(jugador, pide)
	end
	for _ = 1, trato.Da[2] do
		Mochila.dar(jugador, trato.Da[1])
	end
	Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "Deal."))
end

local function preparar(modelo: Model)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.ActionText = "Trade"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.MaxActivationDistance = Config.Casa.Alcance
	prompt.RequiresLineOfSight = false
	prompt.Parent = modelo:WaitForChild("Mando")
	prompt.Triggered:Connect(function(jugador)
		if cerca(jugador) then
			frase = frase % #V.Frases + 1 -- cada vez dice otra
			Remotes.Vendedor:FireClient(jugador, "Abrir", Lang.t(jugador, V.Frases[frase]))
		end
	end)
end

function Vendedor.start()
	for _, modelo in CollectionService:GetTagged("Vendedor") do
		preparar(modelo)
	end
	Remotes.Vendedor.OnServerEvent:Connect(function(jugador, que, i)
		if que == "Cambiar" then
			cambiar(jugador, i)
		end
	end)
end

return Vendedor
