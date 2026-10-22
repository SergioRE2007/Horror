-- La chimenea del salón: lo que echa al Trepador. Con un tronco en las manos, R (Cargar.alUsar "Tronco", etiqueta
-- Chimenea) lo echa al fuego y arde Config.Chimenea.PorTronco segundos (se suman, hasta Max troncos a la vez).
--   Atributo del modelo: Fuego = hora del servidor (GetServerTimeNow) hasta la que arde. El cliente (ChimeneaVista)
--   pinta las llamas, la luz, el humo del tiro y el crepitar.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Cargar = require(script.Parent.Cargar)

local Chimenea = {}

local C = Config.Chimenea
local modelo: Model

local function ahora(): number
	return workspace:GetServerTimeNow()
end

local function fin(): number
	return math.max(ahora(), modelo:GetAttribute("Fuego") or 0)
end

function Chimenea.encendida(): boolean
	return (modelo:GetAttribute("Fuego") or 0) > ahora()
end

-- Echa `troncos` al fuego (también el modo de pruebas).
function Chimenea.echar(troncos: number)
	modelo:SetAttribute("Fuego", fin() + C.PorTronco * troncos)
end

-- Se apaga del todo (al volver a empezar el día).
function Chimenea.apagar()
	modelo:SetAttribute("Fuego", 0)
end

-- Dónde está la boca de arriba del tiro y por dónde se sale al salón (para el Trepador).
function Chimenea.tiro(): Vector3
	return modelo:GetAttribute("Tiro") :: Vector3
end

function Chimenea.salida(): CFrame
	return modelo:GetAttribute("Salida") :: CFrame
end

function Chimenea.start()
	modelo = CollectionService:GetTagged("Chimenea")[1]
	modelo:SetAttribute("Fuego", 0)
	Cargar.alUsar("Tronco", {
		etiquetas = { "Chimenea" },
		accion = "Echar",
		preparar = function(jugador)
			if fin() - ahora() > C.PorTronco * (C.Max - 1) then
				Remotes.Aviso:FireClient(jugador, Lang.t(jugador, "The fire is already high."))
				return nil
			end
			return modelo:GetAttribute("Hogar") :: CFrame, C.Echar
		end,
		terminar = function(_jugador, _chimenea, pieza)
			pieza:Destroy()
			Chimenea.echar(1)
		end,
	})
end

return Chimenea
