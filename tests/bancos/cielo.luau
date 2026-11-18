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
--   Luces de luna de las ventanas (etiqueta Luna): de día grises (no azules), de noche su azul; con el cielo cerrado,
--   apagadas a su parte (y CieloVista se lo dice también a AireVista); el fogonazo del relámpago, entero. El destello de
--   la pantalla (ColorCorrection) solo con lo que se vea del cielo (Ambiente.cieloVisto); la luz de fuera, entera.
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
	local hay = { valor = false, llamadas = {} :: { any } }
	local TormentaFalsa = { hay = function(noche: number, inicio: number, cfg: any): boolean
		table.insert(hay.llamadas, { noche, inicio, cfg })
		return hay.valor
	end }
	local SonidoMudo = { bucle = function()
		return g.Instance.new("Sound")
	end, tocar = function()
		return g.Instance.new("Sound")
	end, en = function()
		return g.Instance.new("Sound")
	end }
	local Ambiente = m.cargar("src/juego/cliente/Ambiente", { Sonido = SonidoMudo })
	Ambiente.start()
	local Cielo = m.cargar("src/juego/cliente/CieloVista", { TormentaVista = TormentaFalsa })
	return { m = m, g = g, L = L, efectos = efectos, hay = hay, Ambiente = Ambiente, Cielo = Cielo, largo = largo }
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
-- TormentaPrueba fuera de Studio: nada.
B.hay.valor = false
B.g.workspace:SetAttribute("TormentaPrueba", true)
B.m.correr(CFG.Rampa + 1, 1 / 10)
comprobar(B.Cielo.estado.tormenta == 0, "TormentaPrueba fuera de Studio: nada")

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

print(`cielo: {cuentas} comprobaciones`)
