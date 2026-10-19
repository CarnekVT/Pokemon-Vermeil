# Lighting Studio v0.4.3 · Hotfix de zoom y rendimiento

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
