#===============================================================================
# Frost Edge
# - +20% Speed in Hail/Snow.
# - Slicing/contact damaging moves have a 20% chance to freeze a target that
#   currently has at least one lowered battle stat.
#===============================================================================
module Battle::AbilityEffects
  SpeedCalc.add(:FROSTEDGE,
    proc { |ability, battler, mult|
      next mult * 1.2 if [:Hail, :Snow].include?(battler.effectiveWeather)
      next mult
    }
  )

  OnDealingHit.add(:FROSTEDGE,
    proc { |ability, user, target, move, battle|
      next if !user || !target || !move || !move.damagingMove?
      next if target.fainted? || target.damageState.substitute
      next if !VermeilBattleAdditions.slicing_move?(move) && !VermeilBattleAdditions.contact_move?(move, user)
      lowered = false
      GameData::Stat.each_battle do |stat|
        if target.stages[stat.id] < 0
          lowered = true
          break
        end
      end
      next if !lowered || battle.pbRandom(100) >= 20
      battle.pbShowAbilitySplash(user)
      if target.pbCanFreeze?(user, Battle::Scene::USE_ABILITY_SPLASH)
        msg = nil
        if !Battle::Scene::USE_ABILITY_SPLASH
          msg = _INTL("{1}'s {2} froze {3}!", user.pbThis, user.abilityName, target.pbThis(true))
        end
        target.pbFreeze(msg)
      end
      battle.pbHideAbilitySplash(user)
    }
  )
end
