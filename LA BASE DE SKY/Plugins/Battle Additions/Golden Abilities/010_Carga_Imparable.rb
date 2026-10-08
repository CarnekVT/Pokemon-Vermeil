#===============================================================================
# CARGA IMPARABLE - :UNSTOPPABLECHARGE
#-------------------------------------------------------------------------------
# - Los movimientos fisicos del portador hacen x1.5 de dano.
# - Tras ejecutar un movimiento fisico, queda fijado en ese movimiento.
# - Fallar o golpear una inmunidad tambien fija, porque el movimiento se uso.
# - Si nunca llega a ejecutar el movimiento (retroceso, sueno, paralisis total,
#   etc.), no se fija.
# - Los movimientos de estado no activan el bloqueo.
# - El bloqueo termina al abandonar el campo.
#===============================================================================

module GoldenAbilities
  module BattlerState
    attr_accessor :golden_unstoppable_charge_move

    def pbInitEffects(*args)
      # Cambiar de Pokemon/reinicializar el battler elimina el bloqueo.
      @golden_unstoppable_charge_move = nil
      # Si este battler estaba en una Presa Mortal, romper el vinculo antes de
      # que el battler sea reutilizado para otro Pokemon.
      golden_clear_deadly_grip_link if respond_to?(:golden_clear_deadly_grip_link)
      super
      @golden_unstoppable_charge_move = nil
    end
  end
end

Battle::Battler.prepend(GoldenAbilities::BattlerState) unless Battle::Battler.ancestors.include?(GoldenAbilities::BattlerState)

# Multiplicador ofensivo. Se usa final_damage_multiplier para que el efecto sea
# literalmente x1.5 al dano del movimiento fisico, no una subida de stat.
Battle::AbilityEffects::DamageCalcFromUser.add(
  GoldenAbilities::UNSTOPPABLE_CHARGE,
  proc { |ability, user, target, move, mults, power, type|
    next if !move.physicalMove?
    mults[:final_damage_multiplier] *= GoldenAbilities::UNSTOPPABLE_CHARGE_MULTIPLIER
  }
)

# El bloqueo se crea al terminar el uso real del movimiento. Este handler no se
# ejecuta cuando el Pokemon nunca consiguio actuar.
Battle::AbilityEffects::OnEndOfUsingMove.add(
  GoldenAbilities::UNSTOPPABLE_CHARGE,
  proc { |ability, user, targets, move, battle|
    next if user.fainted?
    next if user.golden_unstoppable_charge_move

    # Prioriza el movimiento realmente elegido en la fase de comandos. Esto
    # evita que Metronomo/Sonambulo u otros movimientos que llaman a otro
    # movimiento dejen al usuario fijado en un movimiento que ni siquiera conoce.
    chosen_move = nil
    if battle.choices[user.index] && battle.choices[user.index][0] == :UseMove
      chosen_move = battle.choices[user.index][2]
    end

    lock_move = nil
    if chosen_move && chosen_move.respond_to?(:physicalMove?) && chosen_move.physicalMove?
      lock_move = chosen_move
    elsif move.physicalMove? && user.moves.any? { |m| m.id == move.id }
      # Respaldo para usos fuera de la seleccion normal (p. ej. Instruct).
      lock_move = move
    end
    next if !lock_move

    user.golden_unstoppable_charge_move = lock_move.id
    battle.pbShowAbilitySplash(user)
    battle.pbDisplay(_INTL("¡{1} quedo fijado en {2} por {3}!",
                           user.pbThis, lock_move.name, user.abilityName))
    battle.pbHideAbilitySplash(user)
  }
)

# Impide elegir un movimiento distinto al que quedo fijado.
module GoldenAbilities
  module UnstoppableChargeMoveChoice
    def pbCanChooseMove?(idxBattler, idxMove, showMessages, sleepTalk = false)
      battler = @battlers[idxBattler]
      if battler && !sleepTalk && battler.hasActiveAbility?(GoldenAbilities::UNSTOPPABLE_CHARGE)
        locked_id = battler.golden_unstoppable_charge_move
        move = battler.moves[idxMove]
        if locked_id && move && move.id != locked_id
          if showMessages
            locked_name = GameData::Move.get(locked_id).name
            pbDisplay(_INTL("¡{1} solo puede usar {2} por Carga Imparable!",
                            battler.pbThis, locked_name))
          end
          return false
        end
      end
      return super
    end
  end
end

Battle.prepend(GoldenAbilities::UnstoppableChargeMoveChoice) unless Battle.ancestors.include?(GoldenAbilities::UnstoppableChargeMoveChoice)
