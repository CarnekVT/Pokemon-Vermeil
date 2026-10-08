#===============================================================================
# Starry Reach
# - Above 50% HP: status and punching moves gain +1 priority.
# - Above 50% HP: punching moves double their secondary-effect chance (max 100%).
#===============================================================================
Battle::AbilityEffects::PriorityChange.add(:STARRYREACH,
  proc { |ability, battler, move, pri|
    next pri if !battler || battler.hp <= battler.totalhp / 2
    next pri + 1 if move && (move.statusMove? || move.punchingMove?)
    next pri
  }
)

class Battle::Move
  if !method_defined?(:vermeil_starry_reach_pbAdditionalEffectChance_original)
    alias vermeil_starry_reach_pbAdditionalEffectChance_original pbAdditionalEffectChance
  end

  def pbAdditionalEffectChance(user, target, effectChance = 0)
    chance = vermeil_starry_reach_pbAdditionalEffectChance_original(user, target, effectChance)
    return chance if !user || !user.hasActiveAbility?(:STARRYREACH)
    return chance if user.hp <= user.totalhp / 2
    return chance if !punchingMove? || chance <= 0
    return [chance * 2, 100].min
  end
end
