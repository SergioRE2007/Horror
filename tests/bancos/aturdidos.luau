-- Banco de los bichos aturdidos: el flash y el cepo se notan en todos (BichoComun.aturdido). Ejecutar desde la raíz:
-- lune run tests/bancos/aturdidos.luau. ATURDIDOS_VER=1 enseña las medidas de cada caso.
-- Primero BichoComun solo, con un modelo y su atributo Aturdido (la hora del servidor hasta la que dura, como Caza):
--   nil sin aturdir; `nuevo` solo la primera vez; entra en ~0,12 s y sale suave en los últimos 0,4 s; otro flash a
--   medio salir vuelve a entrar sin saltos y sin otro `nuevo`; el temblor entre -1 y 1 y moviéndose; sin tirones en el
--   flash y con ellos en el cepo, a un lado y al otro; con Rendimiento, ni temblor ni tirones.
-- Luego, con el Roblox de mentira, el cuerpo de verdad de cada bicho (lo de servidor/<Bicho>.luau hasta el final de su
-- crear, como el banco del gateo) y su Vista de verdad, de pie y parado delante de la cámara: 1,5 s quieto, aturdido
-- (2 s el flash, 6 el cepo) y 1,5 s después. A 60 y a 20 fps y con Rendimiento, fotograma a fotograma:
--   sin NaN en ninguna pieza; ninguna se mete en el suelo más de lo que ya se metía quieto;
--   se nota: desde 0,2 s (ya ha entrado; TAPADA_YA) hasta que empieza a soltarse, las patas de delante del Trepador y
--   los dedos del Raspador delante de la cara (a menos de CUBRE), los brazos del Imitador y del Acechador por encima de
--   los hombros (en el cepo, hasta el primer tirón);
--   sin saltos: nada se mueve más de SALTO studs de un fotograma al otro (a 60 fps; a 20, lo que toque);
--   en el cepo forcejea: la cara se mueve más de FORCEJEA studs con los tirones; tiembla, y con Rendimiento, la cabeza
--   quieta (el Acechador, ni lo uno ni lo otro: se encoge como con la linterna);
--   chilla una vez al empezar; al acabar, vuelve (las patas, los dedos y los brazos, otra vez lejos de la cara).
-- La Bestia y el Golpeador no lo usan (cada uno tiene lo suyo). Junto a las mesas, el banco del gateo (con `aturde`).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local crearMundo = require("./_roblox")

local VER = process.env.ATURDIDOS_VER ~= nil and process.env.ATURDIDOS_VER ~= ""
local cuentas = 0
local function comprueba(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end

local CUBRE = 1.8 -- studs de la punta de las patas o de los dedos a la cara, como mucho, aturdido
local LEJOS = 2.5 -- ...y como poco, quieto antes y después
local SALTO = 2.5 -- studs que se mueve como mucho una pieza de un fotograma al otro, a 60 fps (al encogerse en
-- 0,12 s, la punta de los brazos largos llega a ~2; algo que salta de golpe, más de 5)
local SUELO = 0.15 -- studs que puede meterse en el suelo más de lo que ya se metía quieto
local FORCEJEA = 0.8 -- studs que se mueve la cara con los tirones del cepo, como poco
local CONFIG = crearMundo().cargar("src/shared/Config")
local FLASH, CEPO = CONFIG.Flash.Aturde, CONFIG.Taller.Trampa.Aturde -- segundos
local BICHOS = { "Trepador", "Imitador", "Raspador", "Acechador" }
-- Segundos hasta que ya se tapa la cara: el resto entra en 0,12; los brazos del Raspador, larguísimos, en 0,3.
local TAPADA_YA: { [string]: number } = { Raspador = 0.35 }

------------------------------------------------------------------------------------------------------------------------
-- BichoComun solo.
do
	local m = crearMundo()
	local g = m.global
	local BC = m.cargar("src/juego/cliente/BichoComun")
	local modelo = g.Instance.new("Model")
	modelo.Parent = g.workspace
	local dt = 1 / 60
	local function hora(): number
		return g.workspace:GetServerTimeNow()
	end
	comprueba(BC.aturdido(modelo, g.os.clock()) == nil, "BichoComun: sin aturdir, nil")
	modelo:SetAttribute("Aturdido", hora() + FLASH)
	local a = BC.aturdido(modelo, g.os.clock())
	comprueba(a and a.nuevo and a.peso == 0, "BichoComun: al empezar, nuevo y sin peso aún")
	local nuevos, temblores, tirones = 0, {}, 0
	local antes = 0
	m.correr(FLASH + 0.2, dt, function(n)
		local t = n * dt
		local b = BC.aturdido(modelo, g.os.clock())
		if b then
			if b.nuevo then
				nuevos += 1
			end
			comprueba(b.peso >= 0 and b.peso <= 1, "BichoComun: peso entre 0 y 1")
			comprueba(b.temblor >= -1 and b.temblor <= 1, "BichoComun: temblor entre -1 y 1")
			comprueba(b.peso - antes <= dt / 0.12 * 1.5 + 1e-6, `BichoComun: entra sin saltos ({t} s)`)
			table.insert(temblores, b.temblor)
			if b.tiron ~= 0 then
				tirones += 1
			end
			if math.abs(t - 0.06) < dt / 2 then
				comprueba(b.peso > 0.3 and b.peso < 0.7, `BichoComun: a 0,06 s, a medias ({b.peso})`)
			elseif t > 0.15 and t < FLASH - 0.42 then
				comprueba(b.peso == 1, `BichoComun: dentro, del todo ({t} s: {b.peso})`)
			elseif math.abs(t - (FLASH - 0.2)) < dt / 2 then
				comprueba(b.peso > 0.3 and b.peso < 0.7, `BichoComun: soltándose, a medias ({b.peso})`)
			end
			antes = b.peso
		else
			comprueba(t >= FLASH - 1e-6, `BichoComun: nil antes de acabar ({t} s)`)
			antes = 0
		end
	end)
	comprueba(nuevos == 0, "BichoComun: nuevo solo la primera vez")
	comprueba(tirones == 0, "BichoComun: el flash, sin tirones")
	local minimo, maximo = math.huge, -math.huge
	for _, v in temblores do
		minimo, maximo = math.min(minimo, v), math.max(maximo, v)
	end
	comprueba(maximo - minimo > 0.8, `BichoComun: el temblor se mueve ({minimo} .. {maximo})`)
	comprueba(BC.aturdido(modelo, g.os.clock()) == nil, "BichoComun: al acabar, nil")

	-- Otro flash a medio soltarse: vuelve a entrar desde donde iba (sin saltos y sin otro chillido).
	modelo:SetAttribute("Aturdido", hora() + FLASH)
	m.correr(FLASH - 0.25, dt, function()
		BC.aturdido(modelo, g.os.clock())
	end)
	local suelto = (BC.aturdido(modelo, g.os.clock()) :: any).peso
	comprueba(suelto < 0.9, "BichoComun: soltándose")
	modelo:SetAttribute("Aturdido", hora() + FLASH)
	local b = BC.aturdido(modelo, g.os.clock()) :: any
	comprueba(not b.nuevo and b.peso <= suelto + 0.01, "BichoComun: otro flash a medio soltarse, sin saltos ni chillido")
	m.correr(0.2, dt)
	comprueba((BC.aturdido(modelo, g.os.clock()) :: any).peso == 1, "BichoComun: ...y vuelve a entrar")
	m.correr(FLASH + 0.1, dt, function()
		BC.aturdido(modelo, g.os.clock())
	end)

	-- El cepo: forcejea a tirones, a un lado y al otro.
	modelo:SetAttribute("Aturdido", hora() + CEPO)
	local positivo, negativo = 0, 0
	m.correr(CEPO, dt, function(n)
		local c = BC.aturdido(modelo, g.os.clock())
		if c then
			comprueba(c.tiron >= -1 and c.tiron <= 1, "BichoComun: tirón entre -1 y 1")
			if n * dt < 0.85 then
				comprueba(c.tiron == 0, "BichoComun: el cepo, sin tirones el primer momento")
			end
			positivo, negativo = math.max(positivo, c.tiron), math.min(negativo, c.tiron)
		end
	end)
	comprueba(positivo > 0.5 and negativo < -0.5, `BichoComun: el cepo, tirones a los dos lados ({negativo} .. {positivo})`)

	-- Con Rendimiento: la pose quieta.
	m.correr(0.5, dt, function()
		BC.aturdido(modelo, g.os.clock())
	end)
	m.jugadorLocal:SetAttribute("Rendimiento", true)
	modelo:SetAttribute("Aturdido", hora() + CEPO)
	m.correr(CEPO - 0.5, dt, function()
		local c = BC.aturdido(modelo, g.os.clock())
		if c then
			comprueba(c.temblor == 0 and c.tiron == 0, "BichoComun: con Rendimiento, sin temblor ni tirones")
		end
	end)
end

------------------------------------------------------------------------------------------------------------------------
-- El cuerpo de verdad: lo de servidor/<Bicho>.luau hasta el final de crear (local), sin sus require (como el gateo).
local TROZOS: { [string]: string } = {}
for _, nombre in BICHOS do
	local texto = string.gsub(fs.readFile("src/juego/servidor/" .. nombre .. ".luau"), "\r\n", "\n")
	local c = string.find(texto, "\nlocal function crear(", 1, true)
	assert(c, `{nombre}: no encuentro crear`)
	local _, b = string.find(texto, "\nend\n", c, true)
	local trozo = string.sub(texto, 1, b)
	trozo = string.gsub(trozo, "\n[^\n]*require%b()[^\n]*", "\n")
	trozo = string.gsub(trozo, "\nlocal [%w_]+: any[^\n]*", "\n")
	TROZOS[nombre] = trozo .. "\nreturn crear, ALTURA"
end

local function cuerpo(m, nombre: string, donde): any
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
	local crear, altura = luau.load(TROZOS[nombre], { debugName = nombre .. ".crear", environment = env })()
	return crear(donde(altura))
end

------------------------------------------------------------------------------------------------------------------------
-- Un caso: el bicho quieto delante de la cámara, aturdido `dura` s. op: dt, rendimiento.
type Op = { dt: number?, rendimiento: boolean? }
local function caso(bicho: string, dura: number, op: Op)
	local dt = op.dt or 1 / 60
	local etiqueta = `{bicho}, {if dura >= 4 then "el cepo" else "el flash"}`
		.. (if op.rendimiento then ", con Rendimiento" else "") .. (if op.dt then `, a {math.floor(1 / dt + 0.5)} fps` else "")
	local m = crearMundo()
	local g = m.global
	local Vector3, CFrame = g.Vector3, g.CFrame
	local chillidos = 0
	local function sonido()
		return g.Instance.new("Sound")
	end
	local falsoSonido = setmetatable({
		en = function(nombre: string)
			if nombre == "Chillido" then
				chillidos += 1
			end
			return sonido()
		end,
	}, { __index = function()
		return sonido
	end })
	if op.rendimiento then
		m.jugadorLocal:SetAttribute("Rendimiento", true)
	end
	m.controles = false
	m.caja(CFrame.new(0, -0.5, 0), Vector3.new(200, 1, 200), { Name = "Suelo" })
	local carpeta = g.Instance.new("Folder")
	carpeta.Name = "Bichos"
	carpeta.Parent = g.workspace
	g.workspace:SetAttribute("Fase", "Noche")
	local camara = g.workspace.CurrentCamera
	camara.CameraType = g.Enum.CameraType.Scriptable
	camara.CFrame = CFrame.new(0, 5, 12)
	-- De cara a la cámara (hacia +Z), a 12 studs: cerca (con su vida de estar parado).
	local modelo = cuerpo(m, bicho, function(alto: number)
		return CFrame.fromMatrix(Vector3.new(0, alto, 0), -Vector3.xAxis, Vector3.yAxis)
	end)
	local raiz = modelo:FindFirstChild("HumanoidRootPart")
	raiz.Anchored = true
	m.paso(dt)
	local Vista = m.cargar("src/juego/cliente/" .. bicho .. "Vista", { Sonido = falsoSonido })
	Vista.start()

	local piezas = {}
	for _, p in modelo:GetDescendants() do
		if p:IsA("BasePart") and p ~= raiz then
			table.insert(piezas, p)
		end
	end
	local cabeza = modelo:FindFirstChild("Cabeza")
	local motorCabeza = raiz:FindFirstChild("Cabeza")
	-- Lo que se mira: la cara, y las puntas que se la tapan (patas de delante, dedos) o los brazos y sus hombros.
	local function cara()
		return cabeza.CFrame * Vector3.new(0, 0, -cabeza.Size.Z / 2)
	end
	local function punta(nombre: string)
		local p = modelo:FindFirstChild(nombre)
		return p.CFrame * Vector3.new(0, -p.Size.Y / 2, 0)
	end
	local cubiertas = if bicho == "Trepador" or bicho == "Raspador" then { "AntebrazoI", "AntebrazoD" } else nil
	-- Cuánto se tapa la cara: con patas o dedos, studs de la punta más lejana a la cara (menos es más tapada); con
	-- brazos sin codo (Imitador, Acechador), studs que le quedan las manos por debajo de los hombros.
	local function tapa(): number
		if cubiertas then
			local c = cara()
			return math.max((punta(cubiertas[1]) - c).Magnitude, (punta(cubiertas[2]) - c).Magnitude)
		end
		local peor = -math.huge
		for _, nombre in { "BrazoI", "BrazoD" } do
			local motor = raiz:FindFirstChild(nombre)
			local brazo = motor.Part1
			local hombro = brazo.CFrame * motor.C1.Position
			peor = math.max(peor, hombro.Y - punta(nombre).Y)
		end
		return peor
	end
	local TAPADA = if cubiertas then CUBRE else 0 -- aturdido, como mucho esto...
	local DESTAPADA = if cubiertas then LEJOS else 2 -- ...y quieto, como poco esto

	local function bajo(p): number
		local cf, h = p.CFrame, p.Size / 2
		return cf.Position.Y - (math.abs(cf.RightVector.Y) * h.X + math.abs(cf.UpVector.Y) * h.Y + math.abs(cf.LookVector.Y) * h.Z)
	end
	local ultimas = {}
	local saltoMax = SALTO * dt * 60
	local peorSalto, peorQue = 0, ""
	local function mirar(fase: string, t: number)
		for i, p in piezas do
			local pos = p.CFrame.Position
			assert(not m.roto(p.CFrame), `{etiqueta}: NaN en {p.Name} ({fase}, {t} s)`)
			if ultimas[i] then
				local d = (pos - ultimas[i]).Magnitude
				if d > peorSalto then
					peorSalto, peorQue = d, `{p.Name} ({fase}, {t} s)`
				end
			end
			ultimas[i] = pos
		end
	end
	local function masBajo(): number
		local y = math.huge
		for _, p in piezas do
			if p.Transparency < 1 then
				y = math.min(y, bajo(p))
			end
		end
		return y
	end

	-- Quieto.
	local sueloQuieto = math.huge
	local destapadaAntes = math.huge
	m.correr(1.5, dt, function(n)
		mirar("quieto", n * dt)
		sueloQuieto = math.min(sueloQuieto, masBajo())
		if n * dt > 0.5 then
			destapadaAntes = math.min(destapadaAntes, tapa())
		end
	end)
	comprueba(destapadaAntes > DESTAPADA, `{etiqueta}: quieto, sin taparse la cara ({destapadaAntes})`)
	comprueba(chillidos == 0, `{etiqueta}: quieto, sin chillar`)

	-- Aturdido.
	modelo:SetAttribute("Aturdido", g.workspace:GetServerTimeNow() + dura)
	local tapadaPeor = -math.huge
	local sueloAturdido = math.huge
	local caraAntes = nil
	local forcejea = 0
	local cabezaQuieta: any = nil
	local cabezaSeMueve = 0
	local largo = dura >= 4 -- (BichoComun: forcejea si dura 4 s o más)
	local primerTiron = if largo and not op.rendimiento then 0.85 else dura - 0.45
	local ya = TAPADA_YA[bicho] or 0.2
	m.correr(dura, dt, function(n)
		local t = n * dt
		mirar("aturdido", t)
		sueloAturdido = math.min(sueloAturdido, masBajo())
		if t >= ya and t <= primerTiron then
			tapadaPeor = math.max(tapadaPeor, tapa())
		end
		if t >= 0.2 and t <= dura - 0.45 then
			local tr = motorCabeza.Transform
			if cabezaQuieta then
				cabezaSeMueve = math.max(cabezaSeMueve, (tr.Position - cabezaQuieta.Position).Magnitude
					+ (tr.LookVector - cabezaQuieta.LookVector).Magnitude + (tr.UpVector - cabezaQuieta.UpVector).Magnitude)
			end
			cabezaQuieta = tr
		end
		if math.abs(t - 0.85) < dt / 2 then
			caraAntes = cara() - raiz.Position
		elseif caraAntes and t > 0.85 and t < dura - 0.45 then
			forcejea = math.max(forcejea, (cara() - raiz.Position - caraAntes).Magnitude)
		end
	end)
	-- Después.
	local destapadaDespues = math.huge
	m.correr(1.5, dt, function(n)
		local t = n * dt
		mirar("después", t)
		sueloAturdido = math.min(sueloAturdido, masBajo())
		if t > 1.2 then
			destapadaDespues = math.min(destapadaDespues, tapa())
		end
	end)
	if VER then
		print(`{etiqueta}: tapa {tapadaPeor} (quieto {destapadaAntes}, después {destapadaDespues}), salto {peorSalto} en`
			.. ` {peorQue}, suelo {sueloQuieto} -> {sueloAturdido}, forcejea {forcejea}, cabeza {cabezaSeMueve},`
			.. ` chillidos {chillidos}`)
	end
	comprueba(#m.errores == 0, `{etiqueta}: sin errores ({m.errores[1]})`)
	comprueba(tapadaPeor < TAPADA, `{etiqueta}: aturdido, se tapa la cara ({tapadaPeor})`)
	comprueba(destapadaDespues > DESTAPADA, `{etiqueta}: al acabar, vuelve ({destapadaDespues})`)
	comprueba(peorSalto < saltoMax, `{etiqueta}: sin saltos ({peorSalto} en {peorQue})`)
	comprueba(sueloAturdido > sueloQuieto - SUELO, `{etiqueta}: sin meterse en el suelo ({sueloAturdido}, quieto {sueloQuieto})`)
	comprueba(chillidos == 1, `{etiqueta}: chilla una vez ({chillidos})`)
	if bicho ~= "Acechador" then
		if largo and not op.rendimiento then
			comprueba(forcejea > FORCEJEA, `{etiqueta}: forcejea ({forcejea})`)
		end
		if op.rendimiento then
			comprueba(cabezaSeMueve < 1e-3, `{etiqueta}: con Rendimiento, la cabeza quieta ({cabezaSeMueve})`)
		else
			comprueba(cabezaSeMueve > 0.02, `{etiqueta}: tiembla ({cabezaSeMueve})`)
		end
	end
end

for _, bicho in BICHOS do
	caso(bicho, FLASH, {})
	caso(bicho, FLASH, { dt = 1 / 20 })
	caso(bicho, FLASH, { rendimiento = true })
	caso(bicho, CEPO, {})
	caso(bicho, CEPO, { rendimiento = true })
end

-- La Bestia y el Golpeador, como estaban.
for _, nombre in { "BestiaVista", "GolpeadorVista" } do
	comprueba(not string.find(fs.readFile("src/juego/cliente/" .. nombre .. ".luau"), "BichoComun.aturdido", 1, true),
		`{nombre}: sin BichoComun.aturdido`)
end

print(`aturdidos: {cuentas} comprobaciones bien`)
