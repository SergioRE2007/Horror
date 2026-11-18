-- Banco de los ojos en la oscuridad (docs/sistemas/ojos.md). Ejecutar desde la raíz: lune run tests/bancos/ojos.luau
-- (lo corre tests/regressions.luau). Carga src/juego/cliente/OjosVista.luau de verdad con el Roblox de mentira:
--   Cuentas: dentro de casa, el cono de la linterna (entero en el centro, nada fuera ni más allá del alcance).
--   Falsos: salen junto a un tronco del haz, a 30-70 studs, a altura de animal o de persona y nunca dentro de casa;
--   solo brillan en el haz; se apagan al mirarlos fijo o al acercarte, con su Ramita; con Rendimiento, ninguno.
--   Bichos: los de fuera brillan con tu luz y no se apagan al mirarlos; de espaldas, dentro de casa, en una cinemática
--   o con la linterna apagada, nada; de día se les quitan.
-- Si algo no se cumple, termina con error.
local crearMundo = require("./_roblox")

local cuentas = 0
local function comprobar(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end

local m = crearMundo()
local g = m.global
local Vector3, CFrame, Enum, Instance = g.Vector3, g.CFrame, g.Enum, g.Instance
local CollectionService = m.servicio("CollectionService")
local jugador = m.jugadorLocal
local camara = m.camara
local Config = m.cargar("src/shared/Config")
local CFG = Config.Ojos
CFG.Entre = { 1, 1 } -- que salgan enseguida (solo en este mundo)

local sonados: { string } = {}
local SonidoFalso = {
	en = function(nombre: string, _pos: any, _tono: number?): any
		table.insert(sonados, nombre)
		return Instance.new("Sound")
	end,
	hay = function(): boolean
		return false
	end,
}

-- (CFrame.lookAt de Lune sale al revés en z: hecho a mano)
local function mirando(desde: any, hacia: any): any
	local mira = (hacia - desde).Unit
	local lado = mira:Cross(Vector3.yAxis).Unit
	return CFrame.fromMatrix(desde, lado, lado:Cross(mira), -mira)
end

-- El mapa: el suelo del bosque y una fila de pinos delante de la cámara, a 40-60 studs.
m.caja(CFrame.new(200, -1, 200), Vector3.new(400, 2, 400), { Name = "Suelo" })
local OJO = Vector3.new(150, 5, 100)
for i, x in { 138, 146, 154, 162 } do
	local t = m.caja(CFrame.new(x, 30, 140 + i * 5), Vector3.new(2, 60, 2), { Name = "Tronco" })
	CollectionService:AddTag(t, "Pino")
end
-- Uno demasiado cerca (a 12 studs) y otro detrás de la cámara: de esos, nunca.
CollectionService:AddTag(m.caja(CFrame.new(150, 30, 112), Vector3.new(2, 60, 2), { Name = "Tronco" }), "Pino")
CollectionService:AddTag(m.caja(CFrame.new(150, 30, 50), Vector3.new(2, 60, 2), { Name = "Tronco" }), "Pino")

local function fase(nombre: string, p: number)
	local ahora = g.workspace:GetServerTimeNow()
	g.workspace:SetAttribute("Fase", nombre)
	g.workspace:SetAttribute("FaseInicio", ahora - p * 600)
	g.workspace:SetAttribute("FaseFin", ahora + (1 - p) * 600)
end
fase("Noche", 0.5)

local Ojos = m.cargar("src/juego/cliente/OjosVista", { Sonido = SonidoFalso })
local E = Ojos.estado

-- Cuentas. -------------------------------------------------------------------------------------------------------------
comprobar(Ojos.enCasa(Vector3.new(0, 6, 0)), "casa: el vestíbulo")
comprobar(Ojos.enCasa(Vector3.new(-36, 6, -10)), "casa: un anexo")
comprobar(not Ojos.enCasa(Vector3.new(0, 40, 0)), "casa: encima del tejado, fuera")
comprobar(not Ojos.enCasa(Vector3.new(150, 5, 150)), "casa: el bosque, fuera")
local luz = mirando(Vector3.zero, Vector3.new(0, 0, 10))
comprobar(math.abs(luz.LookVector.Z - 1) < 1e-6, "mirando: hacia donde toca")
comprobar(Ojos.enCono(luz, Vector3.new(0, 0, 30), 55) == 1, "cono: el centro, entero")
local mitad = math.rad(Config.Linterna.Angulo)
comprobar(Ojos.enCono(luz, Vector3.new(math.tan(mitad * 1.05) * 30, 0, 30), 55) == 0, "cono: fuera del haz, nada")
local borde = Ojos.enCono(luz, Vector3.new(math.tan(mitad * 0.8) * 30, 0, 30), 55)
comprobar(borde > 0 and borde < 1, "cono: hacia el borde, menos")
comprobar(Ojos.enCono(luz, Vector3.new(0, 0, 60), 55) == 0, "cono: más allá del alcance, nada")
comprobar(Ojos.enCono(luz, Vector3.new(0, 0, -30), 55) == 0, "cono: detrás, nada")
comprobar(Ojos.alcance(jugador) >= CFG.Lejos, "alcance: al menos Lejos")

-- Falsos. -------------------------------------------------------------------------------------------------------------
Ojos.start()
jugador:SetAttribute("Linterna", true)
local adelante = mirando(OJO, Vector3.new(150, 5, 200))
camara.CFrame = adelante

local brillo = 0 -- lo más que ha brillado un ojo de los falsos mientras se corría
local function correr(segundos: number, cada: (() -> ())?)
	brillo = 0
	m.correr(segundos, 1 / 60, function()
		for _, par in E.falsos do
			for _, ojo in par.ojos do
				comprobar(not m.roto(ojo.punto.WorldPosition), "falsos: sin NaN")
				brillo = math.max(brillo, ojo.k)
			end
		end
		if cada then
			cada()
		end
	end)
end

local salieron, pares, personas = 0, 0, 0
for _ = 1, 40 do
	correr(1.5)
	if #E.falsos > 0 then
		salieron += 1
		pares = math.max(pares, #E.falsos)
		for _, par in E.falsos do
			local d = (par.centro - OJO).Magnitude
			comprobar(d >= CFG.Nunca and d >= CFG.Distancia[1] - 3 and d <= CFG.Distancia[2] + 5, `falsos: a {d} studs`)
			comprobar(not Ojos.enCasa(par.centro), "falsos: nunca en casa")
			comprobar(par.centro.Z > OJO.Z + 20, "falsos: delante, no detrás")
			local alto = par.centro.Y
			local animal = alto >= CFG.Alto.Animal[1] - 0.01 and alto <= CFG.Alto.Animal[2] + 0.01
			local persona = alto >= CFG.Alto.Persona[1] - 0.01 and alto <= CFG.Alto.Persona[2] + 0.01
			comprobar(animal or persona, `falsos: a altura de animal o persona ({alto})`)
			if persona then
				personas += 1
			end
		end
		-- Que se vayan solos para el siguiente (sin mirarlos: la cámara, a un lado).
		camara.CFrame = mirando(OJO, OJO + Vector3.new(100, 0, 0))
		correr(0.3)
		comprobar(brillo == 0, "falsos: fuera del haz, nada")
		for _, par in E.falsos do
			par.muere = 0
		end
		correr(0.3)
		camara.CFrame = adelante
	end
end
comprobar(salieron >= 10, `falsos: salen a menudo con la linterna en el bosque ({salieron})`)
comprobar(pares == 2, "falsos: a veces dos pares")
comprobar(personas > 0, "falsos: a veces a altura de persona")

-- Mirarlos fijo los apaga y suena una Ramita.
local function esperarFalsos(): any
	for _ = 1, 40 do
		correr(0.5)
		if #E.falsos > 0 then
			return E.falsos[1]
		end
	end
	return nil
end
local par = esperarFalsos()
comprobar(par, "falsos: salen otra vez")
correr(0.2)
comprobar(brillo > 0, "falsos: en el haz, brillan")
table.clear(sonados)
camara.CFrame = mirando(OJO, par.centro)
correr(CFG.Mirada + CFG.Apagar + CFG.Ramita.Tras + 0.3)
comprobar(table.find(E.falsos, par) == nil, "falsos: mirados fijo, se van")
comprobar(sonados[1] == "Ramita", "falsos: al irse, una Ramita")

-- Acercarse también los apaga (sin mirarlos fijo: la cámara un poco a un lado).
camara.CFrame = adelante
par = esperarFalsos()
comprobar(par, "falsos: salen para acercarse")
local hacia = (par.centro - OJO).Unit
camara.CFrame = mirando(par.centro - hacia * (CFG.Cerca - 4), par.centro + Vector3.new(0, 6, 0))
correr(CFG.Apagar + 0.1)
comprobar(table.find(E.falsos, par) == nil, "falsos: al acercarte, se van")

-- Dentro de casa no salen.
camara.CFrame = mirando(Vector3.new(0, 6, -20), Vector3.new(0, 6, 40))
correr(5)
comprobar(#E.falsos == 0, "falsos: con la cámara en casa, ninguno")

-- Con Rendimiento, ninguno (y los que había se van).
camara.CFrame = adelante
esperarFalsos()
jugador:SetAttribute("Rendimiento", true)
correr(0.5)
comprobar(#E.falsos == 0, "rendimiento: se quitan")
correr(6)
comprobar(#E.falsos == 0, "rendimiento: no salen")

-- Bichos. -------------------------------------------------------------------------------------------------------------
local carpeta = Instance.new("Folder")
carpeta.Name = "Bichos"
carpeta.Parent = g.workspace
local bicho = Instance.new("Model")
bicho.Name = "Acechador"
local cabeza = m.caja(mirando(Vector3.new(150, 6, 150), OJO), Vector3.new(1, 1.8, 1.1),
	{ Name = "Cabeza", CanCollide = false, CanQuery = false })
cabeza.Parent = bicho
bicho.Parent = carpeta
local brilloBicho = 0
local function correrBicho(segundos: number)
	brilloBicho = 0
	m.correr(segundos, 1 / 60, function()
		local b = E.bichos[bicho]
		if b then
			for _, ojo in b.ojos do
				brilloBicho = math.max(brilloBicho, ojo.k)
			end
		end
	end)
end
correrBicho(1)
comprobar(E.bichos[bicho] and #E.bichos[bicho].ojos == #CFG.Bichos.Acechador.Ojos, "bicho: con sus ojos")
comprobar(brilloBicho > 0, "bicho: con Rendimiento también brillan")
camara.CFrame = mirando(OJO, cabeza.Position)
correrBicho(4)
comprobar(brilloBicho > 0 and E.bichos[bicho], "bicho: mirado fijo, no se apaga")
local ojo1 = E.bichos[bicho].ojos[1]
comprobar((ojo1.punto.WorldPosition - cabeza.Position).Magnitude < 1, "bicho: los ojos, en la cabeza")
camara.CFrame = mirando(OJO, OJO + Vector3.new(-100, 0, 0))
correrBicho(0.5)
comprobar(brilloBicho == 0, "bicho: fuera del haz, nada")
camara.CFrame = adelante
cabeza.CFrame = mirando(Vector3.new(150, 6, 150), Vector3.new(150, 6, 250))
correrBicho(0.5)
comprobar(brilloBicho == 0, "bicho: de espaldas, nada")
cabeza.CFrame = mirando(Vector3.new(150, 6, 150), OJO)
camara.CameraType = Enum.CameraType.Scriptable
correrBicho(0.5)
comprobar(brilloBicho == 0, "bicho: en una cinemática, nada")
camara.CameraType = Enum.CameraType.Custom
correrBicho(0.5)
comprobar(brilloBicho > 0, "bicho: al volver, brillan")
jugador:SetAttribute("Linterna", false)
correrBicho(0.5)
comprobar(brilloBicho == 0 and not Ojos.pintando(), "bicho: linterna apagada, nada y sin Heartbeat")
jugador:SetAttribute("Linterna", true)
-- Dentro de casa (el bicho dentro y tú también, a 25 studs y de frente): nada.
cabeza.CFrame = mirando(Vector3.new(0, 6, 10), Vector3.new(0, 6, -15))
camara.CFrame = mirando(Vector3.new(0, 6, -15), Vector3.new(0, 6, 10))
correrBicho(0.5)
comprobar(brilloBicho == 0, "bicho: dentro de casa, nada")
-- Muy cerca: ya no brillan (se le ve entero).
cabeza.CFrame = mirando(Vector3.new(150, 6, 108), OJO)
camara.CFrame = adelante
correrBicho(0.5)
comprobar(brilloBicho == 0, "bicho: muy cerca, nada")
-- Uno que no tiene ojos que brillen (el Imitador): ninguno.
local imitador = Instance.new("Model")
imitador.Name = "Imitador"
m.caja(CFrame.new(150, 6, 150), Vector3.new(1, 1, 1), { Name = "Cabeza", CanQuery = false }).Parent = imitador
imitador.Parent = carpeta
correrBicho(0.5)
comprobar(E.bichos[imitador] == nil, "bicho: el Imitador, sin ojos")
-- De día se quitan; al irse el bicho, también.
fase("Dia", 0.3)
correrBicho(0.5)
comprobar(next(E.bichos) == nil and not Ojos.pintando(), "día: sin ojos ni Heartbeat")
fase("Noche", 0.5)
correrBicho(0.5)
comprobar(E.bichos[bicho], "noche: otra vez")
bicho:Destroy()
correrBicho(0.5)
comprobar(next(E.bichos) == nil, "bicho que se va: sin ojos")

print(`Ojos: bien ({cuentas} comprobaciones; falsos {salieron} veces, {personas} de persona)`)
