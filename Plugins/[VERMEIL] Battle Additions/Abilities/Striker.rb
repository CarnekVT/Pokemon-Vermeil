#===============================================================================
# Striker
# Powers up kicking moves by 50%.
#===============================================================================
module VermeilStriker
  KICK_MOVES = [
    :DOUBLEKICK,
    :JUMPKICK,
    :HIGHJUMPKICK,
    :MEGAKICK,
    :LOWKICK,
    :ROLLINGKICK,
    :TRIPLEKICK,
    :BLAZEKICK,
    :TROPKICK,
    :THUNDEROUSKICK,
    :AXEKICK,
    :LOWSWEEP,
    :STOMP,
    :HIGHHORSEPOWER,
    :STOMPINGTANTRUM,
    :CLOSECOMBAT,
    :BEDROCKKICK
  ]

  def self.kick_move?(move)
    return false if !move
    move_id = move
    move_id = move.id if move.respond_to?(:id)
    move_id = move_id.to_sym if move_id.is_a?(String)
    return KICK_MOVES.include?(move_id)
  end
end

module Battle::AbilityEffects
  # Helper for external UIs (Enhanced Battle UI, etc.).
  def self.striker_kick_move?(move_or_id)
    return false if !defined?(VermeilStriker)
    move_id = move_or_id
    move_id = move_or_id.id if move_or_id.respond_to?(:id)
    move_id = move_id.to_sym if move_id.is_a?(String)
    return VermeilStriker::KICK_MOVES.include?(move_id)
  end
end

Battle::AbilityEffects::DamageCalcFromUser.add(:STRIKER,
  proc { |ability, user, target, move, mults, power, type|
    mults[:power_multiplier] *= 1.5 if VermeilStriker.kick_move?(move)
  }
)
