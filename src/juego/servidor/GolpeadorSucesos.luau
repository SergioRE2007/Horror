-- Los sucesos al azar del Golpeador (14.10, pedido por el usuario: "que no sea siempre igual"). El servidor decide y
-- lo pone en atributos de su modelo; el cliente (GolpeadorVista) lo anima. Nunca injustos: durante un suceso no pilla
-- (Caza.cazar espera a que acabe) y ninguno hace que pille a través de las paredes.
--   Atributos: SucesoHora (hora del servidor al empezar; se pone ANTES que Suceso), SucesoDura (s), SucesoMira
--   (Vector3: a dónde mira), SucesoLado (-1/1, solo Garras) y Suceso (el nombre). Vuelven a nil siempre al acabar:
--   también si falla, si amanece (prisa), si le aturden o si se quita.
--   Las tiradas (Config.Golpeador.Sucesos y "una vez por noche entre todos"), en GolpeadorTiradas.
--   Fuera (Golpeador.ataque llama a cara, llama y finge): Cara (la cara pegada al cristal; si le alumbras o le miras de
--   cerca un rato, "Aparta"), Llama (tres toques lentos antes de aporrear; si le abren mientras, entra) y Finge (se
--   cansa, se va, mira atrás y vuelve corriendo).
--   Dentro (enganchar: el gancho alCazar de Caza): Armario (te mira por las rendijas sin saber que estás), Olfatea (al
--   llegar a una sala), Garras (arrastra las garras por la pared al pasar; sigue andando) y Quieto (alumbrado de lejos:
--   no se mueve y luego va a por ti sabiendo dónde estás).
-- Modo de pruebas: ServerStorage.Prueba:Fire("Suceso", "Armario") (o con atributos: Punto = "Armario", Orden =
-- "Suceso") hace que la próxima ocasión de ese suceso salga seguro, aunque ya haya salido esa noche.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Prueba = require(ReplicatedStorage.Shared.Prueba)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Casa = require(script.Parent.Casa)
local Caza = require(script.Parent.Caza)
local Muerte = require(script.Parent.Muerte)
local Tiradas = require(script.Parent.GolpeadorTiradas)

local GolpeadorSucesos = {}

local G = Config.Golpeador
local C = G.Sucesos
GolpeadorSucesos.cfg = C
local azar = Random.new()
local tiradas = Tiradas.nueva(C, azar)
local plano = Caza.plano

-- A ojo (no están en Config: son de cómo se hace, no de equilibrio).
local PASO = 0.2 -- cada cuánto mira si sigue el suceso
local LUZ = 0.6 -- s desde que le dio una linterna para contar como alumbrado (como el Raspador)
local COS_MIRA = math.cos(math.rad(30)) -- le mira quien le tiene así de centrado (en 1.ª persona el cuerpo gira con la cámara)
local COS_LINTERNA = math.cos(math.rad(Config.Linterna.Angulo))
local APARTA = 0.6 -- s apartándose del cristal
local DELANTE = 4.65 -- del centro del armario a donde se para (la puerta a 1,35: ~3,3 delante; inclinado, la cara llega a las rendijas sin meterse)
local PUERTA = 1.35 -- del centro del armario a sus puertas de lamas
local LLEGAR = 6 -- s como mucho andando hasta delante del armario
local FINGE_LEJOS = 28 -- studs que se aleja antes de pararse a mirar atrás
local GARRAS_OTRA = 5 -- s sin volver a tirar Garras tras una ocasión
local QUIETO_OTRA = 6 -- s sin volver a tirar Quieto por el mismo jugador
local HOMBRO = 1 -- studs sobre la raíz: la altura del hombro

local function rango(r: { number }): number
	return azar:NextNumber(r[1], r[2])
end

local function cabezaDe(jugador: Player): BasePart?
	local personaje = jugador.Character
	return personaje and personaje:FindFirstChild("Head") :: BasePart?
end

local function raizDe(jugador: Player): BasePart?
	local personaje = jugador.Character
	return personaje and personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function alumbrado(b: Caza.Bicho): boolean
	return os.clock() - b.iluminado < LUZ
end

-- Rayos sin los bichos ni los personajes (y, si se da, sin `tambien`: la ventana, que el cristal no tape).
local filtro = RaycastParams.new()
filtro.FilterType = Enum.RaycastFilterType.Exclude
local function rayo(desde: Vector3, hacia: Vector3, tambien: Instance?): RaycastResult?
	local ignorar: { Instance } = { Caza.carpeta() }
	if tambien then
		table.insert(ignorar, tambien)
	end
	for _, j in Players:GetPlayers() do
		if j.Character then
			table.insert(ignorar, j.Character)
		end
	end
	filtro.FilterDescendantsInstances = ignorar
	return workspace:Raycast(desde, hacia, filtro)
end

local function poner(modelo: Model, nombre: string, dura: number, mira: Vector3, lado: number?)
	modelo:SetAttribute("SucesoHora", workspace:GetServerTimeNow()) -- primero la hora: quien se entera por Suceso ya la tiene
	modelo:SetAttribute("SucesoDura", dura)
	modelo:SetAttribute("SucesoMira", mira)
	modelo:SetAttribute("SucesoLado", lado)
	modelo:SetAttribute("Suceso", nombre)
end

local function quitarAtributos(modelo: Model)
	if modelo.Parent then -- quitado (Destroy), se van con él
		modelo:SetAttribute("Suceso", nil)
		modelo:SetAttribute("SucesoHora", nil)
		modelo:SetAttribute("SucesoDura", nil)
		modelo:SetAttribute("SucesoMira", nil)
		modelo:SetAttribute("SucesoLado", nil)
	end
end

-- Corre un suceso (`fn`) con el bicho quieto y sin girar solo. Pase lo que pase (también si falla), los atributos
-- vuelven a nil y AutoRotate como estaba. Devuelve lo que devuelva `fn` (nil si no hay modelo).
local function hacer(b: Caza.Bicho, fn: (Model) -> any): any
	local modelo = b.modelo
	if not modelo then
		return nil
	end
	local h = b.humanoide
	local giraba = h.AutoRotate
	local ok, r = pcall(function()
		h.AutoRotate = false
		h:MoveTo(b.raiz.Position)
		return fn(modelo)
	end)
	quitarAtributos(modelo)
	h.AutoRotate = giraba
	if not ok then
		error(r, 0)
	end
	return r
end

-- Espera `segundos` quieto. false si se corta antes: amanece, le aturden (flash), se quita o `corta()` dice que sí.
local function esperar(b: Caza.Bicho, segundos: number, corta: (() -> boolean)?): boolean
	local hasta = os.clock() + segundos
	while os.clock() < hasta do
		task.wait(math.clamp(hasta - os.clock(), 0, PASO))
		if not b.modelo or b.prisa or b:quieto() or (corta and corta()) then
			return false
		end
		b.humanoide:MoveTo(b.raiz.Position)
	end
	return true
end

-- Cara: de la raíz al cristal, a ras de suelo (studs, a ojo). Inclinado, así la cara llega al cristal.
local CARA_CRISTAL = 2.2
local ANDAR_RECTO = 2.5 -- s como mucho en arrimarse o volver

-- Anda recto hasta `punto` (a la altura de la raíz), sin camino: junto a la pared de fuera no hay nada en medio. Para
-- antes si amanece, le aturden o se quita.
local function andarRecto(b: Caza.Bicho, punto: Vector3)
	local hasta = os.clock() + ANDAR_RECTO
	b.humanoide.WalkSpeed = b.o.Andar
	while b.modelo and not b.prisa and not b:quieto() and os.clock() < hasta
		and plano(punto - b.raiz.Position).Magnitude > 0.5 do
		b.humanoide:MoveTo(punto - Vector3.new(0, b.o.Altura, 0))
		task.wait(PASO)
	end
	b.humanoide:MoveTo(b.raiz.Position)
end

-- ¿Le mira de cerca algún jugador desde dentro de la casa a través de esta ventana? (Hacia dónde mira cada uno: el
-- giro de su raíz, que en primera persona sigue a la cámara; como la linterna en Equipo.)
local function leMiran(b: Caza.Bicho, el: Model, centro: CFrame): boolean
	local suya = b:cabeza()
	for _, j in Players:GetPlayers() do
		if not Muerte.vivo(j) or Muerte.escondite(j) then
			continue
		end
		local cabeza, raiz = cabezaDe(j), raizDe(j)
		if not cabeza or not raiz then
			continue
		end
		local p = cabeza.Position
		if (p - centro.Position):Dot(centro.LookVector) >= 0 or (suya - p).Magnitude > C.Cara.Distancia then
			continue -- fuera de la casa o lejos
		end
		local a, hacia = plano(suya - p), plano(raiz.CFrame.LookVector)
		if a.Magnitude > 0.1 and hacia.Magnitude > 0.1 and a.Unit:Dot(hacia.Unit) >= COS_MIRA and not rayo(p, suya - p, el) then
			return true
		end
	end
	return false
end

-- Fuera ----------------------------------------------------------------------------------------------------------------

-- Cara: la ventana con el cristal entero y sin la cortina echada. Pega la cara al cristal `Dura` s; si le alumbras o le
-- mira alguien de dentro de cerca más de `Mirado` s, se aparta de golpe. Luego (o si echan la cortina) ataca normal.
-- true si lo ha hecho.
function GolpeadorSucesos.cara(b: Caza.Bicho, el: Model, noche: number): boolean
	local e = Casa.estado(el)
	if e.tipo ~= "Ventana" or e.persiana or e.cristal > 0 or not tiradas:tirar("Cara", noche) then
		return false
	end
	local centro = el:GetAttribute("Centro") :: CFrame
	local fuera = el:GetAttribute("Fuera") :: Vector3
	local c = C.Cara
	return hacer(b, function(modelo)
		-- Se arrima al cristal (desde Fuera, a 4 studs, la cara no llegaba: probado en Studio) y al acabar vuelve a
		-- Fuera, desde donde golpea.
		local normal = plano(centro.LookVector).Unit
		local pegado = Vector3.new(centro.Position.X, fuera.Y, centro.Position.Z) + normal * CARA_CRISTAL
		andarRecto(b, pegado + Vector3.new(0, b.o.Altura, 0))
		b:mirarA(centro.Position)
		local dura = rango(c.Dura)
		poner(modelo, "Cara", dura, centro.Position)
		local aparta = false
		local desde: number? = nil -- desde cuándo le miran sin parar
		esperar(b, dura, function(): boolean
			local ahora = Casa.estado(el)
			if ahora.persiana or ahora.cristal > 0 then
				return true -- le han echado la cortina: a golpear
			end
			if alumbrado(b) then
				aparta = true
				return true
			end
			if leMiran(b, el, centro) then
				desde = desde or os.clock()
				if os.clock() - (desde :: number) >= c.Mirado then
					aparta = true
					return true
				end
			else
				desde = nil
			end
			return false
		end)
		if aparta and b.modelo and not b.prisa and not b:quieto() then
			poner(modelo, "Aparta", APARTA, centro.Position)
			esperar(b, APARTA)
		end
		quitarAtributos(modelo)
		andarRecto(b, fuera + Vector3.new(0, b.o.Altura, 0))
		b:mirarA(centro.Position)
		return true
	end) == true
end

-- Llama: antes de aporrear, `Toques` toques lentos con un dedo (remote Golpeador "Toque" justo al tocar: el toque i a
-- (i - 0,5) × CadaToque s de SucesoHora) y espera. true si mientras le han abierto la puerta o la cortina: entonces
-- entra en el primer golpe (la regla de siempre, Defensa).
function GolpeadorSucesos.llama(b: Caza.Bicho, el: Model, noche: number): boolean
	-- Rota o abierta no hay a qué llamar: entra (en Studio llamaba al hueco de una ventana rota).
	local antes = Casa.estado(el)
	if antes.vida <= 0 or (antes.tipo == "Puerta" and antes.abierta) or not tiradas:tirar("Llama", noche) then
		return false
	end
	local centro = el:GetAttribute("Centro") :: CFrame
	local c = C.Llama
	local espera = rango(c.Espera)
	local function abrieron(): boolean
		local e = Casa.estado(el)
		return e.abiertaEnAtaque or (e.tipo == "Puerta" and e.abierta)
	end
	return hacer(b, function(modelo)
		poner(modelo, "Llama", c.Toques * c.CadaToque + espera, centro.Position)
		for i = 1, c.Toques do
			if not esperar(b, c.CadaToque * (if i == 1 then 0.5 else 1), abrieron) then
				return abrieron()
			end
			Remotes.Golpeador:FireAllClients("Toque", el)
		end
		esperar(b, c.CadaToque * 0.5 + espera, abrieron)
		return abrieron()
	end) == true
end

-- Finge: se ha cansado sin entrar. Se va hacia el bosque, se para a medio camino mirando atrás (a `casa`) y vuelve
-- corriendo a `fuera`. "Vuelve": ha vuelto (golpea un poco más); "Ve": mientras ha visto a alguien fuera (que le cace);
-- nil: no sale, amanece o le aturden (se va).
function GolpeadorSucesos.finge(b: Caza.Bicho, casa: Vector3, fuera: Vector3, lejos: Vector3, noche: number): ("Vuelve" | "Ve")?
	local ida = plano(lejos - fuera)
	if b.prisa or ida.Magnitude < 1 or not tiradas:tirar("Finge", noche) then
		return nil
	end
	local function nadie(): boolean
		return not b.prisa and b:elegirPresa(true) == nil
	end
	b:irA(fuera + ida.Unit * FINGE_LEJOS, G.Andar, 8, nadie)
	if not b.modelo or b.prisa then
		return nil
	elseif b:elegirPresa(true) then
		return "Ve"
	end
	local visto = false
	local hecho = hacer(b, function(modelo)
		local dura = rango(C.Finge.Mira)
		poner(modelo, "Finge", dura, casa)
		return esperar(b, dura, function(): boolean
			visto = b:elegirPresa(true) ~= nil
			return visto
		end)
	end)
	if visto then
		return "Ve"
	elseif not hecho then
		return nil
	end
	b:irA(fuera, G.Correr, 10, nadie) -- vuelve corriendo (andar normal, sin Suceso)
	if not b.modelo or b.prisa then
		return nil
	end
	return if b:elegirPresa(true) then "Ve" else "Vuelve"
end

-- Dentro (el gancho de Caza.cazar) -------------------------------------------------------------------------------------

type Estado = {
	noche: number,
	armarios: { [Model]: boolean }, -- los armarios en los que ya ha tenido su ocasión
	garrasOtra: number, -- os.clock hasta el que no vuelve a tirar Garras
	quietoOtra: { [Player]: number }, -- lo mismo con Quieto, por jugador
}

-- Armario: de ronda, a menos de `Cerca` del armario donde hay alguien escondido (sin haberle visto meterse: eso ya es
-- cazar, en Caza). Va delante de la puerta, la mira por las rendijas `Dura` s sin pillarle y sigue.
local function armario(b: Caza.Bicho, est: Estado): boolean
	if not Caza.dentroDeCasa(b.raiz.Position) then
		return false
	end
	local suelo = b:suelo()
	for _, jugador in Players:GetPlayers() do
		local sitio, hora = Muerte.escondite(jugador)
		if not sitio or sitio:GetAttribute("Tipo") ~= "Armario" or not Muerte.vivo(jugador)
			or (est.armarios[sitio] and not tiradas.forzados.Armario) then
			continue
		end
		local visto = b.vistoEn[jugador]
		if hora and visto and hora - visto <= b.o.VioEsconderse then
			continue
		end
		local dentro, vista = sitio:GetAttribute("Dentro"), sitio:GetAttribute("Vista")
		if typeof(dentro) ~= "CFrame" or typeof(vista) ~= "CFrame" then
			continue
		end
		local frente = plano(dentro.LookVector).Unit
		local delante = Vector3.new(dentro.X, dentro.Y - 3, dentro.Z) + frente * DELANTE -- a ras de suelo
		if plano(delante - suelo).Magnitude > C.Armario.Cerca or math.abs(delante.Y - suelo.Y) > 6 then
			continue
		end
		-- A la vista desde donde está (la misma sala o por una puerta abierta): no va a través de las paredes.
		local alto = delante + Vector3.new(0, b.o.Altura, 0)
		if rayo(b.raiz.Position, alto - b.raiz.Position) then
			continue
		end
		est.armarios[sitio] = true
		if not tiradas:tirar("Armario", est.noche) then
			continue
		end
		local rendijas = Vector3.new(dentro.X, vista.Y, dentro.Z) + frente * PUERTA -- a la altura de sus ojos
		local function sigue(): boolean
			return Muerte.escondite(jugador) == sitio and b:elegirPresa(false) == nil
		end
		-- Hasta delante de la puerta andando (aún es la ronda, sin Suceso) y el último trecho, recto.
		b:irA(delante, b.o.Andar, LLEGAR, sigue)
		local hasta = os.clock() + 1.5
		while b.modelo and not b.prisa and not b:quieto() and os.clock() < hasta and plano(delante - b:suelo()).Magnitude > 0.6
			and sigue() do
			b.humanoide:MoveTo(delante)
			task.wait(0.1)
		end
		if not b.modelo or b.prisa or b:quieto() or plano(delante - b:suelo()).Magnitude > 1.5 or not sigue() then
			return true
		end
		hacer(b, function(modelo)
			b:mirarA(rendijas)
			poner(modelo, "Armario", rango(C.Armario.Dura), rendijas)
			esperar(b, modelo:GetAttribute("SucesoDura") :: number, function(): boolean
				return not sigue()
			end)
		end)
		return true
	end
	return false
end

-- Olfatea: al llegar a una sala de ronda, se para y huele hacia el jugador más cercano dentro de la casa.
local function olfatea(b: Caza.Bicho, est: Estado): boolean
	if not Caza.dentroDeCasa(b.raiz.Position) then
		return false
	end
	local hacia: Vector3?, mejor = nil, math.huge
	for _, j in Players:GetPlayers() do
		local cabeza = cabezaDe(j)
		if cabeza and Muerte.vivo(j) and Caza.dentroDeCasa(cabeza.Position) then
			local d = (cabeza.Position - b.raiz.Position).Magnitude
			if d < mejor then
				hacia, mejor = cabeza.Position, d
			end
		end
	end
	if not hacia or not tiradas:tirar("Olfatea", est.noche) then
		return false
	end
	hacer(b, function(modelo)
		b:mirarA(hacia)
		local dura = rango(C.Olfatea.Dura)
		poner(modelo, "Olfatea", dura, hacia)
		esperar(b, dura, function(): boolean
			return b:elegirPresa(false) ~= nil
		end)
	end)
	return true
end

-- La pared a un lado (`lado`: -1 izquierda, 1 derecha) a menos de `Pared` studs, a la altura del hombro, que siga 2
-- studs más adelante (un pasillo, no una esquina) y que no sea una puerta. El punto donde la toca, o nil.
local function pared(b: Caza.Bicho, dir: Vector3, lado: number): Vector3?
	local hacia = dir:Cross(Vector3.yAxis) * lado * C.Garras.Pared
	local hombro = b.raiz.Position + Vector3.new(0, HOMBRO, 0)
	local r = rayo(hombro, hacia)
	if not r or math.abs(r.Normal.Y) > 0.3 or r.Instance.Name == "Hoja" or not r.Instance.CanCollide then
		return nil
	end
	local mas = rayo(hombro + dir * 2, hacia)
	if not mas or math.abs(mas.Normal.Y) > 0.3 then
		return nil
	end
	return r.Position
end

-- Garras: de ronda, junto a una pared. Sigue andando hacia `ronda` con las garras arrastrando por ella `Dura` s (o
-- hasta que se acaba la pared, llega a la sala o ve a alguien).
local function garras(b: Caza.Bicho, est: Estado, ronda: Vector3?): boolean
	local dir = plano(b.humanoide.MoveDirection)
	if not ronda or dir.Magnitude < 0.1 or (os.clock() < est.garrasOtra and not tiradas.forzados.Garras)
		or not Caza.dentroDeCasa(b.raiz.Position) then
		return false
	end
	dir = dir.Unit
	local lado: number?, punto: Vector3? = nil, nil
	for _, l in { -1, 1 } do
		punto = pared(b, dir, l)
		if punto then
			lado = l
			break
		end
	end
	if not lado or not punto then
		return false
	end
	est.garrasOtra = os.clock() + GARRAS_OTRA
	if not tiradas:tirar("Garras", est.noche) then
		return false
	end
	local modelo = b.modelo :: Model
	local ok, fallo = pcall(function()
		poner(modelo, "Garras", rango(C.Garras.Dura), punto, lado)
		local hasta = os.clock() + (modelo:GetAttribute("SucesoDura") :: number)
		local sinPared = 0
		while os.clock() < hasta do
			b:pasoHacia(ronda)
			task.wait(0.25)
			if not b.modelo or b.prisa or b:quieto() or b:cerca(ronda, 4) or b:elegirPresa(false) then
				return
			end
			local d = plano(b.humanoide.MoveDirection)
			local p = if d.Magnitude > 0.1 then pared(b, d.Unit, lado) else nil
			if p then
				modelo:SetAttribute("SucesoMira", p)
				sinPared = 0
			else
				sinPared += 0.25
				if sinPared >= 0.5 then
					return -- se acabó la pared
				end
			end
		end
	end)
	quitarAtributos(modelo)
	if not ok then
		error(fallo, 0)
	end
	return true
end

-- Quieto: le alumbra con la linterna desde más de `Lejos` studs. No se mueve `Dura` s mirándole y luego va a por él
-- sabiendo dónde está (aunque se esconda mientras: le está mirando). Devuelve a dónde ir, o nil si no sale.
local function quieto(b: Caza.Bicho, est: Estado, presa: Player, destino: Vector3?): Vector3?
	if not alumbrado(b) or not presa:GetAttribute("Linterna") or Muerte.escondite(presa)
		or not Caza.dentroDeCasa(b.raiz.Position) then
		return nil
	end
	local cabeza, raiz = cabezaDe(presa), raizDe(presa)
	if not cabeza or not raiz or (cabeza.Position - b:cabeza()).Magnitude <= C.Quieto.Lejos then
		return nil
	end
	-- Que sea él quien le alumbra: le tiene delante.
	local a, hacia = plano(b:cabeza() - cabeza.Position), plano(raiz.CFrame.LookVector)
	if a.Magnitude < 0.1 or hacia.Magnitude < 0.1 or a.Unit:Dot(hacia.Unit) < COS_LINTERNA then
		return nil
	end
	if os.clock() < (est.quietoOtra[presa] or -math.huge) and not tiradas.forzados.Quieto then
		return nil
	end
	est.quietoOtra[presa] = os.clock() + QUIETO_OTRA
	if not tiradas:tirar("Quieto", est.noche) then
		return nil
	end
	return hacer(b, function(modelo)
		b:mirarA(cabeza.Position)
		local dura = rango(C.Quieto.Dura)
		poner(modelo, "Quieto", dura, cabeza.Position)
		esperar(b, dura, function(): boolean
			local suya = cabezaDe(presa)
			if not suya or not Muerte.vivo(presa) then
				return true
			end
			-- Otro le queda más a mano (se le ha acercado): lo deja y va a por él, como al olfatear.
			local otra = b:elegirPresa(false)
			if otra and otra ~= presa then
				return true
			end
			modelo:SetAttribute("SucesoMira", suya.Position)
			return false
		end)
		local suya = cabezaDe(presa)
		-- Aturdido o amaneciendo a medias: no sale de golpe a por él al acabar.
		if suya and Muerte.vivo(presa) and not b:quieto() and not b.prisa then
			b.vistoEn[presa] = os.clock()
			return suya.Position - Vector3.new(0, 4.5, 0)
		end
		return destino
	end)
end

-- Le pone al bicho (un Golpeador de la noche `noche`) el gancho de Caza.cazar con los sucesos de dentro de la casa.
function GolpeadorSucesos.enganchar(b: Caza.Bicho, noche: number)
	local est: Estado = { noche = noche, armarios = {}, garrasOtra = -math.huge, quietoOtra = {} }
	b.alCazar = function(self: Caza.Bicho, momento: string, presa: Player?, destino: Vector3?): any
		if momento == "Ronda" then
			return armario(self, est) or garras(self, est, destino)
		elseif momento == "Sala" then
			return olfatea(self, est)
		elseif momento == "Presa" and presa then
			return quieto(self, est, presa, destino)
		end
		return nil
	end
end

-- Al volver a empezar el día (Golpeador.quitar): la misma noche se repite y sus sucesos pueden volver a salir.
function GolpeadorSucesos.reiniciar()
	tiradas:reiniciar()
end

function GolpeadorSucesos.start()
	if not Prueba.activa() then
		return
	end
	task.spawn(function() -- el BindableEvent lo crea Director, que arranca después
		ServerStorage:WaitForChild("Prueba").Event:Connect(function(que: string, nombre: unknown)
			if que ~= "Suceso" then
				return
			end
			if type(nombre) == "string" and tiradas:forzar(nombre) then
				print("[Prueba] La próxima ocasión de " .. nombre .. " sale seguro")
			else
				warn("[Prueba] Suceso desconocido: " .. tostring(nombre))
			end
		end)
	end)
end

return GolpeadorSucesos
