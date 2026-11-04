-- Los pasos del tutorial (14.2 / 13.1): qué toca enseñar ahora a un jugador. Sin nada de Roblox, para probarlo con Lune.
-- Lo usa juego/servidor/Tutorial, que mira el mundo cada poco y le pasa lo que ve (`Vista`); el cliente
-- (TutorialVista) solo pinta el paso que le dice el atributo "Tutorial" del jugador.
--   De día, en orden: abrir la mochila, coger un hacha, talar y cargar un tronco, serrarlo y arrancar el generador. Si
--   ya estaba hecho (el generador encendido, el hacha en la mochila) se salta solo.
--   Al ponerse el sol (Config.Ciclo.Aviso s antes) se dejan los del día y se pasa a cerrar las cortinas de abajo; con
--   todas cerradas, "aguanta hasta el amanecer". Al amanecer se acaba (y Tutorial da el premio), solo si las cerró:
--   quedarse quieto hasta el amanecer no lo acaba.
--   Si mueren todos y se vuelve al principio del día, se vuelve a los pasos del día que falten.
local PasosTutorial = {}

-- En el orden en que salen. No hace falta guardarlo: si el jugador se va a medias, la próxima vez empieza de cero.
PasosTutorial.DIA = { "Mochila", "Hacha", "Tronco", "Serrar", "Generador" }
PasosTutorial.LISTA = { "Mochila", "Hacha", "Tronco", "Serrar", "Generador", "Espera", "Cortinas", "Amanecer" }

export type Estado = {
	paso: string,
	hechos: { [string]: boolean },
	noche: number?, -- la noche que le está enseñando (se apunta al anochecer)
}

export type Vista = {
	fase: string, -- "Dia" o "Noche" (Ciclo)
	noche: number, -- la de Ciclo: de día, la que viene
	quedan: number, -- segundos que le quedan a la fase
	aviso: number, -- Config.Ciclo.Aviso
	mochila: boolean, -- ha abierto la mochila alguna vez desde que empezó el tutorial
	hacha: boolean, -- lleva un hacha en la mochila
	cargando: string?, -- lo pesado que lleva en las manos (atributo Cargando)
	generador: boolean, -- el generador está encendido
	cortinas: number, -- cortinas de abajo aún abiertas (sin contar las rotas)
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
	if v.mochila then
		h.Mochila = true
	end
	if v.hacha then
		h.Hacha = true
	end
	if v.cargando == "Tronco" then
		h.Tronco = true
	end
	if v.cargando == "Tablon" or v.cargando == "TablonReforzado" then
		h.Tronco, h.Serrar = true, true -- ya tiene tablones: lo de talar sobra
	end
	if v.generador then
		h.Generador = true
	end

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

return PasosTutorial
