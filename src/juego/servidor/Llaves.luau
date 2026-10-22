-- Llaves de las salas cerradas (pedido por el usuario): sótano, garaje, desván y habitación del rico (Config.Llaves).
-- Cada llave sale, con la semilla de la partida, en uno de los sitios de su zona (Mapa.llaves, los pone Lugares), con
-- un brillo flojo (Mochila.dejar). Con ella en la mochila, la puerta de su sala se abre y la llave se gasta (Casa).
-- Si mueres con una llave, se cae donde mueres.
-- Se guarda todo con la partida (Partida): la sala abierta (Casa, "bloqueada") y la llave, suelta o en una mochila.
-- Partida llama a repasar al empezar, al cargar y al amanecer: la llave de una sala aún cerrada que ya no está en
-- ningún sitio (se cayó del mapa, o la llevaba en su mochila guardada alguien que no ha venido) vuelve a su sitio.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Azar = require(ReplicatedStorage.Shared.Azar)
local Config = require(ReplicatedStorage.Shared.Config)
local Casa = require(script.Parent.Casa)
local Mapa = require(script.Parent.Mapa)
local Mochila = require(script.Parent.Mochila)
local Reparto = require(script.Parent.Reparto)

local Llaves = {}

local CAT = Config.Objetos

local function esLlave(tipo: unknown): boolean
	return type(tipo) == "string" and CAT[tipo] ~= nil and CAT[tipo].Llave == true
end

-- Dónde sale en esta partida la llave número `orden` de Config.Llaves (siempre el mismo sitio con la misma semilla).
function Llaves.sitio(semilla: number, orden: number): CFrame?
	local sitios = Mapa.llaves[Config.Llaves[orden].Zona]
	if not sitios or #sitios == 0 then
		return nil
	end
	return sitios[Azar.entero(semilla, orden, 1, #sitios)]
end

-- Pone en su sitio las llaves de las salas cerradas que no estén sueltas ni en la mochila de alguien que esté.
-- `guardadas` = las mochilas guardadas de la partida ([UserId] = { cosas }): a los que no están se les quitan.
function Llaves.repasar(semilla: number, guardadas: { [string]: any })
	local vistas: { [string]: number } = {}
	for _, o in Mochila.sueltos() do
		if esLlave(o.tipo) then
			vistas[o.tipo] = (vistas[o.tipo] or 0) + 1
		end
	end
	local estan: { [string]: boolean } = {}
	for _, jugador in Players:GetPlayers() do
		estan[tostring(jugador.UserId)] = true
		for _, l in Config.Llaves do
			vistas[l.Llave] = (vistas[l.Llave] or 0) + Mochila.contar(jugador, l.Llave)
		end
	end
	for _, llave in Reparto.faltan(Casa.cerradas(), vistas, guardadas, estan, esLlave) do
		for orden, l in Config.Llaves do
			local cf = l.Llave == llave and Llaves.sitio(semilla, orden)
			if cf then
				Mochila.dejar(llave, nil, cf)
			end
		end
	end
end

-- Al morir, las llaves que lleva caen donde estaba.
local function soltarAlMorir(jugador: Player)
	local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not raiz then
		return
	end
	local i = 0
	for _, l in Config.Llaves do
		while Mochila.sacar(jugador, l.Llave) do
			i += 1
			local angulo = i * 2.4
			Mochila.dejar(l.Llave, nil, CFrame.new(raiz.Position + Vector3.new(math.cos(angulo) * 1.5, 0.5, math.sin(angulo) * 1.5)))
		end
	end
end

local function alEntrar(jugador: Player)
	jugador:GetAttributeChangedSignal("Muerto"):Connect(function()
		if jugador:GetAttribute("Muerto") then
			soltarAlMorir(jugador)
		end
	end)
end

function Llaves.start()
	Casa.conLlave(function(jugador, llave)
		return Mochila.sacar(jugador, llave) ~= nil
	end)
	Players.PlayerAdded:Connect(alEntrar)
	for _, jugador in Players:GetPlayers() do
		alEntrar(jugador)
	end
end

return Llaves
