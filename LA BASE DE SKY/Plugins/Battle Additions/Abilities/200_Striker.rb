#===============================================================================
# Striker
# Powers up kicking moves by 50%.
#===============================================================================
module VermeilStriker
  # Public compatibility constant used by UIs and other Vermeil systems.
  KICK_MOVES = VermeilMoveClasses::KICK_MOVES

  def self.kick_move?(move)
    return VermeilMoveClasses.kick_move?(move)
  end
end

module Battle::AbilityEffects
  # Helper for external UIs and scripts.
  def self.striker_kick_move?(move_or_id)
    return false if !defined?(VermeilMoveClasses)
    return VermeilMoveClasses.kick_move?(move_or_id)
  end
end

Battle::AbilityEffects::DamageCalcFromUser.add(:STRIKER,
  proc { |ability, user, target, move, mults, power, type|
    mults[:power_multiplier] *= 1.5 if VermeilMoveClasses.kick_move?(move)
  }
)
