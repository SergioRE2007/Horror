-- Sustos con cosas de la casa (ver Sustos/init). Todo local y devuelto a su sitio.
--   Portazo: una puerta abierta de otra sala se cierra de golpe (con polvo y un respingo) y al rato se vuelve a abrir
--     sola, despacio, crujiendo. Si estaba cerrada, la golpean desde el otro lado y luego sacuden el pomo.
--   Cuadro: un cuadro cercano se suelta de la pared y cae de cara al suelo (o al mueble de debajo). Hasta el alba.
--   Bombilla: la bombilla de la sala parpadea cada vez más y revienta con chispas y cristalitos; las demás de la sala
--     se apagan a la vez y se queda a oscuras un rato (con un crujido detrás). La rota no vuelve hasta el alba.
--   Juguetes (cuarto de los niños): el caballito se mece solo, el móvil de la cuna gira y la muñeca de la merienda se
--     queda mirándote (hasta el alba).
-- Las puertas las anima CasaVista con los atributos del servidor: aquí se mueve la hoja a mano y, si el servidor
-- cambia algo de esa puerta mientras, se deja y CasaVista la vuelve a poner donde toca.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Ambiente = require(script.Parent.Parent.Ambiente)
local Sonido = require(script.Parent.Parent.Sonido)
local Util = require(script.Parent.Util)

local azar = Util.azar

---------------------------------------------------------------- portazo

local function puedePortazo(ctx): any?
	local cam = ctx.cam.Position
	if not Util.dentro(cam) then
		return nil
	end
	local cfg = Util.cfg
	local opciones = {}
	for _, el in CollectionService:GetTagged("Puerta") do
		local hoja = el:FindFirstChild("Hoja") :: BasePart?
		local pomo = el:FindFirstChild("Pomo") :: BasePart?
		local bisagra = el:GetAttribute("Bisagra") :: CFrame?
		if not hoja or not pomo or not bisagra or el:GetAttribute("Atacable") or el:GetAttribute("Refuerzo") then
			continue -- las de fuera no: parecería un bicho
		end
		local distancia = (hoja.Position - cam).Magnitude
		if distancia >= cfg.PuertaDistancia[1] and distancia <= cfg.PuertaDistancia[2] then
			table.insert(opciones, { puerta = el, hoja = hoja, pomo = pomo, bisagra = bisagra })
		end
	end
	return if #opciones > 0 then opciones[azar:NextInteger(1, #opciones)] else nil
end

local function lanzarPortazo(d)
	local cfg = Util.cfg
	local hoja, pomo, bisagra = d.hoja :: BasePart, d.pomo :: BasePart, d.bisagra :: CFrame
	-- Ángulo de ahora (CasaVista: hoja = bisagra · giro(a) · su sitio cerrado) y el sitio cerrado de hoja y pomo.
	local rel = bisagra:ToObjectSpace(hoja.CFrame)
	local a0 = math.atan2(-rel.Position.Z, rel.Position.X)
	local baseHoja = CFrame.Angles(0, -a0, 0) * rel
	local basePomo = CFrame.Angles(0, -a0, 0) * bisagra:ToObjectSpace(pomo.CFrame)
	-- Si el servidor toca esta puerta, se deja: CasaVista la pone donde toca (y aquí ya no se mueve la hoja).
	local tocada = false
	local function poner(a: number)
		if tocada then
			return
		end
		local cf = bisagra * CFrame.Angles(0, a, 0)
		hoja.CFrame = cf * baseHoja
		pomo.CFrame = cf * basePomo
	end
	for _, atributo in { "Abierta", "Golpes", "Intentos", "Portazo", "Refuerzo" } do
		Util.temporal(d.puerta:GetAttributeChangedSignal(atributo):Connect(function()
			tocada = true
		end))
	end
	local choca = hoja.CanCollide
	-- Al acabar, la colisión como la tiene ahora el servidor (Casa.publicar: choca si está cerrada), por si alguien la
	-- ha abierto o cerrado durante el susto.
	Util.alAcabar(function()
		hoja.CanCollide = not d.puerta:GetAttribute("Abierta")
	end)
	local function animar(desde: number, hasta: number, segundos: number, estilo: (number) -> number): boolean
		local t0 = os.clock()
		while true do
			if tocada then
				return false
			end
			local k = math.min(1, (os.clock() - t0) / segundos)
			poner(desde + (hasta - desde) * estilo(k))
			if k >= 1 then
				return true
			end
			task.wait()
		end
	end
	local cam = Util.camara().Position
	if math.abs(a0) > math.rad(20) then
		-- Abierta: portazo.
		if not animar(a0, 0, 0.16, function(k)
			return k * k
		end) then
			return
		end
		hoja.CanCollide = true
		Sonido.en("PuertaGolpe", hoja.Position)
		Util.polvo(hoja.Position + Vector3.new(0, hoja.Size.Y / 2 + 0.3, 0), 1)
		if (hoja.Position - cam).Magnitude < 25 then
			Util.tiron(0.5)
		end
		animar(0, a0 * 0.04, 0.08, function(k)
			return math.sin(k * math.pi)
		end) -- rebota un poco
		task.wait(Util.entre(cfg.PuertaCerrada))
		if tocada then
			return
		end
		-- Se vuelve a abrir sola, despacio.
		Sonido.en("Puerta", hoja.Position, 0.6)
		hoja.CanCollide = choca
		animar(0, a0, 3.5, function(k)
			return (1 - math.cos(k * math.pi)) / 2
		end)
	else
		-- Cerrada: algo la golpea desde el otro lado y luego intenta abrirla (si alguien la toca mientras, se para).
		local otroLado = (hoja.Position - cam) * Vector3.new(1, 0, 1)
		local desde = hoja.Position + (if otroLado.Magnitude > 0 then otroLado.Unit else Vector3.zero) * 1.5
		for golpe = 1, 2 do
			if tocada then
				return
			end
			Sonido.en("PuertaGolpe", desde, if golpe == 1 then 1 else 0.92)
			Util.polvo(hoja.Position + Vector3.new(0, hoja.Size.Y / 2 + 0.3, 0), 0.6)
			if (hoja.Position - cam).Magnitude < 20 then
				Util.tiron(0.35)
			end
			for i = 1, 6 do
				poner(a0 + math.rad(if i % 2 == 0 then 2.5 else -2.5))
				task.wait(0.04)
			end
			poner(a0)
			task.wait(0.7)
		end
		task.wait(1.2)
		if tocada then
			return
		end
		Sonido.en("Puerta", pomo.Position, 1.3) -- el pomo traquetea
		for i = 1, 8 do
			poner(a0 + math.rad(if i % 2 == 0 then 0.8 else -0.8))
			task.wait(0.05)
		end
		poner(a0)
		task.wait(1)
	end
end

---------------------------------------------------------------- cuadro

local caidos: { [Model]: boolean } = {}

local function puedeCuadro(ctx): any?
	local cam = ctx.cam.Position
	local casa = Util.casa()
	if not casa or not Util.dentro(cam) then
		return nil
	end
	local cfg = Util.cfg
	local opciones = {}
	for _, m in casa:GetChildren() do
		if not m:IsA("Model") or not string.find(m.Name, "^Cuadro") or caidos[m] then
			continue
		end
		local pivote = m:GetPivot()
		local distancia = (pivote.Position - cam).Magnitude
		if distancia < cfg.CuadroDistancia[1] or distancia > cfg.CuadroDistancia[2]
			or Util.planta(pivote.Y) ~= Util.planta(ctx.pies.Y + 0.5) then
			continue
		end
		local suelo = Util.suelo(pivote.Position + pivote.LookVector * 0.6, 10)
		if suelo and pivote.Y - suelo > 2 then -- colgado (no el que ya está apoyado en el suelo)
			table.insert(opciones, { modelo = m, suelo = suelo })
		end
	end
	return if #opciones > 0 then opciones[azar:NextInteger(1, #opciones)] else nil
end

local function lanzarCuadro(d)
	local m = d.modelo :: Model
	caidos[m] = true
	local antes = m:GetPivot()
	Util.alAlba(function()
		caidos[m] = nil
		if m.Parent then
			m:PivotTo(antes)
		end
	end)
	local caja, tam = m:GetBoundingBox()
	local frente = antes.LookVector -- hacia la sala
	local derecha = antes.RightVector
	local abajo = caja.Position - antes.UpVector * (tam.Y / 2) -- el borde de abajo, en el centro
	local delPivote = antes:ToObjectSpace(CFrame.new(abajo)).Position -- de su borde de abajo a su pivote
	-- Dónde cae: en el suelo o en el mueble de debajo.
	local adelante = abajo + frente * (tam.Y / 2 + 0.3)
	local superficie = Util.encimaDeMuebles(Vector3.new(adelante.X, abajo.Y, adelante.Z), d.suelo, m)
	local final = superficie + tam.Z / 2 + 0.02
	local caida = math.max(0, abajo.Y - final)
	-- Se mueve un poco en el clavo...
	for i = 1, 5 do
		m:PivotTo(antes * CFrame.Angles(0, 0, math.rad(if i % 2 == 0 then 3 else -3)))
		task.wait(0.06)
	end
	-- ...y cae: el borde de abajo baja pegado a la pared y la parte de arriba se va hacia la sala hasta quedar boca abajo.
	local orientacion = antes.Rotation
	local function poner(bajado: number, giro: number)
		local base = abajo - Vector3.new(0, bajado, 0) + frente * 0.15 * giro / (math.pi / 2)
		local rot = CFrame.fromAxisAngle(derecha, -giro) * orientacion
		m:PivotTo(CFrame.new(base) * rot * CFrame.new(-delPivote))
	end
	local dura = 0.35 + caida * 0.04
	local t0 = os.clock()
	while true do
		local k = math.min(1, (os.clock() - t0) / dura)
		poner(caida * k * k, math.pi / 2 * math.min(1, k * 1.15) ^ 2)
		if k >= 1 then
			break
		end
		task.wait()
	end
	Sonido.en("CuadroCae", abajo - Vector3.new(0, caida, 0))
	Util.polvo(abajo - Vector3.new(0, caida - 0.2, 0) + frente * tam.Y / 2, 0.7)
	-- Rebota un poco al dar de cara.
	for _, g in { 0.12, 0.04, 0 } do
		poner(caida, math.pi / 2 - g)
		task.wait(0.06)
	end
	task.wait(1)
end

---------------------------------------------------------------- bombilla

local function puedeBombilla(ctx): any?
	local cam = ctx.cam.Position
	if not Util.dentro(cam) or not Util.hayLuz() then
		return nil
	end
	local mala = Config.Detalles.BombillaMala -- la del pasillo es de DetallesVista
	local malaEn = Vector3.new(mala[1], mala[2], mala[3])
	local mejor, distancia = nil, Util.cfg.BombillaDistancia
	for _, luz in Util.lamparasCerca(ctx.pies + Vector3.new(0, 3, 0), Util.cfg.BombillaDistancia) do
		local pieza = luz.Parent :: BasePart
		local dist = (pieza.Position - cam).Magnitude
		if dist < distancia and (pieza.Position - malaEn).Magnitude > 3 and Util.dentro(pieza.Position) then
			mejor, distancia = luz, dist
		end
	end
	if not mejor then
		return nil
	end
	local pieza = (mejor :: PointLight).Parent :: BasePart
	local demas = {}
	for _, luz in Util.lamparasCerca(pieza.Position - Vector3.new(0, 2, 0), 18) do
		if luz ~= mejor then
			table.insert(demas, luz)
		end
	end
	return { luz = mejor, demas = demas }
end

local function apagar(luz: PointLight)
	luz.Enabled = false
	local pieza = luz.Parent
	if pieza and pieza:IsA("BasePart") then
		pieza.Color = Util.APAGADA
	end
end

local function encender(luz: PointLight)
	if not luz.Parent then
		return
	end
	local hay = Util.hayLuz()
	luz.Enabled = hay
	Ambiente.factor[luz] = nil
	local pieza = luz.Parent
	if pieza:IsA("BasePart") then
		pieza.Color = if hay then Util.ENCENDIDA else Util.APAGADA
	end
end

local function lanzarBombilla(d)
	local cfg = Util.cfg
	local luz = d.luz :: PointLight
	local pieza = luz.Parent :: BasePart
	local donde = pieza.Position
	-- Parpadea cada vez más deprisa...
	Sonido.en("Parpadeo", donde, 0.95)
	local pasos = {}
	for i = 1, 14 do
		local rapido = 1 - i / 16
		table.insert(pasos, { if i % 2 == 0 then azar:NextNumber(0.6, 1) else azar:NextNumber(0, 0.12), 0.05 + 0.12 * rapido * azar:NextNumber(0.5, 1) })
	end
	table.insert(pasos, { 1.6, 0.06 }) -- un fogonazo antes de reventar
	Util.parpadeo({ luz }, pasos)
	-- ...y revienta: chispazo, cristalitos y la sala a oscuras.
	local cristal = Sonido.en("Cristal", donde, 1.7)
	cristal.Volume *= 0.55
	local destello = Instance.new("PointLight")
	destello.Color = Color3.fromRGB(255, 225, 180)
	destello.Brightness = 4
	destello.Range = 14
	local punto = Instance.new("Attachment")
	punto.WorldPosition = donde
	punto.Parent = workspace.Terrain
	destello.Parent = punto
	local chispas = Instance.new("ParticleEmitter")
	chispas.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	chispas.Color = ColorSequence.new(Color3.fromRGB(255, 210, 140))
	chispas.LightEmission = 1
	chispas.Size = NumberSequence.new(0.15, 0)
	chispas.Lifetime = NumberRange.new(0.3, 0.7)
	chispas.Speed = NumberRange.new(6, 12)
	chispas.SpreadAngle = Vector2.new(180, 180)
	chispas.Acceleration = Vector3.new(0, -30, 0)
	chispas.Rate = 0
	chispas.Parent = punto
	chispas:Emit(18)
	task.delay(0.08, destello.Destroy, destello)
	task.delay(1.5, punto.Destroy, punto)
	for _ = 1, 7 do
		local trozo = Util.pieza(Vector3.new(0.1, 0.1, 0.03), CFrame.new(donde) * CFrame.Angles(azar:NextNumber(0, 6), azar:NextNumber(0, 6), 0),
			Color3.fromRGB(230, 230, 220), workspace.Terrain, Enum.Material.Glass)
		trozo.Transparency = 0.3
		trozo.Anchored = false
		trozo.CanCollide = true
		trozo.Massless = true
		trozo.AssemblyLinearVelocity = Vector3.new(azar:NextNumber(-5, 5), azar:NextNumber(-2, 3), azar:NextNumber(-5, 5))
		task.delay(5, trozo.Destroy, trozo)
	end
	apagar(luz)
	-- El servidor no sabe que está rota: si el generador vuelve a arrancar la encendería. Se mantiene apagada hasta el alba.
	local vigila = luz:GetPropertyChangedSignal("Enabled"):Connect(function()
		if luz.Enabled then
			apagar(luz)
		end
	end)
	Util.alAlba(function()
		vigila:Disconnect()
		encender(luz)
	end)
	for _, otra in d.demas do
		apagar(otra)
	end
	Util.alAcabar(function()
		for _, otra in d.demas do
			encender(otra)
		end
	end)
	Util.tiron(0.3)
	-- A oscuras. A medio rato, algo cruje detrás.
	local oscuro = Util.entre(cfg.Oscuro)
	task.wait(oscuro * 0.45)
	local cf = Util.camara()
	Sonido.en("Cruje", cf.Position - Util.delante() * 4 - Vector3.new(0, 3, 0), 0.8)
	task.wait(oscuro * 0.55)
	-- Vuelven las demás, a tirones.
	if Util.hayLuz() and #d.demas > 0 then
		for _, otra in d.demas do
			otra.Enabled = true
		end
		Sonido.en("Parpadeo", (d.demas[1].Parent :: BasePart).Position, 1.05)
		Util.parpadeo(d.demas, { { 0.1, 0.1 }, { 0.7, 0.06 }, { 0, 0.15 }, { 1, 0.08 }, { 0.2, 0.06 }, { 1, 0.01 } })
	end
end

---------------------------------------------------------------- juguetes

local muneca: { [Model]: boolean } = {}

local function puedeJuguetes(ctx): any?
	local cam = ctx.cam.Position
	local casa = Util.casa()
	-- En el cuarto de los niños (arriba, x -39..-12, z 9..33) o asomado a su puerta.
	if not casa or cam.X < -40 or cam.X > -8 or cam.Z < 8 or cam.Z > 34 or Util.planta(ctx.pies.Y + 0.5) ~= 1 then
		return nil
	end
	local caballo = casa:FindFirstChild("Caballito")
	local movil = casa:FindFirstChild("MovilCuna")
	local m = casa:FindFirstChild("Muneca")
	if not caballo or not caballo:IsA("Model") then
		return nil
	end
	return {
		caballo = caballo,
		movil = if movil and movil:IsA("Model") then movil else nil,
		muneca = if m and m:IsA("Model") and not muneca[m] then m else nil,
	}
end

local function lanzarJuguetes(d)
	local caballo = d.caballo :: Model
	local movil = d.movil :: Model?
	local antesCaballo = caballo:GetPivot()
	local antesMovil = movil and movil:GetPivot()
	Util.alAcabar(function()
		caballo:PivotTo(antesCaballo)
	end)
	-- Música de la cuna, si ya hay sonido para ella.
	if movil and Config.Sonidos.CajaMusica then
		Util.temporal(Sonido.en("CajaMusica", (antesMovil :: CFrame).Position))
	end
	-- El caballito se mece solo (gira sobre un punto algo por encima del suelo, como sobre sus patines curvos) y se va
	-- parando; el móvil de la cuna da vueltas despacio.
	local t0 = os.clock()
	local ladoAntes = 0
	local dura = 9
	while os.clock() - t0 < dura do
		local t = os.clock() - t0
		local fuerza = math.rad(12) * math.exp(-t / 3.5) * math.min(1, t * 2)
		local fase = math.sin(t * 2 * math.pi / 1.3)
		caballo:PivotTo(antesCaballo * CFrame.new(0, 2.5, 0) * CFrame.Angles(fuerza * fase, 0, 0) * CFrame.new(0, -2.5, 0))
		local lado = if fase > 0 then 1 else -1
		if lado ~= ladoAntes and fuerza > math.rad(3) then
			ladoAntes = lado
			local s = Sonido.en("Cruje", antesCaballo.Position + Vector3.new(0, 1.5, 0), azar:NextNumber(1.25, 1.4))
			s.Volume *= 0.5
		end
		if movil then
			movil:PivotTo((antesMovil :: CFrame) * CFrame.Angles(0, t * 0.7 * math.exp(-t / 12), 0))
		end
		-- La muñeca se gira hacia ti en cuanto no la miras.
		local m = d.muneca :: Model?
		if m and not muneca[m] and Util.mirada(m:GetPivot().Position) < 0.4 then
			muneca[m] = true
			local antes = m:GetPivot()
			local cam = Util.camara().Position
			m:PivotTo(CFrame.lookAt(antes.Position, Vector3.new(cam.X, antes.Y, cam.Z)))
			Util.alAlba(function()
				muneca[m] = nil
				if m.Parent then
					m:PivotTo(antes)
				end
			end)
		end
		task.wait()
	end
	caballo:PivotTo(antesCaballo)
	if movil then
		local quieto = movil:GetPivot()
		Util.alAlba(function()
			if movil.Parent and movil:GetPivot() == quieto then
				movil:PivotTo(antesMovil :: CFrame)
			end
		end)
	end
end

return {
	Portazo = { puede = puedePortazo, lanzar = lanzarPortazo },
	Cuadro = { puede = puedeCuadro, lanzar = lanzarCuadro },
	Bombilla = { puede = puedeBombilla, lanzar = lanzarBombilla },
	Juguetes = { puede = puedeJuguetes, lanzar = lanzarJuguetes },
}
