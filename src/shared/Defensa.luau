-- Reglas de las ventanas y puertas de la casa cuando un bicho golpea. Sin nada de Roblox, para probarlo con Lune.
-- El estado de cada una es una tabla (la guarda juego/servidor/Casa) y el tiempo llega de fuera (`ahora`).
--   Ventana: persiana bajada (protege cuando ha terminado de bajar), vida de la persiana y grietas del cristal.
--   Puerta: abierta o cerrada y su vida.
-- El Golpeador golpea: si lo de delante protege, le quita vida; si no, agrieta el cristal y al romperlo entra.
-- Si alguien abre la persiana o la puerta mientras golpea, entra en el siguiente golpe (pedido por el usuario).
local Defensa = {}

export type Estado = {
	tipo: string, -- "Ventana" o "Puerta"
	vida: number,
	vidaMax: number,
	persiana: boolean, -- ventana: bajada
	listaEn: number, -- ventana: cuándo termina de bajar
	cristal: number, -- ventana: 0 entero ... GolpesCristal roto
	abierta: boolean, -- puerta
	bloqueada: boolean, -- puerta cerrada con llave
	refuerzo: boolean, -- con un tablón reforzado clavado: más vida hasta que la rompan
	cambio: number, -- última vez que se tocó (para no tocarla a medio mover)
	atacada: boolean,
	abiertaEnAtaque: boolean,
}

function Defensa.nueva(tipo: string, cfg): Estado
	local vidaMax = if tipo == "Puerta" then cfg.VidaPuerta else cfg.VidaPersiana
	return {
		tipo = tipo,
		vida = vidaMax,
		vidaMax = vidaMax,
		persiana = false,
		listaEn = 0,
		cristal = 0,
		abierta = false,
		bloqueada = false,
		refuerzo = false,
		cambio = -math.huge,
		atacada = false,
		abiertaEnAtaque = false,
	}
end

-- ¿Lo de delante para al bicho ahora mismo?
function Defensa.protegida(e: Estado, ahora: number): boolean
	if e.tipo == "Puerta" then
		return not e.abierta and e.vida > 0
	end
	return e.persiana and e.vida > 0 and ahora >= e.listaEn
end

-- Clava un tablón reforzado (`factor` = Config.Taller.Refuerzo): la deja como nueva y con más vida. false si ya lo está.
function Defensa.reforzar(e: Estado, cfg, factor: number): boolean
	if e.refuerzo then
		return false
	end
	e.refuerzo = true
	e.vidaMax = Defensa.nueva(e.tipo, cfg).vidaMax * factor
	e.vida = e.vidaMax
	e.cristal = 0
	return true
end

-- Rota del todo, pierde el refuerzo (los tablones saltan).
local function sinRefuerzo(e: Estado, cfg)
	if e.vida <= 0 and e.refuerzo then
		e.refuerzo = false
		e.vidaMax = Defensa.nueva(e.tipo, cfg).vidaMax
	end
end

-- Un golpe del bicho. Devuelve qué ha pasado: "Persiana", "PersianaRota", "Grieta", "Puerta" o "Entra".
function Defensa.golpe(e: Estado, ahora: number, dano: number, cfg): string
	if Defensa.protegida(e, ahora) then
		e.vida = math.max(0, e.vida - dano)
		sinRefuerzo(e, cfg)
		if e.tipo == "Puerta" then
			if e.vida == 0 then
				e.abierta = true
				return "Entra" -- echa la puerta abajo
			end
			return "Puerta"
		end
		if e.vida == 0 then
			e.persiana = false
			return "PersianaRota"
		end
		return "Persiana"
	end
	if e.tipo == "Puerta" then
		return "Entra"
	end
	if e.abiertaEnAtaque then
		e.cristal = cfg.GolpesCristal
	else
		e.cristal = math.min(cfg.GolpesCristal, e.cristal + 1)
	end
	return if e.cristal >= cfg.GolpesCristal then "Entra" else "Grieta"
end

-- Subir o bajar la persiana. false si no se puede (rota o aún moviéndose).
function Defensa.persiana(e: Estado, ahora: number, cfg): boolean
	if e.tipo ~= "Ventana" or e.vida <= 0 or ahora < e.cambio + cfg.TiempoPersiana then
		return false
	end
	e.cambio = ahora
	if e.persiana then
		e.persiana = false
		if e.atacada then
			e.abiertaEnAtaque = true
		end
	else
		e.persiana = true
		e.listaEn = ahora + cfg.TiempoPersiana
	end
	return true
end

-- Abrir o cerrar la puerta. false si no se puede (con llave, rota o aún moviéndose).
function Defensa.puerta(e: Estado, ahora: number, cfg): boolean
	if e.tipo ~= "Puerta" or e.bloqueada or e.vida <= 0 or ahora < e.cambio + cfg.TiempoPuerta then
		return false
	end
	e.cambio = ahora
	e.abierta = not e.abierta
	if e.abierta and e.atacada then
		e.abiertaEnAtaque = true
	end
	return true
end

-- El bicho entra: rompe del todo lo que haya.
function Defensa.romper(e: Estado, cfg)
	e.vida = 0
	sinRefuerzo(e, cfg)
	if e.tipo == "Puerta" then
		e.abierta = true
	else
		e.persiana = false
		e.cristal = cfg.GolpesCristal
	end
end

function Defensa.necesitaReparar(e: Estado): boolean
	return e.vida < e.vidaMax or e.cristal > 0
end

-- Deja la persiana (subida) y el cristal, o la puerta, como nuevos.
function Defensa.reparar(e: Estado)
	e.vida = e.vidaMax
	e.cristal = 0
end

return Defensa
