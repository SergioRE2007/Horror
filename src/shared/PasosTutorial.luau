-- Los pasos del tutorial (14.2 / 13.1): qué toca enseñar ahora a un jugador. Sin nada de Roblox, para probarlo con Lune.
-- Lo usa juego/servidor/Tutorial, que mira el mundo cada poco y le pasa lo que ve (`Vista`); el cliente
-- (TutorialVista) solo pinta el paso que le dice el atributo "Tutorial" del jugador.
--   De día, en orden: leer la nota de la mesa de la cocina (la pista 1, el gancho de la historia: docs/historia.md),
--   abrir la mochila, coger un hacha, correr al bosque, talar y cargar un tronco, serrarlo y arrancar
--   el generador. Si ya estaba hecho (la nota leída, el generador encendido, el hacha en la mochila) se salta solo.
--   Correr (14.8, "añade al tutorial un paso corto para correr si encaja"): se acaba en cuanto corre un momento (lo
--   mira el servidor: atributo Corriendo). Si ya ha corrido antes, se salta; y si ya lleva un tronco o un tablón,
--   también (cargando no se puede correr: se quedaría atascado).
--   Al ponerse el sol (Config.Ciclo.Aviso s antes) se dejan los del día y se pasa a cerrar las cortinas de abajo; con
--   todas cerradas, "aguanta hasta el amanecer". Al amanecer se acaba (y Tutorial da el premio), solo si las cerró:
--   quedarse quieto hasta el amanecer no lo acaba.
--   Si mueren todos y se vuelve al principio del día, se vuelve a los pasos del día que falten.
--   Gasolina (16.5): con el generador ya en marcha (o sin gasolina para arrancar), el mismo paso Generador pide echarle
--   un bidón (Estado.repostar) si el depósito no llega a Config.Tutorial.Gasolina, hasta que lo llena o sube. Si no
--   queda ningún bidón con gasolina, no lo pide. Así el jugador nuevo no se queda a oscuras a mitad de la primera noche.
--   La puerta principal abierta cuenta como una cortina más (la suma la hace Tutorial en `cortinas`).
-- Después del tutorial, PasosTutorial.meta dice cuál es la siguiente meta (Tutorial la avisa al empezar cada día) y,
-- si ya se ha empezado a preparar la casa para la Bestia, PasosTutorial.metaBestia.
local PasosTutorial = {}

-- En el orden en que salen. No hace falta guardarlo: si el jugador se va a medias, la próxima vez empieza de cero.
PasosTutorial.DIA = { "Nota", "Mochila", "Hacha", "Correr", "Tronco", "Serrar", "Generador" }
PasosTutorial.LISTA =
	{ "Nota", "Mochila", "Hacha", "Correr", "Tronco", "Serrar", "Generador", "Espera", "Cortinas", "Amanecer" }

export type Estado = {
	paso: string,
	hechos: { [string]: boolean },
	noche: number?, -- la noche que le está enseñando (se apunta al anochecer)
	repostar: boolean?, -- el paso Generador pide echarle gasolina (16.5)
	gasolina: number?, -- la gasolina del generador la última vez que se miró (si sube, se la han echado)
}

export type Vista = {
	fase: string, -- "Dia" o "Noche" (Ciclo)
	noche: number, -- la de Ciclo: de día, la que viene
	quedan: number, -- segundos que le quedan a la fase
	aviso: number, -- Config.Ciclo.Aviso
	nota: boolean?, -- ha leído la nota de la cocina (la pista 1: atributo Leida1, lo pone Pistas.leer)
	mochila: boolean, -- ha abierto la mochila alguna vez desde que empezó el tutorial
	hacha: boolean, -- lleva un hacha en la mochila
	cargando: string?, -- lo pesado que lleva en las manos (atributo Cargando)
	generador: boolean, -- el generador está encendido
	cortinas: number, -- cortinas de abajo aún abiertas (sin contar las rotas)
	corrido: boolean?, -- ha corrido alguna vez desde que empezó el tutorial (atributo Corriendo)
	gasolina: number?, -- parte del depósito del generador (0..1); nil = no se pide echarle gasolina
	gasolinaMin: number?, -- lo que debe tener para la noche (Config.Tutorial.Gasolina)
	bidon: boolean?, -- hay gasolina que echarle (un bidón con gasolina, o uno vacío y el depósito de la granja)
}

function PasosTutorial.nuevo(): Estado
	return { paso = PasosTutorial.DIA[1], hechos = {}, noche = nil }
end

-- Número del paso (1..#LISTA) para el "2/8" del cartel.
function PasosTutorial.numero(paso: string): number
	return table.find(PasosTutorial.LISTA, paso) or 0
end

-- Pone al día `e` con lo que se ve ahora. Devuelve true cuando se ha acabado (ha amanecido tras su noche).
function PasosTutorial.avanzar(e: Estado, v: Vista): boolean
	local h = e.hechos
	e.repostar = nil
	if v.nota then
		h.Nota = true
	end
	if v.mochila then
		h.Mochila = true
	end
	if v.hacha then
		h.Hacha = true
	end
	if v.corrido then
		h.Correr = true
	end
	if v.cargando == "Tronco" then
		h.Correr, h.Tronco = true, true -- ya tiene el tronco: correr hasta el bosque sobra (y cargando no se corre)
	end
	if v.cargando == "Tablon" or v.cargando == "TablonReforzado" then
		h.Correr, h.Tronco, h.Serrar = true, true, true -- ya tiene tablones: lo de talar sobra
	end
	if v.generador then
		h.Generador = true
	end
	local gasolina, minimo = v.gasolina, v.gasolinaMin
	local pideGasolina = type(gasolina) == "number" and type(minimo) == "number"
	if pideGasolina then
		if gasolina >= minimo or (e.gasolina ~= nil and gasolina > e.gasolina + 0.02) then
			h.Gasolina = true -- ya tiene para la noche, o se la acaban de echar
		end
		e.gasolina = gasolina
	end
	local faltaGasolina = pideGasolina and not h.Gasolina and v.bidon == true

	local anochece = v.fase == "Noche" or (v.fase == "Dia" and v.quedan <= v.aviso)
	if not anochece then
		if e.noche then
			if v.noche > e.noche and h.Cortinas then
				return true -- ha amanecido tras la noche que le enseñaba, con las cortinas cerradas
			end
			-- Ha vuelto el mismo día (han muerto todos) o ha amanecido sin cerrar las cortinas: otra vez lo del día
			-- que falte y las cortinas de la noche que viene. Sin hacer nada no se cobra el premio.
			e.noche, h.Cortinas = nil, nil
		end
		for _, paso in PasosTutorial.DIA do
			-- En marcha con poca gasolina (o parado sin ella): el paso del generador pide llenarlo.
			if paso == "Generador" and faltaGasolina and (h.Generador or (gasolina :: number) <= 0.01) then
				e.paso, e.repostar = paso, true
				return false
			end
			if not h[paso] then
				e.paso = paso
				return false
			end
		end
		e.paso = "Espera"
		return false
	end

	if e.noche and v.noche > e.noche then
		if h.Cortinas then
			return true -- ya es el día siguiente (aunque se haya visto tarde, con el sol bajando otra vez)
		end
		e.noche = nil -- la noche nueva cuenta como la suya
	end
	e.noche = e.noche or v.noche
	if v.cortinas <= 0 then
		h.Cortinas = true
	end
	e.paso = if h.Cortinas then "Amanecer" else "Cortinas"
	return false
end

-- La siguiente meta tras el tutorial (16.5), de más cerca a más lejos como las llaves (docs/diseño.md): la llave del
-- sótano (granja), la del garaje (aserradero), las piezas del coche y su gasolina, y huir. Antes que todo eso, si el
-- generador no aguanta la noche y hay gasolina a mano, llenarlo (se empieza con poco y una noche gasta más). Devuelve
-- un código y un número (Tutorial lo pasa a una frase con Lang.t):
--   "Generador", "Sotano", "Garaje", "Piezas" (n = piezas que faltan), "Gasolina" (solo falta la del coche) o "Huir".
--   `cerradas` = llaves de las salas aún cerradas (Casa.cerradas); `piezas` = las que le faltan al coche; `poca` = de
--   día, el generador por debajo de Config.Tutorial.Gasolina y queda gasolina que echarle (Tutorial lo calcula).
function PasosTutorial.meta(
	cerradas: { string },
	piezas: number,
	gasolinaCoche: boolean,
	poca: boolean?
): (string, number)
	if poca then
		return "Generador", 0
	elseif table.find(cerradas, "LlaveSotano") then
		return "Sotano", 0
	elseif table.find(cerradas, "LlaveGaraje") then
		return "Garaje", 0
	elseif piezas > 0 then
		return "Piezas", piezas
	elseif gasolinaCoche then
		return "Gasolina", 0
	end
	return "Huir", 0
end

-- La meta del final de la Bestia (12.2), cuando ya se ha empezado a preparar la casa (Tutorial decide cuándo). En el
-- orden en que lo cuentan las pistas: las cruces de gasolina (la 12), el plano de la reja (la 9), montar la reja y
-- esperarla en el vestíbulo. Devuelve un código y un número (Tutorial lo pasa a una frase con Lang.t):
--   "Cruces" (n = cruces que faltan), "Plano" (falta leer la 9), "Reja" (falta montarla) o "Esperar".
function PasosTutorial.metaBestia(cruces: number, reja9Leida: boolean, montada: boolean): (string, number)
	if cruces > 0 then
		return "Cruces", cruces
	elseif not montada and not reja9Leida then
		return "Plano", 0
	elseif not montada then
		return "Reja", 0
	end
	return "Esperar", 0
end

return PasosTutorial
