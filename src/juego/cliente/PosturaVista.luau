-- Agacharse y asomarse (14.6, pedido por el usuario: "cuerpo: agacharse (botón también en el móvil) y asomarse por las
-- esquinas"). Aquí, cuerpo y cámara; los bichos lo saben por el servidor (atributos Agachado y Cubierto, Postura).
--   Agacharse: C o Ctrl izquierdo (alterna), B en el mando y el botón AGACHARSE en el móvil (Hud.EquipoBotones,
--   LayoutOrder 6), que se enciende mientras estás agachado. Saltar levanta (y subir por una escalera o sentarse).
--   Asomarse: mantener Z (izquierda) o X (derecha), solo con teclado. Con la mochila abierta, no. Mirando por la
--   mirilla o entre las cortinas (atributo local Vistazo, de MirarVista) se queda como estaba hasta acabar: si cambiara,
--   MirarVista cortaría el vistazo. En una cinemática no se empieza ni lo uno ni lo otro.
--   Respuesta al momento: se predice con las mismas reglas que el servidor (shared/PosturaReglas) y se le manda (remote
--   Postura). Si el servidor no lo publica (lo ha tirado por llegar muy seguido) se le vuelve a mandar; si no lo
--   quiere, o lo quita él (atributos Agachado y Asomado a nil), te pones de pie.
--   CuerpoVista mueve tu cámara con PosturaVista.agachado() y PosturaVista.asomado(); a los demás los pinta BrazosVista.
--   Pedir correr agachado te levanta si cabes (CorrerVista llama a PosturaVista.levantarse(), 14.8).
--   Al agacharte, al levantarte y al empezar a asomarte, un roce flojo de los pies en el suelo (el sonido de los pasos
--   de ese suelo), solo para ti.
-- El cuerpo agachado (R15; pedido por el usuario, 03-11-2026: "agacharte también debería servir para esconderte, por
-- ejemplo debajo de mesas... que sea útil agacharte es la finalidad"):
--   Agachado, de tu cuerpo solo choca la raíz (HumanoidRootPart), encogida: va de PASO_LIBRE a Config.Postura.Alto
--   studs del suelo, así que cabes bajo un tablero algo más alto y entras andando agachado. Lo demás pasa al grupo de
--   colisión GRUPO (no choca con nada; lo registra el servidor en Postura). La raíz se queda en su grupo: el sensor de
--   suelo del Humanoid usa el grupo de la raíz, y en GRUPO no vería el suelo (caería sobre lo que chocara y andaría
--   en Freefall). Por si la raíz no chocara (CanCollide lo lleva el Humanoid), una banda invisible soldada con su misma
--   caja. Por debajo de PASO_LIBRE no choca nada, así que los peldaños de 1 se siguen subiendo agachado. El HipHeight
--   baja a PASO_LIBRE y la raíz encoge a la vez: los demás te ven más bajo (BrazosVista dobla las piernas lo que de
--   verdad ha bajado). Lo lleva este cliente, que es el dueño de la física de su personaje (nada de esto se replica).
--   Para levantarte (C otra vez, saltar, una escalera, sentarte) tienes que caber de pie (una caja hacia arriba desde
--   la raíz hasta la coronilla de pie): si no, sigues agachado y sin poder saltar, con un golpecito contra lo de arriba
--   (Cruje flojo y la cámara da un respingo, en CuerpoVista). Si el servidor te quita Agachado estando debajo, el cuerpo
--   (y la cámara) siguen abajo hasta que quepas. Muerto o escondido, todo vuelve a su sitio al momento.
--   CuerpoVista lleva la cámara con PosturaVista.bajo() y PosturaVista.cuerpo() (lo que ha bajado el cuerpo).
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local PosturaReglas = require(ReplicatedStorage.Shared.PosturaReglas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sonido = require(script.Parent.Sonido)
local Ui = require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))

local PosturaVista = {}

local ESPERA = 0.45 -- s que se espera a que el servidor lo publique antes de mandarlo otra vez
local INTENTOS = 3 -- veces que se pide agacharse o asomarse antes de dejarlo (ponerse de pie se pide hasta que llegue)
local RECIENTE = 0.9 -- s tras mandar algo en los que un cambio del servidor puede ser el eco de lo que pediste antes
local RUIDO = 0.45 -- volumen (sobre el de los pasos) del roce de los pies al agacharte o levantarte
local RUIDO_ASOMAR = 0.25 -- y al empezar a asomarte (el peso pasa a un pie)
local SUELO: { [Enum.Material]: string } = { -- como en Pasos
	[Enum.Material.Wood] = "PasoMadera",
	[Enum.Material.WoodPlanks] = "PasoMadera",
	[Enum.Material.Grass] = "PasoHierba",
	[Enum.Material.LeafyGrass] = "PasoHierba",
}
local QUE = { "Agachado", "Asomar" }
-- El cuerpo agachado (ver la cabecera).
local GRUPO = "Agachado" -- grupo de colisión que no choca con nada (lo registra el servidor, Postura)
local PASO_LIBRE = 1.1 -- studs del suelo hasta donde empieza lo que choca (la raíz): lo de debajo se sube andando
local CUERPO_VEL = 4 -- studs por segundo que baja o sube el cuerpo (HipHeight) al agacharte o levantarte
local MIRAR_ARRIBA = 0.1 -- s que vale lo mirado hacia arriba (si cabes de pie)
local ALERO = 0.4 -- studs de más alrededor de una zona Debajo cuyo mueble no tiene medidas (atributo Tam)
local ESQUINAS = { { 0, 0 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } } -- de la planta de la raíz, al mirar si cabes
local HOLGURA_PIE = 0.1 -- studs de más sobre la coronilla al mirar si cabes de pie
local TOPE_CADA = 0.6 -- s como poco entre dos golpecitos contra lo de arriba
local TOPE_VOLUMEN = 0.3 -- del Cruje al darte con lo de arriba (sobre el suyo)

type Valor = boolean | number
type Pendiente = { valor: Valor, hora: number, intentos: number }
type Cuerpo = {
	personaje: Model,
	hum: Humanoid,
	raiz: BasePart,
	pie: number, -- HipHeight de pie (el del servidor)
	bajo: number, -- HipHeight agachado
	puesto: number, -- el HipHeight puesto ahora (va de uno a otro a CUERPO_VEL)
	abajo: boolean, -- con el cuerpo de agachado puesto (grupos, raíz encogida y banda)
	alto: number, -- Size.Y de la raíz de pie
	altoBajo: number, -- y agachado (de bajo a Config.Postura.Alto)
	banda: BasePart?, -- la caja de la raíz, por si la raíz no chocara (solo existe en este cliente)
	grupos: { [BasePart]: string }, -- el grupo de colisión que tenía cada pieza antes de agacharte
	alAnadir: RBXScriptConnection?,
	alQuitar: RBXScriptConnection?,
	sinSalto: boolean, -- se le ha quitado saltar (no cabe de pie)
}

local jugador = Players.LocalPlayer
local estado = PosturaReglas.nuevo() -- lo que ya se ve (la predicción)
local quiereAgachado = false -- lo que ha pedido con C (alterna)
local izquierda, derecha, ultima = false, false, 0 -- Z y X apretadas; la última que se apretó (-1 o 1)
local pendiente: { [string]: Pendiente } = {} -- lo mandado que el servidor aún no ha publicado
-- Cuándo cambió por última vez cada atributo del servidor: lo mandado solo se da por puesto con un cambio que llega
-- después de mandarlo (con dos toques seguidos, el valor viejo del servidor puede ser igual al nuevo y no vale).
local cambioEn: { [string]: number } = { Agachado = -math.huge, Asomar = -math.huge }
local mandadoEn: { [string]: number } = { Agachado = -math.huge, Asomar = -math.huge }
local rendido: { [string]: Valor } = {} -- lo que el servidor no ha querido: no se pide más hasta que cambie lo que quieres
local boton: TextButton? = nil
local encendido: boolean? = nil -- cómo está pintado el botón
local apagado: boolean? = nil -- si se pinta como que ahora no se puede
local cuerpo: Cuerpo? = nil -- el cuerpo de ahora (solo R15)
local atascado = false -- de pie según la postura, pero sin sitio para levantarse: el cuerpo sigue abajo
local cabeVisto, cabeHora = true, -math.huge -- lo último mirado hacia arriba y cuándo
local ultimoTope = -math.huge
local arriba = RaycastParams.new()
arriba.FilterType = Enum.RaycastFilterType.Exclude
arriba.RespectCanCollide = true -- cortinas y hojas no cuentan
local zonas: { BasePart } = {} -- las zonas "Debajo" de los muebles (Mapa), que este cliente tiene siempre
-- Lo que tapa el tablero de cada zona, en sus ejes: { x1, x2, z1, z2 }, medido con su CFrame de entonces.
type Techo = { cf: CFrame, x1: number, x2: number, z1: number, z2: number }
local techos: { [BasePart]: Techo } = {}

-- Lo que se ve ahora (para CuerpoVista).
function PosturaVista.agachado(): boolean
	return estado.agachado
end

-- -1 izquierda, 0 o 1 derecha.
function PosturaVista.asomado(): number
	return estado.asomado
end

-- Abajo: agachado, o sin sitio para levantarte (la cámara va con esto, no con agachado()).
function PosturaVista.bajo(): boolean
	return estado.agachado or atascado
end

-- Studs que ha bajado ahora el cuerpo: la cámara baja eso de menos. El HipHeight y lo que ha encogido la raíz, que
-- baja su centro la mitad y la cabeza que pone la cámara de Roblox otro tanto (con AutomaticScalingEnabled la cabeza va
-- a 1,5 + (Size.Y - 2) / 2 del centro; si no, a 1,5 fijo).
function PosturaVista.cuerpo(): number
	local c = cuerpo
	if not c then
		return 0
	end
	local encoge = if c.abajo then math.max(0, c.alto - c.raiz.Size.Y) else 0
	return math.max(0, c.pie - c.puesto) + encoge * (if c.hum.AutomaticScalingEnabled then 1 else 0.5)
end

-- Cuándo te diste por última vez con lo de arriba al querer levantarte (os.clock), para el respingo de la cámara.
function PosturaVista.tope(): number
	return ultimoTope
end

-- Lo que tapa el tablero de una zona Debajo, en los ejes de la zona. Las zonas van solo entre las patas y el tablero
-- sobresale (en la mesa del comedor, 1,96 por las puntas y 0,7 por los lados largos, y por ahí se pasa agachado): se
-- saca de las medidas del mueble (su atributo Tam, con el pivote abajo en el centro, como en Mapa) y, si no cuadran,
-- ALERO de más alrededor.
local function techoDe(zona: BasePart): Techo
	local t = techos[zona]
	if t and t.cf == zona.CFrame then
		return t
	end
	local medio = zona.Size / 2
	local x1, x2, z1, z2 = -medio.X - ALERO, medio.X + ALERO, -medio.Z - ALERO, medio.Z + ALERO
	local mueble = zona.Parent
	local tam = if mueble and mueble:IsA("Model") then mueble:GetAttribute("Tam") else nil
	if mueble and typeof(tam) == "Vector3" then
		local pivote = (mueble :: Model):GetPivot()
		-- La zona va girada como el mueble (Mapa la pone en sus ejes) y apoyada en su suelo.
		if pivote.XVector:Dot(zona.CFrame.XVector) > 0.99 and pivote.YVector:Dot(zona.CFrame.YVector) > 0.99 then
			local centro = pivote:PointToObjectSpace(zona.Position)
			if math.abs(centro.Y - medio.Y) < 0.1 and tam.Y > zona.Size.Y then
				x1, x2 = math.min(x1, -tam.X / 2 - centro.X), math.max(x2, tam.X / 2 - centro.X)
				z1, z2 = math.min(z1, -tam.Z / 2 - centro.Z), math.max(z2, tam.Z / 2 - centro.Z)
			end
		end
	end
	local nuevo = { cf = zona.CFrame, x1 = x1, x2 = x2, z1 = z1, z2 = z2 }
	techos[zona] = nuevo
	return nuevo
end

-- La cara de abajo del tablero que hay encima de `punto` (su x y su z; su y, la altura desde la que se mira, para no
-- contar la mesa de otro piso), si lo hay. Las zonas Debajo de Mapa van del suelo a esa cara, y lo que choca de los
-- muebles no se puede mirar con rayos (CanQuery false, para no tapar la vista a los bichos): se miran a mano, con todo
-- lo que tapa el tablero (techoDe). Lo usan cabeDePie, la cámara (CuerpoVista) y el cuerpo de los demás (BrazosVista).
function PosturaVista.techoDebajo(punto: Vector3): number?
	local mas: number? = nil
	for _, zona in zonas do
		local rel = zona.CFrame:PointToObjectSpace(punto)
		local medio = zona.Size / 2
		local t = techoDe(zona)
		-- (de un poco por debajo del suelo de la zona a un poco por encima del tablero: un avatar muy grande lleva la
		-- raíz más alta que el hueco)
		if rel.X >= t.x1 and rel.X <= t.x2 and rel.Z >= t.z1 and rel.Z <= t.z2
			and rel.Y >= -medio.Y - 1 and rel.Y <= medio.Y + 1.5 then
			local y = zona.CFrame:PointToWorldSpace(Vector3.new(0, medio.Y, 0)).Y
			mas = if mas then math.min(mas, y) else y
		end
	end
	return mas
end

local function humanoide(): Humanoid?
	local personaje = jugador.Character
	return personaje and personaje:FindFirstChildOfClass("Humanoid")
end

local function datos(): PosturaReglas.Jugador
	local hum = humanoide()
	return {
		vivo = hum ~= nil and hum.Health > 0 and not jugador:GetAttribute("Muerto"),
		escondido = jugador:GetAttribute("Escondido") ~= nil,
		cargando = jugador:GetAttribute("Cargando") ~= nil or jugador:GetAttribute("Trabajando") ~= nil,
		mochila = jugador:GetAttribute("MochilaAbierta") == true,
	}
end

local function neutro(que: string): Valor
	return if que == "Agachado" then false else 0
end

-- ¿Una cinemática? (la cámara la lleva un script). Ahí no se empieza a agachar ni a asomar; levantarse y dejar de
-- asomarse, sí. Mirando por la mirilla o entre las cortinas (atributo local Vistazo, de MirarVista) no cuenta: ahí
-- agacharse corta el vistazo (MirarVista sale si cambia Agachado o Asomado), y asomarse se queda como estaba hasta
-- acabar (soltar Z o X a medias no debe cortarlo).
local function enCine(): boolean
	local camara = workspace.CurrentCamera
	return camara ~= nil and camara.CameraType == Enum.CameraType.Scriptable and jugador:GetAttribute("Vistazo") == nil
end

local function mio(que: string): Valor
	return if que == "Agachado" then estado.agachado else estado.asomado
end

local function quiere(que: string): Valor
	if que == "Agachado" then
		return quiereAgachado
	elseif izquierda and derecha then
		return ultima
	end
	return if izquierda then -1 elseif derecha then 1 else 0
end

local function delServidor(que: string): Valor
	if que == "Agachado" then
		return jugador:GetAttribute("Agachado") == true
	end
	local a = jugador:GetAttribute("Asomado")
	return if a == -1 or a == 1 then a else 0
end

-- Cambia lo que se ve sin pedirlo (no cuenta para Config.Postura.Cada).
local function poner(que: string, valor: Valor)
	local nuevo = table.clone(estado)
	if que == "Agachado" then
		nuevo.agachado = valor == true
	else
		nuevo.asomado = valor :: number
	end
	estado = nuevo
end

local function mandar(que: string, valor: Valor, intentos: number)
	pendiente[que] = { valor = valor, hora = os.clock(), intentos = intentos }
	mandadoEn[que] = os.clock()
	Remotes.Postura:FireServer(que, valor)
end

-- No va a ser (el servidor no quiere o lo ha quitado él): derecho y de pie, y no se vuelve a pedir hasta que sueltes la
-- tecla o pulses otra vez.
local function dejar(que: string)
	pendiente[que] = nil
	rendido[que] = quiere(que)
	if que == "Agachado" then
		quiereAgachado = false
	end
	poner(que, neutro(que))
	if delServidor(que) ~= neutro(que) then
		mandar(que, neutro(que), 1)
	end
end

-- El roce de los pies en el suelo al agacharte, al levantarte y al empezar a asomarte (solo lo oyes tú).
local function sonar(tono: number, volumen: number)
	local hum = humanoide()
	local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not raiz or hum.FloorMaterial == Enum.Material.Air then
		return
	end
	local s = Sonido.en(SUELO[hum.FloorMaterial] or "PasoTierra", raiz.Position - Vector3.new(0, 2.5, 0), tono)
	s.Volume *= volumen
end

-- ===== El cuerpo agachado (ver la cabecera) =====

local function grupoListo(): boolean
	local ok, si = pcall(PhysicsService.IsCollisionGroupRegistered, PhysicsService, GRUPO)
	return ok and si == true
end

-- ¿Cabes de pie aquí? Una caja con la planta de la raíz, desde su centro hasta tu coronilla de pie. Lo que ya toca al
-- empezar (una pared al lado) no cuenta. Vale MIRAR_ARRIBA s.
local function cabeDePie(): boolean
	local c = cuerpo
	if not c or (not c.abajo and c.puesto >= c.pie - 1e-3) then
		return true
	end
	local ahora = os.clock()
	if ahora - cabeHora < MIRAR_ARRIBA then
		return cabeVisto
	end
	cabeHora = ahora
	local raiz = c.raiz
	local cabeza = c.personaje:FindFirstChild("Head")
	-- De pie, la coronilla: el centro de la cabeza (donde la pone la cámara de Roblox) y media cabeza. Con la raíz de
	-- pie (agachado está encogida y su centro, más abajo).
	local alto = if c.abajo then c.alto else raiz.Size.Y
	local coronilla = 1.5 + (alto - 2) / 2 + (if cabeza and cabeza:IsA("BasePart") then cabeza.Size.Y / 2 else 0.6)
	arriba.FilterDescendantsInstances = { c.personaje, workspace.CurrentCamera :: Instance }
	local caja = Vector3.new(raiz.Size.X * 0.9, 0.1, raiz.Size.Z * 0.9)
	local subir = (c.pie + alto / 2) - (c.puesto + raiz.Size.Y / 2) + coronilla + HOLGURA_PIE
	cabeVisto = workspace:Blockcast(raiz.CFrame, caja, Vector3.new(0, subir, 0), arriba) == nil
	-- Y los tableros de los muebles (no se ven con rayos): ni el centro ni las esquinas de la planta debajo de uno.
	if cabeVisto then
		local tope = raiz.Position.Y + subir
		for _, e in ESQUINAS do
			local y = PosturaVista.techoDebajo(raiz.CFrame:PointToWorldSpace(Vector3.new(e[1] * caja.X / 2, 0, e[2] * caja.Z / 2)))
			if y and y < tope then
				cabeVisto = false
				break
			end
		end
	end
	return cabeVisto
end

-- Te das con lo de arriba al querer levantarte: un crujido flojo (la cámara da el respingo con PosturaVista.tope()).
local function topar()
	local ahora = os.clock()
	if ahora - ultimoTope < TOPE_CADA then
		return
	end
	ultimoTope = ahora
	local camara = workspace.CurrentCamera
	if camara and Sonido.hay("Cruje") then
		local s = Sonido.en("Cruje", camara.CFrame.Position + Vector3.new(0, 0.6, 0), 1.35)
		s.Volume *= TOPE_VOLUMEN
	end
end

-- Para levantarte tienes que caber de pie; si no, el golpecito. (Saltar manda muchas peticiones seguidas mientras lo
-- mantienes: se usa lo mirado hace menos de MIRAR_ARRIBA s.)
local function puedeLevantarse(): boolean
	if cabeDePie() then
		return true
	end
	topar()
	return false
end

-- Todo el cuerpo a GRUPO salvo la raíz (lo que choca: ver la cabecera) y su banda.
local function aGrupo(c: Cuerpo, parte: Instance)
	if parte:IsA("BasePart") and parte ~= c.raiz and parte ~= c.banda and c.grupos[parte] == nil then
		c.grupos[parte] = parte.CollisionGroup
		parte.CollisionGroup = GRUPO
	end
end

-- La raíz de `alto` de alto, con la planta en el mismo sitio (el Humanoid la pone a HipHeight del suelo); la banda,
-- igual que ella.
local function altoRaiz(c: Cuerpo, alto: number)
	local raiz = c.raiz
	if math.abs(raiz.Size.Y - alto) > 1e-4 then
		raiz.Size = Vector3.new(raiz.Size.X, alto, raiz.Size.Z)
	end
	local banda = c.banda
	if banda and banda.Size ~= raiz.Size then
		banda.Size = raiz.Size
	end
end

-- La banda: la misma caja que la raíz (soldada en su centro, y altoRaiz la cambia con ella), por si la raíz no chocara.
-- Se apunta en c.banda antes de colgarla del personaje (si no, alAnadir la metería también en GRUPO y no chocaría).
local function crearBanda(c: Cuerpo)
	local raiz = c.raiz
	local banda = Instance.new("Part")
	banda.Name = "PosturaBanda"
	banda.Size = raiz.Size
	banda.Transparency = 1
	banda.CastShadow = false
	banda.CanCollide = true
	banda.CanQuery = false
	banda.CanTouch = false
	banda.Massless = true
	banda.CollisionGroup = raiz.CollisionGroup -- el de la raíz ("Personajes")
	local union = Instance.new("Weld")
	union.Part0 = raiz
	union.Part1 = banda
	union.Parent = banda
	banda.CFrame = raiz.CFrame
	c.banda = banda
	banda.Parent = c.personaje
end

-- Abajo: del cuerpo solo chocan la raíz (que irá encogiendo) y su banda.
local function bajarCuerpo(c: Cuerpo)
	if c.puesto >= c.pie - 1e-3 then
		-- De pie del todo: el HipHeight y la raíz de pie se vuelven a mirar (el avatar puede haber cambiado de tamaño).
		c.pie = c.hum.HipHeight
		c.puesto = c.pie
		c.bajo = math.min(PASO_LIBRE, c.pie) -- un avatar tan bajito que ya cabe no baja
		c.alto = c.raiz.Size.Y
	end
	-- Agachado, la raíz llega a Config.Postura.Alto (sin crecer: un avatar bajito ya cabe).
	c.altoBajo = math.min(c.alto, math.max(0.2, Config.Postura.Alto - c.bajo))
	c.abajo = true
	for _, parte in c.personaje:GetDescendants() do
		aGrupo(c, parte)
	end
	c.alAnadir = c.personaje.DescendantAdded:Connect(function(parte)
		aGrupo(c, parte)
	end)
	-- Lo que sale del personaje (una herramienta que se suelta) vuelve a su grupo: en GRUPO caería por el suelo.
	c.alQuitar = c.personaje.DescendantRemoving:Connect(function(parte)
		local pieza = parte :: BasePart
		local grupo = c.grupos[pieza]
		if grupo then
			c.grupos[pieza] = nil
			pieza.CollisionGroup = grupo
		end
	end)
	crearBanda(c)
end

-- De pie otra vez: todo vuelve a chocar como antes, la raíz a su tamaño y la banda se va.
local function soltarCuerpo(c: Cuerpo)
	if c.alAnadir then
		c.alAnadir:Disconnect()
		c.alAnadir = nil
	end
	if c.alQuitar then
		c.alQuitar:Disconnect()
		c.alQuitar = nil
	end
	for parte, grupo in c.grupos do
		if parte.Parent then
			parte.CollisionGroup = grupo
		end
	end
	table.clear(c.grupos)
	if c.banda then
		c.banda:Destroy()
		c.banda = nil
	end
	if c.abajo then
		c.abajo = false
		altoRaiz(c, c.alto)
	end
end

local function quitarSalto(c: Cuerpo, quitar: boolean)
	if c.sinSalto ~= quitar then
		c.sinSalto = quitar
		c.hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, not quitar)
	end
end

-- Cada fotograma: el cuerpo hacia abajo o hacia arriba (si cabes), y sin saltar mientras no quepas de pie.
local function cuidarCuerpo(dt: number)
	local c = cuerpo
	if not c then
		return
	end
	if not c.hum.Parent or c.hum.Health <= 0 or jugador:GetAttribute("Escondido") ~= nil then
		-- Muerto o escondido (el servidor te ancla y te mueve): todo a su sitio al momento.
		atascado = false
		if c.abajo or c.puesto ~= c.pie then
			soltarCuerpo(c)
			c.puesto = c.pie
			c.hum.HipHeight = c.pie
		end
		quitarSalto(c, false)
		return
	end
	if not c.abajo and not estado.agachado then
		return -- de pie y sin nada que hacer
	end
	if not c.abajo and not grupoListo() then
		return -- sin el grupo del servidor no se puede: solo la cámara (CuerpoVista), como antes
	end
	-- Queriendo estar de pie con el cuerpo abajo, solo si cabes.
	atascado = not estado.agachado and not cabeDePie()
	local abajo = estado.agachado or atascado
	if abajo and not c.abajo then
		bajarCuerpo(c)
	end
	local meta = if abajo then c.bajo else c.pie
	if c.puesto ~= meta then
		local paso = CUERPO_VEL * dt
		c.puesto = if math.abs(meta - c.puesto) <= paso then meta else c.puesto + math.sign(meta - c.puesto) * paso
		c.hum.HipHeight = c.puesto
	end
	if c.abajo then
		-- La raíz encoge a la vez que baja el HipHeight (y crece al subir): su tapa va de la de pie a Config.Postura.Alto.
		local recorrido = c.pie - c.bajo
		local k = if recorrido > 1e-3 then math.clamp((c.pie - c.puesto) / recorrido, 0, 1) else 1
		altoRaiz(c, c.alto + (c.altoBajo - c.alto) * k)
	end
	if not abajo and c.puesto >= c.pie - 1e-3 then
		soltarCuerpo(c) -- ya de pie del todo
	end
	quitarSalto(c, abajo and not cabeDePie())
end

local function prepararCuerpo(personaje: Model, hum: Humanoid)
	cuerpo, atascado = nil, false
	local raiz = personaje:WaitForChild("HumanoidRootPart", 10)
	if hum.RigType ~= Enum.HumanoidRigType.R15 or not raiz or not raiz:IsA("BasePart") or jugador.Character ~= personaje then
		return -- R6: solo la cámara, como antes
	end
	cuerpo = {
		personaje = personaje,
		hum = hum,
		raiz = raiz,
		pie = hum.HipHeight,
		bajo = math.min(PASO_LIBRE, hum.HipHeight),
		puesto = hum.HipHeight,
		abajo = false,
		alto = raiz.Size.Y,
		altoBajo = raiz.Size.Y,
		banda = nil,
		grupos = {},
		alAnadir = nil,
		alQuitar = nil,
		sinSalto = false,
	}
end

-- El botón del móvil: encendido (borde claro sobre rojo oscuro) mientras estás agachado; apagado si ahora no se puede.
local function pintarBoton(libre: boolean)
	local b = boton
	if not b then
		return
	end
	if apagado ~= not libre then
		apagado = not libre
		b.TextTransparency = if libre then 0 else 0.55
	end
	if encendido == estado.agachado then
		return
	end
	encendido = estado.agachado
	local info = TweenInfo.new(0.15)
	TweenService:Create(b, info, { BackgroundColor3 = if estado.agachado then Ui.Color.Sangre else Ui.Color.Papel }):Play()
	local borde = b:FindFirstChildOfClass("UIStroke")
	if borde then
		TweenService:Create(borde, info, {
			Color = if estado.agachado then Ui.Color.Hueso else Ui.Color.Sangre,
			Thickness = if estado.agachado then 3 else 2,
		}):Play()
	end
end

-- Pone lo que se ve de acuerdo con lo que quieres y con el servidor. Cada fotograma y al pulsar (respuesta al momento).
local function sincronizar()
	local ahora = os.clock()
	local d = datos()
	local libre = PosturaReglas.puede(d)
	local mirando = jugador:GetAttribute("Vistazo") ~= nil -- por la mirilla o entre las cortinas: asomarse, quieto
	-- Lo que ya no puede ser se quita aquí al momento, sin pedirlo: el servidor también lo quita él solo.
	local quita, limpio = PosturaReglas.limpiar(estado, d)
	if quita then
		estado = limpio
	end
	if not libre then
		-- Muerto, escondido o cargando: de pie y sin pedir nada (no lo aceptaría). Al volver, de pie.
		quiereAgachado = false
		table.clear(pendiente)
		pintarBoton(false)
		return
	end
	for _, que in QUE do
		-- Con el servidor: lo mandado que ya ha publicado, lo que no llega y lo que cambia él.
		local servidor = delServidor(que)
		local p = pendiente[que]
		if p then
			if servidor == p.valor and (cambioEn[que] > p.hora or ahora - p.hora >= ESPERA) then
				pendiente[que] = nil -- lo ha puesto (o ya lo tenía y no ha cambiado en todo este rato)
			elseif ahora - p.hora >= ESPERA then
				if p.valor == neutro(que) or p.intentos < INTENTOS then
					mandar(que, p.valor, p.intentos + 1) -- se perdió o llegó muy seguido: otra vez
				else
					dejar(que)
				end
			end
		elseif servidor ~= mio(que) then
			-- El servidor solo la quita por lo que aquí ya se ve (morir, esconderse, cargar, la mochila, reaparecer). Si
			-- llega sin haber pedido nada, la ha quitado él: de pie. Justo después de pedir algo es el eco de una
			-- petición de antes (varios toques seguidos con la red lenta): se le manda lo que se ve.
			if servidor == neutro(que) and ahora - mandadoEn[que] >= RECIENTE then
				dejar(que)
			else
				mandar(que, mio(que), 1)
			end
		end
		-- Lo que quieres: se pide en cuanto se pueda (las mismas reglas que el servidor, también cada cuánto).
		local q = quiere(que)
		if rendido[que] ~= nil and rendido[que] ~= q then
			rendido[que] = nil
		end
		local quieto = que == "Asomar" and mirando
		if q ~= mio(que) and rendido[que] == nil and not quieto and (q == neutro(que) or not enCine()) then
			local antes = mio(que)
			local cambia, nuevo = PosturaReglas.pedir(estado, que, q, ahora, d)
			if cambia then
				estado = nuevo
				mandar(que, q, 1)
				if que == "Agachado" then
					sonar(if q == true then 0.85 else 0.95, RUIDO)
				elseif antes == 0 then
					sonar(1.05, RUIDO_ASOMAR)
				end
			elseif que == "Agachado" and not PosturaReglas.permitido(que, q, d) then
				quiereAgachado = estado.agachado -- ahora no se puede: se olvida (asomarse sí espera: es mantener)
			end
		end
	end
	pintarBoton(true)
end

-- ¿Sentado o subiendo por una escalera? Ahí no se agacha.
local function ocupado(hum: Humanoid?): boolean
	return hum ~= nil and (hum.Sit or hum:GetState() == Enum.HumanoidStateType.Climbing)
end

local function alternar()
	if not quiereAgachado and (ocupado(humanoide()) or enCine()) then
		return
	end
	if quiereAgachado then
		cabeHora = -math.huge -- al pulsar, se mira de nuevo si cabes
		if not puedeLevantarse() then
			return -- debajo de algo: sigues agachado
		end
	end
	quiereAgachado = not quiereAgachado
	sincronizar()
end

-- Saltar, una escalera o sentarte: de pie, si cabes (debajo de una mesa, saltar no te levanta).
local function levantar()
	if quiereAgachado or estado.agachado then
		if not puedeLevantarse() then
			return
		end
		quiereAgachado = false
		sincronizar()
	end
end

-- Para correr (CorrerVista, 14.8): de pie si cabes, como al saltar. Devuelve si ya no quieres seguir agachado (de pie
-- o levantándote); false si no cabes de pie (el golpecito contra lo de arriba).
function PosturaVista.levantarse(): boolean
	if not (quiereAgachado or estado.agachado) then
		return true
	end
	cabeHora = -math.huge -- se mira de nuevo si cabes
	levantar()
	return not quiereAgachado
end

local function conPersonaje(personaje: Model)
	-- Personaje nuevo: de pie (el servidor también lo quita al reaparecer).
	cuerpo, atascado = nil, false
	estado = PosturaReglas.quitar(estado)
	quiereAgachado = false
	table.clear(pendiente)
	table.clear(rendido)
	local hum = personaje:WaitForChild("Humanoid", 10)
	if hum and hum:IsA("Humanoid") then
		hum.StateChanged:Connect(function(_, nuevo)
			if nuevo == Enum.HumanoidStateType.Climbing or nuevo == Enum.HumanoidStateType.Seated then
				levantar()
			end
		end)
		prepararCuerpo(personaje, hum)
	end
end

function PosturaVista.start()
	-- Móvil: botón AGACHARSE en la rejilla del equipo (EquipoVista: el tamaño lo pone ella; orden 6).
	if Ui.tactil() then
		local fila = Ui.hud():FindFirstChild("EquipoBotones")
		if fila then
			local b = Ui.boton(Lang.t(nil, "Crouch"), { LayoutOrder = 6, Name = "Agacharse" })
			Ui.queQuepa(b, 22)
			b.Activated:Connect(alternar)
			b.Parent = fila
			boton = b
		end
	end
	UserInputService.InputBegan:Connect(function(entrada, procesado)
		if procesado then
			return
		end
		local tecla = entrada.KeyCode
		if tecla == Enum.KeyCode.C or tecla == Enum.KeyCode.LeftControl
			or (tecla == Enum.KeyCode.ButtonB and not jugador:GetAttribute("MochilaAbierta")) then -- B cierra la mochila
			alternar()
		elseif tecla == Enum.KeyCode.Z then
			izquierda, ultima = true, -1
			sincronizar()
		elseif tecla == Enum.KeyCode.X then
			derecha, ultima = true, 1
			sincronizar()
		end
	end)
	-- Al soltar, aunque estuvieras escribiendo: que no se quede asomado.
	UserInputService.InputEnded:Connect(function(entrada)
		if entrada.KeyCode == Enum.KeyCode.Z then
			izquierda = false
			sincronizar()
		elseif entrada.KeyCode == Enum.KeyCode.X then
			derecha = false
			sincronizar()
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		izquierda, derecha = false, false
		sincronizar()
	end)
	UserInputService.JumpRequest:Connect(levantar) -- saltar levanta (teclado, mando y el botón de saltar del móvil)
	for que, atributo in { Agachado = "Agachado", Asomar = "Asomado" } do
		jugador:GetAttributeChangedSignal(atributo):Connect(function()
			cambioEn[que] = os.clock()
		end)
	end
	jugador.CharacterAdded:Connect(conPersonaje)
	if jugador.Character then
		task.spawn(conPersonaje, jugador.Character)
	end
	-- Las zonas Debajo de los muebles (para techoDebajo).
	local function nuevaZona(zona: Instance)
		if zona:IsA("BasePart") and not table.find(zonas, zona) then
			table.insert(zonas, zona)
		end
	end
	for _, zona in CollectionService:GetTagged("Debajo") do
		nuevaZona(zona)
	end
	CollectionService:GetInstanceAddedSignal("Debajo"):Connect(nuevaZona)
	CollectionService:GetInstanceRemovedSignal("Debajo"):Connect(function(zona)
		local i = table.find(zonas, zona :: any)
		if i then
			table.remove(zonas, i)
		end
		techos[zona :: any] = nil
	end)
	RunService.Heartbeat:Connect(function(dt)
		sincronizar()
		cuidarCuerpo(dt)
	end)
end

return PosturaVista
