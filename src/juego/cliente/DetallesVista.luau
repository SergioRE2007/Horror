-- Detalles vivos de la casa (11.9, pedido por el usuario: "detallitos"). Todo en el cliente, en un solo bucle que solo
-- trabaja cerca de la cámara (Config.Detalles.Cerca). La chimenea va aparte, en ChimeneaVista.
--   Reloj de pie del vestíbulo: tic-tac cada segundo y, de noche, campanadas a algunas horas en punto (a las 0, doce).
--   Nevera: zumba con el generador encendido; cada rato se para con un traqueteo y luego vuelve.
--   Grifos que gotean (fregadero y lavabo): la gota se ve caer y suena al llegar abajo.
--   Bombillas (con el generador): la del pasillo zumba y parpadea a menudo; alguna otra cerca, de vez en cuando. Cuando
--   el Trepador baja por la chimenea, todas tiemblan un par de segundos (aviso).
--   De noche, con la cámara dentro de la casa: tuberías que golpean dentro de las paredes.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Ambiente = require(script.Parent.Ambiente)
local Sonido = require(script.Parent.Sonido)

local DetallesVista = {}

local D = Config.Detalles
local ENCENDIDA = Color3.fromRGB(255, 214, 160) -- los colores de la bombilla de Generador
local APAGADA = Color3.fromRGB(70, 66, 60)
local azar = Random.new()

local function v(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end
local RELOJ = v(D.Reloj)
local MALA = v(D.BombillaMala)
local GRIFOS = {} :: { { desde: Vector3, suelo: number } }
for _, g in D.Grifos do
	table.insert(GRIFOS, { desde = v(g), suelo = g[4] })
end
local TUBERIAS = {} :: { Vector3 }
for _, t in D.Tuberias do
	table.insert(TUBERIAS, v(t))
end

type Bombilla = { luz: PointLight, pieza: BasePart, ocupada: boolean }
local bombillas: { Bombilla } = {}
local mala: Bombilla? = nil

local function entre(par: { number }): number
	return azar:NextNumber(par[1], par[2])
end

local function camara(): Vector3
	return workspace.CurrentCamera.CFrame.Position
end

local function cerca(p: Vector3, distancia: number?): boolean
	return (p - camara()).Magnitude < (distancia or D.Cerca)
end

local function dentroDeCasa(p: Vector3): boolean
	return math.abs(p.X) < Config.Casa.MedioX and math.abs(p.Z) < Config.Casa.MedioZ and p.Y < 28
end

-- Un punto fijo del mundo del que cuelgan los sonidos en bucle.
local function punto(posicion: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.WorldPosition = posicion
	a.Parent = workspace.Terrain
	return a
end

local function bucle(nombre: string, donde: Attachment): Sound
	local s = Sonido.bucle(nombre, donde)
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 4
	s.RollOffMaxDistance = Config.Sonidos[nombre].Alcance
	s:Pause()
	return s
end

---------------------------------------------------------------- bombillas

-- La bombilla se queda con `f` (0 a 1) de su luz; la pieza, más o menos encendida a juego.
local function brillo(b: Bombilla, f: number?)
	Ambiente.factor[b.luz] = f
	if b.luz.Enabled then
		b.pieza.Color = APAGADA:Lerp(ENCENDIDA, f or 1)
	end
end

-- Un parpadeo: unos cortes rápidos de luz y vuelve. Con `fuerte`, más largo y casi a oscuras (aviso del Trepador).
local function parpadear(b: Bombilla, fuerte: boolean?, conSonido: boolean?)
	if b.ocupada or not b.luz.Enabled then
		return
	end
	b.ocupada = true
	if conSonido then
		Sonido.en("Parpadeo", b.pieza.Position, azar:NextNumber(0.95, 1.05))
	end
	task.spawn(function()
		local fin = os.clock() + (if fuerte then azar:NextNumber(1.8, 2.6) else azar:NextNumber(0.4, 1.1))
		while os.clock() < fin and b.luz.Enabled and b.pieza.Parent do
			brillo(b, if azar:NextNumber() < 0.5 then azar:NextNumber(0, 0.15) else azar:NextNumber(0.5, 1))
			task.wait(azar:NextNumber(0.03, if fuerte then 0.09 else 0.14))
		end
		brillo(b, nil)
		if not b.luz.Enabled and b.pieza.Parent then
			b.pieza.Color = APAGADA
		end
		b.ocupada = false
	end)
end

local function apuntarBombilla(luz: Instance)
	if not luz:IsA("PointLight") then
		return
	end
	local pieza = luz.Parent
	if not pieza or pieza.Name ~= "Lampara" or not pieza:IsA("BasePart") then
		return
	end
	local b: Bombilla = { luz = luz, pieza = pieza, ocupada = false }
	table.insert(bombillas, b)
	luz.Destroying:Once(function()
		local i = table.find(bombillas, b)
		if i then
			table.remove(bombillas, i)
		end
		Ambiente.factor[luz] = nil
		if mala == b then
			mala = nil
		end
	end)
	-- La mala: la más cercana a D.BombillaMala (a menos de 3 studs).
	if (pieza.Position - MALA).Magnitude < 3
		and (not mala or (pieza.Position - MALA).Magnitude < ((mala :: Bombilla).pieza.Position - MALA).Magnitude)
	then
		mala = b
	end
end

---------------------------------------------------------------- grifos

local function gota(desde: Vector3, suelo: number)
	local g = Instance.new("Part")
	g.Shape = Enum.PartType.Ball
	g.Size = Vector3.one * 0.07
	g.Anchored = true
	g.CanCollide = false
	g.CanQuery = false
	g.CanTouch = false
	g.CastShadow = false
	g.Material = Enum.Material.Glass
	g.Color = Color3.fromRGB(190, 200, 205)
	g.Transparency = 0.35
	g.Position = desde
	g.Parent = workspace
	-- Antes de caer, la gota se hincha un momento en la boca del grifo.
	local hinchar = TweenService:Create(g, TweenInfo.new(0.5), { Size = Vector3.one * 0.1 })
	hinchar:Play()
	hinchar.Completed:Once(function()
		local caida = math.sqrt(2 * math.max(0.1, desde.Y - suelo) / workspace.Gravity * 3) -- algo más lenta, para verla
		local t = TweenService:Create(g, TweenInfo.new(caida, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = Vector3.new(desde.X, suelo, desde.Z) })
		t:Play()
		t.Completed:Once(function()
			Sonido.en("Gota", Vector3.new(desde.X, suelo, desde.Z), azar:NextNumber(0.9, 1.15))
			g:Destroy()
		end)
	end)
end

---------------------------------------------------------------- arranque

function DetallesVista.start()
	local mapa = workspace:WaitForChild("Mapa")
	mapa.DescendantAdded:Connect(apuntarBombilla)
	for _, d in mapa:GetDescendants() do
		apuntarBombilla(d)
	end

	-- Al bajar el Trepador por la chimenea, las luces de la casa tiemblan.
	Remotes.Trepador.OnClientEvent:Connect(function(tipo: string)
		if tipo == "Baja" then
			for _, b in bombillas do
				if dentroDeCasa(b.pieza.Position) then
					parpadear(b, true, false)
				end
			end
		end
	end)

	local casa = mapa:WaitForChild("Casa")
	local generador: Instance? = nil
	local function luzEncendida(): boolean
		if not generador or not (generador :: Instance).Parent then
			generador = CollectionService:GetTagged("Generador")[1]
		end
		return generador ~= nil and (generador :: Instance):GetAttribute("Encendido") == true
	end

	-- Lo que se busca en el mapa cuando ya esté hecho (el servidor lo construye al empezar).
	local reloj: Vector3? = nil
	local nevera: Vector3? = nil
	local zumbaNevera: Sound? = nil
	local zumbaBombilla: Sound? = nil
	local function buscar()
		if not reloj then
			local mejor = math.huge
			for _, m in casa:GetChildren() do
				if m.Name == "RelojPiePH" and m:IsA("Model") then
					local d = (m:GetPivot().Position - RELOJ).Magnitude
					if d < 3 and d < mejor then
						mejor = d
						reloj = m:GetPivot().Position + Vector3.new(0, 6.5, 0)
					end
				end
			end
		end
		if not nevera then
			local m = casa:FindFirstChild("NeveraVieja")
			if m and m:IsA("Model") then
				nevera = m:GetPivot().Position + Vector3.new(0, 1.5, 0)
				zumbaNevera = bucle("Nevera", punto(nevera :: Vector3))
			end
		end
		if zumbaBombilla and (not mala or zumbaBombilla.Parent ~= (mala :: Bombilla).pieza) then
			zumbaBombilla:Destroy() -- la bombilla mala ya no está (o es otra)
			zumbaBombilla = nil
		end
		if mala and not zumbaBombilla then
			zumbaBombilla = bucle("Zumbido", (mala :: Bombilla).pieza)
		end
	end

	-- Cuándo toca cada cosa (os.clock).
	local proximo = {
		tic = 0,
		gotas = {} :: { number },
		mala = 0,
		otras = os.clock() + entre(D.ParpadeoOtras),
		tuberia = os.clock() + entre(D.Tuberia),
		nevera = os.clock() + entre(D.Nevera.Encendida),
		buscar = 0,
	}
	local tac = false
	local neveraEnMarcha = true
	local horaAntes = math.floor(Lighting.ClockTime)
	local campanadas = false -- dando la hora ahora mismo

	local function darLaHora(hora: number)
		if campanadas or not reloj then
			return
		end
		campanadas = true
		task.spawn(function()
			for _ = 1, if hora % 12 == 0 then 12 else hora % 12 do
				Sonido.en("Campanada", reloj :: Vector3)
				task.wait(2.4)
			end
			campanadas = false
		end)
	end

	RunService.Heartbeat:Connect(function()
		if not workspace.CurrentCamera then
			return
		end
		local ahora = os.clock()
		if ahora >= proximo.buscar then
			proximo.buscar = ahora + 2
			buscar()
		end
		local hayLuz = luzEncendida()
		local noche = workspace:GetAttribute("Fase") == "Noche"
		local cam = camara()

		-- Reloj: tic-tac y campanadas.
		if reloj then
			if ahora >= proximo.tic then
				proximo.tic = ahora + 1
				if cerca(reloj :: Vector3, Config.Sonidos.Tic.Alcance) then
					tac = not tac
					Sonido.en("Tic", reloj :: Vector3, if tac then 0.9 else 1)
				end
			end
			local hora = math.floor(Lighting.ClockTime)
			if hora ~= horaAntes then
				horaAntes = hora
				if noche and table.find(D.Campanadas, hora) then
					darLaHora(hora)
				end
			end
		end

		-- Nevera: con luz zumba y a ratos se para.
		if zumbaNevera and nevera then
			if ahora >= proximo.nevera then
				neveraEnMarcha = not neveraEnMarcha
				proximo.nevera = ahora + entre(if neveraEnMarcha then D.Nevera.Encendida else D.Nevera.Parada)
				if not neveraEnMarcha and hayLuz and cerca(nevera :: Vector3) then
					Sonido.en("NeveraClac", nevera :: Vector3)
				end
			end
			local suena = hayLuz and neveraEnMarcha and cerca(nevera :: Vector3)
			if suena and not zumbaNevera.IsPlaying then
				zumbaNevera:Resume()
			elseif not suena and zumbaNevera.IsPlaying then
				zumbaNevera:Pause()
			end
		end

		-- Grifos.
		for i, grifo in GRIFOS do
			if ahora >= (proximo.gotas[i] or 0) then
				proximo.gotas[i] = ahora + entre(D.Gota)
				if cerca(grifo.desde, 30) then
					gota(grifo.desde, grifo.suelo)
				end
			end
		end

		-- Bombillas.
		if mala and zumbaBombilla then
			local b = mala :: Bombilla
			local suena = b.luz.Enabled and cerca(b.pieza.Position)
			if suena and not zumbaBombilla.IsPlaying then
				zumbaBombilla:Resume()
			elseif not suena and zumbaBombilla.IsPlaying then
				zumbaBombilla:Pause()
			end
			if ahora >= proximo.mala then
				proximo.mala = ahora + entre(D.ParpadeoMala)
				if suena then
					parpadear(b, false, true)
				end
			end
		end
		if hayLuz and ahora >= proximo.otras then
			proximo.otras = ahora + entre(D.ParpadeoOtras)
			local cercanas = {}
			for _, b in bombillas do
				if b ~= mala and b.luz.Enabled and cerca(b.pieza.Position, 30) then
					table.insert(cercanas, b)
				end
			end
			if #cercanas > 0 then
				parpadear(cercanas[azar:NextInteger(1, #cercanas)], false, true)
			end
		end

		-- Tuberías: de noche y dentro de la casa.
		if ahora >= proximo.tuberia then
			proximo.tuberia = ahora + entre(D.Tuberia)
			if noche and dentroDeCasa(cam) then
				Sonido.en("Tuberia", TUBERIAS[azar:NextInteger(1, #TUBERIAS)], azar:NextNumber(0.85, 1.1))
			end
		end
	end)
end

return DetallesVista
