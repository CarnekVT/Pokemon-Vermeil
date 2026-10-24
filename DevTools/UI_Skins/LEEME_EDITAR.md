# Kit de skins UI — Pokémon Vermeil

Dos sistemas independientes de PNGs editables, diseñados para pantalla **640 × 480 px**, sin reescalar.

## Cómo instalar
1. Copia **la carpeta Graphics** de este ZIP a la carpeta raíz de `LA BASE DE SKY` de tu proyecto.
2. Los PNGs deben quedar exactamente en `Graphics/UI/Vermeil/NewPokedex/` y `Graphics/UI/Vermeil/ResearchNotebook/`.
3. Abre la Pokédex o Libreta. Si el PNG existe y mide lo indicado, se carga en lugar del dibujo de respaldo.
4. Para cambiar un gráfico edita su PNG en Photoshop, Clip Studio o software similar, guarda **PNG RGBA**, y vuelve a abrir la pantalla.

## Qué archivos editar
**NewPokedex**: `background` fondo global; `header` cabecera; `portrait_panel` recuadro de Pokémon; `list_panel`, `list_row`, `list_row_selected` lista; `counter_panel` contadores; `scrollbar_track`; `entry_page`, `area_page`, `forms_page` páginas.

**ResearchNotebook**: `background` papel abierto; `focus_panel` ficha focal; `grid_panel` base de casillas; `detail_panel` investigación; `grid_cell`, `grid_cell_selected`; `cover` tapa; `pages` hojas de animación; `tab_arcane`, `tab_golden` pestañas.

## Reglas de composición
- Edita los **PNG dentro de Graphics** (sin texto fijo: los nombres, números, estados, Pokémon, localizaciones y estadísticas se dibujan en ejecución).
- Las imágenes en **Plantillas_con_guias** son referencias visuales con cuadrícula cada 32 px, **NO** las copies al juego.
- Todos los PNG usan la resolución exacta registrada en **MEDIDAS_Y_CAPAS.json**. Un tamaño erróneo hace que el motor use su diseño de respaldo.
- `entry_page` y `forms_page` deben conservar el hueco alpha transparente x=24..279, y=56..311 para el sprite del Pokémon.
- El código tiene un interruptor: `NewPokedexConfig::CONFIG[:use_custom_ui]` y `ResearchNotebook::Settings::USE_CUSTOM_UI`.
- Puedes sustituir solo los componentes que quieras. El resto mantiene su fallback.
- No incluyas los nombres de Pokémon ni otras cifras dentro de los PNG: cambian según el progreso, idioma y forma.

## Notas
- `list_row*` mide 326×36 y se repite 10 veces.
- `grid_cell*` mide 58×63 y se repite hasta 25 veces.
- La tapa de la Libreta (`cover`) y sus páginas de animación (`pages`) miden **628×387**.
- La paleta es sugerida y totalmente editable: técnica oscura para Pokédex, papel/cuero para Libreta.
- Volver a abrir la pantalla recarga los PNG modificados. No hace falta alterar los JSON de especies o habilidades.
- Los PNG son ilustrativos; su apariencia final dentro del juego dependerá de sprites, fonts y capas de la versión de Essentials.
