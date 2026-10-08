#===============================================================================
# Battle Additions - Golden Abilities
# abilities_balance_goldenforms
# Configuracion y registro de datos
# Pokemon Essentials v21.1
#===============================================================================

module GoldenAbilities
  UNSTOPPABLE_CHARGE = :UNSTOPPABLECHARGE
  DEADLY_GRIP        = :DEADLYGRIP
  SOLAR_REACTOR      = :SOLARREACTOR

  UNSTOPPABLE_CHARGE_MULTIPLIER = 1.5
  DEADLY_GRIP_MULTIPLIER        = 1.3
  SOLAR_REACTOR_MULTIPLIER      = 1.4

  # Registro de respaldo para que las habilidades existan incluso antes de
  # integrarlas al PBS. Para una instalacion permanente y recompilable, copia
  # tambien las entradas incluidas en PBS/abilities_balance_goldenforms.txt
  # a PBS/abilities.txt (o al PBS modular equivalente de tu proyecto).
  def self.register_ability_if_missing(id, name, description)
    return if !defined?(GameData::Ability)
    return if GameData::Ability.exists?(id)
    GameData::Ability.register({
      :id          => id,
      :name        => name,
      :description => description
    })
  end
end

GoldenAbilities.register_ability_if_missing(
  GoldenAbilities::UNSTOPPABLE_CHARGE,
  "Carga Imparable",
  "Potencia un 50 % sus movimientos fisicos, pero al usar uno queda fijado en ese movimiento hasta abandonar el combate."
)

GoldenAbilities.register_ability_if_missing(
  GoldenAbilities::DEADLY_GRIP,
  "Presa Mortal",
  "Al recibir contacto, impide que ambos Pokemon escapen. Sus ataques contra la presa infligen un 30 % mas de dano."
)

GoldenAbilities.register_ability_if_missing(
  GoldenAbilities::SOLAR_REACTOR,
  "Reactor Solar",
  "Potencia un 40 % los movimientos de tipo Fuego y Electrico, pero no puede repetir ese mismo tipo en el turno siguiente."
)
