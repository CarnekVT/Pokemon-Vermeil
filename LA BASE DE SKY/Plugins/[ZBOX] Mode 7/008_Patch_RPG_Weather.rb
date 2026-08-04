#===============================================================================
# Mode 7 (2.5D) - Parche para dibujar el Clima siempre al frente
#===============================================================================
class RPG::Weather
  alias_method :_ZBOX_M7_orig_weather_update, :update unless method_defined?(:_ZBOX_M7_orig_weather_update)

  def update
    _ZBOX_M7_orig_weather_update
    
    # Si el Modo 7 está activo, disparamos el Z-index del clima al máximo
    if $scene.is_a?(Scene_Map) && Mode7.active_now?
      for sprite in @sprites
        next if sprite.nil? || sprite.disposed?
        sprite.z = 999999 
      end
    end
  end
end