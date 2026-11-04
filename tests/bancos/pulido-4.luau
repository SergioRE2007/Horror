-- Banco del pulido 14.9.1 (grupo 4). Ejecutar desde la raíz: lune run tests/bancos/pulido-4.luau (lo corre
-- tests/regressions.luau).
--   Caza.pasoHacia: el camino calculado se reutiliza (antes, un ComputeAsync en cada paso). Se rehace solo si el
--   destino se aleja, pasa RUTA_VIDA, se acaba o se tapa (Blocked). Sacada del texto con un PathfindingService falso
--   que cuenta las llamadas: Caza necesita Roblox (Casa, Mapa, Muerte...).
-- Si algo no se cumple, termina con error.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local V3 = roblox.Vector3

local cuentas = 0
local function comprueba(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end

local fuente = fs.readFile("src/juego/servidor/Caza.luau")
local function trozo(desde: string, hasta: string): string
	local i = string.find(fuente, desde, 1, true)
	assert(i, `no encuentro {desde}`)
	local f = string.find(fuente, hasta, i, true)
	assert(f, `no encuentro {hasta}`)
	return string.sub(fuente, i, f - 1)
end

-- Un PathfindingService de mentira: un camino en L (por la esquina de (10, 0, 0)), contando los ComputeAsync.
local calculos = 0
local bloqueos: { () -> () } = {}
local reloj = 0
local function nuevoCamino()
	local p = { Status = nil, puntos = {} }
	p.Blocked = { Connect = function(_, fn)
		table.insert(bloqueos, fn)
	end }
	function p.ComputeAsync(self, desde: any, hasta: any)
		calculos += 1
		self.Status = "Success"
		local esquina = V3.new(10, desde.Y, desde.Z)
		self.puntos = { desde }
		for k = 1, 3 do
			table.insert(self.puntos, desde:Lerp(esquina, k / 3))
		end
		for k = 1, 3 do
			table.insert(self.puntos, esquina:Lerp(hasta, k / 3))
		end
	end
	function p.GetWaypoints(self)
		local lista = {}
		for _, q in self.puntos do
			table.insert(lista, { Position = q })
		end
		return lista
	end
	function p.Destroy() end
	return p
end

local trozos = "local Caza = {}\n"
	.. trozo("local caminos:", "local filtroVista")
	.. "local function plano(v) return Vector3.new(v.X, 0, v.Z) end\n"
	.. "local function libre() return false end\n" -- siempre algo en medio: va por camino
	.. "local function sinBichos() return {} end\n"
	.. "local function abrirPuertasCerca() end\n"
	.. trozo("function Caza.pasoHacia(", "function Caza.cerca(")
	.. "return Caza"
local Caza = luau.load(trozos, {
	debugName = "Caza.pasoHacia",
	environment = {
		Vector3 = V3,
		Enum = { PathStatus = { Success = "Success" } },
		PathfindingService = { CreatePath = function()
			return nuevoCamino()
		end },
		os = { clock = function()
			return reloj
		end },
		math = math,
		pcall = pcall,
		table = table,
		setmetatable = setmetatable,
	},
})()

-- Un bicho de mentira: anda hacia donde le mandan (MoveTo) un poco en cada paso.
local bicho = {
	raiz = { Position = V3.new(0, 3, 0) },
	o = { Altura = 3 },
	ultimo = nil :: any,
}
bicho.humanoide = { MoveTo = function(_, p: any)
	bicho.ultimo = p
end }
function bicho.quieto()
	return false
end
function bicho.suelo(self)
	return self.raiz.Position - V3.new(0, 3, 0)
end
local function paso(destino: any, dt: number)
	Caza.pasoHacia(bicho, destino)
	reloj += dt
	-- Anda 2 studs hacia donde le mandó.
	local suelo = bicho:suelo()
	local d = bicho.ultimo - suelo
	local mover = if d.Magnitude > 2 then d.Unit * 2 else d
	bicho.raiz.Position += V3.new(mover.X, 0, mover.Z)
end

local destino = V3.new(10, 0, 10)
paso(destino, 0.25)
comprueba(calculos == 1, "camino: el primer paso lo calcula")
comprueba((bicho.ultimo - V3.new(0, 0, 0)).Magnitude > 3, "camino: va a un punto que no ha alcanzado")
paso(destino, 0.25)
paso(destino, 0.25)
comprueba(calculos == 1, "camino: con el destino quieto no lo rehace en cada paso")
paso(destino, 0.25)
paso(destino, 0.25)
paso(destino, 0.25)
comprueba(calculos == 2, "camino: pasado RUTA_VIDA lo rehace")
local antes = calculos
paso(destino + V3.new(0.5, 0, 0), 0.05)
comprueba(calculos == antes, "camino: un destino que se mueve poco no lo rehace")
paso(V3.new(-20, 0, 30), 0.05)
comprueba(calculos == antes + 1, "camino: un destino que se aleja lo rehace")
antes = calculos
for _, fn in bloqueos do
	fn()
end
paso(V3.new(-20, 0, 30), 0.05)
comprueba(calculos == antes + 1, "camino: tapado (Blocked) lo rehace")
-- Sigue los puntos en orden: nunca le manda a uno a menos de 3 studs de donde está (salvo el destino al final).
local cerca = 0
for _ = 1, 40 do
	local desde = bicho:suelo()
	paso(destino, 0.1)
	if bicho.ultimo ~= destino and (bicho.ultimo - desde).Magnitude <= 3 then
		cerca += 1
	end
end
comprueba(cerca == 0, "camino: siempre al siguiente punto que no ha alcanzado")
comprueba((bicho:suelo() - destino).Magnitude < 1, "camino: llega al destino")

print(`pulido-4: {cuentas} comprobaciones bien`)
