--!strict
-- Modelos 3D de los bichos (Config.Bichos3D): se cargan una vez por su id con InsertService y se dan copias.
-- Librería sin start(). Sin el modelo (sin red, id que no carga) devuelve nil y el bicho sigue con sus bloques.
local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Bichos3D = {}

local cargados: { [string]: Model | false } = {}

local function cargar(nombre: string): Model?
	local hecho = cargados[nombre]
	if hecho ~= nil then
		return hecho or nil
	end
	local id = Config.Bichos3D[nombre]
	local modelo: Model? = nil
	if id then
		local ok, paquete = pcall(InsertService.LoadAsset, InsertService, id)
		if ok then
			modelo = paquete:FindFirstChildWhichIsA("Model")
			if modelo then
				modelo.Parent = nil
			end
			paquete:Destroy()
		else
			warn(`[Bichos3D] no carga el modelo de {nombre} ({id}): {paquete}`)
		end
	end
	cargados[nombre] = modelo or false
	return modelo
end

-- Copia del bicho con los pies en el suelo de `cf` (mirando hacia su LookVector), anclado, sin chocar ni tapar rayos.
function Bichos3D.copia(nombre: string, cf: CFrame): Model?
	local original = cargar(nombre)
	if not original then
		return nil
	end
	-- Un fallo aquí no debe romper a quien lo pide (Mapa, el bicho): sin copia, el bicho sigue con sus bloques
	local ok, resultado = pcall(function(): Model?
		local modelo = original:Clone()
		modelo.Name = nombre
		-- La caja de la malla (la del modelo sigue al pivote, que el importador deja girado)
		local malla = modelo:FindFirstChildWhichIsA("MeshPart", true)
		if not malla then
			modelo:Destroy()
			return nil
		end
		for _, d in modelo:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			elseif d:IsA("BaseScript") then
				d:Destroy() -- un modelo subido no trae código propio que corra en el juego
			end
		end
		-- Sale mirando a -Z: el centro de abajo de la malla va a `cf` (sin tocar WorldPivot, que llega mal al cliente)
		local caja = malla.CFrame
		local pies = CFrame.new(caja.Position - caja.UpVector * malla.Size.Y / 2)
		modelo:PivotTo(cf * pies:Inverse() * modelo:GetPivot())
		return modelo
	end)
	if not ok then
		warn(`[Bichos3D] no sale la copia de {nombre}: {resultado}`)
		return nil
	end
	return resultado
end

-- Viste un bicho de bloques (aún sin colgar en el mapa) con su malla 3D: la malla va soldada a la raíz, sin peso ni
-- choque, y sus bloques de siempre se quedan invisibles (siguen para la lógica, el gateo y los rayos; el cliente copia
-- su postura en los huesos, Malla3D). `pies`: el suelo bajo la raíz, mirando hacia delante; `cadera`: dónde está la
-- cadera de los bloques (la de la malla se pone encima, en planta). Sin modelo no cambia nada y devuelve false.
function Bichos3D.vestir(m: Model, nombre: string, pies: CFrame, cadera: Vector3): boolean
	local raiz = m.PrimaryPart
	local malla = Bichos3D.copia(nombre, pies)
	if not raiz or not malla then
		return false
	end
	local ok, fallo = pcall(function()
		local hips = malla:FindFirstChild("Hips", true)
		if hips and hips:IsA("Bone") then
			local d = cadera - hips.WorldPosition
			malla:PivotTo(malla:GetPivot() + Vector3.new(d.X, 0, d.Z))
		end
		for _, d in malla:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.Massless = true
				local soldadura = Instance.new("WeldConstraint")
				soldadura.Part0 = raiz
				soldadura.Part1 = d
				soldadura.Parent = d
			elseif d:IsA("AnimationController") or d:IsA("Folder") then
				d:Destroy() -- InitialPoses y el controlador del importador: los huesos los mueve el cliente
			end
		end
	end)
	if not ok then
		warn(`[Bichos3D] no se viste {nombre}: {fallo}`)
		malla:Destroy()
		return false
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = 1
		end
	end
	malla.Name = "Malla3D"
	malla.Parent = m
	m:SetAttribute("Malla3D", true) -- el cliente espera a la malla antes de preparar el bicho
	return true
end

return Bichos3D
