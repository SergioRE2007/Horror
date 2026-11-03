-- Lo que hacen tus manos en primera persona (pedido por el usuario: "que se vea como tú lo abres o lo cierras con las
-- manos… y eso con todas las animaciones posibles"). Las manos y cómo se mueven, en Manos; aquí, cada cosa:
--   Al pulsar un cartel (ProximityPrompt) tuyo:
--     cortinas: las dos manos cogen el borde de cada paño y lo corren con él (abrir o cerrar);
--     puerta: la derecha coge el pomo, lo gira y acompaña la hoja (si está cerrada con llave, el pomo traquetea y la
--       mano con él); coger un objeto: la mano baja, lo coge y lo guarda; cargar algo pesado: las dos van a por ello;
--     generador: coge la cuerda y da el tirón (apagarlo: aprieta el botón); esconderse: empuja la puerta del armario o
--       levanta la colcha; leer una pista: coge el papel y lo sube; enchufar el móvil; el banco del taller;
--     mantener pulsado: la palanca del sótano (tira de ella), la cerilla para prender el rastro (la enciende y la baja
--       al suelo) y el volante del coche al huir;
--     cualquier otro: la mano va hacia él y lo toca.
--   Sostener: la linterna encendida en la izquierda (de ella sale la luz; con poca pila, la sacude), el móvil abierto
--     en la derecha, la pistola de bengalas, y lo pesado en las dos manos mientras lo llevas.
--   Foto: las dos manos suben la cámara a la cara (lo pide EquipoVista al hacer la foto).
--   Cambiar la pila de la linterna o el carrete de la cámara: con las dos manos, todo el rato que dura.
--   Lo que coges vuela hasta tu mano (una copia: el de verdad lo quita el servidor).
--   Trepando por una escalera de mano, las manos van de peldaño en peldaño; en el aire, los brazos se abren.
--   Un susto (Sustos): las manos libres suben de golpe por reflejo.
--   Al salir del escondite, las dos manos empujan para salir. Al morir, las manos se levantan temblando ante el bicho.
-- Las herramientas (hacha, sierra, martillo, llave) las agarra TrabajoVista con su propia capa.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Manos = require(script.Parent.Manos)

local ManosGestos = {}

local jugador = Players.LocalPlayer
local camara = workspace.CurrentCamera
local azar = Random.new()

-- ===== Las cosas que se llevan en la mano =====

local function pieza(m: Model, nombre: string, tam: Vector3, cf: CFrame, color: Color3, material: Enum.Material?,
	cilindro: boolean?): Part
	local p = Instance.new("Part")
	p.Name = nombre
	p.Size = tam
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if cilindro then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Parent = m
	return p
end

-- Un cilindro a lo largo del -Z del modelo (los de Roblox van a lo largo de su X).
local ALO_LARGO = CFrame.Angles(0, math.rad(90), 0)

-- Linterna vieja de metal oscuro: el cuerpo es el centro; la luz sale de su -Z (Manos.dondeCosa).
local function linterna(): Model
	local m = Instance.new("Model")
	m.Name = "LinternaMano"
	local metal = Color3.fromRGB(52, 52, 55)
	local cuerpo = pieza(m, "Cuerpo", Vector3.new(0.8, 0.17, 0.17), ALO_LARGO, metal, Enum.Material.Metal, true)
	m.PrimaryPart = cuerpo
	pieza(m, "Cabeza", Vector3.new(0.24, 0.27, 0.27), CFrame.new(0, 0, -0.5) * ALO_LARGO, metal, Enum.Material.Metal, true)
	local cristal = pieza(m, "Cristal", Vector3.new(0.03, 0.22, 0.22), CFrame.new(0, 0, -0.63) * ALO_LARGO,
		Color3.fromRGB(255, 240, 210), Enum.Material.Glass, true)
	cristal.Transparency = 0.15
	pieza(m, "Boton", Vector3.new(0.06, 0.04, 0.1), CFrame.new(0, 0.1, -0.2), Color3.fromRGB(30, 30, 30))
	pieza(m, "Culata", Vector3.new(0.05, 0.19, 0.19), CFrame.new(0, 0, 0.42) * ALO_LARGO, Color3.fromRGB(35, 35, 37),
		Enum.Material.Metal, true)
	return m
end

-- Cámara de fotos vieja: el cuerpo es el centro, el objetivo hacia -Z (lo que fotografías).
local function camaraFotos(): Model
	local m = Instance.new("Model")
	m.Name = "CamaraMano"
	local cuerpo = pieza(m, "Cuerpo", Vector3.new(0.85, 0.5, 0.3), CFrame.new(), Color3.fromRGB(38, 36, 34),
		Enum.Material.Fabric)
	m.PrimaryPart = cuerpo
	pieza(m, "Objetivo", Vector3.new(0.22, 0.3, 0.3), CFrame.new(0.05, -0.02, -0.24) * ALO_LARGO, Color3.fromRGB(25, 25, 26),
		Enum.Material.Metal, true)
	pieza(m, "Flash", Vector3.new(0.28, 0.14, 0.06), CFrame.new(-0.24, 0.17, -0.16), Color3.fromRGB(200, 205, 210),
		Enum.Material.Glass)
	pieza(m, "Visor", Vector3.new(0.14, 0.1, 0.08), CFrame.new(0.27, 0.2, 0.12), Color3.fromRGB(20, 20, 20))
	return m
end

-- Móvil: la pantalla, hacia -Z del modelo (hacia ti, Manos la gira).
local function movil(): Model
	local m = Instance.new("Model")
	m.Name = "MovilMano"
	local cuerpo = pieza(m, "Cuerpo", Vector3.new(0.38, 0.72, 0.05), CFrame.new(), Color3.fromRGB(22, 22, 24))
	m.PrimaryPart = cuerpo
	local pantalla = pieza(m, "Pantalla", Vector3.new(0.33, 0.62, 0.01), CFrame.new(0, 0.01, -0.028),
		Color3.fromRGB(70, 92, 110), Enum.Material.Glass)
	pantalla.Transparency = 0.1
	return m
end

-- Cerilla encendida: el palo a lo largo de -Z y la llama en la punta (con una luz floja: nada de brillos).
local function cerilla(): Model
	local m = Instance.new("Model")
	m.Name = "Cerilla"
	local palo = pieza(m, "Palo", Vector3.new(0.05, 0.05, 0.5), CFrame.new(), Color3.fromRGB(196, 168, 120), Enum.Material.Wood)
	m.PrimaryPart = palo
	pieza(m, "Cabeza", Vector3.new(0.08, 0.08, 0.08), CFrame.new(0, 0, -0.27), Color3.fromRGB(90, 20, 15))
	local llama = pieza(m, "Llama", Vector3.new(0.1, 0.18, 0.1), CFrame.new(0, 0.07, -0.29), Color3.fromRGB(255, 170, 70),
		Enum.Material.Neon)
	llama.Shape = Enum.PartType.Ball
	llama.Transparency = 0.25
	local luz = Instance.new("PointLight")
	luz.Color = Color3.fromRGB(255, 170, 90)
	luz.Brightness = 0.9
	luz.Range = 7
	luz.Parent = llama
	return m
end

-- Una pila gorda vieja (para cambiar la de la linterna).
local function pila(): Model
	local m = Instance.new("Model")
	m.Name = "PilaMano"
	local cuerpo = pieza(m, "Cuerpo", Vector3.new(0.34, 0.13, 0.13), ALO_LARGO, Color3.fromRGB(150, 40, 30),
		Enum.Material.SmoothPlastic, true)
	m.PrimaryPart = cuerpo
	pieza(m, "Polo", Vector3.new(0.04, 0.06, 0.06), CFrame.new(0, 0, -0.19) * ALO_LARGO, Color3.fromRGB(180, 170, 150),
		Enum.Material.Metal, true)
	return m
end

-- Un carrete de fotos (para la cámara).
local function carrete(): Model
	local m = Instance.new("Model")
	m.Name = "CarreteMano"
	local cuerpo = pieza(m, "Cuerpo", Vector3.new(0.26, 0.16, 0.16), ALO_LARGO, Color3.fromRGB(30, 30, 32),
		Enum.Material.SmoothPlastic, true)
	m.PrimaryPart = cuerpo
	pieza(m, "Banda", Vector3.new(0.12, 0.165, 0.165), ALO_LARGO, Color3.fromRGB(190, 150, 40), Enum.Material.SmoothPlastic, true)
	return m
end

-- Dónde va cada cosa respecto a la palma (-Z dedos, +Y dorso; el pulgar de la izquierda en +X, el de la derecha en -X).
-- La linterna, en la izquierda: a lo largo del pulgar (+X de la palma) y por debajo de ella, dentro del puño.
Manos.cosa("Linterna", linterna, CFrame.new(0, -0.13, 0)
	* CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 0, 1), Vector3.new(0, 1, 0), Vector3.new(-1, 0, 0)))
-- La cámara, en la derecha: la mano por su lado derecho, la palma contra él. Con la pose de la foto (dedos arriba,
-- dorso a la derecha) la palma tiene +X hacia delante, +Y a la derecha y -Z arriba: el objetivo queda hacia delante.
Manos.cosa("Camara", camaraFotos, CFrame.new(0, -0.4, 0)
	* CFrame.fromMatrix(Vector3.zero, Vector3.new(0, 1, 0), Vector3.new(0, 0, -1), Vector3.new(-1, 0, 0)))
-- El móvil, en la derecha y de pie sobre la palma, con la pantalla hacia ti.
Manos.cosa("Movil", movil, CFrame.new(0, -0.1, -0.15)
	* CFrame.fromMatrix(Vector3.zero, Vector3.new(1, 0, 0), Vector3.new(0, 0, -1), Vector3.new(0, 1, 0)))
-- La cerilla, entre los dedos de la derecha, saliendo hacia delante.
Manos.cosa("Cerilla", cerilla, CFrame.new(0, -0.05, -0.32))
-- La pila y el carrete, cogidos con la punta de los dedos.
Manos.cosa("Pila", pila, CFrame.new(0, -0.1, -0.22))
Manos.cosa("Carrete", carrete, CFrame.new(0, -0.1, -0.22))
-- La cámara en la izquierda (para cambiar el carrete con la derecha): como la de la derecha, en espejo.
Manos.cosa("CamaraIzq", camaraFotos, CFrame.new(0, -0.4, 0)
	* CFrame.fromMatrix(Vector3.zero, Vector3.new(0, -1, 0), Vector3.new(0, 0, -1), Vector3.new(1, 0, 0)))

-- ===== Ayudas =====

local function lerp(a: number, b: number, k: number): number
	return a + (b - a) * math.clamp(k, 0, 1)
end

-- Suave al empezar y al acabar.
local function suave(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

local function etiquetado(cosa: Instance?, etiqueta: string): Instance?
	while cosa and cosa ~= workspace do
		if CollectionService:HasTag(cosa, etiqueta) then
			return cosa
		end
		cosa = cosa.Parent
	end
	return nil
end

local function posicion(cosa: Instance?): Vector3?
	if not cosa then
		return nil
	elseif cosa:IsA("BasePart") then
		return cosa.Position
	elseif cosa:IsA("Model") then
		return cosa:GetPivot().Position
	elseif cosa:IsA("Attachment") then
		return cosa.WorldPosition
	end
	return nil
end

-- El punto de la caja de `parte` más cerca de `punto` (para agarrar lo que se carga por el lado que queda cerca).
local function cercaEnCaja(parte: BasePart, punto: Vector3): Vector3
	local cf, medio = parte.CFrame, parte.Size / 2
	local l = cf:PointToObjectSpace(punto)
	return cf * Vector3.new(math.clamp(l.X, -medio.X, medio.X), math.clamp(l.Y, -medio.Y, medio.Y),
		math.clamp(l.Z, -medio.Z, medio.Z))
end

-- ===== Gestos al pulsar un cartel =====

local cfgCasa = Config.Casa

-- Las cortinas: las dos manos en el borde de dentro de cada paño, que se mueve como lo mueve CasaVista.
local function cortinas(ventana: Instance)
	local centro = ventana:GetAttribute("Centro")
	local ancho = ventana:GetAttribute("Ancho")
	if typeof(centro) ~= "CFrame" or type(ancho) ~= "number" then
		return
	end
	local desde = if ventana:GetAttribute("Persiana") then 1 else 0 -- 1 cerradas
	local hasta = 1 - desde
	local fuera = ancho / 2 + 0.6
	local function borde(b: number, lado: number): Vector3
		local dentro = fuera - (0.9 + (fuera - 0.9) * b)
		return centro * Vector3.new(lado * dentro, -0.2, 0.95)
	end
	-- Cada mano con el paño de su lado (mirando desde dentro, la derecha de la cámara puede ser -X de la ventana).
	local derecha = if camara.CFrame.RightVector:Dot(centro.RightVector) >= 0 then 1 else -1
	local llega, corre = 0.28, cfgCasa.TiempoPersiana
	Manos.gesto("Mano", llega + corre + 0.3, function(_, s)
		local b = if s < llega then desde else lerp(desde, hasta, suave((s - llega) / corre))
		if s > llega + corre + 0.12 then
			return nil -- suelta y las manos bajan
		end
		-- Al tirar, los brazos se tensan: un poco de temblor de la tela.
		local tiron = if s > llega and s < llega + corre then math.sin(s * 30) * 0.015 else 0
		return {
			der = Manos.hacia("der", borde(b, derecha) + Vector3.new(0, tiron, 0), "agarra"),
			izq = Manos.hacia("izq", borde(b, -derecha) - Vector3.new(0, tiron, 0), "agarra"),
			velocidad = 22,
		}
	end)
end

-- La puerta: la derecha coge el pomo (que gira y se mueve con la hoja en CasaVista, o traquetea si está cerrada).
local function puerta(el: Instance)
	local pomo = el:FindFirstChild("Pomo")
	if not (pomo and pomo:IsA("BasePart")) then
		return
	end
	Manos.gesto("Mano", 0.95, function(_, s)
		if s > 0.75 then
			return nil
		end
		local giro = if s > 0.2 and s < 0.45 then -0.9 * suave((s - 0.2) / 0.15) else (if s >= 0.45 then -0.9 else 0)
		return { der = Manos.hacia("der", pomo.Position, "agarra") * CFrame.Angles(0, 0, giro), velocidad = 20 }
	end)
end

-- Una copia de lo que coges (el servidor quita el de verdad enseguida) que va hasta la palma y desaparece con ella
-- en el bolsillo: que se vea que lo has cogido tú.
local function copiaDe(objeto: BasePart): BasePart?
	local ok, copia = pcall(function()
		local archivable = objeto.Archivable
		objeto.Archivable = true
		local c = objeto:Clone()
		objeto.Archivable = archivable
		return c
	end)
	if not ok or not copia then
		return nil
	end
	local c = copia :: BasePart
	for _, etiqueta in CollectionService:GetTags(c) do
		CollectionService:RemoveTag(c, etiqueta) -- que nadie la tome por un objeto de verdad
	end
	for _, hijo in c:GetDescendants() do
		if hijo:IsA("ProximityPrompt") or hijo:IsA("Script") or hijo:IsA("LocalScript") or hijo:IsA("Light")
			or hijo:IsA("Sound") or hijo:IsA("Constraint") or hijo:IsA("Highlight") then
			hijo:Destroy()
		end
	end
	c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch = true, false, false, false
	c.Parent = camara
	return c
end

-- Coger un objeto suelto: baja la mano, lo coge (vuela a la palma) y la mano se va hacia el bolsillo.
local function coger(objeto: BasePart)
	local donde = objeto.Position
	local copia = copiaDe(objeto)
	local desde = objeto.CFrame
	Manos.gesto("Mano", 0.75, function(_, s)
		local c = copia
		if c then
			local palma = Manos.mano("der")
			if s >= 0.22 and palma then
				-- De donde estaba a la mano, y luego pegado a ella hasta el bolsillo.
				local k = suave((s - 0.22) / 0.14)
				c.CFrame = desde:Lerp(palma * CFrame.new(0, -0.15, -0.1), k)
			end
			if s > 0.62 then
				c:Destroy()
				copia = nil
			end
		end
		if s < 0.3 then
			return { der = Manos.hacia("der", donde + Vector3.new(0, 0.15, 0), "abajo"), velocidad = 18 }
		elseif s < 0.4 then
			return { der = Manos.hacia("der", donde + Vector3.new(0, 0.05, 0), "abajo"), velocidad = 25 }
		end
		local cf = camara.CFrame
		return { der = Manos.palma(cf * Vector3.new(0.55, -1.0, -0.6), -cf.UpVector + cf.LookVector * 0.3, cf.RightVector),
			velocidad = 14 }
	end)
	task.delay(1, function()
		if copia then
			copia:Destroy()
		end
	end)
end

-- Cargar algo pesado: las dos manos van a por sus lados (luego manda la capa de cargar).
local function aPorPesado(p: BasePart)
	Manos.gesto("Mano", 0.4, function()
		local cf = camara.CFrame
		local der = cercaEnCaja(p, cf * Vector3.new(0.7, -1.2, -1.3))
		local izq = cercaEnCaja(p, cf * Vector3.new(-0.7, -1.2, -1.3))
		return { der = Manos.hacia("der", der, "dentro"), izq = Manos.hacia("izq", izq, "dentro"), velocidad = 16 }
	end)
end

-- El generador: coge la cuerda y da un tirón hacia ti (TrabajoVista hace salir la cuerda a la vez).
local function cuerda(gen: Instance)
	local c = gen:FindFirstChild("Cuerda")
	if not (c and c:IsA("BasePart")) then
		return
	end
	Manos.gesto("Mano", 0.95, function(_, s)
		local cf = camara.CFrame
		local agarre = c.Position
		if s < 0.25 then
			return { der = Manos.hacia("der", agarre, "agarra"), velocidad = 18 }
		elseif s < 0.48 then
			-- El tirón: de golpe hacia el hombro y un poco hacia arriba.
			local k = suave((s - 0.25) / 0.12)
			local hacia = (cf.Position - agarre).Unit
			return { der = Manos.hacia("der", agarre + hacia * 1.1 * k + cf.UpVector * 0.25 * k, "agarra"), velocidad = 40 }
		elseif s < 0.75 then
			return { der = Manos.hacia("der", agarre, "agarra"), velocidad = 10 } -- la cuerda vuelve sola y la mano con ella
		end
		return nil
	end)
end

-- Apretar algo (un botón, una superficie): la mano va, empuja un poco y vuelve.
local function apretar(punto: Vector3, lado: string?)
	local l = lado or "der"
	Manos.gesto("Mano", 0.6, function(_, s)
		if s > 0.45 then
			return nil
		end
		local cf = camara.CFrame
		local empuje = if s > 0.22 and s < 0.35 then 0.12 else 0
		local p = punto + (punto - cf.Position).Unit * empuje
		return { [l] = Manos.hacia(l, p, "delante"), velocidad = 18 } :: any
	end)
end

-- Esconderse: las dos manos empujan la puerta del armario o levantan la colcha.
local function esconderse(sitio: Instance)
	local p = posicion(sitio:FindFirstChild("Mando") or sitio)
	if not p then
		return
	end
	Manos.gesto("Mano", 0.4, function()
		local cf = camara.CFrame
		return {
			der = Manos.hacia("der", (p :: Vector3) + cf.RightVector * 0.5, "delante"),
			izq = Manos.hacia("izq", (p :: Vector3) - cf.RightVector * 0.5, "delante"),
			velocidad = 20,
			siempre = true, -- también mientras la cámara se mete en el escondite (MuerteVista)
		}
	end)
end

-- Leer una pista: la coge y la sube a la cara (el papel lo pinta PistasUi).
local function leer(cosa: Instance)
	local p = posicion(cosa)
	if not p then
		return
	end
	Manos.gesto("Mano", 1.1, function(_, s)
		local cf = camara.CFrame
		if s < 0.35 then
			return { der = Manos.hacia("der", p :: Vector3, "abajo"), velocidad = 16 }
		elseif s < 0.95 then
			return {
				der = Manos.palma(cf * Vector3.new(0.3, -0.55, -1.05), cf.UpVector, -cf.LookVector + cf.RightVector * 0.3),
				izq = Manos.palma(cf * Vector3.new(-0.3, -0.55, -1.05), cf.UpVector, -cf.LookVector - cf.RightVector * 0.3),
				velocidad = 12,
			}
		end
		return nil
	end)
end

-- Enchufar el móvil: la derecha lo lleva al enchufe.
local function enchufar(mando: Instance)
	local p = posicion(mando)
	if not p then
		return
	end
	Manos.gesto("Mano", 0.8, function(_, s)
		if s > 0.6 then
			return nil
		end
		return { der = Manos.hacia("der", p :: Vector3, "delante"), cosaDer = if s < 0.45 then "Movil" else nil, velocidad = 14 }
	end)
end

-- El banco del taller: las dos manos se apoyan en él.
local function banco(mando: Instance)
	local p = posicion(mando)
	if not p then
		return
	end
	Manos.gesto("Mano", 0.55, function(_, s)
		if s > 0.4 then
			return nil
		end
		local cf = camara.CFrame
		return {
			der = Manos.hacia("der", (p :: Vector3) + cf.RightVector * 0.6, "abajo"),
			izq = Manos.hacia("izq", (p :: Vector3) - cf.RightVector * 0.6, "abajo"),
			velocidad = 16,
		}
	end)
end

-- ===== Mantener pulsado =====

local sosteniendo: { [ProximityPrompt]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- La palanca: las dos manos la cogen y tiran de ella hacia ti mientras se mantiene.
local function palanca(prompt: ProximityPrompt, mando: Instance)
	local p = posicion(mando)
	if not p then
		return
	end
	local dura = prompt.HoldDuration
	Manos.gesto("Mano", dura + 0.5, function(_, s)
		if not sosteniendo[prompt] then
			return nil
		end
		local cf = camara.CFrame
		local k = math.clamp(s / math.max(dura, 0.1), 0, 1)
		local tira = (cf.Position - (p :: Vector3)).Unit * 0.7 * suave(k) - cf.UpVector * 0.25 * k
		local tiembla = Vector3.new(0, math.sin(s * 40) * 0.02, 0) -- cuesta
		return {
			der = Manos.hacia("der", (p :: Vector3) + tira + tiembla + cf.RightVector * 0.18, "agarra"),
			izq = Manos.hacia("izq", (p :: Vector3) + tira - tiembla - cf.RightVector * 0.18, "agarra"),
			velocidad = 16,
		}
	end)
end

-- La cerilla: sube, se raspa contra la caja (izquierda), prende y baja hasta el rastro de gasolina.
local function cerillaGesto(prompt: ProximityPrompt, mando: Instance)
	local p = posicion(mando)
	if not p then
		return
	end
	Manos.gesto("Mano", prompt.HoldDuration + 0.6, function(_, s)
		if not sosteniendo[prompt] then
			return nil
		end
		local cf = camara.CFrame
		local caja = Manos.palma(cf * Vector3.new(-0.2, -0.7, -1.1), cf.LookVector, cf.UpVector * 0.3 - cf.RightVector)
		if s < 0.45 then
			-- Raspa: de la caja hacia la derecha, de golpe.
			local k = if s < 0.25 then 0 else suave((s - 0.25) / 0.12)
			return {
				der = Manos.palma(cf * Vector3.new(lerp(-0.05, 0.35, k), -0.62, -1.1), cf.LookVector, cf.UpVector),
				izq = caja,
				cosaDer = if s > 0.3 then "Cerilla" else nil,
				velocidad = 30,
			}
		end
		-- Prendida: la protege un momento y la baja hasta el rastro.
		local k = suave((s - 0.45) / 0.6)
		local abajo = (p :: Vector3):Lerp(cf * Vector3.new(0.35, -0.62, -1.1), 1 - k)
		return { der = Manos.hacia("der", abajo, "abajo"), cosaDer = "Cerilla", velocidad = 12 }
	end)
end

-- El volante del coche al huir: las dos manos agarradas delante, apretando.
local function volante(prompt: ProximityPrompt)
	Manos.gesto("Mano", prompt.HoldDuration + 0.5, function(_, s)
		if not sosteniendo[prompt] then
			return nil
		end
		local cf = camara.CFrame
		local gira = math.sin(s * 3) * 0.08
		return {
			der = Manos.palma(cf * Vector3.new(0.42, -0.75 + gira, -1.25), cf.UpVector + cf.RightVector * 0.3, -cf.LookVector * 0.3 + cf.RightVector),
			izq = Manos.palma(cf * Vector3.new(-0.42, -0.75 - gira, -1.25), cf.UpVector - cf.RightVector * 0.3, -cf.LookVector * 0.3 - cf.RightVector),
			velocidad = 16,
		}
	end)
end

-- Ojo: se reconoce cada cartel por su ActionText en inglés tal como lo pone el servidor (Casa, Cargar, Mochila,
-- Generador, Pistas, Preparativos, Coche, Incendio, Taller…). Si se cambia un texto allí, cambiarlo también aquí.
local function alPulsar(prompt: ProximityPrompt, quien: Player)
	if quien ~= jugador or prompt.HoldDuration > 0 then
		return -- los de mantener, en alEmpezarAMantener
	end
	local mando = prompt.Parent
	local texto = prompt.ActionText
	local ventana = etiquetado(mando, "Ventana")
	local puertaEl = etiquetado(mando, "Puerta")
	if ventana and (texto == "Open curtains" or texto == "Close curtains") then
		cortinas(ventana)
	elseif puertaEl and texto ~= "Repair" then
		puerta(puertaEl)
	elseif texto == "Pick up" and mando and mando:IsA("BasePart") then
		coger(mando)
	elseif texto == "Carry" and mando and mando:IsA("BasePart") then
		aPorPesado(mando)
	elseif etiquetado(mando, "Generador") and texto == "Pull the cord" then
		cuerda(etiquetado(mando, "Generador") :: Instance)
	elseif etiquetado(mando, "Escondite") then
		esconderse(etiquetado(mando, "Escondite") :: Instance)
	elseif texto == "Read" or texto == "Look" then
		leer(mando :: Instance)
	elseif texto == "Plug in phone" then
		enchufar(mando :: Instance)
	elseif texto == "Workbench" then
		banco(mando :: Instance)
	elseif texto == "Chop" or texto == "Trade" then
		return -- el hacha la pone TrabajoVista; al vendedor se le habla
	else
		local p = posicion(mando)
		if p then
			apretar(p)
		end
	end
end

local function alEmpezarAMantener(prompt: ProximityPrompt, quien: Player)
	if quien ~= jugador or prompt.HoldDuration <= 0 then
		return
	end
	sosteniendo[prompt] = true
	local texto = prompt.ActionText
	if texto == "Pull" then
		palanca(prompt, prompt.Parent :: Instance)
	elseif texto == "Light" then
		cerillaGesto(prompt, prompt.Parent :: Instance)
	elseif texto == "Escape" then
		volante(prompt)
	else
		local p = posicion(prompt.Parent)
		if p then
			apretar(p)
		end
	end
end

-- ===== Sostener =====

local L = Config.Linterna
local sacudida = 0 -- con poca pila, cuándo le toca la próxima sacudida

-- La linterna encendida, en la izquierda, apuntando adonde miras (un poco hacia la derecha, al centro).
local function capaLinterna(): Manos.Pose?
	if jugador:GetAttribute("Linterna") ~= true then
		return nil
	end
	local cf = camara.CFrame
	local ahora = os.clock()
	local meneo = CFrame.new()
	if (jugador:GetAttribute("Pila") or 1) < L.Poca then
		-- Poca pila: de vez en cuando la sacude, como para que vuelva.
		if ahora > sacudida + 0.45 and ahora - sacudida > azar:NextNumber(3.5, 7) then
			sacudida = ahora
		end
		local k = ahora - sacudida
		if k < 0.45 then
			meneo = CFrame.new(0, math.sin(k * 45) * 0.06 * (1 - k / 0.45), 0)
		end
	end
	local centro = (cf * meneo) * Vector3.new(-0.48, -0.6, -1.25)
	local apunta = (cf * Vector3.new(0.05, -0.1, -12) - centro).Unit
	return { izq = Manos.vara("izq", centro, apunta, -cf.RightVector + cf.UpVector * 0.35), cosaIzq = "Linterna", velocidad = 16 }
end

-- El móvil abierto (MovilUi): en la derecha, de pie delante de ti.
local function capaMovil(): Manos.Pose?
	if jugador:GetAttribute("MovilAbierto") ~= true then
		return nil
	end
	local cf = camara.CFrame
	return {
		der = Manos.palma(cf * Vector3.new(0.3, -0.75, -1.0), cf.UpVector - cf.LookVector * 0.15, cf.LookVector),
		cosaDer = "Movil",
		velocidad = 12,
	}
end

-- La pistola de bengalas (BengalasVista la pone delante de la cámara): la derecha en el mango, la izquierda debajo.
local function capaPistola(): Manos.Pose?
	local pistola = camara:FindFirstChild("PistolaBengalas")
	local mango = pistola and pistola:FindFirstChild("Mango")
	if not (mango and mango:IsA("BasePart")) then
		return nil
	end
	local m = mango.CFrame
	return {
		der = Manos.vara("der", m.Position, m.UpVector, m.RightVector),
		izq = Manos.palma((m * CFrame.new(-0.05, -0.22, 0.05)).Position, m.LookVector, -m.UpVector + m.RightVector * 0.5),
		velocidad = math.huge,
	}
end

-- Lo pesado que llevas: las dos manos en su lado más cercano (la pieza la mueve el servidor con física).
local llevando: BasePart? = nil
local buscado = 0
local function buscarPesado(tipo: string): BasePart?
	if llevando and llevando.Parent and llevando:GetAttribute("Tipo") == tipo
		and (llevando.Position - camara.CFrame.Position).Magnitude < 10 then
		return llevando
	end
	if os.clock() - buscado < 0.25 then
		return nil -- buscar entre todas las piezas, como mucho cuatro veces por segundo
	end
	buscado = os.clock()
	local mejor, distancia = nil, 10
	local cf = camara.CFrame
	for _, p in CollectionService:GetTagged("Pesado") do
		if p:IsA("BasePart") and p:GetAttribute("Tipo") == tipo then
			local d = (p.Position - cf.Position).Magnitude
			local delante = (p.Position - cf.Position):Dot(cf.LookVector) > -1
			if delante and d < distancia then
				mejor, distancia = p, d
			end
		end
	end
	llevando = mejor
	return mejor
end

local function capaCargar(): Manos.Pose?
	local tipo = jugador:GetAttribute("Cargando")
	if type(tipo) ~= "string" then
		llevando = nil
		return nil
	end
	local p = buscarPesado(tipo)
	if not p then
		return nil
	end
	local cf = camara.CFrame
	local der = cercaEnCaja(p, cf * Vector3.new(0.75, -1.1, -1.2))
	local izq = cercaEnCaja(p, cf * Vector3.new(-0.75, -1.1, -1.2))
	local centro = p.Position
	local function fuera(punto: Vector3): Vector3
		local d = punto - centro
		return if d.Magnitude > 1e-3 then d.Unit else cf.RightVector
	end
	return {
		der = Manos.palma(der + fuera(der) * 0.12, cf.LookVector - cf.UpVector * 0.3, fuera(der)),
		izq = Manos.palma(izq + fuera(izq) * 0.12, cf.LookVector - cf.UpVector * 0.3, fuera(izq)),
		velocidad = 22,
	}
end

-- Cambiar la pila (atributo Cambiando = "Pila", Config.Linterna.Cambiar s): la linterna en la izquierda, de lado; la
-- derecha desenrosca la culata, saca la vieja, mete la nueva y vuelve a enroscar. El carrete (Config.Flash.Cambiar):
-- la cámara en la izquierda y la derecha abre la tapa, saca el carrete y mete otro.
local cambioInicio = 0
local function capaCambiar(): Manos.Pose?
	local que = jugador:GetAttribute("Cambiando")
	if que ~= "Pila" and que ~= "Carrete" then
		cambioInicio = 0
		return nil
	end
	if cambioInicio == 0 then
		cambioInicio = os.clock()
	end
	local dura = if que == "Pila" then Config.Linterna.Cambiar else Config.Flash.Cambiar
	local k = math.clamp((os.clock() - cambioInicio) / dura, 0, 1)
	local cf = camara.CFrame
	if que == "Pila" then
		-- La linterna atravesada delante, con la culata hacia la derecha.
		local centro = cf * Vector3.new(-0.15, -0.62, -1.15)
		local izq = Manos.vara("izq", centro, -cf.RightVector + cf.UpVector * 0.25, -cf.UpVector * 0.4 - cf.LookVector)
		local culata = cf * Vector3.new(0.32, -0.6, -1.12)
		local der, cosa
		if k < 0.3 then -- desenrosca: la muñeca gira
			der = Manos.hacia("der", culata, "agarra") * CFrame.Angles(0, 0, math.sin(k * 40) * 0.6)
		elseif k < 0.5 then -- saca la vieja y la deja caer
			der = Manos.hacia("der", culata + cf.RightVector * 0.25 - cf.UpVector * 0.2 * (k - 0.3) / 0.2, "abajo")
			cosa = "Pila"
		elseif k < 0.75 then -- coge la nueva (del bolsillo) y la mete
			local mete = suave((k - 0.5) / 0.25)
			der = Manos.hacia("der", culata + cf.RightVector * (0.35 * (1 - mete)) - cf.UpVector * 0.3 * (1 - mete), "dentro")
			cosa = "Pila"
		else -- enrosca
			der = Manos.hacia("der", culata, "agarra") * CFrame.Angles(0, 0, -math.sin(k * 40) * 0.6)
		end
		return { izq = izq, cosaIzq = "Linterna", der = der, cosaDer = cosa, velocidad = 18 }
	end
	-- El carrete: la cámara en la izquierda, boca abajo; la derecha por detrás.
	local izq = Manos.palma(cf * Vector3.new(-0.35, -0.7, -1.05), cf.UpVector, -cf.RightVector - cf.LookVector * 0.2)
	local tapa = cf * Vector3.new(0.05, -0.62, -0.95)
	local der, cosa
	if k < 0.25 then
		der = Manos.hacia("der", tapa, "agarra") * CFrame.Angles(math.rad(-25 * k / 0.25), 0, 0) -- abre la tapa
	elseif k < 0.5 then
		der = Manos.hacia("der", tapa + cf.RightVector * 0.3 - cf.UpVector * 0.25, "abajo")
		cosa = "Carrete"
	elseif k < 0.8 then
		local mete = suave((k - 0.5) / 0.3)
		der = Manos.hacia("der", tapa + (cf.RightVector * 0.35 - cf.UpVector * 0.3) * (1 - mete), "dentro")
		cosa = "Carrete"
	else
		der = Manos.hacia("der", tapa, "delante") -- cierra la tapa de un golpe
	end
	return { izq = izq, cosaIzq = "CamaraIzq", der = der, cosaDer = cosa, velocidad = 18 }
end

-- Trepar por una escalera de mano (la del sótano a la trampilla, la del desván): las manos se van agarrando a los
-- peldaños, una y otra, al ritmo al que subes o bajas. Van con el cuerpo (mirando a la escalera), no con la cámara.
local trepado = 0
local function capaTrepar(dt: number): Manos.Pose?
	local personaje = jugador.Character
	local hum = personaje and personaje:FindFirstChildOfClass("Humanoid")
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not raiz or hum:GetState() ~= Enum.HumanoidStateType.Climbing then
		return nil
	end
	trepado += raiz.AssemblyLinearVelocity.Y * dt / 1.1 * math.pi -- un peldaño cada ~1,1 studs
	local r = raiz.CFrame
	local function mano(lado: number, fase: number): CFrame
		-- Sube mientras la otra agarra: arriba del todo, se cierra en el peldaño y baja con el cuerpo.
		local alto = 1.25 + math.sin(fase) * 0.45
		local suelta = math.max(0, math.cos(fase)) * 0.18 -- separada de la escalera mientras sube
		local p = (r * CFrame.new(lado * 0.42, alto, -0.95 + suelta)).Position
		return Manos.palma(p, r.UpVector + r.LookVector * 0.3, -r.LookVector)
	end
	return { der = mano(1, trepado), izq = mano(-1, trepado + math.pi), velocidad = 20 }
end

-- En el aire (saltando o cayendo más de un momento): los brazos se abren un poco, para no perder el equilibrio.
local enElAire = 0
local function capaAire(dt: number): Manos.Pose?
	local hum = jugador.Character and jugador.Character:FindFirstChildOfClass("Humanoid")
	local estado = hum and hum:GetState()
	if estado == Enum.HumanoidStateType.Freefall or estado == Enum.HumanoidStateType.Jumping then
		enElAire += dt
	else
		enElAire = 0
	end
	if enElAire < 0.3 then
		return nil
	end
	local cf = camara.CFrame
	local abre = math.min(1, (enElAire - 0.3) / 0.3)
	return {
		der = Manos.palma(cf * Vector3.new(0.7 + 0.15 * abre, -0.9 + 0.25 * abre, -1.0), cf.LookVector + cf.RightVector * 0.4, cf.UpVector),
		izq = Manos.palma(cf * Vector3.new(-0.7 - 0.15 * abre, -0.9 + 0.25 * abre, -1.0), cf.LookVector - cf.RightVector * 0.4, cf.UpVector),
		velocidad = 10,
	}
end

-- ===== Lo que piden otros módulos =====

-- La foto (EquipoVista, al pedirla): sube la cámara a la cara con las dos manos, da el disparo y la baja.
function ManosGestos.foto()
	Manos.gesto("Foto", 0.7, function(_, s)
		local cf = camara.CFrame
		local sube = if s < 0.15 then suave(s / 0.15) elseif s < 0.45 then 1 else 1 - suave((s - 0.45) / 0.25)
		local golpe = if s > 0.16 and s < 0.26 then 0.04 else 0 -- el dedo en el disparador
		local y = lerp(-1.0, -0.32, sube)
		local z = lerp(-1.1, -0.82, sube)
		return {
			der = Manos.palma(cf * Vector3.new(0.4, y - golpe, z), cf.UpVector, cf.RightVector - cf.LookVector * 0.2),
			izq = Manos.palma(cf * Vector3.new(-0.4, y, z), cf.UpVector, -cf.RightVector - cf.LookVector * 0.2),
			cosaDer = "Camara",
			velocidad = 24,
		}
	end, 60)
end

-- Un respingo (los sustos: Sustos/Util.tiron): las manos libres suben de golpe hacia el pecho y bajan despacio. No
-- sueltan lo que llevan (va por debajo de cargar y de las herramientas).
function ManosGestos.sobresalto(fuerza: number)
	local f = math.clamp(fuerza, 0.2, 1)
	Manos.gesto("Sobresalto", 0.9, function(_, s)
		local cf = camara.CFrame
		local sube = if s < 0.1 then suave(s / 0.1) else 1 - suave((s - 0.1) / 0.8)
		local y = lerp(-1.2, -0.55, sube * f)
		-- Con la linterna encendida, la izquierda no la suelta.
		local conLinterna = jugador:GetAttribute("Linterna") == true
		return {
			der = Manos.palma(cf * Vector3.new(0.42, y, -0.8), cf.UpVector + cf.RightVector * 0.2, -cf.LookVector),
			izq = if conLinterna then nil
				else Manos.palma(cf * Vector3.new(-0.42, y, -0.8), cf.UpVector - cf.RightVector * 0.2, -cf.LookVector),
			velocidad = 26,
		}
	end, 28)
end

-- ===== Escondite y muerte =====

local function alSalirDelEscondite()
	Manos.gesto("Mano", 0.5, function(_, s)
		local cf = camara.CFrame
		local k = suave(s / 0.35)
		return {
			der = Manos.palma(cf * Vector3.new(0.35, -0.45, lerp(-0.7, -1.5, k)), cf.UpVector, -cf.LookVector),
			izq = Manos.palma(cf * Vector3.new(-0.35, -0.45, lerp(-0.7, -1.5, k)), cf.UpVector, -cf.LookVector),
			velocidad = 22,
		}
	end)
end

-- Te pilla: las manos se levantan delante, temblando (abajo, para no tapar la cara del bicho).
local function alMorir()
	Manos.gesto("Susto", 1.8, function(_, s)
		local cf = camara.CFrame
		local t = math.min(1, s / 0.15)
		local function temblor(): Vector3
			return Vector3.new(azar:NextNumber(-1, 1), azar:NextNumber(-1, 1), 0) * 0.03
		end
		return {
			der = Manos.palma(cf * (Vector3.new(0.62, lerp(-1.3, -0.62, t), -0.95) + temblor()),
				cf.UpVector + cf.RightVector * 0.25, -cf.LookVector),
			izq = Manos.palma(cf * (Vector3.new(-0.62, lerp(-1.3, -0.66, t), -0.95) + temblor()),
				cf.UpVector - cf.RightVector * 0.25, -cf.LookVector),
			velocidad = 30,
			siempre = true,
		}
	end, 90)
end

-- Para ManosPrueba (Studio): el gesto de ese cartel, como si lo hubieras pulsado, y el del susto al morir.
function ManosGestos.probar(prompt: ProximityPrompt)
	alPulsar(prompt, jugador)
end

function ManosGestos.probarSusto()
	alMorir()
end

function ManosGestos.start()
	ProximityPromptService.PromptTriggered:Connect(alPulsar)
	ProximityPromptService.PromptButtonHoldBegan:Connect(alEmpezarAMantener)
	ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt, quien)
		if quien == jugador then
			sosteniendo[prompt] = nil
		end
	end)
	Manos.capa("Linterna", 10, capaLinterna)
	Manos.capa("Movil", 20, capaMovil)
	Manos.capa("Pistola", 25, capaPistola)
	Manos.capa("Cargar", 30, capaCargar)
	Manos.capa("Cambiar", 45, capaCambiar)
	Manos.capa("Trepar", 35, capaTrepar)
	Manos.capa("Aire", 5, capaAire)
	local escondido = jugador:GetAttribute("Escondido") ~= nil
	jugador:GetAttributeChangedSignal("Escondido"):Connect(function()
		local ahora = jugador:GetAttribute("Escondido") ~= nil
		if escondido and not ahora and not jugador:GetAttribute("Muerto") then
			alSalirDelEscondite()
		end
		escondido = ahora
	end)
	Remotes.Muerte.OnClientEvent:Connect(function(quien: Player)
		if quien == jugador then
			alMorir()
		end
	end)
end

return ManosGestos
