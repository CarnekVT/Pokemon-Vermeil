#===============================================================================
# Core Ability Reworks (Vermeil)
# - NORMALIZE: field-wide Normal typing while bearer is active.
# - ICEBODY: 30% chance to freeze contact attacker.
# - BULLETPROOF: also blocks explosive self-KO moves.
# - SOLARPOWER: keeps Sp. Atk boost in sun, removes end-of-round HP loss.
# - ILLUMINATE: boosts Electric and Light Moves by 1.2x.
# - CORROSION: Poison attacks can hit Steel-types.
# - SKYSNARE: traps Flying-types and resists Flying-type moves.
#===============================================================================
class HandlerHashSymbol
  def remove(key)
    echoln "Removing #{key}"
    @hash.delete(key)
    @add_ifs.delete(key)
  end
end

module VermeilAbilityReworks
  LIGHT_MOVES = [
    :FLASH,
    :FLASHCANNON,
    :LUMINACRASH,
    :MORNINGSUN,
    :MOONLIGHT,
    :SYNTHESIS,
    :SWIFT,
    :REFLECT,
    :LIGHTSCREEN,
    :AURORAVEIL,
    :AURORABEAM,
    :MIRRORCOAT,
    :SPOTLIGHT,
    :PHOTONGEYSER,
    :PRISMATICLASER,
    :LIGHTOFRUIN,
    :DAZZLINGGLEAM,
    :LUSTERPURGE,
    :POWERGEM,
    :SOLARBEAM,
    :SOLARBLADE,
    :MINDBLOWN,
    :SIGNALBEAM,
    :CONFUSERAY,
    :SUNSTEELSTRIKE,
    :MOONGEISTBEAM,
    :FLEURCANNON,
    :FLAMEBURST
  ]

  def self.light_move?(move)
    return false if !move
    return LIGHT_MOVES.include?(move.id)
  end
end

#-------------------------------------------------------------------------------
# NORMALIZE
#-------------------------------------------------------------------------------
# Disable the default move type conversion/boost behavior.
Battle::AbilityEffects::ModifyMoveBaseType.add(:NORMALIZE,
  proc { |ability, user, move, type|
    next type
  }
)

class Battle
  def pbNormalizeFieldActive?
    allBattlers.each do |b|
      next if !b || b.fainted?
      return true if b.hasActiveAbility?(:NORMALIZE)
    end
    return false
  end
end

class Battle::Battler
  if !method_defined?(:vermeil_rework_normalize_pbTypes_original)
    alias vermeil_rework_normalize_pbTypes_original pbTypes
  end

  def pbTypes(withExtraType = false)
    if @battle && @battle.pbNormalizeFieldActive?
      return [:NORMAL]
    end
    return vermeil_rework_normalize_pbTypes_original(withExtraType)
  end
end

#-------------------------------------------------------------------------------
# ICE BODY
#-------------------------------------------------------------------------------
Battle::AbilityEffects::OnBeingHit.add(:ICEBODY,
  proc { |ability, user, target, move, battle|
    next if !move.pbContactMove?(user)
    next if user.frozen? || battle.pbRandom(100) >= 30
    battle.pbShowAbilitySplash(target)
    if user.pbCanFreeze?(target, Battle::Scene::USE_ABILITY_SPLASH) &&
       user.affectedByContactEffect?(Battle::Scene::USE_ABILITY_SPLASH)
      msg = nil
      if !Battle::Scene::USE_ABILITY_SPLASH
        msg = _INTL("{1}'s {2} froze {3}!", target.pbThis, target.abilityName, user.pbThis(true))
      end
      user.pbFreeze(msg)
    end
    battle.pbHideAbilitySplash(target)
  }
)

#-------------------------------------------------------------------------------
# BULLETPROOF
#-------------------------------------------------------------------------------
Battle::AbilityEffects::MoveImmunity.add(:BULLETPROOF,
  proc { |ability, user, target, move, type, battle, show_message|
    explosive_move = false
    explosive_move ||= (move.respond_to?(:function_code) && move.function_code == "UserFaintsExplosive")
    explosive_move ||= move.class.to_s.end_with?("::UserFaintsExplosive")
    next false if !move.bombMove? && !explosive_move
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

#-------------------------------------------------------------------------------
# SOLAR POWER
#-------------------------------------------------------------------------------
# Keep damage boost in sun from base scripts; remove end-of-round HP loss.
Battle::AbilityEffects::EndOfRoundWeather.add(:SOLARPOWER,
  proc { |ability, weather, battler, battle|
    next
  }
)

#-------------------------------------------------------------------------------
# ILLUMINATE
#-------------------------------------------------------------------------------
Battle::AbilityEffects::DamageCalcFromUser.add(:ILLUMINATE,
  proc { |ability, user, target, move, mults, power, type|
    if type == :ELECTRIC || VermeilAbilityReworks.light_move?(move)
      mults[:power_multiplier] *= 1.2
    end
  }
)

Battle::AbilityEffects::StatLossImmunity.add(:ILLUMINATE,
  proc { |ability, battler, stat, battle, showMessages|
    next true if stat == :ACCURACY
  }
)

class Battle::Move::StartWeakenPhysicalDamageAgainstUserSide < Battle::Move
  if !method_defined?(:vermeil_rework_illum_reflect_pbEffectGeneral_original)
    alias vermeil_rework_illum_reflect_pbEffectGeneral_original pbEffectGeneral
  end

  def pbEffectGeneral(user)
    vermeil_rework_illum_reflect_pbEffectGeneral_original(user)
    if user.hasActiveAbility?(:ILLUMINATE) && user.pbOwnSide.effects[PBEffects::Reflect] > 0
      user.pbOwnSide.effects[PBEffects::Reflect] = [user.pbOwnSide.effects[PBEffects::Reflect], 8].max
    end
  end
end

class Battle::Move::StartWeakenSpecialDamageAgainstUserSide < Battle::Move
  if !method_defined?(:vermeil_rework_illum_lscreen_pbEffectGeneral_original)
    alias vermeil_rework_illum_lscreen_pbEffectGeneral_original pbEffectGeneral
  end

  def pbEffectGeneral(user)
    vermeil_rework_illum_lscreen_pbEffectGeneral_original(user)
    if user.hasActiveAbility?(:ILLUMINATE) && user.pbOwnSide.effects[PBEffects::LightScreen] > 0
      user.pbOwnSide.effects[PBEffects::LightScreen] = [user.pbOwnSide.effects[PBEffects::LightScreen], 8].max
    end
  end
end

class Battle::Move::StartWeakenDamageAgainstUserSideIfHail < Battle::Move
  if !method_defined?(:vermeil_rework_illum_aveil_pbEffectGeneral_original)
    alias vermeil_rework_illum_aveil_pbEffectGeneral_original pbEffectGeneral
  end

  def pbEffectGeneral(user)
    vermeil_rework_illum_aveil_pbEffectGeneral_original(user)
    if user.hasActiveAbility?(:ILLUMINATE) && user.pbOwnSide.effects[PBEffects::AuroraVeil] > 0
      user.pbOwnSide.effects[PBEffects::AuroraVeil] = [user.pbOwnSide.effects[PBEffects::AuroraVeil], 8].max
    end
  end
end

#-------------------------------------------------------------------------------
# CORROSION
#-------------------------------------------------------------------------------
# Poison attacks can hit Steel-types if user has Corrosion.
class Battle::Move
  if !method_defined?(:vermeil_rework_corrosion_pbCalcTypeModSingle_original)
    alias vermeil_rework_corrosion_pbCalcTypeModSingle_original pbCalcTypeModSingle
  end

  def pbCalcTypeModSingle(moveType, defType, user, target)
    if moveType == :POISON && defType == :STEEL && user && user.hasActiveAbility?(:CORROSION)
      return Effectiveness::NORMAL_EFFECTIVE_MULTIPLIER
    end
    return vermeil_rework_corrosion_pbCalcTypeModSingle_original(moveType, defType, user, target)
  end
end

#-------------------------------------------------------------------------------
# SKYSNARE
#-------------------------------------------------------------------------------
Battle::AbilityEffects::TrappingByTarget.add(:SKYSNARE,
  proc { |ability, switcher, bearer, battle|
    next true if switcher.pbHasType?(:FLYING)
  }
)

Battle::AbilityEffects::DamageCalcFromTarget.add(:SKYSNARE,
  proc { |ability, user, target, move, mults, power, type|
    mults[:power_multiplier] /= 2 if type == :FLYING
  }
)
