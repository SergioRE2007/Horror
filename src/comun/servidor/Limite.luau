-- Límite de ritmo común para los remotes (16.16): un cliente con trampas puede mandar cientos de peticiones por segundo
-- y cada una cuesta CPU y red del servidor (listas de vivos, avisos, atributos). Cada remote llama a
-- Limite.pasa(jugador, "Clave", segundos) al principio (o justo antes de lo que cuesta) y se tira lo que llega antes.
-- Los intervalos están en Config.Limites. Cuenta desde la última petición que pasó: lo que se tira no alarga la espera.
-- Para que cuenten también los intentos fallidos (que los avisos no se pidan en ráfaga), se llama antes de mirar si
-- se puede; para que solo cuente lo que de verdad se hace, después de las demás comprobaciones.
-- Sin nada de Roblox salvo en start(): se prueba en Lune con un reloj falso (tests/bancos/limite.luau).
local Limite = {}

-- Segundos de ahora. Los tests lo cambian por un reloj falso.
Limite.reloj = os.clock

-- clave -> jugador -> cuándo pasó la última. Claves débiles: aunque se olvidara limpiar, no se acumula nada.
local ultimos: { [string]: { [any]: number } } = {}

local function tablaDe(clave: string): { [any]: number }
	local t = ultimos[clave]
	if not t then
		t = setmetatable({}, { __mode = "k" }) :: any
		ultimos[clave] = t
	end
	return t
end

-- Segundos que faltan para que pase la siguiente petición (0 o menos = ya puede). No apunta nada.
function Limite.restante(jugador: any, clave: string, segundos: number): number
	local ultimo = tablaDe(clave)[jugador]
	if ultimo == nil then
		return 0
	end
	return segundos - (Limite.reloj() - ultimo)
end

-- true si ya pasó `segundos` desde la última que pasó (y apunta esta); false = tirarla sin más.
function Limite.pasa(jugador: any, clave: string, segundos: number): boolean
	local t = tablaDe(clave)
	local ahora = Limite.reloj()
	local ultimo = t[jugador]
	if ultimo ~= nil and ahora - ultimo < segundos then
		return false
	end
	t[jugador] = ahora
	return true
end

-- Borra lo de un jugador (al salir).
function Limite.olvidar(jugador: any)
	for _, t in ultimos do
		t[jugador] = nil
	end
end

-- Para los tests: quita todo lo apuntado.
function Limite.vaciar()
	table.clear(ultimos)
end

function Limite.start()
	game:GetService("Players").PlayerRemoving:Connect(Limite.olvidar)
end

return Limite
