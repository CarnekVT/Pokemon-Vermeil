#===============================================================================
# Mega Starter Reworks (Vermeil)
# - FLEURDEMAL
# - THERMALFRONT
# - FEUDALWARD
#===============================================================================

module VermeilMegaStarterReworks
  def self.draining_move?(move)
    return false if !move
    return true if move.is_a?(Battle::Move::HealUserByHalfOfDamageDone)
    return true if move.is_a?(Battle::Move::HealUserByHalfOfDamageDoneIfTargetAsleep)
    return true if move.is_a?(Battle::Move::HealUserByThreeQuartersOfDamageDone)
    return false
  end
end

#-------------------------------------------------------------------------------
# FLEURDEMAL
# Draining moves heal more HP.
# If the target is poisoned, draining moves deal more damage.
#-------------------------------------------------------------------------------
Battle::AbilityEffects::DamageCalcFromUser.add(:FLEURDEMAL,
  proc { |ability, user, target, move, mults, power, type|
    next if !VermeilMegaStarterReworks.draining_move?(move)
    next if !target || !target.poisoned?
    mults[:power_multiplier] *= 1.3
  }
)

class Battle::Move::HealUserByHalfOfDamageDone
  if !method_defined?(:vermeil_fleurdemal_half_pbEffectAgainstTarget_original)
    alias vermeil_fleurdemal_half_pbEffectAgainstTarget_original pbEffectAgainstTarget
  end

  def pbEffectAgainstTarget(user, target)
    return vermeil_fleurdemal_half_pbEffectAgainstTarget_original(user, target) if !user&.hasActiveAbility?(:FLEURDEMAL)
    return if target.damageState.hpLost <= 0
    hpGain = (target.damageState.hpLost * 0.75).round
    user.pbRecoverHPFromDrain(hpGain, target)
  end
end

class Battle::Move::HealUserByHalfOfDamageDoneIfTargetAsleep
  if !method_defined?(:vermeil_fleurdemal_dreameater_pbEffectAgainstTarget_original)
    alias vermeil_fleurdemal_dreameater_pbEffectAgainstTarget_original pbEffectAgainstTarget
  end

  def pbEffectAgainstTarget(user, target)
    return vermeil_fleurdemal_dreameater_pbEffectAgainstTarget_original(user, target) if !user&.hasActiveAbility?(:FLEURDEMAL)
    return if target.damageState.hpLost <= 0
    hpGain = (target.damageState.hpLost * 0.75).round
    user.pbRecoverHPFromDrain(hpGain, target)
  end
end

class Battle::Move::HealUserByThreeQuartersOfDamageDone
  if !method_defined?(:vermeil_fleurdemal_threequarters_pbEffectAgainstTarget_original)
    alias vermeil_fleurdemal_threequarters_pbEffectAgainstTarget_original pbEffectAgainstTarget
  end

  def pbEffectAgainstTarget(user, target)
    return vermeil_fleurdemal_threequarters_pbEffectAgainstTarget_original(user, target) if !user&.hasActiveAbility?(:FLEURDEMAL)
    return if target.damageState.hpLost <= 0
    hpGain = (target.damageState.hpLost * 1.0).round
    user.pbRecoverHPFromDrain(hpGain, target)
  end
end

#-------------------------------------------------------------------------------
# THERMALFRONT
# Immunity to Ground-type moves.
# Electric-type moves from this user can hit Ground-types.
#-------------------------------------------------------------------------------
Battle::AbilityEffects::MoveImmunity.add(:THERMALFRONT,
  proc { |ability, user, target, move, type, battle, show_message|
    next false if type != :GROUND
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

class Battle::Move
  if !method_defined?(:vermeil_thermalfront_pbCalcTypeModSingle_original)
    alias vermeil_thermalfront_pbCalcTypeModSingle_original pbCalcTypeModSingle
  end

  def pbCalcTypeModSingle(moveType, defType, user, target)
    if moveType == :ELECTRIC && defType == :GROUND && user && user.hasActiveAbility?(:THERMALFRONT)
      return Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER
    end
    return vermeil_thermalfront_pbCalcTypeModSingle_original(moveType, defType, user, target)
  end
end

#-------------------------------------------------------------------------------
# FEUDALWARD
# Reduces damage while at full HP.
# Blocks incoming priority moves.
#-------------------------------------------------------------------------------
Battle::AbilityEffects::DamageCalcFromTarget.add(:FEUDALWARD,
  proc { |ability, user, target, move, mults, power, type|
    next if !target || target.fainted?
    next if target.hp < target.totalhp
    mults[:final_damage_multiplier] *= 0.75
  }
)

Battle::AbilityEffects::MoveImmunity.add(:FEUDALWARD,
  proc { |ability, user, target, move, type, battle, show_message|
    next false if !move || move.pbPriority(user) <= 0
    if show_message
      battle.pbShowAbilitySplash(target)
      if Battle::Scene::USE_ABILITY_SPLASH
        battle.pbDisplay(_INTL("It doesn't affect {1}...", target.pbThis(true)))
      else
        battle.pbDisplay(_INTL("{1}'s {2} blocked the priority move!",
          target.pbThis, target.abilityName))
      end
      battle.pbHideAbilitySplash(target)
    end
    next true
  }
)
