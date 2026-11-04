-- Único sitio donde se definen los RemoteEvents. El servidor los crea; el cliente los espera.
-- El cliente solo pide: el servidor valida todo lo que llega.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NOMBRES = {
	"Idioma", -- cliente -> servidor: ("es" o "en") el idioma que tengo elegido para esta experiencia
	"Aviso", -- servidor -> cliente: (texto) aviso de una línea solo para él
	"Golpeador", -- servidor -> todos: ("Golpe", elemento, resultado) o ("Entra", elemento) para animarlo
	"Muerte", -- servidor -> todos: (jugador, cabeza del bicho, modelo del bicho que le pilla o nil) le han pillado
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
	"Taller", -- servidor -> cliente: ("Abrir", banco, ocultas = números de recetas aún sin descubrir); cliente -> servidor: ("Hacer", n) la receta n del banco que tengo
	-- cerca; servidor -> todos: ("Trampa", posición) una trampa se ha cerrado
	"Huida", -- servidor -> todos: (segundos) la escena final de la huida en el coche
	"Trepador", -- servidor -> todos: ("Baja", modelo) por la chimenea, ("Entra", modelo) sale al salón o ("Quema", modelo)
	"Imitador", -- servidor -> todos: ("Llama", modelo) a la puerta o ("Entra", modelo) le han abierto
	"Acechador", -- servidor -> todos: ("Rama", modelo), ("Carga", modelo) se echa encima o ("Luz", modelo) le frena la linterna
	"Clase", -- cliente -> servidor (lobby): (id) elegir una clase que ya tengo ("" = ninguna)
	"Tienda", -- cliente -> servidor (lobby): ("Clase", id) o ("Cosmetico", id) comprar, ("Poner", tipo, id) ponerme uno
	"Compra", -- cliente -> servidor: abre una compra con Robux: ("Monedas", n), ("Pase", ventaja) o ("Revivir", jugador)
	"Pista", -- servidor -> cliente: (n, encontradas) lee la pista n de shared/Historia (lo pide su ProximityPrompt)
	-- Final de la Bestia (12.2): cada sistema documenta sus mensajes en la cabecera de su módulo.
	"Bestia", -- servidor -> todos: animar a la Bestia (Bestia / BestiaVista)
	"Bengala", -- cliente -> servidor: disparo la pistola; servidor -> todos: el disparo (Bengalas / BengalasVista)
	"Preparativos", -- servidor -> todos: efectos de la preparación (Preparativos / PreparativosVista)
	"Incendio", -- servidor -> todos: el fuego y la escena final (Incendio / IncendioVista)
	-- Más miedo (14.3).
	"Latas", -- servidor -> todos: ("Suena", línea, fuerza, donde 0..1 de la cuerda) algo ha pasado por una trampa de latas (Latas / LatasVista)
	-- Controles y móvil (14.4).
	"Ajustes", -- cliente -> servidor: ("Rendimiento", activo) cambio un ajuste que se guarda (comun/servidor/Ajustes)
	-- Tutorial (14.2).
	"Tutorial", -- cliente -> servidor: ("Saltar") no quiero el tutorial (juego/servidor/Tutorial)
	"Mirar", -- cliente -> servidor: (jugador vivo) de muerto, a quién sigue mi cámara (Muerte: el mapa por partes carga ahí)
	"Mirada", -- cliente -> servidor: (radianes) cuánto miro hacia arriba o abajo; Equipo lo publica en el atributo Mirada
	"Postura", -- cliente -> servidor: ("Agachado", sí/no) o ("Asomar", -1 izquierda / 0 / 1 derecha); Postura lo publica en los atributos Agachado y Asomado
	-- Correr y aguante (14.8).
	"Correr", -- cliente -> servidor: (sí/no) quiero correr; Correr lo publica en los atributos Corriendo, Aguante, Agotado, Frena y Tropiezo
}

local Remotes = {}

if RunService:IsServer() then
	-- En modo Edit (un require desde la barra de comandos o execute_luau, la trampa del CLAUDE.md) no se cuelga nada:
	-- una carpeta de más guardada en el lugar la cogería el cliente al jugar y ningún remoto funcionaría. Al arrancar
	-- el juego se borran las viejas que haya (puede haber varias).
	local enMarcha = RunService:IsRunning()
	if enMarcha then
		for _, vieja in ReplicatedStorage:GetChildren() do
			if vieja.Name == "Remotes" then
				vieja:Destroy()
			end
		end
	end
	local carpeta = Instance.new("Folder")
	carpeta.Name = "Remotes"
	for _, nombre in NOMBRES do
		local remoto = Instance.new("RemoteEvent")
		remoto.Name = nombre
		remoto.Parent = carpeta
		Remotes[nombre] = remoto
	end
	if enMarcha then
		carpeta.Parent = ReplicatedStorage
	end
else
	local carpeta = ReplicatedStorage:WaitForChild("Remotes")
	for _, nombre in NOMBRES do
		Remotes[nombre] = carpeta:WaitForChild(nombre)
	end
end

return Remotes
