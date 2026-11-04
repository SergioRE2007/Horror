-- Correr y aguante (14.8, pedido por el usuario: "añadir la mecánica de correr, que tengas una stamina abajo del todo,
-- una barra fina así minimalista que aparezca al correr"). El servidor manda; las reglas, en shared/CorrerReglas.
--   El cliente (CorrerVista) solo pide con el remote Correr: un booleano, "quiero correr" (Shift mantenido, L3 o el
--   botón). Lo que no sea booleano se tira sin mirar nada más; demasiadas por segundo, también. Las muy seguidas se
--   juntan (CorrerReglas.pedir: la última espera en `pendiente`), así que mandarlo a chorro no cuesta ni sirve.
--   Un solo Heartbeat lleva a todos: CorrerReglas.paso con la velocidad plana de la raíz y lo que va hacia delante
--   (coseno con hacia donde mira la raíz: en primera persona, la cámara). Quien está en reposo (lleno, sin pedir y sin
--   frenar) no cuesta nada.
--   Publica en atributos del Player, solo al cambiar: Corriendo (true o nil), Aguante (0..1 redondeado a 0,01, como
--   mucho cada Config.Correr.Publicar s salvo al llegar a 0 o a 1: 1 es lleno de verdad), Agotado (true o nil), Frena
--   (true o nil: frenando tras agotarse) y Tropiezo (sube 1 cada vez que tropieza: al agotarse, a veces).
--   La velocidad la pone Cargar.ajustarVelocidad (la única que toca WalkSpeed), que lee Corriendo y Frena: se le llama
--   al cambiar cualquiera de los dos. Corriendo hace ruido: Caza lo lee (PosturaReglas.alcanceOido).
--   Al reaparecer, descansado. Shift no activa el Shift Lock (se quita al arrancar y a cada uno al entrar).
-- Seguridad: el cliente no dice cuánto aguante tiene ni a qué velocidad va; si miente con su velocidad (su personaje lo
-- simula él), lo más que consigue es no correr.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(ReplicatedStorage.Shared.Config)
local CorrerReglas = require(ReplicatedStorage.Shared.CorrerReglas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Cargar = require(script.Parent.Cargar)
local Muerte = require(script.Parent.Muerte)

local Correr = {}

local C = Config.Correr
-- Números a ojo (para mirarlos en Studio).
local TOPE = 30 -- peticiones por segundo como mucho: las de más se tiran sin mirarlas (Shift a mano no llega ni a 10)

-- Lo de cada jugador: su estado y lo último publicado.
type Datos = {
	estado: CorrerReglas.Estado,
	aguante: number, -- lo último publicado en Aguante
	publicado: number, -- cuándo (os.clock)
	corriendo: boolean,
	agotado: boolean,
	frena: boolean,
	ventana: number, -- desde cuándo cuenta las peticiones de este segundo (os.clock)
	cuantas: number, -- y cuántas lleva
	quien: CorrerReglas.Jugador, -- sus datos para CorrerReglas (la misma tabla cada vuelta)
}
local datos: { [Player]: Datos } = {}
local azar = Random.new()

local function nuevosDatos(): Datos
	return {
		estado = CorrerReglas.nuevo(),
		aguante = -1, -- nada publicado aún: lo primero se publica seguro
		publicado = -math.huge,
		corriendo = false,
		agotado = false,
		frena = false,
		ventana = -math.huge,
		cuantas = 0,
		quien = { vivo = false, escondido = false, cargando = false, mochila = false, agachado = false, asomado = false },
	}
end

-- ¿No hay nada que llevar? (lleno, sin pedir ni nada pendiente, sin correr, frenar ni estar agotado)
local function enReposo(e: CorrerReglas.Estado): boolean
	return e.aguante >= 1 and not e.quiere and e.pendiente == nil and not e.corriendo and not e.agotado and e.frena <= 0
end

-- El Aguante que se publica: 0 y 1 solo vacío y lleno de verdad; entre medias, a 0,01.
local function redondeo(aguante: number): number
	if aguante >= 1 then
		return 1
	elseif aguante <= 0 then
		return 0
	end
	return math.clamp(math.round(aguante * 100) / 100, 0.01, 0.99)
end

-- Publica lo que haya cambiado y, si cambia la velocidad (Corriendo o Frena), se la pide a Cargar.
local function publicar(jugador: Player, d: Datos, ahora: number)
	local e = d.estado
	local frena = e.frena > 0
	local velocidad = false
	if e.corriendo ~= d.corriendo then
		d.corriendo = e.corriendo
		jugador:SetAttribute("Corriendo", if e.corriendo then true else nil)
		velocidad = true
	end
	if frena ~= d.frena then
		d.frena = frena
		jugador:SetAttribute("Frena", if frena then true else nil)
		velocidad = true
	end
	if e.agotado ~= d.agotado then
		d.agotado = e.agotado
		jugador:SetAttribute("Agotado", if e.agotado then true else nil)
	end
	local aguante = redondeo(e.aguante)
	if aguante ~= d.aguante and (aguante == 0 or aguante == 1 or ahora - d.publicado >= C.Publicar) then
		d.aguante, d.publicado = aguante, ahora
		jugador:SetAttribute("Aguante", aguante)
	end
	if velocidad then
		Cargar.ajustarVelocidad(jugador)
	end
end

local function tropezar(jugador: Player)
	if azar:NextNumber() < C.Tropiezo then
		local antes = jugador:GetAttribute("Tropiezo")
		jugador:SetAttribute("Tropiezo", (if type(antes) == "number" then antes else 0) + 1)
	end
end

-- Lo que pide el cliente: lo que no sea sí/no, o de más en este segundo, se tira sin mirar nada más.
local function pedir(jugador: Player, valor: unknown)
	if not CorrerReglas.valida(valor) then
		return
	end
	local d = datos[jugador]
	if not d then
		return
	end
	local ahora = os.clock()
	if ahora - d.ventana >= 1 then
		d.ventana, d.cuantas = ahora, 0
	end
	d.cuantas += 1
	if d.cuantas > TOPE then
		return
	end
	local cambia, nuevo = CorrerReglas.pedir(d.estado, valor, ahora)
	if cambia then
		d.estado = nuevo -- cuenta en el siguiente Heartbeat (y lo publica él)
	end
end

-- Los datos del jugador para CorrerReglas (como Postura.datosDe), en su tabla de siempre.
local vivos: { [Player]: true } = {} -- el conjunto de esta vuelta (la misma tabla siempre)
local function datosDe(jugador: Player, d: Datos): CorrerReglas.Jugador
	local q = d.quien
	q.vivo = vivos[jugador] == true
	q.escondido = jugador:GetAttribute("Escondido") ~= nil
	q.cargando = jugador:GetAttribute("Cargando") ~= nil or jugador:GetAttribute("Trabajando") ~= nil
	q.mochila = jugador:GetAttribute("MochilaAbierta") == true
	q.agachado = jugador:GetAttribute("Agachado") == true
	q.asomado = jugador:GetAttribute("Asomado") ~= nil
	return q
end

-- Un paso para todos los que tienen algo que llevar. Muerte.vivos() crea una lista: una vez por vuelta y solo si hace
-- falta.
local function vuelta(dt: number)
	local mirados = false
	local ahora = os.clock()
	for jugador, d in datos do
		if enReposo(d.estado) then
			continue
		end
		if not mirados then
			mirados = true
			table.clear(vivos)
			for _, j in Muerte.vivos() do
				vivos[j] = true
			end
		end
		local personaje = jugador.Character
		local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart")
		local velocidad, delante = 0, 0
		if raiz and raiz:IsA("BasePart") then
			local v = raiz.AssemblyLinearVelocity
			local plana = Vector3.new(v.X, 0, v.Z)
			local mira = raiz.CFrame.LookVector
			local miraPlana = Vector3.new(mira.X, 0, mira.Z)
			velocidad = plana.Magnitude
			if velocidad > 1e-3 and miraPlana.Magnitude > 1e-3 then
				delante = plana.Unit:Dot(miraPlana.Unit)
			end
		end
		local nuevo, aviso = CorrerReglas.paso(d.estado, dt, ahora, velocidad, delante, datosDe(jugador, d))
		d.estado = nuevo
		if aviso == "Agota" then
			tropezar(jugador)
		end
		publicar(jugador, d, ahora)
	end
end

-- Al reaparecer: descansado y sin pedir nada.
local function reaparecer(jugador: Player)
	local d = datos[jugador]
	if not d then
		return
	end
	d.estado = CorrerReglas.reaparecer(d.estado)
	publicar(jugador, d, os.clock())
end

local function alEntrar(jugador: Player)
	if datos[jugador] then
		return
	end
	datos[jugador] = nuevosDatos()
	pcall(function()
		jugador.DevEnableMouseLock = false -- Shift es correr, no el Shift Lock
	end)
	jugador.CharacterAdded:Connect(function()
		reaparecer(jugador)
	end)
	publicar(jugador, datos[jugador], os.clock())
end

function Correr.start()
	pcall(function()
		StarterPlayer.EnableMouseLockOption = false
	end)
	Players.PlayerAdded:Connect(alEntrar)
	for _, jugador in Players:GetPlayers() do
		alEntrar(jugador)
	end
	Players.PlayerRemoving:Connect(function(jugador)
		datos[jugador] = nil
		vivos[jugador] = nil
	end)
	Remotes.Correr.OnServerEvent:Connect(pedir)
	RunService.Heartbeat:Connect(vuelta)
end

return Correr
