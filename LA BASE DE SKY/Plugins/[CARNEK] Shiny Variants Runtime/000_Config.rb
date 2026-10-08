#===============================================================================
# [CARNEK] Shiny Variants Runtime - Configuración
#===============================================================================
module ShinyVariantsSettings
  # Activar el soporte para variantes personalizadas y resolución de sprites/iconos
  ENABLED = true

  # Archivo de configuración generado por MakerStudio (Pokemon Shiny Studio)
  CONFIG_FILE = "Data/shiny_variants.json"

  # Carpeta donde se pueden colocar insignias/iconos personalizados para la UI (Summary/Party)
  # Ejemplo: Graphics/UI/ShinyVariants/cosmic.png
  BADGES_DIR = "Graphics/UI/ShinyVariants/"

  # Probabilidad de aparición de variantes especiales en Pokémon salvajes generados (1 en N)
  # Si una variante en Data/shiny_variants.json define su propio "rate", se usará ese.
  DEFAULT_VARIANT_CHANCE = 655360

  # Log detallado en consola de debug al resolver gráficos
  DEBUG_LOG = false
end
