#===============================================================================
# [VERMEIL] Visual 2.5D - 006_Atmosphere.rb
# Clima al frente en la camara 2.5D: fuerza el viewport de lluvia/nieve a la
# maxima profundidad para que se dibuje por delante del mapa proyectado.
#===============================================================================
class RPG::Weather
  MODE7_WEATHER_Z = 999_999 unless const_defined?(:MODE7_WEATHER_Z)

  alias_method :_VERMEIL_25D_weather_update_orig, :update unless method_defined?(:_VERMEIL_25D_weather_update_orig)
  alias_method :_VERMEIL_25D_weather_pos_orig, :update_sprite_position unless method_defined?(:_VERMEIL_25D_weather_pos_orig)

  def update
    _VERMEIL_25D_weather_update_orig
    force_weather_in_front
  end

  def update_sprite_position(sprite, index, is_new_sprite = false)
    _VERMEIL_25D_weather_pos_orig(sprite, index, is_new_sprite)
    if $scene.is_a?(Scene_Map) && Mode7.active_now?
      if sprite && !sprite.disposed?
        sprite.z = MODE7_WEATHER_Z
      end
    end
  end

  private

  def force_weather_in_front
    return unless $scene.is_a?(Scene_Map) && Mode7.active_now?

    # Aseguramos que el viewport del clima este por encima de cualquier capa del mapa
    if @viewport && !@viewport.disposed?
      @viewport.z = MODE7_WEATHER_Z
    end

    # Forzamos todas las colecciones de particulas internas del clima a la maxima profundidad
    [@sprites, @new_sprites, @tiles].each do |collection|
      next unless collection
      collection.each do |particle|
        if particle && !particle.disposed?
          particle.z = MODE7_WEATHER_Z
        end
      end
    end
  end
end