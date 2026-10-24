# Nueva Pokédex — skins editables (Vermeil)

Carpeta: `Graphics/UI/Vermeil/NewPokedex/`. **Resolución del juego: 640 × 480 px, escala 1:1.**

| PNG | Medida exacta | Coordenada principal |
| --- | --- | --- |
| background | 640 × 480 | (0,0) |
| header | 256 × 44 | (24,12) |
| list_panel | 326 × 420 | (286,24) |
| portrait_panel | 256 × 256 | (24,56) |
| counter_panel | 256 × 48 | (24,320) |
| list_row | 326 × 36 | (0,y) sobre la lista; filas: y=20+40*n |
| list_row_selected | 326 × 36 | igual a list_row |
| scrollbar_track | 6 × 420 | (615,32) |
| entry_page | 640 × 480 | (0,0) |
| area_page | 640 × 480 | (0,0) |
| forms_page | 640 × 480 | (0,0) |

- La posición de cada fila es **local al bitmap de lista**, cuyo origen global es (286,24).
- Las páginas entry_page y forms_page deben dejar **alfa transparente (24,56) a (279,311)** para mostrar el retrato sin taparlo.
- **No insertar texto estático** dentro de los gráficos: nombres, estados, tipos, contadores y descripciones los dibuja la escena.
- En `000_Config.rb`: `NewPokedexConfig::CONFIG[:use_custom_ui] = true`. Si lo cambias a `false`, se usa el fallback procedural.
- Cada archivo es opcional e independiente, y se verifica su tamaño. Se carga al abrir la escena; volver a abrir recarga modificaciones.
- Usa PNG con transparencia RGBA. Los gráficos más pequeños (filas) no deberían estar llenos de efectos opacos que oculten el texto.
- La skin no modifica `Data/SpeciesDex/config.json`, el registro de formas ni las demás mecánicas.

Para las plantillas artísticas listas para editar, usa el ZIP `Vermeil_UI_Skin_Kit.zip` entregado junto con esta actualización.
