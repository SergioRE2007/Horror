-- Llaves de las salas cerradas (pedido por el usuario): sótano, garaje, desván y habitación del rico (Config.Llaves).
-- Cada llave sale, con la semilla de la partida, en uno de los sitios de su zona (Mapa.llaves, los pone Lugares), con
-- un brillo flojo (Mochila.dejar). Con ella en la mochila, la puerta de su sala se abre y la llave se gasta (Casa).
-- Si mueres con una llave o con las cerillas, se caen donde mueres (escondido, a la salida del escondite).
-- Se guarda todo con la partida (Partida): la sala abierta (Casa, "bloqueada") y la llave, suelta o en una mochila.
-- Partida llama a repasar al empezar, al cargar y al amanecer: la llave de una sala aún cerrada que ya no está en
-- ningún sitio (se cayó del mapa, o la llevaba en su mochila guardada alguien que no ha venido) vuelve a su sitio.
-- Lo único del final (Config.Objetos con Unica: pistola, bengalas, cerillas) tampoco se pierde con el que no vuelve:
-- se le quita y vuelve a su sitio del mapa; las cerillas, a la caja fuerte si ya se leyó su pista y no quedan más.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Azar = require(ReplicatedStorage.Shared.Azar)
local Config = require(ReplicatedStorage.Shared.Config)
local Casa = require(script.Parent.Casa)
local Mapa = require(script.Parent.Mapa)
local Mochila = require(script.Parent.Mochila)
local Muerte = require(script.Parent.Muerte)
local Pistas = require(script.Parent.Pistas)
local Reparto = require(script.Parent.Reparto)

local Llaves = {}

local CAT = Config.Objetos
local CERILLAS = "Cerillas"
local PISTA_CERILLAS = Config.Bestia.PistaCerillas
-- Del papel de la pista de la caja fuerte (empotrada en la pared este, mira al oeste) al suelo de delante.
local DELANTE_CAJA = Vector3.new(-1.6, -3.2, 0)
local LIBRE = 0.3 -- studs (en horizontal): una cosa suelta del mismo tipo más cerca de su sitio lo ocupa
local escondites: { [Player]: Model } = {} -- el último escondite de cada uno (para soltar a la salida)

local function esLlave(tipo: unknown): boolean
	return type(tipo) == "string" and CAT[tipo] ~= nil and CAT[tipo].Llave == true
end

local function esUnica(tipo: unknown): boolean
	return type(tipo) == "string" and CAT[tipo] ~= nil and CAT[tipo].Unica == true
end

-- Lo que se cuenta para no ponerlo dos veces: las llaves y las cerillas.
local function cuenta(tipo: unknown): boolean
	return esLlave(tipo) or tipo == CERILLAS
end

-- Lo quitado a los que no vuelven, a su sitio de Mapa.objetos: el primero de su tipo que no tenga ya uno encima. Se
-- mueve, no se copia (Reparto ya lo ha quitado de la mochila guardada). Si están todos ocupados, encima del primero.
local function devolver(tipos: { string })
	local sueltos = Mochila.sueltos()
	local usados: { [number]: boolean } = {}
	for n, tipo in tipos do
		local elegido, primero = nil, nil
		for i, o in Mapa.objetos do
			if o.tipo == tipo then
				primero = primero or i
				local libre = not usados[i]
				for _, s in sueltos do
					local d = s.cf.Position - o.cf.Position
					if libre and s.tipo == tipo and Vector2.new(d.X, d.Z).Magnitude < LIBRE then
						libre = false
					end
				end
				if libre then
					elegido = i
					break
				end
			end
		end
		if elegido then
			usados[elegido] = true
			Mochila.dejar(tipo, nil, Mapa.objetos[elegido].cf)
		elseif primero then
			Mochila.dejar(tipo, nil, Mapa.objetos[primero].cf + Vector3.new(0, 0.4 * n, 0))
		end
	end
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
-- `guardadas` = las mochilas guardadas de la partida ([UserId] = { cosas }): a los que no están se les quitan las
-- llaves y lo único, que vuelve a su sitio. `esperados` (solo al cargar) = los UserIds que vienen a esta sesión
-- (Viaje.Info): aún no han entrado pero cuentan como que están, y lo que llevan cuenta como visto.
function Llaves.repasar(semilla: number, guardadas: { [string]: any }, esperados: { number }?)
	local vistas: { [string]: number } = {}
	for _, o in Mochila.sueltos() do
		if cuenta(o.tipo) then
			vistas[o.tipo] = (vistas[o.tipo] or 0) + 1
		end
	end
	local estan: { [string]: boolean } = {}
	for _, jugador in Players:GetPlayers() do
		estan[tostring(jugador.UserId)] = true
		for _, l in Config.Llaves do
			vistas[l.Llave] = (vistas[l.Llave] or 0) + Mochila.contar(jugador, l.Llave)
		end
		vistas[CERILLAS] = (vistas[CERILLAS] or 0) + Mochila.contar(jugador, CERILLAS)
	end
	if esperados then
		Reparto.esperar(guardadas, esperados, estan, vistas, cuenta)
	end
	local faltan, quitadas = Reparto.faltan(Casa.cerradas(), vistas, guardadas, estan, esLlave, esUnica)
	for _, llave in faltan do
		for orden, l in Config.Llaves do
			local cf = l.Llave == llave and Llaves.sitio(semilla, orden)
			if cf then
				Mochila.dejar(llave, nil, cf)
			end
		end
	end
	local aSuSitio, cerillas = Reparto.reponer(quitadas, CERILLAS, Pistas.leida(PISTA_CERILLAS), vistas[CERILLAS] or 0)
	devolver(aSuSitio)
	local caja = cerillas and Pistas.sitio(PISTA_CERILLAS)
	if caja then
		Mochila.dejar(CERILLAS, nil, CFrame.new(caja.Position + DELANTE_CAJA))
	end
end

-- Dónde se cae lo que lleva al morir: donde estaba o, si le pillan dentro de un escondite (Muerte ya le ha soltado
-- el sitio cuando llega aquí), a su salida, que dentro del armario no se podría coger.
local function dondeCae(jugador: Player, raiz: BasePart): Vector3
	local sitio = escondites[jugador]
	escondites[jugador] = nil
	local dentro = sitio and sitio:GetAttribute("Dentro")
	local salida = sitio and sitio:GetAttribute("Salida")
	if typeof(dentro) == "CFrame" and typeof(salida) == "CFrame" and (raiz.Position - dentro.Position).Magnitude < 4 then
		return salida.Position
	end
	return raiz.Position
end

-- Al morir, las llaves y las cerillas que lleva caen a su alrededor.
local function soltarAlMorir(jugador: Player)
	local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not raiz then
		return
	end
	local centro = dondeCae(jugador, raiz)
	local tipos = {}
	for _, l in Config.Llaves do
		table.insert(tipos, l.Llave)
	end
	table.insert(tipos, CERILLAS)
	local i = 0
	for _, tipo in tipos do
		while Mochila.sacar(jugador, tipo) do
			i += 1
			local angulo = i * 2.4
			Mochila.dejar(tipo, nil, CFrame.new(centro + Vector3.new(math.cos(angulo) * 1.5, 0.5, math.sin(angulo) * 1.5)))
		end
	end
end

local function alEntrar(jugador: Player)
	jugador:GetAttributeChangedSignal("Escondido"):Connect(function()
		local sitio = jugador:GetAttribute("Escondido") ~= nil and Muerte.escondite(jugador)
		if sitio then
			escondites[jugador] = sitio
		end
	end)
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
	Players.PlayerRemoving:Connect(function(jugador)
		escondites[jugador] = nil
	end)
	for _, jugador in Players:GetPlayers() do
		alEntrar(jugador)
	end
end

return Llaves
