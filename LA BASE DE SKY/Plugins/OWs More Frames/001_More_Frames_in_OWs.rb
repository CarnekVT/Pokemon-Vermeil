# encoding: utf-8
module OWsMoreFrames
  DEFAULT_FRAMES = 4
  def self.detect_frames(bitmap)
    return DEFAULT_FRAMES unless bitmap
    width  = bitmap.width
    height = bitmap.height
    return DEFAULT_FRAMES if width <= 0 || height <= 0

    cell_h = height / 4
    return DEFAULT_FRAMES if cell_h <= 0

    exact = width.to_f / cell_h
    rounded = exact.round
    return rounded if (exact - rounded).abs < 0.02

    [16, 12, 10, 8, 6, 5, 4, 3, 2].each do |f|
      expected = f * cell_h
      return f if (width - expected).abs <= 2
    end

    [16, 12, 10, 8, 6, 5, 4, 3, 2].each do |f|
      expected = (f * cell_h).to_f
      ratio = width.to_f / expected
      return f if (ratio - 1.0).abs < 0.01
    end

    result = [rounded, 4].max
    result
  end
end

class Game_Character
  def frames
    # Re-detectar si cambió el charset
    if @frames && @frames > 0 && @character_name != @_ows_last_char_name
      @_ows_last_char_name = @character_name
      @frames = nil
    end
    return @frames if @frames && @frames > 0
    if @character_name && @character_name != ""
      begin
        bitmap = AnimatedBitmap.new("Graphics/Characters/" + @character_name, @character_hue)
        @frames = OWsMoreFrames.detect_frames(bitmap.bitmap)
        bitmap.dispose
      rescue
        @frames = 4
      end
    else
      @frames = 4
    end
    @_ows_last_char_name = @character_name
    return @frames
  end

  def frames=(val)
    @frames = val
  end
  alias old_initialize initialize unless method_defined?(:old_initialize)
  def initialize(*args)
    old_initialize(*args)
    @frames = 4
  end
  def update_pattern
    if self == $game_player && defined?($disable_scroll_counter) && $disable_scroll_counter == 2
      $disable_scroll_counter = 1
    end
    return if @lock_pattern
    # Character has stopped moving, return to original pattern
    if @moved_last_frame && !@moved_this_frame && !@step_anime
      @pattern = @original_pattern
      @anime_count = 0
      return
    end
    # Character has started to move, change pattern immediately
    if !@moved_last_frame && @moved_this_frame
      @pattern = (@pattern + 1) % self.frames if @walk_anime
      @anime_count = 0
      return
    end
    # Calculate how many frames each pattern should display for
    pattern_time = pattern_update_speed / self.frames
    return if @anime_count < pattern_time
    # Advance to the next animation frame
    @pattern = (@pattern + 1) % self.frames
    @anime_count -= pattern_time
  end
end

class Sprite_Character
  alias old_set_charset_graphic set_charset_graphic unless method_defined?(:old_set_charset_graphic)
  def set_charset_graphic
    @charbitmap = AnimatedBitmap.new(
      "Graphics/Characters/" + @character_name, @character_hue
    )
    RPG::Cache.retain("Graphics/Characters/", @character_name, @character_hue) if @character == $game_player
    @charbitmapAnimated = true
    @spriteoffset = @character_name[/offset/i]
    frames = OWsMoreFrames.detect_frames(@charbitmap.bitmap)
    @character.frames = frames
    @cw = @charbitmap.width / frames
    @ch = @charbitmap.height / 4
    self.ox = @cw / 2
  end
  alias old_update_charset_frame update_charset_frame unless method_defined?(:old_update_charset_frame)
  def update_charset_frame
    return if @tile_id > 0
    frames = @character.frames
    sx = (@character.pattern % frames) * @cw
    sy = source_frame_y * @ch
    self.src_rect.set(sx, sy, @cw, @ch)
    self.oy = (@spriteoffset rescue false) ? @ch - 16 : @ch
  end
end

class TrainerWalkingCharSprite < Sprite
  alias old_charset_set charset= unless method_defined?(:old_charset_set)
  def charset=(value)
    old_charset_set(value)
    if self.bitmap
      frames = OWsMoreFrames.detect_frames(self.bitmap)
      @frames = frames
      self.src_rect.set(0, 0, self.bitmap.width / frames, self.bitmap.height / 4)
    end
  end

  alias old_altcharset_set altcharset= unless method_defined?(:old_altcharset_set)
  def altcharset=(value)
    old_altcharset_set(value)
    if self.bitmap
      frames = OWsMoreFrames.detect_frames(self.bitmap)
      @frames = frames
      self.src_rect.set(0, 0, self.bitmap.width / frames, self.bitmap.height)
    end
  end

  alias old_update_frame update_frame unless method_defined?(:old_update_frame)
  def update_frame
    frames = @frames || 4
    @current_frame = (frames * (System.uptime % @anim_duration) / @anim_duration).floor
  end
end