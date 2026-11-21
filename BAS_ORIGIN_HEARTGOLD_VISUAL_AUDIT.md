# Origin HeartGold: auditoría visual y oportunidades para Battle Animation Studio

Fecha: 2026-11-21. Fuente pública: https://github.com/originheartgold/originheartgold.github.io (árbol `main`, SHA `63e8ae6b737a13c287965440a8b1c1de46f04fc2`).

## Qué contiene realmente la web pública

- Página publicada: https://originheartgold.github.io/
- Construida con Astro 7.3.5 / Starlight 0.42.5 (identificado en HTML publicado).
- Árbol GitHub: 32,395 entradas, sin truncar. La carpeta `preview/` es una segunda compilación del sitio, no otra biblioteca independiente de animaciones.
- Versión principal, excluyendo `preview/`: 294 archivos de imagen (280 WebP, 12 PNG y 2 SVG), concentrados en `_astro/`, iconografía, páginas de guía, mapas/localizaciones y recursos de presentación.
- **No hay ficheros GIF, APNG, MP4 o WebM en el árbol publicado.** No se halló una carpeta fuente de animaciones editables, ni assets exportados de batalla. La información de movimientos en `moves/` consta principalmente de páginas HTML y no es un pack de animaciones de Essentials.
- Los medios visuales de la web se pueden consultar públicamente en la sección `_astro/`, y la página principal del sitio ofrece los enlaces navegables al catálogo completo. Los recursos del juego DS/ROM y los `.xdelta` no son assets de BAS ni se importarán.

## Criterio de integración

1. Usar las páginas de movimientos **como referencias documentales**, nunca deducir timelines, partículas o sprites a partir de fichas de texto.
2. No importar imágenes estáticas de mapas o guías automáticamente como efectos.
3. No distribuir automáticamente material visual de terceros en el paquete BAS sin verificar derechos y compatibilidad.
4. Si se proporciona una fuente real de capturas/fotogramas de movimientos, crear una biblioteca separada de **referencias** (con URL y atribución), no sobrescribir las 22 animaciones existentes ni los 77 presets.
5. Mantener `PBS/AnimationStudio/animations.json`, `compiled_animations.json` y el runtime Ruby intactos mientras no existan pruebas interactivas.

## Optimizaciones implementadas en esta rama

- `model.js`: `sortPositionKeys` / `sortValueKeys` evitan ejecutar `.sort()` cuando las claves ya están ordenadas; siguen ordenando arrays desordenados como antes.
- `model.js`: `sampleVisible` obtiene el estado discreto directamente sin copiar y ordenar el array en cada frame. Las claves fuera de orden y los duplicados conservan la precedencia de la última clave equivalente.
- `preview.js`: la caché acotada de imágenes con tone/color pasa a actualizar la recencia de las entradas utilizadas (LRU) antes de expulsar elementos. El límite existente de 256 se mantiene.
- No se modifican modelos de datos, archivos de animación, prefabs, presets, ni el runtime Ruby.

## Validación

- Comparación determinista de comportamiento del muestreo de visibilidad: 12.000 casos.
- Comparación determinista de ordenación de claves: 500 casos.
- Sin diferencias en las pruebas de equivalencia anteriores.
- Pendiente: prueba de arranque en la aplicación Maker Studio, reproducción real con partículas, cambios de claves arrastradas y validación visual en Essentials 21.1. Estas comprobaciones requieren el entorno del juego y no se consideran aprobadas aquí.

## Siguientes pasos para animaciones auténticas

Localizar el proyecto fuente que contiene fotogramas o capturas reales del hack (si existe y está accesible), documentar licencia/autores, indexar cada animación con nombre del movimiento, generación, duración, fotogramas y referencia visual, y comparar la trayectoria/impacto con los 77 presets existentes de BAS. No confundir **catálogo de movimientos** con **biblioteca de animaciones**.
