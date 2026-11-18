-- Leer una pista (servidor: Pistas). Sale en el centro un papel oscuro con la esquina manchada de sangre: arriba, en
-- rojo, lo que es ("Nota del rico"); debajo lo que pone; abajo, cuántas llevamos ("3 de 12", pequeño) y CERRAR.
-- Se cierra con CERRAR, volviendo a pulsar E en la misma pista, al alejarse o al morir. Solo enseña: el servidor no
-- espera nada de vuelta. Al abrirla suena el papel que se despliega (Papel).
-- Libreta (PistasUi.libreta, botón NOTAS de la mochila): las leídas por cualquiera (atributo de workspace
-- PistasLeidas) en el mismo papel, empezando por la última encontrada, con < y > (flechas del teclado, LB y RB del
-- mando) y "2 de 5". No se cierra al alejarse ni suena al pasar de hoja; se cierra con CERRAR, B (MochilaUi se lo
-- pasa), Escape, el botón B del mando o al morir. Leer así no le dice nada al servidor.
-- Los avisos de las pistas (Remotes.Pista "Aviso") salen como los demás, pero fuera del papel si está abierto.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Historia = require(ReplicatedStorage.Shared.Historia)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sonido = require(script.Parent.Sonido)
local Ui = require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))

local PistasUi = {}

local ALCANCE = 11 -- studs: más lejos de la pista, se cierra
-- Medidas del papel en píxeles de diseño (el alto sale del texto). En el móvil, más grande y con letra mayor (el HUD
-- se encoge a la mitad) y CERRAR, < y > del alto de un dedo.
local TACTIL = Ui.tactil()
local ANCHO = if TACTIL then 720 else 560
local LETRA = if TACTIL then 28 else 24
local CERRAR = Ui.alto(40)
local FLECHA = math.max(56, CERRAR) -- ancho de < y > (en el móvil, cuadrados de un dedo)
local CUENTA = if TACTIL then 120 else 100 -- ancho de "2 de 5" entre las flechas
local ABAJO = CERRAR + 36 -- lo que queda bajo el texto: la cuenta y CERRAR
local ROJO = Color3.fromRGB(150, 34, 28) -- más claro que Ui.Color.Sangre: sobre el papel oscuro tiene que leerse
local BARRA = 64 -- píxeles de verdad de arriba que tapan los botones de Roblox (un aviso no va ahí)

local jugador = Players.LocalPlayer
local panel: TextButton
local que: TextLabel
local texto: TextLabel
local cuenta: TextLabel
local anterior: TextButton
local siguiente: TextButton
local escala: UIScale
local abierta = 0 -- la pista que se está leyendo (0 = ninguna)
local vez = 0 -- sube cada vez que se abre o se cierra: el bucle viejo de cerrar se para
local enLibreta = false -- abierta desde la mochila (no se cierra al alejarse)
local hojas: { number } = {} -- las de la libreta, en orden
local hoja = 1 -- la que se ve de `hojas`
local ultima = 0 -- la última encontrada que se sabe (la libreta empieza por ella)
local sabidas: { [number]: boolean } = {} -- las de PistasLeidas la última vez que se miró (para saber cuál es nueva)

local function cerrar()
	vez += 1
	abierta = 0
	enLibreta = false
	panel.Visible = false
	panel.Modal = false
end

-- Las leídas por cualquiera en esta partida (lo publica el servidor: "1,2,9"), en orden y solo las que existen.
local function leidas(): { number }
	local lista = {}
	local valor = workspace:GetAttribute("PistasLeidas")
	if type(valor) == "string" then
		for trozo in string.gmatch(valor, "%d+") do
			local n = tonumber(trozo)
			if n and Historia[n] and not table.find(lista, n) then
				table.insert(lista, n)
			end
		end
	end
	table.sort(lista)
	return lista
end

-- La pieza de la pista n en el mundo (para saber si me he alejado).
local function dondeEsta(n: number): BasePart?
	for _, modelo in CollectionService:GetTagged("Pista") do
		if modelo:GetAttribute("N") == n and modelo:IsA("Model") then
			return modelo.PrimaryPart
		end
	end
	return nil
end

local function cerca(n: number): boolean
	local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local donde = dondeEsta(n)
	if not raiz or jugador:GetAttribute("Muerto") then
		return false
	end
	return donde == nil or (donde.Position - raiz.Position).Magnitude <= ALCANCE -- sin la pieza (streaming): no se cierra por eso
end

-- Lo alto del papel para el texto de la pista n (las cortas no dejan medio papel vacío).
local function altoPara(n: number): number
	local escrito = Lang.t(nil, Historia[n].texto)
	local alto = TextService:GetTextSize(escrito, LETRA, Enum.Font.SpecialElite, Vector2.new(ANCHO - 64, 1000)).Y
	local maximo = Ui.lienzo().Y - 40 -- que no se salga de la pantalla
	return math.clamp(math.ceil(alto * texto.LineHeight) + 74 + ABAJO, 200, math.max(200, maximo))
end

-- Lo de abajo: leyendo una pista, la cuenta pequeña a la izquierda; en la libreta, entre < y >.
local function ponerAbajo(libreta: boolean)
	local flechas = libreta and #hojas > 1
	anterior.Visible = flechas
	siguiente.Visible = flechas
	if flechas then
		cuenta.Position = UDim2.new(0, 18 + FLECHA, 1, -16)
		cuenta.Size = UDim2.fromOffset(CUENTA, CERRAR)
		cuenta.TextXAlignment = Enum.TextXAlignment.Center
	else
		cuenta.Position = UDim2.new(0, 32, 1, -22)
		cuenta.Size = UDim2.fromOffset(160, 28)
		cuenta.TextXAlignment = Enum.TextXAlignment.Left
	end
end

-- Pone en el papel la pista n.
local function escribir(n: number)
	local pista = Historia[n]
	abierta = n
	que.Text = Ui.mayusculas(Lang.t(nil, pista.que))
	texto.Text = Lang.t(nil, pista.texto)
end

-- Sale el papel (si no estaba ya) y vigila cuándo cerrarlo: leyendo una pista, al alejarse o morir; en la libreta, al
-- morir o al empezar la escena de un final.
local function mostrar()
	vez += 1
	local mia = vez
	if not panel.Visible then
		Sonido.tocar("Papel") -- de una pista a otra sin cerrar, el papel ya estaba en la mano
	end
	escala.Scale = 0.92
	TweenService:Create(escala, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	panel.Visible = true
	panel.Modal = true -- suelta el ratón en primera persona
	task.spawn(function()
		while vez == mia do
			task.wait(0.25)
			if vez ~= mia then
				break
			end
			local fuera = if enLibreta
				then jugador:GetAttribute("Muerto") or jugador:GetAttribute("EscenaFinal")
				else not cerca(abierta)
			if fuera then
				cerrar()
			end
		end
	end)
end

local function abrir(n: number, encontradas: number)
	if not Historia[n] then
		return
	end
	ultima = n
	if panel.Visible and abierta == n and not enLibreta then
		cerrar() -- E otra vez en la misma: se guarda el papel
		return
	end
	enLibreta = false
	escribir(n)
	panel.Size = UDim2.fromOffset(ANCHO, altoPara(n))
	cuenta.Text = Lang.t(nil, "{n} of {total}", { n = encontradas, total = #Historia })
	ponerAbajo(false)
	mostrar()
end

-- La hoja i de la libreta (da la vuelta: de la última, > lleva a la primera). Pasar de hoja no suena.
local function verHoja(i: number)
	if #hojas == 0 then
		return
	end
	hoja = (i - 1) % #hojas + 1
	escribir(hojas[hoja])
	cuenta.Text = Lang.t(nil, "{n} of {total}", { n = hoja, total = #hojas })
	if escala.Scale >= 1 then
		escala.Scale = 0.98 -- un golpe pequeño, que se note que ha cambiado la hoja
		TweenService:Create(escala, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = 1 }):Play()
	end
end

local function pasar(paso: number)
	if enLibreta and panel.Visible and #hojas > 1 then
		verHoja(hoja + paso)
	end
end

-- Rehace la libreta con las leídas de ahora y enseña la pista n (o la última de la lista). Del alto de la más larga,
-- para que < y > no se muevan bajo el dedo al pasar de hoja.
local function rehacer(n: number): boolean
	hojas = leidas()
	if #hojas == 0 then
		return false
	end
	local alto = 200
	for _, m in hojas do
		alto = math.max(alto, altoPara(m))
	end
	panel.Size = UDim2.fromOffset(ANCHO, alto)
	ponerAbajo(true)
	verHoja(table.find(hojas, n) or #hojas)
	return true
end

-- La libreta: las leídas por cualquiera, empezando por la última encontrada.
function PistasUi.libreta()
	if not panel or jugador:GetAttribute("Muerto") or jugador:GetAttribute("EscenaFinal") then
		return
	end
	if rehacer(ultima) then
		enLibreta = true
		mostrar()
	end
end

-- ¿Está abierta la libreta? (MochilaUi: la B la cierra en vez de abrir la mochila.)
function PistasUi.libretaAbierta(): boolean
	return enLibreta and panel ~= nil and panel.Visible
end

function PistasUi.cerrar()
	if panel and panel.Visible then
		cerrar()
	end
end

-- Un aviso de las pistas: el de siempre (abajo en el centro), pero si el papel está abierto y lo taparía, encima del
-- papel o, si no cabe, debajo.
local function avisar(frase: string)
	local t = Ui.aviso(frase, 4.5)
	if not panel.Visible then
		return
	end
	local pantalla = Ui.hud().AbsoluteSize.Y
	local alto = t.AbsoluteSize.Y
	local arriba = panel.AbsolutePosition.Y
	local abajo = arriba + panel.AbsoluteSize.Y
	local base = t.AbsolutePosition.Y + alto
	if pantalla <= 0 or base - alto >= abajo or base <= arriba then
		return -- no lo tapa
	end
	if arriba - 8 - alto >= BARRA then
		t.Position = UDim2.fromScale(0.5, (arriba - 8) / pantalla)
	elseif abajo + 8 + alto <= pantalla then
		t.Position = UDim2.fromScale(0.5, (abajo + 8 + alto) / pantalla)
	end
end

local function flecha(signo: string, paso: number, x: number): TextButton
	local b = Ui.boton(signo, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, x, 1, -16),
		Size = UDim2.fromOffset(FLECHA, CERRAR),
		TextSize = 26,
		Visible = false,
		ZIndex = 21,
	})
	b.Activated:Connect(function()
		pasar(paso)
	end)
	b.Parent = panel
	return b
end

local function construir()
	panel = Instance.new("TextButton")
	panel.Name = "Pista"
	panel.Text = ""
	panel.AutoButtonColor = false
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.46)
	panel.Size = UDim2.fromOffset(ANCHO, 300)
	panel.BackgroundColor3 = Ui.Color.Papel
	panel.BackgroundTransparency = 0.05
	panel.ClipsDescendants = true
	panel.Visible = false
	panel.ZIndex = 20
	escala = Instance.new("UIScale")
	escala.Parent = panel
	local borde = Instance.new("UIStroke")
	borde.Color = Ui.Color.Hueso
	borde.Transparency = 0.75
	borde.Parent = panel
	Ui.mancha(panel).ZIndex = 20

	que = Ui.texto("", {
		Position = UDim2.fromOffset(32, 22),
		Size = UDim2.new(1, -64, 0, 26),
		TextSize = 19,
		TextColor3 = ROJO,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 21,
	})
	que.Parent = panel
	texto = Ui.texto("", {
		Position = UDim2.fromOffset(32, 60),
		Size = UDim2.new(1, -64, 1, -60 - ABAJO),
		TextSize = LETRA,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		LineHeight = 1.15,
		ZIndex = 21,
	})
	texto.Parent = panel
	cuenta = Ui.texto("", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 32, 1, -22),
		Size = UDim2.fromOffset(160, 28),
		TextSize = 17,
		TextTransparency = 0.5,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 21,
	})
	cuenta.Parent = panel
	anterior = flecha("<", -1, 18)
	siguiente = flecha(">", 1, 18 + FLECHA + CUENTA)
	local salir = Ui.boton(Lang.t(nil, "Close"), {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, -16),
		Size = UDim2.fromOffset(150, CERRAR),
		TextSize = 20,
		ZIndex = 21,
	})
	salir.Activated:Connect(cerrar)
	salir.Parent = panel
	panel.Parent = Ui.hud()
end

-- Cambia PistasLeidas: la que no estaba es la última encontrada (la mía o la de otro). Al cargar no se sabe cuál fue:
-- todas son nuevas y la libreta empieza por la más alta.
local function alCambiarLeidas()
	local nuevas = leidas()
	local antes = sabidas
	sabidas = {}
	for _, n in nuevas do
		sabidas[n] = true
		if not antes[n] then
			ultima = n
		end
	end
	if not table.find(nuevas, ultima) then
		ultima = nuevas[#nuevas] or 0
	end
	if PistasUi.libretaAbierta() then
		rehacer(abierta) -- otro ha encontrado una mientras la miro: entra en la lista y sigo en la misma hoja
	end
end

function PistasUi.start()
	construir()
	Remotes.Pista.OnClientEvent:Connect(function(n, encontradas)
		if type(n) == "number" and type(encontradas) == "number" then
			abrir(n, encontradas)
		elseif n == "Aviso" and type(encontradas) == "string" then
			avisar(encontradas)
		end
	end)
	workspace:GetAttributeChangedSignal("PistasLeidas"):Connect(alCambiarLeidas)
	alCambiarLeidas()
	UserInputService.InputBegan:Connect(function(entrada, procesado)
		if not PistasUi.libretaAbierta() then
			return
		end
		local tecla = entrada.KeyCode
		if tecla == Enum.KeyCode.Escape or tecla == Enum.KeyCode.ButtonB then
			-- Escape también abre el menú de Roblox (llega procesada): se cierra igual. Al acabar este evento: así los
			-- demás que miran la misma tecla (agacharse con B del mando) aún ven la libreta abierta y no hacen nada.
			task.defer(cerrar)
		elseif procesado then
			return
		elseif tecla == Enum.KeyCode.Left or tecla == Enum.KeyCode.ButtonL1 then
			pasar(-1)
		elseif tecla == Enum.KeyCode.Right or tecla == Enum.KeyCode.ButtonR1 then
			pasar(1)
		end
	end)
end

return PistasUi
