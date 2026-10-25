# Tareas

Sale de `docs/plan-tecnico.md` (orden de construcción) y `docs/diseño.md`. Sergio pide pasos enteros ("paso 10"): se hacen todas sus tareas seguidas, en orden, en una sola rama, con un commit por tarea (pedido por el usuario). Estados: `hecho`, `en curso`, `pendiente`. Al acabar una tarea se marca aquí en el mismo commit. Todo lo que queda por hacer está en este archivo (pedido por el usuario: "apunta todo en task"); el detalle de cada sistema va en `docs/sistemas/`.

## Lo siguiente, en orden

1. 11.8.3 a 11.8.13: el interior, una sala por chat (sigue el pasillo, baño y trastero; vestíbulo, salón, comedor y cocina, hechos).
2. 11.6: que Sergio vea la fachada (se puede meter en cualquier chat de sala).
3. 12.1 Pistas → 12.2 La Bestia.
4. 11.5 Pueblo amueblado, 11.2 Monstruos (casi al final), 13 Lanzamiento.

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
    - 11.6 Casa nueva con el plano aprobado, ensanchada para correr, y fachada victoriana (`Fachada.luau`) — hecho (`docs/sistemas/casa-nueva.md`); falta que Sergio vea la fachada
    - Plugin VistaMapa para mover cosas a mano sin Play — hecho
    - Paso previo del interior: papel, molduras, techos y muebles más apagados y sucios; techos rotos; mecedora nueva; burro de serrar en X; quitadas la mesa de la cocina y la silla volcada; sillas del comedor orientadas — hecho

## 11. Arte (lo que queda)

### 11.6 Fachada: que la vea Sergio
- **Qué:** enseñarle la fachada victoriana en Studio y cambiar lo que no le guste.
- **Estado:** en curso — hecha, falta que la vea

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
| 11.8.5 | Pasillo, baño y trastero | bañera y váter; puerta del sótano | pendiente |
| 11.8.6 | Dormitorio de abajo | cama y armario de Blender (escondites) | pendiente |
| 11.8.7 | Galería | balaustrada de verdad sobre el hueco | pendiente |
| 11.8.8 | Dormitorio grande | cama y armario (escondites); salida al balcón | pendiente |
| 11.8.9 | Habitación del rico | lámpara del escritorio; sitio de las pistas (12.1) | pendiente |
| 11.8.10 | Cuarto de los niños | cuna y juguetes | pendiente |
| 11.8.11 | Escalera del desván y desván | baúles; cuarto de revelado | pendiente |
| 11.8.12 | Lavadero, garaje y cobertizo | enchufe del móvil, coche, generador | pendiente |
| 11.8.13 | Sótano | banco del taller (la reja de la 12.2) | pendiente |

En todas: telarañas que flotan o se meten en la pared.

### 11.5 Pueblo amueblado
- **Qué:** lo mismo que se hizo en la casa (salas grandes, muebles contra las paredes, puertas solo donde hacen falta), con el estilo de la casa nueva.
- **Modelos:** borrar todo script y lo que no sea pieza, malla o textura (en la prueba, 2 de 6 traían virus); descartar los sacados de otros juegos. Mejor Poly Haven, como en la 11.8.
- **Estado:** pendiente — después del interior de la casa

### 11.2 Monstruos con IA
- **Descripción:** Golpeador, Raspador, Trepador, Imitador y Acechador desde dibujos de Sergio, pasados por IA de imagen a 3D, con esqueleto y animaciones por código.
- **Criterios:** licencia comercial comprobada; no pasa de Moderate (se ven en penumbra o un instante); animados.
- **Estado:** pendiente — necesita los dibujos de Sergio; se deja para casi el final (pedido por el usuario)

## 12. Final difícil e historia

### 12.1 Pistas de la historia
- **Descripción:** notas, fotos y diario repartidos por el mapa y las salas cerradas; cuentan que el rico te mandó a propósito.
- **Archivos probables:** `src/juego/servidor/Pistas.luau` (nuevo), `FormatoPartida.luau`, `Lang`.
- **Criterios:** se guardan en la partida; carteles de pocas líneas; guardado viejo sin pistas sigue cargando (prueba de Lune).
- **Estado:** pendiente — textos aprobados por el usuario en `docs/historia.md` (12 pistas, dónde va cada una); falta programarlo (en casa, con Rojo)

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
- **Estado:** pendiente — mecánica decidida con Sergio; hacer después de 12.1 (las pistas la explican)

## 13. Lanzamiento

### 13.1 Tutorial
- **Descripción:** los primeros 5 minutos, muy visible (flecha grande, pasos cortos, premio al acabar).
- **Estado:** pendiente — se diseña con Sergio

### 13.2 Nombre, iconos y lanzamiento en privado
- **Descripción:** también crear en Roblox los productos y pases de `Config.Compras` (Id = 0 ahora) y probar compras de verdad.
- **Estado:** pendiente — decide Sergio

## Sueltas por confirmar

Salen en `diseño.md` y no se han encontrado en el código; mirar antes si ya están hechas con otro nombre.

- Ajustes con opción Rendimiento.
- Trampas de latas que suenan fuera de la casa.
- Sustos y efectos (temblores, polvo que cae, cristales) como avisos para quien juega sin cascos.
