-- Qué bicho toca en cada ataque del Director y cuánto se espera hasta el siguiente (16.15). Sin nada de Roblox, para
-- probarlo con Lune y un azar con semilla (tests/bancos/reparto-bichos.luau). Lo usa juego/servidor/Director.
--   `azar` es un Random (o algo con NextNumber() entre 0 y 1 y NextNumber(min, max)). El orden y el número de tiradas
--   son los de siempre: solo se tira por un bicho si le puede tocar (desde su noche, sin otro suyo fuera y sin ataque
--   seguro), así que con la misma semilla sale lo mismo que antes de sacarlo del Director.
local RepartoBichos = {}

export type Estado = {
	noche: number,
	bestia: boolean, -- la noche final (Bestia.activa()): no sale nadie más
	puertaLibre: boolean, -- hay puerta principal y no tiene ya un ataque en marcha (el Imitador solo va a ella)
	seguros: { [string]: boolean }, -- el primer ataque de la noche en que sale un bicho nuevo es suyo
	cuantos: { [string]: number }, -- cuántos hay fuera de cada especial ahora (Imitador, Trepador, Raspador)
}

-- Los especiales, en el orden en que se miran: el primero que toca se lleva el ataque; si ninguno, el Golpeador.
RepartoBichos.ESPECIALES = { "Imitador", "Trepador", "Raspador" }

-- El bicho de este ataque, o nil si no toca ninguno (la noche final: solo ella; el Director espera y vuelve a mirar).
-- `config` es Config (sus tablas Imitador, Trepador y Raspador, con Noche y Probabilidad).
function RepartoBichos.toca(e: Estado, config: any, azar: any): string?
	if e.bestia then
		return nil
	end
	for _, que in RepartoBichos.ESPECIALES do
		local c = config[que]
		-- Uno como mucho a la vez de cada uno; el Imitador, además, solo si la puerta principal está libre.
		if (que ~= "Imitador" or e.puertaLibre) and e.noche >= c.Noche and (e.cuantos[que] or 0) == 0
			and (e.seguros[que] or azar:NextNumber() < c.Probabilidad) then
			return que
		end
	end
	return "Golpeador"
end

-- Segundos hasta el siguiente ataque del mismo hueco: cada noche antes, nunca menos del mínimo, por el ritmo de la
-- dificultad (Dificultad.de). `g` es Config.Golpeador.
function RepartoBichos.intervalo(noche: number, ritmo: number, g: any, azar: any): number
	return math.max(g.IntervaloMin, azar:NextNumber(g.Intervalo[1], g.Intervalo[2]) - g.MenosPorNoche * (noche - 1)) * ritmo
end

-- Uno al azar de una lista (solo con NextNumber(), para que sirva cualquier azar del banco).
local function uno<T>(lista: { T }, azar: any): T?
	if #lista == 0 then
		return nil
	end
	return lista[math.min(#lista, math.floor(azar:NextNumber() * #lista) + 1)]
end

-- Con qué voz llama el Imitador (juego/servidor/Imitador). Devuelve el nombre que dice y el jugador al que imita (nil
-- si no es ninguno de la partida: Tom). `muertos`: los que han muerto esta noche (su cuerpo sigue ahí); `lejos`: los
-- vivos lejos de la puerta; `todos`: los de la partida; `tomLeida`: alguien ha visto la foto de Tom (pista
-- cfg.Antiguo.Pista). `cfg` es Config.Imitador. Cada jugador es algo con DisplayName.
--   Si hay muertos, con cfg.VozMuerto uno de ellos ("soy yo, ábreme"); si no, uno de los vivos lejos de la puerta;
--   jugando solo y con la foto vista, con cfg.Antiguo.Probabilidad el vigilante de antes; si no, cualquiera (solo: tú).
function RepartoBichos.voz(muertos: { any }, lejos: { any }, todos: { any }, tomLeida: boolean, azar: any, cfg: any): (string?, any?)
	local elegido = nil
	if #muertos > 0 and azar:NextNumber() < cfg.VozMuerto then
		elegido = uno(muertos, azar)
	end
	elegido = elegido or uno(lejos, azar)
	if not elegido and #todos == 1 and tomLeida and azar:NextNumber() < cfg.Antiguo.Probabilidad then
		return cfg.Antiguo.Nombre, nil
	end
	elegido = elegido or uno(todos, azar)
	if not elegido then
		return nil, nil
	end
	return elegido.DisplayName, elegido
end

return RepartoBichos
