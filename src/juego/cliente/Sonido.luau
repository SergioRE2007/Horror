-- Sonidos del juego (lista en Config.Sonidos). Plantillas colgadas en SoundService para que estén precargadas
-- (un Sound nuevo tarda 0,3-0,5 s la primera vez) y copias de ellas al tocar.
--   Sonido.en(nombre, posicion): en 3D, desde ese punto del mundo.
--   Sonido.tocar(nombre): sin posición (interfaz, sustos).
--   Sonido.bucle(nombre): uno que se repite; devuelve el Sound para subirle o bajarle el volumen.
-- Un sonido con varias grabaciones (Id = lista) suena con una distinta cada vez, nunca la misma dos veces seguidas.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)

local Sonido = {}

local plantillas: { [string]: { Sound } } = {}
local ultima: { [string]: number } = {}
local azar = Random.new()

local function copia(nombre: string): Sound
	local lista = plantillas[nombre]
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

function Sonido.en(nombre: string, posicion: Vector3, tono: number?): Sound
	local punto = Instance.new("Attachment")
	punto.WorldPosition = posicion
	punto.Parent = workspace.Terrain
	local s = copia(nombre)
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 8
	s.RollOffMaxDistance = Config.Sonidos[nombre].Alcance or 100
	s.PlaybackSpeed = tono or 1
	s.Parent = punto
	s:Play()
	s.Ended:Once(function()
		punto:Destroy()
	end)
	task.delay(15, function()
		if punto.Parent then
			punto:Destroy()
		end
	end)
	return s
end

function Sonido.tocar(nombre: string): Sound
	local s = copia(nombre)
	s.Parent = SoundService
	s:Play()
	s.Ended:Once(function()
		s:Destroy()
	end)
	return s
end

function Sonido.bucle(nombre: string, padre: Instance?): Sound
	local s = copia(nombre)
	s.Looped = true
	s.Parent = padre or SoundService
	s:Play()
	return s
end

function Sonido.start()
	local carpeta = Instance.new("Folder")
	carpeta.Name = "Plantillas"
	local lista = {}
	for nombre, datos in Config.Sonidos do
		plantillas[nombre] = {}
		for _, id in if type(datos.Id) == "table" then datos.Id else { datos.Id } do
			local s = Instance.new("Sound")
			s.Name = nombre
			s.SoundId = "rbxassetid://" .. id
			s.Volume = datos.Volumen
			s.Parent = carpeta
			table.insert(plantillas[nombre], s)
			table.insert(lista, s)
		end
	end
	carpeta.Parent = SoundService
	task.spawn(ContentProvider.PreloadAsync, ContentProvider, lista)
end

return Sonido
