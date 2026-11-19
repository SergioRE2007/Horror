-- Banco del cielo de la partida (docs/sistemas/cielo.md). Ejecutar desde la raíz: lune run tests/bancos/cielo.luau (lo
-- corre tests/regressions.luau). Carga src/juego/cliente/CieloVista.luau y Ambiente de verdad con el Roblox de mentira
-- (_roblox.luau), AireVista de verdad y una TormentaVista falsa (solo su `hay`).
--   Cuentas: nubes de día, de noche y de tormenta, el destello que aclara y vuelve igual, estrellas de 25 en 25 (ninguna
--   de día ni con tormenta, la mitad con Rendimiento) y la rampa sin pasarse.
--   En marcha: reutiliza el Sky del lugar (luna mayor, sin estrellas de día), crea las nubes en el Terrain, el viento
--   sopla en horizontal, la tormenta cierra el cielo en rampa (y Ambiente baja la luz de fuera) y se abre al acabar,
--   el relámpago aclara las nubes un instante, Rendimiento quita las nubes y Ambiente apaga Bloom/SunRays/DepthOfField.
--   Quien entra tarde en una noche de tormenta la ve ya cerrada; un Sky o unas nubes que lleguen tarde mandan sobre los
--   nuestros; TormentaPrueba solo vale en Studio.
--   Noches de niebla cerrada: nunca a la vez que la tormenta (con la TormentaVista de verdad, muchas noches), la misma
--   semilla da lo mismo, ninguna antes de Desde; la rampa sin saltos, la densidad de la Atmosphere dentro de su rango y
--   de día ninguna niebla; en marcha (NieblaPrueba en Studio) se cierra en Niebla.Rampa s, sin estrellas, se lo dice a
--   AireVista (niebla baja más espesa y alta), la tormenta la quita y se levanta desde Abre. Quien entra tarde la ve.
--   Luces de luna de las ventanas (etiqueta Luna): de día grises (no azules), de noche su azul; con el cielo cerrado,
--   apagadas a su parte (y CieloVista se lo dice también a AireVista); el fogonazo del relámpago, entero. El destello de
--   la pantalla (ColorCorrection) solo con lo que se vea del cielo (Ambiente.cieloVisto); la luz de fuera, entera.
--   El viento que se oye (Ambiente.vientoSonido): más con las rachas y la tormenta sin pasar del tope, dentro de casa
--   bajo y sin agudos, en el sótano casi nada; de fuera a dentro y al sótano, sin saltos. En marcha, con la cámara fuera,
--   en el vestíbulo y en el sótano, y con el cielo cerrado.
-- Si algo no se cumple, termina con error.
local crearMundo = require("./_roblox")

local cuentas = 0
local function comprobar(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end
local function cerca(a: number, b: number, e: number?): boolean
	return math.abs(a - b) <= (e or 1e-3)
end
local function finito(x: number): boolean
	return x == x and x > -math.huge and x < math.huge
end

-- Una semilla de TormentaVista con la que CieloVista.hayNiebla da `con` (su tirada, + 104729, contra Probabilidad).
local PROB_NIEBLA = 0.35 -- se comprueba abajo que es la de Config
local function semillaNiebla(g: any, con: boolean): number
	for s = 1, 10000 do
		if (g.Random.new(s + 104729):NextNumber() < PROB_NIEBLA) == con then
			return s
		end
	end
	error("semillaNiebla: ninguna")
end

-- Un mundo con Mapa, fase y Noche; Ambiente de verdad y una TormentaVista falsa que dice lo que `hay.valor`.
local function montar(opciones: { studio: boolean?, conCielo: boolean?, fase: string, p: number, noche: number? })
	local m = crearMundo({ studio = opciones.studio })
	local g = m.global
	local L = m.servicio("Lighting")
	local efectos = {}
	if opciones.conCielo then
		local s = g.Instance.new("Sky")
		s.Name = "SkyDelLugar"
		s.Parent = L
		efectos.cielo = s
	end
	for _, clase in { "BloomEffect", "SunRaysEffect", "DepthOfFieldEffect" } do
		local e = g.Instance.new(clase)
		e.Parent = L
		table.insert(efectos, e)
	end
	local mapa = g.Instance.new("Folder")
	mapa.Name = "Mapa"
	mapa.Parent = g.workspace
	local ahora = g.workspace:GetServerTimeNow()
	local largo = 2000 -- noche larga: el banco no llega al amanecer sin querer
	g.workspace:SetAttribute("Noche", opciones.noche or 3)
	g.workspace:SetAttribute("Fase", opciones.fase)
	g.workspace:SetAttribute("FaseInicio", ahora - opciones.p * largo)
	g.workspace:SetAttribute("FaseFin", ahora + (1 - opciones.p) * largo)
	-- `semilla`: la que da TormentaVista.semilla; por defecto una con la que no hay niebla (semillaNiebla).
	local hay = { valor = false, llamadas = {} :: { any }, semilla = 0 }
	hay.semilla = semillaNiebla(g, false)
	local TormentaFalsa = { hay = function(noche: number, inicio: number, cfg: any): boolean
		table.insert(hay.llamadas, { noche, inicio, cfg })
		return hay.valor
	end, semilla = function(): number
		return hay.semilla
	end }
	local bucles = {} :: { [string]: any } -- los bucles pedidos, por nombre (el viento)
	local SonidoMudo = { bucle = function(nombre: string)
		local s = g.Instance.new("Sound")
		bucles[nombre] = s
		return s
	end, tocar = function()
		return g.Instance.new("Sound")
	end, en = function()
		return g.Instance.new("Sound")
	end }
	local Ambiente = m.cargar("src/juego/cliente/Ambiente", { Sonido = SonidoMudo })
	Ambiente.start()
	local Cielo = m.cargar("src/juego/cliente/CieloVista", { TormentaVista = TormentaFalsa })
	return { m = m, g = g, L = L, efectos = efectos, hay = hay, Ambiente = Ambiente, Cielo = Cielo, largo = largo,
		bucles = bucles }
end

local function cielos(L: any): { any }
	local l = {}
	for _, h in L:GetChildren() do
		if h:IsA("Sky") then
			table.insert(l, h)
		end
	end
	return l
end
local function nubesDe(g: any): { any }
	local l = {}
	for _, h in g.workspace.Terrain:GetChildren() do
		if h:IsA("Clouds") then
			table.insert(l, h)
		end
	end
	return l
end
local function comoNubes(c: any, n: any, e: number?): boolean
	return cerca(c.Cover, n.Cover, e) and cerca(c.Density, n.Density, e) and cerca(c.Color.R * 255, n.Color[1], 0.6)
		and cerca(c.Color.G * 255, n.Color[2], 0.6) and cerca(c.Color.B * 255, n.Color[3], 0.6)
end

-- Cuentas. -------------------------------------------------------------------------------------------------------------
local A = montar({ studio = true, conCielo = true, fase = "Dia", p = 0.3 })
local Cielo, Config = A.Cielo, A.m.cargar("src/shared/Config")
local CFG = Config.Cielo
local N = CFG.Nubes

local function igualNubes(a: any, b: any): boolean
	return cerca(a.Cover, b.Cover) and cerca(a.Density, b.Density) and cerca(a.Color[1], b.Color[1])
		and cerca(a.Color[2], b.Color[2]) and cerca(a.Color[3], b.Color[3])
end
comprobar(igualNubes(Cielo.nubes(0, 0, CFG), N.Dia), "cuentas: de día, las de día")
comprobar(igualNubes(Cielo.nubes(1, 0, CFG), N.Noche), "cuentas: de noche, las de noche")
comprobar(igualNubes(Cielo.nubes(0, 1, CFG), N.Tormenta) and igualNubes(Cielo.nubes(1, 1, CFG), N.Tormenta),
	"cuentas: con tormenta, las de tormenta (de día o de noche)")
local media = Cielo.nubes(0.5, 0, CFG)
comprobar(media.Cover < N.Dia.Cover and media.Cover > N.Noche.Cover, "cuentas: al anochecer, entre las dos")
comprobar(N.Noche.Cover < N.Dia.Cover and N.Dia.Cover < N.Tormenta.Cover, "Config: de noche rotas, de día casi, con tormenta cerrado")
comprobar(N.Tormenta.Density > N.Dia.Density and N.Tormenta.Color[1] < N.Noche.Color[1], "Config: la tormenta, más gruesa y oscura")
for _, n in { N.Dia, N.Noche, N.Tormenta } do
	comprobar(n.Cover >= 0 and n.Cover <= 1 and n.Density >= 0 and n.Density <= 1, "Config: Cover y Density de 0 a 1")
end
local base = Cielo.nubes(1, 1, CFG)
comprobar(Cielo.conDestello(base, 0, CFG) == base, "cuentas: sin destello, las mismas")
local luz = Cielo.conDestello(base, 1, CFG)
comprobar(luz.Color[1] > base.Color[1] + 50 and luz.Density < base.Density, "cuentas: el destello aclara la nube por dentro")
comprobar(luz.Color[1] <= CFG.Destello.Color[1] and luz.Cover == base.Cover, "cuentas: sin cegar ni abrir el cielo")
comprobar(Cielo.estrellas(0, 0, false, CFG) == 0, "cuentas: de día, ninguna estrella")
comprobar(Cielo.estrellas(1, 0, false, CFG) == CFG.Estrellas, "cuentas: de noche, todas")
comprobar(Cielo.estrellas(1, 1, false, CFG) == 0, "cuentas: con tormenta, ninguna")
comprobar(Cielo.estrellas(1, 0, true, CFG) == math.floor(CFG.Estrellas * CFG.EstrellasRendimiento / 25 + 0.5) * 25,
	"cuentas: con Rendimiento, la mitad")
comprobar(CFG.Estrellas < 3000, "Config: menos estrellas que las 3000 de serie")
local antes = -1
for i = 0, 40 do
	local e = Cielo.estrellas(i / 40, 0, false, CFG)
	comprobar(e % 25 == 0 and e >= antes, "cuentas: estrellas de 25 en 25 y subiendo con la noche")
	antes = e
end
comprobar(Cielo.objetivoTormenta("Noche", 0.5, true, CFG) == 1, "cuentas: noche con tormenta, cerrado")
comprobar(Cielo.objetivoTormenta("Noche", 0.5, false, CFG) == 0, "cuentas: noche sin tormenta, nada")
comprobar(Cielo.objetivoTormenta("Dia", 0.5, true, CFG) == 0, "cuentas: de día, nada")
comprobar(Cielo.objetivoTormenta("Noche", CFG.Tormenta.Abre + 0.01, true, CFG) == 0, "cuentas: se abre antes del amanecer")
comprobar(CFG.Tormenta.Abre > Config.Tormenta.HastaNoche, "Config: se abre después del último relámpago")
local x = 0
for _ = 1, 400 do
	local y = Cielo.acercar(x, 1, 0.1, CFG.Rampa)
	comprobar(y >= x and y <= 1, "cuentas: la rampa sube sin pasarse")
	x = y
end
comprobar(x == 1 and cerca(Cielo.acercar(0, 1, CFG.Rampa / 2, CFG.Rampa), 0.5), "cuentas: la rampa tarda Rampa s")
comprobar(Cielo.suave(0) == 0 and Cielo.suave(1) == 1 and cerca(Cielo.suave(0.5), 0.5), "cuentas: suave de 0 a 1")

-- Niebla cerrada: las cuentas. ------------------------------------------------------------------------------------------
local NB = CFG.Niebla
comprobar(NB.Probabilidad == PROB_NIEBLA, "banco: PROB_NIEBLA es la de Config")
comprobar(igualNubes(Cielo.nubes(1, 0, CFG, 1), N.Niebla), "niebla: de noche, las nubes de niebla")
comprobar(igualNubes(Cielo.nubes(0, 0, CFG, 1), N.Dia), "niebla: de día no cuenta")
comprobar(igualNubes(Cielo.nubes(1, 0, CFG, 0), N.Noche), "niebla: sin niebla, las de noche")
comprobar(N.Niebla.Cover > N.Noche.Cover and N.Niebla.Cover < N.Tormenta.Cover, "Config: con niebla, más tapado (sin tormenta)")
comprobar(Cielo.estrellas(1, 0, false, CFG, 1) == 0, "niebla: ninguna estrella")
comprobar(Cielo.estrellas(1, 0, false, CFG, 0) == CFG.Estrellas, "niebla: sin ella, todas")
comprobar(Cielo.objetivoNiebla("Noche", 0.5, true, CFG) == 1 and Cielo.objetivoNiebla("Noche", 0.5, false, CFG) == 0
	and Cielo.objetivoNiebla("Dia", 0.5, true, CFG) == 0 and Cielo.objetivoNiebla("Noche", NB.Abre + 0.01, true, CFG) == 0,
	"niebla: solo de noche, si la hay, hasta Abre")
comprobar(NB.Densidad > 0.36 and NB.Densidad < 1 and NB.Baja > 1 and NB.Alto > 1 and NB.Rampa > CFG.Rampa,
	"Config: la niebla, más densa, la baja más espesa y alta y la rampa más lenta que la tormenta")
-- La rampa: suavizada, sin saltos (la derivada de suave, como mucho 1,5 × paso) y tarda Rampa s.
local xn, antesN, saltoN = 0, 0, 0
for _ = 1, 600 do
	xn = Cielo.acercar(xn, 1, 0.1, NB.Rampa)
	local sn = Cielo.suave(xn)
	saltoN = math.max(saltoN, sn - antesN)
	antesN = sn
end
comprobar(xn == 1 and saltoN <= 1.5 * 0.1 / NB.Rampa + 1e-9, `niebla: la rampa sin saltos ({saltoN})`)
comprobar(cerca(Cielo.acercar(0, 1, NB.Rampa / 2, NB.Rampa), 0.5), "niebla: la rampa tarda Rampa s")

-- Con la TormentaVista de verdad: nunca tormenta y niebla la misma noche, la misma semilla da lo mismo y ninguna antes
-- de Desde. Un mundo aparte (los módulos se cargan una vez por mundo).
do
	local mT = crearMundo({})
	local mudo = { bucle = function() return mT.global.Instance.new("Sound") end, tocar = function() end, en = function() end }
	mT.cargar("src/juego/cliente/Ambiente", { Sonido = mudo })
	local TV = mT.cargar("src/juego/cliente/TormentaVista", { CasaVista = {}, Sonido = mudo })
	local CV = mT.cargar("src/juego/cliente/CieloVista")
	local niebla, tormentas, total = 0, 0, 0
	for i = 1, 3000 do
		local nocheN, inicio = 1 + i % 12, 1_700_000_000 + i * 977
		local conN = CV.hayNiebla(nocheN, inicio, NB)
		local conT = TV.hay(nocheN, inicio, Config.Tormenta)
		comprobar(not (conN and conT), `niebla: nunca con tormenta (noche {nocheN})`)
		comprobar(CV.hayNiebla(nocheN, inicio, NB) == conN, "niebla: la misma semilla, lo mismo")
		if nocheN < NB.Desde then
			comprobar(not conN, "niebla: ninguna antes de Desde")
		else
			total += 1
			niebla += if conN then 1 else 0
			tormentas += if conT then 1 else 0
		end
	end
	-- Sin tormenta, cerca de Probabilidad (a ojo: ±0,06 en unas 2500 noches).
	local parte = niebla / math.max(1, total - tormentas)
	comprobar(niebla > 0 and math.abs(parte - NB.Probabilidad) < 0.06, `niebla: de las noches sin tormenta, ~Probabilidad ({parte})`)
end

-- En marcha: de día. ---------------------------------------------------------------------------------------------------
local m, g, L, Ambiente = A.m, A.g, A.L, A.Ambiente
for _, e in ipairs(A.efectos) do
	comprobar(e.Enabled == false, `Ambiente: {e.ClassName} del lugar, apagado`)
end
local tarde = g.Instance.new("BloomEffect")
tarde.Parent = L
comprobar(tarde.Enabled == false, "Ambiente: un Bloom que llega tarde, apagado")
local querido = g.Instance.new("SunRaysEffect")
querido:SetAttribute("Permitido", true)
querido.Parent = L
comprobar(querido.Enabled == true, "Ambiente: uno con Permitido, encendido")

Cielo.start()
m.correr(0.3, 1 / 60)
local sky = cielos(L)
comprobar(#sky == 1 and sky[1] == A.efectos.cielo, "reutiliza el Sky del lugar (ninguno de más)")
comprobar(sky[1].MoonAngularSize == CFG.Luna and sky[1].CelestialBodiesShown, "la luna, algo mayor")
comprobar(sky[1].StarCount == 0, "de día, ninguna estrella")
local nubes = nubesDe(g)
comprobar(#nubes == 1 and nubes[1].Name == "NubesJuego", "las nubes, en el Terrain")
local nube = nubes[1]
comprobar(nube.Enabled and comoNubes(nube, N.Dia), "de día, nubes grises")
comprobar(Ambiente.nublado == 0, "de día, nada de nublado")
local function vientoBien(fuerte: number): boolean
	local v = g.workspace.GlobalWind
	local mag = v.Magnitude
	local F = Config.Aire.Viento.Fuerza
	return v.Y == 0 and mag >= F[1] * CFG.Viento - 1e-3 and mag <= F[2] * CFG.Viento * fuerte + 1e-3
end
comprobar(vientoBien(1), "el viento de las nubes, en horizontal y en su fuerza")
local v1 = g.workspace.GlobalWind
m.correr(30, 1 / 10)
comprobar((g.workspace.GlobalWind - v1).Magnitude > 1e-4, "el viento cambia (rachas)")

-- Al anochecer, a medias.
local ahora = g.workspace:GetServerTimeNow()
g.workspace:SetAttribute("FaseInicio", ahora - 0.9 * A.largo)
g.workspace:SetAttribute("FaseFin", ahora + 0.1 * A.largo)
m.correr(0.3, 1 / 60)
comprobar(sky[1].StarCount > 0 and sky[1].StarCount < CFG.Estrellas, "al anochecer, salen algunas estrellas")
comprobar(nube.Cover < N.Dia.Cover and nube.Cover > N.Noche.Cover, "al anochecer, las nubes se abren")

-- De noche, sin tormenta.
ahora = g.workspace:GetServerTimeNow()
g.workspace:SetAttribute("Fase", "Noche")
g.workspace:SetAttribute("FaseInicio", ahora - 0.1 * A.largo)
g.workspace:SetAttribute("FaseFin", ahora + 0.9 * A.largo)
m.correr(0.3, 1 / 60)
comprobar(sky[1].StarCount == CFG.Estrellas, "de noche, las estrellas")
comprobar(comoNubes(nube, N.Noche), "de noche, nubes rotas")
local llamada = A.hay.llamadas[#A.hay.llamadas]
comprobar(llamada and llamada[1] == 3 and llamada[2] == g.workspace:GetAttribute("FaseInicio") and llamada[3] == Config.Tormenta,
	"pregunta a TormentaVista.hay con Noche, FaseInicio y Config.Tormenta (lo ven todos igual)")
local brilloSin, fueraSin = L.Brightness, L.OutdoorAmbient
comprobar(Ambiente.nublado == 0, "sin tormenta, nada de nublado")

-- Tormenta: el cielo se cierra en rampa.
A.hay.valor = true
local nan = false
m.correr(CFG.Rampa / 2, 1 / 10, function()
	nan = nan or not (finito(nube.Cover) and finito(nube.Density) and finito(L.Brightness))
end)
local medio = Cielo.estado.tormenta
comprobar(medio > 0.2 and medio < 0.8, `la tormenta llega en rampa ({medio})`)
comprobar(nube.Cover > N.Noche.Cover and nube.Cover < N.Tormenta.Cover, "a medias, las nubes se van cerrando")
comprobar(sky[1].StarCount < CFG.Estrellas and sky[1].StarCount > 0, "a medias, se van tapando las estrellas")
comprobar(L.Brightness < brilloSin and L.Brightness > brilloSin * CFG.Tormenta.Luz, "a medias, algo menos de luz")
m.correr(CFG.Rampa / 2 + 1, 1 / 10, function()
	nan = nan or not (finito(nube.Cover) and finito(nube.Density) and finito(L.Brightness))
end)
comprobar(not nan, "sin NaN en la rampa")
comprobar(Cielo.estado.tormenta == 1 and Ambiente.nublado == 1, "con tormenta, cerrado del todo")
comprobar(m.cargar("src/juego/cliente/AireVista").nublado == 1, "y se lo dice a AireVista (los haces de luna)")
comprobar(sky[1].StarCount == 0, "con tormenta, ninguna estrella")
comprobar(comoNubes(nube, N.Tormenta), "con tormenta, nubes cerradas y oscuras")
comprobar(cerca(L.Brightness, brilloSin * CFG.Tormenta.Luz, 1e-4), "con tormenta, Ambiente baja el brillo")
comprobar(cerca(L.OutdoorAmbient.B, fueraSin.B * CFG.Tormenta.Luz, 1e-3), "y la luz de fuera")
comprobar(vientoBien(CFG.Tormenta.Viento), "con tormenta, más viento (sin pasarse)")

-- Un relámpago: la nube se aclara ese instante y vuelve igual.
Ambiente.destello = 1
m.correr(1 / 60)
comprobar(nube.Color.R * 255 > N.Tormenta.Color[1] + 50 and nube.Density < N.Tormenta.Density, "el relámpago aclara las nubes")
comprobar(nube.Color.R * 255 <= CFG.Destello.Color[1] + 0.6, "sin cegar")
comprobar(L.Brightness > brilloSin, "el relámpago, entero (el nublado no lo apaga)")
Ambiente.destello = 0.3
m.correr(1 / 60)
local aMedias = nube.Color.R * 255
comprobar(aMedias > N.Tormenta.Color[1] and aMedias < CFG.Destello.Color[1], "con el destello bajando, a medias (cada fotograma)")
Ambiente.destello = 0
m.correr(1 / 60)
comprobar(comoNubes(nube, N.Tormenta, 1e-6), "acabado el relámpago, como estaban")

-- Rendimiento: sin nubes y la mitad de estrellas (y se nota en marcha).
A.hay.valor = false
local yo = m.jugadorLocal
yo:SetAttribute("Rendimiento", true)
m.correr(CFG.Rampa + 1, 1 / 10)
comprobar(Cielo.estado.tormenta == 0 and Ambiente.nublado == 0, "sin tormenta, el cielo se abre")
comprobar(nube.Enabled == false, "con Rendimiento, sin nubes")
comprobar(sky[1].StarCount == Cielo.estrellas(1, 0, true, CFG) and sky[1].StarCount < CFG.Estrellas, "con Rendimiento, menos estrellas")
yo:SetAttribute("Rendimiento", nil)
m.correr(0.3, 1 / 60)
comprobar(nube.Enabled and sky[1].StarCount == CFG.Estrellas, "sin Rendimiento, otra vez todo")
comprobar(cerca(L.Brightness, brilloSin, 1e-6) and cerca(L.OutdoorAmbient.B, fueraSin.B, 1e-6), "abierto el cielo, la luz como estaba")

-- TormentaPrueba en Studio: la fuerza.
g.workspace:SetAttribute("TormentaPrueba", true)
m.correr(CFG.Rampa + 1, 1 / 10)
comprobar(Cielo.estado.tormenta == 1 and sky[1].StarCount == 0, "TormentaPrueba en Studio: cielo cerrado")
g.workspace:SetAttribute("TormentaPrueba", nil)

-- Niebla cerrada en marcha (NieblaPrueba en Studio): se cierra en rampa, sin estrellas y AireVista lo sabe.
m.correr(CFG.Rampa + 1, 1 / 10) -- que se vaya la tormenta forzada
local atm = nil
for _, h in L:GetChildren() do
	if h:IsA("Atmosphere") then
		atm = h
	end
end
local AireN = m.cargar("src/juego/cliente/AireVista")
local densSin = atm.Density
comprobar(Cielo.estado.neblina == 0 and Ambiente.neblina == 0 and atm.Haze == 2 and cerca(atm.Offset, 0.1),
	"sin niebla cerrada, la Atmosphere de siempre")
g.workspace:SetAttribute("NieblaPrueba", true)
local saltoM, antesM = 0, 0
local function mirarNiebla()
	saltoM = math.max(saltoM, math.abs(Ambiente.neblina - antesM))
	antesM = Ambiente.neblina
	nan = nan or not (finito(atm.Density) and finito(atm.Haze))
end
m.correr(NB.Rampa / 2, 1 / 10, mirarNiebla)
comprobar(Ambiente.neblina > 0.2 and Ambiente.neblina < 0.8, `NieblaPrueba: llega en rampa ({Ambiente.neblina})`)
comprobar(atm.Density > densSin and atm.Density < NB.Densidad, "a medias, la Atmosphere se va espesando")
m.correr(NB.Rampa / 2 + 1, 1 / 10, mirarNiebla)
comprobar(not nan and saltoM <= 1.5 * 0.2 / NB.Rampa, `niebla en marcha: sin saltos ({saltoM})`)
comprobar(Cielo.estado.neblina == 1 and Ambiente.neblina == 1 and AireN.neblina == 1, "niebla cerrada del todo (y AireVista lo sabe)")
comprobar(Cielo.estado.tormenta == 0 and Ambiente.nublado == 0, "niebla sin tormenta")
comprobar(cerca(atm.Density, NB.Densidad, 1e-4) and cerca(atm.Haze, NB.Haze, 1e-4) and cerca(atm.Offset, NB.Offset, 1e-4),
	"niebla: Density, Haze y Offset de Config.Cielo.Niebla")
comprobar(cerca(atm.Color.R * 255, NB.Color[1], 1) and cerca(atm.Color.B * 255, NB.Color[3], 1) and atm.Color.B > atm.Color.R,
	"niebla: gris azulado")
comprobar(sky[1].StarCount == 0 and comoNubes(nube, N.Niebla), "niebla: sin estrellas y las nubes tapadas")
-- La tormenta manda: con las dos forzadas, solo tormenta.
g.workspace:SetAttribute("TormentaPrueba", true)
m.correr(math.max(CFG.Rampa, NB.Rampa) + 1, 1 / 10)
comprobar(Cielo.estado.tormenta == 1 and Cielo.estado.neblina == 0 and Ambiente.neblina == 0, "con tormenta, nunca niebla")
g.workspace:SetAttribute("TormentaPrueba", nil)
m.correr(math.max(CFG.Rampa, NB.Rampa) + 1, 1 / 10)
comprobar(Cielo.estado.neblina == 1 and Cielo.estado.tormenta == 0, "sin tormenta, vuelve la niebla")
-- Se levanta desde Abre (hacia el amanecer).
ahora = g.workspace:GetServerTimeNow()
g.workspace:SetAttribute("FaseInicio", ahora - (NB.Abre + 0.005) * A.largo)
g.workspace:SetAttribute("FaseFin", ahora + (1 - NB.Abre - 0.005) * A.largo)
m.correr(2, 1 / 10)
comprobar(Cielo.estado.neblina < 1 and Cielo.estado.neblina > 0, "pasado Abre, la niebla se empieza a levantar")
g.workspace:SetAttribute("NieblaPrueba", nil)
-- La niebla baja de AireVista: más espesa y más alta.
local NA = Config.Aire.Niebla
local r0, a0 = AireN.nieblaBaja(1, 0)
local r1, a1 = AireN.nieblaBaja(1, 1)
comprobar(r0 == NA.Rate and a0 == NA.Alto, "niebla baja: sin niebla cerrada, la de siempre")
comprobar(cerca(r1, NA.Rate * NB.Baja) and cerca(a1, NA.Alto * NB.Alto), "niebla baja: con ella, más espesa y alta")
comprobar(AireN.nieblaBaja(0, 1) == 0, "niebla baja: de día, nada")

-- Se abre antes de amanecer (después del último relámpago).
A.hay.valor = true
m.correr(CFG.Rampa + 1, 1 / 10)
ahora = g.workspace:GetServerTimeNow()
g.workspace:SetAttribute("FaseInicio", ahora - (CFG.Tormenta.Abre + 0.005) * A.largo)
g.workspace:SetAttribute("FaseFin", ahora + (1 - CFG.Tormenta.Abre - 0.005) * A.largo)
m.correr(2, 1 / 10)
comprobar(Cielo.estado.tormenta < 1 and Cielo.estado.tormenta > 0, "pasado Abre, el cielo empieza a abrirse")

-- Un Sky que llega tarde: manda (luna mayor, sus estrellas).
local nuevo = g.Instance.new("Sky")
nuevo.Parent = L
m.correr(0.3, 1 / 60)
comprobar(nuevo.MoonAngularSize == CFG.Luna and nuevo.StarCount < 3000, "un Sky que llega tarde: se usa ese")

-- Quien entra tarde en una noche de tormenta, sin Sky en el lugar y sin Studio. ----------------------------------------
local B = montar({ studio = false, fase = "Noche", p = 0.4 })
B.hay.valor = true
B.Cielo.start()
local skyB = cielos(B.L)
comprobar(#skyB == 1 and skyB[1].Name == "CieloJuego", "sin Sky en el lugar, uno nuestro")
comprobar(B.Cielo.estado.tormenta == 1 and skyB[1].StarCount == 0, "entrar tarde: la tormenta ya puesta, sin rampa")
comprobar(comoNubes(nubesDe(B.g)[1], N.Tormenta), "entrar tarde: las nubes ya cerradas")
local nuevoB = B.g.Instance.new("Sky")
nuevoB.Parent = B.L
B.m.correr(0.3, 1 / 60)
local quedan = cielos(B.L)
comprobar(#quedan == 1 and quedan[1] == nuevoB, "un Sky que llega tarde quita el nuestro (nunca dos)")
comprobar(nuevoB.StarCount == 0 and nuevoB.MoonAngularSize == CFG.Luna, "y manda sobre él")
local nubesTarde = B.g.Instance.new("Clouds")
nubesTarde.Parent = B.g.workspace.Terrain
B.m.correr(0.3, 1 / 60)
local nb = nubesDe(B.g)
comprobar(#nb == 1 and nb[1] == nubesTarde and comoNubes(nubesTarde, N.Tormenta), "unas nubes que llegan tarde: se usan esas")
-- TormentaPrueba y NieblaPrueba fuera de Studio: nada.
B.hay.valor = false
B.g.workspace:SetAttribute("TormentaPrueba", true)
B.g.workspace:SetAttribute("NieblaPrueba", true)
B.m.correr(math.max(CFG.Rampa, CFG.Niebla.Rampa) + 1, 1 / 10)
comprobar(B.Cielo.estado.tormenta == 0, "TormentaPrueba fuera de Studio: nada")
comprobar(B.Cielo.estado.neblina == 0, "NieblaPrueba fuera de Studio: nada")

-- Quien entra tarde en una noche de niebla (la de verdad, por la semilla): ya cerrada, sin rampa.
local Dn = montar({ studio = false, fase = "Noche", p = 0.4 })
Dn.hay.semilla = semillaNiebla(Dn.g, true)
Dn.Cielo.start()
Dn.m.correr(0.3, 1 / 60)
local atmD = nil
for _, h in Dn.L:GetChildren() do
	if h:IsA("Atmosphere") then
		atmD = h
	end
end
comprobar(Dn.Cielo.estado.neblina == 1 and Dn.Ambiente.neblina == 1 and cerca(atmD.Density, CFG.Niebla.Densidad, 1e-4),
	"entrar tarde: la niebla ya puesta")
comprobar(Dn.Cielo.estado.tormenta == 0 and cielos(Dn.L)[1].StarCount == 0, "entrar tarde con niebla: sin tormenta ni estrellas")

-- El sol, el alba y el ocaso (Ambiente.valores; Config.Cielo.Sol y Alba). ---------------------------------------------
--   La exposición no sube con sol > Pleno (atardecer sin pico de luz antes de "NIGHT n") y no baja de la de noche al
--   amanecer hasta que el sol empieza a salir (los últimos segundos de la noche no se quedan negros).
--   Luz del sol (Brightness · sol · 2^exposición) nunca más que a mediodía; Brightness nunca más que el de día con sol.
--   La franja: 0 a pleno día, a plena noche y con el cielo cubierto; máxima con el sol en el horizonte. En marcha, la
--   tormenta (Ambiente.nublado) y la escena final (EscenaFinal) la apagan.
local Amb = A.Ambiente
local SOL = CFG.Sol
local EPS = 1e-6

-- El día o la noche de punta a punta, en pasos pequeños (copias: Ambiente.valores rellena siempre la misma tabla).
local function recorrido(fase: string?, nublado: number?): { any }
	local lista = {}
	for i = 0, 1000 do
		local copia = {}
		for k, v in Amb.valores(fase, i / 1000, nublado) do
			copia[k] = v
		end
		table.insert(lista, copia)
	end
	return lista
end
local dia, noche = recorrido("Dia"), recorrido("Noche")
local mediodia = recorrido(nil)[1] -- sin fase: mediodía
local NOCHE_EXP, DIA_EXP = noche[500].Exposicion, mediodia.Exposicion
local luzMediodia = mediodia.Brightness * mediodia.sol * 2 ^ mediodia.Exposicion
comprobar(mediodia.sol == 1 and mediodia.franja == 0, "sol: a mediodía, sol entero y sin franja")
comprobar(NOCHE_EXP > DIA_EXP + 1, "sol: de noche la exposición es mucho más alta que de día")

-- La hora, igual que antes y sin saltos entre fases.
comprobar(cerca(dia[1].hora, 6.5, EPS) and cerca(dia[#dia].hora, 18.5, EPS), "sol: el día va de 6,5 a 18,5")
comprobar(cerca(noche[1].hora, 18.5, EPS) and cerca(noche[#noche].hora, 6.5, EPS), "sol: la noche, de 18,5 a 6,5")
comprobar(cerca(dia[#dia].Exposicion, noche[1].Exposicion, 0.01), "sol: sin salto de exposición al anochecer")
comprobar(cerca(noche[#noche].Exposicion, dia[1].Exposicion, 0.01), "sol: sin salto de exposición al amanecer")
comprobar(cerca(dia[#dia].Brightness, noche[1].Brightness, 0.01), "sol: sin salto de brillo al anochecer")
comprobar(cerca(noche[#noche].Brightness, dia[1].Brightness, 0.01), "sol: sin salto de brillo al amanecer")

-- Atardecer: la exposición no sube mientras el sol esté alto, y luego solo sube (oscurece seguido).
for i, v in dia do
	if v.sol > SOL.Pleno + EPS then
		comprobar(cerca(v.Exposicion, DIA_EXP, EPS), `sol: con sol {v.sol} la exposición ya sube (a las {v.hora})`)
	end
	local luzSol = v.Brightness * v.sol * 2 ^ v.Exposicion
	comprobar(luzSol <= luzMediodia + EPS, `sol: más luz de sol que a mediodía a las {v.hora}`)
	if v.sol > 0 then
		comprobar(v.Brightness <= mediodia.Brightness + EPS, `sol: más Brightness que de día con sol a las {v.hora}`)
	end
	if i > 1 and v.hora > 12 then
		comprobar(v.Exposicion >= dia[i - 1].Exposicion - EPS, `sol: la exposición baja al atardecer a las {v.hora}`)
	end
end
-- Amanecer: la exposición se queda en la de noche hasta que el sol empieza a salir, y luego solo baja.
local salio = false
for i, v in noche do
	if v.sol > 0 then
		salio = salio or v.hora < 12 -- (al empezar la noche aún queda algo del sol que se pone)
		comprobar(v.Brightness <= mediodia.Brightness + EPS, `sol: más Brightness que de día con sol a las {v.hora}`)
	end
	if v.hora > 12 then
		continue
	elseif not salio then
		comprobar(cerca(v.Exposicion, NOCHE_EXP, EPS), `sol: la exposición cae con el sol aún abajo a las {v.hora}`)
	elseif i > 1 then
		comprobar(v.Exposicion <= noche[i - 1].Exposicion + EPS, `sol: la exposición sube al amanecer a las {v.hora}`)
	end
end
comprobar(salio, "sol: el sol sale antes de acabar la noche")

-- Las horas del sol: bajo el horizonte de noche cerrada, entero a pleno día, a medias en el horizonte.
comprobar(Amb.sol(SOL.Sale - SOL.Margen) == 0 and Amb.sol(3) == 0 and Amb.sol(22) == 0, "sol: 0 de noche")
comprobar(Amb.sol(SOL.Sale + SOL.Margen) == 1 and Amb.sol(12) == 1, "sol: 1 de día")
comprobar(cerca(Amb.sol(SOL.Sale), 0.5, EPS) and cerca(Amb.sol(SOL.Pone), 0.5, EPS), "sol: a medias en el horizonte")

-- La franja: 0 a pleno día y plena noche, máxima en el horizonte, la del ocaso por la tarde; nublado la apaga.
local ancho = CFG.Alba.Ancho
for _, h in { 12, 9, 15, SOL.Pone + ancho, 21, 0, 3, SOL.Sale - ancho } do
	comprobar(Amb.franja(h, 0) == 0, `franja: nada a las {h}`)
end
local wa, tardeA = Amb.franja(SOL.Sale, 0)
local wp, tardeP = Amb.franja(SOL.Pone, 0)
comprobar(cerca(wa, 1, EPS) and not tardeA, "franja: la del alba, entera con el sol saliendo")
comprobar(cerca(wp, 1, EPS) and tardeP, "franja: la del ocaso, entera con el sol poniéndose")
local enCampana = Amb.franja(SOL.Sale + 0.3, 0)
comprobar(enCampana < 1 and enCampana > 0.5, "franja: en campana")
local maxDia, maxNoche = 0, 0
for _, v in dia do
	maxDia = math.max(maxDia, v.franja)
end
for _, v in noche do
	maxNoche = math.max(maxNoche, v.franja)
end
comprobar(maxDia > 0.9 and maxNoche > 0.9, "franja: se ve al atardecer y al amanecer")
for _, v in recorrido("Dia", 1) do
	comprobar(v.franja == 0 and v.Glare == 0, "franja: con el cielo cubierto, atardecer sin franja")
end
for _, v in recorrido("Noche", 1) do
	comprobar(v.franja == 0 and v.Glare == 0, "franja: con el cielo cubierto, amanecer gris")
end
-- Niebla cerrada en Ambiente.valores: la densidad, de la de día y noche a la de Niebla, nunca fuera; de día, ninguna.
for i = 0, 1000 do
	for _, nb in { 0, 0.25, 0.5, 1 } do
		local v = Amb.valores("Noche", i / 1000, 0, nb)
		comprobar(v.Densidad >= 0.36 - EPS and v.Densidad <= NB.Densidad + EPS and v.Haze >= 2 - EPS
			and v.Haze <= NB.Haze + EPS and v.Offset >= NB.Offset - EPS and v.Offset <= 0.1 + EPS,
			`niebla: densidad dentro de rango ({v.Densidad} a {i / 1000})`)
		local d = Amb.valores("Dia", i / 1000 * 0.8, 0, nb)
		comprobar(d.neblina == 0 and cerca(d.Densidad, 0.38, EPS) and d.Haze == 2, "niebla: de día, ninguna")
	end
end
local llena = Amb.valores("Noche", 0.5, 0, 1)
comprobar(cerca(llena.Densidad, NB.Densidad, EPS) and cerca(llena.Haze, NB.Haze, EPS) and llena.neblina == 1,
	"niebla: a media noche, la de Config")

-- Con franja, la niebla del ocaso y la del alba tiran a cálido (más rojo que azul, al revés que la de noche).
local ocaso = Amb.valores("Dia", (SOL.Pone - 6.5) / 12)
comprobar(ocaso.franja > 0.9 and ocaso.Niebla.R > ocaso.Niebla.B, "franja: niebla del ocaso rojiza")
local pAlba = 0.9 + (SOL.Sale - 2) / 4.5 * 0.1
local alba = Amb.valores("Noche", pAlba)
comprobar(alba.franja > 0.9 and alba.Niebla.R > alba.Niebla.B, "franja: niebla del alba cálida")

-- En marcha, al alba: la franja se pinta; la tormenta (Ambiente.nublado) y la escena final la apagan.
local C = montar({ studio = false, fase = "Noche", p = pAlba })
local function deClase(clase: string): any
	for _, h in C.L:GetChildren() do
		if h:IsA(clase) then
			return h
		end
	end
	return nil
end
local atmosferaC, colorC = deClase("Atmosphere"), deClase("ColorCorrectionEffect")
C.m.correr(0.3, 1 / 60)
comprobar(atmosferaC.Glare > 0 and colorC.TintColor.B < 1 and atmosferaC.Color.R > atmosferaC.Color.B,
	"alba en marcha: la franja tiñe la niebla y la imagen")
comprobar(cerca(C.L.ExposureCompensation, alba.Exposicion, 0.05), "alba en marcha: la exposición sigue al sol")
C.Ambiente.nublado = 1
C.m.correr(0.3, 1 / 60)
comprobar(atmosferaC.Glare == 0 and cerca(colorC.TintColor.B, 1, EPS), "alba con tormenta: gris, sin franja")
C.Ambiente.nublado = 0
C.m.correr(0.3, 1 / 60)
comprobar(atmosferaC.Glare > 0, "abierto el cielo, vuelve la franja")
C.m.jugadorLocal:SetAttribute("EscenaFinal", true)
C.m.correr(0.3, 1 / 60)
comprobar(atmosferaC.Glare == 0 and cerca(colorC.TintColor.B, 1, EPS), "en la escena final, sin franja")
C.m.jugadorLocal:SetAttribute("EscenaFinal", nil)

-- Las luces de luna de las ventanas y el destello de la pantalla. -----------------------------------------------------
local AZUL = { 120, 140, 190 } -- el de Mapa.luzLuna
local TC = CFG.Tormenta
local function esAzul(c: any): boolean
	return c.B * 255 - c.R * 255 > 50
end
local azulNoche = A.g.Color3.fromRGB(AZUL[1], AZUL[2], AZUL[3])
local f0, c0 = Amb.lunaVentana(azulNoche, 0, 0)
comprobar(f0 == 1 and not esAzul(c0) and cerca(c0.R * 255, CFG.LuzDia[1], 0.6), "luna: de día, entera y gris")
local f1, c1 = Amb.lunaVentana(azulNoche, 1, 0)
comprobar(f1 == 1 and esAzul(c1) and cerca(c1.B * 255, AZUL[3], 0.6), "luna: de noche, su azul")
local f2 = Amb.lunaVentana(azulNoche, 1, 1)
comprobar(cerca(f2, TC.Lunas, EPS) and TC.Lunas < 0.5, "luna: con el cielo cerrado, su parte")
comprobar(not esAzul(A.g.Color3.fromRGB(table.unpack(CFG.LuzDia))), "Config: LuzDia, gris y no azul")

local D = montar({ studio = false, fase = "Dia", p = 0.3 })
local gD = D.g
local CS = D.m.servicio("CollectionService")
local function lunaEn(pos: any, conEtiqueta: boolean): any
	local pieza = D.m.caja(gD.CFrame.new(pos), gD.Vector3.new(1, 1, 1), { Name = "Adorno", CanQuery = false, CanCollide = false })
	local foco = gD.Instance.new("SpotLight")
	foco.Color = azulNoche
	foco.Brightness = 2
	foco.Parent = pieza
	if conEtiqueta then
		CS:AddTag(pieza, "Luna")
	end
	pieza.Parent = gD.workspace.Mapa
	return foco, pieza
end
local fDia = lunaEn(gD.Vector3.new(0, 19, -31.8), true)
local fTarde, piezaTarde = lunaEn(gD.Vector3.new(25, 9, -32.4), false)
local bombillaD = gD.Instance.new("PointLight")
bombillaD.Color = azulNoche
bombillaD.Brightness = 1
bombillaD.Parent = D.m.caja(gD.CFrame.new(5, 10, 0), gD.Vector3.new(1, 1, 1), { Name = "Bombilla" })
bombillaD.Parent.Parent = gD.workspace.Mapa
D.m.correr(0.3, 1 / 60)
comprobar(not esAzul(fDia.Color) and cerca(fDia.Brightness, 2, EPS), "luna en marcha: de día no es azul (y entera)")
comprobar(esAzul(fTarde.Color), "una luz sin etiqueta, como está")
CS:AddTag(piezaTarde, "Luna")
D.m.correr(0.3, 1 / 60)
comprobar(not esAzul(fTarde.Color), "la etiqueta que llega tarde: también")
comprobar(esAzul(bombillaD.Color), "las bombillas, de su color")
local ahoraD = gD.workspace:GetServerTimeNow()
gD.workspace:SetAttribute("Fase", "Noche")
gD.workspace:SetAttribute("FaseInicio", ahoraD - 0.5 * D.largo)
gD.workspace:SetAttribute("FaseFin", ahoraD + 0.5 * D.largo)
D.m.correr(0.3, 1 / 60)
local lunaNoche = fDia.Brightness
comprobar(esAzul(fDia.Color) and cerca(fDia.Color.B * 255, AZUL[3], 0.6), "luna en marcha: de noche, azul")
comprobar(lunaNoche > 0.3, "luna en marcha: de noche se ve")
D.Ambiente.nublado = 1
D.m.correr(0.3, 1 / 60)
comprobar(cerca(fDia.Brightness, lunaNoche * TC.Lunas, 1e-4), "luna con tormenta: apagada a su parte")
local LD = D.L
local colorD = nil
for _, h in LD:GetChildren() do
	if h:IsA("ColorCorrectionEffect") then
		colorD = h
	end
end
local brilloD, pantallaD, contrasteD = LD.Brightness, colorD.Brightness, colorD.Contrast
D.Ambiente.destello = 1
D.Ambiente.lunas[fDia] = 1
D.m.correr(1 / 60)
local T = Config.Tormenta.Luz
comprobar(cerca(fDia.Brightness, lunaNoche * TC.Lunas + T.Luna, 1e-4), "luna con tormenta: el fogonazo, entero")
comprobar(cerca(colorD.Brightness, pantallaD + T.Color, 1e-4) and cerca(colorD.Contrast, contrasteD + T.Contraste, 1e-4),
	"destello con el cielo a la vista: la pantalla, entera")
local brilloFuera = LD.Brightness
comprobar(brilloFuera > brilloD + 1, "destello: la luz de fuera sube")
D.Ambiente.cieloVisto = Config.Tormenta.Pantalla.Escondido
D.m.correr(1 / 60)
comprobar(colorD.Brightness - pantallaD < T.Color * 0.1 and colorD.Contrast - contrasteD < T.Contraste * 0.1,
	"destello sin cielo a la vista: la pantalla casi no parpadea")
comprobar(cerca(LD.Brightness, brilloFuera, 1e-6) and cerca(fDia.Brightness, lunaNoche * TC.Lunas + T.Luna, 1e-4),
	"y la luz de fuera y la luna, enteras igual")
D.Ambiente.destello = 0
D.Ambiente.lunas[fDia] = nil
D.Ambiente.cieloVisto = 1
D.m.correr(1 / 60)
comprobar(cerca(colorD.Brightness, pantallaD, 1e-6) and cerca(colorD.Contrast, contrasteD, 1e-6), "sin destello, la pantalla como estaba")
D.Ambiente.nublado = 0
D.m.correr(0.3, 1 / 60)
comprobar(cerca(fDia.Brightness, lunaNoche, 1e-4), "abierto el cielo, la luna como estaba")

-- El viento que se oye. ---------------------------------------------------------------------------------------------
local VS = CFG.VientoSonido
local AV = A.Ambiente
local BASE = Config.Sonidos.Viento.Volumen
local function rachas(r: number): number
	return VS.Rachas[1] + (VS.Rachas[2] - VS.Rachas[1]) * r
end
local vFuera, aFuera, mFuera = AV.vientoSonido(1, 0.5, 0, 0, 0)
comprobar(cerca(vFuera, BASE * 2 * rachas(0.5), 1e-6) and aFuera == 0 and mFuera == 0, "viento fuera de noche: claro")
comprobar(cerca(AV.vientoSonido(0, 0.5, 0, 0, 0), BASE * rachas(0.5), 1e-6), "viento de día: la mitad que de noche")
comprobar(AV.vientoSonido(1, 1, 0, 0, 0) > AV.vientoSonido(1, 0, 0, 0, 0) * 1.5, "viento: las rachas se notan")
local vTormenta = AV.vientoSonido(1, 0.5, 1, 0, 0)
comprobar(cerca(vTormenta, math.min(VS.Tope, vFuera * VS.Tormenta), 1e-6) and vTormenta > vFuera * 1.2,
	"viento con tormenta: más fuerte")
comprobar(cerca(AV.vientoSonido(1, 1, 1, 0, 0), VS.Tope, 1e-6), "viento con racha y tormenta: no pasa del tope")
local vDentro, aDentro, mDentro = AV.vientoSonido(1, 0.5, 0, 1, 0)
comprobar(cerca(vDentro, vFuera * VS.Dentro.Volumen, 1e-6) and aDentro == VS.Dentro.Agudos and mDentro == VS.Dentro.Medios,
	"viento dentro: bajo y sordo")
local vSotano, aSotano = AV.vientoSonido(1, 0.5, 0, 1, 1)
comprobar(cerca(vSotano, vFuera * VS.Sotano, 1e-6) and aSotano == VS.Dentro.Agudos, "viento en el sótano: casi nada")
comprobar(VS.Sotano < VS.Dentro.Volumen and VS.Dentro.Agudos < VS.Dentro.Medios and VS.Dentro.Medios < 0
	and VS.Tope >= BASE * 2 and VS.Rachas[1] < 1 and VS.Rachas[2] > 1, "Config del viento con sentido")
for k = 0, 1, 0.25 do
	for r = 0, 1, 0.25 do
		for n = 0, 1, 0.5 do
			for d = 0, 1, 0.5 do
				local v, a, md = AV.vientoSonido(k, r, n, d, d * d)
				comprobar(finito(v) and v >= 0 and v <= VS.Tope + 1e-9 and a <= 0 and md <= 0 and a >= VS.Dentro.Agudos,
					"viento: en su rango")
			end
		end
	end
end
-- Fuera → vestíbulo → sótano → fuera, a 10 pintadas por segundo: sin saltos y llega en Cambio segundos.
local dentroV, sotanoV = 0, 0
local antesV, antesA = AV.vientoSonido(1, 0.5, 0, 0, 0)
local saltoV, saltoA = 0, 0
local function pasar(metaD: number, metaS: number, segundos: number)
	for _ = 1, math.floor(segundos / 0.1 + 0.5) do
		dentroV = AV.acercar(dentroV, metaD, 0.1)
		sotanoV = AV.acercar(sotanoV, metaS, 0.1)
		local v, a = AV.vientoSonido(1, 0.5, 0, dentroV, sotanoV)
		saltoV = math.max(saltoV, math.abs(v - antesV))
		saltoA = math.max(saltoA, math.abs(a - antesA))
		antesV, antesA = v, a
	end
end
pasar(1, 0, VS.Cambio + 0.1)
comprobar(dentroV == 1 and cerca(antesV, vDentro, 1e-6), "viento: dentro en Cambio segundos")
pasar(1, 1, VS.Cambio + 0.1)
comprobar(sotanoV == 1 and cerca(antesV, vSotano, 1e-6), "viento: en el sótano en Cambio segundos")
pasar(0, 0, VS.Cambio + 0.1)
comprobar(dentroV == 0 and sotanoV == 0 and cerca(antesV, vFuera, 1e-6), "viento: fuera otra vez")
comprobar(saltoV < vFuera * 0.1 and saltoA < -VS.Dentro.Agudos * 0.1, `viento: sin saltos ({saltoV}, {saltoA} dB)`)

-- En marcha: el viento de verdad (rachas de AireVista) con la cámara en cada sitio.
local W = montar({ fase = "Noche", p = 0.5 })
W.m.camaraRoblox = false
local camW = W.m.camara
camW.CameraType = W.g.Enum.CameraType.Scriptable
local AireW = W.m.cargar("src/juego/cliente/AireVista")
local sonW = W.bucles.Viento
local eqW = sonW and sonW:FindFirstChild("Dentro")
comprobar(eqW and eqW:IsA("EqualizerSoundEffect"), "viento en marcha: con su ecualizador Dentro")
local function vientoAhora(dentroW: number, sotanoW: number, nub: number): number
	local _, _, r = AireW.viento()
	return (W.Ambiente.vientoSonido(1, r, nub, dentroW, sotanoW))
end
local function irW(x: number, y: number, z: number, segundos: number, cada: (() -> ())?)
	camW.CFrame = W.g.CFrame.new(x, y, z)
	W.m.correr(segundos, 1 / 10, cada)
end
irW(150, 5, 150, 2)
comprobar(cerca(sonW.Volume, vientoAhora(0, 0, 0), 1e-3) and not eqW.Enabled, "viento en marcha fuera: claro")
comprobar(sonW.PlaybackSpeed >= 0.96 - 1e-9 and sonW.PlaybackSpeed <= 1.04 + 1e-9, "viento en marcha: el tono con la racha")
local volAntes, saltoW = sonW.Volume, 0
irW(0, 6, 0, VS.Cambio + 0.3, function()
	saltoW = math.max(saltoW, math.abs(sonW.Volume - volAntes))
	volAntes = sonW.Volume
end)
comprobar(saltoW < vientoAhora(0, 0, 0) * 0.12, `viento en marcha: al entrar, sin saltos ({saltoW})`)
comprobar(cerca(sonW.Volume, vientoAhora(1, 0, 0), 1e-3) and eqW.Enabled and cerca(eqW.HighGain, VS.Dentro.Agudos, 1e-6)
	and cerca(eqW.MidGain, VS.Dentro.Medios, 1e-6), "viento en marcha en el vestíbulo: bajo y sordo")
irW(0, -6, 55, VS.Cambio + 0.3)
comprobar(cerca(sonW.Volume, vientoAhora(1, 1, 0), 1e-3), "viento en marcha en el sótano: casi nada")
irW(150, 5, 150, VS.Cambio + 0.3)
comprobar(cerca(sonW.Volume, vientoAhora(0, 0, 0), 1e-3) and not eqW.Enabled, "viento en marcha: al salir, claro otra vez")
W.Ambiente.nublado = 1
irW(150, 5, 150, 0.3)
comprobar(cerca(sonW.Volume, vientoAhora(0, 0, 1), 1e-3) and sonW.Volume > vientoAhora(0, 0, 0) * 1.1,
	"viento en marcha con tormenta: más fuerte")

print(`cielo: {cuentas} comprobaciones`)
