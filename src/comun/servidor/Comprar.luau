-- Cuentas de la tienda del lobby (las usa Tienda). Sin nada de Roblox, para probarlas con Lune: los catálogos
-- (Config.Clases, Config.Cosmeticos) llegan como parámetro. Cada función mira y cambia `datos` de una vez, sin esperas
-- en medio: dos peticiones seguidas no pueden comprar dos veces ni dejar las monedas en negativo.
-- Devuelven "ok" o por qué no: "nada" (no existe), "tiene" (ya es suya) o "monedas" (no le llegan).
local Comprar = {}

local function buscar(lista, id: unknown)
	if type(id) ~= "string" then
		return nil
	end
	for _, cosa in lista do
		if cosa.Id == id then
			return cosa
		end
	end
	return nil
end

-- Lo que cuesta esa clase a ese jugador: la primera que compra, gratis.
function Comprar.precioClase(datos, clase): number
	for _, tiene in datos.clases do
		if tiene == true then
			return clase.Precio
		end
	end
	return 0
end

-- Cobra (si le llega) y apunta la cosa como suya.
local function pagar(datos, precio: number, suyas, id: string): string
	if suyas[id] == true then
		return "tiene"
	end
	if not (datos.monedas >= precio) then
		return "monedas"
	end
	datos.monedas -= precio
	suyas[id] = true
	return "ok"
end

-- Compra la clase y la deja elegida.
function Comprar.clase(datos, clases, id: unknown): string
	local clase = buscar(clases, id)
	if not clase then
		return "nada"
	end
	local r = pagar(datos, Comprar.precioClase(datos, clase), datos.clases, clase.Id)
	if r == "ok" then
		datos.clase = clase.Id
	end
	return r
end

-- Compra el cosmético y se lo pone.
function Comprar.cosmetico(datos, cosmeticos, id: unknown): string
	local cosa = buscar(cosmeticos, id)
	if not cosa then
		return "nada"
	end
	local r = pagar(datos, cosa.Precio, datos.cosmeticos, cosa.Id)
	if r == "ok" then
		datos.puestos[cosa.Tipo] = cosa.Id
	end
	return r
end

-- Se pone un cosmético suyo, o "" para volver al de serie de ese tipo. false si no vale.
function Comprar.poner(datos, cosmeticos, tipo: unknown, id: unknown): boolean
	if id == "" then
		for _, cosa in cosmeticos do
			if cosa.Tipo == tipo then
				datos.puestos[tipo] = nil
				return true
			end
		end
		return false
	end
	local cosa = buscar(cosmeticos, id)
	if not cosa or cosa.Tipo ~= tipo or datos.cosmeticos[cosa.Id] ~= true then
		return false
	end
	datos.puestos[tipo] = cosa.Id
	return true
end

-- El cosmético que lleva puesto de ese tipo, o nil (el de serie). Lo guardado que ya no valga no cuenta.
function Comprar.puesto(datos, cosmeticos, tipo: string)
	local cosa = buscar(cosmeticos, datos.puestos[tipo])
	return if cosa and cosa.Tipo == tipo and datos.cosmeticos[cosa.Id] == true then cosa else nil
end

return Comprar
