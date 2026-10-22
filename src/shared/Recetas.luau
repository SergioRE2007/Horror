-- Cuentas del taller y del coche, sin nada de Roblox (probadas con Lune).
--   Recetas: Pide = { { tipo, cuántos } }; `tengo` = [tipo] = cuántos hay (mochila y cosas pesadas junto al banco).
--   Coche: { piezas = [tipo] = cuántas montadas, gasolina = bidones echados, porton = el del garaje abierto }.
--   `cfg` = Config.Coche.
local Recetas = {}

export type Coche = { piezas: { [string]: number }, gasolina: number, porton: boolean }

-- Lo que falta para hacer una receta: lista de { tipo, cuántos faltan } (vacía = se puede).
function Recetas.falta(pide: { { any } }, tengo: { [string]: number }): { { any } }
	local lista = {}
	for _, p in pide do
		local faltan = p[2] - (tengo[p[1]] or 0)
		if faltan > 0 then
			table.insert(lista, { p[1], faltan })
		end
	end
	return lista
end

function Recetas.nuevoCoche(): Coche
	return { piezas = {}, gasolina = 0, porton = false }
end

-- Cuántas de esa pieza lleva el coche y cuántas le hacen falta (0 si no es una pieza del coche).
local function cuantas(coche: Coche, tipo: string, cfg): (number, number)
	for _, p in cfg.Piezas do
		if p[1] == tipo then
			return coche.piezas[tipo] or 0, p[2]
		end
	end
	return 0, 0
end

-- ¿Le sirve esto al coche? Las piezas que le falten y el bidón ("Bidon") si el depósito no está lleno.
function Recetas.necesita(coche: Coche, tipo: string, cfg): boolean
	if tipo == "Bidon" then
		return coche.gasolina < cfg.Gasolina - 1e-3
	end
	local hay, hacen = cuantas(coche, tipo, cfg)
	return hay < hacen
end

-- Lo primero que le falta, en el orden de cfg.Piezas y luego "Gasolina"; nil si está listo para irse.
function Recetas.queFalta(coche: Coche, cfg): string?
	for _, p in cfg.Piezas do
		if (coche.piezas[p[1]] or 0) < p[2] then
			return p[1]
		end
	end
	return if Recetas.necesita(coche, "Bidon", cfg) then "Gasolina" else nil
end

-- Monta una pieza (true si le hacía falta). Para la gasolina, `cuanta` = lo que se echa; devuelve también lo que ha
-- cabido (el bidón no se vacía de más).
function Recetas.montar(coche: Coche, tipo: string, cfg, cuanta: number?): (boolean, number)
	if not Recetas.necesita(coche, tipo, cfg) then
		return false, 0
	end
	if tipo == "Bidon" then
		local cabe = math.min(cuanta or 0, cfg.Gasolina - coche.gasolina)
		if cabe <= 0 then
			return false, 0
		end
		coche.gasolina += cabe
		return true, cabe
	end
	coche.piezas[tipo] = (coche.piezas[tipo] or 0) + 1
	return true, 1
end

-- Lo guardado (que no es de fiar) a un coche válido: solo piezas que existen, sin pasarse de las que hacen falta.
function Recetas.arreglarCoche(t: unknown, cfg): Coche
	local coche = Recetas.nuevoCoche()
	if type(t) ~= "table" then
		return coche
	end
	local g = t :: any
	if type(g.piezas) == "table" then
		for _, p in cfg.Piezas do
			local n = g.piezas[p[1]]
			if type(n) == "number" and n == n then
				coche.piezas[p[1]] = math.clamp(math.floor(n), 0, p[2])
			end
		end
	end
	if type(g.gasolina) == "number" and g.gasolina == g.gasolina then
		coche.gasolina = math.clamp(g.gasolina, 0, cfg.Gasolina)
	end
	coche.porton = g.porton == true
	return coche
end

return Recetas
