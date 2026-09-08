#===============================================================================
# [VERMEIL] Battle Additions - Ability support
# Shared helpers for the non-Golden Vermeil abilities migrated into this plugin.
#===============================================================================
module VermeilBattleAdditions
  module_function

  def contact_move?(move, user = nil)
    return false if !move
    return move.pbContactMove?(user) if move.respond_to?(:pbContactMove?)
    return move.contactMove? if move.respond_to?(:contactMove?)
    return false
  end

  def slicing_move?(move)
    return false if !move
    return move.slicingMove? if move.respond_to?(:slicingMove?)
    return false
  end

  def spread_move?(move, user)
    return false if !move || !user || !move.respond_to?(:pbTarget)
    data = move.pbTarget(user)
    return false if !data
    targets_foe = data.respond_to?(:targets_foe) ? data.targets_foe : true
    return false if !targets_foe
    return data.num_targets > 1 if data.respond_to?(:num_targets)
    id = data.respond_to?(:id) ? data.id : nil
    return [:AllNearFoes, :AllFoes, :AllNearOthers, :AllBattlers].include?(id)
  end

  def graphics_delta
    return Graphics.delta if Graphics.respond_to?(:delta)
    rate = Graphics.respond_to?(:frame_rate) ? Graphics.frame_rate.to_f : 40.0
    rate = 40.0 if rate <= 0
    return 1.0 / rate
  end
end

class Battle
  def vermeilAbilityState
    @vermeil_ability_state ||= {}
    return @vermeil_ability_state
  end

  def vermeilAbilityStateKey(battler, effect)
    pokemon = (battler.respond_to?(:pokemon) ? battler.pokemon : nil)
    identity = pokemon ? pokemon.object_id : battler.object_id
    return [effect, identity]
  end

  def vermeilAbilityTriggered?(battler, effect)
    return !!vermeilAbilityState[vermeilAbilityStateKey(battler, effect)]
  end

  def pbMarkVermeilAbilityTriggered(battler, effect)
    vermeilAbilityState[vermeilAbilityStateKey(battler, effect)] = true
  end
end
