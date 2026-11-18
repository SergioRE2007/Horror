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

return RepartoBichos
