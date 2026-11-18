-- Cielo de la partida (docs/sistemas/cielo.md): estrellas, luna, nubes y su viento. Solo en el cliente y solo de
-- adorno; números en Config.Cielo (a ojo).
--   Sky ("CieloJuego", o el que traiga el lugar): luna algo mayor; ninguna estrella de día y, de noche, pocas
--     (Config.Cielo.Estrellas, con la misma rampa que la luz de Ambiente): las 3000 de serie brillaban mucho con la
--     exposición alta de la noche. Con tormenta, ninguna: el cielo está cerrado.
--   Nubes (Clouds "NubesJuego" en el Terrain): grises y casi cerradas de día, rotas de noche (la luna asoma entre ellas)
--     y cerradas, bajas y oscuras las noches de tormenta (TormentaVista.hay, o el atributo TormentaPrueba en Studio).
--     La tormenta llega y se va en rampa (Config.Cielo.Rampa s): se ve cerrarse el cielo al anochecer y abrirse al
--     amanecer, después del último relámpago. Quien entra tarde lo ve ya puesto. Con cada relámpago (Ambiente.destello)
--     la nube se aclara por dentro y vuelve igual.
--   Viento: workspace.GlobalWind sigue a AireVista.viento (las nubes se arrastran hacia donde va la niebla baja), más
--     fuerte con tormenta. Ningún emisor usa WindAffectsDrag: no mueve partículas.
--   Luz: Ambiente.nublado (0 a 1, la tormenta en rampa). Ambiente baja con él algo la luz de fuera; con 0, nada.
-- Con Rendimiento (se mira en cada repaso: cambia en marcha), sin nubes y con la mitad de estrellas. Un solo bucle de
-- render: repasa Config.Cielo.Cada s (10 por segundo) y solo mientras dura un destello (y una vez al acabar) pinta las
-- nubes cada fotograma. Las cuentas son funciones puras para el banco (tests/bancos/cielo.luau).
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local AireVista = require(script.Parent.AireVista)
local Ambiente = require(script.Parent.Ambiente)
local TormentaVista = require(script.Parent.TormentaVista)

local CFG = Config.Cielo
local jugador = Players.LocalPlayer

local CieloVista = {}

---------------------------------------------------------------- cuentas (sin Roblox: las usa el banco)

export type Nubes = { Cover: number, Density: number, Color: { number } } -- Color en RGB de 0 a 255

local function mezcla(a: number, b: number, k: number): number
	return a + (b - a) * k
end

local function mezclaNubes(a: Nubes, b: Nubes, k: number): Nubes
	return {
		Cover = mezcla(a.Cover, b.Cover, k),
		Density = mezcla(a.Density, b.Density, k),
		Color = { mezcla(a.Color[1], b.Color[1], k), mezcla(a.Color[2], b.Color[2], k), mezcla(a.Color[3], b.Color[3], k) },
	}
end

-- Suave al empezar y al acabar (la rampa lineal se notaría al arrancar y al parar).
function CieloVista.suave(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Las nubes con `noche` (0 a 1, la rampa de la luz) y `tormenta` (0 a 1, ya suavizada).
function CieloVista.nubes(noche: number, tormenta: number, cfg: any): Nubes
	local n = cfg.Nubes
	return mezclaNubes(mezclaNubes(n.Dia, n.Noche, math.clamp(noche, 0, 1)), n.Tormenta, math.clamp(tormenta, 0, 1))
end

-- Las nubes con un destello `d` (0 a 1) encima: se aclaran por dentro. Con d = 0, las mismas.
function CieloVista.conDestello(base: Nubes, d: number, cfg: any): Nubes
	if d <= 0 then
		return base
	end
	local D = cfg.Destello
	local k = math.clamp(d, 0, 1)
	local color = mezclaNubes(base, { Cover = base.Cover, Density = base.Density, Color = D.Color }, k * D.Mezcla).Color
	return { Cover = base.Cover, Density = math.clamp(base.Density + D.Densidad * k, 0, 1), Color = color }
end

-- Cuántas estrellas: ninguna de día ni con tormenta; de noche, Estrellas (con Rendimiento, su parte). De 25 en 25
-- (StarCount no cambia en cada repaso por una sola estrella).
function CieloVista.estrellas(noche: number, tormenta: number, poco: boolean, cfg: any): number
	local k = math.clamp(noche, 0, 1) * (1 - math.clamp(tormenta, 0, 1))
	local n = cfg.Estrellas * k * k * (if poco then cfg.EstrellasRendimiento else 1)
	return math.floor(n / 25 + 0.5) * 25
end

-- Lo que toca de tormenta (0 o 1) en la fase `fase` a la parte `p` de ella: solo de noche, si la hay, hasta que el
-- cielo empieza a abrirse (Tormenta.Abre).
function CieloVista.objetivoTormenta(fase: string?, p: number, hay: boolean, cfg: any): number
	return if fase == "Noche" and hay and p < cfg.Tormenta.Abre then 1 else 0
end

-- Un paso de la rampa: `actual` va hacia `objetivo` a 1/rampa por segundo.
function CieloVista.acercar(actual: number, objetivo: number, dt: number, rampa: number): number
	local paso = dt / math.max(rampa, 1e-3)
	return actual + math.clamp(objetivo - actual, -paso, paso)
end

---------------------------------------------------------------- en el mundo

local cielo: Sky? = nil -- el que se usa (el del lugar o el nuestro)
local cieloMio: Sky? = nil -- el nuestro, si lo hemos tenido que crear
local nubes: Clouds? = nil
local nubesMias: Clouds? = nil
local tormenta: number? = nil -- en rampa, de 0 a 1 (sin suavizar); nil hasta el primer repaso
local base: Nubes? = nil -- las nubes del último repaso, sin destello

-- Lo que el banco puede mirar.
CieloVista.estado = { tormenta = 0, noche = 0 }

local function poco(): boolean
	return jugador:GetAttribute("Rendimiento") == true
end

local function adoptarCielo(s: Sky)
	cielo = s
	s.CelestialBodiesShown = true
	s.MoonAngularSize = CFG.Luna
end

-- El Sky de Lighting: el que haya (del lugar o del servidor) o uno nuestro. Nunca dos a la vez.
local function asegurarCielo(): Sky
	local s = cielo
	if s and s.Parent == Lighting then
		return s
	end
	local suyo = Lighting:FindFirstChildOfClass("Sky")
	if suyo then
		adoptarCielo(suyo)
		return suyo
	end
	local nuevo = Instance.new("Sky")
	nuevo.Name = "CieloJuego"
	nuevo.StarCount = 0
	adoptarCielo(nuevo)
	nuevo.Parent = Lighting
	cieloMio = nuevo
	return nuevo
end

local function asegurarNubes(): Clouds
	local terreno = workspace.Terrain
	local c = nubes
	if c and c.Parent == terreno then
		return c
	end
	local suyas = terreno:FindFirstChildOfClass("Clouds")
	if suyas then
		nubes = suyas
		return suyas
	end
	local nuevas = Instance.new("Clouds")
	nuevas.Name = "NubesJuego"
	nuevas.Parent = terreno
	nubes = nuevas
	nubesMias = nuevas
	return nuevas
end

-- Cuánto de noche (la rampa de Ambiente) y qué parte de la fase lleva.
local function momento(): (string?, number, number)
	local fase = workspace:GetAttribute("Fase")
	local inicio, fin = workspace:GetAttribute("FaseInicio"), workspace:GetAttribute("FaseFin")
	if type(inicio) ~= "number" or type(fin) ~= "number" then
		return fase, 0, 0
	end
	local p = math.clamp((workspace:GetServerTimeNow() - inicio) / math.max(1, fin - inicio), 0, 1)
	return fase, p, AireVista.noche(fase, p)
end

-- ¿Hay tormenta esta noche? La misma cuenta que TormentaVista (todos lo ven igual) o, en Studio, TormentaPrueba.
local function hayTormenta(fase: string?): boolean
	if fase ~= "Noche" then
		return false
	end
	if workspace:GetAttribute("TormentaPrueba") == true and RunService:IsStudio() then
		return true
	end
	local noche, inicio = workspace:GetAttribute("Noche"), workspace:GetAttribute("FaseInicio")
	return type(noche) == "number" and type(inicio) == "number" and TormentaVista.hay(noche, inicio, Config.Tormenta)
end

-- Las nubes de `base` con el destello de ahora (cada fotograma mientras dura).
local function pintarNubes()
	local b = base
	if not b then
		return
	end
	local c = asegurarNubes()
	local n = CieloVista.conDestello(b, Ambiente.destello, CFG)
	c.Enabled = not poco()
	c.Cover = n.Cover
	c.Density = n.Density
	c.Color = Color3.fromRGB(n.Color[1], n.Color[2], n.Color[3])
end

-- Lo de cada repaso: la rampa de la tormenta, estrellas, viento, nubes y lo que lee Ambiente.
local function repasar(dt: number)
	local fase, p, noche = momento()
	local objetivo = CieloVista.objetivoTormenta(fase, p, hayTormenta(fase), CFG)
	local t = if tormenta == nil then objetivo else CieloVista.acercar(tormenta, objetivo, math.min(dt, 1), CFG.Rampa)
	tormenta = t
	local cerrado = CieloVista.suave(t)
	CieloVista.estado.tormenta = cerrado
	CieloVista.estado.noche = noche
	Ambiente.nublado = cerrado

	local sky = asegurarCielo()
	local estrellas = CieloVista.estrellas(noche, cerrado, poco(), CFG)
	if sky.StarCount ~= estrellas then
		sky.StarCount = estrellas
	end

	local rumbo, fuerza = AireVista.viento()
	workspace.GlobalWind = rumbo * (fuerza * CFG.Viento * mezcla(1, CFG.Tormenta.Viento, cerrado))

	base = CieloVista.nubes(noche, cerrado, CFG)
	pintarNubes()
end

function CieloVista.start()
	-- Lo que llegue tarde (del servidor o del lugar) manda sobre lo puesto aquí: se usa ese y se quita el nuestro.
	Lighting.ChildAdded:Connect(function(hijo)
		if hijo:IsA("Sky") and hijo ~= cieloMio then
			adoptarCielo(hijo)
			if cieloMio then
				cieloMio:Destroy()
				cieloMio = nil
			end
		end
	end)
	workspace.Terrain.ChildAdded:Connect(function(hijo)
		if hijo:IsA("Clouds") and hijo ~= nubesMias then
			nubes = hijo
			if nubesMias then
				nubesMias:Destroy()
				nubesMias = nil
			end
			pintarNubes()
		end
	end)
	repasar(0)
	local desde = 0
	local habiaDestello = false
	RunService.RenderStepped:Connect(function(dt)
		desde += dt
		local destello = Ambiente.destello > 0
		if desde >= CFG.Cada then
			repasar(desde)
			desde = 0
		elseif destello or habiaDestello then
			pintarNubes() -- el relámpago dura décimas: a 10 Hz no se vería
		end
		habiaDestello = destello
	end)
end

return CieloVista
