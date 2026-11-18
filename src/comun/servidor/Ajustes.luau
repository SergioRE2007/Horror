-- Ajustes del jugador que se guardan entre partidas (14.4). Por ahora solo Rendimiento: menos partículas y sin
-- adornos animados; lo leen los módulos de efectos del cliente con jugador:GetAttribute("Rendimiento").
-- Vale en los dos lugares. Se guarda en los datos del jugador (campo `rendimiento` de Formato) y se publica en el
-- atributo "Rendimiento" del Player al cargar. El cliente lo cambia con el remote Ajustes ("Rendimiento", activo):
-- solo un booleano, como mucho uno cada MINIMO segundos. Al entrar, un cliente táctil sin teclado sugiere
-- ("Sugerir", true) y solo vale si el jugador nunca lo eligió (Formato.sugerirRendimiento, 16.9). Detalle en
-- docs/sistemas/ajustes.md.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Datos = require(script.Parent.Datos)
local Formato = require(script.Parent.Formato)
local Limite = require(script.Parent.Limite)

local Ajustes = {}

local function publicar(jugador: Player)
	local datos = Datos.leer(jugador)
	if datos then
		jugador:SetAttribute("Rendimiento", datos.rendimiento == true)
	end
end

local function alEntrar(jugador: Player)
	while jugador.Parent and not jugador:GetAttribute("DatosListos") do
		task.wait(0.5)
	end
	publicar(jugador)
end

local function cambiar(jugador: Player, que: unknown, valor: unknown)
	if (que ~= "Rendimiento" and que ~= "Sugerir") or type(valor) ~= "boolean" then
		return
	end
	if not Limite.pasa(jugador, "Ajustes", Config.Limites.Ajustes) then
		return -- el cliente solo enseña el atributo: si se pierde una pulsación, el botón sigue diciendo la verdad
	end
	Datos.editar(jugador, function(datos)
		if que == "Sugerir" then
			Formato.sugerirRendimiento(datos, valor) -- no hace nada si ya lo eligió (o ya se sugirió)
		else
			datos.rendimiento = valor
			datos.rendimientoElegido = true
		end
	end)
	publicar(jugador) -- se guarda con el siguiente guardado normal (o al salir)
end

function Ajustes.start()
	Players.PlayerAdded:Connect(alEntrar)
	for _, jugador in Players:GetPlayers() do
		task.spawn(alEntrar, jugador)
	end
	Remotes.Ajustes.OnServerEvent:Connect(cambiar)
end

return Ajustes
