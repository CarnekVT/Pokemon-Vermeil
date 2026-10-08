#===============================================================================
# Mega Signature Abilities (Vermeil)
# - IRONCLAD
# - PRECOGNITION
# - HIDDENARSENAL
#===============================================================================

#-------------------------------------------------------------------------------
# IRONCLAD
#-------------------------------------------------------------------------------
# Halves physical damage received.
Battle::AbilityEffects::DamageCalcFromTarget.add(:IRONCLAD,
  proc { |ability, user, target, move, mults, power, type|
    mults[:final_damage_multiplier] /= 2 if move&.physicalMove?
  }
)

# Uses Defense stat/stages instead of Attack for physical moves.
class Battle::Move
  if !method_defined?(:vermeil_ironclad_pbGetAttackStats_original)
    alias vermeil_ironclad_pbGetAttackStats_original pbGetAttackStats
  end

  def pbGetAttackStats(user, target)
    if user&.hasActiveAbility?(:IRONCLAD) && physicalMove?
      return user.defense, user.stages[:DEFENSE] + Battle::Battler::STAT_STAGE_MAXIMUM
    end
    return vermeil_ironclad_pbGetAttackStats_original(user, target)
  end
end

class Battle::Move::UseTargetAttackInsteadOfUserAttack
  if !method_defined?(:vermeil_ironclad_foulplay_pbGetAttackStats_original)
    alias vermeil_ironclad_foulplay_pbGetAttackStats_original pbGetAttackStats
  end

  def pbGetAttackStats(user, target)
    if user&.hasActiveAbility?(:IRONCLAD) && physicalMove?
      return user.defense, user.stages[:DEFENSE] + Battle::Battler::STAT_STAGE_MAXIMUM
    end
    return vermeil_ironclad_foulplay_pbGetAttackStats_original(user, target)
  end
end

#-------------------------------------------------------------------------------
# PRECOGNITION
#-------------------------------------------------------------------------------
# Store per-use flag for Fire/Psychic moves to bypass Protect/screens.
class Battle::Move
  if !method_defined?(:vermeil_precognition_pbCalcType_original)
    alias vermeil_precognition_pbCalcType_original pbCalcType
  end

  def pbCalcType(user)
    ret = vermeil_precognition_pbCalcType_original(user)
    @vermeil_precognition_active = (user&.hasActiveAbility?(:PRECOGNITION) &&
                                    [:FIRE, :PSYCHIC].include?(ret))
    return ret
  end

  if !method_defined?(:vermeil_precognition_canProtectAgainst_original)
    alias vermeil_precognition_canProtectAgainst_original canProtectAgainst?
  end

  def canProtectAgainst?
    return false if @vermeil_precognition_active
    return vermeil_precognition_canProtectAgainst_original
  end

  if !method_defined?(:vermeil_precognition_ignoresReflect_original)
    alias vermeil_precognition_ignoresReflect_original ignoresReflect?
  end

  def ignoresReflect?
    return true if @vermeil_precognition_active
    return vermeil_precognition_ignoresReflect_original
  end
end

# Fire/Psychic moves from this user always hit.
Battle::AbilityEffects::AccuracyCalcFromUser.add(:PRECOGNITION,
  proc { |ability, modifiers, user, target, move, type|
    if [:FIRE, :PSYCHIC].include?(type)
      modifiers[:base_accuracy] = 0
    end
  }
)

# Immune to priority moves.
Battle::AbilityEffects::MoveImmunity.add(:PRECOGNITION,
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

#-------------------------------------------------------------------------------
# HIDDEN ARSENAL
#-------------------------------------------------------------------------------
# Multi-hit moves that vary in number always hit maximum times.
class Battle::Move::HitTwoToFiveTimes
  if !method_defined?(:vermeil_hiddenarsenal_pbNumHits_original)
    alias vermeil_hiddenarsenal_pbNumHits_original pbNumHits
  end

  def pbNumHits(user, targets)
    return 5 if user&.hasActiveAbility?(:HIDDENARSENAL)
    return vermeil_hiddenarsenal_pbNumHits_original(user, targets)
  end
end

# Priority moves are boosted by 50%.
Battle::AbilityEffects::DamageCalcFromUser.add(:HIDDENARSENAL,
  proc { |ability, user, target, move, mults, power, type|
    mults[:power_multiplier] *= 1.5 if move && move.pbPriority(user) > 0
  }
)
