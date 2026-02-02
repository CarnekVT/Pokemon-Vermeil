#===============================================================================
# CREDITS
# Voltseon, DPertierra, lavinytuttini
#===============================================================================
class PokemonGlobalMetadata
    attr_accessor :vial_charges
    attr_accessor :max_vial_charges
    attr_accessor :vial_locked
end

INITIAL_CHARGES_POKEVIAL = 1 
INFINITE_POKEVIAL = false

ItemHandlers::UseFromBag.add(:VIAL, proc { |item| use_pokevial; next 1 })
ItemHandlers::UseInField.add(:VIAL, proc { |item| use_pokevial; next 1 })

def init_pokevial
  $PokemonGlobal.vial_charges ||= INITIAL_CHARGES_POKEVIAL
  $PokemonGlobal.max_vial_charges ||= INITIAL_CHARGES_POKEVIAL
  $PokemonGlobal.vial_locked ||= false
end

def lock_vial
  return unless ensure_pokevial_initialized
  $PokemonGlobal.vial_locked = true
  Kernel.pbMessage(_INTL("The Pokévial has been locked."))
end

def unlock_vial
  return unless ensure_pokevial_initialized
  $PokemonGlobal.vial_locked = false
  Kernel.pbMessage(_INTL("The Pokévial has been unlocked."))
end

def ensure_pokevial_initialized
  return false unless has_player_pokevial
  init_pokevial
  true
end

def has_player_pokevial
  $bag.has?(:VIAL) || $bag.has?(:EMPTYVIAL)
end


def show_message_pokevial
  if $PokemonGlobal.vial_charges <= 0
    Kernel.pbMessage(_INTL("The Pokévial is empty. Recharge it at the Pokémon Center."))
    return false
  end
  if !INFINITE_POKEVIAL
    Kernel.pbMessage(_INTL("You have {1} {2} {3} out of a maximum of {4}.",
      $PokemonGlobal.vial_charges,
      $PokemonGlobal.vial_charges == 1 ? "heal" : "heals",
      $PokemonGlobal.vial_charges == 1 ? "available" : "available",
      $PokemonGlobal.max_vial_charges))
  end
  true
end

def max_vial_charges
  ensure_pokevial_initialized
  $PokemonGlobal.max_vial_charges || 0
end

def vial_charges
  ensure_pokevial_initialized
  $PokemonGlobal.vial_charges || 0
end

def vial_full?
  ensure_pokevial_initialized
  $PokemonGlobal.vial_charges == $PokemonGlobal.max_vial_charges
end


def use_pokevial
  return unless ensure_pokevial_initialized
  if $PokemonGlobal.vial_locked
    Kernel.pbMessage(_INTL("The Pokévial is locked."))
    return
  end
  return unless show_message_pokevial
  if Kernel.pbConfirmMessage(_INTL("Do you want to heal your team?"))
    heal_party_with_pokevial
  end
end

def heal_party_with_pokevial
  $player.heal_party
  pbMEPlay("Pkmn healing")
  Kernel.pbMessage(_INTL("Your Pokémon team has been fully healed!"))
  $PokemonGlobal.vial_charges -= 1 if !INFINITE_POKEVIAL
  $bag.replace_item(:VIAL, :EMPTYVIAL) if $PokemonGlobal.vial_charges <= 0
end

def recharge_vial
    return unless ensure_pokevial_initialized
    $PokemonGlobal.vial_charges = $PokemonGlobal.max_vial_charges
    Kernel.pbMessage(_INTL("Your Pokévial has been recharged!")) if !INFINITE_POKEVIAL
    $bag.replace_item(:EMPTYVIAL,:VIAL) if $bag.has?(:EMPTYVIAL)
end

def add_new_vial_charge
    return unless ensure_pokevial_initialized || INFINITE_POKEVIAL
    $PokemonGlobal.max_vial_charges += 1
    # Done this way so that receiving a new charge doesn't fully restore the vial
    $PokemonGlobal.vial_charges += 1
    Kernel.pbMessage(_INTL("Your Pokévial can now store {1} charge#{$PokemonGlobal.max_vial_charges > 1 ? 's' : ''}!",$PokemonGlobal.max_vial_charges))
end

def remove_vial_charge
  return unless ensure_pokevial_initialized || INFINITE_POKEVIAL
  if $PokemonGlobal.max_vial_charges > 1
    $PokemonGlobal.max_vial_charges -= 1
    # Done this way so that removing a charge doesn't fully restore the vial
    $PokemonGlobal.vial_charges -= 1 if $PokemonGlobal.vial_charges > 0
    Kernel.pbMessage(_INTL("Your Pokévial can now store {1} charge#{$PokemonGlobal.max_vial_charges > 1 ? 's' : ''}!", 
                           $PokemonGlobal.max_vial_charges))
  end
end
