-- Tutorial de los primeros minutos (14.2 / 13.1; pedido por el usuario en el primer juego: "tiene que invadir más la
-- pantalla y que te diga más vistoso dónde clicar"). Sale una vez por cuenta: hasta que lo acaba (premio, el logro
-- Tutorial de Config.Recompensas) o lo salta. Los pasos y cuándo se pasa de uno a otro, en shared/PasosTutorial.
--   Cada Config.Tutorial.Cada s mira lo de cada jugador con tutorial (mochila, hacha, lo que carga, generador,
--   cortinas de abajo abiertas) y publica el paso en atributos del Player:
--     Tutorial = el paso ("Mochila", "Hacha"…; nil = sin tutorial), TutorialFalta = cortinas que quedan por cerrar.
--   El cliente (TutorialVista) pinta el cartel y la flecha; solo puede pedir saltarlo (remote Tutorial, "Saltar").
--   Todo lo que da premio lo mira el servidor: el cliente no puede acabarlo antes de tiempo.
-- En Studio solo sale con Config.Test.Tutorial (los datos de prueba nunca lo tienen hecho).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local PasosTutorial = require(ReplicatedStorage.Shared.PasosTutorial)
local Prueba = require(ReplicatedStorage.Shared.Prueba)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Comun = ServerScriptService:WaitForChild("Comun")
local Datos = require(Comun.Datos)
local Recompensas = require(Comun.Recompensas)
local Casa = require(script.Parent.Casa)
local Ciclo = require(script.Parent.Ciclo)
local Mochila = require(script.Parent.Mochila)

local Tutorial = {}

type Activo = {
	estado: PasosTutorial.Estado,
	mochila: boolean, -- ha abierto la mochila desde que empezó
	conexion: RBXScriptConnection,
}

local activos: { [Player]: Activo } = {}

local function quitar(jugador: Player)
	local a = activos[jugador]
	if a then
		a.conexion:Disconnect()
		activos[jugador] = nil
	end
	if jugador.Parent then
		jugador:SetAttribute("Tutorial", nil)
		jugador:SetAttribute("TutorialFalta", nil)
	end
end

-- Cortinas de la planta baja (las que ataca el Golpeador) aún abiertas; las rotas no cuentan (no se pueden cerrar).
local function cortinasAbiertas(): number
	local n = 0
	for _, el in Casa.atacables() do
		if el:GetAttribute("Persiana") == false and (el:GetAttribute("Vida") or 0) > 0 then
			n += 1
		end
	end
	return n
end

local function generadorEncendido(): boolean
	local gen = CollectionService:GetTagged("Generador")[1]
	return gen ~= nil and gen:GetAttribute("Encendido") == true
end

local function mirar()
	if next(activos) == nil then
		return
	end
	local fase, noche = Ciclo.fase()
	local fin = workspace:GetAttribute("FaseFin")
	local quedan = if type(fin) == "number" then fin - workspace:GetServerTimeNow() else math.huge
	local cortinas, generador = cortinasAbiertas(), generadorEncendido()
	for jugador, a in activos do
		if not jugador.Parent then
			quitar(jugador)
			continue
		end
		local cargando = jugador:GetAttribute("Cargando")
		local acabado = PasosTutorial.avanzar(a.estado, {
			fase = fase,
			noche = noche,
			quedan = quedan,
			aviso = Config.Ciclo.Aviso,
			mochila = a.mochila,
			hacha = Mochila.contar(jugador, "Hacha") > 0,
			cargando = if type(cargando) == "string" then cargando else nil,
			generador = generador,
			cortinas = cortinas,
		})
		if acabado then
			quitar(jugador)
			Recompensas.tutorial(jugador) -- apunta el logro (ya no vuelve a salir) y da las monedas una sola vez
		else
			jugador:SetAttribute("Tutorial", a.estado.paso)
			jugador:SetAttribute("TutorialFalta", if a.estado.paso == "Cortinas" then cortinas else nil)
		end
	end
end

local function empezar(jugador: Player)
	while jugador.Parent and not jugador:GetAttribute("DatosListos") do
		task.wait(0.5)
	end
	local datos = Datos.leer(jugador)
	if not jugador.Parent or not datos or datos.logros.Tutorial or activos[jugador] then
		return
	end
	local a: Activo
	a = {
		estado = PasosTutorial.nuevo(),
		mochila = false,
		conexion = jugador:GetAttributeChangedSignal("MochilaAbierta"):Connect(function()
			if jugador:GetAttribute("MochilaAbierta") then
				a.mochila = true
			end
		end),
	}
	activos[jugador] = a
end

-- Lo salta (sin premio): ya no vuelve a salir en esta cuenta.
local function saltar(jugador: Player, que: unknown)
	if que ~= "Saltar" or not activos[jugador] then
		return
	end
	quitar(jugador)
	if Datos.editar(jugador, function(datos)
		datos.logros.Tutorial = true
	end) then
		task.spawn(Datos.guardar, jugador)
	end
end

function Tutorial.start()
	if not Config.Tutorial.Activo or (Prueba.activa() and not Config.Test.Tutorial) then
		return
	end
	Players.PlayerAdded:Connect(empezar)
	for _, jugador in Players:GetPlayers() do
		task.spawn(empezar, jugador)
	end
	Players.PlayerRemoving:Connect(quitar)
	Remotes.Tutorial.OnServerEvent:Connect(saltar)
	task.spawn(function()
		while true do
			task.wait(Config.Tutorial.Cada)
			mirar()
		end
	end)
end

return Tutorial
