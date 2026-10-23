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
  - Elegida en el lobby, llega al juego con los datos del jugador (DataStore con candado), nunca por datos de teletransporte.
  - Cada ventaja se nota al probarla en Studio y sale solo de `Stats`.
  - El servidor rechaza una clase que el jugador no tiene.
  - Lista de clases al final de `Config` sin reordenar.
- **Estado:** hecho (ver `docs/sistemas/clases.md`)

### 10.3 Tienda en la gasolinera
- **Descripción:** comprar clases y cosméticos con monedas dentro de la gasolinera del lobby.
- **Archivos probables:** `src/lobby/servidor/Tienda.luau`, `src/lobby/cliente/TiendaUi.luau` (nuevos), `Lang`/`LangEs`.
- **Criterios:**
  - El servidor comprueba precio y monedas; pulsar muchas veces seguidas no compra dos veces ni deja monedas en negativo (prueba de Lune).
  - Interfaz oscura de libreta, textos por `Lang`, se usa en móvil.
- **Estado:** hecho (ver `docs/sistemas/tienda.md`)

### 10.4 Revivir y compras con Robux
- **Descripción:** revivir de noche (~25 R$, también a un amigo, máx. 1 por noche), paquetes de monedas y 3-4 pases (mochila grande, más ranuras, linterna mejor, paquete de inicio) por ventajas (`perks`).
- **Archivos probables:** `src/comun/servidor/Compras.luau` (nuevo), `Muerte.luau`, `Mochila.luau`, `Config.luau`.
- **Criterios:**
  - `ProcessReceipt` guarda el `PurchaseId` y no entrega dos veces (prueba de Lune).
  - Revivir solo de noche, solo a un muerto y solo una vez por noche.
  - El código pregunta por la ventaja, nunca por un pase concreto.
  - Lo que solo funciona publicado se apunta como no probado.
- **Estado:** hecho (ver `docs/sistemas/compras.md`; faltan los Id de Roblox al publicar, 13.2)

## 11. Arte

### 11.1 Casa y bosque con Blender
- **Descripción:** sustituir los bloques grises por modelos por script (`tools/blender/`), con mallas `<Pieza>_<Papel>`.
- **Criterios:** la jugabilidad no cambia (mismas colisiones y sitios); vistas `.png` revisadas; rendimiento aceptable en móvil.
- **Estado:** hecho (ver `docs/sistemas/arte.md`)

### 11.2 Monstruos con IA
- **Descripción:** Golpeador, Raspador, Trepador, Imitador y Acechador desde dibujos de Sergio, pasados por IA de imagen a 3D, con esqueleto y animaciones por código.
- **Criterios:** licencia comercial comprobada; no pasa de Moderate (se ven en penumbra o un instante); animados.
- **Estado:** pendiente — necesita los dibujos de Sergio; se deja para casi el final (pedido por el usuario)

### 11.3 Sonidos con ElevenLabs
- **Descripción:** golpes, chirridos, pasos por suelo, casa que cruje, latido, ambiente por capas.
- **Criterios:** Sergio los elige en `escuchar.html`; volumen igualado con `medir.mjs`; precargados en `SoundService`; sonidos 3D desde su ventana.
- **Estado:** en curso — elegidos (ver `docs/sistemas/sonidos.md`); falta el flash. PENDIENTE AL VOLVER A CASA: subir `tools/sonidos/pendiente/FlashYT.mp3` al grupo con `subir.mjs` (este PC no tiene la clave), poner su id en `Config.Sonidos.Flash`, probar en Studio y borrar la carpeta `pendiente`.

### 11.4 Cortinas en vez de persianas (pedido por el usuario)
- **Descripción:** en todo el juego las ventanas tienen cortinas, no persianas: modelo, textos, sonido y nombres que ve el jugador. La mecánica de cerrar y abrir la ventana se queda igual.
- **Criterios:** ningún texto del jugador dice persiana; el Golpeador y el Raspador se juegan igual; partidas guardadas de antes siguen cargando.
- **Estado:** hecho (ver `docs/sistemas/corazon.md`)

### 11.5 Casa más grande, amueblada con modelos del Creator Store (pedido por el usuario)
- **Descripción:** habitaciones más grandes y realistas (la cocina de prueba pasó de 20×16 a 30×24) para moverse rápido y con fluidez dentro de la casa. Muebles del Creator Store; lo que no haya (encimeras viejas), con piezas. Después, igual con el pueblo.
- **Reglas (pedido por el usuario):** ninguna ventana tapada por muebles ni nada (los muebles van en las paredes sin ventana); pasillos anchos alrededor de mesas y muebles; nada que estorbe al correr. Puertas solo donde hacen falta (principal, que ataca el Golpeador, y las de llave: sótano, desván, habitación del rico, garaje); las demás (cocina–salón, dormitorio, baño, limpieza, dormitorio de arriba) pasan a vanos abiertos con marco de madera, más anchos (5-6 studs). Los bichos ya no abren esas puertas: revisar `Caza`.
- **Estilo (referencias en `docs/referencias/casa/`, pedido por el usuario: "así más o menos, pero más vieja y abandonada"):** salas grandes y despejadas, con los muebles contra las paredes y el centro libre; papel pintado (damasco dorado o marrón en el salón, rayas en la cocina) con moldura blanca en el techo y zócalo oscuro; vanos anchos con marco de madera oscura y cortinas oscuras a los lados; cocina con suelo de damas blanco y negro y azulejo blanco a media pared; suelo de madera oscura en el resto; lámparas de globo colgando y lámparas de mesa; muebles de los años 50-60 (butacas, sofá, tele de tubo, piano, aparadores). Lo abandonado: papel despegado y manchado, polvo, telarañas, muebles rotos o volcados, tablas, basura por el suelo y algo de sangre (sin pasar de Moderate), sin estorbar el paso.
- **Modelos:** borrar todo script y lo que no sea pieza, malla o textura (en la prueba, 2 de 6 traían virus, uno cifrado en la mesa). Descartar los sacados de otros juegos (Fallout, Garry's Mod, DOORS…). Elegidos en la prueba: nevera 14662571622, fregadero 88887125500659, cocina de hierro 4693256798, cocina oxidada 251322323, mesa 127957098225412, silla 16041491017.
- **Criterios:** colisiones, escondites, ventanas de los bichos y sitios de objetos siguen funcionando (revisar `Config` y bichos si cambian distancias); se ve bien en móvil.
- **Estado:** en curso — casa hecha (ver `docs/sistemas/casa-grande.md`); falta el pueblo

### 11.6 La casa por fuera (pedido por el usuario: "arreglar el modelo de la casa en sí")
- **Cómo está ahora:** una caja de tablas oscuras con ventanas pequeñas, un tejado tan bajo que casi no se ve y un porche de dos palos. Por dentro gusta ("está guay la casa, mola"): no tocar el interior.
- **Idea:** casa de campo vieja de madera, de los años 50, abandonada en el bosque, que se reconozca de lejos y dé miedo antes de entrar.
- **Plan, por orden (en `Mapa`, con piezas y texturas; Blender solo si hace falta algún adorno):**
  1. Tejado: aleros que sobresalgan con canalones torcidos, tejas oscuras con textura, hastiales de tablas con un ventanuco redondo del desván y la chimenea de ladrillo asomando por fuera. Misma pendiente o, si se cambia, actualizar `TEJADO` y el Trepador (`CUMBRE`, `PARED`).
  2. Fachada: tablas horizontales con textura de madera vieja y pintura desconchada, esquineras, zócalo de piedra abajo y una franja entre las dos plantas.
  3. Ventanas: marcos gruesos con dintel y alféizar, contraventanas (alguna rota o colgando) y algún cristal roto. Mismas ventanas y sitios: no cambiar las 11 que ataca el Golpeador.
  4. Porche ancho a lo largo de la fachada: suelo de tablas, columnas, barandilla rota, escalones y tejadillo; un farol apagado y una mecedora.
  5. Abandono fuera: hiedra subiendo por una esquina, tablas clavadas en una ventana de arriba, manchas de humedad, un buzón torcido y un trozo de valla caída.
  6. Garaje y cobertizo con el mismo estilo (chapa oxidada y tablas).
- **Antes de empezar, de Sergio:** 2-4 capturas de referencia de casas por fuera que le gusten (como las de dentro en `docs/referencias/casa/`).
- **Criterios:** ventanas, puertas, Trepador (tejado y chimenea) y bichos siguen funcionando; nada nuevo que estorbe al correr alrededor de la casa; se ve bien de día y de noche, y en móvil.
- **Estado:** pendiente — plan hecho; se hace en otro chat (pedido por el usuario, para gastar menos)

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
