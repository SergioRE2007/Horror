-- La partida guardada (la casa es del que la crea, con Config.Partida.Ranuras por jugador). Al arrancar el servidor:
-- lee quién es el dueño, qué ranura y quiénes vienen (Viaje.leer, lo apuntó el lobby; en Studio, el dueño falso de
-- Config.Test), coge la partida con candado (Candado, como los jugadores) y deja el mundo como estaba.
--   Al amanecer hace una foto de todo (formato en FormatoPartida) y la guarda. Si mueren todos se vuelve a esa foto
--   (volverAlAmanecer) y si os vais también es lo que queda: lo del día no cuenta hasta el amanecer.
--   Las mochilas son de cada jugador dentro de la partida; lo que lleva el que se va cae al suelo (Mochila) y deja de
--   ser suyo en la siguiente foto.
--   Si el dueño se va, se espera Config.Partida.EsperaDueno por si es un corte y luego se acaba para todos.
--   Cada guardado apunta en los datos del dueño el resumen de la ranura (lo que enseña el lobby).
-- Modo de pruebas: un almacén de mentira que dura lo que la prueba. ServerStorage.Prueba:Fire("Guardar") hace la foto
-- y la guarda ya; ("Cargar") la vuelve a leer del almacén y la pone, como al volver a entrar.
-- Detalle en docs/sistemas/partida.md.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Prueba = require(ReplicatedStorage.Shared.Prueba)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Comun = ServerScriptService:WaitForChild("Comun")
local Candado = require(Comun.Candado)
local Datos = require(Comun.Datos)
local Viaje = require(Comun.Viaje)
local Cargar = require(script.Parent.Cargar)
local Casa = require(script.Parent.Casa)
local Ciclo = require(script.Parent.Ciclo)
local FormatoPartida = require(script.Parent.FormatoPartida)
local Generador = require(script.Parent.Generador)
local Mochila = require(script.Parent.Mochila)
local Recursos = require(script.Parent.Recursos)

local Partida = {}

local P = Config.Partida
local CAT = { objetos = Config.Objetos, pesados = Config.Pesados, maximo = P.Sueltos }
local info: Viaje.Info? = nil
local op: Candado.Opciones? = nil -- nil = no se guarda (sin cargar, acabada o perdida)
local crudo = nil -- lo que había guardado al cargar, tal cual (se devuelve si se cierra antes del primer amanecer)
local ultima = nil -- la foto del último amanecer: lo que se guarda y a lo que se vuelve
local semilla = 0
local idos: { [string]: boolean } = {} -- UserIds que se han ido en esta sesión (lo suyo cayó al suelo)
local guardando = false
local acabada = false
local esperaDueno = 0 -- sube cada vez que el dueño se va: una espera vieja no acaba la partida
local almacenPrueba = nil

local function redondear(n: number, cifras: number): number
	local m = 10 ^ cifras
	return math.round(n * m) / m
end

-- Lo suelto de los sistemas ({ tipo, carga, cf }) a lo guardable ({ tipo, carga, sitio }) y al revés.
local function guardables(lista: { { tipo: string, carga: number?, cf: CFrame } })
	local salida = {}
	for _, c in lista do
		local rx, ry, rz = c.cf:ToEulerAnglesXYZ()
		local p = c.cf.Position
		table.insert(salida, {
			tipo = c.tipo,
			carga = if c.carga then redondear(c.carga, 4) else nil,
			sitio = { redondear(p.X, 2), redondear(p.Y, 2), redondear(p.Z, 2), redondear(rx, 3), redondear(ry, 3), redondear(rz, 3) },
		})
	end
	return salida
end

local function delMundo(lista)
	local salida = {}
	for _, c in lista do
		local s = c.sitio
		table.insert(salida, { tipo = c.tipo, carga = c.carga, cf = CFrame.new(s[1], s[2], s[3]) * CFrame.fromEulerAnglesXYZ(s[4], s[5], s[6]) })
	end
	return salida
end

-- Cómo está todo ahora, en el formato de FormatoPartida.
local function foto()
	local mochilas = table.clone(if ultima then ultima.mochilas else {})
	for id in idos do
		mochilas[id] = nil
	end
	for _, jugador in Players:GetPlayers() do
		local mochila = Mochila.exportar(jugador)
		if mochila then
			mochilas[tostring(jugador.UserId)] = mochila
		end
	end
	local generador = Generador.exportar()
	if generador.movil then
		generador.movil = redondear(generador.movil, 4)
	end
	return {
		version = FormatoPartida.VERSION,
		noche = select(2, Ciclo.fase()),
		semilla = semilla,
		casa = Casa.exportar(),
		arboles = Recursos.exportar(),
		generador = generador,
		objetos = guardables(Mochila.sueltos()),
		pesados = guardables(Cargar.sueltos()),
		mochilas = mochilas,
	}
end

local function ponerMochila(jugador: Player)
	Mochila.importar(jugador, if ultima then ultima.mochilas[tostring(jugador.UserId)] else nil)
end

-- Deja el mundo como en `d` (ya arreglado con FormatoPartida). El orden importa: el móvil del enchufe (Generador)
-- después de quitar los objetos sueltos (Mochila).
local function aplicar(d)
	Cargar.importar(delMundo(d.pesados))
	Mochila.importarSueltos(delMundo(d.objetos))
	Casa.importar(d.casa)
	Recursos.importar(d.arboles)
	Generador.importar(d.generador)
	for _, jugador in Players:GetPlayers() do
		ponerMochila(jugador)
	end
end

local acabar: (texto: string) -> ()

-- Guarda la última foto (con `soltar`, suelta el candado). Un guardado a la vez.
local function guardar(soltar: boolean)
	while guardando do
		task.wait()
	end
	local mio = op
	if not mio then
		return
	end
	guardando = true
	local estado = Candado.guardar(mio, ultima or crudo, soltar, if soltar then Config.Guardado.Intentos else 1)
	guardando = false
	if soltar then
		op = nil
	end
	if estado == "perdido" then
		-- Otro servidor tiene la partida: lo de aquí está viejo. Dejar de guardar y acabar.
		op = nil
		acabar("This game was opened in another server.")
	elseif estado == "ok" and ultima and info then
		local dueno = Players:GetPlayerByUserId(info.dueno)
		local ranura, noche = tostring(info.ranura), ultima.noche
		if dueno then
			Datos.editar(dueno, function(datos)
				datos.partidas[ranura] = { noche = noche, hora = os.time() }
			end)
		end
	end
end

-- Se acaba para todos: se queda lo del último amanecer y vuelven al lobby.
acabar = function(texto: string)
	if acabada then
		return
	end
	acabada = true
	task.spawn(guardar, true)
	task.spawn(Viaje.volver, Players:GetPlayers(), texto) -- sin esperar: lo llaman desde el ciclo y el arranque
end

function Partida.volverAlAmanecer()
	if ultima then
		aplicar(ultima)
		-- Lo que tiraron los que se fueron ya no está en el suelo: su mochila vuelve a ser la del amanecer.
		table.clear(idos)
	end
end

-- Un DataStore de mentira para Studio (una clave, en memoria): pasa por JSON, como el de verdad.
local function almacenDeMentira()
	local guardado: string? = nil
	return {
		UpdateAsync = function(_, _clave: string, transformar)
			local nuevo = transformar(if guardado then HttpService:JSONDecode(guardado) else nil)
			if nuevo ~= nil then
				guardado = HttpService:JSONEncode(nuevo)
			end
			return nuevo
		end,
	}
end

local function alEntrar(jugador: Player)
	local id = tostring(jugador.UserId)
	while not jugador:GetAttribute("Mochila") and jugador.Parent do -- que Mochila le haya preparado la suya
		task.wait()
	end
	if acabada then
		Viaje.volver({ jugador }, "This game has already ended.")
	elseif info and #info.jugadores > 0 and not table.find(info.jugadores, jugador.UserId) then
		Viaje.volver({ jugador }, "This game has already started.")
	elseif idos[id] then
		-- Se fue y ha vuelto: lo suyo se quedó en el suelo. Si se vuelve al amanecer, recupera la de entonces.
		idos[id] = nil
		Mochila.importar(jugador, { cosas = {} })
	elseif ultima then
		ponerMochila(jugador)
	end
	if info and jugador.UserId == info.dueno then
		esperaDueno += 1
	end
end

local function alSalir(jugador: Player)
	idos[tostring(jugador.UserId)] = true
	if not info or jugador.UserId ~= info.dueno or acabada then
		return
	end
	esperaDueno += 1
	local mio = esperaDueno
	for _, otro in Players:GetPlayers() do
		if otro ~= jugador then
			Remotes.Aviso:FireClient(otro, Lang.t(otro, "The host left. If they don't come back soon, the game ends."))
		end
	end
	task.delay(P.EsperaDueno, function()
		if esperaDueno == mio and info and not Players:GetPlayerByUserId(info.dueno) then
			acabar("The host left the game.")
		end
	end)
end

-- Carga la partida y deja el mundo como estaba. Devuelve la noche del día con el que se empieza (para Ciclo).
-- Espera a tenerlo todo: va después de los sistemas que guarda y antes de Ciclo.
function Partida.start(): number
	Players.PlayerAdded:Connect(alEntrar)
	Players.PlayerRemoving:Connect(alSalir)
	Ciclo.alCambiar(function(fase)
		if fase == "Dia" and op and not acabada then
			ultima = foto()
			task.spawn(guardar, false) -- sin frenar al resto de los que escuchan el amanecer
		end
	end)
	task.spawn(function() -- renueva el candado aunque tarde en amanecer
		while true do
			task.wait(Config.Guardado.Intervalo)
			if op and not acabada then
				guardar(false)
			end
		end
	end)
	game:BindToClose(function()
		guardar(true)
	end)

	if Prueba.activa() then
		local primero = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
		info = { dueno = Config.Test.Dueno or primero.UserId, ranura = Config.Test.Ranura, nueva = Config.Test.Nueva, jugadores = {} }
		almacenPrueba = almacenDeMentira()
		ServerStorage:WaitForChild("Prueba").Event:Connect(function(que: string)
			if que == "Guardar" then
				ultima = foto()
				guardar(false)
			elseif que == "Cargar" and op then
				local leido = nil
				almacenPrueba:UpdateAsync(op.clave, function(actual)
					leido = actual
					return nil
				end)
				ultima = FormatoPartida.arreglar(leido and leido.datos, CAT)
				Partida.volverAlAmanecer()
			end
		end)
	else
		info = Viaje.leer()
		if not info then
			acabar("Start the game from the lobby.")
			return 1
		end
	end
	local viaje = info :: Viaje.Info
	for _, jugador in Players:GetPlayers() do
		if #viaje.jugadores > 0 and not table.find(viaje.jugadores, jugador.UserId) then
			Viaje.volver({ jugador }, "This game has already started.")
		end
	end

	local opciones: Candado.Opciones = {
		almacen = almacenPrueba or DataStoreService:GetDataStore(P.Almacen),
		clave = `partida_{viaje.dueno}_{viaje.ranura}`,
		id = HttpService:GenerateGUID(false),
		ahora = os.time,
		esperar = task.wait,
		config = Config.Guardado,
		aviso = warn,
	}
	-- `op` solo cuando ya es nuestra: un cierre a media carga no debe escribir nada (borraría la partida).
	local estado, guardado = Candado.cargar(opciones)
	if estado ~= "ok" then
		acabar(if estado == "ocupado" then "This game is still open in another server. Try again in a minute."
			else "The game could not be loaded. Try again in a minute.")
		return 1
	end
	crudo = guardado
	op = opciones
	-- El dueño puede no llegar nunca (su teletransporte falló): sin él, la partida no sigue.
	local mio = esperaDueno
	task.delay(P.EsperaDueno, function()
		if esperaDueno == mio and not Players:GetPlayerByUserId(viaje.dueno) then
			acabar("The host left the game.")
		end
	end)
	local d = if viaje.nueva then nil else FormatoPartida.arreglar(guardado, CAT)
	if d then
		semilla = d.semilla
		ultima = d
		aplicar(d)
		return d.noche
	end
	semilla = Random.new():NextInteger(1, 2 ^ 31 - 2)
	return 1
end

return Partida
