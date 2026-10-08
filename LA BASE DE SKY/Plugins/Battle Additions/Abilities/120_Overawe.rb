#===============================================================================
# Overawe - Special Intimidate
# Lowers foes' Special Attack on switch-in.
#===============================================================================
class Battle::Battler
  def pbLowerSpecialAttackStatStageIntimidate(user)
    return false if fainted?
    # Keep parity with Intimidate behavior (Substitute blocks it).
    if @effects[PBEffects::Substitute] > 0
      if Battle::Scene::USE_ABILITY_SPLASH
        @battle.pbDisplay(_INTL("{1} is protected by its substitute!", pbThis))
      else
        @battle.pbDisplay(_INTL("{1}'s substitute protected it from {2}'s {3}!",
                                pbThis, user.pbThis(true), user.abilityName))
      end
      return false
    end
    # Same anti-Intimidate ability group in Gen 8+.
    if Settings::MECHANICS_GENERATION >= 8 && hasActiveAbility?([:OBLIVIOUS, :OWNTEMPO, :INNERFOCUS, :SCRAPPY])
      @battle.pbShowAbilitySplash(self)
      if Battle::Scene::USE_ABILITY_SPLASH
        @battle.pbDisplay(_INTL("{1}'s {2} cannot be lowered!", pbThis, GameData::Stat.get(:SPECIAL_ATTACK).name))
      else
        @battle.pbDisplay(_INTL("{1}'s {2} prevents {3} loss!", pbThis, abilityName,
                                GameData::Stat.get(:SPECIAL_ATTACK).name))
      end
      @battle.pbHideAbilitySplash(self)
      return false
    end
    if Battle::Scene::USE_ABILITY_SPLASH
      return pbLowerStatStageByAbility(:SPECIAL_ATTACK, 1, user, false)
    end
    if !hasActiveAbility?(:CONTRARY)
      if pbOwnSide.effects[PBEffects::Mist] > 0
        @battle.pbDisplay(_INTL("{1} is protected from {2}'s {3} by Mist!",
                                pbThis, user.pbThis(true), user.abilityName))
        return false
      end
      if abilityActive? &&
         (Battle::AbilityEffects.triggerStatLossImmunity(self.ability, self, :SPECIAL_ATTACK, @battle, false) ||
          Battle::AbilityEffects.triggerStatLossImmunityNonIgnorable(self.ability, self, :SPECIAL_ATTACK, @battle, false))
        @battle.pbDisplay(_INTL("{1}'s {2} prevented {3}'s {4} from working!",
                                pbThis, abilityName, user.pbThis(true), user.abilityName))
        return false
      end
      allAllies.each do |b|
        next if !b.abilityActive?
        if Battle::AbilityEffects.triggerStatLossImmunityFromAlly(b.ability, b, self, :SPECIAL_ATTACK, @battle, false)
          @battle.pbDisplay(_INTL("{1} is protected from {2}'s {3} by {4}'s {5}!",
                                  pbThis, user.pbThis(true), user.abilityName, b.pbThis(true), b.abilityName))
          return false
        end
      end
    end
    return false if !pbCanLowerStatStage?(:SPECIAL_ATTACK, user)
    return pbLowerStatStageByCause(:SPECIAL_ATTACK, 1, user, user.abilityName)
  end
end

module Battle::AbilityEffects
  OnSwitchIn.add(:OVERAWE,
    proc { |ability, battler, battle, switch_in|
      battle.pbShowAbilitySplash(battler)
      battle.allOtherSideBattlers(battler.index).each do |b|
        next if !b.near?(battler)
        check_item = true
        if b.hasActiveAbility?(:CONTRARY)
          check_item = false if b.statStageAtMax?(:SPECIAL_ATTACK)
        elsif b.statStageAtMin?(:SPECIAL_ATTACK)
          check_item = false
        end
        check_ability = b.pbLowerSpecialAttackStatStageIntimidate(battler)
        b.pbAbilitiesOnIntimidated if check_ability
        b.pbItemOnIntimidatedCheck if check_item
      end
      battle.pbHideAbilitySplash(battler)
    }
  )
end
