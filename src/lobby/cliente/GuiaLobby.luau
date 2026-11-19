-- Guía corta del lobby para el jugador nuevo (16.7). Pedido por el usuario en el primer juego: el tutorial "tiene que
-- invadir más la pantalla y decir más vistoso dónde clicar" (la mitad de los nuevos se iba en 5 minutos). El lobby era una
-- explanada oscura sin ninguna pista.
--   Una sola línea de papel arriba en el centro y una flecha roja grande, que sube y baja, sobre lo que hay que tocar
--   (se ve a través de las paredes); si no está en la pantalla, otra flecha en el borde señala hacia dónde girarse (si
--   está detrás, a media altura en el borde izquierdo o derecho, hacia donde girar). Dos etapas, que decide el servidor (lobby/servidor/GuiaLobby) y publica en el atributo `GuiaLobby`:
--     "Coche"  nunca ha jugado: "Get in the car", la flecha va al coche libre más cercano. Se apaga al sentarse (atributo
--              `Coche`) y vuelve si se baja.
--     "Tienda" ya ha jugado y no ha comprado clase: "Your first class is free" (es cierto: Comprar.precioClase), la
--              flecha va al mostrador. Se apaga al abrir la tienda, al comprar, al subirse a un coche o a los
--              Config.Lobby.Guia.TiendaSegundos s. El servidor la da una sola vez por cuenta.
--   Todo cuelga de la capa común del HUD (Ui.hud, con su UIScale), el bucle es el de Bucle y solo corre mientras se ve.
--   La flecha del borde no se mete bajo el cartel; en el móvil no se pega a las esquinas de abajo (botón de saltar) ni
--   de arriba (botones de Roblox) y el cartel, centrado y estrecho (460), deja libres los lados. Con Rendimiento, sin vaivén ni deslizamiento.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Bucle = require(script.Parent.Bucle)
local Ui = require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))

local GuiaLobby = {}

local yo = Players.LocalPlayer
local SANGRE_VIVA = Color3.fromRGB(165, 22, 18) -- la flecha: más clara que Ui.Color.Sangre para verla de noche
local NOMBRE_BUCLE = "GuiaLobby"
local BUSCAR = 0.5 -- segundos entre una búsqueda de lo que señalar y la siguiente
-- Píxeles de diseño (como el resto del HUD).
local CARTEL_ANCHO, CARTEL_ALTO = 460, 56
local CARTEL_Y = 14
local FLECHA_MUNDO = 120 -- lado de la caja de la flecha sobre el coche o el mostrador (la flecha, en esa escala)
local FLECHA_BORDE = 70

local cartel: Frame
local linea: TextLabel
local flechaMundo: Frame
local halo: Frame
local pulso: UIScale
local mundo: BillboardGui
local flechaBorde: Frame

local activa = false -- se está enseñando la guía
local hecha = false -- la de la tienda ya cumplió (la siguió, compró, se subió a un coche o se agotó el tiempo)
local desde = 0 -- os.clock() de cuando salió
local clasesAl: any = nil -- lo comprado al aparecer la etapa de la tienda: si cambia, ha comprado
local etapaActual: string? = nil
local objetivo: BasePart? = nil
local proxima = 0
local ladoAnterior = 1 -- a qué lado iba la flecha de detrás: justo a la espalda no cambia de lado a cada fotograma
local vez = 0 -- sube al enseñar o esconder el cartel: el deslizamiento de antes ya no lo esconde

local function rendimiento(): boolean
	return yo:GetAttribute("Rendimiento") == true
end

-- La frase de la etapa (literales a la vista: así las encuentra la prueba de LangEs).
local function frase(etapa: string): string
	if etapa == "Tienda" then
		return Lang.t(nil, "Your first class is free")
	end
	return Lang.t(nil, "Get in the car")
end

-- Una flecha que apunta hacia abajo hecha con marcos (sin imágenes subidas): palo y punta en V. Las medidas van en
-- partes de la caja, para que valga igual en el mundo (que se escala con la pantalla) y en el borde.
local function flecha(padre: Instance, lado: UDim2): Frame
	local caja = Instance.new("Frame")
	caja.Name = "Flecha"
	caja.BackgroundTransparency = 1
	caja.Size = lado
	caja.AnchorPoint = Vector2.new(0.5, 0.5)
	local function trozo(nombre: string, tam: Vector2, pos: Vector2, giro: number)
		local f = Instance.new("Frame")
		f.Name = nombre
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = UDim2.fromScale(tam.X, tam.Y)
		f.Position = UDim2.fromScale(pos.X, pos.Y)
		f.Rotation = giro
		f.BackgroundColor3 = SANGRE_VIVA
		f.BorderSizePixel = 0
		local borde = Instance.new("UIStroke")
		borde.Color = Ui.Color.Hueso
		borde.Thickness = 3
		borde.Parent = f
		f.Parent = caja
	end
	trozo("Palo", Vector2.new(0.2, 0.55), Vector2.new(0.5, 0.3), 0)
	trozo("Izquierda", Vector2.new(0.2, 0.5), Vector2.new(0.36, 0.66), -45)
	trozo("Derecha", Vector2.new(0.2, 0.5), Vector2.new(0.64, 0.66), 45)
	caja.Parent = padre
	return caja
end

-- Dónde va la flecha del borde (en píxeles de diseño del HUD) y hacia dónde apunta (unitario, en la pantalla).
--   tam: la pantalla en píxeles de verdad; punto: lo que da WorldToViewportPoint (su Z es la profundidad: <= 0, detrás);
--   lado: la X de lo señalado vista desde la cámara (su signo dice a qué lado girarse); escala: la del HUD;
--   margenLado, margenArriba, margenAbajo: del centro de la flecha a cada borde, en píxeles de diseño.
-- Delante pero fuera de la pantalla: en el borde, en la dirección en que está. Detrás, la proyección no sirve (sale al
-- revés y casi siempre abajo en el centro, que no dice hacia dónde girarse): a media altura en el borde izquierdo o
-- derecho, apuntando a ese lado. La misma cuenta está en TutorialVista (a propósito, sin ayuda común).
local function sitioBorde(tam: Vector2, punto: Vector3, lado: number, escala: number, margenLado: number,
	margenArriba: number, margenAbajo: number): (Vector2, Vector2)
	local izq, der = margenLado * escala, tam.X - margenLado * escala
	local arriba, abajo = margenArriba * escala, tam.Y - margenAbajo * escala
	if der < izq then
		izq, der = tam.X / 2, tam.X / 2
	end
	if abajo < arriba then
		local m = (arriba + abajo) / 2
		arriba, abajo = m, m
	end
	local medio = Vector2.new(math.clamp(tam.X / 2, izq, der), math.clamp(tam.Y / 2, arriba, abajo))
	if punto.Z <= 0 then
		local signo = if lado < 0 then -1 else 1
		return Vector2.new(if signo > 0 then der else izq, medio.Y) / escala, Vector2.new(signo, 0)
	end
	local hacia = Vector2.new(punto.X, punto.Y) - tam / 2
	if hacia.Magnitude < 1 then
		hacia = Vector2.new(0, 1)
	end
	hacia = hacia.Unit
	local cabeX = (if hacia.X > 0 then der - medio.X else medio.X - izq) / math.max(math.abs(hacia.X), 1e-3)
	local cabeY = (if hacia.Y > 0 then abajo - medio.Y else medio.Y - arriba) / math.max(math.abs(hacia.Y), 1e-3)
	return (medio + hacia * math.max(math.min(cabeX, cabeY), 0)) / escala, hacia
end
GuiaLobby.sitioBorde = sitioBorde -- para el banco (tests/bancos/flecha-borde.luau)

local function ladoMundo(): number
	return FLECHA_MUNDO * Ui.escala()
end

local function construir()
	local hud = Ui.hud()
	cartel = Instance.new("Frame")
	cartel.Name = "GuiaLobby"
	cartel.AnchorPoint = Vector2.new(0.5, 0)
	cartel.Position = UDim2.new(0.5, 0, 0, CARTEL_Y)
	cartel.Size = UDim2.fromOffset(CARTEL_ANCHO, CARTEL_ALTO) -- cabe siempre: el lienzo más pequeño mide ~1000 de ancho
	cartel.BackgroundColor3 = Ui.Color.Papel
	cartel.BackgroundTransparency = 0.08
	cartel.Visible = false
	cartel.ZIndex = 40
	local borde = Instance.new("UIStroke")
	borde.Color = Ui.Color.Sangre
	borde.Thickness = 3
	borde.Parent = cartel
	local esquina = Instance.new("UICorner")
	esquina.CornerRadius = UDim.new(0, 4)
	esquina.Parent = cartel
	local mancha = Ui.mancha(cartel)
	mancha.ZIndex = 40
	mancha.Size = UDim2.fromOffset(110, 70)
	linea = Ui.texto("", {
		Size = UDim2.fromScale(1, 1),
		TextSize = 30,
		ZIndex = 41,
	})
	Ui.queQuepa(linea, 30)
	linea.Parent = cartel
	cartel.Parent = hud

	-- La flecha del mundo, en un BillboardGui dentro de PlayerGui (las cinemáticas lo apagan con todo lo demás). Su
	-- tamaño sigue a la escala del HUD (los BillboardGui no tienen UIScale).
	mundo = Instance.new("BillboardGui")
	mundo.Name = "GuiaFlecha"
	mundo.AlwaysOnTop = true
	mundo.LightInfluence = 0
	mundo.ResetOnSpawn = false
	mundo.Enabled = false
	mundo.Size = UDim2.fromOffset(ladoMundo(), ladoMundo())
	-- Un círculo rojo flojo detrás de la punta, que late: se ve desde lejos aunque la flecha quede pequeña.
	halo = Instance.new("Frame")
	halo.Name = "Halo"
	halo.AnchorPoint = Vector2.new(0.5, 0.5)
	halo.Position = UDim2.fromScale(0.5, 0.78)
	halo.Size = UDim2.fromScale(0.6, 0.6)
	halo.BackgroundColor3 = SANGRE_VIVA
	halo.BackgroundTransparency = 0.7
	halo.BorderSizePixel = 0
	local redondo = Instance.new("UICorner")
	redondo.CornerRadius = UDim.new(0.5, 0)
	redondo.Parent = halo
	pulso = Instance.new("UIScale")
	pulso.Parent = halo
	halo.Parent = mundo
	flechaMundo = flecha(mundo, UDim2.fromScale(0.8, 0.8))
	flechaMundo.Position = UDim2.fromScale(0.5, 0.5)
	mundo.Parent = yo:WaitForChild("PlayerGui")
	Ui.hud():GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		mundo.Size = UDim2.fromOffset(ladoMundo(), ladoMundo())
	end)

	flechaBorde = flecha(hud, UDim2.fromOffset(FLECHA_BORDE, FLECHA_BORDE))
	flechaBorde.Visible = false
	flechaBorde.ZIndex = 39
end

-- Lo que hay que señalar ahora. Coche: el libre más cercano (sin dueño ni salida ni llegada en marcha); si no hay
-- libre, uno con gente que no se vaya (se puede subir de acompañante); si no, nada. Tienda: el mostrador.
local function buscar(etapa: string, desde3D: Vector3): BasePart?
	if etapa == "Tienda" then
		local mapa = workspace:FindFirstChild("Mapa")
		local m = mapa and mapa:FindFirstChild("Mostrador")
		return if m and m:IsA("BasePart") then m else nil
	end
	local carpeta = workspace:FindFirstChild("Coches")
	if not carpeta then
		return nil
	end
	local mejor: BasePart?, mejorLibre, mejorDist = nil, false, math.huge
	for _, modelo in carpeta:GetChildren() do
		local cuerpo = modelo:IsA("Model") and (modelo.PrimaryPart or modelo:FindFirstChild("Carroceria")) or nil
		if cuerpo and cuerpo:IsA("BasePart") and modelo:GetAttribute("Salida") == nil and modelo:GetAttribute("Llegada") == nil then
			local libre = modelo:GetAttribute("Dueno") == nil
			local d = (cuerpo.Position - desde3D).Magnitude
			if (libre and not mejorLibre) or (libre == mejorLibre and d < mejorDist) then
				mejor, mejorLibre, mejorDist = cuerpo, libre, d
			end
		end
	end
	return mejor
end

local function apagarFlechas()
	mundo.Enabled = false
	mundo.Adornee = nil
	flechaBorde.Visible = false
	objetivo = nil
	proxima = 0
end

local function cadaFotograma(_dt: number, ahora: number, camara: Camera)
	local etapa = etapaActual
	if not etapa then
		return
	end
	if etapa == "Tienda" and ahora - desde > Config.Lobby.Guia.TiendaSegundos then
		hecha = true
		GuiaLobby.repasar()
		return
	end
	-- Con el HUD apagado o la cámara de una cinemática, ni cartel ni flechas: se pintarían encima de la vista.
	if not Ui.hud().Enabled or camara.CameraType == Enum.CameraType.Scriptable then
		cartel.Visible = false
		apagarFlechas()
		return
	end
	cartel.Visible = true

	local raiz = yo.Character and yo.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not raiz or yo:GetAttribute("Muerto") then
		apagarFlechas()
		return
	end
	if ahora >= proxima then
		proxima = ahora + BUSCAR
		objetivo = buscar(etapa, raiz.Position)
		mundo.Adornee = objetivo
		mundo.StudsOffsetWorldSpace = Vector3.new(0, Config.Lobby.Guia.Altura[etapa] or 5, 0)
		mundo.Enabled = objetivo ~= nil
	end
	local vaiven = if rendimiento() then 0 else math.sin(ahora * 4)
	flechaMundo.Position = UDim2.new(0.5, 0, 0.5, vaiven * 8)
	pulso.Scale = 1 + vaiven * 0.12

	-- Flecha del borde: si lo señalado no está delante.
	flechaBorde.Visible = false
	local meta = objetivo
	if meta and meta.Parent then
		-- El segundo valor de WorldToViewportPoint dice si se ve (delante y dentro), no si está delante: eso lo dice la Z.
		local punto, seVe = camara:WorldToViewportPoint(meta.Position)
		local tam = camara.ViewportSize
		if not (seVe and punto.Z > 0) then
			local lado = camara.CFrame:PointToObjectSpace(meta.Position).X
			if math.abs(lado) > 0.5 then
				ladoAnterior = if lado < 0 then -1 else 1
			end
			local tactil = Ui.tactil()
			-- Márgenes a cada borde: arriba, por debajo del cartel (y en el móvil de los botones de Roblox); abajo, en el
			-- móvil, por encima del botón de saltar (abajo a la derecha) y del joystick.
			local margenArriba = math.max(CARTEL_Y + CARTEL_ALTO + FLECHA_BORDE / 2 + 8, if tactil then 110 else 70)
			local sitio, hacia = sitioBorde(tam, punto, ladoAnterior, Ui.escala(), 70, margenArriba,
				if tactil then 300 else 70)
			sitio += hacia * vaiven * 6 -- empuja hacia donde señala (quieta con Rendimiento)
			flechaBorde.Position = UDim2.fromOffset(sitio.X, sitio.Y)
			-- La flecha apunta hacia abajo (0, 1): girarla hacia `hacia`.
			flechaBorde.Rotation = math.deg(math.atan2(hacia.Y, hacia.X)) - 90
			flechaBorde.Visible = true
		end
	end
end

local function ensenar(etapa: string)
	activa = true
	etapaActual = etapa
	desde = os.clock()
	if etapa == "Tienda" then
		clasesAl = yo:GetAttribute("Clases")
	end
	linea.Text = frase(etapa)
	vez += 1
	cartel.Visible = true
	if rendimiento() then
		cartel.Position = UDim2.new(0.5, 0, 0, CARTEL_Y)
	else
		-- Baja desde arriba con un pequeño rebote.
		cartel.Position = UDim2.new(0.5, 0, 0, -CARTEL_ALTO - 10)
		TweenService:Create(cartel, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Position = UDim2.new(0.5, 0, 0, CARTEL_Y) }):Play()
	end
	Bucle.cada(NOMBRE_BUCLE, cadaFotograma)
end

local function esconder()
	activa = false
	etapaActual = nil
	vez += 1
	local esta = vez
	Bucle.quitar(NOMBRE_BUCLE)
	apagarFlechas()
	if rendimiento() or not cartel.Visible then
		cartel.Visible = false
		return
	end
	local sube = TweenService:Create(cartel, TweenInfo.new(0.2), { Position = UDim2.new(0.5, 0, 0, -CARTEL_ALTO - 10) })
	sube.Completed:Connect(function()
		if vez == esta then -- si mientras tanto volvió a salir, no se esconde
			cartel.Visible = false
		end
	end)
	sube:Play()
end

-- ¿Toca verse ahora? Mira el atributo del servidor y lo que ya ha hecho en esta visita.
local function debeVerse(): string?
	local etapa = yo:GetAttribute("GuiaLobby")
	if etapa ~= "Coche" and etapa ~= "Tienda" then
		return nil
	end
	if etapa == "Tienda" then
		if hecha then
			return nil
		end
		-- Se sube a un coche o compra una clase: ya no hace falta.
		if yo:GetAttribute("Coche") ~= nil or (activa and yo:GetAttribute("Clases") ~= clasesAl) then
			hecha = true
			return nil
		end
	elseif yo:GetAttribute("Coche") ~= nil then
		return nil -- sentado: ya hizo lo que pedía (si se baja, vuelve)
	end
	return etapa
end

function GuiaLobby.repasar()
	local etapa = debeVerse()
	if etapa and (not activa or etapa ~= etapaActual) then
		ensenar(etapa)
	elseif not etapa and activa then
		esconder()
	end
end

function GuiaLobby.start()
	construir()
	for _, atributo in { "GuiaLobby", "Coche", "Clases" } do
		yo:GetAttributeChangedSignal(atributo):Connect(GuiaLobby.repasar)
	end
	-- Abrir la tienda (el mismo prompt que usa TiendaUi) cumple la guía de la tienda.
	task.spawn(function()
		local mostrador = workspace:WaitForChild("Mapa"):WaitForChild("Mostrador")
		local prompt = mostrador:WaitForChild("Tienda") :: ProximityPrompt
		prompt.Triggered:Connect(function()
			if etapaActual == "Tienda" then
				hecha = true
				GuiaLobby.repasar()
			end
		end)
	end)
	GuiaLobby.repasar()
end

return GuiaLobby
