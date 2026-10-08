#===============================================================================
# BURNING RAMPAGE
# Fire moves trap the target for 5-6 turns when they deal a hit.
#===============================================================================
Battle::AbilityEffects::OnDealingHit.add(:BURNINGRAMPAGE,
  proc { |ability, user, target, move, hitNum|
    next if target.fainted? || target.damageState.substitute
    next if target.effects[PBEffects::Trapping] > 0
    next if move.type != :FIRE
    target.effects[PBEffects::Trapping] = 5 + user.battle.pbRandom(2)
    target.effects[PBEffects::TrappingMove] = move.id
    target.effects[PBEffects::TrappingUser] = user.index
    user.battle.pbDisplay(_INTL("{1} was trapped by a burning rampage!", target.pbThis))
  }
)
