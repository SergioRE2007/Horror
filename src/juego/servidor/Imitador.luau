-- El Imitador (desde la noche Config.Imitador.Noche): se planta en la puerta principal y llama con la voz de uno de
-- vosotros ("soy Sergio, abre"). Hay que mirar en el móvil si ese amigo está fuera de verdad. Si alguien abre la puerta
-- mientras está ahí (o se la encuentra abierta), entra: ruge y caza como el Golpeador. Si nadie abre, se cansa y se va.
-- A quien sale a mirar, le caza. La primera noche que sale, al primer golpe en la puerta se va la luz (Generador).
-- De lejos y a oscuras parece una persona; al entrar se le estira el cuello y abre la boca (ImitadorVista).
-- Atributo del modelo para el cliente: Abierto (le han abierto y entra).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Casa = require(script.Parent.Casa)
local Caza = require(script.Parent.Caza)
local Cuerpo = require(script.Parent.Cuerpo)
local Generador = require(script.Parent.Generador)
local Muerte = require(script.Parent.Muerte)

local Imitador = {}

local I = Config.Imitador
local ALTURA = 5
local azar = Random.new()
local plano = Caza.plano

-- Lo que dice en cada llamada ({name}: el amigo al que imita). Al que imita, la primera le dice que es su voz.
local FRASES = {
	"Knock knock. \"It's {name}. Let me in!\"",
	"\"Please, it's so cold out here. It's me, {name}.\"",
	"\"Hurry! Something is coming! Open the door!\"",
	"\"Why won't you open the door?\"",
}
local SU_VOZ = "Someone at the door is talking with your voice."
local ULTIMA = "\"I know you're in there.\""

type Ataque = { bicho: Caza.Bicho?, hilo: thread?, prisa: boolean }
local ataques: { [Ataque]: boolean } = {}

local function rango(r: { number }): number
	return azar:NextNumber(r[1], r[2])
end

-- Ropa oscura y piel de cera; la cara, una sonrisa demasiado ancha llena de dientes.
local ROPA, OSCURA, PIEL, SANGRE = Color3.fromRGB(38, 36, 35), Color3.fromRGB(24, 22, 22), Color3.fromRGB(158, 150, 140),
	Color3.fromRGB(70, 6, 6)

local function crear(cf: CFrame): Caza.Bicho
	local m, raiz = Cuerpo.nuevo("Imitador", cf)
	local function miembro(...)
		return Cuerpo.miembro(m, ...)
	end
	local function pegar(...)
		Cuerpo.pegar(m, ...)
	end

	-- De la talla de una persona: abrigo largo, brazos algo largos, manos grises. Provisional hasta el modelo de verdad.
	local torso = miembro("Torso", Vector3.new(2, 3, 1), raiz, CFrame.new(0, -0.2, 0), CFrame.new(0, -1.5, 0), ROPA)
	pegar(torso, Vector3.new(2.1, 1.4, 1.1), CFrame.new(0, -1.6, 0), ROPA) -- faldón del abrigo
	pegar(torso, Vector3.new(0.4, 1.2, 0.1), CFrame.new(-0.4, 0.4, -0.52), SANGRE) -- una mancha que no es suya
	local cuello = miembro("Cuello", Vector3.new(0.5, 0.8, 0.5), torso, CFrame.new(0, 1.5, 0), CFrame.new(0, -0.4, 0), PIEL)
	local cabeza = miembro("Cabeza", Vector3.new(1.15, 1.3, 1.2), cuello, CFrame.new(0, 0.4, 0), CFrame.new(0, -0.6, 0), PIEL)
	pegar(cabeza, Vector3.new(1.2, 0.35, 1.25), CFrame.new(0, 0.55, 0.05), OSCURA) -- pelo
	-- Ojos negros y pequeños, demasiado separados; la sonrisa de oreja a oreja con los dientes apretados.
	for _, xo in { -0.38, 0.38 } do
		pegar(cabeza, Vector3.new(0.16, 0.12, 0.05), CFrame.new(xo, 0.18, -0.61), Color3.new(0, 0, 0))
	end
	pegar(cabeza, Vector3.new(1.1, 0.26, 0.06), CFrame.new(0, -0.25, -0.61) * CFrame.Angles(0, 0, 0), Color3.fromRGB(20, 0, 0))
	for i = -6, 6 do
		pegar(cabeza, Vector3.new(0.06, 0.18, 0.05), CFrame.new(i * 0.08, -0.25 + math.abs(i) * 0.012, -0.64), Color3.fromRGB(205, 196, 170))
	end
	local mandibula = miembro("Mandibula", Vector3.new(1.05, 0.3, 1.1), cabeza, CFrame.new(0, -0.6, 0.5), CFrame.new(0, 0, 0.55), PIEL)
	pegar(mandibula, Vector3.new(0.08, 0.5, 0.05), CFrame.new(0.3, 0, -0.56), SANGRE)

	for _, lado in { -1, 1 } do
		local brazo = miembro(if lado < 0 then "BrazoI" else "BrazoD", Vector3.new(0.5, 3.8, 0.5), torso,
			CFrame.new(lado * 1.25, 1.3, 0), CFrame.new(0, 1.8, 0), ROPA)
		for i = -1, 1 do
			pegar(brazo, Vector3.new(0.09, 0.8, 0.09), CFrame.new(i * 0.13, -2.25, 0), PIEL) -- dedos largos
		end
	end
	for _, lado in { -1, 1 } do
		miembro(if lado < 0 then "PiernaI" else "PiernaD", Vector3.new(0.75, 4.4, 0.75), raiz, CFrame.new(lado * 0.5, -1.1, 0),
			CFrame.new(0, 2.0, 0), OSCURA)
	end

	local humanoide = Cuerpo.terminar(m, Caza.carpeta(), ALTURA, I.Andar)
	return Caza.nuevo(m, humanoide, {
		Altura = ALTURA,
		Andar = I.Andar,
		Correr = I.Correr,
		Pillar = I.Pillar,
		Vista = I.Vista,
		VioEsconderse = I.VioEsconderse,
	})
end

-- A quién imita: a uno de los que no están junto a la puerta (si estás solo, a ti).
local function elegirAmigo(puerta: Vector3): Player?
	local lista = {}
	for _, jugador in Muerte.vivos() do
		local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if raiz and (raiz.Position - puerta).Magnitude > 25 then
			table.insert(lista, jugador)
		end
	end
	if #lista == 0 then
		lista = Players:GetPlayers()
	end
	return if #lista > 0 then lista[azar:NextInteger(1, #lista)] else nil
end

-- Lo que dice, a los que le oyen (cerca de la puerta).
local function decir(puerta: Vector3, frase: string, amigo: Player?)
	for _, jugador in Players:GetPlayers() do
		local raiz = jugador.Character and jugador.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if raiz and (raiz.Position - puerta).Magnitude <= I.Oido then
			local texto = if jugador == amigo and frase == FRASES[1] then SU_VOZ else frase
			Remotes.Aviso:FireClient(jugador, Lang.t(jugador, texto, { name = if amigo then amigo.DisplayName else "" }))
		end
	end
end

-- ¿Hay alguien fuera muy cerca de él? (si sale alguien a mirar, va a por él)
local function alguienCerca(b: Caza.Bicho): boolean
	local presa, destino = b:elegirPresa(true)
	return presa ~= nil and destino ~= nil and (destino - b:suelo()).Magnitude < 22
end

local function ataque(a: Ataque, el: Model, _noche: number, paciencia: number, apagon: boolean)
	local centro = el:GetAttribute("Centro") :: CFrame
	local fuera = el:GetAttribute("Fuera") :: Vector3
	local dentro = el:GetAttribute("Dentro") :: Vector3
	local normal = plano(centro.LookVector).Unit
	local lado = normal:Cross(Vector3.yAxis)
	local inicio = fuera + normal * 75 + lado * azar:NextNumber(-25, 25)
	local lejos = fuera + normal * 110 + lado * azar:NextNumber(-40, 40)
	local delante = Vector3.new(centro.X, fuera.Y, centro.Z) + normal * 2.5 -- pegado a la puerta, esperando a que le abran
	local b = crear(CFrame.lookAt(inicio + Vector3.new(0, ALTURA, 0), fuera + Vector3.new(0, ALTURA, 0)))
	a.bicho = b
	b.prisa = a.prisa
	local modelo = b.modelo :: Model

	b:irA(delante, I.Andar, 35, function()
		return not b.prisa and b:elegirPresa(true) == nil
	end)
	if b.prisa or b:elegirPresa(true) then
		if not b.prisa then
			b:cazar(I.Caza / 2, true)
		end
		b:irA(lejos, I.Andar, 25)
		return
	end
	b.humanoide.AutoRotate = false
	b:mirarA(centro.Position)

	-- Llama unas cuantas veces; entre llamada y llamada, si alguien abre, entra.
	local amigo = elegirAmigo(centro.Position)
	local abierta = Casa.estado(el).abierta
	local salio = false
	for i = 1, I.Llamadas do
		if abierta or b.prisa then
			break
		end
		Remotes.Imitador:FireAllClients("Llama", modelo)
		decir(centro.Position, FRASES[math.min(i, #FRASES)], amigo)
		if i == 1 and apagon then
			-- Se va la luz justo al llamar (solo si estaba encendida).
			task.delay(1.5, function()
				if Generador.apagon() then
					for _, jugador in Players:GetPlayers() do
						Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "The lights went out."))
					end
				end
			end)
		end
		local hasta = os.clock() + rango(I.CadaLlamada) * paciencia
		while os.clock() < hasta and not b.prisa do
			task.wait(0.2)
			if Casa.estado(el).abierta then
				abierta = true
				break
			elseif alguienCerca(b) then
				salio = true
				break
			end
		end
		if salio then
			break
		end
	end
	b.humanoide.AutoRotate = true

	if salio then
		b:cazar(I.Caza / 2, true)
	elseif abierta and not b.prisa then
		-- Le han abierto: se le estira la cara, entra y caza.
		modelo:SetAttribute("Abierto", true)
		Remotes.Imitador:FireAllClients("Entra", modelo)
		task.wait(0.5)
		local pie = dentro + Vector3.new(0, ALTURA, 0)
		modelo:PivotTo(CFrame.lookAt(pie, pie - normal))
		task.wait(I.Grito)
		b:cazar(I.Caza, false)
		b:irA(dentro, I.Andar, 25)
		local pieFuera = fuera + Vector3.new(0, ALTURA, 0)
		if b.modelo then
			b.modelo:PivotTo(CFrame.lookAt(pieFuera, pieFuera + normal))
		end
	elseif not b.prisa then
		decir(centro.Position, ULTIMA, amigo)
	end
	b:irA(lejos, I.Andar, 25)
end

local function terminar(a: Ataque)
	ataques[a] = nil
	if a.bicho then
		a.bicho:quitar()
		a.bicho = nil
	end
end

-- Empieza un ataque a la puerta `el` y devuelve una función que dice si sigue en marcha. `paciencia` multiplica lo
-- que espera entre llamadas; `apagon`: al primer golpe se va la luz.
function Imitador.atacar(el: Model, noche: number, paciencia: number?, apagon: boolean?): () -> boolean
	local a: Ataque = { bicho = nil, hilo = nil, prisa = false }
	ataques[a] = true
	a.hilo = task.spawn(function()
		ataque(a, el, noche, paciencia or 1, apagon == true)
		terminar(a)
	end)
	return function()
		return ataques[a] == true
	end
end

function Imitador.irse()
	for a in ataques do
		a.prisa = true
		if a.bicho then
			a.bicho.prisa = true
		end
	end
end

function Imitador.quitar()
	for a in ataques do
		if a.hilo and coroutine.status(a.hilo) ~= "dead" then
			task.cancel(a.hilo)
		end
		terminar(a)
	end
end

function Imitador.cuantos(): number
	local n = 0
	for _ in ataques do
		n += 1
	end
	return n
end

return Imitador
