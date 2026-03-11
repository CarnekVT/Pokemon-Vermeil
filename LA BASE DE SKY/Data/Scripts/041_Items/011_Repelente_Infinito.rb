#===============================================================================
# Infinite Repel by dpertierra
# https://github.com/Pokemon-Fan-Games/InifiniteRepel
# https://twitter.com/dpertierra
#
# NOTA: La lógica de infRepel está integrada en:
# - 037_Overworld/003_Overworld_Metadata.rb (attr_accessor :infRepel)
# - 037_Overworld/002_Overworld.rb (repel_active incluye infRepel)
#===============================================================================

def pbToggleInfiniteRepel()
  $PokemonGlobal.infRepel ||= false
  if !$PokemonGlobal.infRepel
    pbMessage("Se activó el repelente infinito.")
    $bag.replace_item(:INFREPELOFF, :INFREPEL)
    $bag.replace_registered(:INFREPELOFF, :INFREPEL)
  else
    pbMessage("Se desactivó el repelente infinito.")
    $bag.replace_item(:INFREPEL, :INFREPELOFF)
    $bag.replace_registered(:INFREPEL, :INFREPELOFF)
  end
  $PokemonGlobal.infRepel = !$PokemonGlobal.infRepel
  return 0
end

ItemHandlers::UseFromBag.add(:INFREPEL,proc{|item| pbToggleInfiniteRepel() })
ItemHandlers::UseFromBag.add(:INFREPELOFF,proc{|item| pbToggleInfiniteRepel() })
ItemHandlers::UseInField.add(:INFREPEL,proc{|item| pbToggleInfiniteRepel() })
ItemHandlers::UseInField.add(:INFREPELOFF,proc{|item| pbToggleInfiniteRepel() })
ItemHandlers::UseText.add(:INFREPEL, proc { |item| next _INTL("Desactivar")})
ItemHandlers::UseText.add(:INFREPELOFF, proc { |item| next _INTL("Activar")})
