-- Un Roblox de mentira para los bancos de Lune (pedido por el usuario: "para animaciones e interfaz, bancos con un
-- Roblox de mentira que carguen el módulo de verdad y miren cada fotograma (NaN, que nada atraviese suelo, paredes ni
-- muebles)"). Empieza por "_": es una ayuda, el corredor de tests/regressions.luau no la ejecuta.
--
--   local crearMundo = require("./_roblox")
--   local mundo = crearMundo()            -- un mundo nuevo y aislado (cliente; { servidor = true } para el servidor)
--   local Barra = mundo.cargar("src/juego/cliente/CorrerBarra")  -- el módulo de verdad, con script y require falsos
--   Barra.start()
--   mundo.correr(2, 1 / 60, function() ... mirar cada fotograma ... end)
--
-- Qué hay: los tipos de @lune/roblox (Vector3, CFrame, Enum...) y, hechos aquí, TweenInfo, RaycastParams,
-- OverlapParams, Random y DateTime; instancias en Lua con señales, atributos, etiquetas, Clone y Destroy; los servicios
-- que usan los módulos del cliente; un reloj que solo avanza con mundo.paso (task, os.clock, tick...); rayos y barridos
-- contra cajas (como Roblox: CanQuery, CanCollide, filtros y grupos de choque); un personaje R15 que anda, cae y no
-- atraviesa paredes; la cámara de Roblox en primera persona; teclas, ratón y clics.
-- Qué no hay (a propósito, para que sea pequeño): física de piezas sueltas, mallas de verdad (todo son cajas, las bolas
-- esferas), Terrain, maquetación de la interfaz (UIListLayout, UIScale y UIPadding no cambian AbsoluteSize), red de
-- verdad (los remotes guardan lo que se les manda), DataStores y los .rbxmx de src.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local typeofNativo = typeof
local Vector3, Vector2, CFrame, Color3 = roblox.Vector3, roblox.Vector2, roblox.CFrame, roblox.Color3
local UDim, UDim2, Font = roblox.UDim, roblox.UDim2, roblox.Font
local NumberSequence, ColorSequence, NumberRange = roblox.NumberSequence, roblox.ColorSequence, roblox.NumberRange

local EPOCA = 1_793_000_000 -- tick() al empezar (noviembre de 2026, más o menos)
local NADA = newproxy() -- una propiedad puesta a nil a mano (manda sobre el valor por defecto)
local CARGANDO = newproxy()
local INFINITO = math.huge

-- Lo que hay en src, leído una vez al cargar esta ayuda: las funciones de @lune/fs son asíncronas y, llamadas desde una
-- corrutina del mundo (un require dentro de un módulo), la dejarían a medias. Solo los .luau (y qué hay en cada carpeta).
local CARPETAS: { [string]: { string } } = {}
local ARCHIVOS: { [string]: string } = {}
local function escanear(dir: string)
	local nombres = fs.readDir(dir)
	table.sort(nombres)
	CARPETAS[dir] = nombres
	for _, n in nombres do
		local ruta = dir .. "/" .. n
		if string.sub(n, 1, 1) ~= "." then
			if fs.isDir(ruta) then
				escanear(ruta)
			elseif string.match(n, "%.luau$") then
				ARCHIVOS[ruta] = fs.readFile(ruta)
			end
		end
	end
end
if fs.isDir("src") then
	escanear("src")
end
CARPETAS["."] = { "src" }

-- Enum con cada EnumItem siempre el mismo objeto: los de @lune/roblox salen nuevos en cada acceso y una tabla con ellos
-- de clave (t[Enum.KeyCode.W]) no los encontraría. Lo comparten todos los mundos (no cambia).
local tiposEnum: { [string]: any } = {}
local MT_ENUMS = { __tipo = "Enums", __tostring = function()
	return "Enum"
end }
local Enum: any = setmetatable({
	GetEnums = function()
		local l = {}
		for _, e in roblox.Enum:GetEnums() do
			table.insert(l, (Enum :: any)[tostring(e):sub(6)])
		end
		return l
	end,
}, MT_ENUMS)
MT_ENUMS.__index = function(_, nombre: string)
	local t = tiposEnum[nombre]
	if t then
		return t
	end
	local real = roblox.Enum[nombre]
	local items: { [string]: any } = {}
	local function item(n: string)
		local i = items[n]
		if i == nil then
			i = real[n]
			items[n] = i
		end
		return i
	end
	local metodos = {
		GetEnumItems = function()
			local l = {}
			for _, i in real:GetEnumItems() do
				table.insert(l, item(i.Name))
			end
			return l
		end,
		FromName = function(_, n: string)
			return if pcall(function()
				return real[n]
			end) then item(n) else nil
		end,
		FromValue = function(_, v: number)
			for _, i in real:GetEnumItems() do
				if i.Value == v then
					return item(i.Name)
				end
			end
			return nil
		end,
	}
	t = setmetatable({}, { __tipo = "Enum", __tostring = function()
		return "Enum." .. nombre
	end, __index = function(_, n)
		return metodos[n] or item(n)
	end })
	tiposEnum[nombre] = t
	return t
end
-- ¿Es `item` de este tipo de Enum? (item.EnumType es el de @lune/roblox, no el de aquí)
local function deTipo(item: any, nombre: string): boolean
	return typeof(item) == "EnumItem" and tostring(item.EnumType) == "Enum." .. nombre
end

export type Opciones = {
	servidor: boolean?, -- un mundo de servidor (IsServer, sin LocalPlayer ni cámara de Roblox)
	studio: boolean?, -- RunService:IsStudio() (por defecto false: como publicado, Config.Test apagado)
	proyecto: string?, -- el .project.json de Rojo que dice qué carpeta es qué (por defecto juego.project.json)
	semilla: number?, -- de Random.new() sin semilla y de math.random
	estricto: boolean?, -- un error en una conexión o tarea para el banco (por defecto true); false: se apunta y sigue
	pantalla: Vector2?, -- ViewportSize (por defecto 1280 × 720)
}

return function(opciones: Opciones?)
	local op: Opciones = opciones or {}
	local mundo: any = {
		errores = {} :: { string }, -- errores en conexiones, tareas y módulos (con su traza)
		avisos = {} :: { string }, -- warn() y avisos del mundo falso (WaitForChild que no encuentra, clases que no conoce)
		estricto = op.estricto ~= false,
		falsos = {} :: { [string]: any }, -- módulos sustituidos: por ruta ("src/shared/Sonido") o por nombre ("Sonido")
		sueloY = 0 :: number?, -- un suelo infinito e invisible para los personajes (nil = sin él: caen al vacío)
		controles = true, -- WASD y espacio mueven al personaje del jugador local (como los controles de Roblox)
		camaraRoblox = true, -- la cámara de Roblox en primera persona (prioridad Camera) sigue la cabeza
		dt = 1 / 60,
	}
	local esServidor = op.servidor == true

	------------------------------------------------------------------------------------------------------------------
	-- Avisos y errores
	local yaAvisado: { [string]: boolean } = {}
	local function aviso(texto: string)
		table.insert(mundo.avisos, texto)
		if not yaAvisado[texto] then
			yaAvisado[texto] = true
			print("[aviso] " .. texto)
		end
	end

	------------------------------------------------------------------------------------------------------------------
	-- Reloj y tareas: solo avanzan con mundo.paso. Cada conexión, tarea y módulo corre en su corrutina (como Roblox).
	local ahora = 0
	local cuadro = 0
	local hilos: { [thread]: boolean } = setmetatable({}, { __mode = "k" }) :: any
	type Dormido = { co: thread, hora: number, cuadro: number, args: { n: number, [number]: any }?, orden: number }
	local dormidos: { Dormido } = {}
	local diferidos: { { co: thread, args: { n: number, [number]: any } } } = {}
	local ordenDormido = 0

	local fallos: { string } = {}
	local function fallo(co: thread, err: any)
		-- coroutine.resume de Lune vuelve texto cualquier error: el que ya se ha apuntado viaja como "[[falso#n]]".
		local s = tostring(err)
		local n = tonumber(string.match(s, "%[%[falso#(%d+)%]%]"))
		local texto = if n then fallos[n] else nil
		if not texto then
			texto = if string.find(s, "stack traceback", 1, true) then s else s .. "\n" .. debug.traceback(co)
			table.insert(mundo.errores, texto)
			table.insert(fallos, texto)
			n = #fallos
			if not mundo.estricto then
				print("[error en el mundo falso] " .. texto)
			end
		end
		if mundo.estricto then
			-- Dentro de otra corrutina del mundo sube la marca (hasta el banco, sin repetir la traza).
			if hilos[coroutine.running()] then
				error(`[[falso#{n}]]`, 0)
			end
			error(texto, 0)
		end
	end
	local function reanudar(co: thread, ...)
		if coroutine.status(co) ~= "suspended" then
			return
		end
		local ok, err = coroutine.resume(co, ...)
		if not ok then
			fallo(co, err)
		end
	end
	local function hilo(fn: (...any) -> ...any): thread
		local co = coroutine.create(fn)
		hilos[co] = true
		return co
	end
	local function ejecutar(fn: (...any) -> ...any, ...)
		local co = hilo(fn)
		reanudar(co, ...)
		return co
	end
	local function enHilo(): thread
		local co = coroutine.running()
		if not hilos[co] then
			error("esperar (task.wait, :Wait) solo vale dentro del mundo: desde el banco, avanza con mundo.paso", 3)
		end
		return co
	end
	local function dormir(co: thread, segundos: number, args: any?)
		ordenDormido += 1
		table.insert(dormidos, { co = co, hora = ahora + math.max(segundos, 0), cuadro = cuadro, args = args, orden = ordenDormido })
	end

	local task = {}
	function task.spawn(f: any, ...)
		local co = if type(f) == "thread" then f else hilo(f)
		reanudar(co, ...)
		return co
	end
	function task.defer(f: any, ...)
		local co = if type(f) == "thread" then f else hilo(f)
		table.insert(diferidos, { co = co, args = table.pack(...) })
		return co
	end
	function task.delay(segundos: number?, f: any, ...)
		local co = if type(f) == "thread" then f else hilo(f)
		dormir(co, segundos or 0, table.pack(...))
		return co
	end
	function task.wait(segundos: number?): number
		local co = enHilo()
		local desde = ahora
		dormir(co, segundos or 0)
		coroutine.yield()
		return ahora - desde
	end
	function task.cancel(co: thread)
		for i = #dormidos, 1, -1 do
			if dormidos[i].co == co then
				table.remove(dormidos, i)
			end
		end
		for i = #diferidos, 1, -1 do
			if diferidos[i].co == co then
				table.remove(diferidos, i)
			end
		end
		if coroutine.status(co) == "suspended" then
			coroutine.close(co)
		end
	end
	function task.synchronize() end
	function task.desynchronize() end

	local function vaciarDiferidos()
		for _ = 1, 1000 do
			if #diferidos == 0 then
				return
			end
			local lista = diferidos
			diferidos = {}
			for _, d in lista do
				reanudar(d.co, table.unpack(d.args, 1, d.args.n))
			end
		end
		error("task.defer sin fin (más de 1000 vueltas)")
	end
	local function despertar()
		local listos = {}
		for i = #dormidos, 1, -1 do
			local d = dormidos[i]
			if d.hora <= ahora + 1e-9 and d.cuadro < cuadro then
				table.insert(listos, d)
				table.remove(dormidos, i)
			end
		end
		table.sort(listos, function(a, b)
			if a.hora ~= b.hora then
				return a.hora < b.hora
			end
			return a.orden < b.orden
		end)
		for _, d in listos do
			if d.args then
				reanudar(d.co, table.unpack(d.args, 1, d.args.n))
			else
				reanudar(d.co)
			end
		end
	end

	------------------------------------------------------------------------------------------------------------------
	-- Señales (RBXScriptSignal): las conexiones corren cada una en su corrutina; Fire es inmediato (como
	-- SignalBehavior Immediate). Las señales falsas tienen :Fire para que el banco las dispare a mano.
	local Senal = {}
	Senal.__index = Senal
	Senal.__tipo = "RBXScriptSignal"
	local Conexion = {}
	Conexion.__index = Conexion
	Conexion.__tipo = "RBXScriptConnection"
	local function nuevaSenal()
		return setmetatable({ conexiones = {}, esperando = {} }, Senal)
	end
	function Senal:Connect(fn)
		assert(type(fn) == "function", "Connect necesita una función")
		local c = setmetatable({ Connected = true, fn = fn, senal = self }, Conexion)
		table.insert(self.conexiones, c)
		return c
	end
	Senal.ConnectParallel = Senal.Connect
	function Senal:Once(fn)
		local c
		c = self:Connect(function(...)
			c:Disconnect()
			fn(...)
		end)
		return c
	end
	function Senal:Wait()
		table.insert(self.esperando, enHilo())
		return coroutine.yield()
	end
	function Senal:Fire(...)
		if #self.conexiones > 0 then
			for _, c in table.clone(self.conexiones) do
				if c.Connected then
					ejecutar(c.fn, ...)
				end
			end
		end
		if #self.esperando > 0 then
			local lista = self.esperando
			self.esperando = {}
			for _, co in lista do
				reanudar(co, ...)
			end
		end
	end
	function Senal:apagar() -- al destruir la instancia
		for _, c in self.conexiones do
			c.Connected = false
		end
		self.conexiones = {}
	end
	function Conexion:Disconnect()
		if not self.Connected then
			return
		end
		self.Connected = false
		local i = table.find(self.senal.conexiones, self)
		if i then
			table.remove(self.senal.conexiones, i)
		end
	end

	------------------------------------------------------------------------------------------------------------------
	-- Tipos que @lune/roblox no trae.
	local function tipo(nombre: string, metodos: { [string]: any }?)
		local mt: any = { __tipo = nombre, __tostring = function()
			return nombre
		end }
		mt.__index = metodos or {}
		return mt
	end

	local MT_TWEENINFO = tipo("TweenInfo")
	local TweenInfo = {
		new = function(tiempo: number?, estilo: any?, direccion: any?, repeticiones: number?, vuelve: boolean?, espera: number?)
			return setmetatable({
				Time = tiempo or 1,
				EasingStyle = estilo or Enum.EasingStyle.Quad,
				EasingDirection = direccion or Enum.EasingDirection.Out,
				RepeatCount = repeticiones or 0,
				Reverses = vuelve or false,
				DelayTime = espera or 0,
			}, MT_TWEENINFO)
		end,
	}

	local metodosFiltro = {}
	function metodosFiltro:AddToFilter(cosa)
		local lista = table.clone(self.FilterDescendantsInstances)
		if type(cosa) == "table" and getmetatable(cosa) == nil then -- una lista (una instancia tiene metatabla)
			for _, x in cosa do
				table.insert(lista, x)
			end
		else
			table.insert(lista, cosa)
		end
		self.FilterDescendantsInstances = lista
	end
	local MT_RAYO = tipo("RaycastParams", metodosFiltro)
	local MT_SOLAPE = tipo("OverlapParams", metodosFiltro)
	local RaycastParams = {
		new = function()
			return setmetatable({
				FilterDescendantsInstances = {},
				FilterType = Enum.RaycastFilterType.Exclude,
				IgnoreWater = false,
				CollisionGroup = "Default",
				RespectCanCollide = false,
				BruteForceAllSlow = false,
			}, MT_RAYO)
		end,
	}
	local OverlapParams = {
		new = function()
			return setmetatable({
				FilterDescendantsInstances = {},
				FilterType = Enum.RaycastFilterType.Exclude,
				MaxParts = 0,
				CollisionGroup = "Default",
				RespectCanCollide = false,
				BruteForceAllSlow = false,
			}, MT_SOLAPE)
		end,
	}
	local MT_RESULTADO = tipo("RaycastResult")

	-- Random con semilla (xorshift32): el mismo banco da siempre lo mismo.
	local metodosAzar = {}
	local MT_AZAR = tipo("Random", metodosAzar)
	local semillas = op.semilla or 12345
	local function nuevoAzar(semilla: number?)
		semillas += 1
		local s = math.floor(math.abs(semilla or semillas * 7919)) % 4294967295
		return setmetatable({ s = if s == 0 then 2463534242 else s }, MT_AZAR)
	end
	local function siguiente(r): number
		local x = r.s
		x = bit32.bxor(x, bit32.lshift(x, 13))
		x = bit32.bxor(x, bit32.rshift(x, 17))
		x = bit32.bxor(x, bit32.lshift(x, 5))
		r.s = x
		return x / 4294967296
	end
	function metodosAzar:NextNumber(a: number?, b: number?): number
		local lo, hi = a or 0, b or 1
		return lo + (hi - lo) * siguiente(self)
	end
	function metodosAzar:NextInteger(a: number, b: number): number
		return a + math.floor(siguiente(self) * (b - a + 1))
	end
	function metodosAzar:NextUnitVector(): any
		local z = self:NextNumber(-1, 1)
		local t = self:NextNumber(0, 2 * math.pi)
		local r = math.sqrt(1 - z * z)
		return Vector3.new(r * math.cos(t), r * math.sin(t), z)
	end
	function metodosAzar:Shuffle(t: { any })
		for i = #t, 2, -1 do
			local j = self:NextInteger(1, i)
			t[i], t[j] = t[j], t[i]
		end
	end
	function metodosAzar:Clone()
		return setmetatable({ s = self.s }, MT_AZAR)
	end
	local Random = { new = nuevoAzar }
	local azarMath = nuevoAzar(op.semilla or 777)
	local math2 = table.clone(math)
	function math2.random(a: number?, b: number?): number
		if a == nil then
			return siguiente(azarMath)
		elseif b == nil then
			return azarMath:NextInteger(1, a)
		end
		return azarMath:NextInteger(a, b :: number)
	end
	function math2.randomseed(s: number)
		azarMath = nuevoAzar(s)
	end

	local MT_FECHA = tipo("DateTime", {
		ToUniversalTime = function(self)
			local t = os.date("!*t", math.floor(self.UnixTimestamp)) :: any
			return { Year = t.year, Month = t.month, Day = t.day, Hour = t.hour, Minute = t.min, Second = t.sec,
				Millisecond = self.UnixTimestampMillis % 1000 }
		end,
		ToIsoDate = function(self)
			return os.date("!%Y-%m-%dT%H:%M:%SZ", math.floor(self.UnixTimestamp))
		end,
	})
	local function fecha(ms: number)
		return setmetatable({ UnixTimestampMillis = math.floor(ms), UnixTimestamp = math.floor(ms / 1000) }, MT_FECHA)
	end
	local DateTime = {
		now = function()
			return fecha((EPOCA + ahora) * 1000)
		end,
		fromUnixTimestamp = function(s: number)
			return fecha(s * 1000)
		end,
		fromUnixTimestampMillis = fecha,
	}

	local function typeofFalso(v: any): string
		if type(v) == "table" then
			local mt = getmetatable(v)
			if type(mt) == "table" and rawget(mt, "__tipo") then
				return mt.__tipo
			end
		end
		return typeofNativo(v)
	end

	------------------------------------------------------------------------------------------------------------------
	-- Instancias. Cada una es una tabla vacía con metatabla; su estado vive en `estado[inst]`. Al leer: método, lo
	-- calculado (Position de una pieza...), lo puesto, una señal, el valor por defecto de su clase, un hijo con ese
	-- nombre (o un archivo de src, para los scripts falsos) y si no, nil.
	type Estado = {
		clase: any, nombre: string, padre: any?, hijos: { any }, props: { [string]: any }, attrs: { [string]: any },
		senales: { [string]: any }, cambios: { [string]: any }, cambiosAttr: { [string]: any }, tags: { [string]: boolean },
		destruido: boolean?, archivo: string?, dir: string?, rellenado: boolean?, [string]: any,
	}
	local estado: { [any]: Estado } = {}
	local MT_INST: any = { __tipo = "Instance" }
	local DEF: { [string]: any } = {}
	local planas: { [string]: any } = {}

	local function clase(nombre: string, base: string?, t: { [string]: any }?)
		local d: any = t or {}
		d.nombre, d.base = nombre, base
		DEF[nombre] = d
	end
	local function plana(nombre: string)
		local p = planas[nombre]
		if p then
			return p
		end
		local d = DEF[nombre]
		if not d then
			aviso(`Instance.new("{nombre}"): clase que el mundo falso no conoce (se crea como Instance)`)
			clase(nombre, "Instance")
			d = DEF[nombre]
		end
		p = { nombre = nombre, metodos = {}, get = {}, set = {}, defectos = {}, eventos = {}, esA = {} }
		if d.base then
			local b = plana(d.base)
			for _, campo in { "metodos", "get", "set", "defectos", "eventos", "esA" } do
				for k, v in b[campo] do
					p[campo][k] = v
				end
			end
		end
		p.esA[nombre] = true
		for k, v in d.props or {} do
			p.defectos[k] = v
		end
		for _, campo in { "metodos", "get", "set" } do
			for k, v in d[campo] or {} do
				p[campo][k] = v
			end
		end
		for _, e in d.eventos or {} do
			p.eventos[e] = true
		end
		planas[nombre] = p
		return p
	end

	local partes: { any } = {} -- todas las BasePart (para los rayos)
	local juntas: { any } = {} -- Motor6D, Weld y WeldConstraint
	local sonidos: { any } = {}
	local humanoides: { any } = {}
	local pistas: { any } = {} -- AnimationTrack
	local pantallas: { any } = {} -- ScreenGui
	local REGISTROS = { BasePart = partes, JointInstance = juntas, WeldConstraint = juntas, Sound = sonidos,
		Humanoid = humanoides, AnimationTrack = pistas, ScreenGui = pantallas }

	local function nueva(nombreClase: string): any
		local c = plana(nombreClase)
		local inst = setmetatable({}, MT_INST)
		estado[inst] = { clase = c, nombre = nombreClase, padre = nil, hijos = {}, props = {}, attrs = {}, senales = {},
			cambios = {}, cambiosAttr = {}, tags = {} }
		for base, lista in REGISTROS do
			if c.esA[base] then
				table.insert(lista, inst)
			end
		end
		return inst
	end
	local function esInstancia(v: any): boolean
		return type(v) == "table" and estado[v] ~= nil
	end
	local function senalDe(st: Estado, nombre: string)
		local s = st.senales[nombre]
		if not s then
			s = nuevaSenal()
			st.senales[nombre] = s
		end
		return s
	end
	-- Lo que vale una propiedad (sin hijos ni señales).
	local function leer(inst: any, st: Estado, k: string): any
		local g = st.clase.get[k]
		if g then
			return g(inst, st)
		end
		local v = st.props[k]
		if v ~= nil then
			return if v == NADA then nil else v
		end
		return st.clase.defectos[k]
	end
	local function cambiado(inst: any, st: Estado, prop: string)
		local s = st.cambios[prop]
		if s then
			s:Fire()
		end
		local c = st.senales.Changed
		if c then
			if st.clase.esA.ValueBase and prop == "Value" then
				c:Fire(leer(inst, st, "Value"))
			elseif not st.clase.esA.ValueBase then
				c:Fire(prop)
			end
		end
	end
	local function poner(inst: any, st: Estado, k: string, v: any)
		local viejo = leer(inst, st, k)
		if viejo ~= v or v ~= v then
			st.props[k] = if v == nil then NADA else v
			cambiado(inst, st, k)
		end
	end

	-- Hijos que salen de archivos (scripts falsos): una carpeta de src se rellena la primera vez que se miran sus hijos.
	local nodoArchivo: (nombre: string, ruta: string, padre: any?) -> any?
	local function rellenar(inst: any, st: Estado)
		if not st.dir or st.rellenado then
			return
		end
		st.rellenado = true
		local nombres = CARPETAS[st.dir] or {}
		for _, n in nombres do
			if not string.match(n, "^init%.") and string.sub(n, 1, 1) ~= "." then
				nodoArchivo(n, st.dir .. "/" .. n, inst)
			end
		end
	end
	local function hijosDe(inst: any): { any }
		local st = estado[inst]
		rellenar(inst, st)
		return st.hijos
	end
	local function hijoLlamado(inst: any, nombre: string): any?
		for _, h in hijosDe(inst) do
			if estado[h].nombre == nombre then
				return h
			end
		end
		return nil
	end

	MT_INST.__index = function(inst, k)
		local st = estado[inst]
		local c = st.clase
		local m = c.metodos[k]
		if m then
			return m
		end
		if k == "Parent" then
			return st.padre
		elseif k == "Name" then
			return st.nombre
		elseif k == "ClassName" then
			return c.nombre
		end
		local g = c.get[k]
		if g then
			return g(inst, st)
		end
		local v = st.props[k]
		if v ~= nil then
			return if v == NADA then nil else v
		end
		if c.eventos[k] then
			return senalDe(st, k)
		end
		local d = c.defectos[k]
		if d ~= nil then
			return d
		end
		return hijoLlamado(inst, k)
	end
	local ponerPadre: (inst: any, st: Estado, padre: any?, forzar: boolean?) -> ()
	MT_INST.__newindex = function(inst, k, v)
		local st = estado[inst]
		if k == "Parent" then
			ponerPadre(inst, st, v)
			return
		elseif k == "Name" then
			assert(type(v) == "string", "Name tiene que ser un texto")
			if v ~= st.nombre then
				st.nombre = v
				cambiado(inst, st, "Name")
			end
			return
		end
		local c = st.clase
		if k == "ClassName" or c.metodos[k] or c.eventos[k] then
			error(`no se puede cambiar {k} de {st.nombre}`, 2)
		end
		local s = c.set[k]
		if s then
			s(inst, st, v)
			return
		end
		poner(inst, st, k, v)
	end
	MT_INST.__tostring = function(inst)
		return estado[inst].nombre
	end

	local juego: any -- el DataModel (game)
	local espacio: any -- workspace
	local etiquetadas: { [string]: { any } } = {}
	local senalesEtiqueta: { [string]: { puesta: any, quitada: any } } = {}
	local function senalesDe(tag: string)
		local s = senalesEtiqueta[tag]
		if not s then
			s = { puesta = nuevaSenal(), quitada = nuevaSenal() }
			senalesEtiqueta[tag] = s
		end
		return s
	end
	local function esDescendiente(inst: any, de: any): boolean
		local p = estado[inst].padre
		while p do
			if p == de then
				return true
			end
			p = estado[p].padre
		end
		return false
	end
	local function enJuego(inst: any): boolean
		return inst == juego or (juego ~= nil and esDescendiente(inst, juego))
	end
	local function enEspacio(inst: any): boolean
		return espacio ~= nil and esDescendiente(inst, espacio)
	end
	-- Sin rellenar carpetas de archivos (eso solo al mirarlas: GetChildren, FindFirstChild...).
	local function descendientes(inst: any, lista: { any }?): { any }
		local l = lista or {}
		for _, h in estado[inst].hijos do
			table.insert(l, h)
			descendientes(h, l)
		end
		return l
	end
	local function descendientesRellenos(inst: any, lista: { any }?): { any }
		local l = lista or {}
		for _, h in hijosDe(inst) do
			table.insert(l, h)
			descendientesRellenos(h, l)
		end
		return l
	end
	local function avisarEtiquetas(inst: any, dentro: boolean)
		local todos = descendientes(inst, { inst })
		for _, i in todos do
			for tag in estado[i].tags do
				local s = senalesEtiqueta[tag]
				if s then
					(if dentro then s.puesta else s.quitada):Fire(i)
				end
			end
		end
	end

	ponerPadre = function(inst, st, padre, forzar)
		if st.bloqueado and not forzar then
			error(`The Parent property of {st.nombre} is locked`, 3)
		end
		if padre == st.padre then
			return
		end
		if padre ~= nil then
			assert(esInstancia(padre), "Parent tiene que ser una instancia")
			assert(padre ~= inst and not esDescendiente(padre, inst), `{st.nombre} no puede ser hijo de sí mismo`)
		end
		local estaba = enJuego(inst)
		local viejo = st.padre
		if viejo then
			local sv = estado[viejo]
			local i = table.find(sv.hijos, inst)
			if i then
				table.remove(sv.hijos, i)
			end
			if sv.senales.ChildRemoved then
				sv.senales.ChildRemoved:Fire(inst)
			end
			local a = viejo
			while a do
				local sa = estado[a]
				if sa.senales.DescendantRemoving then
					sa.senales.DescendantRemoving:Fire(inst)
				end
				a = sa.padre
			end
		end
		st.padre = padre
		if padre then
			table.insert(estado[padre].hijos, inst)
		end
		cambiado(inst, st, "Parent")
		for _, i in descendientes(inst, { inst }) do
			local si = estado[i]
			if si.senales.AncestryChanged then
				si.senales.AncestryChanged:Fire(inst, padre)
			end
		end
		if padre then
			local sp = estado[padre]
			if sp.senales.ChildAdded then
				sp.senales.ChildAdded:Fire(inst)
			end
			local todos = descendientes(inst, { inst })
			local a = padre
			while a do
				local sa = estado[a]
				if sa.senales.DescendantAdded then
					for _, i in todos do
						sa.senales.DescendantAdded:Fire(i)
					end
				end
				a = sa.padre
			end
		end
		local esta = enJuego(inst)
		if esta ~= estaba then
			avisarEtiquetas(inst, esta)
		end
	end

	local function apagarSenales(st: Estado)
		for _, s in st.senales do
			s:apagar()
		end
		for _, s in st.cambios do
			s:apagar()
		end
		for _, s in st.cambiosAttr do
			s:apagar()
		end
	end
	local function destruir(inst: any)
		local st = estado[inst]
		if st.destruido then
			return
		end
		st.destruido = true
		if st.senales.Destroying then
			st.senales.Destroying:Fire()
		end
		for _, h in table.clone(st.hijos) do
			destruir(h)
		end
		ponerPadre(inst, st, nil, true)
		st.bloqueado = true
		apagarSenales(st)
		for _, lista in REGISTROS do
			local i = table.find(lista, inst)
			if i then
				table.remove(lista, i)
			end
		end
	end

	local function clonar(inst: any): any?
		local mapa: { [any]: any } = {}
		local function copia(i: any): any?
			local st = estado[i]
			if leer(i, st, "Archivable") == false then
				return nil
			end
			local n = nueva(st.clase.nombre)
			local sn = estado[n]
			sn.nombre = st.nombre
			sn.props = table.clone(st.props)
			sn.attrs = table.clone(st.attrs)
			sn.archivo, sn.dir, sn.rellenado = st.archivo, st.dir, st.rellenado
			for tag in st.tags do
				sn.tags[tag] = true
				table.insert(etiquetadas[tag], n)
			end
			for clave, v in st do -- estado propio de algunas clases (pistas, tweens...)
				if sn[clave] == nil and type(clave) == "string" and string.sub(clave, 1, 1) == "_" then
					sn[clave] = if type(v) == "table" then table.clone(v) else v
				end
			end
			mapa[i] = n
			for _, h in st.hijos do
				local hc = copia(h)
				if hc then
					ponerPadre(hc, estado[hc], n)
				end
			end
			return n
		end
		local raiz = copia(inst)
		for _, n in mapa do -- lo que apunta dentro de lo copiado (Part0, PrimaryPart...) apunta a la copia
			local sn = estado[n]
			for k, v in sn.props do
				if mapa[v] then
					sn.props[k] = mapa[v]
				end
			end
		end
		return raiz
	end

	local TIPOS_ATRIBUTO = { boolean = true, number = true, string = true, Vector3 = true, Vector2 = true, CFrame = true,
		Color3 = true, UDim = true, UDim2 = true, BrickColor = true, NumberRange = true, NumberSequence = true,
		ColorSequence = true, Rect = true, Font = true, EnumItem = true }

	local function claseDe(inst: any, nombre: string, deVerdad: boolean): boolean
		local c = estado[inst].clase
		return if deVerdad then c.esA[nombre] == true else c.nombre == nombre
	end
	local function buscar(inst: any, cumple: (any) -> boolean, recursivo: boolean?): any?
		for _, h in hijosDe(inst) do
			if cumple(h) then
				return h
			end
		end
		if recursivo then
			for _, h in hijosDe(inst) do
				local r = buscar(h, cumple, true)
				if r then
					return r
				end
			end
		end
		return nil
	end
	local function ancestro(inst: any, cumple: (any) -> boolean): any?
		local p = estado[inst].padre
		while p do
			if cumple(p) then
				return p
			end
			p = estado[p].padre
		end
		return nil
	end

	clase("Instance", nil, {
		props = { Archivable = true },
		eventos = { "Changed", "ChildAdded", "ChildRemoved", "DescendantAdded", "DescendantRemoving", "AncestryChanged",
			"AttributeChanged", "Destroying" },
		metodos = {
			IsA = function(self, n)
				return estado[self].clase.esA[n] == true
			end,
			FindFirstChild = function(self, n, recursivo)
				return buscar(self, function(h)
					return estado[h].nombre == n
				end, recursivo)
			end,
			FindFirstChildOfClass = function(self, n)
				return buscar(self, function(h)
					return claseDe(h, n, false)
				end)
			end,
			FindFirstChildWhichIsA = function(self, n, recursivo)
				return buscar(self, function(h)
					return claseDe(h, n, true)
				end, recursivo)
			end,
			FindFirstDescendant = function(self, n)
				return buscar(self, function(h)
					return estado[h].nombre == n
				end, true)
			end,
			FindFirstAncestor = function(self, n)
				return ancestro(self, function(p)
					return estado[p].nombre == n
				end)
			end,
			FindFirstAncestorOfClass = function(self, n)
				return ancestro(self, function(p)
					return claseDe(p, n, false)
				end)
			end,
			FindFirstAncestorWhichIsA = function(self, n)
				return ancestro(self, function(p)
					return claseDe(p, n, true)
				end)
			end,
			WaitForChild = function(self, n, espera)
				local h = hijoLlamado(self, n)
				if h == nil then
					aviso(`WaitForChild("{n}") en {self:GetFullName()}: no está (devuelve nil sin esperar{if espera then "" else "; en Roblox esperaría para siempre"})`)
				end
				return h
			end,
			GetChildren = function(self)
				return table.clone(hijosDe(self))
			end,
			GetDescendants = function(self)
				return descendientesRellenos(self)
			end,
			IsDescendantOf = function(self, de)
				return de ~= nil and esDescendiente(self, de)
			end,
			IsAncestorOf = function(self, de)
				return de ~= nil and esDescendiente(de, self)
			end,
			GetFullName = function(self)
				local trozos = {}
				local i = self
				while i and i ~= juego do
					table.insert(trozos, 1, estado[i].nombre)
					i = estado[i].padre
				end
				return table.concat(trozos, ".")
			end,
			Destroy = destruir,
			Remove = function(self)
				self.Parent = nil
			end,
			ClearAllChildren = function(self)
				for _, h in table.clone(estado[self].hijos) do
					destruir(h)
				end
			end,
			Clone = clonar,
			SetAttribute = function(self, n, v)
				assert(type(n) == "string", "SetAttribute: el nombre tiene que ser un texto")
				assert(v == nil or TIPOS_ATRIBUTO[typeofFalso(v)], `SetAttribute("{n}"): tipo no válido ({typeofFalso(v)})`)
				local st = estado[self]
				if st.attrs[n] == v and v == v then
					return
				end
				st.attrs[n] = v
				if st.senales.AttributeChanged then
					st.senales.AttributeChanged:Fire(n)
				end
				local s = st.cambiosAttr[n]
				if s then
					s:Fire()
				end
			end,
			GetAttribute = function(self, n)
				return estado[self].attrs[n]
			end,
			GetAttributes = function(self)
				return table.clone(estado[self].attrs)
			end,
			GetAttributeChangedSignal = function(self, n)
				local st = estado[self]
				local s = st.cambiosAttr[n]
				if not s then
					s = nuevaSenal()
					st.cambiosAttr[n] = s
				end
				return s
			end,
			GetPropertyChangedSignal = function(self, p)
				local st = estado[self]
				local s = st.cambios[p]
				if not s then
					s = nuevaSenal()
					st.cambios[p] = s
				end
				return s
			end,
			AddTag = function(self, tag)
				local st = estado[self]
				if st.tags[tag] then
					return
				end
				st.tags[tag] = true
				etiquetadas[tag] = etiquetadas[tag] or {}
				table.insert(etiquetadas[tag], self)
				if enJuego(self) and senalesEtiqueta[tag] then
					senalesEtiqueta[tag].puesta:Fire(self)
				end
			end,
			RemoveTag = function(self, tag)
				local st = estado[self]
				if not st.tags[tag] then
					return
				end
				st.tags[tag] = nil
				local i = table.find(etiquetadas[tag], self)
				if i then
					table.remove(etiquetadas[tag], i)
				end
				if enJuego(self) and senalesEtiqueta[tag] then
					senalesEtiqueta[tag].quitada:Fire(self)
				end
			end,
			HasTag = function(self, tag)
				return estado[self].tags[tag] == true
			end,
			GetTags = function(self)
				local l = {}
				for tag in estado[self].tags do
					table.insert(l, tag)
				end
				table.sort(l)
				return l
			end,
			GetActor = function()
				return nil
			end,
		},
	})
	clase("Folder", "Instance")
	clase("Configuration", "Instance")
	clase("LuaSourceContainer", "Instance")
	clase("ModuleScript", "LuaSourceContainer")
	clase("BaseScript", "LuaSourceContainer", { props = { Enabled = true, Disabled = false } })
	clase("Script", "BaseScript")
	clase("LocalScript", "Script")

	------------------------------------------------------------------------------------------------------------------
	-- Piezas: CFrame es lo que se guarda; Position, Orientation y Rotation salen de él.
	local CF0 = CFrame.new()
	local function grados(cf: any): any
		local x, y, z = cf:ToOrientation()
		return Vector3.new(math.deg(x), math.deg(y), math.deg(z))
	end
	local function desdeGrados(pos: any, o: any): any
		return CFrame.new(pos) * CFrame.fromOrientation(math.rad(o.X), math.rad(o.Y), math.rad(o.Z))
	end
	local function ponerCF(inst: any, st: Estado, cf: any)
		local viejo = leer(inst, st, "CFrame")
		if viejo == cf then
			return
		end
		st.props.CFrame = cf
		cambiado(inst, st, "CFrame")
		if st.cambios.Position or st.senales.Changed then
			cambiado(inst, st, "Position")
		end
		if st.cambios.Orientation or st.senales.Changed then
			cambiado(inst, st, "Orientation")
		end
	end
	clase("PVInstance", "Instance", {
		props = { PivotOffset = CF0 },
		metodos = {
			GetPivot = function(self)
				return self.CFrame * self.PivotOffset
			end,
			PivotTo = function(self, cf)
				self.CFrame = cf * self.PivotOffset:Inverse()
			end,
		},
	})
	local GRIS = Color3.fromRGB(163, 162, 165)
	clase("BasePart", "PVInstance", {
		props = { CFrame = CF0, Size = Vector3.new(4, 1, 2), Anchored = false, CanCollide = true, CanQuery = true,
			CanTouch = true, Transparency = 0, LocalTransparencyModifier = 0, Color = GRIS, Material = Enum.Material.Plastic,
			MaterialVariant = "", Reflectance = 0, CastShadow = true, Massless = false, Locked = false,
			CollisionGroup = "Default", AssemblyLinearVelocity = Vector3.zero, AssemblyAngularVelocity = Vector3.zero,
			TopSurface = Enum.SurfaceType.Smooth, BottomSurface = Enum.SurfaceType.Smooth, RootPriority = 0,
			EnableFluidForces = true, AudioCanCollide = true },
		eventos = { "Touched", "TouchEnded" },
		get = {
			Position = function(_, st)
				return (st.props.CFrame or CF0).Position
			end,
			Orientation = function(_, st)
				return grados(st.props.CFrame or CF0)
			end,
			Rotation = function(_, st)
				return grados(st.props.CFrame or CF0)
			end,
			BrickColor = function(inst, st)
				return roblox.BrickColor.new(leer(inst, st, "Color"))
			end,
			Mass = function(inst, st)
				local s = leer(inst, st, "Size")
				return s.X * s.Y * s.Z * 0.7
			end,
			AssemblyMass = function(inst, st)
				local s = leer(inst, st, "Size")
				return s.X * s.Y * s.Z * 0.7
			end,
			ExtentsCFrame = function(_, st)
				return st.props.CFrame or CF0
			end,
		},
		set = {
			CFrame = ponerCF,
			Position = function(inst, st, v)
				local cf = st.props.CFrame or CF0
				ponerCF(inst, st, cf.Rotation + v)
			end,
			Orientation = function(inst, st, v)
				ponerCF(inst, st, desdeGrados((st.props.CFrame or CF0).Position, v))
			end,
			Rotation = function(inst, st, v)
				ponerCF(inst, st, desdeGrados((st.props.CFrame or CF0).Position, v))
			end,
			BrickColor = function(inst, st, v)
				poner(inst, st, "Color", v.Color)
			end,
		},
		metodos = {
			GetMass = function(self)
				return self.Mass
			end,
			ApplyImpulse = function() end,
			ApplyAngularImpulse = function() end,
			SetNetworkOwner = function() end,
			GetNetworkOwner = function()
				return nil
			end,
			CanSetNetworkOwnership = function()
				return true, nil
			end,
			GetTouchingParts = function()
				return {}
			end,
			GetConnectedParts = function(self)
				return { self }
			end,
			GetJoints = function()
				return {}
			end,
			GetRootPart = function(self)
				return self
			end,
			IsGrounded = function(self)
				return self.Anchored
			end,
			BreakJoints = function() end,
			GetVelocityAtPosition = function(self)
				return self.AssemblyLinearVelocity
			end,
			CanCollideWith = function(self, otra)
				return self.CanCollide and otra.CanCollide
			end,
		},
	})
	clase("FormFactorPart", "BasePart")
	clase("Part", "FormFactorPart", { props = { Shape = Enum.PartType.Block } })
	clase("WedgePart", "FormFactorPart")
	clase("CornerWedgePart", "BasePart")
	clase("TrussPart", "BasePart")
	clase("MeshPart", "BasePart", { props = { MeshId = "", TextureID = "", DoubleSided = false,
		RenderFidelity = Enum.RenderFidelity.Automatic, CollisionFidelity = Enum.CollisionFidelity.Default } })
	clase("PartOperation", "BasePart", { props = { UsePartColor = false } })
	clase("UnionOperation", "PartOperation")
	clase("SpawnLocation", "Part", { props = { Enabled = true, Neutral = true, Duration = 10 } })
	clase("Seat", "Part", { props = { Disabled = false, Occupant = nil } })
	clase("VehicleSeat", "BasePart", { props = { Disabled = false, Throttle = 0, Steer = 0, MaxSpeed = 25 } })
	clase("Terrain", "BasePart", { props = { Anchored = true, CanQuery = false, WaterWaveSize = 0.15 },
		metodos = { FillBlock = function() end, FillBall = function() end, Clear = function() end,
			FillRegion = function() end, ReplaceMaterial = function() end } })

	-- Modelos: el pivote es PrimaryPart, o WorldPivot si se ha puesto, o el centro de la caja de sus piezas.
	local function piezasDe(inst: any): { any }
		local l = {}
		for _, d in descendientes(inst) do
			if estado[d].clase.esA.BasePart then
				table.insert(l, d)
			end
		end
		return l
	end
	local function cajaDe(lista: { any }, giro: any): (any, any)
		local bajo, alto = Vector3.one * INFINITO, -Vector3.one * INFINITO
		for _, p in lista do
			local cf, m = p.CFrame, p.Size / 2
			for _, s in { Vector3.new(1, 1, 1), Vector3.new(1, 1, -1), Vector3.new(1, -1, 1), Vector3.new(1, -1, -1),
				Vector3.new(-1, 1, 1), Vector3.new(-1, 1, -1), Vector3.new(-1, -1, 1), Vector3.new(-1, -1, -1) } do
				local q = giro:PointToObjectSpace(cf:PointToWorldSpace(m * s))
				bajo, alto = bajo:Min(q), alto:Max(q)
			end
		end
		if #lista == 0 then
			return giro, Vector3.zero
		end
		return giro * CFrame.new((bajo + alto) / 2), alto - bajo
	end
	local function pivoteModelo(inst: any, st: Estado): any
		local pp = st.props.PrimaryPart
		if pp and pp ~= NADA and esDescendiente(pp, inst) then
			return pp:GetPivot()
		end
		if st.props.WorldPivot then
			return st.props.WorldPivot
		end
		local lista = piezasDe(inst)
		if #lista == 0 then
			return CF0
		end
		local cf = cajaDe(lista, CF0)
		return cf
	end
	local function moverModelo(inst: any, cf: any)
		local st = estado[inst]
		local antes = pivoteModelo(inst, st)
		for _, p in piezasDe(inst) do
			p.CFrame = cf * antes:ToObjectSpace(p.CFrame)
		end
		local pp = st.props.PrimaryPart
		if not (pp and pp ~= NADA) then
			st.props.WorldPivot = cf
		end
	end
	clase("Model", "PVInstance", {
		props = { LevelOfDetail = Enum.ModelLevelOfDetail.Automatic, ModelStreamingMode = Enum.ModelStreamingMode.Default },
		get = { WorldPivot = pivoteModelo },
		set = { WorldPivot = function(_, st, v)
			st.props.WorldPivot = v
		end },
		metodos = {
			GetPivot = function(self)
				return pivoteModelo(self, estado[self])
			end,
			PivotTo = moverModelo,
			GetBoundingBox = function(self)
				return cajaDe(piezasDe(self), pivoteModelo(self, estado[self]).Rotation)
			end,
			GetExtentsSize = function(self)
				local _, tam = cajaDe(piezasDe(self), pivoteModelo(self, estado[self]).Rotation)
				return tam
			end,
			MoveTo = function(self, pos)
				moverModelo(self, pivoteModelo(self, estado[self]).Rotation + pos)
			end,
			TranslateBy = function(self, v)
				moverModelo(self, pivoteModelo(self, estado[self]) + v)
			end,
			SetPrimaryPartCFrame = function(self, cf)
				local pp = assert(self.PrimaryPart, "SetPrimaryPartCFrame sin PrimaryPart")
				local antes = pp.CFrame
				for _, p in piezasDe(self) do
					p.CFrame = cf * antes:ToObjectSpace(p.CFrame)
				end
			end,
			GetPrimaryPartCFrame = function(self)
				return assert(self.PrimaryPart, "GetPrimaryPartCFrame sin PrimaryPart").CFrame
			end,
			GetScale = function(self)
				return estado[self]._escala or 1
			end,
			ScaleTo = function(self, s)
				local st = estado[self]
				local f = s / (st._escala or 1)
				local piv = pivoteModelo(self, st)
				for _, p in piezasDe(self) do
					local rel = piv:ToObjectSpace(p.CFrame)
					p.Size *= f
					p.CFrame = piv * (rel.Rotation + rel.Position * f)
				end
				st._escala = s
			end,
		},
	})
	clase("Actor", "Model")
	clase("WorldModel", "Model")

	clase("Attachment", "Instance", {
		props = { CFrame = CF0, Visible = false },
		get = {
			Position = function(_, st)
				return (st.props.CFrame or CF0).Position
			end,
			Orientation = function(_, st)
				return grados(st.props.CFrame or CF0)
			end,
			Axis = function(_, st)
				return (st.props.CFrame or CF0).XVector
			end,
			SecondaryAxis = function(_, st)
				return (st.props.CFrame or CF0).YVector
			end,
			WorldCFrame = function(inst, st)
				local p = st.padre
				local base = if p and estado[p].clase.esA.BasePart then p.CFrame
					elseif p and estado[p].clase.esA.Attachment then p.WorldCFrame
					else CF0
				return base * leer(inst, st, "CFrame")
			end,
			WorldPosition = function(inst)
				return inst.WorldCFrame.Position
			end,
			WorldOrientation = function(inst)
				return grados(inst.WorldCFrame)
			end,
		},
		set = {
			Position = function(inst, st, v)
				poner(inst, st, "CFrame", (st.props.CFrame or CF0).Rotation + v)
			end,
			Orientation = function(inst, st, v)
				poner(inst, st, "CFrame", desdeGrados((st.props.CFrame or CF0).Position, v))
			end,
			WorldCFrame = function(inst, st, v)
				local base = inst.WorldCFrame * leer(inst, st, "CFrame"):Inverse()
				poner(inst, st, "CFrame", base:ToObjectSpace(v))
			end,
			WorldPosition = function(inst, _, v)
				inst.WorldCFrame = inst.WorldCFrame.Rotation + v
			end,
		},
	})
	clase("Bone", "Attachment", { props = { Transform = CF0 } })

	clase("JointInstance", "Instance", { props = { C0 = CF0, C1 = CF0, Enabled = true, Active = true } })
	clase("Motor", "JointInstance", { props = { CurrentAngle = 0, DesiredAngle = 0, MaxVelocity = 0 } })
	clase("Motor6D", "Motor", { props = { Transform = CF0 } })
	clase("Weld", "JointInstance")
	clase("ManualWeld", "JointInstance")
	clase("Snap", "JointInstance")
	clase("WeldConstraint", "Instance", { props = { Enabled = true } })
	clase("Constraint", "Instance", { props = { Enabled = true, Visible = false } })
	for _, n in { "NoCollisionConstraint", "RigidConstraint", "AlignPosition", "AlignOrientation", "LinearVelocity",
		"AngularVelocity", "VectorForce", "RopeConstraint", "SpringConstraint", "HingeConstraint", "BallSocketConstraint" } do
		clase(n, "Constraint")
	end
	for _, n in { "BodyVelocity", "BodyGyro", "BodyPosition", "BodyForce", "BodyAngularVelocity" } do
		clase(n, "Instance")
	end

	------------------------------------------------------------------------------------------------------------------
	-- Lo que se ve y suena (sin dibujar nada: solo guardan sus propiedades).
	local BLANCO = Color3.new(1, 1, 1)
	clase("Light", "Instance", { props = { Brightness = 1, Color = BLANCO, Enabled = true, Shadows = false } })
	clase("PointLight", "Light", { props = { Range = 8 } })
	clase("SpotLight", "Light", { props = { Range = 16, Angle = 90, Face = Enum.NormalId.Front } })
	clase("SurfaceLight", "Light", { props = { Range = 16, Angle = 90, Face = Enum.NormalId.Front } })
	clase("ParticleEmitter", "Instance", {
		props = { Enabled = true, Rate = 20, Lifetime = NumberRange.new(5, 10), Speed = NumberRange.new(5),
			Size = NumberSequence.new(1), Transparency = NumberSequence.new(0), Color = ColorSequence.new(BLANCO),
			LightEmission = 0, LightInfluence = 0, Texture = "rbxasset://textures/particles/sparkles_main.dds",
			SpreadAngle = Vector2.zero, Rotation = NumberRange.new(0), RotSpeed = NumberRange.new(0),
			Acceleration = Vector3.zero, Drag = 0, EmissionDirection = Enum.NormalId.Top, LockedToPart = false,
			ZOffset = 0, Brightness = 1, TimeScale = 1, Squash = NumberSequence.new(0) },
		metodos = {
			Emit = function(self, n)
				local st = estado[self]
				st._emitidas = (st._emitidas or 0) + (n or 16)
			end,
			Clear = function() end,
		},
	})
	clase("Beam", "Instance", { props = { Enabled = true, Color = ColorSequence.new(BLANCO),
		Transparency = NumberSequence.new(0.5), Width0 = 1, Width1 = 1, FaceCamera = false, Segments = 10,
		CurveSize0 = 0, CurveSize1 = 0, LightEmission = 0, LightInfluence = 0, Texture = "", TextureLength = 1,
		TextureSpeed = 1, Brightness = 1, ZOffset = 0 } })
	clase("Trail", "Instance", { props = { Enabled = true, Color = ColorSequence.new(BLANCO),
		Transparency = NumberSequence.new(0.5), Lifetime = 2, MinLength = 0.1, MaxLength = 0, WidthScale = NumberSequence.new(1),
		FaceCamera = false, LightEmission = 0, Texture = "" }, metodos = { Clear = function() end } })
	for _, n in { "Fire", "Smoke", "Sparkles" } do
		clase(n, "Instance", { props = { Enabled = true } })
	end
	clase("Highlight", "Instance", { props = { Enabled = true, FillColor = Color3.new(1, 0, 0), FillTransparency = 0.5,
		OutlineColor = BLANCO, OutlineTransparency = 0, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop } })
	clase("FaceInstance", "Instance", { props = { Face = Enum.NormalId.Front } })
	clase("Decal", "FaceInstance", { props = { Texture = "", Transparency = 0, Color3 = BLANCO, ZIndex = 1 } })
	clase("Texture", "Decal", { props = { StudsPerTileU = 2, StudsPerTileV = 2, OffsetStudsU = 0, OffsetStudsV = 0 } })
	clase("SurfaceAppearance", "Instance", { props = { Color = BLANCO } })
	clase("DataModelMesh", "Instance", { props = { Scale = Vector3.one, Offset = Vector3.zero, VertexColor = Vector3.one } })
	clase("SpecialMesh", "DataModelMesh", { props = { MeshType = Enum.MeshType.Head, MeshId = "", TextureId = "" } })
	clase("BlockMesh", "DataModelMesh")
	clase("SelectionBox", "Instance", { props = { Visible = true, Color3 = Color3.fromRGB(13, 105, 172), LineThickness = 0.15,
		Transparency = 0, SurfaceTransparency = 1 } })
	clase("ClickDetector", "Instance", { props = { MaxActivationDistance = 32, CursorIcon = "" },
		eventos = { "MouseClick", "MouseHoverEnter", "MouseHoverLeave", "RightMouseClick" } })
	clase("ProximityPrompt", "Instance", {
		props = { ActionText = "Interact", ObjectText = "", HoldDuration = 0, KeyboardKeyCode = Enum.KeyCode.E,
			GamepadKeyCode = Enum.KeyCode.ButtonX, MaxActivationDistance = 10, Enabled = true, RequiresLineOfSight = true,
			Style = Enum.ProximityPromptStyle.Default, UIOffset = Vector2.zero, ClickablePrompt = true, AutoLocalize = true,
			Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton },
		eventos = { "Triggered", "TriggerEnded", "PromptShown", "PromptHidden", "PromptButtonHoldBegan",
			"PromptButtonHoldEnded" },
		metodos = { InputHoldBegin = function() end, InputHoldEnd = function() end },
	})

	clase("Sound", "Instance", {
		props = { SoundId = "", Volume = 0.5, PlaybackSpeed = 1, Looped = false, Playing = false, TimePosition = 0,
			IsLoaded = true, PlayOnRemove = false, RollOffMaxDistance = 10000, RollOffMinDistance = 10,
			RollOffMode = Enum.RollOffMode.Inverse, PlaybackLoudness = 0, SoundGroup = nil, PlaybackRegionsEnabled = false },
		eventos = { "Played", "Paused", "Resumed", "Stopped", "Ended", "DidLoop", "Loaded" },
		get = {
			IsPlaying = function(inst, st)
				return leer(inst, st, "Playing") == true
			end,
			IsPaused = function(inst, st)
				return leer(inst, st, "Playing") ~= true
			end,
			-- Lo que dura: 1 s si tiene SoundId (o lo que se le ponga a mano en TimeLength).
			TimeLength = function(inst, st)
				local v = st.props.TimeLength
				if v ~= nil then
					return v
				end
				return if leer(inst, st, "SoundId") ~= "" then 1 else 0
			end,
		},
		set = { TimeLength = function(_, st, v)
			st.props.TimeLength = v
		end },
		metodos = {
			Play = function(self)
				local st = estado[self]
				poner(self, st, "TimePosition", 0)
				poner(self, st, "Playing", true)
				senalDe(st, "Played"):Fire(leer(self, st, "SoundId"))
			end,
			Stop = function(self)
				local st = estado[self]
				poner(self, st, "Playing", false)
				poner(self, st, "TimePosition", 0)
				senalDe(st, "Stopped"):Fire(leer(self, st, "SoundId"))
			end,
			Pause = function(self)
				poner(self, estado[self], "Playing", false)
			end,
			Resume = function(self)
				poner(self, estado[self], "Playing", true)
			end,
		},
	})
	clase("SoundGroup", "Instance", { props = { Volume = 0.5 } })
	clase("SoundEffect", "Instance", { props = { Enabled = true, Priority = 0 } })
	for _, n in { "ReverbSoundEffect", "EqualizerSoundEffect", "PitchShiftSoundEffect", "DistortionSoundEffect",
		"EchoSoundEffect", "ChorusSoundEffect", "CompressorSoundEffect", "TremoloSoundEffect", "FlangeSoundEffect" } do
		clase(n, "SoundEffect")
	end

	clase("PostEffect", "Instance", { props = { Enabled = true } })
	clase("ColorCorrectionEffect", "PostEffect", { props = { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = BLANCO } })
	clase("BlurEffect", "PostEffect", { props = { Size = 24 } })
	clase("BloomEffect", "PostEffect", { props = { Intensity = 1, Size = 24, Threshold = 2 } })
	clase("DepthOfFieldEffect", "PostEffect", { props = { FarIntensity = 0.75, FocusDistance = 0.05, InFocusRadius = 10,
		NearIntensity = 0.75 } })
	clase("SunRaysEffect", "PostEffect", { props = { Intensity = 0.25, Spread = 1 } })
	clase("Atmosphere", "Instance", { props = { Density = 0.3, Offset = 0, Color = Color3.fromRGB(199, 199, 199),
		Decay = Color3.fromRGB(106, 112, 125), Glare = 0, Haze = 0 } })
	clase("Sky", "Instance", { props = { StarCount = 3000, CelestialBodiesShown = true } })
	clase("Clouds", "Instance", { props = { Cover = 0.5, Density = 0.7, Enabled = true, Color = BLANCO } })

	-- Valores, eventos y remotos.
	clase("ValueBase", "Instance")
	for n, v in { StringValue = "", NumberValue = 0, IntValue = 0, BoolValue = false, Vector3Value = Vector3.zero,
		CFrameValue = CF0, Color3Value = Color3.new() } do
		clase(n, "ValueBase", { props = { Value = v } })
	end
	clase("ObjectValue", "ValueBase")
	clase("BindableEvent", "Instance", { eventos = { "Event" }, metodos = { Fire = function(self, ...)
		senalDe(estado[self], "Event"):Fire(...)
	end } })
	clase("BindableFunction", "Instance", { metodos = { Invoke = function(self, ...)
		local f = estado[self].props.OnInvoke
		assert(type(f) == "function", "BindableFunction sin OnInvoke")
		return f(...)
	end } })
	local jugadorLocal: any
	local red: { () -> () } = {} -- lo que llega al servidor en el próximo paso
	local function apuntar(remoto: any, quien: string, ...)
		local st = estado[remoto]
		st._enviados = st._enviados or {}
		local p = table.pack(...)
		p.quien = quien
		table.insert(st._enviados, p)
		return p
	end
	clase("BaseRemoteEvent", "Instance", {
		eventos = { "OnClientEvent", "OnServerEvent" },
		metodos = {
			FireServer = function(self, ...)
				local args = apuntar(self, "servidor", ...)
				table.insert(red, function()
					senalDe(estado[self], "OnServerEvent"):Fire(jugadorLocal, table.unpack(args, 1, args.n))
				end)
			end,
			FireClient = function(self, jugador, ...)
				apuntar(self, jugador and jugador.Name or "?", ...)
			end,
			FireAllClients = function(self, ...)
				apuntar(self, "todos", ...)
			end,
		},
	})
	clase("RemoteEvent", "BaseRemoteEvent")
	clase("UnreliableRemoteEvent", "BaseRemoteEvent")
	clase("RemoteFunction", "Instance", { metodos = {
		InvokeServer = function(self, ...)
			apuntar(self, "servidor", ...)
			local f = estado[self].props.OnServerInvoke
			if type(f) == "function" then
				return f(jugadorLocal, ...)
			end
			return nil
		end,
		InvokeClient = function(self, jugador, ...)
			apuntar(self, jugador and jugador.Name or "?", ...)
			local f = estado[self].props.OnClientInvoke
			if type(f) == "function" then
				return f(...)
			end
			return nil
		end,
	} })

	------------------------------------------------------------------------------------------------------------------
	-- Interfaz. AbsoluteSize y AbsolutePosition se calculan al leerlos con Size, Position y AnchorPoint (sin UIScale,
	-- layouts ni UIPadding). La pantalla es la ViewportSize de la cámara; arriba, la barra de Roblox (58 px) salvo con
	-- IgnoreGuiInset o ScreenInsets None; DeviceSafeInsets quita los márgenes del teléfono (mundo.pantalla).
	local BARRA = 58
	local margenes = { arriba = 0, abajo = 0, izquierda = 0, derecha = 0 }
	local camara: any
	local function rectGui(inst: any): (any, any)
		local st = estado[inst]
		local c = st.clase
		if c.esA.ScreenGui then
			local vp = if camara then camara.ViewportSize else Vector2.new(1280, 720)
			local dentro = st.padre ~= nil and estado[st.padre].clase.esA.PlayerGui
			if not dentro then
				return Vector2.zero, Vector2.zero
			end
			local insets = leer(inst, st, "ScreenInsets")
			if leer(inst, st, "IgnoreGuiInset") or insets == Enum.ScreenInsets.None then
				return Vector2.zero, vp
			end
			local arriba = margenes.arriba
			if insets == Enum.ScreenInsets.CoreUISafeInsets then
				arriba = math.max(arriba, BARRA)
			end
			local pos = Vector2.new(margenes.izquierda, arriba)
			return pos, Vector2.new(vp.X - margenes.izquierda - margenes.derecha, vp.Y - arriba - margenes.abajo)
		elseif c.esA.LayerCollector then -- BillboardGui y SurfaceGui: solo la parte en píxeles
			local s = leer(inst, st, "Size") or UDim2.new()
			return Vector2.zero, Vector2.new(s.X.Offset, s.Y.Offset)
		end
		local p = st.padre
		local ppos, ptam = Vector2.zero, Vector2.zero
		if p and estado[p].clase.esA.GuiBase2d then
			ppos, ptam = rectGui(p)
		end
		local s, q, a = leer(inst, st, "Size"), leer(inst, st, "Position"), leer(inst, st, "AnchorPoint")
		local tam = Vector2.new(ptam.X * s.X.Scale + s.X.Offset, ptam.Y * s.Y.Scale + s.Y.Offset)
		local pos = ppos + Vector2.new(ptam.X * q.X.Scale + q.X.Offset, ptam.Y * q.Y.Scale + q.Y.Offset) - a * tam
		return pos, tam
	end
	local function medirTexto(texto: string, tam: number, ancho: number?): any
		local largo = (utf8.len(texto) or #texto) * tam * 0.5
		if ancho and ancho > 0 and largo > ancho then
			return Vector2.new(ancho, tam * math.ceil(largo / ancho))
		end
		return Vector2.new(largo, tam)
	end
	clase("GuiBase", "Instance")
	clase("GuiBase2d", "GuiBase", {
		props = { AutoLocalize = true, SelectionGroup = false },
		get = {
			AbsolutePosition = function(inst)
				return (rectGui(inst))
			end,
			AbsoluteSize = function(inst)
				local _, tam = rectGui(inst)
				return tam
			end,
			AbsoluteRotation = function(inst, st)
				return leer(inst, st, "Rotation") or 0
			end,
		},
	})
	clase("LayerCollector", "GuiBase2d", { props = { Enabled = true, ResetOnSpawn = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling } })
	clase("ScreenGui", "LayerCollector", { props = { IgnoreGuiInset = false, DisplayOrder = 0,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets, ClipToDeviceSafeArea = true } })
	clase("BillboardGui", "LayerCollector", { props = { Size = UDim2.new(), StudsOffset = Vector3.zero,
		StudsOffsetWorldSpace = Vector3.zero, ExtentsOffset = Vector3.zero, AlwaysOnTop = false, MaxDistance = INFINITO,
		LightInfluence = 1, Brightness = 1, ClipsDescendants = false, SizeOffset = Vector2.zero } })
	clase("SurfaceGui", "LayerCollector", { props = { Face = Enum.NormalId.Front, CanvasSize = Vector2.new(800, 600),
		SizingMode = Enum.SurfaceGuiSizingMode.FixedSize, PixelsPerStud = 50, AlwaysOnTop = false, LightInfluence = 1,
		Brightness = 1 } })
	clase("GuiObject", "GuiBase2d", {
		props = { Size = UDim2.fromOffset(100, 100), Position = UDim2.new(), AnchorPoint = Vector2.zero, Visible = true,
			BackgroundColor3 = Color3.fromRGB(163, 162, 165), BackgroundTransparency = 0, BorderColor3 = Color3.fromRGB(27, 42, 53),
			BorderSizePixel = 1, BorderMode = Enum.BorderMode.Outline, ZIndex = 1, LayoutOrder = 0, Rotation = 0,
			ClipsDescendants = false, Active = false, Selectable = false, AutomaticSize = Enum.AutomaticSize.None,
			SizeConstraint = Enum.SizeConstraint.RelativeXY, Interactable = true },
		eventos = { "InputBegan", "InputEnded", "InputChanged", "MouseEnter", "MouseLeave", "MouseMoved",
			"MouseWheelForward", "MouseWheelBackward", "TouchTap", "TouchLongPress", "TouchPan", "TouchPinch",
			"SelectionGained", "SelectionLost" },
	})
	clase("Frame", "GuiObject", { props = { Style = Enum.FrameStyle.Custom } })
	clase("CanvasGroup", "GuiObject", { props = { GroupTransparency = 0, GroupColor3 = BLANCO } })
	clase("ScrollingFrame", "GuiObject", { props = { CanvasSize = UDim2.new(0, 0, 2, 0), CanvasPosition = Vector2.zero,
		ScrollBarThickness = 12, ScrollingEnabled = true, ScrollingDirection = Enum.ScrollingDirection.XY,
		AutomaticCanvasSize = Enum.AutomaticSize.None, ScrollBarImageColor3 = BLANCO, ScrollBarImageTransparency = 0 } })
	clase("ViewportFrame", "GuiObject", { props = { Ambient = Color3.fromRGB(200, 200, 200), LightColor = Color3.fromRGB(140, 140, 140),
		LightDirection = Vector3.new(-1, -1, -1), ImageColor3 = BLANCO, ImageTransparency = 0 } })
	clase("VideoFrame", "GuiObject", { props = { Video = "", Playing = false, Looped = false, Volume = 1 } })
	local TEXTO = { Text = "Label", TextColor3 = Color3.fromRGB(27, 42, 53), TextSize = 14, TextTransparency = 0,
		TextStrokeColor3 = Color3.new(), TextStrokeTransparency = 1, TextScaled = false, TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, RichText = false,
		Font = Enum.Font.Legacy, FontFace = Font.new("rbxasset://fonts/families/LegacyArial.json"), LineHeight = 1,
		MaxVisibleGraphemes = -1, TextTruncate = Enum.TextTruncate.None, TextFits = true }
	local function getTexto()
		return {
			TextBounds = function(inst, st)
				local _, tam = rectGui(inst)
				return medirTexto(tostring(leer(inst, st, "Text")), leer(inst, st, "TextSize"),
					if leer(inst, st, "TextWrapped") then tam.X else nil)
			end,
			ContentText = function(inst, st)
				return leer(inst, st, "Text")
			end,
		}
	end
	local function conTexto(extra: { [string]: any }): { [string]: any }
		local t = table.clone(TEXTO)
		for k, v in extra do
			t[k] = v
		end
		return t
	end
	clase("TextLabel", "GuiObject", { props = TEXTO, get = getTexto() })
	clase("GuiButton", "GuiObject", {
		props = { AutoButtonColor = true, Modal = false, Selected = false, Active = true },
		eventos = { "MouseButton1Click", "MouseButton1Down", "MouseButton1Up", "MouseButton2Click", "MouseButton2Down",
			"MouseButton2Up", "Activated" },
	})
	clase("TextButton", "GuiButton", { props = conTexto({ Text = "Button" }), get = getTexto() })
	local IMAGEN = { Image = "", ImageColor3 = BLANCO, ImageTransparency = 0, ScaleType = Enum.ScaleType.Stretch,
		ImageRectOffset = Vector2.zero, ImageRectSize = Vector2.zero, SliceCenter = roblox.Rect.new(0, 0, 0, 0),
		SliceScale = 1, TileSize = UDim2.fromScale(1, 1), ResampleMode = Enum.ResamplerMode.Default, IsLoaded = true }
	clase("ImageLabel", "GuiObject", { props = IMAGEN })
	clase("ImageButton", "GuiButton", { props = IMAGEN })
	clase("TextBox", "GuiObject", {
		props = conTexto({ Text = "", PlaceholderText = "", PlaceholderColor3 = Color3.fromRGB(178, 178, 178),
			ClearTextOnFocus = true, MultiLine = false, TextEditable = true, CursorPosition = 1 }),
		get = getTexto(),
		eventos = { "FocusLost", "Focused", "ReturnPressedFromOnScreenKeyboard" },
		metodos = {
			CaptureFocus = function(self)
				estado[self]._foco = true
				senalDe(estado[self], "Focused"):Fire()
			end,
			ReleaseFocus = function(self, enter)
				estado[self]._foco = false
				senalDe(estado[self], "FocusLost"):Fire(enter == true, nil)
			end,
			IsFocused = function(self)
				return estado[self]._foco == true
			end,
		},
	})
	clase("UIBase", "Instance")
	clase("UIComponent", "UIBase")
	clase("UIScale", "UIComponent", { props = { Scale = 1 } })
	clase("UIStroke", "UIComponent", { props = { Thickness = 1, Color = Color3.new(), Transparency = 0, Enabled = true,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, LineJoinMode = Enum.LineJoinMode.Round } })
	clase("UICorner", "UIComponent", { props = { CornerRadius = UDim.new(0, 8) } })
	clase("UIGradient", "UIComponent", { props = { Color = ColorSequence.new(BLANCO), Transparency = NumberSequence.new(0),
		Rotation = 0, Offset = Vector2.zero, Enabled = true } })
	clase("UIPadding", "UIComponent", { props = { PaddingTop = UDim.new(), PaddingBottom = UDim.new(),
		PaddingLeft = UDim.new(), PaddingRight = UDim.new() } })
	clase("UIConstraint", "UIComponent")
	clase("UITextSizeConstraint", "UIConstraint", { props = { MaxTextSize = 100, MinTextSize = 1 } })
	clase("UIAspectRatioConstraint", "UIConstraint", { props = { AspectRatio = 1,
		AspectType = Enum.AspectType.FitWithinMaxSize, DominantAxis = Enum.DominantAxis.Width } })
	clase("UISizeConstraint", "UIConstraint", { props = { MinSize = Vector2.zero, MaxSize = Vector2.new(INFINITO, INFINITO) } })
	clase("UIFlexItem", "UIComponent", { props = { FlexMode = Enum.UIFlexMode.None } })
	clase("UIGridStyleLayout", "UIComponent", { props = { FillDirection = Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Left,
		VerticalAlignment = Enum.VerticalAlignment.Top, AbsoluteContentSize = Vector2.zero } })
	clase("UIListLayout", "UIGridStyleLayout", { props = { Padding = UDim.new(), Wraps = false } })
	clase("UIGridLayout", "UIGridStyleLayout", { props = { CellSize = UDim2.fromOffset(100, 100),
		CellPadding = UDim2.fromOffset(5, 5), StartCorner = Enum.StartCorner.TopLeft, FillDirectionMaxCells = 0 } })
	clase("UIPageLayout", "UIGridStyleLayout", { props = { Padding = UDim.new(), Circular = false } })
	clase("UITableLayout", "UIGridStyleLayout", { props = { Padding = UDim2.new() } })

	------------------------------------------------------------------------------------------------------------------
	-- Personajes: Humanoid (anda con MoveDirection × WalkSpeed, cae, salta y no atraviesa paredes), animaciones que
	-- solo cuentan el tiempo.
	local ESTADO_HUM = Enum.HumanoidStateType
	local function cambiarEstado(hum: any, nuevo: any)
		local st = estado[hum]
		local viejo = st._estado or ESTADO_HUM.Running
		if viejo == nuevo then
			return
		end
		st._estado = nuevo
		senalDe(st, "StateChanged"):Fire(viejo, nuevo)
		if nuevo == ESTADO_HUM.Jumping and st.senales.Jumping then
			st.senales.Jumping:Fire(true)
		elseif nuevo == ESTADO_HUM.Freefall and st.senales.FreeFalling then
			st.senales.FreeFalling:Fire(true)
		elseif nuevo == ESTADO_HUM.Dead and st.senales.Died then
			st.senales.Died:Fire()
		end
	end
	local function animador(hum: any): any
		local a = hum:FindFirstChildOfClass("Animator")
		if not a then
			a = nueva("Animator")
			a.Parent = hum
		end
		return a
	end
	clase("Humanoid", "Instance", {
		props = { Health = 100, MaxHealth = 100, WalkSpeed = 16, JumpPower = 50, JumpHeight = 7.2, UseJumpPower = false,
			HipHeight = 2, AutoRotate = true, AutoJumpEnabled = true, Sit = false, Jump = false, PlatformStand = false,
			MoveDirection = Vector3.zero, CameraOffset = Vector3.zero, RigType = Enum.HumanoidRigType.R15,
			DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer, FloorMaterial = Enum.Material.Air,
			WalkToPoint = Vector3.zero, RequiresNeck = true, BreakJointsOnDeath = true, EvaluateStateMachine = true,
			DisplayName = "", MaxSlopeAngle = 89, NameDisplayDistance = 100, HealthDisplayDistance = 100 },
		eventos = { "Died", "HealthChanged", "StateChanged", "Running", "Jumping", "FreeFalling", "Climbing", "Seated",
			"MoveToFinished", "AnimationPlayed", "Touched", "PlatformStanding", "GettingUp", "FallingDown", "Swimming",
			"StateEnabledChanged", "Strafing", "Ragdoll" },
		get = { RootPart = function(_, st)
			return st.padre and hijoLlamado(st.padre, "HumanoidRootPart")
		end },
		set = { Health = function(inst, st, v)
			local antes = leer(inst, st, "Health")
			local h = math.clamp(v, 0, leer(inst, st, "MaxHealth"))
			poner(inst, st, "Health", h)
			if h ~= antes then
				senalDe(st, "HealthChanged"):Fire(h)
			end
			if h <= 0 and antes > 0 then
				cambiarEstado(inst, ESTADO_HUM.Dead)
			end
		end },
		metodos = {
			GetState = function(self)
				return estado[self]._estado or ESTADO_HUM.Running
			end,
			ChangeState = cambiarEstado,
			SetStateEnabled = function(self, e, si)
				local st = estado[self]
				st._apagados = st._apagados or {}
				st._apagados[e] = not si or nil
				if st.senales.StateEnabledChanged then
					st.senales.StateEnabledChanged:Fire(e, si)
				end
			end,
			GetStateEnabled = function(self, e)
				local ap = estado[self]._apagados
				return not (ap and ap[e])
			end,
			Move = function(self, dir, relativo)
				local d = dir
				if relativo and camara then
					local m = camara.CFrame
					d = m:VectorToWorldSpace(dir)
				end
				d = Vector3.new(d.X, 0, d.Z)
				if d.Magnitude > 1 then
					d = d.Unit
				end
				poner(self, estado[self], "MoveDirection", d)
			end,
			MoveTo = function(self, pos)
				local st = estado[self]
				st._meta, st._desdeMeta = pos, ahora
				poner(self, st, "WalkToPoint", pos)
			end,
			TakeDamage = function(self, n)
				self.Health -= n
			end,
			LoadAnimation = function(self, anim)
				return animador(self):LoadAnimation(anim)
			end,
			GetPlayingAnimationTracks = function(self)
				return animador(self):GetPlayingAnimationTracks()
			end,
			EquipTool = function() end,
			UnequipTools = function() end,
			ApplyDescription = function() end,
			BuildRigFromAttachments = function() end,
			GetMoveVelocity = function(self)
				return self.MoveDirection * self.WalkSpeed
			end,
		},
	})
	clase("AnimationController", "Instance")
	clase("Animation", "Instance", { props = { AnimationId = "" } })
	clase("Animator", "Instance", {
		eventos = { "AnimationPlayed" },
		metodos = {
			LoadAnimation = function(self, anim)
				local p = nueva("AnimationTrack")
				local sp = estado[p]
				sp.props.Animation = anim
				sp._animador = self
				sp.nombre = anim and anim.Name or "AnimationTrack"
				return p
			end,
			GetPlayingAnimationTracks = function(self)
				local l = {}
				for _, p in pistas do
					if estado[p]._animador == self and p.IsPlaying then
						table.insert(l, p)
					end
				end
				return l
			end,
			ApplyJointVelocities = function() end,
			StepAnimations = function() end,
		},
	})
	clase("AnimationTrack", "Instance", {
		props = { IsPlaying = false, Length = 1, Looped = false, Priority = Enum.AnimationPriority.Core, Speed = 1,
			TimePosition = 0, WeightCurrent = 0, WeightTarget = 1 },
		eventos = { "Stopped", "Ended", "DidLoop", "KeyframeReached" },
		metodos = {
			Play = function(self, _, peso, velocidad)
				local st = estado[self]
				poner(self, st, "IsPlaying", true)
				poner(self, st, "TimePosition", 0)
				poner(self, st, "WeightTarget", peso or 1)
				poner(self, st, "WeightCurrent", peso or 1)
				if velocidad then
					poner(self, st, "Speed", velocidad)
				end
				local a = st._animador
				if a then
					senalDe(estado[a], "AnimationPlayed"):Fire(self)
				end
			end,
			Stop = function(self)
				local st = estado[self]
				if leer(self, st, "IsPlaying") then
					poner(self, st, "IsPlaying", false)
					poner(self, st, "WeightCurrent", 0)
					senalDe(st, "Stopped"):Fire()
					senalDe(st, "Ended"):Fire()
				end
			end,
			AdjustSpeed = function(self, v)
				poner(self, estado[self], "Speed", v or 1)
			end,
			AdjustWeight = function(self, v)
				poner(self, estado[self], "WeightTarget", v or 1)
				poner(self, estado[self], "WeightCurrent", v or 1)
			end,
			GetMarkerReachedSignal = function(self, n)
				return senalDe(estado[self], "Marca:" .. tostring(n))
			end,
			GetTimeOfKeyframe = function()
				return 0
			end,
		},
	})
	for _, n in { "Shirt", "Pants", "ShirtGraphic", "BodyColors", "CharacterMesh", "HumanoidDescription" } do
		clase(n, "Instance")
	end
	clase("Accoutrement", "Instance")
	clase("Accessory", "Accoutrement", { props = { AccessoryType = Enum.AccessoryType.Unknown } })
	clase("Hat", "Accoutrement")
	clase("Tool", "Model", { props = { Enabled = true, RequiresHandle = true, CanBeDropped = true, ToolTip = "" },
		eventos = { "Activated", "Deactivated", "Equipped", "Unequipped" } })

	------------------------------------------------------------------------------------------------------------------
	-- Cámara: proyecta y lanza rayos con FieldOfView vertical y ViewportSize.
	local function focal(cam: any): number
		return (cam.ViewportSize.Y / 2) / math.tan(math.rad(cam.FieldOfView) / 2)
	end
	local function aVista(cam: any, p: any): (any, boolean)
		local q = cam.CFrame:PointToObjectSpace(p)
		local vp = cam.ViewportSize
		local prof = -q.Z
		local f = focal(cam)
		local d = if math.abs(prof) < 1e-6 then 1e-6 else prof
		local x, y = vp.X / 2 + q.X / d * f, vp.Y / 2 - q.Y / d * f
		return Vector3.new(x, y, prof), prof > 0 and x >= 0 and x <= vp.X and y >= 0 and y <= vp.Y
	end
	local function rayoVista(cam: any, x: number, y: number, prof: number?): any
		local vp = cam.ViewportSize
		local f = focal(cam)
		local d = cam.CFrame:VectorToWorldSpace(Vector3.new((x - vp.X / 2) / f, -(y - vp.Y / 2) / f, -1).Unit)
		return roblox.Ray.new(cam.CFrame.Position + d * (prof or 0), d)
	end
	clase("Camera", "PVInstance", {
		props = { CFrame = CFrame.new(0, 10, 10), Focus = CFrame.new(0, 10, 0), FieldOfView = 70,
			CameraType = Enum.CameraType.Custom, ViewportSize = op.pantalla or Vector2.new(1280, 720), HeadLocked = true,
			HeadScale = 1, NearPlaneZ = -0.1, FieldOfViewMode = Enum.FieldOfViewMode.Vertical, VRTiltAndRollEnabled = false },
		get = { MaxAxisFieldOfView = function(inst, st)
			local vp = leer(inst, st, "ViewportSize")
			local v = math.rad(leer(inst, st, "FieldOfView"))
			return math.deg(2 * math.atan(math.tan(v / 2) * math.max(1, vp.X / vp.Y)))
		end },
		metodos = {
			GetPivot = function(self)
				return self.CFrame
			end,
			PivotTo = function(self, cf)
				self.CFrame = cf
			end,
			WorldToViewportPoint = aVista,
			WorldToScreenPoint = function(self, p)
				local v, si = aVista(self, p)
				return v - Vector3.new(0, BARRA, 0), si
			end,
			ViewportPointToRay = rayoVista,
			ScreenPointToRay = function(self, x, y, prof)
				return rayoVista(self, x, y + BARRA, prof)
			end,
			GetRenderCFrame = function(self)
				return self.CFrame
			end,
			Interpolate = function() end,
		},
	})

	------------------------------------------------------------------------------------------------------------------
	-- Consultas al mundo: rayos, barridos de caja y bola, y solapes. Todo pieza es una caja (Shape Ball, una bola).
	-- Como Roblox: CanQuery = false nunca se ve; RespectCanCollide salta las de CanCollide = false; los grupos de choque
	-- (PhysicsService) cuentan; lo que empieza dentro de una pieza no la toca.
	local noChocan: { [string]: boolean } = {}
	local grupos: { string } = { "Default" }
	local function chocan(a: string, b: string): boolean
		return not noChocan[a .. "\0" .. b]
	end
	local function candidatas(params: any?): { any }
		local filtro: { [any]: boolean } = {}
		local incluir = false
		local respetar, grupo = false, "Default"
		if params then
			for _, x in params.FilterDescendantsInstances do
				filtro[x] = true
			end
			incluir = params.FilterType == Enum.RaycastFilterType.Include
			respetar = params.RespectCanCollide == true
			grupo = params.CollisionGroup or "Default"
		end
		local lista = {}
		for _, p in partes do
			local st = estado[p]
			if st.clase.esA.Terrain or leer(p, st, "CanQuery") == false or not enEspacio(p) then
				continue
			end
			if respetar and leer(p, st, "CanCollide") == false then
				continue
			end
			if not chocan(grupo, leer(p, st, "CollisionGroup")) then
				continue
			end
			local dentro = false
			local a = p
			while a do
				if filtro[a] then
					dentro = true
					break
				end
				a = estado[a].padre
			end
			if dentro == incluir then
				table.insert(lista, p)
			end
		end
		return lista
	end
	local EJES = { "X", "Y", "Z" }
	local VEC_EJE = { X = Vector3.xAxis, Y = Vector3.yAxis, Z = Vector3.zAxis }
	-- Dónde entra el rayo (en partes de `dir`, 0..1) y con qué cara (normal en el mundo); nil si no entra.
	local function rayoCaja(cf: any, medio: any, origen: any, dir: any): (number?, any?)
		local o = cf:PointToObjectSpace(origen)
		local d = cf:VectorToObjectSpace(dir)
		local desde, hasta = -INFINITO, INFINITO
		local eje, signo = "X", 0
		for _, e in EJES do
			local oe, de, me = o[e], d[e], medio[e]
			if math.abs(de) < 1e-12 then
				if math.abs(oe) > me then
					return nil
				end
			else
				local t1, t2 = (-me - oe) / de, (me - oe) / de
				local s = -1
				if t1 > t2 then
					t1, t2, s = t2, t1, 1
				end
				if t1 > desde then
					desde, eje, signo = t1, e, s
				end
				hasta = math.min(hasta, t2)
				if desde > hasta then
					return nil
				end
			end
		end
		if desde < 0 or desde > 1 then
			return nil
		end
		return desde, cf:VectorToWorldSpace(VEC_EJE[eje] * signo)
	end
	local function rayoBola(centro: any, radio: number, origen: any, dir: any): (number?, any?)
		local m = origen - centro
		local a = dir:Dot(dir)
		local b = 2 * m:Dot(dir)
		local c = m:Dot(m) - radio * radio
		if c <= 0 or a < 1e-12 then
			return nil -- empieza dentro
		end
		local disc = b * b - 4 * a * c
		if disc < 0 then
			return nil
		end
		local t = (-b - math.sqrt(disc)) / (2 * a)
		if t < 0 or t > 1 then
			return nil
		end
		return t, (origen + dir * t - centro).Unit
	end
	local function esBola(p: any): boolean
		local s = estado[p].props.Shape
		return s == Enum.PartType.Ball
	end
	local function resultado(p: any, pos: any, normal: any, distancia: number)
		return setmetatable({ Instance = p, Position = pos, Normal = normal, Distance = distancia, Material = p.Material },
			MT_RESULTADO)
	end
	local function lanzarRayo(origen: any, dir: any, params: any?): any?
		local mejorT, mejorP, mejorN = INFINITO, nil, nil
		for _, p in candidatas(params) do
			local t, n
			if esBola(p) then
				local s = p.Size
				t, n = rayoBola(p.Position, math.min(s.X, s.Y, s.Z) / 2, origen, dir)
			else
				t, n = rayoCaja(p.CFrame, p.Size / 2, origen, dir)
			end
			if t and t < mejorT then
				mejorT, mejorP, mejorN = t, p, n
			end
		end
		if not mejorP then
			return nil
		end
		return resultado(mejorP, origen + dir * mejorT, mejorN, mejorT * dir.Magnitude)
	end
	-- Barrido de una caja (cfA, medio mA) que se mueve `dir` contra la caja B: separación de ejes con movimiento (los
	-- 15 ejes de dos cajas). `bola` = radio: la caja A es una bola (solo los ejes de B; algo de más en las esquinas).
	local function ejesDe(cfA: any, cfB: any, bola: boolean): { any }
		local l = { cfB.XVector, cfB.YVector, cfB.ZVector }
		if not bola then
			local a = { cfA.XVector, cfA.YVector, cfA.ZVector }
			for _, e in a do
				table.insert(l, e)
			end
			for _, ea in a do
				for i = 1, 3 do
					local x = ea:Cross(l[i])
					if x.Magnitude > 1e-6 then
						table.insert(l, x.Unit)
					end
				end
			end
		end
		return l
	end
	local function radioEn(cf: any, m: any, eje: any): number
		return m.X * math.abs(cf.XVector:Dot(eje)) + m.Y * math.abs(cf.YVector:Dot(eje)) + m.Z * math.abs(cf.ZVector:Dot(eje))
	end
	local function barrido(cfA: any, mA: any, radioBola: number?, dir: any, cfB: any, mB: any): (number?, any?, number?)
		local entra, sale = -INFINITO, INFINITO
		local normal, rNormal = nil, 0
		for _, eje in ejesDe(cfA, cfB, radioBola ~= nil) do
			local rA = if radioBola then radioBola else radioEn(cfA, mA, eje)
			local r = rA + radioEn(cfB, mB, eje)
			local s0 = (cfA.Position - cfB.Position):Dot(eje)
			local v = dir:Dot(eje)
			if math.abs(v) < 1e-12 then
				if math.abs(s0) >= r then
					return nil
				end
			else
				local t1, t2 = (-r - s0) / v, (r - s0) / v
				if t1 > t2 then
					t1, t2 = t2, t1
				end
				if t1 > entra then
					entra = t1
					normal = if s0 + v * t1 > 0 then eje else -eje
					rNormal = rA
				end
				sale = math.min(sale, t2)
				if entra > sale then
					return nil
				end
			end
		end
		if entra <= 0 or entra > 1 then
			return nil -- empieza dentro, o no llega
		end
		return entra, normal, rNormal
	end
	local function lanzarForma(cf: any, medio: any, radioBola: number?, dir: any, params: any?): any?
		local mejorT, mejorP, mejorN, mejorR = INFINITO, nil, nil, 0
		for _, p in candidatas(params) do
			local t, n, r = barrido(cf, medio, radioBola, dir, p.CFrame, p.Size / 2)
			if t and t < mejorT then
				mejorT, mejorP, mejorN, mejorR = t, p, n, r
			end
		end
		if not mejorP then
			return nil
		end
		return resultado(mejorP, cf.Position + dir * mejorT - mejorN * mejorR, mejorN, mejorT * dir.Magnitude)
	end
	local function solapan(cfA: any, mA: any, cfB: any, mB: any): boolean
		for _, eje in ejesDe(cfA, cfB, false) do
			if math.abs((cfA.Position - cfB.Position):Dot(eje)) > radioEn(cfA, mA, eje) + radioEn(cfB, mB, eje) then
				return false
			end
		end
		return true
	end
	local function solapes(params: any?, cumple: (any) -> boolean): { any }
		local l = {}
		local maximo = if params and params.MaxParts and params.MaxParts > 0 then params.MaxParts else INFINITO
		for _, p in candidatas(params) do
			if cumple(p) then
				table.insert(l, p)
				if #l >= maximo then
					break
				end
			end
		end
		return l
	end

	------------------------------------------------------------------------------------------------------------------
	-- Servicios
	clase("ServiceProvider", "Instance", { metodos = {} })
	local function servicio(nombre: string, t: { [string]: any }?)
		clase(nombre, "Instance", t)
		DEF[nombre].servicio = true
	end
	servicio("Workspace", {
		props = { Gravity = 196.2, FallenPartsDestroyHeight = -500, StreamingEnabled = false },
		get = {
			CurrentCamera = function()
				return camara
			end,
			DistributedGameTime = function()
				return ahora
			end,
		},
		set = { CurrentCamera = function(inst, st, v)
			camara = v
			cambiado(inst, st, "CurrentCamera")
		end },
		metodos = {
			Raycast = function(_, origen, dir, params)
				return lanzarRayo(origen, dir, params)
			end,
			Blockcast = function(_, cf, tam, dir, params)
				return lanzarForma(cf, tam / 2, nil, dir, params)
			end,
			Spherecast = function(_, pos, radio, dir, params)
				return lanzarForma(CFrame.new(pos), Vector3.one * radio, radio, dir, params)
			end,
			Shapecast = function(_, parte, dir, params)
				return lanzarForma(parte.CFrame, parte.Size / 2, nil, dir, params)
			end,
			GetPartBoundsInBox = function(_, cf, tam, params)
				return solapes(params, function(p)
					return solapan(cf, tam / 2, p.CFrame, p.Size / 2)
				end)
			end,
			GetPartBoundsInRadius = function(_, pos, radio, params)
				return solapes(params, function(p)
					local q = p.CFrame:PointToObjectSpace(pos)
					local m = p.Size / 2
					local cerca = Vector3.new(math.clamp(q.X, -m.X, m.X), math.clamp(q.Y, -m.Y, m.Y), math.clamp(q.Z, -m.Z, m.Z))
					return (q - cerca).Magnitude <= radio
				end)
			end,
			GetPartsInPart = function(_, parte, params)
				return solapes(params, function(p)
					return p ~= parte and solapan(parte.CFrame, parte.Size / 2, p.CFrame, p.Size / 2)
				end)
			end,
			BulkMoveTo = function(_, lista, cfs)
				for i, p in lista do
					p.CFrame = cfs[i]
				end
			end,
			GetServerTimeNow = function()
				return EPOCA + ahora
			end,
			GetRealPhysicsFPS = function()
				return 60
			end,
			-- de Model, por si alguien lo pide
			GetBoundingBox = function(self)
				return cajaDe(piezasDe(self), CF0)
			end,
		},
	})
	servicio("Players", {
		props = { MaxPlayers = 8, RespawnTime = 5, CharacterAutoLoads = true, BubbleChat = true },
		get = { LocalPlayer = function()
			return jugadorLocal
		end },
		eventos = { "PlayerAdded", "PlayerRemoving" },
		metodos = {
			GetPlayers = function(self)
				local l = {}
				for _, h in estado[self].hijos do
					if estado[h].clase.esA.Player then
						table.insert(l, h)
					end
				end
				return l
			end,
			GetPlayerFromCharacter = function(self, modelo)
				for _, j in self:GetPlayers() do
					if modelo ~= nil and j.Character == modelo then
						return j
					end
				end
				return nil
			end,
			GetPlayerByUserId = function(self, id)
				for _, j in self:GetPlayers() do
					if j.UserId == id then
						return j
					end
				end
				return nil
			end,
			GetNameFromUserIdAsync = function(_, id)
				return "Jugador" .. tostring(id)
			end,
			GetUserThumbnailAsync = function()
				return "rbxassetid://0", true
			end,
		},
	})
	local renders: { { nombre: string, prioridad: number, fn: any, orden: number } } = {}
	local ordenRender = 0
	servicio("RunService", {
		eventos = { "Heartbeat", "RenderStepped", "Stepped", "PreRender", "PreSimulation", "PostSimulation", "PreAnimation" },
		metodos = {
			IsStudio = function()
				return op.studio == true
			end,
			IsClient = function()
				return not esServidor
			end,
			IsServer = function()
				return esServidor
			end,
			IsRunning = function()
				return true
			end,
			IsRunMode = function()
				return false
			end,
			IsEdit = function()
				return false
			end,
			BindToRenderStep = function(_, nombre, prioridad, fn)
				ordenRender += 1
				table.insert(renders, { nombre = nombre, prioridad = prioridad, fn = fn, orden = ordenRender })
				table.sort(renders, function(a, b)
					if a.prioridad ~= b.prioridad then
						return a.prioridad < b.prioridad
					end
					return a.orden < b.orden
				end)
			end,
			UnbindFromRenderStep = function(_, nombre)
				for i = #renders, 1, -1 do
					if renders[i].nombre == nombre then
						table.remove(renders, i)
					end
				end
			end,
			Set3dRenderingEnabled = function() end,
		},
	})

	-- TweenService: interpola con el reloj falso (antes de Heartbeat). Un tween nuevo sobre la misma propiedad cancela
	-- el viejo, como en Roblox.
	local tweens: { any } = {}
	local function suavizar(estilo: any, t: number): number -- la curva "In" de cada estilo
		local E = Enum.EasingStyle
		if estilo == E.Linear then
			return t
		elseif estilo == E.Sine then
			return 1 - math.cos(t * math.pi / 2)
		elseif estilo == E.Quad then
			return t * t
		elseif estilo == E.Cubic then
			return t ^ 3
		elseif estilo == E.Quart then
			return t ^ 4
		elseif estilo == E.Quint then
			return t ^ 5
		elseif estilo == E.Exponential then
			return if t <= 0 then 0 else 2 ^ (10 * t - 10)
		elseif estilo == E.Circular then
			return 1 - math.sqrt(1 - t * t)
		elseif estilo == E.Back then
			local s = 1.70158
			return t * t * ((s + 1) * t - s)
		elseif estilo == E.Elastic then
			if t <= 0 or t >= 1 then
				return t
			end
			return -(2 ^ (10 * t - 10)) * math.sin((t * 10 - 10.75) * 2 * math.pi / 3)
		elseif estilo == E.Bounce then
			local function fuera(x: number): number
				local n, d = 7.5625, 2.75
				if x < 1 / d then
					return n * x * x
				elseif x < 2 / d then
					x -= 1.5 / d
					return n * x * x + 0.75
				elseif x < 2.5 / d then
					x -= 2.25 / d
					return n * x * x + 0.9375
				end
				x -= 2.625 / d
				return n * x * x + 0.984375
			end
			return 1 - fuera(1 - t)
		end
		return t
	end
	local function curva(t: number, estilo: any, direccion: any): number
		t = math.clamp(t, 0, 1)
		local D = Enum.EasingDirection
		if direccion == D.In then
			return suavizar(estilo, t)
		elseif direccion == D.Out then
			return 1 - suavizar(estilo, 1 - t)
		end
		if t < 0.5 then
			return suavizar(estilo, 2 * t) / 2
		end
		return 1 - suavizar(estilo, 2 * (1 - t)) / 2
	end
	local function mezclar(a: any, b: any, t: number): any
		local ta = typeofFalso(a)
		if ta == "number" and type(b) == "number" then
			return a + (b - a) * t
		elseif ta == "Vector3" or ta == "Vector2" or ta == "CFrame" or ta == "Color3" or ta == "UDim2" then
			return a:Lerp(b, t)
		elseif ta == "UDim" then
			return UDim.new(a.Scale + (b.Scale - a.Scale) * t, a.Offset + (b.Offset - a.Offset) * t)
		elseif ta == "NumberRange" then
			return NumberRange.new(a.Min + (b.Min - a.Min) * t, a.Max + (b.Max - a.Max) * t)
		end
		return if t >= 1 then b else a
	end
	local function acabarTween(tw: any, como: any)
		local st = estado[tw]
		local i = table.find(tweens, tw)
		if i then
			table.remove(tweens, i)
		end
		poner(tw, st, "PlaybackState", como)
		senalDe(st, "Completed"):Fire(como)
	end
	local function moverTween(tw: any)
		local st = estado[tw]
		local d = st._tw
		local info = d.info
		local t = ahora - d.inicio - info.DelayTime
		if t < 0 then
			poner(tw, st, "PlaybackState", Enum.PlaybackState.Delayed)
			return
		end
		poner(tw, st, "PlaybackState", Enum.PlaybackState.Playing)
		local dur = info.Time
		local ciclo = dur * (if info.Reverses then 2 else 1)
		local vuelta = if ciclo > 0 then math.floor(t / ciclo) else INFINITO
		local final = info.RepeatCount >= 0 and vuelta > info.RepeatCount
		local u
		if final then
			u = if info.Reverses then 0 else 1
		else
			local dentro = t - vuelta * ciclo
			u = if dentro <= dur then dentro / dur else 2 - dentro / dur
		end
		local a = curva(u, info.EasingStyle, info.EasingDirection)
		if estado[d.inst].destruido then
			acabarTween(tw, Enum.PlaybackState.Cancelled)
			return
		end
		for k, meta in d.metas do
			d.inst[k] = if final then (if info.Reverses then d.desde[k] else meta) else mezclar(d.desde[k], meta, a)
		end
		if final then
			acabarTween(tw, Enum.PlaybackState.Completed)
		end
	end
	clase("TweenBase", "Instance", {
		props = { PlaybackState = Enum.PlaybackState.Begin },
		eventos = { "Completed" },
		metodos = {
			Play = function(self)
				local st = estado[self]
				local d = st._tw
				if table.find(tweens, self) then
					return
				end
				for _, otro in table.clone(tweens) do -- el más nuevo manda sobre la misma propiedad
					local o = estado[otro]._tw
					if o.inst == d.inst then
						for k in d.metas do
							if o.metas[k] ~= nil then
								acabarTween(otro, Enum.PlaybackState.Cancelled)
								break
							end
						end
					end
				end
				if d.pausa then
					d.inicio = ahora - d.pausa
					d.pausa = nil
				else
					d.inicio = ahora
					d.desde = {}
					for k in d.metas do
						d.desde[k] = d.inst[k]
					end
				end
				table.insert(tweens, self)
				poner(self, st, "PlaybackState", Enum.PlaybackState.Playing)
			end,
			Pause = function(self)
				local st = estado[self]
				local i = table.find(tweens, self)
				if i then
					table.remove(tweens, i)
					st._tw.pausa = ahora - st._tw.inicio
					poner(self, st, "PlaybackState", Enum.PlaybackState.Paused)
				end
			end,
			Cancel = function(self)
				local st = estado[self]
				st._tw.pausa = nil
				if table.find(tweens, self) or st.props.PlaybackState == Enum.PlaybackState.Paused then
					acabarTween(self, Enum.PlaybackState.Cancelled)
				end
			end,
		},
	})
	clase("Tween", "TweenBase")
	servicio("TweenService", { metodos = {
		Create = function(_, inst, info, metas)
			assert(esInstancia(inst), "TweenService:Create necesita una instancia")
			assert(typeofFalso(info) == "TweenInfo", "TweenService:Create necesita un TweenInfo")
			for k in metas do
				assert(not estado[inst].clase.metodos[k], `TweenService:Create: {k} no es una propiedad`)
			end
			local tw = nueva("Tween")
			local st = estado[tw]
			st._tw = { inst = inst, info = info, metas = table.clone(metas) }
			st.props.Instance = inst
			st.props.TweenInfo = info
			return tw
		end,
		GetValue = function(_, alfa, estilo, direccion)
			return curva(alfa, estilo, direccion)
		end,
	} })

	-- Entrada: teclas, ratón y mando. mundo.pulsar / mundo.soltar / mundo.raton.
	local pulsadas: { [any]: any } = {} -- KeyCode o UserInputType -> InputObject
	local ultimoTipo = Enum.UserInputType.Keyboard
	local deltaRaton = Vector2.zero
	clase("InputObject", "Instance", { props = { KeyCode = Enum.KeyCode.Unknown, UserInputType = Enum.UserInputType.None,
		UserInputState = Enum.UserInputState.None, Position = Vector3.zero, Delta = Vector3.zero },
		metodos = { IsModifierKeyDown = function(_, m)
			local K = Enum.KeyCode
			local pares = { Shift = { K.LeftShift, K.RightShift }, Ctrl = { K.LeftControl, K.RightControl },
				Alt = { K.LeftAlt, K.RightAlt }, Meta = { K.LeftMeta, K.RightMeta } }
			for _, k in pares[m.Name] or {} do
				if pulsadas[k] then
					return true
				end
			end
			return false
		end } })
	servicio("UserInputService", {
		props = { TouchEnabled = false, KeyboardEnabled = true, MouseEnabled = true, GamepadEnabled = false,
			AccelerometerEnabled = false, GyroscopeEnabled = false, VREnabled = false, MouseBehavior = Enum.MouseBehavior.Default,
			MouseIconEnabled = true, MouseDeltaSensitivity = 1, ModalEnabled = false, OnScreenKeyboardVisible = false,
			PreferredInput = Enum.PreferredInput.KeyboardAndMouse },
		eventos = { "InputBegan", "InputEnded", "InputChanged", "JumpRequest", "WindowFocusReleased", "WindowFocused",
			"LastInputTypeChanged", "TouchStarted", "TouchEnded", "TouchMoved", "TouchTap", "TouchLongPress",
			"GamepadConnected", "GamepadDisconnected", "TextBoxFocused", "TextBoxFocusReleased", "DeviceRotationChanged" },
		metodos = {
			IsKeyDown = function(_, k)
				return pulsadas[k] ~= nil
			end,
			IsMouseButtonPressed = function(_, b)
				return pulsadas[b] ~= nil
			end,
			IsGamepadButtonDown = function(_, _, k)
				return pulsadas[k] ~= nil
			end,
			GetKeysPressed = function()
				local l = {}
				for k, i in pulsadas do
					if deTipo(k, "KeyCode") then
						table.insert(l, i)
					end
				end
				return l
			end,
			GetLastInputType = function()
				return ultimoTipo
			end,
			GetMouseLocation = function()
				local vp = if camara then camara.ViewportSize else Vector2.new(1280, 720)
				return vp / 2
			end,
			GetMouseDelta = function()
				return deltaRaton
			end,
			GetFocusedTextBox = function()
				return nil
			end,
			GetGamepadConnected = function(self)
				return self.GamepadEnabled
			end,
			GetConnectedGamepads = function(self)
				return if self.GamepadEnabled then { Enum.UserInputType.Gamepad1 } else {}
			end,
			GetNavigationGamepads = function(self)
				return if self.GamepadEnabled then { Enum.UserInputType.Gamepad1 } else {}
			end,
			GetGamepadState = function()
				return {}
			end,
			GetStringForKeyCode = function(_, k)
				return k.Name
			end,
			GetImageForKeyCode = function()
				return ""
			end,
		},
	})
	local acciones: { { nombre: string, fn: any, prioridad: number, entradas: { any }, orden: number } } = {}
	local ordenAccion = 0
	local function atar(nombre: string, fn: any, prioridad: number, ...)
		for i = #acciones, 1, -1 do
			if acciones[i].nombre == nombre then
				table.remove(acciones, i)
			end
		end
		ordenAccion += 1
		table.insert(acciones, { nombre = nombre, fn = fn, prioridad = prioridad, entradas = { ... }, orden = ordenAccion })
		table.sort(acciones, function(a, b)
			if a.prioridad ~= b.prioridad then
				return a.prioridad > b.prioridad
			end
			return a.orden > b.orden
		end)
	end
	servicio("ContextActionService", { eventos = { "LocalToolEquipped", "LocalToolUnequipped" }, metodos = {
		BindAction = function(_, nombre, fn, _boton, ...)
			atar(nombre, fn, 2000, ...)
		end,
		BindActionAtPriority = function(_, nombre, fn, _boton, prioridad, ...)
			atar(nombre, fn, prioridad, ...)
		end,
		UnbindAction = function(_, nombre)
			for i = #acciones, 1, -1 do
				if acciones[i].nombre == nombre then
					table.remove(acciones, i)
				end
			end
		end,
		UnbindAllActions = function()
			table.clear(acciones)
		end,
		GetBoundActionInfo = function(_, nombre)
			for _, a in acciones do
				if a.nombre == nombre then
					return { inputTypes = a.entradas, priorityLevel = a.prioridad }
				end
			end
			return {}
		end,
		GetAllBoundActionInfo = function()
			local t = {}
			for _, a in acciones do
				t[a.nombre] = { inputTypes = a.entradas, priorityLevel = a.prioridad }
			end
			return t
		end,
		GetButton = function()
			return nil
		end,
		SetTitle = function() end,
		SetImage = function() end,
		SetPosition = function() end,
		SetDescription = function() end,
	} })
	servicio("CollectionService", { metodos = {
		GetTagged = function(_, tag)
			local l = {}
			for _, i in etiquetadas[tag] or {} do
				if enJuego(i) then
					table.insert(l, i)
				end
			end
			return l
		end,
		HasTag = function(_, i, tag)
			return i:HasTag(tag)
		end,
		AddTag = function(_, i, tag)
			i:AddTag(tag)
		end,
		RemoveTag = function(_, i, tag)
			i:RemoveTag(tag)
		end,
		GetTags = function(_, i)
			return i:GetTags()
		end,
		GetAllTags = function()
			local l = {}
			for tag in etiquetadas do
				table.insert(l, tag)
			end
			return l
		end,
		GetInstanceAddedSignal = function(_, tag)
			return senalesDe(tag).puesta
		end,
		GetInstanceRemovedSignal = function(_, tag)
			return senalesDe(tag).quitada
		end,
	} })
	servicio("PhysicsService", { metodos = {
		RegisterCollisionGroup = function(_, n)
			if not table.find(grupos, n) then
				table.insert(grupos, n)
			end
		end,
		UnregisterCollisionGroup = function(_, n)
			local i = table.find(grupos, n)
			if i then
				table.remove(grupos, i)
			end
		end,
		IsCollisionGroupRegistered = function(_, n)
			return table.find(grupos, n) ~= nil
		end,
		CollisionGroupSetCollidable = function(_, a, b, si)
			noChocan[a .. "\0" .. b] = not si or nil
			noChocan[b .. "\0" .. a] = not si or nil
		end,
		CollisionGroupsAreCollidable = function(_, a, b)
			return chocan(a, b)
		end,
		GetRegisteredCollisionGroups = function()
			local l = {}
			for i, n in grupos do
				table.insert(l, { name = n, id = i - 1, mask = 0 })
			end
			return l
		end,
		GetMaxCollisionGroups = function()
			return 32
		end,
	} })
	local sonidosLocales: { any } = {}
	servicio("SoundService", { props = { AmbientReverb = Enum.ReverbType.NoReverb, DistanceFactor = 3.33,
		DopplerScale = 1, RolloffScale = 1, RespectFilteringEnabled = true }, metodos = {
		PlayLocalSound = function(_, s)
			table.insert(sonidosLocales, s)
			s:Play()
		end,
		SetListener = function() end,
		GetListener = function()
			return Enum.ListenerType.Camera, nil
		end,
	} })
	local function horaATexto(h: number): string
		h %= 24
		local s = math.floor(h * 3600 + 0.5)
		return string.format("%02d:%02d:%02d", s // 3600, (s // 60) % 60, s % 60)
	end
	servicio("Lighting", {
		props = { ClockTime = 14, Brightness = 2, Ambient = Color3.fromRGB(70, 70, 70), OutdoorAmbient = Color3.fromRGB(70, 70, 70),
			ColorShift_Top = Color3.new(), ColorShift_Bottom = Color3.new(), FogStart = 0, FogEnd = 100000,
			FogColor = Color3.fromRGB(192, 192, 192), ExposureCompensation = 0, GlobalShadows = true, GeographicLatitude = 0,
			EnvironmentDiffuseScale = 0, EnvironmentSpecularScale = 0, ShadowSoftness = 0.2,
			Technology = Enum.Technology.Future },
		get = { TimeOfDay = function(inst, st)
			return horaATexto(leer(inst, st, "ClockTime"))
		end },
		set = { TimeOfDay = function(inst, st, v)
			local h, m, s = string.match(v, "^(%d+):?(%d*):?(%d*)$")
			poner(inst, st, "ClockTime", (tonumber(h) or 0) + (tonumber(m) or 0) / 60 + (tonumber(s) or 0) / 3600)
			cambiado(inst, st, "TimeOfDay")
		end },
		metodos = {
			GetMinutesAfterMidnight = function(self)
				return self.ClockTime * 60
			end,
			SetMinutesAfterMidnight = function(self, m)
				self.ClockTime = m / 60
			end,
			GetSunDirection = function(self)
				local a = (self.ClockTime / 24) * 2 * math.pi - math.pi / 2
				return Vector3.new(math.cos(a), math.sin(a), 0)
			end,
			GetMoonDirection = function(self)
				return -self:GetSunDirection()
			end,
		},
	})
	for _, n in { "ReplicatedStorage", "ReplicatedFirst", "ServerStorage", "ServerScriptService", "StarterPack",
		"MaterialService", "Teams", "Chat", "TextChatService", "VRService", "BadgeService", "PolicyService",
		"AnalyticsService", "Stats", "DataStoreService", "MessagingService", "AssetService", "SocialService",
		"AvatarEditorService", "GroupService", "TeleportService", "InsertService", "StarterPlayer" } do
		servicio(n)
	end
	DEF.StarterPlayer.props = { CameraMode = Enum.CameraMode.Classic, CharacterWalkSpeed = 16, CharacterJumpHeight = 7.2,
		CameraMaxZoomDistance = 128, CameraMinZoomDistance = 0.5 }
	clase("StarterPlayerScripts", "Instance")
	clase("StarterCharacterScripts", "Instance")
	local nucleo: { [string]: any } = {}
	servicio("StarterGui", { props = { ResetPlayerGuiOnSpawn = true, ShowDevelopmentGui = true }, metodos = {
		SetCore = function(_, n, v)
			nucleo[n] = v
		end,
		GetCore = function(_, n)
			return nucleo[n]
		end,
		SetCoreGuiEnabled = function(_, t, si)
			nucleo["Gui:" .. tostring(t)] = si
		end,
		GetCoreGuiEnabled = function(_, t)
			return nucleo["Gui:" .. tostring(t)] ~= false
		end,
		RegisterSetCore = function() end,
		RegisterGetCore = function() end,
	} })
	servicio("GuiService", {
		props = { AutoSelectGuiEnabled = true, GuiNavigationEnabled = true, MenuIsOpen = false, SelectedObject = nil,
			TouchControlsEnabled = true, PreferredTextSize = Enum.PreferredTextSize.Medium, ReducedMotionEnabled = false },
		get = { TopbarInset = function()
			local vp = if camara then camara.ViewportSize else Vector2.new(1280, 720)
			return roblox.Rect.new(0, 0, vp.X, BARRA)
		end },
		eventos = { "MenuOpened", "MenuClosed", "MenuOpening" },
		metodos = {
			GetGuiInset = function()
				return Vector2.new(0, BARRA), Vector2.zero
			end,
			IsTenFootInterface = function()
				return false
			end,
			GetEmotesMenuOpen = function()
				return false
			end,
			Select = function() end,
		},
	})
	servicio("Debris", { metodos = { AddItem = function(_, i, t)
		task.delay(t or 10, function()
			if not estado[i].destruido then
				destruir(i)
			end
		end)
	end } })
	servicio("TextService", { metodos = {
		GetTextSize = function(_, texto, tam, _, marco)
			return medirTexto(texto, tam, marco and marco.X)
		end,
		GetTextBoundsAsync = function(_, p)
			return medirTexto(p.Text or "", p.Size or 14, p.Width)
		end,
	} })
	servicio("ContentProvider", { props = { RequestQueueSize = 0 }, metodos = {
		PreloadAsync = function(_, lista, alAcabar)
			if alAcabar then
				for _, x in lista do
					alAcabar(if type(x) == "string" then x else "", Enum.AssetFetchStatus.Success)
				end
			end
		end,
	} })
	servicio("ProximityPromptService", { props = { Enabled = true, MaxPromptsVisible = 16 },
		eventos = { "PromptShown", "PromptHidden", "PromptTriggered", "PromptTriggerEnded", "PromptButtonHoldBegan",
			"PromptButtonHoldEnded" } })
	local guias = 0
	servicio("HttpService", { props = { HttpEnabled = false }, metodos = {
		JSONEncode = function(_, v)
			return serde.encode("json", v)
		end,
		JSONDecode = function(_, t)
			return serde.decode("json", t)
		end,
		GenerateGUID = function(_, llaves)
			guias += 1
			local g = string.format("00000000-0000-4000-8000-%012d", guias)
			return if llaves == false then g else "{" .. g .. "}"
		end,
		UrlEncode = function(_, t)
			return (string.gsub(t, "[^%w%-_%.~]", function(c)
				return string.format("%%%02X", string.byte(c))
			end))
		end,
	} })
	local compras: { any } = {}
	servicio("MarketplaceService", {
		eventos = { "PromptGamePassPurchaseFinished", "PromptProductPurchaseFinished", "PromptPurchaseFinished" },
		metodos = {
			PromptGamePassPurchase = function(_, j, id)
				table.insert(compras, { "Pase", j, id })
			end,
			PromptProductPurchase = function(_, j, id)
				table.insert(compras, { "Producto", j, id })
			end,
			PromptPurchase = function(_, j, id)
				table.insert(compras, { "Objeto", j, id })
			end,
			UserOwnsGamePassAsync = function()
				return false
			end,
			GetProductInfo = function(_, id)
				return { Name = "Producto " .. tostring(id), PriceInRobux = 0, IconImageAssetId = 0 }
			end,
		},
	})
	clase("Translator", "Instance", { props = { LocaleId = "en-us" }, metodos = {
		Translate = function(_, _, t)
			return t
		end,
		FormatByKey = function(_, k)
			return k
		end,
	} })
	servicio("LocalizationService", { props = { RobloxLocaleId = "en-us", SystemLocaleId = "en-us" }, metodos = {
		GetTranslatorForPlayerAsync = function(_, j)
			local t = nueva("Translator")
			t.LocaleId = j.LocaleId
			return t
		end,
		GetTranslatorForLocaleAsync = function(_, l)
			local t = nueva("Translator")
			t.LocaleId = l
			return t
		end,
		GetCountryRegionForPlayerAsync = function()
			return "ES"
		end,
	} })
	servicio("HapticService", { metodos = { IsVibrationSupported = function()
		return false
	end, SetMotor = function() end, IsMotorSupported = function()
		return false
	end } })

	clase("Player", "Instance", {
		props = { DisplayName = "Prueba", UserId = 1, Character = nil, Team = nil, Neutral = true, LocaleId = "en-us",
			AccountAge = 365, MembershipType = Enum.MembershipType.None, CameraMode = Enum.CameraMode.Classic,
			CameraMaxZoomDistance = 128, CameraMinZoomDistance = 0.5, HealthDisplayDistance = 100, NameDisplayDistance = 100,
			DevEnableMouseLock = true, AutoJumpEnabled = true, RespawnLocation = nil, ReplicationFocus = nil },
		eventos = { "CharacterAdded", "CharacterRemoving", "CharacterAppearanceLoaded", "Chatted", "Idled" },
		metodos = {
			GetMouse = function(self)
				local st = estado[self]
				if not st._raton then
					st._raton = nueva("PlayerMouse")
				end
				return st._raton
			end,
			Kick = function(self, motivo)
				aviso(`{self.Name} expulsado: {motivo or ""}`)
			end,
			HasAppearanceLoaded = function(self)
				return self.Character ~= nil
			end,
			LoadCharacter = function(self)
				mundo.personaje(nil, self)
			end,
			GetNetworkPing = function()
				return 0.05
			end,
			IsInGroup = function()
				return false
			end,
			GetRankInGroup = function()
				return 0
			end,
			GetRoleInGroup = function()
				return "Guest"
			end,
			GetFriendsOnline = function()
				return {}
			end,
			IsFriendsWith = function()
				return false
			end,
			ClearCharacterAppearance = function() end,
		},
	})
	clase("PlayerGui", "Instance", { props = { ScreenOrientation = Enum.ScreenOrientation.LandscapeSensor,
		SelectionImageObject = nil }, metodos = { GetTopbarTransparency = function()
		return 0.5
	end } })
	clase("PlayerScripts", "Instance")
	clase("UserGameSettings", "Instance", { props = { MouseSensitivity = 1, SavedQualityLevel = Enum.SavedQualitySetting.Automatic,
		RotationType = Enum.RotationType.MovementRelative, ComputerMovementMode = Enum.ComputerMovementMode.Default } })
	clase("Backpack", "Instance")
	clase("StarterGear", "Instance")
	clase("PlayerMouse", "Instance", { props = { Hit = CF0, Origin = CF0, Target = nil, TargetFilter = nil, X = 640, Y = 360,
		Icon = "", ViewSizeX = 1280, ViewSizeY = 720, UnitRay = roblox.Ray.new(Vector3.zero, -Vector3.zAxis) },
		eventos = { "Button1Down", "Button1Up", "Button2Down", "Button2Up", "Move", "WheelForward", "WheelBackward", "Idle" } })
	clase("DataModel", "ServiceProvider", {
		props = { PlaceId = 0, GameId = 0, JobId = "falso", PlaceVersion = 0, CreatorId = 0,
			CreatorType = Enum.CreatorType.User, Loaded = true },
		get = { Workspace = function()
			return espacio
		end },
		eventos = { "Loaded", "Close" },
		metodos = {
			GetService = function(self, n)
				local h = hijoLlamado(self, n)
				if h and estado[h].clase.nombre == n then
					return h
				end
				if not (DEF[n] and DEF[n].servicio) then
					aviso(`GetService("{n}"): servicio que el mundo falso no conoce (se crea vacío)`)
					servicio(n)
				end
				local s = nueva(n)
				ponerPadre(s, estado[s], self)
				return s
			end,
			FindService = function(self, n)
				return hijoLlamado(self, n)
			end,
			IsLoaded = function()
				return true
			end,
			BindToClose = function() end,
			GetJobsInfo = function()
				return {}
			end,
		},
	})
	DEF.DataModel.metodos.service = DEF.DataModel.metodos.GetService

	------------------------------------------------------------------------------------------------------------------
	-- El árbol del juego.
	juego = nueva("DataModel")
	estado[juego].nombre = "Juego"
	local function S(n: string): any
		return juego:GetService(n)
	end
	for _, n in { "Workspace", "Players", "Lighting", "ReplicatedStorage", "ReplicatedFirst", "ServerStorage",
		"ServerScriptService", "StarterGui", "StarterPack", "StarterPlayer", "SoundService", "MaterialService", "Teams",
		"RunService", "TweenService", "UserInputService", "ContextActionService", "CollectionService", "PhysicsService",
		"GuiService", "Debris", "TextService", "ContentProvider", "ProximityPromptService", "HttpService",
		"MarketplaceService", "LocalizationService" } do
		S(n)
	end
	espacio = S("Workspace")
	local terreno = nueva("Terrain")
	terreno.Name = "Terrain"
	terreno.Parent = espacio
	camara = nueva("Camera")
	camara.Name = "Camera"
	camara.Parent = espacio
	local inicial = S("StarterPlayer")
	local arranque = nueva("StarterPlayerScripts")
	arranque.Name = "StarterPlayerScripts"
	arranque.Parent = inicial
	local personajeInicial = nueva("StarterCharacterScripts")
	personajeInicial.Name = "StarterCharacterScripts"
	personajeInicial.Parent = inicial

	local cuentaJugadores = 0
	local function nuevoJugador(nombre: string?): any
		cuentaJugadores += 1
		local j = nueva("Player")
		j.Name = nombre or (if cuentaJugadores == 1 then "Prueba" else "Otro" .. cuentaJugadores)
		j.DisplayName = j.Name
		j.UserId = cuentaJugadores
		for _, n in { "PlayerGui", "PlayerScripts", "Backpack", "StarterGear" } do
			local h = nueva(n)
			h.Name = n
			h.Parent = j
		end
		j.Parent = S("Players")
		senalDe(estado[S("Players")], "PlayerAdded"):Fire(j)
		return j
	end
	if not esServidor then
		jugadorLocal = nuevoJugador("Prueba")
	end

	-- Scripts falsos: cada archivo de src es un ModuleScript (o Script / LocalScript) con su ruta; una carpeta es un
	-- Folder (o el script de su init.luau) que se rellena al mirar sus hijos. Dónde va cada carpeta lo dice el
	-- .project.json de Rojo; StarterPlayerScripts va al PlayerScripts del jugador local, como al jugar.
	local raices: { { prefijo: string, nodo: any } } = {}
	local function claseDir(ruta: string): (string, string?)
		for _, p in { { "init.luau", "ModuleScript" }, { "init.client.luau", "LocalScript" },
			{ "init.server.luau", "Script" } } do
			if ARCHIVOS[ruta .. "/" .. p[1]] then
				return p[2], ruta .. "/" .. p[1]
			end
		end
		return "Folder", nil
	end
	nodoArchivo = function(nombre, ruta, padre)
		local claseN, archivo, dir, n = nil, nil, nil, nombre
		if CARPETAS[ruta] then
			claseN, archivo = claseDir(ruta)
			dir = ruta
		else
			local hoja = string.match(ruta, "([^/]+)$") or ruta
			for _, p in { { "%.server%.luau$", "Script" }, { "%.client%.luau$", "LocalScript" }, { "%.luau$", "ModuleScript" } } do
				local base = string.match(hoja, "^(.+)" .. p[1])
				if base then
					claseN, archivo, n = p[2], ruta, base
					break
				end
			end
			if not claseN then
				return nil -- .rbxmx, .json...: no se cargan
			end
		end
		local i = nueva(claseN)
		local st = estado[i]
		st.nombre = n
		st.archivo, st.dir = archivo, dir
		if padre then
			ponerPadre(i, st, padre)
		end
		return i
	end
	local function montar(arbol: { [string]: any }, inst: any)
		for clave, sub in arbol do
			if string.sub(clave, 1, 1) == "$" or type(sub) ~= "table" then
				continue
			end
			local destino
			if inst == juego then
				destino = S(clave)
			elseif clave == "StarterPlayerScripts" and jugadorLocal then
				destino = jugadorLocal.PlayerScripts
			elseif sub["$path"] then
				local ruta = sub["$path"]
				destino = nodoArchivo(clave, ruta, nil)
				if destino then
					estado[destino].nombre = clave
					destino.Parent = inst
					table.insert(raices, { prefijo = string.gsub(ruta, "%.luau$", ""), nodo = destino })
				end
			else
				destino = inst:FindFirstChild(clave) or nueva(sub["$className"] or "Folder")
				estado[destino].nombre = clave
				destino.Parent = inst
			end
			if destino then
				montar(sub, destino)
			end
		end
	end
	local proyecto = op.proyecto or "juego.project.json"
	if fs.isFile(proyecto) then
		montar(serde.decode("json", fs.readFile(proyecto)).tree, juego)
	end
	table.sort(raices, function(a, b)
		return #a.prefijo > #b.prefijo
	end)
	local fuera = nueva("Folder") -- lo que no está en el proyecto cuelga de aquí, carpeta a carpeta
	estado[fuera].nombre = "Archivos"
	estado[fuera].dir = "."

	local function nodoDeCarpeta(dir: string): any?
		local nodo, resto = fuera, dir
		for _, r in raices do
			if dir == r.prefijo then
				return r.nodo
			elseif string.sub(dir, 1, #r.prefijo + 1) == r.prefijo .. "/" then
				nodo, resto = r.nodo, string.sub(dir, #r.prefijo + 2)
				break
			end
		end
		for trozo in string.gmatch(resto, "[^/]+") do
			nodo = hijoLlamado(nodo, trozo)
			if not nodo then
				return nil
			end
		end
		return nodo
	end
	local function nodoDeRuta(ruta: string): any?
		ruta = string.gsub(string.gsub(ruta, "\\", "/"), "%.luau$", "")
		local dir, nombre = string.match(ruta, "^(.*)/([^/]+)$")
		if not dir then
			dir, nombre = ".", ruta
		end
		if nombre == "init" or string.match(nombre, "^init%.") then
			return nodoDeCarpeta(dir)
		end
		nombre = string.gsub(string.gsub(nombre, "%.client$", ""), "%.server$", "")
		local carpeta = nodoDeCarpeta(dir)
		return carpeta and hijoLlamado(carpeta, nombre)
	end

	-- Los RemoteEvents de shared/Remotes, ya creados como los dejaría el servidor (el cliente los espera).
	local carpetaRemotos: any = nil
	local fuenteRemotos = ARCHIVOS["src/shared/Remotes.luau"]
	if not esServidor and fuenteRemotos then
		local fuente = fuenteRemotos
		local lista = string.match(fuente, "local NOMBRES = (%b{})")
		if lista then
			carpetaRemotos = nueva("Folder")
			carpetaRemotos.Name = "Remotes"
			for linea in string.gmatch(lista, "[^\n]+") do
				local n = string.match(linea, '^%s*"([%w_]+)",')
				if n then
					local r = nueva("RemoteEvent")
					r.Name = n
					r.Parent = carpetaRemotos
				end
			end
			carpetaRemotos.Parent = S("ReplicatedStorage")
		end
	end

	------------------------------------------------------------------------------------------------------------------
	-- El entorno de cada módulo cargado.
	local _G2 = {}
	local function esperarViejo(t: number?)
		local e = task.wait(t or 0.03)
		return e, ahora
	end
	local os2 = table.clone(os)
	os2.clock = function()
		return 100 + ahora
	end
	os2.time = function(t: any?)
		if t then
			return os.time(t)
		end
		return math.floor(EPOCA + ahora)
	end
	os2.date = function(f: string?, t: number?)
		return os.date(f, t or math.floor(EPOCA + ahora))
	end
	local base: { [string]: any } = {
		game = juego,
		workspace = espacio,
		Workspace = espacio,
		Instance = {
			new = function(n: string, padre: any?)
				local i = nueva(n)
				if padre then
					i.Parent = padre
				end
				return i
			end,
			fromExisting = clonar,
		},
		Vector3 = Vector3, Vector2 = Vector2, CFrame = CFrame, Color3 = Color3, UDim = UDim, UDim2 = UDim2, Enum = Enum,
		Font = Font, NumberSequence = NumberSequence, NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		ColorSequence = ColorSequence, ColorSequenceKeypoint = roblox.ColorSequenceKeypoint, NumberRange = NumberRange,
		Rect = roblox.Rect, BrickColor = roblox.BrickColor, Ray = roblox.Ray, Region3 = roblox.Region3,
		Region3int16 = roblox.Region3int16, Vector3int16 = roblox.Vector3int16, Vector2int16 = roblox.Vector2int16,
		Faces = roblox.Faces, Axes = roblox.Axes, PhysicalProperties = roblox.PhysicalProperties, Content = roblox.Content,
		TweenInfo = TweenInfo, RaycastParams = RaycastParams, OverlapParams = OverlapParams, Random = Random,
		DateTime = DateTime,
		task = task,
		typeof = typeofFalso,
		math = math2,
		os = os2,
		tick = function()
			return EPOCA + ahora
		end,
		time = function()
			return ahora
		end,
		elapsedTime = function()
			return ahora
		end,
		wait = esperarViejo,
		delay = task.delay,
		spawn = task.defer,
		warn = function(...)
			local t = {}
			for i = 1, select("#", ...) do
				t[i] = tostring((select(i, ...)))
			end
			aviso("warn: " .. table.concat(t, " "))
		end,
		UserSettings = function()
			local ajustes = nueva("UserGameSettings")
			return { GetService = function()
				return ajustes
			end }
		end,
		settings = function()
			return { Rendering = { QualityLevel = Enum.QualityLevel.Automatic }, Physics = {}, Network = {} }
		end,
		_G = _G2,
		shared = _G2,
	}

	local modulos: { [string]: any } = {}
	local requerir: (nodo: any) -> any
	local function entorno(nodo: any): { [string]: any }
		local e = table.clone(base)
		e.script = nodo
		e.require = function(x: any)
			if esInstancia(x) then
				return requerir(x)
			end
			error(`require: solo instancias en el mundo falso (no {typeofNativo(x)})`, 2)
		end
		return e
	end
	local function claveDe(archivo: string): string
		return (string.gsub(string.gsub(string.gsub(archivo, "%.luau$", ""), "%.client$", ""), "%.server$", ""))
	end
	requerir = function(nodo)
		local st = estado[nodo]
		local archivo = st.archivo
		if not archivo then
			error(`require: {nodo:GetFullName()} no es un módulo de src`, 3)
		end
		local clave = claveDe(archivo)
		local corta = string.gsub(clave, "/init$", "")
		for _, k in { clave, corta, corta .. ".luau", st.nombre } do
			if mundo.falsos[k] ~= nil then
				return mundo.falsos[k]
			end
		end
		local hecho = modulos[clave]
		if hecho == CARGANDO then
			error(`require circular: {clave}`, 3)
		elseif hecho ~= nil then
			return if hecho == NADA then nil else hecho
		end
		modulos[clave] = CARGANDO
		local fuente = ARCHIVOS[archivo]
		if not fuente then
			modulos[clave] = nil
			error(`require: no encuentro {archivo}`, 3)
		end
		local fn = luau.load(fuente, { debugName = archivo, environment = entorno(nodo) })
		local salida, acabado = nil, false
		local co = hilo(function()
			salida = fn()
			acabado = true
		end)
		local ok, err = pcall(reanudar, co)
		if not ok then
			modulos[clave] = nil
			error(err, 0)
		end
		if not acabado then
			modulos[clave] = nil
			if coroutine.status(co) == "suspended" then
				error(`{clave} espera (task.wait o :Wait) mientras se carga: en Roblox el require esperaría\n{debug.traceback(co)}`, 3)
			end
			error(`{clave} falló al cargarse`, 3)
		end
		modulos[clave] = if salida == nil then NADA else salida
		return salida
	end

	------------------------------------------------------------------------------------------------------------------
	-- Personaje R15 sencillo: tamaños y juntas de un avatar de bloques (pies en el suelo con HipHeight 2).
	local PIEL = Color3.fromRGB(234, 184, 146)
	local CUERPO = {
		-- nombre, tamaño, padre, junta, C0 (en el padre), C1 (en la pieza)
		{ "LowerTorso", Vector3.new(2, 0.4, 1), "HumanoidRootPart", "Root", CFrame.new(0, -0.8, 0), CF0 },
		{ "UpperTorso", Vector3.new(2, 1.6, 1), "LowerTorso", "Waist", CFrame.new(0, 0.2, 0), CFrame.new(0, -0.8, 0) },
		{ "Head", Vector3.new(1.2, 1.2, 1.2), "UpperTorso", "Neck", CFrame.new(0, 0.8, 0), CFrame.new(0, -0.6, 0) },
		{ "RightUpperArm", Vector3.new(1, 1.2, 1), "UpperTorso", "RightShoulder", CFrame.new(1, 0.56, 0), CFrame.new(-0.5, 0.4, 0) },
		{ "RightLowerArm", Vector3.new(1, 1.1, 1), "RightUpperArm", "RightElbow", CFrame.new(0, -0.4, 0), CFrame.new(0, 0.5, 0) },
		{ "RightHand", Vector3.new(1, 0.3, 1), "RightLowerArm", "RightWrist", CFrame.new(0, -0.55, 0), CFrame.new(0, 0.1, 0) },
		{ "LeftUpperArm", Vector3.new(1, 1.2, 1), "UpperTorso", "LeftShoulder", CFrame.new(-1, 0.56, 0), CFrame.new(0.5, 0.4, 0) },
		{ "LeftLowerArm", Vector3.new(1, 1.1, 1), "LeftUpperArm", "LeftElbow", CFrame.new(0, -0.4, 0), CFrame.new(0, 0.5, 0) },
		{ "LeftHand", Vector3.new(1, 0.3, 1), "LeftLowerArm", "LeftWrist", CFrame.new(0, -0.55, 0), CFrame.new(0, 0.1, 0) },
		{ "RightUpperLeg", Vector3.new(1, 1, 1), "LowerTorso", "RightHip", CFrame.new(0.5, -0.2, 0), CFrame.new(0, 0.5, 0) },
		{ "RightLowerLeg", Vector3.new(1, 0.8, 1), "RightUpperLeg", "RightKnee", CFrame.new(0, -0.5, 0), CFrame.new(0, 0.4, 0) },
		{ "RightFoot", Vector3.new(1, 0.2, 1), "RightLowerLeg", "RightAnkle", CFrame.new(0, -0.4, 0), CFrame.new(0, 0.1, 0) },
		{ "LeftUpperLeg", Vector3.new(1, 1, 1), "LowerTorso", "LeftHip", CFrame.new(-0.5, -0.2, 0), CFrame.new(0, 0.5, 0) },
		{ "LeftLowerLeg", Vector3.new(1, 0.8, 1), "LeftUpperLeg", "LeftKnee", CFrame.new(0, -0.5, 0), CFrame.new(0, 0.4, 0) },
		{ "LeftFoot", Vector3.new(1, 0.2, 1), "LeftLowerLeg", "LeftAnkle", CFrame.new(0, -0.4, 0), CFrame.new(0, 0.1, 0) },
	}
	local CHOCAN = { HumanoidRootPart = false, UpperTorso = true, LowerTorso = true, Head = true }
	local function juntar(j: any)
		local st = estado[j]
		if leer(j, st, "Enabled") == false then
			return
		end
		local p0, p1 = leer(j, st, "Part0"), leer(j, st, "Part1")
		if not (p0 and p1) or estado[p0].destruido or estado[p1].destruido then
			return
		end
		if st.clase.esA.WeldConstraint then
			if not st._rel or st._p0 ~= p0 or st._p1 ~= p1 then
				st._rel, st._p0, st._p1 = p0.CFrame:ToObjectSpace(p1.CFrame), p0, p1
			end
			if p1.Anchored and not p0.Anchored then
				p0.CFrame = p1.CFrame * st._rel:Inverse()
			else
				p1.CFrame = p0.CFrame * st._rel
			end
			return
		end
		local enMedio = leer(j, st, "C0") * (leer(j, st, "Transform") or CF0) * leer(j, st, "C1"):Inverse()
		if p1.Anchored and not p0.Anchored then
			p0.CFrame = p1.CFrame * enMedio:Inverse()
		else
			p1.CFrame = p0.CFrame * enMedio
		end
	end
	local function resolverJuntas()
		for _ = 1, 2 do
			for _, j in juntas do
				if enEspacio(j) then
					juntar(j)
				end
			end
		end
	end
	local function crearPersonaje(cf: any?, jugador: any?): any
		local j = jugador or jugadorLocal
		assert(j, "mundo.personaje: no hay jugador (en un mundo de servidor, pasa uno de mundo.jugador)")
		local viejo = j.Character
		if viejo then
			senalDe(estado[j], "CharacterRemoving"):Fire(viejo)
			destruir(viejo)
		end
		local m = nueva("Model")
		m.Name = j.Name
		local raiz = nueva("Part")
		raiz.Name = "HumanoidRootPart"
		raiz.Size = Vector3.new(2, 2, 1)
		raiz.Transparency = 1
		raiz.CanCollide = false
		raiz.CFrame = cf or CFrame.new(0, 3, 0)
		raiz.Parent = m
		local partesP: { [string]: any } = { HumanoidRootPart = raiz }
		for _, d in CUERPO do
			local p = nueva(if d[1] == "Head" then "Part" else "MeshPart")
			p.Name = d[1]
			p.Size = d[2]
			p.Color = PIEL
			p.CanCollide = CHOCAN[d[1]] == true
			p.Parent = m
			partesP[d[1]] = p
			local junta = nueva("Motor6D")
			junta.Name = d[4]
			junta.Part0, junta.Part1, junta.C0, junta.C1 = partesP[d[3]], p, d[5], d[6]
			junta.Parent = p
			local a = nueva("Attachment")
			a.Name = d[4] .. "RigAttachment"
			a.CFrame = d[6]
			a.Parent = p
		end
		for nombre, sitio in { RootAttachment = { raiz, CF0 },
			RightGripAttachment = { partesP.RightHand, CFrame.new(0, -0.15, 0) * CFrame.Angles(-math.pi / 2, 0, 0) },
			LeftGripAttachment = { partesP.LeftHand, CFrame.new(0, -0.15, 0) * CFrame.Angles(-math.pi / 2, 0, 0) },
			FaceFrontAttachment = { partesP.Head, CFrame.new(0, 0, -0.6) }, HairAttachment = { partesP.Head, CFrame.new(0, 0.6, 0) },
			HatAttachment = { partesP.Head, CFrame.new(0, 0.6, 0) } } do
			local a = nueva("Attachment")
			a.Name = nombre
			a.CFrame = sitio[2]
			a.Parent = sitio[1]
		end
		local corre = nueva("Sound")
		corre.Name = "Running"
		corre.Looped = true
		corre.Parent = raiz
		local hum = nueva("Humanoid")
		hum.Parent = m
		animador(hum)
		m.PrimaryPart = raiz
		j.Character = m
		m.Parent = espacio
		for _, p in m:GetDescendants() do
			if estado[p].clase.esA.Motor6D then
				juntar(p)
			end
		end
		if j == jugadorLocal then
			camara.CameraSubject = hum
		end
		senalDe(estado[j], "CharacterAdded"):Fire(m)
		senalDe(estado[j], "CharacterAppearanceLoaded"):Fire(m)
		vaciarDiferidos()
		return m
	end

	-- Física de los personajes: anda, choca con paredes (barrido de la raíz), se pega al suelo, cae y salta.
	local function moverHumanoide(hum: any, dt: number)
		local st = estado[hum]
		local modelo = st.padre
		if not modelo or not enEspacio(hum) then
			return
		end
		local raiz = hijoLlamado(modelo, "HumanoidRootPart")
		if not raiz or raiz.Anchored or leer(hum, st, "Health") <= 0 then
			return
		end
		local filtro = RaycastParams.new()
		filtro.FilterDescendantsInstances = { modelo }
		filtro.RespectCanCollide = true
		filtro.CollisionGroup = raiz.CollisionGroup
		if st._meta then -- MoveTo
			local falta = st._meta - raiz.Position
			falta = Vector3.new(falta.X, 0, falta.Z)
			if falta.Magnitude < 0.5 then
				st._meta = nil
				hum:Move(Vector3.zero)
				senalDe(st, "MoveToFinished"):Fire(true)
			elseif ahora - st._desdeMeta > 8 then
				st._meta = nil
				hum:Move(Vector3.zero)
				senalDe(st, "MoveToFinished"):Fire(false)
			else
				hum:Move(falta.Unit)
			end
		end
		local quieto = leer(hum, st, "PlatformStand") or leer(hum, st, "Sit")
		local mueve = if quieto then Vector3.zero else leer(hum, st, "MoveDirection")
		local desp = mueve * leer(hum, st, "WalkSpeed") * dt
		local pos = raiz.Position
		local giro = raiz.CFrame.Rotation
		if desp.Magnitude > 1e-6 then
			for _ = 1, 2 do -- choca, y desliza por la pared una vez
				local golpe = lanzarForma(giro + pos, raiz.Size / 2 * 0.98, nil, desp, filtro)
				if not golpe then
					pos += desp
					break
				end
				local hasta = math.max(0, golpe.Distance - 0.05)
				pos += desp.Unit * hasta
				local n = Vector3.new(golpe.Normal.X, 0, golpe.Normal.Z)
				local resto = desp - desp.Unit * hasta
				desp = if n.Magnitude > 1e-6 then resto - n.Unit * resto:Dot(n.Unit) else Vector3.zero
				if desp.Magnitude < 1e-6 then
					break
				end
			end
		end
		-- Suelo y caída.
		local medio = raiz.Size.Y / 2 + leer(hum, st, "HipHeight")
		local vy = st._vy or 0
		local abajo = lanzarRayo(pos, Vector3.new(0, -(medio + 3 + math.max(0, -vy * dt)), 0), filtro)
		local apoyo = if abajo then abajo.Position.Y else nil
		if mundo.sueloY and (apoyo == nil or apoyo < mundo.sueloY) then
			apoyo = mundo.sueloY
		end
		local g = espacio.Gravity
		local enSuelo = st._enSuelo ~= false
		if leer(hum, st, "Jump") then
			poner(hum, st, "Jump", false)
			if enSuelo and hum:GetStateEnabled(ESTADO_HUM.Jumping) then
				vy = if leer(hum, st, "UseJumpPower") then leer(hum, st, "JumpPower")
					else math.sqrt(2 * g * leer(hum, st, "JumpHeight"))
				cambiarEstado(hum, ESTADO_HUM.Jumping)
			end
		end
		local y = pos.Y
		enSuelo = false
		if vy > 0 then
			y += vy * dt
			vy -= g * dt
		elseif apoyo and y - medio <= apoyo + 0.6 then
			y, vy, enSuelo = apoyo + medio, 0, true
		else
			vy -= g * dt
			y += vy * dt
			if apoyo and y - medio <= apoyo then
				y, vy, enSuelo = apoyo + medio, 0, true
			end
		end
		st._vy, st._enSuelo = vy, enSuelo
		local viejoEstado = st._estado or ESTADO_HUM.Running
		if enSuelo then
			if viejoEstado == ESTADO_HUM.Freefall or viejoEstado == ESTADO_HUM.Jumping then
				cambiarEstado(hum, ESTADO_HUM.Landed)
			end
			cambiarEstado(hum, ESTADO_HUM.Running)
			poner(hum, st, "FloorMaterial", if abajo then abajo.Material else Enum.Material.Plastic)
		else
			if vy <= 0 then
				cambiarEstado(hum, ESTADO_HUM.Freefall)
			end
			poner(hum, st, "FloorMaterial", Enum.Material.Air)
		end
		-- Hacia dónde mira: en primera persona (el jugador local), hacia la cámara; si no, hacia donde anda.
		local mira: any = nil
		if leer(hum, st, "AutoRotate") then
			if jugadorLocal and modelo == jugadorLocal.Character and camara.CameraType == Enum.CameraType.Custom then
				mira = camara.CFrame.LookVector
			elseif mueve.Magnitude > 0.01 then
				mira = mueve
			end
		end
		if mira then
			local plano = Vector3.new(mira.X, 0, mira.Z)
			if plano.Magnitude > 1e-4 then
				giro = CFrame.Angles(0, math.atan2(-plano.X, -plano.Z), 0)
			end
		end
		local nuevaPos = Vector3.new(pos.X, y, pos.Z)
		local vel = (nuevaPos - raiz.Position) / dt
		raiz.CFrame = giro + nuevaPos
		raiz.AssemblyLinearVelocity = Vector3.new(vel.X, vy, vel.Z)
		local rapidez = Vector3.new(vel.X, 0, vel.Z).Magnitude
		if math.abs(rapidez - (st._rapidez or 0)) > 0.01 then
			st._rapidez = rapidez
			if st.senales.Running then
				st.senales.Running:Fire(rapidez)
			end
		end
	end

	-- La cámara de Roblox en primera persona: en la cabeza (la raíz + 1,5 y el CameraOffset), con el giro de
	-- mundo.mirar / mundo.raton. Va en BindToRenderStep con prioridad Camera, como la de verdad.
	local giroCam, cabeceo = 0, 0
	local function camaraRoblox()
		if not mundo.camaraRoblox or camara.CameraType ~= Enum.CameraType.Custom then
			return
		end
		local sujeto = camara.CameraSubject
		local pos
		if sujeto and estado[sujeto] and estado[sujeto].clase.esA.Humanoid then
			local raiz = sujeto.RootPart
			if not raiz then
				return
			end
			pos = raiz.Position + Vector3.new(0, 1.5, 0) + raiz.CFrame:VectorToWorldSpace(sujeto.CameraOffset)
		elseif sujeto and estado[sujeto] and estado[sujeto].clase.esA.BasePart then
			pos = sujeto.Position
		else
			return
		end
		local cf = CFrame.new(pos) * CFrame.fromOrientation(cabeceo, giroCam, 0)
		camara.CFrame = cf
		camara.Focus = cf
	end
	S("RunService"):BindToRenderStep("CamaraDeRoblox", Enum.RenderPriority.Camera.Value, camaraRoblox)

	-- Controles de Roblox: WASD (o mundo.andar) mueven al personaje local según la cámara; espacio salta.
	local andarA: any = nil
	local movidoAntes = false
	local function controlar()
		if not mundo.controles or not jugadorLocal then
			return
		end
		local m = jugadorLocal.Character
		local hum = m and m:FindFirstChildOfClass("Humanoid")
		if not hum then
			return
		end
		local K = Enum.KeyCode
		local x = (if pulsadas[K.D] or pulsadas[K.Right] then 1 else 0) - (if pulsadas[K.A] or pulsadas[K.Left] then 1 else 0)
		local z = (if pulsadas[K.S] or pulsadas[K.Down] then 1 else 0) - (if pulsadas[K.W] or pulsadas[K.Up] then 1 else 0)
		local dir = Vector3.zero
		if x ~= 0 or z ~= 0 then
			local mira = camara.CFrame.LookVector
			local frente = Vector3.new(mira.X, 0, mira.Z)
			frente = if frente.Magnitude > 1e-4 then frente.Unit else -Vector3.zAxis
			local derecha = frente:Cross(Vector3.yAxis)
			dir = (derecha * x - frente * z).Unit
		elseif andarA then
			dir = andarA
		end
		if dir.Magnitude > 0 or movidoAntes then
			hum:Move(dir)
			movidoAntes = dir.Magnitude > 0
		end
	end

	------------------------------------------------------------------------------------------------------------------
	-- El fotograma, en el orden de Roblox: lo que llega por red, los controles, RenderStepped (BindToRenderStep por
	-- prioridad, la cámara de Roblox en Camera = 200, y luego la señal), Stepped, la física (personajes, juntas,
	-- sonidos, animaciones), los tweens, Heartbeat y al final las tareas que tocan.
	local RS = S("RunService")
	local senalesRS = estado[RS]
	function mundo.paso(dt: number?)
		local d = dt or mundo.dt
		assert(d > 0, "mundo.paso: dt tiene que ser mayor que 0")
		ahora += d
		cuadro += 1
		local llegan = red
		red = {}
		for _, f in llegan do
			f()
		end
		controlar()
		for _, r in table.clone(renders) do
			if table.find(renders, r) then
				ejecutar(r.fn, d)
			end
		end
		senalDe(senalesRS, "RenderStepped"):Fire(d)
		senalDe(senalesRS, "PreRender"):Fire(d)
		vaciarDiferidos()
		senalDe(senalesRS, "Stepped"):Fire(ahora, d)
		senalDe(senalesRS, "PreSimulation"):Fire(d)
		for _, h in table.clone(humanoides) do
			moverHumanoide(h, d)
		end
		resolverJuntas()
		for _, s in sonidos do
			local st = estado[s]
			if leer(s, st, "Playing") then
				local t = leer(s, st, "TimePosition") + d * leer(s, st, "PlaybackSpeed")
				local largo = s.TimeLength
				if t >= largo then
					if leer(s, st, "Looped") and largo > 0 then
						t %= largo
						senalDe(st, "DidLoop"):Fire(leer(s, st, "SoundId"), 1)
					else
						poner(s, st, "Playing", false)
						t = largo
						senalDe(st, "Ended"):Fire(leer(s, st, "SoundId"))
					end
				end
				poner(s, st, "TimePosition", t)
			end
		end
		for _, p in table.clone(pistas) do
			local st = estado[p]
			if leer(p, st, "IsPlaying") then
				local t = leer(p, st, "TimePosition") + d * leer(p, st, "Speed")
				local largo = leer(p, st, "Length")
				if t >= largo then
					if leer(p, st, "Looped") then
						t %= math.max(largo, 1e-3)
						senalDe(st, "DidLoop"):Fire()
					else
						t = largo
						p:Stop()
					end
				end
				poner(p, st, "TimePosition", t)
			end
		end
		for _, tw in table.clone(tweens) do
			if table.find(tweens, tw) then
				moverTween(tw)
			end
		end
		senalDe(senalesRS, "Heartbeat"):Fire(d)
		senalDe(senalesRS, "PostSimulation"):Fire(d)
		despertar()
		vaciarDiferidos()
	end
	-- Varios pasos seguidos; `cada(n)` se llama tras cada uno (para mirar cada fotograma).
	function mundo.correr(segundos: number, dt: number?, cada: ((n: number) -> ())?)
		local d = dt or mundo.dt
		local n = math.max(1, math.floor(segundos / d + 0.5))
		for i = 1, n do
			mundo.paso(d)
			if cada then
				cada(i)
			end
		end
	end
	function mundo.ahora(): number
		return ahora
	end

	------------------------------------------------------------------------------------------------------------------
	-- Lo que usa el banco.
	function mundo.cargar(ruta: string, falsos: { [string]: any }?)
		for k, v in falsos or {} do
			mundo.falsos[k] = v
		end
		local nodo = nodoDeRuta(ruta)
		assert(nodo, `mundo.cargar: no encuentro {ruta}`)
		local valor = requerir(nodo)
		vaciarDiferidos()
		return valor
	end
	function mundo.falso(nombre: string, valor: any)
		mundo.falsos[nombre] = valor
	end
	function mundo.nodo(ruta: string): any? -- el script falso de un archivo (para mirar sus hijos o su Parent)
		return nodoDeRuta(ruta)
	end
	mundo.personaje = crearPersonaje
	function mundo.jugador(nombre: string?): any
		return nuevoJugador(nombre)
	end
	-- Una pieza anclada que choca, en el mundo: `donde` es un CFrame o una posición.
	function mundo.caja(donde: any, tam: any?, props: { [string]: any }?): any
		local p = nueva("Part")
		p.Name = "Caja"
		p.Anchored = true
		p.Size = tam or Vector3.new(4, 1, 4)
		p.CFrame = if typeofFalso(donde) == "CFrame" then donde else CFrame.new(donde)
		for k, v in props or {} do
			p[k] = v
		end
		if p.Parent == nil then
			p.Parent = espacio
		end
		return p
	end
	local function entrada(tecla: any, estadoEntrada: any, extra: { [string]: any }?): any
		local i = pulsadas[tecla] or nueva("InputObject")
		if deTipo(tecla, "UserInputType") then
			i.UserInputType = tecla
		else
			i.KeyCode = tecla
			local n = tecla.Name
			local mando = string.match(n, "^Button") or string.match(n, "^Thumbstick") or string.match(n, "^DPad")
			i.UserInputType = if mando then Enum.UserInputType.Gamepad1 else Enum.UserInputType.Keyboard
		end
		i.UserInputState = estadoEntrada
		for k, v in extra or {} do
			i[k] = v
		end
		return i
	end
	local function pasarAcciones(i: any)
		for _, a in table.clone(acciones) do
			local vale = false
			for _, e in a.entradas do
				if e == i.KeyCode or e == i.UserInputType then
					vale = true
					break
				end
			end
			if vale then
				local r
				local co = hilo(function()
					r = a.fn(a.nombre, i.UserInputState, i)
				end)
				reanudar(co)
				if r ~= Enum.ContextActionResult.Pass then
					return
				end
			end
		end
	end
	local UIS = S("UserInputService")
	function mundo.pulsar(tecla: any, extra: { [string]: any }?): any
		local i = entrada(tecla, Enum.UserInputState.Begin, extra)
		pulsadas[tecla] = i
		if ultimoTipo ~= i.UserInputType then
			ultimoTipo = i.UserInputType
			senalDe(estado[UIS], "LastInputTypeChanged"):Fire(ultimoTipo)
		end
		senalDe(estado[UIS], "InputBegan"):Fire(i, false)
		pasarAcciones(i)
		if tecla == Enum.KeyCode.Space or tecla == Enum.KeyCode.ButtonA then
			senalDe(estado[UIS], "JumpRequest"):Fire()
			local m = mundo.controles and jugadorLocal and jugadorLocal.Character
			local hum = m and m:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.Jump = true
			end
		end
		vaciarDiferidos()
		return i
	end
	function mundo.soltar(tecla: any)
		local i = pulsadas[tecla] or entrada(tecla, Enum.UserInputState.End)
		pulsadas[tecla] = nil
		i.UserInputState = Enum.UserInputState.End
		senalDe(estado[UIS], "InputEnded"):Fire(i, false)
		pasarAcciones(i)
		vaciarDiferidos()
	end
	-- Mueve el ratón (gira la cámara de Roblox como el de verdad, ~0,0035 rad por píxel).
	function mundo.raton(dx: number, dy: number)
		deltaRaton = Vector2.new(dx, dy)
		local i = nueva("InputObject")
		i.UserInputType = Enum.UserInputType.MouseMovement
		i.UserInputState = Enum.UserInputState.Change
		i.Delta = Vector3.new(dx, dy, 0)
		senalDe(estado[UIS], "InputChanged"):Fire(i, false)
		giroCam -= dx * 0.0035
		cabeceo = math.clamp(cabeceo - dy * 0.0035, -1.4, 1.4)
		vaciarDiferidos()
	end
	-- Hacia dónde mira la cámara de Roblox: giro (radianes, 0 = hacia -Z) y cabeceo (positivo = arriba).
	function mundo.mirar(giro: number, arriba: number?)
		giroCam, cabeceo = giro, math.clamp(arriba or 0, -1.4, 1.4)
	end
	-- Anda hacia `dir` (en el mundo) como si se mantuviera la tecla; nil para parar.
	function mundo.andar(dir: any?)
		andarA = if dir and dir.Magnitude > 0 then Vector3.new(dir.X, 0, dir.Z).Unit else nil
	end
	-- Un clic (o toque) en un botón: MouseButton1Down, MouseButton1Up, MouseButton1Click y Activated.
	function mundo.clic(boton: any)
		local st = estado[boton]
		local i = nueva("InputObject")
		i.UserInputType = Enum.UserInputType.MouseButton1
		i.UserInputState = Enum.UserInputState.Begin
		senalDe(st, "InputBegan"):Fire(i)
		senalDe(st, "MouseButton1Down"):Fire(0, 0)
		i.UserInputState = Enum.UserInputState.End
		senalDe(st, "InputEnded"):Fire(i)
		senalDe(st, "MouseButton1Up"):Fire(0, 0)
		senalDe(st, "MouseButton1Click"):Fire()
		senalDe(st, "Activated"):Fire(i, 1)
		vaciarDiferidos()
	end
	-- El tamaño de la pantalla (y lo que tapa el teléfono: { arriba, abajo, izquierda, derecha }).
	function mundo.pantalla(ancho: number, alto: number, m: { [string]: number }?)
		margenes = { arriba = 0, abajo = 0, izquierda = 0, derecha = 0 }
		for k, v in m or {} do
			margenes[k] = v
		end
		camara.ViewportSize = Vector2.new(ancho, alto)
		for _, g in pantallas do
			cambiado(g, estado[g], "AbsoluteSize")
			cambiado(g, estado[g], "AbsolutePosition")
		end
		vaciarDiferidos()
	end
	-- Un teléfono: pantalla pequeña, táctil, sin teclado ni ratón y la barra de inicio abajo.
	function mundo.movil()
		UIS.TouchEnabled, UIS.KeyboardEnabled, UIS.MouseEnabled = true, false, false
		UIS.PreferredInput = Enum.PreferredInput.Touch
		ultimoTipo = Enum.UserInputType.Touch
		mundo.pantalla(640, 360, { abajo = 20, izquierda = 30, derecha = 30 })
	end
	function mundo.remoto(nombre: string): any
		return assert(carpetaRemotos and carpetaRemotos:FindFirstChild(nombre), `no hay remoto {nombre}`)
	end
	-- Lo que se ha mandado por un remoto (cada vez, sus argumentos empaquetados con table.pack y `quien`).
	function mundo.enviados(nombre: string): { any }
		return estado[mundo.remoto(nombre)]._enviados or {}
	end
	-- El servidor le dice algo al cliente por un remoto: dispara OnClientEvent.
	function mundo.alCliente(nombre: string, ...)
		senalDe(estado[mundo.remoto(nombre)], "OnClientEvent"):Fire(...)
		vaciarDiferidos()
	end
	function mundo.sonando(): { any } -- los Sound que suenan ahora
		local l = {}
		for _, s in sonidos do
			if s.Playing then
				table.insert(l, s)
			end
		end
		return l
	end
	mundo.sonidosLocales = sonidosLocales
	mundo.compras = compras
	-- El estado interno de una instancia (para mirarlo en un banco: _emitidas de un ParticleEmitter, _tw de un tween...).
	function mundo.interno(inst: any): any
		return estado[inst]
	end
	-- ¿Hay un NaN o un infinito en este valor? (número, Vector3, Vector2, CFrame, UDim2, Color3)
	function mundo.roto(v: any): boolean
		local function n(x: number): boolean
			return x ~= x or x == INFINITO or x == -INFINITO
		end
		local t = typeofFalso(v)
		if t == "number" then
			return n(v)
		elseif t == "Vector3" then
			return n(v.X) or n(v.Y) or n(v.Z)
		elseif t == "Vector2" then
			return n(v.X) or n(v.Y)
		elseif t == "CFrame" then
			local c = { v:GetComponents() }
			for _, x in c do
				if n(x) then
					return true
				end
			end
			return false
		elseif t == "UDim2" then
			return n(v.X.Scale) or n(v.X.Offset) or n(v.Y.Scale) or n(v.Y.Offset)
		elseif t == "Color3" then
			return n(v.R) or n(v.G) or n(v.B)
		end
		return false
	end
	-- Las piezas que chocan (CanCollide) y se meten en `parte` más de `margen` studs (para "que nada atraviese").
	function mundo.solapes(parte: any, ignorar: { any }?, margen: number?): { any }
		local params = OverlapParams.new()
		params.FilterDescendantsInstances = ignorar or {}
		params.RespectCanCollide = true
		local m = (margen or 0.05) * 2
		local tam = parte.Size - Vector3.new(m, m, m)
		local cf = parte.CFrame
		return solapes(params, function(p)
			return p ~= parte and solapan(cf, tam:Max(Vector3.zero) / 2, p.CFrame, p.Size / 2)
		end)
	end

	mundo.global = base -- game, workspace, Instance, Vector3, Enum, task... (lo que ve un módulo cargado)
	mundo.game = juego
	mundo.workspace = espacio
	mundo.camara = camara
	mundo.jugadorLocal = jugadorLocal
	mundo.servicio = S
	mundo.task = task
	mundo.typeof = typeofFalso
	mundo.Instance = base.Instance
	vaciarDiferidos()
	return mundo
end
