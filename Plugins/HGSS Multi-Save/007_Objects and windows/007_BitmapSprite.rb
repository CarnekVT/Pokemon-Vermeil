#===============================================================================
# Sprite class that stores multiple bitmaps, and displays only one at once.
#===============================================================================
class ChangelingSprite < Sprite
  # Key is the mode (a symbol).
  # Value is one of:
  #   filepath
  #   [filepath, src_x, src_y, src_width, src_height]
  BITMAPS = {}

  def initialize(x = 0, y = 0, viewport = nil)
    super(viewport)
    self.x = x
    self.y = y
    @bitmaps = {}
    @changeling_data = {}
    @current_bitmap = nil
    initialize_changeling_data
  end

  def initialize_changeling_data
    self.class::BITMAPS.each_pair { |mode, data| add_bitmap(mode, data) }
  end

  def dispose
    return if disposed?
    @bitmaps.each_value { |bm| bm.dispose }
    @bitmaps.clear
    super
  end

  #-----------------------------------------------------------------------------

  def add_bitmap(mode, *data)
    raise ArgumentError.new(_INTL("wrong number of arguments (given {1}, expected 2 or 6)", data.length + 1)) if ![1, 5].include?(data.length)
    filepath = (data[0].is_a?(Array)) ? data[0][0] : data[0]
    @bitmaps[filepath] = AnimatedBitmap.new(filepath) if !@bitmaps[filepath]
    @changeling_data[mode] = (data[0].is_a?(Array) ? data[0].clone : [data[0]])
  end

  def change_bitmap(mode)
    @current_mode = mode
    if @current_mode && @changeling_data[@current_mode]
      data = @changeling_data[@current_mode]
      @current_bitmap = @bitmaps[data[0]]
      self.bitmap = @current_bitmap.bitmap
      if data.length > 1
        self.src_rect.set(data[1], data[2], data[3], data[4])
      else
        self.src_rect.set(0, 0, self.bitmap.width, self.bitmap.height)
      end
    else
      @current_bitmap = nil
      self.bitmap = nil
    end
  end

  #-----------------------------------------------------------------------------

  def update
    return if disposed?
    @bitmaps.each_value { |bm| bm.update }
    self.bitmap = @current_bitmap.bitmap if @current_bitmap
  end
end
