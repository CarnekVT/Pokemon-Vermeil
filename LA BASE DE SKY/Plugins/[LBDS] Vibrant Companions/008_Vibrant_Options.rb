#===============================================================================
# VIBRANT COMPANIONS - MODULE 8: OPTIONS MENU
# Integración con el menú de opciones nativo de Essentials
#===============================================================================

# Inyectar variables en PokemonSystem para que se guarden
class PokemonSystem
  attr_writer :vibrant_caterpillar
  attr_writer :vibrant_max_followers
  attr_writer :vibrant_indoors
  attr_writer :vibrant_wandering
  attr_writer :vibrant_always_animate
  attr_writer :vibrant_items
  attr_writer :vibrant_interact

  # Si la variable es nil (partida antigua), devuelven el valor por defecto
  def vibrant_caterpillar;    return @vibrant_caterpillar || 0; end
  def vibrant_max_followers;  return @vibrant_max_followers || 5; end
  def vibrant_indoors;        return @vibrant_indoors || 0; end
  def vibrant_wandering;      return @vibrant_wandering || 0; end
  def vibrant_always_animate; return @vibrant_always_animate || 0; end
  def vibrant_items;          return @vibrant_items || 0; end
  def vibrant_interact
    @vibrant_interact ||= VibrantCompanions::Settings::ALLOW_INTERACT ? 0 : 1 
    @vibrant_interact
  end
end

if Settings::USE_NEW_OPTIONS_UI
  # Opción que actúa como puerta al submenú
  MenuHandlers.add(:options_menu, :vibrant_follower_submenu, {
    "page"        => :gameplay,
    "name"        => _INTL("Vibrant Follower"),
    "order"       => 20, 
    "type"        => :submenu,
    "condition"   => proc { next $player && defined?(VibrantCompanions::Manager) && VibrantCompanions::Manager.toggled? },
    "parameters"  => :vibrant_companions_page, 
    "description" => _INTL("Configura el sistema de Pokémon acompañantes.")
  })

  # Opción: Modo Tren
  MenuHandlers.add(:options_menu, :vibrant_caterpillar, {
    "page"        => :vibrant_companions_page,
    "name"        => _INTL("Modo Tren"),
    "order"       => 10,
    "type"        => :toggle,
    "condition"   => proc { next VibrantCompanions::Settings::ALLOW_CATERPILLAR_MODE }, # <-- CONDICIÓN
    "parameters"  => proc { [_INTL("Sí"), _INTL("No")] },
    "default_value" => 0,
    "description" => _INTL("Elige si quieres que te siga todo el equipo o solo el primer Pokémon."),
    "get_proc"    => proc { next $PokemonSystem.vibrant_caterpillar || 0 },
    "set_proc"    => proc { |value, _screen| 
      $PokemonSystem.vibrant_caterpillar = value 
      VibrantCompanions::Manager.refresh if defined?(VibrantCompanions)
    }
  })

  # Opción: Máx. Seguidores
  MenuHandlers.add(:options_menu, :vibrant_max_followers, {
    "page"        => :vibrant_companions_page,
    "name"        => _INTL("Máx. Seguidores"),
    "order"       => 20,
    "type"        => :number_type,
    "condition"   => proc { next VibrantCompanions::Settings::ALLOW_CATERPILLAR_MODE }, # <-- CONDICIÓN
    "parameters"  => 1..6,
    "default_value" => 5,
    "description" => _INTL("Elige cuántos Pokémon te seguirán como máximo en el Modo Tren."),
    "disabled_proc"=> proc { next ($PokemonSystem.vibrant_caterpillar || 0) != 0 }, 
    "get_proc"    => proc { next $PokemonSystem.vibrant_max_followers || 5 },
    "set_proc"    => proc { |value, _screen| 
      $PokemonSystem.vibrant_max_followers = value 
      VibrantCompanions::Manager.refresh if defined?(VibrantCompanions)
    }
  })

  # Opción: En Interiores
  MenuHandlers.add(:options_menu, :vibrant_indoors, {
    "page"        => :vibrant_companions_page,
    "name"        => _INTL("En Interiores"),
    "order"       => 30,
    "type"        => :toggle,
    "condition"   => proc { next VibrantCompanions::Settings::ALLOW_INDOORS }, # <-- CONDICIÓN
    "parameters"  => proc { [_INTL("Sí"), _INTL("No")] },
    "default_value" => 0,
    "description" => _INTL("Elige si los Pokémon te seguirán dentro de casas y cuevas."),
    "get_proc"    => proc { next $PokemonSystem.vibrant_indoors || 0 },
    "set_proc"    => proc { |value, _screen| 
      $PokemonSystem.vibrant_indoors = value 
      VibrantCompanions::Manager.refresh
    }
  })

  # Opción: Deambular
  MenuHandlers.add(:options_menu, :vibrant_wandering, {
    "page"        => :vibrant_companions_page,
    "name"        => _INTL("Deambular"),
    "order"       => 40,
    "type"        => :toggle,
    "condition"   => proc { next VibrantCompanions::Settings::ALLOW_WANDERING }, # <-- CONDICIÓN
    "parameters"  => proc { [_INTL("Sí"), _INTL("No")] },
    "default_value" => 1,
    "description" => _INTL("Elige si el Pokémon líder caminará a tu alrededor al quedarte quieto."),
    "get_proc"    => proc { next $PokemonSystem.vibrant_wandering || 0 },
    "set_proc"    => proc { |value, _screen| $PokemonSystem.vibrant_wandering = value }
  })

  # Opción: Animación Constante
  MenuHandlers.add(:options_menu, :vibrant_always_animate, {
    "page"        => :vibrant_companions_page,
    "name"        => _INTL("Anim. Constante"),
    "order"       => 50,
    "type"        => :toggle,
    "condition"   => proc { next VibrantCompanions::Settings::ALLOW_ALWAYS_ANIMATE }, # <-- CONDICIÓN
    "parameters"  => proc { [_INTL("Sí"), _INTL("No")] },
    "default_value" => 0,
    "description" => _INTL("Elige si los Pokémon moverán sus patas incluso cuando estén quietos."),
    "get_proc"    => proc { next $PokemonSystem.vibrant_always_animate || 0 },
    "set_proc"    => proc { |value, _screen| 
      $PokemonSystem.vibrant_always_animate = value 
      VibrantCompanions::Manager.refresh
    }
  })

  # Opción: Interactuar
  MenuHandlers.add(:options_menu, :vibrant_always_animate, {
    "page"        => :vibrant_companions_page,
    "name"        => _INTL("Interactuar"),
    "order"       => 50,
    "type"        => :toggle,
    "condition"   => proc { next VibrantCompanions::Settings::ALLOW_DISABLE_TALK_TO_FOLLOWER }, # <-- CONDICIÓN
    "parameters"  => proc { [_INTL("Sí"), _INTL("No")] },
    "default_value" => 0,
    "description" => _INTL("Elige si se puede interactuar con el Pokémon que te sigue."),
    "get_proc"    => proc { next $PokemonSystem.vibrant_interact },
    "set_proc"    => proc { |value, _screen| 
      $PokemonSystem.vibrant_interact = value 
      VibrantCompanions::Manager.refresh
    }
  })
end