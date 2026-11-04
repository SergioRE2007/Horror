-- Banco del gateo debajo de las mesas (14.9.2, pedido por el usuario: "comprueba con bancos de Lune que los gateos
-- siguen sin atravesar la mesa"). Ejecutar desde la raíz: lune run tests/bancos/gateo.luau [Bicho] (mientras se llame
-- _gateo.luau, regressions.luau no lo lanza).
--   Sin nombre (como lo lanza regressions.luau): un proceso de Lune por bicho, los cinco a la vez (este mismo archivo,
--   sin ruta escrita), con la tanda corta (casosDe: los casos que más han costado y uno de cada cosa, 8 por bicho):
--   ~30 s con 4 CPU (la Bestia marca el paso). GATEO_TODO=1: los 15 casos de cada bicho, ~1 min con 4 CPU.
--   Con un nombre: solo ese bicho, en este proceso (Bestia ~26 s la tanda corta y ~55 s entera; los demás, 6-10 s y
--   ~20 s).
--   GATEO_VER=1 enseña lo peor de cada fase y lo que falla, sin parar; GATEO_SOLO="<trozo de la etiqueta>" corre solo
--   esos casos.
-- Con el Roblox de mentira (tests/bancos/_roblox.luau), en un mundo de cliente:
--   el cuerpo de verdad de cada bicho: lo de servidor/<Bicho>.luau hasta el final de su crear (que es local), sin sus
--   require, con Config y servidor/Cuerpo de verdad y un Caza de mentira (el modelo sale igual que en el servidor; se
--   monta en el mundo del cliente porque el de mentira no replica);
--   la mesa del comedor y la de la cocina como en Mapa (HUECOS se lee de Mapa.luau): el mueble con Tam y su pivote, la
--   zona Debajo con su etiqueta y las cajas Choque del tablero, las patas y la viga, con CanQuery = false;
--   la Vista de verdad del bicho, que lo anima con Gatea y GateaHora (como Caza: raíz anclada en el borde, de cara a ti).
-- Cada caso: llega andando (LLEGA studs en 1 s) y se para, gatea (Config.Postura.Gatear s, o lo deja a mitad si te
-- escapas), lo deja y sale (3 s); la Bestia, además, se va andando hacia atrás (2 s a 6 studs/s) y se para (1 s).
-- Mira fotograma a fotograma, de 0,8 a 6 studs del borde del tablero, en diagonal, con Rendimiento, a 20 fps,
-- escapándote (Gatea a nil a mitad) y pillándote (rugir, como la escena de muerte):
--   sin NaN en ninguna pieza;
--   ninguna pieza que se ve se mete más de MARGEN en el tablero (todo el Tam, de su cara de abajo arriba), las patas o la
--   viga (lo que ya se metía al llegar andando no cuenta en los primeros HEREDA s del gateo);
--   ni más de SUELO en el suelo de lo que ya se metía de pie (al gatear y salir, comparado con lo de llegar andando);
--   al andar y pararse la Bestia, en todo eso solo lo que se mete de más que en esa misma vida de andar sin gatear antes
--   (el mismo caso en otro mundo, de pie en vez de gatear y parada más rato: vidaSinGatear);
--   al acabar sale del hueco y se levanta (la cabeza vuelve a la altura de antes, o a la que lleva de pie sin gatear) y
--   no hay errores (si te pilla, TRAS_SUSTO s más: se queda en el suelo durante el susto);
--   la luz de la cara de la Bestia se enciende metida y se quita al echar a andar (con Rendimiento, nunca).
-- Si algo no se cumple, termina con error (con GATEO_VER, lo dice y sigue).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local task = require("@lune/task")
local crearMundo = require("./_roblox")

local VER = process.env.GATEO_VER ~= nil and process.env.GATEO_VER ~= ""
local TODO = process.env.GATEO_TODO ~= nil and process.env.GATEO_TODO ~= ""
local SOLO = if process.env.GATEO_SOLO ~= "" then process.env.GATEO_SOLO else nil

local cuentas = 0
local fallos = 0
local function comprueba(cond: any, etiqueta: string)
	if VER and not cond then
		print("    FALLA:", etiqueta)
		fallos += 1
	else
		assert(cond, etiqueta)
	end
	cuentas += 1
end

local MARGEN = 0.05 -- studs que puede meterse una pieza en el tablero, las patas o la viga (redondeos de la pose)
local SUELO = 0.1 -- ...y en el suelo, más de lo que ya se metía de pie (los pies apoyados y las manos clavadas rozan)
local LEVANTA = 0.5 -- studs que puede quedar la cabeza por debajo de donde estaba antes de gatear, al acabar
local LLEGA = 4 -- studs que anda hasta el sitio, en 1 s, antes de gatear
local HEREDA = 0.3 -- s del principio del gateo en los que no cuenta lo que ya se metía al llegar andando
local DIAGONAL = { 1.5, 2.5 } -- en diagonal: studs hacia fuera y a un lado del borde
local SALE = 3 -- s que se mira al dejar el gateo
local VA = 6 -- studs/s a los que se va andando la Bestia hacia atrás al acabar...
local ANDA = 2 -- ...durante estos s...
local PARA = 1 -- ...y luego parada estos s
local TRAS_SUSTO = 2 -- s más que se mira si te pilla (se queda en el suelo el susto, y sale después)
-- En la vida de andar (abajo), parada más rato: parada carga el peso de un brazo al otro cada 2,5-5 s y a azar (PESO en
-- BestiaVista), y el brazo que carga mete sus adornos ~0,2-0,3 en el suelo; con 1 s solo se vería un lado.
local PARA_VIDA = 10
local Y = 1 -- el suelo de la planta baja (ABAJO en Mapa)
local BICHOS = { "Golpeador", "Raspador", "Trepador", "Imitador", "Bestia" }

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
	local d = b.cf.Position - a.cf.Position
	-- Lejos (más que la suma de las medias diagonales): no se tocan. Casi todas las parejas; ahorra los 15 ejes.
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
-- Lo más bajo de una caja.
local function bajo(c: Caja): number
	local cf, m = c.cf, c.medio
	return cf.Position.Y - (math.abs(cf.RightVector.Y) * m.X + math.abs(cf.UpVector.Y) * m.Y + math.abs(cf.LookVector.Y) * m.Z)
end

------------------------------------------------------------------------------------------------------------------------
-- El cuerpo de verdad: lo de servidor/<Bicho>.luau hasta el final de crear (local), sin sus require.
local TROZOS: { [string]: string } = {}
local ALTURAS: { [string]: number } = {} -- de los pies al centro de la raíz (ALTURA de cada uno)
for _, nombre in BICHOS do
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
-- El mismo caso sin gatear: lo más baja que lleva la cabeza de pie mientras saldría (cabeza) y, la Bestia, por fase
-- ("andando", "parada") y pieza (por su orden en el modelo), lo que se mete en el suelo y en cada obstáculo (por su orden).
type Vida = { cabeza: number, suelo: { [string]: { [number]: number } }, obst: { [string]: { [number]: { [number]: number } } },
	nombres: { string } }

local gateo: (op: Op, vida: boolean?) -> any
local VIDAS: { [string]: Vida } = {}
-- El mismo caso (bicho, mesa, sitio, fps y Rendimiento) sin gateo: de pie en su sitio lo que gatearía y saldría y, la
-- Bestia, la misma vida de andar de después (VA, ANDA y PARA). Así lo que hace de pie (los bichos vivos se agachan,
-- respiran, cargan el peso) o al andar y pararse cerca de la mesa (que ya hace al llegar) no se le carga al gateo; sí lo
-- que deje el gateo (la pose echada atrás de la Bestia que se mezcla al echar a andar).
local function vidaSinGatear(op: Op): Vida
	local clave = `{op.bicho} {op.mesa} {op.distancia or "diagonal"} {op.dt or 0} {op.rendimiento == true}`
	if not VIDAS[clave] then
		VIDAS[clave] = gateo({ bicho = op.bicho, mesa = op.mesa, distancia = op.distancia, diagonal = op.diagonal,
			rendimiento = op.rendimiento, dt = op.dt }, true)
	end
	return VIDAS[clave]
end

function gateo(op: Op, vida: boolean?): any
	local etiqueta = `{op.bicho} en la mesa de la {op.mesa}, `
		.. (if op.diagonal then "en diagonal" else `a {op.distancia}`)
		.. (if op.rendimiento then ", con Rendimiento" else "")
		.. (if op.dt then `, a {math.floor(1 / op.dt + 0.5)} fps` else "")
		.. (if op.escapa then ", escapándote" else "")
		.. (if op.pilla then ", pillándote" else "")
	if SOLO and not vida and not string.find(etiqueta, SOLO, 1, true) then
		return nil
	end
	if VER and not vida then
		print(etiqueta)
	end
	local anda = op.bicho == "Bestia" -- la Bestia se queda echada atrás hasta que anda: se mira también eso
	local ref = if vida then nil else vidaSinGatear(op)
	local dt = op.dt or 1 / 60
	local m = crearMundo()
	local g = m.global
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
	local x1, x2, z1, z2 = h.hueco[1], h.hueco[2], h.hueco[3], h.hueco[4]
	local zonaCF = pivote * CFrame.new((x1 + x2) / 2, h.abajo / 2, (z1 + z2) / 2)
	local zonaTam = Vector3.new(x2 - x1, h.abajo, z2 - z1)
	local obstaculos: { { nombre: string, caja: Caja } } = {}
	local tu = Vector3.new(d.tu[1], d.tu[2], d.tu[3])
	do
		local casa = Instance.new("Model")
		casa.Name = "Casa"
		casa.Parent = g.workspace
		local mueble = Instance.new("Model")
		mueble.Name = d.mueble
		mueble.WorldPivot = pivote
		mueble:SetAttribute("Tam", tam)
		mueble.Parent = casa
		local function choque(nombre: string, a1, a2, y1, y2, b1, b2)
			local cf = pivote * CFrame.new((a1 + a2) / 2, (y1 + y2) / 2, (b1 + b2) / 2)
			local t = Vector3.new(a2 - a1, y2 - y1, b2 - b1)
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
		local zona = m.caja(zonaCF, zonaTam, { Name = "Debajo", Transparency = 1, CanCollide = false, CanQuery = false,
			CanTouch = false, Parent = mueble })
		zona:SetAttribute("Mueble", d.mueble)
		g.game:GetService("CollectionService"):AddTag(zona, "Debajo")
	end
	if not vida then
		local enZona = zonaCF:PointToObjectSpace(tu)
		comprueba(math.abs(enZona.X) < zonaTam.X / 2 and math.abs(enZona.Z) < zonaTam.Z / 2, etiqueta .. ": tú, en la zona Debajo")
		comprueba(pivote.LookVector:Dot(Vector3.new(d.fuera[1], d.fuera[2], d.fuera[3])) > 0.99 or op.mesa ~= "Cocina", etiqueta .. ": la cocina, de frente hacia ti")
	end

	-- Tú, debajo; el bicho, en el borde y de cara a ti (en Lune, CFrame.lookAt con vector de arriba sale mal).
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
	-- La Vista, después de un fotograma: el Roblox de mentira fija lo soldado (WeldConstraint) la primera vez que lo
	-- junta, no al crearlo; con la Vista ya moviendo los miembros, los adornos quedaban soldados donde no son.
	m.paso(dt)
	local Vista = m.cargar("src/juego/cliente/" .. op.bicho .. "Vista")
	Vista.start()
	if not vida then
		comprueba(math.abs(humanoide.HipHeight + raiz.Size.Y / 2 - ALTURAS[op.bicho]) < 1e-6, etiqueta .. ": a la altura de su Humanoid")
		comprueba((raiz.CFrame.LookVector - mira).Magnitude < 1e-3, etiqueta .. ": de cara a ti")
		comprueba(DIAGONAL[1] ^ 2 + DIAGONAL[2] ^ 2 < Postura.CercaBorde ^ 2, etiqueta .. ": la diagonal, a CercaBorde")
	end

	-- Lo que se ve del bicho (la raíz es invisible; lo que esconde al aplastarse, también).
	local piezas = {}
	for _, p in modelo:GetDescendants() do
		if p:IsA("BasePart") and p ~= raiz then
			table.insert(piezas, p)
		end
	end
	local cabeza = modelo:FindFirstChild("Cabeza")
	assert(cabeza, etiqueta .. ": sin Cabeza")
	local function nombreDe(p): string
		local s = p:FindFirstChildOfClass("WeldConstraint")
		return if s and s.Part0 then `{p.Name} de {s.Part0.Name} {p.Size}` else p.Name
	end
	local nombres = {}
	for i, p in piezas do
		nombres[i] = nombreDe(p)
	end
	if ref then
		comprueba(table.concat(ref.nombres, "|") == table.concat(nombres, "|"), etiqueta .. ": las mismas piezas que en la vida de andar")
	end
	local peor = { mete = 0, que = "" }
	local porFase: { [string]: { mete: number, que: string } } = {}
	local llegada: { [any]: { [any]: number } } = {} -- lo que se mete cada pieza en cada obstáculo al acabar de llegar
	local alLlegar: { [string]: number } = {}
	local dePie: { [any]: number } = {} -- lo que se mete cada pieza en el suelo al llegar andando, antes de gatear
	local suyo: Vida = { cabeza = math.huge, suelo = { andando = {}, parada = {} }, obst = { andando = {}, parada = {} },
		nombres = nombres }
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
		if vida and not suyo.suelo[fase] then
			return -- en la vida de andar solo cuenta lo de andar y pararse
		end
		for i, p in piezas do
			local cf = p.CFrame
			assert(not m.roto(cf), `{etiqueta}: NaN en {p.Name} ({fase}, {t} s)`)
			if p.Transparency < 1 and p.LocalTransparencyModifier < 1 then
				local caja = { cf = cf, medio = p.Size / 2 }
				for k, o in obstaculos do
					-- Lo que ya se metía al llegar andando (antes de gatear: la vida de andar, fuera de lo que mira este banco)
					-- no cuenta en los primeros HEREDA s del gateo, que salen de ahí: solo lo que se mete de más. Al andar y
					-- pararse después, lo mismo con lo que se mete en esa vida de andar sin gatear antes.
					local mete = seMete(caja, o.caja)
					local vidaFase = suyo.obst[fase]
					if vidaFase then
						local porPieza = vidaFase[i] or {}
						porPieza[k] = math.max(porPieza[k] or 0, mete)
						vidaFase[i] = porPieza
					end
					if vida then
						continue
					end
					if ref and ref.obst[fase] then
						mete -= (ref.obst[fase][i] or {})[k] or 0
					end
					if fase == "llegando" then
						local antes = llegada[p] or {}
						antes[o] = mete
						llegada[p] = antes
						if mete > MARGEN then
							alLlegar[`{nombres[i]} en {o.nombre}`] = math.max(alLlegar[`{nombres[i]} en {o.nombre}`] or 0, mete)
						end
						continue
					end
					if fase == "gateando" and t < HEREDA then
						mete -= (llegada[p] or {})[o] or 0
					end
					if mete > MARGEN then
						apuntar(fase, mete, `{nombres[i]} en {o.nombre} ({fase}, {string.format("%.2f", t)} s)`)
					end
				end
				-- En el suelo, lo que ya se mete andando es del modelo (las piernas y los dedos pasan del suelo para que se
				-- vean apoyados): se mira lo que se mete de más. Al gatear y salir, de más que al llegar andando; al andar y
				-- pararse después, de más que en esa misma vida de andar sin gatear antes.
				local suelo = Y - bajo(caja)
				if fase == "llegando" then
					dePie[p] = math.max(dePie[p] or 0, suelo)
				end
				local vidaFase = suyo.suelo[fase]
				if vidaFase then
					vidaFase[i] = math.max(vidaFase[i] or 0, suelo)
				end
				if vida then
					continue
				end
				local antes, de = dePie[p] or 0, "llegando"
				if ref and ref.suelo[fase] then
					antes, de = ref.suelo[fase][i] or 0, `{fase} sin gatear`
				end
				local deMas = suelo - math.max(antes, 0)
				if deMas > SUELO then
					apuntar(fase, deMas - SUELO + MARGEN, `{nombres[i]} {string.format("%.2f", suelo)} en el suelo ({de}, `
						.. `{string.format("%.2f", antes)}; {fase}, {string.format("%.2f", t)} s)`)
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

	-- Llega, gatea y lo deja (en la vida de andar, se queda de pie ese rato).
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
	if vida then
		correr("de pie", GATEAR + SALE, function(t)
			if t >= GATEAR then
				suyo.cabeza = math.min(suyo.cabeza, cabeza.Position.Y)
			end
		end)
		if not anda then
			return suyo
		end
	else
		modelo:SetAttribute("GateaHora", g.workspace:GetServerTimeNow())
		modelo:SetAttribute("Gatea", tu)
	end
	local luz = -1
	local function luzDe(): number
		local a = cabeza:FindFirstChild("LuzGatea")
		local foco = a and a:FindFirstChildOfClass("PointLight")
		return if foco then foco.Brightness else -1
	end
	if not vida then
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
		correr("saliendo", SALE)
		if op.pilla and not anda then
			-- Se queda en el suelo lo que dura el susto (Susto, 2,2 s en sus Vistas) y luego sale: hasta que se levanta.
			correr("tras el susto", TRAS_SUSTO)
		end
	end
	if anda then
		-- Echada atrás hasta que anda: se va andando hacia atrás, como haría al seguir con lo suyo.
		local va = -mira * VA
		correr("andando", ANDA, function()
			raiz.AssemblyLinearVelocity = va
			modelo:PivotTo(raiz.CFrame + va * dt)
		end)
		raiz.AssemblyLinearVelocity = Vector3.zero
		correr("parada", if vida then PARA_VIDA else PARA)
		if vida then
			return suyo
		end
		if op.rendimiento then
			comprueba(luz < 0, `{etiqueta}: sin luz en la cara con Rendimiento`)
		else
			comprueba(luz > 0.3 and luz <= 0.5 + 1e-6, `{etiqueta}: luz floja en la cara metida ({luz})`)
		end
		comprueba(cabeza:FindFirstChild("LuzGatea") == nil, `{etiqueta}: la luz se quita al acabar`)
	end
	if VER then
		for que, mete in alLlegar do
			print("    (al llegar andando)", string.format("%.3f", mete), que)
		end
		for _, f in porFase do
			print("   ", string.format("%.3f", f.mete), f.que)
		end
	else
		comprueba(peor.mete <= MARGEN, `{etiqueta}: atraviesa {string.format("%.3f", peor.mete)}: {peor.que}`)
	end
	-- Fuera del hueco y de pie otra vez.
	local hueco = { cf = zonaCF, medio = zonaTam / 2 }
	for i, p in piezas do
		if p.Transparency < 1 then
			comprueba(seMete({ cf = p.CFrame, medio = p.Size / 2 }, hueco) <= MARGEN, `{etiqueta}: al acabar, {nombres[i]} sigue debajo`)
		end
	end
	-- De pie se agacha a ratos (vivo): la altura de antes, o lo más bajo que la lleva de pie sin gatear ese rato.
	local deVuelta = math.min(cabezaAntes.Y, (ref :: Vida).cabeza)
	comprueba(cabeza.Position.Y > deVuelta - LEVANTA,
		`{etiqueta}: al acabar se levanta ({cabeza.Position.Y}; de pie, {cabezaAntes.Y}, y sin gatear, {(ref :: Vida).cabeza})`)
	comprueba(#m.errores == 0, `{etiqueta}: errores\n{table.concat(m.errores, "\n")}`)
	return peor
end

------------------------------------------------------------------------------------------------------------------------
-- Los casos de un bicho. CORTA (por defecto): los que más han costado y uno de cada cosa; con GATEO_TODO, los 15.
local function casosDe(bicho: string): { Op }
	local casos: { Op } = {}
	local function caso(mesa: string, mas: { [string]: any }, corta: boolean)
		if TODO or corta then
			local op = table.clone(mas)
			op.bicho, op.mesa = bicho, mesa
			table.insert(casos, op :: any)
		end
	end
	for _, distancia in { 0.8, 1.5, 2.5, 4, 6 } do
		caso("Comedor", { distancia = distancia }, distancia == 0.8)
	end
	caso("Comedor", { diagonal = true }, true)
	caso("Comedor", { distancia = 2.5, rendimiento = true }, false)
	caso("Comedor", { distancia = 2.5, dt = 1 / 20 }, true)
	caso("Comedor", { distancia = 2.5, escapa = 1 }, true)
	caso("Comedor", { distancia = 2.5, pilla = true }, true)
	for _, distancia in { 0.8, 2.5, 6 } do
		caso("Cocina", { distancia = distancia }, distancia == 0.8)
	end
	caso("Cocina", { diagonal = true }, true)
	caso("Cocina", { distancia = 2.5, rendimiento = true }, true)
	return casos
end

local solo = process.args[1]
if solo then
	assert(table.find(BICHOS, solo), `no conozco el bicho {solo}`)
	for _, op in casosDe(solo) do
		gateo(op)
	end
	print(`gateo {solo}: {cuentas} comprobaciones bien` .. (if fallos > 0 then `, {fallos} fallan` else ""))
	if fallos > 0 then
		process.exit(1)
	end
else
	-- Un proceso por bicho, todos a la vez (process.exec cede): este mismo archivo, con el nombre del bicho.
	local este = string.gsub(debug.info(1, "s"), "^@", "")
	if not string.match(este, "%.luau$") then
		este ..= ".luau"
	end
	local salidas = {}
	local quedan = #BICHOS
	for i, bicho in BICHOS do
		task.spawn(function()
			salidas[i] = process.exec("lune", { "run", este, bicho })
			quedan -= 1
		end)
	end
	while quedan > 0 do
		task.wait(0.05)
	end
	local total, mal = 0, {}
	for i, r in salidas do
		if VER or not r.ok then
			print(r.stdout .. r.stderr)
		end
		if r.ok then
			total += tonumber(string.match(r.stdout, "(%d+) comprobaciones bien")) or 0
		else
			table.insert(mal, BICHOS[i])
		end
	end
	assert(#mal == 0, `gateo: fallan {table.concat(mal, ", ")}`)
	print(`gateo: {total} comprobaciones bien`)
end
