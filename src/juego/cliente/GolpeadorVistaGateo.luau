-- El gateo del Golpeador y sus muebles; GolpeadorVista lo pone encima de la postura de siempre en cada fotograma
-- (también apartarBrazos de pie, junto a una mesa). Librería sin start().
-- Gatear a por alguien escondido debajo de un mueble (pedido por el usuario: "que el monstruo pueda gatear si te huele
-- con una animación guapa para pillarte debajo de sitios"). El servidor (Caza) le para en el borde, de cara a ti, y pone
-- en su modelo Gatea (dónde estás) y GateaHora (workspace:GetServerTimeNow() al empezar) durante Config.Postura.Gatear s.
-- Pesado: se dobla hasta el suelo apoyando los brazos larguísimos, mete la cabeza de lado a ras de suelo, mirándote, y
-- barre por debajo con un brazo, a tirones, parándose a olfatear. La cara baja por fuera del borde y solo entra cuando
-- está abajo; al acabar, primero la saca, recoge el brazo y luego se levanta. La mesa se mide por su zona Debajo (los
-- rayos no ven los muebles). Comprobado con Lune contra las mesas del comedor (tablero a 2,84 del suelo) y de la cocina
-- (3,29, con caballetes y una viga baja), con el bicho a 0,5-5 studs del borde, de frente y en diagonal: ni el suelo, ni
-- el tablero, ni las patas se atraviesan (tampoco de pie junto a la mesa: los brazos se echan atrás).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BichoComun = require(script.Parent.BichoComun)
local Cuerpo = require(script.Parent.GolpeadorVistaCuerpo)
local MuebleRayo = require(script.Parent.MuebleRayo)
local Muerte = require(script.Parent.GolpeadorVistaMuerte)
local Sonido = require(script.Parent.Sonido)

local GolpeadorVistaGateo = {}

local GATEO = {
	Cae = 0.45, -- segundos en echarse al suelo
	Sale = 0.35, -- al acabar, segundos en sacar la cabeza de debajo...
	Levanta = 0.6, -- ...y en levantarse
	Recoge = 0.5, -- segundos como mucho que espera a recoger el brazo antes de levantarse
	Cara = 1.2, -- studs del suelo al centro de la cabeza
	Ladeo = 1.35, -- la cabeza casi de lado (así la boca se abre de lado y no contra el suelo)
	Hasta = 1.1, -- studs entre su cara y tú al acabar
	Avanza = 1.6, -- studs que mete la cabeza desde que se echa hasta el final
	Fuera = 1.3, -- studs por fuera del borde a los que baja la cara (luego entra a tirones)
	Aparta = 1.2, -- y lo que se aleja más de pie (al echarse viene de ahí y al levantarse vuelve)
	Borde = 1.4, -- studs del borde del mueble hasta ti, si los rayos no encuentran el tablero
	Dentro = 0.55, -- studs que mete el centro de la cara por debajo del tablero (más, el torso tocaría uno de 2,84)
	Inclina = math.rad(55), -- doblado, el torso va de la cadera a los hombros hacia abajo
	Bajo = 1.95, -- studs del suelo al centro de la cara: más arriba no entra debajo del tablero
	-- Los tirones, en segundos de un gateo de 2 s: {empieza, acaba, hasta dónde ha metido la cabeza (0..1)}.
	Tirones = { { 0.5, 0.68, 0.4 }, { 1, 1.18, 0.72 }, { 1.5, 1.75, 1 } },
}
-- Cuándo suena cada ruido del gateo (en segundos de un gateo de 2 s): al echarse y al empezar cada tirón.
local EVENTOS = { GATEO.Cae, GATEO.Tirones[1][1], GATEO.Tirones[2][1], GATEO.Tirones[3][1] }
-- Los brazos al gatear (giros en radianes desde hacia ti, por su lado de fuera): el de apoyo, abierto hacia fuera y algo
-- atrás; si se meten en una pata del mueble, se apartan hacia `Atras` (`Holgura`: lo gordo del brazo). El que mete
-- gira hacia ti como mucho a `Barre` (de 0 a 1) por segundo, y ninguno gira más deprisa que `Giro` por segundo.
local BRAZO = {
	Apoyo = 2.2, -- radianes desde hacia ti, por fuera
	Atras = 2.8,
	Holgura = 0.42,
	Barre = 3,
	Giro = 5,
}
-- Lo más bajo de la mandíbula (en ella): sus esquinas y la sangre que le chorrea de la barbilla.
local BARBILLA = {
	Vector3.new(-0.55, -0.8, -0.61), Vector3.new(0.55, -0.8, -0.61), Vector3.new(-0.55, -0.18, 0.6), Vector3.new(0.55, -0.18, 0.6),
	Vector3.new(-0.55, -0.18, -0.6), Vector3.new(0.55, -0.18, -0.6),
}
-- Junto a un mueble con hueco, los brazos de pie (y al echarse y levantarse) se echan atrás desde el hombro para no
-- atravesar su tablero: lo justo, hasta `Max` radianes, `Sube`/`Baja` radianes por segundo.
local APARTA = { Cerca = 10, Cada = 0.5, Max = 1.6, Sube = 9, Baja = 2.5, Holgura = 0.35 }
-- La cabeza, para no meterla en una pata o travesaño: de qué altura a qué altura del suelo va (con la mandíbula y la
-- sangre), lo que ocupa a cada lado y lo que sobresale por delante de su centro.
-- (La cabeza va de lado: la mandíbula sobresale `Boca` hacia el lado del brazo que mete; al otro, `Ancho`.)
local CABEZA_FONDO = { Bajo = 0.2, Alto = 2.5, Ancho = 0.8, Boca = 1.5, Delante = 1 }
local BORDE_HOLGURA = 0.2 -- studs: se toma el borde del tablero un poco antes de donde está

type Bicho = Cuerpo.Bicho
type Gateo = Cuerpo.Gateo
type Patas = Cuerpo.Patas

local azar = BichoComun.azar
local suave, duraGateo = BichoComun.suaveSinTope, BichoComun.duraGateo
local ALTURA, LADOS, CABEZA_CENTRO, GARRAS, PIERNA = Cuerpo.ALTURA, Cuerpo.LADOS, Cuerpo.CABEZA_CENTRO, Cuerpo.GARRAS, Cuerpo.PIERNA
local orientar, mirarCara = Cuerpo.orientar, Cuerpo.mirarCara
local SUSTO = Muerte.SUSTO
local filtroGateo = RaycastParams.new()
filtroGateo.FilterType = Enum.RaycastFilterType.Exclude

-- El tablero que tapa al escondido en `punto` (el de la zona Debajo en la que está), o nil. Las piezas de los muebles y
-- sus cajas de choque no se ven con rayos (CanQuery false): lo calcula MuebleRayo.tablero con el Tam del mueble.
local function tablero(punto: Vector3): (CFrame?, Vector3?, BasePart?)
	for _, zona in CollectionService:GetTagged("Debajo") do
		if not zona:IsA("BasePart") then
			continue
		end
		local medio = zona.Size / 2
		local p = zona.CFrame:PointToObjectSpace(punto)
		if math.abs(p.X) > medio.X + 0.5 or math.abs(p.Z) > medio.Z + 0.5 or p.Y < -medio.Y - 1 or p.Y > medio.Y + 3 then
			continue
		end
		local cf, tam = MuebleRayo.tablero(zona)
		return cf, tam, zona
	end
	return nil, nil, nil
end

-- Las patas (y travesaños) del mueble de la zona: las cajas de choque de Mapa (HUECOS) que caen bajo su tablero, por
-- debajo de él. No se ven con rayos (CanQuery false): se buscan entre las piezas de la casa, una vez por gateo.
local function patasDe(zona: BasePart, encima: CFrame, tam: Vector3): Patas?
	local mueble = zona.Parent
	local casa = mueble and mueble.Parent
	if not casa then
		return nil
	end
	local abajo = zona.CFrame:PointToWorldSpace(Vector3.new(0, zona.Size.Y / 2, 0)).Y
	local patas: Patas = {}
	for _, pieza in casa:GetChildren() do
		if pieza.Name == "Choque" and pieza:IsA("BasePart") then
			local p = encima:PointToObjectSpace(pieza.Position)
			local arriba = pieza.Position.Y + pieza.Size.Y / 2 -- (de pie: sin girar)
			if math.abs(p.X) < tam.X / 2 and math.abs(p.Z) < tam.Z / 2 and arriba <= abajo + 0.1 then
				table.insert(patas, { cf = pieza.CFrame, medio = pieza.Size / 2 })
			end
		end
	end
	return patas
end

-- Studs (por el suelo, de la raíz hacia `punto`) hasta el borde del tablero que tapa al escondido, en el centro y a los
-- lados (si llega en diagonal, el borde le queda antes a un hombro): el de su zona Debajo y, si no está en ninguna, con
-- rayos hacia arriba cada poco (lo que quede más bajo que un escondite, como el asiento de una silla, no cuenta). Sin
-- tablero, GATEO.Borde antes de ti. (Antes solo con rayos: en el juego no daban nunca en la mesa y se metía por ella.)
local function buscarBorde(b: Bicho, punto: Vector3): (number, Patas?, { [number]: number })
	local raiz = b.raiz.Position
	local plano = Vector3.new(punto.X - raiz.X, 0, punto.Z - raiz.Z)
	local largo = plano.Magnitude
	if largo < 0.5 then
		return 0, nil, { [-1] = math.huge, [1] = math.huge }
	end
	local hacia = plano.Unit
	local lado = Vector3.new(-hacia.Z, 0, hacia.X)
	local cf, tam, zona = tablero(punto)
	if cf and tam and zona then
		-- Por donde entra cada raya (paralelas, por el suelo) en la caja del tablero.
		local medio = tam / 2
		local d = cf:VectorToObjectSpace(hacia)
		local borde = largo
		for _, x in { 0, -1.6, 1.6 } do -- (el torso, más ancho que la cabeza, tocaba el tablero entrando en diagonal)
			local o = cf:PointToObjectSpace(raiz + lado * x)
			local entra, sale = -math.huge, math.huge
			for _, eje in { "X", "Z" } do
				local oe, de, me = (o :: any)[eje], (d :: any)[eje], (medio :: any)[eje]
				if math.abs(de) < 1e-6 then
					if math.abs(oe) > me then
						entra = math.huge
					end
				else
					local t1, t2 = (-me - oe) / de, (me - oe) / de
					entra, sale = math.max(entra, math.min(t1, t2)), math.min(sale, math.max(t1, t2))
				end
			end
			if entra <= sale and sale > 0 then
				borde = math.min(borde, math.max(0, entra))
			end
		end
		local patas = patasDe(zona, cf, tam)
		-- Lo que la cabeza puede meterse: hasta la primera pata o travesaño que tenga delante a su altura (la viga baja de
		-- la mesa de la cocina), con la anchura de la cabeza a cada lado; según hacia qué lado la ladee (`boca`).
		local fondos = { [-1] = math.huge, [1] = math.huge }
		local suelo = raiz.Y - ALTURA
		for _, pata in patas or {} do
			local abajo, arriba = pata.cf.Position.Y - pata.medio.Y - suelo, pata.cf.Position.Y + pata.medio.Y - suelo
			if arriba < CABEZA_FONDO.Bajo or abajo > CABEZA_FONDO.Alto then
				continue
			end
			for _, boca in LADOS do
				local corre = lado * boca * (CABEZA_FONDO.Boca - CABEZA_FONDO.Ancho) / 2
				local o = pata.cf:PointToObjectSpace(Vector3.new(raiz.X, pata.cf.Position.Y, raiz.Z) + corre)
				local dl = pata.cf:VectorToObjectSpace(hacia)
				local entra, sale = -math.huge, math.huge
				for _, eje in { "X", "Z" } do
					local oe, de = (o :: any)[eje], (dl :: any)[eje]
					local me = (pata.medio :: any)[eje] + (CABEZA_FONDO.Boca + CABEZA_FONDO.Ancho) / 2
					if math.abs(de) < 1e-6 then
						if math.abs(oe) > me then
							entra = math.huge
						end
					else
						local t1, t2 = (-me - oe) / de, (me - oe) / de
						entra, sale = math.max(entra, math.min(t1, t2)), math.min(sale, math.max(t1, t2))
					end
				end
				if entra <= sale and sale > 0 then
					fondos[boca] = math.min(fondos[boca], math.max(0, entra))
				end
			end
		end
		return math.max(0, borde - BORDE_HOLGURA), patas, fondos
	end
	local fuera: { Instance } = {}
	local carpeta = workspace:FindFirstChild("Bichos")
	if carpeta then
		table.insert(fuera, carpeta)
	end
	for _, otro in Players:GetPlayers() do
		if otro.Character then
			table.insert(fuera, otro.Character)
		end
	end
	filtroGateo.FilterDescendantsInstances = fuera
	local suelo = raiz.Y - ALTURA
	local d = 0.3
	while d < largo do
		for _, x in { 0, -1.2, 1.2 } do
			local base = Vector3.new(raiz.X, suelo + 0.4, raiz.Z) + hacia * d + lado * x
			local choque = workspace:Raycast(base, Vector3.new(0, 4.5, 0), filtroGateo)
			if choque and choque.Instance.Name ~= "Debajo" and choque.Position.Y - suelo > 2.3 then
				return math.max(0, d - 0.2), nil, { [-1] = math.huge, [1] = math.huge }
			end
		end
		d += 0.3
	end
	return math.max(0, largo - GATEO.Borde), nil, { [-1] = math.huge, [1] = math.huge }
end

-- Por dónde va el gateo a los `t` s: cuánto ha metido la cabeza (0..1), cuánto olfatea (0..1, entre tirones) y el
-- empujón de cada tirón (0..1). Simple (Rendimiento): seguido, sin olfatear.
local function avanceGateo(t: number, simple: boolean): (number, number, number)
	-- GATEO.Tirones va en segundos de un gateo de 2 s. Cada tirón, suave al empezar: con un arranque seco, la punta de las
	-- garras saltaba ~3 studs en un fotograma.
	return BichoComun.avanceGateo(t * 2 / duraGateo(), simple, GATEO, suave)
end

-- Los ruidos del gateo: 1 se echa al suelo; 2 y 3, cada tirón; 4, el último, con un gruñido grave que se corta.
local function ruidoGateo(b: Bicho, n: number)
	local donde = b.cabeza.Position
	if n == 1 then
		Sonido.en("Paso", donde - Vector3.new(0, 0.8, 0), 0.45)
		Sonido.en("Cruje", donde, 0.8)
		return
	end
	Sonido.en("Paso", donde, 0.6)
	if n == 4 then
		local corto = Sonido.en("Rugido", donde, 0.5)
		task.delay(0.4, function()
			if corto.Parent then
				corto:Stop()
			end
		end)
	else
		Sonido.en("Cruje", donde, 0.9)
	end
end

-- Lo alto de los hombros (en el marco del gateo: su Y es la altura sobre el suelo).
local function hombroAlto(m: { [string]: Motor6D }, torso: CFrame): number
	return (torso * m.BrazoD.C0.Position).Y
end

-- Si un punto (en el mundo) no está dentro de una pata del mueble (con algo de holgura: lo gordo del brazo).
local function puntoLibre(patas: Patas, p: Vector3): boolean
	for _, pata in patas do
		local q = pata.cf:PointToObjectSpace(p)
		local m = pata.medio
		if math.abs(q.X) < m.X + BRAZO.Holgura and math.abs(q.Y) < m.Y + BRAZO.Holgura and math.abs(q.Z) < m.Z + BRAZO.Holgura then
			return false
		end
	end
	return true
end

-- Si el brazo entero (del hombro a la punta de las garras, en `dir`; en el marco `enMundo`) está libre de las patas.
local function brazoLibre(patas: Patas, enMundo: CFrame, hombro: Vector3, dir: Vector3): boolean
	local d = 0.4
	while d <= -GARRAS.Y do
		if not puntoLibre(patas, enMundo * (hombro + dir * d)) then
			return false
		end
		d += 0.4
	end
	return true
end

-- El tablero con hueco más cercano a la raíz (a menos de APARTA.Cerca studs, en planta), mirado cada APARTA.Cada s.
local function mesaCerca(b: Bicho, ahora: number)
	if ahora < b.mesaHasta then
		return
	end
	b.mesaHasta = ahora + APARTA.Cada
	b.mesa = nil
	local raiz = b.raiz.Position
	local mejor = APARTA.Cerca
	for _, zona in CollectionService:GetTagged("Debajo") do
		if zona:IsA("BasePart") and (zona.Position - raiz).Magnitude < APARTA.Cerca + 12 then
			local cf, tam = MuebleRayo.tablero(zona)
			local q = cf:PointToObjectSpace(raiz)
			local fuera = Vector3.new(math.max(0, math.abs(q.X) - tam.X / 2), 0, math.max(0, math.abs(q.Z) - tam.Z / 2)).Magnitude
			if fuera < mejor then
				mejor = fuera
				b.mesa = { cf = cf, tam = tam }
			end
		end
	end
end

-- Con los brazos ya puestos este fotograma (de pie, echándose, gateando o levantándose): si alguno atraviesa el tablero
-- de la mesa de al lado, lo echa hacia atrás desde el hombro (hacia fuera de la mesa) lo justo para que no. De pie, tan
-- largos y colgando por delante, se metían hasta 1,7 studs en él (comprobado con Lune). Sube deprisa y baja despacio.
local function apartarBrazos(b: Bicho, dt: number, aparta: { number })
	local mesa = b.mesa
	local m = b.motores
	local torso = m.Torso.C0 * m.Torso.Transform * m.Torso.C1:Inverse() -- en el espacio de la raíz
	local caja, medio, eje = nil, nil, nil
	if mesa then
		local c = b.raiz.CFrame:ToObjectSpace(mesa.cf)
		local mm = mesa.tam / 2 + Vector3.one * APARTA.Holgura
		-- Hacia fuera de la mesa (en planta): de su punto más cercano a la raíz.
		local q = c:PointToObjectSpace(Vector3.zero)
		local n = c:VectorToWorldSpace(q - Vector3.new(math.clamp(q.X, -mm.X, mm.X), q.Y, math.clamp(q.Z, -mm.Z, mm.Z)))
		n = Vector3.new(n.X, 0, n.Z)
		if n.Magnitude > 0.05 then
			caja, medio, eje = c, mm, n.Unit:Cross(Vector3.yAxis)
		end
	end
	for i, lado in LADOS do
		local motor = m[if lado < 0 then "BrazoI" else "BrazoD"]
		local hombro = torso * motor.C0.Position
		local parte = torso * motor.C0 * motor.Transform * motor.C1:Inverse()
		local meta = 0
		if caja and medio and eje then
			local desde, largo = motor.C1.Position, GARRAS
			-- El suelo también cuenta (echado, girar el brazo así lo hundía en él), salvo si ya estaba dentro sin girar.
			local suelo = -math.huge
			if (parte * (desde + largo)).Y > -ALTURA + 0.1 then
				suelo = -ALTURA + 0.05
			end
			local function choca(angulo: number): boolean
				local giro = CFrame.new(hombro) * CFrame.fromAxisAngle(eje, angulo) * CFrame.new(-hombro) * parte
				for k = 0, 1, 0.06 do
					local p = giro * (desde + largo * k)
					local q = caja:PointToObjectSpace(p)
					if p.Y < suelo or math.abs(q.X) < medio.X and math.abs(q.Y) < medio.Y and math.abs(q.Z) < medio.Z then
						return true
					end
				end
				return false
			end
			if choca(aparta[i]) or (aparta[i] > 0 and choca(0)) then
				-- Lo justo: el primer ángulo que no choca y, afinado, su canto (si ninguno vale, se queda como estaba).
				meta = aparta[i]
				for j = 1, 10 do
					local probar = APARTA.Max * j / 10
					if not choca(probar) then
						local lo, hi = APARTA.Max * (j - 1) / 10, probar
						for _ = 1, 5 do
							local mitad = (lo + hi) / 2
							if choca(mitad) then
								lo = mitad
							else
								hi = mitad
							end
						end
						meta = hi
						break
					end
				end
			end
		end
		local antes = aparta[i]
		aparta[i] = if meta > antes then math.min(meta, antes + dt * APARTA.Sube) else math.max(meta, antes - dt * APARTA.Baja)
		if aparta[i] > 1e-3 and eje then
			local giro = CFrame.new(hombro) * CFrame.fromAxisAngle(eje, aparta[i]) * CFrame.new(-hombro) * parte
			motor.Transform = motor.C0:Inverse() * torso:Inverse() * giro * motor.C1
		end
	end
end

-- El gateo: con Gatea y GateaHora en el modelo, se echa al suelo y mete la cabeza y un brazo por debajo del mueble,
-- encima de la postura de siempre (que ya está en las juntas este fotograma); sin ellos, saca la cabeza y se levanta.
-- La cara sigue un camino: baja por fuera del borde y solo entra por debajo cuando está abajo (si no, al doblarse, la
-- cabeza y los brazos barrían el tablero). El torso sale de ella, doblándose poco a poco desde la cadera.
local function gatear(b: Bicho, dt: number, ahora: number, poco: boolean, bocaBase: number)
	local punto = b.modelo:GetAttribute("Gatea")
	local hora = b.modelo:GetAttribute("GateaHora")
	local activo = typeof(punto) == "Vector3" and typeof(hora) == "number"
	local dura = duraGateo()
	local g = b.gatea
	if activo then
		if not g or g.hora ~= hora then
			local t = math.clamp(workspace:GetServerTimeNow() - hora, 0, dura)
			-- Si llega tarde, los ruidos que ya han pasado no suenan todos de golpe.
			local sonados = 0
			for _, en in EVENTOS do
				if t * 2 / dura > en + 0.15 then
					sonados += 1
				end
			end
			-- La cabeza se ladea hacia el lado del brazo que mete: hacia donde no haya una pata cerca, si la hay.
			local brazo = if azar:NextNumber() < 0.5 then -1 else 1
			local borde, patas, fondos = buscarBorde(b, punto)
			if fondos[-brazo] > fondos[brazo] + 0.05 then
				brazo = -brazo
			end
			local fondo = fondos[brazo]
			g = {
				hora = hora, punto = punto, borde = borde, t = t, sonados = sonados,
				brazo = brazo, cara0 = b.cabeza.Position, sale = 0, espera = 0,
				patas = patas, fondo = fondo, barre = 0, rumbo = {}, levanta = 0, mirada = nil,
			}
			b.gatea = g
		end
		local actual = g :: Gateo
		actual.punto = punto
		actual.t = math.clamp(workspace:GetServerTimeNow() - hora, 0, dura)
		actual.sale = 0
		actual.espera = 0
	end
	if not g then
		return
	end
	-- Gateando (o mientras dura el susto si te ha pillado) se echa; al acabar, saca la cabeza y luego se levanta.
	local s = b.susto
	local pillado = s ~= nil and s.gatea
	if activo or pillado then
		b.gateo = math.min(1, b.gateo + dt / GATEO.Cae)
	else
		g.sale = math.min(1, g.sale + dt / GATEO.Sale)
		if g.sale >= 1 then
			-- Antes de levantarse, el brazo que metía vuelve a apoyarse a su lado: si no, al subir los hombros lo metían en
			-- el tablero (comprobado con Lune). Como mucho GATEO.Recoge s.
			local r = g.rumbo[g.brazo]
			g.espera += dt
			if g.barre < 0.02 and (r == nil or math.abs(r - g.brazo * BRAZO.Apoyo) < 0.15) or g.espera > GATEO.Recoge then
				b.gateo = math.max(0, b.gateo - dt / GATEO.Levanta)
			end
		end
	end
	if b.gateo <= 0 then
		b.gatea = nil
		return
	end
	local m = b.motores
	local w = b.gateo
	local entra = suave(math.min(1, w * 4)) -- lo que manda el gateo sobre la postura de siempre
	local a, olfatea, empuje = avanceGateo(g.t, poco)
	local queda = 1 - suave(g.sale)
	a *= queda
	local husmea = if poco then 0 else olfatea * queda
	empuje *= queda
	-- Si te ha pillado (el susto): en Arrastra el brazo que metía tira de ti hacia él (vuelve a su lado) y la cabeza sale
	-- de debajo; luego la levanta un poco del suelo y la gira hacia ti (ya fuera del mueble) para lo demás del susto.
	local tirones = Vector3.zero
	if pillado and s then
		local c = Config.Golpeador.Susto
		local t = ahora - s.t0
		a *= 1 - suave(math.clamp(t / c.Arrastra, 0, 1))
		husmea, empuje = 0, 0
		g.levanta = suave(math.clamp((t - c.Arrastra) / 0.3, 0, 1))
		tirones = s.tir
	else
		g.levanta = math.max(0, g.levanta - dt / 0.35) -- al acabar baja suave (sin saltos)
	end
	local levanta = g.levanta

	-- El marco: en el suelo bajo la raíz, mirando hacia el escondido. Todo lo de abajo va en él.
	local enRaiz = b.raiz.CFrame:PointToObjectSpace(g.punto)
	local plano = Vector3.new(enRaiz.X, 0, enRaiz.Z)
	local lejos = math.max(plano.Magnitude, 0.5)
	local marco = CFrame.new(0, -ALTURA, 0) * CFrame.Angles(0, math.atan2(-plano.X, -plano.Z), 0)
	local tuAlto = math.clamp(enRaiz.Y + ALTURA, 0.6, 2)

	-- La cara: baja (pesado: cada vez más deprisa) por fuera del borde; abajo entra a tirones hasta quedarse a
	-- GATEO.Hasta de ti, sin pasar de GATEO.Dentro por debajo del tablero.
	local cara0 = (b.raiz.CFrame * marco):PointToObjectSpace(g.cara0)
	local alto = cara0.Y + (GATEO.Cara - cara0.Y) * w * w + husmea * 0.05 * math.sin(ahora * 26) + SUSTO.Levanta * levanta
	-- (Con tope: con una pata justo delante salía menos que el de `fuera` y math.clamp daba error.)
	local final = math.max(-0.5, math.min(lejos - GATEO.Hasta, g.borde + GATEO.Dentro, g.fondo - CABEZA_FONDO.Delante))
	-- (Echándose y levantándose, la cara más lejos del borde: de lado, la mandíbula rozaba el tablero al subir.)
	local fuera = math.clamp(g.borde - GATEO.Fuera - (1 - w) * GATEO.Aparta, -0.5, final)
	local hasta = fuera + (final - fuera) * a * math.clamp((GATEO.Bajo - alto) / 0.6, 0, 1)
	local hz = suave(math.min(1, w * 2.5))
	local centro = Vector3.new(cara0.X * (1 - hz), alto, cara0.Z + (-hasta - cara0.Z) * hz)
	local haciaCara = Vector3.new(0, tuAlto, -lejos) - centro
	if levanta > 0 then
		-- Pillado: hacia la cámara (fuera del mueble; desde Salta, fija), sin torcer el cuello más de SUSTO.Giro. Al
		-- acabar el susto, la última, mientras baja la cabeza.
		local suya = g.mirada
		if s then
			local dir = if s.dir then marco:VectorToObjectSpace(s.dir)
				else (b.raiz.CFrame * marco):PointToObjectSpace(s.mirar) - centro
			local angulo = math.clamp(math.atan2(-dir.X, -dir.Z), -SUSTO.Giro, SUSTO.Giro)
			local alza = math.clamp(math.atan2(dir.Y, math.sqrt(dir.X * dir.X + dir.Z * dir.Z)), -0.6, 0.7)
			suya = Vector3.new(-math.sin(angulo) * math.cos(alza), math.sin(alza), -math.cos(angulo) * math.cos(alza))
			g.mirada = suya
		end
		if suya then
			haciaCara = haciaCara.Unit:Lerp(suya, levanta)
		end
	end
	local giroCara = mirarCara(haciaCara,
		(g.brazo * GATEO.Ladeo * (1 - 0.75 * levanta) + husmea * 0.12 * math.sin(ahora * 11) + tirones.Z) * suave(w))
		* CFrame.Angles(tirones.X, tirones.Y, 0)
	local cuello = centro - giroCara * CABEZA_CENTRO

	-- El torso, doblándose desde la cadera: de un poco echado hacia delante a la cadera arriba y los hombros abajo.
	local fi = 0.4 + (math.pi / 2 + GATEO.Inclina - 0.4) * suave(w)
	local giroT = CFrame.fromMatrix(Vector3.zero, Vector3.xAxis, Vector3.new(0, math.cos(fi), -math.sin(fi)))
	local torsoC = CFrame.new(cuello - giroT * m.Cabeza.C0.Position) * giroT
	m.Torso.Transform = m.Torso.Transform:Lerp(m.Torso.C0:Inverse() * (marco * torsoC) * m.Torso.C1, entra)
	m.Cabeza.Transform = m.Cabeza.Transform:Lerp((torsoC * m.Cabeza.C0):Inverse() * (CFrame.new(cuello) * giroCara), entra)

	-- Brazos y piernas, desde el torso que tiene de verdad este fotograma: así las garras y los pies nunca se meten en el
	-- suelo. Un brazo apoyado a su lado, por fuera del mueble; el otro igual hasta que los hombros están abajo, y entonces
	-- barre por debajo hacia ti, a tirones, arañando el suelo (es tan largo que pasa a tu lado).
	local torso = marco:Inverse() * m.Torso.C0 * m.Torso.Transform * m.Torso.C1:Inverse()
	local enMundo = b.raiz.CFrame * marco
	-- Sin ir más deprisa que esto: al llegar tarde (ya metido) el brazo giraba 100° en dos fotogramas.
	local barre = math.clamp(1.15 * a * (1 - suave(math.clamp((hombroAlto(m, torso) - 1.6) / 0.8, 0, 1))), 0, 1)
	g.barre = if barre > g.barre then math.min(barre, g.barre + dt * BRAZO.Barre) else math.max(barre, g.barre - dt * BRAZO.Barre)
	for _, lado in LADOS do
		local motor = m[if lado < 0 then "BrazoI" else "BrazoD"]
		local hombro = torso * motor.C0.Position
		local cae = math.clamp((hombro.Y - 0.12 + GARRAS.Z) / -GARRAS.Y, -0.95, 0.95) -- la punta de las garras a ras de suelo
		-- Los giros, como rumbos por el suelo (0 hacia ti, + hacia su derecha) que pasan siempre por su lado de fuera: con
		-- Lerp de vectores casi opuestos, a medio camino el brazo daba la vuelta de golpe.
		local apoyo = lado * BRAZO.Apoyo
		local rumbo = apoyo
		if lado == g.brazo then
			local junto = Vector3.new(lado * 0.9 - hombro.X, 0, -lejos - hombro.Z)
			local haciaTi = if junto.Magnitude > 0.1 then math.atan2(junto.X, -junto.Z) else 0
			rumbo = apoyo + (haciaTi - apoyo) * g.barre
			if not poco then
				rumbo -= empuje * 0.08 * math.sin(ahora * 31)
			end
		end
		-- Sin atravesar las patas del mueble: va hacia donde querría sin pasar por dentro de ninguna (si una se pone en
		-- medio, se queda en su canto), y si el cuerpo al moverse se la mete dentro, se aparta hacia atrás (hasta
		-- BRAZO.Atras) lo justo. Siempre girando poco a poco: sin saltos.
		local patas = g.patas
		if patas and #patas > 0 then
			local function libre(r: number): boolean
				local dir = Vector3.new(math.sin(r), 0, -math.cos(r))
				return brazoLibre(patas, enMundo, hombro, dir * math.sqrt(1 - cae * cae) - Vector3.yAxis * cae)
			end
			local actual = g.rumbo[lado] or rumbo
			local paso = dt * BRAZO.Giro
			local siguiente = actual + math.clamp(rumbo - actual, -paso, paso)
			if libre(siguiente) then
				actual = siguiente
			elseif not libre(actual) then
				local atras = lado * BRAZO.Atras
				local hallado = atras
				for i = 1, 12 do
					local probar = actual + (atras - actual) * i / 12
					if libre(probar) then
						-- Afinado entre el último que no cabía y este: justo en el canto.
						local lo, hi = actual + (atras - actual) * (i - 1) / 12, probar
						for _ = 1, 4 do
							local medio = (lo + hi) / 2
							if libre(medio) then
								hi = medio
							else
								lo = medio
							end
						end
						hallado = hi
						break
					end
				end
				actual = hallado
			end
			g.rumbo[lado] = actual
			rumbo = actual
		end
		local hacia = Vector3.new(math.sin(rumbo), 0, -math.cos(rumbo))
		local parte = CFrame.new(hombro) * orientar(hacia * math.sqrt(1 - cae * cae) - Vector3.yAxis * cae, -Vector3.yAxis)
			* CFrame.new(-motor.C1.Position)
		motor.Transform = motor.Transform:Lerp(motor.C0:Inverse() * torso:Inverse() * parte * motor.C1, math.min(1, w * 2.5))
	end
	local cadera = torso * m.Torso.C1.Position
	for _, lado in LADOS do
		local motor = m[if lado < 0 then "PiernaI" else "PiernaD"]
		local junta = cadera + torso.XVector * motor.C0.Position.X - Vector3.new(0, 0.1, 0)
		-- El pie en el suelo (la pierna es gruesa: su eje acaba un poco más arriba), la pierna echada hacia atrás.
		local cae = math.clamp((junta.Y - 0.3) / PIERNA, 0, 1)
		local hacia = Vector3.new(lado * 0.3, 0, 0.95).Unit * math.sqrt(1 - cae * cae) - Vector3.yAxis * cae
		local parte = CFrame.new(junta) * orientar(hacia, -Vector3.zAxis) * CFrame.new(-motor.C1.Position)
		motor.Transform = motor.Transform:Lerp(motor.C0:Inverse() * (marco * parte) * motor.C1, math.min(1, w * 2))
	end
	-- La boca, abriéndose según se acerca (de lado); olfateando, a golpecitos. Nunca contra el suelo: con la cabeza tan
	-- baja, abierta del todo (al rugir) la barbilla y la sangre se metían ~0,4 en él (comprobado con Lune).
	local abre = bocaBase + (0.2 + 0.35 * a + husmea * 0.08 * math.abs(math.sin(ahora * 13))) * w
	local cabezaM = marco:Inverse() * m.Torso.C0 * m.Torso.Transform * m.Torso.C1:Inverse() * m.Cabeza.C0 * m.Cabeza.Transform
		* m.Cabeza.C1:Inverse() * m.Mandibula.C0
	local function barbilla(angulo: number): number
		local mand = cabezaM * CFrame.Angles(-angulo, 0, 0) * m.Mandibula.C1:Inverse()
		local bajo = math.huge
		for _, esquina in BARBILLA do
			bajo = math.min(bajo, (mand * esquina).Y)
		end
		return bajo
	end
	if barbilla(abre) < 0.05 then
		local lo, hi = 0, abre
		for _ = 1, 8 do
			local medio = (lo + hi) / 2
			if barbilla(medio) < 0.05 then
				hi = medio
			else
				lo = medio
			end
		end
		abre = lo
	end
	m.Mandibula.Transform = CFrame.Angles(-abre, 0, 0)

	-- Los ruidos, cada uno una vez (con Rendimiento, solo al echarse y el gruñido del final).
	local u = g.t * 2 / dura
	if activo and g.sonados < #EVENTOS and u >= EVENTOS[g.sonados + 1] then
		g.sonados += 1
		if not poco or g.sonados == 1 or g.sonados == #EVENTOS then
			ruidoGateo(b, g.sonados)
		end
	end
end

local G = GolpeadorVistaGateo
G.gatear, G.mesaCerca, G.apartarBrazos = gatear, mesaCerca, apartarBrazos

return GolpeadorVistaGateo
