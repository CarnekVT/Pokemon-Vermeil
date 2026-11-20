# Vermeil: Libreta y Pokédex en MakerStudio

Abrir **MakerStudio > Mods > Abrir el Editor de Interfaces**. Los seis diseños
`vermeil_*` aparecen junto con las interfaces normales. Trabajan a **640 × 480**,
como el juego en `mkxp.json`. Guardar la escena JSON y volver a abrir la
Libreta o la Pokédex para ver los cambios (no se necesita recompilar Ruby).

## Pantallas

| Diseño | Función |
| --- | --- |
| `vermeil_libreta` | portada, panel focal, cuadrícula, centro del Pokémon y pestañas |
| `vermeil_libreta_detalle` | panel derecho de la ficha; comparte el panel focal de la Libreta |
| `vermeil_pokedex_lista` | paneles, lista, contadores, scrollbar y posición del Pokémon |
| `vermeil_pokedex_ficha` | página de ficha, zona transparente de sprite, cuadro descriptivo |
| `vermeil_pokedex_area` | fondo de localizaciones |
| `vermeil_pokedex_formas` | fondo de formas; comparte la zona del sprite de la ficha |

## Qué modifica y qué no

- Los **X/Y de elementos vinculados** se leen al abrir las escenas.
- El tiempo **Entrada > Duración** de `cover` controla la apertura de la
  Libreta; `grid_panel` y `detail_panel` ajustan la duración del paso de página.
- El tiempo de entrada de `entry_page`, `area_page` y `forms_page` ajusta
  la transición de esas vistas en la Pokédex.
- `focus_sprite` y `portrait_pokemon` son **marcadores de punto**, no
  decoración real. Sirven para mover los sprites de Pokémon desde el editor.
- Los elementos del editor son una **guía visual** de la disposición; las
  pantallas conservan el dibujado y las interacciones existentes en Ruby.
  Esto no convierte cada texto, barra y celda en un sprite independiente.
- La apariencia de los PNG existentes sigue controlada por
  `ResearchNotebook::Settings::USE_CUSTOM_UI` y
  `NewPokedexConfig::CONFIG[:use_custom_ui]`; mover una imagen en MakerStudio
  no activa por sí mismo una skin ni reemplaza los textos y datos dinámicos.
- Algunos valores de `ancho/alto`, `capa`, animaciones de rotación, etc.
  todavía los decide el runtime. **Solo los atributos documentados arriba están
  enlazados**. No modificar el progreso de especies, habilidades, forms o
  el JSON de SpeciesDex desde los diseños.

## Pruebas rápidas

1. Abrir Libreta y recorrer páginas de más de 25 especies, alternar Arcano /
   Áureo y abrir una ficha. Los iconos de la página deben estar listos al mostrarse.
2. Mover provisionalmente `focus_sprite` 8 px y comprobar su coordenada
   en la Libreta; revertirla al terminar.
3. Mover `list_panel` 8 px en la Pokédex y comprobar que fondo y filas siguen
   juntos. Probar lista, ficha, área y formas.
4. En un combate, abrir Luchar, cancelar a comandos, entrar en Mochila,
   salir y comprobar el encuadre general.
5. Probar introducciones salvajes y de entrenador, confirmar ausencia de
   cuadrados negros, desplazamiento desde fuera de pantalla y profundidad
   del entrenador. Comprobar animaciones nativas DBK / BAS.

**Nota:** Estas modificaciones pasan comprobaciones estáticas de archivos y JSON.
No sustituyen una prueba en el Game.exe de Windows con partidas reales.
