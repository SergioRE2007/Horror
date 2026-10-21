-- Candado de sesión del guardado: que una partida solo la escriba el servidor que la tiene abierta, para que no se
-- pueda duplicar nada saliendo de un servidor y entrando deprisa en otro. Sin nada de Roblox dentro (el DataStore,
-- el reloj y la espera se le pasan), para probarlo con Lune simulando dos servidores (tests/regressions.luau).
-- Lo guardado en cada clave es { datos = ..., candado = { id, hora } }: id = la sesión que la tiene abierta (uno
-- nuevo cada vez que se carga) y hora = cuándo la renovó por última vez. Todo con UpdateAsync, nunca SetAsync.
-- Números en Config.Guardado. Detalle en docs/sistemas/datos.md.
local Candado = {}

export type Opciones = {
	almacen: any, -- un DataStore (o uno falso en las pruebas) con UpdateAsync
	clave: string,
	id: string, -- el de esta sesión
	ahora: () -> number, -- segundos de reloj de pared, iguales en todos los servidores (os.time)
	esperar: (segundos: number) -> (),
	config: { Reintento: number, Espera: number, Caduca: number },
	aviso: ((texto: string) -> ())?,
}

local function avisar(op: Opciones, texto: string)
	if op.aviso then
		op.aviso(`[Candado] {op.clave}: {texto}`)
	end
end

-- Coge la partida. Devuelve "ok" y sus datos (nil si es nueva), "ocupado" si otra sesión viva la tuvo cogida todo el
-- rato de Config.Guardado.Espera, o "error" si el DataStore falló todo ese rato. Un candado que lleva Caduca segundos
-- sin renovarse es de un servidor caído y se coge.
function Candado.cargar(op: Opciones): (string, any)
	local inicio = op.ahora()
	while true do
		local ocupado, datos = false, nil
		local ok, fallo = pcall(function()
			op.almacen:UpdateAsync(op.clave, function(actual)
				actual = if type(actual) == "table" then actual else {}
				local candado = actual.candado
				local vivo = type(candado) == "table"
					and candado.id ~= op.id
					and type(candado.hora) == "number"
					and op.ahora() - candado.hora < op.config.Caduca
				ocupado = vivo
				if vivo then
					return nil -- no escribe nada
				end
				datos = actual.datos
				return { datos = actual.datos, candado = { id = op.id, hora = op.ahora() } }
			end)
		end)
		if ok and not ocupado then
			return "ok", datos
		end
		if not ok then
			avisar(op, `no se pudo cargar: {fallo}`)
		end
		if op.ahora() - inicio + op.config.Reintento > op.config.Espera then
			return if ok then "ocupado" else "error", nil
		end
		op.esperar(op.config.Reintento)
	end
end

-- Escribe los datos si la partida sigue siendo de esta sesión, renovando el candado o soltándolo (`soltar`, al salir).
-- Devuelve "ok", "perdido" (otra sesión la tiene: no escribe nada, lo de este servidor está viejo) o "error" si el
-- DataStore falló en los `intentos`.
function Candado.guardar(op: Opciones, datos: any, soltar: boolean, intentos: number): string
	for intento = 1, intentos do
		local perdido = false
		local ok, fallo = pcall(function()
			op.almacen:UpdateAsync(op.clave, function(actual)
				local candado = if type(actual) == "table" then actual.candado else nil
				perdido = type(candado) ~= "table" or candado.id ~= op.id
				if perdido then
					return nil
				end
				return { datos = datos, candado = if soltar then nil else { id = op.id, hora = op.ahora() } }
			end)
		end)
		if ok then
			return if perdido then "perdido" else "ok"
		end
		avisar(op, `no se pudo guardar (intento {intento} de {intentos}): {fallo}`)
		if intento < intentos then
			op.esperar(op.config.Reintento)
		end
	end
	return "error"
end

return Candado
