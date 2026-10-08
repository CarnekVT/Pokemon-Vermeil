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
      next if !move || !Battle::AbilityEffects.hammer_master_move?(move.id)
      mults[:power_multiplier] *= 1.5
    }
  )

  # Override Battle Armor behavior so Hammer Master hammer-moves can still crit.
  CriticalCalcFromTarget.add(:BATTLEARMOR,
    proc { |ability, user, target, c|
      move = user.battle.instance_variable_get(:@vermeil_current_critical_move)
      if !move
        choice = user.battle.choices[user.index]
        move = (choice) ? choice[2] : nil
      end
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
      move = user.battle.instance_variable_get(:@vermeil_current_critical_move)
      if !move
        choice = user.battle.choices[user.index]
        move = (choice) ? choice[2] : nil
      end
      if user.hasActiveAbility?(:BLUDGEONMASTER) &&
         move &&
         Battle::AbilityEffects.hammer_master_move?(move.id)
        next c
      end
      next -1
    }
  )
end


# Keep the actual move being evaluated available to the critical handlers. This
# also makes Bludgeon Master work for hammer moves called indirectly rather than
# only for the move stored in the battler's normal choice.
class Battle::Move
  if !method_defined?(:vermeil_bludgeon_master_pbIsCritical_original)
    alias vermeil_bludgeon_master_pbIsCritical_original pbIsCritical?
  end

  def pbIsCritical?(user, target)
    old_move = @battle.instance_variable_get(:@vermeil_current_critical_move)
    @battle.instance_variable_set(:@vermeil_current_critical_move, self)
    begin
      return vermeil_bludgeon_master_pbIsCritical_original(user, target)
    ensure
      @battle.instance_variable_set(:@vermeil_current_critical_move, old_move)
    end
  end
end
