-- Agacharse y asomarse (14.6, pedido por el usuario: "cuerpo: agacharse (botón también en el móvil) y asomarse por las
-- esquinas"). Solo cuerpo y cámara: los bichos no lo notan (no cambia nada de su juego).
--   El cliente (PosturaVista) pide con el remote Postura: ("Agachado", sí/no) o ("Asomar", -1 / 0 / 1). Aquí se valida
--   con shared/PosturaReglas (tipos, cada cuánto y si puede) y se publica en los atributos del jugador Agachado (true o
--   nil) y Asomado (-1, 1 o nil), que leen CuerpoVista (su cámara) y BrazosVista (los demás le ven agachado o asomado).
--   Al morir, esconderse, reaparecer, coger algo pesado o ponerse a trabajar (talar, serrar, clavar...) se quita sola;
--   asomarse, también al abrir la mochila.
--   Agachado anda a Config.Postura.Velocidad: Cargar.ajustarVelocidad lo mira y se le llama tras cada cambio.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PosturaReglas = require(ReplicatedStorage.Shared.PosturaReglas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Cargar = require(script.Parent.Cargar)
local Muerte = require(script.Parent.Muerte)

local Postura = {}

local estados: { [Player]: PosturaReglas.Estado } = {}

local function estadoDe(jugador: Player): PosturaReglas.Estado
	return estados[jugador] or PosturaReglas.nuevo()
end

local function datosDe(jugador: Player): PosturaReglas.Jugador
	return {
		vivo = table.find(Muerte.vivos(), jugador) ~= nil,
		escondido = jugador:GetAttribute("Escondido") ~= nil,
		cargando = jugador:GetAttribute("Cargando") ~= nil or jugador:GetAttribute("Trabajando") ~= nil,
		mochila = jugador:GetAttribute("MochilaAbierta") == true,
	}
end

local function publicar(jugador: Player, estado: PosturaReglas.Estado)
	estados[jugador] = estado
	jugador:SetAttribute("Agachado", if estado.agachado then true else nil)
	jugador:SetAttribute("Asomado", if estado.asomado ~= 0 then estado.asomado else nil)
	Cargar.ajustarVelocidad(jugador)
end

-- Lo que pide el cliente: cualquier cosa rara, muy seguida o fuera de juego se tira sin más.
local function pedir(jugador: Player, que: unknown, valor: unknown)
	if not PosturaReglas.valida(que, valor) then
		return -- lo que no es una petición ni se mira (que mandarlo a chorro no cueste nada)
	end
	local estado, ahora = estadoDe(jugador), os.clock()
	local actual: boolean | number = if que == "Agachado" then estado.agachado else estado.asomado
	if actual == valor or ahora - estado.ultimo < Config.Postura.Cada then
		return -- sin efecto o demasiado seguido: tampoco se miran sus datos (Muerte.vivos hace una lista)
	end
	local cambia, nuevo = PosturaReglas.pedir(estado, que, valor, ahora, datosDe(jugador))
	if cambia then
		publicar(jugador, nuevo)
	end
end

-- Lo que ya no puede ser (muerto, escondido, cargando; asomado con la mochila abierta), fuera.
local function revisar(jugador: Player)
	local cambia, nuevo = PosturaReglas.limpiar(estadoDe(jugador), datosDe(jugador))
	if cambia then
		publicar(jugador, nuevo)
	end
end

-- Al reaparecer, de pie (también lo que hubiera quedado publicado de antes).
local function quitar(jugador: Player)
	local estado = estadoDe(jugador)
	if estado.agachado or estado.asomado ~= 0 or jugador:GetAttribute("Agachado") ~= nil
		or jugador:GetAttribute("Asomado") ~= nil then
		publicar(jugador, PosturaReglas.quitar(estado))
	end
end

local function conPersonaje(jugador: Player, personaje: Model)
	local humanoide = personaje:WaitForChild("Humanoid", 10)
	if humanoide and humanoide:IsA("Humanoid") then
		humanoide.Died:Connect(function()
			revisar(jugador)
		end)
	end
end

local function alEntrar(jugador: Player)
	for _, atributo in { "Muerto", "Escondido", "Cargando", "Trabajando", "MochilaAbierta" } do
		jugador:GetAttributeChangedSignal(atributo):Connect(function()
			revisar(jugador)
		end)
	end
	jugador.CharacterAdded:Connect(function(personaje)
		quitar(jugador)
		conPersonaje(jugador, personaje)
	end)
	if jugador.Character then
		task.spawn(conPersonaje, jugador, jugador.Character)
	end
end

function Postura.start()
	Players.PlayerAdded:Connect(alEntrar)
	for _, jugador in Players:GetPlayers() do
		alEntrar(jugador)
	end
	Players.PlayerRemoving:Connect(function(jugador)
		estados[jugador] = nil
	end)
	Remotes.Postura.OnServerEvent:Connect(pedir)
end

return Postura
