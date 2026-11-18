-- Avisos de una línea con la tecla de la linterna, del flash y de la pistola de bengalas, justo cuando hacen falta
-- (primeros minutos; docs/sistemas/tutorial.md). En el ordenador y con mando nada lo decía.
--   Linterna: al ponerse el sol (Config.Ciclo.Aviso s antes de la noche) o ya de noche, detrás del aviso del sol, si
--     la lleva (pila o pilas de repuesto) y está apagada.
--   Flash: la primera noche en la que ya puede salir el Raspador (Config.Raspador.Noche), si tiene fotos.
--   Pistola: al pasar de no tenerla a tenerla.
-- Cada uno sale como mucho una vez por sesión y solo si aún no ha usado esa cosa. Nunca muerto, escondido, en una
-- cinemática ni con el HUD apagado: espera a que vuelva. Solo el cliente: no decide nada del juego.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ui = require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))
local BengalasVista = require(script.Parent.BengalasVista)

local PistasControles = {}

local yo = Players.LocalPlayer
local P = Config.Tutorial.PistaControles

-- Cómo juega ahora: "Tactil", "Mando" o "Teclado" (como TutorialVista.frase).
local function entrada(): string
	if Ui.tactil() and not UserInputService.KeyboardEnabled then
		return "Tactil"
	elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "Mando"
	end
	return "Teclado"
end

-- Frases enteras (Lang). Los nombres de los botones del móvil son los de EquipoVista y BengalasVista.
local function frase(cual: string): string
	local como = entrada()
	if cual == "Linterna" then
		if como == "Tactil" then
			return Lang.t(nil, "Tap FLASHLIGHT to turn on your flashlight.")
		elseif como == "Mando" then
			return Lang.t(nil, "Press L1 to turn on your flashlight.")
		end
		return Lang.t(nil, "Press F to turn on your flashlight.")
	elseif cual == "Flash" then
		if como == "Tactil" then
			return Lang.t(nil, "Tap FLASH to use the camera flash.")
		elseif como == "Mando" then
			return Lang.t(nil, "Press R2 to use the camera flash.")
		end
		return Lang.t(nil, "Click to use the camera flash.")
	end
	if como == "Tactil" then
		return Lang.t(nil, "Tap FLARE to fire.")
	elseif como == "Mando" then
		return Lang.t(nil, "Press R1 to draw the flare gun, R2 to fire.")
	end
	return Lang.t(nil, "Press Q to draw the flare gun, click to fire.")
end

-- PRUEBA: decidir (tests/bancos/pistas-controles.luau la saca del texto y la prueba con estados de mentira).
-- Qué aviso toca ahora (o nil). `e` son valores sueltos leídos del juego; `s` lo que lleva la sesión
-- (dicho/usado por aviso, `oscuroDesde`: os.clock() en que empezó a oscurecer, `ultimo`: el último aviso, `pistola`:
-- si le acaba de llegar). No toca nada: solo responde.
function PistasControles.decidir(e: { [string]: any }, s: { [string]: any }, p: { [string]: number }): string?
	if not e.libre or e.ahora - s.ultimo < p.Entre then
		return nil
	end
	-- Linterna: detrás del aviso del sol (TrasSol s después de que empiece a oscurecer), para no pisarlo.
	if not s.dicho.Linterna and not s.usado.Linterna and s.oscuroDesde and e.ahora - s.oscuroDesde >= p.TrasSol
		and e.llevaLinterna and not e.encendida then
		return "Linterna"
	end
	if not s.dicho.Flash and not s.usado.Flash and e.fase == "Noche" and e.noche >= e.nocheRaspador and e.fotos > 0 then
		return "Flash"
	end
	if not s.dicho.Pistola and not s.usado.Pistola and s.pistola and e.tienePistola then
		return "Pistola"
	end
	return nil
end
-- FIN PRUEBA

-- Puede leer un aviso: vivo, a la vista, sin cinemática ni HUD apagado.
local function libre(): boolean
	if yo:GetAttribute("Muerto") or yo:GetAttribute("Escondido") or yo:GetAttribute("EscenaFinal") then
		return false
	end
	if not Ui.hud().Enabled then
		return false
	end
	local camara = workspace.CurrentCamera
	return camara ~= nil and camara.CameraType ~= Enum.CameraType.Scriptable and yo.Character ~= nil
end

function PistasControles.start()
	local sesion = {
		dicho = {},
		usado = {},
		oscuroDesde = nil :: number?,
		ultimo = -math.huge,
		pistola = false, -- le acaba de llegar la pistola (de no tenerla a tenerla)
	}
	local tenia = BengalasVista.tienePistola() -- quien ya la tiene al entrar no es "acaba de llegar"

	-- Lo ya usado no se explica.
	if yo:GetAttribute("Linterna") == true then
		sesion.usado.Linterna = true
	end
	yo:GetAttributeChangedSignal("Linterna"):Connect(function()
		if yo:GetAttribute("Linterna") == true then
			sesion.usado.Linterna = true
		end
	end)
	Remotes.Flash.OnClientEvent:Connect(function(quien: Player)
		if quien == yo then
			sesion.usado.Flash = true
		end
	end)
	UserInputService.InputBegan:Connect(function(tecla, procesado)
		if procesado then
			return
		end
		local codigo = tecla.KeyCode
		if codigo == Enum.KeyCode.F or codigo == Enum.KeyCode.ButtonL1 then
			sesion.usado.Linterna = true
		elseif codigo == Enum.KeyCode.Q or codigo == Enum.KeyCode.ButtonR1 then
			sesion.usado.Pistola = true
		end
	end)

	-- Un solo bucle lento, que se acaba cuando ya no queda ningún aviso por dar.
	task.spawn(function()
		while true do
			task.wait(P.Cada)
			local terminado = true
			for _, cual in { "Linterna", "Flash", "Pistola" } do
				if not sesion.dicho[cual] and not sesion.usado[cual] then
					terminado = false
				end
			end
			if terminado then
				break
			end

			local ahora = os.clock()
			local fase = workspace:GetAttribute("Fase")
			local fin = workspace:GetAttribute("FaseFin")
			local oscurece = fase == "Noche"
				or (fase == "Dia" and type(fin) == "number" and fin - workspace:GetServerTimeNow() < Config.Ciclo.Aviso)
			if oscurece then
				sesion.oscuroDesde = sesion.oscuroDesde or ahora
			else
				sesion.oscuroDesde = nil
			end

			local tiene = BengalasVista.tienePistola()
			if tiene and not tenia then
				sesion.pistola = true
			end
			tenia = tiene
			if BengalasVista.enMano() then
				sesion.usado.Pistola = true
			end

			local cual = PistasControles.decidir({
				libre = libre(),
				ahora = ahora,
				fase = fase,
				noche = workspace:GetAttribute("Noche") or 0,
				nocheRaspador = Config.Raspador.Noche,
				fotos = yo:GetAttribute("Fotos") or 0,
				llevaLinterna = (yo:GetAttribute("Pila") or 0) > 0 or (yo:GetAttribute("Pilas") or 0) > 0,
				encendida = yo:GetAttribute("Linterna") == true,
				tienePistola = tiene,
			}, sesion, P)
			if cual then
				sesion.dicho[cual] = true
				sesion.ultimo = ahora
				Ui.aviso(frase(cual), P.Dura)
			end
		end
	end)
end

return PistasControles
