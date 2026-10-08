#===============================================================================
# [ZBOX] Nueva Pokédex - Configuración Unificada
#===============================================================================
module NewPokedexConfig
  # Configuration hash for easy serialization and future extensions
  CONFIG = {
    # Custom Dex names per region (fallback to PBS/auto if missing)
    :custom_dex_names => {
      0 => "Pokédex Regional",
      1 => "Pokédex Nacional",
      2 => "Pokédex Especial"
    },
    # Paths to Dex JSON data
    :dex_json_path => "Data/Pokedex/dexes.json",
    :dex_json_dir  => "Data/Pokedex",
    # Audio / Gamefeel options
    :play_cursor_se   => true,
    :play_decision_se => true,
    :play_cancel_se   => true,
    :play_cry_on_action => true,
    # UI colors
    :color_highlight => Color.new(235, 75, 75),
    :color_text_main => Color.new(245, 245, 245),
    :color_text_muted => Color.new(170, 175, 185),
    :color_seen => Color.new(120, 180, 255),
    :color_owned => Color.new(80, 230, 120),
    # New optional features
    # New optional features
    :show_search_bar => false,   # toggle quick‑search input in the header
    :show_form_names => true,   # display form name instead of F-label
    :use_shiny_toggle => true,   # enable per‑Pokémon shiny toggle
    :use_supershiny_toggle => true,   # enable supershiny toggle
    :forms_visual_only => false,   # when true, form selection is preview only
    :enable_back_sprite_button => true,   # enable back‑sprite button in forms/shiny view
    :background_image => nil,    # path to optional background PNG relative to Graphics/UI
    :use_placeholder_bg => true,
    :use_placeholder_header => true,
    :use_placeholder_list_bg => true,
    :use_placeholder_scrollbar => true,
    :use_placeholder_sprite_bg => true,
    :hide_location_sprite => false,   # hide Pokémon sprite in location view
    :show_form_names => true,   # display form name instead of F-label
    :use_shiny_toggle => true,   # enable per‑Pokémon shiny toggle
    :use_supershiny_toggle => true,   # enable supershiny toggle
    :background_image => nil,    # path to optional background PNG relative to Graphics/UI
    :use_placeholder_bg => true,
    :use_placeholder_header => true,
    :use_placeholder_list_bg => true,
    :use_placeholder_scrollbar => true,
    :use_placeholder_sprite_bg => true,
    :hide_location_sprite => false,   # hide Pokémon sprite in location view
  }

  # Backward‑compatible constants (used by existing code)
PLAY_CURSOR_SE   = CONFIG[:play_cursor_se]
PLAY_DECISION_SE = CONFIG[:play_decision_se]
PLAY_CANCEL_SE   = CONFIG[:play_cancel_se]
PLAY_CRY_ON_ACTION = CONFIG[:play_cry_on_action]
COLOR_HIGHLIGHT   = CONFIG[:color_highlight]
COLOR_TEXT_MAIN   = CONFIG[:color_text_main]
COLOR_TEXT_MUTED  = CONFIG[:color_text_muted]
COLOR_SEEN        = CONFIG[:color_seen]
COLOR_OWNED       = CONFIG[:color_owned]
DEX_JSON_PATH    = CONFIG[:dex_json_path]
DEX_JSON_DIR     = CONFIG[:dex_json_dir]



  
  
  COLOR_TEXT_MAIN   = CONFIG[:color_text_main]
  COLOR_TEXT_MUTED  = CONFIG[:color_text_muted]
  COLOR_SEEN        = CONFIG[:color_seen]
  COLOR_OWNED       = CONFIG[:color_owned]

  # Helper to fetch Dex name with fallback
  def self.dex_name(dex_id)
    names = CONFIG[:custom_dex_names]
    return names[dex_id] if names.key?(dex_id)
    if defined?(pbGetMessage) && defined?(MessageTypes::REGIONAL_DEX_NAMES)
      name = pbGetMessage(MessageTypes::REGIONAL_DEX_NAMES, dex_id) rescue nil
      return name if name && !name.empty?
    end
    return "Pokédex #{dex_id + 1}"
  end
end
