-- Sonidos del lobby: los de Config.Sonidos que ya existen (viento, zumbido, nevera…) y los de Config.SonidosLobby, que
-- faltan por hacer con ElevenLabs (Id = 0: no suenan hasta tener su Id). Como juego/cliente/Sonido, con plantillas
-- colgadas en SoundService (precargadas: un Sound nuevo tarda 0,3-0,5 s la primera vez), pero solo de los que se usan.
--   Sonido.precargar({ nombres }): crea y precarga sus plantillas (llamarlo al empezar con todos los que se vayan a usar).
--   Sonido.hay(nombre) -> boolean: si tiene Id (si no, las de abajo no hacen nada y devuelven nil).
--   Sonido.en(nombre, posicion, tono?) -> Sound?: en 3D, desde ese punto del mundo; se borra solo al acabar.
--   Sonido.tocar(nombre) -> Sound?: sin posición.
--   Sonido.bucle(nombre, padre?) -> Sound?: uno que se repite (en `padre`, en 3D si es una pieza o un Attachment).
-- Un sonido con varias grabaciones (Id = lista) suena con una distinta cada vez, nunca la misma dos veces seguidas.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)

local Sonido = {}

type Datos = { Id: number | { number }, Volumen: number, Alcance: number? }

local plantillas: { [string]: { Sound } } = {}
local ultima: { [string]: number } = {}
local azar = Random.new()
local carpeta: Folder? = nil

local function datos(nombre: string): Datos?
	return (Config.SonidosLobby :: any)[nombre] or (Config.Sonidos :: any)[nombre]
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
		c.Name = "PlantillasLobby"
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

local function copia(nombre: string): Sound?
	local lista = plantilla(nombre)
	if #lista == 0 then
		return nil
	end
	local n = 1
	if #lista > 1 then
		n = azar:NextInteger(1, #lista - 1)
		if n >= (ultima[nombre] or 0) then
			n += 1 -- se salta la de la vez anterior
		end
	end
	ultima[nombre] = n
	return lista[n]:Clone()
end

local function en3D(s: Sound, nombre: string)
	local d = datos(nombre)
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 6
	s.RollOffMaxDistance = (d and d.Alcance) or 100
end

function Sonido.precargar(nombres: { string })
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

function Sonido.hay(nombre: string): boolean
	return #plantilla(nombre) > 0
end

function Sonido.en(nombre: string, posicion: Vector3, tono: number?): Sound?
	local s = copia(nombre)
	if not s then
		return nil
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
	task.delay(20, function() -- por si no llega a acabar (sin cargar)
		if punto.Parent then
			punto:Destroy()
		end
	end)
	return s
end

function Sonido.tocar(nombre: string): Sound?
	local s = copia(nombre)
	if not s then
		return nil
	end
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	return s
end

function Sonido.bucle(nombre: string, padre: Instance?): Sound?
	local s = copia(nombre)
	if not s then
		return nil
	end
	s.Looped = true
	if padre and (padre:IsA("BasePart") or padre:IsA("Attachment")) then
		en3D(s, nombre)
	end
	s.Parent = padre or SoundService
	s:Play()
	return s
end

return Sonido
