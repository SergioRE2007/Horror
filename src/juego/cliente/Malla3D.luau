--!strict
-- La malla 3D de un bicho (Bichos3D.vestir en el servidor) copia la postura de sus bloques invisibles: cada hueso gira
-- lo mismo que el bloque que le toca desde su reposo (en el espacio de la raíz) y la cadera se desplaza con él. Así
-- todo lo que ya hacía la Vista con los bloques (andar, golpear, gatear, el susto) lo hace la malla sin rehacerlo.
-- Como la malla no tiene las medidas de los bloques (piernas más largas, torso más corto):
--   - las piernas van con IK de dos huesos al sitio del pie de su bloque (los pies no se hunden ni flotan y, andando,
--     las rodillas se doblan solas);
--   - con `alinear` (la Vista lo sube al gatear) toda la malla se mueve para que el cuello caiga en el de los bloques:
--     así la cabeza llega a ras de suelo y entra bajo el mueble como la de bloques.
-- Librería sin start(): la Vista llama a Malla3D.preparar al llegar el bicho y a Malla3D.mover cada fotograma, después
-- de poner los Transform de sus motores.
local Malla3D = {}

-- Cómo sigue un hueso a los bloques: gira como `a` (o a medio camino de `a` a `b`, `t`), solo `f` de ese giro; con
-- `desplaza`, además se mueve lo que se mueva la junta de `a` (la cadera). `estira`: su sitio en el padre, más lejos.
export type Sigue = { a: string?, b: string?, t: number?, f: number?, desplaza: boolean?, estira: number? }
-- El centro de la cara en el hueso de la cabeza (para Cara3D, la cara que mira la cámara del susto) y el bloque de la
-- cabeza, del que toma el giro.
export type Cara = { bloque: string, hueso: string, centro: Vector3 }
-- Una pierna con IK: sus tres huesos y el bloque que la mueve, con la planta del pie en ese bloque.
export type Pierna = { muslo: string, rodilla: string, pie: string, bloque: string, planta: Vector3 }
-- El hueso que se pone en la junta de un bloque al alinear.
export type Cuello = { hueso: string, bloque: string }
export type Opciones = { mapa: { [string]: Sigue }, cara: Cara?, piernas: { Pierna }?, cuello: Cuello? }

type Hueso = {
	bone: Bone,
	padre: number?, -- en la lista (nil: cuelga de la malla)
	cf0: CFrame, -- bone.CFrame: su sitio de reposo en el padre
	sitio: CFrame, -- el mismo, ya estirado
	giro0: CFrame, -- su giro en reposo (en la raíz)
	pos0: Vector3, -- su sitio en reposo (en la raíz)
	sigue: Sigue?,
}

type PiernaLista = {
	muslo: number,
	rodilla: number,
	pie: number,
	largo1: number, -- del muslo a la rodilla
	largo2: number, -- de la rodilla al pie
	bloque: string,
	planta: Vector3,
	tobillo: Vector3, -- en reposo, del sitio de la planta del bloque al hueso del pie (en la raíz)
}

export type Rig = {
	raiz: BasePart,
	malla: MeshPart,
	enRaiz: CFrame, -- la malla en la raíz (va soldada)
	motores: { [string]: Motor6D }, -- por el nombre de su bloque
	reposo: { [string]: CFrame }, -- cada bloque en reposo (en la raíz)
	huesos: { Hueso },
	mundo: { CFrame }, -- lo calculado este fotograma, por hueso (en la raíz)
	dobla: { [string]: Vector3 }, -- por hueso: giro de más (eje por radianes, en los ejes de su bloque; lo pone la Vista)
	alinear: number, -- 0..1: cuánto se mueve la malla para que el cuello caiga en el de los bloques (lo pone la Vista)
	piernas: { PiernaLista },
	cuello: number?,
	cuelloBloque: string?,
	cara: BasePart?, -- pieza invisible en la cabeza de la malla
	caraEn: CFrame, -- la cara en el hueso de la cabeza
	caraHueso: number?,
}

local function giro(cf: CFrame): CFrame
	return cf.Rotation
end

-- El giro más corto que lleva la dirección `a` a la `b`.
local function entre(a: Vector3, b: Vector3): CFrame
	if a.Magnitude < 1e-6 or b.Magnitude < 1e-6 then
		return CFrame.identity -- sin dirección: un NaN en un Bone.Transform lo rompería para siempre
	end
	local ua, ub = a.Unit, b.Unit
	local eje = ua:Cross(ub)
	local seno = eje.Magnitude
	if seno < 1e-6 then
		return CFrame.identity -- iguales (u opuestas, que aquí no pasa: el IK solo gira un poco)
	end
	return CFrame.fromAxisAngle(eje / seno, math.atan2(seno, ua:Dot(ub)))
end

-- El bloque `nombre` en la raíz con los Transform de ahora (o en reposo), siguiendo sus motores hasta la raíz.
local function bloque(rig: Rig, nombre: string, ahora: { [string]: CFrame }?, enReposo: boolean): CFrame
	local hecho = if enReposo then rig.reposo[nombre] else (ahora :: { [string]: CFrame })[nombre]
	if hecho then
		return hecho
	end
	local motor = rig.motores[nombre]
	local p0 = motor.Part0
	local padre = if p0 == rig.raiz or not p0 then CFrame.identity else bloque(rig, (p0 :: BasePart).Name, ahora, enReposo)
	local t = if enReposo then CFrame.identity else motor.Transform
	local cf = padre * motor.C0 * t * motor.C1:Inverse()
	if enReposo then
		rig.reposo[nombre] = cf
	else
		(ahora :: { [string]: CFrame })[nombre] = cf
	end
	return cf
end

-- La junta de `nombre` (donde gira respecto a su padre) en la raíz.
local function junta(rig: Rig, nombre: string, ahora: { [string]: CFrame }?, enReposo: boolean): Vector3
	local motor = rig.motores[nombre]
	local p0 = motor.Part0
	local padre = if p0 == rig.raiz or not p0 then CFrame.identity else bloque(rig, (p0 :: BasePart).Name, ahora, enReposo)
	return (padre * motor.C0 * (if enReposo then CFrame.identity else motor.Transform)).Position
end

-- `modelo`: el bicho con su Malla3D; `motores`: sus Motor6D por el nombre del bloque que mueven; `o.mapa`: qué hueso
-- sigue a qué (los que no salen, y sus hijos, siguen a su padre). Devuelve nil si no tiene malla (se queda con los
-- bloques).
function Malla3D.preparar(modelo: Model, motores: { [string]: Motor6D }, o: Opciones): Rig?
	local raiz = modelo.PrimaryPart or modelo:FindFirstChild("HumanoidRootPart") :: BasePart?
	local carpeta = modelo:FindFirstChild("Malla3D")
	local malla = carpeta and carpeta:FindFirstChildWhichIsA("MeshPart", true)
	if not raiz or not malla then
		return nil
	end
	local rig: Rig = {
		raiz = raiz, malla = malla, enRaiz = raiz.CFrame:ToObjectSpace(malla.CFrame), motores = motores, reposo = {},
		huesos = {}, mundo = {}, dobla = {}, alinear = 0, piernas = {}, cuello = nil, cuelloBloque = nil, cara = nil,
		caraEn = CFrame.identity, caraHueso = nil,
	}
	-- Los huesos que se mueven (y todos sus antepasados), de padres a hijos.
	local indice: { [string]: number } = {}
	local function meter(bone: Bone): number
		local ya = indice[bone.Name]
		if ya then
			return ya
		end
		local arriba = bone.Parent
		local padre = if arriba and arriba:IsA("Bone") then meter(arriba) else nil
		local sigue = o.mapa[bone.Name]
		local sitio = bone.CFrame
		if sigue and sigue.estira then
			sitio = CFrame.new(sitio.Position * sigue.estira) * sitio.Rotation
		end
		local enPadre = if padre then rig.mundo[padre] else rig.enRaiz
		local cf = enPadre * sitio
		table.insert(rig.huesos, { bone = bone, padre = padre, cf0 = bone.CFrame, sitio = sitio, giro0 = giro(cf), pos0 = cf.Position, sigue = sigue })
		table.insert(rig.mundo, cf)
		indice[bone.Name] = #rig.huesos
		return #rig.huesos
	end
	for _, d in malla:GetDescendants() do
		if d:IsA("Bone") and o.mapa[d.Name] then
			meter(d)
		end
	end
	if #rig.huesos == 0 then
		return nil
	end
	for nombre in motores do
		bloque(rig, nombre, nil, true)
	end
	for _, p in o.piernas or {} do
		local i1, i2, i3 = indice[p.muslo], indice[p.rodilla], indice[p.pie]
		-- Con los dos huesos de largo de verdad (si no, el clamp del IK no tiene rango)
		if i1 and i2 and i3 and motores[p.bloque] and rig.huesos[i2].padre == i1 and rig.huesos[i3].padre == i2
			and rig.huesos[i2].sitio.Position.Magnitude > 0.05 and rig.huesos[i3].sitio.Position.Magnitude > 0.05 then
			table.insert(rig.piernas, {
				muslo = i1, rodilla = i2, pie = i3,
				largo1 = rig.huesos[i2].sitio.Position.Magnitude, largo2 = rig.huesos[i3].sitio.Position.Magnitude,
				bloque = p.bloque, planta = p.planta,
				tobillo = rig.huesos[i3].pos0 - rig.reposo[p.bloque] * p.planta,
			})
		end
	end
	if o.cuello and indice[o.cuello.hueso] and motores[o.cuello.bloque] then
		rig.cuello = indice[o.cuello.hueso]
		rig.cuelloBloque = o.cuello.bloque
	end
	-- La cara: en el centro de la cabeza de la malla, girada como el bloque de la cabeza.
	local cara = o.cara
	local i = cara and indice[cara.hueso]
	if cara and i and motores[cara.bloque] then
		rig.caraHueso = i
		rig.caraEn = rig.mundo[i]:Inverse() * CFrame.new(rig.mundo[i] * cara.centro) * giro(rig.reposo[cara.bloque])
		local vieja = modelo:FindFirstChild("Cara3D")
		if vieja then
			vieja:Destroy() -- de un preparar anterior: dos con el mismo nombre confundían a la cámara del susto
		end
		local p = Instance.new("Part")
		p.Name = "Cara3D"
		p.Size = Vector3.new(0.2, 0.2, 0.2)
		p.Transparency = 1
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.CFrame = raiz.CFrame * rig.mundo[i] * rig.caraEn
		p.Parent = modelo
		rig.cara = p
	end
	return rig
end

-- El Transform del hueso `i` para que quede en rig.mundo[i] (con su padre ya puesto).
local function poner(rig: Rig, i: number)
	local h = rig.huesos[i]
	local enPadre = if h.padre then rig.mundo[h.padre] else rig.enRaiz
	h.bone.Transform = (enPadre * h.cf0):Inverse() * rig.mundo[i]
end

-- IK de dos huesos: la rodilla hacia donde ya apuntaba y el pie en `meta` (o lo más cerca que llegue).
local function pierna(rig: Rig, p: PiernaLista, meta: Vector3)
	local m = rig.mundo
	local cadera, rodilla, pie = m[p.muslo].Position, m[p.rodilla].Position, m[p.pie].Position
	local hacia = meta - cadera
	local largo = math.clamp(hacia.Magnitude, math.abs(p.largo1 - p.largo2) + 0.01, p.largo1 + p.largo2 - 0.01)
	if hacia.Magnitude < 1e-3 then
		return
	end
	local dir = hacia.Unit
	-- La rodilla, hacia donde la tenía (si estaba recta, hacia delante).
	local fuera = (rodilla - cadera) - dir * (rodilla - cadera):Dot(dir)
	if fuera.Magnitude < 1e-3 then
		fuera = Vector3.new(0, 0, -1) - dir * -dir.Z
		if fuera.Magnitude < 1e-3 then
			fuera = Vector3.xAxis -- la pierna justo a lo largo de Z: a un lado
		end
	end
	local a = (p.largo1 * p.largo1 + largo * largo - p.largo2 * p.largo2) / (2 * largo)
	local alto = math.sqrt(math.max(0, p.largo1 * p.largo1 - a * a))
	local rodilla2 = cadera + dir * a + fuera.Unit * alto
	local pie2 = cadera + dir * largo
	local g1 = entre(rodilla - cadera, rodilla2 - cadera)
	m[p.muslo] = CFrame.new(cadera) * g1 * giro(m[p.muslo])
	local g2 = entre(g1 * (pie - rodilla), pie2 - rodilla2)
	m[p.rodilla] = CFrame.new(rodilla2) * g2 * g1 * giro(m[p.rodilla])
	m[p.pie] = CFrame.new(pie2) * giro(m[p.pie])
	poner(rig, p.muslo)
	poner(rig, p.rodilla)
	poner(rig, p.pie)
end

-- Pone los huesos según los Transform que tienen ahora los motores.
function Malla3D.mover(rig: Rig)
	local ahora: { [string]: CFrame } = {}
	local deltas: { [string]: CFrame } = {}
	local function delta(nombre: string): CFrame
		local d = deltas[nombre]
		if not d then
			d = giro(bloque(rig, nombre, ahora, false)) * giro(rig.reposo[nombre]):Inverse()
			deltas[nombre] = d
		end
		return d
	end
	for i, h in rig.huesos do
		local enPadre = if h.padre then rig.mundo[h.padre] else rig.enRaiz
		local base = enPadre * h.sitio
		local s = h.sigue
		local cf = base
		if s and s.a then
			local d = delta(s.a)
			if s.b then
				d = d:Lerp(delta(s.b), s.t or 0.5)
			end
			if s.f and s.f ~= 1 then
				d = CFrame.identity:Lerp(d, s.f)
			end
			-- Doblado a mano (el codo, que en los bloques no existe): un giro (eje por ángulo) en los ejes de su bloque.
			local doblado = rig.dobla[h.bone.Name]
			if doblado and doblado.Magnitude > 1e-4 then
				local eje = bloque(rig, s.a, ahora, false):VectorToWorldSpace(doblado.Unit)
				d = CFrame.fromAxisAngle(eje, doblado.Magnitude) * d
			end
			local pos = base.Position
			if s.desplaza then
				pos = h.pos0 + junta(rig, s.a, ahora, false) - junta(rig, s.a, nil, true)
			end
			cf = CFrame.new(pos) * d * h.giro0
		end
		rig.mundo[i] = cf
	end
	-- Toda la malla, para que el cuello caiga en la junta de su bloque (lo que diga `alinear`). Como los hijos cuelgan
	-- de los de arriba, basta con mover los de arriba del todo; `mundo` se mueve entero para el IK de después.
	local i = rig.cuello
	if i and rig.cuelloBloque and rig.alinear > 0 then
		local mueve = (junta(rig, rig.cuelloBloque, ahora, false) - rig.mundo[i].Position) * math.min(rig.alinear, 1)
		for j, cf in rig.mundo do
			rig.mundo[j] = cf + mueve
		end
	end
	for j in rig.huesos do
		poner(rig, j)
	end
	for _, p in rig.piernas do
		pierna(rig, p, bloque(rig, p.bloque, ahora, false) * p.planta + p.tobillo)
	end
	local cara = rig.cara
	if cara and rig.caraHueso then
		cara.CFrame = rig.raiz.CFrame * rig.mundo[rig.caraHueso] * rig.caraEn
	end
end

return Malla3D
