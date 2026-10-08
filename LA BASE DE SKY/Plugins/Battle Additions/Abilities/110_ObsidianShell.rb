#===============================================================================
# Obsidian Shell
# - Reduces Water/Ground damage taken by 25%.
# - After surviving such a hit, raises Defense and Sp. Def by 1.
# - If Deluxe Battle Kit's Splinters effect is available, the attacker receives
#   Rock-type splinters for 3 turns the first time it is not already splintered.
#===============================================================================
module Battle::AbilityEffects
  DamageCalcFromTarget.add(:OBSIDIANSHELL,
    proc { |ability, user, target, move, mults, power, type|
      next if ![:WATER, :GROUND].include?(type)
      mults[:final_damage_multiplier] *= 0.75
    }
  )

  OnBeingHit.add(:OBSIDIANSHELL,
    proc { |ability, user, target, move, battle|
      next if !user || !target || !move || !move.damagingMove?
      next if !user.opposes?(target) || target.damageState.fainted
      move_type = move.respond_to?(:calcType) ? move.calcType : nil
      move_type = move.type if !move_type
      next if ![:WATER, :GROUND].include?(move_type)

      can_def = target.pbCanRaiseStatStage?(:DEFENSE, target)
      can_spd = target.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, target)
      splinters_supported = defined?(PBEffects::Splinters) && defined?(PBEffects::SplintersType)
      add_splinters = splinters_supported && user.effects[PBEffects::Splinters].to_i <= 0
      next if !can_def && !can_spd && !add_splinters

      battle.pbShowAbilitySplash(target)
      if add_splinters
        user.effects[PBEffects::Splinters] = 3
        user.effects[PBEffects::SplintersType] = :ROCK
        battle.pbCommonAnimation("ShellBroken", target) rescue nil
        battle.pbDisplay(_INTL("{1}'s obsidian shell shattered, sending sharp splinters flying!", target.pbThis))
        battle.pbCommonAnimation("Splinters", user) rescue nil
        battle.pbDisplay(_INTL("Jagged obsidian splinters dug into {1}!", user.pbThis(true)))
      elsif can_def || can_spd
        battle.pbDisplay(_INTL("{1}'s obsidian shell hardened further!", target.pbThis))
      end
      battle.pbHideAbilitySplash(target)

      show_anim = true
      if can_def
        changed = target.pbRaiseStatStage(:DEFENSE, 1, target, show_anim)
        show_anim = false if changed
      end
      target.pbRaiseStatStage(:SPECIAL_DEFENSE, 1, target, show_anim) if can_spd
    }
  )
end
