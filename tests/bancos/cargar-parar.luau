-- Banco de "moverse corta el trabajo" (juego/servidor/Cargar). Ejecutar desde la raíz: lune run
-- tests/bancos/cargar-parar.luau (lo corre tests/regressions.luau).
--   Cargar.pedir y Cargar.trabajar sacados del texto (Cargar necesita Roblox) con un jugador, un reloj y unos
--   remotes de mentira: "Parar" sin Trabajando no cambia nada; "Parar" trabajando lo deja a medias; sin nada, suelta.
-- Si algo no se cumple, termina con error.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local cuentas = 0
local function comprueba(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end

local fuente = fs.readFile("src/juego/servidor/Cargar.luau")
local function trozo(desde: string, hasta: string): string
	local i = string.find(fuente, desde, 1, true)
	assert(i, `no encuentro {desde}`)
	local f = string.find(fuente, hasta, i, true)
	assert(f, `no encuentro {hasta}`)
	return string.sub(fuente, i, f - 1)
end

-- Un jugador de mentira (solo atributos) y lo que Cargar usa alrededor.
local atributos: { [string]: any } = {}
local jugador = {
	GetAttribute = function(_, k)
		return atributos[k]
	end,
	SetAttribute = function(_, k, v)
		atributos[k] = v
	end,
}
local reloj = 0
local alEsperar: (() -> ())? = nil
local enviados: { string } = {}
local soltados = 0
local Cargar = {
	soltar = function()
		soltados += 1
	end,
	ajustarVelocidad = function() end,
}
local entorno = {
	Cargar = Cargar,
	Remotes = { Trabajo = { FireAllClients = function(_, _, que)
		table.insert(enviados, que)
	end } },
	Muerte = { vivo = function()
		return true
	end },
	os = { clock = function()
		return reloj
	end },
	task = { wait = function(s)
		reloj += s
		if alEsperar then
			alEsperar()
		end
	end },
}
local codigo = trozo("local cortar:", "\n") .. "\n" .. trozo("function Cargar.trabajar", "\nend\n") .. "\nend\n"
	.. trozo("function Cargar.pedir", "\nend\n") .. "\nend\n"
luau.load(codigo, { debugName = "Cargar (trozo)", environment = setmetatable(entorno, { __index = getfenv() }) })()

local pieza = { Parent = {} }

-- Sin trabajar: "Parar" no suelta ni deja nada marcado para el próximo trabajo.
Cargar.pedir(jugador, "Parar")
comprueba(soltados == 0, "Parar sin Trabajando no suelta lo que llevas")
comprueba(atributos.Trabajando == nil, "Parar sin Trabajando no pone Trabajando")
comprueba(Cargar.trabajar(jugador, "Clavar", pieza, 1) == true, "Parar de antes no corta el trabajo siguiente")
comprueba(enviados[#enviados] == "Clavar", "el trabajo entero no manda Parar")
comprueba(atributos.Trabajando == nil, "al acabar se quita Trabajando")

-- Trabajando: "Parar" a medias lo corta y avisa a los clientes.
local vueltas = 0
alEsperar = function()
	vueltas += 1
	if vueltas == 3 then
		Cargar.pedir(jugador, "Parar")
	end
end
local inicio = reloj
comprueba(Cargar.trabajar(jugador, "Clavar", pieza, 3.5) == false, "Parar trabajando lo deja a medias")
comprueba(reloj - inicio < 1, "se corta enseguida, no al final")
comprueba(enviados[#enviados] == "Parar", "los clientes reciben Parar (corta la animación)")
comprueba(atributos.Trabajando == nil, "cortado, se quita Trabajando")
comprueba(soltados == 0, "Parar trabajando no pasa por soltar")
alEsperar = nil
comprueba(Cargar.trabajar(jugador, "Serrar", pieza, 1) == true, "el corte no se queda para el siguiente trabajo")

-- Sin nada (la E de soltar) o cualquier otra cosa: suelta como siempre.
Cargar.pedir(jugador)
comprueba(soltados == 1, "Cargar sin nada suelta lo que llevas")

print(`cargar-parar: {cuentas} comprobaciones bien`)
