-- Banco del cielo (Ambiente, pulido): la exposición y la franja cálida siguen al sol, no a la fase.
--   La exposición no sube con sol > Pleno (atardecer sin pico de luz antes de "NIGHT n") y no baja de la de noche al
--   amanecer hasta que el sol empieza a salir (los últimos segundos de la noche no se quedan negros).
--   Luz del sol (Brightness · sol · 2^exposición) nunca más que a mediodía; Brightness nunca más que el de día con sol.
--   La franja: 0 a pleno día, a plena noche y con el cielo cubierto; máxima con el sol en el horizonte.
-- Ejecutar desde la raíz: lune run tests/bancos/cielo.luau (lo corre regressions.luau).
local crearMundo = require("./_roblox")

local cuentas = 0
local function si(cond: boolean, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end

local m = crearMundo()
local Ambiente = m.cargar("src/juego/cliente/Ambiente")
local Config = m.cargar("src/shared/Config")
local SOL = Config.Cielo.Sol
local EPS = 1e-6

-- El día o la noche de punta a punta, en pasos pequeños (copias: Ambiente.valores rellena siempre la misma tabla).
local function recorrido(fase: string, nublado: number?): { any }
	local lista = {}
	for i = 0, 1000 do
		local copia = {}
		for k, x in Ambiente.valores(fase, i / 1000, nublado) do
			copia[k] = x
		end
		table.insert(lista, copia)
	end
	return lista
end
local dia, noche = recorrido("Dia"), recorrido("Noche")
local mediodia = recorrido("Mediodia")[1] -- sin fase: mediodía
local NOCHE_EXP, DIA_EXP = noche[500].Exposicion, mediodia.Exposicion
local luzMediodia = mediodia.Brightness * mediodia.sol * 2 ^ mediodia.Exposicion
si(mediodia.sol == 1 and mediodia.franja == 0, "cielo: a mediodía, sol entero y sin franja")
si(NOCHE_EXP > DIA_EXP + 1, "cielo: de noche la exposición es mucho más alta que de día")

-- La hora sigue igual que antes y sin saltos entre fases (el reparto de momento() no se ha tocado).
si(math.abs(dia[1].hora - 6.5) < EPS and math.abs(dia[#dia].hora - 18.5) < EPS, "cielo: el día va de 6,5 a 18,5")
si(math.abs(noche[1].hora - 18.5) < EPS and math.abs(noche[#noche].hora - 6.5) < EPS, "cielo: la noche, de 18,5 a 6,5")
si(math.abs(dia[#dia].Exposicion - noche[1].Exposicion) < 0.01, "cielo: sin salto de exposición al anochecer")
si(math.abs(noche[#noche].Exposicion - dia[1].Exposicion) < 0.01, "cielo: sin salto de exposición al amanecer")
si(math.abs(dia[#dia].Brightness - noche[1].Brightness) < 0.01, "cielo: sin salto de brillo al anochecer")
si(math.abs(noche[#noche].Brightness - dia[1].Brightness) < 0.01, "cielo: sin salto de brillo al amanecer")

-- Atardecer: la exposición no sube mientras el sol esté alto, y luego solo sube (oscurece seguido).
for i, v in dia do
	if v.sol > SOL.Pleno + EPS then
		si(math.abs(v.Exposicion - DIA_EXP) < EPS, `cielo: con sol {v.sol} la exposición ya sube (a las {v.hora})`)
	end
	local luz = v.Brightness * v.sol * 2 ^ v.Exposicion
	si(luz <= luzMediodia + EPS, `cielo: más luz de sol que a mediodía a las {v.hora} ({luz} > {luzMediodia})`)
	if v.sol > 0 then
		si(v.Brightness <= mediodia.Brightness + EPS, `cielo: más Brightness que de día con sol a las {v.hora}`)
	end
	if i > 1 and v.hora > 12 then
		si(v.Exposicion >= dia[i - 1].Exposicion - EPS, `cielo: la exposición baja al atardecer a las {v.hora}`)
	end
end
-- Amanecer: la exposición se queda en la de noche hasta que el sol empieza a salir, y luego solo baja.
local salio = false
for i, v in noche do
	if v.sol > 0 then
		salio = salio or v.hora < 12 -- (al empezar la noche aún queda algo del sol que se pone)
		si(v.Brightness <= mediodia.Brightness + EPS, `cielo: más Brightness que de día con sol a las {v.hora}`)
	end
	if v.hora > 12 then
		continue
	elseif not salio then
		si(math.abs(v.Exposicion - NOCHE_EXP) < EPS, `cielo: la exposición cae con el sol aún abajo a las {v.hora}`)
	elseif i > 1 then
		si(v.Exposicion <= noche[i - 1].Exposicion + EPS, `cielo: la exposición sube al amanecer a las {v.hora}`)
	end
end
si(salio, "cielo: el sol sale antes de acabar la noche")

-- Las horas del sol: bajo el horizonte de noche cerrada, entero a pleno día, a medias en el horizonte.
si(Ambiente.sol(SOL.Sale - SOL.Margen) == 0 and Ambiente.sol(3) == 0 and Ambiente.sol(22) == 0, "cielo: sol 0 de noche")
si(Ambiente.sol(SOL.Sale + SOL.Margen) == 1 and Ambiente.sol(12) == 1, "cielo: sol 1 de día")
si(math.abs(Ambiente.sol(SOL.Sale) - 0.5) < EPS and math.abs(Ambiente.sol(SOL.Pone) - 0.5) < EPS,
	"cielo: sol a medias en el horizonte")

-- La franja: 0 a pleno día y plena noche, máxima en el horizonte, la del ocaso por la tarde; nublado la apaga.
local ancho = Config.Cielo.Alba.Ancho
for _, h in { 12, 9, 15, SOL.Pone + ancho, 21, 0, 3, SOL.Sale - ancho } do
	si(Ambiente.franja(h, 0) == 0, `cielo: franja a las {h}`)
end
local wa, tardeA = Ambiente.franja(SOL.Sale, 0)
local wp, tardeP = Ambiente.franja(SOL.Pone, 0)
si(math.abs(wa - 1) < EPS and not tardeA, "cielo: franja del alba entera con el sol saliendo")
si(math.abs(wp - 1) < EPS and tardeP, "cielo: franja del ocaso entera con el sol poniéndose")
local media = Ambiente.franja(SOL.Sale + 0.3, 0)
si(media < 1 and media > 0.5, "cielo: franja en campana")
local maxDia, maxNoche = 0, 0
for _, v in dia do
	maxDia = math.max(maxDia, v.franja)
end
for _, v in noche do
	maxNoche = math.max(maxNoche, v.franja)
end
si(maxDia > 0.9 and maxNoche > 0.9, "cielo: se ve la franja al atardecer y al amanecer")
for _, v in recorrido("Dia", 1) do
	si(v.franja == 0 and v.Glare == 0, "cielo: con el cielo cubierto, atardecer sin franja")
end
for _, v in recorrido("Noche", 1) do
	si(v.franja == 0 and v.Glare == 0, "cielo: con el cielo cubierto, amanecer gris")
end
-- Con franja, la niebla del ocaso tira a rojo (más rojo que azul, al revés que la de noche).
local ocaso = Ambiente.valores("Dia", (SOL.Pone - 6.5) / 12)
si(ocaso.franja > 0.9 and ocaso.Niebla.R > ocaso.Niebla.B, "cielo: niebla del ocaso rojiza")
local alba = Ambiente.valores("Noche", 0.9 + (SOL.Sale - 2) / 4.5 * 0.1)
si(alba.franja > 0.9 and alba.Niebla.R > alba.Niebla.B, "cielo: niebla del alba cálida")

print(`cielo: {cuentas} comprobaciones bien.`)
