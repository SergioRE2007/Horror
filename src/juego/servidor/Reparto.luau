-- Cuentas de las llaves de las salas cerradas (las usa Llaves). Sin nada de Roblox dentro, para probarlo con Lune.
local Reparto = {}

-- Qué llaves hay que volver a poner en su sitio. `cerradas` = llaves de las salas aún cerradas; `vistas[llave]` =
-- cuántas hay sueltas o en las mochilas de los que están; `guardadas[UserId]` = mochilas guardadas ({ cosas }).
-- A los que no están (`estan[UserId]` falso) se les quitan las llaves de la mochila guardada: nadie se lleva una
-- llave a casa, y al volver no la tendrá duplicada.
function Reparto.faltan(cerradas: { string }, vistas: { [string]: number }, guardadas: { [string]: any },
	estan: { [string]: boolean }, esLlave: (tipo: unknown) -> boolean): { string }
	for id, m in guardadas do
		if not estan[id] and type(m) == "table" and type(m.cosas) == "table" then
			for i = #m.cosas, 1, -1 do
				local c = m.cosas[i]
				if type(c) == "table" and esLlave(c.tipo) then
					table.remove(m.cosas, i)
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
	return lista
end

return Reparto
