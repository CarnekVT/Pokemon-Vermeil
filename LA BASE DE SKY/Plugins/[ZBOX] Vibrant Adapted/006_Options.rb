# encoding: utf-8
#===============================================================================
# [ZBOX] Vibrant Adapted — Options Menu
#===============================================================================

class PokemonSystem
  attr_writer :vibrant_indoors
  attr_writer :vibrant_wandering
  attr_writer :vibrant_always_animate
  attr_writer :vibrant_interact

  def vibrant_indoors;        return @vibrant_indoors || 1; end
  def vibrant_wandering;      return @vibrant_wandering || 1; end
  def vibrant_always_animate; return @vibrant_always_animate || 0; end
  def vibrant_interact;       return @vibrant_interact || 0; end
end

if Settings::USE_NEW_OPTIONS_UI
  MenuHandlers.add(:options_menu, :va_follower_submenu, {
    "page"        => :gameplay,
    "name"        => _INTL("Vibrant Adapted"),
    "order"       => 20,
    "type"        => :submenu,
    "condition"   => proc { next $player && defined?(VibrantAdapted::Manager) && VibrantAdapted::Manager.toggled? },
    "parameters"  => :vibrant_adapted_page,
    "description" => _INTL("Configura el sistema de Pokémon acompañante.")
  })

  MenuHandlers.add(:options_menu, :va_indoors, {
    "page"        => :vibrant_adapted_page,
    "name"        => _INTL("En Interiores"),
    "order"       => 10,
    "type"        => :toggle,
    "condition"   => proc { next true },
    "parameters"  => proc { [_INTL("Sí"), _INTL("No")] },
    "default_value" => 1,
    "description" => _INTL("Elige si el Pokémon te seguirá dentro de casas y cuevas."),
    "get_proc"    => proc { next $PokemonSystem.vibrant_indoors || 1 },
    "set_proc"    => proc { |value, _screen|
      $PokemonSystem.vibrant_indoors = value
      VibrantAdapted::Manager.refresh
    }
  })

  MenuHandlers.add(:options_menu, :va_wandering, {
    "page"        => :vibrant_adapted_page,
    "name"        => _INTL("Deambular"),
    "order"       => 20,
    "type"        => :toggle,
    "condition"   => proc { next true },
    "parameters"  => proc { [_INTL("Sí"), _INTL("No")] },
    "default_value" => 1,
    "description" => _INTL("Elige si el Pokémon caminará a tu alrededor al quedarte quieto."),
    "get_proc"    => proc { next $PokemonSystem.vibrant_wandering || 1 },
    "set_proc"    => proc { |value, _screen| $PokemonSystem.vibrant_wandering = value }
  })

  MenuHandlers.add(:options_menu, :va_always_animate, {
    "page"        => :vibrant_adapted_page,
    "name"        => _INTL("Anim. Constante"),
    "order"       => 30,
    "type"        => :toggle,
    "condition"   => proc { next true },
    "parameters"  => proc { [_INTL("Sí"), _INTL("No")] },
    "default_value" => 0,
    "description" => _INTL("Elige si el Pokémon moverá sus patas incluso cuando esté quieto."),
    "get_proc"    => proc { next $PokemonSystem.vibrant_always_animate || 0 },
    "set_proc"    => proc { |value, _screen|
      $PokemonSystem.vibrant_always_animate = value
      VibrantAdapted::Manager.refresh
    }
  })

  MenuHandlers.add(:options_menu, :va_interact, {
    "page"        => :vibrant_adapted_page,
    "name"        => _INTL("Interactuar"),
    "order"       => 40,
    "type"        => :toggle,
    "condition"   => proc { next true },
    "parameters"  => proc { [_INTL("Sí"), _INTL("No")] },
    "default_value" => 0,
    "description" => _INTL("Elige si se puede interactuar con el Pokémon que te sigue."),
    "get_proc"    => proc { next $PokemonSystem.vibrant_interact || 0 },
    "set_proc"    => proc { |value, _screen|
      $PokemonSystem.vibrant_interact = value
      VibrantAdapted::Manager.refresh
    }
  })
end
