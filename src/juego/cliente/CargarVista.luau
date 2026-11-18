-- Lo pesado en el cliente (lo manda el servidor: juego/servidor/Cargar). Mientras llevas algo (atributo Cargando):
--   la E, X en el mando o el botón SOLTAR del móvil lo suelta; con las manos ocupadas no salen los carteles de coger.
--   La vista baja un poco y se balancea al andar, más despacio cuanto más pesa.
--   Usar lo que llevas (R, Y en el mando o el botón del móvil): mirando algo con lo que sirve sale un cartel junto a ello
--   (tronco -> caballete: SERRAR; tablón -> ventana o puerta dañada: CLAVAR; tablón reforzado: REFORZAR; bidón ->
--   generador o coche: ECHAR GASOLINA; motor o rueda -> coche: MONTAR).
-- Con físicas de verdad (15.8, pedido por el usuario: "todo"; cuentas en shared/CargarReglas):
--   Lo que llevas tú solo (la pieza con el atributo Lleva = tu UserId) lo simula tu cliente y aquí se mueve cada
--   fotograma: al hombro (troncos y tablones) o delante, girando con un muelle que se queda atrás y se pasa un poco,
--   bajando a cada paso y ladeándose. Choca con las paredes y los marcos (lo hace la física de Roblox).
--   La E lo deja en el suelo con cuidado (Config.Cargar.Dejar s bajándolo) para que no suene; lo de varios, de golpe.
--   Lanzar (solo madera): mantener clic, R2 o el botón LANZAR coge fuerza (lo echas atrás) y al soltar sale.
--   Sonidos: el golpe de lo que cae (remote Pesado, para todos) y el arrastre en bucle (atributo Arrastra de la pieza).
--   CargarVista.lanzado(): os.clock del último lanzamiento (para las manos: ManosGestos).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local CargarReglas = require(ReplicatedStorage.Shared.CargarReglas)
local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Recetas = require(ReplicatedStorage.Shared.Recetas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sonido = require(script.Parent.Sonido)
local Ui = require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))

local CargarVista = {}

local C, PESADOS = Config.Cargar, Config.Pesados
local B = C.Balanceo

-- Con qué se usa cada cosa y qué pone el cartel (`textos`: otro cartel según la etiqueta del objetivo).
local USOS: { [string]: { etiquetas: { string }, texto: string, textos: { [string]: string }? } } = {
	Tronco = { etiquetas = { "Caballete", "Chimenea" }, texto = "Saw", textos = { Chimenea = "Add to fire" } },
	Tablon = { etiquetas = { "Ventana", "Puerta" }, texto = "Nail" },
	TablonReforzado = { etiquetas = { "Ventana", "Puerta" }, texto = "Reinforce" },
	Bidon = { etiquetas = { "Generador", "Coche", "Gasolina" }, texto = "Refuel", textos = { Gasolina = "Pour fuel" } },
	Reja = { etiquetas = { "MarcoReja" }, texto = "Mount" },
	Motor = { etiquetas = { "Coche" }, texto = "Install" },
	Rueda = { etiquetas = { "Coche" }, texto = "Install" },
}

local jugador = Players.LocalPlayer
local Camara = require(script.Parent.Camara)
local aviso: TextLabel
local boton: TextButton?
local botonUsar: TextButton?
local botonLanzar: TextButton?
local cartel: BillboardGui
local textoCartel: TextLabel
local objetivo: Instance? = nil
local balanceo = 0
local vistaPropia = false -- este módulo mueve el CameraOffset (llevando algo, o volviendo a 0 tras soltarlo)
local buscado = 0
local textoUsar = "" -- lo que dice el cartel de usar (sin la tecla): se repinta si cambia el tipo de entrada

-- Lo que llevo yo solo y cómo va (15.8).
local mia: BasePart? = nil
local buscadoMia = 0
local angulo, velGiro = 0, 0 -- el muelle del giro (radianes y rad/s)
local fase, paso = 0, 0 -- los pasos (fase) y lo que se nota el balanceo (0..1)
local cargaDesde: number? = nil -- os.clock desde que se mantiene para lanzar
local dejandoDesde: number? = nil -- os.clock desde que se está dejando en el suelo con la E
local dejarSuelo: number? = nil -- la Y del suelo donde se deja
local dejado = false -- ya en el suelo y pedido soltarlo: se queda ahí hasta que el servidor lo suelte
local ultimoLanzado = -math.huge
local suelo = RaycastParams.new()
suelo.FilterType = Enum.RaycastFilterType.Exclude
suelo.RespectCanCollide = true

local function tipoQueLlevo(): string?
	local tipo = jugador:GetAttribute("Cargando")
	return if type(tipo) == "string" then tipo else nil
end

-- La pieza que llevo yo solo (nil si no llevo nada, o la llevamos entre varios).
local function buscarMia(): BasePart?
	local tipo = tipoQueLlevo()
	if not tipo then
		mia = nil
		return nil
	end
	if mia and mia.Parent and mia:GetAttribute("Lleva") == jugador.UserId and mia:GetAttribute("Tipo") == tipo then
		return mia
	end
	mia = nil
	if os.clock() - buscadoMia < 0.2 then
		return nil
	end
	buscadoMia = os.clock()
	for _, p in CollectionService:GetTagged("Pesado") do
		if p:IsA("BasePart") and p:GetAttribute("Lleva") == jugador.UserId and p:GetAttribute("Tipo") == tipo then
			mia = p
			-- Empieza donde miras, sin balanceo de lo de antes.
			local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if raiz then
				local f = CargarReglas.frente(raiz.CFrame)
				angulo, velGiro = math.atan2(-f.X, -f.Z), 0
			end
			break
		end
	end
	return mia
end

local function puedeLanzar(): boolean
	local tipo = tipoQueLlevo()
	return tipo ~= nil and CargarReglas.lanzable(tipo) and buscarMia() ~= nil and dejandoDesde == nil
		and not jugador:GetAttribute("Trabajando")
end

local function soltar()
	if not jugador:GetAttribute("Cargando") or jugador:GetAttribute("Trabajando") or dejandoDesde then
		return
	end
	cargaDesde = nil
	if buscarMia() then
		dejandoDesde = os.clock() -- lo baja al suelo y luego lo suelta (mover)
		dejarSuelo, dejado = nil, false
	else
		Remotes.Cargar:FireServer() -- entre varios o arrastrando: de golpe
	end
end

local function empezarLanzar()
	if puedeLanzar() and not cargaDesde then
		cargaDesde = os.clock()
	end
end

local function lanzar()
	local desde = cargaDesde
	cargaDesde = nil
	if not desde or not puedeLanzar() then
		return
	end
	local mantenido = os.clock() - desde
	if mantenido < C.Lanzar.Minimo then
		return -- un clic suelto no lanza
	end
	ultimoLanzado = os.clock()
	Remotes.Cargar:FireServer("Lanzar", math.clamp(mantenido / C.Lanzar.Carga, 0, 1), Camara.get().CFrame.LookVector)
	if Sonido.hay("Lanzar") then
		Sonido.tocar("Lanzar")
	end
end

local function usar()
	if objetivo and jugador:GetAttribute("Cargando") and not jugador:GetAttribute("Trabajando") and not dejandoDesde then
		cargaDesde = nil
		Remotes.Usar:FireServer(objetivo)
	end
end

local function cambiar()
	local tipo = tipoQueLlevo()
	local llevando = tipo ~= nil
	if not llevando then
		mia, cargaDesde, dejandoDesde = nil, nil, nil
	end
	local tactil = UserInputService.TouchEnabled
	if not tactil then
		aviso.Text = if tipo and CargarReglas.lanzable(tipo)
			then Ui.mayusculas(Lang.t(nil, "[E] Drop   [Click] Throw"))
			else "[E]  " .. Ui.mayusculas(Lang.t(nil, "Drop"))
	end
	TweenService:Create(aviso, TweenInfo.new(0.3), {
		TextTransparency = if llevando then 0.25 else 1,
		TextStrokeTransparency = if llevando then 0.6 else 1,
	}):Play()
	if boton then
		boton.Visible = llevando
	end
	if botonLanzar then
		botonLanzar.Visible = tipo ~= nil and CargarReglas.lanzable(tipo)
	end
end

-- ¿Sirve lo que llevo con esto? Las ventanas, por dentro y si están dañadas; las puertas, si están dañadas (con el
-- tablón reforzado, si no lo están ya). El coche, si le falta eso (o gasolina).
local function sirve(el: Instance, raiz: BasePart, tipo: string): boolean
	if el:GetAttribute("Bloqueada") then
		return false
	end
	if CollectionService:HasTag(el, "Gasolina") then -- cruces del final de la Bestia (Preparativos)
		return el:GetAttribute("Lleno") ~= true
	end
	if CollectionService:HasTag(el, "MarcoReja") then
		return el:GetAttribute("Montada") ~= true
	end
	if CollectionService:HasTag(el, "Coche") then
		local coche = { piezas = {}, gasolina = el:GetAttribute("Gasolina") or 0 }
		for _, p in Config.Coche.Piezas do
			coche.piezas[p[1]] = el:GetAttribute(p[1]) or 0
		end
		return Recetas.necesita(coche :: any, tipo, Config.Coche)
	end
	if CollectionService:HasTag(el, "Ventana") or CollectionService:HasTag(el, "Puerta") then
		local danada = (el:GetAttribute("Vida") or 0) < (el:GetAttribute("VidaMax") or 0) or (el:GetAttribute("Cristal") or 0) > 0
		if tipo == "TablonReforzado" then
			danada = not el:GetAttribute("Refuerzo")
		end
		local centro = el:GetAttribute("Centro")
		if CollectionService:HasTag(el, "Ventana") and typeof(centro) == "CFrame" then
			return danada and (raiz.Position - centro.Position):Dot(centro.LookVector) < 0
		end
		return danada
	end
	return true
end

-- Lo más cerca que tengas delante con lo que sirva lo que llevas.
local function buscar(): Instance?
	local tipo = jugador:GetAttribute("Cargando")
	local uso = tipo and USOS[tipo]
	local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not uso or not raiz or jugador:GetAttribute("Trabajando") then
		return nil
	end
	local mejor, distancia = nil, Config.Casa.Alcance
	for _, etiqueta in uso.etiquetas do
		for _, el in CollectionService:GetTagged(etiqueta) do
			local mando = el:FindFirstChild("Mando")
			if not mando or not mando:IsA("BasePart") then
				continue
			end
			local d = (mando.Position - raiz.Position).Magnitude
			local hacia = mando.Position - Camara.get().CFrame.Position
			local delante = hacia.Magnitude > 0.1 and (d < 3.5 or hacia.Unit:Dot(Camara.get().CFrame.LookVector) > 0.55) -- muy cerca, vale de lado
			if d < distancia and delante and sirve(el, raiz, tipo) then
				mejor, distancia = el, d
			end
		end
	end
	return mejor
end

local function apuntar()
	local nuevo = buscar()
	if nuevo == objetivo then
		return
	end
	objetivo = nuevo
	local tipo = jugador:GetAttribute("Cargando")
	local texto = ""
	if objetivo and tipo then
		local uso = USOS[tipo]
		local frase = uso.texto
		for etiqueta, otra in uso.textos or {} do
			if CollectionService:HasTag(objetivo, etiqueta) then
				frase = otra
			end
		end
		texto = Ui.mayusculas(Lang.t(nil, frase))
	end
	cartel.Adornee = if objetivo then objetivo:FindFirstChild("Mando") :: BasePart else nil
	cartel.Enabled = objetivo ~= nil
	textoUsar = texto
	textoCartel.Text = Ui.pista("R", texto)
	if botonUsar then
		botonUsar.Text = texto
		botonUsar.Visible = objetivo ~= nil
	end
end

local function suave(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

-- Mueve lo que llevo yo solo (15.8): dónde debe ir (CargarReglas.sitio) con el muelle del giro, el balanceo de los
-- pasos, echarlo atrás al cargar el lanzamiento y bajarlo al suelo al dejarlo. Lo sigue la física de mi cliente.
local function moverMia(dt: number)
	local pieza = buscarMia()
	local personaje = jugador.Character
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not pieza or not raiz or not personaje then
		return
	end
	local agarre = pieza:FindFirstChild("Agarre")
	local empuje = agarre and agarre:FindFirstChildOfClass("AlignPosition")
	local giro = pieza:FindFirstChild("Giro")
	if not empuje or not giro or not giro:IsA("AlignOrientation") then
		return
	end
	local tipo = pieza:GetAttribute("Tipo")
	local f = CargarReglas.frente(raiz.CFrame)
	angulo, velGiro = CargarReglas.muelle(angulo, velGiro, math.atan2(-f.X, -f.Z), dt)
	local cf = CargarReglas.sitio(tipo, pieza.Size, CFrame.new(raiz.Position) * CFrame.Angles(0, angulo, 0))

	-- Los pasos: baja a cada uno y se ladea (más cuanto más deprisa andas).
	local v = raiz.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
	local andando = v.Magnitude > 1
	paso += ((if andando then 1 else 0) - paso) * (1 - math.exp(-dt * 6))
	if andando then
		fase += v.Magnitude * dt * B.Paso * math.pi
	end
	local bote = -math.abs(math.sin(fase)) * B.Bote * paso
	local ladeo = math.sin(fase) * math.rad(B.Ladeo) * paso
	cf = CFrame.new(0, bote, 0) * cf * CFrame.Angles(ladeo, 0, 0)

	-- Cargando el lanzamiento: atrás, un poco arriba y la punta levantada.
	if cargaDesde then
		local k = suave((os.clock() - cargaDesde) / C.Lanzar.Carga)
		cf = CFrame.new(-f * C.Lanzar.Atras * k + Vector3.new(0, 0.25 * k, 0)) * cf * CFrame.Angles(0, 0, math.rad(12) * k)
	end

	-- Dejándolo en el suelo: baja recto, ya sin la punta levantada, y al llegar se suelta.
	if dejandoDesde then
		if not dejarSuelo then
			suelo.FilterDescendantsInstances = { personaje, pieza }
			local hit = workspace:Raycast(cf.Position + Vector3.new(0, 1, 0), Vector3.new(0, -12, 0), suelo)
			dejarSuelo = if hit then hit.Position.Y else raiz.Position.Y - 3
		end
		local k = suave((os.clock() - dejandoDesde) / C.Dejar)
		local plano = cf.XVector * Vector3.new(1, 0, 1)
		local eje = if plano.Magnitude > 0.01 then plano.Unit else f
		local alto = pieza.Size.Y / 2 + 0.05 -- ya con su eje Y hacia arriba
		local abajo = Vector3.new(cf.Position.X, (dejarSuelo :: number) + alto, cf.Position.Z)
		cf = CFrame.fromMatrix(cf.Position:Lerp(abajo, k), eje, Vector3.yAxis)
		if k >= 1 and not dejado then
			dejado = true -- y no lo vuelve a subir mientras llega la respuesta (si no, caía desde el hombro y sonaba)
			Remotes.Cargar:FireServer()
		end
	end
	empuje.Position = cf.Position
	giro.CFrame = cf.Rotation
end

-- Vista más baja y balanceo al andar con peso; al hombro, la cabeza algo apartada hacia la izquierda.
local function mover(dt: number)
	buscado += dt
	if buscado > 0.15 then
		buscado = 0
		apuntar()
	end
	moverMia(dt)
	local humanoide = jugador.Character and jugador.Character:FindFirstChildOfClass("Humanoid")
	if not humanoide then
		return
	end
	local tipo = tipoQueLlevo()
	local llevando = tipo ~= nil
	if not llevando and not vistaPropia then
		return -- sin nada en las manos el CameraOffset es de CuerpoVista (agacharse y asomarse, 14.6)
	end
	local andando = humanoide.MoveDirection.Magnitude > 0.1 and humanoide.WalkSpeed > 0
	if llevando and andando then
		balanceo += dt * (2 + humanoide.WalkSpeed * 0.45)
	end
	local hombro = tipo ~= nil and CargarReglas.alHombro(tipo)
	local objetivoVista = if llevando
		then Vector3.new(math.sin(balanceo) * 0.12 - (if hombro then 0.15 else 0),
			(if hombro then -0.2 else -0.35) - math.abs(math.cos(balanceo)) * (if andando then 0.15 else 0), 0)
		else Vector3.zero
	humanoide.CameraOffset = humanoide.CameraOffset:Lerp(objetivoVista, math.min(1, dt * 8))
	vistaPropia = llevando or humanoide.CameraOffset.Magnitude > 0.01 -- tras soltarlo, hasta que vuelve a 0
end

-- Sonidos (15.8): golpes y arrastres.
local arrastres: { [BasePart]: Sound } = {}
local function alGolpe(que: string, punto: unknown, fuerza: unknown, tipo: unknown)
	if que ~= "Golpe" or typeof(punto) ~= "Vector3" or type(fuerza) ~= "number" or type(tipo) ~= "string" then
		return
	end
	local datos = PESADOS[tipo]
	local nombre = if datos and datos.Golpe then datos.Golpe else "GolpeMadera"
	if (punto - Camara.get().CFrame.Position).Magnitude > (Config.Sonidos[nombre].Alcance or 100) then
		return
	end
	-- Los golpes se repiten mucho: algo de azar en el tono (CLAUDE.md, sonidos).
	local s = Sonido.en(nombre, punto, 0.9 + math.random() * 0.2 + (1 - fuerza) * 0.1)
	s.Volume *= 0.35 + 0.65 * math.clamp(fuerza, 0, 1)
end

local function mirarArrastre(pieza: Instance)
	if not pieza:IsA("BasePart") then
		return
	end
	local function cambio()
		local arrastra = pieza:GetAttribute("Arrastra") == true and pieza.Parent ~= nil
		local s = arrastres[pieza]
		if arrastra and not s then
			s = Sonido.bucle("Arrastre", pieza)
			s.RollOffMode = Enum.RollOffMode.InverseTapered
			s.RollOffMinDistance = 8
			s.RollOffMaxDistance = Config.Sonidos.Arrastre.Alcance or 50
			arrastres[pieza] = s
		elseif not arrastra and s then
			s:Destroy()
			arrastres[pieza] = nil
		end
	end
	pieza:GetAttributeChangedSignal("Arrastra"):Connect(cambio)
	pieza.Destroying:Connect(function()
		local s = arrastres[pieza]
		if s then
			s:Destroy()
			arrastres[pieza] = nil
		end
	end)
	cambio()
end

function CargarVista.lanzado(): number
	return ultimoLanzado
end

-- De 0 a 1: lo cargado que va el lanzamiento (0 sin cargar).
function CargarVista.carga(): number
	return if cargaDesde then math.clamp((os.clock() - cargaDesde) / C.Lanzar.Carga, 0, 1) else 0
end

function CargarVista.start()
	aviso = Ui.texto("", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -56),
		Size = UDim2.fromOffset(420, 26),
		TextSize = 20,
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	local tactil = Ui.tactil()
	-- La letra solo con teclado: con el dedo hay botón SOLTAR y con el mando, la X de siempre.
	local function pintarAviso()
		aviso.Text = if Ui.conTeclado() then Ui.pista("E", Ui.mayusculas(Lang.t(nil, "Drop"))) else ""
	end
	pintarAviso()
	aviso.Parent = Ui.hud()

	-- Cartel junto a lo que se puede usar, como los de Controles.
	cartel = Instance.new("BillboardGui")
	cartel.Name = "Usar"
	cartel.AlwaysOnTop = true
	local s = math.clamp(Ui.escala(), 0.75, 1) -- fuera del HUD: se encoge a mano en el móvil, como los de Controles
	cartel.Size = UDim2.fromOffset(300 * s, 34 * s)
	cartel.LightInfluence = 0
	cartel.Enabled = false
	textoCartel = Ui.texto("", { Size = UDim2.fromScale(1, 1), TextSize = 22 * s })
	textoCartel.Parent = cartel
	cartel.Parent = Ui.hud().Parent

	if tactil then
		local acciones = Ui.hud():FindFirstChild("Acciones") -- donde sale el botón grande de acción (Controles)
		botonUsar = Ui.boton("", { Size = UDim2.fromOffset(200, 90), Visible = false, LayoutOrder = -3 })
		Ui.queQuepa(botonUsar :: TextButton, 26)
		;(botonUsar :: TextButton).Activated:Connect(usar)
		;(botonUsar :: TextButton).Parent = acciones or Ui.hud()
		-- Lanzar: se mantiene pulsado para coger fuerza y se suelta para lanzar (15.8).
		local bl = Ui.boton(Lang.t(nil, "Throw"), { Size = UDim2.fromOffset(200, 90), Visible = false, LayoutOrder = -2 })
		Ui.queQuepa(bl, 28)
		bl.InputBegan:Connect(function(entrada)
			if entrada.UserInputType == Enum.UserInputType.Touch or entrada.UserInputType == Enum.UserInputType.MouseButton1 then
				empezarLanzar()
			end
		end)
		bl.InputEnded:Connect(function(entrada)
			if entrada.UserInputType == Enum.UserInputType.Touch or entrada.UserInputType == Enum.UserInputType.MouseButton1 then
				lanzar()
			end
		end)
		bl.Parent = acciones or Ui.hud()
		botonLanzar = bl
		boton = Ui.boton(Lang.t(nil, "Drop"), { Size = UDim2.fromOffset(200, 90), Visible = false, LayoutOrder = -1 })
		Ui.queQuepa(boton :: TextButton, 28)
		;(boton :: TextButton).Activated:Connect(soltar)
		;(boton :: TextButton).Parent = acciones or Ui.hud()
	end
	jugador:GetAttributeChangedSignal("Cargando"):Connect(cambiar)
	Ui.alCambiarEntrada(function()
		pintarAviso()
		textoCartel.Text = Ui.pista("R", textoUsar)
	end)
	UserInputService.InputBegan:Connect(function(entrada, procesado)
		if procesado then
			return
		end
		if entrada.KeyCode == Enum.KeyCode.E or entrada.KeyCode == Enum.KeyCode.ButtonX then
			soltar()
		elseif entrada.KeyCode == Enum.KeyCode.R or entrada.KeyCode == Enum.KeyCode.ButtonY then
			usar()
		elseif entrada.UserInputType == Enum.UserInputType.MouseButton1 or entrada.KeyCode == Enum.KeyCode.ButtonR2 then
			empezarLanzar()
		end
	end)
	UserInputService.InputEnded:Connect(function(entrada)
		if entrada.UserInputType == Enum.UserInputType.MouseButton1 or entrada.KeyCode == Enum.KeyCode.ButtonR2 then
			lanzar() -- (aunque la suelte encima de la interfaz: si no, se quedaba cargando)
		end
	end)
	RunService.RenderStepped:Connect(mover)
	Remotes.Pesado.OnClientEvent:Connect(alGolpe)
	CollectionService:GetInstanceAddedSignal("Pesado"):Connect(mirarArrastre)
	for _, p in CollectionService:GetTagged("Pesado") do
		mirarArrastre(p)
	end
end

return CargarVista
