#===============================================================================
# Squire's Will - Custom Ability
#===============================================================================
module Battle::AbilityEffects
  #=============================================================================
  # When HP drops below 50%, raise Attack +1, SpAtk +1, Defense +2, SpDef +2, Speed +1
  #=============================================================================
  OnHPDroppedBelowHalf.add(:SQUIRESWILL,
    proc { |ability, battler, move_user, battle|
      # Check if we've already triggered the effect to avoid multiple triggers
      next false if battler.effects[PBEffects::SquiresWill]
      
      # Raise all stats without showing splash multiple times
      battler.effects[PBEffects::SquiresWill] = true  # Mark as triggered first
      
      battle.pbShowAbilitySplash(battler)
      battle.pbDisplay(_INTL("{1}'s determination increased!", battler.pbThis))
      battle.pbHideAbilitySplash(battler)
      
      # Raise all stats using built-in method (shows proper messages)
      show_anim = true
      if battler.pbCanRaiseStatStage?(:ATTACK, battler)
        battler.pbRaiseStatStage(:ATTACK, 1, battler, show_anim)
        show_anim = false  # Only show animation once
      end
      if battler.pbCanRaiseStatStage?(:SPECIAL_ATTACK, battler)
        battler.pbRaiseStatStage(:SPECIAL_ATTACK, 1, battler, show_anim)
        show_anim = false
      end
      if battler.pbCanRaiseStatStage?(:DEFENSE, battler)
        battler.pbRaiseStatStage(:DEFENSE, 2, battler, show_anim)
        show_anim = false
      end
      if battler.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, battler)
        battler.pbRaiseStatStage(:SPECIAL_DEFENSE, 2, battler, show_anim)
        show_anim = false
      end
      if battler.pbCanRaiseStatStage?(:SPEED, battler)
        battler.pbRaiseStatStage(:SPEED, 1, battler, show_anim)
      end
      
      # Show determination message
    }
  )

  #=============================================================================
  # Immune to flinching while below 50% HP
  #=============================================================================
  # We need to override the flinch check method
  module_function
  def self.triggerFlinchImmunity(battler)
    return true if battler.hasActiveAbility?(:SQUIRESWILL) && battler.hp <= battler.totalhp / 2
    return false
  end

  #=============================================================================
  # Immune to switch-inducing moves while below 50% HP
  #=============================================================================
  # We need to override the switch-out check for moves like Roar/Whirlwind
  MoveImmunity.add(:SQUIRESWILL,
    proc { |ability, user, target, move, type, battle, show_message|
      next false unless move.function_code == "ForceSwitch" || 
                      move.function_code == "ForceSwitchAll" ||
                      move.name.downcase.include?("roar") || 
                      move.name.downcase.include?("whirlwind")
      
      next false unless target.hasActiveAbility?(:SQUIRESWILL) && target.hp <= target.totalhp / 2
      
      if show_message
        battle.pbShowAbilitySplash(target)
        if Battle::Scene::USE_ABILITY_SPLASH
          battle.pbDisplay(_INTL("It doesn't affect {1}...", target.pbThis(true)))
        else
          battle.pbDisplay(_INTL("{1}'s {2} made {3} ineffective!",
             target.pbThis, target.abilityName, move.name))
        end
        battle.pbHideAbilitySplash(target)
      end
      next true
    }
  )
end

# Override the flinch check in Battle_Battler
class Battle::Battler
  alias_method :dbk_original_pbTryUseMove, :pbTryUseMove
  def pbTryUseMove(choice, move, specialUsage, skipAccuracyCheck)
    # Skip flinch check if has Squire's Will and below half HP
    if @effects[PBEffects::Flinch] && hasActiveAbility?(:SQUIRESWILL) && hp <= totalhp / 2
      @effects[PBEffects::Flinch] = false
      PBDebug.log("[Flinch immunity] #{pbThis} ignored flinch because of Squire's Will")
    end
    return dbk_original_pbTryUseMove(choice, move, specialUsage, skipAccuracyCheck)
  end
end

# Override switch-out target status move (Roar/Whirlwind)
class Battle::Move::SwitchOutTargetStatusMove
  alias_method :dbk_original_pbFailsAgainstTarget?, :pbFailsAgainstTarget?
  def pbFailsAgainstTarget?(user, target, show_message)
    if target.hasActiveAbility?(:SQUIRESWILL) && target.hp <= target.totalhp / 2 && !@battle.moldBreaker
      if show_message
        @battle.pbShowAbilitySplash(target)
        if Battle::Scene::USE_ABILITY_SPLASH
          @battle.pbDisplay(_INTL("{1} stands its ground!", target.pbThis))
        else
          @battle.pbDisplay(_INTL("{1} stands its ground with {2}!", target.pbThis, target.abilityName))
        end
        @battle.pbHideAbilitySplash(target)
      end
      return true
    end
    return dbk_original_pbFailsAgainstTarget?(user, target, show_message)
  end
end

# Override switch-out target damaging move (Circle Throw/Dragon Tail)
class Battle::Move::SwitchOutTargetDamagingMove
  alias_method :dbk_original_pbSwitchOutTargetEffect, :pbSwitchOutTargetEffect
  def pbSwitchOutTargetEffect(user, targets, numHits, switched_battlers)
    # Filter out targets with Squire's Will below half HP
    filtered_targets = targets.reject { |b| b.hasActiveAbility?(:SQUIRESWILL) && b.hp <= b.totalhp / 2 && !@battle.moldBreaker }
    return if filtered_targets.empty?
    # Call original method with filtered targets
    dbk_original_pbSwitchOutTargetEffect(user, filtered_targets, numHits, switched_battlers)
  end
end

# Add PBEffect for Squire's Will to track if effect has been triggered
if !PBEffects.const_defined?(:SquiresWill)
  module PBEffects
    SquiresWill = 165  # Unique number for the effect
  end
end

# Add the effect to the list of PBEffects of Deluxe Battle Kit if it exists
if defined?($DELUXE_PBEFFECTS) && !$DELUXE_PBEFFECTS[:battler][:counter].include?(:SquiresWill)
  $DELUXE_PBEFFECTS[:battler][:counter].push(:SquiresWill)
end
