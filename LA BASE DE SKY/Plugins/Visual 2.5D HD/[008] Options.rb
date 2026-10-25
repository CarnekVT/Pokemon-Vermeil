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
  attr_writer :visual25d_model
  attr_writer :visual25d_fov

  # Upgrade only old untouched camera defaults; keep personalized settings.
  # Executed once per saved game, before Core reads its camera parameters.
  def visual25d_upgrade_legacy_profile!
    return if @visual25d_gen5_profile_checked
    @visual25d_gen5_profile_checked = true
    old_tilt = @visual25d_tilt.nil? || @visual25d_tilt.to_f == 27.0
    old_zoom = @visual25d_zoom.nil? || @visual25d_zoom.to_f == 100.0
    old_model = @visual25d_model.nil? || @visual25d_model == :classic
    old_fov = @visual25d_fov.nil? || @visual25d_fov.to_f == 55.0
    # New saves have no settings yet and already use Config defaults.
    previously_used = !@visual25d_tilt.nil? || !@visual25d_model.nil? ||
                      !@visual25d_fov.nil?
    return unless previously_used && old_tilt && old_zoom && old_model && old_fov
    @visual25d_tilt = Visual25D::Config::TILT_DEGREES
    @visual25d_zoom = Visual25D::Config::CAMERA_ZOOM
    @visual25d_model = Visual25D::Config::PROJECTION_MODEL
    @visual25d_fov = Visual25D::Config::CAMERA_FOV
  end

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
end

# Visual 2.5D se configura fuera de Opciones.
# Usar Depuración > Campo > Visual 2.5D HD o pbVisual25DMenu.
