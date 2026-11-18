-- Banco de las puertas que revientan (docs/sistemas/puerta-rota.md). Carga src/juego/cliente/CasaVista.luau y
-- PuertaRotaVista.luau de verdad con el Roblox de mentira (tests/bancos/_roblox.luau) y un Sonido falso que apunta lo
-- que suena. Mira las cuentas (etapas, la hoja colgando sin meterse en el suelo, la caída y el balanceo) y una puerta
-- de verdad: cede a la mitad y al cuarto, revienta (astillas, picos, pomo, hoja colgando), las astillas se anclan y
-- crujen al pisarlas, y al repararla todo vuelve. Con Rendimiento: 5 astillas, sin tablas ni pomo. Sin NaN nunca.
-- Ejecutar desde la raíz: lune run tests/bancos/puerta-rota.luau (lo corre regressions.luau).
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
local Config = m.cargar("src/shared/Config")
local P = Config.PuertaRota

local sonados: { string } = {}
m.falso("Sonido", {
	en = function(nombre: string)
		table.insert(sonados, nombre)
		local s = Instance.new("Sound")
		s.Parent = g.workspace
		return s
	end,
})
m.falso("ManosGestos", { sobresalto = function() end })
local CasaVista = m.cargar("src/juego/cliente/CasaVista")
local R = m.cargar("src/juego/cliente/PuertaRotaVista")

local function angulo(a: any, b: any): number -- grados entre dos giros
	local d = a:ToObjectSpace(b)
	local _, y = d:ToEulerAnglesYXZ()
	return math.deg(math.abs(y))
end
local function yMin(cf: any, tam: any): number
	local bajo = math.huge
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				bajo = math.min(bajo, (cf * Vector3.new(sx * tam.X / 2, sy * tam.Y / 2, sz * tam.Z / 2)).Y)
			end
		end
	end
	return bajo
end

---------------------------------------------------------------- cuentas

do
	comprobar(R.etapa(100, 100) == 0, "etapa: sana")
	comprobar(R.etapa(49, 100) == 1, "etapa: a menos de la mitad cede una")
	comprobar(R.etapa(24, 100) == 2, "etapa: a menos de un cuarto, otra")
	comprobar(R.etapa(0, 100) == 3, "etapa: echada abajo")
	comprobar(R.etapa(130, 150) == 0 and R.etapa(70, 150) == 1, "etapa: con refuerzo cuenta la máxima")
	comprobar(R.tablas(3.8) == 5 and R.tablas(1) == 3, "tablas: según el ancho")
	comprobar(R.rebote(0) == 0 and R.rebote(1) == 1, "rebote: empieza y acaba")
	for t = 0, 1, 0.05 do
		local v = R.rebote(t)
		comprobar(v >= 0 and v <= 1, "rebote: no se sale")
	end
	comprobar(R.mecer(0) == 0 and R.mecer(P.Mecer.Segundos) == 0, "mecer: quieta al empezar y al acabar")
	for t = 0, P.Mecer.Segundos, 0.1 do
		comprobar(math.abs(R.mecer(t)) <= P.Mecer.Grados, "mecer: acotado")
	end
	-- La hoja colgando: hacia la sala, sin meterse en el suelo, la parte de arriba volcada hacia la sala.
	for _, caso in { { giro = 1, hacia = Vector3.new(0, 0, -1) }, { giro = -1, hacia = Vector3.new(0, 0, 1) } } do
		for _, rot in { 0, 1.1, -2.3 } do
			local eje = CFrame.Angles(0, rot, 0)
			local bisagra = CFrame.new(10, 2, 5) * eje
			local hacia = eje:VectorToWorldSpace(caso.hacia)
			-- que `giro` abra hacia `hacia` (como lo calcula CasaVista)
			local giro = if (bisagra * CFrame.Angles(0, math.rad(90), 0)).RightVector:Dot(hacia) > 0 then 1 else -1
			local tam = Vector3.new(3.8, 7.9, 0.35)
			local hojaRel = CFrame.new(2, 4, 0)
			local cf = R.colgada(bisagra, hojaRel, tam, giro, hacia)
			comprobar(not m.roto(cf), "colgada: sin NaN")
			local hoja = cf * hojaRel
			comprobar(yMin(hoja, tam) >= bisagra.Position.Y + 0.01, "colgada: no se mete en el suelo")
			local cerrada = bisagra * hojaRel
			comprobar((hoja.Position - cerrada.Position):Dot(hacia) > 0.5, "colgada: hacia la sala")
			local gira = angulo(bisagra, cf)
			comprobar(gira > P.Colgada.Giro - 6 and gira < P.Colgada.Giro + 6, `colgada: torcida unos 25° ({gira})`)
			local arriba = hoja * Vector3.new(0, tam.Y / 2, 0)
			local abajo = hoja * Vector3.new(0, -tam.Y / 2, 0)
			comprobar((arriba - abajo):Dot(hacia) > 0, "colgada: volcada hacia la sala")
			local cerradura = hoja * Vector3.new(tam.X / 2, -tam.Y / 2, 0)
			local lado = hoja * Vector3.new(-tam.X / 2, -tam.Y / 2, 0)
			comprobar(cerradura.Y < lado.Y, "colgada: cae del lado de la cerradura")
		end
	end
end

---------------------------------------------------------------- una puerta de verdad

local SUELO = 0
m.caja(CFrame.new(0, SUELO - 0.5, 0), Vector3.new(80, 1, 80), { Name = "Suelo" })

local function nuevaPuerta(x: number, vida: number?): any
	local ancho, alto = 4, 8
	local eje = Vector3.new(1, 0, 0)
	local pie = Vector3.new(x, SUELO, 0)
	local bisagra = CFrame.fromMatrix(pie - eje * (ancho / 2), eje, Vector3.yAxis)
	local modelo = Instance.new("Model")
	modelo.Name = "Puerta"
	local hoja = Instance.new("Part")
	hoja.Name = "Hoja"
	hoja.Anchored = true
	hoja.Size = Vector3.new(ancho - 0.2, alto - 0.1, 0.35)
	hoja.CFrame = bisagra * CFrame.new(ancho / 2, alto / 2, 0)
	hoja.Parent = modelo
	local pomo = Instance.new("Part")
	pomo.Name = "Pomo"
	pomo.Anchored = true
	pomo.Size = Vector3.new(0.3, 0.3, 0.8)
	pomo.CFrame = hoja.CFrame * CFrame.new(ancho / 2 - 0.6, -0.4, 0)
	pomo.Parent = modelo
	modelo:SetAttribute("Bisagra", bisagra)
	modelo:SetAttribute("Hacia", Vector3.new(0, 0, 1)) -- la sala, hacia +Z
	modelo:SetAttribute("Ancho", ancho)
	modelo:SetAttribute("Vida", vida or 100)
	modelo:SetAttribute("VidaMax", 100)
	modelo:SetAttribute("Abierta", vida == 0)
	modelo.Parent = g.workspace
	CollectionService:AddTag(modelo, "Puerta")
	return modelo
end

CasaVista.start()
R.start()
local puerta = nuevaPuerta(0)
m.paso(1 / 60)
local d = CasaVista.puertas[puerta]
comprobar(d ~= nil, "puerta: CasaVista la da a PuertaRotaVista")
local hoja, pomo = puerta.Hoja, puerta.Pomo
local cerrada = hoja.CFrame

local function sinNaN(etiqueta: string)
	comprobar(not m.roto(hoja.CFrame) and not m.roto(pomo.CFrame), etiqueta .. ": hoja sin NaN")
	for _, pz in d.piezas do
		comprobar(not m.roto(pz.parte.CFrame), etiqueta .. ": tablas sin NaN")
	end
end
local function correr(segundos: number, etiqueta: string)
	m.correr(segundos, 1 / 60, function()
		sinNaN(etiqueta)
	end)
end
local function haciaSala(p: any): number
	return (p.Position - cerrada.Position):Dot(Vector3.new(0, 0, 1))
end

-- Sana: nada.
correr(0.2, "sana")
comprobar(#d.piezas == 0 and hoja.Transparency == 0, "sana: hoja entera")

-- A menos de la mitad: la hoja se parte en tablas y un trozo se mete hacia dentro.
puerta:SetAttribute("Vida", 45)
correr(0.3, "cede")
comprobar(hoja.Transparency == 1 and #d.piezas >= 5, "cede: hoja en tablas")
local metidos = 0
for _, pz in d.piezas do
	if pz.parte.Name == "Medio" and haciaSala(pz.parte) > P.Metido * 0.6 then
		metidos += 1
	end
end
comprobar(metidos == 1, `cede: un trozo metido hacia la sala ({metidos})`)
comprobar(table.find(sonados, "Crujido") ~= nil, "cede: cruje")
puerta:SetAttribute("Vida", 20)
correr(0.3, "cede otra")
metidos = 0
for _, pz in d.piezas do
	if pz.parte.Name == "Medio" and haciaSala(pz.parte) > P.Metido * 0.6 then
		metidos += 1
	end
end
comprobar(metidos == 2, "cede: el segundo trozo")
local tablasAntes = #d.piezas
local yaSueltas = #R.astillasDe(puerta) -- las pocas que saltan al ceder
comprobar(yaSueltas == 6, `cede: tres astillas cada vez ({yaSueltas})`)

-- Echada abajo: Vida 0 y Abierta (como Defensa.romper; el servidor publica Vida antes que Abierta).
table.clear(sonados)
puerta:SetAttribute("Vida", 0)
puerta:SetAttribute("Abierta", true)
comprobar(angulo(cerrada, hoja.CFrame) < 1, "revienta: no se ve abierta ni un fotograma")
local volando = R.astillasDe(puerta)
-- astillas + los dos trozos metidos + el pomo (más las de antes)
local nuevas = #volando - yaSueltas
comprobar(nuevas >= P.Astillas[1] + 3 and nuevas <= P.Astillas[2] + 3, `revienta: astillas ({nuevas})`)
for i = yaSueltas + 1, #volando do
	local p = volando[i]
	comprobar(not p.Anchored and p.AssemblyLinearVelocity:Dot(Vector3.new(0, 0, 1)) > 0, "revienta: vuelan hacia la sala")
end
comprobar(pomo.Transparency == 1, "revienta: el pomo sale rodando")
comprobar(#d.piezas < tablasAntes, "revienta: los trozos metidos ya no van con la hoja")
comprobar(table.find(sonados, "Crujido") and table.find(sonados, "Golpe"), "revienta: suena")
correr(P.Caida + P.Mecer.Segundos + 0.2, "cae")
local meta = R.colgada(d.bisagra, d.hojaRel, hoja.Size, d.giro, Vector3.new(0, 0, 1))
comprobar((hoja.CFrame.Position - (meta * d.hojaRel).Position).Magnitude < 1e-3, "cae: se queda colgando")
comprobar(yMin(hoja.CFrame, hoja.Size) >= SUELO, "cae: sin meterse en el suelo")
comprobar(haciaSala(hoja) > 0.3, "cae: hacia la sala (no a 100°)")
for _, pz in d.piezas do
	comprobar((pz.parte.CFrame.Position - (meta * pz.rel).Position).Magnitude < 1e-3, "cae: las tablas cuelgan con ella")
end
-- Abierta con la vida a 0: CasaVista no la gira (aunque el ángulo cambie).
puerta:SetAttribute("Golpes", 1)
correr(0.5, "golpe colgada")
comprobar((hoja.CFrame.Position - (meta * d.hojaRel).Position).Magnitude < 1e-3, "colgada: un golpe no la mueve")
local picos = 0
for _, p in g.workspace.PuertasRotas:GetChildren() do
	if p.ClassName == "WedgePart" and p.Anchored and math.abs(p.Position.X - (d.bisagra.Position.X + 4)) < 1 then
		picos += 1
	end
end
comprobar(picos >= P.Picos[1], `revienta: picos en el marco de la cerradura ({picos})`)
correr(P.Anclar * 2, "anclar")
for _, p in R.astillasDe(puerta) do
	comprobar(p.Anchored and not p.CanCollide, "anclar: quietas a los 2 s (como mucho al doble)")
end

-- Las astillas crujen al pisarlas (una, a mano, en el suelo delante: en el mundo de mentira no caen).
local astilla: any = nil
for _, p in R.astillasDe(puerta) do
	if p.Name ~= "Pomo" then
		astilla = p
		break
	end
end
astilla.CFrame = CFrame.new(1, SUELO + 0.05, 8)
local pj = m.personaje(CFrame.new(1, SUELO + 3, 4))
m.camara.CFrame = CFrame.new(1, 5, 4)
table.clear(sonados)
m.andar(Vector3.new(0, 0, 1))
correr(1, "pisar")
m.andar(nil)
comprobar(table.find(sonados, "Cruje") ~= nil, "pisar: cruje la madera")
local veces = 0
for _, n in sonados do
	if n == "Cruje" then
		veces += 1
	end
end
comprobar(veces <= 2, `pisar: no a cada fotograma ({veces})`)
comprobar(pj.Parent ~= nil, "pisar: el personaje sigue ahí")

-- Reparada: se recogen las astillas y la hoja vuelve a su sitio (abierta, como la deja el servidor).
puerta:SetAttribute("Vida", 100)
correr(P.Vuelve + 0.8, "reparar")
comprobar(#R.astillasDe(puerta) == 0 and #d.piezas == 0, "reparar: sin astillas ni tablas")
comprobar(hoja.Transparency == 0 and pomo.Transparency == 0, "reparar: hoja y pomo enteros")
comprobar(#g.workspace.PuertasRotas:GetChildren() == 0, "reparar: nada suelto")
comprobar(math.abs(angulo(cerrada, hoja.CFrame) - 100) < 1, "reparar: vuelve a girar como siempre (abierta)")

-- Con Rendimiento: sin tablas que ceden, 5 astillas y sin pomo.
jugador:SetAttribute("Rendimiento", true)
local otra = nuevaPuerta(20)
local cerradaOtra = otra.Hoja.CFrame
m.paso(1 / 60)
otra:SetAttribute("Vida", 20)
correr(0.2, "poco cede")
local d2 = CasaVista.puertas[otra]
comprobar(#d2.piezas == 0 and otra.Hoja.Transparency == 0, "poco: no se parte")
otra:SetAttribute("Vida", 0)
otra:SetAttribute("Abierta", true)
comprobar(#R.astillasDe(otra) == P.AstillasPoco, "poco: 5 astillas")
comprobar(otra.Pomo.Transparency == 0, "poco: el pomo no rueda")
correr(P.Caida + P.Mecer.Segundos + 0.2, "poco cae")
comprobar((otra.Hoja.Position - cerradaOtra.Position).Z > 0.3, "poco: también cuelga")

-- Entrar tarde con una puerta ya echada abajo: colgando sin ruido.
jugador:SetAttribute("Rendimiento", false)
table.clear(sonados)
local tarde = nuevaPuerta(-20, 0)
local cerradaTarde = tarde:GetAttribute("Bisagra") * CFrame.new(2, 4, 0) -- (CasaVista la cuelga en cuanto llega)
m.paso(1 / 60)
local dt = CasaVista.puertas[tarde]
comprobar(#sonados == 0, "tarde: sin ruido")
local metaTarde = R.colgada(dt.bisagra, dt.hojaRel, tarde.Hoja.Size, dt.giro, Vector3.new(0, 0, 1))
comprobar((tarde.Hoja.Position - (metaTarde * dt.hojaRel).Position).Magnitude < 1e-3, "tarde: ya colgando")
comprobar((tarde.Hoja.Position - cerradaTarde.Position).Z > 0.3, "tarde: hacia la sala")

-- Al borrarse la puerta, nada se queda.
otra:Destroy()
m.paso(1 / 60)
comprobar(#R.astillasDe(otra) == 0, "borrada: sin astillas")

print(`puerta-rota: {cuentas} comprobaciones`)
