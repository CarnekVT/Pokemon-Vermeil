#===============================================================================
# CRYSTAL ORBIT
# When the holder drops below half HP, raise Special Defense by 1 stage.
#===============================================================================
Battle::AbilityEffects::OnHPDroppedBelowHalf.add(:CRYSTALORBIT,
  proc { |ability, battler, move_user, battle|
    next if battler.fainted?
    battle.pbDisplay(_INTL("{1} surrounds itself with a crystal orbit!", battler.pbThis))
    battler.pbRaiseStatStageByAbility(:SPECIAL_DEFENSE, 1, battler)
  }
)
