-- Banco del pulido 14.9.1 (grupo 2). Ejecutar desde la raíz: lune run tests/bancos/pulido-2.luau (lo corre
-- tests/regressions.luau). Con el Roblox de mentira (tests/bancos/_roblox.luau) y el lobby (lobby.project.json):
--   CochesUi: sentado en un coche su "Get in" se apaga en este cliente, se vuelve a apagar si el servidor lo enciende
--   mientras sigues sentado, y se enciende al bajarte o al reaparecer.
-- Si algo no se cumple, termina con error.
local crearMundo = require("./_roblox")

local cuentas = 0
local function comprueba(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end

local m = crearMundo({ proyecto = "lobby.project.json" })
local g = m.global
local Instance, Vector3, CFrame = g.Instance, g.Vector3, g.CFrame

-- Un coche como los de Coches (servidor): modelo con la etiqueta Coche, Carroceria con el prompt y dos asientos.
local function coche(nombre: string, x: number)
	local modelo = Instance.new("Model")
	modelo.Name = nombre
	local carroceria = m.caja(CFrame.new(x, 2, 0), Vector3.new(6, 3, 12))
	carroceria.Name = "Carroceria"
	carroceria.Parent = modelo
	modelo.PrimaryPart = carroceria
	local prompt = Instance.new("ProximityPrompt")
	prompt.Parent = carroceria
	local asientos = {}
	for i = 1, 2 do
		local s = Instance.new("Seat")
		s.Name = `Asiento{i}`
		s.Anchored = true
		s.CFrame = CFrame.new(x + (if i == 1 then -1.5 else 1.5), 3, 0)
		s.Parent = modelo
		table.insert(asientos, s)
	end
	modelo:AddTag("Coche")
	modelo.Parent = g.workspace
	return prompt, asientos
end

m.caja(CFrame.new(0, -0.5, 0), Vector3.new(200, 1, 200))
local promptA, asientosA = coche("CocheA", 0)
local promptB, asientosB = coche("CocheB", 20)
m.personaje()
local CochesUi = m.cargar("src/lobby/cliente/CochesUi", { Sonido = { precargar = function() end, tocar = function() end } })
CochesUi.start()
m.correr(0.5)

local jugador = m.jugadorLocal
local humanoide = jugador.Character:FindFirstChildOfClass("Humanoid")
comprueba(promptA.Enabled and promptB.Enabled, "de pie: los dos prompts encendidos")

humanoide.SeatPart = asientosA[1]
m.correr(0.1)
comprueba(not promptA.Enabled, "sentado en A: su prompt fuera")
comprueba(promptB.Enabled, "sentado en A: el de B sigue")

promptA.Enabled = true -- el servidor lo enciende (rehacer) mientras sigues sentado
m.correr(0.1)
comprueba(not promptA.Enabled, "sentado en A: si el servidor lo enciende, se vuelve a apagar")

humanoide.SeatPart = asientosB[2]
m.correr(0.1)
comprueba(promptA.Enabled and not promptB.Enabled, "de A a B: A encendido y B fuera")

humanoide.SeatPart = nil
m.correr(2)
comprueba(promptA.Enabled and promptB.Enabled, "al bajarte: los dos encendidos")
promptB.Enabled = false -- el servidor lo apaga (coche lleno) estando de pie: no se toca
m.correr(0.1)
comprueba(not promptB.Enabled, "de pie: lo que diga el servidor manda")
promptB.Enabled = true

-- Reaparecer sentado (el personaje de antes se va sin cambiar de SeatPart): el prompt vuelve.
humanoide.SeatPart = asientosA[2]
m.correr(0.1)
comprueba(not promptA.Enabled, "sentado otra vez en A")
local viejo = jugador.Character
m.personaje()
m.correr(0.5)
comprueba(jugador.Character ~= viejo, "personaje nuevo")
comprueba(promptA.Enabled, "al reaparecer: el prompt de A encendido")

print(`pulido-2: todo bien ({cuentas} comprobaciones).`)
