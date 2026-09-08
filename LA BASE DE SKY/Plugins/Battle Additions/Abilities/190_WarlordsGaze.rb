#===============================================================================
# Warlord's Gaze
# - On switch-in, lowers nearby foes' Attack as Intimidate does.
# - A foe that voluntarily leaves the field takes 1/8 max HP before Pursuit and
#   before the replacement. Implemented at Battle#pbPursuit so it also covers
#   U-turn/Volt Switch/Flip Turn, Teleport, Parting Shot and Baton Pass without
#   replacing Essentials' switch classes.
#===============================================================================
module Battle::AbilityEffects
  OnSwitchIn.add(:WARLORDSGAZE,
    proc { |ability, battler, battle, switch_in|
      battle.pbShowAbilitySplash(battler)
      battle.allOtherSideBattlers(battler.index).each do |b|
        next if !b.near?(battler)
        check_item = true
        if b.hasActiveAbility?(:CONTRARY)
          check_item = false if b.statStageAtMax?(:ATTACK)
        elsif b.statStageAtMin?(:ATTACK)
          check_item = false
        end
        check_ability = b.pbLowerAttackStatStageIntimidate(battler)
        b.pbAbilitiesOnIntimidated if check_ability
        b.pbItemOnIntimidatedCheck if check_item
      end
      battle.pbHideAbilitySplash(battler)
    }
  )
end

class Battle
  def pbApplyWarlordsGazeSwitchDamage(switcher)
    return if !switcher || switcher.fainted?
    source = allOtherSideBattlers(switcher.index).find do |b|
      b && !b.fainted? && b.hasActiveAbility?(:WARLORDSGAZE)
    end
    return if !source
    return if !switcher.takesIndirectDamage?(Battle::Scene::USE_ABILITY_SPLASH)

    pbShowAbilitySplash(source)
    damage = [(switcher.totalhp / 8.0).ceil, 1].max
    switcher.pbTakeEffectDamage(damage) do
      pbDisplay(_INTL("{1} took damage from {2}'s {3}!",
        switcher.pbThis, source.pbThis(true), source.abilityName))
    end
    pbHideAbilitySplash(source)
  end

  if method_defined?(:pbPursuit) && !method_defined?(:vermeil_warlords_gaze_pbPursuit_original)
    alias vermeil_warlords_gaze_pbPursuit_original pbPursuit
  end

  if method_defined?(:vermeil_warlords_gaze_pbPursuit_original)
    def pbPursuit(idxBattler, *args)
      switcher = (@battlers && idxBattler) ? @battlers[idxBattler] : nil
      if !@vermeil_warlords_gaze_pursuit_guard
        @vermeil_warlords_gaze_pursuit_guard = true
        begin
          pbApplyWarlordsGazeSwitchDamage(switcher)
        ensure
          @vermeil_warlords_gaze_pursuit_guard = false
        end
      end
      return if switcher && switcher.fainted?
      return vermeil_warlords_gaze_pbPursuit_original(idxBattler, *args)
    end
  end
end
