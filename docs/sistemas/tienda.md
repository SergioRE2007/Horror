# Tienda (paso 10.3)

Precios a ojo, en `Config.Clases` (`Precio`) y `Config.Cosmeticos` (al final de `Config`; se guarda el `Id`: no cambiarlo, lo nuevo al final).

- Mostrador al fondo de la tienda de la gasolinera (`Gasolinera`), con el prompt "Shop". Abre `lobby/cliente/TiendaUi` (rehecha en 14.7, pedido por el usuario): una libreta de espiral vieja con anillas, margen rojo, renglones, mancha de sangre y la marca de una taza, con tres separadores que asoman por la derecha (CLASES, LUCES y ROBUX). Lo tuyo lleva un sello rojo torcido (ELEGIDA, EN USO, TUYO) que se estampa al conseguirlo. Comprar con monedas pide dos toques ("¿COMPRAR?", que se olvida a los 4 s; un doble toque sin querer no cuenta). Llega con un fundido y un pequeño desliz; al cambiar de separador pasa una hoja con ruido de papel (también al cerrar, no al abrir). En el móvil, botones de un dedo y el papel medido con lo que cabe bajo la barra de Roblox. Se cierra con la X o al alejarse 16 studs.
- `comun/servidor/Tienda` (en los dos lugares) y sus cuentas en `Comprar` (sin Roblox, probadas con Lune). Remote `Tienda`, solo en el lobby: `("Clase", id)`, `("Cosmetico", id)` comprar; `("Poner", tipo, id)` ponerse uno suyo (`""` = el de serie). Elegir una clase ya comprada sigue por el remote `Clase` (`Clases`).
- Clases: la primera que compra cada jugador es gratis y la comprada queda elegida.
- Cosméticos: uno puesto por `Tipo` en `datos.puestos[Tipo]`. El servidor publica `Puesto<Tipo>` en el Player (solo si es suyo). Por ahora solo `Linterna`: el color de la luz (`EquipoVista`), en RGB en `Config` porque Lune no tiene `Color3`.
- `Datos` publica lo comprado en los atributos `Clases` y `Cosmeticos` (JSON) para la interfaz.
- Todo se cobra y apunta de una vez dentro de `Datos.editar` (sin esperas) y se guarda enseguida.

## Probado en Studio (22-10-2026)

- Primera clase gratis; la segunda cobra 400 una sola vez con 10 peticiones seguidas; luz roja comprada y puesta; no deja ponerse una que no es suya; peticiones basura ignoradas; la ventana se cierra al alejarse. Sin errores.
- Sin probar: la luz de color dentro de la partida (una línea en `EquipoVista`).
