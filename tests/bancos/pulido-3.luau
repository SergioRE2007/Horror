-- Banco del pulido 14.9.1 (grupo 3). Ejecutar desde la raíz: lune run tests/bancos/pulido-3.luau (lo corre
-- tests/regressions.luau). Con el Roblox de mentira (tests/bancos/_roblox.luau):
--   Sustos/Util.tiron: el respingo se deshace antes de la cámara de Roblox, así que al acabar la cámara mira justo
--   donde miraba (antes se quedaba desviada); en una cinemática (Scriptable) no la toca.
--   Ui.aviso en el móvil: el cuadro acaba antes de los botones de acción (Hud.Acciones) y la letra encoge si no cabe.
-- Si algo no se cumple, termina con error.
local crearMundo = require("./_roblox")

local cuentas = 0
local function comprueba(cond: any, etiqueta: string)
	assert(cond, etiqueta)
	cuentas += 1
end

-- El tirón: con la cámara de Roblox quieta (no la mueve nadie más), al acabar vuelve a su sitio exacto.
do
	local m = crearMundo()
	local g = m.global
	local CFrame, Vector3, Enum = g.CFrame, g.Vector3, g.Enum
	m.camaraRoblox = false
	local Util = m.cargar("src/juego/cliente/Sustos/Util")
	local camara = m.camara
	local inicio = CFrame.lookAt(Vector3.new(0, 5, 0), Vector3.new(10, 4, 3))
	camara.CFrame = inicio
	Util.tiron(1)
	local movida = false
	m.correr(0.2, 1 / 144, function()
		if (camara.CFrame.LookVector - inicio.LookVector).Magnitude > 1e-4 then
			movida = true
		end
	end)
	comprueba(movida, "tirón: la cámara da el respingo")
	m.correr(0.6, 1 / 144)
	comprueba((camara.CFrame.LookVector - inicio.LookVector).Magnitude < 1e-4, "tirón: al acabar mira donde miraba")
	comprueba((camara.CFrame.Position - inicio.Position).Magnitude < 1e-4, "tirón: y no se ha movido")
	-- Dos seguidos (el segundo pilla al primero a medias): tampoco queda desviada.
	Util.tiron(0.6)
	m.correr(0.15, 1 / 30)
	Util.tiron(1)
	m.correr(0.8, 1 / 30)
	comprueba((camara.CFrame.LookVector - inicio.LookVector).Magnitude < 1e-4, "tirón: dos seguidos, sin desvío")
	-- En una cinemática la cámara la lleva un script: no se toca.
	camara.CameraType = Enum.CameraType.Scriptable
	inicio = camara.CFrame
	Util.tiron(1)
	local tocada = false
	m.correr(0.6, 1 / 60, function()
		if (camara.CFrame.LookVector - inicio.LookVector).Magnitude > 1e-6 then
			tocada = true
		end
	end)
	comprueba(not tocada, "tirón: en una cinemática no toca la cámara")
end

-- El aviso de una línea en un teléfono de 640 × 360.
do
	local m = crearMundo()
	m.movil()
	local Ui = m.cargar("src/comun/cliente/Ui")
	local hud = Ui.hud()
	Ui.aviso("La reja está lista. La palanca está fuera, junto a la trampilla.", 2)
	local aviso = nil
	for _, h in hud:GetChildren() do
		if h:IsA("TextLabel") and string.find(h.Text, "reja", 1, true) then
			aviso = h
		end
	end
	comprueba(aviso, "aviso: está")
	-- Hud.Acciones (Controles): AnchorPoint (1, 0,5) al 95,5 % del ancho y 200 de diseño de ancho.
	local escala = Ui.escala()
	local acciones = 0.955 * 640 - 200 * escala
	local derecha = (aviso.Position.X.Scale + aviso.Size.X.Scale * (1 - aviso.AnchorPoint.X)) * 640
	comprueba(derecha <= acciones, `aviso: acaba antes de los botones de acción ({derecha} > {acciones})`)
	comprueba(aviso.TextScaled and aviso:FindFirstChildOfClass("UITextSizeConstraint"), "aviso: la letra encoge")
	comprueba(aviso:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize == 26, "aviso: como mucho la de siempre")
	m.correr(4)
	comprueba(aviso.Parent == nil, "aviso: se va solo")
end

print(`pulido-3: {cuentas} comprobaciones bien`)
