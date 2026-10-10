#===============================================================================
# MinimalGrinding - Toggle para ignorar IVs/EVs en tiempo de ejecución
# Usa MinimalGrinding.on / MinimalGrinding.off / MinimalGrinding.toggle
#===============================================================================
class PokemonGlobalMetadata
  attr_accessor :minimal_griding
end

module MinimalGrinding
  module_function

  def on?
    $PokemonGlobal&.minimal_grinding ? true : false
  end

  def on
    $PokemonGlobal.minimal_grinding = true
  end

  def off
    $PokemonGlobal.minimal_grinding = false
  end

  def toggle
    $PokemonGlobal.minimal_grinding = !$PokemonGlobal.minimal_grinding
  end
end
