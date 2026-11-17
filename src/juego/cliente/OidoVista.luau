--!strict
-- Oído: sonido tapado por las paredes y eco de cada sala (docs/sistemas/oido.md). Solo en el cliente y sin sonidos
-- nuevos: cambia cómo se oye lo que ya suena.
--   Paredes: cada sonido en 3D (Sonido.en, los bucles de Sonido.bucle colgados de algo y lo que se apunte con
--   OidoVista.seguir) mira al empezar, y cada Config.Oido.Cada segundos mientras suena, cuántas paredes hay entre la
--   cámara y su punto (rayos sin bichos ni personajes, y MuebleRayo para los muebles; hasta MaxParedes). Por cada pared,
--   un EqualizerSoundEffect le quita agudos y medios y le baja el volumen: el Golpeador en la ventana de otra sala se oye
--   sordo y al abrir la puerta suena claro de golpe. El volumen se baja con el ecualizador, no con Volume (los bichos y
--   los bucles mueven su Volume cada fotograma).
--   Escondido (armario, debajo de la cama: atributo Escondido de Muerte), todo lo de fuera se oye a través de la
--   madera, menos lo tuyo: tu respiración y tu latido (Sonido.tocar y los bucles sin posición no se siguen).
--   Eco: SoundService.AmbientReverb según la zona de Config.Oido.Zonas en la que esté la cámara.
--   Con Rendimiento, el rayo cada CadaRendimiento segundos y solo para los sonidos a menos de CercaRendimiento.
-- Las cuentas (paredes → ganancias, punto → eco, contar paredes con un rayo cualquiera) son funciones puras para el
-- banco (tests/bancos/oido.luau).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local MuebleRayo = require(script.Parent.MuebleRayo)

local CFG = Config.Oido
local jugador = Players.LocalPlayer

local OidoVista = {}

-- Lo que se sabe de cada sonido seguido. `eq` se crea la primera vez que hace falta (casi todos los pasos y golpes
-- suenan sin nada delante y no lo necesitan).
type Seguido = { eq: EqualizerSoundEffect?, siguiente: number, paredes: number }
local seguidos: { [Sound]: Seguido } = {}

local reverbPuesto: string? = nil
local escondido = false

------------------------------------------------------------------------------------------------------------------------
-- Cuentas puras.

-- Las ganancias del ecualizador (dB: graves, medios, agudos) con `paredes` entre la cámara y el sonido, y escondido o
-- no. El volumen que queda (PorPared.Volumen por pared) se pasa a dB y se resta a las tres bandas.
function OidoVista.ganancias(paredes: number, tapado: boolean, cfg: any): (number, number, number)
	local bajo, medio, alto = 0, 0, 0
	local function sumar(t: any, veces: number)
		if veces <= 0 then
			return
		end
		local v = 20 * math.log10(math.max(t.Volumen, 1e-3)) * veces
		bajo += v
		medio += v + t.Medios * veces
		alto += v + t.Agudos * veces
	end
	sumar(cfg.PorPared, math.clamp(math.floor(paredes), 0, cfg.MaxParedes))
	if tapado then
		sumar(cfg.Escondido, 1)
	end
	return math.max(bajo, -80), math.max(medio, -80), math.max(alto, -80)
end

-- El eco (nombre de Enum.ReverbType) del punto `p`: la primera zona de cfg.Zonas en la que esté; si ninguna, cfg.Fuera.
-- Cada zona tiene Cajas ({ x1, x2, y1, y2, z1, z2 }) o un círculo en planta (Centro = { x, z } y Radio).
function OidoVista.zona(p: Vector3, cfg: any): string
	for _, z in cfg.Zonas do
		if z.Radio then
			local dx, dz = p.X - z.Centro[1], p.Z - z.Centro[2]
			if dx * dx + dz * dz < z.Radio * z.Radio then
				return z.Reverb
			end
		else
			for _, c in z.Cajas do
				if p.X > c[1] and p.X < c[2] and p.Y > c[3] and p.Y < c[4] and p.Z > c[5] and p.Z < c[6] then
					return z.Reverb
				end
			end
		end
	end
	return cfg.Fuera
end

-- Paredes entre `origen` y `punto` (hasta cfg.MaxParedes). `lanzar(o, d)` es un rayo cualquiera: devuelve dónde toca
-- y si lo tocado cuenta como pared (nil si no toca nada). Se deja sin mirar cfg.Margen junto al sonido (la ventana que
-- golpean no tapa su propio golpe). Golpes más juntos que cfg.Grosor a lo largo del rayo son la misma pared (papel, muro
-- y papel del otro lado); como mucho cfg.Rayos rayos.
function OidoVista.contar(origen: Vector3, punto: Vector3, lanzar: (Vector3, Vector3) -> (Vector3?, boolean), cfg: any): number
	local hacia = punto - origen
	local largo = hacia.Magnitude
	local hasta = largo - cfg.Margen
	if hasta <= 0.05 then
		return 0
	end
	local dir = hacia / largo
	local andado = 0
	local paredes = 0
	local ultima = -math.huge -- dónde (a lo largo del rayo) acabó la última pared contada
	for _ = 1, cfg.Rayos do
		local resto = hasta - andado
		if resto <= 0.05 then
			break
		end
		local pos, cuenta = lanzar(origen + dir * andado, dir * resto)
		if not pos then
			break
		end
		local d = (pos - origen):Dot(dir)
		if cuenta then
			if d - ultima > cfg.Grosor then
				paredes += 1
				if paredes >= cfg.MaxParedes then
					break
				end
			end
			ultima = d
		end
		andado = math.max(d, andado) + 0.05 -- desde dentro de lo tocado: el rayo ya no lo ve y sigue al siguiente
	end
	return paredes
end

------------------------------------------------------------------------------------------------------------------------
-- Rayos de verdad.

local filtro = RaycastParams.new()
filtro.FilterType = Enum.RaycastFilterType.Exclude
filtro.IgnoreWater = true

-- Sin bichos ni personajes (como el filtro de Efectos): no tapan el sonido ni el suyo propio.
local function rehacerFiltro()
	local fuera: { Instance } = {}
	local bichos = workspace:FindFirstChild("Bichos")
	if bichos then
		table.insert(fuera, bichos)
	end
	for _, j in Players:GetPlayers() do
		if j.Character then
			table.insert(fuera, j.Character)
		end
	end
	filtro.FilterDescendantsInstances = fuera
end

-- Las cajas de los muebles alrededor de la cámara (MuebleRayo.cajas recorre la casa: se rehacen cada MuebleCada
-- segundos o al moverse MuebleMover studs, no por rayo).
local cajas: { MuebleRayo.Caja } = {}
local cajasDonde: Vector3? = nil
local cajasCuando = -math.huge

local function cajasCerca(camara: Vector3): { MuebleRayo.Caja }
	local ahora = os.clock()
	if cajasDonde == nil or (camara - cajasDonde).Magnitude > CFG.MuebleMover or ahora - cajasCuando > CFG.MuebleCada then
		cajas = MuebleRayo.cajas(camara, CFG.MuebleRadio)
		cajasDonde = camara
		cajasCuando = ahora
	end
	return cajas
end

-- Si lo tocado tapa como una pared: el terreno, y piezas visibles con dos lados de al menos cfg.Pared (un tronco, una
-- pata o un cristal roto del suelo no tapan; una puerta, un muro, un suelo o un armario sí). Las cajas Choque de los
-- muebles son invisibles a propósito; el tablero de un mueble llega como su Model (con su Tam).
local function esPared(inst: Instance): boolean
	if inst:IsA("Terrain") then
		return true
	end
	local tam: Vector3? = nil
	if inst:IsA("BasePart") then
		if inst.Transparency >= 0.98 and inst.Name ~= "Choque" then
			return false
		end
		tam = inst.Size
	elseif inst:IsA("Model") then
		local t = inst:GetAttribute("Tam")
		if typeof(t) ~= "Vector3" then
			return true
		end
		tam = t
	end
	if not tam then
		return false
	end
	local p = CFG.Pared
	local grandes = (if tam.X >= p then 1 else 0) + (if tam.Y >= p then 1 else 0) + (if tam.Z >= p then 1 else 0)
	return grandes >= 2
end

local cajasRayo: { MuebleRayo.Caja } = {}
local function lanzar(o: Vector3, d: Vector3): (Vector3?, boolean)
	local golpe = MuebleRayo.rayo(o, d, filtro, cajasRayo)
	if not golpe then
		return nil, false
	end
	return golpe.Position, esPared(golpe.Instance)
end

-- Dónde suena: el punto (Attachment), la pieza o el modelo del que cuelga. nil: sin posición (se oye igual en todas
-- partes; solo le afecta estar escondido).
local function dondeSuena(s: Sound): Vector3?
	local p = s.Parent
	if p == nil then
		return nil
	elseif p:IsA("Attachment") then
		return p.WorldPosition
	elseif p:IsA("BasePart") then
		return p.Position
	elseif p:IsA("Model") then
		return p:GetPivot().Position
	end
	return nil
end

local function rendimiento(): boolean
	return jugador:GetAttribute("Rendimiento") == true
end

-- Mide un sonido (si toca) y le pone el ecualizador.
local function mirar(s: Sound, d: Seguido, camara: Vector3, ahora: number)
	local poco = rendimiento()
	d.siguiente = ahora + (if poco then CFG.CadaRendimiento else CFG.Cada)
	local personaje = jugador.Character
	local propio = personaje ~= nil and s:IsDescendantOf(personaje) -- lo tuyo nunca se tapa
	local punto = dondeSuena(s)
	if propio or not punto then
		d.paredes = 0
	else
		local distancia = (punto - camara).Magnitude
		local lejos = if poco then math.min(CFG.CercaRendimiento, s.RollOffMaxDistance) else s.RollOffMaxDistance
		if distancia <= lejos then
			cajasRayo = cajasCerca(camara)
			d.paredes = OidoVista.contar(camara, punto, lanzar, CFG)
		end
		-- Más lejos: no se oye (o con Rendimiento no se mira) y se queda como estaba.
	end
	local tapado = escondido and not propio
	local bajo, medio, alto = OidoVista.ganancias(d.paredes, tapado, CFG)
	local hace = bajo < 0 or medio < 0 or alto < 0
	local eq = d.eq
	if not eq then
		if not hace then
			return
		end
		local nuevo = Instance.new("EqualizerSoundEffect")
		nuevo.Name = "Oido"
		nuevo.Parent = s
		eq = nuevo
		d.eq = nuevo
	end
	assert(eq)
	eq.Enabled = hace
	if eq.LowGain ~= bajo then
		eq.LowGain = bajo
	end
	if eq.MidGain ~= medio then
		eq.MidGain = medio
	end
	if eq.HighGain ~= alto then
		eq.HighGain = alto
	end
end

local function camaraEn(): Vector3?
	local camara = workspace.CurrentCamera
	return if camara then camara.CFrame.Position else nil
end

-- Mira los sonidos a los que les toca (todos con `todos`) y el eco de la sala. Lo llama el bucle de start.
local function repasar(todos: boolean?)
	local camara = camaraEn()
	if not camara then
		return
	end
	local reverb = OidoVista.zona(camara, CFG)
	if reverb ~= reverbPuesto then
		reverbPuesto = reverb
		SoundService.AmbientReverb = (Enum.ReverbType :: any)[reverb]
	end
	if next(seguidos) == nil then
		return
	end
	local ahora = os.clock()
	local filtroHecho = false
	for s, d in seguidos do
		if s.Parent == nil then
			seguidos[s] = nil -- destruido (o soltado): se olvida
			continue
		end
		-- Con media vuelta de holgura: uno que empezó justo después de un repaso no espera dos vueltas.
		if not s.IsPlaying or (not todos and ahora + CFG.Cada / 2 < d.siguiente) then
			continue
		end
		if not filtroHecho then
			rehacerFiltro()
			filtroHecho = true
		end
		mirar(s, d, camara, ahora)
	end
end

------------------------------------------------------------------------------------------------------------------------
-- Para los demás módulos.

-- Que este sonido se oiga tapado por las paredes (y escondido, apagado). Ya colgado de su sitio. Sonido.en y
-- Sonido.bucle lo llaman solos; para los Sound que crea otro módulo a mano, llamarlo tras darle Parent.
function OidoVista.seguir(s: Sound)
	if seguidos[s] then
		return
	end
	local d: Seguido = { eq = nil, siguiente = 0, paredes = 0 }
	seguidos[s] = d
	local camara = camaraEn()
	if camara then
		rehacerFiltro()
		mirar(s, d, camara, os.clock()) -- al empezar: que el primer golpe ya suene sordo
	end
end

function OidoVista.start()
	escondido = typeof(jugador:GetAttribute("Escondido")) == "CFrame"
	jugador:GetAttributeChangedSignal("Escondido"):Connect(function()
		escondido = typeof(jugador:GetAttribute("Escondido")) == "CFrame"
		repasar(true) -- al meterse o salir, de golpe
	end)
	-- Un solo bucle para todo: el eco (unas comparaciones) y los sonidos que suenan y les toca mirar.
	task.spawn(function()
		while true do
			task.wait(CFG.Cada)
			repasar()
		end
	end)
	repasar(true)
end

return OidoVista
