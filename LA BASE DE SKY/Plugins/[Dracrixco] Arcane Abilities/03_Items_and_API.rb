#===============================================================================
# Arcane Tea + public building API
#===============================================================================
ItemHandlers::UseOnPokemon.add(
  :ARCANETEA,
  proc do |item, qty, pkmn, scene|
    arcane = pkmn.arcane_ability_id
    if !arcane
      pbMessage(_INTL("No tendría ningún efecto."))
      next false
    end

    if pkmn.arcane_unlocked? && pkmn.arcane_active?
      pbMessage(_INTL(
        "¡{1} ya está en sintonía con su Habilidad Arcana, {2}!",
        pkmn.name, GameData::Ability.get(arcane).name
      ))
      next false
    end

    was_unlocked = pkmn.arcane_unlocked?
    pkmn.unlockArcaneAbility(true)
    if was_unlocked
      pbMessage(_INTL(
        "¡{1} vuelve a sintonizar con su Habilidad Arcana, {2}!",
        pkmn.name, GameData::Ability.get(arcane).name
      ))
    else
      pbMessage(_INTL(
        "¡{1} despierta una capacidad ancestral! ¡Su Habilidad Arcana es {2}!",
        pkmn.name, GameData::Ability.get(arcane).name
      ))
    end
    next true
  end
)

# Event/script helpers:
#   pkmn.unlockArcaneAbility
#   pkmn.activateArcaneAbility
#   pkmn.deactivateArcaneAbility
#   pkmn.toggleArcaneAbility
#
# Evolution needs no replacement hook: @arcane_unlocked/@arcane_active stay on
# the same Pokémon object and arcane_ability_id automatically resolves the new
# species' ArcaneAbility.


# Optional building menu for events/PC systems. It never consumes an item.
def pbArcaneAbilityChoice(pkmn)
  return false if !pkmn || !pkmn.arcane_unlocked? || !pkmn.hasArcaneAbility?
  arcane = GameData::Ability.get(pkmn.arcane_ability_id)
  normal = pkmn.non_arcane_ability_id
  normal_name = normal ? GameData::Ability.get(normal).name : _INTL("habilidad normal")
  commands = [
    _INTL("Usar Arcana: {1}", arcane.name),
    _INTL("Usar {1}", normal_name),
    _INTL("Cancelar")
  ]
  choice = pbMessage(_INTL("¿Qué habilidad quieres usar en la build de {1}?", pkmn.name), commands, 2)
  case choice
  when 0
    pkmn.activateArcaneAbility
    return true
  when 1
    pkmn.deactivateArcaneAbility
    return true
  end
  return false
end

# Arcane Studio visibility callbacks. The Studio button can call the first
# helper for the focused row and the second one for checked rows in its
# multi-selection grid. Visibility is editor-only and never changes gameplay.
def pbArcaneHideSpecies(species,form=0)
  ArcaneAbilities::Data.set_hidden(species,true,form)
end

def pbArcaneShowSpecies(species,form=0)
  ArcaneAbilities::Data.set_hidden(species,false,form)
end

def pbArcaneSetSpeciesVisibility(selection,hidden=true)
  ArcaneAbilities::Data.set_hidden_many(selection,hidden)
end

def pbArcaneImportChangeDexHiddenForms
  ArcaneAbilities::Data.import_changedex_hidden_forms!
end
