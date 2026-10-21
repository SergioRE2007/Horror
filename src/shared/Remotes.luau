-- Único sitio donde se definen los RemoteEvents. El servidor los crea; el cliente los espera.
-- El cliente solo pide: el servidor valida todo lo que llega.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NOMBRES = {
	"Idioma", -- cliente -> servidor: ("es" o "en") el idioma que tengo elegido para esta experiencia
	"Aviso", -- servidor -> cliente: (texto) aviso de una línea solo para él
	"Golpeador", -- servidor -> todos: ("Golpe", elemento, resultado) o ("Entra", elemento) para animarlo
	"Muerte", -- servidor -> todos: (jugador, cabeza del bicho) le han pillado
	"Salir", -- cliente -> servidor: salgo del escondite
	"Raspador", -- servidor -> todos: ("Chilla", modelo) le ha dado un flash, o ("Entra", ventana)
	"Linterna", -- cliente -> servidor: enciende o apaga mi linterna (si no tiene pila, la cambia)
	"Flash", -- cliente -> servidor: (dirección de la cámara) hago una foto; servidor -> todos: (jugador) ha hecho una
	"Mochila", -- cliente -> servidor: ("Abrir", abierta), ("Mover", id, x, y, girada) o ("Tirar", id)
	"Cargar", -- cliente -> servidor: suelto lo pesado que llevo
}

local Remotes = {}

if RunService:IsServer() then
	local carpeta = Instance.new("Folder")
	carpeta.Name = "Remotes"
	for _, nombre in NOMBRES do
		local remoto = Instance.new("RemoteEvent")
		remoto.Name = nombre
		remoto.Parent = carpeta
		Remotes[nombre] = remoto
	end
	carpeta.Parent = ReplicatedStorage
else
	local carpeta = ReplicatedStorage:WaitForChild("Remotes")
	for _, nombre in NOMBRES do
		Remotes[nombre] = carpeta:WaitForChild(nombre)
	end
end

return Remotes
