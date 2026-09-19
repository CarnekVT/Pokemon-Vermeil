#===============================================================================
# Battle Scene Studio & DBK Midbattle Dialogues Integration
#===============================================================================
# Este archivo proporciona integración directa, helpers y plantillas para
# diálogos durante el combate (Mid-Battle Dialogues) usando el motor de DBK.
#
# CÓMO USAR EN EVENTOS DE RPG MAKER:
# ----------------------------------
# Antes de iniciar un combate con pbTrainerBattle o pbWildBattle, puedes activar
# cualquier diálogo registrado usando una sola línea:
#
#   setBattleRule("midbattleScript", :BOSS_TRAINER_EXAMPLE)
#   o bien:
#   setMidbattleDialogue(:BOSS_TRAINER_EXAMPLE)
#
# EN BATTLE SCENE STUDIO (BSS):
# -----------------------------
# En el Blueprint o configuración de Boss en JSON/Editor:
#   "boss": {
#     "enabled": true,
#     "aiSkill": 100,
#     "midbattleScript": "BOSS_WILD_EXAMPLE"
#   }
#===============================================================================

# Helper global para asignar diálogos cómodamente en eventos
def setMidbattleDialogue(script_id)
  setBattleRule("midbattleScript", script_id.to_sym)
end

module MidbattleScripts
  #-----------------------------------------------------------------------------
  # Helper para registrar diálogos dinámicamente desde cualquier script
  #-----------------------------------------------------------------------------
  def self.register(id, script_hash)
    const_set(id.to_sym, script_hash)
  end

  #-----------------------------------------------------------------------------
  # PLANTILLA 1: JEFE SALVAJE (Wild Boss / Totem)
  # Diálogos y efectos narrativos para un Pokémon salvaje dominante.
  # Usa texto nativo de batalla sin barras negras cinematográficas.
  #-----------------------------------------------------------------------------
  BOSS_WILD_EXAMPLE = {
    # Al inicio del primer turno de ataque
    "RoundStartAttack_foe" => {
      "text" => "¡El Pokémon dominante emite un rugido ensordecedor que hace temblar el terreno!"
    },
    # Cuando la vida del jefe baja al 50%
    "TargetHPHalf_foe" => {
      "text" => [
        "¡El Pokémon dominante jadea furioso ante la presión del combate!",
        "¡Una intensa aura de furia comienza a emanar de su cuerpo!"
      ]
    },
    # Cuando la vida del jefe baja al 25% (vida crítica)
    "TargetHPLow_foe" => {
      "text" => "¡El Pokémon dominante reúne sus últimas fuerzas para un contraataque desesperado!"
    },
    # Cuando el jefe es derrotado
    "BattlerFainted_foe" => {
      "text" => "¡El Pokémon dominante cae exhausto tras una feroz batalla!"
    }
  }

  #-----------------------------------------------------------------------------
  # PLANTILLA 2: JEFE ENTRENADOR (Líder de Gimnasio / Rival / Boss Trainer)
  # Diálogos cinematográficos con orador, barras negras y retrato.
  # Cierra con endSpeech para restaurar databoxes y barras negras.
  #-----------------------------------------------------------------------------
  BOSS_TRAINER_EXAMPLE = {
    # Inicio del combate (Turno 1, fase de comandos)
    "RoundStartCommand_foe" => {
      "speech" => [
        "¡Espero que estés listo para un combate de verdad!",
        "¡Demuéstrame lo que tú y tus Pokémon son capaces de hacer!"
      ],
      "endSpeech" => true
    },
    # Cuando su Pokémon recibe daño y cae al 50% o menos
    "TargetHPHalf_foe" => {
      "speech" => [
        "¡Nada mal! Tu técnica es más sólida de lo que imaginaba.",
        "¡Pero aún estamos muy lejos del final!"
      ],
      "endSpeech" => true
    },
    # Cuando su Pokémon está en vida crítica (25% o menos)
    "TargetHPLow_foe" => {
      "speech" => [
        "¡Increíble potencia! Nos tienes contra las cuerdas...",
        "¡Aún así, un verdadero entrenador nunca se rinde hasta el último aliento!"
      ],
      "endSpeech" => true
    },
    # Cuando saca a su último Pokémon (su As)
    "BeforeLastSwitchIn_foe" => {
      "speech" => [
        "¡Llegó la hora! ¡Sal a escena, compañero!",
        "¡Mostremos nuestro verdadero poder!"
      ],
      "endSpeech" => true
    },
    # Tras enviar a su último Pokémon
    "AfterLastSendOut_foe" => {
      "speech" => "¡Este combate se decide aquí y ahora!",
      "endSpeech" => true
    },
    # Si el jugador pierde
    "BattleEndLoss" => {
      "speech" => "Buen intento, pero aún te queda un largo camino por recorrer.",
      "endSpeech" => true
    },
    # Si el jugador gana
    "BattleEndWin" => {
      "speech" => "Has peleado con maestría y corazón. Una victoria totalmente merecida.",
      "endSpeech" => true
    }
  }

  #-----------------------------------------------------------------------------
  # PLANTILLA 3: JEFE CON EFECTOS Y DIÁLOGOS COMPLEJOS
  # Muestra cómo encadenar diálogos, cambios de estado y efectos tácticos.
  #-----------------------------------------------------------------------------
  BOSS_TACTICAL_EXAMPLE = {
    "RoundStartAttack_foe" => {
      "speech" => "¡Prepárate! ¡Esta batalla apenas comienza!",
      "endSpeech" => true
    },
    "TargetHPHalf_foe" => {
      "speech" => [
        "¡No creas que nos vencerás tan fácilmente!",
        "¡Observa cómo damos la vuelta a este combate!"
      ],
      "endSpeech" => true
    },
    "TargetHPLow_foe" => {
      "speech" => "¡Jamás cederemos la victoria!",
      "endSpeech" => true
    }
  }
end
