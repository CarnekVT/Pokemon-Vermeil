#===============================================================================
# Location signpost
#===============================================================================
class LocationWindow
  APPEAR_TIME = 0.62  # In seconds; is also the disappear time
  LINGER_TIME = 1.9   # In seconds; time during which self is fully visible

  def initialize(name, graphic_name = nil, animate = true, viewport = nil, speed_multiplier = 1.0, hold_open = false)
    @animate = animate
    @dismissing = false
    @hold_open = hold_open
    speed_multiplier = 1.0 if speed_multiplier.to_f <= 0
    @appear_time = APPEAR_TIME / speed_multiplier.to_f
    @linger_time = LINGER_TIME
    initialize_viewport(viewport)
    initialize_graphic(graphic_name)
    initialize_text_window(name)
    apply_style(graphic_name)
    setup_initial_positions
    cache_base_opacities
    @current_map = $game_map.map_id
    @timer_start = System.uptime
    @delayed = !$game_temp.fly_destination.nil?
    set_opacity((@animate) ? 0 : 255)
    sync_screen_tone
  end

  def initialize_viewport(viewport)
    if viewport
      @viewport = viewport
      @owns_viewport = false
      return
    end
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @owns_viewport = true
  end

  def initialize_graphic(graphic_name)
    return if graphic_name.nil? || !pbResolveBitmap("Graphics/UI/Location/#{graphic_name}")
    @graphic = Sprite.new(@viewport)
    @graphic.bitmap = RPG::Cache.ui("Location/#{graphic_name}")
    @graphic.x = 0
    @graphic.y = 0
  end

  def initialize_text_window(name)
    @window = Window_AdvancedTextPokemon.new(name)
    @window.resizeToFit(name, Graphics.width)
    @window.x        = 0
    @window.y        = 0
    @window.z        = 1
    @window.viewport = @viewport
  end

  def apply_style(graphic_name)
    @graphic_offset = [0, 0]
    @window_offset = [0, 0]
    @y_distance = @window.height
    return if graphic_name.nil?
    style = :none
    base_color = nil
    shadow_color = nil
    zoom_x = 1
    zoom_y = 1
    center_text = false
    Settings::LOCATION_SIGN_GRAPHIC_STYLES.each_pair do |val, filenames|
      filenames.each do |filename|
        if filename.is_a?(Hash)
          next if !filename.key?(:graphic) || filename[:graphic] != graphic_name
          base_color = filename[:text_color] if filename.key?(:text_color)
          shadow_color = filename[:shadow_color] if filename.key?(:shadow_color)
          zoom_x = filename[:zoomx] || 1
          zoom_y = filename[:zoomy] || 1
          @window_offset = filename[:text_offset] || [0, 0]
          @graphic_offset = filename[:graphic_offset] || [0, 0]
          center_text = filename[:center_text] || false
        elsif filename.is_a?(Array)
          next if filename[0] != graphic_name
          base_color = filename[1]
          shadow_color = filename[2]
        else
          next if filename != graphic_name
        end
        style = val
        break
      end
      break if style != :none
    end
    return if style == :none
    @y_distance = @graphic&.height || @window.height
    @window.back_opacity = 0
    @graphic.zoom_x = zoom_x if @graphic
    @graphic.zoom_y = zoom_y if @graphic
    case style
    when :dp
      @window.baseColor = base_color if base_color
      @window.shadowColor = shadow_color if shadow_color
      @window.text = @window.text
      @window_offset = [8, -10] if @window_offset == [0, 0]
      @graphic&.dispose
      @graphic = Window_AdvancedTextPokemon.new("")
      @graphic.setSkin("Graphics/UI/Location/#{graphic_name}")
      @graphic.width    = @window.width + (@window_offset[0] * 2) - 4
      @graphic.height   = 48
      @graphic.x        = 0
      @graphic.y        = 0
      @graphic.z        = 0
      @graphic.zoom_x   = zoom_x
      @graphic.zoom_y   = zoom_y
      @graphic.viewport = @viewport
      @y_distance = @graphic.height
    when :hgss
      @window.baseColor = base_color if base_color
      @window.shadowColor = shadow_color if shadow_color
      @window.width = @graphic.width
    when :platinum
      @window.baseColor = base_color || Color.black
      @window.shadowColor = shadow_color || Color.new(144, 144, 160)
      @window.text = @window.text
      @window_offset = [10, 16] if @window_offset == [0, 0]
    when :oras
      @window.baseColor = base_color || Color.white
      @window.shadowColor = shadow_color || Color.new(0, 0, 0, 128)
    when :xy
      @window.baseColor = base_color || Color.white
      @window.shadowColor = shadow_color || Color.new(0, 0, 0, 128)
    end
    @window.text = @window.text
    @window.text = "<ac>" + @window.text if center_text
  end

  def setup_initial_positions
    ref_y = @graphic_offset[1] || 0
    @animate_from_bottom = (ref_y > Graphics.height / 2)
    initial_y_offset = (@animate) ? animation_start_offset : 0
    if @graphic
      @graphic.x = @graphic_offset[0]
      @graphic.y = @graphic_offset[1] + initial_y_offset
    end
    @window.x = @graphic_offset[0] + @window_offset[0]
    @window.y = @graphic_offset[1] + @window_offset[1] + initial_y_offset
  end

  def disposed?
    return @window.disposed?
  end

  def dispose
    @graphic&.dispose
    @window.dispose
    @viewport.dispose if @owns_viewport && @viewport && !@viewport.disposed?
  end

  def update
    return if disposed? || $game_temp.fly_destination
    sync_screen_tone
    if @delayed
      @timer_start = System.uptime
      @delayed = false
    end
    @graphic&.update
    @window.update
    return if !@animate
    dismiss if $game_temp.message_window_showing
    if @current_map != $game_map.map_id
      dispose
      return
    end
    elapsed = System.uptime - @timer_start
    if elapsed < @appear_time
      # Pause signs should feel responsive while still animated.
      progress = (@hold_open) ? ease_out_cubic(elapsed / @appear_time) : ease_in_cubic(elapsed / @appear_time)
      y_pos = lerp(animation_start_offset, 0, progress)
      set_opacity((255 * progress).round)
    elsif @hold_open || elapsed < @appear_time + @linger_time
      y_pos = 0
      set_opacity(255)
    else
      # Smooth exit.
      progress = ease_in_cubic((elapsed - @appear_time - @linger_time) / @appear_time)
      y_pos = lerp(0, animation_start_offset, progress)
      set_opacity((255 * (1.0 - progress)).round)
      if progress >= 1.0
        dispose
        return
      end
    end
    @window.x = @graphic_offset[0] + @window_offset[0]
    @window.y = @graphic_offset[1] + @window_offset[1] + y_pos
    if @graphic && !@graphic.disposed?
      @graphic.x = @graphic_offset[0]
      @graphic.y = @graphic_offset[1] + y_pos
    end
  end

  private

  def animation_start_offset
    return (@animate_from_bottom) ? @y_distance : -@y_distance
  end

  def sync_screen_tone
    return if !@owns_viewport || !@viewport || @viewport.disposed? || !$game_screen
    return if !@viewport.respond_to?(:tone) || !$game_screen.respond_to?(:tone) || !$game_screen.tone
    @viewport.tone.set($game_screen.tone.red,
                       $game_screen.tone.green,
                       $game_screen.tone.blue,
                       $game_screen.tone.gray)
  end

  def dismiss(exit_speed_multiplier = 1.0)
    return if disposed? || @dismissing
    @dismissing = true
    exit_speed_multiplier = [exit_speed_multiplier.to_f, 1.0].max
    @appear_time = [@appear_time / exit_speed_multiplier, 0.06].max
    # If this sign was static (pause menu), enable animation just for the exit.
    @animate = true
    # Jump to the start of the exit phase.
    @timer_start = System.uptime - (@appear_time + @linger_time)
  end

  def cache_base_opacities
    @window_base_opacity = (@window.respond_to?(:opacity) ? @window.opacity : 255)
    @window_base_back_opacity = (@window.respond_to?(:back_opacity) ? @window.back_opacity : 255)
    @graphic_base_opacity = (@graphic&.respond_to?(:opacity) ? @graphic.opacity : 255)
    @graphic_base_back_opacity = (@graphic&.respond_to?(:back_opacity) ? @graphic.back_opacity : 255)
  end

  def lerp(start_pos, end_pos, t)
    t = [[t, 0.0].max, 1.0].min
    return start_pos + ((end_pos - start_pos) * t)
  end

  def ease_out_cubic(t)
    t = [[t, 0.0].max, 1.0].min
    return 1.0 - ((1.0 - t)**3)
  end

  def ease_in_cubic(t)
    t = [[t, 0.0].max, 1.0].min
    return t**3
  end

  def set_opacity(value)
    value = [[value, 0].max, 255].min
    ratio = value / 255.0
    if @window
      @window.contents_opacity = value if @window.respond_to?(:contents_opacity=)
      @window.opacity = (@window_base_opacity * ratio).round if @window.respond_to?(:opacity=)
      @window.back_opacity = (@window_base_back_opacity * ratio).round if @window.respond_to?(:back_opacity=)
    end
    if @graphic
      @graphic.contents_opacity = value if @graphic.respond_to?(:contents_opacity=)
      @graphic.opacity = (@graphic_base_opacity * ratio).round if @graphic.respond_to?(:opacity=)
      @graphic.back_opacity = (@graphic_base_back_opacity * ratio).round if @graphic.respond_to?(:back_opacity=)
    end
  end

  public

  def pbHoldOpen(value = true)
    @hold_open = value
  end

  def pbStartExit(exit_speed_multiplier = 1.0)
    dismiss(exit_speed_multiplier)
  end
end

#===============================================================================
# Visibility circle in dark maps
#===============================================================================
class DarknessSprite < Sprite
  attr_reader :radius

  def initialize(viewport = nil)
    super(viewport)
    @darkness = Bitmap.new(Graphics.width, Graphics.height)
    @radius = radiusMin
    self.bitmap = @darkness
    self.z      = 99998
    refresh
  end

  def dispose
    @darkness.dispose
    super
  end

  def radiusMin; return 64;  end   # Before using Flash
  def radiusMax; return 176; end   # After using Flash

  def radius=(value)
    @radius = value.round
    refresh
  end

  def refresh
    @darkness.fill_rect(0, 0, Graphics.width, Graphics.height, Color.black)
    cx = Graphics.width / 2
    cy = Graphics.height / 2
    cradius = @radius
    numfades = 5
    (1..numfades).each do |i|
      (cx - cradius..cx + cradius).each do |j|
        diff2 = (cradius * cradius) - ((j - cx) * (j - cx))
        diff = Math.sqrt(diff2)
        @darkness.fill_rect(j, cy - diff, 1, diff * 2, Color.new(0, 0, 0, 255.0 * (numfades - i) / numfades))
      end
      cradius = (cradius * 0.9).floor
    end
  end
end

#===============================================================================
# Light effects
#===============================================================================
class LightEffect
  def initialize(event, viewport = nil, map = nil, filename = nil)
    @light = IconSprite.new(0, 0, viewport)
    if !nil_or_empty?(filename) && pbResolveBitmap("Graphics/Pictures/" + filename)
      @light.setBitmap("Graphics/Pictures/" + filename)
    else
      @light.setBitmap("Graphics/Pictures/LE")
    end
    @light.z = 1000
    @event = event
    @map = (map) ? map : $game_map
    @disposed = false
  end

  def disposed?
    return @disposed
  end

  def dispose
    @light.dispose
    @map = nil
    @event = nil
    @disposed = true
  end

  def update
    @light.update
  end
end

#===============================================================================
#
#===============================================================================
class LightEffect_Lamp < LightEffect
  def initialize(event, viewport = nil, map = nil)
    lamp = AnimatedBitmap.new("Graphics/Pictures/LE")
    @light = Sprite.new(viewport)
    @light.bitmap = Bitmap.new(128, 64)
    src_rect = Rect.new(0, 0, 64, 64)
    @light.bitmap.blt(0, 0, lamp.bitmap, src_rect)
    @light.bitmap.blt(20, 0, lamp.bitmap, src_rect)
    @light.visible = true
    @light.z       = 1000
    lamp.dispose
    @map = (map) ? map : $game_map
    @event = event
  end
end

#===============================================================================
#
#===============================================================================
class LightEffect_Basic < LightEffect
  def initialize(event, viewport = nil, map = nil, filename = nil)
    super
    @light.ox = @light.bitmap.width / 2
    @light.oy = @light.bitmap.height / 2
    @light.opacity = 100
  end

  def update
    return if !@light || !@event
    super
    if (Object.const_defined?(:ScreenPosHelper) rescue false)
      @light.x      = ScreenPosHelper.pbScreenX(@event)
      @light.y      = ScreenPosHelper.pbScreenY(@event) - (@event.height * Game_Map::TILE_HEIGHT / 2)
      @light.zoom_x = ScreenPosHelper.pbScreenZoomX(@event)
      @light.zoom_y = @light.zoom_x
    else
      @light.x = @event.screen_x
      @light.y = @event.screen_y - (Game_Map::TILE_HEIGHT / 2)
    end
    @light.tone = $game_screen.tone
  end
end

#===============================================================================
#
#===============================================================================
class LightEffect_DayNight < LightEffect
  def initialize(event, viewport = nil, map = nil, filename = nil)
    super
    @light.ox = @light.bitmap.width / 2
    @light.oy = @light.bitmap.height / 2
  end

  def update
    return if !@light || !@event
    super
    shade = PBDayNight.getShade
    if shade >= 144   # If light enough, call it fully day
      shade = 255
    elsif shade <= 64   # If dark enough, call it fully night
      shade = 0
    else
      shade = 255 - (255 * (144 - shade) / (144 - 64))
    end
    @light.opacity = 255 - shade
    if @light.opacity > 0
      if (Object.const_defined?(:ScreenPosHelper) rescue false)
        @light.x      = ScreenPosHelper.pbScreenX(@event)
        @light.y      = ScreenPosHelper.pbScreenY(@event) - (@event.height * Game_Map::TILE_HEIGHT / 2)
        @light.zoom_x = ScreenPosHelper.pbScreenZoomX(@event)
        @light.zoom_y = ScreenPosHelper.pbScreenZoomY(@event)
      else
        @light.x = @event.screen_x
        @light.y = @event.screen_y - (Game_Map::TILE_HEIGHT / 2)
      end
      @light.tone.set($game_screen.tone.red,
                      $game_screen.tone.green,
                      $game_screen.tone.blue,
                      $game_screen.tone.gray)
    end
  end
end

#===============================================================================
#
#===============================================================================
EventHandlers.add(:on_new_spriteset_map, :add_light_effects,
  proc { |spriteset, viewport|
    map = spriteset.map   # Map associated with the spriteset (not necessarily the current map)
    map.events.each_key do |i|
      if map.events[i].name[/^outdoorlight\((\w+)\)$/i]
        filename = $~[1].to_s
        spriteset.addUserSprite(LightEffect_DayNight.new(map.events[i], viewport, map, filename))
      elsif map.events[i].name[/^outdoorlight$/i]
        spriteset.addUserSprite(LightEffect_DayNight.new(map.events[i], viewport, map))
      elsif map.events[i].name[/^light\((\w+)\)$/i]
        filename = $~[1].to_s
        spriteset.addUserSprite(LightEffect_Basic.new(map.events[i], viewport, map, filename))
      elsif map.events[i].name[/^light$/i]
        spriteset.addUserSprite(LightEffect_Basic.new(map.events[i], viewport, map))
      end
    end
  }
)
