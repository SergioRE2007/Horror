--!strict
-- Rayos que ven los muebles, para los gateos que miden la mesa con rayos (TrepadorVista, BestiaVista y los rayos de
-- reserva de ImitadorVista), y el tablero de cada zona Debajo (`tablero`, también para GolpeadorVista, ImitadorVista,
-- RaspadorVista y PosturaVista). Las piezas de los muebles y sus cajas "Choque" tienen CanQuery = false (Piezas y Mapa:
-- que no tapen la vista de los bichos ni la linterna), así que workspace:Raycast no las ve nunca: los gateos medían
-- "sin mesa" y se metían por el tablero. `cajas` junta, una vez por gateo, lo que choca cerca: el tablero entero de
-- cada zona Debajo (con el atributo Tam de su mueble, hasta el borde que se ve) y las cajas Choque de su casa (patas,
-- travesaños, otros muebles). `rayo` es workspace:Raycast que además ve esas cajas, y `choca` si una caja se mete en
-- ellas (el brazo de la Bestia, que barre por debajo). Librería sin start().

local CollectionService = game:GetService("CollectionService")

local MuebleRayo = {}

-- `pieza`: el mueble (para el tablero) o la caja Choque. Nunca la zona: su nombre "Debajo" no cuenta como techo.
-- `bajo` y `alto`: las esquinas de la caja sin girar que la contiene (para descartarla deprisa).
export type Caja = { cf: CFrame, medio: Vector3, pieza: Instance, bajo: Vector3, alto: Vector3 }
export type Golpe = { Position: Vector3, Instance: Instance, Distance: number }

local SALIENTE = 2 -- si el pivote del mueble no cuadra: lo que más sobresale un tablero de su zona (1,96 el comedor)

-- El tablero de un mueble con zona Debajo (Mapa, HUECOS): del alto de la zona a lo alto del mueble y hasta los bordes
-- de su Tam. Si el mueble no tiene Tam o su pivote no cuadra con la zona (girado, o la zona fuera de él), se da por
-- hecho que sobresale SALIENTE de la zona por cada lado. Devuelve su centro, su tamaño y si salió del Tam (`medido`).
-- El único sitio que lo calcula: lo usan los gateos de todos los bichos y el techo de PosturaVista.
function MuebleRayo.tablero(zona: BasePart): (CFrame, Vector3, boolean)
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
			return cf, tam, true
		end
	end
	return cf, tam, false
end

local function caja(cf: CFrame, medio: Vector3, pieza: Instance): Caja
	local x, y, z = cf.XVector * medio.X, cf.YVector * medio.Y, cf.ZVector * medio.Z
	local ancho = Vector3.new(
		math.abs(x.X) + math.abs(y.X) + math.abs(z.X),
		math.abs(x.Y) + math.abs(y.Y) + math.abs(z.Y),
		math.abs(x.Z) + math.abs(y.Z) + math.abs(z.Z)
	)
	return { cf = cf, medio = medio, pieza = pieza, bajo = cf.Position - ancho, alto = cf.Position + ancho }
end

-- Lo que choca de los muebles a menos de `radio` de `punto` (en planta, y en su planta de la casa). Una vez por
-- gateo: recorre la casa.
function MuebleRayo.cajas(punto: Vector3, radio: number): { Caja }
	local lista: { Caja } = {}
	local function cerca(pos: Vector3, tam: Vector3): boolean
		return Vector3.new(pos.X - punto.X, 0, pos.Z - punto.Z).Magnitude < radio + tam.Magnitude / 2
			and math.abs(pos.Y - punto.Y) < 8 + tam.Magnitude / 2
	end
	local casas: { [Instance]: boolean } = {}
	local vistos: { [Instance]: boolean } = {}
	for _, zona in CollectionService:GetTagged("Debajo") do
		if zona:IsA("BasePart") and cerca(zona.Position, zona.Size) then
			local mueble = zona.Parent
			if mueble and vistos[mueble] then
				continue -- otra zona del mismo mueble: el mismo tablero
			end
			local cf, tam = MuebleRayo.tablero(zona)
			table.insert(lista, caja(cf, tam / 2, mueble or zona))
			if mueble then
				vistos[mueble] = true
			end
			local casa = mueble and mueble.Parent
			if casa then
				casas[casa] = true
			end
		end
	end
	for casa in casas do
		for _, pieza in casa:GetChildren() do
			if pieza.Name == "Choque" and pieza:IsA("BasePart") and cerca(pieza.Position, pieza.Size) then
				table.insert(lista, caja(pieza.CFrame, pieza.Size / 2, pieza))
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
function MuebleRayo.entra(c: Caja, origen: Vector3, direccion: Vector3): number?
	local o = c.cf:PointToObjectSpace(origen)
	local d = c.cf:VectorToObjectSpace(direccion)
	local desde: number?, hasta = -math.huge, math.huge
	desde, hasta = franja(o.X, d.X, c.medio.X, desde :: number, hasta)
	if desde == nil or desde > hasta then
		return nil
	end
	desde, hasta = franja(o.Y, d.Y, c.medio.Y, desde, hasta)
	if desde == nil or desde > hasta then
		return nil
	end
	desde, hasta = franja(o.Z, d.Z, c.medio.Z, desde, hasta)
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
	local fin = origen + direccion
	local x0, x1 = math.min(origen.X, fin.X), math.max(origen.X, fin.X)
	local y0, y1 = math.min(origen.Y, fin.Y), math.max(origen.Y, fin.Y)
	local z0, z1 = math.min(origen.Z, fin.Z), math.max(origen.Z, fin.Z)
	for _, c in cajas do
		-- Deprisa: si la caja sin girar que la contiene no cruza la del rayo, no la toca (el Trepador lanza cientos).
		if c.alto.X < x0 or c.bajo.X > x1 or c.alto.Y < y0 or c.bajo.Y > y1 or c.alto.Z < z0 or c.bajo.Z > z1 then
			continue
		end
		local t = MuebleRayo.entra(c, origen, direccion)
		if t and (mejor == nil or t * largo < mejor.Distance) then
			mejor = { Position = origen + direccion * t, Instance = c.pieza, Distance = t * largo }
		end
	end
	return mejor
end

-- Lo que abulta una caja (centro `cf`, mitad `medio`) a lo largo de `eje`, desde su centro.
local function radio(cf: CFrame, medio: Vector3, eje: Vector3): number
	return math.abs(cf.XVector:Dot(eje)) * medio.X + math.abs(cf.YVector:Dot(eje)) * medio.Y
		+ math.abs(cf.ZVector:Dot(eje)) * medio.Z
end

-- Si `eje` separa las dos cajas (`d`: de un centro al otro) dejando que se metan `h` studs.
local function separa(eje: Vector3, d: Vector3, cf: CFrame, medio: Vector3, c: Caja, h: number): boolean
	return math.abs(d:Dot(eje)) >= radio(cf, medio, eje) + radio(c.cf, c.medio, eje) - h
end

-- El eje de una caja: 1 = X, 2 = Y, 3 = Z.
local function eje(cf: CFrame, i: number): Vector3
	return if i == 1 then cf.XVector elseif i == 2 then cf.YVector else cf.ZVector
end

-- La primera de las `cajas` en la que la caja `cf` (mitad `medio`) se mete más de `holgura` studs, o nil (por los 15
-- ejes que separan dos cajas giradas). Para que un brazo que barre no atraviese las patas (BestiaVista). Sin tablas
-- nuevas: se llama varias veces por fotograma.
function MuebleRayo.choca(cf: CFrame, medio: Vector3, cajas: { Caja }, holgura: number?): Caja?
	local h = holgura or 0
	local ancho = Vector3.new(radio(cf, medio, Vector3.xAxis), radio(cf, medio, Vector3.yAxis), radio(cf, medio, Vector3.zAxis))
	local bajo, alto = cf.Position - ancho, cf.Position + ancho
	for _, c in cajas do
		if c.alto.X < bajo.X + h or c.bajo.X > alto.X - h or c.alto.Y < bajo.Y + h or c.bajo.Y > alto.Y - h
			or c.alto.Z < bajo.Z + h or c.bajo.Z > alto.Z - h then
			continue
		end
		local d = c.cf.Position - cf.Position
		local libre = false
		for i = 1, 3 do
			if separa(eje(cf, i), d, cf, medio, c, h) or separa(eje(c.cf, i), d, cf, medio, c, h) then
				libre = true
				break
			end
		end
		if not libre then
			for i = 1, 3 do
				for j = 1, 3 do
					local x = eje(cf, i):Cross(eje(c.cf, j))
					if x.Magnitude > 1e-4 and separa(x.Unit, d, cf, medio, c, h) then
						libre = true
						break
					end
				end
				if libre then
					break
				end
			end
		end
		if not libre then
			return c
		end
	end
	return nil
end

return MuebleRayo
