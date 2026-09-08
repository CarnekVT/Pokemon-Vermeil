#===============================================================================
# Fire Knock
# Contact moves have a 30% chance to burn the target.
#===============================================================================
Battle::AbilityEffects::OnDealingHit.add(:FIREKNOCK,
  proc { |ability, user, target, move, battle|
    next if !user || !target || !move
    next if target.fainted? || target.damageState.substitute
    next if !VermeilBattleAdditions.contact_move?(move, user)
    next if battle.pbRandom(100) >= 30
    battle.pbShowAbilitySplash(user)
    if target.hasActiveAbility?(:SHIELDDUST) && !battle.moldBreaker
      battle.pbShowAbilitySplash(target)
      battle.pbDisplay(_INTL("{1} is unaffected!", target.pbThis)) if !Battle::Scene::USE_ABILITY_SPLASH
      battle.pbHideAbilitySplash(target)
    elsif target.pbCanBurn?(user, Battle::Scene::USE_ABILITY_SPLASH, move)
      msg = nil
      if !Battle::Scene::USE_ABILITY_SPLASH
        msg = _INTL("{1}'s {2} burned {3}!", user.pbThis, user.abilityName, target.pbThis(true))
      end
      target.pbBurn(user, msg)
    end
    battle.pbHideAbilitySplash(user)
  }
)
