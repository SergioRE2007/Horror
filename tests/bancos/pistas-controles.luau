-- Banco de los avisos de teclas de la primera vez (cliente/PistasControles). Ejecutar desde la raíz:
-- lune run tests/bancos/pistas-controles.luau (lo corre tests/regressions.luau).
--   PistasControles.decidir, sacada del texto (el módulo necesita Roblox): qué aviso toca con cada estado.
-- Si algo no se cumple, termina con error.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local cuentas = 0
local function comprueba(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end

local fuente = fs.readFile("src/juego/cliente/PistasControles.luau")
local i = string.find(fuente, "-- PRUEBA: decidir", 1, true)
local f = string.find(fuente, "-- FIN PRUEBA", 1, true)
assert(i and f, "no encuentro el trozo de decidir")
local M = {}
luau.load("local PistasControles = ...\n" .. string.sub(fuente, i, f - 1), { debugName = "PistasControles.decidir" })(M)
local decidir = M.decidir

local P = { Cada = 1, TrasSol = 5, Entre = 6, Dura = 4.5 }
local function estado(cambios: { [string]: any }?)
	local e: { [string]: any } = {
		libre = true, ahora = 100, fase = "Dia", noche = 1, nocheRaspador = 3, fotos = 5,
		llevaLinterna = true, encendida = false, tienePistola = false,
	}
	for k, v in cambios or {} do
		e[k] = v
	end
	return e
end
local function sesion(cambios: { [string]: any }?)
	local s: { [string]: any } = { dicho = {}, usado = {}, oscuroDesde = nil, ultimo = -math.huge, pistola = false }
	for k, v in cambios or {} do
		s[k] = v
	end
	return s
end

-- Linterna: solo tras TrasSol s de oscurecer, para no pisar el aviso del sol.
comprueba(decidir(estado(), sesion(), P) == nil, "de día no dice nada")
comprueba(decidir(estado(), sesion({ oscuroDesde = 97 }), P) == nil, "a los 3 s del sol, aún no")
comprueba(decidir(estado(), sesion({ oscuroDesde = 95 }), P) == "Linterna", "a los 5 s del sol, la linterna")
comprueba(decidir(estado({ encendida = true }), sesion({ oscuroDesde = 90 }), P) == nil, "ya encendida: nada")
comprueba(decidir(estado({ llevaLinterna = false }), sesion({ oscuroDesde = 90 }), P) == nil, "sin linterna: nada")
comprueba(decidir(estado({ libre = false }), sesion({ oscuroDesde = 90 }), P) == nil, "escondido o en escena: espera")
comprueba(decidir(estado(), sesion({ oscuroDesde = 90, usado = { Linterna = true } }), P) == nil, "ya la usó: nada")
comprueba(decidir(estado(), sesion({ oscuroDesde = 90, dicho = { Linterna = true } }), P) == nil, "una vez por sesión")

-- Flash: noche del Raspador o después, con fotos, y separado del aviso anterior.
local noche3 = estado({ fase = "Noche", noche = 3 })
local yaLinterna = { Linterna = true }
comprueba(decidir(estado({ fase = "Noche", noche = 2 }), sesion({ dicho = yaLinterna }), P) == nil, "noche 2: sin flash")
comprueba(decidir(noche3, sesion({ dicho = yaLinterna }), P) == "Flash", "noche 3: el flash")
comprueba(decidir(estado({ fase = "Noche", noche = 3, fotos = 0 }), sesion({ dicho = yaLinterna }), P) == nil,
	"sin fotos: nada")
comprueba(decidir(noche3, sesion({ dicho = yaLinterna, ultimo = 97 }), P) == nil, "no pisa el aviso de hace 3 s")
comprueba(decidir(noche3, sesion({ dicho = yaLinterna, usado = { Flash = true } }), P) == nil, "ya hizo fotos: nada")

-- Pistola: solo al llegarle.
comprueba(decidir(estado({ tienePistola = true }), sesion(), P) == nil, "ya la tenía al entrar: nada")
comprueba(decidir(estado({ tienePistola = true }), sesion({ pistola = true }), P) == "Pistola", "le llega: la Q")
comprueba(decidir(estado({ tienePistola = true }), sesion({ pistola = true, usado = { Pistola = true } }), P) == nil,
	"ya la sacó: nada")
comprueba(decidir(estado(), sesion({ pistola = true }), P) == nil, "la soltó antes del aviso: nada")

print(`pistas-controles: {cuentas} comprobaciones`)
