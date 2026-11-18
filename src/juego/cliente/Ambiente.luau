-- Luz, niebla y hora del día en el cliente, a partir de los atributos del Ciclo (Fase, Noche, FaseInicio, FaseFin).
-- Día gris y apagado con bruma de bosque; noche casi negra con niebla azulada. Las transiciones, al final del día
-- (atardecer) y al final de la noche (amanecer).
-- También: viento de fondo, el aviso de que se pone el sol, "NOCHE n" grande al anochecer y el aviso del amanecer.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
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

-- Parpadeos (DetallesVista): luz → cuánto de su brillo le queda ahora (0 a 1). Sin entrada, todo.
Ambiente.factor = {} :: { [Light]: number }

-- Tormenta seca (TormentaVista, tormenta.md): lo pone TormentaVista y se suma encima de lo de aquí en cada fotograma.
--   destello: fogonazo del relámpago de 0 a 1 (luz de fuera, niebla, ColorCorrection y las lunas de `lunas`).
--   lunas: luz de luna → cuánto de Config.Tormenta.Luz.Luna se le suma ahora (0 a 1).
--   temblor: las bombillas (PointLight) tiemblan con el trueno, de 0 a 1.
Ambiente.destello = 0
Ambiente.lunas = {} :: { [Light]: number }
Ambiente.temblor = 0
-- Cielo cerrado (CieloVista, cielo.md): de 0 a 1, la tormenta en rampa. Baja algo la luz de fuera
-- (Config.Cielo.Tormenta.Luz); con 0, nada.
Ambiente.nublado = 0
local semillas: { [Light]: number } = {} -- cada bombilla tiembla a su aire
local contador = 0
local CONTRASTE = 0.1

local atmosfera: Atmosphere
local color: ColorCorrectionEffect
local viento: Sound? -- nil mientras no haya un viento en Config.Sonidos

local function mezcla(a: number, b: number, k: number): number
	return a + (b - a) * k
end

-- Suma a un color un RGB ({ r, g, b } de 0 a 255) por k.
local function mas(c: Color3, d: { number }, k: number): Color3
	k /= 255
	return Color3.new(math.min(1, c.R + d[1] * k), math.min(1, c.G + d[2] * k), math.min(1, c.B + d[3] * k))
end

-- Cuánto de noche (0 a 1) y la hora (ClockTime) según la fase y lo que lleva de ella.
local function momento(): (number, number)
	local fase = workspace:GetAttribute("Fase")
	local inicio, fin = workspace:GetAttribute("FaseInicio"), workspace:GetAttribute("FaseFin")
	if not fase or not inicio or not fin then
		return 0, 12
	end
	local p = math.clamp((workspace:GetServerTimeNow() - inicio) / math.max(1, fin - inicio), 0, 1)
	if fase == "Dia" then
		return math.clamp((p - 0.8) / 0.2, 0, 1), 6.5 + p * 12
	end
	-- De noche la hora corre deprisa hasta medianoche y luego apenas se mueve (la luna siempre alta); al final, hacia
	-- el amanecer.
	local k = 1 - math.clamp((p - 0.9) / 0.1, 0, 1)
	local hora = if p < 0.08 then 18.5 + p / 0.08 * 5.5
		elseif p < 0.9 then (24 + (p - 0.08) / 0.82 * 2) % 24
		else 2 + (p - 0.9) / 0.1 * 4.5
	return k, hora
end

-- Lo de las lámparas del mapa: su brillo según cuánto de noche es (k) y los parpadeos (factor).
local function pintarLamparas(k: number)
	local proporcion = mezcla(DIA.Lamparas, NOCHE.Lamparas, k)
	local temblor = Ambiente.temblor
	local reloj = os.clock()
	for luz, base in lamparas do
		if luz.Parent then
			local brillo = base * proporcion * (Ambiente.factor[luz] or 1)
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
			Ambiente.factor[luz] = nil
			Ambiente.lunas[luz] = nil
			semillas[luz] = nil
		end
	end
end

local function pintar(k: number, hora: number)
	Lighting.ClockTime = hora
	Lighting.Brightness = mezcla(DIA.Brightness, NOCHE.Brightness, k)
	Lighting.Ambient = DIA.Ambient:Lerp(NOCHE.Ambient, k)
	Lighting.OutdoorAmbient = DIA.OutdoorAmbient:Lerp(NOCHE.OutdoorAmbient, k)
	local nublado = Ambiente.nublado
	if nublado > 0 then -- con el cielo cerrado de tormenta llega menos luz de fuera (el relámpago, encima, entero)
		local f = 1 - (1 - Config.Cielo.Tormenta.Luz) * math.min(nublado, 1)
		local fuera = Lighting.OutdoorAmbient
		Lighting.Brightness *= f
		Lighting.OutdoorAmbient = Color3.new(fuera.R * f, fuera.G * f, fuera.B * f)
	end
	atmosfera.Density = mezcla(DIA.Densidad, NOCHE.Densidad, k)
	atmosfera.Color = DIA.Niebla:Lerp(NOCHE.Niebla, k)
	atmosfera.Decay = atmosfera.Color
	color.Brightness = mezcla(DIA.Brillo, NOCHE.Brillo, k)
	Lighting.ExposureCompensation = mezcla(DIA.Exposicion, NOCHE.Exposicion, k)
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
		color.Brightness += T.Color * d
		color.Contrast = CONTRASTE + T.Contraste * d
	end
	if viento then
		viento.Volume = Config.Sonidos.Viento.Volumen * (1 + k)
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
	atmosfera.Offset = 0.1
	atmosfera.Glare = 0
	atmosfera.Haze = 2
	atmosfera.Parent = Lighting
	color = Instance.new("ColorCorrectionEffect")
	color.Saturation = -0.35 -- colores apagados, realistas
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
	local function apuntarLuz(luz: Instance)
		if luz:IsA("Light") and not lamparas[luz] then
			lamparas[luz] = luz.Brightness
			contador += 1
			semillas[luz] = contador * 1.618
		end
	end
	local mapa = workspace:WaitForChild("Mapa")
	mapa.DescendantAdded:Connect(apuntarLuz)
	for _, luz in mapa:GetDescendants() do
		apuntarLuz(luz)
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
	-- más seguido (30) mientras cambia deprisa (atardecer y amanecer: 0 < k < 1). Los parpadeos de las bombillas (Efectos
	-- y DetallesVista, cortes de 30 a 140 ms) sí se ven a 10 Hz, así que las lámparas se repintan cada fotograma mientras
	-- haya alguno o tiemblen con el trueno (Ambiente.temblor). El relámpago (Ambiente.destello) es un fogonazo de
	-- décimas: mientras dura se pinta todo cada fotograma, y una vez más al acabar para quitarlo. El aviso del
	-- atardecer se mira cada fotograma, aparte.
	local desdePintar = math.huge
	local habiaParpadeo = false
	local habiaDestello = false
	RunService.RenderStepped:Connect(function(dt)
		desdePintar += dt
		local k, hora = momento()
		local cadaCuanto = if k > 0 and k < 1 then 1 / 30 else 1 / 10
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
			local lejano = Sonido.tocar("Rugido") -- un rugido lejano en el bosque
			lejano.Volume *= 0.3
			lejano.PlaybackSpeed = 0.8
		end
	end)
	-- Sonidos sueltos del bosque, al azar y cada uno desde un sitio (pedido por el usuario: el fondo es solo viento y
	-- hojas, para que no se oiga siempre lo mismo). De noche lobos lejos, búhos en lo alto, ramas y grillos; de día,
	-- alguna rama. Números a ojo.
	task.spawn(function()
		local azar = Random.new()
		local SUELTOS_NOCHE = { { "Lobo", 2, 110, 160 }, { "Buho", 3, 40, 80 }, { "Ramita", 3, 25, 60 }, { "Grillo", 3, 15, 35 } }
		local SUELTOS_DIA = { { "Ramita", 1, 25, 60 } }
		while true do
			local noche = workspace:GetAttribute("Fase") == "Noche"
			task.wait(if noche then azar:NextNumber(10, 28) else azar:NextNumber(30, 70))
			local lista = if workspace:GetAttribute("Fase") == "Noche" then SUELTOS_NOCHE else SUELTOS_DIA
			local total = 0
			for _, s in lista do
				total += s[2]
			end
			local tirada = azar:NextNumber(0, total)
			for _, s in lista do
				tirada -= s[2]
				if tirada <= 0 then
					local angulo = azar:NextNumber(0, math.pi * 2)
					local lejos = azar:NextNumber(s[3], s[4])
					local alto = if s[1] == "Buho" then azar:NextNumber(20, 35) else 1
					local p = workspace.CurrentCamera.CFrame.Position
					Sonido.en(s[1], Vector3.new(p.X + math.cos(angulo) * lejos, alto, p.Z + math.sin(angulo) * lejos),
						azar:NextNumber(0.9, 1.08))
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
