#===============================================================================
# [ZBOX] Nueva Pokédex - Configuración Unificada
#===============================================================================
module NewPokedexConfig
  # Nombres personalizados por índice de Pokédex regional
  # Si no se define uno, tomará el nombre de PBS o fallback automático
  CUSTOM_DEX_NAMES = {
    0 => "Pokédex Regional",
    1 => "Pokédex Nacional",
    2 => "Pokédex Especial"
  }

  # Ruta relativa de archivos JSON de Pokédex
  DEX_JSON_PATH = "Data/Pokedex/dexes.json"
  DEX_JSON_DIR  = "Data/Pokedex"

  # Opciones de Gamefeel y Audio
  PLAY_CURSOR_SE   = true
  PLAY_DECISION_SE = true
  PLAY_CANCEL_SE   = true
  PLAY_CRY_ON_ACTION = true

  # Color de resalto para cursor y textos
  COLOR_HIGHLIGHT   = Color.new(235, 75, 75)
  COLOR_TEXT_MAIN   = Color.new(245, 245, 245)
  COLOR_TEXT_MUTED  = Color.new(170, 175, 185)
  COLOR_SEEN        = Color.new(120, 180, 255)
  COLOR_OWNED       = Color.new(80, 230, 120)

  # Función helper para nombres de Dex
  def self.dex_name(dex_id)
    return CUSTOM_DEX_NAMES[dex_id] if CUSTOM_DEX_NAMES.key?(dex_id)
    if defined?(pbGetMessage) && defined?(MessageTypes::REGIONAL_DEX_NAMES)
      name = pbGetMessage(MessageTypes::REGIONAL_DEX_NAMES, dex_id) rescue nil
      return name if name && !name.empty?
    end
    return "Pokédex #{dex_id + 1}"
  end
end
