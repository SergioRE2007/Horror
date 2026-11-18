-- El susto del Golpeador al pillarte (la escena de muerte; GolpeadorVista.rugir lo empieza): ver SUSTO. Lo pone encima
-- de todo en cada fotograma (GolpeadorVista: paso antes de gatear, asustar al final); si te pilló gateando, lo hace en el
-- suelo con GolpeadorVistaGateo. La cámara la lleva MuerteVista. Librería sin start().
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BichoComun = require(script.Parent.BichoComun)
local Cuerpo = require(script.Parent.GolpeadorVistaCuerpo)
local Sonido = require(script.Parent.Sonido)

local Muerte = {}

-- El susto al pillarte (14.10, pedido por el usuario: "hay que mejorar el screamer"). Los tiempos, en
-- Config.Golpeador.Susto (los lee también MuerteVista, que lleva la cámara): si te pilló gateando, primero Arrastra (te
-- saca de debajo del mueble con el brazo que metía); luego Mira (quieto, mirándote), Salta (se abalanza: torso y
-- cabeza adelante, brazos abriéndose), Encima (boca abierta del todo, la cabeza a tirones y las garras entrando por
-- los lados de la pantalla) y Tiron (el último empujón). Se queda así hasta Espera y luego vuelve a lo suyo. A ojo.
local SUSTO = {
	Entra = 0.12, -- s en ponerse en la pose (de pie)
	Sale = 0.5, -- s en volver a lo suyo al acabar (de pie)
	Antes = 0.3, -- gateando, deja el suelo esto antes de Espera (ya en el fundido a negro): el banco del gateo le mira
	-- levantarse 5 s después de pillarte
	Boca = { Arrastra = 0.6, Mira = 0.4, Salta = 1, Encima = 1.25 }, -- radianes (Malla3D: ~1 son unos 60°)
	Tirones = { 0.06, 0.12 }, -- s entre dos tirones de la cabeza, encima de ti
	Tiron = Vector3.new(0.14, 0.42, 0.55), -- lo que da cada tirón como mucho (cabeceo, giro, ladeo)
	-- La punta de las garras en la cara (Cara3D: X a su derecha, -Z hacia delante; la cámara va a 2,6 en su -Z): de
	-- dónde entran, a dónde llegan (los lados de la pantalla) y a dónde se cierran en el tirón. X va por lados.
	GarrasDesde = Vector3.new(3.2, -0.8, 0.4),
	Garras = Vector3.new(1.05, -0.5, -1.6),
	GarrasTiron = Vector3.new(0.7, -0.35, -1.85),
	GarrasEntran = 0.2, -- s que tardan en entrar
	Levanta = 0.9, -- gateando, studs que levanta la cabeza del suelo tras sacarte
	Giro = 1.2, -- gateando, radianes que gira la cara como mucho hacia ti (fuera del mueble)
}
local FASES = { "Mira", "Salta", "Encima", "Tiron" }

type Bicho = Cuerpo.Bicho
type Susto = Cuerpo.Susto

local azar = BichoComun.azar
local rango, suave = BichoComun.rango, BichoComun.suaveSinTope
local ALTURA, LADOS = Cuerpo.ALTURA, Cuerpo.LADOS
local cabezaHacia, alcanzar, garrasSobreSuelo = Cuerpo.cabezaHacia, Cuerpo.alcanzar, Cuerpo.garrasSobreSuelo

-- Por dónde va: la fase, el tirón de la cabeza y a dónde mira. Antes de gatear (que lo usa si te pilló gateando).
local function pasoSusto(b: Bicho, dt: number, ahora: number)
	local s = b.susto
	if not s then
		return
	end
	local c = Config.Golpeador.Susto
	local t = ahora - s.t0
	local fin = if s.gatea then c.Espera - SUSTO.Antes else c.Espera
	if t >= fin + (if s.gatea then 0 else SUSTO.Sale) then
		b.susto = nil
		return
	end
	s.w = if t < fin then math.min(1, t / SUSTO.Entra) else 1 - (t - fin) / SUSTO.Sale
	local antes = s.fase
	local fase, u = "Fin", 1
	local resto = t
	if s.gatea then
		if resto < c.Arrastra then
			fase, u = "Arrastra", resto / c.Arrastra
		end
		resto -= c.Arrastra
	end
	if fase == "Fin" and resto >= 0 then
		for _, f in FASES do
			local dura = (c :: any)[f]
			if resto < dura then
				fase, u = f, resto / dura
				break
			end
			resto -= dura
		end
	end
	s.fase, s.u = fase, u
	if fase == "Arrastra" or fase == "Mira" then
		s.mirar = workspace.CurrentCamera.CFrame.Position -- tu cabeza (la cámara la lleva MuerteVista)
	elseif not s.dir then
		s.dir = b.raiz.CFrame:VectorToObjectSpace(s.mirar - b.cabeza.Position)
	end
	if fase == "Salta" and antes ~= "Salta" then
		Sonido.en("Paso", b.raiz.Position - Vector3.new(0, ALTURA, 0), 0.5) -- el pisotón al abalanzarse
	end
	if fase == "Encima" then
		if ahora >= s.proximo then
			s.proximo = ahora + rango(SUSTO.Tirones)
			local k = SUSTO.Tiron
			s.meta = Vector3.new(azar:NextNumber(-k.X, k.X), azar:NextNumber(-k.Y, k.Y), azar:NextNumber(-k.Z, k.Z))
		end
	else
		s.meta = Vector3.zero
	end
	s.tir = s.tir:Lerp(s.meta, math.min(1, dt * 30))
end

-- Cuánto abre la boca en cada fase del susto (radianes).
local function bocaSusto(s: Susto, ahora: number): number
	local B = SUSTO.Boca
	if s.fase == "Arrastra" then
		return B.Arrastra + 0.08 * math.sin(ahora * 21)
	elseif s.fase == "Mira" then
		return B.Mira + 0.04 * math.sin(ahora * 5)
	elseif s.fase == "Salta" then
		return B.Mira + (B.Salta - B.Mira) * suave(s.u)
	end
	return B.Encima + 0.07 * math.sin(ahora * 37)
end

-- La pose del susto, encima de todo: de pie, el cuerpo entero; gateando (lo hace gatear), solo las garras.
local function asustar(b: Bicho, ahora: number, fino: boolean)
	local s = b.susto
	if not s then
		return
	end
	local m = b.motores
	local f, u = s.fase, s.u
	local k = if f == "Mira" or f == "Arrastra" then 0 elseif f == "Salta" then 1 - (1 - u) * (1 - u) else 1
	local kt = if f == "Tiron" then suave(u) elseif f == "Fin" then 1 else 0
	local w = if s.gatea then 1 else suave(math.clamp(s.w, 0, 1))
	if not s.gatea then
		local tiembla = if f == "Encima" then 0.025 * math.sin(ahora * 43) else 0
		m.Torso.Transform = m.Torso.Transform:Lerp(CFrame.new(0, -0.25 * k - 0.1 * kt, -0.7 * k - 0.5 * kt)
			* CFrame.Angles(-0.12 - 0.45 * k - 0.2 * kt + tiembla, 0, tiembla * 0.6), w)
		local dir = s.dir or b.raiz.CFrame:VectorToObjectSpace(s.mirar - b.cabeza.Position)
		m.Cabeza.Transform = m.Cabeza.Transform:Lerp(
			cabezaHacia(m, dir, 0.3 - 0.15 * k + s.tir.Z, CFrame.Angles(s.tir.X, s.tir.Y, 0)), w)
		m.Mandibula.Transform = m.Mandibula.Transform:Lerp(CFrame.Angles(-bocaSusto(s, ahora), 0, 0), w)
		for _, lado in LADOS do
			local motor = m[if lado < 0 then "BrazoI" else "BrazoD"]
			motor.Transform = motor.Transform:Lerp(CFrame.Angles(0.15 + 0.75 * k + 0.3 * kt, 0, lado * (0.12 + 1.3 * k - 0.3 * kt)), w)
		end
		m.PiernaI.Transform = m.PiernaI.Transform:Lerp(CFrame.Angles(-0.2 * k, 0, 0), w)
		m.PiernaD.Transform = m.PiernaD.Transform:Lerp(CFrame.Angles(0.3 * k, 0, 0), w)
		garrasSobreSuelo(b) -- (echado adelante, colgando, las garras rozaban el suelo)
	end
	-- Las garras entrando por los lados de la pantalla: solo con la malla (los bloques no tienen codo: rectos, cruzarían
	-- la cámara). Van en la cara de la malla (donde va la cámara), así siguen a los tirones de la cabeza.
	local cara = b.rig and b.rig.cara
	if b.codos and cara and (f == "Encima" or f == "Tiron" or f == "Fin") then
		local entra = if f == "Encima" then suave(math.min(1, u * Config.Golpeador.Susto.Encima / SUSTO.GarrasEntran)) else 1
		-- El marco: en la cara y con -Z hacia la cámara (el -Z de Cara3D apunta hacia abajo con él encorvado: las
		-- garras salían bajo la barbilla, fuera de la pantalla; probado en Studio).
		local ojoCam = workspace.CurrentCamera.CFrame.Position
		local marco = if (ojoCam - cara.Position).Magnitude > 0.3 then CFrame.lookAt(cara.Position, ojoCam) else cara.CFrame
		local enCara = b.raiz.CFrame:ToObjectSpace(marco)
		for _, lado in LADOS do
			local en = SUSTO.GarrasDesde:Lerp(SUSTO.Garras, entra):Lerp(SUSTO.GarrasTiron, kt)
			local zarpa = if fino then 0.06 * math.sin(ahora * 29 + lado * 2) else 0
			local punto = enCara * Vector3.new(lado * en.X, en.Y + zarpa, en.Z)
			alcanzar(b, lado, punto, enCara:VectorToWorldSpace(Vector3.new(lado, -0.4, 0.5)), w)
		end
	end
end

Muerte.SUSTO = SUSTO
Muerte.paso, Muerte.boca, Muerte.asustar = pasoSusto, bocaSusto, asustar

return Muerte
