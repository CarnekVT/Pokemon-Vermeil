#===============================================================================
# Folded Guard - Custom Ability
#===============================================================================

module Battle::AbilityEffects
  #=============================================================================
  # The first time this Pokemon is hit in battle, the damage is halved.
  #=============================================================================
  DamageCalcFromTarget.add(:FOLDEDGUARD,
    proc { |ability, user, target, move, mults, power, type|
      next if target.effects[PBEffects::FoldedGuard]
      next unless move && move.damagingMove? && user && user.opposes?(target)
      mults[:final_damage_multiplier] /= 2
    }
  )

  OnBeingHit.add(:FOLDEDGUARD,
    proc { |ability, user, target, move, battle|
      next if target.effects[PBEffects::FoldedGuard]
      next unless move && move.damagingMove? && user && user.opposes?(target)
      target.effects[PBEffects::FoldedGuard] = true
      battle.pbShowAbilitySplash(target)
      battle.pbDisplay(_INTL("{1} folded itself to soften the blow!", target.pbThis))
      battle.pbHideAbilitySplash(target)
    }
  )
end

# Add PBEffect for Folded Guard to track if effect has been triggered
if !PBEffects.const_defined?(:FoldedGuard)
  module PBEffects
    FoldedGuard = 166  # Unique number for the effect
  end
end

# Add the effect to the list of PBEffects of Deluxe Battle Kit if it exists
if defined?($DELUXE_PBEFFECTS) && !$DELUXE_PBEFFECTS[:battler][:counter].include?(:FoldedGuard)
  $DELUXE_PBEFFECTS[:battler][:counter].push(:FoldedGuard)
end
