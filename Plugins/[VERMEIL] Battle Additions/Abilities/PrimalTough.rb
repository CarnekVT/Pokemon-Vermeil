#===============================================================================
# Primal Tough - Custom Ability
#===============================================================================

module Battle::AbilityEffects
  # Reduces Rock-type damage but increases Ice-type damage taken.
  DamageCalcFromTarget.add(:PRIMALTOUGH,
    proc { |ability, user, target, move, mults, power, type|
      if type == :ROCK
        mults[:final_damage_multiplier] *= 0.5
      elsif type == :ICE
        mults[:final_damage_multiplier] *= 1.25
      end
    }
  )
end
