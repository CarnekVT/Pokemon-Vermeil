#===============================================================================
# Folded Guard
# The first opposing damaging hit received in a battle deals half damage.
# The consumed state follows the Pokémon if it switches out and back in.
#===============================================================================
module Battle::AbilityEffects
  DamageCalcFromTarget.add(:FOLDEDGUARD,
    proc { |ability, user, target, move, mults, power, type|
      next if !user || !target || !move || !move.damagingMove?
      next if !user.opposes?(target)
      next if target.battle.vermeilAbilityTriggered?(target, :FOLDEDGUARD)
      mults[:final_damage_multiplier] *= 0.5
    }
  )

  OnBeingHit.add(:FOLDEDGUARD,
    proc { |ability, user, target, move, battle|
      next if !user || !target || !move || !move.damagingMove?
      next if !user.opposes?(target)
      next if target.damageState.substitute
      next if target.damageState.hpLost <= 0
      next if battle.vermeilAbilityTriggered?(target, :FOLDEDGUARD)
      battle.pbMarkVermeilAbilityTriggered(target, :FOLDEDGUARD)
      battle.pbShowAbilitySplash(target)
      battle.pbDisplay(_INTL("{1} folded itself to soften the blow!", target.pbThis))
      battle.pbHideAbilitySplash(target)
    }
  )
end
