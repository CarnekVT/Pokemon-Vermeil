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

  # El modo viejo :classic/:camera sigue deformando el mapa si el save
  # conserva el modelo anterior. Se cambia SOLO el modelo, no los ajustes
  # personales de inclinacion, zoom ni FOV.
  def visual25d_upgrade_legacy_profile!
    # Para un ajuste guardado en perfiles por defecto antiguos (27/32),
    # aplicar una sola vez la inclinacion nueva. Preservar angulos propios.
    if !@visual25d_pitch45_migrated
      @visual25d_pitch45_migrated = true
      if @visual25d_tilt && [27.0, 32.0].include?(@visual25d_tilt.to_f)
        @visual25d_tilt = Visual25D::Config::TILT_DEGREES
      end
    end
    return if @visual25d_gen5_flat_migrated
    @visual25d_gen5_flat_migrated = true
    @visual25d_model = :gen5 if @visual25d_model.nil? ||
                               @visual25d_model == :classic ||
                               @visual25d_model == :camera
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
