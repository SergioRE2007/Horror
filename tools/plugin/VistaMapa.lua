-- Plugin de Studio (pedido por el usuario): ver el mapa sin darle a Play para mover cosas a mano.
-- Se instala copiándolo a %LOCALAPPDATA%\Roblox\Plugins (tools/plugin/instalar.ps1).
--   VER MAPA: genera el mapa como al jugar (Mapa.start) en workspace.Mapa. Cada pieza y modelo guarda dónde salió
--     (atributo Origen) para saber luego qué se ha movido.
--   CAMBIOS: escribe en la Salida lo que se ha movido, añadido o girado, para pasarlo al código (el mapa lo genera el
--     código: lo movido a mano se pierde al darle a Play hasta que Claude lo pase a Mapa.luau).
--   QUITAR MAPA: lo borra (al darle a Play lo borra igualmente Limpieza).
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ServerScriptService = game:GetService("ServerScriptService")

local barra = plugin:CreateToolbar("Juego de terror")
local botonVer = barra:CreateButton("VER MAPA", "Genera el mapa sin darle a Play", "")
local botonCambios = barra:CreateButton("CAMBIOS", "Escribe en la Salida lo que has movido", "")
local botonQuitar = barra:CreateButton("QUITAR MAPA", "Borra el mapa generado", "")
for _, b in { botonVer, botonCambios, botonQuitar } do
	b.ClickableWhenViewportHidden = true
end

local function enJuego(): boolean
	return game:GetService("RunService"):IsRunning()
end

local function generar()
	if enJuego() then
		warn("[VistaMapa] Solo en modo edición, sin Play.")
		return
	end
	local modulo = ServerScriptService:FindFirstChild("Mapa", true)
	if not modulo then
		warn("[VistaMapa] No encuentro el módulo Mapa: ¿está Rojo conectado?")
		return
	end
	local grabando = ChangeHistoryService:TryBeginRecording("Ver mapa")
	local viejo = workspace:FindFirstChild("Mapa")
	if viejo then
		viejo:Destroy()
	end
	local mapa = Instance.new("Folder")
	mapa.Name = "Mapa"
	mapa.Parent = workspace
	-- Una copia de la carpeta del servidor: require guarda el resultado de cada módulo y no vería los cambios de Rojo.
	local copia = modulo.Parent:Clone()
	local ok, err = pcall(function()
		(require :: any)(copia:FindFirstChild("Mapa")).start()
	end)
	copia:Destroy()
	if ok then
		local n = 0
		for _, d in mapa:GetDescendants() do
			if d:IsA("BasePart") then
				d:SetAttribute("Origen", d.CFrame)
				n += 1
			elseif d:IsA("Model") then
				d:SetAttribute("Origen", d:GetPivot())
			end
		end
		print(`[VistaMapa] Mapa generado ({n} piezas). Mueve lo que quieras y pulsa CAMBIOS.`)
	else
		warn("[VistaMapa] Falló al generar: " .. tostring(err))
	end
	if grabando then
		ChangeHistoryService:FinishRecording(grabando, Enum.FinishRecordingOperation.Commit)
	end
end

local function redondear(v: Vector3): string
	return string.format("(%.1f, %.1f, %.1f)", v.X, v.Y, v.Z)
end

local function giroY(cf: CFrame): number
	local _, y = cf:ToOrientation()
	return math.deg(y)
end

local function cambios()
	local mapa = workspace:FindFirstChild("Mapa")
	if not mapa then
		warn("[VistaMapa] No hay mapa: pulsa VER MAPA.")
		return
	end
	local lineas = {}
	local function mirar(cosa: Instance)
		local ahora: CFrame?, antes = nil, cosa:GetAttribute("Origen")
		if cosa:IsA("Model") then
			ahora = cosa:GetPivot()
		elseif cosa:IsA("BasePart") then
			ahora = cosa.CFrame
		end
		if ahora then
			local nombre = cosa:GetFullName():gsub("^Workspace%.Mapa%.", "")
			if typeof(antes) ~= "CFrame" then
				table.insert(lineas, `NUEVO {nombre} en {redondear(ahora.Position)} giro {math.round(giroY(ahora))}`)
				return -- lo de dentro de algo nuevo no se repite
			end
			local movido = (ahora.Position - antes.Position).Magnitude > 0.05
			local girado = math.abs(giroY(ahora) - giroY(antes)) > 0.5
			if movido or girado then
				table.insert(lineas, `MOVIDO {nombre}: {redondear(antes.Position)} -> {redondear(ahora.Position)}, giro {math.round(giroY(antes))} -> {math.round(giroY(ahora))}`)
				return -- si se movió el modelo entero, no se repite cada pieza
			end
		end
		for _, hijo in cosa:GetChildren() do
			mirar(hijo)
		end
	end
	for _, hijo in mapa:GetChildren() do
		mirar(hijo)
	end
	if #lineas == 0 then
		print("[VistaMapa] No se ha movido nada.")
	else
		print(`[VistaMapa] {#lineas} cambios:\n` .. table.concat(lineas, "\n"))
	end
end

local function quitar()
	if enJuego() then
		return
	end
	local mapa = workspace:FindFirstChild("Mapa")
	if mapa then
		local grabando = ChangeHistoryService:TryBeginRecording("Quitar mapa")
		mapa:Destroy()
		if grabando then
			ChangeHistoryService:FinishRecording(grabando, Enum.FinishRecordingOperation.Commit)
		end
	end
end

botonVer.Click:Connect(generar)
botonCambios.Click:Connect(cambios)
botonQuitar.Click:Connect(quitar)
