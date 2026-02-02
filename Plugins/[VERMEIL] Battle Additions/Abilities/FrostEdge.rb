#===============================================================================
# Frost Edge - Habilidad personalizada
#===============================================================================

module Battle::AbilityEffects
  #=============================================================================
  # Aumentar la velocidad en un 20% durante granizo/nieve
  #=============================================================================
  SpeedCalc.add(:FROSTEDGE,
    proc { |ability, battler, mult, ret|
      # Aumentar velocidad en 20% durante granizo o nieve
      next mult * 1.2 if [:Hail, :Snow].include?(battler.effectiveWeather)
    }
  )
  
  #=============================================================================
  # Movimientos de corte o contacto tienen 20% de probabilidad de congelar al rival si tiene estadísticas bajadas
  #=============================================================================
  OnDealingHit.add(:FROSTEDGE,
    proc { |ability, user, target, move, battle|
      next if !move.damagingMove?
      next if !((move.slicingMove?) || (move.contactMove?))
      next if target.fainted?
      
      # Comprobar si el objetivo tiene al menos una estadística bajada
      has_lowered_stats = false
      GameData::Stat.each_battle do |stat|
        if target.stages[stat.id] < 0
          has_lowered_stats = true
          break
        end
      end
      
      next unless has_lowered_stats
      
      # 20% de probabilidad de congelar
      if battle.pbRandom(100) < 20
        battle.pbShowAbilitySplash(user)
        if target.pbCanFreeze?(user, Battle::Scene::USE_ABILITY_SPLASH)
          msg = nil
          if !Battle::Scene::USE_ABILITY_SPLASH
            msg = _INTL("{1}'s {2} froze {3}!", user.pbThis, user.abilityName, target.pbThis(true))
          end
          target.pbFreeze(msg)
        end
        battle.pbHideAbilitySplash(user)
      end
    }
  )
end