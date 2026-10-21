-- El Raspador (pedido por el usuario; desde la noche Config.Raspador.Noche): sale del bosque, se pega a una ventana y
-- raspa el cristal despacio con sus dedos larguísimos. La persiana no le para: si termina de raspar, rompe lo que haya
-- y entra. No soporta la luz: con una linterna encima raspa mucho más lento, y un flashazo le hace chillar y huir. Pero
-- el flash no pasa la persiana bajada: hay que subirla (y con el Golpeador rondando, eso da miedo).
-- Dentro ruge y caza como el Golpeador, más lento; un flash también le echa.
-- Atributos del modelo para el cliente (RaspadorVista): Raspado (0..1), Raspando, Iluminado, Huye.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Casa = require(script.Parent.Casa)
local Caza = require(script.Parent.Caza)
local Cuerpo = require(script.Parent.Cuerpo)

local Raspador = {}

local R = Config.Raspador
local ALTURA = 4.2
local azar = Random.new()
local plano = Caza.plano

type Ataque = { bicho: Caza.Bicho?, hilo: thread?, prisa: boolean }
local ataques: { [Ataque]: boolean } = {}

local function rango(r: { number }): number
	return azar:NextNumber(r[1], r[2])
end

-- Pálido, casi blanco amarillento, como algo que nunca ve el sol; boca negra y sangre seca en las uñas.
local PIEL, VENAS, BOCA, SANGRE = Color3.fromRGB(150, 146, 134), Color3.fromRGB(96, 104, 112), Color3.fromRGB(18, 6, 6), Color3.fromRGB(70, 6, 6)

local function crear(cf: CFrame): Caza.Bicho
	local m, raiz = Cuerpo.nuevo("Raspador", cf)
	local function miembro(...)
		return Cuerpo.miembro(m, ...)
	end
	local function pegar(...)
		Cuerpo.pegar(m, ...)
	end

	-- Altísimo y en los huesos, el cuello estirado hacia delante, cabeza lisa sin ojos con una boca ancha de oreja a
	-- oreja, brazos que le llegan a los pies y dedos como agujas. Provisional hasta el modelo de verdad.
	local torso = miembro("Torso", Vector3.new(1.7, 3.6, 0.9), raiz, CFrame.new(0, -0.6, 0) * CFrame.Angles(-0.2, 0, 0), CFrame.new(0, -1.8, 0), PIEL)
	for i = 0, 4 do
		pegar(torso, Vector3.new(1.5 - i * 0.12, 0.12, 0.12), CFrame.new(0, 0.2 + i * 0.32, -0.46), VENAS)
	end
	pegar(torso, Vector3.new(0.12, 2.6, 0.1), CFrame.new(-0.35, 0.2, -0.47) * CFrame.Angles(0, 0, 0.12), VENAS) -- una vena gorda
	local cuello = miembro("Cuello", Vector3.new(0.45, 1.6, 0.45), torso, CFrame.new(0, 1.8, -0.1) * CFrame.Angles(-0.7, 0, 0), CFrame.new(0, -0.8, 0), PIEL)
	local cabeza = miembro("Cabeza", Vector3.new(1.1, 1.5, 1.2), cuello, CFrame.new(0, 0.8, 0) * CFrame.Angles(0.7, 0, 0), CFrame.new(0, -0.5, 0.2), PIEL)
	-- Sin ojos: solo dos hundidos de piel más oscura. La boca, una raja negra con dientes finos.
	for _, x in { -0.27, 0.27 } do
		pegar(cabeza, Vector3.new(0.32, 0.16, 0.06), CFrame.new(x, 0.3, -0.6), VENAS)
	end
	pegar(cabeza, Vector3.new(1.0, 0.32, 0.08), CFrame.new(0, -0.3, -0.6), BOCA)
	for i = -4, 4 do
		pegar(cabeza, Vector3.new(0.05, azar:NextNumber(0.12, 0.22), 0.05), CFrame.new(i * 0.1, -0.2, -0.64), Color3.fromRGB(190, 182, 160))
	end
	local mandibula = miembro("Mandibula", Vector3.new(1.0, 0.3, 1.1), cabeza, CFrame.new(0, -0.6, 0.45), CFrame.new(0, 0, 0.55), PIEL)
	pegar(mandibula, Vector3.new(0.1, 0.6, 0.05), CFrame.new(0.2, -0.2, -0.56), SANGRE)

	for _, lado in { -1, 1 } do
		local letra = if lado < 0 then "I" else "D"
		local brazo = miembro("Brazo" .. letra, Vector3.new(0.32, 2.8, 0.32), torso, CFrame.new(lado * 1.0, 1.6, 0), CFrame.new(0, 1.3, 0), PIEL)
		local antebrazo = miembro("Antebrazo" .. letra, Vector3.new(0.26, 2.8, 0.26), brazo, CFrame.new(0, -1.35, 0), CFrame.new(0, 1.3, 0), PIEL)
		-- Cuatro dedos largos como agujas, con la punta oscura de sangre.
		for i = 0, 3 do
			local x = (i - 1.5) * 0.09
			pegar(antebrazo, Vector3.new(0.06, 1.6, 0.06), CFrame.new(x, -2.1, -0.05) * CFrame.Angles(0.15, 0, (i - 1.5) * 0.08), PIEL)
			pegar(antebrazo, Vector3.new(0.07, 0.3, 0.07), CFrame.new(x * 1.3, -2.85, -0.17), SANGRE)
		end
	end
	for _, lado in { -1, 1 } do
		miembro(if lado < 0 then "PiernaI" else "PiernaD", Vector3.new(0.45, 4.0, 0.45), raiz, CFrame.new(lado * 0.45, -0.6, 0), CFrame.new(0, 2.0, 0), PIEL)
	end

	local humanoide = Cuerpo.terminar(m, Caza.carpeta(), ALTURA, R.Andar)
	return Caza.nuevo(m, humanoide, {
		Altura = ALTURA,
		Andar = R.Andar,
		Correr = R.Correr,
		Pillar = R.Pillar,
		Vista = R.Vista,
		VioEsconderse = R.VioEsconderse,
	})
end

-- ¿Le da una linterna ahora? (Equipo lo apunta cada poco.)
local function iluminado(b: Caza.Bicho): boolean
	return os.clock() - b.iluminado < 0.6
end

local function ataque(a: Ataque, el: Model, noche: number, paciencia: number)
	local centro = el:GetAttribute("Centro") :: CFrame
	local fuera = el:GetAttribute("Fuera") :: Vector3
	local dentro = el:GetAttribute("Dentro") :: Vector3
	local normal = plano(centro.LookVector).Unit
	local lado = normal:Cross(Vector3.yAxis)
	local pegado = fuera - normal * 1.2 -- casi contra la pared, la cara en el cristal
	local inicio = fuera + normal * 70 + lado * azar:NextNumber(-25, 25)
	local lejos = fuera + normal * 110 + lado * azar:NextNumber(-40, 40)
	local b = crear(CFrame.lookAt(inicio + Vector3.new(0, ALTURA, 0), fuera + Vector3.new(0, ALTURA, 0)))
	a.bicho = b
	b.prisa = a.prisa
	local modelo = b.modelo :: Model
	b.alFlash = function()
		if modelo:GetAttribute("Huye") then
			return
		end
		modelo:SetAttribute("Huye", true)
		modelo:SetAttribute("Raspando", false)
		b.prisa = true
		Remotes.Raspador:FireAllClients("Chilla", modelo)
	end

	-- Llega desde el bosque; si ve a alguien fuera, va a por él.
	b:irA(pegado, R.Andar, 35, function()
		return not b.prisa and b:elegirPresa(true) == nil
	end)
	if not b.prisa and b:elegirPresa(true) then
		b:cazar(R.Caza / 2, true)
		b:irA(lejos, if modelo:GetAttribute("Huye") then R.Huir else R.Andar, 25)
		return
	end

	-- Los últimos pasos hasta pegarse bien al cristal.
	local hasta = os.clock() + 2
	while not b.prisa and os.clock() < hasta and not b:cerca(pegado, 0.6) do
		b.humanoide:MoveTo(pegado)
		task.wait(0.1)
	end

	-- Raspa hasta entrar, salvo que le echen con el flash (o amanezca).
	b.ventana = el
	b.humanoide.AutoRotate = false
	b:mirarA(centro.Position)
	modelo:SetAttribute("Raspando", true)
	local total = math.max(R.RasparMin, rango(R.Raspar) - R.MenosPorNoche * math.max(0, noche - R.Noche)) * paciencia
	local hecho = 0
	local antes = os.clock()
	while hecho < 1 and not b.prisa do
		task.wait(0.25)
		local ahora = os.clock()
		local luz = iluminado(b)
		hecho = math.min(1, hecho + (ahora - antes) / total * (if luz then R.Frena else 1))
		antes = ahora
		modelo:SetAttribute("Raspado", hecho)
		modelo:SetAttribute("Iluminado", luz)
		Casa.agrietar(el, hecho)
	end
	modelo:SetAttribute("Raspando", false)
	b.ventana = nil
	b.humanoide.AutoRotate = true

	if not b.prisa then
		Casa.romper(el)
		Remotes.Raspador:FireAllClients("Entra", el)
		task.wait(0.6)
		local pie = dentro + Vector3.new(0, ALTURA, 0)
		modelo:PivotTo(CFrame.lookAt(pie, pie - normal))
		task.wait(R.Grito)
		b:cazar(R.Caza, false)
		-- Se va por donde entró (corriendo si le han dado con el flash).
		b:irA(dentro, if modelo:GetAttribute("Huye") then R.Huir else R.Andar, 25)
		local pieFuera = fuera + Vector3.new(0, ALTURA, 0)
		modelo:PivotTo(CFrame.lookAt(pieFuera, pieFuera + normal))
	end
	b:irA(lejos, if modelo:GetAttribute("Huye") then R.Huir else R.Andar, 25)
end

local function terminar(a: Ataque)
	ataques[a] = nil
	if a.bicho then
		a.bicho:quitar()
		a.bicho = nil
	end
end

-- Empieza un ataque a esa ventana y devuelve una función que dice si sigue en marcha.
-- `paciencia` multiplica lo que tarda en raspar (tabla de dificultad).
function Raspador.atacar(el: Model, noche: number, paciencia: number?): () -> boolean
	local a: Ataque = { bicho = nil, hilo = nil, prisa = false }
	ataques[a] = true
	a.hilo = task.spawn(function()
		ataque(a, el, noche, paciencia or 1)
		terminar(a)
	end)
	return function()
		return ataques[a] == true
	end
end

function Raspador.irse()
	for a in ataques do
		a.prisa = true
		if a.bicho then
			a.bicho.prisa = true
		end
	end
end

function Raspador.quitar()
	for a in ataques do
		if a.hilo and coroutine.status(a.hilo) ~= "dead" then
			task.cancel(a.hilo)
		end
		terminar(a)
	end
end

-- ¿Cuántos hay ahora en el mapa?
function Raspador.cuantos(): number
	local n = 0
	for _ in ataques do
		n += 1
	end
	return n
end

return Raspador
