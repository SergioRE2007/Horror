-- Cuentas de las compras con Robux (las usan Compras y Revivir). Sin nada de Roblox, para probarlas con Lune. Cada
-- función mira y cambia `datos` de una vez, sin esperas en medio.
local Recibos = {}

-- Apunta la compra `id` como entregada y suma `monedas`. false (y no toca nada) si ya estaba entregada: Roblox puede
-- preguntar otra vez por la misma compra si el guardado de antes no llegó a confirmarse. Recuerda las `recordadas`
-- más nuevas.
function Recibos.apuntar(datos, id: string, ahora: number, recordadas: number, monedas: number): boolean
	if datos.compras[id] ~= nil then
		return false
	end
	datos.monedas += monedas
	datos.compras[id] = ahora
	local cuantas = 0
	for _ in datos.compras do
		cuantas += 1
	end
	while cuantas > recordadas do
		-- Olvidar la más vieja (las de antes de apuntar la hora valen 0).
		local vieja, hora = nil, math.huge
		for otra, cuando in datos.compras do
			local t = if type(cuando) == "number" then cuando else 0
			if t < hora then
				vieja, hora = otra, t
			end
		end
		datos.compras[vieja] = nil
		cuantas -= 1
	end
	return true
end

-- Lo de una vez de un pase (pase.Regalo: monedas y cosméticos). false si no tiene regalo o ya se le dio.
function Recibos.regalo(datos, pase): boolean
	local regalo = pase.Regalo
	if not regalo or datos.regalos[pase.Ventaja] == true then
		return false
	end
	datos.regalos[pase.Ventaja] = true
	datos.monedas += regalo.Monedas or 0
	for _, id in regalo.Cosmeticos or {} do
		datos.cosmeticos[id] = true
	end
	return true
end

-- ¿Se puede revivir ahora a ese jugador? `revividos[UserId]` = la última noche (contador de noches de este servidor)
-- en que revivió con un pago: una vez por noche cada uno.
function Recibos.revivible(esNoche: boolean, muerto: boolean, revividos: { [number]: number }, quien: number,
	noche: number): boolean
	return esNoche and muerto and revividos[quien] ~= noche
end

return Recibos
