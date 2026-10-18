# Lighting Studio — MVP 0.1.0 (prototipo no validado en juego)

## Alcance realizado
- Mod Maker Studio con panel, selector de ID de mapa, lista, inspector, alta/baja de luces radiales, ajustes de color/intensidad/radio/suavidad, ambiente y undo/redo local.
- Herramienta para insertar fuentes por clic en mapa; Ctrl/Alt+clic elimina la fuente más cercana dentro de la tolerancia indicada.
- Overlay radial sobre el mapa, y vista auxiliar esquemática en panel.
- Guardado sin alterar mapas RXDATA: `Data/LightingStudio/maps.json`.
- Plugin runtime Ruby separado para oscurecimiento general y halos aditivos, sin sombras ni lightmap por GPU.

## Instalación
El mod está en `Plugins/MakerStudio/003_Editor/Mods/Lighting Studio/` y el runtime en `Plugins/Lighting Studio Runtime/`. No sustituir el núcleo de Maker Studio.
El runtime requiere que exista `JSON.parse`; en esta rama se encuentra `[CARNKEVT] JSON Compatibility`. Evitar `require 'json'` desde este plugin. Reiniciar Maker Studio y el juego después de instalar.
Abrir un mapa en Maker Studio y entrar a **Mods > Lighting Studio**. El ID del mapa puede ajustarse manualmente en el panel. Activar la herramienta **Luz radial** y hacer clic en el mapa.

## Limitaciones actuales
- No ejecutado dentro de Maker Studio ni Pokémon Essentials. Las integraciones deben validarse en una copia de la partida/proyecto.
- El overlay en editor NO es una simulación fiel del renderer Ruby; no oscurece correctamente el mapa real.
- Runtime de halos aditivos y capa oscura, NO iluminación físicamente correcta, ni luz sobre tiles con oclusión.
- La transparencia/color ambiental se reducen a una capa oscura en runtime; el color ambiental es todavía orientativo.
- Un único tipo de luz (radial), fuentes estáticas; las propiedades de suavidad y radio se muestran, pero el renderer avanzado se diseñará después.
- Renderizar gradientes pixel a pixel es costoso al entrar en mapas con radios grandes. No usar decenas de focos de radio 512 px sin optimización previa.
- No hay manipulación drag / gizmos todavía; las posiciones se afinan en inspector o con nueva inserción.
- El plugin no exporta datos RXDATA y no migra datos de otros plugins.
- Los datos no se recargan dentro de un mapa del juego sin transferir/reiniciar (prototipo).
- Riesgo de orden de dibujo frente a climas/UI/properties que exige pruebas.

## Checklist de validación manual
1. Iniciar Maker Studio, abrir mapa y comprobar que menú, panel y herramienta se registran sin errores.
2. Insertar luz; editar radio/color/intensidad; cambiar de mapa y volver; reiniciar editor y verificar guardado.
3. Probar deshacer y rehacer después de añadir, cambiar y eliminar fuentes.
4. Abrir el juego en ese mapa y verificar compatibilidad visual en interiores, exteriores, lluvia y mapas con Animated Props.
5. Verificar F12 y transferencias sucesivas buscando recursos no liberados.
6. Medir FPS/tiempo al generar gradientes para 1/5/20 luces con radio 32/96/256.
7. Confirmar que la capa oscura no afecta indebidamente a UI, menus y efectos meteorológicos.
8. Comparar zoom, scrolling, ancho/alto de pantalla y posiciones con escenarios reales.

## Siguiente paso técnico
Antes de implementar sombras/timeline, reemplazar el sistema aproximado de halos por un compositor de luz probado en la versión real de RGSS/mkxp del proyecto; añadir preview fiel basado en la misma matemática, interacciones de selección/arrastre, y sincronización robusta con la selección del mapa.
