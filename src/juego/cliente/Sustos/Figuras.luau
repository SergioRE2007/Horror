-- Sustos con una figura (ver Sustos/init):
--   Silueta: una figura negra fuera, tras una ventana de la sala (abajo, o en el balcón). Si la miras de lleno o la
--     alumbras, da un respingo y se aparta de un salto; si no la ves, se va sola.
--   Pasillo: una figura de cara pálida al fondo de un pasillo (el del sótano, la galería o la entrada). Al mirarla o
--     alumbrarla, la linterna y las bombillas de allí parpadean: en un corte aparece más cerca y al siguiente ya no está.
--   Susurro: un susurro al oído, de un lado. Desde la noche CFG.DetrasDesde, a veces hay algo justo detrás al girarte.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Sonido = require(script.Parent.Parent.Sonido)
local Util = require(script.Parent.Util)

local azar = Util.azar

-- Mirándola de lleno o con la linterna encima (y sin nada en medio).
local function vista(p: Vector3, angulo: number, ignorar: { Instance }?): boolean
	local cam = Util.camara().Position
	if (p - cam).Magnitude > 60 then
		return false
	end
	local cos = Util.mirada(p)
	local alumbra = Util.linternaEncendida() and cos > math.cos(math.rad(Config.Linterna.Angulo * 0.7))
	return (cos > math.cos(math.rad(angulo)) or alumbra) and Util.libre(cam, p, ignorar)
end

---------------------------------------------------------------- silueta

local function puedeSilueta(ctx): any?
	local cam = ctx.cam.Position
	if not Util.dentro(cam) then
		return nil
	end
	local cfg = Util.cfg
	local opciones = {}
	for _, el in CollectionService:GetTagged("Ventana") do
		local centro = el:GetAttribute("Centro") :: CFrame?
		local pie = el:GetAttribute("Fuera") :: Vector3?
		if not centro or not pie or not el:IsA("Model") then
			continue
		end
		local fuera = centro.LookVector
		local distancia = (centro.Position - cam).Magnitude
		local hacia = ((centro.Position - cam) * Vector3.new(1, 0, 1)).Unit
		if distancia < cfg.SiluetaDistancia[1] or distancia > cfg.SiluetaDistancia[2]
			or pie.Y < centro.Position.Y - 9 -- de una ventana de arriba solo se verían los pies (salvo el balcón)
			or (cam - centro.Position):Dot(fuera) > 0 -- la cámara está fuera
			or hacia:Dot(fuera) < 0.45 -- muy de lado: no se vería por la ventana
		then
			continue
		end
		-- Persiana es un booleano del servidor (true = cortinas cerradas).
		if not ctx.forzado and (el:GetAttribute("Persiana") == true or Util.mirada(centro.Position) > 0.6) then
			continue -- con las cortinas corridas no se ve; mirando ya hacia ella, no sorprende
		end
		if Util.libre(cam, centro.Position, { el }) then
			table.insert(opciones, { ventana = el, centro = centro, pie = pie })
		end
	end
	return if #opciones > 0 then opciones[azar:NextInteger(1, #opciones)] else nil
end

local function lanzarSilueta(d)
	local cfg = Util.cfg
	local cam = Util.camara().Position
	local hacia = ((d.centro.Position - cam) * Vector3.new(1, 0, 1)).Unit
	-- En la línea de la cámara a través de la ventana, unos studs por fuera, de pie en el suelo de fuera.
	local base = Vector3.new(d.centro.Position.X, d.pie.Y + 4, d.centro.Position.Z) + hacia * cfg.SiluetaFuera
	local suelo = Util.suelo(base, 8, { d.ventana }) or d.pie.Y
	local pies = Vector3.new(base.X, suelo, base.Z)
	local figura = Util.figura(false)
	Util.temporal(figura.modelo)
	local mira = CFrame.lookAt(pies, pies - hacia)
	local t0 = os.clock()
	local vistaDesde: number? = nil
	local huye: number? = nil
	local lado = d.centro.RightVector * (if azar:NextNumber() < 0.5 then 1 else -1)
	local hecho = false
	Util.temporal(RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		if huye then
			-- Se aparta de un salto hacia un lado, fuera del marco.
			local k = math.min(1, (os.clock() - huye) / 0.35)
			local suave = 1 - (1 - k) ^ 3
			figura.poner(mira.Rotation + pies + lado * (6 * suave) - hacia * (1.5 * suave), t)
			if k >= 1 then
				hecho = true
			end
			return
		end
		figura.poner(mira, t)
		local pecho = pies + Vector3.new(0, 5.5, 0)
		if vista(pecho, 9, { d.ventana }) then
			vistaDesde = vistaDesde or os.clock()
			if os.clock() - (vistaDesde :: number) > 0.2 then
				huye = os.clock()
				local s = Sonido.tocar("Sobresalto")
				s.Volume *= 0.8
			end
		else
			vistaDesde = nil
			if t > cfg.SiluetaMax then
				hecho = true -- no la ha visto: se va sin más (ahora no se la ve)
			end
		end
	end))
	while not hecho do
		task.wait(0.1)
	end
end

---------------------------------------------------------------- pasillo

local function puedePasillo(ctx): any?
	local cam = ctx.cam.Position
	if not Util.dentro(cam) or (not ctx.forzado and not Util.linternaEncendida()) then
		return nil
	end
	local cfg = Util.cfg
	local opciones = {}
	for _, f in cfg.Fondos do
		local p = Vector3.new(f[1], f[2], f[3])
		local distancia = (p - cam).Magnitude
		if Util.planta(p.Y) ~= Util.planta(ctx.pies.Y + 0.5) or distancia < cfg.FondoDistancia[1] or distancia > cfg.FondoDistancia[2] then
			continue
		end
		local suelo = Util.suelo(p + Vector3.new(0, 4, 0), 8)
		if not suelo then
			continue
		end
		local pies = Vector3.new(p.X, suelo, p.Z)
		if (ctx.forzado or Util.mirada(pies + Vector3.new(0, 6, 0)) < 0.85) and Util.libre(cam, pies + Vector3.new(0, 6, 0)) then
			table.insert(opciones, pies)
		end
	end
	return if #opciones > 0 then opciones[azar:NextInteger(1, #opciones)] else nil
end

local function lanzarPasillo(pies: Vector3)
	local cfg = Util.cfg
	local figura = Util.figura(true)
	Util.temporal(figura.modelo)
	local donde = pies
	local t0 = os.clock()
	local function mirando(): CFrame
		local cam = Util.camara().Position
		return CFrame.lookAt(donde, Vector3.new(cam.X, donde.Y, cam.Z))
	end
	local vistaDesde: number? = nil
	local visto = false
	local salir = false
	local conexion = Util.temporal(RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		figura.poner(mirando(), t)
		if visto then
			return
		end
		if vista(donde + Vector3.new(0, 6, 0), 9) then
			vistaDesde = vistaDesde or os.clock()
			if os.clock() - (vistaDesde :: number) > cfg.PasilloMirar then
				visto = true
			end
		else
			vistaDesde = nil
			if t > cfg.PasilloMax then
				salir = true
			end
		end
	end))
	while not visto and not salir do
		task.wait(0.05)
	end
	if salir then
		return
	end
	-- Parpadeo: en el tercer corte está más cerca (a medio camino) y se ve un instante; al siguiente, nada.
	local cam = Util.camara().Position
	local cerca = donde:Lerp(Vector3.new(cam.X, donde.Y, cam.Z), 0.5)
	local sueloCerca = Util.suelo(cerca + Vector3.new(0, 4, 0), 8)
	local luces = Util.lamparasCerca(donde, 22)
	for _, luz in Util.lamparasCerca(cam, 16) do
		if not table.find(luces, luz) then
			table.insert(luces, luz)
		end
	end
	local pieza = luces[1] and luces[1].Parent :: BasePart?
	Sonido.en("Parpadeo", if pieza then pieza.Position else cam, 0.95)
	Util.parpadeo(luces, {
		{ 0.05, 0.08 }, { 1, 0.07 }, { 0, 0.14 }, { 1, 0.16 }, { 0, 0.3 }, { 0.6, 0.05 }, { 0, 0.08 }, { 1, 0.01 },
	}, function(i)
		if i == 4 and sueloCerca then
			donde = Vector3.new(cerca.X, sueloCerca, cerca.Z) -- más cerca, mirándote
			Sonido.tocar("Sobresalto")
			Util.tiron(0.6)
		elseif i == 5 then
			conexion:Disconnect()
			figura.modelo:Destroy()
		end
	end)
end

---------------------------------------------------------------- susurro

local function puedeSusurro(ctx): any?
	if not Util.dentro(ctx.cam.Position, Util.cfg.Junto) then
		return nil
	end
	local d = { detras = nil :: Vector3? }
	if ctx.noche >= Util.cfg.DetrasDesde and (ctx.forzado or azar:NextNumber() < Util.cfg.DetrasProb) then
		-- Algo de pie justo detrás, si hay sitio (sin pared en medio y con suelo).
		local atras = -Util.delante()
		local cabeza = ctx.cam.Position + atras * 3
		local suelo = Util.suelo(cabeza, 9)
		if Util.libre(ctx.cam.Position, cabeza + atras * 0.8) and suelo and math.abs(suelo - ctx.pies.Y) < 1.5 then
			d.detras = Vector3.new(cabeza.X, suelo, cabeza.Z)
		end
	end
	return d
end

local function lanzarSusurro(d)
	local cf = Util.camara()
	local lado = if azar:NextNumber() < 0.5 then 1 else -1
	Sonido.en("Susurro", cf.Position + cf.RightVector * (1.2 * lado) - cf.LookVector * 0.5)
	if not d.detras then
		task.wait(3)
		return
	end
	local pies = d.detras :: Vector3
	local figura = Util.figura(true)
	Util.temporal(figura.modelo)
	local t0 = os.clock()
	local visto = false
	local conexion = Util.temporal(RunService.RenderStepped:Connect(function()
		local cam = Util.camara().Position
		figura.poner(CFrame.lookAt(pies, Vector3.new(cam.X, pies.Y, cam.Z)), os.clock() - t0)
		if not visto and Util.mirada(pies + Vector3.new(0, 6.5, 0)) > 0.55 then
			visto = true
		end
	end))
	while not visto and os.clock() - t0 < 5 do
		task.wait()
	end
	if not visto then
		return -- no se ha girado: se va sin que la vea
	end
	Sonido.tocar("Sobresalto")
	Util.tiron(1)
	task.wait(0.25)
	Util.parpadeo(Util.lamparasCerca(pies, 16), Util.CORTE, function(i)
		if i == 3 then
			conexion:Disconnect()
			figura.modelo:Destroy()
		end
	end)
end

return {
	Silueta = { puede = puedeSilueta, lanzar = lanzarSilueta },
	Pasillo = { puede = puedePasillo, lanzar = lanzarPasillo },
	Susurro = { puede = puedeSusurro, lanzar = lanzarSusurro },
}
