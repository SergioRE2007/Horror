-- Sonidos del juego (lista en Config.Sonidos). Plantillas colgadas en SoundService para que estén precargadas
-- (un Sound nuevo tarda 0,3-0,5 s la primera vez) y copias de ellas al tocar.
--   Sonido.en(nombre, posicion): en 3D, desde ese punto del mundo.
--   Sonido.tocar(nombre): sin posición (interfaz, sustos).
--   Sonido.bucle(nombre): uno que se repite; devuelve el Sound para subirle o bajarle el volumen.
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)

local Sonido = {}

local plantillas: { [string]: Sound } = {}

local function copia(nombre: string): Sound
	local s = plantillas[nombre]:Clone()
	return s
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
		local s = Instance.new("Sound")
		s.Name = nombre
		s.SoundId = "rbxassetid://" .. datos.Id
		s.Volume = datos.Volumen
		s.Parent = carpeta
		plantillas[nombre] = s
		table.insert(lista, s)
	end
	carpeta.Parent = SoundService
	task.spawn(ContentProvider.PreloadAsync, ContentProvider, lista)
end

return Sonido
