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

# Stalagmite Fall:
# - 30% chance to flinch.
# - 10% chance to lower target's Defense by 1.
class Battle::Move::StalagmiteFall < Battle::Move
  def flinchingMove?
    return true
  end

  def pbAdditionalEffect(user, target)
    return if target.damageState.substitute
    flinch_chance = pbAdditionalEffectChance(user, target, 30)
    if flinch_chance > 0 && @battle.pbRandom(100) < flinch_chance
      target.pbFlinch(user)
    end
    drop_chance = pbAdditionalEffectChance(user, target, 10)
    if drop_chance > 0 && @battle.pbRandom(100) < drop_chance
      if target.pbCanLowerStatStage?(:DEFENSE, user, self)
        target.pbLowerStatStage(:DEFENSE, 1, user)
      end
    end
  end
end
