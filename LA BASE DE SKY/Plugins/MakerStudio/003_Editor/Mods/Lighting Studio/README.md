# Lighting Studio v0.5.0 — iluminación real por normales en overworlds

Compatibilidad objetivo: Pokémon Essentials v21.1 · LA BASE DE SKY 1.2.1.1 · Maker Studio.

**Estado:** cambios subidos a `new-MK-for-2.5D-Testeo`, probados en lógica de JS y matemáticas de zoom; falta comprobación de ejecución real de Maker Studio y Pokémon Essentials. Prototipo, no release estable.

## Fallos tratados

### 1. Luces descolocadas al acercar o alejar Maker Studio

- Las luces con modo **Fusionar áreas** ya no se rasterizan sobre una superficie de tamaño de viewport dependiente del zoom.
- Se generan fragmentos fijos del **mundo** de 256 × 256 píxeles base, con 64 × 64 píxeles de datos por fragmento.
- Cada fragmento se coloca usando la transformación del overlay de Animated Props: `(tile * tileSize - viewportX) * zoom`.
- El zoom y el scrolling solo cambian la posición/tamaño de los fragmentos en pantalla, **no su contenido**.
- Una sola fuente se dibuja directamente con la misma transformación de mapa.
- La preview rápida para arrastre/sliders evita recomponer los fragmentos en cada movimiento de mouse; al soltar se muestra el modo de fusión exacto.

### 2. Luces que se mueven ingame

- El runtime dibuja la fusión con sprites de fragmentos anclados a coordenadas del mapa, **no con una pantalla de luz que necesita recomposición según la cámara**.
- El cálculo de posición de cada sprite usa el mismo zoom centrado y el mismo redondeo de `display_x/display_y` que el runtime de Animated Props.
- La cámara solo transforma la ubicación de esos sprites; el patrón de iluminación del mundo permanece fijo.

### 3. Picos de FPS y lag

Antes, el runtime ejecutaba bucles Ruby con `Bitmap#get_pixel` y `Bitmap#set_pixel` para cada fuente **cada vez que la cámara cambiaba**. Esto podía producir picos severos.

Ahora:
- Se calculan fragmentos por coordenada del mundo y se mantienen en caché (máximo: 48 fragmentos).
- Se construye **como máximo un fragmento nuevo por fotograma**. Con zoom extremadamente alejado se priorizan los 48 fragmentos más cercanos al centro de la cámara para evitar picos; las zonas más exteriores pueden no verse iluminadas a ese nivel de alejamiento.
- Las máscaras de fuentes estáticas se construyen a demanda, **como máximo dos máscaras nuevas por fotograma**.
- El coste de lectura/escritura de píxeles se paga al construir un fragmento, **no en cada desplazamiento**.
- La posición/zoom de los sprites se actualiza por fotograma con operaciones baratas, siguiendo Animated Props.
- Máscaras limitadas a 64 píxeles de dimensión máxima para reducir el coste inicial.

**Limitación:** la aparición progresiva de fragmentos nuevos puede ser visible durante unos fotogramas al entrar en un mapa o alejar mucho el zoom. El modo de fusión por máximo se conserva para luces estáticas. Para evitar recalcular fragmentos constantemente, las luces con pulsación usan sprites dinámicos aditivos; cuando se superponen no mantienen una unión MAX exacta en esta revisión.

## Controles actuales

- Editor de luces directamente sobre el mapa.
- Fuentes: radial, cono, elipse y rectángulo.
- Difuminado desde centro, arriba, abajo, izquierda, derecha o posición personalizada.
- Intensidad, brillo central, color, suavidad, rotación, tamaño, pixel art y pulsación.
- Por mapa: ambiente, interruptor global, vista nocturna solo editor, **Fusionar áreas** / **Acumular brillo**.
- Por luz: **Unir con otras luces**, **Sumar brillo**, Normal, Oscurecer.
- X/Y admite coordenadas con decimales.

## Pruebas imprescindibles

1. En Maker Studio, ancla una luz a un tile concreto y prueba zoom **50 %, 75 %, 100 %, 125 %, 150 % y 200 %** con una luz y luego dos luces fusionadas. Debe permanecer en el mismo punto del mapa.
2. Desplaza la cámara manteniendo la luz inmóvil: el centro visual debe seguir el tile.
3. Ingresa al juego, mueve al jugador/cámara y prueba el zoom del mundo con las mismas luces. No deben acompañar al jugador.
4. Compara **FPS en mapa vacío** contra 1, 5 y 20 luces estáticas y con pulsación.
5. Verifica las transiciones de mapa, reinicio con F12 y liberación de recursos.
6. Si hay lag, revisa en Maker Studio los milisegundos de render y espera en el panel.

No se ha ejecutado Maker Studio ni el juego desde este entorno. No afirmar FPS ni ausencia de picos hasta medirlos localmente.


## v0.4.4 — Difuminado y rendimiento (2026-10-19)

- Corregido el sentido del degradado: **Hacia abajo** significa luz fuerte arriba, zona uniforme y transición hacia abajo. **Hacia arriba**, izquierda y derecha siguen el sentido hacia el borde al que se atenúa.
- Nuevo control **Inicio del difuminado** (0 a 0.95; predeterminado 0.58), que decide cuánto área conserva su brillo antes de comenzar la transición. Separación de la máscara de silueta y el gradiente direccional.
- El degradado direccional usa una atenuación suave y solo recorta los bordes de la geometría para evitar que otra caída radial deforme las bandas. El pixel art cuantiza los niveles al generar la máscara.
- El parámetro se serializa conservando los mapas anteriores. Lo comparten Canvas Maker Studio y Ruby runtime; se incluye en las claves de caché para evitar conservar máscaras obsoletas.
- La unión del editor construye **máximo dos fragmentos del mundo por pasada de dibujo**. Los fragmentos pendientes solicitan actualizaciones incrementales desde el temporizador de Lighting Studio.
- La preview directa en arrastre y edición de sliders sigue siendo rápida y no reconstruye la composición fusionada hasta finalizar.
- Pruebas JavaScript realizadas: sintaxis de model/render/map_overlay/index, muestra descendente del degradado, simetría arriba-abajo, datos antiguos y unión MAX sin sobreexposición.

**Pendiente:** no se ha ejecutado Maker Studio ni el runtime Ruby en un proyecto Essentials real; la mejoría real de FPS, ausencia de picos y ubicación durante zoom necesitan validación práctica. No cambiar ni garantizar el sistema de chunks del juego basándose solo en la prueba estática.


## v0.4.5 — Pixel art de cono/elipse y respuesta de los sliders

- **Pixel art en editor:** la máscara se rasteriza en una rejilla lógica de bloques del tamaño elegido (`pixel.size`). Se elimina la doble reducción previa (`MASK_MAX` seguida de agrupación de celdas) que deterioraba conos y elipses. La rejilla tiene un máximo de 128×128 texeles para mantener un límite de CPU/memoria.
- **Pixel art ingame:** el runtime Ruby aplica la misma técnica de texeles lógicos antes de ampliar la máscara. El compositor por fragmentos continúa limitado a 64×64 por chunk; aún pueden aparecer diferencias visuales entre editor y juego, especialmente con zoom y mezclas.
- **Preview de parámetros:** los eventos `input` se agrupan hasta aproximadamente 10 actualizaciones por segundo; el valor final se aplica y guarda al soltar el slider. No se ocultan las otras luces durante el ajuste.
- **Optimización adicional:** se omite la generación/dibujo de máscaras de fuentes individuales completamente fuera del viewport y se preservan las aristas de pixel art en la unión de chunks.
- **Validación estática:** sintaxis de `render.js`, `index.js`, `map_overlay.js` y `model.js`; muestras iluminadas de rejillas cono 32×32 y elipse 27×16; omisión de fuentes fuera de pantalla; confirmación de temporizador/cancelación de preview.
- **Sin validación en ejecución:** no se han ejecutado Maker Studio ni Essentials/mkxp desde este entorno. No se garantiza FPS ni coincidencia 1:1 de las texturas en el juego. Probar con y sin fusión, en varios niveles de zoom, y medir tiempos de render del overlay antes de dar por terminado el fix.

## v0.4.6 — Corrección del haz cónico

- Las luces cónicas tienen **falloff especializado**: distancia frontal, apertura angular y atenuación lateral independiente. La fuente conserva su origen en el centro del sprite/mapa; no se desplaza de forma incompatible con luces guardadas.
- Se mantiene el alcance circular delante del origen, con un centro luminoso y una salida gradual en el extremo del foco. El modo de difuminado direccional sigue pudiéndose combinar con el cono.
- **Difuminado > Suavidad lateral del cono**: parámetro opcional `coneFeather` (0.03 a 0.90, predeterminado 0.28). Con valores bajos, bordes marcados; con valores altos, bordes más suaves.
- Las máscaras del editor y del runtime Ruby aplican la misma ecuación especializada. Las claves de caché incluyen `coneFeather` para que cambios en el inspector no reutilicen una máscara antigua.
- Pruebas JavaScript: `node tests/cone-falloff.test.mjs`. Comprueban origen, límite angular, simetría, caída hacia el extremo, intensidad lateral, rejilla pixel art y persistencia del ajuste.
- **Pendiente de validar en ejecución real**: la apariencia del cono en el mapa, la sintaxis y el arranque completos del plugin Ruby y los FPS de Maker Studio / Essentials. No se cambiaron los límites de construcción de fragmentos ni los cálculos de zoom en esta versión.

## v0.4.7 — Conos y elipses sin pixel art

- Los focos y elipses suaves del editor ahora usan máscaras de hasta **256 px**, diferenciadas de la rejilla lógica de pixel art (que no se modifica).
- La fusión de iluminación en el editor pasa a **128 × 128 muestras** por fragmento de 256 px del mundo (antes 64 × 64). Se conserva el contorno correcto con zoom.
- Se eliminó del algoritmo de unión la secuencia repetitiva `drawImage → getImageData` por fuente. La composición por máximo de RGB ahora se calcula directamente en un solo buffer por chunk, sin readbacks del canvas.
- Se limita la construcción de fragmentos por pasada y se reutiliza su caché; la preview se actualiza directamente mientras se mueve un slider y la unión exacta se reconstruye después de **350 ms de inactividad**.
- El redibujado no espera ya confirmaciones del overlay para poder recibir cambios posteriores. Las actualizaciones de fragmentos pendientes se comprueban cada 120 ms.
- El runtime Ruby usa máscaras suaves de hasta 128 px para conos y elipses, y fragmentos de iluminación de mayor resolución solo si el mapa incluye geometrías suaves de esos tipos. **Advertencia:** esto puede incrementar el coste de construcción inicial en ciertos mapas; sigue siendo necesario medir el FPS real del juego.

## Normal maps (fase 1: vinculación de recursos)

En el editor encontrarás la sección **NORMAL MAPS · Tiles y Overworld**. Permite:
- Seleccionar un gráfico original de `Graphics/Tilesets`, `Graphics/Autotiles` o `Graphics/Characters`.
- Seleccionar una textura de normales PNG en `Graphics/LightingStudio/Normals/Tilesets`, `Autotiles` o `Characters`.
- Vincular ambas por nombre, habilitar/deshabilitar el vínculo, guardar la convención de canal verde invertido y comprobar si los PNG existen.
- Mantener los vínculos al guardar, cargar o deshacer el mapa, con compatibilidad con proyectos anteriores.

**Importante:** aún NO hay sombreado por normal maps en mkxp. El módulo actual solo registra y valida texturas. No debe confundirse con soporte de iluminación por normales en OWs y tiles; esa etapa requiere integración con su dibujado y un pipeline shader o equivalente eficiente.

Referencia: `Graphics/LightingStudio/Normals/README.md`. Las normales deben tener el mismo tamaño y distribución de fotogramas/tiles que sus gráficos originales.

## Pruebas de regresión

- `tests/cone-falloff.test.mjs` — falloff y control lateral del cono.
- `tests/render-quality.test.mjs` — suavizado, caché de fragmentos y serialización de normales.
- **Pendiente:** pruebas integradas en Maker Studio y Essentials 21.1. No se garantiza eliminación del lag de 10 segundos hasta probarlo en la instalación del usuario.


## v0.4.8 — Normales automáticas, sin cientos de asignaciones

- **Catálogo global:** `normalSettings` está en la raíz de `Data/LightingStudio/maps.json`. Una sola configuración sirve para todos los mapas. Los vínculos manuales heredados de versiones anteriores se migran como excepciones, sin borrarse de sus mapas originales.
- **Reconocimiento automático:** al habilitar los normal maps en el panel, por defecto se busca `Graphics/LightingStudio/Normals/Characters/<nombre real del gráfico>_n.png` y lo mismo en `Tilesets/` y `Autotiles/`. No se enumera ningún Pokémon ni se crea una variable por especie, sexo, forma o follower.
- Ejemplo: cuando el motor muestre `Graphics/Characters/Followers/VENUSAUR.png`, el recurso esperado es `Graphics/LightingStudio/Normals/Characters/Followers/VENUSAUR_n.png`. Si el gráfico cambia, el resolvedor toma el nuevo nombre.
- **Excepciones**: la lista de vínculos manuales ahora es opcional y únicamente sirve para archivos que no respetan el sufijo `_n`. Se admiten subcarpetas seguras.
- **Ruby:** `Lighting Studio Runtime/002_NormalCatalog.rb` contiene `LightingStudio.normal_map_path(category, graphic)`, `normal_for_character(character)` y `normal_for_character_sprite(sprite)`. Cachea existencias y restablece esa caché al transferir mapa; no analiza especies ni fuerza lectura de archivos por frame.
- **Importante:** el catálogo resuelve rutas, pero NO hay sombreado por normal maps en RGSS/mkxp todavía. El siguiente paso es integrar shader/materiales con sprites de personajes, followers y tiles. Esta etapa no altera sus gráficos ni el rendimiento del juego.

## v0.4.8 — Lag al cambiar los parámetros de luz

- **Invalidación espacial:** mover, redimensionar o modificar una luz ya no reinicia todos los fragmentos de iluminación fusionada. `invalidateLightRegions(before, after)` borra únicamente los fragmentos que intersectan su posición anterior o la actual.
- **Edición inmediata:** mientras se manipula un control se representa una preview rápida; la unión definitiva se recupera tras 350 ms sin interacción. Los fragmentos no afectados permanecen en caché.
- **Autosave diferido:** las escrituras de `maps.json` se agrupan tras 700 ms de inactividad para no provocar recargas del sistema de archivos por cada deslizador; el botón **Guardar** continúa forzando la escritura.
- **Regresión reproducible**: `node tests/automatic-normals-and-cache.test.mjs`. Incluye nombres del jugador/follower, migración de datos y edición localizada de una de dos luces distantes.
- **Pendiente de medición real:** la desaparición del bloqueo de ~10 segundos necesita comprobarse en Maker Studio y con datos de diagnóstico; no hay cifras de FPS verificadas.

## v0.5.0 — Primera iluminación por normal maps del protagonista y followers

### Estado: integración RGSS experimental

`Plugins/Lighting Studio Runtime/003_CharacterNormals.rb` agrega una pasada **visible** de iluminación a los sprites `Sprite_Character` del protagonista y followers (no a todos los NPC). Se calcula a partir de los datos RGB del PNG de normales en la dirección de la luz más fuerte y cercana, para el **fotograma realmente visible** de la hoja de animaciones.

El resultado se muestra como un Sprite RGSS adicional, sincronizado con posición, zoom y origen del personaje. Se genera un máximo de un fotograma de luz por frame de Graphics; los resultados se cachean por gráfico, celda del sprite, ocho orientaciones discretas y color. El cambio de intensidad de luz solo altera la opacidad de la capa cacheada.

**Esta etapa NO es un shader GPU.** La API pública RGSS de mkxp-z no expone un enlace universal de shader personalizado por sprite. Se usa `Bitmap.raw_data` (RGSS/mkxp-z) para calcular de forma diferida texturas pequeñas que se reutilizan. No hay lectura de normales por píxel en cada tick. La superposición utiliza la luz dominante (máximo **una** fuente direccional por sprite). Los mapas normales de tiles y autotiles todavía NO participan en el render.

### Activación de los recursos

`Data/LightingStudio/maps.json` ahora incluye `normalSettings.enabled=true` y `normalSettings.auto.characters=true`. Esta configuración global permite usar el recurso ya subido:

```
Graphics/Characters/trainer_POKEMONTRAINER_Red.png
Graphics/LightingStudio/Normals/Characters/trainer_POKEMONTRAINER_Red_n.png
```

Los followers funcionan sin añadir variables por especie; su `character_name` determina el archivo de normales buscado. Si no existe, se usa el sprite original sin error.

### Modos de diagnóstico ingame (llamada de script)

```ruby
LightingStudioNormals.mode = :original # Solo el OW original; sin respuesta de normales
LightingStudioNormals.mode = :normals  # Muestra los colores RGB del normal map visible
LightingStudioNormals.mode = :lit      # Original + iluminación calculada (predeterminado)
```

Para observar la diferencia, coloca al protagonista junto a la farola cálida del mapa 79, cambia entre original y lit y desplázate alrededor de la fuente. Al entrar en un mapa se libera la caché de normales anteriores. La primera aparición de un fotograma o dirección nuevos puede generar un trabajo de CPU puntual; las apariciones siguientes usan caché.

### Limitaciones que requieren validación y mejoras futuras

- La capa se dibuja en `z = 8502` para que se distinga sobre la oscuridad ambiental; esto **puede alterar la oclusión frente a objetos/tiles altos**. Un render totalmente integrado en la composición de cada personaje necesita modificar el renderer o disponer de un shader.
- Si se activa otro plugin que reemplace el bitmap de un OW, la compatibilidad debe probarse.
- El seguimiento de luces utiliza una sola fuente predominante con influencia por distancia, no una solución físicamente exacta de varias luces y geometrías.
- Para limitar el coste, la dirección se discretiza en ocho ángulos y hay un máximo de 96 fotogramas iluminados en caché. Las transparencias, tono del OW, hue y reflejos todavía requieren pruebas.
- Aún NO se ha podido arrancar Pokémon Essentials/mkxp desde este entorno ni verificar sus FPS. Se requiere prueba real y captura. **No está confirmado que sea visualmente correcto sin ajustar opacidades y orden de capas.**

### Prueba automatizada independiente

```bash
ruby "Plugins/Lighting Studio Runtime/tests/test_character_normals.rb"
```

El test usa mocks RGSS para comparar una normal orientada a la derecha ante luz derecha/izquierda, comprobar que se reutiliza la imagen de la caché y que se crea el overlay en el sprite del protagonista. No sustituye una prueba en el juego.
