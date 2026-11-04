# trepador: gateo del Trepador (esconderse agachado)

Archivo: `src/juego/cliente/TrepadorVista.luau` (solo cliente). Nada visto en Studio: comprobado con un banco de Lune
(Roblox de mentira, CFrame y Vector3 de verdad) que mira cada fotograma. El banco está en el scratchpad de la sesión
(`.../scratchpad/trepador/banco.luau`), fuera del repo; si hace falta, se rehace.

## Hecho

- **Gateo del Trepador** (pedido por el usuario: "que el monstruo pueda gatear si te huele… para pillarte debajo de
  sitios"). Con `Gatea` (Vector3) y `GateaHora` en su modelo:
  - Mide el tablero con rayos hacia arriba en 21 carriles (cada 0,75 studs, ±7,5: lo que abre las patas).
  - Si la cabeza (asoma 3,65) o las rodillas (aplastado, 2,9) le quedan sobre la mesa, primero se echa atrás (hasta 3
    studs) de golpe, como quien se aparta de un salto, con la cabeza derecha y la boca cerrada.
  - Se aplasta: el torso a 0,66 del suelo, las patas muy abiertas (6,8 de la cadera a la punta). Rodillas a 2,3-2,5.
  - Se cuela a tirones, la cabeza (del revés) a 0,7 del suelo y mirándote (frente a ~1,15 de ti), olfateando entre
    tirón y tirón. Mete la frente como mucho 2,6 por debajo del tablero.
  - Patas por la misma cinemática inversa (`pisar`): al aplastarse y entre tirones las mueve de dos en dos, en
    diagonal. Cada punta se apoya donde le toca con el torso a medio camino de lo que avanza mientras sigue ahí: no
    resbalan (< 0,02 studs por fotograma apoyadas). Las puntas que caerían bajo el tablero se agarran por fuera de él.
  - Al acabar saca la cabeza y se retira a donde se echó atrás; se levanta ahí y se queda retirado (`b.retiro`) hasta
    que vuelve a andar. Si no, al volver a su sitio metería la cabeza en el tablero.
  - Sin saltos: empieza desde lo que se veía el fotograma anterior (torso, puntas, cabeza y boca), también si llega
    otro gateo a medio levantarse.
  - Si te pilla (`rugir`): `b.agarra`, se queda aplastado 2,2 s chillando, con la boca abierta y temblando.
  - Ruidos: Paso y Cruje al aplastarse; Aranazo en cada tirón; al final, Chillido agudo cortado a 0,35 s. Pisadas
    agudas al apoyar cada par.
  - Con Rendimiento: avanza seguido, sin olfatear, sin pisadas, y solo los ruidos de aplastarse y del final.
- La vida de espera se pausa mientras gatea (`and not gateando`).
- Banco de Lune (32 casos, todos bien en 4 pasadas seguidas: la pose de espera tiene azar):
  - Mesas: comedor por el lado largo y por la punta; cocina por delante.
  - Distancias al borde: 1,8, 2,2 y 3. Diagonales: 27º, 45º en la esquina y dos con la raíz mirando al mueble (el marco
    gira).
  - Con y sin Rendimiento; cortado a 0,3 y 1,1 s; te pilla.
  - Resultado: sin NaN, nada atraviesa el suelo ni el tablero en ningún fotograma (al echarse, colarse, salir y
    levantarse), sin saltos de más de 0,7 studs por fotograma.

## Falta

- Probarlo en Studio (pasos abajo) y retocar a ojo: rapidez de los pasos al aplastarse (0,17 s cada par), cuánto abre
  las patas y lo agudo de las pisadas.
- Párrafo para `docs/sistemas/bichos.md` (lo pone el principal).

## Riesgos

- Su pose de espera de siempre ya atraviesa el tablero si el servidor le para cerca: la cabeza asoma 3,6 y la boca
  queda a ~2,9 del suelo. En el comedor, por el lado largo, el sitio donde se para (Caza `FUERA` 2,5 desde la zona
  Debajo) cae a ~1,1 del borde. El gateo lo quita en ~0,15 s (se echa atrás), pero esos primeros fotogramas aún
  atraviesan. Arreglo en otro archivo: `Fuera = 5` en las opciones del Trepador (`servidor/Trepador.luau`, `Caza.nuevo`).
- Los dedos (adornos de la punta) se meten ~0,43 en el suelo en su pose de siempre (pasaba ya antes). Aplastado no:
  apoya la punta a 0,55 y los dedos quedan a ras de suelo.
- Abierto mide unos 13 studs de punta a punta: las patas pueden atravesar sillas o muebles de al lado (el banco solo
  mira el tablero y el suelo). Por fuera del tablero no pisa las patas de la mesa ni los caballetes de la cocina.
- Si el servidor mueve la raíz durante el gateo, las puntas resbalan (se apoyan en un marco pegado a la raíz).
- Lune 0.10.5 construye mal `CFrame.lookAt` con vector de arriba propio: en las pruebas, `CFrame.fromMatrix`.

## Probar en Studio

1. Play. En el datamodel Server: `game.ServerStorage.Prueba:Fire("Noche")` y luego `Prueba:Fire("Trepador")`; esperar
   a que salga al salón por la chimenea (o ponerlo a mano: `workspace.Bichos.Trepador:PivotTo(...)`).
2. Gateo a mano (Server), con el Trepador quieto a ~2 studs del borde de la mesa del comedor (en (-25.5, 1, -15),
   tablero de 5,56 de ancho en x), de cara a ella:
   `local b = workspace.Bichos:FindFirstChild("Trepador"); b:SetAttribute("Gatea", Vector3.new(-25.5, 2.3, -15));`
   `b:SetAttribute("GateaHora", workspace:GetServerTimeNow())`. A los 2 s, poner los dos atributos a nil.
3. Mirar:
   - Desde debajo de la mesa, agachado a ~1 del suelo: se aplasta, la cabeza del revés a ras de suelo y de cara a ti.
   - Desde fuera: se echa atrás antes de aplastarse; las patas no resbalan; al acabar se levanta sin tocar el tablero.
   - Cocina: mesa en (-19.5, 1, 6.9), entrar por +Z, `Gatea = Vector3.new(-19.5, 2.3, 6.9)`.
4. Con Rendimiento (Ajustes): igual, más simple.
5. NaN (Client): `for _, p in workspace.Bichos:GetDescendants() do if p:IsA("BasePart") and p.Position.X ~= p.Position.X then print(p:GetFullName()) end end`.
6. De verdad: agacharse debajo de la mesa con el Trepador cazando en la casa (Caza le lleva al borde y gatea solo).
