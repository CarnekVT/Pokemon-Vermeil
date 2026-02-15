#===============================================================================
# Avalugg / Mega Feraligatr - Custom Abilities
#===============================================================================

module Battle::AbilityEffects
  #===========================================================================
  # Habbakuk Hull
  # - Holder takes half damage from Fire/Fighting/Rock.
  # - Allies take 25% less damage from spread moves in doubles.
  #===========================================================================
  DamageCalcFromTarget.add(:HABBAKUKHULL,
    proc { |ability, user, target, move, mults, power, type|
      next unless [:FIRE, :FIGHTING, :ROCK].include?(type)
      mults[:final_damage_multiplier] /= 2
    }
  )

  DamageCalcFromTargetAlly.add(:HABBAKUKHULL,
    proc { |ability, user, target, move, mults, power, type|
      next if !target.battle.doubleBattle?
      next if !move.pbTarget(user).targets_foe
      next if move.pbTarget(user).num_targets <= 1
      mults[:final_damage_multiplier] *= 0.75
    }
  )

  #===========================================================================
  # Permafrost Jaw
  # - Biting moves get 1.5x power.
  # - Biting moves ignore target defensive Ability effects.
  #===========================================================================
  DamageCalcFromUser.add(:PERMAFROSTJAW,
    proc { |ability, user, target, move, mults, power, type|
      next if !move.bitingMove?
      mults[:power_multiplier] *= 1.5
    }
  )

  #===========================================================================
  # Delta Plating
  # - Holder takes half damage from super-effective moves.
  # - On critical hit taken, raise Speed by 2.
  #===========================================================================
  DamageCalcFromTarget.add(:DELTAPLATING,
    proc { |ability, user, target, move, mults, power, type|
      next if !Effectiveness.super_effective?(target.damageState.typeMod)
      mults[:final_damage_multiplier] /= 2
    }
  )

  OnBeingHit.add(:DELTAPLATING,
    proc { |ability, user, target, move, battle|
      next if !move || !move.damagingMove?
      next if !target.damageState.critical
      next if target.fainted?
      next if !target.pbCanRaiseStatStage?(:SPEED, target)
      battle.pbShowAbilitySplash(target)
      target.pbRaiseStatStage(:SPEED, 2, target)
      battle.pbHideAbilitySplash(target)
    }
  )
end

#===============================================================================
# Permafrost Jaw mold-breaker behavior for biting moves.
#===============================================================================
class Battle::Battler
  if !method_defined?(:permafrost_jaw_hasMoldBreaker_original)
    alias permafrost_jaw_hasMoldBreaker_original hasMoldBreaker?
  end

  def hasMoldBreaker?
    if hasActiveAbility?(:PERMAFROSTJAW)
      choice = @battle.choices[@index]
      if choice && choice[0] == :UseMove && choice[2] && choice[2].bitingMove?
        return true
      end
    end
    return permafrost_jaw_hasMoldBreaker_original
  end
end
