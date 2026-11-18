-- La cámara de la partida, leída siempre al día. Si el motor sustituye workspace.CurrentCamera (o aún no existe al
-- cargar un módulo), quien guardó la vieja en una local seguiría tocando una cámara que ya no se ve: por eso los módulos
-- llaman a Camara.get() en cada uso en lugar de guardarla. No tiene start(): se engancha sola al cargarse.
local Camara = {}

local actual: Camera? = workspace.CurrentCamera
local cambios = Instance.new("BindableEvent") -- avisa a quien tenía conexiones hechas a la cámara anterior

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	actual = workspace.CurrentCamera
	cambios:Fire(actual)
end)

-- La cámara actual (nunca vieja). Si el motor aún no ha puesto ninguna, espera a que la haya.
function Camara.get(): Camera
	local c = actual
	if c == nil or c.Parent == nil then
		c = workspace.CurrentCamera
		actual = c
		while c == nil do
			workspace:GetPropertyChangedSignal("CurrentCamera"):Wait()
			c = workspace.CurrentCamera
			actual = c
		end
	end
	return c :: Camera
end

-- Conecta `f` a una propiedad de la cámara y la rehace sola si la cámara cambia. Devuelve algo con :Disconnect().
function Camara.alCambiar(propiedad: string, f: () -> ()): { Disconnect: (any) -> () }
	local conexion = Camara.get():GetPropertyChangedSignal(propiedad):Connect(f)
	local alCambiarCamara = cambios.Event:Connect(function()
		conexion:Disconnect()
		conexion = Camara.get():GetPropertyChangedSignal(propiedad):Connect(f)
		f()
	end)
	return {
		Disconnect = function()
			conexion:Disconnect()
			alCambiarCamara:Disconnect()
		end,
	}
end

return Camara
