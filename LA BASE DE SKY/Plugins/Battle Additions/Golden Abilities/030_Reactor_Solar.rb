#===============================================================================
# REACTOR SOLAR - :SOLARREACTOR
#-------------------------------------------------------------------------------
# - Los movimientos de tipo Fuego y Electrico hacen x1.4 de dano.
# - Tras usar un movimiento Fuego/Electrico, ese tipo queda bloqueado SOLO
#   durante el siguiente turno del usuario.
# - Puede usar el otro STAB, cobertura, movimientos de estado de otro tipo o
#   cambiar de Pokemon.
# - Si durante el turno bloqueado no usa un nuevo movimiento Fuego/Electrico,
#   la restriccion expira al pasar ese turno.
# - Si usa el otro tipo durante el turno bloqueado, ese nuevo tipo queda
#   bloqueado para el turno posterior. Ejemplo:
#       T1 Fuego -> T2 no Fuego
#       T2 Electrico -> T3 no Electrico (Fuego vuelve a estar disponible)
# - El bloqueo se elimina al abandonar el campo.
# - No causa dano/recoil adicional; el coste es exclusivamente tactico.
#===============================================================================

module GoldenAbilities
  module SolarReactorBattlerState
    attr_accessor :golden_solar_reactor_blocked_type
    attr_accessor :golden_solar_reactor_blocked_turn

    def pbInitEffects(*args)
      @golden_solar_reactor_blocked_type = nil
      @golden_solar_reactor_blocked_turn = nil
      super
      @golden_solar_reactor_blocked_type = nil
      @golden_solar_reactor_blocked_turn = nil
    end

    # Devuelve el tipo que Reactor Solar impide seleccionar en la ronda actual.
    # La informacion se invalida automaticamente una vez pasada esa ronda.
    def golden_solar_reactor_locked_type
      return nil if !@golden_solar_reactor_blocked_type
      return nil if !@golden_solar_reactor_blocked_turn
      current_turn = @battle.turnCount
      if current_turn > @golden_solar_reactor_blocked_turn
        @golden_solar_reactor_blocked_type = nil
        @golden_solar_reactor_blocked_turn = nil
        return nil
      end
      return nil if current_turn < @golden_solar_reactor_blocked_turn
      return @golden_solar_reactor_blocked_type
    end

    def golden_solar_reactor_set_cooldown(type)
      return if ![:FIRE, :ELECTRIC].include?(type)
      @golden_solar_reactor_blocked_type = type
      @golden_solar_reactor_blocked_turn = @battle.turnCount + 1
    end
  end
end

Battle::Battler.prepend(GoldenAbilities::SolarReactorBattlerState) unless Battle::Battler.ancestors.include?(GoldenAbilities::SolarReactorBattlerState)

#-------------------------------------------------------------------------------
# Potenciacion ofensiva: x1.4 final para Fuego/Electrico.
# Se usa el tipo ya calculado por el motor, por lo que respeta cambios de tipo
# del movimiento que hayan ocurrido antes del calculo de dano.
#-------------------------------------------------------------------------------
Battle::AbilityEffects::DamageCalcFromUser.add(
  GoldenAbilities::SOLAR_REACTOR,
  proc { |ability, user, target, move, mults, power, type|
    next if ![:FIRE, :ELECTRIC].include?(type)
    mults[:final_damage_multiplier] *= GoldenAbilities::SOLAR_REACTOR_MULTIPLIER
  }
)

#-------------------------------------------------------------------------------
# Al terminar de USAR realmente un movimiento Fuego/Electrico, prepara el
# bloqueo de ese tipo para la ronda siguiente. Fallar o golpear una inmunidad
# cuenta porque el movimiento si se utilizo. Si el Pokemon nunca actuo, este
# handler no llega a crear el cooldown.
#-------------------------------------------------------------------------------
Battle::AbilityEffects::OnEndOfUsingMove.add(
  GoldenAbilities::SOLAR_REACTOR,
  proc { |ability, user, targets, move, battle|
    next if user.fainted?

    used_type = nil
    if move.respond_to?(:pbCalcType)
      used_type = move.pbCalcType(user)
    elsif move.respond_to?(:type)
      used_type = move.type
    end
    next if ![:FIRE, :ELECTRIC].include?(used_type)

    user.golden_solar_reactor_set_cooldown(used_type)
  }
)

#-------------------------------------------------------------------------------
# Impide seleccionar, durante la ronda bloqueada, cualquier movimiento cuyo
# tipo ACTUAL coincida con el tipo sobrecalentado.
#-------------------------------------------------------------------------------
module GoldenAbilities
  module SolarReactorMoveChoice
    def pbCanChooseMove?(idxBattler, move_or_index, showMessages, sleepTalk = false, *extra, &block)
      battler = @battlers[idxBattler]
      if battler && !sleepTalk
        locked_type = battler.golden_solar_reactor_locked_type
        # Essentials vanilla may pass a move-slot index, while DBK's command/AI
        # flow can pass the Battle::Move instance itself.  Never index the move
        # array with a Battle::Move object.
        move = if move_or_index.is_a?(Integer)
                 battler.moves[move_or_index]
               elsif move_or_index.respond_to?(:id)
                 move_or_index
               else
                 nil
               end
        if locked_type && move
          move_type = if move.respond_to?(:pbCalcType)
                        move.pbCalcType(battler)
                      elsif move.respond_to?(:type)
                        move.type
                      end
          if move_type == locked_type
            if showMessages
              type_name = GameData::Type.get(locked_type).name
              pbDisplay(_INTL("¡El reactor de {1} aun no puede estabilizar la energia de tipo {2}!",
                              battler.pbThis, type_name))
            end
            return false
          end
        end
      end
      return super
    end
  end
end

Battle.prepend(GoldenAbilities::SolarReactorMoveChoice) unless Battle.ancestors.include?(GoldenAbilities::SolarReactorMoveChoice)
