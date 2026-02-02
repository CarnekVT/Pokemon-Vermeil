#===============================================================================
# Burning Rampage - Habilidad personalizada
#===============================================================================

module Battle::AbilityEffects
   #=============================================================================
   # Inmunidad a congelación
   #=============================================================================
   StatusImmunity.add(:BURNINGRAMPAGE,
     proc { |ability, battler, status|
       PBDebug.log("[Burning Rampage] StatusImmunity triggered - Status: #{status}, Battler: #{battler.pbThis}")
       next true if status == :FROZEN
     }
   )
  
   #=============================================================================
   # Al ser golpeado, aumenta el poder de los movimientos de tipo Fuego en un 10% (máximo 50%)
   #=============================================================================
   OnBeingHit.add(:BURNINGRAMPAGE,
     proc { |ability, user, target, move, battle|
       PBDebug.log("[Burning Rampage] OnBeingHit - Movimiento: #{move ? move.name : 'nil'}, Tipo: #{move ? move.type : 'nil'}")
       PBDebug.log("[Burning Rampage] Current stacks: #{target.effects[PBEffects::BurningRampage] || 0}")
       PBDebug.log("[Burning Rampage] Move is damaging: #{move && move.damagingMove?}")
       PBDebug.log("[Burning Rampage] Target fainted: #{target.damageState.fainted}")
       
       # Aumentar el contador de Burning Rampage solo si el movimiento es dañino y el objetivo no se va a debilitar
       current_stacks = target.effects[PBEffects::BurningRampage] || 0
       if move && move.damagingMove? && !target.damageState.fainted && current_stacks < 5
         target.effects[PBEffects::BurningRampage] = current_stacks + 1
         PBDebug.log("[Burning Rampage] Aumentado a #{target.effects[PBEffects::BurningRampage]} stacks")
         
         # Mostrar mensaje de la habilidad
         battle.pbShowAbilitySplash(target)
         battle.pbDisplay(_INTL("{1}'s Burning Rampage intensifies!", target.pbThis))
         battle.pbHideAbilitySplash(target)
       end
     }
   )
  
   #=============================================================================
   # Aumentar el poder de los movimientos de tipo Fuego según el número de stacks
   #=============================================================================
   DamageCalcFromUser.add(:BURNINGRAMPAGE,
     proc { |ability, user, target, move, mults, baseDmg, type|
       PBDebug.log("[Burning Rampage] DamageCalcFromUser triggered - Type: #{type}, Move: #{move.name}")
       PBDebug.log("[Burning Rampage] Stacks: #{user.effects[PBEffects::BurningRampage] || 0}")
       PBDebug.log("[Burning Rampage] Ability active: #{user.hasActiveAbility?(:BURNINGRAMPAGE)}")
       
       next unless type == :FIRE
       
       stacks = user.effects[PBEffects::BurningRampage] || 0
       bonus = 1.0 + (stacks * 0.10)  # 10% por stack, máximo 1.5 (5 stacks)
       bonus = [bonus, 1.5].min  # Limitar a 50% de aumento
       
       mults[:power_multiplier] *= bonus
       PBDebug.log("[Burning Rampage] Aplicado bonus de #{(bonus - 1) * 100}% al movimiento #{move.name} (tipo #{type})")
       PBDebug.log("[Burning Rampage] Power multiplier: #{mults[:power_multiplier]}")
     }
   )
  
  #=============================================================================
  # Mantener el contador al cambiar de Pokémon (guardo en el Pokémon, no en el battler)
  #=============================================================================
  OnSwitchOut.add(:BURNINGRAMPAGE,
    proc { |ability, battler, endOfBattle|
      PBDebug.log("[Burning Rampage] OnSwitchOut - Contador actual: #{battler.effects[PBEffects::BurningRampage]}")
      # Si el Pokémon se debilita o el combate termina, reiniciar el contador;
      # en un cambio normal, guardar el contador en el Pokémon.
      if endOfBattle || battler.fainted?
        PBDebug.log("[Burning Rampage] Clearing stacks due to faint or end of battle")
        battler.effects[PBEffects::BurningRampage] = 0
        battler.pokemon.burning_rampage_stacks = 0
      else
        battler.pokemon.burning_rampage_stacks = battler.effects[PBEffects::BurningRampage]
      end
    }
  )
  
  OnSwitchIn.add(:BURNINGRAMPAGE,
    proc { |ability, battler, battle, switch_in|
      PBDebug.log("[Burning Rampage] OnSwitchIn - Pokémon tiene #{battler.pokemon.burning_rampage_stacks} stacks guardados")
      # Recuperar el contador del Pokémon
      battler.effects[PBEffects::BurningRampage] = battler.pokemon.burning_rampage_stacks || 0
    }
  )
end

#===============================================================================
# Extender la clase Pokemon para guardar el contador de Burning Rampage
#===============================================================================
class Pokemon
  attr_accessor :burning_rampage_stacks
  
  def burning_rampage_stacks
    @burning_rampage_stacks ||= 0
  end
end

