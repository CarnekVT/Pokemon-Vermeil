#===============================================================================
# OVERCHARGE
# Powers up Electric-type moves by 33%.
#===============================================================================
Battle::AbilityEffects::DamageCalcFromUser.add(:OVERCHARGE,
  proc { |ability, user, target, move, mults, power, type|
    mults[:power_multiplier] *= 1.33 if type == :ELECTRIC
  }
)
