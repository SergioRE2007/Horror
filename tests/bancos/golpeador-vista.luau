-- Banco de los sucesos al azar y del susto de pie del Golpeador (14.10). Ejecutar desde la raíz:
-- lune run tests/bancos/golpeador-vista.luau. SUCESOS_VER=1 enseña lo peor de cada caso y lo que falla, sin parar.
-- Con el Roblox de mentira (tests/bancos/_roblox.luau): el cuerpo de verdad del Golpeador (lo de servidor/Golpeador.luau
-- hasta el final de crear, sin sus require, como el banco del gateo: sin malla, con los bloques) y su Vista de verdad,
-- que lo anima con los atributos que pone Caza (Suceso, SucesoHora, SucesoMira, SucesoLado) y con rugir.
-- Cada caso: de pie 1 s (lo que ya se mete de pie no cuenta), el suceso (SucesoDura s) y lo deja (2 s). Mira fotograma
-- a fotograma, a 60 y a 20 fps y con Rendimiento:
--   sin NaN en ninguna pieza;
--   ninguna pieza que se ve se mete más de MARGEN en la pared (Garras: andando a su lado; Cara, Llama y Armario: la del
--   cristal o la puerta), ni más de SUELO en el suelo de lo que ya se metía de pie;
--   Garras: la punta de las garras llega a la pared (a menos de TOCA); Llama: el dedo toca el cristal en cada toque; Cara
--   y Armario: la cabeza, pegada a SucesoMira (a menos de PEGA);
--   al acabar, la cabeza vuelve a donde estaba de pie (a menos de VUELVE).
-- El susto de pie (rugir): sin NaN, se abalanza (la cabeza se adelanta) y hasta Espera sigue en la pose; luego vuelve.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local crearMundo = require("./_roblox")

local VER = process.env.SUCESOS_VER ~= nil and process.env.SUCESOS_VER ~= ""
local cuentas, fallos = 0, 0
local function comprueba(cond: any, etiqueta: string)
	if VER and not cond then
		print("    FALLA:", etiqueta)
		fallos += 1
	else
		assert(cond, etiqueta)
	end
	cuentas += 1
end

local MARGEN = 0.05 -- studs que puede meterse una pieza en la pared
local SUELO = 0.1 -- ...y en el suelo, más de lo que ya se metía de pie
local TOCA = 0.5 -- studs: la punta de las garras, a esto de la pared como mucho alguna vez (Garras, Llama)
local PEGA = 1.6 -- studs del centro de la cabeza de bloques a SucesoMira (Cara y Armario; la cara sobresale ~0,75)
local VUELVE = 0.5 -- studs: al acabar, la cabeza a esto de donde estaba de pie

-- Cajas orientadas: cuánto se mete una en otra (0 si no se tocan), por los 15 ejes que las separan (como el del gateo).
local function radio(c, eje): number
	local cf, m = c.cf, c.medio
	return math.abs(cf.RightVector:Dot(eje)) * m.X + math.abs(cf.UpVector:Dot(eje)) * m.Y + math.abs(cf.LookVector:Dot(eje)) * m.Z
end
local function seMete(a, b): number
	local d = b.cf.Position - a.cf.Position
	if d.Magnitude >= a.medio.Magnitude + b.medio.Magnitude then
		return 0
	end
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
local function bajo(c): number
	local cf, m = c.cf, c.medio
	return cf.Position.Y - (math.abs(cf.RightVector.Y) * m.X + math.abs(cf.UpVector.Y) * m.Y + math.abs(cf.LookVector.Y) * m.Z)
end

-- El cuerpo de verdad: lo de servidor/Golpeador.luau hasta el final de crear (local), sin sus require.
local TROZO = (function()
	local texto = string.gsub(fs.readFile("src/juego/servidor/Golpeador.luau"), "\r\n", "\n")
	local c = string.find(texto, "\nlocal function crear(", 1, true)
	assert(c, "Golpeador: no encuentro crear")
	local _, b = string.find(texto, "\nend\n", c, true)
	local trozo = string.gsub(string.sub(texto, 1, b), "\n[^\n]*require%b()[^\n]*", "\n")
	return trozo .. "\nreturn crear, ALTURA"
end)()

local function cuerpo(m, cf)
	local g = m.global
	local carpeta = g.workspace:FindFirstChild("Bichos")
	local nada = setmetatable({}, { __index = function()
		return function() end
	end })
	local env = table.clone(g)
	env.Config = m.cargar("src/shared/Config")
	env.Cuerpo = m.cargar("src/juego/servidor/Cuerpo")
	env.Bichos3D = nada
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
	setmetatable(env, { __index = function()
		return nada
	end })
	local crear, altura = luau.load(TROZO, { debugName = "Golpeador.crear", environment = env })()
	return if cf then crear(cf) else nil, altura
end

-- Un caso. op: suceso, dura, dt, rendimiento, susto (rugir en vez de suceso).
local function caso(op: { suceso: string?, dura: number, dt: number?, rendimiento: boolean?, susto: boolean? })
	local dt = op.dt or 1 / 60
	local etiqueta = (op.suceso or "susto") .. (if op.rendimiento then ", con Rendimiento" else "")
		.. (if op.dt then `, a {math.floor(1 / op.dt + 0.5)} fps` else "")
	local m = crearMundo()
	local g = m.global
	local Vector3, CFrame, Instance = g.Vector3, g.CFrame, g.Instance
	local Config = m.cargar("src/shared/Config")
	m.sueloY = 0
	m.controles = false
	m.caja(CFrame.new(0, -0.5, 0), Vector3.new(400, 1, 400), { Name = "Suelo" })
	local carpeta = Instance.new("Folder")
	carpeta.Name = "Bichos"
	carpeta.Parent = g.workspace
	g.workspace:SetAttribute("Fase", "Noche")
	local _, ALTURA = cuerpo(m, nil)

	-- La pared: con su cara en z = -cara (de cara a +Z), 1 de gruesa y alta. El bicho, en el origen mirando a -Z (a ella)
	-- o, en Garras, andando por +X con ella a su izquierda.
	local garras = op.suceso == "Garras"
	-- (En el susto, lejos: la cámara y la pared son cosa de MuerteVista.)
	local cara = if garras then 3 elseif op.suceso == "Armario" then 3.3 elseif op.susto then 12 else 4
	local paredCF = CFrame.new(0, 6, -cara - 0.5)
	local paredTam = Vector3.new(60, 12, 1)
	m.caja(paredCF, paredTam, { Name = "Pared" })
	local pared = { cf = paredCF, medio = paredTam / 2 }
	m.personaje(CFrame.new(0, 3, 6))
	if op.rendimiento then
		m.jugadorLocal:SetAttribute("Rendimiento", true)
	end
	local cf = if garras then CFrame.fromMatrix(Vector3.new(-6, ALTURA, 0), Vector3.new(0, 0, 1), Vector3.yAxis)
		else CFrame.new(0, ALTURA, 0)
	local modelo = cuerpo(m, cf)
	local raiz = modelo:FindFirstChild("HumanoidRootPart")
	raiz.Anchored = true
	m.paso(dt)
	local Vista = m.cargar("src/juego/cliente/GolpeadorVista")
	Vista.start()

	local piezas, brazo = {}, {}
	for _, p in modelo:GetDescendants() do
		if p:IsA("BasePart") and p ~= raiz then
			table.insert(piezas, p)
			local s = p:FindFirstChildOfClass("WeldConstraint")
			-- Las garras: las piezas pegadas al brazo izquierdo (el de Garras) por debajo de su centro.
			if s and s.Part0 and s.Part0.Name == "BrazoI" and s.Part0.CFrame:PointToObjectSpace(p.Position).Y < -3 then
				table.insert(brazo, p)
			end
		end
	end
	local cabeza = modelo:FindFirstChild("Cabeza")
	local dePie: { [any]: number } = {}
	local peor = { mete = 0, que = "" }
	local function nombreDe(p): string
		local s = p:FindFirstChildOfClass("WeldConstraint")
		return if s and s.Part0 then `{p.Name} de {s.Part0.Name}` else p.Name
	end
	local function mirar(fase: string, t: number)
		for _, p in piezas do
			assert(not m.roto(p.CFrame), `{etiqueta}: NaN en {p.Name} ({fase}, {t} s)`)
			if p.Transparency >= 1 then
				continue
			end
			local caja = { cf = p.CFrame, medio = p.Size / 2 }
			local suelo = -bajo(caja)
			if fase == "de pie" then
				dePie[p] = math.max(dePie[p] or 0, suelo)
				continue
			end
			local mete = seMete(caja, pared)
			if mete > MARGEN and mete > peor.mete then
				peor = { mete = mete, que = `{nombreDe(p)} en la pared ({fase}, {string.format("%.2f", t)} s)` }
			end
			local deMas = suelo - math.max(dePie[p] or 0, 0) - SUELO
			if deMas > 0 and deMas + MARGEN > peor.mete then
				peor = { mete = deMas + MARGEN, que = `{nombreDe(p)} {string.format("%.2f", suelo)} en el suelo ({fase}, {string.format("%.2f", t)} s)` }
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
	-- Andando (Garras): la raíz por +X a 4 studs/s.
	local x = -6
	local function anda(_t: number)
		if garras then
			x += 4 * dt
			raiz.AssemblyLinearVelocity = Vector3.new(4, 0, 0)
			modelo:PivotTo(CFrame.fromMatrix(Vector3.new(x, ALTURA, 0), Vector3.new(0, 0, 1), Vector3.yAxis))
		end
	end

	correr("de pie", 1)
	local cabezaAntes = cabeza.Position
	local mira = if garras then Vector3.new(0, ALTURA + 2.4, -cara)
		elseif op.suceso == "Armario" then Vector3.new(0, 4.6, -cara)
		else Vector3.new(0, 4.5, -cara)
	if op.susto then
		Vista.rugir(Vector3.new(0, 4.5, -3), modelo)
		local masDelante = 0
		local tarde = 0
		correr("susto", Config.Golpeador.Susto.Espera, function(t)
			masDelante = math.max(masDelante, -(cabeza.Position.Z - cabezaAntes.Z))
			if t > Config.Golpeador.Susto.Espera - 0.2 then
				tarde = math.max(tarde, -(cabeza.Position.Z - cabezaAntes.Z))
			end
		end)
		comprueba(masDelante > 0.8, `{etiqueta}: se abalanza (la cabeza se adelanta {masDelante})`)
		comprueba(tarde > 0.8, `{etiqueta}: sigue encima hasta Espera ({tarde})`)
		correr("tras el susto", 2)
	else
		local hora = g.workspace:GetServerTimeNow()
		modelo:SetAttribute("SucesoHora", hora)
		modelo:SetAttribute("SucesoDura", op.dura)
		modelo:SetAttribute("SucesoMira", mira)
		modelo:SetAttribute("SucesoLado", -1)
		modelo:SetAttribute("Suceso", op.suceso)
		local toca, pega = math.huge, math.huge
		local toques = {}
		correr("suceso", op.dura, function(t)
			anda(t)
			if garras then
				for _, p in brazo do
					toca = math.min(toca, (p.Position.Z - p.Size.Magnitude / 2) - (-cara))
				end
			elseif op.suceso == "Llama" then
				-- El dedo más cerca del cristal, en cada toque ((i - 0,5) · CadaToque s de SucesoHora).
				local reglas = Config.Golpeador.Sucesos.Llama
				for i = 1, reglas.Toques do
					if math.abs(t - (i - 0.5) * reglas.CadaToque) < 0.05 then
						local cerca = math.huge
						for _, p in piezas do
							if p.Transparency < 1 then
								local q = p.CFrame
								local medio = p.Size / 2
								local frente = q.Position.Z - (math.abs(q.RightVector.Z) * medio.X + math.abs(q.UpVector.Z) * medio.Y
									+ math.abs(q.LookVector.Z) * medio.Z)
								cerca = math.min(cerca, frente + cara)
							end
						end
						toques[i] = math.min(toques[i] or math.huge, cerca)
					end
				end
			end
			pega = math.min(pega, (cabeza.Position - mira).Magnitude)
		end)
		if garras then
			comprueba(toca < TOCA, `{etiqueta}: las garras llegan a la pared ({toca})`)
		elseif op.suceso == "Llama" then
			for i = 1, Config.Golpeador.Sucesos.Llama.Toques do
				comprueba((toques[i] or math.huge) < TOCA, `{etiqueta}: el dedo toca el cristal en el toque {i} ({toques[i]})`)
			end
		elseif op.suceso == "Cara" or op.suceso == "Armario" then
			comprueba(pega < PEGA, `{etiqueta}: la cabeza, pegada ({pega})`)
		end
		for _, nombre in { "Suceso", "SucesoHora", "SucesoDura", "SucesoMira", "SucesoLado" } do
			modelo:SetAttribute(nombre, nil)
		end
		raiz.AssemblyLinearVelocity = Vector3.zero
		correr("dejándolo", 2, anda) -- (Garras sigue andando: de pie junto a la pared, sus brazos ya la rozan)
	end
	comprueba(peor.mete <= MARGEN, `{etiqueta}: lo peor, {peor.que} ({string.format("%.3f", peor.mete)})`)
	if not garras then
		comprueba((cabeza.Position - cabezaAntes).Magnitude < VUELVE, `{etiqueta}: la cabeza vuelve a su sitio`)
	end
	comprueba(#m.errores == 0, `{etiqueta}: sin errores ({m.errores[1]})`)
	if VER then
		print(etiqueta, "lo peor:", peor.que, string.format("%.3f", peor.mete))
	end
end

local DURA = { Armario = 4, Olfatea = 2.5, Llama = 4.6, Cara = 4, Aparta = 0.6, Finge = 2, Garras = 2.4, Quieto = 3 }
for _, nombre in { "Armario", "Olfatea", "Llama", "Cara", "Aparta", "Finge", "Garras", "Quieto" } do
	caso({ suceso = nombre, dura = DURA[nombre] })
	caso({ suceso = nombre, dura = DURA[nombre], dt = 1 / 20 })
	caso({ suceso = nombre, dura = DURA[nombre], rendimiento = true })
end
caso({ susto = true, dura = 0 })
caso({ susto = true, dura = 0, dt = 1 / 20 })
if VER then
	print(`sucesos del Golpeador: {cuentas} comprobaciones, {fallos} fallan`)
else
	print(`sucesos del Golpeador: {cuentas} comprobaciones bien`)
end
