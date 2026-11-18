-- Los sucesos al azar del Golpeador (Armario, Olfatea, Llama, Cara, Aparta, Finge, Garras y Quieto): ver SUCESO. La
-- parte del servidor está en GolpeadorSucesos (Caza los elige). GolpeadorVista los pone encima de la postura de siempre
-- en cada fotograma; el toque del dedo llega por el remote Golpeador "Toque". Librería sin start().
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BichoComun = require(script.Parent.BichoComun)
local Cuerpo = require(script.Parent.GolpeadorVistaCuerpo)
local Sonido = require(script.Parent.Sonido)

local Sucesos = {}

-- Sucesos al azar (14.10, pedido por el usuario: "que no sea siempre igual"). Los decide el servidor (Caza) y los pone
-- en el modelo: Suceso (nombre), SucesoHora, SucesoDura, SucesoMira (Vector3) y SucesoLado (Garras). Cada uno es una
-- pose encima de la de siempre, que entra y sale suave (Sale y Entra: por segundo). Números a ojo.
local SUCESO = {
	Entra = 2.5,
	Sale = 1.8,
	Rapido = 14, -- Aparta: de golpe
	Despacio = 1.1, -- Finge: gira la cabeza despacio
	-- Agachado (Armario y Cara): la cadera baja hasta esto (en la raíz) y el torso cuelga del cuello.
	Cadera = -2.2,
	-- Armario: la cara a `Frente` studs de las rendijas, la cabeza ladeada `Ladeo`; respira cada `Respira` s; las manos
	-- en la pared a los lados del armario (`Manos`: a un lado y arriba de las rendijas).
	Armario = { Frente = 0.4, Ladeo = 0.55, Respira = 3.4, Manos = Vector2.new(2.3, 1.4) },
	-- Olfatea: golpes de nariz cada `Cada` s, en tandas de `Tanda`, con `Pausa` s entre tandas.
	Olfatea = { Cada = 0.34, Tanda = 3, Pausa = { 0.7, 1.1 }, Alza = 0.3 },
	-- Llama: SucesoMira es el centro de la ventana o puerta; el dedo toca `Alto` por encima, `Aparte` studs fuera del
	-- cristal entre toques. El toque i llega a (i - 0,5) · CadaToque s de SucesoHora (Caza): el dedo se acerca `Acerca`
	-- s antes y se retira en `Retira` s.
	Llama = { Alto = 0.6, Aparte = 0.45, Acerca = 0.3, Retira = 0.4 },
	-- Cara: la cara a `Alto` por encima del centro del cristal y a `Frente` de él; las manos a los lados (`Manos`).
	Cara = { Alto = 0.7, Frente = 0.3, Manos = Vector2.new(2.6, 0.9) },
	-- Garras: la punta de las garras a `Pared` de la pared (rayo), arrastrándose `Atras` por detrás del hombro y `Bajo`
	-- por debajo; rayos cada `Cada` s (con Rendimiento, `CadaPoco`), hasta `Largo` studs.
	Garras = { Pared = 0.12, Atras = 1.5, Bajo = 0.9, Cada = 0, CadaPoco = 0.15, Largo = 6 },
	-- Quieto: la cabeza se ladea a tirones de `Paso` radianes cada `Cada` s, crujiendo flojo (`Volumen`).
	Quieto = { Paso = 0.14, Cada = { 0.6, 1.2 }, Max = 1.15, Volumen = 0.3 },
}

type Bicho = Cuerpo.Bicho
type Suceso = Cuerpo.Suceso

local rango, acercar, suave = BichoComun.rango, BichoComun.acercar, BichoComun.suaveSinTope
local ALTURA, LADOS, LADEO, CABEZA_CENTRO, PIERNA = Cuerpo.ALTURA, Cuerpo.LADOS, Cuerpo.LADEO, Cuerpo.CABEZA_CENTRO, Cuerpo.PIERNA
local orientar, mirarCara, torsoEnRaiz = Cuerpo.orientar, Cuerpo.mirarCara, Cuerpo.torsoEnRaiz
local perpendicular, cabezaHacia, alcanzar = Cuerpo.perpendicular, Cuerpo.cabezaHacia, Cuerpo.alcanzar
local bocaDe, provisional = Cuerpo.bocaDe, Cuerpo.provisional
local filtroSuceso = RaycastParams.new()
filtroSuceso.FilterType = Enum.RaycastFilterType.Exclude

-- Por el suelo, de `punto` (en la raíz) hacia la raíz: hacia él desde la ventana, la puerta o la pared.
local function haciaRaiz(punto: Vector3): Vector3
	local n = Vector3.new(-punto.X, 0, -punto.Z)
	return if n.Magnitude > 1e-3 then n.Unit else Vector3.zAxis
end

-- Una dirección (en la raíz) sin torcer el cuello más de `giro` radianes a cada lado ni mirar más arriba o abajo.
local function sinTorcer(dir: Vector3, giro: number): Vector3
	local plano = math.sqrt(dir.X * dir.X + dir.Z * dir.Z)
	local a = math.clamp(math.atan2(-dir.X, -dir.Z), -giro, giro)
	local alza = math.clamp(math.atan2(dir.Y, plano), -0.9, 0.7)
	return Vector3.new(-math.sin(a) * math.cos(alza), math.sin(alza), -math.cos(a) * math.cos(alza))
end

-- Agachado con la cara (la de la malla, o el frente de la cabeza) en `cara` (en la raíz) mirando en `dir`, ladeada: el
-- torso cuelga del cuello como al gatear (la cadera, como mucho hasta SUCESO.Cadera; si hace falta, echada atrás) y las
-- piernas van al suelo bajo ella, por delante. Devuelve el marco del suelo, mirando hacia `dir`.
local function agachar(b: Bicho, cara: Vector3, dir: Vector3, ladeo: number, w: number): CFrame
	local m = b.motores
	-- Al entrar y salir, la cara va en línea recta desde donde la tiene ahora (de pie) y casi sin mezclar: mezclando el
	-- torso y la cabeza, a medio camino la cabeza se iba hacia delante y se metía en la puerta (comprobado con Lune).
	local ahora = torsoEnRaiz(m) * m.Cabeza.C0 * m.Cabeza.Transform * m.Cabeza.C1:Inverse()
	cara = (ahora * b.offCara):Lerp(cara, w)
	dir = ahora.LookVector:Lerp(dir.Unit, w)
	ladeo *= w
	w = math.min(1, w * 4)
	local giroCara = mirarCara(dir, ladeo)
	local cuello = cara - giroCara * b.offCara - giroCara * CABEZA_CENTRO
	local plano = Vector3.new(dir.X, 0, dir.Z)
	local rumbo = CFrame.Angles(0, if plano.Magnitude > 1e-3 then math.atan2(-plano.X, -plano.Z) else 0, 0)
	local fi = math.acos(math.clamp((cuello.Y - SUCESO.Cadera) / 3.8, -0.2, math.cos(0.4)))
	local giroT = rumbo * CFrame.fromMatrix(Vector3.zero, Vector3.xAxis, Vector3.new(0, math.cos(fi), -math.sin(fi)))
	local torsoC = CFrame.new(cuello - giroT * m.Cabeza.C0.Position) * giroT
	m.Torso.Transform = m.Torso.Transform:Lerp(m.Torso.C0:Inverse() * torsoC * m.Torso.C1, w)
	m.Cabeza.Transform = m.Cabeza.Transform:Lerp((torsoC * m.Cabeza.C0):Inverse() * (CFrame.new(cuello) * giroCara), w)
	local marco = CFrame.new(0, -ALTURA, 0) * rumbo
	local torso = marco:Inverse() * torsoEnRaiz(m)
	local cadera = torso * m.Torso.C1.Position
	for _, lado in LADOS do
		local motor = m[if lado < 0 then "PiernaI" else "PiernaD"]
		local junta = cadera + torso.XVector * motor.C0.Position.X - Vector3.new(0, 0.1, 0)
		-- Abiertas a los lados (como una araña; hacia delante, de pie el pie iba 1,5 adelante y se metía en la puerta).
		local cae = math.clamp((junta.Y - 0.3) / PIERNA, 0, 1)
		local hacia = Vector3.new(lado * 0.9, 0, -0.3).Unit * math.sqrt(1 - cae * cae) - Vector3.yAxis * cae
		local parte = CFrame.new(junta) * orientar(hacia, -Vector3.zAxis) * CFrame.new(-motor.C1.Position)
		-- (Más deprisa que el resto: mezclando a medias, a medio camino el pie se metía ~0,2 en el suelo.)
		motor.Transform = motor.Transform:Lerp(motor.C0:Inverse() * (marco * parte) * motor.C1, math.min(1, w * 3))
	end
	return marco
end

-- Los cuerpos que no cuentan para los rayos de los sucesos: los bichos y los jugadores.
local function filtrarSucesos()
	local fuera: { Instance } = {}
	local carpeta = workspace:FindFirstChild("Bichos")
	if carpeta then
		table.insert(fuera, carpeta)
	end
	for _, otro in Players:GetPlayers() do
		if otro.Character then
			table.insert(fuera, otro.Character)
		end
	end
	filtroSuceso.FilterDescendantsInstances = fuera
end

-- `punto` (en el mundo) llevado a la superficie que tenga delante, a lo largo de `n` (hacia él): la pared de al lado de
-- la ventana o del armario, que puede no estar justo en el plano del cristal o de la puerta.
local function enLaPared(punto: Vector3, n: Vector3): Vector3
	local choque = workspace:Raycast(punto + n * 1.5, -n * 3, filtroSuceso)
	return if choque then choque.Position + n * 0.06 else punto
end

------------------------------------------------------------------------------------------------------------------------
-- Sucesos al azar: una pose por suceso (b, el suceso, su peso ya suave, dt, ahora, fino: con los detalles pequeños).
type Pose = (Bicho, Suceso, number, number, number, boolean) -> ()

-- Las manos apoyadas a los lados de `mira` (Armario y Cara): en la pared y, con la malla, con el codo doblado hacia fuera.
local function manosEnPared(b: Bicho, r: Suceso, w: number, mira: Vector3, n: Vector3, manos: Vector2)
	local raiz = b.raiz.CFrame
	local derecha = (-n):Cross(Vector3.yAxis)
	for _, lado in LADOS do
		local mano = r.manos[lado]
		if not mano then
			mano = enLaPared(raiz * (mira + derecha * lado * manos.X + Vector3.new(0, manos.Y, 0)), raiz:VectorToWorldSpace(n))
			r.manos[lado] = mano
		end
		local p = raiz:PointToObjectSpace(mano)
		alcanzar(b, lado, p, derecha * lado * 0.7 + n * 0.5 - Vector3.yAxis * 0.3, w, { p = p, n = n })
	end
	table.insert(b.planos, { p = mira, n = n }) -- (noAtravesar, en animar: después de todo lo que mueve los brazos)
end

local POSES: { [string]: Pose } = {}

-- Armario: pegado a las rendijas (no sabe que estás), la cabeza ladeada mirando dentro, respirando fuerte y lento (la
-- respiración, en animar), con las manos en la pared a los lados del armario.
POSES.Armario = function(b, r, w, _dt, ahora, fino)
	local A = SUCESO.Armario
	local mira = b.raiz.CFrame:PointToObjectSpace(r.mira)
	local n = haciaRaiz(mira)
	local derecha = (-n):Cross(Vector3.yAxis)
	local aire = math.sin(b.respira)
	local mece = if fino then math.sin(ahora * 0.35) else 0
	local cara = mira + n * (A.Frente + 0.06 * aire) + derecha * 0.12 * mece
	local dir = -n + Vector3.new(0, -0.08, 0) + derecha * (if fino then 0.1 * math.sin(ahora * 0.27) else 0)
	agachar(b, cara, dir, A.Ladeo + 0.15 * mece, w)
	b.agacha = math.max(b.agacha, w)
	manosEnPared(b, r, w, mira, n, A.Manos)
	local m = b.motores
	m.Mandibula.Transform = m.Mandibula.Transform:Lerp(CFrame.Angles(-(0.3 + 0.15 * math.max(0, -aire)), 0, 0), w)
end

-- Olfatea: levanta la cabeza hacia ti y da golpes de nariz cortos, en tandas.
POSES.Olfatea = function(b, r, w, _dt, ahora)
	local O = SUCESO.Olfatea
	if r.activo and ahora >= r.proximo then
		if r.tanda <= 0 then
			r.tanda = O.Tanda
		end
		r.tanda -= 1
		r.golpe = ahora
		r.proximo = ahora + (if r.tanda > 0 then O.Cada else rango(O.Pausa))
		if w > 0.5 then
			local nariz = bocaDe(b)
			if Sonido.hay("Olfateo") then
				Sonido.en("Olfateo", nariz)
			else
				provisional("Rafaga", nariz, 1.7, 0.35, 0.16) -- un soplo corto y agudo, como de nariz
			end
		end
	end
	local tg = ahora - r.golpe
	local golpe = if tg < 0.05 then tg / 0.05 elseif tg < 0.2 then 1 - (tg - 0.05) / 0.15 else 0
	local m = b.motores
	m.Torso.Transform = m.Torso.Transform:Lerp(CFrame.new(0, 0.06 * golpe, 0) * CFrame.Angles(0.12 + 0.02 * golpe, 0, 0), w)
	local raiz = b.raiz.CFrame
	local dir = sinTorcer(raiz:PointToObjectSpace(r.mira) - raiz:PointToObjectSpace(b.cabeza.Position), 1.3)
	dir = (dir + Vector3.new(0, O.Alza, 0)).Unit
	local nariz = CFrame.new(0, 0, -0.08 * golpe) * CFrame.Angles(0.12 * golpe, 0, 0)
	m.Cabeza.Transform = m.Cabeza.Transform:Lerp(cabezaHacia(m, dir, 0.15, nariz), w)
	m.Mandibula.Transform = m.Mandibula.Transform:Lerp(CFrame.Angles(-(0.22 - 0.12 * golpe), 0, 0), w)
end

-- Llama: un dedo contra el cristal, tres toques lentos (a la hora que dice Caza; el remote "Toque" lo hace sonar).
POSES.Llama = function(b, r, w, _dt, ahora, fino)
	local L = SUCESO.Llama
	local reglas = Config.Golpeador.Sucesos.Llama
	local mira = b.raiz.CFrame:PointToObjectSpace(r.mira)
	local n = haciaRaiz(mira)
	local derecha = (-n):Cross(Vector3.yAxis)
	if r.lado == 0 then
		r.lado = if mira:Dot(Vector3.xAxis) >= 0 then 1 else -1 -- el brazo del lado de la ventana
	end
	local tt = workspace:GetServerTimeNow() - r.hora
	local cerca = 0
	for i = 1, reglas.Toques do
		local d = tt - (i - 0.5) * reglas.CadaToque
		if d > -L.Acerca and d < L.Retira then
			cerca = math.max(cerca, if d < 0 then suave(1 + d / L.Acerca) else 1 - suave(d / L.Retira))
		end
	end
	local tr = ahora - r.golpe -- por si el reloj no cuadra: el remote también lo pone en el cristal
	if tr < L.Retira then
		cerca = math.max(cerca, 1 - suave(tr / L.Retira))
	end
	local punto = mira + Vector3.new(0, L.Alto, 0) + derecha * r.lado * 0.35 + n * (0.05 + L.Aparte * (1 - cerca))
	local m = b.motores
	m.Torso.Transform = m.Torso.Transform:Lerp(CFrame.Angles(0.06 + 0.03 * math.sin(ahora * 0.8), 0, 0), w)
	local raiz = b.raiz.CFrame
	local dir = sinTorcer(punto - raiz:PointToObjectSpace(b.cabeza.Position), 1.2)
	m.Cabeza.Transform = m.Cabeza.Transform:Lerp(cabezaHacia(m, dir, 0.4 + (if fino then 0.06 * math.sin(ahora * 0.7) else 0)), w)
	alcanzar(b, r.lado, punto, derecha * r.lado * 0.6 - Vector3.yAxis * 0.7, w, { p = mira + n * 0.05, n = n })
	table.insert(b.planos, { p = mira, n = n }) -- (noAtravesar, en animar: después de todo lo que mueve los brazos)
	m.Mandibula.Transform = m.Mandibula.Transform:Lerp(CFrame.Angles(-0.35, 0, 0), w)
end

-- Cara: la cara pegada al cristal mirando dentro, agachado hasta él, con las manos apoyadas a los lados.
POSES.Cara = function(b, r, w, _dt, ahora, fino)
	local C = SUCESO.Cara
	local mira = b.raiz.CFrame:PointToObjectSpace(r.mira)
	local n = haciaRaiz(mira)
	local derecha = (-n):Cross(Vector3.yAxis)
	local mece = if fino then math.sin(ahora * 0.6) else 0
	local cara = mira + Vector3.new(0, C.Alto, 0) + n * C.Frente + derecha * 0.08 * mece
	agachar(b, cara, -n + Vector3.new(0, -0.1, 0), 0.2 + 0.12 * mece, w)
	b.agacha = math.max(b.agacha, w)
	manosEnPared(b, r, w, mira, n, C.Manos)
	local m = b.motores
	m.Mandibula.Transform = m.Mandibula.Transform:Lerp(CFrame.Angles(-(0.45 + 0.12 * mece), 0, 0), w)
end

-- Aparta: se echa atrás de golpe, con la cabeza apartada y los brazos subiendo.
POSES.Aparta = function(b, _r, w)
	local m = b.motores
	m.Torso.Transform = m.Torso.Transform:Lerp(CFrame.new(0, 0.25, 0.9) * CFrame.Angles(0.45, 0, 0), w)
	m.Cabeza.Transform = m.Cabeza.Transform:Lerp(CFrame.fromEulerAnglesYXZ(0.35, 0.45, -0.3), w)
	for _, lado in LADOS do
		local motor = m[if lado < 0 then "BrazoI" else "BrazoD"]
		motor.Transform = motor.Transform:Lerp(CFrame.Angles(0.6, 0, lado * 0.9), w)
	end
	m.Mandibula.Transform = m.Mandibula.Transform:Lerp(CFrame.Angles(-0.9, 0, 0), w)
end

-- Todo quieto (Finge y Quieto): el torso algo echado adelante (y girado `giro`), los brazos colgando, las piernas rectas.
local function quieto(b: Bicho, w: number, giro: number)
	local m = b.motores
	m.Torso.Transform = m.Torso.Transform:Lerp(CFrame.Angles(-0.08, giro, 0), w)
	for _, lado in LADOS do
		local motor = m[if lado < 0 then "BrazoI" else "BrazoD"]
		motor.Transform = motor.Transform:Lerp(CFrame.Angles(0.04, 0, lado * 0.1), w)
	end
	m.PiernaI.Transform = m.PiernaI.Transform:Lerp(CFrame.identity, w)
	m.PiernaD.Transform = m.PiernaD.Transform:Lerp(CFrame.identity, w)
	m.Mandibula.Transform = m.Mandibula.Transform:Lerp(CFrame.Angles(-0.28, 0, 0), w)
end

-- Finge: parado, mira atrás por encima del hombro hacia la casa, despacio (SUCESO.Despacio) y quieto.
POSES.Finge = function(b, r, w)
	local raiz = b.raiz.CFrame
	local mira = raiz:PointToObjectSpace(r.mira)
	local angulo = math.atan2(-mira.X, -mira.Z)
	quieto(b, w, math.clamp(angulo * 0.3, -0.55, 0.55))
	local m = b.motores
	local dir = sinTorcer(mira - raiz:PointToObjectSpace(b.cabeza.Position), 2.1)
	m.Cabeza.Transform = m.Cabeza.Transform:Lerp(cabezaHacia(m, dir, 0.2), w)
end

-- Quieto: alumbrado al fondo, no se mueve; solo la cabeza se ladea despacio, a tirones, crujiendo flojo.
POSES.Quieto = function(b, r, w, dt, ahora)
	local Q = SUCESO.Quieto
	if r.activo and ahora >= r.proximo and r.ladeoMeta < Q.Max then
		r.proximo = ahora + rango(Q.Cada)
		r.ladeoMeta = math.min(Q.Max, r.ladeoMeta + Q.Paso)
		if w > 0.5 then
			Sonido.en("Crujido", b.cabeza.Position, 1.15).Volume *= Q.Volumen
		end
	end
	r.ladeo = acercar(r.ladeo, r.ladeoMeta, dt, 18)
	quieto(b, w, 0)
	local raiz = b.raiz.CFrame
	local m = b.motores
	local dir = sinTorcer(raiz:PointToObjectSpace(r.mira) - raiz:PointToObjectSpace(b.cabeza.Position), 1)
	m.Cabeza.Transform = m.Cabeza.Transform:Lerp(cabezaHacia(m, dir, r.ladeo), w)
end

-- Garras: andando junto a una pared, el brazo de SucesoLado estirado hacia ella arrastrando las garras por detrás del
-- hombro. La pared se busca con un rayo desde el hombro (la punta se queda SUCESO.Garras.Pared antes de ella) y otro
-- del hombro a la punta: si algo se cruza (el marco de una puerta, una esquina) o no hay pared, el brazo se recoge.
POSES.Garras = function(b, r, w, dt, ahora, fino)
	local G = SUCESO.Garras
	local lado = if r.lado < 0 then -1 else 1
	local m = b.motores
	local raiz = b.raiz.CFrame
	local motor = m[if lado < 0 then "BrazoI" else "BrazoD"]
	local ik = b.codos and b.codos[lado]
	local hombro = if ik and b.rig then b.rig.mundo[ik.hueso].Position else (torsoEnRaiz(m) * motor.C0).Position
	local hombroM = raiz * hombro
	if r.activo and ahora - r.rayo >= (if fino then G.Cada else G.CadaPoco) then
		r.rayo = ahora
		local hacia = r.normal and -r.normal or Vector3.new(r.mira.X - hombroM.X, 0, r.mira.Z - hombroM.Z)
		if hacia.Magnitude < 1e-3 then
			hacia = raiz.RightVector * lado
		end
		r.punta = nil
		local choque = workspace:Raycast(hombroM, hacia.Unit * G.Largo, filtroSuceso)
		local nn = choque and Vector3.new(choque.Normal.X, 0, choque.Normal.Z)
		if choque and nn and nn.Magnitude > 0.5 then
			nn = nn.Unit
			r.normal = nn
			local d = (hombroM - choque.Position):Dot(nn)
			local atras = perpendicular(-raiz.LookVector, nn)
			local punta = hombroM - nn * (d - G.Pared) + atras * G.Atras - Vector3.yAxis * G.Bajo
			if not workspace:Raycast(hombroM, punta - hombroM, filtroSuceso) then
				r.punta = choque.Position + nn * G.Pared -- (un punto del plano de la pared, ya con su holgura)
			end
		end
	end
	local toca = r.activo and r.punta ~= nil and r.normal ~= nil
	r.contacto = acercar(r.contacto, if toca then 1 else 0, dt, 8)
	local normal, enPlano = r.normal, r.punta
	if normal and enPlano and r.contacto > 1e-3 then
		-- La punta, cada fotograma desde el hombro de ahora (sigue andando): en el plano, detrás y abajo.
		local d = (hombroM - enPlano):Dot(normal)
		local atras = perpendicular(-raiz.LookVector, normal)
		local punta = hombroM - normal * d + atras * G.Atras - Vector3.yAxis * G.Bajo
		local n = raiz:VectorToObjectSpace(normal)
		alcanzar(b, lado, raiz:PointToObjectSpace(punta), n * 0.7 + Vector3.yAxis * 0.3 + Vector3.zAxis * 0.4, w * r.contacto,
			{ p = raiz:PointToObjectSpace(enPlano), n = n })
		-- El arañazo, en bucle donde están las garras: más fuerte andando.
		if not r.punto then
			local nombre = if Sonido.hay("UnasPared") then "UnasPared" else "Raspado"
			local punto = Instance.new("Attachment")
			punto.Name = "GarrasGolpeador"
			punto.Parent = workspace.Terrain
			local s = Sonido.bucle(nombre, punto)
			s.RollOffMode = Enum.RollOffMode.InverseTapered
			s.RollOffMinDistance = 6
			s.RollOffMaxDistance = Config.Sonidos[nombre].Alcance or 45
			s:SetAttribute("Base", s.Volume * (if nombre == "Raspado" then 0.35 else 1)) -- el Raspado, bajito
			s.Volume = 0
			r.punto, r.sonido = punto, s
		end
		local v = b.raiz.AssemblyLinearVelocity
		local s = r.sonido :: Sound
		;(r.punto :: Attachment).WorldPosition = punta
		s.Volume = (s:GetAttribute("Base") or 0.5) * r.contacto * math.clamp(Vector3.new(v.X, 0, v.Z).Magnitude / 4, 0.35, 1)
	elseif r.sonido then
		r.sonido.Volume = 0
	end
	if normal and enPlano then
		table.insert(b.planos, { p = raiz:PointToObjectSpace(enPlano - normal * G.Pared), n = raiz:VectorToObjectSpace(normal) })
	end
end

-- El orden en que se ponen (Aparta, la última: sale de la Cara y manda sobre ella).
local ORDEN = { "Armario", "Olfatea", "Llama", "Cara", "Finge", "Garras", "Quieto", "Aparta" }

local function acabarSuceso(r: Suceso)
	if r.punto then
		r.punto:Destroy()
		r.punto, r.sonido = nil, nil
	end
end

local function olvidarSucesos(b: Bicho)
	for _, r in b.sucesos do
		acabarSuceso(r)
	end
	table.clear(b.sucesos)
	b.agacha = 0
end

-- Los sucesos del modelo, encima de la pose de siempre (que ya está en las juntas este fotograma).
local function sucesos(b: Bicho, dt: number, ahora: number, fino: boolean)
	local modelo = b.modelo
	local nombre = modelo:GetAttribute("Suceso")
	local lista = b.sucesos
	if typeof(nombre) ~= "string" or not POSES[nombre] then
		nombre = nil
	end
	b.agacha = 0
	table.clear(b.planos)
	if nombre == nil and next(lista) == nil then
		return
	end
	if nombre then
		local hora = modelo:GetAttribute("SucesoHora")
		hora = if typeof(hora) == "number" then hora else 0
		local r = lista[nombre]
		if not r or r.hora ~= hora then
			local lado = modelo:GetAttribute("SucesoLado")
			local nuevo: Suceso = {
				nombre = nombre, hora = hora, mira = b.cabeza.Position, lado = if typeof(lado) == "number" then lado else 0,
				w = if r then r.w else 0, activo = true, manos = {}, proximo = ahora + 0.3, golpe = -math.huge, tanda = 0,
				ladeo = LADEO, ladeoMeta = LADEO, normal = nil, punta = nil, contacto = 0, rayo = -math.huge,
				sonido = nil, punto = nil,
			}
			if r then
				acabarSuceso(r)
			end
			lista[nombre] = nuevo
			filtrarSucesos()
		end
		local mira = modelo:GetAttribute("SucesoMira")
		if typeof(mira) == "Vector3" then
			lista[nombre].mira = mira
		end
	end
	for _, n in ORDEN do
		local r = lista[n]
		if not r then
			continue
		end
		r.activo = n == nombre
		local rapidez = if n == "Aparta" then SUCESO.Rapido
			elseif not r.activo then SUCESO.Sale
			elseif n == "Finge" then SUCESO.Despacio
			else SUCESO.Entra
		r.w = if r.activo then math.min(1, r.w + dt * rapidez) else math.max(0, r.w - dt * rapidez)
		if r.w <= 0 and not r.activo then
			acabarSuceso(r)
			lista[n] = nil
			continue
		end
		POSES[n](b, r, suave(r.w), dt, ahora, fino)
	end
end

-- Un toque del dedo en el cristal (Llama; remote Golpeador "Toque", justo cuando toca): en el bicho que llama a `el`
-- (la ventana o la puerta), el dedo se pega al cristal y suena el toque.
local function toque(bichos: { [Model]: Bicho }, el: Instance?)
	local donde = nil
	if typeof(el) == "Instance" then
		local centro = el:GetAttribute("Centro")
		if typeof(centro) == "CFrame" then
			donde = centro.Position
		elseif el:IsA("BasePart") then
			donde = el.Position
		elseif el:IsA("Model") then
			donde = el:GetPivot().Position
		end
	end
	local suyo, distancia = nil, 15
	for _, b in bichos do
		local r = b.sucesos.Llama
		if r and r.activo then
			local d = if donde then (r.mira - donde).Magnitude else 0
			if d < distancia then
				suyo, distancia = r, d
			end
		end
	end
	local punto = if suyo then suyo.mira + Vector3.new(0, SUCESO.Llama.Alto, 0) else donde
	if suyo then
		suyo.golpe = os.clock()
	end
	if not punto then
		return
	end
	if Sonido.hay("ToqueDedo") then
		Sonido.en("ToqueDedo", punto)
	else
		-- Mientras falta: el tic del reloj, más grave y fuerte, suena a una uña contra el cristal.
		local s = Sonido.en("Tic", punto, 0.8)
		s.Volume *= 2
		s.RollOffMaxDistance = Config.Sonidos.ToqueDedo.Alcance or 60
	end
end

Sucesos.SUCESO = SUCESO
Sucesos.poner, Sucesos.olvidar, Sucesos.toque = sucesos, olvidarSucesos, toque

return Sucesos
