-- Las tiradas de los sucesos al azar del Golpeador (14.10, pedido por el usuario: "que no sea siempre igual"). Pura,
-- sin nada de Roblox (se prueba con Lune: tests/bancos/golpeador-sucesos.luau). La usa GolpeadorSucesos.
--   Cada suceso sale con su Probabilidad (Config.Golpeador.Sucesos) en cada ocasión, y como mucho una vez por noche
--   entre todos los Golpeadores: lo que ha salido se olvida al cambiar de noche (o con reiniciar, al volver a empezar
--   el día).
--   forzar(nombre) (modo de pruebas): la siguiente ocasión de ese suceso sale seguro, aunque ya haya salido esa noche.
local Tiradas = {}
Tiradas.__index = Tiradas

export type Tiradas = typeof(setmetatable({} :: {
	cfg: { [string]: any }, -- Config.Golpeador.Sucesos
	azar: any, -- con NextNumber() entre 0 y 1 (un Random)
	noche: number?, -- la noche de lo apuntado en `salidos`
	salidos: { [string]: boolean },
	forzados: { [string]: boolean },
}, Tiradas))

function Tiradas.nueva(cfg: { [string]: any }, azar: any): Tiradas
	return setmetatable({ cfg = cfg, azar = azar, noche = nil, salidos = {}, forzados = {} }, Tiradas)
end

-- ¿Sale ahora `nombre`, en una ocasión de la noche `noche`? Si sale, ya no sale más esa noche (salvo forzado).
function Tiradas.tirar(self: Tiradas, nombre: string, noche: number): boolean
	local c = self.cfg[nombre]
	if not c then
		return false
	end
	if self.noche ~= noche then
		self.noche = noche
		table.clear(self.salidos)
	end
	if self.forzados[nombre] then
		self.forzados[nombre] = nil
		self.salidos[nombre] = true
		return true
	end
	if self.salidos[nombre] or self.azar:NextNumber() >= (c.Probabilidad or 0) then
		return false
	end
	self.salidos[nombre] = true
	return true
end

-- La próxima ocasión de `nombre` sale seguro. false si no existe ese suceso.
function Tiradas.forzar(self: Tiradas, nombre: string): boolean
	if not self.cfg[nombre] then
		return false
	end
	self.forzados[nombre] = true
	return true
end

-- Olvida lo que ha salido (al volver a empezar el día, la misma noche se repite).
function Tiradas.reiniciar(self: Tiradas)
	self.noche = nil
	table.clear(self.salidos)
end

return Tiradas
