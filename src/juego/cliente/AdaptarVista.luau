-- Ojos que se acostumbran a la oscuridad (y deslumbran) (pedido por el usuario: "mejorar la inmersión"; docs/sistemas/
-- adaptar.md). Todo en el cliente y solo de adorno: un ColorCorrectionEffect propio (AdaptarOjos, en Lighting) que se
-- suma a los de Ambiente y MirarVista sin tocarlos.
--   Te quedas a oscuras de golpe (apagas la linterna, salta el generador, te metes en un armario): casi negro y en 8-12 s
--   los ojos se acostumbran, un pelo más claro que lo normal y en grises: empiezan a verse siluetas.
--   Llega mucha luz de golpe estando hecho a la oscuridad (enciendes la linterna, un relámpago, el flash de otro, sales
--   al día): te deslumbra (blanco cálido, contraste hundido) y se va en ~1 s.
--   La linterna de otro jugador a la cara (a menos de Ajena.Lejos studs, dentro de Ajena.Angulo grados de su haz y sin
--   pared en medio) deslumbra mientras te apunte.
-- La luz que te llega, cada Config.Adaptar.Cada s: de día fuera (rayo hacia arriba: techo o no), tu linterna (y su
-- rebote si da contra algo cerca), las luces del mundo a su alcance y sin pared (su Brightness de verdad: ya lleva el
-- parpadeo de Ambiente.factor y el generador; las de luna, etiqueta Luna, con su peso; la chimenea, las bengalas y el
-- flash de los demás también son luces) y, en cada fotograma, el relámpago (Ambiente.destello, por el cielo que se ve:
-- Ambiente.cieloVisto, el mismo del destello de la pantalla; en el sótano o escondido, casi nada).
-- Escondido sigue (con menos luz: Luz.Escondido). Muerto, en cinemáticas (cámara Scriptable sin vistazo ni escondite) o
-- mirando por la mirilla (Mirilla), a cero; al volver, los ojos ya están hechos a la luz de entonces (sin deslumbre).
-- Con Rendimiento igual (cuesta poco), salvo la linterna de otro: Ajena.Rendimiento de fuerte.
-- Las cuentas, en AdaptarCuentas (banco tests/bancos/adaptar.luau). Un solo Heartbeat.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AdaptarCuentas = require(script.Parent.AdaptarCuentas)
local AireVista = require(script.Parent.AireVista)
local Ambiente = require(script.Parent.Ambiente)
local Camara = require(script.Parent.Camara)
local Config = require(ReplicatedStorage.Shared.Config)

local AdaptarVista = {}

local C = Config.Adaptar
local jugador = Players.LocalPlayer
local CRISTAL = 0.3 -- piezas con esta transparencia o más no tapan (cristales, telarañas, niebla)
local CERCA_LUZ = 2 -- studs: un rayo que choca a menos de esto de la luz llega (la pantalla, la bombilla, la cabeza)
local BLANCO = Color3.new(1, 1, 1)

local function rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end
local FRIO = rgb(C.Acostumbrado.Frio)
local CALIDO = rgb(C.Deslumbre.Calido)

local efecto: ColorCorrectionEffect
-- Las luces del mundo (claves débiles: la que se destruye se va sola).
local luces: { [Light]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local rayo = RaycastParams.new()
rayo.FilterType = Enum.RaycastFilterType.Exclude
rayo.IgnoreWater = true
local filtroDe: Model? = nil

-- El estado.
local hecho = 0 -- a qué luz están hechos los ojos (0..1)
local suma = 0 -- la luz medida (sin el relámpago)
local ajena = 0 -- la linterna de otro a la cara, ya suavizada
local ajenaMeta = 0
local proxima = 0
local reiniciar = true -- en la próxima medida, los ojos se hacen a la luz que haya (sin deslumbre)
local puesto = false -- si el efecto está encendido
local prueba: number? = nil -- solo en Studio: AdaptarPrueba

-- Las luces que no cuentan aquí: las linternas (la tuya va aparte; la de otro a la cara también) y lo que cuelga de tu
-- personaje (tu flash: ya lo pinta de blanco EquipoVista).
local function cuenta(luz: Light): boolean
	local padre = luz.Parent
	if not padre or padre.Name == "Linterna" then
		return false
	end
	local personaje = jugador.Character
	return not (personaje and luz:IsDescendantOf(personaje))
end

local function apuntar(d: Instance)
	if d:IsA("Light") then
		luces[d] = true
	end
end

-- Dónde está la luz y hacia dónde mira (el CFrame de lo que la lleva).
local function sitio(luz: Light): CFrame?
	local padre = luz.Parent
	if padre and padre:IsA("BasePart") then
		return padre.CFrame
	elseif padre and padre:IsA("Attachment") then
		return padre.WorldCFrame
	end
	return nil
end

-- Si de `desde` a `punto` llega la luz (los cristales no tapan; lo que choca muy cerca de la luz, tampoco).
local function llega(desde: Vector3, punto: Vector3): boolean
	local origen = desde
	for _ = 1, 3 do
		local hacia = punto - origen
		if hacia.Magnitude < CERCA_LUZ then
			return true
		end
		local choque = workspace:Raycast(origen, hacia, rayo)
		if not choque or (choque.Position - punto).Magnitude < CERCA_LUZ then
			return true
		end
		if choque.Instance.Transparency < CRISTAL then
			return false
		end
		origen = choque.Position + hacia.Unit * 0.05
	end
	return false
end

-- Las luces del mundo que te llegan: las que más dan, con un rayo cada una (como mucho C.Rayos).
local function delMundo(ojo: Vector3): number
	local L = C.Luz
	local candidatas: { { luz: number, punto: Vector3 } } = {}
	for luz in luces do
		if not luz.Parent then
			luces[luz] = nil
			continue
		end
		if not luz.Enabled or luz.Brightness <= 0 or not cuenta(luz) then
			continue
		end
		local cf = sitio(luz)
		if not cf then
			continue
		end
		local alcance = luz.Range
		local haciaMi = ojo - cf.Position
		local distancia = haciaMi.Magnitude
		if distancia >= alcance then
			continue
		end
		local peso = if CollectionService:HasTag(luz.Parent :: Instance, "Luna") then L.Luna else L.Bombilla
		local da = AdaptarCuentas.punto(distancia, alcance, luz.Brightness) * peso
		if luz:IsA("SpotLight") or luz:IsA("SurfaceLight") then
			local angulo = (luz :: any).Angle :: number
			local dir = cf:VectorToWorldSpace(Vector3.FromNormalId((luz :: any).Face))
			da *= AdaptarCuentas.foco(haciaMi, dir, angulo)
		end
		if da >= C.Minimo then
			table.insert(candidatas, { luz = da, punto = cf.Position })
		end
	end
	table.sort(candidatas, function(a, b)
		return a.luz > b.luz
	end)
	local total = 0
	for i = 1, math.min(#candidatas, C.Rayos) do
		local c = candidatas[i]
		if llega(ojo, c.punto) then
			total += c.luz
		end
	end
	return total
end

-- De 0 a 1, lo que te deslumbra la linterna de otro (la que más).
local function deOtros(ojo: Vector3): number
	local mas = 0
	for _, otro in Players:GetPlayers() do
		if otro == jugador or otro:GetAttribute("Linterna") ~= true then
			continue
		end
		local personaje = otro.Character
		local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
		local cabeza = personaje and personaje:FindFirstChild("Head") :: BasePart?
		if not raiz or not cabeza then
			continue
		end
		-- Como en BrazosVista: hacia donde mira su raíz, inclinado por su Mirada.
		local m = otro:GetAttribute("Mirada")
		local mirada = if type(m) == "number" and m == m then math.clamp(m, -1.4, 1.4) else 0
		local dir = (raiz.CFrame.Rotation * CFrame.Angles(mirada, 0, 0)).LookVector
		local mano = personaje:FindFirstChild("LeftHand") :: BasePart?
		local origen = if mano then mano.Position else cabeza.Position
		local k = AdaptarCuentas.apunta(origen, dir, ojo)
		if k > mas and llega(ojo, origen) then
			mas = k
		end
	end
	return mas
end

-- Mide la luz que te llega (sin el relámpago, que va en cada fotograma).
local function medir()
	local personaje = jugador.Character
	if personaje ~= filtroDe then
		filtroDe = personaje
		rayo.FilterDescendantsInstances = if personaje then { personaje, Camara.get() } else { Camara.get() }
	end
	local L = C.Luz
	local cf = Camara.get().CFrame
	local ojo = cf.Position
	local s = C.Base
	-- El día (rayo hacia arriba: bajo techo o no; los cristales no cuentan como techo).
	local techo = workspace:Raycast(ojo, Vector3.new(0, L.Techo, 0), rayo)
	local fuera = techo == nil or techo.Instance.Transparency >= CRISTAL
	local fase, inicio, fin = workspace:GetAttribute("Fase"), workspace:GetAttribute("FaseInicio"),
		workspace:GetAttribute("FaseFin")
	if type(inicio) == "number" and type(fin) == "number" then
		local p = math.clamp((workspace:GetServerTimeNow() - inicio) / math.max(1, fin - inicio), 0, 1)
		s += (1 - AireVista.noche(fase, p)) * (if fuera then L.Dia else L.DiaDentro)
	else
		s += if fuera then L.Dia else L.DiaDentro -- sin ciclo (al cargar): de día
	end
	-- Tu linterna (EquipoVista la apaga en las cinemáticas, que aquí ya no llegan).
	if jugador:GetAttribute("Linterna") == true then
		local choque = workspace:Raycast(ojo, cf.LookVector * L.RebotaHasta, rayo)
		s += L.Linterna + L.Rebote * AdaptarCuentas.rebote(if choque then choque.Distance else nil)
	end
	s += delMundo(ojo)
	local escondido = jugador:GetAttribute("Escondido") ~= nil
	if escondido then
		s *= L.Escondido
	end
	suma = s
	local k = deOtros(ojo)
	if jugador:GetAttribute("Rendimiento") == true then
		k *= C.Ajena.Rendimiento
	end
	ajenaMeta = k * C.Ajena.Fuerza
end

-- Si ahora toca ver con los ojos: vivo, sin cinemática y sin mirar por la mirilla.
local function ve(): boolean
	if jugador:GetAttribute("Muerto") or jugador:GetAttribute("Mirilla") == true then
		return false
	end
	if Camara.get().CameraType == Enum.CameraType.Scriptable and jugador:GetAttribute("Vistazo") == nil
		and jugador:GetAttribute("Escondido") == nil then
		return false
	end
	local personaje = jugador.Character
	local hum = personaje and personaje:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

local function quitar()
	if puesto then
		puesto = false
		efecto.Brightness, efecto.Contrast, efecto.Saturation, efecto.TintColor = 0, 0, 0, BLANCO
		efecto.Enabled = false
	end
end

-- La luz de ahora (0..1), con el relámpago de este fotograma por lo que se ve del cielo (Ambiente.cieloVisto, que ya
-- tiene en cuenta dentro, el sótano y el escondite: el mismo que el destello de la pantalla de Ambiente).
local function luzAhora(): number
	return AdaptarCuentas.juntar(suma + AdaptarCuentas.rayo(Ambiente.destello or 0, Ambiente.cieloVisto or 1))
end

local function paso(dt: number)
	if not ve() then
		reiniciar = true
		proxima = 0 -- al volver, se mide enseguida
		ajena, ajenaMeta = 0, 0
		quitar()
		return
	end
	local ahora = os.clock()
	if ahora >= proxima then
		proxima = ahora + C.Cada
		medir()
		if reiniciar then
			reiniciar = false
			hecho = luzAhora()
		end
	end
	local luz = luzAhora()
	local p = prueba
	if p then
		prueba = nil
		hecho = p
	end
	hecho = AdaptarCuentas.acostumbrar(hecho, luz, dt)
	ajena = AdaptarCuentas.seguir(ajena, ajenaMeta, dt)
	local e = AdaptarCuentas.efecto(hecho, luz, ajena)
	if AdaptarCuentas.nada(e) then
		quitar()
		return
	end
	puesto = true
	efecto.Enabled = true
	efecto.Brightness = e.brillo
	efecto.Contrast = e.contraste
	efecto.Saturation = e.saturacion
	efecto.TintColor = BLANCO:Lerp(FRIO, e.frio):Lerp(CALIDO, e.calido)
end

-- Para quien lo quiera leer (y para probar en Studio): a qué luz están hechos los ojos y la luz de ahora (0..1).
function AdaptarVista.estado(): (number, number)
	return hecho, luzAhora()
end

function AdaptarVista.start()
	efecto = Instance.new("ColorCorrectionEffect")
	efecto.Name = "AdaptarOjos"
	efecto.Enabled = false
	efecto.Parent = Lighting
	workspace.DescendantAdded:Connect(apuntar)
	for _, d in workspace:GetDescendants() do
		apuntar(d)
	end
	-- Solo en Studio, para probarlo sin esperar: poner al jugador el atributo AdaptarPrueba = 0..1 (desde execute_luau
	-- en el cliente) hace los ojos a esa luz (0: del todo acostumbrado a la oscuridad; luego enciende la linterna).
	if RunService:IsStudio() then
		jugador:GetAttributeChangedSignal("AdaptarPrueba"):Connect(function()
			local v = jugador:GetAttribute("AdaptarPrueba")
			if type(v) == "number" then
				prueba = math.clamp(v, 0, 1)
			end
			if v ~= nil then
				jugador:SetAttribute("AdaptarPrueba", nil)
			end
		end)
	end
	RunService.Heartbeat:Connect(paso)
end

return AdaptarVista
