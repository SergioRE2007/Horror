-- Idioma del jugador: el que tiene elegido para esta experiencia en el menú de Roblox (Ajustes → Idioma), no el de su
-- cuenta. Roblox lo da en el Translator del jugador (su LocaleId), que además avisa cuando cambia.
-- Va lo primero en el arranque del cliente: espera un momento a saberlo, para que ningún módulo escriba un texto en
-- el idioma que no es, y se lo dice al servidor (remote Idioma) para sus avisos.
-- En español el juego pone sus propios textos (shared/LangEs): ahí se apaga la traducción automática de Roblox
-- (AutoLocalize) en la interfaz, para que no intente traducirlos como si fueran inglés.
-- En Studio, el atributo "LangTest" del jugador local ("es" o "en") hace lo mismo que cambiarlo en el menú de Roblox.
local LocalizationService = game:GetService("LocalizationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Idioma = {}

local ESPERA = 3 -- segundos como mucho esperando a Roblox al arrancar; después vale el idioma de la cuenta

local jugador = Players.LocalPlayer

local function autoLocalize()
	local activo = Lang.codigo() ~= "es"
	local gui = jugador:FindFirstChildOfClass("PlayerGui")
	if gui then
		for _, capa in gui:GetChildren() do
			if capa:IsA("LayerCollector") then
				capa.AutoLocalize = activo
			end
		end
	end
end

local function cambiar(codigo: string)
	if codigo == Lang.codigo() then
		return
	end
	Lang.set(codigo)
	Remotes.Idioma:FireServer(codigo)
	autoLocalize()
end

function Idioma.start()
	local hecho = false
	task.spawn(function()
		local ok, traductor = pcall(function()
			return LocalizationService:GetTranslatorForPlayerAsync(jugador)
		end)
		if ok and traductor then
			local codigo = Lang.deLocale(traductor.LocaleId)
			Lang.set(codigo)
			Remotes.Idioma:FireServer(codigo)
			traductor:GetPropertyChangedSignal("LocaleId"):Connect(function()
				cambiar(Lang.deLocale(traductor.LocaleId))
			end)
		else
			-- Sin traductor (lugar sin publicar o fallo de Roblox): vale el idioma de la cuenta.
			Remotes.Idioma:FireServer(Lang.codigo())
		end
		hecho = true
	end)
	local esperado = 0
	while not hecho and esperado < ESPERA do
		esperado += task.wait()
	end

	local gui = jugador:WaitForChild("PlayerGui")
	gui.ChildAdded:Connect(function(capa)
		if capa:IsA("LayerCollector") and Lang.codigo() == "es" then
			capa.AutoLocalize = false
		end
	end)
	autoLocalize()
	if RunService:IsStudio() then
		jugador:GetAttributeChangedSignal("LangTest"):Connect(function()
			local codigo = jugador:GetAttribute("LangTest")
			if codigo == "es" or codigo == "en" then
				cambiar(codigo)
			end
		end)
	end
end

return Idioma
