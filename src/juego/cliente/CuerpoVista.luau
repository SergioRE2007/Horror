-- Que la cámara se sienta un cuerpo (pedido por el usuario: "que todo esté animado y sea inmersivo"). Solo en primera
-- persona, con la cámara normal (nunca en cinemáticas, escondido, muerto ni con la mochila abierta):
--   Al andar, la cabeza sube y baja con cada paso (la misma zancada que los sonidos de Pasos) y se mece un poco de lado;
--   corriendo deprisa, más. Quieto, respira.
--   Al moverte de lado, se inclina un poco hacia ese lado.
--   Al caer de una altura, la cabeza baja de golpe y vuelve.
--   Con un bicho cerca, respira más rápido y más hondo (el miedo).
--   De noche y fuera de la casa, se ve el vaho al respirar (sin él con Rendimiento).
--   Manda al servidor cuánto miras arriba o abajo (remote Mirada) para que los demás lo vean (BrazosVista).
--   Agachado (PosturaVista, 14.6), la vista baja suave Config.Postura.Baja; al bajar, las rodillas dan un golpecito
--   (sin él con Rendimiento). Asomado, va de lado Config.Postura.Asomar y se ladea Config.Postura.Giro grados, sin
--   meterse en las paredes (rayos hacia ese lado desde la cabeza y desde la cámara, que va ATRAS detrás: si chocan, se
--   queda HOLGURA antes). Mirando por la mirilla (atributo local Mirilla), derecho y de pie. Agachado se sigue con la
--   mochila abierta (la vista no salta al abrirla) y el ladeo vuelve suave; escondido, muerto o en una cinemática la
--   cámara no es de Roblox y no se nota (al volver, el ladeo entra suave).
--   Esconderse agachado (pedido por el usuario: "debajo de mesas"): agachado el cuerpo baja de verdad (PosturaVista
--   baja el HipHeight) y la vista baja eso de menos, así que queda a la misma altura que antes. Debajo de algo (un
--   tablero) baja más: nunca se mete dentro (rayos hacia arriba donde está la cabeza y donde va la cámara) y andando
--   hacia ello empieza a bajar ANTICIPA s antes de llegar. Sin sitio para levantarte, sigue abajo (PosturaVista.bajo)
--   y, al intentarlo, la cabeza da un respingo contra lo de arriba (PosturaVista.tope).
--   Correr (14.8, pedido por el usuario: "todo animado e inmersivo"), mezclado con CorrerVista.ritmo() para que no
--   salte: la cabeza sube y baja más, más seguido (zancada ZANCADA_CORRE, como Pasos) y cabecea en cada pisada, y el
--   campo de visión se abre CAMPO grados. Al frenar en seco (venías corriendo y la velocidad cae de golpe: soltar, una
--   pared, agotarte), la cabeza sigue un poco hacia delante y vuelve. Cansado (CorrerVista.cansancio), respira más
--   deprisa y más hondo, y de noche fuera echa más vaho. Al tropezar (CorrerVista.tropiezo), la vista cae hacia delante
--   y de lado, baja un poco y se recupera en TROPIEZO_VUELVE s, sin meterse en el suelo, paredes ni muebles (rayos con
--   MuebleRayo). Con Rendimiento, sin campo de visión, sin balanceo de más ni sacudida al frenar; el tropiezo sí, más
--   corto. Las cuentas, en funciones sueltas sin Roblox (CuerpoVista.balanceo, campo, tropiezo, frenazo, respiracion)
--   para probarlas con Lune.
--   El campo de visión se suma igual que el giro: se quita en Camera - 1 si sigue como lo dejamos (si otro lo ha
--   cambiado, se deja). Al empezar un vistazo (atributo Vistazo), MirarVista apunta el de antes con lo nuestro dentro
--   y al acabar lo devuelve: eso se quita una vez al volver (`deuda`) para que no se quede abierto.
-- Con lo pesado en las manos el balanceo lo pone CargarVista: aquí no se suma.
-- Se pinta encima de la cámara de Roblox (BindToRenderStep, Camera + 1): solo mueve la posición y la inclina de lado.
-- Lo sumado se quita antes del fotograma siguiente (Camera - 1), girando en el espacio del mundo: los temblores de
-- otros módulos (CasaVista, BestiaVista, la reja, MochilaUi...) giran en Camera + 1 y se deshacen en Camera - 1, y
-- según quién corriera antes su deshacer y el nuestro se mezclaban y la mirada se iba desviando (comprobado con Lune:
-- así sale bien en cualquier orden).
-- Agacharse y asomarse van ANTES de la cámara de Roblox (Camera - 1), en el CameraOffset del Humanoid: así la cámara ya
-- sale de ahí y lo que va colgado de ella (manos, linterna, la mochila abierta, la entrada al escondite) lo ve igual,
-- haya corrido antes quien haya corrido. Con algo pesado el CameraOffset es de CargarVista (y la postura ya está
-- quitada): entonces no se toca.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CorrerVista = require(script.Parent.CorrerVista)
local MuebleRayo = require(script.Parent.MuebleRayo)
local PosturaVista = require(script.Parent.PosturaVista)

local CuerpoVista = {}

local jugador = Players.LocalPlayer
local camara = workspace.CurrentCamera
local ZANCADA = 7 -- studs entre paso y paso (como Pasos)
local SUBE = 0.07 -- studs que sube y baja la cabeza al andar a 16
local LADO = 0.045
local MECE = math.rad(0.5) -- inclinación al andar
local INCLINA = math.rad(1.4) -- de lado, al moverte a 16 hacia un lado
local CAIDA = 0.45 -- studs que baja la cabeza al caer de alto
local MIEDO = 30 -- studs: con un bicho más cerca, respira con miedo
local P = Config.Postura
local SUAVE_POSTURA = 9 -- lo deprisa que baja o sube la vista al agacharte y al asomarte
local VUELVE_LADEO = 3 -- por segundo: lo que tarda el ladeo en volver tras una cinemática o un vistazo (1/3 s)
local HOLGURA = 0.3 -- studs que se queda la cámara antes de una pared al asomarte
local ATRAS = 0.5 -- studs que pone la cámara de Roblox los ojos detrás de la cabeza en primera persona
local RODILLAS = 2.5 -- golpecito al agacharte (velocidad que se suma al muelle de la caída; al levantarte, menos)
local CERCA_TECHO = 0.15 -- studs que se queda la cámara por debajo de lo de arriba (un tablero), además de ATRAS
local ANTICIPA = 0.3 -- s: andando agachado se mira lo de arriba donde estarás, para ir bajando la vista antes
local TOPE = 1.6 -- respingo hacia arriba al darte con lo de arriba queriendo levantarte (como RODILLAS)
-- Correr (14.8). Números a ojo (para mirarlos en Studio).
local ZANCADA_CORRE = 6.2 -- studs entre paso y paso corriendo (como Pasos): pasos más seguidos
local CORRE_SUBE = 0.9 -- corriendo, el sube y baja de la cabeza va por (1 + esto)...
local CORRE_LADO = 0.6 -- ...el vaivén de lado...
local CORRE_MECE = 1.2 -- ...y la inclinación de lado
local CORRE_CABECEA = math.rad(0.8) -- y en cada pisada la cabeza cabecea esto hacia abajo
local CAMPO = 7 -- grados de más de campo de visión corriendo deprisa
local CAMPO_PLENO = 20 -- studs/s a los que se abre del todo (corriendo de verdad: 24)
local SUAVE_CAMPO = 5 -- por segundo: lo deprisa que se abre y se cierra
local FRENAZO_DESDE = 9 -- studs/s que tiene que caer la velocidad de golpe para sacudir (de correr a andar: 8, no)
local FRENAZO_PLENO = 20 -- y del todo (de correr a parar en seco: unos 22)
local FRENAZO_GIRO = 1.1 -- rad/s que se suman al cabeceo hacia delante (del todo: unos 2,5 grados)
local FRENAZO_BAJA = 1.5 -- y a la caída (como RODILLAS: unos 0,06 studs)
local FRENAZO_CADA = 0.6 -- s como poco entre dos sacudidas
local RECIEN = 0.35 -- s: venías corriendo si corriste hace menos de esto
local MEDIA = 6 -- por segundo: la velocidad de hace un momento (para ver si cae de golpe)
local CANSADO_RESPIRA = 2.4 -- agotado, el ritmo de la respiración de más (el normal es 1,3 por segundo)
local CANSADO_HONDO = 0.04 -- studs de más que sube y baja al respirar agotado
local CANSADO_CABECEA = math.rad(0.6) -- y lo que cabecea con cada respiración
local CANSADO_VAHO = 1.7 -- s de menos entre vaho y vaho agotado (y VAHO_CANSADO nubecillas de más)
local VAHO_CANSADO = 4
local TROPIEZO_CAE = 0.2 -- s que tarda en caer (cada vez más deprisa)
local TROPIEZO_ABAJO = 0.15 -- s que se queda abajo (con un rebote pequeño)
local TROPIEZO_VUELVE = 1.4 -- s desde que tropieza hasta estar recuperado
local TROPIEZO_VUELVE_REND = 1 -- y con Rendimiento
local TROPIEZO_CABECEO = math.rad(16) -- lo que cae la vista hacia delante
local TROPIEZO_ALABEO = math.rad(7) -- y de lado (a un lado al azar)
local TROPIEZO_BAJA = 0.7 -- studs que baja
local TROPIEZO_DELANTE = 0.3 -- studs que va hacia delante
local SUELO_MIN = 1.2 -- studs que se queda la cámara sobre el suelo, como poco, al tropezar
local CAJAS_RADIO = 6 -- studs alrededor en los que se miran los muebles al tropezar (MuebleRayo.cajas, una vez)

local fase = 0
local fuerza = 0 -- cuánto se nota el andar (sube y baja suave al empezar y al parar)
local inclinado = 0
local caida = 0 -- lo que ha bajado la cabeza al caer (vuelve sola)
local velCaida = 0
local respiracion = 0
local miedo = 0
local bichoCerca = 0 -- se mira cada poco
local proximoVaho = 0
local proximaMirada = 0
local vaho: ParticleEmitter? = nil
local boca: Attachment? = nil
-- Postura (lo que se pone en el CameraOffset; en el espacio de la raíz).
local bajado = 0 -- studs que ha bajado la vista (agachado)
local asomo = 0 -- -1..1: cuánto está asomado (para el ladeo)
local lateral = 0 -- studs de lado ahora mismo (lo que deja la pared)
local aplicado = Vector3.zero -- lo puesto este fotograma
local duenoDe: Humanoid? = nil -- el Humanoid cuyo CameraOffset se lleva aquí (nil con algo pesado: es de CargarVista)
local estabaAgachado = false
local topeVisto = -math.huge -- el último golpe contra lo de arriba ya hecho (PosturaVista.tope)
local pesoLadeo = 1 -- 0..1: cuánto se nota el ladeo (a 0 mientras la cámara es de otro; luego vuelve suave)
local giroAplicado: CFrame? = nil -- lo que `paso` le ha sumado a la cámara este fotograma
local camaraTras: CFrame? = nil -- y cómo quedó la cámara justo después
local filtroDe: Model? = nil -- el personaje que tienen fuera los rayos de `rayo`
-- Correr.
local media = 0 -- la velocidad de hace un momento (suave)
local cabeceo = 0 -- lo que cabecea la cabeza al frenar en seco (vuelve sola, con un muelle como la caída)
local velCabeceo = 0
local ultimoFrenazo = -math.huge
local campoMas = 0 -- grados de más de campo de visión ahora (suave)
local campoSumado = 0 -- lo sumado al FieldOfView este fotograma...
local campoTras: number? = nil -- ...y cómo quedó
local deuda: number? = nil -- lo nuestro que se llevó MirarVista dentro de su campo "de antes" (se quita al volver)
local deudaEn = 0 -- el campo con eso dentro
local tropiezoAntes: number? = nil -- lo que dio CorrerVista.tropiezo() el fotograma anterior (para ver uno nuevo)
local tropiezoLado = 1
local cajasTropiezo: { MuebleRayo.Caja } = {} -- los muebles de alrededor al tropezar
local cajasListas = false -- ya se han mirado para este tropiezo
local azar = Random.new()
local rayo = RaycastParams.new()
rayo.FilterType = Enum.RaycastFilterType.Exclude
rayo.RespectCanCollide = true -- cortinas, hojas y lo que no choca no paran la cabeza

-- Dentro de la casa (como Ambiente: la caja de la casa y por debajo del tejado).
local function enCasa(p: Vector3): boolean
	local c = Config.Casa
	return math.abs(p.X) < c.MedioX and math.abs(p.Z) < c.MedioZ and p.Y < 28
end

-- El vaho: una nubecilla que sale de la boca y se deshace (las partículas se quedan donde salen).
local function echarVaho(cf: CFrame, cantidad: number)
	if not vaho then
		local a = Instance.new("Attachment")
		a.Name = "Vaho"
		a.Parent = workspace.Terrain
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.LightInfluence = 1 -- de noche, apenas: solo se ve con la linterna
		e.Color = ColorSequence.new(Color3.fromRGB(215, 220, 228))
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.82), NumberSequenceKeypoint.new(1, 1) })
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0.7) })
		e.Lifetime = NumberRange.new(1, 1.6)
		e.Speed = NumberRange.new(0.8, 1.4)
		e.SpreadAngle = Vector2.new(18, 18)
		e.Acceleration = Vector3.new(0, 0.6, 0)
		e.Drag = 1.5
		e.Rate = 0
		e.Parent = a
		boca, vaho = a, e
	end
	(boca :: Attachment).WorldCFrame = cf * CFrame.new(0, -0.35, -0.6)
	;(vaho :: ParticleEmitter):Emit(cantidad)
end

-- Cuentas de correr (sin nada de Roblox: para el banco de Lune) -------------------------------------------------------

local function suave01(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Studs entre paso y paso con `ritmo` (CorrerVista.ritmo, 0..1).
function CuerpoVista.zancada(ritmo: number): number
	return ZANCADA + (ZANCADA_CORRE - ZANCADA) * math.clamp(ritmo, 0, 1)
end

-- El andar en `enFase` (pi por paso) con `cuanto` (rapidez / 16, hasta 1,4) y `ritmo` de correr: lo que sube la
-- cabeza, lo que va de lado (studs), lo que se mece de lado y lo que cabecea (radianes; negativo, hacia abajo).
function CuerpoVista.balanceo(enFase: number, cuanto: number, ritmo: number): (number, number, number, number)
	local r = math.clamp(ritmo, 0, 1)
	local s = math.sin(enFase)
	local pisa = math.abs(s)
	local sube = SUBE * cuanto * (1 + CORRE_SUBE * r) * (1 - 2 * pisa)
	local lado = s * LADO * cuanto * (1 + CORRE_LADO * r)
	local mece = s * MECE * cuanto * (1 + CORRE_MECE * r)
	local cabecea = -CORRE_CABECEA * r * math.min(cuanto, 1) * pisa * pisa * pisa
	return sube, lado, mece, cabecea
end

-- Grados de más de campo de visión que tocan con `ritmo` yendo a `rapidez` studs/s (contra una pared, apenas).
function CuerpoVista.campo(ritmo: number, rapidez: number): number
	return CAMPO * suave01(ritmo) * math.clamp(rapidez / CAMPO_PLENO, 0, 1)
end

-- De 0 a 1, lo caído en un tropiezo a los `t` s: cae cada vez más deprisa, rebota un poco abajo y se recupera suave
-- hasta `vuelve` s (0 antes y después).
function CuerpoVista.curvaTropiezo(t: number, vuelve: number?): number
	local fin = math.max(vuelve or TROPIEZO_VUELVE, TROPIEZO_CAE + TROPIEZO_ABAJO + 0.05)
	if t ~= t or t < 0 or t >= fin then
		return 0
	end
	if t < TROPIEZO_CAE then
		local x = t / TROPIEZO_CAE
		return x * x
	end
	local abajo = TROPIEZO_CAE + TROPIEZO_ABAJO
	if t < abajo then
		return 1 - 0.08 * math.sin(math.pi * (t - TROPIEZO_CAE) / TROPIEZO_ABAJO)
	end
	return 1 - suave01((t - abajo) / (fin - abajo))
end

-- El tropiezo a los `t` s: cabeceo (radianes, negativo: hacia abajo), alabeo (radianes, sin el lado), lo que baja y lo
-- que va hacia delante (studs, antes de mirar el suelo y las paredes).
function CuerpoVista.tropiezo(t: number, rendimiento: boolean): (number, number, number, number)
	local f = CuerpoVista.curvaTropiezo(t, if rendimiento then TROPIEZO_VUELVE_REND else TROPIEZO_VUELVE)
	return -TROPIEZO_CABECEO * f, TROPIEZO_ALABEO * f, TROPIEZO_BAJA * f, TROPIEZO_DELANTE * f
end

-- De 0 a 1, la sacudida al frenar: la velocidad ha caído de `antes` (la de hace un momento) a `ahora` de golpe y
-- `venias` corriendo.
function CuerpoVista.frenazo(antes: number, ahora: number, venias: boolean): number
	if not venias then
		return 0
	end
	return math.clamp((antes - ahora - FRENAZO_DESDE) / (FRENAZO_PLENO - FRENAZO_DESDE), 0, 1)
end

-- La respiración con `susto` (el miedo) y `cansancio` (0..1): su ritmo (radianes por segundo), lo que sube y baja (studs) y lo
-- que cabecea con ella (radianes).
function CuerpoVista.respiracion(susto: number, cansancio: number): (number, number, number)
	local c = math.clamp(cansancio, 0, 1)
	return 1.3 + susto * 2.2 + c * CANSADO_RESPIRA, 0.012 + susto * 0.03 + c * CANSADO_HONDO, c * CANSADO_CABECEA
end

-- ---------------------------------------------------------------------------------------------------------------------

local function enJuego(raiz: BasePart): boolean
	if camara.CameraType ~= Enum.CameraType.Custom then
		return false
	end
	if jugador:GetAttribute("Muerto") or jugador:GetAttribute("Escondido") or jugador:GetAttribute("MochilaAbierta") then
		return false
	end
	local cabeza = jugador.Character and jugador.Character:FindFirstChild("Head") :: BasePart?
	-- La cámara está desplazada lo que haya puesto la postura (agachado o asomado): se compara con ese sitio.
	local desvio = raiz.CFrame:VectorToWorldSpace(aplicado)
	return cabeza ~= nil and (camara.CFrame.Position - cabeza.Position - desvio).Magnitude < 2.5
end

-- Lo libre hacia un lado desde `desde`, hasta P.Asomar.
local function libreDesde(desde: Vector3, lado: Vector3): number
	local choque = workspace:Raycast(desde, lado, rayo)
	return if choque then math.max(0, choque.Distance - HOLGURA) else P.Asomar
end

-- Hasta dónde puede ir la cabeza hacia `signo` (1 derecha, -1 izquierda) sin meterse en una pared. `alturaOjo`: donde
-- está ahora la cabeza sobre el centro de la raíz (ya agachado).
local function hueco(raiz: BasePart, signo: number, alturaOjo: number): number
	local ojo = raiz.CFrame:PointToWorldSpace(Vector3.new(0, alturaOjo, 0))
	local lado = raiz.CFrame.RightVector * (signo * (P.Asomar + HOLGURA))
	-- Y desde donde va de verdad la cámara: ATRAS studs detrás, hacia donde miras. Asomándote junto a una esquina que
	-- acaba justo a tu altura, la cabeza ya ha pasado el borde pero la cámara aún no, y se metería en la pared.
	return math.min(libreDesde(ojo, lado), libreDesde(ojo - camara.CFrame.LookVector * ATRAS, lado))
end

-- Lo que hay que bajar la vista (desde los ojos de pie, a la altura `ojoPie`) para no meter la cámara en lo que haya
-- encima del punto (x, z): el tablero de un mueble (sus zonas Debajo, PosturaVista.techoDebajo: lo que choca de los
-- muebles no se ve con rayos) o lo demás (un rayo: el hueco de una escalera, una viga). El rayo sale de la altura de
-- la raíz (`desdeY`), que agachado queda siempre por debajo de lo que tapa (la raíz encogida de PosturaVista choca
-- hasta Config.Postura.Alto y no deja que se meta nada ahí). 0 si no hay nada a esa altura.
local function techoEn(punto: Vector3, desdeY: number, ojoPie: number): number
	local tope = ojoPie + ATRAS + CERCA_TECHO
	if tope <= desdeY then
		return 0
	end
	local desde = Vector3.new(punto.X, desdeY, punto.Z)
	local y = PosturaVista.techoDebajo(desde) or math.huge
	local choque = workspace:Raycast(desde, Vector3.new(0, tope - desdeY, 0), rayo)
	if choque then
		y = math.min(y, choque.Position.Y)
	end
	return if y < tope then tope - y else 0
end

-- Quita lo que `paso` le sumó a la cámara el fotograma anterior (ver la cabecera). Por la izquierda, en el espacio del
-- mundo: tras · giro⁻¹ · tras⁻¹ deshace justo lo nuestro aunque otros hayan girado después o ya se hayan deshecho.
-- En una cinemática no se toca (la cámara la lleva un script).
local function deshacer()
	local giro, tras = giroAplicado, camaraTras
	giroAplicado, camaraTras = nil, nil
	if giro and tras and camara.CameraType == Enum.CameraType.Custom then
		camara.CFrame = tras * giro:Inverse() * tras:Inverse() * camara.CFrame
	end
	-- El campo de visión: solo si sigue como lo dejamos (si otro lo ha cambiado, es suyo).
	local sumado, campoDejado = campoSumado, campoTras
	campoSumado, campoTras = 0, nil
	if campoDejado and math.abs(camara.FieldOfView - campoDejado) < 0.01 then
		camara.FieldOfView -= sumado
	end
	-- Lo nuestro que se llevó un vistazo en su campo "de antes": al volver la cámara, si lo ha dejado tal cual, se quita.
	if deuda and camara.CameraType == Enum.CameraType.Custom and jugador:GetAttribute("Vistazo") == nil then
		if math.abs(camara.FieldOfView - deudaEn) < 0.01 then
			camara.FieldOfView -= deuda
		end
		deuda = nil
	end
end

-- Lo que has metido en la cámara para que no se meta en lo de debajo ni en lo de delante al tropezar: lo que puede
-- bajar y lo que puede ir hacia `delante` (en planta) desde `desde`.
local function limitarTropiezo(desde: Vector3, baja: number, delante: number, frente: Vector3): (number, number)
	if baja > 0 then
		local abajo = MuebleRayo.rayo(desde, Vector3.new(0, -(baja + SUELO_MIN), 0), rayo, cajasTropiezo)
		if abajo then
			baja = math.min(baja, math.max(0, abajo.Distance - SUELO_MIN))
		end
	end
	if delante > 0 and frente.Magnitude > 0.01 then
		local hacia = frente.Unit * (delante + HOLGURA)
		local choque = MuebleRayo.rayo(desde - Vector3.new(0, baja, 0), hacia, rayo, cajasTropiezo)
		if choque then
			delante = math.min(delante, math.max(0, choque.Distance - HOLGURA))
		end
	end
	return baja, delante
end

local function filtrar(personaje: Model)
	if filtroDe ~= personaje then
		filtroDe = personaje -- los rayos no ven tu cuerpo ni lo que cuelga de la cámara (sin una tabla por fotograma)
		rayo.FilterDescendantsInstances = { personaje, camara }
	end
end

-- Le suma `giro` a la cámara (por la derecha, en su espacio) y lo apunta para deshacerlo.
local function aplicar(giro: CFrame)
	camara.CFrame *= giro
	giroAplicado, camaraTras = giro, camara.CFrame
end

-- Antes de la cámara de Roblox: agacharse y asomarse en el CameraOffset (ver la cabecera).
local function postura(dt: number)
	deshacer()
	aplicado = Vector3.zero
	local personaje = jugador.Character
	local hum = personaje and personaje:FindFirstChildOfClass("Humanoid")
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not personaje or not hum or not raiz or jugador:GetAttribute("Cargando") then
		duenoDe = nil -- con lo pesado lo lleva CargarVista
		asomo = if math.abs(asomo) < 1e-3 then 0 else asomo * math.exp(-dt * SUAVE_POSTURA) -- el ladeo vuelve igual
		return
	end
	-- Lo que ha bajado el cuerpo de verdad (el HipHeight, PosturaVista): la cámara baja eso de menos.
	local cuerpoBaja = PosturaVista.cuerpo()
	if duenoDe ~= hum then
		-- Vuelve aquí (al soltar lo pesado, o un personaje nuevo): desde donde lo dejó CargarVista, sin saltos.
		duenoDe = hum
		bajado, lateral, asomo = math.max(0, cuerpoBaja - hum.CameraOffset.Y), hum.CameraOffset.X, 0
	end
	local muerto = hum.Health <= 0 or jugador:GetAttribute("Muerto") == true
	local derecho = muerto or jugador:GetAttribute("Mirilla") == true -- por la mirilla, de pie y sin asomarse
	local abajo = PosturaVista.bajo() -- agachado, o sin sitio para levantarte
	local metaBaja = if abajo and not derecho then P.Baja else 0
	local metaAsomo = if derecho then 0 else PosturaVista.asomado()
	local k = if muerto then 1 else 1 - math.exp(-dt * SUAVE_POSTURA)
	local cabezaRaiz = 1.5 + (raiz.Size.Y - 2) / 2 -- donde pone la cámara de Roblox la cabeza sobre la raíz
	filtrar(personaje)
	-- Agachado, lo de arriba (debajo de una mesa la vista va más baja): hacia donde vas, para ir bajando antes de llegar.
	local mirarTecho = (abajo or cuerpoBaja > 0.01) and not muerto
	local ojoPie = raiz.Position.Y + cuerpoBaja + cabezaRaiz -- donde tendrías los ojos de pie
	if mirarTecho then
		local v = raiz.AssemblyLinearVelocity
		metaBaja = math.max(metaBaja, techoEn(raiz.Position + Vector3.new(v.X, 0, v.Z) * ANTICIPA, raiz.Position.Y, ojoPie))
	end
	bajado += (metaBaja - bajado) * k
	asomo += (metaAsomo - asomo) * k
	-- De lado: lo que deja la pared de cada lado por el que va o va a ir (hacia la pared, al momento: nunca dentro).
	local metaLado = metaAsomo * P.Asomar
	local alturaOjo = cabezaRaiz + cuerpoBaja - bajado
	local der = if lateral > 0.01 or metaLado > 0 then hueco(raiz, 1, alturaOjo) else P.Asomar
	local izq = if lateral < -0.01 or metaLado < 0 then hueco(raiz, -1, alturaOjo) else P.Asomar
	lateral += (math.clamp(metaLado, -izq, der) - lateral) * k
	lateral = math.clamp(lateral, -izq, der)
	if mirarTecho then
		-- Y nunca dentro de lo de arriba: donde está la cabeza y donde va la cámara (ATRAS detrás), al momento.
		local foco = raiz.CFrame:PointToWorldSpace(Vector3.new(lateral, 0, 0))
		bajado = math.max(bajado, techoEn(foco, raiz.Position.Y, ojoPie),
			techoEn(foco - camara.CFrame.LookVector * ATRAS, raiz.Position.Y, ojoPie))
	end
	if bajado < 1e-3 then
		bajado = 0
	end
	if math.abs(lateral) < 1e-3 then
		lateral = 0
	end
	if math.abs(asomo) < 1e-3 then
		asomo = 0
	end
	aplicado = Vector3.new(lateral, cuerpoBaja - bajado, 0)
	if hum.CameraOffset ~= aplicado then
		hum.CameraOffset = aplicado
	end
end

local function distanciaBicho(desde: Vector3): number
	local carpeta = workspace:FindFirstChild("Bichos")
	local mejor = math.huge
	for _, bicho in (if carpeta then carpeta:GetChildren() else {}) do
		local raiz = bicho:FindFirstChild("HumanoidRootPart")
		if raiz and raiz:IsA("BasePart") then
			mejor = math.min(mejor, (raiz.Position - desde).Magnitude)
		end
	end
	return mejor
end

local function paso(dt: number)
	local personaje = jugador.Character
	local hum = personaje and personaje:FindFirstChildOfClass("Humanoid")
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
	local agachado = PosturaVista.agachado()
	local cambioPostura = agachado ~= estabaAgachado
	estabaAgachado = agachado
	-- Un tropiezo nuevo (aunque ahora no se vea: así no se pinta a medias al volver).
	local tropezando = CorrerVista.tropiezo()
	local tropiezoNuevo = tropezando ~= nil and (tropiezoAntes == nil or tropezando < tropiezoAntes)
	tropiezoAntes = tropezando
	if tropiezoNuevo then
		tropiezoLado = if azar:NextNumber() < 0.5 then -1 else 1
		cajasListas = false
	end
	-- Asomado, la cabeza se ladea hacia ese lado (a la derecha, lo de arriba de la imagen va a la derecha). Solo con la
	-- cámara de Roblox; si ha sido de otro un rato (una cinemática, un vistazo, el escondite), vuelve suave sin saltar.
	pesoLadeo = if camara.CameraType == Enum.CameraType.Custom then math.min(1, pesoLadeo + dt * VUELVE_LADEO) else 0
	local ladeo = -asomo * math.rad(P.Giro) * pesoLadeo * pesoLadeo * (3 - 2 * pesoLadeo)
	if not personaje or not hum or not raiz or not enJuego(raiz) then
		fuerza, inclinado, caida, velCaida = 0, 0, 0, 0
		cabeceo, velCabeceo, campoMas, media = 0, 0, 0, 0
		-- El ladeo vuelve suave aunque ahora no toque balancear (al abrir la mochila asomándote, p. ej.).
		if hum and ladeo ~= 0 and not jugador:GetAttribute("Escondido") then
			aplicar(CFrame.Angles(0, 0, ladeo))
		end
		return
	end
	local rendimiento = jugador:GetAttribute("Rendimiento") == true
	-- Al agacharte, las rodillas: la cabeza baja un poco de más y vuelve (con el muelle de la caída).
	if cambioPostura and not rendimiento then
		velCaida += if agachado then -RODILLAS else RODILLAS * 0.4
	end
	-- Queriendo levantarte debajo de algo: la cabeza da contra ello (un respingo hacia arriba que vuelve). Con
	-- Rendimiento también: es lo que te dice que no cabes.
	local tope = PosturaVista.tope()
	if tope ~= topeVisto then
		topeVisto = tope
		velCaida += TOPE
	end
	local cf = camara.CFrame
	local v = raiz.AssemblyLinearVelocity
	local plano = Vector3.new(v.X, 0, v.Z)
	local rapidez = plano.Magnitude
	local enSuelo = hum.FloorMaterial ~= Enum.Material.Air
	local cargando = jugador:GetAttribute("Cargando") ~= nil
	-- Corriendo: con Rendimiento, sin balanceo de más ni campo de visión.
	local ritmo = if rendimiento then 0 else CorrerVista.ritmo()

	-- Andar: una bajada por paso (más seguidas corriendo).
	local andando = enSuelo and rapidez > 1 and not cargando
	fuerza += ((if andando then math.clamp(rapidez / 16, 0, 1.4) else 0) - fuerza) * (1 - math.exp(-dt * 6))
	if andando then
		fase += rapidez * dt / CuerpoVista.zancada(CorrerVista.ritmo()) * math.pi
	end
	local sube, lado, mece, cabecea = CuerpoVista.balanceo(fase, fuerza, ritmo)

	-- De lado: se inclina hacia donde va.
	local deLado = plano:Dot(cf.RightVector)
	inclinado += (-deLado / 16 * INCLINA - inclinado) * (1 - math.exp(-dt * 5))

	-- Frenar en seco tras correr: la cabeza sigue un poco hacia delante y vuelve.
	local venias = CorrerVista.corriendo() or CorrerVista.recien() < RECIEN
	local frena = CuerpoVista.frenazo(media, rapidez, venias)
	media += (rapidez - media) * (1 - math.exp(-dt * MEDIA))
	if frena > 0 and not rendimiento and enSuelo and os.clock() - ultimoFrenazo >= FRENAZO_CADA then
		ultimoFrenazo = os.clock()
		velCabeceo -= FRENAZO_GIRO * frena
		velCaida -= FRENAZO_BAJA * frena
	end

	-- Caer: la cabeza baja de golpe y vuelve con un muelle (y el cabeceo del frenazo, igual). A pasitos de 1/60 s como
	-- mucho: con fotogramas largos (un móvil lento, un tirón al aterrizar) el muelle se disparaba y la cámara salía volando.
	local pasos = math.clamp(math.ceil(dt * 60), 1, 15)
	local h = math.min(dt, 0.25) / pasos
	for _ = 1, pasos do
		velCaida += (-caida * 120 - velCaida * 16) * h
		caida += velCaida * h
		velCabeceo += (-cabeceo * 120 - velCabeceo * 16) * h
		cabeceo += velCabeceo * h
	end
	if caida ~= caida or velCaida ~= velCaida then
		caida, velCaida = 0, 0 -- por si acaso (NaN): que no se rompa la cámara
	end
	if cabeceo ~= cabeceo or velCabeceo ~= velCabeceo then
		cabeceo, velCabeceo = 0, 0
	end

	-- Respirar, con miedo si hay un bicho cerca y más hondo cuanto más cansado.
	bichoCerca -= dt
	if bichoCerca <= 0 then
		bichoCerca = 0.4
		local d = distanciaBicho(raiz.Position)
		miedo = math.clamp(1 - (d - 8) / (MIEDO - 8), 0, 1)
	end
	local cansancio = CorrerVista.cansancio()
	local deprisa, hondo, respiraCabecea = CuerpoVista.respiracion(miedo, cansancio)
	respiracion += dt * deprisa
	local respira = math.sin(respiracion) * hondo
	local respiraGiro = math.sin(respiracion) * respiraCabecea

	-- Tropezar: la vista cae hacia delante y de lado, y baja (sin meterse en el suelo ni en lo de delante).
	local trCabeceo, trAlabeo, trBaja, trDelante = 0, 0, 0, 0
	if tropezando then
		filtrar(personaje)
		if not cajasListas then
			cajasListas = true
			cajasTropiezo = MuebleRayo.cajas(raiz.Position, CAJAS_RADIO) -- una vez por tropiezo
		end
		trCabeceo, trAlabeo, trBaja, trDelante = CuerpoVista.tropiezo(tropezando, rendimiento)
		local frente = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
		trBaja, trDelante = limitarTropiezo(cf.Position, trBaja, trDelante, frente)
		trAlabeo *= tropiezoLado
		if frente.Magnitude > 0.01 then
			frente = frente.Unit
		end
		local mueve = cf:VectorToObjectSpace(Vector3.new(0, -trBaja, 0) + frente * trDelante)
		sube += mueve.Y
		lado += mueve.X
		trDelante = mueve.Z -- (ya en el espacio de la cámara)
	elseif #cajasTropiezo > 0 then
		cajasTropiezo = {}
	end

	aplicar(CFrame.new(lado, sube + respira + caida, if tropezando then trDelante else 0)
		* CFrame.Angles(cabecea + cabeceo + respiraGiro + trCabeceo, 0, mece + inclinado + ladeo + trAlabeo))

	-- El campo de visión, abierto corriendo deprisa (se quita en `deshacer`).
	local metaCampo = if rendimiento then 0 else CuerpoVista.campo(ritmo, rapidez)
	campoMas += (metaCampo - campoMas) * (1 - math.exp(-dt * SUAVE_CAMPO))
	if campoMas < 0.01 and metaCampo == 0 then
		campoMas = 0
	end
	if campoMas > 0 then
		camara.FieldOfView += campoMas
		campoSumado, campoTras = campoMas, camara.FieldOfView
	end

	-- Hacia dónde miras, para que los demás vean tu cabeza y tu linterna (BrazosVista), cada 0,2 s si ha cambiado.
	-- Se compara con lo que ha publicado el servidor (atributo Mirada, entre -1,4 y 1,4 y redondeado a 0,05), no con lo
	-- último mandado: si tiró un envío (dos llegaron muy seguidos), se vuelve a mandar hasta que se publique y la de
	-- antes no se queda atascada.
	if os.clock() >= proximaMirada then
		proximaMirada = os.clock() + 0.2
		local inclinacion = math.asin(math.clamp(cf.LookVector.Y, -1, 1))
		local publicada = jugador:GetAttribute("Mirada")
		local dicha = if type(publicada) == "number" then publicada else 0
		if math.abs(math.clamp(inclinacion, -1.4, 1.4) - dicha) >= 0.05 then
			Remotes.Mirada:FireServer(inclinacion)
		end
	end

	-- Vaho de noche fuera de casa, al soltar el aire (más seguido con miedo o cansado, y más cansado).
	local ahora = os.clock()
	if ahora >= proximoVaho then
		proximoVaho = ahora + math.max(1, 3.2 - miedo * 1.6 - cansancio * CANSADO_VAHO)
		if workspace:GetAttribute("Fase") == "Noche" and not enCasa(cf.Position) and not rendimiento then
			echarVaho(camara.CFrame, 5 + math.floor(cansancio * VAHO_CANSADO + 0.5))
		end
	end
end

function CuerpoVista.start()
	local function conPersonaje(personaje: Model)
		local hum = personaje:WaitForChild("Humanoid", 10) :: Humanoid?
		if not hum then
			return
		end
		local altura: number? = nil -- desde dónde empezó a caer
		hum.StateChanged:Connect(function(_, nuevo)
			local raiz = personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not raiz then
				return
			end
			if nuevo == Enum.HumanoidStateType.Freefall then
				altura = raiz.Position.Y
			elseif nuevo == Enum.HumanoidStateType.Landed and altura then
				local cayo = altura - raiz.Position.Y
				altura = nil
				if cayo > 2.5 then
					velCaida -= math.clamp(cayo / 10, 0.3, 1) * CAIDA * 14
				end
			end
		end)
	end
	jugador.CharacterAdded:Connect(conPersonaje)
	if jugador.Character then
		task.spawn(conPersonaje, jugador.Character)
	end
	-- Un vistazo apunta el campo de visión de antes (con lo nuestro dentro) para devolverlo al acabar: ver `deshacer`.
	jugador:GetAttributeChangedSignal("Vistazo"):Connect(function()
		if jugador:GetAttribute("Vistazo") ~= nil and campoTras and math.abs(camara.FieldOfView - campoTras) < 0.01 then
			deuda, deudaEn = campoSumado, campoTras
		end
	end)
	RunService:BindToRenderStep("CuerpoPostura", Enum.RenderPriority.Camera.Value - 1, postura)
	RunService:BindToRenderStep("Cuerpo", Enum.RenderPriority.Camera.Value + 1, paso)
end

return CuerpoVista
