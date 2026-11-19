-- Cuentas de las llaves de las salas cerradas y de lo único del final (pistola, bengalas, cerillas: Config.Objetos con
-- Unica). Las usa Llaves. Sin nada de Roblox dentro, para probarlo con Lune.
local Reparto = {}

type Predicado = (tipo: unknown) -> boolean

local function cosasDe(m: any): { any }?
	if type(m) == "table" and type(m.cosas) == "table" then
		return m.cosas
	end
	return nil
end

-- Los que vienen a esta sesión (`esperados`, UserIds del viaje) cuentan como que están aunque aún no hayan entrado:
-- no se les quita nada y lo que `cuenta` dice de su mochila guardada se suma a `vistas` (llegará con ellos).
function Reparto.esperar(guardadas: { [string]: any }, esperados: { number }, estan: { [string]: boolean },
	vistas: { [string]: number }, cuenta: Predicado)
	for _, userId in esperados do
		local id = tostring(userId)
		if not estan[id] then
			estan[id] = true
			for _, c in cosasDe(guardadas[id]) or {} do
				if type(c) == "table" and cuenta(c.tipo) then
					vistas[c.tipo] = (vistas[c.tipo] or 0) + 1
				end
			end
		end
	end
end

-- Qué llaves hay que volver a poner en su sitio. `cerradas` = llaves de las salas aún cerradas; `vistas[llave]` =
-- cuántas hay sueltas o en las mochilas de los que están; `guardadas[UserId]` = mochilas guardadas ({ cosas }).
-- A los que no están (`estan[UserId]` falso) se les quitan las llaves y lo único (`esUnica`) de la mochila guardada:
-- nadie se lleva una llave ni la pistola a casa, y al volver no la tendrá duplicada.
-- Devuelve las llaves que faltan y lo único quitado (un tipo por cosa), que hay que devolver al mapa (Reparto.reponer).
function Reparto.faltan(cerradas: { string }, vistas: { [string]: number }, guardadas: { [string]: any },
	estan: { [string]: boolean }, esLlave: Predicado, esUnica: Predicado?): ({ string }, { string })
	local quitadas = {}
	for id, m in guardadas do
		local cosas = cosasDe(m)
		if not estan[id] and cosas then
			for i = #cosas, 1, -1 do
				local c = cosas[i]
				if type(c) == "table" and esLlave(c.tipo) then
					table.remove(cosas, i)
				elseif type(c) == "table" and esUnica and esUnica(c.tipo) then
					table.remove(cosas, i)
					table.insert(quitadas, c.tipo)
				end
			end
		end
	end
	local lista = {}
	for _, llave in cerradas do
		if (vistas[llave] or 0) == 0 then
			table.insert(lista, llave)
		end
	end
	return lista, quitadas
end

-- Qué de lo quitado vuelve a su sitio del mapa (todo menos las cerillas) y si se ponen cerillas nuevas en la caja
-- fuerte: solo con su pista leída (`leida`) y si no queda ninguna en ningún sitio (`hay`). Así no se pierden aunque
-- se cayeran del mapa o se las llevara alguien antes de leerla, y nunca hay dos.
function Reparto.reponer(quitadas: { string }, cerillas: string, leida: boolean, hay: number): ({ string }, boolean)
	local lista = {}
	for _, tipo in quitadas do
		if tipo ~= cerillas then
			table.insert(lista, tipo)
		end
	end
	return lista, leida and hay <= 0
end

-- Cuántas bengalas vuelven delante del baúl del desván: las que falten hasta `total` (Config.Bestia.Bengalas) si la
-- Bestia salió ese día (`bestiaHoy`: la noche final salió mal y alguien llegó al amanecer) o si no queda ninguna en
-- toda la partida (`hay`, sueltas y en mochilas). Si no, ninguna: un día normal las gastadas siguen gastadas.
function Reparto.bengalas(hay: number, total: number, bestiaHoy: boolean): number
	if bestiaHoy or hay <= 0 then
		return math.max(total - hay, 0)
	end
	return 0
end

return Reparto
