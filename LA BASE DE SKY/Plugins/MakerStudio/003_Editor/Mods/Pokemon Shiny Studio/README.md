# Pokémon Shiny Studio v1.0.0

Mod de Maker Studio para crear, editar y administrar variantes de Shiny, SuperShiny y variantes personalizadas de Pokémon con sincronización a Pokémon Essentials v21.1.

## Características

- **Catálogo PBS**: Lee `PBS/pokemon.txt` y archivos adicionales `PBS/pokemon_*.txt`.
- **Variantes soportadas**:
  - **Normal**: `Graphics/Pokemon/Front/`, `Back/`, `Icons/`
  - **Shiny**: `Graphics/Pokemon/Front shiny/`, `Back shiny/`, `Icons shiny/`
  - **Super Shiny**: `Graphics/Pokemon/Front supershiny/`, `Back supershiny/`, `Icons supershiny/`
  - **Variantes personalizadas**: `Graphics/Pokemon/Front <id>/`, `Back <id>/`, `Icons <id>/`
- **Herramientas de edición**:
  - **Paleta Indexada**: Extrae colores únicos del sprite y permite cambiar cualquier color con un color picker en tiempo real.
  - **Ajuste HSL**: Deslizadores para Tono (Hue 0°-360°), Saturación (0%-200%) y Brillo (-50% a +50%).
  - **Sincronización de Iconos**: Aplica el mismo esquema de color automáticamente a los dos frames del icono animado.
  - **Sincronización de Back Sprites**: Aplica los mismos cambios al sprite trasero.
- **Creador de variantes**:
  - Crea nuevas variantes de shiny (por ejemplo: `cosmic`, `albino`, `radiant`) registrándolas en `Data/shiny_variants.json`.
  - Guarda automáticamente los assets PNG listos para ser consumidos por el runtime in-game.

## Atajo

- Menú `Mods` -> `Pokémon Shiny Studio` o `Ctrl+Shift+Y`.
