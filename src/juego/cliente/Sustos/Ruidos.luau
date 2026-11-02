-- Sustos de oído (ver Sustos/init):
--   Pasos: estando abajo, alguien cruza el piso de arriba (con polvillo que cae del techo a cada paso) y se para justo
--     encima de ti; un crujido y más polvo. Estando arriba, al revés: anda por abajo y se para justo debajo.
--   Pared: algo araña por dentro de la pared que tienes al lado, de un lado a otro, y luego da dos golpes.
local RunService = game:GetService("RunService")

local Sonido = require(script.Parent.Parent.Sonido)
local Util = require(script.Parent.Util)

local azar = Util.azar

---------------------------------------------------------------- pasos

local function puedePasos(ctx): any?
	local cam = ctx.cam.Position
	if not Util.dentro(cam) then
		return nil
	end
	local planta = Util.planta(ctx.pies.Y + 0.5)
	if planta == 2 then
		return nil
	end
	local arriba = planta == 0
	-- Donde acaban: justo encima (o debajo) del jugador. Por dónde vienen: de un lado, dentro de la casa.
	local techo = Util.techo(cam)
	if arriba and (not techo or techo - ctx.pies.Y > 14) then
		return nil -- bajo el hueco del vestíbulo no hay piso justo encima
	end
	local y = if arriba then (techo :: number) + 0.6 else 1.3
	local fin = Vector3.new(cam.X, y, cam.Z)
	for _ = 1, 8 do
		local angulo = azar:NextNumber(0, math.pi * 2)
		local inicio = fin + Vector3.new(math.cos(angulo), 0, math.sin(angulo)) * Util.cfg.PasosLargo
		if Util.dentro(inicio) then
			return { inicio = inicio, fin = fin, arriba = arriba, techo = techo }
		end
	end
	return nil
end

local function lanzarPasos(d)
	local cfg = Util.cfg
	local sonidos: { Sound } = {}
	local donde = d.inicio
	local t0 = os.clock()
	Util.temporal(RunService.Heartbeat:Connect(function()
		local k = math.min(1, (os.clock() - t0) / cfg.PasosTiempo)
		donde = d.inicio:Lerp(d.fin, k)
		for _, s in sonidos do
			local punto = s.Parent
			if punto and punto:IsA("Attachment") then
				punto.WorldPosition = donde
			end
		end
	end))
	local siguientePolvo = 0
	local siguientePaso = 0 -- reloj: uno nuevo solo cuando el anterior ha durado lo suyo (aunque tarde en cargar)
	while os.clock() - t0 < cfg.PasosTiempo do
		local ultimo = sonidos[#sonidos]
		if os.clock() >= siguientePaso and (not ultimo or not ultimo.IsPlaying) then
			local s = Sonido.en("PasosArriba", donde, azar:NextNumber(0.95, 1.03))
			Util.temporal(s)
			table.insert(sonidos, s)
			-- Sin cargar aún TimeLength es 0: entonces un mínimo para no apilarlos.
			local dura = if s.TimeLength > 0.5 then s.TimeLength / s.PlaybackSpeed else Util.cfg.PasosMinimo
			siguientePaso = os.clock() + math.max(dura, Util.cfg.PasosMinimo)
		end
		if d.arriba and os.clock() >= siguientePolvo then
			siguientePolvo = os.clock() + azar:NextNumber(0.7, 1.1)
			local techo = Util.techo(Vector3.new(donde.X, (d.techo or 13) - 3, donde.Z))
			if techo then
				Util.polvo(Vector3.new(donde.X, techo - 0.15, donde.Z), 0.6)
			end
		end
		task.wait(0.1)
	end
	for _, s in sonidos do
		s:Stop()
	end
	-- Se ha parado justo encima (o debajo). Un momento de silencio y un crujido.
	task.wait(azar:NextNumber(1.6, 2.4))
	Sonido.en("Cruje", d.fin, 0.8)
	if d.arriba and d.techo then
		Util.polvo(Vector3.new(d.fin.X, d.techo - 0.15, d.fin.Z), 1.6)
		Sonido.en("Polvo", Vector3.new(d.fin.X, d.techo - 0.2, d.fin.Z))
	end
	task.wait(1.5)
end

---------------------------------------------------------------- pared

local function puedePared(ctx): any?
	local cam = ctx.cam.Position
	if not Util.dentro(cam, Util.cfg.Junto) then
		return nil
	end
	local casa = Util.casa()
	local desde = cam - Vector3.new(0, 1.5, 0) -- a la altura del pecho
	local mejor, distancia = nil, math.huge
	for i = 0, 7 do
		local angulo = i * math.pi / 4 + azar:NextNumber(-0.2, 0.2)
		local r = Util.rayo(desde, Vector3.new(math.cos(angulo), 0, math.sin(angulo)) * 7)
		if r and casa and r.Instance:IsDescendantOf(casa) and math.abs(r.Normal.Y) < 0.3 then
			local dist = (r.Position - desde).Magnitude
			if dist > 1.5 and dist < distancia then
				mejor, distancia = r, dist
			end
		end
	end
	return mejor and { punto = mejor.Position, normal = mejor.Normal }
end

local function lanzarPared(d)
	-- El ruido va por dentro de la pared, a lo largo de ella, subiendo y bajando un poco.
	local dentro = d.punto - d.normal * 0.5
	local largo = d.normal:Cross(Vector3.yAxis).Unit * (if azar:NextNumber() < 0.5 then 1 else -1)
	local s = Util.temporal(Sonido.en("Aranazo", dentro - largo * 1.8, azar:NextNumber(0.92, 1.05)))
	local punto = s.Parent :: Attachment
	local t0 = os.clock()
	local dura = if s.TimeLength > 0.5 then s.TimeLength / s.PlaybackSpeed else 3
	Util.polvo(d.punto + d.normal * 0.1 + Vector3.new(0, 1.2, 0), 0.3)
	while os.clock() - t0 < dura and s.IsPlaying do
		local k = (os.clock() - t0) / dura
		punto.WorldPosition = dentro + largo * (-1.8 + 3.6 * k) + Vector3.new(0, math.sin(k * 9) * 0.4, 0)
		task.wait()
	end
	-- Silencio... y dos golpes secos desde dentro.
	task.wait(azar:NextNumber(1, 1.6))
	for _ = 1, 2 do
		Sonido.en("Toc", punto.WorldPosition, 0.6)
		Util.polvo(d.punto + d.normal * 0.1 + Vector3.new(0, 1.5, 0), 0.25)
		task.wait(0.45)
	end
	task.wait(1)
end

return {
	Pasos = { puede = puedePasos, lanzar = lanzarPasos },
	Pared = { puede = puedePared, lanzar = lanzarPared },
}
