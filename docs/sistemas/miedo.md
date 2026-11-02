# Más miedo (paso 14.3)

Hecho en paralelo con cuatro agentes (pedido por el usuario: "tiene que quedar bien"). Números a ojo en `Config.Latas`, `Config.LatasVista`, `Config.Efectos`, `Config.EfectosCasa`, `Config.AmbienteMiedo` y `Config.Sustos`.

## Trampas de latas (`servidor/Latas`, `cliente/LatasVista`)

- 13 cuerdas con 5-8 latas oxidadas (y alguna botella o trapo) entre estacas, a 78-84 studs del centro, en el borde del claro: los bichos salen a ~75 de su ventana y cruzan una línea unos 35 studs antes de llegar. La 13 va alta sobre la carretera (el coche pasa por debajo; solo la tocan los bichos). Ninguna estorba la carretera, el coche, el caballete, el cobertizo ni la trampilla. Sin colisión ni `CanQuery`. Van en `workspace.Mapa.Latas`.
- El servidor mira cada 0,2 s a los bichos (`Caza.todos`) y a los jugadores vivos: si cruzan una línea (segmento entre la posición anterior y la de ahora) o se acercan a 2,5 studs, `Remotes.Latas:FireAllClients("Suena", n, fuerza, donde)`. Los jugadores suenan más flojo (así el Imitador, que suena fuerte, se delata).
- Cliente: latas como péndulos amortiguados, cuerda que vibra, tintineo en 3D desde el punto de la cuerda y ecos más flojos. Vaivén leve con el viento, sin sonido.
- Prueba: `ServerStorage.Prueba:Fire("Latas", punto)` (sin punto, todas una tras otra).

## Avisos visuales sin cascos (`cliente/Efectos`, `cliente/CasaVista`)

- Algo llega a una ventana o puerta (a 18 studs de su sitio fuera): la cortina se hincha hacia dentro, el cristal vibra (`CristalVibra`), polvillo del marco; pegado al cristal, vaho de su aliento. En puertas, la hoja se comba como si empujaran.
- Pisadas cerca (45 studs): retumbo, temblor de cámara suave (nunca en cinemáticas; la Bestia tiene el suyo), vasos y tarros que tiemblan, cuadros que se tuercen (se quedan torcidos a propósito), lámparas colgantes que se balancean y bombillas que tiemblan (con `Ambiente.factor`, sin pisar a `DetallesVista`).
- Pisadas por encima (Trepador en el tejado o un bicho arriba): polvo y arenilla del techo justo debajo (`Polvo`). Probado: cae cada pocos pasos.
- Cristales: al romperse, los trozos se quedan en el suelo y picos en el marco hasta el amanecer o la reparación; crujen al pisarlos.

## Sustos (`cliente/Sustos/`)

- Cada jugador los suyos, solo en su cliente (el amigo no lo ha visto). El primero a los 45-80 s de la noche y luego uno cada 170-230 s (menos cada noche). Nunca con un bicho a menos de 90 studs (ni 20 s después), en cinemáticas, la noche final, muerto, escondido o con el móvil o la mochila abiertos, ni lejos de la casa. Todo vuelve a su sitio al amanecer.
- 12 sustos: Silueta (fuera de una ventana, se aparta al mirarla), Pasillo (figura pálida al fondo con la linterna), Susurro (desde la noche 4, a veces algo detrás), Pasos en el otro piso con polvo, Pared (algo araña dentro), Portazo, Cuadro que cae, Bombilla que revienta, Juguetes del cuarto de los niños, Cristal (golpecitos y una mano de sangre por fuera), Espejo (escrito con sangre: "Get out of here", "He knew", "Behind you") y Goteo de sangre del techo.
- Prueba (datamodel Client): `game.Players.LocalPlayer.PlayerScripts:FindFirstChild("Sustos", true).Lanzar:Fire("Silueta")`; `"Alba"` lo devuelve todo.

## Ambiente (`cliente/AmbienteMiedo`)

- De noche dentro de la casa, `CasaFondo` en bucle bajo. `Tension`: zumbido grave que sube con un bicho cerca (el Imitador no cuenta hasta que le abren, para no delatarlo). Ráfagas (`Rafaga`) contra una ventana cercana cada 35-90 s. Papel al abrir una pista (`PistasUi`).

## Sonidos (tanda `miedo`)

- `tools/sonidos/generar.mjs` (tanda `miedo`) y `tools/sonidos/miedo.json` (Tension y CasaFondo compuestos con `componer.mjs`: no salen de ElevenLabs). Página: `Documents\Roblox\sonidos-terror\miedo\escuchar.html`; ids en su `ids.json`.
- Hechos: Latas, PuertaGolpe, CuadroCae, PasosArriba, Papel, Tension y CasaFondo (puesta la versión que recomendó Claude; falta que elija el usuario).
- Sin hacer por falta de créditos de ElevenLabs (se recargan hacia el 08-11-2026): Susurro, Toc, Aranazo, Sobresalto, Polvo, CristalVibra, Retumbo y Rafaga; mientras, ids de otros sonidos. Faltan también `CristalPisa`, `CajaMusica` y `BombillaRevienta`.

## Pendiente

- Imagen de la mano de sangre (ahora hecha con marcos, se ve de dibujo): texto para ChatGPT en el informe del paso.
- Que Sergio juegue una noche con cascos y sin ellos.
