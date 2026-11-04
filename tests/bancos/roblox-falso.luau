-- Banco del Roblox de mentira (tests/bancos/_roblox.luau): que sus piezas se porten como Roblox antes de que otros
-- bancos se fíen de él. Ejecutar desde la raíz: lune run tests/bancos/roblox-falso.luau (lo corre regressions.luau).
local crearMundo = require("./_roblox")

local cuentas = 0
local function igual(actual, esperado, etiqueta: string)
	assert(actual == esperado, `{etiqueta}: esperado {tostring(esperado)}, recibido {tostring(actual)}`)
	cuentas += 1
end
local function cerca(actual: number, esperado: number, etiqueta: string, margen: number?)
	assert(math.abs(actual - esperado) <= (margen or 1e-4), `{etiqueta}: esperado {esperado}, recibido {actual}`)
	cuentas += 1
end
local function falla(fn: () -> (), etiqueta: string)
	assert(not pcall(fn), etiqueta .. ": tenía que fallar")
	cuentas += 1
end

local m = crearMundo()
local g = m.global
local Instance, Vector3, CFrame, UDim2, Enum = g.Instance, g.Vector3, g.CFrame, g.UDim2, g.Enum
local task = g.task
local TweenService = m.servicio("TweenService")
local RunService = m.servicio("RunService")

-- Señales: Connect, Fire, Disconnect, Once y Wait dentro de una corrutina del mundo.
do
	local e = Instance.new("BindableEvent")
	local suma = 0
	local c = e.Event:Connect(function(n)
		suma += n
	end)
	e:Fire(2)
	e:Fire(3)
	igual(suma, 5, "señal: Connect y Fire")
	c:Disconnect()
	igual(c.Connected, false, "señal: Disconnect")
	e:Fire(10)
	igual(suma, 5, "señal: desconectada no llega")
	local veces = 0
	e.Event:Once(function()
		veces += 1
	end)
	e:Fire()
	e:Fire()
	igual(veces, 1, "señal: Once solo una vez")
	local recibido = nil
	task.spawn(function()
		recibido = e.Event:Wait()
	end)
	igual(recibido, nil, "señal: Wait espera")
	e:Fire("hola")
	igual(recibido, "hola", "señal: Wait despierta con lo disparado")
	falla(function()
		e.Event:Wait()
	end, "señal: Wait desde el banco (fuera del mundo)")
	igual(m.typeof(e.Event), "RBXScriptSignal", "señal: typeof")
	igual(m.typeof(e), "Instance", "instancia: typeof")
end

-- Árbol: Parent, ChildAdded, DescendantAdded, FindFirstChild recursivo, IsA con clases base, Clone y Destroy.
do
	local carpeta = Instance.new("Folder")
	local hijos, descendientes = 0, 0
	carpeta.ChildAdded:Connect(function()
		hijos += 1
	end)
	carpeta.DescendantAdded:Connect(function()
		descendientes += 1
	end)
	local modelo = Instance.new("Model")
	modelo.Name = "Mueble"
	local tabla = Instance.new("Part")
	tabla.Name = "Tablero"
	tabla.Parent = modelo
	modelo.Parent = carpeta
	igual(hijos, 1, "árbol: ChildAdded")
	igual(descendientes, 2, "árbol: DescendantAdded del modelo y su pieza")
	igual(carpeta:FindFirstChild("Tablero"), nil, "árbol: FindFirstChild no recursivo")
	igual(carpeta:FindFirstChild("Tablero", true), tabla, "árbol: FindFirstChild recursivo")
	igual(carpeta.Mueble.Tablero, tabla, "árbol: hijos por nombre")
	igual(tabla:IsA("BasePart") and tabla:IsA("PVInstance") and tabla:IsA("Instance"), true, "árbol: IsA con las bases")
	igual(tabla:IsA("Model"), false, "árbol: IsA de otra clase")
	igual(tabla:FindFirstAncestorOfClass("Model"), modelo, "árbol: FindFirstAncestorOfClass")
	igual(carpeta:FindFirstChildWhichIsA("PVInstance"), modelo, "árbol: FindFirstChildWhichIsA")
	igual(tabla:IsDescendantOf(carpeta), true, "árbol: IsDescendantOf")
	igual(#carpeta:GetDescendants(), 2, "árbol: GetDescendants")
	falla(function()
		carpeta.Parent = tabla
	end, "árbol: no puede colgar de su propio descendiente")
	local junta = Instance.new("WeldConstraint")
	junta.Part0 = tabla
	junta.Parent = modelo
	local copia = modelo:Clone()
	igual(copia.Parent, nil, "Clone: sin padre")
	igual(copia.Tablero == tabla, false, "Clone: piezas nuevas")
	igual(copia.WeldConstraint.Part0, copia.Tablero, "Clone: lo que apunta dentro apunta a la copia")
	local cambios, destruyendo = 0, 0
	tabla.Changed:Connect(function()
		cambios += 1
	end)
	tabla.Destroying:Connect(function()
		destruyendo += 1
	end)
	modelo:Destroy()
	igual(destruyendo, 1, "Destroy: Destroying")
	igual(modelo.Parent, nil, "Destroy: sin padre")
	falla(function()
		modelo.Parent = carpeta
	end, "Destroy: Parent bloqueado")
	tabla.Transparency = 0.5
	igual(cambios, 1, "Destroy: desconecta (solo contó el Parent = nil)")
	igual(Instance.new("Part").Gravedad, nil, "propiedad desconocida y sin poner: nil")
	local p = Instance.new("Part")
	p.Gravedad = 3
	igual(p.Gravedad, 3, "propiedad desconocida: guarda lo que se pone")
end

-- Propiedades y atributos: GetPropertyChangedSignal, Changed y GetAttributeChangedSignal solo al cambiar.
do
	local f = Instance.new("Frame")
	local veces, cuales = 0, {}
	f:GetPropertyChangedSignal("Visible"):Connect(function()
		veces += 1
	end)
	f.Changed:Connect(function(prop)
		table.insert(cuales, prop)
	end)
	f.Visible = true -- ya lo era
	f.Visible = false
	igual(veces, 1, "propiedades: solo salta al cambiar")
	igual(cuales[1], "Visible", "propiedades: Changed con el nombre")
	local jugador = m.jugadorLocal
	local attr = 0
	jugador:GetAttributeChangedSignal("Aguante"):Connect(function()
		attr += 1
	end)
	jugador:SetAttribute("Aguante", 1)
	jugador:SetAttribute("Aguante", 1)
	jugador:SetAttribute("Aguante", 0.5)
	igual(attr, 2, "atributos: solo al cambiar")
	igual(jugador:GetAttribute("Aguante"), 0.5, "atributos: GetAttribute")
	jugador:SetAttribute("Aguante", nil)
	igual(jugador:GetAttributes().Aguante, nil, "atributos: nil los quita")
	falla(function()
		jugador:SetAttribute("Mala", {})
	end, "atributos: una tabla no vale")
	local v = Instance.new("NumberValue")
	local llega = nil
	v.Changed:Connect(function(x)
		llega = x
	end)
	v.Value = 4
	igual(llega, 4, "ValueBase: Changed con el valor")
end

-- Piezas y modelos: CFrame, Position y Orientation coherentes; PivotTo mueve todo el modelo.
do
	local p = Instance.new("Part")
	p.CFrame = CFrame.new(1, 2, 3) * CFrame.Angles(0, math.rad(90), 0)
	igual(p.Position, Vector3.new(1, 2, 3), "pieza: Position del CFrame")
	cerca(p.Orientation.Y, 90, "pieza: Orientation en grados")
	p.Position = Vector3.new(5, 0, 0)
	cerca(p.CFrame.LookVector.X, -1, "pieza: Position no cambia el giro")
	p.Orientation = Vector3.new(0, 0, 0)
	igual(p.CFrame, CFrame.new(5, 0, 0), "pieza: Orientation cambia el CFrame")
	local modelo = Instance.new("Model")
	local a, b = Instance.new("Part"), Instance.new("Part")
	a.CFrame, b.CFrame = CFrame.new(0, 0, 0), CFrame.new(4, 0, 0)
	a.Parent, b.Parent = modelo, modelo
	modelo.PrimaryPart = a
	modelo:PivotTo(CFrame.new(10, 0, 0) * CFrame.Angles(0, math.pi, 0))
	cerca((b.Position - Vector3.new(6, 0, 0)).Magnitude, 0, "modelo: PivotTo mueve y gira las piezas")
	local _, tam = modelo:GetBoundingBox()
	cerca(tam.X, 8, "modelo: GetBoundingBox")
end

-- Reloj y tareas: solo avanzan con mundo.paso.
do
	local reloj = g.os.clock
	local antes = reloj()
	local orden = {}
	task.delay(0.5, function(x)
		table.insert(orden, "delay " .. x)
	end, "a")
	local hilo = task.delay(0.2, function()
		table.insert(orden, "cancelado")
	end)
	task.cancel(hilo)
	local esperado = nil
	task.spawn(function()
		esperado = task.wait(0.3)
		table.insert(orden, "wait")
	end)
	task.defer(function()
		table.insert(orden, "defer")
	end)
	igual(reloj(), antes, "reloj: no avanza solo")
	m.correr(1, 0.1)
	cerca(reloj() - antes, 1, "reloj: avanza con mundo.paso")
	cerca(g.tick() - g.workspace:GetServerTimeNow(), 0, "reloj: tick y GetServerTimeNow juntos")
	igual(table.concat(orden, ","), "defer,wait,delay a", "tareas: defer, wait y delay en orden; cancel no corre")
	cerca(esperado :: number, 0.3, "tareas: task.wait devuelve lo esperado", 0.11)
	local azar1, azar2 = crearMundo().global.Random.new(5), g.Random.new(5)
	igual(azar1:NextNumber(), azar2:NextNumber(), "Random: misma semilla, mismo número")
end

-- RenderStepped en el orden de Roblox: BindToRenderStep por prioridad (la cámara de Roblox en Camera), luego la señal,
-- Stepped y Heartbeat.
do
	local orden = {}
	RunService:BindToRenderStep("Despues", Enum.RenderPriority.Camera.Value + 1, function()
		table.insert(orden, "camara+1")
	end)
	RunService:BindToRenderStep("Antes", Enum.RenderPriority.Input.Value, function()
		table.insert(orden, "entrada")
	end)
	local cs = {}
	for _, n in { "RenderStepped", "Stepped", "Heartbeat" } do
		table.insert(cs, RunService[n]:Connect(function()
			table.insert(orden, n)
		end))
	end
	m.paso()
	igual(table.concat(orden, ","), "entrada,camara+1,RenderStepped,Stepped,Heartbeat", "fotograma: orden")
	RunService:UnbindFromRenderStep("Despues")
	RunService:UnbindFromRenderStep("Antes")
	for _, c in cs do
		c:Disconnect()
	end
end

-- Tweens: interpolan con el reloj falso, Completed al acabar y uno nuevo cancela al viejo.
do
	local f = Instance.new("Frame")
	f.BackgroundTransparency = 0
	local tw = TweenService:Create(f, g.TweenInfo.new(1, Enum.EasingStyle.Linear), { BackgroundTransparency = 1,
		Position = UDim2.fromScale(1, 0) })
	local fin = nil
	tw.Completed:Connect(function(como)
		fin = como
	end)
	tw:Play()
	m.correr(0.5, 0.05)
	cerca(f.BackgroundTransparency, 0.5, "tween: a la mitad", 1e-6)
	cerca(f.Position.X.Scale, 0.5, "tween: UDim2 a la mitad", 1e-6)
	m.correr(0.6, 0.05)
	igual(f.BackgroundTransparency, 1, "tween: llega al final exacto")
	igual(fin, Enum.PlaybackState.Completed, "tween: Completed")
	local viejo = TweenService:Create(f, g.TweenInfo.new(1), { BackgroundTransparency = 0 })
	local nuevo = TweenService:Create(f, g.TweenInfo.new(0.2), { BackgroundTransparency = 0.3 })
	local comoViejo = nil
	viejo.Completed:Connect(function(como)
		comoViejo = como
	end)
	viejo:Play()
	m.paso()
	nuevo:Play()
	igual(comoViejo, Enum.PlaybackState.Cancelled, "tween: el nuevo cancela al viejo")
	m.correr(0.3)
	cerca(f.BackgroundTransparency, 0.3, "tween: manda el nuevo")
	cerca(TweenService:GetValue(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), 0.25, "tween: GetValue")
end

-- Rayos contra una caja girada: CanQuery, filtros, CanCollide y grupos de choque; barridos y solapes.
do
	local w = g.workspace
	local caja = m.caja(CFrame.new(0, 10, 0) * CFrame.Angles(0, math.rad(45), 0), Vector3.new(4, 4, 4))
	local r = w:Raycast(Vector3.new(-10, 10, 0), Vector3.new(20, 0, 0))
	assert(r, "rayo: tenía que tocar la caja")
	igual(r.Instance, caja, "rayo: la caja")
	cerca(r.Distance, 10 - 2 * math.sqrt(2), "rayo: entra por la esquina girada")
	cerca(r.Normal.Y, 0, "rayo: normal de lado")
	assert(r.Normal.X < 0, "rayo: la normal mira hacia el rayo")
	igual(w:Raycast(Vector3.new(-10, 10, 0), Vector3.new(5, 0, 0)), nil, "rayo: corto, no llega")
	igual(w:Raycast(Vector3.new(0, 10, 0), Vector3.new(10, 0, 0)), nil, "rayo: desde dentro no la ve (como Roblox)")
	local filtro = g.RaycastParams.new()
	filtro.FilterDescendantsInstances = { caja }
	igual(w:Raycast(Vector3.new(-10, 10, 0), Vector3.new(20, 0, 0), filtro), nil, "rayo: Exclude")
	filtro.FilterType = Enum.RaycastFilterType.Include
	igual(w:Raycast(Vector3.new(-10, 10, 0), Vector3.new(20, 0, 0), filtro).Instance, caja, "rayo: Include")
	local respeta = g.RaycastParams.new()
	respeta.RespectCanCollide = true
	caja.CanCollide = false
	igual(w:Raycast(Vector3.new(-10, 10, 0), Vector3.new(20, 0, 0), respeta), nil, "rayo: RespectCanCollide")
	igual(w:Raycast(Vector3.new(-10, 10, 0), Vector3.new(20, 0, 0)).Instance, caja, "rayo: sin RespectCanCollide la ve")
	caja.CanCollide = true
	local Fisica = m.servicio("PhysicsService")
	Fisica:RegisterCollisionGroup("Fantasmas")
	Fisica:CollisionGroupSetCollidable("Fantasmas", "Default", false)
	local fantasma = g.RaycastParams.new()
	fantasma.CollisionGroup = "Fantasmas"
	igual(w:Raycast(Vector3.new(-10, 10, 0), Vector3.new(20, 0, 0), fantasma), nil, "rayo: grupo que no choca")
	caja.CanQuery = false
	igual(w:Raycast(Vector3.new(-10, 10, 0), Vector3.new(20, 0, 0)), nil, "rayo: CanQuery = false no la ve")
	caja.CanQuery = true
	local barrido = w:Blockcast(CFrame.new(-10, 10, 0), Vector3.new(1, 1, 1), Vector3.new(20, 0, 0))
	assert(barrido, "Blockcast: tenía que tocar")
	cerca(barrido.Distance, 10 - 2 * math.sqrt(2) - 0.5, "Blockcast: su cara toca la esquina de la caja", 1e-3)
	local bola = w:Spherecast(Vector3.new(0, 20, 0), 1, Vector3.new(0, -20, 0))
	cerca(bola.Distance, 7, "Spherecast: cae sobre la caja")
	igual(#w:GetPartBoundsInBox(CFrame.new(2.5, 10, 0), Vector3.new(1, 1, 1)), 1, "solape: la esquina (2,83) sobresale")
	igual(#w:GetPartBoundsInBox(CFrame.new(2.5, 10, 2.5), Vector3.new(1, 1, 1)), 0, "solape: al lado de la cara girada no")
	igual(#w:GetPartBoundsInRadius(Vector3.new(0, 13, 0), 1.1), 1, "solape: radio")
	caja:Destroy()
	igual(w:Raycast(Vector3.new(-10, 10, 0), Vector3.new(20, 0, 0)), nil, "rayo: destruida ya no está")
end

-- El personaje: anda, se pega al suelo, no atraviesa la pared y la cámara de Roblox va en su cabeza.
do
	local suelo = m.caja(CFrame.new(0, -0.5, 0), Vector3.new(100, 1, 100))
	local pared = m.caja(CFrame.new(0, 3, -10), Vector3.new(20, 6, 1))
	local pj = m.personaje(CFrame.new(0, 3, 0))
	local raiz, hum = pj.HumanoidRootPart, pj.Humanoid
	igual(m.jugadorLocal.Character, pj, "personaje: es el del jugador")
	cerca(pj.RightFoot.Position.Y, 0.1, "personaje: los pies en el suelo")
	cerca(pj.Head.Position.Y, 4.6, "personaje: la cabeza con las juntas")
	m.mirar(0, 0) -- hacia -Z, hacia la pared
	m.andar(Vector3.new(0, 0, -1))
	local roto = false
	m.correr(2, 1 / 60, function()
		roto = roto or m.roto(raiz.CFrame) or m.roto(m.camara.CFrame)
		assert(raiz.Position.Z > -10 + 0.5 + 0.5 - 0.06, `personaje: atraviesa la pared (z = {raiz.Position.Z})`)
		assert(#m.solapes(raiz, { pj }) == 0, "personaje: se mete en algo")
	end)
	igual(roto, false, "personaje: sin NaN")
	cerca(raiz.Position.Z, -9 + 0.05, "personaje: se para en la pared", 0.1)
	cerca(raiz.Position.Y, 3, "personaje: sigue en el suelo")
	m.andar(nil)
	m.paso()
	igual(hum.MoveDirection, Vector3.zero, "personaje: para al soltar")
	cerca((m.camara.CFrame.Position - (raiz.Position + Vector3.new(0, 1.5, 0))).Magnitude, 0, "cámara: en la cabeza", 0.3)
	m.pulsar(Enum.KeyCode.Space)
	m.correr(0.2)
	assert(raiz.Position.Y > 3.5, "personaje: salta")
	m.soltar(Enum.KeyCode.Space)
	m.correr(2)
	cerca(raiz.Position.Y, 3, "personaje: vuelve al suelo")
	igual(hum:GetState(), Enum.HumanoidStateType.Running, "personaje: de pie al caer")
	m.pulsar(Enum.KeyCode.D)
	m.correr(0.5)
	m.soltar(Enum.KeyCode.D)
	cerca(raiz.Position.X, 8, "personaje: D anda a la derecha (16 studs/s)", 0.4)
	suelo:Destroy()
	pared:Destroy()
end

-- Entrada: teclas, ContextActionService y remotes (lo que se manda se guarda y llega al servidor al paso siguiente).
do
	local UIS = m.servicio("UserInputService")
	local tecla = nil
	local c = UIS.InputBegan:Connect(function(input, procesado)
		tecla = if procesado then nil else input.KeyCode
	end)
	m.pulsar(Enum.KeyCode.LeftShift)
	igual(tecla, Enum.KeyCode.LeftShift, "entrada: InputBegan")
	igual(UIS:IsKeyDown(Enum.KeyCode.LeftShift), true, "entrada: IsKeyDown")
	m.soltar(Enum.KeyCode.LeftShift)
	igual(UIS:IsKeyDown(Enum.KeyCode.LeftShift), false, "entrada: soltar")
	c:Disconnect()
	local accion = {}
	m.servicio("ContextActionService"):BindAction("Correr", function(_, estado)
		table.insert(accion, estado.Name)
	end, false, Enum.KeyCode.ButtonL3)
	m.pulsar(Enum.KeyCode.ButtonL3)
	m.soltar(Enum.KeyCode.ButtonL3)
	igual(table.concat(accion, ","), "Begin,End", "entrada: BindAction")
	igual(UIS:GetLastInputType(), Enum.UserInputType.Gamepad1, "entrada: el mando cambia el último tipo")
	local Remotes = m.cargar("src/shared/Remotes")
	igual(Remotes, m.cargar("src/shared/Remotes"), "cargar: cada módulo una sola vez por mundo")
	local quien, que = nil, nil
	Remotes.Correr.OnServerEvent:Connect(function(j, v)
		quien, que = j, v
	end)
	Remotes.Correr:FireServer(true)
	igual(m.enviados("Correr")[1][1], true, "remoto: guarda lo mandado")
	igual(quien, nil, "remoto: no llega en el mismo fotograma")
	m.paso()
	igual(quien, m.jugadorLocal, "remoto: llega al servidor con el jugador")
	igual(que, true, "remoto: con lo mandado")
	local aviso = nil
	Remotes.Aviso.OnClientEvent:Connect(function(t)
		aviso = t
	end)
	m.alCliente("Aviso", "hola")
	igual(aviso, "hola", "remoto: alCliente")
end

-- Etiquetas: GetTagged solo lo que está en el juego, y las señales al entrar y salir.
do
	local CS = m.servicio("CollectionService")
	local entran, salen = 0, 0
	CS:GetInstanceAddedSignal("Debajo"):Connect(function()
		entran += 1
	end)
	CS:GetInstanceRemovedSignal("Debajo"):Connect(function()
		salen += 1
	end)
	local zona = Instance.new("Part")
	zona:AddTag("Debajo")
	igual(#CS:GetTagged("Debajo"), 0, "etiquetas: fuera del juego no cuenta")
	zona.Parent = g.workspace
	igual(#CS:GetTagged("Debajo"), 1, "etiquetas: GetTagged")
	igual(entran, 1, "etiquetas: al entrar")
	zona:Destroy()
	igual(salen, 1, "etiquetas: al salir")
end

-- El cargador: script.Parent, Comun, init.luau y ReplicatedStorage.Shared como en Rojo; falsos por nombre; dos mundos
-- no comparten nada.
do
	local nodo = m.nodo("src/juego/cliente/CuerpoVista")
	assert(nodo, "cargador: el nodo de CuerpoVista")
	igual(nodo.ClassName, "ModuleScript", "cargador: un .luau es ModuleScript")
	igual(nodo.Parent.ClassName, "LocalScript", "cargador: la carpeta con init.client.luau es su LocalScript")
	igual(nodo.Parent.Parent:WaitForChild("Comun"):FindFirstChild("Ui").ClassName, "ModuleScript", "cargador: la carpeta Comun")
	igual(m.servicio("ReplicatedStorage").Shared.Config, m.nodo("src/shared/Config"), "cargador: ReplicatedStorage.Shared")
	local otro = crearMundo()
	local falsoSonido = { falso = true }
	otro.falso("Sonido", falsoSonido)
	local Config1 = m.cargar("src/shared/Config")
	local Config2 = otro.cargar("src/shared/Config")
	igual(Config1 == Config2, false, "cargador: cada mundo con sus módulos")
	local raro = nil
	otro.falso("src/shared/Lang", { t = function()
		raro = "falso"
		return ""
	end })
	otro.cargar("src/comun/cliente/Ui")
	igual(raro, nil, "cargador: un falso solo se usa si lo piden")
	igual(#otro.errores, 0, "cargador: sin errores")
end

-- Errores: en una conexión paran el banco con su traza (mundo.estricto), o se apuntan y sigue.
do
	local suave = crearMundo({ estricto = false })
	local e = suave.global.Instance.new("BindableEvent")
	e.Event:Connect(function()
		error("a propósito")
	end)
	e:Fire()
	igual(#suave.errores, 1, "errores: apuntado")
	assert(string.find(suave.errores[1], "a propósito", 1, true), "errores: con su mensaje")
	local duro = crearMundo()
	local e2 = duro.global.Instance.new("BindableEvent")
	e2.Event:Connect(function()
		error("a propósito")
	end)
	falla(function()
		e2:Fire()
	end, "errores: estricto para el banco")
end

-- La interfaz de verdad: comun/cliente/Ui carga y hace su HUD, un botón que se hunde al pulsar y un aviso que se va.
do
	local Ui = m.cargar("src/comun/cliente/Ui")
	local hud = Ui.hud()
	igual(hud.Parent, m.jugadorLocal.PlayerGui, "Ui: el HUD en el PlayerGui")
	igual(hud.AbsoluteSize, g.Vector2.new(1280, 720), "Ui: HUD a pantalla completa")
	igual(Ui.escala(), 1, "Ui: escala 1 en 1280 × 720")
	local boton = Ui.boton("correr", { Size = UDim2.fromOffset(200, 60), Parent = hud })
	igual(boton.Text, "CORRER", "Ui: botón en mayúsculas")
	igual(boton:FindFirstChildOfClass("UIStroke").Color, Ui.Color.Sangre, "Ui: borde rojo oscuro")
	local escala = boton:FindFirstChildOfClass("UIScale")
	m.servicio("UserInputService") -- (el botón usa MouseButton1Down/Up)
	local senal = boton.MouseButton1Down
	senal:Fire()
	m.correr(0.1)
	cerca(escala.Scale, 0.94, "Ui: se hunde al pulsar")
	m.clic(boton)
	m.correr(0.3)
	cerca(escala.Scale, 1, "Ui: vuelve al soltar", 1e-3)
	Ui.aviso("Hello", 1)
	local aviso = nil
	for _, h in hud:GetChildren() do
		if h:IsA("TextLabel") and h.Text == "Hello" then
			aviso = h
		end
	end
	assert(aviso, "Ui: el aviso está")
	m.correr(3)
	igual(aviso.Parent, nil, "Ui: el aviso se va solo")
	m.movil()
	cerca(Ui.escala(), 0.55, "Ui: en el móvil encoge")
	cerca(Ui.zonaSegura(), 20 / 0.55, "Ui: la zona segura de abajo en píxeles de diseño", 0.01)
	igual(#m.errores, 0, "Ui: sin errores")
end

print(`roblox-falso: {cuentas} comprobaciones.`)
