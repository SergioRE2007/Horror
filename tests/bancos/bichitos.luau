-- Banco de los bichitos (docs/sistemas/bichitos.md). Ejecutar desde la raíz: lune run tests/bancos/bichitos.luau (lo
-- corre tests/regressions.luau). Carga src/juego/cliente/BichitosVista.luau de verdad con el Roblox de mentira
-- (_roblox.luau) y Ambiente y Sonido falsos. Hay un trastero con su suelo y sus cuatro paredes, el suelo de la cocina,
-- una bombilla y un charco lejos de la casa.
--   Ratas: nacen en el suelo de la sala (2-3 en el trastero), nunca salen del rectángulo, ni se meten en las paredes, ni
--     dejan el suelo, ni tienen NaN; con una pared en medio la linterna no las espanta; de cerca huyen; con la linterna
--     encima huyen y se esconden; al rato vuelven; con un bicho cerca se esconden todas y no salen hasta que se va.
--   Rendimiento: una rata por sala y ninguna cucaracha ni mosca. Lejos de todo, nada (y el bucle desconectado).
--   Cucarachas en la cocina; polillas en la bombilla encendida (y ninguna apagada); moscas en el charco a los pocos
--     segundos; la polilla de la linterna de noche fuera, que se va al apagarla.
-- Si algo no se cumple, termina con error.
local crearMundo = require("./_roblox")

local cuentas = 0
local function comprobar(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end

local m = crearMundo()
local g = m.global
local Vector3, CFrame, Instance = g.Vector3, g.CFrame, g.Instance
local CollectionService = m.servicio("CollectionService")
local jugador = m.jugadorLocal
local camara = m.camara
local Config = m.cargar("src/shared/Config")
local CFG = Config.Bichitos

local function sala(nombre: string): any
	for _, s in CFG.Salas do
		if s.Nombre == nombre then
			return s
		end
	end
	error("no hay sala " .. nombre)
end
local T = sala("Trastero")
local C = sala("Cocina")

-- El mundo: el trastero (suelo en y = 1 y paredes con la cara justo en el borde del rectángulo) y el suelo de la cocina.
local mapa = Instance.new("Folder")
mapa.Name = "Mapa"
mapa.Parent = g.workspace
local function caja(cf: any, tam: any, nombre: string): any
	local p = m.caja(cf, tam, { Name = nombre })
	p.Parent = mapa
	return p
end
local cx, cz = (T.x1 + T.x2) / 2, (T.z1 + T.z2) / 2
local ancho, fondo = T.x2 - T.x1, T.z2 - T.z1
caja(CFrame.new(cx, T.Suelo - 0.5, cz), Vector3.new(ancho + 2, 1, fondo + 2), "Suelo")
caja(CFrame.new(T.x1 - 0.5, T.Suelo + 6, cz), Vector3.new(1, 12, fondo + 2), "Pared")
caja(CFrame.new(T.x2 + 0.5, T.Suelo + 6, cz), Vector3.new(1, 12, fondo + 2), "Pared")
caja(CFrame.new(cx, T.Suelo + 6, T.z1 - 0.5), Vector3.new(ancho + 2, 12, 1), "Pared")
caja(CFrame.new(cx, T.Suelo + 6, T.z2 + 0.5), Vector3.new(ancho + 2, 12, 1), "Pared")
caja(CFrame.new((C.x1 + C.x2) / 2, C.Suelo - 0.5, (C.z1 + C.z2) / 2), Vector3.new(C.x2 - C.x1 + 2, 1, C.z2 - C.z1 + 2), "Suelo")

local sonados: { string } = {}
local SonidoFalso = {
	sonados = sonados,
	en = function(nombre: string, _pos: any, _tono: number?): any
		table.insert(sonados, nombre)
		return Instance.new("Sound")
	end,
	hay = function(_nombre: string): boolean
		return false
	end,
	bucle = function(_nombre: string, _padre: any): any
		return Instance.new("Sound")
	end,
}
local AmbienteFalso = { factor = {} }

local function mirarA(desde: any, hacia: any)
	local f = (hacia - desde).Unit
	local derecha = f:Cross(Vector3.yAxis).Unit
	camara.CFrame = CFrame.fromMatrix(desde, derecha, derecha:Cross(f), -f)
end
-- Fuera del trastero, al otro lado de la pared de z2 (en el baño): a menos de Cerca, sin ver dentro.
local BANO = Vector3.new(cx, T.Suelo + 4.5, T.z2 + 9)
mirarA(BANO, Vector3.new(cx, T.Suelo, cz))

local Bichitos = m.cargar("src/juego/cliente/BichitosVista", { Ambiente = AmbienteFalso, Sonido = SonidoFalso })
Bichitos.start()
local E = Bichitos.estado()

local function salaDe(nombre: string): any
	for _, s in E.salas do
		if s.datos.Nombre == nombre then
			return s
		end
	end
	error("no hay sala " .. nombre)
end
local trastero = salaDe("Trastero")
local cocina = salaDe("Cocina")

local function roto(v: any): boolean
	return m.roto(v)
end

-- Lo que se mira en cada fotograma de las ratas del trastero.
local function mirarRatas(etiqueta: string)
	for _, b in trastero.bichos do
		comprobar(not roto(b.pos), `{etiqueta}: rata sin NaN`)
		comprobar(b.pos.X >= T.x1 - 1e-6 and b.pos.X <= T.x2 + 1e-6 and b.pos.Z >= T.z1 - 1e-6 and b.pos.Z <= T.z2 + 1e-6,
			`{etiqueta}: rata dentro del rectángulo ({b.pos})`)
		comprobar(math.abs(b.pos.Y - T.Suelo) < 1e-3, `{etiqueta}: rata en el suelo ({b.pos.Y})`)
		if b.visible then
			for i = 1, 7 do -- cuerpo y cabeza (la cola puede rozar la pared de espaldas)
				local p = b.partes[i].Position
				comprobar(not roto(p), `{etiqueta}: pieza sin NaN`)
				comprobar(p.X > T.x1 - 0.05 and p.X < T.x2 + 0.05 and p.Z > T.z1 - 0.05 and p.Z < T.z2 + 0.05,
					`{etiqueta}: {b.partes[i].Name} fuera de las paredes ({p}, {b.estado}, rata en {b.pos})`)
				comprobar(p.Y > T.Suelo - 0.05, `{etiqueta}: {b.partes[i].Name} bajo el suelo`)
			end
		end
	end
end
local function cuantas(s: any, estado: string?): number
	local n = 0
	for _, b in s.bichos do
		if estado == nil or b.estado == estado then
			n += 1
		end
	end
	return n
end

-- Nacen y pasean, sin asustarse (lejos, sin luz). ----------------------------------------------------------------------
m.correr(1, 1 / 30)
comprobar(trastero.viva, "el trastero tiene vida a menos de Cerca")
comprobar(#trastero.bichos >= T.Ratas[1] and #trastero.bichos <= T.Ratas[2], `ratas en el trastero ({#trastero.bichos})`)
comprobar(#trastero.huecos == 4, "cuatro rincones")
comprobar(#trastero.agujeros >= 4, "un agujerito en cada rincón con pared")
comprobar(not cocina.viva, "la cocina, lejos: sin vida")
comprobar(Bichitos.estado().animando, "el bucle anima")
m.correr(20, 1 / 30, function()
	mirarRatas("paseo")
	comprobar(cuantas(trastero, "huye") == 0, "nadie huye sin susto")
end)

-- La linterna desde el otro lado de la pared: no las ve. ---------------------------------------------------------------
jugador:SetAttribute("Linterna", true)
m.correr(3, 1 / 30, function(n)
	if n % 10 == 0 then
		local b = trastero.bichos[1 + (n // 10) % #trastero.bichos]
		mirarA(BANO, b.pos)
	end
	mirarRatas("pared")
	comprobar(cuantas(trastero, "huye") == 0, "con la pared en medio la linterna no espanta")
end)

-- Dentro, con la linterna apagada: las de cerca huyen y se esconden. ---------------------------------------------------
jugador:SetAttribute("Linterna", false)
local DENTRO = Vector3.new(cx, T.Suelo + 4.5, T.z2 - 1)
for _ = 1, 3 do
	mirarA(DENTRO, Vector3.new(cx, T.Suelo, T.z1))
	m.correr(0.2, 1 / 30)
	for _, b in trastero.bichos do
		if b.estado ~= "fuera" and b.estado ~= "huye" then
			local d = Vector3.new(b.pos.X - DENTRO.X, 0, b.pos.Z - DENTRO.Z).Magnitude
			comprobar(d >= CFG.Rata.Susto - 0.5, `de cerca huye (a {d} studs y {b.estado})`)
		end
	end
end
m.correr(3, 1 / 30, function()
	mirarRatas("de cerca")
end)

-- La linterna encima de una que se ve: huye y se mete. -----------------------------------------------------------------
-- Desde la puerta, mirando a cada una que esté a la vista y lejos del susto.
local alumbradas = 0
local chillidos = #SonidoFalso.sonados
for _ = 1, 8 do
	local objetivo = nil
	for _, b in trastero.bichos do
		if b.estado ~= "fuera" and b.estado ~= "huye" then
			objetivo = b
		end
	end
	if not objetivo then
		m.correr(5, 1 / 30) -- esperar a que salga alguna
		continue
	end
	jugador:SetAttribute("Linterna", false)
	local desde = objetivo.pos + Vector3.new(0, 4.5, 0)
		+ (Vector3.new(cx, 0, cz) - Vector3.new(objetivo.pos.X, 0, objetivo.pos.Z)).Unit * 0.01
	-- Que la cámara esté a más de Susto: en el rincón de la sala más lejos de ella.
	local mejor, lejos = desde, -1
	for _, e in { { T.x1 + 0.6, T.z1 + 0.6 }, { T.x2 - 0.6, T.z1 + 0.6 }, { T.x1 + 0.6, T.z2 - 0.6 }, { T.x2 - 0.6, T.z2 - 0.6 } } do
		local p = Vector3.new(e[1], T.Suelo + 4.5, e[2])
		local d = Vector3.new(p.X - objetivo.pos.X, 0, p.Z - objetivo.pos.Z).Magnitude
		if d > lejos then
			mejor, lejos = p, d
		end
	end
	if lejos < CFG.Rata.Susto + 0.5 then
		m.correr(2, 1 / 30)
		continue
	end
	mirarA(mejor, objetivo.pos)
	m.correr(0.1, 1 / 30)
	if objetivo.estado == "huye" or objetivo.estado == "fuera" then
		m.correr(2, 1 / 30) -- se asustó sola al acercar la cámara: otra
		continue
	end
	jugador:SetAttribute("Linterna", true)
	m.correr(0.15, 1 / 30, function()
		mirarA(mejor, objetivo.pos)
	end)
	comprobar(objetivo.estado == "huye" or objetivo.estado == "fuera", `la linterna la espanta ({objetivo.estado})`)
	m.correr(4, 1 / 30, function()
		mirarRatas("linterna")
	end)
	comprobar(objetivo.estado == "fuera", `se ha escondido ({objetivo.estado})`)
	comprobar(objetivo.partes[1].Transparency == 1, "escondida no se ve")
	alumbradas += 1
	if alumbradas >= 2 then
		break
	end
end
comprobar(alumbradas >= 1, "alguna rata alumbrada")
comprobar(#sonados > chillidos or #sonados > 0, "chillan al huir (provisional: Cruje)")
comprobar(sonados[1] == "Cruje", "el chillido provisional es Cruje")

-- Al rato vuelven (con la cámara fuera, en el baño). --------------------------------------------------------------------
jugador:SetAttribute("Linterna", false)
mirarA(BANO, Vector3.new(cx, T.Suelo, cz))
m.correr(CFG.Rata.Vuelve[2] + 8, 1 / 20, function()
	mirarRatas("vuelven")
end)
comprobar(cuantas(trastero, "fuera") == 0, `vuelven todas ({cuantas(trastero, "fuera")} escondidas)`)

-- Un bicho cerca: todas se esconden, sin un ruido, y no salen hasta que se va. -------------------------------------------
local carpetaBichos = Instance.new("Folder")
carpetaBichos.Name = "Bichos"
carpetaBichos.Parent = g.workspace
local bicho = Instance.new("Model")
bicho.Name = "Golpeador"
local raiz = m.caja(CFrame.new(cx, T.Suelo + 3, T.z2 + 7), Vector3.new(2, 2, 1), { Name = "HumanoidRootPart", CanCollide = false })
raiz.Parent = bicho
bicho.Parent = carpetaBichos
local antes = #SonidoFalso.sonados
m.correr(4, 1 / 30, function()
	mirarRatas("bicho")
end)
comprobar(trastero.bicho ~= nil, "la sala sabe que hay un bicho")
comprobar(cuantas(trastero, "fuera") == #trastero.bichos, "con un bicho cerca, todas escondidas")
comprobar(#SonidoFalso.sonados == antes, "esconderse del bicho no suena")
m.correr(CFG.Rata.Vuelve[2] + 10, 1 / 15)
comprobar(cuantas(trastero, "fuera") == #trastero.bichos, "mientras siga el bicho, ninguna sale")
bicho:Destroy()
m.correr(CFG.Rata.Vuelve[2] + 8, 1 / 20, function()
	mirarRatas("se va el bicho")
end)
comprobar(trastero.bicho == nil, "el bicho se fue")
comprobar(cuantas(trastero, "fuera") == 0, "sin bicho, vuelven")

-- Rendimiento: una rata por sala; en la cocina, ninguna cucaracha. ------------------------------------------------------
jugador:SetAttribute("Rendimiento", true)
m.correr(1, 1 / 30)
comprobar(#trastero.bichos == CFG.Rendimiento.Ratas, `con Rendimiento, {CFG.Rendimiento.Ratas} rata ({#trastero.bichos})`)
local COCINA = Vector3.new((C.x1 + C.x2) / 2, C.Suelo + 4.5, (C.z1 + C.z2) / 2)
mirarA(COCINA, COCINA + Vector3.new(0, -4, -3))
m.correr(1, 1 / 30)
comprobar(cocina.viva and #cocina.bichos == 0, "con Rendimiento, sin cucarachas")
comprobar(not trastero.viva, "el trastero, lejos de la cocina: sin vida")
jugador:SetAttribute("Rendimiento", false)
m.correr(1, 1 / 30)
comprobar(#cocina.bichos >= C.Cucarachas[1] and #cocina.bichos <= C.Cucarachas[2], `cucarachas en la cocina ({#cocina.bichos})`)
for _, b in cocina.bichos do
	comprobar(not b.rata and math.abs(b.pos.Y - C.Suelo) < 1e-3, "cucaracha en el suelo")
end
m.correr(5, 1 / 30, function()
	for _, b in cocina.bichos do
		comprobar(not roto(b.pos) and b.pos.X >= C.x1 and b.pos.X <= C.x2 and b.pos.Z >= C.z1 and b.pos.Z <= C.z2,
			"cucaracha dentro de la cocina")
	end
end)

-- Lejos de todo: nada, y el bucle parado. -------------------------------------------------------------------------------
local LEJOS = Vector3.new(300, 6, 300)
mirarA(LEJOS, LEJOS + Vector3.new(0, 0, -5))
m.correr(1, 1 / 30)
comprobar(not cocina.viva and not trastero.viva, "lejos, ninguna sala con vida")
comprobar(#(g.workspace:FindFirstChild("Bichitos"):GetChildren()) == 0, "lejos, ninguna pieza")
comprobar(not Bichitos.estado().animando, "sin nada que animar, el bucle desconectado")

-- Polillas en una bombilla encendida (las Lampara del generador). -------------------------------------------------------
local lampara = caja(CFrame.new(300, 10, 300), Vector3.new(0.5, 0.6, 0.5), "Lampara")
lampara.CanCollide = false
local luz = Instance.new("PointLight")
luz.Parent = lampara
m.correr(1, 1 / 30)
local bombilla = E.bombillas[luz]
comprobar(bombilla ~= nil, "la bombilla se apunta")
comprobar(#bombilla.polillas >= CFG.Polillas[1] and #bombilla.polillas <= CFG.Polillas[2], "polillas en la bombilla")
m.correr(5, 1 / 30, function()
	for _, p in bombilla.polillas do
		local d = (p.pieza.Position - lampara.Position).Magnitude
		comprobar(not roto(p.pieza.Position) and d < 3.5, `la polilla da vueltas a la bombilla ({d})`)
	end
end)
luz.Enabled = false
m.correr(1, 1 / 30)
comprobar(#bombilla.polillas == 0, "bombilla apagada, sin polillas")
luz.Enabled = true

-- Moscas en un charco de sangre. ---------------------------------------------------------------------------------------
local charco = m.caja(CFrame.new(302, 0.05, 300), Vector3.new(4, 0.05, 4), { Name = "Charco", CanCollide = false })
CollectionService:AddTag(charco, "Charco")
m.correr(1, 1 / 30)
local c = E.charcos[charco]
comprobar(c ~= nil and #c.moscas == 0, "las moscas tardan en llegar")
m.correr(CFG.Moscas.Llegan, 1 / 30)
comprobar(#c.moscas >= CFG.Moscas.Cuantas[1] and #c.moscas <= CFG.Moscas.Cuantas[2], `moscas en el charco ({#c.moscas})`)
m.correr(8, 1 / 30, function()
	for _, mosca in c.moscas do
		local p = mosca.pieza.Position
		local plana = Vector3.new(p.X - charco.Position.X, 0, p.Z - charco.Position.Z).Magnitude
		comprobar(not roto(p) and plana < 2.3 and p.Y >= charco.Position.Y and p.Y < charco.Position.Y + 1.4,
			`la mosca zumba sobre el charco ({p})`)
	end
end)
jugador:SetAttribute("Rendimiento", true)
m.correr(1, 1 / 30)
comprobar(#c.moscas == 0, "con Rendimiento, sin moscas")
comprobar(#bombilla.polillas == CFG.Rendimiento.Polillas, "con Rendimiento, una polilla")
jugador:SetAttribute("Rendimiento", false)
charco:Destroy()
m.correr(1, 1 / 30)
comprobar(E.charcos[charco] == nil, "el charco que se va se olvida")

-- La polilla de la linterna: de noche, fuera de casa. -------------------------------------------------------------------
lampara:Destroy()
g.workspace:SetAttribute("Fase", "Noche")
jugador:SetAttribute("Linterna", true)
local llego = false
m.correr(CFG.PolillaLinterna.Cada[2] + 5, 1 / 20, function()
	local v = Bichitos.estado().visita
	if v then
		llego = true
		local d = (v.m.pieza.Position - camara.CFrame.Position).Magnitude
		comprobar(not roto(v.m.pieza.Position) and d < 20 and d > 0.5, `la polilla revolotea delante ({d})`)
	end
end)
comprobar(llego, "de noche fuera, una polilla acude a la linterna")
m.correr(30, 1 / 20, function()
	if Bichitos.estado().visita then
		llego = true
	end
end)
jugador:SetAttribute("Linterna", false)
m.correr(2.5, 1 / 20)
comprobar(Bichitos.estado().visita == nil, "al apagar la linterna, se va")

print(`bichitos: {cuentas} comprobaciones bien`)
