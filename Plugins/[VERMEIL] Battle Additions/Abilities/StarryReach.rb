#===============================================================================
# Starry Reach (STARRYREACH)
# - +1 priority to status and punching moves while user's HP is above 50%.
# - Doubles secondary effect chance of punching moves under the same HP condition.
#===============================================================================

Battle::AbilityEffects::PriorityChange.add(:STARRYREACH,
  proc { |ability, battler, move, pri|
    next pri + 1 if move.statusMove? || move.punchingMove?
  }
)

class Battle::Move
  if !method_defined?(:starry_reach_pbAdditionalEffectChance_original)
    alias starry_reach_pbAdditionalEffectChance_original pbAdditionalEffectChance
  end

  def pbAdditionalEffectChance(user, target, effectChance = 0)
    chance = starry_reach_pbAdditionalEffectChance_original(user, target, effectChance)
    return chance if !user || !user.hasActiveAbility?(:STARRYREACH)
    return chance if !punchingMove?
    return chance if chance <= 0
    return chance * 2
  end
end
