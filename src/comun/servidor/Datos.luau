-- Guardado de cada jugador (monedas, clases, cosméticos, logros…), con candado de sesión (Candado) y el formato de
-- Formato. Vale en los dos lugares. Al entrar se carga, cada Config.Guardado.Intervalo se guarda y al salir se
-- guarda y se suelta el candado. Lo que el cliente necesita ver se publica en atributos del Player ("Monedas",
-- "Partidas"…); "DatosListos" = true cuando ya está cargado.
-- Desde fuera: Datos.leer(jugador) para mirar, Datos.editar(jugador, fn) para cambiar (publica solo) y
-- Datos.guardar(jugador) para guardar ya. Nunca escribir en ese DataStore por otro lado: se saltaría el candado.
-- Con el modo de pruebas (shared/Prueba) no se lee ni se guarda nada. Detalle en docs/sistemas/datos.md.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Prueba = require(ReplicatedStorage.Shared.Prueba)
local Candado = require(script.Parent.Candado)
local Formato = require(script.Parent.Formato)

local Datos = {}

type Partida = {
	datos: any,
	op: Candado.Opciones?, -- nil en el modo de pruebas (no se guarda)
	guardando: boolean,
	soltada: boolean?, -- el guardado de salida fue bien (lo que se juntó con él también está guardado)
	cola: { hecho: boolean, ok: boolean }?, -- el guardado normal que espera turno (los que llegan se juntan en él)
}

local partidas: { [Player]: Partida } = {}
local fuera: { [Player]: boolean } = setmetatable({}, { __mode = "k" }) :: any -- los que ya se han ido
local almacen = nil
local cargando = 0 -- cargas a medias: al cerrar el servidor también se esperan (si no, su candado se quedaba cogido)

local function publicar(jugador: Player, datos)
	jugador:SetAttribute("Monedas", datos.monedas)
	jugador:SetAttribute("Partidas", HttpService:JSONEncode(datos.partidas)) -- resumen de sus ranuras (el lobby)
	jugador:SetAttribute("Clases", HttpService:JSONEncode(datos.clases)) -- lo comprado (la tienda)
	jugador:SetAttribute("Cosmeticos", HttpService:JSONEncode(datos.cosmeticos))
end

local function opciones(jugador: Player): Candado.Opciones
	almacen = almacen or DataStoreService:GetDataStore(Config.Guardado.Almacen)
	return {
		almacen = almacen,
		clave = `jugador_{jugador.UserId}`,
		id = HttpService:GenerateGUID(false),
		ahora = os.time,
		esperar = task.wait,
		config = Config.Guardado,
		aviso = warn,
	}
end

-- Lo que da el modo de pruebas a una partida nueva.
local function datosDePrueba()
	local datos = Formato.jugadorNuevo()
	if Config.Test.Monedas > 0 then
		datos.monedas = Config.Test.Monedas
	end
	datos.partidas = table.clone(Config.Test.Partidas)
	return datos
end

local function cargar(jugador: Player)
	if Prueba.activa() then
		partidas[jugador] = { datos = datosDePrueba(), guardando = false }
	else
		local op = opciones(jugador)
		cargando += 1
		local cargado, estado, guardado = pcall(Candado.cargar, op)
		if not cargado then
			warn("[Datos] " .. tostring(estado))
			estado, guardado = "fallo", nil
		end
		if fuera[jugador] or jugador.Parent == nil then
			-- Se fue mientras cargaba (también al cerrar el servidor): soltar el candado sin perder nada.
			if estado == "ok" then
				Candado.guardar(op, Formato.arreglarJugador(guardado), true, Config.Guardado.Intentos)
			end
			cargando -= 1
			return
		end
		cargando -= 1
		if estado == "ocupado" then
			jugador:Kick(Lang.t(jugador, "Your save is open in another server. Try again in a minute."))
			return
		elseif estado ~= "ok" then
			jugador:Kick(Lang.t(jugador, "Your save could not be loaded. Try again in a minute."))
			return
		end
		partidas[jugador] = { datos = Formato.arreglarJugador(guardado), op = op, guardando = false }
	end
	publicar(jugador, partidas[jugador].datos)
	jugador:SetAttribute("DatosListos", true)
end

-- Guarda ya (sin esperar a nadie: quien llama ya ha mirado que no hay otro guardado en marcha).
local function guardarYa(jugador: Player, partida: Partida, soltar: boolean): boolean
	if partidas[jugador] ~= partida then
		-- Otro guardado ya lo soltó: si fue bien, ya llevaba lo de este (una compra hecha justo al salir).
		return partida.soltada == true
	end
	if not partida.op then
		if soltar then
			partidas[jugador] = nil
		end
		return true
	end
	partida.guardando = true
	local intentos = if soltar then Config.Guardado.Intentos else 1
	local ok, estado = pcall(Candado.guardar, partida.op, partida.datos, soltar, intentos)
	partida.guardando = false -- también si falla: si no, los que esperan se quedaban esperando para siempre
	if not ok then
		warn("[Datos] " .. tostring(estado))
		estado = "fallo"
	end
	if estado == "perdido" then
		-- Otro servidor tiene la partida: lo de aquí está viejo. Dejar de guardar y echarlo.
		partidas[jugador] = nil
		if jugador.Parent then
			jugador:Kick(Lang.t(jugador, "Your save was opened in another server."))
		end
	elseif soltar then
		partidas[jugador] = nil
		partida.soltada = estado == "ok"
	end
	return estado == "ok"
end

-- Guarda y, con `soltar`, suelta el candado y olvida al jugador. Un guardado a la vez por jugador. true si ha quedado
-- guardado (con el modo de pruebas no se guarda nada y también es true).
-- Los guardados normales que llegan mientras otro está en marcha se juntan: el primero que espera guarda también lo
-- de los demás (aún no ha leído los datos) y todos reciben su resultado. Así pulsar muchas veces algo que guarda no
-- gasta el cupo de DataStore del servidor, que es de todos.
local function guardar(jugador: Player, soltar: boolean): boolean
	local partida = partidas[jugador]
	if not partida then
		return false
	end
	if not soltar and partida.guardando then
		local cola = partida.cola
		if cola then
			while not cola.hecho do
				task.wait()
			end
			return cola.ok
		end
		cola = { hecho = false, ok = false }
		partida.cola = cola
		while partida.guardando do
			task.wait()
		end
		partida.cola = nil -- desde aquí, lo que llegue espera al siguiente
		cola.ok = guardarYa(jugador, partida, false)
		cola.hecho = true
		return cola.ok
	end
	while partida.guardando do
		task.wait()
	end
	return guardarYa(jugador, partida, soltar)
end

-- Los datos del jugador, o nil si aún no están cargados. Solo para mirar: los cambios, con Datos.editar.
function Datos.leer(jugador: Player)
	local partida = partidas[jugador]
	return if partida then partida.datos else nil
end

-- Cambia los datos con fn(datos) y publica lo que ve el cliente. false si aún no estaban cargados.
function Datos.editar(jugador: Player, fn: (datos: any) -> ()): boolean
	local partida = partidas[jugador]
	if not partida then
		return false
	end
	fn(partida.datos)
	publicar(jugador, partida.datos)
	return true
end

-- Guarda ya. true si ha quedado guardado (una compra de Robux solo se confirma a Roblox entonces).
function Datos.guardar(jugador: Player): boolean
	return guardar(jugador, false)
end

function Datos.start()
	Players.PlayerAdded:Connect(cargar)
	for _, jugador in Players:GetPlayers() do
		task.spawn(cargar, jugador)
	end
	Players.PlayerRemoving:Connect(function(jugador)
		fuera[jugador] = true
		guardar(jugador, true)
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Guardado.Intervalo)
			for jugador in partidas do
				task.spawn(guardar, jugador, false)
			end
		end
	end)

	game:BindToClose(function()
		local pendientes = 0
		for jugador in partidas do
			pendientes += 1
			task.spawn(function()
				guardar(jugador, true)
				pendientes -= 1
			end)
		end
		local inicio = os.clock()
		while (pendientes > 0 or cargando > 0) and os.clock() - inicio < Config.Guardado.Cierre do
			task.wait(0.1)
		end
	end)
end

return Datos
