-- Idioma del juego. En el código los textos van en inglés y esta librería los pasa al idioma de quien los va a leer:
-- español (la tabla de shared/LangEs) o inglés (los demás idiomas los traduce Roblox a partir del inglés).
--   Lang.t(jugador, "Night {n}", { n = 3 })  -> "Noche 3" o "Night 3"
-- Frases enteras con huecos {así}, nunca trozos pegados. Un texto nuevo = escribirlo en inglés y añadir su entrada en
-- LangEs con los mismos huecos.
-- Qué idioma: el que el jugador tiene elegido para esta experiencia en el menú de Roblox (su Translator), no el de su
-- cuenta. Lo averigua comun/cliente/Idioma al arrancar (Lang.set) y se lo dice al servidor, que lo apunta en el
-- atributo "Lang" del jugador; hasta entonces vale el de su cuenta. En el cliente siempre es el del jugador local; en
-- el servidor hay que pasar quién va a leer el texto (sin jugador sale en inglés).
local Config = require(script.Parent.Config)

local Lang = {}

Lang.es = require(script.Parent.LangEs)

-- Los servicios se piden con cuidado: las pruebas de Lune cargan este módulo fuera de Roblox.
local enStudio, enCliente = false, false
pcall(function()
	local RunService = game:GetService("RunService")
	enStudio = RunService:IsStudio()
	enCliente = RunService:IsClient()
end)

local codigoLocal: string? = nil

-- "es" o "en" de un código de Roblox ("es-es", "en-us"...).
function Lang.deLocale(locale: unknown): string
	return if type(locale) == "string" and string.sub(string.lower(locale), 1, 2) == "es" then "es" else "en"
end

-- Solo en el cliente: el idioma del jugador local.
function Lang.set(codigo: string)
	codigoLocal = if codigo == "es" then "es" else "en"
end

-- "es" o "en": el idioma en el que hay que escribirle a ese jugador. Config.Test.Lang lo fuerza en Studio.
function Lang.codigo(jugador: Player?): string
	local forzado = Config.Test.Lang
	if enStudio and (forzado == "es" or forzado == "en") then
		return forzado
	end
	if enCliente then
		if not codigoLocal then
			local ok, locale = pcall(function()
				return game:GetService("LocalizationService").RobloxLocaleId
			end)
			codigoLocal = Lang.deLocale(if ok then locale else nil)
		end
		return codigoLocal :: string
	end
	if jugador then
		local ok, dicho = pcall(function()
			return jugador:GetAttribute("Lang")
		end)
		if ok and (dicho == "es" or dicho == "en") then
			return dicho
		end
		local okCuenta, locale = pcall(function()
			return jugador.LocaleId
		end)
		return Lang.deLocale(if okCuenta then locale else nil)
	end
	return "en"
end

local avisados = {}

-- El texto (en inglés) en el idioma de ese jugador, con los huecos {nombre} rellenos con `huecos`.
function Lang.t(jugador: Player?, texto: string, huecos: { [string]: any }?): string
	local resultado = texto
	if Lang.codigo(jugador) == "es" then
		local traducido = Lang.es[texto]
		if traducido then
			resultado = traducido
		elseif enStudio and not avisados[texto] then
			avisados[texto] = true
			warn(`[Lang] Falta en LangEs: "{texto}"`)
		end
	end
	if huecos then
		resultado = string.gsub(resultado, "{(%w+)}", function(clave)
			local valor = huecos[clave]
			return if valor ~= nil then tostring(valor) else nil
		end)
	end
	return resultado
end

return Lang
