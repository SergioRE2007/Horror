-- Banco de Muerte y la escena de muerte (14.9.2): el servidor dice qué bicho te pilla y la escena lo enfoca sin adivinar.
-- Ejecutar desde la raíz: lune run tests/bancos/muerte.luau (lo corre regressions.luau).
--   Servidor (Muerte de verdad): matar manda (jugador, cabeza, modelo) por el remote Muerte, devuelve si ha matado,
--   avisa una vez a los de Muerte.alMorir (también si muere de otra cosa) y vivo dice lo mismo que vivos. En un final
--   (Final de workspace) no te deja esconderte.
--   Cliente (MuerteVista de verdad, con las Vistas de mentira): con el modelo ruge ese bicho aunque otro tenga la cabeza
--   más cerca; sin modelo, el de la cabeza más cerca. Con Final y sin escena (el fuego del incendio corriendo) el
--   escondite es el de siempre y al salir vuelve la cámara; en la escena de un final (EscenaFinal) no toca la cámara al
--   salir del escondite ni al acabar el susto.
local crearMundo = require("./_roblox")

local cuentas = 0
local function igual(actual, esperado, etiqueta: string)
	assert(actual == esperado, `{etiqueta}: esperado {tostring(esperado)}, recibido {tostring(actual)}`)
	cuentas += 1
end

do -- El servidor.
	local m = crearMundo({ servidor = true })
	local g = m.global
	local Vector3, Instance = g.Vector3, g.Instance
	local Muerte = m.cargar("src/juego/servidor/Muerte")
	local remoto = m.cargar("src/shared/Remotes").Muerte -- en el servidor los crea Remotes (no el mundo)
	local function enviadosMuerte(): { any }
		return m.interno(remoto)._enviados or {}
	end
	Muerte.start()
	local muertes: { any } = {}
	Muerte.alMorir(function(j)
		table.insert(muertes, j)
	end)
	local todos = 0
	Muerte.alMorirTodos(function()
		todos += 1
	end)
	local a, b = m.jugador("A"), m.jugador("B")
	m.correr(0.2)
	igual(a.Character ~= nil and b.Character ~= nil, true, "servidor: los dos tienen personaje")
	local function enLista(j): boolean
		return table.find(Muerte.vivos(), j) ~= nil
	end
	igual(Muerte.vivo(a), true, "servidor: vivo")
	igual(Muerte.vivo(a), enLista(a), "servidor: vivo y vivos dicen lo mismo")
	igual(type(Muerte.sacar), "function", "servidor: Muerte.sacar para los finales")

	local bicho = Instance.new("Model")
	bicho.Name = "Golpeador"
	local cara = Vector3.new(1, 5, 2)
	igual(Muerte.matar(a, cara, bicho), true, "servidor: matar a un vivo")
	m.correr(0.1)
	local enviados = enviadosMuerte()
	local ultimo = enviados[#enviados]
	igual(ultimo and ultimo.quien, "todos", "servidor: el remote Muerte va a todos")
	igual(ultimo and ultimo[1], a, "servidor: con el jugador")
	igual(ultimo and ultimo[2], cara, "servidor: con la cabeza del bicho")
	igual(ultimo and ultimo[3], bicho, "servidor: con el modelo que le pilla")
	igual(Muerte.vivo(a), false, "servidor: muerto")
	igual(Muerte.vivo(a), enLista(a), "servidor: muerto, vivo y vivos dicen lo mismo")
	igual(#muertes, 1, "servidor: alMorir una vez (Died ve Muerto y no avisa otra)")
	igual(muertes[1], a, "servidor: alMorir con quien ha muerto")
	igual(Muerte.matar(a, cara, bicho), false, "servidor: matar a un muerto no hace nada")
	igual(#enviadosMuerte(), #enviados, "servidor: ni manda otra escena")
	igual(#muertes, 1, "servidor: ni avisa otra vez")

	-- Muere de otra cosa (sin bicho): también avisa, una vez.
	local hum = b.Character:FindFirstChildOfClass("Humanoid")
	hum.Health = 0
	m.correr(0.1)
	igual(b:GetAttribute("Muerto"), true, "servidor: de otra cosa, Muerto")
	igual(Muerte.vivo(b), false, "servidor: de otra cosa, ya no vivo")
	igual(#muertes, 2, "servidor: de otra cosa, alMorir también")
	igual(muertes[2], b, "servidor: de otra cosa, con quien ha muerto")
	igual(todos >= 1, true, "servidor: muertos todos, alMorirTodos")
	igual(Muerte.matar(b, cara), false, "servidor: muerto de otra cosa, matar no hace nada")

	-- Revive (amanecer o Revivir): vivo otra vez y sin aviso de muerte de más.
	Muerte.revivir(a)
	m.correr(0.2)
	igual(Muerte.vivo(a), true, "servidor: revivido")
	igual(Muerte.vivo(a), enLista(a), "servidor: revivido, vivo y vivos dicen lo mismo")
	igual(#muertes, 2, "servidor: revivir no avisa")
	-- Sin modelo (cualquiera que no lo sepa): el remote va igual, con el modelo en nil.
	igual(Muerte.matar(a, cara), true, "servidor: matar sin modelo")
	m.correr(0.1)
	local sin = enviadosMuerte()[#enviadosMuerte()]
	igual(sin[1] == a and sin[3] == nil, true, "servidor: sin modelo, el remote lleva nil")

	-- Esconderse: en un final no (la huida o el incendio ya prendido).
	Muerte.revivir(a)
	m.correr(0.2)
	local raizA = a.Character:FindFirstChild("HumanoidRootPart")
	local sitio = Instance.new("Model")
	sitio.Name = "Armario"
	local mando = m.caja(raizA.Position, Vector3.new(1, 1, 1), { Name = "Mando", Anchored = true })
	Instance.new("ProximityPrompt").Parent = mando
	mando.Parent = sitio
	local CFrame = g.CFrame
	sitio:SetAttribute("Ocupado", 0)
	sitio:SetAttribute("Dentro", CFrame.new(raizA.Position + Vector3.new(0, 0, 3)))
	sitio:SetAttribute("Vista", CFrame.new(raizA.Position + Vector3.new(0, 1.5, 3)))
	sitio:SetAttribute("Salida", CFrame.new(raizA.Position))
	sitio.Parent = m.workspace
	m.workspace:SetAttribute("Final", true)
	Muerte.esconder(a, sitio)
	igual(a:GetAttribute("Escondido"), nil, "servidor: en un final no se esconde")
	igual(sitio:GetAttribute("Ocupado"), 0, "servidor: en un final el escondite sigue libre")
	m.workspace:SetAttribute("Final", nil)
	Muerte.esconder(a, sitio)
	igual(typeof(a:GetAttribute("Escondido")), "CFrame", "servidor: sin final, sí se esconde")
	Muerte.sacar(a)
	igual(a:GetAttribute("Escondido"), nil, "servidor: y sale")
	igual(#m.errores, 0, "servidor: sin errores " .. table.concat(m.errores, "\n"))
end

do -- El cliente: la escena enfoca al bicho que dice el servidor.
	local m = crearMundo()
	local g = m.global
	local Vector3, CFrame, Instance, Enum = g.Vector3, g.CFrame, g.Instance, g.Enum
	local carpeta = Instance.new("Folder")
	carpeta.Name = "Bichos"
	carpeta.Parent = m.workspace
	local function bicho(nombre: string, donde: any): any
		local modelo = Instance.new("Model")
		modelo.Name = nombre
		local raiz = m.caja(donde - Vector3.new(0, 2, 0), Vector3.new(2, 2, 1), { Name = "HumanoidRootPart", CanCollide = false })
		raiz.Parent = modelo
		local cabeza = m.caja(donde, Vector3.new(1, 1, 1), { Name = "Cabeza", CanCollide = false })
		cabeza.Parent = modelo
		modelo.PrimaryPart = raiz
		modelo.Parent = carpeta
		return modelo
	end
	-- Las Vistas de mentira: cada una ruge solo con los suyos (como las de verdad: bichos[modelo]).
	local rugidos: { { vista: string, modelo: any } } = {}
	local suyos: { [string]: { [any]: boolean } } = {}
	local falsos: { [string]: any } = {}
	for _, n in { "Golpeador", "Raspador", "Trepador", "Imitador", "Acechador", "Bestia" } do
		suyos[n] = {}
		falsos[n .. "Vista"] = {
			rugir = function(_punto, modelo)
				if modelo and suyos[n][modelo] then
					table.insert(rugidos, { vista = n, modelo = modelo })
					return modelo
				end
				return nil
			end,
			candidatos = function()
				error("MuerteVista no debe pedir candidatos")
			end,
		}
	end
	local nada = setmetatable({}, {
		__index = function()
			return function()
				return nil
			end
		end,
	})
	falsos.Sonido = setmetatable({ hay = function()
		return false
	end }, { __index = nada })
	falsos.CorrerVista = { recien = function()
		return math.huge
	end, cansancio = function()
		return 0
	end, jadear = function() end }
	local MuerteVista = m.cargar("src/juego/cliente/MuerteVista", falsos)
	MuerteVista.start()
	m.correr(0.2)

	-- Un Golpeador con la cabeza justo en la boca del hueco y, algo más lejos, el Raspador que gateaba y te pilla.
	local boca = Vector3.new(0, 1.5, -6)
	local golpeador = bicho("Golpeador", boca + Vector3.new(2, 0, 0))
	local raspador = bicho("Raspador", boca + Vector3.new(0, -0.6, 2.5))
	suyos.Golpeador[golpeador] = true
	suyos.Raspador[raspador] = true
	m.jugadorLocal:SetAttribute("Muerto", true)
	m.alCliente("Muerte", m.jugadorLocal, boca, raspador)
	m.correr(0.4)
	igual(#rugidos, 1, "cliente: ruge uno solo")
	igual(rugidos[1] and rugidos[1].modelo, raspador, "cliente: con el modelo, ruge ese aunque otro esté más cerca")
	igual(rugidos[1] and rugidos[1].vista, "Raspador", "cliente: y lo anima su Vista")
	-- Delante de su cara (a lo largo de su LookVector) y casi en su eje. Solo la posición: el CFrame.lookAt de Lune
	-- 0.10.5 sale del revés (mira hacia -Z cuando tendría que mirar hacia +Z) y la dirección de la cámara no vale aquí.
	local function delanteDe(modelo: any): boolean
		local c = modelo.Cabeza.CFrame
		local d = m.camara.CFrame.Position - c.Position
		local fondo = d:Dot(c.LookVector)
		local lado = (d - c.LookVector * fondo).Magnitude
		return fondo > 2 and fondo < 7 and lado < 1
	end
	igual(delanteDe(raspador), true, "cliente: la cámara, delante de la cara del que te pilla")
	igual(delanteDe(golpeador), false, "cliente: y no delante del que tenía la cabeza más cerca")
	m.correr(4)
	igual(m.camara.CameraType, Enum.CameraType.Custom, "cliente: después del susto, la cámara vuelve")

	-- Sin modelo (no ha llegado): el de la cabeza más cerca.
	rugidos = {}
	m.alCliente("Muerte", m.jugadorLocal, boca, nil)
	m.correr(0.4)
	igual(rugidos[1] and rugidos[1].modelo, golpeador, "cliente: sin modelo, el de la cabeza más cerca")
	m.correr(4)

	-- Final sin escena (el fuego del incendio corre, ~17 s antes de la escena; o se cancela): el escondite es el de
	-- siempre y al salir vuelve la cámara (se quedaba congelada en Scriptable).
	m.jugadorLocal:SetAttribute("Muerto", nil)
	m.correr(0.2)
	m.workspace:SetAttribute("Final", true)
	local vista = CFrame.new(0, 3, 0)
	m.jugadorLocal:SetAttribute("Escondido", vista)
	m.correr(0.6)
	igual(m.camara.CameraType, Enum.CameraType.Scriptable, "cliente: con Final y sin escena, cámara del escondite")
	igual((m.camara.CFrame.Position - vista.Position).Magnitude < 0.5, true, "cliente: con Final, la cámara va al escondite")
	m.jugadorLocal:SetAttribute("Escondido", nil)
	m.correr(0.1)
	igual(m.camara.CameraType, Enum.CameraType.Custom, "cliente: con Final y sin escena, al salir vuelve la cámara")
	m.workspace:SetAttribute("Final", nil) -- el fuego se cancela

	-- La escena de un final (la huida o el incendio llevan la cámara): al salir del escondite no se pone en Custom.
	m.jugadorLocal:SetAttribute("Escondido", vista)
	m.correr(0.3)
	igual(m.camara.CameraType, Enum.CameraType.Scriptable, "cliente: escondido, cámara del escondite")
	m.workspace:SetAttribute("Final", true)
	m.jugadorLocal:SetAttribute("EscenaFinal", true) -- lo que ponen HuidaVista e IncendioVista
	m.camara.CameraType = Enum.CameraType.Scriptable -- la de la escena
	local escena = CFrame.new(50, 20, 50)
	m.camara.CFrame = escena
	m.correr(0.1)
	igual(m.camara.CFrame == escena, true, "cliente: en un final, el escondite no mueve la cámara")
	m.jugadorLocal:SetAttribute("Escondido", nil)
	m.correr(0.1)
	igual(m.camara.CameraType, Enum.CameraType.Scriptable, "cliente: en un final, al salir no se pone en Custom")

	-- Te pillan justo antes de la escena y empieza durante el susto: al acabarlo no le quita la cámara.
	m.jugadorLocal:SetAttribute("EscenaFinal", nil)
	m.camara.CameraType = Enum.CameraType.Custom
	m.jugadorLocal:SetAttribute("Muerto", true)
	m.alCliente("Muerte", m.jugadorLocal, boca, raspador)
	m.correr(0.4)
	m.jugadorLocal:SetAttribute("EscenaFinal", true)
	m.correr(4)
	igual(m.camara.CameraType, Enum.CameraType.Scriptable, "cliente: el susto acaba en la escena y no la corta")
	m.jugadorLocal:SetAttribute("EscenaFinal", nil)
	igual(#m.errores, 0, "cliente: sin errores " .. table.concat(m.errores, "\n"))
end

print(`muerte: {cuentas} comprobaciones bien`)
