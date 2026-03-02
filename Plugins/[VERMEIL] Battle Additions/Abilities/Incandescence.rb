#===============================================================================
# Incandescence - Custom Ability
#===============================================================================
# Effect: Under sunny weather or if hit by a Fire-type move, the Pokémon's
# body heats up, increasing its Defense and Special Attack by one stage.
# Additionally, contact moves against it have a 30% chance of burning the attacker.
#===============================================================================
module Battle::AbilityEffects
  #=============================================================================
  # Stat boost at the end of the turn in Sun
  #=============================================================================
  EndOfRoundEffect.add(:INCANDESCENCE,
    proc { |ability, battler, battle|
      next if ![:Sun, :HarshSun].include?(battler.effectiveWeather)
      next if !battler.pbCanRaiseStatStage?(:DEFENSE, battler) && !battler.pbCanRaiseStatStage?(:SPECIAL_ATTACK, battler)
      
      battle.pbShowAbilitySplash(battler)
      
      show_anim = true
      if battler.pbCanRaiseStatStage?(:DEFENSE, battler)
        battler.pbRaiseStatStage(:DEFENSE, 1, battler, show_anim)
        show_anim = false
      end
      if battler.pbCanRaiseStatStage?(:SPECIAL_ATTACK, battler)
        battler.pbRaiseStatStage(:SPECIAL_ATTACK, 1, battler, show_anim)
      end
      
      battle.pbDisplay(_INTL("{1}'s body glows with incandescent heat!", battler.pbThis))
      battle.pbHideAbilitySplash(battler)
    }
  )

  #=============================================================================
  # Stat boost when hit by a Fire move & burn on contact
  #=============================================================================
  OnBeingHit.add(:INCANDESCENCE,
    proc { |ability, user, target, move, battle|
      # Stat boost if hit by a Fire-type move
      if move.calcType == :FIRE && move.damagingMove?
        if target.pbCanRaiseStatStage?(:DEFENSE, target) || target.pbCanRaiseStatStage?(:SPECIAL_ATTACK, target)
          battle.pbShowAbilitySplash(target)
          
          show_anim = true
          if target.pbCanRaiseStatStage?(:DEFENSE, target)
            target.pbRaiseStatStage(:DEFENSE, 1, target, show_anim)
            show_anim = false
          end
          if target.pbCanRaiseStatStage?(:SPECIAL_ATTACK, target)
            target.pbRaiseStatStage(:SPECIAL_ATTACK, 1, target, show_anim)
          end
          
          battle.pbDisplay(_INTL("{1}'s body glows with incandescent heat!", target.pbThis))
          battle.pbHideAbilitySplash(target)
        end
      end

      # Burn attacker on contact
      if move.contactMove? && user.affectedByContactEffect? && battle.pbRandom(100) < 30
        user.pbBurn(target, _INTL("{1}'s {2} burned {3}!", target.pbThis, target.abilityName, user.pbThis(true))) if user.pbCanBurn?(target, false, move)
      end
    }
  )
end
