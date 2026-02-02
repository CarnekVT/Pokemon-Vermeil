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