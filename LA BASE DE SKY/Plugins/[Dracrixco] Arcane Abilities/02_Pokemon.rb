#===============================================================================
# Persistent per-Pokémon Arcane state
#===============================================================================
class Pokemon
  # Compatibility reader/writer for old saves.
  def arcane_awake
    return arcane_unlocked?
  end

  def arcane_awake=(value)
    @arcane_unlocked = !!value
    @arcane_active = !!value if value
  end

  def arcane_unlocked?
    if !defined?(@arcane_unlocked) || @arcane_unlocked.nil?
      @arcane_unlocked = (defined?(@arcane_awake) && @arcane_awake) ? true : false
    end
    return !!@arcane_unlocked
  end

  def arcane_active?
    return false if !arcane_unlocked?
    return false if defined?(@arcane_active) && @arcane_active == false
    return !arcane_ability_id.nil?
  end

  def arcane_source_form
    # A Golden Form is a battle transformation. Arcane must keep resolving from
    # the biological form that entered the transformation, not from the Golden
    # Form's species-data record.
    if respond_to?(:golden_state) && golden_state == :FORM &&
       respond_to?(:pre_golden_form) && !pre_golden_form.nil?
      return pre_golden_form
    end
    return form
  end

  def arcane_ability_id
    source_form = arcane_source_form
    json_value = ArcaneAbilities::Data.ability_for(@species, source_form)
    return json_value if json_value

    # Legacy PBS fallback for one-time migration. Editors never write PBS.
    data = nil
    begin
      data = GameData::Species.get_species_form(@species, source_form)
    rescue
      data = species_data rescue nil
    end
    arcane = data.arcane_ability if data && data.respond_to?(:arcane_ability)
    return arcane if arcane
    if source_form.to_i != 0
      base = GameData::Species.get(@species) rescue nil
      return base.arcane_ability if base && base.respond_to?(:arcane_ability)
    end
    return nil
  end


  def non_arcane_ability_id
    sp_data = species_data
    abil_index = ability_index
    ability = nil
    if abil_index >= 2
      ability = sp_data.hidden_abilities[abil_index - 2]
      abil_index = (@personalID & 1) if !ability
    end
    ability ||= sp_data.abilities[abil_index] || sp_data.abilities[0]
    return ability
  end

  def hasArcaneAbility?
    return !arcane_ability_id.nil?
  end

  def unlockArcaneAbility(activate = true)
    return false if !hasArcaneAbility?
    @arcane_unlocked = true
    @arcane_active = !!activate
    return true
  end

  def activateArcaneAbility
    return false if !arcane_unlocked? || !hasArcaneAbility?
    @arcane_active = true
    return true
  end

  def deactivateArcaneAbility
    @arcane_active = false
    return true
  end

  def toggleArcaneAbility
    return false if !arcane_unlocked? || !hasArcaneAbility?
    @arcane_active = !arcane_active?
    return true
  end
end

module ArcaneAbilities
  module PokemonAbilityResolver
    def ability_id
      if arcane_active?
        arcane = arcane_ability_id
        return arcane if arcane
      end
      return super
    end
  end
end
Pokemon.prepend(ArcaneAbilities::PokemonAbilityResolver)
