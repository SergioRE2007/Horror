-- Banco de la tormenta seca (docs/sistemas/tormenta.md). Ejecutar desde la raíz: lune run tests/bancos/tormenta.luau
-- (lo corre tests/regressions.luau). Carga src/juego/cliente/TormentaVista.luau de verdad con el Roblox de mentira
-- (_roblox.luau) y Ambiente, CasaVista y Sonido falsos; luego Ambiente de verdad para el destello que se suma.
--   Cuentas: nunca antes de Config.Tormenta.Desde, más o menos una de cada dos noches, la misma semilla da el mismo
--   horario (todos lo ven a la vez), los tiempos en sus rangos y la fuerza del destello de 0 a 1 (con Rendimiento, uno).
--   En marcha: cae a su hora, sube la luz y la luna, enciende el fogonazo con sombras, el trueno suena y tiemblan
--   cristales y bombillas; luego todo vuelve a 0 y el bucle se desconecta. Rendimiento: un destello y sin sombras.
--   Cinemática: nada. De día: nada. Ambiente: el destello sube la luz de fuera y la luna, y sin él queda como estaba.
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
local CFG = Config.Tormenta
local INICIO = 1_793_000_000.25

-- Los falsos: Ambiente (lo que TormentaVista le pone), CasaVista (una ventana que vibra) y Sonido (se apunta).
local AmbienteFalso = { destello = 0, lunas = {}, temblor = 0, factor = {} }
local vibraciones = 0
local temblores = 0
local CasaFalsa = { elementos = {}, temblar = function()
	temblores += 1
end }
local sonados: { { nombre: string, s: any, pos: any } } = {}
local SonidoFalso = {
	en = function(nombre: string, pos: any, tono: number?): any
		local s = Instance.new("Sound")
		s.Volume = 1
		s.PlaybackSpeed = tono or 1
		table.insert(sonados, { nombre = nombre, s = s, pos = pos })
		return s
	end,
	tocar = function(nombre: string): any
		local s = Instance.new("Sound")
		s.Volume = 1
		table.insert(sonados, { nombre = nombre, s = s })
		return s
	end,
	hay = function(_nombre: string): boolean
		return false
	end,
	bucle = function(_nombre: string): any
		return Instance.new("Sound")
	end,
}
local Tormenta = m.cargar("src/juego/cliente/TormentaVista", { Ambiente = AmbienteFalso, CasaVista = CasaFalsa, Sonido = SonidoFalso })

-- Cuentas. -------------------------------------------------------------------------------------------------------------
local con, total = 0, 0
for i = 1, 400 do
	local inicio = INICIO + i * 613.7
	comprobar(not Tormenta.hay(1, inicio, CFG), "noche 1: nunca hay tormenta")
	total += 1
	if Tormenta.hay(2 + i % 9, inicio, CFG) then
		con += 1
	end
end
comprobar(con > total * 0.35 and con < total * 0.65, `más o menos una de cada dos noches ({con} de {total})`)

-- Una noche con tormenta (la primera que salga) y su horario.
local NOCHE, inicio = 3, INICIO
while not Tormenta.hay(NOCHE, inicio, CFG) do
	inicio += 97.3
end
local fin = inicio + 600
local lista = Tormenta.horario(NOCHE, inicio, fin, CFG)
local otra = Tormenta.horario(NOCHE, inicio, fin, CFG)
comprobar(#lista >= 5, `una noche de 10 min trae unos cuantos relámpagos ({#lista})`)
comprobar(#otra == #lista, "la misma semilla, el mismo horario")
for i, r in lista do
	comprobar(r.t == otra[i].t and r.cerca == otra[i].cerca and #r.destellos == #otra[i].destellos, "mismo relámpago " .. i)
	comprobar(r.t > inicio and r.t < inicio + 600 * CFG.HastaNoche, "dentro de la noche, antes del amanecer")
	if i == 1 then
		comprobar(r.t - inicio >= CFG.Primero[1] and r.t - inicio <= CFG.Primero[2], "el primero, a su hora")
	else
		local hueco = r.t - lista[i - 1].t
		comprobar(hueco >= CFG.Cada[1] - 1e-6 and hueco <= CFG.Cada[2] + 1e-6, `entre relámpagos, Cada ({hueco})`)
	end
	comprobar(#r.destellos >= CFG.Destellos[1] and #r.destellos <= CFG.Destellos[2], "2-3 destellos")
	for j, d in r.destellos do
		local dura = d.subida + d.bajada
		comprobar(dura >= CFG.Duracion[1] - 1e-6 and dura <= CFG.Duracion[2] + 1e-6, `destello muy corto ({dura})`)
		comprobar(d.fuerza > 0 and d.fuerza <= 1, "fuerza de 0 a 1")
		if j > 1 then
			comprobar(d.fuerza <= r.destellos[1].fuerza, "el primero, el más fuerte")
		end
	end
	comprobar(r.trueno >= CFG.Trueno[1] and r.trueno <= CFG.Trueno[2], "trueno 1-5 s después")
	for x = -0.1, Tormenta.duracion(r) + 0.2, 0.004 do
		local k = Tormenta.fuerza(r, x, false)
		comprobar(k >= 0 and k <= 1 and k == k, "fuerza sin NaN y de 0 a 1")
		comprobar(Tormenta.fuerza(r, x, true) <= k + 1e-9, "con Rendimiento, nunca más")
		if x > r.destellos[1].subida + r.destellos[1].bajada then
			comprobar(Tormenta.fuerza(r, x, true) == 0, "con Rendimiento, un solo destello")
		end
	end
	comprobar(Tormenta.fuerza(r, r.destellos[1].subida, false) > 0.5, "en lo más fuerte, se nota")
	comprobar(Tormenta.fuerza(r, Tormenta.duracion(r) + 0.01, false) == 0, "después, nada")
end
comprobar(#Tormenta.horario(1, inicio, fin, CFG) == 0, "noche 1: horario vacío")
comprobar(#Tormenta.horario(1, inicio, fin, CFG, true) > 0, "forzada (prueba en Studio): siempre hay")

-- En marcha. ----------------------------------------------------------------------------------------------------------
local mapa = Instance.new("Folder")
mapa.Name = "Mapa"
mapa.Parent = g.workspace
m.caja(CFrame.new(0, 0.5, 0), Vector3.new(80, 1, 70), { Name = "Piso" })
local luna = m.caja(CFrame.new(0, 19, -31.8), Vector3.new(1, 1, 1), { Name = "Adorno", CanQuery = false, CanCollide = false, Transparency = 1 })
local foco = Instance.new("SpotLight")
foco.Range = 40
foco.Parent = luna
CollectionService:AddTag(luna, "Luna")
local lejana = m.caja(CFrame.new(400, 10, 400), Vector3.new(1, 1, 1), { Name = "Adorno", CanQuery = false, CanCollide = false, Transparency = 1 })
local focoLejos = Instance.new("SpotLight")
focoLejos.Parent = lejana
CollectionService:AddTag(lejana, "Luna")
local ventana = Instance.new("Model")
ventana.Name = "Ventana"
ventana:SetAttribute("Centro", CFrame.new(0, 19, -32.4))
ventana.Parent = mapa
CollectionService:AddTag(ventana, "Ventana")
CasaFalsa.elementos[ventana] = { centro = CFrame.new(0, 19, -32.4), vibrar = function(f: number)
	assert(f > 0 and f <= 1, "vibrar de 0 a 1")
	vibraciones += 1
end }
camara.CameraType = Enum.CameraType.Custom
camara.CFrame = CFrame.new(0, 12, -22) -- en el vestíbulo, dentro de casa y cerca de la ventana

local function fase(nombre: string, noche: number, desde: number, hasta: number)
	g.workspace:SetAttribute("Noche", noche)
	g.workspace:SetAttribute("FaseInicio", desde)
	g.workspace:SetAttribute("FaseFin", hasta)
	g.workspace:SetAttribute("Fase", nombre)
end
-- Una noche con tormenta que empezó hace un rato: lo justo para que el primer relámpago caiga en 0,5-3 s.
local ahora = g.workspace:GetServerTimeNow()
local elegida: number? = nil
for noche = 2, 9 do
	for cand = ahora - CFG.Primero[2], ahora - CFG.Primero[1], 0.37 do
		local l = Tormenta.horario(noche, cand, cand + 600, CFG)
		if l[1] and l[1].t - ahora > 0.5 and l[1].t - ahora < 3 then
			NOCHE, elegida = noche, cand
			break
		end
	end
	if elegida then
		break
	end
end
assert(elegida, "no encuentro una noche con tormenta que empiece ahora")
inicio, fin = elegida, elegida + 600
fase("Noche", NOCHE, inicio, fin)
Tormenta.start()
m.correr(0.1)
local r1 = Tormenta.estado.lista[1]
comprobar(r1 and r1.t == Tormenta.horario(NOCHE, inicio, fin, CFG)[1].t, "el horario de la noche de ahora")
local espera = r1.t - g.workspace:GetServerTimeNow()
if espera > 0 then
	m.correr(espera - 0.2, 1 / 30) -- dormido hasta casi la hora: nada
end
comprobar(Tormenta.estado.relampagos == 0 and AmbienteFalso.destello == 0, "antes de su hora, nada")

local maximo, conSombras, lunaPuesta = 0, false, false
m.correr(0.8, 1 / 120, function()
	maximo = math.max(maximo, AmbienteFalso.destello)
	if AmbienteFalso.lunas[foco] then
		lunaPuesta = true
	end
	local extra = g.workspace:FindFirstChild("TormentaLocal")
	if extra then
		for _, d in extra:GetDescendants() do
			if d:IsA("SpotLight") and d.Enabled then
				conSombras = d.Shadows
			end
		end
	end
	comprobar(AmbienteFalso.lunas[focoLejos] == nil, "la luna lejana, no")
end)
comprobar(Tormenta.estado.relampagos == 1, "cae el relámpago a su hora")
comprobar(maximo > 0.5, `sube la luz ({maximo})`)
comprobar(lunaPuesta, "la luna cercana, fogonazo")
comprobar(conSombras, "el fogonazo con sombras, encendido")
local pieza = g.workspace.TormentaLocal:FindFirstChild("Fogonazo")
comprobar(pieza and (pieza.Position - luna.Position).Magnitude > CFG.Fogonazo.Atras - 0.01, "el fogonazo, por fuera de la luna")
comprobar(AmbienteFalso.destello == 0 and AmbienteFalso.lunas[foco] == nil, "acabado el destello, todo a 0")

-- El trueno.
m.correr(r1.trueno + 0.3, 1 / 30)
comprobar(Tormenta.estado.truenos == 1, "suena el trueno")
local s = Tormenta.estado.ultimoTrueno
comprobar(s and s.PlaybackSpeed <= CFG.TonoRetumbo[2] + 1e-6, "Retumbo, muy grave")
comprobar(vibraciones > 0, "con el trueno vibra el cristal de la ventana cercana")
local vibra = false
for _, x in sonados do
	if x.nombre == "CristalVibra" then
		vibra = true
	end
end
comprobar(vibra, "y suena el cristal")
if r1.cerca < CFG.Cerca3D then
	comprobar(s:FindFirstChildOfClass("EqualizerSoundEffect"), "lejano y desde dentro: sordo")
end
local temblorMax = 0
m.correr(0.4, 1 / 60, function()
	temblorMax = math.max(temblorMax, AmbienteFalso.temblor)
end)
comprobar(temblorMax > 0, "las bombillas tiemblan")
m.correr(CFG.Temblor.Dura + 0.5, 1 / 30)
comprobar(AmbienteFalso.temblor == 0 and AmbienteFalso.destello == 0, "luego, todo quieto")

-- Rendimiento: un destello y sin sombras. Se salta al siguiente relámpago.
local function hastaElSiguiente(cada: ((n: number) -> ())?)
	local r = nil
	for _, x in Tormenta.estado.lista do
		if x.t > g.workspace:GetServerTimeNow() then
			r = x
			break
		end
	end
	assert(r, "hay otro relámpago")
	m.correr(r.t - g.workspace:GetServerTimeNow() + 0.6, 1 / 120, cada)
	return r
end
jugador:SetAttribute("Rendimiento", true)
local picos, antes, encendidas = 0, 0, 0
local r2 = hastaElSiguiente(function()
	local d = AmbienteFalso.destello
	if d > 0.05 and antes <= 0.05 then
		picos += 1
	end
	antes = d
	local extra = g.workspace:FindFirstChild("TormentaLocal")
	if extra then
		for _, l in extra:GetDescendants() do
			if l:IsA("SpotLight") and l.Enabled then
				encendidas += 1
			end
		end
	end
end)
comprobar(Tormenta.estado.relampagos == 2, "el segundo relámpago")
comprobar(picos == 1, `con Rendimiento, un solo destello ({picos} de {#r2.destellos})`)
comprobar(encendidas == 0, "con Rendimiento, sin sombras extra")
jugador:SetAttribute("Rendimiento", nil)
m.correr(r2.trueno + CFG.Temblor.Dura + 0.5, 1 / 30)

-- Cinemática: ni destello ni trueno.
camara.CameraType = Enum.CameraType.Scriptable
local truenos = Tormenta.estado.truenos
local visto = 0
local r3 = hastaElSiguiente(function()
	visto = math.max(visto, AmbienteFalso.destello)
end)
m.correr(r3.trueno + 0.5, 1 / 30)
comprobar(visto == 0 and Tormenta.estado.truenos == truenos, "cinemática: nada")
-- Por la mirilla (Scriptable con Vistazo), sí.
jugador:SetAttribute("Vistazo", "Mirilla")
visto = 0
hastaElSiguiente(function()
	visto = math.max(visto, AmbienteFalso.destello)
end)
comprobar(visto > 0, "por la mirilla, sí se ve")
jugador:SetAttribute("Vistazo", nil)
camara.CameraType = Enum.CameraType.Custom

-- De día: nada.
local n = Tormenta.estado.relampagos
fase("Dia", NOCHE, g.workspace:GetServerTimeNow(), g.workspace:GetServerTimeNow() + 600)
m.correr(80, 1 / 10)
comprobar(Tormenta.estado.relampagos == n, "de día, ningún relámpago")

-- Ambiente de verdad: el destello se suma a la luz de fuera y a la luna, y sin él queda como estaba. ------------------
local m2 = crearMundo()
local g2 = m2.global
local mapa2 = g2.Instance.new("Folder")
mapa2.Name = "Mapa"
mapa2.Parent = g2.workspace
local luna2 = m2.caja(g2.CFrame.new(0, 19, -31.8), g2.Vector3.new(1, 1, 1), { Name = "Adorno", CanQuery = false, CanCollide = false })
local foco2 = g2.Instance.new("SpotLight")
foco2.Brightness = 2
foco2.Parent = luna2
local bombilla = m2.caja(g2.CFrame.new(5, 10, 0), g2.Vector3.new(1, 1, 1), { Name = "Bombilla" })
local luz2 = g2.Instance.new("PointLight")
luz2.Brightness = 1
luz2.Parent = bombilla
luna2.Parent = mapa2
bombilla.Parent = mapa2
local ahora2 = g2.workspace:GetServerTimeNow()
g2.workspace:SetAttribute("Fase", "Noche")
g2.workspace:SetAttribute("FaseInicio", ahora2 - 300)
g2.workspace:SetAttribute("FaseFin", ahora2 + 300)
local SonidoMudo = { bucle = function()
	return g2.Instance.new("Sound")
end, tocar = function()
	return g2.Instance.new("Sound")
end, en = function()
	return g2.Instance.new("Sound")
end }
local ok, Ambiente = pcall(m2.cargar, "src/juego/cliente/Ambiente", { Sonido = SonidoMudo })
if ok then
	Ambiente.start()
	m2.correr(0.1)
	local L2 = m2.servicio("Lighting")
	local brillo, fuera, lunaBase = L2.Brightness, L2.OutdoorAmbient, foco2.Brightness
	Ambiente.destello = 1
	Ambiente.lunas[foco2] = 1
	m2.correr(1 / 30)
	comprobar(L2.Brightness > brillo + 1, "Ambiente: el destello sube el brillo")
	comprobar(L2.OutdoorAmbient.B > fuera.B, "Ambiente: y la luz de fuera")
	comprobar(foco2.Brightness > lunaBase + 2, "Ambiente: y la luna")
	Ambiente.destello = 0
	Ambiente.lunas[foco2] = nil
	m2.correr(1 / 30)
	comprobar(math.abs(L2.Brightness - brillo) < 1e-6 and math.abs(foco2.Brightness - lunaBase) < 1e-6, "Ambiente: sin destello, como estaba")
	local base = luz2.Brightness
	Ambiente.temblor = 0.5
	local menor = base
	m2.correr(0.5, 1 / 60, function()
		menor = math.min(menor, luz2.Brightness)
		comprobar(luz2.Brightness <= base + 1e-6 and luz2.Brightness >= 0, "Ambiente: el temblor solo baja")
	end)
	comprobar(menor < base, "Ambiente: la bombilla tiembla")
	comprobar(math.abs(foco2.Brightness - lunaBase) < 1e-6, "Ambiente: la luna no tiembla")
	Ambiente.temblor = 0
	m2.correr(1 / 30)
	comprobar(math.abs(luz2.Brightness - base) < 1e-6, "Ambiente: sin temblor, como estaba")
else
	print("tormenta: Ambiente no se carga en el Roblox de mentira (" .. tostring(Ambiente) .. "), sin esa parte")
end

print(`tormenta: bien ({cuentas} comprobaciones)`)
