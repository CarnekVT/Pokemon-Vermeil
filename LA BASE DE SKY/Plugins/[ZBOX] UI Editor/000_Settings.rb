# encoding: utf-8
module ZBOX_UIEditor
  module Settings
    OVERRIDES_FILE = "UI_Editor_Overrides.json"
    SCREEN_W = ::Settings::SCREEN_WIDTH
    SCREEN_H = ::Settings::SCREEN_HEIGHT

    SCREENS = {
      pc_storage: {
        label: "PC Storage",
        elements: [
          { klass: "PokemonBoxSprite",      const: :BOX_X,                     label: "Caja X",       visual: :pos_x, group: :box },
          { klass: "PokemonBoxSprite",      const: :BOX_Y,                     label: "Caja Y",       visual: :pos_y, group: :box },
          { klass: "PokemonBoxSprite",      const: :BOX_WIDTH,                 label: "Ancho caja",   visual: :size_w, group: :box },
          { klass: "PokemonBoxSprite",      const: :BOX_HEIGHT,                label: "Alto caja",    visual: :size_h, group: :box },
          { klass: "PokemonBoxSprite",      const: :POKEMON_BOX_SPRITE_X_OFFSET, label: "Grilla X",   visual: :pos_x, group: :grid },
          { klass: "PokemonBoxSprite",      const: :POKEMON_BOX_SPRITE_Y_OFFSET, label: "Grilla Y",   visual: :pos_y, group: :grid },
          { klass: "PokemonBoxSprite",      const: :POKEMON_BOX_SPRITE_X_SPACING, label: "Esp. X",    visual: :val, group: :grid },
          { klass: "PokemonBoxSprite",      const: :POKEMON_BOX_SPRITE_Y_SPACING, label: "Esp. Y",    visual: :val, group: :grid },
          { klass: "PokemonBoxSprite",      const: :BOX_NAME_X_OFFSET,         label: "Nom. caja X",  visual: :pos_x, group: :name },
          { klass: "PokemonBoxSprite",      const: :BOX_NAME_Y,                label: "Nom. caja Y",  visual: :pos_y, group: :name },
        ]
      },
      pc_storage_scene: {
        label: "Panel info PC",
        elements: [
          { klass: "PokemonStorageScene",   const: :POKEMON_SPRITE_X,          label: "Sprite PKMN X", visual: :pos_x, group: :sprite },
          { klass: "PokemonStorageScene",   const: :POKEMON_SPRITE_Y,          label: "Sprite PKMN Y", visual: :pos_y, group: :sprite },
          { klass: "PokemonStorageScene",   const: :POKENAME_TEXT_X,           label: "Nombre X",     visual: :pos_x, group: :text },
          { klass: "PokemonStorageScene",   const: :POKENAME_TEXT_Y,           label: "Nombre Y",     visual: :pos_y, group: :text },
          { klass: "PokemonStorageScene",   const: :LEVEL_ICON_X,              label: "Nivel icono X", visual: :pos_x, group: :level },
          { klass: "PokemonStorageScene",   const: :LEVEL_ICON_Y,              label: "Nivel icono Y", visual: :pos_y, group: :level },
          { klass: "PokemonStorageScene",   const: :LEVEL_NUMBER_X,            label: "Nivel num X",  visual: :pos_x, group: :level },
          { klass: "PokemonStorageScene",   const: :LEVEL_NUMBER_Y,            label: "Nivel num Y",  visual: :pos_y, group: :level },
          { klass: "PokemonStorageScene",   const: :ABILITY_NAME_X,            label: "Habilidad X",  visual: :pos_x, group: :ability },
          { klass: "PokemonStorageScene",   const: :ABILITY_NAME_Y,            label: "Habilidad Y",  visual: :pos_y, group: :ability },
          { klass: "PokemonStorageScene",   const: :ITEM_NAME_X,               label: "Objeto X",     visual: :pos_x, group: :item },
          { klass: "PokemonStorageScene",   const: :ITEM_NAME_Y,               label: "Objeto Y",     visual: :pos_y, group: :item },
          { klass: "PokemonStorageScene",   const: :SHINY_ICON_X,              label: "Shiny X",      visual: :pos_x, group: :shiny },
          { klass: "PokemonStorageScene",   const: :SHINY_ICON_Y,              label: "Shiny Y",      visual: :pos_y, group: :shiny },
          { klass: "PokemonStorageScene",   const: :TYPE_ICON_X_1,             label: "Tipo 1 X",     visual: :pos_x, group: :type },
          { klass: "PokemonStorageScene",   const: :TYPE_ICON_X_2,             label: "Tipo 2 X",     visual: :pos_x, group: :type },
          { klass: "PokemonStorageScene",   const: :TYPE_ICON_Y,               label: "Tipo Y",       visual: :pos_y, group: :type },
          { klass: "PokemonStorageScene",   const: :MARKINGS_X,                label: "Marcas X",     visual: :pos_x, group: :marks },
          { klass: "PokemonStorageScene",   const: :MARKINGS_Y,                label: "Marcas Y",     visual: :pos_y, group: :marks },
          { klass: "PokemonStorageScene",   const: :GENDER_ICON_TEXT_X,        label: "Género X",     visual: :pos_x, group: :text },
          { klass: "PokemonStorageScene",   const: :GENDER_ICON_TEXT_Y,        label: "Género Y",     visual: :pos_y, group: :text },
        ]
      },
      summary: {
        label: "Resumen",
        elements: [
          { klass: "PokemonSummary_Scene",  const: :UI_POKEMON_SPRITE_X,       label: "Sprite PKMN X", visual: :pos_x, group: :sprite },
          { klass: "PokemonSummary_Scene",  const: :UI_POKEMON_SPRITE_Y,       label: "Sprite PKMN Y", visual: :pos_y, group: :sprite },
          { klass: "PokemonSummary_Scene",  const: :UI_POKEICON_X,             label: "Icono X",       visual: :pos_x, group: :icon },
          { klass: "PokemonSummary_Scene",  const: :UI_POKEICON_Y,             label: "Icono Y",       visual: :pos_y, group: :icon },
          { klass: "PokemonSummary_Scene",  const: :TEXT_NAME_X,               label: "Nombre X",      visual: :pos_x, group: :text },
          { klass: "PokemonSummary_Scene",  const: :TEXT_NAME_Y,               label: "Nombre Y",      visual: :pos_y, group: :text },
          { klass: "PokemonSummary_Scene",  const: :TEXT_LEVEL_X,              label: "Nivel X",       visual: :pos_x, group: :level },
          { klass: "PokemonSummary_Scene",  const: :TEXT_LEVEL_Y,              label: "Nivel Y",       visual: :pos_y, group: :level },
          { klass: "PokemonSummary_Scene",  const: :UI_ITEMICON_X,             label: "Obj.icono X",   visual: :pos_x, group: :item },
          { klass: "PokemonSummary_Scene",  const: :UI_ITEMICON_Y,             label: "Obj.icono Y",   visual: :pos_y, group: :item },
          { klass: "PokemonSummary_Scene",  const: :TEXT_GENDER_X,             label: "Género X",      visual: :pos_x, group: :text },
          { klass: "PokemonSummary_Scene",  const: :TEXT_GENDER_Y,             label: "Género Y",      visual: :pos_y, group: :text },
          { klass: "PokemonSummary_Scene",  const: :IMG_SHINY_X,               label: "Shiny X",       visual: :pos_x, group: :shiny },
          { klass: "PokemonSummary_Scene",  const: :IMG_SHINY_Y,               label: "Shiny Y",       visual: :pos_y, group: :shiny },
        ]
      },
      summary_cursor: {
        label: "Cursor movimientos",
        elements: [
          { klass: "MoveSelectionSprite",   const: :CURSOR_BASE_X,             label: "Cursor X",       visual: :pos_x, group: :cursor },
          { klass: "MoveSelectionSprite",   const: :CURSOR_BASE_Y,             label: "Cursor Y",       visual: :pos_y, group: :cursor },
          { klass: "MoveSelectionSprite",   const: :CURSOR_OFFSET_Y,           label: "Offset Y",       visual: :val, group: :cursor },
        ]
      },
      party: {
        label: "Equipo",
        elements: [
          { klass: "PokemonBoxPartySprite", const: :PARTY_BOX_X,               label: "Panel X",        visual: :pos_x, group: :box },
          { klass: "PokemonBoxPartySprite", const: :PARTY_BOX_Y_OFFSET,        label: "Panel Y offset", visual: :val, group: :box },
          { klass: "PokemonBoxPartySprite", const: :PARTY_ICON_X_START,        label: "Iconos X start", visual: :pos_x, group: :icons },
          { klass: "PokemonBoxPartySprite", const: :PARTY_ICON_X_SPACING,      label: "Iconos esp X",   visual: :val, group: :icons },
          { klass: "PokemonBoxPartySprite", const: :PARTY_ICON_Y_START,        label: "Iconos Y start", visual: :pos_y, group: :icons },
          { klass: "PokemonBoxPartySprite", const: :PARTY_ICON_Y_SPACING,      label: "Iconos esp Y",   visual: :val, group: :icons },
        ]
      },
    }
  end
end
