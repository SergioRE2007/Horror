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
	"Usar", -- cliente -> servidor: (objetivo) uso lo que llevo en las manos con esto (serrar, clavar, echar gasolina)
	"Trabajo", -- servidor -> todos: (jugador, que, pieza, segundos) para animar: "Hachazo", "Serrar", "Clavar", "Verter",
	-- "Montar" (una pieza del coche), "Fabricar" (en un banco del taller),
	-- "Parar" (lo ha dejado a medias) y "Parte" (un árbol caído se parte en troncos; jugador = nil)
	"Movil", -- cliente -> servidor: (abierto) miro o guardo el móvil
	"Coche", -- cliente -> servidor (lobby): ("Ranura", n), ("Nueva", nueva) o ("Arrancar"): solo el dueño del coche
	"Vendedor", -- servidor -> cliente: ("Abrir", frase) le habla; cliente -> servidor: ("Cambiar", n) hago el trato n
	"Taller", -- servidor -> cliente: ("Abrir", banco); cliente -> servidor: ("Hacer", n) la receta n del banco que tengo
	-- cerca; servidor -> todos: ("Trampa", posición) una trampa se ha cerrado
	"Huida", -- servidor -> todos: (segundos) la escena final de la huida en el coche
	"Trepador", -- servidor -> todos: ("Baja", modelo) por la chimenea, ("Entra", modelo) sale al salón o ("Quema", modelo)
	"Imitador", -- servidor -> todos: ("Llama", modelo) a la puerta o ("Entra", modelo) le han abierto
	"Acechador", -- servidor -> todos: ("Rama", modelo), ("Carga", modelo) se echa encima o ("Luz", modelo) le frena la linterna
	"Clase", -- cliente -> servidor (lobby): (id) elegir una clase que ya tengo ("" = ninguna)
	"Tienda", -- cliente -> servidor (lobby): ("Clase", id) o ("Cosmetico", id) comprar, ("Poner", tipo, id) ponerme uno
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
