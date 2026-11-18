-- Sonidos de lobby y partida: una sola implementación (16.17). juego/cliente/Sonido y lobby/cliente/Sonido son
-- envoltorios de una línea que piden su versión con Sonido.nuevo("juego") o Sonido.nuevo("lobby"), así todos los que
-- hacen require(script.Parent.Sonido) siguen igual.
-- Plantillas colgadas en SoundService (precargadas: un Sound nuevo tarda 0,3-0,5 s la primera vez) y copias de ellas.
--   Sonido.precargar({ nombres }): crea y precarga sus plantillas (el lobby, al empezar con los que vaya a usar).
--   Sonido.start(): crea y precarga todas las de su lugar (la partida; el lobby no lo necesita).
--   Sonido.hay(nombre) -> boolean: si tiene grabación (los que faltan llevan Id 0).
--   Sonido.en(nombre, posicion, tono?) -> Sound: en 3D, desde ese punto del mundo; se borra solo al acabar.
--   Sonido.tocar(nombre) -> Sound: sin posición (interfaz, sustos).
--   Sonido.bucle(nombre, padre?) -> Sound: uno que se repite; devuelve el Sound para subirle o bajarle el volumen.
-- Un sonido con varias grabaciones (Id = lista) suena con una distinta cada vez, nunca la misma dos veces seguidas.
-- Lo que falta (Id 0) o no existe: en la partida devuelve un Sound mudo (para que nada falle); en el lobby, nil.
-- Límite de vida: tocar, en y bucle se destruyen solos si el audio no llega a cargar o a acabar (asset roto o
-- moderado: no llega `Ended`), así no se acumulan Sounds huérfanos.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)

type Datos = { Id: number | { number }, Volumen: number, Alcance: number? }

-- Segundos que se espera, como mínimo, antes de dar por perdido un audio que no ha acabado (a ojo).
local VIDA_MINIMA = 15
-- Y lo que se deja de margen sobre la duración real si por fin carga y suena.
local VIDA_MARGEN = 2
-- Si un bucle a los tantos segundos sigue sin cargar, se avisa en la Salida (no se borra: puede ser un móvil lento).
local VIDA_BUCLE = 30

local Sonido = {}

-- Cómo es cada lugar: sus carpetas de plantillas, dónde busca y qué hace con lo que falta.
local LUGARES = {
	juego = { carpeta = "Plantillas", tablas = { "Sonidos" }, mudos = true, minimo = 8, bucle3D = false },
	lobby = { carpeta = "PlantillasLobby", tablas = { "SonidosLobby", "Sonidos" }, mudos = false, minimo = 6, bucle3D = true },
}

function Sonido.nuevo(lugar: string)
	local L = LUGARES[lugar]
	assert(L, "lugar de Sonido desconocido: " .. tostring(lugar))

	local M = {}
	local plantillas: { [string]: { Sound } } = {}
	local ultima: { [string]: number } = {}
	local azar = Random.new()
	local carpeta: Folder? = nil

	-- La búsqueda mira primero la tabla del lugar (la del lobby, SonidosLobby) y luego la general.
	local function datos(nombre: string): Datos?
		for _, tabla in L.tablas do
			local d = (Config :: any)[tabla][nombre]
			if d then
				return d
			end
		end
		return nil
	end

	local function ids(d: Datos): { number }
		local lista = {}
		for _, id in if type(d.Id) == "table" then d.Id else { d.Id } do
			if type(id) == "number" and id > 0 then
				table.insert(lista, id)
			end
		end
		return lista
	end

	local function plantilla(nombre: string): { Sound }
		local hechas = plantillas[nombre]
		if hechas then
			return hechas
		end
		local lista = {}
		plantillas[nombre] = lista
		local d = datos(nombre)
		if not d then
			warn(`[Sonido] no hay ningún sonido "{nombre}" en Config`)
			return lista
		end
		if not carpeta then
			local c = Instance.new("Folder")
			c.Name = L.carpeta
			c.Parent = SoundService
			carpeta = c
		end
		for _, id in ids(d) do
			local s = Instance.new("Sound")
			s.Name = nombre
			s.SoundId = "rbxassetid://" .. id
			s.Volume = d.Volumen
			s.Parent = carpeta
			table.insert(lista, s)
		end
		return lista
	end

	-- Una copia de una de sus grabaciones; nil si falta (el que llama decide si devuelve un mudo).
	local function copia(nombre: string): Sound?
		local lista = plantilla(nombre)
		if #lista == 0 then
			return nil
		end
		local n = 1
		if #lista > 1 then
			local antes = ultima[nombre] -- nil la primera vez: vale cualquiera
			n = azar:NextInteger(1, if antes then #lista - 1 else #lista)
			if antes and n >= antes then
				n += 1 -- se salta la de la vez anterior
			end
		end
		ultima[nombre] = n
		return lista[n]:Clone()
	end

	-- Lo que se devuelve cuando falta: un Sound mudo (partida) o nada (lobby). El mudo no se cuelga de nada: no suena
	-- ni acaba, y se recoge solo cuando nadie lo guarda.
	local function mudo(): Sound?
		if not L.mudos then
			return nil
		end
		return Instance.new("Sound")
	end

	local function en3D(s: Sound, nombre: string)
		local d = datos(nombre)
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = L.minimo
		s.RollOffMaxDistance = (d and d.Alcance) or 100
	end

	-- Límite de vida: pasado VIDA_MINIMA, si `que` sigue vivo y el audio no suena se destruye; si suena (cargó tarde),
	-- se le da lo que le quede más un margen. `s` es el Sound y `que` lo que se borra (el Sound o su Attachment).
	local function vida(s: Sound, que: Instance)
		task.delay(math.max(VIDA_MINIMA, s.TimeLength + VIDA_MARGEN), function()
			if not que.Parent then
				return
			end
			local resta = s.TimeLength - s.TimePosition
			if s.IsPlaying and resta > 0 then
				task.delay(resta / math.max(s.PlaybackSpeed, 0.1) + VIDA_MARGEN, function()
					if que.Parent then
						que:Destroy()
					end
				end)
				return
			end
			que:Destroy()
		end)
	end

	function M.precargar(nombres: { string })
		local lista = {}
		for _, nombre in nombres do
			for _, s in plantilla(nombre) do
				table.insert(lista, s)
			end
		end
		if #lista > 0 then
			task.spawn(ContentProvider.PreloadAsync, ContentProvider, lista)
		end
	end

	-- Todas las de este lugar (la partida llama a esto el primero de todos).
	function M.start()
		local nombres = {}
		for _, tabla in L.tablas do
			for nombre in (Config :: any)[tabla] do
				table.insert(nombres, nombre)
			end
		end
		M.precargar(nombres)
	end

	function M.hay(nombre: string): boolean
		return #plantilla(nombre) > 0
	end

	function M.en(nombre: string, posicion: Vector3, tono: number?): Sound
		local s = copia(nombre)
		if not s then
			return mudo() :: Sound
		end
		local punto = Instance.new("Attachment")
		punto.WorldPosition = posicion
		punto.Parent = workspace.Terrain
		en3D(s, nombre)
		s.PlaybackSpeed = tono or 1
		s.Parent = punto
		s:Play()
		s.Ended:Once(function()
			punto:Destroy()
		end)
		vida(s, punto)
		return s
	end

	function M.tocar(nombre: string): Sound
		local s = copia(nombre)
		if not s then
			return mudo() :: Sound
		end
		s.Parent = SoundService
		s:Play()
		s.Ended:Once(function()
			s:Destroy()
		end)
		vida(s, s)
		return s
	end

	function M.bucle(nombre: string, padre: Instance?): Sound
		local s = copia(nombre)
		if not s then
			return mudo() :: Sound
		end
		s.Looped = true
		if L.bucle3D and padre and (padre:IsA("BasePart") or padre:IsA("Attachment")) then
			en3D(s, nombre)
		end
		s.Parent = padre or SoundService
		s:Play()
		-- Un bucle dura lo que quiera el que lo pidió y no se borra nunca desde aquí: quien lo pide guarda la referencia y no
		-- lo vuelve a crear, así que borrarlo por tardar en cargar (móvil lento) dejaba el ambiente mudo toda la partida.
		-- Si tarda mucho solo se avisa; en cuanto cargue, suena solo (ya tiene Play).
		task.delay(VIDA_BUCLE, function()
			if s.Parent and not s.IsLoaded then
				warn(`Sonido: el bucle {nombre} aún no ha cargado tras {VIDA_BUCLE} s`)
			end
		end)
		return s
	end

	return M
end

return Sonido
