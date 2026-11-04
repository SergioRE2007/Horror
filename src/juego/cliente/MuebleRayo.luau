--!strict
-- Rayos que ven los muebles, para los gateos que miden la mesa con rayos (TrepadorVista y BestiaVista). Las piezas de
-- los muebles y sus cajas "Choque" tienen CanQuery = false (Piezas y Mapa: que no tapen la vista de los bichos ni la
-- linterna), así que workspace:Raycast no las ve nunca: los gateos medían "sin mesa" y se metían por el tablero.
-- `cajas` junta, una vez por gateo, lo que choca cerca: el tablero entero de cada zona Debajo (con el atributo Tam de
-- su mueble, hasta el borde que se ve) y las cajas Choque de su casa (patas, travesaños, otros muebles). `rayo` es
-- workspace:Raycast que además ve esas cajas. Librería sin start().

local CollectionService = game:GetService("CollectionService")

local MuebleRayo = {}

-- `pieza`: el mueble (para el tablero) o la caja Choque. Nunca la zona: su nombre "Debajo" no cuenta como techo.
export type Caja = { cf: CFrame, medio: Vector3, pieza: Instance }
export type Golpe = { Position: Vector3, Instance: Instance, Distance: number }

local SALIENTE = 2 -- si el pivote del mueble no cuadra: lo que más sobresale un tablero de su zona (1,96 el comedor)

-- El tablero de un mueble con zona Debajo (Mapa, HUECOS): del alto de la zona a lo alto del mueble y hasta los bordes
-- de su Tam. Igual que `cajaTablero` de GolpeadorVista e ImitadorVista. Devuelve su centro y su tamaño.
function MuebleRayo.tablero(zona: BasePart): (CFrame, Vector3)
	local medio = zona.Size / 2
	local cf = zona.CFrame * CFrame.new(0, medio.Y + 0.4, 0)
	local tam = Vector3.new(zona.Size.X + 2 * SALIENTE, 0.8, zona.Size.Z + 2 * SALIENTE)
	local mueble = zona.Parent
	local medida = if mueble and mueble:IsA("Model") then mueble:GetAttribute("Tam") else nil
	if mueble and typeof(medida) == "Vector3" then
		local pivote = (mueble :: Model):GetPivot()
		local z = pivote:PointToObjectSpace(zona.Position)
		if math.abs(pivote.XVector:Dot(zona.CFrame.XVector)) > 0.99 and math.abs(pivote.YVector:Dot(Vector3.yAxis)) > 0.99
			and math.abs(z.X) + medio.X <= medida.X / 2 + 0.05 and math.abs(z.Z) + medio.Z <= medida.Z / 2 + 0.05
			and math.abs(z.Y - medio.Y) < 0.1 and medida.Y > zona.Size.Y
		then
			cf = pivote * CFrame.new(0, (zona.Size.Y + medida.Y) / 2, 0)
			tam = Vector3.new(medida.X, medida.Y - zona.Size.Y, medida.Z)
		end
	end
	return cf, tam
end

-- Lo que choca de los muebles a menos de `radio` de `punto` (en planta). Una vez por gateo: recorre la casa.
function MuebleRayo.cajas(punto: Vector3, radio: number): { Caja }
	local lista: { Caja } = {}
	local function cerca(pos: Vector3, tam: Vector3): boolean
		return Vector3.new(pos.X - punto.X, 0, pos.Z - punto.Z).Magnitude < radio + tam.Magnitude / 2
	end
	local casas: { [Instance]: boolean } = {}
	for _, zona in CollectionService:GetTagged("Debajo") do
		if zona:IsA("BasePart") and cerca(zona.Position, zona.Size) then
			local cf, tam = MuebleRayo.tablero(zona)
			local mueble = zona.Parent
			table.insert(lista, { cf = cf, medio = tam / 2, pieza = mueble or zona })
			local casa = mueble and mueble.Parent
			if casa then
				casas[casa] = true
			end
		end
	end
	for casa in casas do
		for _, pieza in casa:GetChildren() do
			if pieza.Name == "Choque" and pieza:IsA("BasePart") and cerca(pieza.Position, pieza.Size) then
				table.insert(lista, { cf = pieza.CFrame, medio = pieza.Size / 2, pieza = pieza })
			end
		end
	end
	return lista
end

-- Un eje del método de las franjas: estrecha [desde, hasta]; nil si el rayo no pasa por esa franja.
local function franja(o: number, d: number, m: number, desde: number, hasta: number): (number?, number)
	if math.abs(d) < 1e-9 then
		if math.abs(o) > m then
			return nil, hasta
		end
		return desde, hasta
	end
	local t1, t2 = (-m - o) / d, (m - o) / d
	if t1 > t2 then
		t1, t2 = t2, t1
	end
	return math.max(desde, t1), math.min(hasta, t2)
end

-- Dónde entra en la caja el rayo de `origen` a `origen + direccion`, en partes de `direccion` (0..1); nil si no la
-- toca. Si empieza dentro, tampoco (como workspace:Raycast).
function MuebleRayo.entra(caja: Caja, origen: Vector3, direccion: Vector3): number?
	local o = caja.cf:PointToObjectSpace(origen)
	local d = caja.cf:VectorToObjectSpace(direccion)
	local desde: number?, hasta = -math.huge, math.huge
	desde, hasta = franja(o.X, d.X, caja.medio.X, desde :: number, hasta)
	if desde == nil or desde > hasta then
		return nil
	end
	desde, hasta = franja(o.Y, d.Y, caja.medio.Y, desde, hasta)
	if desde == nil or desde > hasta then
		return nil
	end
	desde, hasta = franja(o.Z, d.Z, caja.medio.Z, desde, hasta)
	if desde == nil or desde > hasta or desde < 0 or desde > 1 then
		return nil
	end
	return desde
end

-- Como workspace:Raycast(origen, direccion, filtro), pero también ve las `cajas` (de MuebleRayo.cajas): lo primero
-- que toque.
function MuebleRayo.rayo(origen: Vector3, direccion: Vector3, filtro: RaycastParams, cajas: { Caja }): Golpe?
	local mejor: Golpe? = nil
	local mundo = workspace:Raycast(origen, direccion, filtro)
	if mundo then
		mejor = { Position = mundo.Position, Instance = mundo.Instance, Distance = (mundo.Position - origen).Magnitude }
	end
	local largo = direccion.Magnitude
	for _, caja in cajas do
		local t = MuebleRayo.entra(caja, origen, direccion)
		if t and (mejor == nil or t * largo < mejor.Distance) then
			mejor = { Position = origen + direccion * t, Instance = caja.pieza, Distance = t * largo }
		end
	end
	return mejor
end

return MuebleRayo
