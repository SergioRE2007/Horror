-- Día y noche. El estado va en atributos del workspace para que el cliente pinte la luz (Ambiente):
--   Fase ("Dia" o "Noche"), Noche (número de la noche que viene o en la que estamos), FaseInicio y FaseFin (hora del
--   servidor, workspace:GetServerTimeNow()).
-- Día 1 → noche 1 → día 2 → noche 2... Quien quiera enterarse de los cambios usa Ciclo.alCambiar.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Prueba = require(ReplicatedStorage.Shared.Prueba)

local Ciclo = {}

local fase, noche, fin = "Dia", 1, 0
local oyentes: { (fase: string, noche: number) -> () } = {}

local function duracion(cual: string): number
	local prueba = if Prueba.activa() then Config.Test[cual] else nil
	return prueba or Config.Ciclo[cual]
end

local function poner(nuevaFase: string, n: number)
	fase, noche = nuevaFase, n
	local ahora = workspace:GetServerTimeNow()
	fin = ahora + duracion(fase)
	workspace:SetAttribute("Fase", fase)
	workspace:SetAttribute("Noche", noche)
	workspace:SetAttribute("FaseInicio", ahora)
	workspace:SetAttribute("FaseFin", fin)
	for _, fn in oyentes do
		task.spawn(fn, fase, noche)
	end
end

function Ciclo.alCambiar(fn: (fase: string, noche: number) -> ())
	table.insert(oyentes, fn)
end

function Ciclo.fase(): (string, number)
	return fase, noche
end

-- Salta ya a esa fase (solo el modo de pruebas).
function Ciclo.forzar(nuevaFase: string)
	poner(nuevaFase, noche)
end

-- Acaba ya la fase de ahora como si se hubiera acabado el tiempo (solo el modo de pruebas: amanecer de verdad).
function Ciclo.saltar()
	fin = workspace:GetServerTimeNow()
end

-- Vuelve al principio del día de esta noche (cuando mueren todos).
function Ciclo.reiniciarDia()
	poner("Dia", noche)
end

-- `primera`: la noche del día con el que se empieza (la guardada de la partida, ver Partida).
function Ciclo.start(primera: number?)
	task.defer(poner, "Dia", primera or 1) -- en diferido: que los demás sistemas se apunten antes con alCambiar
	task.spawn(function()
		while true do
			task.wait(0.25)
			if fin > 0 and workspace:GetServerTimeNow() >= fin then
				if fase == "Dia" then
					poner("Noche", noche)
				else
					poner("Dia", noche + 1)
				end
			end
		end
	end)
end

return Ciclo
