# Ajustes (14.4)

- Engranaje pequeño dibujado con marcos (sin imagen) en la barra de arriba, justo a la derecha de los botones de Roblox de la izquierda (`GuiService.TopbarInset`, dividido por el `UIScale` del HUD): en móvil no lo tapa nada. Sin barra de Roblox (cinemáticas), en la esquina. En el lobby y en el juego (`comun/cliente/AjustesUi`).
- Ventana: papel oscuro en el centro con mancha de sangre, título AJUSTES en rojo, la opción RENDIMIENTO con una línea de qué hace y un botón SÍ/NO (rojo oscuro cuando está activo), y CERRAR. Libera el ratón (`Modal`).
- **Rendimiento:** atributo `Rendimiento` del `Player`. Lo pone solo el servidor (`comun/servidor/Ajustes`): el cliente pide con el remote `Ajustes` (`"Rendimiento", activo`), el servidor acepta solo un booleano y como mucho un cambio cada 0,25 s (constante `MINIMO` del módulo, a ojo). El botón enseña el atributo, no lo que se pulsó.
- Se guarda en los datos del jugador: campo `rendimiento` (booleano, `false` en datos viejos o rotos) de `Formato`, con el guardado normal de `Datos`. Al cargar se publica el atributo.
- Lo leen en cada uso `CasaVista`, `Efectos`, `IncendioVista` y `LatasVista` (menos partículas, sin viento ni adornos animados): cambia en marcha sin volver a entrar.
