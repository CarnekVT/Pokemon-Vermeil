# Interface Studio 1.0.0

Editor visual de interfaces para Maker Studio / Pokémon Vermeil.

## Abrir

Maker Studio → Mods → Interface Studio. El editor abre en panel amplio y ofrece modo pantalla completa / ventana normal.

## Flujo

1. Crea o elige una pantalla en Biblioteca. Define nombre y resolución (640×480, 512×384, panorámica o libre).
2. Añade paneles, textos o imágenes. La biblioteca escanea PNG/JPG/BMP/WEBP del proyecto en Graphics/UI.
3. Selecciona una capa, arrastra para mover o tira del manipulador inferior derecho para redimensionar. Modifica las propiedades en Inspector.
4. Usa ↑ / ↓ para cambiar el orden, ◉ para mostrar/ocultar, ◇ para bloquear/desbloquear, y Duplicar/Eliminar para administrar capas.
5. Guarda para crear Data/InterfaceStudio/layouts.json. Los cambios no pisan código Ruby existente.
6. «Ruby…» genera un método por pantalla para colocar sprites, paneles y textos en una escena de Pokémon Essentials. Copia el código dentro de tu plugin y llama al método desde tu escena. No se inyecta código a los scripts del juego.

## Atajos

Ctrl+S guardar · Ctrl+Z deshacer · Ctrl+Y rehacer · Ctrl+D duplicar capa · Supr borrar · Flechas mover 1 px · Mayús+flechas mover 8 px · Escape deseleccionar.

## Compatibilidad y límites

La vista previa usa imágenes reales del proyecto si el backend Tauri permite leer binarios. Si no están disponibles, muestra un placeholder visible, nunca una imagen falsa. Los paneles y textos se aproximan visualmente al layout; no implementan automáticamente las rutinas, fuentes específicas, ventanas animadas o renderers propios de otras interfaces.

El editor conserva todos los archivos originales y no altera UI del juego hasta que integres explícitamente el código Ruby generado. Si el JSON existente está corrupto, activa solo lectura para evitar sobrescribirlo. Las dimensiones se expresan en píxeles del juego. El editor fue diseñado con el patrón Biblioteca/Visor/Inspector inspirado en BAS/BSS.
