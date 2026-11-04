-- La barra del aguante (14.8, pedido por el usuario: "una stamina abajo del todo, una barra fina así minimalista que
-- aparezca al correr"). Abajo del todo y centrada, muy fina, un tercio del ancho de la pantalla, sin texto ni números:
-- blanco desgastado (Ui.Color.Hueso, con los extremos gastados) sobre una raya oscura casi transparente. Se vacía desde
-- los dos lados hacia el centro.
--   Aparece suave al correr o mientras no está llena y se va ~1,5 s después de llenarse. Con poco aguante (menos de
--   Config.Correr.Poco) pasa a rojo oscuro, y agotado late (se aviva y engorda un poco a ritmo de pulso).
--   Fuera en las cinemáticas (además la interfaz entera se apaga), por la mirilla o las cortinas (Vistazo), escondido y
--   muerto: lo decide CorrerVista, que la crea (CorrerBarra.nueva) y la mueve en su bucle (CorrerBarra.mover).
--   Bajo el UIScale del HUD. En el ordenador va en el hueco bajo el cartel de la pila (EquipoVista, a 18 px del borde);
--   en el móvil, por encima de la zona segura (Ui.zonaSegura) y bajo la rejilla de botones EquipoBotones.
-- Lo de cada fotograma (CorrerBarra.cuadro) es una cuenta pura, sin nada de Roblox, para probarla con Lune: por eso
-- este módulo no pide servicios ni módulos al cargarse, solo al crear la barra.
local CorrerBarra = {}

-- Números a ojo (para mirarlos en Studio).
local ALTO = 4 -- píxeles de diseño (a escala 1) de alto
local ANCHO = 1 / 3 -- del ancho de la pantalla
local ABAJO_PC = 7 -- píxeles de diseño del borde de abajo (el cartel de la pila acaba a 18)
local ABAJO_MOVIL = 6 -- y en el móvil, sobre la zona segura (la rejilla de botones deja ~20 debajo)
local QUEDA = 1.5 -- s que se queda a la vista después de llenarse
local ENTRA = 0.25 -- s en aparecer
local SALE = 0.6 -- s en irse
local SALE_YA = 0.15 -- s en irse cuando hay que esconderla (mirilla, escondido...)
local SIGUE = 12 -- lo deprisa que el relleno va hacia el aguante (por segundo; 12: casi al momento, sin tirones)
local ENROJECE = 4 -- por segundo, al pasar a rojo y al volver
local LATIDO = 1.4 -- latidos por segundo agotado
local APAGA_LATIDO = 3 -- por segundo, lo que tarda en dejar de latir
local LLENA = 0.999 -- a partir de aquí cuenta como llena
local FONDO = 0.72 -- transparencia de la raya oscura de fondo (a la vista del todo)
local RELLENO = 0.12 -- y la del relleno
local ENGORDA = 0.5 -- agotado, el alto crece hasta esta parte más en cada latido
local LATE_FONDO = 0.25 -- y el fondo (vacío: agotado está a 0) se hace así de menos transparente
local FONDO_ROJO = 0.55 -- hasta esta parte del rojo

-- Lo que entra cada fotograma (lo da CorrerVista).
export type Entrada = {
	aguante: number, -- 0..1 (el predicho)
	corriendo: boolean,
	agotado: boolean,
	oculto: boolean, -- cinemática, mirilla o cortinas, escondido o muerto
	poco: number, -- Config.Correr.Poco
}

-- Lo que se ve (lo que sale de cada fotograma y entra en el siguiente).
export type Vista = {
	opacidad: number, -- 0 nada, 1 del todo
	relleno: number, -- 0..1: lo que se ve lleno (va hacia el aguante)
	rojo: number, -- 0 blanco, 1 rojo
	latido: number, -- 0..1: lo fuerte que late ahora (agotado)
	fase: number, -- del latido, en vueltas
	llena: number, -- s que lleva llena (para irse a los QUEDA)
}

-- Lo que hay que pintar (lo saca CorrerBarra.pintura de una Vista).
export type Pintura = {
	visible: boolean,
	fondo: number, -- transparencia del fondo
	fondoRojo: number, -- 0..1: el fondo hacia el rojo (agotado late también lo vacío)
	relleno: number, -- transparencia del relleno
	ancho: number, -- 0..1 del ancho de la barra
	rojo: number, -- 0..1: mezcla del blanco hueso al rojo
	alto: number, -- veces el alto normal
}

local function acercar(valor: number, meta: number, paso: number): number
	if valor < meta then
		return math.min(meta, valor + paso)
	end
	return math.max(meta, valor - paso)
end

function CorrerBarra.reposo(): Vista
	return { opacidad = 0, relleno = 1, rojo = 0, latido = 0, fase = 0, llena = math.huge }
end

-- Un fotograma de `dt` s: la vista nueva (una copia; la de antes no se toca).
function CorrerBarra.cuadro(antes: Vista, e: Entrada, dt: number): Vista
	local v = table.clone(antes)
	if not (dt > 0) then
		return v
	end
	dt = math.min(dt, 0.25) -- un tirón no la salta de golpe
	local aguante = math.clamp(if e.aguante == e.aguante then e.aguante else 1, 0, 1)
	-- El relleno sigue al aguante deprisa pero sin saltos (las correcciones del servidor no dan tirones).
	v.relleno = v.relleno + (aguante - v.relleno) * math.min(1, dt * SIGUE)
	if math.abs(v.relleno - aguante) < 0.001 then
		v.relleno = aguante
	end
	-- Cuánto lleva llena: corriendo o agotado no cuenta como llena.
	local llena = aguante >= LLENA and not e.corriendo and not e.agotado
	v.llena = if llena then v.llena + dt else 0 -- (en reposo vale math.huge y ahí se queda)
	-- Opacidad: a la vista corriendo, sin llenar o recién llena; fuera si toca esconderla.
	local meta = if not e.oculto and v.llena < QUEDA then 1 else 0
	local ritmo = if meta > v.opacidad then 1 / ENTRA elseif e.oculto then 1 / SALE_YA else 1 / SALE
	v.opacidad = acercar(v.opacidad, meta, dt * ritmo)
	-- Rojo con poco aguante o agotada.
	v.rojo = acercar(v.rojo, if e.agotado or aguante < e.poco then 1 else 0, dt * ENROJECE)
	-- Agotado, late.
	if e.agotado then
		v.fase = (v.fase + dt * LATIDO) % 1
		v.latido = acercar(v.latido, 1, dt * APAGA_LATIDO)
	else
		v.latido = acercar(v.latido, 0, dt * APAGA_LATIDO)
		if v.latido <= 0 then
			v.fase = 0
		end
	end
	return v
end

-- De una Vista, lo que se pinta.
function CorrerBarra.pintura(v: Vista): Pintura
	-- El latido: un golpe rápido y una caída lenta (como un pulso), de 0 a 1.
	local golpe = if v.fase < 0.18 then v.fase / 0.18 else math.max(0, 1 - (v.fase - 0.18) / 0.55)
	local pulso = golpe * v.latido
	local a = v.opacidad
	return {
		visible = a > 0.001,
		fondo = 1 - ((1 - FONDO) + LATE_FONDO * pulso) * a,
		fondoRojo = v.latido * (0.3 + 0.7 * pulso),
		relleno = 1 - (1 - RELLENO) * a * (0.55 + 0.45 * math.max(1 - v.latido, pulso)),
		ancho = math.clamp(v.relleno, 0, 1),
		rojo = math.clamp(v.rojo, 0, 1),
		alto = 1 + ENGORDA * pulso,
	}
end

-- Lo de Roblox ----------------------------------------------------------------------------------------------------

export type Barra = {
	marco: Frame, -- la raya de fondo (posición y tamaño)
	lleno: Frame, -- el relleno, centrado
	pintado: Pintura?, -- lo último pintado (para no tocar nada si no cambia)
	negro: Color3, -- el del fondo
	hueso: Color3, -- el color de la barra...
	rojo: Color3, -- ...y el de poco aguante
}

-- Crea la barra colgada del HUD (escondida hasta que CorrerBarra.mover la enseñe).
function CorrerBarra.nueva(): Barra
	local Ui = require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))
	local hud = Ui.hud()
	local tactil = Ui.tactil()
	local marco = Instance.new("Frame")
	marco.Name = "Aguante"
	marco.AnchorPoint = Vector2.new(0.5, 1)
	marco.Size = UDim2.new(ANCHO, 0, 0, ALTO)
	marco.BackgroundColor3 = Ui.Color.Negro
	marco.BackgroundTransparency = 1
	marco.BorderSizePixel = 0
	marco.Active = false -- no quita toques ni clics
	marco.Visible = false
	marco.ZIndex = 5
	local esquina = Instance.new("UICorner")
	esquina.CornerRadius = UDim.new(1, 0)
	esquina.Parent = marco
	-- Los extremos, gastados: se pierden en el fondo.
	local gastado = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(0.08, 0.15), NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(0.92, 0.15), NumberSequenceKeypoint.new(1, 0.75),
	})
	local degradado = Instance.new("UIGradient")
	degradado.Transparency = gastado
	degradado.Parent = marco
	local lleno = Instance.new("Frame")
	lleno.Name = "Lleno"
	lleno.AnchorPoint = Vector2.new(0.5, 0.5)
	lleno.Position = UDim2.fromScale(0.5, 0.5)
	lleno.Size = UDim2.fromScale(1, 1)
	lleno.BackgroundColor3 = Ui.Color.Hueso
	lleno.BackgroundTransparency = 1
	lleno.BorderSizePixel = 0
	lleno.ZIndex = 6
	local esquina2 = Instance.new("UICorner")
	esquina2.CornerRadius = UDim.new(1, 0)
	esquina2.Parent = lleno
	local degradado2 = Instance.new("UIGradient")
	degradado2.Transparency = gastado
	degradado2.Parent = lleno
	lleno.Parent = marco
	local function colocar()
		local abajo = if tactil then Ui.zonaSegura() + ABAJO_MOVIL else ABAJO_PC
		marco.Position = UDim2.new(0.5, 0, 1, -abajo)
	end
	colocar()
	hud:GetPropertyChangedSignal("AbsoluteSize"):Connect(colocar) -- al girar el teléfono cambia la zona segura
	marco.Parent = hud
	return {
		marco = marco,
		lleno = lleno,
		pintado = nil,
		negro = Ui.Color.Negro,
		hueso = Ui.Color.Hueso,
		rojo = Ui.Color.Sangre:Lerp(Color3.fromRGB(200, 40, 34), 0.45), -- algo más clara: que se vea en una raya tan fina
	}
end

-- Pinta la vista `v` (solo lo que ha cambiado).
function CorrerBarra.mover(barra: Barra, v: Vista)
	local p = CorrerBarra.pintura(v)
	local antes = barra.pintado
	if antes and antes.visible == p.visible and not p.visible then
		return -- escondida y sigue escondida: nada que tocar
	end
	if antes and math.abs(antes.fondo - p.fondo) < 0.004
		and math.abs(antes.fondoRojo - p.fondoRojo) < 0.004 and math.abs(antes.relleno - p.relleno) < 0.004
		and math.abs(antes.ancho - p.ancho) < 0.001 and math.abs(antes.rojo - p.rojo) < 0.004
		and math.abs(antes.alto - p.alto) < 0.01 and antes.visible == p.visible then
		return
	end
	barra.pintado = p
	barra.marco.Visible = p.visible
	barra.marco.BackgroundTransparency = p.fondo
	barra.marco.BackgroundColor3 = barra.negro:Lerp(barra.rojo, FONDO_ROJO * p.fondoRojo)
	barra.marco.Size = UDim2.new(ANCHO, 0, 0, ALTO * p.alto)
	barra.lleno.BackgroundTransparency = p.relleno
	barra.lleno.Size = UDim2.fromScale(p.ancho, 1)
	barra.lleno.BackgroundColor3 = barra.hueso:Lerp(barra.rojo, p.rojo)
end

return CorrerBarra
