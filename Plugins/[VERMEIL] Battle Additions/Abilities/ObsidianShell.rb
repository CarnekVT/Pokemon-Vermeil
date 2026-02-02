#===============================================================================
# Obsidian Shell - Habilidad personalizada
#===============================================================================

module Battle::AbilityEffects
  #=============================================================================
  # Reducir daño de movimientos Water y Ground en un 75%
  #=============================================================================
  DamageCalcFromTarget.add(:OBSIDIANSHELL,
    proc { |ability, user, target, move, mults, power, type|
      next unless [:WATER, :GROUND].include?(type.upcase)
      mults[:final_damage_multiplier] *= 0.75  # Reducción del 75%
      PBDebug.log("[Obsidian Shell] Redujo el daño del movimiento #{move.name} (tipo #{type}) en un 75%")
    }
  )
  
  #=============================================================================
  # Al ser golpeado, dejar splinters de obsidiana (efecto de Splinters)
  #=============================================================================
  OnBeingHit.add(:OBSIDIANSHELL,
    proc { |ability, user, target, move, battle|
      PBDebug.log("[Obsidian Shell] OnBeingHit - Movimiento: #{move ? move.name : 'nil'}, Tipo: #{move ? move.type : 'nil'}")
      
      # Aplicar el efecto de obsidian splinters solo si el movimiento es de tipo Water o Ground, el objetivo no se va a debilitar y las splinters no están activas
      if move && [:WATER, :GROUND].include?(move.calcType) && user.opposes?(target) && !target.damageState.fainted && user.effects[PBEffects::Splinters] == 0
        # Establecer el efecto de Splinters en el usuario del movimiento (oponente)
        user.effects[PBEffects::Splinters] = 3  # Duración de 3 turnos
        user.effects[PBEffects::SplintersType] = :ROCK  # Tipo Rock para el daño de splinters
        
        PBDebug.log("[Obsidian Shell] Aplicó obsidian splinters, duración: #{user.effects[PBEffects::Splinters]} turnos, tipo: #{user.effects[PBEffects::SplintersType]}")
        
        # Mostrar mensaje de la habilidad y animación
        battle.pbShowAbilitySplash(target)
        battle.pbCommonAnimation("ShellBroken", target)
        battle.pbDisplay(_INTL("{1}'s obsidian shell shattered, sending sharp splinters flying!", target.pbThis))
        battle.pbCommonAnimation("Splinters", user)
        battle.pbDisplay(_INTL("Jagged obsidian splinters dug into {1}!", user.pbThis(true)))
        battle.pbHideAbilitySplash(target)
        
        # Aumentar Defense y Special Defense solo si no están en su máximo
        if target.pbCanRaiseStatStage?(:DEFENSE, target)
          target.pbRaiseStatStage(:DEFENSE, 1, target)
        end
        if target.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, target)
          target.pbRaiseStatStage(:SPECIAL_DEFENSE, 1, target)
        end
        PBDebug.log("[Obsidian Shell] Boost de DEFENSE y SPECIAL_DEFENSE en #{target.pbThis}")
      elsif move && [:WATER, :GROUND].include?(move.calcType) && user.opposes?(target) && !target.damageState.fainted && user.effects[PBEffects::Splinters] > 0
        # Si las splinters ya están activas, solo se endurece la coraza si las defensas no están al máximo
        if target.pbCanRaiseStatStage?(:DEFENSE, target) || target.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, target)
          battle.pbShowAbilitySplash(target)
          battle.pbDisplay(_INTL("{1}'s obsidian shell hardened further!", target.pbThis))
          battle.pbHideAbilitySplash(target)
          
          # Aumentar Defense y Special Defense solo si no están en su máximo
          if target.pbCanRaiseStatStage?(:DEFENSE, target)
            target.pbRaiseStatStage(:DEFENSE, 1, target)
          end
          if target.pbCanRaiseStatStage?(:SPECIAL_DEFENSE, target)
            target.pbRaiseStatStage(:SPECIAL_DEFENSE, 1, target)
          end
          PBDebug.log("[Obsidian Shell] Boost de DEFENSE y SPECIAL_DEFENSE en #{target.pbThis}")
        end
      end
    }
  )
end
