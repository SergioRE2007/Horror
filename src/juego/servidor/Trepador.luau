-- El Trepador (desde la noche Config.Trepador.Noche): sale del bosque, trepa por la pared de delante o de detrás y
-- ronda por el tejado (pasos y crujidos encima de las cabezas). Al rato se mete por el tiro de la chimenea, baja y sale
-- al salón por el hogar: ruge y caza como el Golpeador. Se le echa encendiendo la chimenea (Chimenea): con el fuego
-- encendido, en el tejado o mientras baja, chilla, se tira del tejado y huye.
-- En la pared y en el tejado se mueve sin física (la raíz anclada, paso a paso); en el suelo, como los demás (Caza).
-- Atributos del modelo para el cliente (TrepadorVista): Trepando, EnTejado, Bajando.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Caza = require(script.Parent.Caza)
local Chimenea = require(script.Parent.Chimenea)
local Cuerpo = require(script.Parent.Cuerpo)
local Muerte = require(script.Parent.Muerte)

local Trepador = {}

local T = Config.Trepador
local ALTURA = 2.2 -- a cuatro patas: de los pies al centro de la raíz
local azar = Random.new()

-- El tejado (Mapa): dos faldones con la cumbrera a lo largo de x en z = 0; la cara de arriba a 36,53 en la cumbrera y
-- bajando 9/24 por stud hasta el alero (|z| = 24). La pared de delante está en z = -22,5 y la de detrás en 22,5.
local CUMBRE, PENDIENTE, PARED = 36.53, 9 / 24, 22.5
local COS, SIN = math.cos(math.atan(PENDIENTE)), math.sin(math.atan(PENDIENTE))

type Ataque = { bicho: Caza.Bicho?, hilo: thread?, prisa: boolean }
local ataques: { [Ataque]: boolean } = {}

local function rango(r: { number }): number
	return azar:NextNumber(r[1], r[2])
end

-- Carne pálida y despellejada, con lo de dentro asomando por la espalda.
local PIEL, CARNE, SANGRE, HUESO = Color3.fromRGB(150, 124, 114), Color3.fromRGB(112, 34, 30), Color3.fromRGB(70, 6, 6),
	Color3.fromRGB(196, 186, 160)

local function crear(cf: CFrame): Caza.Bicho
	local m, raiz = Cuerpo.nuevo("Trepador", cf)
	local function miembro(...)
		return Cuerpo.miembro(m, ...)
	end
	local function pegar(...)
		Cuerpo.pegar(m, ...)
	end

	-- Un hombre a cuatro patas como una araña: cuerpo tumbado, codos y rodillas muy por encima de la espalda, la
	-- cabeza del revés (la boca arriba), la espalda abierta con las costillas y el espinazo al aire.
	local torso = miembro("Torso", Vector3.new(1.9, 1.1, 4.4), raiz, CFrame.new(0, 0, 0), CFrame.new(0, 0, 0), PIEL)
	pegar(torso, Vector3.new(1.1, 0.15, 3.2), CFrame.new(0, 0.5, 0.1), CARNE)
	for i = 0, 5 do
		pegar(torso, Vector3.new(1.5, 0.14, 0.14), CFrame.new(0, 0.62, -1.2 + i * 0.5) * CFrame.Angles(0, 0, 0), HUESO)
		pegar(torso, Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, 0.7, -1.3 + i * 0.52), HUESO)
	end
	pegar(torso, Vector3.new(0.5, 0.1, 1.4), CFrame.new(0.35, 0.58, 0.6), SANGRE) -- algo blando y oscuro entre las costillas

	local cabeza = miembro("Cabeza", Vector3.new(1.2, 1.3, 1.4), torso, CFrame.new(0, 0.1, -2.3) * CFrame.Angles(0, 0, math.pi),
		CFrame.new(0, 0, 0.6), PIEL)
	-- Del revés: lo que en la cabeza está abajo se ve arriba. Ojos abiertos de par en par, sin párpados.
	for _, x in { -0.3, 0.3 } do
		pegar(cabeza, Vector3.new(0.34, 0.3, 0.1), CFrame.new(x, 0.3, -0.67), Color3.fromRGB(10, 6, 6))
		pegar(cabeza, Vector3.new(0.12, 0.12, 0.05), CFrame.new(x, 0.3, -0.73), Color3.fromRGB(190, 180, 160), Enum.Material.Neon)
	end
	pegar(cabeza, Vector3.new(1.05, 0.45, 0.1), CFrame.new(0, -0.3, -0.67), Color3.fromRGB(25, 0, 0))
	for i = -4, 4 do
		pegar(cabeza, Vector3.new(0.07, azar:NextNumber(0.15, 0.3), 0.06), CFrame.new(i * 0.11, -0.12, -0.72), HUESO)
	end
	local mandibula = miembro("Mandibula", Vector3.new(1.1, 0.3, 1.2), cabeza, CFrame.new(0, -0.65, 0.5), CFrame.new(0, 0, 0.6), PIEL)
	pegar(mandibula, Vector3.new(0.1, 0.5, 0.05), CFrame.new(-0.3, 0.1, -0.62), SANGRE)

	-- Patas: el tramo de arriba sube hacia fuera desde el hombro o la cadera; el de abajo baja hasta el suelo.
	for _, datos in { { "Brazo", "Antebrazo", -1.7 }, { "Pierna", "Espinilla", 1.7 } } do
		for _, lado in { -1, 1 } do
			local letra = if lado < 0 then "I" else "D"
			local arriba = miembro(datos[1] .. letra, Vector3.new(0.36, 3, 0.36), torso,
				CFrame.new(lado * 0.9, 0, datos[3]) * CFrame.Angles(0, 0, lado * 2.36), CFrame.new(0, 1.5, 0), PIEL)
			local abajo = miembro(datos[2] .. letra, Vector3.new(0.28, 4.5, 0.28), arriba,
				CFrame.new(0, -1.5, 0) * CFrame.Angles(0, 0, -lado * 2.0), CFrame.new(0, 2.25, 0), PIEL)
			-- Dedos largos abiertos en la punta, con sangre seca.
			for i = -1, 1 do
				pegar(abajo, Vector3.new(0.08, 0.7, 0.08), CFrame.new(i * 0.1, -2.45, -0.15) * CFrame.Angles(0.6, 0, i * 0.3), SANGRE)
			end
		end
	end

	local humanoide = Cuerpo.terminar(m, Caza.carpeta(), ALTURA, T.Andar)
	return Caza.nuevo(m, humanoide, {
		Altura = ALTURA,
		Andar = T.Andar,
		Correr = T.Correr,
		Pillar = T.Pillar,
		Vista = T.Vista,
		VioEsconderse = T.VioEsconderse,
	})
end

-- Un aviso de una línea a los que están dentro de la casa.
local function avisarDentro(frase: string)
	for _, jugador in Muerte.vivos() do
		local cabeza = jugador.Character and jugador.Character:FindFirstChild("Head") :: BasePart?
		if cabeza and Caza.dentroDeCasa(cabeza.Position) then
			Remotes.Aviso:FireClient(jugador, Lang.t(jugador, frase))
		end
	end
end

-- Dónde va la raíz para estar a cuatro patas sobre el tejado en (x, z), y hacia dónde es "arriba" ahí.
local function sobreTejado(x: number, z: number): (Vector3, Vector3)
	local lado = if z >= 0 then 1 else -1
	local arriba = Vector3.new(0, COS, lado * SIN)
	return Vector3.new(x, CUMBRE - math.abs(z) * PENDIENTE, z) + arriba * ALTURA, arriba
end

-- Lleva la raíz (anclada) hasta `hasta` en `segundos`. Devuelve false si se corta: amanece, le queman (si `fuego`) o
-- desaparece.
local function deslizar(b: Caza.Bicho, hasta: CFrame, segundos: number, fuego: boolean?): boolean
	local desde = b.raiz.CFrame
	local inicio = os.clock()
	while true do
		if not b.modelo or b.prisa or (fuego and Chimenea.encendida()) then
			return false
		end
		local t = math.min(1, (os.clock() - inicio) / math.max(segundos, 0.01))
		b.raiz.CFrame = desde:Lerp(hasta, t)
		if t >= 1 then
			return true
		end
		RunService.Heartbeat:Wait()
	end
end

-- Anda por el tejado hasta (x, z), del mismo faldón.
local function andarTejado(b: Caza.Bicho, x: number, z: number): boolean
	local hasta, arriba = sobreTejado(x, z)
	local desde = b.raiz.Position
	local recorrido = hasta - desde
	if recorrido.Magnitude < 0.5 then
		return true
	end
	return deslizar(b, CFrame.lookAt(hasta, hasta + recorrido.Unit, arriba), recorrido.Magnitude / T.PorTejado, true)
end

local function esperarTejado(b: Caza.Bicho, segundos: number): boolean
	local hasta = os.clock() + segundos
	while os.clock() < hasta do
		if not b.modelo or b.prisa or Chimenea.encendida() then
			return false
		end
		task.wait(0.1)
	end
	return true
end

local function ataque(a: Ataque, noche: number, paciencia: number)
	local lado = if azar:NextNumber() < 0.5 then 1 else -1
	local fuera = Vector3.new(0, 0, lado)
	-- Detrás, el cobertizo del generador ocupa de x = 3 a 13: por ahí no.
	local x = if lado > 0 then azar:NextNumber(-20, -1) else azar:NextNumber(-18, 18)
	local pie = Vector3.new(x, 0, lado * (PARED + 4))
	local inicio = pie + fuera * 70 + Vector3.xAxis * azar:NextNumber(-25, 25)
	local lejos = pie + fuera * 110 + Vector3.xAxis * azar:NextNumber(-40, 40)
	local alto = Vector3.new(0, ALTURA, 0)
	local b = crear(CFrame.lookAt(inicio + alto, pie + alto))
	a.bicho = b
	b.prisa = a.prisa
	local modelo = b.modelo :: Model

	-- Llega desde el bosque; si ve a alguien fuera, va a por él.
	b:irA(pie, T.Andar, 35, function()
		return not b.prisa and b:elegirPresa(true) == nil
	end)
	if b.prisa or b:elegirPresa(true) then
		if not b.prisa then
			b:cazar(T.Caza / 2, true)
		end
		b:irA(lejos, T.Andar, 25)
		return
	end

	-- Trepa por la pared: la tripa contra la pared, la cabeza hacia arriba.
	b.raiz.Anchored = true
	modelo:SetAttribute("Trepando", true)
	local pared = lado * (PARED + 1.4)
	local quemado = false
	local seguir = deslizar(b, CFrame.lookAt(Vector3.new(x, 3, pared), Vector3.new(x, 4, pared), fuera), 0.35)
		and deslizar(b, CFrame.lookAt(Vector3.new(x, 25.5, pared), Vector3.new(x, 26.5, pared), fuera), T.Subir)
	modelo:SetAttribute("Trepando", nil)

	-- Al tejado: rodea el alero y ronda un rato por su faldón, a veces quieto (el silencio también asusta).
	if seguir then
		local p, arriba = sobreTejado(x, lado * 21.5)
		seguir = deslizar(b, CFrame.lookAt(p, p - fuera * 2, arriba), 0.6)
	end
	if seguir then
		modelo:SetAttribute("EnTejado", true)
		avisarDentro("Something is walking on the roof.")
		local hasta = os.clock() + math.max(T.TejadoMin, rango(T.Tejado) - T.MenosPorNoche * math.max(0, noche - T.Noche)) * paciencia
		while seguir and os.clock() < hasta do
			seguir = andarTejado(b, azar:NextNumber(-22, 22), lado * azar:NextNumber(5, 20))
			if seguir and azar:NextNumber() < 0.45 then
				seguir = esperarTejado(b, azar:NextNumber(1, 3))
			end
		end
		-- Hasta la chimenea, se sube al tiro y se mete dentro.
		seguir = seguir and andarTejado(b, -20.5, lado * 3.5)
		local tiro = Chimenea.tiro()
		if seguir then
			seguir = deslizar(b, CFrame.lookAt(tiro + Vector3.new(0, 1.5, 0), tiro + Vector3.new(0, -5, 0), Vector3.xAxis), 0.7, true)
		end
		modelo:SetAttribute("EnTejado", nil)
		if seguir then
			modelo:SetAttribute("Bajando", true)
			Remotes.Trepador:FireAllClients("Baja", modelo)
			avisarDentro("Something is coming down the chimney!")
			local abajo = Vector3.new(tiro.X, 4, tiro.Z)
			seguir = deslizar(b, CFrame.lookAt(abajo, abajo - Vector3.yAxis * 5, Vector3.xAxis), T.Bajar, true)
			modelo:SetAttribute("Bajando", nil)
		end
		quemado = not seguir and not b.prisa and b.modelo ~= nil and Chimenea.encendida()
	end

	if quemado or b.prisa or not seguir then
		-- Quemado (o amanece): chilla, vuelve arriba si estaba dentro, se tira del tejado y huye.
		if quemado then
			Remotes.Trepador:FireAllClients("Quema", modelo)
		end
		local tiro = Chimenea.tiro()
		if b.raiz.Position.Y < tiro.Y - 1 and math.abs(b.raiz.Position.X - tiro.X) < 2 then
			b.raiz.CFrame = CFrame.lookAt(tiro + Vector3.new(0, 1.5, 0), tiro + Vector3.new(0, 6, 0), Vector3.xAxis)
		end
		if b.raiz.Position.Y > 6 then
			task.wait(0.8)
			local p, arriba = sobreTejado(b.raiz.Position.X, lado * 23)
			b.raiz.CFrame = CFrame.lookAt(p, p + fuera, arriba)
			task.wait(0.25)
		end
		local suelo = Vector3.new(b.raiz.Position.X, ALTURA, lado * (PARED + 4))
		b.raiz.CFrame = CFrame.lookAt(suelo, suelo + fuera)
		b.raiz.Anchored = false
		b:irA(lejos, if quemado then T.Huir else T.Andar, 25)
		return
	end

	-- Sale al salón por el hogar entre hollín, ruge y caza.
	local salida = Chimenea.salida()
	b.raiz.CFrame = salida + alto
	b.raiz.Anchored = false
	Remotes.Trepador:FireAllClients("Entra", modelo)
	task.wait(T.Grito)
	b:cazar(T.Caza, false)
	-- Se vuelve a meter por la chimenea.
	b:irA(salida.Position, T.Andar, 25)
	if b.modelo then
		Remotes.Trepador:FireAllClients("Baja", modelo)
	end
end

local function terminar(a: Ataque)
	ataques[a] = nil
	if a.bicho then
		a.bicho:quitar()
		a.bicho = nil
	end
end

-- Empieza un ataque (por la chimenea) y devuelve una función que dice si sigue en marcha.
-- `paciencia` multiplica lo que ronda por el tejado (tabla de dificultad).
function Trepador.atacar(noche: number, paciencia: number?): () -> boolean
	local a: Ataque = { bicho = nil, hilo = nil, prisa = false }
	ataques[a] = true
	a.hilo = task.spawn(function()
		ataque(a, noche, paciencia or 1)
		terminar(a)
	end)
	return function()
		return ataques[a] == true
	end
end

function Trepador.irse()
	for a in ataques do
		a.prisa = true
		if a.bicho then
			a.bicho.prisa = true
		end
	end
end

function Trepador.quitar()
	for a in ataques do
		if a.hilo and coroutine.status(a.hilo) ~= "dead" then
			task.cancel(a.hilo)
		end
		terminar(a)
	end
end

function Trepador.cuantos(): number
	local n = 0
	for _ in ataques do
		n += 1
	end
	return n
end

return Trepador
