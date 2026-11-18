-- Banco de Mochila.sitioLibre (pulido: lo tirado no atraviesa paredes). Ejecutar desde la raíz:
-- lune run tests/bancos/tirar-paredes.luau (lo corre tests/regressions.luau).
--   Una llave tirada contra la puerta cerrada de su sala caía dentro y la partida se atascaba. sitioLibre se saca del
--   texto de Mochila (Mochila necesita Cargar, Mapa, Muerte...) y se corre en el Roblox de mentira con una pared de
--   1 stud, la carpeta de objetos, un pesado y un personaje en medio.
-- Si algo no se cumple, termina con error.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local crearMundo = require("./_roblox")

local cuentas = 0
local function igual(actual, esperado, etiqueta: string)
	assert(actual == esperado, `{etiqueta}: esperado {tostring(esperado)}, recibido {tostring(actual)}`)
	cuentas += 1
end
local function cerca(actual: number, esperado: number, etiqueta: string)
	assert(math.abs(actual - esperado) <= 1e-3, `{etiqueta}: esperado {esperado}, recibido {actual}`)
	cuentas += 1
end

local fuente = fs.readFile("src/juego/servidor/Mochila.luau")
local i = string.find(fuente, "local DESPEGUE", 1, true)
local f = string.find(fuente, "-- fin de sitioLibre", 1, true)
assert(i and f, "no encuentro sitioLibre en Mochila")

local m = crearMundo({ servidor = true })
local g = m.global
local Vector3, CFrame, Instance = g.Vector3, g.CFrame, g.Instance
local w = g.workspace
local objetos = Instance.new("Folder")
objetos.Name = "Objetos"
objetos.Parent = w
local Mochila = {}
local entorno = { Mochila = Mochila, carpeta = objetos, Players = m.servicio("Players") }
for k, v in g do -- luau.load copia el entorno: sin __index, todo a mano
	entorno[k] = v
end
luau.load(string.sub(fuente, i, f - 1), { debugName = "sitioLibre", environment = entorno })()

-- Una pared (o puerta cerrada) de 1 stud en x = 1..2.
local pared = m.caja(CFrame.new(1.5, 3, 0), Vector3.new(1, 8, 8))
local desde, hasta = Vector3.new(0, 3, 0), Vector3.new(3, 3, 0)

local p, choca = Mochila.sitioLibre(desde, hasta)
igual(choca, true, "pared: choca")
cerca(p.X, 1 - 0.6, "pared: se queda de este lado, despegado")
cerca(p.Y, 3, "pared: a la misma altura")

-- Sin nada en medio, el punto pedido.
local q, chocaQ = Mochila.sitioLibre(desde, Vector3.new(-3, 3, 0))
igual(chocaQ, false, "libre: no choca")
igual(q, Vector3.new(-3, 3, 0), "libre: el punto pedido")
local r, chocaR = Mochila.sitioLibre(desde, desde)
igual(chocaR, false, "mismo punto: no choca")
igual(r, desde, "mismo punto: el mismo")

-- Una puerta abierta (sin choque) no para.
pared.CanCollide = false
igual(select(2, Mochila.sitioLibre(desde, hasta)), false, "sin CanCollide: no para")
pared.CanCollide = true

-- Lo suelto, lo pesado y los personajes no cuentan: la pared de detrás sí.
local suelto = m.caja(CFrame.new(0.5, 3, 0), Vector3.new(0.3, 2, 2))
suelto.Parent = objetos
local pesados = Instance.new("Folder")
pesados.Name = "Pesados"
pesados.Parent = w
local tabla = m.caja(CFrame.new(0.7, 3, 0), Vector3.new(0.2, 2, 2))
tabla.Parent = pesados
local a = m.jugador("A")
a:LoadCharacter()
assert(a.Character, "el jugador tiene personaje")
local raiz = a.Character:FindFirstChild("HumanoidRootPart")
raiz.CFrame = CFrame.new(0.85, 3, 0)
local p2 = Mochila.sitioLibre(desde, hasta)
cerca(p2.X, 1 - 0.6, "filtros: solo la pared")

print(`tirar-paredes: {cuentas} comprobaciones bien.`)
