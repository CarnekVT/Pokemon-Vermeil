Battle::AbilityEffects::DamageCalcFromUser.add(:STRIKER,
  proc { |ability, user, target, move, mults, power, type|
    mults[:power_multiplier] *= 1.5 if MoveClasses::KICK_MOVES.include?(move.id)
  }
)

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

Battle::AbilityEffects::DamageCalcFromUser.add(:OVERCHARGE,
  proc { |ability, user, target, move, mults, power, type|
    mults[:power_multiplier] *= 1.33 if type == :ELECTRIC
  }
)

Battle::AbilityEffects::OnHPDroppedBelowHalf.add(:CRYSTALORBIT,
  proc { |ability, battler, move_user, battle|
    next if battler.fainted?
    battle.pbDisplay(_INTL("{1} surrounds itself with a crystal orbit!", battler.pbThis))
    battler.pbRaiseStatStageByAbility(:SPECIAL_DEFENSE, 1, battler)
  }
)
