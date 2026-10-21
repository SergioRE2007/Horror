-- El Golpeador: sale del bosque, se planta delante de una ventana o de la puerta y golpea.
--   Persiana bajada o puerta cerrada: le quita vida hasta cansarse (o romperla). Cristal al descubierto: lo agrieta
--   y al romperlo entra. Si le abren mientras golpea, entra (reglas en shared/Defensa).
--   Dentro ruge unos segundos (tiempo para esconderse) y caza (lo común, en Caza): persigue a quien ve, va a donde le
--   vio por última vez y si no, ronda por las salas. Si te vio esconderte, te saca. Luego se va por donde entró.
--   Fuera, de noche, persigue a quien vea en el bosque. El flash le aturde un momento.
-- Puede haber varios a la vez (tabla de dificultad). Es un Humanoid del servidor (se mueve suave en los clientes); el
-- cliente le anima las piernas y brazos (GolpeadorVista) y oye los golpes con el remote Golpeador.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Casa = require(script.Parent.Casa)
local Caza = require(script.Parent.Caza)
local Cuerpo = require(script.Parent.Cuerpo)

local Golpeador = {}

local G = Config.Golpeador
local ALTURA = 5 -- de los pies al centro de la raíz
local azar = Random.new()
local plano = Caza.plano

type Ataque = { bicho: Caza.Bicho?, objetivo: Model?, hilo: thread?, prisa: boolean }
local ataques: { [Ataque]: boolean } = {}

local function rango(r: { number }): number
	return azar:NextNumber(r[1], r[2])
end

-- Piel gris y fría, como de muerto, un poco brillante (mojada).
local PIEL, OSCURA, SANGRE = Color3.fromRGB(84, 82, 80), Color3.fromRGB(40, 37, 36), Color3.fromRGB(70, 6, 6)

local function crear(cf: CFrame): Caza.Bicho
	local m, raiz = Cuerpo.nuevo("Golpeador", cf)
	local function miembro(...)
		return Cuerpo.miembro(m, ...)
	end
	local function pegar(...)
		Cuerpo.pegar(m, ...)
	end

	-- Flaco y encorvado (el torso se inclina hacia delante desde la cadera), cabeza alargada colgando, mandíbula
	-- abierta con dientes, ojos hundidos con un punto claro, costillas y espinazo marcados, brazos larguísimos con
	-- garras y sangre en la boca, el pecho y las garras. Provisional hasta el modelo de verdad.
	local torso = miembro("Torso", Vector3.new(2.3, 3.8, 1.3), raiz, CFrame.new(0, -0.8, 0) * CFrame.Angles(-0.4, 0, 0), CFrame.new(0, -1.9, 0), PIEL)
	for i = 0, 3 do
		pegar(torso, Vector3.new(2.0 - i * 0.15, 0.18, 0.2), CFrame.new(0, 0.1 + i * 0.42, -0.66), OSCURA)
		pegar(torso, Vector3.new(0.35, 0.3, 0.3), CFrame.new(0, 0.2 + i * 0.5, 0.66), PIEL)
	end
	pegar(torso, Vector3.new(0.55, 1.6, 0.1), CFrame.new(0.15, 0.9, -0.7), SANGRE, Enum.Material.SmoothPlastic)

	local cabeza = miembro("Cabeza", Vector3.new(1.3, 1.8, 1.4), torso, CFrame.new(0, 1.9, -0.2) * CFrame.Angles(0.15, 0, 0), CFrame.new(0, -0.6, 0.4), PIEL)
	-- Ojos: cuencas negras hundidas, una más alta que otra, con un puntito claro al fondo.
	for i, x in { -0.32, 0.3 } do
		local y = if i == 1 then 0.38 else 0.31
		pegar(cabeza, Vector3.new(0.42, 0.36, 0.1), CFrame.new(x, y, -0.67) * CFrame.Angles(0, 0, (i - 1.5) * 0.3), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
		pegar(cabeza, Vector3.new(0.06, 0.06, 0.05), CFrame.new(x, y, -0.73), Color3.fromRGB(165, 155, 135), Enum.Material.Neon)
	end
	-- Dientes amarillentos, desiguales y torcidos, arriba y abajo.
	local diente = Color3.fromRGB(176, 162, 124)
	local function dientes(padre: BasePart, y: number, z: number, hacia: number)
		for i = -2, 2 do
			local largo = azar:NextNumber(0.2, 0.4)
			pegar(padre, Vector3.new(0.1, largo, 0.08), CFrame.new(i * 0.19 + azar:NextNumber(-0.03, 0.03), y + hacia * largo / 2, z)
				* CFrame.Angles(0, 0, azar:NextNumber(-0.25, 0.25)), diente, Enum.Material.SmoothPlastic)
		end
	end
	pegar(cabeza, Vector3.new(0.95, 0.5, 0.1), CFrame.new(0, -0.45, -0.67), Color3.fromRGB(25, 0, 0), Enum.Material.SmoothPlastic)
	dientes(cabeza, -0.2, -0.72, -1)
	local mandibula = miembro("Mandibula", Vector3.new(1.1, 0.35, 1.2), cabeza, CFrame.new(0, -0.8, 0.5), CFrame.new(0, 0, 0.6), PIEL)
	dientes(mandibula, 0.15, -0.52, 1)
	-- Sangre que le chorrea de las comisuras y la barbilla.
	for _, x in { -0.42, 0.1, 0.38 } do
		local largo = azar:NextNumber(0.4, 0.9)
		pegar(mandibula, Vector3.new(0.09, largo, 0.05), CFrame.new(x, 0.1 - largo / 2, -0.61), SANGRE, Enum.Material.SmoothPlastic)
	end

	for _, lado in { -1, 1 } do
		local brazo = miembro(if lado < 0 then "BrazoI" else "BrazoD", Vector3.new(0.45, 6.4, 0.45), torso, CFrame.new(lado * 1.35, 1.6, 0) * CFrame.Angles(0.4, 0, 0), CFrame.new(0, 3.0, 0), PIEL)
		for i = -1, 1 do
			pegar(brazo, Vector3.new(0.12, 1.3, 0.12), CFrame.new(i * 0.18, -3.75, -0.1) * CFrame.Angles(0.35, 0, 0), Color3.fromRGB(40, 12, 10), Enum.Material.SmoothPlastic)
		end
	end
	for _, lado in { -1, 1 } do
		miembro(if lado < 0 then "PiernaI" else "PiernaD", Vector3.new(0.7, 4.2, 0.7), raiz, CFrame.new(lado * 0.6, -0.9, 0), CFrame.new(0, 2.0, 0), OSCURA)
	end

	local humanoide = Cuerpo.terminar(m, Caza.carpeta(), ALTURA, G.Andar)
	return Caza.nuevo(m, humanoide, {
		Altura = ALTURA,
		Andar = G.Andar,
		Correr = G.Correr,
		Pillar = G.Pillar,
		Vista = G.Vista,
		VioEsconderse = G.VioEsconderse,
	})
end

local function ataque(a: Ataque, el: Model, noche: number, paciencia: number)
	local centro = el:GetAttribute("Centro") :: CFrame
	local fuera = el:GetAttribute("Fuera") :: Vector3
	local dentro = el:GetAttribute("Dentro") :: Vector3
	local normal = plano(centro.LookVector).Unit
	local lado = normal:Cross(Vector3.yAxis)
	local inicio = fuera + normal * 75 + lado * azar:NextNumber(-25, 25)
	local lejos = fuera + normal * 110 + lado * azar:NextNumber(-40, 40)
	local b = crear(CFrame.lookAt(inicio + Vector3.new(0, ALTURA, 0), fuera + Vector3.new(0, ALTURA, 0)))
	a.bicho = b
	b.prisa = a.prisa
	local function noVeNadie()
		return not b.prisa and b:elegirPresa(true) == nil
	end

	-- Llega desde el bosque; si ve a alguien fuera, va a por él.
	b:irA(fuera, G.Andar, 30, noVeNadie)
	if not b.prisa and b:elegirPresa(true) then
		b:cazar(G.Caza / 2, true)
		b:irA(lejos, G.Andar, 25)
		return
	end

	-- Golpea hasta cansarse o hasta entrar.
	a.objetivo = el
	Casa.empezarAtaque(el)
	b.humanoide.AutoRotate = false
	b:mirarA(centro.Position)
	local finPaciencia = os.clock() + (rango(G.Paciencia) + G.MasPaciencia * (noche - 1)) * paciencia
	local entra = false
	while os.clock() < finPaciencia and not b.prisa do
		task.wait(rango(G.CadaGolpe))
		if b.prisa then
			break
		end
		if b:quieto() then
			continue -- aturdido por un flash: deja de golpear un momento
		end
		Remotes.Golpeador:FireAllClients("Golpe", el)
		task.wait(0.35) -- el brazo baja: el golpe suena al llegar
		if Casa.golpe(el, rango(G.Dano)) == "Entra" then
			entra = true
			break
		end
	end
	Casa.terminarAtaque(el)
	a.objetivo = nil
	b.humanoide.AutoRotate = true

	if entra then
		Casa.romper(el)
		Remotes.Golpeador:FireAllClients("Entra", el)
		task.wait(0.6)
		local pie = dentro + Vector3.new(0, ALTURA, 0)
		if b.modelo then
			b.modelo:PivotTo(CFrame.lookAt(pie, pie - normal))
		end
		task.wait(G.Grito)
		b:cazar(G.Caza, false)
		-- Se va por donde entró.
		b:irA(dentro, G.Andar, 25)
		local pieFuera = fuera + Vector3.new(0, ALTURA, 0)
		if b.modelo then
			b.modelo:PivotTo(CFrame.lookAt(pieFuera, pieFuera + normal))
		end
	end
	b:irA(lejos, G.Andar, 25)
end

local function terminar(a: Ataque)
	ataques[a] = nil
	if a.objetivo then
		Casa.terminarAtaque(a.objetivo)
		a.objetivo = nil
	end
	if a.bicho then
		a.bicho:quitar()
		a.bicho = nil
	end
end

-- Empieza un ataque a esa ventana o puerta y devuelve una función que dice si sigue en marcha.
-- `paciencia` multiplica lo que aguanta golpeando (tabla de dificultad).
function Golpeador.atacar(el: Model, noche: number, paciencia: number?): () -> boolean
	local a: Ataque = { bicho = nil, objetivo = nil, hilo = nil, prisa = false }
	ataques[a] = true
	a.hilo = task.spawn(function()
		ataque(a, el, noche, paciencia or 1)
		terminar(a)
	end)
	return function()
		return ataques[a] == true
	end
end

-- Amanece: dejan de golpear o cazar y se van andando.
function Golpeador.irse()
	for a in ataques do
		a.prisa = true
		if a.bicho then
			a.bicho.prisa = true
		end
	end
end

-- Los quita del mapa al momento (al volver a empezar el día).
function Golpeador.quitar()
	for a in ataques do
		if a.hilo and coroutine.status(a.hilo) ~= "dead" then
			task.cancel(a.hilo)
		end
		terminar(a)
	end
end

function Golpeador.start()
	Caza.carpeta()
end

return Golpeador
