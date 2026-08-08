# encoding: utf-8

module ZBOX
  module WeatherLayerFix
    NORMAL_SPRITE_Z = 1000

    module_function

    def use_mode7_weather_layer?
      return false unless $scene.is_a?(Scene_Map)
      return false if interface_open?
      return false unless defined?(Mode7) && Mode7.respond_to?(:rendering_now?)
      return Mode7.rendering_now?
    end

    def interface_open?
      return true if @interface_depth.to_i > 0
      return false if !$game_temp
      return $game_temp.in_menu || $game_temp.in_storage || $game_temp.message_window_showing
    end

    def with_interface
      @interface_depth = @interface_depth.to_i + 1
      lower_current_weather
      return yield
    ensure
      @interface_depth -= 1
    end

    def lower_current_weather
      return unless $scene.is_a?(Scene_Map)
      spriteset = $scene.spritesetGlobal
      return if !spriteset
      weather = spriteset.instance_variable_get(:@weather)
      return if !weather || !weather.respond_to?(:zbox_restore_normal_weather_layer)
      weather.zbox_restore_normal_weather_layer
    end
  end
end

class RPG::Weather
  alias_method :_ZBOX_weather_layer_orig_update, :update unless method_defined?(:_ZBOX_weather_layer_orig_update)

  def update
    _ZBOX_weather_layer_orig_update
    zbox_restore_normal_weather_layer if !ZBOX::WeatherLayerFix.use_mode7_weather_layer?
  end

  def zbox_restore_normal_weather_layer
    restore_zbox_normal_weather_layer
  end

  private

  def restore_zbox_normal_weather_layer
    return if !@viewport || @viewport.disposed?
    return if !@origViewport || @origViewport.disposed?

    @viewport.z = @origViewport.z + 1
    # ponytail: reset only layer state owned by this weather; centralize if more weather viewports appear.
    [@sprites, @new_sprites, @tiles].each do |sprites|
      next if !sprites
      sprites.each do |sprite|
        next if !sprite || sprite.disposed?
        sprite.z = ZBOX::WeatherLayerFix::NORMAL_SPRITE_Z
      end
    end
  end
end

class Object
  alias_method :_ZBOX_wlf_orig_pbDebugMenu, :pbDebugMenu unless method_defined?(:_ZBOX_wlf_orig_pbDebugMenu) || private_method_defined?(:_ZBOX_wlf_orig_pbDebugMenu)
  def pbDebugMenu(*args)
    return ZBOX::WeatherLayerFix.with_interface { _ZBOX_wlf_orig_pbDebugMenu(*args) }
  end
  private :pbDebugMenu

  alias_method :_ZBOX_wlf_orig_pbCreateMessageWindow, :pbCreateMessageWindow unless method_defined?(:_ZBOX_wlf_orig_pbCreateMessageWindow) || private_method_defined?(:_ZBOX_wlf_orig_pbCreateMessageWindow)
  def pbCreateMessageWindow(*args)
    ZBOX::WeatherLayerFix.lower_current_weather
    return _ZBOX_wlf_orig_pbCreateMessageWindow(*args)
  end
  private :pbCreateMessageWindow
end
