-- Para mirar y retocar en Studio las poses de las manos (Manos, ManosGestos) sin tener que provocar cada cosa. Solo
-- en Studio. Desde la barra de comandos con el datamodel Client:
--   game.Players.LocalPlayer.PlayerScripts:FindFirstChild("ManosPrueba", true).Lanzar:Fire("Cortina")
-- Gestos: "Cortina" (la ventana más cerca), "Puerta" (la más cerca), "Foto", "Sobresalto", "Susto", "Pila" y "Carrete"
-- (cambiar la pila o el carrete: se hace como si el servidor lo dijera, solo en local), "Linterna" (enciende o apaga
-- la de la mano, solo en local) y "Movil".
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local ManosGestos = require(script.Parent.ManosGestos)

local ManosPrueba = {}

local jugador = Players.LocalPlayer

-- El ProximityPrompt principal del elemento con esa etiqueta más cerca de la cámara.
local function promptCerca(etiqueta: string): ProximityPrompt?
	local camara = workspace.CurrentCamera
	local mejor, distancia = nil, math.huge
	for _, el in CollectionService:GetTagged(etiqueta) do
		local mando = el:FindFirstChild("Mando")
		local prompt = mando and mando:FindFirstChildOfClass("ProximityPrompt")
		if prompt and mando:IsA("BasePart") then
			local d = (mando.Position - camara.CFrame.Position).Magnitude
			if d < distancia then
				mejor, distancia = prompt, d
			end
		end
	end
	return mejor
end

-- Como si lo hubiera cambiado el servidor un rato (solo en este cliente).
local function atributo(nombre: string, valor: any, segundos: number?)
	jugador:SetAttribute(nombre, valor)
	if segundos then
		task.delay(segundos, function()
			if jugador:GetAttribute(nombre) == valor then
				jugador:SetAttribute(nombre, nil)
			end
		end)
	end
end

local function lanzar(que: string)
	if que == "Cortina" or que == "Puerta" then
		local prompt = promptCerca(if que == "Cortina" then "Ventana" else "Puerta")
		if prompt then
			-- El mismo camino que al pulsarlo (sin pedírselo al servidor: no se abre de verdad).
			ManosGestos.probar(prompt)
		end
	elseif que == "Foto" then
		ManosGestos.foto()
	elseif que == "Sobresalto" then
		ManosGestos.sobresalto(1)
	elseif que == "Susto" then
		ManosGestos.probarSusto()
	elseif que == "Pila" then
		atributo("Cambiando", "Pila", Config.Linterna.Cambiar)
	elseif que == "Carrete" then
		atributo("Cambiando", "Carrete", Config.Flash.Cambiar)
	elseif que == "Linterna" then
		atributo("Linterna", not jugador:GetAttribute("Linterna"))
	elseif que == "Movil" then
		atributo("MovilAbierto", not jugador:GetAttribute("MovilAbierto"))
	end
end

function ManosPrueba.start()
	if not RunService:IsStudio() then
		return
	end
	local orden = Instance.new("BindableEvent")
	orden.Name = "Lanzar"
	orden.Event:Connect(lanzar)
	orden.Parent = script
end

return ManosPrueba
