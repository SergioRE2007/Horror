-- Banco de llevar cosas pesadas en el cliente (15.8, pedido por el usuario: "todo": físicas, al hombro, lanzar y ruido).
-- Ejecutar desde la raíz: lune run tests/bancos/cargar-vista.luau (también lo lanza tests/regressions.luau).
-- Carga con el Roblox de mentira (tests/bancos/_roblox.luau) el juego/cliente/CargarVista de verdad (Sonido, falso) y
-- una pieza como la crea juego/servidor/Cargar (Agarre con su AlignPosition y el Giro), con Lleva = mi UserId. Sin
-- física de piezas sueltas: se mira lo que CargarVista le pide a la física (el AlignPosition y el Giro) cada fotograma:
--   quieto: al hombro donde dice CargarReglas.sitio; nunca NaN.
--   girando de golpe: se queda atrás, se pasa un poco y acaba donde miras.
--   andando: baja a cada paso, sin pasar de Balanceo.Bote.
--   lanzar: mantener clic lo echa atrás; al soltar manda ("Lanzar", carga, dirección) con la carga del tiempo
--   mantenido; un clic suelto no manda nada; lo que no se lanza (el bidón) tampoco.
--   la E: lo baja hasta el suelo en Config.Cargar.Dejar s y entonces lo suelta; entre varios (sin Lleva), de golpe.
--   sonidos: el golpe del remote Pesado suena más fuerte cuanto más fuerte; el arrastre suena mientras Arrastra.
--   el aviso de abajo: dice cómo lanzar solo si se puede.
-- Si algo no se cumple, termina con error.
local crearMundo = require("./_roblox")

local cuentas = 0
local function comprueba(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end

local DT = 1 / 60

local function montar()
	local m = crearMundo()
	local g = m.global
	local Vector3, CFrame, Instance = g.Vector3, g.CFrame, g.Instance
	m.caja(CFrame.new(0, -0.5, 0), Vector3.new(600, 1, 600))
	m.personaje(CFrame.new(0, 3, 0))
	m.mirar(0, 0)
	local Config = m.cargar("src/shared/Config")
	local Reglas = m.cargar("src/shared/CargarReglas")
	local sonidos = {}
	local function nuevoSonido(nombre: string, padre: any)
		local s = Instance.new("Sound")
		s.Name = nombre
		s.SoundId = "rbxassetid://1"
		s.Volume = Config.Sonidos[nombre].Volumen
		s.Parent = padre or m.servicio("SoundService")
		s:Play()
		table.insert(sonidos, s)
		return s
	end
	local Vista = m.cargar("src/juego/cliente/CargarVista", {
		Sonido = {
			hay = function()
				return false
			end,
			en = function(nombre: string, _punto: any, _tono: number?)
				return nuevoSonido(nombre, nil)
			end,
			tocar = function(nombre: string)
				return nuevoSonido(nombre, nil)
			end,
			bucle = function(nombre: string, padre: any)
				local s = nuevoSonido(nombre, padre)
				s.Looped = true
				return s
			end,
		},
	})
	Vista.start()
	local jugador = m.jugadorLocal
	local CS = m.servicio("CollectionService")

	-- Una pieza como la de juego/servidor/Cargar.nuevo + coger (uno solo).
	local function pieza(tipo: string, solo: boolean)
		local t = Config.Pesados[tipo].Tam
		local p = Instance.new("Part")
		p.Name = tipo
		p.Size = Vector3.new(t[1], t[2], t[3])
		p.Anchored = false
		p:SetAttribute("Tipo", tipo)
		p:SetAttribute("Peso", Config.Pesados[tipo].Peso)
		local giro = Instance.new("AlignOrientation")
		giro.Name = "Giro"
		giro.Parent = p
		local punto = Instance.new("Attachment")
		punto.Name = "Agarre"
		punto.Parent = p
		local empuje = Instance.new("AlignPosition")
		empuje.Parent = punto
		local raiz = jugador.Character.HumanoidRootPart
		local sitio = Reglas.sitio(tipo, p.Size, raiz.CFrame)
		p.CFrame = sitio
		empuje.Position = sitio.Position
		giro.CFrame = sitio.Rotation
		if solo then
			p:SetAttribute("Lleva", jugador.UserId)
		end
		p.Parent = m.workspace
		CS:AddTag(p, "Pesado")
		jugador:SetAttribute("Cargando", tipo)
		m.paso(DT)
		return p, empuje, giro
	end
	return {
		m = m, g = g, Config = Config, Reglas = Reglas, Vista = Vista, jugador = jugador, pieza = pieza,
		sonidos = sonidos, Vector3 = Vector3, CFrame = CFrame,
	}
end

local function finito(v: any): boolean
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and math.abs(v.X) < 1e5 and math.abs(v.Y) < 1e5 and math.abs(v.Z) < 1e5
end

-- 1-3. Quieto, girando y andando con un tronco al hombro.
do
	local b = montar()
	local m, C = b.m, b.Config.Cargar
	local _, empuje, giro = b.pieza("Tronco", true)
	local raiz = b.jugador.Character.HumanoidRootPart
	m.correr(0.5, DT, function()
		comprueba(finito(empuje.Position) and finito(giro.CFrame.XVector), "quieto: sin NaN")
	end)
	local debe = b.Reglas.sitio("Tronco", b.Vector3.new(6, 1.4, 1.4), raiz.CFrame)
	comprueba((empuje.Position - debe.Position).Magnitude < 0.15, `quieto: al hombro ({(empuje.Position - debe.Position).Magnitude})`)
	comprueba(giro.CFrame.XVector:Dot(debe.XVector) > 0.99, "quieto: a lo largo")
	local l = raiz.CFrame:PointToObjectSpace(empuje.Position)
	comprueba(l.X > 0.6, "quieto: a la derecha")

	-- Gira 90° de golpe (a la izquierda).
	m.mirar(math.rad(90), 0)
	local atrasMax, pasado = 0, 0
	m.correr(1.5, DT, function(n)
		local f = b.Reglas.frente(raiz.CFrame)
		local eje = giro.CFrame.XVector * b.Vector3.new(1, 0, 1)
		comprueba(finito(eje), "girando: sin NaN")
		if eje.Magnitude > 0.01 then
			local a = math.atan2(-eje.Unit.X, -eje.Unit.Z)
			local d = b.Reglas.diferencia(a, math.atan2(-f.X, -f.Z))
			if n < 10 then
				atrasMax = math.max(atrasMax, math.abs(d))
			elseif d < 0 then
				pasado = math.max(pasado, -d)
			end
		end
	end)
	local f = b.Reglas.frente(raiz.CFrame)
	comprueba(f.X < -0.95, `la raíz ha girado (frente {f})`)
	comprueba(atrasMax > math.rad(15), `al girar de golpe se queda atrás ({math.deg(atrasMax)}°)`)
	comprueba(giro.CFrame.XVector:Dot(b.Reglas.sitio("Tronco", b.Vector3.new(6, 1.4, 1.4), raiz.CFrame).XVector) > 0.995,
		"y acaba donde miras")

	-- Anda hacia delante: baja a cada paso.
	local yQuieto = empuje.Position.Y
	local minimo, maximo = math.huge, -math.huge
	m.andar(f)
	m.correr(2, DT, function()
		comprueba(finito(empuje.Position), "andando: sin NaN")
		local y = empuje.Position.Y - (raiz.Position.Y - 3) -- desde los pies
		minimo, maximo = math.min(minimo, y), math.max(maximo, y)
	end)
	m.andar(nil)
	local bote = maximo - minimo
	comprueba(bote > C.Balanceo.Bote * 0.4, `andando baja a cada paso ({bote})`)
	comprueba(bote <= C.Balanceo.Bote + 0.05, `sin pasarse ({bote})`)
	comprueba(math.abs(maximo - (yQuieto - 0)) < 3, "a la altura del hombro")
end

-- 4-5. Lanzar.
do
	local b = montar()
	local m, C = b.m, b.Config.Cargar
	local _, empuje = b.pieza("Tronco", true)
	local raiz = b.jugador.Character.HumanoidRootPart
	local antes = empuje.Position
	local f = b.Reglas.frente(raiz.CFrame)
	m.pulsar(b.g.Enum.UserInputType.MouseButton1)
	m.correr(1, DT)
	comprueba(b.Vista.carga() == 1, "cargado del todo a C.Lanzar.Carga s")
	local atras = (empuje.Position - antes):Dot(f)
	comprueba(atras < -C.Lanzar.Atras * 0.8, `al cargar lo echa atrás ({atras})`)
	m.soltar(b.g.Enum.UserInputType.MouseButton1)
	local env = m.enviados("Cargar")
	comprueba(#env == 1 and env[1][1] == "Lanzar", "al soltar, lo lanza")
	comprueba(env[1] and env[1][2] == 1, "con la carga entera")
	comprueba(env[1] and b.g.typeof(env[1][3]) == "Vector3" and finito(env[1][3]), "hacia donde miro")
	comprueba(b.Vista.lanzado() > 0, "las manos saben que ha lanzado")
	b.jugador:SetAttribute("Cargando", nil) -- el servidor lo suelta
	m.paso(DT)

	-- Un clic suelto no lanza.
	local _, empuje2 = b.pieza("Tablon", true)
	m.pulsar(b.g.Enum.UserInputType.MouseButton1)
	m.paso(DT)
	m.soltar(b.g.Enum.UserInputType.MouseButton1)
	comprueba(#m.enviados("Cargar") == 1, "un clic suelto no lanza")
	comprueba(finito(empuje2.Position), "tablón: sin NaN")
	-- Media carga.
	m.pulsar(b.g.Enum.UserInputType.MouseButton1)
	m.correr(C.Lanzar.Carga / 2, DT)
	m.soltar(b.g.Enum.UserInputType.MouseButton1)
	local env2 = m.enviados("Cargar")
	comprueba(#env2 == 2 and math.abs(env2[2][2] - 0.5) < 0.06, `media carga ({env2[2] and env2[2][2]})`)
	b.jugador:SetAttribute("Cargando", nil)
	m.paso(DT)

	-- El bidón no se lanza.
	b.pieza("Bidon", true)
	m.pulsar(b.g.Enum.UserInputType.MouseButton1)
	m.correr(1, DT)
	m.soltar(b.g.Enum.UserInputType.MouseButton1)
	comprueba(#m.enviados("Cargar") == 2, "el bidón no se lanza")
end

-- 6. Dejar con la E.
do
	local b = montar()
	local m, C = b.m, b.Config.Cargar
	local p, empuje = b.pieza("Tronco", true)
	m.pulsar(b.g.Enum.KeyCode.E)
	m.soltar(b.g.Enum.KeyCode.E)
	comprueba(#m.enviados("Cargar") == 0, "la E no lo suelta de golpe")
	m.correr(C.Dejar * 0.5, DT)
	comprueba(#m.enviados("Cargar") == 0, "a medio bajar, aún en las manos")
	m.correr(C.Dejar * 0.6, DT)
	local env = m.enviados("Cargar")
	comprueba(#env == 1 and env[1].n == 0, "abajo del todo lo suelta (sin nada más)")
	comprueba(math.abs(empuje.Position.Y - (p.Size.Y / 2 + 0.05)) < 0.1, `en el suelo ({empuje.Position.Y})`)
	b.jugador:SetAttribute("Cargando", nil)
	p:SetAttribute("Lleva", nil) -- el servidor lo suelta
	m.paso(DT)
	-- Entre varios (sin Lleva): de golpe.
	b.pieza("Motor", false)
	m.pulsar(b.g.Enum.KeyCode.E)
	m.soltar(b.g.Enum.KeyCode.E)
	comprueba(#m.enviados("Cargar") == 2, "entre varios, la E lo suelta de golpe")
end

-- 7. Sonidos y aviso.
do
	local b = montar()
	local m = b.m
	local p = b.pieza("Motor", false)
	local raiz = b.jugador.Character.HumanoidRootPart
	m.alCliente("Pesado", "Golpe", raiz.Position + b.Vector3.new(3, 0, 0), 1, "Tronco")
	m.alCliente("Pesado", "Golpe", raiz.Position + b.Vector3.new(3, 0, 0), 0, "Motor")
	comprueba(#b.sonidos == 2, "los golpes suenan")
	comprueba(b.sonidos[1].Name == "GolpeMadera" and b.sonidos[2].Name == "GolpeMetal", "cada uno con el suyo")
	comprueba(b.sonidos[1].Volume > b.sonidos[2].Volume, "más fuerte, más alto")
	m.alCliente("Pesado", "Golpe", raiz.Position + b.Vector3.new(500, 0, 0), 1, "Tronco")
	comprueba(#b.sonidos == 2, "muy lejos no suena")
	m.alCliente("Pesado", "Golpe", "basura", 0 / 0, 3)
	comprueba(#b.sonidos == 2, "lo raro no suena ni rompe")
	p:SetAttribute("Arrastra", true)
	m.paso(DT)
	comprueba(#b.sonidos == 3 and b.sonidos[3].Name == "Arrastre" and b.sonidos[3].Parent == p, "arrastrando suena")
	p:SetAttribute("Arrastra", nil)
	m.paso(DT)
	comprueba(b.sonidos[3].Parent == nil, "al parar, se calla")
	-- El aviso de abajo.
	local hud = b.jugador.PlayerGui
	local texto = ""
	for _, d in hud:GetDescendants() do
		if d:IsA("TextLabel") and string.find(d.Text, "%[E%]") then
			texto = d.Text
		end
	end
	comprueba(not string.find(texto, "THROW"), `con el motor no dice lanzar ({texto})`)
	b.jugador:SetAttribute("Cargando", nil)
	m.paso(DT)
	b.pieza("Tronco", true)
	for _, d in hud:GetDescendants() do
		if d:IsA("TextLabel") and string.find(d.Text, "%[E%]") then
			texto = d.Text
		end
	end
	comprueba(string.find(texto, "THROW") ~= nil, `con el tronco dice cómo lanzar ({texto})`)
end

print(`Cargar en el cliente: todo bien ({cuentas} comprobaciones).`)
