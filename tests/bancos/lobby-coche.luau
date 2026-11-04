-- Banco del coche que llega al lobby (14.9.3, pedido por el usuario: el de verdad reaparecía de golpe al quedar libre;
-- y bancos que carguen el módulo de verdad y miren cada fotograma). Ejecutar desde la raíz:
-- lune run tests/bancos/lobby-coche.luau (también lo lanza tests/regressions.luau).
-- Con el Roblox de mentira (tests/bancos/_roblox.luau) y lobby.project.json: los cuatro coches de verdad
-- (lobby/servidor/GasolineraCoches) y lobby/cliente/SalidaVista, LlegadaVista y CocheCopia de verdad. Lo demás de la
-- gasolinera, cajas con sus medidas (GasolineraFuera y Gasolinera): el suelo (cara de arriba en 0,2), las islas con
-- los surtidores, los pilares y la marquesina, el cartel alto, la tienda, el quitamiedos y las farolas.
-- Mira fotograma a fotograma, para cada coche: sin NaN; la copia no se mete en el suelo, la gasolinera ni los otros
-- coches aparcados; aparece entre la niebla y hasta los últimos CERCA s no llega a las plazas (lo que da por hecho
-- Coches, en el servidor); el de verdad, escondido y sin chocar todo el rato; al acabar la copia está justo donde el
-- de verdad, se borra y vuelve a verse el de verdad. Y: la salida que se pasa a la llegada sin que se vea el de verdad
-- ni un fotograma (y la copia que sale sigue hasta la niebla); entrar a medias (la copia, donde la de quien lo vio
-- desde el principio); una Salida retrasada (quieta hasta su hora); Rendimiento (sin ruedas que ruedan, limpias ni
-- humo); un fallo a medias y que el servidor quite Llegada (todo vuelve). En el servidor (lobby/servidor/Coches de
-- verdad, con Viaje falso): Llegada al vaciarse tras el viaje, nadie se sube hasta entonces, por el carril no van dos a
-- la vez (la Salida de otro y la Llegada de otro esperan) y a la hora queda libre. Y que los números de Coches cuadran
-- con los de LlegadaVista.
local fs = require("@lune/fs")
local crearMundo = require("./_roblox")

local cuentas = 0
local function comprobar(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end

local DT = 1 / 60
local SUELO = 0.2 -- la cara de arriba del asfalto y de la explanada
local PLAZAS = 47 -- |z| de la explanada (40) más medio coche: más allá, el que llega aún no está delante de las plazas

type Caja = { cf: any, h: any, nombre: string, x1: number, x2: number, y1: number, y2: number, z1: number, z2: number }

-- La caja alineada con los ejes de una pieza girada.
local function aabb(cf: any, tam: any): (number, number, number, number, number, number)
	local h = tam / 2
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	local ex = math.abs(r.X) * h.X + math.abs(u.X) * h.Y + math.abs(l.X) * h.Z
	local ey = math.abs(r.Y) * h.X + math.abs(u.Y) * h.Y + math.abs(l.Y) * h.Z
	local ez = math.abs(r.Z) * h.X + math.abs(u.Z) * h.Y + math.abs(l.Z) * h.Z
	local p = cf.Position
	return p.X - ex, p.X + ex, p.Y - ey, p.Y + ey, p.Z - ez, p.Z + ez
end

-- La de una pieza (los cilindros, como cilindros: una rueda que rueda no baja del suelo).
local function aabbPieza(p: any): (number, number, number, number, number, number)
	if p.Shape ~= nil and p.Shape.Name == "Cylinder" then
		local a, h, r = p.CFrame.RightVector, p.Size.X / 2, math.min(p.Size.Y, p.Size.Z) / 2
		local function e(c: number): number
			return math.abs(c) * h + r * math.sqrt(math.max(0, 1 - c * c))
		end
		local q = p.Position
		return q.X - e(a.X), q.X + e(a.X), q.Y - e(a.Y), q.Y + e(a.Y), q.Z - e(a.Z), q.Z + e(a.Z)
	end
	return aabb(p.CFrame, p.Size)
end

-- ¿Se meten dos cajas giradas una en la otra más de `margen`? (ejes separadores)
local function solapan(a: any, ha: any, b: any, hb: any, margen: number): boolean
	local ea = { a.RightVector, a.UpVector, a.LookVector }
	local eb = { b.RightVector, b.UpVector, b.LookVector }
	local ma, mb = { ha.X, ha.Y, ha.Z }, { hb.X, hb.Y, hb.Z }
	local d = b.Position - a.Position
	local ejes = {}
	for i = 1, 3 do
		table.insert(ejes, ea[i])
		table.insert(ejes, eb[i])
		for j = 1, 3 do
			local c = ea[i]:Cross(eb[j])
			if c.Magnitude > 1e-6 then
				table.insert(ejes, c.Unit)
			end
		end
	end
	for _, e in ejes do
		local ra, rb = 0, 0
		for i = 1, 3 do
			ra += math.abs(ea[i]:Dot(e)) * ma[i]
			rb += math.abs(eb[i]:Dot(e)) * mb[i]
		end
		if math.abs(d:Dot(e)) > ra + rb - margen then
			return false
		end
	end
	return true
end

-- Un mundo nuevo con la gasolinera en cajas, los cuatro coches de verdad y los módulos del cliente.
local function montar(op: { rendimiento: boolean?, falsos: { [string]: any }?, antes: ((any, any) -> ())? }?)
	local o = op or {}
	local m = crearMundo({ proyecto = "lobby.project.json" })
	local g = m.global
	-- Vector3.FromNormalId (CocheCopia.hacerHumo) no está en @lune/roblox.
	local V3 = g.Vector3
	local caras = { Right = V3.new(1, 0, 0), Left = V3.new(-1, 0, 0), Top = V3.new(0, 1, 0), Bottom = V3.new(0, -1, 0),
		Back = V3.new(0, 0, 1), Front = V3.new(0, 0, -1) }
	g.Vector3 = setmetatable({ FromNormalId = function(n)
		return caras[n.Name]
	end }, { __index = V3 })
	local Vector3, CFrame = V3, g.CFrame
	if o.rendimiento then
		m.jugadorLocal:SetAttribute("Rendimiento", true)
	end
	local fijas: { Caja } = {}
	local function solida(cf: any, tam: any, nombre: string)
		local p = m.caja(cf, tam, { Name = nombre })
		local x1, x2, y1, y2, z1, z2 = aabb(cf, tam)
		table.insert(fijas, { cf = cf, h = tam / 2, nombre = nombre, x1 = x1, x2 = x2, y1 = y1, y2 = y2, z1 = z1, z2 = z2 })
		return p
	end
	local suelo = m.caja(CFrame.new(0, SUELO - 0.5, 0), Vector3.new(1000, 1, 1000), { Name = "Suelo" })
	-- GasolineraFuera: islas (centradas en x = 32, z = ±5), surtidores encima, pilares en sus puntas, la marquesina
	-- (x 22..42, z -13..13, de 12,4 a 13,6) y el cartel alto en (23,5, -45) girado 45°.
	for _, z in { -5, 5 } do
		solida(CFrame.new(32, SUELO + 0.225, z), Vector3.new(9.8, 0.55, 3.2), "Isla")
		solida(CFrame.new(32, 0.7 + 1.85, z), Vector3.new(2.6, 3, 1.35), "Surtidor")
		solida(CFrame.new(32, 0.7 + 4.1, z), Vector3.new(2.7, 1.5, 1.5), "Surtidor")
		for _, dx in { -4.9, 4.9 } do
			solida(CFrame.new(32 + dx, 0.78 + 5.81, z), Vector3.new(1, 11.57, 1), "Pilar")
		end
	end
	solida(CFrame.new(32, 13, 0), Vector3.new(20, 1.2, 26), "Marquesina")
	local cartel = CFrame.new(23.5, 0, -45) * CFrame.Angles(0, math.rad(45), 0)
	for _, u in { -2.5, 2.5 } do
		solida(cartel * CFrame.new(u, 0.25, 0), Vector3.new(1.6, 0.9, 1.6), "Zapata")
		solida(cartel * CFrame.new(u, 8.4, 0), Vector3.new(0.8, 15.4, 0.8), "PosteCartel")
	end
	solida(cartel * CFrame.new(0, 14, 0), Vector3.new(12, 5, 1), "Cartel")
	-- La tienda (x 52..70, z -14..14) y su acera; Gasolinera: el quitamiedos del este (x 8,8..9,25, z 93..139) y las
	-- farolas (zócalo y pie).
	solida(CFrame.new(61, 6, 0), Vector3.new(18, 12, 28), "Tienda")
	solida(CFrame.new(50.3, 0.35, 0), Vector3.new(3.4, 0.3, 29.6), "Acera")
	solida(CFrame.new(9.0, 1.2, 116), Vector3.new(0.5, 1.2, 46), "Quitamiedos")
	for _, f in { { -9, -54 }, { -9, 52 }, { 9, -122 } } do
		solida(CFrame.new(f[1], SUELO + 0.3, f[2]), Vector3.new(1.3, 0.9, 1.3), "Zocalo")
		solida(CFrame.new(f[1], SUELO + 4.45, f[2]), Vector3.new(0.7, 7.4, 0.7), "Farola")
	end

	local carpeta = g.Instance.new("Folder")
	carpeta.Name = "Coches"
	carpeta.Parent = g.workspace
	m.cargar("src/lobby/servidor/GasolineraCoches").construir(carpeta)
	if o.antes then
		o.antes(m, carpeta)
	end
	local CocheCopia = m.cargar("src/lobby/cliente/CocheCopia")
	local falsos = o.falsos and o.falsos(CocheCopia)
	local SalidaVista = m.cargar("src/lobby/cliente/SalidaVista", falsos)
	local LlegadaVista = m.cargar("src/lobby/cliente/LlegadaVista", falsos)
	SalidaVista.start()
	LlegadaVista.start()
	return {
		m = m,
		g = g,
		carpeta = carpeta,
		suelo = suelo,
		fijas = fijas,
		CocheCopia = CocheCopia,
		LlegadaVista = LlegadaVista,
		ahora = function()
			return g.workspace:GetServerTimeNow()
		end,
	}
end

local function copias(w: any): { any }
	local f = w.g.workspace:FindFirstChild("CochesSaliendo")
	return if f then f:GetChildren() else {}
end

local function piezas(modelo: any): { any }
	local l = {}
	for _, d in modelo:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(l, d)
		end
	end
	return l
end

-- Lo que choca de los otros coches (los de verdad, aparcados).
local function obstaculos(w: any, salvo: any): { Caja }
	local l = table.clone(w.fijas)
	for _, otro in w.carpeta:GetChildren() do
		if otro ~= salvo then
			for _, p in piezas(otro) do
				if p.CanCollide then
					local x1, x2, y1, y2, z1, z2 = aabb(p.CFrame, p.Size)
					table.insert(l, { cf = p.CFrame, h = p.Size / 2, nombre = `{otro.Name}.{p.Name}`, x1 = x1, x2 = x2, y1 = y1,
						y2 = y2, z1 = z1, z2 = z2 })
				end
			end
		end
	end
	return l
end

-- Mira la copia en este fotograma: NaN, suelo y que no se meta en nada. Devuelve su carrocería.
local function mirarCopia(w: any, copia: any, cajas: { Caja }, etiqueta: string): any
	local m = w.m
	local lista = piezas(copia)
	local X1, X2, Y1, Y2, Z1, Z2 = math.huge, -math.huge, math.huge, -math.huge, math.huge, -math.huge
	local datos = {}
	for _, p in lista do
		comprobar(not m.roto(p.CFrame), `{etiqueta}: NaN en {p.Name}`)
		local x1, x2, y1, y2, z1, z2 = aabbPieza(p)
		comprobar(y1 >= SUELO - 0.02, `{etiqueta}: {p.Name} se mete en el suelo ({y1})`)
		X1, X2, Y1, Y2, Z1, Z2 = math.min(X1, x1), math.max(X2, x2), math.min(Y1, y1), math.max(Y2, y2), math.min(Z1, z1),
			math.max(Z2, z2)
		table.insert(datos, { p = p, x1 = x1, x2 = x2, y1 = y1, y2 = y2, z1 = z1, z2 = z2 })
	end
	local M = 0.03 -- lo que se puede meter (redondeos)
	for _, c in cajas do
		if c.x1 < X2 - M and c.x2 > X1 + M and c.y1 < Y2 - M and c.y2 > Y1 + M and c.z1 < Z2 - M and c.z2 > Z1 + M then
			for _, d in datos do
				if c.x1 < d.x2 - M and c.x2 > d.x1 + M and c.y1 < d.y2 - M and c.y2 > d.y1 + M and c.z1 < d.z2 - M
					and c.z2 > d.z1 + M then
					comprobar(not solapan(d.p.CFrame, d.p.Size / 2, c.cf, c.h, M),
						`{etiqueta}: {d.p.Name} se mete en {c.nombre} en {d.p.Position}`)
				end
			end
		end
	end
	return copia:FindFirstChild("Carroceria") or copia.PrimaryPart
end

-- Lo que se ve del de verdad: escondido (true) o como siempre (false).
local function escondido(modelo: any): boolean
	return modelo.Carroceria.LocalTransparencyModifier == 1 and modelo:GetAttribute("SaliendoLocal") == true
		and modelo.Carroceria.CanCollide == false
end

local function visible(modelo: any): boolean
	for _, p in piezas(modelo) do
		if p.LocalTransparencyModifier ~= 0 then
			return false
		end
	end
	return modelo.Carroceria.CanCollide == true and modelo:GetAttribute("SaliendoLocal") == nil
end

-- La copia, pieza a pieza, justo donde el de verdad (la pieza del de verdad con el mismo nombre más cerca).
local function igualQueElDeVerdad(copia: any, modelo: any, etiqueta: string)
	local deVerdad = {}
	for _, p in piezas(modelo) do
		local l = deVerdad[p.Name] or {}
		deVerdad[p.Name] = l
		table.insert(l, p)
	end
	for _, p in piezas(copia) do
		local mejor, cerca = nil, math.huge
		for _, q in deVerdad[p.Name] or {} do
			local d = (q.Position - p.Position).Magnitude
			if d < cerca then
				mejor, cerca = q, d
			end
		end
		comprobar(mejor ~= nil, `{etiqueta}: {p.Name} no está en el de verdad`)
		local a, b = { p.CFrame:GetComponents() }, { mejor.CFrame:GetComponents() }
		local peor = 0
		for i = 1, 12 do
			peor = math.max(peor, math.abs(a[i] - b[i]))
		end
		comprobar(peor < 1e-3, `{etiqueta}: {p.Name} acaba a {peor} de su sitio`)
	end
end

local LLEGADA_DURA, LLEGADA_CERCA

------------------------------------------------------------------------------------------------------------------------
-- 1. Cada coche llega solo, desde el principio: fotograma a fotograma.
local referencia: { [number]: { any } } = {} -- el marco de la copia en cada fotograma, por coche
for n = 1, 4 do
	local w = montar()
	local LV = w.LlegadaVista
	LLEGADA_DURA, LLEGADA_CERCA = LV.DURA, LV.CERCA
	local modelo = w.carpeta[`Coche{n}`]
	local hora = w.ahora() + LV.DURA
	modelo:SetAttribute("Llegada", hora)
	w.m.paso(DT)
	local cajas = obstaculos(w, modelo)
	local marcos = {}
	referencia[n] = marcos
	local primera, ultima = nil, nil
	local zMin, atras = math.huge, false
	local antes = nil
	local farosVistos, acabada = false, false
	while w.ahora() < hora - DT / 2 do
		local etiqueta = `Coche{n} a {string.format("%.2f", w.ahora() - (hora - LV.DURA))} s`
		comprobar(escondido(modelo), `{etiqueta}: el de verdad se ve`)
		local lista = copias(w)
		comprobar(#lista == 1, `{etiqueta}: {#lista} copias`)
		local carro = mirarCopia(w, lista[1], cajas, etiqueta)
		local pos = carro.Position
		primera = primera or pos
		ultima = carro.CFrame
		table.insert(marcos, carro.CFrame)
		zMin = math.min(zMin, pos.Z)
		if antes and pos.Z > antes.Z + 1e-4 then
			atras = true -- entra marcha atrás
		end
		if antes then
			comprobar((pos - antes).Magnitude < 40 * DT, `{etiqueta}: salta {(pos - antes).Magnitude}`)
		end
		antes = pos
		if hora - w.ahora() > LV.CERCA then
			comprobar(pos.Z > PLAZAS, `{etiqueta}: antes de los últimos {LV.CERCA} s ya está en las plazas (z {pos.Z})`)
		end
		local haz = lista[1]:FindFirstChild("Haz", true)
		farosVistos = farosVistos or (haz and haz.Enabled)
		if hora - w.ahora() < 1.5 * DT then
			-- El último fotograma con copia: justo en su sitio y con las luces apagadas.
			igualQueElDeVerdad(lista[1], modelo, `Coche{n}`)
			comprobar(not haz.Enabled, `Coche{n}: acaba con los faros encendidos`)
			acabada = true
		end
		w.m.paso(DT)
	end
	comprobar(primera.Z > 200, `Coche{n}: aparece a z {primera.Z}, no entre la niebla`)
	comprobar(math.abs(primera.X - 3.5) < 0.5, `Coche{n}: no viene por el carril (x {primera.X})`)
	comprobar(atras, `Coche{n}: no entra marcha atrás`)
	comprobar(zMin < modelo.Carroceria.Position.Z - 10, `Coche{n}: no se pasa de su plaza antes de entrar`)
	comprobar(farosVistos, `Coche{n}: sin faros`)
	comprobar(acabada, `Coche{n}: la copia se ha ido antes de la hora`)
	comprobar((ultima.Position - modelo.Carroceria.Position).Magnitude < 1e-3, `Coche{n}: no acaba en su plaza`)
	comprobar(#copias(w) == 0, `Coche{n}: la copia sigue tras la hora`)
	comprobar(visible(modelo), `Coche{n}: el de verdad no vuelve a verse`)
	for _, otro in w.carpeta:GetChildren() do
		comprobar(visible(otro), `Coche{n}: {otro.Name} no se ve`)
	end
	comprobar(#w.m.errores == 0 and #w.m.avisos == 0, `Coche{n}: errores o avisos: {w.m.errores[1] or w.m.avisos[1]}`)
	print(`Coche{n}: llega desde z {string.format("%.0f", primera.Z)}, se pasa hasta {string.format("%.1f", zMin)}`)
end

------------------------------------------------------------------------------------------------------------------------
-- 2. El coche 2 se va (con marcha atrás para salir) y, al vaciarse, el servidor pone Llegada y quita Salida en el
-- mismo fotograma (como Coches): el de verdad no se ve en ningún momento y la copia que sale sigue hasta la niebla.
do
	local w = montar()
	local modelo = w.carpeta.Coche2
	-- Con gente dentro, GasolineraVista le enciende las luces: al volver, apagadas (está vacío).
	for _, d in modelo:GetDescendants() do
		if d:IsA("Light") then
			d.Enabled = true
		end
	end
	local salida = w.ahora() + 7
	modelo:SetAttribute("Salida", salida)
	w.m.paso(DT)
	local fueraEn, vista = nil, false
	local llegada = nil
	local hasta = salida + 30
	while w.ahora() < hasta do
		if not llegada and w.ahora() >= salida + 2 then
			llegada = w.ahora() + 2 + w.LlegadaVista.DURA
			modelo:SetAttribute("Llegada", llegada)
			modelo:SetAttribute("Salida", nil)
		end
		if llegada and w.ahora() >= llegada then
			break
		end
		vista = vista or not escondido(modelo)
		local lista = copias(w)
		for _, c in lista do
			if c:FindFirstChild("Carroceria").Position.Z < -380 then
				fueraEn = fueraEn or w.ahora()
			end
		end
		w.m.paso(DT)
	end
	comprobar(not vista, "salida y llegada: el de verdad se ve entre las dos")
	comprobar(fueraEn ~= nil and fueraEn > salida + 2, "salida y llegada: la copia que sale no llega a la niebla")
	w.m.paso(DT)
	comprobar(visible(modelo) and #copias(w) == 0, "salida y llegada: no vuelve el de verdad")
	for _, d in modelo:GetDescendants() do
		comprobar(not d:IsA("Light") or not d.Enabled, `salida y llegada: vuelve con {d.Parent.Name} encendido`)
	end
	comprobar(#w.m.errores == 0 and #w.m.avisos == 0, `salida y llegada: {w.m.errores[1] or w.m.avisos[1]}`)
end

-- Que la que sale ha dejado atrás las plazas a los SALE_CERCA s de arrancar (lo que da por hecho Coches).
local fuente = fs.readFile("src/lobby/servidor/Coches.luau")
local SALE_CERCA = tonumber(string.match(fuente, "\nlocal SALE_CERCA = ([%d%.]+)"))
comprobar(SALE_CERCA ~= nil, "Coches: sin SALE_CERCA")
for n = 1, 4 do
	local w = montar()
	local modelo = w.carpeta[`Coche{n}`]
	local salida = w.ahora() + 7
	modelo:SetAttribute("Salida", salida)
	w.m.correr(SALE_CERCA :: number, DT)
	local copia = copias(w)[1]
	local z = copia:FindFirstChild("Carroceria").Position.Z
	comprobar(z < -PLAZAS - 20, `Coche{n}: a los {SALE_CERCA} s de arrancar aún está en las plazas (z {z})`)
end

------------------------------------------------------------------------------------------------------------------------
-- 3. Entrar a medias: la copia va donde la de quien lo ha visto desde el principio.
do
	local A = 10
	local w = montar({ antes = function(m, carpeta)
		carpeta.Coche3:SetAttribute("Llegada", m.global.workspace:GetServerTimeNow() + LLEGADA_DURA - A)
	end })
	w.m.paso(DT)
	local marcos = referencia[3]
	for k = 1, 120 do
		local copia = copias(w)[1]
		comprobar(copia ~= nil, "a medias: sin copia")
		local ref = marcos[math.floor(A / DT + 0.5) + k]
		local dist = (copia.Carroceria.Position - ref.Position).Magnitude
		comprobar(dist < 0.05, `a medias: la copia va a {dist} de donde la ven los demás`)
		w.m.paso(DT)
	end
	comprobar(escondido(w.carpeta.Coche3), "a medias: el de verdad se ve")
end

------------------------------------------------------------------------------------------------------------------------
-- 4. Rendimiento: lo mismo, sin ruedas que ruedan, limpias ni humo; y acaba igual.
do
	local w = montar({ rendimiento = true })
	local modelo = w.carpeta.Coche4
	local hora = w.ahora() + w.LlegadaVista.DURA
	modelo:SetAttribute("Llegada", hora)
	w.m.paso(DT)
	local cajas = obstaculos(w, modelo)
	while w.ahora() < hora - DT / 2 do
		local copia = copias(w)[1]
		local carro = mirarCopia(w, copia, cajas, "Rendimiento")
		for _, p in piezas(copia) do
			if p.Name == "Rueda" or string.sub(p.Name, 1, 6) == "Limpia" then
				local rel = carro.CFrame:ToObjectSpace(p.CFrame)
				local a = { rel:GetComponents() }
				local recto = math.abs(a[4] - 1) < 1e-3 and math.abs(a[8] - 1) < 1e-3 and math.abs(a[12] - 1) < 1e-3
				local cilindro = math.abs(a[6] - 1) < 1e-3 or math.abs(a[6] + 1) < 1e-3 or recto
				comprobar(recto or cilindro or string.sub(p.Name, 1, 6) == "Limpia", `Rendimiento: {p.Name} gira`)
			end
			if p:IsA("BasePart") then
				for _, e in p:GetDescendants() do
					if e:IsA("ParticleEmitter") then
						comprobar(e.Rate == 0, "Rendimiento: echa humo")
					end
				end
			end
		end
		if hora - w.ahora() < 1.5 * DT then
			igualQueElDeVerdad(copia, modelo, "Rendimiento")
		end
		w.m.paso(DT)
	end
	comprobar(visible(modelo) and #copias(w) == 0, "Rendimiento: no vuelve el de verdad")
end

------------------------------------------------------------------------------------------------------------------------
-- 5. Un fallo a medias (CocheCopia.mover rompe) y el servidor que quita Llegada antes de hora: todo vuelve.
do
	local romper = false
	local w = montar({ falsos = function(real)
		return { CocheCopia = setmetatable({ mover = function(...)
			if romper then
				error("roto a propósito")
			end
			return real.mover(...)
		end }, { __index = real }) }
	end })
	w.m.estricto = false
	local modelo = w.carpeta.Coche2
	modelo:SetAttribute("Llegada", w.ahora() + w.LlegadaVista.DURA)
	w.m.correr(8, DT)
	comprobar(escondido(modelo) and #copias(w) == 1, "fallo: no ha empezado")
	romper = true
	w.m.paso(DT)
	comprobar(visible(modelo) and #copias(w) == 0, "fallo: no se devuelve todo")
	comprobar(#w.m.avisos > 0 and string.find(w.m.avisos[1], "roto a propósito", 1, true) ~= nil, "fallo: sin aviso")
	romper = false
	-- Otra vez, y el servidor la quita.
	modelo:SetAttribute("Llegada", w.ahora() + w.LlegadaVista.DURA)
	w.m.correr(12, DT)
	comprobar(escondido(modelo) and #copias(w) == 1, "quitada: no ha empezado")
	modelo:SetAttribute("Llegada", nil)
	w.m.paso(DT)
	comprobar(visible(modelo) and #copias(w) == 0, "quitada: no se devuelve todo")
	-- Una Llegada que ya ha pasado (entrar tarde): nada.
	modelo:SetAttribute("Llegada", w.ahora() - 1)
	w.m.paso(DT)
	comprobar(visible(modelo) and #copias(w) == 0, "pasada: se esconde")
end

-- Una Salida retrasada por el servidor (otro coche estaba llegando): quieto y a la vista hasta su hora.
do
	local w = montar()
	local modelo = w.carpeta.Coche3
	local salida = w.ahora() + 7 + 5
	modelo:SetAttribute("Salida", salida)
	w.m.correr(4.9, DT)
	comprobar(visible(modelo) and #copias(w) == 0, "salida retrasada: empieza antes de hora")
	w.m.correr(0.2, DT)
	comprobar(escondido(modelo) and #copias(w) == 1, "salida retrasada: no empieza a su hora")
end

------------------------------------------------------------------------------------------------------------------------
-- 6. El servidor (lobby/servidor/Coches de verdad, con Viaje falso): al vaciarse tras el viaje pone Llegada, nadie se
-- sube hasta entonces y la Salida de otro coche espera a que haya llegado; a la hora, libre.
do
	local m = crearMundo({ servidor = true, proyecto = "lobby.project.json" })
	local g = m.global
	-- Lo que falta en el mundo falso: TeleportService.TeleportInitFailed y Seat:Sit.
	m.interno(m.servicio("TeleportService")).clase.eventos.TeleportInitFailed = true
	local carpeta = g.Instance.new("Folder")
	carpeta.Name = "Coches"
	carpeta.Parent = g.workspace
	m.cargar("src/lobby/servidor/GasolineraCoches").construir(carpeta)
	m.interno(carpeta.Coche1.Asiento1).clase.metodos.Sit = function(asiento, humanoide)
		asiento.Occupant = humanoide
	end
	local viajes = 0
	local Coches = m.cargar("src/lobby/servidor/Coches", { Viaje = { ir = function()
		viajes += 1
		return true
	end } })
	Coches.start()
	local Remotes = m.cargar("src/shared/Remotes")
	local function ahora(): number
		return g.workspace:GetServerTimeNow()
	end
	local function prompt(n: number): any
		return carpeta[`Coche{n}`].Carroceria:FindFirstChildOfClass("ProximityPrompt")
	end
	local A, B = m.jugador("A"), m.jugador("B")
	m.personaje(g.CFrame.new(0, 3, 0), A)
	m.personaje(g.CFrame.new(0, 3, 10), B)
	local c2, c3 = carpeta.Coche2, carpeta.Coche3
	prompt(2).Triggered:Fire(A)
	m.paso()
	comprobar(c2:GetAttribute("Dueno") == A.UserId, "servidor: A no se sube")
	Remotes.Coche.OnServerEvent:Fire(A, "Arrancar")
	comprobar(math.abs(c2:GetAttribute("Salida") - ahora() - 7) < 1e-6, "servidor: la salida no es a los 7 s")
	m.correr(7.1)
	comprobar(viajes == 1, "servidor: no se va")
	c2.Asiento1.Occupant = nil -- se lo ha llevado el teletransporte
	m.paso()
	local llegada = c2:GetAttribute("Llegada")
	comprobar(type(llegada) == "number" and math.abs(llegada - ahora() - 2 - LLEGADA_DURA) < 0.05,
		`servidor: Llegada {llegada and llegada - ahora()}`)
	comprobar(c2:GetAttribute("Salida") == nil and not prompt(2).Enabled, "servidor: se puede subir al que llega")
	prompt(2).Triggered:Fire(B)
	m.paso()
	comprobar(c2.Asiento1.Occupant == nil and B:GetAttribute("Coche") == nil, "servidor: B se sube al que llega")
	-- B arranca el 3 mientras el 2 ya va por las plazas: su salida espera a que el 2 se pare.
	m.correr(LLEGADA_DURA - LLEGADA_CERCA + 4)
	prompt(3).Triggered:Fire(B)
	m.paso()
	Remotes.Coche.OnServerEvent:Fire(B, "Arrancar")
	local salida3 = c3:GetAttribute("Salida")
	comprobar(salida3 - 7 >= llegada, `servidor: el 3 sale a la vez que llega el 2 ({salida3 - 7 - llegada})`)
	m.correr(llegada - ahora() + 0.05)
	comprobar(c2:GetAttribute("Llegada") == nil and prompt(2).Enabled, "servidor: el 2 no queda libre al llegar")
	-- El 3 se va; el 1 se queda vacío tras un viaje mientras llega el 3: su llegada espera a la del 3.
	m.correr(salida3 - ahora() + 0.1)
	comprobar(viajes == 2, "servidor: el 3 no se va")
	c3.Asiento1.Occupant = nil
	m.paso()
	local llegada3 = c3:GetAttribute("Llegada")
	prompt(1).Triggered:Fire(A)
	m.paso()
	Remotes.Coche.OnServerEvent:Fire(A, "Arrancar")
	m.correr(carpeta.Coche1:GetAttribute("Salida") - ahora() + 0.1)
	carpeta.Coche1.Asiento1.Occupant = nil
	m.paso()
	local llegada1 = carpeta.Coche1:GetAttribute("Llegada")
	comprobar(llegada1 - LLEGADA_CERCA >= llegada3, `servidor: el 1 llega a la vez que el 3 ({llegada1 - LLEGADA_CERCA - llegada3})`)
	comprobar(#m.errores == 0 and #m.avisos == 0, `servidor: {m.errores[1] or m.avisos[1]}`)
end

------------------------------------------------------------------------------------------------------------------------
-- 7. Los números del servidor cuadran con los del cliente.
comprobar(tonumber(string.match(fuente, "\nlocal LLEGADA = ([%d%.]+)")) == LLEGADA_DURA, "Coches.LLEGADA ~= LlegadaVista.DURA")
comprobar(tonumber(string.match(fuente, "\nlocal CERCA = ([%d%.]+)")) == LLEGADA_CERCA, "Coches.CERCA ~= LlegadaVista.CERCA")

print(`lobby-coche: {cuentas} comprobaciones bien`)
