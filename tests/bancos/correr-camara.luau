-- Banco de la cámara corriendo (14.8, pedido por el usuario: "todo animado e inmersivo"; y bancos que carguen el módulo
-- de verdad y miren cada fotograma). Carga src/juego/cliente/CuerpoVista.luau y Pasos.luau con el Roblox de mentira
-- (tests/bancos/_roblox.luau) y CorrerVista, PosturaVista y Sonido falsos que lleva el banco. Hay un suelo, una pared,
-- una pared al lado (para asomarse) y una casa con un armario (caja Choque) y una encimera (zona Debajo con su
-- tablero): las dos con CanQuery = false, como en el juego (los rayos normales no las ven, MuebleRayo sí).
-- En cada fotograma, justo después de CuerpoVista (Camera + 2): sin NaN en la cámara ni en el campo de visión, la cámara
-- nunca baja del suelo ni se mete en la pared ni en los muebles. Y por escenas: andar, correr, frenar en seco, soltar
-- Shift, correr contra la pared, tropezar (en abierto, contra la pared, el armario y la encimera, agachado y asomado),
-- cansado de noche, Rendimiento, un vistazo, la mochila, una cinemática y un fotograma muy largo; al parar, todo vuelve
-- al reposo (campo de visión 70 justo, sin desvío ni giro). Pasos: más seguidos corriendo, el pisotón al tropezar
-- (el tuyo y el de otro). Ejecutar desde la raíz: lune run tests/bancos/correr-camara.luau (lo corre regressions.luau).
local crearMundo = require("./_roblox")

local cuentas = 0
local function comprobar(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end

local m = crearMundo()
local g = m.global
local Vector3, CFrame, Enum = g.Vector3, g.CFrame, g.Enum
local RunService = m.servicio("RunService")
local TweenService = m.servicio("TweenService")
local jugador = m.jugadorLocal
local camara = m.camara
local Config = m.cargar("src/shared/Config")

local CAMPO = 70 -- el campo de visión normal (el de la cámara de Roblox)
local MARGEN = 0.1 -- studs que se queda la cámara como poco de cualquier caja (el plano cercano de Roblox)
local MARGEN_TROPIEZO = 0.28 -- y al tropezar hacia algo (CuerpoVista: HOLGURA 0,3)
local SUELO = 1.0 -- studs sobre el suelo como poco (CuerpoVista: SUELO_MIN 1,2 al tropezar, menos el balanceo)

-- El mundo, lejos de la casa (x = 200: fuera, para el vaho de noche). ---------------------------------------------------
local X = 200
m.caja(CFrame.new(X + 20, -0.5, 0), Vector3.new(120, 1, 120), { Name = "Suelo" })
local solidas: { { cf: any, tam: any, nombre: string } } = {}
local function solida(cf: any, tam: any, nombre: string, props: { [string]: any }?): any
	local p = m.caja(cf, tam, props)
	p.Name = nombre
	table.insert(solidas, { cf = cf, tam = tam, nombre = nombre })
	return p
end
local PARED_Z = -30 -- la cara de la pared de delante
solida(CFrame.new(X, 4, PARED_Z - 0.5), Vector3.new(30, 8, 1), "Pared")
-- Una pared a la derecha (para asomarse): su cara a 1 stud del centro de la raíz.
solida(CFrame.new(X - 20 + 1.5, 4, 0), Vector3.new(1, 8, 30), "ParedLado")
-- La casa: un armario (caja Choque) y una encimera (zona Debajo con Tam: su tablero de 3,6 a 4,4, a la altura de la
-- cámara al tropezar). Las dos sin CanQuery, como en el juego; debajo, un zócalo que sí choca para que el personaje
-- de mentira se pare (el de mentira no choca con lo que no tiene CanQuery).
local casa = g.Instance.new("Model")
casa.Name = "Casa"
casa.Parent = g.workspace
local AX, EX = X + 30, X + 37
local armario = solida(CFrame.new(AX, 3.5, PARED_Z - 0.5), Vector3.new(4, 7, 1), "Choque", { CanQuery = false })
armario.Parent = casa
m.caja(CFrame.new(AX, 1.2, PARED_Z - 0.5), Vector3.new(4, 2.4, 1), { Name = "Zocalo" })
local encimera = g.Instance.new("Model")
encimera.Name = "Encimera"
encimera:SetAttribute("Tam", Vector3.new(5, 4.4, 3))
encimera.WorldPivot = CFrame.new(EX, 0, PARED_Z - 1.5)
encimera.Parent = casa
local zona = m.caja(CFrame.new(EX, 1.8, PARED_Z - 1.5), Vector3.new(4, 3.6, 2), { CanCollide = false, CanQuery = false })
zona.Name = "Debajo"
zona.Parent = encimera
zona:AddTag("Debajo")
local tablero = solida(CFrame.new(EX, 4, PARED_Z - 1.5), Vector3.new(5, 0.8, 3), "Tablero", { CanQuery = false })
tablero.Parent = encimera
m.caja(CFrame.new(EX, 1.2, PARED_Z - 1.5), Vector3.new(5, 2.4, 3), { Name = "Zocalo" })

-- Falsos ------------------------------------------------------------------------------------------------------------
-- CorrerVista: lo que el banco quiere (Shift), con ritmo suave como el de verdad (sube en 0,25 s, baja en 0,4 s), la
-- velocidad local (16, por 1,5 corriendo, por FactorFrena tras agotarse, a la mitad agachado) y el tropiezo.
local C = Config.Correr
local estado = {
	quiere = false,
	corre = false,
	ritmo = 0,
	cansancio = 0,
	frena = false,
	tropiezoEn = nil :: number?,
	ultima = -math.huge,
}
local postura = { agachado = false, asomado = 0, cuerpo = 0, tope = 0 }
local CorrerFalso = {}
function CorrerFalso.corriendo(): boolean
	return estado.corre
end
function CorrerFalso.ritmo(): number
	return estado.ritmo
end
function CorrerFalso.aguante(): number
	return 1 - estado.cansancio
end
function CorrerFalso.agotado(): boolean
	return estado.frena
end
function CorrerFalso.cansancio(): number
	return estado.cansancio
end
function CorrerFalso.tropiezo(): number?
	local t = estado.tropiezoEn and m.ahora() - estado.tropiezoEn
	return if t and t < 1.6 then t else nil
end
function CorrerFalso.recien(): number
	return if estado.corre then 0 else m.ahora() - estado.ultima
end
function CorrerFalso.jadear() end
function CorrerFalso.alAgotarse()
	return { Disconnect = function() end }
end
local PosturaFalsa = {
	agachado = function()
		return postura.agachado
	end,
	asomado = function()
		return postura.asomado
	end,
	bajo = function()
		return postura.agachado
	end,
	cuerpo = function()
		return postura.cuerpo
	end,
	tope = function()
		return postura.tope
	end,
	techoDebajo = function()
		return nil
	end,
	levantarse = function()
		return true
	end,
}
local sonidos: { { nombre: string, pos: any, tono: number, t: number, s: any } } = {}
local SonidoFalso = {
	en = function(nombre: string, pos: any, tono: number?)
		local s = g.Instance.new("Sound")
		s.Volume = 0.5
		table.insert(sonidos, { nombre = nombre, pos = pos, tono = tono or 1, t = m.ahora(), s = s })
		return s
	end,
	tocar = function()
		return g.Instance.new("Sound")
	end,
}

local pj = m.personaje(CFrame.new(X, 3, 0))
local hum, raiz = pj.Humanoid, pj.HumanoidRootPart
local falsos = { CorrerVista = CorrerFalso, PosturaVista = PosturaFalsa, Sonido = SonidoFalso }
local CuerpoVista = m.cargar("src/juego/cliente/CuerpoVista", falsos)
local Pasos = m.cargar("src/juego/cliente/Pasos", falsos)

-- El CorrerVista falso, antes que todo (prioridad Input), como la velocidad local del de verdad.
RunService:BindToRenderStep("CorrerFalso", Enum.RenderPriority.Input.Value, function(dt: number)
	local mueve = hum.MoveDirection.Magnitude > 0.01
	local antes = estado.corre
	estado.corre = estado.quiere and mueve and not estado.frena and not postura.agachado
	if antes and not estado.corre then
		estado.ultima = m.ahora()
	end
	if estado.corre then
		estado.ritmo = math.min(1, estado.ritmo + dt / 0.25)
	else
		estado.ritmo = math.max(0, estado.ritmo - dt / 0.4)
	end
	local v = 16 * (if estado.corre then C.Factor else 1) * (if estado.frena then C.FactorFrena else 1)
		* (if postura.agachado then 0.5 else 1)
	if hum.WalkSpeed ~= v then
		hum.WalkSpeed = v
	end
end)

-- La sonda, justo después de CuerpoVista: lo que se ve este fotograma. -----------------------------------------------
local function distanciaCaja(p: any, cf: any, tam: any): number
	local o = cf:PointToObjectSpace(p)
	local h = tam / 2
	local fuera = Vector3.new(math.max(math.abs(o.X) - h.X, 0), math.max(math.abs(o.Y) - h.Y, 0),
		math.max(math.abs(o.Z) - h.Z, 0))
	if fuera.Magnitude > 0 then
		return fuera.Magnitude
	end
	return -math.min(h.X - math.abs(o.X), h.Y - math.abs(o.Y), h.Z - math.abs(o.Z)) -- dentro: negativo
end

local escena = "?"
local margen = MARGEN
local mirada = { giro = 0, arriba = 0 } -- hacia dónde mira la cámara de Roblox (m.mirar)
local medida: { [string]: number } = {}
local function medir(clave: string, valor: number, mayor: boolean)
	local antes = medida[clave]
	if antes == nil or (mayor and valor > antes) or (not mayor and valor < antes) then
		medida[clave] = valor
	end
end
local function nueva(nombre: string)
	escena = nombre
	medida = {}
	margen = MARGEN
end
local fotogramas = 0
local base: any = nil
RunService:BindToRenderStep("Sonda", Enum.RenderPriority.Camera.Value + 2, function()
	fotogramas += 1
	local cf = camara.CFrame
	comprobar(not m.roto(cf), `{escena}: NaN o infinito en la cámara`)
	comprobar(not m.roto(camara.FieldOfView), `{escena}: NaN en el campo de visión`)
	local ejes = math.abs(cf.LookVector.Magnitude - 1) + math.abs(cf.LookVector:Dot(cf.UpVector))
	comprobar(ejes < 1e-4, `{escena}: la cámara deformada ({ejes})`)
	if camara.CameraType ~= Enum.CameraType.Custom then
		return
	end
	comprobar(cf.Position.Y >= SUELO, `{escena}: la cámara baja del suelo (y = {cf.Position.Y})`)
	for _, s in solidas do
		local d = distanciaCaja(cf.Position, s.cf, s.tam)
		medir("cerca" .. s.nombre, d, false)
		comprobar(d >= margen, `{escena}: la cámara a {d} de {s.nombre} (como poco {margen})`)
	end
	local fov = camara.FieldOfView
	medir("fovMax", fov, true)
	medir("fovMin", fov, false)
	medida.fov = fov
	-- Lo que CuerpoVista le ha sumado a la cámara de Roblox (en la cabeza más el CameraOffset; ver _roblox).
	base = CFrame.new(raiz.Position + Vector3.new(0, 1.5, 0) + raiz.CFrame:VectorToWorldSpace(hum.CameraOffset))
		* CFrame.fromOrientation(mirada.arriba, mirada.giro, 0)
	local rel = base:ToObjectSpace(cf)
	local cabeceo = math.deg(math.asin(math.clamp(cf.LookVector.Y, -1, 1))) - math.deg(mirada.arriba)
	local alabeo = math.deg(math.asin(math.clamp(rel.RightVector.Y, -1, 1)))
	medir("subeMax", rel.Position.Y, true)
	medir("subeMin", rel.Position.Y, false)
	medir("delanteMax", -rel.Position.Z, true)
	medir("desvioMax", rel.Position.Magnitude, true)
	medir("cabeceoMin", cabeceo, false)
	medir("cabeceoMax", cabeceo, true)
	medir("alabeoMax", math.abs(alabeo), true)
	medida.desvio = rel.Position.Magnitude
	medida.cabeceo = cabeceo
	medida.alabeo = alabeo
	medida.ojoY = cf.Position.Y
end)

-- Ayudas de las escenas ---------------------------------------------------------------------------------------------
local function reposo()
	estado.quiere, estado.frena, estado.cansancio, estado.tropiezoEn = false, false, 0, nil
	postura.agachado, postura.asomado, postura.cuerpo = false, 0, 0
	hum.HipHeight = 2
	m.andar(nil)
end
-- El personaje en (x, z) con los pies en el suelo, mirando `giro` (0 = hacia -Z), y quieto hasta que se asiente.
local function colocar(x: number, z: number, giro: number?)
	reposo()
	mirada.giro, mirada.arriba = giro or 0, 0
	m.mirar(mirada.giro, 0)
	pj:PivotTo(CFrame.new(x, 3, z) * CFrame.Angles(0, mirada.giro, 0))
	m.correr(0.3)
	estado.ultima = -math.huge -- que el salto de sitio no cuente como frenar tras correr
	m.correr(2.5)
end
local function delante(): any
	return Vector3.new(-math.sin(mirada.giro), 0, -math.cos(mirada.giro))
end
local function tropezar()
	estado.tropiezoEn = m.ahora()
end
-- Tras parar: todo de vuelta (el campo de visión justo, sin desvío ni giro de más; solo la respiración).
local function enReposo(etiqueta: string)
	comprobar(medida.fov == CAMPO, `{etiqueta}: el campo de visión no vuelve ({medida.fov})`)
	comprobar(camara.FieldOfView == CAMPO, `{etiqueta}: el campo de visión no vuelve al acabar el fotograma`)
	comprobar(medida.desvio < 0.03, `{etiqueta}: la cámara se queda movida ({medida.desvio})`)
	comprobar(math.abs(medida.cabeceo) < 0.3, `{etiqueta}: la cámara se queda cabeceada ({medida.cabeceo})`)
	comprobar(math.abs(medida.alabeo) < 0.1, `{etiqueta}: la cámara se queda ladeada ({medida.alabeo})`)
	comprobar(hum.CameraOffset.Magnitude < 1e-3, `{etiqueta}: el CameraOffset se queda puesto`)
end

Pasos.start()
CuerpoVista.start()
m.correr(0.5)
comprobar(#m.errores == 0, "arranque sin errores")

-- Las cuentas sueltas (lo que dijo CAMARA) -----------------------------------------------------------------------
do
	local function cerca(a: number, b: number, etiqueta: string)
		comprobar(math.abs(a - b) < 1e-6, `{etiqueta}: {a} y no {b}`)
	end
	cerca(CuerpoVista.curvaTropiezo(0), 0, "curvaTropiezo(0)")
	cerca(CuerpoVista.curvaTropiezo(0.2), 1, "curvaTropiezo(0,2)")
	cerca(CuerpoVista.curvaTropiezo(1.4), 0, "curvaTropiezo(1,4)")
	cerca(CuerpoVista.curvaTropiezo(0 / 0), 0, "curvaTropiezo(NaN)")
	cerca(CuerpoVista.campo(1, 24), 7, "campo(1, 24)")
	cerca(CuerpoVista.campo(0.5, 24), 3.5, "campo(0,5, 24)")
	cerca(CuerpoVista.frenazo(23, 0, true), 1, "frenazo(23, 0)")
	cerca(CuerpoVista.frenazo(24, 16, true), 0, "frenazo de correr a andar")
	cerca(CuerpoVista.frenazo(24, 0, false), 0, "frenazo sin venir corriendo")
	cerca(CuerpoVista.zancada(1), 6.2, "zancada(1)")
	-- La curva no tiene saltos (de 1/120 s en 1/120 s).
	local antes, salto = 0, 0
	for i = 1, 200 do
		local f = CuerpoVista.curvaTropiezo(i / 120)
		salto = math.max(salto, math.abs(f - antes))
		antes = f
	end
	comprobar(salto < 0.12, `curvaTropiezo sin saltos ({salto})`)
end

-- Andar y correr en abierto --------------------------------------------------------------------------------------
local subeAndando, subeCorriendo
do
	colocar(X + 10, 20, math.pi) -- hacia +Z, con sitio
	nueva("andar")
	local n0 = #sonidos
	m.andar(delante())
	m.correr(3)
	comprobar(medida.fovMax == CAMPO and medida.fovMin == CAMPO, "andar: el campo de visión no se mueve")
	subeAndando = medida.subeMax - medida.subeMin
	comprobar(subeAndando > 0.08 and subeAndando < 0.2, `andar: la cabeza sube y baja ({subeAndando})`)
	local pasosAndando = #sonidos - n0
	m.andar(nil)
	m.correr(2.5)
	enReposo("andar y parar")

	colocar(X + 10, -20, math.pi)
	nueva("correr")
	n0 = #sonidos
	estado.quiere = true
	m.andar(delante())
	m.correr(3)
	comprobar(math.abs(medida.fov - (CAMPO + 7)) < 0.05, `correr: el campo de visión se abre 7 ({medida.fov})`)
	comprobar(medida.fovMax <= CAMPO + 7 + 1e-6, "correr: el campo de visión no se pasa")
	subeCorriendo = medida.subeMax - medida.subeMin
	comprobar(subeCorriendo > subeAndando * 1.8, `correr: la cabeza se mueve más ({subeCorriendo} / {subeAndando})`)
	comprobar(medida.cabeceoMin < -0.3, `correr: cabecea en cada pisada ({medida.cabeceoMin})`)
	local pasosCorriendo = #sonidos - n0
	-- 3 s: andando 48 studs / 7 (unos 7 pasos); corriendo 72 / 6,2 (unos 11).
	comprobar(pasosAndando >= 6 and pasosAndando <= 8, `pasos andando: {pasosAndando}`)
	comprobar(pasosCorriendo >= 10 and pasosCorriendo <= 13, `pasos corriendo: {pasosCorriendo}`)
	comprobar(sonidos[#sonidos].tono >= 0.85 and sonidos[#sonidos].tono <= 1.2, "pasos corriendo: el tono")

	-- Frenar en seco: suelta todo de golpe.
	nueva("frenar en seco")
	estado.quiere = false
	m.andar(nil)
	m.correr(0.6)
	comprobar(medida.cabeceoMin < -1.5, `frenar en seco: la cabeza sigue hacia delante ({medida.cabeceoMin})`)
	comprobar(medida.cabeceoMin > -4, `frenar en seco: sin pasarse ({medida.cabeceoMin})`)
	m.correr(2.5)
	enReposo("frenar en seco")
end

-- Soltar solo Shift sin dejar de andar: sin sacudida -----------------------------------------------------------
do
	colocar(X + 10, -20, math.pi)
	estado.quiere = true
	m.andar(delante())
	m.correr(2)
	nueva("correr y soltar Shift")
	m.correr(1)
	local corriendo = medida.cabeceoMin
	nueva("soltar Shift")
	estado.quiere = false
	m.correr(1)
	comprobar(medida.cabeceoMin > corriendo - 0.3, `soltar Shift: sacude ({medida.cabeceoMin} / {corriendo})`)
	comprobar(math.abs(medida.fov - CAMPO) < 0.3, `soltar Shift: el campo de visión vuelve ({medida.fov})`)
	m.andar(nil)
	m.correr(2.5)
	enReposo("soltar Shift")
end

-- Agotarse corriendo: frena a FactorFrena y sacude a la mitad ------------------------------------------------------
do
	colocar(X + 10, -20, math.pi)
	estado.quiere = true
	m.andar(delante())
	m.correr(2)
	nueva("agotarse")
	estado.frena = true
	m.correr(0.6)
	comprobar(medida.cabeceoMin < -0.6, `agotarse: un frenazo pequeño ({medida.cabeceoMin})`)
	estado.quiere = false
	m.andar(nil)
	m.correr(2.5)
	enReposo("agotarse")
end

-- Correr contra la pared: no se mete, el campo de visión casi no se abre ---------------------------------------------
do
	colocar(X, PARED_Z + 6)
	nueva("correr contra la pared")
	estado.quiere = true
	m.andar(delante())
	m.correr(1.5)
	comprobar(raiz.Position.Z < PARED_Z + 0.7, `correr contra la pared: llega a la pared ({raiz.Position.Z})`)
	comprobar(medida.fov < CAMPO + 0.5, `contra la pared: el campo de visión apenas ({medida.fov})`)
	-- Y tropezar ahí: la cámara no se mete en la pared (los rayos de siempre).
	nueva("tropezar contra la pared")
	margen = MARGEN_TROPIEZO
	tropezar()
	m.correr(1.6)
	comprobar(medida.cabeceoMin < -12, `tropezar contra la pared: cae la vista ({medida.cabeceoMin})`)
	comprobar(medida.subeMin < -0.4, `tropezar contra la pared: baja ({medida.subeMin})`)
	estado.quiere = false
	m.andar(nil)
	m.correr(2.5)
	enReposo("tropezar contra la pared")
end

-- Tropezar en abierto: cae hacia delante y de lado, baja, va hacia delante y vuelve ------------------------------
do
	colocar(X + 10, -20, math.pi)
	estado.quiere = true
	m.andar(delante())
	m.correr(1.5)
	nueva("tropezar")
	local n0 = #sonidos
	estado.frena = true
	tropezar()
	m.correr(0.4)
	comprobar(medida.cabeceoMin < -14 and medida.cabeceoMin > -19, `tropezar: la vista cae 16 ({medida.cabeceoMin})`)
	comprobar(medida.alabeoMax > 5 and medida.alabeoMax < 9, `tropezar: de lado 7 ({medida.alabeoMax})`)
	comprobar(medida.subeMin < -0.55, `tropezar: baja ({medida.subeMin})`)
	comprobar(medida.delanteMax > 0.2 and medida.delanteMax < 0.45, `tropezar: hacia delante ({medida.delanteMax})`)
	-- Pasos: el pisotón al momento y el pie que se arrastra a 0,12 y 0,26 s.
	local tonos = {}
	for i = n0 + 1, #sonidos do
		table.insert(tonos, sonidos[i].tono)
	end
	comprobar(table.find(tonos, 0.78) and table.find(tonos, 0.62) and table.find(tonos, 0.55),
		`tropezar: pisotón y arrastre ({table.concat(tonos, ", ")})`)
	estado.quiere = false
	m.andar(nil)
	m.correr(1.2)
	comprobar(math.abs(medida.cabeceo) < 1, `tropezar: se recupera ({medida.cabeceo})`)
	estado.frena = false
	m.correr(2)
	enReposo("tropezar")
end

-- Tropezar contra el armario y la encimera (CanQuery = false: solo los ve MuebleRayo) ----------------------------
for _, cosa in { { "armario", AX }, { "encimera", EX } } do
	colocar(cosa[2], PARED_Z + 6)
	estado.quiere = true
	m.andar(delante())
	m.correr(1.5)
	comprobar(raiz.Position.Z < PARED_Z + 1, `{cosa[1]}: llega ({raiz.Position.Z})`)
	nueva("tropezar contra el " .. cosa[1])
	margen = MARGEN_TROPIEZO
	tropezar()
	m.correr(1.6)
	comprobar(medida.cabeceoMin < -12, `{cosa[1]}: cae la vista ({medida.cabeceoMin})`)
	comprobar(medida.subeMin < -0.4, `{cosa[1]}: baja ({medida.subeMin})`)
	comprobar(medida.delanteMax < 0.29, `{cosa[1]}: no va hacia delante entero ({medida.delanteMax})`)
	-- Frenar ahí en seco (al soltar contra el mueble) tampoco mete la cámara.
	estado.quiere = false
	m.andar(nil)
	m.correr(2.5)
	enReposo("tropezar contra el " .. cosa[1])
end

-- Agachado: la vista baja y, tropezando, no baja del suelo ------------------------------------------------------
do
	colocar(X + 10, 20, math.pi)
	nueva("agachado")
	postura.agachado = true
	postura.cuerpo = 1 -- PosturaVista baja el HipHeight y la vista baja eso de menos
	hum.HipHeight = 1
	m.andar(delante())
	m.correr(2)
	local ojo = medida.ojoY
	comprobar(ojo < 4.5 - 1.4 and ojo > 4.5 - 2, `agachado: la vista baja Config.Postura.Baja ({ojo})`)
	comprobar(medida.fovMax == CAMPO, "agachado: el campo de visión no se mueve")
	tropezar()
	m.correr(1.6)
	comprobar(medida.cabeceoMin < -12, `agachado: tropieza ({medida.cabeceoMin})`)
	postura.agachado, postura.cuerpo = false, 0
	hum.HipHeight = 2
	m.andar(nil)
	m.correr(2.5)
	enReposo("agachado")
end

-- Asomado junto a la pared de la derecha (a 1 stud): la cabeza no se mete, ni tropezando ---------------------------
do
	colocar(X - 20, 0)
	nueva("asomado")
	postura.asomado = 1
	m.correr(1.5)
	comprobar(medida.alabeoMax > 8, `asomado: se ladea ({medida.alabeoMax})`)
	estado.quiere = true
	m.andar(delante())
	m.correr(0.5)
	tropezar()
	m.correr(1.6)
	estado.quiere = false
	m.andar(nil)
	postura.asomado = 0
	m.correr(2.5)
	enReposo("asomado")
end

-- Cansado de noche, fuera: más vaho y la respiración más honda; descansado vuelve ----------------------------------
do
	colocar(X + 10, 20, math.pi)
	g.workspace:SetAttribute("Fase", "Noche")
	local function vahoEn(cansancio: number, segundos: number): (number, number)
		estado.cansancio = cansancio
		local emisor = g.workspace.Terrain:FindFirstChild("Vaho")
		local antes = emisor and m.interno(emisor:FindFirstChildOfClass("ParticleEmitter"))._emitidas or 0
		nueva("cansado " .. cansancio)
		m.correr(segundos)
		emisor = g.workspace.Terrain:FindFirstChild("Vaho")
		local despues = emisor and m.interno(emisor:FindFirstChildOfClass("ParticleEmitter"))._emitidas or 0
		return despues - antes, medida.subeMax - medida.subeMin
	end
	local vahoDescansado, respiraDescansado = vahoEn(0, 12)
	local vahoCansado, respiraCansado = vahoEn(1, 12)
	comprobar(vahoDescansado > 0, "de noche fuera: echa vaho")
	comprobar(vahoCansado > vahoDescansado * 1.8, `cansado: más vaho ({vahoCansado} / {vahoDescansado})`)
	comprobar(respiraCansado > respiraDescansado * 2.5, `cansado: respira más hondo ({respiraCansado} / {respiraDescansado})`)
	jugador:SetAttribute("Rendimiento", true)
	local vahoRend = vahoEn(1, 6)
	comprobar(vahoRend == 0, "Rendimiento: sin vaho")
	jugador:SetAttribute("Rendimiento", nil)
	g.workspace:SetAttribute("Fase", nil)
	estado.cansancio = 0
	m.correr(1)
	enReposo("cansado")
end

-- Rendimiento: sin campo de visión, sin balanceo de más ni frenazo (el tropiezo sí) ---------------------------------
do
	jugador:SetAttribute("Rendimiento", true)
	colocar(X + 10, -20, math.pi)
	estado.quiere = true
	m.andar(delante())
	m.correr(1)
	nueva("Rendimiento corriendo")
	m.correr(2)
	comprobar(medida.fovMax == CAMPO and medida.fovMin == CAMPO, `Rendimiento: el campo de visión quieto ({medida.fovMax})`)
	local sube = medida.subeMax - medida.subeMin
	comprobar(sube < subeCorriendo * 0.85, `Rendimiento: sin balanceo de más ({sube} / {subeCorriendo})`)
	comprobar(medida.cabeceoMin > -0.2, `Rendimiento: sin cabecear al pisar ({medida.cabeceoMin})`)
	nueva("Rendimiento frenar")
	estado.quiere = false
	m.andar(nil)
	m.correr(0.6)
	comprobar(medida.cabeceoMin > -0.2, `Rendimiento: sin frenazo ({medida.cabeceoMin})`)
	nueva("Rendimiento tropezar")
	tropezar()
	m.correr(1.2)
	comprobar(medida.cabeceoMin < -12, `Rendimiento: el tropiezo sí ({medida.cabeceoMin})`)
	m.correr(1.5)
	enReposo("Rendimiento")
	jugador:SetAttribute("Rendimiento", nil)
end

-- Un vistazo (como MirarVista) a mitad de correr: al volver, el campo de visión de siempre. MirarVista apunta el campo
-- de antes (con lo nuestro dentro) y pone Vistazo al pulsar; luego, en su paso (Camera + 3), pone el suyo. `enSuPaso`:
-- todo eso a la vez dentro de un fotograma, tras CuerpoVista (el campo cambia antes de que CuerpoVista lo quite).
local function vistazo(etiqueta: string, enSuPaso: boolean)
	colocar(X + 10, -20, math.pi)
	estado.quiere = true
	m.andar(delante())
	m.correr(2)
	nueva(etiqueta)
	local fovAntes = camara.FieldOfView
	local function empezar()
		fovAntes = camara.FieldOfView
		jugador:SetAttribute("Vistazo", "Mirilla")
		if enSuPaso then
			camara.FieldOfView = 50
		end
	end
	if enSuPaso then
		RunService:BindToRenderStep("VistazoFalso", Enum.RenderPriority.Camera.Value + 3, function()
			RunService:UnbindFromRenderStep("VistazoFalso")
			empezar()
		end)
	else
		empezar()
	end
	estado.quiere = false
	m.andar(nil)
	m.paso()
	comprobar(fovAntes > CAMPO + 6, `{etiqueta}: corriendo al empezar ({fovAntes})`)
	camara.CameraType = Enum.CameraType.Scriptable
	camara.FieldOfView = 50
	local puesto = camara.FieldOfView
	m.correr(1)
	comprobar(camara.FieldOfView == puesto, `{etiqueta}: no toca el campo del vistazo`)
	camara.CameraType = Enum.CameraType.Custom
	if math.abs(camara.FieldOfView - puesto) < 0.01 then
		camara.FieldOfView = fovAntes
	end
	jugador:SetAttribute("Vistazo", nil)
	m.correr(2.5)
	enReposo(etiqueta)
end
vistazo("vistazo corriendo", false)
vistazo("vistazo corriendo (en su paso)", true)

-- La mochila a mitad de correr (MochilaUi: tween a 58 y luego a 70) ----------------------------------------------
do
	colocar(X + 10, -20, math.pi)
	estado.quiere = true
	m.andar(delante())
	m.correr(2)
	nueva("mochila")
	jugador:SetAttribute("MochilaAbierta", true)
	TweenService:Create(camara, g.TweenInfo.new(0.35), { FieldOfView = 58 }):Play()
	estado.quiere = false
	m.andar(nil)
	m.correr(1)
	jugador:SetAttribute("MochilaAbierta", nil)
	TweenService:Create(camara, g.TweenInfo.new(0.25), { FieldOfView = 70 }):Play()
	m.correr(2.5)
	enReposo("mochila")
end

-- Una cinemática a mitad de un tropiezo: no se toca la cámara; al volver, todo en su sitio ------------------------
do
	colocar(X + 10, -20, math.pi)
	estado.quiere = true
	m.andar(delante())
	m.correr(1.5)
	tropezar()
	m.correr(0.15)
	nueva("cinemática")
	local fija = CFrame.new(X, 20, 0) * CFrame.Angles(-0.3, 0.5, 0)
	camara.CameraType = Enum.CameraType.Scriptable
	local function poner()
		camara.CFrame = fija
	end
	RunService:BindToRenderStep("Cine", Enum.RenderPriority.Camera.Value, poner)
	local tocada = false
	RunService:BindToRenderStep("CineMira", Enum.RenderPriority.Camera.Value + 3, function()
		tocada = tocada or camara.CFrame ~= fija
	end)
	m.correr(1)
	comprobar(not tocada, "cinemática: CuerpoVista no mueve la cámara")
	RunService:UnbindFromRenderStep("Cine")
	RunService:UnbindFromRenderStep("CineMira")
	camara.CameraType = Enum.CameraType.Custom
	estado.quiere = false
	m.andar(nil)
	m.correr(2.5)
	enReposo("cinemática")
end

-- Un fotograma muy largo (un tirón) corriendo y tropezando: ni NaN ni la cámara volando --------------------------
do
	colocar(X + 10, -20, math.pi)
	estado.quiere = true
	m.andar(delante())
	m.correr(1.5)
	nueva("tirón")
	tropezar()
	m.paso(0.05)
	m.paso(0.6)
	m.paso(1 / 60)
	comprobar(medida.desvioMax < 1.5, `tirón: la cámara no sale volando ({medida.desvioMax})`)
	estado.quiere = false
	m.andar(nil)
	m.paso(0.5)
	m.correr(2.5)
	enReposo("tirón")
end

-- Pasos de otro: su atributo Tropiezo sube, su pisotón se oye en sus pies ------------------------------------------
do
	local otro = m.jugador("Otro")
	local suyo = m.personaje(CFrame.new(X + 14, 3, 20), otro)
	m.correr(0.5)
	local n0 = #sonidos
	otro:SetAttribute("Tropiezo", 1)
	m.correr(0.5)
	local tonos = {}
	for i = n0 + 1, #sonidos do
		table.insert(tonos, sonidos[i].tono)
		comprobar((sonidos[i].pos - suyo.HumanoidRootPart.Position).Magnitude < 3.5, "pasos de otro: en sus pies")
	end
	comprobar(#tonos == 3 and tonos[1] == 0.78, `pasos de otro: pisotón y arrastre ({table.concat(tonos, ", ")})`)
end

comprobar(#m.errores == 0, `sin errores: {table.concat(m.errores, "\n")}`)
print(`correr-camara: {cuentas} comprobaciones en {fotogramas} fotogramas.`)
