-- Llegada en coche y coche destrozado tras la noche 1 (16.8; diseño: "llegas en tu coche (cinemática al empezar) y la
-- primera noche un bicho te lo destroza").
--   Día 1 y noche 1: tu coche, entero, aparcado en la carretera delante de la casa (una copia sin prompts del de Coche,
--   etiqueta CocheLlegada y atributo Sitio). El de verdad, el que se arregla, está escondido (Coche.esconder).
--   Partida nueva (nunca una cargada: Coche.cargada): escena de llegada (cliente LlegadaCocheVista) solo para los que
--   están al empezar: atributo LlegadaInicio del Player = hora del servidor en que empieza. Mientras dura, EscenaLlegada
--   del workspace a true (el tutorial espera); ya está a true desde que arranca el servidor (antes de que nadie tenga
--   los datos listos) hasta saber si la partida es nueva, y siempre vuelve a false, como mucho a los Config.Llegada.Tope s
--   de empezar la escena. Quien la salta lo dice (remote Llegada, "Saltar": solo durante la escena, una vez cada uno);
--   cuando la han saltado todos los que la ven, se acaba ya.
--   Al amanecer de la noche 1 (visto en directo, no cargado): la copia se cambia por el coche destrozado (sin ruedas de
--   delante, de morros, torcido, capó abierto, arañazos y humo). Cada uno, al acercarse (Ver studs), recibe un aviso de
--   una línea. Cuando ya lo han visto todos (o ha anochecido), pasados Minimo s y sin nadie a menos de Lejos studs, "se
--   lo llevan" al garaje: la copia se va y sale el de verdad (allí se arregla y de allí sale la huida). Tope: el
--   amanecer siguiente. El motor suelto (Mapa.motorSuelto, el que se monta en el coche) sale con el destrozado: el día 1
--   está dentro del coche entero. Una partida guardada lo trae en sus pesados (Cargar), como siempre.
--   Una partida cargada de la noche 2 en adelante: como antes, el coche destrozado en el garaje y nada delante.
-- Modo de pruebas: ServerStorage.Prueba:Fire("Llegada") repite la escena; ("Destrozar") y ("Garaje") los dos pasos.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Prueba = require(ReplicatedStorage.Shared.Prueba)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Cargar = require(script.Parent.Cargar)
local Ciclo = require(script.Parent.Ciclo)
local Coche = require(script.Parent.Coche)
local Mapa = require(script.Parent.Mapa)

local Llegada = {}

local L = Config.Llegada
-- Las piezas que en el de verdad faltan y en el entero se ven (MapaAnexos.construirCoche).
local PIEZAS = { "Motor", "Rueda1", "Rueda2", "Rueda3", "Rueda4", "Bateria", "Radiador" }

local frente: Model? = nil -- la copia de delante de la casa (entera o destrozada)
local estado = "" -- "entero", "destrozado" o "garaje"
local destrozadoEn = 0 -- os.clock() del amanecer en que se destrozó
local vistos: { [Player]: boolean } = {} -- a quién le ha llegado ya el aviso
local vez = 0 -- cada vez que se pone EscenaLlegada (para el tope)
local viendo: { [Player]: boolean } = {} -- los que ven la escena ahora (false = ya la ha saltado)
local casa: Instance = workspace -- donde va la copia: con el coche de verdad (la casa), aunque esté escondido

-- Donde aparca: en la carretera delante de la casa, mirando a ella (+z). El coche mira a su -z (Mapa).
local function sitio(): CFrame
	local p = Vector3.new(L.Sitio[1], 0.15, L.Sitio[2]) -- 0.15 = encima de la carretera de tierra (Mapa)
	return CFrame.lookAt(p, p + Vector3.new(0, 0, 1))
end

-- `sinTope`: la espera del principio (hasta saber si la partida es nueva): cargarla puede tardar más que Tope y el
-- tutorial no debe empezar antes de la escena. Ciclo siempre arranca (Partida.start vuelve aunque falle).
local function marcar(si: boolean, sinTope: boolean?)
	vez += 1
	workspace:SetAttribute("EscenaLlegada", si)
	if si and not sinTope then
		local mia = vez
		task.delay(L.Tope, function()
			if vez == mia then
				workspace:SetAttribute("EscenaLlegada", false)
			end
		end)
	end
end

-- Una copia del coche de Coche, solo para verla: sin etiquetas, atributos, prompts ni mandos; solo chocan el chasis y la
-- cabina. `entero`: con todas sus piezas, sin ladrillos ni arañazos y el capó cerrado (como HuidaVista); si no, como
-- está el de verdad (destrozado), sin los ladrillos de debajo.
local function copia(entero: boolean): Model
	local original = Coche.modelo()
	local base = original:GetAttribute("Sitio") :: CFrame
	local m = original:Clone()
	m.Name = "CocheLlegada"
	m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent -- la escena lo ve desde lejos por la carretera
	for nombre in m:GetAttributes() do
		m:SetAttribute(nombre, nil)
	end
	for _, d in m:GetDescendants() do
		for _, etiqueta in CollectionService:GetTags(d) do
			CollectionService:RemoveTag(d, etiqueta)
		end
		if d:IsA("ProximityPrompt") then
			d:Destroy()
		end
	end
	for _, etiqueta in CollectionService:GetTags(m) do
		CollectionService:RemoveTag(m, etiqueta)
	end
	for _, hijo in m:GetChildren() do
		local nombre = hijo.Name
		if nombre == "Mando" or nombre == "Conducir" or string.sub(nombre, 1, 9) == "Ladrillos"
			or (entero and (nombre == "Marcas" or nombre == "Arañazo")) then
			hijo:Destroy()
		end
	end
	m.WorldPivot = base
	if entero then
		for _, nombre in PIEZAS do
			local parte = m:FindFirstChild(nombre)
			if parte and parte:IsA("BasePart") then
				parte.Transparency = if parte:GetAttribute("ConMalla") == true then 1 else 0
				for _, malla in parte:GetChildren() do
					if malla:IsA("BasePart") then
						malla.Transparency = 0
					end
				end
			end
		end
		local capo = m:FindFirstChild("Capo")
		if capo and capo:IsA("MeshPart") then -- el de Blender: cerrado sobre el hueco del motor
			capo.CFrame = base * CFrame.new(0, 3.12, -4.2)
			for _, nombre in { "Motor", "Bateria" } do -- asoman por encima del capó cerrado
				local pieza = m:FindFirstChild(nombre)
				for _, d in if pieza then pieza:GetDescendants() else {} do
					if d:IsA("BasePart") then
						d.Transparency = 1
					end
				end
			end
		elseif capo and capo:IsA("BasePart") then -- de bloques: más grueso, tapa también el motor y la batería
			capo.Size = Vector3.new(6.2, 1.2, 4.3)
			capo.CFrame = base * CFrame.new(0, 3.3, -3.9)
		end
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			local choca = d.Parent == m and (d.Name == "Chasis" or d.Name == "Cabina")
			d.Anchored = true
			d.CanCollide = choca
			d.CanQuery = choca
			d.CanTouch = false
		end
	end
	return m
end

local function quitarFrente()
	if frente then
		frente:Destroy()
		frente = nil
	end
end

local function ponerFrente(m: Model, cf: CFrame)
	quitarFrente()
	m:PivotTo(cf)
	m:SetAttribute("Sitio", cf)
	CollectionService:AddTag(m, "CocheLlegada")
	m.Parent = casa
	frente = m
end

-- Día 1 y noche 1: el entero delante y el de verdad escondido.
local function ponerEntero()
	if estado == "entero" then
		return
	end
	Coche.esconder(true)
	ponerFrente(copia(true), sitio())
	estado = "entero"
end

-- Se lo llevan al garaje: fuera la copia, sale el de verdad. A quien no lo había visto, el aviso igual.
local function alGaraje()
	if estado == "garaje" then
		return
	end
	local avisar = estado == "destrozado"
	estado = "garaje"
	quitarFrente()
	Coche.esconder(false)
	if avisar then
		for _, j in Players:GetPlayers() do
			if not vistos[j] then
				Remotes.Aviso:FireClient(j, Lang.t(j, "Your car is wrecked. There's no way out now."))
			end
		end
	end
	table.clear(vistos)
end

-- Al amanecer de la noche 1: destrozado, de morros (sin las ruedas de delante) y torcido, con humo del motor.
local function destrozar()
	if estado == "destrozado" then
		return
	end
	local m = copia(false)
	local caida = math.atan2(0.95, 8.7) -- baja el morro lo que medía el chasis sobre el suelo (eje: las ruedas de atrás)
	local cf = sitio() * CFrame.Angles(0, math.rad(L.Giro), 0) * CFrame.new(0, 0, 4.3) * CFrame.Angles(-caida, 0, 0)
		* CFrame.new(0, 0, -4.3)
	local motor = m:FindFirstChild("Motor")
	if motor and motor:IsA("BasePart") then
		local humo = Instance.new("Smoke")
		humo.Color = Color3.fromRGB(70, 68, 66)
		humo.Opacity = 0.12
		humo.RiseVelocity = 2.5
		humo.Size = 2.5
		humo.Parent = motor
	end
	-- Arañazos también del otro lado (con la malla; sin ella, las rayas de bloques ya están).
	local marcas = m:FindFirstChild("Marcas")
	if marcas and marcas:IsA("BasePart") then
		local otro = marcas:Clone()
		otro.Name = "Marcas"
		otro.CFrame = marcas.CFrame * CFrame.new(6.5, 0.3, -1.2)
		for _, d in otro:GetChildren() do
			if d:IsA("Decal") then
				d.Face = Enum.NormalId.Right
			end
		end
		otro.Parent = m
	end
	ponerFrente(m, cf)
	-- El motor arrancado, en el suelo (si no hay ya uno suelto o montado: una partida del día 1 guardada antes lo traía).
	local hayMotor = (Coche.modelo():GetAttribute("Motor") or 0) > 0
	for _, pieza in CollectionService:GetTagged("Pesado") do
		if pieza:GetAttribute("Tipo") == "Motor" and pieza:IsDescendantOf(workspace) then
			hayMotor = true
		end
	end
	if not hayMotor then
		Cargar.nuevo("Motor", Mapa.motorSuelto)
	end
	estado = "destrozado"
	destrozadoEn = os.clock()
	table.clear(vistos)
end

local function raizDe(j: Player): BasePart?
	return j.Character and j.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Con el destrozado delante: el aviso a quien se acerca y llevárselo cuando toca.
local function vigilar()
	while true do
		task.wait(1)
		if estado ~= "destrozado" or not frente then
			continue
		end
		local donde = frente:GetPivot().Position
		local todos, cerca = true, false
		for _, j in Players:GetPlayers() do
			local raiz = raizDe(j)
			local d = if raiz then (raiz.Position - donde).Magnitude else math.huge
			if d <= L.Ver and not vistos[j] then
				vistos[j] = true
				Remotes.Aviso:FireClient(j, Lang.t(j, "Your car is wrecked. There's no way out now."))
			end
			todos = todos and vistos[j] == true
			cerca = cerca or d < L.Lejos
		end
		local fase = Ciclo.fase()
		if (todos or fase == "Noche") and os.clock() - destrozadoEn >= L.Minimo and not cerca then
			alGaraje()
		end
	end
end

-- La escena de llegada para los que están ahora (espera un poco a que tengan personaje).
local function escena()
	marcar(true)
	local quienes = Players:GetPlayers()
	local limite = os.clock() + L.Espera
	while os.clock() < limite do
		if #quienes == 0 then
			quienes = Players:GetPlayers()
		end
		local listos = #quienes > 0
		for _, j in quienes do
			if j.Parent and not raizDe(j) then
				listos = false
			end
		end
		if listos then
			break
		end
		task.wait(0.2)
	end
	if #quienes > 0 then
		task.wait(0.5) -- que su cliente haya arrancado LlegadaCocheVista (si no, lo mira al arrancar)
		local inicio = workspace:GetServerTimeNow()
		table.clear(viendo)
		for _, j in quienes do
			if j.Parent then
				j:SetAttribute("LlegadaInicio", inicio)
				viendo[j] = true
			end
		end
		-- Hasta que acaba o la han saltado todos los que siguen aquí.
		local hasta = os.clock() + L.Segundos + 1
		while os.clock() < hasta do
			local alguien = false
			for j, ve in viendo do
				alguien = alguien or (ve and j.Parent ~= nil)
			end
			if not alguien then
				break
			end
			task.wait(0.2)
		end
		table.clear(viendo)
		for _, j in quienes do
			if j.Parent then
				j:SetAttribute("LlegadaInicio", nil)
			end
		end
	end
	marcar(false)
end

-- La ha saltado (LlegadaCocheVista): solo quien la está viendo y una vez.
local function saltar(j: Player, que: unknown)
	if que ~= "Saltar" or viendo[j] ~= true then
		return
	end
	viendo[j] = false
end

function Llegada.start()
	if not L.Activa then
		Cargar.nuevo("Motor", Mapa.motorSuelto) -- sin llegada, el motor suelto desde el principio (como antes)
		return
	end
	casa = Coche.modelo().Parent or workspace -- antes de esconderlo
	-- Hasta saber si la partida es nueva (el primer día, después de cargarla), el tutorial espera, sin tope.
	marcar(true, true)
	Remotes.Llegada.OnServerEvent:Connect(saltar)
	local primera = true
	local antes: { fase: string, noche: number }? = nil
	Ciclo.alCambiar(function(fase, noche)
		local previo = antes
		antes = { fase = fase, noche = noche }
		if noche <= 1 then
			ponerEntero()
		elseif fase == "Dia" and noche == 2 and previo and previo.fase == "Noche" and previo.noche == 1 then
			destrozar()
		elseif fase == "Dia" or estado ~= "destrozado" then
			-- Cargada de la noche 2 en adelante, o el destrozado aún delante al amanecer siguiente (o al volver a
			-- empezar el día): al garaje. El destrozado sigue delante de noche hasta que vigilar se lo lleve.
			alGaraje()
		end
		if primera then
			primera = false
			if fase == "Dia" and noche == 1 and not Coche.cargada() then
				escena()
			else
				marcar(false)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(j)
		vistos[j] = nil
		viendo[j] = nil
	end)
	task.spawn(vigilar)
	if not Prueba.activa() then
		return
	end
	task.spawn(function() -- el BindableEvent lo crea Director, que arranca después
		ServerStorage:WaitForChild("Prueba").Event:Connect(function(que: string)
			if que == "Llegada" then
				estado = ""
				ponerEntero()
				escena()
			elseif que == "Destrozar" then
				destrozar()
			elseif que == "Garaje" then
				alGaraje()
			end
		end)
	end)
end

return Llegada
