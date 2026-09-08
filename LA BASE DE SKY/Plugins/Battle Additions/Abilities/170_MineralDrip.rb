#===============================================================================
# Stalactree - Custom Ability and Move Effects
#===============================================================================

module Battle::AbilityEffects
  # Mineral Drip:
  # - Restores 1/16 max HP at end of turn.
  # - Restores 1/8 max HP instead during sandstorm.
  EndOfRoundEffect.add(:MINERALDRIP,
    proc { |ability, battler, battle|
      next if battler.fainted?
      next if !battler.canHeal?
      heal_divisor = (battle.pbWeather == :Sandstorm) ? 8 : 16
      heal_amount = [(battler.totalhp.to_f / heal_divisor).floor, 1].max
      battle.pbShowAbilitySplash(battler)
      battler.pbRecoverHP(heal_amount)
      if Battle::Scene::USE_ABILITY_SPLASH
        battle.pbDisplay(_INTL("{1}'s HP was restored.", battler.pbThis))
      else
        battle.pbDisplay(_INTL("{1}'s {2} restored its HP.", battler.pbThis, battler.abilityName))
      end
      battle.pbHideAbilitySplash(battler)
    }
  )
end
