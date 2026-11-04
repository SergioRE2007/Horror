-- Monedas que se ganan: por noche superada, por el final, por logros y el premio diario. Las cuentas, en Premio.
-- Todo en el servidor: no hay remote, el cliente solo ve el atributo "Monedas" y un aviso de una línea.
--   Amanecer: Director pasa cada cambio de fase (Recompensas.fase); cobran todos los que estén, vivos o muertos.
--   Final: Coche, al huir (Recompensas.final); Incendio, al quemar a la Bestia (Recompensas.finalBestia, también con
--   insignia de Config.Insignias). Diario: al entrar, en los dos lugares.
-- Lo ganado se guarda ya en los datos del jugador (Datos.guardar), aunque la partida no llegue a guardarse.
local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Lang = require(ReplicatedStorage.Shared.Lang)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Datos = require(script.Parent.Datos)
local Premio = require(script.Parent.Premio)

local R = Config.Recompensas
local Recompensas = {}

local ciclo = Premio.ciclo()
local dadas: { [number]: boolean } = {} -- UserId -> ya se le ha dado (o se le está dando) la insignia de un final

-- cuenta(datos) dice cuántas monedas da (y apunta lo que haga falta en los datos). Sin datos cargados no da nada.
-- El aviso, a los `retraso` s (las monedas, ya).
local function cobrar(jugador: Player, cuenta: (datos: any) -> number, texto: string, retraso: number?)
	local monedas = 0
	Datos.editar(jugador, function(datos)
		monedas = cuenta(datos)
		Premio.sumar(datos, monedas)
	end)
	if monedas > 0 then
		task.spawn(Datos.guardar, jugador)
		task.delay(retraso or 0, function()
			if jugador.Parent then
				Remotes.Aviso:FireClient(jugador, Lang.t(jugador, texto, { monedas = monedas }))
			end
		end)
	end
end

-- Cada cambio de fase del Ciclo (lo llama Director). Solo paga los amaneceres de verdad, una vez cada uno.
function Recompensas.fase(fase: string, noche: number)
	if not Premio.amanecer(ciclo, fase, noche) then
		return
	end
	local superada = noche - 1
	for _, jugador in Players:GetPlayers() do
		cobrar(jugador, function(datos)
			local total = Premio.noche(R, superada)
			for nombre, logro in R.Logros do
				if logro.Noche and superada >= logro.Noche then
					total += Premio.logro(datos, R, nombre)
				end
			end
			return total
		end, "You survived the night. +{monedas} coins")
	end
end

-- El final de la huida: cobran ya todos los que estén. El aviso sale cuando acaba la escena (`espera` s).
function Recompensas.final(espera: number)
	for _, jugador in Players:GetPlayers() do
		cobrar(jugador, function(datos)
			return Premio.final(datos, R, "Huida")
		end, "You escaped. +{monedas} coins", espera)
	end
end

-- La insignia de un final (Config.Insignias), si ya está creada (Id ~= 0). Una vez por jugador y servidor; si ya la
-- tenía, BadgeService no hace nada. Si falla (Roblox caído, Studio), se puede volver a intentar otra vez.
local function insignia(jugador: Player, id: number)
	if id == 0 or dadas[jugador.UserId] then
		return
	end
	dadas[jugador.UserId] = true
	task.spawn(function()
		local ok, fallo = pcall(BadgeService.AwardBadge, BadgeService, jugador.UserId, id)
		if not ok then
			dadas[jugador.UserId] = nil
			warn("[Recompensas] insignia " .. id .. ": " .. tostring(fallo))
		end
	end)
end

-- El final de la Bestia (Incendio, al quemarla): como el de la huida, con su logro y su insignia.
function Recompensas.finalBestia(espera: number)
	for _, jugador in Players:GetPlayers() do
		cobrar(jugador, function(datos)
			return Premio.final(datos, R, "Bestia")
		end, "You killed the Beast. +{monedas} coins", espera)
		insignia(jugador, Config.Insignias.Bestia)
	end
end

-- El tutorial acabado (juego/servidor/Tutorial): su logro, una vez por cuenta.
function Recompensas.tutorial(jugador: Player)
	cobrar(jugador, function(datos)
		return Premio.logro(datos, R, "Tutorial")
	end, "Tutorial complete. +{monedas} coins")
end

local function alEntrar(jugador: Player)
	while jugador.Parent and not jugador:GetAttribute("DatosListos") do
		task.wait(0.5)
	end
	cobrar(jugador, function(datos)
		return Premio.diario(datos, R, os.time())
	end, "Daily reward: +{monedas} coins")
end

function Recompensas.start()
	Players.PlayerAdded:Connect(alEntrar)
	for _, jugador in Players:GetPlayers() do
		task.spawn(alEntrar, jugador)
	end
end

return Recompensas
