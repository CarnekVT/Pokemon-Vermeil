#===============================================================================
# Visual 2.5D HD - Datos guardados
#-------------------------------------------------------------------------------
# El angulo de la camara y la distancia de dibujado viven en la partida, para que
# cada jugador se ajuste el mapa a su gusto y se le respete al cargar. Se editan
# con  pbVisual25DMenu .
#===============================================================================
class PokemonSystem
  attr_writer :visual25d_enabled
  attr_writer :visual25d_tilt
  attr_writer :visual25d_zoom
  attr_writer :visual25d_round

  def visual25d_enabled
    @visual25d_enabled = Visual25D::Config::ENABLED if @visual25d_enabled.nil?
    return @visual25d_enabled
  end

  def visual25d_tilt
    @visual25d_tilt = Visual25D::Config::TILT_DEGREES if @visual25d_tilt.nil?
    return @visual25d_tilt
  end

  def visual25d_zoom
    @visual25d_zoom = Visual25D::Config::CAMERA_ZOOM if @visual25d_zoom.nil?
    return @visual25d_zoom
  end

  # true = redondo (el terreno de ahora). false = plano.
  def visual25d_round
    @visual25d_round = true if @visual25d_round.nil?
    return @visual25d_round
  end
end

MenuHandlers.add(:options_menu, :visual25d_enabled, {
  "page"        => :graphics,
  "name"        => _INTL("Modo 2.5D"),
  "order"       => 100,
  "type"        => :toggle,
  "parameters"  => proc { [_INTL("Sí"), _INTL("No")] },
  "description" => _INTL("Activa o desactiva el modo visual 2.5D."),
  "get_proc"    => proc {
    enabled = if $PokemonSystem&.respond_to?(:visual25d_enabled)
                $PokemonSystem.visual25d_enabled
              else
                Visual25D.enabled
              end
    next enabled ? 0 : 1
  },
  "set_proc"    => proc { |value, _screen|
    enabled = (value == 0)
    # Sin mark_save_sync_dirty: el sync del frame siguiente cancelaria el fundido.
    $PokemonSystem.visual25d_enabled = enabled if $PokemonSystem&.respond_to?(:visual25d_enabled=)
    pbVisual25DSetSmooth(enabled)
  }
})

MenuHandlers.add(:options_menu, :visual25d_world, {
  "page"        => :graphics,
  "name"        => _INTL("Mundo 2.5D"),
  "order"       => 101,
  "type"        => :array,
  "parameters"  => proc { [_INTL("Redondo"), _INTL("Plano")] },
  "description" => _INTL("Elige si el terreno se curva en el horizonte o se queda plano."),
  "get_proc"    => proc {
    round = if $PokemonSystem&.respond_to?(:visual25d_round)
              $PokemonSystem.visual25d_round
            else
              Visual25D.horizon_curve_px > 0.5
            end
    next round ? 0 : 1
  },
  "set_proc"    => proc { |value, _screen|
    round = (value == 0)
    $PokemonSystem.visual25d_round = round if $PokemonSystem&.respond_to?(:visual25d_round=)
    Visual25D.horizon_curve = round ? Visual25D::Config::HORIZON_CURVE : 0
  }
})