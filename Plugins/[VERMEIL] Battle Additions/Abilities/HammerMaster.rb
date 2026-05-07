#===============================================================================
# Hammer Master - Custom Ability
#===============================================================================

module Battle::AbilityEffects
  # Moves treated as hammer/mace/club-style attacks for Hammer Master.
  HAMMER_MASTER_MOVES = [
    :ICEHAMMER,      # Ice Hammer
    :CRABHAMMER,     # Crabhammer
    :HAMMERARM,      # Hammer Arm
    :NEEDLEARM,      # Needle Arm
    :WOODHAMMER,     # Wood Hammer
    :GIGATONHAMMER,  # Gigaton Hammer
    :DRAGONHAMMER,   # Dragon Hammer
    :BONECLUB,       # Bone Club
    :SHADOWBONE,     # Shadow Bone
    :BONEMERANG,     # Bonemerang
    :BULBBASH,       # Bulb Bash
    :BLAZINGCLUB     # Blazing Club
  ]

  def self.hammer_master_move?(move_id)
    return HAMMER_MASTER_MOVES.include?(move_id)
  end

  # 50% power boost to hammer-style moves.
  DamageCalcFromUser.add(:BLUDGEONMASTER,
    proc { |ability, user, target, move, mults, power, type|
      next if !Battle::AbilityEffects.hammer_master_move?(move.id)
      mults[:power_multiplier] *= 1.5
    }
  )

  # Override Battle Armor behavior so Hammer Master hammer-moves can still crit.
  CriticalCalcFromTarget.add(:BATTLEARMOR,
    proc { |ability, user, target, c|
      choice = user.battle.choices[user.index]
      move = (choice) ? choice[2] : nil
      if user.hasActiveAbility?(:BLUDGEONMASTER) &&
         move &&
         Battle::AbilityEffects.hammer_master_move?(move.id)
        next c
      end
      next -1
    }
  )

  # Same override for Shell Armor.
  CriticalCalcFromTarget.add(:SHELLARMOR,
    proc { |ability, user, target, c|
      choice = user.battle.choices[user.index]
      move = (choice) ? choice[2] : nil
      if user.hasActiveAbility?(:BLUDGEONMASTER) &&
         move &&
         Battle::AbilityEffects.hammer_master_move?(move.id)
        next c
      end
      next -1
    }
  )
end
