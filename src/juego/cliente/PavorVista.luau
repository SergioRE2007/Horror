-- Pavor al ver un bicho (pedido por el usuario: "mejorar la inmersión"; docs/sistemas/pavor.md). Todo en el cliente y
-- solo de adorno. La primera vez que un bicho entra en tu vista de verdad (en la pantalla, a menos de Config.Pavor.Lejos
-- studs y con un rayo sin paredes en medio; los cristales no tapan; el Imitador mientras finge en la puerta no cuenta),
-- el cuerpo reacciona:
--   Vértigo: el campo de visión se cierra (de 70 a ~60, CuerpoVista.ponerPavor) en 0,5 s mientras la cámara recula un
--   palmo, y vuelve despacio.
--   Un golpe de tensión flojo (Sobresalto), las manos dan un respingo (ManosGestos.sobresalto) y el latido (Latido) se
--   oye unos segundos y se apaga.
--   Luego, 20-30 s de pavor que baja poco a poco: las manos y la linterna tiemblan (Manos.pavor: la luz sale de
--   Manos.dondeCosa y tiembla con la mano), la respiración de la cámara va más deprisa y al girar rápido la vista se
--   queda un pelo atrás (CuerpoVista).
-- Cuanto más cerca lo veas, más fuerte. El mismo bicho no vuelve a asustar hasta que lo pierdes de vista
-- Config.Pavor.Olvida s. Nada escondido ni debajo de un mueble (allí manda MuerteVista: su latido), muerto, con la
-- mochila abierta, mirando por la mirilla o la ventana (MirarVista tiene su susto) ni en cinemáticas (cámara que no es
-- Custom). Con Rendimiento, sin vértigo ni retraso ni respiración de más: solo el latido y un temblor flojo.
-- Las cuentas, en PavorCuentas (banco tests/bancos/pavor.luau). Un solo RenderStep antes de la cámara: mira los bichos
-- cada Config.Pavor.Cada s y, si no hay pavor ni latido, no hace nada más.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local CuerpoVista = require(script.Parent.CuerpoVista)
local Manos = require(script.Parent.Manos)
local ManosGestos = require(script.Parent.ManosGestos)
local PavorCuentas = require(script.Parent.PavorCuentas)
local Sonido = require(script.Parent.Sonido)

local PavorVista = {}

local C = Config.Pavor
local jugador = Players.LocalPlayer
local camara = workspace.CurrentCamera
local CRISTAL = 0.3 -- piezas con esta transparencia o más no tapan (cristales, telarañas, niebla)
local RAYOS = 4 -- rayos por punto como mucho (atravesando cristales)

-- La última vez que se vio cada bicho (os.clock); claves débiles: un bicho que se va no se queda aquí.
local vistos: { [Instance]: number } = setmetatable({}, { __mode = "k" }) :: any
local proximaMirada = 0
-- El vértigo de ahora.
local vertigoDesde: number? = nil
local vertigoFuerza = 0
-- El pavor: desde cuándo baja, desde qué nivel y en cuánto.
local pavorDesde: number? = nil
local pavorNivel = 0
local pavorDura = 1
-- El latido.
local latido: Sound? = nil
local latidoBase = 1
local latidoDesde = 0
local latidoFuerza = 0
local ultimoSobresalto = -math.huge
local puesto = false -- si hay algo puesto en CuerpoVista o Manos (para quitarlo una vez)
local rayo = RaycastParams.new()
rayo.FilterType = Enum.RaycastFilterType.Exclude
rayo.IgnoreWater = true
local filtroDe: Model? = nil

-- El Imitador mientras finge ser una persona en la puerta (como en MirarVista y MuerteVista): no cuenta.
local function fingiendo(bicho: Instance): boolean
	return bicho.Name == "Imitador" and not bicho:GetAttribute("Abierto")
end

-- Si ahora el cuerpo puede reaccionar: en primera persona con la cámara normal, vivo, sin esconderse ni mirar por algo.
local function puedeSentir(): boolean
	if camara.CameraType ~= Enum.CameraType.Custom then
		return false
	end
	if jugador:GetAttribute("Muerto") or jugador:GetAttribute("Escondido") ~= nil
		or jugador:GetAttribute("Cubierto") == true or jugador:GetAttribute("MochilaAbierta")
		or jugador:GetAttribute("Vistazo") ~= nil or jugador:GetAttribute("Mirilla") == true then
		return false
	end
	local personaje = jugador.Character
	local hum = personaje and personaje:FindFirstChildOfClass("Humanoid")
	local cabeza = personaje and personaje:FindFirstChild("Head") :: BasePart?
	if not hum or hum.Health <= 0 or not cabeza then
		return false
	end
	-- Primera persona (con margen: agachado, asomado o tropezando la cámara se aparta algo de la cabeza).
	return (camara.CFrame.Position - cabeza.Position).Magnitude < 4
end

-- Si de `desde` a `punto` no hay nada que tape (el bicho mismo no tapa; los cristales tampoco).
local function sinParedes(desde: Vector3, punto: Vector3, bicho: Instance): boolean
	local origen = desde
	for _ = 1, RAYOS do
		local hacia = punto - origen
		if hacia.Magnitude < 0.05 then
			return true
		end
		local choque = workspace:Raycast(origen, hacia, rayo)
		if not choque or choque.Instance:IsDescendantOf(bicho) then
			return true
		end
		if choque.Instance.Transparency < CRISTAL then
			return false
		end
		origen = choque.Position + hacia.Unit * 0.05 -- a través del cristal
	end
	return false
end

-- Si el punto está en la pantalla (sin los bordes) y delante.
local function enPantalla(punto: Vector3): boolean
	local p, dentro = camara:WorldToViewportPoint(punto)
	if not dentro or p.Z <= 0 then
		return false
	end
	local vp = camara.ViewportSize
	return p.X >= vp.X * C.Borde and p.X <= vp.X * (1 - C.Borde) and p.Y >= vp.Y * C.Borde
		and p.Y <= vp.Y * (1 - C.Borde)
end

-- A qué distancia se ve el bicho (nil si no se ve): por la cabeza o por el cuerpo.
local function seVe(bicho: Instance, desde: Vector3): number?
	if not bicho:IsA("Model") or fingiendo(bicho) then
		return nil
	end
	local hum = bicho:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health <= 0 then
		return nil
	end
	local raiz = bicho:FindFirstChild("HumanoidRootPart")
	local cabeza = bicho:FindFirstChild("Cabeza") or bicho:FindFirstChild("Head")
	for _, parte in { cabeza, raiz } do
		if parte and parte:IsA("BasePart") then
			local d = (parte.Position - desde).Magnitude
			if d <= C.Lejos and enPantalla(parte.Position) and sinParedes(desde, parte.Position, bicho) then
				return d
			end
		end
	end
	return nil
end

local function cortarLatido()
	if latido then
		latido:Destroy()
		latido = nil
	end
end

-- El susto de ver uno a `distancia` studs.
local function asustar(distancia: number, ahora: number)
	local f = PavorCuentas.fuerza(distancia)
	if f <= 0 then
		return
	end
	-- El pavor: desde lo que quede o lo nuevo, lo que sea más.
	local queda = if pavorDesde then PavorCuentas.queda(ahora - pavorDesde, pavorNivel, pavorDura) else 0
	pavorNivel = PavorCuentas.sumar(queda, f)
	pavorDura = PavorCuentas.dura(pavorNivel)
	pavorDesde = ahora
	-- El vértigo: uno nuevo si el de antes ya acabó; si aún se está cerrando, más fuerte.
	if not vertigoDesde or ahora - vertigoDesde >= PavorCuentas.finVertigo() then
		vertigoDesde, vertigoFuerza = ahora, f
	elseif ahora - (vertigoDesde :: number) < C.Vertigo.Cierra then
		vertigoFuerza = math.max(vertigoFuerza, f)
	end
	-- El golpe de tensión, flojo (y no dos seguidos).
	if ahora - ultimoSobresalto >= C.SobresaltoCada then
		ultimoSobresalto = ahora
		local s = Sonido.tocar("Sobresalto")
		s.Volume *= C.Sobresalto * (0.6 + 0.4 * f)
		pcall(ManosGestos.sobresalto, C.Manos * f)
	end
	-- El latido, desde ahora (si ya sonaba, sigue: con la fuerza mayor).
	if latido then
		latidoFuerza = math.max(latidoFuerza, f)
	else
		latido = Sonido.bucle("Latido")
		local l = latido :: Sound
		latidoBase = l.Volume
		latidoFuerza = f
		l.Volume = latidoBase * C.Latido.Volumen * f
	end
	latidoDesde = ahora
end

-- Mira los bichos: el que entra en la vista y no se veía desde hace Olvida s, asusta.
local function mirar(ahora: number)
	local carpeta = workspace:FindFirstChild("Bichos")
	if not carpeta then
		return
	end
	local personaje = jugador.Character
	if personaje and filtroDe ~= personaje then
		filtroDe = personaje
		rayo.FilterDescendantsInstances = { personaje, camara } -- tú y lo que cuelga de la cámara (las manos)
	end
	local desde = camara.CFrame.Position
	local masCerca: number? = nil
	for _, bicho in carpeta:GetChildren() do
		local d = seVe(bicho, desde)
		if d then
			local antes = vistos[bicho]
			vistos[bicho] = ahora
			if antes == nil or ahora - antes >= C.Olvida then
				masCerca = math.min(masCerca or math.huge, d)
			end
		end
	end
	if masCerca then
		asustar(masCerca, ahora)
	end
end

local function quitar()
	if puesto then
		puesto = false
		CuerpoVista.ponerPavor(0, 0, 0, 0)
		Manos.pavor(0)
	end
end

local function paso()
	local ahora = os.clock()
	local siente = puedeSentir()
	if siente and ahora >= proximaMirada then
		proximaMirada = ahora + C.Cada
		mirar(ahora)
	end
	-- Lo que queda de cada cosa (el tiempo corre también escondido: al salir sigue lo que quede).
	local nivel = 0
	if pavorDesde then
		nivel = PavorCuentas.queda(ahora - pavorDesde, pavorNivel, pavorDura)
		if nivel <= 0 then
			pavorDesde, pavorNivel = nil, 0
		end
	end
	local vertigo = 0
	if vertigoDesde then
		local t = ahora - vertigoDesde
		if t >= PavorCuentas.finVertigo() then
			vertigoDesde = nil
		else
			vertigo = PavorCuentas.vertigo(t) * vertigoFuerza
		end
	end
	if not siente then
		cortarLatido() -- escondido, el latido es de MuerteVista; muerto o en una cinemática, fuera
		vertigoDesde = nil
		quitar()
		return
	end
	-- El latido se apaga solo.
	local l = latido
	if l then
		local k = PavorCuentas.latido(ahora - latidoDesde, latidoFuerza)
		if k <= 0 then
			cortarLatido()
		else
			l.Volume = latidoBase * C.Latido.Volumen * latidoFuerza * k
		end
	end
	if nivel <= 0 and vertigo <= 0 then
		quitar()
		return
	end
	puesto = true
	if jugador:GetAttribute("Rendimiento") == true then
		CuerpoVista.ponerPavor(0, 0, 0, 0)
		Manos.pavor(nivel * C.Temblor.Rendimiento)
	else
		CuerpoVista.ponerPavor(C.Vertigo.Campo * vertigo, C.Vertigo.Recula * vertigo, nivel * C.Respira, nivel)
		Manos.pavor(nivel)
	end
end

-- El pavor que queda ahora (0..1), para quien lo quiera leer (y el banco).
function PavorVista.nivel(): number
	if not pavorDesde then
		return 0
	end
	return PavorCuentas.queda(os.clock() - pavorDesde, pavorNivel, pavorDura)
end

function PavorVista.start()
	-- Solo en Studio, para probarlo sin esperar a un bicho: poner al jugador el atributo PavorPrueba = distancia en studs
	-- (desde execute_luau en el cliente) hace el susto de ver uno a esa distancia.
	if RunService:IsStudio() then
		jugador:GetAttributeChangedSignal("PavorPrueba"):Connect(function()
			local d = jugador:GetAttribute("PavorPrueba")
			if type(d) == "number" and puedeSentir() then
				asustar(d, os.clock())
			end
			if d ~= nil then
				jugador:SetAttribute("PavorPrueba", nil)
			end
		end)
	end
	-- Antes de la cámara de Roblox y de CuerpoVista (Camera - 1): lo de este fotograma ya va puesto.
	RunService:BindToRenderStep("Pavor", Enum.RenderPriority.Camera.Value - 2, paso)
end

return PavorVista
