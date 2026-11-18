-- Lo común a las Vistas de los bichos (librería sin start()).
-- BichoComun.aturdido(modelo, ahora): si el bicho está aturdido (atributo Aturdido del modelo, que pone Caza.aturdir:
-- hasta cuándo, en la hora del servidor; el flash, el cepo o la linterna al Acechador), cómo va su pose de dolor; nil si
-- no lo está. `ahora`: os.clock(). Lo que devuelve es de este módulo (se reutiliza cada fotograma): solo se lee.
--   peso: 0..1, suave: cuánto manda la pose. Entra en ENTRA s y sale en los últimos SALE s; si le vuelven a aturdir a
--   medio salir, vuelve a entrar desde donde iba, sin saltos.
--   temblor: -1..1 (math.noise y un temblequeo rápido encima); 0 con Rendimiento (la pose, quieta).
--   tiron: -1..1: forcejea a tirones en los aturdimientos largos (el cepo: de FORCEJEA.Largo s o más), uno cada
--   FORCEJEA.Cada s, a un lado y al otro (el signo); 0 en los cortos (el flash) y con Rendimiento.
--   lado: -1 o 1: hacia dónde aparta la cara (al azar en cada aturdimiento).
--   nuevo: true solo en la primera llamada de cada aturdimiento (para el chillido).
-- Lo usan Trepador, Imitador, Raspador y Acechador. La Bestia y el Golpeador tienen lo suyo.
local Players = game:GetService("Players")

local BichoComun = {}

-- Números visuales (a ojo; se retocan en Studio).
local ENTRA = 0.12 -- segundos en encogerse del todo
local SALE = 0.4 -- segundos antes de acabar en los que se va soltando
local TIEMBLA = 13 -- el temblor lento (math.noise), por segundo...
local TIRITA = { Rapido = 47, Parte = 0.35 } -- ...y el temblequeo rápido de encima: radianes por segundo y cuánto pesa
-- Forcejear (el cepo): solo si dura Largo s o más; empieza a Desde s, un tirón cada Cada s que sube en Sube s y se
-- apaga a Baja por segundo; cada tirón con su fuerza (de Floja a 1).
local FORCEJEA = { Largo = 4, Desde = 0.9, Cada = 1.05, Sube = 0.08, Baja = 5, Floja = 0.6 }

export type Aturdido = {
	peso: number,
	temblor: number,
	tiron: number,
	lado: number,
	nuevo: boolean,
	dentro: boolean, -- en un aturdimiento: desde que empieza hasta que acaba de soltarse
	desde: number, -- hora del servidor en que empezó (la primera vez que se vio)...
	hasta: number, -- ...y en que acaba
	lineal: number, -- el peso sin suavizar
	ultima: number, -- hora del servidor de la última llamada
	semilla: number,
}

local jugador = Players.LocalPlayer
local azar = Random.new()
-- Uno por modelo; claves débiles: el de un modelo que ya no está se va solo.
local estados = setmetatable({}, { __mode = "k" }) :: { [Model]: Aturdido }

local function suave(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

function BichoComun.aturdido(modelo: Model, ahora: number): Aturdido?
	local hasta = modelo:GetAttribute("Aturdido")
	local servidor = workspace:GetServerTimeNow()
	local activo = typeof(hasta) == "number" and servidor < hasta
	local a = estados[modelo]
	if not activo and not (a and a.dentro) then
		return nil
	end
	if not a then
		a = { peso = 0, temblor = 0, tiron = 0, lado = 1, nuevo = false, dentro = false, desde = servidor,
			hasta = servidor, lineal = 0, ultima = servidor, semilla = azar:NextNumber(0, 100) }
		estados[modelo] = a
	end
	a.nuevo = false
	if activo then
		if not a.dentro then
			a.dentro, a.nuevo = true, true
			a.desde, a.ultima, a.lineal = servidor, servidor, 0
			a.lado = if azar:NextNumber() < 0.5 then -1 else 1
		end
		a.hasta = hasta :: number
	end
	-- Entra a 1/ENTRA por segundo (con tope: lejos no se mira cada fotograma) y nunca pasa de lo que le queda.
	local queda = if activo then math.clamp((a.hasta - servidor) / SALE, 0, 1) else 0
	a.lineal = math.min(a.lineal + math.clamp(servidor - a.ultima, 0, 1) / ENTRA, queda)
	a.ultima = servidor
	if a.lineal <= 0 and not activo then
		a.dentro = false
		return nil
	end
	a.peso = suave(a.lineal)

	if jugador:GetAttribute("Rendimiento") == true then
		a.temblor, a.tiron = 0, 0
		return a
	end
	a.temblor = math.clamp(math.noise(ahora * TIEMBLA, a.semilla) * 1.6
		+ TIRITA.Parte * math.sin(ahora * TIRITA.Rapido + a.semilla), -1, 1)
	local t = servidor - a.desde - FORCEJEA.Desde
	a.tiron = 0
	if a.hasta - a.desde >= FORCEJEA.Largo and t > 0 then
		local n = math.floor(t / FORCEJEA.Cada)
		local u = t - n * FORCEJEA.Cada
		local golpe = if u < FORCEJEA.Sube then suave(u / FORCEJEA.Sube) else math.exp(-(u - FORCEJEA.Sube) * FORCEJEA.Baja)
		local fuerza = FORCEJEA.Floja + (1 - FORCEJEA.Floja) * math.clamp(math.noise(n + 0.5, a.semilla) * 2 + 0.5, 0, 1)
		a.tiron = (if n % 2 == 0 then 1 else -1) * golpe * fuerza
	end
	return a
end

return BichoComun
