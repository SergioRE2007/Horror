# Tareas

Sale de `docs/plan-tecnico.md` (orden de construcción) y `docs/diseño.md`. Sergio pide pasos enteros ("paso 10"): se hacen todas sus tareas seguidas, en orden, en una sola rama, con un commit por tarea (pedido por el usuario). Estados: `hecho`, `en curso`, `pendiente`. Al acabar una tarea se marca aquí en el mismo commit.

## Hechas (pasos 1-9)

1. Base: Rojo con los dos lugares, `Config`, `Lang`, `Remotes`, `Datos` con candado, Lune y modo de pruebas — hecho
2. El corazón: casa gris, día y noche, Golpeador, persianas, esconderse y morir — hecho
3. Raspador, linterna con pilas, flash y dificultad por jugadores — hecho
4. Mochila de casillas, objetos y cargar cosas pesadas — hecho
5. Bosque gris, talar, tablones, generador y móvil con mapa — hecho
6. Guardado de la partida, lobby, coches y viaje — hecho
7. Llaves, salas cerradas, pueblo y vendedor — hecho
8. Taller, coche y final de la huida — hecho
9. Trepador, Imitador y Acechador — hecho

## 10. Clases, monedas, tienda, revivir y compras

### 10.1 Monedas que se ganan
- **Descripción:** monedas por noche superada, final, logro y premio diario. Se guardan en cada jugador al amanecer aunque la partida no se guarde.
- **Archivos probables:** `src/juego/servidor/Recompensas.luau` (nuevo), `Partida.luau`, `src/comun/servidor/Datos.luau`, `Config.luau`, `tests/regressions.luau`.
- **Criterios:**
  - Al amanecer cada jugador vivo o muerto suma lo de `Config` y el atributo `Monedas` cambia.
  - Un mismo amanecer no paga dos veces (prueba de Lune).
  - El premio diario solo una vez cada 24 h por jugador, contado en el servidor.
  - Aviso de una línea, sin desgloses.
- **Estado:** hecho

### 10.2 Clases
- **Descripción:** Leñador, Corredor, Fotógrafo, Mecánico, Carpintero y Explorador; una por jugador y partida; la primera gratis. Sus ventajas pasan por un módulo `Stats` (única fuente de multiplicadores).
- **Archivos probables:** `src/shared/Stats.luau` (nuevo), `Config.luau`, `Recursos.luau`, `Raspador.luau`, `Casa.luau`, `Coche.luau`, `Llaves.luau`, lobby.
- **Criterios:**
  - Elegida en el lobby, llega al juego por `MemoryStoreService` (nunca por datos de teletransporte).
  - Cada ventaja se nota al probarla en Studio y sale solo de `Stats`.
  - El servidor rechaza una clase que el jugador no tiene.
  - Lista de clases al final de `Config` sin reordenar.
- **Estado:** pendiente

### 10.3 Tienda en la gasolinera
- **Descripción:** comprar clases y cosméticos con monedas dentro de la gasolinera del lobby.
- **Archivos probables:** `src/lobby/servidor/Tienda.luau`, `src/lobby/cliente/TiendaUi.luau` (nuevos), `Lang`/`LangEs`.
- **Criterios:**
  - El servidor comprueba precio y monedas; pulsar muchas veces seguidas no compra dos veces ni deja monedas en negativo (prueba de Lune).
  - Interfaz oscura de libreta, textos por `Lang`, se usa en móvil.
- **Estado:** pendiente

### 10.4 Revivir y compras con Robux
- **Descripción:** revivir de noche (~25 R$, también a un amigo, máx. 1 por noche), paquetes de monedas y 3-4 pases (mochila grande, más ranuras, linterna mejor, paquete de inicio) por ventajas (`perks`).
- **Archivos probables:** `src/comun/servidor/Compras.luau` (nuevo), `Muerte.luau`, `Mochila.luau`, `Config.luau`.
- **Criterios:**
  - `ProcessReceipt` guarda el `PurchaseId` y no entrega dos veces (prueba de Lune).
  - Revivir solo de noche, solo a un muerto y solo una vez por noche.
  - El código pregunta por la ventaja, nunca por un pase concreto.
  - Lo que solo funciona publicado se apunta como no probado.
- **Estado:** pendiente

## 11. Arte

### 11.1 Casa y bosque con Blender
- **Descripción:** sustituir los bloques grises por modelos por script (`tools/blender/`), con mallas `<Pieza>_<Papel>`.
- **Criterios:** la jugabilidad no cambia (mismas colisiones y sitios); vistas `.png` revisadas; rendimiento aceptable en móvil.
- **Estado:** pendiente

### 11.2 Monstruos con IA
- **Descripción:** Golpeador, Raspador, Trepador, Imitador y Acechador desde dibujos de Sergio, pasados por IA de imagen a 3D, con esqueleto y animaciones por código.
- **Criterios:** licencia comercial comprobada; no pasa de Moderate (se ven en penumbra o un instante); animados.
- **Estado:** pendiente — necesita los dibujos de Sergio

### 11.3 Sonidos con ElevenLabs
- **Descripción:** golpes, chirridos, pasos por suelo, casa que cruje, latido, ambiente por capas.
- **Criterios:** Sergio los elige en `escuchar.html`; volumen igualado con `medir.mjs`; precargados en `SoundService`; sonidos 3D desde su ventana.
- **Estado:** pendiente — Sergio elige

## 12. Final difícil e historia

### 12.1 Pistas de la historia
- **Descripción:** notas, fotos y diario repartidos por el mapa y las salas cerradas; cuentan que el rico te mandó a propósito.
- **Archivos probables:** `src/juego/servidor/Pistas.luau` (nuevo), `FormatoPartida.luau`, `Lang`.
- **Criterios:** se guardan en la partida; carteles de pocas líneas; guardado viejo sin pistas sigue cargando (prueba de Lune).
- **Estado:** pendiente — el texto de la historia lo aprueba Sergio

### 12.2 La Bestia
- **Descripción:** final de matar al bicho, con la preparación que dicen las pistas (trampa del sótano, arma del desván…). Pide casi toda la casa abierta.
- **Criterios:** se puede completar de principio a fin en `Config.Test`; recompensa e insignia propias, entregadas una vez.
- **Estado:** pendiente — la mecánica concreta se decide con Sergio

## 13. Lanzamiento

### 13.1 Tutorial
- **Descripción:** los primeros 5 minutos, muy visible (flecha grande, pasos cortos, premio al acabar).
- **Estado:** pendiente — se diseña con Sergio

### 13.2 Nombre, iconos y lanzamiento en privado
- **Estado:** pendiente — decide Sergio

## Sueltas por confirmar

Salen en `diseño.md` y no se han encontrado en el código; mirar antes si ya están hechas con otro nombre.

- Ajustes con opción Rendimiento.
- Trampas de latas que suenan fuera de la casa.
- Sustos y efectos (temblores, polvo que cae, cristales) como avisos para quien juega sin cascos.
