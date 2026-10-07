# Pokémon Icon Studio v0.2.1

Mod de Maker Studio para administrar icons de Pokémon directamente desde el proyecto.

## Catálogo

- `PBS/pokemon.txt` se muestra primero y conserva su orden interno.
- Después se leen los demás `pokemon_*.txt` en orden alfabético por nombre de archivo, conservando el orden interno de cada PBS.
- Las formas de una especie existente se agregan a esa especie sin crear duplicados.
- La preview de la lista usa siempre el icon exacto de **Forma 0 / Normal / Male**. No toma por accidente una forma, Female o Shiny como thumbnail base.

## Variantes soportadas

Respeta la convención de Pokémon Essentials v21.1:

- Normal: `Graphics/Pokemon/Icons/SPECIES.png`
- Forma: `Graphics/Pokemon/Icons/SPECIES_1.png`
- Female: `Graphics/Pokemon/Icons/SPECIES_female.png`
- Forma Female: `Graphics/Pokemon/Icons/SPECIES_1_female.png`
- Shiny: `Graphics/Pokemon/Icons shiny/SPECIES.png`
- Shiny Female/Forma: `Graphics/Pokemon/Icons shiny/SPECIES_1_female.png`

El inspector permite cambiar **Forma**, **Sexo** y **Shiny**. Si una variante exacta no existe, **Crear desde base** usa el fallback compatible disponible como plantilla y guarda en la ruta exacta de la variante seleccionada.

## Frames y posicionamiento

- Frame 1 / Frame 2.
- Arrastrar para mover.
- Flechas: 1 px.
- Shift + flechas: 5 px.
- Copiar posición 1→2 / 2→1.
- Copiar gráfico 1→2 / 2→1.
- Mover ambos frames juntos.
- Centrar por contenido visible.
- Diagnóstico de clipping.
- Undo/Redo.

## Preview

- Preview animada Frame 1 ↔ Frame 2.
- Onion Skin configurable.
- Fondo del lienzo: **Claro (gris medio)**, **Negro** o **Custom**.
- El color del preview nunca se escribe dentro del PNG.
- Guías de centro opcionales.

## Lienzo e importación

El tamaño de cada frame puede cambiarse manualmente desde el inspector.

- Ancho y alto de frame editables.
- El resize conserva el contenido centrado.
- Opción **Expandir lienzo si la imagen no cabe**.
- Modo de pegar/importar:
  - Automático.
  - Frame actual.
  - Icon completo.

Esto permite pegar una imagen más grande de lo normal sin que el Studio la recorte ni la interprete obligatoriamente como un spritesheet.

## Navegación

El botón **↳ Seleccionado** vuelve inmediatamente al Pokémon actualmente seleccionado dentro de la lista. Si un filtro o búsqueda lo ocultaba, restablece la lista antes de centrarlo.

## Portapapeles / archivos

- Copiar frame.
- Copiar icon completo.
- Pegar desde portapapeles.
- Importar PNG.
- Drag & drop.
- Exportar PNG.
- Guardar sobre el asset actual.
- Guardar como ID/forma/sexo/shiny correctos.

## Confirmaciones

No usa `window.confirm` ni el plugin Tauri Dialog. Las confirmaciones de descarte son modales internos del Studio, evitando errores de ACL como `plugin:dialog|confirm not allowed by ACL`.

## Runtime

No necesita runtime Ruby. Lee PBS/assets reales y escribe directamente los PNG mediante el backend binario de Maker Studio/Tauri, con fallbacks para builds compatibles.

## v0.2.1
- Corregido **↳ Seleccionado**: ahora centra el Pokémon exclusivamente dentro del navegador de especies.
- Eliminado `scrollIntoView` para impedir que Maker Studio desplace la ventana/panel general y cambie la posición visual del lienzo.
