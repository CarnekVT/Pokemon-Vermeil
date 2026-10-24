# Libreta de Investigación — skins editables

Carpeta: `Graphics/UI/Vermeil/ResearchNotebook/`. **Pantalla: 640 × 480 px**, sin escala automática.

| PNG | Medida exacta | Coordenada principal |
| --- | --- | --- |
| background | 640 × 480 | (0,0) |
| focus_panel | 294 × 368 | (14,62) |
| grid_panel | 306 × 348 | (320,76) |
| detail_panel | 306 × 365 | (320,61) |
| grid_cell | 58 × 63 | cada celda desde (325,76), separación 61×66 |
| grid_cell_selected | 58 × 63 | igual, según selección |
| cover | 628 × 387 | (6,55) |
| pages | 628 × 387 | (6,55) |
| tab_arcane | 149 × 37 | (318,8) si hay dos pestañas |
| tab_golden | 149 × 37 | (471,8) si hay dos pestañas |

- Los sprites de Pokémon, tipos, nombres, cifras, estados y contenido de la Libreta se dibujan **sobre los PNGs** desde Ruby.
- Nunca dibujar nombres de habilidades o especies como parte de un asset, pues cambian con el progreso.
- Las casillas se repiten hasta 25 veces; cuanto más transparentes las decoraciones centrales, más legible el icono de la especie.
- `cover.png` dibuja el cuero/fondo de la tapa pero **no tiene texto preimpreso**: el motor coloca su título y efecto al abrir.
- Configuración: `ResearchNotebook::Settings::USE_CUSTOM_UI = true` en `001_research_notebook_config.rb`.
- Archivos faltantes o con tamaño erróneo regresan al aspecto dibujado por código y no interrumpen el juego.
- Los datos originales Golden/Arcane/ChangeDex y los guardados no se alteran.

El ZIP `Vermeil_UI_Skin_Kit.zip` contiene PNGs limpios, copias con cuadrícula de medidas, vistas previas, y el script para regenerar el kit.
