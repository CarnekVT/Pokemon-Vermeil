#===============================================================================
# Arcane Ability data. Data/ArcaneAbilities/species.json is authoritative.
# Old PBS ArcaneAbility is supported only as a migration fallback.
#===============================================================================
module ArcaneAbilities
  VERSION="2.4.0"
  module LegacySpeciesSchema
    def schema(compiling_forms=false)
      ret=super; ret["ArcaneAbility"] ||= [:arcane_ability,"e",:Ability]; ret
    end
  end
  module LegacySpeciesInitialize
    def initialize(hash); super; @arcane_ability=hash[:arcane_ability]; end
  end
end
module GameData
  class Species
    attr_reader :arcane_ability
  end
end
GameData::Species.singleton_class.prepend(ArcaneAbilities::LegacySpeciesSchema)
GameData::Species.prepend(ArcaneAbilities::LegacySpeciesInitialize)
