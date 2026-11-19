-- Luz, niebla y hora del día en el cliente, a partir de los atributos del Ciclo (Fase, Noche, FaseInicio, FaseFin).
-- Día gris y apagado con bruma de bosque; noche casi negra con niebla azulada. Las transiciones, al final del día
-- (atardecer) y al final de la noche (amanecer): la exposición sigue al sol (no a la fase) y una franja cálida tiñe la
-- niebla y la luz de fuera con el sol en el horizonte (Config.Cielo.Sol y Alba, docs/sistemas/cielo.md).
-- También: viento de fondo (a rachas, más fuerte con tormenta y sordo dentro de casa: Ambiente.vientoSonido), las
-- noches de niebla cerrada (Ambiente.neblina, Config.Cielo.Niebla), el aviso de que se pone el sol, "NOCHE n" grande al
-- anochecer y el aviso del amanecer.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local AireVista = require(script.Parent.AireVista)
local Sonido = require(script.Parent.Sonido)
local Ui = require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))

local Ambiente = {}

-- Valores de día (k = 0) y de noche (k = 1); se mezclan.
local DIA = {
	Brightness = 1.1,
	Ambient = Color3.fromRGB(62, 62, 66),
	OutdoorAmbient = Color3.fromRGB(105, 106, 110),
	Densidad = 0.38,
	Niebla = Color3.fromRGB(150, 154, 158),
	Brillo = 0,
	Exposicion = 0,
	Lamparas = 1,
}
-- Noche oscura pero legible: la luna alta azula el bosque y recorta la casa y los troncos; la niebla, azul oscura y
-- no negra, para que las siluetas se vean a lo lejos. Sin subir la exposición la luz de luna de Roblox sale negra
-- del todo; al subirla, las lámparas de la casa se bajan para que dentro siga en penumbra (Lamparas = proporción).
local NOCHE = {
	Brightness = 1.4,
	Ambient = Color3.fromRGB(26, 25, 28),
	OutdoorAmbient = Color3.fromRGB(62, 70, 92),
	Densidad = 0.36,
	Niebla = Color3.fromRGB(30, 36, 52),
	Brillo = -0.02,
	Exposicion = 1.6,
	Lamparas = 0.41,
}

local lamparas: { [Light]: number } = {} -- luz → su brillo puesto por el servidor
-- Las luces de luna de las ventanas (hijas de una pieza con la etiqueta Luna, Mapa.luzLuna) → su color de noche (el
-- azul puesto por el servidor). De día van al gris de Config.Cielo.LuzDia y con el cielo cerrado se apagan a su parte.
local lunasMapa: { [Light]: Color3 } = {}
local LUZ_DIA = Color3.fromRGB(table.unpack(Config.Cielo.LuzDia))

-- Parpadeos (DetallesVista): luz → cuánto de su brillo le queda ahora (0 a 1). Sin entrada, todo.
Ambiente.factor = {} :: { [Light]: number }

-- Tormenta seca (TormentaVista, tormenta.md): lo pone TormentaVista y se suma encima de lo de aquí en cada fotograma.
--   destello: fogonazo del relámpago de 0 a 1 (luz de fuera, niebla, ColorCorrection y las lunas de `lunas`).
--   lunas: luz de luna → cuánto de Config.Tormenta.Luz.Luna se le suma ahora (0 a 1).
--   temblor: las bombillas (PointLight) tiemblan con el trueno, de 0 a 1.
--   cieloVisto: cuánto cielo se ve desde la cámara en este relámpago (0 a 1; fuera 1, en el sótano o escondido casi
--     nada). Solo multiplica la parte del ColorCorrection (la pantalla entera); al acabar vuelve a 1.
Ambiente.destello = 0
Ambiente.lunas = {} :: { [Light]: number }
Ambiente.temblor = 0
Ambiente.cieloVisto = 1
-- Cielo cerrado (CieloVista, cielo.md): de 0 a 1, la tormenta en rampa. Baja la luz de fuera
-- (Config.Cielo.Tormenta.Luz) y las luces de luna de las ventanas (Tormenta.Lunas); con 0, nada.
Ambiente.nublado = 0
-- Noche de niebla cerrada (CieloVista, cielo.md): de 0 a 1, en rampa. Lleva la Atmosphere de la noche hacia la de
-- Config.Cielo.Niebla (más densa, más clara y sin horizonte); de día no cuenta (va por la noche k).
Ambiente.neblina = 0
local semillas: { [Light]: number } = {} -- cada bombilla tiembla a su aire
local contador = 0
local CONTRASTE = 0.1
local SATURACION = -0.35 -- colores apagados, realistas

local atmosfera: Atmosphere
local color: ColorCorrectionEffect
local viento: Sound? -- nil mientras no haya un viento en Config.Sonidos
local vientoEq: EqualizerSoundEffect? -- "Dentro": le quita agudos y medios con la cámara en casa (el "Oido", aparte)
local VS = Config.Cielo.VientoSonido
-- Cuánto se está dentro de casa y en el sótano (0 a 1): van hacia 0 o 1 en VS.Cambio segundos, sin saltos en la puerta.
local vientoDentro, vientoSotano = 0, 0
local vientoAntes: number? = nil -- nil: la primera vez se pone donde toque, sin rampa (entrar ya dentro de casa)

local SOL = Config.Cielo.Sol
local ALBA = Config.Cielo.Alba
local BLANCO = Color3.new(1, 1, 1)
local AMANECER = Color3.fromRGB(table.unpack(ALBA.Amanecer))
local ATARDECER = Color3.fromRGB(table.unpack(ALBA.Atardecer))
local TINTE = Color3.fromRGB(table.unpack(ALBA.Tinte))
local NIEBLA = Config.Cielo.Niebla
local NIEBLA_COLOR = Color3.fromRGB(table.unpack(NIEBLA.Color))
local HAZE, OFFSET = 2, 0.1 -- los de la Atmosphere sin niebla cerrada

local function mezcla(a: number, b: number, k: number): number
	return a + (b - a) * k
end

-- Rampa de 0 a 1 que arranca y acaba sin golpe.
local function suave(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Suma a un color un RGB ({ r, g, b } de 0 a 255) por k.
local function mas(c: Color3, d: { number }, k: number): Color3
	k /= 255
	return Color3.new(math.min(1, c.R + d[1] * k), math.min(1, c.G + d[2] * k), math.min(1, c.B + d[3] * k))
end

-- Cuánto de noche (0 a 1) y la hora (ClockTime) según la fase y lo que lleva de ella (p, 0 a 1). Sin fase, mediodía.
-- La noche (k) manda en lámparas, Ambient y niebla; la luz del sol y la exposición siguen a la hora (Ambiente.sol).
function Ambiente.hora(fase: string?, p: number): (number, number)
	if fase == "Dia" then
		return math.clamp((p - 0.8) / 0.2, 0, 1), 6.5 + p * 12
	elseif fase == nil then
		return 0, 12
	end
	-- De noche la hora corre deprisa hasta medianoche y luego apenas se mueve (la luna siempre alta); al final, hacia
	-- el amanecer.
	local k = 1 - math.clamp((p - 0.9) / 0.1, 0, 1)
	local hora = if p < 0.08 then 18.5 + p / 0.08 * 5.5
		elseif p < 0.9 then (24 + (p - 0.08) / 0.82 * 2) % 24
		else 2 + (p - 0.9) / 0.1 * 4.5
	return k, hora
end

-- Cuánto sol hay (0 a 1) a esa hora: 0 con el sol bajo el horizonte, 1 con el sol ya alto; las rampas, Margen horas a
-- cada lado de la salida y la puesta (con el sol cruzando el horizonte, 0,5).
function Ambiente.sol(hora: number): number
	local m = SOL.Margen
	return math.min(suave((hora - (SOL.Sale - m)) / (2 * m)), suave((SOL.Pone + m - hora) / (2 * m)))
end

-- Cuánto de la luz de noche (luna) se deja: 0 mientras haya algo de sol y sube durante Luna horas tras ponerse del todo
-- (por la mañana, al revés). Así el Brightness nunca pasa del de día con el sol fuera.
local function pesoLuna(hora: number): number
	if hora >= 12 then
		return suave((hora - (SOL.Pone + SOL.Margen)) / SOL.Luna)
	end
	return suave((SOL.Sale - SOL.Margen - hora) / SOL.Luna)
end

-- Peso de la franja cálida (0 a 1): campana de Ancho horas a cada lado de la salida o la puesta, máxima con el sol en
-- el horizonte, 0 a pleno día y a plena noche; con el cielo cubierto (nublado 1), 0. Y si es la del ocaso.
function Ambiente.franja(hora: number, nublado: number?): (number, boolean)
	local tarde = hora >= 12
	local d = math.abs(hora - (if tarde then SOL.Pone else SOL.Sale)) / ALBA.Ancho
	if d >= 1 then
		return 0, tarde
	end
	return 0.5 * (1 + math.cos(math.pi * d)) * (1 - math.clamp(nublado or 0, 0, 1)), tarde
end

-- Lo que pinta el cielo según la noche (k), la hora, lo cubierto que esté (para la franja) y la niebla cerrada
-- (`neblina`, 0 a 1, solo de noche: va por k), sin tocar nada y antes de la tormenta y el relámpago (eso lo pone pintar
-- encima). Se rellena siempre la misma tabla.
local valores = {} :: { [string]: any }
local function calcular(k: number, hora: number, nublado: number?, neblina: number?): { [string]: any }
	local sol = Ambiente.sol(hora)
	local w, tarde = Ambiente.franja(hora, nublado)
	local calido = if tarde then ATARDECER else AMANECER
	local n = math.clamp(neblina or 0, 0, 1) * k
	local niebla = DIA.Niebla:Lerp(NOCHE.Niebla, k):Lerp(NIEBLA_COLOR, n)
	valores.k, valores.hora, valores.sol, valores.franja = k, hora, sol, w
	valores.Brightness = mezcla(DIA.Brightness, NOCHE.Brightness, k * pesoLuna(hora))
	-- La exposición sigue al sol: no sube hasta que baja de Pleno ni cae hasta que sale (sin ella la luna sale negra).
	valores.Exposicion = mezcla(NOCHE.Exposicion, DIA.Exposicion, math.min(1, sol / SOL.Pleno))
	valores.Ambient = DIA.Ambient:Lerp(NOCHE.Ambient, k)
	valores.OutdoorAmbient = DIA.OutdoorAmbient:Lerp(NOCHE.OutdoorAmbient, k):Lerp(calido, w * ALBA.Ambiente)
	valores.Densidad = mezcla(mezcla(DIA.Densidad, NOCHE.Densidad, k), NIEBLA.Densidad, n)
	valores.Haze = mezcla(HAZE, NIEBLA.Haze, n)
	valores.Offset = mezcla(OFFSET, NIEBLA.Offset, n)
	valores.neblina = n
	valores.Niebla = niebla:Lerp(calido, w * ALBA.Niebla) -- hacia el sol, más cálida
	valores.Decay = niebla:Lerp(calido, w * ALBA.Niebla * 0.5) -- lejos del sol, menos
	valores.Glare = w * ALBA.Glare
	valores.Brillo = mezcla(DIA.Brillo, NOCHE.Brillo, k)
	valores.Saturacion = SATURACION + w * ALBA.Saturacion
	valores.Tinte = BLANCO:Lerp(TINTE, w)
	return valores
end

-- Lo mismo a partir de la fase y lo que lleva de ella (lo usa tests/bancos/cielo.luau).
function Ambiente.valores(fase: string?, p: number, nublado: number?, neblina: number?): { [string]: any }
	local k, hora = Ambiente.hora(fase, p)
	return calcular(k, hora, nublado, neblina)
end

-- Cuánto de noche (0 a 1) y la hora, de los atributos del Ciclo.
local function momento(): (number, number)
	local fase = workspace:GetAttribute("Fase")
	local inicio, fin = workspace:GetAttribute("FaseInicio"), workspace:GetAttribute("FaseFin")
	if not fase or not inicio or not fin then
		return Ambiente.hora(nil, 0)
	end
	return Ambiente.hora(fase, math.clamp((workspace:GetServerTimeNow() - inicio) / math.max(1, fin - inicio), 0, 1))
end

-- El viento que se oye (sin tocar nada): volumen, y agudos y medios (dB, 0 o menos) del ecualizador, con la noche `k`, la
-- racha de AireVista.viento, el cielo cerrado `nublado` y cuánto se está dentro de casa y en el sótano (0 a 1; el
-- sótano cuenta dentro). Fuera no pasa de VS.Tope; dentro, por Dentro.Volumen (y en el sótano por Sotano) y sordo.
function Ambiente.vientoSonido(k: number, racha: number, nublado: number, dentro: number, sotano: number): (number, number, number)
	local base = if Config.Sonidos.Viento then Config.Sonidos.Viento.Volumen else 0
	local d = math.clamp(dentro, 0, 1)
	local fuera = base * (1 + math.clamp(k, 0, 1)) * mezcla(VS.Rachas[1], VS.Rachas[2], math.clamp(racha, 0, 1))
		* mezcla(1, VS.Tormenta, math.clamp(nublado, 0, 1))
	local sitio = mezcla(mezcla(1, VS.Dentro.Volumen, d), VS.Sotano, math.clamp(sotano, 0, 1))
	return math.min(fuera, VS.Tope) * sitio, VS.Dentro.Agudos * d, VS.Dentro.Medios * d
end

-- Lleva `x` hacia `meta` a 1/VS.Cambio por segundo (de 0 a 1 en Cambio segundos).
function Ambiente.acercar(x: number, meta: number, dt: number): number
	local paso = dt / VS.Cambio
	return if meta > x then math.min(meta, x + paso) else math.max(meta, x - paso)
end

-- Una luz de luna de ventana (sin tocar nada): su brillo con el cielo cerrado `nublado` (0 a 1) por esta parte, y su
-- color con la noche `k`: de día el gris frío de LuzDia (no cae luz azul a pleno sol), de noche su azul. Lo usa el banco.
function Ambiente.lunaVentana(colorNoche: Color3, k: number, nublado: number): (number, Color3)
	local f = 1 - (1 - Config.Cielo.Tormenta.Lunas) * math.clamp(nublado, 0, 1)
	return f, LUZ_DIA:Lerp(colorNoche, math.clamp(k, 0, 1))
end

-- Lo de las lámparas del mapa: su brillo según cuánto de noche es (k) y los parpadeos (factor). Las de luna, además,
-- con el cielo (Ambiente.lunaVentana); el fogonazo del relámpago se les suma entero.
-- El bosque se calla (Config.BosqueCalla, sonidos.md): ¿cuenta este hijo de workspace.Bichos? Un Model vivo; el
-- Imitador no mientras finge ser una persona en la puerta (como en AmbienteMiedo: callarse delataría que no es amigo).
function Ambiente.bichoCuenta(modelo: Instance): boolean
	if not modelo:IsA("Model") then
		return false
	end
	if modelo.Name == "Imitador" and not modelo:GetAttribute("Abierto") then
		return false
	end
	local humanoide = modelo:FindFirstChildOfClass("Humanoid")
	return not (humanoide and humanoide.Health <= 0)
end

-- La cuenta del silencio, pura: `posiciones` son las de los bichos que cuentan y `callaHasta` hasta cuándo dura el
-- silencio que ya había. Con alguno a menos de Calla studs en planta de la cámara se calla y el silencio sigue
-- `vuelve` segundos más (por defecto lo menos de Vuelve); sin ninguno, sigue callado hasta callaHasta. Devuelve si
-- calla, el nuevo hasta y, si hay uno cerca, la posición del más cercano (para la ramita que lo delata).
function Ambiente.bosqueCalla(posiciones: { Vector3 }, camara: Vector3, ahora: number, callaHasta: number,
	vuelve: number?): (boolean, number, Vector3?)
	local cfg = Config.BosqueCalla
	local cerca: Vector3? = nil
	local mejor = cfg.Calla
	for _, p in posiciones do
		local dx, dz = p.X - camara.X, p.Z - camara.Z
		local d = math.sqrt(dx * dx + dz * dz)
		if d < mejor then
			mejor = d
			cerca = p
		end
	end
	if cerca then
		return true, math.max(callaHasta, ahora + (vuelve or cfg.Vuelve[1])), cerca
	end
	return ahora < callaHasta, callaHasta, nil
end

local function pintarLamparas(k: number)
	local proporcion = mezcla(DIA.Lamparas, NOCHE.Lamparas, k)
	local temblor = Ambiente.temblor
	local nublado = math.min(Ambiente.nublado, 1)
	local reloj = os.clock()
	for luz, base in lamparas do
		if luz.Parent then
			local brillo = base * proporcion * (Ambiente.factor[luz] or 1)
			local azul = lunasMapa[luz]
			if azul then
				local f, c = Ambiente.lunaVentana(azul, k, nublado)
				brillo *= f
				if luz.Color ~= c then
					luz.Color = c
				end
			end
			if temblor > 0 and luz:IsA("PointLight") then -- el trueno: tiembla y baja un poco, cada una a su aire
				local n = semillas[luz] or 0
				brillo *= 1 - temblor * (0.5 + 0.5 * math.noise(reloj * 22, n, 0.37))
			end
			local luna = Ambiente.lunas[luz]
			if luna then
				brillo += luna * Ambiente.destello * Config.Tormenta.Luz.Luna
			end
			luz.Brightness = brillo
		else
			lamparas[luz] = nil
			lunasMapa[luz] = nil
			Ambiente.factor[luz] = nil
			Ambiente.lunas[luz] = nil
			semillas[luz] = nil
		end
	end
end

-- Cuánto tapa la franja cálida: la tormenta (Ambiente.nublado, de CieloVista) la apaga en rampa y en la escena final
-- (EscenaFinal del jugador) no hay: la luz la lleva la escena, sin tintes nuestros.
local function cubierto(): number
	local jugador = Players.LocalPlayer
	return math.max(Ambiente.nublado, if jugador and jugador:GetAttribute("EscenaFinal") then 1 else 0)
end

-- El viento de fondo: rachas y tormenta de AireVista y el sitio de la cámara, acercándose sin saltos.
local function pintarViento(s: Sound, k: number)
	local ahora = os.clock()
	local dt = if vientoAntes then math.min(ahora - vientoAntes, 0.5) else VS.Cambio
	vientoAntes = ahora
	local camara = workspace.CurrentCamera
	local dentro, sotano = false, false
	if camara then
		local casa, _, sala = AireVista.dentro(camara.CFrame.Position)
		dentro, sotano = casa, sala == "Sotano"
	end
	vientoDentro = Ambiente.acercar(vientoDentro, if dentro then 1 else 0, dt)
	vientoSotano = Ambiente.acercar(vientoSotano, if sotano then 1 else 0, dt)
	local _, _, racha = AireVista.viento()
	local volumen, agudos, medios = Ambiente.vientoSonido(k, racha, Ambiente.nublado, vientoDentro, vientoSotano)
	s.Volume = volumen
	s.PlaybackSpeed = 0.96 + 0.08 * racha
	local eq = vientoEq
	if eq then
		local hace = agudos < -0.01 or medios < -0.01
		if eq.Enabled ~= hace then
			eq.Enabled = hace
		end
		if hace then
			eq.HighGain = agudos
			eq.MidGain = medios
		end
	end
end

local function pintar(k: number, hora: number)
	local v = calcular(k, hora, cubierto(), Ambiente.neblina)
	Lighting.ClockTime = hora
	Lighting.Brightness = v.Brightness
	Lighting.Ambient = v.Ambient
	Lighting.OutdoorAmbient = v.OutdoorAmbient
	local nublado = Ambiente.nublado
	if nublado > 0 then -- con el cielo cerrado de tormenta llega menos luz de fuera (el relámpago, encima, entero)
		local f = 1 - (1 - Config.Cielo.Tormenta.Luz) * math.min(nublado, 1)
		local fuera = Lighting.OutdoorAmbient
		Lighting.Brightness *= f
		Lighting.OutdoorAmbient = Color3.new(fuera.R * f, fuera.G * f, fuera.B * f)
	end
	atmosfera.Density = v.Densidad
	atmosfera.Color = v.Niebla
	atmosfera.Decay = v.Decay
	atmosfera.Glare = v.Glare
	atmosfera.Haze = v.Haze
	atmosfera.Offset = v.Offset
	color.Brightness = v.Brillo
	color.Saturation = v.Saturacion
	color.TintColor = v.Tinte
	Lighting.ExposureCompensation = v.Exposicion
	pintarLamparas(k)
	-- Relámpago de la tormenta seca: la luz de fuera, la niebla (el cielo se pone blanco) y un pico de brillo y
	-- contraste (las siluetas, más negras), encima de lo de arriba. Sin destello, nada. Con destello se pinta todo en
	-- cada fotograma (ver start), así que el += parte siempre de lo recién puesto.
	local d = Ambiente.destello
	color.Contrast = CONTRASTE
	if d > 0 then
		local T = Config.Tormenta.Luz
		Lighting.Brightness += T.Brillo * d
		Lighting.OutdoorAmbient = mas(Lighting.OutdoorAmbient, T.Fuera, d)
		atmosfera.Color = mas(atmosfera.Color, T.Niebla, d)
		atmosfera.Decay = mas(atmosfera.Decay, T.Niebla, d * 0.6)
		-- La pantalla entera, solo con lo que se vea del cielo desde aquí (en el sótano o en el armario, casi nada).
		local visto = math.clamp(Ambiente.cieloVisto, 0, 1)
		color.Brightness += T.Color * d * visto
		color.Contrast = CONTRASTE + T.Contraste * d * visto
	end
	if viento then
		pintarViento(viento, k)
	end
end

-- Título grande que aparece y se va (al anochecer).
local function titulo(texto: string)
	local t = Ui.texto(Ui.mayusculas(texto), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromScale(0.8, 0.12),
		TextSize = 72,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
		ZIndex = 40,
	})
	local raya = Instance.new("Frame")
	raya.AnchorPoint = Vector2.new(0.5, 0)
	raya.Position = UDim2.fromScale(0.5, 0.92)
	raya.Size = UDim2.fromScale(0, 0.05)
	raya.BorderSizePixel = 0
	raya.BackgroundColor3 = Ui.Color.Sangre
	raya.Parent = t
	t.Parent = Ui.hud()
	TweenService:Create(t, TweenInfo.new(1.5), { TextTransparency = 0, TextStrokeTransparency = 0.3 }):Play()
	TweenService:Create(raya, TweenInfo.new(1.2, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(0.35, 0.05) }):Play()
	task.delay(4, function()
		TweenService:Create(t, TweenInfo.new(2), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		TweenService:Create(raya, TweenInfo.new(2), { BackgroundTransparency = 1 }):Play()
		task.delay(2, t.Destroy, t)
	end)
end

function Ambiente.start()
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.3
	Lighting.EnvironmentSpecularScale = 0.3
	atmosfera = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosfera.Offset = OFFSET
	atmosfera.Glare = 0
	atmosfera.Haze = HAZE
	atmosfera.Parent = Lighting
	color = Instance.new("ColorCorrectionEffect")
	color.Saturation = SATURACION
	color.Contrast = CONTRASTE
	color.Parent = Lighting
	-- Lo que traiga el lugar (la plantilla de Roblox pone Bloom, SunRays y DepthOfField), apagado: brillos flojos y la
	-- niebla ya da la profundidad. Un efecto que el juego quiera de verdad lleva el atributo Permitido.
	local function apagarEfecto(e: Instance)
		local apagable = e:IsA("BloomEffect") or e:IsA("SunRaysEffect") or e:IsA("DepthOfFieldEffect")
		if apagable and e:GetAttribute("Permitido") ~= true then
			(e :: PostEffect).Enabled = false
		end
	end
	for _, e in Lighting:GetChildren() do
		apagarEfecto(e)
	end
	Lighting.ChildAdded:Connect(apagarEfecto)
	viento = if Config.Sonidos.Viento then Sonido.bucle("Viento") else nil
	if viento then
		local eq = Instance.new("EqualizerSoundEffect")
		eq.Name = "Dentro"
		eq.LowGain, eq.MidGain, eq.HighGain = 0, 0, 0
		eq.Enabled = false
		eq.Parent = viento
		vientoEq = eq
	end
	-- Una luz de luna: su azul de noche se guarda una vez (como el brillo), antes de que la pintemos de gris.
	local function apuntarLuz(luz: Instance)
		if luz:IsA("Light") then
			if not lamparas[luz] then
				lamparas[luz] = luz.Brightness
				contador += 1
				semillas[luz] = contador * 1.618
			end
			local padre = luz.Parent
			if padre and not lunasMapa[luz] and CollectionService:HasTag(padre, "Luna") then
				lunasMapa[luz] = luz.Color
			end
		end
	end
	local mapa = workspace:WaitForChild("Mapa")
	mapa.DescendantAdded:Connect(apuntarLuz)
	for _, luz in mapa:GetDescendants() do
		apuntarLuz(luz)
	end
	-- Por si la etiqueta llega después que la luz: las luces de esa pieza del mapa, a luna.
	local function apuntarPiezaLuna(pieza: Instance)
		if pieza:IsDescendantOf(mapa) then
			for _, hijo in pieza:GetChildren() do
				apuntarLuz(hijo)
			end
		end
	end
	CollectionService:GetInstanceAddedSignal("Luna"):Connect(apuntarPiezaLuna)
	for _, pieza in CollectionService:GetTagged("Luna") do
		apuntarPiezaLuna(pieza)
	end

	local faseAntes = workspace:GetAttribute("Fase")
	local avisado = false
	workspace:GetAttributeChangedSignal("Fase"):Connect(function()
		local fase = workspace:GetAttribute("Fase")
		if fase == "Noche" then
			titulo(Lang.t(nil, "Night {n}", { n = workspace:GetAttribute("Noche") }))
		elseif faseAntes == "Noche" then
			Ui.aviso(Lang.t(nil, "Dawn. It's gone… for now."))
		end
		faseAntes = fase
		avisado = false
	end)
	-- La hora corre en minutos, no en fotogramas: la iluminación se pinta unas 10 veces por segundo (rendimiento.md) y
	-- más seguido (30) mientras cambia deprisa (atardecer y amanecer: 0 < k < 1, o la franja cálida encendida). Los
	-- parpadeos de las bombillas (Efectos y DetallesVista, cortes de 30 a 140 ms) sí se ven a 10 Hz, así que las
	-- lámparas se repintan cada fotograma mientras haya alguno o tiemblen con el trueno (Ambiente.temblor). El relámpago
	-- (Ambiente.destello) es un fogonazo de décimas: mientras dura se pinta todo cada fotograma, y una vez más al acabar
	-- para quitarlo. El aviso del atardecer se mira cada fotograma, aparte.
	local desdePintar = math.huge
	local azarRugido = Random.new()
	local habiaParpadeo = false
	local habiaDestello = false
	RunService.RenderStepped:Connect(function(dt)
		desdePintar += dt
		local k, hora = momento()
		local cambia = (k > 0 and k < 1) or Ambiente.franja(hora) > 0
		local cadaCuanto = if cambia then 1 / 30 else 1 / 10
		local destello = Ambiente.destello > 0
		local parpadeo = next(Ambiente.factor) ~= nil or Ambiente.temblor > 0
		if desdePintar >= cadaCuanto or destello or habiaDestello then
			desdePintar = 0
			pintar(k, hora)
			habiaParpadeo = parpadeo
			habiaDestello = destello
		elseif habiaParpadeo or parpadeo then
			habiaParpadeo = parpadeo
			pintarLamparas(k)
		end
		local fin = workspace:GetAttribute("FaseFin")
		if not avisado and workspace:GetAttribute("Fase") == "Dia" and fin
			and fin - workspace:GetServerTimeNow() < Config.Ciclo.Aviso then
			avisado = true
			Ui.aviso(Lang.t(nil, "The sun is going down. Close everything."))
			-- Un rugido lejano desde un sitio del bosque (no en la cabeza): en 3D se sabe de dónde viene y OidoVista
			-- lo tapa dentro de casa. Alcance largo para que llegue de lejos sin sonar encima.
			local bc = Config.BosqueCalla
			local angulo = azarRugido:NextNumber(0, math.pi * 2)
			local lejos = azarRugido:NextNumber(bc.Rugido[1], bc.Rugido[2])
			local p = workspace.CurrentCamera.CFrame.Position
			local lejano = Sonido.en("Rugido", Vector3.new(p.X + math.cos(angulo) * lejos, 3, p.Z + math.sin(angulo) * lejos), 0.8)
			lejano.RollOffMinDistance = bc.RugidoMin
			lejano.RollOffMaxDistance = bc.RugidoMax
		end
	end)
	-- Sonidos sueltos del bosque, al azar y cada uno desde un sitio (pedido por el usuario: el fondo es solo viento y
	-- hojas, para que no se oiga siempre lo mismo). De noche lobos lejos, búhos en lo alto, ramas y grillos; de día,
	-- alguna rama. Con un bicho cerca el bosque se calla (Ambiente.bosqueCalla, Config.BosqueCalla): no suena ninguno
	-- hasta 25-40 s después de irse; al callarse, a veces una rama cruje hacia donde viene, y al volver la calma lo
	-- primero es un grillo cerca. De noche en calma suenan más seguido, para que el silencio se note. Números a ojo.
	task.spawn(function()
		local azar = Random.new()
		local bc = Config.BosqueCalla
		local SUELTOS_NOCHE = {
			{ "Lobo", 2, 110, 160 },
			{ "Buho", 3, 40, 80 },
			{ "Ramita", 3, 25, 60 },
			{ "Grillo", bc.PesoGrillo, 15, 35 },
		}
		local SUELTOS_DIA = { { "Ramita", 1, 25, 60 } }
		local function entre(r: { number }): number
			return azar:NextNumber(r[1], r[2])
		end
		-- `nombre` a `lejos` studs de la cámara en la dirección `angulo` (en planta).
		local function sonar(nombre: string, angulo: number, lejos: number)
			local alto = if nombre == "Buho" then azar:NextNumber(20, 35) else 1
			local p = workspace.CurrentCamera.CFrame.Position
			Sonido.en(nombre, Vector3.new(p.X + math.cos(angulo) * lejos, alto, p.Z + math.sin(angulo) * lejos),
				azar:NextNumber(0.9, 1.08))
		end
		local function bichos(): { Vector3 }
			local lista = {}
			local carpeta = workspace:FindFirstChild("Bichos")
			if carpeta then
				for _, modelo in carpeta:GetChildren() do
					if Ambiente.bichoCuenta(modelo) then
						local raiz = (modelo:FindFirstChild("HumanoidRootPart") or (modelo :: Model).PrimaryPart) :: BasePart?
						table.insert(lista, if raiz then raiz.Position else (modelo :: Model):GetPivot().Position)
					end
				end
			end
			return lista
		end
		local callado = false
		local callaHasta = -math.huge
		local siguiente = os.clock() + entre(bc.Espera)
		while true do
			task.wait(bc.Mirar)
			local ahora = os.clock()
			local noche = workspace:GetAttribute("Fase") == "Noche"
			local camara = workspace.CurrentCamera.CFrame.Position
			local antes = callado
			local cerca: Vector3?
			callado, callaHasta, cerca = Ambiente.bosqueCalla(bichos(), camara, ahora, callaHasta, entre(bc.Vuelve))
			if callado then
				-- Al callarse, a veces una sola rama cruje hacia donde viene (sin pasarse de él).
				if not antes and cerca and azar:NextNumber() < bc.RamaAviso then
					local dx, dz = cerca.X - camara.X, cerca.Z - camara.Z
					local lejos = math.min(entre(bc.Rama), math.max(math.sqrt(dx * dx + dz * dz), 8))
					sonar("Ramita", math.atan2(dz, dx), lejos)
				end
				continue
			end
			if antes then
				-- Vuelve la calma: lo primero, un grillo cerca (de día no hay grillos: solo se reanuda la espera).
				if noche then
					sonar("Grillo", azar:NextNumber(0, math.pi * 2), entre(bc.Grillo))
				end
				siguiente = ahora + entre(if noche then bc.Espera else bc.Dia)
				continue
			end
			-- Al anochecer, la espera larga del día no aguanta: se recorta a la de la noche.
			if noche and siguiente - ahora > bc.Espera[2] then
				siguiente = ahora + entre(bc.Espera)
			end
			if ahora < siguiente then
				continue
			end
			siguiente = ahora + entre(if noche then bc.Espera else bc.Dia)
			local lista = if noche then SUELTOS_NOCHE else SUELTOS_DIA
			local total = 0
			for _, s in lista do
				total += s[2]
			end
			local tirada = azar:NextNumber(0, total)
			for _, s in lista do
				tirada -= s[2]
				if tirada <= 0 then
					sonar(s[1], azar:NextNumber(0, math.pi * 2), azar:NextNumber(s[3], s[4]))
					break
				end
			end
		end
	end)
	-- De noche, con la cámara dentro de la casa (x -26..26, z -22..22), la madera cruje sola de vez en cuando en algún
	-- sitio cerca: no es nada, pero no se sabe.
	task.spawn(function()
		local azar = Random.new()
		while true do
			task.wait(azar:NextNumber(18, 45))
			local p = workspace.CurrentCamera.CFrame.Position
			if workspace:GetAttribute("Fase") == "Noche" and math.abs(p.X) < Config.Casa.MedioX and math.abs(p.Z) < Config.Casa.MedioZ and p.Y < 28 then
				local donde = p + Vector3.new(azar:NextNumber(-12, 12), azar:NextNumber(-3, 6), azar:NextNumber(-12, 12))
				Sonido.en("Cruje", donde, azar:NextNumber(0.85, 1.1))
			end
		end
	end)
end

return Ambiente
