-- Ojos en la oscuridad (pedido por el usuario: "mejorar la inmersión"): de noche y fuera, al barrer el bosque con la
-- linterna, a veces dos puntitos que devuelven la luz (verdosos o ámbar, muy flojos) asoman junto a un tronco a 30-70
-- studs, a altura de un animal o de una persona. Detalle en docs/sistemas/ojos.md.
--   Solo brillan dentro del cono de TU linterna (un ojo de verdad solo brilla con la luz de frente): fuera del haz,
--     nada. Parpadean; al mirarlos fijamente o acercarte se apagan y suena una Ramita en 3D desde allí, como algo que
--     se va. A veces son dos pares. Los falsos son de cada cliente (cada uno los suyos).
--   Los bichos de verdad que están fuera (Acechador, Golpeador, Bestia, Trepador en el tejado) también tienen ojos que
--     brillan con tu linterna, en el mismo sitio que los puntitos de su modelo y en todos los clientes igual: no se
--     apagan al mirarlos. Unos ojos que siguen ahí son un aviso de verdad.
-- Nunca dentro de la casa ni a menos de Config.Ojos.Nunca studs; en las cinemáticas, nada; con Rendimiento, solo los
-- de los bichos. Un repaso cada Config.Ojos.Cada segundos decide qué hay; el Heartbeat que los pinta solo está
-- conectado con la linterna encendida y algo que pintar.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Stats = require(ReplicatedStorage.Shared.Stats)
local AireVista = require(script.Parent.AireVista)
local Sonido = require(script.Parent.Sonido)

local OjosVista = {}

local CFG = Config.Ojos
local jugador = Players.LocalPlayer
local azar = Random.new()

local BLANCO = Color3.new(1, 1, 1)
local VAIVEN = 0.06 -- studs que se mueve la cabeza de los falsos (respira, mira)
local ESCONDE = 0.35 -- studs que se mete hacia el tronco al irse

type Ojo = { punto: Attachment, nucleo: Frame, halo: Frame, k: number }
type Par = {
	ojos: { Ojo },
	centro: Vector3, -- los falsos: el centro del par
	lado: Vector3, -- los falsos: hacia dónde se separan los ojos (y hacia dónde está el tronco, con signo)
	sep: number,
	semilla: number,
	muere: number, -- os.clock en que se va solo
	parpadea: number, -- os.clock del siguiente parpadeo
	cierra: number, -- os.clock hasta el que está con los ojos cerrados
	mirado: number, -- segundos que llevas mirándolo fijo
	huye: number?, -- os.clock en que empezó a irse
}
type Bicho = { cabeza: BasePart, ojos: { Ojo }, parpadea: number, cierra: number }

local falsos: { Par } = {}
local bichos: { [Model]: Bicho } = {}
local siguiente = 0 -- os.clock desde el que pueden salir otros falsos
local latido: RBXScriptConnection? = nil

-- Lo que el banco puede mirar.
OjosVista.estado = { falsos = falsos, bichos = bichos }
function OjosVista.pintando(): boolean
	return latido ~= nil
end

local function entre(par: { number }): number
	return azar:NextNumber(par[1], par[2])
end

local function rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function plano(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- ¿Está este punto dentro de la casa? (como AmbienteMiedo: con los anexos y sin el tejado).
function OjosVista.enCasa(p: Vector3): boolean
	if p.Y > Config.AmbienteMiedo.AltoCasa then
		return false
	end
	if math.abs(p.X) < Config.Casa.MedioX and math.abs(p.Z) < Config.Casa.MedioZ then
		return true
	end
	for _, a in Config.Casa.Anexos do
		if p.X > a[1] and p.X < a[2] and p.Z > a[3] and p.Z < a[4] then
			return true
		end
	end
	return false
end

-- Cuánto le da la luz a `punto` (0 a 1) desde una linterna en `luz` con ese alcance: entero en el centro del cono,
-- apagándose hacia el borde y hacia el final del alcance; fuera del haz, 0.
function OjosVista.enCono(luz: CFrame, punto: Vector3, alcance: number): number
	local hacia = punto - luz.Position
	local d = hacia.Magnitude
	if d < 1e-3 or d > alcance then
		return 0
	end
	local mitad = math.rad(Config.Linterna.Angulo)
	local angulo = math.acos(math.clamp(luz.LookVector:Dot(hacia / d), -1, 1))
	local k = math.clamp((mitad - angulo) / (mitad * (1 - CFG.Centro)), 0, 1)
	return k * math.clamp((alcance - d) / 6, 0, 1)
end

-- Hasta dónde brillan los ojos con la linterna de este jugador (el pase Luz la alarga).
function OjosVista.alcance(otro: Player): number
	return math.max(CFG.Lejos, Config.Linterna.Alcance * Stats.valor(otro, "Luz") * 1.3)
end

local function noche(): number
	local fase = workspace:GetAttribute("Fase")
	local inicio, fin = workspace:GetAttribute("FaseInicio"), workspace:GetAttribute("FaseFin")
	if type(inicio) ~= "number" or type(fin) ~= "number" then
		return 0
	end
	local p = math.clamp((workspace:GetServerTimeNow() - inicio) / math.max(1, fin - inicio), 0, 1)
	return AireVista.noche(fase, p)
end

-- Tu linterna: de dónde sale y hacia dónde mira (la luz de EquipoVista, colgada en Terrain), o nil apagada o en una
-- cinemática. Lo segundo, cuánto alumbra ahora (con poca pila parpadea: los ojos, con ella).
local function miLuz(): (CFrame?, number)
	local camara = workspace.CurrentCamera
	if jugador:GetAttribute("Linterna") ~= true or not camara or camara.CameraType ~= Enum.CameraType.Custom then
		return nil, 0
	end
	local punto = workspace.Terrain:FindFirstChild("Linterna")
	if punto and punto:IsA("Attachment") then
		local foco = punto:FindFirstChildOfClass("SpotLight")
		if foco and not foco.Enabled then
			return nil, 0
		end
		return punto.WorldCFrame, if foco then math.clamp(foco.Brightness / Config.Linterna.Brillo, 0, 1) else 1
	end
	return camara.CFrame, 1 -- recién encendida: aún sin su luz
end

-- Un ojo: un punto con un BillboardGui de pocos píxeles (de lejos no se pierde), sin luz que le influya y tapado por
-- lo que tenga delante (AlwaysOnTop = false: un tronco lo esconde). Empieza apagado.
local function nuevoOjo(padre: Instance, color: Color3): Ojo
	local punto = Instance.new("Attachment")
	punto.Name = "OjoBrillo"
	local t = CFG.Tam
	local cartel = Instance.new("BillboardGui")
	cartel.Name = "Ojo"
	cartel.Size = UDim2.new(t.Studs * CFG.Halo, t.Px * CFG.Halo, t.Studs * CFG.Halo, t.Px * CFG.Halo)
	cartel.LightInfluence = 0
	cartel.AlwaysOnTop = false
	cartel.MaxDistance = 2 * CFG.Lejos
	cartel.Adornee = punto
	cartel.Parent = punto
	local function bola(tam: number, c: Color3): Frame
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.Size = UDim2.fromScale(tam, tam)
		f.BorderSizePixel = 0
		f.BackgroundColor3 = c
		f.BackgroundTransparency = 1
		local esquina = Instance.new("UICorner")
		esquina.CornerRadius = UDim.new(0.5, 0)
		esquina.Parent = f
		f.Parent = cartel
		return f
	end
	local halo = bola(1, color)
	local nucleo = bola(1 / CFG.Halo, color:Lerp(BLANCO, 0.35))
	punto.Parent = padre
	return { punto = punto, nucleo = nucleo, halo = halo, k = 0 }
end

local function pintar(ojo: Ojo, k: number)
	k = math.clamp(k, 0, 1)
	if math.abs(ojo.k - k) < 0.01 and (k > 0 or ojo.k == 0) then
		return
	end
	ojo.k = k
	ojo.nucleo.BackgroundTransparency = 1 - k * (1 - CFG.Transparencia)
	ojo.halo.BackgroundTransparency = 1 - k * (1 - CFG.TransparenciaHalo)
end

local function quitarFalso(i: number)
	local par = falsos[i]
	for _, ojo in par.ojos do
		ojo.punto:Destroy()
	end
	table.remove(falsos, i)
end

local function quitarFalsos()
	for i = #falsos, 1, -1 do
		quitarFalso(i)
	end
end

local filtro = RaycastParams.new()
filtro.FilterType = Enum.RaycastFilterType.Exclude
filtro.RespectCanCollide = true
filtro.IgnoreWater = true
local function prepararFiltro()
	local lista: { Instance } = { workspace.CurrentCamera }
	if jugador.Character then
		table.insert(lista, jugador.Character)
	end
	local carpeta = workspace:FindFirstChild("Bichos")
	if carpeta then
		table.insert(lista, carpeta)
	end
	filtro.FilterDescendantsInstances = lista
end

-- ¿Se ve `hasta` desde `desde` sin nada en medio?
local function seVe(desde: Vector3, hasta: Vector3): boolean
	return workspace:Raycast(desde, hasta - desde, filtro) == nil
end

-- Un sitio para unos ojos junto a `tronco`, asomando por un lado (`signo`) desde donde mira la cámara: suelo de
-- verdad debajo, fuera de casa y visible. nil si no vale.
local function sitioJunto(camara: Vector3, tronco: BasePart, signo: number, alto: number): (Vector3?, Vector3?)
	local t = tronco.Position
	local mira = plano(t - camara)
	if mira.Magnitude < 1 then
		return nil, nil
	end
	mira = mira.Unit
	local lado = mira:Cross(Vector3.yAxis).Unit * signo
	local radio = math.min(tronco.Size.X, tronco.Size.Y, tronco.Size.Z) / 2
	local base = Vector3.new(t.X, camara.Y, t.Z) + lado * (radio + 0.55) + mira * 0.6
	local suelo = workspace:Raycast(base + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), filtro)
	local y = if suelo then suelo.Position.Y else t.Y - math.max(tronco.Size.X, tronco.Size.Y, tronco.Size.Z) / 2
	local p = Vector3.new(base.X, y + alto, base.Z)
	if OjosVista.enCasa(p) or not seVe(camara, p) then
		return nil, nil
	end
	return p, -lado -- los ojos se separan a lo ancho; al irse, se meten hacia el tronco
end

local function nuevoFalso(p: Vector3, lado: Vector3, persona: boolean, color: Color3, ahora: number)
	local sep = entre(if persona then CFG.Separacion.Persona else CFG.Separacion.Animal)
	local par: Par = {
		ojos = {},
		centro = p,
		lado = lado,
		sep = sep,
		semilla = azar:NextNumber(0, 100),
		muere = ahora + entre(CFG.Vida),
		parpadea = ahora + entre(CFG.Parpadeo),
		cierra = 0,
		mirado = 0,
		huye = nil,
	}
	for _ = 1, 2 do
		local ojo = nuevoOjo(workspace.Terrain, color)
		table.insert(par.ojos, ojo)
	end
	table.insert(falsos, par)
end

-- Intenta sacar unos ojos falsos (o dos pares) junto a los troncos que caen dentro del haz. true si salieron.
function OjosVista.sacar(luz: CFrame): boolean
	local camara = luz.Position
	local alcance = math.min(CFG.Distancia[2], OjosVista.alcance(jugador))
	local mitad = math.rad(Config.Linterna.Angulo) * CFG.Cono
	local candidatos: { BasePart } = {}
	for _, tronco in CollectionService:GetTagged("Pino") do
		if not tronco:IsA("BasePart") or not tronco:IsDescendantOf(workspace) then
			continue
		end
		local hacia = plano(tronco.Position - camara)
		local d = hacia.Magnitude
		if d < math.max(CFG.Nunca, CFG.Distancia[1]) or d > alcance then
			continue
		end
		local enPlano = plano(luz.LookVector)
		if enPlano.Magnitude < 0.2 or math.acos(math.clamp(enPlano.Unit:Dot(hacia / d), -1, 1)) > mitad then
			continue
		end
		table.insert(candidatos, tronco)
	end
	if #candidatos == 0 then
		return false
	end
	prepararFiltro()
	local ahora = os.clock()
	local persona = azar:NextNumber() < CFG.Persona
	local color = rgb(CFG.Colores[azar:NextInteger(1, #CFG.Colores)])
	local alto = entre(if persona then CFG.Alto.Persona else CFG.Alto.Animal)
	local primero: BasePart? = nil
	for _ = 1, math.min(6, #candidatos) do
		local tronco = candidatos[azar:NextInteger(1, #candidatos)]
		local signo = if azar:NextNumber() < 0.5 then -1 else 1
		local p, lado = sitioJunto(camara, tronco, signo, alto)
		if not p then
			p, lado = sitioJunto(camara, tronco, -signo, alto)
		end
		if p and lado then
			-- La luz tiene que dar en el sitio (el cono es en 3D: mirando al suelo, unos ojos de persona no salen).
			if OjosVista.enCono(luz, p, alcance + 6) <= 0 then
				continue
			end
			nuevoFalso(p, lado, persona, color, ahora)
			primero = tronco
			break
		end
	end
	if not primero then
		return false
	end
	-- A veces dos pares: el otro junto a otro tronco cercano (o al otro lado del mismo), de la misma clase.
	if azar:NextNumber() < CFG.Doble then
		for _ = 1, 4 do
			local otro = candidatos[azar:NextInteger(1, #candidatos)]
			if (otro.Position - (primero :: BasePart).Position).Magnitude > 15 then
				otro = primero :: BasePart
			end
			local p, lado = sitioJunto(camara, otro, if azar:NextNumber() < 0.5 then -1 else 1,
				entre(if persona then CFG.Alto.Persona else CFG.Alto.Animal))
			if p and lado and (p - falsos[#falsos].centro).Magnitude > 1.5 then
				nuevoFalso(p, lado, persona, color, ahora)
				break
			end
		end
	end
	return true
end

-- Al irse unos falsos: una Ramita en 3D un poco más allá, y a veces otra más lejos, como algo que se aleja.
local function ramita(p: Vector3, camara: Vector3)
	local R = CFG.Ramita
	local lejos = plano(p - camara)
	lejos = if lejos.Magnitude > 0.1 then lejos.Unit else Vector3.zAxis
	task.delay(R.Tras, function()
		local s = Sonido.en("Ramita", p + lejos * R.Lejos)
		s.Volume *= R.Volumen
	end)
	if azar:NextNumber() < R.Otra then
		task.delay(R.Tras + azar:NextNumber(0.5, 1), function()
			local s = Sonido.en("Ramita", p + lejos * R.Lejos * 2.5, 0.92)
			s.Volume *= R.Volumen * 0.7
		end)
	end
end

local function apagarTodo()
	for _, par in falsos do
		for _, ojo in par.ojos do
			pintar(ojo, 0)
		end
	end
	for _, b in bichos do
		for _, ojo in b.ojos do
			pintar(ojo, 0)
		end
	end
end

-- Cada fotograma (solo con la linterna encendida y algo que pintar): cuánto brilla cada ojo con tu luz.
local function fotograma(dt: number)
	local luz, fuerza = miLuz()
	local camara = workspace.CurrentCamera
	if not luz or not camara then
		apagarTodo()
		return
	end
	local ahora = os.clock()
	local alcance = OjosVista.alcance(jugador)
	local vista = camara.CFrame
	local fijo = math.cos(math.rad(CFG.Fijo))
	for i = #falsos, 1, -1 do
		local par = falsos[i]
		local k = 1
		if par.huye then
			local t = (ahora - par.huye) / CFG.Apagar
			if t >= 1 then
				quitarFalso(i)
				continue
			end
			k = 1 - t
		elseif ahora >= par.cierra and ahora >= par.parpadea then
			par.cierra = ahora + CFG.Cierre
			par.parpadea = ahora + entre(CFG.Parpadeo)
		end
		if ahora < par.cierra and not par.huye then
			k = 0
		end
		-- La cabeza se mueve un poco; al irse, se mete hacia el tronco.
		local n = par.semilla
		local vaiven = Vector3.new(math.noise(ahora * 0.6, n, 0), math.noise(ahora * 0.5, 0, n) * 0.5,
			math.noise(n, ahora * 0.6, 0)) * VAIVEN
		local esconde = if par.huye then par.lado * ESCONDE * ((ahora - par.huye) / CFG.Apagar) else Vector3.zero
		local centro = par.centro + vaiven + esconde
		local luzAqui = OjosVista.enCono(luz, centro, alcance)
		k *= luzAqui * fuerza
		local derecha = -par.lado
		par.ojos[1].punto.WorldPosition = centro - derecha * par.sep / 2
		par.ojos[2].punto.WorldPosition = centro + derecha * par.sep / 2
		pintar(par.ojos[1], k)
		pintar(par.ojos[2], k)
		if par.huye then
			continue
		end
		-- Mirarlos fijamente (con la luz encima) o acercarte los apaga: algo que se va.
		local hacia = centro - vista.Position
		local d = hacia.Magnitude
		if luzAqui > 0.3 and vista.LookVector:Dot(hacia / d) >= fijo then
			par.mirado += dt
		end
		if par.mirado >= CFG.Mirada or d < CFG.Cerca then
			par.huye = ahora
			ramita(par.centro, vista.Position)
		end
	end
	for _, b in bichos do
		local cabeza = b.cabeza
		if ahora >= b.cierra and ahora >= b.parpadea then
			b.cierra = ahora + CFG.Cierre
			b.parpadea = ahora + entre(CFG.ParpadeoBicho)
		end
		local k = 0
		if ahora >= b.cierra and not OjosVista.enCasa(cabeza.Position) then
			local hacia = vista.Position - cabeza.Position
			local d = hacia.Magnitude
			if d > CFG.BichoCerca and cabeza.CFrame.LookVector:Dot(hacia / d) > CFG.Cara then
				k = math.clamp((d - CFG.BichoCerca) / 4, 0, 1)
			end
		end
		for _, ojo in b.ojos do
			pintar(ojo, if k > 0 then k * fuerza * OjosVista.enCono(luz, ojo.punto.WorldPosition, alcance) else 0)
		end
	end
end

local function desconectar()
	if latido then
		latido:Disconnect()
		latido = nil
		apagarTodo()
	end
end

-- Los bichos de fuera con ojos: se les ponen al llegar y se les quitan al irse (o de día).
local function repasarBichos(hay: boolean)
	local carpeta = workspace:FindFirstChild("Bichos")
	for modelo, b in bichos do
		if not hay or not carpeta or modelo.Parent ~= carpeta or not b.cabeza:IsDescendantOf(modelo) then
			for _, ojo in b.ojos do
				ojo.punto:Destroy()
			end
			bichos[modelo] = nil
		end
	end
	if not hay or not carpeta then
		return
	end
	local ahora = os.clock()
	for _, modelo in carpeta:GetChildren() do
		local datos = CFG.Bichos[modelo.Name]
		if not datos or not modelo:IsA("Model") or bichos[modelo] then
			continue
		end
		local cabeza = modelo:FindFirstChild("Cabeza")
		if not cabeza or not cabeza:IsA("BasePart") then
			continue
		end
		local color = rgb(CFG.Colores[datos.Color] or CFG.Colores[1])
		local ojos = {}
		for _, sitio in datos.Ojos do
			local ojo = nuevoOjo(cabeza, color)
			ojo.punto.Position = Vector3.new(sitio[1], sitio[2], sitio[3])
			table.insert(ojos, ojo)
		end
		bichos[modelo] = { cabeza = cabeza, ojos = ojos, parpadea = ahora + entre(CFG.ParpadeoBicho), cierra = 0 }
	end
end

-- El repaso: qué bichos hay, si toca sacar falsos y si hace falta el Heartbeat.
function OjosVista.repasar()
	local ahora = os.clock()
	local hayNoche = noche() >= CFG.Noche
	local poco = jugador:GetAttribute("Rendimiento") == true
	repasarBichos(hayNoche)
	if not hayNoche or poco then
		quitarFalsos()
	end
	for i = #falsos, 1, -1 do
		if ahora >= falsos[i].muere and not falsos[i].huye then
			quitarFalso(i) -- se fue sin que lo vieras (o apagado: ni lo notas)
		end
	end
	local luz = miLuz()
	if luz and hayNoche and not poco and #falsos == 0 and ahora >= siguiente and not OjosVista.enCasa(luz.Position) then
		if OjosVista.sacar(luz) then
			siguiente = ahora + entre(CFG.Entre)
		else
			siguiente = ahora + 2 -- ningún tronco en el haz: se vuelve a probar en un rato
		end
	end
	local cerca = false
	if luz then
		for _, b in bichos do
			if (b.cabeza.Position - luz.Position).Magnitude < OjosVista.alcance(jugador) + 5 then
				cerca = true
				break
			end
		end
	end
	if luz and (#falsos > 0 or cerca) then
		if not latido then
			latido = RunService.Heartbeat:Connect(fotograma)
		end
	else
		desconectar()
	end
end

function OjosVista.start()
	siguiente = os.clock() + entre(CFG.Entre)
	task.spawn(function()
		while true do
			task.wait(CFG.Cada)
			OjosVista.repasar()
		end
	end)
end

return OjosVista
