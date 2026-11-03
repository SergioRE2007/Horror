-- Un solo bucle por fotograma para todo lo animado del lobby (CLAUDE.md: "lo animado, en un solo bucle que solo corre
-- cuando hace falta y solo cerca de la cámara"). Cada sistema se apunta con un nombre:
--   Bucle.cada(nombre, fn): fn(dt, ahora, camara) corre en cada fotograma (RenderStepped) mientras esté apuntada.
--     `ahora` = os.clock(). Apuntar otra vez con el mismo nombre la cambia.
--   Bucle.quitar(nombre): la borra.
-- Si una falla, se avisa una vez en la Salida y se quita, para que un fallo no pare a las demás. Sin nada apuntado, el
-- bucle se desconecta.
local RunService = game:GetService("RunService")

local Bucle = {}

type Tarea = { nombre: string, fn: (number, number, Camera) -> () }
local tareas: { Tarea } = {}
local conexion: RBXScriptConnection? = nil

local function paso(dt: number)
	local camara = workspace.CurrentCamera
	local ahora = os.clock()
	-- Sobre una copia: una tarea puede apuntar o quitar otras mientras corre.
	for _, t in table.clone(tareas) do
		local ok, fallo = pcall(t.fn, dt, ahora, camara)
		if not ok then
			warn(`[Bucle] {t.nombre}: {fallo}`)
			Bucle.quitar(t.nombre)
		end
	end
end

function Bucle.quitar(nombre: string)
	for i, t in tareas do
		if t.nombre == nombre then
			table.remove(tareas, i)
			break
		end
	end
	if #tareas == 0 and conexion then
		conexion:Disconnect()
		conexion = nil
	end
end

function Bucle.cada(nombre: string, fn: (number, number, Camera) -> ())
	for _, t in tareas do
		if t.nombre == nombre then
			t.fn = fn
			return
		end
	end
	table.insert(tareas, { nombre = nombre, fn = fn })
	if not conexion then
		conexion = RunService.RenderStepped:Connect(paso)
	end
end

return Bucle
