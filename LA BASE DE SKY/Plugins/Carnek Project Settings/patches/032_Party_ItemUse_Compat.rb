#===============================================================================
# Carnek Project Settings - Party/Bag item compatibility
# Pokémon Essentials v21.1 / LA BASE DE SKY
#
# Some customized Party/Bag flows still call the Essentials v21.1 helper
# pbCanUseOnPokemon?.  Define the vanilla-compatible helper only when the
# current runtime does not provide it, so UI_Party.rb can safely filter items.
#===============================================================================

unless Object.method_defined?(:pbCanUseOnPokemon?) ||
       Object.private_method_defined?(:pbCanUseOnPokemon?)
  Object.class_eval do
    def pbCanUseOnPokemon?(item)
      itm = GameData::Item.get(item)
      return ItemHandlers.hasUseOnPokemon(itm.id) || itm.is_machine?
    end
    private :pbCanUseOnPokemon?
  end
end
