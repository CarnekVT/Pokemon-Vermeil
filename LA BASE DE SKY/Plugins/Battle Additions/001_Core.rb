# ReactiveThorn — uses higher offensive stat, super effective vs Flying/Bug
class Battle::Move::ReactiveThorn < Battle::Move
  def initialize(battle, move)
    super
    @calcCategory = 1
  end

  def physicalMove?(thisType = nil); return (@calcCategory == 0); end
  def specialMove?(thisType = nil);  return (@calcCategory == 1); end

  def pbOnStartUse(user, targets)
    target = targets[0]
    return if !target
    real_atk  = user.stat_with_stages(:ATTACK)
    real_spatk = user.stat_with_stages(:SPECIAL_ATTACK)
    @calcCategory = (real_atk > real_spatk) ? 0 : 1
  end

  def pbCalcTypeModSingle(moveType, defType, user, target)
    return Effectiveness::SUPER_EFFECTIVE_MULTIPLIER if [:FLYING, :BUG].include?(defType)
    return super
  end
end

# BurningRampage — Fire Spin trapping + 10% burn
class Battle::Move::BurningRampage < Battle::Move
  def pbEffectAgainstTarget(user, target)
    return if target.fainted? || target.damageState.substitute
    if target.effects[PBEffects::Trapping] == 0
      target.effects[PBEffects::Trapping] = 5 + @battle.pbRandom(2)
      target.effects[PBEffects::TrappingMove] = @id
      target.effects[PBEffects::TrappingUser] = user.index
      @battle.pbDisplay(_INTL("¡{1} fue atrapado en un torbellino de fuego!", target.pbThis))
    end
    if @battle.pbRandom(100) < 10
      target.pbBurn(user) if target.pbCanBurn?(user, false, self)
    end
  end
end

# WarlordsCrush — 30% flinch + sets Grassy Terrain
class Battle::Move::WarlordsCrush < Battle::Move
  def pbEffectAfterHit(user, target)
    if @battle.pbCanStartTerrain?(:Grassy)
      @battle.pbStartTerrain(user, :Grassy)
    end
  end

  def pbAdditionalEffect(user, target)
    target.pbFlinch(user) if target.pbCanFlinch?(user, false, self)
  end
end

# SpikyGrasp — Grass-type bind
class Battle::Move::SpikyGrasp < Battle::Move
  def pbEffectAgainstTarget(user, target)
    return if target.fainted? || target.damageState.substitute
    return if target.effects[PBEffects::Trapping] > 0
    target.effects[PBEffects::Trapping] = 5 + @battle.pbRandom(2)
    target.effects[PBEffects::TrappingMove] = @id
    target.effects[PBEffects::TrappingUser] = user.index
    @battle.pbDisplay(_INTL("¡{1} fue atrapado por zarzas punzantes!", target.pbThis))
  end
end

# GlacierCrunch — super effective against Rock types
class Battle::Move::GlacierCrunch < Battle::Move
  def pbCalcTypeModSingle(moveType, defType, user, target)
    return Effectiveness::SUPER_EFFECTIVE_MULTIPLIER if defType == :ROCK
    return super
  end
end

# AncientVigor — Rock-type drain, heals 50% of damage dealt
class Battle::Move::AncientVigor < Battle::Move
  def healingMove?; return true; end

  def pbEffectAgainstTarget(user, target)
    return if target.damageState.hpLost <= 0
    hpGain = (target.damageState.hpLost / 2.0).round
    user.pbRecoverHPFromDrain(hpGain, target)
  end
end

# SerpentFlare — Fire-type, raises SpAtk by 1 stage after hit
class Battle::Move::SerpentFlare < Battle::Move::StatUpMove
  def initialize(battle, move)
    super
    @statUp = [:SPECIAL_ATTACK, 1]
  end
end

# DynasticFang — Dark-type multi-hit (2-5 times)
class Battle::Move::DynasticFang < Battle::Move
  def multiHitMove?; return true; end

  def pbNumHits(user, targets)
    return 4 + @battle.pbRandom(2) if user.hasActiveItem?(:LOADEDDICE)
    hitChances = [2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3, 3, 3, 3, 4, 4, 4, 5, 5, 5]
    r = @battle.pbRandom(hitChances.length)
    r = hitChances.length - 1 if user.hasActiveAbility?(:SKILLLINK)
    return hitChances[r]
  end
end

# BergmiteSortie — Ice-type damaging move
class Battle::Move::BergmiteSortie < Battle::Move
end
