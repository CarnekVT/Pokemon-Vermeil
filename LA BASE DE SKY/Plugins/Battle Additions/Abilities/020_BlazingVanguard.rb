#===============================================================================
# Blazing Vanguard
# - Raises Attack by 1 on switch-in. In Gen 9+ this can trigger once per battle.
# - Reduces physical damage taken by 25%.
#===============================================================================
module Battle::AbilityEffects
  OnSwitchIn.add(:BLAZINGVANGUARD,
    proc { |ability, battler, battle, switch_in|
      next if battler.fainted?
      if Settings::MECHANICS_GENERATION >= 9
        next if battle.vermeilAbilityTriggered?(battler, :BLAZINGVANGUARD)
        battle.pbMarkVermeilAbilityTriggered(battler, :BLAZINGVANGUARD)
      end
      battler.pbRaiseStatStageByAbility(:ATTACK, 1, battler) if battler.pbCanRaiseStatStage?(:ATTACK, battler)
    }
  )

  DamageCalcFromTarget.add(:BLAZINGVANGUARD,
    proc { |ability, user, target, move, mults, power, type|
      next if !move || !move.physicalMove?
      mults[:final_damage_multiplier] *= 0.75
    }
  )
end
