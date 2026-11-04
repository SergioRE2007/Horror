-- Banco del gateo debajo de las mesas (14.9.2, pedido por el usuario: "comprueba con bancos de Lune que los gateos
-- siguen sin atravesar la mesa"). Ejecutar desde la raíz: lune run tests/bancos/_gateo.luau [Bicho] (con un nombre,
-- solo ese bicho). A MEDIAS: con "_" regressions.luau no lo lanza; cuando pase con los cinco, quitarle el "_".
-- GATEO_VER=1 enseña lo peor de cada fase sin fallar; GATEO_SOLO="<trozo de la etiqueta>" corre solo esos casos.
-- Con el Roblox de mentira (tests/bancos/_roblox.luau), en un mundo de cliente:
--   el cuerpo de verdad de cada bicho: lo de servidor/<Bicho>.luau hasta el final de su crear (que es local), sin sus
--   require, con Config y servidor/Cuerpo de verdad y un Caza de mentira (el modelo sale igual que en el servidor; se
--   monta en el mundo del cliente porque el de mentira no replica);
--   la mesa del comedor y la de la cocina como en Mapa (HUECOS se lee de Mapa.luau): el mueble con Tam y su pivote, la
--   zona Debajo con su etiqueta y las cajas Choque del tablero, las patas y la viga, con CanQuery = false;
--   la Vista de verdad del bicho, que lo anima con Gatea y GateaHora (como Caza: raíz anclada en el borde, de cara a ti).
-- Mira fotograma a fotograma, de 0,8 a 6 studs del borde del tablero, en diagonal, con Rendimiento, a 20 fps,
-- escapándote (Gatea a nil a mitad) y pillándote (rugir, como la escena de muerte):
--   sin NaN en ninguna pieza;
--   ninguna pieza que se ve se mete más de MARGEN en el tablero (todo el Tam, de su cara de abajo arriba), las patas, la
--   viga o el suelo (SUELO);
--   al acabar sale del hueco y se levanta (la cabeza vuelve a la altura de antes);
--   la luz de la cara de la Bestia se enciende metida y se quita al echar a andar (con Rendimiento, nunca).
-- Si algo no se cumple, termina con error.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local crearMundo = require("./_roblox")

local cuentas = 0
local function comprueba(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end

local MARGEN = 0.05 -- studs que puede meterse una pieza en el tablero, las patas o la viga (redondeos de la pose)
local SUELO = 0.1 -- ...y en el suelo, más de lo que ya se metía de pie (los pies apoyados y las manos clavadas rozan)
local LEVANTA = 0.5 -- studs que puede quedar la cabeza por debajo de donde estaba antes de gatear, al acabar
local LLEGA = 4 -- studs que anda hasta el sitio, en 1 s, antes de gatear
local HEREDA = 0.3 -- s del principio del gateo en los que no cuenta lo que ya se metía al llegar andando
local DIAGONAL = { 1.5, 2.5 } -- en diagonal: studs hacia fuera y a un lado del borde
local Y = 1 -- el suelo de la planta baja (ABAJO en Mapa)

-- Los huecos de Mapa (HUECOS es local): la tabla tal cual, sacada del texto.
local HUECOS = (function()
	local texto = fs.readFile("src/juego/servidor/Mapa.luau")
	local a = string.find(texto, "\nlocal HUECOS", 1, true)
	assert(a, "Mapa: no encuentro HUECOS")
	local abre = string.find(texto, "{\n", a, true)
	local _, cierra = string.find(texto, "\n}\n", abre, true)
	return luau.load("return " .. string.sub(texto, abre, cierra), { debugName = "HUECOS" })()
end)()

-- Dónde se para cada uno a gatear (Caza.borde): studs fuera de la zona Debajo.
local FUERA = {
	Golpeador = function(P)
		return P.Fuera
	end,
	Imitador = function(P)
		return P.Fuera
	end,
	Raspador = function(P)
		return P.FueraRaspador
	end,
	Trepador = function(P)
		return P.FueraTrepador
	end,
	Bestia = function(P)
		return P.FueraBestia
	end,
}

-- Las dos mesas, puestas como en Mapa. El Tam del comedor es el de verdad; el de la cocina, a ojo (el de verdad está en
-- ServerStorage.Muebles, fuera del repo), con sus patas y su hueco de HUECOS dentro.
local MESAS = {
	Comedor = {
		mueble = "MesaComedorPH",
		tam = { 13, 3.51, 5.56 },
		-- tienda("MesaComedorPH", CFrame.new(MESA) * CFrame.Angles(0, math.pi / 2, 0)), MESA = (-25.5, ABAJO, -15)
		pivote = function(CFrame)
			return CFrame.new(-25.5, Y, -15) * CFrame.Angles(0, math.pi / 2, 0)
		end,
		tu = { -26.1, 3, -15 }, -- donde te pones en bichos.md
		fuera = { -1, 0, 0 }, -- por dónde se entra (el lado largo del oeste)
	},
	Cocina = {
		mueble = "MesaCocinaPH",
		tam = { 4.8, 3.9, 3.4 },
		-- contraPared("MesaCocinaPH", -19.5, ABAJO, 3.7, DETRAS): la espalda en la pared y el frente hacia +Z (el
		-- CFrame.lookAt(pos, pos + Vector3.zAxis) de Mapa, con fromMatrix: en Lune lookAt sale mal)
		pivote = function(CFrame, Vector3, tam)
			local pos = Vector3.new(-19.5, Y, 3.7 + tam.Z / 2 + 0.05)
			return CFrame.fromMatrix(pos, -Vector3.xAxis, Vector3.yAxis)
		end,
		tu = { -19.5, 3, 7 },
		fuera = { 0, 0, 1 },
	},
}

------------------------------------------------------------------------------------------------------------------------
-- Cajas orientadas: cuánto se mete una en otra (0 si no se tocan), por los 15 ejes que las separan.
type Caja = { cf: any, medio: any }
local function radio(c: Caja, eje): number
	local cf, m = c.cf, c.medio
	return math.abs(cf.RightVector:Dot(eje)) * m.X + math.abs(cf.UpVector:Dot(eje)) * m.Y + math.abs(cf.LookVector:Dot(eje)) * m.Z
end
local function seMete(a: Caja, b: Caja): number
	local ejesA = { a.cf.RightVector, a.cf.UpVector, a.cf.LookVector }
	local ejesB = { b.cf.RightVector, b.cf.UpVector, b.cf.LookVector }
	local ejes = table.clone(ejesA)
	for _, e in ejesB do
		table.insert(ejes, e)
	end
	for _, ea in ejesA do
		for _, eb in ejesB do
			local x = ea:Cross(eb)
			if x.Magnitude > 1e-4 then
				table.insert(ejes, x.Unit)
			end
		end
	end
	local d = b.cf.Position - a.cf.Position
	local menos = math.huge
	for _, eje in ejes do
		local mete = radio(a, eje) + radio(b, eje) - math.abs(d:Dot(eje))
		if mete <= 0 then
			return 0
		end
		menos = math.min(menos, mete)
	end
	return menos
end
-- Lo más bajo de una caja.
local function bajo(c: Caja): number
	local cf, m = c.cf, c.medio
	return cf.Position.Y - (math.abs(cf.RightVector.Y) * m.X + math.abs(cf.UpVector.Y) * m.Y + math.abs(cf.LookVector.Y) * m.Z)
end

------------------------------------------------------------------------------------------------------------------------
-- El cuerpo de verdad: lo de servidor/<Bicho>.luau hasta el final de crear (local), sin sus require.
local TROZOS: { [string]: string } = {}
local ALTURAS: { [string]: number } = {} -- de los pies al centro de la raíz (ALTURA de cada uno)
for _, nombre in { "Golpeador", "Raspador", "Trepador", "Imitador", "Bestia" } do
	local texto = fs.readFile("src/juego/servidor/" .. nombre .. ".luau")
	local c = string.find(texto, "\nlocal function crear(", 1, true)
	assert(c, `{nombre}: no encuentro crear`)
	local _, b = string.find(texto, "\nend\n", c, true)
	local trozo = string.sub(texto, 1, b)
	trozo = string.gsub(trozo, "\n[^\n]*require%b()[^\n]*", "\n")
	trozo = string.gsub(trozo, "\nlocal [%w_]+: any[^\n]*", "\n") -- los que se cargan en start() (Bestia: Acechador)
	TROZOS[nombre] = trozo .. "\nreturn crear, ALTURA"
end

local function cuerpo(m, nombre: string, cf)
	local g = m.global
	local carpeta = g.workspace:FindFirstChild("Bichos")
	local nada = setmetatable({}, { __index = function()
		return function() end
	end })
	local env = table.clone(g)
	env.Config = m.cargar("src/shared/Config")
	env.Cuerpo = m.cargar("src/juego/servidor/Cuerpo")
	env.Caza = setmetatable({
		plano = function(v)
			return g.Vector3.new(v.X, 0, v.Z)
		end,
		carpeta = function()
			return carpeta
		end,
		nuevo = function(modelo)
			return modelo
		end,
	}, { __index = nada })
	-- Los demás módulos del servidor que nombran (fuera de crear): nada.
	setmetatable(env, { __index = function()
		return nada
	end })
	local crear, altura = luau.load(TROZOS[nombre], { debugName = nombre .. ".crear", environment = env })()
	ALTURAS[nombre] = altura
	return if cf then crear(cf) else nil
end

------------------------------------------------------------------------------------------------------------------------
-- Un gateo entero. op: bicho, mesa, distancia (de la raíz al borde de Caza.borde, a su Fuera de la zona) o diagonal, rendimiento, dt, escapa
-- (s hasta que Gatea vuelve a nil; si no, GATEAR), pilla (rugir al pillarte, como la escena de muerte).
type Op = { bicho: string, mesa: string, distancia: number?, diagonal: boolean?, rendimiento: boolean?, dt: number?,
	escapa: number?, pilla: boolean? }

local function gateo(op: Op)
	local etiqueta = `{op.bicho} en la mesa de la {op.mesa}, `
		.. (if op.diagonal then "en diagonal" else `a {op.distancia}`)
		.. (if op.rendimiento then ", con Rendimiento" else "")
		.. (if op.dt then `, a {math.floor(1 / op.dt + 0.5)} fps` else "")
		.. (if op.escapa then ", escapándote" else "")
		.. (if op.pilla then ", pillándote" else "")
	if process.env.GATEO_SOLO and not string.find(etiqueta, process.env.GATEO_SOLO, 1, true) then
		return
	end
	local dt = op.dt or 1 / 60
	local m = crearMundo()
	local g = m.global
	if process.env.GATEO_DEBUG then
		g._G.DEPURA = true
	end
	local Postura = m.cargar("src/shared/Config").Postura
	local GATEAR = Postura.Gatear
	local Vector3, CFrame, Instance = g.Vector3, g.CFrame, g.Instance
	m.sueloY = Y
	m.controles = false
	m.caja(CFrame.new(0, Y - 0.5, 0), Vector3.new(400, 1, 400), { Name = "Suelo" })
	local carpeta = Instance.new("Folder")
	carpeta.Name = "Bichos"
	carpeta.Parent = g.workspace
	g.workspace:SetAttribute("Fase", "Noche")

	-- La mesa, como Mapa.tienda y conHueco.
	local d = MESAS[op.mesa]
	local h = HUECOS[d.mueble]
	local tam = Vector3.new(d.tam[1], d.tam[2], d.tam[3])
	local pivote = d.pivote(CFrame, Vector3, tam)
	local casa = Instance.new("Model")
	casa.Name = "Casa"
	casa.Parent = g.workspace
	local mueble = Instance.new("Model")
	mueble.Name = d.mueble
	mueble.WorldPivot = pivote
	mueble:SetAttribute("Tam", tam)
	mueble.Parent = casa
	local obstaculos: { { nombre: string, caja: Caja } } = {}
	local function choque(nombre: string, x1, x2, y1, y2, z1, z2)
		local cf = pivote * CFrame.new((x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2)
		local t = Vector3.new(x2 - x1, y2 - y1, z2 - z1)
		m.caja(cf, t, { Name = "Choque", Transparency = 1, CanQuery = false, CanTouch = false, Parent = casa })
		if nombre ~= "" then
			table.insert(obstaculos, { nombre = nombre, caja = { cf = cf, medio = t / 2 } })
		end
	end
	-- Lo que choca del tablero es el 90 % del Tam; lo que se ve (y se mira aquí), el Tam entero.
	choque("", -tam.X * 0.45, tam.X * 0.45, h.abajo, tam.Y, -tam.Z * 0.45, tam.Z * 0.45)
	local tablero = pivote * CFrame.new(0, (h.abajo + tam.Y) / 2, 0)
	table.insert(obstaculos, { nombre = "el tablero", caja = { cf = tablero, medio = Vector3.new(tam.X, tam.Y - h.abajo, tam.Z) / 2 } })
	for i, c in h.cajas do
		choque(if c[3] > 0 then "la viga" else `la pata {i}`, c[1], c[2], c[3], c[4], c[5], c[6])
	end
	local x1, x2, z1, z2 = h.hueco[1], h.hueco[2], h.hueco[3], h.hueco[4]
	local zonaCF = pivote * CFrame.new((x1 + x2) / 2, h.abajo / 2, (z1 + z2) / 2)
	local zonaTam = Vector3.new(x2 - x1, h.abajo, z2 - z1)
	local zona = m.caja(zonaCF, zonaTam, { Name = "Debajo", Transparency = 1, CanCollide = false, CanQuery = false,
		CanTouch = false, Parent = mueble })
	zona:SetAttribute("Mueble", d.mueble)
	g.game:GetService("CollectionService"):AddTag(zona, "Debajo")

	-- Tú, debajo; el bicho, en el borde y de cara a ti (en Lune, CFrame.lookAt con vector de arriba sale mal).
	local tu = Vector3.new(d.tu[1], d.tu[2], d.tu[3])
	local enZona = zonaCF:PointToObjectSpace(tu)
	comprueba(math.abs(enZona.X) < zonaTam.X / 2 and math.abs(enZona.Z) < zonaTam.Z / 2, etiqueta .. ": tú, en la zona Debajo")
	comprueba(pivote.LookVector:Dot(Vector3.new(d.fuera[1], d.fuera[2], d.fuera[3])) > 0.99 or op.mesa ~= "Cocina", etiqueta .. ": la cocina, de frente hacia ti")
	cuerpo(m, op.bicho, nil) -- solo para saber su ALTURA
	m.personaje(CFrame.new(tu))
	if op.rendimiento then
		m.jugadorLocal:SetAttribute("Rendimiento", true)
	end
	local fuera = Vector3.new(d.fuera[1], d.fuera[2], d.fuera[3])
	-- El borde de Caza.borde por ese lado, frente a ti: a Fuera (el de ese bicho) de la zona Debajo.
	local medio = (zonaCF:VectorToObjectSpace(fuera)):Abs() * zonaTam / 2
	local borde = Vector3.new(tu.X, Y, tu.Z)
		+ fuera * ((zonaCF.Position - tu):Dot(fuera) + medio.X + medio.Z + FUERA[op.bicho](Postura))
	local alto = Y + ALTURAS[op.bicho] -- la raíz, donde la tiene su Humanoid (HipHeight + medio alto de la raíz)
	-- En diagonal: más a un lado que hacia fuera, sin pasar de Config.Postura.CercaBorde del borde (donde empieza a gatear).
	local desde = borde + (if op.diagonal then fuera * DIAGONAL[1] + fuera:Cross(Vector3.yAxis) * DIAGONAL[2] else fuera * op.distancia)
	desde = Vector3.new(desde.X, alto, desde.Z)
	local mira = Vector3.new(tu.X - desde.X, 0, tu.Z - desde.Z).Unit
	local derecha = mira:Cross(Vector3.yAxis)
	-- Llega andando (LLEGA studs, de cara a ti) y se para: así lo deja Caza al empezar a gatear.
	local modelo = cuerpo(m, op.bicho, CFrame.fromMatrix(desde - mira * LLEGA, derecha, Vector3.yAxis))
	local raiz = modelo:FindFirstChild("HumanoidRootPart")
	local humanoide = modelo:FindFirstChildOfClass("Humanoid")
	raiz.Anchored = true
	comprueba(math.abs(humanoide.HipHeight + raiz.Size.Y / 2 - ALTURAS[op.bicho]) < 1e-6, etiqueta .. ": a la altura de su Humanoid")
	-- La Vista, después de un fotograma: el Roblox de mentira fija lo soldado (WeldConstraint) la primera vez que lo
	-- junta, no al crearlo; con la Vista ya moviendo los miembros, los adornos quedaban soldados donde no son.
	m.paso(dt)
	local Vista = m.cargar("src/juego/cliente/" .. op.bicho .. "Vista")
	Vista.start()
	comprueba((raiz.CFrame.LookVector - mira).Magnitude < 1e-3, etiqueta .. ": de cara a ti")
	comprueba(DIAGONAL[1] ^ 2 + DIAGONAL[2] ^ 2 < Postura.CercaBorde ^ 2, etiqueta .. ": la diagonal, a CercaBorde")

	-- Lo que se ve del bicho (la raíz es invisible; lo que esconde al aplastarse, también).
	local piezas = {}
	for _, p in modelo:GetDescendants() do
		if p:IsA("BasePart") and p ~= raiz then
			table.insert(piezas, p)
		end
	end
	local cabeza = modelo:FindFirstChild("Cabeza")
	assert(cabeza, etiqueta .. ": sin Cabeza")
	local peor = { mete = 0, que = "" }
	local porFase: { [string]: { mete: number, que: string } } = {}
	local llegada: { [any]: { [any]: number } } = {} -- lo que se mete cada pieza en cada obstáculo al acabar de llegar
	local alLlegar: { [string]: number } = {}
	local dePie: { [any]: number } = {} -- lo que se mete cada pieza en el suelo al llegar andando, antes de gatear
	local function nombreDe(p): string
		local s = p:FindFirstChildOfClass("WeldConstraint")
		return if s and s.Part0 then `{p.Name} de {s.Part0.Name} {p.Size}` else p.Name
	end
	local function apuntar(fase: string, mete: number, que: string)
		if mete > peor.mete then
			peor = { mete = mete, que = que }
		end
		local f = porFase[fase]
		if not f or mete > f.mete then
			porFase[fase] = { mete = mete, que = que }
		end
	end
	local function mirar(fase: string, t: number)
		for _, p in piezas do
			local cf = p.CFrame
			assert(not m.roto(cf), `{etiqueta}: NaN en {p.Name} ({fase}, {t} s)`)
			if p.Transparency < 1 and p.LocalTransparencyModifier < 1 then
				local caja = { cf = cf, medio = p.Size / 2 }
				for _, o in obstaculos do
					-- Lo que ya se metía al llegar andando (antes de gatear: la vida de andar, fuera de lo que mira este banco)
					-- no cuenta en los primeros HEREDA s del gateo, que salen de ahí: solo lo que se mete de más.
					local mete = seMete(caja, o.caja)
					if fase == "llegando" then
						local antes = llegada[p] or {}
						antes[o] = mete
						llegada[p] = antes
						if mete > MARGEN then
							alLlegar[`{nombreDe(p)} en {o.nombre}`] = math.max(alLlegar[`{nombreDe(p)} en {o.nombre}`] or 0, mete)
						end
						continue
					end
					if fase == "gateando" and t < HEREDA then
						mete -= (llegada[p] or {})[o] or 0
					end
					if mete > MARGEN and process.env.GATEO_DEBUG == p.Name then
						local q = o.caja.cf:PointToObjectSpace(cf.Position)
						print(string.format("%s %.2f %s %.2f mete %.3f; en la caja (%.2f %.2f %.2f) eje (%.2f %.2f %.2f) raíz %s", fase, t, o.nombre, 0,
							mete, q.X, q.Y, q.Z, cf.UpVector.X, cf.UpVector.Y, cf.UpVector.Z, tostring(raiz.Position)))
					end
					if mete > MARGEN then
						apuntar(fase, mete, `{nombreDe(p)} en {o.nombre} ({fase}, {string.format("%.2f", t)} s)`)
					end
				end
				-- En el suelo, lo que ya se mete andando es del modelo (las piernas y los dedos pasan del suelo para que se
				-- vean apoyados): se mira lo que se mete de más.
				local suelo = Y - bajo(caja)
				if fase == "llegando" then
					dePie[p] = math.max(dePie[p] or 0, suelo)
				end
				local deMas = suelo - math.max(dePie[p] or 0, 0)
				if process.env.GATEO_DEBUG == "suelo" and deMas > SUELO then
					local s0 = p:FindFirstChildOfClass("WeldConstraint")
					local brazo = s0 and s0.Part0
					print(string.format("%s %.2f %s baja %.2f; eje %s; brazo eje %s centro %s; adorno en brazo %s", fase, t, nombreDe(p), suelo,
						tostring(cf.UpVector), brazo and tostring(brazo.CFrame.UpVector) or "", brazo and tostring(brazo.Position) or "",
						brazo and tostring(brazo.CFrame:PointToObjectSpace(cf.Position)) or ""))
				end
				if deMas > SUELO then
					apuntar(fase, deMas - SUELO + MARGEN, `{nombreDe(p)} {string.format("%.2f", suelo)} en el suelo (llegando, `
						.. `{string.format("%.2f", dePie[p] or 0)}; {fase}, {string.format("%.2f", t)} s)`)
				end
			end
		end
		cuentas += 1
	end
	local function correr(fase: string, segundos: number, cada: ((t: number) -> ())?)
		local t0 = m.ahora()
		m.correr(segundos, dt, function()
			local t = m.ahora() - t0
			mirar(fase, t)
			if cada then
				cada(t)
			end
		end)
	end

	-- Llega, gatea y lo deja.
	local v = mira * LLEGA / 1
	correr("llegando", 1, function()
		raiz.AssemblyLinearVelocity = v
		modelo:PivotTo(raiz.CFrame + v * dt)
	end)
	modelo:PivotTo(CFrame.fromMatrix(desde, derecha, Vector3.yAxis))
	-- Se para (el Humanoid frena en unos 0,1 s) y Caza le pone a gatear.
	correr("llegando", 0.2, function(t)
		raiz.AssemblyLinearVelocity = v * math.max(0, 1 - t / 0.1)
	end)
	local cabezaAntes = cabeza.Position
	modelo:SetAttribute("GateaHora", g.workspace:GetServerTimeNow())
	modelo:SetAttribute("Gatea", tu)
	local luz = -1
	local function luzDe(): number
		local a = cabeza:FindFirstChild("LuzGatea")
		local foco = a and a:FindFirstChildOfClass("PointLight")
		return if foco then foco.Brightness else -1
	end
	local masBaja = math.huge
	correr("gateando", op.escapa or GATEAR, function()
		luz = math.max(luz, luzDe())
		masBaja = math.min(masBaja, cabeza.Position.Y)
	end)
	comprueba(masBaja < cabezaAntes.Y - 0.5, `{etiqueta}: la cabeza baja a gatear ({masBaja} de {cabezaAntes.Y})`)
	if op.pilla then
		Vista.rugir(cabeza.Position, modelo)
	end
	modelo:SetAttribute("Gatea", nil)
	modelo:SetAttribute("GateaHora", nil)
	correr("saliendo", 3)
	if op.bicho == "Bestia" then
		-- Echada atrás hasta que anda: se va andando hacia atrás, como haría al seguir con lo suyo.
		local va = -mira * 6
		correr("andando", 2, function()
			raiz.AssemblyLinearVelocity = va
			modelo:PivotTo(raiz.CFrame + va * dt)
		end)
		raiz.AssemblyLinearVelocity = Vector3.zero
		correr("parada", 1)
		if op.rendimiento then
			comprueba(luz < 0, `{etiqueta}: sin luz en la cara con Rendimiento`)
		else
			comprueba(luz > 0.3 and luz <= 0.5 + 1e-6, `{etiqueta}: luz floja en la cara metida ({luz})`)
		end
		comprueba(cabeza:FindFirstChild("LuzGatea") == nil, `{etiqueta}: la luz se quita al acabar`)
	end
	if process.env.GATEO_VER then
		print(etiqueta)
		for que, mete in alLlegar do
			print("    (al llegar andando)", string.format("%.3f", mete), que)
		end
		for _, f in porFase do
			print("   ", string.format("%.3f", f.mete), f.que)
		end
		return peor
	end
	comprueba(peor.mete <= MARGEN, `{etiqueta}: atraviesa {string.format("%.3f", peor.mete)}: {peor.que}`)
	-- Fuera del hueco y de pie otra vez.
	local hueco = { cf = zonaCF, medio = zonaTam / 2 }
	for _, p in piezas do
		if p.Transparency < 1 then
			comprueba(seMete({ cf = p.CFrame, medio = p.Size / 2 }, hueco) <= MARGEN, `{etiqueta}: al acabar, {p.Name} sigue debajo`)
		end
	end
	comprueba(cabeza.Position.Y > cabezaAntes.Y - LEVANTA, `{etiqueta}: al acabar se levanta ({cabeza.Position.Y} de {cabezaAntes.Y})`)
	comprueba(#m.errores == 0, `{etiqueta}: errores\n{table.concat(m.errores, "\n")}`)
	return peor
end

------------------------------------------------------------------------------------------------------------------------
local solo = process.args[1]
local peores = {}
for _, bicho in { "Golpeador", "Raspador", "Trepador", "Imitador", "Bestia" } do
	if solo and solo ~= bicho then
		continue
	end
	local casos: { Op } = {}
	for _, distancia in { 0.8, 1.5, 2.5, 4, 6 } do
		table.insert(casos, { bicho = bicho, mesa = "Comedor", distancia = distancia })
	end
	table.insert(casos, { bicho = bicho, mesa = "Comedor", diagonal = true })
	table.insert(casos, { bicho = bicho, mesa = "Comedor", distancia = 2.5, rendimiento = true })
	table.insert(casos, { bicho = bicho, mesa = "Comedor", distancia = 2.5, dt = 1 / 20 })
	table.insert(casos, { bicho = bicho, mesa = "Comedor", distancia = 2.5, escapa = 1 })
	table.insert(casos, { bicho = bicho, mesa = "Comedor", distancia = 2.5, pilla = true })
	for _, distancia in { 0.8, 2.5, 6 } do
		table.insert(casos, { bicho = bicho, mesa = "Cocina", distancia = distancia })
	end
	table.insert(casos, { bicho = bicho, mesa = "Cocina", diagonal = true })
	table.insert(casos, { bicho = bicho, mesa = "Cocina", distancia = 2.5, rendimiento = true })
	for _, op in casos do
		local peor = gateo(op)
		table.insert(peores, peor)
	end
end

print(`gateo: {cuentas} comprobaciones bien`)
