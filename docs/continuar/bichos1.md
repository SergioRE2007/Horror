# bichos1: Golpeador, Raspador y Trepador (vida de espera y gateo)

Archivos: `src/juego/cliente/GolpeadorVista.luau`, `RaspadorVista.luau`, `TrepadorVista.luau`. Todo en el cliente, moviendo
la Transform de sus Motor6D. Nada se ha visto en Studio: todo está comprobado con un banco de Lune que carga los módulos
con un Roblox de mentira y mira cada fotograma (NaN, suelo, cristal, tablero). El banco está en el scratchpad de la
sesión, fuera del repo: si hace falta, se rehace.

## Hecho

- **Vida mientras esperan** (pedido por el usuario: "los bichos con más vida mientras esperan"), con un bucle por
  Vista que solo corre mientras hay alguno, a menos de 120 studs (45 con Rendimiento) y vaho de noche fuera de la casa:
  - Golpeador: respira con rabia, se crispa, da tirones con la cabeza y reacciona a la mirilla. Antes de cada golpe se
    echa atrás y sube los brazos por los lados; las garras se hunden ~0,5 en la pared de encima de la ventana sin
    asomar por dentro.
  - Raspador: raspa paciente con las manos por cinemática y la cara ladeada contra el cristal. Con la linterna se
    encoge, recoge una mano y con la otra sigue arañando despacio; con el flash recoge las dos. Nada cruza el cristal.
  - Trepador: patas por cinemática inversa (no resbalan). Agazapado y nervioso; se para a escuchar (clavado, sin
    respirar, cabeza ladeada) y en el tejado cruje la madera. Bajando por el tiro se esconde en el cliente.
- Arreglado de paso:
  - NaN (`math.sin(inf)`) en las juntas del Golpeador y del Raspador hasta su primera sacudida o "cosa rara".
  - Los brazos del Golpeador atravesaban la pared al golpear.
  - Los dedos del Raspador atravesaban el cristal al alumbrarle, y su vaho no salía nunca.
- LEVE del revisor:
  - Raspador: solo mide el cristal a menos de `vidaLejos`, a destiempo si hay varios.
  - Raspador: a más de 250 studs para el chirrido.
  - Trepador: comprueba `Tiro` y `Hogar` de la chimenea antes de usarlos.
- **Gateo del Golpeador** (pedido por el usuario: "que el monstruo pueda gatear si te huele… para pillarte debajo
  de sitios"):
  - Con `Gatea` (Vector3) y `GateaHora` (hora del servidor) en su modelo, se dobla hasta el suelo a cuatro patas.
  - Su cara baja por fuera del borde y entra de lado, a ras de suelo (a 1,2 del suelo), mirándote; acaba a ~1,1 de ti.
  - Un brazo queda apoyado fuera y el otro barre por debajo, a tirones, parándose a olfatear.
  - Ruidos: Paso y Cruje al echarse y en cada tirón; Rugido grave cortado al final.
  - Al acabar, primero saca la cabeza y luego se levanta. Si te pilla (`rugir`), se queda en el suelo 2,2 s, durante
    el susto.
  - El borde se busca con rayos hacia arriba (tres en paralelo).
  - Comprobado con la mesa del comedor (hueco de 2,84, 2,8 de ancho) a 1,8, 2,2 y 3 studs del borde y en diagonal:
    ni suelo ni tablero.
  - Con Rendimiento: sin olfatear ni arañar, y solo los ruidos de echarse y del final.

## Falta

- Gateo del Raspador: se arrastra boca abajo despacio, con el cuello estirado y los brazos por cinemática 3D (el codo
  hacia fuera y arriba).
- Gateo del Trepador: se aplasta con las patas muy abiertas (rodillas por debajo de 2,5), primero se echa atrás si su
  cabeza o sus rodillas quedan sobre la mesa, y se cuela a tirones.
- Para los dos, seguir el mismo esquema que `gatear` en GolpeadorVista: el camino de la cara (fuera, abajo, dentro);
  probar con la mesa del comedor.
- Párrafo para `docs/sistemas/bichos.md` (lo pone el principal).

## Probar en Studio

1. Play. En el datamodel Server: `game.ServerStorage.Prueba:Fire("Noche")`.
2. Bichos:
   - Golpeador: `Prueba:Fire("Ataque", Vector3.new(25, 0, -40))` (ventanal del salón).
   - Raspador: `Prueba:Fire("Raspador", Vector3.new(25, 0, -40))`.
   - Trepador: `Prueba:Fire("Trepador")`.
3. Gateo a mano (Server), con el bicho dentro de la casa:
   `local b = workspace.Bichos:FindFirstChild("Golpeador"); b:SetAttribute("Gatea", Vector3.new(-25.5, 2, -15));`
   `b:SetAttribute("GateaHora", workspace:GetServerTimeNow())`. La mesa del comedor está en (-25.5, 1, -15). A los 2 s,
   poner los dos atributos a nil. Mirar desde debajo de la mesa a ~1 del suelo.
4. NaN (Client): `for _, p in workspace.Bichos:GetDescendants() do if p:IsA("BasePart") and p.Position.X ~= p.Position.X then print(p:GetFullName()) end end`.

## Riesgos

- De pie, el Golpeador tiene los brazos 1,4 por delante. Si el servidor le para a menos de ~1,8 del borde, sus brazos
  colgando ya se meten en el canto del tablero, antes y después de gatear.
- `Gatea` se toma como el punto del escondido. La cara mira a su altura, limitada entre 0,6 y 2 del suelo.
- Lune 0.10.5 construye mal `CFrame.lookAt` con vector de arriba propio: en las pruebas, `CFrame.fromMatrix`.
