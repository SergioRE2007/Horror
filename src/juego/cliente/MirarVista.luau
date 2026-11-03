-- Mirar sin abrir (pedido por el usuario: "mirar entre las cortinas o por la mirilla de la puerta principal (útil con el
-- Imitador)"). Todo en el cliente: los carteles, la mano, la cámara y lo que se ve.
--   Mirilla (puerta principal, por dentro, cerrada y entera): cartel "Look through". La mano derecha va a la puerta y,
--     al llegar, aparta la tapita de latón (la mirilla se ve en la hoja, por las dos caras); la izquierda baja la
--     linterna. La cabeza se acerca, todo se cierra en negro y se ve desde la cara de fuera con ojo de pez, un círculo
--     negro alrededor, algo de desenfoque y frío, y la respiración meciendo la vista. Mientras, atributo LOCAL
--     Mirilla = true en el jugador (ImitadorVista hace que el Imitador reaccione; la cámara está entonces en la mirilla).
--   Entre las cortinas (cada ventana con las cortinas cerradas y entera, por dentro): cartel "Peek". La mano coge el
--     borde de la cortina, la cabeza se mete por la ranura hasta casi el cristal (las cortinas no se mueven: son de
--     CasaVista) y se ve fuera entre dos bandas de tela oscura. Para ver al Golpeador o al Raspador sin abrir.
--   Los dos carteles con TECLA (MANDO en el mando; en el móvil, el botón de acción de Controles). Mientras dura, atributo
--     LOCAL Vistazo = "Mirilla" o "Ventana". Mirando se puede girar un poco la vista (ratón, palanca derecha o dedo).
--   Se sale al volver a pulsar (también B del mando, clic o un toque), al moverse o saltar, a los MIRAR s, al abrir la
--     mochila o el móvil, al agacharse o asomarse; de golpe (con un respingo) si golpean, agrietan o rompen lo que
--     miras; y sin animación si te pillan, mueres, te escondes o empieza una cinemática. Asomado no se empieza (mirando
--     por la mirilla PosturaVista no deja asomarse: el cambio lo cortaba nada más empezar).
--   Un bicho cerca a la vista (con un rayo: tras una pared no cuenta): golpe de tensión (Sobresalto), contienes el aire
--     (Contener, y calla la respiración; al acabar, Exhalar), la vista da un respingo y la respiración se acelera. El
--     Imitador mientras finge en la puerta no cuenta (lo delataría): su susto en la mirilla es de ImitadorVista; cuando
--     se pega a ella, solo el respingo y contener el aire.
-- La cámara va en Scriptable y el HUD y los carteles 3D se esconden; todo se devuelve siempre (cámara Custom, campo de
-- visión, HUD, carteles, atributos a nil), aunque algo falle. Con Rendimiento (se mira en cada vistazo): sin
-- desenfoque, sin vaho en el cristal y sin vaivenes de adorno.
-- ManosGestos también reacciona a estos carteles (coger el pomo, tocar la ventana): aquí se pisa ese gesto.
-- Hecho sin Studio: los números de la vista están aquí arriba para retocarlos al mirarlo.
local CollectionService = game:GetService("CollectionService")
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Manos = require(script.Parent.Manos)
local ManosGestos = require(script.Parent.ManosGestos)
local Sonido = require(script.Parent.Sonido)
local Ui = require(script.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))

local MirarVista = {}

local jugador = Players.LocalPlayer
local camara = workspace.CurrentCamera
local azar = Random.new()
local cfg = Config.Casa

-- ===== Números (a ojo, para mirarlos en Studio) =====

local TECLA = Enum.KeyCode.L -- libre: E abre la puerta y R repara
local MANDO = Enum.KeyCode.ButtonL2 -- X e Y son de los carteles de la casa
local ALCANCE = 5.5 -- studs del cartel (desde la cadera)
local CERCA = 16 -- más lejos ni se miran los carteles
local REPASO = 0.25 -- s entre repasos de los carteles
local DESCANSO = 0.6 -- s sin carteles al acabar (que la misma pulsación no vuelva a entrar)
local PRIORIDAD = 55 -- de los gestos de la mano: encima del toque de ManosGestos (50), debajo de la foto (60)
local MIRAR = 6 -- s mirando como mucho
-- Si una cinemática se quedó con la cámara y luego nadie la mueve en este tiempo, no era de nadie: vuelve la de Roblox.
-- Más que el plano quieto más largo de las cinemáticas (el primero de la huida, 3,4 s).
local ABANDONADA = 5
local PASO = "MirarVista" -- nombre del BindToRenderStep
local SALIR = "MirarSalir" -- y de la acción de salir

-- La mirilla.
local MIRILLA_ALTO = 4.7 -- studs del suelo (los ojos van a ~4,5)
local MIRILLA_FUERA = 0.26 -- la cámara, por fuera de la hoja (delante de los tablones del refuerzo, que sobresalen 0,23)
local MIRILLA_DENTRO = 0.3 -- hasta dónde se acerca la cabeza por dentro antes del negro
local MIRILLA_FOV = 100 -- ojo de pez
local MIRILLA_INCLINA = 8 -- grados hacia arriba: el Imitador es muy alto (a 2,5 studs, su cara queda a ~65°)
local MIRILLA_RADIO = 0.42 -- radio del círculo, en lado corto de la pantalla
local MIRILLA_BLUR = 2
local MIRILLA_TINTE = Color3.fromRGB(206, 220, 242) -- frío
local TAPA_GIRO = 100 -- grados que gira la tapita al apartarla
local TAPA_COLGADA = 0.085 -- del pivote de la tapita a su centro
local LATON = Color3.fromRGB(116, 92, 52)

-- Entre las cortinas.
local VENTANA_CARTEL = 1.0 -- el cartel, en la ranura (las cortinas cuelgan a ~0,75 del cristal)
local VENTANA_DELANTE = 1.15 -- la cabeza, delante de la ranura
local VENTANA_CERCA = 0.32 -- y al final, casi en el cristal (su cara de dentro está a 0,1)
local VENTANA_LADO = 0.5 -- a un lado del montante del medio de la cruceta
local VENTANA_FOV = 64
local VENTANA_INCLINA = -3 -- grados (hacia abajo: el bicho está en el suelo de fuera)
local RENDIJA = 0.525 -- cuánto se cierran las bandas mirando (1 = cerradas del todo)
local TELA = Color3.fromRGB(26, 11, 10) -- la cortina pegada al ojo, desenfocada
local VAHO = 0.18 -- lo opaco del vaho en el cristal al soltar el aire (de noche)

-- De noche, una luz floja y fría fuera para que se vea algo (la linterna se apaga con la cámara en Scriptable).
local LUZ_BRILLO, LUZ_ALCANCE, LUZ_COLOR = 0.35, 10, Color3.fromRGB(150, 170, 210)

-- La mano aparta la tapita (o coge la cortina) cuando llega a ella; de lejos llega al acercarse la cabeza.
local MANO_CERCA = 0.3 -- studs de la palma a su sitio para darla por llegada
local MANO_TARDE = 0.7 -- si a esta parte del acercamiento aún no ha llegado, la aparta igual
local MANO_SOLTAR = 0.2 -- s que aguanta la tapita (o la cortina) al volver antes de bajar

-- Tiempos (s).
local T = {
	camara = 0.28, -- la cámara empieza a moverse
	acercar = 0.36, -- más ACERCAR_STUD por stud hasta la puerta (o la ranura), hasta ACERCAR_MAX
	pasar = 0.16, -- ventana: de la ranura al cristal, con la tela tapándolo todo
	abrir = 0.3,
	cerrar = 0.13,
	volver = 0.32,
	golpe = 0.6, -- al salir de golpe, todo más deprisa
}
local ACERCAR_STUD, ACERCAR_MAX = 0.05, 0.65

-- Girar la vista mirando.
local GIRO_LADO, GIRO_ARRIBA, GIRO_ABAJO = math.rad(24), math.rad(26), math.rad(16)
local RATON = 0.0045 -- rad por píxel (por la sensibilidad de Roblox)
local TOQUE = 0.006
local PALANCA = 1.6 -- rad/s con la palanca a tope

-- Bichos a la vista.
local SUSTO_CERCA = 16 -- studs
local SUSTO_CADA = 12 -- s como poco entre dos golpes de tensión
local PEGADO = 2.2 -- studs de la cámara a la cabeza del Imitador: más cerca, se ha pegado a la mirilla
local RESPIRA = 0.55 -- volumen de tu respiración mirando (si hay sonido Respiracion), por el suyo

local EJE_Z = CFrame.Angles(0, math.pi / 2, 0) -- un cilindro (su eje es su X) con el eje a lo largo de Z
local GRANDE = 20000 -- píxeles: más que cualquier pantalla
-- Lo negro alrededor del cuadrado del círculo (AnchorPoint, Position, Size), hijas del círculo.
local PLANCHAS = {
	{ Vector2.new(0.5, 1), UDim2.fromScale(0.5, 0), UDim2.fromOffset(GRANDE, GRANDE) },
	{ Vector2.new(0.5, 0), UDim2.fromScale(0.5, 1), UDim2.fromOffset(GRANDE, GRANDE) },
	{ Vector2.new(1, 0.5), UDim2.fromScale(0, 0.5), UDim2.new(0, GRANDE, 1, 0) },
	{ Vector2.new(0, 0.5), UDim2.fromScale(1, 0.5), UDim2.new(0, GRANDE, 1, 0) },
}
-- El borde de la lente, difuminado hacia dentro (anillos de `desde` a `desde + grosor` radios) y un hilo azulado.
local ANILLOS = {
	{ desde = 0.84, grosor = 0.16, transparencia = 0.55, color = Color3.new(0, 0, 0) },
	{ desde = 0.92, grosor = 0.08, transparencia = 0.45, color = Color3.new(0, 0, 0) },
	{ desde = 0.97, grosor = 0.03, transparencia = 0.3, color = Color3.new(0, 0, 0) },
	{ desde = 0.82, grosor = 0.012, transparencia = 0.75, color = Color3.fromRGB(70, 84, 130) },
}
-- Con las manos ocupadas (también con el móvil en la mano) o fuera de juego no se mira.
local OCUPADO = { "Muerto", "Escondido", "MochilaAbierta", "Cargando", "Trabajando", "Cambiando", "MovilAbierto" }
-- Si cambian mirando, se deja de mirar.
local CORTAN = { "MochilaAbierta", "Cargando", "Trabajando", "Cambiando", "MovilAbierto", "Agachado", "Asomado" }

-- ===== Estado =====

type Elemento = {
	modelo: Model,
	tipo: string, -- "Mirilla" o "Ventana"
	punto: Attachment, -- de donde cuelga el cartel
	prompt: ProximityPrompt,
	cambio: number, -- última vez que se abrió o cerró (os.clock): a medio mover no se mira
	espera: number,
	centro: CFrame, -- el atributo Centro (LookVector hacia fuera)
	ancho: number,
	alto: number,
	-- La mirilla: la hoja, su signo (1: su -Z mira fuera), la altura del agujero en ella y medio grosor.
	hoja: BasePart?,
	signo: number,
	y0: number,
	grosor: number,
	tapa: NumberValue?, -- grados que está girada la tapita
	tapaMeta: number, -- y hacia dónde va
	piezas: { Instance },
	conexiones: { RBXScriptConnection },
}

type Vistazo = {
	el: Elemento,
	fase: string, -- "entrar", "mirar" o "salir"
	inicio: number,
	t0: number, -- cuándo empezó la fase (o el trozo de fase)
	prueba: boolean, -- lanzado desde Studio (Probar): vale desde lejos
	camara: boolean, -- la cámara ya es nuestra (Scriptable)
	carteles: boolean, -- los carteles 3D los hemos apagado nosotros
	alOtroLado: boolean, -- ya se ve fuera
	vuelto: boolean, -- al salir: ya ha vuelto a este lado
	pasando: boolean, -- ventana: cruzando la ranura
	agarre: number?, -- s desde el inicio en que la mano llegó a la tapita (o a la cortina)
	acercar: number, -- s que tarda la cabeza en llegar a la puerta (o a la ranura)
	desde: CFrame, -- de dónde parte la cámara en el trozo de ahora
	ajuste: Vector3, -- lo que la cámara de verdad estaba apartada de ojos() al empezar (se suma al volver)
	ultimo: CFrame?, -- lo último que se puso en la cámara (si cambia sola, la lleva otro)
	fovAntes: number,
	fovPuesto: number?,
	fovDesde: number, -- al salir: el campo de visión de partida
	radioAhora: number, -- el radio del círculo de la mirilla (píxeles)
	radioDesde: number, -- al salir: el de partida
	motivo: string, -- por qué se sale: "normal" o "golpe"
	mirada: Vector3, -- hacia dónde se mira al volver a los ojos
	altura: number, -- ventana: la cabeza respecto al centro de la ventana
	lado: number, -- ventana: a qué lado del montante del medio
	yaw: number,
	pitch: number,
	objYaw: number,
	objPitch: number,
	palanca: Vector2,
	sensibilidad: number,
	respira: number,
	tension: number,
	respingo: number,
	vio: boolean, -- has visto un bicho (contienes el aire hasta acabar)
	contiene: number, -- desde cuándo (os.clock; math.huge si no)
	pegado: boolean, -- el Imitador se ha pegado a la mirilla
	proximaMirada: number,
	aliento: Sound?, -- tu respiración mirando
	alientoBase: number,
	cierre: number, -- ventana: cómo de cerradas están las bandas
	cierreDesde: number, -- al salir: lo cerradas que estaban al empezar el trozo
	hud: ScreenGui?,
	gui: ScreenGui?,
	negro: Frame?,
	iris: Frame?,
	irisBorde: UIStroke?,
	anillos: { { borde: UIStroke, grosor: number } },
	bandas: { Frame },
	vineta: { Frame },
	vaho: BasePart?,
	efectos: { Instance },
	conexiones: { RBXScriptConnection },
}

local elementos: { [Model]: Elemento } = {}
local activo: Vistazo? = nil
local descanso = 0 -- hasta cuándo no hay carteles (os.clock)
local proximoSusto = 0

-- Para ver si un bicho se ve de verdad (sin paredes en medio). Las piezas de los bichos no se tocan con rayos (Cuerpo):
-- si el rayo llega a su cabeza sin chocar, se le ve.
local rayoVista = RaycastParams.new()
rayoVista.FilterType = Enum.RaycastFilterType.Exclude
rayoVista.IgnoreWater = true

local empezar: (el: Elemento, forzar: boolean?) -> ()
local pedirSalir: (v: Vistazo, motivo: string) -> ()
local limpiar: (v: Vistazo, como: string) -> ()

-- ===== Ayudas =====

local function lerp(a: number, b: number, k: number): number
	return a + (b - a) * k
end

-- Suave al empezar y al acabar.
local function suave(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

local function poco(): boolean
	return jugador:GetAttribute("Rendimiento") == true
end

local function cuerpo(): (Humanoid?, BasePart?)
	local personaje = jugador.Character
	local hum = personaje and personaje:FindFirstChildOfClass("Humanoid")
	local raiz = hum and hum.RootPart
	if not hum or not raiz or hum.Health <= 0 then
		return nil, nil
	end
	return hum, raiz
end

local function manosLibres(): boolean
	for _, atributo in OCUPADO do
		if jugador:GetAttribute(atributo) then
			return false
		end
	end
	-- Asomado (-1 o 1) tampoco: por la mirilla PosturaVista no deja asomarse y ese cambio cortaba el vistazo.
	local asomado = jugador:GetAttribute("Asomado")
	return not (type(asomado) == "number" and asomado ~= 0)
end

local function saltando(hum: Humanoid): boolean
	local estado = hum:GetState()
	return hum.Jump or estado == Enum.HumanoidStateType.Jumping or estado == Enum.HumanoidStateType.Freefall
end

-- Donde va la cámara en primera persona (como la de Roblox: la raíz más 1,5 y el CameraOffset, y medio stud detrás).
local function ojos(hum: Humanoid, raiz: BasePart, mirada: Vector3): CFrame
	local foco = raiz.CFrame:PointToWorldSpace(Vector3.new(0, 1.5 + (raiz.Size.Y - 2) / 2, 0) + hum.CameraOffset)
	local m = Vector3.new(mirada.X, math.clamp(mirada.Y, -0.8, 0.8), mirada.Z)
	m = if m.Magnitude > 1e-3 then m.Unit else raiz.CFrame.LookVector
	local pos = foco - m * 0.5
	return CFrame.lookAt(pos, pos + m)
end

-- ¿Se puede mirar ahora por aquí? Entera, quieta, cerrada (cortinas corridas) y desde dentro.
local function sePuede(el: Elemento, raiz: BasePart): boolean
	local m = el.modelo
	if (m:GetAttribute("Vida") or 0) <= 0 or os.clock() - el.cambio < el.espera then
		return false
	end
	if el.tipo == "Mirilla" then
		if m:GetAttribute("Abierta") then
			return false
		end
	elseif not m:GetAttribute("Persiana") or (m:GetAttribute("Cristal") or 0) >= cfg.GolpesCristal then
		return false
	end
	return (raiz.Position - el.centro.Position):Dot(el.centro.LookVector) < 0 -- por dentro (como Casa.puede)
end

-- ===== La mirilla: dónde está todo (sigue a la hoja si CasaVista la mueve o la comba) =====

local function haciaDentro(el: Elemento): Vector3
	return (el.hoja :: BasePart).CFrame:VectorToWorldSpace(Vector3.new(0, 0, el.signo))
end

-- Tu derecha, mirando la puerta desde dentro.
local function aLaDerecha(el: Elemento): Vector3
	return (el.hoja :: BasePart).CFrame:VectorToWorldSpace(Vector3.new(el.signo, 0, 0))
end

-- La vista por la mirilla: desde la cara de fuera, mirando fuera y un poco hacia arriba.
local function vistaMirilla(el: Elemento): CFrame
	local hoja = (el.hoja :: BasePart).CFrame
	local fuera = -haciaDentro(el)
	local ojo = hoja * Vector3.new(0, el.y0, -el.signo * (el.grosor + MIRILLA_FUERA))
	return CFrame.lookAt(ojo, ojo + fuera, hoja.UpVector) * CFrame.Angles(math.rad(MIRILLA_INCLINA), 0, 0)
end

-- La cabeza pegada a la puerta por dentro (antes del negro y al volver).
local function pegadoMirilla(el: Elemento): CFrame
	local hoja = (el.hoja :: BasePart).CFrame
	local ojo = hoja * Vector3.new(0, el.y0, el.signo * (el.grosor + MIRILLA_DENTRO))
	return CFrame.lookAt(ojo, ojo - haciaDentro(el), hoja.UpVector)
end

local function puntoTapa(el: Elemento): Vector3
	return (el.hoja :: BasePart).CFrame * Vector3.new(0, el.y0, el.signo * (el.grosor + 0.055))
end

-- La mano derecha en la tapita: la palma contra la puerta y los dedos arriba, con la punta en ella; `aparta` de 0 a 1
-- la lleva hacia tu derecha, con la tapita. La mano mide 0,36: su centro a 0,18 de la hoja, para no meterse en ella.
local function manoTapa(el: Elemento, aparta: number, despega: number): CFrame
	local arriba = (el.hoja :: BasePart).CFrame.UpVector
	local dentro = haciaDentro(el)
	local punto = puntoTapa(el) - arriba * 0.17 + aLaDerecha(el) * (0.03 + 0.1 * aparta) + dentro * (0.12 + despega)
	return Manos.palma(punto, arriba, dentro)
end

-- La tapita: se aparta deprisa y al soltarla cae y se balancea (sin balanceo con Rendimiento).
local function moverTapa(el: Elemento, abierta: boolean)
	local tapa = el.tapa
	if not tapa or not tapa.Parent then
		return
	end
	local destino = if abierta then TAPA_GIRO * el.signo else 0
	if el.tapaMeta == destino then
		return -- ya va hacia allí (al volver la sueltan la mano y la limpieza: un solo clic)
	end
	el.tapaMeta = destino
	local info = if abierta then TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		elseif poco() then TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		else TweenInfo.new(0.8, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out)
	TweenService:Create(tapa, info, { Value = destino }):Play()
	if not abierta then
		Sonido.en("Mirilla", puntoTapa(el), 0.85)
	end
end

local function pieza(nombre: string, tam: Vector3, cf: CFrame, color: Color3, material: Enum.Material, padre: Instance): Part
	local p = Instance.new("Part")
	p.Name = nombre
	p.Shape = Enum.PartType.Cylinder
	p.Size = tam
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = false -- pegada a la hoja: gira con ella
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.Parent = padre
	return p
end

-- La mirilla en la hoja (solo en este cliente; cada uno pone la suya): por dentro un aro de latón y la tapita, que
-- cuelga sobre el agujero y gira de lado (un Weld: su C0 la gira); por fuera el ojo de cristal oscuro en su aro.
local function hacerMirilla(el: Elemento)
	local hoja = el.hoja :: BasePart
	local s, g, y = el.signo, el.grosor, el.y0
	local function pegar(p: BasePart)
		local union = Instance.new("WeldConstraint")
		union.Part0, union.Part1 = hoja, p
		union.Parent = p
		table.insert(el.piezas, p)
	end
	pegar(pieza("MirillaAro", Vector3.new(0.04, 0.24, 0.24), hoja.CFrame * CFrame.new(0, y, s * (g + 0.02)) * EJE_Z, LATON,
		Enum.Material.Metal, hoja))
	local pivote = Vector3.new(0, y + TAPA_COLGADA, s * (g + 0.055))
	local colgada = CFrame.new(0, -TAPA_COLGADA, 0) * EJE_Z
	local tapa = pieza("MirillaTapa", Vector3.new(0.025, 0.17, 0.17), hoja.CFrame * CFrame.new(pivote) * colgada,
		LATON:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Metal, hoja)
	local junta = Instance.new("Weld")
	junta.Part0, junta.Part1 = hoja, tapa
	junta.C0 = CFrame.new(pivote)
	junta.C1 = colgada:Inverse()
	junta.Parent = tapa
	table.insert(el.piezas, tapa)
	local giro = Instance.new("NumberValue")
	giro.Name = "MirillaGiro"
	giro.Changed:Connect(function(a: number)
		junta.C0 = CFrame.new(pivote) * CFrame.Angles(0, 0, math.rad(a)) -- alrededor del eje de la puerta
	end)
	giro.Parent = tapa
	el.tapa = giro
	pegar(pieza("MirillaFuera", Vector3.new(0.03, 0.2, 0.2), hoja.CFrame * CFrame.new(0, y, -s * (g + 0.015)) * EJE_Z, LATON,
		Enum.Material.Metal, hoja))
	local lente = pieza("MirillaLente", Vector3.new(0.035, 0.1, 0.1), hoja.CFrame * CFrame.new(0, y, -s * (g + 0.02)) * EJE_Z,
		Color3.fromRGB(24, 26, 30), Enum.Material.SmoothPlastic, hoja)
	lente.Reflectance = 0.15
	pegar(lente)
end

-- ===== Entre las cortinas =====

local function ladoVentana(el: Elemento): number
	return math.min(VENTANA_LADO, math.max(0.2, el.ancho / 2 - 0.45))
end

-- La cabeza delante de la ranura entre los dos paños.
local function ranura(v: Vistazo): CFrame
	return v.el.centro * CFrame.new(0, v.altura, VENTANA_DELANTE)
end

-- Tras las cortinas, casi en el cristal y a un lado del montante, mirando fuera.
local function vistaVentana(v: Vistazo): CFrame
	return v.el.centro * CFrame.new(v.lado * ladoVentana(v.el), v.altura, VENTANA_CERCA)
		* CFrame.Angles(math.rad(VENTANA_INCLINA), 0, 0)
end

-- El borde del paño de tu derecha, a la altura del pecho; `tira` de 0 a 1 lo coge y tira un poco.
local function puntoCortina(v: Vistazo, tira: number): Vector3
	return v.el.centro * Vector3.new(0.07 + 0.06 * tira, v.altura - 0.3, 0.98 + 0.05 * tira)
end

-- ===== Lo que se ve encima (círculo, bandas, negro) =====

local function radioMirilla(): number
	local tam = camara.ViewportSize
	return MIRILLA_RADIO * math.min(tam.X, tam.Y)
end

-- Con este radio lo negro queda fuera de la pantalla.
local function radioGrande(): number
	return camara.ViewportSize.Magnitude * 0.62
end

local function radio(v: Vistazo, r: number)
	local iris, borde = v.iris, v.irisBorde
	if not iris or not borde then
		return
	end
	r = math.max(1, r)
	v.radioAhora = r
	iris.Size = UDim2.fromOffset(r * 2, r * 2)
	borde.Thickness = r * 0.5 + 2 -- llena las esquinas entre el círculo y su cuadrado (fuera, las planchas)
	for _, a in v.anillos do
		a.borde.Thickness = math.max(1, r * a.grosor)
	end
end

local function oscuro(v: Vistazo, a: number)
	if v.negro then
		v.negro.BackgroundTransparency = 1 - math.clamp(a, 0, 1)
	end
end

-- 0 = abiertas (fuera de la pantalla), RENDIJA = mirando, 1 = cerradas del todo.
local function bandas(v: Vistazo, c: number)
	v.cierre = c
	local x = lerp(-0.02, 0.78, math.clamp(c, 0, 1.05)) -- el borde de dentro de la banda izquierda
	local izq, der = v.bandas[1], v.bandas[2]
	if izq and der then
		izq.Position = UDim2.fromScale(x, 0)
		der.Position = UDim2.fromScale(1 - x, 0)
	end
	for _, f in v.vineta do
		f.BackgroundTransparency = 1 - math.clamp(c / RENDIJA, 0, 1)
	end
end

local function redondo(gui: GuiObject)
	local esquina = Instance.new("UICorner")
	esquina.CornerRadius = UDim.new(0.5, 0)
	esquina.Parent = gui
end

-- El círculo de la mirilla: un marco redondo sin fondo con un borde negro muy gordo, planchas negras alrededor, el
-- borde de la lente difuminado y un reflejo flojo en el cristal.
local function crearIris(v: Vistazo, gui: ScreenGui)
	local iris = Instance.new("Frame")
	iris.Name = "Iris"
	iris.AnchorPoint = Vector2.new(0.5, 0.5)
	iris.Position = UDim2.fromScale(0.5, 0.5)
	iris.BackgroundTransparency = 1
	iris.ZIndex = 2
	redondo(iris)
	local borde = Instance.new("UIStroke")
	borde.Color = Color3.new(0, 0, 0)
	borde.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	borde.Parent = iris
	v.irisBorde = borde
	for _, p in PLANCHAS do
		local f = Instance.new("Frame")
		f.AnchorPoint = p[1]
		f.Position = p[2]
		f.Size = p[3]
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BorderSizePixel = 0
		f.ZIndex = 2
		f.Parent = iris
	end
	for _, a in ANILLOS do
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.Size = UDim2.fromScale(a.desde, a.desde)
		f.BackgroundTransparency = 1
		f.ZIndex = 2
		redondo(f)
		local s = Instance.new("UIStroke")
		s.Color = a.color
		s.Transparency = a.transparencia
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = f
		f.Parent = iris
		table.insert(v.anillos, { borde = s, grosor = a.grosor })
	end
	local reflejo = Instance.new("Frame")
	reflejo.Name = "Reflejo"
	reflejo.AnchorPoint = Vector2.new(0.5, 0.5)
	reflejo.Position = UDim2.fromScale(0.33, 0.27)
	reflejo.Size = UDim2.fromScale(0.34, 0.1)
	reflejo.Rotation = -38
	reflejo.BackgroundColor3 = Color3.new(1, 1, 1)
	reflejo.BackgroundTransparency = 0.93
	reflejo.BorderSizePixel = 0
	reflejo.ZIndex = 2
	redondo(reflejo)
	local brillo = Instance.new("UIGradient")
	brillo.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.3), NumberSequenceKeypoint.new(1, 1),
	})
	brillo.Parent = reflejo
	reflejo.Parent = iris
	iris.Parent = gui
	v.iris = iris
	radio(v, radioGrande())
end

-- Las dos bandas de tela (la cortina pegada a la cara, desenfocada, con un par de pliegues) y la viñeta de arriba y
-- abajo.
local function crearBandas(v: Vistazo, gui: ScreenGui)
	for _, lado in { -1, 1 } do
		local b = Instance.new("Frame")
		b.Name = if lado < 0 then "Izquierda" else "Derecha"
		b.AnchorPoint = Vector2.new(if lado < 0 then 1 else 0, 0)
		b.Size = UDim2.fromScale(1, 1)
		b.BackgroundColor3 = TELA
		b.BorderSizePixel = 0
		b.ZIndex = 2
		local degradado = Instance.new("UIGradient")
		degradado.Rotation = if lado < 0 then 0 else 180 -- opaca por fuera; se deshace hacia la ranura
		degradado.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.62, 0.03),
			NumberSequenceKeypoint.new(0.86, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		})
		degradado.Parent = b
		for i, x in { 0.28, 0.46 } do -- en la parte opaca: un pliegue claro y uno oscuro
			local pliegue = Instance.new("Frame")
			pliegue.AnchorPoint = Vector2.new(0.5, 0)
			pliegue.Position = UDim2.fromScale(if lado < 0 then x else 1 - x, 0)
			pliegue.Size = UDim2.fromScale(0.08 + 0.03 * i, 1)
			pliegue.BackgroundColor3 = if i == 1 then Color3.fromRGB(64, 28, 25) else Color3.new(0, 0, 0)
			pliegue.BackgroundTransparency = 0.5
			pliegue.BorderSizePixel = 0
			pliegue.ZIndex = 3
			local suaveBorde = Instance.new("UIGradient")
			suaveBorde.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1),
			})
			suaveBorde.Parent = pliegue
			pliegue.Parent = b
		end
		b.Parent = gui
		table.insert(v.bandas, b)
	end
	for _, arriba in { true, false } do
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0, if arriba then 0 else 1)
		f.Position = UDim2.fromScale(0, if arriba then 0 else 1)
		f.Size = UDim2.fromScale(1, 0.34)
		f.BackgroundColor3 = Color3.new(0, 0, 0)
		f.BackgroundTransparency = 1
		f.BorderSizePixel = 0
		f.ZIndex = 1
		local degradado = Instance.new("UIGradient")
		degradado.Rotation = if arriba then 90 else 270
		degradado.Transparency = NumberSequence.new(0.2, 1)
		degradado.Parent = f
		f.Parent = gui
		table.insert(v.vineta, f)
	end
	bandas(v, 0)
end

local function crearCapa(v: Vistazo)
	local gui = Instance.new("ScreenGui")
	gui.Name = "Mirar"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 6 -- encima del HUD y del blanco del flash; debajo del negro de las cinemáticas
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	v.gui = gui
	local negro = Instance.new("Frame")
	negro.Name = "Negro"
	negro.Size = UDim2.fromScale(1, 1)
	negro.BackgroundColor3 = Color3.new(0, 0, 0)
	negro.BackgroundTransparency = 1
	negro.BorderSizePixel = 0
	negro.ZIndex = 10
	negro.Parent = gui
	v.negro = negro
	if v.el.tipo == "Mirilla" then
		crearIris(v, gui)
	else
		crearBandas(v, gui)
	end
	gui.Parent = jugador:FindFirstChildOfClass("PlayerGui") -- sin esperar: esto va dentro del paso de la cámara
end

-- ===== Efectos de la vista =====

-- La lente de la mirilla: fría, algo apagada y (sin Rendimiento) un poco borrosa.
local function lente(v: Vistazo)
	local color = Instance.new("ColorCorrectionEffect")
	color.Name = "MirarFrio"
	color.TintColor = MIRILLA_TINTE
	color.Saturation = -0.35
	color.Contrast = 0.14
	color.Brightness = 0.05 -- el ojo se acostumbra a lo oscuro
	color.Parent = camara
	table.insert(v.efectos, color)
	if not poco() then
		local borroso = Instance.new("BlurEffect")
		borroso.Name = "MirarBorroso"
		borroso.Size = MIRILLA_BLUR
		borroso.Parent = camara
		table.insert(v.efectos, borroso)
	end
end

local function luzFuera(v: Vistazo, donde: Vector3)
	if workspace:GetAttribute("Fase") == "Dia" then
		return
	end
	local punto = Instance.new("Attachment")
	punto.Name = "MirarLuz"
	punto.WorldPosition = donde
	local luz = Instance.new("PointLight")
	luz.Brightness = LUZ_BRILLO
	luz.Range = LUZ_ALCANCE
	luz.Color = LUZ_COLOR
	luz.Shadows = false
	luz.Parent = punto
	punto.Parent = workspace.Terrain
	table.insert(v.efectos, punto)
end

-- De noche, tu aliento empaña el cristal delante de la boca (sin Rendimiento).
local function vaho(v: Vistazo)
	if poco() or workspace:GetAttribute("Fase") == "Dia" then
		return
	end
	local p = Instance.new("Part")
	p.Name = "MirarVaho"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.02, 0.55, 0.55)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = Color3.fromRGB(196, 200, 204)
	p.Transparency = 1
	-- A 0,04 del cristal: si vibra (CasaVista) no se cruzan. A la altura de la boca: empaña la parte de abajo de la vista.
	p.CFrame = v.el.centro * CFrame.new(v.lado * ladoVentana(v.el), v.altura - 0.3, 0.14) * EJE_Z
	p.Parent = workspace.Terrain
	v.vaho = p
	table.insert(v.efectos, p)
end

local function quitarEfectos(v: Vistazo)
	for _, e in v.efectos do
		if e:IsA("BasePart") then -- el vaho se va despacio del cristal
			TweenService:Create(e, TweenInfo.new(1.2), { Transparency = 1 }):Play()
			task.delay(1.3, e.Destroy, e)
		else
			e:Destroy()
		end
	end
	table.clear(v.efectos)
	v.vaho = nil
	v.aliento = nil
end

-- ===== HUD =====

local function esconderHud(v: Vistazo)
	local hud = Ui.hud()
	if hud.Enabled then
		hud.Enabled = false
		v.hud = hud
	end
	-- Los carteles 3D (prompts) también: siempre se pintan encima y se verían flotando por la mirilla o el cristal.
	if ProximityPromptService.Enabled then
		ProximityPromptService.Enabled = false
		v.carteles = true
	end
end

-- Los carteles, como los deja Controles: apagados con las manos ocupadas o la mochila abierta.
local function devolverCarteles(v: Vistazo)
	if not v.carteles then
		return
	end
	v.carteles = false
	ProximityPromptService.Enabled = not (jugador:GetAttribute("Cargando") or jugador:GetAttribute("MochilaAbierta")
		or jugador:GetAttribute("Trabajando"))
end

-- `esperar`: una cinemática se ha quedado con la cámara; el HUD vuelve cuando acabe (si no, saldría en medio).
local function devolverHud(v: Vistazo, esperar: boolean)
	local hud = v.hud
	v.hud = nil
	if not hud then
		return
	end
	if not esperar then
		hud.Enabled = true
		return
	end
	task.spawn(function()
		local hasta = os.clock() + 180
		repeat
			task.wait(0.25)
		until camara.CameraType == Enum.CameraType.Custom or os.clock() > hasta
		hud.Enabled = true
	end)
end

-- ===== La mano =====

-- La mano derecha en la tapita (o en el borde de la cortina); `aparta` de 0 a 1.
local function agarre(v: Vistazo, aparta: number, despega: number): CFrame
	if v.el.tipo == "Mirilla" then
		return manoTapa(v.el, aparta, despega)
	end
	return Manos.hacia("der", puntoCortina(v, aparta), "agarra")
end

-- Adónde tiene que llegar la palma (para la cortina, el punto de verdad: Manos.hacia lo acorta a lo que llega el brazo).
local function sitioMano(v: Vistazo): Vector3
	return if v.el.tipo == "Mirilla" then manoTapa(v.el, 0, 0).Position else puntoCortina(v, 0)
end

-- Esa mano abajo, fuera de la vista (más o menos donde la deja Manos sin capa), en el mundo.
local function abajo(lado: string): CFrame
	return camara.CFrame * CFrame.new(if lado == "der" then 0.8 else -0.8, -2.4, -0.5) * CFrame.Angles(math.rad(-80), 0, 0)
end

-- Al pulsar: la derecha va a la tapita (o a la cortina) y, al llegar, la aparta; la izquierda baja (con la linterna, si
-- la llevas: se apaga al quedarse la cámara en Scriptable, EquipoVista). `siempre`: se ven aunque la cámara ya sea
-- Scriptable; al pasar al otro lado (todo negro o tapado por la tela) bajan sin que se vea. `velDer` / `velIzq`: cada
-- mano a su ritmo (si Manos no los conoce, las dos con `velocidad`).
local function gestoEntrar(v: Vistazo)
	Manos.gesto("Mirar", 3, function(_, s)
		if activo ~= v or v.alOtroLado or v.fase ~= "entrar" then
			return nil
		end
		local desde = v.agarre
		local velocidad = if desde then 26 else 18
		return {
			der = agarre(v, if desde then suave((s - desde) / 0.16) else 0, 0),
			izq = abajo("izq"),
			cosaIzq = if jugador:GetAttribute("Linterna") == true then "Linterna" else nil,
			velocidad = velocidad,
			velDer = velocidad,
			velIzq = 7,
			siempre = true,
		}
	end, PRIORIDAD)
end

-- Al volver: la mano aguanta un momento la tapita (o la cortina) y baja mientras la cámara vuelve a los ojos (con
-- `siempre`: en Scriptable, si no, desaparecería de golpe); de vuelta, acaba de bajar sola con su muelle.
local function gestoSoltar(v: Vistazo)
	Manos.gesto("Mirar", 1.5, function(_, s)
		if activo ~= v then
			return nil
		end
		local pose = agarre(v, 1, math.min(s, MANO_SOLTAR) * 0.6)
		return { der = pose:Lerp(abajo("der"), suave((s - MANO_SOLTAR) / 0.3)), velocidad = 30, siempre = true }
	end, PRIORIDAD)
	if v.el.tipo == "Mirilla" then
		task.delay(MANO_SOLTAR - 0.02, moverTapa, v.el, false)
	end
end

-- ===== Bichos =====

-- El Imitador mientras finge ser una persona en la puerta (como en MuerteVista y AmbienteMiedo).
local function fingiendo(bicho: Instance): boolean
	return bicho.Name == "Imitador" and not bicho:GetAttribute("Abierto")
end

-- A qué distancia está el bicho más cercano, si alguno se ve (cerca, por donde miras y sin nada en medio) y si el
-- Imitador que finge se ha pegado a la mirilla. El que finge no cuenta para lo demás: lo delataría.
local function bichos(v: Vistazo): (number, boolean, boolean)
	local carpeta = workspace:FindFirstChild("Bichos")
	if not carpeta then
		return math.huge, false, false
	end
	local cf = camara.CFrame
	local mirilla = v.el.tipo == "Mirilla"
	local cono = if mirilla then 0.62 else 0.8
	local cerca, visto, pegado = math.huge, false, false
	local filtro: { Instance } = { v.el.modelo } -- la puerta (o el cristal) y tú no tapan
	if jugador.Character then
		table.insert(filtro, jugador.Character)
	end
	rayoVista.FilterDescendantsInstances = filtro
	for _, bicho in carpeta:GetChildren() do
		local raiz = bicho:FindFirstChild("HumanoidRootPart")
		if not (raiz and raiz:IsA("BasePart")) then
			continue
		end
		local cabeza = bicho:FindFirstChild("Cabeza")
		local punto = if cabeza and cabeza:IsA("BasePart") then cabeza.Position else raiz.Position
		local d = punto - cf.Position
		local m = d.Magnitude
		if fingiendo(bicho) then
			pegado = pegado or (mirilla and m < PEGADO)
			continue
		end
		cerca = math.min(cerca, m)
		if not visto and m > 0.1 and m < SUSTO_CERCA and d.Unit:Dot(cf.LookVector) > cono then
			local choque = workspace:Raycast(cf.Position, d, rayoVista)
			visto = choque == nil or choque.Instance:IsDescendantOf(bicho)
		end
	end
	return cerca, visto, pegado
end

-- Tu respiración se va apagando (al volver, o al acabar de golpe).
local function soltarAliento(v: Vistazo)
	local s = v.aliento
	v.aliento = nil
	if not s then
		return
	end
	local i = table.find(v.efectos, s)
	if i then
		table.remove(v.efectos, i)
	end
	TweenService:Create(s, TweenInfo.new(0.4), { Volume = 0 }):Play()
	task.delay(0.45, s.Destroy, s)
end

-- ===== La cámara, fotograma a fotograma =====

local function poner(v: Vistazo, cf: CFrame)
	camara.CFrame = cf
	camara.Focus = cf * CFrame.new(0, 0, -4)
	v.ultimo = cf
end

local function campo(v: Vistazo, valor: number)
	camara.FieldOfView = valor
	v.fovPuesto = camara.FieldOfView
end

local function girar(v: Vistazo, dx: number, dy: number)
	v.objYaw = math.clamp(v.objYaw - dx, -GIRO_LADO, GIRO_LADO)
	v.objPitch = math.clamp(v.objPitch - dy, -GIRO_ABAJO, GIRO_ARRIBA)
end

local function giroDe(v: Vistazo): CFrame
	return CFrame.Angles(0, v.yaw, 0) * CFrame.Angles(v.pitch, 0, 0)
end

-- Ya se ve fuera: la mirilla, al otro lado de la puerta (todo negro mientras salta); la ventana, tras las cortinas.
local function alOtroLado(v: Vistazo)
	local el = v.el
	v.alOtroLado = true
	v.fase = "mirar"
	v.t0 = os.clock()
	if el.tipo == "Mirilla" then
		campo(v, MIRILLA_FOV)
		lente(v)
		poner(v, vistaMirilla(el))
		radio(v, radioMirilla() * 0.15)
		jugador:SetAttribute("Mirilla", true)
		local hoja = (el.hoja :: BasePart).CFrame
		luzFuera(v, hoja * Vector3.new(0, el.y0 + 2.6, -el.signo * (el.grosor + 1.6)))
	else
		campo(v, VENTANA_FOV)
		vaho(v)
		luzFuera(v, el.centro * Vector3.new(0, 2, -2.2))
	end
	-- Tu respiración, pegado a la puerta o al cristal (cuando haya grabación: Respiracion falta, Id 0).
	if Sonido.hay("Respiracion") then
		local aliento = Sonido.bucle("Respiracion")
		v.alientoBase = aliento.Volume * RESPIRA
		aliento.Volume = 0
		v.aliento = aliento
		table.insert(v.efectos, aliento)
	end
	local ok, s = pcall(function()
		return UserSettings():GetService("UserGameSettings").MouseSensitivity
	end)
	v.sensibilidad = if ok and type(s) == "number" then s else 1
	ContextActionService:BindActionAtPriority(SALIR, function(_, estado)
		if estado == Enum.UserInputState.Begin then
			pedirSalir(v, "normal")
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, TECLA, MANDO, Enum.KeyCode.ButtonB, Enum.UserInputType.MouseButton1)
end

local function entrar(v: Vistazo, t: number)
	local el = v.el
	local mirilla = el.tipo == "Mirilla"
	-- La mano aparta la tapita (o coge la cortina) al llegar a ella: de cerca enseguida; de lejos, cuando la cabeza ya
	-- se ha acercado (el brazo no llega antes). Si no llega, a MANO_TARDE del acercamiento.
	if not v.agarre then
		local palma = Manos.mano("der")
		local llega = palma ~= nil and (palma.Position - sitioMano(v)).Magnitude < MANO_CERCA
		if llega or t >= T.camara + v.acercar * MANO_TARDE then
			v.agarre = t
			if mirilla then
				moverTapa(el, true)
				Sonido.en("Mirilla", puntoTapa(el))
			end
		end
	end
	if t < T.camara then
		return -- la mano va a la tapita (o a la cortina); la cámara aún es tuya
	end
	if not v.camara then
		if camara.CameraType ~= Enum.CameraType.Custom then
			limpiar(v, "nada") -- otra cosa se ha quedado con la cámara mientras tanto
			return
		end
		v.camara = true
		v.desde = camara.CFrame
		-- La cabeza parte de la cámara de verdad (agachado, con el vaivén de CuerpoVista…). Lo que esté apartada de
		-- ojos() (avatares sin escala automática, el vaivén) se suma al volver, para acabar donde la recoge la de Roblox.
		local hum, raiz = cuerpo()
		if hum and raiz then
			local ajuste = v.desde.Position - ojos(hum, raiz, v.desde.LookVector).Position
			v.ajuste = if ajuste.Magnitude < 1 then ajuste else Vector3.zero
		end
		-- Cuanto más lejos, más tarda la cabeza en llegar (de lejos era un salto).
		local hasta = if mirilla then pegadoMirilla(el) else ranura(v)
		v.acercar = math.min(ACERCAR_MAX, T.acercar + (hasta.Position - v.desde.Position).Magnitude * ACERCAR_STUD)
		camara.CameraType = Enum.CameraType.Scriptable
		esconderHud(v)
		crearCapa(v)
	end
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	local k = math.clamp((t - T.camara) / v.acercar, 0, 1)
	if mirilla then
		-- La cabeza a la puerta; se va cerrando la vista y al final, negro.
		poner(v, v.desde:Lerp(pegadoMirilla(el), suave(k)))
		radio(v, lerp(radioGrande(), radioMirilla() * 0.7, suave(k)))
		oscuro(v, (k - 0.72) / 0.28)
		if k >= 1 then
			alOtroLado(v)
		end
		return
	end
	if k < 1 then
		poner(v, v.desde:Lerp(ranura(v), suave(k)))
		campo(v, lerp(v.fovAntes, VENTANA_FOV, suave(k) * 0.5))
		bandas(v, suave((k - 0.55) / 0.45)) -- la tela se acerca a la cara
		return
	end
	-- Con la tela tapándolo todo, por la ranura hasta el cristal.
	if not v.pasando then
		v.pasando = true
		local roce = Sonido.en("Cortina", el.centro.Position, 1.3)
		roce.Volume *= 0.35
	end
	local k2 = math.clamp((t - T.camara - v.acercar) / T.pasar, 0, 1)
	bandas(v, 1)
	poner(v, ranura(v):Lerp(vistaVentana(v), suave(k2)))
	campo(v, lerp(v.fovAntes, VENTANA_FOV, 0.5 + 0.5 * suave(k2)))
	if k2 >= 1 then
		alOtroLado(v)
	end
end

local function mirar(v: Vistazo, t: number, dt: number)
	local el = v.el
	local ahora = os.clock()
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	if v.palanca.Magnitude > 0.15 then
		girar(v, v.palanca.X * PALANCA * dt, -v.palanca.Y * PALANCA * dt)
	end
	local k = 1 - math.exp(-dt * 12)
	v.yaw += (v.objYaw - v.yaw) * k
	v.pitch += (v.objPitch - v.pitch) * k
	-- Bichos, unas veces por segundo: cerca, la respiración se acelera; a la vista, el susto y contienes el aire.
	if ahora >= v.proximaMirada then
		v.proximaMirada = ahora + 0.15
		local cerca, visto, pegado = bichos(v)
		v.tension = if v.pegado or pegado then 1 else math.clamp(1 - cerca / 30, 0, 1)
		if pegado and not v.pegado then
			-- El Imitador se pega a la mirilla: su golpe de tensión lo pone ImitadorVista; aquí, el respingo.
			v.pegado = true
			v.respingo = ahora
		elseif visto and not v.vio then
			v.respingo = ahora
			if ahora >= proximoSusto then
				proximoSusto = ahora + SUSTO_CADA
				Sonido.tocar("Sobresalto")
			end
		end
		if (pegado or visto) and not v.vio then
			v.vio = true
			v.contiene = ahora
			Sonido.tocar("Contener")
		end
	end
	-- Conteniendo el aire: calla la respiración, el vaho se va y la vista deja de mecerse y tiembla un poco.
	local aguanta = math.clamp((ahora - v.contiene) / 1.2, 0, 1)
	local aliento = v.aliento
	if aliento then
		local meta = if v.vio then 0 else v.alientoBase * (0.8 + 0.4 * v.tension)
		aliento.Volume += (meta - aliento.Volume) * math.min(1, dt * (if v.vio then 12 else 3))
		aliento.PlaybackSpeed = 1 + 0.15 * v.tension
	end
	v.respira += dt * math.pi * 2 / lerp(3.4, 1.5, v.tension)
	local quieto = poco()
	local mece = 1 - 0.8 * aguanta
	local tiembla = 0.004 * aguanta
	local meneo = if quieto then CFrame.new()
		else CFrame.Angles(math.sin(v.respira) * (0.008 + 0.006 * v.tension) * mece + math.noise(ahora * 9, 1.3) * tiembla,
			math.sin(v.respira * 0.5 + 1) * 0.005 * mece + math.noise(ahora * 9, 4.1) * tiembla, 0)
	local susto = math.clamp(1 - (ahora - v.respingo) / 0.5, 0, 1) ^ 2
	local giro = giroDe(v) * CFrame.Angles(susto * 0.05, 0, 0) * meneo
	if el.tipo == "Mirilla" then
		poner(v, vistaMirilla(el) * giro)
		-- El ojo se hace a la lente (el círculo se abre); con el respingo se aparta un poco y el círculo se encoge.
		radio(v, radioMirilla() * lerp(0.15, 1, suave(t / T.abrir)) * (1 - 0.3 * susto))
		oscuro(v, 1 - t / 0.15)
	else
		local sube = if quieto then 0 else math.sin(v.respira) * 0.015 * mece
		poner(v, vistaVentana(v) * CFrame.new(0, sube, susto * 0.12) * giro) -- con el respingo, se aparta del cristal
		local abre = lerp(1, RENDIJA, suave(t / T.abrir))
		bandas(v, abre + (if quieto then 0 else math.sin(v.respira * 0.5) * 0.008 * mece) + susto * 0.06)
		local p = v.vaho
		if p then
			p.Transparency = 1 - VAHO * (0.55 + 0.45 * math.sin(v.respira - 1)) * suave(t / 1.5) * (1 - aguanta)
		end
	end
	-- En Studio, el atributo MirarQuieto del Workspace no deja que se acabe (para mirarlo con calma).
	local quieta = RunService:IsStudio() and workspace:GetAttribute("MirarQuieto")
	if t >= MIRAR and not quieta then
		pedirSalir(v, "normal")
	end
end

-- Vuelve a este lado de la puerta (o de la cortina), con todo negro (o la tela tapándolo todo).
local function volverAca(v: Vistazo)
	local el = v.el
	v.vuelto = true
	v.t0 = os.clock()
	soltarAliento(v)
	quitarEfectos(v)
	jugador:SetAttribute("Mirilla", nil)
	if el.tipo == "Mirilla" then
		campo(v, v.fovAntes)
		v.desde = pegadoMirilla(el)
		radio(v, radioMirilla() * 0.7)
		v.radioDesde = v.radioAhora
	else
		v.desde = ranura(v)
		v.cierreDesde = v.cierre
		local roce = Sonido.en("Cortina", el.centro.Position, 1.3)
		roce.Volume *= 0.35
	end
	poner(v, v.desde)
	gestoSoltar(v)
end

local function salir(v: Vistazo, t: number)
	local el = v.el
	local mirilla = el.tipo == "Mirilla"
	local golpe = v.motivo == "golpe"
	local prisa = if golpe then T.golpe else 1
	if v.alOtroLado and not v.vuelto then
		-- Se cierra mirando aún; de golpe, la vista tiembla (y en la ventana, la cabeza se echa atrás).
		local k = math.clamp(t / (T.cerrar * prisa), 0, 1)
		local f = if golpe then (1 - k) * 0.06 else 0
		local giro = giroDe(v) * CFrame.Angles(azar:NextNumber(-f, f), azar:NextNumber(-f, f), azar:NextNumber(-f, f) * 0.5)
		if mirilla then
			poner(v, vistaMirilla(el) * giro)
			oscuro(v, k)
		else
			poner(v, vistaVentana(v) * CFrame.new(0, 0, if golpe then 0.2 * suave(k) else 0) * giro)
			bandas(v, lerp(v.cierreDesde, 1, suave(k)))
		end
		if k >= 1 then
			volverAca(v)
		end
		return
	end
	local hum, raiz = cuerpo()
	if not hum or not raiz then
		limpiar(v, "fuera")
		return
	end
	local k = math.clamp(t / (T.volver * prisa), 0, 1)
	poner(v, v.desde:Lerp(ojos(hum, raiz, v.mirada) + v.ajuste, suave(k)))
	if mirilla then
		oscuro(v, 1 - k / 0.35)
		radio(v, lerp(v.radioDesde, radioGrande(), suave(k)))
	else
		bandas(v, lerp(v.cierreDesde, 0, suave(k)))
		campo(v, lerp(v.fovDesde, v.fovAntes, suave(k)))
	end
	if k >= 1 then
		limpiar(v, v.motivo)
	end
end

local function pasoVistazo(v: Vistazo, dt: number)
	if elementos[v.el.modelo] ~= v.el or not v.el.punto:IsDescendantOf(workspace) then
		limpiar(v, "error") -- la puerta o la ventana (o su hoja, o su mando) ya no está
		return
	end
	local hum, raiz = cuerpo()
	if not hum or not raiz then
		limpiar(v, "fuera")
		return
	end
	-- Te han llevado a otro sitio (el servidor te mueve): se devuelve todo de golpe.
	if not v.prueba and (raiz.Position - v.el.punto.WorldPosition).Magnitude > CERCA then
		limpiar(v, "error")
		return
	end
	-- Si la cámara cambia de tipo o salta sola, la lleva otro (una cinemática): se deja sin tocarla. Los temblores de
	-- otros módulos (CasaVista, BestiaVista, la reja, Sustos, la mochila) solo la giran, y casi todos ni la tocan en
	-- Scriptable: no la mueven. Si al final nadie la lleva, vigilarAbandonada la devuelve.
	local ultimo = v.ultimo
	if v.camara and (camara.CameraType ~= Enum.CameraType.Scriptable
		or (ultimo and (camara.CFrame.Position - ultimo.Position).Magnitude > 0.5)) then
		if RunService:IsStudio() then -- (ojo: execute_luau de Studio devuelve la cámara a Custom si un script la cambia)
			print("[MirarVista] otro coge la cámara:", camara.CameraType.Name,
				if ultimo then (camara.CFrame.Position - ultimo.Position).Magnitude else -1)
		end
		limpiar(v, "cine")
		return
	end
	if v.fase ~= "salir" and (hum.MoveDirection.Magnitude > 0.1 or saltando(hum)) then
		pedirSalir(v, "normal")
		if activo ~= v then
			return
		end
	end
	local t = os.clock() - v.t0
	if v.fase == "entrar" then
		entrar(v, t)
	elseif v.fase == "mirar" then
		mirar(v, t, dt)
	else
		salir(v, t)
	end
end

local function paso(dt: number)
	local v = activo
	if not v then
		RunService:UnbindFromRenderStep(PASO)
		return
	end
	local ok, fallo = pcall(pasoVistazo, v, dt)
	if not ok then
		warn("[MirarVista] " .. tostring(fallo))
		limpiar(v, "error")
	end
end

-- ===== Empezar, salir y devolverlo todo =====

pedirSalir = function(v: Vistazo, motivo: string)
	if activo ~= v or v.fase == "salir" then
		return
	end
	if not v.camara then
		limpiar(v, "nada") -- la cámara aún no se había movido
		return
	end
	v.fase = "salir"
	v.t0 = os.clock()
	v.motivo = motivo
	v.desde = camara.CFrame
	v.mirada = camara.CFrame.LookVector
	-- Cada cosa vuelve desde donde estaba (si sales a medio acercarte, sin saltos).
	v.fovDesde = camara.FieldOfView
	v.radioDesde = v.radioAhora
	v.cierreDesde = v.cierre
	ContextActionService:UnbindAction(SALIR)
	if not v.alOtroLado then
		gestoSoltar(v) -- a medio acercarte: la mano suelta la tapita (o la cortina) y baja
	end
end

-- La cámara vuelve a la de Roblox, con el campo de visión de antes (si nadie ha puesto otro).
local function aCustom(v: Vistazo)
	camara.CameraType = Enum.CameraType.Custom
	if v.fovPuesto and math.abs(camara.FieldOfView - v.fovPuesto) < 0.01 then
		camara.FieldOfView = v.fovAntes
	end
end

-- Tras "cine": si la cámara sigue en Scriptable y nadie la mueve en ABANDONADA s seguidos, no era de ninguna cinemática:
-- vuelve la de Roblox, y con ella el HUD (devolverHud espera a Custom). Las cinemáticas la mueven (o su plano quieto
-- dura menos) y al acabar la ponen en Custom ellas mismas.
local function vigilarAbandonada(v: Vistazo)
	task.spawn(function()
		local antes, quieta = camara.CFrame, os.clock()
		local hasta = os.clock() + 180
		while os.clock() < hasta do
			task.wait(0.25)
			if activo ~= nil or camara.CameraType ~= Enum.CameraType.Scriptable then
				return -- otra vez mirando, o ya la lleva la de Roblox
			end
			local ahora = camara.CFrame
			if ahora ~= antes then
				antes, quieta = ahora, os.clock()
			elseif os.clock() - quieta >= ABANDONADA then
				aCustom(v)
				return
			end
		end
	end)
end

-- `como`: "normal" o "golpe" (acabado), "nada" (sin mover la cámara), "error" (se devuelve todo), "fuera" (te pillan,
-- mueres o te escondes: la cámara ya la lleva MuerteVista) o "cine" (la lleva una cinemática).
limpiar = function(v: Vistazo, como: string)
	if activo ~= v then
		return
	end
	activo = nil
	descanso = os.clock() + DESCANSO
	pcall(RunService.UnbindFromRenderStep, RunService, PASO)
	pcall(ContextActionService.UnbindAction, ContextActionService, SALIR)
	for _, c in v.conexiones do
		c:Disconnect()
	end
	table.clear(v.conexiones)
	local deOtro = como == "fuera" or como == "cine"
	pcall(soltarAliento, v)
	pcall(quitarEfectos, v)
	pcall(devolverCarteles, v)
	if v.gui then
		v.gui:Destroy()
		v.gui = nil
	end
	if v.camara then
		pcall(function()
			if not deOtro and camara.CameraType == Enum.CameraType.Scriptable then
				camara.CameraType = Enum.CameraType.Custom
			end
			-- El campo de visión de antes, salvo que otro haya puesto el suyo (el susto pone 60).
			if v.fovPuesto and math.abs(camara.FieldOfView - v.fovPuesto) < 0.01 then
				camara.FieldOfView = v.fovAntes
			end
			-- El ratón suelto (la cámara de Roblox lo vuelve a fijar en primera persona; escondido hace falta para SALIR).
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end)
	end
	jugador:SetAttribute("Mirilla", nil)
	jugador:SetAttribute("Vistazo", nil)
	pcall(devolverHud, v, como == "cine")
	pcall(moverTapa, v.el, false)
	if v.vio and not deOtro then
		Sonido.tocar("Exhalar") -- sueltas el aire (si te pillan o empieza una cinemática, no)
	end
	if como == "golpe" then
		pcall(ManosGestos.sobresalto, 0.9) -- las manos suben de golpe
	end
	-- Muerto sin el susto (sin remote): que la cámara no se quede aquí si nadie la recoge. (Aquí no vale lo de
	-- "cine": escondido con Rendimiento la vista puede quedarse quieta, y MuerteVista volvería a meterte.)
	local ultimo = v.ultimo
	if como == "fuera" and v.camara and ultimo then
		task.delay(2.5, function()
			if activo == nil and camara.CameraType == Enum.CameraType.Scriptable
				and (camara.CFrame.Position - ultimo.Position).Magnitude < 0.05 then
				aCustom(v)
			end
		end)
	elseif como == "cine" and v.camara then
		vigilarAbandonada(v)
	end
end

-- Lo que corta el vistazo mientras dura.
local function vigilar(v: Vistazo)
	local c = v.conexiones
	local el = v.el
	local function cortar(motivo: string): () -> ()
		return function()
			pedirSalir(v, motivo)
		end
	end
	for _, atributo in CORTAN do
		table.insert(c, jugador:GetAttributeChangedSignal(atributo):Connect(cortar("normal")))
	end
	for _, atributo in { "Muerto", "Escondido" } do
		table.insert(c, jugador:GetAttributeChangedSignal(atributo):Connect(function()
			if jugador:GetAttribute(atributo) then
				limpiar(v, "fuera")
			end
		end))
	end
	table.insert(c, jugador.CharacterAdded:Connect(function()
		limpiar(v, "fuera")
	end))
	-- Golpean, agrietan o rompen lo que miras: fuera de golpe (repararlo no). Si lo abren, fuera.
	table.insert(c, el.modelo:GetAttributeChangedSignal("Golpes"):Connect(cortar("golpe")))
	local grietas = el.modelo:GetAttribute("Cristal") or 0
	table.insert(c, el.modelo:GetAttributeChangedSignal("Cristal"):Connect(function()
		local ahora = el.modelo:GetAttribute("Cristal") or 0
		if ahora > grietas then
			pedirSalir(v, "golpe")
		end
		grietas = ahora
	end))
	table.insert(c, el.modelo:GetAttributeChangedSignal("Vida"):Connect(function()
		if (el.modelo:GetAttribute("Vida") or 0) <= 0 then
			pedirSalir(v, "golpe")
		end
	end))
	table.insert(c, el.modelo:GetAttributeChangedSignal(if el.tipo == "Mirilla" then "Abierta" else "Persiana")
		:Connect(cortar("normal")))
	-- Girar la vista (el ratón fijo en el centro mientras se mira) y salir con un toque en el móvil.
	table.insert(c, UserInputService.InputChanged:Connect(function(entrada, procesado)
		if v.fase ~= "mirar" then
			return
		end
		local tipo = entrada.UserInputType
		if tipo == Enum.UserInputType.MouseMovement then
			girar(v, entrada.Delta.X * RATON * v.sensibilidad, entrada.Delta.Y * RATON * v.sensibilidad)
		elseif tipo == Enum.UserInputType.Touch then
			if not procesado then
				girar(v, entrada.Delta.X * TOQUE, entrada.Delta.Y * TOQUE)
			end
		elseif entrada.KeyCode == Enum.KeyCode.Thumbstick2 then
			v.palanca = Vector2.new(entrada.Position.X, entrada.Position.Y)
		end
	end))
	table.insert(c, UserInputService.InputEnded:Connect(function(entrada)
		if entrada.KeyCode == Enum.KeyCode.Thumbstick2 then
			v.palanca = Vector2.zero
		end
	end))
	table.insert(c, UserInputService.TouchTap:Connect(function(_, procesado)
		if not procesado and v.fase == "mirar" then
			pedirSalir(v, "normal")
		end
	end))
end

empezar = function(el: Elemento, forzar: boolean?)
	if activo then
		pedirSalir(activo, "normal") -- volver a pulsar: dejar de mirar
		return
	end
	local hum, raiz = cuerpo()
	if not hum or not raiz or not manosLibres() or camara.CameraType ~= Enum.CameraType.Custom
		or elementos[el.modelo] ~= el or not el.punto:IsDescendantOf(workspace)
		or (not forzar and not sePuede(el, raiz)) then
		return
	end
	local ojo = camara.CFrame
	local v: Vistazo = {
		el = el,
		fase = "entrar",
		inicio = os.clock(),
		t0 = os.clock(),
		prueba = forzar == true,
		camara = false,
		carteles = false,
		alOtroLado = false,
		vuelto = false,
		pasando = false,
		agarre = nil,
		acercar = T.acercar,
		desde = ojo,
		ajuste = Vector3.zero,
		ultimo = nil,
		fovAntes = camara.FieldOfView,
		fovPuesto = nil,
		fovDesde = camara.FieldOfView,
		radioAhora = 0,
		radioDesde = 0,
		motivo = "normal",
		mirada = ojo.LookVector,
		altura = 0,
		lado = 1,
		yaw = 0,
		pitch = 0,
		objYaw = 0,
		objPitch = 0,
		palanca = Vector2.zero,
		sensibilidad = 1,
		respira = 0,
		tension = 0,
		respingo = -math.huge,
		vio = false,
		contiene = math.huge,
		pegado = false,
		proximaMirada = 0,
		aliento = nil,
		alientoBase = 0,
		cierre = 0,
		cierreDesde = 0,
		hud = nil,
		gui = nil,
		negro = nil,
		iris = nil,
		irisBorde = nil,
		anillos = {},
		bandas = {},
		vineta = {},
		vaho = nil,
		efectos = {},
		conexiones = {},
	}
	if el.tipo == "Ventana" then
		-- La cabeza a la altura de tus ojos (sin el travesaño del medio de la cruceta) y del lado en que estás.
		local rel = el.centro:PointToObjectSpace(ojo.Position)
		v.lado = if rel.X < -0.1 then -1 else 1
		local hueco = math.max(0, el.alto / 2 - 0.6)
		local altura = math.clamp(rel.Y, -hueco, hueco)
		if math.abs(altura) < 0.45 then
			altura = if altura < 0 then -0.45 else 0.45
		end
		v.altura = altura
	end
	activo = v
	local ok, fallo = pcall(function()
		for _, otro in elementos do
			otro.prompt.Enabled = false
		end
		jugador:SetAttribute("Vistazo", el.tipo)
		gestoEntrar(v)
		vigilar(v)
		RunService:BindToRenderStep(PASO, Enum.RenderPriority.Camera.Value + 3, paso) -- tras la cámara y sus temblores
	end)
	if not ok then
		warn("[MirarVista] " .. tostring(fallo))
		limpiar(v, "error")
		return
	end
	-- ManosGestos también ha reaccionado a este cartel (en la puerta, coger el pomo; en la ventana, tocarlo): su gesto
	-- ("Mano") se pisa con uno vacío cuando ya lo ha puesto (va por PromptTriggered, a la vez que este).
	task.defer(function()
		if activo == v then
			Manos.gesto("Mano", 0, function()
				return nil
			end)
		end
	end)
end

-- ===== Los carteles =====

local function nuevo(modelo: Model, tipo: string, punto: Attachment, centro: CFrame, texto: string): Elemento
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Mirar"
	prompt.Style = Enum.ProximityPromptStyle.Custom -- lo pinta Controles (y en el móvil, su botón de acción)
	prompt.ActionText = texto
	prompt.ObjectText = ""
	prompt.KeyboardKeyCode = TECLA
	prompt.GamepadKeyCode = MANDO
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = ALCANCE
	prompt.RequiresLineOfSight = false
	-- Controles: el cartel va una fila por encima del de la cosa y en el móvil su botón queda arriba.
	prompt.UIOffset = Vector2.new(0, -60)
	prompt.Enabled = false
	prompt.Parent = punto
	local el: Elemento = {
		modelo = modelo,
		tipo = tipo,
		punto = punto,
		prompt = prompt,
		cambio = -math.huge,
		espera = (if tipo == "Mirilla" then cfg.TiempoPuerta else cfg.TiempoPersiana) + 0.15,
		centro = centro,
		ancho = modelo:GetAttribute("Ancho") or 4,
		alto = modelo:GetAttribute("Alto") or 4,
		hoja = nil,
		signo = 1,
		y0 = 0,
		grosor = 0,
		tapa = nil,
		tapaMeta = 0,
		piezas = {},
		conexiones = {},
	}
	table.insert(el.conexiones, prompt.Triggered:Connect(function(quien: Player)
		if quien == jugador then
			empezar(el)
		end
	end))
	table.insert(el.conexiones, modelo:GetAttributeChangedSignal(if tipo == "Mirilla" then "Abierta" else "Persiana")
		:Connect(function()
			el.cambio = os.clock()
		end))
	elementos[modelo] = el
	return el
end

local function prepararPuerta(modelo: Instance)
	if not modelo:IsA("Model") or modelo.Name ~= "PuertaPrincipal" or elementos[modelo] then
		return
	end
	local hoja = modelo:WaitForChild("Hoja", 20)
	local bisagra = modelo:GetAttribute("Bisagra")
	local centro = modelo:GetAttribute("Centro")
	if not (hoja and hoja:IsA("BasePart")) or typeof(bisagra) ~= "CFrame" or typeof(centro) ~= "CFrame"
		or elementos[modelo] or not modelo.Parent then
		return
	end
	-- La hoja cerrada tiene el giro de la bisagra (Mapa), aunque al llegar CasaVista ya la haya abierto.
	local signo = if bisagra.LookVector:Dot(centro.LookVector) >= 0 then 1 else -1
	local grosor = hoja.Size.Z / 2
	local y0 = MIRILLA_ALTO - (hoja.Position.Y - bisagra.Position.Y) -- gira en vertical: la altura no cambia
	local punto = Instance.new("Attachment")
	punto.Name = "Mirilla"
	punto.Position = Vector3.new(0, y0, signo * (grosor + 0.08))
	punto.Parent = hoja
	local el = nuevo(modelo, "Mirilla", punto, centro, "Look through")
	el.hoja, el.signo, el.grosor, el.y0 = hoja, signo, grosor, y0
	hacerMirilla(el)
end

local function prepararVentana(modelo: Instance)
	if not modelo:IsA("Model") or elementos[modelo] then
		return
	end
	local mando = modelo:WaitForChild("Mando", 20)
	local centro = modelo:GetAttribute("Centro")
	if not (mando and mando:IsA("BasePart")) or typeof(centro) ~= "CFrame" or elementos[modelo] or not modelo.Parent then
		return
	end
	local punto = Instance.new("Attachment")
	punto.Name = "Vistazo"
	punto.Parent = mando
	punto.WorldPosition = (centro * CFrame.new(0, 0, VENTANA_CARTEL)).Position
	nuevo(modelo, "Ventana", punto, centro, "Peek")
end

local function quitar(modelo: Instance)
	local el = elementos[modelo :: Model]
	if not el then
		return
	end
	if activo and activo.el == el then
		limpiar(activo, "error")
	end
	elementos[modelo :: Model] = nil
	for _, c in el.conexiones do
		c:Disconnect()
	end
	el.punto:Destroy() -- con su cartel
	for _, p in el.piezas do
		p:Destroy()
	end
end

-- Enciende el cartel de lo que tengas cerca si se puede mirar; los demás, apagados.
local function repasar()
	local _, raiz = cuerpo()
	local libre = raiz ~= nil and activo == nil and os.clock() >= descanso and manosLibres()
		and camara.CameraType == Enum.CameraType.Custom
	for _, el in elementos do
		local quiere = false
		-- Sin la hoja o el mando (el punto sin padre daría su posición de dentro, cerca del origen), nada.
		if libre and raiz and el.punto:IsDescendantOf(workspace)
			and (el.punto.WorldPosition - raiz.Position).Magnitude < CERCA then
			quiere = sePuede(el, raiz)
		end
		if el.prompt.Enabled ~= quiere then
			el.prompt.Enabled = quiere
		end
	end
end

-- Para probar en Studio: mirar por lo más cercano de ese tipo ("Mirilla" o "Ventana") sin ir hasta allí.
local function probar(tipo: string)
	local _, raiz = cuerpo()
	if not raiz then
		return
	end
	local mejor, distancia = nil, math.huge
	for _, el in elementos do
		local d = (el.punto.WorldPosition - raiz.Position).Magnitude
		if el.tipo == tipo and d < distancia and el.punto:IsDescendantOf(workspace) then
			mejor, distancia = el, d
		end
	end
	if mejor then
		empezar(mejor, true)
	end
end

-- Qué se está mirando ahora ("Mirilla", "Ventana" o nil), para otros módulos.
function MirarVista.mirando(): string?
	return if activo then activo.el.tipo else nil
end

function MirarVista.start()
	for etiqueta, preparar in { Puerta = prepararPuerta, Ventana = prepararVentana } do
		CollectionService:GetInstanceAddedSignal(etiqueta):Connect(function(modelo)
			task.spawn(preparar, modelo)
		end)
		CollectionService:GetInstanceRemovedSignal(etiqueta):Connect(quitar)
		for _, modelo in CollectionService:GetTagged(etiqueta) do
			task.spawn(preparar, modelo)
		end
	end
	Remotes.Muerte.OnClientEvent:Connect(function(quien: Player)
		if quien == jugador and activo then
			limpiar(activo, "fuera") -- el susto se queda con la cámara
		end
	end)
	task.spawn(function()
		while true do
			task.wait(REPASO)
			local ok, fallo = pcall(repasar)
			if not ok then
				warn("[MirarVista] " .. tostring(fallo))
			end
		end
	end)
	-- Studio: PlayerScripts:FindFirstChild("MirarVista", true).Probar:Fire("Mirilla") (o "Ventana").
	if RunService:IsStudio() then
		local prueba = Instance.new("BindableEvent")
		prueba.Name = "Probar"
		prueba.Event:Connect(probar)
		prueba.Parent = script
	end
end

return MirarVista
