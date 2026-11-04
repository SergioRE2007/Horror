# Esconderse agachado: los bichos (Caza y Bestia)

Pedido por el usuario (03-11-2026): "agacharte también debería servir para esconderte, por ejemplo debajo de mesas, y que el monstruo pueda gatear si te huele… que sea útil agacharte es la finalidad". Archivos: `src/juego/servidor/Caza.luau` y `src/juego/servidor/Bestia.luau`.

## Hecho

- `Caza.elegirPresa`: a quien no está en un armario o cama le ve a `PosturaReglas.alcanceVista(Vista, Agachado, Cubierto)` y le oye a `alcanceOido(8, …)`. Debajo de un mueble (`Cubierto`) solo se le nota muy de cerca y solo desde su misma parte del mapa (los dos dentro de la casa o los dos fuera, y en su planta). Cada bicho lleva su `olor` de cada uno (`PosturaReglas.oler`, con el dt de verdad entre vueltas, 0,5 s como mucho de una vez). Con `huele(olor)` es presa y el destino es el borde del mueble. Si le vio u oyó meterse hace menos de `VioEsconderse` (o le nota ahora), lo sabe al momento (`olor = Huele`). Devuelve un tercer valor, `Debajo` (zona, borde, cara).
- `Caza.borde` (pura): por dónde se mete. Lados de la zona, frente a él y corriéndose a lo largo cada stud (entre sillas no cabe), a 1 stud de las esquinas; antes lo más cercano a él y, si empatan, lo que pilla de camino al bicho. `sitioLibre` lo valida con rayos que respetan `CanCollide` (ven las cajas Choque de muebles y sillas). Del medio del hueco a pasado el borde, nada (nunca a través de una pared). A ±1,3 de lado, nada (cabe de ancho). En el borde hay suelo y nada encima.
- `Caza.aPorDebajo`: va al borde (`pasoHacia` o el `ir` de la Bestia). Al llegar (a 3) gatea; si en 4 s no se acerca, le deja (y vuelve a olerle desde cero) y apunta ese borde en `sinSalida`, para que la próxima vez pruebe por otro sitio.
- `Caza.gatear`: parado, de cara a él, `AutoRotate` apagado. Atributos en el modelo: primero `GateaHora` (`GetServerTimeNow`) y luego `Gatea` (Vector3: dónde está él). Cada 0,1 s mira si sigue debajo de esa zona, o fuera a menos de 6 del borde sin nada en medio. A los `Config.Postura.Gatear` s: `Muerte.matar(presa, punto)`, con el punto en la boca del hueco, bajo. Lo deja si se escapa, si le aturden, si amanece o si se quita. Los atributos vuelven a nil siempre (pcall); si lo quitan con `task.cancel`, el modelo se destruye, salvo en `Bestia.quemar`, que los quita a mano.
- `Caza.cazar` y la Bestia (`perseguir`, `cazar`, `encerrada`) usan lo mismo. La Bestia se para a 3 del mueble (los demás, a 2,5) y su olfato propio (`oler`, a 25) ya no cuenta a los que están debajo de algo.
- Prueba sin Roblox de `Caza.borde` y `enZona` (72 comprobaciones, mesas del comedor y de la cocina incluidas): está en el scratchpad de la sesión y no en `tests/` (ver "Falta").

## Falta

- Hecho (04-11-2026): la prueba de `Caza.borde` está en `tests/regressions.luau` (sacada del texto de `Caza.luau`), con mueble girado y lado corto; también `alcanceOido` nunca más que el oído.
- Hecho: los números a ojo están en `Config.Postura` (al final: `Oido`, `Fuera`, `FueraBestia`, `CercaBorde`, `SeEscapa`, `Atasco`, `MaxOlor`, `Ancho`, y nuevo `SinSalida` 20), con los mismos valores.
- Hecho, casos raros: `sinSalida` es una lista de como mucho 3 bordes que se olvidan a los `SinSalida` s (antes era uno para siempre: un mueble con un solo lado libre quedaba seguro para siempre si una vez no llegó). El atasco cuenta aunque él se mueva un poco debajo (antes `rumbo ~= borde` lo reiniciaba). Dos bichos no gatean en el mismo borde (`gateaEn`: el segundo busca otro lado o espera). Dentro de la zona solo le alcanza si no hay nada que choque desde la boca del hueco (nunca a través de una pared) y `Mapa` avisa en la Salida si una zona Debajo cruza algo que no sea una caja `Choque`. Revisado y bien: se va o muere a mitad (lo deja, sin apuntarle olor), personaje nuevo, bicho quitado, aturdido, amanecer, `Bestia.quemar` (quita también `gateaEn`).
- Banco con un Roblox de mentira y reloj simulado (9 casos: pilla, se va, se escapa, dos bichos, sin salida, se mueve, pared, amanece): `scratchpad/caza/banco.luau` de la sesión (fuera del repo), `lune run` desde la raíz.
- Falta: probarlo en Studio (abajo). El olor y `vistoEn` de quien muere no se borran hasta que se va (si revive y se mete debajo en los segundos siguientes, ese bicho ya le huele): menor.

## Probar en Studio

1. Play. En la consola del servidor: `game.ServerStorage.Prueba:Fire("Noche")` y luego `game.ServerStorage.Prueba:Fire("Ataque", Vector3.new(-25.5, 1, -15))`, o `("Raspador", …)`, para que salga un bicho.
2. Agacharse debajo de la mesa del comedor (x -25,5, z -15) o de la de la cocina (x -19,5, z 6,9, entrando por +Z). Comprobar `Player:GetAttribute("Cubierto") == true`.
3. Con el bicho a menos de 14 studs, a los ~5 s debe ir al borde (comedor: el lado +X, hacia z -17,7, donde no hay silla que choque) y gatear. Mirar en el servidor `workspace.Bichos:GetChildren()[1]:GetAttribute("Gatea")` y `"GateaHora"`. A los 2 s, susto con la cara baja en la boca de la mesa.
4. Salir de debajo y alejarse más de 6 antes de los 2 s: los atributos vuelven a nil y sigue cazando (te persigue si te ve).
4b. Mirar la Salida al empezar: no debe salir "[Mapa] la zona Debajo de … cruza …" (si sale con algo que no es pared, como una alfombra que choca, es ruido: avisar).
4c. Con dos bichos (`Ataque` y `Raspador` a la vez), uno debajo de la mesa: no deben gatear los dos en el mismo sitio.
5. Meterse debajo a la vista del bicho: va al momento (sin esperar a olerte).
6. Bestia: `Prueba:Fire("Bestia")` y lo mismo dentro de la casa.

## Riesgos

- Un mueble sin ningún lado libre (paredes o sillas que chocan en los cuatro) es un escondite seguro. La mesa del comedor tiene libre solo el trozo de +X sin silla; si se mueven las sillas, mirarlo.
- Si una zona Debajo cruza una pared, ya no se pilla a través (rayo desde la boca) y Mapa avisa; pero el bicho iría y volvería a gatear cada pocos segundos. Las zonas deben quedarse dentro de su sala.
- El rayo de dentro de la zona da por escapado a quien tenga algo que choca entre él y la boca: si alguna vez se meten sillas que chocan debajo del tablero, mirarlo.
- El bicho puede subirse a una mesa baja si va recto (es como ya pasaba). Si no llega al borde, a los 4 s le deja.
- Sin probar en Studio: el gateo, el olor y los rayos con las sillas de verdad.
