# encoding: utf-8
class RPG::Weather
  alias_method :_CARNEKVT_cw_orig_update_sprite_position, :update_sprite_position unless method_defined?(:_CARNEKVT_cw_orig_update_sprite_position)
  alias_method :_CARNEKVT_cw_orig_set_sprite_bitmap, :set_sprite_bitmap unless method_defined?(:_CARNEKVT_cw_orig_set_sprite_bitmap)
  alias_method :_CARNEKVT_cw_orig_prepare_bitmaps, :prepare_bitmaps unless method_defined?(:_CARNEKVT_cw_orig_prepare_bitmaps)
  alias_method :_CARNEKVT_cw_orig_update, :update unless method_defined?(:_CARNEKVT_cw_orig_update)
  alias_method :_CARNEKVT_cw_orig_reset_sprite_position, :reset_sprite_position unless method_defined?(:_CARNEKVT_cw_orig_reset_sprite_position)

  def update
    _CARNEKVT_cw_orig_update
    if $game_switches && $game_switches[CustomWeather::SEPIA_FILTER_SWITCH]
      current_strength = (@max && @max > 0) ? @max : 40 
      gray_val = [current_strength * 4, 255].min
      @viewport.tone.set(-10, -20, -30, gray_val)
    end
  end

  def ensure_safe_offsets
    @ox_offset = 0 if @ox_offset.nil? || (@ox_offset.is_a?(Float) && @ox_offset.nan?)
    @oy_offset = 0 if @oy_offset.nil? || (@oy_offset.is_a?(Float) && @oy_offset.nan?)
  end

  def prepare_bitmaps(type)
    _CARNEKVT_cw_orig_prepare_bitmaps(type)
    ensure_safe_offsets
  end

  def set_sprite_bitmap(sprite, index, weather_type)
    if @weatherTypes[weather_type] && @weatherTypes[weather_type][0].category == :Rain && @weatherTypes[weather_type][1].length == 1
      weatherBitmaps = @weatherTypes[weather_type][1]
      sprite.bitmap = weatherBitmaps[0]
      if CustomWeather::PROPERTIES.key?(weather_type)
        sprite.angle = CustomWeather::FALLING_DIAG_TYPES.include?(weather_type) ? 0 : rand(360)
      end
    else
      _CARNEKVT_cw_orig_set_sprite_bitmap(sprite, index, weather_type)
    end
  end

  def update_sprite_position(sprite, index, is_new_sprite = false)
    weather_type = (is_new_sprite) ? @target_type : @type
    if !@weatherTypes[weather_type] && GameData::Weather.exists?(weather_type)
      prepare_bitmaps(weather_type)
    end
    if CustomWeather::PROPERTIES.key?(weather_type)
        behavior = CustomWeather::get_behavior(weather_type)
        if is_new_sprite || sprite.x.nil? || sprite.y.nil?
          ensure_safe_offsets 
          reset_sprite_position(sprite, index, is_new_sprite)
          return 
        end
        case behavior
        when :storm then update_storm_particle(sprite, index, is_new_sprite, weather_type)
        when :flutter then update_flutter_particle(sprite, index, is_new_sprite, weather_type)
        when :spin, :whirl then update_spinning_particle(sprite, index, is_new_sprite, weather_type)
        when :rise then update_rising_particle(sprite, index, is_new_sprite, weather_type)
        when :custom then update_custom_generic(sprite, index, is_new_sprite, weather_type)
        else _CARNEKVT_cw_orig_update_sprite_position(sprite, index, is_new_sprite)
        end
    else
      _CARNEKVT_cw_orig_update_sprite_position(sprite, index, is_new_sprite)
    end
  end

  private
  def get_weather_data(weather_type)
     return @weatherTypes[weather_type][0] if @weatherTypes[weather_type]
     nil
  end

  def update_flutter_particle(sprite, index, is_new_sprite, weather_type)
    return if sprite.x.nil? 
    data = get_weather_data(weather_type)
    return unless data
    t = (Graphics.frame_count + index * 10) / 45.0 
    sprite.x += data.particle_delta_x
    sprite.y += data.particle_delta_y
    sprite.opacity += data.particle_delta_opacity * 0.1 
    sprite.x += Math.sin(t) * 1.5 
    sprite.angle = Math.sin(t / 2.0) * 20 
    check_custom_offscreen(sprite, index, is_new_sprite)
  end

  def update_spinning_particle(sprite, index, is_new_sprite, weather_type)
    return if sprite.x.nil?
    data = get_weather_data(weather_type)
    return unless data
    t = Graphics.frame_count
    sprite.x += data.particle_delta_x
    sprite.y += data.particle_delta_y + Math.sin(t / 5.0) * 2 
    sprite.angle += 5
    check_custom_offscreen(sprite, index, is_new_sprite)
  end

  def update_storm_particle(sprite, index, is_new_sprite, weather_type)
    return if sprite.x.nil?
    data = get_weather_data(weather_type)
    return unless data
    sprite.x += data.particle_delta_x
    sprite.y += data.particle_delta_y
    if CustomWeather::FALLING_DIAG_TYPES.include?(weather_type)
      t = (Graphics.frame_count + index * 7) / 50.0
      sprite.x += Math.sin(t) * 0.4 + ((rand * 0.3) - 0.15)
      sprite.y += (rand * 0.4) - 0.1
      sprite.opacity -= 2
    else
      sprite.opacity = 200 
    end
    is_thunder = weather_type.to_s.include?("Thunderstorm")
    if is_thunder && rand(500) == 0
       @viewport.flash(Color.new(255, 255, 255, 200), 5)
       pbSEPlay("061-Thunderclap01") if File.exist?("Audio/SE/061-Thunderclap01")
    end
    check_custom_offscreen(sprite, index, is_new_sprite)
  end

  def update_rising_particle(sprite, index, is_new_sprite, weather_type)
    return if sprite.x.nil?
    data = get_weather_data(weather_type)
    return unless data
    t = Graphics.frame_count / 20.0
    sprite.x += Math.sin(t + index) 
    sprite.y += data.particle_delta_y 
    sprite.opacity -= 2
    sprite.tone = Tone.new(rand(50), rand(50), 0) if rand(10) == 0
    if sprite.y < -50 || sprite.opacity <= 0
       reset_sprite_position(sprite, index, is_new_sprite)
       sprite.y = 500
    end
  end

  def update_custom_generic(sprite, index, is_new_sprite, weather_type)
     if $CUSTOM_WEATHER_UPDATE
       update_user_defined_bitmaps
       $CUSTOM_WEATHER_UPDATE = false
     end
     return if sprite.x.nil?
     sprite.x += $CUSTOM_WEATHER_X
     sprite.y += $CUSTOM_WEATHER_Y
     sprite.opacity -= $CUSTOM_WEATHER_FADE
     check_custom_offscreen(sprite, index, is_new_sprite)
  end

  def update_user_defined_bitmaps
    return if $CUSTOM_WEATHER_IMAGES.empty?
    @weatherTypes[:UserDefined][1].each { |bitmap| bitmap.dispose }
    @weatherTypes[:UserDefined][1].clear
    $CUSTOM_WEATHER_IMAGES.each do |image_name|
      path = "Graphics/Weather/#{image_name}"
      if File.exist?(path + ".png") || File.exist?(path + ".gif")
         @weatherTypes[:UserDefined][1] << RPG::Cache.load_bitmap("Graphics/Weather/", "#{image_name}")
      end
    end
  end

  def check_custom_offscreen(sprite, index, is_new_sprite)
    ensure_safe_offsets 
    x = sprite.x - @ox - @ox_offset
    y = sprite.y - @oy - @oy_offset
    if sprite.opacity < 10 || x < -100 || x > Graphics.width + 100 || y < -100 || y > Graphics.height + 100
      reset_sprite_position(sprite, index, is_new_sprite)
    end
  end

  def reset_sprite_position(sprite, index, is_new_sprite = false)
    weather_type = (is_new_sprite) ? @target_type : @type
    if CustomWeather::FALLING_DIAG_TYPES.include?(weather_type)
      return if !sprite || !sprite.bitmap
      if index < (is_new_sprite ? @new_max : @max)
        sprite.visible = true
      else
        sprite.visible = false
        return
      end
      ensure_safe_offsets
      if rand < 0.65
        sprite.x = @ox + @ox_offset - sprite.bitmap.width + rand(Graphics.width + sprite.bitmap.width)
        sprite.y = @oy + @oy_offset - sprite.bitmap.height - rand((Graphics.height * 0.4).to_i + 1)
      else
        sprite.x = @ox + @ox_offset + Graphics.width + rand((Graphics.width * 0.4).to_i + 1)
        sprite.y = @oy + @oy_offset - sprite.bitmap.height + rand((Graphics.height * 0.9).to_i + 1)
      end
      sprite.opacity = 255
      return
    end
    _CARNEKVT_cw_orig_reset_sprite_position(sprite, index, is_new_sprite)
  end
end

class Battle
  alias_method :_CARNEKVT_cw_orig_pbStartWeather, :pbStartWeather unless method_defined?(:_CARNEKVT_cw_orig_pbStartWeather)
  def pbStartWeather(user, newWeather, fixedDuration = false, showAnim = true)
    _CARNEKVT_cw_orig_pbStartWeather(user, newWeather, fixedDuration, showAnim)
  end

  alias_method :_CARNEKVT_cw_orig_pbStartBattleCore, :pbStartBattleCore unless method_defined?(:_CARNEKVT_cw_orig_pbStartBattleCore)
  def pbStartBattleCore(*args)
    overworld_weather = $game_screen ? $game_screen.weather_type : :None
    has_decorative_weather = false
    if CustomWeather::PROPERTIES.key?(overworld_weather)
      target = nil
      if GameData::Weather.exists?(overworld_weather)
        target = GameData::Weather.get(overworld_weather).battle_weather if GameData::Weather.get(overworld_weather).respond_to?(:battle_weather)
      end
      target = CustomWeather::PROPERTIES[overworld_weather][:battle_weather] if CustomWeather::PROPERTIES[overworld_weather].key?(:battle_weather)
      target ||= :None
      has_decorative_weather = (target == :None)
    end
    _CARNEKVT_cw_orig_pbStartBattleCore(*args)
    if has_decorative_weather
      @field.defaultWeather = :None
      @field.weather = :None
      @field.weatherDuration = 0
    end
  end

  alias_method :_CARNEKVT_cw_orig_defaultWeather_set, :defaultWeather= unless method_defined?(:_CARNEKVT_cw_orig_defaultWeather_set)
  def defaultWeather=(value)
    overworld_weather = $game_screen ? $game_screen.weather_type : :None
    if CustomWeather::PROPERTIES.key?(overworld_weather)
      target = CustomWeather::PROPERTIES[overworld_weather][:battle_weather] if CustomWeather::PROPERTIES[overworld_weather].key?(:battle_weather)
      target ||= :None
      if target == :None
        self._CARNEKVT_cw_orig_defaultWeather_set(:None)
        return
      end
    end
    self._CARNEKVT_cw_orig_defaultWeather_set(value)
  end
end

def pbSetCustomWeather(type, max = 40, duration = 20)
  return unless $game_map && $game_map.weather
  if CustomWeather::FALLING_DIAG_TYPES.include?(type)
    max = CustomWeather::FALLING_DIAG_MAX
  elsif type == CustomWeather::TYPE_GREEN_LEAVES
    max = [(max * 0.9).round, 6].max
  end
  weather_type = GameData::Weather.get(type).id
  $game_map.weather.fade_in(weather_type, max, duration)
end

def pbResetWeather(duration = 20)
  return unless $game_map && $game_map.weather
  $game_map.weather.fade_in(:None, 0, duration)
end
