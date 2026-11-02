-- Sustos con algo de sangre (ver Sustos/init). Moderate: sangre seca y oscura, nada de gore. Todo hasta el alba.
--   Cristal: tres golpecitos en el cristal de una ventana cercana, el cristal vibra y de pronto se planta una mano de
--     sangre por fuera, que resbala dejando el rastro.
--   Espejo: en un espejo que no estás mirando aparece escrito con sangre ("GET OUT"...); al verlo, golpe de tensión y
--     los chorretones empiezan a bajar.
--   Goteo: gotas de sangre que caen del techo justo delante, una mancha que se extiende arriba y un charco abajo.
-- La mano y los chorretones están hechos con marcos (no hay imagen de mano aún): ver el informe de 14.3.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Sonido = require(script.Parent.Parent.Sonido)
local Ui = require(script.Parent.Parent.Parent:WaitForChild("Comun"):WaitForChild("Ui"))
local Util = require(script.Parent.Util)

local azar = Util.azar

-- Una placa local con un SurfaceGui en su cara de delante (`cf` mira hacia quien lo ve).
local function placa(tamano: Vector2, cf: CFrame, porStud: number): (Part, SurfaceGui)
	local p = Util.pieza(Vector3.new(tamano.X, tamano.Y, 0.05), cf, Color3.new(1, 1, 1))
	p.Transparency = 1
	p.CastShadow = false
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = porStud
	gui.LightInfluence = 0.85
	gui.Parent = p
	return p, gui
end

local function marco(padre: Instance, pos: UDim2, tam: UDim2, giro: number?, redondo: number?, transparencia: number?): Frame
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.BackgroundColor3 = Util.SANGRE
	f.BackgroundTransparency = transparencia or 0.12
	f.Position = pos
	f.Size = tam
	f.Rotation = giro or 0
	f.Parent = padre
	if redondo then
		local esquina = Instance.new("UICorner")
		esquina.CornerRadius = UDim.new(redondo, 0)
		esquina.Parent = f
	end
	return f
end

-- Un chorretón que baja desde arriba y se aclara al final.
local function chorreton(padre: Instance, x: number, y: number, ancho: number): Frame
	local f = marco(padre, UDim2.fromScale(x, y), UDim2.fromScale(ancho, 0), 0, 1, 0.1)
	local degradado = Instance.new("UIGradient")
	degradado.Rotation = 90
	degradado.Transparency = NumberSequence.new(0, 0.55)
	degradado.Parent = f
	return f
end

---------------------------------------------------------------- cristal

local conMano: { [Instance]: boolean } = {}

local function roto(el: Instance): boolean
	return (el:GetAttribute("Cristal") or 0) >= Config.Casa.GolpesCristal
end

local function puedeCristal(ctx): any?
	local cam = ctx.cam.Position
	if not Util.dentro(cam) then
		return nil
	end
	local cfg = Util.cfg
	local opciones = {}
	for _, el in CollectionService:GetTagged("Ventana") do
		local centro = el:GetAttribute("Centro") :: CFrame?
		local cristal = el:FindFirstChild("Cristal")
		if not centro or not cristal or not cristal:IsA("BasePart") or roto(el) or conMano[el] then
			continue
		end
		local distancia = (centro.Position - cam).Magnitude
		if distancia >= cfg.CristalDistancia[1] and distancia <= cfg.CristalDistancia[2]
			and (cam - centro.Position):Dot(centro.LookVector) < 0 and Util.libre(cam, centro.Position, { el }) then
			table.insert(opciones, { ventana = el, centro = centro, cristal = cristal })
		end
	end
	return if #opciones > 0 then opciones[azar:NextInteger(1, #opciones)] else nil
end

-- La mano: palma, cuatro dedos y el pulgar, en `padre` (cuadrado).
local function mano(padre: Instance)
	marco(padre, UDim2.fromScale(0.25, 0.45), UDim2.fromScale(0.5, 0.42), -4, 0.4)
	marco(padre, UDim2.fromScale(0.33, 0.55), UDim2.fromScale(0.3, 0.22), 10, 0.5, 0.35) -- más oscuro en el centro
	for i, h in { 0.28, 0.34, 0.32, 0.25 } do
		local x = ({ 0.26, 0.38, 0.5, 0.62 })[i]
		marco(padre, UDim2.fromScale(x, 0.49 - h), UDim2.fromScale(0.1, h), ({ -10, -3, 3, 10 })[i], 1)
	end
	marco(padre, UDim2.fromScale(0.71, 0.5), UDim2.fromScale(0.11, 0.27), 42, 1)
end

local function lanzarCristal(d)
	local el = d.ventana :: Model
	local centro = d.centro :: CFrame
	local cristal = d.cristal :: BasePart
	local fuera = centro.LookVector
	local ancho, alto = el:GetAttribute("Ancho") or 4, el:GetAttribute("Alto") or 5
	-- Tres golpecitos, el cristal vibra...
	for _ = 1, 3 do
		Sonido.en("Toc", cristal.Position + centro.RightVector * azar:NextNumber(-0.6, 0.6), azar:NextNumber(0.95, 1.05))
		task.wait(azar:NextNumber(0.5, 0.75))
	end
	Sonido.en("CristalVibra", cristal.Position)
	task.wait(azar:NextNumber(1.2, 1.8))
	if roto(el) or not el.Parent then
		return
	end
	-- ...y de golpe, la mano por fuera.
	conMano[el] = true -- una mano por ventana
	local x = azar:NextNumber(-1, 1) * math.max(0, ancho / 2 - 0.9)
	local y = azar:NextNumber(-0.2, 1) * math.max(0, alto / 2 - 1.2)
	local pos = centro.Position + centro.RightVector * x + centro.UpVector * (y - 0.5) + fuera * 0.2
	local p, gui = placa(Vector2.new(2, 3.7), CFrame.lookAt(pos, pos - fuera), 70) -- más grande que una mano de persona
	local golpe = Sonido.en("Toc", pos, 0.55)
	golpe.Volume *= 1.4
	local grupo = Instance.new("Frame")
	grupo.BackgroundTransparency = 1
	grupo.Size = UDim2.fromScale(1, 2 / 3.7)
	grupo.Parent = gui
	mano(grupo)
	-- Resbala un poco y deja el rastro (y los regueros de la imagen de gotas).
	local rastro = marco(gui, UDim2.fromScale(0.25, 0.25), UDim2.fromScale(0.5, 0), 0, 0.3, 0.5)
	rastro.ZIndex = 0
	local regueros = Instance.new("ImageLabel")
	regueros.BackgroundTransparency = 1
	regueros.Image = Util.IMAGEN.Gotas
	regueros.ImageTransparency = 1
	regueros.Position = UDim2.fromScale(0.05, 0.3)
	regueros.Size = UDim2.fromScale(0.9, 0.7)
	regueros.ZIndex = 0
	regueros.Parent = gui
	local info = TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(grupo, info, { Position = UDim2.fromScale(0, 0.2) }):Play()
	TweenService:Create(rastro, info, { Size = UDim2.fromScale(0.5, 0.25) }):Play()
	TweenService:Create(regueros, TweenInfo.new(4), { ImageTransparency = 0.15 }):Play()
	Util.tiron(0.35)
	local function quitar()
		p:Destroy()
		conMano[el] = nil
	end
	Util.alAlba(quitar)
	-- Si se rompe el cristal, la mano se va con él.
	Util.vigilar(function()
		if not p.Parent then
			return true
		end
		if not el.Parent or roto(el) then
			quitar()
			return true
		end
		return false
	end)
	task.wait(2.5)
end

---------------------------------------------------------------- espejo

local FRASES = { "Get out of here", "He knew", "Behind you" }
local escritos: { [Model]: boolean } = {}

local function puedeEspejo(ctx): any?
	local cam = ctx.cam.Position
	local casa = Util.casa()
	if not casa or not Util.dentro(cam) then
		return nil
	end
	local cfg = Util.cfg
	local opciones = {}
	for _, m in casa:GetChildren() do
		if m.Name ~= "EspejoPH" or not m:IsA("Model") or escritos[m] then
			continue
		end
		local p = m:GetPivot().Position
		local distancia = (p - cam).Magnitude
		if distancia >= cfg.EspejoDistancia[1] and distancia <= cfg.EspejoDistancia[2] and Util.planta(p.Y) == Util.planta(ctx.pies.Y + 0.5)
			and (ctx.forzado or Util.mirada(p) < 0.45) then
			table.insert(opciones, m)
		end
	end
	return if #opciones > 0 then opciones[azar:NextInteger(1, #opciones)] else nil
end

local function lanzarEspejo(m: Model)
	escritos[m] = true
	local caja, tam = m:GetBoundingBox()
	local frente = m:GetPivot().LookVector
	local pos = caja.Position + frente * (tam.Z / 2 + 0.04) + caja.UpVector * (tam.Y * 0.06)
	local p, gui = placa(Vector2.new(tam.X * 0.8, tam.Y * 0.6), CFrame.lookAt(pos, pos + frente, caja.UpVector), 60)
	local texto = Instance.new("TextLabel")
	texto.BackgroundTransparency = 1
	texto.FontFace = Font.fromEnum(Enum.Font.Creepster)
	texto.Text = Ui.mayusculas(Lang.t(nil, FRASES[azar:NextInteger(1, #FRASES)]))
	texto.TextColor3 = Color3.fromRGB(105, 6, 8)
	texto.TextTransparency = 0.08
	texto.TextScaled = true
	texto.Position = UDim2.fromScale(0.02, 0.06)
	texto.Size = UDim2.fromScale(0.96, 0.5)
	texto.Rotation = azar:NextNumber(-5, 3)
	texto.Parent = gui
	local chorros = {}
	for _ = 1, 8 do
		table.insert(chorros, chorreton(gui, azar:NextNumber(0.08, 0.9), azar:NextNumber(0.4, 0.52), azar:NextNumber(0.008, 0.016)))
	end
	local function bajar(segundos: number)
		for _, c in chorros do
			TweenService:Create(c, TweenInfo.new(segundos * azar:NextNumber(0.7, 1.3), Enum.EasingStyle.Sine),
				{ Size = UDim2.fromScale(c.Size.X.Scale, azar:NextNumber(0.12, 0.45)) }):Play()
		end
	end
	bajar(30) -- bajan despacio aunque no lo mire nadie
	Util.alAlba(function()
		escritos[m] = nil
		p:Destroy()
	end)
	-- La primera vez que lo ve: golpe de tensión y los chorretones bajan de golpe.
	Util.vigilar(function()
		if not p.Parent then
			return true
		end
		local cam = Util.camara().Position
		if (pos - cam).Magnitude < 30 and Util.mirada(pos) > 0.88 and Util.libre(cam, pos) then
			if not Util.bichoCerca(Util.cfg.LejosBicho) then
				Sonido.tocar("Sobresalto")
			end
			bajar(5)
			return true
		end
		return false
	end)
end

---------------------------------------------------------------- goteo

local function puedeGoteo(ctx): any?
	local cam = ctx.cam.Position
	if not Util.dentro(cam) then
		return nil
	end
	local delante = Util.delante()
	local lado = delante:Cross(Vector3.yAxis)
	local p = ctx.pies + delante * 2.8 + lado * azar:NextNumber(-0.6, 0.6)
	local techo = Util.techo(Vector3.new(p.X, ctx.pies.Y + 3, p.Z))
	local suelo = Util.suelo(Vector3.new(p.X, ctx.pies.Y + 2, p.Z), 4)
	if not techo or not suelo or techo - suelo > 16 or techo - suelo < 6 then
		return nil
	end
	local abajo = Util.encimaDeMuebles(Vector3.new(p.X, techo - 0.5, p.Z), suelo)
	return { x = p.X, z = p.Z, techo = techo, abajo = abajo }
end

-- Una mancha plana (decal) que mira hacia `normal`.
local function mancha(pos: Vector3, normal: Vector3, imagen: string, tam: number): Part
	local p = Util.pieza(Vector3.new(tam, tam, 0.02), CFrame.lookAt(pos, pos + normal, Vector3.zAxis), Color3.new(1, 1, 1))
	p.Transparency = 1
	p.CastShadow = false
	local d = Instance.new("Decal")
	d.Texture = imagen
	d.Face = Enum.NormalId.Front
	d.Parent = p
	return p
end

local function lanzarGoteo(d)
	local cfg = Util.cfg
	local arriba = mancha(Vector3.new(d.x, d.techo - 0.02, d.z), -Vector3.yAxis, Util.IMAGEN.Salpicadura, 0.4)
	TweenService:Create(arriba, TweenInfo.new(cfg.GoteoTiempo), { Size = Vector3.new(2.6, 2.6, 0.02) }):Play()
	local charco = mancha(Vector3.new(d.x, d.abajo + 0.03, d.z), Vector3.yAxis, Util.IMAGEN.Salpicadura, 0.1)
	Util.alAlba(function()
		arriba:Destroy()
		charco:Destroy()
	end)
	local t0 = os.clock()
	local gotas = 0
	while os.clock() - t0 < cfg.GoteoTiempo do
		local desde = Vector3.new(d.x + azar:NextNumber(-0.15, 0.15), d.techo - 0.1, d.z + azar:NextNumber(-0.15, 0.15))
		local g = Util.pieza(Vector3.one * 0.12, CFrame.new(desde), Util.SANGRE, nil, Enum.Material.Glass)
		g.Shape = Enum.PartType.Ball
		g.CastShadow = false
		Util.temporal(g)
		local caida = math.sqrt(2 * math.max(0.5, desde.Y - d.abajo) / workspace.Gravity * 2.5)
		local t = TweenService:Create(g, TweenInfo.new(caida, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = Vector3.new(desde.X, d.abajo + 0.05, desde.Z) })
		t:Play()
		t.Completed:Once(function()
			g:Destroy()
			gotas += 1
			Sonido.en("Gota", Vector3.new(d.x, d.abajo, d.z), azar:NextNumber(0.68, 0.8))
			local lado = math.min(1.9, 0.5 + gotas * 0.14)
			TweenService:Create(charco, TweenInfo.new(0.25), { Size = Vector3.new(lado, lado, 0.02) }):Play()
		end)
		task.wait(Util.entre(cfg.GoteoCada))
	end
	task.wait(1.5)
end

return {
	Cristal = { puede = puedeCristal, lanzar = lanzarCristal },
	Espejo = { puede = puedeEspejo, lanzar = lanzarEspejo },
	Goteo = { puede = puedeGoteo, lanzar = lanzarGoteo },
}
