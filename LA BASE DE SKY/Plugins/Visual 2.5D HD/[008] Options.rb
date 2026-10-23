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
  attr_writer :visual25d_model
  attr_writer :visual25d_fov

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

  def visual25d_model
    @visual25d_model = Visual25D::Config::PROJECTION_MODEL if @visual25d_model.nil?
    return @visual25d_model
  end

  def visual25d_fov
    @visual25d_fov = Visual25D::Config::CAMERA_FOV if @visual25d_fov.nil?
    return @visual25d_fov
  end

  # Horizonte plano por defecto, con curvatura opcional.
  def visual25d_round
    @visual25d_round = false if @visual25d_round.nil?
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

# Controles directos para el testeo. Se pueden modificar desde
# Opciones -> Graficos sin activar el menu de depuracion.
module Visual25DCameraOptions
  TILTS = [0, 15, 20, 25, 27, 30, 35, 40, 45, 50]
  ZOOMS = [75, 85, 90, 100, 110, 120, 135]
  FOVS  = [35, 45, 55, 65, 75, 85]

  def self.nearest(values, value)
    values.each_index.min_by { |i| (values[i] - value.to_f).abs } || 0
  end
end

MenuHandlers.add(:options_menu, :visual25d_angle, {
  "page" => :graphics,
  "name" => _INTL("2.5D: Inclinacion"),
  "order" => 102,
  "type" => :array,
  "parameters" => proc { Visual25DCameraOptions::TILTS.map { |v| _INTL("{1} grados", v) } },
  "description" => _INTL("Angulo de perspectiva. Valores bajos son mas ligeros."),
  "get_proc" => proc { next Visual25DCameraOptions.nearest(Visual25DCameraOptions::TILTS, Visual25D.tilt) },
  "set_proc" => proc { |value, _screen| Visual25D.tilt = Visual25DCameraOptions::TILTS[value] }
})

MenuHandlers.add(:options_menu, :visual25d_distance, {
  "page" => :graphics,
  "name" => _INTL("2.5D: Zoom"),
  "order" => 103,
  "type" => :array,
  "parameters" => proc { Visual25DCameraOptions::ZOOMS.map { |v| _INTL("{1}%", v) } },
  "description" => _INTL("A menos zoom, mas tiles visibles y mayor coste."),
  "get_proc" => proc { next Visual25DCameraOptions.nearest(Visual25DCameraOptions::ZOOMS, Visual25D.camera_zoom) },
  "set_proc" => proc { |value, _screen| Visual25D.camera_zoom = Visual25DCameraOptions::ZOOMS[value] }
})

MenuHandlers.add(:options_menu, :visual25d_model, {
  "page" => :graphics,
  "name" => _INTL("2.5D: Proyeccion"),
  "order" => 104,
  "type" => :array,
  "parameters" => proc { [_INTL("Clasica (estable)"), _INTL("Camara (experimental)")] },
  "description" => _INTL("El modelo clasico es el recomendado para el testeo."),
  "get_proc" => proc { next Visual25D.projection_model == :camera ? 1 : 0 },
  "set_proc" => proc { |value, _screen| Visual25D.projection_model = (value == 1 ? :camera : :classic) }
})

MenuHandlers.add(:options_menu, :visual25d_fov, {
  "page" => :graphics,
  "name" => _INTL("2.5D: Campo de vision"),
  "order" => 105,
  "type" => :array,
  "parameters" => proc { Visual25DCameraOptions::FOVS.map { |v| _INTL("{1} grados", v) } },
  "description" => _INTL("FOV del modelo Camara. No tiene efecto en el clasico."),
  "get_proc" => proc { next Visual25DCameraOptions.nearest(Visual25DCameraOptions::FOVS, Visual25D.camera_fov) },
  "set_proc" => proc { |value, _screen| Visual25D.camera_fov = Visual25DCameraOptions::FOVS[value] }
})
