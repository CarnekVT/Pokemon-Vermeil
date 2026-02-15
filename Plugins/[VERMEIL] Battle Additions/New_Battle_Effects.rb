#===============================================================================
# Battle Additions - Efectos personalizados
#===============================================================================

#-------------------------------------------------------------------------------
# Añadir PBEffect para Burning Rampage
#-------------------------------------------------------------------------------
if !PBEffects.const_defined?(:BurningRampage)
  module PBEffects
    BurningRampage = 164  # Número único para el efecto
  end
end

#-------------------------------------------------------------------------------
# Agregar el efecto a la lista de PBEffects de Deluxe Battle Kit
#-------------------------------------------------------------------------------
if defined?($DELUXE_PBEFFECTS) && !$DELUXE_PBEFFECTS[:battler][:counter].include?(:BurningRampage)
  $DELUXE_PBEFFECTS[:battler][:counter].push(:BurningRampage)
end

#-------------------------------------------------------------------------------
# Custom FunctionCode: Ignores screens if user's Burning Rampage is fully charged
#-------------------------------------------------------------------------------
class Battle::Move::IgnoreScreensIfUserBurningRampageFull < Battle::Move
  def ignoresReflect?
    user_battler = nil
    if defined?(@battle) && @battle && @battle.respond_to?(:lastMoveUser) && @battle.lastMoveUser && @battle.lastMoveUser >= 0
      user_battler = @battle.battlers[@battle.lastMoveUser]
    end
    if user_battler
      PBDebug.log("[Burning Rampage] ignoresReflect? called - DerivedUser: #{user_battler.pbThis}, AbilityActive: #{user_battler.hasActiveAbility?(:BURNINGRAMPAGE)}, Stacks: #{user_battler.effects[PBEffects::BurningRampage] || 0}")
      return false if !user_battler.hasActiveAbility?(:BURNINGRAMPAGE)
      return user_battler.effects[PBEffects::BurningRampage] == 5
    else
      PBDebug.log("[Burning Rampage] ignoresReflect? called - no user found via @battle.lastMoveUser")
      return false
    end
  end
end

#-------------------------------------------------------------------------------
# Custom FunctionCode: Reactive Thorn
# Category depends on user's higher damage stat (like Photon Geyser)
# Super effective against Flying and Bug types, guarantees Speed reduction
#-------------------------------------------------------------------------------
class Battle::Move::ReactiveThorn < Battle::Move
  def initialize(battle, move)
    super
    @calcCategory = 1
  end

  def physicalMove?(thisType = nil); return (@calcCategory == 0); end
  def specialMove?(thisType = nil);  return (@calcCategory == 1); end

  def pbOnStartUse(user, targets)
    # Calculate user's effective attacking value (considering stat stages)
    max_stage = Battle::Battler::STAT_STAGE_MAXIMUM
    stageMul = Battle::Battler::STAT_STAGE_MULTIPLIERS
    stageDiv = Battle::Battler::STAT_STAGE_DIVISORS
    atk        = user.attack
    atkStage   = user.stages[:ATTACK] + max_stage
    realAtk    = (atk.to_f * stageMul[atkStage] / stageDiv[atkStage]).floor
    spAtk      = user.spatk
    spAtkStage = user.stages[:SPECIAL_ATTACK] + max_stage
    realSpAtk  = (spAtk.to_f * stageMul[spAtkStage] / stageDiv[spAtkStage]).floor
    # Determine move's category based on higher damage stat
    @calcCategory = (realAtk > realSpAtk) ? 0 : 1
  end

  def pbCalcTypeModSingle(moveType, defType, user, target)
    # Super effective against Flying and Bug types
    return Effectiveness::SUPER_EFFECTIVE_MULTIPLIER if defType == :FLYING || defType == :BUG
    return super
  end
end

#-------------------------------------------------------------------------------
# Custom FunctionCode: Warlord's Crush
# Deals double damage if the target's Attack is lowered.
#-------------------------------------------------------------------------------
class Battle::Move::WarlordsCrush < Battle::Move
  def pbBaseDamage(baseDmg, user, target)
    if target.stages[:ATTACK] < 0
      PBDebug.log("[Warlord's Crush] Target Attack is lowered, doubling damage.")
      return baseDmg * 2
    end
    return baseDmg
  end
end

#-------------------------------------------------------------------------------
# Custom FunctionCode: Bergmite Sortie
# Hits 2-5 times and may lower target's Speed each hit.
#-------------------------------------------------------------------------------
class Battle::Move::BergmiteSortie < Battle::Move::LowerTargetSpeed1
  def multiHitMove?; return true; end

  def pbNumHits(user, targets)
    hitChances = [
      2, 2, 2, 2, 2, 2, 2,
      3, 3, 3, 3, 3, 3, 3,
      4, 4, 4,
      5, 5, 5
    ]
    r = @battle.pbRandom(hitChances.length)
    r = hitChances.length - 1 if user.hasActiveAbility?(:SKILLLINK)
    return hitChances[r]
  end
end

#-------------------------------------------------------------------------------
# Custom FunctionCode: Glacier Crunch
# Biting move that is super effective against Steel.
#-------------------------------------------------------------------------------
class Battle::Move::GlacierCrunch < Battle::Move
  def pbCalcTypeModSingle(moveType, defType, user, target)
    return Effectiveness::SUPER_EFFECTIVE_MULTIPLIER if defType == :STEEL
    return super
  end
end

#-------------------------------------------------------------------------------
# Custom FunctionCode: Ancient Vigor
# Drains HP (1/2 damage dealt) and may raise user's Def and SpDef.
#-------------------------------------------------------------------------------
class Battle::Move::AncientVigor < Battle::Move::HealUserByHalfOfDamageDone
  def pbAdditionalEffect(user, target)
    user.pbRaiseStatStage(:DEFENSE, 1, user) if user.pbCanRaiseStatStage?(:DEFENSE, user, self)
    user.pbRaiseStatStage(:SPECIAL_DEFENSE, 1, user) if user.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, user, self)
  end
end

#-------------------------------------------------------------------------------
# Custom FunctionCode: Serpent Flare
# Hits 2-5 times and may burn target each hit.
#-------------------------------------------------------------------------------
class Battle::Move::SerpentFlare < Battle::Move::BurnTarget
  def multiHitMove?; return true; end

  def pbNumHits(user, targets)
    hitChances = [
      2, 2, 2, 2, 2, 2, 2,
      3, 3, 3, 3, 3, 3, 3,
      4, 4, 4,
      5, 5, 5
    ]
    r = @battle.pbRandom(hitChances.length)
    r = hitChances.length - 1 if user.hasActiveAbility?(:SKILLLINK)
    return hitChances[r]
  end
end

#-------------------------------------------------------------------------------
# Custom FunctionCode: Dynastic Fang
# Biting move with +1 priority if target is below 50% HP.
#-------------------------------------------------------------------------------
class Battle::Move::DynasticFang < Battle::Move
  def pbPriority(user)
    ret = super
    target_idx = @battle.choices[user.index][3]
    if target_idx && target_idx >= 0
      target = @battle.battlers[target_idx]
      if target && !target.fainted? && (target.hp * 2 < target.totalhp)
        ret += 1
      end
    end
    return ret
  end
end
