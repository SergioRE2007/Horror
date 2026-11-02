# Tareas

Sale de `docs/plan-tecnico.md` (orden de construcción) y `docs/diseño.md`. Sergio pide pasos enteros ("paso 10"): se hacen todas sus tareas seguidas, en orden, en una sola rama, con un commit por tarea (pedido por el usuario). Estados: `hecho`, `en curso`, `pendiente`. Al acabar una tarea se marca aquí en el mismo commit. Todo lo que queda por hacer está en este archivo (pedido por el usuario: "apunta todo en task"); el detalle de cada sistema va en `docs/sistemas/`.

## Lo siguiente, en orden

1. 14 Pulido, fase a fase (14.1 → 14.5; la 14.2 es el tutorial 13.1).
2. 11.2 Monstruos (casi al final), 13.2 Lanzamiento.

## Hechas

1. Base: Rojo con los dos lugares, `Config`, `Lang`, `Remotes`, `Datos` con candado, Lune y modo de pruebas — hecho
2. El corazón: casa gris, día y noche, Golpeador, persianas, esconderse y morir — hecho
3. Raspador, linterna con pilas, flash y dificultad por jugadores — hecho
4. Mochila de casillas, objetos y cargar cosas pesadas — hecho
5. Bosque gris, talar, tablones, generador y móvil con mapa — hecho
6. Guardado de la partida, lobby, coches y viaje — hecho
7. Llaves, salas cerradas, pueblo y vendedor — hecho
8. Taller, coche y final de la huida — hecho
9. Trepador, Imitador y Acechador — hecho
10. Monedas, clases, tienda de la gasolinera, revivir y compras con Robux — hecho (`docs/sistemas/clases.md`, `tienda.md`, `compras.md`; faltan los Id de Roblox al publicar, 13.2)
11. Arte ya hecho:
    - 11.1 Casa y bosque con Blender — hecho (`docs/sistemas/arte.md`)
    - 11.3 Sonidos con ElevenLabs — hecho (`docs/sistemas/sonidos.md`)
    - 11.4 Cortinas en vez de persianas — hecho (`docs/sistemas/corazon.md`)
    - 11.5 Casa más grande con muebles del Creator Store: la casa — hecho (`docs/sistemas/casa-grande.md`); el pueblo sigue abajo
    - 11.6 Casa nueva con el plano aprobado, ensanchada para correr, y fachada victoriana (`Fachada.luau`) — hecho (`docs/sistemas/casa-nueva.md`); fachada vista y aprobada por Sergio
    - Plugin VistaMapa para mover cosas a mano sin Play — hecho
    - Paso previo del interior: papel, molduras, techos y muebles más apagados y sucios; techos rotos; mecedora nueva; burro de serrar en X; quitadas la mesa de la cocina y la silla volcada; sillas del comedor orientadas — hecho

## 11. Arte (lo que queda)

### 11.8 Interior realista, sala por sala (pedido por el usuario: "la casa por dentro es un ñordo gordo", muebles "demasiado simples")
- **Qué:** cambiar los muebles de la tienda de Roblox y los hechos con bloques por modelos de Poly Haven (CC0, uso comercial libre), pasados por Blender a Roblox con sus texturas (`SurfaceAppearance`). Lo que no haya, en Blender por script, nunca bloques.
- **Cómo (pedido por el usuario: una sala por chat y bien hecha, sin pasar a la siguiente hasta que la apruebe):** los 7 pasos de cada sala, la lista de muebles de cada una y la tubería están en `docs/plan-salas.md`. Blender abierto.
- **Incluye lo que quedaba de la 11.6** (salas menos vacías, que no parezcan cajas: arcos, columnas, techos y suelos distintos, balaustrada de verdad) **y la 11.7** (cada mueble mirando a la sala, apoyado y de tamaño creíble; los sospechosos están puestos en su sala).
- **Reglas que no cambian (pedido por el usuario):** ninguna ventana tapada, el centro libre, vanos anchos, nada que estorbe al correr; Moderate como máximo.
- **Criterios:** realista y abandonado de día y de noche; móvil a 30 fps o más (unos 5.000 triángulos por mueble, texturas de 512-1024); escondites, ventanas atacables, puertas con llave y objetos de `Mapa.objetos` siguen funcionando. Si se mueve una ventana o puerta, avisar: las partidas viejas la pierden.

| Tarea | Sala | Además revisar | Estado |
|---|---|---|---|
| 11.8.0 | Tubería Poly Haven → Roblox (`docs/sistemas/polyhaven.md`), probada con la butaca | — | hecho |
| 11.8.1 | Vestíbulo (aprobado por el usuario: "ha quedado muy bien") | dónde aparece el jugador | hecho |
| 11.8.2 | Salón (aprobado por el usuario: "esta bien") | sofá, tele encogida al 70 %; chimenea del Trepador sin tocar | hecho |
| 11.8.3 | Comedor (aprobado por el usuario: "me convence") | — | hecho |
| 11.8.4 | Cocina (aprobado por el usuario: "esta guay"; nevera de los 50 hecha aquí, pedido por el usuario) | sillas, cocina de hierro | hecho |
| 11.8.5 | Pasillo, baño y trastero (aprobado por el usuario: "esta bien") | bañera y váter; puerta del sótano | hecho |
| 11.8.6 | Dormitorio de abajo (aprobado por el usuario) | cama de hierro (escondite) y armario | hecho |
| 11.8.7 | Galería | balaustrada de verdad sobre el hueco | hecho |
| 11.8.8 | Dormitorio grande | cama y armario (escondites); salida al balcón | hecho |
| 11.8.9 | Habitación del rico | lámpara del escritorio; sitio de las pistas (12.1) | hecho |
| 11.8.10 | Cuarto de los niños | cuna y juguetes | hecho |
| 11.8.11 | Escalera del desván y desván | baúles; cuarto de revelado | hecho |
| 11.8.12 | Lavadero, garaje y cobertizo | enchufe del móvil, coche, generador | hecho |
| 11.8.13 | Sótano | banco del taller (la reja de la 12.2) | hecho (aprobado por el usuario el 02-11-2026) |

En todas: telarañas que flotan o se meten en la pared.

### 11.9 Detalles vivos de la casa (pedido por el usuario: "poner que la chimenea esté animada con fuego o sonidos de los electrodomésticos, detallitos")

- Todo en el cliente (`DetallesVista` y `ChimeneaVista`), sin tocar el camino del Trepador. Detalle en `docs/sistemas/detalles.md`.
- Chimenea: chispas, brasas que se enfrían al apagarse, llamarada al quemar al Trepador; al bajar él, las brasas se apagan de golpe y las luces tiemblan (aviso). Viento por el tiro.
- Reloj de pie del vestíbulo (tic-tac y campanadas de noche), nevera con el generador, gotas en fregadero y lavabo, bombillas que chisporrotean y tuberías que golpean.
- Sonidos con ElevenLabs (tanda `detalles`), elegidos por el usuario; los de la bombilla, de YouTube (pedido por el usuario). — hecho

### 11.5 Pueblo amueblado
- **Qué (pedido por el usuario: "hacerlo bien, pero rápido", no las 2 semanas de la casa):** fachadas bien hechas en todos los edificios y solo unos pocos con interior. Nada de una sala por chat: todo en 1-2 conversaciones.
- **Fachadas:** las de `Fachada.luau` de la casa (tablas, ventanas con molduras, tejados con tejas, porches), cada casa distinta (color, una o dos plantas, porche o no). Iglesia de piedra. Las cerradas, tapiadas y sin interior.
- **Se entra en:** tienda (vendedor), la casa de la puerta rota, iglesia, cripta y caseta del enterrador. Muebles reutilizados de la casa (`src/muebles/`) y pocos nuevos.
- **Calle:** farolas apagadas, coche abandonado, buzones, vallas caídas.
- **Modelos:** borrar todo script y lo que no sea pieza, malla o textura (en la prueba, 2 de 6 traían virus); descartar los sacados de otros juegos. Mejor Poly Haven, como en la 11.8.
- **Estado:** hecho — detalle en `docs/sistemas/pueblo.md` (vendedor como personaje de Roblox, vallas oscuras, charcos sin reflejo y bosque alrededor: pedido por el usuario)

### 11.2 Monstruos con IA
- **Descripción:** Golpeador, Raspador, Trepador, Imitador y Acechador desde dibujos de Sergio, pasados por IA de imagen a 3D, con esqueleto y animaciones por código.
- **Criterios:** licencia comercial comprobada; no pasa de Moderate (se ven en penumbra o un instante); animados.
- **Estado:** pendiente — necesita los dibujos de Sergio; se deja para casi el final (pedido por el usuario)

## 12. Final difícil e historia

### 12.1 Pistas de la historia
- **Descripción:** notas, fotos y diario repartidos por el mapa y las salas cerradas; cuentan que el rico te mandó a propósito.
- **Archivos probables:** `src/juego/servidor/Pistas.luau` (nuevo), `FormatoPartida.luau`, `Lang`.
- **Criterios:** se guardan en la partida; carteles de pocas líneas; guardado viejo sin pistas sigue cargando (prueba de Lune).
- **Estado:** hecho (`docs/sistemas/pistas.md`); falta un sonido de papel

### 12.2 La Bestia
- **Descripción (pedido por el usuario):** la Bestia es el origen de todos los bichos (partes o crías suyas que cazan para ella; el rico la alimenta con gente y por eso te contrató). Se la mata dentro de la casa: herirla, atraerla al sótano, encerrarla y quemar la casa empapada de gasolina. Al morir ella caen todos.
- **Preparación** (días y noches normales, lo explican las pistas):
  1. Gasolina: un bidón en cada uno de 6 puntos marcados de la casa (salón, cocina, pasillo, escalera, los dos dormitorios); se ve el charco, suena `Verter`. El último deja un rastro hasta el porche.
  2. Trampa del sótano: reja de hierro armada en el banco del taller con piezas (cadenas, barrotes); cae con una palanca y encierra lo que haya dentro.
  3. Pistola de bengalas del rico en el desván, con 3 bengalas (luz y fuego: lo que la daña).
  4. Cerillas para prender el rastro.
- **Noche final:** empieza con "Esperarla" en la casa cuando todo está listo. Esa noche no sale ningún otro bicho. Es más rápida que el jugador; cada bengala la deja cojeando ~8 s y más lenta. Se la atrae al sótano, se pasa la reja y se tira de la palanca; se sale por una trampilla nueva al patio. Desde el porche, la cerilla al rastro: el fuego recorre la casa sala por sala, cinemática de la casa ardiendo con su rugido, amanece; recompensa e insignia. Sin bengalas o con la reja fallada, te pilla y mueres.
- **Números a ojo:** 6 puntos de gasolina, 3 bengalas, ~8 s cojeando (en `Config`).
- **Criterios:** se puede completar de principio a fin en `Config.Test`; recompensa e insignia propias, entregadas una vez; lo preparado se guarda en la partida (guardado viejo sigue cargando, prueba de Lune); cinemática que esconde la interfaz y la devuelve siempre.
- **Estado:** hecho — probado en Studio de punta a punta el 02-11-2026 (`docs/sistemas/bestia.md`); lo que queda por pulir, en el plan de pulido

## 13. Lanzamiento

### 13.1 Tutorial
- **Descripción:** los primeros 5 minutos, muy visible (flecha grande, pasos cortos, premio al acabar).
- **Estado:** pendiente — se diseña con Sergio

### 13.2 Nombre, iconos y lanzamiento en privado
- **Descripción:** también crear en Roblox los productos y pases de `Config.Compras` (Id = 0 ahora) y probar compras de verdad.
- **Estado:** pendiente — decide Sergio

## 14. Pulido (pedido por el usuario: "un nuevo plan con muchas fases para empezar con pulir el juego", 02-11-2026)

Cada fase es un paso entero en su rama. Lo que salga al probar, se apunta en su fase.

### 14.1 Final de la Bestia justo y vistoso
- **Palanca fuera:** pasarla al patio, junto a la trampilla. Se la mete en el sótano, se sale por la trampilla y se tira desde fuera (ahora, dentro, te pilla mientras tiras aunque cojee).
- **Que suba al piso de arriba:** ahora arriba estás a salvo porque no encuentra camino.
- **Incendio grande:** llamas por ventanas y tejado, humo, la casa entera ardiendo en la escena final.
- **Puerta principal cerrada** al empezar "Wait for her", para que la reviente.
- **Morir esa noche** no borra lo preparado ese día.
- **Bidón:** no soltarlo después de cada cruz mientras le quede gasolina.
- **Aviso** "Corre. Vuelve a la luz." no tiene sentido en el sótano oscuro de la noche final.
- **Estado:** hecho (`docs/sistemas/bestia.md`; probado en Studio de punta a punta el 02-11-2026)

### 14.2 Los primeros 5 minutos
- Es la 13.1 (tutorial muy visible: flecha grande, pasos cortos, premio al acabar). Se diseña con Sergio.
- **Estado:** pendiente

### 14.3 Más miedo
- Sustos y efectos (temblores, polvo que cae, cristales) como avisos para quien juega sin cascos (sale en `diseño.md`; mirar antes si ya está con otro nombre).
- Trampas de latas que suenan fuera de la casa (ídem).
- Sonido de ambiente, con ElevenLabs. Falta también el sonido de papel de las pistas.
- **Estado:** pendiente

### 14.4 Controles y móvil
- Botones que solo salen muy cerca (la puerta del sótano, a ~3 studs).
- Ajustes con opción Rendimiento (mirar antes si ya está).
- HUD en pantallas pequeñas, cuántas piezas tiene el mapa (el pueblo, ~5.100 más 240 pinos) y probar en móvil.
- Aviso suelto del asset 203785492 en la consola.
- **Estado:** pendiente

### 14.5 Partida entera de prueba
- Una partida de principio a fin sin órdenes de prueba: ritmo de días y noches, monedas y precios (skill `roblox-economy-balancing`), fallos que salgan.
- **Estado:** pendiente
