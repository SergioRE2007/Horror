-- Sustos sueltos (14.3, "más miedo"): de noche, de vez en cuando, a cada jugador le pasa algo que solo ve él (así el
-- amigo no lo ha visto: "¿lo has visto?"). Todo en el cliente; lo que se mueve o se rompe del mapa vuelve a su sitio
-- al amanecer. Sustos fuertes pero pocos (diseño.md): uno cada varios minutos, algo más seguidos cada noche, nunca dos
-- iguales seguidos, nunca con un bicho cerca, en cinemáticas, la huida o la noche de la Bestia, y casi siempre con el
-- jugador dentro o junto a la casa.
--   Figuras: Silueta (tras una ventana; se aparta si la miras o la alumbras), Pasillo (al fondo; desaparece en un
--     parpadeo de la linterna y las bombillas), Susurro (al oído; las noches altas, algo detrás al girarte).
--   Ruidos: Pasos (cruzan el piso de arriba con polvillo del techo, o el de abajo, y se paran justo encima o debajo),
--     Pared (algo araña dentro de la pared y golpea).
--   Objetos: Portazo (en otra sala; si estaba cerrada, la golpean desde el otro lado), Cuadro (se cae de la pared),
--     Bombilla (parpadea, revienta y la sala se queda a oscuras un rato), Juguetes (el caballito se mece solo, el
--     móvil de la cuna gira y la muñeca te mira).
--   Sangre: Cristal (golpecitos y una mano de sangre por fuera del cristal), Espejo (algo escrito con sangre), Goteo
--     (gotas de sangre del techo y un charco).
-- Un solo bucle ligero (cada CFG.Paso) que reparte los sustos; cada susto corre solo mientras dura.
-- Para probar en Studio (datamodel Client):
--   game.Players.LocalPlayer.PlayerScripts:FindFirstChild("Sustos", true).Lanzar:Fire("Cuadro")
--   ("Alba" lo devuelve todo a su sitio). Lanzado a mano no mira la noche ni los bichos, solo si hay sitio.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(script.Util)

local CFG = Config.Sustos
Util.cfg = CFG

local Sustos = {}

type Ctx = { forzado: boolean, noche: number, pies: Vector3, cam: CFrame }
type Susto = { puede: (ctx: Ctx) -> any?, lanzar: (datos: any, ctx: Ctx) -> () }

local LISTA: { [string]: Susto } = {}
for _, hijo in { script.Figuras, script.Ruidos, script.Objetos, script.Sangre } do
	for nombre, susto in require(hijo) :: any do
		LISTA[nombre] = susto
	end
end

local jugador = Players.LocalPlayer
local activo = false
local ultimo: string? = nil
local estaNoche: { [string]: boolean } = {}
local proximo = math.huge
local bichoHasta = 0 -- os.clock() hasta el que no se asusta (un bicho cerca hace poco)
local albaPendiente = false -- amaneció con un susto en marcha: se recoge todo cuando acabe

-- Todo a su sitio; si hay un susto en marcha, al acabar (aún puede apuntar cosas con alAlba).
local function amanecer()
	if activo then
		albaPendiente = true
	else
		Util.alba()
	end
end

local function contexto(forzado: boolean): Ctx
	return { forzado = forzado, noche = workspace:GetAttribute("Noche") or 1, pies = Util.pies(), cam = Util.camara() }
end

-- Si ahora puede haber un susto (sin mirar el sitio: eso lo dice cada uno).
local function permitido(): boolean
	if workspace:GetAttribute("Fase") ~= "Noche" or workspace:GetAttribute("Final") or workspace:GetAttribute("Bestia") then
		return false
	end
	local camara = workspace.CurrentCamera
	if not camara or camara.CameraType ~= Enum.CameraType.Custom then
		return false -- cinemática
	end
	local humanoide = jugador.Character and jugador.Character:FindFirstChildOfClass("Humanoid")
	if not humanoide or humanoide.Health <= 0 or jugador:GetAttribute("Muerto") or jugador:GetAttribute("Escondido")
		or jugador:GetAttribute("MovilAbierto") or jugador:GetAttribute("MochilaAbierta") then
		return false
	end
	if os.clock() < bichoHasta then
		return false
	end
	return Util.dentro(camara.CFrame.Position, CFG.Junto)
end

local function espera(): number
	local noche = workspace:GetAttribute("Noche") or 1
	local k = math.max(CFG.EsperaMinima, 1 - (noche - 1) * CFG.MenosPorNoche)
	return Util.entre(CFG.Espera) * k
end

local function ejecutar(nombre: string, datos: any, ctx: Ctx)
	activo = true
	ultimo = nombre
	estaNoche[nombre] = true
	task.spawn(function()
		local ok, fallo = pcall(LISTA[nombre].lanzar, datos, ctx)
		if not ok then
			warn("Sustos:", nombre, fallo)
		end
		Util.acabar()
		activo = false
		if albaPendiente then
			albaPendiente = false
			Util.alba()
		end
	end)
end

-- Elige uno al azar entre los que tienen sitio ahora (nunca el de la vez anterior). true si ha salido alguno.
local function elegir(): boolean
	local ctx = contexto(false)
	local opciones, total = {}, 0
	for nombre, susto in LISTA do
		if nombre ~= ultimo then
			local ok, datos = pcall(susto.puede, ctx)
			if ok and datos ~= nil then
				local peso = (CFG.Pesos[nombre] or 1) * (if estaNoche[nombre] then CFG.RepetidoEstaNoche else 1)
				table.insert(opciones, { nombre = nombre, datos = datos, peso = peso })
				total += peso
			elseif not ok then
				warn("Sustos:", nombre, datos)
			end
		end
	end
	if #opciones == 0 then
		return false
	end
	local tirada = Util.azar:NextNumber(0, total)
	for _, o in opciones do
		tirada -= o.peso
		if tirada <= 0 then
			ejecutar(o.nombre, o.datos, ctx)
			return true
		end
	end
	local o = opciones[#opciones]
	ejecutar(o.nombre, o.datos, ctx)
	return true
end

-- A mano, para probar: sin mirar la noche ni los bichos.
function Sustos.lanzar(nombre: string)
	if nombre == "Alba" then
		amanecer()
		return
	end
	local susto = LISTA[nombre]
	if not susto then
		warn("Sustos: no hay ninguno llamado", nombre)
		return
	end
	if activo then
		warn("Sustos: ya hay uno en marcha")
		return
	end
	local ctx = contexto(true)
	local datos = susto.puede(ctx)
	if datos == nil then
		warn("Sustos:", nombre, "no tiene sitio aquí")
		return
	end
	ejecutar(nombre, datos, ctx)
end

function Sustos.start()
	if RunService:IsStudio() then
		local lanzar = Instance.new("BindableEvent")
		lanzar.Name = "Lanzar"
		lanzar.Event:Connect(Sustos.lanzar)
		lanzar.Parent = script
	end
	task.spawn(function()
		local faseAntes = nil
		while true do
			task.wait(CFG.Paso)
			local fase = workspace:GetAttribute("Fase")
			local ahora = os.clock()
			if fase ~= faseAntes then
				if fase == "Noche" then
					proximo = ahora + Util.entre(CFG.Primero)
					table.clear(estaNoche)
				elseif faseAntes == "Noche" then
					amanecer() -- todo a su sitio
					proximo = math.huge
				end
				faseAntes = fase
			end
			if Util.bichoCerca(CFG.LejosBicho) then
				bichoHasta = ahora + CFG.TrasBicho
			end
			Util.vigilarTodo()
			if not activo and ahora >= proximo then
				if permitido() and elegir() then
					proximo = ahora + espera()
				else
					proximo = ahora + CFG.Reintento
				end
			end
		end
	end)
end

return Sustos
