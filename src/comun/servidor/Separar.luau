-- Dos caras de bloques distintos en el mismo plano, mirando al mismo lado y solapadas parpadean entre las dos al
-- mover la cámara (esquinas de muros, peldaños, muebles hechos de piezas; pedido por el usuario arreglarlo). Tras
-- generar el mapa, Separar.caras busca esas parejas y agranda un poco una de las dos (CRECE studs en cada cara),
-- y repite hasta que no quede ninguna. Solo bloques anclados y sin girar de lado (los de los mapas grises).
local Separar = {}

local CRECE = 0.03 -- studs que crece cada cara de la pieza que se separa
local IGUAL = 0.02 -- caras más cerca que esto cuentan como el mismo plano
local CAJON = 0.1 -- studs de plano por cajón (para no comparar todas con todas)
local VUELTAS = 20 -- con los marcos de puertas y ventanas hacen falta más de 8

type Cara = { pieza: BasePart, plano: number, a0: number, a1: number, b0: number, b1: number }

-- El índice del eje (1 = X, 2 = Y, 3 = Z) si el vector va casi a lo largo de uno.
local function ejeDe(v: Vector3): number?
	local c = { v.X, v.Y, v.Z }
	for i = 1, 3 do
		if math.abs(math.abs(c[i]) - 1) < 1e-3 then
			return i
		end
	end
	return nil
end

-- Las caras de las piezas, por eje y lado ("1+", "2-"…) y dentro, por cajón del plano.
local function caras(piezas: { BasePart }): { [string]: { [number]: { Cara } } }
	local grupos = {}
	for _, p in piezas do
		local cf, s = p.CFrame, p.Size
		local medio = { 0, 0, 0 }
		local recto = true
		for k, v in { cf.RightVector, cf.UpVector, cf.LookVector } do
			local i = ejeDe(v)
			if not i then
				recto = false
				break
			end
			medio[i] = ({ s.X, s.Y, s.Z })[k] / 2
		end
		if not recto then
			continue
		end
		local c = { cf.X, cf.Y, cf.Z }
		for i = 1, 3 do
			local j, k = i % 3 + 1, (i + 1) % 3 + 1
			for _, lado in { 1, -1 } do
				local plano = c[i] + lado * medio[i]
				local grupo = `{i}{lado}`
				local cajon = math.floor(plano / CAJON)
				grupos[grupo] = grupos[grupo] or {}
				grupos[grupo][cajon] = grupos[grupo][cajon] or {}
				table.insert(grupos[grupo][cajon], {
					pieza = p, plano = plano,
					a0 = c[j] - medio[j], a1 = c[j] + medio[j], b0 = c[k] - medio[k], b1 = c[k] + medio[k],
				})
			end
		end
	end
	return grupos
end

local function chocan(A: Cara, B: Cara): boolean
	return A.pieza ~= B.pieza and math.abs(A.plano - B.plano) < IGUAL
		and math.min(A.a1, B.a1) - math.max(A.a0, B.a0) > 0.01 and math.min(A.b1, B.b1) - math.max(A.b0, B.b0) > 0.01
end

-- Separa las caras que coinciden entre las piezas de `carpeta`. Devuelve cuántas parejas quedan (0 si todo bien).
function Separar.caras(carpeta: Instance): number
	local piezas = {}
	for _, p in carpeta:GetDescendants() do
		if p:IsA("Part") and p.Shape == Enum.PartType.Block and p.Anchored and p.Transparency < 1 then
			table.insert(piezas, p)
		end
	end
	local quedan = 0
	for _ = 1, VUELTAS do
		local crecer: { [BasePart]: boolean } = {}
		quedan = 0
		for _, cajones in caras(piezas) do
			for cajon, lista in cajones do
				local siguiente = cajones[cajon + 1] or {} -- dos planos casi iguales pueden caer en cajones vecinos
				for x, A in lista do
					for y = x + 1, #lista + #siguiente do
						local B = if y <= #lista then lista[y] else siguiente[y - #lista]
						if chocan(A, B) then
							quedan += 1
							if not crecer[A.pieza] then
								crecer[B.pieza] = true
							end
						end
					end
				end
			end
		end
		if quedan == 0 then
			break
		end
		for p in crecer do
			p.Size += Vector3.one * (CRECE * 2)
		end
	end
	return quedan
end

return Separar
