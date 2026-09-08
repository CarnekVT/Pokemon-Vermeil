#===============================================================================
# Squire's Will
# - The first time HP falls to half or below: Atk +1, SpAtk +1, Def +2,
#   SpDef +2 and Speed +1.
# - At half HP or below: immune to flinching and phazing moves.
#===============================================================================
module Battle::AbilityEffects
  OnHPDroppedBelowHalf.add(:SQUIRESWILL,
    proc { |ability, battler, move_user, battle|
      next if !battler || battler.fainted?
      next if battle.vermeilAbilityTriggered?(battler, :SQUIRESWILL)
      battle.pbMarkVermeilAbilityTriggered(battler, :SQUIRESWILL)

      battle.pbShowAbilitySplash(battler)
      battle.pbDisplay(_INTL("{1}'s determination increased!", battler.pbThis))
      battle.pbHideAbilitySplash(battler)

      boosts = [
        [:ATTACK, 1], [:SPECIAL_ATTACK, 1], [:DEFENSE, 2],
        [:SPECIAL_DEFENSE, 2], [:SPEED, 1]
      ]
      show_anim = true
      boosts.each do |stat, amount|
        next if !battler.pbCanRaiseStatStage?(stat, battler)
        changed = battler.pbRaiseStatStage(stat, amount, battler, show_anim)
        show_anim = false if changed
      end
    }
  )
end

class Battle::Battler
  if method_defined?(:pbFlinch) && !method_defined?(:vermeil_squires_will_pbFlinch_original)
    alias vermeil_squires_will_pbFlinch_original pbFlinch
  end

  if method_defined?(:vermeil_squires_will_pbFlinch_original)
    def pbFlinch(*args)
      if hasActiveAbility?(:SQUIRESWILL) && hp <= totalhp / 2 && !@battle.moldBreaker
        @battle.pbShowAbilitySplash(self)
        @battle.pbDisplay(_INTL("{1} stands firm and cannot flinch!", pbThis))
        @battle.pbHideAbilitySplash(self)
        return false
      end
      return vermeil_squires_will_pbFlinch_original(*args)
    end
  end
end

# Roar/Whirlwind-style status phazing.
if defined?(Battle::Move::SwitchOutTargetStatusMove)
  class Battle::Move::SwitchOutTargetStatusMove
    if !method_defined?(:vermeil_squires_will_pbFailsAgainstTarget_original)
      alias vermeil_squires_will_pbFailsAgainstTarget_original pbFailsAgainstTarget?
    end

    def pbFailsAgainstTarget?(user, target, show_message)
      if target && target.hasActiveAbility?(:SQUIRESWILL) &&
         target.hp <= target.totalhp / 2 && !@battle.moldBreaker
        if show_message
          @battle.pbShowAbilitySplash(target)
          @battle.pbDisplay(_INTL("{1} stands its ground!", target.pbThis))
          @battle.pbHideAbilitySplash(target)
        end
        return true
      end
      return vermeil_squires_will_pbFailsAgainstTarget_original(user, target, show_message)
    end
  end
end

# Dragon Tail/Circle Throw-style damaging phazing. Damage still lands; only the
# forced switch is prevented.
if defined?(Battle::Move::SwitchOutTargetDamagingMove)
  class Battle::Move::SwitchOutTargetDamagingMove
    if !method_defined?(:vermeil_squires_will_pbSwitchOutTargetEffect_original)
      alias vermeil_squires_will_pbSwitchOutTargetEffect_original pbSwitchOutTargetEffect
    end

    def pbSwitchOutTargetEffect(user, targets, numHits, switched_battlers)
      blocked = []
      allowed = []
      targets.each do |target|
        if target && target.hasActiveAbility?(:SQUIRESWILL) &&
           target.hp <= target.totalhp / 2 && !@battle.moldBreaker
          blocked << target
        else
          allowed << target
        end
      end
      blocked.each do |target|
        @battle.pbShowAbilitySplash(target)
        @battle.pbDisplay(_INTL("{1} stands its ground!", target.pbThis))
        @battle.pbHideAbilitySplash(target)
      end
      return if allowed.empty?
      return vermeil_squires_will_pbSwitchOutTargetEffect_original(user, allowed, numHits, switched_battlers)
    end
  end
end
