#===============================================================================
# [VERMEIL] Visual 2.5D - 006_Atmosphere.rb
# Clima al frente en la camara 2.5D: fuerza el viewport de lluvia/nieve a la
# maxima profundidad para que se dibuje por delante del mapa proyectado,
# pero respetando ventanas de mensajes, menus y la interfaz (Weather Layer Fix).
#===============================================================================

module Mode7
  module WeatherLayer
    NORMAL_SPRITE_Z = 1000
    MODE7_WEATHER_Z = 999_999

    module_function

    def use_mode7_weather_layer?
      return false unless $scene.is_a?(Scene_Map)
      return false if interface_open?
      return false unless Mode7.respond_to?(:rendering_now?)
      Mode7.rendering_now?
    end

    def interface_open?
      return true if @interface_depth.to_i > 0
      return false if !$game_temp
      $game_temp.in_menu || $game_temp.in_storage || $game_temp.message_window_showing
    end

    def with_interface
      @interface_depth = @interface_depth.to_i + 1
      lower_current_weather
      yield
    ensure
      @interface_depth -= 1
    end

    def lower_current_weather
      return unless $scene.is_a?(Scene_Map)
      spriteset = $scene.spritesetGlobal rescue nil
      return if !spriteset
      weather = spriteset.instance_variable_get(:@weather)
      return if !weather || !weather.respond_to?(:restore_normal_weather_layer)
      weather.restore_normal_weather_layer
    end
  end
end

class RPG::Weather
  MODE7_WEATHER_Z = Mode7::WeatherLayer::MODE7_WEATHER_Z

  alias_method :_VERMEIL_25D_weather_update_orig, :update unless method_defined?(:_VERMEIL_25D_weather_update_orig)
  alias_method :_VERMEIL_25D_weather_pos_orig, :update_sprite_position unless method_defined?(:_VERMEIL_25D_weather_pos_orig)

  def update
    _VERMEIL_25D_weather_update_orig
    if Mode7::WeatherLayer.use_mode7_weather_layer?
      force_weather_in_front
    else
      restore_normal_weather_layer
    end
  end

  def update_sprite_position(sprite, index, is_new_sprite = false)
    _VERMEIL_25D_weather_pos_orig(sprite, index, is_new_sprite)
    if Mode7::WeatherLayer.use_mode7_weather_layer?
      sprite.z = MODE7_WEATHER_Z if sprite && !sprite.disposed?
    end
  end

  def restore_normal_weather_layer
    return if !@viewport || @viewport.disposed?
    return if !@origViewport || @origViewport.disposed?

    @viewport.z = @origViewport.z + 1
    [@sprites, @new_sprites, @tiles].each do |sprites|
      next unless sprites
      sprites.each do |sprite|
        next if !sprite || sprite.disposed?
        sprite.z = Mode7::WeatherLayer::NORMAL_SPRITE_Z
      end
    end
  end

  private

  def force_weather_in_front
    return unless @viewport && !@viewport.disposed?

    @viewport.z = MODE7_WEATHER_Z
    [@sprites, @new_sprites, @tiles].each do |collection|
      next unless collection
      collection.each do |particle|
        particle.z = MODE7_WEATHER_Z if particle && !particle.disposed?
      end
    end
  end
end

# Interceptores de interfaz para bajar el clima cuando se abren ventanas
class Object
  alias_method :_VERMEIL_wlf_orig_pbDebugMenu, :pbDebugMenu unless method_defined?(:_VERMEIL_wlf_orig_pbDebugMenu) || private_method_defined?(:_VERMEIL_wlf_orig_pbDebugMenu)
  def pbDebugMenu(*args)
    Mode7::WeatherLayer.with_interface { _VERMEIL_wlf_orig_pbDebugMenu(*args) }
  end
  private :pbDebugMenu

  alias_method :_VERMEIL_wlf_orig_pbCreateMessageWindow, :pbCreateMessageWindow unless method_defined?(:_VERMEIL_wlf_orig_pbCreateMessageWindow) || private_method_defined?(:_VERMEIL_wlf_orig_pbCreateMessageWindow)
  def pbCreateMessageWindow(*args)
    Mode7::WeatherLayer.lower_current_weather
    _VERMEIL_wlf_orig_pbCreateMessageWindow(*args)
  end
  private :pbCreateMessageWindow
end

# --- Sombra de OW sobre superficies elevadas (antes 015_OWShadowDepth.rb) ---
class Game_Player
  alias_method :_VERMEIL_25D_orig_shows_shadow?, :shows_shadow? unless method_defined?(:_VERMEIL_25D_orig_shows_shadow?)

  def shows_shadow?(recalc = false)
    result = _VERMEIL_25D_orig_shows_shadow?(recalc)
    return result if result || !$scene.is_a?(Scene_Map) || !Mode7.rendering_now?
    tag = $game_map.terrain_tag(x, y)
    return result if !tag || tag.id == :None
    walls = Mode7.indoor_map? ? Mode7::Config::INDOOR_WALL_TERRAIN_TAG_HEIGHT :
                                Mode7::Config::OUTDOOR_WALL_TERRAIN_TAG_HEIGHT
    walls.key?(tag.id)
  end
end

class Sprite_OWShadow
  alias_method :_VERMEIL_25D_orig_update_depth, :update unless method_defined?(:_VERMEIL_25D_orig_update_depth)

  def update
    _VERMEIL_25D_orig_update_depth
    return if disposed? || !$scene.is_a?(Scene_Map) || !Mode7.rendering_now?
    return if !@event.is_a?(Game_Player) || !@sprite || @sprite.disposed? ||
              !@rsprite || @rsprite.disposed?
    if Mode7::Config::OW_SHADOW_HIDE_IN_BUSH && @event.bush_depth > 0
      @sprite.visible = false
      return
    end
    return if !@sprite.visible || @sprite.opacity <= 0
    if Mode7::Config::OW_SHADOW_GROUND_ALIGNMENT && Mode7.perspective_mode?
      # Sprite_OWShadow hereda el zoom uniforme del personaje. Una sombra es
      # plana, así que Y debe usar la derivada vertical del plano proyectado.
      # Conservamos el factor temporal de salto/flotación del script original.
      original_scale = @rsprite.zoom_x.to_f
      factor = original_scale.abs > 0.001 ? @sprite.zoom_x.to_f / original_scale : 1.0
      wy = @event.real_y.to_f / Game_Map::Y_SUBPIXELS + Game_Map::TILE_HEIGHT
      elevation = if Mode7.respond_to?(:nds_surface_height_at_real)
                    wx = @event.real_x.to_f / Game_Map::X_SUBPIXELS + Game_Map::TILE_WIDTH / 2.0
                    Mode7.nds_surface_height_at_real(wx, wy)
                  else
                    Mode7.nds_surface_height_at(@event.x, @event.y)
                  end
      @sprite.zoom_x = Mode7.object_scale_for_world_y(wy, elevation) * factor
      @sprite.zoom_y = Mode7.perspective_vertical_scale_for_world_y(wy, elevation) * factor
    end
    # No usar ground_cap: cambia por celda durante movimiento vertical/diagonal
    # y hace alternar z contra Mountain. Mismo Z interpolado del player, -1.
    @sprite.z = @event.screen_z(@rsprite.src_rect.height) - 1
  rescue Exception
    # ponytail: sombra vanilla queda intacta si una API externa no esta lista.
  end
end