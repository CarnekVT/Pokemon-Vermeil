#===============================================================================
#
#===============================================================================
class BushBitmap
  def initialize(bitmap, isTile, depth)
    @bitmaps  = []
    @bitmap   = bitmap
    @isTile   = isTile
    @isBitmap = @bitmap.is_a?(Bitmap)
    @depth    = depth
  end

  def dispose
    @bitmaps.each { |b| b&.dispose }
  end

  def bitmap
    thisBitmap = (@isBitmap) ? @bitmap : @bitmap.bitmap
    current = (@isBitmap) ? 0 : @bitmap.currentIndex
    if !@bitmaps[current]
      if @isTile
        @bitmaps[current] = pbBushDepthTile(thisBitmap, @depth)
      else
        @bitmaps[current] = pbBushDepthBitmap(thisBitmap, @depth)
      end
    end
    return @bitmaps[current]
  end

  def pbBushDepthBitmap(bitmap, depth)
    ret = Bitmap.new(bitmap.width, bitmap.height)
    charheight = ret.height / 4
    cy = charheight - depth - 2
    4.times do |i|
      y = i * charheight
      if cy >= 0
        ret.blt(0, y, bitmap, Rect.new(0, y, ret.width, cy))
        ret.blt(0, y + cy, bitmap, Rect.new(0, y + cy, ret.width, 2), 170)
      end
      ret.blt(0, y + cy + 2, bitmap, Rect.new(0, y + cy + 2, ret.width, 2), 85) if cy + 2 >= 0
    end
    return ret
  end

  def pbBushDepthTile(bitmap, depth)
    ret = Bitmap.new(bitmap.width, bitmap.height)
    charheight = ret.height
    cy = charheight - depth - 2
    y = charheight
    if cy >= 0
      ret.blt(0, y, bitmap, Rect.new(0, y, ret.width, cy))
      ret.blt(0, y + cy, bitmap, Rect.new(0, y + cy, ret.width, 2), 170)
    end
    ret.blt(0, y + cy + 2, bitmap, Rect.new(0, y + cy + 2, ret.width, 2), 85) if cy + 2 >= 0
    return ret
  end
end

#===============================================================================
#
#===============================================================================
class Sprite_Character < RPG::Sprite
  attr_accessor :character

  def initialize(viewport, character = nil)
    super(viewport)
    @character    = character
    @oldbushdepth = 0
    @spriteoffset = false
    @tile_animation_timer = 0
    @tile_current_frame = 0
    if !character || character == $game_player || (character.name[/reflection/i] rescue false)
      @reflection = Sprite_Reflection.new(self, viewport)
    end
    @surfbase = Sprite_SurfBase.new(self, viewport) if character == $game_player
    self.zoom_x = TilemapRenderer::ZOOM_X
    self.zoom_y = TilemapRenderer::ZOOM_Y
    update
  end

  def groundY
    return @character.screen_y_ground
  end

  def visible=(value)
    super(value)
    @reflection.visible = value if @reflection
  end

  def dispose
    @bushbitmap&.dispose
    @bushbitmap = nil
    @charbitmap&.dispose
    @charbitmap = nil
    @reflection&.dispose
    @reflection = nil
    @surfbase&.dispose
    @surfbase = nil
    @character = nil
    super
  end

  def refresh_graphic
    return if @tile_id == @character.tile_id &&
              @character_name == @character.character_name &&
              @character_hue == @character.character_hue &&
              @oldbushdepth == @character.bush_depth
    @tile_id        = @character.tile_id
    @character_name = @character.character_name
    @character_hue  = @character.character_hue
    @oldbushdepth   = @character.bush_depth
    @charbitmap&.dispose
    @charbitmap = nil
    @bushbitmap&.dispose
    @bushbitmap = nil
    @tile_animation_timer = 0
    @tile_current_frame = 0
    if @tile_id >= 384
      @charbitmap = pbGetTileBitmap(@character.map.tileset_name, @tile_id,
                                    @character_hue, @character.width, @character.height)
      @charbitmapAnimated = false
      @spriteoffset = false
      @cw = Game_Map::TILE_WIDTH * @character.width
      @ch = Game_Map::TILE_HEIGHT * @character.height
      self.src_rect.set(0, 0, @cw, @ch)
      self.ox = @cw / 2
      self.oy = @ch
     elsif @character_name != ""
        puts "DEBUG: Sprite_Character - Attempting to load: Graphics/Characters/#{@character_name}"
        begin
          @charbitmap = AnimatedBitmap.new(
            "Graphics/Characters/" + @character_name, @character_hue
          )
          puts "DEBUG: Sprite_Character - Successfully loaded AnimatedBitmap"
        rescue => e
          puts "DEBUG: Sprite_Character - Error loading AnimatedBitmap: #{e.message}"
          puts "DEBUG: Sprite_Character - Error backtrace: #{e.backtrace}"
        end
       RPG::Cache.retain("Graphics/Characters/", @character_name, @character_hue) if @character == $game_player
       @charbitmapAnimated = true
       @spriteoffset = @character_name[/offset/i]
       puts "DEBUG: Sprite_Character - AnimatedBitmap loaded successfully"
       puts "DEBUG: Sprite_Character - charbitmap.length: #{@charbitmap.length}"
        # For custom animated sprites, check if event defines frame size
        if @character.respond_to?(:frame_width) && @character.respond_to?(:frame_height) &&
           @character.frame_width > 0 && @character.frame_height > 0
          @cw = @character.frame_width
          @ch = @character.frame_height
          puts "DEBUG: Sprite_Character - Using custom frame size: #{@cw}x#{@ch}"
        # For custom animated sprites (like windmill), check if the filename indicates animation
        # and use appropriate dimensions
        elsif @character_name[/AnimatedTiles/i] || @charbitmap.length > 1
          # For animated tiles, use full height and calculate width based on frame count
          @ch = @charbitmap.height
          @cw = @charbitmap.width
          # If it's a PNG animated sprite with frame count in filename, use that to calculate width
          if @character_name[/\[(\d+),?\d*\]/]
            frame_count = $1.to_i
            @cw = @charbitmap.width / frame_count if frame_count > 1
          end
          puts "DEBUG: Sprite_Character - Using calculated frame size: #{@cw}x#{@ch}"
          puts "DEBUG: Sprite_Character - Bitmap dimensions: #{@charbitmap.width}x#{@charbitmap.height}"
          # For animated tiles, if it's a PngAnimatedBitmap, each frame already has correct dimensions
          if @charbitmap.length > 1
            @ch = @charbitmap.height
            @cw = @charbitmap.width
            puts "DEBUG: Sprite_Character - Using PngAnimatedBitmap frame size: #{@cw}x#{@ch}"
            puts "DEBUG: Sprite_Character - Number of frames: #{@charbitmap.length}"
          else
            # For single-frame bitmaps with multiple frames in a strip
            @ch = @charbitmap.height
            @cw = @charbitmap.width
            if @character_name[/\[(\d+),?\d*\]/]
              frame_count = $1.to_i
              @cw = @charbitmap.width / frame_count if frame_count > 1
            end
            puts "DEBUG: Sprite_Character - Using single bitmap frame size: #{@cw}x#{@ch}"
            puts "DEBUG: Sprite_Character - Bitmap dimensions: #{@charbitmap.width}x#{@charbitmap.height}"
          end
      else
        # For standard character sprites, use 4x4 grid
        @cw = @charbitmap.width / 4
        @ch = @charbitmap.height / 4
        puts "DEBUG: Sprite_Character - Using standard 4x4 grid size: #{@cw}x#{@ch}"
      end
      self.ox = @cw / 2
    else
      self.bitmap = nil
      @cw = 0
      @ch = 0
    end
    @character.sprite_size = [@cw, @ch]
  end

  def update
    return if @character.is_a?(Game_Event) && !@character.should_update?
    super
    refresh_graphic
    return if !@charbitmap
    @charbitmap.update if @charbitmapAnimated
    bushdepth = @character.bush_depth
    if bushdepth == 0
      self.bitmap = (@charbitmapAnimated) ? @charbitmap.bitmap : @charbitmap
    else
      @bushbitmap = BushBitmap.new(@charbitmap, (@tile_id >= 384), bushdepth) if !@bushbitmap
      self.bitmap = @bushbitmap.bitmap
    end
    self.visible = !@character.transparent
      if @tile_id == 0
       # For custom animated sprites, show full frame
       if @character_name[/AnimatedTiles/i] || @charbitmap.length > 1
         # Check if we have a single bitmap with custom frame size
         if @cw > 0 && @charbitmap.width > @cw
           total_frames = @charbitmap.width / @cw
           wait_frames = 5
           if @character_name[/\[\d+,(\d+)\]/]
             wait_frames = $1.to_i
           end
           @tile_animation_timer += 1
           if @tile_animation_timer >= wait_frames
             @tile_animation_timer = 0
             @tile_current_frame = (@tile_current_frame + 1) % total_frames
           end
           self.src_rect.set(@tile_current_frame * @cw, 0, @cw, @ch)
         else
           self.src_rect.set(0, 0, @cw, @ch)
         end
         self.oy = @ch  # Set to bottom of sprite
      else
        # For standard character sprites
        sx = @character.pattern * @cw
        sy = ((@character.direction - 2) / 2) * @ch
        self.src_rect.set(sx, sy, @cw, @ch)
        self.oy = (@spriteoffset rescue false) ? @ch - 16 : @ch
        self.oy -= @character.bob_height
      end
    end
    if self.visible
      if @character.is_a?(Game_Event) && @character.name[/regulartone/i]
        self.tone.set(0, 0, 0, 0)
      else
        pbDayNightTint(self)
      end
    end
    this_x = @character.screen_x
    this_x = ((this_x - (Graphics.width / 2)) * TilemapRenderer::ZOOM_X) + (Graphics.width / 2) if TilemapRenderer::ZOOM_X != 1
    self.x = this_x
    this_y = @character.screen_y
    this_y = ((this_y - (Graphics.height / 2)) * TilemapRenderer::ZOOM_Y) + (Graphics.height / 2) if TilemapRenderer::ZOOM_Y != 1
    self.y = this_y
    self.z = @character.screen_z(@ch)
    self.opacity = @character.opacity
    self.blend_type = @character.blend_type
    if @character.animation_id != 0
      animation = $data_animations[@character.animation_id]
      animation(animation, true)
      @character.animation_id = 0
    end
    @reflection&.update
    @surfbase&.update
  end
end
