#===============================================================================
# [VERMEIL] Visual 2.5D - 008_Options.rb
# Opcion del jugador para activar/desactivar la camara 2.5D desde el menu de
# Opciones. Solo se muestra si Config::PLAYER_SWITCH apunta a un switch libre.
#===============================================================================
if defined?(MenuHandlers) && Mode7::Config::PLAYER_SWITCH > 0
  sw = Mode7::Config::PLAYER_SWITCH

  MenuHandlers.add(:options_menu, :mode7_toggle_player, {
    "name"        => _INTL("Camara 2.5D"),
    "page"        => :plugins,
    "order"       => 10,
    "type"        => :array,
    "parameters"  => proc { [_INTL("Activada"), _INTL("Desactivada")] },
    "description" => _INTL("Activa o desactiva la camara en perspectiva 2.5D de los mapas."),
    "condition"   => proc { $game_switches && $game_switches[sw] },
    "get_proc"    => proc { next ($game_switches[sw] ? 0 : 1) },
    "set_proc"    => proc { |value, _screen|
      next if value == ($game_switches[sw] ? 0 : 1)
      $game_switches[sw] = (value == 0)
    }
  })
end