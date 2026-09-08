#===============================================================================
# Habbakuk Hull / Permafrost Jaw / Delta Plating
#===============================================================================
module Battle::AbilityEffects
  # Holder takes half damage from Fire/Fighting/Rock.
  DamageCalcFromTarget.add(:HABBAKUKHULL,
    proc { |ability, user, target, move, mults, power, type|
      next if ![:FIRE, :FIGHTING, :ROCK].include?(type)
      mults[:final_damage_multiplier] *= 0.5
    }
  )

  # Allies take 25% less damage from opposing spread moves in doubles.
  DamageCalcFromTargetAlly.add(:HABBAKUKHULL,
    proc { |ability, user, target, move, mults, power, type|
      next if !target || !target.battle.doubleBattle?
      next if !VermeilBattleAdditions.spread_move?(move, user)
      mults[:final_damage_multiplier] *= 0.75
    }
  )

  # Biting moves get 1.5x power.
  DamageCalcFromUser.add(:PERMAFROSTJAW,
    proc { |ability, user, target, move, mults, power, type|
      next if !move || !move.bitingMove?
      mults[:power_multiplier] *= 1.5
    }
  )

  # Holder takes half damage from super-effective moves.
  DamageCalcFromTarget.add(:DELTAPLATING,
    proc { |ability, user, target, move, mults, power, type|
      next if !target || !Effectiveness.super_effective?(target.damageState.typeMod)
      mults[:final_damage_multiplier] *= 0.5
    }
  )

  # Critical hit taken -> Speed +2.
  OnBeingHit.add(:DELTAPLATING,
    proc { |ability, user, target, move, battle|
      next if !move || !move.damagingMove? || !target.damageState.critical
      next if target.fainted? || target.damageState.substitute
      next if !target.pbCanRaiseStatStage?(:SPEED, target)
      battle.pbShowAbilitySplash(target)
      target.pbRaiseStatStage(:SPEED, 2, target)
      battle.pbHideAbilitySplash(target)
    }
  )
end

# Biting moves from Permafrost Jaw ignore target defensive Ability effects.
class Battle::Battler
  if !method_defined?(:vermeil_permafrost_jaw_hasMoldBreaker_original)
    alias vermeil_permafrost_jaw_hasMoldBreaker_original hasMoldBreaker?
  end

  def hasMoldBreaker?
    if hasActiveAbility?(:PERMAFROSTJAW)
      choice = (@battle && @battle.choices) ? @battle.choices[@index] : nil
      move = (choice && choice[0] == :UseMove) ? choice[2] : nil
      return true if move && move.respond_to?(:bitingMove?) && move.bitingMove?
    end
    return vermeil_permafrost_jaw_hasMoldBreaker_original
  end
end
