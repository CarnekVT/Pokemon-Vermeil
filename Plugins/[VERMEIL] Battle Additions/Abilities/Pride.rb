#===============================================================================
# Pride - Special Moxie
# Raises the user's Special Attack when it causes a foe to faint.
#===============================================================================
module Battle::AbilityEffects
  OnEndOfUsingMove.add(:PRIDE,
    proc { |ability, user, targets, move, battle|
      next if battle.pbAllFainted?(user.idxOpposingSide)
      num_fainted = 0
      targets.each { |b| num_fainted += 1 if b.damageState.fainted }
      next if num_fainted == 0
      next if !user.pbCanRaiseStatStage?(:SPECIAL_ATTACK, user)
      user.pbRaiseStatStageByAbility(:SPECIAL_ATTACK, num_fainted, user)
    }
  )
end
