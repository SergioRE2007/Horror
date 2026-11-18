-- Lo que tenían copiado igual las Vistas de los bichos (Golpeador, Raspador, Trepador, Imitador, Acechador y Bestia):
-- cuentas pequeñas, el vaho y las cuentas del gateo. Solo lo que era idéntico; lo que cambiaba de una a otra va por
-- parámetro (los números de cada bicho se quedan en su Vista) o se ha quedado en su Vista.
-- Librería sin start(): la usa cada Vista.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local BichoComun = {}

BichoComun.azar = Random.new()

-- Un número al azar entre r[1] y r[2].
function BichoComun.rango(r: { number }): number
	return BichoComun.azar:NextNumber(r[1], r[2])
end

-- De `actual` hacia `meta`, `rapidez` por segundo (sin pasarse).
function BichoComun.acercar(actual: number, meta: number, dt: number, rapidez: number): number
	return actual + (meta - actual) * math.min(1, dt * rapidez)
end

-- Suave al empezar y al acabar (0..1, con tope).
function BichoComun.suave(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

-- Lo mismo sin tope (Golpeador, Raspador y Trepador: siempre lo llaman con 0..1).
function BichoComun.suaveSinTope(u: number): number
	return u * u * (3 - 2 * u)
end

-- Por el suelo: sin la altura.
function BichoComun.plano(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Una crispación: sube de golpe en `sube` s y se apaga (0..1); pasados `fin` s, nada.
function BichoComun.crispacion(t: number, fin: number, sube: number): number
	if t < 0 or t > fin then
		return 0
	end
	local x = t / sube
	return x * math.exp(1 - x)
end

-- Como CuerpoVista: dentro de la casa no se ve el vaho.
function BichoComun.dentroDeCasa(p: Vector3): boolean
	local c = Config.Casa
	return math.abs(p.X) < c.MedioX and math.abs(p.Z) < c.MedioZ and p.Y < 28
end

-- El bicho (de los de una Vista) con la raíz más cerca de `punto`, si hay alguno a menos de `maximo`.
function BichoComun.cercano<B>(bichos: { [Model]: B }, punto: Vector3, maximo: number?): B?
	local mejor, distancia = nil, maximo or math.huge
	for _, b in bichos do
		local d = ((b :: any).raiz.Position - punto).Magnitude
		if d < distancia then
			mejor, distancia = b, d
		end
	end
	return mejor
end

------------------------------------------------------------------------------------------------------------------------
-- El vaho.

-- De noche, cerca y sin Rendimiento (Imitador, Acechador y Bestia).
function BichoComun.puedeVaho(distancia: number, lejos: number): boolean
	return distancia < lejos
		and workspace:GetAttribute("Fase") == "Noche"
		and Players.LocalPlayer:GetAttribute("Rendimiento") ~= true
end

-- Cómo es el vaho de cada bicho (lo demás es igual en todos). `Abre`: SpreadAngle; `Sube`: lo que sube (Acceleration);
-- `Giro`: con él, cada partícula sale girada y gira hasta esto por segundo; `Delante`: sale por el frente del punto.
export type Vaho = {
	Transparencia: number,
	Tam: { number },
	Vida: { number },
	Rapidez: { number },
	Abre: number,
	Sube: number,
	Freno: number,
	Giro: number?,
	Delante: boolean?,
}

-- El emisor del vaho (sin colgar): Rate 0, se echa con Emit.
local function emisor(v: Vaho): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.LightInfluence = 1 -- de noche apenas se ve: con la linterna o alguna luz
	e.Color = ColorSequence.new(Color3.fromRGB(215, 220, 228))
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, v.Transparencia), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, v.Tam[1]), NumberSequenceKeypoint.new(1, v.Tam[2]) })
	e.Lifetime = NumberRange.new(v.Vida[1], v.Vida[2])
	e.Speed = NumberRange.new(v.Rapidez[1], v.Rapidez[2])
	e.SpreadAngle = Vector2.new(v.Abre, v.Abre)
	if v.Giro then
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-v.Giro, v.Giro)
	end
	if v.Delante then
		e.EmissionDirection = Enum.NormalId.Front
	end
	e.Acceleration = Vector3.new(0, v.Sube, 0)
	e.Drag = v.Freno
	e.Rate = 0
	return e
end

-- El vaho de la cabeza de `b` (Imitador, Acechador y Bestia): un punto en ella, en `donde`, que se hace la primera vez
-- y se guarda en b.vaho (las partículas se quedan donde salen).
function BichoComun.vahoDe(b: any, donde: Vector3, v: Vaho): ParticleEmitter
	if b.vaho and b.vaho.Parent then
		return b.vaho
	end
	local a = Instance.new("Attachment")
	a.Name = "Vaho"
	a.Position = donde
	local e = emisor(v)
	e.Parent = a
	a.Parent = b.cabeza
	b.vaho = e
	return e
end

-- Golpeador, Raspador y Trepador: un solo punto suelto (en Terrain) por bicho, `nombre`, que se mueve a la boca cada
-- vez. Echa `cuantas` partículas desde `desde` hacia `hacia` (unitario).
local sueltos: { [string]: { punto: Attachment, emisor: ParticleEmitter } } = {}
function BichoComun.echarVaho(nombre: string, v: Vaho, desde: Vector3, hacia: Vector3, cuantas: number)
	local s = sueltos[nombre]
	if not s then
		local a = Instance.new("Attachment")
		a.Name = nombre
		a.Parent = workspace.Terrain
		local e = emisor(v)
		e.Parent = a
		s = { punto = a, emisor = e }
		sueltos[nombre] = s
	end
	-- Sale por el eje Y del punto.
	s.punto.WorldCFrame = CFrame.lookAt(desde, desde + hacia) * CFrame.Angles(-math.pi / 2, 0, 0)
	s.emisor:Emit(cuantas)
end

------------------------------------------------------------------------------------------------------------------------
-- Las cuentas del gateo.

-- Lo que dura un gateo (Config.Postura.Gatear).
function BichoComun.duraGateo(): number
	local reglas = Config.Postura
	return if reglas and reglas.Gatear then reglas.Gatear else 2
end

-- Golpeador y Trepador: por dónde va el gateo en `u` (en segundos de un gateo de 2 s): cuánto ha metido la cabeza
-- (0..1), cuánto olfatea (0..1, entre tirones) y el empujón de cada tirón (0..1). `gateo`: su Cae (segundos en echarse)
-- y sus Tirones ({empieza, acaba, hasta dónde}); `tiron`: cómo va cada tirón de 0 a 1. Simple (Rendimiento): seguido,
-- sin olfatear.
function BichoComun.avanceGateo(
	u: number,
	simple: boolean,
	gateo: { Cae: number, Tirones: { { number } } },
	tiron: (number) -> number
): (number, number, number)
	if simple then
		return BichoComun.suaveSinTope(math.clamp((u - gateo.Cae) / (1.75 - gateo.Cae), 0, 1)), 0, 0
	end
	local a = 0
	for _, t in gateo.Tirones do
		if u >= t[2] then
			a = t[3]
		elseif u > t[1] then
			local k = (u - t[1]) / (t[2] - t[1])
			return a + (t[3] - a) * tiron(k), 0, math.sin(math.pi * k)
		else
			break
		end
	end
	return a, if u > gateo.Cae then 1 else 0, 0
end

return BichoComun
