# Compras con Robux (paso 10.4)

Precios a ojo, en `Config.Compras` (al final de `Config`). `Id = 0` = aún sin crear en Roblox: el botón sale apagado (en Studio con el modo de pruebas se hace como si se pagara, sin Roblox). Al publicar hay que crear los productos y pases con el precio de `Robux` y poner sus `Id`.

- `comun/servidor/Compras` (en los dos lugares) y sus cuentas en `Recibos` (sin Roblox, probadas con Lune).
- Remote `Compra`: `("Monedas", n)`, `("Pase", ventaja)` o `("Revivir", jugador)`. La compra la abre el servidor (`PromptProductPurchase`/`PromptGamePassPurchase`) después de validar; una petición por segundo.
- Productos: `ProcessReceipt` mira `datos.compras[PurchaseId]`; si es nueva la entrega y la apunta de una vez (`Recibos.apuntar`, guarda la hora y recuerda las `Recordadas` más nuevas). Solo responde `PurchaseGranted` cuando `Datos.guardar` ha guardado con la compra dentro; si no, Roblox vuelve a preguntar y no se da dos veces.
- Pases (pedido en el diseño: por ventajas, `perks`): al entrar se pregunta a Roblox (`UserOwnsGamePassAsync`, 3 intentos) y se publica `Pase<Ventaja>` en el Player. El aviso de compra del cliente se comprueba con Roblox antes de darlo. El código pregunta con `Stats.pase(jugador, "MochilaGrande")`, nunca por un pase concreto.
  - `MochilaGrande`: `Stats.mochila` → `Config.Mochila.Grande`. Si llega con la partida empezada, `Mochila` rehace la rejilla con lo que lleva.
  - `MasRanuras`: `Stats.ranuras` → 6 partidas (`Coches` lo valida, `CochesUi` enseña los botones).
  - `LinternaMejor`: ventajas `Pila` ×1,5 (`Equipo`) y `Luz` ×1,25 (alcance: lo que frena a un bicho en `Equipo` y lo que se ve en `EquipoVista`).
  - `PaqueteInicio`: `Regalo` de una vez (1000 monedas y la luz violeta), apuntado en `datos.regalos`.
- Revivir (`juego/servidor/Revivir`, botones en `juego/cliente/RevivirUi`): de noche, a ti o a otro muerto, una vez por noche cada uno (la noche cuenta aunque se repita al morir todos). Se apunta a quién antes de abrir la compra y se vuelve a mirar al pagar; si ya no se puede, `Config.Compras.Reembolso` monedas. Atributo `Revivible` del Player para los botones.
- Tienda del lobby: pestaña ROBUX con los pases ("TUYO" si lo tienes) y los paquetes de monedas.
- Modo de pruebas: `Config.Test.Pases = true` da todos los pases.

## Probado en Studio (22-10-2026)

- Lobby: paquete de 300 con 5 peticiones seguidas da 300 una vez; paquete de inicio +1000 y luz violeta una vez; pase ya tenido no se vuelve a pedir; paquete que no existe y revivir en el lobby se ignoran; pestaña ROBUX con "TUYO"; 6 ranuras con el pase. Sin errores.

## Sin probar (solo publicado)

- Compras de verdad: `ProcessReceipt` real, `PromptGamePassPurchaseFinished`, `UserOwnsGamePassAsync` y el guardado contra el DataStore real. Faltan los `Id` (crear productos y pases al publicar, paso 13.2).
