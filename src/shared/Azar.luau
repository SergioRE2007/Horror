-- Azar con semilla: el mismo número para la misma semilla y la misma tirada, en cualquier servidor (Random cambia
-- entre versiones de Roblox). Sin nada de Roblox dentro, para probarlo con Lune.
local Azar = {}

local DOS32 = 2 ^ 32

-- a * b módulo 2^32 sin perder cifras (un double solo guarda 53 bits).
local function multiplicar(a: number, b: number): number
	local alto, bajo = bit32.rshift(a, 16), bit32.band(a, 0xFFFF)
	return ((alto * b % 65536) * 65536 + bajo * b) % DOS32
end

-- Revuelve un entero de 32 bits (lowbias32).
local function mezclar(x: number): number
	x = bit32.bxor(x, bit32.rshift(x, 16))
	x = multiplicar(x, 0x7FEB352D)
	x = bit32.bxor(x, bit32.rshift(x, 15))
	x = multiplicar(x, 0x846CA68B)
	return bit32.bxor(x, bit32.rshift(x, 16))
end

-- Entero entre minimo y maximo (incluidos) para la tirada número `tirada` de la partida con esa semilla.
function Azar.entero(semilla: number, tirada: number, minimo: number, maximo: number): number
	local x = mezclar(bit32.bxor(semilla % DOS32, mezclar((tirada * 0x9E3779B9) % DOS32)))
	return minimo + x % (maximo - minimo + 1)
end

return Azar
