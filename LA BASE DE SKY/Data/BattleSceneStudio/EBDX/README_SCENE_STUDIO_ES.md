# EBDX Studio / Background Composer

`bundled_scenes.json` queda reservado para futuros presets BSS curados. Los presets provisionales fueron retirados en v0.8.12 para no llenar la biblioteca con escenarios que no alcanzaban la calidad visual esperada.

Los escenarios creados o duplicados por el usuario se guardan en `scenes.json`. Las asignaciones por mapa se guardan en `map_metadata.json`. Estos dos archivos no forman parte del ZIP de actualización: una actualización de BSS no debe sobrescribir escenas ni asignaciones del proyecto.

## Flujo actual

1. EBDX Studio → Fondos abre el Background Composer.
2. La biblioteca de fondos es un drawer (`☰ Fondos`) y no roba espacio mientras editas.
3. El panel izquierdo `Capas / + Elementos` es ajustable de ancho. Se puede ocultar temporalmente.
4. El Outliner se ordena de frente a fondo y permite subir, bajar, mandar al frente/fondo o arrastrar filas para cambiar profundidad Z.
5. El canvas usa la cuadrícula lógica EBDX 384×308. Se puede seleccionar y arrastrar una capa haciendo clic sobre el área de la imagen, no solo sobre su origen. `Alt+clic` recorre capas superpuestas.
6. La barra rápida mantiene X, Y, Z y escala X/Y de la selección al lado del canvas.
7. El inspector derecho se divide en `Capa` y `Escena`, es ajustable de ancho y se puede ocultar para dar más espacio al canvas.
8. `Shift` usa precisión de 1 px. Las flechas mueven la selección; `Ctrl+↑/↓` cambia profundidad y `Ctrl+Shift+↑/↓` manda al frente/fondo.
9. Undo/Redo es local a cada escena.
10. Los recursos de `Graphics/BattleSceneStudio/EBDX/SceneAssets` son piezas de composición, no fondos completos.
11. Config → Fondos por mapa guarda las asignaciones por Map ID.

La preview se reconstruye desde la misma definición de escena y ahora respeta Z entre capas `img###`. El runtime normaliza las propiedades internas del JSON al esquema de EBDX original para que las capas y sus comportamientos se interpreten correctamente en juego.
