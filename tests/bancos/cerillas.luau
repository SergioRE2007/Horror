-- Banco de las cerillas del final: están en la caja fuerte del rico (pista 12, docs/historia.md: "En la caja, las
-- cerillas"), no sueltas por la casa. Lee el código (no hace falta el Roblox de mentira):
--   ningún Mapa*.luau deja Cerillas entre los objetos sueltos;
--   Config.Bestia.PistaCerillas es la 12 y Pistas, al leerla por primera vez (antes de apuntarla), da Cerillas y avisa;
--   las frases nuevas están en LangEs y la vieja ("It must...") ya no está en ningún sitio.
-- Ejecutar desde la raíz: lune run tests/bancos/cerillas.luau (lo corre regressions.luau).
local fs = require("@lune/fs")

local cuentas = 0
local function bien(cond: any, que: string)
	assert(cond, "cerillas: " .. que)
	cuentas += 1
end

-- Todo lo que construye el mapa (Mapa, MapaAnexos, MapaBosque...): las cerillas vivían en construirFinal (MapaAnexos).
local SERVIDOR = "src/juego/servidor/"
local mapa = ""
for _, archivo in fs.readDir(SERVIDOR) do
	if string.match(archivo, "^Mapa.*%.luau$") then
		mapa ..= fs.readFile(SERVIDOR .. archivo)
	end
end
local pistas = fs.readFile("src/juego/servidor/Pistas.luau")
local incendio = fs.readFile("src/juego/servidor/Incendio.luau")
local config = fs.readFile("src/shared/Config.luau")
local langEs = fs.readFile("src/shared/LangEs.luau")

bien(not string.find(mapa, '{ "Cerillas"', 1, true), "Mapa ya no pone cerillas sueltas (estaban en la encimera)")
bien(string.find(config, "PistaCerillas = 12,", 1, true), "Config.Bestia.PistaCerillas es la caja fuerte (12)")

-- En Pistas.leer: se mira si es la primera vez antes de apuntarla, y luego se dan y se avisa.
local leer = string.match(pistas, "function Pistas%.leer.-\nend\n")
bien(leer, "Pistas.leer existe")
local antes = string.find(leer, "n == Config.Bestia.PistaCerillas and not leidas[n]", 1, true)
local apunta = string.find(leer, "leidas[n] = true", 1, true)
local da = string.find(leer, 'Mochila.dar(jugador, "Cerillas")', 1, true)
bien(antes and apunta and antes < apunta, "la primera lectura se mira antes de apuntarla (no se dan dos veces)")
bien(da and da > apunta, "da las cerillas al leer la caja fuerte")
bien(string.find(leer, 'Lang.t(jugador, "There are matches inside the safe.")', 1, true), "avisa de las cerillas")
bien(string.find(pistas, "require(script.Parent.Mochila)", 1, true), "Pistas carga Mochila")

-- Sin require circular: ni Mochila ni nada de lo que carga (siguiendo los require hasta el fondo) carga Pistas.
local vistos, pendientes = {}, { "Mochila" }
while #pendientes > 0 do
	local nombre = table.remove(pendientes) :: string
	if not vistos[nombre] then
		vistos[nombre] = true
		local fuente = fs.readFile(`{SERVIDOR}{nombre}.luau`)
		bien(not string.find(fuente, "require(script.Parent.Pistas)", 1, true), `{nombre} no carga Pistas`)
		for otro in string.gmatch(fuente, "require%(script%.Parent%.([%w_]+)%)") do
			table.insert(pendientes, otro)
		end
	end
end
bien(vistos.MapaAnexos and vistos.Mapa and vistos.Cargar, "se han seguido los require de Mochila (Mapa, MapaAnexos...)")

-- Textos: frases enteras con su español.
bien(string.find(incendio, '"She must be locked in the basement first."', 1, true), "Incendio la llama ella")
bien(not string.find(incendio .. langEs, "It must be locked", 1, true), "la frase vieja ya no está")
bien(
	string.find(langEs, '["She must be locked in the basement first."] = "Antes tiene que estar encerrada en el sótano."', 1, true),
	"su español en LangEs"
)
bien(
	string.find(langEs, '["There are matches inside the safe."] = "Dentro de la caja fuerte hay unas cerillas."', 1, true),
	"el aviso tiene su español"
)

print(`cerillas: {cuentas} comprobaciones`)
