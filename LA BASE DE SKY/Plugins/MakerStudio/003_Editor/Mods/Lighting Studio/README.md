# Lighting Studio v0.9.1 — tonos Pokémon Fable (día y noche)

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
ruby "DeveloperTests/LightingStudio/test_character_normals.rb"
```

El test usa mocks RGSS para comparar una normal orientada a la derecha ante luz derecha/izquierda, comprobar que se reutiliza la imagen de la caché y que se crea el overlay en el sprite del protagonista. No sustituye una prueba en el juego.


## v0.5.1 — Corrección de inicio (LoadError)

**Importante:** Pokémon Essentials recopila recursivamente archivos `.rb` dentro de cada carpeta de plugin. El archivo de pruebas `test_character_normals.rb` se había colocado por error en `Plugins/Lighting Studio Runtime/tests/` y su `load` se ejecutaba al iniciar el juego. Por eso aparecía el error intentando cargar `003_CharacterNormals.rb` desde la raíz.

El test independiente se ha trasladado a `LA BASE DE SKY/DeveloperTests/LightingStudio/test_character_normals.rb` y su ruta relativa se ha corregido. Solo se ejecuta voluntariamente desde `LA BASE DE SKY`, con el comando indicado arriba. Dentro de `Plugins/Lighting Studio Runtime` solo deben existir los scripts de runtime `001_`, `002_` y `003_` y el `meta.txt`.

 
## v0.5.2 — Normales sin popping y compatibles con pulsación

- **Salida suave:** la pasada normal ya no desaparece inmediatamente cuando el protagonista abandona una luz; conserva el último bitmap renderizado y reduce gradualmente la opacidad hasta cero.
- **Entrada suave:** el efecto aparece progresivamente, evitando cambios bruscos al cruzar el límite.
- **Pulsación sincronizada:** el cálculo de normales utiliza `LightingStudio.pulse_values(pulse, System.uptime)`, exactamente la misma función y reloj que el runtime principal. Se animan intensidad **y** radio; la intensidad solo modifica `Sprite#opacity`, sin regenerar bitmaps del normal map.
- **Frontera continua:** antes se utilizaba una caída lineal con corte. Ahora se añade una curva suave hacia cero entre el 60 % y el 100 % de influencia de la luz, respetando la geometría radial, elíptica, rectangular y el alcance del cono.
- **Movimiento:** el muestreo de la distancia prioriza `real_x` y `real_y` del personaje para evitar saltos por cambios de tile a tile.
- **Rendimiento:** las texturas calculadas siguen almacenadas en caché; solo se actualiza su opacidad y posición durante el movimiento. Una luz dominante controla la dirección del normal map.
- **Test de regresión:** `ruby "DeveloperTests/LightingStudio/test_character_normals.rb"` comprueba progresión de pulsación, aparición, desaparición y caché.
 
**Validación:** lógica inspeccionada y pruebas de regresión incluidas en GitHub; falta comprobar visualmente el resultado y rendimiento dentro de mkxp/Pokémon Essentials. El cambio no añade un shader GPU.

## v0.5.3 — Normales invisibles tras el suavizado

- Corrige una **regresión de alcance** introducida en v0.5.2: las luces rectangulares y elípticas excluían al personaje demasiado pronto, porque el muestreo solo utilizaba el centro del sprite y el área estricta de la luz. Se añade un margen de contacto de 24 píxeles de mundo a la influencia sobre personajes, sin modificar la luz visible del mapa.
- El desvanecimiento espacial se concentra en el borde exterior (a partir de 82 % del alcance efectivo), conservando mayor brillo en la zona iluminada. El brillo máximo de la pasada normal se ajusta a 225/255.
- Se conserva la entrada/salida temporal gradual y la pulsación de tamaño e intensidad, con el mismo reloj `System.uptime` que el runtime de las luces.
- **Diagnóstico ingame**: desde un evento de script, ejecutar `p LightingStudioNormals.debug_status`. El resultado muestra `normal_path`, `normal_exists`, `light_count`, `light_strength`, `baked_frames` y `cached_normals`. Con `LightingStudioNormals.mode = :normals` se puede comprobar la carga del PNG independientemente de las luces.
- El test independiente `DeveloperTests/LightingStudio/test_character_normals.rb` comprueba ahora luces elípticas y rectangulares cerca del borde, visualización activa junto a la luz, salida suave y oscilación de pulsación. Ninguna prueba Ruby se ubica dentro de `Plugins/`.

**Pendiente:** comprobar la visibilidad en el juego y ejecutar los tests en Ruby/mkxp. Esta revisión se ha verificado por lectura del código, matemáticas del alcance y validaciones del repositorio; no hay confirmación visual del resultado real.


## v0.5.4 — Normal maps fluidos al acercarse a luces

- La influencia de normales se prolonga hasta el **122 % del alcance normalizado**, con caída suave desde el **72 %**. El margen de contacto del sprite (24 px) se conserva. Esto permite que el relieve reaccione también al acercarse desde fuera del halo.
- Se sustituyen los saltos entre 8 orientaciones por **16 direcciones de caché** y mezcla ponderada de dos fotogramas vecinos mediante dos capas RGSS sincronizadas con el sprite. El ángulo de la luz se interpola sin volver a procesar píxeles por cada frame.
- La opacidad de ambos overlays suma la misma intensidad temporal compartida; se mantiene el pulso de tamaño e intensidad de la fuente y la entrada/salida progresiva. No se recrean texturas si el fotograma y las direcciones ya están cacheados.
- Los normal maps siguen resolviéndose automáticamente por gráfico: jugador y Pokémon seguidores. Al cambiar de gráfico se reinician ambas capas para evitar mantener normales del Pokémon anterior.
- Diagnóstico: `LightingStudioNormals.mode = :normals` muestra el PNG en la primera capa; `LightingStudioNormals.mode = :lit` usa la iluminación interpolada; `p LightingStudioNormals.debug_status` indica la intensidad.
- **Nota de compatibilidad:** ahora se crean dos sprites auxiliares por personaje en lugar de uno. El runtime desecha los dos al liberar el spriteset; las 96 imágenes direccionales como máximo se siguen administrando en la caché. Puede requerir hasta dos fotogramas para crear un par de direcciones inédito.
- Prueba Ruby independiente actualizada: `ruby "DeveloperTests/LightingStudio/test_character_normals.rb"`. No colocar tests `.rb` dentro de Plugins.

**Estado de validación:** pendientes la ejecución del test Ruby y la comprobación visual en Essentials 21.1/mkxp-z. No se ha medido el impacto en FPS en el juego real.

## v0.7.0 — Cambios implementados

### 1. Optimización de normals y control real de brillo

- Las normales del jugador y followers tienen intensidad configurable: `normalSettings.intensity`, rango 0–1.5, valor predeterminado **0.5** (antes se imponía un brillo máximo fijo).
- `normalSettings.warmup` precarga el PNG de normales al dibujar el personaje, antes de entrar en una luz; se pueden generar **dos orientaciones nuevas por fotograma** en lugar de una, por lo que ambas capas pueden aparecer al mismo tiempo.
- No se hornean todas las animaciones en cada frame: caché de hasta 128 bitmaps, liberada al cambiar de mapa. La primera vez que aparece una orientación nueva todavía puede producirse una pequeña carga.
- En Maker Studio, panel «NORMAL MAPS · Catálogo global»: slider **Intensidad visual de normales** y casilla de precarga.
- La iluminación de normales de una fuente personalizada PNG comprueba además si el personaje se encuentra dentro de una zona clara de su máscara, evitando respuesta donde la imagen es negra/transparente.

### 2. Mejoras de rendimiento de Maker Studio

- Editor: tres modos **Calidad de previsualización** (Rápida / Equilibrada / Completa).
- Se ralentizan los repintados en los modos económicos y las actualizaciones del diagnóstico. La vista previa usa chunks de 96×96 y caché acotada para reducir coste.
- Las ediciones por slider se guardan con retardo, no con una escritura del archivo por cada tick de ratón. Los controles mantienen su configuración al guardar.
- No se ha medido el FPS real del editor en esta revisión; es preciso probar mapas con bastantes luces y Animated Props.

### 3. Luces con máscaras de forma personalizada

- Tipo de luz **«Máscara PNG (forma personalizada)»**.
- Directorio: `Graphics/LightingStudio/Masks/`. Ejemplo: `cueva_salida.png`.
- Los valores RGBA y la escala de grises del PNG definen la forma y su intensidad, tanto en la vista previa como en el runtime.
- Configuración: nombre del archivo, ancho y alto de proyección, rotación, color, potencia y pulsación. Se conservan los mapas con luces geométricas anteriores.
- El editor carga el archivo mediante la misma lectura binaria de Maker Studio que Animated Props.
- **Para una salida de cueva:** dibuja en blanco/gris el área iluminada hacia fuera, con transparencia detrás del muro. La luz resultante no se extiende fuera de la silueta dibujada.
- Se aceptan nombres PNG simples, tamaño máximo 512×512. Consulta `Graphics/LightingStudio/Masks/README.md`.

### 4. Ciclo horario (fuente real o reloj interno)

- Configuración global `timeOfDay` en `Data/LightingStudio/maps.json`. **Desactivado por defecto**, para no cambiar la iluminación ya creada.
- `source: "real"`: hora local del ordenador. `source: "internal"`: reloj interno que avanza con la variable `minutesPerSecond` y se conserva en la partida mediante `$PokemonGlobal`.
- `keyframes`: tabla editable de horas (0–24), color ambiente `#RRGGBB` y oscuridad 0–1. La transición entre entradas es suave e incluye el tramo de 23:59 a 00:00.
- Modo por mapa `dayNightMode: "follow" | "ignore"`: útil para que las cuevas e interiores conserven su iluminación configurada.
- En Maker Studio → «Ciclo de día y noche»: origen, hora inicial, velocidad, colores por hora, oscuridad por hora, anulación por mapa y una hora de previsualización que **no modifica el reloj ingame**.
- En eventos Ruby: `LightingStudioDayNight.current_hour` y `LightingStudioDayNight.set_internal_time(18,30)`.
- En esta etapa controla la **luz ambiental**; no ajusta automáticamente niebla, clima ni el encendido/apagado de cada farola.

### Ejemplo de esquema añadido

```json
{
  "normalSettings": {"enabled":true,"intensity":0.5,"warmup":true},
  "timeOfDay": {
    "enabled":true,"source":"internal","startHour":8,"minutesPerSecond":0.1,
    "keyframes":[
      {"hour":0,"color":"#182440","darkness":0.68},
      {"hour":12,"color":"#FFFFFF","darkness":0.0}
    ]
  }
}
```

### Validación y límites

- **JS:** syntax-check de módulos editados; comprobada migración de mapa antiguo, lectura de máscara y cálculo horario en pruebas de modelo.
- **Ruby:** pendiente `ruby -c` del plugin y prueba real en Essentials/mkxp-z. No hay confirmación de FPS ni del aspecto visual dentro del juego.
- Los PNG y colores son autorales; el plugin no genera automáticamente una máscara a partir de tiles existentes. Los mapas existentes mantienen su configuración cuando `timeOfDay.enabled=false`.

 
## v0.7.1 — correcciones ingame y nueva interfaz de Maker Studio

### Luces inmediatas al cargar el mapa
- Se precalculan hasta **12 chunks cercanos** durante la creación del spriteset del mapa; después continúa a **2 chunks por frame** (antes era 1).
- Máscaras y chunks escriben y leen píxeles por buffers `Bitmap.raw_data` cuando están disponibles, con fallback a `get_pixel/set_pixel`. Se evita ejecutar un método gráfico por cada texel.
- Al precalcular al inicio puede aumentar ligeramente el tiempo del fotograma de carga, a cambio de eliminar la aparición escalonada durante el primer segundo. Los valores exactos de FPS están pendientes de prueba ingame.

### Normales con profundidad correcta
- Las dos capas de iluminación por normales utilizan `overlay.z = base.z + 1`, conservando el orden de personajes y tiles con prioridad, en lugar de `z = 8502`.
- Las copas de árboles, techos y tiles situados delante del OW pueden ocultar su relieve luminoso. **Limitación:** el overlay queda ahora por debajo de la capa ambiental que Lighting Studio dibuja a `z = 8500`, por lo que su efecto puede parecer más tenue de noche; hará falta integración de composición por sprite para un resultado ideal.

### Editor ancho y navegación por categorías
- Lighting Studio abre una ventana de **1050×810 px** por defecto (el usuario puede cambiar su tamaño).
- Pestañas de trabajo: **Luces e inspector, Ambiente, Día y noche, Normal maps**.
- En «Luces e inspector», la biblioteca de luces queda a la izquierda y las propiedades a la derecha. El diseño baja a una columna cuando el panel se estrecha; las secciones de otros sistemas dejan de amontonarse unas debajo de otras.

### Nuevo objeto clave: Saco de dormir
- Nuevo ID en `PBS/items.txt`: `SLEEPINGBAG` (FieldUse Direct, KeyItem).
- Manejador `Plugins/Lighting Studio Runtime/005_SleepingBag.rb`, disponible desde bolsa y menú de acceso rápido.
- Permite **descansar 1, 6 o 12 horas** o fijar la hora a **06:00, 12:00, 18:00 y 00:00**. Es reutilizable.
- Solo funciona si `timeOfDay.enabled=true` y `timeOfDay.source="internal"`. No modifica el reloj real.
- Su hora se guarda con `$PokemonGlobal` y se refleja en el mapa al actualizar la iluminación ambiental.
- Para probar: recompila PBS desde Debug, activa «Ciclo de día y noche» en Maker Studio, selecciona «Reloj interno» y concede el objeto desde un evento:
  `pbReceiveItem(:SLEEPINGBAG)`.
- Su imagen está en `Graphics/Items/SLEEPINGBAG.png` (icono pixel art de 48×48).
- Test independiente `ruby "DeveloperTests/LightingStudio/test_daynight.rb"` para opciones del saco, persistencia en objeto de guardado y transiciones horarias; cubierto también por CI.

**Validación:** los archivos se subieron a la rama `new-MK-for-2.5D-Testeo`; queda por comprobar visualmente la prioridad y la carga inicial dentro de Essentials 21.1. Si los normales se vuelven demasiado oscuros por el orden de composición, se requerirá una solución que combine la iluminación en la capa del personaje y no otro aumento de z.

## v0.7.2 — Corrección de salto horario y reorganización de interfaz

- **Reloj funcional en mapa 79:** `Data/LightingStudio/maps.json` incorpora el perfil horario `timeOfDay` activado en **modo interno**, y el mapa 79 sigue ese perfil. Antes faltaba `timeOfDay` en el archivo de datos del juego y no podía reaccionar aunque el saco cambiara la hora.
- **Actualización inmediata:** `LightingStudioDayNight.set_internal_time` incrementa una revisión y solicita un repintado de la capa ambiental del mapa sin volver a entrar. El renderizador ya no depende exclusivamente del temporizador de 0,2 s; evita volver a dibujar el píxel ambiental si el color no cambia.
- **Diagnóstico:** `p LightingStudioDayNight.debug_status` permite ver `source`, `enabled`, `map_mode`, `hour`, `ambient` y `revision`.
- **Saco de dormir:** selector de seis horas fijas **06:00 Amanecer, 09:00 Mañana, 12:00 Mediodía, 15:00 Tarde, 18:00 Atardecer, 21:00 Noche**. Pregunta: «¿A qué hora quieres despertar?». No permite avanzar la hora del sistema real.
- **Nueva experiencia Maker Studio:** navegación superior por secciones, herramientas de editar luces solo en «Luces e inspector», diagnósticos plegables, biblioteca e inspector en dos columnas, ciclo horario dividido en configuración y tabla editable de colores/oscuridad. La franja visual de 24 horas permite previsualizar una hora pulsando directamente en su segmento.
- **Undo/Redo:** los controles de color y oscuridad de la línea temporal crean y consolidan ediciones, en lugar de mutar datos sin historial.
- **Tests:** `DeveloperTests/LightingStudio/test_day_night.rb` comprueba configuración activa, salto horario, la tabla de seis horas y solicitud de actualización inmediata; se ejecuta en CI.

### Activación / pruebas rápidas

Actualiza desde la rama `new-MK-for-2.5D-Testeo`, abre Lighting Studio → «Día y noche» y comprueba que están activados el ciclo y el modo «Reloj interno». Asegúrate de probar el **mapa 79**. Da el saco mediante `pbReceiveItem(:SLEEPINGBAG)` (recompila PBS si nunca lo hiciste) y cambia a 06:00 y 21:00. La capa ambiental debería cambiar al instante. Si no sucede, ejecuta `p LightingStudioDayNight.debug_status`.

**Validación:** modelos JavaScript y estructura de cambios revisados. Pruebas Ruby añadidas al workflow, pero aún no hay confirmación ingame del efecto o del diseño final de la interfaz.

 
## v0.8.0 — Cambio de ambientación y activación horaria de luces

### Ciclo visual inspirado en RPG 2D y Pokémon vanilla

- **Luz del día neutra:** a las 11:00 el ambiente tiene oscuridad 0 y color blanco sin opacidad, por lo que conserva los colores originales del pixel art sin capa blanca.
- **Tarde poco invasiva:** a las 15:00 y 17:00 el ambiente añade solo un matiz cálido suave, sin teñir el mapa de amarillo ni verde.
- **Anochecer y noche:** transición progresiva a una tonalidad azul grisácea. Las sombras se mantienen moderadas para conservar la legibilidad de vegetación, agua y casas.
- El renderizador del reloj utiliza un máximo de **170 puntos de opacidad para oscuridad=1** (el ambiente manual sin reloj no cambia), en lugar de 230. Los presets pueden modificarse desde Día y noche.
- El perfil se guarda en `Data/LightingStudio/maps.json` del mapa 79. Los demás mapas mantienen su configuración.

### Inspector → «Horario»

Cada luz puede tener un horario propio `schedule`:
```json
"schedule": {
  "enabled": true,
  "startHour": 19,
  "endHour": 7,
  "fadeMinutes": 20
}
```

- **Siempre encendida**: comportamiento de antes. **Solo día**: 07:00–19:00. **Solo noche**: 19:00–07:00. **Personalizado**: cualquier intervalo con cruce de medianoche. **Transición**: 0 a 120 minutos del juego.
- Una luz con horario se dibuja mediante sprite dinámico, sin tener que regenerar chunks estáticos al cambiar la hora; su opacidad multiplica la intensidad programada por la pulsación (si la hay).
- Los normales de jugador/followers **también consideran el horario** de la luz; no continuarán brillando bajo una farola apagada.
- El inspector incorpora la quinta pestaña «Horario». En Día y noche, al activar la hora de previsualización se ven encendidas las fuentes que corresponden a ese horario.
- Las **dos farolas cálidas existentes** del mapa 79 están configuradas para funcionar de **19:00 a 07:00**, encendiendo y apagando a la hora exacta. El cambio de opacidad se suaviza en aproximadamente 0,28 segundos reales para no mostrar saltos. Las demás luces siguen encendidas todo el día. Cambia estos horarios desde su inspector.

### Saco de dormir — seis horas exactas de la referencia

**Menú único con las seis horas:** 7 a.m., 11 a.m., 3 p.m., 5 p.m., 7 p.m. y 11 p.m. No hay flechas, paginación ni una segunda ventana; se cancela con el botón habitual de retroceso.

Tras elegir: **10 fotogramas hacia blanco**, **espera de 10**, cambio de hora, **ME Pokémon Healing**, **espera de 30**, **10 fotogramas de vuelta**, espera de 20 y un texto contextual corto y distinto por hora (sin usar la frase sobre la determinación).

La transición blanca se hace con un sprite blanco temporal, para no cambiar permanentemente los tonos del mapa o interferir con las capas de otras modificaciones. El reloj cambia con `LightingStudioDayNight.skip_to_hour(7)`; está disponible además `LightingStudioDayNight.time_in_text`.

### Pruebas y limitaciones

- `DeveloperTests/LightingStudio/test_day_night.rb`: valida los seis horarios, el único menú de seis horas, 80 fotogramas de animación por elección, la ME, el refresco inmediato y los horarios nocturnos atravesando medianoche.
- `DeveloperTests/LightingStudio/test_model.mjs`: comprueba conservación de horarios en JSON, reglas nocturnas y ausencia de tinte diurno.
- **Pendiente probar el resultado dentro de Pokémon Essentials y revisar FPS**. Las variantes de iluminación de escenarios particulares pueden requerir ajustes artísticos por mapa; no se han cambiado sprites, tilesets ni normals.

### Ajuste final de activación horaria

La programación de las farolas de prueba utiliza `fadeMinutes: 0`: **al cambiar con el saco directamente a las 19:00 se activan** (sin esperar 20 minutos del reloj interno). El runtime interpola la opacidad durante unos 0,28 segundos del tiempo real cuando una fuente programada cambia de estado.

Quien desee una transición gradual basada en el tiempo del juego puede elevar «Transición (minutos del juego)» en el inspector de cada luz. Esta opción tiene prioridad sobre la transición visual breve y acepta periodos que cruzan medianoche.

### Ajuste UX del saco de dormir (menú único)

Las seis horas fijas se muestran en **una sola selección** de Pokémon Essentials, en lugar de repartirlas en dos páginas. Orden: 07:00, 11:00, 15:00, 17:00, 19:00 y 23:00. La transición blanca, la ME y los mensajes por hora se conservan. El test `DeveloperTests/LightingStudio/test_day_night.rb` comprueba que la ventana contiene las seis opciones, en su orden correcto, sin flechas.


## v0.9.0 — Cambio del mezclado ambiental a Tone (RGBG) nativo

**Motivo:** la superposición translúcida de un color RGB con alpha en toda la pantalla alteraba la saturación y lavaba los colores originales del pixel art, incluso usando paletas menos intensas.

**Referencias técnicas:**
- Deo's Custom Day & Night Tones: https://eeveeexpo.com/resources/50/ . Usa Tone.new(red,green,blue,gray), busca legibilidad nocturna y conserva los colores de los tiles; estos presets están adaptados, no copiados exactamente.
- Godot CanvasModulate / 2D Lights: separar modulación ambiental de luces de puntos, que son aditivas.
- Unity URP 2D: Multiply para cambiar la energía del fondo y Additive para luces locales; evitar sumar múltiples passes de tinte similares.

### Motor ingame

- El modo `timeOfDay.blendMode: "tone"` es ahora el predeterminado. Lighting Studio **ya no dibuja un rectángulo semitransparente** para su ciclo día-noche en este modo.
- Aplica valores RGSS `Tone.new(R,G,B,Gray)` sobre el viewport del mapa. La hora interpola los cuatro canales por separado, conservando el color de fondo en el día.
- La integración suma el Tone de eventos `$game_screen.tone` al del reloj, con clamp RGSS. Los mapas marcados `dayNightMode: "ignore"` siguen usando los efectos de la base.
- **Evita doble coloración:** la base dispone de `pbDayNightTint(@map_renderer)` independiente, gobernado por la hora real. Si el ciclo nativo de Lighting Studio está activo en el mapa, se neutraliza solo el Tone vanilla del renderer (sin alterar el Tone de eventos). Cuando se apaga el ciclo, ese comportamiento vanilla vuelve a utilizarse.
- En mapas conectados, el Tone definitivo se establece después de actualizar todos los Spriteset_Map.
- El modo antiguo `blendMode: "overlay"` permanece para compatibilidad con proyectos que dependan de RGB `color + darkness`.
- Los mapas sin el ciclo habilitado y los controles manuales de oscuridad no han sido modificados.

### Editor Maker Studio

- Sección **Día y noche → Cómo se mezcla el color**: “Tono nativo Pokémon (RGB + gris)” o “Capa RGB antigua”.
- En modo nativo, cada hora tiene controles directos **Rojo, Verde, Azul** (-255 a 255) y **Gris** (0 a 255), además del horario.
- La franja de 24 horas utiliza muestras de referencia RGBG, no bloques del color elegido.
- La previsualización sobre el mapa usa mezclas Canvas *multiply* (oscurecimiento de canales) y *screen* (valores positivos), sin leer píxeles de toda la pantalla. **Es aproximada**: el gris nativo de Essentials solo se representa exactamente en el juego.

### Configuración de prueba (mapa 79)

- 00:00 — RGBG (-58, -58, +9, 30)
- 07:00 — RGBG (-16, -28, -34, 9)
- 11:00 a 15:00 — RGBG (0, 0, 0, 0)
- 17:00 — RGBG (-12, -27, -32, 9)
- 19:00 — RGBG (-29, -33, +4, 20)
- 23:00 — RGBG (-58, -58, +9, 30)

Se conservan los presets, pulsación, horarios de las farolas y el saco de dormir con seis horas en una única página.

### Validación

- Comprobación de sintaxis JavaScript de los módulos y cálculo del modelo de horarios; agregados tests de mezcla RGBG, compatibilidad con el formato anterior, Tone de eventos y eliminación del doble tinte vanilla.
- **Falta ejecutar el plugin dentro de Essentials / mkxp y confirmar visualmente el resultado y FPS.** Para aislar si el problema es la paleta o el mezclado, compara 11:00 y 23:00, con las luces locales desactivadas temporalmente, y después actívalas.

## v0.9.1 — Preset Pokémon Fable (Deo, Eevee Expo)

**Fuente:** https://eeveeexpo.com/resources/50/ — sección «Pokémon Fable Tone».

Se sustituyen los tonos predeterminados de `model.js` y los del `Data/LightingStudio/maps.json` del mapa de prueba por los **valores RGGB exactos** del recurso para noche, mañana, día y tarde:

| Hora clave | Rojo | Verde | Azul | Gris | Tramo |
|---|---:|---:|---:|---:|---|
| 00:00 | -30 | -70 | +11 | 68 | Noche púrpura |
| 05:00 | -20 | -60 | -30 | 17 | Amanecer |
| 09:00 | 0 | 0 | 0 | 0 | Día neutro |
| 17:00 | +2 | -20 | +3 | 17 | Tarde |
| 21:00 | -30 | -70 | +11 | 68 | Noche |

**Importante:** la fuente original define una tabla de 24 tonos horarios. Lighting Studio conserva los **cinco tonos clave exactos** y añade cuatro puntos de mantenimiento a las 04:45, 08:45, 16:45 y 20:45. Así mantiene los tonos Fable durante la noche, mañana, día y tarde, con transiciones suaves de 15 minutos del juego. El mediodía queda completamente neutro y la noche alcanza el tono Fable desde las 21:00 hasta las 04:45. Se mantiene el mezclado `blendMode: 'tone'`, que usa el sistema nativo de Pokémon Essentials (sin capa RGB superpuesta).

No se han modificado las cuatro luces del mapa 79, los horarios de las farolas, los normal maps, los tiempos del reloj ni el saco de dormir. Los mapas antiguos que ya hayan guardado otra paleta conservarán sus valores personalizados; el preset nuevo se aplica a proyectos nuevos y al `maps.json` de esta rama.

Validación: pruebas del modelo para las cinco horas, la interpolación vespertina y la compatibilidad con el modo legado; pendiente comprobar tonalidad y FPS en el juego.
