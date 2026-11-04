-- Ritmo y economía (14.9.5): una partida típica de 1 y de 2 jugadores y una semana de un jugador que juega 30 min al
-- día. Ejecutar desde la raíz: lune run tests/bancos/economia.luau (también lo lanza tests/regressions.luau).
-- Sin Roblox: carga Config, Premio (las cuentas de Recompensas), Comprar (las de la tienda) y Formato (un jugador
-- nuevo), y simula con ellos. Lo que no sale de Config (cuántas noches hasta cada final, cuánto se muere, lo que
-- tarda el lobby) son supuestos a ojo, todos en la tabla S de abajo: se cambian ahí al ver jugar a alguien.
-- Comprueba lo que pide el diseño ("relativamente f2p", la primera clase gratis y otra en pocas partidas, pagar solo
-- acelera) y que lo primero que se gana llega pronto. Las cuentas y la propuesta, en docs/sistemas/economia.md.
-- Si algo no se cumple, termina con error.
local fs = require("@lune/fs")
local luau = require("@lune/luau")

-- Un "script" falso: script.Parent.Config = el archivo de al lado, como en Roblox (lo mismo que tests/regressions).
local function nodo(ruta: string)
	return setmetatable({ ruta = ruta }, {
		__index = function(_, clave)
			return nodo(if clave == "Parent" then (string.match(ruta, "^(.*)/[^/]+$") :: string) else ruta .. "/" .. clave)
		end,
	})
end
local cargados = {}
local function cargar(ruta: string)
	if cargados[ruta] == nil then
		local fuente = fs.readFile(ruta .. ".luau")
		local entorno = {
			script = nodo(ruta),
			require = function(n)
				return cargar(n.ruta)
			end,
		}
		cargados[ruta] = luau.load(fuente, { debugName = ruta, environment = entorno })()
	end
	return cargados[ruta]
end

local Config = cargar("src/shared/Config")
local Premio = cargar("src/comun/servidor/Premio")
local Comprar = cargar("src/comun/servidor/Comprar")
local Formato = cargar("src/comun/servidor/Formato")
local R = Config.Recompensas -- se cambia un momento en el apartado 5 (la propuesta)
local C = Config.Ciclo -- Config.Test no cuenta: es solo para Studio

-- Supuestos a ojo (no están en Config: salen de cómo se juega). [1] = solo, [2] = dos jugadores.
local S = {
	Sesion = 30 * 60, -- lo que juega al día
	Entrada = 90, -- s del lobby a la casa: cargar, tienda, coche (Config.Coches.Salida) y teletransporte
	Vuelta = 30, -- s de vuelta al lobby tras un final
	-- Probabilidad de que mueran todos en la noche n: Base + Sube * (n - 1), como mucho Tope. Con dos, uno que aguanta
	-- salva la noche (quien muere revive de día), así que se pierden menos.
	Perder = { { Base = 0.08, Sube = 0.03, Tope = 0.45 }, { Base = 0.05, Sube = 0.025, Tope = 0.35 } },
	Muere = 0.6, -- parte de la noche que dura de media una noche perdida
	Huida = { 8, 6 }, -- noches superadas antes de huir (llave del aserradero, piezas, batería, radiador y bidón)
	HuirDia = 60, -- s del día de la huida hasta arrancar (montar lo último)
	Bestia = { 13, 11 }, -- la noche de la Bestia (casi toda la casa abierta, pista 9, 6 cruces, reja, desván)
	BestiaLucha = 150, -- s de "Wait for her" a encerrarla y prender el fuego
	PerderBestia = { 0.4, 0.3 }, -- probabilidad de morir todos en ella (se vuelve a la foto de "Wait for her")
	-- A qué hora empieza a jugar cada día de la semana: un niño no juega siempre a la misma hora.
	Horas = { 18, 17.5, 18.25, 17.75, 19, 17.5, 18.5 },
	Base = 1.8e9, -- os.time() del día 1 a las 00:00 (cualquiera muy por encima de 0)
	PrimerDia = nil :: number?, -- s del día 1 de cada partida (nil = Config.Ciclo.Dia); solo lo cambia la propuesta
}

local fallos = {}
local function comprobar(cumple: boolean, que: string)
	if not cumple then
		table.insert(fallos, que)
	end
end
local function mmss(s: number): string
	return string.format("%d:%02d", s // 60, math.floor(s % 60))
end

-- Lo que paga Recompensas.fase al amanecer tras superar la noche `superada` (copiado de allí: noche + logros de noche).
local function amanecer(datos, superada: number): number
	local total = Premio.noche(R, superada)
	for nombre, logro in R.Logros do
		if logro.Noche and superada >= logro.Noche then
			total += Premio.logro(datos, R, nombre)
		end
	end
	return total
end

local function perder(j: number, n: number): number
	local P = S.Perder[j]
	return math.min(P.Base + P.Sube * (n - 1), P.Tope)
end

-- Lo que se compra, en el orden en que lo haría un niño: clases (lo que se nota al jugar) y luego luces, de la más
-- barata a la más cara.
local LISTA = {}
for _, clase in Config.Clases do
	table.insert(LISTA, { tipo = "Clase", id = clase.Id, precio = clase.Precio })
end
local luces = table.clone(Config.Cosmeticos)
table.sort(luces, function(a, b)
	return a.Precio < b.Precio
end)
for _, cosa in luces do
	table.insert(LISTA, { tipo = "Cosmetico", id = cosa.Id, precio = cosa.Precio })
end

---------------------------------------------------------------------------------------------------------------------
-- 1. Partida típica: minutos y monedas por noche (valor esperado con la probabilidad de perder cada noche).
---------------------------------------------------------------------------------------------------------------------
local CICLO = C.Dia + C.Noche
local function esperado(j: number, n: number): number
	local p = perder(j, n)
	return CICLO + p / (1 - p) * (C.Dia + C.Noche * S.Muere + C.Reinicio)
end

print("Partida típica (minutos acumulados; monedas de la noche, la primera vez con logros)")
print("noche |  solo  |  dos   | monedas | 1.ª vez")
local acumulado = { S.Entrada, S.Entrada }
local primeraPartida = Formato.jugadorNuevo()
local porPartida = { 0, 0 } -- monedas de la 1.ª partida (huida) de un jugador nuevo, solo y con dos
local minutosPartida = { 0, 0 }
for n = 1, S.Bestia[1] do
	for j = 1, 2 do
		acumulado[j] += esperado(j, n)
	end
	local normal = Premio.noche(R, n)
	local conLogros = amanecer(primeraPartida, n)
	if n == 1 then
		conLogros += Premio.logro(primeraPartida, R, "Tutorial")
	end
	for j = 1, 2 do
		if n <= S.Huida[j] then
			porPartida[j] += conLogros
			minutosPartida[j] = acumulado[j] + S.HuirDia + Config.Coche.Cinematica
		end
	end
	print(string.format("%5d | %6s | %6s | %7d | %7d", n, mmss(acumulado[1]), mmss(acumulado[2]), normal, conLogros))
end
local huidaPrimera = Premio.final(Formato.jugadorNuevo(), R, "Huida")
local bestiaPrimera = Premio.final(Formato.jugadorNuevo(), R, "Bestia")
for j = 1, 2 do
	porPartida[j] += huidaPrimera
	print(string.format("1.ª partida %s: huida tras la noche %d, %s min, %d monedas (%.1f por minuto)",
		if j == 1 then "solo" else "con dos", S.Huida[j], mmss(minutosPartida[j]), porPartida[j],
		porPartida[j] / (minutosPartida[j] / 60)))
end
print(string.format("Finales: huida %d (+%d la 1.ª vez), Bestia %d (+%d la 1.ª vez)", R.Final, huidaPrimera - R.Final,
	R.FinalBestia, bestiaPrimera - R.FinalBestia))

-- Lo que rinde cada manera de jugar (monedas por minuto, sin logros): acabar debe rendir más que quedarse en las
-- noches altas para siempre (sin límite de noches: cada noche más difícil empuja a terminar).
local function rinde(j: number, final: string): number
	local noches = if final == "Huida" then S.Huida[j] else S.Bestia[j] - 1
	local monedas, segundos = 0, S.Entrada + S.Vuelta
	for n = 1, noches do
		monedas += Premio.noche(R, n)
		segundos += esperado(j, n)
	end
	if final == "Huida" then
		monedas += R.Final
		segundos += S.HuirDia + Config.Coche.Cinematica
	else
		monedas += R.FinalBestia
		local p = S.PerderBestia[j]
		segundos += C.Dia + S.BestiaLucha + Config.Bestia.ArdeCasa + Config.Bestia.Cinematica
			+ p / (1 - p) * (C.Reinicio + Config.Bestia.Espera + S.BestiaLucha * S.Muere)
	end
	return monedas / (segundos / 60)
end
local alto = R.TopeNoches + 1
for j = 1, 2 do
	local quedarse = Premio.noche(R, alto) / (esperado(j, alto) / 60)
	print(string.format("Monedas/min %s: partida con huida %.1f, con la Bestia %.1f, quedarse en la noche %d+ %.1f",
		if j == 1 then "solo" else "con dos", rinde(j, "Huida"), rinde(j, "Bestia"), alto, quedarse))
	comprobar(rinde(j, "Huida") > quedarse and rinde(j, "Bestia") > quedarse,
		"acabar la partida rinde más que quedarse en las noches altas")
end

---------------------------------------------------------------------------------------------------------------------
-- 2. Una semana de 30 min al día: partidas seguidas (la 1.ª se acaba huyendo, la 2.ª con la Bestia y así), el
-- premio diario al entrar en cada lugar (lobby y casa, como Recompensas) y compras en la tienda del lobby.
---------------------------------------------------------------------------------------------------------------------
type Semana = {
	datos: any,
	compras: { [string]: string }, -- id → cuándo ("día 2, min 14")
	orden: { string },
	partida: number,
	superadas: number,
	acumulado: number, -- para perder las noches de forma fija: cada vez que pasa de 1, se pierde una
	diarios: number,
	finales: { [string]: number },
	porDia: { { monedas: number, noches: number, final: string } },
	primerPremio: number?, -- s desde que entra la primera vez hasta el primer premio de la partida
	minuto5: number?, -- monedas a los 5 min
	alcanza: number?, -- s de juego hasta tener para la segunda clase (la tienda está en el lobby: se compra al volver)
	todo: string?, -- cuándo tiene ya todo el catálogo
	clases: string?, -- cuándo tiene ya todas las clases
}

local function semana(j: number, paquete: boolean): Semana
	local w: Semana = {
		datos = Formato.jugadorNuevo(),
		compras = {},
		orden = {},
		partida = 1,
		superadas = 0,
		acumulado = 0,
		diarios = 0,
		finales = { Huida = 0, Bestia = 0 },
		porDia = {},
		primerPremio = nil,
		minuto5 = nil,
		alcanza = nil,
		todo = nil,
		clases = nil,
	}
	local datos = w.datos
	if paquete then -- el pase PaqueteInicio comprado el primer minuto (lo que da su Regalo)
		local pase = nil
		for _, p in Config.Compras.Pases do
			if p.Ventaja == "PaqueteInicio" then
				pase = p
			end
		end
		Premio.sumar(datos, pase.Regalo.Monedas)
		for _, id in pase.Regalo.Cosmeticos do
			datos.cosmeticos[id] = true
		end
	end
	local dia, inicio = 1, 0

	local function cuando(t: number): string
		return `día {dia}, min {(t - inicio) // 60}`
	end
	local segunda = Config.Clases[2]
	local function sumar(m: number, t: number)
		Premio.sumar(datos, m)
		if not w.alcanza and not w.compras[segunda.Id] and datos.monedas >= segunda.Precio then
			w.alcanza = (dia - 1) * S.Sesion + (t - inicio)
		end
	end
	local function entrar(t: number) -- Recompensas al entrar en un lugar: el premio diario
		local m = Premio.diario(datos, R, t)
		if m > 0 then
			sumar(m, t)
			w.diarios += 1
		end
	end
	local function tienda(t: number) -- compra en orden y ahorra para lo siguiente (no se gasta en luces antes)
		for _, cosa in LISTA do
			if not w.compras[cosa.id] then
				local r = if cosa.tipo == "Clase"
					then Comprar.clase(datos, Config.Clases, cosa.id)
					else Comprar.cosmetico(datos, Config.Cosmeticos, cosa.id)
				if r == "ok" or r == "tiene" then
					w.compras[cosa.id] = if r == "ok" then cuando(t) else "regalo"
					table.insert(w.orden, cosa.id)
					if #w.orden == #LISTA then
						w.todo = cuando(t)
					end
					if #w.orden == #Config.Clases then
						w.clases = cuando(t)
					end
				else
					break
				end
			end
		end
	end

	for d = 1, 7 do
		dia = d
		inicio = S.Base + (d - 1) * 86400 + S.Horas[d] * 3600
		local fin = inicio + S.Sesion
		local antes, nochesHoy, finalHoy = datos.monedas, 0, ""
		local gastado = 0
		local t = inicio
		entrar(t)
		local m0 = datos.monedas
		tienda(t)
		gastado += m0 - datos.monedas
		while t + S.Entrada < fin do
			t += S.Entrada
			entrar(t)
			local final = if w.partida % 2 == 1 then "Huida" else "Bestia"
			local ciclo = Premio.ciclo() -- un servidor nuevo: el primer día no paga
			Premio.amanecer(ciclo, "Dia", w.superadas + 1)
			local acabada = false
			local intentoBestia = false
			while true do
				local n = w.superadas + 1
				local p, dura
				if final == "Huida" and w.superadas >= S.Huida[j] then
					dura = S.HuirDia + Config.Coche.Cinematica
					if t + dura > fin then
						t = fin
						break
					end
					t += dura
					sumar(Premio.final(datos, R, "Huida"), t)
					acabada = true
					break
				elseif final == "Bestia" and n >= S.Bestia[j] then
					p = S.PerderBestia[j]
					local pierde = w.acumulado + p >= 1
					local antesDeLuchar = if intentoBestia then C.Reinicio + Config.Bestia.Espera else C.Dia
					dura = antesDeLuchar + if pierde then S.BestiaLucha * S.Muere
						else S.BestiaLucha + Config.Bestia.ArdeCasa + Config.Bestia.Cinematica
					if t + dura > fin then
						t = fin
						break
					end
					t += dura
					w.acumulado = if pierde then w.acumulado + p - 1 else w.acumulado + p
					intentoBestia = true
					if not pierde then
						sumar(Premio.final(datos, R, "Bestia"), t)
						acabada = true
						break
					end
				else
					p = perder(j, n)
					local pierde = w.acumulado + p >= 1
					local diaHoy = if n == 1 and S.PrimerDia then S.PrimerDia else C.Dia
					dura = diaHoy + if pierde then C.Noche * S.Muere + C.Reinicio else C.Noche
					if t + dura > fin then
						t = fin -- se va a media noche: vuelve a la foto del último amanecer
						break
					end
					t += dura
					w.acumulado = if pierde then w.acumulado + p - 1 else w.acumulado + p
					Premio.amanecer(ciclo, "Noche", n)
					if pierde then
						Premio.amanecer(ciclo, "Dia", n) -- mueren todos: vuelve el mismo día, sin pagar
					else
						assert(Premio.amanecer(ciclo, "Dia", n + 1), "el amanecer de verdad paga")
						local m = amanecer(datos, n)
						m += Premio.logro(datos, R, "Tutorial") -- acaba al primer amanecer (cortinas cerradas)
						sumar(m, t)
						w.superadas = n
						nochesHoy += 1
						if not w.primerPremio then
							w.primerPremio = t - inicio
						end
					end
				end
			end
			if w.minuto5 == nil then
				-- a los 5 min solo puede tener lo del lobby: nada de la casa llega antes del primer amanecer
				w.minuto5 = if (w.primerPremio or math.huge) <= 300 then -1 else m0
			end
			if not acabada then
				break
			end
			w.finales[final] += 1
			finalHoy ..= (if finalHoy == "" then "" else "+") .. final
			w.partida += 1
			w.superadas = 0
			t += S.Vuelta
			entrar(t)
			local m1 = datos.monedas
			tienda(t)
			gastado += m1 - datos.monedas
		end
		table.insert(w.porDia, { monedas = datos.monedas - antes + gastado, noches = nochesHoy, final = finalHoy })
	end
	return w
end

local precioTotal = 0
for _, cosa in LISTA do
	precioTotal += cosa.precio
end
local primeraClase = Config.Clases[1].Precio

for j = 1, 2 do
	local w = semana(j, false)
	print(`\nSemana de 30 min al día ({if j == 1 then "solo" else "con un amigo"}; monedas de cada uno)`)
	print("día | ganado | noches | final")
	local total = 0
	for d, hoy in w.porDia do
		total += hoy.monedas
		print(string.format("%3d | %6d | %6d | %s", d, hoy.monedas, hoy.noches, hoy.final))
	end
	print(`Total {total} monedas, {w.diarios} premios diarios de 7, finales: {w.finales.Huida} huidas, {w.finales.Bestia} Bestias`)
	print(`Le quedan {w.datos.monedas} sin gastar; el catálogo entero cuesta {precioTotal - primeraClase} (la 1.ª clase, gratis)`)
	local lineas = {}
	for _, id in w.orden do
		table.insert(lineas, `{id} ({w.compras[id]})`)
	end
	print("Compras: " .. table.concat(lineas, ", "))
	print(`Primer premio de la casa: min {mmss(w.primerPremio or 0)} desde que entra; a los 5 min tiene {w.minuto5} monedas`)

	-- Lo que debe cumplirse.
	comprobar(w.compras[Config.Clases[1].Id] == "día 1, min 0", "la primera clase, gratis en el primer minuto")
	print(`Tiene para la segunda clase a los {mmss(w.alcanza or 0)} min de juego; la compra el {w.compras[Config.Clases[2].Id]}`)
	comprobar(w.alcanza ~= nil and w.alcanza <= 60 * 60, "para la segunda clase (400) en menos de 1 h de juego (1-2 partidas)")
	comprobar(w.compras[Config.Clases[2].Id] ~= nil and string.match(w.compras[Config.Clases[2].Id], "^día [123],") ~= nil,
		"la segunda clase comprada antes de acabar el día 3")
	for _, clase in Config.Clases do
		comprobar(w.compras[clase.Id] ~= nil, `la clase {clase.Id} se consigue sin pagar en la primera semana`)
	end
	comprobar(w.finales.Huida >= 1 and w.finales.Bestia >= 1, "los dos finales en la primera semana sin Robux")
	comprobar((w.primerPremio or math.huge) <= 10 * 60, "el primer premio de la casa antes de 10 min")
	if w.diarios < 7 then
		-- No es un fallo del código: Config.Recompensas.Cada pide 24 h justas y jugar un poco antes otro día lo pierde.
		print(`AVISO: solo {w.diarios} premios diarios de 7 jugando a horas algo distintas (propuesta en economia.md)`)
	end
end

-- Pagar solo acelera: con el paquete de inicio se tiene todo antes, pero sin él también.
do
	local f2p, pagado = semana(1, false), semana(1, true)
	local function ultimo(w: Semana): string
		return w.todo or `sin acabar ({#w.orden} de {#LISTA})`
	end
	print(`\nTodas las clases (solo): sin pagar {f2p.clases or "sin acabar"}; con el paquete de inicio {pagado.clases or "sin acabar"}`)
	print(`Todo el catálogo (solo): sin pagar {ultimo(f2p)}; con el paquete de inicio {ultimo(pagado)}`)
	comprobar(f2p.clases ~= nil, "todas las clases sin pagar en una semana")
end

---------------------------------------------------------------------------------------------------------------------
-- 3. Robux: pocos pases, nada imprescindible, precios coherentes.
---------------------------------------------------------------------------------------------------------------------
local CP = Config.Compras
print("\nRobux")
local tasa = 0
for _, paquete in CP.Monedas do
	local esta = paquete.Monedas / paquete.Robux
	print(string.format("  %d R$ → %d monedas (%.1f por R$)", paquete.Robux, paquete.Monedas, esta))
	comprobar(esta >= tasa, "los paquetes de monedas más grandes rinden más por Robux")
	tasa = esta
end
local tasaBase = CP.Monedas[1].Monedas / CP.Monedas[1].Robux
print(string.format("  Una clase (%d) ≈ %d R$; revivir %d R$ ≈ %d monedas (reembolso %d)", primeraClase,
	math.ceil(Config.Clases[2].Precio / tasaBase), CP.Revivir.Robux, math.floor(CP.Revivir.Robux * tasaBase),
	CP.Reembolso))
comprobar(#CP.Pases <= 4, "pocos pases (3-4, docs/diseño.md)")
for _, pase in CP.Pases do
	print(string.format("  Pase %s: %d R$", pase.Ventaja, pase.Robux))
	if pase.Ventajas then
		for ventaja, valor in pase.Ventajas do
			comprobar(Config.Ventajas[ventaja] ~= nil, `el pase {pase.Ventaja} solo toca ventajas que existen`)
			comprobar(valor <= 1.5, `el pase {pase.Ventaja}: {ventaja} ×{valor} es una comodidad, no lo imprescindible`)
			for _, clase in Config.Clases do
				comprobar(clase.Ventajas[ventaja] == nil, `el pase {pase.Ventaja} no vende la ventaja de una clase`)
			end
		end
	end
	if pase.Regalo then
		for clave in pase.Regalo do
			comprobar(clave == "Monedas" or clave == "Cosmeticos",
				`el regalo de {pase.Ventaja} solo da monedas y cosméticos (nunca llaves, piezas ni noches)`)
		end
		comprobar((pase.Regalo.Monedas or 0) <= precioTotal - primeraClase,
			"el paquete de inicio no da más de lo que vale el catálogo")
	end
	if pase.Ranuras then
		comprobar(Config.Partida.Ranuras >= 3, "sin pase hay 3 ranuras: basta para jugar")
	end
end
comprobar(math.abs(CP.Reembolso - CP.Revivir.Robux * tasaBase) <= CP.Reembolso * 0.5,
	"el reembolso de un revivir vale más o menos lo pagado")

---------------------------------------------------------------------------------------------------------------------
-- 4. Lo que siempre debe valer, sin supuestos.
---------------------------------------------------------------------------------------------------------------------
local nuevo = Formato.jugadorNuevo()
for _, clase in Config.Clases do
	comprobar(Comprar.precioClase(nuevo, clase) == 0, `la primera clase es gratis ({clase.Id})`)
end
local anterior = 0
for n = 1, R.TopeNoches + 5 do
	local m = Premio.noche(R, n)
	comprobar(m >= anterior, "cada noche paga lo mismo o más que la anterior")
	anterior = m
end
comprobar(Premio.noche(R, R.TopeNoches + 1) == Premio.noche(R, R.TopeNoches + 5), "la paga de la noche tiene tope")
comprobar(R.Logros.Tutorial.Monedas < primeraClase, "el tutorial da menos que una clase (la 1.ª ya es gratis)")
comprobar(R.FinalBestia > R.Final, "el final difícil paga más que el fácil")

---------------------------------------------------------------------------------------------------------------------
-- 5. La propuesta de docs/sistemas/economia.md (a ojo; NO está en Config: la decide Sergio en la 14.5). Solo lo que
-- se puede simular aquí: premio diario cada 20 h, más por la noche 1 y el tutorial, logros en las noches 3 y 7 (las
-- de los bichos nuevos) y un primer día de 120 s.
---------------------------------------------------------------------------------------------------------------------
do
	local propuesta = table.clone(Config.Recompensas)
	propuesta.Cada = 20 * 3600
	propuesta.Logros = table.clone(Config.Recompensas.Logros)
	propuesta.Logros.Noche1 = { Noche = 1, Monedas = 100 }
	propuesta.Logros.Tutorial = { Monedas = 150 }
	propuesta.Logros.Noche3 = { Noche = 3, Monedas = 75 }
	propuesta.Logros.Noche7 = { Noche = 7, Monedas = 200 }
	local original = R
	R = propuesta
	S.PrimerDia = 120
	print("\nCon la propuesta (a ojo, sin tocar Config)")
	for j = 1, 2 do
		local w = semana(j, false)
		local total = 0
		for _, hoy in w.porDia do
			total += hoy.monedas
		end
		print(string.format("  %s: %d monedas en la semana, %d diarios de 7, 1.er premio min %s, segunda clase %s,"
			.. " todas las clases %s, todo %s", if j == 1 then "solo" else "con dos", total, w.diarios,
			mmss(w.primerPremio or 0), w.compras[Config.Clases[2].Id] or "-", w.clases or "-", w.todo or "sin acabar"))
		comprobar(w.diarios == 7, "propuesta: todos los premios diarios")
		comprobar(string.match(w.compras[Config.Clases[2].Id] or "", "^día [12],") ~= nil,
			"propuesta: la segunda clase al empezar el día 2 como tarde")
	end
	R = original
	S.PrimerDia = nil
end

if #fallos > 0 then
	error("economía:\n  " .. table.concat(fallos, "\n  "))
end
print("\neconomía: todo se cumple")
