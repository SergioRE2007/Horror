-- Ambiente que da miedo (14.3), por capas y casi sin música. Todo en el cliente, en un solo bucle cada CFG.Paso s.
--   CasaFondo: de noche, con la cámara dentro de la casa, el fondo de casa vieja en bucle muy bajo (viento apagado
--   contra las paredes, la madera a lo lejos); fuera se apaga despacio. Lo de fuera ya lo pone Ambiente (Viento).
--   Tension: un zumbido grave que sube despacio cuando un bicho está cerca de la cámara o cazando dentro de la casa
--   (con la cámara también dentro), y baja cuando se va. También con la Bestia: ella no tiene música propia, solo sus
--   ruidos. El Imitador no cuenta mientras finge ser una persona en la puerta (si no, delataría que no es un amigo).
--   Calla en las cinemáticas y en la muerte (cámara Scriptable) y baja escondido, donde manda el latido (MuerteVista).
--   Rafaga: de vez en cuando, de noche y con la cámara en casa, una ráfaga contra una ventana cercana, en 3D desde fuera
--   del cristal.
-- No repite lo de Ambiente (viento, crujidos sueltos) ni lo de DetallesVista (reloj, tuberías, nevera, bombillas).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Sonido = require(script.Parent.Sonido)

local AmbienteMiedo = {}

-- Números a ojo.
local CFG = Config.AmbienteMiedo

local jugador = Players.LocalPlayer
local azar = Random.new()

-- ¿Está este punto dentro de la casa? (como Caza.dentroDeCasa, con los anexos y sin el tejado).
local function enCasa(p: Vector3): boolean
	if p.Y > CFG.AltoCasa then
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

-- Cuánta tensión pide ahora lo que hay en la carpeta Bichos (0 a 1).
local function tensionBichos(camara: Vector3, camaraEnCasa: boolean): number
	local carpeta = workspace:FindFirstChild("Bichos")
	if not carpeta then
		return 0
	end
	local nivel = 0
	for _, modelo in carpeta:GetChildren() do
		if not modelo:IsA("Model") or (modelo.Name == "Imitador" and not modelo:GetAttribute("Abierto")) then
			continue
		end
		local raiz = (modelo:FindFirstChild("HumanoidRootPart") or modelo.PrimaryPart) :: BasePart?
		if not raiz then
			continue
		end
		local d = (raiz.Position - camara).Magnitude
		nivel = math.max(nivel, math.clamp((CFG.TensionLejos - d) / (CFG.TensionLejos - CFG.TensionCerca), 0, 1))
		if camaraEnCasa and enCasa(raiz.Position) then
			nivel = math.max(nivel, CFG.TensionDentro)
		end
	end
	return nivel
end

-- Acerca `actual` a `meta` como mucho `subir` (o `bajar`) por segundo.
local function acercar(actual: number, meta: number, subir: number, bajar: number, dt: number): number
	if meta > actual then
		return math.min(meta, actual + subir * dt)
	end
	return math.max(meta, actual - bajar * dt)
end

-- Pone el volumen de un bucle (0 a 1 de su volumen de Config) y lo pausa cuando no suena, para no gastar.
local function ajustar(s: Sound, base: number, k: number)
	s.Volume = base * k
	if k > 0 and not s.IsPlaying then
		s:Resume()
	elseif k <= 0 and s.IsPlaying then
		s:Pause()
	end
end

-- Una ráfaga contra la ventana de la casa más o menos cercana (una al azar de las que están al alcance).
local function rafaga(camara: Vector3)
	local cerca = {}
	for _, ventana in CollectionService:GetTagged("Ventana") do
		local centro = ventana:GetAttribute("Centro")
		if typeof(centro) == "CFrame" and (centro.Position - camara).Magnitude < CFG.RafagaAlcance then
			table.insert(cerca, centro)
		end
	end
	if #cerca == 0 then
		return
	end
	local centro: CFrame = cerca[azar:NextInteger(1, #cerca)]
	-- El LookVector de Centro mira hacia fuera (CargarVista): suena un poco por fuera del cristal.
	Sonido.en("Rafaga", centro.Position + centro.LookVector * CFG.RafagaFuera, azar:NextNumber(CFG.RafagaTono[1], CFG.RafagaTono[2]))
end

function AmbienteMiedo.start()
	local fondo = Sonido.bucle("CasaFondo")
	local fondoBase = fondo.Volume
	local tension = Sonido.bucle("Tension")
	local tensionBase = tension.Volume
	ajustar(fondo, fondoBase, 0)
	ajustar(tension, tensionBase, 0)

	task.spawn(function()
		local kFondo, kTension = 0, 0
		local proximaRafaga = os.clock() + azar:NextNumber(CFG.RafagaCada[1], CFG.RafagaCada[2])
		local antes = os.clock()
		while true do
			task.wait(CFG.Paso)
			local ahora = os.clock()
			local dt = ahora - antes
			antes = ahora
			local camara = workspace.CurrentCamera
			local p = camara.CFrame.Position
			local noche = workspace:GetAttribute("Fase") == "Noche"
			local dentro = enCasa(p)

			kFondo = acercar(kFondo, if noche and dentro then 1 else 0, CFG.FondoSubir, CFG.FondoBajar, dt)
			ajustar(fondo, fondoBase, kFondo)

			-- Cinemática o muerte: cámara Scriptable sin estar escondido (escondido también lo es, pero ahí sí suena; y
			-- mirando por la mirilla o entre las cortinas, atributo local Vistazo de MirarVista, también).
			local escondido = typeof(jugador:GetAttribute("Escondido")) == "CFrame"
			local cine = camara.CameraType == Enum.CameraType.Scriptable and not escondido
				and not jugador:GetAttribute("Vistazo")
			local meta = 0
			if not cine and not jugador:GetAttribute("Muerto") then
				meta = tensionBichos(p, dentro) * (if escondido then CFG.TensionEscondido else 1)
			end
			-- En las cinemáticas se corta deprisa (lo suyo es lo de la escena); si no, sube y baja despacio.
			kTension = acercar(kTension, meta, CFG.TensionSubir, if cine then 2 else CFG.TensionBajar, dt)
			ajustar(tension, tensionBase, kTension)
			tension.PlaybackSpeed = CFG.TensionTono[1] + (CFG.TensionTono[2] - CFG.TensionTono[1]) * kTension

			if ahora >= proximaRafaga then
				proximaRafaga = ahora + azar:NextNumber(CFG.RafagaCada[1], CFG.RafagaCada[2])
				if noche and dentro then
					rafaga(p)
				end
			end
		end
	end)
end

return AmbienteMiedo
