-- Ayudas para construir el lobby con piezas (las usan Gasolinera, GasolineraTienda, GasolineraFuera y GasolineraCoches).
-- Estilo de la casa y el pueblo del juego (juego/servidor/Fachada, PuebloFachadas): realista, oscuro, sucio y sin
-- brillos. Nada de Neon en piezas grandes; las luces, flojas.
--   P.bloque(padre, nombre, tamano, cf, color, material?, choca?) -> Part: anclada. Sin `choca`, es adorno: no choca,
--     no tapa rayos ni toca (CanCollide, CanQuery y CanTouch a false) y solo hace sombra si es grande.
--   P.cilindro(...) / P.cuna(...) / P.bola(...): lo mismo con otra forma (el cilindro va a lo largo de X, como en Roblox).
--   P.luz(pieza, clase, brillo, alcance, color, sombras?) -> Light: "PointLight", "SpotLight" o "SurfaceLight".
--   P.mancha(pieza, cara, id?, color?, transparencia?) -> Decal (una de P.MANCHAS si no se da id).
--   P.letrero(pieza, cara, texto, color, fuente?) -> SurfaceGui con un TextLabel que llena la cara (solo palabras de
--     marca o números: "GAS", "24H", "ICE"; nada de frases, que no pasan por Lang).
--   P.etiqueta(cosa, tag, atributos?) -> la misma cosa, con la etiqueta de CollectionService y sus atributos.
--   P.punto(padre, nombre, posicion) -> Attachment en ese punto del mundo (para Goteo, Sombra…).
local CollectionService = game:GetService("CollectionService")

local P = {}

-- Manchas de humedad ya subidas (tools/texturas).
P.MANCHAS = { "rbxassetid://85700610438600", "rbxassetid://78490976398688", "rbxassetid://76547078941684" }

-- Colores apagados de gasolinera vieja (la noche y la niebla hacen el resto).
P.COLOR = {
	Hierba = Color3.fromRGB(42, 48, 40),
	Barro = Color3.fromRGB(52, 45, 38),
	Asfalto = Color3.fromRGB(38, 38, 40),
	AsfaltoViejo = Color3.fromRGB(50, 49, 49),
	Hormigon = Color3.fromRGB(88, 86, 82),
	HormigonSucio = Color3.fromRGB(66, 64, 60),
	Bloque = Color3.fromRGB(104, 100, 92), -- bloques de hormigón pintados y sucios
	Pintura = Color3.fromRGB(150, 146, 134), -- pintura blanca vieja
	Rojo = Color3.fromRGB(112, 34, 28), -- el rojo de la marca, desteñido
	Oxido = Color3.fromRGB(84, 52, 36),
	OxidoOscuro = Color3.fromRGB(56, 38, 30),
	Metal = Color3.fromRGB(86, 86, 84),
	MetalOscuro = Color3.fromRGB(40, 40, 41),
	Goma = Color3.fromRGB(26, 26, 27),
	Cristal = Color3.fromRGB(110, 122, 124), -- cristal sucio
	Madera = Color3.fromRGB(70, 52, 38),
	Aceite = Color3.fromRGB(16, 15, 14),
	Agua = Color3.fromRGB(22, 26, 30),
	Linea = Color3.fromRGB(150, 140, 100), -- pintura del suelo, gastada
	Tubo = Color3.fromRGB(214, 218, 204), -- un fluorescente encendido (SmoothPlastic, no Neon)
	Bombilla = Color3.fromRGB(240, 210, 160),
}

local function nueva(clase: string, padre: Instance, nombre: string, tamano: Vector3, cf: CFrame, color: Color3,
	material: Enum.Material?, choca: boolean?): BasePart
	local p = Instance.new(clase) :: BasePart
	p.Name = nombre
	p.Anchored = true
	p.Size = tamano
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Concrete
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local siChoca = choca == true
	p.CanCollide = siChoca
	p.CanQuery = siChoca
	p.CanTouch = false -- nadie usa Touched en el lobby
	-- Lo pequeño sin sombra: son muchas piezas y pesa en móvil.
	p.CastShadow = math.max(tamano.X, tamano.Y, tamano.Z) > 2.5
	p.Parent = padre
	return p
end

function P.bloque(padre: Instance, nombre: string, tamano: Vector3, cf: CFrame, color: Color3, material: Enum.Material?,
	choca: boolean?): Part
	return nueva("Part", padre, nombre, tamano, cf, color, material, choca) :: Part
end

function P.cilindro(padre: Instance, nombre: string, tamano: Vector3, cf: CFrame, color: Color3, material: Enum.Material?,
	choca: boolean?): Part
	local p = nueva("Part", padre, nombre, tamano, cf, color, material, choca) :: Part
	p.Shape = Enum.PartType.Cylinder
	return p
end

function P.bola(padre: Instance, nombre: string, tamano: Vector3, cf: CFrame, color: Color3, material: Enum.Material?,
	choca: boolean?): Part
	local p = nueva("Part", padre, nombre, tamano, cf, color, material, choca) :: Part
	p.Shape = Enum.PartType.Ball
	return p
end

function P.cuna(padre: Instance, nombre: string, tamano: Vector3, cf: CFrame, color: Color3, material: Enum.Material?,
	choca: boolean?): WedgePart
	return nueva("WedgePart", padre, nombre, tamano, cf, color, material, choca) :: WedgePart
end

function P.luz(pieza: Instance, clase: string, brillo: number, alcance: number, color: Color3, sombras: boolean?): Light
	local l = Instance.new(clase) :: any
	l.Brightness = brillo
	l.Range = alcance
	l.Color = color
	l.Shadows = sombras == true
	l.Parent = pieza
	return l
end

local azar = Random.new(77) -- siempre igual: el lobby sale idéntico en cada servidor

function P.mancha(pieza: BasePart, cara: Enum.NormalId, id: string?, color: Color3?, transparencia: number?): Decal
	local d = Instance.new("Decal")
	d.Texture = id or P.MANCHAS[azar:NextInteger(1, #P.MANCHAS)]
	d.Color3 = color or Color3.fromRGB(30, 30, 26)
	d.Transparency = transparencia or 0.4
	d.Face = cara
	d.Parent = pieza
	return d
end

function P.letrero(pieza: BasePart, cara: Enum.NormalId, texto: string, color: Color3, fuente: Enum.Font?): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = cara
	gui.LightInfluence = 1 -- que no brille por su cuenta: lo ilumina la luz que tenga cerca
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = texto
	t.TextScaled = true
	t.Font = fuente or Enum.Font.Oswald
	t.TextColor3 = color
	t.Parent = gui
	gui.Parent = pieza
	return gui
end

function P.etiqueta<T>(cosa: T, tag: string, atributos: { [string]: any }?): T
	CollectionService:AddTag(cosa :: any, tag)
	for clave, valor in atributos or {} do
		(cosa :: any):SetAttribute(clave, valor)
	end
	return cosa
end

-- Los Attachment solo valen colgados de una pieza o del Terrain: si `padre` no es una pieza, va al Terrain.
function P.punto(padre: Instance, nombre: string, posicion: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Name = nombre
	a.Parent = if padre:IsA("BasePart") then padre else workspace.Terrain
	a.WorldPosition = posicion
	return a
end

return P
