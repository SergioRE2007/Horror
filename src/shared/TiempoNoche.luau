-- El tiempo de cada noche (docs/sistemas/cielo.md y tormenta.md): si hay tormenta seca o niebla cerrada. Cuentas puras,
-- sin Roblox más que Random, para que el cliente (TormentaVista, CieloVista) y el servidor (Caza: con niebla los bichos
-- tampoco ven lejos fuera) den lo mismo. La semilla sale de Noche y FaseInicio (atributos del workspace que pone
-- Ciclo), que llegan iguales a todos: lo ven todos igual, sin remote. Los números, en Config.Tormenta y
-- Config.Cielo.Niebla (se pasan como `cfg`); las tiradas (+ 104729 la de la niebla) no se cambian nunca: cambiarían
-- qué noches tienen qué tiempo.
local TiempoNoche = {}

local OTRA_TIRADA_NIEBLA = 104729 -- la tirada de la niebla, distinta de la de la tormenta con la misma semilla

-- La semilla de una noche.
function TiempoNoche.semilla(noche: number, inicio: number): number
	return (math.floor(inicio) % 2_147_000) * 1000 + math.floor(noche) % 1000
end

-- ¿Hay tormenta esta noche? Desde cfg.Desde, con cfg.Probabilidad (cfg = Config.Tormenta).
function TiempoNoche.hayTormenta(noche: number, inicio: number, cfg: any): boolean
	if noche < cfg.Desde then
		return false
	end
	return Random.new(TiempoNoche.semilla(noche, inicio)):NextNumber() < cfg.Probabilidad
end

-- La tirada de la niebla con una semilla ya hecha y sabiendo si hay tormenta (CieloVista la usa con las de
-- TormentaVista; el banco del cielo las cambia por unas falsas). Nunca con tormenta; desde cfg.Desde, con
-- cfg.Probabilidad (cfg = Config.Cielo.Niebla).
function TiempoNoche.nieblaCon(semilla: number, conTormenta: boolean, noche: number, cfg: any): boolean
	if noche < cfg.Desde or conTormenta then
		return false
	end
	return Random.new(semilla + OTRA_TIRADA_NIEBLA):NextNumber() < cfg.Probabilidad
end

-- ¿Hay niebla cerrada esta noche? `cfgNiebla` = Config.Cielo.Niebla, `cfgTormenta` = Config.Tormenta.
function TiempoNoche.hayNiebla(noche: number, inicio: number, cfgNiebla: any, cfgTormenta: any): boolean
	if noche < cfgNiebla.Desde then
		return false -- sin tirar la tormenta: las primeras noches nunca
	end
	return TiempoNoche.nieblaCon(
		TiempoNoche.semilla(noche, inicio),
		TiempoNoche.hayTormenta(noche, inicio, cfgTormenta),
		noche,
		cfgNiebla
	)
end

-- Hasta dónde ve un bicho con niebla cerrada (Caza.elegirPresa, después de PosturaReglas.vistaDeLado y antes de
-- alcanceVista). Solo si él o el jugador están fuera de la casa (`fuera`): `vista` por `k` (Config.Caza.Niebla.Vista),
-- sin bajar de `minimo` (Config.Postura.VerEspalda: de cerca te sigue viendo). Sin niebla o dentro, la misma.
function TiempoNoche.vistaConNiebla(vista: number, niebla: boolean, fuera: boolean, k: number, minimo: number): number
	if not niebla or not fuera then
		return vista
	end
	return math.max(vista * k, math.min(vista, minimo))
end

return TiempoNoche
