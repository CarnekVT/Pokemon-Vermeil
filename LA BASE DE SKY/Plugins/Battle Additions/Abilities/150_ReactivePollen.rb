#===============================================================================
# Reactive Pollen
# Physical hits lower the attacker's Attack and Speed by 1.
# Special hits lower the attacker's Special Attack and Speed by 1.
#===============================================================================
module Battle::AbilityEffects
  OnBeingHit.add(:REACTIVEPOLLEN,
    proc { |ability, user, target, move, battle|
      next if !user || !target || !move || !move.damagingMove?
      next if target.fainted? || user.fainted? || target.damageState.substitute
      next if !user.opposes?(target)

      stats = if move.physicalMove?
                [:ATTACK, :SPEED]
              elsif move.specialMove?
                [:SPECIAL_ATTACK, :SPEED]
              else
                []
              end
      next if stats.empty?
      applicable = stats.any? { |stat| user.pbCanLowerStatStage?(stat, target) }
      next if !applicable

      battle.pbShowAbilitySplash(target)
      show_anim = true
      stats.each do |stat|
        next if !user.pbCanLowerStatStage?(stat, target)
        changed = user.pbLowerStatStage(stat, 1, target, show_anim)
        show_anim = false if changed
      end
      battle.pbHideAbilitySplash(target)
    }
  )
end
