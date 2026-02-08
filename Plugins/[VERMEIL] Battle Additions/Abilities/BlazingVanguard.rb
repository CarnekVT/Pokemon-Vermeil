#===============================================================================
# Blazing Vanguard - Custom Ability
#===============================================================================

module Battle::AbilityEffects
  #=============================================================================
  # On switch-in, raise Attack by 1 (once per battle, Gen 9+ logic)
  #=============================================================================
  OnSwitchIn.add(:BLAZINGVANGUARD,
    proc { |ability, battler, battle, switch_in|
      next if Settings::MECHANICS_GENERATION >= 9 && battler.ability_triggered?
      battler.pbRaiseStatStageByAbility(:ATTACK, 1, battler)
      battle.pbSetAbilityTrigger(battler)
    }
  )

  #=============================================================================
  # Reduce damage from physical moves
  #=============================================================================
  DamageCalcFromTarget.add(:BLAZINGVANGUARD,
    proc { |ability, user, target, move, mults, power, type|
      next if !move.physicalMove?
      mults[:final_damage_multiplier] *= 0.75
    }
  )
end
