-- Banco de los cuerpos que caen de verdad (docs/sistemas/cadaver.md). Ejecutar desde la raíz:
-- lune run tests/bancos/cadaver.luau (lo corre tests/regressions.luau). Carga src/juego/cliente/CadaverVista.luau de
-- verdad con el Roblox de mentira (_roblox.luau, sin física de piezas sueltas: aquí no se ve caer, solo lo demás):
--   Cuentas: hacia dónde sale despedido, los límites de cada junta (R15 y R6, la raíz fuera), cómo crece el charco y
--   el brillo de la linterna caída (parpadea, baja al final y a los 40 s, nada).
--   En el mundo: al matar a otro (remote Muerte), el de verdad escondido y sin chocar, y un muñeco con su ropa, sin
--   scripts, sin raíz ni Motor6D, con una rótula con límites por junta, despedido hacia el lado contrario del bicho;
--   el charco escondido hasta que se ancla y luego bajo el pecho, creciendo en 8 s; la linterna encendida cae con su
--   color y se apaga a los 40 s; el bucle se para solo; el tope de 4; con Rendimiento se ancla a los 1,5 s y la
--   linterna cae quieta y sin sombras; al revivir, fuera; tu muerte, tras el susto; y una muerte sin remote.
-- Si algo no se cumple, termina con error.
local crearMundo = require("./_roblox")

local cuentas = 0
local function comprobar(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end
local function cerca(a: number, b: number, etiqueta: string, margen: number?)
	assert(math.abs(a - b) <= (margen or 1e-6), `{etiqueta}: esperado {b}, recibido {a}`)
	cuentas += 1
end

local m = crearMundo()
local g = m.global
local Vector3, CFrame, Enum, Instance = g.Vector3, g.CFrame, g.Enum, g.Instance
local CollectionService = m.servicio("CollectionService")
local jugador = m.jugadorLocal
local Config = m.cargar("src/shared/Config")
local CFG = Config.Cadaver
local C = m.cargar("src/juego/cliente/CadaverVista")

---------------------------------------------------------------- cuentas

do
	local d = C.empuje(Vector3.new(0, 3, 0), Vector3.new(5, 6, 0), Vector3.new(0, 0, -1))
	cerca(d.X, -1, "empuje: lejos del bicho")
	cerca(d.Y, 0, "empuje: en horizontal")
	d = C.empuje(Vector3.new(0, 3, 0), Vector3.new(0, 8, 0), Vector3.new(0, 0, -1))
	cerca(d.Z, 1, "empuje: con el bicho encima, hacia atrás")
	d = C.empuje(Vector3.new(0, 3, 0), nil, Vector3.new(1, 0, 0))
	cerca(d.X, -1, "empuje: sin bicho, hacia atrás")
	d = C.empuje(Vector3.new(0, 3, 0), nil, Vector3.new(0, 1, 0))
	comprobar(not m.roto(d) and math.abs(d.Magnitude - 1) < 1e-6, "empuje: mirando arriba, sin NaN")

	for nombre, clave in { Neck = "Cuello", LeftShoulder = "Hombro", RightElbow = "Codo", LeftWrist = "Muneca",
		Waist = "Cintura", RightHip = "Cadera", LeftKnee = "Rodilla", RightAnkle = "Tobillo",
		["Left Shoulder"] = "Hombro", ["Right Hip"] = "Cadera" } do
		comprobar(C.junta(nombre) == CFG.Juntas[clave], `junta: {nombre} es {clave}`)
	end
	comprobar(C.junta("Root") == nil and C.junta("RootJoint") == nil, "junta: la raíz se quita")
	comprobar(C.junta("Rara") == CFG.Juntas.Otra, "junta: una que no se conoce, la de por defecto")
	for _, lim in CFG.Juntas do
		comprobar(lim[1] > 0 and lim[1] <= 90 and lim[2] > 0 and lim[2] <= 90, "junta: límites con sentido")
	end
	comprobar(CFG.Juntas.Rodilla[2] < CFG.Juntas.Hombro[2], "junta: la rodilla apenas gira sobre sí")

	cerca(C.charcoTam(0, 6), CFG.Charco.Desde, "charco: empieza pequeño")
	cerca(C.charcoTam(CFG.Charco.Crece, 6), 6, "charco: a los 8 s, su tamaño")
	cerca(C.charcoTam(100, 6), 6, "charco: y no pasa de ahí")
	local antes = 0
	for t = 0, CFG.Charco.Crece, 0.5 do
		local tam = C.charcoTam(t, 6)
		comprobar(tam >= antes, "charco: siempre crece")
		antes = tam
	end
	comprobar(C.charcoTam(CFG.Charco.Crece / 2, 6) < 6 - 0.5, "charco: a mitad, aún no ha llegado")

	local L = CFG.Linterna
	cerca(C.brillo(L.Dura, 0.5), 0, "linterna: a los 40 s, apagada")
	cerca(C.brillo(L.Dura + 5, 0.9), 0, "linterna: y sigue apagada")
	comprobar(C.brillo(1, 0.5) > 0.85, "linterna: al caer, casi entera")
	comprobar(C.brillo(1, -1) < 0.1, "linterna: un tirón la deja casi apagada")
	comprobar(C.brillo(L.Dura - 1, 0.9) < C.brillo(5, 0.9), "linterna: al final, más floja")
	-- Al final hay más tirones: un ruido que al principio no corta, al final sí.
	comprobar(C.brillo(5, -0.3) > 0.5 and C.brillo(L.Dura - 0.5, -0.3) < 0.05, "linterna: más tirones al apagarse")
	for t = 0, L.Dura, 0.37 do
		for _, r in { -1, -0.4, 0, 0.6, 1 } do
			local b = C.brillo(t, r)
			comprobar(b >= 0 and b <= 1 and not m.roto(b), "linterna: brillo entre 0 y 1")
		end
	end
	comprobar(C.anclarEn(false) == CFG.Anclar and C.anclarEn(true) == CFG.AnclarRendimiento
		and CFG.AnclarRendimiento < CFG.Anclar, "anclar: antes con Rendimiento")
end

---------------------------------------------------------------- en el mundo

m.caja(Vector3.new(0, -0.5, 0), Vector3.new(400, 1, 400)) -- el suelo
m.personaje(CFrame.new(-60, 3, 0)) -- tú, lejos
C.start()
local carpeta = g.workspace:FindFirstChild("Cadaveres")
comprobar(carpeta ~= nil, "start: la carpeta de los cuerpos")

-- Lo que MuerteVista pone al morir otro (su función charco): un cilindro tumbado con la etiqueta, creciendo.
local function charcoDeMuerteVista(pos: Vector3): any
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Size = Vector3.new(0.05, 1, 1)
	p.CFrame = CFrame.new(Vector3.new(pos.X, 0.03, pos.Z)) * CFrame.Angles(0, 0, math.pi / 2)
	p.Parent = g.workspace.Terrain
	p:AddTag("Charco")
	g.game:GetService("TweenService"):Create(p, g.TweenInfo.new(6), { Size = Vector3.new(0.05, 6, 6) }):Play()
	return p
end

local function contar(modelo: any, clase: string): number
	local n = 0
	for _, d in modelo:GetDescendants() do
		if d.ClassName == clase then
			n += 1
		end
	end
	return n
end

-- Muere otro, con un bicho a su derecha y la linterna roja encendida.
local victima = m.jugador("Victima")
local real = m.personaje(CFrame.new(0, 3, 0), victima)
local motores = contar(real, "Motor6D")
local camisa = Instance.new("Shirt")
camisa.Parent = real
local sombrero = Instance.new("Accessory")
local asa = Instance.new("Part")
asa.Name = "Handle"
asa.CFrame = CFrame.new(0, 5.6, 0)
asa.Parent = sombrero
sombrero.Parent = real
local guion = Instance.new("LocalScript")
guion.Name = "Animate"
guion.Parent = real
real:AddTag("Personaje")
victima:SetAttribute("Linterna", true)
victima:SetAttribute("PuestoLinterna", "LuzRoja")
m.alCliente("Muerte", victima, Vector3.new(5, 6, 0), nil)
local charco = charcoDeMuerteVista(Vector3.new(0, 3, 0))
m.correr(1 / 30)

local lista = C.cuerpos()
comprobar(#lista == 1, "muerte: un muñeco")
local c = lista[1]
local copia = c.modelo
comprobar(copia.Parent == carpeta, "muerte: en su carpeta")
comprobar(copia:FindFirstChildOfClass("Shirt") ~= nil, "muerte: con su ropa")
comprobar(copia:FindFirstChildOfClass("Humanoid") ~= nil, "muerte: con su Humanoid (para la ropa)")
local hum = copia:FindFirstChildOfClass("Humanoid")
comprobar(hum.EvaluateStateMachine == false and hum.DisplayDistanceType == Enum.HumanoidDisplayDistanceType.None,
	"muerte: el Humanoid de la copia no hace nada ni enseña el nombre")
comprobar(copia:FindFirstChild("HumanoidRootPart") == nil, "muerte: sin la raíz")
comprobar(contar(copia, "Motor6D") == 0, "muerte: sin Motor6D")
comprobar(contar(copia, "LocalScript") == 0 and contar(copia, "Sound") == 0, "muerte: sin scripts ni sonidos")
comprobar(#copia:GetTags() == 0, "muerte: sin las etiquetas del personaje")
local rotulas = {}
for _, d in copia:GetDescendants() do
	if d.ClassName == "BallSocketConstraint" then
		table.insert(rotulas, d)
	end
end
comprobar(#rotulas == motores - 1, `muerte: una rótula por junta menos la raíz ({#rotulas} de {motores})`)
comprobar(contar(copia, "NoCollisionConstraint") == #rotulas, "muerte: las dos piezas de cada junta no chocan")
for _, bs in rotulas do
	comprobar(bs.LimitsEnabled and bs.TwistLimitsEnabled, "rótula: con límites")
	comprobar(bs.UpperAngle > 0 and bs.TwistLowerAngle == -bs.TwistUpperAngle, "rótula: cono y giro")
	local a0, a1 = bs.Attachment0, bs.Attachment1
	comprobar(a0 and a1 and a0.Parent ~= a1.Parent, "rótula: une dos piezas")
	comprobar(not m.roto(a0.CFrame) and not m.roto(a1.CFrame), "rótula: sin NaN")
	cerca((a0.WorldPosition - a1.WorldPosition).Magnitude, 0, "rótula: los dos lados en el mismo sitio", 1e-3)
	cerca(a0.WorldCFrame.XVector:Dot(a1.WorldCFrame.XVector), 1, "rótula: en reposo con la pose de ahora", 1e-3)
end
local cuello = copia.Head:FindFirstChild("CadaverNeck")
comprobar(cuello and cuello.UpperAngle == CFG.Juntas.Cuello[1], "rótula: el cuello con sus límites")
local rodilla = copia:FindFirstChild("LeftLowerLeg"):FindFirstChild("CadaverLeftKnee")
comprobar(rodilla and rodilla.TwistUpperAngle == CFG.Juntas.Rodilla[2], "rótula: la rodilla con sus límites")
-- El de verdad, escondido y sin chocar; la copia, a la vista y sin anclar.
for _, d in real:GetDescendants() do
	if d:IsA("BasePart") then
		comprobar(d.LocalTransparencyModifier == 1 and not d.CanCollide and not d.CanQuery, "real: escondido y sin chocar")
	end
end
comprobar(real:FindFirstChildOfClass("Humanoid").DisplayDistanceType == Enum.HumanoidDisplayDistanceType.None,
	"real: sin el nombre encima")
local cuerpoTorso = copia:FindFirstChild("UpperTorso")
for _, p in c.partes do
	comprobar(p.LocalTransparencyModifier == 0 and not p.Anchored, "copia: a la vista y suelta")
end
comprobar(cuerpoTorso.CanCollide, "copia: el tronco choca")
local asaCopia = copia:FindFirstChildOfClass("Accessory"):FindFirstChild("Handle")
comprobar(not asaCopia.CanCollide and asaCopia.Massless, "copia: el sombrero no choca ni pesa")
-- Despedido hacia el lado contrario del bicho (que está en +X), hacia arriba y girando.
local v = cuerpoTorso.AssemblyLinearVelocity
comprobar(v.X < -CFG.Empuje * 0.7 and v.Y > 0 and math.abs(v.Z) < 1e-6, "copia: sale despedida lejos del bicho")
comprobar(cuerpoTorso.AssemblyAngularVelocity.Magnitude > 0, "copia: el tronco gira")
-- La linterna, roja, con sombras, suelta.
comprobar(c.linterna ~= nil, "linterna: cae")
local lint = c.linterna.parte
comprobar(lint.Parent == carpeta and not lint.Anchored, "linterna: suelta, rodando")
local luz = lint:FindFirstChildOfClass("SpotLight")
comprobar(luz and luz.Color.R > luz.Color.G * 1.5 and luz.Shadows, "linterna: con su color (roja) y sombras")
comprobar(luz.Brightness <= Config.Linterna.Brillo, "linterna: no más fuerte que en la mano")
-- El charco: escondido mientras vuela.
comprobar(c.charco == charco, "charco: el de MuerteVista es suyo")
comprobar(charco.Transparency == 1, "charco: escondido mientras vuela")
m.correr(0.5)
comprobar(charco.Size.Y < 0.2, "charco: no crece mientras vuela (manda sobre el tween de MuerteVista)")
comprobar(C.activo(), "bucle: corre mientras se mueve")

-- A los 3 s, anclado entero y sin chocar; el charco bajo el pecho, pequeño y creciendo.
m.correr(CFG.Anclar - 0.5 - 0.2, 1 / 30)
comprobar(not c.anclado, "anclar: antes de los 3 s, no")
m.correr(0.3, 1 / 30)
comprobar(c.anclado, "anclar: a los 3 s, sí")
for _, p in c.partes do
	comprobar(p.Anchored and not p.CanCollide, "anclar: todas sus piezas, sin chocar")
end
comprobar(charco.Transparency == 0, "charco: a la vista al pararse")
local ct = cuerpoTorso.Position
comprobar(math.abs(charco.Position.X - ct.X) < 0.1 and math.abs(charco.Position.Z - ct.Z) < 0.1,
	"charco: bajo el pecho")
cerca(charco.Position.Y, 0.03, "charco: en el suelo", 0.01)
comprobar(charco.Size.Y < 1.5, "charco: empieza pequeño")
m.correr(CFG.Charco.Crece / 2, 1 / 10)
local mitad = charco.Size.Y
comprobar(mitad > 1.5 and mitad < CFG.Charco.Tam[2], "charco: a mitad, creciendo")
m.correr(CFG.Charco.Crece / 2 + 0.2, 1 / 10)
comprobar(charco.Size.Y >= CFG.Charco.Tam[1] - 1e-3 and charco.Size.Y <= CFG.Charco.Tam[2] + 1e-3,
	"charco: a los 8 s, su tamaño")
comprobar(lint.Anchored, "linterna: ya quieta")
comprobar(luz.Enabled, "linterna: aún encendida")
-- Parpadea: el brillo cambia.
local brillos = {}
m.correr(3, 1 / 10, function()
	brillos[math.floor(luz.Brightness * 100)] = true
end)
local distintos = 0
for _ in brillos do
	distintos += 1
end
comprobar(distintos > 3, "linterna: el haz parpadea")
m.correr(CFG.Linterna.Dura, 1 / 10)
comprobar(not luz.Enabled, "linterna: a los 40 s, apagada")
comprobar(lint.Parent == carpeta, "linterna: se queda en el suelo")
m.correr(0.1)
comprobar(not C.activo(), "bucle: parado cuando ya no se mueve nada")
comprobar(copia.Parent == carpeta, "muerte: el cuerpo se queda")

-- Revive (personaje nuevo): fuera el muñeco y su linterna.
m.personaje(CFrame.new(0, 3, 0), victima)
m.correr(0.1)
comprobar(#C.cuerpos() == 0 and copia.Parent == nil, "revivir: fuera el muñeco")
comprobar(lint.Parent == nil, "revivir: fuera su linterna")
comprobar(charco.Parent ~= nil, "revivir: la sangre se queda")

-- El tope: 5 muertes seguidas, como mucho 4 moviéndose; el más viejo, anclado.
local otros = {}
for i = 1, 5 do
	local j = m.jugador("Otro" .. i)
	m.personaje(CFrame.new(i * 12, 3, 40), j)
	table.insert(otros, j)
	m.alCliente("Muerte", j, Vector3.new(i * 12, 6, 45), nil)
	m.correr(0.05)
end
local moviendo = 0
for _, x in C.cuerpos() do
	if not x.anclado then
		moviendo += 1
	end
end
comprobar(#C.cuerpos() == 5 and moviendo == CFG.Tope, `tope: {CFG.Tope} moviéndose ({moviendo})`)
comprobar(C.cuerpos()[1].anclado, "tope: el más viejo, anclado")
comprobar(C.cuerpos()[2].modelo.UpperTorso.AssemblyLinearVelocity.Z < 0, "tope: despedidos lejos del bicho (en -Z)")
comprobar(C.cuerpos()[2].linterna == nil, "tope: sin linterna encendida, nada cae")
m.correr(CFG.Anclar + 0.2)
local Players = m.servicio("Players")
local function irse(j: any)
	Players.PlayerRemoving:Fire(j) -- el Roblox de mentira no lo dispara solo
	j:Destroy()
end
for _, j in otros do
	irse(j)
end
m.correr(0.1)
comprobar(#C.cuerpos() == 0, "se va: fuera sus muñecos")

-- Con Rendimiento: se ancla a los 1,5 s y la linterna cae ya quieta y sin sombras.
jugador:SetAttribute("Rendimiento", true)
local r = m.jugador("Rendimiento")
m.personaje(CFrame.new(-20, 3, -40), r)
r:SetAttribute("Linterna", true)
m.alCliente("Muerte", r, Vector3.new(-25, 6, -40), nil)
m.correr(CFG.AnclarRendimiento - 0.2, 1 / 30)
local cr = C.cuerpos()[1]
comprobar(not cr.anclado, "rendimiento: antes de 1,5 s, suelto")
m.correr(0.3, 1 / 30)
comprobar(cr.anclado, "rendimiento: a los 1,5 s, anclado")
local lr = cr.linterna.parte
comprobar(lr.Anchored and not lr:FindFirstChildOfClass("SpotLight").Shadows, "rendimiento: linterna quieta y sin sombras")
cerca(lr.Position.Y, 0.15, "rendimiento: la linterna en el suelo", 0.01)
jugador:SetAttribute("Rendimiento", nil)
irse(r)
m.correr(0.1)

-- Muerte sin remote (otra causa): a los 0,3 s, un muñeco donde está, sin empuje ni grito.
local s = m.jugador("Caido")
local realS = m.personaje(CFrame.new(30, 3, -30), s)
m.correr(0.1)
realS:FindFirstChildOfClass("Humanoid").Health = 0
m.correr(0.1)
comprobar(#C.cuerpos() == 0, "sin remote: aún no")
m.correr(CFG.SinAviso)
comprobar(#C.cuerpos() == 1, "sin remote: su muñeco")
cerca(C.cuerpos()[1].modelo.UpperTorso.AssemblyLinearVelocity.Magnitude, 0, "sin remote: sin empuje")
irse(s)
m.correr(0.1)

-- Tu muerte: nada mientras el susto lleva la cámara; luego tu muñeco, con apenas empuje, y tu cuerpo anclado.
local tuyo = jugador.Character
m.camara.CameraType = Enum.CameraType.Scriptable
m.alCliente("Muerte", jugador, Vector3.new(-55, 6, 0), nil)
m.correr(3)
comprobar(#C.cuerpos() == 0, "tú: nada durante el susto")
m.camara.CameraType = Enum.CameraType.Custom
m.correr(0.1)
comprobar(#C.cuerpos() == 1 and C.cuerpos()[1].propio, "tú: tu muñeco al acabar el susto")
local vt = C.cuerpos()[1].modelo.UpperTorso.AssemblyLinearVelocity
comprobar(vt.X < 0 and vt.Magnitude < CFG.Empuje * 0.5, "tú: con apenas empuje")
comprobar(tuyo.HumanoidRootPart.Anchored and tuyo.Head.LocalTransparencyModifier == 1, "tú: tu cuerpo, quieto y escondido")
m.correr(CFG.Anclar + 0.2)
comprobar(not C.activo(), "tú: el bucle se para")

print(`cadaver: {cuentas} comprobaciones bien`)
