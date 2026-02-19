#===============================================================================
# Overcharge
# Raises Attack by 1 stage after landing a contact move or a recoil move.
#===============================================================================
module Battle::AbilityEffects
  OnEndOfUsingMove.add(:OVERCHARGE,
    proc { |ability, user, targets, move, battle|
      next if !move || !move.damagingMove?
      next if !(move.contactMove? || move.recoilMove?)
      hit_target = false
      targets.each do |b|
        next if !b
        next if b.damageState.unaffected
        next if b.damageState.calcDamage <= 0 && !b.damageState.substitute
        hit_target = true
        break
      end
      next if !hit_target
      next if !user.pbCanRaiseStatStage?(:ATTACK, user)
      user.pbRaiseStatStageByAbility(:ATTACK, 1, user)
    }
  )
end

