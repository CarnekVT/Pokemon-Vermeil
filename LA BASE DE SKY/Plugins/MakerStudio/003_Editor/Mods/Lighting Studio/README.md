# Lighting Studio v0.4.2 — Pokémon Essentials 21.1

**Estado:** desarrollo experimental. Cambios en la rama `new-MK-for-2.5D-Testeo`. La API y las pruebas dentro de Maker Studio y Pokémon Essentials todavía requieren validación local.

## Flujo de trabajo

1. Abre un mapa y entra en **Mods > Lighting Studio**.
2. Comprueba que estén marcados **Iluminación activada para este mapa** y **Ver luces en mapa**.
3. Usa **Añadir luz** para colocar una fuente en el mapa; **Seleccionar** para arrastrarla o editarla; **Borrar** para eliminarla. La selección desde la lista también activa la herramienta.
4. Si el mapa es claro y no distingues la iluminación, activa **Vista nocturna (solo editor)**. El efecto temporal no altera `maps.json` ni el juego.
5. En **Superposición de luces** elige:
   - **Fusionar áreas · farolas (recomendado)**: dos fuentes amplían el área iluminada. Se aplica el máximo por canal, sin sumarse entre sí.
   - **Acumular brillo · suma**: las intensidades se añaden en la intersección.
6. El **Modo de mezcla** de cada luz determina si participa en la unión, si se suma independientemente, si se dibuja en modo normal o si oscurece.

## Inspector

Pestañas: **Forma**, **Difuminado**, **Pulsación**, **Pixel art**.

- Geometrías: radial, cono, elipse y rectángulo.
- Difuminado: desde centro, arriba, abajo, izquierda, derecha u origen personalizado.
- Pulsación independiente de intensidad y tamaño.
- Pixel art: tamaño de bloque y niveles del degradado.
- X/Y admite decimales hasta tres cifras. Los clics con el mouse todavía se ajustan a casillas.

## Ubicaciones

- Editor: `Plugins/MakerStudio/003_Editor/Mods/Lighting Studio/`.
- Runtime: `Plugins/Lighting Studio Runtime/`.
- Datos: `Data/LightingStudio/maps.json`.

El esquema de datos se mantiene en versión 1. Las antiguas luces con `blendMode: 'add'` se interpretan como `union`.

## Render y rendimiento

- El editor utiliza canvas DOM en lugar de OffscreenCanvas; mantiene una única superficie compartida y caché de máscaras, y conserva un fallback de dibujo si falla la composición.
- Las luces en modo `union` usan un máximo real por canal. `sum` aumenta el brillo intencionadamente.
- El runtime genera una superficie compartida a una cuarta parte de resolución y compone máximos leyendo las regiones iluminadas; es más costoso con muchas fuentes grandes.
- Las solicitudes de redibujado se agrupan. La barra de diagnóstico distingue tiempo de render y espera del editor.
- El zoom se proyecta siguiendo el cálculo de Animated Props. El posicionamiento preciso por píxel del mouse sigue pendiente.

## Comprobaciones antes de darlo por cerrado

1. Abre un mapa, crea una farola y actívala. Si no se ve, enciende **Vista nocturna (solo editor)**. Revisa los avisos de visibilidad.
2. Crea otra farola con solapamiento parcial. Compara **Fusionar áreas** y **Acumular brillo**.
3. Confirma que los colores, el radio, la geometría y el modo de difuminado cambian sobre el mapa.
4. Prueba zoom 50 %, 75 %, 100 %, 125 %, 150 % y 200 %, desplazando la cámara.
5. En el juego, prueba las mismas farolas, el scrolling, la transferencia entre mapas y F12.
6. Revisa los FPS y el diagnóstico del editor con 1, 5 y 20 luces.

## Limitaciones conocidas

- La preview y el runtime no tienen todavía equivalencia exacta de color, gamma, transparencia y tono ambiental.
- El runtime no utiliza shaders: la fusión por máximos tiene coste de CPU, especialmente con movimiento de cámara.
- Falta probar realmente Maker Studio y el plugin Ruby completo; **la visibilidad en el equipo del usuario no está confirmada**.
- No hay sombras físicas, oclusión de geometría ni seguimiento de eventos.
