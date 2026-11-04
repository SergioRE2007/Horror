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
--   Apoyarse (pedido por el usuario: "manos que se apoyan en la pared al pegarte a ella"): pegado a una pared, las
--     manos libres se apoyan en ella; asomado, la de ese lado se agarra al borde de la esquina o del marco; agachado,
--     se apoyan encima de lo bajo (una mesa, un mostrador). Es la capa más baja: cualquier otra cosa manda en la mano.
--   Correr (14.8, pedido por el usuario: "todo animado e inmersivo"; las cuentas en ManosCorrer): las manos libres
--     bracean al ritmo de los pasos (menos si la otra lleva algo; lo que lleva va y viene y tiembla: Manos); agotado,
--     asoman abajo y suben y bajan con la respiración; al tropezar, se adelantan para frenar la caída y vuelven.
-- Las herramientas (hacha, sierra, martillo, llave) las agarra TrabajoVista con su propia capa.
local CollectionService = game:GetService("CollectionService")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local CorrerVista = require(script.Parent.CorrerVista)
local Manos = require(script.Parent.Manos)
local ManosCorrer = require(script.Parent.ManosCorrer)
local Sonido = require(script.Parent.Sonido)

local ManosGestos = {}

local jugador = Players.LocalPlayer
local camara = workspace.CurrentCamera
local azar = Random.new()

-- Apoyarse en las paredes (capa "Pared", más abajo). Números a ojo, para retocarlos en Studio. Distancias en studs.
local APOYO = {
	prioridad = 4, -- la más baja de todas (por debajo del aire, 5, y de la linterna, 10)
	cada = 0.1, -- s entre una tanda de rayos y la siguiente (nunca cada fotograma)
	cadaLento = 0.2, -- con Rendimiento
	largo = 1.6, -- desde los ojos (de frente a la pared): más cerca que esto, estás pegado a ella
	rayo = 2.2, -- largo de esos rayos (más que `largo`: mirando la pared de lado, el rayo llega a ella más lejos)
	llegaMano = 2.15, -- del hombro a la pared: más lejos, la mano no llega
	deFrente = 0.45, -- la pared, como mucho a unos 63° de donde miras (el coseno)
	ancho = 0.3, -- cada mano, a este tanto del centro (más lo que abre: más separadas cuanto más lejos está la pared)
	abre = 0.12, -- por stud hasta la pared
	abreRayo = 0.35, -- sin nada justo delante, los rayos de cada lado se abren este tanto por stud (unos 19°)
	resbala = 3, -- studs/s que te deslizas por delante de la pared (o de la mesa): más deprisa, no se apoya
	bajo = 0.3, -- los rayos van a este tanto por debajo de los ojos
	inclina = 0.3, -- la palma queda por debajo de los ojos este tanto por stud que hay hasta la pared (unos 17°)
	alto = { der = 0, izq = -0.06 }, -- una mano un pelo más baja que la otra: así no parece un muñeco
	gira = 0.22, -- los dedos, hacia arriba y un poco hacia fuera
	-- El codo, contra la pared, siempre algo hacia ti. Con los ojos a `d` de ella o menos, hacia fuera (hacia abajo, el
	-- antebrazo se metía en ella); a codoLejos.d o más, hacia abajo y algo hacia fuera, como al empujar (la muñeca, unos
	-- 50° en vez de 85°). En medio, mezclado (comprobado con Lune: el antebrazo no se acerca a la pared más que la mano).
	codo = { fuera = 1, abajo = 0.35, atras = 0.35, d = 0.6 },
	codoLejos = { fuera = 0.6, abajo = 0.9, atras = 0.45, d = 1.2 },
	codoEncima = { fuera = 1, atras = 0.4 }, -- encima de algo: hacia fuera y hacia ti (hacia abajo se metía en la mesa)
	codoBorde = { abajo = 1, atras = 0.6 }, -- en una esquina: hacia abajo y hacia ti (hacia fuera se metía en la pared)
	-- Cogida por el canto: hacia ti, un poco abajo y hacia el hueco (la muñeca, unos 25-45° en vez de 85°).
	codoCanto = { abajo = 0.4, atras = 1, fuera = 0.2 },
	separa = 0.22, -- del centro de la mano a la superficie (la mitad de su grueso y un pelo)
	minimo = 1.2, -- lo que mide menos que esto por su lado más largo no sirve para apoyarse (un pomo, una lata)
	-- Las cortinas corridas de una ventana (los paños son de CasaVista, cuelgan a 0,75 ± 0,2 del cristal hacia la sala y
	-- no chocan con los rayos): la mano se apoya en la tela, no detrás de ella.
	cortina = 0.9, -- la cara de la tela, desde el cristal hacia la sala
	cortinaLado = 0.6, -- lo que sobresalen los paños por cada lado de la ventana
	cortinaArriba = 0.55, -- y por arriba (la barra)
	cortinaAbajo = 0.35, -- y por abajo
	fallos = 2, -- tandas de rayos seguidas sin apoyo para soltarla (una sola es un parpadeo: bajaba y volvía de un tirón)
	recolocar = 0.45, -- si donde debería ir la mano se aleja más que esto de donde está, la recoloca
	recolocarBorde = 0.25, -- lo mismo, agarrada a una esquina
	levanta = 0.12, -- al recolocarla, se separa de la pared este tanto por el camino
	llega = 0.35, -- s que tarda en quedarse pegada (el muelle se endurece hasta quedar quieta en la pared)
	muelle = 12, -- al ir hacia la pared
	muelleFin = 70, -- al acabar de llegar (luego, pegada)
	suelta = 0.4, -- s que tarda en bajar al apartarte
	muelleSuelta = 9, -- más blando: baja suave
	alcance = 2.4, -- del hombro a la mano: más lejos, la suelta sin esperar a los rayos (te has ido de golpe)
	-- Asomado: rayos desde el cuerpo, de delante hacia ese lado.
	borde = 2, -- largo de esos rayos
	bajoBorde = 0.3, -- por debajo de los ojos
	rayosBorde = 6, -- en 90°: uno cada 15°
	afinar = 3, -- rayos más entre los dos donde se acaba la pared, para dar con el borde (con Rendimiento, 1)
	rodea = 0.55, -- los dedos rodean la esquina: este tanto hacia detrás de la pared
	canto = 0.1, -- cogida por el canto (con el hombro más allá del borde): la palma, este tanto por detrás de la cara
	hombroLado = 0.75, -- lo que sale el hombro de la cámara hacia su lado (HOMBRO en Manos)
	bajaBorde = 0.4, -- si no llega, la mano puede bajar por la esquina hasta este tanto
	-- Agachado: algo bajo delante.
	encima = { 0.75, 1.15 }, -- por delante, dónde se busca su cara de arriba
	anchoEncima = 0.38, -- a cada lado
	sobreOjos = 0.45, -- hasta este tanto por encima de los ojos (un mostrador más alto que tú agachado)
	bajoEncima = 1.5, -- y hasta este tanto por debajo
	sobreSuelo = 0.9, -- lo que no levanta del suelo más que esto es el suelo (o un escalón)
	adentro = 0.15, -- encima, los dedos hacia delante y un poco hacia dentro
	cadaSonido = 4, -- s como poco entre dos ruidos al apoyarse (el cristal, una puerta que cruje)
	volumenCristal = 0.35, -- de su volumen: flojito, es tu mano
	volumenCruje = 0.3,
	cruje = 0.4, -- probabilidad de que una puerta cruja al apoyarte
}

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
	local vuela: number? = nil -- cuándo echa a volar la copia
	Manos.gesto("Mano", 0.75, function(_, s)
		local c = copia
		if c then
			local palma = Manos.mano("der")
			-- Vuela solo cuando el servidor ha quitado el de verdad: con la mochila llena se queda en el suelo y la
			-- copia, justo encima de él, no se mueve (no se ve otro igual volando a la mano).
			if not vuela and s >= 0.22 and objeto.Parent == nil then
				vuela = s
			end
			if vuela and palma then
				-- De donde estaba a la mano, y luego pegado a ella hasta el bolsillo.
				local k = suave((s - (vuela :: number)) / 0.14)
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
local sacudida = 0 -- con poca pila, cuándo empezó la última sacudida
local proximaSacudida = 0 -- y cuándo le toca la siguiente (sorteado una vez: de 3,5 a 7 s)

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
		if ahora >= proximaSacudida then
			sacudida = ahora
			proximaSacudida = ahora + azar:NextNumber(3.5, 7)
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

-- ===== Apoyarse: en la pared, en el borde de una esquina, encima de algo bajo =====
-- Pegado a una pared (a menos de APOYO.largo de los ojos) y yendo hacia ella o quieto, cada mano libre se apoya en ella:
-- la palma contra la pared y los dedos hacia arriba (de frente, las dos; si solo hay pared a un lado, la de ese lado).
-- Al pasar por delante o resbalar por ella, no. Asomado (atributo Asomado del jugador, -1 izquierda / 1 derecha, lo pone
-- Postura), la mano de ese lado se agarra al borde de la esquina o del marco de la puerta. Agachado (atributo Agachado),
-- si delante hay algo bajo (una mesa, un mostrador, una repisa), la mano se apoya encima. Solo de pie en el suelo y sin
-- mirar por la mirilla ni entre las cortinas (atributos locales Mirilla y Vistazo, de MirarVista); escondido, muerto,
-- con la mochila abierta o en una cinemática, Manos ya no las enseña.
-- Los rayos, cada APOYO.cada s. Entre medias la mano se queda donde se apoyó, pegada a lo que toca: no resbala al mirar
-- alrededor y, si es una puerta que se abre, va con ella. Si se aleja demasiado de donde debería ir, se recoloca
-- separándose un poco de la pared por el camino. Los rayos solo tocan lo que choca contigo: no las mallas que solo se
-- ven ni los adornos (los muebles, por su bloque de choque), ni personajes, bichos, el vendedor, objetos sueltos o lo que
-- se carga; pasan de largo lo diminuto (un pomo) y lo que el cliente esconde (un cristal roto). Con las cortinas
-- corridas, la mano se apoya en la tela (los paños no chocan con los rayos) y no se mete detrás.

-- Dónde da un rayo de apoyarse (como un RaycastResult, pero se puede mover: con las cortinas corridas, a la tela, y
-- entonces `Tela`).
type Toque = { Instance: BasePart, Position: Vector3, Normal: Vector3, Tela: boolean? }
-- Dónde debería ir una mano. `codo`: hacia dónde sale el codo, en el mundo (en las esquinas; en la pared y encima de
-- algo se calcula con la cámara en cada fotograma). `tela`: en unas cortinas corridas (no suena el cristal de detrás).
type Ideal = { tipo: string, parte: BasePart, pose: CFrame, normal: Vector3, codo: Vector3?, tela: boolean? }
-- Dónde está apoyada una mano: su pose, la normal de la superficie y el codo, respecto a lo que toca (por si se mueve).
type Apoyo = { tipo: string, parte: BasePart, rel: CFrame, normal: Vector3, codo: Vector3? }
-- estado: nil (no se apoya), "va" (yendo, con el muelle), "puesta" (pegada) o "suelta" (bajando). `fallos`: tandas de
-- rayos seguidas sin dar con dónde apoyarla.
type ManoApoyo = { apoyo: Apoyo?, estado: string?, desde: number, recolocada: boolean, fallos: number }

local LADOS = { "der", "izq" }
local SIGNO = { der = 1, izq = -1 }
local apoyos: { [string]: ManoApoyo } = {
	der = { apoyo = nil, estado = nil, desde = 0, recolocada = false, fallos = 0 },
	izq = { apoyo = nil, estado = nil, desde = 0, recolocada = false, fallos = 0 },
}
local libreAntes: { [string]: boolean } = { der = false, izq = false }
local proximoSondeo = 0
local sonadoApoyo = 0

local filtroApoyo = RaycastParams.new()
filtroApoyo.FilterType = Enum.RaycastFilterType.Exclude
filtroApoyo.RespectCanCollide = true -- ni adornos, ni mallas que solo se ven, ni mandos, ni puertas abiertas
filtroApoyo.IgnoreWater = true
local conGrupo = false

local function filtroParaApoyar(): RaycastParams
	local fuera: { Instance } = { camara } -- lo que se pinta delante de la cámara (las manos, la pistola)
	for _, nombre in { "Bichos", "Objetos" } do
		local carpeta = workspace:FindFirstChild(nombre)
		if carpeta then
			table.insert(fuera, carpeta)
		end
	end
	for _, j in Players:GetPlayers() do
		if j.Character then
			table.insert(fuera, j.Character)
		end
	end
	for _, vendedor in CollectionService:GetTagged("Vendedor") do
		table.insert(fuera, vendedor) -- a la gente no se la toca: las manos irían a su pecho
	end
	filtroApoyo.FilterDescendantsInstances = fuera
	if not conGrupo then
		-- Lo que alguien lleva en brazos (grupo Cargado) no choca con los personajes (grupo Personajes, los dos de
		-- Cargar): tampoco se apoya uno en ello.
		local ok, hay = pcall(PhysicsService.IsCollisionGroupRegistered, PhysicsService, "Personajes")
		if ok and hay then
			filtroApoyo.CollisionGroup = "Personajes"
			conGrupo = true
		end
	end
	return filtroApoyo
end

-- Las ventanas con las cortinas corridas entre tus ojos y el cristal, cerca (se buscan en cada tanda de rayos): su
-- centro (+Z hacia la sala), ancho y alto, como en sus atributos.
type Cortina = { centro: CFrame, ancho: number, alto: number }
local corridas: { Cortina } = {}
local function buscarCortinas(ojo: Vector3)
	table.clear(corridas)
	for _, v in CollectionService:GetTagged("Ventana") do
		local centro, ancho, alto = v:GetAttribute("Centro"), v:GetAttribute("Ancho"), v:GetAttribute("Alto")
		-- Persiana = cortinas corridas; sin vida, los paños se han caído (CasaVista).
		if v:GetAttribute("Persiana") == true and (v:GetAttribute("Vida") or 1) > 0 and typeof(centro) == "CFrame"
			and type(ancho) == "number" and type(alto) == "number"
			and (centro.Position - ojo).Magnitude < ancho / 2 + APOYO.rayo + 2
			and centro:PointToObjectSpace(ojo).Z > APOYO.cortina then
			table.insert(corridas, { centro = centro, ancho = ancho, alto = alto })
		end
	end
end

-- Si el rayo ha dado detrás de unas cortinas corridas (la mano tendría que atravesar la tela): en lo que mira a la
-- sala, el toque pasa a la tela; en lo demás (la repisa de debajo), no hay nada que tocar (nil).
local function conCortinas(t: Toque): Toque?
	for _, c in corridas do
		local p = c.centro:PointToObjectSpace(t.Position)
		if math.abs(p.X) <= c.ancho / 2 + APOYO.cortinaLado and p.Y <= c.alto / 2 + APOYO.cortinaArriba
			and p.Y >= -c.alto / 2 - APOYO.cortinaAbajo and p.Z > -0.6 and p.Z < APOYO.cortina then
			local n = c.centro:VectorToObjectSpace(t.Normal)
			if n.Z < 0.7 then
				return nil
			end
			return { Instance = t.Instance, Position = t.Position + t.Normal * ((APOYO.cortina - p.Z) / n.Z), Normal = t.Normal,
				Tela = true }
		end
	end
	return t
end

-- Un rayo de apoyarse. Lo diminuto (un pomo, una lata) y lo que el cliente ha escondido (un cristal roto) no tapan: el
-- rayo sigue detrás (la puerta del pomo, el marco de la ventana).
local function rayoApoyo(desde: Vector3, hacia: Vector3, filtro: RaycastParams): Toque?
	for _ = 1, 3 do
		local r = workspace:Raycast(desde, hacia, filtro)
		if not r then
			return nil
		end
		local p = r.Instance
		if p:IsA("Terrain") then
			return { Instance = p, Position = r.Position, Normal = r.Normal }
		end
		local t = p.Size
		if math.max(t.X, t.Y, t.Z) >= APOYO.minimo and p.LocalTransparencyModifier < 0.99 then
			return conCortinas({ Instance = p, Position = r.Position, Normal = r.Normal })
		end
		filtro:AddToFilter(p) -- hasta la próxima tanda (filtroParaApoyar lo rehace)
	end
	return nil
end

-- Lo horizontal de un vector, de largo 1 (nil si es casi vertical).
local function plano(v: Vector3): Vector3?
	local h = Vector3.new(v.X, 0, v.Z)
	return if h.Magnitude > 1e-3 then h.Unit else nil
end

-- Cómo te mueves en esta tanda de rayos (la velocidad del cuerpo, en horizontal).
local velTanda = Vector3.zero

-- ¿Te estás deslizando por delante de la superficie de normal `n` (andando de lado o en diagonal)?
local function resbalando(n: Vector3): boolean
	local lado = velTanda - n * velTanda:Dot(n)
	return Vector3.new(lado.X, 0, lado.Z).Magnitude > APOYO.resbala
end

-- Si lo que ha tocado `r` es una pared en la que apoyarse (vertical, delante de ti, cerca, y no te estás yendo de ella
-- ni pasando por delante): su normal horizontal y lo lejos que está de los ojos. nil si no.
local function caraDePared(r: Toque, ojo: Vector3, frente: Vector3, mueve: Vector3): (Vector3?, number)
	local n = r.Normal
	local nh = plano(n)
	if not nh or math.abs(n.Y) > 0.45 or -nh:Dot(frente) < APOYO.deFrente then
		return nil, 0 -- el suelo, algo inclinado o una pared que no tienes delante
	end
	if (mueve.Magnitude > 0.1 and mueve:Dot(-nh) < 0.3) or resbalando(nh) then
		return nil, 0 -- solo yendo hacia ella o quieto (no al pasar por su lado, al resbalar por ella ni al irte)
	end
	local d = (ojo - r.Position):Dot(nh)
	if d > APOYO.largo then
		return nil, 0 -- lejos (los rayos son más largos para dar con ella aunque la mires de lado)
	end
	return nh, d
end

-- La palma de `lado` contra la pared que ha tocado `r` (a `d` de los ojos): por debajo de los ojos (más cuanto más lejos
-- está la pared, para que se vea), los dedos hacia arriba y un poco hacia fuera, el dorso hacia ti. nil si no llega.
local function enPared(lado: string, r: Toque, ojo: Vector3, d: number): Ideal?
	local n = r.Normal
	local sube = (Vector3.yAxis - n * n.Y).Unit -- hacia arriba, por la pared
	local alto = ojo.Y - math.clamp(d, 0.5, APOYO.largo) * APOYO.inclina + APOYO.alto[lado]
	local punto = r.Position + sube * ((alto - r.Position.Y) / sube.Y)
	if (punto - Manos.hombro(lado)).Magnitude > APOYO.llegaMano then
		return nil
	end
	local fuera = sube:Cross(n) * SIGNO[lado]
	return {
		tipo = "pared",
		parte = r.Instance :: BasePart,
		pose = Manos.palma(punto + n * APOYO.separa, sube + fuera * APOYO.gira, n),
		normal = n,
		tela = r.Tela,
	}
end

-- La mano `lado` contra la pared que toque el rayo de `desde` a `hacia` (nil si no es una pared buena).
local function manoEnPared(lado: string, desde: Vector3, hacia: Vector3, filtro: RaycastParams, ojo: Vector3,
	frente: Vector3, mueve: Vector3): Ideal?
	local r = rayoApoyo(desde, hacia, filtro)
	if not r then
		return nil
	end
	local nh, d = caraDePared(r, ojo, frente, mueve)
	return if nh then enPared(lado, r, ojo, d) else nil
end

-- Las manos libres contra lo que tengas delante. Un rayo por el centro busca la pared; si la hay, cada mano va derecha a
-- ella desde donde le cae natural (así llega aunque la mires de lado), y si es algo estrecho (un poste, un tronco), una
-- sola mano, al centro. Si no hay nada justo delante, un rayo por cada lado, por si solo hay pared a uno (un pilar, el
-- canto de una puerta).
local function paredesDelante(filtro: RaycastParams, ojo: Vector3, frente: Vector3, derecha: Vector3, mueve: Vector3,
	libres: { [string]: boolean }): { [string]: Ideal? }
	local base = ojo - Vector3.new(0, APOYO.bajo, 0)
	local res: { [string]: Ideal? } = {}
	local centro = rayoApoyo(base, frente * APOYO.rayo, filtro)
	local nh: Vector3?, d = nil, 0
	if centro then
		nh, d = caraDePared(centro, ojo, frente, mueve)
	end
	if centro and nh then
		for _, lado in LADOS do
			if libres[lado] then
				local desde = base + derecha * (SIGNO[lado] * (APOYO.ancho + d * APOYO.abre))
				local hasta = (desde - centro.Position):Dot(nh)
				if hasta > 0.05 then
					-- Más largo que hasta la pared del centro: con las cortinas corridas, el cristal o la pared de detrás
					-- de la tela quedan casi un stud más allá (y lo lejos ya lo descarta caraDePared).
					res[lado] = manoEnPared(lado, desde, -nh * (hasta + 1.2), filtro, ojo, frente, mueve)
				end
			end
		end
		local sola = if libres.der then "der" elseif libres.izq then "izq" else nil
		if sola and not res.der and not res.izq then
			res[sola] = enPared(sola, centro, ojo, d)
		end
	else
		for _, lado in LADOS do
			if libres[lado] then
				local s = SIGNO[lado]
				res[lado] = manoEnPared(lado, base + derecha * (s * APOYO.ancho),
					(frente + derecha * (s * APOYO.abreRayo)).Unit * APOYO.rayo, filtro, ojo, frente, mueve)
			end
		end
	end
	return res
end

-- Agarrada al borde de una cara que se acaba (una esquina, el marco de una puerta). `cerca`: el último rayo que daba en
-- esa cara; `lejos`: hacia dónde iba el primero que ya no. nil si en realidad la cara sigue (los rayos se quedaban
-- cortos) o si el borde te queda detrás. Con el hombro de este lado del borde, la palma en la cara, justo antes del
-- borde, y los dedos rodeándolo. Con el hombro más allá (`hombro`: dónde queda asomado del todo; la cámara y el hombro
-- se van hacia ese lado y miras por delante del borde), lo coge por el canto, como una C: la palma en el canto y los
-- dedos hacia dentro, por detrás de la cara (cogido como en el otro caso, la muñeca se doblaba del revés).
local function agarrarBorde(cerca: Toque, desde: Vector3, lejos: Vector3, frente: Vector3, hombro: Vector3): Ideal?
	local n = plano(cerca.Normal)
	if not n then
		return nil
	end
	local den = lejos:Dot(n)
	if den > -0.05 then
		return nil -- el rayo de fuera ya no iba hacia esa cara: no se sabe dónde acaba
	end
	local k = (cerca.Position - desde):Dot(n) / den
	if k > APOYO.borde - 0.05 then
		return nil -- la cara sigue más allá de donde llegaban los rayos
	end
	-- Por la cara, de donde daba el rayo hacia donde habría dado el de fuera si la cara siguiera: hacia el borde.
	local hueco = desde + lejos * k - cerca.Position
	hueco = Vector3.new(hueco.X, 0, hueco.Z)
	hueco -= n * hueco:Dot(n)
	if hueco.Magnitude < 1e-3 then
		return nil
	end
	local t = hueco.Unit
	local punto, pose, normal, codo
	if (hombro - cerca.Position):Dot(t) > 0 then
		local esquina = cerca.Position + hueco / 2 -- el borde está entre los dos rayos
		punto = esquina + t * APOYO.separa - n * APOYO.canto
		pose, normal = Manos.palma(punto, -n, t), t
		local c = APOYO.codoCanto
		codo = n * c.atras + t * c.fuera - Vector3.yAxis * c.abajo
	else
		punto = cerca.Position + n * APOYO.separa - t * 0.06
		pose, normal = Manos.palma(punto, t - n * APOYO.rodea, n + t * APOYO.rodea), n
		codo = n * APOYO.codoBorde.atras - Vector3.yAxis * APOYO.codoBorde.abajo
	end
	if (punto - desde):Dot(frente) < 0.1 then
		return nil -- detrás de ti
	end
	return { tipo = "borde", parte = cerca.Instance :: BasePart, pose = pose, normal = normal, codo = codo }
end

-- Asomado hacia `lado`: busca el borde barriendo con rayos desde el cuerpo (no desde la cámara, que ya se ha ido hacia
-- ese lado), de delante hacia ese lado. Donde un rayo da en una cara y el siguiente ya no (o da en algo que queda detrás
-- de ella), allí se acaba; unos rayos más entre los dos afinan dónde.
local function borde(lado: string, filtro: RaycastParams, raiz: BasePart, ojo: Vector3, frente: Vector3,
	derecha: Vector3, afinar: number): Ideal?
	local s = SIGNO[lado]
	local desde = Vector3.new(raiz.Position.X, ojo.Y - APOYO.bajoBorde, raiz.Position.Z)
	local function hacia(a: number): Vector3
		return frente * math.cos(a) + derecha * (s * math.sin(a))
	end
	local function tiro(a: number): Toque?
		local r = rayoApoyo(desde, hacia(a) * APOYO.borde, filtro)
		return if r and math.abs(r.Normal.Y) < 0.45 then r else nil
	end
	local function mismaCara(a: Toque, b: Toque): boolean
		return a.Normal:Dot(b.Normal) > 0.9 and math.abs((b.Position - a.Position):Dot(a.Normal)) < 0.15
	end
	-- ¿Se acaba `a` entre los dos? (el otro no da en nada, o da en algo que queda detrás de la cara de `a`)
	local function acaba(a: Toque?, b: Toque?): boolean
		return a ~= nil and (b == nil or (not mismaCara(a, b) and (b.Position - a.Position):Dot(a.Normal) < -0.3))
	end
	-- Dónde queda el hombro asomado del todo (CuerpoVista lleva la cámara de lado Config.Postura.Asomar; el hombro sale
	-- otro tanto de ella): con el de ahora, al empezar a asomarse cogía la esquina de una forma y al rato de la otra.
	local hombro = desde + derecha * (s * (Config.Postura.Asomar + APOYO.hombroLado))
	local cada = math.rad(90) / APOYO.rayosBorde
	local antes = tiro(0)
	for k = 1, APOYO.rayosBorde do
		local ahora = tiro(k * cada)
		local cerca: Toque? = nil
		local aCerca, aLejos = 0, 0
		if acaba(antes, ahora) then
			cerca, aCerca, aLejos = antes, (k - 1) * cada, k * cada
		elseif acaba(ahora, antes) then
			cerca, aCerca, aLejos = ahora, k * cada, (k - 1) * cada
		end
		if cerca then
			local junto = cerca :: Toque
			for _ = 1, afinar do
				local medio = (aCerca + aLejos) / 2
				local r = tiro(medio)
				if r and mismaCara(junto, r) then
					junto, aCerca = r, medio
				else
					aLejos = medio
				end
			end
			local ideal = agarrarBorde(junto, desde, hacia(aLejos), frente, hombro)
			if ideal then
				return ideal
			end
		end
		antes = ahora
	end
	return nil
end

-- Agachado: la palma encima de lo bajo que tengas delante, con los dedos hacia delante. nil si a esa altura ya hay pared
-- (eso es apoyarse en la pared) o si solo está el suelo.
local function encima(lado: string, filtro: RaycastParams, ojo: Vector3, frente: Vector3, derecha: Vector3,
	suelo: number): Ideal?
	local s = SIGNO[lado]
	local arriba = Vector3.new(ojo.X, ojo.Y + APOYO.sobreOjos, ojo.Z) + derecha * (s * APOYO.anchoEncima)
	for _, d in APOYO.encima do
		if rayoApoyo(arriba, frente * d, filtro) then
			return nil
		end
		local r = rayoApoyo(arriba + frente * d, Vector3.new(0, -(APOYO.sobreOjos + APOYO.bajoEncima), 0), filtro)
		if r and r.Normal.Y > 0.8 and r.Position.Y > suelo + APOYO.sobreSuelo then
			return {
				tipo = "encima",
				parte = r.Instance :: BasePart,
				pose = Manos.palma(r.Position + Vector3.new(0, APOYO.separa, 0), frente - derecha * (s * APOYO.adentro),
					Vector3.yAxis),
				normal = Vector3.yAxis,
			}
		end
	end
	return nil
end

-- El sitio, si la mano llega desde su hombro (nil si no). La pared ya lo mira al buscarla (enPared); el borde y lo de
-- encima, aquí. Si no, la mano iría y se soltaría en el mismo fotograma (poseMano, APOYO.alcance) una y otra vez. En una
-- esquina, la mano puede bajar un poco por ella para llegar (asomado, el hombro se ha ido con la cámara hacia ese lado).
local function llega(lado: string, ideal: Ideal?): Ideal?
	if not ideal then
		return nil
	end
	local d = ideal.pose.Position - Manos.hombro(lado)
	local r = APOYO.llegaMano
	if d.Magnitude <= r then
		return ideal
	end
	local llano = d.X * d.X + d.Z * d.Z
	if ideal.tipo ~= "borde" or llano >= r * r or d.Y <= 0 then
		return nil
	end
	local baja = d.Y - math.sqrt(r * r - llano) + 0.02
	if baja > APOYO.bajaBorde then
		return nil
	end
	ideal.pose -= Vector3.new(0, baja, 0)
	return ideal
end

-- Una tanda de rayos: dónde debería ir cada mano libre (nil = en ningún sitio).
local function sondear(hum: Humanoid, raiz: BasePart, libres: { [string]: boolean }): { [string]: Ideal? }
	local cf = camara.CFrame
	local ojo = cf.Position
	local frente = plano(cf.LookVector) or plano(raiz.CFrame.LookVector) or Vector3.new(0, 0, -1)
	local derecha = frente:Cross(Vector3.yAxis)
	local mueve = hum.MoveDirection
	local vel = raiz.AssemblyLinearVelocity
	velTanda = Vector3.new(vel.X, 0, vel.Z)
	local filtro = filtroParaApoyar()
	buscarCortinas(ojo)
	local res = paredesDelante(filtro, ojo, frente, derecha, mueve, libres)
	-- Agachado, lo bajo manda sobre la pared: si su cara de arriba queda a mano, la mano va encima. No andando de lado
	-- (iría saltando de un sitio a otro de la mesa).
	if jugador:GetAttribute("Agachado") == true and (mueve.Magnitude < 0.1 or mueve:Dot(frente) > 0.3)
		and not resbalando(frente) then
		local abajo = workspace:Raycast(raiz.Position, Vector3.new(0, -8, 0), filtro)
		local suelo = if abajo then abajo.Position.Y else raiz.Position.Y - 3
		for _, lado in LADOS do
			if libres[lado] then
				res[lado] = llega(lado, encima(lado, filtro, ojo, frente, derecha, suelo)) or res[lado]
			end
		end
	end
	-- Asomado, la mano de ese lado al borde de la esquina, si lo hay.
	local asomado = jugador:GetAttribute("Asomado")
	local afinar = if jugador:GetAttribute("Rendimiento") == true then 1 else APOYO.afinar
	for _, lado in LADOS do
		if libres[lado] and asomado == SIGNO[lado] then
			res[lado] = llega(lado, borde(lado, filtro, raiz, ojo, frente, derecha, afinar)) or res[lado]
		end
	end
	return res
end

-- De pie en el suelo (no en el aire, sentado, trepando ni nadando) y sin mirar por la mirilla ni entre las cortinas
-- (atributos locales de MirarVista).
local function puedeApoyarse(hum: Humanoid): boolean
	local estado = hum:GetState()
	return hum.Health > 0 and not hum.Sit and hum.FloorMaterial ~= Enum.Material.Air
		and (estado == Enum.HumanoidStateType.Running or estado == Enum.HumanoidStateType.RunningNoPhysics
			or estado == Enum.HumanoidStateType.Landed)
		and jugador:GetAttribute("Mirilla") ~= true and jugador:GetAttribute("Vistazo") == nil
end

local function poseApoyo(a: Apoyo): CFrame
	return a.parte.CFrame * a.rel
end

-- Al apoyar la mano: un cristal traquetea un poco en su marco y una puerta vieja cruje a veces (solo el principio del
-- crujido de la casa, que es largo). Flojito: es tu mano. En la tela de unas cortinas, nada.
local function sonarApoyo(ideal: Ideal)
	local ahora = os.clock()
	if ahora - sonadoApoyo < APOYO.cadaSonido or ideal.tela then
		return
	end
	local parte, punto = ideal.parte, ideal.pose.Position
	if parte.Name == "Cristal" then
		sonadoApoyo = ahora
		local s = Sonido.en("CristalVibra", punto, azar:NextNumber(0.95, 1.05))
		s.Volume *= APOYO.volumenCristal
	elseif etiquetado(parte, "Puerta") and azar:NextNumber() < APOYO.cruje then
		sonadoApoyo = ahora
		local s = Sonido.en("Cruje", punto, azar:NextNumber(0.95, 1.05))
		s.Volume *= APOYO.volumenCruje
		TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.45),
			{ Volume = 0 }):Play()
	end
end

-- Lo que dicen los rayos para esa mano: apoyarla, dejarla donde está o soltarla. Sin apoyo, la suelta tras APOYO.fallos
-- tandas seguidas (una sola es un parpadeo, un rayo que roza un canto: bajaba y volvía de un tirón), o enseguida con
-- `deGolpe` (al saltar, sentarse, trepar o nadar).
local function aplicar(lado: string, ideal: Ideal?, ahora: number, deGolpe: boolean?)
	local m = apoyos[lado]
	local apoyada = m.estado == "va" or m.estado == "puesta"
	if not ideal then
		m.fallos += 1
		if apoyada and (deGolpe or m.fallos >= APOYO.fallos) then
			m.estado, m.desde = "suelta", ahora
		end
		return
	end
	m.fallos = 0
	local a = m.apoyo
	if apoyada and a and a.tipo == ideal.tipo and a.parte.Parent then
		local donde = poseApoyo(a)
		local margen = if a.tipo == "borde" then APOYO.recolocarBorde else APOYO.recolocar
		if (donde.Position - ideal.pose.Position).Magnitude < margen and donde.UpVector:Dot(ideal.pose.UpVector) > 0.9 then
			return -- se queda donde está: no resbala al mirar un poco alrededor
		end
	end
	if not apoyada then
		sonarApoyo(ideal)
	end
	local cf = ideal.parte.CFrame
	m.apoyo = { tipo = ideal.tipo, parte = ideal.parte, rel = cf:ToObjectSpace(ideal.pose),
		normal = cf:VectorToObjectSpace(ideal.normal), codo = ideal.codo and cf:VectorToObjectSpace(ideal.codo) }
	m.estado, m.desde, m.recolocada = "va", ahora, apoyada
end

-- Hacia dónde sale el codo de la mano apoyada en la pared en `objetivo` (normal `normal`): pegado a ella, hacia fuera;
-- a un brazo, hacia abajo (APOYO.codo y APOYO.codoLejos, mezclados según lo lejos que están tus ojos).
local function codoPared(lado: string, cf: CFrame, objetivo: CFrame, normal: Vector3): Vector3
	local cerca, lejos = APOYO.codo, APOYO.codoLejos
	local d = (cf.Position - objetivo.Position):Dot(normal) + APOYO.separa
	local k = (d - cerca.d) / (lejos.d - cerca.d)
	return cf.RightVector * (SIGNO[lado] * lerp(cerca.fuera, lejos.fuera, k)) - cf.UpVector * lerp(cerca.abajo, lejos.abajo, k)
		+ normal * lerp(cerca.atras, lejos.atras, k)
end

-- La pose de esa mano en este fotograma (nil: no la pide), su muelle, hacia dónde sale el codo (nil: el de siempre) y
-- cuánto se mece (nil: lo de siempre). Yendo a la pared, el meneo se apaga a la vez que se endurece el muelle: pegada ya
-- no lo lleva, y si se quitara de golpe al pegarse, la mano daría un saltito.
local function poseMano(lado: string, libre: boolean, ahora: number, cf: CFrame, frente: Vector3)
	: (CFrame?, number, Vector3?, number?)
	local m = apoyos[lado]
	if not libre then
		m.estado, m.apoyo = nil, nil -- la lleva otra capa: al soltarla se vuelve a mirar enseguida
		return nil, 0, nil, nil
	end
	local a = m.apoyo
	if m.estado == "va" or m.estado == "puesta" then
		if not (a and a.parte.Parent) then
			m.estado, m.desde = "suelta", ahora
		else
			local objetivo = poseApoyo(a)
			local normal = a.parte.CFrame:VectorToWorldSpace(a.normal)
			local codo = if a.codo then a.parte.CFrame:VectorToWorldSpace(a.codo)
				elseif a.tipo == "encima" then cf.RightVector * (SIGNO[lado] * APOYO.codoEncima.fuera)
					- frente * APOYO.codoEncima.atras
				else codoPared(lado, cf, objetivo, normal)
			local hacia = objetivo.Position - cf.Position
			if (objetivo.Position - Manos.hombro(lado)).Magnitude > APOYO.alcance
				or Vector3.new(hacia.X, 0, hacia.Z):Dot(frente) < 0.05 then
				m.estado, m.desde = "suelta", ahora -- te has ido de golpe o te has dado la vuelta
			elseif m.estado == "va" then
				local k = math.clamp((ahora - m.desde) / APOYO.llega, 0, 1)
				if m.recolocada then
					objetivo += normal * (APOYO.levanta * math.sin(math.pi * k))
				end
				if k >= 1 then
					m.estado = "puesta"
				end
				return objetivo, lerp(APOYO.muelle, APOYO.muelleFin, suave(k)), codo, 1 - suave(k)
			else
				-- Pegada: quieta en la pared aunque mires alrededor o te mezas al respirar.
				return objetivo, math.huge, codo, 0
			end
		end
	end
	if m.estado == "suelta" then
		if ahora - m.desde < APOYO.suelta then
			return Manos.reposo(lado), APOYO.muelleSuelta, nil, nil
		end
		m.estado, m.apoyo = nil, nil
	end
	return nil, 0, nil, nil
end

local function capaPared(): Manos.Pose?
	local ahora = os.clock()
	local personaje = jugador.Character
	local hum = personaje and personaje:FindFirstChildOfClass("Humanoid")
	local raiz = personaje and personaje:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not raiz or Manos.escondidas() then
		for _, lado in LADOS do
			apoyos[lado].estado, apoyos[lado].apoyo = nil, nil -- escondidas de golpe: al volver, suben desde abajo
			libreAntes[lado] = false
		end
		return nil
	end
	local libres: { [string]: boolean } = {}
	local alguna = false
	for _, lado in LADOS do
		local libre = (Manos.ocupadaPor(lado) or 0) <= APOYO.prioridad
		if libre and not libreAntes[lado] then
			proximoSondeo = 0 -- se acaba de quedar libre: mirar ya, sin esperar
		end
		libreAntes[lado] = libre
		libres[lado] = libre
		alguna = alguna or libre
	end
	if not puedeApoyarse(hum) then
		for _, lado in LADOS do
			aplicar(lado, nil, ahora, true) -- al saltar, sentarse o trepar, la mano se va enseguida
		end
	elseif alguna and ahora >= proximoSondeo then
		proximoSondeo = ahora + (if jugador:GetAttribute("Rendimiento") == true then APOYO.cadaLento else APOYO.cada)
		local ideales = sondear(hum, raiz, libres)
		for _, lado in LADOS do
			if libres[lado] then
				aplicar(lado, ideales[lado], ahora)
			end
		end
	end
	local cf = camara.CFrame
	local frente = plano(cf.LookVector) or plano(raiz.CFrame.LookVector) or Vector3.new(0, 0, -1)
	local der, velDer, codoDer, meneoDer = poseMano("der", libres.der, ahora, cf, frente)
	local izq, velIzq, codoIzq, meneoIzq = poseMano("izq", libres.izq, ahora, cf, frente)
	if not der and not izq then
		return nil
	end
	return { der = der, izq = izq, velDer = velDer, velIzq = velIzq, codoDer = codoDer, codoIzq = codoIzq,
		meneoDer = meneoDer, meneoIzq = meneoIzq }
end

-- ===== Correr (14.8) =====
-- Corriendo, las manos libres bracean (capa "Correr", por debajo de apoyarse y del aire: contra una pared o en el aire
-- mandan ellas); agotado y ya sin correr, asoman abajo con la respiración. Al tropezar, se adelantan para frenar la
-- caída (capa "Tropiezo", por encima de la pared y del aire pero no de lo que llevas). Con Rendimiento, sin braceo ni
-- jadeo (los brazos, como al andar); el tropiezo sí. Escondidas (muerto, escondido, cinemática…), nada: lo mira Manos.
local CORRER = {
	prioridad = 3, -- la más baja de todas (debajo de apoyarse, 4)
	tropiezo = 6, -- encima del aire (5), debajo de la linterna (10)
	velocidad = 26, -- el muelle del braceo: deprisa, que siga al paso
	velJadeo = 9, -- agotado, despacio
	velTropiezo = 24,
	jadeoSube = 2, -- por segundo: lo deprisa que asoman las manos al agotarte (en ~0,5 s)...
	jadeoBaja = 1.5, -- ...y que se van
}
local jadeo = 0 -- de 0 a 1, lo que asoman las manos libres agotado

local function capaCorrer(dt: number): Manos.Pose?
	local ritmo = CorrerVista.ritmo()
	local agotado = CorrerVista.agotado() and not CorrerVista.corriendo()
	if jugador:GetAttribute("Rendimiento") == true then
		ritmo, agotado = 0, false
	end
	jadeo = if agotado then math.min(1, jadeo + dt * CORRER.jadeoSube) else math.max(0, jadeo - dt * CORRER.jadeoBaja)
	if ritmo < 0.02 and jadeo <= 0.01 then
		return nil
	end
	local cf = camara.CFrame
	local fase, respiro, cansancio = Manos.fasePaso(), Manos.respiro(), CorrerVista.cansancio()
	local pose: Manos.Pose = {
		velocidad = if ritmo > 0.3 then CORRER.velocidad else CORRER.velJadeo,
		meneoDer = 0, -- el braceo ya es el meneo
		meneoIzq = 0,
	}
	for _, lado in LADOS do
		local otro = if lado == "der" then "izq" else "der"
		local menos = if (Manos.ocupadaPor(otro) or 0) >= 10 then 1 else 0 -- la otra lleva algo (la linterna o más)
		local pos, dedos, dorso, codo = ManosCorrer.manoLibre(SIGNO[lado], fase, ritmo, jadeo, respiro, cansancio, menos)
		local mano = Manos.palma(cf * pos, cf:VectorToWorldSpace(dedos), cf:VectorToWorldSpace(dorso))
		if lado == "der" then
			pose.der, pose.codoDer = mano, cf:VectorToWorldSpace(codo)
		else
			pose.izq, pose.codoIzq = mano, cf:VectorToWorldSpace(codo)
		end
	end
	return pose
end

local function capaTropiezo(): Manos.Pose?
	local t = CorrerVista.tropiezo()
	if not t or ManosCorrer.tropiezo(t) <= 0 then
		return nil
	end
	local cf = camara.CFrame
	local pose: Manos.Pose = { velocidad = CORRER.velTropiezo, meneoDer = 0, meneoIzq = 0 }
	for _, lado in LADOS do
		local pos, dedos, dorso, codo = ManosCorrer.frenar(SIGNO[lado], t)
		local mano = Manos.palma(cf * pos, cf:VectorToWorldSpace(dedos), cf:VectorToWorldSpace(dorso))
		if lado == "der" then
			pose.der, pose.codoDer = mano, cf:VectorToWorldSpace(codo)
		else
			pose.izq, pose.codoIzq = mano, cf:VectorToWorldSpace(codo)
		end
	end
	return pose
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
	Manos.capa("Pared", APOYO.prioridad, capaPared)
	Manos.capa("Correr", CORRER.prioridad, capaCorrer)
	Manos.capa("Tropiezo", CORRER.tropiezo, capaTropiezo)
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
