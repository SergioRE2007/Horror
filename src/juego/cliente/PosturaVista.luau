-- Agacharse y asomarse (14.6, pedido por el usuario: "cuerpo: agacharse (botón también en el móvil) y asomarse por las
-- esquinas"). Solo cuerpo y cámara: los bichos no lo notan.
--   Agacharse: C o Ctrl izquierdo (alterna), B en el mando y el botón AGACHARSE en el móvil (Hud.EquipoBotones,
--   LayoutOrder 6), que se enciende mientras estás agachado. Saltar levanta (y subir por una escalera o sentarse).
--   Asomarse: mantener Z (izquierda) o X (derecha), solo con teclado. Con la mochila abierta, no. Mirando por la
--   mirilla o entre las cortinas (atributo local Vistazo, de MirarVista) se queda como estaba hasta acabar: si cambiara,
--   MirarVista cortaría el vistazo. En una cinemática no se empieza ni lo uno ni lo otro.
--   Respuesta al momento: se predice con las mismas reglas que el servidor (shared/PosturaReglas) y se le manda (remote
--   Postura). Si el servidor no lo publica (lo ha tirado por llegar muy seguido) se le vuelve a mandar; si no lo
--   quiere, o lo quita él (atributos Agachado y Asomado a nil), te pones de pie.
--   CuerpoVista mueve tu cámara con PosturaVista.agachado() y PosturaVista.asomado(); a los demás los pinta BrazosVista.
--   Al agacharte, al levantarte y al empezar a asomarte, un roce flojo de los pies en el suelo (el sonido de los pasos
--   de ese suelo), solo para ti.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Lang = require(ReplicatedStorage.Shared.Lang)
local PosturaReglas = require(ReplicatedStorage.Shared.PosturaReglas)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Sonido = require(script.Parent.Sonido)
local Ui = require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))

local PosturaVista = {}

local ESPERA = 0.45 -- s que se espera a que el servidor lo publique antes de mandarlo otra vez
local INTENTOS = 3 -- veces que se pide agacharse o asomarse antes de dejarlo (ponerse de pie se pide hasta que llegue)
local RECIENTE = 0.9 -- s tras mandar algo en los que un cambio del servidor puede ser el eco de lo que pediste antes
local RUIDO = 0.45 -- volumen (sobre el de los pasos) del roce de los pies al agacharte o levantarte
local RUIDO_ASOMAR = 0.25 -- y al empezar a asomarte (el peso pasa a un pie)
local SUELO: { [Enum.Material]: string } = { -- como en Pasos
	[Enum.Material.Wood] = "PasoMadera",
	[Enum.Material.WoodPlanks] = "PasoMadera",
	[Enum.Material.Grass] = "PasoHierba",
	[Enum.Material.LeafyGrass] = "PasoHierba",
}
local QUE = { "Agachado", "Asomar" }

type Valor = boolean | number
type Pendiente = { valor: Valor, hora: number, intentos: number }

local jugador = Players.LocalPlayer
local estado = PosturaReglas.nuevo() -- lo que ya se ve (la predicción)
local quiereAgachado = false -- lo que ha pedido con C (alterna)
local izquierda, derecha, ultima = false, false, 0 -- Z y X apretadas; la última que se apretó (-1 o 1)
local pendiente: { [string]: Pendiente } = {} -- lo mandado que el servidor aún no ha publicado
-- Cuándo cambió por última vez cada atributo del servidor: lo mandado solo se da por puesto con un cambio que llega
-- después de mandarlo (con dos toques seguidos, el valor viejo del servidor puede ser igual al nuevo y no vale).
local cambioEn: { [string]: number } = { Agachado = -math.huge, Asomar = -math.huge }
local mandadoEn: { [string]: number } = { Agachado = -math.huge, Asomar = -math.huge }
local rendido: { [string]: Valor } = {} -- lo que el servidor no ha querido: no se pide más hasta que cambie lo que quieres
local boton: TextButton? = nil
local encendido: boolean? = nil -- cómo está pintado el botón
local apagado: boolean? = nil -- si se pinta como que ahora no se puede

-- Lo que se ve ahora (para CuerpoVista).
function PosturaVista.agachado(): boolean
	return estado.agachado
end

-- -1 izquierda, 0 o 1 derecha.
function PosturaVista.asomado(): number
	return estado.asomado
end

local function humanoide(): Humanoid?
	local personaje = jugador.Character
	return personaje and personaje:FindFirstChildOfClass("Humanoid")
end

local function datos(): PosturaReglas.Jugador
	local hum = humanoide()
	return {
		vivo = hum ~= nil and hum.Health > 0 and not jugador:GetAttribute("Muerto"),
		escondido = jugador:GetAttribute("Escondido") ~= nil,
		cargando = jugador:GetAttribute("Cargando") ~= nil or jugador:GetAttribute("Trabajando") ~= nil,
		mochila = jugador:GetAttribute("MochilaAbierta") == true,
	}
end

local function neutro(que: string): Valor
	return if que == "Agachado" then false else 0
end

-- ¿Una cinemática? (la cámara la lleva un script). Ahí no se empieza a agachar ni a asomar; levantarse y dejar de
-- asomarse, sí. Mirando por la mirilla o entre las cortinas (atributo local Vistazo, de MirarVista) no cuenta: ahí
-- agacharse corta el vistazo (MirarVista sale si cambia Agachado o Asomado), y asomarse se queda como estaba hasta
-- acabar (soltar Z o X a medias no debe cortarlo).
local function enCine(): boolean
	local camara = workspace.CurrentCamera
	return camara ~= nil and camara.CameraType == Enum.CameraType.Scriptable and jugador:GetAttribute("Vistazo") == nil
end

local function mio(que: string): Valor
	return if que == "Agachado" then estado.agachado else estado.asomado
end

local function quiere(que: string): Valor
	if que == "Agachado" then
		return quiereAgachado
	elseif izquierda and derecha then
		return ultima
	end
	return if izquierda then -1 elseif derecha then 1 else 0
end

local function delServidor(que: string): Valor
	if que == "Agachado" then
		return jugador:GetAttribute("Agachado") == true
	end
	local a = jugador:GetAttribute("Asomado")
	return if a == -1 or a == 1 then a else 0
end

-- Cambia lo que se ve sin pedirlo (no cuenta para Config.Postura.Cada).
local function poner(que: string, valor: Valor)
	local nuevo = table.clone(estado)
	if que == "Agachado" then
		nuevo.agachado = valor == true
	else
		nuevo.asomado = valor :: number
	end
	estado = nuevo
end

local function mandar(que: string, valor: Valor, intentos: number)
	pendiente[que] = { valor = valor, hora = os.clock(), intentos = intentos }
	mandadoEn[que] = os.clock()
	Remotes.Postura:FireServer(que, valor)
end

-- No va a ser (el servidor no quiere o lo ha quitado él): derecho y de pie, y no se vuelve a pedir hasta que sueltes la
-- tecla o pulses otra vez.
local function dejar(que: string)
	pendiente[que] = nil
	rendido[que] = quiere(que)
	if que == "Agachado" then
		quiereAgachado = false
	end
	poner(que, neutro(que))
	if delServidor(que) ~= neutro(que) then
		mandar(que, neutro(que), 1)
	end
end

-- El roce de los pies en el suelo al agacharte, al levantarte y al empezar a asomarte (solo lo oyes tú).
local function sonar(tono: number, volumen: number)
	local hum = humanoide()
	local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not raiz or hum.FloorMaterial == Enum.Material.Air then
		return
	end
	local s = Sonido.en(SUELO[hum.FloorMaterial] or "PasoTierra", raiz.Position - Vector3.new(0, 2.5, 0), tono)
	s.Volume *= volumen
end

-- El botón del móvil: encendido (borde claro sobre rojo oscuro) mientras estás agachado; apagado si ahora no se puede.
local function pintarBoton(libre: boolean)
	local b = boton
	if not b then
		return
	end
	if apagado ~= not libre then
		apagado = not libre
		b.TextTransparency = if libre then 0 else 0.55
	end
	if encendido == estado.agachado then
		return
	end
	encendido = estado.agachado
	local info = TweenInfo.new(0.15)
	TweenService:Create(b, info, { BackgroundColor3 = if estado.agachado then Ui.Color.Sangre else Ui.Color.Papel }):Play()
	local borde = b:FindFirstChildOfClass("UIStroke")
	if borde then
		TweenService:Create(borde, info, {
			Color = if estado.agachado then Ui.Color.Hueso else Ui.Color.Sangre,
			Thickness = if estado.agachado then 3 else 2,
		}):Play()
	end
end

-- Pone lo que se ve de acuerdo con lo que quieres y con el servidor. Cada fotograma y al pulsar (respuesta al momento).
local function sincronizar()
	local ahora = os.clock()
	local d = datos()
	local libre = PosturaReglas.puede(d)
	local mirando = jugador:GetAttribute("Vistazo") ~= nil -- por la mirilla o entre las cortinas: asomarse, quieto
	-- Lo que ya no puede ser se quita aquí al momento, sin pedirlo: el servidor también lo quita él solo.
	local quita, limpio = PosturaReglas.limpiar(estado, d)
	if quita then
		estado = limpio
	end
	if not libre then
		-- Muerto, escondido o cargando: de pie y sin pedir nada (no lo aceptaría). Al volver, de pie.
		quiereAgachado = false
		table.clear(pendiente)
		pintarBoton(false)
		return
	end
	for _, que in QUE do
		-- Con el servidor: lo mandado que ya ha publicado, lo que no llega y lo que cambia él.
		local servidor = delServidor(que)
		local p = pendiente[que]
		if p then
			if servidor == p.valor and (cambioEn[que] > p.hora or ahora - p.hora >= ESPERA) then
				pendiente[que] = nil -- lo ha puesto (o ya lo tenía y no ha cambiado en todo este rato)
			elseif ahora - p.hora >= ESPERA then
				if p.valor == neutro(que) or p.intentos < INTENTOS then
					mandar(que, p.valor, p.intentos + 1) -- se perdió o llegó muy seguido: otra vez
				else
					dejar(que)
				end
			end
		elseif servidor ~= mio(que) then
			-- El servidor solo la quita por lo que aquí ya se ve (morir, esconderse, cargar, la mochila, reaparecer). Si
			-- llega sin haber pedido nada, la ha quitado él: de pie. Justo después de pedir algo es el eco de una
			-- petición de antes (varios toques seguidos con la red lenta): se le manda lo que se ve.
			if servidor == neutro(que) and ahora - mandadoEn[que] >= RECIENTE then
				dejar(que)
			else
				mandar(que, mio(que), 1)
			end
		end
		-- Lo que quieres: se pide en cuanto se pueda (las mismas reglas que el servidor, también cada cuánto).
		local q = quiere(que)
		if rendido[que] ~= nil and rendido[que] ~= q then
			rendido[que] = nil
		end
		local quieto = que == "Asomar" and mirando
		if q ~= mio(que) and rendido[que] == nil and not quieto and (q == neutro(que) or not enCine()) then
			local antes = mio(que)
			local cambia, nuevo = PosturaReglas.pedir(estado, que, q, ahora, d)
			if cambia then
				estado = nuevo
				mandar(que, q, 1)
				if que == "Agachado" then
					sonar(if q == true then 0.85 else 0.95, RUIDO)
				elseif antes == 0 then
					sonar(1.05, RUIDO_ASOMAR)
				end
			elseif que == "Agachado" and not PosturaReglas.permitido(que, q, d) then
				quiereAgachado = estado.agachado -- ahora no se puede: se olvida (asomarse sí espera: es mantener)
			end
		end
	end
	pintarBoton(true)
end

-- ¿Sentado o subiendo por una escalera? Ahí no se agacha.
local function ocupado(hum: Humanoid?): boolean
	return hum ~= nil and (hum.Sit or hum:GetState() == Enum.HumanoidStateType.Climbing)
end

local function alternar()
	if not quiereAgachado and (ocupado(humanoide()) or enCine()) then
		return
	end
	quiereAgachado = not quiereAgachado
	sincronizar()
end

local function levantar()
	if quiereAgachado or estado.agachado then
		quiereAgachado = false
		sincronizar()
	end
end

local function conPersonaje(personaje: Model)
	-- Personaje nuevo: de pie (el servidor también lo quita al reaparecer).
	estado = PosturaReglas.quitar(estado)
	quiereAgachado = false
	table.clear(pendiente)
	table.clear(rendido)
	local hum = personaje:WaitForChild("Humanoid", 10)
	if hum and hum:IsA("Humanoid") then
		hum.StateChanged:Connect(function(_, nuevo)
			if nuevo == Enum.HumanoidStateType.Climbing or nuevo == Enum.HumanoidStateType.Seated then
				levantar()
			end
		end)
	end
end

function PosturaVista.start()
	-- Móvil: botón AGACHARSE en la rejilla del equipo (EquipoVista: el tamaño lo pone ella; orden 6).
	if Ui.tactil() then
		local fila = Ui.hud():FindFirstChild("EquipoBotones")
		if fila then
			local b = Ui.boton(Lang.t(nil, "Crouch"), { LayoutOrder = 6, Name = "Agacharse" })
			Ui.queQuepa(b, 22)
			b.Activated:Connect(alternar)
			b.Parent = fila
			boton = b
		end
	end
	UserInputService.InputBegan:Connect(function(entrada, procesado)
		if procesado then
			return
		end
		local tecla = entrada.KeyCode
		if tecla == Enum.KeyCode.C or tecla == Enum.KeyCode.LeftControl
			or (tecla == Enum.KeyCode.ButtonB and not jugador:GetAttribute("MochilaAbierta")) then -- B cierra la mochila
			alternar()
		elseif tecla == Enum.KeyCode.Z then
			izquierda, ultima = true, -1
			sincronizar()
		elseif tecla == Enum.KeyCode.X then
			derecha, ultima = true, 1
			sincronizar()
		end
	end)
	-- Al soltar, aunque estuvieras escribiendo: que no se quede asomado.
	UserInputService.InputEnded:Connect(function(entrada)
		if entrada.KeyCode == Enum.KeyCode.Z then
			izquierda = false
			sincronizar()
		elseif entrada.KeyCode == Enum.KeyCode.X then
			derecha = false
			sincronizar()
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		izquierda, derecha = false, false
		sincronizar()
	end)
	UserInputService.JumpRequest:Connect(levantar) -- saltar levanta (teclado, mando y el botón de saltar del móvil)
	for que, atributo in { Agachado = "Agachado", Asomar = "Asomado" } do
		jugador:GetAttributeChangedSignal(atributo):Connect(function()
			cambioEn[que] = os.clock()
		end)
	end
	jugador.CharacterAdded:Connect(conPersonaje)
	if jugador.Character then
		task.spawn(conPersonaje, jugador.Character)
	end
	RunService.Heartbeat:Connect(sincronizar)
end

return PosturaVista
