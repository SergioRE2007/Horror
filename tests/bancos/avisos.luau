-- Banco de los avisos de una línea (Ui.aviso, docs/sistemas/movil.md): que no se pisen. Carga Ui de verdad con el
-- Roblox de mentira (tests/bancos/_roblox.luau) y mira:
--   uno solo en pantalla; al amanecer el de amanecer y el del premio salen seguidos y los dos se ven ≥ 1,4 s;
--   repetir la misma frase no la rehace (misma etiqueta, sin parpadeo) y la alarga, también mientras se funde;
--   el que pide 5 s (morir) se ve los 5 s aunque llegue otro; la cola no pasa de 3 ni repite frases.
-- Ejecutar desde la raíz: lune run tests/bancos/avisos.luau (lo corre regressions.luau).
local crearMundo = require("./_roblox")

local cuentas = 0
local function comprueba(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end

local m = crearMundo()
local Ui = m.cargar("src/comun/cliente/Ui")
local DT = 1 / 60

-- Los avisos que hay ahora en el HUD.
local function avisos(): { any }
	local lista = {}
	for _, hijo in Ui.hud():GetChildren() do
		if hijo.Name == "Aviso" then
			table.insert(lista, hijo)
		end
	end
	return lista
end
-- Corre `segundos` y apunta, fotograma a fotograma, cuánto se ha visto cada frase (casi opaca) y cuántos a la vez.
local function mirar(segundos: number, visto: { [string]: number }): number
	local maximo = 0
	m.correr(segundos, DT, function()
		local lista = avisos()
		maximo = math.max(maximo, #lista)
		for _, t in lista do
			if t.TextTransparency < 0.5 then
				visto[t.Text] = (visto[t.Text] or 0) + DT
			end
		end
	end)
	return maximo
end

-- Al amanecer: dos a la vez. Los dos se leen, de uno en uno.
do
	local visto = {}
	Ui.aviso("Dawn. It's gone… for now.")
	Ui.aviso("You survived the night. +40 coins")
	local maximo = mirar(9, visto)
	comprueba(maximo == 1, `amanecer: un solo aviso en pantalla (había {maximo})`)
	comprueba((visto["Dawn. It's gone… for now."] or 0) >= 1.1, "amanecer: el del amanecer se lee")
	comprueba((visto["You survived the night. +40 coins"] or 0) >= 3, "amanecer: el del premio se lee entero")
	comprueba(#avisos() == 0, "amanecer: al final no queda ninguno")
end

-- E varias veces en una puerta cerrada: la misma etiqueta, sin volver a fundirse.
do
	Ui.aviso("It's locked.")
	m.correr(0.6)
	local primera = avisos()[1]
	for _ = 1, 6 do
		Ui.aviso("It's locked.")
		m.correr(0.5, DT, function()
			comprueba(avisos()[1] == primera and #avisos() == 1, "puerta: no se rehace")
		end)
		comprueba(primera.TextTransparency < 0.05, "puerta: no parpadea")
	end
	comprueba(primera.Parent ~= nil, "puerta: sigue mientras se insiste")
	-- Pasa su tiempo y empieza a irse; repetirla entonces la trae de vuelta, la misma.
	m.correr(3.9)
	comprueba(primera.Parent ~= nil and primera.TextTransparency > 0.2, "puerta: se está fundiendo")
	Ui.aviso("It's locked.")
	m.correr(0.4)
	comprueba(avisos()[1] == primera and primera.TextTransparency < 0.05, "puerta: repetida al irse, vuelve")
	m.correr(6)
	comprueba(#avisos() == 0, "puerta: al final se va")
end

-- Morir: 'It got you…' pide 5 s y los tiene aunque llegue otro detrás.
do
	local visto = {}
	Ui.aviso("It got you. You'll wake up at dawn.", 5)
	m.correr(0.5)
	Ui.aviso("Run. Get back to the light.")
	mirar(12, visto)
	comprueba((visto["It got you. You'll wake up at dawn."] or 0) >= 4.4, "morir: sus 5 s")
	comprueba((visto["Run. Get back to the light."] or 0) >= 3, "morir: el de detrás sale luego")
end

-- Muchos de golpe: como mucho 3 esperando, sin repetir, y nunca dos a la vez.
do
	local visto = {}
	Ui.aviso("A")
	for _, texto in { "B", "C", "B", "D", "E" } do
		Ui.aviso(texto)
	end
	local maximo = mirar(16, visto)
	comprueba(maximo == 1, "ráfaga: uno solo en pantalla")
	comprueba(visto.A ~= nil and visto.B == nil, "ráfaga: se olvida el más viejo de la cola")
	comprueba(visto.C ~= nil and visto.D ~= nil and visto.E ~= nil, "ráfaga: salen los tres de la cola")
	for texto, s in visto do
		comprueba(s >= 1.1, `ráfaga: {texto} se ve al menos el mínimo`)
	end
	comprueba(#avisos() == 0, "ráfaga: al final no queda ninguno")
end

comprueba(#m.errores == 0, "sin errores " .. table.concat(m.errores, "\n"))
print(`avisos: {cuentas} comprobaciones bien`)
